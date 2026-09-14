# SystemNix — Comprehensive Status Report

**Date:** 2026-05-05 23:30 CEST
**Session:** 34 — Brutal Self-Review + Execution Sprint
**Branch:** master (`62d9fa8`, pushed to origin)
**Build:** `just test-fast` — ALL CHECKS PASSED ✅
**Agent:** GLM-5.1 via Crush

---

## Executive Summary

Session 34 was a **READ → UNDERSTAND → RESEARCH → REFLECT → EXECUTE** session. Read all prior status reports (sessions 28–33), performed a brutal 11-question self-review, identified the **#1 most dangerous pattern** (port split-brain between caddy and service modules), then executed 7 atomic commits fixing it along with other cleanup.

**7 commits produced this session**, all pushed to master. Combined with session 33's deploy, the system now has:

- **Zero hardcoded port numbers in caddy.nix** (was 8)
- **8/30 modules using `serviceDefaults{}`** (was 5/30)
- **`primaryUser` used in tmpfiles/activation scripts** (was hardcoded `"lars"`)
- **Dead code removed** (redundant `colorScheme` config, duplicate `extraGroups`)
- **AGENTS.md fully updated**

**Overall Health:** 🟢 Build clean, all 31 service modules evaluate, caddy port split-brain eliminated, zero hardcoded ports in caddy. **Deploy pending** — sessions 29–34 changes not yet activated on evo-x2.

---

## a) FULLY DONE ✅

### Session 34 — This Session (7 Commits)

|| # | Commit | What | Impact |
||---|--------|------|--------|
|| 1 | `1d7ec93` | Remove redundant `colorScheme` config assignment in configuration.nix | Cleanup — default already provides it |
|| 2 | `fddec05` | Use `primaryUser` in tmpfiles rules and activation scripts | DRY — no more hardcoded `"lars"` in those paths |
|| 3 | `9cd0a0a` | Remove redundant `extraGroups` from default.nix and voice-agents.nix | DRY — `docker`/`render`/`video` already in configuration.nix |
|| 4 | `faa189f` | Add `port` options to photomap, twenty, authelia modules | Foundation for port dedup |
|| 5 | **`d039c9e`** | **Eliminate caddy port split-brain** — reference `config.services.*.port` | **CRITICAL — eliminates silent-failure risk** |
|| 6 | `033e560` | Migrate twenty, gitea-repos, ai-stack to `serviceDefaults{}` | Consistency — 5→8 modules |
|| 7 | `62d9fa8` | Update AGENTS.md with session 34 changes | Documentation accuracy |

### Session 33 — Deploy + Fixes (by parallel session)

|| Item | Status |
||------|--------|
|| Caddy CapabilityBoundingSet fix | ✅ Deployed (gen 276) |
|| ComfyUI Python deps installed | ✅ Service starts |
|| Photomap container image pulled | ✅ 2.5 GB image available |
|| Nix GC run | ✅ 3.8 GiB freed |
|| All critical services verified running | ✅ Caddy, Ollama, Immich, Authelia, Hermes, SigNoz, etc. |

### Session 30 — Manifest LLM Router (by parallel session)

|| Item | Status |
||------|--------|
|| Manifest NixOS module (207 lines) | ✅ Committed |
|| Caddy vhost + DNS entry | ✅ Committed |
|| Sops secret template | ✅ Committed |
|| Justfile recipes (4) | ✅ Committed |

### Session 31 — Justfile Overhaul (by parallel session)

|| Item | Status |
||------|--------|
|| Justfile radical rewrite | ✅ 1658→582 lines, 143→59 recipes |
|| Stale reference fixes (README, contributing, health-check) | ✅ Committed |

### Session 29 — Architecture Cleanup (previous session)

|| Item | Status |
||------|--------|
|| primaryUser module (15 hardcoded `"lars"` eliminated) | ✅ Committed |
|| Dead code removal (gatus 406 lines, nix-visualize, lib/default.nix) | ✅ Committed |
|| Darwin compatibility fixes (taskwarrior, nix-settings) | ✅ Committed |
|| Service hardening (harden{} to ai-stack, disk-monitor) | ✅ Committed |

### Evergreen — Verified Complete Across All Sessions

|| Category | Status | Details |
||----------|--------|---------|
|| Cross-platform flake | ✅ | macOS (aarch64-darwin) + NixOS (x86_64-linux), ~80% shared |
|| flake-parts architecture | ✅ | 31 service modules imported in flake.nix |
|| Crash recovery stack | ✅ | 6-layer defense-in-depth (SysRq, kernel panic, watchdogd, GPU recovery) |
|| DNS blocking | ✅ | Unbound + dnsblockd, 25 blocklists, 2.5M+ domains |
|| Service hardening | ✅ | `harden()` adopted in 18 service modules |
|| Shared lib/ helpers | ✅ | `lib/systemd.nix`, `lib/systemd/service-defaults.nix`, `lib/types.nix`, `lib/rocm.nix` |
|| Wallpaper self-healing | ✅ | awww-daemon + PartOf restart propagation |
|| EMEET PIXY webcam | ✅ | Auto-activation, face tracking, privacy mode |
|| Hermes AI gateway | ✅ | System service, sops secrets, 24G MemoryMax |
|| Taskwarrior sync | ✅ | TaskChampion server, zero-setup deterministic client IDs |
|| Niri session save/restore | ✅ | 60s timer, workspace-aware, crash recovery |
|| Theme | ✅ | Catppuccin Mocha everywhere |
|| Pre-commit hooks | ✅ | gitleaks + deadnix + statix + alejandra + nix flake check |
|| Port deduplication | ✅ | **NEW** — caddy references all 9 service ports via config |

---

## b) PARTIALLY DONE ⚠️

|| # | Item | What's Done | What's Missing |
||---|------|-------------|----------------|
|| 1 | **Deploy to evo-x2** | Session 28 + caddy fix deployed (gen 276) | Sessions 29–34 (28+ commits) NOT activated. Machine runs session 28 config. |
|| 2 | **Manifest deployment** | Module written, validated, wired | `platforms/nixos/secrets/manifest.yaml` doesn't exist — must create with sops on evo-x2 |
|| 3 | **serviceDefaults adoption** | 8/30 modules (27%) | 10 modules still manually inline `Restart =` (6 use `mkForce` — need priority fix) |
|| 4 | **primaryUser adoption** | 12 service modules + tmpfiles/activation | 2 remaining in `ssh-config.nix` (different module pattern) |
|| 5 | **Catppuccin color centralization** | zellij, starship, fzf, tmux use `colorScheme.palette` | waybar (32 hex), rofi (15), yazi (73) — **120 hardcoded colors** |
|| 6 | **Disk cleanup** | Nix GC ran (3.8 GiB freed) | Root still at 89%. Whisper Docker image 37.5 GB. 571 system generations. |
|| 7 | **lib/types.nix adoption** | 4 helpers defined | Only hermes.nix uses it — should adopt broadly or inline |
|| 8 | **Docker image pinning** | All images specified | Twenty, Manifest, Whisper, Redis use `:latest` — not reproducible |

---

## c) NOT STARTED ❌

|| # | Item | Priority | Effort | Blocker |
||---|------|----------|--------|---------|
|| 1 | **Create `manifest.yaml` sops secrets** | P0 | 5 min | Must run on evo-x2 |
|| 2 | **Deploy sessions 29–34 to evo-x2** | P0 | 10 min | Must run on evo-x2 |
|| 3 | **Delete old system generations** (571→3) | P0 | 5 min | Must run as root |
|| 4 | **Docker system prune -af** | P0 | 5 min | Must run on evo-x2 |
|| 5 | **Fix `harden()` priority model** | P1 | 30 min | Architectural decision needed |
|| 6 | **Fix podman config permissions** | P1 | 20 min | None |
|| 7 | **Pin Docker images to SHA256** | P1 | 15 min | None |
|| 8 | **Move VRRP password to sops** | P1 | 10 min | None |
|| 9 | **Migrate 6 mkForce modules to serviceDefaults** | P1 | 20 min | Depends on priority fix |
|| 10 | **Extract Catppuccin colors to `lib/catppuccin.nix`** | P2 | 30 min | None |
|| 11 | **Split signoz.nix** (746 lines) into sub-modules | P2 | 45 min | None |
|| 12 | **Create FEATURES.md** | P2 | 30 min | None |
|| 13 | **Create TODO_LIST.md** | P2 | 30 min | None |
|| 14 | **Fix 21 files with stale justfile refs** | P2 | 30 min | None |
|| 15 | **Archive 2025 planning docs** (23 files) | P2 | 10 min | None |
|| 16 | **Add post-deploy health check to justfile** | P2 | 15 min | None |
|| 17 | **Whisper image: pin or rebuild smaller** | P2 | 20 min | None |
|| 18 | **Update SigNoz versions** | P2 | 30 min | None |
|| 19 | **Adopt lib/types.nix broadly** or inline | P2 | 20 min | None |
|| 20 | **Provision Pi 3 hardware** for DNS failover | P3 | 2 hr+ | Hardware |
|| 21 | **Enable AppArmor** | P3 | 30 min | None |
|| 22 | **Add ComfyUI pip check to ExecCondition** | P3 | 10 min | None |
|| 23 | **Wrap ComfyUI in Nix derivation** | P3 | 4 hr | None |
|| 24 | **LUKS disk encryption + TPM** | P4 | 60 min | Planning |
|| 25 | **CI/CD pipeline** for `just test` | P4 | 60 min | GitHub |

---

## d) TOTALLY FUCKED UP 💥

### Issues Found and Fixed This Session

|| # | What | How Bad | Root Cause | Fixed By |
||---|------|---------|-----------|----------|
|| 1 | **8 hardcoded ports in caddy.nix** | CRITICAL — port change in any module would silently break reverse proxy | No shared port reference between modules | `d039c9e` — caddy now uses `config.services.*.port` |
|| 2 | **Redundant `colorScheme` assignment** | LOW — dead config line | Default already provides it | `1d7ec93` — removed |
|| 3 | **Hardcoded `"lars"` in tmpfiles/activation** | MED — primaryUser not fully adopted | Missed during session 29 | `fddec05` — now uses `config.users.primaryUser` |
|| 4 | **Duplicate `extraGroups`** across 3 files | MED — `docker` duplicated, scattered group assignments | Decentralized user management | `9cd0a0a` — removed duplicates |

### Carried Forward (Multi-Session Issues)

|| # | What | How Bad | Status |
||---|------|---------|--------|
|| 5 | **28+ commits undeployed** | 🔴 CRITICAL — sessions 29–34 committed but NOT active on evo-x2 | Not deployed |
|| 6 | **Root disk at 89%** | 🔴 CRITICAL — 55 GiB free, worsening despite GC | Needs root cleanup |
|| 7 | **Manifest blocked on sops** | 🟡 HIGH — `manifest.yaml` doesn't exist | Needs evo-x2 |
|| 8 | **`harden()` priority model ineffective** for some services | 🟡 MEDIUM — `mkDefault` (priority 1000) loses to NixOS module defaults (priority 100) | Architectural fix needed |
|| 9 | **Whisper Docker image 37.5 GB** | 🟡 MEDIUM — single largest disk consumer | Not addressed |
|| 10 | **service-health-check spam** | 🟡 HIGH — fails every 15 min, cascading from photomap | Will self-fix after deploy |
|| 11 | **120 hardcoded Catppuccin hex colors** | 🟢 LOW — works but not DRY | Not done |
|| 12 | **571 system generations** | 🟡 MEDIUM — massive Nix store waste | Needs root to clean |

---

## e) WHAT WE SHOULD IMPROVE 📈

### Architecture

1. **Deploy discipline is the #1 process failure.** 5+ sessions of committed code sit undeployed. Rule: every session that changes services MUST end with `just switch`.

2. **`harden()` priority model needs rethinking.** `mkDefault` (priority 1000) silently loses to NixOS module defaults (priority 100). Options: (a) add `priority` parameter, (b) switch to `mkOverride 200`, (c) use `mkForce` for services we fully control. This affects 16 services.

3. **signoz.nix at 746 lines** — split into `signoz/query-service`, `signoz/otel-collector`, `signoz/clickhouse`, `signoz/exporters`.

4. **Catppuccin color centralization** — 120 hardcoded hex values across waybar/rofi/yazi should use `lib/catppuccin.nix` derived from `colorScheme.palette`.

5. **Docker image pinning** — `:latest` tags are not reproducible. Pin Twenty, Whisper, Manifest, Redis to SHA256 digests.

6. **ComfyUI venv is fragile** — mutable venv outside Nix breaks on upstream dep changes. Wrap in Nix derivation or add `pip check` ExecCondition.

7. **Port registry** — now that caddy references module ports, consider a `lib/port-registry.nix` for cross-module port awareness (homepage dashboard links, SigNoz scrape targets still hardcode ports).

### Process

8. **Act on disk warnings** — 4 status reports flagged 84→89% disk usage. Nobody ran the cleanup commands until session 33, and even that only freed 3.8 GiB.

9. **Post-deploy verification** — add `just deploy-check` recipe that runs `systemctl --failed`, checks critical services, verifies DNS resolution.

10. **Stale docs cleanup** — 21 files with stale justfile references from the session 31 rewrite.

---

## f) TOP 25 THINGS TO DO NEXT

### Tier 1: Deploy & Fix What's Broken (P0)

|| # | Task | Effort | Impact | Blocked? |
||---|------|--------|--------|----------|
|| 1 | **Create `manifest.yaml` sops secrets** on evo-x2 | 5 min | Unblocks Manifest | Needs evo-x2 |
|| 2 | **Deploy to evo-x2** (`just switch`) — 5 sessions of changes | 10 min | Activates ALL work | Needs evo-x2 |
|| 3 | **Delete old system generations** (571→3) | 5 min | Massive Nix store savings | Needs root |
|| 4 | **Root disk deep cleanup** — `docker system prune -af` | 5 min | Prevents disk-full | Needs evo-x2 |

### Tier 2: High Impact Fixes (P1)

|| # | Task | Effort | Impact | Blocked? |
||---|------|--------|--------|----------|
|| 5 | **Fix `harden()` priority model** — add priority parameter or switch to mkOverride 200 | 30 min | Makes hardening actually effective | Decision needed |
|| 6 | **Fix podman config permissions** | 20 min | Re-enables photomap | No |
|| 7 | **Verify service-health-check passes** after deploy | 5 min | Stops notification spam | Post deploy |
|| 8 | **Pin Docker images to SHA256** | 15 min | Reproducible deploys | No |
|| 9 | **Move VRRP password to sops** | 10 min | Security fix | No |
|| 10 | **Migrate remaining mkForce modules to serviceDefaults** | 20 min | DRY compliance | Depends on #5 |

### Tier 3: Architecture Improvements (P2)

|| # | Task | Effort | Impact | Blocked? |
||---|------|--------|--------|----------|
|| 11 | **Extract Catppuccin colors to `lib/catppuccin.nix`** | 30 min | 120 values → 1 source | No |
|| 12 | **Split signoz.nix** into sub-modules | 45 min | 746 lines → manageable | No |
|| 13 | **Add post-deploy health check** to justfile | 15 min | Catch failures immediately | No |
|| 14 | **Whisper image: pin to digest or rebuild** | 20 min | 37.5 GB monster | No |
|| 15 | **Update SigNoz versions** | 30 min | Security + features | No |
|| 16 | **Create FEATURES.md** from code audit | 30 min | Project documentation | No |
|| 17 | **Create TODO_LIST.md** verified against code | 30 min | Project tracking | No |
|| 18 | **Fix 21 files with stale justfile refs** | 30 min | Doc accuracy | No |
|| 19 | **Archive 2025 planning docs** | 10 min | Reduce noise | No |
|| 20 | **Adopt lib/types.nix broadly** or inline | 20 min | Reduce dead code | No |

### Tier 4: Lower Priority (P3–P4)

|| # | Task | Effort | Impact | Blocked? |
||---|------|--------|--------|----------|
|| 21 | **Provision Pi 3 hardware** for DNS failover | 2 hr+ | HA DNS | Hardware |
|| 22 | **Enable AppArmor** | 30 min | MAC security | None |
|| 23 | **Add ComfyUI pip check to ExecCondition** | 10 min | Early failure detection | No |
|| 24 | **Wrap ComfyUI in Nix derivation** | 4 hr | Eliminates dependency fragility | No |
|| 25 | **CI/CD pipeline** for `just test` | 60 min | Automated quality gate | GitHub |

---

## g) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**What's the right approach for the `harden()` priority model?**

The `harden()` function uses `lib.mkDefault` (priority 1000) for all parameters. This means any NixOS module that sets the same field at default priority (100) silently overrides our hardening. For Caddy we worked around it with `//` merge, but Ollama's `harden { NoNewPrivileges = false; }` is **completely ineffective** — the deployed config shows `true`.

Options:

1. **Add `priority` parameter** to `harden()` — callers choose `mkOverride 200` vs `mkForce`
2. **Switch default to `mkOverride 200`** — stronger than `mkDefault` but still overridable
3. **Use `mkForce` for all** — always wins, but callers can't override with `//` merge
4. **Accept the limitation** — only use `harden()` for custom services, use `mkForce` directly for NixOS-packaged services

This is an architectural decision affecting 16 services. I lean toward option 2 as the best balance.

---

## System Metrics

|| Metric | Value |
||--------|-------|
| Service modules | 31 (photomap disabled, manifest blocked on sops) |
| Harden adoption | 18 service modules use `harden()` |
| serviceDefaults adoption | 8/30 (27%) |
| Caddy hardcoded ports | 0 ✅ (was 8) |
| Custom packages | 9 |
| Platforms | 2 (macOS aarch64-darwin, NixOS x86_64-linux) |
| Total .nix files | 104 |
| Service module LOC | 5,362 |
| Largest module | signoz.nix (746 lines) |
| Justfile recipes | 59 (582 lines) |
| Status docs | 8 active, ~228 archived |
| Working tree | 2 untracked (cybersecurity-tools-evo-x2.md, twenty-FREELANCE-PROJECTS.md) |
| Pre-commit hooks | All passing |
| Deployed to evo-x2 | ❌ 5 sessions behind (session 28 + caddy fix active) |
| Root disk | 89% (55 GiB free) |
| Data disk | 76% (209 GiB free) |
| System generations | 571 |

## Session 34 Commit History

```
62d9fa8 docs(agents): update for session 30 — port dedup, serviceDefaults, primaryUser
033e560 refactor(services): migrate twenty, gitea-repos, ai-stack to serviceDefaults{}
d039c9e fix(caddy): eliminate port split-brain — reference service config ports
faa189f feat(services): add port options to photomap, twenty, authelia modules
9cd0a0a chore(services): remove redundant extraGroups — already in configuration.nix
fddec05 fix(config): use primaryUser in tmpfiles rules and activation scripts
1d7ec93 fix(config): remove redundant colorScheme assignment — default already provides it
```

## Timeline: Today's Sessions

|| Time | Session | Key Work |
||------|---------|----------|
|| 12:27 | 28 | Build fix chain, deploy, caddy fix, reliability hardening |
|| 12:30 | 28b | Waybar recovery, Gitea, health checks |
|| 12:32 | — | Comprehensive full system status |
|| 17:54 | 29 | Brutal self-review, architecture cleanup, dead code removal |
|| 20:37 | 30 | Manifest LLM router module |
|| 21:19 | 31 | Justfile radical rewrite (1658→582 lines) |
|| 21:34 | 32 | Full system status, photomap disable |
|| 23:31 | 33 | Deploy, GC, Caddy fix, ComfyUI deps, photomap image |
|| 23:30 | **34** | **This session: brutal self-review, port split-brain fix, serviceDefaults migration, AGENTS.md update** |

---

_Arte in Aeternum_
