# VM test for the Browser History service module.
#
# Verifies the runtime behavior that nix eval CANNOT check:
#   1. Server starts without crash-looping (DynamicUser + StateDirectory)
#   2. Health endpoint responds with 200
#   3. Agent token provisioning: the co-located agent-token-provision oneshot
#      mints a real bh_ DB token non-interactively (the kill-the-manual-sops
#      flow), the agent env file lands root-owned, and the agent itself runs
#      against the provisioned token.
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

  # Canonical example ULID — users_view.key must be parseable as a ULID.
  vmUserULID = "01ARZ3NDEKTSV4RRFFQ69G5FAV";

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
      services.browser-history-agent = {
        enable = true;
        serverUrl = "http://127.0.0.1:8087";
        machineId = "vm-test";
      };

      environment.systemPackages = [ pkgs.sqlite ];

      systemd.services.browser-history.serviceConfig.EnvironmentFile = lib.mkForce [
        "${mockAgentToken}"
      ];
    };

  testScript = ''
    machine.start()

    # Keep the 1-min agent timer from racing the provisioning steps below.
    machine.execute("systemctl stop browser-history-agent.timer 2>/dev/null || true")

    # 1. Server starts without crash-looping
    machine.wait_for_unit("browser-history.service")

    # 2. Health endpoint responds (Go server may need a moment to bind after
    #    systemd marks Type=simple as active)
    machine.wait_for_open_port(8087, timeout=30)
    machine.succeed("curl -sf http://localhost:8087/health")

    # 3. Provisioner fails LOUDLY with no registered user (fresh-host guard)
    machine.succeed("systemctl start browser-history-agent-token-provision.service || true")
    machine.succeed("systemctl is-failed browser-history-agent-token-provision.service")
    machine.succeed(
      "journalctl -u browser-history-agent-token-provision.service "
      "| grep -q 'no registered users'"
    )

    # 4. Seed one user (full production column set) and re-run the provisioner
    machine.succeed(
      "sqlite3 /var/lib/browser-history/data.db \"INSERT INTO users_view "
      "(key, email, display_name, email_verified, totp_enabled, created_at, "
      "updated_at, data, tombstoned) VALUES "
      "('${vmUserULID}','vm@test.local','vm',0,0,"
      "'2026-01-01T00:00:00Z','2026-01-01T00:00:00Z','{}',0);\""
    )
    machine.succeed("systemctl start browser-history-agent-token-provision.service")

    # 5. The minted env file exists, is root-owned 0600, and carries a bh_ token
    machine.succeed("grep -q '^BROWSER_HISTORY_AGENT_TOKEN=bh_' /var/lib/browser-history-agent-token/agent.env")
    machine.succeed("test \"$(stat -c %a /var/lib/browser-history-agent-token/agent.env)\" = 600")
    machine.succeed("test \"$(stat -c %U /var/lib/browser-history-agent-token/agent.env)\" = root")

    # 6. Idempotent re-run makes no changes
    machine.succeed("systemctl restart browser-history-agent-token-provision.service")
    machine.succeed(
      "journalctl -u browser-history-agent-token-provision.service "
      "| grep -q 'already provisioned'"
    )

    # 7. The agent runs end-to-end against the provisioned token (empty
    #    browser set = empty sync, but the full auth path is exercised)
    machine.succeed("systemctl start browser-history-agent.service")
    machine.wait_until_succeeds(
      "[[ $(systemctl show -p Result --value browser-history-agent.service) == success ]]"
    )

    print("Browser History verified — server healthy, token provisioning converges, agent runs")
  '';
}
