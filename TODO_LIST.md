# SystemNix TODO List

**Updated:** 2026-08-14 (docs-health audit) | **Last sessions:** hermes `registration_lifecycle` fix (downstream patch, upstream PR pending); vendorHash drift checks across 11 LarsArtmann repos (5 stale hashes caught); systemd `harden()` primitives + I/O-throttled dev wrappers; registration lock (OAuth2 gate + TOCTOU closed upstream — release chain open); oomd 50%/20s→60%/30s + dnsblockd MemoryMax 4G; monitoring gap closures (crash-loop, oomd, docker, disk, textfile health); mkOidcGate/mkDnsGate + 4-service refactor; smart-audio daemon; qmd retirement; HaGeZi GitLab mirror; ZRAM tuning; niri outputs config

---

## Priority 0: Critical (Data Loss / System Risk)

- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. The Aug 3 corruption event (13 files lost) proves this is not theoretical. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged since 2026-06-25. **Manual action:** set up Hetzner StorageBox + BorgBackup
- [ ] **Free disk space** — Root filesystem at 86% (was 90-93%; ~18 GiB reclaimed 2026-08-14 by removing migrated cache sources + trash-empty). High fill increases write amplification, SLC cache exhaustion, and WDT crash risk. The "Root Disk Usage" Gatus alert (85%) still fires. Candidates: `nix-collect-garbage -d`, old BTRFS snapshots, `docker system prune`, audit `/data/activitywatch` (12G), Steam (5.9G), DuckDB (13G), retirement of the now-redundant cache subvolume mounts (`.cache`/`go`/`.npm`/`.cargo` — see reclaim item below). **Source:** Multiple 08-11 → 08-14 reports
- [ ] **Add `ManagedOOMPreference=omit` to dnsblockd** — dnsblockd is the sole DNS resolver on :53 and lacks oomd exemption. It was killed **730x/day** at the 50%/20s threshold (1,591 since boot). The 60%/30s raise (deployed 2026-08-14) should cut the rate, but exemption is the proper fix — hermes was oomd-killed at 3.7G peak the same day (same pressure source: PMA page-cache reclaim). Mitigations applied: MemoryMax 2G→4G, GOMEMLIMIT 3GiB. **Verified:** Aug 14 live data
- [ ] **Run foreground BTRFS scrub on `/`** — `/dev/nvme0n1p6` (`/`) has NEVER been scrubbed. Same physical NVMe as `/data` which had 13 corrupted files. SMART says drive is healthy (11% wear, 0 media errors), but root FS corruption would be catastrophic. **Manual command:** `sudo btrfs scrub start -B /`
- [ ] **Reboot evo-x2** — Multiple deployed changes need a reboot to activate: (1) NixOS system registry override for nixpkgs tarball regression, (2) oomd 60%/30s threshold (oomd reads config at daemon start), (3) Hyprland purge, (4) niri outputs config persistence verification, (5) `/mnt/buildcache` mount options (`data=writeback,commit=120,lazytime` — live mount still runs `data=ordered,commit=5` from the manual migration mount; ext4 journal data mode cannot be changed by remount). Post-reboot verify: `tr ' ' '\n' < /proc/fs/ext4/sdb1/options | grep -E '^(data|commit)='` and `buildcache-init` re-run is a no-op (`.initialized` stamp). **Source:** Multiple reports since 08-10; buildcache session 08-14

## Priority 1: High (Service Outages / Security)

- [ ] **PMA discovery daemon starvation — upstream root cause** — The daemon goroutine starves in cgroup direct reclaim while the 260-repo discovery scan runs (socket accepts connections, never answers; 3 hangs on 2026-08-14 incl. one that lasted 21h and 503'd Overview the whole time). SystemNix mitigations deployed 2026-08-14: `MemoryHigh` 6G→12G + `MemoryMax` 8G→16G (scan working set outgrew the old ceiling), `PMA_DISCOVERY_WORKERS=2`, and `pma-daemon-watchdog` (5-min liveness probe → restart after 2 failed probes). Root fix belongs upstream in projects-management-automation: bound per-worker scan memory, or make the daemon goroutine reclaim-insensitive (pre-fault its pages / lower goroutine GOMAXPROCS isolation). Also upstream: the module emits unquoted `GIT_AUTHOR_NAME=Lars Artmann` env entries — systemd drops "Artmann" and spams the journal on every load (SystemNix adds quoted duplicates as workaround; fix is quoting upstream). **Source:** 2026-08-14 buildcache session monitor logs
- [ ] **Bump `overview` flake input past `a9321f0`** — Upstream fix (StartLimit* moved to top-level/[Unit]) is committed locally in `/home/lars/projects/overview` but NOT pushed. After push: `nix flake lock --update-input overview`, deploy, then delete the stale `[Service]` StartLimit copies and the interim comment in SystemNix's `overview.nix`. **Source:** 2026-08-14 buildcache session

- [ ] **Gate `import_export.go` user-import path (registration lock hole #3)** — cqrs-htmx `importUsers()` (`usermgmt/import_export.go:156`) dispatches `RegisterUserCmd` directly, bypassing both the `MaxUsers` check and the `registrationMu` lock. Admin-only (CSV upload), so lower risk than the OAuth2 bypass, but the gate is incomplete until this is closed. Same pattern as the two closed paths; ~15-min fix. Also re-run `rg "NewRegisterUserCmd" usermgmt/*.go | grep -v test` to audit for any 4th dispatch site. **Source:** `docs/status/2026-08-14_10-41_oauth2-gate-toctou-fix-self-critical-review.md`
- [ ] **Fix forgejo-oidc-setup deploy restart race** — Recurring activation blocker: `forgejo-oidc-setup.service` runs before Caddy is up → `dial tcp 192.168.1.150:443: connection refused` → `nh os switch` exit 4 → partial activation (seen 08-13 and 08-14, blocked the hermes deploy's post-steps). Fix: `after`/`wants` on `caddy.service`, or reuse `mkOidcGate`. Same class as the browser-history agent→server race (fixed 08-10). **Source:** `docs/status/2026-08-14_13-44_hermes-registration-lifecycle-fixed-deploy-partial.md`

## Priority 2: Manual Steps (Blocked on Human)

- [ ] **Smart-audio: verify audible output + reverse direction** — Play a test sound on the TV (DP-2 routed, node 57), then switch focus to DP-1 (monitor) and confirm the profile switches back. PipeWire routing verified via `wpctl status` but actual audibility has NEVER been tested — flagged as a pattern failure in three consecutive reports. **Source:** `docs/status/2026-08-14_08-24_smart-audio-daemon-built-deployed-with-gaps.md`
- [ ] **Clean up qmd cache** — `~/.cache/qmd/` still holds ~2GB GGUF models + index after the qmd retirement. **Manual:** `trash ~/.cache/qmd`
- [ ] **Hermes: install SSH deploy key** — private key to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model`
- [ ] **Test browser-history OAuth2 login end-to-end** — Visit `https://history.home.lan`, click "Login with Pocket ID", verify redirect flow completes and dashboard loads with data. CSS fix deployed (`bb998e8d`), StartLimit fixed (`a941f88d`), secret desync fixed (regenerated + revert deployed). **Source:** `docs/status/2026-08-12_14-59_browser-history-css-and-startlimit-fixes.md`
- [ ] **Verify dnsblockd dashboard auth** — Visit `https://dnsblock.home.lan/dashboard`, enter token (retrieve via sops), confirm stats load. Widget sends Bearer header. **Source:** `docs/status/2026-08-12_14-55_dnsblockd-dashboard-auth-comprehensive-review.md`
- [ ] **WebAuthn `.lan` RP ID browser validation** — Verify browsers accept passkey registration on `history.home.lan` (`.lan` is not a real TLD; Chrome/Firefox may reject)
- [ ] **Turso plan decision** — DiscordSync crash-loops on Turso `unexpected EOF` after dbHeal cascade. Currently on sqlite-only backend. Decide: keep sqlite-only, re-auth Turso, or upgrade plan
- [ ] **Deploy to macOS** — Darwin registry override for nixpkgs written in config (`platforms/darwin/nix/settings.nix`) but NOT deployed. Run `nix run .#deploy` on `Lars-MacBook-Air`
- [ ] **Clean up orphaned dnsblockd tracking DB** — `/var/lib/dnsblockd/dnsblockd_tracking.db` (724 MB, last modified Jul 15) is the old database from before the rename to `tracking.db`. **Manual:** `sudo trash /var/lib/dnsblockd/dnsblockd_tracking.db`
- [ ] **BIOS fix for DAS boot hang** — GLMtec logo hang: disable USB boot, enable Fast Boot, NVMe-only boot priority. Manual BIOS change; will recur on every cold boot with the DAS connected until done. **Source:** `docs/status/2026-08-14_08-23_boot-failure-diagnosis-qmd-removal-activitywatch-fix.md`
- [ ] **Hermes: check upstream for `registration_lifecycle` fix** — If a newer hermes-agent rev adds it to `py-modules`, bump the flake input and DELETE the SystemNix PYTHONPATH patch (hidden second source of truth). File upstream issue/PR to NousResearch/hermes-agent. **Source:** `docs/status/2026-08-14_13-44_hermes-registration-lifecycle-fixed-deploy-partial.md`
- [ ] **Move Docker data-root to SSD 2 (btrfs)** — Second SanDisk SDSSDA240G (serial 174244451713, btrfs+compress=zstd, ~224 GiB) is mounted manually at `/mnt/ssd-btrfs` awaiting its role: Docker images/build cache off the QLC NVMe (`/data/docker` today). Keep SigNoz/ClickHouse volumes on `/data` — telemetry history is the only non-re-pullable Docker data. Add declarative `fileSystems` entry under a proper name (e.g. `/mnt/docker`), migrate, wire `virtualisation.docker.daemon.settings.data-root`. smartd already monitors the drive. **Source:** `docs/status/2026-08-14_13-15_ssd-repurposing-options.md`
- [ ] **Reclaim `/rust-cache` partition (nvme0n1p9, 100 GiB) + redundant cache subvolume mounts** — Rust targets moved to `/mnt/buildcache/rust` (2026-08-14); the old ext4 partition still holds a stale 32 GB copy plus its automount. The `@cache-home`/`@go`/`@npm`/`@cargo` subvolume automounts (`/home/lars/.cache`, `/home/lars/go`, `/home/lars/.npm`, `/home/lars/.cargo`) are redundant now that caches live on `/mnt/buildcache` (contents already emptied 2026-08-14). Reclaim: verify monitor365 builds fine on the new cache, remove the `fileSystems` entries (hardware-configuration.nix), delete p9, optionally grow the adjacent BTRFS partition. **Manual:** partition surgery — plan carefully. **Source:** AGENTS.md "Build Cache SSD" section

## Priority 3: Infrastructure

- [ ] **Add eval-time assertion for `StartLimitBurst` placement** — In systemd 261+, `StartLimitBurst`/`StartLimitIntervalSec` in `serviceConfig` (=[Service]) are SILENTLY IGNORED. This caused the 2026-08-11 WDT crash chain (browser-history 592 restarts). The 2026-08-14 "zero violations" audit was WRONG: overview rendered `StartLimitBurst=` (empty) in [Service] — upstream's misplacement compounded by SystemNix's `lib.mkForce null` neutralization, which nixpkgs `attrsToSection` renders as an empty key (null is `toString`-ed, never filtered). Fixed 2026-08-14 (upstream overview `a9321f0` moves them to top-level; SystemNix null-hack deleted). An eval-time guard prevents regressions. Create `start-limit-audit.nix`. **Source:** `docs/status/2026-08-11_23-28_wdt-crash-postmortem-deploy-blockers.md` (archived), AGENTS.md StartLimitBurst gotcha
- [ ] **Fix browser-history `expires_at` session reaper error** — Every 5 min: `session reaper failed: no such column: expires_at`. SQLite sessions table missing column, migration gap in browser-history upstream. Investigate schema migration. **Source:** `docs/status/2026-08-12_14-17_browser-history-oidc-secret-desync-fix.md`
- [ ] **Fix browser-history `CheckpointStore` upstream** — Server replays ALL events on startup (4-min projection drain) because there's no persistent checkpoint store. Requires cqrs-htmx `HydrateFromSQL`. Causes availability gap on every restart. **Source:** `docs/status/2026-08-12_10-20_comprehensive-session-review.md`
- [ ] **Release + deploy registration lock and go.work fix** — The `MaxUsers` registration gate is committed upstream (cqrs-htmx `e5cdc925`: identity-model/errors.go, usermgmt/{errors,service_core,service_register,service_register_test}.go; browser-history `b750ec5`: api/{config,server}.go + go.work identity-model replace — both swept in by the auto-git daemon). The OAuth2 auto-provisioning gate + shared registration mutex (TOCTOU fix) + HTTP 403 handler tests are implemented and verified (full suite + `-race` green, 2026-08-14) but still UNCOMMITTED working-tree changes in cqrs-htmx (`usermgmt/{service_core,service_register,service_oauth2_extracted}.go`, `handler_register_test.go`, `oauth2_http_test.go`, new `service_oauth2_register_test.go`) — they will be swept by the auto-git daemon. The `es_materialize_adapter_test.go` drift no longer blocks tagging (healed 2026-08-14). Note the release includes a BREAKING `NewOAuth2Service` signature change (new `maxUsers`/`registrationMu` params). Steps: commit/verify sweep, tag cqrs-htmx (identity-model + usermgmt consumers), bump browser-history `go.mod` to require the new tags BEFORE the SystemNix flake bump (the go.work replaces hide the version dependency locally; the Nix build uses published versions), tag browser-history, bump SystemNix `browser-history` flake input, deploy, then verify `POST /auth/register` returns 403 while logged-out AND a second Pocket ID first-login is rejected
- [ ] **Browser-history DB backup** — `/var/lib/browser-history/data.db` (SQLite WAL mode) is NOT in `backup-coordination`. Needs periodic `sqlite3 .backup` job + entry in `configuration.nix` `services.backup-coordination.backups`. Stagger schedule (01:00–03:00 window)
- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), has btrbk snapshot protection but not a named subvolume. Migration to `@data` would enable separate CoW semantics. Requires ~1h downtime
- [ ] **Create Attic cache + CI token** — Attic module deployed but cache not yet created. Steps: `attic cache create monitor365`, `atticadm make-token --sub ci --validity 1y --push monitor365 --pull monitor365`, configure Forgejo runner. See `docs/services/nix-binary-cache-setup.md`
- [ ] **Enable niri blur** — Terminal transparency added (88%/90%) but niri's blur option is NOT configured (niri HM module lacks `blur {}` option). Transparent terminals without blur are hard to read
- [ ] **Caddy reload root-cause fix** — `PrivateTmp=true` in `harden {}` blocks `systemctl reload caddy` on every deploy (exit code 4). Currently band-aided with unconditional restart in `deploy.sh`
- [ ] **Declarative health-check** — `criticalSystemServices` in `scheduled-tasks.nix` is a hand-maintained list of only 4 services (caddy, forgejo, dnsblockd, postgresql). Missing active services: discordsync, searx, monitor365, signoz, immich, pocket-id. Generate list from Nix config instead
- [ ] **SigNoz dashboards: v1→v2 Perses migration + provisioner idempotency + live-DB cleanup** — Research 100% complete; full v2 "v6" schema extracted from the exact locked SigNoz rev (`docs/status/2026-08-14_10-00_signoz-dashboard-v2-perses-migration-research.md`, 30-step execution list). Three coupled problems: (1) the 5 dashboard JSONs are v1 format — v2 POSTs return 2xx but the create-time migration only preserves `spec.display`, producing EMPTY dashboards (`panels: {}`, `layouts: []`); (2) the provisioner (`_signoz-scripts.nix:113-135`) POST-creates on every run with no idempotency — 251 duplicate/broken dashboards in the live DB, growing by 5 per deploy (legacy v5 entries are 501-zombies: listed but unreadable, delete-only); (3) dead queries — `dns.json` targets removed `unbound_*` metrics plus a literal `"0"` placeholder panel, `signoz-overview.json` CPU temp uses `node_hwmon_temp_celsius` (real metric: `node_amdgpu_gpu_temp_celsius`), `docker.json` `container_restart_total` unverified. Order: fix provisioner first (PUT-by-name else POST, failures = FAILED), one-time purge of the 251 (user decision: purge all vs inspect for hand-created dashboards first), then rewrite the 5 JSONs against verified live metrics (enumerate `:9100`/`:9193`/caddy/dnsblockd `/metrics` first), `trash` the unused Grafana-format `overview.json`
- [ ] **Add v2 dashboard schema lint to pre-commit/CI** — `gatus-pattern-lint` precedent: script-side JSON validation (schemaVersion v6, exactly 1 query per panel, all layout `$ref`s resolve, 12-column geometry) so a v1-format regression fails CI instead of warning at deploy time. **Source:** signoz migration report step 18
- [ ] **Verify `audio.nix` WirePlumber priority rules don't fight smart-audio** — `device.restore-profile = false` + `device.profile.priority.rules` were designed for static profile preference; the smart-audio daemon switches profiles dynamically on niri focus. They may fight each other on device events. Verify coexistence, then remove the superseded rules. **Source:** `docs/status/2026-08-14_08-24_smart-audio-daemon-built-deployed-with-gaps.md`
- [ ] **System-health collector hardening** — (1) Word splitting: `for cname in $(docker ps ...)` → `while IFS= read -r`; (2) `timeout 5` on `docker inspect`/`docker ps` (hanging Docker daemon currently blocks the whole collector); (3) MemoryMax 128M → 256M (collector now runs docker + journalctl + 12+ systemctl queries); (4) NRestarts triple-read → single read. **Source:** `docs/status/2026-08-14_08-46_monitoring-gap-closures-self-review.md`
- [ ] **VM tests for new Gatus patterns** — Extend `tests/test-gatus-patterns.nix` with the 5 patterns added 2026-08-14 (`system_disk_usage_over_threshold`, `system_any_service_crash_loop`, `system_oomd_kills_alert`, `system_any_docker_container_restart_alert`, `node_textfile_scrape_error`). **Source:** monitoring-gap-closures report §C.9
- [ ] **Hermes build-time import smoke test** — Flake check running `python -c "import hermes_cli.plugins"` against the sealed venv would have caught the `registration_lifecycle` py-modules drift at build time instead of at 09:19 on a production box. **Source:** hermes 08-14 report §e.6
- [ ] **deploy.sh auto-retry on exit 4** — If `nh os switch` exits 4 (restart failure), deploy.sh should run `reset-failed` + retry activation once before aborting. Two consecutive sessions left the system partially activated. **Source:** hermes 08-14 report §e.1
- [ ] **ClickHouse backup before SigNoz upgrade** — Schema migrator runs on startup. No backup taken before upgrades. `clickhouse-client -q "BACKUP DATABASE signoz TO Disk('backups', 'pre-signoz-upgrade.zip')"`
- [ ] **Add Dozzle container security hardening** — Dozzle has Docker socket mounted read-only but is missing `security_opt = ["no-new-privileges:true"]`, `cap_drop = ["ALL"]`. A container with Docker socket access can escape to the host. Memory limits + log rotation were added; security opts were not. Uses `oci-containers` abstraction (not Compose), so uses `extraOptions` not YAML keys
- [ ] **Standardize Docker container hardening** — No single helper exists for applying standard memory limits, log rotation, security options to Docker containers. Manifest/Twenty use Compose (`mkDockerServiceFactory`) with `mem_limit`/`memswap_limit` keys. Dozzle uses `oci-containers` with `extraOptions` flags. Create a helper analogous to `harden {}` for systemd
- [ ] **Verify vendorHash pre-deploy check patterns at runtime** — Check #11 in `pre-deploy-check.sh` uses grep patterns (`"would build"`, `"would (copy|fetch)"`) based on nix CLI conventions but NOT yet verified against real `nix build --dry-run` output. Run end-to-end at next deploy to confirm patterns match
- [ ] **Add `--force` flag to deploy.sh for phantom metrics** — When deploying NEW metrics, pre-deploy-check blocks because old system hasn't emitted new metrics yet (forced an `nh os switch` bypass on 08-14). Add documented escape hatch (`--skip-phantom-checks` or `--force`) instead of bypassing safety gates manually
- [ ] **Extend mkOidcGate with optional diagnostic output** — The oauth2-proxy refactor lost TLS fingerprint diagnostic (`openssl x509 -fingerprint` output on failure). Add optional `diagnosticMessage` parameter to `mkOidcGate`
- [ ] **Refactor discordsync to use shared gate helper** — DiscordSync has a `waitDnsReady` that probes `https://discord.com` via curl (external HTTP, not local DNS). Current `mkDnsGate` only does `getent hosts`. Either extend helper with HTTP mode or create `mkHttpGate`
- [ ] **Move gate helpers to `lib/gates.nix`** — `lib/default.nix` is 300+ lines. Gate helpers are a cohesive unit deserving their own file
- [ ] **Add eval-time assertions to gate helpers** — Validate `domain` non-empty, `serviceName` has no spaces (would break script derivation name)
- [ ] **Clean up stale qmd references in planning docs** — `docs/service-integration-plan.md` (lines 276-295: SearXNG adapter, Crush Daily QMD integration), `docs/crash-analysis-2026-08-11.md:143` (SQLite WAL recommendation mentions qmd)
- [ ] **SearXNG streaming exploration** — User wants streaming results (progressive rendering). Options: SearXNG fork with SSE endpoint, Go/Rust streaming proxy, or Caddy flush_buffers
- [ ] **Track wf-recorder FFmpeg 7 upstream fix** — `wfRecorderFfmpeg6Overlay` in `overlays/linux.nix:203` pins ffmpeg_6 because wf-recorder 0.6.0 accesses AVCodec fields FFmpeg 7 made private. Remove overlay when upstream releases a fix. **Source:** `docs/status/2026-08-13_18-36_flake-lock-repair-and-build-failures.md`
- [ ] **Pin go-cqrs-lite benchstat `rev = "master"`** — Third-party (golang/perf) tool with a floating rev; its hashes WILL drift again on every `nix flake update` (already required 2 hash fixes). Pin to a commit or drop the check. **Source:** `docs/status/2026-08-14_13-22_vendorhash-hardening-iowrap-gomemlimit-session.md`

## Priority 4: Code Quality

- [ ] **Run `scripts/validate-gomemlimit.sh` after next deploy** — Script created + SigNoz collector GOMEMLIMIT normalized (384→768MiB) but the validation script has NEVER been executed (systemctl permission wall during authoring session). First run will likely reveal grep-pattern bugs. Also consider wiring it as a flake app (`nix run .#validate-gomemlimit`)
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

- [ ] **`jscpd` lockfile** — PR upstream to publish `pnpm-lock.yaml` (the vendored lockfile needed a typo fix, `72115c62`)
- [ ] **XRT boost 1.87+ compat** — PR to `nix-amd-npu` to pin `boost187` for XRT build
- [ ] **Upstream direnv caching pattern** — The fish-native mtime gate (46ms→0.7ms) and `_nix_add_gcroot` optimization would benefit all fish+direnv users on large flakes
- [ ] **hermes-agent: add `registration_lifecycle` to `py-modules`** — Issue/PR to NousResearch/hermes-agent; removes the need for the SystemNix PYTHONPATH patch. Also `mini_swe_runner` is missing but test-only (harmless)
- [ ] **wf-recorder FFmpeg 7 compat** — file/subscribe to upstream issue; unblocks removing the SystemNix ffmpeg_6 overlay

### LarsArtmann Apps

- [ ] **cqrs-htmx/browser-history: registration-lock polish** — Remaining NON-security follow-ups: (1) frontend register form still renders and surfaces a raw 403 (needs friendly "registration closed" state); (2) no monitoring alert if browser-history user count exceeds 1 (needs a `browser_history_user_count` metric first, then a Gatus check — detects ANY future bypass); (3) document the per-process mutex limitation (multi-process deployment needs a DB-level lock or fold invariant); (4) `slog.Warn` when `NewOAuth2Service` gets nil mutex + maxUsers > 0 (silent advisory degradation). The import path gate is tracked in Priority 1. **Source:** `docs/status/2026-08-14_10-41_oauth2-gate-toctou-fix-self-critical-review.md`
- [ ] **dnsblockd: fix OTEL cardinality leak** — Drop or bucket `dns_domain`, `http_path`, `proxy_domain` labels. Each unique value creates a permanent in-memory time series
- [ ] **Monitor365: investigate DuckDB pool deadlock root cause** — Watchdog recovers the state but doesn't prevent it. All pool connections get stuck; upstream investigation needed
- [ ] **DiscordSync: fix chattr ExecStartPre upstream** — Push proper fix to upstream NixOS module
- [ ] **PMA daemon: stop committing broken flake.lock** — Auto-commit daemon runs unscoped `nix flake update` which triggers tarball regression
- [ ] **`golangci-lint-auto-configure`: fix incomplete vendoring** — Disabled in `lib/lars-packages.nix` (commented out) due to local-dep (gogenfilter) vendoring gaps. Fix upstream or remove the input
- [ ] **`hermes`**: Auto-create directory structure on first run; handle own state migration; sane defaults for `OLLAMA_API_KEY`; use PID file or socket-based single-instance locking
- [ ] **BuildFlow: pre-commit needs missing devShell binaries** — `go-licenses`, `tsc`, `npm`, `tailwindcss`, `vulnix`, `codespell`, `shellcheck`, `eslint` referenced by pre-commit but absent from devShell — forces `--no-verify` bypasses. **Source:** `docs/status/2026-08-13_04-47_buildflow-templ-fix-and-self-review.md`
- [ ] **picoclaw: bump `modernc.org/sqlite` v1.48.0 → v1.56.0** — v1.48 lacks mattn-compat shorthand support, making the `_foreign_keys=on` DSN param a no-op (FKs enforced via explicit SQL PRAGMA — redundant, not broken). **Source:** `docs/status/2026-08-14_12-53_5-item-go-nix-review-dsn-audit-logger-wiring.md`
- [ ] **Tag CreditReformBilanzampel + Kernovia DSN fixes** — Both fixes applied (mattn↔modernc DSN mismatches) but untagged; downstream pinning pending. **Source:** 12-53 report §b

### SystemNix docs debt

- [ ] **Annotate appendix-only ARCHIVED reports** — 11 archived 2026-08-1x files carry the generic "harvested" note but zero inline `done at` markers (left broken by the 2026-08-12 audit; list in `docs/status/2026-08-12_20-52_docs-health-audit-brutal-self-review.md` §b.1/§b.2). Lower priority: archived snapshots, few readers.

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
- [ ] **Re-evaluate oomd thresholds after reboot** — If 60%/30s proves insufficient (dnsblockd kill rate stays high), consider per-slice refinement: tighter limit on `system.slice` only, looser globally. Also re-check `user-1000.slice` `MemoryHigh=80G/MemoryMax=90G` headroom against the raised threshold. Watch `system_oomd_kills_total` and the Twenty worker restart count post-reboot
- [ ] **HaGeZi blocklist refresh workflow** — Lists now track the GitLab mirror `main` branch (mutable) with SRI-hash pinning — deploys fail loudly when content drifts, but hashes must be refreshed periodically to get fresh blocklists. Consider `scripts/update-dns-blocklists.sh` or a scheduled bump. **Source:** `docs/status/2026-08-13_16-11_HAGEZI-DNS-BLOCKLISTS-GITHUB-LOCK-MIRROR-FIX.md`

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
