# ─────────────────────────────────────────────────────────────────────────────
# Smart direnv extensions for LarsArtmann projects.
#
# This file is auto-loaded by direnv from ~/.config/direnv/lib/ BEFORE any
# .envrc is evaluated. It loads AFTER hm-nix-direnv.sh (alphabetically
# zz > hm), so function overrides take effect.
#
# Two things happen here:
#   1. _nix_add_gcroot override  — eliminates per-input `nix build --out-link`
#   2. use_go_env helper          — auto-detects GOEXPERIMENT + GOPRIVATE
# ─────────────────────────────────────────────────────────────────────────────

# ─── nix-direnv Compatibility Guard ──────────────────────────────────────────
# If nix-direnv renamed _nix_add_gcroot, the override below is a dead function
# that nothing calls. Warn so the developer knows GC root optimization is off.
if declare -f use_flake > /dev/null 2>&1 && ! declare -f _nix_add_gcroot > /dev/null 2>&1; then
  log_error "zz-smart-nix.sh: nix-direnv loaded but _nix_add_gcroot not found — GC root optimization inactive (function may have been renamed upstream)"
fi

# ─── GC Root Optimization ───────────────────────────────────────────────────
# Override nix-direnv's per-input GC root creation.
#
# nix-direnv's stock implementation spawns a SEPARATE `nix build --out-link`
# process for every flake input (258 processes on SystemNix = 6.4s wasted).
# This override uses instant `ln -sfn` for paths already in /nix/store,
# falling back to `_nix build` only for the devShell profile symlink (which
# needs store-path resolution).
#
# Measured impact: 5.1x faster cold reload (14.8s → 2.9s on SystemNix).
# See: SystemNix/docs/status/2026-08-03_03-23_shell-latency-benchmark-and-nix-direnv-cold-path-fix.md
_nix_add_gcroot() {
  local storepath=$1
  local symlink=$2
  if [[ $storepath == /nix/store/* ]]; then
    ln -sfn "$storepath" "$symlink"
  else
    _nix build --out-link "$symlink" "$storepath"
  fi
}

# ─── Go Environment Auto-Detection ──────────────────────────────────────────
# Call `use_go_env` in .envrc after `use flake`.
# Auto-detects and exports Go environment variables based on project files.
# Respects existing env values — never overwrites what's already set.
use_go_env() {
  # GOEXPERIMENT=jsonv2:
  #   nix-direnv doesn't reliably propagate shellHook exports, so we set it
  #   here as a fallback. Detection order (fast → slow):
  #     1. flake.nix mentions GOEXPERIMENT or jsonv2 (instant, most reliable)
  #     2. Go source files import encoding/json/v2 (fast grep, excludes vendor/)
  if [[ -z ${GOEXPERIMENT:-} ]]; then
    if [[ -f flake.nix ]] && grep -qE 'GOEXPERIMENT|jsonv2' flake.nix 2>/dev/null; then
      export GOEXPERIMENT=jsonv2
    elif [[ -f go.mod ]] && grep -rq --include='*.go' --exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=.git 'encoding/json/v2' . 2>/dev/null; then
      export GOEXPERIMENT=jsonv2
    fi
  fi

  # GOPRIVATE: auto-detect private larsartmann repos from go.mod.
  # Skipped if GOPRIVATE is already set (project may have a custom value).
  if [[ -z ${GOPRIVATE:-} ]] && [[ -f go.mod ]] && grep -qE 'github.com/[Ll]ars[Aa]rtmann' go.mod 2>/dev/null; then
    export GOPRIVATE="github.com/larsartmann/*,github.com/LarsArtmann/*"
  fi
}
