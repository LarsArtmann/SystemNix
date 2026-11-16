#!/usr/bin/env bash
# Prom-textfile tmpfile-janitor regression fixtures for the tmpfiles rule in
# modules/nixos/services/_signoz-metrics.nix (the sticky textfile_collectors
# dir).
#
# WHY: writers that die mid-write (the I/O-storm class) leak their mktemp
# temps forever in the 1777 sticky dir — the 2026-11-14 census found ~60+
# (`vm-top.prom.aB12cd` ×16, `crowdsec-counts.prom.<hash>` ×12, psi ×7,
# memory-emergency-guard ×8…). The janitor rule `R …/*.prom.* - - - 1d`
# structurally cannot touch a live file ONLY IF the glob stays anchored:
# real textfiles end at `.prom` and never match `*.prom.*`. That glob
# boundary is a one-character edit away from deleting real metrics at the
# daily clean pass — only a fixture that runs the REAL rule through
# systemd-tmpfiles against orphan-shaped and real-shaped files pins it.
#
# What is pinned (systemd 262 semantics, empirically established):
#   remove-mode  glob legs    — `--remove` honors R unconditionally: both
#                               orphan forms (`<name>.prom.XXXXXX` mktemp and
#                               `<name>.prom.tmp.<s>`) are removed, while a
#                               2-day-old REAL `.prom` file survives (the
#                               load-bearing safety property)
#   clean-mode   age gate     — `--clean` (what the daily
#                               systemd-tmpfiles-clean.timer runs, and the
#                               mode production purges ride) honors the age
#                               field: a fresh orphan SURVIVES age=1d, the
#                               same orphan is REMOVED at age=0 (the
#                               positive mechanism proof — fixture ctimes are
#                               unforgeable unprivileged, so the >1d positive
#                               leg is asserted mechanism-side, not
#                               timestamp-side)
#   clean-mode   age-0 scope  — age=0 removes ONLY glob matches: the real
#                               `.prom` still survives (an age regression
#                               cannot widen the glob)
#   wiring pin                 — the rule line is EXTRACTED from the staged
#                               module copy; a rename/retune that drops the
#                               rule (or breaks its shape) fails the test
#                               before any tree ships it.
set -uo pipefail

MODULE="${1:?usage: test-prom-tmp-janitor.sh <path/to/_signoz-metrics.nix>}"

PASS_CNT=0
FAIL_CNT=0
ok() { PASS_CNT=$((PASS_CNT + 1)); }
bad() {
  echo "FAIL: $1" >&2
  FAIL_CNT=$((FAIL_CNT + 1))
}

# ── Wiring pin: extract the REAL rule from the staged module ────────────
RULE_RAW="$(grep -oE '"R /var/lib/prometheus-node-exporter/textfile_collectors/\*\.prom\.\* - - - [0-9]+[a-z]?"' "$MODULE" | head -1 || true)"
if [ -z "$RULE_RAW" ]; then
  bad "wiring: janitor rule line not found in $(basename "$MODULE") — rule dropped, renamed, or retuned past recognition"
  echo "$PASS_CNT passed, $FAIL_CNT failed"
  exit 1
fi
ok
RULE="${RULE_RAW#\"}"
RULE="${RULE%\"}"
case "$RULE" in
  *" - - - 1d") ok ;;
  *) bad "wiring: rule age leg is not 1d (got: $RULE) — the purge cadence changed without this test being updated" ;;
esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mk_fixture() { # mk_fixture <root> — orphan forms + real textfile, real+2 orphans aged 2d
  local root=$1 d
  d="$root/var/lib/prometheus-node-exporter/textfile_collectors"
  mkdir -p "$d"
  echo 1 >"$d/vm-top.prom.aB12cd"
  echo 2 >"$d/crowdsec-counts.prom.tmp.ab12"
  echo 3 >"$d/psi.prom.zz99xx"
  echo 4 >"$d/system_health.prom"
  touch -d "2 days ago" "$d/vm-top.prom.aB12cd" "$d/crowdsec-counts.prom.tmp.ab12" "$d/system_health.prom"
}

run_rule() { # run_rule <mode> <root> <age> — applies the REAL rule with the age field swapped
  local mode=$1 root=$2 age=$3 conf
  conf="$root/etc/tmpfiles.d/prom-janitor.conf"
  mkdir -p "$(dirname "$conf")"
  printf 'R /var/lib/prometheus-node-exporter/textfile_collectors/*.prom.* - - - %s\n' "$age" >"$conf"
  systemd-tmpfiles --"$mode" --root "$root" "$conf" >/dev/null 2>&1
}

absent() { # absent <desc> <file>
  if [ ! -e "$2" ]; then ok; else bad "$1: still present: $(basename "$2")"; fi
}
present() { # present <desc> <file>
  if [ -e "$2" ]; then ok; else bad "$1: MISSING (over-deletion): $(basename "$2")"; fi
}

# ── remove-mode glob legs (unconditional R honors the glob boundary) ────
R1="$WORK/remove"
mk_fixture "$R1"
run_rule remove "$R1" 1d
absent "remove-mode: mktemp orphan form purged" "$R1/var/lib/prometheus-node-exporter/textfile_collectors/vm-top.prom.aB12cd"
absent "remove-mode: .prom.tmp. orphan form purged" "$R1/var/lib/prometheus-node-exporter/textfile_collectors/crowdsec-counts.prom.tmp.ab12"
present "remove-mode: real .prom IMMUNE to the glob (2d old)" "$R1/var/lib/prometheus-node-exporter/textfile_collectors/system_health.prom"

# ── clean-mode age gate (the mode the daily tmpfiles-clean pass runs) ───
C1="$WORK/clean-1d"
mk_fixture "$C1"
run_rule clean "$C1" 1d
present "clean-mode age=1d: fresh orphan survives (age gate refuses fresh files)" "$C1/var/lib/prometheus-node-exporter/textfile_collectors/psi.prom.zz99xx"
present "clean-mode age=1d: real .prom survives" "$C1/var/lib/prometheus-node-exporter/textfile_collectors/system_health.prom"

C2="$WORK/clean-0"
mk_fixture "$C2"
run_rule clean "$C2" 0
absent "clean-mode age=0: orphan removed (proves --clean honors R+age)" "$C2/var/lib/prometheus-node-exporter/textfile_collectors/psi.prom.zz99xx"
absent "clean-mode age=0: 2d orphan removed" "$C2/var/lib/prometheus-node-exporter/textfile_collectors/vm-top.prom.aB12cd"
present "clean-mode age=0: real .prom still immune (age cannot widen the glob)" "$C2/var/lib/prometheus-node-exporter/textfile_collectors/system_health.prom"

# ── Mutation leg: the REAL rule's age leg must be load-bearing in clean
#    mode — with the age swapped to 1d a fresh orphan stays, without it
#    (age=0) it goes. Both directions asserted above; here we assert the
#    DIFFERENCE exists (a rule whose age field does nothing is dead config).
if [ -e "$C1/var/lib/prometheus-node-exporter/textfile_collectors/psi.prom.zz99xx" ] && [ ! -e "$C2/var/lib/prometheus-node-exporter/textfile_collectors/psi.prom.zz99xx" ]; then
  ok
else
  bad "mutation: clean-mode behavior identical at age=1d and age=0 — the age leg is decorative (dead config)"
fi

echo "$PASS_CNT passed, $FAIL_CNT failed"
[ "$FAIL_CNT" -eq 0 ] || exit 1
