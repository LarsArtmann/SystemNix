# SystemNix TODO List

**Updated:** 2026-08-09 | **Last sessions:** Browser-history deployment (3-iteration OAuth2/sandbox fix cascade, now deployed + healthy), vendorHash cascade fix (5 Go repos), Pocket ID provision SQLite BUSY timeout fix, DNSblockd TLS handshake spam investigation, Helium video anti-throttling flags (4 flags), Prevention Plan M1–M15 complete (gatus pattern validator, timeout audit, metric validator, Unknown Author rejection, daily nixpkgs compat CI, auth gateway health check, ref=master audit, monitoring-the-monitor)

---

## Priority 0: Critical (Data Loss Risk)

- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. The Aug 3 corruption event (13 files lost) proves this is not theoretical. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged since 2026-06-25. **Manual action:** set up Hetzner StorageBox + BorgBackup
- [ ] **Run foreground BTRFS scrub on `/`** — `/dev/nvme0n1p6` (`/`) has NEVER been scrubbed. Same physical NVMe as `/data` which had 13 corrupted files. SMART says drive is healthy (11% wear, 0 media errors), but root FS corruption would be catastrophic. **Manual command:** `sudo btrfs scrub start -B /`
- [ ] **Push unpushed commits to origin** — 7+ SystemNix commits local-only on a system with "#1 data loss risk" (no remote backup). Also 2 unpushed PMA upstream commits (`e72831c5` human-readable durations, `3ed42be7` Gomega migration). **Manual:** `git push origin master`

## Priority 1: High (Deploy Pending)

- [ ] **Deploy pending changes** — Browser-history deployed Aug 8–9 (3 iterations). System has been deployed recently, but verify: Helium anti-throttle flags, Pocket ID provision timeout fix, vendorHash cascade fix, Prevention Plan M12–M14 (system-health collector, Gatus VM tests, PMA identity test). Run `nix run .#deploy` then `nix run .#post-deploy-check`
- [ ] **Reboot evo-x2** — NixOS system registry override for nixpkgs is in config but NOT active until reboot (currently running old registry). Hyprland purge also needs reboot to take effect. The registry override is critical defense against the recurring tarball regression
- [ ] **Twenty CRM: fix PG role** — `twenty-server` crash-loops with `FATAL: role "twenty" does not exist`. Data is NOT lost (1 user, 1 workspace, 66 companies across 90 tables). Needs PG role fix + decision on Docker vs native nixification
- [ ] **Test browser-history OAuth2 login end-to-end** — Visit `https://history.home.lan`, click "Login with Pocket ID", verify redirect flow completes and dashboard loads with data. Server is deployed and healthy (2,927 events), OAuth2 providers configured (`pocket-id`), but full browser flow not manually tested yet
- [ ] **Add browser-history agent `after` dependency** — Agent is `Type=oneshot` with no `after = [ "browser-history.service" ]`, causing transient 502 retries during server restarts. Add ordering in SystemNix layer (`modules/nixos/services/browser-history.nix`)
- [ ] **Add browser-history to post-deploy smoke tests** — `/health` HTTP check + external HTTPS vHost check for `history.home.lan` in `scripts/post-deploy-check.sh`
- [ ] **Create Attic cache + CI token** — Attic module deployed but cache not yet created. Steps: `attic cache create monitor365`, `atticadm make-token --sub ci --validity 1y --push monitor365 --pull monitor365`, configure Forgejo runner. See `docs/services/nix-binary-cache-setup.md`
- [ ] **Enable niri blur** — Terminal transparency added (88%/90%) but niri's blur option is NOT configured (niri HM module lacks `blur {}` option). Transparent terminals without blur are hard to read. Workaround: raw KDL config, wait for niri-flake, or drop transparency

## Priority 2: Manual Steps (Blocked on Human)

- [ ] **Hermes: install SSH deploy key** — private key to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model`
- [x] **Install `dnsblockd-CA` on Mac** — Without it, Chrome/Helium block Touch ID platform authenticator for `*.home.lan`, breaking Gatus/Forgejo SSO. Manual: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dnsblockd-ca.pem`
- [ ] **Turso plan decision** — DiscordSync crash-loops on Turso `unexpected EOF` after dbHeal cascade (dbHeal created fresh local DB, Turso sync can't initialize). Currently on sqlite-only backend. Decide: keep sqlite-only, re-auth Turso, or upgrade plan
- [ ] **Reduce `/data` fill below 80%** — Currently 92% full (700 GiB / 758 GiB). High fill on QLC NAND increases write amplification and failure risk. Candidates: clean Docker images (`docker system prune`), re-download corrupted AI models only when needed, audit `/data/activitywatch` (12G), Steam (5.9G), DuckDB (13G)
- [ ] **Deploy to macOS** — Darwin registry override for nixpkgs written in config (`platforms/darwin/nix/settings.nix`) but NOT deployed. Run `nix run .#deploy` on `Lars-MacBook-Air`
- [ ] **Clean up orphaned dnsblockd tracking DB** — `/var/lib/dnsblockd/dnsblockd_tracking.db` (724 MB, last modified Jul 15) is the old database from before the rename to `tracking.db`. **Manual:** `sudo trash /var/lib/dnsblockd/dnsblockd_tracking.db`
- [ ] **DNSblockd whitelist policy decisions** — Consider whitelisting iCloud Private Relay domains (`mask.icloud.com`, `mask-h2.icloud.com` — privacy-enhancing, can't work through DNS-blocking resolver) and DoH bypass domains (`dns.quad9.net`, `one.one.one.one` — already blocked at resolver level)

## Priority 3: Infrastructure

- [ ] **Browser-history DB backup** — `/var/lib/browser-history/data.db` (SQLite WAL mode, 2,927 events) is NOT in `backup-coordination`. Needs periodic `sqlite3 .backup` job (matching Immich/Twenty pattern) + entry in `configuration.nix` `services.backup-coordination.backups`. Stagger schedule (01:00–03:00 window)

- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), has btrbk snapshot protection but not a named subvolume. Migration to `@data` would enable separate CoW semantics. Requires ~1h downtime
- [ ] **`/data` compression decision** — `compress=zstd:3` on `/data` is under review (corruption report recommended removal). Needs user decision: keep, lower to `zstd:1`, or remove. Blocked by reboot requirement
- [ ] **Remove Pocket ID WAL band-aid** — Pocket ID 2.12.0 (deployed via nixpkgs update) includes upstream francis fixes. The WAL-clearing ExecStartPre, `ACTORS_HOST=127.0.0.1`, and `MemoryMax=1G` overrides may no longer be needed. Remove one at a time, verify SQLITE_BUSY doesn't recur
- [ ] **SearXNG streaming exploration** — User wants streaming results (progressive rendering), not the current "wait for all engines" model. Options: SearXNG fork with SSE endpoint, Go/Rust streaming proxy, or Caddy flush_buffers
- [ ] **Declarative health-check** — `criticalSystemServices` in `scheduled-tasks.nix` is a hand-maintained list of only 4 services (caddy, forgejo, dnsblockd, postgresql). Missing active services: discordsync, searx, qmd-mcp, emeet-pixyd, monitor365, signoz, immich, pocket-id. Generate list from Nix config or `systemctl list-units` instead

## Priority 4: Code Quality

- [ ] **Delete dead `scripts/nvme-metrics.sh`** — Orphaned script split-brained with inline `nvmeMetrics` in `_signoz-metrics.nix`. The deployed collector is the inline version; the script is dead code that was accidentally edited instead of the real implementation
- [ ] **Add GOMEMLIMIT to all Go services** — dnsblockd OOM mitigation proved GOMEMLIMIT effectiveness. Audit all Go services with `MemoryMax` and add `GOMEMLIMIT` at ~75% of MemoryMax. Prevents Go GC from waiting until heap doubles before collecting
- [ ] **Wire `doc-freshness-check.sh` into pre-commit or CI** — Script exists (`scripts/doc-freshness-check.sh`) but is not automated. Validates doc counts against code
- [ ] **Add regression tests for past bugs** — VM test infrastructure exists (`tests/`). Add tests for: DynamicUser + sops owner mismatch, deploy.sh start-limit reset, `writeShellApplication` pipefail + SIGPIPE patterns, `builtins.toString null` slice key bug
- [ ] **Consolidate systemd blocks for statix** — `statix.toml` disables `repeated_keys` (false positive for NixOS modules). Alternative: consolidate service+timer pairs into single blocks
- [ ] **PMA `GenerateMessage` handler leak** — Same `defer Close()` pattern as the fixed `Commit()` site, but `GenerateMessage` was missed. Upstream fix needed in PMA repo
- [ ] **vendorHash drift detection** — Systemic issue: nixpkgs updates break Go vendorHashes across 8+ repos. Consider CI check (`nix flake check` doesn't catch FOD mismatches), batch script, or pre-commit hook
- [ ] **Pre-deploy vendorHash validation** — `scripts/pre-deploy-check.sh` checks ports, mounts, and metrics but NOT vendorHash freshness. Add `nix build .#X.goModules --dry-run` check for all Go packages
- [ ] **VendorHash CI check across LarsArtmann repos** — dnsblockd has a `vendor-hash` check; replicate across browser-history, crush-daily, file-and-image-renamer, and all other Go repos
- [ ] **Pocket ID provision: `api_get` timeout** — `pocket-id.nix:79` still has `--max-time 10` (POST/PUT were raised to 30s). Add `--retry 3 --retry-delay 2` to all provision curl calls for transient SQLITE_BUSY resilience
- [ ] **Implement cgroup I/O throttling for dev builds** — QLC NAND I/O contention from `cargo`, `go test`, `nix build` caused Helium video to drop to 3 FPS. Wrap dev commands with `IOSchedulingClass=idle` or `IOWeight` limits. Give Helium elevated `IOWeight=1000`
- [ ] **Fix IO-heavy journalctl patterns** — `scripts/usb-diagnostic.sh:53`, `scripts/verify-deployment.sh:46,48`, `scripts/internet-diagnostic.sh:97` use `journalctl | grep` (burns 98% CPU). Switch to `journalctl --grep`. Add pre-commit guard for `journalctl.*|.*grep` pattern

## Priority 5: Desktop

- [ ] **Test removing `--enable-zero-copy`** — if it prevents display hotplug crashes, `--disable-gpu-watchdog` may become unnecessary
- [x] **Verify all extension IDs are live on Chrome Web Store** — Dead IDs cause silent download failures now that background networking is enabled. **Verified 2026-08-09:** All 19 active NixOS extension IDs confirmed live via Chrome Web Store update API (`clients2.google.com/service/update2/crx`). All return valid CRX codebase + version (uBlock Origin v1.73.0, React DevTools v7.0.1, Refined GitHub v26.8.8, etc.)
- [x] **Verify DMS wallpaper management** — swww removed, DMS manages wallpapers via IPC (`dms ipc call wallpaper next`). Verify `dms-wallpaper-init` seeds correctly from `~/.local/share/wallpapers/`. Check `journalctl --user -u quickshell` for errors. **Verified 2026-08-09:** (1) Zero swww/awww refs in .nix files. (2) Deployed binary (`p3x39p...`) uses `dms ipc call wallpaper get/set` correctly. (3) `dms-wallpaper-init` completed successfully on Aug 07 boot (17s). (4) DMS running 24h+ stable, all 13 plugins loaded, only benign warnings (polkit duplicate agent, evdev device removal). (5) 5 wallpapers available in `~/.local/share/wallpapers/`. (6) Stale old binary (`g4zni9...`) with swww still in store but GC will reclaim; systemd unit correctly references new path
- [x] **Backup DMS `settings.json` before deploy** — DMS may overwrite user-owned `settings.json` on rebuild (split-brain risk). Backup before deploying. **Resolved 2026-08-09:** (1) Found BOTH `settings.json` and `plugin_settings.json` are HM-managed symlinks (AGENTS.md was wrong — settings.json is NOT user-owned). (2) Added auto-backup step to `deploy.sh` that detects when DMS has replaced the symlink with a real file and creates a timestamped `.bak` before `nh os switch`. (3) Existing `.bak` (22KB, 530 keys from Jul 27) preserved as safety net. (4) Corrected AGENTS.md and gotchas-archive.md to reflect actual symlink architecture

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
- [ ] **Upstream direnv caching pattern** — The fish-native mtime gate (46ms→0.7ms per command) and `_nix_add_gcroot` optimization (14.8s→2.9s cold path) would benefit all fish+direnv users on large flakes

### LarsArtmann Apps

- [ ] **dnsblockd: fix OTEL cardinality leak** — Drop or bucket `dns_domain`, `http_path`, `proxy_domain` labels in `internal/server/telemetry.go`. Each unique value creates a permanent in-memory time series. SystemNix mitigation (GOMEMLIMIT+2G) reduces OOM frequency but doesn't fix the leak
- [ ] **Monitor365: investigate DuckDB pool deadlock root cause** — Watchdog recovers the state but doesn't prevent it. All pool connections get stuck; upstream investigation needed (pool size vs 15+ concurrent tasks, connection leak, DuckDB PRAGMA settings)
- [ ] **DiscordSync: fix chattr ExecStartPre upstream** — Push proper fix to upstream NixOS module (use `+` prefix for root ExecStartPre or drop chattr entirely)
- [ ] **PMA daemon: stop committing broken flake.lock** — Auto-commit daemon runs unscoped `nix flake update` which triggers tarball regression. Options: run `fix-nixpkgs-lock.sh` after update, run `nix flake check --no-build` before commit, or stop touching flake.lock
- [ ] **file-and-image-renamer: pin 3 inputs from `ref=master` to tags** — `go-filewatcher-src`, `vision-review-agent-src`, `go-nix-helpers` all track master. go-nix-helpers especially critical (build-time library, drifting changes `mkPreparedSource` behavior)
- [ ] **file-and-image-renamer: `GOTOOLCHAIN=auto` → `local`** — In both `preBuild` blocks + vet check. Currently safe but will break sandbox purity when go.mod exceeds go_1_26
- [ ] **`hermes`**: Auto-create directory structure on first run; handle own state migration; sane defaults for `OLLAMA_API_KEY`; use PID file or socket-based single-instance locking instead of `--replace` flag

---

## Priority 7: Browser History

- [ ] **AGENTS.md browser-history updates** — Document (a) LoadCredential + isolated StateDirectory pattern for OIDC oneshot, (b) `ProviderConfig.Validate()` crash-loop root cause (CLIENT_ID always emitted by upstream `optionalEnv` even when secret missing), (c) add browser-history to SSO Layer 1 table (native OIDC, direct TLS proxy — NOT `protectedVHost`)
- [ ] **Fix OTel endpoint URL scheme upstream** — browser-history uses `otlptracegrpc` with `127.0.0.1:4317` (missing `http://` scheme). Go OTel library expects a URL. Should use HTTP port 4318 (`OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318`) or fix upstream to add scheme. Requires commit → push → flake update → redeploy
- [ ] **Add Gatus monitoring for agent timer staleness** — Agent is `Type=oneshot` + timer. Alert if `browser-history-agent.timer` hasn't fired in >1h via system-health textfile metric
- [ ] **Clean up stale OAuth2 env files** — `/var/lib/browser-history/oauth2-secrets.env` from failed deploy iterations 1–2 (now at `/var/lib/browser-history-oidc/oauth2-secrets.env`)

---

## Priority 8: Long-Term

- [ ] **Provision Pi 3** for DNS failover cluster — hardware required
- [ ] **Auditd enablement** — blocked on NixOS 26.05 bug #483085
- [ ] **AppArmor enablement** — commented out in security-hardening.nix
- [ ] **Darwin Home Manager parity** — disk constrained (256GB, 90%+ full)
- [ ] **Monitor365 agent to server auth** — no auth, anyone on LAN can POST data
- [ ] **Disabled service triage** — voice-agents, minecraft: decide enable or remove
- [ ] **Monitor365 event-store compaction** — 597M backlog events draining at 1B/day limit; after drain, compact the event store to reclaim DuckDB space
- [ ] **Overview upstream: retry discovery** — Overview runs discovery ONCE at startup; if PMA daemon is slow, it caches nil and returns 503. Upstream fix needed (Overview should retry). SystemNix has a watchdog workaround
- [ ] **NVMe drive replacement evaluation** — SMART says healthy (11% wear) but 58 unsafe shutdowns (WDT resets from QLC SLC exhaustion) are the real risk. Daily fstrim + `commit=300` mitigates. Consider TLC replacement, RAID1 for `/data`, or UPS to prevent unsafe shutdowns
- [ ] **NPU utilization** — AMD XDNA 2 (50 TOPS) confirmed completely idle. GPU via ROCm is the compute path. Explore ONNX Runtime / Ryzen AI SDK for small model offloading. Monitor upstream llama.cpp XDNA/IRON plugin progress
- [ ] **`go-standard` migration for file-and-image-renamer** — 13 inputs + ~400 lines of perSystem boilerplate could collapse to ~3 inputs + ~20 lines via `inputs.go-nix-helpers.flakeModules.go-standard`

---

## Deploy Verification Checklist

After `nix run .#deploy`, verify:

1. **Post-deploy check** — `nix run .#post-deploy-check` (hard-fails on critical issues)
2. **Pocket ID** — Verify `auth.home.lan` loads, check `journalctl -u pocket-id.service` for SQLITE_BUSY or francis panics (should be resolved by 2.12.0)
3. **SearXNG** — Verify `search.home.lan` loads, test a search query, confirm rate limiter removal didn't break functionality
4. **Attic cache** — Verify `cache.home.lan` loads, run `attic cache info monitor365`
5. **BTRFS** — Verify daily fstrim schedule (`systemctl cat fstrim.timer`), verify `commit=300` on mounts (`mount | grep commit`), check PSI I/O metrics in SigNoz
6. **Shell** — Verify fish startup < 60ms (`fish -i -c exit` with timing), verify direnv caching works (`time cd .`)
7. **Desktop** — Verify DMS wallpaper management (`dms ipc call wallpaper next`), check `journalctl --user -u quickshell` for errors
8. **Registry** — Verify nixpkgs registry override active: `nix registry list | grep nixpkgs`
9. **Monitor365** — Verify server-watchdog active (`systemctl status monitor365-server-watchdog.timer`), check `/health` endpoint
10. **DNS** — Verify `getent hosts dash.home.lan` resolves, check dnsblockd memory stays under 2G
11. **Browser History** — Verify `history.home.lan` loads, test OAuth2 login via Pocket ID, verify dashboard shows visit data, check agent timer fires (`systemctl list-timers browser-history-agent*`)

---

_Completed work is tracked in [CHANGELOG.md](./CHANGELOG.md)._
