# DeepFlow for SystemNix — PRO / CONTRA Analysis

**Date:** 2026-04-05
**Evaluated by:** Crush (AI Assistant)
**Decision:** **NOT RECOMMENDED** at this time (see conclusion)

---

## 1. What is DeepFlow?

DeepFlow is an open-source (Apache 2.0) eBPF-based observability platform that provides **zero-code** distributed tracing, metrics, logging, and continuous profiling. It uses eBPF to automatically instrument applications without any code changes or SDK integration.

| Aspect | Detail |
|--------|--------|
| **License** | Apache 2.0 (Community Edition) |
| **Language** | Go (53.5%) + Rust (34.4%) |
| **GitHub** | 4k+ stars, actively maintained |
| **Key Tech** | eBPF, ClickHouse, SmartEncoding |
| **Deployment** | Kubernetes (primary), Docker Compose (non-prod) |

### Core Capabilities

| Feature | Description |
|---------|-------------|
| **AutoMetrics** | Zero-code RED (Rate, Errors, Duration) metrics via eBPF for any language |
| **AutoTracing** | Distributed tracing without TraceID injection — correlates via eBPF events |
| **AutoProfiling** | Continuous On-CPU/Off-CPU/GPU/Memory profiling at <1% overhead |
| **AutoTagging** | Automatic injection of cloud/K8s/process tags into all signals |
| **SmartEncoding** | 10x storage reduction vs standard ClickHouse tag storage |
| **Protocol Support** | 30+ protocols (HTTP, gRPC, MySQL, Redis, Kafka, DNS, etc.) + Wasm plugins |

---

## 2. Current SystemNix Observability Stack

| Component | Role | Status |
|-----------|------|--------|
| **SigNoz v0.117.1** | Query service + UI | Active, custom NixOS module, built from source |
| **SigNoz OTel Collector v0.144.2** | Trace/metric/log ingestion (OTLP) | Active, built from source |
| **ClickHouse** | Storage backend | Active, managed by SigNoz module |
| **Caddy** | Reverse proxy at `signoz.lan` | Active, TLS + Authelia SSO |
| **Homepage** | Service dashboard listing | Active |

**What SigNoz provides today:**
- Traces, metrics, and logs via OpenTelemetry (OTLP on gRPC:4317 / HTTP:4318)
- ClickHouse-backed storage with three databases (`signoz_metrics`, `signoz_traces`, `signoz_logs`)
- SQLite for SigNoz metadata
- Custom NixOS systemd services (333-line module)
- Proxied through Caddy with Authelia authentication
- Built from source via flake inputs

**What SigNoz does NOT provide:**
- eBPF-based zero-code instrumentation
- Continuous profiling (On-CPU/Off-CPU/GPU)
- Automatic service map without instrumentation
- Network-level observability
- Kernel-level tracing

---

## 3. DeepFlow vs SigNoz — Feature Comparison

| Feature | DeepFlow | SigNoz (Current) |
|---------|----------|-------------------|
| **Traces** | ✅ Auto (eBPF) + OTLP ingest | ✅ OTLP ingest only |
| **Metrics** | ✅ Auto (eBPF RED) + Prometheus | ✅ OTLP ingest only |
| **Logs** | ✅ Flow logs (auto) + OTLP | ✅ OTLP ingest only |
| **Profiling** | ✅ OnCPU/OffCPU/GPU/Memory | ❌ Not supported |
| **Auto-instrumentation** | ✅ Zero-code (eBPF) | ❌ Requires SDK/instrumentation |
| **Service Map** | ✅ Automatic | ⚠️ Requires trace data |
| **Protocol parsing** | ✅ 30+ protocols auto-detected | ❌ OTLP only |
| **ClickHouse storage** | ✅ (required) | ✅ (already running) |
| **Storage efficiency** | ✅ SmartEncoding (10x) | ⚠️ Standard ClickHouse |
| **Grafana integration** | ✅ Native plugin | ❌ Own UI |
| **PromQL support** | ✅ Built-in | ❌ No |
| **GPU profiling** | ✅ CUDA support | ❌ No |
| **License** | Apache 2.0 | Apache 2.0 / BSL |
| **NixOS module** | ❌ None exists | ✅ Custom-built (333 lines) |
| **Single-machine deploy** | ⚠️ Docker Compose (limited) | ✅ Native systemd |
| **Maturity** | v6.x, CNCF landscape | v0.117, growing adoption |

---

## 4. PRO Arguments

### 4.1 Zero-Code Observability is a Game Changer
DeepFlow's eBPF approach means **every service on the machine gets traced automatically** — no SDK integration, no code changes, no OpenTelemetry instrumentation needed. For a homelab running diverse services (Gitea, Immich, Caddy, Docker containers), this would provide instant visibility into inter-service communication, latency, and errors across the entire stack.

### 4.2 Continuous Profiling
SigNoz has no profiling capability. DeepFlow provides On-CPU, Off-CPU, GPU, Memory, and Network profiling at <1% overhead. On a machine with an AMD Ryzen AI Max+ 395 and 128GB unified memory running AI workloads, GPU profiling could be **particularly valuable** for optimizing model inference and training pipelines.

### 4.3 Network-Level Observability
DeepFlow captures flow logs at the TCP/UDP level and can parse 30+ application-layer protocols automatically. This means visibility into:
- DNS query performance (relevant: Unbound + dnsblockd stack)
- Database query latency (ClickHouse, SQLite)
- Inter-service HTTP/gRPC calls
- External API calls from any service

### 4.4 SmartEncoding Storage Efficiency
10x storage reduction via SmartEncoding could significantly reduce ClickHouse storage requirements, especially important on a single-machine BTRFS setup.

### 4.5 GPU Profiling for AI Stack
The machine runs an AI stack (`desktop/ai-stack.nix`) with AMD GPU/NPU. DeepFlow's CUDA/GPU profiling support (even if AMD support is evolving) could provide insights into AI workload performance.

### 4.6 Complementary, Not Replacement
DeepFlow could coexist with SigNoz — it can export data via OTLP to SigNoz, or SigNoz could be kept as the alerting/dashboard layer while DeepFlow provides the data collection layer.

---

## 5. CONTRA Arguments

### 5.1 ❌ NO NixOS Packaging Exists
**This is the single biggest blocker.** DeepFlow has:
- No nixpkgs package
- No NixOS module
- No community flake
- No GitHub issues/PRs for Nix packaging

**Impact:** You would need to build and maintain a custom NixOS module from scratch, similar to the SigNoz module (333 lines) but significantly more complex because DeepFlow has **more components** (server with 4 sub-modules, agent, MySQL, ClickHouse, Grafana).

**Estimated effort:** 500-800 lines of Nix to create a proper module, plus ongoing maintenance against DeepFlow's rapid release cadence.

### 5.2 ❌ Kubernetes-First Architecture
DeepFlow's server is designed for Kubernetes. The "standalone" option is Docker Compose, which:
- Is explicitly **not recommended for production** by DeepFlow docs
- Does not support HA or leader election
- Limits ClickHouse to single-shard
- Requires Docker (already available via `/data/docker`)

**Your machine is a single-node NixOS box, not K8s.** Running DeepFlow server via Docker Compose works but fights the tool's design.

### 5.3 ❌ Additional Resource Consumption
DeepFlow adds significant resource overhead:

| Component | CPU | RAM | Disk |
|-----------|-----|-----|------|
| DeepFlow Server | 2-4 cores | 4-8 GB | Varies |
| DeepFlow Agent | 0.5-2 cores | 1-4 GB | Minimal |
| MySQL (required) | 0.5-1 core | 1-2 GB | Varies |
| **Total additional** | **3-7 cores** | **6-14 GB** | **Varies** |

Your machine has 128GB RAM and a 16-core CPU, so **resources aren't the blocker** — but it's a lot of overhead for a homelab observability stack when SigNoz already runs.

### 5.4 ❌ Requires MySQL
SigNoz uses SQLite for metadata (zero operational overhead). DeepFlow **requires MySQL 8.0+** for configuration, metadata, and Grafana data. This adds another database to manage, backup, and maintain.

### 5.5 ❌ Duplicate ClickHouse Instance
DeepFlow requires its own ClickHouse databases (`deepflow_system`, `event`, `ext_metrics`, `flow_log`, `flow_metrics`, `flow_tag`, `profile`). SigNoz already runs ClickHouse. Running two ClickHouse instances (or two logical sets of databases) increases:
- Memory pressure
- Disk usage
- Operational complexity
- Backup burden

### 5.6 ❌ Rapid Release Cadence = Maintenance Burden
DeepFlow releases frequently. Without nixpkgs packaging, every update requires manual flake input bumps, potential build fixes, and vendor hash updates. The SigNoz module already demonstrates this pain (Go 1.25 override, custom build flags).

### 5.7 ❌ eBPF Kernel Requirements
Full eBPF features require Linux kernel 4.14+. The machine runs `linuxPackages_latest` which is fine, but:
- AutoTracing requires kernel 4.14+
- AutoProfiling requires kernel 4.9+
- Some advanced features may need specific kernel configs

**However:** The machine uses `linuxPackages_latest` and `amd_iommu=off`, so this is likely fine.

### 5.8 ❌ Single-Machine Diminishes Value
DeepFlow's superpowers shine in **multi-service, multi-node environments** where correlating traces across machines is critical. On a single machine:
- Service-to-service communication is local (localhost)
- Network latency is negligible
- The service map is small (maybe 8-10 services)
- eBPF tracing overhead provides marginal benefit over OTLP SDK tracing

### 5.9 ❌ SigNoz is Already Working
The existing SigNoz stack is:
- Fully integrated into NixOS via a custom flake-parts module
- Proxied through Caddy with Authelia SSO
- Listed on Homepage dashboard
- Running ClickHouse with embedded Keeper
- Backed by SQLite (zero-maintenance metadata store)

Adding DeepFlow would mean running **two observability stacks in parallel** or replacing SigNoz entirely (losing all existing dashboards, alerts, and configuration).

---

## 6. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Nix packaging breaks on update | High | High | Pin versions, extensive testing |
| Docker Compose server instability | Medium | High | Monitor, restart policies |
| Resource contention with AI workloads | Low | Medium | Resource limits on Docker |
| ClickHouse storage bloat | Medium | Medium | Retention policies, SmartEncoding |
| MySQL operational overhead | Low | Medium | Automated backups |
| eBPF conflicts with kernel params | Low | High | Test before production use |

---

## 7. Alternative Approaches

### Option A: Add Only DeepFlow Agent (Recommended if anything)
Run the DeepFlow agent in Docker, sending data to the existing SigNoz OTel Collector. This gives you eBPF-based collection without the DeepFlow server overhead. **However:** DeepFlow agent is designed to talk to DeepFlow server, not generic OTLP collectors — integration may be limited.

### Option B: Grafana Pyroscope for Profiling
If profiling is the main interest, Grafana Pyroscope provides continuous profiling and can integrate with SigNoz/Grafana. Lighter weight, available in nixpkgs.

### Option C: Parca for eBPF Profiling
Parca is an open-source eBPF-based continuous profiling tool. Simpler scope than DeepFlow, could complement SigNoz for profiling specifically.

### Option D: Wait for NixOS Packaging
Watch for community packaging efforts. Once DeepFlow is in nixpkgs (or has a mature community flake), the integration cost drops dramatically.

### Option E: Enhance SigNoz Instrumentation
Instead of adding DeepFlow, add OpenTelemetry SDK instrumentation to the services that matter most. This gives better traces in SigNoz without a new stack.

---

## 8. Verdict Matrix

| Criterion | Weight | DeepFlow Score | Notes |
|-----------|--------|---------------|-------|
| Feature value for homelab | 20% | 7/10 | Impressive tech, but single-machine limits value |
| NixOS integration feasibility | 25% | 2/10 | No packaging exists, massive effort required |
| Resource efficiency | 10% | 5/10 | 6-14GB RAM overhead on 128GB machine is acceptable |
| Maintenance burden | 20% | 3/10 | Rapid releases, no nixpkgs, Docker Compose only |
| Overlap with SigNoz | 15% | 4/10 | Significant overlap; SigNoz already covers basics |
| Operational complexity | 10% | 3/10 | MySQL, duplicate ClickHouse, Docker server |
| **Weighted Total** | **100%** | **3.55/10** | **Not recommended** |

---

## 9. Conclusion

### Recommendation: **DO NOT ADD** DeepFlow at this time.

**Reasoning:**

DeepFlow is technically impressive — its eBPF-based zero-code observability is genuinely superior to SigNoz's SDK-required approach. The profiling capabilities and SmartEncoding storage are compelling.

However, for this specific homelab setup, the **integration cost massively outweighs the benefit**:

1. **No NixOS packaging** means building and maintaining 500-800 lines of custom Nix against a rapidly evolving upstream
2. **Kubernetes-first architecture** fights the single-node NixOS design
3. **SigNoz already works** and covers traces/metrics/logs natively
4. **Single machine** diminishes the core value proposition of distributed tracing correlation
5. **MySQL requirement** adds operational overhead for zero additional value
6. **Duplicate ClickHouse** wastes resources and complicates backups

**When to reconsider:**
- DeepFlow gets nixpkgs packaging (NixOS module + packages)
- You move to a multi-node setup (K8s cluster or multiple NixOS machines)
- SigNoz becomes insufficient for your observability needs
- You need profiling capabilities urgently (consider Pyroscope/Parca as lighter alternatives first)

**Immediate alternatives:**
- Add OTel SDK instrumentation to critical services for better SigNoz data
- Consider Grafana Pyroscope (in nixpkgs) for profiling if needed
- Monitor DeepFlow's packaging status in nixpkgs

---

_Report generated for the SystemNix project. Re-evaluate when upstream packaging situation changes._
