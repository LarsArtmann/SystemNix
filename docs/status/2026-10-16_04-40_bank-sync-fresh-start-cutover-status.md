# Status Report — bank-sync fresh-start cutover (staged, undeployed)

**Date:** 2026-10-16 04:40 CEST · **Session scope:** the owner "update bank-sync" request → block re-verification → owner-ratified fresh-start cutover, staged end-to-end. Per instruction, no research beyond this session's observations; open-row citations are from rows this session read/touched.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | **Block re-verified first-hand (twice today)** — the float past `67dd64526` was still hard-blocked by upstream code state at session start | bank-sync HEAD `d622e7b9` still locks go-cqrs-lite `d15e0a48`; 8 new commits (0c8b22dc→d622e7b9) touch only catalog/CI/sqlite-pool/golangci/docs; `journal_preflight.go:140` still `ParseStreamID`s old-key rows; go-cqrs-lite master `118bb9f1` (300-file delta) leaves `core/v5/id` untouched — `String()` still brand-prefixes |
| 2 | **Concrete mechanism explanation delivered** (owner asked "code or DB layout") | walk-through: stored keys `BalanceSync:profile:wise:14757634` / `BalanceSync:<ulid>` (171,945 rows, 45 snapshots) vs computed `BalanceSync:StreamMarker:<derived>`; `StreamRef.StreamKey() = Type + ":" + ID.String()`; preflight `journalCount < version` → all 45 divergent → exit 65 |
| 3 | **Owner decision captured** — fresh-start cutover ratified via structured question ("Go, stage it all") | question-tool transcript |
| 4 | **Pin lift** — flake.nix hard pin → floating `?ref=refs/heads/master` with full-history comment; lock `67dd64526` → `8e384027`; pin-audit allowlist row removed (stale-entry class avoided) | `git show e062ce9e` |
| 5 | **`bank-sync-fresh-start` oneshot** — marker-gated one-time dataDir archive (`bank-sync-pre-keybump-20261016`), Before daemon + storage-dir, `RequiresMountsFor` pool, CAP_DAC_OVERRIDE only, no converger-pattern name, no restartTriggers | `nix eval .#…services.bank-sync-fresh-start.description` = the cutover description; all eval audits green |
| 6 | **FOD buildable at the locked rev under our followed graph — NO shim needed** | `/nix/store/zvmy87q0…-bank-sync-8e384027…` built green (first probe at `d622e7b9` also green) |
| 7 | **`nix flake check --no-build` = "all checks passed!"** — pin audit, deploy-restart-audit, systemd-shape, mount-gating all accept the changes | check output |
| 8 | **Empty-journal boot rehearsal PASSED** — `BANK_SYNC_DEMO_DB` scratch + `bank-sync demo` on the built binary under `timeout` | rc=124 (timeout-kill of a HEALTHY server), dashboard + daemon listening lines, **0** divergence lines, no leftover process, scratch cleaned |
| 9 | **Docs synced (7 surfaces)** — runbook §Fresh-start cutover (mechanism + empty-scratch rehearsal protocol + post-cutover checklist), CHANGELOG ×2, upstream.md blocker row closed as moot, TODO_LIST +2/−2 closed, services.md +3/−1 closed | `git show 688de929`, `e062ce9e` |
| 10 | **Formatter + guards** — scoped `nix fmt` 0-changed; `check-todo-system.sh`: "OK: TODO queue/library structure clean"; daemon-swept commits inspected (`git show --stat`) — only my files rode them | outputs in-session |

## b) PARTIALLY DONE

1. **The cutover itself** — staged, eval-proven, rehearsal-proven … **and undeployed**. The switch is gated on the browser-history StateShape fix (upstream) + owner go.
2. **The rehearsal** — positive-only: it proves an empty journal boots clean; it does NOT prove the preflight still *fires* on `8e384027` (I found the wiring at `infrastructure.go:347` but never proved demo exercises it — the absence of a divergence line is weaker evidence than a demonstrated refusal). Harvested as a `[ready]` row: seed one old-key snapshot row in scratch → expect exit 65.
3. **Post-deploy checklist** — fully written into the runbook (7 steps), zero steps executable until the deploy lands.
4. **The parallel session's bank-sync pushes** — I consumed their result (master moved to `8e384027` mid-session, re-locked, re-built) but deliberately did not review their split-brain changes (`sca.go`, `error_templates.go`, `deploy/nixos/bank-sync.nix` module defaults) beyond confirming the inner go-cqrs-lite pin — their surface, their close-out.

## c) NOT STARTED (by this session; mostly out of scope or owner-gated)

1. **browser-history `StateShape` fix** — upstream master == `cbe6bac` (ahead 0); fix is in that repo (re-sync `_local_deps/cqrs-htmx` or drop the field). Queued `[ready]`. **This gates EVERY evo-x2 deploy.**
2. **The cutover deploy** — waiting on (1) + owner timing.
3. **Wise SCA re-approval** — owner 2FA flow (phone-change class since 2026-10-09); unchanged by the cutover.
4. **Full-history backfill 2021-01-01→today** — needs (3).
5. **Paperless duplicate-statement check** — needs the first backfilled Sunday archival.
6. **Upstream key-compat work (options a/b)** — now MOOT for SystemNix (no consumer starts against old-key data); recorded as closed in upstream.md.
7. Not touched (pre-existing rows read during greps, left for their owners): verdict-only SCA 403 classification, readiness-gate storm tolerance, MemoryHigh thrash review, 55 s boot activation, sync-streak restart semantics, leaked demo instances, SCA re-approval runbook gaps (already closed by another session 2026-10-14).

## d) TOTALLY FUCKED UP

**Nothing.** No breakage left behind: tree evals green before and after, eval-only changes are additive (one new unit), no stray processes, all doc surfaces synced, daemon commits inspected. Honest near-misses (caught, corrected, none landed broken):

- **First probe-build ran WITHOUT `--keep-going`** — under-enumerated failures and burned a run on browser-history noise before the proper enumeration. The house rule ("--keep-going FIRST") exists precisely for this; I re-ran it correctly (isolated FOD probe + full keep-going enumeration), but the first run shouldn't have happened.
- **Malformed question-tool call** (missing `type` field) — one wasted round trip before the go/no-go reached the owner.
- **A stale-premise risk I did NOT walk into** (for the record): had I floated the lock without re-probing after the re-lock moved master `d622e7b9`→`8e384027`, the "builds green" claim would have been about a rev the tree no longer holds.

## e) WHAT WE SHOULD IMPROVE

1. **When reporting a block, present the remedy SPACE, not just the wall.** Yesterday's identical owner float request was aborted with "still blocked" — the fresh-start option was derivable from the same runbook evidence ("every journal fact is Wise-derived" was already written down) and would have saved a day. Verify-and-stop is half the job; option-invent is the other half.
2. **`--keep-going` FIRST, every time** — the rule now has a fresh datapoint (mine).
3. **Rehearsals need their negative case.** Positive-only rehearsals can prove the happy path while the guard silently doesn't run. The old-key-scratch negative rehearsal should be standard for any preflight-gated cutover.
4. **Prove wiring before asserting it.** "The preflight passed" ≠ "the preflight ran". I hedged correctly in the report, but the negative rehearsal closes it properly.
5. **Mid-flight relock discipline worked** — upstream master moved twice during the session; every build/claim was re-anchored to the rev the tree actually holds. Keep doing exactly this.
6. **Question-tool payloads** — validate the schema mentally before sending; a malformed call costs the owner a round trip.

## f) Up to 50 things we should get done next (impact-ordered brainstorm)

*Per the status-report skill: beyond the top items this is a brainstorm, not a commitment list — harvest goes through docs-health rigor. Items marked **[harvested]** already have queue/library rows from this session; the rest are ROADMAP fuel or belong to existing rows.*

**Gate + cutover cluster (do first):**
1. Fix browser-history `_local_deps/cqrs-htmx` StateShape drift upstream, push, SystemNix relock — **[harvested]**, THE deploy gate.
2. Negative preflight rehearsal (old-key scratch row → expect exit 65) on `8e384027` — **[harvested]**, pre-deploy confidence.
3. Deploy the fresh-start cutover once unblocked — owner go + timing.
4. Post-deploy verification battery: exactly-once fresh-start journal line, `/health/ready` 200, HM CLI = new binary, post-deploy-check.sh — **[harvested]**.
5. Wise SCA re-approval (owner 2FA) → full-history backfill 2021→today → `bank_sync_sync_total` climbs — **[harvested]** (battery row).
6. Paperless duplicate-statement check after the first backfilled Sunday archival — **[harvested]** (battery row).
7. Decide canary handling while SCA is blocked (first post-cutover Sunday run will OnFailure-push; see question 3).
8. Smoke-baseline: annotate the expected post-cutover reds (SCA rows) with first-seen stamps — folds into existing row 192.
9. After backfill verifies: decide the archive's fate (retention/trash) — see question 1; never trash before (6) is clean.
10. Consider a fixtures/selftest leg for the fresh-start marker logic (house pattern: storage-history/pre-vacuum got selftests).

**Bank-sync residual debt (all pre-existing rows, unchanged by the cutover):**
11. Verdict-only SCA 403 classification → light `bank_sync_sca_approval_pending` (rows 383/398).
12. Readiness-gate storm tolerance (PSI-aware budget; 10 wasted restarts 2026-10-14) (row 1272).
13. MemoryHigh reclaim-thrash review: bank-sync 5k hits (rows 221/467).
14. 55 s boot-activation mechanism diagnosis (rows 513/336).
15. `bank_sync_sync_consecutive_failures` restart-semantics probe (row 477).
16. `bank_sync_sync_errors_total` windowing + DB-write-failure metric (rows 997/1251).
17. Analyze one captured Wise trace (`error=` empty, 20 failed balances) (row 430).
18. gatus live-verify of the 4 bank-sync checks post-deploy (rows 399/535).
19. Clean up the 5 leaked `bank-sync demo` instances from 2026-10-07 (row 401).
20. Systemd-ize the post-approval auto-backfill watcher vs ad-hoc poller (row 402).
21. `bank_sync_sync_sustained_failure`/challenge-counter semantics after the next restart (row 411).
22. Record the wrong-phone incident narrative in the runbook once SCA lands (row 400).
23. Un-follow bank-sync's nixpkgs input decision (kill the vendorHash-skew class) (rows 331/1076).
24. Watch: fresh-start changes the HM `programs.bank-sync` admin surface — first CLI use post-deploy double-checks the second surface (new, tiny).
25. Update FEATURES.md bank-sync rows after the deploy (docs-health BUILD/VERIFY pass).

**Fleet/deploy-hygiene items surfaced by this session's greps:**
26. Run post-deploy-check.sh after the pending vendorHash-wave switch (monitoring row 354).
27. Fold the python-urllib+gunzip `/metrics` probe recipe into the monitoring runbook (row 355).
28. monitor365 :9191 connection-refused triage (row 349).
29. Catalog integration-subdomains warning — 21 names incl. `banksync` (rows 427/437/505).
30. CI-watch the 2026-10-13 eight-repo upstream push wave (row 549).
31. Audit the other four 618d4593-wave inputs against documented ceilings (upstream row 16 — bank-sync's leg is now moot, the other four aren't).
32. Same-rev FOD drift probe for pinned FOD inputs (pipeline row 890).
33. pre-commit nixpkgs fast-guard honesty sweep (pipeline row 13/642).
34. go-nix-helpers dynamic toolchain row — drop `goPkgAttr` pins on next helper move (upstream row 91).
35. GOPRIVATE decision for the private SDK family incl. bank-sync (pipeline row 36).
36. Smoke-baseline staleness stamps generally (pipeline row 192).
37. Failure catch-up for remaining dump legs (bank-sync among them) — storage row 1010.
38. Fleet-wide infra follows in tool repos (upstream row 18).
39. SigNoz trace instrumentation parts 3–6 (upstream row 24).
40. systemd-ize decision for SCA watchers generally (row 402's broader pattern).

**Session-specific polish:**
41. If the negative rehearsal (2) passes, consider promoting the fresh-start pattern into docs/agents/systemd.md as the general "key-basis cutover" recipe.
42. Snapshot the fresh-start oneshot's journal line format into the post-deploy-check baseline expectations (so the "moved" line is EXPECTED, not flagged).
43. After the deploy + backfill: annotate this report + the runbook with the real final journal/snapshot counts (171,945 rows / 45 streams are the pre-cutover record).
44. Re-run the §17 memory sweep attribution post-cutover (bank-sync restarts reset its counters — the 5k-hit row's premise partially resets too).
45. Consider whether `bank-sync-paperless` archival coverage state (pre-cutover coverage spans) needs a one-line note in its own runbook pointing at the fresh-start section.
46. Demo-mode hygiene: `bank-sync demo` self-cleans its temp DB but only when `BANK_SYNC_DEMO_DB` is unset — the rehearsal pattern pins a path; consider a `--ttl` or trap in upstream demo.go (suggestion file).
47. When browser-history is fixed, extend the keep-going enumeration into a permanent pre-deploy gate output (it just proved its worth twice).
48. Pin-audit header comment still narrates bank-sync among the 2026-10-14 rollback pins — historical, fine, but a one-line "lifted 2026-10-16" pointer would prevent future archaeology.
49. ROADMAP: upstream-side (a) passthrough fix is dead weight for SystemNix — mark it wontfix-in-SystemNix scope if any consumer ever reappears.
50. Harvest check on THIS report: items 2 and 4 are harvested (rows added at authoring time); items 1/3/5/6 pre-existed as rows; the rest deliberately not harvested (brainstorm per the skill's >25 rule; owners: their existing rows or ROADMAP).

## g) Questions I cannot figure out myself

1. **Archive disposition:** how long should `/mnt/pool/services/bank-sync-pre-keybump-20261016` live, and what's the trash condition — clean Paperless duplicate check + N days? forever? (It's permission-gated to the service user, so I can't even size it, and the retention call is yours.)
2. **Deploy timing:** once browser-history unblocks the tree, do you want the cutover switched immediately (sentinels legitimately red until your SCA approval — a day or more of known-red push noise) or held until you're sitting on the SCA approval flow so red is minutes, not days?
3. **Canary during the blocked window:** the weekly canary's first post-cutover run will hit the SCA block and OnFailure-push. Keep that push as your reminder to re-approve, or should I gate/skip the canary until SCA is approved (one-line unit condition)?

---

*Self-harvest record: rows 2 + 4 landed in TODO_LIST.md + docs/todo/services.md at authoring time (fresh-start verification battery + negative preflight rehearsal); items 1/3/5/6 already had rows; all remaining §f items are deliberately unharvested brainstorm (skill's >25 rule — ROADMAP fuel, docs-health HARVEST applies extra routing rigor).*
