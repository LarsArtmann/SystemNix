# FEATURES enable-drift audit (2026-10-25, fleet-stabilization F11-F13;
# implements the [ready] pipeline.md:631 row the 03-42 plan queued as W1).
#
# The forgejo-repos class: a FEATURES service row carried ✅ for 27 days
# while the module's `enable` was false (caught only by the 2026-10-24 U2
# manual sweep). This audit is the standing gate: it re-derives enable
# truth from eval and compares every FEATURES row that cites a module file.
#
# Pure function — the flake-level check (flake/parts/checks/
# features-drift.nix) supplies eval-derived inputs; the selftest supplies
# fixtures. No hardcoded names on either side.
#
# Row model (FEATURES service tables): `| label | status | \`file.nix\` | … |`
# where the file cell is a STANDALONE backticked .nix path (short form
# `caddy.nix` or full `modules/nixos/services/caddy.nix`). Status semantics
# per the FEATURES legend: ✅ = fully functional (must be enable=true),
# 🔧 = code exists, disabled (enable=false), 🚫 = removed (enable=false,
# usually cited with a dead file that never maps). Rows with other emojis
# (📋 etc.) are not lifecycle claims and are skipped.
#
# Mapping rules (measured 2026-10-25: 93/131 modules map exactly, 10 map
# ambiguously by prefix, 28 declare no services.<name>.enable):
#   exact:     stem(file) == namespace            -> guarded
#   prefix:    exactly ONE namespace stem.*       -> guarded
#   ambiguous: 2+ prefix matches (attic->2 …)     -> skipped, counted
#   unmapped:  no namespace                       -> skipped, counted
#
# Returns { violations; guarded; skippedAmbiguous; skippedUnmapped; rows }
# (violations = list of strings, [] = green).
{
  text,
  # filenames of OUR module files (e.g. [ "caddy.nix" "monitor365.nix" … ])
  moduleFiles,
  # attrset namespace -> enable truth (e.g. { caddy = true; … }) covering
  # every services.<ns> that HAS an enable option
  enabledMap,
}:
let
  stems = map (f: builtins.head (builtins.match "(.*)[.]nix" f)) moduleFiles;
  stemSet = builtins.listToAttrs (
    map (s: {
      name = s;
      value = true;
    }) stems
  );

  namespaces = builtins.attrNames enabledMap;

  # namespace for a module stem: exact, unique-prefix, or null
  namespaceOf =
    stem:
    if enabledMap ? ${stem} then
      stem
    else
      let
        prefixed = builtins.filter (ns: builtins.match "${stem}.*" ns != null) namespaces;
      in
      if builtins.length prefixed == 1 then builtins.head prefixed else null;

  cellMatch = cell: pattern: builtins.match pattern cell != null;

  rows = builtins.filter builtins.isString (builtins.split "\n" text);

  # classify each table row; returns null for non-service rows
  rowInfo =
    line:
    let
      cells = builtins.filter builtins.isString (builtins.split "\\|" line);
      statusCell = builtins.filter (c: cellMatch c " ?(✅|🔧|🚫).*") cells;
      fileCells = builtins.filter (c: cellMatch c "^ *`[^`]*[.]nix` *$") cells;
    in
    if statusCell == [ ] || fileCells == [ ] then
      null
    else
      let
        status = builtins.head (builtins.match " ?(✅|🔧|🚫).*" (builtins.head statusCell));
        f = builtins.head (builtins.match "^ *`([^`]*)` *$" (builtins.head fileCells));
        stem = baseNameOf (builtins.head (builtins.match "(.*)[.]nix" f));
      in
      {
        inherit line status stem;
      };

  serviceRows = builtins.filter (r: r != null) (map rowInfo rows);

  fold =
    acc@{
      violations,
      guarded,
      skippedAmbiguous,
      skippedUnmapped,
      count,
    }:
    row:
    let
      ns = namespaceOf row.stem;
      claimEnabled = row.status == "✅";
    in
    if !(stemSet ? ${row.stem}) then
      acc // { count = count + 1; }
    else if ns == null then
      let
        prefixed = builtins.filter (n: builtins.match "${row.stem}.*" n != null) namespaces;
      in
      if prefixed == [ ] then
        acc
        // {
          skippedUnmapped = skippedUnmapped + 1;
          count = count + 1;
        }
      else
        acc
        // {
          skippedAmbiguous = skippedAmbiguous + 1;
          count = count + 1;
        }
    else
      let
        truth = enabledMap.${ns};
      in
      if claimEnabled != truth then
        acc
        // {
          violations = violations ++ [
            "row '${
              builtins.substring 0 60 (libTrim row.line)
            }…' cites ${row.stem}.nix with status ${row.status} but eval says services.${ns}.enable = ${builtins.toJSON truth} — flip the row status or the module enable (the forgejo-repos wrong-done class)"
          ];
          guarded = guarded + 1;
          count = count + 1;
        }
      else
        acc
        // {
          guarded = guarded + 1;
          count = count + 1;
        };

  # minimal local trim (keep this file lib-free)
  libTrim =
    s:
    let
      parts = builtins.match "[ \t]*([^ \t].*[^ \t])[ \t]*" s;
    in
    if parts == null then s else builtins.head parts;

  result = builtins.foldl' fold {
    violations = [ ];
    guarded = 0;
    skippedAmbiguous = 0;
    skippedUnmapped = 0;
    count = 0;
  } serviceRows;
in
result
