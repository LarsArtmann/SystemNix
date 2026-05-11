# Dozzle — Evaluation

**Date:** 2026-05-11
**URL:** https://github.com/amir20/dozzle
**Version evaluated:** 10.5.2
**License:** MIT

## Overview

Dozzle is a lightweight, real-time web-based Docker and Kubernetes log viewer. It streams container logs to a browser with no persistent storage — purely live viewing.

## Technical Profile

| Aspect | Details |
|--------|---------|
| Image size | ~7 MB compressed |
| Backend | Go 1.26, chi router, Docker/Moby SDK, K8s client-go, gRPC (agent mode) |
| Frontend | Vue 3, Vite 8, Tailwind 4, DaisyUI, xterm.js, CodeMirror, Pinia, DuckDB-WASM |
| Auth | File-based users + forward proxy (Authelia compatible) |
| Deployment | Single Docker container, Docker Compose, or Swarm service |

## Features

- Real-time log streaming with split-screen for multiple containers
- Regex and SQL log search (DuckDB-WASM in-browser)
- Live stats with memory and CPU usage per container
- Multi-host monitoring via agent mode (gRPC)
- Docker Swarm and Kubernetes support
- Forward proxy authentication (Authelia, etc.)
- Fuzzy search for container names
- Dark mode

## Strengths

- **Purpose-built** — does one thing well: streaming container logs in a browser
- **Lightweight** — single Go binary + embedded SPA, minimal memory footprint
- **Multi-host** — agent mode for monitoring multiple Docker hosts via gRPC
- **Swarm + K8s** — supports both orchestration platforms natively
- **SQL log search** — DuckDB-WASM enables SQL queries on buffered logs in-browser
- **Auth** — forward proxy auth works with Authelia (compatible with existing setup)
- **Active maintenance** — regular releases, modern Go and frontend stack

## Weaknesses / Trade-offs

- **No persistent storage** — cannot search historical/offline logs (by design)
- **Google Analytics** — embedded telemetry (opt-out via `--no-analytics`)
- **Not a full logging stack** — complementary to SigNoz, not a replacement
- **SPA complexity** — DuckDB-WASM + xterm.js + CodeMirror = heavier frontend than expected for a log viewer

## Comparison with SigNoz

| | SigNoz | Dozzle |
|---|---|---|
| Logs | Historical, searchable, aggregated | Live streaming, real-time |
| Use case | Alerting, analysis, debugging over time | "What's happening right now" on a container |
| Storage | ClickHouse (persistent) | None (ephemeral) |
| Scope | Full observability (metrics, traces, logs) | Container log tailing only |

## Fit for SystemNix

Dozzle fills a different niche than SigNoz — real-time log tailing vs. historical analysis and alerting. They are complementary, not competing.

**Integration path:**
- Add as a Docker container in the existing stack
- Mount `docker.sock`, place behind Caddy at `logs.home.lan`
- Protect with Authelia forward auth (already supported by Dozzle)
- No custom NixOS module needed — Docker Compose service is sufficient

**Recommendation:** Worth adding. Best-in-class for live container log tailing. Complements SigNoz (historical search/alerting). Authelia forward auth support means clean integration with existing SSO.
