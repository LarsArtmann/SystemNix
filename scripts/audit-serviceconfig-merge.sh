#!/usr/bin/env bash
# audit-serviceconfig-merge.sh — reject shallow `//` merges in module source.
#
# Rule 1 (serviceConfig): `//` on serviceConfig DISCARDS priority:
# mkDefault/mkForce inside either operand is silently clobbered by the plain
# values of the other. The documented rule (docs/agents/systemd.md): ALWAYS
# merge fragments via lib.mkMerge [...] so per-key priorities survive:
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
# Scope v3 adds rule 2 — mkIf inside a shallow `//` on ANY attribute, not just
# serviceConfig. `lib.mkIf` returns a CONDITIONAL attrset; composing it with
# `//` makes the module system treat the whole attribute value as conditional,
# so the unconditional operand silently vanishes when the condition is false.
# Eval stays green and the rendered unit loses its ExecStart: the 2026-10-28
# dns-blocker.nix `systemd = { … } // (lib.mkIf cfg.allowlistBackup.enable
# { … })` wiped EVERY dnsblockd unit on evo-x2 (no ExecStart) and the unit
# entirely on rpi3-dns — found only when a parallel session's readiness gate
# went red, never by an eval error.
#
#   BAD:  systemd = { after = [ "a" ]; } // (lib.mkIf cfg.on { … });
#   GOOD: systemd = lib.mkMerge [ { after = [ "a" ]; } (lib.mkIf cfg.on { … }) ];
#
# Usage:
#   bash scripts/audit-serviceconfig-merge.sh            # scan the tree
#   bash scripts/audit-serviceconfig-merge.sh --selftest # prove the scanner detects
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# scan_mkif_merge <file> <rel> — the BROADER sibling of the serviceConfig
# rule: any `ATTR = <expr> // <expr>` whose operands mention lib.mkIf.
#
# `//` is a SHALLOW attrset merge, and lib.mkIf returns a conditional
# attrset. Composing them makes the module system treat the ENTIRE
# attribute value as conditional, so the unconditional half silently
# disappears whenever the condition is false — and eval stays green while
# the rendered unit loses its ExecStart (2026-10-28 dns-blocker.nix:
# `systemd = { … } // (lib.mkIf cfg.allowlistBackup.enable { … })` wiped
# every dnsblockd unit on evo-x2, and the whole unit on rpi3-dns, with no
# eval error anywhere). The sanctioned form is
# `ATTR = lib.mkMerge [ { … } (lib.mkIf cond { … }) ];`.
#
# Only `//` + `mkIf` is flagged; a plain `//` (priority-clobbering) is the
# serviceConfig rule's job, and an mkMerge buffer may legitimately hold an
# mkIf fragment.
scan_mkif_merge() {
  local f="$1" rel="$2"
  awk -v rel="$rel" '
    function report(nr, text,   check) {
      check = text
      gsub(/:\/\//, ":", check)
      if (check ~ /\/\// && check ~ /mkIf/ && check !~ /mkMerge/) {
        printf "FAIL [%s]: mkIf inside a shallow // merge (line %d — the whole attribute becomes conditional and the other operand is silently dropped when false; use lib.mkMerge [ … (lib.mkIf …) ]):\n", rel, nr
        print "  " text
      }
    }
    /^[[:space:]]*#/ { next }
    {
      if (collect) {
        buf = buf "\n" $0
        if ($0 ~ /;/) {
          report(startnr, buf)
          collect = 0
        } else if (NR - startnr >= 12) {
          report(startnr, buf)
          collect = 0
        }
        next
      }
      if ($0 ~ /[A-Za-z_][A-Za-z0-9_.-]*[[:space:]]*=/ && $0 !~ /;/) {
        collect = 1
        startnr = NR
        buf = $0
        next
      }
      report(NR, $0)
    }
  ' "$f"
}

scan_file() {
  local f="$1" rel="$2"
  scan_serviceconfig_merge "$f" "$rel"
  scan_mkif_merge "$f" "$rel"
}

scan_serviceconfig_merge() {
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

  # mkIf-inside-`//` legs: the 2026-10-28 dns-blocker shape that wiped every
  # dnsblockd unit while eval stayed green.
  cat >"$tmp/evil-mkif.nix" <<'EOF'
systemd = { after = [ "a.service" ]; } // (lib.mkIf cfg.on { requires = [ "b" ]; });
EOF
  cat >"$tmp/evil-mkif-continuation.nix" <<'EOF'
systemd =
  { after = [ "a.service" ]; }
  // (lib.mkIf cfg.on { requires = [ "b" ]; });
EOF
  cat >"$tmp/good-mkif.nix" <<'EOF'
# sanctioned: mkIf as an mkMerge fragment, no // anywhere
systemd = lib.mkMerge [
  { after = [ "a.service" ]; }
  (lib.mkIf cfg.on { requires = [ "b" ]; })
];
# a plain shallow merge without mkIf is the other rule's business
extraConfig = a // b;
EOF

  out="$(scan_mkif_merge "$tmp/evil-mkif.nix" "evil-mkif.nix")"
  if [ -z "$out" ] || ! echo "$out" | grep -q 'mkIf inside a shallow // merge'; then
    echo "SELFTEST FAIL: scanner did not flag mkIf inside a single-line // merge:"
    echo "$out"
    rc=1
  fi
  out="$(scan_mkif_merge "$tmp/evil-mkif-continuation.nix" "evil-mkif-continuation.nix")"
  if [ -z "$out" ] || ! echo "$out" | grep -q 'mkIf inside a shallow // merge'; then
    echo "SELFTEST FAIL: scanner did not flag mkIf inside a continuation-line // merge:"
    echo "$out"
    rc=1
  fi
  out="$(scan_mkif_merge "$tmp/good-mkif.nix" "good-mkif.nix")"
  if [ -n "$out" ]; then
    echo "SELFTEST FAIL: scanner flagged the sanctioned mkMerge/mkIf form or a plain non-mkIf merge:"
    echo "$out"
    rc=1
  fi
  rm -rf "$tmp"
  if [ "$rc" -eq 0 ]; then
    echo "SELFTEST PASS: detects single-line + continuation shallow merges (serviceConfig and mkIf-inside-//), ignores mkMerge (all shapes) and URLs"
  fi
  return "$rc"
}

case "${1:-}" in
--selftest) selftest ;;
*) scan_tree ;;
esac
