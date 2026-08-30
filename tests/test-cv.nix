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
    { lib, ... }:
    {
      imports = [
        cvNixosModule
        ./mock-sops.nix
        ./test-helpers.nix
      ];

      sops.templates."cv-env" = { };

      services.cv-server.enable = true;

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
    #    cv-scan timer is a no-op). The scan POST itself is only runnable
    #    once the cv flake input carries the X-API-Key CSRF bypass
    #    (2026-08-29); until then this asserts the wiring, not the request.
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

    print("CV server verified — starts, health responds, config generated, content synced, PDF export works, scan timer wired")
  '';
}
