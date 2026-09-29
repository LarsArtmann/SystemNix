# scripts/lib/precommit-eval-cache.sh — memo for eval-expensive pre-commit legs.
# Sourced by .githooks/pre-commit and scripts/fmt-cached.sh; selftested by
# scripts/test-precommit-eval-cache.sh (flake check:
# precommit-eval-cache-selftest — fixture-proven, never a drifted copy).
#
# WHAT is memoized: the resolved store path of .#formatter.$sys. Building it
# pays a full flake eval (30-90s+ warm on this 420-input tree; see the AGENTS.md
# "Why plain flake EVAL is slow here" bullet) on EVERY .nix-touching commit,
# yet the out-path is a pure function of a SMALL input set: flake.nix +
# flake.lock + overlays/ + lib/ (perSystem pkgs imports the overlays; the
# formatter block lives in flake.nix; the patched treefmt config is derived
# at BUILD time from the locked treefmt-full-flake input) + the nix client
# version. Module edits do NOT move it — which is the common case.
#
# SAFETY MODEL (deliberate non-goals):
#  - The `nix flake check` leg is NOT memoized: its docs-only/no-staged fast
#    paths already cover the cheap cases, and every remaining run IS an
#    eval-relevant diff that should eval. A verdict cache would trade
#    phantom-green risk on the primary gate for a thin win.
#  - Stale-formatter drift (key under-coverage) is backstopped by CI's
#    `nix fmt -- --ci` arbitration — drift fails RED, never silent. The key
#    is content-based: no TTL can serve an entry computed from other bytes.
#  - GC'd store paths: every lookup validates the path still exists; a
#    missing path is a MISS (falls through to a real build).
#  - Escape hatch: PRECOMMIT_EVAL_CACHE=0 disables all lookups.
#
# State: ${PRECOMMIT_EVAL_CACHE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/systemnix/precommit-eval-cache}
# NEVER /tmp — the tmp-cleaner eats >4h-stale entries (deploy-queue lesson).

# Overridable store-path prefix (test isolation only; production default).
_PEC_STORE_PREFIX="${_PEC_STORE_PREFIX:-/nix/store}"

precommit_eval_cache_enabled() {
  [ "${PRECOMMIT_EVAL_CACHE:-1}" = "1" ]
}

_pec_state_dir() {
  local d="${PRECOMMIT_EVAL_CACHE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/systemnix/precommit-eval-cache}"
  mkdir -p "$d" || return 1
  printf '%s\n' "$d"
}

# Content key over exactly the formatter's eval-relevant inputs. Returns 1
# (=> MISS downstream) if any input is unreadable — never a partial key:
# sha256sum prints "hash  path" per file, so identity AND content are keyed
# (a same-content rename still misses).
precommit_formatter_key() {
  local listing
  listing=$(
    git ls-files -z -- 'flake.nix' 'flake.lock' 'overlays/*.nix' 'lib/*.nix' |
      xargs -0 -r sha256sum
  ) || return 1
  [ -n "$listing" ] || return 1
  {
    printf 'nix-version: '
    nix --version || printf 'unknown\n'
    printf '%s\n' "$listing"
  } | sha256sum | cut -d' ' -f1
}

# Echo the memoized formatter store path, or return 1 (MISS).
precommit_formatter_cached_path() {
  precommit_eval_cache_enabled || return 1
  local key f p
  key=$(precommit_formatter_key) || return 1
  f="$(_pec_state_dir)/formatter.$key" || return 1
  [ -s "$f" ] || return 1
  p=$(head -n 1 "$f" 2>/dev/null) || return 1
  case "$p" in
  "$_PEC_STORE_PREFIX"/*) ;;
  *) return 1 ;;
  esac
  [ -e "$p/bin/treefmt" ] || return 1
  printf '%s\n' "$p"
}

# Record a freshly resolved formatter path against the current key.
# Best-effort: a failed write only costs a future MISS, never a wrong hit.
precommit_formatter_store_path() {
  local p="$1" key d tmp
  case "$p" in
  "$_PEC_STORE_PREFIX"/*) ;;
  *) return 0 ;;
  esac
  key=$(precommit_formatter_key) || return 0
  d=$(_pec_state_dir) || return 0
  tmp=$(mktemp "$d/.formatter.XXXXXX") || return 0
  printf '%s\n' "$p" >"$tmp"
  mv -f "$tmp" "$d/formatter.$key" || {
    rm -f "$tmp"
    return 0
  }
  # Prune: keep the 5 newest entries (lock churn rotates keys).
  ls -1t "$d"/formatter.* 2>/dev/null | tail -n +6 | while IFS= read -r old; do
    rm -f "$old"
  done || true
  return 0
}
