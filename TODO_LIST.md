# SystemNix TODO List

**Updated:** 2026-07-30 | **Last session:** SigNoz alert rules always-firing bug fix (target=0 + above_or_equal = always true), git insteadOf restoration, /tmp tmpfs cap raise + cleanup timer, full docs-health + update-old-docs pass (76 historical files read, 24 annotated)

---

## Priority 0: Critical (Data Loss Risk)

- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged in every status report since 2026-06-25. **Manual action required:** set up Hetzner StorageBox + BorgBackup
- [ ] **Run BTRFS scrub on `/` and `/data`** — Jul 8 NVMe report found 91,561 csum errors with identical wrong checksum. No scrub has ever been run. **Manual command:** `sudo btrfs scrub start -r /data` and `sudo btrfs scrub start -r /`. Monitoring infrastructure is complete (scrub metrics every 5 min via `btrfs-health.nix`, Gatus alerts on Discord when `btrfs_scrub_error_free` drops to 0)
- [ ] **Run `smartctl -a /dev/nvme0n1`** — Cannot determine if the Lexar NQ790 is physically failing (NAND degradation) or if the 91K csum errors are purely a `discard=async` software issue. SMART data is the only way to know. **Manual command required**

## Priority 1: High (Stability & Monitoring)

- [ ] **Twenty CRM: fix PG role + decide Docker vs native** — `twenty-server` crash-loops with `FATAL: role "twenty" does not exist`. Data is NOT lost (1 user, 1 workspace, 66 companies across 90 tables). Needs PG role fix + decision on Docker vs native nixification
- [ ] **Find the missing 20th SigNoz alert rule** — 20 `mkRule` calls in `_signoz-alerts.nix` but only 19 rules appear in the API. The 20th rule is silently dropped during provisioning. Investigate the provision script's dedup logic or a POST failure
- [ ] **Add `target` validation to SigNoz `mkRule`** — Prevent `target=0` + `above_or_equal` (mathematically always true for non-negative metrics). Four rules had this bug (fixed `2026-07-30_14-27`). Add a Nix-level assertion so it can't recur

## Priority 2: Manual Steps (Blocked on Human)

- [ ] **Deploy pending changes** — Code-complete items pending `nix run .#deploy`: /tmp tmpfs cap raise (16G -> 48G) + cleanup timer, git insteadOf restoration (`502020e7`), SigNoz always-firing rules fix. Run deploy then `nix run .#post-deploy-check`
- [ ] **Hermes: install SSH deploy key** — private key to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model`
- [ ] **Install `dnsblockd-CA` on Mac** — Without it, Chrome/Helium block Touch ID platform authenticator for `*.home.lan`, breaking Gatus/Forgejo SSO. Manual: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dnsblockd-ca.pem`
- [ ] **Turso plan decision** — DiscordSync switched to sqlite backend (eliminates Turso 403). Cloud sync via Turso requires upgrading the plan or waiting for quota reset. Decide: keep sqlite-only, or re-enable turso-sync after plan upgrade

## Priority 3: Infrastructure

- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), now has btrbk snapshot protection but still not a named subvolume. Migration to `@data` would enable separate CoW semantics. Requires ~1h downtime
- [ ] **/tmp Prometheus monitoring** — Add `df /tmp` metric to `system-health` textfile collector + Gatus alert when /tmp exceeds 80% (~38 GiB). Would catch runaway builds before hitting the 48 GiB ceiling

## Priority 4: Code Quality

- [ ] **Wire `doc-freshness-check.sh` into pre-commit or CI** — Script exists (`scripts/doc-freshness-check.sh`) but is not automated. Validates doc counts against code
- [ ] **Homepage widgets audit** — Audit `widgets.yaml` for schema issues (same class as the bookmark schema crash). Verify Productivity `columns=4` with 3 tiles, fix dishonest Caddy tile latency, consider local favicon bundling instead of CDN

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
