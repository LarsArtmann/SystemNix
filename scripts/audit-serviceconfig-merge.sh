#!/usr/bin/env bash
# audit-serviceconfig-merge.sh — reject `serviceConfig = <expr> // <expr>`
# shallow merges in module source.
#
# `//` on serviceConfig DISCARDS priority: mkDefault/mkForce inside either
# operand is silently clobbered by the plain values of the other. The
# documented rule (AGENTS.md gotchas, "Systemd"): ALWAYS merge fragments via
# lib.mkMerge [...] so per-key priorities survive:
#
#   BAD:  serviceConfig = harden { MemoryMax = "2G"; } // serviceDefaults {};
#         (a later plain key, or a mkForce inside harden, is silently lost)
#   GOOD: serviceConfig = lib.mkMerge [ (harden { … }) (serviceDefaults { … }) ];
#
# Scope v1: single-line direct assignments (`serviceConfig = X // Y`),
# the historically recurring shape. Multi-line/nested `//` between two
# fragments inside mkMerge is the same priority hazard but needs a parser
# to judge — grep cannot; review those at write time.
#
# Usage:
#   bash scripts/audit-serviceconfig-merge.sh            # scan the tree
#   bash scripts/audit-serviceconfig-merge.sh --selftest # prove the scanner detects
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

scan_file() {
  local f="$1" rel="$2"
  # Comments may quote the banned shape to document it — strip them.
  # Exclusions: mkMerge mentions (sanctioned wrapper), :// URL schemes.
  grep -vE '^[[:space:]]*#' "$f" 2>/dev/null |
    grep -nE 'serviceConfig[[:space:]]*=.*//' |
    grep -v 'mkMerge' |
    grep -v '://' |
    while IFS= read -r line; do
      echo "FAIL [$rel]: serviceConfig assigned with a shallow // merge (discards mkDefault/mkForce priority — use lib.mkMerge [...]):"
      echo "  $line"
    done
}

scan_tree() {
  local fail=0 scanned=0 f rel out
  local files
  mapfile -t files < <(grep -rl '' --include='*.nix' \
    "$REPO_ROOT/modules" "$REPO_ROOT/platforms" "$REPO_ROOT/pkgs" \
    2>/dev/null | sort)

  if [ "${#files[@]}" -eq 0 ]; then
    echo "FATAL: no .nix files found under $REPO_ROOT"
    exit 2
  fi

  for f in "${files[@]}"; do
    scanned=$((scanned + 1))
    rel="${f#"$REPO_ROOT"/}"
    out="$(scan_file "$f" "$rel")"
    if [ -n "$out" ]; then
      echo "$out"
      fail=1
    fi
  done

  echo ""
  echo "=== serviceconfig-merge audit: $scanned files scanned, fail=$fail ==="
  return "$fail"
}

selftest() {
  local tmp out
  tmp="$(mktemp -d)"
  # NOTE: no EXIT trap — with set -u a function-local trap outlives the
  # function and detonates as "unbound variable" at script exit (the exact
  # subshell/trap class this repo documents). Explicit cleanup instead.
  local rc=0

  cat >"$tmp/evil.nix" <<'EOF'
# documentation comment mentioning serviceConfig = x // y must NOT fire
serviceConfig = harden { MemoryMax = "2G"; } // serviceDefaults {};
EOF
  cat >"$tmp/good.nix" <<'EOF'
serviceConfig = lib.mkMerge [ (harden { MemoryMax = "2G"; }) (serviceDefaults { }) ];
# a URL scheme in the expression is not a merge operator
serviceConfig = mkDefault (env "https://example.test" // { });
EOF

  out="$(scan_file "$tmp/evil.nix" "evil.nix")"
  if [ -z "$out" ] || ! echo "$out" | grep -q 'serviceConfig'; then
    echo "SELFTEST FAIL: scanner did not flag the banned shallow merge:"
    echo "$out"
    rc=1
  fi
  out="$(scan_file "$tmp/good.nix" "good.nix")"
  if [ -n "$out" ]; then
    echo "SELFTEST FAIL: scanner flagged sanctioned forms (mkMerge / URLs):"
    echo "$out"
    rc=1
  fi
  rm -rf "$tmp"
  if [ "$rc" -eq 0 ]; then
    echo "SELFTEST PASS: detects shallow // merge, ignores mkMerge and URLs"
  fi
  return "$rc"
}

case "${1:-}" in
--selftest) selftest ;;
*) scan_tree ;;
esac
