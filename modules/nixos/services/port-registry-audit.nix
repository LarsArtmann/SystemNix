# Eval-time audit: every TCP port literal in systemd unit text must be a
# value from lib/ports.nix — the "never hardcode localhost:PORT" Critical
# Rule, finally ENFORCED instead of remembered.
#
# Why this exists: port collisions and forgotten ports are the "missing
# config" class. lib/default.nix already throws on duplicate VALUES within
# the registry (port-uniqueness), but NOTHING checked the other half — that
# ports actually USED by services are IN the registry. A new service wiring
# `127.0.0.1:8150` inline collides with nothing at eval time and is only
# discovered at runtime.
#
# What is scanned per service: Exec{Start,StartPre,StartPost,Stop,StopPost,
# Reload,Condition} and Environment (list or attrset form), stringified.
# Extraction forms (mirrors how this repo actually writes ports):
#   host-form   127.0.0.1:8099 / localhost 25 / 0.0.0.0:53
#   colon-form  <non-alnum>:<digits>   (listen=:8100, http://host:8080/x)
#   flag-form   --port 8100 / --port=8100
# Deliberately NOT scanned: EnvironmentFile contents, Caddy/gatus/compose
# configs (own modules), anything inside script bodies (opaque).
#
# Justified exceptions (upstream-owned units etc.):
#   services.port-registry-audit.allowPorts = [ 8150 ];  # + comment why
#
# Non-goals: UDP ranges written space-separated, ports in nested config
# files. This is a regression guard over the dominant literal forms, not a
# total net — a port that slips past every form is invisible to this audit,
# never a false alarm.
{
  flake.nixosModules.port-registry-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.port-registry-audit;

      registeredPorts = builtins.attrValues (import ../../../lib/ports.nix).ports;
      allowedPorts = registeredPorts ++ cfg.allowPorts;

      scanKeys = [
        "ExecStart"
        "ExecStartPre"
        "ExecStartPost"
        "ExecStop"
        "ExecStopPost"
        "ExecReload"
        "ExecCondition"
      ];

      # host-form | colon-form | flag-form (see header). Leading class
      # excludes digits (clock times "2:30", uid:gid never match); trailing
      # boundary for the colon-form excludes letters so model-tag lookalikes
      # ("qwen3.6-moe:35b-a3b" — live false positive on first deploy of this
      # guard) never match; a port is followed by a non-alphanumeric or EOL.
      portRegex = "((127\\.0\\.0\\.1|localhost|0\\.0\\.0\\.0)[: ]([0-9]{2,5})([^0-9]|$))|([^0-9]:([0-9]{2,5})([^0-9a-zA-Z]|$))|(--port[ =]([0-9]{2,5})([^0-9]|$))";

      extractPorts =
        text:
        let
          parts = builtins.split portRegex text;
          digitGroups =
            builtins.filter (g: builtins.isString g && builtins.match "[0-9]+" g != null)
              (lib.flatten (map (x: if builtins.isList x then x else [ ]) parts));
        in
        lib.unique (builtins.filter (p: p >= 2 && p <= 65535) (map lib.toInt digitGroups));

      envToString =
        env:
        if builtins.isAttrs env then
          lib.mapAttrsToList (k: v: "${k}=${toString v}") env
        else
          map toString (lib.toList env);

      unitText =
        svc:
        lib.concatStringsSep " \n "
          (
            (map (k: if svc.serviceConfig ? ${k} then (lib.concatMapStringsSep " " toString (lib.toList svc.serviceConfig.${k})) else "") scanKeys)
            ++ (lib.optionals (svc.serviceConfig ? Environment) (envToString svc.serviceConfig.Environment))
          );

      # tryEval: a unit whose Exec text cannot be coerced (exotic
      # self-referential config) must never break eval — it is skipped.
      offenders = lib.filterAttrs (
        name: svc:
        let
          text = builtins.tryEval (unitText svc);
          unregistered =
            if !text.success then [ ] else lib.subtractLists allowedPorts (extractPorts text.value);
        in
        unregistered != [ ]
      ) config.systemd.services;

      offenderReport = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: svc:
          let
            text = builtins.tryEval (unitText svc);
            unregistered = lib.subtractLists allowedPorts (extractPorts text.value);
          in
          "  ${name}: ${lib.concatStringsSep ", " (map toString unregistered)}"
        ) offenders
      );
    in
    {
      options.services.port-registry-audit = {
        allowPorts = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
          description = ''
            Port numbers exempt from the registry requirement (upstream-owned
            units, protocol-fixed ports that do not belong in lib/ports.nix).
            Every entry MUST carry a justification comment where it is set.
          '';
        };
      };

      config.assertions = [
        {
          assertion = offenders == { };
          message = ''
            port-registry-audit: port literal(s) not registered in lib/ports.nix:
            ${offenderReport}
            Every port a service binds or dials must live in lib/ports.nix so
            collisions are caught at eval time and the port map stays complete.
            Fix: add the port to lib/ports.nix and reference it, or — for a
            justified exemption — extend:
              services.port-registry-audit.allowPorts = [ <port> ];
            with a comment explaining why it must stay out of the registry.
          '';
        }
      ];
    };
}
