# SystemNix TODO List

**Updated:** 2026-08-03 | **Last sessions:** NVMe corruption investigation (root cause: 58 unsafe shutdowns, not async discard), nixpkgs update (Jan→Aug 2026, Pocket ID 2.12.0), shell optimization (direnv caching 46ms→0.7ms), Attic binary cache, Desktop Renaissance v3 (swww + GLSL shaders)

---

## Priority 0: Critical (Data Loss Risk)

- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. The Aug 3 corruption event (13 files lost) proves this is not theoretical. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged in every status report since 2026-06-25. **Manual action required:** set up Hetzner StorageBox + BorgBackup
- [ ] **Run foreground BTRFS scrub on `/`** — `/dev/nvme0n1p6` (`/`) has NEVER been scrubbed. Same physical NVMe as `/data` which had 13 corrupted files. SMART says drive is healthy (11% wear, 0 media errors), but root FS corruption would be catastrophic. **Manual command:** `sudo btrfs scrub start -B /`
- [ ] **Investigate 58 unsafe shutdowns** — 46% of 126 power cycles were unsafe (WDT resets, OOM cascades, power events). This is the root cause of the data corruption, not async discard. Each unsafe shutdown risks incomplete BTRFS commits. Consider UPS, WDT timeout tuning, or oomd threshold adjustment

## Priority 1: High (Deploy Pending)

- [ ] **Deploy pending changes** — Multiple sessions' work committed but not yet deployed: NVMe corruption fixes (weekly scrub `9083c126`, scrub monitoring fix, dangerous config reverts `c2615d09`), Attic binary cache (bootstrap service + storage dir + public key `2c344e64`), SearXNG TTFB optimization (rate limiter + Redis removal `27aed87b`), Desktop Renaissance v3 (swww + GLSL shaders + transparency), shell optimization (direnv per-command caching `64d53448`). Run `nix run .#deploy` then `nix run .#post-deploy-check`
- [ ] **Twenty CRM: fix PG role** — `twenty-server` crash-loops with `FATAL: role "twenty" does not exist`. Data is NOT lost (1 user, 1 workspace, 66 companies across 90 tables). Needs PG role fix + decision on Docker vs native nixification
- [ ] **Create Attic cache + CI token** — Attic module deployed but cache not yet created. Steps: `attic cache create monitor365`, `atticadm make-token --sub ci --validity 1y --push monitor365 --pull monitor365`, configure Forgejo runner. See `docs/services/nix-binary-cache-setup.md`
- [ ] **Enable niri blur** — Desktop Renaissance v3 added terminal transparency (88%/90%) but niri's blur option is NOT configured (niri HM module lacks `blur {}` option). Transparent terminals without blur are hard to read. Workaround: raw KDL config, wait for niri-flake, or drop transparency

## Priority 2: Manual Steps (Blocked on Human)

- [ ] **Hermes: install SSH deploy key** — private key to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model`
- [ ] **Install `dnsblockd-CA` on Mac** — Without it, Chrome/Helium block Touch ID platform authenticator for `*.home.lan`, breaking Gatus/Forgejo SSO. Manual: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dnsblockd-ca.pem`
- [ ] **Turso plan decision** — DiscordSync switched to sqlite backend (eliminates Turso 403). Cloud sync via Turso requires upgrading the plan or waiting for quota reset. Decide: keep sqlite-only, or re-enable turso-sync after plan upgrade
- [ ] **Reduce `/data` fill below 80%** — Currently 92% full (700 GiB / 758 GiB). High fill on QLC NAND increases write amplification and failure risk. Candidates: clean Docker images (`docker system prune`), re-download corrupted AI models only when needed, audit `/data/activitywatch` (12G), Steam (5.9G), DuckDB (13G)

## Priority 3: Infrastructure

- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), has btrbk snapshot protection but not a named subvolume. Migration to `@data` would enable separate CoW semantics. Requires ~1h downtime
- [ ] **`/data` compression decision** — `compress=zstd:3` on `/data` is under review (corruption report recommended removal). Needs user decision: keep, lower to `zstd:1`, or remove. Blocked by reboot requirement
- [ ] **Remove Pocket ID WAL band-aid** — Pocket ID 2.12.0 (deployed via nixpkgs update `06ed9234`) includes upstream francis fixes. The WAL-clearing ExecStartPre, `ACTORS_HOST=127.0.0.1`, and `MemoryMax=1G` overrides may no longer be needed. Remove one at a time, verify SQLITE_BUSY doesn't recur
- [ ] **SearXNG streaming exploration** — User wants streaming results (progressive rendering), not the current "wait for all engines" model. Options: SearXNG fork with SSE endpoint, Go/Rust streaming proxy, or Caddy flush_buffers. Config tuning (rate limiter removal) is committed but the streaming work is deferred

## Priority 4: Code Quality

- [ ] **Wire `doc-freshness-check.sh` into pre-commit or CI** — Script exists (`scripts/doc-freshness-check.sh`) but is not automated. Validates doc counts against code
- [ ] **Add regression tests for past bugs** — VM test infrastructure exists (`tests/`). Add tests for: DynamicUser + sops owner mismatch, deploy.sh start-limit reset, `writeShellApplication` pipefail + SIGPIPE patterns
- [ ] **Consolidate systemd blocks for statix** — `statix.toml` disables `repeated_keys` (false positive for NixOS modules). Alternative: consolidate service+timer pairs into single blocks to eliminate the warning entirely
- [ ] **PMA `GenerateMessage` handler leak** — Same `defer Close()` pattern as the fixed `Commit()` site, but `GenerateMessage` was missed. Upstream fix needed in PMA repo

## Priority 5: Desktop

- [ ] **Test removing `--enable-zero-copy`** — if it prevents display hotplug crashes, `--disable-gpu-watchdog` may become unnecessary
- [ ] **Verify all extension IDs are live on Chrome Web Store** — Dead IDs cause silent download failures now that background networking is enabled
- [ ] **Visual verify Desktop Renaissance v3** — GLSL fire/circle shaders, terminal transparency, swww wallpaper daemon — all committed but ZERO runtime testing. Check `journalctl --user -u quickshell` for shader compile errors
- [ ] **Backup DMS `settings.json` before deploy** — DMS may overwrite user-owned `settings.json` on rebuild (split-brain risk). Backup before deploying Desktop Renaissance v3

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

- [ ] **`hermes`**: Auto-create directory structure on first run; handle own state migration; sane defaults for `OLLAMA_API_KEY`; use PID file or socket-based single-instance locking instead of `--replace` flag

## Priority 7: Long-Term

- [ ] **Provision Pi 3** for DNS failover cluster — hardware required
- [ ] **Auditd enablement** — blocked on NixOS 26.05 bug #483085
- [ ] **AppArmor enablement** — commented out in security-hardening.nix
- [ ] **Darwin Home Manager parity** — disk constrained (256GB, 90%+ full)
- [ ] **Monitor365 agent to server auth** — no auth, anyone on LAN can POST data
- [ ] **Disabled service triage** — voice-agents, minecraft: decide enable or remove
- [ ] **Monitor365 event-store compaction** — 597M backlog events draining at 1B/day limit; after drain, compact the event store to reclaim DuckDB space
- [ ] **Overview upstream: retry discovery** — Overview runs discovery ONCE at startup; if PMA daemon is slow, it caches nil and returns 503. Upstream fix needed (Overview should retry). SystemNix has a watchdog workaround
- [ ] **NVMe drive replacement evaluation** — SMART says healthy (11% wear) but 58 unsafe shutdowns are the real risk. Consider TLC replacement, RAID1 for `/data`, or UPS to prevent unsafe shutdowns

---

## Deploy Verification Checklist

After `nix run .#deploy`, verify:

1. **Post-deploy check** — `nix run .#post-deploy-check` (hard-fails on critical issues)
2. **Pocket ID** — Verify `auth.home.lan` loads, check `journalctl -u pocket-id.service` for SQLITE_BUSY or francis panics (should be resolved by 2.12.0)
3. **SearXNG** — Verify `search.home.lan` loads, test a search query, confirm rate limiter removal didn't break functionality
4. **Attic cache** — Verify `cache.home.lan` loads, run `attic cache info monitor365`
5. **BTRFS scrub** — Verify `btrfs scrub status /` shows weekly schedule, check Prometheus metrics for scrub status
6. **Shell** — Verify fish startup < 60ms (`fish -i -c exit` with timing), verify direnv caching works (`time cd .`)
7. **Desktop** — Check `journalctl --user -u quickshell` for GLSL shader errors, verify wallpaper daemon, test transparency

---

_Completed work is tracked in [CHANGELOG.md](./CHANGELOG.md)._
