# SystemNix TODO List

**Updated:** 2026-08-14 | **Last sessions:** docs harvest of all 2026-08-14 status reports (completed items moved to CHANGELOG, only open work remains here); SigNoz dashboard v2 migration research (schema extracted from exact locked rev — 251 duplicate dashboards, empty-panel bug, and dead queries discovered, implementation not started); browser-history registration lock (cqrs-htmx `MaxUsers` gate — OAuth2 bypass + release still open) + oomd threshold raise 50%/20s→60%/30s; systemd hardening audit + I/O-throttled dev wrappers; smart-audio daemon + qmd retirement + Twenty hardening; monitoring gap closures, mkOidcGate/mkDnsGate refactors

---

## Priority 0: Critical (Data Loss / System Risk)

- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. The Aug 3 corruption event (13 files lost) proves this is not theoretical. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged since 2026-06-25. **Manual action:** set up Hetzner StorageBox + BorgBackup
- [ ] **Free disk space urgently** — Root filesystem at 90-93% on QLC NAND. High fill increases write amplification, SLC cache exhaustion, and WDT crash risk. Candidates: `nix-collect-garbage -d`, delete old BTRFS snapshots (`sudo btrbk prune`), `docker system prune`, audit `/data/activitywatch` (12G), Steam (5.9G), DuckDB (13G). **Source:** Multiple 08-11/08-12 reports
- [ ] **Add `ManagedOOMPreference=omit` to dnsblockd** — dnsblockd is the sole DNS resolver on :53 and lacks oomd exemption. It's being killed **730 times/day** (1,591 since boot) because it's the largest non-exempt service when system-slice memory pressure exceeds the oomd threshold (now 60%/30s, raised from 50%/20s this session — kill rate should drop but exemption is still the proper fix). Each kill breaks DNS for all LAN clients. PMA's page-cache reclaim (6.6 GiB, 2.9M MemoryHigh events) is the pressure source. Same pattern as nix-daemon and PMA exemptions. IO PSI at 65% — 6.5x the WDT crash threshold. **Mitigation applied:** MemoryMax raised 2G→4G, GOMEMLIMIT 1500MiB→3GiB. Exemption still needed. **Verified:** Aug 14 live data
- [ ] **Run foreground BTRFS scrub on `/`** — `/dev/nvme0n1p6` (`/`) has NEVER been scrubbed. Same physical NVMe as `/data` which had 13 corrupted files. SMART says drive is healthy (11% wear, 0 media errors), but root FS corruption would be catastrophic. **Manual command:** `sudo btrfs scrub start -B /`
- [ ] **Reboot evo-x2** — NixOS system registry override for nixpkgs tarball regression is in config but NOT active until reboot (currently running old registry). Hyprland purge also needs reboot. The registry override is critical defense against the recurring tarball regression. **Source:** Multiple reports since 08-10

## Priority 1: High (Service Outages)

- [ ] **Fix hermes crash-loop — `ModuleNotFoundError: No module named 'registration_lifecycle'`** — hermes.service hits `start-limit-hit` after 5 restarts (verified live Aug 14 09:19; error persists in journal within the last 48h). Python packaging gap: the module is missing from the env derivation. Dead since the 2026-08-13 deploy and it blocks clean `nh os switch` activations (deploy.sh `reset-failed` only works around it). Fix the derivation, verify with `journalctl -u hermes.service`, then do the Hermes runtime verification below. **Source:** `docs/status/2026-08-14_08-24_smart-audio-daemon-built-deployed-with-gaps.md`

## Priority 2: Manual Steps (Blocked on Human)

- [ ] **Smart-audio: verify audible output + reverse direction** — Play a test sound on the TV (DP-2 routed, node 57), then switch focus to DP-1 (monitor) and confirm the profile switches back. PipeWire routing was verified via `wpctl status` but actual audibility has NEVER been tested — flagged as a pattern failure in two consecutive reports. **Source:** `docs/status/2026-08-14_08-24_smart-audio-daemon-built-deployed-with-gaps.md`
- [ ] **Clean up qmd cache** — `~/.cache/qmd/` still holds ~2GB GGUF models + index after the qmd retirement. **Manual:** `trash ~/.cache/qmd`
- [ ] **Hermes: install SSH deploy key** — private key to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model`
- [ ] **Hermes runtime verification** — Hermes re-enabled (`2090bd7e`) but Discord bot presence, cron job registration, and gateway request handling were NEVER verified. Check `journalctl -u hermes.service`. **Source:** `docs/status/2026-08-12_13-05_overview-hermes-pma-split-mode-startlimit-hardening.md`
- [ ] **Test browser-history OAuth2 login end-to-end** — Visit `https://history.home.lan`, click "Login with Pocket ID", verify redirect flow completes and dashboard loads with data. CSS fix deployed (`bb998e8d`), StartLimit fixed (`a941f88d`). **Source:** `docs/status/2026-08-12_14-59_browser-history-css-and-startlimit-fixes.md`
- [ ] **Verify dnsblockd dashboard auth** — `sudo systemctl restart dnsblockd.service`, then visit `https://dnsblock.home.lan/dashboard`, enter token (retrieve via sops), confirm stats load. Widget should show block counts. **Source:** `docs/status/2026-08-12_14-55_dnsblockd-dashboard-auth-comprehensive-review.md`
- [ ] **WebAuthn `.lan` RP ID browser validation** — Verify browsers accept passkey registration on `history.home.lan` (`.lan` is not a real TLD; Chrome/Firefox may reject)
- [ ] **Turso plan decision** — DiscordSync crash-loops on Turso `unexpected EOF` after dbHeal cascade. Currently on sqlite-only backend. Decide: keep sqlite-only, re-auth Turso, or upgrade plan
- [ ] **Deploy to macOS** — Darwin registry override for nixpkgs written in config (`platforms/darwin/nix/settings.nix`) but NOT deployed. Run `nix run .#deploy` on `Lars-MacBook-Air`
- [ ] **Clean up orphaned dnsblockd tracking DB** — `/var/lib/dnsblockd/dnsblockd_tracking.db` (724 MB, last modified Jul 15) is the old database from before the rename to `tracking.db`. **Manual:** `sudo trash /var/lib/dnsblockd/dnsblockd_tracking.db`

## Priority 3: Infrastructure

- [ ] **Add eval-time assertion for `StartLimitBurst` placement** — In systemd 261+, `StartLimitBurst`/`StartLimitIntervalSec` in `serviceConfig` (=[Service]) are SILENTLY IGNORED. This caused the 2026-08-11 WDT crash chain (browser-history 592 restarts). Create `start-limit-audit.nix` that catches this pattern at eval time. **Source:** `docs/status/2026-08-11_23-28_wdt-crash-postmortem-deploy-blockers.md`, AGENTS.md StartLimitBurst gotcha
- [ ] **Fix browser-history `expires_at` session reaper error** — Every 5 min: `session reaper failed: no such column: expires_at`. SQLite sessions table missing column, migration gap in browser-history upstream. Investigate schema migration. **Source:** `docs/status/2026-08-12_14-17_browser-history-oidc-secret-desync-fix.md`
- [ ] **Fix browser-history `CheckpointStore` upstream** — Server replays ALL events on startup (4-min projection drain) because there's no persistent checkpoint store. Requires cqrs-htmx `HydrateFromSQL`. Causes availability gap on every restart. **Source:** `docs/status/2026-08-12_10-20_comprehensive-session-review.md`
- [ ] **Release + deploy registration lock and go.work fix** — The `MaxUsers` registration gate is committed upstream (cqrs-htmx `e5cdc925`: identity-model/errors.go, usermgmt/{errors,service_core,service_register,service_register_test}.go; browser-history `b750ec5`: api/{config,server}.go + go.work identity-model replace — both swept in by the auto-git daemon) but untagged and NOT deployed: nothing is live. Steps: fix the pre-existing `cqrs-htmx/usermgmt/es_materialize_adapter_test.go` drift vs local go-cqrs-lite (missing `DeleteTypes`/`DeleteInclude` — blocks CI/tagging; the file currently has uncommitted working-tree changes), tag cqrs-htmx (identity-model + usermgmt consumers), bump browser-history `go.mod` to require the new tags BEFORE the SystemNix flake bump (the go.work replaces hide the version dependency locally; the Nix build uses published versions), tag browser-history, bump SystemNix `browser-history` flake input, deploy, then verify `POST /auth/register` returns 403 while logged-out
- [ ] **Browser-history DB backup** — `/var/lib/browser-history/data.db` (SQLite WAL mode) is NOT in `backup-coordination`. Needs periodic `sqlite3 .backup` job + entry in `configuration.nix` `services.backup-coordination.backups`. Stagger schedule (01:00–03:00 window)
- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), has btrbk snapshot protection but not a named subvolume. Migration to `@data` would enable separate CoW semantics. Requires ~1h downtime
- [ ] **Create Attic cache + CI token** — Attic module deployed but cache not yet created. Steps: `attic cache create monitor365`, `atticadm make-token --sub ci --validity 1y --push monitor365 --pull monitor365`, configure Forgejo runner. See `docs/services/nix-binary-cache-setup.md`
- [ ] **Enable niri blur** — Terminal transparency added (88%/90%) but niri's blur option is NOT configured (niri HM module lacks `blur {}` option). Transparent terminals without blur are hard to read
- [ ] **Caddy reload root-cause fix** — `PrivateTmp=true` in `harden {}` blocks `systemctl reload caddy` on every deploy (exit code 4). Currently band-aided with unconditional restart in `deploy.sh`
- [ ] **Declarative health-check** — `criticalSystemServices` in `scheduled-tasks.nix` is a hand-maintained list of only 4 services. Missing active services: discordsync, searx, monitor365, signoz, immich, pocket-id. Generate list from Nix config instead
- [ ] **Fix OTel endpoint URL scheme upstream (browser-history)** — Uses `otlptracegrpc` with `127.0.0.1:4317` (missing `http://` scheme). Go OTel library expects a URL. Fix edited in SystemNix but needs upstream confirmation + deploy. **Source:** `docs/status/2026-08-12_14-59_browser-history-css-and-startlimit-fixes.md`
- [ ] **SigNoz dashboards: v1→v2 Perses migration + provisioner idempotency + live-DB cleanup** — Research 100% complete; full v2 "v6" schema extracted from the exact locked SigNoz rev (`docs/status/2026-08-14_10-00_signoz-dashboard-v2-perses-migration-research.md`, 30-step execution list). Three coupled problems: (1) the 5 dashboard JSONs are v1 format — v2 POSTs return 2xx but the create-time migration only preserves `spec.display`, producing EMPTY dashboards (`panels: {}`, `layouts: []`); (2) the provisioner (`_signoz-scripts.nix:113-135`) POST-creates on every run with no idempotency — 251 duplicate/broken dashboards in the live DB, growing by 5 per deploy (legacy v5 entries are 501-zombies: listed but unreadable, delete-only); (3) dead queries — `dns.json` targets removed `unbound_*` metrics plus a literal `"0"` placeholder panel, `signoz-overview.json` CPU temp uses `node_hwmon_temp_celsius` (real metric: `node_amdgpu_gpu_temp_celsius`), `docker.json` `container_restart_total` unverified. Order: fix provisioner first (PUT-by-name else POST, failures = FAILED), one-time purge of the 251 (user decision: purge all vs inspect for hand-created dashboards first), then rewrite the 5 JSONs against verified live metrics (enumerate `:9100`/`:9193`/caddy/dnsblockd `/metrics` first), `trash` the unused Grafana-format `overview.json`, update AGENTS.md
- [ ] **Add v2 dashboard schema lint to pre-commit/CI** — `gatus-pattern-lint` precedent: script-side JSON validation (schemaVersion v6, exactly 1 query per panel, all layout `$ref`s resolve, 12-column geometry) so a v1-format regression fails CI instead of warning at deploy time. **Source:** signoz migration report step 18
- [ ] **Verify `audio.nix` WirePlumber priority rules don't fight smart-audio** — `device.restore-profile = false` + `device.profile.priority.rules` were designed for static profile preference; the smart-audio daemon switches profiles dynamically on niri focus. They may fight each other on device events. Verify coexistence, then remove the superseded rules. **Source:** `docs/status/2026-08-14_08-24_smart-audio-daemon-built-deployed-with-gaps.md`
- [ ] **AGENTS.md additions (3 gaps)** — (1) smart-audio module doc: architecture, options, and the fact that HDMI audio profiles are mutually exclusive on the Radeon card (profile switching, not just sink switching); (2) `writers.writePython3Bin` runs a strict pyflakes/pycodestyle linter at build time — use `writeScriptBin` + python shebang for daemon scripts (cost a full build+deploy cycle); (3) browser-history `go.work` needs the `identity-model/v4 => ../cqrs-htmx/identity-model` local replace or builds break against local cqrs-htmx (20-min diagnosis if unknown)
- [ ] **Annotate superseded status reports** — `2026-08-13_09-06_hdmi-audio-routing-wireplumber-profile-priority.md` (claims routing "solved" — superseded by the smart-audio daemon), `2026-08-13_23-39_hdmi-tv-audio-runtime-fix-persistence-gap.md` (persistence gap RESOLVED by smart-audio daemon), `2026-08-12_20-08_nix-daemon-oomd-kill-and-twenty-worker-restart-loop.md` (resolved by the oomd 60%/30s raise once rebooted). Inline `done at` markers, not appendix-only
- [ ] **ClickHouse backup before SigNoz upgrade** — Schema migrator runs on startup. No backup taken before upgrades. `clickhouse-client -q "BACKUP DATABASE signoz TO Disk('backups', 'pre-signoz-upgrade.zip')"`
- [ ] **Add Dozzle container security hardening** — Dozzle has Docker socket mounted read-only but is missing `security_opt = ["no-new-privileges:true"]`, `cap_drop = ["ALL"]`. A container with Docker socket access can escape to the host. Memory limits were added but security hardening was not. Uses `oci-containers` abstraction (not Compose), so uses `extraOptions` not YAML keys
- [ ] **Standardize Docker container hardening** — No single helper exists for applying standard memory limits, log rotation, security options to Docker containers. Manifest/Twenty use Compose (`mkDockerServiceFactory`) with `mem_limit`/`memswap_limit` keys. Dozzle uses `oci-containers` with `extraOptions` flags. Create a helper analogous to `harden {}` for systemd
- [ ] **Verify vendorHash pre-deploy check patterns at runtime** — Check #11 in `pre-deploy-check.sh` uses grep patterns (`"would build"`, `"would (copy|fetch)"`) based on nix CLI conventions but NOT yet verified against real `nix build --dry-run` output. Run end-to-end at next deploy to confirm patterns match
- [ ] **Add `--force` flag to deploy.sh for phantom metrics** — When deploying NEW metrics, pre-deploy-check blocks because old system hasn't emitted new metrics yet. Add documented escape hatch (`--skip-phantom-checks` or `--force`) instead of bypassing safety gates manually
- [ ] **Extend mkOidcGate with optional diagnostic output** — The oauth2-proxy refactor lost TLS fingerprint diagnostic (`openssl x509 -fingerprint` output on failure). Add optional `diagnosticMessage` parameter to `mkOidcGate`
- [ ] **Refactor discordsync to use shared gate helper** — DiscordSync has a `waitDnsReady` that probes `https://discord.com` via curl (external HTTP, not local DNS). Current `mkDnsGate` only does `getent hosts`. Either extend helper with HTTP mode or create `mkHttpGate`
- [ ] **Move gate helpers to `lib/gates.nix`** — `lib/default.nix` is 300+ lines. Gate helpers are a cohesive unit deserving their own file
- [ ] **Add eval-time assertions to gate helpers** — Validate `domain` non-empty, `serviceName` has no spaces (would break script derivation name)
- [ ] **Clean up stale qmd references in planning docs** — `docs/service-integration-plan.md` (lines 276-295: SearXNG adapter, Crush Daily QMD integration), `docs/crash-analysis-2026-08-11.md:143` (SQLite WAL recommendation mentions qmd)
- [ ] **SearXNG streaming exploration** — User wants streaming results (progressive rendering). Options: SearXNG fork with SSE endpoint, Go/Rust streaming proxy, or Caddy flush_buffers

## Priority 4: Code Quality

- [ ] **VendorHash CI check across LarsArtmann repos** — dnsblockd has a `vendor-hash` check; replicate across browser-history, crush-daily, file-and-image-renamer, and all other Go repos
- [ ] **GOMEMLIMIT runtime validation** — Values (75% of MemoryMax) are reasonable defaults but actual Go GC behavior depends on heap live-set. Verify via `runtime.MemStats` or GC logs after deploy
- [ ] **Create dep-audit script for LarsArtmann Go repos** — Cross-reference ALL `go.mod` require lines against flake.nix pinned revs before deploy

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

- [ ] **cqrs-htmx/browser-history: close the registration-lock security gap** — The `MaxUsers` gate covers `POST /auth/register` ONLY. OAuth2 (Pocket ID) first-login auto-provisioning dispatches `RegisterUserCmd` directly in cqrs-htmx `OAuth2Service` and bypasses the cap — a second user can still be created via "Login with Pocket ID" (user decision needed: reject second user vs auto-provision). Also: the count check is advisory (TOCTOU between `readModel.Count()` and dispatch — an event-sourced invariant in the `UserState` fold would close it); no HTTP handler test exists for the 403 status mapping (`WithHTTPStatus` path untested); the frontend register form still renders and now surfaces a raw 403; no monitoring alerts if browser-history user count exceeds 1 (detects ANY bypass). **Source:** `docs/status/2026-08-14_10-04_registration-lock-oomd-threshold-session.md`
- [ ] **cqrs-htmx/browser-history repo hygiene** — Run the full browser-history test suite (`go test ./api/...` — never executed in the lock session; only `go vet` was run); document `MAX_USERS` in the browser-history README; `gofmt` cqrs-htmx `context_actor_test.go` (pre-existing unformatted file)
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
- [ ] **Re-evaluate oomd thresholds after reboot** — If 60%/30s proves insufficient (dnsblockd kill rate stays high), consider per-slice refinement: tighter limit on `system.slice` only, looser globally. Also re-check `user-1000.slice` `MemoryHigh=80G/MemoryMax=90G` headroom against the raised threshold. Watch `system_oomd_kills_total` and the Twenty worker restart count post-reboot

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
