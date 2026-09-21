# Window Closeout — Five Tasks: gate-review fix, hermes orphan, probe-user purge, hot-db module

**Date:** 2026-09-21 10:45 CEST · **Window:** 2026-09-19 ~00:30 → 2026-09-20 10:01 (queue completion timestamps) · **Reporter task:** `000001a0c0d6f497e2302edb9b49be5305bb` · **Tree at write:** `2325b329` (clean)

**The window's five queue tasks (all `completed` in the queue DB, verified via `tq show`):**

| Task | Item | Outcome |
| ---- | ---- | ------- |
| `000001a0b68a0aee…78bd6` | Review finding on the browser-history registration-gate close-out | **DONE** — fix `8b07ecc9`, report `a14a4984` (since archived with a RESOLVED banner) |
| `000001a0b6ca1ef7…9f8a09f` | Re-realize the orphaned `hermes-python-source` store path | **DONE (3 dispatches past closure)** — closure re-verified each time; store path still valid today |
| `000001a0b7a5db5c…86a1` | Delete browser-history probe user `probe-gate@example.com` | **BLOCKED at every dispatch (deploy-gated); the work itself EXECUTED 2026-09-20** via the shipped purge mechanism |
| `000001a0b7c158b0…7453` | Same item, second queue ID (dispatches 4–6) | Same — verification-only repeats |
| `000001a0bbb066…26a74a` | `services.hot-db` NixOS module (Phase 2 mechanism) | **LANDED + verified**, ships DORMANT; closeout report `067cbe97` |

Closeout reports read first, as instructed: `docs/status/archived/2026-09-19_00-59_task-…78bd6.md`, `2026-09-19_03-17_task-…9f8a09f.md`, `2026-09-19_05-28_task-…86a1.md`, `2026-09-19_06-28_task-…7453.md`, `2026-09-20_09-46_task-…26a74a.md`. Every claim below was re-verified against the live tree/host this pass unless cited otherwise.

---

## a) FULLY DONE (verified this pass, not just claimed)

1. **Browser-history registration-gate review fix (`8b07ecc9`).** The reviewer's finding ("live second-Pocket-ID rejection marked done on inference only") was fixed exactly as demanded: the closed-item text now states the OAuth2 live rejection is UNVERIFIED (inference, not measurement) and the user-run passkey ceremony is mirrored as a backlog entry. Verified live today: the mirrored user-gated item exists at `docs/todo/services.md:28` (post queue-split home), and the follow-up CORRECTED annotation on the original report (`2026-09-18_03-56` §a.4) landed too. Report archived with a docs-health RESOLVED banner. The underlying live-verification itself (probe 201 → count-gap discovery → gate proven in a scratch-run) remains correctly recorded as done-with-caveat in CHANGELOG.
2. **`hermes-python-source` store path healthy — item closed for good.** The orphaned `7g4gal5lh4zzgk41v2cax2rsjch7q4ym-hermes-python-source` dir self-healed (registered again) and the pre-commit flake leg went green; the queue then dispatched the SAME ID three more times anyway. Each dispatch re-verified instead of trusting: `nix path-info` rc=0, `nix store verify` clean, `nix flake check --no-build` green — re-confirmed once more this pass (`nix path-info` rc=0). The TODO row is pruned; CHANGELOG's 74-row prune entry records the closure. Six footer commits (`461fd135`…`38d3c0d5`) + three reports are the paper trail.
3. **The probe-user purge EXECUTED — the window's longest-running orbit is actually closed.** All five dispatched runs were deploy-gated (sudo/tool-policy walls) and could only verify preconditions. The declarative purge (`services.browser-history.probeRegistrationCleanup`, shipped by a parallel session at `2c2a860c` 2026-09-19 04:32) fired on the next privileged deploy: **journal line `browser-history-probe-registration-purge: purged probe registration for probe-gate@example.com` at 2026-09-20 11:33:55** (verified this pass), and the live server metric reads **0** users (pre-probe value holding). The agent-verifiable close-out criteria from the 04:57/05:52 handoffs are now met; the TODO row was pruned in the interim. (Residue: see d.3 — the self-neutralizing block still sits in-tree and the library entry is stale.)
4. **`services.hot-db` Phase-2 module landed, verified, and correctly dormant.** `modules/nixos/services/hot-db.nix` (per-service BTRFS subvol mounts from the Samsung `tlc` pool at each service dataDir, nodatacow opt-in, `hot-db-bootstrap` oneshot, btrbk landmine + path-validation eval assertions, anti-shadow consumer wiring), `scripts/migrate-hot-db.sh`, VM test + 8-case assertion test — all in-tree with the footer commit `c9dc44a6` and closeout `067cbe97`. The closeout's honest confession (footer missing from the lineage for ~5 h) was repaired by that same session. Follow-on sibling runs (2026-09-21 00:25 + 01:39, outside this window) fixed the landmine guard's blanket-`hot/` rejection, ran the fsync-pain measurement (9–13× gap, verdicts recorded), and re-verified landed state green at `79f89062`. evo-x2 runs it with `enable = false`, zero entries — by design.
5. **Queue-side bookkeeping for the window is clean.** All five tasks read `status=completed` via `tq show`; every dispatch carried its Task-Queue-ID footer (the probe orbit accumulated 8 footer commits across two IDs); every report landed at the dispatcher-specified path.

## b) PARTIALLY DONE

1. **hot-db Phase 2 is partial BY DESIGN:** mechanism shipped dormant; every actual migration wave (pocket-id → postgres → discordsync; docker data-root) is an owner sudo window. The `crush-hot-db` interim module is NOT yet folded in (documented debt; the 2026-09-21 10:35 session's per-project-guard upgrade is code-complete but deploy-pending behind the IO storm). The two hot-related VM tests are unrealized on the current tree (queued as TODO_LIST storage row "Rebuild `hot-db` + `crush-hot-db` VM tests green").
2. **The probe-purge close-out chain is half-consumed.** The deletion executed (a.3), but the 04:57-handoff's second half — "remove the `probeRegistrationCleanup` block (self-neutralizing debt)" — never ran: the option + script + fixture + configuration.nix wiring are still in-tree (`browser-history.nix:198/368-387`, `configuration.nix:519`), now dead code, and `docs/todo/services.md:21` still carries the item as `[blocked:user]` although nothing is blocked anymore (annotated this pass).
3. **The OAuth2 live rejection remains UNVERIFIED** (user passkey ceremony, `docs/todo/services.md:28`) — correctly qualified by the window's review fix, still open by design.
4. **The review-fix report's own §a.4-style residue:** none — the CORRECTED annotation landed. Nothing partial left in that orbit.

## c) NOT STARTED (window skipped, deliberately — canonical lists live in the cited reports)

- All standing fleet work was correctly untouched under the no-unrelated-research scope: llama.cpp spin bisect + real-unit soak (THE llama-rag re-enable gate), /data EIO corruption repair chain, offsite Borg leg, the owed reboot (flm :52626 corpse, D-state pile), Resend SPF/domain verification, crush-hot-db fold, hermes deploy items.
- Process fixes the window surfaced but did not implement (all already tracked): pre-commit loud-WARN for `path ... is not valid` (TODO_LIST pipeline row), queue done-filter/idempotency (TODO_LIST upstream row), dispatcher-side TODO reconciliation, human-capability tag at enqueue.
- The hot-db closeout's §f waves and T14 monitoring (partially harvested this pass — see the new TODO items).

## d) TOTALLY FUCKED UP (regressions, broken gates, dead-lettered work, debt)

1. **The queue re-dispatched closed/blocked work 8 times across the window's 5 tasks.** hermes orphan: 3 dispatches under one ID, each landing ~25 min after the previous closed it, past four footer commits + three reports + a pruned TODO row. Probe-user: 6 dispatches across two IDs against one S-sized privileged step, ignoring an explicit in-TODO suppression request ("suppress further pre-deploy dispatches"). Each repeat re-derived the same wall. The fix items exist (done-filter/idempotency, human-capability tag) but were not implemented — the window proves their priority. **Rough cost: ~5 agent-hours of verification-only repeats.**
2. **The queue↔git footer discipline failed for ~5 h on the hot-db lineage** (all engineering landed via daemon heuristic commits; no footer until the closeout session's `c9dc44a6`) — already confessed in the 09-46 report; tracked as a TODO row ("Queue-footer discipline: FIRST commit carries the footer").
3. **The purge-execution handoff rotted for 29 hours.** The 04:57 NEXT-VERIFIER instructions (journal line + count 0 → flip → remove block) fired on 2026-09-20 11:33 but nobody consumed them: the library entry still said `[blocked:user]`, the self-neutralizing block stayed in-tree, and no CHANGELOG line recorded the purge. Closed by this pass (annotation + CHANGELOG + new removal item), but the pattern — "self-neutralizing mechanisms need a named consumer" — recurs.
4. **A live monitoring regression emerged mid-window and is still red-prone: the browser-history `/health` 503-degraded class.** The upstream `AGENT_FRESHNESS` upgrade (deployed with the 2026-09-19/20 waves) makes the server answer 503 `degraded` whenever no agent ingest landed in 30 min — but the agent's runs find "no new visits to send" (all raw visits filtered), so freshness lapses every time the user steps away. Live this pass: `/health` 503 since ~2026-09-20 21:59 CEST (`lastIngestAt`, db ok) while the Gatus "Browser History" check demands `[STATUS] == 200` — a healthy box paging "server down". The queued post-deploy smoke ("poll browser-history /health") inherits the same false-FAIL. Needs a decision + fix (new TODO item).
5. **The browser-history user-count metric was silently RENAMED upstream** (`browser_history_user_count` → live `browser_history_users`, verified on `/metrics` this pass; the old name is gone). The queued Gatus-check item (`docs/todo/services.md:95`) and a `configuration.nix:511` comment still reference the dead name — landing the check as written would guarantee a permanent red/pattern-miss. Caught this pass; queued as a fix item.
6. **Daemon races hit three of the window's six report sessions** (the 03:06 hermes race, the 00:59 review-fix race, the 05:21 probe race) — each recovered by verify-then-amend, and the fifth dispatch PROVED the single-command pathspec commit prevents the race. The discipline is documented; compliance is still per-agent luck.

## e) WHAT WE SHOULD IMPROVE

1. **Stop dispatching at closed/blocked items mechanically:** the queue needs the done-filter + privileged-execution/human-capability flags implemented, not re-proposed — this window is the strongest evidence yet (8 wasted dispatches). Both items exist in TODO_LIST; they should jump the queue.
2. **Self-neutralizing mechanisms need a named consumer:** any one-shot cleanup shipped as "fires on next deploy" must also ship its close-out owner (a TODO row that survives past the mechanism, or a textfile gauge making execution observable). The purge rotted 29 h; the 226-era lessons rhyme.
3. **Intake protocol at the dispatch boundary:** every hermes dispatch re-learned "grep the footer commits + reports + fresh row read first". Encode it where tasks are handed out (dispatcher template / CONTRIBUTING intake paragraph), not in per-run reports that the next dispatch ignores.
4. **Re-verify naming premises against the LIVE surface before queueing monitoring work:** the metric rename made a queued item's premise stale within 48 h. The "queue intake freshness rule" row (TODO_LIST upstream) covers exactly this — same priority argument as e.1.
5. **Health-check semantics vs upstream health upgrades:** when an upstream binary gains a new health dimension (AGENT_FRESHNESS), sweep the Gatus checks + post-deploy smokes that probe that endpoint IN THE SAME CHANGE. The 503-degraded class was predictable from the upstream diff.
6. **Keep what worked:** verify-don't-trust held across every repeat dispatch (zero false-closes; two stale premises caught: the "always-red" flake leg and the "purge not yet executed" state); delta-only reports with canonical §f pointers reduced forking; the single-command pathspec commit is now twice-proven as the daemon-race cure.

## f) NEXT THINGS (harvested; the actionable ones are appended to TODO_LIST this pass)

1. Remove the self-neutralized `probeRegistrationCleanup` block (`configuration.nix:519`, option/script/fixture per the keep-or-rip answer) — unblocked by the executed purge; **appended**.
2. Fix the user-count metric-name drift (`browser_history_users` live) in `docs/todo/services.md:95` + `configuration.nix:511` BEFORE landing the Gatus check; **appended**.
3. Resolve the `/health` 503-degraded false-alarm class (Gatus condition vs upstream poll-counts-as-freshness) + sweep the post-deploy smoke that polls `/health`; **appended**.
4. T14 hot-db monitoring: `/mnt/hot` + per-entry mount-presence textfile metric (fail-closed) + Gatus checks — flagged un-queued by the 2026-09-21 01:39 sibling run; **appended**.
5. `migrate-hot-db.sh` stub-fixture test before its first user-run window (untested destructive script); **appended**.
6. Update the Phase-2 plan doc's T-task table with completion status so the plan stops lying; **appended**.
7. Nix `--json` deprecation sweep over scripts/docs call sites (carried from the hermes chain); **appended**.
8. Owner decisions (blocked items appended as questions): keep-or-rip the purge mechanism; repeat-dispatch report policy; the queue done-signal.
9. Everything else stays canonical in the domain libraries (storage waves, upstream count-gap + user-loss bugs, llama bisect, Borg offsite) — deliberately not forked here.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Keep or rip `probeRegistrationCleanup` after the executed purge (3rd ask):** does the option + script + fixture check stay as a reusable probe-cleanup pattern, or get ripped entirely (YAGNI; the fixture costs eval/build time forever)? Determines what the removal commit deletes.
2. **Repeat-dispatch report policy:** for verification-only repeat dispatches of unchanged state, is the convention "annotate the TODO/library entry only, full reports reserved for state changes"? Two runs re-litigated this; it should be encoded once (and would have saved the 06:04→06:28 report pair).
3. **Queue done-signal (3rd ask, now 8 dispatches of evidence):** what does the queue actually consume to mark a task done, and is the re-dispatch loop intended to terminate on something agents cannot see from inside the repo? The fix item (done-filter/idempotency) exists; the intended done-signal semantics are queue-side knowledge.

## h) BAND DRIFT (ADR-0015 accountability)

**None recorded.** The tq journal holds 18,737 facts and ZERO of type `task.reprioritized` (type inventory verified: claimed 2350, requeued 1558, failed 594, enqueued 381, completed 188, dead-lettered 188, released 8, cancelled 1). No priority moved through the journal in or before this window, so there is nothing to explain. (Side observation, not drift: `dead-lettered == completed == 188` — a 50% terminal-failure share worth a look in the go-taskqueue domain, out of scope here.)

---

*Point-in-time snapshot, 2026-09-21 10:45 CEST. Reporter commits carry `Task-Queue-ID: 000001a0c0d6f497e2302edb9b49be5305bb`. Window reports for the probe orbit and the hermes orbit were archived this pass (items fully done, unreferenced externally); this report cites their `archived/` paths.*
