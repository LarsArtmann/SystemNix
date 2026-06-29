{lib}: args @ {
  mode ? "system",
  MemoryMax ? "512M",
  MemoryHigh ? "80%", # Throttle at 80% of MemoryMax before hard kill
  ProtectSystem ? "full",
  ProtectHome ? true,
  ReadWritePaths ? [],
  RestrictNamespaces ? true,
  NoNewPrivileges ? true,
  CapabilityBoundingSet ? "",
  ...
}: let
  isOverride = v: builtins.isAttrs v && v ? _type && v._type == "override";
  mkDefault' = v:
    if isOverride v
    then v
    else lib.mkDefault v;

  shared = {
    PrivateTmp = lib.mkDefault true;
    ProtectHostname = lib.mkDefault true;
    RestrictSUIDSGID = lib.mkDefault true;
    LockPersonality = lib.mkDefault true;
    MemoryMax = mkDefault' MemoryMax;
    MemoryHigh = mkDefault' MemoryHigh;
    RestrictNamespaces = mkDefault' RestrictNamespaces;
    NoNewPrivileges = mkDefault' NoNewPrivileges;
  };

  systemOnly = {
    ProtectClock = lib.mkDefault true;
    ProtectKernelLogs = lib.mkDefault true;
    ProtectSystem = mkDefault' ProtectSystem;
    ProtectHome = mkDefault' ProtectHome;
    ReadWritePaths = mkDefault' ReadWritePaths;
    CapabilityBoundingSet = mkDefault' CapabilityBoundingSet;
  };

  namedKeys = [
    "mode"
    "MemoryMax"
    "MemoryHigh"
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
