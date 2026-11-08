# Standing registry-matrix drift gate (plan T9, 2026-11-08 nix-native
# plan): the service matrix in docs/agents/integration-registry.md is
# GENERATED from eval truth (lib/registry-matrix.nix) and must stay
# byte-identical — a registry change without a doc re-stamp fails
# `nix flake check` instead of silently rotting prose (the features-drift
# doctrine).
#
# Also exports packages.registry-matrix (the writeText artifact behind
# `nix build .#registry-matrix --print-out-paths`) for regeneration.
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      host = inputs.self.nixosConfigurations.evo-x2;
      render = import (root + "/lib/registry-matrix.nix") lib;
      generatedText = render {
        catalog = host.config.services.catalog;
        integration = host.config.services.integration;
      };
      expected = pkgs.writeText "expected-matrix.md" generatedText;
    in
    lib.mkIf (system == "x86_64-linux") {
      packages.registry-matrix = pkgs.writeText "registry-matrix.md" generatedText;

      checks.registry-matrix-drift = pkgs.runCommand "registry-matrix-drift" { } ''
        set -euo pipefail
        awk '/BEGIN GENERATED SERVICE MATRIX/{flag=1} flag{print} /END GENERATED SERVICE MATRIX/{flag=0}' \
          ${root + "/docs/agents/integration-registry.md"} > committed.txt
        # Anti-blind-skip: a sentinel deletion that yields an empty
        # extraction must fail loud, not pass vacuously.
        [ -s committed.txt ] || {
          echo "registry-matrix-drift: sentinels missing from docs/agents/integration-registry.md (empty extraction) — restore the GENERATED SERVICE MATRIX block" >&2
          exit 1
        }
        diff -u committed.txt ${expected} > drift.txt || {
          echo "registry-matrix-drift: docs/agents/integration-registry.md service matrix is STALE:" >&2
          head -40 drift.txt >&2
          echo "" >&2
          echo "Regenerate: nix build .#registry-matrix --print-out-paths && cat <path>" >&2
          echo "then replace the block between the BEGIN/END GENERATED SERVICE MATRIX sentinels." >&2
          exit 1
        }
        touch $out
      '';
    };
}
