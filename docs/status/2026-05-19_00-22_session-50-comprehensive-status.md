# SystemNix — Session 50: Full Comprehensive Status Report

**Date:** 2026-05-19 00:22 CEST
**Machine:** evo-x2 (NixOS x86_64-linux) + Lars-MacBook-Air (macOS aarch64-darwin)
**Previous Report:** 2026-05-19_00-02 (Session 49 — Go shared lib lockfile dedup)
**Day Summary:** 2026-05-18_DAY_SUMMARY.md (Sessions 36–49, 14 sessions, 21 hours)

---

## System Metrics Snapshot

| Metric | Value |
|--------|-------|
| `.nix` files | 111 |
| Service modules | 35 total (32 enabled, 3 disabled) |
| Overlay packages | 17/17 building |
| Cross-platform programs | 14 |
| Shell scripts | 18 |
| Lock nodes | 73 (from 137 baseline, 47% reduction) |
| Root flake inputs | 47 |
| Sops secret files | 11 |
| Sops templates | 7 |
| Gatus endpoints | 27+ |
| Justfile recipes | ~50+ across 9 groups |
| TODO comments in .nix | 1 (Pi 3 provisioning) |
| FIXME/HACK/XXX | 0 |
| Status reports total | ~345+ (45 active, 300+ archived) |
| Status reports disk usage | 6.6 MB |
| FEATURES.md entries | ~140 enabled features |
| ADRs | 5 |

---

## a) FULLY DONE

### Infrastructure

| Item | Session | Details |
|------|---------|---------|
| Flake lockfile optimization | S46–49 | 137→73 nodes (47% reduction), ~17-28 GB evaluation RAM saved |
| nixpkgs follows | S46 | All inputs with nixpkgs dependency follow the root input |
| flake-parts follows | S46 | 8 inputs consolidated |
| flake-utils consolidation | S47 | 10 duplicate instances → 1 shared input |
| systems/treefmt-nix follows | S48 | Dedup across dnsblockd, library-policy, niri-session-manager, treefmt-full-flake |
| Go shared lib dedup | S49 | 6 libraries (go-output, go-finding, gogenfilter, go-branded-id, go-filewatcher, cmdguard) as top-level `flake = false` inputs with full follows chains |
| nix-colors removal | S47 | Inlined Catppuccin Mocha palette, removed dependency |
| aarch64-linux removal from perSystem | S46 | rpi3 has its own nixpkgs instantiation |
| Overlays extracted to `overlays/` | S73 | `default.nix`, `shared.nix`, `linux.nix` — clean separation |

### Build System

| Item | Session | Details |
|------|---------|---------|
| All 17 overlay packages building | S36–49 | 7 were broken at S36 start, all fixed |
| vendorHash cascade fix | S45 | Stale hashes across 7 Go repos updated |
| `mkPreparedSource` v2 | S38 | Per-dep `subModules` support, 5 repos migrated |
| `proxyVendor = true` standardization | S45 | All `_local_deps` repos use consistent pattern |
| Version string fix (0.0.0- prefix) | S39 | 5 Go repos, fixes `nh` closure diff parsing |
| modernize removal | S47/49 | gopls bundles modernize at Go 1.26.2 |

### Security

| Item | Session | Details |
|------|---------|---------|
| monitor365 sops migration | S43 | Plaintext authToken/jwtSecret → sops-nix templates |
| VRRP authPassword → sops (then reverted) | S47/S49 | Moved to sops, then reverted to `writeText` (see section d) |
| LAN firewall | S41 | `trustedInterfaces = ["eno1"]` |
| SSH deprecation warnings | S41 | matchBlocks→settings migration via upstream nix-ssh-config |

### Service Fixes

| Item | Session | Details |
|------|---------|---------|
| Systemd dependency ordering | S40 | unbound + sops-nix added to Docker services and Hermes |
| OpenSEO env deletion bug | S47 | Removed destructive preStartCommands |
| Wireshark-cli removal | S47 | Redundant with wireshark Qt package |
| tor-browser restoration | S39 | Added back to linuxUtilities |
| netwatch installation | S40 | Resolved "built but not installed" |
| XDG_PROJECTS_DIR→PROJECTS rename | S40 | Eliminates HM deprecation warning |
| lib.sh inlining | S40 | Fixed broken display-watchdog + niri-drm-healthcheck |
| Caddy NoNewPrivileges=false | S48 | Force override to preserve capability inheritance |

### External Repos

| Item | Details |
|------|---------|
| hierarchical-errors flake.nix | Proper flake with SSH URL, 5 inputs, all with follows — DONE |
| go-auto-upgrade path→SSH | Already using `git+ssh://` URL — DONE |
| BuildFlow vendorHash | Uses `mkPackageOverlay`, hash managed upstream — N/A (no local override) |
| PMA vendorHash | Uses `mkPackageOverlay`, hash managed upstream — N/A (no local override) |
| go-structure-linter vendorHash | Uses `mkPackageOverlay`, hash managed upstream — N/A (no local override) |

---

## b) PARTIALLY DONE

| Item | Progress | Blocker | Next Step |
|------|----------|---------|-----------|
| Voice-agents Caddy vHost consolidation | 0% | Low priority | Inline vHosts in `voice-agents.nix:110-121` need extracting to `caddy.nix` pattern |
| NVMe SMART monitoring | 70% | Metrics script orphaned | `nvme-health-monitor.nix` (notifications) is staged. `nvme-metrics.sh` (Prometheus metrics) has no timer/service invoking it. Gatus endpoint checks for `node_nvme_*` metrics that nothing produces |
| SigNoz alert channel routing | 0% | Not started | Per-threshold routing (critical→Discord, warning→log) not implemented |
| DNS failover cluster | 60% | Pi 3 hardware | Module complete, VRRP configured, sops wiring partially done. Pi 3 not provisioned |
| Dozzle deployment | 10% | Not started | Listed in TODO as evaluation complete, needs implementation |
| `gogenfilter_2` lockfile duplicate | 80% | PMA upstream | Last controllable duplicate. Needs PMA to accept `gogenfilter` as overridable input |

---

## c) NOT STARTED

| Item | Priority | Details |
|------|----------|---------|
| Deploy Dozzle | P3 | Docker container log tailing at `logs.home.lan` |
| nix-colors integration (HM) | P3 | Obsolete — nix-colors was removed and replaced with inline Catppuccin Mocha. TODO_LIST.md still references this — needs cleanup |
| Pi 3 provisioning | P4 | Hardware needed |
| Pi 3 DNS failover wiring | P4 | Depends on Pi 3 hardware |
| Shared flake-parts template | External | `mkGoPackage`, checks, devshells for Go repos |
| Per-threshold SigNoz channel routing | P2 | `signoz.nix` alert routing |
| Dozzle Docker log viewer | P3 | Not implemented |

---

## d) TOTALLY FUCKED UP

### 1. VRRP Password Security Regression — SEVERITY: HIGH

**Files:** `platforms/nixos/system/dns-blocker-config.nix:69`, `platforms/nixos/rpi3/default.nix:163`

The VRRP password was migrated TO sops in Session 47, then **REVERTED** in Session 49 back to `pkgs.writeText`:

```nix
passwordFile = pkgs.writeText "keepalived-vrrp-env" "VRRP_AUTH_PASSWORD=DNSClusterVRRP-evox2";
```

**Problem:** `pkgs.writeText` puts the password in the **world-readable `/nix/store`** (mode 0444). Any user/process can read `/nix/store/*-keepalived-vrrp-env` and extract the auth password.

**Mitigation:** VRRP `auth_type PASS` is already cleartext on the wire — LAN sniffable. But defense-in-depth still demands sops.

**Fix:** Revert to the sops approach from Session 47 — restore `dns_failover_vrrp_password` in `sops.nix`, restore `keepalived-vrrp-env` template, update `dns-blocker-config.nix` and `rpi3/default.nix` to use `config.sops.templates."keepalived-vrrp-env".path`.

### 2. NVMe Metrics Script Orphaned — SEVERITY: MEDIUM

**File:** `scripts/nvme-metrics.sh`

The `nvme-health-monitor.nix` module (staged) handles desktop notifications but does NOT run `nvme-metrics.sh`. No systemd timer/service anywhere invokes this script. The Gatus endpoint added in this same commit checks for `node_nvme_temperature_celsius`, `node_nvme_percentage_used`, `node_nvme_media_errors_total` — **none of which will exist** until the metrics script runs.

**Fix:** Add a systemd timer/service to `nvme-health-monitor.nix` (or `ai-stack.nix` / `signoz.nix`) that runs `scripts/nvme-metrics.sh` periodically, writing to `/var/lib/prometheus-node-exporter/textfile_collectors/nvme.prom`.

### 3. Dead Variable in nvme-health-monitor.nix — SEVERITY: LOW

**File:** `modules/nixos/services/nvme-health-monitor.nix:21`

`METRICS_FILE` is defined but never written to. The check script only does notifications, not metrics output.

---

## e) WHAT WE SHOULD IMPROVE

### Code Quality

1. **Status report accumulation** — 345+ reports, 6.6 MB. No archival policy beyond manual `archive/` moves. Should auto-archive reports older than 30 days.
2. **TODO_LIST.md is stale** — References nix-colors integration (removed), go-auto-upgrade path→SSH (done), hierarchical-errors flake (done), buildflow/PMA vendorHash (now mkPackageOverlay). Needs full refresh.
3. **Voice-agents inline vHosts** — Only service module that doesn't follow the caddy.nix pattern. Should extract to caddy.nix.
4. **`dns-failover.nix` option docstring stale** — Says "Use sops.templates" but actual usage is `writeText`.

### Security

5. **VRRP password regression** — Must restore sops approach (see section d).
6. **4 secrets still outside sops** — Authelia OIDC client_secret, Gitea admin password, Twenty secrets, unsloth zero hardening.
7. **No pre-commit hook for follows regression** — Adding a new input without `follows` silently bloats the lockfile. Should add a check.

### Architecture

8. **NVMe metrics not wired** — Script exists, module exists, no connection between them.
9. **monitor365.nix is 709 lines** — Largest service module. Could benefit from data extraction (like signoz-alerts pattern).
10. **signoz.nix is 677 lines** — Complex but well-structured. Minor concern for maintainability.

### Process

11. **No CI/CD** — All testing is manual (`just test-fast`, `just test`). No PR checks, no auto-formatting enforcement.
12. **Darwin disk constraint** — MacBook Air at 90-95% full. No automation for cleanup.
13. **`just test` is slow** — Full build validation takes significant time. No incremental testing.

---

## f) Top 25 Things We Should Get Done Next

### Critical (Do First)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Fix VRRP password security regression** — restore sops approach from S47 | Security | 30 min |
| 2 | **Wire nvme-metrics.sh to systemd timer** — Gatus checks phantom metrics | Monitoring | 30 min |
| 3 | **Deploy staged changes** — `just switch` on evo-x2 to activate S49+S50 work | Deployment | 15 min |
| 4 | **Verify VRRP auto-provision** — confirm sops secret appears correctly | Verification | 10 min |

### High Priority

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 5 | **Refresh TODO_LIST.md** — remove stale items, add current priorities | Documentation | 30 min |
| 6 | **Investigate whisper-asr failure** — pre-existing broken service | Reliability | 1-2 hr |
| 7 | **Consolidate voice-agents Caddy vHost** into caddy.nix pattern | Consistency | 30 min |
| 8 | **Add per-threshold SigNoz alert routing** (critical→Discord, warning→log) | Observability | 1 hr |
| 9 | **Migrate Authelia OIDC client_secret to sops** | Security | 30 min |
| 10 | **Migrate Gitea admin password to sops** | Security | 30 min |
| 11 | **Migrate Twenty secrets to central sops** | Security | 1 hr |

### Medium Priority

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 12 | **Deploy Dozzle** — Docker log tailing at `logs.home.lan` | Observability | 1 hr |
| 13 | **Add pre-commit hook for follows regression** — prevent lockfile bloat | Process | 1 hr |
| 14 | **Fix `gogenfilter_2` duplicate** — eliminate last controllable lock node | Optimization | External |
| 15 | **Remove dead `METRICS_FILE` variable** in nvme-health-monitor.nix | Cleanup | 5 min |
| 16 | **Update `dns-failover.nix` option docstring** — fix stale sops reference | Documentation | 5 min |
| 17 | **Auto-archive old status reports** — 30-day policy | Process | 30 min |
| 18 | **Investigate photomap podman permission issue** — disabled service | Reliability | 1-2 hr |

### Lower Priority

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 19 | **Extract monitor365 data** — 709 lines could use signoz-alerts pattern | Maintainability | 2 hr |
| 20 | **Provision Pi 3 for DNS failover cluster** | Resilience | Hardware |
| 21 | **Create shared flake-parts template** for Go repos | Standardization | External |
| 22 | **Add Darwin disk cleanup automation** | Stability | 1 hr |
| 23 | **Implement incremental testing** — faster feedback loop | Developer Experience | 2 hr |
| 24 | **Review/refresh FEATURES.md** — generated 2026-05-03, may be stale | Documentation | 1 hr |
| 25 | **Consider CI/CD** — at minimum, pre-push format + check | Process | 4 hr |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why was the VRRP sops migration reverted in Session 49?**

The staged changes show:
- `sops.nix` REMOVED the `dns_failover_vrrp_password` secret + `keepalived-vrrp-env` template + `sops-provision-vrrp-password` activation script
- `dns-blocker-config.nix` REPLACED `config.sops.templates."keepalived-vrrp-env".path` with `pkgs.writeText` containing the hardcoded password

The Session 47 day summary says "VRRP→sops" was done. The Session 49 day summary says "VRRP auto-provision." But the actual staged code reverts to a less secure approach.

**What was the problem with the sops approach that caused the revert?** Was it:
- The activation script failing during `just switch`?
- sops decryption timing issues with keepalived startup?
- A deliberate decision to simplify since VRRP PASS is already cleartext on the wire?
- An accidental partial revert?

This matters because the current approach is a security regression and the report should document the reasoning if it's intentional.

---

## Staged Changes Summary (Uncommitted)

8 files staged, 428 insertions, 31 deletions:

| File | Change | Status |
|------|--------|--------|
| `docs/status/2026-05-18_DAY_SUMMARY.md` | New — Session 36–49 day summary | ✅ Good |
| `flake.nix` | Added nvme-health-monitor to serviceModules | ✅ Good |
| `modules/nixos/services/gatus-config.nix` | Added NVMe SMART metrics endpoint | ⚠️ Checks metrics that don't exist yet |
| `modules/nixos/services/nvme-health-monitor.nix` | New — NVMe health monitoring with desktop notifications | ⚠️ Dead variable, no metrics integration |
| `modules/nixos/services/sops.nix` | Removed VRRP password + template + activation script | 🔴 Security regression |
| `platforms/nixos/system/configuration.nix` | Enabled nvme-health-monitor | ✅ Good |
| `platforms/nixos/system/dns-blocker-config.nix` | VRRP password → hardcoded writeText | 🔴 Security regression |
| `scripts/nvme-metrics.sh` | Formatting fix (`} > "$TMP"` → `} >"$TMP"`) | ✅ Good |

---

_Arte in Aeternum_
