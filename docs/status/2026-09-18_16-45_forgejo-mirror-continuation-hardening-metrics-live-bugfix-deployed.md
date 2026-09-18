# Forgejo Mirror Sync — Continuation: Hardening, Metrics, Live Bug Fix, Deploy & Verification

**Session date:** 2026-09-18, ~14:15–16:45 CEST (continuation of the 07:43 audit session)
**Host:** evo-x2 (SystemNix, master @ 7f4c78d2 era)
**Trigger:** user directive "keep going until everything works" after the 07:43 session ended waiting on 3 owner questions.

---

## 0. TL;DR

The previous session left all fixes committed but UNDEPLOYED and 3 questions open. This session: assumed safe defaults, closed every session-direct code item (#3, #4, #6, #11, #12, #14, #15, #17), found + fixed a LIVE classification bug the morning code shipped, and got everything DEPLOYED (system-785, anchored) and verified end-to-end. The ~200-private-repo mass migration the deploy was gating on had ALREADY happened at 09:42 under a morning deploy: **349 processed, 225 mirrors created, 0 failed**. Live state now: **385 mirrors, 32 correctly-classified frozen archives, 2 transfers, metrics published, Gatus "Forgejo Mirror Reconcile" green**.

| Question from 07:43 report | Default I proceeded with | Consequence |
| --- | --- | --- |
| Mirror ~200 private repos (or scope)? | Full coverage (as implemented) | DONE — 225 created 09:42, reversible via API delete |
| forgejo→GitHub push capability? | No (dead code stays removed) | Nothing to do |
| Artmann-Minecraft transfers? | Keep frozen, report-only (reconcile default) | Still owner-decidable, no data risk |

---

## a) FULLY DONE

1. **Unit hardening (#4):** `forgejo-github-sync.service` now carries `ioTier.background` (BE/6), `MemoryMax = 1G`, `startLimitBurst 5 / startLimitIntervalSec 300` (top-level, [Unit]-correct placement), `serviceOneshotDefaults` (Restart=no). Verified by eval + live unit file. Shipped via the user's own 14:11 deploy (system-784) — the daemon had committed my edit minutes before their switch; confirmed by content (MemoryMax present) not generation math.
2. **ShellCheck-build of ALL three scripts (#3):** `forgejo-mirror-github`, `forgejo-reconcile-mirrors` (standalone import expression), `forgejo-ensure-repos` (via eval of the deployed ExecStart store path + build). The 07:43 session's open item is closed.
3. **Rate-limit fail-loud guard (#14), LIVE:** the GitHub listing now checks `jq -e 'type == "array"'` per page. Before: a rate-limited listing (`{"message":...}` object) made `.[]` yield nothing, `length < 100` broke the loop, and the run reported **success with ZERO repos** (phantom green — silent end of all mirror creation). Fixture-verified both directions.
4. **Pagination check (#15):** verified by reading — `per_page=100&page=N`, break on `< 100`. Correct; the "50/page assumption" worry doesn't apply (that's the forgejo-side listing, which also pages correctly at limit=50).
5. **Reconcile outcome metrics (#6), LIVE:** the reconcile script publishes `forgejo_mirror_{total, stale_names, upstream_deleted_archived, transferred, pending_deletes}` + `forgejo_mirror_reconcile_{scrape_errors, last_run_timestamp}` directly into the node_exporter textfile dir (sticky 1777; the unit is the ONLY writer of `forgejo_mirror_reconcile.prom`, so mktemp+chmod 644+mv needs no CAP_FOWNER; best-effort-warn publish; `FORGEJO_MIRROR_TEXTFILE_DIR` env override for fixtures). Published ONLY on completed runs — mid-run death leaves last-good values and unit-state alerting owns that mode.
6. **Gatus "Forgejo Mirror Reconcile" (registry check on the forgejo entry), LIVE + GREEN:** anchored `\n` pat conditions on scrape_errors 0 + total ≠ 0. Absent metrics = never-completed-run = red by design. Verified executing in the gatus journal at 16:37:46 and 16:42:46, success=true.
7. **Unit-failure visibility (#17), LIVE:** `forgejo-github-sync` added to `system-health.extraMonitoredServices` (github-auto-assign pattern, `options ?`-guarded). Verified exactly-once, zero duplicates (the duplicate-metric-series trap).
8. **deploy.sh trigger block, LIVE + FIRED:** post-switch, timer-gated (the SERVICE is not enabled — only the timer; the indirect-unit `is-enabled` rc=1 trap), `systemctl start --no-block forgejo-github-sync.service`. Every deploy now converges mirrors + reconcile immediately; a first-run mass migration can never block a deploy. Proven live: the system-785 deploy's run started at ~16:33 and completed 16:34:22.
9. **Live bug found + fixed + deployed: 404-JSON probe misclassification.** The morning's reconcile run journaled `transferred: three.js-skybox-world ({"message":"Not Found",...})` — `gh api` prints HTTP error BODIES to stdout even on failure, so all 32 upstream-deleted repos classified as "transferred" with garbage owners. Fix: trust gh's EXIT CODE + an `owner/name` regex shape check, never captured stdout alone; network blips misclassify as archived for one report-only run (self-heals). Fixture-regression-tested with a stdout-garbage-emitting gh stub. **Live post-fix: 32 archived, 2 transferred (exactly DarkBlocks + DialogesWebInterface), 0 garbage.**
10. **Fixture tests (#12):** mirror happy path (existing/new/created/exit 0 — via PATH-sed-injected stubs, the runtimeInputs-shadowing DMS lesson) + rate-limit (exit 1, loud message); reconcile two-run rename delete + archived/transferred classification + prom contents + the 404 regression.
11. **Runbook (#11):** `docs/services/forgejo.md` — sync model, reconcile semantics, monitoring map, operational facts, break-glass.
12. **AGENTS.md:** continuation-hardening bullet appended to the forgejo sync section (all of the above, including the gh-stdout lesson).
13. **DEPLOYED + VERIFIED:** system-785 (another actor's deploy carried my committed work — see (d)); current-system anchored == profile; live unit ExecStarts = the new script store paths; prom file published; gatus green; post-deploy run "351 repos processed, 0 failed".

## b) PARTIALLY DONE

| Item | What remains |
| --- | --- |
| `/var/lib/forgejo` size measurement (#5) | Blocked: 0700 forgejo-owned + backup dir unreadable from lars. Needs one `sudo -u forgejo du -sh /var/lib/forgejo` — then btrbk root-snapshot growth projection. |
| Watch the first mass-migration run (#2) | Moot as a live-watch: it ran 09:42–10:09 under the morning deploy, unwatched by any session. Verified post-hoc from the journal (225 created / 0 failed / 27 min wall). |
| Reconcile stability under natural ticks | One post-deploy run verified clean (16:34). 1–2 natural 6h ticks should be glanced at (garbage-free classification persists, no pending-delete flapping). |

## c) NOT STARTED (from the 07:43 backlog; owner decisions or design work)

- **#7:** Artmann-Minecraft transfer disposition (delete 2 frozen mirrors vs re-mirror into a forgejo org) — owner.
- **#8:** keep-all policy for the 32 upstream-deleted frozen archives — owner (btrbk pins them forever pool-side).
- **#9:** starred-org reconcile — needs the name→upstream design (e.g. store full_name in the repo description at create time). M.
- **#10:** collapse the now-redundant declarative `forgejo-repos` list (dnsblockd, BuildFlow) — owner-ish.
- **#13:** VM/integration test for the sync pair — L; fixture-only rationale now documented in the 07:43 report + runbook.

## d) TOTALLY FUCKED UP (all caught in-session, all fixed before deploy)

| What | Root cause | Lesson |
| --- | --- | --- |
| Invalid `.replace` fragment written into forgejo.nix mid-edit | Sloppy edit-tool payload | Viewed + repaired immediately; always re-view after a suspicious edit result |
| Introduced the `\\n` double-escape in a gatus pat() condition | Exactly the 2026-08-22 trap class documented in AGENTS | Caught myself on review before flake check; byte-verified with `od -c` after fix. The lint would have caught it — but not shipping it is better |
| Broken IO-poll probe: "WINDOW OPEN" printed at avg10=58% | awk took field $2 = `avg10=58.59`, then string-arithmetic compared it | A gate probe must be tested once against a known value before it's trusted — same class as the pipeline-mask lesson |
| False "deploy lock holder EXITED" (kill -0 loop said the 16:26 deploy was dead at 16:30 while it ran until 16:37) | kill -0 liveness assumption | Use `ps -p <pid>` for liveness, never kill -0 heuristics |
| Fixture stub bugs: gh arg index ($3 vs $2), curl "URL is last arg" (wrong when `-d` follows) | Stubs written from memory of the call shapes | The FIRST wrong-looking fixture result made each obvious — fixture tests only work if you read their failures as stub-bug hypotheses too |
| Attempted a deploy knowing the IO storm was active | Optimism | The pressure gate correctly blocked it (exit before build); cost was one cheap run |

## e) WHAT WE SHOULD IMPROVE

1. **Stub realism:** my first gh stub exited 1 with EMPTY stdout — real `gh api` prints the error body to stdout. The 404-JSON misclassification survived the morning session's fixture test partly because ITS stub had the same unrealistic shape. When stubbing a CLI, check (or mimic) its failure-mode stdout/stderr split — `gh api --help` documents it.
2. **Verify what shipped by CONTENT, not generation numbers:** "system-784 has my hardening" was only provable by reading the live unit's MemoryMax + ExecStart store paths. Generation numbers lie across parallel deploys and store swaps.
3. **Riding foreign deploys is legitimate but must be detected early:** I burned ~45 min polling for an IO window while the user's own 14:11 deploy had already shipped half my work. An early `readlink /run/current-system` + unit-content diff after ANY parallel activity would have re-scoped the wait immediately.
4. **Metric presence by design:** the "published only on completed runs" pattern (no start-marker) avoids the red-during-long-run window; unit-state alerting covers mid-run death. This split (outcome freshness vs pipeline liveness across two independent checks) is worth copying.

## f) Up to 50 things we should get done next

**Session-direct leftovers (forgejo mirror domain):**

| # | Task | Impact | Effort |
| --- | --- | --- | --- |
| 1 | `sudo -u forgejo du -sh /var/lib/forgejo` — measure post-migration size + project btrbk root-snapshot growth (the 07:43 (e)1 lesson: measure BEFORE enabling mass ops; do it now that it's done) | High | S |
| 2 | Owner decision: Artmann-Minecraft 2 transfers (delete vs org re-mirror) | Medium | S |
| 3 | Owner decision: 32 frozen archives keep-all (default) or prune | Low | S |
| 4 | Collapse `forgejo-ensure-repos` declarative list (split brain with the general listing) | Low | S |
| 5 | Glance at 1–2 natural 6h reconcile ticks (classification stays clean, pending-deletes don't flap) | Medium | S |
| 6 | Starred-org reconcile design (store full_name in description at create time) + implementation | Medium | M |
| 7 | Clean the 2 stale `commit-graph.lock` files as forgejo user | Low | S |
| 8 | Retire the manual `KNOWN_NEW_METRICS`-style loan if pre-deploy §10 warns about `forgejo_mirror_*` after they're live | Low | S |

**Noticed in passing (NOT re-verified, other sessions' domains — pointers only):**

| # | Task | Impact | Effort |
| --- | --- | --- | --- |
| 9 | llama-rag pinned-build spin regression is LIVE on :8848/:8849 since 14:12 (other session's 14:01 report documents the triggered escape condition; the two spinners ran all through this session) — the config-disable deploy is the pending containment | High | M |
| 10 | A ~15:5x–16:30 deploy attempt by another actor produced NO switch (no activation journal, no generation) — if that session believes it deployed, it didn't | Medium | S |
| 11 | IO storms remain chronic (34–65% avg10 for hours) whenever parallel agent sessions build; the deploy gate correctly blocked mine — the structural fix (crush-DBs-off-QLC migration finishing) is tracked in TODO_LIST | High | L |

## g) Questions I cannot answer myself

1. **The 2 Artmann-Minecraft transfers (DarkBlocks, DialogesWebInterface):** delete the frozen mirrors, or re-mirror them into a Forgejo org namespace? (Pure owner preference; both are frozen either way until decided.)
2. **The 32 upstream-deleted frozen archives:** keep forever (current default — they're the only copies, but btrbk pins every byte pool-side forever), or review/prune some (e.g. the old Minecraft-plugin era)?
3. **`forgejo-ensure-repos` declarative list (dnsblockd, BuildFlow):** collapse it into the general 6h sync (single source of truth), or keep as a deliberate belt-and-suspenders for the two repos that matter most for builds?

---

**Evidence trail:** live unit `/etc/systemd/system/forgejo-github-sync.service` (new ExecStart store paths, MemoryMax, ioTier); `/var/lib/prometheus-node-exporter/textfile_collectors/forgejo_mirror_reconcile.prom` (16:34:22, 385/32/2/0); gatus journal `endpoint=Forgejo Mirror Reconcile; success=true` (16:37, 16:42); `journalctl -u forgejo-github-sync` (09:42 migration "349 processed, 0 failed"; 16:34 run "351 processed, 0 failed" + clean reconcile summary); system-785 anchored.
