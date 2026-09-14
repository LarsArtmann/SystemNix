# Full System Status Report — 2026-04-24 21:50

**Generated:** 2026-04-24 21:50 CEST
**Author:** Crush (GLM-5.1)
**Commit:** 409f7a2 (ahead of origin by 1)
**Platform:** evo-x2 (x86_64-linux, AMD Ryzen AI Max+ 395, 128GB)

---

## a) FULLY DONE

### 1. DNS Blocker: Dedicated IP Architecture (THIS SESSION)

**Problem diagnosed**: dnsblockd stats showed `total_blocked: 0` despite Unbound correctly resolving blocked domains to `192.168.1.150`. Root cause: all modern browser traffic is HTTPS (port 443), which was Caddy — not dnsblockd. dnsblockd only listened on `192.168.1.150:80` (HTTP) and `192.168.1.150:8443` (HTTPS), neither of which browsers ever hit. Blocked domains resolved correctly but the HTTPS request landed in Caddy (no matching vhost → generic error), dnsblockd's `blockHandler` was never called, `recordBlock()` never fired.

**Fix applied** (commit `a00834f`, authored by prior MiniMax session):

- dnsblockd gets its own IP: `192.168.1.200` — a secondary address on `eno1`
- dnsblockd binds `192.168.1.200:80` (HTTP) + `192.168.1.200:443` (HTTPS with dynamic per-domain TLS certs)
- Caddy binds only to `192.168.1.150:443` (via `servers { bind }` in global config)
- Removed runtime IP detection scripts (`detectIPScript`, `addIPScript`, `delIPScript`)
- dnsblockd uses static `-addr 192.168.1.200` instead of runtime-detected `$IP`
- Reverted Caddy `:443` catch-all reverse proxy (no longer needed)

**Files changed**:

- `platforms/nixos/system/dns-blocker-config.nix` — `blockIP = "192.168.1.200"`, `blockTLSPort = 443`
- `platforms/nixos/modules/dns-blocker.nix` — simplified: no runtime detection, static IP, unconditional `/32` on interface
- `modules/nixos/services/caddy.nix` — `caddyBind` binds to server IP only, removed catch-all
- `platforms/nixos/programs/dnsblockd/main.go` — initialized `RecentBlocks` as `make([]BlockEntry, 0)` (was nil → `null` in JSON)

**Status**: Committed, build passes (`just test-fast`), NOT deployed (`just switch` not run).

### 2. hipblaslt Removal (prior session, commit `a00834f`)

- Removed `rocmPackages.hipblaslt` from `amd-gpu.nix`
- Removed `ROCBLAS_USE_HIPBLASLT=1` from `ai-stack.nix` (2 locations) and `comfyui.nix`
- Deleted `hipblasltFixOverlay` from `flake.nix` (13 lines + overlay reference)
- Result: zero ROCm patches, zero overlays. The 31-error build cascade resolved by removing optional library.

### 3. Flake-Parts Service Module Migration (~60% complete)

- 10 of ~50 modules migrated to flake-parts architecture in prior sessions
- Each defines `config` options under `services.<name>`, manages own systemd services
- Imported in `flake.nix` via `imports`, wired via `inputs.self.nixosModules.<name>`

### 4. DNS High-Availability Cluster (prior sessions)

- Keepalived VRRP failover: `192.168.1.53` virtual IP, tracks Unbound process
- Pi 3 backup DNS node: software 100% in repo, hardware not flashed
- Shared blocklists via `platforms/shared/dns-blocklists.nix`

### 5. Comprehensive Review & Planning

- `docs/status/REVIEW_DOCS.md` — full audit of 246 status docs, security issues, code quality
- `docs/status/MASTER_TODO_PLAN.md` — 96 prioritized tasks (P0–P9), ~15 hours estimated
- `docs/status/debug-map.md` — incident forensic document

---

## b) PARTIALLY DONE

### 1. NixOS Deployment

- All changes committed and build-tested
- `just switch` NOT run — dnsblockd still running with OLD config (`192.168.1.150:80+8443`)
- Caddy still listening on `*:443` (should be `192.168.1.150:443` after deploy)
- Blocked domains still resolve to `192.168.1.150` (not `192.168.1.200` yet)

### 2. dnsblockd Stats Validation

- Code fix committed (`RecentBlocks` initialization)
- New IP architecture committed
- Cannot verify stats work until `just switch` + browsing blocked domains

### 3. Pi 3 DNS Backup Node

- Software: 100% — `platforms/nixos/rpi3/default.nix` complete
- Hardware: NOT started — SD image not built, not flashed, not booted
- DNS failover: untested (needs Pi 3 running)

### 4. Flake-Parts Migration

- ~60% complete (10 of ~50 modules)
- 16 modules still have no `enable` option (always-on)
- `homeModules` pattern for Home Manager configs not yet created

---

## c) NOT STARTED

1. **Service verification** — Ollama, Steam, ComfyUI untested after hipblaslt removal
2. **SigNoz** — built but unclear if actively collecting metrics/logs/traces
3. **Authelia SSO** — status unknown since 04-05
4. **PhotoMap** — status unknown since 03-31
5. **AMD NPU** — driver installed, never tested with actual workload
6. **GitHub Actions CI** — zero CI exists
7. **Archive stale status docs** — 39 redundant docs in `docs/status/`
8. **Git hygiene** — 3 stale stashes, 17 remote `copilot/fix-*` branches
9. **Security fixes** — Taskwarrior encryption secret public in repo, VRRP plaintext auth, Docker image digests unpinned
10. **Module enable toggles** — 16 always-on modules need `lib.mkEnableOption`
11. **`git push`** — 1 unpushed commit (recommended in 15+ status docs, never done)
12. **`.editorconfig`** — no consistent editor settings
13. **Backup restore tests** — Immich + Twenty backups exist but never verified

---

## d) TOTALLY FUCKED UP

### 1. dnsblockd Currently Broken on Live System

```
dnsblockd listening on 192.168.1.150:80     (HTTP — works but browsers don't use HTTP)
dnsblockd listening on 192.168.1.150:8443   (HTTPS — WRONG PORT, no browser sends here)
Caddy listening on *:443                     (captures all HTTPS including blocked domains)
```

**Result**: Blocked domains resolve to `192.168.1.150` → HTTPS request hits Caddy → Caddy has no vhost for `doubleclick.net` → returns generic error. dnsblockd never sees the request. Stats stay at 0 forever.

**Fix is committed but NOT deployed.** Requires `just switch`.

### 2. Ollama/Steam/ComfyUI — UNKNOWN State

- hipblaslt removed in committed code but NOT deployed
- Currently running system still has hipblaslt overlay (from previous generation)
- After `just switch`, ROCm-dependent apps may or may not work — untested

### 3. 46 Status Docs (Doc Rot)

- 44 active + 2 new = 46 markdown files in `docs/status/`
- ~66% are redundant (same info repeated across multiple reports)
- README.md stale since 04-04 (20 days)
- Creating more status docs without archiving old ones is compounding the problem

### 4. 3 Stale Git Stashes

```
stash@{0}: WIP on master: 24335f3 chore(deps): update emeet-pixyd vendorHash
stash@{1}: WIP on master: 2f94f3f docs(status): normalize line endings
stash@{2}: WIP on master: 99ddc46 fix(desktop): update Hyprland window rules
```

All orphaned since pre-niri migration. Likely useless.

### 5. `just test` Intermittent Race

- emeet-pixyd sandbox test fails in parallel, succeeds alone
- Root cause unknown, not investigated

---

## e) IMPROVEMENTS NEEDED

### High Priority

1. **Validate `192.168.1.200` doesn't conflict** — ping/arp scan before deploy
2. **`just switch` + verify dnsblockd** — the entire IP architecture change is theoretical until deployed
3. **Archive 39 status docs** — move to `docs/status/archive/`, keep only 5-7 recent
4. **`git stash clear`** — drop 3 orphaned stashes
5. **`git push`** — 1 unpushed commit at risk
6. **Delete 17 remote `copilot/fix-*` branches** — stale since April

### Medium Priority

7. **Move Taskwarrior encryption to sops** — `sha256("taskchampion-sync-encryption-systemnix")` is public
8. **Pin Docker image digests** — Voice Agents + PhotoMap using `:latest`
9. **Add `WatchdogSec` to 4 services** — caddy, gitea, authelia, taskchampion
10. **Add `.editorconfig`** — 2-space indent, UTF-8, LF
11. **Fix deadnix unused params** — 4 batches across 17 files
12. **Extract `lib/systemd-harden.nix` helper** — 20 lines repeated per service

### Low Priority

13. **GitHub Actions CI** — zero CI, every change is manually tested
14. **Backup restore tests** — Immich + Twenty backups never verified
15. **NixOS VM tests** — zero `nixosTests` in flake

---

## f) Top 25 Things to Get Done Next

| #  | Task                                                               | Est. | Impact                           |
| -- | ------------------------------------------------------------------ | ---- | -------------------------------- |
| 1  | `just switch` — deploy all committed changes                       | 45m  | Everything depends on this       |
| 2  | Verify dnsblockd serves block pages on `192.168.1.200:443`         | 3m   | Confirms the entire fix          |
| 3  | Verify Ollama works after rebuild (`ollama list` + test inference) | 5m   | ROCm-dependent, was broken       |
| 4  | Verify Steam + ComfyUI work after rebuild                          | 10m  | ROCm-dependent                   |
| 5  | `git push` — push all local commits                                | 1m   | Unpushed work at risk            |
| 6  | `git stash clear` — drop 3 orphaned stashes                        | 1m   | Hygiene                          |
| 7  | Delete 17 remote `copilot/fix-*` branches                          | 2m   | Hygiene                          |
| 8  | Ping `192.168.1.200` to confirm no IP conflict                     | 1m   | Pre-deploy validation            |
| 9  | Archive 39 redundant status docs to `archive/`                     | 5m   | Doc rot                          |
| 10 | Move Taskwarrior encryption secret to sops-nix                     | 10m  | Security                         |
| 11 | Pin Docker image digests (Voice Agents + PhotoMap)                 | 10m  | Security                         |
| 12 | Secure VRRP `auth_pass` with sops-nix                              | 8m   | Security                         |
| 13 | Add `WatchdogSec=30` to caddy, gitea, authelia, taskchampion       | 10m  | Reliability                      |
| 14 | Add `Restart=on-failure` to services missing it                    | 8m   | Reliability                      |
| 15 | Add systemd hardening to `gitea-ensure-repos`                      | 8m   | Only service with zero hardening |
| 16 | Build Pi 3 SD image (`nix build .#rpi3-dns`)                       | 30m  | DNS HA completion                |
| 17 | Flash + boot Pi 3                                                  | 15m  | DNS HA completion                |
| 18 | Test DNS failover (stop Unbound on evo-x2, verify Pi 3 takes over) | 10m  | DNS HA validation                |
| 19 | Add `.editorconfig` (2-space, UTF-8, LF)                           | 2m   | Code quality                     |
| 20 | Fix deadnix unused params (batch 1: 6 service modules)             | 10m  | Code quality                     |
| 21 | Extract `lib/systemd-harden.nix` shared helper                     | 12m  | DRY, 20 lines per service        |
| 22 | Add GitHub Actions: `nix flake check` on push                      | 10m  | Zero CI exists                   |
| 23 | Verify SigNoz is collecting metrics/logs/traces                    | 5m   | Unknown status                   |
| 24 | Verify Authelia SSO login works                                    | 3m   | Unknown since 04-05              |
| 25 | Add `homeModules` pattern for HM configs via flake-parts           | 12m  | Architecture                     |

---

## g) My Top #1 Question

**Does `192.168.1.200` conflict with anything on your LAN?**

The dnsblockd dedicated IP is hardcoded as `192.168.1.200`. This is a common gateway/router address on many networks. If your router or any other device uses `.2`, the secondary IP will cause an ARP conflict and break both dnsblockd AND the conflicting device. Please confirm this IP is free before `just switch`.

---

## Runtime State (Live System — NOT yet deployed)

```
dnsblockd: 192.168.1.150:80 + 192.168.1.150:8443 (OLD — stats broken)
Caddy:     *:443 (OLD — binds all interfaces)
Unbound:   0.0.0.0:53 + ::0:53 (working, 2.5M+ domains blocked)
Blocked:   doubleclick.net → 192.168.1.150 (correct resolution, wrong handler)
```

## Expected State After `just switch`

```
dnsblockd: 192.168.1.200:80 + 192.168.1.200:443 (NEW — own IP, dynamic TLS)
Caddy:     192.168.1.150:443 (NEW — bound to server IP only)
Unbound:   0.0.0.0:53 (unchanged)
Blocked:   *.blocked-domain → 192.168.1.200 (NEW — goes directly to dnsblockd)
```

---

## Git State

```
Branch: master (ahead of origin by 1 commit)
Untracked: docs/status/MASTER_TODO_PLAN.md
Stashes: 3 (all stale, orphaned since pre-niri)
Recent: 409f7a2 docs(status): full system status report (2026-04-24 21:37)
        a00834f chore: remove hipblaslt, simplify DNS blocker interface binding, fix Caddy TLS
```
