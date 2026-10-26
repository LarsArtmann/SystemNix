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
#   2. Implicit edges: a unit in a target's wants/requires gets an implicit
#      Before=<target> (the target's completion waits for its members) —
#      this is what puts plain multi-user-wanted services on the boot
#      critical chain.
#   3. Suppression: the implicit edge is NOT added when an explicit ordering
#      already exists between the pair in either direction (live-verified
#      2026-10-26: the runner fix — wantedBy=forgejo + After=forgejo —
#      restarted cleanly where the unsuppressed implicit edge had armed the
#      cycle). This is the sanctioned "wanted by X but starts after X"
#      idiom; late-applications.target is the graph's single sanctioned
#      carrier of After=multi-user.target.
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
      # Every unit type that participates in start ordering. NOTE:
      # config.systemd.mounts is a LIST upstream (units keyed by `where`
      # elsewhere) — mount units are not modeled; edges to them are dropped.
      unitSets = {
        inherit (config.systemd)
          services
          targets
          timers
          paths
          sockets
          ;
      };

      # unitConfig.* directives may be space-separated strings (systemd
      # verbatim syntax — ai-meter-keys ships unitConfig.After as one);
      # after=/before= attrs are lists by option type but normalize anyway.
      asList =
        x:
        if builtins.isList x then
          x
        else if builtins.isString x then
          lib.filter (v: v != "") (lib.split " " x)
        else
          [ ];

      # unitName -> { after = [...]; before = [...]; } — explicit directives
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
                u = set.${name};
                after = asList (u.after or [ ]) ++ asList (u.unitConfig.After or [ ]);
                before = asList (u.before or [ ]) ++ asList (u.unitConfig.Before or [ ]);
              in
              if (u.enable or true) == false then acc2 else acc2 // { ${name} = { inherit after before; }; }
            ) acc (builtins.attrNames set);
        in
        builtins.foldl' merge { } (builtins.attrValues unitSets);

      # name -> [unitName it must start AFTER] — explicit edges only,
      # restricted to known units, deduped.
      explicitAfterGraph = builtins.mapAttrs (
        name: u:
        let
          strings = xs: builtins.filter builtins.isString xs;
        in
        lib.unique (
          (builtins.filter (x: builtins.hasAttr x explicitGraph && x != name) (strings u.after))
          ++ (builtins.filter (x: builtins.hasAttr x explicitGraph && x != name) (strings u.before))
        )
      ) explicitGraph;

      # wantedBy is NOT reflected into config.systemd.targets.<t>.wants at
      # eval (it only generates install symlinks at build time — proven by
      # the first negative-test leg passing vacuously). Derive memberships
      # from every unit's own wantedBy instead: target -> [member units].
      wantedMemberships =
        let
          add =
            acc: set:
            builtins.foldl' (
              acc2: name:
              let
                u = set.${name};
                wb = asList (u.wantedBy or [ ]);
              in
              if (u.enable or true) == false then
                acc2
              else
                builtins.foldl' (acc3: t: acc3 // { ${t} = (acc3.${t} or [ ]) ++ [ name ]; }) acc2 wb
            ) acc (builtins.attrNames set);
        in
        builtins.foldl' add { } (builtins.attrValues unitSets);

      # Implicit target-membership edges: member m of target T (via
      # wants/requires/wantedBy) → "T after m", unless an explicit ordering
      # between m and T already exists in either direction (suppression).
      targetMemberEdges = lib.mapAttrs (
        tName: t:
        let
          members = lib.unique (
            asList (t.wants or [ ]) ++ asList (t.requires or [ ]) ++ (wantedMemberships.${tName} or [ ])
          );
          tAfter = asList (t.after or [ ]) ++ asList (t.unitConfig.After or [ ]);
          tBefore = asList (t.before or [ ]) ++ asList (t.unitConfig.Before or [ ]);
          explicitPair =
            m:
            builtins.any (a: a == tName) (explicitGraph.${m}.after or [ ])
            || builtins.any (b: b == tName) (explicitGraph.${m}.before or [ ])
            || builtins.elem m tAfter
            || builtins.elem m tBefore;
        in
        builtins.filter (
          m: builtins.isString m && m != tName && builtins.hasAttr m explicitGraph && !explicitPair m
        ) members
      ) config.systemd.targets;

      fullAfterGraph =
        explicitAfterGraph
        // builtins.mapAttrs (
          tName: _explicit: lib.unique (explicitAfterGraph.${tName} ++ (targetMemberEdges.${tName} or [ ]))
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
        }) ((targetMemberEdges."late-applications.target" or [ ]) ++ [ "late-applications.target" ])
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
          members = targetMemberEdges."multi-user.target" or [ ];
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
