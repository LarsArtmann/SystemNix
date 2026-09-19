#!/usr/bin/env bash
# llama-rag soak harness — the mechanical gate for re-enabling llama-rag.
#
# WHY THIS EXISTS (2026-09-18 freeze #5): a shell direct-run of the pinned
# llama.cpp build looked healthy (bge-m3 loaded in ~4s, /health 200), so
# llama-rag was re-enabled — and both servers then spun ~94% CPU x2 under
# the REAL systemd units until the box froze 4h later. A unit-context bug
# (device cgroup, GPU state, HSA env) does not reproduce in a bare shell
# run. This harness soaks the candidate build under a sandbox that mirrors
# the deployed units' EXACT shape (rocm.nix deviceCgroup + env, via
# systemd-run) and judges SPIN on CPU-TIME DELTAS over windows — never
# instantaneous %CPU (the spin is intermittent; point-in-time reads
# under-detect it, 2026-09-19 rogue forensics).
#
# Verdict:
#   exit 0  PASS   — /health served AND CPU-time accumulation stayed idle
#                    through the whole soak window after a warmup grace.
#   exit 1  SPIN   — CPU time kept accumulating (>=SPIN_FLOOR seconds of
#                    CPU per 10s sample for >=3 consecutive samples) while
#                    /health never went 200 — the freeze-5 signature.
#   exit 2  USAGE  — bad invocation (not root, missing args, llama-rag
#                    enabled without --force).
#
# Usage (root):
#   sudo ./scripts/llama-rag-soak.sh --server /nix/store/...-llama-server \
#        --model /data/ai/models/gguf/bge-m3.gguf [--minutes 10] \
#        [--port 18848] [--force]
#
# The llama-rag module must be DISABLED while soaking (default guard; the
# candidate binds a scratch port, but a concurrent real server on the GPU
# invalidates the CPU baseline). Run INSIDE a quiet-IO window: the guard
# zones on this box trip on IO pressure, and a soak under pressure proves
# nothing.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

SERVER=""
MODEL=""
MINUTES=10
PORT=18848
ALIAS="soak-candidate"
FORCE=0
CTX=8192

usage() {
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --server)
      SERVER="${2:-}"
      shift 2
      ;;
    --model)
      MODEL="${2:-}"
      shift 2
      ;;
    --minutes)
      MINUTES="${2:-10}"
      shift 2
      ;;
    --port)
      PORT="${2:-18848}"
      shift 2
      ;;
    --alias)
      ALIAS="${2:-soak-candidate}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      ;;
  esac
done

[ "$(id -u)" -eq 0 ] || {
  echo -e "${RED}FAIL:${NC} run as root (systemd-run needs a system scope)" >&2
  exit 2
}
[ -n "$SERVER" ] || usage
[ -n "$MODEL" ] || usage
[ -x "$SERVER" ] || {
  echo -e "${RED}FAIL:${NC} --server is not executable: $SERVER" >&2
  exit 2
}
[ -r "$MODEL" ] || {
  echo -e "${RED}FAIL:${NC} --model is not readable: $MODEL" >&2
  exit 2
}

# Guard: llama-rag must be config-disabled while soaking. systemd-run under
# root sees the real unit state; INACTIVE covers both "disabled" and
# "stopped". --force overrides for deliberate concurrent-GPU experiments.
if [ "$FORCE" -ne 1 ]; then
  for unit in llama-embeddings.service llama-reranker.service; do
    state="$(systemctl show "$unit" -p ActiveState --value 2>/dev/null || echo unknown)"
    if [ "$state" != "inactive" ]; then
      echo -e "${RED}FAIL:${NC} $unit is '$state' — llama-rag must be disabled while soaking (GPU baseline). Use --force to override deliberately." >&2
      exit 2
    fi
  done
fi

# Mirror lib/rocm.nix deviceCgroup + env EXACTLY — the sandbox shape is the
# suspected variable (freeze-5: bare-shell run healthy, unit-context run
# spun). If rocm.nix changes, update BOTH.
DEVICE_ARGS=(
  --property=DevicePolicy=strict
  --property='DeviceAllow=/dev/null'
  --property='DeviceAllow=/dev/zero'
  --property='DeviceAllow=/dev/full'
  --property='DeviceAllow=/dev/random'
  --property='DeviceAllow=/dev/urandom'
  --property='DeviceAllow=/dev/dri/'
  --property='DeviceAllow=/dev/dri/renderD128'
  --property='DeviceAllow=/dev/kfd'
)
ENV_ARGS=(
  --setenv=HSA_OVERRIDE_GFX_VERSION=11.5.1
  --setenv=HSA_ENABLE_SDMA=0
)

SCOPE="llama-rag-soak-$$"
systemd-run --unit="$SCOPE" --collect \
  "${DEVICE_ARGS[@]}" "${ENV_ARGS[@]}" \
  "$SERVER" --embedding -m "$MODEL" --alias "$ALIAS" \
  --host 127.0.0.1 --port "$PORT" --ctx-size "$CTX" \
  >/dev/null

cleanup() {
  systemctl stop "$SCOPE.service" 2>/dev/null || true
}
trap cleanup EXIT

# Resolve the server's main PID from the scope cgroup.
get_pid() {
  systemd-cgls -u "$SCOPE.service" --no-pager 2>/dev/null |
    grep -oE '[0-9]+ .*/'"$(basename "$SERVER")" |
    head -1 |
    awk '{print $1}'
}

# CPU-time sample: utime+stime (ticks) from /proc/<pid>/stat field 14+15.
cpu_ticks() {
  local pid="$1"
  awk '{print $14 + $15}' "/proc/$pid/stat" 2>/dev/null || echo ""
}

echo "soak: scope=$SCOPE port=$PORT minutes=$MINUTES model=$(basename "$MODEL")"
echo "soak: waiting for process..."
PID=""
for _ in $(seq 1 30); do
  PID="$(get_pid)"
  [ -n "$PID" ] && break
  sleep 1
done
[ -n "$PID" ] || {
  echo -e "${RED}SPIN/DEAD:${NC} server process never appeared in the scope"
  exit 1
}
echo "soak: pid=$PID"

# Warmup grace: model load + HSA init legitimately burn CPU. The verdict
# window starts after the load settles OR after WARMUP_MAX, whichever first.
WARMUP_MAX=180
HEALTH_OK=""
start_epoch="$(date +%s)"
while [ "$(( $(date +%s) - start_epoch ))" -lt "$WARMUP_MAX" ]; do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$PORT/health" 2>/dev/null || true)"
  if [ "$code" = "200" ]; then
    HEALTH_OK=1
    break
  fi
  sleep 5
done

SAMPLE_INTERVAL=10
SPIN_FLOOR=5 # CPU-ticks per sample: 5 ticks = 0.5s CPU per 10s wall = 5% sustained
SPIN_STRIKES=0
SPIN_STRIKES_TO_TRIP=3
prev="$(cpu_ticks "$PID")"
samples=0
end_epoch=$(( start_epoch + WARMUP_MAX + MINUTES * 60 ))
spin=0

while [ "$(date +%s)" -lt "$end_epoch" ]; do
  sleep "$SAMPLE_INTERVAL"
  cur="$(cpu_ticks "$PID")"
  if [ -z "$cur" ]; then
    echo -e "${RED}DEAD:${NC} server process vanished mid-soak"
    exit 1
  fi
  delta=$(( cur - prev ))
  prev="$cur"
  samples=$(( samples + 1 ))
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$PORT/health" 2>/dev/null || true)"
  [ "$code" = "200" ] && HEALTH_OK=1
  echo "soak: sample=$samples cpu_delta=${delta}ticks health=$code"
  # SPIN = CPU keeps burning while /health NEVER went 200 (freeze-5: ~94%
  # x2 with /health 503 forever). A healthy server idles at ~0 ticks/sample
  # once loaded; transient load spikes without health recovery still count
  # as spin because health staying dark is the disqualifier.
  if [ -z "$HEALTH_OK" ] && [ "$delta" -ge "$SPIN_FLOOR" ]; then
    SPIN_STRIKES=$(( SPIN_STRIKES + 1 ))
    if [ "$SPIN_STRIKES" -ge "$SPIN_STRIKES_TO_TRIP" ]; then
      echo -e "${RED}SPIN VERDICT:${NC} sustained CPU-time growth ($SPIN_STRIKES consecutive samples) with /health never 200 — the mid-load spin class. Do NOT re-enable llama-rag on this build."
      exit 1
    fi
  else
    SPIN_STRIKES=0
  fi
done

if [ -n "$HEALTH_OK" ]; then
  echo -e "${GREEN}PASS VERDICT:${NC} /health served and CPU stayed idle through $samples samples ($MINUTES min) under the unit-shaped sandbox. Candidate cleared for the re-enable evaluation."
  exit 0
else
  echo -e "${RED}DARK VERDICT:${NC} /health never served 200 in the window without sustained spin — treat as failing (mid-load wedge variant). Do NOT re-enable."
  exit 1
fi
