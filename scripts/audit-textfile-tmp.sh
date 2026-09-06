#!/usr/bin/env bash
# audit-textfile-tmp.sh — sweep node_exporter textfile collectors for the
# fixed-tmp / phantom-rendered-path failure classes.
#
# The shared textfile dir (/var/lib/prometheus-node-exporter/
# textfile_collectors) is a STICKY 1777 dir: NOBODY — including root under
# harden{} (all capabilities stripped) — can rename over a file owned by
# someone else without CAP_FOWNER. The incident shape (mail-relay,
# 2026-09-02..06, 845+ failed runs): a collector switched from root to a
# service user; the last root-era run left a root-owned .prom behind; every
# run of the new unit died at `mv "$TMP" "$OUT"` with EPERM and the textfile
# froze (Gatus red, fail-closed, for 4 days). niri-health hit the same class
# on 2026-09-04 from a manual run as another user.
#
# Verdict tiers:
#   FAIL (exit 1) — crisp, zero-false-positive classes:
#     A  fixed-tmp writes: (TMP|TEMP|tmp_file|tmp)="<something>.tmp" or
#        "<something>.tmp.$$" — collides with stale foreign-owned leftovers
#        and offers no self-heal. REQUIRED pattern instead:
#          TMP="$(mktemp "<dir>/<name>.prom.XXXXXX")"
#          chmod 644 "$TMP"
#          trap 'rm -f "$TMP"' EXIT
#        plus CapabilityBoundingSet = "CAP_FOWNER" on the unit when harden{}
#        is in play (not statically checkable here — review at write time).
#     B  hardcoded /run/secrets-rendered paths: real sops-nix renders
#        templates under /run/secrets/rendered (secretsDir + rendered
#        subdir). A hand-written /run/secrets-rendered literal read a path
#        that does not exist in production (mail-relay collector flagged its
#        credential missing on every run); the old mock-sops DEFAULT carried
#        the divergent path and made the VM test validate the bug. Always
#        interpolate config.sops.templates."<name>".path instead.
#
# Allowlist (reasoned, revisit on touch):
#   modules/nixos/services/memory-emergency-guard.nix
#   modules/nixos/services/sev1-escalation.nix
#     Safety-critical emergency-path units, deliberately NOT converted in the
#     mail-relay sweep (2026-09-06): both already carry
#     CAP_FOWNER + CAP_DAC_OVERRIDE, so rename-over-foreign and stale-tmp
#     replacement SUCCEED for them (the caps defeat the sticky-dir rule);
#     the fixed tmp name is survivable, conversion is cosmetic there.
#
# Usage: bash scripts/audit-textfile-tmp.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# class A allowlist: file basename — reason is documented above.
readonly A_ALLOW="memory-emergency-guard.nix sev1-escalation.nix"

fail=0
scanned=0

mapfile -t files < <(grep -rl '' --include='*.nix' \
  "$REPO_ROOT/modules" "$REPO_ROOT/platforms" "$REPO_ROOT/tests" "$REPO_ROOT/lib" \
  2>/dev/null | sort)

if [ "${#files[@]}" -eq 0 ]; then
  echo "FATAL: no .nix files found under $REPO_ROOT"
  exit 2
fi

for f in "${files[@]}"; do
  scanned=$((scanned + 1))
  rel="${f#"$REPO_ROOT"/}"
  # Comment lines document incidents (they MUST be able to name the banned
  # path/pattern) — strip them before every matcher (house convention:
  # grep -v '^[[:space:]]*#').
  code() { grep -vE '^[[:space:]]*#' "$f" || true; }

  # A. fixed-tmp textfile writes (incl. the pid-suffix mid-generation).
  while IFS= read -r line; do
    case "$A_ALLOW" in
    *"$(basename "$rel")"*) continue ;;
    esac
    echo "FAIL [$rel] A: fixed-tmp write (collides with foreign-owned leftovers in the sticky textfile dir; use mktemp + chmod 644 + trap + CAP_FOWNER):"
    echo "  $line"
    fail=1
  done < <(code | grep -nE '(TMP|TEMP|tmp_file|tmp)="?[^"]*\.tmp(\.\$\$)?"' | grep -v mktemp || true)

  # B. phantom rendered-templates path.
  while IFS= read -r line; do
    echo "FAIL [$rel] B: hardcoded /run/secrets-rendered path (real sops-nix renders under /run/secrets/rendered — interpolate config.sops.templates.\"<name>\".path):"
    echo "  $line"
    fail=1
  done < <(code | grep -n 'secrets-rendered' || true)
done

echo ""
echo "=== textfile-tmp audit: $scanned files scanned, fail=$fail ==="
exit "$fail"
