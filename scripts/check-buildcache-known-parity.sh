#!/usr/bin/env bash
# buildcacheDirs ↔ KNOWN_CACHE_ENTRIES parity guard (selftesting).
#
# Every literal dir in buildcache.nix's `buildcacheDirs` list must be covered
# by the KNOWN_CACHE_ENTRIES array in scripts/das-link-recovery-check.sh — the
# check's [6] leg flags unknown /mnt/buildcache entries, and a hand-edit to
# either list must fail loudly here instead of at the next manual re-fire
# (2026-10-02 re-fire-9 class). Coverage semantics: KNOWN names are top-level
# mount entries, so a literal like `cargo/registry` is covered by its
# top-level name (`cargo`).
#
# Selftesting (house pattern: gitleaks-coverage-selftest — no guard without a
# positive fixture): `--selftest` runs the check against the real files AND
# against deliberately-drifted temp copies, asserting the guard FAILS on both
# drift shapes (missing KNOWN name, extra buildcacheDirs literal).
#
# Usage: check-buildcache-known-parity.sh [--selftest] [buildcache.nix das-check.sh]
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
default_buildcache_nix="$repo_root/modules/nixos/services/buildcache.nix"
default_das_check="$repo_root/scripts/das-link-recovery-check.sh"

selftest=false
positional=()
for arg in "$@"; do
  case $arg in
  --selftest) selftest=true ;;
  *) positional+=("$arg") ;;
  esac
done

extract_dirs() {
  sed -n '/buildcacheDirs = \[/,/^\s*\];/p' "$1" |
    grep -oE '"[^"]+"' | tr -d '"' | sort -u
}

extract_known() {
  sed -n '/^KNOWN_CACHE_ENTRIES=(/,/^)/p' "$1" |
    sed '1d;$d' | grep -oE '[^[:space:]]+' | sort -u
}

fail() {
  echo "PARITY FAIL: $*" >&2
  exit 1
}

run_check() {
  local buildcache_nix="$1" das_check="$2"
  [ -f "$buildcache_nix" ] || fail "buildcache.nix not found: $buildcache_nix"
  [ -f "$das_check" ] || fail "das-link-recovery-check.sh not found: $das_check"

  local dirs known
  dirs=$(extract_dirs "$buildcache_nix")
  known=$(extract_known "$das_check")

  # Fail-closed: an extraction that yields nothing is a broken extraction,
  # never a passing parity result.
  [ -n "$dirs" ] || fail "extracted zero buildcacheDirs literals from $buildcache_nix — parser drifted"
  [ -n "$known" ] || fail "extracted zero KNOWN_CACHE_ENTRIES names from $das_check — parser drifted"

  local missing=0 dir
  while IFS= read -r dir; do
    if ! grep -qxF "$dir" <<<"$known" && ! grep -qxF "${dir%%/*}" <<<"$known"; then
      echo "PARITY FAIL: buildcacheDirs literal '$dir' is not covered by KNOWN_CACHE_ENTRIES" >&2
      missing=$((missing + 1))
    fi
  done <<<"$dirs"

  [ "$missing" -eq 0 ] || fail "$missing buildcacheDirs literal(s) uncovered — extend KNOWN_CACHE_ENTRIES or fix the drift"
  echo "PARITY OK: $(wc -l <<<"$dirs") buildcacheDirs literals covered by $(wc -l <<<"$known") KNOWN_CACHE_ENTRIES names"
}

expect_fail() {
  local label="$1"
  shift
  # Subshell: fail() exits, and that exit must be contained to the probe.
  if (run_check "$@") >/dev/null 2>&1; then
    fail "selftest: guard did NOT detect drift shape '$label' — the guard is dead"
  fi
  echo "selftest: guard correctly rejected drift shape '$label'"
}

buildcache_nix="${positional[0]:-$default_buildcache_nix}"
das_check="${positional[1]:-$default_das_check}"

if ! $selftest; then
  run_check "$buildcache_nix" "$das_check"
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat "$buildcache_nix" >"$work/buildcache.nix"
cat "$das_check" >"$work/das-check.sh"

echo "selftest: positive control (real files)"
run_check "$work/buildcache.nix" "$work/das-check.sh"

echo "selftest: drift shape 1 — KNOWN name removed"
sed -i 's/\bgo-build\b/go-build-renamed/' "$work/das-check.sh"
expect_fail "KNOWN name removed" "$work/buildcache.nix" "$work/das-check.sh"
cat "$das_check" >"$work/das-check.sh"

echo "selftest: drift shape 2 — new buildcacheDirs literal"
sed -i 's|^        "sccache"$|        "sccache"\n        "brand-new-drift-dir"|' "$work/buildcache.nix"
expect_fail "new buildcacheDirs literal" "$work/buildcache.nix" "$work/das-check.sh"

echo "selftest: fail-closed on empty extraction"
printf 'buildcacheDirs = [ ];\n' >"$work/empty.nix"
expect_fail "empty extraction" "$work/empty.nix" "$work/das-check.sh"
