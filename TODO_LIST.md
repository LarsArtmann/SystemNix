# SystemNix TODO List

**Updated:** 2026-07-29 | **Last deploy:** `840ff561` (SearXNG follow-up fixes — proxyTo X-Real-IP, sops crush-daily owner fix)

---

## Priority 0: Critical (Data Loss Risk)

- [ ] **Off-site backup** — No DR backup exists. Forgejo (Git history), Immich (photos), Twenty (CRM), DiscordSync (Discord archive) would all be lost on SSD failure or BTRFS corruption. Evaluated in `docs/research/hetzner-storagebox-borgbackup.md` but never executed. Flagged in every status report since 2026-06-25.
- [ ] **Run BTRFS scrub on `/` and `/data`** — Jul 8 NVMe report found 91,561 csum errors with identical wrong checksum. No scrub has ever been run. Need `sudo btrfs scrub start -r /data` and `sudo btrfs scrub start -r /`. Monitoring infrastructure is complete (scrub metrics every 5 min via `btrfs-health.nix`, Gatus alerts on Discord when `btrfs_scrub_error_free` drops to 0).
- [ ] **Run `smartctl -a /dev/nvme0n1`** — Cannot determine if the Lexar NQ790 is physically failing (NAND degradation) or if the 91K csum errors are purely a `discard=async` software issue. SMART data is the only way to know.

## Priority 1: High (Stability & Monitoring)

- [ ] **SigNoz: 19 alert rules NOT provisioned** — `signoz-provision` had a 4-month-old jq array-path bug (`.rules[]` instead of `.data.rules[]`) that blocked deploy. The jq path is now fixed, but the `RemainAfterExit=yes` + `Restart=no` oneshot never re-ran. Rules endpoint still returns `{"data":{"rules":[]}}` — a silent observability gap (no Gatus alert fires because no rules exist). Action: re-trigger `signoz-provision.service`, add `restartTriggers` to ALL SystemNix provisioner oneshots, add a Gatus check asserting `GET /api/v1/rules → .data.rules length > 15`.
- [ ] **SearXNG runtime verification** — SearXNG is deployed and functional (returns search results) but 4 items remain unverified: (1) Gatus health check green (never queried the Gatus API), (2) browser default search-engine policy at runtime, (3) favicon cache state (`faviconcache.db` may not exist; SQLite `ResourceWarning`), (4) wikidata 403 / Brave 429 engine errors (assumed transient, not tested). See `docs/status/2026-07-29_00-05_searxng-followup-fixes-self-review.md`.
- [ ] **monitor365 buffer backlog purge** — 597M events predate the integrity fix, may be unrecoverable. Daily 10K tenant limit blocks drain (would take ~163 years). Needs purge or limit raise.
- [ ] **Twenty CRM: fix PG role + decide Docker vs native** — `twenty-server` crash-loops with `FATAL: role "twenty" does not exist`. Data is NOT lost (1 user, 1 workspace, 66 companies across 90 tables). Needs PG role fix + decision on Docker vs native nixification.
- [x] **MiniMax-M3 model identifier verification** — Verified 2026-07-29. The MiniMax API accepts `MiniMax-M3` as a valid model identifier: PMA auto-commit daemon produced **1,147 successful AI-generated commits** in the last 7 days (durations 3-15s, consistent with LLM API calls) with zero model-not-found/4xx API errors. The model constant lives at `go-commit/pkg/commit/providers/minimax.go:4` (`defaultMinimaxModel = "MiniMax-M3"`). An invalid model would reject every request and yield zero successful AI commits.

## Priority 2: Manual Steps (Blocked on Human)

- [ ] **Hermes: install SSH deploy key** — private key to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model`
- [ ] **Install `dnsblockd-CA` on Mac** — Without it, Chrome/Helium block Touch ID platform authenticator for `*.home.lan`, breaking Gatus/Forgejo SSO. Manual: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dnsblockd-ca.pem`

## Priority 3: Infrastructure

- [ ] **Caddy: generalize `proxyTo` X-Real-IP** — `protectedVHost` now adds `X-Real-IP`, but 10 bare `reverse_proxy` directives (oauth2-proxy, Pocket ID, Forgejo, SigNoz, Gatus, OpenSEO GSC, Monitor365) still see `127.0.0.1`. Apply `header_up X-Real-IP {remote_host}` to all reverse_proxy directives.
- [ ] **Crush Daily: data backfill 2026-07-19 to 2026-07-26** — The scheduler only collects "yesterday". The 8-day gap (between the silent-zero-data bug and the fix) has no reports. Needs a manual POST per date or a `backfill` option.
- [ ] **BTRFS `/data` subvolume migration** — currently toplevel (subvolid=5), now has btrbk snapshot protection but still not a named subvolume. Migration to `@data` would enable separate CoW semantics. Requires ~1h downtime.
- [ ] **Firewall deny-by-default** — all inbound allowed, services exposed to LAN. Should restrict to 80/443 + SSH + LAN-only ports.
- [ ] **Replace X11-only runtime deps with Wayland equivalents in monitor365** — `xdotool`, `xprintidle`, `scrot` are X11-only but evo-x2 runs niri (Wayland-only). Consider adding `grim`, `slurp`, `wtype`, `wlr-randr`.

## Priority 4: Code Quality

- [ ] **Split large modules** — signoz (943L), forgejo (725L) into sub-modules.
- [ ] **Re-enable `cqrs-lint` and `mr-sync`** — both disabled in `lib/lars-packages.nix` due to cmdguard/samber-do-auditlog v0.6.0+ API break. `samber-do-auditlog` is pinned to v0.5.0 as a top-level flake input, but the disabled packages need verification + re-enable.
- [ ] **Convert `minecraft.nix` raw iptables** to declarative `networking.firewall.allowedTCPPorts`
- [ ] **Convert `ssh-config.nix` `home.activation.ssh-sockets-dir`** to `systemd.user.tmpfiles.rules` — same class of conversion, HM-level. Discovered during activationScripts audit.
- [ ] **Audit all `writeShellApplication` scripts for missing `runtimeInputs`** — gpu-active collector lacked `gawk`, same bug class may exist elsewhere.
- [ ] **go-commit: pin as top-level flake input** — flake.lock shows go-commit at `ref=master` (transitive via PMA). PMA's own `service_gogit.go` fix means this is no longer blocking, but pinning would prevent future regressions from `mkPreparedSource` override.

## Priority 5: Desktop (from Jul 9 Helium/browser reports)

- [ ] **Test removing `--enable-zero-copy`** — if it prevents display hotplug crashes, `--disable-gpu-watchdog` may become unnecessary.
- [ ] **Remove `--enable-gpu-rasterization`** — increases GPUActive memory pressure on Strix Halo with no proven benefit.
- [ ] **Remove 9gag Post Filter** — abandoned extension ("THIS PROJECT IS DEAD").

## Priority 6: Upstream Contributions

### nixpkgs

- [ ] **`aw-watcher-utilization` poetry-core migration** — `pkgs/aw-watcher-utilization.nix:19-24`. Add `postPatch` to nixpkgs package.
- [ ] **`valkey` / `aiocache` / `timm` / `xformers` broken tests** — 4 packages with `doCheck = false`. Investigate and PR fixes.
- [ ] **`taskwarrior3` build flags** — `SYSTEM_CORROSION=on` + `ENABLE_TLS_NATIVE_ROOTS=on` should be nixpkgs defaults.
- [ ] **Kitty GC resilience patch** — After `nix-collect-garbage`, kitty's bundled binary lookup breaks.
- [ ] **KeePassXC Chromium manifests** — nixpkgs only ships Firefox-format native messaging manifests.
- [ ] **`llama-cpp` ROCm MMFMA flag** — `-DGGML_HIP_MMQ_MFMA=ON` should be a package option.

### Home Manager

- [x] **ActivityWatch Wayland watcher: `graphical-session.target` deps** — Done 2026-07-24. Local workaround hardened with `StartLimitBurst=5`/`StartLimitIntervalSec=300` (prevents the observed `start-limit-hit` on slow compositor startup). Upstream Home Manager patch prepared in `docs/services/home-manager-activitywatch-graphical-session.patch` (adds a `requiresGraphicalSession` watcher option); submission is a manual external step.
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
- [ ] **Monitor365 agent to server auth** — no auth, anyone on LAN can POST data
- [ ] **Disabled service triage** — voice-agents, minecraft: decide enable or remove

---

## Documentation

- [ ] **Add AGENTS.md gotchas** — Two gotchas overdue from multiple sessions: (1) homepage `mdi-*` icon names don't exist in the dashboard-icons pack (verify against the pack before using), (2) md-go-validator "prebuilt ELF binaries in Go modules break FOD purity" (go-branded-id v0.5.0 case study).
- [ ] **Add doc-freshness CI check** — script that verifies doc counts against code.
- [ ] **Create `docs/DOMAIN_LANGUAGE.md`** — does not exist yet. Would document domain terms for the Nix config ecosystem (BTRFS, DNS, SSO, etc.).

---

_Completed work is tracked in [CHANGELOG.md](./CHANGELOG.md)._
