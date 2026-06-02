{
  flake,
  lib,
}: let
  nixosConfig = flake.nixosConfigurations."evo-x2".config;

  stripPrefixes = s:
    if lib.hasPrefix "+-" s
    then lib.removePrefix "+-" s
    else if lib.hasPrefix "+" s
    then lib.removePrefix "+" s
    else if lib.hasPrefix "-" s
    then lib.removePrefix "-" s
    else s;

  extractBinPath = line: let
    m = builtins.match "([^[:space:]]+).*" (stripPrefixes line);
  in
    if m == null
    then null
    else builtins.head m;

  execFields = ["ExecStart" "ExecStartPre" "ExecStartPost" "ExecStop" "ExecReload"];

  getExecValues = svc:
    lib.concatLists (map (
        field: let
          raw = svc.serviceConfig.${field} or null;
        in
          if raw == null
          then []
          else let
            items =
              if builtins.isList raw
              then lib.filter (x: x != null && builtins.isString x) raw
              else lib.filter builtins.isString [raw];
          in
            lib.filter (x: x.path != null)
            (map (item: {
                inherit field;
                path = extractBinPath item;
              })
              items)
      )
      execFields);

  entries = lib.concatLists (
    lib.mapAttrsToList (
      name: svc:
        map (entry: entry // {inherit name;}) (getExecValues svc)
    )
    nixosConfig.systemd.services
  );

  storePaths =
    lib.filter (p: lib.hasPrefix "/nix/store/" p)
    (map (e: e.path) entries);
in
  builtins.toJSON {
    total = builtins.length storePaths;
    paths = builtins.map builtins.unsafeDiscardStringContext storePaths;
  }
