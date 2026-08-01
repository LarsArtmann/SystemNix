# Service Integration Plan — Comprehensive TODO Breakdown

> All tasks are estimated at ≤12 minutes each.
> Sorted by **Impact → Effort → Customer Value** (highest first).
> Each task is atomic: one file, one change, one verification.

**Generated:** 2026-08-01

---

## Sorting Rationale

| Priority | Criteria |
|---|---|
| **P0 — Do First** | Low effort + high impact + immediate observability gains |
| **P1 — Do Next** | Medium effort + high impact + architectural improvement |
| **P2 — Do Later** | Medium effort + medium impact + quality of life |
| **P3 — Optional** | Higher effort or lower impact + nice-to-have |

---

## P0 — Do First (Low Effort, High Impact)

### Phase 1A: Expand SigNoz Journald Log Coverage

Add 5 high-value services to SigNoz's journald receiver. One edit, immediate log visibility.

| ID | Task | File | Est |
|---|---|---|---|
| 1A.1 | Add `monitor365-server.service` to journald `units` list in collector.yaml template | `modules/nixos/services/signoz.nix:444-459` | 3 min |
| 1A.2 | Add `discordsync.service` to journald `units` list | `modules/nixos/services/signoz.nix:455` | 2 min |
| 1A.3 | Add `hermes.service` to journald `units` list | `modules/nixos/services/signoz.nix:455` | 2 min |
| 1A.4 | Add `projects-management-automation.service` to journald `units` list | `modules/nixos/services/signoz.nix:455` | 2 min |
| 1A.5 | Add `dnsblockd.service` to journald `units` list | `modules/nixos/services/signoz.nix:455` | 2 min |
| 1A.6 | Verify: `nix eval .#nixosConfigurations.evo-x2.config.systemd.services.signoz-collector.serviceConfig.ExecStart` succeeds | — | 3 min |

---

### Phase 1B: Remove Homepage Monitoring Duplication

Eliminate ~25 redundant `siteMonitor` probes. Replace with Gatus badge references.

| ID | Task | File | Est |
|---|---|---|---|
| 1B.1 | Read homepage.nix to confirm all `siteMonitor` entries and the `mkService` pattern | `modules/nixos/services/homepage.nix` | 5 min |
| 1B.2 | Remove `siteMonitor` from Pocket ID tile (keep `statusStyle = "dot"`) | `modules/nixos/services/homepage.nix:158` | 3 min |
| 1B.3 | Remove `siteMonitor` from Caddy tile | `modules/nixos/services/homepage.nix:171` | 2 min |
| 1B.4 | Remove `siteMonitor` from DiscordSync tile | `modules/nixos/services/homepage.nix:207` | 2 min |
| 1B.5 | Remove `siteMonitor` from Immich tile | `modules/nixos/services/homepage.nix:217` | 2 min |
| 1B.6 | Remove `siteMonitor` from DNS Blocker tile | `modules/nixos/services/homepage.nix:224` | 2 min |
| 1B.7 | Remove `siteMonitor` from Forgejo tile | `modules/nixos/services/homepage.nix:234` | 2 min |
| 1B.8 | Remove `siteMonitor` from Overview tile | `modules/nixos/services/homepage.nix:243` | 2 min |
| 1B.9 | Remove `siteMonitor` from Crush Daily tile | `modules/nixos/services/homepage.nix:254` | 2 min |
| 1B.10 | Remove `siteMonitor` from Manifest tile | `modules/nixos/services/homepage.nix:263` | 2 min |
| 1B.11 | Remove `siteMonitor` from Ollama tile | `modules/nixos/services/homepage.nix:271` | 2 min |
| 1B.12 | Remove `siteMonitor` from LiveKit tile | `modules/nixos/services/homepage.nix:280` | 2 min |
| 1B.13 | Remove `siteMonitor` from Whisper ASR tile | `modules/nixos/services/homepage.nix:287` | 2 min |
| 1B.14 | Remove `siteMonitor` from Gatus tile | `modules/nixos/services/homepage.nix:298` | 2 min |
| 1B.15 | Remove `siteMonitor` from SigNoz tile | `modules/nixos/services/homepage.nix:307` | 2 min |
| 1B.16 | Remove `siteMonitor` from Dozzle tile | `modules/nixos/services/homepage.nix:316` | 2 min |
| 1B.17 | Remove `siteMonitor` from Node Exporter tile | `modules/nixos/services/homepage.nix:324` | 2 min |
| 1B.18 | Remove `siteMonitor` from cAdvisor tile | `modules/nixos/services/homepage.nix:332` | 2 min |
| 1B.19 | Remove `siteMonitor` from dnsblockd metrics tile | `modules/nixos/services/homepage.nix:342` | 2 min |
| 1B.20 | Remove `siteMonitor` from EMEET PIXY tile | `modules/nixos/services/homepage.nix:348` | 2 min |
| 1B.21 | Remove `siteMonitor` from Monitor365 tile | `modules/nixos/services/homepage.nix:357` | 2 min |
| 1B.22 | Remove `siteMonitor` from Twenty CRM tile | `modules/nixos/services/homepage.nix:368` | 2 min |
| 1B.23 | Remove `siteMonitor` from File Renamer tile | `modules/nixos/services/homepage.nix:379` | 2 min |
| 1B.24 | Remove `siteMonitor` from Taskwarrior tile | `modules/nixos/services/homepage.nix:388` | 2 min |
| 1B.25 | Remove `siteMonitor` from OpenSEO tile | `modules/nixos/services/homepage.nix:399` | 2 min |
| 1B.26 | Remove `siteMonitor` from SearXNG tile | `modules/nixos/services/homepage.nix:408` | 2 min |
| 1B.27 | Add Gatus badge URL config to Homepage settings — set `useExternalStatusCheck = true` or configure Gatus integration in Homepage settings | `modules/nixos/services/homepage.nix` (settings section) | 8 min |
| 1B.28 | Verify: `nix eval .#nixosConfigurations.evo-x2.config.services.homepage-dashboard.settings` renders correctly | — | 3 min |

---

### Phase 1C: Wire OTLP Tracing for DiscordSync (already done — audit only)

| ID | Task | File | Est |
|---|---|---|---|
| 1C.1 | Verify DiscordSync OTLP endpoint is `localhost:4318` (no scheme) and traces appear in SigNoz | `modules/nixos/services/discordsync.nix:101-106` | 5 min |
| 1C.2 | Document the canonical OTLP wiring pattern (env var + upstream init) for reuse across other Go services | `docs/service-integration-ideas.md` (appendix) | 8 min |

---

## P1 — Do Next (Medium Effort, High Impact)

### Phase 2A: Wire OTLP Tracing for Monitor365 Server

| ID | Task | File / Location | Est |
|---|---|---|---|
| 2A.1 | Read monitor365.nix to find the server service environment block | `modules/nixos/services/monitor365.nix` | 5 min |
| 2A.2 | Add `OTEL_EXPORTER_OTLP_ENDPOINT = "localhost:${toString ports.signoz-otlp-http}"` to monitor365-server environment (via `lib.mkDefault`) | `modules/nixos/services/monitor365.nix` (server env) | 5 min |
| 2A.3 | Add upstream OTLP init code to monitor365-server repo (`/home/lars/projects/monitor365`) — add `go.opentelemetry.io/otel` + `otlptracehttp` deps | `/home/lars/projects/monitor365/go.mod` + tracer init | 10 min |
| 2A.4 | Write a unit test verifying tracer is initialized when `OTEL_EXPORTER_OTLP_ENDPOINT` is set | `/home/lars/projects/monitor365` test file | 10 min |
| 2A.5 | Bump monitor365 flake input: `nix flake lock --update-input monitor365` | SystemNix root | 3 min |
| 2A.6 | Verify: `nix eval` passes, check vendorHash | — | 5 min |

---

### Phase 2B: Wire OTLP Tracing for PMA

| ID | Task | File / Location | Est |
|---|---|---|---|
| 2B.1 | Read PMA wrapper module to find the service environment | `modules/nixos/services/projects-management-automation.nix` | 5 min |
| 2B.2 | Add `OTEL_EXPORTER_OTLP_ENDPOINT = "localhost:${toString ports.signoz-otlp-http}"` to PMA daemon environment | `modules/nixos/services/projects-management-automation.nix` | 5 min |
| 2B.3 | Add upstream OTLP init code to PMA repo (`/home/lars/projects/projects-management-automation`) | upstream `go.mod` + tracer init | 10 min |
| 2B.4 | Write unit test for tracer init | upstream test file | 10 min |
| 2B.5 | Bump PMA flake input: `nix flake lock --update-input projects-management-automation` | SystemNix root | 3 min |
| 2B.6 | Verify: `nix eval` passes | — | 5 min |

---

### Phase 2C: Wire OTLP Tracing for Overview

| ID | Task | File / Location | Est |
|---|---|---|---|
| 2C.1 | Read overview.nix to find the service environment block | `modules/nixos/services/overview.nix` | 5 min |
| 2C.2 | Add `OTEL_EXPORTER_OTLP_ENDPOINT` env var to Overview service | `modules/nixos/services/overview.nix` | 5 min |
| 2C.3 | Add upstream OTLP init code to Overview repo (`/home/lars/projects/overview`) | upstream `go.mod` + tracer init | 10 min |
| 2C.4 | Write unit test for tracer init | upstream test file | 10 min |
| 2C.5 | Bump overview flake input: `nix flake lock --update-input overview` | SystemNix root | 3 min |
| 2C.6 | Verify: `nix eval` passes | — | 5 min |

---

### Phase 2D: Wire OTLP Tracing for Hermes

| ID | Task | File / Location | Est |
|---|---|---|---|
| 2D.1 | Read hermes.nix to find the service environment / EnvironmentFile pattern | `modules/nixos/services/hermes.nix` | 5 min |
| 2D.2 | Add `OTEL_EXPORTER_OTLP_ENDPOINT` to Hermes environment (inline, not via sops — it's not a secret) | `modules/nixos/services/hermes.nix` | 5 min |
| 2D.3 | Add upstream OTLP init code to Hermes repo (`/home/lars/projects/hermes`) — Python: `opentelemetry-sdk` + `opentelemetry-exporter-otlp` | upstream `pyproject.toml` + tracer init | 12 min |
| 2D.4 | Write a test verifying tracer initializes when env var is set | upstream test | 10 min |
| 2D.5 | Bump hermes flake input: `nix flake lock --update-input hermes` | SystemNix root | 3 min |
| 2D.6 | Verify: `nix eval` passes | — | 5 min |

---

### Phase 2E: Wire OTLP Tracing for Crush Daily

| ID | Task | File / Location | Est |
|---|---|---|---|
| 2E.1 | Read crush-daily.nix to find the service environment | `modules/nixos/services/crush-daily.nix` | 5 min |
| 2E.2 | Add `OTEL_EXPORTER_OTLP_ENDPOINT` env var to crush-daily service | `modules/nixos/services/crush-daily.nix` | 5 min |
| 2E.3 | Add upstream OTLP init code to crush-daily repo (`/home/lars/projects/crush-daily`) | upstream `go.mod` + tracer init | 10 min |
| 2E.4 | Write unit test for tracer init | upstream test file | 10 min |
| 2E.5 | Bump crush-daily flake input: `nix flake lock --update-input crush-daily` | SystemNix root | 3 min |
| 2E.6 | Verify: `nix eval` passes | — | 5 min |

---

### Phase 2F: Wire OTLP Tracing for Manifest

| ID | Task | File / Location | Est |
|---|---|---|---|
| 2F.1 | Read manifest.nix to find the Docker Compose environment block | `modules/nixos/services/manifest.nix` | 5 min |
| 2F.2 | Add `OTEL_EXPORTER_OTLP_ENDPOINT` to Manifest container environment (note: Docker networking — use `host.docker.internal:4318` since the OTLP receiver is on the host) | `modules/nixos/services/manifest.nix` | 8 min |
| 2F.3 | Add upstream OTLP init code to Manifest repo (`/home/lars/projects/manifest`) — likely Node.js/TypeScript | upstream `package.json` + tracer init | 12 min |
| 2F.4 | Write a test verifying tracer initializes | upstream test | 10 min |
| 2F.5 | Bump manifest flake input (if applicable) or rebuild Docker image | SystemNix root | 5 min |
| 2F.6 | Verify: `nix eval` passes + container can reach `host.docker.internal:4318` | — | 8 min |

---

### Phase 2G: Wire OTLP Tracing for File-Renamer

| ID | Task | File / Location | Est |
|---|---|---|---|
| 2G.1 | Read file-and-image-renamer.nix to find the service environment | `modules/nixos/services/file-and-image-renamer.nix` | 5 min |
| 2G.2 | Add `OTEL_EXPORTER_OTLP_ENDPOINT` env var to both watcher and health services | `modules/nixos/services/file-and-image-renamer.nix` | 5 min |
| 2G.3 | Add upstream OTLP init code to file-and-image-renamer repo (`/home/lars/projects/file-and-image-renamer`) | upstream `go.mod` + tracer init | 10 min |
| 2G.4 | Write unit test for tracer init | upstream test file | 10 min |
| 2G.5 | Bump file-and-image-renamer flake input | SystemNix root | 3 min |
| 2G.6 | Verify: `nix eval` passes | — | 5 min |

---

### Phase 2H: Verify End-to-End Distributed Tracing

| ID | Task | File / Location | Est |
|---|---|---|---|
| 2H.1 | Deploy all OTLP changes: `nix run .#deploy` | — | 10 min |
| 2H.2 | Verify traces appear in SigNoz UI for each service (navigate to Traces → Services) | SigNoz web UI | 8 min |
| 2H.3 | Add a Gatus check for SigNoz OTLP receiver health (`http://localhost:4318/` returns 200) | `modules/nixos/services/gatus-config.nix` | 5 min |
| 2H.4 | Document the distributed tracing setup in AGENTS.md | `AGENTS.md` | 8 min |

---

## P2 — Do Later (Medium Effort, Medium Impact)

### Phase 3A: Consolidate AI Inference Through Manifest

| ID | Task | File / Location | Est |
|---|---|---|---|
| 3A.1 | Read manifest.nix to understand the Manifest API surface (endpoints, model config, routing logic) | `modules/nixos/services/manifest.nix` | 8 min |
| 3A.2 | Read Manifest upstream repo to document the OpenAI-compatible API (if it exposes one) | `/home/lars/projects/manifest` | 10 min |
| 3A.3 | Design routing strategy: which services route through Manifest vs direct (document tradeoffs) | `docs/service-integration-ideas.md` | 10 min |
| 3A.4 | Point Crush Daily's LLM endpoint to Manifest — add `LLM_BASE_URL = "http://localhost:${toString ports.manifest}"` env var (or equivalent) | `modules/nixos/services/crush-daily.nix` | 8 min |
| 3A.5 | Point File-Renamer's `GLM_MODEL`/`ZAI_API_KEY` to Manifest's OpenAI-compatible endpoint | `modules/nixos/services/file-and-image-renamer.nix` | 8 min |
| 3A.6 | Add Manifest as a dependency (`after`, `wants`) for Crush Daily and File-Renamer services | respective `.nix` files | 5 min |
| 3A.7 | Add a Gatus check for Manifest API health (already exists — verify it covers the `/v1/chat/completions` endpoint) | `modules/nixos/services/gatus-config.nix` | 5 min |
| 3A.8 | Add Manifest cost/usage metrics to the Prometheus textfile collector (if Manifest exposes them) | new collector or `system-health.nix` | 12 min |
| 3A.9 | Deploy and verify: Crush Daily insights still generate, File-Renamer still renames | — | 10 min |

---

### Phase 3B: Cross-Service Backup Coordination

| ID | Task | File / Location | Est |
|---|---|---|---|
| 3B.1 | Audit all backup services: Immich, Monitor365, Manifest, Twenty, Taskwarrior — collect schedules, output dirs, retention | all `.nix` files | 10 min |
| 3B.2 | Create a `backup-coordination.nix` module skeleton with an `enabledBackups` option | `modules/nixos/services/backup-coordination.nix` | 8 min |
| 3B.3 | Add a Prometheus textfile collector script that checks all backup dirs for freshness (age < 25h) | `modules/nixos/services/backup-coordination.nix` | 12 min |
| 3B.4 | Add `immich-db-backup` health metric output (write `backup_immich_healthy`, `backup_immich_age_hours` to textfile) | `modules/nixos/services/immich.nix` or backup-coordination.nix | 10 min |
| 3B.5 | Add `manifest-db-backup` health metric output | backup-coordination.nix | 8 min |
| 3B.6 | Add `twenty-db-backup` health metric output | backup-coordination.nix | 8 min |
| 3B.7 | Add staggered scheduling: shift Immich to `01:00`, Manifest to `02:00`, Twenty to `02:30`, Monitor365 stays `03:00` | respective `.nix` files | 10 min |
| 3B.8 | Add a Gatus check: "All Backups Healthy" — queries node_exporter metrics for `backup_*_healthy` flags | `modules/nixos/services/gatus-config.nix` | 8 min |
| 3B.9 | Add Discord alert on any backup stale >25h | `modules/nixos/services/gatus-config.nix` | 3 min |
| 3B.10 | Enable the module in `configuration.nix` | `platforms/nixos/system/configuration.nix` | 2 min |
| 3B.11 | Verify: `nix flake check --no-build` passes | — | 3 min |

---

### Phase 3C: Unified Secret Rotation Notifications

| ID | Task | File / Location | Est |
|---|---|---|---|
| 3C.1 | Read pocket-id.nix to understand `regenerateSecretsFor` and the provision script flow | `modules/nixos/services/pocket-id.nix` | 8 min |
| 3C.2 | Read sops.nix to understand `restartUnits` and template patterns | `modules/nixos/services/sops.nix` | 8 min |
| 3C.3 | Add a `secret-rotation-metrics` oneshot script that checks all OIDC client secret files for freshness (mtime < 30d) | new script or in `system-health.nix` | 12 min |
| 3C.4 | Write Prometheus textfile metrics: `secret_rotation_age_days{client="forgejo"}`, `secret_rotation_stale{client="gatus"}` | textfile collector output | 10 min |
| 3C.5 | Add a Gatus check: "Secret Rotation Health" — alerts when any secret is >30d old | `modules/nixos/services/gatus-config.nix` | 8 min |
| 3C.6 | Add timer for the rotation checker (every 1h) | same module | 5 min |
| 3C.7 | Verify: `nix flake check --no-build` passes | — | 3 min |

---

### Phase 3D: Homepage Dynamic Service Discovery

| ID | Task | File / Location | Est |
|---|---|---|---|
| 3D.1 | Read caddy.nix to extract the full list of vHosts (both `protectedVHost` and plain `reverse_proxy`) | `modules/nixos/services/caddy.nix` | 8 min |
| 3D.2 | Design a NixOS option `services.homepage-dashboard.autoDiscover` that reads from Caddy's vHost list | design doc / notes | 10 min |
| 3D.3 | Create a helper function that generates Homepage service tiles from Caddy vHost definitions | `modules/nixos/services/homepage.nix` or `lib/` | 12 min |
| 3D.4 | Wire `autoDiscover` into the Homepage settings generation (merge auto-generated tiles with manual ones) | `modules/nixos/services/homepage.nix` | 10 min |
| 3D.5 | Add per-tile icon mapping (service name → dashboard-icons pack name) | `modules/nixos/services/homepage.nix` | 12 min |
| 3D.6 | Add a `lib.optionalString` guard so disabled services don't generate tiles | `modules/nixos/services/homepage.nix` | 5 min |
| 3D.7 | Verify: `nix eval .#nixosConfigurations.evo-x2.config.services.homepage-dashboard.settings.services` shows auto-generated tiles | — | 5 min |
| 3D.8 | Deploy and visually verify the dashboard | — | 5 min |

---

### Phase 3E: Forgejo ↔ PMA Discovery Integration

| ID | Task | File / Location | Est |
|---|---|---|---|
| 3E.1 | Read PMA upstream module to understand the discovery daemon's source interface (filesystem walker) | `/home/lars/projects/projects-management-automation` | 10 min |
| 3E.2 | Read forgejo-repos.nix to understand the Forgejo API query patterns and auth | `modules/nixos/services/forgejo-repos.nix` | 8 min |
| 3E.3 | Design a Forgejo-backed discovery source: query `GET /api/v1/repos/search?uid=1` to list repos with metadata | design notes | 10 min |
| 3E.4 | Implement `ForgejoSource` in PMA upstream that queries the API and returns project entries | `/home/lars/projects/projects-management-automation` | 12 min |
| 3E.5 | Add Forgejo API token reading to PMA (via env var `FORGEJO_TOKEN` or config file) | upstream PMA config | 8 min |
| 3E.6 | Write integration test for Forgejo discovery source | upstream PMA test | 12 min |
| 3E.7 | Wire SystemNix env: pass `FORGEJO_URL = "http://localhost:${toString ports.forgejo}"` to PMA service | `modules/nixos/services/projects-management-automation.nix` | 5 min |
| 3E.8 | Bump PMA flake input: `nix flake lock --update-input projects-management-automation` | SystemNix root | 3 min |
| 3E.9 | Verify: `nix eval` passes + PMA discovers repos from Forgejo API | — | 8 min |

---

## P3 — Optional (Higher Effort / Lower Impact)

### Phase 4A: QMD ↔ SearXNG Integration

| ID | Task | File / Location | Est |
|---|---|---|---|
| 4A.1 | Read qmd-config.nix to understand the MCP HTTP API (endpoints, request/response format) | `modules/nixos/services/qmd-config.nix` | 8 min |
| 4A.2 | Read searxng.nix engine config to understand custom engine definition format | `modules/nixos/services/searxng.nix` | 8 min |
| 4A.3 | Design a thin adapter: either (a) a SearXNG engine plugin that queries QMD's MCP endpoint, or (b) a reverse approach where QMD uses SearXNG as a fallback | design notes | 10 min |
| 4A.4 | Implement the adapter as a small HTTP service (Go or Python) that translates SearXNG engine API ↔ QMD MCP | new `pkgs/qmd-searxng-adapter/` | 12 min |
| 4A.5 | Register the adapter as a SearXNG engine in settings | `modules/nixos/services/searxng.nix` | 8 min |
| 4A.6 | Add systemd service for the adapter | new `.nix` or inline | 8 min |
| 4A.7 | Add a Gatus check for the adapter | `modules/nixos/services/gatus-config.nix` | 5 min |
| 4A.8 | Deploy and test: search query in SearXNG returns local results from QMD | — | 8 min |

---

### Phase 4B: QMD Index Feeds to Crush Daily

| ID | Task | File / Location | Est |
|---|---|---|---|
| 4B.1 | Read crush-daily.nix to understand how it generates insights (what data sources it uses) | `modules/nixos/services/crush-daily.nix` | 8 min |
| 4B.2 | Read qmd-config.nix to understand the search/query API | `modules/nixos/services/qmd-config.nix` | 5 min |
| 4B.3 | Design the integration: Crush Daily queries QMD for project-related notes before generating insights | design notes | 10 min |
| 4B.4 | Implement QMD query integration in crush-daily upstream (`/home/lars/projects/crush-daily`) — call `qmd query` or HTTP MCP before insight generation | upstream repo | 12 min |
| 4B.5 | Add `QMD_ENDPOINT = "http://localhost:${toString ports.qmd}"` env var to Crush Daily | `modules/nixos/services/crush-daily.nix` | 5 min |
| 4B.6 | Write a test verifying QMD results are included in insights | upstream test | 10 min |
| 4B.7 | Bump crush-daily flake input | SystemNix root | 3 min |
| 4B.8 | Verify: insights now contain context from QMD-indexed notes | — | 8 min |

---

## Summary Table (All Tasks Sorted by Priority)

| ID | Task | Phase | Priority | Impact | Effort | Est |
|---|---|---|---|---|---|---|
| **1A.1** | Add monitor365-server to SigNoz journald | 1A | P0 | High | Low | 3 min |
| **1A.2** | Add discordsync to SigNoz journald | 1A | P0 | High | Low | 2 min |
| **1A.3** | Add hermes to SigNoz journald | 1A | P0 | High | Low | 2 min |
| **1A.4** | Add PMA to SigNoz journald | 1A | P0 | High | Low | 2 min |
| **1A.5** | Add dnsblockd to SigNoz journald | 1A | P0 | High | Low | 2 min |
| **1A.6** | Verify journald eval | 1A | P0 | High | Low | 3 min |
| **1B.1** | Read homepage.nix for siteMonitor audit | 1B | P0 | Med | Low | 5 min |
| **1B.2–1B.26** | Remove 25 siteMonitor entries (one per tile) | 1B | P0 | Med | Low | 2 min each |
| **1B.27** | Configure Gatus badge integration for Homepage | 1B | P0 | Med | Low | 8 min |
| **1B.28** | Verify Homepage eval | 1B | P0 | Med | Low | 3 min |
| **1C.1** | Verify DiscordSync OTLP traces in SigNoz | 1C | P0 | Med | Low | 5 min |
| **1C.2** | Document OTLP wiring pattern | 1C | P0 | Med | Low | 8 min |
| **2A.1–2A.6** | OTLP tracing for Monitor365 | 2A | P1 | High | Med | 38 min total |
| **2B.1–2B.6** | OTLP tracing for PMA | 2B | P1 | High | Med | 38 min total |
| **2C.1–2C.6** | OTLP tracing for Overview | 2C | P1 | High | Med | 38 min total |
| **2D.1–2D.6** | OTLP tracing for Hermes | 2D | P1 | High | Med | 40 min total |
| **2E.1–2E.6** | OTLP tracing for Crush Daily | 2E | P1 | High | Med | 38 min total |
| **2F.1–2F.6** | OTLP tracing for Manifest | 2F | P1 | High | Med | 48 min total |
| **2G.1–2G.6** | OTLP tracing for File-Renamer | 2G | P1 | High | Med | 38 min total |
| **2H.1–2H.4** | End-to-end tracing verification | 2H | P1 | High | Med | 31 min total |
| **3A.1–3A.9** | AI routing through Manifest | 3A | P2 | High | Med | 84 min total |
| **3B.1–3B.11** | Cross-service backup coordination | 3B | P2 | Med | Med | 84 min total |
| **3C.1–3C.7** | Secret rotation notifications | 3C | P2 | Med | Med | 54 min total |
| **3D.1–3D.8** | Homepage dynamic discovery | 3D | P2 | Med | Med | 67 min total |
| **3E.1–3E.9** | Forgejo ↔ PMA discovery | 3E | P2 | Med | Med | 80 min total |
| **4A.1–4A.8** | QMD ↔ SearXNG adapter | 4A | P3 | Low | Med | 71 min total |
| **4B.1–4B.8** | QMD → Crush Daily context | 4B | P3 | Low | Med | 61 min total |

---

## Phase Totals

| Phase | Description | Tasks | Total Est | Priority |
|---|---|---|---|---|
| 1A | Expand SigNoz journald | 6 | 14 min | P0 |
| 1B | Remove Homepage monitoring dupes | 28 | 66 min | P0 |
| 1C | DiscordSync OTLP audit | 2 | 13 min | P0 |
| 2A | OTLP — Monitor365 | 6 | 38 min | P1 |
| 2B | OTLP — PMA | 6 | 38 min | P1 |
| 2C | OTLP — Overview | 6 | 38 min | P1 |
| 2D | OTLP — Hermes | 6 | 40 min | P1 |
| 2E | OTLP — Crush Daily | 6 | 38 min | P1 |
| 2F | OTLP — Manifest | 6 | 48 min | P1 |
| 2G | OTLP — File-Renamer | 6 | 38 min | P1 |
| 2H | E2E tracing verification | 4 | 31 min | P1 |
| 3A | AI routing via Manifest | 9 | 84 min | P2 |
| 3B | Backup coordination | 11 | 84 min | P2 |
| 3C | Secret rotation alerts | 7 | 54 min | P2 |
| 3D | Homepage dynamic discovery | 8 | 67 min | P2 |
| 3E | Forgejo ↔ PMA | 9 | 80 min | P2 |
| 4A | QMD ↔ SearXNG | 8 | 71 min | P3 |
| 4B | QMD → Crush Daily | 8 | 61 min | P3 |
| **TOTAL** | | **130** | **~903 min (~15h)** | |
