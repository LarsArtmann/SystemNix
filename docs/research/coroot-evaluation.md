# Coroot for SystemNix — PRO / CONTRA Analysis

**Date:** 2026-04-05
**Evaluated by:** Crush (AI Assistant)
**Decision:** **NOT RECOMMENDED** as SigNoz replacement; **MAYBE** as complementary profiling layer (see conclusion)

---

## 1. What is Coroot?

Coroot is an open-source (Apache 2.0) eBPF-based observability and APM platform that provides **zero-instrumentation** monitoring of metrics, logs, traces, and continuous profiling. It uses eBPF to automatically collect telemetry from the kernel level — no code changes, no SDK integration, no OpenTelemetry instrumentation required.

| Aspect | Detail |
|--------|--------|
| **License** | Apache 2.0 (Community) / Commercial (Enterprise) |
| **Language** | Go (58.7%) + Vue.js (39.1%) |
| **GitHub** | 7.5k stars, 356 forks, actively maintained |
| **Current Version** | v1.19.0 (April 3, 2026) |
| **Key Tech** | eBPF, ClickHouse, Prometheus, CO-RE |
| **Deployment** | Kubernetes (primary), Docker Compose, systemd (Ubuntu/RHEL) |

### Core Capabilities

| Feature | Description |
|---------|-------------|
| **Zero-Instrumentation Metrics** | eBPF-based RED (Rate, Errors, Duration) for any TCP service |
| **Distributed Tracing** | Auto-tracing via eBPF + OpenTelemetry compatibility |
| **Log Management** | Auto-collection with pattern extraction, ClickHouse-backed |
| **Continuous Profiling** | On-CPU/Off-CPU profiling at <1% overhead (Go, Java, Python) |
| **Service Map** | 100% automatic topology from eBPF network tracing |
| **SLO Monitoring** | Built-in availability + latency SLOs with burn-rate alerting |
| **Database Monitoring** | Auto-discovers Postgres, MySQL, Redis, MongoDB, Memcached |
| **AI Root Cause Analysis** | Automated RCA (Enterprise only, $1/CPU core/month) |
| **30+ Protocol Detection** | HTTP, gRPC, MySQL, PostgreSQL, Redis, Kafka, DNS, etc. |

### Architecture

```
coroot-node-agent (per node, privileged, eBPF)
  ├── metrics  → Prometheus Remote Write
  ├── logs     → OTLP/HTTP → Coroot Server → ClickHouse
  ├── traces   → OTLP/HTTP → Coroot Server → ClickHouse
  └── profiles → Custom HTTP → Coroot Server → ClickHouse

coroot-cluster-agent (cluster-level)
  ├── Database metrics (Postgres, MySQL, Redis, MongoDB)
  └── Go application profiling

Coroot Server
  ├── On-disk metric cache (refreshed from Prometheus)
  ├── UI / API (Vue.js frontend)
  └── Metadata: SQLite (single) / Postgres (HA)
```

---

## 2. Current SystemNix Observability Stack

| Component | Role | Status |
|-----------|------|--------|
| **SigNoz v0.117.1** | Query service + UI | Active, custom NixOS module (333 lines) |
| **SigNoz OTel Collector v0.144.2** | Trace/metric/log ingestion (OTLP) | Active, built from source |
| **ClickHouse** | Storage backend (3 DBs: metrics, traces, logs) | Active, managed by SigNoz module |
| **Caddy** | Reverse proxy at `signoz.lan` | Active, TLS + Authelia SSO |
| **Homepage** | Service dashboard listing | Active |

**What SigNoz provides today:**
- Traces, metrics, and logs via OpenTelemetry (OTLP gRPC:4317 / HTTP:4318)
- ClickHouse-backed storage with three dedicated databases
- SQLite metadata store (zero-maintenance)
- Custom NixOS systemd services, fully declarative
- Proxied through Caddy with Authelia authentication
- Built from source via flake inputs

**What SigNoz does NOT provide:**
- eBPF-based zero-code instrumentation
- Continuous profiling (On-CPU/Off-CPU)
- Automatic service map without instrumentation
- Network-level observability / protocol parsing
- Kernel-level tracing
- Database auto-discovery and monitoring

**Critical gap:** No exporters are running. SigNoz's OTel collector receives OTLP data, but nothing scrapes system metrics (no node_exporter, no cAdvisor). Authelia and Caddy expose Prometheus metrics but nothing collects them. The observability pipeline has no data producers.

---

## 3. Coroot vs SigNoz — Feature Comparison

| Feature | Coroot | SigNoz (Current) |
|---------|--------|-------------------|
| **Traces** | ✅ Auto (eBPF) + OTLP ingest | ✅ OTLP ingest only |
| **Metrics** | ✅ Auto (eBPF RED) + Prometheus | ✅ OTLP ingest only |
| **Logs** | ✅ Auto (eBPF) + OTLP | ✅ OTLP ingest only |
| **Profiling** | ✅ OnCPU/OffCPU <1% overhead | ❌ Not supported |
| **Auto-instrumentation** | ✅ Zero-code (eBPF) | ❌ Requires SDK/instrumentation |
| **Service Map** | ✅ Automatic, 100% coverage | ⚠️ Requires trace data |
| **Protocol parsing** | ✅ 30+ protocols auto-detected | ❌ OTLP only |
| **SLO Monitoring** | ✅ Built-in with burn-rate alerts | ⚠️ Threshold-based only |
| **Database Monitoring** | ✅ Auto-discovers 5+ DB types | ❌ Manual instrumentation |
| **ClickHouse storage** | ✅ (required, own schema) | ✅ (already running, own schema) |
| **Root Cause Analysis** | ✅ AI-powered (Enterprise) | ❌ Manual investigation |
| **Real User Monitoring** | ❌ Not available | ✅ Basic Core Web Vitals |
| **License** | Apache 2.0 / Commercial | Apache 2.0 / BSL |
| **NixOS module** | ❌ None (packages exist in nixpkgs) | ✅ Custom-built (333 lines) |
| **Single-machine deploy** | ⚠️ Docker Compose / systemd | ✅ Native systemd |
| **Maturity** | v1.19, 7.5k stars | v0.117, growing adoption |
| **Pricing (Enterprise)** | $1/CPU core/month | Usage-based |

---

## 4. PRO Arguments

### 4.1 Zero-Code Observability — Solves the "No Exporters" Problem
The single biggest win. Coroot's eBPF agent automatically instruments **every service on the machine** — Gitea, Immich, Caddy, Authelia, Docker containers, systemd services — without any SDK, config, or code changes. This directly addresses the critical gap in the current stack where SigNoz has no data producers.

### 4.2 Automatic Service Map
100% coverage of all inter-service communication. For a homelab running 8+ services behind Caddy, this provides instant visibility into who calls whom, latency, and error rates — including the Unbound → dnsblockd stack, Caddy → backend routing, and Docker container networking.

### 4.3 Continuous Profiling
SigNoz has zero profiling capability. Coroot provides always-on On-CPU and Off-CPU profiling at <1% overhead. On a machine with an AMD Ryzen AI Max+ 395 (16 cores, 128GB) running AI workloads, this could reveal performance bottlenecks in model inference, ClickHouse queries, or service contention.

### 4.4 Database Auto-Discovery
Coroot's cluster-agent automatically discovers and monitors Postgres, MySQL, Redis, MongoDB, and Memcached. While the current stack doesn't use these heavily (SigNoz uses SQLite + ClickHouse), this is valuable if database services are added later.

### 4.5 30+ Protocol Parsing
Automatic detection and parsing of HTTP, gRPC, MySQL, PostgreSQL, Redis, Kafka, DNS, and more. This provides application-layer visibility into:
- Caddy reverse proxy latency per backend
- ClickHouse query performance
- DNS resolution timing (relevant: Unbound + dnsblockd)
- Inter-service HTTP calls

### 4.6 Packages Exist in nixpkgs
Unlike DeepFlow (which had zero packaging), Coroot has:
- `coroot` package (v1.17.9) — the main server
- `coroot-node-agent` package (v1.30.0) — the eBPF agent
- Both maintained by the same person (@errnoh)
- Both build with `buildGoModule`

This significantly lowers the integration barrier compared to DeepFlow.

### 4.7 Built-in SLO Monitoring
Availability and latency SLOs with multi-window burn-rate alerting. SigNoz only has threshold-based alerting. SLOs provide a more sophisticated incident detection framework.

### 4.8 ClickHouse Already Running
Both Coroot and SigNoz use ClickHouse. While they can't share databases (different schemas), the infrastructure knowledge and operational patterns transfer.

---

## 5. CONTRA Arguments

### 5.1 ❌ No NixOS Service Module Exists
While packages exist in nixpkgs, **no NixOS service module** exists for either `coroot` or `coroot-node-agent`. You would need to write:

1. **`services.coroot` NixOS module** — systemd service for the Coroot server, ClickHouse schema management, Prometheus configuration, user/group setup, firewall rules (~150-200 lines)
2. **`services.coroot-node-agent` NixOS module** — systemd service for the privileged eBPF agent with kernel module dependencies, cgroup mounts, debugfs/tracefs access (~100-150 lines)
3. **`services.coroot-cluster-agent` NixOS module** — optional, for database discovery (~80-100 lines)
4. **Integration wiring** — Caddy reverse proxy, Homepage entry, Authelia SSO, DNS record

**Estimated effort:** 350-500 lines of Nix, plus ongoing maintenance. Less than DeepFlow (which needed 500-800) because packages exist, but still substantial.

### 5.2 ❌ eBPF Agent Compatibility with NixOS is Uncertain
The `coroot-node-agent` requires:
- Linux kernel 5.1+ with BTF support (`CONFIG_DEBUG_INFO_BTF=y`)
- Access to `/sys/kernel/debug`, `/sys/kernel/tracing`, `/sys/fs/cgroup`
- Privileged execution with host PID namespace
- CO-RE (Compile Once – Run Everywhere) support

NixOS uses a custom kernel configuration. While `linuxPackages_latest` likely includes BTF, **this is untested territory**. No documentation, no GitHub issues, no community reports of running Coroot on NixOS exist. The agent's eBPF programs may fail to load if NixOS kernel is missing required tracepoints or BTF data.

**Risk:** High. eBPF compatibility is a hard requirement — without it, Coroot has no data.

### 5.3 ❌ Kubernetes-First Architecture on a Single Machine
Coroot's design is Kubernetes-native. Non-K8s deployment options:
- **Docker Compose:** Supported, but runs as containers (not native NixOS services)
- **systemd (Ubuntu/RHEL):** Install scripts target FHS paths (`/usr/local/bin`, `/etc/systemd/system`) — incompatible with NixOS

Running Coroot via Docker Compose means:
- Container overhead on top of Docker (already used for PhotoMap + Gitea Actions)
- Separate networking from native NixOS services
- Different log management, restart policies, and monitoring
- Fighting the tool's primary design intent

### 5.4 ❌ Duplicate ClickHouse = Significant Overlap
Coroot requires its own ClickHouse databases (separate schema from SigNoz). Running both means:

| Aspect | Impact |
|--------|--------|
| Memory | ClickHouse is already running; two logical tenants on one instance |
| Disk | Coroot stores logs, traces, profiles, and metrics (7-day default TTL) |
| Schema conflicts | Both manage their own tables — must use separate databases |
| Backup complexity | Two sets of databases to backup and restore |
| Operational overhead | Two tools managing the same ClickHouse instance |

The machine has 128GB RAM, so resources aren't the blocker — but the operational complexity is real.

### 5.5 ❌ Prometheus Requirement Adds Another Component
Coroot requires Prometheus (or VictoriaMetrics) for metrics storage, even in non-K8s deployments. The current stack intentionally removed Prometheus (see incident doc `docs/status/2026-04-05_05-59_PROMETHEUS-REMOVAL-INTERNET-LOSS-INCIDENT.md`). Adding it back for Coroot contradicts that decision.

### 5.6 ❌ Single Machine Diminishes Core Value
Coroot's superpowers — distributed tracing correlation, multi-node service maps, cross-AZ network visibility — shine in **multi-node environments**. On a single NixOS machine:
- All inter-service communication is localhost (negligible latency)
- Service map is small (8-10 services)
- eBPF tracing overhead provides marginal benefit over direct OTLP instrumentation
- No cross-node network issues to debug
- No deployment rollouts to track (no Kubernetes)

### 5.7 ❌ Significant Overlap with SigNoz
Running both would mean:
- Two UIs for traces, metrics, and logs
- Two alerting systems
- Two data pipelines into ClickHouse
- Two sets of dashboards
- Confusion about which tool is the "source of truth"

The overlap is ~70%. The only genuinely new capabilities are profiling, auto-instrumentation, and service map — which could be obtained more cheaply.

### 5.8 ❌ Enterprise Features Behind Paywall
The most compelling feature — AI-powered Root Cause Analysis — is Enterprise-only ($1/CPU core/month). For a 16-core machine, that's $16/month. Community edition provides:
- ✅ eBPF observability, service maps, SLOs, profiling
- ❌ AI RCA, SSO/SAML/OIDC, RBAC, 24/7 support

Since SigNoz is already behind Authelia SSO, losing SSO for Coroot is a regression.

### 5.9 ❌ nixpkgs Version Lag
nixpkgs packages are at v1.17.9, while upstream is v1.19.0. The agent is at v1.30.0. Version mismatches between server and agent can cause incompatibilities. Maintaining up-to-date packages requires either waiting for nixpkgs updates or maintaining overlay overrides.

---

## 6. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| eBPF agent fails on NixOS kernel | High | Critical | Test manually before investing in module |
| No NixOS module = ongoing maintenance | High | Medium | Automate with flake-parts pattern |
| ClickHouse schema conflicts with SigNoz | Low | High | Separate databases (already default) |
| Resource contention with AI workloads | Low | Low | 128GB RAM is sufficient |
| Docker Compose instability | Medium | Medium | Restart policies, health checks |
| Prometheus re-introduction causes port conflicts | Medium | High | Use VictoriaMetrics or custom port |
| nixpkgs version lag breaks server-agent compat | Medium | Medium | Pin versions, test before updating |

---

## 7. Comparison with Previous Evaluations

| Aspect | DeepFlow | Coroot | SigNoz (Current) |
|--------|----------|--------|-------------------|
| **nixpkgs packages** | ❌ None | ✅ Server + Agent exist | ✅ Custom-built |
| **NixOS module** | ❌ None | ❌ None | ✅ 333-line custom module |
| **Estimated Nix effort** | 500-800 lines | 350-500 lines | Already done |
| **eBPF zero-code** | ✅ | ✅ | ❌ |
| **Profiling** | ✅ GPU + CPU | ✅ CPU (Go, Java, Python) | ❌ |
| **Requires MySQL** | ✅ (blocker) | ❌ (SQLite/Postgres) | ❌ (SQLite) |
| **Requires Prometheus** | ❌ (own TSDB) | ✅ (or VictoriaMetrics) | ❌ (ClickHouse direct) |
| **Single-machine fit** | Poor | Moderate | Excellent |
| **NixOS kernel compat risk** | Unknown | Unknown (high) | None |

**Coroot is a better fit than DeepFlow** (packages exist, no MySQL, less Nix effort), but shares the same fundamental blockers: no NixOS module, eBPF uncertainty, and single-machine diminishing returns.

---

## 8. Alternative Approaches

### Option A: Add Coroot Agent Only — Send OTLP to SigNoz (Best if anything)
Run only the `coroot-node-agent` via Docker or systemd, configuring it to export traces and metrics via OTLP to the existing SigNoz collector. This gives you:
- ✅ eBPF-based auto-instrumentation
- ✅ Service map in SigNoz
- ✅ No new UI, no Prometheus, no duplicate ClickHouse
- ❌ No profiling (that requires Coroot server + ClickHouse)
- ❌ Agent may not support standalone OTLP export (designed to talk to Coroot server)

**Risk:** Coroot's agent is designed to talk to the Coroot server, not generic OTLP collectors. OTLP export may be limited.

### Option B: Grafana Pyroscope for Profiling Only
If profiling is the main interest, Pyroscope provides continuous profiling and is available in nixpkgs. It can integrate with existing Grafana (if re-added) or run standalone. Much lighter weight than a full Coroot deployment.

### Option C: Add OTel SDK Instrumentation to Critical Services
Instead of eBPF, add OpenTelemetry SDK instrumentation to the services that matter most (Caddy, Gitea, Immich). This feeds better data into the existing SigNoz stack. Zero new infrastructure.

### Option D: Write NixOS Module for Coroot (Full Commit)
Write the full `services.coroot` and `services.coroot-node-agent` NixOS modules. Run alongside SigNoz. ~350-500 lines of Nix. Addresses the "no exporters" gap comprehensively but adds significant complexity.

### Option E: Replace SigNoz with Coroot Entirely
Remove SigNoz, replace with Coroot. Single observability tool, no overlap. **Not recommended** — loses SigNoz's mature OTel pipeline, custom NixOS integration, and existing ClickHouse data.

### Option F: Add node_exporter + cAdvisor to SigNoz (Lowest Effort)
The simplest fix for the "no data producers" gap: add `node_exporter` and `cAdvisor` as Prometheus-style exporters, configure SigNoz's OTel collector to scrape them. No eBPF, no new stack, but provides basic system and container metrics.

---

## 9. Verdict Matrix

| Criterion | Weight | Coroot Score | Notes |
|-----------|--------|-------------|-------|
| Feature value for homelab | 20% | 6/10 | Excellent tech, but single-machine limits value |
| NixOS integration feasibility | 25% | 5/10 | Packages exist but no module; eBPF untested on NixOS |
| Resource efficiency | 10% | 6/10 | ClickHouse overlap is wasteful but 128GB absorbs it |
| Maintenance burden | 15% | 4/10 | No NixOS module, version lag in nixpkgs, Docker Compose |
| Overlap with SigNoz | 15% | 3/10 | ~70% overlap; two stacks = confusion |
| Operational complexity | 15% | 4/10 | Prometheus re-addition, duplicate ClickHouse, new UI |
| **Weighted Total** | **100%** | **4.55/10** | **Not recommended as-is** |

---

## 10. Conclusion

### Recommendation: **DO NOT ADD** Coroot at this time.

**Reasoning:**

Coroot is technically superior to SigNoz in observability depth — its eBPF-based zero-code instrumentation, automatic service maps, continuous profiling, and built-in SLO monitoring are genuinely impressive. It addresses the critical "no exporters" gap in the current stack perfectly.

However, for this specific homelab setup, the **integration cost outweighs the benefit**:

1. **No NixOS service module** means 350-500 lines of custom Nix to write and maintain, against a rapidly evolving upstream
2. **eBPF on NixOS is untested** — the agent may simply fail on NixOS's custom kernel, and there's zero community evidence it works
3. **Kubernetes-first architecture** fights the single-node NixOS design; Docker Compose is the only viable path
4. **SigNoz already works** and covers traces/metrics/logs natively with a mature NixOS integration
5. **Single machine** diminishes the core value proposition — distributed tracing and multi-node service maps are Coroot's killer features
6. **Prometheus re-introduction** contradicts the explicit decision to remove it (incident 2026-04-05)
7. **70% feature overlap** with SigNoz means running two parallel observability stacks

**Coroot is a better candidate than DeepFlow** (packages exist in nixpkgs, no MySQL requirement, less Nix effort), but shares the same fundamental problems: no NixOS module, eBPF kernel uncertainty, and single-machine diminishing returns.

### When to reconsider:
- Coroot gets a NixOS service module (upstream or community)
- eBPF agent is verified to work on NixOS's kernel
- You move to a multi-node setup where distributed tracing matters
- SigNoz becomes insufficient and you're willing to replace it entirely
- You need profiling urgently (consider Pyroscope as a lighter alternative first)

### Immediate alternatives (ranked by effort/value):
1. **Add `node_exporter` + `cAdvisor` to SigNoz** — fixes the "no data" gap with minimal effort
2. **Add OTel SDK instrumentation to critical services** — better SigNoz data, no new infrastructure
3. **Try Grafana Pyroscope for profiling** — lightweight, in nixpkgs, addresses the profiling gap
4. **Test coroot-node-agent standalone on NixOS** — validate eBPF compatibility before committing

---

_Report generated for the SystemNix project. Re-evaluate when NixOS module or eBPF compatibility status changes._
