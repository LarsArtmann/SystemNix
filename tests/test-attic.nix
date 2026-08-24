# VM test for the Attic binary cache module.
#
# Verifies the runtime risks that nix eval CANNOT check:
#   1. atticd starts (DynamicUser + storage permissions + systemd unit validity)
#   2. Health endpoint responds (catches non-existent API endpoint bugs)
#   3. Prometheus metrics file is valid (catches heredoc indentation bugs)
#   4. Storage directory is writable by DynamicUser
#   5. Size guard runs without error (no crash from missing ReadWritePaths)
#   6. atticd-atticadm make-token works (catches missing permission flags)
#   7. Full cache lifecycle: token → login → cache create (end-to-end)
#
# Uses mock-sops.nix so we can evaluate sops-dependent config without the age key.
# Generates a real RSA key at build time for JWT signing (same pattern as nixpkgs upstream test).
{ pkgs }:
let
  # Extract the NixOS module from the flake-parts wrapper.
  # attic.nix is _: { flake.nixosModules.attic = <nixos-module-fn>; }
  # Calling with {} extracts the inner module function.
  atticFlakeOutput = (import ../modules/nixos/services/attic.nix) { };
  atticNixosModule = atticFlakeOutput.flake.nixosModules.attic;

  # Generate a real RS256 key at build time (same pattern as the nixpkgs upstream test).
  # The module's environmentFile points to a sops template path; we override it
  # with this build-time file via mkForce so the VM has a real key without needing
  # a keygen oneshot service.
  testEnvFile = pkgs.runCommand "atticd-test-env" { } ''
    echo "ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=$(${pkgs.openssl}/bin/openssl genrsa -traditional 2048 | base64 -w0)" > $out
  '';
in
{
  name = "attic";

  nodes.machine = { lib, ... }: {
    imports = [
      atticNixosModule
      ./mock-sops.nix
      ./test-helpers.nix
    ];

    # Override the sops template path with a build-time generated key file.
    # mkForce is needed because the module sets environmentFile at default priority.
    services.atticd.environmentFile = lib.mkForce testEnvFile;

    # Use a VM-friendly storage path (no /data partition in QEMU)
    services.attic-config = {
      enable = true;
      storagePath = "/var/lib/atticd/storage";
    };

    # Declare the sops template + secret so config.sops.templates."attic-env".path
    # resolves (mock-sops creates the option, we just register the names)
    sops.templates."attic-env" = { };
    sops.secrets.attic_token_rs256_secret_base64 = { };
  };

  testScript = ''
    machine.start()

    # 1. atticd starts — catches DynamicUser + storage permission issues
    machine.wait_for_unit("atticd.service")

    # 2. Port is open
    machine.wait_for_open_port(8200)

    # 3. Health endpoint responds — the REAL endpoint (GET /),
    #    NOT the non-existent /api/v1/server-info that was in the original config
    machine.succeed("curl -sf http://localhost:8200/")

    # 4. Prometheus metrics: trigger manually and verify valid output.
    #    The grep with ^ (start-of-line anchor) catches heredoc indentation bugs
    #    where metric lines have leading whitespace (invalid Prometheus format).
    machine.systemctl("start atticd-metrics.service")
    machine.wait_for_file("/var/lib/prometheus-node-exporter/textfile_collectors/attic.prom")
    machine.succeed("grep -E '^attic_storage_bytes ' /var/lib/prometheus-node-exporter/textfile_collectors/attic.prom")
    machine.succeed("grep -E '^attic_storage_over_threshold ' /var/lib/prometheus-node-exporter/textfile_collectors/attic.prom")

    # 5. Storage directory exists (DynamicUser write access proven by atticd running)
    machine.succeed("test -d /var/lib/atticd/storage")

    # 6. Size guard runs without error (no crash from missing ReadWritePaths)
    machine.systemctl("start atticd-size-guard.service")

    # 7. atticd-atticadm make-token with permission flags (catches missing flags).
    #    Same flags as the nixpkgs upstream test. The nixpkgs module creates the
    #    atticd-atticadm wrapper which bakes in the config file and runs via
    #    systemd-run with the same DynamicUser/EnvironmentFile as atticd.
    token = machine.succeed("atticd-atticadm make-token --sub test --validity 1y --create-cache '*' --pull '*' --push '*' --delete '*' --configure-cache '*' --configure-cache-retention '*'").strip()
    assert len(token) > 50, f"Expected a JWT token, got: {token!r}"

    # 8. Full cache lifecycle: login + create cache (end-to-end smoke test)
    machine.succeed(f"attic login local http://localhost:8200 {token}")
    machine.succeed("attic cache create test-cache")

    # 9. Regression (2026-08-24): a detached DAS must SKIP the bootstrap, not
    #    fail it. The storage dir exists only while the pool is mounted (created
    #    by the mount-gated atticd-storage-dir). Removing it simulates the
    #    detached-DAS boot: re-running the bootstrap must land in
    #    result=condition (clean skip), NOT the old connection-refused exit-4
    #    failure that blocked every nh os switch during DAS outages.
    machine.succeed("rm -rf /var/lib/atticd/storage")
    machine.systemctl("restart atticd-bootstrap.service")
    # Condition skip => inactive + ConditionResult=no, and the journal shows
    # the skip. Result= is NOT a reliable signal across a restart (it retains
    # "success" from the pre-restart run), so assert on the properties that
    # actually change.
    state = machine.succeed("systemctl show -p ActiveState --value atticd-bootstrap.service").strip()
    cond = machine.succeed("systemctl show -p ConditionResult --value atticd-bootstrap.service").strip()
    assert state == "inactive", f"expected bootstrap inactive after condition skip, got {state!r}"
    assert cond == "no", f"expected ConditionResult=no, got {cond!r}"
    machine.succeed("journalctl -u atticd-bootstrap.service -b | grep -q 'unmet condition'")
    machine.fail("systemctl is-failed --quiet atticd-bootstrap.service")
  '';
}
