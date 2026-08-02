# Deploy Failure Analysis & Fixes — 2026-08-02

**Session:** Post-deploy failure triage and fix
**Trigger:** User pasted `nix run .#deploy` output with 7 failed services
**Status:** Code fixes applied + committed, **NOT YET DEPLOYED**

---

## a) FULLY DONE

### 1. tmp-cleanup.service — pipefail arithmetic bug (FIXED)

**Root cause:** `pkgs.writeShellApplication` enables `set -o pipefail`. The pattern `du -skx /tmp 2>/dev/null | cut -f1 || echo 0` produces **multi-line output** when `du` exits non-zero (permission-denied subdirs under `/tmp`): pipefail makes the pipeline fail, `|| echo 0` runs and APPENDS `0` to whatever `cut` already output. Result: `before_kb="12345\n0"` → arithmetic syntax error in `$(())`, and the variable is never assigned → `unbound variable` on the next line under `set -u`.

**Fix:** Changed `|| echo 0` → `|| true` + `''${var:-0}` default. Applied to 3 scripts in `scheduled-tasks.nix`:
- `tmp-cleanup` (the primary failure)
- `nix-build-cleanup` (same bug pattern)
- `cargo-sweep` section (same bug pattern)

Also: `rm -rf` errors on other users' files (`Permission denied`) are now suppressed with `2>/dev/null || true` — the service runs with `CapabilityBoundingSet=""` so it correctly cannot delete files owned by other users. Skipping them is the correct security behavior.

**File:** `platforms/nixos/system/scheduled-tasks.nix`

### 2. backup-health-metrics.service — SIGPIPE + missing dir (FIXED)

**Root cause:** `find "$BACKUP_DIR" ... | sort -rn | head -1 | cut -f2` pipeline fails under pipefail:
1. `find` exits non-zero when backup directories don't exist yet (first boot, or service never ran)
2. `head -1` closes stdin after 1 line → SIGPIPE (exit 141) to `sort`/`find`
3. Under pipefail + `set -e`, the script exits before writing the `.prom` file

**Fix:** Added `|| true` to the pipeline, file-existence check `[ -e "$LATEST" ]`, `mkdir -p` on the textfile collector dir, and `2>/dev/null` on `stat`.

**File:** `modules/nixos/services/backup-coordination.nix`

### 3. forgejo-oidc-setup.service — DNS race (FIXED)

**Root cause:** Service had `after = ["dnsblockd.service"]` but NO DNS gate ExecStartPre. During deploy, dnsblockd restarts and there's a brief window where DNS isn't ready. The OIDC setup script resolves `auth.home.lan` → `dial tcp: lookup auth.home.lan: no such host`.

**Fix:** Added `forgejo-oidc-wait-dns` ExecStartPre that probes `getent hosts auth.home.lan` with 30x2s retries. Exits 1 on timeout (OIDC setup is mandatory — degraded mode is meaningless). Same DNS-gate pattern as SearXNG and DiscordSync.

**File:** `modules/nixos/services/forgejo.nix`

### 4. manifest/twenty-db-backup — Docker ordering race (FIXED)

**Root cause:** `mkDockerService` backup service had `after = ["${name}.service"]` + `requires = ["docker.service"]` but NOT `after = ["docker.service"]`. During deploy, Docker is stopped and restarted. If the backup timer fires during this window, `docker-compose exec` fails with `service "postgres" is not running`.

**Fix:** Added `"docker.service"` to the `after` list.

**File:** `lib/docker.nix`

### 5. monitor365-duckdb-heal — same SIGPIPE pattern (FIXED)

**Root cause:** Same `find | sort -rn | head -1` pipeline bug as backup-health-metrics.

**Fix:** Added `|| true`.

**File:** `modules/nixos/services/monitor365.nix`

### 6. atticd.service — storage directory missing (PARTIALLY FIXED)

**Root cause:** systemd-tmpfiles refuses to create `/data/atticd/storage` because `/data` is owned by `lars:users` — an "unsafe path transition" (`/data` (lars) → `/data/atticd` (root)). Result: directory never created → atticd fails with `status=226/NAMESPACE` (systemd can't bind-mount `ReadWritePaths` for a non-existent path).

**Fix applied:** Created `/data/atticd/storage` manually — atticd is now running and listening on `127.0.0.1:8200`.

**Code already present:** `atticd-storage-dir.service` (dedicated oneshot running as root WITHOUT namespace hardening) was already defined in the Nix code but was MISSING from the deployed generation (deploy generation mismatch — documented gotcha). A re-deploy will include it.

**File:** `modules/nixos/services/attic.nix`

### 7. AGENTS.md gotchas documented (DONE)

Added 5 new gotcha rows:
1. `writeShellApplication` pipefail + `|| echo 0` multi-line output
2. `writeShellApplication` pipefail + `| sort | head` SIGPIPE
3. Attic tmpfiles unsafe path transition on `/data`
4. forgejo-oidc-setup DNS gate
5. Docker backup service ordering (`requires` without `after`)

---

## b) PARTIALLY DONE

### Deploy verification
- Code fixes are committed (6 commits by auto-git daemon)
- `nix flake check --no-build` passes
- **NOT deployed** — the running system still has the old generation
- Manual fixes applied on the live system: `/data/atticd/storage` created, atticd running

### Pattern audit
- Found and fixed 5 instances of the pipefail/SIGPIPE bug pattern
- Found 22 total `| sort | head` pipeline matches across the codebase
- Only fixed the ones in `writeShellApplication` contexts (which have pipefail)
- **NOT audited:** Shell scripts in `scripts/` directory, overlay build scripts, inline `script = ''...''` that don't use `writeShellApplication`

---

## c) NOT STARTED

1. **Re-deploy** with `nix run .#deploy` to apply all fixes to the running system
2. **Post-deploy check** (`nix run .#post-deploy-check`) to verify all services are functional
3. **VM tests** for the new forgejo-oidc-setup DNS gate behavior
4. **Extract a shared DNS-gate helper** (`mkDnsGate` in `lib/default.nix`) — currently duplicated in 3 services (searxng, discordsync, forgejo)
5. **Audit `scripts/` directory** for the same pipefail patterns

---

## d) TOTALLY FUCKED UP / WHAT I FORGOT

### 1. I forgot to deploy
I fixed the code, verified `nix flake check`, but **never ran `nix run .#deploy`**. The user pasted a failed deploy and I fixed the source — but the running system is still broken. Every fix is academic until deployed.

### 2. I didn't run pre-commit hooks
I didn't verify that `alejandra` formatting or `statix` linting passes on the changed files. The auto-git daemon committed the changes, but pre-commit hooks may not have run.

### 3. I didn't verify the `CapabilityBoundingSet=""` interaction with tmp-cleanup
The `Permission denied` errors on `/tmp/TestTrailingSlash_*` files are because the service has `CapabilityBoundingSet=""` — even running as root, it CANNOT bypass DAC permissions. My `2>/dev/null || true` fix HIDES the error but the service still can't clean those files. This is arguably correct (security hardening working as designed — a cleanup service shouldn't be able to delete other users' files), but I should have documented WHY rather than just suppressing.

### 4. I didn't check the `_signoz-scripts.nix`, `_forgejo-scripts.nix`, and `overlays/linux.nix` pipelines
These files have `| head -1` patterns that could also SIGPIPE under pipefail. I identified them in my grep but only fixed the services I was actively debugging. A thorough fix would audit ALL matches.

### 5. I didn't consider the `forgejo-oidc-setup` DNS gate hard-fail consequences
The gate `exit 1`s on timeout. Since `forgejo-oidc-setup` has `wantedBy = ["forgejo.service"]`, a failed oneshot creates a `Wants=` dependency — but NOT `Requires=`, so forgejo should still start. However, the `OnFailure=` directive triggers a notification, and `deploy.sh`'s `reset-failed` would clear it. Still, I should verify this doesn't block forgejo startup on next deploy.

### 6. I didn't verify the atticd `atticd-storage-dir.service` is in the NEW generation
I verified the code defines it and `nix eval` shows it (from a stale cache), but I didn't verify it will actually be in the next deployed generation. The deploy generation mismatch gotcha means I should deploy and then check `ls /etc/systemd/system/atticd-storage-dir.service`.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture / Patterns
1. **Extract `mkDnsGate` helper** — DNS-gate ExecStartPre is duplicated 3 times with slight variations. A shared `lib/default.nix` helper would enforce consistency.
2. **Extract `safePipe` or document pipefail-safe pipeline patterns** — The `|| true` + `''${var:-0}` pattern should be documented or linted. A statix/custom linter rule could catch `|| echo 0` on pipelines.
3. **Consider `writeShellApplication` without pipefail for cleanup scripts** — Cleanup scripts that tolerate partial failures should NOT have `set -o pipefail` + `set -e`. Consider `writeShellApplication { runtimeInputs = [...]; text = ''set -eu\n...''; }` with explicit error handling.
4. **Pre-commit hook for pipefail-safe patterns** — A grep-based pre-commit check for `|| echo 0` on pipelines would catch this bug class.

### Process
5. **Always deploy after fixing** — Code fixes without deployment are incomplete work.
6. **Always run post-deploy-check** — Verify functional outcomes, not just service-alive.
7. **Audit shell scripts systematically** — When a bug pattern is found, grep for ALL instances, not just the ones in the failing service.

---

## f) Up to 50 Things to Get Done Next

| # | Priority | Task |
|---|----------|------|
| 1 | P0 | **Deploy** the fixes with `nix run .#deploy` |
| 2 | P0 | Run `nix run .#post-deploy-check` to verify all services functional |
| 3 | P0 | Verify `atticd-storage-dir.service` exists in the new generation |
| 4 | P0 | Reset failed services: `systemctl reset-failed hermes.service forgejo-oidc-setup.service` |
| 5 | P1 | Extract `mkDnsGate` helper in `lib/default.nix` (deduplicate searxng/discordsync/forgejo) |
| 6 | P1 | Audit ALL `| head` / `| sort` pipelines in `writeShellApplication` contexts across the entire repo |
| 7 | P1 | Audit `scripts/*.sh` for pipefail bugs (post-deploy-check, pre-deploy-check, deploy.sh) |
| 8 | P1 | Check `_signoz-scripts.nix` `\| head -1` patterns for SIGPIPE under pipefail |
| 9 | P1 | Check `_forgejo-scripts.nix` `\| head -1` patterns for SIGPIPE under pipefail |
| 10 | P1 | Check `overlays/linux.nix` `\| head -1` patterns for SIGPIPE under pipefail |
| 11 | P1 | Add pre-commit lint rule for `\|\| echo 0` on pipelines (always wrong under pipefail) |
| 12 | P2 | Document the `CapabilityBoundingSet=""` + tmp-cleanup interaction in the gotcha table |
| 13 | P2 | Verify forgejo-oidc-setup DNS gate doesn't block forgejo startup on next deploy |
| 14 | P2 | Consider whether atticd tmpfiles rule should be removed (storage-dir service handles it) |
| 15 | P2 | Add Gatus health check for atticd (HTTP GET on `cache.home.lan`) |
| 16 | P2 | Run `alejandra` on changed files to verify formatting |
| 17 | P2 | Run `statix check` on changed files |
| 18 | P2 | Consider adding `startLimitBurst` to `tmp-cleanup` and `backup-health-metrics` (oneshot services) |
| 19 | P3 | Create VM test for backup-health-metrics script (mock backup dirs, verify .prom output) |
| 20 | P3 | Create VM test for tmp-cleanup script (create stale files, verify removal) |
| 21 | P3 | Document the shared DNS-gate pattern in `docs/CONTRIBUTING.md` |
| 22 | P3 | Consider a `lib/pipeline.nix` helper for pipefail-safe shell variable assignment |
| 23 | P3 | Review whether `docker.nix` `mkDockerService` backup should also `after = ["${name}.service" "docker.service" "docker.socket"]` |
| 24 | P4 | Consider whether all Prometheus textfile collector scripts should share a common `lib` helper |
| 25 | P4 | Document the systemd-tmpfiles unsafe-path-transition limitation in `docs/troubleshooting/` |
| 26 | P4 | Review whether `/data` ownership should be `root:root` instead of `lars:users` to avoid unsafe transitions |
| 27 | P4 | Add a `pre-deploy-check` assertion for atticd-storage-dir.service existence |
| 28 | P4 | Consider whether forgejo-oidc-setup should have `startLimitBurst`/`startLimitIntervalSec` |
| 29 | P4 | Check if `harden {}` should add `CAP_DAC_OVERRIDE` to tmp-cleanup (NO — correct as-is) |
| 30 | P4 | Review all oneshot services for missing `startLimitBurst`/`startLimitIntervalSec` |

---

## g) Questions I Cannot Answer Myself

1. **Should I deploy now?** The fixes are committed but the running system is on the old generation. Deploying will rebuild + switch, which takes time and briefly restarts services. Should I proceed with `nix run .#deploy` or wait for your go-ahead?

2. **Should `/data` ownership be changed?** `/data` is owned by `lars:users` which causes systemd-tmpfiles unsafe path transitions for any service that needs root-owned subdirectories on `/data`. Changing to `root:root` would fix this class of bug permanently but might break Docker volume permissions or other services that expect `lars` ownership. This is a system-level decision with broad blast radius.

3. **Should the tmp-cleanup service be allowed to delete other users' files in /tmp?** Currently it can't (`CapabilityBoundingSet=""`), and it silently skips them. This is arguably correct (defense-in-depth — a cleanup service shouldn't have blanket delete power), but it means Go test artifacts (`TestTrailingSlash_*`) accumulate until manual cleanup. Should we add `CAP_DAC_OVERRIDE` to the service, or accept the limitation?
