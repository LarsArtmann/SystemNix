# SystemNix — Full Project Status Report

**Date:** 2026-04-20 11:00 CEST
**Branch:** `master`
**Commits ahead of origin:** 2
**Working tree:** 1 staged file (hermes.nix), otherwise clean

---

## A) FULLY DONE ✅

### Observability Pipeline (SigNoz)

| Item                   | Status      | Details                                                                                                                       |
| ---------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------- |
| SigNoz OTel Collector  | ✅ Complete | OTLP receiver (4317/4318), prometheus receiver, journald receiver                                                             |
| node_exporter          | ✅ Complete | Port 9100, collectors: cpu, diskstats, filesystem, loadavg, meminfo, netdev, stat, **systemd**, time, vmstat, hwmon, pressure |
| cAdvisor               | ✅ Complete | Port 9110, container metrics                                                                                                  |
| Caddy metrics          | ✅ Complete | Port 2019, reverse proxy metrics                                                                                              |
| Authelia metrics       | ✅ Complete | Port 9959, SSO health                                                                                                         |
| dnsblockd /metrics     | ✅ Complete | Port 9090, 3 custom metrics (blocked_total, active_temp_allows, false_positive_reports)                                       |
| emeet-pixyd /metrics   | ✅ Complete | Port 8090, 3 custom metrics (in_call, auto_mode, camera_state)                                                                |
| AMD GPU monitoring     | ✅ Complete | Textfile collector at `/var/lib/prometheus-node-exporter/textfile_collectors/amdgpu.prom`, 5 metrics                          |
| Alert rules            | ✅ Complete | 7 rules: disk-full, cpu-sustained, memory-critical, service-down, gpu-thermal, dnsblockd-down, emeet-pixyd-down               |
| Dashboard provisioning | ✅ Complete | signoz-provision oneshot service deploys 1 dashboard + 7 alert rules via API                                                  |
| Scrape interval        | ✅ Fixed    | 30s (was 60s) for better alert responsiveness                                                                                 |

### Security Hardening (This Session)

| Item                            | Status      | Details                                                                                                             |
| ------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------- |
| dnsblockd XSS fix               | ✅ Complete | `html.EscapeString()` on all user-controlled domain strings in 3 HTML handlers + `urlSafeDomain()` for JS redirects |
| dnsblockd data race             | ✅ Complete | `hit.Count++` → `atomic.AddInt64(&hit.Count, 1)`                                                                    |
| node_exporter systemd collector | ✅ Complete | `systemd` added to enabledCollectors — `node_systemd_units` now available for alerts                                |
| dnsblockd CSS gradient          | ✅ Fixed    | `%%23` → `%%,` in false-positive handler gradient                                                                   |

### CI/CD

| Item                      | Status     | Details                                                                                                 |
| ------------------------- | ---------- | ------------------------------------------------------------------------------------------------------- |
| nix-check.yml             | ✅ Updated | 5 jobs: check, build-darwin, syntax-check, go-test (emeet-pixyd + vet), go-test-dnsblockd (build + vet) |
| flake-update.yml          | ✅ Updated | Weekly auto-update with `nix flake check --no-build` validation                                         |
| cachix/install-nix-action | ✅ Updated | v22 → v28 across all workflows                                                                          |

### Homepage Dashboard

| Item                    | Status      | Details                                                                             |
| ----------------------- | ----------- | ----------------------------------------------------------------------------------- |
| System resource widgets | ✅ Complete | CPU, RAM, disk, uptime in header                                                    |
| DNS Blocker card        | ✅ Fixed    | siteMonitor now points to http://localhost:9090/health (was https://localhost:8443) |
| Monitoring group        | ✅ Complete | SigNoz, Node Exporter, cAdvisor, dnsblockd, EMEET PIXY cards                        |

### Infrastructure

| Item                            | Status      | Details                                                            |
| ------------------------------- | ----------- | ------------------------------------------------------------------ |
| Timeshift snapshot verification | ✅ Complete | Daily timer, 3-day freshness threshold                             |
| Hermes NixOS module             | ✅ Complete | flake input, HM service, sops secrets (staged, not committed)      |
| Flake source filter             | ✅ Fixed    | dnsblockd uses `builtins.filterSource` — correctly includes go.sum |

### Session Services (Previous Work)

| Item                            | Status      | Details                                                    |
| ------------------------------- | ----------- | ---------------------------------------------------------- |
| Niri session save/restore       | ✅ Complete | 60s save interval, crash recovery, workspace-aware restore |
| AMD GPU crash cascade hardening | ✅ Complete | Systemd timeouts, watchdog, OOM protection                 |
| Voice agents systemd fix        | ✅ Complete | Timeout prefix instead of shell error suppression          |

---

## B) PARTIALLY DONE ⚠️

| Item                             | What's Done                                     | What's Missing                                                                                                                |
| -------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| **SigNoz dashboard**             | 13 panels for system metrics, Caddy, containers | No panels for dnsblockd, emeet-pixyd, Authelia, or AMD GPU metrics                                                            |
| **dnsblockd-processor CI**       | —                                               | No build, vet, or test coverage in any workflow                                                                               |
| **dnsblockd tests**              | —                                               | Zero test files; CI only runs `go build` + `go vet`                                                                           |
| **signoz-provision idempotency** | Deploys rules + dashboard on boot               | No deletion of stale rules; `                                                                                                 |     | true` swallows errors; creates duplicates on reboot |
| **Service metrics coverage**     | 6 of ~16 services have scrape targets           | 10 services have no metrics: gitea, immich, twenty, hermes, taskchampion, voice-agents, photomap, homepage, postgresql, redis |
| **Hermes integration**           | Module written + staged                         | Not committed; no metrics; no SigNoz alert; no Homepage card                                                                  |

---

## C) NOT STARTED ❌

| #   | Item                                        | Impact                                           | Effort                            |
| --- | ------------------------------------------- | ------------------------------------------------ | --------------------------------- |
| 1   | dnsblockd unit tests                        | High — 933 lines of untested Go code             | Medium                            |
| 2   | dnsblockd-processor unit tests              | Medium — 254 lines untested                      | Low                               |
| 3   | SigNoz dashboard panels for custom services | Medium — metrics exist but no visualization      | Medium                            |
| 4   | Gitea metrics endpoint + SigNoz scraping    | Medium — major service without monitoring        | Low (Gitea has built-in /metrics) |
| 5   | Immich metrics + SigNoz scraping            | Low — Docker service, limited prometheus support | Low                               |
| 6   | TaskChampion metrics                        | Low — simple sync server                         | Low                               |
| 7   | Voice-agents metrics                        | Low — AI agent session services                  | Low                               |
| 8   | Homepage card for Hermes                    | Low — service exists but no dashboard entry      | Low                               |
| 9   | NixOS build job in CI                       | Medium — only Darwin config is built in CI       | Medium                            |
| 10  | dnsblockd-processor CI job                  | Medium — no coverage at all                      | Low                               |
| 11  | SigNoz alert for GPU VRAM usage             | Low — data available via textfile collector      | Low                               |
| 12  | SigNoz alert for high DNS block rate        | Low — metric exists                              | Low                               |
| 13  | Idempotent signoz-provision                 | Medium — current approach creates duplicates     | Medium                            |
| 14  | Security-hardening.nix TODOs                | Low — audit rules disabled pending NixOS fixes   | Blocked upstream                  |
| 15  | PostgreSQL metrics (pg_exporter)            | Medium — database without monitoring             | Medium                            |

---

## D) TOTALLY FUCKED UP 💥

| #   | Issue                                             | Severity  | Details                                                                                         |
| --- | ------------------------------------------------- | --------- | ----------------------------------------------------------------------------------------------- |
| 1   | **Duplicate package definitions in flake.nix**    | 🔴 High   | 5 packages defined in BOTH `perSystem.packages` AND overlays — divergent builds possible        |
| 2   | **dnsblockd go.mod version mismatch**             | 🟡 Medium | `go.mod` says `go 1.23.0` but flake overlay pins Go 1.26.1 — may cause subtle incompatibilities |
| 3   | **signoz-provision silently swallows all errors** | 🟡 Medium | Every `curl` uses `                                                                             |     | true` — failed provisioning is invisible |
| 4   | **No `go test` for dnsblockd in CI**              | 🟡 Medium | dnsblockd job only runs `go build` + `go vet` — no actual test execution                        |
| 5   | **emeet-pixyd `go vet` issues unaddressed**       | 🟢 Low    | `strings.CutPrefix` simplification, unwrapped errors, function length                           |

---

## E) WHAT WE SHOULD IMPROVE 📈

### Architecture

1. **Eliminate duplicate package definitions** — Choose overlays OR perSystem.packages, not both. Current dual-definition risks divergent builds.
2. **Make signoz-provision idempotent** — Use PUT instead of POST, or check for existing resources before creating. Add proper error handling (remove `|| true`).
3. **Add Go tests for dnsblockd** — 933 lines of production Go code with zero test coverage is a risk.
4. **Standardize Go module versions** — dnsblockd `go.mod` says 1.23 but overlay pins 1.26. Align them.

### Observability

5. **Add dashboard panels for custom services** — dnsblockd and emeet-pixyd metrics are collected but not visualized.
6. **Enable Gitea's built-in Prometheus metrics** — Just needs `METRICS_ENABLED = true` in app.ini.
7. **Add pg_exporter for PostgreSQL** — Major dependency with no metrics.
8. **Add Redis exporter** — Immich depends on Redis, but no metrics exposed.

### CI

9. **Add NixOS build job** — Darwin config is built in CI but NixOS is not. Even a syntax-only check helps.
10. **Add dnsblockd-processor to CI** — No coverage at all currently.
11. **Add `go build` step for emeet-pixyd** — CI only runs tests, not a build verification.

### Security

12. **Audit remaining HTML templates** — The block page uses Go templates (safe), but review all `fmt.Fprintf` calls in dnsblockd for remaining injection vectors.
13. **Fix security-hardening.nix TODOs** — Two audit-related items disabled pending NixOS bug fixes.
14. **Add rate limiting to dnsblockd API endpoints** — temp-allow and false-positive endpoints have no rate limiting.

---

## F) TOP 25 THINGS TO DO NEXT 🎯

| Priority | Task                                                        | Effort |                                 Impact                                 |
| :------: | ----------------------------------------------------------- | :----: | :--------------------------------------------------------------------: |
|    1     | **Push 2 unpushed commits to origin**                       | 1 min  |                     Critical — code not backed up                      |
|    2     | **Deploy to evo-x2 and verify all changes**                 | 30 min |                   Critical — untested in production                    |
|    3     | **Verify metrics endpoints on live system**                 | 5 min  | High — `curl localhost:9090/metrics`, `:8090/metrics`, `:9100/metrics` |
|    4     | **Eliminate duplicate package defs in flake.nix**           | 30 min |                      High — divergent builds risk                      |
|    5     | **Write dnsblockd unit tests**                              | 2-3 hr |                       High — 933 lines untested                        |
|    6     | **Add SigNoz dashboard panels for dnsblockd + emeet-pixyd** |  1 hr  |                 Medium — data collected but invisible                  |
|    7     | **Make signoz-provision idempotent (PUT + error handling)** |  1 hr  |                     Medium — duplicates on reboot                      |
|    8     | **Enable Gitea built-in Prometheus metrics**                | 15 min |                   Medium — major service unmonitored                   |
|    9     | **Add pg_exporter for PostgreSQL monitoring**               |  1 hr  |                      Medium — database blind spot                      |
|    10    | **Add NixOS build job to CI**                               | 30 min |                   Medium — Darwin tested, NixOS not                    |
|    11    | **Commit hermes.nix (staged)**                              | 5 min  |                         Medium — work at risk                          |
|    12    | **Add dnsblockd-processor CI job**                          | 15 min |                         Medium — zero coverage                         |
|    13    | **Fix dnsblockd go.mod version (1.23 → 1.26)**              | 5 min  |                         Low — version mismatch                         |
|    14    | **Add Redis exporter for SigNoz**                           | 30 min |                         Low — cache blind spot                         |
|    15    | **Add GPU VRAM alert rule**                                 | 15 min |                      Low — data exists, no alert                       |
|    16    | **Add DNS block rate alert rule**                           | 15 min |                     Low — metric exists, no alert                      |
|    17    | **Add Homepage card for Hermes**                            | 10 min |                    Low — service exists, not listed                    |
|    18    | **Fix emeet-pixyd vet issues**                              | 15 min |                   Low — CutPrefix, unwrapped errors                    |
|    19    | **Add rate limiting to dnsblockd API**                      | 30 min |                          Low — no protection                           |
|    20    | **Add Prometheus metrics to hermes**                        |  1 hr  |                     Low — new service, no metrics                      |
|    21    | **Add voice-agents metrics**                                | 30 min |                   Low — session services unmonitored                   |
|    22    | **Add TaskChampion metrics**                                | 30 min |                     Low — sync server unmonitored                      |
|    23    | **Create SigNoz alert for high DNS block rate**             | 15 min |                       Low — proactive monitoring                       |
|    24    | **Add SigNoz Authelia panel to dashboard**                  | 15 min |                 Low — metrics exist, no visualization                  |
|    25    | **Review and update AGENTS.md**                             | 30 min |                      Low — missing recent changes                      |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**The `signoz-provision` service creates duplicate alert rules and dashboards on every reboot because it uses POST (create) instead of PUT (update).**

I need to know: **Does the SigNoz API support idempotent upsert via PUT/PATCH on `/api/v1/rules` and `/api/v1/dashboards`?** Or does it require a different approach (e.g., delete-then-create, or check-if-exists-then-update)? Without knowing the exact API semantics, I cannot make the provision service idempotent without risking data loss or duplication. The SigNoz API documentation for rule/dashboard management is the blocker here.

---

## Repository State

```
On branch master
Ahead of origin/master by 2 commits

Unpushed commits:
  b5ba48f feat(signoz): add GPU thermal, dnsblockd, and emeet-pixyd alert rules; fix dnsblockd CSS gradient
  3033750 fix(security): harden dnsblockd against XSS, fix node_exporter systemd collector, improve CI

Staged:
  modules/nixos/services/hermes.nix (+21/-4 lines)

Pre-existing uncommitted (from other work):
  (none beyond hermes.nix)
```

## SigNoz Alert Rules (7 total)

| Rule                           | Condition                                | Eval Interval |
| ------------------------------ | ---------------------------------------- | :-----------: |
| Disk Space Critical (>90%)     | filesystem usage > 90%                   |      5m       |
| CPU Sustained High (>90%)      | CPU idle < 10% for 15m                   |      5m       |
| Memory Critical (>90%)         | memory available < 10%                   |      5m       |
| Systemd Service Failed         | `node_systemd_units{state="failed"} > 0` |      1m       |
| GPU Thermal Throttling (>90°C) | `node_amdgpu_gpu_temp_celsius > 90`      |      5m       |
| DNS Blocker Down               | `up{job="dnsblockd"} != 1`               |      1m       |
| EMEET PIXY Daemon Down         | `up{job="emeet-pixyd"} != 1`             |      1m       |

## Prometheus Scrape Targets (6)

| Job           | Address        | Metrics Path |
| ------------- | -------------- | :----------: |
| node-exporter | 127.0.0.1:9100 |   /metrics   |
| cadvisor      | 127.0.0.1:9110 |   /metrics   |
| caddy         | 127.0.0.1:2019 |   /metrics   |
| authelia      | 127.0.0.1:9959 |   /metrics   |
| dnsblockd     | 127.0.0.1:9090 |   /metrics   |
| emeet-pixyd   | 127.0.0.1:8090 |   /metrics   |

## Custom Go Daemons — Line Counts

| Package             | Production |   Test    | Generated |   Total   |
| ------------------- | :--------: | :-------: | :-------: | :-------: |
| dnsblockd           |    933     |     0     |     0     |    933    |
| dnsblockd-processor |    254     |     0     |     0     |    254    |
| emeet-pixyd         |   3,069    |   2,660   |    720    |   6,449   |
| **Total**           | **4,256**  | **2,660** |  **720**  | **7,636** |

## CI Workflows Summary

| Workflow         | Jobs                                                              | Triggers                         |
| ---------------- | ----------------------------------------------------------------- | -------------------------------- |
| nix-check.yml    | 5 (check, build-darwin, syntax-check, go-test, go-test-dnsblockd) | push/PR to master                |
| flake-update.yml | 1 (update)                                                        | Weekly Monday 02:00 UTC + manual |
