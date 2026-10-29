> [!NOTE]
> This filing was drafted by GLM (glm-5.3) via Crush from an AI-run investigation, not at my request. When the failure traces to an external report, that source is linked in the body.
>
> - [ ] MANUALLY REVIEWED by `@Lars Artmann` at `[<date-time>]`

**TL;DR:** Hook results on lifecycle events are parsed and then thrown away — `context` injection only exists for tool events — so `SessionStart`/`PostCompact` hooks cannot feed anything back into the conversation. Asking for `context` to be honored on lifecycle events (or for the observe-only contract to be stated explicitly in the docs).

## Problem

The hooks-everywhere release (v0.99.0) added lifecycle events, but as shipped they are observe-only in a way the event names do not suggest: a hook's returned `{"context": "..."}` is read, parsed, and discarded for every non-tool event.

At v0.99.0:

| Event | `context` honored? | Where the result goes |
| --- | --- | --- |
| `PreToolUse` / `PostToolUse` / `PostToolUseFailure` | yes | `internal/agent/hooked_tool.go` joins `pre.Context`/`post.Context` into the tool response |
| `TurnStart` / `TurnEnd` / `Interrupt` / `StopFailure` | no | `fireTurnHook` (`internal/agent/turn_hooks.go`) calls `hooks.Run` and ignores the returned `AggregateResult` |
| `SessionStart` / `SessionEnd` | no | `internal/app/hooks.go` discards the result |
| `PreCompact` | only the deny decision | `Blocked()` is honored; `context` is ignored |
| `PostCompact` | no | `internal/agent/agent.go` fires the event and ignores the result |

(`updated_output` is correctly gated to `PostToolUse` in `hooked_tool.go` — that one reads intentional.)

Two concrete losses on our side, both from multi-hour agent sessions:

1. **Compaction amnesia.** After `PostCompact` the model continues with a summary, but any "you are mid-task X, the failing probe is Y, re-read Z before acting" context a hook wants to re-inject has no path back into the conversation. The exact moment a session most needs orientation is the moment hooks are muted.
2. **Session-start state surfacing.** We run parallel agent sessions against shared working trees, and the highest-value hook we could write is a `SessionStart` hook that lists, say, recently-modified untracked files so sessions stop colliding. As shipped, that hook can log, but cannot tell the model anything.

## Goal

As a user running long agent sessions, I want to type:

```bash
hook add PostCompact --command "bash ./reorient.sh" --name reorient
```

and have the hook's `{"context": "..."}` reach the model the same way a `PreToolUse` hook's context does.

| | today (v0.99.0) | desired |
| --- | --- | --- |
| `context` on tool events | works | unchanged |
| `context` on `SessionStart` | parsed, discarded | injected into the first turn |
| `context` on `PostCompact` | parsed, discarded | injected after compaction |
| `updated_output` on non-`PostToolUse` | parsed, dropped | still dropped (fine — document it) |
| deny/`Blocked()` semantics | `PreCompact` only | unchanged |

If honoring `context` on lifecycle events is a deliberate scope decision, then the ask shrinks to: state the observe-only contract explicitly in `docs/hooks/README.md` per event, so hook authors do not discover it by wiring a hook that can never fire into the conversation.

## Notes

- `internal/hooks/events.go` doc comments already describe `context` support only for the three tool events — the code and those comments agree; the gap is that nothing else tells an author the lifecycle events are write-only.
- Either threading selected lifecycle contexts into the conversation, or a dedicated `inject`/`orientation` result field with explicit event support, would serve; not prescribing the mechanism.

-crush v0.99.0, verified against the tag: `internal/hooks/events.go`, `internal/agent/hooked_tool.go`, `internal/agent/turn_hooks.go`, `internal/app/hooks.go`, `internal/agent/agent.go`.

💘 Generated with Crush

---

*(draft meta — not part of the filing body)*

**Status:** NOT filed — awaiting owner approval (plan T18.3).
**Proposed title:** `Hooks: honor "context" on lifecycle events (SessionStart, PostCompact) — currently parsed then discarded`
**Target:** charmbracelet/crush · **Source plan:** docs/planning/2026-10-29_18-42_SUPERB (T18) · claim source-verified at tag v0.99.0 (18.1 done).
**File with:** `gh issue create --repo charmbracelet/crush --title '<above>' --body-file <this-file>` (banner box stays unchecked until the owner ticks it).
