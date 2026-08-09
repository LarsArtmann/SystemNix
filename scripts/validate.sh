#!/usr/bin/env bash
set -euo pipefail
# Validate the flake evaluates without building.
# Uses `nix eval` on the toplevel derivation instead of `nix flake check --no-build`
# because the latter produces false "path is not valid" errors from mkPreparedSource
# and go-nix-helpers eval-time builtins.pathExists checks.
nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath
