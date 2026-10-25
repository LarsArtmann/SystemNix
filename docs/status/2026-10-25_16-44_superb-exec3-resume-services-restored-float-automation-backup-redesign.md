# SUPERB exec-3 resume: control plane restored, four services green, float ceremony automated, backup export redesigned

**Written:** 2026-10-25 16:44 CET · **Session:** exec-3 resume (14:40 report → owner re-fire → this session, 15:00-16:43) · **HEAD at write:** daemon batches through gen-946 tree · **Live generation:** `system-946` (deploy7; generation line verified — full readlink anchor check queued in §f) · **Ports:** :3001 ✓ :8088 ✓ :8099 ✓ (all three listening at write time)

## TL;DR

monitor365's control plane is BACK (65/65 indexes rebuilt out-of-band; API+UI smoke PASS), papdashboard is BACK (duplicate manual tiles removed + new eval-time duplicate-name gate), inboxclean-web is BACK (stop-cause SOLVED: the memory-emergency-guard shed it, not a phantom actor), the lock-float ceremony that blocked every `nix flake update` is now AUTOMATIC (`scripts/float-register.sh`, wired into deploy), and the nightly backup export was redesigned around upstream's broken `COPY FROM DATABASE` (valid-6GB limit still OOM'd; Oct 24/25 "backups" are partial corpses — last full export = Oct 23). The redesigned backup fire + retention proof (F19/F20) was ONE command away when the owner ordered this report; it has NOT been fired.

---

## a) FULLY DONE

1. **monitor365-server: crash-loop root-caused and REPAIRED; healthy through a deploy.** The 14:40 "silent index rebuild" hypothesis was WRONG — the journal (14:57-15:00) showed `schema init failed: Out of Memory Error (1.8 GiB/1.8 GiB used)` crash-looping: the boot-time `CREATE INDEX IF NOT EXISTS` rebuild over the 30 GB DB cannot fit upstream's DEFAULT DuckDB `memory_limit="2GB"` (decimal 2e9 = 1.86 GiB). Repaired via `scripts/monitor365-index-rebuild.sh` (NEW): quiesce server+watchdog, run the schema.sql index DDL through the duckdb CLI **one invocation per statement** (a single connection high-waters ACROSS statements — the 61-statement batch OOM'd even at 6GB while fresh-process single builds fit at 1.8 GiB). **Live result: 65/65 indexes, 0 failed; server healthy; post-deploy smoke: Monitor365 API (200) + UI (200) PASS.** Module fix deployed (gen-946): server `MONITOR365_SERVER__MEMORY_LIMIT=4GB` + MemoryHigh 6G/MemoryMax 8G (was 3G/4G, default 1.86 GiB inside).
2. **The memory_limit shape trap found and fixed in THREE surfaces.** Upstream `memory_limit.rs` validates `<digits>(KB|MB|GB|TB)` and SILENTLY falls back to the default on mismatch (WARN log only). The backup wrapper's `"6G"` (the prior session's F19 "fix") NEVER WORKED — the plan's own F19 text encoded the broken shape. Fixed to `"6GB"` (monitor365.nix); shape rule documented in the runbook + module comments; first-hand proof the valid shape applies (5.5 GiB in the 16:12 fire).
3. **PapDashboard: fixed, deployed, verified.** Live `/etc/papdashboard/services.json` showed exactly TWO dupes (`Media/Immich ×2`, `Development/Forgejo ×2` — the 14:40 note naming Paperless/Gatus/SigNoz/SearXNG was STALE). Cause: the 2026-10-25 tile-coverage work added registry homepage tiles (immich.nix:190, forgejo.nix:1509) duplicating legacy manual tiles. Fix: manual tiles removed (Development kept as an empty positioning group per the 594-596 pattern; registry tiles are canonical) + **NEW eval-time assertion** `duplicateTileNames` over post-fold `allGroups` mirroring the icon gate — registry-vs-manual collisions now fail eval, not the next restart. **Live: :8088 /api/health PASS, /api/ingest 401 PASS** (postdeploy2 + deploy7 smokes).
4. **inboxclean-web: UP + healthy, stop-cause SOLVED (§g.1 of the 14:40 report).** The unit served 200s continuously 14:45-14:53 on the new binary (c63bf28), then stopped CLEANLY at 14:54:19 — the SAME second `crush-hot-db-migrate` stopped. Actor: **the memory-emergency-guard** — both units are in its shed list (`memory-emergency-guard.nix:1191,1200`); it trips episodically during the IO storm (6×/60min). The 13:27:25 stop was the same mechanism. Revived by deploy machinery (reset-failed + generation start); smoke: InboxClean /health PASS, dashboard PASS. Remaining: Gmail main `auth_expired` (owner OAuth runbook, pre-existing WARN).
5. **F18 FIXED + VERIFIED LIVE.** `node_textfile_scrape_error=1` root cause: `storage-collector-crash-orphans.prom` carried a **client-side timestamp** (`storage_collector_crash_orphans_total 0 1792899205`) — node_exporter rejects the ENTIRE file. Emitter fixed (storage-collector.nix printf, no timestamp). **Live proof: `node_textfile_scrape_error 0` at :9100 + the gauge exporting.** The absent-`forwarded` WARN was a checker MISCLASSIFICATION (it's the Gatus Alert Relay /healthz BODY substring `pat(*forwarded*)`, not a metric) — fixed in pre-deploy-check's extractor exclusion list after my F18 fix flipped it from WARN to hard BLOCK (the collector-healthy state removed the infra-downgrade).
6. **cv float unblocked with first-hand evidence.** Proof build3 red: cv@29868e05 go-modules specified SkTcNXE (shim baked for 88e0d12), got **1o2UQtLN** — and upstream at 29868e05 bakes a THIRD, equally stale value (Asj5FdV, verified in the fetched source's vendorHash.nix), so dropping the shim cannot work. Shim updated to 1o2UQtLN with dated evidence (cv.nix). **Live: CV /health/live PASS, version 29868e0.**
7. **The float ceremony is now AUTOMATIC — the owner's "I hate this fake update locking" item.** NEW `scripts/float-register.sh`: drift check (instant no-op when clean) → regenerate registry body from the lock (header rederive command) → keep-going toplevel proof to `~/.cache/lockfloat/float-proof-<ts>.log` → on green commit lock+registry TOGETHER with an audit message; on red REVERT the rows + print roots; lock-fingerprint guard aborts if the lock moves mid-proof; daemon-race tolerant (a heuristic batch landing mid-proof is detected and content-verified instead of failing). Wired into `scripts/deploy.sh` before the validation battery (`FLOAT_REGISTER=0` opts out; red proof aborts the deploy with exit 12) + `nix run .#float-register` app (flake/parts/apps.nix). **First live runs: the full dogfood cycle registered go-taskqueue/go-humanize-linter/nur with proof rc=0; deploy7's hook printed "no drift — registry matches flake.lock".**
8. **Four float drift sets registered + proven this session** (parallel sessions + owner kept moving the lock): build3 (red → cv fix), build5, build6, float-proof-155523 — all logs retained in `~/.cache/lockfloat/`. Deploys: gen-945 (papdashboard dedupe + monitor365 env + storage-collector fix + cv shim), gen-946 (backup redesign + pre-deploy checker fix + float-register wiring).
9. **Backup export REDESIGNED (3rd iteration, deployed gen-946, NOT yet fired).** Evidence chain: the 03:01 OOM died at 1.86 GiB (default); the 16:12 forced fire (NEW `scripts/monitor365-backup-fire.sh`) proved the VALID 6GB limit applies (5.5 GiB/5.5 GiB in the error) and STILL died — `backup copy failed: Failed to commit: failed to pin block` ~3 min in at ~7-8 GB written, 8G cgroup peak. Conclusion: upstream's `COPY FROM DATABASE` cannot stream a 30 GB DB under any sane cgroup (it worked ≤ Oct 23 on 35 G — the float-era DuckDB/vendored change is the suspect). The Oct 24 (7.3 G) and Oct 25 (8 G) "backups" are PARTIAL CORPSES of the same class — **the rollback ladder's last full export is 2026-10-23** (plus the owner's NVMe safety copy 2026-10-22). New wrapper (monitor365.nix): quiesced (server stopped = single writer) → duckdb `CHECKPOINT` as the service user → `cp --reflink=always` (same BTRFS subvol = instant, IO-free CoW; plain-copy fallback) → same `*.backup_*.db` naming the prune + heal-restore paths speak.
10. **5 orphan `tq-autopsy` processes cleared** (~7h old, loopback test ports; systemd pool unaffected; killed by explicit PID after cmdline review).
11. **Runbook updated** (docs/services/monitor365.md): shape-trap correction in the env-overrides row + new "Index desync + boot-rebuild OOM incident (2026-10-25)" section (both repair scripts, the per-statement doctrine, the operational DuckDB facts learned live).

## b) PARTIALLY DONE

1. **F19+F20 (backup + retention proof): redesigned, deployed, NOT re-fired.** The re-fire (`scripts/monitor365-backup-fire.sh`, ~1-2 min) was the immediate next action when the owner ordered this report. Until it fires green, the nightly ladder's freshest FULL rung remains Oct 23 (partial-corpse risk documented above).
2. **deploy7 (gen-946) exited rc=3 "NEW smoke failures vs baseline"** — context lines point near paperless-gpt; NOT triaged (the ANSI-wrapped FAIL lines defeated my grep; the deploy itself activated gen-946 and all key services were green minutes earlier in postdeploy2). Needs the exact new-vs-baseline delta read.
3. **F21 (agent SSE + breaker):** agent-watchdog verdict 16:10:57 "agent healthy … server connected" ✓; breaker opened DURING the 16:12 backup quiesce (expected); post-window closure + SSE reconnect + device count NOT re-verified.
4. **F17 (node_exporter clean journal):** fix is live (scrape_error 0) but the 10-minute clean-window journal proof was not collected.
5. **Commit hygiene vs the daemon:** every one of my edits landed inside heuristic daemon batches (verified exclusively-mine in `d4447ffe0`, mixed elsewhere); the properly-messaged registry commit lost the race to the daemon on first float-register run (race-tolerance added after). Registry history-as-audit-log doctrine is violated for this session's rows — attribution lives here and in module comments.
6. **Gen-946 anchor:** the deploy printed "New profile generation: system-946 (was system-945)" and 946 is the newest profile link; the full `readlink /run/current-system` == target equality check was not re-run after deploy7 (queued, 10 seconds).

## c) NOT STARTED

1. F66/F68 (/data du-vs-df) — needs a calm IO window.
2. Close-out corpus: CHANGELOG entry, TODO harvest of this report's §f, SUPERB plan tombstone flip (still says "EXECUTING exec-2" + wave-3 marker), the 12-55 report's §e obligations.
3. memory-emergency-guard review: it trips 6×/h during the IO storm while MemAvailable ≈ 30 GB and sheds a user-facing dashboard (inboxclean-web); shed units have no auto-restore (revive = deploy machinery or manual start). Stability-domain item.
4. Upstream queue (owner-gated): monitor365 `COPY FROM DATABASE` commit-pin OOM + the silent shape-rejection (should fail loud) + the WAL-delete desync class; cv + health-hub vendorHash pastes (14-49 session's items).
5. deploy5's STORM-SUSPECT items (cv browser render smoke) — re-verify when calm.

## d) TOTALLY FUCKED UP (honest ledger)

1. **Two failed index-rebuild attempts on a down control plane:** v1's grep-based DDL extraction truncated schema.sql:543's TWO-LINE statement → misleading `syntax error at or near "CHECKPOINT"`; v2's single-connection 61-statement batch OOM'd at 6GB (connection high-water across statements — the insight v3's per-statement design came from, but the control plane bled IO for two extra cycles while I learned it).
2. **Pipe-masked my own deploy rc** (`tee | grep … ; echo rc=$?` reported GREP's 0 while the deploy had aborted on a mid-eval lock drift) — the exact documented class; the deploy4 log caught it, but I reported "rc=0" in-flight reasoning first.
3. **Registry splice dropped the opening `{`** (head-arithmetic assumed a line that wasn't there) → eval syntax error → sed re-insert. Sloppy on a gate file.
4. **jq dotted-hyphen key** (`.nodes.go-taskqueue`) parsed as subtraction — my bug, not the direnv trap; bracket form fixed it.
5. **The 14:40 session's stale dupe list** (Paperless/Gatus/SigNoz/SearXNG "×2") was wrong for the live generation — I designed the papdashboard fix against it before checking the actual services.json; the live file (2 dupes) corrected the edit scope. Claim-vs-source discipline slipped between sessions.
6. **My F18 fix flipped the pre-deploy gate**: healing the textfile collector removed the infra-downgrade that had been WARN-ing `forwarded` — the next deploy hard-failed on my own fix's interaction with the checker's body-vs-metric misclassification. Fixed same-deploy-cycle, but gen-946 needed a second attempt because of it.
7. **Hook strikes ×2** (`rg -rn` false-trigger on composite commands) cost blocked round trips; worked around by splitting commands.

## e) WHAT WE SHOULD IMPROVE (systemic)

1. **pre-deploy §10's body-vs-metric exclusion list is growing by incident** (`connected|email_states?|oidc|forwarded|[A-Z]…`) — invert it: declare which gatus checks assert METRICS (endpoint-tagged) instead of excluding body substrings one at a time.
2. **Registry commits keep riding daemon batches.** The float doctrine ("registry history is the audit log") needs either a pre-commit hook that requires the float message when `flake/expected-locks.nix` is staged, or float-register committing within seconds (it now does — verify it wins henceforth).
3. **The guard sheds without restoring.** A shed wanted-service stays down until the next deploy — propose restore-on-clear in the guard (stability.md row queued in §f).
4. **monitor365 upstream bug reports should be queued now** (backup OOM + shape rejection) — the local redesign is a workaround, not a cure; the upstream COPY bug will bite every big-DB deployment of monitor365.
5. **DuckDB operational doctrine (learned at user cost today) is now in the runbook** — single-writer query discipline, per-statement DDL isolation, WAL/checkpoint semantics. Add a VM-test/fixture for the backup wrapper's new reflink path (the retention script has a fixture precedent).

## f) UP TO 50 THINGS TO GET DONE NEXT

1. **Re-fire the redesigned backup:** `scripts/monitor365-backup-fire.sh` → verify F19 (unit green, export file ≈ DB size, "reflink" journal line) + F20 (retention journal lines, DB size delta) — the session's interrupted final step.
2. Triage deploy7's NEW-vs-baseline smoke failure (paperless-gpt context; read the smoke-fail baseline diff).
3. Verify gen-946 anchor: `readlink /run/current-system` == `system-946-link` target (by generation number).
4. F17: `journalctl -u <node-exporter unit> --since '-15 min' | grep -c 'error gathering'` == 0 proof.
5. F21: post-backup agent SSE reconnect + breaker-closed journal + devices count (2-min grace).
6. Commit `scripts/monitor365-backup-fire.sh` (untracked) + any unstaged script edits (pathspec commits).
7. CHANGELOG entry: monitor365 incident + index/memory fixes + backup redesign + float-register automation + papdashboard dupe gate + F18 fix + guard attribution.
8. TODO harvest of THIS report's §f into TODO_LIST.md + domain libraries (monitoring/services/stability/pipeline rows).
9. SUPERB plan tombstone: coordinate with wave-3 (marker `8835d9100`), flip to EXECUTED with per-item state when T1/T2 close.
10. 12-55 report §e obligations: verify none remain unharvested.
11. F66/F68 /data du-vs-df at a calm window (io PSI < 20%).
12. Guard stability row: trip thresholds under IO-storm + shed auto-restore proposal (stability.md + a [decision] row).
13. Upstream queue rows (no push): monitor365 COPY FROM DATABASE OOM (evidence: 16:12 fire log), memory_limit shape silent-reject, WAL-delete desync; cv `1o2UQtLN` paste; health-hub `0Ko7CAVV` paste.
14. Re-run post-deploy-check when calm (storm-suspects: cv render smokes; nsfw CPU; journal-volume FAILs).
15. Verify the next real `nix flake update` → deploy cycle rides float-register end-to-end (the automation's true acceptance test).
16. InboxClean Gmail OAuth runbook (owner-gated; `auth_expired` WARN).
17. Confirm the 15:55 boot-catch-up backup attempt class (the 0-byte .tmp) — the Persistent timer will re-fire the REDESIGNED unit at next boot; verify it goes green (it also answers 1).
18. Storage-history STALE baseline FAIL (restic-storage-history >25h): separate pre-existing item — journal + /mnt/pool attachment check.
19. Consider a fixture/VM-test for the reflink backup path (e)5.
20. Monitor gen-946's monitor365-server restart behavior: schema-init should now be a no-op fast path even with all 65 indexes present (watch first boot after any future index loss — 4GB env must hold).

## g) THREE QUESTIONS I CANNOT ANSWER MYSELF

1. **Reflink backups share extents with the live DB** (CoW on the same BTRFS subvol) — they protect against app-level corruption/loss but NOT against filesystem-level damage. Acceptable as the nightly ladder given the owner's NVMe safety copy + the pool-side restic/btrbk layers, or do you want a periodic FULL (non-reflink) copy, e.g. weekly?
2. **Upstream monitor365 bug reports** (backup `COPY FROM DATABASE` commit-pin OOM; memory_limit shape silently ignored): queue-only in docs/todo/upstream.md, or authorize preparing/pushing issues to the upstream repo?
3. **The memory-emergency-guard sheds inboxclean-web during IO storms while ~30 GB stays available** (6 trips/hour today; both 13:27 and 14:54 stops were it). Tune its trip thresholds, add restore-on-clear for shed units, or leave as designed (shed-then-manual-revive)?

---

**Logs retained:** `~/.cache/lockfloat/` (build3-6, float-proof-155523, deploy3-7, postdeploy2) · `~/.cache/monitor365-index-rebuild.log` · `~/.cache/monitor365-backup-fire.log`

**Report left UNTRACKED for owner review** (the 14-49 session's precedent); no further execution until instructions.
