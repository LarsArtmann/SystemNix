# Storage Decisions Q&A + Purge Wave 1 — Full Status

**2026-11-03 20:44 CET · session: storage decision Q&A (3 batches × 5), cache spot-check + purge, doc/queue updates**
**Tree at authoring:** HEAD `07a7afa83` (daemon-swept, clean); prior window's report: `docs/status/2026-11-03_19-02_qlc-vs-samsung-storage-audit.md`.

**Scope line — VERIFIED here (command → result):**

- Owner decisions captured verbatim: 3 `question`-tool batches (15 questions), answers quoted in queue rows and below.
- Cache contents spot-check (owner-required before cleaning): `ls -A` + `find -maxdepth 3` for db/pem/key/sqlite/env patterns across 11 cache dirs — glac-fleet/m365fix/cv-go/ds-gate/ec-hooligan… (see §d/verdict below).
- Purge wave 1: `df -B1 /dev/nvme1n1p6` before/after + `rm -rf` of 5 pure-GOCACHE dirs — **625458880512 → 621215395840 = 4.24 GB freed at first sample (84%→83%)**.
- ollama reclaim premise check: `ls /data/ai/models/` — `ollama` ABSENT (embeddings, fastflowlm, gguf, image, jan, tts, vision, whisper present); `df` unchanged after a no-op rm attempt.
- All queue writes validated: `scripts/check-todo-system.sh` → "OK: TODO queue/library structure clean" (both before and after; WARN 173 = pre-existing parallel-session backlog, unchanged).
- storage-collector existence: rg TODO_LIST — already a deployed project with `modules/nixos/services/storage-collector.nix`, dirSizes capability rows, lock-bump rows.
- Multi-agent activity: `git log` — daemon commits `85e4aaf09`, `248c26be3`, `cd523ac65`, `96ac7b5e0`, `78d43d16e` swept my edits + a parallel session's flake work (`flake.nix`, `flake.lock`, `lib/flake-input-pin-audit.nix`; working-tree `lint-static.nix` + `lars-packages.nix` = NOT mine, untouched, now committed or still foreign-owned per HEAD).

**Scope line — NOT verified here (and why):**

- Full contents of the 4 excluded cache dirs — spot-check sampled shapes at depth ≤3 only; glac-fleet's 25G could hold more unique data than the Kernovia DBs found.
- Who/what deleted `negative-test-lints.PR7oGL` (6.4G) mid-session and when `/data/ai/models/ollama` was reclaimed — both happened outside this session's visibility (parallel session / operator suspected; no journal dig, out of scope).
- df delta reconciliation for the purge (4.2G df vs ~16G logical du) — commit-lag + CoW-sharing hypotheses stated, no compsize run.
- Whether the merge into paperless completed (gcs-staging gate) — owner knowledge / needs a paperless-side probe.
- burn-in end precision (Nov 4 vs 5) — CHANGELOG says "≥7 d" from 2026-10-28; not re-derived from the plan.

---

## a) FULLY DONE

| Item | Evidence |
|---|---|
| 15-question storage decision Q&A executed in 3 importance-ranked batches (reclaims/backup → design/layout → ops/tooling), every answer captured | owner selections in this report §f + queue rows |
| Important-data spot-check on `~/.cache` BEFORE any purge (owner-required constraint) | found Kernovia `.db`s (glac-fleet), `legacy.duckdb` (m365fix), `pipeline.sqlite` (cv-go/tmp), run logs (ds-gate/ec-hub) → 4 dirs excluded |
| Purge wave 1: 5 pure-GOCACHE dirs deleted (vra-gocache, cmdguard-gocache, go-build-{baseline,gobilanz,bf}) | df 4.24 GB freed at first sample, 84%→83% |
| btrbk excludes decision queued: /data/ai + SteamLibrary + gcs-staging never to the pool (owner directive: NEVER backup re-downloadable AI models) | storage.md + TODO_LIST `[ready]` rows |
| ClickHouse relocation rows RETIRED on both surfaces (owner directive: ClickHouse stays on QLC) | storage.md row 156 + TODO_LIST row stamped |
| crush/ reclassified IMPORTANT DATA (feeds crush-daily) — dedicated session + hourly/3h restic-pattern incremental queued (NOT btrbk; hot-subvol doctrine) | storage.md crush row UPDATE |
| /data redesign scoped: FULL design doc, latency-first constraint | decision row UPDATE |
| SSD-merge decision queued: owner leans merge (~440G), gated on bench-disk IO tests; rust-cache-btrfs rationale documented | `[decision]` row |
| Phase F shadow reclaim AUTO-GO queued at burn-in end | `[watch]` row |
| storage-collector ledger capability queued — corrected mid-flight from "new project" to "extend the EXISTING deployed collector" (prerequisite rows folded) | `[ready]` rows both surfaces |
| Samsung-as-root feasibility queued as watch (owner goal; preservation explicitly declined; PSI-baseline watch = the crash-hypothesis test) | `[watch]` row |
| ollama stale row stamped: tree ALREADY reclaimed before today (absent at probe) | storage.md pinning-table row |
| gcs-staging evidence rows closed on queue + library (2 subtrees, 98,718 files, newest 2026-10-01) | TODO_LIST row ticked |
| All edits landed; queue structure green after every wave | checker output ×3 |

## b) PARTIALLY DONE

1. **~/.cache cleanup** — wave 1 done (4.2G); wave 2 (the 4 excluded mixed dirs, ~70G) blocked on owner triage per dir. Blocker: owner verdict (delete/archive/keep). Effort: S once verdict lands.
2. **btrbk excludes** — decision captured; implementation (snapshots.nix excludes + verify leg + eval) not started. Effort: M.
3. **Go-cache redirect to buildcache** — direction set ("ALL Go caches → /mnt/buildcache"); writer identification + capacity policy (240G wedge history; SSD-merge bench gate) open. Effort: M–L.
4. **/data corruption repair (T06a→T09)** — "next calm window" chosen; root-run + T06a sign-off remain; excludes shrink the eventual re-send scope. Effort: L, root-gated.
5. **Phase F reclaim** — auto-go queued; time-gated to burn-in end (~Nov 4-5). Effort: M at execution.
6. **gcs-staging purge** — owner selected it; gated on the merge-landed confirmation. Effort: S.
7. **docker inventory** — owner must run the root probe (command provided); verdict then reclaim. Effort: S.
8. **/var/lib ledger completion** — command provided to owner (`sudo ionice -c3 nice -n19 du -x -h --max-depth=1 /var/lib`); awaiting output. Effort: S.
9. **crush/ safe-and-fast mechanism** — dedicated session agreed; nothing designed yet. Effort: L.
10. **storage-collector ledger capability** — queued with prerequisite rows (dirSizes capability wiring, spawn_blocking). Effort: L.

## c) NOT STARTED

- /data FS/layout/naming design doc (latency-first) — queued, not drafted.
- SSD-merge bench-disk IO test campaign — queued, gated.
- Samsung-as-root feasibility design — queued as watch.
- Root-fs per-folder 1-by-1 review wave (`.local` 34G, `.config` 15G, `go` 13G, `.gotmp` 6.4G) — queued.
- journald retention verify vs 7.8G Samsung journal — queued.
- dnsblockd growth sanity check (8.5G hot subvol) — queued in services.md.
- Go-cache writer identification (which tooling spawns the per-project cache dirs) — folded into the redirect row.
- compsize passes for shared-vs-exclusive splits — brainstorm (§f).
- @cache-home usage metric + Trash-size alert — owner approved ("sounds smart"); not wired.

## d) TOTALLY FUCKED UP

1. **My multiedit deleted a queue row mid-batch** — the storage.md insert used the per-folder row as `old_string` but the `new_string` omitted it, silently destroying the row. Caught by post-edit `rg` count check and repaired in the next call. Failure mode: batch edits that reuse a row as an anchor without re-including it. Severity: transient (repaired same turn), but the pattern would have silently dropped a directive row.
2. **I offered ollama 15G as an executable reclaim without live-verifying it exists** — the docs said "dormant, pending reclaim"; the dir was already gone. The owner's premise-check rule (grep the claimed state before queueing/asking) was violated for exactly this one option; discovered at execution, stamped on the stale row. No harm done (no-op rm), but the answer I gave contained a false executable.
3. **I queued "new project storage-collector" without grepping** — the project already exists and is deployed; the owner's phrasing meant extension. Caught during verification grep, corrected on both surfaces. Same class as (2): premise unverified before writing.
4. **`negative-test-lints.PR7oGL` (6.4G) vanished mid-session, unexplained** — present at the 19:00 du, gone at 20:3x; parallel session or self-clean suspected, not attributed. Shared-tree discipline says flag (done) — the attribution gap stays open.
5. **Batch-1's purge option shipped without its safety check built in** — the owner had to add "double check none of my projects put important data into ~/.cache" as a constraint. The check should have been part of the option description; their instinct found real data (Kernovia DBs) that a blind purge would have destroyed.
6. **4.2G df vs ~16G logical purge delta unreconciled** — commit-lag/CoW hypotheses stated but compsize not run; the number I quoted is a floor, not the verdict.

## e) WHAT WE SHOULD IMPROVE

1. **Premise-check EVERY executable claim at option/queue time** — ollama (2) and storage-collector (3) were both catchable with one `ls`/`rg` before writing. The rule exists in AGENTS.md; apply it at question-option granularity, not just queue-row granularity.
2. **Multiedit hygiene**: when a row doubles as an anchor, the `new_string` must re-include it verbatim; post-batch, verify expected row counts (`rg -c`) before moving on.
3. **Build safety checks INTO options** — destructive-action options in question batches must carry their guard rails ("after spot-check", "after root inventory") in the option text, not as owner addenda.
4. **question-tool batches worked** — 3×5 importance-ranked with embedded counter-question space captured 15 decisions + 5 free-text corrections in one pass; reuse this pattern for future decision-heavy sessions.
5. **Quote df floors as floors** — post-deletion claims need either commit-window patience or compsize before being called "reclaimed X".
6. **Doc staleness keeps compounding**: ollama "pending reclaim" (already done), storage-collector framing — the 19:02 report's fix-on-sight pass caught three; today's pass caught two more. The probe-date discipline (now in composition lines) needs to extend to lifecycle-state claims ("pending X" rows get a re-verify date).

## f) Up to 50 things to get done next (ranked; routing-tagged)

**Owner-gated, ready on your word:**
1. Triage the 4 excluded cache dirs (glac-fleet Kernovia DBs 25G / m365fix legacy.duckdb 22G / cv-go 19G incl. pipeline.sqlite / ds-gate+ec-hub 8G) — delete/archive/keep each. Impact: High, Effort: S. *(owner verdict)*
2. Paste the `/var/lib` du output → completes the root ledger (monitor365-server ~39G visibility). Impact: Medium, Effort: S. *(awaiting you)*
3. Confirm gcs-staging merge landed in paperless → trash 24G. Impact: Medium, Effort: S. *(owner confirm)*
4. Run the docker root inventory (command offered) → Twenty-DB verdict → reclaim ~10G. Impact: Medium, Effort: S. *(root-only)*
5. Phase F auto-go executes at burn-in end (~Nov 4-5) — ~137G QLC shadow reclaim per runbook. Impact: Critical, Effort: M. *(queued, time-gated)*

**Queued implementation (agent-actionable `[ready]`):**
6. Implement btrbk excludes (/data/ai + SteamLibrary + gcs-staging) + verify leg. Impact: High, Effort: M.
7. Redirect all Go caches to /mnt/buildcache + GC leg (identify the per-project writer first). Impact: Critical, Effort: M–L.
8. Extend the existing storage-collector with the PSI-gated ledger capability (prereqs: dirSizes capability wiring + spawn_blocking). Impact: High, Effort: L.
9. Root-fs per-folder review wave (`.local`/`.config`/`go`/`.gotmp`). Impact: High, Effort: M.
10. journald retention verify (7.8G Samsung journal). Impact: Medium, Effort: S.
11. dnsblockd growth check (8.5G, +3.7G/3w). Impact: Medium, Effort: S.
12. @cache-home usage metric + Trash-size alert (owner-approved). Impact: High, Effort: S.
13. EIO repair chain at the next calm window (T06a→T09; excludes shrink the re-send). Impact: Critical, Effort: L, root-gated.

**Decisions/design (queued):**
14. /data full design doc (FS + layout + naming; latency-first). Impact: High, Effort: L.
15. SSD-merge bench campaign (bench-disk.sh; both-USB btrfs failure-domain tradeoff). Impact: Medium, Effort: M.
16. crush/ dedicated session: safe-and-fast mechanism + hourly/3h restic-pattern incremental (VACUUM dedup-cost documented). Impact: High, Effort: L.
17. Samsung-as-root feasibility design (no preservation adoption; capacity math first). Impact: High, Effort: L, early.
18. Attributions: who reclaimed ollama / deleted negative-test-lints.PR7oGL (shared-tree discipline). Impact: Low, Effort: S.

**Pre-existing tracked rows re-confirmed live this session:**
19. btrbk-forgejo stray receive heal. 20. btrbk-projects nightly ladder verify. 21. D6 boot proof (projects subvol). 22. QLC PSI baseline watch (your crash-hypothesis test). 23. du -sb baseline artifact. 24. Hot-db shadow soak-end reclaims. 25. Samsung SMART owner check. 26. Post-EIO-repair memory.peak proof. 27. Home Trash 55G prune (existing blocked:user row). 28. Trash-prune timer row. 29. Ledger tooling row (absorbed by 8). 30. zz-test fixture chattr cycle deletion.

**New from this session, not yet queued (brainstorm/ROADMAP fuel):**
31. compsize passes over /data, root @, /mnt/hot (true shared-vs-exclusive splits). 32. Go-cache writer attribution via audit hooks (which session/tool spawns the dirs — feeds 7). 33. Wave-2 purge automation once the 4 dirs are triaged (fold into 7's GC leg). 34. df-floor discipline in purge scripts (commit-window wait or compsize before claiming reclaimed bytes). 35. question-batch pattern → skill candidate (decision-heavy sessions). 36. Probe-date stamp for "pending X" lifecycle rows (auto-stale after N days). 37. `~/.cache` per-dir growth watcher (feeds 12's metric). 38. Kernovia DB provenance check before any glac-fleet deletion (are clones2 vs clones divergent?). 39. cv-go pipeline.sqlite vs cv-backup's canonical DB — dedupe/conflict check. 40. m365fix legacy.duckdb → does the project still open it (recent mtime check at triage). 41. ec-hub `run-3744802`/`site-verify` — run-artifact retention rule. 42. ds-gate quality.log rotation. 43. Merge precondition: rust-cache ext4-vs-btrfs re-decision if merged (compression value survives merge?). 44. btrbk excludes → also exclude from local /data snapshots? (owner call: local pins cost QLC space on model churn). 45. Post-excludes pool-send duration/size delta measurement (proves the capacity win). 46. gcs-staging deletion runbook step: trash → 4-5w pin note (queue in the execution row). 47. Phase F execution must re-check parity one last time before umount (belt on top of auto-go). 48. `negative-test-lints` harness: name runs deterministically + self-clean (kills the PR7oGL-class litter). 49. Home Trash 55G: fold into wave-2 purge day (trash-empty owner run). 50. Update the 19:02 report's ollama/docker figures with today's discoveries (annotate, never rewrite).

(31–50: deliberately NOT harvested — brainstorm/verification grain; 1–18 already live in the queue; 19–30 are pre-existing rows, no duplicates created.)

## g) Questions I cannot answer myself

1. **Wave-2 triage verdicts** — for each: glac-fleet (Kernovia `.db` clones + push scripts — keep/archive/delete?), m365fix (`legacy.duckdb` — is it opened by the project or superseded?), cv-go (`tmp/pipeline.sqlite` — scratch or the real integration-events DB?), ds-gate + ec-hub (run logs/artifacts — how long do you want them kept?). I checked shapes; importance is yours to rule.
2. **gcs-staging merge gate** — did the private-cloud/paperless-merge actually complete into paperless (so the 24G staging trash is safe), or do you want to verify in the paperless UI first?
3. **Attribution** — do you know which session/operator reclaimed `/data/ai/models/ollama` and deleted `negative-test-lints.PR7oGL` between today's readings? (Both moved outside my visibility; attribution closes the shared-tree gap instead of leaving two unexplained mutations.)

---

### Multi-agent note

Parallel session active throughout: flake surface edits (`flake.nix`/`flake.lock`/`lib/flake-input-pin-audit.nix` committed via daemon; `lint-static.nix` + `lars-packages.nix` in flight), TODO_LIST mtime conflict hit once (re-read, re-applied). All my writes content-pinned per the shared-tree discipline; checker green at every step.

_Arte in Aeternum_
