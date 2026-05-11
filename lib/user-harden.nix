{lib}: {
  MemoryMax ? "512M",
  RestrictNamespaces ? true,
  NoNewPrivileges ? true,
  LockPersonality ? true,
  RestrictSUIDSGID ? true,
  PrivateTmp ? true,
  ProtectHostname ? true,
  ...
}: let
  isOverride = v: builtins.isAttrs v && v ? _type && v._type == "override";
  mkDefault' = v:
    if isOverride v
    then v
    else lib.mkDefault v;
in {
  PrivateTmp = mkDefault' PrivateTmp;
  ProtectHostname = mkDefault' ProtectHostname;
  RestrictSUIDSGID = mkDefault' RestrictSUIDSGID;
  LockPersonality = mkDefault' LockPersonality;
  MemoryMax = mkDefault' MemoryMax;
  RestrictNamespaces = mkDefault' RestrictNamespaces;
  NoNewPrivileges = mkDefault' NoNewPrivileges;
}
