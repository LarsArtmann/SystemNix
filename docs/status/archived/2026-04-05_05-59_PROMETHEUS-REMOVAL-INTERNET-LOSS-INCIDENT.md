# Prometheus Removal & Internet Loss Incident

**Date:** 2026-04-05
**System:** evo-x2 (NixOS)
**Severity:** P1 (network outage during deploy)

## Summary

Removed Prometheus monitoring stack (superseded by SigNoz). Identified and fixed port 9090 conflict that caused a complete network outage during NixOS activation of generation 191. Rolled back to generation 190.

## Incident: Internet Loss During NixOS Switch

### Timeline

1. `nh os switch` deployed generation 191 (added Authelia, SigNoz, ClickHouse, Steam, Gitea Runner)
2. During activation, `dnsblockd.service` and `unbound.service` were stopped and restarted
3. **`dnsblockd.service` FAILED** to start (port 9090 conflict with Prometheus)
4. System DNS (`127.0.0.1`) broke — all DNS resolution failed
5. Activation failed with exit code 4, leaving system in inconsistent state
6. Rolled back to generation 190 to restore network

### Root Cause

**Port 9090 conflict between Prometheus and dnsblockd:**

| Service         | Port   | File                                               |
| --------------- | ------ | -------------------------------------------------- |
| Prometheus      | `9090` | `modules/nixos/services/monitoring.nix:7`          |
| dnsblockd stats | `9090` | `platforms/nixos/system/dns-blocker-config.nix:24` |

Both services tried to bind to port 9090 during simultaneous restart. dnsblockd lost the race, which broke the DNS block page server. Combined with the unbound restart window, the system lost all DNS resolution (primary nameserver is `127.0.0.1`).

### Why It Wasn't Caught Earlier

Prometheus was added before dnsblockd existed. When dnsblockd was configured with `statsPort = 9090`, the conflict was never detected because both services ran on the same port by coincidence — whichever started first won the bind.

## Changes Made

### Prometheus Removal (superseded by SigNoz)

| File                                    | Change                                                   |
| --------------------------------------- | -------------------------------------------------------- |
| `modules/nixos/services/monitoring.nix` | **Deleted** — Prometheus + node/postgres/redis exporters |
| `flake.nix:180`                         | Removed `./modules/nixos/services/monitoring.nix` import |
| `flake.nix:403`                         | Removed `inputs.self.nixosModules.monitoring` module     |
| `modules/nixos/services/homepage.nix`   | Removed Prometheus + Node Exporter dashboard entries     |

### What Was Removed

- Prometheus server (port 9090, 30-day retention)
- Node exporter (port 9100, 12 collectors)
- PostgreSQL exporter (port 9187)
- Redis exporter (port 9121)
- Scrape configs for node, postgres, caddy, redis, authelia

SigNoz now handles all observability (traces, metrics, logs) via ClickHouse backend.

## Full Port Map (Post-Fix)

No remaining conflicts. All 22 ports uniquely assigned:

| Port      | Service                                           |
| --------- | ------------------------------------------------- |
| 22        | SSH                                               |
| 53        | DNS (Unbound)                                     |
| 80/443    | Caddy + dnsblockd block page                      |
| 2283      | Immich                                            |
| 3000      | Gitea                                             |
| 4317/4318 | SigNoz OTel Collector (gRPC/HTTP)                 |
| 8050      | PhotoMap                                          |
| 8080      | SigNoz Query Service                              |
| 8082      | Homepage Dashboard                                |
| 8123      | ClickHouse HTTP                                   |
| 8443      | DNS Blocker TLS stats                             |
| 8888      | Unsloth Studio                                    |
| 9000      | ClickHouse native                                 |
| 9090      | dnsblockd stats (was conflicting with Prometheus) |
| 9091      | Authelia SSO                                      |
| 9181      | ClickHouse ZooKeeper                              |
| 9234      | ClickHouse Keeper Raft                            |
| 9959      | Authelia metrics                                  |
| 11434     | Ollama                                            |

## Recommendations

1. **Add port allocation doc** — central registry of all assigned ports to prevent future conflicts
2. **Consider hardening the activation sequence** — ensure unbound/dnsblockd are restarted atomically, not stopped then started with a gap
3. **Add a pre-switch port conflict check** — `just test-fast` validates syntax but not runtime port conflicts

## Status

- [x] Prometheus removed
- [x] Port 9090 conflict resolved
- [x] Homepage dashboard updated
- [x] `just test-fast` passes
- [ ] Deploy to evo-x2 (pending user confirmation)
