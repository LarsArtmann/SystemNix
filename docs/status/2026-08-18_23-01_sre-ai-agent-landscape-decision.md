# SRE AI Agents — Landscape & Adoption Decision

_Session note (2026-08-18): research + recommendation from a Q&A discussion. No code changed._

---

## 1. What big companies call DevOps people

Mostly **Site Reliability Engineer (SRE)** — a term Google coined — plus variations:

| Company | Title |
|---------|-------|
| Google, Netflix, Meta | SRE (Meta: "Production Engineer") |
| Microsoft/Azure | Cloud Engineer, Platform Engineer, or SRE |
| Amazon | Systems Development Engineer |

The broader umbrella terms today are **Platform Engineer** and **Infrastructure Engineer** — "DevOps Engineer" itself is more common at smaller companies.

---

## 2. Open Source SRE AI Agent Landscape (as of 2026-08)

The four genuine incident-investigation agents:

| Project | What it does | Notes |
|---------|--------------|-------|
| **[HolmesGPT](https://github.com/HolmesGPT/holmesgpt)** | Agentic RCA across 30+ observability tools (Prometheus, Grafana, PagerDuty, K8s), read-only by design. New "Operator Mode" runs 24/7 and opens PRs | CNCF Sandbox, ~3.1k stars, Microsoft contributions, very active |
| **[OpenSRE](https://github.com/Tracer-Cloud/opensre)** | Framework for self-hosted AI SRE agents, 60+ integrations, RL/simulation environment ("SWE-bench for SRE"), BYO-LLM | Fastest riser (~10.6k stars since Jan 2026) but Public Alpha |
| **[k8sgpt](https://github.com/k8sgpt-ai/k8sgpt)** | Deterministic K8s analyzers + LLM explanations, MCP server, operator with gated auto-remediation | Most established (~8.1k stars, CNCF since 2023) |
| **[Aurora](https://github.com/Arvo-AI/aurora)** | Multi-cloud incident mgmt: LangGraph supervisor + sandboxed sub-agents run kubectl/aws/az/gcloud in K8s pods, auto-postmortems, remediation PRs behind approval gate, self-hosted | Small community (~400 stars) but production-mature (v1.x) |

Commonly paired with (not agents themselves):

- **[Keep](https://github.com/keephq/keep)** — open-source AIOps alert management/correlation (~12.2k stars; MIT core + proprietary `ee/`)
- **[kagent](https://github.com/kagent-dev/kagent)** — CNCF K8s-native agent framework (agents/tools as CRDs)
- **[Coroot](https://github.com/coroot/coroot)** — eBPF observability with built-in AI RCA (~7.9k stars)
- **[AIOpsLab](https://github.com/microsoft/AIOpsLab)** — Microsoft's benchmark harness for evaluating AIOps agents
- **[kubectl-ai](https://github.com/GoogleCloudPlatform/kubectl-ai)** — Google's natural-language kubectl assistant (~7.5k stars)

Archived/dead: IncidentFox OSS (archived 2026-05-31 — not maintained).

---

## 3. Decision: Should SystemNix adopt one?

**Verdict: No — the fit is poor. If we want more AI in the ops loop, extend PapDashboard instead.**

### Reasons against adoption

1. **Stack mismatch.** HolmesGPT/k8sgpt/Aurora are Kubernetes- and SaaS-centric (K8s APIs, PagerDuty, Datadog, cloud CLIs). SystemNix runs zero Kubernetes — the actual surface is systemd/NixOS/Gatus/SigNoz/Caddy/BTRFS, for which none of these tools ship real integrations.
2. **We already built the local version.** PapDashboard's insight enricher (journal evidence reads + FastFlowLM LLM at `:52625/v1`, best-effort, never fatal) *is* a mini AI-SRE, wired to the actual stack. An off-the-shelf agent would see none of it.
3. **The moat is knowledge, not the agent.** Our repeated failure class — phantom greens, 226/NAMESPACE aborts, method-case bugs, zombie mounts, stale daemon caches — is documented in AGENTS.md / gotchas-archive. None of these tools can consume that corpus. Crush sessions (which read AGENTS.md) are already the working RCA layer.
4. **Operationally wrong shape.** These agents want container orchestration, cloud credentials, and SaaS alert routing; SystemNix's equivalent primitives (hardened systemd units, sops, gatus, backup-coordination) have no plugin surface for them.

### Better ROI: extend PapDashboard's enricher

- More `journalUnits` / `evidenceURLs` sources (node_exporter already wired; candidates: caddy access logs, smartd, btrfs-health metrics)
- Remediation hints: let the LLM suggest links into AGENTS.md / `docs/gotchas-archive.md` for known failure classes
- This is architecturally the same pattern as OpenSRE (tool-calling loop over evidence + LLM + notify), just pointed at our reality

### If experimenting anyway

HolmesGPT supports custom OpenAI-compatible backends → it could talk to FastFlowLM (`http://127.0.0.1:52625/v1`, model `qwen3.6-moe:35b-a3b`). Caveats: cold load 1-3 min per activation, 10-connection hard limit, and it would still lack meaningful sources to investigate. Treat as a weekend toy, not an adoption.

---

## Revisit triggers

Re-evaluate if any of these change:

- We adopt Kubernetes anywhere (→ k8sgpt becomes relevant)
- OpenSRE leaves alpha and grows systemd/NixOS-adjacent integrations
- PapDashboard enricher hits a ceiling that an agent framework solves (tool-use complexity, eval, multi-step reasoning)
