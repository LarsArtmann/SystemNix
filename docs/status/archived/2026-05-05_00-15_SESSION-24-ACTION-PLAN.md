# Session 24 — Action Plan

**Created:** 2026-05-05 00:15 CEST | **Tasks:** 30 | **Est. Total:** ~5.5h
**Pre-req:** All commits clean, working tree clean, branch ahead of origin by 3 commits

---

## DEPLOYMENT — nothing works until deployed

| # | Task                                       | Cat    | Est | Impact      | Why                                      |
| - | ------------------------------------------ | ------ | --- | ----------- | ---------------------------------------- |
| 1 | `just switch` — deploy ALL pending changes | deploy | 45m | 🔴 CRITICAL | 0% of today's fixes work until this runs |

## IMMEDIATE FIXES — broken right now

| # | Task                                                      | Cat    | Est | Impact  | Why                                        |
| - | --------------------------------------------------------- | ------ | --- | ------- | ------------------------------------------ |
| 2 | Verify whisper-asr starts correctly post-switch           | verify | 5m  | 🔴 HIGH | Was crash-looping for weeks                |
| 3 | Verify watchdogd is running: `systemctl status watchdogd` | verify | 2m  | 🔴 HIGH | The whole point of today                   |
| 4 | Verify SysRq enabled: `cat /proc/sys/kernel/sysrq`        | verify | 1m  | 🔴 HIGH | Confirm REISUB works                       |
| 5 | Fix AMD GPU metrics (`amdgpu.prom` empty value)           | fix    | 12m | 🟡 HIGH | Spams node_exporter errors every 30s       |
| 6 | Fix or remove `clamav-freshclam.service`                  | fix    | 5m  | 🟡 MED  | Failed service = noise you learn to ignore |
| 7 | Fix `service-health-check.service`                        | fix    | 12m | 🟡 MED  | Health monitoring is down                  |

## DISK & MEMORY — ticking bombs

| #  | Task                                                  | Cat     | Est | Impact  | Why                                  |
| -- | ----------------------------------------------------- | ------- | --- | ------- | ------------------------------------ |
| 8  | `nix-collect-garbage -d` — clean old generations      | cleanup | 10m | 🔴 HIGH | Root 88% full, recover 20-50GB       |
| 9  | `docker system prune -af` — clean unused images       | cleanup | 5m  | 🟡 MED  | Docker images hog disk on /          |
| 10 | Check memory hogs: `ps aux --sort=-%mem \| head -20`  | diag    | 5m  | 🔴 HIGH | 60/62GB used at 17min uptime         |
| 11 | Investigate Hermes actual memory usage with 24G limit | diag    | 10m | 🟡 MED  | Was the 4G limit masking real usage? |

## SECURITY — P1 from master plan

| #  | Task                                            | Cat      | Est | Impact | Why                                        |
| -- | ----------------------------------------------- | -------- | --- | ------ | ------------------------------------------ |
| 12 | Move Taskwarrior encryption secret to sops (#7) | security | 10m | 🟡 MED | Hardcoded `sha256(...)` in taskwarrior.nix |
| 13 | Pin Docker image digest for Voice Agents (#9)   | security | 5m  | 🟢 LOW | Already SHA256 pinned — DONE               |
| 14 | Pin Docker image digest for PhotoMap (#10)      | security | 5m  | 🟡 MED | Version-tagged not digest-pinned           |
| 15 | Secure VRRP auth_pass with sops (#11)           | security | 10m | 🟡 MED | Plaintext password in dns-failover.nix     |

## POST-SWITCH VERIFICATION

| #  | Task                                              | Cat    | Est | Impact  | Why                                  |
| -- | ------------------------------------------------- | ------ | --- | ------- | ------------------------------------ |
| 16 | Verify niri compositor stable after rebuild (#41) | verify | 5m  | 🟢 HIGH | Desktop is the primary interface     |
| 17 | Verify Ollama works after rebuild (#42)           | verify | 5m  | 🟢 MED  | Core AI infrastructure               |
| 18 | Verify ComfyUI works after rebuild (#44)          | verify | 5m  | 🟢 MED  | Image generation                     |
| 19 | Verify Caddy HTTPS + block page (#45)             | verify | 3m  | 🟢 MED  | All services depend on reverse proxy |
| 20 | Verify SigNoz collecting metrics/logs (#46)       | verify | 5m  | 🟢 MED  | Observability                        |
| 21 | Verify Authelia SSO status (#47)                  | verify | 3m  | 🟢 MED  | Forward auth for services            |
| 22 | Check PhotoMap service status (#48)               | verify | 3m  | 🟢 LOW  | Photo management                     |

## SERVICE IMPROVEMENTS

| #  | Task                                    | Cat     | Est | Impact | Why                          |
| -- | --------------------------------------- | ------- | --- | ------ | ---------------------------- |
| 23 | Hermes: add health check endpoint (#62) | service | 12m | 🟢 MED | Service reliability          |
| 24 | Authelia: add SMTP notifications (#66)  | service | 10m | 🟢 LOW | Blocked on SMTP credentials  |
| 25 | Immich backup restore test (#67)        | service | 10m | 🟢 LOW | Verify backups actually work |

## INFRASTRUCTURE

| #  | Task                                           | Cat   | Est | Impact | Why                   |
| -- | ---------------------------------------------- | ----- | --- | ------ | --------------------- |
| 26 | Build Pi 3 SD image (#50)                      | infra | 30m | 🟢 MED | DNS failover cluster  |
| 27 | Fix root partition sizing — move more to /data | infra | 12m | 🟡 MED | Long-term disk health |

## FUTURE / RESEARCH

| #  | Task                                                   | Cat      | Est | Impact  | Why                         |
| -- | ------------------------------------------------------ | -------- | --- | ------- | --------------------------- |
| 28 | Investigate GPU compute/display isolation (cgroups)    | research | 12m | 🟡 HIGH | Prevent GPU crash cascading |
| 29 | Add real-time niri session save via event-stream (#94) | feature  | 12m | 🟢 MED  | Better crash recovery       |
| 30 | Investigate binary cache (Cachix) (#92)                | perf     | 12m | 🟢 LOW  | 45min rebuilds are painful  |

---

## Session 24 Fixes Already Committed (not yet deployed)

| Commit    | What                                                 |
| --------- | ---------------------------------------------------- |
| `01fd963` | photomap harden() + missing imports                  |
| `e03cf51` | library-policy nix migration report                  |
| `922648a` | whisper-asr command fix + harden() across 6 services |
| `2085dd0` | extract shared systemd helpers to lib/               |
| `8d77137` | wallpaper self-healing with awww restore             |
| `593be03` | 6-layer crash recovery defense-in-depth              |
| `150d269` | wallpaper daemon restart policy hardening            |

All pass `just test-fast`. All pass pre-commit hooks. Clean working tree.
