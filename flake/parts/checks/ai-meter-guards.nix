# Equivalence guard for the ai-meter spend formulas (2026-11-25).
#
# WHY: the reference cost of a routed AI call is computed in TWO places.
# EstimateCost (pkgs/ai-meter/config.go) prices the cumulative counter, and
# the dashboard's spend-rate queries derive it in PromQL from the token
# counters, so that a price row which lands late restates the chart's whole
# history (modules/nixos/services/_ai-meter-dashboard.nix). Two
# implementations of one formula drift silently: the first draft of the
# PromQL divided only its last term by 1e6. So nothing here trusts the
# generator's text:
#
#   1. promtool's PromQL engine evaluates what the generator REALLY emits,
#      on a token series chosen so every intermediate value is exact in
#      floating point (promtool 3.16 compares samples exactly): each minute
#      adds 900 prompt tokens (180 cached) and 450 completions at 2/0.5/4
#      USD per 1M, which is 0.1998 USD per hour.
#   2. The Go side is held to the very same number, by running
#      TestEstimateCostMatchesDashboardPromQL with the value in its
#      environment. Either formula moving alone fails this check.
#   3. The dashboard evo-x2 will actually provision keeps both spend panels
#      and mentions every priced model in their queries (asserted here, at
#      flake-eval time); the build additionally rejects a leftover
#      placeholder.
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
      checks.ai-meter-spend-promql =
        let
          renderer = import (root + "/modules/nixos/services/_ai-meter-dashboard.nix") { inherit lib; };
          template = builtins.readFile (root + "/modules/nixos/services/dashboards/ai-meter.json");

          host = inputs.self.nixosConfigurations.evo-x2.config.services.ai-meter;
          hostDashboard = builtins.fromJSON (builtins.readFile host.dashboard);

          # Each minute adds prompt 900 (180 of them cached) and completion
          # 450. "quiet" is priced but never called: the total must not
          # collapse and the by-model chart must not show it.
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
          # 0.00333 USD per minute x 60 minutes.
          usdPerHour = 0.1998;

          series =
            kind: perMinute:
            {
              series = ''ai_meter_tokens_total{client="crush",upstream="fake",model="m",kind="${kind}"}'';
              values = "0+${toString perMinute}x40";
            };
          inputSeries = [
            (series "prompt" 900)
            (series "cached" 180)
            (series "completion" 450)
          ];
          # One promtool unit test per price table: the total is a label-less
          # sample, the by-model chart one sample for the called model.
          # promtool's own keys, so the file is its native format (it accepts
          # JSON as YAML).
          testCase =
            costs: total:
            {
              interval = "1m";
              input_series = inputSeries;
              promql_expr_test = [
                {
                  expr = renderer.spendRate costs;
                  eval_time = "30m";
                  exp_samples = [
                    {
                      labels = "{}";
                      value = total;
                    }
                  ];
                }
                {
                  expr = renderer.spendRateByModel costs;
                  eval_time = "30m";
                  exp_samples = [
                    {
                      labels = ''{model="m"}'';
                      value = total;
                    }
                  ];
                }
              ];
            };
          promqlTest = pkgs.writeText "ai-meter-spend-test.json" (
            builtins.toJSON {
              rule_files = [ ];
              evaluation_interval = "1m";
              tests = [
                (testCase fixture usdPerHour)
                (testCase { } 0)
              ];
            }
          );

          # Every priced model must appear in the spend-rate queries of the
          # dashboard that ships. The asserts fire when this file is evaluated.
          spendPanelNames = [
            "Spend Rate"
            "Spend Rate by Model"
          ];
          spendPanels = lib.filterAttrs (
            _: panel: builtins.elem panel.spec.display.name spendPanelNames
          ) hostDashboard.spec.panels;
          spendPanelList = lib.attrValues spendPanels;
          spendQueries = map (panel: (lib.head panel.spec.queries).spec.plugin.spec.query) spendPanelList;
          # The queries spell a model name regex-escaped ("glm-5\.3").
          uncovered = lib.filter (
            model: !builtins.all (lib.hasInfix (renderer.escapeRegex model)) spendQueries
          ) (builtins.attrNames host.costs);
          wiringHolds =
            assert
            lib.assertMsg (lib.length spendPanelList == 2)
              "ai-meter-spend-promql: the dashboard must keep exactly one panel each for ${toString spendPanelNames}, found ${toString (lib.length spendPanelList)}"
            ;
            assert
            lib.assertMsg (uncovered == [ ])
              "ai-meter-spend-promql: priced models missing from the dashboard's spend-rate queries: ${toString uncovered}"
            ;
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

          ${lib.optionalString (!wiringHolds) "fail \"the dashboard evo-x2 provisions carries a template placeholder\""}
          grep -q '@@' ${fixtureDashboard} && fail "the rendered fixture dashboard still carries a template placeholder"

          promtool test rules ${promqlTest} \
            || fail "the generated PromQL disagrees with the Go cost formula (pkgs/ai-meter/config.go EstimateCost) on the 900/180/450 at 2/0.5/4 fixture"

          cp -r ${root + "/pkgs/ai-meter"} src
          (
            cd src
            export HOME=$TMP GOCACHE=$TMP/gocache GOPATH=$TMP/gopath GOTOOLCHAIN=local GOPROXY=off GOFLAGS=
            AI_METER_PROMQL_SPEND_RATE_USD_PER_HOUR=${toString usdPerHour} \
              go test -count=1 -run 'TestEstimateCost' . \
              || { echo "FAIL: ai-meter-spend-promql: EstimateCost disagrees with the ${toString usdPerHour} USD/hour the PromQL was held to" >&2; exit 1; }
          )

          echo "ok: PromQL and Go price the fixture identically; the dashboard prices ${toString (builtins.attrNames host.costs)}"
          touch $out
          '';
    };
}
