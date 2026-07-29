# SystemNix TODO List

**Updated:** 2026-07-29 | **Last session:** Crush Daily insights pipeline — 3 root-cause bugs fixed (errgroup cancellation, partial results discarded, timezone truncation), all 46 dates now have cross-project insights, flake.lock bumped, deployed

---

## Priority 0: Critical (Data Loss Risk)

- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged in every status report since 2026-06-25. **Manual action required:** set up Hetzner StorageBox + BorgBackup.
- [ ] **Run BTRFS scrub on `/` and `/data`** — Jul 8 NVMe report found 91,561 csum errors with identical wrong checksum. No scrub has ever been run. **Manual command:** `sudo btrfs scrub start -r /data` and `sudo btrfs scrub start -r /`. Monitoring infrastructure is complete (scrub metrics every 5 min via `btrfs-health.nix`, Gatus alerts on Discord when `btrfs_scrub_error_free` drops to 0).
- [ ] **Run `smartctl -a /dev/nvme0n1`** — Cannot determine if the Lexar NQ790 is physically failing (NAND degradation) or if the 91K csum errors are purely a `discard=async` software issue. SMART data is the only way to know. **Manual command required.**

## Priority 1: High (Stability & Monitoring)

- [ ] **SigNoz: 19 alert rules NOT provisioned** — `signoz-provision` now has proper HTTP status code checking (exits 1 on failure, was always exit 0 with `|| true`). `restartTriggers` added. Gatus health check + post-deploy assertion added. **Remaining:** the `POST /api/v1/rules` calls silently fail — likely a payload format mismatch with SigNoz 0.127.1. Next deploy will reveal the actual HTTP status code. May need to update the rule JSON format in `_signoz-alerts.nix` or use a different API endpoint (`/api/v2/rules`?).
- [x] **SearXNG runtime verification** — Done 2026-07-29. All 4 items verified: (1) Gatus health check GREEN — every 60s `success=true`, ~4ms response (queried via journald, Gatus API is OIDC-protected at 401); (2) Browser search-engine policy VERIFIED — `/etc/chromium/policies/managed/extra.json` contains `DefaultSearchProviderSearchURL=https://search.home.lan/search?q={searchTerms}` + suggest URL, deployed and live; (3) Favicon cache WORKING — `/favicon_proxy` serves binary image data for result favicons (cache DB at `/var/cache/searx/faviconcache.db`); (4) Engine errors DIAGNOSED — Brave 429 "too many requests" is live but transient (SearXNG auto-retries after `ban_time_on_fail=5s`). Wikidata was NOT a 403 — it failed DNS init at boot (`Name or service not known`) and stayed permanently disabled. Root cause: searx.service had no dependency on `dnsblockd.service`. **Fixed:** added `after/wants dnsblockd.service` + `ExecStartPre searxng-wait-dns` gate to both `searx.service` and `searx-init.service` (same pattern as discordsync). **Pending deploy.**
- [x] **monitor365 buffer backlog purge** — Fixed 2026-07-29. `monitor365-schema-migrate` now sets `max_events_per_day = 1000000000` (1B) on every run, overriding the upstream 10K/day default. The 597M backlog will drain in ~1 day after deploy. The integrity-hash fix (`ebb26a0bd`) recomputes hashes on upload, so legacy events are recoverable. **Pending deploy.**
- [ ] **Twenty CRM: fix PG role + decide Docker vs native** — `twenty-server` crash-loops with `FATAL: role "twenty" does not exist`. Data is NOT lost (1 user, 1 workspace, 66 companies across 90 tables). Needs PG role fix + decision on Docker vs native nixification.
- [x] **MiniMax-M3 model identifier verification** — Verified 2026-07-29. PMA auto-commit daemon produced 1,147 successful AI-generated commits in 7 days with zero model-not-found errors.

## Priority 2: Manual Steps (Blocked on Human)

- [ ] **Hermes: install SSH deploy key** — private key to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model`
- [ ] **Install `dnsblockd-CA` on Mac** — Without it, Chrome/Helium block Touch ID platform authenticator for `*.home.lan`, breaking Gatus/Forgejo SSO. Manual: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dnsblockd-ca.pem`
- [ ] **Deploy pending changes** — Multiple code-complete changes are undeployed: Caddy `proxyTo` generalization, browser extension fix + 9gag removal + MV2 policy, SigNoz provisioner error handling, monitor365 Wayland deps, Pocket-ID secret hard-fail, crush-daily-backfill app. **Run `nix run .#deploy`** then verify with `nix run .#post-deploy-check`.

## Priority 3: Infrastructure

- [x] **Caddy: generalize `proxyTo` X-Real-IP** — Done 2026-07-29. ALL reverse_proxy directives now use `${proxyTo PORT}`. Zero bare `reverse_proxy` remaining. **Pending deploy.**
- [x] **Crush Daily: data backfill** — Done 2026-07-29. All 45 zero-data dates backfilled. Collect + reports 100% complete. 31/45 dates missing cross-project insights (Synthetic API rate limit). **Pending service restart** to rehydrate in-memory read model.
- [x] **Crush Daily: retry 31 failed cross-project insights** — Fixed 2026-07-29. Three root-cause bugs found and fixed: (1) `errgroup.WithContext` cancelled all goroutines on first error (→ plain `errgroup.Group` + error slice), (2) partial results discarded before storage (→ moved storage before error return), (3) `Yesterday()` timezone truncation — `Truncate(24h)` snapped to UTC midnight, causing nightly collect (00:30 CEST) and insights (03:00 CEST) to compute different dates (→ `time.Date()` with local location). All upstream commits pushed (`868fe33`, `9286bf0`, `0cb5ea6`). Flake.lock bumped. 27/31 batch successes + remaining dates retried manually. All 46 collected dates now have cross-project insights.
- [x] **Firewall deny-by-default** — Already configured. `networking.nix` has `firewall.enable = true`, `trustedInterfaces = [ "eno1" ]` (LAN trusted), only 22/53/80/443 open to WAN. Correct homelab design.
- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), now has btrbk snapshot protection but still not a named subvolume. Migration to `@data` would enable separate CoW semantics. Requires ~1h downtime.
- [x] **Replace X11-only deps in monitor365** — Done 2026-07-29. Added `grim`, `slurp`, `wtype` alongside legacy X11 tools. X11 tools kept for upstream compatibility.

## Priority 4: Code Quality

- [x] **Split large modules** — Done 2026-07-29. signoz: 943→511L, forgejo: 725→353L.
- [x] **Fix cqrs-lint (go-cqrs-lite stale lock)** — Done 2026-07-29. Root cause was multi-layered: (1) go-cqrs-lite flake.lock had stale `flake:false` orphan node, (2) upstream go-cqrs-lite still imported `cmdguard/v3` but cmdguard had migrated to v4, (3) `go.mod` needed tidying to capture indirect deps from local-source replaces. Fixed upstream (cmdguard v3→v4 imports, `go mod tidy`, vendorHash). SystemNix lock surgery updated `go-cqrs-lite_3` to the fixed commit. `nix build .#cqrs-lint` produces `cqrs-lint 0.2.2`.
- [x] **mr-sync re-enabled** — Builds from upstream. Uses `proxyVendor = true` (mkPreparedSource workaround). `doCheck = false` is upstream — change to `checkFlags` upstream. Push to GitHub done.
- [x] **minecraft.nix iptables** — Already uses `networking.firewall.allowedTCPPorts`.
- [x] **ssh-config.nix activation → tmpfiles** — Done 2026-07-29.
- [x] **Audit writeShellApplication runtimeInputs** — Done 2026-07-29. Fixed dms-locks, dms-wallpaper-next, gpu-python.
- [x] **go-commit: pin as top-level flake input** — Done 2026-07-29. Pinned to `refs/tags/v0.4.0`.
- [x] **samber-do-auditlog pin removed** — Done 2026-07-29. v0.5.0 pin was wrong (cmdguard v3.1.0 needs v0.7.0+). Lock resolves to v0.8.1 transitively. Dead code removed.
- [x] **Convert remaining `writeShellScriptBin` to `writeShellApplication`** — Done 2026-07-29. Converted openseo (4 scripts, coreutils/findutils runtimeInputs), templates/go-flake-parts (2 apps, fixed `program=` derivation→`lib.getExe` bug + goPkg/golangci-lint runtimeInputs), overlays/linux.nix bun wrapper (systemd runtimeInputs), and monitor365 duckdb-heal (was inline `writeShellScript`→`lib.getExe`, rewrote `ls -t|head` to `find -printf|sort` to pass shellcheck SC2012). All 8 scripts verified shellcheck-clean; `nix flake check --no-build` passes.

## Priority 5: Desktop (from Jul 9 Helium/browser reports)

- [ ] **Test removing `--enable-zero-copy`** — if it prevents display hotplug crashes, `--disable-gpu-watchdog` may become unnecessary.
- [x] **Remove `--enable-gpu-rasterization`** — Already excluded in `base.nix:43-46`.
- [x] **Fix Helium extensions not installing** — Done 2026-07-29. Root cause: `--disable-background-networking` killed the ExtensionDownloader. Removed both `--disable-background-networking` and `--disable-component-update`. Added `ExtensionManifestV2Availability = 2`. Removed dead 9gag Post Filter. **Pending deploy + runtime verification** (check `chrome://extensions`).
- [ ] **Research `--disable-component-update` removal impact** — Removed alongside background networking. May enable CRLSet/cert-revocation component fetches. If extensions work without it, consider re-adding it (blocks unwanted component fetches without breaking extensions).
- [ ] **Verify all 20 extension IDs are live on Chrome Web Store** — Dead IDs cause silent download failures now that networking is enabled.

## Priority 6: Upstream Contributions

### nixpkgs

- [ ] **`aw-watcher-utilization` poetry-core migration** — `pkgs/aw-watcher-utilization.nix:19-24`. Add `postPatch` to nixpkgs package.
- [ ] **`valkey` / `aiocache` / `timm` / `xformers` broken tests** — 4 packages with `doCheck = false`. Investigate and PR fixes.
- [ ] **`taskwarrior3` build flags** — `SYSTEM_CORROSION=on` + `ENABLE_TLS_NATIVE_ROOTS=on` should be nixpkgs defaults.
- [ ] **Kitty GC resilience patch** — After `nix-collect-garbage`, kitty's bundled binary lookup breaks.
- [ ] **KeePassXC Chromium manifests** — nixpkgs only ships Firefox-format native messaging manifests.
- [ ] **`llama-cpp` ROCm MMFMA flag** — `-DGGML_HIP_MMQ_MFMA=ON` should be a package option.

### Home Manager

- [x] **ActivityWatch Wayland watcher: `graphical-session.target` deps** — Done 2026-07-24. Local workaround + upstream patch prepared.
- [ ] **Darwin user definition requirement** — HM on Darwin requires explicit `users.users.<name>.home` — tracks issue #6036.

### Third-Party

- [ ] **`jscpd` lockfile** — PR upstream to publish `pnpm-lock.yaml`.
- [ ] **XRT boost 1.87+ compat** — PR to `nix-amd-npu` to pin `boost187` for XRT build.

### LarsArtmann Apps

- [ ] **`hermes`**: Auto-create directory structure on first run; handle own state migration; sane defaults for `OLLAMA_API_KEY`; use PID file or socket-based single-instance locking instead of `--replace` flag.
- [x] **`mr-sync`**: Fixed all 6 previously-failing tests. Done 2026-07-29. Root cause was two-layered: (1) go-atomic-write v0.4.0's `commitVerified` acquired a flock (which creates the file via O_CREATE) before checking existence on zero-fingerprint first-write — fixed in v0.4.1 (tagged + pushed). (2) Three tests passed zero fingerprint when the file already existed — fixed by parsing the file first to get the correct fingerprint. `checkFlags` removed entirely, `doCheck` defaults to true, all tests pass. All 9 SSH flake inputs converted to `github:` HTTPS URLs.
- [x] **`go-cqrs-lite`**: Fixed stale flake.lock (was a copy of SystemNix's 249-node lock — replaced with correct 14-input lock). cmdguard v3→v4 migration verified. All flake inputs are `github:` HTTPS URLs. cqrs-lint v0.2.2 builds, `nix flake check` passes. Pushed to GitHub.

## Priority 7: Long-Term

- [ ] **Provision Pi 3** for DNS failover cluster — hardware required
- [ ] **Auditd enablement** — blocked on NixOS 26.05 bug #483085
- [ ] **AppArmor enablement** — commented out in security-hardening.nix
- [ ] **Darwin Home Manager parity** — disk constrained (256GB, 90%+ full)
- [ ] **Monitor365 agent to server auth** — no auth, anyone on LAN can POST data
- [ ] **Disabled service triage** — voice-agents, minecraft: decide enable or remove

---

## Documentation

- [x] **Add AGENTS.md gotchas** — Done 2026-07-29. Added 6 gotchas: mdi-* icons, prebuilt ELF binaries, switch-to-configuration+oneshot, proxyTo canonical, SigNoz || true fix, Helium extensions.
- [x] **Create `docs/DOMAIN_LANGUAGE.md`** — Done 2026-07-29. Created with infrastructure domain terms.
- [x] **Add doc-freshness CI check** — Done 2026-07-29. `scripts/doc-freshness-check.sh` validates doc counts against code.
- [x] **Annotate stale historical reports** — Done 2026-07-29. 4 reports annotated with resolution notes.
- [x] **README.md audit** — Done 2026-07-29. Updated module/script/package/Gatus counts, added SearXNG to service table.
- [x] **Hermes v0.19 in FEATURES/CHANGELOG** — Done 2026-07-29.
- [ ] **Wire `doc-freshness-check.sh` into pre-commit or CI** — Script exists but not automated.

---

## Deploy Verification Checklist

After `nix run .#deploy`, verify:

1. **SigNoz provisioner** — Check `journalctl -u signoz-provision.service` for HTTP status codes on POST /api/v1/rules. If non-2xx, the rule JSON format needs updating for SigNoz 0.127.1.
2. **Browser extensions** — Launch Helium, check `chrome://extensions` for installed extensions. Check `~/.config/net.imput.helium/Default/Extensions/` is non-empty.
3. **Caddy proxyTo** — Check service access logs for real client IPs (not `127.0.0.1`).
4. **Crush Daily** — Run `sudo systemctl restart crush-daily.service`, then verify `GET /api/reports/2026-07-28` returns non-zero sessions.
5. **monitor365 Wayland** — Verify `grim`/`slurp`/`wtype` are in the agent's PATH (`systemctl show monitor365.service -p Environment`).
6. **Post-deploy check** — `nix run .#post-deploy-check` (hard-fails on SigNoz rules if 0 provisioned).

---

_Completed work is tracked in [CHANGELOG.md](./CHANGELOG.md)._
