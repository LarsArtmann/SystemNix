# shellcheck shell=bash
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
if declare -f use_flake >/dev/null 2>&1 && ! declare -f _nix_add_gcroot >/dev/null 2>&1; then
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

# ─── Dead Automount Guard (/mnt/buildcache) ──────────────────────────────────
# The session env (home.nix) points GOCACHE/GOMODCACHE/GOLANGCI_LINT_CACHE/
# npm_config_cache at the /mnt/buildcache USB automount. When the device is
# absent, EVERY go/golangci/npm spawn stalls ~25s in an uninterruptible stat
# (BuildFlow gotcha #129). BuildFlow's EnvGuard covers pipeline runs; this
# guard covers the interactive shell itself, at direnv-eval time.
#
# Zero cost when no cache var points at the automount (string check first).
# The probe runs in the background and is POLLED, never waited on: a D-state
# stat cannot be interrupted, only outlived — `wait` would inherit the 25s
# stall we are defending against. Healthy mount: probe answers in ~1ms and
# the guard costs one 0.1s poll tick. Dead mount: 0.5s bound, then the vars
# are rewritten to the known-healthy local fallbacks and the guard disarms
# itself (subsequent evals see healthy values and skip the probe entirely).
BF_DEAD_MOUNT_PATH="${BF_DEAD_MOUNT_PATH:-/mnt/buildcache}"
BF_DEAD_MOUNT_POLLS="${BF_DEAD_MOUNT_POLLS:-5}"

_bf_dead_mount_probe() {
  stat -c %i "$BF_DEAD_MOUNT_PATH" >/dev/null 2>&1
}

_bf_dead_mount_guard() {
  local var needs_probe=0
  for var in GOCACHE GOMODCACHE GOLANGCI_LINT_CACHE npm_config_cache; do
    if [[ ${!var:-} == "$BF_DEAD_MOUNT_PATH"/* ]]; then
      needs_probe=1
    fi
  done
  if [[ $needs_probe == 0 ]]; then
    return 0
  fi

  _bf_dead_mount_probe &
  local probe=$!
  local alive=0
  local _
  for _ in $(seq 1 "$BF_DEAD_MOUNT_POLLS"); do
    if ! kill -0 "$probe" 2>/dev/null; then
      alive=1
      break
    fi
    sleep 0.1
  done
  # Never wait: on a dead mount the probe lingers ~25s in D-state. It is
  # orphaned here and exits on its own; leaving it costs nothing.
  kill "$probe" 2>/dev/null || true
  if [[ $alive == 1 ]]; then
    return 0
  fi

  log_status "zz-smart-nix.sh: $BF_DEAD_MOUNT_PATH automount is dead — rewriting cache env vars to local fallbacks (spawns would otherwise stall ~25s each)"
  if [[ ${GOCACHE:-} == "$BF_DEAD_MOUNT_PATH"/* ]]; then
    export GOCACHE="$HOME/.cache/gocache"
  fi
  if [[ ${GOMODCACHE:-} == "$BF_DEAD_MOUNT_PATH"/* ]]; then
    export GOMODCACHE="$HOME/go/pkg/mod"
  fi
  if [[ ${GOLANGCI_LINT_CACHE:-} == "$BF_DEAD_MOUNT_PATH"/* ]]; then
    export GOLANGCI_LINT_CACHE="$HOME/.cache/golangci-lint"
  fi
  if [[ ${npm_config_cache:-} == "$BF_DEAD_MOUNT_PATH"/* ]]; then
    export npm_config_cache="/tmp/npm-cache-home"
  fi
}

_bf_dead_mount_guard
