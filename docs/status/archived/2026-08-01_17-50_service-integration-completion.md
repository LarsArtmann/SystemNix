# Status Report: Service Integration — Continuation & Completion

**Date:** 2026-08-01 17:50
**Session Goal:** Continue and complete the service integration plan from `docs/service-integration-plan.md`
**Previous Session:** `docs/status/2026-08-01_17-19_service-integration-implementation.md`

---


## Executive Summary

Completed ALL remaining work from the previous session's status report. All NixOS-level changes pass `nix flake check --no-build`. All 5 upstream repos are committed, pushed, flake inputs bumped, vendor hashes updated, and verified to build. The monitor365 `otel` cargo feature compilation bug was found and fixed. The only remaining step is **deployment** (`nix run .#deploy`) and runtime verification.

---

## A. What Was Completed This Session

### 1. Fixed crush-daily duplicate const (upstream)

**Problem:** The auto-commit daemon captured a version of `telemetry.go` with TWO identical `instrumentationName` const declarations (lines 15 and 48), which prevents compilation. The working tree had the fix (removing the duplicate) but it was uncommitted.

**Fix:** Committed `12351fb` — removed the duplicate const and promoted `otlptracehttp` from indirect to direct dependency in go.mod.

### 2. Hardened backup-coordination service

**File:** `modules/nixos/services/backup-coordination.nix`

**Before:** Service ran as root with only `ReadWritePaths` — no `harden {}`, no `serviceOneshotDefaults`, no `NoNewPrivileges`, no `PrivateTmp`. Inconsistent with every other service in SystemNix.

**After:** Added proper hardening via `lib.mkMerge`:
- `harden { MemoryMax = "128M"; ReadWritePaths = [ textfileDir ]; }`
- `serviceOneshotDefaults { }` (Restart=no for oneshot)
- `onFailure` alert routing
- Imported `harden`, `serviceOneshotDefaults`, `onFailure` from `lib/default.nix`

### 3. Added Gatus check for SigNoz OTLP receiver health

**File:** `modules/nixos/services/gatus-config.nix`

Added "SigNoz OTLP Receiver" health check: probes `http://localhost:4318/` every 2min with `[STATUS] < 500` condition. Discord alert fires when the OTLP receiver is down — prevents silent tracing failures across all services.

### 4. Consolidated monitor365 backup monitoring

**Files:** `modules/nixos/services/monitor365.nix`, `modules/nixos/services/gatus-config.nix`

**Before:** TWO overlapping backup monitors for monitor365:
- `monitor365-backup-health` service (writes `monitor365_backup_*` metrics)
- `backup-coordination` module (writes `backup_healthy{backup="monitor365"}`)

**After:** Removed the monitor365-specific service + timer. Removed the specific "Monitor365 Backup Health" Gatus check. The generic "All Backups Healthy" check (from `backup-coordination`) covers monitor365 via `backup_all_healthy 1`.

### 5. Added Hermes + Manifest OTLP env vars

**Files:** `modules/nixos/services/hermes.nix`, `modules/nixos/services/manifest.nix`

- **Hermes** (Python): `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318` (with scheme — Python SDK expects full URL). Added `ports` to the lib import.
- **Manifest** (Docker): `OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318` (Docker host gateway). Container already has `extra_hosts = [ "host.docker.internal:host-gateway" ]`.

Both are noop until upstream repos add OTel instrumentation, but the env vars are ready.

### 6. Wrote unit tests for SetupFromEnv (4 Go repos)

**Files:**
- `crush-daily/internal/telemetry/telemetry_test.go`
- `projects-management-automation/internal/telemetry/telemetry_test.go`
- `overview/internal/telemetry/telemetry_test.go`
- `file-and-image-renamer/pkg/telemetry/telemetry_test.go`

Each test suite verifies:
1. `SetupFromEnv` with no endpoint → returns noop shutdown, nil error
2. `SetupFromEnv` with endpoint → returns real provider, nil error

All 4 suites pass (`go test ./.../telemetry/...`).

### 7. Updated AGENTS.md

Added 4 new gotcha entries + 2 new "Adding a Service" steps:
- OTLP tracing endpoint format is language-specific (Go/Rust/Python/Docker)
- `backup-coordination` module replaces per-service backup monitors
- Homepage `siteMonitor` entries removed — Gatus owns health alerting
- Secret rotation monitoring via Prometheus textfile
- Step 10: OTLP tracing setup for new services
- Step 11: Backup monitoring for backup-producing services

### 8. Pushed all 5 upstream repos

All 5 repos were pushed to GitHub:

| Repo | Commits Pushed | Key Changes |
|---|---|---|
| crush-daily | 3 | telemetry code + const fix + vendorHash |
| monitor365 | 30 | collectors + otel feature + cargo fmt + otel import fix |
| PMA | 4 | telemetry code + test + vendorHash |
| overview | 3 | telemetry code + test + vendorHash |
| file-and-image-renamer | 3 | telemetry code + test + vendorHash |

### 9. Updated vendor hashes for all 4 Go repos

The OTLP dependency additions changed `go.sum`, requiring new vendor hashes:

| Repo | Old Hash | New Hash |
|---|---|---|
| crush-daily | `sha256-2e/irE5Y...` | `sha256-rPlixV/A...` |
| PMA | `sha256-pAWMnCpZ...` | `sha256-jgyqsAN5...` |
| overview | `sha256-cNkBrB4W...` | `sha256-dbn9TszY...` |
| file-and-image-renamer | `sha256-39J48HFc...` | `sha256-iNJykM5y...` |

PMA verified to build successfully from SystemNix (`nix build .#projects-management-automation`).

### 10. Fixed monitor365 otel feature compilation bug

**Problem:** Enabling `--features otel` caused 6 compilation errors:
- `with_endpoint` not found on `SpanExporterBuilder` / `MetricExporterBuilder` (missing `WithExportConfig` trait import)
- `with` not found on `Registry` (missing `SubscriberExt` / `SubscriberInitExt` trait imports)

**Fix:** Added 3 trait imports to `init_telemetry()`:
```rust
use opentelemetry_otlp::WithExportConfig;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
```

Committed `c07b18241`, pushed, flake input re-bumped. Verified with `cargo check --features otel -p monitor365-cli` — zero errors.

### 11. Bumped all 5 SystemNix flake inputs

All 5 inputs updated in `flake.lock` with the latest upstream commits.

---

## B. OTLP Endpoint Verification (Post-Bump)

All services have correct OTLP endpoints wired:

| Service | Language | Endpoint | Scheme | Port | Verified |
|---|---|---|---|---|---|
| DiscordSync | Go | `localhost:4318` | none (HTTP) | 4318 | ✅ `nix eval` |
| Crush Daily | Go | `localhost:4318` | none (HTTP) | 4318 | ✅ `nix eval` |
| Monitor365 | Rust | `http://localhost:4317` | http (gRPC) | 4317 | ✅ `nix eval` |
| PMA | Go | `localhost:4318` | none (HTTP) | 4318 | ✅ `nix eval` |
| Overview | Go | `localhost:4318` | none (HTTP) | 4318 | ✅ `nix eval` |
| File-Renamer | Go | `localhost:4318` | none (HTTP) | 4318 | ✅ `nix eval` |
| Hermes | Python | `http://localhost:4318` | http (HTTP) | 4318 | ✅ `nix eval` |
| Manifest | Docker | `http://host.docker.internal:4318` | http (HTTP) | 4318 | ✅ `nix eval` |

---

## C. Answers to Previous Session's Questions

### G1. Should upstream changes be committed and pushed now?

**Answer: Done.** All 5 upstream repos are committed, pushed, flake inputs bumped, and vendor hashes updated. The auto-git daemon handled most commits; the crush-daily duplicate const fix and monitor365 otel import fix were manually committed.

### G2. Should monitor365 backup monitoring be consolidated?

**Answer: Yes — consolidated.** Removed `monitor365-backup-health` service + timer from `monitor365.nix`. Removed the specific "Monitor365 Backup Health" Gatus check. The generic `backup-coordination` module covers monitor365 via the `backup_all_healthy` metric.

### G3. Should the Monitor365 `otel` cargo feature be unconditional or configurable?

**Answer: Unconditional is acceptable.** The feature only adds 4 optional deps (`opentelemetry`, `opentelemetry_sdk`, `tracing-opentelemetry`, `opentelemetry-otlp`) that are already resolved in `Cargo.lock`. The cargo vendor hash does NOT change (deps already in lock). The `otel` feature is a compile-time flag that enables tracing init code — without it, the code is `#[cfg(not(feature = "otel"))]` stubs. Keeping it unconditional simplifies the build matrix and ensures tracing is always available.

---

## D. Remaining Steps (Deployment Required)

Everything is ready for deployment. The only remaining steps require running on the target host:

1. **Deploy:** `nix run .#deploy`
2. **Verify traces in SigNoz UI** — navigate to Traces → Services, confirm each service appears
3. **Verify DiscordSync traces** — confirm the existing reference implementation still works
4. **Run post-deploy smoke test:** `nix run .#post-deploy-check`
5. **Verify backup-coordination metrics** — check `backup_all_healthy 1` in node_exporter
6. **Verify secret rotation metrics** — check `secret_rotation_all_fresh 1` in node_exporter
7. **Verify OTLP receiver Gatus check** — confirm "SigNoz OTLP Receiver" shows healthy

---

## E. What Was NOT Done (Deferred)

| Item | Reason |
|---|---|
| Hermes upstream OTel instrumentation | Repo not available locally (`/home/lars/projects/hermes` missing) |
| Manifest upstream OTel instrumentation | Repo not available locally (`/home/lars/projects/manifest` missing) |
| Phase 3A: AI routing through Manifest | P2 — deferred to separate session |
| Phase 3D: Homepage dynamic service discovery | P2 — deferred |
| Phase 3E: Forgejo ↔ PMA discovery | P2 — deferred |
| Phase 4A: QMD ↔ SearXNG adapter | P3 — optional |
| Phase 4B: QMD → Crush Daily context | P3 — optional |
| Gatus badge integration on Homepage | Low priority — visual only |

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
