# SigNoz dashboard lint (2026-11-25): a pure validator for the dashboard
# JSON files in modules/nixos/services/dashboards/.
#
# WHY: the provisioner converges dashboards through the SigNoz v2 API and
# fails the deploy on any 400, and the API validates the WHOLE document in
# one call. A layout overlap, a second query on a panel or a PromQL query on
# a table passes every other gate and surfaces at deploy time (2026-09-16
# overview; the first ai-meter rewrite, 2026-11-25, spent a deploy on it).
# This validator encodes the API's rules, read from its source
# (pkg/types/dashboardtypes, pinned rev da35d997), plus four rules of our
# own that the API does not enforce: no orphan panels, known unit ids, the
# server-default keys the provisioner's unchanged-check needs, and titles that
# fit their tile.
#
# It is a pure function: the signoz-query-lint check feeds it the real files,
# signoz-dashboard-lint-selftest feeds it fixtures.
#
#   validateDashboard <file> <doc>   findings for one parsed dashboard
#   findings <dir>                   findings for every *.json in a directory
#   isUnit <id>                      whether a unit id renders
#
# Findings are strings; [] means valid.
{ lib }:
let
  inherit (builtins)
    attrNames
    elemAt
    head
    isAttrs
    isInt
    isList
    isString
    ;
  inherit (lib)
    any
    concatMap
    filter
    flatten
    hasPrefix
    imap0
    length
    mapAttrsToList
    naturalSort
    optional
    range
    stringLength
    ;

  # A malformed file must produce a finding, never a crash. `x.y or default`
  # covers a missing key only: not a JSON null, and not a value of the wrong
  # shape. These four read any document without failing.
  key = set: name: (if isAttrs set then set else { }).${name} or null;
  text = value: if isString value then value else "";
  list = value: if isList value then value else [ ];
  sub = set: name: if isAttrs (key set name) then key set name else { };
  subList = set: name: list (key set name);

  gridColumns = 12;
  maxItemsPerLayout = 100;
  maxTitleLength = 256;
  # A tile two columns wide shows 22 characters of its title at a 1500 px
  # viewport and cuts the rest with an ellipsis (headless render 2026-11-26:
  # 22 fit, 23 and more were cut; a panel's info icon takes its share). The
  # cut always lands on the end: the window or the unit the title names.
  # The limit holds the narrowest viewport the dashboards are read in, 1280 px
  # (the ai-meter viewer's iframe is the whole window; headless render
  # 2026-11-28): there 21 and more are cut, 18 fit only with narrow letters
  # ("Unauthorized (24h)" lost 2 px on the live dashboard) and 17 fit. Wide
  # letters (W, M, m) overflow earlier at any count, so measure a new title.
  narrowTileWidth = 2;
  maxNarrowTileTitle = 17;
  refPrefix = "#/spec/panels/";

  # ── units ──────────────────────────────────────────────────────────────────
  unitLines = filter (line: line != "" && !hasPrefix "#" line) (
    lib.splitString "\n" (builtins.readFile ./signoz-unit-ids.txt)
  );
  unitSet = lib.listToAttrs (
    map (unit: {
      name = unit;
      value = true;
    }) (filter (unit: unit != "") (lib.lists.unique (concatMap (lib.splitString " ") unitLines)))
  );
  # Built at run time by @grafana/data getValueFormat, so no row exists.
  runtimeUnitPrefixes = [
    "prefix:"
    "suffix:"
    "time:"
    "si:"
    "count:"
    "currency:"
    "bool:"
  ];
  isUnit =
    unit:
    isString unit
    && (
      unitSet ? ${unit}
      || any (
        prefix: hasPrefix prefix unit && stringLength unit > stringLength prefix
      ) runtimeUnitPrefixes
    );

  # ── query kinds (allowedQueryKinds, perses_plugin_wrappers.go) ────────────
  builder = "signoz/BuilderQuery";
  aiBuilder = "signoz/AIBuilderQuery";
  composite = "signoz/CompositeQuery";
  formula = "signoz/Formula";
  traceOperator = "signoz/TraceOperator";
  promql = "signoz/PromQLQuery";
  clickhouse = "signoz/ClickHouseSQL";
  everyKind = [
    builder
    aiBuilder
    composite
    formula
    traceOperator
    promql
    clickhouse
  ];
  queryKindsForPanel = {
    "signoz/TimeSeriesPanel" = everyKind;
    "signoz/BarChartPanel" = everyKind;
    "signoz/AreaChartPanel" = everyKind;
    "signoz/NumberPanel" = everyKind;
    "signoz/HistogramPanel" = everyKind;
    # Tables and pie charts never take PromQL, not even inside a composite query.
    "signoz/PieChartPanel" = [
      builder
      aiBuilder
      composite
      formula
      traceOperator
    ];
    "signoz/TablePanel" = [
      builder
      aiBuilder
      composite
      formula
      traceOperator
      clickhouse
    ];
    "signoz/ListPanel" = [
      builder
      aiBuilder
    ];
    "signoz/TextPanel" = [ ];
    "signoz/HeatmapPanel" = [
      builder
      composite
      formula
      promql
      clickhouse
    ];
    "signoz/ScatterPlotPanel" = [
      builder
      composite
      formula
    ];
    "signoz/GeoMapPanel" = [
      builder
      composite
      formula
    ];
    "signoz/TopListPanel" = [
      builder
      composite
      formula
      traceOperator
    ];
  };
  # The `type` of a composite sub-query, as the API maps it to a query kind.
  compositeTypeKinds = {
    builder_query = builder;
    builder_ai_query = aiBuilder;
    builder_formula = formula;
    builder_trace_operator = traceOperator;
    inherit promql;
    clickhouse_sql = clickhouse;
  };
  # Panel kinds whose values carry exactly one unit.
  unitPanels = [
    "signoz/TimeSeriesPanel"
    "signoz/NumberPanel"
    "signoz/PieChartPanel"
  ];

  # ── units of one panel ─────────────────────────────────────────────────────
  unitFindings =
    where: kind: plugin:
    let
      formatting = sub (key plugin "spec") "formatting";
      unit = key formatting "unit";
      thresholds = subList (key plugin "spec") "thresholds";
    in
    (
      if lib.elem kind unitPanels && !isUnit unit then
        [
          "${where}: unit id '${toString unit}' is unknown, so the panel prints the id behind its number; use an id from lib/signoz-unit-ids.txt or a prefix:/suffix:/count:/currency:/time:/si:/bool: form"
        ]
      else
        [ ]
    )
    ++ flatten (
      mapAttrsToList (
        column: columnUnit:
        optional (!isUnit columnUnit)
          "${where}: unit id '${toString columnUnit}' of column '${column}' is unknown (lib/signoz-unit-ids.txt)"
      ) (sub formatting "columnUnits")
    )
    ++ concatMap (
      threshold:
      let
        thresholdUnit = key threshold "unit";
      in
      if !isAttrs threshold then
        [ "${where}: each threshold must be an object" ]
      else
        optional (thresholdUnit != "" && thresholdUnit != null && !isUnit thresholdUnit)
          "${where}: unit id '${toString thresholdUnit}' of a threshold is unknown (lib/signoz-unit-ids.txt)"
    ) thresholds;

  # ── one panel ──────────────────────────────────────────────────────────────
  validatePanel =
    file: panelKey: panel:
    if !isAttrs panel then
      [ "${file}: panel '${panelKey}' must be an object" ]
    else
      let
        spec = sub panel "spec";
        title = text (key (sub spec "display") "name");
        where = "${file}: panel '${if title == "" then panelKey else title}'";
        firstQuery = if isList queries && queries != [ ] then head queries else { };
        plugin = sub (sub firstQuery "spec") "plugin";
        kind = text (key (sub spec "plugin") "kind");
        knownKind = queryKindsForPanel ? ${kind};
        allowed = if knownKind then queryKindsForPanel.${kind} else [ ];
        queries = key spec "queries";
        queryCount = length (list queries);
        pluginKind = text (key plugin "kind");
        subTypes = map (entry: text (key entry "type")) (subList (key plugin "spec") "queries");
        unsupportedSubs = filter (
          type: compositeTypeKinds ? ${type} && !lib.elem compositeTypeKinds.${type} allowed
        ) subTypes;
        queryFindings =
          if !knownKind then
            [
              "${where}: unknown panel kind '${kind}' (add it to queryKindsForPanel in lib/signoz-dashboard-lint.nix)"
            ]
          else if kind == "signoz/TextPanel" then
            (
              if queries == [ ] then
                [ ]
              else
                [
                  "${where}: kind signoz/TextPanel renders without a query and must have queries: []"
                ]
            )
          else if !isList queries then
            [ "${where}: queries are required; a panel must have one query" ]
          else if queryCount != 1 then
            [ "${where}: must have one query, found ${toString queryCount}" ]
          else if !lib.elem pluginKind allowed then
            [ "${where}: query kind '${pluginKind}' is not supported by panel kind '${kind}'" ]
          else
            map (
              type: "${where}: composite sub-query type '${type}' is not supported by panel kind '${kind}'"
            ) unsupportedSubs;
      in
      queryFindings ++ unitFindings where kind (sub spec "plugin");

  # ── layouts ────────────────────────────────────────────────────────────────
  rectanglesOverlap =
    a: b: a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;

  # The geometry rule an item breaks, or null. Mirrors validateGridLayoutGeometry.
  geometryProblem =
    at: item:
    let
      x = key item "x";
      y = key item "y";
      width = key item "width";
      height = key item "height";
    in
    if !isAttrs item then
      "${at}: must be an object"
    else if !(isInt x && isInt y && isInt width && isInt height) then
      "${at}: x, y, width and height must be integers"
    else if width < 1 then
      "${at}: width must be at least 1, got ${toString width}"
    else if height < 1 then
      "${at}: height must be at least 1, got ${toString height}"
    else if x < 0 then
      "${at}: x must not be negative, got ${toString x}"
    else if y < 0 then
      "${at}: y must not be negative, got ${toString y}"
    else if width > gridColumns then
      "${at}: width (${toString width}) exceeds grid width ${toString gridColumns}"
    else if x >= gridColumns then
      "${at}: x (${toString x}) must be less than grid width ${toString gridColumns}"
    else if x + width > gridColumns then
      "${at}: x (${toString x}) + width (${toString width}) exceeds grid width ${toString gridColumns}"
    else
      null;

  # The items of one layout, each with its index.
  itemsOf =
    layout: imap0 (index: item: { inherit index item; }) (subList (sub layout "spec") "items");

  panelKeyOf =
    ref:
    if isString ref && hasPrefix refPrefix ref then
      lib.substring (stringLength refPrefix) (-1) ref
    else
      null;

  validateLayouts =
    file: panels: layouts:
    let
      indexed = imap0 (index: value: { inherit index value; }) layouts;
      # every placed item: its layout index, item index and the panel key it names
      placements = concatMap (
        layout: map (entry: entry // { layout = layout.index; }) (itemsOf layout.value)
      ) indexed;
      keyed = map (
        placement: placement // { panelKey = panelKeyOf (key (sub placement.item "content") "$ref"); }
      ) placements;
      at = placement: "${file}: layouts[${toString placement.layout}] items[${toString placement.index}]";
      known = filter (placement: placement.panelKey != null && panels ? ${placement.panelKey}) keyed;
      placementsPerPanel = lib.foldl' (
        counts: placement: counts // { ${placement.panelKey} = (counts.${placement.panelKey} or 0) + 1; }
      ) { } known;
      referenceFindings =
        concatMap (
          placement:
          let
            ref = key (sub placement.item "content") "$ref";
          in
          if !isAttrs placement.item then
            [ ]
          else if ref == null then
            [ "${at placement}: content reference is required" ]
          else if placement.panelKey == null then
            [ "${at placement}: '${ref}' must reference a panel as ${refPrefix}<key>" ]
          else if !panels ? ${placement.panelKey} then
            [ "${at placement}: references unknown panel '${placement.panelKey}'" ]
          else
            [ ]
        ) keyed
        ++ flatten (
          mapAttrsToList (
            panelKey: count:
            optional (count > 1)
              "${file}: panel '${panelKey}' is placed ${toString count} times; the frontend keys each grid item by its panel, so place it once"
          ) placementsPerPanel
        )
        ++ mapAttrsToList (
          panelKey: _: "${file}: panel '${panelKey}' is placed in no layout, so it never renders"
        ) (removeAttrs panels (lib.lists.unique (map (placement: placement.panelKey) known)));
      layoutFindings = concatMap (
        layout:
        let
          where = "${file}: layouts[${toString layout.index}]";
          kind = text (key layout.value "kind");
          entries = itemsOf layout.value;
          # Overlap is judged between items of valid geometry; a malformed
          # one has its own finding already.
          sound = filter (entry: geometryProblem "" entry.item == null) entries;
        in
        (
          if !isAttrs layout.value then
            [ "${where}: layout must be an object" ]
          else if kind != "Grid" then
            [ "${where}: layout kind '${kind}' is not Grid, the only kind SigNoz accepts" ]
          else
            [ ]
        )
        ++ optional (
          length entries > maxItemsPerLayout
        ) "${where}: has ${toString (length entries)} items; maximum is ${toString maxItemsPerLayout}"
        ++ optional (
          stringLength (text (key (sub (sub layout.value "spec") "display") "title")) > maxTitleLength
        ) "${where}: section title is longer than ${toString maxTitleLength} characters"
        ++ concatMap (
          entry:
          let
            problem = geometryProblem "${where}: items[${toString entry.index}]" entry.item;
          in
          optional (problem != null) problem
        ) entries
        ++ concatMap (
          i:
          concatMap (
            j:
            optional (rectanglesOverlap (elemAt sound i).item (elemAt sound j).item) "${where}: dashboard layout overlap: items[${toString (elemAt sound i).index}] and items[${toString (elemAt sound j).index}] intersect"
          ) (range (i + 1) (length sound - 1))
        ) (range 0 (length sound - 1))
      ) indexed;
      narrowTileTitleFindings = concatMap (
        placement:
        let
          width = key placement.item "width";
          panel =
            if placement.panelKey != null && panels ? ${placement.panelKey} then
              panels.${placement.panelKey}
            else
              { };
          title = text (key (sub (sub panel "spec") "display") "name");
          cut =
            isInt width && width <= narrowTileWidth && title != "" && stringLength title > maxNarrowTileTitle;
        in
        optional cut "${at placement}: panel '${title}' has a ${toString (stringLength title)}-character title on a tile ${toString width} columns wide; the header cuts it with an ellipsis past ${toString maxNarrowTileTitle}, keep a narrow tile's title short"
      ) keyed;
    in
    referenceFindings ++ layoutFindings ++ narrowTileTitleFindings;

  validateDashboard =
    file: doc:
    if !isAttrs doc then
      [ "${file}: not a JSON object" ]
    else
      let
        spec = sub doc "spec";
        panels = sub spec "panels";
        layouts = subList spec "layouts";
        # The provisioner skips a dashboard only when the stored spec equals
        # the file. SigNoz adds these keys on store, so a file without them is
        # re-PUT on every deploy (caddy and gcp until 2026-11-25).
        missingDefaults = filter (name: !(spec ? ${name})) [
          "duration"
          "refreshInterval"
          "links"
        ];
        structure =
          optional (!isAttrs (key doc "spec")) "${file}: spec must be an object"
          ++ optional (text (key doc "name") == "") "${file}: .name (the slug) is required"
          ++ optional (text (key (sub spec "display") "name") == "") "${file}: .spec.display.name is required"
          ++
            optional (missingDefaults != [ ])
              "${file}: spec is missing ${toString missingDefaults}; SigNoz adds them on store, so the stored spec never equals the file and the provisioner re-PUTs the dashboard on every deploy"
          ++ optional (
            !isList (key spec "variables")
          ) "${file}: spec.variables is required and must be a list; use [] for a dashboard without variables"
          ++ optional (!isAttrs (key spec "panels")) "${file}: spec.panels is required and must be an object"
          ++ optional (!isList (key spec "layouts")) "${file}: spec.layouts is required and must be a list";
      in
      naturalSort (
        lib.lists.unique (
          structure
          ++ flatten (mapAttrsToList (panelKey: validatePanel file panelKey) panels)
          ++ validateLayouts file panels layouts
        )
      );

  # Findings for every *.json file of a directory.
  dashboardFindings =
    dir:
    concatMap (name: validateDashboard name (builtins.fromJSON (builtins.readFile "${dir}/${name}"))) (
      naturalSort (filter (name: lib.hasSuffix ".json" name) (attrNames (builtins.readDir dir)))
    );
in
{
  inherit isUnit validateDashboard;

  findings = dashboardFindings;
}
