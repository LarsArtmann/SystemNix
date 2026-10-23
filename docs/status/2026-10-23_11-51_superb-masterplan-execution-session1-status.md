# SUPERB Masterplan — Execution Session 1 Status (self-review + full inventory)

**Session window:** 2026-10-23 ~11:20 → 11:51 CEST · **Instance:** `superb-masterplan-exec-1` · **HEAD at close:** `f5330fb1a`
**Plan:** `docs/planning/2026-10-23_09-53_SUPERB-backlog-masterplan.md` (1,042 sprints / 1,752 rows at authoring 09:53)
**Context at close:** tree has a FOREIGN eval-red blocker (forgejo-runner assertion — see §b/§g); IO PSI some avg300 ≈ 68 % all session; 8 concurrent crush sessions live; census moved 1,752 → 1,757 (parallel lock-wave session +8 new rows, this session −3 closed).

---

## a) FULLY DONE

1. **Baseline + twin-executor guard** — census grep == 1,752 == plan count (no drift at start); no EXECUTING marker existed on the plan; HEAD `58bc5522e` clean.
2. **Plan-marker protocol executed** — header conformance fix (`**Authored:**` → `**Created:**`, the script's anchor), `scripts/plan-marker.sh … start superb-masterplan-exec-1` stamped + committed immediately (`423a6c49c`, hooks green).
3. **U1 (deploy train) feasibility verdict — IO-GATE-BLOCKED, evidence-backed** — /proc/pressure/io some avg10 54.6 / avg60 59.7 / avg300 68.6 %, load 24.5; `sudo` is guard-blocked for agent shells; storm attribution (read-only): 8 concurrent crush sessions + a D-state `find` sweep + clickhouse + `buf` — multi-agent IO load, NOT a disk fault. A deploy train in this window is the documented freeze class; verdict recorded before pivoting.
4. **Sprint T-001 (monitoring:127) — tmp-orphan sweep now emits its crash-count signal** — `storage-collector-crash-orphan-sweep` pre-start script in `modules/nixos/services/storage-collector.nix`: counts `.state.json.*.tmp` orphans, journals each file name, atomically publishes `storage_collector_crash_orphans_total <count> <epoch>` to a dedicated `storage-collector-crash-orphans.prom` (mktemp + chmod 0644 + trap + rename under the sticky-1777/CAP_FOWNER doctrine), THEN deletes. Best-effort `-` prefix preserved. **Full verification battery:** functional fixture test (2 orphans → journaled + gauge 2 + 0644 + zero leftovers), shellcheck clean, `audit-textfile-tmp.sh` fail=0, targeted eval render of ExecStartPre, deadnix + statix clean (the daemon-bypassed pre-commit legs re-run standalone per the daemon-swept rule). Library row + TODO_LIST mirror + CHANGELOG entry all ticked. Deploy-gated to go live; gauge first appears at the next daemon start.
5. **Sprint T-029 (stability:102) — closed as already-satisfied with evidence** — the freeze list in `docs/agents/stability.md` has carried the full Freeze #7 scrub-restart-loop entry since 2026-10-01 (mechanism, `f21be80a` fix, PROVEN-across-four-boots note); the owner-confirmation condition the row waited on is already recorded in-tree. Closed with the correction-claim discipline (surface + evidence named).
6. **Sprint T-033 (stability:126, full extended scope) — the freeze taxonomy completed** — all 22 missing entries authored into `docs/agents/stability.md`: #8 (thermal-trip new class), #9 + #10-attempt, #11 (thermal series recovered via samples_v4 fingerprint scan), #12 (thermal-leading verdict + standing-deficit live finding), #13–#15, #16+#17 (mitigation-live family), #18, #19 (rust-cache migration rsync trigger, pure-IO 748.97/96.78/0.51 signature), #20 (zero-thermal mixed CPU+IO signature), #21, #22 (deploy validation ungated terminal), #23+#24, #25, #26 (muzzle-vs-fired third angle + the fleet-sweep/PTY incident), #27, #29 (thermally-unsampled death window), #30 (owner-manual balance attribution via sudo-journal COMMAND lines). Each entry: class discriminator, driver attribution, guard trip ranges, forensics report pointer — **authored from the source autopsy reports (verdicts re-read this session), not just the row drafts**. Sequence #4→#30 verified contiguous; every cited forensics path ls-verified to exist. Library row + TODO_LIST mirror + CHANGELOG ticked; commit `f5330fb1a` hooks-green.
7. **Foreign blocker root-caused (not touched)** — the 07:09 lock wave broke `nix flake check` in FOUR places; the parallel lock-wave session already fixed crowdsec + monitor365 legs (daemon-swept 11:31/11:34); ONLY `services.forgejo-runner.instances.evo-x2.settings.server.connections requires at least one connection` remains. Read the locked nixpkgs module: the assertion has NO mute hatch, and every naive fix (static connections entry, token_url via LoadCredential) breaks the repo's deliberate `.runner`-legacy flow (gen-runner-token ExecStartPre writes the token INSIDE the start — the documented 2026-10-16 start-limit class). Correctly left to the owning session (twin-executor rule); flagged to owner (§g Q1).

## b) PARTIALLY DONE

1. **T-001 landing protocol** — content verified green in HEAD, but the plan §9 "one footer-bearing commit" protocol was NOT met: the content split across daemon heuristic batches (`30e51805a`/`ad6f6d2b2`, then `745bea50e`/`f5330fb1a`) because my hook-gated commits were blocked twice (first my own fixed-tmp bug, then the foreign eval-red). Amend-forward is FORBIDDEN here — the batches carry foreign files (crowdsec.nix, deploy.sh). Mitigation executed: standalone lint re-runs + HEAD-content verification of all four surfaces.
2. **U1** — assessed with evidence (IO-blocked), not executed; additionally now gated on the forgejo-runner fix (deploys run the eval battery). The plan's 1 %→51 % Pareto head is therefore double-blocked (storm + tree-red).
3. **Plan progress** — 3 of 1,042 sprints (T-001, T-029, T-033); P0 lane 3 of 54; the entire `.nix` sprint lane is blocked by the foreign eval-red; docs-only lane proven green (two hooks-green docs commits during the red tree).

## c) NOT STARTED

- **T-002** (ai-stack:38 llama-chat start budget) — designated first `.nix` sprint once the tree greens; never started (would sit unverifiable while eval-red).
- **T-003..T-054** — remaining P0 sprints (several are journal-read-only and COULD have run docs/read-wise; pivoted to the two highest-value doc sprints instead under time+storm constraints).
- **U2–U5** — owner-gated by definition (reboots, sudo batch, push session, decisions).
- **The forgejo-runner migration row** — deliberately not taken (owning session's active surface).

## d) TOTALLY FUCKED UP (caught + fixed in-session, but honest)

1. **First T-001 commit shipped a fixed-tmp write** (`tmp="$promFile.$$.tmp"`) — violating the sticky-dir collision doctrine documented IN THE SAME MODULE FILE. Caught by the house `audit-textfile-tmp.sh` class A pre-commit leg (the prevention layer working exactly as designed); fixed to mktemp+0644+trap the same session. Lesson: internalize the textfile write pattern BEFORE authoring, not via the gate.
2. **The stability:126 row tick CORRUPTED the row** — prefix-only `edit` match on a 9.8 KB one-line TODO row left the entire old draft dangling after my DONE text. Caught by post-edit inspection, truncated with sed within one tool call. **New gotcha class for this repo: one-line TODO rows must be matched FULL-LINE (or sed-truncated), never prefix-matched** — harvested below (§f.12).
3. **The `rg -rn` replace-flag trap hit TWICE** (mangled displays: "audit-n.sh", "n audit") — the EXACT trap AGENTS.md Session Discipline documented this same morning. Zero damage (caught both times, re-ran with `rg -n`), but tripping a same-day documented rule is unacceptable flag hygiene.
4. **Lost two daemon-commit races** — both sprint landings rode heuristic daemon batches instead of my properly-messaged commits. Partly circumstance (hook-blocked retries), partly a too-wide edit→commit window on the second one.

## e) WHAT WE SHOULD IMPROVE

1. **One-line-row edit discipline** — full-line match or sed; prefix edits corrupt (§d.2). Should land in AGENTS.md/CONTRIBUTING as a rule.
2. **rg flag hygiene** — `-r` is REPLACE. Personal enforcement: never type `-rn`; if output shows implausibly short identifiers, suspect your own flags (already policy — this session proves it needs muscle memory, not just documentation).
3. **Daemon-race window for docs commits** — between final edit and pathspec commit there is a minutes-wide race (8 concurrent sessions, ~10 min daemon cadence). Countermeasure available TODAY: commit per-surface immediately after each file edit (smaller race surface); structural fix (daemon claim-file) is an owner decision.
4. **`.nix` sprints only on a green tree** — parked `.nix` edits invite unverifiable daemon sweeps. This session's docs-only pivot worked; formalize it as the standing play for foreign eval-red windows.
5. **Partial-eval green is NOT green** — both this session and (likely) the lock-wave session hit the same trap: targeted `nix eval` of one option does NOT force `config.assertions`; only toplevel/flake check does. Any "eval-verified" claim on a migration should name WHICH eval ran. (Candidate CONTRIBUTING/AGENTS.md line; related: the lock-wave session's own queued "Eval gate on lock floats" row.)
6. **Plan S-IDs are line-based and will drift** as rows close (census already 1,757 ≠ 1,752 with +8 parallel adds). The plan needs an explicit maintenance stance (regenerate per session vs authoring-time snapshot) — owner question, not mine to decide.
7. **Census re-baseline per execution session** — cheap (one grep) and keeps the plan's completeness assertion honest.

## f) Next up to 50 (grounded in THIS session; the plan's full queue is §6 of the plan itself)

1. **Forgejo-runner connections assertion fix** — THE single tree-green unblocker (every `.nix` commit + every deploy). Owner steers ownership (§g Q1).
2. **Eval gate on lock floats** (already queued by the lock-wave session, pipeline.md) — prevents today's 4-place breakage class from recurring.
3. **T-002** llama-chat start budget — first `.nix` sprint post-green.
4. **Post-deploy verify leg for T-001** — first daemon start must emit `storage_collector_crash_orphans_total`; journal line + .prom presence check (rides the next deploy battery).
5. **U1 deploy train** at the next PSI-calm + tree-green window (`--keep-going` first per Critical Rules).
6. **T-004** storm-night btrbk send verification (journal reads; root prom legs are owner).
7. **T-005** memcg OOM textfile collector.
8. **T-008** gatus boot/restart alert-storm + flap suppression.
9. **T-009** secret-history scanner canary allowlist.
10. **T-003** flm crash-trigger composite alert (SigNoz rule — eval-affected, post-green).
11. **Census re-baseline** + plan §7 regeneration-or-snapshot decision (§g Q3).
12. **AGENTS.md: one-line-row prefix-edit gotcha** (§e.1 — harvested to pipeline.md this session, AGENTS.md line lands when the owning session next touches it to avoid another shared-file race).
13. **AGENTS.md/CONTRIBUTING: daemon-race docs-commit pattern** — per-surface immediate commits as the race countermeasure (harvested this session, same deferral).
14. **monitor365 meta.mainProgram** (queued by the parallel session; kills the recurring getExe warning seen in every flake-check log this session).
15. **Verify the lock-wave session knows its crowdsec.nix/deploy.sh work was daemon-committed** at 11:34 out from under it (shared-tree attribution flag per AGENTS.md).
16. **TODO_LIST harvest pass**: 3 new `[x]` rows (1405, 324, + the freeze-#7 one had no queue row) to prune into CHANGELOG at the next pass.
17. **T-032 sev1 chronic-latch design** should consume the now-documented muzzle-vs-fired three-angle proof (#24/#25/#26 entries) as input evidence.
18. **Plan §9 protocol amendment** (owner-gated): daemon-batched landing + standalone-lint verification as the sanctioned fallback when amend is forbidden.
19. **T-006/T-007** pre-crash heat attribution + truncated-journal corroboration (post-green; SigNoz-side).
20. **T-011..T-014** pipeline P0 rows (post-green; eval-gate adjacent).

*(Remaining 1,000+ sprints live in the plan's §6/§7 — not restated here; this list is only what THIS session surfaced or advanced.)*

## g) Questions (cannot determine from inside the session)

1. **Is the lock-wave session still alive and on the forgejo-runner migration row?** The tree's ONLY eval-red is that assertion; it blocks every `.nix` commit and every deploy (U1). If that session ended believing its partial evals were green, the row is orphaned — may I dispatch it next session? (I cannot map the 8 live crush PIDs to row ownership; /proc forensics gives cwd/start-time, not intent.)
2. **Daemon-batched landings policy:** when verified content lands via heuristic daemon commits and amend is forbidden (foreign files in the batch), is the standalone-lint + HEAD-verification close-out sufficient (this session's approach), or do you want history surgery (rebase-split) on the unpushed batches?
3. **Plan maintenance stance:** regenerate the SUPERB masterplan after each execution session (S-IDs/line-refs drift; census 1,757 ≠ 1,752 already), or treat it as an authoring-time snapshot with the domain libraries as the only living index?

---

**Harvest note (per the self-harvest rule):** §f.12/§f.13 are landed in `docs/todo/pipeline.md` + TODO_LIST one-liners in this report's commit; §f.1/§f.2/§f.14 were ALREADY queued by the lock-wave session (not re-queued — no drift); §f.11/§f.18 are owner-gated by the questions above (deliberately not harvested as rows until answered).

**Marker:** flipped to EXECUTED for instance `superb-masterplan-exec-1` in this commit; the next execution session re-stamps `start`.
