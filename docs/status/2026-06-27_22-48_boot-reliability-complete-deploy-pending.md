# Status Report — Boot Reliability Fixes Complete, Deploy Pending

**Generated:** Saturday, June 27, 2026 at 22:48 CEST
**Host:** evo-x2 (NixOS, x86_64-linux, AMD Ryzen AI Max+ 395, 128GB RAM)
**Uptime:** 5h43m (booted 17:06) · **Branch:** master @ `71081507` (1 commit ahead of origin)

---

## TL;DR

All six boot-time service failures are **root-caused and fixed in Nix** (commit `f09dae03`). The deploy-blocking exit-code-4 bug is **also fixed** (commit `71081507`). The DiscordSync upstream migration bug — the only remaining failure — is **fixed in the DiscordSync repo** (commit `e6c7606`). **Everything is ready to deploy.** Nothing has been deployed yet.

| Metric | Value |
|--------|-------|
| Services fixed in Nix | 6/7 (DiscordSync needs flake update) |
| Services deployed | 0 — deploy pending |
| Failed units (live now) | 4 (all `start-limit-hit` from boot — will clear on deploy) |
| Disk: root (`/`) | 536G / 723G (76%) |
| Disk: `/data` | 631G / 1.1T (61%) |
| SystemNix commits ahead of origin | 1 |
| DiscordSync commits ahead of origin | 2 (1 mine + 1 pre-existing refactoring) |

---

## a) FULLY DONE ✅

### SystemNix — boot reliability fixes (commit `f09dae03`, eval-verified)

1. **SigNoz stale migration lock** — Added `ExecStartPre` (`signoz-clear-migration-lock`) that clears the `migration_lock` table on every start. Self-healing.
2. **Monitor365 agent** — Switched from `$XDG_RUNTIME_DIR` (empty in hardened services) to `%t` systemd specifier in ExecStart + ExecStartPre.
3. **Monitor365 server** — Removed invalid `--config` flag (CLI changed upstream; now uses env vars + XDG auto-load).
4. **dnsblockd-cert-import** — `path = [pkgs.nss.tools pkgs.coreutils]` (was `pkgs.nss` which is libs-only, missing `certutil`).
5. **xdg-document-portal** — Added `security.wrappers.fusermount3` setuid wrapper (pulls fuse3 into closure).
6. **ActivityWatch wayland watcher** — Added `Restart=on-failure` + `RestartSec=5s` (was no restart policy; stayed dead after compositor race).
7. **AGENTS.md** — 7 new gotchas documented (all root causes + the exit-code-4 gotcha).

### SystemNix — deploy fix (commit `71081507`)

8. **deploy.sh** — Now runs `systemctl reset-failed` (system + user scope) before `nh os switch`. This clears `start-limit-hit` state so `switch-to-configuration` can restart changed units. Without this, **any** service that crash-looped at boot permanently blocks all deploys with exit code 4.

### DiscordSync — upstream migration bug (commit `e6c7606`)

9. **`internal/db/db.go`** — Replaced single multi-statement `ExecContext(ctx, schema)` (270-line blob) with `splitSQLStatements()` + `execSchema()` that executes each statement individually. The turso/libSQL driver rejects multi-statement Exec — this was the root cause of `CREATE INDEX: guild_id` parse error. Handles `BEGIN...END` trigger bodies and SQL comments correctly. 3 new tests. All 54 tests pass. BuildFlow green.

### Verified understanding

10. **Turso driver** — Confirmed DiscordSync already uses the **modern pure-Go driver** (`turso.tech/database/tursogo` v0.6.1 via `purego`). The `github.com/tursodatabase/turso` URL is the engine/CLI repo, not a Go SDK. No driver migration needed.

---

## b) PARTIALLY DONE ⚠️

| Area | Status | What remains |
|------|--------|--------------|
| **Deploy** | All fixes committed, eval-verified, pre-commit hooks green. | **`nix run .#deploy` not yet run.** The 4 failed services are still in `start-limit-hit` from the last boot. Deploy will auto-reset them. |
| **DiscordSync in SystemNix** | Migration bug fixed in DiscordSync repo (`e6c7606`). | DiscordSync commit **not pushed**. SystemNix flake input **not updated** (`nix flake lock --update-input discordsync`). |
| **Verification** | `nix flake check --no-build` ✅, `nix eval .#nixosConfigurations.evo-x2` ✅. | No live deploy verification — can't confirm services actually start until deployed. |
| **DiscordSync repo** | Has 2 unpushed commits (mine `e6c7606` + pre-existing refactoring by another agent). | 17 files of uncommitted formatting/refactoring changes in working tree that I did **not** author — leaving untouched. |

---

## c) NOT STARTED 📋

| Item | Notes |
|------|-------|
| **Deploy the fixes** | `nix run .#deploy` — the single action that activates everything. |
| **Push DiscordSync commit** | `git push` in DiscordSync repo, then `nix flake lock --update-input discordsync` in SystemNix, then redeploy. |
| **Off-site backup** | No BorgBackup to Hetzner StorageBox. Single point of failure. |
| **BTRFS `/data` subvolume migration** | `/data` is toplevel (subvolid=5), no snapshot protection. ~1h downtime. |
| **Firewall deny-by-default** | NixOS allows all inbound. |
| **Monitor365 agent→server auth** | No authentication on LAN. |

---

## d) TOTALLY FUCKED UP 💥

### 1. The deploy has been blocked for the entire session

Four services have been sitting in `start-limit-hit` since boot (signoz, monitor365, monitor365-server, discordsync). The deploy-blocking exit-code-4 bug was only diagnosed and fixed an hour ago. Every `nh os switch` attempt before that failed silently. **The fixes exist but are not live.**

### 2. DiscordSync fix requires a two-repo deploy dance

The migration fix is in the DiscordSync repo (`e6c7606`), but SystemNix consumes it via a flake input pinned to a specific commit. To activate: (1) push DiscordSync, (2) update the flake lock in SystemNix, (3) rebuild. Three steps, any of which can fail. Until then, DiscordSync will still crash-loop.

### 3. DiscordSync working tree has foreign changes

17 files of uncommitted refactoring (generics in config.go, test cleanup, formatting) that I did not author. These block a clean `git push` — either they need to be committed/stashed first, or the push needs to be selective.

### 4. Boot is still slow (4min 53s)

`signoz-provision` takes 2 minutes waiting for signoz health checks. This will improve once signoz starts cleanly (the migration lock fix), but the provision script's timeout is still the single largest boot-time contributor.

---

## e) WHAT WE SHOULD IMPROVE 🔧

1. **Deploy immediately** — every fix in this session is inert until deployed.
2. **Two-repo deploy automation** — when a private LarsArtmann dependency changes, the update-push-relock-rebuild flow is manual and fragile. Consider a `nix run .#update-dep <name>` script.
3. **Post-deploy health check** — `deploy.sh` should verify that previously-failed services are now running, not just list `systemctl --failed`.
4. **Reset-failed should be automatic** — NixOS's `switch-to-configuration` should handle `start-limit-hit` gracefully. Consider an upstream PR or a `system.activationScripts` hook.
5. **Don't let services stay broken** — the 4 failed services were broken for the entire 5h43m uptime. Add a watchdog timer that alerts on services stuck in failed state.
6. **DiscordSync working tree hygiene** — the 17 uncommitted files need to be committed or stashed. A dirty working tree blocks clean pushes.

---

## f) Top 25 Things to Get Done Next

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Deploy the 6 fixes** (`nix run .#deploy`) | 🔴 Critical | XS |
| 2 | **Push DiscordSync** `e6c7606` → update flake lock → redeploy | 🔴 Critical | S |
| 3 | **Commit/stash DiscordSync's 17 uncommitted files** | 🔴 Blocker for push | XS |
| 4 | **Verify all 7 services start post-deploy** | 🔴 High | XS |
| 5 | **Verify signoz-provision completes** (should self-heal now) | 🔴 High | XS |
| 6 | **Push SystemNix** to origin (1 commit ahead) | 🟠 Medium | XS |
| 7 | **Set up BorgBackup** to Hetzner StorageBox | 🔴 Critical | M |
| 8 | **BTRFS `/data` subvolume migration** | 🔴 High | L |
| 9 | **Hermes manual steps** (OpenAI key, SSH key, fallback model) | 🟠 Medium | S |
| ~~10~~ | ~~**Fix network-dependent service ordering** (`.device` units)~~ | ✅ Done | M |
| 10 | **Reduce signoz-provision boot tail** | 🟠 Medium | M |
| 12 | **Firewall deny-by-default** | 🟠 High | M |
| 13 | **Bind Immich to localhost** | 🟡 Security | XS |
| 14 | **Monitor365 agent→server auth** | 🟡 Security | M |
| 15 | **Post-deploy health assertion** in deploy.sh | 🟠 Medium | S |
| 16 | **Watchdog for stuck-failed services** | 🟠 Medium | M |
| 17 | **Two-repo deploy automation script** | 🟢 Low | M |
| 18 | **Remove photomap** (decided, not done) | 🟢 Low | XS |
| 19 | **Audit `/nix` at 118G** — run `nix-collect-garbage -d` | 🟠 Medium | S |
| 20 | **Split large modules** (monitor365 716L, signoz 705L) | 🟢 Low | L |
| 21 | **Upstream nixpkgs PRs** (aw-watcher-utilization, etc.) | 🟢 Low | S |
| 22 | **Auditd enablement** (re-check NixOS bug #483085) | 🟡 Security | S |
| 23 | **Jan llama-server respawn investigation** | 🟠 Medium | M |
| 24 | **Provision Pi 3** for DNS failover cluster | 🟢 Low | L |
| 25 | **Darwin HM parity** (blocked by 256GB disk) | 🟢 Low | L |

---

## g) Top Question I Cannot Figure Out Myself 🤔

**What should I do with the 17 uncommitted files in the DiscordSync working tree?**

They contain real refactoring (not mine): `getEnvInt`/`getEnvDuration` collapsed into a generic `getEnvParsed[T]`, test dedup, and gofumpt formatting across `internal/bot/`, `internal/db/`, `internal/projection/`, and `internal/config/`. They were present when I started working on the migration fix.

Options:
- **Commit them** — they look like clean refactoring from another agent/session, but I didn't author them and can't verify their intent
- **Stash them** — safe, but blocks `git push` (my commit `e6c7606` is already committed on top of them, so push would work, but the stash creates divergence)
- **Leave them** — they don't block pushing `e6c7606` (it's already committed), but the working tree stays dirty

I need to know: are these your changes? Should I commit them, or are they WIP from another session that you'll handle?

---

## Commits This Session

### SystemNix (1 commit ahead of origin)

| Commit | Summary |
|--------|---------|
| `71081507` | fix(deploy): reset failed units before activation to prevent exit code 4 |
| `f09dae03` | fix(services): resolve six boot-time service failures from log audit |

### DiscordSync (2 commits ahead of origin, 1 mine)

| Commit | Summary |
|--------|---------|
| `e6c7606` | fix(db): split schema into individual statements for turso driver compat |

## Files Changed

### SystemNix
| File | Change |
|------|--------|
| `modules/nixos/services/signoz.nix` | + ExecStartPre (migration lock cleanup) |
| `modules/nixos/services/monitor365.nix` | agent `%t` specifier; server dropped `--config` |
| `modules/nixos/services/dns-blocker.nix` | `path = [pkgs.nss.tools pkgs.coreutils]` |
| `platforms/common/programs/activitywatch.nix` | + `Restart=on-failure` |
| `platforms/nixos/system/configuration.nix` | + `security.wrappers.fusermount3` |
| `scripts/deploy.sh` | + `systemctl reset-failed` before activation |
| `AGENTS.md` | + 7 gotcha entries |
| `docs/status/2026-06-27_21-18_*` | Previous status report |

### DiscordSync
| File | Change |
|------|--------|
| `internal/db/db.go` | `splitSQLStatements()` + `execSchema()` replacing single multi-statement Exec |
| `internal/db/db_test.go` | + 3 tests for splitter + trigger verification |

**Validation:** `nix flake check --no-build` ✅ · `nix eval .#nixosConfigurations.evo-x2` ✅ · `go test ./...` ✅ · BuildFlow ✅
