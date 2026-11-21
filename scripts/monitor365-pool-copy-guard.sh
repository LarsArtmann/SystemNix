#!/usr/bin/env bash
# ExecStartPre concurrency guard for monitor365-pool-copy.
#
# The pool-copy unit has NO dependency edge on monitor365-server-backup:
# the `wants` edge was dropped 2026-11-20 because every timer fire
# re-STARTED the finished oneshot backup (export + retention twice per
# night). Without the edge the unit's `after` is inert — systemd orders
# only units inside the same transaction, and the timer's start job does
# not pull the backup unit in. This guard is the ordering: refuse the
# copy while the backup is active/activating/reloading (racing the
# quiesced window — export, retention, VACUUM, the one-shot
# RETENTION_COMPACT mv — would duplicate a torn DB), and fail CLOSED on
# an unreadable state (copying blind is worse than a skipped night). A
# refusal fails the unit (onFailure alert); the next nightly fire
# catches up.
#
# Fixture: scripts/test-monitor365-pool-copy-guard.sh via
# checks.monitor365-pool-copy-guard-selftest — the unattended window must
# never be this branch list's first execution.
set -euo pipefail

STATE="$(systemctl is-active monitor365-server-backup.service 2>/dev/null || true)"
case "$STATE" in
  active | activating | reloading)
    echo "monitor365-pool-copy-guard: backup unit still $STATE — refusing to copy mid-quiesce (no ordering edge; next fire catches up)" >&2
    exit 1
    ;;
  "")
    echo "monitor365-pool-copy-guard: could not read backup unit state (systemctl/bus failed) — refusing to copy blind" >&2
    exit 1
    ;;
esac
echo "monitor365-pool-copy-guard: backup unit is '$STATE' — clear to copy"
