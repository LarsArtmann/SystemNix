# Status Report + Brutal Self-Review — Incident Pipeline Close-out: Docs, clipStr, Full Gates

- **Date:** 2026-10-09 02:31 CEST
- **Session:** the close-out leg of the 23-34 incident-pipeline report — owner said "keep going", so every NON-gated item in its §f was executed: docs (DOMAIN_LANGUAGE / AGENTS row / CHANGELOG / README), the `clipStr` fix, and the full go-taskqueue gate battery. The three §g decisions remain OPEN and untouched.
- **Repo pins:** go-taskqueue @ `7dd59cdd` (master, clean; parallel release-hardening + composition sessions active the whole window) · SystemNix @ `c0e59af7` (clean; this report + the 02:33 addendum correction swept by the daemon)
- **Scope:** this session's run only. Pipeline semantics themselves are unchanged from the 23-34 report — nothing in `internal/incident`'s behavior was touched except `clipStr`.

---

## What did I forget? What could I have done better?

Four concrete misses, all mine, all recovered:

1. **I wrote "gate battery GREEN (… ci-local.sh …)" into the 02:30 addendum while ci-local was STILL RUNNING in the background** — it then exited 1 (twice, both foreign-transient). That is the exact "assert success from output text alone" class this repo already has a rule for; background jobs are where the temptation is worst. Corrected 02:33 with the per-leg-green/no-full-pass truth (see §d-1).
2. **My AGENTS.md row was 137 B, not the 84 B I estimated** — I forgot I had padded BOTH table columns. That blew the 18,500 B guard, and worse: I first MISATTRIBUTED the overshoot to a parallel session ("+54 B unexplained") instead of checking my own arithmetic. Daemon-commit forensics (`git show --stat f550c2eb` = exactly my 2 edits) settled it in two tool calls. Attribution needs evidence, not narrative — the SystemNix live-verify rule applies to byte math too.
3. **My first multibyte regression test had two arithmetic errors** (message below the cap → nothing clipped; 2-byte runes can never split at an even cut). It caught itself by FAILING, but I burned two cycles on uncomputed fixture math.
4. **On the edit-tool mtime race I diagnosed via bash twice** before realizing the edit tool keys its read-state on `view`, not `cat`/`sed`. View-first on "modified since read".

## a) FULLY DONE

1. **`clipStr` fixed for real (23-34 §f-3 / §d-8 closed):** the identical if/else is gone; a valid-UTF-8 cut now backs off to the rune boundary (no more halving multibyte characters into U+FFFD), invalid input keeps byte-truncation. Pinned by a new case in `TestClipAndValidate`: 2,000 × "€" (6,000 B) clipped at MaxMessage=4096 backs off to 4095. `internal/incident` + `internal/httpapi` 10/10 green.
2. **DOMAIN_LANGUAGE (§f-4):** six terms added — Error report, Fingerprint, Incident, Mint, Regression, Incident status. Every claim cross-checked against source BEFORE writing (Fingerprint inputs + release-EXCLUSION verified at `incident.go:178-191`; `TaskDedupPrefix = "err:"` at `policy.go:26`; statuses at `fold.go:19-23`; fact types at `journal.go:82,90`).
3. **AGENTS.md package-table row (§f-5):** `internal/incident | Error reports → fix tasks (ADR-0021)`, 18,491/18,500 B — BOTH guards green (script + `TestAgentsDocSizeGuard`). Made room by compressing the size-guard paren to the test name only (the script twin stays discoverable via the "Guards: check-*.sh" line).
4. **CHANGELOG (§f-6):** [Unreleased]/Added entry describing the whole pipeline (command → fact → fold → mint → lifecycle fold-back, priorities, dedup, ADR-0021 pointer).
5. **README (§f-7, table half):** `tq incidents` row in the command map + `POST /api/v1/errors` folded into the `tq api` row.
6. **Formatting debt cleared:** `nix fmt`/gofmt caught three last-session residues — the journal FACADE const block (unformatted since the facade re-exports landed), a whitespace-only line in `policy.go`, and an import-order slip in `cmd/tq/main.go`. All fixed, re-tested.
7. **Gate battery — every leg verified green individually:** root build/vet/test (`./...`); journal module gate; `check-facade-parity.sh` (7 facades); `test-cmd-tq.sh`; `lint-baseline.sh` with **0 baseline rows for incident/httpapi** (no new debt pinned — verified by grep after the daemon swept the regenerated baseline); `check-doc-refs`; `check-agents-size`; `check-go-mods` (45 ok); `go mod vendor` no-op; standalone `check-gomod-vendor-sync.sh` green (22/22 sync, exit 0); ci-local's legs (vet, build, windows cross-compile, `-race` — first pass raced the parallel session and healed on the DESIGNED retry 1/3, second pass fully green — module-isolation ×23, embed example, go-mod hygiene, all self-test pins).
8. **SystemNix 23-34 report addendum (02:30, swept in `5b1b23a0`) + its 02:33 correction** recording this window's closure and the corrected gate truth.
9. **Concurrency discipline held:** content-pinned before every write, re-read after both races (one mtime-only touch, one real 54 B delta that turned out to be my own padding), pathspec-free tree left clean for the daemon, no revert of foreign work (the foreign unindexed report that redded run 1's doc gate was indexed by ITS session minutes later — I only verified, never touched it).

## b) PARTIALLY DONE

1. **ci-local end-to-end:** every leg is green, but NO single run exited 0 — two runs, two different foreign transients (run 1: unindexed foreign status report in the daemon-sweep doc gate; run 2: dep-bump drift from a foreign bump landing mid-gate — the script's own failure text names this case and says "let it commit and re-run"; standalone re-run green). A clean single exit-0 pass needs a quiescent tree, which a live parallel session makes a lottery. This is the one missing end-to-end proof.
2. **README "API section" (§f-7, prose half):** the ask was a section; I delivered a table-row mention of `POST /api/v1/errors`. Accurate but shallow — no request/response example, no 202/400/503 contract prose.
3. **AGENTS.md STATUS line still says "v0.3.2 shipped"** while `worker/v0.3.3` and `internal/composition/v0.3.4` tags exist. Noticed on sight, deliberately left (owning session's active surface; same-length fix would have been free but racing a live session's doc is how split brains start). Still stale at close.

## c) NOT STARTED (deliberately, unchanged from 23-34 §f)

§f-8 examples/api `/errors` producer sample · §f-9 harvest into go-taskqueue's TODO_LIST (recorded deferral: after §g answers) · §f-10 webui incidents view · §f-14 postgres backend verification of the incident path · §f-15 occurrence-count enrichment on the API response · §f-16 budget carve-out flag · §f-17 per-fact metrics surface · §f-18 ADR-0009 Subscribe convergence · §f-19 SystemNix deployment leg (sops token, systemd unit, `lib/ports.nix` entry — gated on §g-3).

## d) TOTALLY FUCKED UP

1. **The premature GREEN claim (see opening #1):** a close-out document asserted a gate result before the gate returned. Not a code bug — a TRUST bug, in exactly the genre this repo's rules exist to prevent ("a verification close-out must answer the question the item ASKED"; "never assert success from output text alone"). Corrected in the same surface it was written in, naming the post-state; recorded here so the class stays visible.
2. **The byte-math + misattribution miss (opening #2).** Recovered fast, but the wrong theory came FIRST and could have shaped edits (I nearly "made room" for a phantom session's bytes).
3. **Structural finding recorded, not yet fuckup but one release away from being one:** `cmd/tq` (replace-free, ADR-0017) now imports `internal/incident`, which exists in NO published tag — `@latest` (v0.3.3) answers "does not contain package …/internal/incident". Today the drift gate merely PRINTS that (tolerated stderr, exit 0 — the normal between-releases window for any new cmd/tq-consumed internal package; the devmod shim masks it for dev builds, which is why `test-cmd-tq.sh` stays green). The lockstep release resolves it BY DESIGN (root module tags first, then cmd/tq's require bumps). But if the release flow ever tags cmd/tq BEFORE root, that tag is a poisoned install on the proxy. There is no runbook row pinning the ordering.

## e) WHAT WE SHOULD IMPROVE

1. **Exit codes before prose:** no gate claim goes into a report while its process runs — "in flight" is an honest state. Background jobs are the highest-risk case (output LOOKS complete at the tail).
2. **Byte-budget arithmetic before editing:** compute the exact line length (2 + col1 + 3 + col2 + 2 + newline) for any guarded file; padding is not optional weight, it IS the cost.
3. **On an unexplained delta, diff against HEAD first** (`git show HEAD:file | wc -c`) — evidence beats narrative, especially when the narrative blames a colleague session.
4. **Compute test-fixture math before writing the test** (cap position, rune width, expected remainder). My €-test burned two cycles on arithmetic I could have done on paper.
5. **`view` (not bash cat) refreshes edit-tool read-state** after an mtime race — one tool call, not a forensics detour.
6. **The between-releases window for new cmd/tq internal imports deserves a machine-checked rule**, not tolerated stderr: a release-gates check that refuses to tag cmd/tq while any of its internal imports is absent from the LATEST tagged root module. Cheap, kills the poisoned-tag class entirely.
7. **Quiescence is a gate input:** when a battery is this long and the tree is shared, run the single-pass proof at a quiescent moment (or accept per-leg evidence and say so) instead of burning 3 re-runs on foreign transients.

## f) Next things (⚠ = owner-gated; go-taskqueue items belong in ITS TODO_LIST at harvest time)

1. Re-run `ci-local.sh` once on a quiescent tree → the missing single exit-0 pass.
2. ⚠ Squash the 9 heuristic daemon commits (original 4 `a107c254`→`c4a5bb08` + this window's `ec77e26a`, `f550c2eb`, `1c18a441`, `4bf0af82`, `2224fbc1`) — now INTERLEAVED with foreign release-hardening commits, so this is an interactive rebase over shared history, not a contiguous squash; full SystemNix rewrite checklist applies.
3. ⚠ §g-1: project-name contract (fail-closed ingest validation vs tolerant + DLQ autopsy).
4. ⚠ §g-2: incident sweep unconditional (current) vs flag-gated like every sibling sweeper.
5. ⚠ §g-3: first target app (name + repo) → then build the two-hop reporter/beacon.
6. Release-gates row: refuse to tag cmd/tq while any cmd/tq internal import is missing from the latest tagged root module (§d-3/§e-6).
7. examples/api `/errors` producer sample next to `/enqueue` (23-34 §f-8).
8. README prose API section for `POST /api/v1/errors` (request/response, 202/400-with-fix/503-unarmed contract).
9. Harvest 23-34 §f + this §f into go-taskqueue's TODO_LIST (after §g answers, per the recorded rationale).
10. Webui: incidents view / error.observed payload rendering on detail pages.
11. Postgres backend verification run for the incident path.
12. Occurrence-count enrichment on the API response (currently `{incident}` only).
13. Per-fact metrics surface (mints/storms) into `tq stats` or the textfile collector.
14. Budget carve-out flag for error-minted agent tasks.
15. ADR-0009 convergence: migrate the policy onto `consumer.Dispatcher.Subscribe` once a production host exists.
16. AGENTS.md STATUS line v0.3.2 → current release (owning session's; spot-fix if still stale at next touch).
17. SystemNix deployment leg when §g-3 lands: sops token, systemd unit, port registry entry, gatus check (23-34 §f-19).

_Harvest note: §f is deliberately NOT harvested into SystemNix TODO_LIST.md — items 2-5, 9 are owner-gated on the §g answers, the rest are go-taskqueue-repo work that repo's own TODO system owns (same recorded rationale as the 23-34 report). Re-harvest after the owner answers §g._

## g) Questions I cannot figure out myself

1. **Project-name contract (§g-1, unchanged):** should `Report.Project` be validated at INGEST against a known repo registry (400 on unknown project — fail-closed, protects agent budget from typos), or stay tolerant (unknown project dead-letters at execution and the DLQ autopsy owns it — what the E2E actually demonstrated)? Which failure mode do you prefer?
2. **Unconditional or flag-gated sweep (§g-2, unchanged):** the incident sweep currently runs UNCONDITIONALLY in the agent-pool tick (minting is journal-cheap; minted tasks stay inert behind the existing autonomy gates). Every sibling sweeper is flag-gated. Keep as-is, or gate behind `--incidents`?
3. **First target app (§g-3, unchanged — still the only blocker to real usage):** which app/repo gets the error reporter first (name + repo)? This also decides whether v1 needs the browser-beacon leg at all or starts server-errors-only. (Squash timing from §f-2 can ride along with this answer if you care.)

---

**Session verdict:** all non-gated close-out work is done and per-leg verified green; the two self-inflicted wounds (a premature GREEN claim, a byte-math misattribution) were caught, corrected in the surfaces they were written in, and encoded as process rules. The pipeline itself needed nothing — `clipStr` was the only code touched, and it came out STRONGER than the minimum de-branch (real rune-safety + a test that proves it). What remains is one quiescent ci-local pass, owner decisions, and the harvest.

_Awaiting instructions._
