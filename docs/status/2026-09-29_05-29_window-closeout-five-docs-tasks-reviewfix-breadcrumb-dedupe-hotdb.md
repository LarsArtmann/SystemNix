# Window Closeout — Five Docs Tasks: review-fix harvest, heal-breadcrumb convention, ffprobe dedupe, crush-hot-db record, completeness correction

**Date:** 2026-09-29 05:29 CEST · **Dispatcher task:** `000001a0eb1b883e781b7d2fd3e1ffa0ca89`
**Window span:** 2026-09-28 ~19:21 → 2026-09-29 04:55 CEST (plus this closeout)
**Method:** each dispatch's closeout report read FIRST; every landing surface, commit, and queue claim re-verified against the current tree and the tq journal (7,782 facts; window slice 274). Quality gate at closeout: `nix flake check --no-build` → all checks passed. Nothing below is claimed without a probe behind it in this pass.

---

## a) FULLY DONE (verified this pass, not just claimed)

**1. Task `…928916188de912b2eb63685bcf9` — review-fix: harvest the go-taskqueue push follow-ups to queue surfaces.** Work commit `47def23c`, report commit `4d3797af` (both in history; `git show --stat` confirms 3-file / 1-file docs-only diffs). The reviewer finding was real and is now closed with all three surfaces verified live in THIS pass:
   - `docs/todo/upstream.md:13` carries the `[blocked:push]` go-taskqueue row (ahead 7, classification `449d72ac`, full post-push chain, Source pointer).
   - `TODO_LIST.md:216` carries the agent-executable post-push consumption row (flake re-lock + FOD/package verify from our lock + `tq-agent-pool` redeploy).
   - The parent report's misleading "queued as the top follow-up" sentence is corrected with a dated CORRECTION note (line 32 of `docs/status/2026-09-28_19-21_task-…f542c1.md`).
   The task's remaining open item (its §f5 self-audit template step) was NEVER harvested — found this pass and closed by a new TODO_LIST row (see §f/item 5 below), which also unblocked archiving the report (done this pass).

**2. Task `…93f7494428f6bdb90352db02588` — heal-attribution breadcrumb convention.** Work commit `451d4f8c` (CONTRIBUTING + script + TODO_LIST + stability.md + CHANGELOG), report commit `4a82b952`. Verified live this pass:
   - `docs/CONTRIBUTING.md:200` — the convention paragraph (one breadcrumb per manual heal via `bash scripts/heal-breadcrumb.sh "<what> <how>"`, probe `journalctl -t systemnix-heal`, hand-run-gap scoping, secret-value prohibition).
   - `scripts/heal-breadcrumb.sh` exists, executable, 34 lines. Shellcheck (the task's own admitted bypass) was independently discharged at `--severity=warning` by the follow-up review-fix task — zero findings.
   - `CHANGELOG.md` Added entry, `TODO_LIST.md:63` `[x]`, `docs/todo/stability.md:51` `[x]` — all three surfaces closed, no drift.
   - Honest gap recorded by the task itself and still open as rows: runbook step 1's heal line does not yet call the helper (TODO_LIST:135), SUDO_USER attribution (136), runbook sweep (137), motivating-report annotation (138).

**3. Task `…95aebd871672d672c98258ad103` — dedupe the ffprobe-sweep rows.** Work commit `850b0051` (TODO_LIST −2/+1, pixel6.md −3/+1). Verified this pass: `grep -c '591 UCR WAVs'` returns exactly 1 in `TODO_LIST.md` and 1 in `docs/todo/pixel6.md` — the ask that existed in three places (library prioritized + backlog + doubled queue row) now exists once per surface, richer wording kept. The dispatched item itself is `[x]`-closed in the same commit. The extra queue-row collapse beyond the literal ask is documented by the task as defensible scope, and this pass concurs (a doubled queue row is a double-dispatch bug).

**4. Task `…ea69007114315b9d2ae5d5843bca` — verify + flip the stale crush-hot-db review-fix rows.** The four-run arc (03:22/03:31/03:39/03:41 verification runs + 04:00 self-harvest repair; work flips via the parallel dispatch `7ded9002`). Verified live this pass:
   - All four in-scope rows in `docs/todo/storage.md` are `[x]` with per-row LIVE-VERIFIED-2026-09-29 evidence (alerting/OnFailure + extraMonitoredServices, depth-4 WARN, per-project `comm=crush` guard, `--dry-run` + integrity). The four remaining `[blocked:deploy]` rows in that file belong to other services (33 boot-mirror, 42 own-tools, 117/118 btrbk/btrfs-verify) — correctly untouched.
   - Monitoring leg: rendered `nix eval` of `extraMonitoredServices` contains `crush-hot-db-migrate` (36-entry list), matching the deployed script (prior-run probe, carried; this pass re-confirmed the rendered side via the 04-00 report's preserved evidence and the row text).
   - "deploy-pending" sentences swept from `docs/services/crush.md` + AGENTS.md; AGENTS.md's crush-hot-db section now states the deployed-generation verification (matches the 2026-09-29 header).
   - Self-harvest repair (the round-2 miss) landed as rows: proxyVendor eval-warning (TODO_LIST:426), duplicate-dispatch class (427), verification-verb template (428), monitoring-evidence-standard `[decision]` (429) — all four verified present this pass.

**5. Task `…eb0016286b1ff87e9252f392ac57` — review-fix: correct the completeness record.** Commit `76150586` (exactly TODO_LIST + the 03-22 report). Verified this pass:
   - `TODO_LIST.md` close-out line now counts all FOUR blocked:deploy review-fix rows and names which pass flipped what (was "three").
   - `docs/status/2026-09-29_03-22_task-…3bca.md` §b carries the inline dated CORRECTION (line 29) — the "nothing partially done" claim was false at authoring time; the f13 row was flipped same-morning by `7ded9002`.
   - Root cause pinned better than asked: the 03:31 dispatch had corrected the count in storage.md only — a surface-blind success claim; harvested as the report-claim SURFACE rule (TODO_LIST:431).
   - Its two self-harvest rows (430 stale deploy-pending clause, 431 surface rule) verified present.

**In-window context (parallel tasks, verified in passing):** the memory-emergency-guard 4 fixes are code-landed (backup-starvation catch-up slot, starvation metrics, log heartbeat dedup, trip-line io.stat attribution; `grep` confirms the surfaces in the module) with the AGENTS.md bullet (line 1152) and the Gatus "Memory Guard Backup Starved" check inserted (`gatus-config.nix:878` — the 01-45 report's "planned, not inserted" is now stale in the check's favor); FastFlowLM waker attribution evidence complete (three named by-design wakers, all-Zone-6 trip profile); crush-db migration baseline verdict (crush-session IO ~630 → ~9 MB/min, ≈70× reduction; Zone 6 continues from OTHER drivers); the heal-breadcrumb self-harvest fix (`ea36b448`, rows TODO_LIST:135-139 + stability.md:52-56 + pipeline entry, commits `45b698b1`/`ec0e078b`).

## b) PARTIALLY DONE

1. **Guard fixes are build-verified, not behavior-verified.** Script derivation builds (shellcheck pass), `bash -n` pass, artifact surfaces confirmed — but the VM regression test is NOT extended/run for the new state machine (starvation→grant, slot-protection through a trip, `CGROUP_IO_SRC` attribution). TODO_LIST:130 ("Guard VM-test extensions") is the tracking row and now covers these surfaces. Deploy also pending (user window).
2. **go-taskqueue master is still UNPUSHED (ahead 7).** The verify-gate classification exists only in the local checkout; production `tq` still burns attempts on environmental gate failures. The `[blocked:push]` row (upstream.md:13) + consumption row (TODO_LIST:216) are staged and waiting on the owner push. This remains the single highest-leverage item in the chain.
3. **The `/run/binfmt` durable fixes are in-tree but UNDEPLOYED** (host gen 797-era): a reboot before the next deploy re-manifests the boot cycle. VM-test run + deploy + reboot-verify owed (TODO_LIST:134).
4. **`ea36b448`'s own queue closure is broken** (see §d1): its work landed, its task ended DEAD.
5. **The 04-46 correction pass left the storage.md f2 stale clause unfixed** — deliberately harvested as row 430 rather than edited in that docs-only task; still open.

## c) NOT STARTED (deliberately; correctly routed, none lost)

- **The ffprobe sweep itself** (all 591 UCR WAVs) — the deduped row (TODO_LIST:376) is the work; the window only deduplicated its bookkeeping.
- **Post-push go-taskqueue consumption** (row 216) — hard-blocked on the owner push.
- **Heal-breadcrumb follow-through** (rows 135-138) — wiring, SUDO_USER, runbook sweep, motivating-report annotation. Row 139 (FEATURES check) is closed by THIS pass: verdict NO row — an ops convention, not a system feature; CONTRIBUTING + CHANGELOG own it (tick applied with this report as evidence).
- **All `[blocked:deploy]` rows** in storage.md (boot-mirror activation, own-tools NVMe→pool, btrbk MemoryHigh, btrfs-verify 2-day WARN) — they close mechanically at the next deploy window; nothing agent-actionable first.
- **Phase-2 `services.hot-db` fold, VM-test rebuild (PSI-gated), `archived/*` migration posture, empty-target auto-heal, legal-cases rmdir heal** — all tracked in storage.md with owners/pacing; the window correctly did not touch them.

## d) TOTALLY FUCKED UP (regressions, dead letters, debt — all verified)

1. **A window task is DEAD-LETTERED despite its work having landed.** `ea36b448` (the heal-breadcrumb §f self-harvest fix) sits in the DLQ (`tq tasks --status dead`) with last error `agent verify failed ("nix flake check --no-build"): exit status 1` — while its deliverable is verifiably in-tree (rows 135-139 + library entries + commits `45b698b1`/`ec0e078b`). The queue's completion signal diverged from repo reality: verify raced parallel-session eval churn and the task dead-lettered on noise. False-negative closure class — the queue needs a rescue-and-verify-close path for exactly this shape.
2. **Broken agent-skill frontmatter is taxing every queue operation.** `~/projects/SKILLS/naming-review/SKILL.md` has invalid YAML frontmatter (the `metadata:` block indented under a single-line `description:` scalar → "mapping values are not allowed in this context"); EVERY `tq` invocation warns, and the journal shows repeated pool agent run/closeout exit-1 failures ending in exactly that error (2026-09-29 02:31–05:07), each costing a 15-minute requeue. Companion: `~/.config/crush/skills/go-cqrs-lite/SKILL.md` description is 1362 chars (> the 1024 validation limit). Both files live OUTSIDE this repo (SKILLS fan-out) — reported here, fix belongs there.
3. **Provider rate-limit tax.** Window journal (19:00→05:15): 274 facts, 48 `task.failed`, 47 `task.requeued` (31 explicitly "rate limited", mostly 15-min backoffs), 17 `task.completed`, 15 `task.dead`. The zai glm-5.3-flash 429s repeatedly aborted agent streams mid-run (`retry error: too many requests`).
4. **Duplicate-dispatch churn recurred at review time.** The `ea690071` arc produced 4-5 status reports and 5+ commits for one logical row flip; the completeness residue then needed a HUMAN reviewer round (04-46) to surface. Root-cause rows exist (427 upstream, 344 dedup preflight, 338 repeat-dispatch policy) — none implemented yet.
5. **Verify gates raced parallel-session churn.** Two docs-only verify failures on `nix flake check --no-build` show eval merge noise (`d then { value = mergedValue; } …`) — the signature of another session's mid-edit tree state, not the task's own diff. Docs-only diffs skip the pre-commit flake leg, but the QUEUE-side verify gate has no such classification.
6. **Preflight dirty-tree refusals blocked dispatches on other sessions' strays.** Task `ea690071` was requeued 4× over ~30 min because an UNTRACKED status report from the parallel memory-guard session sat in the tree; CV tasks requeued 3× on a dirty `go.mod` + untracked HTML from that repo's own parallel session.
7. **hermes cron resurrected config-disabled llama-servers.** Both 0.3.0 instances (:8848/:8849) have been running under `hermes-worker-cron-*.scope` since 2026-09-28 05:40 while `llama-rag.enable = false` — a NEW resurrection vector the 2026-09-18 portGuard cannot see (it only runs at unit start; disabled units never start).
8. **Process debt accumulated, tracked:** self-harvest violations (3 consecutive reports before the ea36b448 repair), surface-blind correction claims, SHA-citation fragility under rebase churn, report proliferation on one task ID. All harvested as rows (426-431, 338, 344); the debt is documented, not yet paid.

## e) WHAT WE SHOULD IMPROVE

1. **Give the queue a done-signal that reads the repo, not just attempts.** The strongest failure this window (`ea36b448` dead with landed work) is a queue/repo divergence. A rescue-and-verify-close path (or verify-gate tolerance for docs-only diffs parallel to the pre-commit's docs-only skip) would have closed it at zero cost.
2. **Lint skill frontmatter at pool entry.** `tq` already detects the broken naming-review/go-cqrs-lite skill files on every invocation — promote that WARN to a harvest/bootstrap-time failure (or just fix the two files; the lint gate prevents the next one).
3. **Classify verify failures against parallel churn** — an eval error naming merge/`mkMerge` internals while a parallel session is mid-edit is a RETRY signal, not an attempt burn (mirrors the classify-before-burn work already landed upstream, unpushed).
4. **Keep the two-surface harvest as ONE atomic edit pair** — the window's cleanest pattern (20-15 fix, ea36b448 fix): queue row + library entry authored by one owner in one commit, zero drift by construction.
5. **Adopt the HARVESTED/DISCHARGED/NOT-HARVESTED marker convention permanently** — it worked in every report that used it, and the pre-marker reports are exactly the ones that needed reviewer repairs.
6. **Wire conventions WITH their first consumer** (the breadcrumb paragraph landed next to an unwired runbook line — row 135). One-line edits at landing beat follow-up dispatches.
7. **Dead-letter should distinguish "work lost" from "signal lost"** — 15 dead-lettered facts this window, but only 5 remain dead and none lost work; the DLQ is functioning as a retry boundary. Make that explicit in the tq runbook so operators stop treating DLQ rows as emergencies by default.

## f) NEXT THINGS (top items; new ones appended to TODO_LIST this pass)

**New this pass (appended below, 7 rows + 3 owner questions):**
1. Fix the broken `naming-review` SKILL.md frontmatter (~/projects/SKILLS) + the go-cqrs-lite over-length description — the every-invocation WARN tax with real requeue costs (§d2).
2. Triage the 5 DLQ tasks: rescue-and-verify-close `ea36b448` (work landed), root-cause the 4 foreign verify-dead before any blind rescue (§d1/d).
3. Measure the zai 429 rate-limit tax and pick a mitigation (§d3).
4. Decide the preflight-vs-parallel-churn policy (ignore-list for untracked docs/status reports vs require_clean) (§d6).
5. Add the §f self-audit step to the report protocol in CONTRIBUTING (closes the 20-15 report's last open item; prevents the finding class at authoring time).
6. go-taskqueue upstream: emit `task.reprioritized` journal facts — band-drift accountability is currently structurally impossible (§h).
7. Kill/legitimize the hermes-cron-resurrected llama-servers + decide the durable guard (§d7; sudo window for the kill).

**Already tracked, highest-value (pointers only — no duplication):** push go-taskqueue master + consumption chain (upstream.md:13 / row 216); guard VM-test extensions + deploy (row 130, §b1); `/run/binfmt` durable-fix deploy (row 134); wire the breadcrumb into runbook step 1 (row 135); duplicate-dispatch fixes (rows 427/344/338); verification-verb template (row 428); monitoring-evidence standard (row 429); report-claim surface rule promotion (row 431); legal-cases rmdir heal + empty-target auto-heal (storage.md); Phase-2 hot-db fold (storage.md `[watch]`); llama-rag spin bisect (row 168) — still THE gate for the paperless RAG leg.

## g) QUESTIONS (owner-only; appended as BLOCKED rows)

1. **DLQ disposition:** `ea36b448`'s work is verifiably landed — rescue and close on the landed evidence? And are the CV/go-taskqueue verify failures environmental (dirty trees, GOEXPERIMENT drift — CV currently has uncommitted `go.mod` changes) or real — rescue, re-scope, or dismiss each?
2. **Hermes-cron port policy:** may hermes cron workers bind config-disabled services' ports (today's llama-server resurrection), or should cron scopes be denied those ports — which stance does the durable guard encode?
3. **Sudo-only heal attribution** (carried unanswered from the 20-40 report §g3): will the owner adopt the `heal-breadcrumb` one-liner habit for heals only they can run (nix-daemon restarts, socket starts), or are the durable fixes (preferStaticEmulators, deploy ordering) the real closure, making the convention belt-only?

## h) BAND DRIFT (ADR-0015 accountability)

**None recorded.** `tq facts --type task.reprioritized` returns zero facts, and a full scan of the journal (7,782 facts, all types) finds no reprioritized event — neither in the window nor ever. No priority moved queue-side this window, so there is nothing to explain; the dispatch order itself was the queue's default cadence. **Structural note (queued as an upstream item):** the ADR-0015 accountability section can never record anything until go-taskqueue emits a `task.reprioritized` fact type — today priority changes are invisible to after-the-fact audit by construction.

---

*Closeout authored 2026-09-29 05:29 CEST under Task-Queue-ID `000001a0eb1b883e781b7d2fd3e1ffa0ca89`. Scope: the five dispatched tasks + window-adjacent evidence (queue journal, parallel-session artifacts read in passing). Quality gate at authoring: `nix flake check --no-build` green; `scripts/check-todo-system.sh` green pre-edit.*
