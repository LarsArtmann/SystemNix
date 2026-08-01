# Service Integration Ideas

Comprehensive analysis of cross-service integration opportunities for SystemNix, organized by impact and effort.

**Generated:** 2026-08-01

---

## Current State Summary

**Hub services** (everything radiates from these):
- **Pocket ID** — identity (7 services depend on OIDC client secrets)
- **dnsblockd** — DNS resolution + TLS certs
- **Caddy** — routing + forward-auth

**Strongest app-level coupling:** PMA ↔ Overview (Unix socket + `partOf` + discovery watchdog)

**Broadest observer coupling:** Gatus (~30 health checks), SigNoz (Prometheus + journald + OTLP)

**Isolated silos** (no inter-service deps): Crush Daily, Twenty, TaskChampion, Manifest, Minecraft, Dozzle, File-Renamer, QMD, OpenSEO, Voice Agents, Ollama

---

## Ideas

### 1. Unified OTLP Tracing (Highest Impact)

Only **DiscordSync** sends OTLP traces to SigNoz. The other LarsArtmann Go services are invisible to distributed tracing.

| Service | Sends Traces? | Could? |
|---|---|---|
| DiscordSync | Yes (`localhost:4318`) | — |
| Monitor365 (server) | No | Yes — Go binary, add `OTEL_EXPORTER_OTLP_ENDPOINT` |
| PMA | No | Yes — Go binary |
| Overview | No | Yes — Go binary |
| Manifest | No | Yes — Go binary (LLM router — tracing request routing is high value) |
| Crush Daily | No | Yes — Go binary |
| Hermes | No | Yes — AI agent gateway, tracing agent flows is high value |

**Impact:** End-to-end request tracing across all Go services. A single trace would show "user → Caddy → Forgejo → OIDC → Pocket ID".

**Effort:** Low per-service (env var + upstream `otlp` init). Each is a one-commit upstream change + a `mkDefault` env var in the SystemNix wrapper.

---

### 2. Consolidate AI Inference Through Manifest

Currently 5 services independently call LLM APIs, bypassing Manifest (the smart LLM router):

| Service | LLM Usage | Current Routing |
|---|---|---|
| Manifest | IS the router | Direct |
| Hermes | Direct (Anthropic, GLM, etc.) | Bypasses Manifest |
| Crush Daily | Direct LLM calls for insights | Bypasses Manifest |
| File-Renamer | Direct (GLM, Synthetic) | Bypasses Manifest |
| OpenSEO | Direct (OpenRouter) | Bypasses Manifest |

**Impact:** Centralized cost tracking, automatic fallback, rate-limit handling, single point to switch providers.

**Tradeoff:** Adds a network hop (localhost) + failure dependency on Manifest availability.

**Recommendation:** Start with Crush Daily and File-Renamer (simplest — they already use env-var-configured endpoints, just point at Manifest's port).

---

### 3. Expand SigNoz Journald Log Coverage

SigNoz tails logs for 8 services but misses the most operationally important ones.

**Currently logged:** `signoz, caddy, immich-server, forgejo, docker, postgresql, pocket-id, oauth2-proxy`

**Missing (high-value additions):**
- `monitor365-server` — DuckDB errors, cloud sync failures
- `discordsync` — Turso quota issues, backfill progress
- `hermes` — Agent execution errors
- `pma` — Commit daemon failures
- `dnsblockd` — DNS resolution issues

**Effort:** Add service names to the SigNoz journald receiver config. One line each.

---

### 4. QMD ↔ SearXNG Integration

QMD searches local files (notes, code); SearXNG searches the web. They're siloed.

**Opportunity:** Add QMD as a SearXNG engine (or vice versa) so a single search query covers both local and web results. SearXNG supports custom engine definitions.

**Tradeoff:** QMD's HTTP MCP API isn't a standard SearXNG engine format — needs a thin adapter.

**Priority:** Lower — both work independently today.

---

### 5. Eliminate Monitoring Overlap

Three systems probe the same services redundantly:

| Probe | Gatus | Homepage `siteMonitor` | SigNoz |
|---|---|---|---|
| HTTP health | ~30 checks | ~25 tiles | Prometheus scrape |
| Overlap | Full | Full | Different angle (metrics) |

Homepage's `siteMonitor` duplicates Gatus but without Discord alerting.

**Recommendation:** Remove `siteMonitor` from Homepage tiles, let Gatus own health alerting, and have Homepage display a Gatus status badge instead (Gatus has a badge API). Eliminates ~25 redundant HTTP probes every refresh.

---

### 6. Forgejo ↔ PMA Data Flow

PMA discovers projects from the **filesystem**, not Forgejo. But Forgejo mirrors all GitHub repos locally.

- PMA discovers repos that Forgejo already knows about, via a slower filesystem walk
- Forgejo's API has richer metadata (stars, issues, last commit) than filesystem stats

**Opportunity:** Add a Forgejo-backed project source to PMA's discovery daemon (query `GET /api/v1/repos/search`) instead of/in addition to the filesystem walk.

**Tradeoff:** Couples PMA to Forgejo availability. The filesystem walk is the reliable fallback.

---

### 7. Unified Secret Rotation Notifications

When `pocket-id-provision` regenerates OIDC client secrets (via `regenerateSecretsFor`), only services with `partOf`/`after` dependencies pick up the new secret. Services that read secrets at startup without ordering deps silently use stale credentials.

**Opportunity:** A `secret-rotation-broadcaster` that writes to the Prometheus textfile collector when any sops secret changes, so Gatus can alert on "stale secret" conditions.

---

### 8. Cross-Service Backup Coordination

Multiple services create independent backups with no coordination:

| Service | Backup Target |
|---|---|
| Immich | PostgreSQL dump |
| Monitor365 | DuckDB `.backup` |
| Forgejo | Gitea dump |
| Manifest | SQLite/PostgreSQL |
| DiscordSync | GCS attachment backup |

**Opportunity:** A unified backup orchestrator that:
- Staggers backups to avoid IO spikes
- Writes a shared `backup_status.prom` metric for Gatus
- Reports a single "all backups healthy" dashboard signal

---

### 9. Homepage Dynamic Service Discovery

Homepage service tiles are hardcoded. When a new service is added to Caddy, the Homepage tile must be manually added.

**Opportunity:** Generate Homepage tiles from Caddy's vHost config (or from a shared service registry). A NixOS module could auto-generate tiles for every `protectedVHost` and plain `reverse_proxy`.

---

### 10. QMD Index Feeds to Crush Daily

Crush Daily generates insights from Crush databases. QMD indexes local markdown/notes.

**Opportunity:** Crush Daily could query QMD for project-related notes/context when generating daily insights, giving richer context (e.g., "you spent 3h on project X, and your notes mention pending bug Y").

---

## Priority Matrix

| # | Integration | Impact | Effort | Recommended |
|---|---|---|---|---|
| 1 | OTLP tracing for Go services | High | Low | Do first |
| 3 | Expand SigNoz journald | Medium | Low | Do first |
| 5 | Remove Homepage monitoring dupes | Medium | Low | Quick win |
| 2 | AI routing through Manifest | High | Medium | Next |
| 7 | Secret rotation notifications | Medium | Low | Next |
| 8 | Cross-service backup coordination | Medium | Medium | Next |
| 9 | Homepage dynamic discovery | Medium | Medium | Later |
| 6 | Forgejo → PMA discovery | Medium | Medium | Later |
| 10 | QMD → Crush Daily context | Low | Medium | Optional |
| 4 | QMD ↔ SearXNG | Low | Medium | Optional |

---

## Appendix: OTLP Tracing Wiring Pattern

The canonical pattern for wiring a Go service to send OTLP traces to SigNoz:

### Go Services (via go-cqrs-lite otel package)

Services using `github.com/larsartmann/go-cqrs-lite/otel/v4` (DiscordSync, Crush Daily, PMA) auto-initialize an OTLP exporter when the env var is set. The binary installs a **noop tracer** when unset.

**NixOS module** — add one line to the service `environment`:

```nix
environment = {
  OTEL_EXPORTER_OTLP_ENDPOINT = "localhost:${toString ports.signoz-otlp-http}";
};
```

**Key rules:**
- `localhost:4318` (HTTP) — NOT `localhost:4317` (gRPC). The Go `otlptracehttp` SDK expects `host:port` WITHOUT scheme.
- The SDK constructs the full URL internally (`http://<endpoint>/v1/traces`).
- `WithInsecure()` is used (plain HTTP, no TLS) since traffic is localhost.
- When `OTEL_EXPORTER_OTLP_ENDPOINT` is unset, a noop tracer is installed — zero overhead.

### Rust Services (monitor365)

Monitor365 has full OTLP support behind the `otel` cargo feature flag (`#[cfg(feature = "otel")]`). The `init_tracing` function in `crates/cli/src/telemetry.rs` reads `OTEL_EXPORTER_OTLP_ENDPOINT` from env.

**Key differences from Go:**
- Uses tonic (gRPC), NOT HTTP. The endpoint should be `localhost:4317` (gRPC port), not `localhost:4318`.
- Requires the `otel` cargo feature to be enabled in the Nix build (`buildFeatures = ["otel"]`).
- Uses `tracing-opentelemetry` layer integration for structured logging + tracing.

### Docker Services (Manifest)

Docker containers cannot reach `localhost:4318` on the host. Use `host.docker.internal:4318` and add `extra_hosts` in the compose definition:

```yaml
services:
  app:
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=host.docker.internal:4318
```

### Verification

After wiring, verify traces appear in SigNoz:
1. Deploy: `nix run .#deploy`
2. Navigate to SigNoz → Traces → Services
3. Each service should appear with incoming trace data
4. Cross-service traces show the full request path
