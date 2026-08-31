# VM test for the tmp-cleanup systemd-private-* guard.
#
# Regression test for the 2026-08-18..30 incident: the tmp-cleanup timer
# globbed /tmp/* without excluding systemd-private-* (PrivateTmp backing
# dirs) — forgejo mirrors died for 12 days (16,318 errors), discordsync
# dropped 550 attachment downloads, paperless celery and immich-ml crashed.
#
# Exercises the REAL deployed unit (imported from
# platforms/nixos/system/scheduled-tasks.nix, not a copy) against REAL
# systemd, plus proves the causal mechanism itself:
#
#   1. Fixtures: an artificially AGED systemd-private-* fixture must survive
#      a tmp-cleanup run while equally-aged junk is removed. Aging is the
#      deterministic re-creation of the incident condition (an idle/broken
#      service's backing dir ALWAYS profiles as stale — its mtime protection
#      can never fire).
#   2. Mechanism: a sacrificial PrivateTmp service; deleting its backing dir
#      from the host side must make every file creation inside the unit's
#      private /tmp fail (the forgejo "open /tmp/forgejo-clone-credentials-N:
#      no such file or directory" signature). This is the live repro the
#      incident report could only infer from correlation.
{ pkgs }:
{
  name = "tmp-cleanup";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        # The REAL host module (bare NixOS module — platforms/ files are not
        # flake-parts wrappers) + the users.primaryUser option it reads.
        (import ../platforms/nixos/system/scheduled-tasks.nix)
        (import ../platforms/nixos/system/primary-user.nix)
      ];
      # The module resolves config.users.users.<primaryUser>.uid at eval
      # time — root exists in every VM; the default "lars" does not.
      users.primaryUser = "root";

      # scheduled-tasks references the host-overlay package
      # pkgs.nur.repos.charmbracelet.crush (crush-update-providers unit);
      # runNixOSTest injects read-only nixpkgs (read-only.nix pins
      # nixpkgs.overlays with a unique type — a test-side overlay definition
      # collides with "defined multiple times"), so stub the UNIT instead of
      # the package. The unit never fires in this test (timer 00:00); it only
      # needs to render.
      systemd.services.crush-update-providers.serviceConfig.ExecStart =
        lib.mkForce "${pkgs.coreutils}/bin/true";

      # Sacrificial PrivateTmp victim for the mechanism proof (scenario 2).
      systemd.services.private-tmp-probe = {
        description = "sacrificial PrivateTmp probe (deleted-backing-dir mechanism)";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          PrivateTmp = true;
          ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
        };
      };

      system.stateVersion = "25.11";
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("private-tmp-probe.service")

    # ---- Scenario 1: the real tmp-cleanup unit preserves systemd-private-* ----
    # Aged 5h: looks EXACTLY like an idle/broken service's backing dir — the
    # mtime escape hatch must NOT save it; only the exclusion may.
    priv_fixture = "/tmp/systemd-private-0123456789abcdef0123456789abcdef-test-victim.service-FiXtUrE"
    machine.succeed(f"mkdir -p {priv_fixture} && touch {priv_fixture}/stale-inside")
    machine.succeed("mkdir -p /tmp/aged-junk-dir && touch /tmp/aged-junk-dir/inner")
    machine.succeed("touch /tmp/aged-file /tmp/fresh-file /tmp/.dotfile-aged")
    machine.succeed(
        "touch -m -d '5 hours ago' "
        f"{priv_fixture} {priv_fixture}/stale-inside "
        "/tmp/aged-junk-dir /tmp/aged-junk-dir/inner /tmp/aged-file /tmp/.dotfile-aged"
    )

    machine.succeed("systemctl start tmp-cleanup.service")

    machine.fail("test -e /tmp/aged-junk-dir")        # aged junk is removed
    machine.fail("test -e /tmp/aged-file")
    machine.succeed("test -e /tmp/fresh-file")        # fresh entries survive
    machine.succeed("test -e /tmp/.dotfile-aged")     # dotfiles are protected
    # THE regression assertion: maximally stale, still alive.
    machine.succeed(f"test -e {priv_fixture}")

    # ---- Scenario 2: mechanism — deleting a PrivateTmp backing dir kills /tmp in the namespace ----
    pid = machine.succeed("systemctl show -p MainPID --value private-tmp-probe.service").strip()
    assert pid not in ("", "0"), "probe has no MainPID"

    backing = machine.succeed("ls -d /tmp/systemd-private-*private-tmp-probe*").strip()
    machine.succeed(f"echo before > /proc/{pid}/root/tmp/before")
    # the write landed INSIDE the private tmp, not the host /tmp:
    machine.succeed(f"test -e {backing}/tmp/before")

    # Simulate the pre-fix tmp-cleanup (host-side rm of the backing dir).
    machine.succeed(f"rm -rf {backing}")

    # Forensics: is the namespace /tmp still listable, or gone outright?
    listable = machine.succeed(f"test -d /proc/{pid}/root/tmp && echo listable || echo gone").strip()
    print(f"private /tmp after backing-dir deletion: {listable}")

    # Every file creation inside the unit's private /tmp now fails — the
    # exact forgejo "no such file or directory" signature (unlinked bind
    # source → create returns ENOENT).
    machine.fail(f"echo after > /proc/{pid}/root/tmp/after")
    # ...and the pre-deletion file is gone with the backing dir:
    machine.fail(f"test -e /proc/{pid}/root/tmp/before")
  '';
}
