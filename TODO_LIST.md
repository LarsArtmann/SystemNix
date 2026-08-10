# SystemNix TODO List

**Updated:** 2026-08-10 | **Last sessions:** BFQ I/O priority tier system (7 tiers, `ioTier` helpers, 14+ services classified), GOMEMLIMIT on 6 Go services, DiscordSync DB-heal oneshot extraction, Crush ionice/nice wrapper, scripts comprehensive review (~60 bugs fixed, 3 VM tests verified), PMA death-loop crash fix (3-layer: upstream `isNothingToCommit` + cgroup hardening + memory monitoring), post-deploy check hardening (double-000 fix, hermetic runtimeInputs, shellcheck pre-commit), SigNoz flake URL pin removal (all 61 inputs now version-tag-free), cadvisor port conflict fix (9190→9193), ZFS VM investigation (2x16TB external HDD, NixOS + FreeBSD VM configs written but untested), auto-optimise-store disabled (per-build dedup → daily nix-optimise.timer), I/O pressure check in post-deploy

---

## Priority 0: Critical (Data Loss Risk)

- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. The Aug 3 corruption event (13 files lost) proves this is not theoretical. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged since 2026-06-25. **Manual action:** set up Hetzner StorageBox + BorgBackup
- [ ] **Run foreground BTRFS scrub on `/`** — `/dev/nvme0n1p6` (`/`) has NEVER been scrubbed. Same physical NVMe as `/data` which had 13 corrupted files. SMART says drive is healthy (11% wear, 0 media errors), but root FS corruption would be catastrophic. **Manual command:** `sudo btrfs scrub start -B /`
- [ ] **Push unpushed commits to origin** — 7+ SystemNix commits local-only on a system with "#1 data loss risk" (no remote backup). Also 2 unpushed PMA upstream commits (`e72831c5` human-readable durations, `3ed42be7` Gomega migration). **Manual:** `git push origin master`

## Priority 1: High (Deploy Pending)

- [ ] **Deploy pending changes** — I/O scheduling (BFQ tiers, GOMEMLIMIT), PMA death-loop fix, scripts review, post-deploy check hardening, SigNoz flake pin removal, cadvisor port fix, auto-optimise-store disabled. Run `nix run .#deploy` then `nix run .#post-deploy-check`
- [ ] **Reboot evo-x2** — NixOS system registry override for nixpkgs is in config but NOT active until reboot (currently running old registry). Hyprland purge also needs reboot to take effect. The registry override is critical defense against the recurring tarball regression
- [ ] **Commit/push PMA upstream fix + bump flake** — `isNothingToCommit()` TOCTOU fix is in `/home/lars/projects/projects-management-automation` working tree but NOT committed. SystemNix cgroup limits work WITHOUT the code fix (reduces crash risk) but the code fix prevents unnecessary cooldown cycles. Commit → push → `nix flake lock --update-input projects-management-automation`
- [ ] **Commit/push browser-history OAuth2 fix + bump flake** — `ClientSecret != ""` guard added to all 3 OAuth2 provider checks in `/home/lars/projects/browser-history/api/oauth2.go`. Commit → push → tag → bump SystemNix flake input
- [ ] **Twenty CRM: fix PG role** — `twenty-server` crash-loops with `FATAL: role "twenty" does not exist`. Data is NOT lost (1 user, 1 workspace, 66 companies across 90 tables). Needs PG role fix + decision on Docker vs native nixification
- [ ] **Test browser-history OAuth2 login end-to-end** — Visit `https://history.home.lan`, click "Login with Pocket ID", verify redirect flow completes and dashboard loads with data. Server is deployed and healthy (2,927 events), OAuth2 providers configured (`pocket-id`), but full browser flow not manually tested yet
- [ ] **Add browser-history agent `after` dependency** — Agent is `Type=oneshot` with no `after = [ "browser-history.service" ]`, causing transient 502 retries during server restarts. Add ordering in SystemNix layer (`modules/nixos/services/browser-history.nix`)
- [ ] **Create Attic cache + CI token** — Attic module deployed but cache not yet created. Steps: `attic cache create monitor365`, `atticadm make-token --sub ci --validity 1y --push monitor365 --pull monitor365`, configure Forgejo runner. See `docs/services/nix-binary-cache-setup.md`
- [ ] **Enable niri blur** — Terminal transparency added (88%/90%) but niri's blur option is NOT configured (niri HM module lacks `blur {}` option). Transparent terminals without blur are hard to read. Workaround: raw KDL config, wait for niri-flake, or drop transparency

## Priority 2: Manual Steps (Blocked on Human)

- [ ] **Hermes: install SSH deploy key** — private key to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model`
- [ ] **WebAuthn `.lan` RP ID browser validation** — Verify browsers accept passkey registration on `history.home.lan`
- [ ] **Turso plan decision** — DiscordSync crash-loops on Turso `unexpected EOF` after dbHeal cascade (dbHeal created fresh local DB, Turso sync can't initialize). Currently on sqlite-only backend. Decide: keep sqlite-only, re-auth Turso, or upgrade plan
- [ ] **Reduce `/data` fill below 80%** — Currently 92% full (700 GiB / 758 GiB). High fill on QLC NAND increases write amplification and failure risk. Candidates: clean Docker images (`docker system prune`), re-download corrupted AI models only when needed, audit `/data/activitywatch` (12G), Steam (5.9G), DuckDB (13G)
- [ ] **Deploy to macOS** — Darwin registry override for nixpkgs written in config (`platforms/darwin/nix/settings.nix`) but NOT deployed. Run `nix run .#deploy` on `Lars-MacBook-Air`
- [ ] **Clean up orphaned dnsblockd tracking DB** — `/var/lib/dnsblockd/dnsblockd_tracking.db` (724 MB, last modified Jul 15) is the old database from before the rename to `tracking.db`. **Manual:** `sudo trash /var/lib/dnsblockd/dnsblockd_tracking.db`
- [ ] **DNSblockd whitelist policy decisions** — Consider whitelisting iCloud Private Relay domains (`mask.icloud.com`, `mask-h2.icloud.com` — privacy-enhancing, can't work through DNS-blocking resolver) and DoH bypass domains (`dns.quad9.net`, `one.one.one.one` — already blocked at resolver level)
- [ ] **Browser-history: registration lock after first user** — `POST /auth/register` is open to anyone on LAN. Add `registration_open = false` flag after first user created. Upstream code change in browser-history repo. Surfaces from 3 separate status reports (02-12, 07-47, 10-36)
- [ ] **WebAuthn `.lan` RP ID browser validation** — Verify browsers accept passkey registration on `history.home.lan` (`.lan` is not a real TLD; Chrome/Firefox may reject). If rejected, Pocket ID OAuth2 is the fallback (already integrated). Manual: open `chrome://gpu` in Helium, test `navigator.credentials.create()`

## Priority 3: Infrastructure

- [ ] **Browser-history DB backup** — `/var/lib/browser-history/data.db` (SQLite WAL mode, 2,927 events) is NOT in `backup-coordination`. Needs periodic `sqlite3 .backup` job (matching Immich/Twenty pattern) + entry in `configuration.nix` `services.backup-coordination.backups`. Stagger schedule (01:00–03:00 window)

- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), has btrbk snapshot protection but not a named subvolume. Migration to `@data` would enable separate CoW semantics. Requires ~1h downtime
- [ ] **`/data` compression decision** — `compress=zstd:3` on `/data` is under review (corruption report recommended removal). Needs user decision: keep, lower to `zstd:1`, or remove. Blocked by reboot requirement
- [ ] **Remove Pocket ID WAL band-aid** — Pocket ID 2.12.0 (deployed via nixpkgs update) includes upstream francis fixes. The WAL-clearing ExecStartPre, `ACTORS_HOST=127.0.0.1`, and `MemoryMax=1G` overrides may no longer be needed. Remove one at a time, verify SQLITE_BUSY doesn't recur. **NOTE 2026-08-09:** Post-deploy-check now scans journal for `SQLITE_BUSY|panic` — confirmed alarm lease renewal is STILL hitting `database is locked` every ~10s on 2.12.0. WAL band-aid removal should wait until SQLITE_BUSY is resolved upstream or via config
- [ ] **SearXNG streaming exploration** — User wants streaming results (progressive rendering), not the current "wait for all engines" model. Options: SearXNG fork with SSE endpoint, Go/Rust streaming proxy, or Caddy flush_buffers
- [ ] **Declarative health-check** — `criticalSystemServices` in `scheduled-tasks.nix` is a hand-maintained list of only 4 services (caddy, forgejo, dnsblockd, postgresql). Missing active services: discordsync, searx, qmd-mcp, emeet-pixyd, monitor365, signoz, immich, pocket-id. Generate list from Nix config or `systemctl list-units` instead
- [ ] **Caddy reload root-cause fix** — `PrivateTmp=true` in `harden {}` blocks `systemctl reload caddy` on every deploy (exit code 4). Currently band-aided with unconditional restart in `deploy.sh`. Investigate: (a) `PrivateTmp = lib.mkForce false` on Caddy, (b) `restartTriggers = [ configFile ]` as defense-in-depth, (c) make deploy.sh restart conditional on config diff
- [ ] **Thread flake `inputs` through `tests/default.nix`** — Test infrastructure doesn't receive flake `inputs`, blocking VM tests that need upstream modules (e.g., PMA module gitIdentity → systemd Environment wiring test)
- [ ] **Add `GOTOOLCHAIN=local` to all Go devShells** — Proactive prevention against sandbox purity breaks when `go.mod` exceeds `go_1_26`. Currently safe but will break silently
- [ ] **Browser-history VM test** — Create `tests/browser-history.nix` verifying service starts and `/health` returns 200. Register in `tests/default.nix`
- [ ] **Fix CI port check false-positives** — Regex `(=|:)[[:space:]]*[0-9]{4,5}` in `.github/workflows/nix-check.yml` matches 25 false positives (Docker configs, UIDs, subvolume IDs). Either tighten or remove. Source: 04-59 report (D2)
- [ ] **Fix port-uniqueness VM test quoting** — `tests/test-port-uniqueness.nix` has nested `''${}` escaping issues in testScript string. May not run correctly — was never executed. Source: 04-59 report (D3)
- [ ] **SigNoz dashboard JSONs v1→v2 Perses schema migration** — 5 dashboard files (`signoz-overview.json`, `gpu.json`, `dns.json`, `docker.json`, `caddy.json`) are in v1 flat format but POSTed to v2 API. Currently non-fatal warnings. Perses schema requires `spec.display`, `spec.layouts`, `spec.panels`. Source: `docs/status/archived/2026-08-10_02-53_deploy-failure-diagnosis-and-fixes.md`
- [ ] **node_exporter textfile metrics phantom issue** — 14 `system_*` and `niri_running` metrics in valid `.prom` files don't appear in node_exporter's `/metrics` output. 14 Gatus health checks permanently RED. Worked around in `KNOWN_NEW_METRICS` list but root cause unknown (textfile collector config, file permissions, or node_exporter version bug). Source: 02-53 report
- [ ] **Convert remaining raw I/O literals to `ioTier.*`** — 5 services in `boot.nix` (sshd, niri, dms, pipewire, fstrim) and 1 in `security-hardening.nix` (clamav) still use raw `IOSchedulingClass`/`IOSchedulingPriority` instead of `ioTier.*` helpers. Source: 04-59 report (E4)
- [ ] **GOMEMLIMIT runtime validation** — Values (75% of MemoryMax) are reasonable defaults but actual Go GC behavior depends on heap live-set. dnsblockd's value was tuned from real OOM data; the new 6 values are starting points that need runtime verification via `runtime.MemStats` or GC logs. Source: 04-59 report (E6)
- [ ] **Add GOMEMLIMIT to remaining Go services** — attic, file-and-image-renamer, crush-daily still lack GOMEMLIMIT. Source: 04-59 report (item 32-33)
- [ ] **ClickHouse backup before SigNoz upgrade** — Schema migrator runs on startup. No backup taken before v0.127.1→main upgrade. `clickhouse-client -q "BACKUP DATABASE signoz TO Disk('backups', 'pre-signoz-main-upgrade.zip')"`. Source: `docs/status/archived/2026-08-09_06-31_signoz-flake-url-version-pin-removal.md`
- [ ] **memory.events metric monitoring** — Scrape `/sys/fs/cgroup/.../memory.events` per monitored service. The `max` counter is the truest death-loop signal — fires at cgroup boundary before CPU/memory thresholds. Would have caught the PMA death-loop (27,312 hits) before PSI hit 95%. Source: `docs/status/archived/2026-08-09_11-40_pma-death-loop-crash-analysis-and-fix.md`

## Priority 4: Code Quality

- [ ] **Delete dead `scripts/nvme-metrics.sh`** — Orphaned script split-brained with inline `nvmeMetrics` in `_signoz-metrics.nix`. The deployed collector is the inline version; the script is dead code that was accidentally edited instead of the real implementation
- [ ] **Verify `crush-daily-backfill.py` re-insert SQL schema** — The `INSERT INTO events` assumes columns `id, aggregate_id, event_type, payload, occurred_at`. Never checked against the actual `CREATE TABLE` in crush-daily source. If column names/types don't match, the re-insert crashes. Source: `docs/status/archived/2026-08-10_04-55_vm-tests-verified-and-self-assessment.md`
- [ ] **Fix `test-home-manager.sh` TESTS_TOTAL inflation** — 20+ increment sites, some branches increment by 2-3. The summary line reports an inflated total. Source: 04-55 report
- [ ] **Decide on `niri-health.sh`** — Unreferenced by any Nix module. Either delete (dead code) or wire to a systemd service/timer. Source: 04-55 report
- [ ] **Add `ruff check scripts/*.py` to pre-commit** — Python scripts (5) have zero linting. One-line addition to `.githooks/pre-commit`. Source: 04-55 report
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
- [ ] **Fix IO-heavy journalctl patterns** — `scripts/usb-diagnostic.sh:53`, `scripts/verify-deployment.sh:46,48`, `scripts/internet-diagnostic.sh:97` use `journalctl | grep` (burns 98% CPU). Switch to `journalctl --grep`. Add pre-commit guard for `journalctl.*|.*grep` pattern. **NOTE 2026-08-09:** post-deploy-check.sh Pocket ID scan uses `journalctl ... > file` then `grep file` — acceptable (file-based, no pipe), but could be optimized with `journalctl --grep`
- [ ] **Systemd hardening consistency audit** — Several hardening primitives are in some services but not all. Audit: `TimeoutStopSec` (services that hang on shutdown), `RestartSec` consistency (5s/10s/30s variation), `ProcSubset` (kernel 6.2+), `RestrictAddressFamilies`, `SystemCallArchitectures`, `LockPersonality`, `UMask` (022 vs 007). Add missing primitives to `harden()` helper
- [ ] **Monitoring gaps from prevention plan** — Add Gatus checks for: oauth2-proxy itself (not just services behind it), Caddy config reload success (silent failures), dnsblockd block page HTTPS endpoint (cert issues), BTRFS scrub freshness (days since last successful scrub as textfile metric)
- [ ] **CI improvements** — (a) Add `gatus-patterns` and `pma-identity` to `.github/workflows/nix-check.yml` vm-tests job, (b) run VM tests on PR not just push, (c) add CI check for duplicate port assignments across modules, (d) add pre-commit check for `lib.optionalAttrs` without `config.services.X.enable` guard
- [ ] **AGENTS.md documentation gaps** — (a) Document Caddy `PrivateTmp` reload gotcha (reload fails on every deploy due to hardening), (b) document phantom metric pre-deploy check chicken-and-egg, (c) fix stale version "Chromium 150" → "Chromium 151" in Helium gotcha, (d) document prevention layers in `docs/CONTRIBUTING.md` for non-AGENTS.md readers
- [ ] **Create dep-audit script for LarsArtmann Go repos** — Cross-reference ALL `go.mod` require lines against flake.nix pinned revs before deploy. Would have caught go-etag, go-idempotency, AND go-retry cascading failures in one pass instead of 3 separate deploy cycles
- [ ] **dnsblockd CA cert deployment automation** — Create deployment script for macOS (`security add-trusted-cert` flow) and guide for iOS/Android (MDM profile or manual import). Prevents TLS handshake spam (224K errors/day) when devices don't trust the CA

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
- [ ] **Try native ZFS on host kernel 7.1** — Connected 2x16TB external ZFS mirror pool (`datapool`, only 21.4GB / 0.14% used — mostly disposable Docker images). nixpkgs claims ZFS 2.4.3 max kernel is 6.18, but OpenZFS 2.4.3 actually supports up to 7.0 (ONE minor behind host's 7.1). VFIO VM passthrough PROVEN WORKING but unnecessary if native ZFS compiles. 3-line config change: `boot.supportedFilesystems = [ "zfs" ]`. Source: `docs/status/2026-08-10_06-44_zfs-vfio-passthrough-success.md`
- [ ] **Decide ZFS pool fate: keep, reformat to BTRFS, or dismiss** — Pool is 99.86% empty (21GB of 14.5TB). Data is almost entirely disposable Docker container images. Reformatting costs nothing. Source: 06-44 report
- [ ] **SMART monitoring for external ZFS drives** — `smartctl -a /dev/sda` and `/dev/sdb`. 16TB HDDs in USB enclosures run hot. Check reallocated sectors, pending sectors, temperature. Source: 05-49 report
- [ ] **Deploy.sh backup retention** — Backup step creates timestamped `.bak` files on every deploy but never cleans them up. Add retention policy (keep last 3). Source: `docs/status/archived/2026-08-09_05-28_extension-dms-verification-and-settings-backup.md`
- [ ] **Add `dms` to `dms-wallpaper-init` runtimeInputs** — Script calls `dms ipc call wallpaper get/set` but `dms` is NOT in runtimeInputs. Works only because `dms` is on session PATH. Fragile under `hardenUser` restrictions or PATH changes. Source: 05-28 report
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

**All 11 items below are now automated in `scripts/post-deploy-check.sh`.** Run `nix run .#post-deploy-check` after every deploy — no manual steps required.

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

_All post-deploy-check manual-only items have been resolved (double-000 fix, hermetic runtimeInputs, shellcheck pre-commit). No remaining manual-only items._

---

_Completed work is tracked in [CHANGELOG.md](./CHANGELOG.md)._
