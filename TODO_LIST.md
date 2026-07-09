# SystemNix TODO List

**Updated:** 2026-07-09 (Pareto plan created + project-meta investigation: package is actually healthy)
**Last deploy:** 2026-07-05 (`26.11.20260705.d407951`)
**Last commit:** 2026-07-08 (`4d75e83b` — NVMe discard=async status doc)

---

## Active Tasks

### Priority 0: Critical (Block or Risk Data Loss)

- [ ] **Deploy the `discard=async` → `fstrim.timer` fix** — Fix is in `hardware-configuration.nix` (TRIM via mount option removed). Running system still has `discard=async` on 8 BTRFS mounts. Root cause of the 2026-07-08 watchdog hard-reset (253ms discard latency → 17.7s BTRFS commit → freeze → 30s watchdog → reset). Every nix build risks recurrence until deployed. Requires `nix run .#deploy` + reboot.
- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged in every status report since 2026-06-25.
- [x] **Investigate `project-meta` silent build failure** — Re-investigated 2026-07-09: `project-meta` builds successfully, is present in the evaluated `environment.systemPackages` (store path `meta-0.2.0`), and provides the `meta` binary. The original TODO was based on an outdated evaluation/grep. No code change needed; will be deployed with next `nix run .#deploy`.
- [ ] **Run BTRFS scrub on `/` and `/data`** — Jul 8 NVMe report found 91,561 csum errors with identical wrong checksum (controller returning garbage under I/O pressure). No scrub has ever been run. Need `sudo btrfs scrub start -r /data` and `sudo btrfs scrub start -r /` to map all bad blocks and assess corruption extent.
- [ ] **Run `smartctl -a /dev/nvme0n1`** — Cannot determine if the Lexar NQ790 is physically failing (NAND degradation, available spare below threshold) or if the 91K csum errors are purely a `discard=async` software issue. SMART data is the only way to know. If media errors are climbing, drive replacement is needed urgently.

### Priority 0: Deploy & Verify

- [ ] **Reboot evo-x2** — verify boot time after NVMe APST fix + Caddy sops ordering fix. Target: ~35s (was 6m17s)
- [ ] **Verify Pocket ID email sending** — test login notification or email verification after SMTP wiring + sops secret added
- [x] **Reset Monitor365 failed state** — Root cause identified: upstream Rust panic (Axum 0.7 route syntax `:param` → `{param}`). Needs fix in `github:LarsArtmann/monitor365` source. Nix-side workaround not possible. *Superseded by sessions 156–158 fixes — see Completed.*
- [ ] **Verify crush-daily collection** post-deploy — `ProtectHome=false` fix written (session 156, commit `29b5c267`), needs deploy + manual trigger: `systemctl start crush-daily-collect`
- [ ] **Verify Monitor365 `/ui/` serves the WASM dashboard** post-deploy — `pkgs.monitor365-server` package fix written (session 156), needs deploy + visit `monitor.home.lan`
- [ ] **Verify DiscordSync SSO** post-deploy — vHost wired (session 156, commit `b1e45529`), needs deploy + visit `discordsync.home.lan`
- [ ] **Verify Overview vHost** post-deploy — wired in session 157 (commit `f3926729`), needs deploy + visit `overview.home.lan`
- [ ] **Verify post-deploy smoke test** actually runs — `post-deploy-check.sh` written (session 157), wired into `deploy.sh:27` via `$(dirname "$0")/post-deploy-check.sh`. When run from nix store, the nix-store path doesn't contain the script → silent failure. May need rewrite to `nix run .#post-deploy-check` (same pattern as `pre-deploy-check`).

### Priority 0: DNS Migration — dnsblockd → Primary Resolver (2026-07-02)

**Strategy:** dnsblockd becomes the DEFAULT resolver on `:53` (`dns_enabled: true`). Unbound stays as IMMEDIATE FALLBACK on `:5353` with identical config (same local zones, forwarders, ACLs, blocklists). After 24h of stable dnsblockd operation, remove unbound entirely.

**Phase 2a — Module rework (`modules/nixos/services/dns-blocker.nix`)**
- [ ] Add new NixOS options: `dnsEnable`, `dnsForwarders`, `localRecords`, `localZones`, `allowedNetworks`, `dnsIPv6Enabled`, `dnsReloadInterval`
- [ ] Generate dnsblockd YAML with `dns_enabled: true` + all DNS config fields (local records, zones, forwarders, ACLs, blocklists, IPv6 disabled)
- [ ] Move unbound to `:5353` as backup resolver (keep all current config: local-zone, forwarders, access-control, blocklists, remote-control)
- [ ] Remove `unbound_control` / `SupplementaryGroups = ["unbound"]` from dnsblockd service — dnsblockd is self-contained now
- [ ] Remove `dnsblockd process` build step — dnsblockd loads blocklists natively (`dns_blocklists` config key)
- [ ] Add assertion: `dnsEnable = true` requires `allowedNetworks` (prevent open resolver)
- [ ] Add assertion: `dnsEnable = true` requires `localZones` if `localRecords` has entries (prevent upstream leak)

**Phase 2b — Config updates**
- [ ] `platforms/nixos/system/dns-blocker-config.nix` — set `dnsEnable = true`, migrate 13 local-data → `localRecords`, set forwarders/ACLs/zones/IPv6
- [ ] `platforms/nixos/system/dns-blocker-config.nix` — move unbound to `:5353` (backup)
- [ ] `platforms/common/dns-resolver.nix` — keep `nameservers = ["127.0.0.1"]` (points at dnsblockd on :53)
- [ ] `platforms/nixos/rpi3/default.nix` — same migration (dnsblockd primary on :53, unbound backup on :5353)

**Phase 2c — Dependencies & failover**
- [ ] Update 6+ services that depend on `unbound.service` — they should depend on dnsblockd now (or a generic DNS target)
- [ ] Rewrite VRRP health check in `dns-failover.nix` — `chk_unbound` → DNS query to dnsblockd on :53
- [ ] Pin dnsblockd flake input to `v0.2.0` tag (currently `ref=master`)

**Phase 3 — Deploy & validate (24h observation period)**
- [ ] `nix flake check --no-build` + `nix eval` — syntax + eval
- [ ] Deploy to evo-x2
- [ ] `dig @127.0.0.1 forgejo.home.lan.` → 192.168.1.150 (local records)
- [ ] `dig @127.0.0.1 unknown.home.lan.` → NXDOMAIN (zone boundary)
- [ ] `dig @127.0.0.1 google.com.` → resolves (via DoT forwarder)
- [ ] Query blocked domain → returns block IP (192.168.1.200)
- [ ] Temp-allow a blocked domain → resolves to real IP (cache flushed)
- [ ] Wait for expiry → blocked again (cache flushed)
- [ ] `dig @127.0.0.1 -t AAAA google.com.` → no IPv6 upstream (dns_ipv6_enabled: false)
- [ ] Verify from LAN client: `dig @192.168.1.150 google.com.` → resolves (ACL)
- [ ] **24h observation** — monitor dnsblockd stats API, query logs, error rates. If dnsblockd breaks: switch resolv.conf back to `127.0.0.1` port 5353 (unbound backup), debug, redeploy
- [ ] After 24h stable: remove unbound entirely from all configs

**Phase 4 — Cleanup**
- [ ] Remove unbound from system packages + all config files
- [ ] Remove `:5353` backup listener
- [ ] Update AGENTS.md — change "dnsblockd embedded resolver ≠ unbound replacement (yet)" to reflect completion
- [ ] Update ROADMAP.md — mark Theme 4 DNS migration items done
- [ ] Remove unbound-related gotchas from AGENTS.md

### Priority 1: Fix Broken Services

- [ ] **Fix Twenty CRM intermittent 502s** — APPEARS RESOLVED. Server running since 06-23, responding on :3200. Monitor for recurrence.
- [x] **Audit Gatus health checks** — AUDITED 2026-06-25. Only 2 DOWN: Ollama (expected, `wantedBy = []` no autostart) and Monitor365 Server (upstream Rust panic). All 36 other endpoints pass. *Superseded by session 154 expansion: 38→41 endpoints with 31 Discord alerts and 17 response-time thresholds.*
- [ ] **Fix `post-deploy-check.sh` path in deploy.sh** — `$(dirname "$0")/post-deploy-check.sh` works from source but fails when run from nix store (script isn't in the store path). Should use `nix run .#post-deploy-check` pattern, same as `pre-deploy-check` at `deploy.sh:5`.

### Priority 1: Documentation Gaps (Discovered in Jul 8 Session)

- [x] **Document `discard=async` QLC gotcha in AGENTS.md** — Added to AGENTS.md Non-Obvious Gotchas table on 2026-07-09.
- [x] **Document `buildGoModule` env attr filtering gotcha** — Added to AGENTS.md Non-Obvious Gotchas table on 2026-07-09.
- [x] **Document `buildGoDir` silent-swallow behavior** — Added to AGENTS.md Non-Obvious Gotchas table on 2026-07-09.

### Priority 2: Manual Steps (Blocked on Human)

- [ ] **Hermes: install SSH deploy key** — private key from `scripts/hermes-setup/id_ed25519` to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model` (choose a model from an active provider — GLM, MiniMax, etc.)
- [ ] **Install `dnsblockd-CA` on Mac** — Manual: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dnsblockd-ca.pem`. Without it, Chrome/Helium block Touch ID platform authenticator for `*.home.lan`, breaking Gatus/Forgejo SSO. Flagged in 2026-07-01 report.

### Priority 3: Infrastructure

- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), no snapshot protection for Docker/Immich/AI data. Manual: create subvolume, update fstab, reboot, rsync data
- [ ] **Swap investigation** — 4.5 GiB swap used on 128 GiB RAM (improved from 7.3 GiB on Jul 1). Run `smem -t -k | tail -20` and `swapoff -a && swapon -a` if needed
- [ ] **GPUActive monitoring** — Add Prometheus/textfile collector for `/proc/meminfo`'s `GPUActive` (30.7 GiB now, was 51+ GiB after extended uptime) and `GPUReclaim` fields. Currently invisible to SigNoz/otel/Gatus. The #1 RAM consumer on Strix Halo.
- [ ] **TTM `page_pool_size` reduction** — Currently `112 GiB` (exceeds the 94 GiB visible to Linux!). TODO documented in `boot.nix` since Jul 2 — needs reboot + Ollama testing. Reducing to ~32 GiB would force faster return of freed GPU pages to the kernel.

### Priority 4: Documentation

- [x] **Archive old status reports** — moved 197 pre-June-22 files to `docs/status/archive/`. 13 current files remain (June 22-25: BTRFS crisis + DMS migration)
- [x] **Create ROADMAP.md** — created with 6 themes: Reliability, Security, Desktop, Architecture, Upstream, AI/ML + deferred ideas
- [x] **Create CHANGELOG.md** — created from git history, covers 2025-07 through 2026-06 with Keep a Changelog format
- [x] **Documentation freshness pass** — README, FEATURES, docs/README, docs/CONTRIBUTING updated: retired Waybar/Dunst/Rofi for DMS, corrected counts (modules, packages, inputs, scripts, checks, alerts), replaced all `just` references with Nix flake commands, consolidated ADR directory references, fixed `.pre-commit-config.yaml` stale `just validate` hook

### Priority 5: Upstream Contributions

#### nixpkgs

- [ ] **`aw-watcher-utilization` poetry-core migration** — `pkgs/aw-watcher-utilization.nix:19-24`. Upstream uses deprecated `poetry.masonry.api`; add `postPatch` to nixpkgs package. Removes need for custom overlay
- [ ] **`valkey` / `aiocache` / `timm` / `xformers` broken tests** — `overlays/default.nix:22-31`. 4 packages with `doCheck = false` due to test failures. Investigate and PR fixes
- [ ] **`taskwarrior3` build flags** — `platforms/common/programs/taskwarrior.nix:42-47`. `SYSTEM_CORROSION=on` + `ENABLE_TLS_NATIVE_ROOTS=on` should be nixpkgs defaults
- [ ] **Kitty GC resilience patch** — `platforms/nixos/users/home.nix:57-63`. After `nix-collect-garbage`, kitty's bundled binary lookup breaks. Should be a nixpkgs wrapper fix
- [ ] **KeePassXC Chromium manifests** — `platforms/common/programs/keepassxc.nix:9-27`. nixpkgs only ships Firefox-format native messaging manifests; Chromium manifest is trivially generated
- [ ] **`llama-cpp` ROCm MMFMA flag** — `modules/nixos/services/ai-stack.nix:16-25`. `-DGGML_HIP_MMQ_MFMA=ON` should be a package option
- [ ] **`netwatch` / `govalid` / `openaudible`** — `pkgs/*.nix`. Custom packages not in nixpkgs — candidates for new package submissions

#### Home Manager

- [ ] **ActivityWatch Wayland watcher: `graphical-session.target` deps** — `platforms/common/programs/activitywatch.nix:26-32`. HM module only sets `After=["activitywatch.service"]` — Wayland watchers need compositor
- [ ] **ActivityWatch theme setting** — `platforms/common/programs/activitywatch.nix:34-46`. No HM option for theme; workaround via curl oneshot. PR to add `programs.activitywatch.theme`
- [ ] **Darwin user definition requirement** — `platforms/darwin/default.nix:53-59`. HM on Darwin requires explicit `users.users.<name>.home` — tracks issue #6036

#### LarsArtmann Go Repos — Stale `go.sum` / `vendorHash`

All of these have `go mod tidy` workarounds or stale `vendorHash` overrides in SystemNix that vanish when the upstream repo commits a correct `go.sum` and updates its own flake `vendorHash`:

- [ ] **`library-policy`** — `overlays/shared.nix`. `mkTidyOverride` (go mod tidy + proxyVendor + overrideModAttrs). Fix: commit correct `go.sum` upstream
- [ ] **`mr-sync`** — `overlays/shared.nix`. Same `mkTidyOverride` pattern. Fix: commit correct `go.sum` upstream
- [x] **`golangci-lint-auto-configure`** — Fixed: no more override needed (upstream `go.sum` correct)
- [x] **`hierarchical-errors`** — Fixed: no more stale `vendorHash` or `go-finding` override
- [x] **`go-auto-upgrade`** — Fixed session 138: added `go-error-family.follows`, removed redundant vendorHash override from overlay (hash was identical to upstream's own)
- [x] **`go-structure-linter`** — Fixed: no more stale `vendorHash` override
- [x] **`art-dupl`** — Fixed: no more stale `vendorHash` override (on `fork` branch)
- [x] **`dnsblockd`** — Fixed: uses `dnsblockd.overlays.default`, no stale override
- [x] **`emeet-pixyd`** — Fixed: uses `emeet-pixyd.overlays.default`, no stale override

#### LarsArtmann Apps — Missing Upstream Features

- [ ] **`monitor365`**: Support reading secrets from env vars (e.g., `MONITOR365_CLOUD_AUTH_TOKEN`) instead of requiring config file mutation via `sed` at runtime. Also: bundle runtime deps natively or provide `--runtime-deps-path` flag; respect `$DISPLAY` / Wayland APIs instead of hardcoding
- [ ] **`hermes`**: Auto-create directory structure on first run (currently Nix does it); handle own state migration from old paths; sane defaults for `OLLAMA_API_KEY`/`TERMINAL_ENV`; handle deprecated config keys internally instead of requiring sed cleanup; use PID file or socket-based single-instance locking instead of `--replace` flag
- [x] **`discordsync`**: Config file support (YAML via `DISCORDSYNC_CONFIG`) + boolean `BACKFILL_ON_STARTUP` landed upstream. Reactivated in SystemNix with `apiAddr` on port 8085 (localhost). GCS attachment backup opt-in via `gcsBucket` (needs bucket name + service account JSON)

#### Third-Party Upstream Projects

- [ ] **`aw-watcher-utilization` pyproject.toml** — PR to ActivityWatch repo: migrate from `poetry` to `poetry-core` build backend (eliminates nixpkgs `postPatch` too)
- [ ] **`jscpd` lockfile** — `pkgs/jscpd.nix:20-22`. PR upstream to publish `pnpm-lock.yaml` in npm tarball or GitHub releases
- [ ] **XRT boost 1.87+ compat** — `platforms/nixos/hardware/amd-npu.nix:6-10`. PR to `nix-amd-npu` to pin `boost187` for XRT build

### Priority 6: Long-Term

- [ ] **Provision Pi 3** for DNS failover cluster — hardware required
- [ ] **Auditd enablement** — blocked on NixOS 26.05 bug #483085
- [ ] **AppArmor enablement** — commented out in security-hardening.nix
- [ ] **Darwin Home Manager parity** — disk constrained (256GB, 90%+ full)
- [ ] **Monitor365 agent→server auth** — no auth, anyone on LAN can POST data
- [ ] **Disabled service triage** — voice-agents, minecraft, photomap: decide enable or remove
- [ ] **Split large modules** — monitor365 (716L), signoz (705L), forgejo (583L)

---

## Completed (session 122)

- [x] Configure secondary LLM provider for hermes (Nix wiring done, manual sops step remaining)
- [x] Hermes git remote access (SSH key generated, manual install remaining)
- [x] nix-colors integration (164 colors migrated)
- [x] Create `just status` command
- [x] Create post-deploy verification script (`scripts/verify-deployment.sh`) + `just verify`
- [x] Per-threshold SigNoz channel routing
- [x] Flake inputs audit (45 inputs, all used)
- [x] Darwin home.nix parity (terminal, editor, theme, xdg)

## Completed (session 128)

- [x] sops atomic failure fix — discordsync owner blocked ALL secrets, wrapped with optionalAttrs
- [x] SigNoz decoupled from boot — custom `signoz.target`, ~2m faster boot
- [x] SigNoz JWT auto-generation — wrapper script on first start
- [x] Crash-loop protection — `startLimitBurst = 5` on 9 services
- [x] notify-failure %i fix — specifier passed as script argument
- [x] plugdev group — eliminated 36 udev warnings
- [x] Deprecated amdgpu.gttsize removed
- [x] ClickHouse ports centralized in lib/ports.nix
- [x] Overview package build — mkPreparedSource with 9 private Go repos
- [x] Discordsync enabled + bot token regenerated

## Completed (session 129)

- [x] Pocket ID provision: header casing + URL encoding + race conditions — fully working
- [x] QDirStat — Qt disk usage analyzer added
- [x] NVMe APST boot delay fix — `nvme_core.default_ps_max_latency_us=0` kernel param

## Completed (session 130)

- [x] Homepage Dashboard YAML rewrite — `mkGroup`/`mkService` helpers, ALLOWED_HOSTS, cache dir
- [x] Manifest behind auth — moved to `protectedVHost`
- [x] Hermes icon fix — `ai.png` → `hermes-icon.png`

## Completed (session 131a)

- [x] Fix Caddy boot ordering — `wants = ["sops-nix.service"]` + `after` prevents 14-hour outage recurrence
- [x] Fix DNS A records for 5 subdomains — status, seo, daily, logs, monitor added to both primary + RPi3 DNS
- [x] Guard ALL sops secrets with optionalAttrs — hermes, crush-daily, openseo, monitor365, signoz, voice-agents secrets + templates now wrapped in `lib.optionalAttrs config.services.X.enable`
- [x] Root disk cleanup — `nix-collect-garbage -d` run by user

## Completed (session 131b)

- [x] Resend SMTP wiring — `smtp.resend.com:465`, `noreply@cloud.larsartmann.com`, API key added to sops
- [x] Pocket ID OTel fix — `OTEL_METRICS_EXPORTER=prometheus` (removed unnecessary traces/logs exporters)
- [x] AGENTS.md sops guide corrected — ssh-to-age `-private-key`, `SOPS_AGE_KEY` in RAM, one-liner pattern

## Completed (session 131c)

- [x] Sops secret management skill — project-local skill at `.crush/skills/sops-secret-management/SKILL.md` with gitignore whitelist
- [x] ssh-to-age added to system packages — was not installed, needed `nix run` every time
- [x] Fix Monitor365 server DB path — added `--config` flag to ExecStart (wasn't reading config) + fixed `sqlite://` to `sqlite:///` (3 slashes = absolute path)
- [x] Fix aw-watcher-window-wayland startup race — added `After=graphical-session.target` dependency

## Completed (session 138)

- [x] Flake follows consolidation — Added missing `follows` for 7 repos: crush-daily, discordsync, overview, project-meta, projects-management-automation, mr-sync, branching-flow. Eliminated 38 duplicate lock nodes (182→144)
- [x] go-auto-upgrade fix — Added `go-error-family.follows`, removed redundant vendorHash override from `overlays/shared.nix`

## Completed (session 153)

- [x] Rofi → DMS migration — All 5 niri rofi keybindings rewired to DMS IPC (spotlight toggle, clipboard toggle, keybinds toggle niri, spotlight toggleQuery ":e" for emoji, spotlight toggleQuery "=" for calc). Root cause: rofi leaked 7 GB → global OOM killed niri + 8 other processes. Rofi config kept for Sway backup WM only.
- [x] Community DMS plugins added — dms-emoji-launcher (trigger `:e`) and DankCalculator (trigger `=`) via `fetchFromGitHub` in quickshell.nix
- [x] cliphist service retired — `wl-paste --watch cliphist store` removed; DMS owns clipboard history exclusively. CLI tool kept in base.nix for manual use.
- [x] DMS MemoryMax=4G — defense-in-depth against future launcher leaks
- [x] AGENTS.md + FEATURES.md updated — rofi migration, cliphist retirement, plugin inventory documented

## Completed (session 154 — 2026-07-01 to 2026-07-02)

- [x] Helium display-hotplug crash fix — `--disable-gpu-watchdog` Chromium flag. Root cause: GPU watchdog kills process during slow DCN 3.5.1 surface recreation under GPUActive pressure.
- [x] `/tmp` tmpfs capped at 16 GiB — `boot.tmp.useTmpfs = false` + explicit systemd `tmp.mount` unit with `size=16G` + `nofail`. Previously defaulted to 50% of RAM (~47 GiB). go-build caches filled 16+ GiB in 21h.
- [x] Unbound cache bounds — `key-cache-size = "16m"`, `neg-cache-size = "16m"`, `infra-cache-numhost = 10000`. Was 1.5 GiB RSS for 192 MiB of explicit caches (DNSSEC key cache and NXDOMAIN cache were unbounded).
- [x] MGLRU thrash protection — `min_ttl_ms=1000` via sysfs service `mglru-thrash-protection.service`. Protects youngest page generation from eviction for 1s under pressure.
- [x] OOM tuning — `user-1000.slice` MemoryHigh=56G/MemoryMax=64G, oomd 50%/20s.
- [x] BTRFS metadata ENOSPC prevention — `btrfs-health.nix` gates `nix-gc` when device-unallocated < 10%. Gatus alerts on metadata ratio. DMS widget shows device-unallocated %. btrbk staggered to 23:00 (before GC at 00:00).
- [x] Network interface boot race fix — `dnsblockd-attach-ip.service` (CAP_NET_ADMIN oneshot, ordered after `sys-subsystem-net-devices-eno1.device`). dns-blocker no longer uses `networking.localCommands` with `|| true`.
- [x] `switch-to-configuration` exit 4 fix — `deploy.sh:10-11` now runs `systemctl reset-failed` (system + user) before `nh os switch`. Without this, any service that crash-looped at boot blocks ALL deploys until manually reset.
- [x] Pre-deploy validation — `nix run .#pre-deploy-check` catches boot-breakers (ext4 `discard=async`, missing `nofail`). Wired into `deploy.sh:5`.
- [x] RAM forensic audit — Discovered GPUActive (GTT buffer objects) consume 30-55% of visible RAM on Strix Halo. `/proc/meminfo` has a dedicated counter invisible to `free`/`htop`/SigNoz. Documented in AGENTS.md.
- [x] Niri fork for session management — Switched to `LarsArtmann/niri` fork (commit `f1f23079`) for improved session save/restore.
- [x] SSH socket cleanup timer — `ssh-socket-cleanup` systemd user timer (every 5 min) probes sockets via AF_UNIX `connect()` and unlinks dead ones. Fixes stale socket warnings from `ControlMaster auto`.
- [x] Herdr terminal agent multiplexer — Deployed across platforms (commit `7514ba8f`).
- [x] dnsblockd v0.2.0 tag — Tagged `ad14663` in `/home/lars/projects/dnsblockd`. Full embedded recursive resolver (sdns, DNSSEC, DoT, DoH, caching, local zones, ACLs, upstream forwarding). Ready for SystemNix migration (Phase 2a-4 in this file).

## Completed (session 155 — 2026-07-03)

- [x] Gatus monitoring expansion (commit `148beb9c`, `3c5eb141`, `25a67a9d`, `3ae3d177`) — 38→41 endpoints, 31 with Discord alerts, 17 with response-time thresholds. Added Redis TCP check, Mullvad DoT upstream check, external HTTPS connectivity check, Overview service check.
- [x] Caddy security hardening (commit `a5e688cf`, `15a8869d`) — Security headers (`commonConfig`: HSTS, nosniff, frame-options, referrer-policy, permissions-policy), compression (`encode zstd gzip`), HTTP→HTTPS redirect, structured access logging (JSON to `/var/log/caddy/access.log`, 100MB rotation), TLS 1.2+ enforcement, strict SNI host.
- [x] Overview CSP/CDN migration — Cross-repo fix: `templ-components` switched CDN from unpkg.com → cdn.jsdelivr.net (commits `176ce37`, `4cd9529`). Overview updated CSP `connect-src` (commits `0e70781`, `037c5ac`, `0b0ed2a`). cqrs-htmx v3→v4 migration with `.vendor-local` exclude.

## Completed (session 156 — 2026-07-04)

- [x] DiscordSync dashboard exposed (commit `b1e45529`) — `protectedVHost "discordsync" ports.discordsync-api` + DNS A record + Homepage tile. Layer-2 SSO via Pocket ID.
- [x] Crush-daily data collection repaired (commit `29b5c267`) — `ProtectHome=true` (from `harden{}`) made `/home` invisible. Fixed with `ProtectHome=false`, `ReadOnlyPaths` scoped to `.crush/`, `SupplementaryGroups="users"`, activation script `chmod g+rx` on three 700-permission dirs.
- [x] Monitor365 UI package fix (commit `29b5c267`) — `cfg.server.package` was defaulting to `pkgs.monitor365` (agent CLI, no UI). Changed to `pkgs.monitor365-server` (symlinkJoin with WASM UI + `UI_DIST_PATH` wrapper).
- [x] Renamer health dashboard wired (commit `f892e256`) — Caddy vHost + Gatus + Pocket ID for `file-and-image-renamer`.
- [x] File & Image Renamer health dashboard — Wired with Caddy vHost + Gatus + Pocket ID. Renamer domain added to `dns-blocklists` allowlist (commit `8a7ae088`).

## Completed (session 157 — 2026-07-04)

- [x] Preventive infrastructure hardening sprint (commit `f3926729`) — Three-layer defense against silent failures:
  1. ProtectHome pre-commit hook (`protect-home-audit` in `.pre-commit-config.yaml`) — flags `harden{} + /home` patterns at commit time. Catches the crush-daily class of bug.
  2. Functional Gatus body assertions — Monitor365 `/ui/` checks for `<html` body, Homepage + Overview body checks with Discord alerts. Catches "alive but broken" patterns that status-only checks miss.
  3. Post-deploy smoke test (`scripts/post-deploy-check.sh`, wired into `deploy.sh:27`) — verifies vHosts return expected HTML, APIs return expected JSON, specific bug patterns. Available as `nix run .#post-deploy-check`.
- [x] ProtectHome audit — Scanned all 39 service modules. Result: clean — crush-daily and hermes both already override `ProtectHome = false`.
- [x] Caddy body size limit — Global `request_body { max_size 10GB }` in `commonConfig` — prevents memory exhaustion from unbounded POSTs while allowing large Immich video uploads.
- [x] Photomap removed — Module, port (8051), Docker image reference, Homepage tile, config stub all cleaned up. Decision from ROADMAP.md Theme 3.
- [x] Monitoring runbook — `docs/runbooks/monitoring-runbook.md` documents recovery procedures for every Discord alert (OOM, Docker containerd corruption, SigNoz stale migration lock, BTRFS ENOSPC).
- [x] AGENTS.md gotchas — 4 new entries: `harden{} + /home` silent failure pattern, package alias traps (monitor365), post-deploy smoke test, functional Gatus checks convention.
- [x] Overview exposed — `protectedVHost "overview" ports.overview` + DNS A record + Homepage tile. Last unexposed web UI.
- [x] DNS local config extracted — `f28167e1` refactored local subdomain configuration into `dns-local.nix` module.

## Completed (session 158 — 2026-07-08)

- [x] Diagnosed NVMe discard=async watchdog hard-reset — 2026-07-08 06:57 hard crash (73-second gap in logs, tree-log replay, watchdog reset). Root cause: `discard=async` causing 253ms discard latency on QLC NAND → 17.7s BTRFS commit under build load → system freeze → 30s watchdog timeout → hard reset. Fix applied to source (`hardware-configuration.nix`: TRIM via mount option removed). NOT YET DEPLOYED.
- [x] Diagnosed buildflow silent empty binary — `whereis buildflow` returned empty. Root cause: layered chain — BuildFlow uses experimental `encoding/json/v2` + `encoding/json/jsontext` (behind `goexperiment.jsonv2` in Go 1.26.4), and `buildGoModule`'s `env` attr is silently filtered to known Go vars. Build "succeeded" but produced zero binaries (`buildGoDir` swallows "build constraints exclude all Go files" as non-fatal). Fixed: moved `GOEXPERIMENT=jsonv2` from `env` to `export` in `preBuild`. Deployed (commit `0c3db8a` in BuildFlow, `8603e730` in SystemNix flake.lock).
- [x] Documented buildflow GOEXPERIMENT fix and NVMe crash — Two status reports written: `2026-07-08_08-45_buildflow-goexperiment-jsonv2-fix.md` and `2026-07-08_08-38_NVME-DISCARD-ASYNC-IO-CHOKE-INVESTIGATION.md`. Committed as `7b7b20f3` and `4d75e83b`.
