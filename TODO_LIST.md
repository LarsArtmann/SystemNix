# SystemNix TODO List

**Updated:** 2026-07-11 (BTRFS Pareto plan implementation: scrub metrics, compsize metrics, /data snapshots, Gatus alerting)
**Last deploy:** 2026-07-05 (`26.11.20260705.d407951`)
**Last commit:** 2026-07-08 (`4d75e83b` — NVMe discard=async status doc)

---

## Active Tasks

### Priority 0: Critical (Block or Risk Data Loss)

- [ ] **Deploy the `discard=async` → `fstrim.timer` fix** — Fix is in `hardware-configuration.nix` (TRIM via mount option removed). Running system still has `discard=async` on 8 BTRFS mounts. Root cause of the 2026-07-08 watchdog hard-reset (253ms discard latency → 17.7s BTRFS commit → freeze → 30s watchdog → reset). Every nix build risks recurrence until deployed. Requires `nix run .#deploy` + reboot.
- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged in every status report since 2026-06-25.
- [ ] **Run BTRFS scrub on `/` and `/data`** — Jul 8 NVMe report found 91,561 csum errors with identical wrong checksum (controller returning garbage under I/O pressure). No scrub has ever been run. Need `sudo btrfs scrub start -r /data` and `sudo btrfs scrub start -r /` to map all bad blocks and assess corruption extent. **Monitoring infrastructure is complete:** scrub metrics collected every 5 min (`btrfs_scrub_errors_total`, `btrfs_scrub_status`, `btrfs_scrub_error_free`), Gatus alerts on Discord when errors found.
- [ ] **Run `smartctl -a /dev/nvme0n1`** — Cannot determine if the Lexar NQ790 is physically failing (NAND degradation, available spare below threshold) or if the 91K csum errors are purely a `discard=async` software issue. SMART data is the only way to know. If media errors are climbing, drive replacement is needed urgently.

### Priority 0: Deploy & Verify

- [ ] **Reboot evo-x2** — verify boot time after NVMe APST fix + Caddy sops ordering fix. Target: ~35s (was 6m17s)
- [ ] **Verify Pocket ID email sending** — test login notification or email verification after SMTP wiring + sops secret added
- [ ] **Verify crush-daily collection** post-deploy — `ProtectHome=false` fix written (session 156, commit `29b5c267`), needs deploy + manual trigger: `systemctl start crush-daily-collect`
- [ ] **Verify Monitor365 `/ui/` serves the WASM dashboard** post-deploy — `pkgs.monitor365-server` package fix written (session 156), needs deploy + visit `monitor.home.lan`
- [ ] **Verify DiscordSync SSO** post-deploy — vHost wired (session 156, commit `b1e45529`), needs deploy + visit `discordsync.home.lan`
- [ ] **Verify Overview vHost** post-deploy — wired in session 157 (commit `f3926729`), needs deploy + visit `overview.home.lan`
- [ ] **Verify post-deploy smoke test runs after deploy** — `deploy.sh:27` uses `nix run .#post-deploy-check`. Needs deploy + verification that smoke checks actually execute.

### Priority 0: DNS Migration — ✅ CODE COMPLETE (2026-07-13, pending deploy)

**Status:** All code changes done. Unbound removed entirely — dnsblockd is the sole DNS resolver on :53 with embedded sdns. Rollback: `git switch` to pre-migration commit + `nix run .#deploy`.

**Completed:**
- [x] Added NixOS options: `dnsForwarders`, `localRecords`, `localZones`, `allowedNetworks`, `dnsIPv6Enabled`, `dnsReloadInterval` to `dns-blocker.nix`
- [x] Generate dnsblockd YAML with `dns_enabled: true` + all DNS config fields
- [x] Removed all unbound config (services.unbound, systemd.services.unbound, unboundIncludeFile)
- [x] Removed `unbound_control` / `SupplementaryGroups = ["unbound"]` from dnsblockd service
- [x] Assertions: `allowedNetworks` required (open resolver prevention), `localZones` required when `localRecords` set
- [x] `dns-blocker-config.nix` — migrated local-data → `localRecords`, set zones/ACLs/IPv6=false
- [x] `dns-resolver.nix` — removed unbound config, kept nameservers/resolv.conf
- [x] `rpi3/default.nix` — removed unbound, enabled dns-blocker with DNS resolver options
- [x] Updated 5 services: oauth2-proxy, hermes, discordsync, docker (lib/docker.nix), scheduled-tasks → depend on `dnsblockd.service`
- [x] VRRP health check renamed `chk_unbound` → `chk_dns` in `dns-failover.nix`
- [x] dnsblockd flake input already pinned to `v0.2.0` tag
- [x] Updated AGENTS.md, ROADMAP.md, TODO_LIST.md
- [x] Removed stale unbound test from `tests/default.nix`

**Pending deploy & validate:**
- [ ] `nix flake check --no-build` + `nix eval`
- [ ] Deploy to evo-x2
- [ ] `dig @127.0.0.1 forgejo.home.lan.` → server IP (local records)
- [ ] `dig @127.0.0.1 unknown.home.lan.` → NXDOMAIN (zone boundary)
- [ ] `dig @127.0.0.1 google.com.` → resolves (root recursion)
- [ ] Query blocked domain → returns block IP
- [ ] Verify from LAN client: `dig @<serverIP> google.com.` → resolves (ACL)

### Priority 1: Fix Broken Services

- [ ] **Twenty CRM: fix PG role + decide Docker vs native** — `twenty-server` crash-loops with `FATAL: role "twenty" does not exist` because the PG container only has a `postgres` role. Data is NOT lost: 1 user, 1 workspace, 66 companies, 144 contacts across 90 tables (schemas `core` + `workspace_e9cj8i2yyuv46o8h43y8adli`, 17 MB total in `twenty_db-data` volume). The `twenty-server-local-data` volume (1.1 MB) has 2 workspace dirs from May 3 with generated SDK zips and custom function stubs. Needs: (1) fix the PG role mismatch so the app can connect, (2) decide whether to keep Twenty on Docker (it's 4 containers ~1.5 GB RAM for an idle CRM) or nixify it natively like SigNoz/Forgejo/Homepage. Twenty is the single biggest Docker consumer and a major contributor to BTRFS overlay2 metadata fragmentation.
- [ ] **Fix Twenty CRM intermittent 502s** — APPEARS RESOLVED. Server running since 06-23, responding on :3200. Monitor for recurrence.

### Priority 2: Manual Steps (Blocked on Human)

- [ ] **Hermes: install SSH deploy key** — private key from `scripts/hermes-setup/id_ed25519` to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model` (choose a model from an active provider — GLM, MiniMax, etc.)
- [ ] **Install `dnsblockd-CA` on Mac** — Manual: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dnsblockd-ca.pem`. Without it, Chrome/Helium block Touch ID platform authenticator for `*.home.lan`, breaking Gatus/Forgejo SSO. Flagged in 2026-07-01 report.

### Priority 3: Infrastructure

- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), now has btrbk snapshot protection (daily at 23:30, 14d+4w retention) but still not a named subvolume. Migration to `@data` would enable separate CoW semantics and cleaner snapshot exclusion. Manual: create subvolume, update fstab, reboot, rsync data
- [ ] **Swap investigation** — 4.5 GiB swap used on 128 GiB RAM (improved from 7.3 GiB on Jul 1). Run `smem -t -k | tail -20` and `swapoff -a && swapon -a` if needed
- [ ] **GPUActive monitoring** — Add Prometheus/textfile collector for `/proc/meminfo`'s `GPUActive` (30.7 GiB now, was 51+ GiB after extended uptime) and `GPUReclaim` fields. Currently invisible to SigNoz/otel/Gatus. The #1 RAM consumer on Strix Halo.
- [ ] **TTM `page_pool_size` reduction** — Currently `112 GiB` (exceeds the 94 GiB visible to Linux!). TODO documented in `boot.nix` since Jul 2 — needs reboot + Ollama testing. Reducing to ~32 GiB would force faster return of freed GPU pages to the kernel.

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

#### LarsArtmann Apps — Missing Upstream Features

- [ ] **`monitor365`**: Support reading secrets from env vars (e.g., `MONITOR365_CLOUD_AUTH_TOKEN`) instead of requiring config file mutation via `sed` at runtime. Also: bundle runtime deps natively or provide `--runtime-deps-path` flag; respect `$DISPLAY` / Wayland APIs instead of hardcoding
- [ ] **`hermes`**: Auto-create directory structure on first run (currently Nix does it); handle own state migration from old paths; sane defaults for `OLLAMA_API_KEY`/`TERMINAL_ENV`; handle deprecated config keys internally instead of requiring sed cleanup; use PID file or socket-based single-instance locking instead of `--replace` flag

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

_Completed work is tracked in [CHANGELOG.md](./CHANGELOG.md)._
