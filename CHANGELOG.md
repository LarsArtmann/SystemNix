# Changelog

All notable changes to SystemNix are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/).

Given the project's history (2,927 commits), this changelog focuses on significant user-facing and architectural changes. For exhaustive detail, see `git log` and `docs/status/`.

---

## [Unreleased]

### Added

- **dnsblockd memory limit raise (2G→4G)** — dnsblockd was being oomd-killed 730x/day (1,591 since boot) because 2G was too tight for Go GC + OTEL cardinality + SQLite tracking pages. GOMEMLIMIT raised 1500MiB→3GiB to match. PMA MemoryMax confirmed at 8G (already set). Root cause: PMA's 6.6 GiB page-cache reclaim drives system-slice pressure to 65%, triggering oomd's 50%/20s kill threshold on dnsblockd as the largest non-exempt target
- **Auth/DNS gate helpers (`mkOidcGate` / `mkDnsGate`)** — two composable Nix helpers in `lib/default.nix` that eliminate duplicated curl/getent shell scripts across the codebase. `mkOidcGate` probes `https://auth.${domain}/.well-known/openid-configuration` via curl (120s timeout, TLS verified), returning `{ after, wants, serviceConfig.ExecStartPre }`. `mkDnsGate` probes DNS resolution via `getent hosts` with optional non-fatal mode. Both support `includeProvision` for Pocket ID provision dependency. Documented in `AGENTS.md`
- **Service refactors to gate helpers** — refactored 4 services from hand-rolled wait scripts to `mkOidcGate`/`mkDnsGate`, eliminating ~65 lines of duplicated shell: `oauth2-proxy.nix` (mkOidcGate), `gatus-config.nix` (mkOidcGate), `forgejo.nix` (mkDnsGate), `searxng.nix` (mkDnsGate)
- **qmd doc cleanup** — removed all qmd references from active docs after retirement: `FEATURES.md`, `pkgs/README.md`, `docs/gotchas-archive.md` (3 entries), `TODO_LIST.md`, `service-health-check` script
- **Monitoring gap closures (7 Gatus checks + 4 textfile collectors)** — closed all Priority 1 monitoring gaps that let crash loops, OOM kills, and disk fill go undetected: (1) "Textfile Collector Health" meta-check on `node_textfile_scrape_error` — catches invalid `.prom` files that silently drop ALL textfile metrics (14 Gatus checks went permanently RED from this); (2) "Root Disk Usage" alert at 85% — `system_disk_usage_percent` + `_over_threshold` textfile metric from `system-health.nix`; (3) "Service Crash Loop" detector — `system_service_crash_loop` per-service + `system_any_service_crash_loop` aggregate, tracking NRestarts delta per 2min interval (threshold 3); (4) "OOMD Kills" alert — `system_oomd_kills_total`/`_recent`/`_alert` from `journalctl -u systemd-oomd --grep "Marked.*for killing"` with delta tracking (grep pattern verified on live system: `"Killed"` returned 0 matches, `"Marked.*for killing"` returned 2,203); (5) "Docker Container Restarts" monitor — `docker_container_restart_count`/`_alert` per-container + aggregate, using `docker inspect --format '{{.RestartCount}}'` with delta tracking (auto-disabled when Docker off); (6) "PMA Daemon Health" check hitting `127.0.0.1:9190/readyz` (K8s-style readiness probe). Added `pma-health = 9190` to `lib/ports.nix`. Added browser-history + browser-history-agent to `monitoredServices`
- **Twenty CRM Docker container memory limits** — `mem_limit`+`memswap_limit` added to all containers (server=1g, db=2g, redis=256m) + `NODE_OPTIONS=--max-old-space-size=768` on server. Prevents unbounded containers from becoming systemd-oomd kill targets under `/system.slice` memory pressure. Worker already had 2g + 1536M heap cap from prior session
- **Manifest + Dozzle container memory limits** — Extended memory bounding to remaining unbounded Docker containers: Manifest postgres (1g+1g), Manifest app (added memswap 1g), Dozzle (256m+256m + log rotation). All Docker containers on evo-x2 now bounded
- **Pocket ID provision retry resilience** — Added `--retry 3 --retry-delay 2` to `api_put` and `api_post` curl calls in pocket-id provision script. GET already had retries. Prevents transient SQLITE_BUSY failures during OIDC client provisioning
- **vendorHash pre-deploy check** — Added check #11 to `scripts/pre-deploy-check.sh` that dry-runs `.goModules` FODs for all 6 local Go packages. vendorHash mismatches are FOD failures invisible to `nix flake check --no-build`
- **test-home-manager.sh counter fix** — Fixed 4 error branches that double/triple incremented TESTS_TOTAL (Starship, Fish shell/command, Tmux). Each check now counts exactly 1 test regardless of pass/fail outcome
- **StartLimitBurst audit complete** — Full audit of all service modules confirmed zero misplaced `StartLimitBurst`/`StartLimitIntervalSec` in `serviceConfig` ([Service]) sections. All occurrences correctly placed at top-level or in `unitConfig` ([Unit])
- **Niri headless vs desktop-died alerting** — `niri-health-metrics` now emits `niri_graphical_session`, `niri_desktop_died`, and `niri_crash_loop` textfile metrics. Gatus checks distinguish "intentionally headless" (SSH-only, no SDDM login) from "desktop died" (user has a graphical session but niri crashed), and alert on crash loops (3+ restarts in 10 min). Includes a 60s grace period before `desktop_died` fires to avoid false positives during niri's 2s auto-restart window
- **Post-deploy check automation** — all 11 items from the manual Deploy Verification Checklist are now automated in `scripts/post-deploy-check.sh` (went from ~40 to ~53 checks). New checks: Pocket ID journal scan for `SQLITE_BUSY|panic`, SearXNG functional search query (HTML result parsing), Attic cache liveness, Browser History server + agent timer, Monitor365 server-watchdog timer, DNS resolution via `getent`, dnsblockd memory (<2G threshold), BTRFS `commit=300` mount verification, BTRFS `fstrim.timer` enabled, nixpkgs registry state (tarball regression guard), fish startup timing (200ms threshold), direnv smart-nix lib presence, DMS wallpaper IPC, quickshell journal error scan. Added `report_pass/report_fail/report_skip/report_warn` helper functions for non-HTTP checks. Updated flake app runtimeInputs to include `jq`

- **Attic binary cache** — self-hosted Nix binary cache on port 8200 (`cache.home.lan`). RS256 JWT auth, DynamicUser + sops secret (owner=root), Prometheus metrics split from GC trigger, storage dir pre-creation service, cache bootstrap automation, Homepage tile. NixOS VM test (`tests/test-attic.nix`, 6 assertions). Dedicated Gatus health check + storage alert. Forgejo runner MemoryMax raised 4G→16G for CI builds
- **DynamicUser eval-time audit** — `modules/nixos/services/dynamic-user-audit.nix` cross-references `DynamicUser=true` services with sops secrets/templates at eval time. Catches ANY DynamicUser service (present or future) with non-root secret owners. Replaces fragile bash-grep pre-commit hook
- **BTRFS balance timers** — weekly metadata balance (`-musage=50`, Mon 04:00) + bounded data balance (`-dusage=50 -dlimit=10`, Mon 05:00) in `btrfs-health.nix`. Both guarded by `btrfs-chunk-check` (skip if balance running, skip if unallocated < 5G/10G). Prevents the 2026-06-26 metadata ENOSPC crash mode
- **BTRFS emergency reserve** — 10 GiB `fallocate`d file at `/btrfs-emergency-reserve`, created on boot. Delete for instant 10 GiB free space during ENOSPC. Tracked via Prometheus metrics + Gatus Discord alert if missing
- **BTRFS weekly scrub** — `autoScrub.interval` changed from monthly to weekly (monthly scrub only ran 15 min before interruption, corruption detection was broken for weeks). Scrub monitoring false-positive fixed (checks "finished" not just "no errors")
- **NVMe block-layer discard disable** — `ff2c2f80` disables discards at the block layer (`nvme_core.default_ps_max_latency_us=0` + `elevator=none`). Investigation found BTRFS auto-enables `nodiscard` on SSDs; explicit `nodiscard` on all BTRFS mounts confirmed working
- **Shell latency optimization** — direnv per-command caching (46ms→0.7ms, 65x faster), carapace/starship/fzf init script caching, per-session direnv sentinel isolation (`$fish_pid`), smart direnv GC root library. Fish startup: 67ms→54ms. Cold path: 14.8s→2.9s
- **swww wallpaper daemon** — replaces DMS wallpaper management with shader-based transitions (fire GLSL on close, circle GLSL on open). `swww-wallpaper` switcher script. DMS wallpaper init retained as fallback
- **Lockscreen improvements** — shared `pkgs/dms-lock.nix` package, wallpaper-based lock background (not screenshot), `sway-audio-idle-inhibit` (prevents idle lock during media playback), Catppuccin Mocha theming, `--daemonize` before-sleep fix
- **Desktop Renaissance v3** — terminal transparency (88%/90%), floating window transparency, enhanced focus ring, DMS dock, DMS lock screen, DMS fonts/icons, fire/circle GLSL shaders, theme color inheritance
- **SearXNG engine expansion** — expanded from ~8→71 engines across 5 categories. `disabled` vs `inactive` bug fixed (`inactive=false` doesn't override `disabled=true`). Redis cache bounded (128mb/allkeys-lru). Timeouts raised. Image engines expanded (4→8). Hostnames plugin configured (high_priority: SO/MDN/GitHub, remove: Pinterest)
- **SearXNG privacy + TTFB optimization** — rate limiter + Redis removed (private LAN, no abuse vector), `request_timeout` 8s→3s, `max_request_timeout` 20s→5s, autocomplete→DuckDuckGo, `method=GET` + `query_in_title=true`. `formats=["html"]` blocks JSON API scraping
- **Service integration: OTLP tracing** — OTLP env vars wired for DiscordSync, crush-daily, PMA, Overview, File-Renamer (Go services: `localhost:4318`). Monitor365 otel cargo feature enabled (`c07b18241`). Hermes + Manifest env vars set (upstream instrumentation pending). Unit tests for `SetupFromEnv` in 4 Go repos
- **Service integration: backup coordination** — generic `services.backup-coordination` module monitors ALL backup directories via Prometheus textfile metrics. Replaces per-service backup monitors
- **Service integration: secret rotation monitoring** — Pocket ID client secret freshness check (90-day threshold), Prometheus textfile metrics + Gatus Discord alert
- **Service integration: SigNoz OTLP receiver Gatus check** — health check for the OTel collector HTTP endpoint
- **Pocket ID francis crash-loop fix** — WAL clearing ExecStartPre + `ACTORS_HOST=127.0.0.1` + `MemoryMax=1G`. Root cause: francis actor framework SQLITE_BUSY cascade → nil-pointer panic. Superseded by Pocket ID 2.12.0 via nixpkgs update
- **nixpkgs update (Jan 2026 → Aug 2026)** — 7-month drift resolved. Pocket ID 2.10.0→2.12.0. segment-buffer build fix (crane `importCargoLock`). libspa-sys lint fixes. catppuccin-gtk Python 3.14 overlay. Redis→Valkey module key migration. Deployed successfully (29 PASS, 0 FAIL, 2 SKIP)
- **statix.toml** — disables `repeated_keys` false positive for NixOS modules. `manual_inherit`/`manual_inherit_from` warnings fixed across 15 files via `statix fix`
- **Forgejo OIDC DNS gate** — `forgejo-oidc-wait-dns` ExecStartPre probes `getent hosts auth.home.lan` (same DNS-gate pattern as SearXNG/DiscordSync)
- **Docker backup service ordering** — added `docker.service` to `after` list (was only `requires` without `after`)
- **nixpkgs tarball regression defense (4 layers)** — eval-time `nixpkgsTarballGuard` in `flake.nix` (fails all flake operations when nixpkgs lock node is tarball type), `.githooks/pre-commit` rejecting tarball-type nixpkgs, CI normalization (`.github/workflows/flake-update.yml` runs `fix-nixpkgs-lock.sh --latest` after every `nix flake update`), one-command recovery (`nix run .#fix-nixpkgs-lock` / `scripts/fix-nixpkgs-lock.sh` using `nix flake prefetch` which is immune to registry interception). NixOS + Darwin system registry override pinning `nixpkgs/nixos-unstable` to GitHub.
- **QLC SLC cache exhaustion mitigation** — fstrim schedule changed weekly → daily. BTRFS CoW churn exhausts the QLC NAND SLC write cache within 22-47h when fstrim is weekly; with cache gone, every write hits QLC directly (~253ms), building an exponential I/O queue that freezes the kernel → sp5100-tco WDT reset (3 crashes in 3 days proven via ClickHouse metrics). `commit=300` added to `/` and `/data` mounts (reduces metadata write frequency ~10x). fstrim runs at idle I/O priority (`IOSchedulingClass=idle`, `Nice=10`).
- **PSI I/O stall monitoring** — `/proc/pressure/io` metrics (`node_psi_io_some_avg300`, `node_psi_io_full_avg300`, `node_psi_io_alert` at 10% threshold) + Gatus Discord alert "I/O Stall Rate". Catches the I/O queue buildup that precedes WDT crashes.
- **fstrim duration monitoring** — system-health collector tracks fstrim execution time via systemd `ExecMainStartTimestamp`/`ExecMainExitTimestamp`, Gatus alert at 30min threshold. Daily fstrim trims ~24h of churn (~50-100 GiB, ~10-15 min) vs the initial 446 GiB backlog (1h14m).
- **monitor365-server-watchdog** — timer (5min interval) with 3 checks: process alive, `/health` returns HTTP 200 within 10s, journal "pool acquire failed" count >20 in 5min. Recovers degraded-but-alive DuckDB pool deadlock states where `Restart=always` never fires (process stays alive, all endpoints 500). Agent watchdog fixed (`curl -sf` silent failure on non-200 → explicit HTTP status check).
- **go-humanize-linter** — AST linter detecting hand-rolled reimplementations of `go-humanize`. Added as SystemNix system package via `mkLarsPackages` (`flake.nix` input + `lib/lars-packages.nix`).
- **Display watchdog login-screen guard** — `display-watchdog.sh` checks `loginctl` for active user Wayland/X11 sessions before treating DPMS-off as "dead display". Prevents SDDM login-screen restart loop (~10min cycle). Root cause: Xorg idle DPMS-off at login screen looked identical to a dead display.
- **AGENTS.md gotcha archive** — 228-row gotcha table extracted to `docs/gotchas-archive.md` (preserves all root-cause narratives, commit hashes, dates). AGENTS.md gotcha section compressed to categorized enduring-rules list (447 KB → 45 KB, 90% reduction).
- **DiscordSync SQLite corruption self-heal** — `discordsync-db-heal` ExecStartPre cascade: `PRAGMA integrity_check` → backup corrupt DB (`.corrupt-<timestamp>`) → `sqlite3 .recover` → BTRFS snapshot CoW clone (`cp --reflink=always`) → fresh DB as last resort. Re-syncs from Turso cloud after recovery.
- **Browser History service** — Go CQRS/ES browser history server (`history.home.lan`, port 8087). SQLite WAL mode, WebAuthn + OAuth2 (Pocket ID) dual auth. Direct TLS proxy (NOT `protectedVHost` — forward-auth breaks WebAuthn API calls). Agent extracts browsing history from Firefox/Chromium profiles via systemd timer. OIDC oneshot provisions Pocket ID client secret via systemd `LoadCredential` (bypasses `ProtectSystem=strict`). Deployed across 3 iterations fixing OAuth2/sandbox cascade (empty ClientSecret crash-loop, DynamicUser StateDirectory isolation, LoadCredential secret bridging)
- **Helium video anti-throttling** — 4 Chromium flags added to Helium wrapper (`--disable-background-timer-throttling`, `--disable-backgrounding-occluded-windows`, `--disable-renderer-backgrounding`, `--disable-background-media-suspend`). Prevents video dropping to 1–3 FPS when tab backgrounded or scrolled out of view under I/O contention on QLC NAND
- **Prevention Plan M12–M14** — Gatus pattern VM test (`tests/test-gatus-patterns.nix`, 5 endpoints), PMA daemon identity VM test (`tests/test-pma-identity.nix`, 6 assertions), monitoring-the-monitor meta-check (`system_gatus_endpoints_in_error_long` metric + Gatus alert on sustained failures)
- **Pocket ID provision SQLite BUSY timeout fix** — `pocket-id.nix` provision script curl POST/PUT `--max-time` raised 10s→30s for SQLITE_BUSY contention from francis actor framework. Health check retries (`--retry 120 --retry-delay 1`)
- **IO-heavy journalctl elimination** — SigNoz `journalctl --follow` was burning 96% CPU / 3.78 GB read. `monitor365-server-watchdog` `journalctl | grep -c` burned 98% CPU / 274 MB per 5-min run. `niri-health-metrics` burned CPU every 30s. All switched to `journalctl --grep` (in-process filtering). 4 low-value SigNoz journald log units dropped. Service-level log filters tightened from `info` to `warning`
- **BFQ I/O Priority Tiers** — 7-tier BFQ I/O scheduling system in `lib/default.nix` (`ioTier.interactive` through `ioTier.maintenance`). Prevents build storms from freezing SSH and the desktop compositor on QLC NAND. Applied to 14+ services: sshd (BE/1), niri/dms/pipewire/crush (BE/3), clickhouse/monitor365 (BE/5), signoz/discordsync/browser-history/ollama/attic (BE/6), nix-daemon/forgejo-runner/PMA (BE/7+Nice=10), fstrim/clamav (idle). `verify-io-tiers.sh` script registered as `nix run .#verify-io-tiers`. Crush binary wrapped with `ionice -c 2 -n 3 nice -n 5` via `writeShellApplication`
- **GOMEMLIMIT on Go services** — Added `GOMEMLIMIT` at ~75% of MemoryMax to 6 Go services (discordsync, browser-history, PMA, signoz-query, signoz-otel, pocket-id). Prevents Go GC from waiting until heap doubles before collecting, reducing OOM risk under memory pressure
- **DiscordSync DB-heal oneshot** — 11 GB SQLite integrity check extracted from `ExecStartPre` into separate `discordsync-db-heal.service` (Type=oneshot, RemainAfterExit, 10min timeout, BE/6). DiscordSync main service now `after`/`wants` the oneshot. TimeoutStartSec reduced 5min→2min. Deploy activation no longer blocked by multi-minute DB recovery during build storms
- **Scripts comprehensive review** — ~60 bugs fixed across 38 shell scripts + 5 Python scripts. CRITICAL: `update-vendor-hash.sh` array key spaces (17 projects silently skipped), `dns-update.sh` SRI hash sed delimiter corruption, `deploy.sh` treating build failures as recoverable. HIGH: hardcoded nix store paths in 3 scripts, `post-deploy-check.sh` `check()` always returning 0, SIGPIPE aborts in 15+ scripts. 3 NixOS VM tests added (`lib-helpers`, `pipefail-sigpipe`, `sed-delimiter`) — all verified PASS at runtime (~17-20s each)
- **PMA death-loop crash fix (3 layers)** — Layer 1 (upstream): `isNothingToCommit()` in PMA daemon treats TOCTOU "clean working tree" races as `StatusSkipped` not `StatusFailed`, avoiding unnecessary cooldown + retry cycles. Layer 2 (cgroup): `MemoryHigh=6G`, `MemoryMax=8G`, `CPUQuota=200%`, `MemorySwapMax=0`, `PMA_COMMITTER_WORKERS=2` prevent page-cache thrash loop. Layer 3 (monitoring): `system_service_memory_bytes` + `system_service_memory_over_threshold` metrics, Gatus alerts for PMA CPU (>150%) and memory (>5G) at 2-min intervals. Root cause: PMA page-cache death-loop consumed 91% CPU, 27,312 memory boundary hits, system-wide PSI 95%, kernel freeze, WDT reset
- **Post-deploy check hardening** — (1) Double-000 curl bug fixed (`|| echo "000"` → `|| true` at 3 sites — curl already emits `000` on failure). (2) Hermetic runtimeInputs expanded from 2 to 9 packages (coreutils, curl, fish, glibc, gnugrep, jq, nix, procps, systemd). (3) Shellcheck pre-commit hook added (`.githooks/pre-commit`, `--severity=warning` on `.sh` files)
- **I/O pressure check in post-deploy** — `/proc/pressure/io` avg10 check added to `post-deploy-check.sh` (warn if >80% sustained). Catches the I/O contention pattern that caused Helium 3 FPS video and WDT crashes
- **Port-uniqueness VM test** — `tests/test-port-uniqueness.nix` verifies the eval-time port collision assertion in `lib/default.nix` fires correctly
- **disk-common.sh + lib.sh safe pipe helpers** — `scripts/disk-common.sh` provides shared geometry constants (`TARGET_P8_END_GIB`, sector offsets) sourced by both `disk-fix.sh` and `disk-diagnose.sh` (kills the 1548 vs 1560 drift class). `lib.sh` adds `safe_head`, `safe_tail`, `safe_sort_head` for pipefail-safe `| head` patterns
- **ZFS VM configs (untested)** — `systems/zfs-vm.nix` (NixOS VM with ZFS on kernel 6.18, USB passthrough) and `pkgs/freebsd-zfs-vm.nix` (FreeBSD 14.2 cloud image QEMU launcher) wired into flake. NixOS VM evaluates successfully. VFIO PCIe passthrough PROVEN WORKING: NixOS VM (kernel 6.18.43, ZFS 2.4.3) successfully imported `datapool` mirror (2x16TB HDDs, 21GB used). QEMU `usb-host` does NOT work for JMicron JMS567 dual-LUN USB bridge (fundamental limitation). Native ZFS on host kernel 7.1 not attempted
- **memory.events death-loop detection** — system-health collector now scrapes `/sys/fs/cgroup/system.slice/<svc>/memory.events` for all monitored services. Emits `system_service_memory_events_max` (raw counter) and `system_service_memory_events_high` (threshold flag at 100). Gatus alert on PMA thrash loop. Catches the page-cache death-loop pattern (27,312 max events without a single oom_kill — page cache is reclaimable so OOM-killer never fires)
- **browser-history VM test** — `tests/test-browser-history.nix` — NixOS VM test verifying browser-history service starts and `/health` returns 200. Imports upstream module, mocks sops + Pocket ID (WebAuthn-only mode)
- **Ruff pre-commit hook** — `.githooks/pre-commit` now runs `ruff check` on staged `.py` files via `nix shell nixpkgs#ruff`
- **nix-daemon oomd exemption + monitoring** — `ManagedOOMPreference = "omit"` + `OOMScoreAdjust = -1000` on nix-daemon prevents systemd-oomd from killing it during builds. Added to `system-health` monitored services + Gatus health check (1-min interval, Discord alert with recovery command). The outage previously went completely undetected
- **Twenty worker memory limits** — `mem_limit = "2g"` + `memswap_limit = "2g"` + `NODE_OPTIONS = "--max-old-space-size=1536"` on twenty-worker container. Prevents systemd-oomd kill loop (235 restarts) caused by Node.js/NestJS init memory bursts under system-slice pressure
- **dnsblockd dashboard auth** — `/stats` endpoint gated behind auth token via sops-rendered env file (`DNSBLOCK_AUTH_TOKEN`). DMS widget wired with Bearer header + otelEndpoint scheme fix. Cookie-based dashboard login with 30-day MaxAge
- **smartd NVMe-only + SATA pool spindown** — `smartd` bounded to NVMe drive only. Retired SATA ZFS pool spun down (standby) via hdparm + udev. Prevents unnecessary spin-up noise and wear on idle 16TB HDDs
- **niri-health-metrics namespace fix** — Missing `StateDirectory` caused `ReadWritePaths` + `PrivateTmp=true` to create an empty `/var/lib/prometheus-node-exporter/textfile_collectors` mount namespace, hiding the target dir. Added `StateDirectory` + tmpfiles rule. Fixed `niri_graphical_session` metric going permanently absent
- **Niri alert grace period + graphical-session probe** — `niri_desktop_died` now uses a state file requiring 2 consecutive checks (~60s) before firing, avoiding false positives during niri's 2s auto-restart window. `niri_graphical_session` debug Gatus check added
- **USB HDD nr_requests udev rule** — Raises `nr_requests` from default 128 to 256 for USB HDD enclosures (`JMicron` bridge). Unthrottles sequential read throughput on 2x16TB external pool
- **ZFS offline recovery tooling** — `zfs-vm-backup.sh` and `zfs-vm-deepdive.sh` scripts for offline ZFS pool recovery. Headless VM survey workflow (`zfs-vm-survey.sh`) for automated pool inspection
- **system-health `[not set]` poison value fix** — `systemctl show --value` returns `[not set]` for inactive services. Arithmetic on `[not set]` produces invalid `.prom` files → node_exporter drops ALL textfile metrics silently (14 Gatus checks permanently RED). Fixed with `systemctl_value()` helper that coerces `[not set]` to 0

### Changed

- **Service auth gates refactored to shared helpers** — `oauth2-proxy.nix`, `gatus-config.nix`, `forgejo.nix`, `searxng.nix` replaced hand-rolled `waitOidcReady`/`waitDnsReady`/`forgejoOidcWaitDns` shell scripts with `mkOidcGate`/`mkDnsGate` from `lib/default.nix`. ~65 lines of duplicated curl/getent scripts eliminated
- **auto-optimise-store disabled** — Per-build hardlink dedup (`auto-optimise-store = true`) was generating random read I/O competing with the build itself on QLC NAND. Dedup now happens once during low-activity hours via `nix-optimise.timer` (daily ~04:00)
- **SigNoz flake URL pin removal** — `signoz-src` and `signoz-collector-src` inputs converted from hardcoded version tags (`/v0.127.1`, `/v0.144.5`) to default-branch tracking. Version derived via `shortRev or "latest"`. All 61 flake inputs now defer versioning to `flake.lock` (zero hardcoded version tags in URLs)
- **Cadvisor port 9190→9193** — PMA (`projects-management-automation`) listens on `127.0.0.1:9190` via upstream `PMA_HEALTH_LISTEN_ADDR`. Cadvisor was also on 9190, causing a port conflict crash-loop on boot. Cadvisor moved to 9193
- **SigNoz v2 dashboard API** — SigNoz permanently deprecated the v1 dashboard API (HTTP 501 `dashboard_deprecated`). Provisioning script POSTs to `/api/v2/dashboards` with dashboard failures as non-fatal warnings. Alert rules (23) and channels still deploy via v1 API. Dashboard JSONs still in v1 flat format (Perses v2 migration pending)
- **Crush I/O priority wrapper** — Shell alias replaced with `writeShellApplication` wrapper (`ionice -c 2 -n 3 nice -n 5` on Linux, plain exec on Darwin). Works in all contexts (interactive, scripts, MCP), not just interactive shells

- **Deploy resilience** — `deploy.sh` now runs `systemctl reset-failed` (system + user) AND explicitly starts enabled-but-inactive services after reset. Previously crash-looped services at boot blocked ALL deploys until manually reset.
- **system-health collector** — Prometheus textfile collector for systemd service state (active/failed/start-limit-hit), `user-1000.slice` memory threshold (40G), GPUActive threshold (60G), monitor365 DuckDB buffer pressure. Pre-computes boolean flags for Gatus `pat()` matching.
- **Monitor365 schema-migrate oneshot** — runs `ALTER TABLE tenants ADD COLUMN IF NOT EXISTS version INTEGER` before server start. Resolves the DuckDB "version" column binder error after upstream schema change.
- **Monitor365 agent watchdog** — timer (every 5min) checks agent process + metrics endpoint; resets start-limit and restarts if dead. Runs as root (required for `systemctl start`).
- **Monitor365 graphical-restart path unit** — watches for Wayland socket, restarts agent when compositor appears. Debounced (skips restart if started <60s ago or not active).
- **Helium auto-restart service** — systemd user service (`helium.service`) with `Restart=always`, `RestartSec=5`, `StartLimitBurst=10`. `helium-launch` wrapper pgrep-checks for existing main process before launching, preventing the empty-window crash loop.
- **Memory-limited test wrappers** — `go-test-memlimit` (4G), `cargo-test-memlimit` (8G), `pnpm-test-memlimit` (4G) via `wrapWithMemoryLimit` helper in `lib/default.nix`. Uses `systemd-run --user --scope` with `MemoryMax`.
- **TTM page_pool_size reduction** — `ttmPagePoolSize` reduced from 112 GiB to 24 GiB in boot.nix (was exceeding the 94 GiB visible to Linux, allowing GPU driver to consume virtually all RAM).
- **Post-deployment health check** — `scripts/post-deploy-check.sh` verifies services are functional (not just alive) after deploy: checks vHosts return expected HTML, APIs return expected JSON, catches "alive but broken" services.
- **DNS local config module** — `dns-local.nix` extracted from inline config. Manages `localSubdomains` list (required because dnsblockd's sdns resolver does NOT support wildcard local records).
- **qmd** — on-device semantic + BM25 hybrid markdown/code search via persistent HTTP MCP server (port 8181). Built from GitHub source (`fetchFromGitHub` + `pnpmConfigHook`). Three GGUF models auto-cached (~2 GiB). CPU-only by default. Crush MCP integration.
- **Bun memory limiter** — `bunMemoryLimitOverlay` wraps `bun` in a `systemd-run --user --scope` with `MemoryMax=8G`, `MemorySwapMax=0`, `oom_score_adj=1000`. Prevents runaway `bun test` from consuming 61 GB and triggering WDT reset.
- **monitor365 graphical collectors** — keystroke, mouse, camera, clipboard, screenshot collectors wired. `input`/`video` groups added, path-unit restart on Wayland login, upstream pgrep-based display env discovery (`displayUser`).
- **monitor365 backup health monitoring** — Prometheus textfile collector (`monitor365_backup_healthy`, `monitor365_backup_age_hours`) + Gatus Discord alert. Follows AGENTS.md rule 9 mandate.
- **monitor365 nightly DuckDB backup** — timer at 03:00, 7-day retention.
- **DiscordSync OTel tracing** — traces exported to SigNoz via `OTEL_EXPORTER_OTLP_ENDPOINT`.
- **DiscordSync webhook alerting** — `DISCORDSYNC_WEBHOOK_URL` from sops secret.
- **ssh-suspend-guard** — holds `sleep` block inhibitor via `systemd-inhibit` while SSH sessions active, preventing idle suspend during remote work
- **PSI memory pressure metrics** — textfile collector in SigNoz exports `/proc/pressure/memory` avg10 values + derived alert boolean, with Gatus Discord alerting
- **md-go-validator** — added to both NixOS and macOS desktops
- **USB printing support** — added to NixOS hardware configuration
- **Homepage local icons** — `enableLocalIcons = true` bundles 4276 dashboard icons (was defaulting to false, producing ~25 browser 404s per page load)
- **SearXNG** — privacy-focused metasearch engine on port 8889 (`search.home.lan`). Built-in Granian ASGI server, dedicated Redis (unix socket, isolated from Immich), auto-generated secret key (not sops — machine-local random). Layer 2 SSO via oauth2-proxy (no native OIDC support). Rate limiter with trusted proxies (Caddy) + LAN `pass_ip`. POST-only search (queries not in URLs/logs), dark mode, favicon caching (DuckDuckGo resolver). Browser default search engine integration via Chromium policy (`DefaultSearchProviderSuggestURL` proxied through SearXNG). `restartTriggers` on settings + limiter config + package
- **CPUQuota=200% default in `harden()`** — ALL services now get a 2-core hard CPU cap by default, preventing CPU runaway from code bugs (monitor365 busy-loop incident). AI services (ollama 400%, hermes 400%, immich-ml 300%, minecraft 300%, whisper-asr 300%) have explicit overrides
- **Per-service CPU alerting** — `system-health.nix` tracks `CPUUsageNSec` per monitored service, emits `system_service_cpu_percent` + `system_service_cpu_over_threshold` (threshold=150%). Gatus "CPU Runaway (Any Service)" alert fires on Discord
- **Overview 503 watchdog** — timer (every 2 min) restarts Overview when it returns 503 BUT the PMA discovery daemon is healthy. ExecStartPre gate waits for daemon `/v1/health` before starting Overview
- **/tmp cleanup timer** — `nix-build-cleanup-timer` variant removes /tmp entries untouched >4h (every 4h + on boot). `/tmp` tmpfs cap raised from 16 GiB to 48 GiB
- **/tmp tmpfs monitoring** — system-health collector emits `system_tmpfs_tmp_usage_percent` + `system_tmpfs_tmp_over_threshold` (80% of 48 GiB cap ≈ 38 GiB). SigNoz alert "/tmp TmpFS Usage High (>80%)" + Gatus Discord alert. Catches runaway builds before hitting the ceiling
- **SigNoz mkRule target validation** — `validateTarget` assertion in `mkRule` rejects `target=0` + `above_or_equal` (always true for non-negative metrics) and `target=0` + `below` (never true). Prevents the always-firing alert bug from recurring
- **duckdb CLI** — added to cross-platform base packages (handy for inspecting monitor365 `.duckdb` files)
- **Monitor365 module restructured** — pinned to upstream `0615301` (avoids libspa-sys bindgen breakage from `5ee717e3+`). Added schema-migrate, watchdog, graphical-restart, backup-health, restartTriggers. All `//` chains converted to `lib.mkMerge`.
- **oauth2-proxy hardening** — added `--whitelist-domain=.home.lan` (fixes post-login redirect 500), `partOf = pocket-id-provision.service` (ensures credential reload on secret rotation), PKCE S256 enabled (`code-challenge-method = "S256"`).
- **SigNoz auth** — impersonation mode (`SIGNOZ_IDENTN_IMPERSONATION_ENABLED=true`) + unconditional Caddy forward-auth (no LAN bypass). Pocket ID is the sole auth boundary. OIDC is Enterprise-only ($4k/mo).
- **samber-do-auditlog pin REMOVED** — the v0.5.0 pin was wrong (cmdguard v3.1.0 needs v0.7.0+). Flake.lock resolves to v0.8.1 transitively. Top-level input removed as dead code.
- **Hermes upgraded to v0.19** — active pip extras: messaging, anthropic, firecrawl, edge-tts, fal, exa. Multi-provider LLM wiring updated (GLM, MiniMax, Xiaomi, Synthetic, FAL).
- **mr-sync pinned to `3db4fb2`** — upstream `6492eef` removed `nixpkgs` from `outputs` params without adding `...` catch-all.
- **DiscordSync module refactor** — consumes upstream `nixosModules.default` (Monitor365 gold-standard pattern). Eliminates option re-declaration drift. SystemNix specifics layered via `lib.mkMerge`.
- **Post-deploy-check improvements** — SIGPIPE fix (body-file grep instead of pipe), `--compressed` flag for gzip responses, DiscordSync startup-race handling (retry + SKIP for backfill), renamer data-correctness assertion (`total_operations > 0`).
- **OOM hardening** — tuned systemd-oomd thresholds (50%/20s pressure), added `user-1000.slice` MemoryHigh=56G / MemoryMax=64G to contain runaway user processes that starved journald → WDT hard reset. PSI early-warning alerting via Gatus Discord
- **mkLarsPackages simplification** — eliminated manual vendorHash overrides, removed `mkPackageOverlay` indirection for Go tool packages
- **Gatus monitoring expansion** — 69 endpoints (was 59), with Discord alerting and response-time thresholds on user-facing services
- **NixOS modules** — 43 auto-discovered (was 42, added SearXNG)
- **DiscordSync backend** — switched turso-sync → sqlite (eliminates Turso free-plan "SQL read operations forbidden" 403 — 13,993+ consecutive failures). Turso cloud sync can be re-enabled by setting `backend = "turso-sync"` + `tursoUrl` + `tursoAuthTokenFile`
- **Caddy `proxyTo` helper** — `protectedVHost` now wraps `reverse_proxy` with `header_up X-Real-IP {remote_host}`, benefiting all Layer 2 services behind forward-auth (SearXNG, Homepage, etc.)
- **Crush Daily** — `runAsUser` support (runs as `primaryUser` instead of system user, fixing ACL `mask::---` on `/home/lars`). Silent-zero-data post-deploy assertion (`session_count > 0`)
- **goreleaser** added to Linux base packages
- **SigNoz provisioner error handling** — all `|| true` on POST calls replaced with HTTP status code checking (`curl -w "%{http_code}"`). Script now exits 1 on failure (was always exit 0). Final verification step asserts `GET /api/v1/rules` returns >0 rules.
- **SigNoz alert rules monitoring** — Prometheus textfile collector (`system_signoz_alert_rules_total`, `system_signoz_alert_rules_healthy`) + Gatus Discord alert. Post-deploy-check hard-fails if 0 rules provisioned.
- **restartTriggers on ALL provisioner oneshots** — signoz-provision, pocket-id-provision, forgejo-generate-token, forgejo-github-sync, forgejo-ensure-repos, twenty-fix-collation, dnsblockd-attach-ip, monitor365-schema-migrate. `deploy.sh` explicitly restarts all provisioners after `nh os switch` (systemd doesn't restart `Type=oneshot` + `RemainAfterExit=true` on `restartTriggers` change).
- **Browser extensions** — removed `--disable-background-networking` and `--disable-component-update` from Helium wrapper (was silently blocking all `force_installed` extension downloads). Added `ExtensionManifestV2Availability = 2` (Chromium 150 MV2 deprecation). Removed dead 9gag Post Filter extension.
- **Caddy `proxyTo` generalized** — ALL reverse_proxy directives now use `${proxyTo PORT}` (was only `protectedVHost`). Forgejo, SigNoz, Gatus, Pocket ID, oauth2-proxy, OpenSEO, Monitor365 all get `X-Real-IP` header.
- **monitor365 Wayland deps** — added `grim`, `slurp`, `wtype` alongside legacy X11 tools (`xdotool`, `xprintidle`, `scrot`). Functional on niri (Wayland-only).
- **Crush Daily backfill** — `scripts/crush-daily-backfill.py` wired as `nix run .#crush-daily-backfill`. All 45 zero-data dates (2026-06-11 through 2026-07-26) backfilled.
- **monitor365 + go-commit unpinned to `ref=master`** — both were temporarily pinned to specific commits (monitor365 `0615301` for libspa-sys bindgen, go-commit `v0.4.0` for go-git config fix). Both issues resolved upstream; unpinned safely
- **Monitor365 daily event limit override** — `monitor365-schema-migrate` sets `max_events_per_day = 1000000000` (1B) on every run, overriding upstream 10K/day default. The 597M backlog drains in ~1 day instead of ~163 years
- **PMA MemoryMax raised to 12G** — upstream `MemoryMax=8G` was too low for project-discovery daemon re-scanning ~293 projects on restart (OOM-kill). Steady state is far lower; the spike is transient
- **git insteadOf restoration** — the `url.git@github.com:.insteadof=https://github.com/` rule was removed (`2026-07-29`) to prevent SSH-URL lock pollution, then restored on user demand (`2026-07-30`, `502020e7`). AGENTS.md documents both the risk and the restoration
- **Homepage Caddy tile honesty** — `siteMonitor` changed from self-referential dashboard URL (showed Next.js SSR latency through Caddy as "Caddy latency") to Caddy admin API (`localhost:2019/metrics` — measures Caddy's own process). `href` removed (no user-facing Caddy UI; linking to the dashboard you're already on is a no-op)
- **Homepage favicon local bundling** — changed from GitHub CDN (`raw.githubusercontent.com/walkxcode/dashboard-icons`) to local icon pack (`/icons/nixos.png`), eliminating external dependency
- **Hermes flake input** — switched from pinned tag (`v0.19.0`) to default-branch tracking. Hermes now tracks `0.19.1+` automatically. `extraDependencyGroups` documented
- **llama-cpp ROCm MFMA flag removed** — `-DGGML_HIP_MMQ_MFMA=ON` override was a complete no-op on Strix Halo (gfx1150/RDNA 3.5). The flag only affects CDNA GPUs (MI100/200/300); RDNA uses WMMA which is always enabled via compiler builtins. Removing it restored binary caching (30+ min builds → instant substitutes)
- **Attic cache bootstrap automation** — `atticadm` runs directly in bootstrap service, auto-starts on boot, storage dir pre-created via dedicated oneshot (tmpfiles insufficient on `/data`)
- **PMA death-loop fix** — error wrapping (`oops.Wrap` instead of `oops.New`), per-project failure cooldown, workers reduced 8→4, MemoryMax raised 12G→16G. Upstream commits `3bb24b30`, `5a8a3065`
- **Helium empty-window loop re-fix** — removed self-defeating 300s timeout from `helium-launch`. The timeout defeated the "wait for existing instance death" guard — every 5 min it fired "launch anyway" → Chromium found SingletonLock → empty window. Now waits indefinitely as a monitor
- **NixOS VM test infrastructure** — migrated from deprecated `make-test-python.nix` to `pkgs.testers.runNixOSTest`. `tests/mock-sops.nix` mocks sops-nix in VMs. `tests/test-helpers.nix` provides common mocks. CI runs VM tests with KVM
- **user-1000.slice memory cap** — `builtins.toString null` evaluated to `""` for `config.users.users.lars.uid` (null at eval time for `isNormalUser`), creating nonexistent slice key `"user-"`. Hardcoded `"user-1000"`. Raised MemoryMax 64G → 90G / MemoryHigh 56G → 80G per user request (`boot.nix`).
- **dnsblockd OOM mitigation** — `MemoryMax` 1G → 2G + `GOMEMLIMIT=1500MiB` in `dns-blocker.nix`. Root cause: unbounded OTEL/Prometheus cardinality (`dns_domain`, `http_path`, `proxy_domain` labels retain every unique value forever). Mitigated, not fully fixed — upstream Go code fix needed.
- **Journald `SystemMaxUse`** — 16G → 8G (reduces disk pressure during I/O-intensive crash cascades).
- **Monitor365 MemoryMax** — 2G → 4G (+ MemoryHigh 3G) for DuckDB 597M event backlog processing.
- **Hermes `inputs.nixpkgs.follows` restored** — prior session wrongly removed `follows`, causing root nixpkgs to silently downgrade to hermes's pinned `0954f7ee2f6b` (Jan 2026). Restored to follow main nixpkgs.
- **nix profile cleanup** — 4 duplicate packages removed from `nix profile` (cqrs-lint, direnv, herdr, mr) that were already provided by SystemNix. `herdr` upgraded 0.7.1 → 0.8.0 via SystemNix. Principle: SystemNix owns persistent tools; `nix profile` is for transient experiments only.
- **ioTier shallow merge fix** — 4 services (forgejo, monitor365, browser-history, PMA) used `// ioTier.*` (shallow merge) instead of `lib.mkMerge [ { ... } ioTier.* ]`. Shallow merge discards Nix priority semantics (`mkDefault`/`mkForce`). Worked today only because ioTier attrsets have no priority annotations — a time bomb. All 4 converted to `mkMerge`
- **GOMEMLIMIT expanded to 8 Go services** — Added `GOMEMLIMIT` to crush-daily (768MiB, 75% of new 1G MemoryMax) and file-and-image-renamer (384MiB, 75% of existing 512M MemoryMax). Total Go services with GOMEMLIMIT: 8
- **crush-daily memory cap** — Added `MemoryMax=1G` (previously uncapped). Combined with `GOMEMLIMIT=768MiB` to prevent Go GC from waiting until heap doubles before collecting
- **boot.nix ioTier conversion** — sshd, dms, pipewire converted from inline `IOSchedulingClass`/`IOSchedulingPriority` literals to `ioTier.interactive` / `ioTier.desktop` via `mkMerge`. Centralizes I/O priority config alongside the ioTier system
- **Pocket ID provision retry** — `api_get()` curl calls now use `--retry 3 --retry-delay 2 --retry-all-errors` for transient failures during SQLITE_BUSY contention. POST/PUT left unchanged (non-idempotent)
- **CI port check accuracy** — Tightened unregistered-port regex in `.github/workflows/nix-check.yml` from `[^0-9]` to `[^0-9MiB]`, added 10 exclusion terms (GOMEMLIMIT, BLOB_MAX, etc.), added Docker connection-string filter. False positives reduced 25→2 (92% reduction)
- **PMA flake input decoupling** — Removed `go-nix-helpers.follows`, `treefmt-nix.follows`, `systems.follows` from PMA input. PMA now uses its own versions of these deps, reducing cross-input coupling
- **Test infrastructure** — Threaded flake `inputs` through `tests/default.nix` to enable upstream-module VM tests. Signature changed to accept `{ pkgs, lib, system, inputs, ... }`
- **ioTier expansion** — fstrim (`boot.nix`) and clamav-daemon (`security-hardening.nix`) converted from raw `IOSchedulingClass = "idle"` literals to `ioTier.maintenance`. Networking nix-daemon kept as raw literal (uses `mkForce` — semantically different from `ioTier.build`'s `mkDefault`)
- **browser-history flake bump** — Updated to `451fa4d` (CSP-safe .templ templates + Tailwind v4 CSS refresh). Prior session incorrectly reported the upstream `ClientSecret` guard was missing — it already exists at `api/oauth2.go:64` (provider silently skipped when either ClientID or ClientSecret is empty). PMA `isNothingToCommit()` TOCTOU fix also already exists at `pma-daemon/committer/committer.go:289`
- **CI improvements** — browser-history VM test added to CI VM test matrix. Shellcheck CI job added (`--severity=error` on `scripts/*.sh` + `.githooks/*`)
- **ruff.toml** — Project-level ruff configuration selecting E/F/W/I/UP rules, ignoring DTZ/PLW (inappropriate for operational scripts). All 6 Python scripts cleaned: 3 auto-fixed (unused imports, f-strings), 5 manual fixes (ambiguous `l` variables, unused `name`, line-length wraps)
- **PMA oomd exemption + env fixes** — `ManagedOOMPreference = "omit"` prevents systemd-oomd from killing PMA during discovery burst (260+ repos). `PATH` restored (CLI was unreachable — `projects-management-automation` not on PATH). Environment quoting fixed (`GIT_AUTHOR_NAME = "Lars Artmann"` was split on space, producing `Invalid environment assignment: Artmann`)
- **Overview fail-fast + restart hardening** — Overview now fails immediately when project-discovery daemon is absent (was OOM-looping on 4+ GB local discovery). `StartLimitBurst`/`StartLimitIntervalSec` moved from `serviceConfig` (silently ignored in `[Service]`) to top-level `[Unit]` placement. Hardened restart loop with backoff
- **Hermes re-enabled** — Service was disabled during PMA build blocker. Re-enabled with flake bump. Tracks default branch (`0.19.1+`). Runtime verification pending (Discord bot, cron, gateway)
- **ClickHouse thread tuning** — Reduced thread count from 434 to ~344 by setting `max_thread_pool_size=200`, `max_concurrent_queries=64`, `background_pool_size=16`. ClickHouse was spawning excessive threads consuming RAM and scheduler slots
- **zram zstd level 1** — Changed zram compression from default zstd level 3 to level 1 for faster compress/decompress at slightly worse ratio. Benchmark: 3.01x ratio at level 1 vs 3.12x at level 3 (3.6% difference) with ~2x throughput improvement
- **Git compression config cleanup** — Removed `core.compression = 9` (counterproductive for Nix repos — .nix files compress poorly, increases CPU). Removed dead `pack.windowMemory`, `core.bigFileThreshold`. `http.postBuffer` retained for large pushes
- **go-auto-upgrade disabled** — `charm.land/lipgloss/v2/table` multi-module vendoring issue breaks `vendorHash`. Temporarily set to `null` in `lars-packages.nix` until upstream fixes the vendor tree
- **project-meta follows removal** — Removed stale `inputs.project-meta.inputs.*.follows` overrides pointing to non-existent inputs. `go-nix-helpers`, `treefmt-nix`, `systems` follows were causing "non-existent input" warnings
- **go-nix-helpers as flake input** — Converted from `fetchFromGitHub` overlay pattern to a proper flake input. Enables `mkPreparedSource` and other build-time helpers to track upstream via `flake.lock`
- **Health metrics preserved for inactive services** — `system-health.nix` now emits metrics for ALL monitored services even when inactive (was skipping stopped services, causing metric gaps that made Gatus checks flap)
- **browser-history StartLimit fix** — `StartLimitBurst`/`StartLimitIntervalSec` moved from `serviceConfig` (silently ignored by systemd 261+ in `[Service]` section) to top-level `[Unit]` placement. Without this, browser-history crash-looped 592 times → I/O pressure → WDT reset (2026-08-11 crash)
- **nixpkgs refresh + flake input cleanup** — Refreshed nixpkgs lock, cleaned up stale follows overrides, removed unused test arguments

### Removed

- **qmd (on-device markdown search)** — retired after NAR hash drift across 4 deploy cycles (stale Cargo.lock after nixpkgs pin updates) and missing systemd wrapper. Module (`qmd-config.nix`), package (`pkgs/qmd.nix`), overlay, port (8181), CLI tool, health check, and all doc references removed. `~/.cache/qmd/` (~2GB models + index) still on disk — manual cleanup needed
- **swww wallpaper daemon** — ghost service crash-looping 1220+ times/boot (GC'd nix store binary). Replaced with DMS IPC (`dms ipc call wallpaper next`). GLSL fire/circle shader transitions removed. `dms-wallpaper-init` rewritten to seed wallpaper via DMS IPC. DMS owns wallpaper management natively.
- **Hyprland package set** — `grimblast` (screenshot helper) pulled in hyprland-0.56.1 + all hypr* deps (hyprcursor, hyprgraphics, hyprland-qt-support, hyprland-qtutils, hyprlang, hyprpicker, hyprutils, hyprwire). ~122 MiB purged (3850 → 3824 store paths). Screenshots now via grim + slurp + swappy directly (grimblast was a redundant Hyprland wrapper).
- **justfile** — removed in favor of direct Nix flake commands (`nix run .#deploy`, `nix flake check --no-build`, `nix fmt`). All recipes replaced by flake apps and `scripts/` shell scripts
- **Dead scripts** — `scripts/nvme-metrics.sh` (superseded by inline `_signoz-metrics.nix` nvmeMetrics derivation) and `scripts/niri-health.sh` (superseded by inline `niri-health-metrics` in `niri-config.nix`) deleted. Neither was referenced by any `.nix` file

### Fixed

- **NVMe data corruption (13 files)** — root cause: 58 unsafe shutdowns (46% of 126 power cycles) causing incomplete BTRFS commits, NOT async discard. SMART shows drive healthy (0 media errors, 11% wear). All 13 corrupted AI model files identified and deleted. `autoScrub` changed monthly→weekly. Dangerous `discard=none` and block-layer disable changes reverted (would have bricked boot). Database integrity verified (PostgreSQL clean, DuckDB clean)
- **Pocket ID v2.10.0 francis crash-loop** — `francis` actor framework's SQLITE_BUSY cascade caused nil-pointer panic → SIGSEGV → start-limit-hit. Auth.home.lan was down ~2 hours. WAL clearing + ACTORS_HOST + MemoryMax=1G band-aid applied, then superseded by Pocket ID 2.12.0 via nixpkgs update
- **segment-buffer build failure** — `outputHashes` entry missing for `segment-buffer-0.6.0` Rust crate. Fixed via crane's `importCargoLock` API in nixpkgs update
- **libspa-sys bindgen breakage** — monitor365's `[patch.crates.io]` path override produced empty bindgen output. Resolved upstream (unpinned from `5ee717e3`)
- **`writeShellApplication` pipefail false-FAIL** — two bug classes: (1) `|| echo 0` on pipelines produces multi-line output under pipefail → arithmetic error. Fix: `|| true` + `${var:-0}`. (2) `| sort | head` SIGPIPE (exit 141) under pipefail. Fix: append `|| true`. Affected: `tmp-cleanup`, `nix-build-cleanup`, `cargo-sweep`, `backup-health-metrics`, `monitor365-duckdb-heal`
- **Attic tmpfiles unsafe path transition** — systemd-tmpfiles skips `/data/atticd/storage` because `/data` (owned by `lars:users`) → root is an unsafe ownership transition. Fix: dedicated `atticd-storage-dir.service` oneshot creates the directory via `mkdir -p` before atticd starts
- **Attic cache-info.txt write failure** — DynamicUser atticd couldn't write to `/var/lib/atticd`. Fix: explicit `ReadWritePaths` grant via `79dfcd8c`
- **Forgejo OIDC setup DNS race** — `forgejo-oidc-setup` had `after=["dnsblockd.service"]` but no DNS gate ExecStartPre. During deploy, DNS briefly unavailable → `dial tcp: lookup auth.home.lan: no such host`. Fix: `forgejo-oidc-wait-dns` ExecStartPre (30×2s retries, exits 1 on timeout)
- **Docker backup service ordering** — backup service had `requires=["docker.service"]` but NOT `after=["docker.service"]`. During deploy, Docker restarts → backup timer fires → `docker-compose exec` fails. Fix: added `docker.service` to `after` list
- **ActivityWatch Wayland watcher start-limit-hit** — `aw-watcher-window-wayland` had `After`/`PartOf = graphical-session.target` but no start-limit hardening, so a slow compositor start or transient Wayland failure hit the systemd default (5 starts / 10 s) and left the watcher dead until manual `reset-failed`. Added `StartLimitBurst=5` / `StartLimitIntervalSec=300` to the local override. Upstream Home Manager patch prepared (`docs/services/home-manager-activitywatch-graphical-session.patch`) adding a `requiresGraphicalSession` watcher option so the compositor dep is upstreamable instead of a hand-rolled per-site override.
- **Monitor365 DuckDB WAL corruption** — `monitor365-duckdb-heal` ExecStartPre always removes `.wal` before startup. DuckDB checkpoints WAL on graceful shutdown; `.wal` present = unclean shutdown. Server was crash-looping 291+ times.
- **Monitor365 agent circuit-breaker deadlock + start-limit death spiral** — 4-layer fix: `startLimitBurst=10` on service, debounced graphical-restart (skips if <60s ago), watchdog timer (resets + restarts), deploy.sh starts inactive services.
- **PMA auto-commit (DefaultChain)** — `committer.New()` now uses `DefaultChainFromEnv()` (reads `MINIMAX_API_KEY` from env) instead of `DefaultChain()` (empty providers). Upstream `d1d013d2`.
- **PMA "Unknown Author"** — go-git's `repo.Config()` reads only local scope (`.git/config`), not global. Both go-commit (`v0.4.0`) and PMA (`e8380b44`) now use `git config user.name`/`user.email` via CLI which merges all scopes.
- **Helium empty-window crash loop** — `Restart=always` + existing-session handoff spawned 11 empty windows in 36s. `helium-launch` wrapper pgrep-checks before launch.
- **dnsblockd wildcard DNS resolution** — `*.home.lan` wildcard record silently ignored by sdns resolver. Only explicitly listed subdomains in `localSubdomains` resolve. Added all service subdomains.
- **dnsblockd cache CNAME-chase bug** — cache never called `SetQueryer`, serving partial CNAME answers (CNAME without terminal A/AAAA). Caused `curl: (6) Could not resolve host` for CNAME-chained CDN hostnames. Fixed upstream.
- **dnsblockd blocklist dir-vs-file path** — was reading directory instead of file inside it (0 entries blocked, 2.5M domains silently missing).
- **Pocket ID client-secret desync** — provision script migration block seeded stale secrets; skip-if-exists check prevented regeneration. `regenerateSecretsFor` option added for declarative recovery.
- **Forgejo GitHub-sync API token** — `FORGEJO_TOKEN` must come from auto-generated token file, not sops template (stale `CHANGE_ME` placeholder rejected all API calls).
- **Immich Redis TCP port** — nixpkgs defaults to unix-socket-only (port 0); overridden to listen on TCP for monitoring.
- **PMA Type=notify without sd_notify** — upstream sets `Type=notify` + `WatchdogSec=30s` but Go binary never calls `sd_notify(READY=1)`. Overridden to `Type=exec`.
- **Overview OOM-kills when PMA absent** — Overview delegates discovery to PMA daemon socket; falls back to 4+ GB local discovery (OOM-loop) when socket missing.
- **File & Image Renamer auth fallback** — `ErrorTypeAuth` (non-retryable, triggers provider fallback) for 401/403. Upstream `8bf60bd`. Sops key provisioning via `mkKeyedSecrets`.
- **File & Image Renamer split-brain** — watcher and health service unified on `dataDir` state paths (`b0c76b58`). Dashboard was silently showing 0 operations.
- **PMA watcher attribution** — `convertEvent` now resolves actual git repo root per file event (upstream `52c01b18`).
- **Monitor365 integrity hash serialization** — canonical JSON serialization before hashing (upstream `9ea1f1000` + `ebb26a0bd`).
- **Homepage orphaned process after nix-gc** — `restartTriggers = [ pkg ]` forces restart when package changes (same pattern as dnsblockd).
- **Post-deploy-check SIGPIPE false-FAIL** — grep reads from body file directly instead of pipe (large bodies >64KB triggered SIGPIPE under `set -o pipefail`).
- **btrbk-data snapshot directory** — `/data/.snapshots` created via tmpfiles rule.
- **btrfs-verify-snapshots false alarm** — parses snapshot name instead of inherited `stat` mtime.
- **Ollama silent non-start** — removed `wantedBy = mkForce []` that suppressed nixpkgs' default `WantedBy=multi-user.target`.
- **Pre-commit hook statix multi-file bug** — statix now iterates per-file instead of passing all files to one invocation.
- Cascading build failures across 10+ Go repos (cmdguard follows clause, vendor hash cascades)
- Hermes hardcoded `lars` username → `config.users.primaryUser`
- Forgejo duplicate password generation in admin setup
- Monitor365 re-enabled after SQLX_OFFLINE fix
- **SigNoz provision jq array-path bug** — 4-month-old `jq` accessed `.rules[]` instead of `.data.rules[]` in alert-rules provisioning, blocking `nh os switch`. Fixed array path in `signoz-provision` script
- **Homepage bookmark schema crash** — bare YAML object instead of list-of-one-object white-screened the entire dashboard. Fixed to upstream schema format (`[{ ... }]`)
- **Crush Daily silent-zero-data (3 bugs)** — (1) service ran as `crush-daily` system user instead of `primaryUser` (ACL `mask::---` blocked `/home/lars` traversal — `crush projects --json` read empty state), (2) crush CLI v0.86 schema drift (`prompt_tokens`/`completion_tokens`/`cost` moved from per-message to per-session columns — SQL `no such column`), (3) SQLite DSN without `file:` URI prefix opened in-memory DB (treated `?` as filename). All fixed upstream + SystemNix
- **DiscordSync nullable FK crash loop** — backfilling empty string into nullable `guild_id`/`channel_id` columns caused `invalid expression in CREATE INDEX` → crash loop → `start-limit-hit`. Upstream fix (`d785fdfa`) added `backfill_nulls.go` regression test
- **md-go-validator FOD purity break** — `go-branded-id@v0.5.0` shipped a 3.3 MB committed ELF `namer` binary embedding the Go compiler store path. Resolved upstream in v0.5.1 (removed binary). SystemNix `stripPrebuiltGoBinaries` band-aid removed
- **sops crush-daily user mismatch** — secrets owned by non-existent `crush-daily` system user blocked ALL secret deployment atomically (`failed to lookup user 'crush-daily'`). Fixed to `owner = primaryUser; group = "users"` (same pattern as file-and-image-renamer)
- **Crush Daily SQLite DSN** — `sql.Open("sqlite", dbPath+"?_loc=...")` without `file:` URI prefix opened in-memory DB. Fixed to `sql.Open("sqlite", "file:"+dbPath+"?_loc=auto&_time_format=sqlite")` (upstream `83cb19d`)
- **Crush Daily HTML template** — Go 1.26 `html/template` reverted `printf` arg order — `{{"%.2f"|printf .TotalCost}}` triggered type error. Fixed to `{{printf "%.2f" .TotalCost}}` (upstream `b8095de`)
- **SigNoz always-firing alert rules** — four rules used `target=0` with `above_or_equal` (the default), meaning "alert when metric >= 0" — mathematically always true. Three rules (`service-down`, `nvme-critical-warning`, `nvme-media-errors`) were permanently `state: firing`. Fixed all to `target=1` (`2026-07-30_14-27`)
- **SigNoz v5 alerting API format** — SigNoz 0.127.1 replaced the legacy `{"data":{"rule":{...}}}` payload. Migrated to the flat v5 schema with `condition.compositeQuery`, `preferredChannels`, `ruleType: promql_rule`
- **SigNoz provisioner `|| true` anti-pattern** — all POST calls swallowed errors (always exit 0). Replaced with HTTP status code checking + final verification step asserting rules >0
- **Monitor365 server COALESCE NULL crash** — `tenants.version`/`users.version` columns contained NULL in legacy rows from projection replay. Restored `COALESCE(tenants.version, 0)` with qualified table prefix (avoids DuckDB alias-shadow binder error)
- **Monitor365 CPU busy-loop** — circuit breaker + early-flush path bypassed backoff sleep when buffer had >=200 events. With CB open (1.15M failures), loop busy-spun at ~16Hz burning 295% CPU for 23+ hours. Fixed upstream (`f72cf1073`)
- **DiscordSync Turso quota hard-fail** — `OpenTursoSync` retried 3x then HARD-FAILED (exit 69) on Turso 403 quota exhaustion, crash-looping to `start-limit-hit`. Now detects quota error and falls back to local SQLite
- **Forgejo SSH keys GET endpoint** — Forgejo removed GET on `/api/v1/admin/users/{u}/keys` (returns 405). Switched dedup GET to public `GET /api/v1/users/{u}/keys`
- **SearXNG engine init DNS race** — engines calling network during `init()` (wikidata, radio-browser) failed with DNS errors at boot and stayed permanently disabled. Added `dnsblockd.service` dependency + `searxng-wait-dns` ExecStartPre gate
- **Crush Daily insights errgroup cancellation** — `errgroup.WithContext` cancelled ALL goroutines on first transient API failure. Replaced with plain `errgroup.Group` + mutex-guarded error slice (upstream `868fe33`)
- **Crush Daily timezone bug** — `Yesterday()` used `time.Now().Truncate(24h)` which snaps to UTC midnight, not local midnight. Collect (00:30 CEST) and insights (03:00 CEST) computed different dates. Fixed to `time.Date()` with local location (upstream `9286bf0`)
- **PMA discovery OOM during restart** — daemon re-scans ~293 projects on every restart, spiking memory past `MemoryMax=8G`. Raised to `12G`
- **Overview 503 on deploy** — Overview runs discovery ONCE at startup, caches nil on timeout → permanent 503. Three-layer fix: ExecStartPre gate, `partOf` PMA restart, watchdog timer
- **WDT crash (`builtins.toString null`)** — `config.users.users.lars.uid` is `null` at eval time for `isNormalUser`. `builtins.toString null` evaluates to `""` (does NOT throw), producing slice key `"user-"` instead of `"user-1000"`. MemoryHigh/MemoryMax applied to nonexistent slice → `user-1000.slice` ran uncapped → runaway process starved journald → sp5100-tco WDT hard reset (2026-08-03 crash).
- **QLC SLC cache exhaustion crashes** (3 crashes in 3 days: Aug 1, 3, 4) — root cause: weekly fstrim insufficient for QLC NAND. BTRFS CoW churn exhausts SLC cache within 22-47h → direct QLC writes (~253ms latency) → exponential I/O queue → kernel freeze → WDT reset. Proven via ClickHouse metrics (PSI I/O stall 42% baseline, queue depth growing 450/s → 6,192/s). Fix: daily fstrim + `commit=300`.
- **Monitor365 DuckDB pool deadlock** — all pool connections stuck; server alive (port 3001 listening, `Restart=always` never fired) but all endpoints HTTP 500, 99.6% CPU on retry loops, 15+ background tasks failing. Persisted 14+ hours (no server health watchdog existed). Fix: `monitor365-server-watchdog` (5min interval, 3 checks).
- **Monitor365 agent watchdog silent failure** — `curl -sf` silently returned non-zero on non-200 HTTP responses, making the watchdog believe the agent was dead when it was actually degraded. Fixed to explicit HTTP status code checking.
- **Display watchdog login-screen false positive** — `display-watchdog.sh` treated Xorg idle DPMS-off at SDDM login screen as "dead display" → restarted `display-manager.service` every ~10min. Fix: `loginctl` session check (if no user Class=wayland|x11 session exists, DPMS-off is normal idle power-saving).
- **nixpkgs tarball lock regression (RECURRING)** — global Nix registry rewrites `github:NixOS/nixpkgs/nixos-unstable` to stale `channels.nixos.org` tarball during ANY `nix flake update`. PMA auto-commit daemon triggers it by running unscoped `nix flake update`. `--override-input` and `--no-use-registries` do NOT prevent it. Fix: 4-layer defense (eval guard + pre-commit + CI normalization + recovery script) + NixOS/Darwin registry override.
- **go-cqrs-lite transitive dependency break** — `idempotency/` and `retry/` submodules declared zero pseudo-version + local `replace` directives, breaking all transitive consumers. Fixed upstream: published v0.1.x tags, dropped local replaces (`eea5dafa`).
- **Mass vendorHash drift (8 repos)** — nixpkgs Jan→Aug 2026 jump broke Go vendorHashes across emeet-pixyd, crush-daily, mr-sync, md-go-validator, go-humanize-linter, branching-flow, hierarchical-errors, PMA. All updated with published upstream fixes.
- **DiscordSync chattr ExecStartPre** — upstream module ships `chattr -R +C /var/lib/discordsync 2>/dev/null || true` as non-shell ExecStartPre. systemd passes `2>/dev/null` and `|| true` as literal arguments to chattr. Also lacks `+` prefix → runs as `discordsync` user → `Operation not permitted`. Fixed with `lib.mkForce` override in `discordsync.nix`.
- **Hermes nixpkgs silent downgrade** — removing `inputs.nixpkgs.follows` from hermes-agent input caused root nixpkgs to silently downgrade to hermes's pinned Jan 2026 revision. Restored `follows`.
- **DNS resolution regression** — `/etc/resolv.conf` had `9.9.9.9` before `127.0.0.1` (user manually replaced Nix-managed symlink with a file). glibc queried Quad9 first → NXDOMAIN for `*.home.lan`. All external vHost checks failed. Fix: restored Nix-managed symlink (only `nameserver 127.0.0.1`).
- **Browser-history OAuth2 crash-loop (3-iteration fix)** — `ProviderConfig.Validate()` in `cqrs-htmx/usermgmt/oauth2/provider.go` rejects empty ClientSecret. Upstream `optionalEnv` always emits `OAUTH2_POCKET_ID_CLIENT_ID` as systemd Environment (even when secret missing), triggering provider creation → Validate → crash-loop. Fix: remove clientId/issuer from upstream module options; route all 3 OAuth2 vars through a single env file from the OIDC oneshot. Additionally: oneshot switched from direct file read (blocked by `ProtectSystem=strict`) to systemd `LoadCredential`; OIDC oneshot moved to separate `StateDirectory=browser-history-oidc` (DynamicUser server's `StateDirectory=browser-history` is private to its dynamic UID)
- **vendorHash cascade (5 Go repos)** — Browser-history, crush-daily, file-and-image-renamer, and 2 other Go repos had stale vendorHashes after flake-pin-drift fix. All updated via `vendorHash = ""` → build → paste `got:` hash
- **Pocket ID provision SQLITE_BUSY** — francis actor framework SQLite contention caused curl POST timeouts during OIDC client provisioning. POST/PUT `--max-time` raised 10s→30s
- **dms-wallpaper-init missing dms binary** — service called `dms ipc call wallpaper next` but `dms` was not in PATH. Added `dankMaterialShell.packages.${system}.default` to runtimeInputs
- **crush-daily-backfill.py data-loss bug** — INSERT into `events` table was missing two NOT NULL columns (`aggregate_type`, `version`) that have no defaults. The "restore original event" fallback (used when collect fails after deleting the original event) would crash with `NOT NULL constraint failed`, permanently losing the deleted event. Fixed: SELECT, dict, and INSERT all now include `aggregate_type` and `version`
- **browser-history WDT crash chain (2026-08-11)** — `StartLimitBurst`/`StartLimitIntervalSec` in `serviceConfig` are SILENTLY IGNORED by systemd 261+ (only valid in `[Unit]`). browser-history crash-looped 592 times with no limit → SQLite DSN driver mismatch (`mattn/go-sqlite3` params with `modernc.org/sqlite` driver) → I/O pressure on 90%+ full disk → system-wide PSI 95% → sp5100-tco WDT reset. Fix: move StartLimit to `[Unit]` section + upstream DSN fix
- **browser-history CSS missing** — Tailwind v4 CSS wasn't being rebuilt in the Nix derivation. Bumped browser-history flake input to `fdcbdf6` (CSP-safe .templ templates + CSS refresh)
- **dnsblockd dashboard auth token regression** — DMS widget was sending raw token without `Bearer` prefix. Widget `otelEndpoint` was missing `http://` scheme. Both fixed
- **PMA daemon oomd pressure kill** — PMA was the top memory consumer under `/system.slice` during project discovery (6.3G peak). systemd-oomd killed it at 50% pressure threshold. Fix: `ManagedOOMPreference = "omit"` + `OOMScoreAdjust = -1000`
- **nix-daemon killed by systemd-oomd** — nix-daemon (875MB current, 4.8G peak during builds) was oomd's top candidate under `/system.slice`. Socket activation re-triggered on every pending nix command → rapid restarts → `start-limit-hit` → daemon permanently dead → ALL nix operations blocked. Fix: `ManagedOOMPreference = "omit"` + `OOMScoreAdjust = -1000` + Gatus monitoring

### Disabled

- **Mullvad VPN** — `mullvad-vpn.enable = false` due to talpid_dns corrupting `/etc/resolv.conf`. Config preserved for future re-enablement

---

## [2026-07] — Desktop Shell Migration & Infrastructure Hardening

### Added

- **DankMaterialShell (DMS)** — replaced Waybar, Dunst, Rofi as sole Quickshell desktop shell. Owns notifications, wallpapers, clipboard, launcher, polkit
- **DMS community plugins** — emoji launcher (`:e` trigger) and DankCalculator (`=` trigger) via `fetchFromGitHub`
- **DMS SystemNix plugins** — 13 native widgets (clock, volume, brightness, network, battery, workspace bar, etc.)
- **Helium display-hotplug crash mitigation** — `--disable-gpu-watchdog` flag prevents Chromium GPU watchdog kill during slow DCN 3.5.1 surface recreation under GPUActive pressure
- **`/tmp` tmpfs capped at 16 GiB** — static systemd `tmp.mount` unit replacing default 50%-of-RAM (~47 GiB) tmpfs. go-build caches filled 16+ GiB in 21h previously
- **MGLRU thrashing protection** — `min_ttl_ms=1000` via sysfs service prevents thrash spiral (evict hot page → fault → evict another) that starves journald
- **BTRFS metadata ENOSPC prevention** — `btrfs-health.nix` gates `nix-gc` when device-unallocated < 10%, Gatus Discord alerts on metadata ratio, DMS widget shows device-unallocated %. btrbk staggered to 23:00 (before GC at 00:00)
- **Network interface boot race fix** — `dnsblockd-attach-ip.service` (CAP_NET_ADMIN oneshot, ordered after `.device` unit) replaces `localCommands` with `|| true`
- **Pre-deploy validation** — `nix run .#pre-deploy-check` catches boot-breakers (ext4 `discard=async`, missing `nofail`)
- **Post-deploy smoke test** — `nix run .#post-deploy-check` verifies vHosts return expected HTML, APIs return expected JSON, catches "alive but broken" services
- **ProtectHome pre-commit hook** — flags `harden{} + /home` patterns at commit time, catches the crush-daily class of silent data-access failure
- **Functional Gatus body assertions** — Monitor365 `/ui/` checks for `<html` body, Homepage + Overview body checks with Discord alerts. Catches "alive but broken" services
- **Gatus monitoring expansion** — 38→41 endpoints, 31 with Discord alerts, 17 with response-time thresholds. Added Redis TCP check, Mullvad DoT upstream check, external HTTPS connectivity check
- **Caddy security hardening** — `commonConfig` snippet: HSTS, nosniff, frame-options, referrer-policy, permissions-policy, compression (zstd/gzip), HTTP→HTTPS redirect, structured JSON access logging (100MB rotation), TLS 1.2+ enforcement, strict SNI host, 10GB body size limit
- **SSH socket cleanup timer** — systemd user timer (every 5 min) probes `ControlMaster` sockets via AF_UNIX `connect()` and unlinks dead ones
- **Herdr terminal agent multiplexer** — deployed across platforms
- **Niri fork** — switched to `LarsArtmann/niri` (commit `f1f23079`) for improved session save/restore
- **DNS local config module** — `dns-local.nix` extracted from inline configuration
- **Monitoring runbook** — `docs/runbooks/monitoring-runbook.md` documents recovery procedures for every Discord alert
- **Renamer health dashboard** — Caddy vHost + Gatus + Pocket ID for `file-and-image-renamer`
- **DiscordSync dashboard** — exposed at `discordsync.home.lan` with Layer-2 SSO via Pocket ID
- **Overview exposed** — `overview.home.lan`, last unexposed web UI
- **Overview CSP/CDN migration** — cross-repo fix: `templ-components` switched CDN from unpkg.com → cdn.jsdelivr.net. cqrs-htmx v3→v4 migration
- **Resend SMTP wiring** — `smtp.resend.com:465`, `noreply@cloud.larsartmann.com`
- **dnsblockd v0.2.0** — tagged with full embedded recursive resolver (sdns, DNSSEC, DoT, DoH, caching, local zones, ACLs, upstream forwarding). Ready for SystemNix migration

### Changed

- **Rofi → DMS migration** — all 5 niri rofi keybindings rewired to DMS IPC (spotlight, clipboard, keybinds, emoji, calc). Root cause: rofi leaked 7 GB → global OOM killed niri + 8 other processes
- **Unbound cache bounds** — `key-cache-size = "16m"`, `neg-cache-size = "16m"`, `infra-cache-numhost = 10000`. Was 1.5 GiB RSS for 192 MiB explicit caches (DNSSEC key + NXDOMAIN caches were unbounded)
- **OOM tuning** — `user-1000.slice` MemoryHigh=56G / MemoryMax=64G, oomd 50%/20s pressure threshold
- **Deploy resilience** — `deploy.sh` now runs `systemctl reset-failed` (system + user) before `nh os switch`. Without this, crash-looped services at boot block ALL deploys
- **Monitor365 UI package fix** — changed from `pkgs.monitor365` (agent CLI, no UI) to `pkgs.monitor365-server` (symlinkJoin with WASM UI + `UI_DIST_PATH` wrapper)
- **Crush-daily data collection repaired** — `ProtectHome=false` + scoped `ReadOnlyPaths` to `.crush/`. `harden{}` defaults made `/home` invisible — silent empty output for weeks

### Removed

- **Photomap** — module, port (8051), Docker image, Homepage tile, config stub all cleaned up
- **cliphist service** — `wl-paste --watch cliphist store` retired; DMS owns clipboard history exclusively. CLI tool kept for manual use
- **Waybar** — completely removed (import, package, service, scripts). DMS is sole shell
- **Dunst** — disabled (`services.dunst.enable = lib.mkForce false`). DMS owns `org.freedesktop.Notifications`

### Fixed

- **Rofi OOM crash** — 7 GB leak over 5h22m triggered global OOM killing niri, ghostty, signal, pipewire, unbound, clickhouse, immich
- **Helium display-hotplug crash** — GPU watchdog killed process during slow surface recreation under GPUActive memory pressure
- **`switch-to-configuration` exit code 4** — crash-looped services at boot block deploys until manually reset
- **Crush-daily `ProtectHome` silent failure** — hardened service couldn't read `~/.local/share/crush/`
- **BuildFlow silent empty binary** — `buildGoModule` silently dropped `GOEXPERIMENT=jsonv2` from `env` attr; moved to `export` in `preBuild`
- **NVMe `discard=async` watchdog hard-reset diagnosed** — 253ms discard latency on QLC NAND → 17.7s BTRFS commit → system freeze → 30s watchdog → hard reset. Fix: remove `discard=async`, use `fstrim.timer`
- **Monitor365 DB path** — `sqlite://` → `sqlite:///` (3 slashes = absolute path) + added `--config` flag to ExecStart
- **aw-watcher-window-wayland startup race** — added `After=graphical-session.target` dependency
- **Pocket ID OTel** — removed unnecessary traces/logs exporters, kept `OTEL_METRICS_EXPORTER=prometheus`
- **project-meta build** — re-investigated; builds successfully, package is healthy. Original TODO was based on outdated evaluation
- **7 LarsArtmann Go repos** — eliminated stale `vendorHash` / `go.sum` overrides: `golangci-lint-auto-configure`, `hierarchical-errors`, `go-structure-linter`, `art-dupl`, `dnsblockd`, `emeet-pixyd` (all use upstream overlays or `follows` now)

### Added (Documentation)

- **Documentation overhaul** — ROADMAP.md (6 themes), CHANGELOG.md, archived 197 old status reports, freshness pass across README/FEATURES/CONTRIBUTING (retired Waybar/Dunst/Rofi references, corrected counts, replaced `just` with flake commands)
- **AGENTS.md gotchas** — `discard=async` QLC NAND I/O death spiral, `buildGoModule` silent env attr filtering, `buildGoDir` silent-swallow behavior, Helium wrapper double-wrap collision, VA-API flag renames

---

## [2026-06] — Auth & Service Wiring

### Added

- **Sops secret management skill** — project-local skill at `.crush/skills/sops-secret-management/SKILL.md` with gitignore whitelist
- **ssh-to-age** — added to system packages (was not installed, needed `nix run` every time)

### Fixed

- **Caddy boot ordering** — `wants = ["sops-nix.service"]` + `after` prevents 14-hour outage recurrence
- **DNS A records for 5 subdomains** — status, seo, daily, logs, monitor added to both primary + RPi3 DNS
- **All sops secrets guarded** — hermes, crush-daily, openseo, monitor365, signoz, voice-agents wrapped in `lib.optionalAttrs config.services.X.enable`
- **AGENTS.md sops guide** — corrected ssh-to-age `-private-key`, `SOPS_AGE_KEY` in RAM, one-liner pattern

---

## [2026-05] — Ecosystem Stabilization Sprint

### Added

- **Pocket ID migration** — replaced Authelia with passkey-based OIDC provider, declarative provisioning (`pocket-id-config.provision.enable`)
- **BTRFS snapshot overhaul** — btrbk daily snapshots with 14d+4w retention, `btrfs-verify-snapshots` timer, `/mnt/btrfs-root` automount
- **Custom `signoz.target`** — decouples SigNoz/ClickHouse from `multi-user.target`, ~2m faster boot
- **Crash-loop protection** — `startLimitBurst = 5` on all critical services
- **Stale LSP cleanup timer** — kills gopls/vtsls/rust-analyzer running >5min every 5min
- **Rust target cleanup** — weekly timer prunes stale `target/` dirs
- **QDirStat** — Qt disk usage analyzer added
- **NVMe APST boot delay fix** — `nvme_core.default_ps_max_latency_us=0` kernel param prevents 2m50s device detection delay

### Changed

- Migrated from earlyoom to systemd-oomd
- Consolidated flake follows (38 duplicate lock nodes eliminated: 182→144)
- SigNoz JWT auto-generation wrapper script (no longer needs sops secret)
- Port centralization — all ports in `lib/ports.nix`, collision-protected
- Image registry — all container references via `lib/images.nix`
- **go-auto-upgrade fix** — added `go-error-family.follows`, removed redundant vendorHash override from `overlays/shared.nix`
- Manifest moved behind auth (`protectedVHost`)
- Hermes icon fix (`ai.png` → `hermes-icon.png`)

### Fixed

- OOM crash chain — Helium/Electron renderers in `user-1000.slice` exhausting RAM → journald starved → sp5100-tco WDT hard reset
- DNS rollback incident — Mullvad talpid_dns crisis
- Boot performance — `initrd-nixos-activation` 2m50s hang (sops owner validation)
- OAuth2-proxy cookie secret blocking deploy
- Pocket ID provision — header casing + URL encoding + race conditions

---

## [2026-04] — Service Hardening & Auth Stack

### Added

- **oauth2-proxy** — forward-auth bridge between Caddy and Pocket ID
- **Gatus health monitoring** — expanding endpoint coverage with Discord alerting
- **SigNoz dashboards** — Caddy, DNS, Docker, GPU, overview, SigNoz-overview
- **Pocket ID SMTP** — configurable via module options (`cfg.smtp.*`)

### Changed

- Homepage Dashboard rewritten with `mkGroup`/`mkService` helpers
- All sops secrets guarded with `lib.optionalAttrs config.services.X.enable`
- Caddy boot ordering fix (`wants = ["sops-nix.service"]`)

---

## [2026-03] — Desktop & Display Manager Migration

### Added

- **SilentSDDM** — replaced SDDM with themed login manager
- **Ghostty terminal** — primary terminal (GPU-accelerated, native Wayland)
- **Nix-colors migration** — 164 colors migrated to local `theme.nix`

### Changed

- Display manager migration from LightDM/GDM to SilentSDDM
- DNS blocklist ultimate expansion (23 blocklists, 2.5M+ domains)

---

## [2026-02] — Kernel Panic Investigation & Recovery

### Fixed

- Kernel panic investigation and ZFS removal on macOS (ADR-003)
- Nix-darwin build fix (Go module builder mismatch)
- Path reference cleanup

---

## [2026-01] — Nix Anti-Patterns Elimination

### Changed

- Phase 3-4 anti-patterns elimination — major refactoring
- GOPATH implementation made Nix-native
- Wrapper system removal
- Technitium DNS automation (later replaced by dnsblockd)

---

## [2025-12] — v1.0 Release

### Added

- Cross-platform Nix flake (Darwin + NixOS)
- Flake-parts modular architecture
- Home Manager integration for Darwin
- BTRFS root with snapshots
- Custom packages: jscpd, govalid, netwatch, openaudible, aw-watcher-utilization

---

## [2025-11] — NixOS Desktop Setup

### Added

- Hyprland (later replaced by Niri)
- btop wallpaper automation
- Home Manager consolidation
- Evo-X2 hardware configuration (AMD Strix Halo)

---

## [2025-07] — v2.0.0 (Initial Nix Migration)

### Added

- Initial migration from dotfiles to Nix flake
- Terminal performance optimization
- Network monitoring setup
