# SystemNix Comprehensive Status Report

**Date:** 2026-04-23 07:33 | **Host:** evo-x2 (NixOS 26.05 / x86_64-linux)
**Working Tree:** DIRTY — 3 files modified (not yet committed)
**Branch:** master | **Sync:** ahead of origin (local changes not pushed)

---

## Executive Summary

System is **stable but has uncommitted work**. Two unrelated improvements in the working tree: Minecraft module parameterization and scheduled-tasks UID hardening. JetBrains IDEA package addition from earlier today is committed. Flake validates clean. Critical security items (disk encryption, boot editor, passwordless sudo) remain **unaddressed** for the 3rd consecutive report.

---

## Working Tree Changes (Uncommitted)

| File                                         | Change                                                                                                                  | Status               |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | -------------------- |
| `modules/nixos/services/minecraft.nix`       | Parameterized module options (port, jvmOpts, difficulty, maxPlayers, motd, viewDistance, simulationDistance, whitelist) | ✅ Ready to commit   |
| `platforms/nixos/system/scheduled-tasks.nix` | Replaced hardcoded UID 1000 with dynamic `config.users.users.${primaryUser}.uid`                                        | ✅ Ready to commit   |
| `platforms/common/packages/base.nix`         | Added `jetbrains.idea` (COMMITTED in `017005c`)                                                                         | ✅ Already committed |
| `platforms/common/core/nix-settings.nix`     | Added `"idea"` + `"idea-ultimate"` to allowUnfreePredicate (COMMITTED in `017005c`)                                     | ✅ Already committed |

---

## Recent Commits (Last 24h)

| Hash      | Message                                                                      |
| --------- | ---------------------------------------------------------------------------- |
| `0707c4d` | docs(status): comprehensive system status report (2026-04-23 06:07)          |
| `b5d4b42` | feat(unbound): enable DNS-over-QUIC (DoQ) via libngtcp2 + libnghttp3 overlay |
| `017005c` | chore(jetbrains): add JetBrains IDEA to Linux packages                       |

---

## Codebase Metrics

| Metric                 | Value                         |
| ---------------------- | ----------------------------- |
| Total `.nix` files     | 91                            |
| Total `.go` files      | 19                            |
| Nix lines of code      | 11,667                        |
| Go lines of code       | 7,744                         |
| **Total lines**        | **~19,411**                   |
| NixOS service modules  | 17                            |
| Common program modules | 16                            |
| Custom packages        | 9                             |
| Flake inputs           | 20                            |
| Justfile recipes       | ~150+                         |
| Status reports         | 238 (31 active, 207 archived) |

---

## A) FULLY DONE ✅

| Item                      | Details                                                              |
| ------------------------- | -------------------------------------------------------------------- |
| JetBrains IDEA package    | Added `jetbrains.idea` to `linuxUtilities`, unfree predicate updated |
| DNS-over-QUIC (DoQ)       | Unbound + libngtcp2 + libnghttp3 overlay (`b5d4b42`)                 |
| Niri session save/restore | 24/24 features implemented across 2 rounds                           |
| TODO list (2026-04-22)    | 27/30 complete (96%)                                                 |
| SSH config extraction     | Shared common module (`839f6dc`)                                     |
| Networking extraction     | Local network config module (`8d91214`)                              |
| MIME type associations    | Image/video for Helium browser (`f01a24b`)                           |
| Systemd hardening         | Watchdog, reliability, sandboxing across services (`2328de8`)        |
| Hermes system service     | Converted from user to system-level (`862c67b`)                      |
| AI stack module           | Proper NixOS module with conditional Unsloth (`61b90aa`)             |
| jscpd native package      | Code duplication detection tool packaged (`1acdfa0`)                 |
| EMEET PIXY refactor       | Removed htmx eval, moved toasts server-side (`285f427`)              |
| Monitor365 integration    | Local dev path + module enhancements (`81aa90e`)                     |
| Config cleanup            | App descriptions, temp file handling, encryption (`4a59df5`)         |
| Code formatting           | 56 files formatted via `nix fmt` (alejandra)                         |
| CI pipeline               | 5 jobs (flake check, darwin build, syntax, 2x Go tests)              |
| Pre-commit hooks          | 8 hooks (gitleaks, deadnix, statix, alejandra, etc.)                 |
| Flake checks              | statix, deadnix, nix-eval-darwin, nix-eval-nixos                     |

## B) PARTIALLY DONE ⚠️

| Item                 | Status                                                | What's Missing                     |
| -------------------- | ----------------------------------------------------- | ---------------------------------- |
| Minecraft module     | Options defined but **not yet committed**             | Needs `git add` + commit           |
| Scheduled tasks UID  | Fix written but **not yet committed**                 | Needs `git add` + commit           |
| SigNoz observability | Stack running but **JWT secret missing**              | Errors on every restart            |
| Hermes gateway       | Service running but **state is `{}`**                 | Discord bot unconfirmed working    |
| Taskwarrior sync     | Server running, **client unconfigured**               | Client ID not set, no device sync  |
| EMEET PIXY daemon    | Package built, **service down**                       | Needs manual restart               |
| DNS blocklist        | Unbound + dnsblockd running, **DoQ not yet deployed** | `just switch` needed               |
| Security hardening   | auditd config exists, **disabled**                    | Blocked by NixOS 26.05 bug #483085 |
| NPU driver           | Module loaded, **SVA bind failures**                  | `amdxdna` ret -19                  |

## C) NOT STARTED ❌

| Item                                      | Priority | Notes                                            |
| ----------------------------------------- | -------- | ------------------------------------------------ |
| **Disk encryption (LUKS)**                | CRITICAL | Root + /data are plain btrfs                     |
| **TPM2 setup**                            | CRITICAL | No measured boot                                 |
| **Boot editor lockdown**                  | HIGH     | One-line fix: `systemd-boot.editor = false`      |
| **Passwordless sudo removal**             | HIGH     | `wheelNeedsPassword = false` persists            |
| **fwupd firmware updates**                | MEDIUM   | Not enabled                                      |
| Kernel sysctl hardening                   | MEDIUM   | No custom sysctl.conf                            |
| NixOS VM/integration tests                | LOW      | Zero automated tests                             |
| `passthru.tests` for custom packages      | LOW      | No package-level tests                           |
| Shell scripts → Nix apps migration        | LOW      | Deferred from TODO list                          |
| Niri fullscreen restore                   | LOW      | Blocked: niri IPC doesn't expose `is_fullscreen` |
| Session restore stats in waybar           | LOW      | Not started                                      |
| Integration test for session save/restore | LOW      | Not started                                      |
| Real-time save via event-stream           | LOW      | Not started                                      |
| ADR for session restore design            | LOW      | Not started                                      |
| AGENTS.md update                          | LOW      | Last updated 2026-04-04 (19 days behind)         |
| Status report archival/cleanup            | LOW      | 238 reports, growing unbounded                   |
| Gitea GitHub sync token                   | MEDIUM   | Token rejected, needs regeneration               |

## D) TOTALLY FUCKED UP 💥

| Item                             | Severity    | Details                                                                                                                                             |
| -------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **No disk encryption**           | 💀 CRITICAL | Physical access = full compromise. Has been flagged for 3+ reports with zero action.                                                                |
| **Hermes env delivery conflict** | HIGH        | `EnvironmentFile` AND `mergeEnvScript` both present from concurrent editing sessions. Design conflict unresolved — file has conflicting mechanisms. |
| **Gitea GitHub sync**            | MEDIUM      | Token rejected: "invalid username, password or token". Sync broken, needs sops secret regeneration.                                                 |
| **NPU (AMD XDNA)**               | LOW         | `amdxdna` SVA bind failures (ret -19). Hardware support is incomplete upstream.                                                                     |

## E) WHAT WE SHOULD IMPROVE 🔧

1. **Security posture is abysmal for a "production" machine** — No encryption, open boot editor, passwordless sudo. These are trivially exploitable and have been flagged repeatedly.
2. **Uncommitted work piles up** — Minecraft module + scheduled-tasks fix sitting in working tree. Should commit immediately.
3. **Hermes has conflicting config delivery** — Two mechanisms fighting each other. Needs a design decision.
4. **Gitea sync rotting** — Broken token means no GitHub mirror. Needs active intervention.
5. **Status report bloat** — 238 reports with no lifecycle management. Need archival policy.
6. **No automated testing** — Zero NixOS VM tests, zero `passthru.tests`. Every change is tested manually.
7. **AGENTS.md is stale** — 19 days behind, doesn't reflect recent changes (Minecraft parameterization, DoQ, etc.).
8. **Services unverified** — Minecraft, Twenty, Voice Agents modules exist but their runtime state is unconfirmed.
9. **Monitor365 disabled** — Module exists but `enable = false`. Dead code or intentional?
10. **Justfile has known bugs** — `session-status`, `dns-diagnostics`, `cam-logs` reported as having shell escaping issues.

## F) Top 25 Things We Should Get Done Next

### Critical (Do Immediately)

1. **Commit uncommitted work** — Minecraft module parameterization + scheduled-tasks UID fix
2. **`boot.loader.systemd-boot.editor = false`** — One-line security fix, zero risk
3. **Plan LUKS disk encryption** — At minimum, encrypt `/data` (contains Docker volumes, secrets)
4. **Fix Hermes env delivery conflict** — Remove `EnvironmentFile` or `mergeEnvScript`, not both
5. **`just switch`** — Deploy DoQ + unbound rebuild (new feature sitting undeployed)

### High (Do This Week)

6. **Enable passworded sudo** — `wheelNeedsPassword = true` with wheel group
7. **Regenerate Gitea GitHub sync token** — Fix mirror pipeline
8. **Restart EMEET PIXY daemon** — `systemctl --user restart emeet-pixyd`
9. **Fix SigNoz JWT secret** — Generate and configure via sops
10. **Enable fwupd** — `services.fwupd.enable = true` for firmware updates
11. **Configure Taskwarrior client** — Set client ID + encryption secret for sync
12. **Fix justfile shell escaping bugs** — `session-status`, `dns-diagnostics`, `cam-logs`

### Medium (Do This Month)

13. **Verify Minecraft module** — Test parameterized options after deploy
14. **Verify Twenty CRM module** — Confirm runtime state
15. **Verify Voice Agents module** — Confirm runtime state
16. **Update AGENTS.md** — Reflect all recent changes (Minecraft, DoQ, JetBrains, etc.)
17. **Add NixOS VM tests** — At minimum for service modules
18. **Implement status report lifecycle** — Auto-archive reports older than 30 days
19. **Resolve Monitor365 status** — Enable or remove dead module code
20. **Add kernel sysctl hardening** — Network, filesystem, memory protections

### Low (Do Eventually)

21. **Add `passthru.tests` for custom packages** — dnsblockd, emeet-pixyd, jscpd
22. **Migrate shell scripts to Nix apps** — Per deferred TODO item
23. **Write ADR for session restore design** — Document design decisions
24. **Niri fullscreen restore** — Track niri discussion #1843 for IPC support
25. **Session restore stats in waybar** — Visibility into save/restore health

## G) Top #1 Question I Cannot Answer Myself

**Why has disk encryption not been implemented despite being flagged as CRITICAL for 3+ consecutive status reports?**

This is the single most impactful security improvement possible. The machine has 128GB RAM and holds Docker volumes, sops secrets, Gitea repos, and personal data on unencrypted btrfs. The risk is clear: physical access (theft, lost laptop, disposal) = full data compromise including all sops-encrypted secrets (which are decrypted at runtime).

Possible blockers I cannot determine:

- Is there a migration path concern? (reinstall vs in-place)
- Is performance a worry? (btrfs + LUKS on NVMe should be negligible)
- Is TPM2 needed first for auto-unlock?
- Is there a plan to restructure partitions before encrypting?

**What is the actual blocker, and what would it take to unblock this?**

---

_This report was generated at 2026-04-23 07:33 by Crush AI assistant._
