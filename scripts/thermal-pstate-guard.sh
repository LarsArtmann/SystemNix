#!/usr/bin/env bash
# Thermal pstate guard — flips the amd_pstate driver mode on thermal hysteresis.
# Runbook: docs/services/thermal-pstate-guard.md
#
# Normal state: "active" + performance governor + performance EPP (max clocks).
# When any monitored hwmon sensor sustains >= its high threshold (enterTicks),
# the guard snapshots governor/EPP and switches the driver to "guided" so the
# GMKtec firmware manages frequencies within thermal headroom (the freeze
# #8-#14 family died riding Tctl 98-99C under exactly the pinned-max regime).
# When ALL sensors are <= their low thresholds for exitTicks, it restores
# "active" + the snapshotted governor/EPP.
#
# All inputs are env-overridable so the fixture selftest runs the real logic
# against fake sysfs trees; the systemd unit sets only the config-threshold
# variables.
set -euo pipefail

HWMON_ROOT="${HWMON_ROOT:-/sys/class/hwmon}"
PSTATE_ROOT="${PSTATE_ROOT:-/sys/devices/system/cpu/amd_pstate}"
CPUFREQ_ROOT="${CPUFREQ_ROOT:-/sys/devices/system/cpu/cpufreq}"
STATE_DIR="${STATE_DIR:-/var/lib/thermal-pstate-guard}"
TEXTFILE_OUT="${THERMAL_GUARD_TEXTFILE_OUT:-/var/lib/prometheus-node-exporter/textfile_collectors/thermal-pstate-guard.prom}"
SENSORS_SPEC="${THERMAL_GUARD_SENSORS:-k10temp=95/80 nvme=70/60 amdgpu=90/75 acpitz=85/70}"
ENTER_TICKS="${THERMAL_GUARD_ENTER_TICKS:-2}"
EXIT_TICKS="${THERMAL_GUARD_EXIT_TICKS:-12}"
VERBOSE_INTERVAL="${THERMAL_GUARD_VERBOSE_INTERVAL:-600}"
NORMAL_GOVERNOR="${THERMAL_GUARD_NORMAL_GOVERNOR:-performance}"
NORMAL_EPP="${THERMAL_GUARD_NORMAL_EPP:-performance}"

MODE_FILE="$STATE_DIR/mode"
ENTER_STREAK_FILE="$STATE_DIR/enter-streak"
EXIT_STREAK_FILE="$STATE_DIR/exit-streak"
TRIPS_FILE="$STATE_DIR/trips"
RESTORES_FILE="$STATE_DIR/restores"
THROTTLE_LOG_EPOCH_FILE="$STATE_DIR/throttle-log-epoch"
SNAPSHOT_FILE="$STATE_DIR/governor-epp.snapshot"

read_count() {
  cat "$1" 2>/dev/null || echo 0
}

write_sysfs() {
  local value="$1" path="$2"
  if ! printf '%s' "$value" > "$path" 2>/dev/null; then
    echo "thermal-pstate-guard: WARN: sysfs write failed: $path <- $value" >&2
    return 1
  fi
}

log() {
  echo "thermal-pstate-guard: $*"
}

# Prints "<value_celsius> <hwmon_dir>" for the max temp*_input of the first
# hwmon whose name matches; empty when no such sensor exists.
read_sensor_pattern() {
  local name="$1" dir hwmon best="" best_dir=""
  for dir in "$HWMON_ROOT"/hwmon*; do
    [ -r "$dir/name" ] || continue
    [ "$(cat "$dir/name")" = "$name" ] || continue
    local input milli
    for input in "$dir"/temp*_input; do
      [ -r "$input" ] || continue
      milli=$(cat "$input" 2>/dev/null) || continue
      if [ -z "$best" ] || [ "$milli" -gt "$best" ]; then
        best="$milli"
        best_dir="$dir"
      fi
    done
  done
  if [ -n "$best" ]; then
    echo "$((best / 1000)) $best_dir"
  fi
}

# Restores governor/EPP for every cpufreq policy from the snapshot (or the
# configured normal values when no snapshot exists). Called AFTER writing
# status=active: mode switches may reset per-policy attributes.
restore_performance() {
  local policy governor epp
  while IFS=' ' read -r policy governor epp; do
    [ -n "$policy" ] || continue
    write_sysfs "${governor:-$NORMAL_GOVERNOR}" "$CPUFREQ_ROOT/$policy/scaling_governor" || true
    write_sysfs "${epp:-$NORMAL_EPP}" "$CPUFREQ_ROOT/$policy/energy_performance_preference" || true
  done < "${1:-/dev/null}"
  # Snapshot-less restores (external-mode adoption) get the configured normal.
  if [ ! -s "${1:-/dev/null}" ]; then
    for policy in "$CPUFREQ_ROOT"/policy*; do
      [ -d "$policy" ] || continue
      write_sysfs "$NORMAL_GOVERNOR" "$policy/scaling_governor" || true
      write_sysfs "$NORMAL_EPP" "$policy/energy_performance_preference" || true
    done
  fi
}

snapshot_governors() {
  local policy governor epp
  : > "$SNAPSHOT_FILE.tmp"
  for policy in "$CPUFREQ_ROOT"/policy*; do
    [ -d "$policy" ] || continue
    governor="performance"
    [ -r "$policy/scaling_governor" ] && governor=$(cat "$policy/scaling_governor")
    epp="$NORMAL_EPP"
    [ -r "$policy/energy_performance_preference" ] && epp=$(cat "$policy/energy_performance_preference")
    echo "$(basename "$policy") $governor $epp" >> "$SNAPSHOT_FILE.tmp"
  done
  mv -f "$SNAPSHOT_FILE.tmp" "$SNAPSHOT_FILE"
}

write_metrics() {
  local throttled="$1" missing="$2" trips="$3" restores="$4"
  shift 4
  local out_dir
  out_dir="$(dirname "$TEXTFILE_OUT")"
  mkdir -p "$out_dir" 2>/dev/null || true
  local tmp
  tmp=$(mktemp "$TEXTFILE_OUT.XXXXXX") || return 0
  chmod 644 "$tmp"
  {
    echo "# HELP thermal_pstate_guard_throttled 1 when the guard has switched amd_pstate to guided"
    echo "# TYPE thermal_pstate_guard_throttled gauge"
    echo "thermal_pstate_guard_throttled $throttled"
    echo "# HELP thermal_pstate_guard_sensor_celsius Max temp per sensor name pattern (millidegree inputs, integer C)"
    echo "# TYPE thermal_pstate_guard_sensor_celsius gauge"
    local label value
    for label in "$@"; do
      [ -n "$label" ] || continue
      value="${label##*=}"
      label="${label%%=*}"
      echo "thermal_pstate_guard_sensor_celsius{sensor=\"$label\"} $value"
    done
    echo "# HELP thermal_pstate_guard_sensors_missing Sensor name patterns from the spec with no matching hwmon"
    echo "# TYPE thermal_pstate_guard_sensors_missing gauge"
    echo "thermal_pstate_guard_sensors_missing $missing"
    echo "# HELP thermal_pstate_guard_trips_total Completed throttle transitions into guided"
    echo "# TYPE thermal_pstate_guard_trips_total counter"
    echo "thermal_pstate_guard_trips_total $trips"
    echo "# HELP thermal_pstate_guard_restores_total Completed restore transitions back to active"
    echo "# TYPE thermal_pstate_guard_restores_total counter"
    echo "thermal_pstate_guard_restores_total $restores"
    echo "# HELP thermal_pstate_guard_last_run_timestamp_seconds Unix time of the last completed tick (frozen file = dead guard)"
    echo "# TYPE thermal_pstate_guard_last_run_timestamp_seconds gauge"
    echo "thermal_pstate_guard_last_run_timestamp_seconds $(date +%s)"
  } > "$tmp"
  mv -f "$tmp" "$TEXTFILE_OUT"
}

tick() {
  mkdir -p "$STATE_DIR"

  local current_mode
  current_mode=$(cat "$PSTATE_ROOT/status" 2>/dev/null) || {
    log "ERROR: cannot read $PSTATE_ROOT/status — amd_pstate driver missing; no action taken"
    exit 0
  }

  local state_mode
  state_mode=$(cat "$MODE_FILE" 2>/dev/null || echo "$current_mode")

  # External-override adoption: if an operator (or a crash mid-transition)
  # left the driver in a different mode than our state claims, the sysfs
  # wins — never fight a human. A guided->active adoption also restores the
  # performance governor so "normal" is a known state.
  if [ "$current_mode" != "$state_mode" ]; then
    log "adopted externally-set mode: $current_mode (state said $state_mode); streaks reset"
    state_mode="$current_mode"
    echo 0 > "$ENTER_STREAK_FILE"
    echo 0 > "$EXIT_STREAK_FILE"
    if [ "$state_mode" = "active" ]; then
      if [ -f "$SNAPSHOT_FILE" ]; then
        restore_performance "$SNAPSHOT_FILE"
        rm -f "$SNAPSHOT_FILE"
      else
        restore_performance /dev/null
      fi
    fi
  fi
  echo "$state_mode" > "$MODE_FILE"

  # Read every sensor pattern from the spec. Absent patterns do not vote.
  # spec form: name=high/low (degrees C). Colon-separated numbers would
  # trip the port-registry audit's host:port literal patterns.
  local spec name high low reading value hot=0 cool=1 missing=0 present=0
  local sensor_labels=() sensor_summary=""
  for spec in $SENSORS_SPEC; do
    name="${spec%%=*}"
    rest="${spec#*=}"
    high="${rest%%/*}"
    low="${rest#*/}"
    reading=$(read_sensor_pattern "$name")
    if [ -z "$reading" ]; then
      missing=$((missing + 1))
      continue
    fi
    present=$((present + 1))
    value="${reading%% *}"
    sensor_labels+=("$name=$value")
    sensor_summary="$sensor_summary $name=${value}C(hi:$high/lo:$low)"
    if [ "$value" -ge "$high" ]; then
      hot=1
    fi
    if [ "$value" -gt "$low" ]; then
      cool=0
    fi
  done

  local trips restores
  trips=$(read_count "$TRIPS_FILE")
  restores=$(read_count "$RESTORES_FILE")

  if [ "$present" -eq 0 ]; then
    log "ERROR: no sensors matched the spec ($SENSORS_SPEC) — guard blind, no mode change"
    write_metrics 0 "$missing" "$trips" "$restores" ""
    exit 0
  fi

  local enter_streak exit_streak now
  enter_streak=$(read_count "$ENTER_STREAK_FILE")
  exit_streak=$(read_count "$EXIT_STREAK_FILE")
  now=$(date +%s)

  if [ "$state_mode" = "guided" ]; then
    if [ "$hot" -eq 1 ]; then
      echo 0 > "$EXIT_STREAK_FILE"
      local last_log
      last_log=$(read_count "$THROTTLE_LOG_EPOCH_FILE")
      if [ $((now - last_log)) -ge "$VERBOSE_INTERVAL" ]; then
        log "throttled (guided), still hot:$sensor_summary"
        echo "$now" > "$THROTTLE_LOG_EPOCH_FILE"
      fi
    elif [ "$cool" -eq 1 ]; then
      exit_streak=$((exit_streak + 1))
      echo "$exit_streak" > "$EXIT_STREAK_FILE"
      if [ "$exit_streak" -ge "$EXIT_TICKS" ]; then
        if write_sysfs active "$PSTATE_ROOT/status"; then
          restore_performance "$SNAPSHOT_FILE"
          rm -f "$SNAPSHOT_FILE"
          echo active > "$MODE_FILE"
          echo 0 > "$EXIT_STREAK_FILE"
          restores=$((restores + 1))
          echo "$restores" > "$RESTORES_FILE"
          log "THERMAL THROTTLE EXIT: amd_pstate restored to active + $NORMAL_GOVERNOR after ${EXIT_TICKS}x cool ticks:$sensor_summary"
        else
          log "ERROR: failed to write active to $PSTATE_ROOT/status; staying guided"
        fi
      fi
    else
      # Middle band: below high but above low — dwell resets, silent.
      echo 0 > "$EXIT_STREAK_FILE"
    fi
  else
    if [ "$hot" -eq 1 ]; then
      enter_streak=$((enter_streak + 1))
      echo "$enter_streak" > "$ENTER_STREAK_FILE"
      if [ "$enter_streak" -ge "$ENTER_TICKS" ]; then
        snapshot_governors
        if write_sysfs guided "$PSTATE_ROOT/status"; then
          echo guided > "$MODE_FILE"
          echo 0 > "$ENTER_STREAK_FILE"
          trips=$((trips + 1))
          echo "$trips" > "$TRIPS_FILE"
          echo "$now" > "$THROTTLE_LOG_EPOCH_FILE"
          log "THERMAL THROTTLE ENTER: amd_pstate -> guided after ${ENTER_TICKS}x hot ticks:$sensor_summary"
        else
          log "ERROR: failed to write guided to $PSTATE_ROOT/status; staying $state_mode"
          rm -f "$SNAPSHOT_FILE"
        fi
      fi
    else
      echo 0 > "$ENTER_STREAK_FILE"
    fi
  fi

  local throttled=0
  [ "$(cat "$MODE_FILE" 2>/dev/null || echo "$current_mode")" = "guided" ] && throttled=1
  write_metrics "$throttled" "$missing" "$(read_count "$TRIPS_FILE")" "$(read_count "$RESTORES_FILE")" "${sensor_labels[@]}"
}

run_selftest() {
  # Deliberately NOT local: the EXIT trap runs outside the function scope,
  # where a local fixture would be unbound under set -u.
  fixture=$(mktemp -d)
  trap 'rm -rf "$fixture"' EXIT

  mkdir -p "$fixture/hwmon/hwmon0" "$fixture/hwmon/hwmon1" "$fixture/hwmon/hwmon2" "$fixture/hwmon/hwmon3" "$fixture/hwmon/hwmon4" \
    "$fixture/pstate" "$fixture/cpufreq/policy0" "$fixture/cpufreq/policy1" \
    "$fixture/state" "$fixture/textfile"

  echo nvme > "$fixture/hwmon/hwmon0/name"; echo 55000 > "$fixture/hwmon/hwmon0/temp1_input"
  echo nvme > "$fixture/hwmon/hwmon1/name"; echo 57000 > "$fixture/hwmon/hwmon1/temp1_input"
  echo amdgpu > "$fixture/hwmon/hwmon2/name"; echo 42000 > "$fixture/hwmon/hwmon2/temp1_input"
  echo k10temp > "$fixture/hwmon/hwmon3/name"; echo 60000 > "$fixture/hwmon/hwmon3/temp1_input"
  echo acpitz > "$fixture/hwmon/hwmon4/name"; echo 45000 > "$fixture/hwmon/hwmon4/temp1_input"

  echo active > "$fixture/pstate/status"
  echo performance > "$fixture/cpufreq/policy0/scaling_governor"
  echo performance > "$fixture/cpufreq/policy0/energy_performance_preference"
  echo performance > "$fixture/cpufreq/policy1/scaling_governor"
  echo performance > "$fixture/cpufreq/policy1/energy_performance_preference"

  local env_common=(
    HWMON_ROOT="$fixture/hwmon"
    PSTATE_ROOT="$fixture/pstate"
    CPUFREQ_ROOT="$fixture/cpufreq"
    STATE_DIR="$fixture/state"
    THERMAL_GUARD_TEXTFILE_OUT="$fixture/textfile/guard.prom"
    THERMAL_GUARD_SENSORS="k10temp=95/80 nvme=70/60"
    THERMAL_GUARD_ENTER_TICKS=2
    THERMAL_GUARD_EXIT_TICKS=3
    THERMAL_GUARD_VERBOSE_INTERVAL=0
  )

  local failures=0
  assert_eq() {
    if [ "$2" != "$3" ]; then
      echo "SELFTEST FAIL ($1): expected [$3], got [$2]" >&2
      failures=$((failures + 1))
    else
      echo "ok: $1"
    fi
  }

  # 1. Cold start: adopts current mode, no throttle.
  env "${env_common[@]}" bash "$0" tick
  assert_eq "cold-start-mode" "$(cat "$fixture/state/mode")" "active"
  assert_eq "cold-start-pstate" "$(cat "$fixture/pstate/status")" "active"

  # 2. One hot tick: debounce holds active.
  echo 96000 > "$fixture/hwmon/hwmon3/temp1_input"
  env "${env_common[@]}" bash "$0" tick
  assert_eq "debounce-holds-active" "$(cat "$fixture/pstate/status")" "active"

  # 3. Second hot tick: enters guided, snapshot taken, trip counted.
  env "${env_common[@]}" bash "$0" tick
  assert_eq "enter-guided" "$(cat "$fixture/pstate/status")" "guided"
  assert_eq "snapshot-exists" "$([ -s "$fixture/state/governor-epp.snapshot" ] && echo yes)" "yes"
  assert_eq "trips-1" "$(cat "$fixture/state/trips")" "1"

  # 4. Still hot: stays guided, no double trip.
  env "${env_common[@]}" bash "$0" tick
  assert_eq "stays-guided" "$(cat "$fixture/pstate/status")" "guided"
  assert_eq "trips-still-1" "$(cat "$fixture/state/trips")" "1"

  # 5. Middle band (85C, above low 80): dwell resets, stays guided.
  echo 85000 > "$fixture/hwmon/hwmon3/temp1_input"
  env "${env_common[@]}" bash "$0" tick
  env "${env_common[@]}" bash "$0" tick
  assert_eq "middle-band-resets" "$(cat "$fixture/state/exit-streak")" "0"
  assert_eq "middle-band-stays" "$(cat "$fixture/pstate/status")" "guided"

  # 6. Cool x3: restores active + snapshotted governor.
  echo 70000 > "$fixture/hwmon/hwmon3/temp1_input"
  env "${env_common[@]}" bash "$0" tick
  env "${env_common[@]}" bash "$0" tick
  assert_eq "exit-debounce-holds" "$(cat "$fixture/pstate/status")" "guided"
  env "${env_common[@]}" bash "$0" tick
  assert_eq "exit-restores-active" "$(cat "$fixture/pstate/status")" "active"
  assert_eq "governor-restored" "$(cat "$fixture/cpufreq/policy0/scaling_governor")" "performance"
  assert_eq "epp-restored" "$(cat "$fixture/cpufreq/policy0/energy_performance_preference")" "performance"
  assert_eq "restores-1" "$(cat "$fixture/state/restores")" "1"
  assert_eq "snapshot-removed" "$([ -e "$fixture/state/governor-epp.snapshot" ] && echo yes || echo no)" "no"

  # 7. Metrics reflect the run.
  grep -q '^thermal_pstate_guard_throttled 0$' "$fixture/textfile/guard.prom"
  assert_eq "metric-throttled" "$?" "0"
  grep -q 'thermal_pstate_guard_sensor_celsius{sensor="k10temp"} 70' "$fixture/textfile/guard.prom"
  assert_eq "metric-k10temp" "$?" "0"
  grep -q '^thermal_pstate_guard_last_run_timestamp_seconds [0-9]*$' "$fixture/textfile/guard.prom"
  assert_eq "metric-freshness" "$?" "0"

  # 8. External override: operator flips to guided; guard adopts, does not fight.
  echo guided > "$fixture/pstate/status"
  env "${env_common[@]}" bash "$0" tick
  assert_eq "adopt-external-guided" "$(cat "$fixture/state/mode")" "guided"

  # 9. External flip back without our snapshot: adoption restores the
  # configured performance governor even over a mode-switch reset.
  echo 96000 > "$fixture/hwmon/hwmon3/temp1_input"
  env "${env_common[@]}" bash "$0" tick # stays guided (hot)
  echo active > "$fixture/pstate/status"
  echo schedutil > "$fixture/cpufreq/policy0/scaling_governor" # simulate mode-switch reset
  env "${env_common[@]}" bash "$0" tick
  assert_eq "adopt-external-active" "$(cat "$fixture/state/mode")" "active"
  assert_eq "adopt-restores-governor" "$(cat "$fixture/cpufreq/policy0/scaling_governor")" "performance"

  # 10. Blind guard: no sensors match -> metric only, no crash, no change.
  local blind_env=(
    HWMON_ROOT="$fixture/hwmon"
    PSTATE_ROOT="$fixture/pstate"
    CPUFREQ_ROOT="$fixture/cpufreq"
    STATE_DIR="$fixture/state-blind"
    THERMAL_GUARD_TEXTFILE_OUT="$fixture/textfile/blind.prom"
    THERMAL_GUARD_SENSORS="nonexistent=50/40"
  )
  env "${blind_env[@]}" bash "$0" tick
  assert_eq "blind-no-change" "$(cat "$fixture/pstate/status")" "active"
  grep -q '^thermal_pstate_guard_sensors_missing 1$' "$fixture/textfile/blind.prom"
  assert_eq "blind-metric" "$?" "0"

  if [ "$failures" -gt 0 ]; then
    echo "SELFTEST FAILED: $failures assertion(s)" >&2
    exit 1
  fi
  echo "SELFTEST PASSED: thermal-pstate-guard"
}

case "${1:-tick}" in
  tick) tick ;;
  selftest) run_selftest ;;
  *)
    echo "usage: $0 [tick|selftest]" >&2
    exit 2
    ;;
esac
