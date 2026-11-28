#!/usr/bin/env bash
# Behavior test for the service-health-check script (no VM, no systemd).
#
# usage: service-health-check-harness.sh <script> <work-dir>
#
# tests/test-service-health-check.nix calls this with the SHIPPED
# writeShellApplication artifact. Stubs are sed-INJECTED into a copy of the
# script, because the wrapper pins PATH to its runtimeInputs (systemd first
# among them), so PATH-level stubs can never shadow the real binaries.
#
# The 2026-11-28 storm this pins down: the acute-vs-chronic classifier never
# fired once (it asked for "foo.service.timer"), so 17 scheduled jobs whose
# last run failed were listed under "Health Check: services down", and the
# desktop dedup hashed the whole member set while members flapped: 99
# critical popups in 35.5 hours.
set +e
set +u
set -o pipefail

SRC="$1"
WORK="$2"
STUBS="$WORK/stubs"
export HC_FIXTURE="$WORK/fixture"
export HC_HOME="$WORK/home"
mkdir -p "$STUBS" "$HC_FIXTURE" "$HC_HOME"

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------

# systemctl answers exactly the forms the checker uses, from plain-text
# fixture files under $HC_FIXTURE:
#   <scope>.failed  one unit id per failed service (scope = system | user)
#   props           <scope>|<unit>|<prop>=<value>
#   inactive        <scope>|<unit>, for every unit or timer that is not active
# An unknown invocation exits 64: a new call shape must fail loudly here,
# never pass as an empty answer.
printf '#!%s\n' "$BASH" > "$STUBS/systemctl"
cat >> "$STUBS/systemctl" <<'STUB'
fix="$HC_FIXTURE"
scope=system
args=""
for arg in "$@"; do
    case "$arg" in
        --user) scope=user ;;
        --no-legend | --no-pager | --plain | --quiet | --value) ;;
        *) args="$args $arg" ;;
    esac
done
# shellcheck disable=SC2086
set -- $args
cmd="$1"
shift
case "$cmd" in
    is-active)
        if grep -qxF -- "$scope|$1" "$fix/inactive"; then exit 3; fi
        exit 0
        ;;
    show)
        # show <unit> -p <prop>
        awk -v key="$scope|$1|$3=" '
            index($0, key) == 1 { print substr($0, length(key) + 1); found = 1; exit }
            END { if (!found) print "" }
        ' "$fix/props"
        exit 0
        ;;
    --failed)
        if [ "$1" != "--type=service" ]; then
            echo "stub systemctl: unexpected --failed arguments: $*" >&2
            exit 64
        fi
        awk '{ print $1 " loaded failed failed " $1 }' "$fix/$scope.failed"
        exit 0
        ;;
    *)
        echo "stub systemctl: unexpected invocation: $cmd $*" >&2
        exit 64
        ;;
esac
STUB

# notify-send: "-u <urgency> <summary> <body>", one line per call.
printf '#!%s\n' "$BASH" > "$STUBS/notify-send"
cat >> "$STUBS/notify-send" <<'STUB'
printf 'notify|%s|%s|%s\n' "$2" "$3" "$(printf '%s' "$4" | tr '\n' '~')" >> "$HC_FIXTURE/notify.log"
STUB

# sleep: the critical-service retry loop must not cost 6s per run.
printf '#!%s\n' "$BASH" > "$STUBS/sleep"
echo 'exit 0' >> "$STUBS/sleep"
chmod +x "$STUBS"/*

sed -e "s|\bsystemctl\b|$STUBS/systemctl|g" \
    -e "s|\bnotify-send\b|$STUBS/notify-send|g" \
    -e "s|\bsleep\b|$STUBS/sleep|g" \
    "$SRC" > "$WORK/check"
chmod +x "$WORK/check"

# A failed injection must fail loudly, never phantom-green.
n_systemctl="$(grep -c "$STUBS/systemctl" "$WORK/check")"
if [ "$n_systemctl" -lt 8 ]; then
    echo "FAIL: systemctl stub injection incomplete ($n_systemctl/8 sites)"
    exit 1
fi
n_notify="$(grep -c "$STUBS/notify-send" "$WORK/check")"
if [ "$n_notify" -ne 1 ]; then
    echo "FAIL: notify-send stub injection incomplete ($n_notify/1 sites)"
    exit 1
fi
n_sleep="$(grep -c "$STUBS/sleep" "$WORK/check")"
if [ "$n_sleep" -lt 1 ]; then
    echo "FAIL: sleep stub injection incomplete ($n_sleep/1 sites)"
    exit 1
fi
echo "PASS: stub injection coverage (8 systemctl, 1 notify-send, 1 sleep)"

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

scenario=0
reset() {
    # A fresh home per scenario: ledger and popup state never leak between
    # scenarios, and nothing has to be deleted to get there.
    scenario=$((scenario + 1))
    export HC_HOME="$WORK/home-$scenario"
    mkdir -p "$HC_FIXTURE" "$HC_HOME"
    : > "$HC_FIXTURE/system.failed"
    : > "$HC_FIXTURE/user.failed"
    : > "$HC_FIXTURE/props"
    : > "$HC_FIXTURE/inactive"
    : > "$HC_FIXTURE/notify.log"
}

failed_add() {
    echo "$2" >> "$HC_FIXTURE/$1.failed"
}

recover() {
    # recover <scope> <unit>...: these units are no longer failed.
    scope="$1"
    shift
    grep -vxF -- "$@" "$HC_FIXTURE/$scope.failed" > "$HC_FIXTURE/$scope.failed.new"
    mv "$HC_FIXTURE/$scope.failed.new" "$HC_FIXTURE/$scope.failed"
}

prop() {
    # prop <scope> <unit> <prop> <value>: a repeated key replaces its value.
    key="$1|$2|$3="
    grep -vF -- "$key" "$HC_FIXTURE/props" > "$HC_FIXTURE/props.new"
    echo "$key$4" >> "$HC_FIXTURE/props.new"
    mv "$HC_FIXTURE/props.new" "$HC_FIXTURE/props"
}

inactive() {
    # inactive <scope> <unit-or-timer>
    echo "$1|$2" >> "$HC_FIXTURE/inactive"
}

# A systemd-style timestamp ("Sat 2026-11-28 11:04:37 CET") for N seconds ago.
ago() {
    date -d "@$(( $(date +%s) - $1 ))" "+%a %Y-%m-%d %H:%M:%S %Z"
}

# daemon_down <scope> <unit>: failed, no trigger, nothing retries it.
daemon_down() {
    failed_add "$1" "$2"
    prop "$1" "$2" Transient no
    prop "$1" "$2" InactiveEnterTimestamp "$(ago 60)"
}

# timer_job <scope> <unit> <seconds>: a timer-driven unit whose latest run
# failed N seconds ago.
timer_job() {
    failed_add "$1" "$2"
    prop "$1" "$2" Transient no
    prop "$1" "$2" TriggeredBy "retry.timer"
    prop "$1" "$2" InactiveEnterTimestamp "$(ago "$3")"
}

# refail <scope> <unit> <seconds>: the same unit ran again and failed again.
refail() {
    prop "$1" "$2" InactiveEnterTimestamp "$(ago "$3")"
}

# ---------------------------------------------------------------------------
# Runner and assertions
# ---------------------------------------------------------------------------

run() {
    rc=0
    HOME="$HC_HOME" bash "$WORK/check" > "$WORK/out.txt" 2> "$WORK/err.txt" || rc=$?
    if [ -s "$WORK/err.txt" ]; then
        echo "FAIL: checker wrote to stderr:" >&2
        cat "$WORK/err.txt" >&2
        exit 1
    fi
}

dump() {
    echo "--- checker stdout" >&2
    cat "$WORK/out.txt" >&2
    echo "--- popups" >&2
    cat "$HC_FIXTURE/notify.log" >&2
    exit 1
}

expect() {
    # expect <label> <actual> <expected>
    if [ "$2" != "$3" ]; then
        echo "FAIL: $1: got [$2], want [$3]" >&2
        dump
    fi
    echo "PASS: $1"
}

out_has() {
    # out_has <label> <fixed string the checker output must contain>
    if ! grep -qF -- "$2" "$WORK/out.txt"; then
        echo "FAIL: $1: output lacks [$2]" >&2
        dump
    fi
    echo "PASS: $1"
}

out_lacks() {
    # out_lacks <label> <fixed string the checker output must not contain>
    n="$(grep -cF -- "$2" "$WORK/out.txt")"
    if [ "$n" != 0 ]; then
        echo "FAIL: $1: output contains [$2] ($n line(s))" >&2
        dump
    fi
    echo "PASS: $1"
}

out_count() {
    # out_count <label> <expected> <fixed string>: how many output lines carry it
    n="$(grep -cF -- "$3" "$WORK/out.txt")"
    expect "$1" "$n" "$2"
}

popups() {
    wc -l < "$HC_FIXTURE/notify.log" | tr -d ' '
}

popup_body_has() {
    # popup_body_has <label> <fixed string>: the LAST popup lists this member
    if ! tail -n 1 "$HC_FIXTURE/notify.log" | grep -qF -- "$2"; then
        echo "FAIL: $1: last popup lacks [$2]" >&2
        dump
    fi
    echo "PASS: $1"
}

ledger() {
    cat "$HC_HOME/.cache/service-health-check/failures/$1" 2>/dev/null || echo "<absent>"
}

strikes() {
    # strikes <scope:unit>: the strike count in that unit's ledger file
    cut -d' ' -f1 <<< "$(ledger "$1")"
}

state_file() {
    cat "$HC_HOME/.cache/service-health-check/last-notified-failed" 2>/dev/null || echo "<absent>"
}

state_count() {
    # state_count <label> <expected> <fixed string>
    n="$(grep -cF -- "$3" <<< "$(state_file)")"
    expect "$1" "$n" "$2"
}

# ---------------------------------------------------------------------------
# Scenarios (one shared fixture, as on a real host: state carries over
# unless a scenario calls reset)
# ---------------------------------------------------------------------------

echo "## a timer-driven job: first failure is acute, second is chronic"
reset
timer_job system cron-job.service 60
run
expect "a1 first failure exits 0" "$rc" 0
out_has "a2 first failure is PENDING in the journal" "cron-job.service (failed, timer retry pending)"
out_lacks "a3 first failure is not FAILED" "FAILED:"
expect "a4 first failure fires no popup" "$(popups)" 0
expect "a5 first failure is one strike" "$(strikes system:cron-job.service)" 1
first_epoch="$(cut -d' ' -f2 <<< "$(ledger system:cron-job.service)")"

run
expect "a6 same failure, next check: still exit 0" "$rc" 0
out_has "a7 same failure is still PENDING" "cron-job.service (failed, timer retry pending)"
expect "a8 same failure fires no popup" "$(popups)" 0
expect "a9 same failure is still one strike" "$(strikes system:cron-job.service)" 1

refail system cron-job.service 30
run
expect "a10 failed again after the retry: exit 1" "$rc" 1
out_has "a11 failed again is FAILED" "FAILED:"
out_lacks "a12 failed again is no longer PENDING" "retry pending"
expect "a13 failed again fires one popup" "$(popups)" 1
popup_body_has "a14 the popup names the unit" "cron-job.service (failed)"
popup_body_has "a15 the popup keeps its title" "Health Check: services down"
expect "a16 failed again is the second strike" "$(strikes system:cron-job.service)" 2
if [ "$(cut -d' ' -f2 <<< "$(ledger system:cron-job.service)")" = "$first_epoch" ]; then
    echo "FAIL: a17 the ledger must record the new failure epoch" >&2
    dump
fi
echo "PASS: a17 the ledger must record the new failure epoch"

run
expect "a18 chronic, next check: exit 1" "$rc" 1
out_has "a19 chronic member already notified: silent" "NOTIFY-SKIPPED"
expect "a20 no second popup for the same member" "$(popups)" 1

echo "## popups follow members, not the hash of the set"
daemon_down system daemon.service
run
expect "b1 a new member next to a chronic one: exit 1" "$rc" 1
out_has "b2 a new member notifies" "NOTIFIED"
expect "b3 one popup for the new member" "$(popups)" 2
out_count "b4 daemon listed once" 1 "daemon.service"
popup_body_has "b5 the popup lists the new member" "daemon.service (failed)"
popup_body_has "b6 the popup lists the chronic member too" "cron-job.service (failed)"

recover system daemon.service
run
expect "b7 a member recovering leaves the other failed: exit 1" "$rc" 1
out_has "b8 a pure shrink is silent" "NOTIFY-SKIPPED"
expect "b9 no popup for good news" "$(popups)" 2
out_lacks "b10 the recovered member is gone from FAILED" "daemon.service"
state_count "b11 the state file drops the recovered member" 0 "daemon.service"
state_count "b12 the state file keeps the chronic member" 1 "cron-job.service (failed)"

echo "## recovery starts a new episode"
recover system cron-job.service
run
expect "c1 everything green: exit 0" "$rc" 0
out_has "c2 recovery is reported" "RECOVERED"
out_has "c3 the OK line" "critical services active, no failed services"
expect "c4 the ledger of the recovered unit is pruned" "$(ledger system:cron-job.service)" "<absent>"
expect "c5 the popup state is cleared" "$(state_file)" "<absent>"

timer_job system cron-job.service 60
run
expect "c6 a failure after recovery is acute again" "$rc" 0
expect "c7 a failure after recovery is one strike" "$(strikes system:cron-job.service)" 1

echo "## one unit recovering keeps the other unit's ledger"
timer_job system second-job.service 60
refail system cron-job.service 30
run
expect "d1 two failed timer jobs" "$rc" 1
recover system second-job.service
run
expect "d2 the still-failed unit stays chronic" "$rc" 1
expect "d3 its ledger survives" "$(strikes system:cron-job.service)" 2
expect "d4 the recovered unit's ledger is pruned" "$(ledger system:second-job.service)" "<absent>"

echo "## nothing retries these: FAILED at once"
reset
daemon_down system daemon.service
run
expect "e1 a daemon without trigger: exit 1" "$rc" 1
out_has "e2 a daemon without trigger is FAILED" "daemon.service (failed)"
out_lacks "e3 never PENDING" "retry pending"
expect "e4 one popup" "$(popups)" 1
expect "e5 no ledger for a unit without trigger" "$(ledger system:daemon.service)" "<absent>"

reset
timer_job system job.service 60
inactive system retry.timer
run
expect "e6 an inactive timer: exit 1" "$rc" 1
out_has "e7 an inactive timer makes the failure FAILED at once" "job.service (failed)"
expect "e8 one popup" "$(popups)" 1

reset
timer_job system daily-job.service 90000
run
expect "e9 a first failure older than a day: exit 1" "$rc" 1
out_has "e10 it is FAILED at once" "daily-job.service (failed)"
expect "e11 one popup" "$(popups)" 1

reset
failed_add system stale.service
prop system stale.service Transient no
prop system stale.service TriggeredBy retry.timer
run
expect "e12 an unparsable failure time fails closed: exit 1" "$rc" 1
out_has "e13 it is FAILED" "stale.service (failed)"

reset
failed_add system multi.service
prop system multi.service Transient no
prop system multi.service TriggeredBy "retry.timer other.path"
prop system multi.service InactiveEnterTimestamp "$(ago 60)"
inactive system retry.timer
run
expect "e14 any active trigger owes a retry: first failure exits 0" "$rc" 0
out_has "e15 it is PENDING" "multi.service (failed, timer retry pending)"
inactive system other.path
run
expect "e16 no trigger active: exit 1" "$rc" 1
out_has "e17 FAILED at once" "multi.service (failed)"

echo "## what the sweep leaves alone"
reset
failed_add system run-abc123.service
prop system run-abc123.service Transient yes
prop system run-abc123.service InactiveEnterTimestamp "$(ago 60)"
run
expect "f1 a failed transient unit is debris, not an outage" "$rc" 0
out_lacks "f2 it is not listed" "run-abc123.service"

reset
failed_add system session-2.scope
failed_add system user@1000.service
prop system user@1000.service Transient no
prop system user@1000.service InactiveEnterTimestamp "$(ago 60)"
run
expect "f3 session and user-manager units are ignored" "$rc" 0
out_lacks "f4 the user manager is not listed" "user@1000.service"

echo "## the user manager"
reset
timer_job user nanny.service 60
run
expect "g1 a user unit's first failure: exit 0" "$rc" 0
out_has "g2 it is labelled as a user unit" "nanny.service (user, failed, timer retry pending)"
refail user nanny.service 30
run
expect "g3 failed again: exit 1" "$rc" 1
out_has "g4 FAILED with the user label" "nanny.service (user, failed)"
expect "g5 one popup" "$(popups)" 1
expect "g6 its ledger lives under the user scope" "$(strikes user:nanny.service)" 2

echo "## the critical list"
reset
inactive system caddy
failed_add system caddy.service
prop system caddy.service Transient no
prop system caddy.service InactiveEnterTimestamp "$(ago 60)"
run
expect "h1 a critical daemon down: exit 1" "$rc" 1
out_count "h2 listed once, not once per sweep" 1 "caddy.service"
out_lacks "h3 no suffix on a critical daemon" "caddy.service (failed)"
expect "h4 one popup" "$(popups)" 1

reset
inactive system forgejo
run
expect "h5 a gated service that is down: exit 0" "$rc" 0
out_has "h6 it is reported as GATED" "forgejo (gated: /var/lib/forgejo/.subvol-migrated absent)"

echo "## state left by the previous checker version and damaged state"
reset
mkdir -p "$HC_HOME/.cache/service-health-check"
echo "9f2c3a4b5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708" > "$HC_HOME/.cache/service-health-check/last-notified-failed"
daemon_down system daemon.service
run
expect "i1 a hash-shaped state file notifies once" "$rc" 1
out_has "i2 NOTIFIED" "NOTIFIED"
expect "i3 one popup" "$(popups)" 1
run
out_has "i4 then the rewritten state dedups" "NOTIFY-SKIPPED"
expect "i5 still one popup" "$(popups)" 1

reset
timer_job system job.service 60
mkdir -p "$HC_HOME/.cache/service-health-check/failures"
echo "corrupt ledger" > "$HC_HOME/.cache/service-health-check/failures/system:job.service"
run
expect "i6 a corrupt ledger counts as a first strike" "$rc" 0
expect "i7 rewritten as one strike" "$(strikes system:job.service)" 1

echo "## both lists in one report"
reset
daemon_down system daemon.service
timer_job system cron-job.service 60
run
expect "j1 exit 1 with one FAILED and one PENDING member" "$rc" 1
out_has "j2 the PENDING list is printed next to FAILED" "PENDING (first failure, retry owed on its trigger"
popup_body_has "j3 the popup carries the failed member only" "daemon.service (failed)"
if tail -n 1 "$HC_FIXTURE/notify.log" | grep -qF "cron-job.service"; then
    echo "FAIL: j4 the popup must not carry the pending member" >&2
    dump
fi
echo "PASS: j4 the popup must not carry the pending member"

echo "## documented limit: a unit that passes between two failures never escalates"
reset
timer_job system flappy.service 60
run
recover system flappy.service
run
expect "k1 green in between: exit 0" "$rc" 0
timer_job system flappy.service 60
run
expect "k2 the next failure is acute again: exit 0" "$rc" 0
out_has "k3 PENDING" "flappy.service (failed, timer retry pending)"

echo
echo "ALL PASS: service-health-check classifier, ledger and desktop dedup"
