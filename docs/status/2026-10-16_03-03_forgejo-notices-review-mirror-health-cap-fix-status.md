# Status — Forgejo system-notices review + dead-mirror collector capability fix

**Window:** 2026-10-16 ~02:20–03:03 CEST · **Host:** evo-x2 · **Branch:** master · **HEAD at authoring:** 084cb48e (+ working tree)
**Task:** "Review all forgejo system notices" → full `notice`-table review; the review surfaced a monitoring-plane bug which was root-caused and fixed in-tree.
**Daemon commits carrying this session's work:** `a022140d` (forgejo.nix fix; batched with a parallel session's files) · `084cb48e` (runbook + todo surfaces).
**Parallel session observed (NOT touched, per shared-tree rules):** `docs/services/crowdsec.md`, `scripts/bench-hot-file.sh`, `docs/planning/2026-10-16_02-38_pbx-traffic-into-geometrikks.md`, AGENTS.md edit + `docs/status/2026-10-16_02-26_offline-banner-*.md` (both rode `a022140d`).

---

## a) FULLY DONE

1. **Complete forgejo system-notices review — every row read and classified.** 102 rows total (2026-08-17 → 10-16), all Type=1 (mirror), zero Type=2 (admin). Four classes: (i) 22 rows Aug-17 empty-reason update-failure burst across 8 repos — self-healed, purge-safe; (ii) 1 row Aug-21 migrate credential-temp-file one-off; (iii) 3 transient blips (payment-automation HTTP2 09-24, watchssss connect-timeout 09-25, e-invoicing commit-graph rename 09-25); (iv) **76 rows ACTIVE: `lars/auto-deduplicate` PRUNE failures every ~2.5h since 09-24 20:15** ("could not read Password … terminal prompts disabled") — the only live generator. Evidence: read-only sudo-harness sqlite dump (`/tmp/forgejo-notices-*.sh`), full text review, per-repo/class counts cross-checked against `known-stale.txt` (34 lines; neither repo stale).
2. **The "notices table flood" premise answered.** The 09-18-era claim (~1.6k Type=1 rows/day from frozen mirrors, docs/todo/services.md:169) is OBSOLETE: the flood is gone (frozen mirrors resolved via reconcile). Live census: 102 rows, 28 KB table. Row 169 updated with the measurement (its own ask was "re-measure the live count").
3. **Dead-mirror collector bug root-caused and fixed in-tree.** `forgejo-mirror-health` ran as root with `harden{}` bounding `CAP_FOWNER` only; without `CAP_DAC_READ_SEARCH` root cannot traverse forgejo's 0700 StateDirectory → **every 5-min run since ship day 2026-09-18 (`e71362b4`) printed "DB not readable" + `forgejo_mirror_health_scrape_errors 1`** (journal-proven ≥ Oct 07; code-proven since birth). Fix: `CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_READ_SEARCH"` (forgejo.nix:673) — identical pair to `forgejo-subvol-backup-metrics` (forgejo.nix:970); `capability-grant-audit` does not apply (root acquires bounding caps; it only flags non-root units). Verified: rendered unit eval `CAP_FOWNER CAP_DAC_READ_SEARCH`; `nix flake check --no-build` all-pass. Commit `a022140d`.
4. **The e-invoicing prune-failure mystery closed.** Upstream `LarsArtmann/e-invoicing` was renamed → redirects to `ksef-sandbox` (gh-verified); reconcile deleted the stale mirror 10-11 (row gone from `repository`), and the canonical `ksef-sandbox` mirror exists + is **fresh (mirror_updated 2026-10-16 03:00:09)** — verified live this session (initially asserted in the runbook pre-verification; verification landed 3 min later, green).
5. **Docs + queue truth-sync across five surfaces, no drift:** runbook (`docs/services/forgejo.md` §dead-mirror: census, prune-class, collector finding + post-deploy verify recipe; stale "~1.6k/day" note replaced), library (`docs/todo/services.md`: 165 + 169 premise-updates; 3 new rows — `[blocked:deploy]` deploy-verify, `[ready]` prune diagnosis, `[ready]` prune-signal), queue (TODO_LIST 2 `[ready]` one-liners mirroring the library), CHANGELOG (`### Fixed` entry). Commit `084cb48e`.
6. **Shared-tree discipline held:** content-pin before every write (`git rev-parse` + status), daemon commits verified with `git show --stat` after landing mid-session, parallel session's dirty files identified, flagged, and left untouched.

## b) PARTIALLY DONE

1. **The cap fix is in-tree, not live.** The RUNNING system still executes the broken unit every 5 min until the next `nix run .#deploy`. Remaining: deploy + post-switch verify (no "not readable" journal line, `forgejo_mirror_health_scrape_errors 0`, Gatus "Forgejo Dead Mirror Candidates" green). Blocker: deploy timing is owner's call while a parallel session has in-flight tree work. Effort: S (queued `[blocked:deploy]`).
2. **The active notice generator is classified, not diagnosed.** auto-deduplicate's prune step fails while its fetch/update succeeds (mirror_updated fresh, upstream alive, pushed 10-15); 276 private mirrors, `enable_prune=1` fleet-wide, only this repo (+ the since-deleted e-invoicing stale) ever notice-failed, both first failing the same 09-24 ~20:15 window. Why prune loses the credential the fetch uses = open (needs deployed-forgejo source verification). Effort: M (queued `[ready]`).
3. **The prune failure class is still invisible to monitoring.** `forgejo_mirror_dead_candidates` greps UPDATE notices only; even after the cap fix lands, prune failures count zero. Extension queued (`forgejo_mirror_health_prune_candidates`), not started. Effort: M.
4. **Runbook truth-sync is partial.** The surfaces this review touched are current; the runbook's OTHER stale numbers (mirror counts 158→463-era, "32 upstream-deleted" vs 34 known-stale entries, audit-era counts) were left as-is — flagged for a dedicated pass (§f). Effort: M.

## c) NOT STARTED (planned this session, zero work done — all queued or listed in §f)

- Prune-credential diagnosis (queued `[ready]`).
- Prune-notice signal + Gatus anchor in the collector (queued `[ready]`).
- Deploy + live-verify of the cap fix (queued `[blocked:deploy]`).
- Purge of the 23 purge-safe August rows (folded into row 169 `[decision]`).
- Never-green detector (post-deploy assertion that newly shipped metrics reach green), alert-routing audit for the 4-week red, root-cap fleet sweep, runbook number sweep, notices census metric, permanent census script — all §f brainstorm, not queued yet.

## d) TOTALLY FUCKED UP

1. **The dead-mirror detector has NEVER worked — 28 days, ~8,000 failed runs, zero coverage.** `forgejo-mirror-health` shipped 2026-09-18 (`e71362b4`) with a capability set that made its own DB unreadable to itself. Severity: monitoring-plane blind — the exact failure class it was built to catch (the 12-day redirect-freeze mirrors) would have gone undetected all month. Root cause: `harden{}` + `CapabilityBoundingSet = "CAP_FOWNER"` dropped `CAP_DAC_READ_SEARCH`; root could not traverse forgejo's 0700 StateDirectory. Fix in-tree (`a022140d`), deploy pending. **The uglier half: nobody noticed for 4 weeks, and the 2026-10-11 02:17 status report read the red counter and attributed it to a "01:52 family-stop window, not recurring" — a false benign-verdict shipped into the permanent record** (report not annotated yet; ANNOTATE queued, §f item 14). A check that has never been green is not "one red cycle".
2. **A real, ongoing failure signal sat unreviewed for 22 days under a stale premise.** auto-deduplicate's prune failures (~10/day) were invisible three ways at once: the collector's grep is UPDATE-only; the notices table was presumed "flooded by frozen mirrors" so nobody looked (the flood had actually ended); and the one row asking for a re-measure (169) sat unanswered since 10-02. 22 days × ~10 rows = ~220 evidence rows of a live fault, zero human reads. The stale-premise survived at least one dispatch cycle — exactly the "wrong premise costs a full dispatch" class AGENTS.md warns about.
3. **A permanently-red Gatus check ("Forgejo Dead Mirror Candidates") raised no human response for weeks.** Whether the red never paged anyone (routing gap for registry checks) or pages were absorbed (alert fatigue) is uninvestigated — both answers are bad. Unresolved; §f item 5.

## e) WHAT WE SHOULD IMPROVE

1. **"Never-green" must be a distinct alarm state.** scrape_errors=1 forever looks identical in triage to a transient red. Concrete fix: post-deploy-check leg asserting every newly-shipped textfile metric reaches green (scrape_errors 0) within N minutes of a switch that carries it — mechanical, fixture-able (§f item 6).
2. **Quantitative premises in queue rows need re-measure stamps.** "~1.6k rows/day since 09-18" survived 6 weeks falsified. Convention: any row carrying a number carries a "re-measure by <date/trigger>" clause; the re-measure is one command when the method is recorded. My review only happened because the owner asked.
3. **Monitoring checks need a birth-time live probe ritual.** Shipped-inert is a valid state, but "shipped and assumed verified" is not: the 09-18 batch's runbook even predicted "one red cycle" — the prediction was never checked against reality, and the reality contradicted it silently.
4. **Root-run units are a capability-audit blind spot.** `capability-grant-audit` only flags non-root units; the root-acquires-bounding-caps property is exactly why `CAP_FOWNER`-only looked plausible. Sweep other root+harden units reading foreign 0700 data (§f item 23), and/or extend the audit to an inventory (not throw) for root DAC caps.
5. **Manual DB forays should graduate to a recorded recipe.** This session authored throwaway sudo-harness sqlite probes (the sanctioned pattern for agent-banned sudo); they live in /tmp and die at reboot. A `scripts/forgejo-notices-census.sh` (read-only, self-elevating, runbook-documented) makes the next review zero-authoring (§f items 20/43).
6. **Formatter runs must name their blast radius.** My `nix fmt . <path>` reported "formatted 16 files (1 changed)" without naming the file; I reconstructed the tree state manually (all accounted for: my edits daemon-committed, remainder is the parallel session's). Convention: after any formatter invocation, print `git diff --name-only` (§f item 49).
7. **Assert-then-write held this session — barely.** The ksef-sandbox "syncs clean" line went into the runbook before its verification query ran (green 3 minutes later, but the order was wrong). The verify-before-write order is the whole discipline; "it happened to be true" is luck, not compliance.

## f) Up to 50 things we should get done next

Legend: **[Q]** = already queued this session (TODO_LIST/docs/todo/services.md) — do not re-queue. Impact / Effort (S<30m, M 30m–2h, L>2h) / Category.

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Deploy the pending bundle carrying the mirror-health cap fix; post-switch verify scrape_errors 0 + Gatus green; stamp the `[blocked:deploy]` row **[Q]** | Critical | S | Bug |
| 2 | Diagnose why forgejo's PRUNE step loses the credential the fetch uses for `auto-deduplicate` (verify against the DEPLOYED forgejo source, v15.0.10) **[Q]** | High | M | Bug |
| 3 | Add `forgejo_mirror_health_prune_candidates` (prune-notice grep + known-stale subtraction + fixture legs + Gatus anchor) **[Q]** | High | M | Feature |
| 4 | Post-deploy-check leg: every textfile metric shipped by the deployed config must be present + scrape_errors 0 within N min of switch (the never-green detector; would have caught this bug on day one) | High | M | Quality |
| 5 | Audit why 4 weeks of red "Dead Mirror Candidates" never reached a human: routing for registry Gatus checks, Discord OnFailure coverage, alert-fatigue posture | High | M | Bug |
| 6 | Sweep ALL root+harden units reading foreign-owned 0700 data for the missing-`CAP_DAC_READ_SEARCH` trap (system-health census, storage collectors, geometrikks readability probe neighbors); fix or document each | High | M | Bug |
| 7 | Emit `forgejo_notices_rows{type}` census gauge (weekly timer) + Gatus growth anchor so the notices table is observable without DB forays | Medium | S | Feature |
| 8 | `scripts/forgejo-notices-census.sh`: permanent read-only self-elevating census (the /tmp harnesses, hardened) + runbook recipe | Medium | S | Cleanup |
| 9 | ANNOTATE the 2026-10-11 02:17 status report: its "one benign counter … not recurring" attribution is falsified (docs-health ANNOTATE mode, inline, non-destructive) | Medium | S | Documentation |
| 10 | Add per-repo dead-candidate gauge (`forgejo_mirror_dead_candidate{name=…}`) so triage needs no DB read | Medium | M | Feature |
| 11 | Emit `forgejo_mirror_health_last_run_timestamp` (freshness anchor; absent-metric = unit-dead class, mirrors the reconcile metric) | Medium | S | Feature |
| 12 | Gatus alert text: split scrape_errors=1 (collector broken) from dead_candidates>0 (mirrors dying) into different messages/responders | Medium | S | Quality |
| 13 | Journal archaeology: why did e-invoicing AND auto-deduplicate FIRST prune-fail the same 09-24 ~20:15 window (restart? config change? first stale-ref prune attempt?) — answers the blast-radius question for 276 private mirrors | Medium | M | Bug |
| 14 | Reconcile-delete residue check: did the e-invoicing mirror deletion leave orphaned on-disk `.git`/wiki/LFS dirs on the subvol? | Medium | S | Cleanup |
| 15 | Runbook number sweep: re-verify the audit-era counts still in forgejo.md (mirror totals, 32-vs-34 upstream-deleted, 158-era figures) — one truth-sync pass | Medium | M | Documentation |
| 16 | Tripwire: `checks.*-selftest` leg pinning mirror-health's bounding set (style of `nix-heavy-builds-gate-selftest`) so the cap can't silently regress | Medium | S | Quality |
| 17 | Auto-deduplicate decision tail: once diagnosed, choose enable_prune=0 (admin-API write, root token) vs upstream fix vs tolerate-stale-refs; document in runbook break-glass **[decision half queued]** | Medium | S | Decision |
| 18 | If upstream bug: search forgejo issues for the prune-credential pattern BEFORE filing (verify-before-filing), then github-voice the report with v15.0.10 source lines | Medium | M | Bug |
| 19 | Capture pre-deploy evidence: current red state of "Dead Mirror Candidates" on the dashboard (before/after pair for the fix close-out) | Medium | S | Documentation |
| 20 | Extend post-deploy §forgejo legs to read `forgejo_mirror_health.prom` (verify the leg is actually absent before wiring) | Medium | S | Quality |
| 21 | Purge the 23 purge-safe August rows (22 empty-reason + 1 migrate one-off) per the 169 decision — owner UI or sudo SQL, AFTER the prune diagnosis if the rows matter as evidence | Low | S | Cleanup |
| 22 | Probe `commit-graph.lock` on `auto-deduplicate.git`/`e-invoicing.git` (one-off row-27 class; runbook documents the forgejo-user cleanup) | Low | S | Cleanup |
| 23 | "Re-measure by" convention for quantitative premises: add to docs/CONTRIBUTING.md TODO contract (premise-check rule extension) | Medium | S | Documentation |
| 24 | Mirror-health + subvol-metrics share the textfile publish helper (duplication between the two writeShellApplications) | Low | M | Cleanup |
| 25 | Consider `BindReadOnlyPaths` of just the .db/-wal/-shm as a cap-free alternative design for the collector (drop DAC_READ_SEARCH need) if the cap is deemed too broad | Low | M | Quality |
| 26 | Wiki-notice policy: the collector `grep -v`s wiki notices — decide count-vs-ignore explicitly if wiki mirrors can fail independently | Low | S | Quality |
| 27 | Verify prune-message paths map onto the flat known-stale names (collector does `basename .git`; stale file is flat-named) before wiring item 3's subtraction | Low | S | Quality |
| 28 | Timer-ordering note: health runs every 5 min, reconcile hourly — the known-stale file's first-run absence window is fail-closed; confirm the Gatus text still explains it | Low | S | Quality |
| 29 | Pin down the journal-rotation boundary: is Oct 07 01:30 the collector's real journal start or a vacuum edge (`journalctl --list-boots` + vacuum audit)? Upgrades the "since ship day" claim from code-grade to journal-grade | Low | S | Documentation |
| 30 | Notices-table retention knob: declarative purge (admin-API script or vacuum timer) so the table never needs manual looks again | Low | M | Feature |
| 31 | Record the sudo-harness sqlite probe pattern in docs/agents/shell-devtools.md's verified live-probe set (sqlite3-not-in-PATH + agent-banned sudo handling) | Low | S | Documentation |
| 32 | CHANGELOG post-deploy truth-sync: add the generation number to the `### Fixed` entry once live | Low | S | Documentation |
| 33 | SigNoz crosscheck: do forgejo unit journals (mirror-health stderr) reach the logs explorer? "DB not readable" should have been searchable for 4 weeks | Low | S | Quality |
| 34 | Extend `capability-grant-audit` with a non-throwing root-unit DAC-cap inventory (documentation surface, no assertion) | Low | M | Quality |
| 35 | CONTRIBUTING contributor-style note: formatter invocations must be followed by `git diff --name-only` (names the blast radius; closes this session's fmt blind spot) | Low | S | Documentation |
| 36 | Re-stamp row 169's census with the next re-measure date (watch clause: re-census 2026-11 or next notices-touching change) | Low | S | Documentation |
| 37 | Zombie-mirror detector (services.md:456, still open): implement together with item 3 as ONE collector PR (same script, same fixture) | Medium | M | Feature |
| 38 | Verify the hourly re-interval phase's ~470 localhost GETs aren't drowning the forgejo journal (noise budget) | Low | S | Quality |
| 39 | After item 2's diagnosis: if per-mirror `enable_prune=0` wins, write the admin-API recipe into runbook break-glass (root-token env handling) | Low | S | Documentation |
| 40 | Fixture leg for prune notices (stub with prune rows → `prune_candidates 1`) inside `forgejo-scripts-fixture`, so item 3 ships tested | Low | S | Quality |
| 41 | Consider `forgejo_mirror_health_scrape_errors` reason labels (db-unreadable vs stale-file-missing vs sqlite-fail) — one metric, three causes today | Low | S | Quality |
| 42 | Runbook: document that Gatus Dead Mirror Candidates fails closed on absent metric AND what red-since-forever means (post-item-5) | Low | S | Documentation |
| 43 | Check whether the Aug-17 empty-reason burst (22 rows/2h, 8 repos) correlates with a known 08-17/18 event (the secrets-purge window) — closes the last unexplained notice cluster | Low | S | Documentation |
| 44 | Align `known-stale.txt` consumers: health greps flat names, reconcile publishes pairs — after item 3, confirm both read the same file shape sanely | Low | S | Quality |
| 45 | Post-deploy: watch one full sync cycle for NEW notice rows (should be auto-deduplicate prune only) — confirms the review's "only live generator" verdict holds | Medium | S | Bug |
| 46 | Fold the notices census into the periodic-look the runbook already recommends (replace "worth a periodic look" with the metric from item 7) | Low | S | Documentation |
| 47 | If item 13 shows the 09-24 window was a forgejo restart: check restart-safety of mirror credentials generally (other mirrors may be one restart from the same class) | Medium | M | Bug |
| 48 | Make the two `/tmp` harness scripts' queries part of item 8's script (counts by type, time window, per-repo rollup, known-stale cross-ref — the exact review shape) | Low | S | Cleanup |
| 49 | (consumed by 35) — formatter blast-radius convention | — | — | — |
| 50 | Queue-hygiene pass after items 1–3 close: prune the `[x]` rows to CHANGELOG per the TODO contract in the same pass | Low | S | Cleanup |

**Harvest note (binding):** items 1–3, 17(partial), 37, 45 are ALREADY queued (`[Q]`) — do not duplicate. Items 4–16, 19–20, 23, 35 are the §f follow-ups this report self-harvests as candidates: they are brainstorm-grade until a docs-health HARVEST pass routes them (TODO_LIST vs ROADMAP); none is queued yet at authoring time.

## g) Questions I can NOT answer myself

1. **Deploy timing:** the cap fix is committed and eval-green, but the tree also carries a parallel session's in-flight work (`crowdsec.md`, `bench-hot-file.sh`, planning doc). Do you want `nix run .#deploy` NOW (the fix sweeps up whatever the parallel session has on disk at switch time) or should I hold until that session quiesces?
2. **The 4 silent weeks:** did you receive ANY page/notification for Gatus "Forgejo Dead Mirror Candidates" between 09-18 and today — and if yes, did you dismiss it as known-red? (I can read the alert config, but whether pages reached you and were absorbed is unknowable to me; the answer decides whether item 5 is a routing bug or an alert-fatigue fix, and how aggressive item 4's never-green detector should be.)
3. **auto-deduplicate prune — tolerate or fix?** If the diagnosis confirms forgejo's prune step drops credentials for private mirrors: do you want (a) `enable_prune=0` on that one mirror via admin API (stale refs accumulate silently, noise gone), (b) an upstream forgejo investigation/file, or (c) leave everything as-is and just add the prune-signal monitoring?

---

*Method note: agent shells ban `sudo` at command-parse time; all live reads ran via throwaway bash harnesses (the sanctioned pattern) with `sqlite3 -readonly` against `/var/lib/forgejo/data/forgejo.db` (WAL). No writes touched the live forgejo DB. Report format: `.md` per explicit instruction in the dispatch prompt (HTML is the skill's canonical default — one-off override, flagged per spec).*
