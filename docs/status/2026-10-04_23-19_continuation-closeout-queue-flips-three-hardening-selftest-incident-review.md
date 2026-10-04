# Continuation Closeout — Queue Flips, Three Script Hardenings, Selftest Incident Review (2026-10-04 23:19)

**Session:** direct continuation of the 19-43 movie-window session (owner meta-dispatch: "READ, UNDERSTAND, RESEARCH, REFLECT… keep going until done"). Window 22:50–23:02, report at 23:19. Constraints honored all session: no deploys, no VM tests, no builds, no sudo, **zero nix invocations** (IO storm live the entire window — some avg10 54→56%, load ~9-10; freeze-15 "agent verification battery" class consciously avoided). `systemctl` sandbox-ban respected. This report covers ONLY this continuation run + what it noticed.

## a) FULLY DONE (verified)

1. **Queue bookkeeping — all 16 closed rows flipped `[x]` on BOTH surfaces.** The 13 movie-window items (journal-proof tq verdict-correction, clickhouse store-hit pin live-verify, T14 hardening live-verify, paperless_tasks closure, geometrikks runtime-log source-verify, the 4 docs items, CHANGELOG batch, gitleaks pin, adversarial §f clause, time-gated lint leg) + this session's 3 (das-check `[6]`, dns-update selftest, cv-oidc smoke). TODO_LIST one-liners + services/monitoring/pipeline/storage library rows all stamped with evidence pointers into the 19-43 report §a + its Continuation section. `check-todo-system.sh` green rc=0 at start, mid, and end (0 FAIL; 49-DRIFT/88-UNHARVESTED WARNs pre-existing). **The tq pool can no longer re-dispatch any of the 16.**
2. **das-link-recovery-check.sh `[6]` empty-dir churn distinction — landed + live-proven on its first run.** Empty-dir branch prints "(empty, recurring transient?)"; the recreated-empty `golangci-lint-analysis` (5th recreation today) took that branch while `alt-nix`/`scratch` kept the debris hint. `bash -n` green.
3. **dns-update.sh pin-extraction selftest — 4/4 green, hermetic.** Extraction factored into `extract_sb_pin()` (single shipped regex — no test-copy drift); `--selftest` proves: healthy `hosts/<40-hex>/` URL → the commit, never `hosts`; commit-less URL → empty (fail-loud path fires); hagezi `hosts/` decoy → never matches. See §d for the incident that shaped the `exit`.
4. **deploy.sh cv OIDC anti-replay smoke assertion — contract-locked.** Decision extracted to `scripts/lib/cv-oidc-gate.sh` (pure `cv_oidc_gate_decide <before> <after>`, byte-stable deploy-output lines; deploy.sh keeps systemctl/sha256sum plumbing — runtime behavior and output byte-identical to the inline gate). `scripts/check-cv-oidc-gate.sh`: unchanged→skip+smoke-line, rotated/absent-edge→restart, plus wiring greps (source + call + plumbing); selftest rejects 4 drift shapes (inverted decision, reworded line, unwired call, deleted function); plain run green; **pre-commit leg wired** on staged deploy.sh/lib edits (parity-leg pattern); standalone hook run green rc=0 with skip-paths proven and NO eval spawned (empty-staging fast path verified). Nullglob audit: 4 warnings, all pre-existing (flake.nix ×3, test-caddy-mint.nix), none mine.
5. **nvme0n1p8 corruption counter — preserved, not dropped:** `[blocked:user]` triage row in docs/todo/storage.md (by-id mapping across the nvme0↔nvme1 swap; magnitude reconciliation vs the documented 1.35M csum damage; device-stats delta across the next scrub).
6. **CHANGELOG:** continuation-batch bullet under [Unreleased]/Added (bookkeeping + the 3 hardenings + the queued triage row).
7. **Report trail:** Continuation section appended to the 19-43 report (Q1 answered by doing, Q2 queued, Q3 deferred-with-reason); THIS report self-harvests §f (see Harvest log).
8. **Tree hygiene:** the dns-blocklists.nix accidental mutation fully reverted (tree was clean at 22:50 — the diff was provably 100% this session's product); parallel-session work (2 TODO_LIST rows earlier, commit `1554cb40` cmdguard docs) untouched; daemon's mid-session heuristic commits (`5a07ffaf`, `3d8efd8c`) verified to contain exactly my files.

## b) PARTIALLY DONE

1. **The bookkeeping is flipped but NOT pruned.** TODO_LIST's own header says "a `[x]` row must never persist here — done items are pruned to CHANGELOG at every pass"; I flipped 16 rows to `[x]` (matching the observed house pattern — other sessions' `[x]` rows also persist) and added the CHANGELOG bullet, but the physical prune (row removal) is owed. Deliberate: pruning 16 rows without the owner confirming the flip-vs-prune rhythm (§g Q2) risks churn. Prune pass queued (§f.1).
2. **cv-oidc-gate CI coverage.** Pre-commit leg + standalone check green, but the flake-check wiring (`checks.x86_64-linux.cv-oidc-gate`) is deferred — wiring it requires a flake.nix edit whose eval I could not verify without a nix invocation mid-storm. HARVESTED as a [ready] row (both surfaces) at authoring time.
3. **Shellcheck on the session's shell edits.** `bash -n` green everywhere, constructs mirror in-file patterns — but true shellcheck never ran: I claimed "shellcheck not in sandbox" while the repo CARRIES `scripts/shellcheck.sh` (locked-nixpkgs wrapper, landed 2026-09-30) which I forgot existed until post-session reflection. Not yet run (report-then-wait); queued as the adoption row §f.3.

## c) NOT STARTED (this session's remaining surface; all open rows, none silently dropped)

1. **Parity-leg live-fire** (TODO_LIST:20) — PSI probed twice (54%, 56%): storm never drained; the row's own quiescent-moment constraint governs. Correctly deferred, documented.
2. **Stretch items from the 19-43 §c.4** — untouched, still open queue rows: SSO table refresh, dead-guard-lint v2 non-`-z`/`-n` forms, buildcache-metrics pnpm gauges, textfile exit-0/empty-value class audit, per-unit io.stat sampler, pre-deploy build-set enumeration leg, dump-leg OnFailure catch-up, under-hot guard case in test-hot-db-assertions.nix.
3. **paperless-tasks-collector fixture test** (TODO_LIST:747) — sibling of the closed metric-presence row; deliberately out of this batch's scope, still open.
4. **88 unharvested §f-bearing reports + 49 pairing-drift WARNs** — standing backlogs, separately queued, unchanged by this session.

## d) TOTALLY FUCKED UP (caught in-session; all root-caused, none survived to the tree)

1. **dns-update selftest fall-through — the session's real failure.** My first `--selftest` cut lacked `exit`: after printing 4/4 green it FELL THROUGH into the main path, ran `git ls-remote`, and refreshed SRI hashes — **mutating 16 lines of `platforms/common/dns-blocklists.nix`**, a tracked config file, mid-storm, un-sanctioned. Root cause: I designed the mode but never traced control flow past the final assertion before executing a script I had just written (the exact "read before you run" discipline this repo preaches). Contained: mutation noticed in the same output, `git restore` within the minute (clean-tree baseline from 22:50 proved sole authorship), `exit` added, re-run verified hermetic (no network, no repo file). Silver lining: the run accidentally re-proved the HaGeZi drift is live again (16/23 lists) — recorded on the existing nightly-automation row, not a new row.
2. **CHANGELOG bullet fusion.** My insert used an old_string that was a line-PREFIX of the long storm-deploy bullet — the edit silently merged my bullet onto that line's remainder. Caught by immediate post-edit structural greps (bullet-count went 1/0), split restored, both bullets verified intact. Lesson re-confirmed: on long single-line markdown bullets, match the WHOLE line or verify structure right after.
3. One edit-tool refusal (TODO_LIST cv-oidc row: I composed old_string from the pipeline.md twin instead of the actual queue line — "sha-gate" vs "deploy.sh sha-gate"). Re-grepped, retried exact, landed. Cheap miss, zero damage.

## e) WHAT WE SHOULD IMPROVE

1. **`--selftest`/mode-flag discipline:** every mode that must not continue (selftests, `--check`, dry-runs) needs `exit` BEFORE the main path BY CONSTRUCTION — and a CONTRIBUTING line saying so (queued §f.4). This session paid the lesson once; the repo has at least 3 more mode-carrying scripts that should be audited for the same shape.
2. **Agent tool-blindness to house wrappers:** "shellcheck not in sandbox" was false — `scripts/shellcheck.sh` exists precisely because two prior sessions hit this (its own header says so). Agents keep re-deriving tool availability from $PATH instead of the repo. A pointer in AGENTS.md/CONTRIBUTING ("lint shell via scripts/shellcheck.sh, never assume PATH") closes the class (queued with §f.3).
3. **Flip-vs-prune ambiguity is now 16 rows deep.** The TODO_LIST header and observed practice disagree; every session that flips without pruning widens the gap between the written contract and the file. Needs one owner sentence (§g Q2), then either a prune pass or a header amendment.
4. **Check-driven debris churn on the buildcache SSD:** `.cache-write-probe`/`.checks-probe`/`.devshell-probe` (trashed as debris 2026-10-02) are BACK — the checks that create them keep paying mount-IO and [6]-noise for zero value. Same class as the golangci-lint-analysis writer hunt: bless the names with provenance or fix the writers (queued §f.5).
5. **Daemon commits still bypass pre-commit legs on new scripts** — my two new scripts + hook edit landed via heuristic daemon commits, so the gitleaks/shellcheck legs never saw them staged. No secrets involved (fixture uses a public upstream commit hash), but the standing gap (TODO_LIST:724 daemon-past-failing-hooks family) remains the structural answer.
6. **Session hygiene positives to keep:** content-pinned before writes (HEAD + clean tree at 22:50), daemon-swept commits verified with `git show --stat`, PSI probed before every heavy decision, zero nix invocations under storm, parallel-session work never touched.

## f) Next (ranked; existing rows cited, new rows harvested at authoring — see Harvest log)

1. **TODO_LIST `[x]` prune pass** — remove the 16 flipped rows (evidence lives in CHANGELOG + reports) and the older persisting `[x]` rows; enforces the header contract (NEW row).
2. **cv-oidc-gate flake-check wiring** (`checks.x86_64-linux.cv-oidc-gate`) at a quiet eval window (NEW row, harvested).
3. **Run `scripts/shellcheck.sh` over this session's shell edits** (check-cv-oidc-gate.sh, lib/cv-oidc-gate.sh, dns-update.sh, das-link-recovery-check.sh, .githooks/pre-commit) + adopt the wrapper in the agent conventions doc (NEW row, harvested).
4. **CONTRIBUTING: selftest-modes-exit-first convention** + audit the 3+ existing mode-carrying scripts for fall-through (NEW row, harvested).
5. **check-probe dirs (`-write-probe`/`-checks-probe`/`-devshell-probe`): bless into KNOWN_CACHE_ENTRIES with provenance or fix the writers** (NEW row, harvested — storage).
6. Parity-leg live-fire at PSI-calm (existing TODO_LIST:20).
7. Nightly dns-blocklist drift automation — 16/23 lists drifted AGAIN tonight; each drift is a future killed deploy (existing TODO_LIST:240).
8. golangci-lint-analysis writer hunt — 5th recreation today (existing TODO_LIST:41).
9. paperless-tasks-collector fixture test (existing TODO_LIST:747).
10. Textfile-collector exit-0/empty-value class audit (existing TODO_LIST:748).
11. Dead-guard-lint v2 non-`-z`/`-n` forms (existing TODO_LIST:706).
12. SSO-layer table refresh in docs/agents/sso-dns.md (existing TODO_LIST:708).
13. buildcache-metrics pnpm-cache/pnpm-state gauges (existing TODO_LIST:715).
14. Per-unit io.stat top-consumer sampler (existing TODO_LIST:753).
15. Pre-deploy build-set enumeration leg (existing TODO_LIST:739).
16. Store-hit-first reflex in the deploy runbook (existing TODO_LIST:740).
17. dump-leg OnFailure catch-up + under-hot guard case in test-hot-db-assertions.nix (existing rows, 19-43 §c.4).
18. Daemon-past-failing-hooks guard (existing TODO_LIST:724) — the §e.5 structural fix.
19. The 88-report unharvested-§f backlog + 49 pairing-drift WARNs (standing, separately queued).
20. ~10-04 23:50 prune verification (time-gated row, TODO_LIST:21) — fires in ~30 min from report time.
21. Root-space floor auto-prune trigger >90% (existing TODO_LIST:22).
22. IO admission for tq pool + parallel build slices (existing stability row) — the storm that governed this whole session is its 4th data point.
23. Thermal-pstate-guard deploy (existing [blocked:deploy] stability row).
24. nvme0n1p8 corruption-counter triage — owner answer or the read-only legs (NEW row, queued §a.5).
25. Commit-msg footer / multi-stamp compaction convention (existing TODO_LIST:43) — my 16 fresh stamps make it more timely.

## g) Questions I cannot answer myself

1. **nvme0n1p8 corruption counter (≈3.87e8, /data):** known dev-stats quirk (stale accumulation of the documented shrink damage) or new signal worth the triage legs? Asked at 19:43, still open — the queued row waits on this sentence.
2. **Flip-vs-prune policy:** when a row closes, should the closing session REMOVE the TODO_LIST one-liner immediately (strict header reading), or is the current rhythm (flip now, periodic prune pass) the accepted convention — in which case the header should be amended to say so?
3. **Post-freeze-15 nix policy:** my zero-nix-invocations stance this session was self-imposed from the freeze-15 autopsy. Do you want that as a standing rule for agent sessions while PSI is elevated (I can queue it as an enforcement-leg companion), or do you prefer to gate nix activity yourself per-window?

## Harvest log

§f NEW rows harvested at authoring on both surfaces (TODO_LIST + matching library): f.1 prune pass (pipeline), f.2 already-harvested earlier this session, f.3 shellcheck wrapper run + adoption (pipeline), f.4 selftest-exit convention + audit (pipeline), f.5 check-probe blessing/writer (storage), f.24 already queued §a.5. All other §f items are EXISTING open rows (cited by row number) — re-queuing would duplicate. §d incidents are fully contained in-tree; their only follow-ups are f.3/f.4 (the convention rows). Deliberately NOT harvested: the HaGeZi re-drift observation (covered by TODO_LIST:240), the IO-storm persistence note (covered by the IO-admission row f.22), §g questions (owner-gated by definition).
