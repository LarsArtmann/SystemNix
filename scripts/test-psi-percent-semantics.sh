#!/usr/bin/env bash
# PSI percent-semantics regression fixtures for the psi-metrics collector
# (the script body of systemd.services.psi-metrics in
# modules/nixos/services/_signoz-metrics.nix).
#
# WHY: /proc/pressure/* reports PERCENT (0-100, two decimals). The emitter's
# thresholds once read 0.50/0.10 FRACTIONS, so `node_psi_memory_alert` fired
# at 0.5% pressure — a standing red for 8 days that survived every static
# lint and a queued wrong-file misdiagnosis (the T4 class, 2026-10-10).
# Threshold-semantics bugs are not statically lintable: only a fixture that
# drives the REAL emitter body with a REAL-shaped /proc/pressure file pins
# the kernel format against the thresholds forever.
#
# The collector body is EXTRACTED from the staged module copy (the same file
# the system builds from, never a hand-copied twin): Nix indented-string
# escapes are unescaped and the three IO seams (textfile dir, PSI file
# paths, /sys/block glob) are substituted with fixture paths. Per case:
#
#   calm             0.63% some avg10 — the exact T4 trap value; must NOT
#                    alert (0.63 > 0.50 was the fraction-form false fire)
#   boundary-some    some avg10 = 50.00 exactly — alert uses strict `>`, must
#                    stay 0 (pins > vs >=)
#   storm-some       some avg10 = 63.5 — alert 1 (percent bar crossed)
#   boundary-full    full avg10 = 10.00 exactly — alert 0 (strict `>`)
#   full-stall       full avg10 = 12.4 — alert 1
#   warning-boundary some avg60 = 20.00 — warning uses `>=`, must be 1
#   io-calm          io some avg300 = 8.5 — io_warning/alert/phantom all 0
#   io-phantom       io some avg300 = 45.2 with an empty block-device dir —
#                    io_storm computed 1 but zero disk corroboration ⇒
#                    phantom 1, alert 0, disk_busy_percent_max 0.0
#   io-boundary-40   io some avg300 = 40.00 exactly WITH a live (mutating)
#                    disk — strict `>` keeps io_storm 0, so corroboration
#                    alone cannot page: alert 0, phantom 0
#   io-boundary-401  40.01 over the bar with corroboration ⇒ alert 1 (pins
#                    the >40 storm bar from both sides)
#   corroborated-    45.2% io PSI + mid-run-mutating io_ticks (the io-psi-
#     storm          crosscheck snapshot pattern) ⇒ the full alert path
#   mutation         the extracted body with thresholds REGRESSED to the
#                    0.50/0.10/0.20/0.40 fraction form ⇒ memory_alert,
#                    memory_warning, io_warning, io_phantom all fire —
#                    proves every alert/warning leg is live (a leg that
#                    fails to fire under regression is dead)
#
# Static legs pin the threshold LITERALS: no `0.xxx` fraction comparison may
# reappear, and the percent literals (50/10/20/40) must stay present.
set -uo pipefail

MODULE="${1:?usage: test-psi-percent-semantics.sh <path/to/_signoz-metrics.nix>}"

PASS_CNT=0
FAIL_CNT=0
ok() { PASS_CNT=$((PASS_CNT + 1)); }
bad() {
  echo "FAIL: $1" >&2
  FAIL_CNT=$((FAIL_CNT + 1))
}
assert_line() { # assert_line <desc> <prom-file> <exact-metric-line>
  if grep -qxF "$3" "$2" 2>/dev/null; then ok; else bad "$1: expected line /$3/ in $(basename "$2")"; fi
}
assert_ge() { # assert_ge <desc> <prom-file> <metric> <min> (busy_max is timing-dependent, exact-line pinning would flake)
  local got
  got="$(grep -m1 "^$3 " "$2" 2>/dev/null | awk '{print $2}')"
  if [ -n "$got" ] && awk "BEGIN{exit !($got >= $4)}"; then ok; else bad "$1: expected $3 >= $4, got /$got/"; fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Extract + render the collector body from the module ──────────────────
start="$(grep -n "psiMetrics = pkgs.writeShellApplication" "$MODULE" | head -1 | cut -d: -f1)"
[ -n "$start" ] || bad "psiMetrics writer block not found in module"
text_start="$(tail -n +"$start" "$MODULE" | grep -n -m1 "text = ''$" | cut -d: -f1)"
[ -n "$text_start" ] || bad "text = '' start marker not found"
end="$(tail -n +"$((start + text_start))" "$MODULE" | grep -n -m1 "^ *'';$" | cut -d: -f1)"
[ -n "$end" ] || bad "body end marker ('';) not found"
# tail -n +K numbers its output 1-based FROM K: text_start greps from
# start (text = '' at start+text_start-1), end_rel greps from
# start+text_start (terminator at start+text_start+end-1). The body is
# the line AFTER text = '' through the line before the terminator.
end=$((start + text_start + end - 1))
sed -n "$((start + text_start)),$((end - 1))p" "$MODULE" >"$WORK/body.raw"
if grep -q 'OUT=' "$WORK/body.raw"; then ok; else bad "extraction lost the OUT line (slice start off)"; fi

# Unescape the Nix indented-string forms: ''${ → ${ first, then '' → '.
cat >"$WORK/unescape.sed" <<'SED'
s/''\${/${/g
s/''/'/g
SED
sed -f "$WORK/unescape.sed" "$WORK/body.raw" >"$WORK/body.bash"
bash -n "$WORK/body.bash" || bad "rendered collector fails bash -n"

render_case() { # render_case <out.sh> <workdir> [<body.sh>]
  sed -e "s|/var/lib/prometheus-node-exporter/textfile_collectors|$2/tfd|g" \
    -e "s|PSI=\"/proc/pressure/memory\"|PSI=\"$2/pressure-memory\"|" \
    -e "s|IO_PSI=\"/proc/pressure/io\"|IO_PSI=\"$2/pressure-io\"|" \
    -e "s|for d in /sys/block/sd\* /sys/block/nvme\*n\* /sys/block/vd\*; do|for d in $2/block/*; do|" \
    "${3:-$WORK/body.bash}" >"$1"
  bash -n "$1" || bad "rendered case fails bash -n"
}

run_case() { # run_case <name> <mem-file> <io-file> [<body.sh>] ; echoes the .prom path
  local name="$1" memfile="$2" iofile="$3" body="${4:-$WORK/body.bash}"
  local wd="$WORK/$name"
  mkdir -p "$wd/tfd" "$wd/block"
  cp "$memfile" "$wd/pressure-memory"
  cp "$iofile" "$wd/pressure-io"
  render_case "$wd/run.sh" "$wd" "$body"
  bash "$wd/run.sh" || bad "$name: collector exited nonzero"
  echo "$wd/tfd/psi.prom"
}

run_case_corroborated() { # like run_case but plants ONE live-mutating nvme stat (the io-psi-crosscheck snapshot pattern): io_ticks climb ~1000 ms per real second, so the emitter's 1s-apart reads corroborate a real stall
  local name="$1" memfile="$2" iofile="$3"
  local wd="$WORK/$name"
  mkdir -p "$wd/tfd" "$wd/block/nvme0n1"
  cp "$memfile" "$wd/pressure-memory"
  cp "$iofile" "$wd/pressure-io"
  (
    v=5000
    while :; do
      v=$((v + 50))
      printf '8 0 100 200 0 0 0 0 0 %d 0 0 0 0 0 0 0 0 0 0\n' "$v" >"$wd/block/nvme0n1/stat.tmp"
      mv "$wd/block/nvme0n1/stat.tmp" "$wd/block/nvme0n1/stat"
      sleep 0.05
    done
  ) &
  local mupd=$!
  render_case "$wd/run.sh" "$wd"
  bash "$wd/run.sh" || bad "$name: collector exited nonzero"
  kill "$mupd" 2>/dev/null
  wait "$mupd" 2>/dev/null
  echo "$wd/tfd/psi.prom"
}

CALM_IO="$WORK/fx-io-calm"
cat >"$CALM_IO" <<'EOF'
some avg10=0.10 avg60=0.20 avg300=8.50 total=1000
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
EOF

# calm — the exact T4 trap: 0.63% must NOT trip the 0.50 fraction form
CALM_MEM="$WORK/fx-mem-calm"
cat >"$CALM_MEM" <<'EOF'
some avg10=0.63 avg60=0.42 avg300=0.31 total=123456789
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
EOF
prom="$(run_case calm "$CALM_MEM" "$CALM_IO")"
assert_line "calm" "$prom" "node_psi_memory_alert 0"
assert_line "calm" "$prom" "node_psi_memory_warning 0"
assert_line "calm" "$prom" "node_psi_io_alert 0"
assert_line "calm" "$prom" "node_psi_io_phantom 0"
assert_line "calm" "$prom" "node_disk_busy_percent_max 0.0"

# boundary-some — 50.00 exactly: strict `>`, alert stays 0
B_MEM="$WORK/fx-mem-b50"
cat >"$B_MEM" <<'EOF'
some avg10=50.00 avg60=4.00 avg300=1.10 total=123456789
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
EOF
prom="$(run_case boundary-some "$B_MEM" "$CALM_IO")"
assert_line "boundary-some" "$prom" "node_psi_memory_alert 0"

# storm-some — 63.5% crosses the 50 percent bar
S_MEM="$WORK/fx-mem-storm"
cat >"$S_MEM" <<'EOF'
some avg10=63.50 avg60=55.00 avg300=48.00 total=123456789
full avg10=2.20 avg60=1.10 avg300=0.40 total=123456789
EOF
prom="$(run_case storm-some "$S_MEM" "$CALM_IO")"
assert_line "storm-some" "$prom" "node_psi_memory_alert 1"

# boundary-full — full avg10 = 10.00 exactly stays 0 (strict `>`)
BF_MEM="$WORK/fx-mem-bf10"
cat >"$BF_MEM" <<'EOF'
some avg10=1.20 avg60=0.90 avg300=0.50 total=123456789
full avg10=10.00 avg60=3.00 avg300=1.00 total=123456789
EOF
prom="$(run_case boundary-full "$BF_MEM" "$CALM_IO")"
assert_line "boundary-full" "$prom" "node_psi_memory_alert 0"

# full-stall — full avg10 = 12.4 crosses the 10 percent bar with calm some
F_MEM="$WORK/fx-mem-full"
cat >"$F_MEM" <<'EOF'
some avg10=1.20 avg60=0.90 avg300=0.50 total=123456789
full avg10=12.40 avg60=6.00 avg300=2.00 total=123456789
EOF
prom="$(run_case full-stall "$F_MEM" "$CALM_IO")"
assert_line "full-stall" "$prom" "node_psi_memory_alert 1"

# warning-boundary — some avg60 = 20.00 exactly: `>=`, warning fires
W_MEM="$WORK/fx-mem-w20"
cat >"$W_MEM" <<'EOF'
some avg10=1.20 avg60=20.00 avg300=18.00 total=123456789
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
EOF
prom="$(run_case warning-boundary "$W_MEM" "$CALM_IO")"
assert_line "warning-boundary" "$prom" "node_psi_memory_warning 1"
assert_line "warning-boundary" "$prom" "node_psi_memory_alert 0"

# io-calm — io some avg300 = 8.5 under every io threshold
prom="$(run_case io-calm "$CALM_MEM" "$CALM_IO")"
assert_line "io-calm" "$prom" "node_psi_io_warning 0"
assert_line "io-calm" "$prom" "node_psi_io_alert 0"
assert_line "io-calm" "$prom" "node_psi_io_phantom 0"

# io-phantom — 45.2% io PSI over the 40 storm bar, zero disks to corroborate
IO_P="$WORK/fx-io-phantom"
cat >"$IO_P" <<'EOF'
some avg10=52.00 avg60=48.00 avg300=45.20 total=1000
full avg10=30.00 avg60=20.00 avg300=15.00 total=1000
EOF
prom="$(run_case io-phantom "$CALM_MEM" "$IO_P")"
assert_line "io-phantom" "$prom" "node_psi_io_warning 1"
assert_line "io-phantom" "$prom" "node_psi_io_alert 0"
assert_line "io-phantom" "$prom" "node_psi_io_phantom 1"
assert_line "io-phantom" "$prom" "node_disk_busy_percent_max 0.0"

# io-boundary-40 — avg300 = 40.00 exactly with a LIVE disk: strict `>` keeps
# io_storm 0, so corroboration alone cannot page (phantom 0 — the disk IS
# corroborating, the storm bar just is not crossed)
B40="$WORK/fx-io-b40"
cat >"$B40" <<'EOF'
some avg10=52.00 avg60=48.00 avg300=40.00 total=1000
full avg10=30.00 avg60=20.00 avg300=15.00 total=1000
EOF
prom="$(run_case_corroborated io-boundary-40 "$CALM_MEM" "$B40")"
assert_line "io-boundary-40" "$prom" "node_psi_io_warning 1"
assert_line "io-boundary-40" "$prom" "node_psi_io_alert 0"
assert_line "io-boundary-40" "$prom" "node_psi_io_phantom 0"

# io-boundary-401 — one hundredth over the bar, same live disk: alert 1
# (pins the >40 storm bar from BOTH sides at the exact boundary)
B401="$WORK/fx-io-b401"
cat >"$B401" <<'EOF'
some avg10=52.00 avg60=48.00 avg300=40.01 total=1000
full avg10=30.00 avg60=20.00 avg300=15.00 total=1000
EOF
prom="$(run_case_corroborated io-boundary-401 "$CALM_MEM" "$B401")"
assert_line "io-boundary-401" "$prom" "node_psi_io_warning 1"
assert_line "io-boundary-401" "$prom" "node_psi_io_alert 1"
assert_line "io-boundary-401" "$prom" "node_psi_io_phantom 0"
assert_ge "io-boundary-401" "$prom" "node_disk_busy_percent_max" 10.0

# corroborated-storm — 45.2% io PSI plus a mid-run-mutating io_ticks stat:
# the FULL alert path the io-phantom case can never reach
prom="$(run_case_corroborated corroborated-storm "$CALM_MEM" "$IO_P")"
assert_line "corroborated-storm" "$prom" "node_psi_io_alert 1"
assert_line "corroborated-storm" "$prom" "node_psi_io_phantom 0"

# mutation — regress every threshold to the T4 fraction form and prove each
# alert/warning leg FIRES (a leg that stays 0 under regression is dead code,
# and the positive legs above would then be pinning nothing)
MUT="$WORK/body-mutated.bash"
sed -e 's/> 50/> 0.50/g' -e 's/> 10/> 0.10/g' -e 's/>= 20/>= 0.20/g' -e 's/> 40/> 0.40/g' \
  "$WORK/body.bash" >"$MUT"
prom="$(run_case mutation "$CALM_MEM" "$CALM_IO" "$MUT")"
assert_line "mutation" "$prom" "node_psi_memory_alert 1"
assert_line "mutation" "$prom" "node_psi_memory_warning 1"
assert_line "mutation" "$prom" "node_psi_io_warning 1"
assert_line "mutation" "$prom" "node_psi_io_phantom 1"
assert_line "mutation" "$prom" "node_psi_io_alert 0"

# ── Static legs: the threshold literals themselves ───────────────────────
if grep -qE '(>|\>=) *0\.[0-9]' "$WORK/body.bash"; then
  bad "static: fraction-form threshold comparison reappeared in the emitter (the T4 class)"
else
  ok
fi
for lit in '> 50' '> 10' '>= 20' '> 40'; do
  if grep -qF "$lit" "$WORK/body.bash"; then ok; else bad "static: percent threshold literal /$lit/ missing from the emitter"; fi
done

echo "psi percent-semantics fixtures: $PASS_CNT passed, $FAIL_CNT failed"
[ "$FAIL_CNT" -eq 0 ]
