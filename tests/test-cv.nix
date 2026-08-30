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

    print("CV server verified — starts, health responds, config generated, content synced, PDF export works, scan timer wired, timer-shaped scan-POST live-proven, session-probe timer wired")
  '';
}
