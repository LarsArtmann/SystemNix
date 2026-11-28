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
#   5. The HARDENED unit can post its span export to the collector's OTLP
#      port: the recorded call arrives at the fake endpoint as a GenAI span
#      (the wire contract itself is covered by traces_test.go; this proves
#      the sandbox, the rendered otlp_endpoint and the async worker).
#   6. Cost survives a restart inside the HARDENED unit: the cost counter is
#      replayed from the ledger at every start, and nothing else is.
#   7. A price row that lands after a call was made restates that call: the
#      same binary, user and ledger with only the price table changed.
#   8. The module's own renderer: every optional proxy field it can set
#      (client priority, priority_aging_seconds, interactive_reserve,
#      quota_source, quota_provider) is absent at the defaults — the
#      default render is pinned byte for byte — and lands exactly where the
#      proxy reads it once set, with nothing else moving. The real binary
#      then boots on the part of that render the locked proxy knows.
{
  pkgs,
  inputs,
  ...
}:
let
  inherit (import ../lib/default.nix pkgs.lib) ports;
  inherit (pkgs) lib;

  # The derivation the unit runs (the ai-meter flake input's package), so
  # the restatement leg starts the real binary by hand.
  aiMeterExe = pkgs.lib.getExe inputs.ai-meter.packages.${pkgs.system}.ai-meter;
  aiMeterFlakeOutput = import ../modules/nixos/services/ai-meter.nix { inherit inputs; };
  aiMeterModule = aiMeterFlakeOutput.flake.nixosModules.ai-meter;

  catalogModule = (import ../modules/nixos/services/catalog.nix { }).flake.nixosModules.catalog;
  integrationModule =
    (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration;

  # Fake OpenAI-compatible upstream: answers every chat completion with the
  # usage block of one 100/20/50-token call, which prices at 0.00037 USD.
  fakeUpstream = pkgs.writeText "fake-upstream.py" ''
    import http.server

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            self.rfile.read(int(self.headers.get("Content-Length", "0")))
            body = b'{"choices":[],"usage":{"prompt_tokens":100,"completion_tokens":50,"total_tokens":150,"prompt_tokens_details":{"cached_tokens":20}}}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    http.server.ThreadingHTTPServer(("127.0.0.1", ${toString ports.llama-chat}), Handler).serve_forever()
  '';

  # Fake OTLP/HTTP endpoint: answers every export and appends its body to
  # /tmp/otlp-spans.jsonl, so the test can read the span the proxy sent.
  otlpSink = pkgs.writeText "otlp-sink.py" ''
    import http.server

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
            with open("/tmp/otlp-spans.jsonl", "a") as sink:
                sink.write(body.decode() + "\n")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"partialSuccess":{}}')

        def log_message(self, *args):
            pass

    http.server.ThreadingHTTPServer(("127.0.0.1", 4318), Handler).serve_forever()
  '';

  # Same shape the sops template renders; keys are fake (the VM never talks
  # to a real upstream: the "dead" upstream points at a closed port, and the
  # fake one stands in for a local model server, on llama-chat's registered
  # port). The price table is the only difference between the config the
  # unit deploys with and the one the restatement leg starts by hand.
  mkVmConfig =
    costs:
    pkgs.writeText "ai-meter-config.json" (
      builtins.toJSON {
        listen = "127.0.0.1:8107";
        metrics_listen = "127.0.0.1:8108";
        ledger_path = "/var/lib/ai-meter/usage.jsonl";
        inject_stream_usage = true;
        clients = [
          {
            name = "vmtest";
            key_file = "/run/ai-meter-keys/config/vmtest";
          }
        ];
        upstreams = [
          {
            name = "dead";
            base_url = "http://127.0.0.1:9";
            api_key = "unused";
          }
          {
            name = "fake";
            base_url = "http://127.0.0.1:${toString ports.llama-chat}";
            api_key = "unused";
          }
        ];
        inherit costs;
        otlp_endpoint = "http://127.0.0.1:4318";
        deployment_environment = "vmtest";
      }
    );
  vmConfig = mkVmConfig { };
  vmPricedConfig = mkVmConfig {
    m = {
      input = 2;
      output = 4;
      cached_input = 0.5;
    };
  };

  # --- The module's own renderer -------------------------------------------
  # proxyConfig is not an option; the content of the sops template is the
  # one place the rendered JSON shows up. Evaluated in isolation with the
  # same stubs the VM node below uses (mock-sops placeholders, catalog
  # module). The module's own assertions are NOT checked here: they fire in
  # the VM node's system build, which is what the negative legs
  # (scripts/negative-test-lints.sh, group aimeter) build.
  renderModule =
    settings:
    (pkgs.lib.evalModules {
      modules = [
        aiMeterModule
        catalogModule
        # The VM node imports this too (and the ai-meter module's registry
        # entry is guarded on the option's existence): without it the guard
        # sees no services.integration and emits an EMPTY mkIf'd definition,
        # which evalModules' check rejects ("option does not exist").
        integrationModule
        ../tests/mock-sops.nix
        (
          { lib, config, ... }:
          {
            config.sops.placeholder = lib.mapAttrs (_: _: "") config.sops.secrets;
            options.sops.placeholder = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
            };
            options.assertions = lib.mkOption {
              type = lib.types.listOf lib.types.attrs;
              default = [ ];
            };
            options.users.primaryUser = lib.mkOption { type = lib.types.str; };
            options.networking.domain = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
          }
        )
        {
          users.primaryUser = "root";
          services.ai-meter = {
            enable = true;
            clients.vmtest.user = "root";
          } // settings;
        }
      ];
    }).config.sops.templates."ai-meter-config".content;

  defaultRender = renderModule { };
  defaultConfig = builtins.fromJSON defaultRender;

  # Every optional field the module can set, at values that differ from the
  # proxy's own defaults so a dropped field cannot pass as a default. The VM
  # node sets the same options, so the module's assertions hold them too.
  newOptions = {
    clients.vmtest.priority = "interactive";
    priorityAgingSeconds = 45;
    interactiveReserve = 2;
    quotaSource = {
      enable = true;
      pollSeconds = 20;
      staleSeconds = 400;
    };
    upstreams.zai.quotaProvider = "zai";
  };
  fullConfig = builtins.fromJSON (renderModule newOptions);
  upstreamByName = builtins.listToAttrs (
    map (up: {
      name = up.name;
      value = up;
    }) fullConfig.upstreams
  );

  # The full render with the new fields lifted back out, serialized the way
  # the module serializes: must equal the default render byte for byte.
  strippedRender = builtins.toJSON (
    removeAttrs fullConfig [ "quota_source" ]
    // {
      clients = map (client: removeAttrs client [ "priority" ]) fullConfig.clients;
      upstreams = map (
        up:
        removeAttrs up [ "quota_provider" ]
        // lib.optionalAttrs (up ? admission) {
          admission = removeAttrs up.admission [
            "priority_aging_seconds"
            "interactive_reserve"
          ];
        }
      ) fullConfig.upstreams;
    }
  );

  # sha256 of defaultRender as the module rendered it BEFORE these options
  # existed (2026-11-28: `git show HEAD:modules/nixos/services/ai-meter.nix`,
  # evaluated through the same renderModule with the same stubs). Any
  # intended change to the rendered defaults (an upstream, a client field, a
  # price) updates it; an unintended one fails here, before the VM boots.
  defaultRenderHash = "__HASH__";

  renderChecks =
    (map (
      a:
      if a.assertion then
        null
      else
        throw "ai-meter module render: ${a.message}"
    ) [
      {
        assertion = strippedRender == defaultRender;
        message = "the new fields must be the only difference between the default and the full render";
      }
      {
        assertion = builtins.hashString "sha256" defaultRender == defaultRenderHash;
        message = "the default render is no longer byte-identical to the pre-options render";
      }
      {
        assertion = !lib.hasInfix "quota_source" defaultRender && !lib.hasInfix "quota_provider" defaultRender;
        message = "the default render must carry no quota_source and no quota_provider";
      }
      {
        assertion = builtins.all (
          up: !(up ? quota_provider) && (!(up ? admission) || (!(up.admission ? priority_aging_seconds) && !(up.admission ? interactive_reserve)))
        ) defaultConfig.upstreams;
        message = "no default upstream may carry quota_provider, priority_aging_seconds or interactive_reserve";
      }
      {
        assertion = builtins.all (client: !(client ? priority)) defaultConfig.clients;
        message = "no default client may carry a priority";
      }
      {
        assertion = defaultConfig.clients == [
          {
            name = "vmtest";
            key_file = "/run/ai-meter-keys/config/vmtest";
          }
        ];
        message = "the default client entry must be exactly name and key_file";
      }
      {
        assertion = fullConfig.clients == [
          {
            name = "vmtest";
            key_file = "/run/ai-meter-keys/config/vmtest";
            priority = "interactive";
          }
        ];
        message = "a client with priority set must render it third, after name and key_file";
      }
      {
        assertion = upstreamByName.zai.quota_provider == "zai";
        message = "upstreams.zai.quotaProvider must render as quota_provider on the zai upstream";
      }
      {
        assertion = upstreamByName.zai.admission.priority_aging_seconds == 45
        && upstreamByName.zai.admission.interactive_reserve == 2
        && upstreamByName.zai.admission.max_concurrency == 8
        && upstreamByName.zai.admission.quota_reset_utc_offset_hours == 8;
        message = "priorityAgingSeconds and interactiveReserve must land inside the zai admission block beside its existing keys";
      }
      {
        assertion = !builtins.any (name: upstreamByName.${name} ? quota_provider) (
          builtins.attrNames (removeAttrs upstreamByName [ "zai" ])
        );
        message = "no other upstream may carry a quota_provider";
      }
      {
        assertion = fullConfig.quota_source == {
          url = "http://127.0.0.1:8791";
          poll_seconds = 20;
          stale_seconds = 400;
        };
        message = "quota_source must render url (the quotaboard default), poll_seconds and stale_seconds";
      }
    ]);

  # The full render minus what the proxy input locked in flake.lock does not
  # know yet (quota_source and quota_provider: uncommitted in the ai-meter
  # repository on 2026-11-28). The real binary boots on this in the VM.
  bootableConfig = pkgs.writeText "ai-meter-module-config.json" (
    renderModule (
      removeAttrs newOptions [
        "quotaSource"
        "upstreams"
      ]
    )
  );
in
{
  name = "ai-meter";

  nodes.machine =
    { ... }:
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
        # Non-root consumer: exercises the CAP_CHOWN chown path the prod
        # clients (lars, paperless-gpt, inboxclean) actually take — a
        # chown-to-ROOT target is a kernel no-op that would mask a
        # missing capability (exactly how the first mint draft slipped).
        clients.vmtest2.user = "nobody";
      } // newOptions;

      # Point the template at the store-rendered config (mock-sops cannot
      # decrypt anything; the module's readOnly configFile follows).
      sops.templates."ai-meter-config".path = toString vmConfig;

      # The stand-in for the SigNoz collector's OTLP/HTTP receiver, on the
      # same loopback port the prod module renders.
      systemd.services.otlp-sink = {
        description = "fake OTLP/HTTP receiver for the ai-meter VM test";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${otlpSink}";
      };

      systemd.services.ai-meter-fake-upstream = {
        description = "fake OpenAI-compatible upstream for the ai-meter VM test";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${fakeUpstream}";
      };

      system.stateVersion = "25.11";
    };

  # renderChecks is a list of nulls once every check passed and a throw at
  # the first failed one; prepending its (empty) text forces it at eval.
  testScript = lib.concatStringsSep "" (map (_: "") renderChecks) + ''
    import json

    def cost_of(metrics, upstream):
        for line in metrics.splitlines():
            if line.startswith("ai_meter_cost_usd_total{") and f'upstream="{upstream}",model="m"' in line:
                return float(line.rsplit(" ", 1)[1])
        raise AssertionError(f"no cost series for upstream {upstream}:\n{metrics}")

    machine.start()

    with subtest("client key mint"):
        machine.wait_for_unit("ai-meter-keys.service")
        machine.succeed("stat -c '%U %a' /run/ai-meter-keys/vmtest | grep 'root 400'")
        machine.succeed("stat -c '%U %a' /run/ai-meter-keys/vmtest2 | grep 'nobody 400'")
        machine.succeed("stat -c '%U:%G %a' /run/ai-meter-keys/config | grep 'root:ai-meter 750'")
        machine.succeed("stat -c '%U %a' /run/ai-meter-keys/config/vmtest | grep 'ai-meter 400'")
        machine.succeed("cmp /run/ai-meter-keys/vmtest /run/ai-meter-keys/config/vmtest")

    with subtest("fake OTLP endpoint is listening"):
        machine.wait_for_unit("otlp-sink.service")
        machine.wait_for_open_port(4318)

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

    with subtest("the recorded call reaches the OTLP endpoint as a GenAI span"):
        # The export is asynchronous; bounded wait instead of a fixed sleep.
        machine.succeed("timeout 20 sh -c 'until test -s /tmp/otlp-spans.jsonl; do sleep 0.2; done'")
        exports = machine.succeed("cat /tmp/otlp-spans.jsonl").strip().splitlines()
        assert len(exports) == 1, exports
        export = json.loads(exports[0])
        resource = {a["key"]: a["value"] for a in export["resourceSpans"][0]["resource"]["attributes"]}
        assert resource["service.name"] == {"stringValue": "ai-meter"}, resource
        assert resource["deployment.environment"] == {"stringValue": "vmtest"}, resource
        span = export["resourceSpans"][0]["scopeSpans"][0]["spans"][0]
        assert span["name"] == "chat m", span
        assert span["kind"] == 3, span
        assert "parentSpanId" not in span, span
        assert span["status"]["code"] == 2, span
        attrs = {a["key"]: a["value"] for a in span["attributes"]}
        for key, want in {
            "gen_ai.operation.name": {"stringValue": "chat"},
            "gen_ai.request.model": {"stringValue": "m"},
            "gen_ai.provider.name": {"stringValue": "dead"},
            "gen_ai.response.finish_reasons": {"stringValue": "error"},
            "ai_meter.client": {"stringValue": "vmtest"},
            "error.type": {"stringValue": "ai_meter.upstream_unreachable"},
            "http.response.status_code": {"intValue": "502"},
        }.items():
            assert attrs.get(key) == want, f"{key}: {attrs.get(key)}, want {want}"
        machine.succeed("sleep 1")
        metrics = machine.succeed("curl -sf http://127.0.0.1:8108/metrics")
        assert 'ai_meter_spans_exported_total{outcome="ok"} 1' in metrics, metrics
        assert 'ai_meter_spans_exported_total{outcome="failed"} 0' in metrics, metrics

    with subtest("rejected and unknown calls export no span"):
        # 401 and 404 are answered before any call is recorded.
        machine.succeed("curl -s -o /dev/null -XPOST http://127.0.0.1:8107/v1/dead/chat/completions -d '{\"model\":\"m\"}'")
        machine.succeed("sleep 1")
        assert machine.succeed("wc -l < /tmp/otlp-spans.jsonl").strip() == "1"

    with subtest("ledger records the call"):
        machine.succeed("grep -q '\"client\":\"vmtest\"' /var/lib/ai-meter/usage.jsonl")

    with subtest("admin plane exposes the family surface"):
        machine.succeed("curl -sf http://127.0.0.1:8108/metrics | grep '# TYPE ai_meter_tokens_total counter'")
        machine.succeed("curl -sf http://127.0.0.1:8108/metrics | grep '# TYPE ai_meter_spans_exported_total counter'")

    with subtest("an unpriced call is metered at zero cost"):
        machine.wait_for_unit("ai-meter-fake-upstream.service")
        machine.wait_for_open_port(${toString ports.llama-chat})
        machine.succeed(
            "curl -sf -o /dev/null -XPOST http://127.0.0.1:8107/v1/fake/chat/completions"
            + " -H 'Authorization: Bearer '$(cat /run/ai-meter-keys/vmtest)"
            + " -H 'Content-Type: application/json' -d '{\"model\":\"m\"}'"
        )
        machine.succeed("sleep 1")
        metrics = machine.succeed("curl -sf http://127.0.0.1:8108/metrics")
        assert 'ai_meter_tokens_total{client="vmtest",upstream="fake",model="m",kind="prompt"} 100' in metrics, metrics
        assert cost_of(metrics, "fake") == 0, metrics

    with subtest("the hardened unit replays the ledger at start, cost family only"):
        machine.systemctl("restart ai-meter.service")
        machine.wait_for_unit("ai-meter.service")
        machine.wait_for_open_port(8108)
        # The replay runs alongside serving, so the cost series can land a
        # moment after the port opens.
        machine.succeed("timeout 20 sh -c 'until curl -sf http://127.0.0.1:8108/metrics | grep -q ai_meter_cost_usd_total.; do sleep 0.1; done'")
        metrics = machine.succeed("curl -sf http://127.0.0.1:8108/metrics")
        # No call has been made since the restart, yet both earlier calls have
        # a cost series; the restart-reset families are still empty.
        assert cost_of(metrics, "fake") == 0, metrics
        assert cost_of(metrics, "dead") == 0, metrics
        assert "ai_meter_requests_total{" not in metrics, metrics

    with subtest("a price row that lands later restates the earlier call"):
        machine.systemctl("stop ai-meter.service")
        machine.succeed(
            "systemd-run --unit=ai-meter-priced --uid=ai-meter ${aiMeterExe} -config ${vmPricedConfig}"
        )
        machine.wait_for_unit("ai-meter-priced.service")
        machine.wait_for_open_port(8108)
        machine.succeed("timeout 20 sh -c 'until curl -sf http://127.0.0.1:8108/metrics | grep -q ai_meter_cost_usd_total.; do sleep 0.1; done'")
        metrics = machine.succeed("curl -sf http://127.0.0.1:8108/metrics")
        assert abs(cost_of(metrics, "fake") - 0.00037) < 1e-12, metrics

        # A second start at the same price must not count the call twice...
        machine.systemctl("restart ai-meter-priced.service")
        machine.wait_for_open_port(8108)
        machine.succeed("timeout 20 sh -c 'until curl -sf http://127.0.0.1:8108/metrics | grep -q ai_meter_cost_usd_total.; do sleep 0.1; done'")
        metrics = machine.succeed("curl -sf http://127.0.0.1:8108/metrics")
        assert abs(cost_of(metrics, "fake") - 0.00037) < 1e-12, metrics

        # ...and a call made after the price landed adds on top of it.
        machine.succeed(
            "curl -sf -o /dev/null -XPOST http://127.0.0.1:8107/v1/fake/chat/completions"
            + " -H 'Authorization: Bearer '$(cat /run/ai-meter-keys/vmtest)"
            + " -H 'Content-Type: application/json' -d '{\"model\":\"m\"}'"
        )
        machine.succeed("sleep 1")
        metrics = machine.succeed("curl -sf http://127.0.0.1:8108/metrics")
        assert abs(cost_of(metrics, "fake") - 0.00074) < 1e-12, metrics
        ledger_lines = machine.succeed("wc -l < /var/lib/ai-meter/usage.jsonl").strip()
        assert ledger_lines == "3", f"the ledger must hold exactly the three calls made, has {ledger_lines}"

    with subtest("the proxy boots on the module's own render"):
        # Rendered by the module (not hand-written): the client priority and
        # the zai admission block's priority_aging_seconds and
        # interactive_reserve, as the eval-time checks above pinned them.
        # Both ports have to be free, so the hand-started unit of the previous
        # leg stops first.
        machine.systemctl("stop ai-meter-priced.service")
        machine.succeed(
            "systemd-run --unit=ai-meter-module --uid=ai-meter ${aiMeterExe} -config ${bootableConfig}"
        )
        machine.wait_for_unit("ai-meter-module.service")
        machine.wait_for_open_port(8107)
        machine.wait_for_open_port(8108)
        machine.succeed("curl -sf http://127.0.0.1:8107/health | grep ok")
        # The key file the render names is the one the module's mint wrote:
        # the minted key authenticates (an unknown upstream answers 404, not 401).
        status = machine.succeed(
            "curl -s -o /dev/null -w '%{http_code}' -XPOST http://127.0.0.1:8107/v1/nope/chat/completions"
            + " -H 'Authorization: Bearer '$(cat /run/ai-meter-keys/vmtest)"
            + " -H 'Content-Type: application/json' -d '{\"model\":\"m\"}'"
        )
        assert status.strip() == "404", f"expected 404 with the minted key, got {status}"
  '';
}
