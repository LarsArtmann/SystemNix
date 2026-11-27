#!/usr/bin/env bash
# Deploy fire-permission watcher: only launch `nix run .#deploy` when the
# repo is quiescent, per the canonical pattern canonized in AGENTS.md
# ("Deploy-vs-executor race, 2026-10-25, gen-949").
#
# Why this exists: on 2026-10-25 evening, a live plan-executor session
# committing milestone waves made THREE deploy batteries die in §11 mid-run
# voids / mid-float evals before the hand-rolled ~/.cache watcher (5
# iterations) landed gen-949. The §11 tree-stamp voids on ANY eval-relevant
# mid-battery change, so short stability windows are unwinnable — the
# stability requirement is DERIVED from the thing it protects:
#
#   MIN_STABLE * POLL_INTERVAL + HEAT_STALE_SECS >= full battery duration
#   (pre-deploy battery ~= 8-10 min incl. the §11 FOD preview; defaults
#   below give 4*60s polls of a 300s-cold tree ~= 10 min of demonstrated
#   quiescence before firing)
#
# Gates, in order:
#   A. clean tree        — `git status --porcelain` empty (untracked files
#                          under auto-discovered module dirs break evals via
#                          the tracked-files trap, so porcelain must be
#                          fully empty)
#   B. cold tree         — no eval-relevant path (scripts/lib/eval-relevant-
#                          paths.sh) modified within HEAT_STALE_SECS
#   C. green-eval pre-gate — `nix eval --raw …toplevel.drvPath` rc=0
#                          (NO --no-link on nix eval; 07-09 report §d.3)
# After A+B hold for MIN_STABLE consecutive polls and C passes:
#   default (dry):       report WOULD-FIRE and exit 0
#   --fire:              exec `nix run .#deploy` and classify the outcome:
#                          rc=0                                  -> exit 0
#                          rc=13 / flock-conflict                -> loop back
#                           to polling with bounded retries (2026-10-28
#                           opencloud-deploy8 UPDATE: deploy #8 lost a 51 s
#                           race to a predecessor sequencer's own fire and
#                           simply died)
#                          rc=1 + §11-void/eval class in output  -> exit 3
#                           (EXPECTED race under a live executor; re-arm)
#                          anything else                         -> exit 1
#                           (stop for human review)
# Every stop/handoff exit carries a DISARM-LIST of other armed watchers
# (2026-10-28 UPDATE: two armed sequencers for the same payload raced at
# 23:31 because the earlier stop never disarmed the first one).
#   --probe:             single-shot gates A+B, verdict to STDOUT only, no
#                         polling, never fires; exit 0 clean+cold / 1
#                         dirty-or-hot (deploy.sh's §0.5 advisory is the
#                         in-tree consumer, 2026-11-15: make skipping the
#                         quiescence check LOUD instead of silent)
#   --probe-eval:        --probe plus gate C; exit 2 when the eval fails
#
# PSI/memory/pressure gates are deliberately NOT here: deploy.sh's own
# entry gates own those, and this watcher must not duplicate (or widen,
# via an extra §11 probe) the window it tries to shrink.
#
# Usage: deploy-when-quiescent.sh [--fire] [--probe] [--probe-eval]
#        [--poll-interval SEC] [--min-stable N] [--stale-secs SEC]
#        [--host NAME] [--log FILE]
# Run:   bash scripts/deploy-when-quiescent.sh            (observe mode)
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/eval-relevant-paths.sh disable=SC1091
source "$REPO_ROOT/scripts/lib/eval-relevant-paths.sh"

FIRE=false
PROBE=false
PROBE_EVAL=false
LOCK_RETRIES=0
MAX_LOCK_RETRIES="${MAX_LOCK_RETRIES:-3}"
POLL_INTERVAL=60
MIN_STABLE=4
STALE_SECS=300
HOST="evo-x2"
LOG_FILE="${HOME}/.cache/deploy-when-quiescent.log"

while [ $# -gt 0 ]; do
  case "$1" in
  --fire) FIRE=true ;;
  --probe) PROBE=true ;;
  --probe-eval)
    PROBE=true
    PROBE_EVAL=true
    ;;
  --poll-interval)
    POLL_INTERVAL="${2:?--poll-interval needs seconds}"
    shift
    ;;
  --min-stable)
    MIN_STABLE="${2:?--min-stable needs a count}"
    shift
    ;;
  --stale-secs)
    STALE_SECS="${2:?--stale-secs needs seconds}"
    shift
    ;;
  --host)
    HOST="${2:?--host needs a name}"
    shift
    ;;
  --log)
    LOG_FILE="${2:?--log needs a path}"
    shift
    ;;
  *)
    echo "unknown option: $1" >&2
    exit 64
    ;;
  esac
  shift
done

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

clean_tree() {
  [ -z "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]
}

hot_tree() {
  # Prints the newest eval-relevant path touched within the stale window,
  # empty when cold. -newermt with a relative date is GNU find syntax.
  find "${EVAL_RELEVANT_PATHS[@]}" \
    -newermt "$STALE_SECS seconds ago" -print 2>/dev/null | head -3
}

green_eval() {
  # Deliberately --raw WITHOUT --no-link: `nix eval` rejects --no-link
  # (2026-10-25 §d.3 — the flag bug that lost a fire window).
  nix eval --raw \
    ".#nixosConfigurations.$HOST.config.system.build.toplevel.drvPath" \
    >/dev/null 2>&1
}

print_disarm_list() {
  # 2026-10-28 opencloud-deploy8 UPDATE: every stop/handoff must carry a
  # DISARM-LIST of armed sibling automation — two armed sequencers for the
  # same payload raced at 23:31 because the earlier stop never disarmed the
  # first watcher. pgrep output goes through redact-argv.sh (secrets ride
  # argv — the 2026-10-22 monitor365 --jwt-secret class).
  local others
  others=$(pgrep -af 'deploy-when-quiescent' 2>/dev/null | grep -v "^$$ " || true)
  if [ -n "$others" ]; then
    if [ -x "$REPO_ROOT/scripts/redact-argv.sh" ]; then
      # Fail closed: when the redactor has no program it prints nothing
      # and exits 1; the listing is withheld, never shown unredacted.
      if ! redacted=$(printf '%s\n' "$others" | "$REPO_ROOT/scripts/redact-argv.sh" 2>/dev/null); then
        redacted="  (listing withheld: the redactor has no program, see scripts/redact-argv.sh)"
      fi
      others="$redacted"
    fi
    log "DISARM-LIST — other armed quiescence watchers (verify + kill before arming a replacement):"
    while IFS= read -r watcher_line; do
      [ -n "$watcher_line" ] && log "  $watcher_line"
    done <<<"$others"
  else
    log "DISARM-LIST: no other armed quiescence watchers found"
  fi
}

if [ "$PROBE" = true ]; then
  # Single-shot snapshot for callers (deploy.sh §0.5 advisory, 2026-11-15):
  # gates A+B evaluated ONCE, verdict to STDOUT only (no log file — the
  # caller's output is the surface), no sleep loop, never fires. Exit 0 =
  # clean + cold, 1 = dirty tree and/or hot eval-relevant paths, 2 = gate C
  # (--probe-eval) eval red, 64 = usage.
  probe_fail=0
  if ! clean_tree; then
    echo "PROBE-DIRTY: $(git -C "$REPO_ROOT" status --porcelain | wc -l | tr -d ' ') working-tree entries (untracked files under module dirs break evals — the tracked-files trap)"
    probe_fail=1
  fi
  probe_hot=$(hot_tree)
  if [ -n "$probe_hot" ]; then
    echo "PROBE-HOT: eval-relevant path(s) touched <${STALE_SECS}s ago: $(echo "$probe_hot" | tr '\n' ' ')"
    probe_fail=1
  fi
  if [ "$probe_fail" -eq 0 ]; then
    echo "PROBE-QUIESCENT: tree clean + cold for ${STALE_SECS}s"
    if [ "$PROBE_EVAL" = true ] && ! green_eval; then
      echo "PROBE-EVAL-RED: toplevel drvPath eval failed — mid-executor half-wave is the prime suspect"
      exit 2
    fi
    exit 0
  fi
  exit 1
fi

stable=0
log "deploy-when-quiescent: start (fire=$FIRE poll=${POLL_INTERVAL}s min-stable=$MIN_STABLE stale=${STALE_SECS}s host=$HOST)"

while true; do
  if ! clean_tree; then
    if [ "$stable" -gt 0 ]; then
      log "dirty tree again — stability counter reset (was $stable)"
    fi
    stable=0
    log "waiting: tree dirty ($(git -C "$REPO_ROOT" status --porcelain | wc -l | tr -d ' ') entries)"
    sleep "$POLL_INTERVAL"
    continue
  fi

  local_hot=$(hot_tree)
  if [ -n "$local_hot" ]; then
    if [ "$stable" -gt 0 ]; then
      log "eval-relevant mutation again — stability counter reset (was $stable)"
    fi
    stable=0
    log "waiting: hot eval-relevant path(s): $(echo "$local_hot" | tr '\n' ' ')"
    sleep "$POLL_INTERVAL"
    continue
  fi

  stable=$((stable + 1))
  log "quiescent poll $stable/$MIN_STABLE (tree clean + cold ${STALE_SECS}s)"

  if [ "$stable" -lt "$MIN_STABLE" ]; then
    sleep "$POLL_INTERVAL"
    continue
  fi

  log "stability threshold reached — running green-eval pre-gate"
  if ! green_eval; then
    stable=0
    log "pre-gate eval FAILED — resetting stability (mid-executor half-wave is the prime suspect); will re-prove quiescence"
    sleep "$POLL_INTERVAL"
    continue
  fi

  if [ "$FIRE" = true ]; then
    log "FIRING: nix run .#deploy"
    deploy_out=$(nix run .#deploy 2>&1 | tee -a "$LOG_FILE")
    deploy_rc=${PIPESTATUS[0]}
    if [ "$deploy_rc" -eq 0 ]; then
      log "deploy rc=0"
      exit 0
    fi
    # Classify THIS run's output only (the log accumulates across runs —
    # grepping it would classify the last watcher's race as this one's).
    # rc=13 / flock-conflict first (2026-10-28 deploy8 UPDATE): a
    # predecessor sequencer's own fire legitimately holds the lock — loop
    # back to polling with a bounded retry budget instead of dying.
    if [ "$deploy_rc" -eq 13 ] || grep -q 'Another deploy is already running' <<<"$deploy_out"; then
      LOCK_RETRIES=$((LOCK_RETRIES + 1))
      if [ "$LOCK_RETRIES" -gt "$MAX_LOCK_RETRIES" ]; then
        log "deploy rc=13/flock-conflict — retry budget (${MAX_LOCK_RETRIES}) exhausted; STOP for human review"
        print_disarm_list
        exit 1
      fi
      log "deploy rc=13 (flock held by another deploy) — looping back to polling (retry $LOCK_RETRIES/$MAX_LOCK_RETRIES)"
      stable=0
      sleep "$POLL_INTERVAL"
      continue
    fi
    if grep -qE 'MUTATED|evaluation failed|flake check' <<<"$deploy_out"; then
      log "deploy rc=$deploy_rc with §11-void/eval signature — EXPECTED race class under a live executor; re-arm the watcher"
      print_disarm_list
      exit 3
    fi
    log "deploy rc=$deploy_rc — NOT a recognized race signature; STOP for human review (tail $LOG_FILE)"
    print_disarm_list
    exit 1
  else
    log "WOULD-FIRE (dry mode) — re-run with --fire to deploy"
    exit 0
  fi
done
