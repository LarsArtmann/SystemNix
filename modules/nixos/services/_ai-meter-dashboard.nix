# Renders the ai-meter SigNoz dashboard with its two spend-rate queries
# derived from the reference price table (services.ai-meter.costs).
#
# WHY spend is derived in the query instead of read off
# ai_meter_cost_usd_total: a counter records what was true when it was
# scraped. A model that is used before its price is published (glm-5.4 from
# 2026-11-24) therefore has a zero cost history that no later deploy can
# rewrite, and shipping the price row makes the cumulative counter step,
# which rate() reports as one enormous spike. The token counters were always
# exact, so "tokens x current prices" computed at query time restates the
# whole chart the moment the price row ships, at the true timestamps, with
# no spike and no backfill step.
#
# The formula mirrors the Go one (BreakdownCost in
# pkgs/ai-meter/config.go). Two implementations of one formula drift
# silently, so checks.ai-meter-spend-promql
# (flake/parts/checks/ai-meter-guards.nix) evaluates what this file
# generates against the same fixture the Go test pins, and fails when the
# numbers differ.
{ lib }:
let
  # How a model name is spelled inside the `model=~` selector. It must match
  # literally, and it must parse in BOTH query engines: SigNoz's own PromQL
  # parser rejects the single "\." that promtool and Prometheus accept (live
  # 2026-11-25: "unknown escape sequence U+002E"), which would have shipped
  # two dead panels. So dots become a character class and every other
  # metacharacter a doubled backslash, which both engines read as a literal.
  regexSpecial = lib.strings.stringToCharacters "+*?()|[]{}^$\\";
  escapeRegex =
    name:
    lib.concatMapStrings (
      char:
      if char == "." then
        "[.]"
      else if builtins.elem char regexSpecial then
        "\\\\${char}"
      else
        char
    ) (lib.strings.stringToCharacters name);

  # Tokens per second of one kind for one priced model. The label carries
  # whatever the client asked for; the proxy's price lookup strips one
  # provider prefix ("zai/glm-5.3"), so the selector matches both spellings
  # and the sum collapses client and upstream.
  tokensPerSecond =
    model: kind:
    ''sum by (model) (rate(ai_meter_tokens_total{model=~"(.*/)?${escapeRegex model}",kind="${kind}"}[15m]))'';

  # USD per HOUR for one priced model: the cached subset of the prompt at
  # its own rate, the rest of the prompt at the input rate, completions at
  # the output rate. Prices are USD per 1M tokens, hence the divisor.
  spendPerHour =
    model: price:
    let
      prompt = tokensPerSecond model "prompt";
      cached = tokensPerSecond model "cached";
      completion = tokensPerSecond model "completion";
    in
    "(((${prompt} - ${cached}) * ${toString price.input}"
    + " + ${cached} * ${toString price.cachedInput}"
    + " + ${completion} * ${toString price.output})"
    + " * 3600) / 1000000";

  # The models are unioned with `or` because they carry different model
  # labels: adding them would match nothing, and a priced model without
  # traffic yields no samples at all.
  spendTerms = costs: lib.mapAttrsToList (model: price: spendPerHour model price) costs;

  # USD per hour across every priced model. The trailing vector(0) keeps a
  # number on the panel while no priced model has traffic.
  spendRate =
    costs:
    let
      terms = spendTerms costs;
    in
    if terms == [ ] then "vector(0)" else "sum(${lib.concatStringsSep " or " terms} or vector(0))";

  # USD per hour per priced model.
  spendRateByModel =
    costs:
    let
      terms = spendTerms costs;
    in
    if terms == [ ] then
      "sum by (model) (rate(ai_meter_tokens_total[15m])) * 0"
    else
      lib.concatStringsSep " or " terms;
in
{
  inherit spendRate spendRateByModel;

  # How a model name is spelled inside the generated `model=~` selectors.
  escapeRegex = escapeRegex;

  # Substitutes the spend-rate queries into the dashboard template. Throws
  # when a placeholder is missing or occurs more than once, so a renamed or
  # duplicated panel can never ship an unrendered or ambiguous query.
  render =
    {
      template,
      costs,
    }:
    let
      queries = {
        "@@spendRate@@" = spendRate costs;
        "@@spendRateByModel@@" = spendRateByModel costs;
      };
      occurrences =
        placeholder:
        (lib.stringLength template - lib.stringLength (lib.replaceStrings [ placeholder ] [ "" ] template))
        / lib.stringLength placeholder;
      found = lib.genAttrs (builtins.attrNames queries) (placeholder: occurrences placeholder);
      broken = lib.filterAttrs (_: times: times != 1) found;
      complaint = lib.concatStringsSep ", " (
        lib.mapAttrsToList (placeholder: times: "'${placeholder}' occurs ${toString times} times") broken
      );
      # The query is spliced between the template's own quotes, so it needs
      # a JSON string BODY: toJSON's output minus its surrounding quotes.
      jsonBody =
        promql:
        let
          quoted = builtins.toJSON promql;
        in
        lib.substring 1 (lib.stringLength quoted - 2) quoted;
      rendered = lib.replaceStrings (builtins.attrNames queries) (map jsonBody (
        lib.attrValues queries
      )) template;
    in
    if broken != { } then
      throw "ai-meter dashboard template: each spend placeholder must occur exactly once, but ${complaint}"
    else
      builtins.seq (builtins.fromJSON rendered) rendered;
}
