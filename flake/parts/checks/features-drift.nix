# Standing FEATURES enable-drift eval gate (2026-10-25, fleet-stabilization
# F11-F13; implements the [ready] pipeline.md:631 row / 03-42 plan W1).
#
# For every FEATURES service row citing one of OUR module files, the row's
# lifecycle status (✅ vs 🔧/🚫) must match eval-derived
# services.<ns>.enable on evo-x2. Kills the forgejo-repos class (a ✅ row
# over an enable=false module since 2026-09-18, caught only manually).
#
# Pure logic: lib/features-drift.nix (fixture-tested by
# checks.features-drift-selftest in lint-static.nix). This file only derives
# the eval truth and stamps the guard; nothing is hardcoded.
#
# Anti-blind-skip: the parse must keep guarding at least `minGuarded` rows —
# a FEATURES restructure that stops rows from parsing fails LOUD instead of
# silently covering nothing.
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
          host = inputs.self.nixosConfigurations.evo-x2;
          enableNamespaces = builtins.filter (ns: (host.options.services.${ns}.enable.type or null) != null) (
            builtins.attrNames host.options.services
          );
          enabledMap = builtins.listToAttrs (
            map (ns: {
              name = ns;
              value = host.config.services.${ns}.enable;
            }) enableNamespaces
          );
          moduleFiles =
            let
              dirs = [
                (root + "/modules/nixos/services")
                (root + "/modules/nixos/desktop")
              ];
              all = builtins.concatLists (map (d: builtins.attrNames (builtins.readDir d)) dirs);
            in
            builtins.filter (f: builtins.match ".*[.]nix" f != null && builtins.match "_.*" f == null) all;
          verdict = import (root + "/lib/features-drift.nix") {
            text = builtins.readFile (root + "/FEATURES.md");
            inherit moduleFiles enabledMap;
          };
          minGuarded = 40;
        in
        {
          features-drift =
            pkgs.runCommand "features-drift"
              {
                guards =
                  lib.throwIf (verdict.violations != [ ])
                    "features-drift: ${toString (builtins.length verdict.violations)} enable drift(s) between FEATURES rows and eval truth:\n  ${lib.concatStringsSep "\n  " verdict.violations}"
                    (
                      lib.throwIf (verdict.guarded < minGuarded)
                        "features-drift: only ${toString verdict.guarded} rows guarded (< ${toString minGuarded}) — the FEATURES row anchors rotted; fix the row parse in lib/features-drift.nix, do not lower the threshold"
                        "guarded=${toString verdict.guarded} ambiguous=${toString verdict.skippedAmbiguous} unmapped=${toString verdict.skippedUnmapped} rows=${toString verdict.count}"
                    );
              }
              ''
                echo "$guards" >/dev/null
                touch $out
              '';
        };
    };
}
