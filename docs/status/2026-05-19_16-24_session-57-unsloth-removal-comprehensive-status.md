# Session 57 — Comprehensive Status Report

**Date:** 2026-05-19 16:24
**Focus:** Unsloth Studio removal, uncommitted work audit, system health assessment

---

## Executive Summary

The SystemNix monorepo is in **strong shape** — 112 Nix files, 36 service modules, 20 shell scripts, 72 lock nodes (down from 130). The unsloth-studio module was fully removed this session. However, **significant uncommitted work has accumulated** from multiple prior sessions, including a DNS resolver extraction, Forgejo migration leftovers (stale `gitea` references in DNS, Authelia, Homepage), and script formatting fixes. The biggest gap is the **Gitea → Forgejo migration is incomplete in user-facing configs**: DNS records, Authelia OIDC client ID, and Homepage dashboard still reference "gitea" instead of "forgejo".

---

## a) FULLY DONE ✅

| What | Details | Commit |
|------|---------|--------|
| Unsloth Studio removal | Removed `unslothStudio` option, all systemd services (setup + runtime), venv/pip/studio bindings, tmpfiles, `UNSLOTH_MODELS` env var. ai-stack.nix simplified from 272 → 82 lines | **This session** |
| ai-models.nix cleanup | Removed `unsloth` path, `UNSLOTH_MODELS` session variable, `unsloth` tmpfiles rule | **This session** |
| justfile ai-migrate | Removed unsloth migration block, updated comment | **This session** |
| Documentation cleanup | AGENTS.md, README.md, FEATURES.md, boot-performance-analysis.md, NIX-REVIEW.md — all unsloth references removed | **This session** |
| Forgejo code migration | Gitea → Forgejo module rename, sops secrets renamed, flake.nix serviceModules updated | `d3a7f3fb` |
| gogenfilter v3 migration | All 5 private repo overlays fixed for gogenfilter API changes, 13/13 build | `54bf3d90` |
| art-dupl fork → master migration | Migrated art-dupl from fork branch to upstream master | `df13983a` |
| Overlay fix (5 broken packages) | Fixed all 5 broken overlay packages after gogenfilter migration | `04f0d813` |
| DNS resolver extraction | Shared `platforms/common/dns-resolver.nix` module for evo-x2 + rpi3 | **Uncommitted** |
| rpi3-dns cleanup | Deduplicated unbound config using shared dns-resolver module | **Uncommitted** |
| USB diagnostic script | SanDisk Ultra Fit 128GB verification report | **Uncommitted** |
| Script formatting | shellcheck fixes for usb-diagnostic.sh, rename-sops-gitea-to-forgejo.sh | **Uncommitted** |
| NVMe health monitor | SSD health monitoring with desktop notifications | `5f55d56e` |
| Lockfile deduplication | 130 → 72 nodes (44.6% reduction) | Session 51 |
| nixpkgs follows chains | crush-config, treefmt-full-fluke, hermes-agent all follow top-level nixpkgs | Session 51 |
| Systemd hardening | 22/23 service modules with systemd services use `harden {}` | Ongoing |
| GPU defense in depth | OLLAMA_MAX_LOADED_MODELS=1, GPU_OVERHEAD=8GiB, per-service memory fractions | Session 41 |
| Dual-WAN ECMP+MPTCP | Active-active failover with route health monitoring | Sessions 35-38 |
| Niri DRM healthcheck + GPU recovery | Consecutive error detection, unbind/rebind, auto-reboot | Sessions 39-40 |

---

## b) PARTIALLY DONE 🔧

| What | Status | What's Left |
|------|--------|-------------|
| Forgejo migration | Module code migrated, sops secrets renamed | **Stale `gitea` references remain** in: DNS records (dns-blocker-config.nix:59), rpi3 DNS (default.nix:128), Authelia OIDC client_id (authelia.nix:198), Authelia callback URL (authelia.nix:201), Homepage dashboard (homepage.nix:116, :120). These need updating to `forgejo` or the services break post-migration. |
| DNS resolver sharing | Shared module created, rpi3 migrated | evo-x2 dns-blocker-config.nix still has duplicated settings — should import shared module too |
| ComfyUI | Module exists with full Docker config, disabled | Marked as removed in FEATURES.md but code still exists. Decision: keep module for potential re-enable, or delete entirely? |
| Voice agents | Enabled but Whisper Docker + ROCm pipeline may need verification | No end-to-end test done |
| Twenty CRM | Enabled in configuration.nix | Module exists but unclear if actively deployed/functional |
| Monitor365 | Enabled with collectors disabled | Runs but with heavy collector restrictions — effectively a skeleton deployment |

---

## c) NOT STARTED ⬜

| What | Priority | Estimated Effort |
|------|----------|-----------------|
| rpi3-dns hardware provisioning | Low | Physical — needs Pi 3 + USB SSD |
| sops key provisioning for Pi 3 | Low | 30 min after hardware ready |
| DNS failover VRRP testing | Low | Blocked on Pi 3 hardware |
| Auditd enablement | Low | Blocked on NixOS 26.05 bug #483085 |
| AppArmor profiles | Low | Commented out in security-hardening |
| Gatus monitoring for Voice agents | Low | Add endpoint to gatus-config.nix |
| OpenTelemetry instrumentation for Hermes | Low | Would need code changes in hermes-agent |
| Integration tests (nixosTests) | Medium | No automated NixOS VM tests exist |
| Cloud backup solution | Medium | Pricing research done (docs/research/), no decision made |
| Forgejo federation | Low | Guide exists (docs/), not enabled |

---

## d) TOTALLY FUCKED UP 💥

| What | Severity | Status |
|------|----------|--------|
| Stale `gitea` references after Forgejo migration | 🔴 HIGH | **Active bug** — Authelia OIDC client_id is `"gitea"` but Forgejo expects `"forgejo"`. Homepage health check hits `/api/v1/nodeinfo` via `gitea.home.lan` DNS. DNS records still create `gitea.home.lan` but not `forgejo.home.lan`. These WILL break if Forgejo doesn't respond to the old name. |
| Staged but uncommitted dns-resolver.nix | 🟡 MEDIUM | `platforms/common/dns-resolver.nix` is staged but not committed alongside the rpi3 changes that depend on it. Should be a single atomic commit. |
| 12+ files with uncommitted changes | 🟡 MEDIUM | Accumulated from multiple sessions — DNS extraction, Forgejo leftovers, script formatting, unsloth removal. Risk of losing work. |
| /data/unsloth/ 28GB on disk | 🟢 LOW | Directory still exists on evo-x2, consuming 28GB. Module removed but disk space not reclaimed. |

---

## e) WHAT WE SHOULD IMPROVE 🏗️

1. **Forgejo migration completion** — The Gitea→Forgejo migration is the #1 half-done task. All user-facing configs (DNS, Authelia, Homepage) still say "gitea". This is a ticking time bomb.
2. **Commit hygiene** — 12+ files with uncommitted changes spanning multiple sessions. Should commit after each logical unit of work.
3. **Dead code audit** — ComfyUI module (disabled), Voice agents (unverified), Twenty CRM (unclear status), Monitor365 (skeleton). Either verify they work or remove them.
4. **Integration testing** — Zero automated tests. `just test-fast` only checks syntax. No nixosTests, no service smoke tests.
5. **AGENTS.md accuracy** — Still references "Gitea" in several places (Caddy port table, architecture section). Should be updated to Forgejo.
6. **Flake.lock staleness** — Several private repo inputs may be behind upstream. Should run `just update` periodically.
7. **DNS resolver deduplication** — Shared module created but evo-x2 dns-blocker-config.nix doesn't use it yet.
8. **Sops secret centralization** — Authelia OIDC client_secret still bcrypt, Gitea admin password still plaintext, Twenty secrets outside central sops.nix.
9. **Monitoring gaps** — No Gatus endpoint for Voice agents, Hermes, or Manifest. These services could silently fail.
10. **Documentation accuracy** — Many docs/status/archive files contain outdated "gitea" references. Non-critical but messy.

---

## f) Top #25 Things We Should Get Done Next

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **Complete Forgejo migration** — update DNS records, Authelia OIDC, Homepage dashboard from "gitea" to "forgejo" | 🔴 Critical | 30 min | Bug fix |
| 2 | **Commit all accumulated changes** — 12+ files uncommitted | 🔴 Critical | 5 min | Hygiene |
| 3 | **Verify Forgejo + Authelia OIDC flow works end-to-end** | 🔴 High | 15 min | Verification |
| 4 | **Reclaim /data/unsloth/ 28GB** on evo-x2 disk | 🟡 Medium | 5 min | Cleanup |
| 5 | **Deduplicate evo-x2 dns-blocker-config.nix** with shared dns-resolver module | 🟡 Medium | 20 min | Code quality |
| 6 | **Update AGENTS.md** — rename all "Gitea" references to "Forgejo", update service module list | 🟡 Medium | 15 min | Docs |
| 7 | **Verify Voice agents** end-to-end (Whisper + LiveKit + ROCm) | 🟡 Medium | 30 min | Verification |
| 8 | **Verify Twenty CRM** is functional or document why it's not | 🟡 Medium | 15 min | Verification |
| 9 | **Add Gatus endpoints** for Voice agents, Hermes, Manifest | 🟡 Medium | 15 min | Monitoring |
| 10 | **Move Authelia OIDC client_secret from bcrypt to sops** | 🟡 Medium | 20 min | Security |
| 11 | **Move Gitea/Forgejo admin password to sops** | 🟡 Medium | 10 min | Security |
| 12 | **Audit and remove dead modules** (ComfyUI if confirmed unused, Multi-WM/Sway if bitrotted) | 🟡 Medium | 30 min | Cleanup |
| 13 | **Centralize Twenty secrets** in sops.nix | 🟢 Low | 15 min | Security |
| 14 | **Run `just update`** to refresh flake.lock with latest upstream | 🟢 Low | 10 min | Maintenance |
| 15 | **Add nixosTests** for critical services (Caddy, DNS, Forgejo) | 🟢 Low | 2h | Testing |
| 16 | **Implement cloud backup** (B2/R2 pricing research done) | 🟢 Low | 2h | Reliability |
| 17 | **Provision Pi 3 + USB SSD** for DNS failover cluster | 🟢 Low | Physical | Infrastructure |
| 18 | **Enable Forgejo federation** (guide exists) | 🟢 Low | 30 min | Feature |
| 19 | **Create Incus VM for AI workloads** — isolate Ollama, ComfyUI GPU bugs | 🟢 Low | 2h | Security |
| 20 | **Enable AppArmor profiles** for hardened services | 🟢 Low | 1h | Security |
| 21 | **Add Signoz dashboards** for GPU metrics, Niri health, service correlations | 🟢 Low | 1h | Observability |
| 22 | **Script health check runner** — one command to verify all services | 🟢 Low | 30 min | DX |
| 23 | **Clean archive docs** — update stale "gitea" references in docs/status/archive/ | 🟢 Low | 30 min | Docs |
| 24 | **Validate monitor365 value** — skeleton deployment, is it worth keeping? | 🟢 Low | 15 min | Audit |
| 25 | **Boot performance optimization** — implement remaining items from boot-performance-analysis.md | 🟢 Low | 1h | Performance |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Does the Forgejo instance actually respond to both `gitea.home.lan` AND `forgejo.home.lan` DNS names?**

The DNS records still create `gitea.home.lan` (not `forgejo.home.lan`). The Caddy reverse proxy was presumably updated during the Forgejo migration. If Caddy only accepts `forgejo.home.lan` but DNS only resolves `gitea.home.lan`, then:
- Homepage health checks (`gitea.home.lan`) would fail
- Authelia OIDC callbacks (`https://gitea.${domain}/user/oauth2/authelia/callback`) would fail
- Users can't reach the service

I cannot verify this without SSH access to evo-x2. This is the single most important thing to confirm before touching the DNS/Authelia/Homepage configs — the answer determines whether the migration is a quick rename or requires careful dual-name support.

---

## Metrics

| Metric | Value |
|--------|-------|
| Service modules | 36 |
| Total .nix files | 112 |
| Total lines of Nix | 14,896 |
| Shell scripts | 20 |
| Flake lock nodes | 72 (was 130) |
| Services with `harden {}` | 22/23 (96%) |
| Gatus monitored endpoints | 26+ |
| Uncommitted files | 12+ |
| Commit distance from HEAD | 20 commits |
| System state version | 25.11 |

---

## Files Changed This Session

| File | Change |
|------|--------|
| `modules/nixos/services/ai-stack.nix` | Removed unsloth-studio: 272 → 82 lines (-190) |
| `modules/nixos/services/ai-models.nix` | Removed unsloth path, UNSLOTH_MODELS env var |
| `justfile` | Removed unsloth migration from ai-migrate |
| `AGENTS.md` | Removed unsloth directory tree, service references, migration docs |
| `README.md` | Removed "Unsloth Studio" from AI/ML tech stack |
| `FEATURES.md` | Removed Unsloth Studio rows (AI table + risk table + DNS records) |
| `docs/boot-performance-analysis.md` | Removed unsloth-setup from network-online table |
| `docs/NIX-REVIEW.md` | Removed Unsloth Studio from domain expertise list |

## Uncommitted Work (From Prior Sessions)

| File | Change | Session |
|------|--------|---------|
| `platforms/common/dns-resolver.nix` | NEW — shared DNS resolver profile | Session 52 |
| `platforms/nixos/rpi3/default.nix` | Deduplicate unbound config using shared module | Session 52 |
| `platforms/nixos/system/networking.nix` | DNS resolver changes | Session 52 |
| `scripts/usb-diagnostic.sh` | Shellcheck formatting fixes | Session 52 |
| `scripts/rename-sops-gitea-to-forgejo.sh` | Shellcheck formatting fixes | Session 52 |

---

_Arte in Aeternum_
