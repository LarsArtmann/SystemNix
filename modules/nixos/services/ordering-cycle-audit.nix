# ordering-cycle-audit: fail eval on ANY ordering cycle in the composed
# systemd start graph — the eval-time gate for the 2026-10-26 gitea-runner
# class (systemd "Found ordering cycle ... Job deleted to break ordering
# cycle" silently removes start jobs from boot/switch transactions; the
# runner was dead ~11h on 2026-10-25 and again 2026-10-26, geometrikks +
# crowdsec-bouncer-register followed at the gen-954 switch).
#
# The graph models systemd's ACTUAL transaction semantics:
#   1. Explicit edges: after=/before= (attr-level and unitConfig-level —
#      both render into [Unit] After=/Before=).
#   2. Implicit edges: a unit in a target's wants/requires/wantedBy gets an
#      implicit Before=<target> (the target's completion waits for its
#      members) — this is what puts plain multi-user-wanted services on the
#      boot critical chain. wantedBy is NOT reflected into
#      config.systemd.targets.<t>.wants at eval (install symlinks are a
#      build-time artifact — the first negative-test leg passed vacuously
#      before memberships were derived from each unit's own wantedBy).
#   3. Suppression: the implicit edge is NOT added when an explicit ordering
#      already exists between the pair in either direction (live-verified
#      2026-10-26: the runner fix — wantedBy=forgejo + After=forgejo —
#      restarted cleanly where the unsuppressed implicit edge had armed the
#      cycle). This is the sanctioned "wanted by X but starts after X"
#      idiom; late-applications.target is the graph's single sanctioned
#      carrier of After=multi-user.target.
#
# NAMES: config.systemd.* keys are suffix-less ("forgejo") while every
# directive value is a full unit name ("forgejo.service") — all nodes and
# edges are normalized to FULL unit names, and directive refs without a
# known suffix are resolved by appending the unit-type suffixes.
#
# Edges to units absent from config.systemd.* (foreign/typo names) are
# dropped: they cannot participate in a cycle systemd would break.
{
  flake.nixosModules.ordering-cycle-audit =
    {
      config,
      lib,
      ...
    }:
    let
      suffixes = [
        ".service"
        ".target"
        ".timer"
        ".path"
        ".socket"
      ];
      hasKnownSuffix = n: builtins.any (s: lib.hasSuffix s n) suffixes;

      # setName -> unit suffix for config.systemd.<setName> keys.
      unitSets = {
        services = {
          suffix = ".service";
          units = config.systemd.services;
        };
        targets = {
          suffix = ".target";
          units = config.systemd.targets;
        };
        timers = {
          suffix = ".timer";
          units = config.systemd.timers;
        };
        paths = {
          suffix = ".path";
          units = config.systemd.paths;
        };
        sockets = {
          suffix = ".socket";
          units = config.systemd.sockets;
        };
      };

      # unitConfig.* directives may be space-separated strings (systemd
      # verbatim syntax — ai-meter-keys ships unitConfig.After as one);
      # after=/before= attrs are lists by option type but normalize anyway.
      asList =
        x:
        if builtins.isList x then
          x
        else if builtins.isString x then
          builtins.filter (v: v != "") (builtins.split " " x)
        else
          [ ];

      # fullName -> { after = [...]; before = [...]; } — explicit directives
      # only, ENABLED units only (disabled units keep their attr with
      # enable=false but never exist at runtime — modeling them creates
      # phantom cycles).
      explicitGraph =
        let
          merge =
            acc: set:
            builtins.foldl' (
              acc2: name:
              let
                u = set.units.${name};
                full = if hasKnownSuffix name then name else name + set.suffix;
                after = asList (u.after or [ ]) ++ asList (u.unitConfig.After or [ ]);
                before = asList (u.before or [ ]) ++ asList (u.unitConfig.Before or [ ]);
              in
              if (u.enable or true) == false then acc2 else acc2 // { ${full} = { inherit after before; }; }
            ) acc (builtins.attrNames set.units);
        in
        builtins.foldl' merge { } (builtins.attrValues unitSets);

      # Resolve a directive ref to a known node, appending unit-type
      # suffixes when the ref is suffix-less ("forgejo" -> "forgejo.service").
      resolve =
        ref:
        if explicitGraph ? ${ref} then
          ref
        else
          let
            candidates = builtins.filter (s: explicitGraph ? ${ref + s}) suffixes;
          in
          if candidates == [ ] then ref else ref + builtins.head candidates;

      # fullName -> [fullName it must start AFTER] — explicit edges only,
      # resolved, restricted to known units, deduped. before= is the REVERSE
      # direction: "U before X" means X waits for U, so U lands in X's
      # after-list (folding before= into U's OWN after-list inverts every
      # such edge — the ai-meter-keys false cycle class).
      explicitAfterGraph =
        let
          strings = xs: builtins.filter builtins.isString xs;
          direct = builtins.mapAttrs (
            name: u:
            lib.unique (builtins.filter (x: x != name && explicitGraph ? ${x}) (map resolve (strings u.after)))
          ) explicitGraph;
          addReversals =
            acc: name:
            let
              u = explicitGraph.${name};
            in
            builtins.foldl' (
              acc2: b:
              let
                rb = resolve b;
              in
              if explicitGraph ? ${rb} && rb != name then
                acc2 // { ${rb} = lib.unique ((acc2.${rb} or [ ]) ++ [ name ]); }
              else
                acc2
            ) acc (strings u.before);
        in
        builtins.foldl' addReversals direct (builtins.attrNames explicitGraph);

      # target -> [member units] from every unit's own wantedBy (enabled
      # units only). Full names on both sides by construction.
      wantedMemberships =
        let
          add =
            acc: set:
            builtins.foldl' (
              acc2: name:
              let
                u = set.units.${name};
                full = if hasKnownSuffix name then name else name + set.suffix;
                wb = asList (u.wantedBy or [ ]);
              in
              if (u.enable or true) == false then
                acc2
              else
                builtins.foldl' (acc3: t: acc3 // { ${t} = (acc3.${t} or [ ]) ++ [ full ]; }) acc2 wb
            ) acc (builtins.attrNames set.units);
        in
        builtins.foldl' add { } (builtins.attrValues unitSets);

      # Implicit target-membership edges: member m of target T (via
      # wants/requires/wantedBy) → "T after m", unless an explicit ordering
      # between m and T already exists in either direction (suppression).
      targetMemberEdges =
        let
          targets = config.systemd.targets;
        in
        lib.mapAttrs (
          rawName: t:
          let
            tName = if hasKnownSuffix rawName then rawName else rawName + ".target";
            rawMembers =
              asList (t.wants or [ ]) ++ asList (t.requires or [ ]) ++ (wantedMemberships.${tName} or [ ]);
            members = map resolve (builtins.filter builtins.isString rawMembers);
            tAfter = map resolve (asList (t.after or [ ]) ++ asList (t.unitConfig.After or [ ]));
            tBefore = map resolve (asList (t.before or [ ]) ++ asList (t.unitConfig.Before or [ ]));
            explicitPair =
              m:
              builtins.any (a: a == tName) (explicitGraph.${m}.after or [ ])
              || builtins.any (b: b == tName) (explicitGraph.${m}.before or [ ])
              || builtins.elem m tAfter
              || builtins.elem m tBefore;
          in
          builtins.filter (m: m != tName && explicitGraph ? ${m} && !explicitPair m) members
        ) targets;

      fullAfterGraph =
        explicitAfterGraph
        // builtins.mapAttrs (
          rawName: _explicit:
          let
            tName = if hasKnownSuffix rawName then rawName else rawName + ".target";
          in
          lib.unique (explicitAfterGraph.${tName} ++ (targetMemberEdges.${rawName} or [ ]))
        ) config.systemd.targets;

      # DFS cycle detection. visit returns { cycle; visited; } — cycle is a
      # path [a b ... a] (non-empty stops exploration), visited accumulates the
      # explored subtree so siblings and later roots skip it (O(V+E)).
      findCycle =
        let
          visit =
            node: path: grey: black:
            let
              nexts = fullAfterGraph.${node};
              step =
                acc: n:
                if acc.cycle != [ ] then
                  acc
                else if grey ? ${n} then
                  acc // { cycle = path ++ [ n ]; }
                else if black ? ${n} || acc.visited ? ${n} then
                  acc
                else
                  let
                    sub = visit n (path ++ [ n ]) (grey // { ${n} = true; }) black;
                  in
                  {
                    inherit (sub) cycle;
                    visited = acc.visited // sub.visited;
                  };
            in
            builtins.foldl' step {
              cycle = [ ];
              visited = {
                ${node} = true;
              };
            } nexts;

          iterate =
            black: rootList:
            if rootList == [ ] then
              [ ]
            else
              let
                r = builtins.head rootList;
                rest = builtins.tail rootList;
              in
              if black ? ${r} then
                iterate black rest
              else
                let
                  sub = visit r [ r ] { ${r} = true; } black;
                in
                if sub.cycle != [ ] then sub.cycle else iterate (black // sub.visited) rest;
        in
        iterate { } (builtins.attrNames fullAfterGraph);

      cycle = findCycle;

      # Second class (found 2026-10-26 while designing the class fix): a
      # multi-user-wanted unit that transitively Afters a late-applications
      # member drags that member's readiness wait back into the boot
      # transaction. Not a cycle (the member has no backward edge) — but the
      # boot-blocking shape the 2026-10-18 audit existed to prevent
      # (miniflux 91s on the boot-0 critical chain). Such units belong in
      # late-applications themselves.
      lateSet = builtins.listToAttrs (
        map (m: {
          name = m;
          value = true;
        }) ((targetMemberEdges."late-applications" or [ ]) ++ [ "late-applications.target" ])
      );

      reachSet =
        start:
        let
          go =
            frontier: acc:
            if frontier == [ ] then
              acc
            else
              let
                n = builtins.head frontier;
                nexts = builtins.filter (x: !acc ? ${x}) (fullAfterGraph.${n} or [ ]);
              in
              go (builtins.tail frontier ++ nexts) (
                acc
                // (builtins.listToAttrs (
                  map (x: {
                    name = x;
                    value = true;
                  }) nexts
                ))
              );
        in
        go [ start ] { ${start} = true; };

      bootBlockers =
        let
          members = targetMemberEdges."multi-user" or [ ];
          offender =
            m:
            let
              reachable = lib.filter (r: lateSet ? ${r}) (builtins.attrNames (reachSet m));
            in
            if reachable == [ ] then [ ] else [ "${m} (after -> ${lib.concatStringsSep " " reachable})" ];
        in
        builtins.concatMap offender members;
    in
    {
      config = {
        assertions = [
          {
            assertion = cycle == [ ];
            message = "ordering-cycle-audit: ordering cycle in the systemd start graph: ${lib.concatStringsSep " -after-> " cycle} — systemd deletes start jobs to break such cycles at boot/switch (the 2026-10-26 gitea-runner/geometrikks/crowdsec class: units silently never start). Units that must start AFTER the boot transaction belong in wantedBy = [ \"late-applications.target\" ] (modules/nixos/services/late-applications.nix), never in after = [ \"multi-user.target\" ] while anything multi-user-wanted orders after them.";
          }
          {
            assertion = bootBlockers == [ ];
            message = "ordering-cycle-audit: multi-user-wanted units transitively ordered after late-applications members drag their readiness waits back into the boot transaction (the 2026-10-18 miniflux-91s critical-chain class): ${lib.concatStringsSep "; " bootBlockers}. Move them to wantedBy = [ \"late-applications.target\" ] (modules/nixos/services/late-applications.nix).";
          }
        ];
      };
    };
}
