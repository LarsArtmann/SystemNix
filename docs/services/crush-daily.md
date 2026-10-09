# crush-daily (AI development insights)

**Service:** `services.crush-daily` — `modules/nixos/services/crush-daily.nix` is the SystemNix hardening overlay over the upstream flake module (the input owns `enable`, timers, `dataDir`, `runAsUser`). Port 8081 (`lib/ports.nix`), loopback. URL: `daily.<domain>` (**Layer 2 protected** via the registry — the UI has no native auth). DNS `daily`. Part of the crush ecosystem — parent runbook: [crush.md](./crush.md).

Daily collector over the user's crush session DBs (`~/.local/share/crush/.crush`) + repo checkouts, producing AI-summarized development insight reports served as a web dashboard.

## What it serves

| Route          | Auth                    | What                                                                                  |
| -------------- | ----------------------- | ------------------------------------------------------------------------------------- |
| `/`            | forward-auth / open LAN | Report dashboard                                                                      |
| `/api/health`  | none (loopback)         | Gatus "Crush Daily" (5m, 200 + <1s)                                                   |
| `/api/reports` | forward-auth / open LAN | JSON report list (deploy smoke probes it — pass `--compressed`, the API answers gzip) |

## Ops

- **Runs as the primary user** (`runAsUser` in configuration.nix) — the default upstream system user cannot traverse `/home/<user>` (mode 0700), so the collector saw `projects=0` forever. With `runAsUser` set, a `+`-privileged ExecStartPre chowns the dataDir to that user — the migration MUST stay `+`-prefixed (unprivileged it SIGSYS'd at every boot on `fchownat`, then EPERM'd even unfiltered).
- **System-user mode** (runAsUser null — other hosts) — tmpfiles open the traversal path (0750) and the unit gets `SupplementaryGroups = users` + `ReadOnlyPaths` on the session DB dir.
- **LLM key** — sops `crush-daily.yaml` `synthetic_api_key` → `crush-daily-env` template (`CRUSH_DAILY_LLM_API_KEY`, owner `primaryUser:users` 0400; rotation restarts the unit). The upstream binary hits the Synthetic provider.
- **OTel** — `OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4318` (OTLP/HTTP); registered in signoz-coverage with the standard 26h budget (26h rides in the shared expectations block — see signoz-coverage.nix).
- **Resource shape** — MemoryMax 1G / GOMEMLIMIT 768MiB, TimeoutStartSec 3min, StartLimit deliberately 3/60s (upstream cadence self-heals).
- **Monitoring** — Gatus "Crush Daily" (registry check) + Homepage tile `daily` (AI group) + onFailure.

## Related

- [crush.md](./crush.md) — the parent crush runbook: session DBs on the Samsung hot tier, the auth store doctrine, crush-debug
- [signoz.md](./signoz.md) — where its spans land
