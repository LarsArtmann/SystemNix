# 2026-10-03 16:55 — Owner force-deploy verified, geometrikks green, tq outage + CV replay duplication root-caused, 5 fixes landed

Continuation of `2026-10-03_15-05_cutover-post-deploy-verification-and-activation-fixes.md`. Session span 15:35–16:55: the owner ran `nh os switch` (15:35, activation exit 4 — geometrikks only), then `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` (16:17, activation exit 4 — service-health-check only during activation; geometrikks STARTED). This session root-caused every remaining failure, landed 5 more module/script fixes, and left the anchoring deploy pending on the guard gate.

## a. What the deploys proved

- **15:35 activation (owner, raw nh)**: exit 4 from `geometrikks.service` ONLY — geometrikks-db-provision went green (timescaledb tolerant UPDATE + collation refresh 2.42→2.44 ×3 applied), paperless-sqlite-to-pg-migration's data work had already completed 3× at 14:36 (only its cosmetic failed/start-limit state remained), sops 3.13.3 + age 1.3.2 restored in the closure (`sops --version` live), cv-server restarted and **backfill pass 1 landed: 10,489 opportunities + 894 companies created, 0 errors** — the full missed-event replay from the 15-05 session's race fix.
- **geometrikks 15:35 failure root cause** (fix landed this session): the assets ExecStartPre's `cp -r` from the nix store **preserves store perms** (files 444, dirs 555); `rm -rf` on a 555 dir EPERMs even as owner (unlink needs the dir write bit). The 15-05 fix chmod'd *after* copying, but the tree was already locked by the 14:37 copy that died before reaching the chmod. Fix: `chmod -R u+w` heal BEFORE `rm` (owner can always chmod its own tree) — `modules/nixos/services/geometrikks.nix`. **Deployed at 16:17: geometrikks.service started green, serving 200 on :8102.**
- **16:17 activation (owner, deploy.sh forced past both gates)**: "new units were started: geometrikks.service, fastflowlm.socket". Post-switch smoke: 110 PASS / 19 FAIL / 10 SKIP / 5 WARN.

## b. The new regressions, root-caused to evidence

1. **CV ×5 smoke FAILs = transient**: cv-server was never down pre-deploy (the 16:16 pre-deploy "cv metrics not responding" was a probe timeout under the IO storm; the server ran continuously 15:35→16:17:26). The smoke probed during deploy.sh's 16:17:26 cv-server restart. Healthy since (health 200; /health/live 200).
2. **tq-serve + tq-agent-pool stopped 16:18:19, never restarted** — root cause chain: deploy.sh runs `pool-usb-recovery.service`; under the IO storm (PSI avg60 >40%, disk busy 68.9%) its 20s `ls -A /mnt/pool` health probe timed out → "stale mount" verdict → `systemctl stop mnt-pool.mount` → systemd propagated the stop to mount-bound units (implicit RequiresMountsFor: tq-serve, tq-agent-pool — tq.db is on the pool — and btrbk-pool-clean, SIGTERM mid-run, status 15) → pool remounted healthy → `converge_consumers` restarted only the 9 listed units — **tq was not in `restartUnits`**. Fix: `pool-recovery.nix` restartUnits += tq-serve/tq-agent-pool (the module's own documented class: "deliberately hand-stopped units come back on the next recovery run"). tq returns at the next pool-usb-recovery run (the anchoring deploy runs it) or reboot.
3. **btrbk-pool-clean failed = same mount-stop propagation** (not the guard — it is not in any guard list). Its own timer re-runs it; an interrupted receive self-heals on the next run per the module docs. No fix needed.
4. **paperless-gpt-token EPERM**: `/run/paperless-gpt/env` is chowned to the gpt user at 0400 by each mint's ExecStartPost; the NEXT mint's `>` O_TRUNC EPERMs as the paperless user. **Same class as the geometrikks alembic.ini bug** (stale read-only file + O_TRUNC/EPERM). Fix: `rm -f "$MINT_OUT"` before the printf (dir is paperless-owned 0711) — `paperless-gpt.nix`.
5. **service-health-check failing every run = correct symptom reporting** (tq/flm/forgejo down). Heals when they return.
6. **node_exporter textfile blindness (pre-existing, fixed)**: `system_health.prom` rejected WHOLE-FILE by node_exporter — wants-symlink unit names are systemd-escaped (`gitea-runner-evo\x2dx2.service`) and `\x` is an invalid Prometheus escape → every `system_*` metric dark. Fix: decode `\x2d`/`\x5f` + prom-escape survivors in `system-health.nix`. Also `paperless_tasks.prom` was 0600 (mktemp→mv without chmod — the one collector missing the house `chmod 644` pattern) → unreadable → skipped. Fix: `chmod 0644` in `paperless.nix`.

## c. CV→CRM replay duplication (STOP-SHIP class — deploy.sh gated)

deploy.sh's unconditional "Restarting cv-oidc-env.service + cv-server.service (reload OIDC client secret)" step (scripts/deploy.sh:620-624) restarted cv-server at 16:17:26 → in-memory idempotency reset → **full replay from zero again: 10,489 MORE opportunities created (distinct crm_ids) — the CRM now holds ~20,978 opportunities, half of them duplicates**. Companies dedupe cross-restart (find-before-create, 0 duplicate company creates); opportunities do NOT.

Fix landed: deploy.sh now sha256-compares `/var/lib/cv-oidc/client-secret.env` across the cv-oidc-env restart and only restarts cv-server when the secret actually changed. **Residual risk**: a genuinely rotated secret still forces a restart → full replay → duplication again, until the CV syncer grows a durable replay checkpoint (CV repo, owner-gated). Dedupe of the current duplicates should happen AFTER that fix (or accept re-dup risk), via the CRM UI/API as lars.

## d. The IO storm (meta-context)

Guard trips #1773–#1778+ all day, every build/deploy/battery feeding avg60 >40%; flm socket restore CAPPED (3/3 by 16:10 — manual `systemctl start fastflowlm.socket` is the documented owner action once PSI calm; ties into the stability.md restore-cap policy decision). At 16:45+ the storm showed 2.1 MiB/5s actual throughput with high PSI (journal-flush churn class; no D-state pile, no USB kernel events). The anchoring deploy waits on a gate-aware loop (guard trips in trailing 60 min == 0 AND PSI some avg10 < 20).

## e. Security finding (flagged, not fixable from SystemNix)

`crm-server` receives its machine API token as a **plain ExecStart argument** — systemd expands `${API_TOKEN}` from the EnvironmentFile into argv before exec, so the resolved token is visible in `ps`/`/proc/*/cmdline` to every local user (`modules/nixos/services/crm.nix`). The sops hygiene is otherwise correct (token reaches PID1 via EnvironmentFile). The app reads `apiToken` ONLY from the `-api-token` flag (`/home/lars/projects/crm/cmd/crm-server/main.go:482` — no env fallback, no file flag), so the fix needs a cr-repo change (env read or `-api-token-file`) + rev bump. Queued [blocked:user] alongside the CV fix.

## f. Follow-ups (self-harvested at authoring time)

1. [blocked:user, services.md] crm-server: take the API token from env/file instead of the `-api-token` flag (cr repo change) so SystemNix can drop it from ExecStart argv — §e.
2. [ready, TODO_LIST] Post-anchoring-deploy verify batch: tq-serve/tq-agent-pool up (pool-usb-recovery converge), paperless-gpt-token mint result=success, `system_*`/`paperless_tasks_*` metrics present on :9100, `/run/current-system` anchored to the newest profile (reboot no longer reverts), activation exit 0.
3. [blocked:user, services.md] CV syncer durable replay checkpoint + cross-restart opportunity idempotency (CV repo; unblocks safe dedupe) — §c.
4. [blocked:user, services.md] CRM dedupe ~10,489 duplicate opportunities (created 16:17:26–16:19:47 window; after f.3) — §c.
5. [blocked:user, stability.md] flm socket manual restore (restore-capped 3/3 today) — §d.
6. [watch, stability.md] pool-usb-recovery false-stale remount under IO storm (20s probe; consider guard-style disk-busy corroboration) — §b.2.
7. The prior 15-05 report's §f (32 items) was NOT yet harvested — owner instruction pending ("harvest when instructed"); this report does not cover it.

## g. Owner questions

1. **Anchoring deploy**: `/run/current-system` != system-813 profile — **a reboot WILL revert to the 15:35 generation** (which lacks the geometrikks perm-heal — harmless on the now-healed tree — and lacks today's 5 fixes). My delayed loop will deploy once the guard gate clears (60 min trip-free + PSI <20); force (`DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`) if you want it sooner. The deploy also brings tq back.
2. **CRM duplicates**: confirm dedupe sequencing (after the CV-repo checkpoint fix? via UI as lars?) — ~10,489 duplicate opportunities are live in the CRM now.
3. **crm.nix token-on-cmdline**: queued [blocked:user] — needs a cr-repo env/file option first (see §e); bundles naturally with the CV syncer rev bump.

## Addendum (17:15, anchoring landed + one more layered bug)

**The owner preempted the gated loop and ran the anchoring deploy manually at 17:00:07** (interactive fish on pts/1, same SSH session that forced 16:17). Deploy **exit 0 at 17:07:41 after 450s**; log `/var/log/systemnix-deploys/2026-10-03_17-00-11.log`; **new profile generation: system-814** (`/run/current-system` == `system-814-link` == `kjzj5qa9…` — anchored, reboot-safe). Smoke 121 PASS / 12 FAIL / 9 SKIP / 4 WARN — **all 12 FAILs match the previous run's baseline, advisory exit 1, no new regressions**.

Verify battery, item by item against §f.2:

- activation exit 0 ✓; profile anchored ✓ (all three links agree)
- **tq-serve + tq-agent-pool ✓** — restarted 17:05:07 by pool-usb-recovery converge (the restartUnits fix proving itself); :8100 answers 200; budget note "30/30 tasks enqueued today"
- **paperless-gpt-token ✓** — mint Finished 17:06:10, no EPERM (rm -f fix proven live)
- **`system_*` metrics ✓** — 10 `system_unit_enabled_inactive` series with REAL unit names (`activitywatch-watcher-aw-watcher-utilification.service` — decoded, not `\x2d`-escaped); the \x-escape fix works
- **NO third cv replay ✓** — deploy log line: `cv OIDC env unchanged — cv-server NOT restarted (avoids CRM replay duplication)`; the sha256 gate fired as designed; cv :8098 /health/live 200 on the untouched process
- **`paperless_tasks_*` ✗ — one MORE layered bug found and fixed.** The 0644 chmod fix made node_exporter READ the file for the first time, and it fails to PARSE: line 18 `paperless_inbox_count ` (empty value). Root cause is two-layered:
  1. `WHERE t.slug = 'inbox'` — **paperless ≥3.1 moved Tag to TreeNodeModel and the `slug` column no longer exists** (`ERROR: column t.slug does not exist` in the collector journal). The version-proof column is `is_inbox_tag` (present in both 3.1.3 and 3.2.1 models).
  2. **psql exits 0 on SQL errors by default** — so `|| fail=1` never fired, `collector_success` read 1 (round-trip "succeeded"), and the empty value poisoned the whole .prom. Fix: `-v ON_ERROR_STOP=1` in the collector's PSQL (fail-closed now actually closes).
  Both landed in `modules/nixos/services/paperless.nix` (eval-verified, drv `3p2l1mvq…`); deploy rides a NEW transparent gated loop (0C7: same gate — 0 guard trips in trailing 60 min AND IO PSI some avg10 < 20 — replacing the opaque 08B loop). Residual open item is the narrowed TODO_LIST/services.md row.
- geometrikks ✓ (:8102 HTTP 200, still green), btrbk-pool-clean ✓ (self-healed 17:06, clean no_action run)

**Baseline FAIL ownership (all pre-existing, none new):** Forgejo = deliberate `ConditionPathExists=/var/lib/forgejo/.subvol-migrated` gate (subvol migration pending since 10-01, tracked in storage.md/services.md); FastFlowLM = guard restore-cap, owner manual restore once PSI calm; CV render = ONLY the `/de/cv` leg, known IO-PSI false-FAIL (TODO_LIST row: CV render smoke IO-pressure-aware); Bank-Sync = Wise event `version_conflict` on save (app-level, restart-cumulative counter keeps smoke red — windowing row already queued; execution trace auto-captured at `/mnt/pool/services/bank-sync/traces/`); Desktop polkit = long-standing 2026-08-18 class; memory PSI calm (0.00%), IO still saturated (avg10 ~80% during the deploy's own eval).

**Storm/guard at addendum time:** trips #1777–#1781 in the trailing hour (16:13–16:59); nix-daemon IO during the deploy was the deploy's own pre-deploy-check eval (the heavy `systemd.services` ExecStart audit), not a separate runaway. Thermal/cooling inspection (freeze #12) still stands as the owner action.

## Addendum 2 (20:20, gated deploy still storm-bound — loop handed forward)

The gated deploy loop for the paperless collector fix ran its full 3h window (17:14–20:12, 90 polls): the IO storm never opened the gate — guard trips continued hourly (#1783 17:19 → #1789 19:24, drivers alternating user-1000.slice and nix-daemon.service, i.e. the parallel agent sessions' own workloads; clickhouse joined at #1789) and IO PSI some avg10 oscillated 20-70% without ever coinciding with a trip-free hour. A fresh 6h loop is armed (same gate). **The fix itself is DONE in-tree** (paperless.nix: `is_inbox_tag` + `-v ON_ERROR_STOP=1`, eval-verified drv `3p2l1mvq…`, daemon-swept); only its activation waits for calm. If the owner wants it sooner: `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` (their precedent, twice today) — it is a cached, metrics-only change. Verify after any deploy: `paperless_tasks_*` + `paperless_inbox_count` present on :9100, `node_textfile_scrape_error` 0, and the collector journal free of `t.slug` errors.
