# SystemNix TODO List

**Updated:** 2026-07-13 (docs-health audit: 17 stale claims fixed; 19 new tasks integrated from status report findings)
**Last deploy:** 2026-07-09 (`26.11.20260709` — build succeeded, 3 activation failures fixed)
**Last commit:** 2026-07-13 (`076dc778` — feat(dns): migrate from unbound to dnsblockd as sole DNS resolver)

---

## Active Tasks

### Priority 0: Critical (Block or Risk Data Loss)

- [ ] **Deploy pending changes** — DNS migration (commit `076dc778`), NVMe discard fix, monitor365/openseo fixes are in source. Build succeeded 2026-07-09 but DNS migration is newer. Needs `nix run .#deploy` + reboot to activate the unbound→dnsblockd cutover.
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
- [ ] **Verify signoz-provision at runtime** — wait-loop fix deployed but never exercised. Needs deploy + check `systemctl status signoz-provision` and confirm dashboards/alerts appear in SigNoz UI.

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
- [ ] **Fix post-deploy-check empty ports bug** — 14 false FAILs from missing port interpolation. The check references ports that don't get substituted, causing noise on every deploy.
- [ ] **Add `harden` to `immich.nix` db-backup service** — `immich.nix:105-129` database backup oneshot runs without `harden {}` or `serviceDefaults {}`. Unhardened service with DB access.
- [ ] **Fix upstream monitor365 CORS bug** — env var can't represent TOML sequences. Current workaround removes CORS entirely. Needs upstream PR to support list-valued env vars or switch to file-based config.

### Priority 2: Manual Steps (Blocked on Human)

- [ ] **Hermes: install SSH deploy key** — private key from `scripts/hermes-setup/id_ed25519` to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model` (choose a model from an active provider — GLM, MiniMax, etc.)
- [ ] **Install `dnsblockd-CA` on Mac** — Manual: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dnsblockd-ca.pem`. Without it, Chrome/Helium block Touch ID platform authenticator for `*.home.lan`, breaking Gatus/Forgejo SSO. Flagged in 2026-07-01 report.

### Priority 3: Infrastructure

- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), now has btrbk snapshot protection (daily at 23:30, 14d+4w retention) but still not a named subvolume. Migration to `@data` would enable separate CoW semantics and cleaner snapshot exclusion. Manual: create subvolume, update fstab, reboot, rsync data
- [ ] **Swap investigation** — 4.5 GiB swap used on 128 GiB RAM (improved from 7.3 GiB on Jul 1). Run `smem -t -k | tail -20` and `swapoff -a && swapon -a` if needed
- [ ] **GPUActive monitoring** — Add Prometheus/textfile collector for `/proc/meminfo`'s `GPUActive` (30.7 GiB now, was 51+ GiB after extended uptime) and `GPUReclaim` fields. Currently invisible to SigNoz/otel/Gatus. The #1 RAM consumer on Strix Halo.
- [ ] **TTM `page_pool_size` reduction** — Currently `112 GiB` (exceeds the 94 GiB visible to Linux!). TODO documented in `boot.nix` since Jul 2 — needs reboot + Ollama testing. Reducing to ~32 GiB would force faster return of freed GPU pages to the kernel.
- [ ] **Firewall deny-by-default** — all inbound allowed, services exposed to LAN. Should restrict to 80/443 + SSH + LAN-only ports.

### Priority 4: Code Quality (from Jul 9 nix anti-pattern reports)

- [ ] **Audit all `writeShellApplication` scripts for missing `runtimeInputs`** — gpu-active collector lacked `gawk` in `runtimeInputs`, causing silent failures. Same bug class may exist in other scripts.
- [ ] **Convert `minecraft.nix` raw iptables** → declarative `networking.firewall.allowedTCPPorts` — avoids fragile manual iptables manipulation.
- [ ] **Convert 6 `activationScripts`** → `systemd.tmpfiles.rules` (hermes, discordsync, crush-daily, configuration, 2 darwin) — tmpfiles is the idiomatic NixOS pattern for directory creation.
- [ ] **Split large modules** — signoz (943L), forgejo (725L) into sub-modules. (monitor365 already reduced: 716L→151L.)

### Priority 4: Desktop (from Jul 9 Helium/browser reports)

- [ ] **Runtime-verify Helium wrapper double-wrap fix** — single-layer `makeWrapper` fix never tested at runtime. Verify all flags survive (`--enable-features`, VA-API, privacy flags).
- [ ] **Verify browser extension policies actually install in Helium** — ungoogled-chromium may ignore `update_url`-based extension installation. Check `chrome://extensions` post-deploy.
- [ ] **Test removing `--enable-zero-copy`** — if it prevents display hotplug crashes entirely, `--disable-gpu-watchdog` may become unnecessary (regaining GPU hang detection). See `docs/status/2026-07-09_08-48_helium-config-overhaul-audit.md`.
- [ ] **Remove `--enable-gpu-rasterization`** — increases GPUActive memory pressure on Strix Halo with no proven benefit.
- [ ] **Configure Memory Saver via enterprise policy** — aggressive tab discarding for this memory-constrained system (chronic GPUActive pressure).
- [ ] **Remove 9gag Post Filter** — abandoned extension ("THIS PROJECT IS DEAD"). Clean removal from Chromium policies.

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

- [x] **`library-policy`** — Removed local `replace github.com/larsartmann/go-finding => /home/lars/projects/go-finding` from go.mod; switched to published v1.2.0. `go.sum` was already correct. The `mkTidyOverride` workaround was already removed from SystemNix in a prior refactor (commit `4cffb612`)
- [x] **`mr-sync`** — Already correct: no local replaces, `go.sum` matches `go mod tidy` (0 diff), no workarounds remain in SystemNix

#### LarsArtmann Apps — Missing Upstream Features

- [x] **`monitor365`**: Secrets already read from env vars (`MONITOR365__CLOUD__AUTH_TOKEN` via systemd `LoadCredential`) — the `sed` concern was stale. Fixed upstream: (1) `runtimeDeps` option is now wired into the systemd service `PATH` (was defined but never used), (2) added `displayUser` option — when set, the start script discovers `DISPLAY`/`WAYLAND_DISPLAY`/`XAUTHORITY`/`XDG_RUNTIME_DIR`/`DBUS_SESSION_BUS_ADDRESS` from the user's active login session via `/proc/<pid>/environ` (no more hardcoding)
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
- [ ] **Disabled service triage** — voice-agents, minecraft: decide enable or remove (photomap already removed)

### Priority 6: Documentation (from docs-health audit)

- [ ] **Verify README.md flake input count** — claims "56 inputs." Run `nix flake metadata --json | jq '.locks.nodes | length'` to confirm.
- [ ] **Verify CHANGELOG.md covers DNS migration** — `rg "dnsblockd\|unbound" CHANGELOG.md` — major architectural change should be logged.
- [ ] **Deep FEATURES.md service status audit** — verify every ✅ service has a Gatus endpoint and is actually deployed. Status icons were spot-checked, not systematically verified.
- [ ] **Count Caddy vhosts** — FEATURES.md claims "15 vhosts." Verify against `caddy.nix` (`rg 'protectedVHost\|reverse_proxy' modules/nixos/services/caddy.nix | wc -l`).
- [ ] **Verify DMS plugin count** — FEATURES.md says 13. Verify `pkgs/dms-plugins/` has 13 dirs (excl. `_template`) and each has valid `plugin.json` + `.qml`.
- [ ] **Add Helium to README.md desktop row** — primary browser not mentioned in "What You Get" table (lists Niri, DMS, SDDM, Ghostty, Kitty, Sway, Rofi).
- [ ] **Add doc-freshness CI check** — script that verifies doc counts (Gatus endpoints, module counts, flake inputs) against code. Prevents the static-count rot caught in this audit.
- [ ] **Create monitoring runbook** — "what to do when each Discord alert fires" (started in `docs/runbooks/monitoring-runbook.md`, needs completion).
- [ ] **Add documentation freshness section to AGENTS.md** — document the docs-health skill, file ownership model, and "update FEATURES.md after deploy" rule.

---

_Completed work is tracked in [CHANGELOG.md](./CHANGELOG.md)._
