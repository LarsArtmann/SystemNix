# SystemNix Master TODO — Prioritized Execution Plan

**Created:** 2026-05-11
**Source:** Sessions 67–70 status reports + improvement plan + nix standardization plan

---

## How to Read This

- **Every task** is ≤12 minutes
- Sorted by: Impact (🔴🟡🟢🔵) → Effort (min) → Dependencies
- `Dep` = must-complete-before dependency (task number)
- `File` = primary file to change
- `Status` = ⬜ not started, 🔄 in progress, ✅ done

---

## Phase 1: DEPLOY OR DIE (do first, blocks everything)

| # | Task | Impact | Min | Dep | File | Status |
|---|------|--------|-----|-----|------|--------|
| 1 | `git push` all 19 commits to origin | 🔴 | 2 | — | — | ⬜ |
| 2 | Run `just switch` to build + activate new config | 🔴 | 10 | — | — | ⬜ |
| 3 | Reboot (kernel 7.0.1→7.0.6 update) | 🔴 | 5 | 2 | — | ⬜ |
| 4 | Verify all services start clean: `systemctl --failed` | 🔴 | 3 | 3 | — | ⬜ |
| 5 | Check SigNoz provision logs for channel + rule creation | 🔴 | 5 | 4 | — | ⬜ |
| 6 | Test Discord channel via `POST /api/v1/channels/test` | 🔴 | 5 | 4 | — | ⬜ |
| 7 | Verify Gatus loaded config with webhook URL (check logs) | 🔴 | 3 | 4 | — | ⬜ |
| 8 | Verify Gatus endpoints all healthy at `status.home.lan` | 🔴 | 5 | 4 | — | ⬜ |

---

## Phase 2: MONITORING COMPLETENESS (high-value, short tasks)

| # | Task | Impact | Min | Dep | File | Status |
|---|------|--------|-----|-----|------|--------|
| 9 | Add SigNoz alert rule: Ollama down (`up{job="ollama"}` absent) | 🟡 | 8 | — | signoz.nix | ⬜ |
| 10 | Add SigNoz alert rule: Docker daemon down (`up{job="cadvisor"}` absent) | 🟡 | 8 | — | signoz.nix | ⬜ |
| 11 | Add Gatus DNS blocking test endpoint (blocked domain → block page) | 🟡 | 8 | — | gatus-config.nix | ⬜ |
| 12 | Add per-endpoint Gatus alert descriptions for critical services | 🟡 | 10 | — | gatus-config.nix | ⬜ |
| 13 | Create `hardenUser {}` in lib/ (subset: MemoryMax, NoNewPrivileges, RestrictNamespaces, LockPersonality) | 🟡 | 10 | — | lib/user-harden.nix | ⬜ |
| 14 | Export `hardenUser` from `lib/default.nix` | 🟡 | 2 | 13 | lib/default.nix | ⬜ |
| 15 | Apply `hardenUser {}` to monitor365 user service | 🟡 | 5 | 14 | monitor365.nix | ⬜ |
| 16 | Apply `hardenUser {}` to file-and-image-renamer user service | 🟡 | 5 | 14 | file-and-image-renamer.nix | ⬜ |
| 17 | Apply `hardenUser {}` to niri-drm-healthcheck user service | 🟡 | 5 | 14 | niri-config.nix | ⬜ |
| 18 | Replace Gatus sed hack: add sops template for full gatus.yaml | 🟡 | 10 | — | sops.nix | ⬜ |
| 19 | Replace Gatus ExecStartPre: point config at sops template output | 🟡 | 8 | 18 | gatus-config.nix | ⬜ |
| 20 | Remove `/run/gatus/` directory dance and `gnused` dependency | 🟡 | 3 | 19 | gatus-config.nix | ⬜ |
| 21 | Remove `serviceDefaults` from `disk-monitor.nix` if already has it (verify) | 🟡 | 5 | — | disk-monitor.nix | ⬜ |
| 22 | Harden ClickHouse: add `MemoryMax` and `harden {}` to systemd unit | 🟡 | 8 | — | signoz.nix | ⬜ |
| 23 | Add `onFailure` to amdgpu-metrics timer service | 🟡 | 3 | — | signoz.nix | ⬜ |

---

## Phase 3: FLAKE.NIX CLEANUP (reduce 850→600 lines)

| # | Task | Impact | Min | Dep | File | Status |
|---|------|--------|-----|-----|------|--------|
| 24 | Create `overlays/shared.nix` with 13 shared overlay functions | 🟢 | 10 | — | overlays/shared.nix | ⬜ |
| 25 | Create `overlays/linux.nix` with 6 Linux-only overlay functions | 🟢 | 8 | — | overlays/linux.nix | ⬜ |
| 26 | Create `overlays/default.nix` that imports both | 🟢 | 2 | 24, 25 | overlays/default.nix | ⬜ |
| 27 | Replace inline overlays in flake.nix with `imports = [ ./overlays ]` | 🟢 | 8 | 26 | flake.nix | ⬜ |
| 28 | Delete inline overlay definitions from flake.nix (~200 lines removed) | 🟢 | 5 | 27 | flake.nix | ⬜ |
| 29 | Run `just test-fast` to verify overlay extraction works | 🟢 | 5 | 28 | — | ⬜ |
| 30 | Run `nix fmt` on all new overlay files | 🟢 | 2 | 28 | overlays/*.nix | ⬜ |

---

## Phase 4: LIB/ CONSISTENCY & CLEANUP

| # | Task | Impact | Min | Dep | File | Status |
|---|------|--------|-----|-----|------|--------|
| 31 | Decide `systemdServiceIdentity` future: keep as-is, split, or remove | 🟢 | 10 | — | — | ⬜ |
| 32 | Remove unused `restartDelay`/`stopTimeout` from `lib/types.nix` (only hermes uses them) | 🟢 | 5 | 31 | lib/types.nix | ⬜ |
| 33 | Verify all modules already use `lib/default.nix` single import (audit) | 🟢 | 8 | — | modules/**/*.nix | ⬜ |
| 34 | Add `serviceTypes.servicePort` to voice-agents (replace hardcoded ports) | 🟢 | 8 | — | voice-agents.nix | ⬜ |
| 35 | Add `serviceTypes.servicePort` to signoz module option (replace hardcoded 8080) | 🟢 | 8 | — | signoz.nix | ⬜ |
| 36 | Add `serviceDefaults` to dns-failover keepalived service (if possible) | 🟢 | 5 | — | dns-failover.nix | ⬜ |

---

## Phase 5: SCRIPT QUALITY

| # | Task | Impact | Min | Dep | File | Status |
|---|------|--------|-----|-----|------|--------|
| 37 | Add `set -euo pipefail` to `gpu-recovery.sh` | 🟢 | 3 | — | scripts/gpu-recovery.sh | ⬜ |
| 38 | Add `set -euo pipefail` to `niri-drm-healthcheck.sh` | 🟢 | 3 | — | scripts/niri-drm-healthcheck.sh | ⬜ |
| 39 | Add `set -euo pipefail` to `niri-health.sh` | 🟢 | 3 | — | scripts/niri-health.sh | ⬜ |
| 40 | Parameterize PCI address in `gpu-recovery.sh` (auto-detect) | 🟢 | 8 | 37 | scripts/gpu-recovery.sh | ⬜ |
| 41 | Parameterize hostname in `nixos-diagnostic.sh` (remove hardcoded evo-x2) | 🟢 | 5 | — | scripts/nixos-diagnostic.sh | ⬜ |
| 42 | Add `just validate-scripts` recipe (shellcheck all scripts) | 🟢 | 8 | 37-41 | justfile | ⬜ |

---

## Phase 6: SIGNOZ V2 MIGRATION (optional, higher effort)

| # | Task | Impact | Min | Dep | File | Status |
|---|------|--------|-----|-----|------|--------|
| 43 | Research SigNoz v2 rules API (`POST /api/v2/rules`) schema differences | 🟢 | 10 | — | — | ⬜ |
| 44 | Migrate 1 rule to v2 schema as proof-of-concept | 🟢 | 10 | 43 | signoz.nix | ⬜ |
| 45 | Migrate remaining 10 rules to v2 schema | 🟢 | 10 | 44 | signoz.nix | ⬜ |
| 46 | Add per-threshold channel routing (critical→Discord, warning→log) | 🟢 | 10 | 44 | signoz.nix | ⬜ |
| 47 | Update provision script: `POST /api/v2/rules` endpoint | 🟢 | 5 | 44 | signoz.nix | ⬜ |
| 48 | Add SigNoz dashboard: GPU metrics (VRAM, temp, busy) | 🟢 | 10 | — | signoz.nix | ⬜ |
| 49 | Add SigNoz dashboard: DNS blocking (queries, blocks, latency) | 🟢 | 10 | — | signoz.nix | ⬜ |
| 50 | Add SigNoz dashboard: Docker containers (CPU, memory, network) | 🟢 | 10 | — | signoz.nix | ⬜ |
| 51 | Add SigNoz log-based alert: journald error spike detection | 🟢 | 10 | — | signoz.nix | ⬜ |

---

## Phase 7: SECURITY & SECRETS

| # | Task | Impact | Min | Dep | File | Status |
|---|------|--------|-----|-----|------|--------|
| 52 | Move `dns-failover.nix` plaintext `authPassword` to sops | 🟡 | 8 | — | sops.nix, dns-failover.nix | ⬜ |
| 53 | Add Gatus TLS certificate expiry check for `*.home.lan` certs | 🟢 | 8 | — | gatus-config.nix | ⬜ |
| 54 | Add Caddy metrics dashboard in SigNoz | 🟢 | 10 | — | signoz.nix | ⬜ |

---

## Phase 8: DOCUMENTATION

| # | Task | Impact | Min | Dep | File | Status |
|---|------|--------|-----|-----|------|--------|
| 55 | Create `TODO_LIST.md` from all planning docs (scan docs/planning/) | 🟢 | 10 | — | TODO_LIST.md | ⬜ |
| 56 | Create ADR: Discord notification architecture decision | 🟢 | 10 | — | docs/adr/ | ⬜ |
| 57 | Create ADR: Gatus secret injection approach | 🟢 | 10 | 18 | docs/adr/ | ⬜ |
| 58 | Archive docs/status/ sessions 45–62 to `docs/status/archive/` | 🔵 | 5 | — | docs/status/ | ⬜ |
| 59 | Consolidate AGENTS.md monitoring sections (GPU defense, alerting) | 🔵 | 10 | — | AGENTS.md | ⬜ |
| 60 | Update AGENTS.md with `hardenUser {}` pattern | 🔵 | 5 | 13 | AGENTS.md | ⬜ |
| 61 | Update AGENTS.md with overlay extraction structure | 🔵 | 5 | 27 | AGENTS.md | ⬜ |

---

## Phase 9: INFRASTRUCTURE (low priority, high effort)

| # | Task | Impact | Min | Dep | File | Status |
|---|------|--------|-----|-----|------|--------|
| 62 | Add `just test` recipe: full `nix build` validation (not just --no-build) | 🟢 | 10 | — | justfile | ⬜ |
| 63 | Integrate `test-home-manager.sh` into `just test` | 🟢 | 5 | 62 | justfile | ⬜ |
| 64 | Integrate `test-shell-aliases.sh` into `just test` | 🟢 | 5 | 62 | justfile | ⬜ |
| 65 | Add `mkGraphicalUserService` helper to `lib/` | 🟢 | 10 | — | lib/ | ⬜ |
| 66 | Consolidate voice-agents Caddy vHost into caddy.nix pattern | 🟢 | 8 | — | caddy.nix | ⬜ |
| 67 | Provision Pi 3 hardware for DNS failover cluster | 🔵 | — | — | — | ⬜ |
| 68 | Wire Pi 3 as secondary DNS in dns-failover.nix | 🔵 | 10 | 67 | dns-failover.nix | ⬜ |

---

## Summary

| Phase | Tasks | Total Min | Status |
|-------|-------|-----------|--------|
| 1. Deploy or Die | 8 | 38 | ⬜ All pending |
| 2. Monitoring Completeness | 15 | 113 | ⬜ All pending |
| 3. Flake.nix Cleanup | 7 | 50 | ⬜ All pending |
| 4. Lib/ Consistency | 6 | 44 | ⬜ All pending |
| 5. Script Quality | 6 | 30 | ⬜ All pending |
| 6. SigNoz v2 Migration | 9 | 85 | ⬜ All pending |
| 7. Security & Secrets | 3 | 26 | ⬜ All pending |
| 8. Documentation | 7 | 55 | ⬜ All pending |
| 9. Infrastructure | 7 | 48+ | ⬜ All pending |
| **TOTAL** | **68** | **~489** | **0% done** |

### Priority Execution Order

1. **Phase 1** (deploy) — unlocks verification of everything else
2. **Phase 2** tasks 9-12 (monitoring gaps) — high impact, no deps on deploy
3. **Phase 3** (overlay extraction) — reduces flake.nix by 200 lines
4. **Phase 5** (scripts) — quick safety wins
5. **Phase 2** tasks 13-23 (hardening + gatus fix)
6. **Phase 4** (lib consistency)
7. **Phases 6-9** in order of interest
