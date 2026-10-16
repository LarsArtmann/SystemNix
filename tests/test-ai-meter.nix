# VM test for the ai-meter service module (modules/nixos/services/ai-meter.nix).
#
# The full metering behavior (streaming usage capture, injection, cost math,
# ledger) is covered by the Go test suite (buildflow -s test-race) against a
# fake upstream — duplicating that in a VM buys nothing. This test verifies
# what only the assembled SYSTEM can prove:
#   1. The ai-meter-keys oneshot mints a per-client key with the right
#      owner (root) and mode (0400) in /run/ai-meter-keys, PLUS the
#      ai-meter-owned daemon mirror (config/<name>, 0400) the proxy
#      actually authenticates against.
#   2. The daemon boots against a store-rendered config at the sops
#      template path (mock-sops path-override pattern) and binds both
#      loopback ports.
#   3. Auth is enforced on the proxy port (401 without key), unknown
#      upstreams 404, and a BAD upstream key yields 502 with the request
#      still RECORDED (metering must never break the call).
#   4. The admin plane exposes the ai_meter_* Prometheus families.
{
  pkgs,
  ...
}:
let
  aiMeterFlakeOutput = (import ../modules/nixos/services/ai-meter.nix) { };
  aiMeterModule = aiMeterFlakeOutput.flake.nixosModules.ai-meter;

  catalogModule = (import ../modules/nixos/services/catalog.nix { }).flake.nixosModules.catalog;
  integrationModule =
    (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration;

  # Same shape the sops template renders; keys are fake (the VM never talks
  # to a real upstream — the "dead" upstream points at a closed port).
  vmConfig = pkgs.writeText "ai-meter-config.json" (
    builtins.toJSON {
      listen = "127.0.0.1:8107";
      metrics_listen = "127.0.0.1:8108";
      ledger_path = "/var/lib/ai-meter/usage.jsonl";
      inject_stream_usage = true;
      clients = [ { name = "vmtest"; key_file = "/run/ai-meter-keys/config/vmtest"; } ];
      upstreams = [
        {
          name = "dead";
          base_url = "http://127.0.0.1:9";
          api_key = "unused";
        }
      ];
      costs = { };
    }
  );
in
{
  name = "ai-meter";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        aiMeterModule
        catalogModule
        integrationModule
        ../tests/mock-sops.nix
        # mock-sops declares no sops.placeholder (the real module does) —
        # mirror its contract loosely: every declared secret has a
        # placeholder string (empty here; the VM overrides the template
        # path, so only eval-ability matters).
        (
          {
            config,
            lib,
            ...
          }:
          {
            options.sops.placeholder = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
            };
            config.sops.placeholder = lib.mapAttrs (_: _: "") config.sops.secrets;
          }
        )
      ];

      services.ai-meter = {
        enable = true;
        clients.vmtest.user = "root";
      };

      # Point the template at the store-rendered config (mock-sops cannot
      # decrypt anything; the module's readOnly configFile follows).
      sops.templates."ai-meter-config".path = toString vmConfig;

      system.stateVersion = "25.11";
    };

  testScript = ''
    machine.start()

    with subtest("client key mint"):
        machine.wait_for_unit("ai-meter-keys.service")
        machine.succeed("stat -c '%U %a' /run/ai-meter-keys/vmtest | grep 'root 400'")
        machine.succeed("stat -c '%U %a' /run/ai-meter-keys/config/vmtest | grep 'ai-meter 400'")
        machine.succeed("cmp /run/ai-meter-keys/vmtest /run/ai-meter-keys/config/vmtest")

    with subtest("daemon boots and binds both loopback ports"):
        machine.wait_for_unit("ai-meter.service")
        machine.wait_for_open_port(8107)
        machine.wait_for_open_port(8108)
        machine.succeed("curl -sf http://127.0.0.1:8107/health | grep ok")
        machine.succeed("curl -sf http://127.0.0.1:8108/health | grep ok")

    with subtest("auth enforced on the proxy port"):
        status = machine.succeed(
          "curl -s -o /dev/null -w '%{http_code}' -XPOST http://127.0.0.1:8107/v1/dead/chat/completions"
          + " -H 'Content-Type: application/json' -d '{\"model\":\"m\"}'"
        )
        assert status.strip() == "401", f"expected 401 without key, got {status}"

    with subtest("unknown upstream 404"):
        status = machine.succeed(
          "curl -s -o /dev/null -w '%{http_code}' -XPOST http://127.0.0.1:8107/v1/nope/chat/completions"
          + " -H 'Authorization: Bearer '$(cat /run/ai-meter-keys/vmtest)"
          + " -H 'Content-Type: application/json' -d '{\"model\":\"m\"}'"
        )
        assert status.strip() == "404", f"expected 404 for unknown upstream, got {status}"

    with subtest("dead upstream yields 502 but the call is metered"):
        status = machine.succeed(
          "curl -s -o /dev/null -w '%{http_code}' -XPOST http://127.0.0.1:8107/v1/dead/chat/completions"
          + " -H 'Authorization: Bearer '$(cat /run/ai-meter-keys/vmtest)"
          + " -H 'Content-Type: application/json' -d '{\"model\":\"m\"}'"
        )
        assert status.strip() == "502", f"expected 502 for dead upstream, got {status}"
        machine.succeed("sleep 1")
        metrics = machine.succeed("curl -sf http://127.0.0.1:8108/metrics")
        assert 'ai_meter_requests_total{client="vmtest",upstream="dead",model="m",code="502"} 1' in metrics, metrics
        assert "ai_meter_unauthorized_total 1" in metrics, metrics

    with subtest("ledger records the call"):
        machine.succeed("grep -q '\"client\":\"vmtest\"' /var/lib/ai-meter/usage.jsonl")

    with subtest("admin plane exposes the family surface"):
        machine.succeed("curl -sf http://127.0.0.1:8108/metrics | grep '# TYPE ai_meter_tokens_total counter'")
  '';
}
