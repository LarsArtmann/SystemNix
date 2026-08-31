# VM test for the CV service wrapper module (services.cv-server).
#
# Verifies the runtime behavior that nix eval CANNOT check (the full
# production claim chain from the 2026-08-27 deployment):
#   1. Server starts without crash-looping under the sops EnvironmentFile
#      wiring + hardening profile (MemoryMax, GOMEMLIMIT, ReadWritePaths)
#   2. /health/live responds with 200 (go-health probe, raw-mux route)
#   3. config.yaml is generated from `settings` into the state dir
#   4. Content sync materialized the typst template (assets/typst/cv.typ)
#      — the asset-vanishing incident class this must never regress
#   5. /export/pdf returns real PDF magic bytes (typst renderer end-to-end)
#   6-8. scan automation + session-probe wiring (see below)
#   9. Pool backup dir SELF-CREATES on a mounted /mnt/pool (2026-08-31
#      regression: the pool fs never had /mnt/pool/backups/cv and every
#      cv-backup died 226/NAMESPACE — ReadWritePaths cannot be fixed
#      in-unit because systemd builds the namespace BEFORE ExecStart)
#  10. Full replay of the incident: dir removed (fresh pool), deploy-style
#      restart of cv-backup-dir, real sqlite seed, cv-backup lands a
#      pipeline-*.sqlite file pool-side, unit not failed
#
# Uses mock-sops.nix + test-helpers.nix for shared mock infrastructure.
# The rendered sops template is never produced inside the VM, so the
# EnvironmentFile is mkForce'd to a mock (browser-history test pattern).
{
  pkgs,
  inputs,
}:
let
  cvWrapperFlakeOutput = (import ../modules/nixos/services/cv.nix) { inherit inputs; };
  cvNixosModule = cvWrapperFlakeOutput.flake.nixosModules.cv;

  mockCvEnv = pkgs.writeText "cv-env" ''
    CV_API_KEY=test-api-key-for-vm-only
  '';

  # lib/ports.nix: cv = 8098. Hardcoded here because the testScript is a
  # plain string (no Nix interpolation of the lib import).
  cvPort = 8098;

  # For seeding a REAL sqlite store the backup unit can .backup from.
  sqliteBin = "${pkgs.sqlite}/bin/sqlite3";
in
{
  name = "cv";

  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = [
        cvNixosModule
        ./mock-sops.nix
        ./test-helpers.nix
      ];

      sops.templates."cv-env" = { };

      services.cv-server.enable = true;

      # Probe timer (plan T23): assert the wiring with a stub chromium so
      # the VM closure stays light — the real deployment uses pkgs.chromium.
      services.cv-server.profileProbe = {
        enable = true;
        chromiumPackage = pkgs.hello;
      };

      systemd.services.cv-server.serviceConfig.EnvironmentFile = lib.mkForce [
        "${mockCvEnv}"
      ];

      # Simulate the mirrored HDD pool: a second disk auto-formatted and
      # mounted at /mnt/pool, exactly what cv-backup-dir's RequiresMountsFor
      # gates on in production.
      virtualisation.emptyDiskImages = [ 512 ];
      fileSystems."/mnt/pool" = {
        device = "/dev/vdb";
        fsType = "ext4";
        autoFormat = true;
      };
    };

  testScript = ''
    machine.start()

    # 1. Server starts without crash-looping
    machine.wait_for_unit("cv-server.service")

    # 2. Health probe responds (content sync + Go boot can take a moment)
    machine.wait_for_open_port(${toString cvPort}, timeout=120)
    machine.succeed("curl -sf http://localhost:${toString cvPort}/health/live")

    # 3. config.yaml generated from settings into the state dir
    machine.succeed("test -f /var/lib/cv/config.yaml")

    # 4. Content sync materialized the typst template (asset-vanishing incident class)
    machine.succeed("test -f /var/lib/cv/assets/typst/cv.typ")

    # 5. PDF export returns real PDF magic bytes (typst end-to-end)
    pdf = machine.succeed("curl -sf 'http://localhost:${toString cvPort}/export/pdf'")
    assert pdf.startswith("%PDF"), "PDF export did not return PDF magic bytes"

    # 6. Continuous scan automation wired: timer active, portals present in
    #    the GENERATED config (settings are the whole config.yaml — without
    #    this list the server answers 400 "no portals configured" and the
    #    cv-scan timer is a no-op).
    machine.wait_for_unit("cv-scan.timer")
    machine.succeed("grep -q 'freelancermap.com/projects/remote' /var/lib/cv/config.yaml")
    machine.succeed("test \"$(grep -c 'freelancermap.com/projects' /var/lib/cv/config.yaml)\" -ge 9")
    # systemctl show -P ExecStart prints the load-image format
    # "{ path=/nix/store/... ; argv[]=... ; ... }" — extract the bare
    # script path before grepping its contents (caught by the first real
    # VM run 2026-08-30: the braces made grep treat the whole line as a
    # filename).
    scan_script = machine.succeed(
      "systemctl show -P ExecStart cv-scan.service | tr ';' '\\n' | sed -n 's/.*path=//p' | tr -d ' '"
    ).strip()
    machine.succeed("test -f " + scan_script)
    machine.succeed("grep -q 'api/pipeline/scan' " + scan_script)
    machine.succeed("grep -q 'api/pipeline/evaluate-tracked' " + scan_script)

    # 7. Live scan-POST through the full stdlib chain: the cv flake input
    #    now carries the X-API-Key CSRF bypass (2026-08-29), so the exact
    #    timer request shape is provable in-VM — no key -> 403 (nosurf
    #    armed), wrong key -> 401 (fail-closed APIKeyAuth), mock env key
    #    -> 200 (bypass + auth). The body pins one connection-refused
    #    portal so the accepted async scan cannot egress the VM.
    def scan_status(extra_headers):
        return machine.succeed(
            "curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' "
            + extra_headers
            + " --data '{\"portals\":[{\"url\":\"http://127.0.0.1:1/refused\",\"company\":\"vm-test\"}]}'"
            + " http://localhost:${toString cvPort}/api/pipeline/scan"
        ).strip()

    no_key = scan_status("")
    assert no_key == "403", "POST without X-API-Key must hit nosurf (got " + no_key + ")"
    wrong_key = scan_status("-H 'X-API-Key: wrong-key'")
    assert wrong_key == "401", "wrong X-API-Key must be fail-closed (got " + wrong_key + ")"
    ok_key = scan_status("-H 'X-API-Key: test-api-key-for-vm-only'")
    assert ok_key == "200", "timer-shaped POST must bypass CSRF and pass auth (got " + ok_key + ")"

    # 8. Session-probe timer wiring (T23): the unit exists with the probe
    #    command and the chromium env, and the weekly timer is scheduled.
    #    Wiring-only: the probe itself needs operator sessions + a real
    #    browser, neither of which exists in the VM.
    machine.succeed("systemctl cat cv-profile-probe.service | grep -q 'profile accounts --probe --all'")
    machine.succeed("systemctl cat cv-profile-probe.service | grep -q 'CHROMIUM_EXECUTABLE_PATH'")
    machine.succeed("systemctl list-timers | grep -q cv-profile-probe")

    # 9. Regression (2026-08-31): the pool-side backup dir must SELF-CREATE.
    #    Production incident: /mnt/pool/backups/cv never existed on the pool
    #    fs — a root-fs shadow dir under the mountpoint masked it during the
    #    9-day DAS outage, and the pool remount turned every cv-backup run
    #    into 226/NAMESPACE. The mount-gated cv-backup-dir oneshot
    #    (atticd-storage-dir pattern) is the declarative creator: boot-wired
    #    via multi-user.target, restarted by deploy.sh, wants-pulled by the
    #    cv-backup timer transaction.
    machine.wait_for_unit("cv-backup-dir.service")
    machine.succeed("test -d /mnt/pool/backups/cv")
    machine.succeed("systemctl cat cv-backup.service | grep -q 'RequiresMountsFor=/mnt/pool/backups/cv'")

    # 10. Replay the exact production state (pool WITHOUT the dir) + the
    #     deploy convergence path: restart the creator (what deploy.sh does
    #     post-switch), seed a real sqlite store, then run a real backup.
    #     Asserts the artifact lands pool-side and the unit is not failed —
    #     the 226 class can never recur silently.
    machine.succeed("rm -rf /mnt/pool/backups/cv")
    machine.systemctl("restart cv-backup-dir.service")
    machine.succeed("test -d /mnt/pool/backups/cv")
    machine.succeed("mkdir -p /var/lib/cv/data")
    machine.succeed("${sqliteBin} /var/lib/cv/data/pipeline.sqlite 'CREATE TABLE IF NOT EXISTS _vm_seed(x)'")
    machine.systemctl("start cv-backup.service")
    machine.succeed("test -f /mnt/pool/backups/cv/pipeline-*.sqlite")
    machine.fail("systemctl is-failed --quiet cv-backup.service")

    print("CV server verified — starts, health responds, config generated, content synced, PDF export works, scan timer wired, timer-shaped scan-POST live-proven, session-probe timer wired, pool backup dir self-creates + backup lands")
  '';
}
