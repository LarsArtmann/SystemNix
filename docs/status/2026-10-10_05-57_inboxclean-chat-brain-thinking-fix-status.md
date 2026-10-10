# Session status + brutal self-review: InboxClean chat FIXED (llama-chat thinking-mode root cause)

**Session window:** 2026-10-10 ~04:45–06:05 CEST · **Trigger:** user: "Why is InboxClean AI chat still broken!?"
**Deployed:** generation 856, `/run/current-system` anchored (reboot-safe) · **llama-chat:** green with the fix · **Report format:** `.md` at user-demanded path (skill default is HTML; user instruction wins — one-off override, NOT a new default)

---

## The one-paragraph verdict

The InboxClean chat had NEVER worked — 4/4 agent turns since the llama-chat brain landed died, 0 tool calls ever executed. Root cause was NOT llama-chat being down (it was healthy) and NOT purely the IO storm: the Qwen3.6 template's **thinking mode defaults ON** under `--jinja`, so every OpenAI call opened a `<think>` block before any content; at ~25 tok/s CPU against a 4.9k-token plan prompt, no turn could converge inside InboxClean's hard 3-minute `chatTurnTimeout` — every one died `context deadline exceeded`. Fixed server-side (`--chat-template-kwargs '{"enable_thinking":false}'`), deployed after one self-inflicted quoting failure, proven with a consumer-equivalent probe: 27.1 s, `finish_reason=stop`, 72 tokens, valid plan JSON, zero reasoning. Residual: the SDK's plan-approval gate means the first UI reply is "approve this plan?" — an owner decision, queued.

---

## a) FULLY DONE

| # | Item | Evidence |
| - | ---- | -------- |
| a1 | **Root cause chain, fully diagnosed** — llama-server healthy (200 /health, correct alias, ~25 t/s) → turns canceled at exactly 180 s → `chat.go:39` 3-min budget → agent-sdk `executionplan/generator.go:48` plain `Generate` (no max_tokens, no JSON mode) over the full tool catalog → probe: trivial plan request burned 600/600 max_tokens on reasoning ALONE (content EMPTY, `finish_reason=length`) in 59 s | journal (02:35 + 04:54 turn pairs), `/mnt/buildcache/.../agent-sdk-go@v0.2.75` source, live probes |
| a2 | **Fix landed + deployed** — `--chat-template-kwargs '{"enable_thinking":false}'` in `modules/nixos/services/llama-chat.nix:88-92` (server-side, so consumers that send no template kwargs — InboxClean — get it); gen 856 active + anchored | unit argv via pgrep (single clean arg), `readlink` anchor match |
| a3 | **Fix proven with the consumer's exact request shape** (no kwargs, no max_tokens): 27.1 s, `stop`, 72 completion tokens, valid plan JSON, `reasoning_content` empty | post-deploy probe output |
| a4 | **systemd ExecStart quoting trap diagnosed, fixed, documented** — bare `"` in an ExecStart arg is word-split by the unit parser (llama-server received `{e`, exit 1); single-quoted render is the rule; lesson added to `docs/agents/systemd.md` ("Bare `"` inside an ExecStart arg…") + module comment | journal `json.exception.parse_error.101`, deploy #1 failure log |
| a5 | **Runbook updated** — `docs/services/llama-chat.md` "Thinking OFF" bullet with probe evidence + all-four-turns-dead history | file |
| a6 | **Version drift fixed in the surfaces I touched** — runbook + module header said llama.cpp 0.5.0; live binary is 0.6.0 | both files corrected |
| a7 | **Deploy pressure-gate abort decoded per runbook protocol** — gate fired "corpse-pile on a dead automount"; probes showed ALL devices idle (sdb 1% busy, in_flight drains to 0), pool + buildcache automounts respond, writers = sibling sessions (`nix flake check` 153% CPU 3m42s, fresh `go test ./...`, `cargo test`/`rustc`) → the documented parallel-build phantom class, NOT hardware → sanctioned `DEPLOY_FORCE_PRESSURE=1` | 5 s per-device `/sys/block/*/stat` deltas, automount probes, ps |
| a8 | **Daemon-race discipline held** — daemon swept my edits into `a50b0f94` + `5601e271`; contents verified (exactly my 2 files, nothing foreign); no amend attempted after foreign commits landed on top; skipped lint re-run scoped to my 3 files via treefmt → **0 changed** (legs had NOT skipped) | `git show --stat`, treefmt output |
| a9 | **Follow-up queued at authoring time** — `[decision]` row for the SDK plan-approval gate in `docs/todo/upstream.md` | file |

## b) PARTIALLY DONE

| # | Item | What's missing |
| - | ---- | -------------- |
| b1 | **Chat works at the API layer; the UI experience is UNVERIFIED** | no real browser turn (agent can't drive the UI); the first reply will be a plan-approval prompt, which the user may still perceive as "broken" until the §g-1 decision lands |
| b2 | **InboxClean app-level health** — `/health` still 503 at its 8 s handler budget; dashboard queries 3–5 s with `context canceled` WARNs | this is the sibling-storm/PSI class (documented 2026-10-06 + 03:47 report); it drains with the sibling builds — I left it standing rather than chase it (out of session scope) |
| b3 | **Deploy verification is INCOMPLETE** — both 2026-10-10 deploys' post-deploy smoke aborted at line 187 (`service-sanity-sweep.sh` missing from the post-deploy-check derivation), so the InboxClean/CV/catchall legs never ran; activation + anchor + my own probes substitute | queued to `docs/todo/pipeline.md` this session; smoke re-run pending the packaging fix |

## c) NOT STARTED (observed this session, deliberately not done — "report only" scope)

1. **03:47-report runbook row still open** — `docs/services/inboxclean.md` still describes the 3 s /health incident without the 8 s-budget + STORM-SUSPECT end-state (pre-existing §f-2 of `2026-10-10_03-47`; I added the Thinking bullet to llama-chat.md, NOT this).
2. **Real end-to-end UI chat turn** — needs the user (or a browser harness).
3. **Gatus "llama.cpp Chat" explicit green confirm** — my direct probe is 200, which the check consumes; I did not open Gatus itself.
4. **Eval-time lint for bare quotes in ExecStart args** — lesson documented only (docs/agents/systemd.md); an eval throw + negative-test would make it a layer.
5. **Standing DEPLOY_FORCE_PRESSURE policy** — I made a one-off evidence-based override; no owner rule exists.
6. **Post-deploy smoke re-run** — blocked on b3's packaging fix.

## d) TOTALLY FUCKED UP (my own failures — brutally honest)

1. **I deployed an UNVALIDATED ExecStart arg.** I verified the flag against `llama-server --help` and via a request-level probe, but never checked the RENDERED unit line before deploy #1 — the one `nix eval …ExecStart` that exposes the quoting ran only AFTER the failure. Cost: a failed-unit window (~25 min of llama-chat down instead of ~4 min reload), llama-chat-ensure failing in its wake, an activation exit-4, and a second deploy cycle under PSI pressure. Entirely avoidable.
2. **Misdiagnosed my own tooling failure.** First eval failed `flake/parts/pkgs.nix: No such file or directory`; I suspected the documented tracked-files trap — the actual cause was my `head -10` truncating `git ls-files` (pkgs.nix sorts AFTER packages.nix). I re-ran the eval instead of reading my own command output properly; one wasted eval cycle under storm load.
3. **Edit raced the daemon and bounced** ("file modified since read") — I knew the discipline (re-read first, content-pin before write) and applied it only after the failure.
4. **I added load to a PSI-stalled box**: two model probes (600- + 300-token generations) plus two full toplevel evals plus two deploy builds ran mid-storm. Each was individually justified; cumulatively I was part of the storm I was decoding.
5. **The 29 s "no-thinking" probe reading was sloppy** — I initially didn't notice that 29 s for 99 prompt tokens meant queue-behind-something; the decisive evidence (finish=stop vs length, 80 vs 600 tokens) was right, but my elapsed-time reasoning in-flight was loose.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-deploy ExecStart argv validation** — eval-time lint: any rendered Exec* arg containing a bare `"` outside single-quote spans throws (negative-test into `scripts/negative-test-lints.sh`). Would have caught d1.
2. **Give deploy.sh's pressure gate the memory-guard's phantom filter** — PSI-high + per-disk `io_ticks` corroboration (idle disks ⇒ phantom verdict, WARN not abort). Today's abort was a false positive for the build-load class; the decode cost ~15 min.
3. **Cross-session storm etiquette needs a POLICY, not per-incident decoding** — third sibling-build PSI storm in 4 days (10-06 go test/ar, 10-08, today flake-check+go test+cargo). Options: a session-start gate (no heavy builds when io PSI avg60 > X), or buildflow queueing. Owner call.
4. **Fix the post-deploy smoke packaging** (b3, queued) — a deploy without its smoke legs is an unverified deploy.
5. **InboxClean turn observability** — "turns attempted vs succeeded vs tool-calls-executed" as a metric; journal forensics should not be required to see "0/4 ever worked".
6. **agent-sdk hardening** — max_tokens bound on Generate (a future thinking-enabled brain would fail FAST instead of burning 3 min) + the plan-approval decision (§g-1).
7. **Model-probe hygiene**: schedule multi-minute 12-thread probes for calm windows; use `max_tokens`-capped probes during storms.

## f) Up to 50 next things (session-scoped; harvest status marked)

Direct follow-ups already QUEUED this session: plan-approval decision (upstream.md), smoke packaging bug (pipeline.md), catalog-subdomains eval warning (services.md). The rest: 1–3, 5, 9, 12 are actionable next; 6–8, 10–11 need the owner; 13+ are pre-existing rows surfaced by this session.

1. **Owner decides: plan-approval vs direct execution** for /chat (queued, upstream.md).
2. **Verify one REAL UI chat turn** end-to-end (user; the SSE/agent last mile is unprobed).
3. **Fix post-deploy-check packaging** (`service-sanity-sweep.sh`), then re-run the full smoke to cover the skipped legs (queued, pipeline.md).
4. **Eval-lint: bare-quoted ExecStart args** + negative test (from d1; docs/agents/systemd.md holds the lesson).
5. **InboxClean /health re-probe once the sibling storm drains** — confirm the 503 class clears without app action.
6. **Owner rules on DEPLOY_FORCE_PRESSURE standing policy** for decoded-phantom windows.
7. **Owner rules on cross-session build etiquette** (e-3).
8. **Owner confirms thinking-off quality tradeoff** for ALL llama-chat consumers (§g-2).
9. **Gatus "llama.cpp Chat" green confirm** (post-reload state).
10. **max_tokens bound in agent-sdk Generate calls** (rides #1).
11. **Turn-attempt/success metric in inboxclean** (e-5; upstream).
12. **03:47 report's runbook row**: inboxclean.md /health 8 s end-state (pre-existing, still open).
13. **Cloud Console OAuth app "In production" confirm** — the 7-day-consent bomb since 10-04 (pre-existing [blocked:user] row; reminder).
14. **`sudo systemctl restart inboxclean-web`** row — re-verify premise first: deployed rev is now 171de0d (newer than the row's 01d2c5e), the lazy-reconnect fix may already be live (pre-existing).
15. **gmail-verdict-cache regression test** (pre-existing [ready], upstream).
16. **templ CLI ≥ go.mod pin** (pre-existing [ready], upstream).
17. **Dead-grant honesty chain push** (pre-existing [blocked:push]).
18. **Catalog subdomains eval warning** (queued, services.md).
19. **`nix flake check` transient-race class** — my "pkgs.nix not found" eval failure under parallel sessions; worth a known-issue note in nix-flakes.md if it recurs (watch).

(Stopped at 19 deliberately: the remaining ~31 would be padding — §f's tail is brainstorm-fuel and the open InboxClean backlog already lives in docs/todo/{upstream,services}.md; this report adds no invented items.)

## g) Questions I can NOT figure out myself

1. **Plan-approval UX:** keep the SDK's "I've created an execution plan — do you approve?" flow (current default), or switch /chat to direct execution (`WithRequirePlanApproval(false)`-style) with the system prompt's confirm-before-destructive protocol as the only gate? This decides whether chat "feels fixed" to you.
2. **Thinking-off quality tradeoff:** disabling thinking server-side fixes latency but reduces reasoning depth for ALL llama-chat consumers. Accept for now, or do you want complex asks routed differently (e.g. a thinking-on second model/alias) once the CPU budget allows?
3. **Storm-window deploys:** when the pressure gate aborts and a decode shows the phantom/build-load class (idle disks, healthy automounts), should `DEPLOY_FORCE_PRESSURE=1` be the STANDING rule for agent deploys, or must every forced deploy wait for owner approval?

---

*Daemon note: report left uncommitted per harness rule (no explicit "commit"); auto-commit daemon will sweep it. Per the TODO System, this report's §f direct follow-ups were self-harvested at authoring time (rows 1, 3, 18 landed in their domain libraries before this file was written).*
