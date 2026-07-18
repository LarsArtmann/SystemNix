# SigNoz NixOS Integration — Status Report

**Date:** 2026-04-03
**Status:** 🟡 IN PROGRESS — Architecture complete, builds not yet tested
**Goal:** Replace Prometheus + Grafana + Alertmanager with SigNoz (native NixOS packaging)

---

## What Is SigNoz

OpenTelemetry-native observability platform. Single app for metrics, traces, and logs. Replaces the need for separate Prometheus, Grafana, Loki, Tempo, and Alertmanager.

**Why:** Unified UI, ClickHouse backend (fast for high-cardinality data), OTel-native, one less stack to maintain.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        SigNoz Stack                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  signoz (binary)          signoz-otel-collector (binary)    │
│  ├── Go query-service     ├── Custom OTel Collector         │
│  └── Embedded React UI    └── ClickHouse exporters          │
│       │                        │                             │
│     Port 8080            Port 4317 (gRPC)                   │
│                          Port 4318 (HTTP)                    │
│       │                        │                             │
│       └────────────┬───────────┘                             │
│                    ↓                                         │
│             ClickHouse DB                                    │
│             Port 9000/8123                                   │
│             (signoz_metrics, signoz_traces, signoz_logs)     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Component Map

| Component                | Language | Source                                    | Version   | Purpose                              |
| ------------------------ | -------- | ----------------------------------------- | --------- | ------------------------------------ |
| `signoz`                 | Go 1.25  | `github.com/SigNoz/signoz`                | v0.117.1  | Query service + embedded frontend    |
| `signoz-otel-collector`  | Go 1.24  | `github.com/SigNoz/signoz-otel-collector` | v0.144.2  | Data ingestion (traces/metrics/logs) |
| `signoz-schema-migrator` | Go 1.24  | Same as collector                         | v0.144.2  | ClickHouse schema migrations         |
| `clickhouse`             | C++      | nixpkgs                                   | (nixpkgs) | Columnar database storage            |

### NixOS Systemd Services

| Service                    | Description                 | Dependencies         |
| -------------------------- | --------------------------- | -------------------- |
| `clickhouse.service`       | Database (managed by NixOS) | —                    |
| `signoz.service`           | Query service + web UI      | `clickhouse.service` |
| `signoz-collector.service` | OTel data ingestion         | `signoz.service`     |

---

## Files Created/Modified

### New Files

| File                                | Purpose                                           |
| ----------------------------------- | ------------------------------------------------- |
| `modules/nixos/services/signoz.nix` | Main module: packages + NixOS module (all-in-one) |
| `pkgs/signoz/README.md`             | Detailed documentation                            |
| `pkgs/signoz/nixos-module.nix`      | Old standalone module (superseded, can delete)    |

### Modified Files

| File            | Change                                                 |
| --------------- | ------------------------------------------------------ |
| `flake.nix:148` | Added `./modules/nixos/services/signoz.nix` to imports |

### Files From Earlier in Session (Not SigNoz)

| File                                             | Change                             |
| ------------------------------------------------ | ---------------------------------- |
| `platforms/nixos/desktop/ai-stack.nix`           | GPU detection fix, bash in PATH    |
| `flake.nix:278`                                  | Removed deprecated `system = null` |
| `platforms/nixos/system/dns-blocker-config.nix`  | Added `unsloth.lan` DNS entry      |
| `modules/nixos/services/gitea.nix`               | `COOKIE_SECURE = true`             |
| `modules/nixos/services/photomap.nix`            | Added PostgreSQL dependency        |
| `modules/nixos/services/ssh.nix`                 | Removed `ssh-rsa` algorithm        |
| `modules/nixos/services/homepage.nix`            | Fixed DNS health check             |
| `platforms/nixos/desktop/security-hardening.nix` | fail2ban jails for Gitea/Grafana   |
| `platforms/nixos/system/boot.nix`                | ZRAM capped at 25%                 |
| `platforms/nixos/system/dns-blocker-config.nix`  | Whitelist `deref-mail.com`         |

---

## Current State: What Works vs What Doesn't

### ✅ Done (Architecture)

- [x] Version compatibility matrix determined
- [x] Module structure follows existing `modules/nixos/services/` pattern
- [x] Integrated into main flake via `imports` (not standalone)
- [x] All-in-one module: packages + NixOS config in single file
- [x] NixOS module with `services.signoz.enable` option
- [x] Component toggles (clickhouse, queryService, otelCollector)
- [x] Systemd services with dependency ordering
- [x] Auto-generated OTel collector config
- [x] Firewall rules auto-configured
- [x] User/group management (`signoz:signoz`)
- [x] Documentation written

### ❌ Not Done (Build)

| #   | Blocker                                    | Effort    | How to Fix                                                                                          |
| --- | ------------------------------------------ | --------- | --------------------------------------------------------------------------------------------------- |
| 1   | **`signoz-src` sha256 is fake**            | 5 min     | Run fetch, copy real hash from error                                                                |
| 2   | **`signoz-collector-src` sha256 is fake**  | 5 min     | Run fetch, copy real hash from error                                                                |
| 3   | **`signoz` vendorHash is fake**            | 30 min    | Run `nix build`, copy hash from error                                                               |
| 4   | **`otelCollector` vendorHash is fake**     | 30 min    | Run `nix build`, copy hash from error                                                               |
| 5   | **`schemaMigrator` vendorHash is fake**    | 15 min    | Run `nix build`, copy hash from error                                                               |
| 6   | **Frontend yarn build untested**           | 30-60 min | May need `--no-lockfile` or `npm` instead                                                           |
| 7   | **Go module path may be wrong**            | 15 min    | v0.117.1 changed from `go.signoz.io/signoz` to `github.com/signoz/signoz` — ldflags may need update |
| 8   | **`subPackages` path untested**            | 15 min    | `"pkg/query-service"` must match go.mod structure                                                   |
| 9   | **CGO/sqlite linking untested**            | 15 min    | `CGO_ENABLED = 1` with `pkgs.sqlite` — may need extra flags                                         |
| 10  | **Full `nixos-rebuild switch` not tested** | 30 min    | After all hashes resolved                                                                           |

### Estimated Time to Complete

| Phase               | Time          | Description                                    |
| ------------------- | ------------- | ---------------------------------------------- |
| Fix source hashes   | 10 min        | `fetchTarball` sha256 for both repos           |
| Fix vendor hashes   | 60-90 min     | Iterative: build → error → copy hash → rebuild |
| Fix build errors    | 60-120 min    | Go module layout, frontend build, CGO          |
| Test NixOS module   | 30 min        | `nixos-rebuild switch`, verify services        |
| **Total remaining** | **3-4 hours** |                                                |

---

## Version Compatibility (Verified)

| Component               | Version      | Go Required | Source                                                    |
| ----------------------- | ------------ | ----------- | --------------------------------------------------------- |
| SigNoz                  | **v0.117.1** | Go 1.25.0   | `github.com/SigNoz/signoz` (Latest)                       |
| OTel Collector          | **v0.144.2** | Go 1.24.0   | `github.com/SigNoz/signoz-otel-collector` (Latest stable) |
| Schema Migrator         | **v0.144.2** | Go 1.24.0   | Same repo as collector                                    |
| Collector dep in SigNoz | v0.144.2     | —           | `go.mod` requires this exact version                      |

Verified from: `go.mod` files, `docker-compose.yaml` default tags, GitHub releases.

---

## Migration Plan (Prometheus/Grafana → SigNoz)

### Phase 1: Parallel Run (Current Goal)

```
Keep existing:          Add new:
├── Prometheus :9091    ├── SigNoz :8080
├── Grafana :3001       ├── OTel Collector :4317/:4318
├── Node Exporter       └── ClickHouse :9000
├── Postgres Exporter
└── Redis Exporter
```

- Don't remove Prometheus/Grafana yet
- SigNoz collector scrapes same exporters via `prometheusreceiver`
- Compare dashboards side-by-side

### Phase 2: Switch Over

- Point `grafana.lan` Caddy vhost to SigNoz
- Update Homepage dashboard links
- Remove `grafana.lan` DNS entry, add `signoz.lan`
- Remove Prometheus + Grafana from `monitoring.nix`
- Remove `modules/nixos/services/grafana.nix`

### Phase 3: Cleanup

- Delete old Prometheus/Grafana data
- Remove `monitoring.nix` flake-parts module
- Remove `grafana.nix` service module
- Update `homepage.nix` service list

---

## Risk Assessment

| Risk                            | Likelihood | Impact | Mitigation                                  |
| ------------------------------- | ---------- | ------ | ------------------------------------------- |
| Go vendor hash resolution fails | Medium     | Medium | Use `go mod vendor` manually                |
| Frontend build fails (yarn)     | Medium     | Low    | Use npm instead, or pre-built Docker assets |
| ClickHouse resource usage       | Low        | Medium | Cap at 8GB, monitor                         |
| SigNoz query-service crashes    | Low        | High   | Keep Prometheus as fallback until stable    |
| OTel Collector plugin missing   | Low        | Medium | Standard collector has most plugins         |
| NixOS module bugs               | Medium     | Low    | Systemd `Restart = on-failure`              |

---

## Resource Impact (Projected)

| Component | Current (Prometheus/Grafana) | With SigNoz | Delta    |
| --------- | ---------------------------- | ----------- | -------- |
| RAM       | ~200MB                       | ~4-6GB      | +4-6GB   |
| Disk      | ~1GB                         | ~50GB       | +49GB    |
| CPU       | Negligible                   | ~2 cores    | +2 cores |

**System:** AMD Strix Halo 128GB RAM, 16+ cores — plenty of headroom.

---

## Open Questions

1. **Keep `grafana.lan` DNS or rename to `signoz.lan`?**
   - Currently `grafana.lan` in Caddy and DNS
   - Option: add `signoz.lan` now, remove `grafana.lan` after migration

2. **ClickHouse data directory?**
   - Default: `/var/lib/clickhouse` (NixOS managed)
   - Alternative: `/data/clickhouse` (like Docker setup)
   - Recommendation: default is fine

3. **OTel Collector config location?**
   - Currently auto-generated at `/etc/signoz/collector.yaml`
   - May want persistent config at `/var/lib/signoz/collector.yaml`

4. **Old `pkgs/signoz/` directory cleanup?**
   - `pkgs/signoz/nixos-module.nix` — superseded by `modules/nixos/services/signoz.nix`
   - `pkgs/signoz/README.md` — still accurate but references standalone flake
   - Action: clean up after integration complete

---

## Next Session Instructions

1. **Fix source hashes:**

   ```bash
   nix-prefetch-url --unpack https://github.com/SigNoz/signoz/archive/refs/tags/v0.117.1.tar.gz
   nix-prefetch-url --unpack https://github.com/SigNoz/signoz-otel-collector/archive/refs/tags/v0.144.2.tar.gz
   ```

2. **Get Go vendor hashes (iterative):**

   ```bash
   cd /home/lars/projects/SystemNix
   nix build .#signoz 2>&1 | grep "got:"  # Copy vendor hash
   # Edit signoz.nix, replace fakeHash, repeat for each component
   ```

3. **Fix build errors** as they appear (Go module layout, frontend, CGO)

4. **Test NixOS module:**

   ```bash
   nh os switch .
   ```

5. **Clean up:**
   - Remove `pkgs/signoz/nixos-module.nix` (superseded)
   - Update `pkgs/signoz/README.md` to reflect integrated structure
   - Add `signoz.lan` to DNS and Caddy
   - Update `homepage.nix` with SigNoz entry
