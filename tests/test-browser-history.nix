# VM test for the Browser History service module.
#
# Verifies the runtime behavior that nix eval CANNOT check:
#   1. Server starts without crash-looping (DynamicUser + StateDirectory)
#   2. Health endpoint responds with 200
#
# Uses mock-sops.nix + test-helpers.nix for shared mock infrastructure.
# Pocket ID/OIDC integration is NOT enabled (conditional on pocketIdEnabled),
# so the server runs in WebAuthn-only mode — the simplest valid configuration.
{
  pkgs,
  inputs,
}:
let
  browserHistoryFlakeOutput = (import ../modules/nixos/services/browser-history.nix) {
    inherit inputs;
  };
  browserHistoryNixosModule = browserHistoryFlakeOutput.flake.nixosModules.browser-history;

  mockAgentToken = pkgs.writeText "browser-history-env" ''
    BROWSER_HISTORY_AGENT_TOKEN=test-token-for-vm-only
  '';

  # Mock pocket-id-config option (not imported in this minimal test)
  mockPocketId =
    { lib, ... }:
    {
      options.services.pocket-id-config.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
in
{
  name = "browser-history";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        browserHistoryNixosModule
        ./mock-sops.nix
        ./test-helpers.nix
        mockPocketId
      ];

      users.users.testuser = {
        isNormalUser = true;
        password = "test";
      };

      sops.templates."browser-history-env" = { };
      sops.secrets.browser_history_agent_token = { };

      services.browser-history.enable = true;

      systemd.services.browser-history.serviceConfig.EnvironmentFile = lib.mkForce [
        "${mockAgentToken}"
      ];
    };

  testScript = ''
    machine.start()

    # 1. Server starts without crash-looping
    machine.wait_for_unit("browser-history.service")

    # 2. Health endpoint responds (Go server may need a moment to bind after
    #    systemd marks Type=simple as active)
    machine.wait_for_open_port(8087, timeout=30)
    machine.succeed("curl -sf http://localhost:8087/health")

    print("Browser History server verified — starts and health endpoint responds")
  '';
}
