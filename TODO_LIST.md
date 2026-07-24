# SystemNix TODO List

**Updated:** 2026-07-24 | **Last deploy:** `d243f1ee` (comprehensive fix audit — monitor365, helium, DNS, watchdog)

---

## Priority 0: Critical (Data Loss Risk)

- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged in every status report since 2026-06-25.
- [ ] **Run BTRFS scrub on `/` and `/data`** — Jul 8 NVMe report found 91,561 csum errors with identical wrong checksum. No scrub has ever been run. Need `sudo btrfs scrub start -r /data` and `sudo btrfs scrub start -r /`. Monitoring infrastructure is complete (scrub metrics every 5 min via `btrfs-health.nix`, Gatus alerts on Discord when `btrfs_scrub_error_free` drops to 0).
- [ ] **Run `smartctl -a /dev/nvme0n1`** — Cannot determine if the Lexar NQ790 is physically failing (NAND degradation) or if the 91K csum errors are purely a `discard=async` software issue. SMART data is the only way to know.

## Priority 1: High (Stability & Monitoring)

- [ ] **DiscordSync Turso 403** — 13,993+ consecutive turso sync failures: "SQL read operations are forbidden" (free plan limit). Either upgrade Turso plan or disable turso sync (switch to sqlite local-only backend).
- [ ] **monitor365 buffer backlog purge** — 597M events predate the integrity fix, may be unrecoverable. Daily 10K tenant limit blocks drain (would take ~163 years). Needs purge or limit raise.
- [ ] **Twenty CRM: fix PG role + decide Docker vs native** — `twenty-server` crash-loops with `FATAL: role "twenty" does not exist`. Data is NOT lost (1 user, 1 workspace, 66 companies across 90 tables). Needs PG role fix + decision on Docker vs native nixification.
- [ ] **Monitor365 agent circuit breaker investigation** — Agent accumulated 452K+ consecutive cloud-sync failures before watchdog restart cleared it. If server is down for extended periods, the in-memory CB opens and only a process restart clears it. Consider persisting CB state or adding a `cloud_sync_zero_accept_cycles` alert threshold.
- [ ] **go-commit v0.4.0 flake input pin** — flake.lock still shows go-commit at `ref=master, rev=3f74fd19` (pre-fix). The PMA repo has its own fix (`e8380b44`), but go-commit's `gogit.go` CLI path still compiles the old buggy code via `mkPreparedSource` override. Pin go-commit as a top-level flake input to `refs/tags/v0.4.0`.
- [ ] **MiniMax-M3 model identifier verification** — PMA auto-commit daemon was switched to `MiniMax-M3` but the model name was never verified against the MiniMax API. If invalid, every auto-commit fails silently. Verify before relying on it.

## Priority 2: Manual Steps (Blocked on Human)

- [ ] **Hermes: install SSH deploy key** — private key to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model`
- [ ] **Install `dnsblockd-CA` on Mac** — Without it, Chrome/Helium block Touch ID platform authenticator for `*.home.lan`, breaking Gatus/Forgejo SSO. Manual: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dnsblockd-ca.pem`

## Priority 3: Infrastructure

- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), now has btrbk snapshot protection but still not a named subvolume. Migration to `@data` would enable separate CoW semantics. Requires ~1h downtime.
- [ ] **Firewall deny-by-default** — all inbound allowed, services exposed to LAN. Should restrict to 80/443 + SSH + LAN-only ports.
- [ ] **Replace X11-only runtime deps with Wayland equivalents in monitor365** — `xdotool`, `xprintidle`, `scrot` are X11-only but evo-x2 runs niri (Wayland-only). Consider adding `grim`, `slurp`, `wtype`, `wlr-randr`.

## Priority 4: Code Quality

- [ ] **Split large modules** — signoz (943L), forgejo (725L) into sub-modules.
- [ ] **Convert `minecraft.nix` raw iptables** → declarative `networking.firewall.allowedTCPPorts`
- [ ] **Convert `activationScripts`** → `systemd.tmpfiles.rules` (hermes, discordsync, crush-daily, configuration, darwin)
- [ ] **Audit all `writeShellApplication` scripts for missing `runtimeInputs`** — gpu-active collector lacked `gawk`, same bug class may exist elsewhere.

## Priority 5: Desktop (from Jul 9 Helium/browser reports)

- [ ] **Test removing `--enable-zero-copy`** — if it prevents display hotplug crashes, `--disable-gpu-watchdog` may become unnecessary.
- [ ] **Remove `--enable-gpu-rasterization`** — increases GPUActive memory pressure on Strix Halo with no proven benefit.
- [ ] **Remove 9gag Post Filter** — abandoned extension ("THIS PROJECT IS DEAD").
- [ ] **file-and-image-renamer: update to upstream `b181444`** — current pin is `ca95be5` (auth fix only). Upstream `b181444` adds `ErrorTypeRateLimit`, `ErrorTypeContextTooLarge`, provider architecture redesign via `vision-review-agent` + `charm.land/fantasy`. Also: clear dead-letter queue, trash stale `~/.zai_api_key`, add `restartTriggers`.

## Priority 6: Upstream Contributions

### nixpkgs

- [ ] **`aw-watcher-utilization` poetry-core migration** — `pkgs/aw-watcher-utilization.nix:19-24`. Add `postPatch` to nixpkgs package.
- [ ] **`valkey` / `aiocache` / `timm` / `xformers` broken tests** — 4 packages with `doCheck = false`. Investigate and PR fixes.
- [ ] **`taskwarrior3` build flags** — `SYSTEM_CORROSION=on` + `ENABLE_TLS_NATIVE_ROOTS=on` should be nixpkgs defaults.
- [ ] **Kitty GC resilience patch** — After `nix-collect-garbage`, kitty's bundled binary lookup breaks.
- [ ] **KeePassXC Chromium manifests** — nixpkgs only ships Firefox-format native messaging manifests.
- [ ] **`llama-cpp` ROCm MMFMA flag** — `-DGGML_HIP_MMQ_MFMA=ON` should be a package option.

### Home Manager

- [ ] **ActivityWatch Wayland watcher: `graphical-session.target` deps** — Wayland watchers need compositor dependency.
- [ ] **Darwin user definition requirement** — HM on Darwin requires explicit `users.users.<name>.home` — tracks issue #6036.

### Third-Party

- [ ] **`jscpd` lockfile** — PR upstream to publish `pnpm-lock.yaml`.
- [ ] **XRT boost 1.87+ compat** — PR to `nix-amd-npu` to pin `boost187` for XRT build.

### LarsArtmann Apps

- [ ] **`hermes`**: Auto-create directory structure on first run; handle own state migration; sane defaults for `OLLAMA_API_KEY`; use PID file or socket-based single-instance locking instead of `--replace` flag.

## Priority 7: Long-Term

- [ ] **Provision Pi 3** for DNS failover cluster — hardware required
- [ ] **Auditd enablement** — blocked on NixOS 26.05 bug #483085
- [ ] **AppArmor enablement** — commented out in security-hardening.nix
- [ ] **Darwin Home Manager parity** — disk constrained (256GB, 90%+ full)
- [ ] **Monitor365 agent→server auth** — no auth, anyone on LAN can POST data
- [ ] **Disabled service triage** — voice-agents, minecraft: decide enable or remove

---

## Documentation

- [ ] **Add doc-freshness CI check** — script that verifies doc counts against code.
- [ ] **Create `docs/DOMAIN_LANGUAGE.md`** — does not exist yet. Would document domain terms for the Nix config ecosystem (BTRFS, DNS, SSO, etc.).

---

_Completed work is tracked in [CHANGELOG.md](./CHANGELOG.md)._
