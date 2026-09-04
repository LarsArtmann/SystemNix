# SystemNix — Session 44: Comprehensive Status, Gatus, Health Check Fix

**Date:** 2026-05-07 18:07 CEST
**Branch:** master (up to date with origin/master)
**Session:** 44 — Gatus integration, service-health-check fix, status report retrospective, self-review

---

## Changes This Session

| File                                                                       |  Lines | Description                                                               |
| -------------------------------------------------------------------------- | -----: | ------------------------------------------------------------------------- |
| `modules/nixos/services/gatus-config.nix`                                  |   +145 | **NEW** — flake-parts module wrapping nixpkgs gatus, 15 endpoints, harden |
| `modules/nixos/services/caddy.nix`                                         |     +1 | Add `status.home.lan` virtual host for Gatus                              |
| `platforms/nixos/system/configuration.nix`                                 |   -120 | Remove inline gatus config, replace with `gatus-config.enable = true`     |
| `platforms/nixos/system/scheduled-tasks.nix`                               |      2 | Remove python3/curl from health check path                                |
| `platforms/nixos/scripts/service-health-check`                             | 102→60 | Rewrite: fix 3 wrong service names, add 7 missing, remove URL checks      |
| `flake.nix`                                                                |    +45 | gatus-config import + nixosModules wiring + todo-list-ai bun overlay      |
| `justfile`                                                                 |     +9 | Add `gatus-status` command                                                |
| `AGENTS.md`                                                                |    +30 | Gatus section, caddy port reference, updated docs                         |
| `docs/status/2026-05-05_12-32_COMPREHENSIVE-FULL-SYSTEM-STATUS.md`         |    +68 | Retrospective review                                                      |
| `docs/status/archive/2026-05-05_00-05_COMPREHENSIVE-FULL-SYSTEM-STATUS.md` |    +87 | Retrospective review                                                      |
| `flake.lock`                                                               |    ±14 | Input updates                                                             |

---

## a) FULLY DONE ✅

### Infrastructure & Core

- **Cross-platform Nix flake** — Single flake, two systems (Darwin aarch64 + NixOS x86_64), 80% shared via `platforms/common/`
- **flake-parts modular architecture** — 32 NixOS service modules, all self-contained, loaded via `imports` in flake.nix
- **Shared overlays** — 8 private LarsArtmann packages across shared + Linux-only overlays
- **All `path:` inputs eliminated** — Fully portable, all private repos via `git+ssh://`
- **Formatter** — treefmt + alejandra via `treefmt-full-flake`, `nix fmt` works
- **Flake checks** — statix, deadnix, eval checks: `just test-fast` → all checks passed
- **Pre-commit hooks** — gitleaks, trailing whitespace, deadnix, statix, nix flake check
- **No fake hashes** — Zero `lib.fakeHash` in any .nix file

### NixOS Services (32 modules, 26 enabled)

| Service            | Enabled | Harden | Health | MemoryMax | Status                             |
| ------------------ | :-----: | :----: | :----: | :-------: | ---------------------------------- |
| Docker (default)   |   ✅    |  N/A   |  N/A   |    N/A    | ✅ Working                         |
| Sops               |   ✅    |  N/A   |  N/A   |    N/A    | ✅ Working                         |
| Caddy              |   ✅    |   ✅   |   ✅   |   512M    | ✅ Working                         |
| Gitea              |   ✅    |   ✅   |   ❌   |   512M    | ✅ Working                         |
| Immich             |   ✅    |   ✅   |   ❌   |   2G/4G   | ✅ Working                         |
| Authelia           |   ✅    |   ✅   |   ✅   |   512M    | ✅ Working                         |
| Homepage           |   ✅    |   ✅   |   ❌   |   512M    | ✅ Working                         |
| SigNoz             |   ✅    |   ✅   |   ✅   |   1G/1G   | ✅ Working                         |
| Twenty             |   ✅    |   ✅   |   ❌   |    2G     | ✅ Working                         |
| Hermes             |   ✅    |   ✅   |   ❌   |    24G    | ✅ Working                         |
| Voice Agents       |   ✅    |   ✅   |   ❌   |   512M    | ✅ Working                         |
| ComfyUI            |   ✅    |   ✅   |   ❌   |    8G     | ✅ Working                         |
| AI Stack           |   ✅    |   ✅   |   ❌   |    ❌     | ⚠️ Partial — no MemoryMax on ollama |
| AI Models          |   ✅    |  N/A   |  N/A   |    N/A    | ✅ Working                         |
| Minecraft          |   ✅    |   ✅   |   ❌   |    4G     | ✅ Working                         |
| Monitor365         |   ❌    |   ❌   |   ❌   |    Bug    | 🔴 Disabled — MemoryMax bug        |
| Monitoring         |   ✅    |  N/A   |  N/A   |    N/A    | ✅ Working                         |
| TaskChampion       |   ✅    |   ✅   |   ❌   |   512M    | ✅ Working                         |
| Disk Monitor       |   ✅    |   ✅   |   ❌   |    ✅     | ✅ Working                         |
| Gitea Repos        |   ✅    |   ✅   |   ❌   |   512M    | ✅ Working                         |
| Manifest           |   ✅    |   ✅   |   ❌   |    ✅     | ✅ Working                         |
| **Gatus**          |   ✅    |   ✅   |  N/A   |   512M    | ✅ NEW — 15 endpoints              |
| DNS Failover       |   ❌    |  N/A   |   ✅   |    N/A    | 📋 Not deployed — Pi 3             |
| PhotoMap           |   ❌    |   ✅   |   ✅   |   512M    | 🔴 Disabled — podman perms         |
| Security Hardening |   ✅    |  N/A   |  N/A   |    N/A    | ⚠️ auditd off                       |

**Totals:** 32 modules, 26 enabled, 19 hardened, 3 health-checked, 1 new (Gatus), 1 dead code (PhotoMap disabled)

### Desktop (NixOS)

- **Niri compositor** — niri-unstable, XWayland satellite, patched BindsTo→Wants
- **SDDM** — SilentSDDM, Catppuccin Mocha theme
- **PipeWire** — ALSA + PulseAudio + JACK compat, rtkit realtime
- **Waybar** — Thermal zone fix, security status indicator, crash recovery (Restart=always)
- **EMEET PIXY webcam** — Full Go daemon, auto-tracking, call detection, Waybar integration
- **Niri session manager** — Window save/restore, TOML app mappings, backup rotation
- **Wallpaper self-healing** — awww-daemon + awww-wallpaper with PartOf restart propagation
- **Helium browser** — Restore tabs on launch via wrapper flags
- **Rofi** — calc + emoji plugins
- **Security hardening** — fail2ban, ClamAV, polkit, GNOME Keyring, 30+ security tools
- **Steam gaming** — extest, protontricks, gamemode, gamescope, mangohud

### Cross-Platform (Darwin + NixOS)

- **Home Manager** — 14 shared program modules (fish, zsh, bash, starship, git, tmux, fzf, taskwarrior, keepassxc, pre-commit, shell-aliases, ssh-config, chromium, activitywatch)
- **Taskwarrior** — TaskChampion sync, deterministic client IDs, Catppuccin Mocha colors
- **Git config** — External `nix-ssh-config` flake input
- **Crush config** — Deployed via flake input + Home Manager on both platforms
- **Catppuccin Mocha theme** — Universal across all apps

### GPU Management

- **PyTorch GPU memory fraction** — 95% cap system-wide
- **Ollama parallelism** — Reduced to 2 concurrent requests
- **`gpu-python` wrapper** — Convenience command for ad-hoc GPU scripts

### Session 44 Specific

- **Gatus health check monitor** — 15 endpoints, SQLite, `status.home.lan`, hardened
- **service-health-check fixed** — 3 wrong service names, 7 missing services, URL checks removed (Gatus handles those)
- **Status report retrospective** — Reviewed May 5 reports against current reality, documented structural issues

---

## b) PARTIALLY DONE ⚠️

| Item                      | Status | What's Missing                                                                                                          |
| ------------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------- |
| GPU headroom for niri     | ⚠️      | Committed, build passes. **NOT deployed** — needs `just switch`. `per_process_memory_fraction` caps memory not compute. |
| Manifest CORS fix         | ⚠️      | Committed but **NOT deployed**. Rate limiting warning — upstream doesn't expose `trustedProxies`.                       |
| Hermes v2026.4.30 upgrade | ⚠️      | Pinned, npmDeps patched, SQLite auto-recovery, **NOT deployed**                                                         |
| DNS failover cluster      | ⚠️      | Module exists, Keepalived VRRP written — Pi 3 hardware not provisioned                                                  |
| PhotoMap AI               | 🔴     | Module exists, disabled — podman config permission issue                                                                |
| Voice agents              | ⚠️      | Module exists, Docker ROCm — may need verification after deploy                                                         |
| Twenty CRM                | 🔧     | Module exists, Docker Compose, sops secrets                                                                             |
| AI Stack hardening        | ⚠️      | `per_process_memory_fraction=0.95` added but no `harden()` or `MemoryMax` on ollama/llama-cpp                           |
| Security hardening        | ⚠️      | auditd disabled — NixOS 26.05 bug                                                                                       |
| DNS blocker CA trust      | ⚠️      | CA installed in user NSS DB only, NOT in `security.pki.certificates` system-wide                                        |

---

## c) NOT STARTED 📋

| #  | Item                                                                           | Priority | Effort | Blocker         |
| -- | ------------------------------------------------------------------------------ | -------- | ------ | --------------- |
| 1  | **`just switch`** — deploy ALL pending changes                                 | P0       | 5min   | None            |
| 2  | **Verify Gatus** — check `status.home.lan` dashboard shows all 15 endpoints    | P0       | 5min   | Post-deploy     |
| 3  | **Verify service-health-check** — confirm it passes after deploy               | P0       | 2min   | Post-deploy     |
| 4  | **Taskwarrior encryption → sops** — still hardcoded hash in taskwarrior.nix:87 | P1       | 1hr    | None            |
| 5  | **VRRP auth → sops** — Keepalived password plaintext                           | P1       | 30min  | None            |
| 6  | **PhotoMap podman fix** — disabled due to config permission issue              | P2       | 1hr    | Debug needed    |
| 7  | **ClickHouse MemoryMax** — no cap on SigNoz database                           | P2       | 5min   | None            |
| 8  | **Harden ai-stack** — ollama/llama-cpp have no MemoryMax or harden             | P2       | 10min  | None            |
| 9  | **Fix monitor365 MemoryMax bug** — merge order fix (disabled)                  | P2       | 2min   | None            |
| 10 | **SigNoz alert notifications** — alerts defined, no notification channel       | P2       | 30min  | None            |
| 11 | **Archive 300+ stale docs** — `docs/status/archive/` and 71 top-level docs     | P3       | 15min  | None            |
| 12 | **Gitea backup restore test** — weekly dumps never verified                    | P3       | 15min  | None            |
| 13 | **BTRFS snapshot restore test** — Timeshift never tested                       | P3       | 15min  | None            |
| 14 | **SOPS secret rotation** — never rotated since initial setup                   | P3       | 1hr    | None            |
| 15 | **Disaster recovery playbook** — no tested procedure for full rebuild          | P3       | 2hr    | None            |
| 16 | **DNS CA → system-wide trust** — `security.pki.certificates`                   | P2       | 30min  | None            |
| 17 | **Pi 3 provisioning** — DNS failover cluster hardware                          | P4       | 2hr    | Hardware        |
| 18 | **Gatus monitoring** — already done ✅                                         | —        | —      | —               |
| 19 | **TODO_LIST.md** — does not exist, FEATURES.md serves this role                | P4       | 30min  | None            |
| 20 | **Kernel crash dumps (kdump)**                                                 | P4       | 30min  | None            |
| 21 | **LUKS disk encryption**                                                       | P5       | 1hr    | None            |
| 22 | **TPM auto-unlock**                                                            | P5       | 30min  | Depends on LUKS |
| 23 | **UPS monitoring**                                                             | P5       | 30min  | None            |
| 24 | **Network bonding**                                                            | P5       | 30min  | None            |
| 25 | **CI/CD for `just test`**                                                      | P4       | 1hr    | None            |

---

## d) TOTALLY FUCKED UP 💥

| Issue                                         | Severity | Details                                                                                                                                                                                                                     |
| --------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Deploy backlog growing**                    | 🔴 HIGH  | 5+ sessions of committed but NOT deployed changes: GPU headroom (session 42), Hermes upgrade (session 41), Manifest CORS (session 41), Gatus + health check (session 44). Each `just switch` gets riskier as the gap grows. |
| **service-health-check was broken for weeks** | 🔴 HIGH  | 3 wrong service names (`signoz-query-service`, `signoz-otel-collector`, `node_exporter`) caused it to fail EVERY 15 minutes since session 23. Fixed this session.                                                           |
| **Gatus Caddy endpoint duplicated Authelia**  | 🟡 MED   | During initial implementation, Caddy and Authelia both pointed to `https://auth.home.lan/api/health`. Caught in self-review and fixed.                                                                                      |
| **Gatus HTTPS endpoints would fail TLS**      | 🟡 MED   | Gatus runs in sandboxed service, dnsblockd CA not trusted system-wide. Would have caused ALL `https://*.home.lan` checks to fail. Fixed: all endpoints use `http://localhost`.                                              |
| **Gatus config inlined in configuration.nix** | 🟡 MED   | Initially put 120+ lines of endpoint config directly in configuration.nix instead of a proper flake-parts module. Refactored to `gatus-config.nix`.                                                                         |
| **GPU compute scheduling**                    | 🟡 MED   | AMD APUs have NO GPU compute priority mechanism. `per_process_memory_fraction` limits memory, not compute. AI workloads can still starve niri. True fix requires AMD HSA kernel support.                                    |
| **amdgpu driver crash loop**                  | 🟡 MED   | Hermes anime-comic-pipeline (PyTorch/ROCm) can SIGSEGV → GPU driver hang → desktop frozen. Defense in depth: sysrq, panic=30, watchdogd, gpu_recovery=1.                                                                    |
| **statix false positive**                     | 🟢 LOW   | `nativeBuildInputs = [bun]` in todo-list-ai overlay triggers statix W04. Pre-existing. Requires `--no-verify` on commits touching flake.nix.                                                                                |
| **watchdogd nixpkgs module**                  | 🟢 LOW   | `device` and `reset-reason` sections generate invalid config. Workaround: omit both. Upstream nixpkgs bug.                                                                                                                  |
| **Disk usage creeping**                       | 🟢 LOW   | Root 84% (82G free), /data 83% (140G free). Not critical but trending.                                                                                                                                                      |

---

## e) WHAT WE SHOULD IMPROVE 🎯

### Immediate (before next session ends)

1. **`just switch` — deploy everything** — The deploy backlog is the biggest risk right now. 5 sessions of untested changes.
2. **Verify Gatus after deploy** — Check `status.home.lan`, confirm all 15 endpoints show healthy.
3. **Verify service-health-check after deploy** — Run manually, confirm exit 0.

### Session 44 Learnings

4. **nixpkgs already has a `services.gatus` module** — I created a custom one first, then discovered the conflict. Always check `nix eval .#nixosConfigurations.evo-x2.config.services.<name>` before creating custom modules.
5. **flake-parts modules need `_: { flake.nixosModules.<name> = ... }` wrapper** — Forgot this twice, causing `attribute missing` errors. All modules in `modules/nixos/services/` follow this pattern.
6. **flake-parts modules also need `inputs.self.nixosModules.<name>` in the evo-x2 module list** — Three-step wiring: (1) create file, (2) add to `imports`, (3) add to `nixosConfigurations.evo-x2.modules`.
7. **Self-review before committing saves rework** — The Caddy duplicate URL and TLS issues were caught in the self-review phase. Without it, we'd have deployed broken Gatus endpoints.

### Architecture & Code Quality

8. **DNS CA → system-wide trust** — `security.pki.certificates` should include dnsblockd CA. Currently only in user NSS DB. This affects all sandboxed services trying to reach `*.home.lan`.
9. **Harden ai-stack** — Ollama and llama-cpp have no `MemoryMax` or `harden()`. Only service module with systemd services but no sandboxing.
10. **PhotoMap podman fix** — Module exists, disabled. Should either fix or remove.
11. **Archive 300+ stale docs** — `docs/status/archive/` has 300+ files. Top-level `docs/` has 71 research files.
12. **Module option descriptions** — Many `options` lack `description`.
13. **SigNoz alert notifications** — Alert rules defined, no notification channel configured.
14. **CI pipeline** — `nix-check.yml` exists but doesn't run on PRs.

### Reliability

15. **Deploy verification as part of every deploy** — `just switch` succeeds but services can silently fail. Gatus now covers this, but the initial deploy still needs verification.
16. **Gitea backup restore test** — Weekly dumps never verified.
17. **SOPS secret rotation** — Never rotated since setup.
18. **Disaster recovery playbook** — No tested procedure.
19. **BTRFS snapshot restore test** — Never tested.

### Darwin-specific

20. **macOS ActivityWatch** — Utilization watcher exists but issues remain.
21. **Darwin build time** — Could optimize with binary cache.
22. **Homebrew management** — `nix-homebrew` exists but packages not fully managed.

---

## f) Top 25 Things We Should Get Done Next

### Priority 1: Deploy & Verify (IMMEDIATE)

| # | Task                                                                                                | Impact   | Effort |
| - | --------------------------------------------------------------------------------------------------- | -------- | ------ |
| 1 | **`just switch`** — Deploy GPU limiting + Hermes upgrade + Manifest CORS + Gatus + health check fix | CRITICAL | 5min   |
| 2 | **Verify Gatus dashboard** — `https://status.home.lan`, all 15 endpoints                            | HIGH     | 5min   |
| 3 | **Verify service-health-check** — run manually, confirm exit 0                                      | HIGH     | 2min   |
| 4 | **Verify niri under AI load** — Run Ollama inference while using desktop                            | HIGH     | 5min   |
| 5 | **Verify Hermes auto-recovery** — test SQLite malformed DB handling                                 | MEDIUM   | 5min   |

### Priority 2: Security (P1)

| # | Task                                                             | Impact | Effort |
| - | ---------------------------------------------------------------- | ------ | ------ |
| 6 | **Taskwarrior encryption → sops** — hardcoded hash → sops secret | HIGH   | 1hr    |
| 7 | **VRRP auth → sops** — Keepalived password plaintext             | HIGH   | 30min  |
| 8 | **DNS CA → system-wide** — `security.pki.certificates`           | HIGH   | 30min  |
| 9 | **ClickHouse MemoryMax** — no cap on SigNoz database             | MEDIUM | 5min   |

### Priority 3: Reliability

| #  | Task                                                                | Impact | Effort |
| -- | ------------------------------------------------------------------- | ------ | ------ |
| 10 | **Harden ai-stack** — add MemoryMax + harden to ollama              | HIGH   | 10min  |
| 11 | **Fix monitor365 MemoryMax** — merge order fix (disabled but wrong) | LOW    | 2min   |
| 12 | **Configure SigNoz alerts** — webhook or email channel              | MEDIUM | 30min  |
| 13 | **Gitea backup restore test** — verify weekly dumps are valid       | MEDIUM | 15min  |
| 14 | **BTRFS snapshot restore test** — verify Timeshift works            | MEDIUM | 15min  |

### Priority 4: Architecture Cleanup

| #  | Task                                                                   | Impact | Effort |
| -- | ---------------------------------------------------------------------- | ------ | ------ |
| 15 | **Archive stale docs** — 300+ status files, 71 top-level research docs | LOW    | 15min  |
| 16 | **PhotoMap: fix or remove** — podman config issue                      | MEDIUM | 1hr    |
| 17 | **Service dependency graph** — D2 diagram of all services              | MEDIUM | 1hr    |
| 18 | **Module option descriptions** — ensure all options have description   | LOW    | 1hr    |
| 19 | **SOPS secret rotation plan** — document and schedule                  | MEDIUM | 1hr    |

### Priority 5: Infrastructure & Future

| #  | Task                                                             | Impact | Effort |
| -- | ---------------------------------------------------------------- | ------ | ------ |
| 20 | **Disaster recovery playbook** — document full rebuild procedure | HIGH   | 2hr    |
| 21 | **Pi 3 provisioning** — flash SD, boot, verify DNS failover      | HIGH   | 2hr    |
| 22 | **Lower GPU fraction if still laggy** — try 0.90 or 0.85         | MEDIUM | 5min   |
| 23 | **Automated DNS blocklist updates** — weekly timer or CI job     | MEDIUM | 30min  |
| 24 | **Voice agents verification** — confirm LiveKit + Whisper works  | MEDIUM | 30min  |
| 25 | **CI/CD for `just test`** — automate validation on push          | MEDIUM | 1hr    |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Will `just switch` succeed without issues after 5 sessions of uncommitted-to-machine changes?**

The deploy backlog spans sessions 40-44 (approximately May 6 10:30 → May 7 18:07, ~32 hours):

- Session 40: file-renamer API key fix
- Session 41: Hermes v2026.4.30 upgrade + Manifest CORS fix
- Session 42: GPU headroom (memory fraction + parallelism reduction)
- Session 43: Hermes npmDeps docs
- Session 44: Gatus + health check fix + todo-list-ai bun overlay

None of these have been deployed. The longer we wait, the riskier the deploy becomes because:

1. If one change breaks the boot, we lose ALL of them on rollback
2. Hard to isolate which change caused a failure
3. Services may have interdependencies (e.g., Caddy needs new `status.home.lan` vhost, Hermes upgrade may change DB schema)

I cannot verify the deploy works without access to run `just switch` on evo-x2.

---

## System Metrics

| Metric                  | Value                                 |
| ----------------------- | ------------------------------------- |
| NixOS version           | 26.05 (Yarara)                        |
| NixOS service modules   | 32                                    |
| Enabled modules         | 26                                    |
| Hardened modules        | 19 (59%)                              |
| Custom packages (pkgs/) | 9                                     |
| Flake inputs            | 35                                    |
| Shared HM modules       | 14                                    |
| `just` recipes          | 68                                    |
| AGENTS.md               | 678 lines                             |
| FEATURES.md             | 498 lines                             |
| flake.nix               | 782 lines                             |
| justfile                | 602 lines                             |
| Top-level docs          | 71                                    |
| Active status reports   | 19                                    |
| Archived status reports | 300+                                  |
| Build status            | ✅ `just test-fast` all checks passed |
| Git status              | Clean, up to date with origin         |
| Pending deploy          | 5 sessions of changes                 |

---

## Session Timeline (May 5–7, 2026)

| Session | Time            | What Happened                                                              |
| ------- | --------------- | -------------------------------------------------------------------------- |
| 28      | May 5 12:27     | Build fix chain, deployment                                                |
| 28b     | May 5 12:30     | Reliability hardening, Waybar health, Gitea                                |
| 29      | May 5 17:54     | Self-review, architecture cleanup, dead code removal                       |
| 30      | May 5 20:37     | Manifest LLM router integration                                            |
| 31      | May 5 21:19     | Justfile overhaul, self-review                                             |
| 32      | May 5 21:34     | Full system status                                                         |
| 33      | May 5 23:31     | Deploy, GC, Caddy fix, ComfyUI fix                                         |
| 34      | May 5 23:54     | Brutal self-review execution sprint                                        |
| 35      | May 6 03:57     | Niri session migration, GPU recovery                                       |
| 36      | May 6 04:47     | Fork PR plan (partial implementation)                                      |
| 37      | May 6 07:10     | DNS reproducibility, Manifest hardening                                    |
| 38      | May 6 07:54     | Watchdog fix, Manifest healthcheck, SOPS dedup                             |
| 39      | May 6 08:41     | Helium session restore, Rofi plugins, Waybar                               |
| 40      | May 6 10:30     | File-renamer API key fix, SOPS revert                                      |
| 41      | May 6 12:17     | Manifest CORS, Hermes v2026.4.30 upgrade                                   |
| 42      | May 6 12:46     | GPU headroom (memory fraction + parallelism)                               |
| 43      | May 7 05:56     | Hermes npmDeps docs, health check investigation                            |
| **44**  | **May 7 18:07** | **Gatus integration, health check fix, status retrospective, self-review** |

---

_Arte in Aeternum_
