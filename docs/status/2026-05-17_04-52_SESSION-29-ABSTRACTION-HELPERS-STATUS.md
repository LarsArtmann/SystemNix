# SystemNix — Session 29 Status Report

**Date:** 2026-05-17 04:52
**Session Focus:** Continued deduplication + new abstraction helpers
**Build status:** `nix flake check` passes clean
**Branch:** master, pushed to origin

---

## A) FULLY DONE (6 commits)

| Commit | What | Impact |
|--------|------|--------|
| `7d2dd9b0` | Delete dead `lib/graphical-user-service.nix` | Removed 23-line dead code file, never used by any module |
| `5895d1fe` | Remove duplicate fail2ban from configuration.nix | Eliminated split-brain fail2ban config (was defined in both configuration.nix and security-hardening.nix) |
| `bcfc706a` | Document justfile hardcoded IP source | Added comment linking `evo_x2_ip` to `local-network.nix` |
| `696b57a6` | Migrate signoz 4 port options to serviceTypes.servicePort | -16 lines boilerplate, all signoz ports now use shared helper |
| `fd136612` | Add `mkStateDir` helper + migrate hermes + ai-models | New helper for tmpfiles rules, hermes 8→2 lines, ai-models 18→4 lines |
| `ae637581` | Update AGENTS.md | Removed deleted mkGraphicalUserService, added mkStateDir/onFailure/mkDockerServiceFactory |

---

## B) PARTIALLY DONE

### mkStateDir — adopted by 2/18 modules
- **Done:** hermes.nix (8 dirs), ai-models.nix (18 dirs)
- **Not done:** 16 other modules with tmpfiles could use it (openseo, manifest, signoz, immich, authelia, homepage, gitea, etc.)
- These can be migrated incrementally — no urgency, the old format still works fine.

### serviceTypes.servicePort — adopted by 16/20 port options
- **Done:** comfyui, voice-agents, taskchampion, twenty, photomap, manifest, openseo, minecraft, gatus-config, homepage, authelia, signoz (4 ports)
- **Not done:** immich (uses upstream module, port is plain value), monitor365 (5 ports), ai-stack (ollama hardcoded), voice-agents (LiveKit + port range)

---

## C) NOT STARTED

| Task | Effort |
|------|--------|
| Migrate remaining 16 modules to mkStateDir | 1-2 hrs |
| Add `.pre-commit-config.yaml` to repo root | 30 min |
| Extract SSH config IPs to shared module | 1 hr |
| Write basic nixosTests | 2 hrs |
| Refactor gitea.nix embedded scripts | 2 hrs |
| Simplify serviceModules list in flake.nix | 30 min |

---

## D) TOTALLY FUCKED UP

Nothing in this session. All 6 commits passed every pre-commit check (gitleaks, deadnix, statix, alejandra, nix flake check).

---

## E) WHAT WE SHOULD IMPROVE

1. **Incremental mkStateDir migration** — Don't do all 16 modules at once. Migrate 2-3 per session when touching a module for other reasons.
2. **monitor365 has 21 `mkEnableOption` calls** — Could use a `mkFeature desc default` helper in types.nix.
3. **flake.nix serviceModules list is verbose** — 35 entries × 2 lines each. Could use convention-based mapping.
4. **No pre-commit hooks in repo** — The global pre-commit config exists but `.pre-commit-config.yaml` is missing from the repo root.

---

## F) Top #10 Things We Should Get Done Next

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Add `.pre-commit-config.yaml` to repo root | 30 min | Prevents Nix quality regressions |
| 2 | Simplify serviceModules list (convention-based) | 30 min | Reduces flake.nix verbosity |
| 3 | Migrate homepage + photomap to mkDockerService | 30 min | Reduces Docker boilerplate |
| 4 | Migrate signoz tmpfiles to mkStateDir (5 instances) | 10 min | Consistency |
| 5 | Extract SSH config IPs to shared options module | 1 hr | Eliminates 6 hardcoded IPs |
| 6 | Write basic nixosTests for caddy + unbound | 2 hrs | Catches runtime breakage |
| 7 | Refactor gitea.nix embedded scripts | 2 hrs | 555→250 lines |
| 8 | Add `just bootstrap` for new machine setup | 2 hrs | Reproducible provisioning |
| 9 | Split configuration.nix into focused sub-modules | 2 hrs | Separation of concerns |
| 10 | Test rpi3-dns build | 20 min | Ensures alternate target works |

---

## G) Top #1 Question

**Same as session 28** — How to simplify the `serviceModules` list in flake.nix? Each entry requires `{path = ...; module = ...;}` because `default.nix` maps to `default-services`. A convention-based approach (file basename = module name, one special case) could cut flake.nix from 695 to ~620 lines.

---

## Metrics

| Metric | Session 28 | Session 29 | Delta |
|--------|-----------|-----------|-------|
| lib/ files | 7 | 6 | -1 (deleted graphical-user-service) |
| Dead code exports | 1 (mkGraphicalUserService) | 0 | -1 |
| Duplicate fail2ban configs | 2 | 1 | -1 |
| Manual port mkOption in signoz | 4 | 0 | -4 |
| tmpfiles using mkStateDir | 0 | 2 modules (26 dirs) | +2 |
| Commits this session | 0 | 6 | +6 |

All pushed to origin. Build clean. Working tree clean.
