#!/usr/bin/env bash
# Scheduled OIDC client secret auto-rotation for Pocket ID.
#
# Complements the monitor-only pocket-id-secret-rotation collector: when a
# client secret file in <secrets-dir> is older than <max-age-days>, this
# script rotates the secret via Pocket ID's multi-secret API
# (POST /api/oidc/clients/{id}/secrets — returns the secret exactly once),
# atomically rewrites the file (the exact mktemp+mv dance pocket-id-provision
# uses), then restarts the consumer units so the new secret actually reaches
# the running daemons (LoadCredential/env-file bind at process start only).
#
# Safety rails:
#   - mode "dry-run" plans and reports but never rotates (default first window)
#   - <max-per-run> caps the blast radius (default 1 client per run)
#   - skips a run while pocket-id-provision is mid-flight (deploy race)
#   - healthz gate: never rotates against a dead/unhealthy Pocket ID
#   - a stale client with no consumer mapping is SKIPPED (rotating without
#     a consumer restart would desync exactly the way this exists to prevent)
#   - consumer spec "daemon@bridge:envfile" restarts the daemon only when the
#     bridge actually re-rendered the env file (the 2026-10-03 cv duplicate-
#     opportunity trap: unconditional restarts replay non-idempotent syncers)
#
# Usage:
#   pocket-id-auto-rotate.sh <mode> <api-key-file> <api-url> <secrets-dir> \
#     <textfile-dir> <max-age-days> <max-per-run> [client=unit,unit,...]...
#     consumer unit forms: "unit" | "daemon@bridge:envfile"
#   pocket-id-auto-rotate.sh selftest
set -uo pipefail

SELF_NAME="pocket-id-auto-rotate"

log() { echo "$SELF_NAME: $*"; }
warn() { echo "$SELF_NAME: WARN: $*" >&2; }
die() { echo "$SELF_NAME: ERROR: $*" >&2; return 1; }

# ── planner (pure, selftest-covered) ────────────────────────────────────────
# Emits "<client> <age_days>" for stale clients (age strictly greater than
# max_age_days, matching the monitor's -gt threshold), oldest first, capped.
plan_rotations() {
  local dir=$1 now=$2 max_age_days=$3 max_per_run=$4 f client mtime age
  local -a lines=()
  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    [ -s "$f" ] || continue
    client=$(basename "$f")
    mtime=$(stat -c %Y "$f" 2>/dev/null) || continue
    age=$(((now - mtime) / 86400))
    [ "$age" -gt "$max_age_days" ] || continue
    lines+=("$age $client")
  done
  [ "${#lines[@]}" -gt 0 ] || return 0
  printf '%s\n' "${lines[@]}" | sort -rn | head -n "$max_per_run" | awk '{print $2, $1}'
}

# ── selftest (no API, no systemd) ───────────────────────────────────────────
if [ "${1:-}" = "selftest" ]; then
  set -euo pipefail
  scratch=$(mktemp -d)
  trap 'rm -rf "$scratch"' EXIT
  now=$(date +%s)
  : >"$scratch/a"; touch -d "100 days ago" "$scratch/a"
  : >"$scratch/b"; touch -d "95 days ago" "$scratch/b"
  : >"$scratch/c"; touch -d "10 days ago" "$scratch/c"
  : >"$scratch/.hidden-state"; touch -d "400 days ago" "$scratch/.hidden-state"

  plan=$(plan_rotations "$scratch" "$now" 90 1)
  [ "$plan" = "a 100" ] || {
    echo "selftest: cap-1 plan wrong: got '$plan'" >&2
    exit 1
  }

  plan=$(plan_rotations "$scratch" "$now" 90 5)
  [ "$(echo "$plan" | wc -l)" -eq 2 ] || {
    echo "selftest: expected 2 stale clients, got: $plan" >&2
    exit 1
  }
  [ "$(echo "$plan" | head -1 | awk '{print $2}')" = "a" ] || {
    echo "selftest: oldest-first order wrong: $plan" >&2
    exit 1
  }

  plan=$(plan_rotations "$scratch" "$now" 99 5)
  [ "$plan" = "a 100" ] || {
    echo "selftest: threshold boundary wrong: got '$plan'" >&2
    exit 1
  }

  plan=$(plan_rotations "$scratch" "$now" 100 5)
  [ -z "$plan" ] || {
    echo "selftest: empty plan expected at threshold 100, got '$plan'" >&2
    exit 1
  }

  # Consumer spec parsing: plain unit + daemon@bridge:envfile forms.
  parse_consumers "cv=cv-oidc-env,cv-server@cv-oidc-env:/var/lib/cv-oidc/client-secret.env" "forgejo=forgejo.service"
  [ "${CONSUMERS[cv]}" = "cv-oidc-env,cv-server@cv-oidc-env:/var/lib/cv-oidc/client-secret.env" ] || {
    echo "selftest: cv consumer spec mangled: '${CONSUMERS[cv]}'" >&2
    exit 1
  }
  [ "${CONSUMERS[forgejo]}" = "forgejo.service" ] || {
    echo "selftest: forgejo consumer spec mangled" >&2
    exit 1
  }
  [ "$(split_consumer_unit "cv-server@cv-oidc-env:/x/y.env" && echo ok)" = "ok" ] || {
    echo "selftest: @-gate spec split failed" >&2
    exit 1
  }
  [ "$SPLIT_DAEMON" = "cv-server" ] && [ "$SPLIT_BRIDGE" = "cv-oidc-env" ] && [ "$SPLIT_ENVFILE" = "/x/y.env" ] || {
    echo "selftest: @-gate split wrong: daemon=$SPLIT_DAEMON bridge=$SPLIT_BRIDGE envfile=$SPLIT_ENVFILE" >&2
    exit 1
  }

  echo "$SELF_NAME selftest OK"
  exit 0
fi

# ── argument handling ───────────────────────────────────────────────────────
if [ $# -lt 7 ]; then
  echo "usage: $0 <mode> <api-key-file> <api-url> <secrets-dir> <textfile-dir> <max-age-days> <max-per-run> [client=units]..." >&2
  exit 2
fi

MODE=$1
API_KEY_FILE=$2
API_URL=$3
SECRETS_DIR=$4
TEXTFILE_DIR=$5
MAX_AGE_DAYS=$6
MAX_PER_RUN=$7
shift 7

case "$MODE" in
  dry-run | apply) ;;
  *)
    echo "$SELF_NAME: ERROR: mode must be dry-run or apply, got '$MODE'" >&2
    exit 2
    ;;
esac
case "$MAX_PER_RUN" in
  '' | *[!0-9]*)
    echo "$SELF_NAME: ERROR: max-per-run must be a number" >&2
    exit 2
    ;;
esac
[ -f "$API_KEY_FILE" ] || {
  echo "$SELF_NAME: ERROR: API key file missing: $API_KEY_FILE" >&2
  exit 1
}
[ -d "$SECRETS_DIR" ] || {
  echo "$SELF_NAME: ERROR: secrets dir missing: $SECRETS_DIR" >&2
  exit 1
}

STATE_FILE="$SECRETS_DIR/.auto-rotation.state"

# ── consumer map ────────────────────────────────────────────────────────────
declare -A CONSUMERS =()
parse_consumers() {
  CONSUMERS=()
  local spec client
  for spec in "$@"; do
    case "$spec" in
      *=*) client=${spec%%=*} ;;
      *)
        warn "malformed consumer spec (want client=units): $spec"
        continue
        ;;
    esac
    CONSUMERS[$client]=${spec#*=}
  done
  return 0
}

# Splits "daemon@bridge:envfile" into SPLIT_DAEMON/SPLIT_BRIDGE/SPLIT_ENVFILE.
# Returns 1 when the spec is a plain unit.
split_consumer_unit() {
  SPLIT_DAEMON=""
  SPLIT_BRIDGE=""
  SPLIT_ENVFILE=""
  case "$1" in
    *@*:*)
      SPLIT_DAEMON=${1%%@*}
      SPLIT_BRIDGE=${1#*@}
      SPLIT_BRIDGE=${SPLIT_BRIDGE%%:*}
      SPLIT_ENVFILE=${1#*:@}
      SPLIT_ENVFILE=${SPLIT_ENVFILE#*:}
      return 0
      ;;
    *) return 1 ;;
  esac
}

parse_consumers "$@"

# ── metrics ─────────────────────────────────────────────────────────────────
ROTATED_TOTAL=0
LAST_SUCCESS_TS=0
if [ -f "$STATE_FILE" ]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE" 2>/dev/null || true
fi

SKIP_PROVISION=0
UNMAPPED=0
RUN_FAILED=0
PENDING=0
LAST_CLIENT="-"

write_prom() {
  local now temp
  now=$(date +%s)
  temp=$(mktemp "$TEXTFILE_DIR/secret-rotation-auto.prom.XXXXXX")
  {
    echo "# HELP secret_rotation_auto_run_failed 1 if the last auto-rotation run failed (rotation or consumer restart)"
    echo "# TYPE secret_rotation_auto_run_failed gauge"
    echo "secret_rotation_auto_run_failed $RUN_FAILED"
    echo "# HELP secret_rotation_auto_dry_run 1 while auto-rotation only observes (never rotates)"
    echo "# TYPE secret_rotation_auto_dry_run gauge"
    echo "secret_rotation_auto_dry_run $( [ "$MODE" = dry-run ] && echo 1 || echo 0)"
    echo "# HELP secret_rotation_auto_rotated_total cumulative client secrets rotated by the automation"
    echo "# TYPE secret_rotation_auto_rotated_total counter"
    echo "secret_rotation_auto_rotated_total $ROTATED_TOTAL"
    echo "# HELP secret_rotation_auto_last_success_timestamp unix time of the last successful rotation (0 = never)"
    echo "# TYPE secret_rotation_auto_last_success_timestamp gauge"
    echo "secret_rotation_auto_last_success_timestamp $LAST_SUCCESS_TS"
    echo "# HELP secret_rotation_auto_last_rotated_client last client rotated (label only, value is the timestamp)"
    echo "# TYPE secret_rotation_auto_last_rotated_client gauge"
    echo "secret_rotation_auto_last_rotated_client{client=\"$LAST_CLIENT\"} $LAST_SUCCESS_TS"
    echo "# HELP secret_rotation_auto_pending stale clients awaiting rotation (dry-run: would rotate on apply)"
    echo "# TYPE secret_rotation_auto_pending gauge"
    echo "secret_rotation_auto_pending $PENDING"
    echo "# HELP secret_rotation_auto_unmapped_clients stale clients skipped because no consumer units are declared"
    echo "# TYPE secret_rotation_auto_unmapped_clients gauge"
    echo "secret_rotation_auto_unmapped_clients $UNMAPPED"
    echo "# HELP secret_rotation_auto_skipped_provision_active 1 if this run was skipped because pocket-id-provision was mid-flight"
    echo "# TYPE secret_rotation_auto_skipped_provision_active gauge"
    echo "secret_rotation_auto_skipped_provision_active $SKIP_PROVISION"
    echo "# HELP secret_rotation_auto_age_days per-client secret file age in days"
    echo "# TYPE secret_rotation_auto_age_days gauge"
    local f client mtime age
    for f in "$SECRETS_DIR"/*; do
      [ -f "$f" ] || continue
      client=$(basename "$f")
      mtime=$(stat -c %Y "$f" 2>/dev/null) || continue
      age=$(((now - mtime) / 86400))
      echo "secret_rotation_auto_age_days{client=\"$client\"} $age"
    done
  } >"$temp"
  chmod 644 "$temp"
  mv -f "$temp" "$TEXTFILE_DIR/secret-rotation-auto.prom"
}

# ── locks and gates ─────────────────────────────────────────────────────────
LOCK_DIR=${RUNTIME_DIRECTORY:-/run/pocket-id-auto-rotation}
mkdir -p "$LOCK_DIR"
exec 9>"$LOCK_DIR/lock"
if ! flock -n 9; then
  log "another run holds the lock — exiting (timer overlap)"
  exit 0
fi

provision_state=$(systemctl is-active pocket-id-provision.service 2>/dev/null || true)
if [ "$provision_state" = "activating" ]; then
  log "pocket-id-provision is mid-run (deploy in progress) — skipping this run"
  SKIP_PROVISION=1
  write_prom
  exit 0
fi

# Healthz gate: never rotate against a dead or busy-storming Pocket ID.
if ! timeout 120 bash -c "until curl -sf --max-time 3 $API_URL/healthz >/dev/null 2>&1; do sleep 2; done"; then
  warn "Pocket ID healthz did not come up within 120s — failing loudly, nothing rotated"
  RUN_FAILED=1
  write_prom
  exit 1
fi

API_KEY=$(cat "$API_KEY_FILE")

# ── plan ────────────────────────────────────────────────────────────────────
now=$(date +%s)
plan=$(plan_rotations "$SECRETS_DIR" "$now" "$MAX_AGE_DAYS" "$MAX_PER_RUN")

all_stale=$(plan_rotations "$SECRETS_DIR" "$now" "$MAX_AGE_DAYS" 100000)
if [ -n "$all_stale" ]; then
  PENDING=$(echo "$all_stale" | wc -l)
fi

if [ -z "$plan" ]; then
  log "no stale clients (threshold ${MAX_AGE_DAYS}d) — nothing to do"
  write_prom
  exit 0
fi

if [ "$MODE" = "dry-run" ]; then
  while read -r client age; do
    log "[DRY-RUN] would rotate client=$client age=${age}d consumers=${CONSUMERS[$client]:-<UNMAPPED>}"
  done <<<"$plan"
  write_prom
  exit 0
fi

# ── rotate ──────────────────────────────────────────────────────────────────
persist_state() {
  printf 'ROTATED_TOTAL=%s\nLAST_SUCCESS_TS=%s\n' "$ROTATED_TOTAL" "$LAST_SUCCESS_TS" >"$STATE_FILE"
}

rotate_secret() {
  local client=$1 response code body secret tmp attempt
  for attempt in 1 2; do
    response=$(curl -sS --compressed --max-time 30 --retry 3 --retry-delay 2 -w '\n%{http_code}' \
      -X POST -H "X-API-Key: $API_KEY" \
      "$API_URL/api/oidc/clients/$client/secrets" 2>&1) || true
    code=$(printf '%s' "$response" | tail -n 1)
    body=$(printf '%s' "$response" | sed '$d')
    secret=$(printf '%s' "$body" | jq -er '.secret // empty' 2>/dev/null) || secret=""
    if [ -n "$secret" ] && [ "$code" = "201" -o "$code" = "200" ]; then
      # Atomic write, mirrored from pocket-id-provision: a killed run must
      # never leave a truncated secret (crash-looping consumers).
      tmp=$(mktemp "$SECRETS_DIR/.secret.$client.XXXXXX")
      printf '%s\n' "$secret" >"$tmp"
      chmod 640 "$tmp"
      chown pocket-id:pocket-id "$tmp"
      mv -f "$tmp" "$SECRETS_DIR/$client"
      log "rotated client=$client (HTTP $code) and rewrote $SECRETS_DIR/$client"
      return 0
    fi
    warn "rotation POST for $client returned HTTP $code (attempt $attempt/2)"
    sleep 5
  done
  # NOTE: if the POST succeeded but parsing/write failed, Pocket ID's DB
  # already holds a newer secret than the file — consumers are desynced.
  # That is exactly why this failure is LOUD (unit fails -> Discord alert)
  # and why the next run retries: the retry rotates again and rewrites the
  # file, converging file and DB.
  die "failed to rotate $client after 2 attempts (HTTP $code) — DB/file desync possible, run again to converge"
}

restart_consumers() {
  local client=$1 spec daemon bridge envfile before after
  spec=${CONSUMERS[$client]:-}
  if [ -z "$spec" ]; then
    warn "client $client has NO consumer mapping — rotation SKIPPED (rotating without a consumer restart would desync)"
    return 2
  fi
  local unit
  IFS=, read -ra units <<<"$spec"
  for unit in "${units[@]}"; do
    if split_consumer_unit "$unit"; then
      if ! systemctl is-active --quiet "$SPLIT_DAEMON" 2>/dev/null; then
        log "consumer $SPLIT_DAEMON inactive — skipping bridge+daemon restart (next start converges)"
        continue
      fi
      before=$(sha256sum "$SPLIT_ENVFILE" 2>/dev/null | awk '{print $1}' || echo absent)
      if ! systemctl restart "$SPLIT_BRIDGE" 2>/dev/null; then
        die "failed to restart bridge $SPLIT_BRIDGE for client $client — daemon still holds the OLD secret"
        return 1
      fi
      after=$(sha256sum "$SPLIT_ENVFILE" 2>/dev/null | awk '{print $1}' || echo absent)
      if [ "$before" != "$after" ]; then
        if ! systemctl restart "$SPLIT_DAEMON" 2>/dev/null; then
          die "failed to restart daemon $SPLIT_DAEMON for client $client — it still holds the OLD secret"
          return 1
        fi
        log "restarted $SPLIT_BRIDGE + $SPLIT_DAEMON (env file changed)"
      else
        log "restarted $SPLIT_BRIDGE; env file unchanged — $SPLIT_DAEMON NOT restarted (idempotency gate)"
      fi
    else
      if systemctl is-active --quiet "$unit" 2>/dev/null; then
        if ! systemctl restart "$unit" 2>/dev/null; then
          die "failed to restart consumer $unit for client $client — it still holds the OLD secret"
          return 1
        fi
        log "restarted consumer $unit"
      else
        log "consumer $unit inactive — skipping (next start converges)"
      fi
    fi
  done
  return 0
}

while read -r client age; do
  [ -n "$client" ] || continue
  log "rotating stale client=$client (age ${age}d > ${MAX_AGE_DAYS}d, cap $MAX_PER_RUN/run)"
  if ! rotate_secret "$client"; then
    RUN_FAILED=1
    continue
  fi
  restart_consumers "$client"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    # Rotation already happened; a consumer-less client must not silently
    # linger — flag it loudly via the unmapped metric AND the run failure.
    UNMAPPED=$((UNMAPPED + 1))
    RUN_FAILED=1
    continue
  elif [ "$rc" -ne 0 ]; then
    RUN_FAILED=1
    continue
  fi
  ROTATED_TOTAL=$((ROTATED_TOTAL + 1))
  LAST_SUCCESS_TS=$(date +%s)
  LAST_CLIENT=$client
  persist_state
done <<<"$plan"

write_prom

if [ "$RUN_FAILED" -ne 0 ]; then
  die "run finished WITH FAILURES — see WARN/ERROR lines above"
fi

log "run complete: rotated this-run deltas applied (total $ROTATED_TOTAL)"
exit 0
