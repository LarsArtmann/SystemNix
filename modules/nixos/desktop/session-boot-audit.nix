# Eval-time guard against the 2026-08-18 black-screen class:
# a user unit reachable from default.target (i.e. pulled into the user-manager
# BOOT transaction — linger starts it before SDDM exists) must never
# Wants=/Requires=/BindsTo= graphical-session.target. Pulling that target
# pre-login starts niri-session-manager (Requires=niri.service) -> a headless
# zombie niri -> SDDM login exits "A niri session is already running" ->
# black screen. Wants= is only safe on units the TARGET itself starts
# (WantedBy=graphical-session.target), because those are never in the boot
# transaction.
#
# The guard builds the user-manager dependency graph at eval time:
#   - pull edges     unit --Wants/Requires/BindsTo--> unit
#   - install edges  target --[Install] WantedBy/RequiredBy--> unit
# from config.systemd.user.* (NixOS shape AND raw-text units) plus every
# home-manager user's systemd.user.* (HM shape), seeds the built-in user
# target chain (default -> basic -> paths/sockets/timers), BFS's from
# default.target, and fails the eval if graphical-session.target is reachable.
# The failure message includes the offending dependency chain.
#
# If a unit legitimately needs to pull the target at boot (none does today),
# add it to services.session-boot-audit.allowedUnits with a comment explaining
# why the boot-transaction hazard does not apply.
{
  flake.nixosModules.session-boot-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.session-boot-audit;

      sessionTargets = [
        "graphical-session.target"
      ];

      splitTokens = value: builtins.filter (t: t != "") (lib.split "[[:space:]]+" value);

      valueToList =
        v:
        if lib.isString v then
          splitTokens v
        else if lib.isList v then
          lib.concatMap (e: if lib.isString e then splitTokens e else [ ]) v
        else
          [ ];

      sectionToList =
        section: keys:
        if section == null || !lib.isAttrs section then
          [ ]
        else
          lib.concatMap (key: valueToList (section.${key} or null)) (
            builtins.filter (key: section ? ${key}) keys
          );

      pullKeys = [
        "Wants"
        "Requires"
        "BindsTo"
      ];
      installKeys = [
        "WantedBy"
        "RequiredBy"
      ];

      # NixOS-shape user units: top-level wants/requires/bindsTo/wantedBy,
      # unitConfig camelCase sections, `enable` gating symlink creation.
      collectNixosUnits =
        kindUnits:
        lib.concatLists (
          lib.mapAttrsToList (
            name: u:
            let
              enabled = u.enable or true;
              unitConfig = u.unitConfig or null;
            in
            lib.optionals enabled [
              {
                inherit name;
                deps =
                  (u.wants or [ ]) ++ (u.requires or [ ]) ++ (u.bindsTo or [ ]) ++ sectionToList unitConfig pullKeys;
                installs = (u.wantedBy or [ ]) ++ (u.requiredBy or [ ]);
              }
            ]
          ) kindUnits
        );

      # Home-Manager-shape user units: nested Unit/Install sections (PascalCase,
      # string-or-list values), optional top-level wantedBy.
      collectHmUnits =
        kindUnits:
        lib.concatLists (
          lib.mapAttrsToList (
            name: u:
            let
              unitSection = u.Unit or null;
              installSection = u.Install or null;
            in
            [
              {
                inherit name;
                deps = sectionToList unitSection pullKeys;
                installs =
                  (if u ? wantedBy then valueToList u.wantedBy else [ ]) ++ sectionToList installSection installKeys;
              }
            ]
          ) kindUnits
        );

      # Raw-text units (config.systemd.user.units.<name>.text): parse the
      # directive lines systemd would see. Limitation: no continuation lines
      # (none of our generated units use them).
      parseUnitText =
        text:
        let
          cleanLines = builtins.filter (l: l != "" && !lib.hasPrefix "#" l && !lib.hasPrefix ";" l) (
            map (l: lib.head (builtins.match "[[:space:]]*(.*)" l)) (
              builtins.filter lib.isString (lib.splitString "\n" text)
            )
          );
          fold =
            acc: line:
            if lib.hasPrefix "[" line then
              acc // { section = lib.substring 1 (lib.stringLength line - 2) line; }
            else
              let
                parts = lib.splitString "=" line;
                key = lib.head parts;
                value = lib.concatStringsSep "=" (lib.tail parts);
                tokens = splitTokens value;
              in
              if acc.section == "Unit" && builtins.elem key pullKeys then
                acc // { deps = acc.deps ++ tokens; }
              else if acc.section == "Install" && builtins.elem key installKeys then
                acc // { installs = acc.installs ++ tokens; }
              else
                acc;
        in
        builtins.foldl' fold {
          section = "";
          deps = [ ];
          installs = [ ];
        } cleanLines;

      collectRawUnits =
        rawUnits:
        lib.concatLists (
          lib.mapAttrsToList (
            name: u:
            let
              parsed = parseUnitText (if u ? text && lib.isString u.text then u.text else "");
              optionInstalls = if u ? wantedBy && u ? enable && u.enable then u.wantedBy else [ ];
            in
            [
              {
                inherit name;
                inherit (parsed) deps;
                installs = parsed.installs ++ optionInstalls;
              }
            ]
          ) rawUnits
        );

      hmUsers =
        if config ? home-manager && config.home-manager ? users then config.home-manager.users else { };

      nixosKinds = [
        config.systemd.user.services
        config.systemd.user.timers
        config.systemd.user.sockets
        config.systemd.user.paths
        config.systemd.user.targets
      ];

      hmKinds = lib.concatLists (
        lib.mapAttrsToList (
          _: hmUser:
          let
            su = if hmUser ? systemd && hmUser.systemd ? user then hmUser.systemd.user else null;
          in
          lib.optionals (su != null) [
            su.services
            su.timers
            su.sockets
            su.paths
            su.targets
          ]
        ) hmUsers
      );

      allUnits =
        (lib.concatMap collectNixosUnits nixosKinds)
        ++ (lib.concatMap collectHmUnits hmKinds)
        ++ (collectRawUnits config.systemd.user.units);

      # Canonical spelling: `foo` (NixOS/HM option key) and `foo.service`
      # (raw systemd.user.units key) are the SAME generated unit. Without
      # this, a split-spelled unit puts its install edge on one node and its
      # pull edge on the other — the chain breaks and the guard misses it
      # (the exact false-negative class the CI negative test locks in).
      # Stripping only .service never merges distinct .target/.socket kinds,
      # and reachability is monotone under merging: the guard can only
      # become MORE sensitive, never blind.
      canonical = name: lib.removeSuffix ".service" name;

      canonicalUnits = map (u: {
        name = canonical u.name;
        deps = map canonical u.deps;
        installs = map canonical u.installs;
      }) allUnits;

      # A unit in allowedUnits may keep its pull edge (documented exception).
      allowed = map canonical cfg.allowedUnits;

      pullEdges = builtins.foldl' (
        acc: unit:
        acc
        // {
          ${unit.name} =
            (acc.${unit.name} or [ ])
            ++ (builtins.filter (
              dep: !(builtins.elem unit.name allowed && builtins.elem dep sessionTargets)
            ) unit.deps);
        }
      ) { } canonicalUnits;

      installEdges = builtins.foldl' (
        acc: unit:
        builtins.foldl' (
          acc2: target: acc2 // { ${target} = (acc2.${target} or [ ]) ++ [ unit.name ]; }
        ) acc unit.installs
      ) { } canonicalUnits;

      # Built-in user-manager target chain (systemd upstream, stable for years):
      # default.target Wants basic.target Wants {paths,sockets,timers}.target.
      seedEdges = {
        "default.target" = [ "basic.target" ];
        "basic.target" = [
          "paths.target"
          "sockets.target"
          "timers.target"
        ];
      };

      edgesOf =
        name: (pullEdges.${name} or [ ]) ++ (installEdges.${name} or [ ]) ++ (seedEdges.${name} or [ ]);

      bfs =
        queue: seen: parents:
        if queue == [ ] then
          parents
        else
          let
            head = builtins.head queue;
            tail = builtins.tail queue;
            successors = builtins.filter (n: !seen ? ${n}) (edgesOf head);
            newSeen = seen // (builtins.listToAttrs (map (n: lib.nameValuePair n true) successors));
            newParents = parents // (builtins.listToAttrs (map (n: lib.nameValuePair n head) successors));
          in
          bfs (tail ++ successors) newSeen newParents;

      parents = bfs [ "default.target" ] { "default.target" = true; } { };

      pathTo = n: if !(parents ? ${n}) then [ n ] else (pathTo parents.${n}) ++ [ n ];

      violatingPaths = builtins.filter (path: builtins.length path > 1) (map pathTo sessionTargets);

      mkMessage =
        path:
        "session-boot-audit: graphical-session.target is reachable from default.target via: "
        + (lib.concatStringsSep " -> " path)
        + ". This pulls the target into the user-manager BOOT transaction (lingering starts it before SDDM exists)"
        + " -> niri-session-manager (Requires=niri.service) -> headless zombie niri -> SDDM login exits"
        + " \"A niri session is already running\" -> black screen (2026-08-18 incident)."
        + " Fix: delete the Wants=/Requires=/BindsTo= graphical-session.target on the offending unit;"
        + " order with After= + a gate that waits for the compositor socket instead (see activitywatch.nix)."
        + " If this is deliberate, add the unit to services.session-boot-audit.allowedUnits with a reason.";
    in
    {
      options.services.session-boot-audit = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Eval-time assertion that no user unit reachable from default.target pulls graphical-session.target into the boot transaction.";
        };

        allowedUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Units allowed to Wants=/Requires= graphical-session.target even when boot-reachable (documented exceptions only).";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = map (path: {
          assertion = false;
          message = mkMessage path;
        }) violatingPaths;
      };
    };
}
