# Standing doc-counts eval gate (2026-10-24, 16-43 plan T3).
#
# README.md and FEATURES.md assert flake-derived counts (nixosModules,
# Gatus endpoints, packages). Hand-maintained numbers rotted 40-70%
# between sweeps (55 asserted vs 131 real modules, caught 2026-10-24 M4).
# This gate evals the TRUTH from the flake itself and compares it against
# what the docs assert — never assert-against-assert: the doc-extracted
# number is the guarded claim, the eval number is derived, and neither
# side is hardcoded here. Re-stamping the doc after adding a module makes
# the gate green again without touching this file.
#
# Anchors are single-occurrence forms (verified 2026-10-24):
#   README.md   "…`nix eval .#nixosModules` → NNN…"
#   README.md   "…endpoints --apply 'x: builtins.length x'` → NNN…"
#   FEATURES.md "NNN modules auto-discovered…"
#   FEATURES.md "NNN packages in `#packages…"
# Restructuring those assertion lines requires updating the anchors below
# in the same change; a lost anchor fails as drift, never silently passes.
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    lib.mkIf (system == "x86_64-linux") {
      checks =
        let
          # eval truth — derived from the flake, never hardcoded
          moduleCount = builtins.length (builtins.attrNames inputs.self.nixosModules);
          gatusCount = builtins.length inputs.self.nixosConfigurations.evo-x2.config.services.gatus.settings.endpoints;
          packageCount = builtins.length (builtins.attrNames inputs.self.packages.x86_64-linux);

          # Extract the number from the doc's assertion line and throw on
          # drift or missing anchor. Returns the asserted number (forced
          # by the caller so laziness cannot skip the guard).
          numOnAnchor =
            text: anchor: label: want:
            let
              lines = lib.strings.splitString "\n" text;
              hits = builtins.filter (l: builtins.match anchor l != null) lines;
            in
            if hits == [ ] then
              throw "doc-counts: ${label} assertion anchor missing (regex ${anchor}) — the doc lost its count line, re-stamp it"
            else
              let
                got = builtins.head (builtins.match anchor (builtins.head hits));
              in
              lib.throwIf (got != toString want)
                "doc-counts: ${label} asserts ${got}, eval truth is ${toString want} — re-derive with the README-embedded commands and re-stamp the doc (the 55-vs-131 drift class)"
                got;

          # path + string keeps this a PATH (no string-context store-path
          # coercion — "${root}/x" would capture the flake's random-named
          # working-tree copy in the derivation context and fail flake
          # check's derivationStrict with "path …-source is not valid").
          readmeText = builtins.readFile (root + "/README.md");
          featuresText = builtins.readFile (root + "/FEATURES.md");
        in
        {
          doc-counts =
            pkgs.runCommand "doc-counts"
              {
                guards =
                  numOnAnchor readmeText ".*nix eval .#nixosModules. → ([0-9]+).*" "README nixosModules" moduleCount
                  +
                    numOnAnchor readmeText ".*endpoints --apply .x: builtins.length x.. → ([0-9]+).*"
                      "README gatus endpoints"
                      gatusCount
                  +
                    numOnAnchor featuresText ".*[^0-9]([0-9]+) modules auto-discovered.*" "FEATURES nixosModules"
                      moduleCount
                  +
                    numOnAnchor featuresText ".*[^0-9]([0-9]+) packages in .#packages.*" "FEATURES packages"
                      packageCount;
              }
              ''
                echo "$guards" >/dev/null
                touch $out
              '';
        };
    };
}
