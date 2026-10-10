#!/usr/bin/env bash
# Bun memory watchdog.
#
# SIGKILLs any process whose resolved /proc/PID/exe is `bun` once its VmRSS
# crosses the kill threshold (default 16 GiB). Motivated by the 2026-10-10
# near-freeze: `bun test` (qmd mcp toolchain) climbed past 70 GB on the
# 128 GB host with no natural ceiling — bun processes are spawned by agent
# sessions as plain user processes (session scopes, no systemd unit to cap),
# so the only launcher-agnostic containment is a /proc sweep.
#
# Safety rails:
#   - exe identity is re-verified immediately before the kill (PID reuse).
#   - The sweep only ever matches exact exe basenames from PROCESS_NAMES —
#     never a pattern, never a cmdline substring.
#   - BUN_WATCHDOG_DRY_RUN_FILE turns kills into append-only records (the
#     selftest mode and manual drills use this; production never sets it).
#
# Metric freshness follows the memory-guard doctrine: the .prom is rewritten
# atomically (mktemp + rename) on every tick and stamps
# last_run_timestamp_seconds, so a dead watchdog is detectable by staleness.
#
# Runbook: docs/services/bun-memory-watchdog.md

set -euo pipefail

PROC_SRC="${BUN_WATCHDOG_PROC_SRC:-/proc}"
OUT="${BUN_WATCHDOG_OUT:-/var/lib/prometheus-node-exporter/textfile_collectors/bun-memory-watchdog.prom}"
STATE_DIR="${BUN_WATCHDOG_STATE_DIR:-/var/lib/bun-memory-watchdog}"
# 16 GiB in kB (VmRSS unit). The 2026-10-10 offender sat at ~70 GB before
# anything reacted; 16 GiB leaves headroom for legitimate bun workloads
# (installs, test suites) while stopping a leak two orders of magnitude
# before it can starve the box.
THRESHOLD_KB="${BUN_WATCHDOG_THRESHOLD_KB:-16777216}"
PROCESS_NAMES="${BUN_WATCHDOG_PROCESS_NAMES:-bun}"
DRY_RUN_FILE="${BUN_WATCHDOG_DRY_RUN_FILE:-}"

SCRATCH_DIR=""
PROM_TMP=""
cleanup() {
  if [ -n "$PROM_TMP" ]; then
    rm -f "$PROM_TMP"
  fi
  if [ -n "$SCRATCH_DIR" ]; then
    rm -rf "$SCRATCH_DIR"
  fi
}
trap cleanup EXIT

read -ra process_names <<<"$PROCESS_NAMES"

sweep() {
  local kills=0
  local stat_dir pid exe base rss_kb exe_now cmdline cgroup name
  for stat_dir in "$PROC_SRC"/[0-9]*; do
    pid="${stat_dir##*/}"
    exe="$(readlink "$stat_dir/exe" 2>/dev/null)" || continue
    base="${exe##*/}"
    base="${base% (deleted)}"
    local is_match=0
    for name in "${process_names[@]}"; do
      [ "$base" = "$name" ] && is_match=1
    done
    [ "$is_match" = 1 ] || continue
    rss_kb="$(awk '/^VmRSS:/ {print $2}' "$stat_dir/status" 2>/dev/null)" || continue
    [ -n "$rss_kb" ] || continue
    [ "$rss_kb" -ge "$THRESHOLD_KB" ] 2>/dev/null || continue
    # PID-reuse guard: confirm the exe STILL resolves to the same bun
    # binary right before the kill.
    exe_now="$(readlink "$stat_dir/exe" 2>/dev/null)" || continue
    [ "${exe_now##*/}" = "$base" ] || continue
    cmdline="$(tr '\0' ' ' <"$stat_dir/cmdline" 2>/dev/null || true)"
    cgroup="$(head -1 "$stat_dir/cgroup" 2>/dev/null || true)"
    if [ -n "$DRY_RUN_FILE" ]; then
      printf '%s\n' "$pid" >>"$DRY_RUN_FILE"
    elif kill -9 "$pid" 2>/dev/null; then
      printf '%s %s\n' "$(date -Is)" \
        "KILLED $base pid=$pid rss=${rss_kb}kB cgroup=${cgroup:-unknown} cmd=${cmdline:-unknown}" >&2
      printf '%s\n' "$pid" >"$STATE_DIR/last-kill-pid"
      printf '%s\n' "$rss_kb" >"$STATE_DIR/last-kill-rss-kb"
      date +%s >"$STATE_DIR/last-kill-epoch"
      kills=$((kills + 1))
    else
      printf '%s %s\n' "$(date -Is)" \
        "kill FAILED $base pid=$pid rss=${rss_kb}kB (gone or EPERM)" >&2
    fi
  done
  echo "$kills"
}

PROM_TMP=""
render_prom() {
  local kills_delta="$1"

  local total_kills=0
  if [ -f "$STATE_DIR/kills.count" ]; then
    total_kills="$(cat "$STATE_DIR/kills.count")"
  fi
  total_kills=$((total_kills + kills_delta))
  printf '%s\n' "$total_kills" >"$STATE_DIR/kills.count"

  local last_pid=0
  if [ -f "$STATE_DIR/last-kill-pid" ]; then
    last_pid="$(cat "$STATE_DIR/last-kill-pid")"
  fi
  local last_rss_kb=0
  if [ -f "$STATE_DIR/last-kill-rss-kb" ]; then
    last_rss_kb="$(cat "$STATE_DIR/last-kill-rss-kb")"
  fi
  local last_epoch=0
  if [ -f "$STATE_DIR/last-kill-epoch" ]; then
    last_epoch="$(cat "$STATE_DIR/last-kill-epoch")"
  fi
  local last_rss_gib
  last_rss_gib="$(awk -v kb="$last_rss_kb" 'BEGIN { printf "%.1f", kb / 1048576 }')"

  # mktemp + rename per the repo textfile doctrine (1777 sticky dir: a fixed
  # .tmp path wedges on foreign-owned leftovers; the unit carries
  # CAP_FOWNER/CAP_DAC_OVERRIDE but the unique-tmp form needs no caps and
  # keeps the audit exception list empty).
  PROM_TMP="$(mktemp "${OUT}.XXXXXX")"
  chmod 644 "$PROM_TMP"
  {
    echo "# HELP bun_memory_watchdog_kills_total Bun processes SIGKILLed for crossing the memory threshold since watchdog install"
    echo "# TYPE bun_memory_watchdog_kills_total counter"
    echo "bun_memory_watchdog_kills_total $total_kills"
    echo "# HELP bun_memory_watchdog_last_kill_pid PID of the last killed bun process (0 = none yet)"
    echo "# TYPE bun_memory_watchdog_last_kill_pid gauge"
    echo "bun_memory_watchdog_last_kill_pid $last_pid"
    echo "# HELP bun_memory_watchdog_last_kill_rss_gib VmRSS in GiB of the last killed bun process (0 = none yet)"
    echo "# TYPE bun_memory_watchdog_last_kill_rss_gib gauge"
    echo "bun_memory_watchdog_last_kill_rss_gib $last_rss_gib"
    echo "# HELP bun_memory_watchdog_last_kill_timestamp_seconds Epoch of the last kill (0 = none yet)"
    echo "# TYPE bun_memory_watchdog_last_kill_timestamp_seconds gauge"
    echo "bun_memory_watchdog_last_kill_timestamp_seconds $last_epoch"
    echo "# HELP bun_memory_watchdog_last_run_timestamp_seconds Epoch of this sweep — freshness signal; a frozen value means the watchdog is DEAD (node_exporter serves the stale textfile forever)"
    echo "# TYPE bun_memory_watchdog_last_run_timestamp_seconds gauge"
    echo "bun_memory_watchdog_last_run_timestamp_seconds $(date +%s)"
  } >"$PROM_TMP"
  mv "$PROM_TMP" "$OUT"
  PROM_TMP=""
}

# --- selftest -------------------------------------------------------------
# Fixture proc tree; drives the REAL sweep via `sweep-run` subprocesses
# (env-configurable data sources) and asserts the kill rule, the non-bun
# exclusion, the threshold boundary, and counter persistence across runs.
selftest() {
  local scratch
  scratch="$(mktemp -d)"
  SCRATCH_DIR="$scratch"

  local fake_proc="$scratch/proc"
  mkdir -p "$fake_proc/111" "$fake_proc/222" "$fake_proc/333" "$fake_proc/444"
  # offender: bun at 17 GiB -> MUST be killed
  ln -s "/nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-bun-1.3.6/bin/bun" "$fake_proc/111/exe"
  printf 'VmRSS:\t17825792 kB\n' >"$fake_proc/111/status"
  # under threshold: bun at 15 GiB -> MUST survive
  ln -s "/nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-bun-1.3.6/bin/bun" "$fake_proc/222/exe"
  printf 'VmRSS:\t15728640 kB\n' >"$fake_proc/222/status"
  # over threshold but NOT bun -> MUST survive
  ln -s "/nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-bash-5.2/bin/bash" "$fake_proc/333/exe"
  printf 'VmRSS:\t17825792 kB\n' >"$fake_proc/333/status"
  # exactly at threshold: bun at 16 GiB -> MUST be killed (>= semantics)
  ln -s "/nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-bun-1.3.6/bin/bun" "$fake_proc/444/exe"
  printf 'VmRSS:\t16777216 kB\n' >"$fake_proc/444/status"
  for p in 111 222 333 444; do
    printf 'bun\x00test\x00' >"$fake_proc/$p/cmdline"
    printf '0::/user.slice/user-1000.slice/session-1.scope\n' >"$fake_proc/$p/cgroup"
  done

  local dry_run="$scratch/kills.txt" out="$scratch/watchdog.prom" state="$scratch/state"
  mkdir -p "$state"

  local run1 run2
  run1="$(
    BUN_WATCHDOG_PROC_SRC="$fake_proc" \
      BUN_WATCHDOG_STATE_DIR="$state" \
      BUN_WATCHDOG_OUT="$out" \
      BUN_WATCHDOG_DRY_RUN_FILE="$dry_run" \
      bash "${BASH_SOURCE[0]}" sweep-run
  )"

  local fail=0
  if ! grep -qx '111' "$dry_run"; then
    echo "selftest FAIL: 17 GiB bun (pid 111) not killed" >&2
    fail=1
  fi
  if ! grep -qx '444' "$dry_run"; then
    echo "selftest FAIL: exactly-16-GiB bun (pid 444) not killed (>= semantics broken)" >&2
    fail=1
  fi
  if grep -qx '222' "$dry_run"; then
    echo "selftest FAIL: 15 GiB bun (pid 222) killed — below threshold" >&2
    fail=1
  fi
  if grep -qx '333' "$dry_run"; then
    echo "selftest FAIL: non-bun process (pid 333) killed — exe filter broken" >&2
    fail=1
  fi
  if [ "$run1" != "2" ]; then
    echo "selftest FAIL: sweep reported $run1 kills, expected 2" >&2
    fail=1
  fi

  # counter persistence: a second run with one fresh offender must
  # accumulate (kills_total 3, not 1).
  mkdir -p "$fake_proc/555"
  ln -s "/nix/store/yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy-bun-1.3.6/bin/bun" "$fake_proc/555/exe"
  printf 'VmRSS:\t20971520 kB\n' >"$fake_proc/555/status"
  printf 'bun\x00test\x00' >"$fake_proc/555/cmdline"
  printf '0::/user.slice/user-1000.slice/session-1.scope\n' >"$fake_proc/555/cgroup"

  run2="$(
    BUN_WATCHDOG_PROC_SRC="$fake_proc" \
      BUN_WATCHDOG_STATE_DIR="$state" \
      BUN_WATCHDOG_OUT="$out" \
      BUN_WATCHDOG_DRY_RUN_FILE="$dry_run" \
      bash "${BASH_SOURCE[0]}" sweep-run
  )"

  if [ "$run2" != "1" ]; then
    echo "selftest FAIL: second sweep reported $run2 kills, expected 1" >&2
    fail=1
  fi
  if ! grep -q '^bun_memory_watchdog_kills_total 3$' "$out"; then
    echo "selftest FAIL: kills_total did not accumulate across runs" >&2
    cat "$out" >&2
    fail=1
  fi
  if ! grep -q '^bun_memory_watchdog_last_kill_rss_gib 20.0$' "$out"; then
    echo "selftest FAIL: last_kill_rss_gib wrong" >&2
    cat "$out" >&2
    fail=1
  fi
  if ! grep -q '^bun_memory_watchdog_last_run_timestamp_seconds [0-9]' "$out"; then
    echo "selftest FAIL: last_run_timestamp_seconds missing" >&2
    fail=1
  fi
  if [ "$(grep -cx '555' "$dry_run")" != "1" ]; then
    echo "selftest FAIL: second-run offender (pid 555) not recorded exactly once" >&2
    fail=1
  fi

  if [ "$fail" = "0" ]; then
    echo "bun-memory-watchdog selftest OK"
  fi
  return "$fail"
}

# --- entry ----------------------------------------------------------------
if [ "${1:-}" = "selftest" ]; then
  selftest
  exit $?
fi

mkdir -p "$STATE_DIR"

kills="$(sweep)"
render_prom "$kills"

printf 'bun-watchdog sweep: kills=%s\n' "$kills" >&2
echo "$kills"
