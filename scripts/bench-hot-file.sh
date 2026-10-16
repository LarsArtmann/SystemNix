#!/usr/bin/env bash
# bench-hot-file.sh — quiet-window live-FS fio bench of the Samsung hot tier.
#
# For the mounted Samsung (boot drive + /nix + hot tier since 2026-10-15),
# raw-device benching (bench-disk.sh) is impossible — it refuses mounted
# devices. This runs the same 6-workload suite against a +C scratch FILE on
# that filesystem (nodatacow/no-compression = raw-equivalent layers).
#
# Lessons baked in from the 2026-10-16 storm-contaminated run:
#   1. reads of a freshly fallocate'd file hit HOLES (no device IO — 1.5M
#      fake IOPS), so a seq-write FILLS the test region FIRST;
#   2. numbers under a concurrent IO storm are 2.5-9x depressed, so the run
#      WAITS for a quiet window (io PSI some avg10 < GATE_THRESHOLD) and
#      ABORTS when none arrives within GATE_TIMEOUT_S — a contaminated
#      dataset is worse than no dataset (v2 ran at PSI 29-42 and had to be
#      re-qualified as non-parity);
#   3. the scratch location is verified to sit on the Samsung before any
#      IO starts (kernel nvmeX names flip across boots — model-based check).
#
# Usage:
#   scripts/bench-hot-file.sh
#   GATE_TIMEOUT_S=3600 RUNTIME=30 KEEP_RAW=1 scripts/bench-hot-file.sh
#
# Env knobs:
#   GATE_THRESHOLD  io PSI some avg10 % below which the bench runs (default 20)
#   GATE_TIMEOUT_S  max seconds to wait for the window before ABORT (default 7200)
#   RUNTIME         seconds per fio test (default 15; v2 parity)
#   BASE            directory for the +C scratch (default /home/lars/.cache/nix
#                   — the Samsung users/cache subvol)
#   KEEP_RAW        1 = keep scratch dir + per-test JSONs (path printed)
set -euo pipefail

FIO="${FIO:-/nix/store/c0crr6i6gl1amh50d2xkb9ip69g0k0z8-fio-3.42/bin/fio}"
BASE="${BASE:-/home/lars/.cache/nix}"
RUNTIME="${RUNTIME:-15}"
GATE_THRESHOLD="${GATE_THRESHOLD:-20}"
GATE_TIMEOUT_S="${GATE_TIMEOUT_S:-7200}"
KEEP_RAW="${KEEP_RAW:-0}"

psi10() { grep -o 'avg10=[0-9.]*' /proc/pressure/io | head -1 | cut -d= -f2; }

[ -x "$FIO" ] || FIO="$(command -v fio || true)"
if [ -z "$FIO" ] || [ ! -x "$FIO" ]; then
  FIO="$(nix build --no-link --print-out-paths --impure --expr \
    'let f = builtins.getFlake "git+file:///home/lars/projects/SystemNix"; in f.inputs.nixpkgs.legacyPackages.x86_64-linux.fio' 2>/dev/null)/bin/fio"
fi
[ -x "$FIO" ] || {
  echo "FAIL: fio not found (set FIO=/path/to/fio; a nix build may need NIX_HEAVY_GATE_FORCE=1 while the heavy-gate shim is deployed)"
  exit 1
}
command -v jq >/dev/null || {
  echo "FAIL: jq required for result parsing"
  exit 1
}
command -v chattr >/dev/null || {
  echo "FAIL: chattr required (e2fsprogs)"
  exit 1
}

SAM=""
LEX=""
for d in /sys/class/nvme/nvme*; do
  model="$(cat "$d/model" 2>/dev/null || true)"
  case "$model" in
  *Samsung*) SAM="$d" ;;
  *Lexar*) LEX="$d" ;;
  esac
done
[ -n "$SAM" ] || {
  echo "FAIL: no Samsung NVMe found"
  exit 1
}
SAM_T="$(find -L "$SAM" -maxdepth 2 -name temp1_input 2>/dev/null | head -1 || true)"
LEX_T="$(find -L "$LEX" -maxdepth 2 -name temp1_input 2>/dev/null | head -1 || true)"

D="$(mktemp -d "$BASE/samsung-bench.XXXXXX")"
F="$D/fio.bin"
SAMPLER=0
cleanup() {
  if [ "$SAMPLER" -ne 0 ]; then
    kill "$SAMPLER" 2>/dev/null || true
  fi
  if [ "$KEEP_RAW" = "1" ]; then
    echo "KEEP_RAW=1 — raw artifacts left in $D"
  else
    rm -rf "$D"
  fi
}
trap cleanup EXIT

fallocate -l 3G "$F"
chattr +C "$F"

# the touch above settles any autofs on BASE — verify the scratch really
# sits on the Samsung before generating IO (flip-proof, model-based)
SRC="$(findmnt -nro SOURCE --target "$D")"
DEVNODE="$(printf '%s' "$SRC" | grep '^/dev/' | head -1 | sed 's/\[.*//' || true)"
BASEDEV="$(basename "$DEVNODE")"
NSDEV="${BASEDEV%p[0-9]*}"
SCRATCH_MODEL="$(cat "/sys/class/block/$NSDEV/device/model" 2>/dev/null || true)"
case "$SCRATCH_MODEL" in
*Samsung*) ;;
*)
  echo "REFUSING: scratch $D resolves to '$SRC' (device: ${DEVNODE:-none}, model: ${SCRATCH_MODEL:-unknown}) — not the Samsung; refusing to write a mislabeled parity dataset"
  exit 1
  ;;
esac

(
  while :; do
    printf '%s,%s,%s,%s\n' \
      "$(date +%s)" \
      "$(cat "$SAM_T" 2>/dev/null)" \
      "$(cat "$LEX_T" 2>/dev/null)" \
      "$(psi10)" >>"$D/samples.csv"
    sleep 2
  done
) &
SAMPLER=$!
trap cleanup EXIT

echo "### PSI gate: waiting for io some avg10 < ${GATE_THRESHOLD}% (abort after $((GATE_TIMEOUT_S / 60))min)"
waited=0
while [ "$(psi10 | cut -d. -f1)" -ge "$GATE_THRESHOLD" ]; do
  if [ "$waited" -ge "$GATE_TIMEOUT_S" ]; then
    echo "ABORT: no quiet window (io some avg10 stayed >= ${GATE_THRESHOLD}% for $((GATE_TIMEOUT_S / 60))min) — no contaminated dataset produced; retry later"
    exit 1
  fi
  sleep 30
  waited=$((waited + 30))
done
echo "### gate passed after ${waited}s at PSI io some avg10=$(psi10)% — live-FS bench on $(xargs <"$SAM/model" 2>/dev/null || echo Samsung) (+C pre-filled scratch, ${RUNTIME}s per test)"

run_test() { # <name> <rw> <extra fio args...>
  local name="$1" rw="$2"
  shift 2
  "$FIO" --name="$name" --filename="$F" --size=2G --direct=1 --ioengine=io_uring \
    --rw="$rw" --time_based --runtime="$RUNTIME" --group_reporting \
    --output-format=json --output="$D/$name.json" "$@" >/dev/null 2>&1
}

# seq write FIRST: fills the 2G region with real extents (kills the hole-read
# artifact) and doubles as the seq-write datapoint
run_test sw write --bs=1m --iodepth=1
run_test sr read --bs=1m --iodepth=1
run_test rr1 randread --bs=4k --iodepth=1
run_test rr32 randread --bs=4k --iodepth=32
run_test rw1 randwrite --bs=4k --iodepth=1
run_test fs1 randwrite --bs=4k --iodepth=1 --fsync=1

metric() { # <name> <iops|lat_us|bw_mibs>
  local f="$D/$1.json" m="$2"
  case "$m" in
  iops) jq -r '[.jobs[0].read.iops, .jobs[0].write.iops] | map(select(. != null and . > 0)) | .[0] // 0' "$f" ;;
  lat_us) jq -r '[.jobs[0].read.lat_ns.mean, .jobs[0].write.lat_ns.mean] | map(select(. != null and . > 0)) | .[0] // 0 | . / 1000' "$f" ;;
  bw_mibs) jq -r '[.jobs[0].read.bw_bytes, .jobs[0].write.bw_bytes] | map(select(. != null and . > 0)) | .[0] // 0 | . / 1048576' "$f" ;;
  esac
}
fsync_lat_us() { jq -r '.jobs[0].sync.lat_ns.mean // 0 | . / 1000' "$D/fs1.json"; }

printf '%-28s %12s %12s %12s\n' "TEST" "IOPS" "avg lat" "BW"
printf '%-28s %12s %12s %12s\n' "----" "----" "-------" "--"
printf '%-28s %12.0f %10.1fµs %9.0fMiB/s\n' "4K randread QD1" "$(metric rr1 iops)" "$(metric rr1 lat_us)" "$(metric rr1 bw_mibs)"
printf '%-28s %12.0f %10.1fµs %9.0fMiB/s\n' "4K randwrite QD1" "$(metric rw1 iops)" "$(metric rw1 lat_us)" "$(metric rw1 bw_mibs)"
printf '%-28s %12.0f %10.1fµs %9.0fMiB/s\n' "4K randread QD32" "$(metric rr32 iops)" "$(metric rr32 lat_us)" "$(metric rr32 bw_mibs)"
printf '%-28s %12.0f %10.1fµs %9.0fMiB/s\n' "4K randwrite+fsync QD1" "$(metric fs1 iops)" "$(metric fs1 lat_us)" "$(metric fs1 bw_mibs)"
printf '%-28s %12s %10.1fµs %9s\n' "  fsync (sync) latency" "" "$(fsync_lat_us)" ""
printf '%-28s %12s %12s %10.0fMiB/s\n' "1M seq read" "" "" "$(metric sr bw_mibs)"
printf '%-28s %12s %12s %10.0fMiB/s\n' "1M seq write" "" "" "$(metric sw bw_mibs)"

sleep 6
echo
echo "### temperatures (2s samples, millidegrees):"
awk -F, 'NR==1{f=$2} {if($2+0>m)m=$2+0; l=$2} END{printf "  Samsung: first %d → max %d → last %d\n", f, m, l}' "$D/samples.csv"
awk -F, 'NR==1{f=$3} {if($3+0>m)m=$3+0; l=$3} END{printf "  Lexar  : first %d → max %d → last %d\n", f, m, l}' "$D/samples.csv"
echo "  (divide by 1000 for °C)"
echo "### PSI io some avg10: pre-gate exit $(psi10)% | max during bench $(awk -F, '{if($4+0>m)m=$4+0} END{printf "%.1f", m}' "$D/samples.csv")% | now $(psi10)%"
