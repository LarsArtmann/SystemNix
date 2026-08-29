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

    print("CV server verified — starts, health responds, config generated, content synced, PDF export works")
  '';
}
