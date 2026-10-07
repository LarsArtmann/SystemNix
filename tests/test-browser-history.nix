# VM test for the Browser History service module.
#
# Verifies the runtime behavior that nix eval CANNOT check:
#   1. Server starts without crash-looping (DynamicUser + StateDirectory)
#   2. Health endpoint responds with 200
#   3. Agent token provisioning: the co-located agent-token-provision oneshot
#      mints a real bh_ DB token non-interactively (the kill-the-manual-sops
#      flow), the agent env file lands root-owned, and the agent itself runs
#      against the provisioned token.
#   4. Machine attribution wiring: the provisioner labels the token with the
#      machineId option, a header-stamped ingest lands in the visits table,
#      and AD-2 cross-machine dedup keeps first-dispatch attribution.
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
      options.services.pocket-id-config = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        # The integration registry fan-out appends the module's OIDC client
        # here when the (mocked) namespace exists — declare the leaf.
        provision.extraOidcClients = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
        };
        provision.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
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
        # co-import: the module declares a services.integration entry (mkIf-wrapped options?-guard caveat, 2026-09-15)
        (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration
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
    # Any ANSWERED status = healthy wiring. Since AGENT_FRESHNESS
    # (lock 10fe5d8a+) a server with no agent ingest yet answers 503
    # "degraded" — demanding 200 here is the liveness-deadlock class
    # (the module's waitServerReady gate documents it); step 7's agent run
    # is what heals the server, asserted below.
    machine.wait_until_succeeds(
      "[[ $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8087/health) =~ ^[1-9][0-9][0-9]$ ]]",
      timeout=60,
    )

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

    # 7.5 The agent's (empty-batch) ingest HEALS the freshness-degraded
    #     health: AGENT_FRESHNESS flips the server back to 200 on first
    #     agent activity — the exact behavior the prod waitServerReady gate
    #     relies on.
    machine.wait_until_succeeds("curl -sf http://localhost:8087/health", timeout=60)

    # 8. Agent-activity collector: timer enabled, fresh ingest → active=1
    machine.succeed("systemctl is-active browser-history-agent-metrics.timer")
    machine.succeed(
      "sqlite3 /var/lib/browser-history/data.db "
      "\"UPDATE agent_tokens SET last_used_at = (strftime('%s','now') * 1000000000);\""
    )
    machine.succeed("systemctl start browser-history-agent-metrics.service")
    prom = machine.succeed(
      "cat /var/lib/prometheus-node-exporter/textfile_collectors/browser-history-agent.prom"
    )
    assert "browser_history_agent_scrape_errors 0\n" in prom, prom
    assert "browser_history_agent_tokens_total 1\n" in prom, prom
    assert "browser_history_agents_active 1\n" in prom, prom
    assert "browser_history_agent_last_ingest_age_seconds -" not in prom, prom

    # 9. Stale ingest (2h old > default 60min window) → active=0 (the alert)
    machine.succeed(
      "sqlite3 /var/lib/browser-history/data.db "
      "\"UPDATE agent_tokens SET last_used_at = (strftime('%s','now') * 1000000000) - 7200000000000;\""
    )
    machine.succeed("systemctl start browser-history-agent-metrics.service")
    prom = machine.succeed(
      "cat /var/lib/prometheus-node-exporter/textfile_collectors/browser-history-agent.prom"
    )
    assert "browser_history_agents_active 0\n" in prom, prom

    # 10. Scrape failure fails CLOSED: scrape_errors=1, active metric ABSENT
    machine.succeed("mv /var/lib/browser-history/data.db /var/lib/browser-history/data.db.bak")
    machine.succeed("systemctl start browser-history-agent-metrics.service")
    prom = machine.succeed(
      "cat /var/lib/prometheus-node-exporter/textfile_collectors/browser-history-agent.prom"
    )
    assert "browser_history_agent_scrape_errors 1\n" in prom, prom
    assert "browser_history_agents_active" not in prom, prom
    machine.succeed("mv /var/lib/browser-history/data.db.bak /var/lib/browser-history/data.db")

    # 11. Machine attribution wiring: the token label is the machineId option
    #     (single source of truth shared with the agent's X-Machine-Id header,
    #     enforced at eval by the wrapper's machineId binding), and a header-
    #     stamped /ingest lands machine_id in the visits table.
    machine.succeed(
      "test \"$(sqlite3 /var/lib/browser-history/data.db 'SELECT label FROM agent_tokens')\" = vm-test"
    )
    machine.succeed(
      "curl -sf -X POST http://127.0.0.1:8087/ingest "
      "-H \"Authorization: Bearer $(sed -n 's/^BROWSER_HISTORY_AGENT_TOKEN=//p' /var/lib/browser-history-agent-token/agent.env)\" "
      "-H \"X-Machine-Id: machine-a\" -H \"Content-Type: application/json\" "
      "-d '{\"visits\":[{\"url\":\"https://vm-machine.test/page-a\",\"title\":\"machine attribution probe\",\"domain\":\"vm-machine.test\",\"visitCount\":1,\"lastVisitTime\":\"2026-10-07T00:00:00Z\",\"typedCount\":0,\"browser\":\"chrome\",\"profile\":\"default\",\"productivity\":0}]}'"
    )
    machine.succeed(
      "test \"$(sqlite3 /var/lib/browser-history/data.db "
      "\"SELECT machine_id FROM visits WHERE url = 'https://vm-machine.test/page-a'\")\" = machine-a"
    )

    # 12. AD-2 cross-machine dedup on the deployed wiring: the SAME visit
    #     re-ingested under a different machine stays ONE row and keeps the
    #     first dispatcher's attribution (machine_id is attribution only,
    #     never part of the deterministic VisitID hash; upstream guard
    #     api/dedup_test.go).
    machine.succeed(
      "curl -sf -X POST http://127.0.0.1:8087/ingest "
      "-H \"Authorization: Bearer $(sed -n 's/^BROWSER_HISTORY_AGENT_TOKEN=//p' /var/lib/browser-history-agent-token/agent.env)\" "
      "-H \"X-Machine-Id: machine-b\" -H \"Content-Type: application/json\" "
      "-d '{\"visits\":[{\"url\":\"https://vm-machine.test/page-a\",\"title\":\"machine attribution probe\",\"domain\":\"vm-machine.test\",\"visitCount\":1,\"lastVisitTime\":\"2026-10-07T00:00:00Z\",\"typedCount\":0,\"browser\":\"chrome\",\"profile\":\"default\",\"productivity\":0}]}'"
    )
    machine.succeed(
      "test \"$(sqlite3 /var/lib/browser-history/data.db "
      "\"SELECT count(*) FROM visits WHERE url = 'https://vm-machine.test/page-a'\")\" = 1"
    )
    machine.succeed(
      "test \"$(sqlite3 /var/lib/browser-history/data.db "
      "\"SELECT machine_id FROM visits WHERE url = 'https://vm-machine.test/page-a'\")\" = machine-a"
    )

    print("Browser History verified — server healthy, token provisioning converges, agent runs, machine attribution wired")
  '';
}
