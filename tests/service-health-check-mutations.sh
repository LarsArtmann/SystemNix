#!/usr/bin/env bash
# Mutation legs for service-health-check-harness.sh.
#
# usage: service-health-check-mutations.sh <script> <harness> <work-root>
#
# A behavior test proves nothing until it is seen to fail: every mutated
# copy of the checker must FAIL the harness, and a comment-only control must
# pass. Each leg is one historical or plausible defect, re-introduced into a
# copy of the SHIPPED script by a literal one-site replacement.
set +e
set +u
set -o pipefail

SRC="$1"
HARNESS="$2"
ROOT="$3"
mkdir -p "$ROOT"

rc_overall=0
leg() {
    # leg <name> <literal to replace, first occurrence> <replacement> <fail|pass>
    name="$1"
    dir="$ROOT/$name"
    mkdir -p "$dir"
    if ! FROM="$2" TO="$3" awk '
        {
            line = $0
            at = index(line, ENVIRON["FROM"])
            if (at && !done) {
                line = substr(line, 1, at - 1) ENVIRON["TO"] substr(line, at + length(ENVIRON["FROM"]))
                done = 1
            }
            print line
        }
        END { if (!done) exit 3 }
    ' "$SRC" > "$dir/mutant.sh"; then
        echo "LEG $name: BROKEN LEG, the mutation matched nothing"
        rc_overall=1
        return
    fi
    bash "$HARNESS" "$dir/mutant.sh" "$dir/work" > "$dir/harness.log" 2>&1
    rc=$?
    passes="$(grep -c '^PASS' "$dir/harness.log")"
    first_fail="$(grep -m1 '^FAIL' "$dir/harness.log")"
    if [ "$4" = fail ]; then
        if [ "$rc" -eq 0 ]; then
            echo "LEG $name: MUTANT SURVIVED (harness passed, $passes assertions)"
            rc_overall=1
        else
            echo "LEG $name: killed after $passes assertions: $first_fail"
        fi
    else
        if [ "$rc" -eq 0 ]; then
            echo "LEG $name: control passed ($passes assertions)"
        else
            echo "LEG $name: CONTROL FAILED: $first_fail"
            rc_overall=1
        fi
    fi
}

# The literals are single-quoted on purpose: they are text to find and
# text to put in its place, nothing here may expand.
# shellcheck disable=SC2016
leg control 'a latch, not a severity' 'a latch (not a severity)' pass
# The 2026-10-17..28 live defect: the trigger lookup never finds a timer.
leg classifier-dead 'TriggeredBy)" || true' 'TriggeredBy-unavailable)" || true' fail
leg strike-never-counts 'strikes=$((strikes + 1))' 'strikes=1' fail
leg dedup-removed 'if [ "$new_failure" = true ]; then' 'if true; then' fail
# The 2026-11-24..28 live defect: any change of the member set re-notifies.
leg dedup-by-set-change 'if ! grep -qxF -- "$member" <<< "$notified"; then' 'if [ "$current" != "$notified" ]; then' fail
leg ledger-never-pruned '*) rm -f "$ledger" || true ;;' '*) : ;;' fail
leg transient-listed 'if [ "$(unit_prop "$scope" "$unit" Transient)" != "yes" ]; then' 'if true; then' fail
leg timer-state-ignored '    retry_owed=false' '    retry_owed=true' fail
leg age-cap-removed '[ "$NOW_EPOCH" -lt $((failed_epoch + ACUTE_MAX_AGE_SECONDS)) ]' 'true' fail
leg empty-timestamp-trusted '    if [ -z "$failed_at" ]; then' '    if false; then' fail
leg user-scope-unlabelled 'sweep_failed user "user, failed"' 'sweep_failed user "failed"' fail
leg recovery-not-reset '        rm -f "$NOTIFY_STATE"' '        :' fail
leg trigger-list-unsplit $'done <<< "$(printf \'%s\' "$trigger" | tr \' \' \'\\n\')"' 'done <<< "$trigger"' fail
leg ignored-pattern-dropped '            session-* | user@*)' '            never-matches-*)' fail
exit $rc_overall
