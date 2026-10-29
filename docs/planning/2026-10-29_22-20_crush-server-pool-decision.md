# Decision needed — tq-agent-pool execution model: per-task `crush -y` processes vs persistent `crush server`

**Authored:** 2026-10-29 22:2x CET — executor session of the crush-0990 plan (T17 spike)
**Status:** DRAFT — awaiting owner sign-off. Until then the pool keeps per-task processes (the verschlimmbessern guard: no architecture change without an explicit decision).

## The question

The tq-agent-pool dispatches `[ready]` TODO rows by spawning a fresh `crush -y`
(headless one-shot) per task. crush v0.99.0's `crush server` (NOT `serve` —
source-verified at the tag) makes a persistent alternative possible: a
long-lived process hosting workspaces/sessions over HTTP with SIGHUP config
reload. Should the pool switch?

## What v0.99.0 `crush server` actually provides (source: internal/cmd/server.go, internal/server/server.go, internal/backend/*)

- **HTTP over a Unix socket** by default (`unix://$XDG_RUNTIME_DIR/crush-<uid>.sock`); `http://`/`tcp://` optional. OpenAPI at `/v1/docs/openapi.json`.
- **One process ≠ one conversation**: sessions run multiple sequential turns; multiple sessions per process (multiclient tests at the tag).
- **SIGHUP = config reload** (30s budget) for the server AND every hosted workspace; a workspace whose reload fails keeps its old config (no crash).
- **Graceful shutdown**: 15s detached budget, workspaces torn down first, active HTTP connections not interrupted; idle-shutdown when the last workspace detaches.
- **`CRUSH_PERMISSIONS_PIPED=1`**: the in-process prompt is suppressed because an external client owns permission answering — the hook for a pool-side permission policy surface.

## Option A — keep per-task processes (status quo)

**Pros:** total task isolation (a leaked FD/hung model call dies with the
task); crash blast radius = one task; the 2026-10-27 180m task-timeout wall
enforces cleanly (kill the process); zero new operational surface; the pool
already works (round-9 dogfood + nightly batches).

**Cons:** every task pays crush startup (~1–2 s, irrelevant vs task length)
and cold provider/model discovery; hooks/state reload per task; no
cross-task session continuity (by design).

## Option B — persistent `crush server` per pool worker

**Pros:** one config load per worker (SIGHUP reload on crush-config float
WITHOUT restarting mid-task); hooks (redaction, trap remediation, the new
audit/StopFailure logging) load once and stay hot; `CRUSH_PERMISSIONS_PIPED`
enables a future pool-side permission policy UI (the crush-debug host-UI
roadmap item); sessions addressable over HTTP = the pool could inspect/steer
running tasks (today: blind).

**Cons:** a wedged server wedges EVERY task on that worker (the #4143
tool-failure fix does not cover a dead transport); task isolation weakens
(env/state bleed between sessions in one process); the 180m task wall needs
a NEW enforcement mechanism (HTTP-level cancel or server-side session
kill — unverified); one more always-on service to monitor (gatus +
memory ceiling); the socket path security model on a multi-user box needs
review (Unix socket + uid is fine single-user, but the pool runs as a
service user while sessions act on $HOME repos).

## Recommendation

**Stay on Option A; park B behind a trigger.** The pool's problems
(2026-10-07/10-25 freeze autopsies: IO churn; the dead-letter classes:
timeouts, gate artifacts) are NOT process-spawn costs — a persistent server
solves none of them and adds a wedge-class failure mode the current
architecture cannot have. Revisit ONLY if: (a) hook/rc reload latency ever
matters at pool cadence, (b) a pool-side permission UI becomes a real ask,
or (c) task steering/inspection over HTTP becomes operationally necessary.
The SIGHUP-reload primitive is the one piece worth keeping warm: it is also
the mechanism a future `crush server` adopter would use to ride crush-config
floats without session interruption.

## If the owner picks B anyway (prerequisites, non-negotiable)

1. Per-worker server (not one global) — wedge radius = one worker's queue slot.
2. Session-kill semantics verified against the 180m wall (HTTP cancel or
   supervisor kill of the session, proven in a VM test).
3. MemoryHigh/MemoryMax on the server unit (the freeze doctrine) + gatus
   liveness on the socket.
4. Socket under /run with 0700 dir perms; pool user owns it.
