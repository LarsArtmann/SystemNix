# Throwaway probe (never deployed): walks the REAL evo-x2 config and reports
# findings for the four unguarded bug classes, without asserting anything.
# usage: nix eval --impure --json .#probeAudit
{
  inputs,
  ...
}:
let
  lib = inputs.nixpkgs.lib;
  system = "x86_64-linux";
  flake = builtins.getFlake (toString ./.);
  host = flake.nixosConfigurations.evo-x2;
  cfg = host.config;

  portsLib = import ./lib/ports.nix;
  registeredPorts = builtins.attrValues portsLib.ports;

  svcNames = builtins.attrNames cfg.systemd.services;

  # --- class 1: Type=oneshot + invalid Restart ---
  oneshotBadRestart = lib.filter (
    name:
    let s = cfg.systemd.services.${name}; in
    (s.serviceConfig.Type or null) == "oneshot"
    && builtins.elem (s.serviceConfig.Restart or null) [ "always" "on-success" "on-abnormal" "on-watchdog" ]
  ) svcNames;

  # --- class 2: timer-driven + Restart != no (the start-limit race class) ---
  timerNames = builtins.attrNames cfg.systemd.timers;
  timerDriven = builtins.filter (name: cfg.systemd.timers.${name}.enable or false) timerNames;
  # a timer named X drives service X
  timerRestartRace = lib.filter (
    name:
    let
      timer = cfg.systemd.timers.${name};
      svc = cfg.systemd.services.${name} or null;
    in
    svc != null
    && (svc.serviceConfig.Restart or "no") != "no"
    && ((svc.serviceConfig.Type or null) == "oneshot")
  ) timerDriven;

  # --- class 3: path units using PathExists / PathExistsGlob ---
  pathUnits = lib.filterAttrs (
    name: p:
    (p.pathConfig ? PathExists && p.pathConfig.PathExists != null)
    || (p.pathConfig ? PathExistsGlob && p.pathConfig.PathExistsGlob != null)
  ) cfg.systemd.paths;

  # --- class 4: hardcoded port literals in unit text ---
  scanKeys = [
    "ExecStart" "ExecStartPre" "ExecStartPost" "ExecStop" "ExecStopPost" "ExecReload" "ExecCondition"
  ];
  portRegex = "(127\\.0\\.0\\.1|localhost|0\\.0\\.0\\.0|\\[::1\\])[: ]([0-9]{2,5})|[^0-9a-zA-Z]:([0-9]{2,5})([^0-9]|$)|--port[ =]([0-9]{2,5})";

  extractPorts = text:
    let
      matches = builtins.match ".*(${portRegex}).*" text;
      # match returns groups for first occurrence only; use split for all
      parts = builtins.split portRegex text;
      groups = builtins.filter builtins.isString (map (x: if builtins.isList x then (builtins.head (builtins.filter (g: g != null) x)) else null) parts);
    in
    map lib.toInt (builtins.filter (p: p != null && p >= 2 && p <= 65535) groups);

  unitText = name:
    let s = cfg.systemd.services.${name}.serviceConfig; in
    lib.concatStringsSep " "
      ((map (k: if s ? ${k} then (lib.concatMapStringsSep " " toString (lib.toList s.${k})) else "") scanKeys)
      ++ (lib.optionals (s ? Environment)
          (if builtins.isAttrs s.Environment
           then (lib.mapAttrsToList (k: v: "${k}=${toString v}") s.Environment)
           else map toString (lib.toList s.Environment))));

  portOffenders = lib.filterAttrs (
    name: _:
    let
      text = builtins.tryEval (unitText name);
      found = if text.success then (lib.subtractLists registeredPorts (lib.unique (extractPorts text.value))) else [];
    in
    found != []
  ) cfg.systemd.services;

in
{
  oneshotBadRestart = oneshotBadRestart;
  timerRestartRace = timerRestartRace;
  pathExistsUnits = builtins.attrNames pathUnits;
  portOffenders = builtins.attrNames portOffenders;
}
