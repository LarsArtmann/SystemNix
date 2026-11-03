# SUPERB v3 exec-1 — eight-sprint opening session status (tombstone + 5 closes + 2 landed-unticked)

**Instance:** superb-v3-exec-1 · **Window:** 2026-11-03 17:33–19:15 CET · **HEAD at start:** `7241d5d7b` · **HEAD at report:** `1525096df` (daemon) · **Plan:** `docs/planning/2026-11-03_17-10_SUPERB-backlog-masterplan-v3.md` (marker committed `4d2b5d77e`)
**Census:** 2,091 at tombstone → **2,100** at report (my split +5 net; parallel sessions appended freeze #41–#44 registrations and more — drift is the documented condition, not an error).

## Verification basis

| Claim | Evidence | Result |
| --- | --- | --- |
| Tombstone live | `git log --oneline --grep tombstone` → `4d2b5d77e` | committed before any row work |
| io-PSI probes work | live probe runs ×2 | attributed a LIVE transient storm in one pass (fish pid 247 MB/s, PSI some avg10 97.5 → drained minutes later); caught that the pid-join needs lexicographic `sort -k1,1` |
| Scanner noise gone | full-history scan after rewrite | 1,400+ HIT lines → 224 (198 ctx7sk + 1 AIza + 5 gsk_ + 20 syn_cb0b — all real-leak classes), 8 visible allowlist skips, 0 sk-00000 phantoms |
| Scanner selftest | `nix build .#checks.x86_64-linux.secret-history-scanner-selftest` | green ×2; mutation (de-anchored `sk-`) trips the L2 regression leg |
| gitleaks selftest | `nix build .#checks.x86_64-linux.gitleaks-coverage-selftest` | green; mutations (any-ULID allowlist; useDefault=false) fail loudly |
| crash-triage S-0025 legs | `bash scripts/test-crash-triage.sh` + nix check + live `--boots 4` | PASS; live verdict block: "abrupt=3 clean=0 running=1 — all abrupt boots have branch proposals + evidence" |
| shellcheck | severity=warning on all touched scripts | clean |

## a) FULLY DONE

1. **Tombstone + census re-baseline** — plan header carries EXECUTING marker (committed `4d2b5d77e`, commit-msg hook took the eval-skip branch: "Eval-irrelevant staged diff … skipping").
2. **S-0035 io-PSI storm-attribution probe set codified** into `docs/agents/stability.md` (new section + index entry): `/proc/pressure/io` brackets, two-snapshot `/proc/*/io` **fixed-key join(1) on pid** (never `paste`), cgroup `io.stat` by-KEY parsing, diskstats wedging cross-check, redact-argv rule. Ticked on stability lib row + queue mirror + CHANGELOG. The codification itself fixed the probe (lexicographic sort) and live-proved it.
3. **S-0001 secret-history scanner** — root cause of the "1,194 fixture blobs" was a REGEX BUG (unanchored `sk-` matching `task-<tq-id>.md` filenames), not fixtures: all token prefixes now `\b`-anchored; value-DIGEST allowlist (4 values incl. `re_bzp5m…`, census-adjudicated REAL-but-auto-revoked-by-Resend 2026-08-18); blob-sha allowlist (3 qcow2 throwaway-VM PEMs + own slack fixture — PEM header is generic, only blob-level allowlisting is sound); visible SKIP accounting; **CI deliberately stays red on the 4 real-leak classes** (rotation = security.md owner row). 6-leg selftest `checks.secret-history-scanner-selftest` + mutation negative. Ticked on pipeline lib row + queue mirror + CHANGELOG.
4. **S-0004 ULID FP fixture pair** — `negative-user-id-allowed-ulid.txt` (literal-allowlisted, expect_clean) + `positive-user-id-novel-ulid.txt` (@ULID26@, Crockford-base32 entropy 4.36, expect_detect): pins allowlist-REGION semantics; mutation (any-ULID regex) fails loudly (first via the square leg — a 26-char class also masks hex captures; literal-only vindicated). Ticked on pipeline lib row + queue mirror + CHANGELOG.
5. **S-0007 slack coverage pinned, premise CORRECTED** — pinned defaults DO carry `slack-bot-token` (live-verified bare + keyword contexts; the row's "invisible repo-side" holds only for low-entropy bodies). Fix that landed: `positive-slack.txt` + expect_detect leg pinning extend.useDefault; mutation useDefault=false fails. No custom rule (would race the default). Ticked on security lib row + CHANGELOG (no queue mirror existed).
6. **S-0019 bundled row split** into **7 atomic rows** (stability lib + 7 queue one-liners): nix-gc/btrbk admission, smartd liveness+by-id trap note, psi_episodes alert condition, is-active-vs-oneshot eval lint, crash2 ×3. Every sub-ask premise-checked STILL-OPEN at split time. Split rows ticked on both surfaces; checker green.
7. **Slack-fixture/parallel-session conflict resolved** — my fixture's fixed numerics tripped the pre-commit hook on a daemon sweep (parallel session wedge-fixed via a `.gitleaks.toml` allowlist entry, `17f14463b`), which in turn silenced my detect leg; resolved by rewriting the numerics inside the selftest's template expansion (tracked fixture stays hook-safe, scanned copy stays detectable). Selftest green again after.

## b) PARTIALLY DONE

1. **S-0024 (discriminator fork)** — verified SATISFIED by the existing 2026-10-28 "Crash Autopsy — Family Discriminator" section (three-way fork + census table superset of the ask). **Row tick + queue mirror still owed** (one edit each).
2. **S-0025 (crash-autopsy.sh)** — the WORK landed (see c) but **row tick + queue mirror + CHANGELOG owed**; also no standalone crash-autopsy.sh was created — the ask was satisfied by EXTENDING `scripts/crash-triage.sh` (3 census legs: hung_task/btrfs_warn/kthermal + verdict block naming open discriminators, running-boot never paged) — the row text should record that design decision.
3. **Negative-test harness** — my gitleaks-related legs green; the harness TOTALS are currently poisoned by a pre-existing tree-level blocker: `dead-guard-lint` (and other pristine-copy controls) fail to build on **"flake.lock lock-float audit failed (revs drifted from flake/expected-locks.nix)"** — last full run read 31 passed/45 failed with most failures being that single blocker fanning out (NOT my change; I never touched flake.lock/expected-locks.nix; tracked under the upstream rollback-tenure/four-rev-pins rows).
4. **P0 sprint block**: 8 of the 42 P0 leads addressed (S-0001, S-0004, S-0007, S-0019, S-0024✓, S-0025✓, S-0035 + tombstone); 34 remain (see §f).

## c) BLOCKED / NOT STARTED

- Not started: S-0002 (sops manifest check-mode), S-0006 (sops-nix-age-key ghost), S-0023 (thermal driver), S-0034 (boot cadence), S-0038 (shadow-split guard), S-0029–S-0032 (autopsies), S-0003/S-0005/S-0008–S-0018/S-0020–S-0022/S-0026–S-0028/S-0033/S-0036/S-0037/S-0039–S-0042, the whole P1–P3 tail, all 751 gated rows.
- Owner-gated P0s untouched (S-1349 key rotation, S-1370 /data ruling, S-1361, S-1355, …) — batch owner review still owed by the plan's §8 lane.

## d) TOTALLY FUCKED UP (self-review, honest)

1. **My slack fixture wedged OTHER sessions' commits** — the tracked template's fixed numeric prefix is a captured region; the pre-commit hook tripped on the daemon's own sweep and a parallel session had to hotfix it with an allowlist entry, which then SILENCED my own detect leg (caught on the negative-test controls leg 30 min later). Lesson: run the repo gitleaks config against the TRACKED form of any new fixture BEFORE landing it (harvested below).
2. **Two wrong selftest expectations written before deriving them from fixture semantics** (abrupt=3 clean=1; bootA THIN-CENSUS) — the selftest rejected MY assertions twice; both were my misreads of the branch ladder (trips≥5 → "B livelock", not thin). Cost: 2 round trips that a 30-second re-derivation would have saved.
3. **Near-miss: wrong root-cause theory on sk-00000** — I first planned a 140-digest allowlist for "fixture variants"; context inspection (one grep of the matched text) revealed the task-ID filename regex bug. The census-first pattern saved the fix shape; institutionalize it.
4. **Vacuous-test near-miss**: first ULID derivation used a hex alphabet → entropy 3.14, under generic-api-key's 3.5 gate → the "novel ULID must trip" fixture would have passed vacuously clean; caught only because I tested the novel fixture explicitly and its cleanliness was suspicious.
5. Mechanical sloppiness fixed on sight: `\\\n` escaping bug in the stability.md code block; a CHANGELOG edit that clipped the io-PSI entry's title (repaired same minute); a nonsense bash ternary line in crash-triage.sh (caught in review before any run); an `nprintf` typo.
6. **Close-out discipline slip**: S-0024/S-0025 work landed but ticks/CHANGELOG batched "for later" — exactly the anti-pattern the correction-claim rule warns about (a reviewer reading the libraries would see open rows for landed work). Owed first thing next session.
7. Redundant work: three full ~2-min history-scanner walks where one cached run + targeted greps would do.
8. Harness totals reported without isolating my legs under parallel churn — the 31/45 number is misleading without the lock-float blocker context (this report §b.3 corrects it).

## e) IMPROVE ANSWERS

1. **First thought wrong (kept mouth shut? No — evidence overrode):** the slack-row premise. I accepted "no slack rule repo-side" from the row; my FIRST empirical test (low-entropy token) CONFIRMED the wrong premise, and only the realistic-entropy test exposed the default rule. Rule: premise-check with REALISTIC data, not any data matching the shape.
2. **2/10 max**: 2 verified premise-corrections (scanner root cause, slack rule existence) + 2 mutation-negatives + 6-leg selftest + live proofs; minus the fixture-wedge I caused and the batched close-outs.
3. **What I'd do differently**: census/context FIRST on any "allowlist N things" ask; derive assertions from fixtures before writing them; hook-check tracked fixtures; tick rows the moment their verification lands.
4. **Missing from thinking**: the fixture I add becomes INPUT to other gates (hook, scanner history walk) the moment it's tracked — blast radius thinking for test data.
5. **Confidence calibration**: high on the five closes (each live-proven + selftest-pinned); medium on the split rows' priorities (keyword-classified per plan; premise-checked open/closed only).

## f) NEXT (direct follow-ups; items 1–2 are this session's owed close-outs)

1. Tick S-0024 row + queue mirror (verified-satisfied close, evidence in this report §b.1).
2. Tick S-0025 row + queue mirror + CHANGELOG entries for S-0019/S-0024/S-0025 (work is landed and green; §b.2).
3. S-0002: sops manifest check-mode leg in pre-deploy-check (H2, highest prevention value left in the P0 block).
4. S-0006: settle the `/run/secrets/sops-nix-age-key` ghost (live probe + settle/delete).
5. S-0034: crash-class boot cadence quantification (journal; feeds S-0023).
6. S-0023: 06:00–09:00 thermal driver — historical journal analysis across ≥5 mornings (the 1% row; the new crash-triage censuses feed it).
7. S-0038: hot-db shadow-split guard (eval-time).
8. S-0029–S-0032: autopsy rows — run `scripts/crash-triage.sh` per boot first (its new legs + verdict point the way).
9. The 7 split rows (nix-gc/btrbk admission gate; smartd gatus+by-id; psi_episodes rule; is-active-vs-oneshot lint; crash2 ×3).
10. Watch CI on the daemon-swept commits: FIRST run of `secret-history-scanner-selftest` + the reshaped `secret-history-scan` output (expect 224 red lines / 4 classes — if it shows sk-00000 lines, the \b fix regressed).
11. NEW (harvested): fixture-template pre-land hook-check — convention + optional negative-test leg that stages a new fixture and runs the repo gitleaks config against its TRACKED form (from the §d.1 lesson; TODO_LIST + pipeline.md rows added at authoring time).
12. dead-guard-lint / negative-test controls blocked by the lock-float drift (revs vs expected-locks.nix) — deliberately NOT harvested: already tracked (upstream rollback-tenure + four-rev-pins rows, upstream.md:221/:238).
13. Journal vacuum edge: 7.7G/8G at 19:0x — re-check before any journal-heavy task; all abrupt boots in window evidenced as of the live run (no action owed NOW).
14. S-0033 sustained-storm attribution using the codified probe set (P0, stability).
15. S-0013 monitor365 SQLite wedge (P0, services).
16. Owner-gated P0 batch review (33 rows) — the plan §8 unblocker lane.
17. Re-verify `gitleaks/negative-fixture-corrupt` leg in a quiet window (passed in the 68/8 run; confirm post-churn).
18. S-0037 ClickHouse→Samsung authoring leg (deploy-gated).
19. S-0041/S-0042 monitor365 upstream JWT-off-argv + SsoConfigRow logging (upstream repo work).
20. S-0003/S-0005 eval-guard + §18 CPU-leg follow-ups.

*(Items 3–20 are pre-existing plan/library rows — deliberately not re-harvested; only item 11 was new from this session.)*

## g) QUESTIONS (max 3)

1. **Key rotation timing (S-1349):** `ctx7sk-…` (documented "still LIVE"), `AIza…`/`gsk_…` (iTerm2 blob, purge never landed), `syn_cb0b…` (redacted in-tree only) keep the secret-history scan red BY DESIGN. Rotate now? This also decides whether the 2026-08-18 filter-repo purge should be re-run (the archive-dir copies survived it).
2. **Execution order:** continue the P0 sprint block straight (S-0002 next) or pivot to the storm/stability family (S-0023/S-0033 + autopsies) while the fresh probe doctrine is hot?
3. **Lock-float drift:** dead-guard-lint + negative-test controls are red on "revs drifted from expected-locks.nix". Hold for the rollback-tenure decision, or re-pin expected-locks now? (Blocks the nightly negative-test suite's controls legs.)

— superb-v3-exec-1, awaiting instructions
