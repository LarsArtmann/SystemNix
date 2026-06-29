# SystemNix TODO List

**Updated:** 2026-06-25 (session 152)

---

## Active Tasks

### Priority 0: Deploy & Verify

- [ ] **Reboot evo-x2** — verify boot time after NVMe APST fix + Caddy sops ordering fix. Target: ~35s (was 6m17s)
- [ ] **Verify Pocket ID email sending** — test login notification or email verification after SMTP wiring + sops secret added
- [x] **Reset Monitor365 failed state** — Root cause identified: upstream Rust panic (Axum 0.7 route syntax `:param` → `{param}`). Needs fix in `github:LarsArtmann/monitor365` source. Nix-side workaround not possible.

### Priority 1: Fix Broken Services

- [ ] **Fix Twenty CRM intermittent 502s** — APPEARS RESOLVED. Server running since 06-23, responding on :3200. Monitor for recurrence.
- [x] **Audit Gatus health checks** — AUDITED 2026-06-25. Only 2 DOWN: Ollama (expected, `wantedBy = []` no autostart) and Monitor365 Server (upstream Rust panic). All 36 other endpoints pass.

### Priority 2: Manual Steps (Blocked on Human)

- [ ] **Hermes: install SSH deploy key** — private key from `scripts/hermes-setup/id_ed25519` to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model` (choose a model from an active provider — GLM, MiniMax, etc.)

### Priority 3: Infrastructure

- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), no snapshot protection for Docker/Immich/AI data. Manual: create subvolume, update fstab, reboot, rsync data
- [ ] **Swap investigation** — 8 GiB swap used on 128 GiB RAM. Run `smem -t -k | tail -20` and `swapoff -a && swapon -a`

### Priority 4: Documentation

- [x] **Archive old status reports** — moved 197 pre-June-22 files to `docs/status/archive/`. 13 current files remain (June 22-25: BTRFS crisis + DMS migration)
- [x] **Create ROADMAP.md** — created with 6 themes: Reliability, Security, Desktop, Architecture, Upstream, AI/ML + deferred ideas
- [x] **Create CHANGELOG.md** — created from git history, covers 2025-07 through 2026-06 with Keep a Changelog format

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

## Completed (session 138)

- [x] **Flake follows consolidation** — Added missing `follows` for 7 repos: crush-daily, discordsync, overview, project-meta, projects-management-automation, mr-sync, branching-flow. Eliminated 38 duplicate lock nodes (182→144)
- [x] **go-auto-upgrade fix** — Added `go-error-family.follows`, removed redundant vendorHash override from `overlays/shared.nix`

## Completed (session 131c)

- [x] **Sops secret management skill** — project-local skill at `.crush/skills/sops-secret-management/SKILL.md` with gitignore whitelist
- [x] **ssh-to-age added to system packages** — was not installed, needed `nix run` every time
- [x] **Fix Monitor365 server DB path** — added `--config` flag to ExecStart (wasn't reading config) + fixed `sqlite://` to `sqlite:///` (3 slashes = absolute path)
- [x] **Fix aw-watcher-window-wayland startup race** — added `After=graphical-session.target` dependency

## Completed (session 131b)

- [x] **Resend SMTP wiring** — `smtp.resend.com:465`, `noreply@cloud.larsartmann.com`, API key added to sops
- [x] **Pocket ID OTel fix** — `OTEL_METRICS_EXPORTER=prometheus` (removed unnecessary traces/logs exporters)
- [x] **AGENTS.md sops guide corrected** — ssh-to-age `-private-key`, `SOPS_AGE_KEY` in RAM, one-liner pattern

## Completed (session 131a)

- [x] **Fix Caddy boot ordering** — `wants = ["sops-nix.service"]` + `after` prevents 14-hour outage recurrence
- [x] **Fix DNS A records for 5 subdomains** — status, seo, daily, logs, monitor added to both primary + RPi3 DNS
- [x] **Guard ALL sops secrets with optionalAttrs** — hermes, crush-daily, openseo, monitor365, signoz, voice-agents secrets + templates now wrapped in `lib.optionalAttrs config.services.X.enable`
- [x] **Root disk cleanup** — `nix-collect-garbage -d` run by user

## Completed (session 130)

- [x] **Homepage Dashboard YAML rewrite** — `mkGroup`/`mkService` helpers, ALLOWED_HOSTS, cache dir
- [x] **Manifest behind auth** — moved to `protectedVHost`
- [x] **Hermes icon fix** — `ai.png` → `hermes-icon.png`

## Completed (session 129)

- [x] **Pocket ID provision: header casing + URL encoding + race conditions** — fully working
- [x] **QDirStat** — Qt disk usage analyzer added
- [x] **NVMe APST boot delay fix** — `nvme_core.default_ps_max_latency_us=0` kernel param

## Completed (session 128)

- [x] **sops atomic failure fix** — discordsync owner blocked ALL secrets, wrapped with optionalAttrs
- [x] **SigNoz decoupled from boot** — custom `signoz.target`, ~2m faster boot
- [x] **SigNoz JWT auto-generation** — wrapper script on first start
- [x] **Crash-loop protection** — `startLimitBurst = 5` on 9 services
- [x] **notify-failure %i fix** — specifier passed as script argument
- [x] **plugdev group** — eliminated 36 udev warnings
- [x] **Deprecated amdgpu.gttsize removed**
- [x] **ClickHouse ports centralized** in lib/ports.nix
- [x] **Overview package build** — mkPreparedSource with 9 private Go repos
- [x] **Discordsync enabled** + bot token regenerated

## Completed (session 122)

- [x] Configure secondary LLM provider for hermes (Nix wiring done, manual sops step remaining)
- [x] Hermes git remote access (SSH key generated, manual install remaining)
- [x] nix-colors integration (164 colors migrated)
- [x] Create `just status` command
- [x] Create post-deploy verification script (`scripts/verify-deployment.sh`) + `just verify`
- [x] Per-threshold SigNoz channel routing
- [x] Flake inputs audit (45 inputs, all used)
- [x] Darwin home.nix parity (terminal, editor, theme, xdg)
