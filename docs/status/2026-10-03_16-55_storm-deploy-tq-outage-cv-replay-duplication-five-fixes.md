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
