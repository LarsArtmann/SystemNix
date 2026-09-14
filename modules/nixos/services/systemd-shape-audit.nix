# Eval-time audit: INVALID or RACY systemd unit SHAPES that systemd itself
# either refuses to load or accepts while silently arming a failure cascade.
#
# Three bug classes, all with live incident history (see AGENTS.md gotchas):
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
      ];
    };
}
