# Renders the ai-meter SigNoz dashboard with its four spend queries derived
# from the reference price table (services.ai-meter.costs): the spend rate in
# total, per model and per client, and the spend of the last 24 hours.
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

  # The token series of one kind for one priced model. The model label carries
  # whatever the client asked for; the proxy's price lookup strips one
  # provider prefix ("zai/glm-5.3"), so the selector matches both spellings.
  #   by     grouping keys. A priced model never shares a series with another
  #          one, so terms stay distinguishable under `or`.
  #   over   rate (tokens per second) or increase (tokens inside the window).
  #   window the range `over` looks at.
  tokenSeries =
    {
      by ? "model",
      over ? "rate",
      window ? "15m",
      model,
      kind,
    }:
    ''sum by (${by}) (${over}(ai_meter_tokens_total{model=~"(.*/)?${escapeRegex model}",kind="${kind}"}[${window}]))'';

  # USD for one priced model: the cached subset of the prompt at its own
  # rate, the rest of the prompt at the input rate, completions at the output
  # rate. Prices are USD per 1M tokens, hence the divisor. `scale` turns a
  # per-second figure into an hourly one; a window total needs no scaling.
  usdOfTokens =
    {
      by ? "model",
      over ? "rate",
      window ? "15m",
      scale ? 3600,
      model,
      price,
    }:
    let
      series =
        kind:
        tokenSeries {
          inherit
            by
            over
            window
            model
            kind
            ;
        };
    in
    "(((${series "prompt"} - ${series "cached"}) * ${toString price.input}"
    + " + ${series "cached"} * ${toString price.cachedInput}"
    + " + ${series "completion"} * ${toString price.output})"
    + lib.optionalString (scale != 1) " * ${toString scale}"
    + ") / 1000000";

  # One term per priced model.
  spendTerms =
    options: costs:
    lib.mapAttrsToList (model: price: usdOfTokens (options // { inherit model price; })) costs;

  # USD per hour across every priced model. The terms are unioned with `or`
  # because they carry different model labels: adding them would match
  # nothing, and a priced model without traffic yields no samples at all. The
  # trailing vector(0) keeps a number on the panel while no priced model has
  # traffic.
  spendRate =
    costs:
    let
      terms = spendTerms { } costs;
    in
    if terms == [ ] then "vector(0)" else "sum(${lib.concatStringsSep " or " terms} or vector(0))";

  # USD per hour per priced model.
  spendRateByModel =
    costs:
    let
      terms = spendTerms { } costs;
    in
    if terms == [ ] then
      "sum by (model) (rate(ai_meter_tokens_total[15m])) * 0"
    else
      lib.concatStringsSep " or " terms;

  # USD per hour per client (the service holding the key). Every term keeps
  # the client AND the model, so a client that calls two priced models
  # contributes two series to the union, and the outer sum adds them. A plain
  # `or` of per-client totals would keep only the first model's series.
  spendRateByClient =
    costs:
    let
      terms = spendTerms { by = "client, model"; } costs;
    in
    if terms == [ ] then
      "sum by (client) (rate(ai_meter_tokens_total[15m])) * 0"
    else
      "sum by (client) (${lib.concatStringsSep " or " terms})";

  # USD spent in the last 24 hours across every priced model. increase() over
  # the token counters survives the proxy's restarts; the same expression on
  # the cost counter would report a price restatement as spend.
  spendLast24h =
    costs:
    let
      terms = spendTerms {
        over = "increase";
        window = "24h";
        scale = 1;
      } costs;
    in
    if terms == [ ] then "vector(0)" else "sum(${lib.concatStringsSep " or " terms} or vector(0))";
in
{
  inherit
    spendRate
    spendRateByModel
    spendRateByClient
    spendLast24h
    ;

  # How a model name is spelled inside the generated `model=~` selectors.
  escapeRegex = escapeRegex;

  # Substitutes the spend queries into the dashboard template. Throws
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
        "@@spendRateByClient@@" = spendRateByClient costs;
        "@@spendLast24h@@" = spendLast24h costs;
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
