# GeoMetrikks Resume Session — Storm Watch, Build Retry, Deploy Still Queued

**Date:** 2026-09-19 23:47
**Session:** Resume of the 21:15 report (`2026-09-19_21-15_geometrikks-setup-io-storm-deploy-blocked.md`). Task: deploy GeoMetrikks (`services.geometrikks`, access-log geo analytics on `geo.home.lan`) and verify end-to-end.
**Headline:** The deploy is STILL blocked ~6.5 hours into a sustained IO storm, but this session produced: proof the storm is now **build-driven and dangerous** (MemAvailable dipped to **6.5–8.2%**, zram **82%**), a **failed first build attempt** (my own pipeline-masking mistake, then fixed), discovery that **the lock moved under me mid-session** (parallel session bumped nixpkgs + re-locked dnsblockd), a **full eval-level verification sweep of every GeoMetrikks surface** (all green), and **build #2 with `--keep-going`** now running to enumerate the real failure.

---

## Live state at report time (23:47)

| Signal | Value | Verdict |
| --- | --- | --- |
| io PSI some avg10 / avg60 | 21.6% / 30.9% (decaying from 57/45) | Storm finally draining, still above the 20% deploy gate |
| MemAvailable | **8.1G (6%)** | **DANGER — below the 10% gate floor; was 6.5% in guard samples ~23:00** |
| zram fill | ~82% (51.5G of 62.2G swapped) | Approaching the 90% zone; memory-emergency-guard active, flm socket sacrificed (restore capped at 3/day) |
| Guard journal | "crash #3 class: stacked full-disk readers", disk busy bursts **100%**, MemAvailable 6.5–16.9% over the last hour | Real storm, not just PSI-latency phantom |
| Deploy log `/tmp/deploy-geometrikks2.log` | **EMPTY — watcher #3 never fired** | Deploy never attempted |
| Build #2 (job 068, `--keep-going`) | RUNNING | First full failure enumeration in progress |
| git HEAD | `eb8cc186` (tree clean, all work committed) | Moving shared surface — 2 more daemon commits since 22:45 |

## Storm timeline (this session's evidence)

- **21:16–22:45** — watcher #3 (inherited job 045) polled 90×, io avg10 swung **17–85**, never 3 consecutive green readings, expired with `WATCHER3-DONE` and never fired the deploy.
- **22:48** — my own first diskstats sample: near-zero throughput, PSI still 35 — initially read as "drained"; **the guard's 30s samples contradicted this**: disk busy bursts to 100%, crash-#3-class message. Lesson: my 6s samples caught quiet windows; the guard sees the bursts.
- **22:49–23:05** — I started the toplevel pre-build (job 052). Concurrent builds: mine + `nix build -L .#telephony-browser` + `nix build . --keep-going` (two parallel agent sessions). Load spiked to **107**; io PSI avg10 bounced 31–57.
- **~23:00–23:20** — guard samples show the storm's worst: **MemAvailable 6.5–8.2%**, disk busy 100% bursts, io avg60 42–48%. Three concurrent builds squeezed memory; SwapFree fell 27.7G → 10.8G.
- **23:05** — build #1 FAILED: `Cannot build …nixos-system-evo-x2-26.11.20260917.e554fab.drv, 1 dependency failed` — but my `| tail -5` had **masked both the exit code and the failure detail** (see §d). The nixpkgs rev in the error (`20260917.e554fab`) revealed the **lock had been bumped mid-session** by the parallel session (HEAD commit `e0f74cd9` "fix: re-lock dnsblockd for its go 1.27.1 toolchain wiring (upstream 4770802)") — the tree I verified at 22:45 is not byte-identical to the tree the deploy will build.
- **23:20+** — build #2 launched correctly: `--keep-going`, full output → `~/.local/state/deploy-geometrikks/build2.log` (durable path, NOT /tmp — the tmp-cleaner lesson). Still running at 23:47.
- **23:47** — PSI decaying (21.6 avg10) but MemAvailable **6%** and zram 82% — the box is at the freeze edge while three agent sessions build concurrently.

---

## a) FULLY DONE

1. **Watcher #3 disposition confirmed** — expired at 22:45 after 90 polls / zero green streaks; `/tmp/deploy-geometrikks2.log` empty; no deploy fired. (Inherited from prior session; verified, not re-run.)
2. **Storm root-cause identification** — the persistent storm is now **concurrent-build-driven** (3 nix builds + parallel test suite), NOT the throughput storm of the afternoon. Evidence chain: per-process 5s IO deltas = **0 KB/s for all top cumulative-IO processes** (`tq` 609G and the crush agents' 100G+ are all-time totals); guard samples show 100% busy **bursts** + MemAvailable degradation to 6.5%; zero D-state processes (no corpse pile, no dead-automount phantom).
3. **crush-hot-db migration state established** — `/mnt/hot/crush` IS populated (migration partially ran at 15:41 per prior session), but `~/projects/*/.crush` dirs for live-crush projects remain real dirs: the **pgrep guard correctly skips projects with live crush sessions**, so completion needs a quiet window. The unit's journal shows no run in the last 3h.
4. **Deploy gate mechanics re-verified from source** — `scripts/deploy.sh:230–315`: blocks at mem PSI ≥20 OR io PSI ≥20 (with disk-busy corroboration branch + D-state-phantom branch, both of which still block), zram ≥95% + PSI ≥5 combined zone, `DEPLOY_FORCE_PRESSURE=1` escape hatch.
5. **Eval-level verification sweep of EVERY GeoMetrikks surface — ALL GREEN** (this is the session's main deliverable; each checked against the RENDERED config, not source):
   - **sops template `geometrikks-env`**: `LOGPARSER_LOG_PATHS` renders the full 34-entry vhost-derived list, global `access.log` first, **no `.log.log` double-suffix** (the pre-deploy-caught bug confirmed fixed in the committed tree); `APP_ADMIN_USER=admin`, `APP_AUTH_DISABLED=false`, `APP_SESSION_SECURE=true`, `APP_TRUSTED_PROXIES=172.32.0.0/24`, `LOGPARSER_HOST_NAME=evo-x2`; MaxMind user/license + CARTO render as `<SOPS:…:PLACEHOLDER>` (geo-degraded go-live state as designed); passwords present (redacted in my output, lengths verified by pattern).
   - **Gatus check "GeoMetrikks"**: `http://localhost:8102/health/ready`, 30s interval, `[STATUS] == 200` + `[RESPONSE_TIME] < 1000`, group Monitoring, **Discord + custom (PapDashboard ingest) alerts** — registry fan-out confirmed in the rendered `services.gatus.settings.endpoints`.
   - **Integration registry entry** (`services.integration.geometrikks`): `enable=true`, `port=8102`, `subdomain="geo"`, `vHost.layer="protected"`, `monitored=true`, `homepage={group="Infrastructure", description="Access-log geo analytics (live world map)", …}`, `backup={directory="/mnt/pool/backups/geometrikks", maxAgeHours=31}`, checks wired.
   - **Backup timer**: `systemd.timers."geometrikks-db-backup".timerConfig.OnCalendar = "*-*-* 05:15:00"`; backup exec = `docker-compose exec -T timescale_db pg_dump -U geouser geometrikks` → dated `.sql` + 14d retention cleanup. (`services.geometrikks.backup` is NOT an option path — the registry entry above owns the values; my first eval guess at that path was wrong, corrected.)
   - **Caddy vHost `geo.home.lan`** (rendered `services.caddy.virtualHosts`): TLS 1.2/1.3 via dnsblockd certs, full security-header block, encode zstd/gzip, 10GB body limit, **protected layer exactly as designed** — `@external not remote_ip (loopback/LAN)` → forward_auth oauth2-proxy :4180 with Pocket-ID sign-in redirect; LAN handle → direct `reverse_proxy localhost:8102`; **per-vhost access log = `output file /var/log/caddy/access-geo.home.lan.log`** which byte-matches the container's ro-bind ingestion path (`access-geo.home.lan.log` in LOGPARSER_LOG_PATHS).
   - **DNS**: `"geo"` present in `platforms/common/dns-local.nix:34`.
   - **Docker backend**: `virtualisation.oci-containers.backend = "docker"`; `mkDockerService` wires `docker-compose --env-file <sops-template> -f <composeFile> up --remove-orphans` (`lib/docker.nix:86–93`) — the `${VAR}` substitution design holds.
6. **Pre-deploy battery PASSED pre-storm-drain** — `nix run .#pre-deploy-check`: **64 passed, 18 warnings, 0 failed**. §10 metric presence: all current metrics present, `storage_collector_health` auto-loaned as known-new; §12: all 251 ExecStart binaries exist (5 "not built yet" warnings are expected pre-build layout checks, incl. hermes 0.21.3).
7. **Multi-agent tree drift detected and adapted to** — HEAD moved `6e62d51d` → `e0f74cd9` (dnsblockd re-lock + nixpkgs `b1b8759`→`e554fab`) → `f270ca9c` → `eb8cc186` during the session; working tree clean throughout; my geometrikks changes confirmed present at every HEAD (pathspec-verified in commits `a1795f86`/`616489e6`/`be621000` lineage).
8. **Doctrine held under pressure** — did NOT force-deploy despite 6.5h of blocking; the guard's crash-#3 classification + MemAvailable 6.5% makes force indefensible (freeze #5 died 9s into activation in a materially BETTER state than 23:00 tonight).

## b) PARTIALLY DONE

1. **Toplevel build for the deploy** — build #1 failed (1 dependency failed, details lost to my output masking); build #2 (`--keep-going`, full log at `~/.local/state/deploy-geometrikks/build2.log`) RUNNING at report time. The build is REQUIRED for deploy and its result gates everything below.
2. **The deploy itself** — blocked by the pressure gate for ~6.5h. Correctly queued, not raced. Needs: build #2 green + io PSI avg10 <20 + MemAvailable comfortably >10% (ideally >20%) at the same moment.
3. **Post-deploy verification battery** — fully specified (prior session §"Exact next steps" + this session's eval-verified expectations) but zero items executable until containers exist.
4. **crush-hot-db structural storm fix** — partially migrated; blocked on live crush sessions by design. The QLC `.crush/` churn class continues until it completes.
5. **fastflowlm re-arm** — socket stays DOWN (restore capped 3/3 today, per guard journal). Re-arm is a post-storm manual step (`systemctl start fastflowlm.socket`), user-gated or next-session.

## c) NOT STARTED

1. Post-deploy: container health verification (`docker ps` — `geometrikks-app-1` + `geometrikks-timescale_db-1` healthy; images pre-pulled so no pull IO).
2. Post-deploy: `/health/ready` probe via python urllib (curl is sandbox-banned) expecting 200.
3. Post-deploy: `/var/lib/geometrikks/.env` exists, root 0600, sops-rendered (placeholders resolved to real secrets or inert empties).
4. Post-deploy: ingestion proof — gatus' 30s probes against all vhosts should produce parse events within ~1 min; check app logs; if auto-detect fails, pin `LOGPARSER_LOG_FORMATS=caddy-json` + redeploy (runbook has the one-liner).
5. Post-deploy: Gatus "GeoMetrikks" check green (probe the endpoint directly; the gatus DB route needs root).
6. Post-deploy: `geo.home.lan` serves the login page on LAN (protected layer bypasses oauth2-proxy locally).
7. Post-deploy: PapDashboard tile + services.json contains GeoMetrikks; system-health `monitored` row live.
8. Post-deploy: backup proof — `geometrikks-db-backup.service` start (systemctl is sandbox-banned for me → user command or next deploy's provisioner loop), `.sql` lands in `/mnt/pool/backups/geometrikks/`, backup-coordination freshness row (maxAge 31h).
9. `nix run .#post-deploy-check` full smoke battery.
10. GeoMetrikks smoke block in `scripts/post-deploy-check.sh` (so future deploys self-verify the service).
11. Caddy per-vhost `roll_keep_for 168h` retention decision (100MiB×10 rolls currently; geo analytics make retention a user call).
12. `deploy-when-green` helper (see §e/§f — three watchers have now died of short horizons).
13. MaxMind GeoLite2 signup + key paste via sops (user-gated, carried from prior report).
14. CARTO basemap key paste (user-gated, carried).
15. First admin login (`admin` + password from sops) + visual map sanity check (user-gated, carried).

## d) TOTALLY FUCKED UP

1. **My build #1 failure was hidden BY ME** — I piped the build through `tail -5` without `pipefail` or rc capture: the pipeline printed a masked tail INCLUDING a `BUILD-EXIT=0` echo that lied (it echoed the tail's status, not nix's). This repo documents this EXACT trap ("`nix build … | tail` chains mask FOD/eval exit codes — always `set -o pipefail`… always capture rc", AGENTS.md 2026-09-17 wave lesson) and I repeated it anyway. Cost: ~25 min before I noticed the process was gone, re-ran with `--keep-going` + unmasked full log. The fix pattern is now applied: output → `~/.local/state/deploy-geometrikks/build2.log`, rc echoed unconditionally.
2. **I initially mis-read the storm as "drained" from 6s diskstats samples** and nearly upgraded my assessment to "deploy window near". The guard's 30s journal (100% busy bursts, MemAvailable 6.5%) was the ground truth; my sample caught a quiet inter-burst window. Sampling-window bias on a bursty signal — the guard exists precisely because of this. (Caught before any wrong action; no damage.)
3. **My own build added to the storm's worst hour** — starting the toplevel build at 22:49 put a third concurrent build into the exact window where MemAvailable fell to 6.5%. It is required work in the sacrificial tier (BFQ BE/7, Nice 10, MemoryHigh 32G — designed for this), but a stricter reading of "queue the deploy" would have also deferred the build until the parallel sessions' builds finished. Judgment call I'd repeat under time pressure but should flag: on a box with a 6%-MemAvailable cliff, "build now vs build at the green window" deserves the same explicit gate as "switch now vs switch at the green window".
4. **Watcher horizons keep losing to storm duration** — watcher #3 (inherited) had a 90-min horizon against a 6.5h+ storm; watchers #1–#3 all expired without firing. Not a new failure tonight, but the third consecutive instance: the queueing mechanism itself is under-engineered for multi-hour storms (see §e).

## e) WHAT WE SHOULD IMPROVE

1. **`deploy-when-green` as a real helper, not ad-hoc watcher shells** — requirements learned from three dead watchers: horizon ≥6h (storm outlives 90 min), green rule = N consecutive polls (3× io avg10 <15 today; also require MemAvailable >20% — tonight proved PSI-only gates are insufficient), lock-free single instance, heartbeat log to a durable path (`~/.local/state/`), and post-fire exit-code capture. Either a script in `scripts/` or a tiny systemd user timer; the systemd route survives session death, which ad-hoc shells don't.
2. **Add MemAvailable to the watcher green rule** — tonight's storm had PSI and memory moving in OPPOSITE directions at times (PSI decaying while MemAvailable hit 6%). A PSI-only green window could have fired a switch into a 6%-memory box.
3. **Build-phase pressure awareness in deploy.sh (idea, needs owner decision)** — the gate protects the SWITCH; nothing protects the BUILD that precedes it. A pre-build check (warn or defer when MemAvailable <15% with ≥2 concurrent nix builds) would prevent the 23:00 squeeze pattern. Tradeoff: builds are the sacrificial tier by design; forcing serialization could starve throughput on a multi-agent box.
4. **Multi-agent deploy coordination is still handshake-by-luck** — three sessions built concurrently tonight; my deploy will carry their lock bumps (`e554fab` nixpkgs, dnsblockd re-lock) unreviewed-by-them. The deploy-lock (rc=13) prevents concurrent SWITCHES but not concurrent TREE MOVEMENT. A minimal convention (e.g., a `~/.local/state/deploy-claim` note with session+scope, checked by deploy.sh's prelude) would make "who is about to deploy what" visible.
5. **Status-report timestamps in file names vs reality** — minor: this session's report lands at 23:47 but the watcher logs / guard journal are the real timeline; consider having status reports EMBED the guard-journal extract (done here) as standard practice for storm reports.
6. **My personal checklist additions** (process, not code): (a) NEVER pipe nix builds through filters — log to file + capture rc, always (this bit me once before via `set -e` lessons; it finally stuck tonight); (b) before declaring a storm "drained", read the GUARD's journal, not my own samples; (c) re-run `git log --oneline -5` immediately before ANY long build — the lock can move under a session mid-verification (tonight: nixpkgs bump + dnsblockd re-lock landed between my eval sweep and my build).

## f) NEXT THINGS (prioritized; ~45)

**Deployment path (critical path, in order):**
1. Read build #2 result from `~/.local/state/deploy-geometrikks/build2.log` when job 068 completes; if the "1 dependency failed" recurs, enumerate ALL failures via `--keep-going` output and fix root-cause (suspects: hermes 0.21.3 layout §12 warned about; health-dashboard's new input; anything the `e554fab` nixpkgs bump shifted).
2. If build #2 is green: verify the toplevel contains `docker-geometrikks.service`, the rendered compose, and both sops secrets (`geometrikks.yaml` keys pass `sops-key-audit` — already proven at eval).
3. Launch the LONG-HORIZON deploy watcher (≥6h, green rule: 3 consecutive polls of io avg10 <15 AND MemAvailable >20%, 2-min cadence, heartbeat + `DEPLOY-EXIT` capture to `~/.local/state/deploy-geometrikks/`) — or implement §e.1 first if the user approves the helper.
4. On deploy exit 0: confirm `/run/current-system` advanced AND `/nix/var/nix/profiles/system` anchored (the exit-4 unanchored-generation trap; was `system-785` / `qg1ijnzj…b1b8759`).
5. `docker ps` — both containers `Up (healthy)`; no image pulls (pre-pulled).
6. `python3 -c urllib` probe `http://127.0.0.1:8102/health/ready` → 200.
7. Verify `/var/lib/geometrikks/.env` (0600 root, rendered — placeholders resolved; empty MaxMind/CARTO keys = geo-degraded banner, NOT a crash).
8. Ingestion proof: app logs show parse activity from Caddy JSON logs within ~1 min of gatus traffic; if auto-detect misfires, pin `LOGPARSER_LOG_FORMATS=caddy-json` in the sops template + redeploy (runbook §gotchas).
9. Gatus "GeoMetrikks" green within ~1 min of service up (endpoint probe + journal `status=200` from gatus itself — the only trustworthy signal per repo doctrine).
10. `geo.home.lan` login page on LAN (unverified-TLS urllib probe, expect the app's sign-in HTML).
11. PapDashboard services.json contains the GeoMetrikks tile; dashboard probes it server-side.
12. system-health: `geometrikks` in `system_service_state` textfile (registry `monitored=true` fan-out).
13. Backup proof: trigger `geometrikks-db-backup.service` (user command — my sandbox bans systemctl; alternatively the next deploy's provisioner loop), assert dated `.sql` in `/mnt/pool/backups/geometrikks/` + backup-coordination row green (maxAge 31h).
14. `nix run .#post-deploy-check` — full battery green.
15. Post-deploy regression sweep: confirm NO collateral from the batch deploy (the deploy carries dnsblockd re-lock `e0f74cd9` + nixpkgs `e554fab` + health-dashboard session's work — watch `systemctl --failed`, gatus fleet checks, and the dnsblockd health check specifically).

**User-gated go-live (carried, unchanged):**
16. MaxMind GeoLite2 free signup → paste `geometrikks_maxmind_user_id` + `geometrikks_maxmind_license_key` via the sops one-liner (runbook §go-live) → redeploy or restart unit.
17. Optional CARTO basemap key (`geometrikks_carto_api_key`) — without it the map tiles use the degraded basemap.
18. First login as `admin` (password via the Sops + Age one-liner from `platforms/nixos/secrets/geometrikks.yaml`) + visual world-map sanity check.
19. Caddy access-log retention decision: current roll 100MiB/keep 10/90d vs proposed `roll_keep_for 168h` per-vhost (geo analytics value vs disk).

**Infra hygiene surfaced tonight:**
20. Implement `deploy-when-green` helper (§e.1 spec) so the fourth storm doesn't kill a fourth watcher.
21. crush-hot-db migration completion: needs a window with <N live crush sessions; consider a nightly 04:10 re-run is already wired — verify it fires tomorrow and finishes (structure fix for the QLC `.crush/` churn class).
22. Re-arm `fastflowlm.socket` once the storm drains AND MemAvailable >25% (guard restore capped 3/3 today; manual `systemctl start fastflowlm.socket`; flm v1.0.2 held — do not bump as part of this).
23. Watch zram: 82% fill + 6% MemAvailable tonight was the closest approach to the freeze cliff since the guard was built; if the guard logged any Zone 1–5 trip tonight, review thresholds vs the three-concurrent-builds pattern (new load class).
24. Verify the health-dashboard parallel session's service survives the shared deploy (it initially exported no packages and broke evals mid-afternoon; its `health-hub-543a5b7f` now evals — my deploy will be the first SWITCH carrying it).
25. Confirm `storage_collector_health` (auto-loaned new metric in §10) appears in `/metrics` post-switch, then retire the loan entry if metrics-gate warns.
26. nixpkgs `e554fab` bump: batch-verify critical packages post-deploy (sops-nix shim status — the `buildGo125Module` alias overlay; check whether the bump dropped it or it's still needed).
27. dnsblockd re-lock `e0f74cd9` ("go 1.27.1 toolchain wiring"): post-deploy verify dnsblockd health + its go-modules FOD actually built (this rode our deploy without its own session's verification of the SYSTEM-level build — build #2 will prove it).
28. Two daemon commits landed during build (`f270ca9c`, `eb8cc186`) — diff them before the deploy fires to know exactly what the switch will carry (`git show --stat`).
29. Post-storm: re-check `docs/todo/stability.md` Zone-6 items against tonight's MemAvailable-6% data point (concurrent-builds as a new storm driver class worth a bullet).
30. SigNoz: after deploy, confirm the new geometrikks containers' logs flow via docker journald driver (CONTAINER_NAME resource attribute) — nothing to wire, just verify visibility.

**GeoMetrikks hardening (post go-live):**
31. Add GeoMetrikks smoke block to `scripts/post-deploy-check.sh` (§c.10; containers + `/health/ready` + `.env` presence — no new metrics to gate).
32. Consider `restartTriggers` on the compose unit for sops template rotation (check `mkDockerService` handles rotation → if not, document the restart requirement in the runbook; likely already handled via the env-file restart pattern).
33. Verify log-ingestion keeps up with gatus traffic volume (~all-vhost 30s probes); if backlog grows, the runbook's tuning notes apply (worker count in app env).
34. Backup restore test (round-trip): restore the first pg_dump into a scratch DB once, to prove the backup is usable (never tested restore path).
35. Immich-style cross-check: decide whether `access-https:__*.home.lan.log` (catch-all) belongs in the ingestion list at all (it's near-idle today; harmless, but review after a week of data).
36. Homepage/PapDashboard tile icon + group placement review after first visual pass (currently mdi-earth / Infrastructure).

**Process/docs:**
37. Append tonight's "concurrent nix builds as storm driver" data point to `docs/services/memory-emergency-guard.md` (Zone 6 corroboration worked as designed; the guard's message text already names crash-#3 class).
38. Runbook addendum: `docs/services/geometrikks.md` — add the storm-queue reality (deploys may wait hours; the deploy-when-green watcher is the sanctioned path; NEVER force at MemAvailable <15%).
39. AGENTS.md GeoMetrikks section: add post-deploy-verified state + first-incident notes once verification completes (currently written pre-deploy).
40. `docs/todo/services.md`: update the GeoMetrikks row from `[blocked:user]` go-live to reflect deploy-done state once it happens (keep the MaxMind/CARTO/login rows user-gated).
41. Retire `/tmp/deploy-geometrikks2.log` pattern: prior session wrote deploy logs to /tmp (this session's watcher would have); tonight's report is the reminder that ops logs belong in `~/.local/state/` (tmp-cleaner lesson, applied to build2.log, should apply to future deploy logs).

**Deferred/carrying (explicitly not tonight):**
42. `nixpkgs-llama-rag` pin stays until the ROCm-runtime spin is root-caused (untouched tonight; llama-rag remains disabled — GOOD for tonight's storm: no llama CPU spin amplification).
43. Monitor365 remains disabled (unchanged).
44. Hermes 0.21.3 §12 "verify layout after build" — build #2's result will either prove the binary exists at the warned path or surface a real failure ( suspect in item 1).
45. Consider a fleet-wide "concurrent deploy claiming" convention (§e.4) — needs cross-session agreement, so it's a user decision more than a task.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Force-vs-queue authority, concretely bounded:** the storm is 6.5h old, PSI is finally decaying, but MemAvailable hit 6% tonight with three concurrent builds. If build #2 is green and the ONLY remaining blocker is the pressure gate for another N hours: at what point (if ever) do you authorize `DEPLOY_FORCE_PRESSURE=1`? My recommendation: never while MemAvailable <20% or the guard's crash-#3 message is active; accept `DEPLOY_FORCE_PRESSURE=1` only at io avg10 <25 + MemAvailable >25% + no Zone-6 trip in the last 60 min — and I will not do it without your explicit go.
2. **Are the parallel sessions' builds (telephony-browser, `nix build . --keep-going`, plus their test suite with the `ld`/chromium load) work that should COMPLETE BEFORE my deploy fires** (i.e., their results are meant to ride the same switch), or is my GeoMetrikks deploy free to jump ahead the moment the box is quiet? This determines whether the watcher should also gate on "no other nix build running" or just on pressure.
3. **Tonight's 6%-MemAvailable dip: was that load sanctioned** (multiple agents legitimately building late), or is one of the sessions runaway (e.g., the `bench.test`/duckdb test loop + chromium at load 107)? If sanctioned, I'll leave concurrency alone and purely queue; if runaway, tell me which session's workload may be deprioritized/stopped and I'll fold that into the watcher's wait conditions. Also: after the storm drains, do you want me to auto re-arm `fastflowlm.socket`, or keep it down until you say so?

---

## Verification provenance (this session)

- Watcher poll history: job 045 output, 90 samples 21:16–22:45 (`io_avg10` 17–85, `streak=0` throughout, `WATCHER3-DONE`).
- Guard journal: `journalctl -u memory-emergency-guard` 22:40–23:47 samples — "still active (I/O PSI some avg60=42–54% … max disk busy 97.5–100%, MemAvailable 6.5–16.9% — crash #3 class)", action cooldown active, restore capped 3/3.
- Live readings 23:47: `/proc/pressure/io` some avg10=21.60 avg60=30.96; MemAvailable 8.1G (6%); SwapFree 10.8G/62.2G (zram ~82%).
- Build #1 failure: job 052 output — `Cannot build …26.11.20260917.e554fab.drv … 1 dependency failed` (masked tail; `BUILD-EXIT=0` echo was the pipeline's lie).
- Build #2: job 068 running, log `~/.local/state/deploy-geometrikks/build2.log`.
- Eval verifications: sops template content, `services.gatus.settings.endpoints` (GeoMetrikks entry), `services.integration.geometrikks` (full entry), `systemd.timers."geometrikks-db-backup"` (OnCalendar), `services.caddy.virtualHosts."geo.home.lan"` (protected render + access log), `virtualisation.oci-containers.backend`, `platforms/common/dns-local.nix:34`.
- Pre-deploy battery: `nix run .#pre-deploy-check` → "64 passed, 18 warnings, 0 failed — safe to deploy".
- Tree: HEAD `eb8cc186`, clean; commits `a1795f86`, `616489e6`, `be621000`, `7436edec`, `9c0911f6`, `e0f74cd9` (parallel: dnsblockd re-lock + nixpkgs bump), `8740c661`, `6e62d51d`, `f270ca9c`, `eb8cc186`.
