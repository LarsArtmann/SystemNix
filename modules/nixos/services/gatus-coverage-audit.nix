# Eval-time audit: GATUS MONITORING COVERAGE — the "every service MUST be
# monitored" doctrine, finally ENFORCED instead of remembered.
#
# Two directions over the RESOLVED config (no source greps):
#
#   A. Coverage: every port that is (a) extracted from live unit
#      Exec*/Environment text (same scan as port-registry-audit) AND
#      (b) registered in lib/ports.nix must appear as :<port> in at
#      least one gatus endpoint URL — else the service serves a port
#      nothing watches (silent failures are unacceptable). Only enforced
#      when gatus itself is enabled on the host.
#
#   B. Reverse: every gatus URL that targets LOOPBACK must carry a port
#      registered in lib/ports.nix (external upstream checks such as
#      tcp://dot.mullvad.net:853 are exempt — 853 is Mullvad's port, not
#      ours). Catches registry drift in the monitor itself.
#
# Justified exceptions (with a comment where set):
#   services.gatus-coverage-audit.allowPorts = [ 52625 ];
# Known sanctioned exception classes:
#   - FastFlowLM :52625/:52626 — MUST NOT be probed (each probe holds a
#     connection slot; the 2026-08-18 live incident churned slots and
#     reset real clients). Liveness is asserted via system-health
#     system_service_state_failed metrics instead.
#   - vHost-monitored services (systemd-graph): the gatus check hits
#     https://<sub>.home.lan/ through Caddy, so the backend port never
#     appears in a URL — allowlist the port with that justification.
#
# Assertions are forced by `nix flake check` (pre-commit + CI); a bare
# `nix eval ...toplevel.drvPath` does NOT check them.
{
  flake.nixosModules.gatus-coverage-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.gatus-coverage-audit;

      registeredPorts = builtins.attrValues (import ../../../lib/ports.nix).ports;
      allowed = registeredPorts ++ cfg.allowPorts;

      portRegex = "((127\\.0\\.0\\.1|localhost|0\\.0\\.0\\.0)[: ]([0-9]{2,5})([^0-9]|$))|([^0-9]:([0-9]{2,5})([^0-9a-zA-Z]|$))|(--port[ =]([0-9]{2,5})([^0-9]|$))";
      extractPorts =
        text:
        let
          parts = builtins.split portRegex text;
          digitGroups = builtins.filter (g: builtins.isString g && builtins.match "[0-9]+" g != null) (
            lib.flatten (map (x: if builtins.isList x then x else [ ]) parts)
          );
        in
        lib.unique (builtins.filter (p: p >= 2 && p <= 65535) (map lib.toInt digitGroups));

      scanKeys = [
        "ExecStart"
        "ExecStartPre"
        "ExecStartPost"
        "ExecStop"
        "ExecStopPost"
        "ExecReload"
        "ExecCondition"
      ];
      envToString =
        env:
        if builtins.isAttrs env then
          lib.mapAttrsToList (k: v: "${k}=${toString v}") env
        else
          map toString (lib.toList env);
      unitText =
        svc:
        lib.concatStringsSep " \n " (
          (map (
            k:
            if svc.serviceConfig ? ${k} then
              (lib.concatMapStringsSep " " toString (lib.toList svc.serviceConfig.${k}))
            else
              ""
          ) scanKeys)
          ++ (lib.optionals (svc.serviceConfig ? Environment) (envToString svc.serviceConfig.Environment))
        );

      # (a) in-use ports with owning units, restricted to registered ones
      # (registry membership was already enforced by port-registry-audit;
      # this keeps word:NNN scan residue out of the coverage signal).
      inUseWithOwner =
        let
          gatusEnabled = config.services.gatus.enable or false;
        in
        lib.optionals gatusEnabled (
          lib.concatLists (
            lib.mapAttrsToList (
              name: svc:
              let
                t = builtins.tryEval (unitText svc);
              in
              if !t.success then
                [ ]
              else
                map (p: { port = p; owner = name; }) (
                  builtins.filter (p: builtins.elem p registeredPorts) (extractPorts t.value)
                )
            ) config.systemd.services
          )
        );
      inUsePorts = lib.unique (map (x: x.port) inUseWithOwner);
      owners =
        p:
        lib.concatStringsSep ", " (
          lib.unique (map (x: x.owner) (lib.filter (x: x.port == p) inUseWithOwner))
        );

      gatusEndpoints = config.services.gatus.settings.endpoints or [ ];
      gatusUrls = map (ep: toString (ep.url or "")) gatusEndpoints;

      urlPorts =
        url:
        let
          parts = builtins.split "[:]([0-9]{2,5})([^0-9]|$)" url;
          groups = builtins.filter (g: builtins.isString g && builtins.match "[0-9]+" g != null) (
            lib.flatten (map (x: if builtins.isList x then x else [ ]) parts)
          );
        in
        map lib.toInt groups;
      coveredPorts = lib.unique (lib.concatMap urlPorts gatusUrls);

      # --- class A: in-use but unmonitored ---
      uncovered = lib.subtractLists (coveredPorts ++ cfg.allowPorts) inUsePorts;
      uncoveredReport = map (p: "  ${toString p} (referenced by: ${owners p})") uncovered;

      # --- class B: loopback gatus URLs must use registered ports ---
      loopbackUrlPorts =
        lib.concatLists (
          map (
            url:
            let
              # IPv6 [::1] literals are not matched — POSIX ERE rejects the
              # \[ escape, and no gatus URL in this repo uses IPv6 loopback.
              isLoopback =
                builtins.match "(http|https|tcp)://(127\\.0\\.0\\.1|localhost).*" url != null;
            in
            lib.optionals isLoopback (urlPorts url)
          ) gatusUrls
        );
      unregisteredLoopback = lib.unique (
        lib.subtractLists allowed loopbackUrlPorts
      );

    in
    {
      options.services.gatus-coverage-audit = {
        allowPorts = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
          description = ''
            Ports exempt from the gatus coverage requirement (prohibited-to-probe
            services, vHost-monitored backends). Every entry MUST carry a
            justification comment where it is set.
          '';
        };
      };

      config.assertions =
        let
          gatusEnabled = config.services.gatus.enable or false;
        in
        lib.optionals gatusEnabled [
          {
            assertion = uncovered == [ ];
            message = ''
              gatus-coverage-audit: registered port(s) referenced by live units but never probed by any gatus endpoint:
              ${lib.concatStringsSep "\n" uncoveredReport}
              "Every new service MUST be monitored — silent failures are unacceptable."
              Fix: add a check in gatus-config.nix (mkHttpCheck for HTTP, raw
              attrset for TCP/DNS), or — for a justified exemption (prohibited-to-
              probe socket, vHost-monitored backend) — extend:
                services.gatus-coverage-audit.allowPorts = [ <port> ];
              with a comment explaining why a direct probe is wrong.
            '';
          }
          {
            assertion = unregisteredLoopback == [ ];
            message = ''
              gatus-coverage-audit: loopback gatus URL(s) use unregistered port(s):
              ${lib.concatStringsSep ", " (map toString unregisteredLoopback)}
              Ports OUR services serve must live in lib/ports.nix so collisions
              are caught at eval time. External upstream checks (dot.mullvad.net,
              1.1.1.1, ...) are exempt by design.
            '';
          }
        ];
    };
}
