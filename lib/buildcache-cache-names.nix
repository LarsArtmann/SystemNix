# Parser for scripts/lib/buildcache-reap-names.sh — the single source of
# truth for the env-less cache reap inventories (deploy.sh pre-switch reap,
# buildcache-usb-recovery step 2.5, home.nix checkLinkTargets activation).
# The shell file keeps deploy.sh consumable without Nix; Nix consumers parse
# it here so the lists can never drift between the shell and Nix surfaces.
# Import: import ../../../lib/buildcache-cache-names.nix lib
lib:
let
  src = builtins.readFile ../scripts/lib/buildcache-reap-names.sh;
  parse =
    name:
    let
      matches = lib.filter (lib.hasPrefix name) (lib.splitString "\n" src);
      line =
        if matches == [ ] then
          throw "scripts/lib/buildcache-reap-names.sh: no assignment for ${name}"
        else
          builtins.head matches;
      m = builtins.match "${name}=\"([^\"]+)\"" line;
    in
    if m == null then
      throw "scripts/lib/buildcache-reap-names.sh: malformed assignment for ${name}: ${line}"
    else
      lib.splitString " " (builtins.head m);
in
{
  # Reaped as ~/.cache/<name>
  cacheDirs = parse "BUILDCACHE_REAP_CACHE_DIRS";
  # Reaped as $HOME/<path>
  homeRelDirs = parse "BUILDCACHE_REAP_HOME_DIRS";
}
