{ lib }:
args@{
  mode ? "system",
  MemoryMax ? "512M",
  MemoryHigh ? null, # Throttle before the hard kill. Default: 80% of MemoryMax.
  CPUQuota ? "200%", # Hard cap: 2 cores. Prevents CPU runaway from code bugs. Override for AI/build services.
  ProtectSystem ? "full",
  ProtectHome ? true,
  ReadWritePaths ? [ ],
  RestrictNamespaces ? true,
  NoNewPrivileges ? true,
  CapabilityBoundingSet ? "",
  ...
}:
let
  isOverride = v: builtins.isAttrs v && v ? _type && v._type == "override";
  mkDefault' = v: if isOverride v then v else lib.mkDefault v;

  # systemd memory percentages resolve against TOTAL PHYSICAL RAM, not against
  # MemoryMax — on a 128G host a literal MemoryHigh = "80%" (~102G) sits far
  # above the default MemoryMax = 512M and the throttle never engages before
  # the hard kill. Derive the default from MemoryMax instead.
  memoryValue =
    v:
    if isOverride v then v.content else v;
  parseMemoryBytes =
    v:
    let
      s = toString (memoryValue v);
      match = builtins.match "([0-9]+)(K|M|G|T)?" s;
      multiplier =
        if match == null then
          null
        else
          {
            K = 1024;
            M = 1024 * 1024;
            G = 1024 * 1024 * 1024;
            T = 1024 * 1024 * 1024 * 1024;
            "" = 1;
          }.${builtins.elemAt match 1};
    in
    if match == null then null else (lib.toInt (builtins.elemAt match 0)) * multiplier;
  defaultMemoryHigh =
    let
      maxBytes = parseMemoryBytes MemoryMax;
    in
    if maxBytes == null then "80%" else toString (maxBytes * 4 / 5);
  memoryHigh = if MemoryHigh == null then defaultMemoryHigh else MemoryHigh;

  shared = {
    PrivateTmp = lib.mkDefault true;
    ProtectHostname = lib.mkDefault true;
    RestrictSUIDSGID = lib.mkDefault true;
    LockPersonality = lib.mkDefault true;
    RestrictRealtime = lib.mkDefault true;
    MemoryMax = mkDefault' MemoryMax;
    MemoryHigh = mkDefault' memoryHigh;
    CPUQuota = mkDefault' CPUQuota;
    RestrictNamespaces = mkDefault' RestrictNamespaces;
    NoNewPrivileges = mkDefault' NoNewPrivileges;
  };

  systemOnly = {
    ProtectClock = lib.mkDefault true;
    ProtectKernelLogs = lib.mkDefault true;
    ProtectKernelTunables = lib.mkDefault true;
    ProtectKernelModules = lib.mkDefault true;
    ProtectControlGroups = lib.mkDefault true;
    SystemCallArchitectures = lib.mkDefault "native";
    ProtectSystem = mkDefault' ProtectSystem;
    ProtectHome = mkDefault' ProtectHome;
    ReadWritePaths = mkDefault' ReadWritePaths;
    CapabilityBoundingSet = mkDefault' CapabilityBoundingSet;
  };

  namedKeys = [
    "mode"
    "MemoryMax"
    "MemoryHigh"
    "CPUQuota"
    "ProtectSystem"
    "ProtectHome"
    "ReadWritePaths"
    "RestrictNamespaces"
    "NoNewPrivileges"
    "CapabilityBoundingSet"
  ];
  passthrough = builtins.removeAttrs args namedKeys;
in
shared // lib.optionalAttrs (mode == "system") systemOnly // passthrough
