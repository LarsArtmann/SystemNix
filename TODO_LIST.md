# SystemNix TODO List

**Updated:** 2026-07-30 | **Last session:** SigNoz alert rules always-firing bug fix (target=0 + above_or_equal = always true), git insteadOf restoration, /tmp tmpfs cap raise + cleanup timer, full docs-health + update-old-docs pass (76 historical files read, 24 annotated)

---

## Priority 0: Critical (Data Loss Risk)

- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged in every status report since 2026-06-25. **Manual action required:** set up Hetzner StorageBox + BorgBackup
- [ ] **Run BTRFS scrub on `/` and `/data`** — Jul 8 NVMe report found 91,561 csum errors with identical wrong checksum. No scrub has ever been run. **Manual command:** `sudo btrfs scrub start -r /data` and `sudo btrfs scrub start -r /`. Monitoring infrastructure is complete (scrub metrics every 5 min via `btrfs-health.nix`, Gatus alerts on Discord when `btrfs_scrub_error_free` drops to 0)
- [ ] **Run `smartctl -a /dev/nvme0n1`** — Cannot determine if the Lexar NQ790 is physically failing (NAND degradation) or if the 91K csum errors are purely a `discard=async` software issue. SMART data is the only way to know. **Manual command required**

## Priority 1: High (Stability & Monitoring)

- [ ] **Twenty CRM: fix PG role + decide Docker vs native** — `twenty-server` crash-loops with `FATAL: role "twenty" does not exist`. Data is NOT lost (1 user, 1 workspace, 66 companies across 90 tables). Needs PG role fix + decision on Docker vs native nixification
- [ ] **Find the missing 20th SigNoz alert rule** — 20 `mkRule` calls in `_signoz-alerts.nix` but only 19 rules appeared in the API. The 20th rule was silently dropped during provisioning. **UPDATE 2026-07-30:** Now 20 rules exist (added `/tmp TmpFS Usage High`). Need to verify all 20 appear in the live API after deploy — the original 20th drop may still be a provision script bug
- [x] **Add `target` validation to SigNoz `mkRule`** — DONE 2026-07-30. `validateTarget` assertion in `_signoz-alerts.nix` throws at eval time on `target=0 + above_or_equal` (always true) and `target=0 + below` (never true). Verified: all 20 rules pass, deliberate bad target correctly throws. `nix flake check` catches it before deploy

## Priority 2: Manual Steps (Blocked on Human)

- [ ] **Deploy pending changes** — Code-complete items pending `nix run .#deploy`: /tmp tmpfs cap raise (16G -> 48G) + cleanup timer, git insteadOf restoration (`502020e7`), SigNoz always-firing rules fix, CPUQuota=200% default, mkRule target validation, /tmp tmpfs monitoring (system-health + SigNoz + Gatus), Homepage Caddy tile + favicon fixes. Run deploy then `nix run .#post-deploy-check`
- [ ] **Hermes: install SSH deploy key** — private key to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model`
- [ ] **Install `dnsblockd-CA` on Mac** — Without it, Chrome/Helium block Touch ID platform authenticator for `*.home.lan`, breaking Gatus/Forgejo SSO. Manual: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dnsblockd-ca.pem`
- [ ] **Turso plan decision** — DiscordSync switched to sqlite backend (eliminates Turso 403). Cloud sync via Turso requires upgrading the plan or waiting for quota reset. Decide: keep sqlite-only, or re-enable turso-sync after plan upgrade

## Priority 3: Infrastructure

- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), now has btrbk snapshot protection but still not a named subvolume. Migration to `@data` would enable separate CoW semantics. Requires ~1h downtime
- [x] **/tmp Prometheus monitoring** — DONE 2026-07-30. `system-health.nix` emits `system_tmpfs_tmp_usage_percent` + `system_tmpfs_tmp_over_threshold` (80% of 48 GiB). SigNoz alert "/tmp TmpFS Usage High (>80%)" (primary, numeric comparison) + Gatus check (defense-in-depth, pre-computed boolean). Pending deploy

## Priority 4: Code Quality

- [ ] **Wire `doc-freshness-check.sh` into pre-commit or CI** — Script exists (`scripts/doc-freshness-check.sh`) but is not automated. Validates doc counts against code
- [x] **Homepage widgets audit** — DONE 2026-07-30. Widgets use `pkgs.formats.yaml` (structurally safe). Productivity has 5 tiles (not 3), `columns=4` correct. Caddy tile `siteMonitor` fixed (self-referential dashboard URL → Caddy admin API `localhost:2019/metrics`). Favicon CDN → local `/icons/nixos.png`. **Caveat:** field-level schema not cross-referenced against Homepage docs. Pending deploy

## Priority 5: Desktop

- [ ] **Test removing `--enable-zero-copy`** — if it prevents display hotplug crashes, `--disable-gpu-watchdog` may become unnecessary
- [ ] **Verify all 20 extension IDs are live on Chrome Web Store** — Dead IDs cause silent download failures now that background networking is enabled. Launch Helium, check `chrome://extensions`
- [ ] **Research `--disable-component-update` removal impact** — Removed alongside background networking. May enable CRLSet/cert-revocation component fetches. If extensions work without it, consider re-adding it

## Priority 6: Upstream Contributions

### nixpkgs

- [ ] **`aw-watcher-utilization` poetry-core migration** — `pkgs/aw-watcher-utilization.nix:19-24`. Add `postPatch` to nixpkgs package
- [ ] **`valkey` / `aiocache` / `timm` / `xformers` broken tests** — 4 packages with `doCheck = false`. Investigate and PR fixes
- [ ] **`taskwarrior3` build flags** — `SYSTEM_CORROSION=on` + `ENABLE_TLS_NATIVE_ROOTS=on` should be nixpkgs defaults
- [ ] **Kitty GC resilience patch** — After `nix-collect-garbage`, kitty's bundled binary lookup breaks
- [ ] **KeePassXC Chromium manifests** — nixpkgs only ships Firefox-format native messaging manifests
- [ ] **`llama-cpp` ROCm MMFMA flag** — `-DGGML_HIP_MMQ_MFMA=ON` should be a package option

### Home Manager

- [ ] **Darwin user definition requirement** — HM on Darwin requires explicit `users.users.<name>.home` — tracks issue #6036

### Third-Party

- [ ] **`jscpd` lockfile** — PR upstream to publish `pnpm-lock.yaml`
- [ ] **XRT boost 1.87+ compat** — PR to `nix-amd-npu` to pin `boost187` for XRT build

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

---

## Deploy Verification Checklist

After `nix run .#deploy`, verify:

1. **SigNoz provisioner** — Check `journalctl -u signoz-provision.service` for HTTP status codes on POST /api/v1/rules. Verify all 19+ rules are `state: inactive` (not `firing`)
2. **Browser extensions** — Launch Helium, check `chrome://extensions` for installed extensions. Check `~/.config/net.imput.helium/Default/Extensions/` is non-empty
3. **Caddy proxyTo** — Check service access logs for real client IPs (not `127.0.0.1`)
4. **Crush Daily** — Run `sudo systemctl restart crush-daily.service`, then verify `GET /api/reports/2026-07-30` returns non-zero sessions
5. **monitor365 Wayland** — Verify `grim`/`slurp`/`wtype` are in the agent's PATH (`systemctl show monitor365.service -p Environment`)
6. **/tmp tmpfs** — Verify `df -h /tmp` shows 48G capacity (requires remount/reboot for size change)
7. **Post-deploy check** — `nix run .#post-deploy-check` (hard-fails on SigNoz rules if 0 provisioned)

---

_Completed work is tracked in [CHANGELOG.md](./CHANGELOG.md)._
