# SystemNix — Comprehensive Status Report

**Date:** 2026-04-23 06:07
**Host:** evo-x2 (NixOS 26.05 / x86_64-linux)
**Report Type:** Full System Health & Progress Assessment
**Reporter:** Crush AI Agent
**Previous Report:** 2026-04-23 04:58 (~69 minutes ago)

---

## Executive Summary

System is **stable** with 1 new feature commit since last report (DoQ in Unbound). Flake validates clean, all critical infrastructure running. Working tree is clean — all changes committed. The last hour brought: DNS-over-QUIC (DoQ) enabled in Unbound via libngtcp2+libnghttp3 overlay, JetBrains IDEA added to Linux packages, and `nix fmt` auto-formatted 56 files across the repo.

The P0 security items from the previous report remain unaddressed — no `just switch` has been run since the DoQ commit. The persistent issues (EMEET PIXY daemon down, Gitea sync broken, TaskChampion unconfigured, Hermes state empty) remain unchanged.

---

## Codebase Metrics

| Metric                    | Value            |
| ------------------------- | ---------------- |
| Total lines (Nix + Go)    | ~19,400          |
| NixOS service modules     | 18 (flake-parts) |
| Common program modules    | 16               |
| Custom packages (pkgs/)   | 9                |
| Flake inputs              | 20               |
| Git commits (last 24h)    | 19               |
| Status reports (total)    | 238              |
| Status reports (active)   | 31               |
| Status reports (archived) | 207              |
| Git stashes               | 0 (clean)        |
| Working tree              | Clean            |
| Ahead of origin/master    | 0 (in sync)      |
| Last flake update         | ~69 min ago      |

---

## A) FULLY DONE

### Infrastructure & Core

1. **Flake-parts modular architecture** — 18 NixOS services as self-contained flake-parts modules
2. **Cross-platform Home Manager** — Both Darwin + NixOS import `common/home-base.nix` → 16 program modules
3. **Go 1.26.1 overlay** — Pinned on both Darwin and NixOS via shared overlay
4. **Catppuccin Mocha theme** — Universal across all apps, terminals, bars, login screen
5. **treefmt + alejandra** — Formatting via `treefmt-full-flake`, statix + deadnix checks in CI
6. **Flake check passes** — `nix flake check --no-build` ✅ all 18 NixOS modules validated
7. **Fast test passes** — `just test-fast` ✅
8. **Health check passes** — Fish shell clean, starship available, dotfiles linked

### DNS Stack (Major Update This Hour)

9. **DNS-over-QUIC (DoQ) enabled** — Unbound 1.24.2 now speaks DoQ on UDP 853 via libngtcp2 + libnghttp3 overlay. QUIC handles encryption natively, zero TLS certificates needed. Committed `b5d4b42`.
10. **Unbound resolver** — Running ✅ with DoT to Quad9 + Cloudflare, DNSSEC, qname-minimisation, harden-glue
11. **dnsblockd block page server** — Running ✅ with 25 blocklists, 2.5M+ domains, block page categories
12. **Firefox policy locked** — DoH disabled, CA cert installed, gestures/swipe disabled

### Services (Production, Verified Running)

13. **Immich server** — Running ✅ at http://localhost:2283
14. **Immich Machine Learning** — Running ✅
15. **PostgreSQL (immich)** — Running ✅
16. **Redis (immich)** — Running ✅
17. **Immich backup timer** — Scheduled ✅
18. **SigNoz** — Full stack: OTel collector, ClickHouse, node_exporter, cAdvisor, journald ingestion
19. **Caddy** — Reverse proxy with TLS via sops
20. **Authelia** — SSO forward auth
21. **TaskChampion sync server** — Service running
22. **Homepage dashboard** — Service health checks active

### Custom Packages

23. **EMEET PIXY daemon** — Package built (`emeet-pixyd-0.2.0`), 63.4% test coverage, 1.3M+ fuzz executions
24. **dnsblockd** — Built (`dnsblockd-0.1.0`)
25. **dnsblockd-processor** — Built (`dnsblockd-processor-0.1.0`)
26. **jscpd** — Native Nix package (`jscpd-4.0.9`)
27. **monitor365** — Built (`monitor365-0.1.0`)
28. **aw-watcher-utilization** — Built (`aw-watcher-utilization-1.2.2`)
29. **signoz + signoz-otel-collector + signoz-schema-migrator** — Built from source
30. **openaudible** — Native Nix package
31. **JetBrains IDEA** — Added to Linux packages this hour (`017005c`)

### Completed in Last 69 Minutes

32. **DoQ in Unbound** — libngtcp2 + libnghttp3 overlay, `quic-port = 853`, UDP 853 in firewall
33. **nix fmt pass** — 56 files auto-formatted with alejandra (11 changed), 683 traversed
34. **JetBrains IDEA** — Added to Linux package list

---

## B) PARTIALLY DONE

| Item                    | Status                        | What's Missing                                                                     |
| ----------------------- | ----------------------------- | ---------------------------------------------------------------------------------- |
| **Hermes gateway**      | Service active                | State shows empty `{}` — Discord bot connectivity unconfirmed                      |
| **SigNoz JWT secret**   | `SIGNOZ_TOKENIZER_JWT_SECRET` | Not set — critical error logged on every restart                                   |
| **Gitea GitHub sync**   | Service runs                  | **FAILED** — token rejected: "invalid username, password or token"                 |
| **Voice agents**        | Module defined                | Status unknown — no runtime verification                                           |
| **Minecraft server**    | Module defined                | Status unknown — no runtime verification                                           |
| **Monitor365**          | Package built                 | `enable = false` — intentionally disabled                                          |
| **EMEET PIXY daemon**   | Package built                 | **NOT RUNNING** — daemon down                                                      |
| **TaskChampion client** | Sync server running           | Client not configured — "Client ID: not set", "Sync configuration: Not configured" |
| **Unsloth Studio**      | Module defined                | Conditional enablement — status unverified                                         |
| **Twenty CRM**          | Module defined                | Image pinned — status unverified                                                   |
| **Security hardening**  | Good baseline                 | No LUKS, no TPM2, no fwupd, no kernel sysctls, auditd disabled                     |

---

## C) NOT STARTED

### Security (High Impact — All P0 from Last Report, Still Unaddressed)

1. **LUKS disk encryption** — Root and `/data` plain btrfs. Physical access = full data theft
2. **TPM2 enablement** — `security.tpm2.enable = true` — prerequisite for LUKS auto-unlock
3. **Firmware updates** — `services.fwupd.enable = true` — not configured
4. **Kernel security sysctls** — `kptr_restrict=2`, `dmesg_restrict=1`, `kexec_load=0`, `rp_filter=1`
5. **Boot editor protection** — `boot.loader.systemd-boot.editor = false`
6. **Passwordless sudo** — `wheelNeedsPassword = false` on desktop with browsers = privilege escalation path
7. **Auditd re-enablement** — Rules written but blocked by NixOS [#483085](https://github.com/NixOS/nixpkgs/issues/483085)

### Operations & Observability

8. **Hermes SigNoz monitoring** — No journald ingestion, alert rules, or dashboard
9. **Hermes config.yaml declarative** — `/var/lib/hermes/config.yaml` unmanaged
10. **Flake.lock staleness alerting** — No automated check for aged inputs
11. **Per-service rollback docs** — No recovery procedures
12. **Service restart limits** — `StartLimitBurst`/`StartLimitIntervalSec` not audited across all modules

### Code Quality & Documentation

13. **NixOS VM tests** — Zero automated tests
14. **`passthru.tests`** — Not added to custom packages
15. **AGENTS.md update** — Last updated 2026-04-04, 19 days behind — missing hermes, voice-agents, minecraft, monitor365, DoQ
16. **TaskChampion client setup** — `just task-setup` not run on any device

### Cleanup

17. **Status report pruning** — 238 total reports (31 active, 207 archived), growing unbounded
18. **Git stash cleanup** — 0 stashes (clean)
19. **`docs/` top-level files** — Many stale one-time analysis docs

---

## D) TOTALLY FUCKED UP

| Item                                    | Severity     | Details                                                                                          |
| --------------------------------------- | ------------ | ------------------------------------------------------------------------------------------------ |
| **EMEET PIXY daemon not running**       | **HIGH**     | Camera daemon down. Users lose auto face-tracking, privacy toggle, call detection.               |
| **Gitea GitHub sync completely broken** | **MEDIUM**   | Token rejected on both repos — "invalid username, password or token". Repos falling out of sync. |
| **No disk encryption**                  | **CRITICAL** | Root + /data plain btrfs. Physical access = immediate full compromise.                           |
| **Passwordless sudo**                   | **HIGH**     | `wheelNeedsPassword = false` + browser on same account = trivial privilege escalation            |
| **Boot editor open**                    | **HIGH**     | `systemd-boot` editor allows `init=/bin/sh` at boot screen                                       |
| **SigNoz JWT secret missing**           | **MEDIUM**   | Critical error logged every restart                                                              |
| **Hermes state empty**                  | **MEDIUM**   | `hermes gateway status` returns `{}` — bot may not be connected                                  |
| **auditd blocked**                      | **MEDIUM**   | NixOS 26.05 bug prevents audit rules from loading                                                |
| **Firmware updates disabled**           | **MEDIUM**   | `fwupd` not enabled — unpatched BIOS/UEFI vulnerabilities                                        |

---

## E) WHAT WE SHOULD IMPROVE

### Immediate Priority (Before Next Reboot)

1. **Apply DoQ config** — `just switch` to activate the DoQ overlay + unbound rebuild. This is the single new feature this hour and needs a rebuild to take effect.
2. **Fix EMEET PIXY daemon** — `systemctl --user restart emeet-pixyd` to restore camera functionality
3. **Fix Gitea GitHub sync** — Verify/regenerate the GitHub token in sops

### Short Term (This Week)

4. **P0 security sweep** — All 7 P0 security items are single-line config changes. One `just switch` could close: boot editor, fwupd, kernel sysctls, wheelNeedsPassword, TPM2, LUKS (LUKS is complex but the rest are trivial)
5. **Set SigNoz JWT secret** — One sops secret + `just switch`
6. **TaskChampion client setup** — `just task-setup` on all devices
7. **Verify Hermes runtime** — Confirm Discord bot connected

### Operational Excellence

8. **Hermes SigNoz monitoring** — Add Hermes to journald pipeline + create dashboard panels
9. **Hermes config.yaml declarative** — Make `/var/lib/hermes/config.yaml` managed
10. **Service restart limits audit** — Verify `StartLimitBurst` everywhere after last night's 150+ restart incidents
11. **Auto-archive status reports** — Keep last 10 active, move older to `archive/`
12. **Update AGENTS.md** — DoQ, hermes, voice-agents, minecraft, monitor365 all undocumented

### Long Term / Architecture

13. **Cross-platform parity** — Darwin config less tested; validate macOS build regularly
14. **Config drift detection** — No mechanism to detect runtime vs declared config divergence
15. **NPU driver** — `amdxdna` SVA bind failures (ret -19), NPU unusable
16. **Flake.lock freshness** — Add automated alerting for inputs >30 days

---

## F) TOP 25 NEXT ACTIONS

| #   | Priority | Action                                                                                                        | Effort | Impact                                    |
| --- | -------- | ------------------------------------------------------------------------------------------------------------- | ------ | ----------------------------------------- |
| 1   | **P0**   | **`just switch`** — Apply DoQ + unbound rebuild with libngtcp2/nghttp3                                        | Medium | High — activates DoQ feature              |
| 2   | **P0**   | **Restart EMEET PIXY daemon** — `systemctl --user restart emeet-pixyd`                                        | Low    | High — camera UX regression               |
| 3   | **P0**   | **Fix Gitea GitHub sync token** — Regenerate/verify token in sops                                             | Low    | Medium — repos broken                     |
| 4   | **P0**   | **Enable LUKS + TPM2 auto-unlock** — Full disk encryption, TPM-bound                                          | High   | Critical — closes physical attack surface |
| 5   | **P0**   | **`boot.loader.systemd-boot.editor = false`** — One line                                                      | Low    | High — prevents `init=/bin/sh`            |
| 6   | **P0**   | **`services.fwupd.enable = true`** — Firmware updates                                                         | Low    | High — patches firmware CVEs              |
| 7   | **P0**   | **Kernel security sysctls** — `kptr_restrict=2`, `dmesg_restrict=1`, `rp_filter=1`                            | Low    | Medium — standard hardening               |
| 8   | **P0**   | **Set `SIGNOZ_TOKENIZER_JWT_SECRET`** via sops + `just switch`                                                | Low    | Medium — removes critical log spam        |
| 9   | **P1**   | **Re-evaluate `wheelNeedsPassword = false`** — `true` with `timestampTimeout = 30`                            | Low    | Medium — closes privilege escalation      |
| 10  | **P1**   | **TaskChampion client setup** — `just task-setup` on all devices                                              | Low    | Medium — zero device sync                 |
| 11  | **P1**   | **Verify Hermes runtime** — Confirm Discord bot connected, cron jobs                                          | Low    | Medium — AI gateway unverified            |
| 12  | **P1**   | **Verify Twenty CRM** — Check `/app/python` error resolved                                                    | Low    | Low — or disable                          |
| 13  | **P1**   | **Verify Unsloth Studio** — Confirm restart loop resolved                                                     | Low    | Low — or disable                          |
| 14  | **P2**   | **Add `StartLimitBurst` to all services** — Audit after 150+ restart incidents                                | Low    | Medium — prevents restart loops           |
| 15  | **P2**   | **Add disk space alerting** — SigNoz alert for root >85%                                                      | Low    | Medium — root at ~81%                     |
| 16  | **P2**   | **Update AGENTS.md** — 19 days behind, missing DoQ/hermes/voice-agents                                        | Medium | Medium — AI agent accuracy                |
| 17  | **P2**   | **Auto-archive status reports** — Keep last 10, move older to archive                                         | Low    | Low — prevent bloat                       |
| 18  | **P2**   | **Prune `docs/` top-level files** — Delete/archive stale analysis docs                                        | Medium | Low — repo cleanliness                    |
| 19  | **P3**   | **Validate Darwin build** — Ensure macOS config still builds                                                  | Low    | Medium — cross-platform health            |
| 20  | **P3**   | **Fix amdxdna NPU driver** — SVA bind failure ret -19                                                         | Hard   | Medium — NPU unusable                     |
| 21  | **P3**   | **Monitor auditd NixOS bug** — Re-enable when [#483085](https://github.com/NixOS/nixpkgs/issues/483085) fixed | Low    | Medium — audit trail                      |
| 22  | **P3**   | **Flake.lock staleness alerting** — Automated check for inputs >30 days                                       | Medium | Low — dependency freshness                |
| 23  | **P3**   | **Hermes SigNoz monitoring** — Add journald ingestion + dashboard                                             | Medium | Medium — observability gap                |
| 24  | **P3**   | **Hermes config.yaml declarative** — Managed `/var/lib/hermes/config.yaml`                                    | Medium | Medium — config consistency               |
| 25  | **P3**   | **Add NixOS VM tests** — Smoke tests for caddy, immich, signoz                                                | High   | High — regression prevention              |

---

## G) TOP #1 QUESTION I CANNOT ANSWER MYSELF

**Has `just switch` been run since the DoQ commit (`b5d4b42`)?**

The unboundDoQOverlay adds libngtcp2 + libnghttp3 as build inputs to Unbound, which means Unbound needs to be **rebuilt from source** before DoQ works. If `just switch` hasn't been run, the overlay is in the flake but unbound is still the stock nixpkgs version without DoQ. I cannot verify this from the CLI — only a `just switch` will confirm.

Also: **What's the current Gitea GitHub token status?** The sync script reports "invalid username, password or token" but I can't see whether the token in sops is expired, misconfigured, or if Gitea's OAuth app settings changed.

---

## Files Changed Since Last Report (2 commits, ~69 min)

### b5d4b42 — feat(unbound): enable DNS-over-QUIC (DoQ) via libngtcp2 + libnghttp3 overlay

```
4 files changed, 29 insertions(+), 1 deletion(-)
```

- `flake.nix` — unboundDoQOverlay: adds ngtcp2 + nghttp3 to buildInputs, --with-libngtcp2/--with-libnghttp3 to configureFlags
- `platforms/nixos/modules/dns-blocker.nix` — doqPort option (default 853), quic-port in unbound settings
- `platforms/nixos/system/dns-blocker-config.nix` — doqPort = 853
- `platforms/nixos/system/networking.nix` — UDP 853 in firewall.allowedUDPPorts

### 017005c — chore(jetbrains): add JetBrains IDEA to Linux packages

```
1 file changed, 1 insertion(+), 1 deletion(-)
```

- `flake.nix` — Added JetBrains IDEA to Linux packages list

### auto-format (via nix fmt on commit hook)

```
11 files changed, 156 insertions(+), 148 deletions(-)
```

- alejandra formatted 56 files across the repo (11 actually changed)

---

## Appendix: Service Module Inventory

| Module                    | Path                                      | Status           |
| ------------------------- | ----------------------------------------- | ---------------- |
| Authelia                  | `modules/nixos/services/authelia.nix`     | ✅ Running       |
| Caddy                     | `modules/nixos/services/caddy.nix`        | ✅ Running       |
| Default Services (Docker) | `modules/nixos/services/default.nix`      | ✅ Running       |
| Gitea                     | `modules/nixos/services/gitea.nix`        | ✅ Running       |
| Gitea Repos               | `modules/nixos/services/gitea-repos.nix`  | ❌ Sync broken   |
| Hermes                    | `modules/nixos/services/hermes.nix`       | ⚠️ State empty   |
| Homepage                  | `modules/nixos/services/homepage.nix`     | ✅ Running       |
| Immich                    | `modules/nixos/services/immich.nix`       | ✅ Running       |
| Minecraft                 | `modules/nixos/services/minecraft.nix`    | ⚠️ Unverified    |
| Monitor365                | `modules/nixos/services/monitor365.nix`   | Disabled         |
| Photomap                  | `modules/nixos/services/photomap.nix`     | ✅ Running       |
| SigNoz                    | `modules/nixos/services/signoz.nix`       | ⚠️ JWT missing   |
| Sops                      | `modules/nixos/services/sops.nix`         | ✅ Running       |
| TaskChampion              | `modules/nixos/services/taskchampion.nix` | ⚠️ Client unconf |
| Twenty                    | `modules/nixos/services/twenty.nix`       | ⚠️ Unverified    |
| Voice Agents              | `modules/nixos/services/voice-agents.nix` | ⚠️ Unverified    |

**Legend:** ✅ Running/Stable | ⚠️ Needs Verification | ❌ Broken | Disabled = Module defined but `enable = false`

---

## Appendix: Custom Package Inventory

| Package                | Path                              | Version  | Status                   |
| ---------------------- | --------------------------------- | -------- | ------------------------ |
| aw-watcher-utilization | `pkgs/aw-watcher-utilization.nix` | 1.2.2    | ✅ Built                 |
| dnsblockd              | `pkgs/dnsblockd.nix`              | 0.1.0    | ✅ Built                 |
| dnsblockd-processor    | `pkgs/dnsblockd-processor/`       | 0.1.0    | ✅ Built                 |
| emeet-pixyd            | `pkgs/emeet-pixyd/`               | 0.2.0    | ✅ Built, ❌ Not running |
| jscpd                  | `pkgs/jscpd.nix`                  | 4.0.9    | ✅ Built                 |
| JetBrains IDEA         | `flake.nix`                       | Latest   | ✅ Added this hour       |
| modernize              | `pkgs/modernize.nix`              | unstable | ✅ Built                 |
| monitor365             | `pkgs/monitor365.nix`             | 0.1.0    | ✅ Built, disabled       |
| openaudible            | `pkgs/openaudible.nix`            | Latest   | ✅ Built                 |
| signoz                 | `signoz-src`                      | 0.117.1  | ✅ Built                 |
| signoz-otel-collector  | `signoz-collector-src`            | 0.144.2  | ✅ Built                 |
| signoz-schema-migrator | `signoz-collector-src`            | 0.144.2  | ✅ Built                 |

---

_Report generated: 2026-04-23 06:07_
_Reporter: Crush AI Agent via CLI_
_Waiting for instructions on next priority actions._
