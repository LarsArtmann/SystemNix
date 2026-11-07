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
#   MODEL       GGUF path (default: DERIVED at runtime from llama-chat.nix's
#               modelPath option default — the swap-brain runbook
#               (docs/services/llama-chat.md "Swap the brain") edits exactly
#               that line, so the bench default cannot silently stale; a
#               hardcoded 2026-11-05 fallback + WARN covers runs outside a
#               checkout. A swap via an override elsewhere (not the module
#               default) is invisible to the derive — pass MODEL= explicitly)
#   PORT        scratch port (default 18848; REFUSES if any listener holds it ,
#               the 09-18 rogue-port-holder class)
#   CTX         llama-server context size (default 4096; fixed = comparable)
#   NGL         GPU layers offload (default 99)
#   EMBED       0 = auto (default): the GGUF header's general.architecture
#               is parsed (first 16 KB, unprivileged, no gguf-py) and
#               embedding-family arches (bert/nomic-bert/jina-bert class)
#               get --embedding automatically (embed_auto=true recorded in
#               the JSON) — they GGML_ASSERT-crash in init without the
#               flag, the missing-flag abort misattributed to dio on
#               2026-11-05; 1 = force the flag (WARNs on a non-embedding
#               arch)
#   LM          llama-server --load-mode (default none = plain buffered
#               reads. dio's old "SIGABRTs under memory pressure" note was
#               a misattribution: the two 2026-11-05 aborts fired on bge-m3
#               WITHOUT --embedding in BOTH load-modes (dio 02:02:08, none
#               02:05:15 per coredumpctl), and the KEEP_RAW rerun
#               reproduced it deterministically at zero memory pressure
#               with the reason captured: llama-context.cpp:2275
#               GGML_ASSERT(n_outputs_max <= cparams.n_outputs_max) — the
#               missing-embedding assert, not a dio defect. dio stays
#               opt-in only for fixed-flag comparability with the none
#               baseline. With LM=none the COLD eviction is what makes the
#               probe cold)
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
#   OUT         append a JSON line per run to this file (default: stdout
#               only); FAILED runs append event=dead-server / event=timeout
#               lines carrying the crash-reason excerpt + PSI context, so
#               crash forensics join the measurement stream instead of
#               living only in the KEEP_RAW scratch dir
#
# 2026-11-07 hardening (queue rows):
#   - scratch dir lives under ~/.cache (durable), never /tmp — tmpfiles
#     wiped KEEP_RAW evidence mid-session twice (the /tmp-volatility trap)
#   - psi.csv + JSON carry mem PSI beside io (psi_mem_*), so "reproduced at
#     zero memory pressure" rests on at-crash samples, not a pre-run read
#   - the gate needs hysteresis: 2 consecutive calm polls ≥10s apart (a
#     single avg10 dip can sit inside a resuming storm cell — the 2026-11-05
#     strict-gate dio run launched on one dip and a cell resumed mid-run)
set -euo pipefail

MODEL_ARG="${1:-}"
MODEL="${MODEL_ARG:-${MODEL-}}"
if [ -z "$MODEL" ]; then
  LLAMA_CHAT_NIX="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/modules/nixos/services/llama-chat.nix"
  DERIVED_MODEL=""
  if [ -r "$LLAMA_CHAT_NIX" ]; then
    DERIVED_MODEL="$(sed -n '/modelPath = lib.mkOption/,/};/p' "$LLAMA_CHAT_NIX" | grep -o 'default = "[^"]*"' | head -1 | cut -d'"' -f2)"
  fi
  if [ -n "$DERIVED_MODEL" ]; then
    MODEL="$DERIVED_MODEL"
    echo "### default model derived from llama-chat.nix: $MODEL"
  else
    MODEL="/data/ai/models/jan/llamacpp/models/qwen3.6-35b-a3b-aggressive/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf"
    echo "WARN: could not derive llama-chat modelPath default ($LLAMA_CHAT_NIX unreadable or option block moved), using hardcoded 2026-11-05 fallback"
  fi
fi
PORT="${PORT:-18848}"
CTX="${CTX:-4096}"
NGL="${NGL:-99}"
EMBED="${EMBED:-0}"
LM="${LM:-none}"
COLD="${COLD:-fadvise}"
PSI_MAX="${PSI_MAX:-20}"
PSI_WAIT_S="${PSI_WAIT_S:-1800}"
PSI_ACCEPT="${PSI_ACCEPT:-0}"
TIMEOUT_S="${TIMEOUT_S:-1200}"
OUT="${OUT:-}"

psi10() { grep -o 'avg10=[0-9.]*' /proc/pressure/io | head -1 | cut -d= -f2; }
mem10() { grep -o 'avg10=[0-9.]*' /proc/pressure/memory | head -1 | cut -d= -f2; }

gguf_arch() {
  # Parse general.architecture out of the GGUF header: v2/v3 layout is
  # magic(4) ver(4) tensors(8) kvs(8), then KVs of
  # [u64 keylen][key][u32 vtype][value]. The arch string is KV[0] in
  # llama.cpp-produced files, but the walk skips scalar/string KVs ahead
  # of it and bails (exit 1, no output) on the first array/unknown/v1
  # layout instead of guessing.
  head -c 16384 "$1" 2>/dev/null | od -An -tu1 -v | tr -s ' \n' ' ' | awk '
    { n = split($0, b, " "); p = 1
      if (b[1] != 71 || b[2] != 71 || b[3] != 85 || b[4] != 70) exit 1
      p = 5
      ver = b[p] + 256 * b[p+1] + 65536 * b[p+2] + 16777216 * b[p+3]
      if (ver < 2) exit 1
      p += 12
      k = b[p] + b[p+1] * 256 + b[p+2] * 65536 + b[p+3] * 16777216 + b[p+4] * 256^4 + b[p+5] * 256^5 + b[p+6] * 256^6 + b[p+7] * 256^7
      p += 8
      split("1 1 2 2 4 4 4 1 0 0 8 8 8", sz, " ")
      for (i = 0; i < k && p + 8 <= n; i++) {
        kl = b[p] + b[p+1] * 256 + b[p+2] * 65536 + b[p+3] * 16777216 + b[p+4] * 256^4 + b[p+5] * 256^5 + b[p+6] * 256^6 + b[p+7] * 256^7
        p += 8
        key = ""
        for (j = 0; j < kl && p + j <= n; j++) key = key sprintf("%c", b[p+j])
        p += kl
        vt = b[p] + 256 * b[p+1] + 65536 * b[p+2] + 16777216 * b[p+3]
        p += 4
        if (vt == 8) {
          vl = b[p] + b[p+1] * 256 + b[p+2] * 65536 + b[p+3] * 16777216 + b[p+4] * 256^4 + b[p+5] * 256^5 + b[p+6] * 256^6 + b[p+7] * 256^7
          p += 8
          if (key == "general.architecture") {
            val = ""
            for (j = 0; j < vl && p + j <= n; j++) val = val sprintf("%c", b[p+j])
            print val
            exit 0
          }
          p += vl
        } else if (vt == 13) exit 1
        else if (vt >= 0 && vt <= 12 && sz[vt+1] > 0) p += sz[vt+1]
        else exit 1
      }
      exit 1
    }'
}

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

EMBED_ARCH="$(gguf_arch "$MODEL" || true)"
EMBED_AUTO=false
case "$EMBED_ARCH" in
bert | nomic-bert | jina-bert | jina-bert-v2)
  if [ "$EMBED" != "1" ]; then
    EMBED=1
    EMBED_AUTO=true
    echo "### auto-embedding: GGUF arch '$EMBED_ARCH' is embedding-family, enabling --embedding (embed_auto=true in the JSON)"
    echo "  why: embedding GGUFs GGML_ASSERT-crash in init without the flag (the 2026-11-05 dio misattribution class); EMBED=0 now means auto, not force-off"
  fi
  ;;
"")
  echo "WARN: could not parse general.architecture from the GGUF header (v1 or exotic layout); EMBED=$EMBED is used as-is"
  ;;
*)
  if [ "$EMBED" = "1" ]; then
    echo "WARN: EMBED=1 but GGUF arch '$EMBED_ARCH' is not embedding-family; --embedding passed as requested"
  fi
  ;;
esac

if ss -ltn 2>/dev/null | grep -q ":${PORT} "; then
  echo "FAIL: port $PORT already has a listener, refusing to share/bind-collide"
  echo "  why: a scratch bench server on a live port produces phantom smoke results (the 09-18 rogue-port-holder class)"
  echo "  fix: PORT=<free port> scripts/bench-cold-load.sh"
  exit 1
fi

echo "### PSI gate: waiting for io some avg10 < ${PSI_MAX}% held on 2 consecutive polls ≥10s apart (hysteresis; abort after $((PSI_WAIT_S / 60))min; PSI_ACCEPT=1 overrides)"
waited=0
psi_accepted=false
calm_streak=0
PSI_POLL_S=10
while :; do
  now10="$(psi10 | cut -d. -f1)"
  if [ "$now10" -lt "$PSI_MAX" ]; then
    calm_streak=$((calm_streak + 1))
    if [ "$calm_streak" -ge 2 ]; then
      break
    fi
  else
    calm_streak=0
    if [ "$PSI_ACCEPT" = "1" ]; then
      psi_accepted=true
      echo "WARN: PSI_ACCEPT=1, running in a NOISY window (io some avg10=${now10}%): the load_s number is storm-depressed (2.5-9x class) and marked psi_accepted in the JSON"
      break
    fi
    if [ "$waited" -ge "$PSI_WAIT_S" ]; then
      echo "ABORT: no quiet window (io some avg10 stayed >= ${PSI_MAX}% for $((PSI_WAIT_S / 60))min), a storm-depressed number is worse than no number"
      echo "  fix: retry in a calm window, or PSI_ACCEPT=1 to record a known-noisy probe, or PSI_MAX=<n> to relax the gate"
      exit 1
    fi
  fi
  sleep "$PSI_POLL_S"
  waited=$((waited + PSI_POLL_S))
done
PSI_PRE="$(psi10)"
MEM_PRE="$(mem10)"
echo "### gate done after ${waited}s (${calm_streak} consecutive calm polls), pre-load PSI io some avg10=${PSI_PRE}% mem avg10=${MEM_PRE}% | model $(du -h "$MODEL" | cut -f1) | port $PORT | ctx $CTX | ngl $NGL"

D="$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/bench-cold-load.XXXXXX")"
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
    printf '%s,%s,%s\n' "$(date +%s)" "$(psi10)" "$(mem10)" >>"$D/psi.csv"
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
EMBED_FLAGS=""
if [ "$EMBED" = "1" ]; then
  EMBED_FLAGS="--embedding"
fi
# shellcheck disable=SC2086
"$SERVER" -m "$MODEL" $EMBED_FLAGS \
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
  srv_state="$(awk '{print $3}' "/proc/${SRV}/stat" 2>/dev/null || echo dead)"
  case "$srv_state" in
  dead | Z)
    echo "### server process died (state=$srv_state) before /health went 200"
    break
    ;;
  esac
  sleep 0.2
done
T1="$(date +%s.%N)"

PSI_POST="$(psi10)"
MEM_POST="$(mem10)"
PSI_MAX_RUN="$(awk -F, '{if($2+0>m)m=$2+0} END{printf "%.1f", m}' "$D/psi.csv" 2>/dev/null || echo "$PSI_POST")"
PSI_AVG_RUN="$(awk -F, '{s+=$2; n++} END{if(n)printf "%.1f", s/n; else print "0"}' "$D/psi.csv" 2>/dev/null || echo "0")"
MEM_MAX_RUN="$(awk -F, '{if($3+0>m)m=$3+0} END{printf "%.1f", m}' "$D/psi.csv" 2>/dev/null || echo "$MEM_POST")"
MEM_AVG_RUN="$(awk -F, '{s+=$3; n++} END{if(n)printf "%.1f", s/n; else print "0"}' "$D/psi.csv" 2>/dev/null || echo "0")"

BYTES=$(stat -c %s "$MODEL")
LOAD_S=$(awk -v t0="$T0" -v t1="$T1" 'BEGIN{printf "%.2f", t1 - t0}')

if [ "$health_ok" != "true" ]; then
  srv_state="$(awk '{print $3}' "/proc/${SRV}/stat" 2>/dev/null || echo dead)"
  case "$srv_state" in
  dead | Z) bench_event="dead-server" ;;
  *) bench_event="timeout" ;;
  esac
  reason="$(grep -aiE 'ggml_assert|fatal|abort|terminate|exception|error|failed' "$D/server.log" 2>/dev/null | tail -2 | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-400)"
  [ -n "$reason" ] || reason="$(tail -c 400 "$D/server.log" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g')"
  [ -n "$reason" ] || reason="(server log empty)"
  echo "### RESULT: FAILED ($bench_event), /health never returned 200 within ${TIMEOUT_S}s (last PSI avg10=${PSI_POST}%, max during run ${PSI_MAX_RUN}%)"
  echo "  reason excerpt: $reason"
  echo "  server log head (crash reason lives here):"
  head -8 "$D/server.log" | sed 's/^/    /' || true
  echo "  server log tail:"
  tail -3 "$D/server.log" | sed 's/^/    /' || true
  echo "  fix: KEEP_RAW=1 preserves $D/server.log; a dead-server line above means the load-mode or GPU env aborted (try LM=none), a timeout line means rerun with TIMEOUT_S=<larger> in a calmer window"
  FAIL_JSON="$(jq -c -n \
    --arg ts "$(date -Is)" \
    --arg model "$MODEL" \
    --arg lm "$LM" \
    --arg port "$PORT" \
    --arg ctx "$CTX" \
    --arg ngl "$NGL" \
    --arg bytes "$BYTES" \
    --arg timeout_s "$TIMEOUT_S" \
    --arg psi_max "$PSI_MAX" \
    --arg psi_pre "$PSI_PRE" \
    --arg psi_post "$PSI_POST" \
    --arg psi_max_run "$PSI_MAX_RUN" \
    --arg psi_avg_run "$PSI_AVG_RUN" \
    --arg mem_pre "$MEM_PRE" \
    --arg mem_post "$MEM_POST" \
    --arg mem_max_run "$MEM_MAX_RUN" \
    --arg mem_avg_run "$MEM_AVG_RUN" \
    --arg embed_arch "$EMBED_ARCH" \
    --argjson embed_auto "$EMBED_AUTO" \
    --argjson psi_accepted "$psi_accepted" \
    --arg event "$bench_event" \
    --arg reason "$reason" \
    '{schema: 1, ts: $ts, probe: "cold-load", event: $event, model: $model, bytes: ($bytes | tonumber), load_mode: $lm, port: ($port | tonumber), ctx: ($ctx | tonumber), ngl: ($ngl | tonumber), timeout_s: ($timeout_s | tonumber), psi_gate_max: ($psi_max | tonumber), psi_pre: ($psi_pre | tonumber), psi_post: ($psi_post | tonumber), psi_max_during: ($psi_max_run | tonumber), psi_avg_during: ($psi_avg_run | tonumber), psi_mem_pre: ($mem_pre | tonumber), psi_mem_post: ($mem_post | tonumber), psi_mem_max_during: ($mem_max_run | tonumber), psi_mem_avg_during: ($mem_avg_run | tonumber), psi_accepted: $psi_accepted, embed_arch: $embed_arch, embed_auto: $embed_auto, reason: $reason}')"
  if [ -n "$OUT" ]; then
    mkdir -p "$(dirname "$OUT")"
    printf '%s\n' "$FAIL_JSON" >>"$OUT"
    echo "### failure JSON line appended to $OUT"
  else
    printf '%s\n' "$FAIL_JSON"
  fi
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
printf '%-24s %s%% (max during run %s%%, avg %s%%)\n' "PSI mem some avg10" "$MEM_POST" "$MEM_MAX_RUN" "$MEM_AVG_RUN"
printf '%-24s %s (gate<%s%%, accepted=%s)\n' "psi gate" "$PSI_PRE" "$PSI_MAX" "$psi_accepted"
printf '%-24s %s @ port %s ctx %s ngl %s\n' "server" "$SERVER" "$PORT" "$CTX" "$NGL"

JSON="$(jq -c -n \
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
  --arg mem_pre "$MEM_PRE" \
  --arg mem_post "$MEM_POST" \
  --arg mem_max_run "$MEM_MAX_RUN" \
  --arg mem_avg_run "$MEM_AVG_RUN" \
  --arg bytes "$BYTES" \
  --arg load_s "$LOAD_S" \
  --arg mb_s "$MB_S" \
  --arg embed_arch "$EMBED_ARCH" \
  --argjson embed_auto "$EMBED_AUTO" \
  --argjson psi_accepted "$psi_accepted" \
  '{schema: 1, ts: $ts, probe: "cold-load", model: $model, bytes: ($bytes | tonumber), server: $server, cold: $cold, load_mode: $lm, port: ($port | tonumber), ctx: ($ctx | tonumber), ngl: ($ngl | tonumber), psi_gate_max: ($psi_max | tonumber), psi_pre: ($psi_pre | tonumber), psi_post: ($psi_post | tonumber), psi_max_during: ($psi_max_run | tonumber), psi_avg_during: ($psi_avg_run | tonumber), psi_mem_pre: ($mem_pre | tonumber), psi_mem_post: ($mem_post | tonumber), psi_mem_max_during: ($mem_max_run | tonumber), psi_mem_avg_during: ($mem_avg_run | tonumber), load_s: ($load_s | tonumber), mb_s: ($mb_s | tonumber), psi_accepted: $psi_accepted, embed_arch: $embed_arch, embed_auto: $embed_auto}')"
if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  printf '%s\n' "$JSON" >>"$OUT"
  echo "### JSON line appended to $OUT"
else
  printf '%s\n' "$JSON"
fi
