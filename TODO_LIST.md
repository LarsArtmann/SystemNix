# SystemNix TODO — Dispatch Queue

**This file is the QUEUE**: every agent-actionable (`[ready]`) open item, one line each, linking into its domain library. The tq pool (`repos = "CV,SystemNix,go-taskqueue"`) harvests THIS file only — blocked, watch, decision and upstream-push items are deliberately NOT here, so agents stop being dispatched at work they are banned from doing (sudo, pushes, browser ceremonies).

**Routing rules** (docs-health HARVEST writes at append time — NEVER as dated sections; the 2026-09-19 split retired that growth pattern):

- actionable engineering → one line here + the full entry (ask + blocker + `**Source:**`) in the domain library
- blocked on sudo / browser / external console / owner hands → library only, `[blocked:user]`
- blocked on an upstream push/tag → library only, `[blocked:push]` (agents implement locally, never push)
- waits on a deploy or a time window → library only, `[blocked:deploy]` / `[watch]`
- owner question → library only, `[decision]`
- vague / long-term → `ROADMAP.md`

Done items are pruned to `CHANGELOG.md` at every pass — a `[x]` row must never persist here. Verification narratives go to the status report, never the item. Full contract: `AGENTS.md` → "TODO System".

## Queue

<!-- QUEUE:BODY -->

## Libraries

| Library | Owns |
| --- | --- |
| [docs/todo/storage.md](docs/todo/storage.md) | BTRFS, btrbk + pool backups, /data repair, Samsung hot-DB tier, buildcache, offsite Borg, ClickHouse XFS |
| [docs/todo/stability.md](docs/todo/stability.md) | freezes, memory-guard + sev1, PSI/IO storms, boot resilience, journald/oomd, USB/NIC hardware |
| [docs/todo/monitoring.md](docs/todo/monitoring.md) | Gatus, SigNoz, textfile collectors, system-health, alert routing (cross-service) |
| [docs/todo/ai-stack.md](docs/todo/ai-stack.md) | FastFlowLM, llama-rag/llama.cpp, ollama, GPU/ROCm, RAG consumers, whisper |
| [docs/todo/services.md](docs/todo/services.md) | per-service debt + go-lives (paperless, hermes, forgejo, miniflux, …) |
| [docs/todo/upstream.md](docs/todo/upstream.md) | LarsArtmann Go-ecosystem chains, nixpkgs/HM/third-party contributions, go-taskqueue |
| [docs/todo/security.md](docs/todo/security.md) | key rotation, secrets/sops, gitleaks policy, leak residues |
| [docs/todo/pipeline.md](docs/todo/pipeline.md) | deploy.sh, pre/post-deploy checks, flake checks + eval audits, CI, repo/docs hygiene, queue conventions |
| [docs/todo/desktop.md](docs/todo/desktop.md) | niri, DMS/Quickshell, Qt, audio, shell UX, Signal |
| [docs/todo/pixel6.md](docs/todo/pixel6.md) | Pixel 6 recovery → media-archive project |

_Completed work: [CHANGELOG.md](./CHANGELOG.md). Long-term ideas: [ROADMAP.md](./ROADMAP.md)._
