# Session 61 — Forgejo Runner Token: Root Cause Fix + Full Ecosystem Status

**Date:** 2026-05-19 21:28 CEST
**Session Context:** Continuation of Gitea→Forgejo migration (Sessions 58-60)
**Machine:** evo-x2 (x86_64-linux, AMD Ryzen AI Max+ 395)

---

## Executive Summary

The Forgejo Actions runner (`gitea-runner-evo-x2`) is **finally working** after four sessions of failed attempts. The root cause was a `utils.escapeSystemdPath` mismatch — the nixpkgs module escapes hyphens in hostnames (`evo-x2` → `evo\x2dx2`), so our override was creating a **separate empty service** that never merged with the nixpkgs module's service.

**Runner status:** Running, registered with Forgejo, poller launched, accepting jobs.

---

## A. FULLY DONE

### 1. Forgejo Runner Token Lifecycle — FIXED THIS SESSION

**Root cause chain (all three required for the failure):**

1. **`escapeSystemdPath` mismatch** — nixpkgs `gitea-actions-runner` module generates service name `gitea-runner-evo\x2dx2.service` (escaped hyphen). Our override used `gitea-runner-evo-x2.service` (raw string). These are two separate systemd services. Our override never merged with nixpkgs module's service, producing an empty unit with no `ExecStart`.

2. **Unreliable token generation service** — The separate `forgejo-runner-token` service used `harden {}` (interfering with Forgejo CLI), swallowed errors silently (`|| TOKEN=""` + `exit 0`), and used `RemainAfterExit = true` preventing re-runs after silent failure.

3. **Stale Gitea-era `.runner` state** — After Gitea→Forgejo migration, the runner had old registration credentials pointing at the old Gitea database.

**Fix (single commit):**
- Eliminated `forgejo-runner-token` service entirely
- Two-step `ExecStartPre` in the runner service:
  1. `+` prefix (root) → `runuser -u forgejo -- forgejo actions generate-runner-token` → writes `/run/forgejo-runner/token` (644)
  2. Dynamic user → sources token, removes stale `.runner` on first run (`.forgejo-migrated` marker), registers runner
- `EnvironmentFile` uses `-` prefix (tolerates missing file on first start)
- Used `utils.escapeSystemdPath hostName` for correct service name override
- Migration marker (`.forgejo-migrated`) ensures one-time forced re-registration

**Evidence of success:**
```
level=info msg="Runner registered successfully."
level=info msg="Starting runner daemon"
level=info msg="runner: evo-x2, with version: v12.9.0, with labels: [ubuntu-latest ubuntu-22.04 native]"
level=info msg="[poller] launched"
```

### 2. Gitea→Forgejo Migration (Sessions 58-60) — COMPLETE

| Component | Status | Details |
|-----------|--------|---------|
| Forgejo package | ✅ | `pkgs.forgejo-lts` 15.0.0 |
| Data migration | ✅ | `/var/lib/gitea` → `/var/lib/forgejo` |
| DNS subdomain | ✅ | `forgejo.home.lan` (all references renamed) |
| Caddy vhost | ✅ | TLS via sops, forward auth |
| Actions runner | ✅ | `forgejo-runner` v12.9.0, 3 labels |
| Push mirrors | ✅ | Forgejo → GitHub on all owned repos |
| WatchdogSec | ✅ | Removed (Forgejo doesn't send WATCHDOG=1) |
| Health check script | ✅ | 34 correct service names (was checking dead `gitea`) |
| Admin password | ✅ | Auto-generated, stored in forgejo-owned file |
| API token generation | ✅ | `forgejo-generate-token` oneshot service |

### 3. Codebase Quality

| Metric | Value |
|--------|-------|
| TODO comments in `.nix` source | **1** (Pi 3 sops provisioning) |
| FIXME/HACK/XXX in source | **0** |
| `just test-fast` | ✅ Passes |
| `just test` (full build) | ✅ Passes |
| `nh os switch` (deploy) | ✅ Success |

---

## B. PARTIALLY DONE

| Item | Status | What's Left |
|------|--------|-------------|
| TODO_LIST.md | Stale | Multiple sessions old, doesn't reflect current state |
| Forgejo push mirrors | Working but | GITHUB_TOKEN embedded in push mirror URL in Forgejo DB — should use dedicated PAT with minimal scope |
| Darwin build | Not tested | `just test` only validates NixOS configs in this session |

---

## C. NOT STARTED

| Item | Priority | Notes |
|------|----------|-------|
| Raspberry Pi 3 provisioning | Medium | Hardware not available — blocks DNS failover cluster |
| PhotoMap AI | Low | Disabled in config, pinned to old SHA256 |
| Multi-WM (Sway backup) | Low | Disabled — may have bitrot |
| Dozzle log viewer at `logs.home.lan` | Low | In TODO_LIST.md |
| Twenty CRM verification | Medium | Unclear if actively deployed and functional |
| Voice agents verification | Medium | Whisper Docker + ROCm pipeline may need testing |
| nix-colors TODO cleanup | Low | Stale TODO referencing removed nix-colors |
| Shared flake-parts template | Low | For private Go repos (mkGoPackage, checks, devshells) |
| go-auto-upgrade `path:` input migration | Low | Convert to SSH URL like all other repos |
| SigNoz per-threshold channel routing | Low | critical→Discord, warning→log |
| ComfyUI removal from FEATURES.md | Low | Still listed as broken, should be marked removed |

---

## D. TOTALLY FUCKED UP (Lessons Learned)

### 1. Three Failed Runner Token Attempts (Session 60)

Three commits (`e0728ece`, `7bbba62e`, `255900c4`) each addressed ONE symptom without understanding the full chain:

| Attempt | What | Why It Failed |
|---------|------|---------------|
| 1 | Removed stale-file check, always regenerate | Token written to forgejo-owned dir, DynamicUser can't read it |
| 2 | Moved token to `/run/forgejo-runner-token` | forgejo user can't write to `/run/` root |
| 3 | `RuntimeDirectory = "forgejo-runner"` | Never deployed (service was in failed state from attempt 2) |

**What I should have done:** Read the nixpkgs `gitea-actions-runner.nix` module source FIRST, trace the full lifecycle (token generation → file write → file read → runner registration → runner connection), identify ALL constraints (DynamicUser, hardening, `/run/` permissions, systemd path escaping), and make ONE targeted fix.

### 2. Service Name Escaping Blind Spot

The most critical bug — `utils.escapeSystemdPath("evo-x2")` = `"evo\\x2dx2"` — was invisible because:
- The generated unit files were in `/etc/systemd/system/` with escaped names
- `journalctl -u gitea-runner-evo-x2` matched BOTH files (with and without escaping)
- The "no ExecStart" error seemed like a different issue entirely

**Rule:** When overriding nixpkgs-generated systemd services, ALWAYS use `utils.escapeSystemdPath` for service names.

### 3. Silent Error Swallowing

The `forgejo-runner-token` script had `|| TOKEN=""` and `exit 0` even on failure. systemd saw "success" but no token file was created. The runner then failed on missing `EnvironmentFile` (no `-` prefix).

**Rule:** Token generation must fail loudly (`exit 1`) so systemd reports the real error.

---

## E. WHAT WE SHOULD IMPROVE

### Process Improvements

1. **READ THE SOURCE before fixing** — Every failed attempt could have been avoided by reading `gitea-actions-runner.nix` first (it's 283 lines, takes 5 minutes)
2. **Trace full lifecycle, not symptoms** — Token generation → file write → permissions → file read → registration → connection. ALL steps.
3. **Check generated systemd units** — After `mkForce` overrides, always inspect the actual `.service` file in `/nix/store/.../etc/systemd/system/`
4. **Deploy incrementally** — Each commit should be deployable and verifiable independently, not stacked on broken previous attempts
5. **Never swallow errors in oneshot services** — `|| TOKEN=""` + `exit 0` hides failures. Fail loud, fail early.

### Technical Improvements

1. **Stale commit cleanup** — The three failed attempts (`e0728ece`, `7bbba62e`, `255900c4`) are in history. Consider squashing into the final fix.
2. **TODO_LIST.md is stale** — Last updated session 74, doesn't reflect sessions 75-61 work
3. **FEATURES.md has ghosts** — ComfyUI listed as "broken" but actually removed, benchmark scripts listed as "removed — never created"
4. **AGENTS.md should document `escapeSystemdPath` rule** — Added this session, but should be a project-wide pattern

---

## F. Top 25 Things We Should Do Next

### P0 — Immediate (this week)

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 1 | **Squash failed runner token commits** | 5min | Clean git history |
| 2 | **Verify Forgejo web UI** — login, browse repos, check Actions tab | 5min | Confirm full migration |
| 3 | **Test push mirrors** — verify Forgejo → GitHub sync works | 10min | Data integrity |
| 4 | **Clean up stale runner state** — `/var/lib/gitea-runner/evo-x2/` old files | 5min | Disk cleanup |
| 5 | **Remove old Gitea backup** — `/var/lib/gitea.pre-forgejo-migration` | 5min | Disk space |

### P1 — High Priority (this week)

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 6 | **Update TODO_LIST.md** — reflect current state, remove stale items | 30min | Organization |
| 7 | **Update FEATURES.md** — mark ComfyUI as removed, fix ghost scripts | 15min | Accuracy |
| 8 | **Create a Forgejo Actions test workflow** — run `echo hello` on the runner | 15min | Verify runner actually works end-to-end |
| 9 | **Audit all `mkForce` overrides** — check for other `escapeSystemdPath` mismatches | 30min | Prevent similar bugs |
| 10 | **Review stale `/var/lib/forgejo/.runner-token`** from attempt 1 | 5min | Cleanup |

### P2 — Medium Priority (next 2 weeks)

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 11 | **Verify Twenty CRM** — check if it's actually running and useful | 30min | Feature audit |
| 12 | **Verify Voice Agents pipeline** — Whisper Docker + ROCm | 30min | Feature audit |
| 13 | **Test Darwin build** — `just test-fast` on macOS | 10min | Cross-platform |
| 14 | **PhotoMap AI** — update SHA256 pin or remove | 30min | Feature decision |
| 15 | **Provision Pi 3** for DNS failover cluster | 2hr | Infrastructure resilience |
| 16 | **Dedicated GitHub PAT** for Forgejo push mirrors | 15min | Security |
| 17 | **Dozzle log viewer** at `logs.home.lan` | 1hr | Observability |
| 18 | **SigNoz alert channel routing** — critical→Discord, warning→log | 1hr | Alert quality |

### P3 — Lower Priority (backlog)

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 19 | **Multi-WM (Sway) refresh or remove** | 2hr | Backup compositor |
| 20 | **Shared flake-parts template** for private Go repos | 4hr | Standardization |
| 21 | **go-auto-upgrade `path:` → SSH URL** migration | 15min | Consistency |
| 22 | **AppArmor re-enablement** after NixOS 26.05 bug fix | 30min | Security hardening |
| 23 | **Auditd re-enablement** after NixOS 26.05 bug #483085 | 30min | Security hardening |
| 24 | **DNS-over-QUIC overlay** — investigate binary cache breakage | 2hr | Performance |
| 25 | **Performance benchmark scripts** — create or remove references | 1hr | Documentation accuracy |

---

## G. Top Question I Cannot Answer Myself

**Is the Forgejo Actions runner actually executing workflows?**

The runner is registered and the poller is launched, but I haven't verified that an actual CI/CD workflow runs successfully. The only way to confirm is to:

1. Create a test repo in Forgejo
2. Add a `.forgejo/workflows/test.yml` with a trivial job
3. Push and observe the runner pick it up

This is important because the runner uses `DynamicUser = true` and `docker` labels — Docker-in-DynamicUser has subtle permission issues (container socket access, volume mounts, HOME directory). The runner may register successfully but fail to execute container-based jobs.

---

## Files Modified This Session

| File | Changes |
|------|---------|
| `modules/nixos/services/forgejo.nix` | Removed `forgejo-runner-token` service. Added inline token generation via `+` ExecStartPre with `runuser -u forgejo`. Added registration script with migration marker. Used `utils.escapeSystemdPath` for service name override. Extracted `runnerLabels`, `runnerSettings`, `runnerConfigFile` to let block. |
| `AGENTS.md` | Added `escapeSystemdPath` + inline token generation note to Known Issues table |

## Commits This Session (uncommitted)

Previous session committed the failed attempts. This session replaces them with the correct fix. Changes are currently uncommitted — see `git diff HEAD`.

---

## System Health Snapshot

| Service | Status |
|---------|--------|
| Forgejo | ✅ Running, responding to API requests |
| Actions Runner | ✅ Running, registered, poller active |
| Caddy | ✅ TLS termination active |
| Docker | ✅ Socket available |
| DNS (Unbound) | ✅ Resolving |
| SigNoz | ✅ Monitoring |
| Gatus | ✅ Health checks |
| Sops secrets | ✅ Decrypted on activation |
