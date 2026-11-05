#!/usr/bin/env bash
# bench-cold-load.sh, PSI-gated cold-load benchmark: time llama-server
# loading one representative GGUF off the /data QLC disk.
#
# This is the repeatable before/after probe every /data redesign leg is
# gated on (docs/planning/2026-11-03_data-redesign-latency-first-design.md
# §4/§5): A1 (chattr +C + compression-off) proof, A2 (XFS split) escalation
# trigger. It measures the M12 pain class directly, the boot-storm
# "23.4G model page-in >8min" (docs/services/llama-rag.md).
#
# What it measures: wall time from exec to /health 200 with
# --load-mode dio (DirectIO: weights are read straight off storage,
# bypassing page cache entirely, so the number is the pure storage+init
# cost and repeatable with no cache games; LM=none falls back to buffered
# reads, where the COLD=fadvise eviction is what makes it cold). Fixed
# flags = before/after runs are apples-to-apples.
#
# Lessons baked in (bench-hot-file.sh storm-contaminated-run class):
#   1. numbers under a concurrent IO storm are 2.5-9x depressed, so the run
#      WAITS for a quiet window (io PSI some avg10 < PSI_MAX) and ABORTS
#      when none arrives within PSI_WAIT_S, a contaminated dataset is
#      worse than no dataset;
#   2. PSI_ACCEPT=1 forces a run in a noisy window, the JSON marks it
#      "psi_accepted": true so downstream knows the number is noisy;
#   3. PSI io some/max during the load are sampled and reported, so a
#      mid-run storm cannot hide itself.
#
# Cold-cache eviction (COLD env):
#   drop (default), `sync` + pagecache-only drop via sudo -n (system-wide
#     but cache-only and self-healing; the PSI gate keeps it out of storms)
#   fadvise       : `vmtouch -e <model>` evicts ONLY the model file's
#     pages; needs vmtouch on PATH, no root
#
# Usage:
#   scripts/bench-cold-load.sh [model.gguf]
#   PSI_WAIT_S=3600 OUT=~/.cache/coldload/results.jsonl scripts/bench-cold-load.sh
#
# Env knobs:
#   PSI_MAX     io PSI some avg10 % below which the bench runs (default 20,
#               the house deploy-gate number)
#   PSI_WAIT_S  max seconds to wait for the window before ABORT (default 1800)
#   PSI_ACCEPT  1 = run anyway in a noisy window (default 0)
#   MODEL       GGUF path (default: llama-chat's configured modelPath default,
#               modules/nixos/services/llama-chat.nix modelPath, the 23.4G
#               Qwen3.6-35B-A3B Q4_K_P, the actual M12 pain case)
#   PORT        scratch port (default 18848; REFUSES if any listener holds it ,
#               the 09-18 rogue-port-holder class)
#   CTX         llama-server context size (default 4096; fixed = comparable)
#   NGL         GPU layers offload (default 99)
#   LM          llama-server --load-mode (default dio = DirectIO, storage-
#               bypasses page cache; LM=none reads buffered, then COLD
#               eviction is what makes the probe cold)
#   COLD        cache-eviction mode: fadvise (default: vmtouch -e, evicts
#               ONLY the model's pages; unprivileged; auto-resolves vmtouch
#               via nix) | drop (sync + pagecache drop; needs root, NOT
#               runnable from agent shells whose sandbox sets
#               no-new-privileges and hard-fails sudo)
#               caveat: fadvise on a model another process holds mmap'd
#               (e.g. the live bge-m3 embedder) sees those pages re-fault
#               warm during the run, slightly flattering the number
#   TIMEOUT_S   hard cap on the server load itself (default 1200, the QLC
#               can take ~8-12min for 23G; M12 measured >8min under storm)
#   OUT         append the final JSON line to this file (default: stdout only)
set -euo pipefail

MODEL_ARG="${1:-}"
MODEL="${MODEL_ARG:-${MODEL-}}"
MODEL="${MODEL:-/data/ai/models/jan/llamacpp/models/qwen3.6-35b-a3b-aggressive/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf}"
PORT="${PORT:-18848}"
CTX="${CTX:-4096}"
NGL="${NGL:-99}"
LM="${LM:-dio}"
COLD="${COLD:-fadvise}"
PSI_MAX="${PSI_MAX:-20}"
PSI_WAIT_S="${PSI_WAIT_S:-1800}"
PSI_ACCEPT="${PSI_ACCEPT:-0}"
TIMEOUT_S="${TIMEOUT_S:-1200}"
OUT="${OUT:-}"

psi10() { grep -o 'avg10=[0-9.]*' /proc/pressure/io | head -1 | cut -d= -f2; }

SERVER="$(command -v llama-server-rocm || command -v llama-server || true)"
[ -n "$SERVER" ] || {
  echo "FAIL: llama-server not found on PATH (expected llama-server-rocm from ai-stack, or llama-server)"
  exit 1
}
[ -r "$MODEL" ] || {
  echo "FAIL: model not readable: $MODEL"
  echo "  why: the benchmark loads the GGUF with the invoking user's rights"
  echo "  fix: pass a readable GGUF, e.g. scripts/bench-cold-load.sh /data/ai/models/gguf/bge-m3.gguf"
  exit 1
}

if ss -ltn 2>/dev/null | grep -q ":${PORT} "; then
  echo "FAIL: port $PORT already has a listener, refusing to share/bind-collide"
  echo "  why: a scratch bench server on a live port produces phantom smoke results (the 09-18 rogue-port-holder class)"
  echo "  fix: PORT=<free port> scripts/bench-cold-load.sh"
  exit 1
fi

echo "### PSI gate: waiting for io some avg10 < ${PSI_MAX}% (abort after $((PSI_WAIT_S / 60))min; PSI_ACCEPT=1 overrides)"
waited=0
psi_accepted=false
while [ "$(psi10 | cut -d. -f1)" -ge "$PSI_MAX" ]; do
  if [ "$PSI_ACCEPT" = "1" ]; then
    psi_accepted=true
    echo "WARN: PSI_ACCEPT=1, running in a NOISY window (io some avg10=$(psi10)%): the load_s number is storm-depressed (2.5-9x class) and marked psi_accepted in the JSON"
    break
  fi
  if [ "$waited" -ge "$PSI_WAIT_S" ]; then
    echo "ABORT: no quiet window (io some avg10 stayed >= ${PSI_MAX}% for $((PSI_WAIT_S / 60))min), a storm-depressed number is worse than no number"
    echo "  fix: retry in a calm window, or PSI_ACCEPT=1 to record a known-noisy probe, or PSI_MAX=<n> to relax the gate"
    exit 1
  fi
  sleep 30
  waited=$((waited + 30))
done
PSI_PRE="$(psi10)"
echo "### gate done after ${waited}s, pre-load PSI io some avg10=${PSI_PRE}% | model $(du -h "$MODEL" | cut -f1) | port $PORT | ctx $CTX | ngl $NGL"

D="$(mktemp -d /tmp/bench-cold-load.XXXXXX)"
SAMPLER=0
SRV=0
cleanup() {
  if [ "$SAMPLER" -ne 0 ]; then
    kill "$SAMPLER" 2>/dev/null || true
    wait "$SAMPLER" 2>/dev/null || true
  fi
  if [ "$SRV" -ne 0 ]; then
    kill "$SRV" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$SRV" 2>/dev/null || break
      sleep 0.5
    done
    kill -9 "$SRV" 2>/dev/null || true
  fi
  if [ "${KEEP_RAW:-0}" = "1" ]; then
    echo "KEEP_RAW=1, server log + PSI samples left in $D"
  else
    rm -rf "$D"
  fi
}
trap cleanup EXIT INT TERM

# house ROCm env (AGENTS.md GPU section): the rocm wrapper bakes
# LD_LIBRARY_PATH; the HSA overrides must come from session env, export
# them here so a bare cron/agent invocation still detects the gfx1150 GPU
export HSA_OVERRIDE_GFX_VERSION="${HSA_OVERRIDE_GFX_VERSION:-11.5.1}"
export HSA_ENABLE_SDMA="${HSA_ENABLE_SDMA:-0}"

(
  while :; do
    printf '%s,%s\n' "$(date +%s)" "$(psi10)" >>"$D/psi.csv"
    sleep 2
  done
) &
SAMPLER=$!

COLD_NOTE=""
case "$COLD" in
drop)
  if [ "$(id -u)" -eq 0 ]; then
    sync
    echo 1 >/proc/sys/vm/drop_caches
  else
    sudo -n sh -c 'sync; echo 1 > /proc/sys/vm/drop_caches' || {
      echo "FAIL: cold-cache drop needs root (sudo -n refused)"
      echo "  why: drop_caches is a root-only sysctl write; without it the model may sit warm in page cache and the probe measures a WARM load"
      echo "  fix: run sudo -n true once to prime the cached credential, or COLD=fadvise with vmtouch installed (file-scoped, no root)"
      exit 1
    }
  fi
  COLD_NOTE="sync+pagecache-drop"
  ;;
fadvise)
  VMTOUCH_BIN="$(command -v vmtouch || true)"
  if [ -z "$VMTOUCH_BIN" ]; then
    VMTOUCH_BIN="$(nix build nixpkgs#vmtouch --no-link --print-out-paths 2>/dev/null | tail -1)/bin/vmtouch"
  fi
  [ -x "$VMTOUCH_BIN" ] || {
    echo "FAIL: COLD=fadvise could not resolve vmtouch"
    echo "  why: fadvise mode evicts the model's pages via vmtouch (unprivileged, file-scoped); it is not on PATH and the nix build failed"
    echo "  fix: run 'nix build nixpkgs#vmtouch' once, or install vmtouch, or COLD=drop under a root shell"
    exit 1
  }
  "$VMTOUCH_BIN" -e "$MODEL"
  COLD_NOTE="vmtouch-fadvise"
  ;;
*)
  echo "FAIL: COLD must be drop|fadvise (got: $COLD)"
  exit 1
  ;;
esac
echo "### cache cold: $COLD_NOTE, launching llama-server (--load-mode $LM: /health 200 = bytes truly read)"

T0="$(date +%s.%N)"
"$SERVER" -m "$MODEL" \
  --host 127.0.0.1 --port "$PORT" \
  --ctx-size "$CTX" --n-gpu-layers "$NGL" \
  --load-mode "$LM" --parallel 1 \
  >"$D/server.log" 2>&1 &
SRV=$!

health_ok=false
end=$((SECONDS + TIMEOUT_S))
while [ "$SECONDS" -lt "$end" ]; do
  if curl -fsS -m 2 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    health_ok=true
    break
  fi
  kill -0 "$SRV" 2>/dev/null || break
  sleep 0.2
done
T1="$(date +%s.%N)"

PSI_POST="$(psi10)"
PSI_MAX_RUN="$(awk -F, '{if($2+0>m)m=$2+0} END{printf "%.1f", m}' "$D/psi.csv" 2>/dev/null || echo "$PSI_POST")"
PSI_AVG_RUN="$(awk -F, '{s+=$2; n++} END{if(n)printf "%.1f", s/n; else print "0"}' "$D/psi.csv" 2>/dev/null || echo "0")"

BYTES=$(stat -c %s "$MODEL")
LOAD_S=$(awk -v t0="$T0" -v t1="$T1" 'BEGIN{printf "%.2f", t1 - t0}')

if [ "$health_ok" != "true" ]; then
  echo "### RESULT: TIMEOUT after ${TIMEOUT_S}s, /health never returned 200 (last PSI avg10=${PSI_POST}%, max during run ${PSI_MAX_RUN}%)"
  echo "  server log tail:"
  tail -5 "$D/server.log" | sed 's/^/    /' || true
  echo "  fix: rerun with TIMEOUT_S=<larger> in a calmer window; KEEP_RAW=1 preserves $D/server.log"
  exit 1
fi

MB_S=$(awk -v b="$BYTES" -v s="$LOAD_S" 'BEGIN{printf "%.0f", b / 1048576 / s}')

echo
echo "### COLD LOAD RESULT"
printf '%-24s %s\n' "model" "$MODEL"
printf '%-24s %.2f GiB\n' "size" "$(awk -v b="$BYTES" 'BEGIN{printf "%.2f", b / 1073741824}')"
printf '%-24s %s s\n' "load (exec→/health 200)" "$LOAD_S"
printf '%-24s %s MiB/s\n' "effective read rate" "$MB_S"
printf '%-24s %s%% (max during run %s%%, avg %s%%)\n' "PSI io some avg10" "$PSI_POST" "$PSI_MAX_RUN" "$PSI_AVG_RUN"
printf '%-24s %s (gate<%s%%, accepted=%s)\n' "psi gate" "$PSI_PRE" "$PSI_MAX" "$psi_accepted"
printf '%-24s %s @ port %s ctx %s ngl %s\n' "server" "$SERVER" "$PORT" "$CTX" "$NGL"

JSON="$(jq -n \
  --arg ts "$(date -Is)" \
  --arg model "$MODEL" \
  --arg server "$SERVER" \
  --arg cold "$COLD_NOTE" \
  --arg lm "$LM" \
  --arg port "$PORT" \
  --arg ctx "$CTX" \
  --arg ngl "$NGL" \
  --arg psi_max "$PSI_MAX" \
  --arg psi_pre "$PSI_PRE" \
  --arg psi_post "$PSI_POST" \
  --arg psi_max_run "$PSI_MAX_RUN" \
  --arg psi_avg_run "$PSI_AVG_RUN" \
  --arg bytes "$BYTES" \
  --arg load_s "$LOAD_S" \
  --arg mb_s "$MB_S" \
  --argjson psi_accepted "$psi_accepted" \
  '{schema: 1, ts: $ts, probe: "cold-load", model: $model, bytes: ($bytes | tonumber), server: $server, cold: $cold, load_mode: $lm, port: ($port | tonumber), ctx: ($ctx | tonumber), ngl: ($ngl | tonumber), psi_gate_max: ($psi_max | tonumber), psi_pre: ($psi_pre | tonumber), psi_post: ($psi_post | tonumber), psi_max_during: ($psi_max_run | tonumber), psi_avg_during: ($psi_avg_run | tonumber), load_s: ($load_s | tonumber), mb_s: ($mb_s | tonumber), psi_accepted: $psi_accepted}')"
if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  printf '%s\n' "$JSON" >>"$OUT"
  echo "### JSON line appended to $OUT"
else
  printf '%s\n' "$JSON"
fi
