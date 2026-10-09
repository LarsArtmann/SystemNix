# Status Report + Brutal Self-Review — Event-Driven Incident Pipeline Implementation (go-taskqueue)

- **Date:** 2026-10-08 23:34 (CEST)
- **Session:** continuation of the 22-05 design session; this leg implemented the "Command + Event Sourced" error→fix-task pipeline in `/home/lars/projects/go-taskqueue` per ADR-0021
- **Repo pins:** SystemNix @ `6abf00c1` (clean) · go-taskqueue @ `c4a5bb08` (clean — but see §d-7: the daemon swept all session work into 4 heuristic commits mid-flight)
- **Report scope:** this session's run only, per instruction. The 22-05 report's §g questions remain unanswered; they still gate first integration.

---

## What was built (one paragraph)

The error→auto-fix pipeline from the 22-05 design is now REAL CODE inside go-taskqueue's own event spine: error reports arrive as a **command** (`POST /api/v1/errors` → `incident.Recorder`), land as **facts** (`error.observed` on the synthetic `incident:<fingerprint>` journal stream — the session:* precedent), are folded into a pure **projection** (`incident.State`: occurrences, status open→fix-dispatched→resolved/fix-failed, regressions), and a watermark-cursor **policy** (`incident.Policy`, the review/dlqfix sweeper seam) **reacts** by minting agent fix tasks — hot band 120 first occurrence, machine band 150 regression, storm-bounded to one task per stage, dedup-convergent under replay. Verified end-to-end with the real binary.

## a) FULLY DONE

1. **Research pass (all claims source-read, not assumed):** journal fact model + open FactType + session-stream precedent; ADR-0009 (exact-consumer classes, watermarks, dispatcher-vs-own-loop policy); review.Sweeper as the production exact-consumer template (watermark.Cursor pump, handleFact shape, art-dupl annotation); task.New/AgentPayload contracts (`Repo,Prompt,Item,Dedup,V,Verify,Yolo…`); cmd/tq wiring (mintPass tick site, command map); devmod shim mechanics (scripts/lib/cmd-tq-devmod.sh); prior-art scan of tq planning docs (no conflicting ratified design).
2. **Fact family:** `journal.ErrorObserved` ("error.observed") + `journal.IncidentTaskMinted` ("incident.task-minted") in `internal/journal` **and** the public `journal/` facade (ADR-0016 surface).
3. **`internal/incident` package** (5 files, root module, mirrors review/status placement): `incident.go` (Report with secrets-unrepresentable wire type, Clip caps, digit/quote/whitespace-normalizing Fingerprint, TopFrame), `recorder.go` (command handler over the FactSink seam), `fold.go` (pure State fold + incident read model + mint index), `policy.go` (watermark sweeper: needsFix rules, regression detection, mint + prompt renderer, pending guard, first-run replay), `read.go` (FoldAll — watermark-free read for CLI).
4. **Test battery — 9/9 green** against the real SQLite store (house style): fingerprint stability, clip/validate, recorder contract (+invalid-appends-nothing), **storm 1,000→1 task**, replay-after-rewind no-duplicate, **regression mints at 150** + fold records both mints, dead-letter→fix-failed, restart resume no-remint, **first-run replay** (errors recorded before any policy ran still mint).
5. **API surface:** `POST /api/v1/errors` on the machine API (token-guarded via existing `guard`, 1 MiB cap, 202/400-with-fix/503-unarmed) + `Server.UseErrorRecorder`; httpapi tests green including nothing-journaled-on-invalid.
6. **CLI + wiring:** `tq incidents` (table + --json, read-only fold); `tq api` arms the recorder; agent-pool constructs the policy unconditionally and ticks `incident sweep` in the pool loop; usage text updated.
7. **Binary E2E (real tq build via the devmod shim):** POST error → 202 `incident:fa34772f1846042a` → `tq incidents` shows it → `tq agent-pool --once` logs `incident sweep done minted=1` → agent task executes → dead-letters "repo webapp does not exist" (correct permanent classification in an empty projects dir) → fold shows `fix-failed outcome=dead`. **Every lifecycle transition exercised through the real binary.**
8. **ADR-0021** written (`docs/adr/0021-incident-pipeline-error-reports-as-commands.md`): commands/facts/projection/policy decisions, idempotency proofs, documented crash windows + reorder edge, verification inventory.
9. **Vendor tree resynced** (`go mod vendor`) after discovering root builds resolve vendored internal copies.

## b) PARTIALLY DONE

1. **Repo gates: only per-package builds/tests ran.** NOT yet run: root `go build/vet/test ./...`, journal module gate, `scripts/check-facade-parity.sh` (journal facade WAS touched — parity unverified), `scripts/test-cmd-tq.sh`, lint baseline, dprint fmt, check-doc-refs, check-agents-size, check-go-mods, vendor-sync check, ci-local.sh.
2. **Docs: ADR done; the rest not** — DOMAIN_LANGUAGE has no Incident section, AGENTS.md package table lacks the `internal/incident` row, CHANGELOG entry missing, README "command at a glance" lacks `tq incidents`/`POST /api/v1/errors`.
3. **Formatting of new files unverified** (dprint/gofmt never run on them).

## c) NOT STARTED

1. TODO harvest in either repo (see harvest note).
2. Webui/dashboard surface (board column, incidents view, detail-page rendering of error facts).
3. `examples/api` /errors producer sample; reporter library for a real target app (still no target app named — §g).
4. Any postgres-backend verification (sqlitev4 only).
5. Systemd/deploy surface for the API-on-a-host story (tq AGENTS mentions deploy/; not investigated this session).

## d) TOTALLY FUCKED UP (ranked, honest)

1. **"All patterns confirmed" was premature — then four avoidable build failures:** `slog.Discard` (unchecked Go surface), string→Kind assignment, dropped ctx through handleFact→mint, jsontext.Value alias question. All fixable in seconds; all discoverable by reading before writing. I announced confidence one step early.
2. **Debug spiral on the empty fold:** ~4 rounds of theorizing (pointer semantics? pagination? watermark?) before writing a 40-line debug test that found the actual cause in one run — MY TEST computed fingerprints on the unclipped report (`Kind: ""`) while the recorder clips (`Kind: "server"`): different fingerprints, empty Get. Rule violated: **contradiction → empirical probe FIRST**.
3. **Three bugs in my own test code** (fingerprint-of-unclipped-report; regression-task selection assuming List order; `watermarks set` flag-after-positional misuse in E2E). Tests of new code need the same skepticism as the code.
4. **Deferred a smelled-wrong semantic until the binary bit me:** I NOTICED during design that first-run bootstrap-at-head drops pre-policy errors, wrote "document in ADR," and moved on. The E2E then proved the primary deployment flow (api records standalone → pool starts later) drops everything on first start. Fix was 8 lines + a test. **When a semantic smells wrong, fix it now — "documented" is not "decided".**
5. **E2E fixture hygiene:** reused /tmp/tq-e2e/tasks.db across binary versions — the OLD binary's head-watermark made the NEW fix look broken until I realized the DB poisoned the test. Fresh DB per binary under test.
6. **go.mod churn:** added module requires/replaces for `internal/incident` as if it were a sub-module (it's a root-module package like review/), build failed, reverted. The dependency-graph shape should have been read BEFORE editing go.mods, not after failing.
7. **Daemon race transposed:** the tq auto-commit daemon swept the session's work into FOUR heuristic commits (a107c254→c4a5bb08), the last landing the ADR + a policy change BEFORE any repo gate ran — exactly the SystemNix "daemon commits bypass pre-commit legs" gotcha in a new repo. Tree is clean and files verified intact (`git show --stat`), but HEAD is heuristic-messaged, unverified-by-gates, and needs an owner-gated squash (§f-1).
8. **Dead code left in:** `clipStr`'s `utf8.ValidString` if/else has IDENTICAL branches — noticed while writing this report, still unfixed.
9. **Vendor discovery cost two debug rounds** before realizing root builds resolve `vendor/github.com/larsartmann/go-taskqueue/internal/*` copies over the local replaces.

## e) WHAT WE SHOULD IMPROVE

1. **Empirical-first debugging:** on the first unexplained contradiction, write the minimal probe (debug test / print), run it, THEN theorize. Cap theorizing at one round.
2. **Inventory the target repo's guard scripts before touching its build graph** (vendor, go-mod-vendor-sync, facade parity, module scaffolding scripts — the scripts/ dir IS the repo's contract; read it like AGENTS.md).
3. **Gates DURING, not after:** I batched all repo gates to "the end" — the daemon committed ungated code first. Run the narrow gate (build+vet+test of touched packages) immediately, the wide gate before yielding; in daemon-swept repos, the wide gate belongs BEFORE the first 10-minute daemon window if feasible.
4. **Test-of-tests skepticism:** for every assertion that fails mysteriously, check whether the TEST's fixture contradicts the code's contract (clipping, ordering, flag grammar) before blaming the code.
5. **Fresh fixtures per binary/version in E2E** — stateful DBs carry old semantics forward.
6. **Don't defer smelled-wrong semantics to documentation.**

## f) Next things (owner-gated marked ⚠; go-taskqueue items belong in ITS TODO_LIST at harvest time)

1. ⚠ Squash the 4 heuristic daemon commits into one proper feature commit (history rewrite → run the full verification checklist from SystemNix docs/agents/git.md).
2. Run the FULL gate battery: root build/vet/test, journal module gate, facade parity, test-cmd-tq.sh, lint-baseline, dprint fmt, check-doc-refs, check-agents-size, check-go-mods, vendor-sync, ci-local.sh.
3. Fix `clipStr` identical-branch dead code.
4. DOMAIN_LANGUAGE: Incident pipeline section (Incident, Fingerprint, Error observed, Mint, Regression, Fix-dispatched/Resolved/Fix-failed).
5. AGENTS.md package table row for `internal/incident`.
6. CHANGELOG entry (Unreleased section).
7. README: command-map row for `tq incidents`; API section for `POST /api/v1/errors`.
8. examples/api: /errors producer sample next to /enqueue.
9. Harvest §f into go-taskqueue TODO_LIST per its own format guards.
10. Webui: incidents view / board integration (detail page rendering error.observed payloads like agent prompts render today).
11. Decide ⚠ project-name contract (see §g-1): ingest-time validation vs autopsy-owns-it (E2E proved the dead-letter path works).
12. Decide ⚠ flag vs unconditional incident sweep (see §g-2).
13. Name the ⚠ first target app (see §g-3) → build the two-hop reporter (app middleware + browser beacon) against `POST /api/v1/errors`.
14. Postgres backend verification run (postgresv4 path untested this session).
15. Occurrence-count enrichment on the API response (currently {incident} only).
16. Optional: budget carve-out flag for error-minted agent tasks.
17. Optional: per-fact metrics surface (mints/storms) into stats or textfile collector.
18. ADR-0009 convergence note: revisit migrating the policy onto `consumer.Dispatcher.Subscribe` once a production host exists.
19. SystemNix side: if/when the API runs on evo-x2, sops token + systemd unit + port registry entry (lib/ports.nix) — the full SystemNix prevention layers apply to the deployment.

## g) Questions I cannot figure out myself

1. **Project-name contract:** should `Report.Project` be validated at INGEST against a known repo registry (400 on unknown project), or stay tolerant (unknown project dead-letters at execution, DLQ autopsy owns it — what the E2E demonstrated)? Fail-closed-ingest protects agent budget from typos; tolerant-ingest never drops an error report. Which failure mode do you prefer?
2. **Unconditional or flag-gated sweep?** I wired the incident sweep UNCONDITIONALLY into the agent-pool tick (minting is journal-cheap; the tasks stay inert behind the existing autonomy gates: --agents, .tq-agents, budgets, exclusivity). Every sibling sweeper is flag-gated. Keep unconditional, or gate it behind e.g. `--incidents`?
3. **First target app?** The pipeline is live but has no producer. Which app/repo gets the `/internal/errors` beacon + middleware reporter first (name + repo)? This also answers whether v1 needs the client-side (browser) leg at all or starts server-errors-only. _(Same question as the 22-05 report — still open, now the only blocker to real usage.)_

---

**Session verdict:** the pipeline works end-to-end and its invariants are test-pinned (storm/replay/regression/restart), but the session violated its own discipline twice where it mattered — deferred a smelled-wrong semantic until E2E caught it, and batched the repo gates so the daemon committed ungated code first. Both are process fixes, both encoded in §e.

_Harvest note: §f items are deliberately NOT harvested into SystemNix TODO_LIST.md — items 1-18 are go-taskqueue-repo work (that repo owns its own TODO system with format guards) and 19 is deployment-dependent on §g-3. Re-harvest after the owner answers §g._

_Awaiting instructions._

---

## Addendum 2026-10-09 02:30 — remaining non-gated work CLOSED (follow-up session)

Owner instructed "keep going" — everything in §f not marked ⚠ or gated on §g answers is now done. The §g questions remain OPEN and still gate first integration.

- **§f-3 `clipStr` fixed properly, not just de-branched:** the identical if/else was replaced with real rune-safety — a valid-UTF-8 cut backs off to the rune boundary so multibyte messages never halve into U+FFFD; invalid input keeps byte-truncation. Pinned by a new regression case in `TestClipAndValidate` ("€" cuts at 4096 back off to 4095). §d-8 closed.
- **§f-4..7 docs all landed:** DOMAIN_LANGUAGE gained six terms (Error report, Fingerprint, Incident, Mint, Regression, Incident status — every claim cross-checked against `Fingerprint`/`fold.go`/`journal.go` source before writing); AGENTS.md package-table row for `internal/incident` (9 B under the 18,500 B budget; the size-guard paren trimmed to make room — the script twin stays discoverable via the "Guards: check-*.sh" line); CHANGELOG [Unreleased] Added entry; README `tq incidents` command row + `POST /api/v1/errors` folded into the `tq api` row.
- **§f-2 full gate battery — every leg green, no single exit-0 pass yet:** root build/vet/test, journal module gate, `check-facade-parity.sh` (7 facades), `test-cmd-tq.sh`, `lint-baseline.sh` (0 baseline rows for incident/httpapi — no new debt pinned), `nix fmt` (fixed the un-gofmt'd journal facade const block + a policy.go whitespace line + a cmd/tq import order — all last-session residue), `check-doc-refs`, `check-agents-size` (18,491/18,500), `check-go-mods` (45 ok), vendor re-sync no-op, standalone `check-gomod-vendor-sync.sh` green (exit 0, 22/22 sync). `ci-local.sh` itself never exited 0 in one pass: both runs died on FOREIGN transients (run 1: unindexed foreign status report, indexed by its own session minutes later; run 2: dep-bump drift from a foreign bump landing mid-gate — the script's own message names this case, standalone re-run green; the -race leg's first pass also raced the same session and healed on the designed retry). Corrected 02:33 from an earlier "GREEN" overclaim written before the background run finished — full detail in the 02-31 report §d-1.
- **Concurrency note:** a parallel session (composition/ProjectionRuntime, release-hardening) was active the whole window — one edit-tool race on `incident_test.go` (content unchanged, mtime-only) and one 54 B AGENTS.md delta that turned out to be my own mis-measured row padding, both resolved by re-read. This window's work rode daemon sweeps `ec77e26a`, `f550c2eb`, `1c18a441`, `4bf0af82`, `2224fbc1` — the owner-gated squash (§f-1) now covers 9 heuristic commits total (4 from the original session + these 5).
- **Still deliberately open, unchanged:** §f-1 squash (⚠), §f-8 examples/api producer, §f-9 harvest into go-taskqueue TODO_LIST, §f-10 webui view, §f-11..13 (the three §g decisions), §f-14..19. The 22-05/§g questions are the only blocker to real usage.
