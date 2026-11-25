# Equivalence guard for the ai-meter spend formulas (2026-11-25).
#
# WHY: the reference cost of a routed AI call is computed in TWO places. The
# Go formula (BreakdownCost in pkgs/ai-meter/config.go; EstimateCost is its
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
#      2/0.5/4 USD per 1M, which is 0.1998 USD per hour.
#   2. The Go side is held to the very same number, by running that test
#      with the value in its environment. Either formula moving alone
#      fails this check.
#   3. The dashboard evo-x2 will actually provision keeps both spend panels
#      and mentions every priced model in their queries (asserted here, at
#      flake-eval time); the build additionally rejects a leftover
#      placeholder.
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

          series = kind: perMinute: {
            series = ''ai_meter_tokens_total{client="crush",upstream="fake",model="m",kind="${kind}"}'';
            values = "0+${toString perMinute}x40";
          };
          inputSeries = [
            (series "prompt" 900)
            (series "cached" 180)
            (series "completion" 450)
          ];
          # One promtool unit test per price table: the total is a label-less
          # sample, the by-model chart one sample for the called model. The
          # keys are promtool's own (it accepts JSON as YAML).
          rounded = promql: "round((${promql}) * 10000, 1)";
          testCase = costs: total: {
            interval = "1m";
            input_series = inputSeries;
            promql_expr_test = [
              {
                expr = rounded (renderer.spendRate costs);
                eval_time = "30m";
                exp_samples = [
                  {
                    labels = "{}";
                    value = total;
                  }
                ];
              }
              {
                expr = rounded (renderer.spendRateByModel costs);
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
                (testCase fixture usdPerHourRounded)
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
            assert lib.assertMsg (lib.length spendPanelList == 2)
              "ai-meter-spend-promql: the dashboard must keep exactly one panel each for ${toString spendPanelNames}, found ${toString (lib.length spendPanelList)}";
            assert lib.assertMsg (uncovered == [ ])
              "ai-meter-spend-promql: priced models missing from the dashboard's spend-rate queries: ${toString uncovered}";
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
              || fail "the generated PromQL disagrees with the Go cost formula (pkgs/ai-meter/config.go BreakdownCost) on the 900/180/450 at 2/0.5/4 fixture"

            cp -r ${root + "/pkgs/ai-meter"} src
            (
              cd src
              # Pure Go: the module is stdlib-only and the sandbox has no C compiler.
              export HOME=$TMP GOCACHE=$TMP/gocache GOPATH=$TMP/gopath GOTOOLCHAIN=local GOPROXY=off GOFLAGS= CGO_ENABLED=0
              AI_METER_PROMQL_SPEND_RATE_USD_PER_HOUR=${usdPerHour} \
                go test -count=1 -run 'TestEstimateCost' . \
                || { echo "FAIL: ai-meter-spend-promql: EstimateCost disagrees with the ${usdPerHour} USD/hour the PromQL was held to" >&2; exit 1; }
            )

            echo "ok: PromQL and Go price the fixture identically; the dashboard prices ${toString (builtins.attrNames host.costs)}"
            touch $out
          '';
    };
}
