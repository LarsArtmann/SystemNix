# Equivalence guard for the ai-meter spend formulas (2026-11-25).
#
# WHY: the reference cost of a routed AI call is computed in TWO places. The
# Go formula (BreakdownCost in internal/meter/config.go of the ai-meter
# input; EstimateCost is its
# total) prices the cumulative counter, and the dashboard's spend-rate
# queries derive it in PromQL from the token counters, so that a price row
# which lands late restates the chart's whole history
# (modules/nixos/services/_ai-meter-dashboard.nix). Two implementations of
# one formula drift silently: the first draft of the PromQL divided only its
# last term by 1e6, and its second forgot the per-hour scaling of the
# by-model chart. Both were caught right here. So nothing in this check
# trusts the generator's text:
#
#   1. promtool's PromQL engine evaluates what the generator REALLY emits,
#      on the fixture TestEstimateCostMatchesDashboardPromQL pins: each
#      minute adds 900 prompt tokens (180 cached) and 450 completions at
#      2/0.5/4 USD per 1M, which is 0.1998 USD per hour. The same figure
#      must come out of all four generated queries, and a second fixture
#      (two priced models, two clients) pins the per-client sum and the
#      24-hour window, which the Go side does not compute.
#   2. The Go side is held to the very same number, by running that test
#      with the value in its environment. Either formula moving alone
#      fails this check.
#   3. The dashboard evo-x2 will actually provision keeps both spend panels
#      and mentions every priced model in their queries (asserted here, at
#      flake-eval time); the build additionally rejects a leftover
#      placeholder.
#   4. No generated query carries a single-backslash escape. promtool would
#      accept it, SigNoz's own PromQL parser refuses it ("unknown escape
#      sequence"), and the first live cross-check on 2026-11-25 is what
#      caught that: two dead panels that every offline test had passed.
#
# promtool (3.16) compares samples EXACTLY, and rate() carries float noise
# (15 comes back as 14.999999999999998), so the PromQL side is rounded to
# 1e-4 USD/hour before it is compared. Every formula error moves the value
# by far more than that.
#
# Negative legs: scripts/negative-test-lints.sh, group `aimeter`.
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    lib.mkIf (system == "x86_64-linux") {
      # The proxy's own Go suite (vet and race tests), built by the ai-meter
      # flake from its locked source. The suite lives with the code; this
      # check makes `nix flake check` here refuse a floated rev that fails it.
      checks.ai-meter-go-suite = inputs.ai-meter.checks.${system}.go-test;

      checks.ai-meter-spend-promql =
        let
          renderer = import (root + "/modules/nixos/services/_ai-meter-dashboard.nix") { inherit lib; };
          template = builtins.readFile (root + "/modules/nixos/services/dashboards/ai-meter.json");

          host = inputs.self.nixosConfigurations.evo-x2.config.services.ai-meter;
          hostDashboard = builtins.fromJSON (builtins.readFile host.dashboard);

          # "quiet" is priced but never called: the total must not collapse
          # and the by-model chart must not show it.
          fixture = {
            m = {
              input = 2;
              output = 4;
              cachedInput = 0.5;
            };
            quiet = {
              input = 9;
              output = 9;
              cachedInput = 9;
            };
          };
          # 0.00333 USD per minute x 60 minutes, and the same figure scaled
          # for promtool's exact comparison.
          usdPerHour = "0.1998";
          usdPerHourRounded = 1998;

          series = model: client: kind: perMinute: {
            series = ''ai_meter_tokens_total{client="${client}",upstream="fake",model="${model}",kind="${kind}"}'';
            values = "0+${toString perMinute}x40";
          };
          inputSeries = [
            (series "m" "crush" "prompt" 900)
            (series "m" "crush" "cached" 180)
            (series "m" "crush" "completion" 450)
          ];
          # The same fixture one client wider: crush also calls "n", and
          # paperless calls "n" only. "n" costs (100 * 1 + 50 * 2) / 1e6 =
          # 0.0002 USD per minute for crush and a tenth of that for paperless.
          fixtureWide = fixture // {
            n = {
              input = 1;
              output = 2;
              cachedInput = 0.1;
            };
          };
          wideSeries = inputSeries ++ [
            (series "n" "crush" "prompt" 100)
            (series "n" "crush" "cached" 0)
            (series "n" "crush" "completion" 50)
            (series "n" "paperless" "prompt" 10)
            (series "n" "paperless" "cached" 0)
            (series "n" "paperless" "completion" 5)
          ];
          # USD per hour, scaled by 10000 for promtool's exact comparison:
          # "n" alone is 0.012 for crush and 0.0012 for paperless.
          wideModelN = 132;
          wideCrush = 2118;
          widePaperless = 12;
          wideTotal = 2130;
          # increase() over 24h on a 41-minute fixture, read at minute 30:
          # promtool (Prometheus 3) does not extend an integer counter past
          # its samples, so the window holds exactly the 30 minutes between
          # the first and the last sample. 0.00333 USD per minute then make
          # 0.0999 USD, and 0.00355 with both models 0.1065.
          usd24hRounded = 999;
          wide24hRounded = 1065;

          # One promtool unit test per fixture, each running all four
          # generated queries. The keys are promtool's own (it accepts JSON
          # as YAML).
          rounded = promql: "round((${promql}) * 10000, 1)";
          sample = labels: value: { inherit labels value; };
          testCase = costs: seriesList: expected: {
            interval = "1m";
            input_series = seriesList;
            promql_expr_test = [
              {
                expr = rounded (renderer.spendRate costs);
                eval_time = "30m";
                exp_samples = expected.total;
              }
              {
                expr = rounded (renderer.spendRateByModel costs);
                eval_time = "30m";
                exp_samples = expected.byModel;
              }
              {
                expr = rounded (renderer.spendRateByClient costs);
                eval_time = "30m";
                exp_samples = expected.byClient;
              }
              {
                expr = rounded (renderer.spendLast24h costs);
                eval_time = "30m";
                exp_samples = expected.last24h;
              }
            ];
          };
          promqlTest = pkgs.writeText "ai-meter-spend-test.json" (
            builtins.toJSON {
              rule_files = [ ];
              evaluation_interval = "1m";
              tests = [
                # One priced and called model: the figure the Go formula is
                # held to.
                (testCase fixture inputSeries {
                  total = [ (sample "{}" usdPerHourRounded) ];
                  byModel = [ (sample ''{model="m"}'' usdPerHourRounded) ];
                  byClient = [ (sample ''{client="crush"}'' usdPerHourRounded) ];
                  last24h = [ (sample "{}" usd24hRounded) ];
                })
                # Two clients on two priced models: a client's spend is the
                # sum over every model it calls.
                (testCase fixtureWide wideSeries {
                  total = [ (sample "{}" wideTotal) ];
                  byModel = [
                    (sample ''{model="m"}'' usdPerHourRounded)
                    (sample ''{model="n"}'' wideModelN)
                  ];
                  byClient = [
                    (sample ''{client="crush"}'' wideCrush)
                    (sample ''{client="paperless"}'' widePaperless)
                  ];
                  last24h = [ (sample "{}" wide24hRounded) ];
                })
                # No priced model: every figure is an honest zero, never an
                # empty panel.
                (testCase { } inputSeries {
                  total = [ (sample "{}" 0) ];
                  byModel = [ (sample ''{model="m"}'' 0) ];
                  byClient = [ (sample ''{client="crush"}'' 0) ];
                  last24h = [ (sample "{}" 0) ];
                })
              ];
            }
          );

          # Every priced model must appear in the spend-rate queries of the
          # dashboard that ships. The asserts fire when this file is evaluated.
          spendPanelNames = [
            "Spend Rate"
            "Spend Rate by Model"
            "Spend Rate by Client"
            "Spend (24h)"
          ];
          spendPanels = lib.filterAttrs (
            _: panel: builtins.elem panel.spec.display.name spendPanelNames
          ) hostDashboard.spec.panels;
          spendPanelList = lib.attrValues spendPanels;
          spendQueries = map (panel: (lib.head panel.spec.queries).spec.plugin.spec.query) spendPanelList;
          # The queries spell a model name regex-escaped ("glm-5[.]3").
          uncovered = lib.filter (
            model: !builtins.all (lib.hasInfix (renderer.escapeRegex model)) spendQueries
          ) (builtins.attrNames host.costs);

          # promtool accepts a single-backslash escape ("\\.") that SigNoz's own
          # PromQL parser rejects, and a dead panel is the only symptom (live
          # 2026-11-25). No spend-rate query may carry a lone backslash.
          carriesLoneBackslash = query: lib.hasInfix "\\" (lib.replaceStrings [ "\\\\" ] [ "" ] query);
          offending = lib.filter carriesLoneBackslash (
            [
              (renderer.spendRate fixture)
              (renderer.spendRateByModel fixture)
              (renderer.spendRateByClient fixture)
              (renderer.spendLast24h fixture)
            ]
            ++ spendQueries
          );
          wiringHolds =
            assert lib.assertMsg (lib.length spendPanelList == 4)
              "ai-meter-spend-promql: the dashboard must keep exactly one panel each for ${toString spendPanelNames}, found ${toString (lib.length spendPanelList)}";
            assert lib.assertMsg (uncovered == [ ])
              "ai-meter-spend-promql: priced models missing from the dashboard's spend-rate queries: ${toString uncovered}";
            assert lib.assertMsg (offending == [ ])
              "ai-meter-spend-promql: a spend-rate query carries a single-backslash escape, which SigNoz's PromQL parser rejects: ${lib.head offending}";
            !lib.hasInfix "@@" (builtins.readFile host.dashboard);
          fixtureDashboard = pkgs.writeText "ai-meter-dashboard-fixture.json" (
            renderer.render {
              inherit template;
              costs = fixture;
            }
          );
        in
        pkgs.runCommand "ai-meter-spend-promql"
          {
            nativeBuildInputs = [
              pkgs.go
              pkgs.prometheus.cli
            ];
          }
          ''
            fail() { echo "FAIL: ai-meter-spend-promql: $*" >&2; exit 1; }

            ${lib.optionalString (
              !wiringHolds
            ) "fail \"the dashboard evo-x2 provisions carries a template placeholder\""}
            grep -q '@@' ${fixtureDashboard} && fail "the rendered fixture dashboard still carries a template placeholder"

            promtool test rules ${promqlTest} \
              || fail "the generated PromQL disagrees with the Go cost formula (internal/meter/config.go BreakdownCost of the ai-meter input) on the 900/180/450 at 2/0.5/4 fixture"

            cp -r ${inputs.ai-meter} src
            (
              cd src/internal/meter
              # Pure Go: the module is stdlib-only and the sandbox has no C compiler.
              export HOME=$TMP GOCACHE=$TMP/gocache GOPATH=$TMP/gopath GOTOOLCHAIN=local GOPROXY=off GOFLAGS= CGO_ENABLED=0
              AI_METER_PROMQL_SPEND_RATE_USD_PER_HOUR=${usdPerHour} \
                go test -count=1 -run 'TestEstimateCost' . \
                || { echo "FAIL: ai-meter-spend-promql: EstimateCost disagrees with the ${usdPerHour} USD/hour the PromQL was held to" >&2; exit 1; }
            )

            echo "ok: PromQL and Go price the fixture identically; the dashboard prices ${toString (builtins.attrNames host.costs)}"
            touch $out
          '';
      # The ai-meter failure-rate alert under admission control (2026-11-26).
      #
      # WHY: on the gate's first night "AI Upstream Failure Rate High" sat
      # firing for 85 % of 30 hours (289 of 338 five-minute points). It
      # counted the 429 answers ai-meter makes itself (a call that waited out
      # its budget) as failures, mixed every provider into one ratio, and
      # read a provider with almost no traffic as "100 % failed". The rule is
      # now per provider, without the proxy's own answers, above a volume
      # floor. promtool evaluates the query the rule file REALLY carries, so a
      # rule that loses one of the three properties fails here:
      #
      #   gate-only      z.ai: 20 served, 19 sent back by ai-meter, 1 real 429
      #                  -> 4.8 %, silent
      #   provider-down  z.ai: 10 served, 30 failed (500)             -> fires
      #   storm          z.ai: 40 plain 429s and no admission outcome  -> fires
      #   quiet          llama-embeddings: one failed call per 5 min   -> 4 %, silent
      #   one-of-two     z.ai healthy, llama-embeddings failing        -> only it fires
      #
      # "Fires" is the rule's own comparison, applied by the test.
      #
      # Negative legs: scripts/negative-test-lints.sh, group `aimeter`
      # (alert-gate-blind-dropped, alert-floor-lowered, alert-floor-raised,
      # alert-429-ignored, alert-providers-mixed).
      #
      # The second rule, "AI Embeddings Calls Failing (ai-meter)", is held by
      # the same derivation. WHY: on 2026-11-26 llama-embeddings was active and
      # listening and failed 387 of 424 calls (each hung until its client gave
      # up); the unit rule saw nothing and the failure-rate rule keeps that
      # little traffic below its floor on purpose. The rule fires when at least
      # two calls failed and at least half of the calls did, in 30 minutes:
      #
      #   hang         one failed call every 5 minutes, nothing served  -> fires
      #   single       one failed call in the half hour                  -> 25, silent
      #   healthy      12 served                                          -> 0, silent
      #   minority     12 served, 6 failed                                -> 33, silent
      #   majority     6 served, 9 failed                                 -> 60, fires
      #   reset        only failures, the counter restarts midway         -> fires
      #   elsewhere    z.ai fails 40 a minute, embeddings served          -> 0, silent
      #
      # Negative legs: embeddings-floor-lowered, embeddings-window-shortened,
      # embeddings-status-widened, embeddings-target-raised,
      # embeddings-upstream-dropped (same group).
      checks.ai-meter-alert-promql =
        let
          readRule =
            path:
            (builtins.fromJSON (
              builtins.readFile inputs.self.nixosConfigurations.evo-x2.config.environment.etc.${path}.source
            )).condition;
          # A rule's own comparison as a boolean: 1 where it would fire.
          firesOf =
            condition:
            "(${(lib.head condition.compositeQuery.queries).spec.query}) >= bool ${toString condition.target}";
          rule = readRule "signoz/rules/ai-upstream-failure-rate.json";
          embeddingsRule = readRule "signoz/rules/ai-embeddings-failing.json";
          # The rule's own comparison as a boolean: 1 where it would fire.
          fires = firesOf rule;
          embeddingsFires = firesOf embeddingsRule;
          zai = "client=\"crush\",model=\"m\",upstream=\"zai\"";
          embed = "client=\"paperless\",model=\"bge-m3\",upstream=\"llama-embeddings\"";
          # A counter that grows by perMinute every minute, sampled 41 times.
          linear = metric: labels: perMinute: {
            series = "${metric}{${labels}}";
            values = "0+${toString perMinute}x40";
          };
          # One failed call every five minutes: 0.2 a minute, all of them failing.
          trickling = {
            series = "ai_meter_requests_total{${embed},code=\"502\"}";
            values = lib.concatMapStringsSep " " (minute: toString (minute / 5)) (lib.range 0 40);
          };
          outcome = upstream: doesFire: {
            labels = "{upstream=\"${upstream}\"}";
            value = if doesFire then 1 else 0;
          };
          test = seriesList: expected: {
            interval = "1m";
            input_series = seriesList;
            promql_expr_test = [
              {
                expr = fires;
                eval_time = "30m";
                exp_samples = expected;
              }
            ];
          };
          alertTest = pkgs.writeText "ai-meter-alert-test.json" (
            builtins.toJSON {
              rule_files = [ ];
              evaluation_interval = "1m";
              tests = [
                (test
                  [
                    (linear "ai_meter_requests_total" "${zai},code=\"200\"" 20)
                    (linear "ai_meter_requests_total" "${zai},code=\"429\"" 20)
                    (linear "ai_meter_admission_outcomes_total" "${zai},outcome=\"timeout\"" 19)
                  ]
                  [ (outcome "zai" false) ]
                )
                (test
                  [
                    (linear "ai_meter_requests_total" "${zai},code=\"200\"" 10)
                    (linear "ai_meter_requests_total" "${zai},code=\"500\"" 30)
                  ]
                  [ (outcome "zai" true) ]
                )
                (test
                  [ (linear "ai_meter_requests_total" "${zai},code=\"429\"" 40) ]
                  [
                    (outcome "zai" true)
                  ]
                )
                (test [ trickling ] [ (outcome "llama-embeddings" false) ])
                (test
                  [
                    (linear "ai_meter_requests_total" "${zai},code=\"200\"" 40)
                    (linear "ai_meter_requests_total" "${embed},code=\"502\"" 10)
                  ]
                  [
                    (outcome "llama-embeddings" true)
                    (outcome "zai" false)
                  ]
                )
              ];
            }
          );
          # The embeddings rule sums without a by(), so its result carries no labels.
          plain = doesFire: {
            labels = "{}";
            value = if doesFire then 1 else 0;
          };
          embTest = seriesList: doesFire: {
            interval = "1m";
            input_series = seriesList;
            promql_expr_test = [
              {
                expr = embeddingsFires;
                eval_time = "30m";
                exp_samples = [ (plain doesFire) ];
              }
            ];
          };
          served = perMinute: linear "ai_meter_requests_total" "${embed},code=\"200\"" perMinute;
          failed = perMinute: linear "ai_meter_requests_total" "${embed},code=\"502\"" perMinute;
          # One failed call, at minute 10; the counter then stays.
          single = {
            series = "ai_meter_requests_total{${embed},code=\"502\"}";
            values = lib.concatMapStringsSep " " (minute: if minute < 10 then "0" else "1") (lib.range 0 40);
          };
          # A failed-call counter that restarts at minute 20 and counts on.
          restarted = {
            series = "ai_meter_requests_total{${embed},code=\"502\"}";
            values = lib.concatMapStringsSep " " (
              minute: toString (if minute < 20 then minute else minute - 20)
            ) (lib.range 0 40);
          };
          embeddingsTest = pkgs.writeText "ai-meter-embeddings-alert-test.json" (
            builtins.toJSON {
              rule_files = [ ];
              evaluation_interval = "1m";
              tests = [
                (embTest [ trickling ] true)
                (embTest [ single ] false)
                (embTest [ (served 0.4) ] false)
                (embTest [ (served 0.4) (failed 0.2) ] false)
                (embTest [ (served 0.2) (failed 0.3) ] true)
                (embTest [ restarted ] true)
                (embTest [
                  (linear "ai_meter_requests_total" "${zai},code=\"502\"" 40)
                  (served 0.4)
                ] false)
              ];
            }
          );
        in
        pkgs.runCommand "ai-meter-alert-promql" { nativeBuildInputs = [ pkgs.prometheus.cli ]; } ''
          promtool test rules ${alertTest} > test.log 2>&1 \
            || { cat test.log; echo "FAIL: ai-meter-alert-promql: the failure-rate rule no longer tells the proxy's own 429 answers, a quiet provider and a failing provider apart" >&2; exit 1; }
          grep -q SUCCESS test.log || { cat test.log; echo "FAIL: ai-meter-alert-promql: promtool reported no SUCCESS" >&2; exit 1; }
          promtool test rules ${embeddingsTest} > embeddings.log 2>&1 \
            || { cat embeddings.log; echo "FAIL: ai-meter-alert-promql: the embeddings rule no longer tells a hung server (most calls failing) from one failed call, a healthy server and another provider's failures" >&2; exit 1; }
          grep -q SUCCESS embeddings.log || { cat embeddings.log; echo "FAIL: ai-meter-alert-promql: promtool reported no SUCCESS for the embeddings rule" >&2; exit 1; }
          echo "ok: the failure-rate rule is silent on gate answers and on a quiet provider, and fires per failing provider"
          echo "ok: the embeddings rule fires on a hung server and stays silent on one failed call, a healthy server and another provider's failures"
          touch $out
        '';
    };
}
