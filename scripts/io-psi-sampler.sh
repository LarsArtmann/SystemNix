#!/usr/bin/env bash
# io-psi-sampler.sh — windowed per-cgroup IO PSI + write-rate attribution.
#
# The trap-time tools answer "who was stalled at the instant the guard fired"
# (io-psi-forensics.sh) and "is the deploy-gate refusal real" (io-psi-crosscheck.sh).
# Neither answers "which cgroup drove the WHOLE storm window" — the 2026-10-23
# deploy-gate deferrals and the 2026-10-25 freeze-#33 autopsy both needed a
# sustained sample: per-cgroup io.pressure (some/full avg10) plus io.stat
# wbytes deltas aggregated over minutes, ranked top-N, persisted under
# ~/.cache/psi-storm/ (NOT /tmp — the 2026-10-17 volatility rule).
#
# Read-only over /sys/fs/cgroup; sampling is cheap (a few hundred file reads
# per tick) and NEVER fatal: unreadable cgroups are skipped silently.
#
# Usage:
#   io-psi-sampler.sh                     # 600s window, 5s cadence, top-20
#   io-psi-sampler.sh 300 10              # duration seconds, interval seconds
#   io-psi-sampler.sh selftest            # fixture tree, no live cgroupfs
#
# Env overrides:
#   PSI_SAMPLER_ROOT   cgroup fs root      (default /sys/fs/cgroup)
#   PSI_SAMPLER_OUT    persistence dir     (default ~/.cache/psi-storm)
#
# Output: TSV blocks to stdout (top by peak full-PSI, top by peak write-rate)
#         + one timestamped summary file per run in PSI_SAMPLER_OUT.
#         Raw per-tick samples ride along when PSI_SAMPLER_RAW=1.
# Exit codes: 0 evidence produced; 1 bad usage / selftest failure.
set -uo pipefail

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }

MODE="${1:-}"
case "$MODE" in
  selftest) SELFTEST=1; DURATION=3; INTERVAL=1;;
  -h|--help|help) usage; exit 0;;
  *[!0-9]*) usage >&2; exit 1;;
  *) SELFTEST=0; DURATION="${MODE:-600}"; INTERVAL="${2:-5}";;
esac
case "${INTERVAL:-}" in (*[!0-9]*|'') usage >&2; exit 1;; esac
[ "$INTERVAL" -ge 1 ] || { usage >&2; exit 1; }
ROOT="${PSI_SAMPLER_ROOT:-/sys/fs/cgroup}"
OUTDIR="${PSI_SAMPLER_OUT:-$HOME/.cache/psi-storm}"
TOPN=20

mkdir -p "$OUTDIR" || { echo "io-psi-sampler: cannot create $OUTDIR" >&2; exit 1; }

if [ "$SELFTEST" -eq 1 ]; then
  FIXTURE="$(mktemp -d "${OUTDIR}/selftest.XXXXXX")"
  trap 'rm -rf "$FIXTURE"' EXIT
  ROOT="$FIXTURE"
  # two cgroups: one storming (high PSI + writes), one idle — aggregation must
  # rank the storming one first in BOTH blocks. io.stat starts at zero and a
  # mid-run mutator grows it so the write-rate delta is a real tick-to-tick one.
  mkdir -p "$FIXTURE/system.slice/storm.service" "$FIXTURE/system.slice/idle.service"
  printf 'some avg10=80.00 avg60=70.00 avg300=60.00 total=1\n' > "$FIXTURE/system.slice/storm.service/io.pressure"
  printf 'full avg10=70.00 avg60=60.00 avg300=50.00 total=1\n' >> "$FIXTURE/system.slice/storm.service/io.pressure"
  printf 'some avg10=0.00 avg60=0.00 avg300=0.00 total=0\n' > "$FIXTURE/system.slice/idle.service/io.pressure"
  printf 'full avg10=0.00 avg60=0.00 avg300=0.00 total=0\n' >> "$FIXTURE/system.slice/idle.service/io.pressure"
  printf '8:0 rbytes=0 wbytes=0\n' > "$FIXTURE/system.slice/storm.service/io.stat"
  printf '8:0 rbytes=0 wbytes=0\n' > "$FIXTURE/system.slice/idle.service/io.stat"
  (
    sleep 1.2
    printf '8:0 rbytes=0 wbytes=10485760\n' > "$FIXTURE/system.slice/storm.service/io.stat"
    printf '8:0 rbytes=0 wbytes=1024\n' > "$FIXTURE/system.slice/idle.service/io.stat"
  ) &
fi

# one tick: emit "path<TAB>some_avg10<TAB>full_avg10<TAB>wbytes_total" lines
sample_tick() {
  local cg
  while IFS= read -r cg; do
    cg="${cg%/*}"                       # strip trailing /io.pressure
    local pressure wbytes
    pressure="$(awk 'NR==1{for(i=1;i<=NF;i++) if($i ~ /^avg10=/){sub("avg10=","",$i); print $i}}' "$cg/io.pressure" 2>/dev/null)" || continue
    local full10
    full10="$(awk 'NR==2{for(i=1;i<=NF;i++) if($i ~ /^avg10=/){sub("avg10=","",$i); print $i}}' "$cg/io.pressure" 2>/dev/null)"
    wbytes="$(awk '{for(i=1;i<=NF;i++) if($i ~ /^wbytes=/){sub("wbytes=","",$i); s+=$i}} END{print s+0}' "$cg/io.stat" 2>/dev/null)"
    [ -n "$pressure" ] || continue
    printf '%s\t%s\t%s\t%s\n' "${cg#"$ROOT"}" "$pressure" "${full10:-0}" "${wbytes:-0}"
  done < <(find "$ROOT" -maxdepth 5 -name io.pressure -type f 2>/dev/null | sort)
}

mkdir -p "$OUTDIR" 2>/dev/null || true   # already ensured above; keep the tick loop tolerant
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RAWFILE="$OUTDIR/samples-${STAMP}.tsv"
SUMFILE="$OUTDIR/summary-${STAMP}.tsv"

echo "io-psi-sampler: window=${DURATION}s interval=${INTERVAL}s root=$ROOT out=$OUTDIR"
TICKS=0
END=$(( $(date +%s) + DURATION ))
while [ "$(date +%s)" -lt "$END" ]; do
  sample_tick >> "$RAWFILE"
  TICKS=$((TICKS + 1))
  [ "$(date +%s)" -lt "$END" ] && sleep "$INTERVAL"
done

# aggregate: max some/full avg10, avg full, peak write-rate (max wbytes delta
# between consecutive ticks for the same cgroup, divided by the interval)
awk -F'\t' '
  { cg=$1; some=$2; full=$3; wb=$4; n[cg]++;
    if (some+0 > maxsome[cg]+0) maxsome[cg]=some+0;
    if (full+0 > maxfull[cg]+0) maxfull[cg]=full+0;
    if (n[cg] > 1) {
      rate=(wb - prevwb[cg]) / '"$INTERVAL"';
      if (rate+0 > maxrate[cg]+0) maxrate[cg]=rate+0;
    }
    prevwb[cg]=wb+0;
    sumfull[cg]+=full+0;
  }
  END { for (c in n) printf "R\t%s\t%.2f\t%.2f\t%.2f\t%.0f\n", c, maxsome[c], maxfull[c], sumfull[c]/n[c], maxrate[c]+0 }' \
  "$RAWFILE" > "$OUTDIR/agg.$$"

{
  echo -e "path\tmax_some_avg10\tmax_full_avg10\tavg_full_avg10\tpeak_write_Bps"
  sort -t$'\t' -k4,4 -rn "$OUTDIR/agg.$$" | head -n "$TOPN" | cut -f2-
  echo ""
  echo -e "path\tpeak_write_Bps\tmax_full_avg10"
  sort -t$'\t' -k6,6 -rn "$OUTDIR/agg.$$" | head -n "$TOPN" | awk -F'\t' '{printf "%s\t%s\t%s\n", $2, $6, $4}'
} | tee "$SUMFILE"
rm -f "$OUTDIR/agg.$$"

if [ "${PSI_SAMPLER_RAW:-0}" != "1" ] && [ "$SELFTEST" -eq 0 ]; then
  rm -f "$RAWFILE"   # raw per-tick data is bulky; keep only summaries by default
fi

if [ "$SELFTEST" -eq 1 ]; then
  wait
  if head -2 "$SUMFILE" | tail -1 | grep -q '^/system.slice/storm.service' \
    && grep -A1 $'^path\tpeak_write_Bps' "$SUMFILE" | tail -1 | grep -q '^/system.slice/storm.service'; then
    echo "selftest: OK (storm ranked first in both blocks)"
  else
    echo "selftest: FAIL (ranking wrong)"; cat "$SUMFILE"; exit 1
  fi
fi
exit 0
