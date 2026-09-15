#!/usr/bin/env bash
# audit-push-protection-literals.sh — reject tracked literals that match
# known GitHub push-protection secret patterns.
#
# WHY: GitHub push protection IGNORES .gitleaks.toml allowlists — it
# pattern-matches raw blobs in the push range (the 2026-09-15 GH013 push
# block: a handcrafted `sgp_<40hex>` gitleaks-fixture literal passed
# pre-commit + CI and still blocked the push on 4 commits). The sanctioned
# form for test/detector fixtures is a TEMPLATE (`@HEX40@`, expanded to a
# deterministic sha256-derived hex at scan time — see flake.nix
# gitleaks-coverage-selftest), which never matches these patterns.
#
# Covered shapes (extend as new partner patterns enter the ecosystem):
#   sgp_[0-9a-fA-F]{40}     Sourcegraph access token
#   sq0atp-[0-9a-zA-Z]{40}  Square access token
#
# Usage:
#   audit-push-protection-literals.sh             # scan all tracked files
#   audit-push-protection-literals.sh --selftest  # prove the scanner scans
set -uo pipefail

PATTERNS=(
  'sgp_[0-9a-fA-F]{40}'
  'sq0atp-[0-9a-zA-Z]{40}'
)

scan_files() {
  # $@: file paths. Prints FAIL lines; returns non-zero on any hit.
  local fail=0 pattern file
  for pattern in "${PATTERNS[@]}"; do
    while IFS= read -r -d '' file; do
      if grep -nIE "$pattern" "$file" 2>/dev/null; then
        echo "FAIL: push-protection-shaped literal in $file (pattern: $pattern)" >&2
        echo "      GitHub push protection pattern-matches raw blobs and IGNORES gitleaks allowlists" >&2
        echo "      — template it instead: @HEX40@ expanded at scan time (flake.nix expect_detect)" >&2
        fail=1
      fi
    done < <(printf '%s\0' "$@")
  done
  return "$fail"
}

selftest() {
  # NOT local: the EXIT trap must still see it after the function returns
  tmp=$(mktemp -d) || return 1
  trap 'rm -rf "$tmp"' EXIT

  # Compose the negative-case tokens at RUNTIME — the assembled literals
  # must never appear in this file, or the scanner would flag itself.
  local hex40='REDACTED-PUSH-PROTECTION-FIXTURE'
  local mixed='REDACTED-PUSH-PROTECTION-FIXTURE'
  printf 'sourcegraph access token: sgp_%s\n' "$hex40" >"$tmp/sgp.txt"
  printf 'square access token: sq0atp-%s\n' "$mixed" >"$tmp/sq.txt"
  printf 'sourcegraph access token: sgp_@HEX40@\n' >"$tmp/templated.txt"
  printf 'bare hex without keywords: 7f3e9a1c48d2b650e4fa93c17b8d05264e9f0a3c\n' >"$tmp/bare.txt"

  if scan_files "$tmp/sgp.txt" "$tmp/sq.txt" 2>/dev/null; then
    echo "SELFTEST FAIL: the scanner did NOT flag the known push-protection literals" >&2
    return 1
  fi
  echo "selftest: both literal shapes flagged"
  if ! scan_files "$tmp/templated.txt" "$tmp/bare.txt" 2>/dev/null; then
    echo "SELFTEST FAIL: the scanner flagged the sanctioned template/bare-hex forms" >&2
    return 1
  fi
  echo "selftest: template + bare-hex forms pass"
  echo "SELFTEST PASS"
}

case "${1:-}" in
--selftest)
  selftest
  ;;
*)
  # A scanner must prove it measured: zero tracked files is an error,
  # not a pass (the gosec Files:0 false-green class).
  mapfile -d '' files < <(git ls-files -z)
  if [ "${#files[@]}" -eq 0 ]; then
    echo "FAIL: no tracked files found — run from the repo root" >&2
    exit 1
  fi
  echo "scanning ${#files[@]} tracked files for push-protection-shaped literals"
  scan_files "${files[@]}"
  ;;
esac
