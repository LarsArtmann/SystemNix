# Window Closeout — Five Queue Runs: Hermes Smoke, Browser-History Gate Verify, Import-Gate Upstream Fix, Paperless E2E Blocked, Gate-Review Fix

**Date:** 2026-09-19 01:38 CEST
**Window:** 2026-09-18 03:13 → 2026-09-19 00:59 CEST (five completed queue tasks; a sixth sibling task `000001a0b68a0aee7ce7935b8d6914878bd6` finished inside the window but was NOT part of it — its OAuth2-qualification work is reported in passing where it touched this window's artifacts)
**Format note:** the status-report skill's canonical format is styled HTML; the harness explicitly requested `.md`. Honoring the user instruction; one-off override, not propagated into the skill.
**Scope guard:** this report covers ONLY this window's tasks and what was noticed in passing. Every claim below was re-verified against commits (`git show`) and the tree during this closeout; the closeout's own doc edits (FEATURES/CHANGELOG/AGENTS/TODO_LIST) are itemized in §docs-health.

---

## a) FULLY DONE

1. **Hermes Discord-connectivity smoke (task `000001a0b2069a1df77e4c62aef8b0488125`, work `7dba37d0` + daemon-swept `9d9cfc5a`, report `9e3becb7`)** — root cause found by SOURCE verification, not guessing: hermes stderr logging defaults to WARNING+ (`gateway/run.py:34038`), so the INFO-level `[Discord] Connected as` on_ready line (`plugins/platforms/discord/adapter.py:1450`) never reached journald at all — the 08-21 "journal-quiet buffering" theory was wrong. Two-part fix landed: `modules/nixos/services/hermes.nix` ExecStart now runs `gateway run --replace -v` (flag surface verified against `hermes_cli/subcommands/gateway.py`), and `scripts/post-deploy-check.sh`'s hermes block gained a boot-scoped `journalctl --grep "\[Discord\] Connected as"` assertion (journalctl-native grep, no SIGPIPE trap). Verified: `bash -n` clean, `nix flake check --no-build` green, journal-grep predicate hand-probed live. TODO item closed `[x]` (TODO_LIST line 39). CHANGELOG already carried the entry.
2. **Browser-history registration-gate live verification (task `000001a0b21d7d821da36f61711e46394735`, close `e033d4d4`, report `7c07de71`)** — the QUESTION "is the gate closed live?" was answered, though the answer is the finding in §d/below: gate CODE proven live at three levels (deployed `browser-history-server-0971fe9` + `go version -m` replace-chain audit; scratch-run of the exact store binary on a fresh DB with `MAX_USERS=1` → user1 201 → user2 403; upstream provenance via `git merge-base --is-ancestor e5cdc925 eb356ed2`). Prod probe (CSRF double-submit dance) returned 201 ONCE then 403 `[rejection:usermgmt.registration_closed]` forever after — that first-201 is the count-gap FINDING (see d1), not a pass. Probe-user debris created deliberately and named (`probe-gate@example.com`, `probe-` prefix); cleanup backlogged root-only (TODO line 42).
3. **`importUsers()` registration-lock hole #3 gated UPSTREAM (task `000001a0b2421c771642abfbde5442abc951`, SystemNix `9ce11b41` + `ae32c7dc`, reports `04-32`/`04-47`)** — cqrs-htmx master `68a2cd68` gates the batch import behind MaxUsers + holds `registrationMu` for the whole batch (TOCTOU-safe, same mutex as Register/OAuth2), skipping over-cap users with `"registration is closed"`; regression test `TestImportUsers_RespectsMaxUsers` present. Verified with real gates, not output text: `go build` clean + full `usermgmt` suite green (`ok … 16.891s`). SystemNix doc loop closed: TODO item `[x]` with the propagation chain appended (line 44), and the stale AGENTS.md browser-history bullet ("importUsers() CSV path is NOT yet gated") corrected to cite `68a2cd68` — re-verified accurate in the current tree during this closeout.
4. **Paperless-AI ↔ llama-rag E2E item triaged honestly instead of executed against a dead premise (task `000001a0b68a0a38da1c4a597637e0401f85`, close `dd688ef4`, report `bbcb38f8`)** — the item's premise ("llama-rag is re-enabled and ACTIVE") was FALSIFIED: the freeze-5 escape condition had re-disabled the module hours after the item was written. Verified live: `configuration.nix:626` disable, no `llama-embeddings`/`llama-reranker` units in the deployed generation, :8848/:8849 refuse connections, Gatus checks + homepage tile correctly enable-gated (no permanent reds), generation anchoring clean (system-785). The paperless HALF of the item was verified to the deployed surface: all four paperless units active, and `/etc/systemd/system/paperless-web.service` carries `PAPERLESS_AI_ENABLED=true` + the `:8848/v1` embedding wiring + `bge-m3` — upgrading the "env wiring confirmed" claim from source-inference to deployed-generation fact. Item left `[ ]` with an accurate BLOCKED annotation (the correct disposition).
5. **Review finding on the gate close-out fixed EXACTLY as filed (task `000001a0b68a0a7d3cf616a18addd70234ff`, fix `0e65881f`, report `1933a4f2`)** — both contradictory headline sites corrected (TODO_LIST line 40 + the 03-56 report's Outcome line, inline-annotated per docs-health ANNOTATE), claim-class sweep confirmed no third site (the FEATURES hit was unrelated and has now been handled in this closeout's docs pass — see §docs-health), pathspec commit with hooks green, exactly one Task-Queue-ID footer.
6. **TODO_LIST line 37 (hermes-python-source orphan) closed THIS session with fresh evidence** — the 6th sibling task had verified `nix path-info` rc=0 and two green hook runs but left the item for scope reasons; this closeout added the third data point (`nix flake check --no-build` → "all checks passed!" rc=0) and ticked the row. Docs-only commits no longer need `--no-verify` on this account.
7. **Window commits verified footer-clean** — all five tasks' commits carry exactly one `Task-Queue-ID` footer each (checked via `git show` trailers); two changes (the smoke-script edit `9d9cfc5a`, and the 6th task's `aeb5bba2`) were first swept into footer-less daemon commits and recovered by the documented verify-then-amend discipline.

## b) PARTIALLY DONE

1. **Hermes `-v` + smoke: in-tree, DEPLOY REQUIRED.** Until `nix run .#deploy`, the new smoke assertion FAILS red on hermes-enabled hosts (a loud true-positive: the deployed unit emits no connectivity signal). Both changes ride the same deploy so the red window is ~zero — unless the script is cherry-picked alone. Positive live proof of the `Connected as` line is still pending the deploy restart.
2. **Import-gate fix: upstream-local, NOT pushed, NOT consumed.** `68a2cd68` is not an ancestor of cqrs-htmx `origin/master` (verified in the 04-47 report) — agent sessions never push. The full chain (push → tag v4 sub-modules → browser-history go.mod → goModules FOD probe → SystemNix input bump → live import-over-cap rejection) is queued as TODO line 44 and is the 80% of the remaining work. **The deployed browser-history still carries hole #3.**
3. **Paperless E2E: the live-call half is blocked, by design.** Remaining: an embedding request actually completing against a serving :8848, the `paperless_appconfig` DB-vs-env effective check (sudo-gated), and journal corroboration. Effort S once the llama-rag bisect gate (§f1) passes. The reranker wiring clause is correctly MOOT (paperless 3.1.3 has zero reranker support, source-verified).
4. **OAuth2-first-login live rejection: still unverified** — code-level inference only (shared `registrationMu` + count check). The sibling task converted this into an explicit UNVERIFIED qualification in the close-out + a new P2 user-run passkey-ceremony item (TODO line 73). Correct, but the measurement itself remains open.
5. **The gate's effective close: open by exactly one slot.** Gate code live, but until the upstream count-gap fix lands and propagates, every read-model rebuild admits ONE ghost registration. Two bypass classes on one invariant (count-gap TODO line 43 + import chain line 44), both queued, neither landed.

## c) NOT STARTED (window skipped; already tracked or now tracked)

1. **The llama.cpp mid-load spin bisect** (ROCm runtime/kernel/GPU-state, upstream of llama.cpp) — the gate for EVERYTHING llama-rag (re-enable, paperless RAG, the reranker question). Documented in AGENTS doctrine but carried by NO TODO item — this closeout appended it (see §f/TODO appends). Highest-value miss of the window.
2. Probe-user deletion (line 42), count-gap upstream fix (line 43), import-gate propagation chain (line 44) — the security trio behind this window's verification work; untouched (correctly queued).
3. All standing fleet work the window did not touch: the owed reboot (flm :52626 corpse, D-state pile), crush-hot-db first migration + verification sweep, Resend SPF/domain verification, InboxClean `main` re-consent, Monitor365/Turso/groq owner decisions, offsite Borg leg, /data corruption repair, hetzner+borg, hotspot of P0/P1 rows — unchanged.

## d) TOTALLY FUCKED UP

1. **The window's worst artifact was its own close-out.** The 03-56 gate-verification report wrote "gate verified live … NO chain work needed" two paragraphs above its own evidence of a 201 — the deployed gate ACCEPTED one unauthorized registration in prod during the probe, and the headline asserted the opposite of the item's actual question. A reviewer had to catch it; the count-gap was already IN the report's §e.2, framed as a hypothetical future risk instead of an active, already-exploited bypass. Root failure mode: pattern-matching the expected outcome instead of reading the prod result against the question asked (binary-gates evidence ≠ system-closed evidence; the count-gap is the variable that separates them). Fixed by the review-fix task; the lesson is now a repo Critical Rule (AGENTS.md, this closeout).
2. **A real user was created on prod with no pre-planned cleanup path.** The verification probe mutated live state before scouting the rollback (`/var/lib/browser-history/data.db` is 0700 DynamicUser-owned; root-only SQL, plus the journal-event subtlety that a bare read-model delete resurrects on rebuild). `probe-gate@example.com` still sits in prod. Discipline gap, not data loss — but "destructive-verification needs a rehearsed undo FIRST" is the same class as the existing "never force-enable to verify" rule.
3. **Queue premise rot nearly caused a repeat freeze.** The paperless E2E item was dispatched asserting "llama-rag is re-enabled and ACTIVE … expect ~4s load" hours after freeze #5 falsified both claims; a less disciplined session would have re-enabled and deployed INTO the spin class. One AGENTS.md grep at intake would have caught it. Process fix appended to the backlog (queue intake freshness rule).
4. **The pre-commit flake leg was red repo-wide for ~a day** (`path … hermes-python-source is not valid`) — every explicit commit needed `--no-verify`, which also skips gitleaks. Self-healed by 2026-09-19 (verified three independent ways this closeout; TODO line 37 ticked), but the failure mode (cryptic message, repo-wide blast radius, normalized hook-bypassing) remains unclassified in pre-commit — backlog item appended.
5. **Daemon-race losses keep recurring** (3+ in this window across sessions: `9d9cfc5a` swept the smoke script, `aeb5bba2` and `1207797f`/`17752b4a` swept TODO edits) — every one recovered by verify-then-amend, each one gamble away from sweeping foreign files into a footer commit. Systemic; already tracked (TODO rows on daemon-footer hygiene), no new item needed.
6. **Paperless RAG is silently dark** (by design, near-invisibly): `PAPERLESS_AI_LLM_EMBEDDING_*` points at dead :8848 and paperless-ai's graceful degradation is the phantom-green kind — nothing outside paperless logs says "RAG disabled". Backlog item appended (degradation visibility).

## e) WHAT WE SHOULD IMPROVE

1. **Close-out headline rule (now a repo Critical Rule):** a DONE line states the outcome OF THE THING THE ITEM ASKED, with the probe-transcript line that proves it; a live probe's contradiction of the expected invariant IS the verdict. Security findings get worded at observed strength ("happened", never "can").
2. **Destructive-verification protocol:** any probe that writes to a live state store gets its undo rehearsed before the first write (admin-API or journal-safe delete path, verified reachable from the agent sandbox or explicitly marked user-run).
3. **Queue intake hygiene:** live-state premises get a mandatory AGENTS.md reconciliation step at session start; root-gated work is tagged at enqueue (extends the existing HUMAN-tag and privilege-marker rows) so BLOCKED is the planned outcome, not a discovered one.
4. **Premise-staleness is contagious through harvests:** this window's blocked item existed because a harvest carried a stale "re-enabled and ACTIVE" note forward; the verify-before-harvest rule (already tracked) needs teeth for live-state claims specifically.
5. **Feature-adjacent doc loops:** the import-gate task fixed AGENTS.md on sight (good), but FEATURES.md's two stale rows survived until this closeout's docs pass — the "NOT yet gated / verify the gate" claim class should be grepped against upstream git history during docs passes (cheap, catches the drift class).
6. **Commit immediately after edit; build the footer commit atomically** (message pre-built, pathspec-scoped, single chained command) — the daemon race is deterministic when sessions dawdle.
7. **What went well and should stay:** source-verification before guessing (hermes log level), deployed-surface probing over source claims (unit-file grep for paperless env), honest BLOCKED disposition over forcing execution against a dead premise, and the review loop catching a headline its own evidence refuted — the queue worked exactly as designed on the two hardest tasks.

## f) UP TO 50 NEXT THINGS (most valuable first; 10 + 3 questions appended to TODO_LIST, the rest are ROADMAP/queue fuel)

**Appended to TODO_LIST this closeout (dedup-checked against all 445 open rows):**
1. Bisect the llama.cpp 0.3.0 spin upstream + the ≥10-min REAL-unit soak acceptance gate — THE llama-rag re-enable gate (unblocks paperless RAG; freeze-5's root driver).
2. Post-deploy smoke for the registration gate using the CSRF double-submit dance (403-closed vs csrf-wall distinguishable).
3. Gatus check: `browser_history_user_count` decrease/exceed-baseline alert (count-gap exploitation detector).
4. Post-deploy hermes `-v` verification bundle: `Connected as` positive proof + one-day journal-volume measurement with revert path + version-dependency note in the smoke's fail message.
5. Paperless RAG degradation visibility ("expects embeddings, :8848 dark") metric/Gatus signal.
6. Pre-commit: classify `path ... is not valid` as loud WARN + repair hint (end the orphan-class `--no-verify` habit).
7. CONTRIBUTING convention: boot-scoped vs window-scoped journal assertions.
8. Rogue-listener defense for :8848/:8849 while llama-rag is disabled (the 2026-09-18 orphan class can phantom-pass smokes).
9. Registration-surface audit: `/auth/import` unauthenticated-unreachable on the deployed path + sibling user-creation-path sweep in cqrs-htmx (close the unknown-third-bypass-class question).
10. Queue intake freshness rule: live-state claims reconcile against the relevant AGENTS.md section before execution.
11–13. (Blocked questions, also appended): Caddy fence on `/auth/register` as interim mitigation? Gate acceptance re-run timing (post-fix vs post-cleanup reprobe)? Hermes global `-v` permanent posture vs upstream adapter-scoped/env-var ask?

**Queue-ready items from the window's own reports, already tracked (do NOT re-dispatch, pointers only):** push+tag+bump the `68a2cd68` chain (line 44); count-gap fix (43); probe-user deletion (42); OAuth2 live passkey ceremony (73, P2); CSRF-recipe documentation (03-56 §f.7); post-deploy llama-rag verification chain (650); reranker side drop-or-track decision (653); `nixpkgs-llama-rag` pin expiry probe (652).

**Additional candidates not appended (cap reached; ROADMAP/backlog fuel):**
14. VM test asserting hermes ExecStart carries `-v` + a mocked Discord-ready journal line through the smoke predicate.
15. Negative-side smoke assertion: FAIL on a `Failed to connect to Discord` WARNING this boot (presence-of-success AND absence-of-failure).
16. hermes upstream: log the Discord connect line at WARNING (or a metric) so default-verbosity installs keep a positive signal; env-var log level.
17. One-day hermes INFO journal-volume measurement is folded into item 4; the deeper follow-up is adapter-scoped logging upstream.
18. cqrs-htmx: dedicated regression test pinning import-under-cap counts (import 3 at MaxUsers=2 → exactly 2 imported); full `go test ./...` before tagging.
19. Check whether any OTHER cqrs-htmx consumer exposes import endpoints (grep LarsArtmann repos).
20. HTTP-layer admin gate on the import endpoint (defense in depth) — owner question embedded in TODO line 44's review.
21. Registration-rejection audit-log event (evidence source PapDashboard could ingest — today a bypass attempt is HTTP-response-only).
22. Sweep `docs/status/archived/` for the headline-vs-evidence close-out pattern ("verified live|DONE" adjacent to contradicting probe results) — the 03-56 class may have siblings.
23. Store-orphan mechanism investigation + fleet sweep for other present-but-unregistered store paths (the hermes-python-source class will recur after every freeze).
24. CSRF double-submit recipe documented in docs/services as THE probe pattern for authenticated-adjacent endpoints.
25. VM test for the CSRF-then-gate layering; `browser_history_user_count` onto a SigNoz dashboard.
26. Periodic (non-deploy-time) journal-freshness check for the hermes `Connected as` line between deploys — owner decision (grace window for flapping gateways).
27. Confirm the `Slash command sync timed out` WARNING is the known benign 429 pattern at INFO visibility; file upstream for backoff if chronic.
28. Re-check the browser-history upstream hold (`f3561fd8` SQLITE_READONLY) so the eventual bump picks a rev with BOTH the gate fixes AND a working server (interacts with TODO line 44).
29. Count-gap + import holes filed to the cqrs-htmx issue tracker with the 2026-09-18 live evidence (verify-before-filing first).
30. Paperless-side journal evidence of embedding attempts (quiet window; corroboration only — the DB check subsumes it).
31. Verify `llama-rag-leak-metrics` collector is enable-gated like the checks/tiles (no orphan collector while disabled).
32. Confirm post-deploy-check's llama smoke auto-skips gracefully with the module disabled.
33. §10 metric-loan sweep for llama-era stale entries after the disable.
34. Capture which paperless source consumes `PAPERLESS_AI_*` (fork vs nixpkgs 3.1.1) to write the exact `paperless_appconfig` DB-check query.
35. hermes workspace-doc/monitoring runbook parity: `docs/services/hermes.md` monitoring section gains the new journal assertion (out of this closeout's edit scope; one line).
36. Gatus candidates from the 03-56 report left unqueued by design: boot-scoped-vs-window convention (item 7), user-count dashboard (25), gate-verification runbook page (24/25).
37. Daemon-footer hygiene (PMA upstream): skip index entries staged by an explicit session, or inherit the stager's footer — two more footer-less sweeps this window.
38. The sibling task's leftover: tighten the P2 OAuth2 item's bypass-branch wording (its "delete immediately" branch over-promises the P1 SQL replays for an OAuth2-provisioned user — it does not; re-derive cleanup instead).
39. Annotate-on-review-fix doctrine: when a close-out is reworded by review, sweep the parent report for cross-references to the old wording (this closeout did it for §a.4; generalize).
40–50: standing fleet backlog unchanged (owed reboot + pre-reboot-check, crush-hot-db first run + sweep + PSI baseline, Resend SPF replace + non-owner delivery probe, InboxClean re-consent, offsite Borg leg, /data repair T04-T08, sigNoz trace-gap instrumentation per repo, Miniflux SSO flip gate, monitor365/Turso/groq/MiniMax decisions, flm v1.0.3 staged go-live, `@nix` dead-subvol deletion post-reboot, clickhouse-backup decision, SigNoz zombie-table DROP decision) — all carried by existing TODO rows; re-listing them here would only mint dedup hazards.

## g) UP TO 3 QUESTIONS ONLY THE OWNER CAN DECIDE (appended to TODO_LIST as BLOCKED items)

1. **Caddy fence on `/auth/register` as an interim mitigation** until the count-gap fix + import propagation land: is the LAN trust model acceptable for a single-slot bypass, or do we fence (loopback/LAN-only) now at the cost of the agent's own probes needing a localhost exemption?
2. **Gate acceptance re-run timing:** wait for the upstream count-gap fix (first-probe-403 then proves "closed"), or delete the probe user first and re-probe — knowing the first probe may 201 AGAIN (another prod mutation, another debris user) and a clean "closed" verdict may be structurally impossible pre-fix?
3. **Hermes logging posture:** is global `-v` (INFO for the whole gateway, deploy-pending) the permanent stance, or does this become an upstream request for adapter-scoped logging / a `HERMES_LOG_STDERR_LEVEL`-style env var so systemd units can raise verbosity without ExecStart edits?

## h) BAND DRIFT (ADR-0015 accountability)

**None recorded.** `tq facts --type task.reprioritized` returns 0 facts and a full-journal grep for "repriorit" finds nothing — no priority moves were journaled for this window (or at all). The window's execution order (smoke → gate verify → import fix → paperless E2E → review fix) matches the queue's dispatch order with no re-banding to explain. For the record: the two review-driven tasks (the fix task and the sibling qualification task) were NEW dispatches spawned by reviewer findings, not re-prioritizations of existing items.

---

## docs-health pass (what this closeout changed, and why)

- **FEATURES.md** — two stale Browser-History claims corrected against evidence: row 95's "Known gaps" (import path ungated → FIXED upstream `68a2cd68` pending chain; OAuth2 "not manually tested" → the precise code-level-only/live-pending state; count-gap added) and row 526's "verify the registration gate is live" (→ verified 2026-09-18 with the count-gap outcome stated at observed strength).
- **CHANGELOG.md** — [Unreleased]/Changed gained the window's one user-visible verification+security story (gate verified live; count-gap exposure; importUsers gated upstream; close-out corrected by review). The hermes `-v` entry already existed from the task itself.
- **AGENTS.md** — Critical Rules gained the close-out-verdict lesson (§e.1) with its evidence, per the review-fix report's own recommendation now that the class has an instance.
- **TODO_LIST.md** — line 37 ticked with three-source evidence (path-info rc=0, flake check green this session, two green hook runs in the sibling report); 13 items appended in a dated section (10 next-things + 3 blocked questions), every candidate dedup-checked against the 445 open rows (probe-user/count-gap/propagation/OAuth2-ceremony/CSRF-doc candidates already existed and were skipped, several as reword-risk).
- **Annotations** — the 03-56 report's §a.4 gained an inline CORRECTED note: its "documented as such in the TODO close-out" clause describes wording the sibling task's `8b07ecc9` reworded; point-in-time body left intact otherwise.
- **Archives** — none moved: every window report still carries open items (deploy-pending hermes, queued security chain, blocked paperless), and the older candidates remain referenced by open TODO rows. The standing archive-sweep TODO row continues to own the older backlog.
- **Out-of-scope sightings reported, not touched:** `docs/services/hermes.md` monitoring-table parity line (item 35); `docs/CONTRIBUTING.md` convention (item 7); no code, config, tests, locks, or scripts were modified by this closeout.

*Point-in-time snapshot, 2026-09-19 01:38 CEST. Task-Queue-ID cross-reference: this report's commit.*

**COMMIT MAPPING (daemon race, the 2026-09-17 closeout precedent):** the auto-commit daemon swept this closeout's doc edits before the footer-carrying commit could land — FEATURES/CHANGELOG/AGENTS = `5881225a`, TODO_LIST (tick + appends) + the 03-56 §a.4 annotation = `94e9d713` (both verified by `git show --stat` to contain EXACTLY this closeout's files, no foreign sweep); the footer-carrying commit carries this report + the final TODO_LIST report-pointer fix.
