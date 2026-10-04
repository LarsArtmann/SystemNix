# Movie-Window Light Batch — Live Verifies, Journal-Provenance Corrections, Docs, Time-Gate Leg (2026-10-04 19:43)

**Session:** direct owner dispatch ("what can you safely get done while I watch a movie"), read-only + docs + eval-free scripts only. IO storm active all session (io some avg10 61% at start, nix-daemon 165G written by a PARALLEL session's builds; 4 reboots today 03:37/05:09/08:39/09:32; deploys 815-821, live gen-821 11:31). No deploys, no VM tests, no builds, no sudo performed. `systemctl` is sandbox-banned for this session — all unit-state claims below use the sanctioned equivalents (CONTRIBUTING 2026-09-29 clause: `/etc/systemd/system` symlink → store unit text, `/proc/<pid>`, journal, textfile `.prom` + mtime).

## a) Fully done (verified)

1. **Journal-proof the 17:05 tq restart — CLOSED with a CORRECTED verdict.** The 03-05 report's "inferred via converge" attribution is WRONG: journal evidence (readable file, not the truncated `system@00065cc9ec260c9d…journal~` — which cannot be parsed even via `journalctl --file`, "No data available") shows (i) tq unit files written + systemd daemon-reload reading them 17:05:05.194 (`/etc/systemd/system/tq-serve.service:46: Unknown key 'startLimitBurst'` — the then-current HAND-WRITTEN units, since replaced by native store symlinks), (ii) `Started tq serve` + `Started tq agent-pool` 17:05:06.938-941, (iii) pool-usb-recovery's ONLY in-window run at 17:06:12 = "mount healthy (/mnt/pool) — no action". Corroboration: system-814-link profile mtime is exactly 2026-10-03 17:05 (the anchoring deploy's activation). Verdict: the restart rode the DEPLOY activation, not the converge. pool-recovery.nix restartUnits does list both tq units (tree-verified) — converge remains wired for real remount events.
2. **Clickhouse store-hit pin — live-verified on gen-821.** Unit `ExecStart` binary `/nix/store/1rb0ambr…-clickhouse-26.8.7.19-lts/bin/clickhouse-server` is byte-identical to the RUNNING process (pgrep PID 5621 same store path); all 6 closure unit symlinks (clickhouse/db-backup/log-ttl/xfs-metrics + gatus cross-check) resolve to existing store paths; `X-Restart-Triggers` present. Process started 09:33:04 today = the 09:32:34 reboot (boot -0), NOT a trigger flip — the "no restart fired" invariant of the original row is moot across reboots, and the meaningful invariant (binary identity across 7 deploys + 4 reboots) HOLDS. NOT run: `scripts/post-deploy-check.sh` (systemctl-gated for agent sessions).
3. **T14 review hardening — live-verified on gen-821.** `hot-db-metrics.service` unit carries `OnFailure=notify-failure@%n.service`; the rendered system-health collector's monitored list contains `hot-db-metrics` (list line + `emit_service` + two svc blocks); live `system_health.prom` fresh (17:35) with the full `system_service_*{service="hot-db-metrics"}` family. `65e93b80` is an ancestor of HEAD.
4. **paperless_tasks_* metric presence (the "LAST open item" of the anchoring batch) — CLOSED live.** Today's deploys carried the two-layer parse fix: `paperless_tasks.prom` is VALID (HELP/TYPE + `paperless_inbox_count 39`, `paperless_tasks_pending_total 3`, llmindex age), FRESH (mtime 17:40), correctly owned `paperless:paperless`, and the node-exporter journal shows ZERO textfile parse errors since 12:00.
5. **Geometrikks runtime-log handling — source-verified + comment corrected.** v0.19.0 `geometrikks/services/logparser/formats/caddy.py parse()`: non-JSON → None; decoded object without a `request` → None; missing client IP/timestamp → None. Runtime lines are dropped BY CONSTRUCTION. `geometrikks.nix` comment corrected (was: global access.log "only receives un-matched traffic" — FALSE; now: it is Caddy's DEFAULT logger = hosts without their own log block + runtime lines, which the parser drops harmlessly, with the source citation).
6. **Docs batch:** (i) `docs/agents/monitoring.md` — two 2026-10-03 collector gotchas recorded (psql needs `-v ON_ERROR_STOP=1` or `|| fail=1` is vacuous; paperless ≥3.1 Tag has NO `slug` — `is_inbox_tag`); (ii) `docs/services/signoz.md` — clickhouse pin runbook bullet (overlay at `overlays/linux.nix:252`, drop condition, drv≠version caveat, live-verified state); (iii) `docs/services/emeet-pixyd.md` — `/api/status` contract + grey-"off" widget trap section; (iv) `AGENTS.md` boot-mirror paragraph — activation runs log NOTHING (script self-elevates, stdout-only; evidence paths = efivarfs decode + `boot-mirror-sync.service` journal), and the stale "first reboot pending" state re-stamped (freeze-#12 reboot WAS the first post-activation boot; mirror survived; only PartUUID/BootCurrent decode remains).
7. **CHANGELOG entry for the 2026-10-03/04 storm-deploy fix batch** — all 7 fixes verified in tree (grep-verified each: ON_ERROR_STOP line 1161, is_inbox_tag 1181, chmod 0644, deploy.sh cv sha gate, system-health `\x2d` decode, paperless-gpt `rm -f`, geometrikks perm-heal) + live state folded in.
8. **CONTRIBUTING ×2:** gitleaks post-amend invocation PINNED with live proof (system gitleaks 8.30.1: `detect --log-opts="HEAD~1..HEAD"` scans clean; adding `-s` fatals `stat dev: no such file or directory` — the old documented form `detect -s --log-opts=…` in the Post-amend clause was itself the BROKEN shape, now fixed); adversarial §f cross-check clause added to re-dispatch protocol step 3.
9. **check-todo-system.sh time-gated [ready] lint leg (check 5).** Wait-language (`tonight|tomorrow|re-dispatch after|after the <x> run|after HH:MM|fires … HH:MM`) on an unchecked `[ready]` row without `BLOCKED` = gate FAIL. Regex validated three ways BEFORE wiring: zero FPs on the live queue (two candidate FPs found and designed out: "notifying at 08:36" historical, "nightly … 03:00" schedule context), the 10-04 incident shape detected, BLOCKED-marked rows exempt. Selftest extended both directions (bad row fails gate; compliant row unflagged); `bash -n` + shellcheck severity=warning clean; live gate run green (rc=0; the 49 DRIFT + 88 UNHARVESTED WARNs are the pre-existing standing backlogs of separately-queued rows).

## b) Partially done

1. **Queue bookkeeping for the 13 closed rows above — NOT yet flipped** (TODO_LIST one-liners + `docs/todo/{services,monitoring,pipeline,storage}.md` entries still read open). The daemon already committed the work files (HEAD `51c92818` at 19:43). Until flipped, the tq pool may re-dispatch already-done rows — see Harvest log.
2. **das-link-recovery-check `[6]` empty-dir churn distinction** — located (lines 349-361, the "debris or path-join bug" note), edit designed but not applied.
3. This report.

## c) Not started (planned, halted)

1. dns-update.sh pin-extraction selftest (fixture script).
2. deploy.sh `cv OIDC env unchanged` smoke assertion.
3. Buildcache parity pre-commit leg live-fire — deliberately deferred: the row demands a quiescent moment AND a full pre-commit run executes `nix flake check` (eval load on a storm box mid-movie).
4. Stretch candidates never opened: SSO table refresh, dead-guard-lint v2 non-`-z`/`-n` forms, buildcache-metrics pnpm gauges, textfile exit-0/empty-value class audit, per-unit io.stat sampler, pre-deploy build-set enumeration leg, dump-leg OnFailure catch-up, under-hot guard case in test-hot-db-assertions.nix.

## d) Nothing broken

No destructive operations ran. Two edit-tool refusals (monitoring.md/AGENTS.md before View — tool enforced read-first; re-read then landed cleanly) and two regex-FP candidates during leg design (both caught in validation, designed out pre-wiring). `TODO_LIST.md` carried another session's 2 uncommitted rows all session — untouched, still present.

## e) What I'd do better / saw but did not act on

1. **Deferred queue bookkeeping too long** — rows should flip as items close, not batch at session end; the owner interrupt exposed the gap (13 done rows still [ready] for the pool to re-fire). The Harvest log below is the interim bridge.
2. **One wasteful 102KB /metrics fetch** where the .prom file + exporter journal sufficed — I realized after; on a storm box every such read counts.
3. **Observations passed but not actioned (each likely already tracked; verified none myself):** `node_btrfs_device_errors_total{device="nvme0n1p8",type="corruption"}` ≈ 3.87e8 on /data (unverified whether known dev-stats quirk vs real); `btrfs_health_critical 1` (unalloc 4%, root 95% allocated — prune rows standing); `forgejo_mirror_health_scrape_errors 1`; `monitor365_backup_healthy 0` + `backup_healthy{crm-server,pbx-backup-pull} 0`; `btrfs_scrub_stale{root,data} 1` (scrubs interrupted); flm-real SIGABRT coredump 11:12 (guard-sacrifice class, 2G written); `memory_emergency_guard_trips_last_hour 2` zone6 live during the movie.

## f) Next (concrete, ranked)

1. Flip the 13 closed rows on BOTH surfaces + prune to CHANGELOG (§a inventory is the evidence).
2. das-check `[6]` empty-dir distinction (edit designed).
3. dns-update.sh pin-extraction selftest; deploy.sh cv-OIDC smoke assertion.
4. Parity-leg live-fire at a quiescent moment (post-movie/post-storm).
5. The standing blocked/ready queue: ~10-04 23:50 prune verification (after the run), root-space floor >90% trigger, deploy-gated batches (caddy batch, P2 attribution, buildcache-init proof), T14 family deferred legs, VM-test rebuild quiet-window batch, master-plan P3 rows, unharvested-report backlog (88), pairing-drift backlog (49), hot-db migration waves + pacing decisions.

## Harvest log

§f items 1-4 and the c) items are deliberately NOT queued as new rows this pass — the session was halted by the owner for this report; items 1-4 map onto EXISTING open rows (they are the completion-side flips and already-open [ready] rows), so new queue rows would duplicate. Next session: flip surfaces per §f.1 before the tq pool re-fires any of the 13.

---

## Continuation (2026-10-04 23:02 — owner meta-dispatch "keep going until done")

IO storm STILL active at continuation start (some avg10 54→56% across the session; load ~9-10). All movie-window constraints honored: no deploys, no VM tests, no builds, no sudo, **zero nix invocations** (freeze-15 class — every verification used direct script runs + bash -n).

### a) Closed this continuation

1. **§b.1 bookkeeping — DONE.** All 13 rows flipped `[x]` on BOTH surfaces (TODO_LIST one-liners + services/monitoring/pipeline/storage library rows; the boot-mirror-logging item annotated onto its storage.md fold row, the T14-verify row carried its library evidence inside the DONE stamp — queue-only row). `check-todo-system.sh` green rc=0 before and after (0 FAIL; the 49-DRIFT + 88-UNHARVESTED WARNs are the pre-existing standing backlogs). The tq pool can no longer re-fire the 13.
2. **§b.2 das-check `[6]` empty-dir distinction — DONE + live-proven.** Empty-dir branch landed; first live run showed the recreated-empty `golangci-lint-analysis` (5th recreation) printing "(empty, recurring transient?)" while `alt-nix`/`scratch`/the three check-probe dirs kept the debris hint. `bash -n` green (shellcheck absent from the sandbox — pre-commit/CI legs own it).
3. **§c.1 dns-update.sh pin-extraction selftest — DONE (4/4) with one in-session incident.** `--selftest` mode exercises the SHIPPED extraction via a shared `extract_sb_pin()` (single regex — no test-copy drift): healthy `hosts/<40-hex>/` URL → commit, never `hosts`; commit-less URL → empty (fail-loud path); hagezi `hosts/` decoy → no match. **Incident:** the first cut lacked `exit` and FELL THROUGH into the main path — it ran `git ls-remote` + refreshed SRI hashes, mutating `platforms/common/dns-blocklists.nix` (16 lines). Caught within the minute, `git restore`d (tree was clean at 22:50 — the diff was 100% this run's product), `exit` added, re-run hermetic (no network, no repo file touched). Side observation: 16/23 lists drifted again — the nightly-drift-automation row (TODO_LIST:240) remains the real fix.
4. **§c.2 deploy.sh cv OIDC smoke assertion — DONE.** Decision extracted to `scripts/lib/cv-oidc-gate.sh` (pure `cv_oidc_gate_decide <before> <after>`, byte-stable deploy-output lines; deploy.sh keeps the systemctl/sha256sum plumbing — output byte-identical to the pre-extraction gate). `scripts/check-cv-oidc-gate.sh` asserts unchanged→skip+line, rotated/absent-edge→restart, plus deploy.sh wiring greps (source + call + plumbing); selftest rejects 4 drift shapes (inverted decision, reworded unchanged-line, unwired call, deleted function); plain run green; wired as a pre-commit leg on staged deploy.sh/lib edits (parity-leg pattern; standalone hook run green rc=0 with the skip path proven). `bash -n` on all five touched shell files green; nullglob audit: 4 pre-existing warnings (flake.nix ×3, test-caddy-mint.nix), none mine.
5. **Owner Q2 (nvme0n1p8 corruption counter) — queued, not dropped:** `[blocked:user]` triage row in docs/todo/storage.md (by-id mapping across the nvme0↔nvme1 swap, magnitude reconciliation vs the documented 1.35M csum damage, device-stats delta across the next scrub).
6. **CHANGELOG:** continuation-batch bullet added under [Unreleased]/Added (an initial edit fused it with the storm-deploy bullet via a line-prefix match — caught by grep, split restored, both bullets verified intact).

### b) Deliberately NOT done

1. **Owner Q3 / §c.3 parity-leg live-fire — still deferred by the row's own constraint:** PSI some avg10 54-56% throughout; the row demands a quiescent moment AND a full pre-commit run executes `nix flake check`. Re-probe at the next calm window.
2. **Flake-check wiring for `check-cv-oidc-gate.sh`** — same no-nix-mid-storm constraint; HARVESTED as a new [ready] row on both surfaces (TODO_LIST pipeline section + pipeline.md).
3. Stretch items (§c.4) untouched — they remain open queue rows.

### Harvest log (continuation)

New follow-ups born this continuation: (1) cv-oidc-gate flake-check wiring — QUEUED both surfaces; (2) HaGeZi 16/23-list re-drift observation — deliberately not queued, tracked by the existing nightly-drift-automation row (TODO_LIST:240 + services.md:55); (3) shellcheck-absent-from-sandbox — deliberately not queued, pre-commit/CI legs own script lint, no repo gap. All closed items carry evidence pointers into this report's §a + Continuation §a.
