# SystemNix TODO List

**Updated:** 2026-08-14 | **Last sessions:** code-quality audit (9 TODO items resolved: StartLimitBurst audit, Docker limits for Manifest/Dozzle, Pocket ID retries, vendorHash pre-deploy check, test-home-manager.sh counter fix, 4 stale TODOs closed), monitoring gap closures (textfile scrape error meta-check, disk usage alert, crash-loop detector, oomd kills tracking, Docker restart monitoring, PMA daemon health check), smart-audio daemon + qmd retirement + Twenty hardening

---

## Priority 0: Critical (Data Loss / System Risk)

- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. The Aug 3 corruption event (13 files lost) proves this is not theoretical. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged since 2026-06-25. **Manual action:** set up Hetzner StorageBox + BorgBackup
- [ ] **Free disk space urgently** — Root filesystem at 90-93% on QLC NAND. High fill increases write amplification, SLC cache exhaustion, and WDT crash risk. Candidates: `nix-collect-garbage -d`, delete old BTRFS snapshots (`sudo btrbk prune`), `docker system prune`, audit `/data/activitywatch` (12G), Steam (5.9G), DuckDB (13G). **Source:** Multiple 08-11/08-12 reports
- [ ] **Run foreground BTRFS scrub on `/`** — `/dev/nvme0n1p6` (`/`) has NEVER been scrubbed. Same physical NVMe as `/data` which had 13 corrupted files. SMART says drive is healthy (11% wear, 0 media errors), but root FS corruption would be catastrophic. **Manual command:** `sudo btrfs scrub start -B /`
- [ ] **Reboot evo-x2** — NixOS system registry override for nixpkgs tarball regression is in config but NOT active until reboot (currently running old registry). Hyprland purge also needs reboot. The registry override is critical defense against the recurring tarball regression. **Source:** Multiple reports since 08-10

## Priority 1: High (Monitoring Gaps)

- [x] **Add `node_textfile_scrape_error` Gatus check** — DONE: Added "Textfile Collector Health" Gatus check in `gatus-config.nix` that alerts when `node_textfile_scrape_error != 0`. When system-health produced invalid `.prom` files, node_exporter silently dropped ALL textfile metrics and 14 Gatus checks went permanently RED
- [x] **Add disk usage Gatus alert (85% threshold)** — DONE: Added `system_disk_usage_percent` + `system_disk_usage_over_threshold` textfile metrics in `system-health.nix` and "Root Disk Usage" Gatus alert in `gatus-config.nix`
- [x] **Add I/O PSI Gatus alert** — ALREADY EXISTED: "I/O Stall Rate" Gatus check was already present in `gatus-config.nix` (line 716-726), alerting on `node_psi_io_alert 0` (PSI I/O stall >10% over 5min)
- [x] **Add crash-loop detector metric** — DONE: Added `system_service_crash_loop` per-service + `system_any_service_crash_loop` aggregate textfile metrics in `system-health.nix` (tracks NRestarts delta per 2min interval, threshold 3 restarts). "Service Crash Loop" Gatus alert added in `gatus-config.nix`. Also added browser-history + browser-history-agent to monitoredServices
- [x] **Add `system_oomd_kills_total` metric** — DONE: Added `system_oomd_kills_total`, `system_oomd_kills_recent`, and `system_oomd_kills_alert` textfile metrics in `system-health.nix` (counts systemd-oomd kill events from journal with delta tracking). "OOMD Kills" Gatus alert added in `gatus-config.nix`
- [x] **Add Gatus health checks for overview + PMA discovery daemon** — DONE: Overview Gatus check already existed (line 908-919). Added "PMA Daemon Health" Gatus check in `gatus-config.nix` hitting `127.0.0.1:9190/readyz` (Kubernetes-style readiness probe — 503 if auto-commit or discovery daemon fails). Added `pma-health = 9190` to `lib/ports.nix`
- [x] **Add Docker container restart count monitoring** — DONE: Added `docker_container_restart_count`, `docker_container_restart_alert` per-container, and `system_any_docker_container_restart_alert` aggregate textfile metrics in `system-health.nix` (uses `docker inspect --format '{{.RestartCount}}'` with delta tracking per 2min interval, threshold 3 restarts). "Docker Container Restarts" Gatus alert added. Auto-disabled when Docker is not enabled

## Priority 2: Manual Steps (Blocked on Human)

- [x] **Twenty CRM: PG role resolved + Docker hardening** — PG role issue was transient (volume recreated with correct `POSTGRES_USER=postgres`). System verified healthy: 66 companies, 90 tables, 0 restarts. Docker stays (third-party NestJS app, nixification not viable). Added `mem_limit`+`memswap_limit` to all containers (server=1g, db=2g, redis=256m) and `NODE_OPTIONS=--max-old-space-size=768` to server
- [ ] **Hermes: install SSH deploy key** — private key to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model`
- [ ] **Hermes runtime verification** — Hermes re-enabled (`2090bd7e`) but Discord bot presence, cron job registration, and gateway request handling were NEVER verified. Check `journalctl -u hermes.service`. **Source:** `docs/status/2026-08-12_13-05_overview-hermes-pma-split-mode-startlimit-hardening.md`
- [ ] **Test browser-history OAuth2 login end-to-end** — Visit `https://history.home.lan`, click "Login with Pocket ID", verify redirect flow completes and dashboard loads with data. CSS fix deployed (`bb998e8d`), StartLimit fixed (`a941f88d`). **Source:** `docs/status/2026-08-12_14-59_browser-history-css-and-startlimit-fixes.md`
- [ ] **Verify dnsblockd dashboard auth** — `sudo systemctl restart dnsblockd.service`, then visit `https://dnsblock.home.lan/dashboard`, enter token (retrieve via sops), confirm stats load. Widget should show block counts. **Source:** `docs/status/2026-08-12_14-55_dnsblockd-dashboard-auth-comprehensive-review.md`
- [ ] **WebAuthn `.lan` RP ID browser validation** — Verify browsers accept passkey registration on `history.home.lan` (`.lan` is not a real TLD; Chrome/Firefox may reject)
- [ ] **Turso plan decision** — DiscordSync crash-loops on Turso `unexpected EOF` after dbHeal cascade. Currently on sqlite-only backend. Decide: keep sqlite-only, re-auth Turso, or upgrade plan
- [ ] **Deploy to macOS** — Darwin registry override for nixpkgs written in config (`platforms/darwin/nix/settings.nix`) but NOT deployed. Run `nix run .#deploy` on `Lars-MacBook-Air`
- [ ] **Clean up orphaned dnsblockd tracking DB** — `/var/lib/dnsblockd/dnsblockd_tracking.db` (724 MB, last modified Jul 15) is the old database from before the rename to `tracking.db`. **Manual:** `sudo trash /var/lib/dnsblockd/dnsblockd_tracking.db`
- [ ] **Browser-history: registration lock after first user** — `POST /auth/register` is open to anyone on LAN. Add `registration_open = false` flag after first user created. Upstream code change in browser-history repo
- [ ] **Evaluate oomd pressure threshold** — Current `DefaultMemoryPressureLimit = 50%` / `DefaultMemoryPressureDurationSec = 20s` killed both nix-daemon (mid-build) and Twenty worker (steady-state). May be too aggressive for a system that regularly runs nix builds + Docker + AI workloads. Consider 60%/30s or per-slice config. **Source:** `docs/status/2026-08-12_20-08_nix-daemon-oomd-kill-and-twenty-worker-restart-loop.md`

## Priority 3: Infrastructure

- [ ] **Add eval-time assertion for `StartLimitBurst` placement** — In systemd 261+, `StartLimitBurst`/`StartLimitIntervalSec` in `serviceConfig` (=[Service]) are SILENTLY IGNORED. This caused the 2026-08-11 WDT crash chain (browser-history 592 restarts). Create `start-limit-audit.nix` that catches this pattern at eval time. **Source:** `docs/status/2026-08-11_23-28_wdt-crash-postmortem-deploy-blockers.md`, AGENTS.md StartLimitBurst gotcha
- [x] **Add Docker container memory limits (Manifest, Dozzle)** — DONE: Manifest postgres got `mem_limit=1g`+`memswap_limit=1g`, manifest container got `memswap_limit=1g`, Dozzle got `mem_limit=256m`+`memswap_limit=256m`+log rotation. All Docker containers now bounded
- [ ] **Fix browser-history `expires_at` session reaper error** — Every 5 min: `session reaper failed: no such column: expires_at`. SQLite sessions table missing column, migration gap in browser-history upstream. Investigate schema migration. **Source:** `docs/status/2026-08-12_14-17_browser-history-oidc-secret-desync-fix.md`
- [ ] **Fix browser-history `CheckpointStore` upstream** — Server replays ALL events on startup (4-min projection drain) because there's no persistent checkpoint store. Requires cqrs-htmx `HydrateFromSQL`. Causes availability gap on every restart. **Source:** `docs/status/2026-08-12_10-20_comprehensive-session-review.md`
- [ ] **Browser-history DB backup** — `/var/lib/browser-history/data.db` (SQLite WAL mode) is NOT in `backup-coordination`. Needs periodic `sqlite3 .backup` job + entry in `configuration.nix` `services.backup-coordination.backups`. Stagger schedule (01:00–03:00 window)
- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), has btrbk snapshot protection but not a named subvolume. Migration to `@data` would enable separate CoW semantics. Requires ~1h downtime
- [ ] **Create Attic cache + CI token** — Attic module deployed but cache not yet created. Steps: `attic cache create monitor365`, `atticadm make-token --sub ci --validity 1y --push monitor365 --pull monitor365`, configure Forgejo runner. See `docs/services/nix-binary-cache-setup.md`
- [ ] **Enable niri blur** — Terminal transparency added (88%/90%) but niri's blur option is NOT configured (niri HM module lacks `blur {}` option). Transparent terminals without blur are hard to read
- [ ] **Caddy reload root-cause fix** — `PrivateTmp=true` in `harden {}` blocks `systemctl reload caddy` on every deploy (exit code 4). Currently band-aided with unconditional restart in `deploy.sh`
- [ ] **Declarative health-check** — `criticalSystemServices` in `scheduled-tasks.nix` is a hand-maintained list of only 4 services. Missing active services: discordsync, searx, monitor365, signoz, immich, pocket-id. Generate list from Nix config instead. Also check for stale `qmd-mcp` reference (qmd was retired)
- [ ] **Fix OTel endpoint URL scheme upstream (browser-history)** — Uses `otlptracegrpc` with `127.0.0.1:4317` (missing `http://` scheme). Go OTel library expects a URL. Fix edited in SystemNix but needs upstream confirmation + deploy. **Source:** `docs/status/2026-08-12_14-59_browser-history-css-and-startlimit-fixes.md`
- [ ] **SigNoz dashboard JSONs v1→v2 Perses schema migration** — 5 dashboard files are in v1 flat format but POSTed to v2 API. Currently non-fatal warnings
- [ ] **ClickHouse backup before SigNoz upgrade** — Schema migrator runs on startup. No backup taken before upgrades. `clickhouse-client -q "BACKUP DATABASE signoz TO Disk('backups', 'pre-signoz-upgrade.zip')"`
- [ ] **Add Dozzle container security hardening** — Dozzle has Docker socket mounted read-only but is missing `security_opt = ["no-new-privileges:true"]`, `cap_drop = ["ALL"]`. A container with Docker socket access can escape to the host. Memory limits were added but security hardening was not. Uses `oci-containers` abstraction (not Compose), so uses `extraOptions` not YAML keys
- [ ] **Standardize Docker container hardening** — No single helper exists for applying standard memory limits, log rotation, security options to Docker containers. Manifest/Twenty use Compose (`mkDockerServiceFactory`) with `mem_limit`/`memswap_limit` keys. Dozzle uses `oci-containers` with `extraOptions` flags. Create a helper analogous to `harden {}` for systemd
- [ ] **Verify vendorHash pre-deploy check patterns at runtime** — Check #11 in `pre-deploy-check.sh` uses grep patterns (`"would build"`, `"would (copy|fetch)"`) based on nix CLI conventions but NOT yet verified against real `nix build --dry-run` output. Run end-to-end at next deploy to confirm patterns match
- [ ] **Deploy pending changes** — Manifest postgres memory limits, Dozzle memory limits, Pocket ID retries, vendorHash check, test-home-manager.sh fix — all pass eval but NOT deployed. Manifest postgres running unbounded in production
- [ ] **SearXNG streaming exploration** — User wants streaming results (progressive rendering). Options: SearXNG fork with SSE endpoint, Go/Rust streaming proxy, or Caddy flush_buffers

## Priority 4: Code Quality

- [x] **Audit ALL service modules for `StartLimitBurst` in `serviceConfig`** — DONE: Full audit complete. Zero violations found across all modules. All `startLimitBurst`/`StartLimitBurst` correctly placed at top-level or in `unitConfig`. browser-history.nix fix (`a941f88d`) was the only instance of this bug class. Also confirmed `overview.nix` uses intentional `mkForce null` override pattern
- [x] **Verify `crush-daily-backfill.py` re-insert SQL schema** — DONE: Verified against `go-cqrs-lite/storage/sql/migrations/sqlite.sql`. All 7 INSERT columns (`id`, `aggregate_id`, `aggregate_type`, `version`, `event_type`, `payload`, `occurred_at`) exist in the `events` table. Omitted columns (`schema_version`, `payload_encoding`, `metadata`) have defaults. Insert is safe
- [x] **Fix `test-home-manager.sh` TESTS_TOTAL inflation** — DONE: Fixed 4 error branches that double/triple incremented TESTS_TOTAL (Starship not found +2→+1, Fish command not found +2→+1, Fish shell not active +3→+1, Tmux not found +2→+1). Each check now counts as exactly 1 test regardless of outcome
- [x] **Pocket ID provision: `api_get` timeout** — DONE: `api_get` already had `--retry 3 --retry-delay 2 --retry-all-errors`. Added `--retry 3 --retry-delay 2` to `api_put` and `api_post` (without `--retry-all-errors` — safer for non-idempotent POST/PUT, still retries on transient HTTP 500/502/503 SQLITE_BUSY)
- [x] **Pre-deploy vendorHash validation** — DONE: Added check #11 to `scripts/pre-deploy-check.sh` that runs `nix build .#<pkg>.goModules --dry-run` for all 6 local Go packages (dnsblockd, monitor365, netwatch, emeet-pixyd, file-and-image-renamer, crush-daily). Warns when FOD not cached (potential stale hash)
- [ ] **VendorHash CI check across LarsArtmann repos** — dnsblockd has a `vendor-hash` check; replicate across browser-history, crush-daily, file-and-image-renamer, and all other Go repos
- [ ] **PMA `GenerateMessage` handler leak** — Same `defer Close()` pattern as the fixed `Commit()` site, but `GenerateMessage` was missed. Upstream fix needed in PMA repo
- [ ] **Systemd hardening consistency audit** — Audit: `TimeoutStopSec`, `RestartSec` consistency (5s/10s/30s variation), `ProcSubset`, `RestrictAddressFamilies`, `SystemCallArchitectures`, `LockPersonality`, `UMask`. Add missing primitives to `harden()` helper
- [ ] **Implement cgroup I/O throttling for dev builds** — QLC NAND I/O contention from `cargo`, `go test`, `nix build` caused Helium video to drop to 3 FPS. Wrap dev commands with `IOSchedulingClass=idle` or `IOWeight` limits
- [ ] **GOMEMLIMIT runtime validation** — Values (75% of MemoryMax) are reasonable defaults but actual Go GC behavior depends on heap live-set. Verify via `runtime.MemStats` or GC logs after deploy
- [x] **Fix port-uniqueness VM test quoting** — DONE (stale TODO): Investigated `tests/test-port-uniqueness.nix`. No nested `''${}` escaping issues exist. The testScript is pure static Python string with no interpolation. No fix needed
- [x] **Add `GOTOOLCHAIN=local` to Go builds** — DONE (already handled): nixpkgs `buildGoModule` already injects `GOTOOLCHAIN = "local"` via `pkgs/build-support/go/module.nix` env attrset. No manual addition needed. Pre-commit hook + CI already guard against `GOTOOLCHAIN=auto`. Template devShell correctly sets it too
- [ ] **Create dep-audit script for LarsArtmann Go repos** — Cross-reference ALL `go.mod` require lines against flake.nix pinned revs before deploy
- [x] **Fix IO-heavy journalctl patterns** — DONE (already fixed): All 6 `journalctl` call sites across scripts/ already use safe patterns (`--grep`, `-n` caps, write-to-file, capture-to-variable). No `journalctl | grep` pipe traps remain

## Priority 5: Desktop

- [ ] **Test removing `--enable-zero-copy`** — if it prevents display hotplug crashes, `--disable-gpu-watchdog` may become unnecessary

## Priority 6: Upstream Contributions

### nixpkgs

- [ ] **`aw-watcher-utilization` poetry-core migration** — `pkgs/aw-watcher-utilization.nix:19-24`. Add `postPatch` to nixpkgs package
- [ ] **`valkey` / `aiocache` / `timm` / `xformers` broken tests** — 4 packages with `doCheck = false`. Investigate and PR fixes
- [ ] **`taskwarrior3` build flags** — `SYSTEM_CORROSION=on` + `ENABLE_TLS_NATIVE_ROOTS=on` should be nixpkgs defaults
- [ ] **Kitty GC resilience patch** — After `nix-collect-garbage`, kitty's bundled binary lookup breaks
- [ ] **KeePassXC Chromium manifests** — nixpkgs only ships Firefox-format native messaging manifests

### Home Manager

- [ ] **Darwin user definition requirement** — HM on Darwin requires explicit `users.users.<name>.home` — tracks issue #6036

### Third-Party

- [ ] **`jscpd` lockfile** — PR upstream to publish `pnpm-lock.yaml`
- [ ] **XRT boost 1.87+ compat** — PR to `nix-amd-npu` to pin `boost187` for XRT build
- [ ] **Upstream direnv caching pattern** — The fish-native mtime gate (46ms→0.7ms) and `_nix_add_gcroot` optimization would benefit all fish+direnv users on large flakes

### LarsArtmann Apps

- [ ] **dnsblockd: fix OTEL cardinality leak** — Drop or bucket `dns_domain`, `http_path`, `proxy_domain` labels. Each unique value creates a permanent in-memory time series
- [ ] **Monitor365: investigate DuckDB pool deadlock root cause** — Watchdog recovers the state but doesn't prevent it. All pool connections get stuck; upstream investigation needed
- [ ] **DiscordSync: fix chattr ExecStartPre upstream** — Push proper fix to upstream NixOS module
- [ ] **PMA daemon: stop committing broken flake.lock** — Auto-commit daemon runs unscoped `nix flake update` which triggers tarball regression
- [ ] **file-and-image-renamer: pin 3 inputs from `ref=master` to tags** — `go-filewatcher-src`, `vision-review-agent-src`, `go-nix-helpers`
- [ ] **file-and-image-renamer: `GOTOOLCHAIN=auto` → `local`** — In both `preBuild` blocks + vet check
- [ ] **`hermes`**: Auto-create directory structure on first run; handle own state migration; sane defaults for `OLLAMA_API_KEY`; use PID file or socket-based single-instance locking
- [ ] **browser-history: fix `modernc.org/sqlite` vs `mattn/go-sqlite3` DSN mismatch** — Root-caused the Aug 11 WDT crash. The DSN uses `mattn/go-sqlite3` params (`_journal=WAL`) with the `modernc.org/sqlite` driver. Audit all LarsArtmann Go projects for the same mismatch
- [ ] **errorfamily: flush logger before `os.Exit`** — `HandleError` calls `os.Exit(1)` without flushing the logger, losing the final error message. Upstream library fix needed
- [ ] **go-auto-upgrade: fix `charm.land/lipgloss/v2/table` vendoring** — Multi-module vendoring issue blocks re-enabling. Currently disabled (`= null` in `lars-packages.nix`)

## Priority 7: Long-Term

- [ ] **Provision Pi 3** for DNS failover cluster — hardware required
- [ ] **Try native ZFS on host kernel 7.1** — Connected 2x16TB external ZFS mirror pool (`datapool`, only 21.4GB used — mostly disposable Docker images). nixpkgs claims ZFS 2.4.3 max kernel is 6.18, but OpenZFS 2.4.3 actually supports up to 7.0 (ONE minor behind host's 7.1). VFIO VM passthrough PROVEN WORKING but unnecessary if native ZFS compiles. 3-line config change: `boot.supportedFilesystems = [ "zfs" ]`
- [ ] **Decide ZFS pool fate: keep, reformat to BTRFS, or dismiss** — Pool is 99.86% empty (21GB of 14.5TB). Data is almost entirely disposable Docker container images. SATA pool spun down (`d57c1210`). Reformatting costs nothing
- [ ] **SMART monitoring for external ZFS drives** — `smartctl -a /dev/sda` and `/dev/sdb`. 16TB HDDs in USB enclosures run hot. Check reallocated sectors, pending sectors, temperature
- [ ] **Auditd enablement** — blocked on NixOS 26.05 bug #483085
- [ ] **AppArmor enablement** — commented out in security-hardening.nix
- [ ] **Darwin Home Manager parity** — disk constrained (256GB, 90%+ full)
- [ ] **Monitor365 agent to server auth** — no auth, anyone on LAN can POST data
- [ ] **Disabled service triage** — voice-agents, minecraft: decide enable or remove
- [ ] **Monitor365 event-store compaction** — 597M backlog events draining at 1B/day limit; after drain, compact the event store to reclaim DuckDB space
- [ ] **Overview upstream: retry discovery** — Overview runs discovery ONCE at startup; if PMA daemon is slow, it caches nil and returns 503. Upstream fix needed (Overview should retry). SystemNix has a watchdog workaround
- [ ] **NVMe drive replacement evaluation** — SMART says healthy (11% wear) but 58 unsafe shutdowns (WDT resets from QLC SLC exhaustion) are the real risk. Consider TLC replacement, RAID1 for `/data`, or UPS
- [ ] **NPU utilization** — AMD XDNA 2 (50 TOPS) confirmed completely idle. Explore ONNX Runtime / Ryzen AI SDK for small model offloading
- [ ] **Deploy.sh backup retention** — Backup step creates timestamped `.bak` files on every deploy but never cleans them up. Add retention policy (keep last 3)
- [ ] **`go-standard` migration for file-and-image-renamer** — 13 inputs + ~400 lines of perSystem boilerplate could collapse to ~3 inputs + ~20 lines via `inputs.go-nix-helpers.flakeModules.go-standard`

---

## Deploy Verification Checklist

**All 11 items below are automated in `scripts/post-deploy-check.sh`.** Run `nix run .#post-deploy-check` after every deploy.

| # | Item | Automated Check |
|---|------|----------------|
| 1 | Post-deploy check | Self (the script itself) |
| 2 | Pocket ID — SQLITE_BUSY/panic scan | `journalctl -u pocket-id --since -30min` grep |
| 3 | SearXNG — functional search | `curl /search?q=test` grep for `<article\|result-default` |
| 4 | Attic cache | `check_local 8200` |
| 5 | BTRFS — commit=300 + fstrim | `grep commit=300 /proc/mounts` + `systemctl is-enabled fstrim.timer` |
| 6 | Shell — fish startup + direnv | `date +%s%N` around `fish -i -c exit` + direnv lib check |
| 7 | Desktop — DMS wallpaper + quickshell | `dms ipc call wallpaper get` + `journalctl --user -u quickshell -p err` |
| 8 | Registry — nixpkgs github vs tarball | `nix registry list \| grep nixpkgs` |
| 9 | Monitor365 — watchdog timer | `systemctl is-active monitor365-server-watchdog.timer` |
| 10 | DNS — resolution + memory | `getent hosts` + `systemctl show -p MemoryCurrent dnsblockd` |
| 11 | Browser History — liveness + agent timer | `check_local 8087` + `systemctl is-active browser-history-agent.timer` |

---

_Completed work is tracked in [CHANGELOG.md](./CHANGELOG.md)._
