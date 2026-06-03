# Session 118+ Execution Plan

**Created:** 2026-06-03
**Status:** In Progress

## Scope

All TODOs from TODO_LIST.md, status reports, and session findings.
Excludes items needing physical hardware access or user decisions.

## Excluded (with reason)

| Item | Reason |
|------|--------|
| ClickHouse 30d TTL | ClickHouse holds 8KB. Disk full from AI models (862G), not observability. |
| Pi 3 DNS failover | Needs physical hardware access |
| Darwin home.nix parity | Blocked on: Is Darwin actively used? |
| Provision Pi 3 | Needs physical hardware access |
| nix-colors integration | 167 hardcoded colors across 6 files. 6h effort. Separate session. |
| External repo flake template | External repo work, separate session |
| Deploy & verify (`just switch`) | Needs user to run on live system |
| Hermes SSH deploy key | Needs SSH key generated and added to repo |

## Execution Tasks (sorted by impact × urgency ÷ effort)

### Phase 1: Quick Wins (code-only, ≤12min each)

| # | Task | Status | Effort |
|---|------|--------|--------|
| 1 | Fix Dozzle — use inline oci-containers in configuration.nix instead of module | IN PROGRESS | 12min |
| 2 | Add Caddy vHost for Dozzle (`logs.home.lan` via inline config) | PENDING | 5min |
| 3 | Add /data disk growth Gatus check | PENDING | 10min |
| 4 | Delete disabled orphan modules (photomap, voice-agents, minecraft) | PENDING | 5min |
| 5 | Remove Darwin SublimeText LaunchAgent orphan | PENDING | 5min |
| 6 | Create `just status` command | PENDING | 10min |
| 7 | Add per-threshold SigNoz channel routing (critical→Discord) | PENDING | 10min |
| 8 | Configure Hermes OpenRouter as secondary LLM | PENDING | 10min |

### Phase 2: CI Pipeline

| # | Task | Status | Effort |
|---|------|--------|--------|
| 9 | Create `.github/workflows/ci.yml` with nix install + cache | PENDING | 10min |
| 10 | Add `just test-fast` + `just hash-check` + `just test-exec-paths` steps | PENDING | 10min |
| 11 | Add `just test` (full build) on merge to master | PENDING | 5min |

### Phase 3: Testing

| # | Task | Status | Effort |
|---|------|--------|--------|
| 12 | Create dnsblockd nixosTest with mock sops | PENDING | 12min |
| 13 | Wire nixosTests into CI | PENDING | 5min |

### Phase 4: Code Quality

| # | Task | Status | Effort |
|---|------|--------|--------|
| 14 | Audit flake inputs (48 total) — list unused | PENDING | 12min |
| 15 | Remove unused flake inputs | PENDING | 10min |
| 16 | Convert go-auto-upgrade `path:` input to SSH URL | PENDING | 10min |

### Phase 5: Documentation

| # | Task | Status | Effort |
|---|------|--------|--------|
| 17 | Update AGENTS.md with session 117-118 changes | PENDING | 10min |
| 18 | Update TODO_LIST.md with completed items | PENDING | 10min |
| 19 | Update FEATURES.md with new services | PENDING | 10min |

### Phase 6: Final Verification

| # | Task | Status | Effort |
|---|------|--------|--------|
| 20 | Run `just test-fast` — all checks pass | PENDING | 5min |
| 21 | Commit with detailed message | PENDING | 5min |

## Disk Usage Context (discovered during research)

```
/data — 946G / 1.0T (93%)
├── /data/models         481G  (AI models — Ollama, video gen, anime)
├── /data/llamacpp-models 207G  (GGUF quantized models)
├── /data/ai             174G  (AI workspaces — 124G models + 51G cache)
├── /data/SteamLibrary   107G  (Steam games)
├── /data/unsloth         28G  (ML training)
├── ClickHouse             8K  (NOT a disk consumer)
└── Docker                  0  (containers stopped)
```

Root cause of disk full: AI models (862G = 91%). Not ClickHouse/Docker/observability.
