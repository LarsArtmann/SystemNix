# FULL SYSTEM STATUS — 2026-04-24 23:02

**Scope:** Complete pkgs/ README review + comprehensive project audit
**Session focus:** pkgs/ documentation accuracy, README cleanup, AGENTS.md updates

---

## A) FULLY DONE

| #   | What                                                                                                                                       | Files Changed                        |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------ |
| 1   | **Rewrote `pkgs/README.md`** — was entirely about deleted `crush-patched.nix`, now documents all 8 actual packages                         | `pkgs/README.md`                     |
| 2   | **Rewrote `pkgs/emeet-pixyd/README.md`** — was placeholder "A Go project" boilerplate, now has commands, architecture, config table        | `pkgs/emeet-pixyd/README.md`         |
| 3   | **Rewrote `pkgs/dnsblockd-processor/README.md`** — was placeholder boilerplate, now has usage, input formats, output examples              | `pkgs/dnsblockd-processor/README.md` |
| 4   | **Updated root `README.md`** — `pkgs/` tree line now lists key packages                                                                    | `README.md:56`                       |
| 5   | **Updated `AGENTS.md`** — added jscpd, monitor365, openaudible to pkgs tree; fixed overlays table from "Three" to "Eight" with all entries | `AGENTS.md`                          |

---

## B) PARTIALLY DONE

| #   | What                                        | Status                                                                    | Remaining                                                                                                                                    |
| --- | ------------------------------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **MASTER TODO P0 tasks**                    | Stashes cleared (were already gone). Doc archiving done in prior session. | `git push` still not done (15+ docs recommend it). Remote branch cleanup (17 `copilot/fix-*` branches now deleted — only 3 branches remain). |
| 2   | **Go lint warnings in emeet-pixyd**         | 20 warnings identified, none are compilation errors.                      | Not fixed: `funlen` (Run=104 lines), `goconst` ("idle" 4×), `golines`, `mnd`, `perfsprint`, `embeddedstructfieldcheck`, `nlreturn`           |
| 3   | **Go lint warnings in dnsblockd-processor** | 2 warnings identified.                                                    | Not fixed: 2 unused `//nolint:gosec` directives                                                                                              |

---

## C) NOT STARTED

| #   | What                                                                                     | Priority    | Est. |
| --- | ---------------------------------------------------------------------------------------- | ----------- | ---- |
| 1   | Move Taskwarrior encryption secret to sops-nix (P1-#7)                                   | SECURITY    | 10m  |
| 2   | Add systemd hardening to `gitea-ensure-repos` (P1-#8)                                    | SECURITY    | 8m   |
| 3   | Pin Docker image digests for Voice Agents + PhotoMap (P1-#9,#10)                         | SECURITY    | 10m  |
| 4   | Secure VRRP auth_pass with sops-nix (P1-#11)                                             | SECURITY    | 8m   |
| 5   | Remove dead `ublock-filters.nix` (P1-#12)                                                | CLEANUP     | 5m   |
| 6   | Add WatchdogSec to 4 services (P2-#14)                                                   | RELIABILITY | 10m  |
| 7   | Add Restart=on-failure to 5 services (P2-#15)                                            | RELIABILITY | 8m   |
| 8   | Fix 3 dead let bindings (P2-#16)                                                         | CLEANUP     | 5m   |
| 9   | Fix pre-commit trailing-whitespace NixOS-only sed path                                   | CROSS-PLAT  | 3m   |
| 10  | Remove duplicate security-hardening.nix (old platforms/nixos/desktop/ copy)              | CLEANUP     | 2m   |
| 11  | Remove rogue root files (`download_glm_model.py`, `MIGRATION_TO_NIX_FLAKES_PROPOSAL.md`) | CLEANUP     | 2m   |
| 12  | `just switch` — deploy all pending changes to evo-x2 (P5-#41)                            | DEPLOY      | 45m+ |
| 13  | All P3-P9 tasks from MASTER TODO PLAN (69 remaining)                                     | QUALITY+    | ~14h |

---

## D) TOTALLY FUCKED UP / CRITICAL ISSUES

| #   | Issue                                          | Severity  | Detail                                                                                                                                       |
| --- | ---------------------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **`pkgs/README.md` was 100% wrong**            | CRITICAL  | Documented a deleted package (`crush-patched.nix`) that hasn't existed for weeks. Zero mention of the 8 actual packages. Fixed this session. |
| 2   | **Taskwarrior encryption secret in plaintext** | SECURITY  | `sha256("taskchampion-sync-encryption-systemnix")` is public in git. Anyone can decrypt synced tasks. Unfixed.                               |
| 3   | **Fail2ban configured in TWO places**          | CONFLICT  | Both `configuration.nix` and `security-hardening.nix` configure fail2ban — potential config conflict.                                        |
| 4   | **Security-hardening.nix duplicated**          | DEAD CODE | Identical file at `modules/nixos/services/` and `platforms/nixos/desktop/`. Old copy not imported anywhere.                                  |
| 5   | **Old desktop modules all still exist**        | DEAD CODE | 7 files in `platforms/nixos/desktop/` are commented out in config, superseded by flake-parts modules. Never cleaned up.                      |
| 6   | **Audit daemon disabled**                      | SECURITY  | 2 TODOs blocked on nixpkgs#483085. System running without audit logging.                                                                     |
| 7   | **`git push` never done**                      | RISK      | 15+ status docs recommend pushing. Local commits could be lost.                                                                              |

---

## E) WHAT WE SHOULD IMPROVE

1. **No CI exists** — zero GitHub Actions workflows actually running. The `.github/workflows/nix-check.yml` is referenced in README but may be stale.
2. **Documentation rot** — `pkgs/README.md` was completely wrong, subproject READMEs were boilerplate. Need periodic doc audits.
3. **Dead code accumulation** — old module locations kept alongside new flake-parts locations. Clean up after migrations.
4. **No `nixosTests`** — zero automated tests for any service. Critical services (Authelia, DNS, Caddy) have no test coverage.
5. **Overly verbose status docs** — MASTER TODO PLAN is 212 lines, this doc adds more. Should extract actionable items to Taskwarrior.
6. **Pre-commit cross-platform issue** — `trailing-whitespace` hook hardcodes `/run/current-system/sw/bin/sed` (NixOS-only).
7. **Docker images unpinned** — Voice Agents and PhotoMap use `:latest` tags. Silent breakage risk.
8. **Overlay count mismatch in AGENTS.md** — said "Three" for months, actually Eight. Docs drifted from reality.

---

## F) TOP 25 THINGS TO DO NEXT

| #   | Task                                                               | Priority | Est. |
| --- | ------------------------------------------------------------------ | -------- | ---- |
| 1   | `git push` — push all local commits to origin                      | P0       | 1m   |
| 2   | Move Taskwarrior encryption secret to sops-nix                     | P1       | 10m  |
| 3   | Add systemd hardening to `gitea-ensure-repos`                      | P1       | 8m   |
| 4   | Pin Docker image digests (Voice Agents + PhotoMap)                 | P1       | 10m  |
| 5   | Remove duplicate `platforms/nixos/desktop/security-hardening.nix`  | CLEANUP  | 2m   |
| 6   | Remove 7 dead desktop module files from `platforms/nixos/desktop/` | CLEANUP  | 5m   |
| 7   | Remove rogue root files (`download_glm_model.py`, migration doc)   | CLEANUP  | 2m   |
| 8   | Secure VRRP auth_pass with sops-nix                                | P1       | 8m   |
| 9   | Remove dead `ublock-filters.nix` module + import                   | P1       | 5m   |
| 10  | Add WatchdogSec to caddy, gitea, authelia, taskchampion            | P2       | 10m  |
| 11  | Add Restart=on-failure to 5 services                               | P2       | 8m   |
| 12  | Fix pre-commit trailing-whitespace sed path for macOS              | P2       | 3m   |
| 13  | Fix 3 dead let bindings (twenty, dns-blocker, aw-watcher)          | P2       | 5m   |
| 14  | Fix fail2ban dual-configuration conflict                           | P2       | 5m   |
| 15  | Fix `fonts.packages` darwin compatibility                          | P2       | 5m   |
| 16  | Fix deadnix unused params (4 batches, 23 files)                    | P3       | 40m  |
| 17  | Create shared `lib/systemd-harden.nix` helper                      | P4       | 12m  |
| 18  | `just switch` — deploy all changes to evo-x2                       | P5       | 45m+ |
| 19  | Verify Caddy HTTPS block page                                      | P5       | 3m   |
| 20  | Verify SigNoz metrics/logs/traces collection                       | P5       | 5m   |
| 21  | Add GitHub Actions CI for nix flake check + Go tests               | P7       | 20m  |
| 22  | Consolidate duplicate justfile recipes                             | P7       | 8m   |
| 23  | Fix 20 Go lint warnings in emeet-pixyd                             | P3       | 15m  |
| 24  | Fix 2 unused nolint directives in dnsblockd-processor              | P3       | 2m   |
| 25  | Document DNS cluster architecture in AGENTS.md                     | P8       | 8m   |

**Estimated total: ~4.5 hours**

---

## G) TOP QUESTION I CANNOT ANSWER

**Why is `monitor365` disabled (`enable = false`) in configuration.nix?**

It has a full NixOS module with 14 collectors, systemd hardening, ActivityWatch integration, Prometheus metrics — clearly significant effort went into it. Is it:

- Not ready for production yet?
- Blocked on a missing secret or remote endpoint?
- Replaced by something else (SigNoz node_exporter covers system metrics)?
- Intentionally off because the privacy-sensitive collectors need review?

This affects whether we should invest in improving it or remove it entirely.

---

## PROJECT STATS

| Metric                                 | Value                                          |
| -------------------------------------- | ---------------------------------------------- |
| NixOS service modules                  | 26                                             |
| Custom packages (pkgs/)                | 8                                              |
| Platforms                              | 2 (macOS + NixOS) + 1 Pi 3 DNS                 |
| Justfile recipes                       | ~90                                            |
| Open TODO items (MASTER TODO)          | 96 (~15h)                                      |
| Untracked files                        | 2 (rogue root files)                           |
| Git stashes                            | 0 (clean)                                      |
| Remote branches                        | 3 (master, feature/nushell, organize-packages) |
| Unpushed commits                       | ~15                                            |
| Go lint warnings (emeet-pixyd)         | 20 (0 errors)                                  |
| Go lint warnings (dnsblockd-processor) | 2 (0 errors)                                   |
| Duplicate/dead .nix files              | 8                                              |
