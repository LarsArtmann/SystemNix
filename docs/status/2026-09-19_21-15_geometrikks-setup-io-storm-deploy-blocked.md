# Status Report — GeoMetrikks Setup Session (2026-09-19, ~17:15–21:15)

**Task given:** "Setup: https://github.com/GilbN/geometrikks ??" — then repeated
READ/UNDERSTAND/RESEARCH/REFLECT/EXECUTE/VERIFY directives, ending with this
full status report (this session's run only).

**TL;DR:** GeoMetrikks is FULLY CONFIGURED, COMMITTED, and `nix flake check`
PASSES. The ONLY unfinished step is the deploy — blocked ~2h by a sustained
host IO storm (io PSI avg10 27–98%, Zone-6-class emergency active). Per
doctrine (freeze #5/#6), the deploy is QUEUED, not raced. Docker images are
pre-pulled, so the switch will be short once pressure drains.

---

## a) FULLY DONE

1. **Research phase** — upstream README/compose/.env fetched and understood;
   deployed-Caddyfile log topology traced (per-vhost sinks, global idle);
   nixpkgs caddy `vhost-options.nix` read (log filename rule: `/`+` `→`_`);
   Caddy docs confirmed file output ⇒ default encoder is **JSON** (no
   caddy.nix changes needed).
2. **Image pins** (`lib/images.nix`): `ghcr.io/gilbn/geometrikks` tag
   `0.16.0` + digest `sha256:59b80fda…c7735`; `timescale/timescaledb-ha` tag
   `pg18` + digest `sha256:b86177c6…dd1e4`. Tag trap documented: GHCR tags are
   UNPREFIXED (`0.16.0`; `v0.16.0` = "manifest unknown"). Digests verified
   against the registry.
3. **Port 8102** registered in `lib/ports.nix`; **DNS `geo`** added to
   `platforms/common/dns-local.nix`.
4. **Sops secrets** `platforms/nixos/secrets/geometrikks.yaml` created and
   encrypted (public-key only, no sudo): random admin password, random DB
   password, MaxMind/CARTO keys EMPTY (geo-degraded = documented off state).
   Staged with `git add -f`.
5. **Module** `modules/nixos/services/geometrikks.nix` (manifest.nix
   pattern): compose (app + timescale_db with upstream's LOAD-BEARING worker
   tuning), sops env template, `TimeoutStartSec=15min`, nightly 05:15
   pg_dump backup to `/mnt/pool/backups/geometrikks`, registry entry
   (protected vHost `geo.home.lan`, Gatus check, homepage tile `mdi-earth`,
   `monitored=true`, backup freshness).
6. **Eval-derived log tailing**: `LOGPARSER_LOG_PATHS` = JSON list built from
   `config.services.caddy.virtualHosts` + global `access.log` — new services
   auto-tracked. A first-draft bug (`access-access.log.log`) was caught in
   rendered-output verification and fixed BEFORE deploy.
7. **Enablement** in `configuration.nix`; module `git add`ed (tracked-files
   trap avoided).
8. **Verification that could run**: focused evals green (ExecStart, registry
   checks JSON, sops template content incl. fixed LOGPARSER list, env
   placeholders); **`nix flake check --no-build` → all checks passed**
   (includes port-registry-audit, sops-key-audit, mount-gating,
   deploy-restart-audit, systemd-shape-audit, gatus-pattern-lint).
9. **Both Docker images pre-pulled** on the host (digests verified by the
   daemon) — the ~2.5 GB timescaledb-ha pull will NOT happen during the
   switch.
10. **Docs**: runbook `docs/services/geometrikks.md` (architecture, login
    retrieval one-liner, go-live steps, gotchas); `[blocked:user]` go-live
    row appended to `docs/todo/services.md`; AGENTS.md `### GeoMetrikks`
    section written (with the PUID=0 rationale and do-NOT-"fix" warnings).
11. **Session-report diligence**: pressure-gate behavior, guard state, and
    poller telemetry captured in this report.

## b) PARTIALLY DONE

1. **DEPLOY — blocked, queued.** First `nix run .#deploy` exited 12
   (pressure gate: io avg10 34.55% + disk busy 101%). The storm persisted
   ~4h (avg10 27–98.97%, avg60 ~47–85%, disk busy 100% peaks, MemAvailable
   22–28%, zram 0%, memory fine). Zone-6-class guard lines confirmed
   ("crash #3 class: stacked full-disk readers livelocking the scheduler";
   flm socket already sacrificed, action-cooldown cycling). Two pollers ran
   65 + 60 min; a third auto-deploy watcher fires only after 3 CONSECUTIVE
   green polls (<15 avg10) — still waiting at report time (21:13:
   58.31/53.10). `nix flake check` + toplevel build are DONE and cached, so
   the eventual switch is short.
2. **Post-deploy verification — not yet possible**: `/health/ready` probe,
   login render, ingestion proof (gatus traffic ⇒ events within minutes),
   Gatus check green, tile, backup dir, `docker compose ps` health states.
   All steps are written down (runbook); zero thinking left for that phase.

## c) NOT STARTED

1. **User-gated go-live** (tracked in `docs/todo/services.md`): MaxMind
   GeoLite2 free signup + key paste; optional CARTO key; first login as
   `admin` (password via the Sops+Age one-liner); visual map check.
2. Historical `.gz` access-log backfill via upstream `litestar import-logs`
   (deliberately scoped out; raw rotations are 90d-retained, so backfill
   stays possible later).
3. GeoMetrikks VM test (`tests/test-geometrikks.nix`) — the module follows
   the proven manifest shape and is eval-guarded, but has no VM regression
   (manifest has none either; noted for parity review, not urgent).

## d) TOTALLY FUCKED UP

1. **Nothing destructive, nothing lost.** Honest misses:
   - Ran `curl` via bash twice (banned in this tool sandbox — tool refused
     it; switched to `docker manifest inspect` + fetch tool).
   - Ran `nix fmt --no-update-lock-file -- --ci <file>` and it MODIFIED the
     file anyway (misread flag semantics; outcome benign — formatter output
     is canonical, diff reviewed).
   - Two `edit` collisions with the parallel session on
     `configuration.nix` (mod-time rejections) — handled by re-read+retry,
     but I initially missed that the file had been read seconds before
     their write; cost 2 dead cycles.
   - First sops-file creation and module write raced the auto-commit
     daemon twice — my in-flight files were swept into heuristic batch
     commits (f590b262 batching BOTH my files and the parallel session's
     health-dashboard work). Contents verified afterwards with
     `git show --stat`; nothing corrupted; known daemon behavior, worth
     remembering for pathspec-commit discipline.

## e) WHAT WE SHOULD IMPROVE

1. **The deploy-pressure storm class needs an owner decision**: ~4h of
   27–98% io PSI from ~6 concurrent crush-agent sessions (each 10–20 GB
   cumulative writes) + parallel-session builds. The structural fix
   (crush-hot-db migration FIRST RUN) still shows "not yet run" in AGENTS
   — re-check whether it has fired since 2026-09-16; if not, the queue is
   permanently vulnerable to this block.
2. **Status of the queued deploy must be checked in the NEXT session**
   (deploy log `/tmp/deploy-geometrikks2.log` appears only if the watcher
   fired; no geometrikks containers exist as of 21:13).
3. **Caddy per-vhost log retention**: nixpkgs defaults roll at 100MiB/keep
   10/**90 days** on the QLC root (btrbk snapshot bloat). We now have a
   consumer (GeoMetrikks) for ~7 days of raw logs at most — consider
   explicit `logFormat` overrides (`roll_keep_for 168h`) in a follow-up,
   deliberately NOT bundled into this feature change.
4. **Global `access.log` is near-useless** (only un-matched traffic; last
   real write 12:09 today) — anyone tailing it sees ~nothing. Worth a
   gotcha line in docs if anyone debugs via that file.
5. **`pre-deploy-check`'s pressure gate + my workflow**: the gate worked as
   designed; consider a "queued-deploy" helper app (`nix run .#deploy-when-green`)
   wrapping the 3-green-poll loop I hand-rolled, so deploys self-queue
   instead of dying at exit 12 during multi-agent days.
6. **Post-deploy smoke block for GeoMetrikks** in
   `scripts/post-deploy-check.sh` (health/ready + login page) — skipped
   this session to limit shared-file churn during the parallel
   health-dashboard work; queue it.
7. **Sandbox constraint handling**: I attempted `sudo`/`systemctl`/`curl`
   before remembering all three are denied (docs/todo already records
   "sandboxed agent sessions are denied both"). A pre-flight mental check
   for live-probe tasks would have saved 3 refused calls.

## f) NEXT THINGS (prioritized)

1. Verify pressure drained → complete the deploy (`nix run .#deploy`) and
   confirm profile anchoring (`readlink /run/current-system` vs numbered
   profile).
2. Post-deploy verification battery: `docker compose ps` (both healthy),
   `/health/ready` 200 via loopback, login page renders, DB initialized,
   events flowing within ~1 min (gatus traffic), Gatus "GeoMetrikks" green,
   tile renders, `geo.home.lan` resolves + vHost serves (LAN bypass).
3. Confirm sops rendered the env (`/var/lib/geometrikks/.env` exists 0600
   root) and the app started WITHOUT the admin-password refusal.
4. Trigger/start `geometrikks-db-backup` once manually; verify the pg_dump
   lands in `/mnt/pool/backups/geometrikks/` (first-run proof).
5. Verify backup-coordination picked up the freshness entry (dashboard row
   appears).
6. Check ingestion actually parses caddy-json (UI log rows populated; if
   auto-detect failed, pin `LOGPARSER_LOG_FORMATS=caddy-json` and redeploy).
7. Watch the first rotation cycle (100MiB) for tail-follow survival across
   Caddy's rename-rotation.
8. User: MaxMind signup + key paste (go-live row in todo/services.md).
9. User: optional CARTO key paste.
10. User: first login + visual map sanity (browser session).
11. Add post-deploy smoke block for GeoMetrikks (§e.6).
12. Decide Caddy per-vhost `roll_keep_for 168h` override (§e.3).
13. Decide the deploy-when-green helper (§e.5).
14. Re-check crush-hot-db first-migration status (§e.1) — structural fix
    for the whole queue-blocked class.
15. Update AGENTS.md after first live deploy with the deployed-generation
    note + any runtime surprises (rotation behavior, parse evidence).
16. Harvest this report per docs-health (VERIFY items against code next
    pass; `[ready]` items already filed).
17. GeoMetrikks version-bump doctrine note: upstream releases weekly-ish;
    bump = `docker manifest inspect` new tag + digest refresh in
    images.nix (check-image-updates.sh will flag digest drift daily).
18. Consider upstream filing: `.env.example` says PUID "app runs as" but
    root-running requires PUID=0 support confirmation (worked here per
    upstream default flow; if the entrypoint ever refuses PUID=0, fallback
    documented in runbook gotchas).
19. Optional: `litestar import-logs` backfill of the .gz history (§c.2).
20. Optional: SigNoz dashboard panel for geometrikks container metrics
    (cadvisor already scrapes docker; a panel is cheap if wanted).
21. Re-arm `fastflowlm.socket` after the storm drains (guard restore is
    capped — check `restore_capped` after the deploy window).

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Deploy risk acceptance**: the storm has run 4h with 98% saturation
   peaks. Doctrine says queue (I queued). If it persists into tomorrow:
   do you want `DEPLOY_FORCE_PRESSURE=1` (cached toplevel, short switch,
   images pre-pulled — materially lower risk than freeze #5's four-race),
   or keep strict queuing?
2. **Is the current storm intentional?** ~6 crush agents + the parallel
   health-dashboard session are driving it. If that's unexpected/runaway,
   name the culprit and I'll investigate; if it's normal multi-agent work,
   the queue just waits it out.
3. **MaxMind/CARTO**: will you paste the keys yourself via the sops
   one-liner (runbook), or should the next session prompt you for values
   through the interactive `sops` editor path?

---

**Session evidence anchors**: deploy gate log `/tmp/deploy-geometrikks.log`
(exit 12); watcher logs in session; guard journal `-u memory-emergency-guard`
(Zone-6 class lines 19:00–19:05); daemon commits `f590b262`, `616489e6`,
`be621000`, `7436edec`, `9c0911f6`, `a1795f86` carry this session's files.
