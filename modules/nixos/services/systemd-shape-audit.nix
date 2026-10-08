# Eval-time audit: INVALID or RACY systemd unit SHAPES that systemd itself
# either refuses to load or accepts while silently arming a failure cascade.
#
# Three bug classes, all with live incident history (see docs/agents/systemd.md gotchas):
#
# 1. Type=oneshot + Restart=always/on-success/on-abnormal/on-watchdog
#    systemd REFUSES to load such a unit (service-defaults.nix documents the
#    crash). serviceOneshotDefaults exists precisely to prevent this — the
#    audit catches any regression, incl. hand-rolled `Restart = "always"`
#    merged over a oneshot Type from another fragment.
#
# 2. A unit with a MATCHING TIMER whose service carries Restart != no.
#    The restart-retry and the next timer fire land as two start requests in
#    one rate-limit window; the rejected one still counts against the limit
#    and ONE failed run cascades into a self-re-arming start-limit-hit that
#    blocks runs for hours (browser-history-agent 2026-08-18: 5-min timer +
#    5-min RestartSec + burst 2/1800s → alternating blocked/success fires all
#    day). The timer IS the retry mechanism: Restart=no + a generous
#    short-window burst. Deliberate bounded-retry exceptions (rapid retries
#    that self-extinguish long before the next timer fire) go in
#    services.systemd-shape-audit.allowTimerRestart WITH a justification
#    comment at the definition site.
#
# 3. Path units using PathExists/PathExistsGlob as the trigger.
#    PathExists fires immediately when the file already exists at unit start
#    → re-fire loop → start-limit-hit. Use PathChanged/PathModified
#    (ConditionPathExists is the correct EXISTENCE gate and is not affected).
#
# 4. Literal $HOME in USER unit Exec lines.
#    Hardened user services may not expand $HOME (environment stripped) —
#    the systemd specifier %h is the sanctioned form. A unit that works
#    unhardened silently breaks under hardenUser. Scope: system-declared
#    user units (config.systemd.user.services — the hardenUser consumers);
#    Home-Manager-internal units are evaluated in the HM closure, not here.
#
# 5. Unit-level script options (script/preStart/postStart/…) nested inside
#    serviceConfig. serviceConfig is a FREEFORM attrset serialized verbatim
#    into [Service]: a script nested there renders line-by-line as garbage
#    keys (script=/dst=/src=…), the unit gets NO ExecStart, and systemd
#    REFUSES TO LOAD it — while eval stays green (live incident: crm-backup,
#    unloadable from its 2026-10-03 cutover deploy until 2026-10-07; backups
#    silently never ran, docs/status/2026-10-07_15-50_* §a5/§d1).
#
# 6. The SAME RuntimeDirectory declared by more than one unit. systemd removes
#    a unit's RuntimeDirectory when that unit stops; with two declarers,
#    whichever stops first unlinks the OTHER unit's live files (sockets!)
#    inside it — the other unit keeps running but is unreachable (live
#    incident 2026-10-07: PMA's stale RuntimeDirectory=project-discovery vs
#    the standalone project-discovery-daemon; PMA's deploy-stop flushed the
#    live daemon's socket and overview crash-looped ~26h on its daemon-gate).
#    A runtime dir has exactly ONE owning unit; consumers connect to the
#    socket, they never co-declare the directory.
#
# Assertions are forced by `nix flake check` (pre-commit + CI); a bare
# `nix eval ...toplevel.drvPath` does NOT check them.
{
  flake.nixosModules.systemd-shape-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.systemd-shape-audit;

      invalidOneshotRestarts = [
        "always"
        "on-success"
        "on-abnormal"
        "on-watchdog"
      ];

      # --- class 1: Type=oneshot + invalid Restart ---
      oneshotOffenders =
        let
          bad = lib.filterAttrs (
            _name: svc:
            (svc.serviceConfig.Type or null) == "oneshot"
            && builtins.elem (svc.serviceConfig.Restart or null) invalidOneshotRestarts
          ) config.systemd.services;
        in
        lib.attrNames bad;

      # --- class 2: matching timer + Restart != no ---
      # A timer named X drives service X (systemd timer-unit semantics).
      timerOffenders =
        let
          activeTimers = lib.filterAttrs (_n: t: t.enable) config.systemd.timers;
          driven = lib.filterAttrs (name: _t: config.systemd.services ? ${name}) activeTimers;
          bad = lib.filterAttrs (
            name: _t:
            let
              svc = config.systemd.services.${name};
            in
            (svc.serviceConfig.Restart or null) != null
            && svc.serviceConfig.Restart != "no"
            && !builtins.elem name cfg.allowTimerRestart
          ) driven;
        in
        lib.attrNames bad;

      # --- class 3: Path units triggered by PathExists/PathExistsGlob ---
      pathOffenders =
        let
          bad = lib.filterAttrs (
            _name: p:
            (p.pathConfig ? PathExists && p.pathConfig.PathExists != null)
            || (p.pathConfig ? PathExistsGlob && p.pathConfig.PathExistsGlob != null)
          ) config.systemd.paths;
        in
        lib.attrNames bad;

      # --- class 4: literal $HOME in USER unit Exec lines ---
      # Hardened user services may not expand $HOME (the environment is
      # stripped); the systemd specifier %h is the sanctioned form. A unit
      # that works unhardened silently breaks under hardenUser.
      userExecKeys = [
        "ExecStart"
        "ExecStartPre"
        "ExecStartPost"
        "ExecStop"
        "ExecReload"
        "ExecCondition"
      ];
      homeOffenders =
        let
          bad = lib.filterAttrs (
            _name: svc:
            builtins.any (
              k:
              svc.serviceConfig ? ${k}
              && lib.hasInfix "$HOME" (lib.concatMapStringsSep " " toString (lib.toList svc.serviceConfig.${k}))
            ) userExecKeys
          ) config.systemd.user.services;
        in
        lib.attrNames bad;

      # --- class 5: unit-level script options nested inside serviceConfig ---
      # None of these are real systemd [Service] keys — inside the freeform
      # serviceConfig they serialize as garbage lines, so flagging is
      # false-positive-free by construction.
      unitScriptKeys = [
        "script"
        "preStart"
        "preStop"
        "postStart"
        "postStop"
        "stopScript"
        "reloadScript"
      ];
      scriptInServiceConfigOffenders =
        let
          bad = lib.filterAttrs (
            _name: svc: builtins.any (k: svc.serviceConfig ? ${k}) unitScriptKeys
          ) config.systemd.services;
        in
        lib.attrNames bad;

      # --- class 6: one RuntimeDirectory declared by more than one unit ---
      # RuntimeDirectory accepts a string or a list; normalize both. Empty
      # strings (explicitly cleared via mkForce []) mean "owns nothing" and
      # are skipped.
      sharedRuntimeDirs =
        let
          unitDirs = lib.concatLists (
            lib.mapAttrsToList (
              name: svc:
              let
                dirs = builtins.map toString (lib.toList (svc.serviceConfig.RuntimeDirectory or [ ]));
              in
              lib.optional svc.enable (
                builtins.map (d: {
                  inherit name;
                  dir = d;
                }) (builtins.filter (d: d != "") dirs)
              )
            ) config.systemd.services
          );
        in
        lib.filterAttrs (_dir: owners: builtins.length owners > 1) (
          lib.groupBy (x: x.dir) unitDirs
        );
    in
    {
      options.services.systemd-shape-audit = {
        allowTimerRestart = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Units with a matching timer whose Restart != no is deliberate:
            a bounded rapid-retry (e.g. 3x5s) that self-extinguishes via
            start-limit long before the next timer fire. Every entry MUST
            carry a justification comment where it is set.
          '';
        };
      };

      config.assertions = [
        {
          assertion = oneshotOffenders == [ ];
          message = ''
            systemd-shape-audit: Type=oneshot combined with an invalid Restart for:
            ${lib.concatStringsSep ", " oneshotOffenders}
            systemd only allows Restart = "no" | "on-failure" for oneshot services —
            anything else makes the unit fail to load entirely.
            Fix: use serviceOneshotDefaults (defaults Restart=no) and at most
            Restart = "on-failure". Never merge serviceDefaults (Restart=always)
            into a oneshot unit.
          '';
        }
        {
          assertion = timerOffenders == [ ];
          message = ''
            systemd-shape-audit: timer-driven unit(s) with Restart != no:
            ${lib.concatStringsSep ", " timerOffenders}
            The restart-retry and the next timer fire both count against the start
            rate limit — one failed run cascades into a self-re-arming
            start-limit-hit that blocks runs for hours (browser-history-agent
            2026-08-18). The timer IS the retry mechanism.
            Fix: Restart = "no" + a generous short-window burst, e.g.
              startLimitBurst = 5; startLimitIntervalSec = 300;
            Deliberate bounded-retry exception:
              services.systemd-shape-audit.allowTimerRestart = [ "<unit>" ];
            with a justification comment.
          '';
        }
        {
          assertion = pathOffenders == [ ];
          message = ''
            systemd-shape-audit: path unit(s) triggered by PathExists/PathExistsGlob:
            ${lib.concatStringsSep ", " pathOffenders}
            PathExists fires immediately when the file exists at unit start →
            re-fire loop → start-limit-hit. Use PathChanged/PathModified as the
            trigger. (ConditionPathExists on services is the correct existence
            gate and is NOT flagged.)
          '';
        }
        {
          assertion = homeOffenders == [ ];
          message = ''
            systemd-shape-audit: user unit(s) with a literal $HOME in Exec lines:
            ${lib.concatStringsSep ", " homeOffenders}
            Hardened user services may not expand $HOME (environment stripped).
            Use the systemd specifier %h instead:
              ExecStart = "/bin/app --config %h/.config/app";
          '';
        }
        {
          assertion = scriptInServiceConfigOffenders == [ ];
          message = ''
            systemd-shape-audit: unit-level script option(s) nested inside serviceConfig:
            ${lib.concatStringsSep ", " scriptInServiceConfigOffenders}
            serviceConfig is freeform and serializes verbatim into the [Service]
            section — a script nested there renders line-by-line as garbage keys
            (script=…, dst=…), the unit gets NO ExecStart, and systemd REFUSES
            TO LOAD it while eval stays green (crm-backup, 2026-10-03 →
            2026-10-07: backups silently never ran).
            Fix: hoist script/preStart/postStart/… to the unit TOP LEVEL
            (sibling of path/after); keep only real [Service] keys (Type,
            User, ReadWritePaths, …) inside serviceConfig.
          '';
        }
        {
          assertion = sharedRuntimeDirs == { };
          message = ''
            systemd-shape-audit: RuntimeDirectory declared by more than one unit:
            ${lib.concatStringsSep ", " (
              lib.mapAttrsToList (
                dir: owners: "${dir} (" + lib.concatStringsSep ", " (map (o: o.name) owners) + ")"
              ) sharedRuntimeDirs
            )}
            systemd removes a unit's RuntimeDirectory when that unit stops —
            whichever unit stops first unlinks the OTHER unit's live files
            (sockets) inside it; the other unit keeps running but becomes
            unreachable (2026-10-07 ghost-socket: PMA's stop flushed the live
            project-discovery-daemon socket; overview crash-looped ~26h).
            A runtime dir has exactly ONE owning unit; consumers connect to
            the socket, they never co-declare the directory. Clear the
            non-owner with RuntimeDirectory = lib.mkForce [ ];
          '';
        }
      ];
    };
}
