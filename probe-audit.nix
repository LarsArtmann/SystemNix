# Throwaway probe (never deployed): walks the REAL evo-x2 config and reports
# findings for the four unguarded bug classes, without asserting anything.
# usage: nix eval --impure --json --expr 'import ./probe-audit.nix'
let
  flake = builtins.getFlake (toString ./.);
  lib = flake.inputs.nixpkgs.lib;
  cfg = flake.nixosConfigurations.evo-x2.config;

  portsLib = import ./lib/ports.nix;
  registeredPorts = builtins.attrValues portsLib.ports;

  svcNames = builtins.attrNames cfg.systemd.services;

  oneshotBadRestart = lib.filter (
    name:
    let
      s = cfg.systemd.services.${name};
    in
    (s.serviceConfig.Type or null) == "oneshot"
    && builtins.elem (s.serviceConfig.Restart or null) [
      "always"
      "on-success"
      "on-abnormal"
      "on-watchdog"
    ]
  ) svcNames;

  timerDriven = builtins.filter (name: cfg.systemd.timers.${name}.enable or false) (
    builtins.attrNames cfg.systemd.timers
  );
  timerRestartRace = lib.filter (
    name:
    let
      svc = cfg.systemd.services.${name} or null;
    in
    svc != null
    && (svc.serviceConfig.Restart or "no") != "no"
    && (
      (svc.serviceConfig.Type or null) == "oneshot" || svc.serviceConfig.Restart or "no" == "on-failure"
    )
  ) timerDriven;

  pathExistsUnits = lib.filterAttrs (
    name: p:
    (p.pathConfig ? PathExists && p.pathConfig.PathExists != null)
    || (p.pathConfig ? PathExistsGlob && p.pathConfig.PathExistsGlob != null)
  ) cfg.systemd.paths;

  scanKeys = [
    "ExecStart"
    "ExecStartPre"
    "ExecStartPost"
    "ExecStop"
    "ExecStopPost"
    "ExecReload"
    "ExecCondition"
  ];
  portRegex = "((127\\.0\\.0\\.1|localhost|0\\.0\\.0\\.0)[: ]([0-9]{2,5}))|([^0-9a-zA-Z]:([0-9]{2,5})([^0-9]|$))|(--port[ =]([0-9]{2,5}))";

  extractPorts =
    text:
    let
      parts = builtins.split portRegex text;
      digitGroups = builtins.filter (g: builtins.isString g && builtins.match "[0-9]+" g != null) (
        lib.flatten (map (x: if builtins.isList x then x else [ ]) parts)
      );
    in
    builtins.filter (p: p >= 2 && p <= 65535) (map lib.toInt digitGroups);

  unitText =
    name:
    let
      s = cfg.systemd.services.${name}.serviceConfig;
    in
    lib.concatStringsSep " \n " (
      (map (
        k: if s ? ${k} then (lib.concatMapStringsSep " " toString (lib.toList s.${k})) else ""
      ) scanKeys)
      ++ (lib.optionals (s ? Environment) (
        if builtins.isAttrs s.Environment then
          (lib.mapAttrsToList (k: v: "${k}=${toString v}") s.Environment)
        else
          map toString (lib.toList s.Environment)
      ))
    );

  portFindings =
    lib.mapAttrs
      (
        name: _:
        let
          text = builtins.tryEval (unitText name);
          found =
            if text.success then
              (lib.subtractLists registeredPorts (lib.unique (extractPorts text.value)))
            else
              [ ];
        in
        found
      )
      (
        lib.filterAttrs (
          name: _:
          let
            text = builtins.tryEval (unitText name);
            found =
              if text.success then
                (lib.subtractLists registeredPorts (lib.unique (extractPorts text.value)))
              else
                [ ];
          in
          found != [ ]
        ) cfg.systemd.services
      );
in
{
  oneshotBadRestart = oneshotBadRestart;
  timerRestartRace = timerRestartRace;
  pathExistsUnits = builtins.attrNames pathExistsUnits;
  portOffenders = portFindings;
}
