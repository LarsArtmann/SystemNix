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
# Scope v2: (1) single-line direct assignments (`serviceConfig = X // Y`),
# the historically recurring shape; (2) CONTINUATION-line shallow merges — a
# `serviceConfig =` assignment whose `//` operator lands on a FOLLOWING line
# (the 2026-09-30 caddy.nix dnsblockd-cert-mint defect: `serviceConfig =
# (serviceOneshotDefaults { })` newline `// {` sailed past the v1 single-line
# regex at landing time). The continuation check is a bounded (≤6 lines)
# statement buffer: any `//` in the buffer (URLs `://` stripped) without a
# `mkMerge` anywhere in it fails. Multi-line `//` between two fragments
# INSIDE a mkMerge list is a different judgment call and stays out of scope.
#
# Usage:
#   bash scripts/audit-serviceconfig-merge.sh            # scan the tree
#   bash scripts/audit-serviceconfig-merge.sh --selftest # prove the scanner detects
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

scan_file() {
  local f="$1" rel="$2"
  # One awk pass; comment lines skipped FIRST so reported line numbers are
  # true FNR. `://` URL schemes are stripped before the `//` operator check.
  awk -v rel="$rel" '
    /^[[:space:]]*#/ { next }
    {
      if (collect) {
        buf = buf "\n" $0
        if ($0 ~ /;/) {
          check = buf
          gsub(/:\/\//, ":", check)
          if (check ~ /\/\// && check !~ /mkMerge/) {
            printf "FAIL [%s]: serviceConfig shallow // merge across continuation lines (line %d — discards mkDefault/mkForce priority; use lib.mkMerge [...]):\n", rel, startnr
            print "  " buf
          }
          collect = 0
        } else if (NR - startnr >= 6) {
          collect = 0
        }
        next
      }
      if ($0 ~ /serviceConfig[[:space:]]*=/) {
        line = $0
        gsub(/:\/\//, ":", line)
        if (line ~ /\/\// && line !~ /mkMerge/) {
          printf "FAIL [%s]: serviceConfig assigned with a shallow // merge (line %d — discards mkDefault/mkForce priority; use lib.mkMerge [...]):\n", rel, NR
          print "  " $0
          next
        }
        if ($0 !~ /;/) {
          collect = 1
          startnr = NR
          buf = $0
        }
      }
    }
  ' "$f"
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
  cat >"$tmp/evil-multiline.nix" <<'EOF'
# the 2026-09-30 caddy.nix landing shape: // on a continuation line
serviceConfig =
  (serviceOneshotDefaults { })
  // {
    Type = "oneshot";
  };
EOF
  cat >"$tmp/good.nix" <<'EOF'
serviceConfig = lib.mkMerge [ (harden { MemoryMax = "2G"; }) (serviceDefaults { }) ];
# a URL scheme is not a merge operator (:// stripped before the // check)
serviceConfig = mkDefault "https://example.test";
EOF
  cat >"$tmp/good-multiline.nix" <<'EOF'
# the sanctioned multi-line mkMerge shape must stay green
serviceConfig =
  lib.mkMerge [
    (harden { MemoryMax = "2G"; })
    { ReadWritePaths = [ "/var/lib/x" ]; }
  ];
# a plain multi-line assignment with no // is not a merge
serviceConfig =
  harden { MemoryMax = "2G"; };
EOF

  out="$(scan_file "$tmp/evil.nix" "evil.nix")"
  if [ -z "$out" ] || ! echo "$out" | grep -q 'serviceConfig'; then
    echo "SELFTEST FAIL: scanner did not flag the banned shallow merge:"
    echo "$out"
    rc=1
  fi
  out="$(scan_file "$tmp/evil-multiline.nix" "evil-multiline.nix")"
  if [ -z "$out" ] || ! echo "$out" | grep -q 'continuation lines'; then
    echo "SELFTEST FAIL: scanner did not flag the continuation-line shallow merge:"
    echo "$out"
    rc=1
  fi
  out="$(scan_file "$tmp/good.nix" "good.nix")"
  if [ -n "$out" ]; then
    echo "SELFTEST FAIL: scanner flagged sanctioned forms (mkMerge / URLs):"
    echo "$out"
    rc=1
  fi
  out="$(scan_file "$tmp/good-multiline.nix" "good-multiline.nix")"
  if [ -n "$out" ]; then
    echo "SELFTEST FAIL: scanner flagged sanctioned multi-line forms (mkMerge list / plain continuation):"
    echo "$out"
    rc=1
  fi
  rm -rf "$tmp"
  if [ "$rc" -eq 0 ]; then
    echo "SELFTEST PASS: detects single-line + continuation shallow merges, ignores mkMerge (both shapes) and URLs"
  fi
  return "$rc"
}

case "${1:-}" in
--selftest) selftest ;;
*) scan_tree ;;
esac
