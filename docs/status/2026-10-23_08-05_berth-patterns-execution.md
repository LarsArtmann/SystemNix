# Berth-Patterns Plan Executed — Port Guards, Collector Identity, ai-stack-status

**Created:** 2026-10-23 08:05 CEST
**Scope:** full execution of [docs/planning/2026-10-23_06-59_SUPERB-berth-patterns-adoption.md](../planning/2026-10-23_06-59_SUPERB-berth-patterns-adoption.md) (T1–T8), dispatched by owner paste. Tombstone written at start (37f1e866e); flipped to EXECUTED at close.

## a. What landed

| Task | Delivered | Verification |
| --- | --- | --- |
| T1 port guard | `lib/port-guard.nix` → `mkPortGuard` (extraction of llama-rag's proven script + `/proc/<pid>/stat` f22 identity re-checked before EVERY signal + release verification: surviving foreign holder → BIND-BLOCKED named-fail, not opaque EADDRINUSE); wired `+`-privileged on the flm backend :52626; llama-rag refactored onto it | narrow unit evals render both guards; LIVE dry-fires: flm inert rc 0 (port free), rag guard SPARED its live owner (pid 3503, llama-embeddings.service) |
| T2 negative tests | `tests/test-port-guard.nix` → `checks.x86_64-linux.port-guard-check`: 7 artifact-level decision-path legs (stub-injected ss/cat/kill/sleep against the SHIPPED scripts) + `CASES=portguard` group in `scripts/negative-test-lints.sh` | 7/7 legs green; mutations 3/3 (recheck-drop → pid-reuse leg fires; owner-spare-break → owner-spared leg fires; green control stays green) |
| T3 collector identity | leak collector: identity triple (cgroup ∈ module units AND (pid,starttime) stable AND no module-port listener) + mid-scan-reuse skip; dark-guard: `ss -tlnp` + per-rogue forensic journal line (pid, starttime, cgroup) | live smoke of the SHIPPED artifact (scratch outdir): `leaked 0 / leaks_present 0 / scrape_errors 0` |
| T4 guard liveness | **verified ALREADY-DONE, no code** (see §b) | live spot-check: guard .prom rewritten 6 s before probe; `system_memory_guard_metrics_fresh 1` |
| T5 refusal-with-reason | design note + `services.fastflowlm.refusalReason` (default false, ships DARK — Environment absent, behavior identical); implemented refusal = sacrificed-only (see §c) | proxyConn builds shellcheck-green; flag-off eval: Environment ABSENT |
| T6 ai-stack-status | `scripts/ai-stack-status.sh` + `nix run .#ai-stack-status` (ports from lib/ports.nix as injected JSON; batched systemctl; cgroup-verified port ownership incl. HELD-UNVERIFIED class; guard freshness; leak/dark gauges; `--format json`; exit 1 on red) | live run caught BOTH live findings (§d) with follow-up commands |
| T7 runbooks | fastflowlm.md (port-guard contract + refusal-reason), llama-rag.md (shared helper + collector semantics + rogue finding), inboxclean.md (503-reason consumer paragraph) | — |
| T8 harvest | 5 queue rows ticked + library entries synced (both surfaces); this report self-harvests §f | `bash scripts/check-todo-system.sh` at commit |

## b. T4 — the plan's premise P4 was WRONG, and the protocol caught it

The plan claimed no gatus check watches `system_memory_guard_metrics_fresh`; its grep ran against **gatus-config.nix only**. The check exists in **system-health.nix:2680-2697** ("Memory Guard Collector Fresh", live since 2026-09-15): both anchored legs exactly as the plan prescribed, DOWN alert, sev1 desktop notify. Per the row's own step-1 escape hatch ("if covered, tick with pointer") and §7.8 (no split brain), NO duplicate was added. Lesson for queue authors: premise-grep the owning module, not one config file — per-service checks live in `services.integration.<name>.checks` in the OWNING module (integration-registry step 9; system-health owns this one).

## c. T5 design correction (deviation from plan subtask 5.2, documented)

The plan's shape — "on backend-not-listening → immediate 503 {reason: cold-loading}" — would **defeat socket activation**: the arriving connection IS the backend's wake-up trigger; answering 503 before the wait loop means the backend never starts for refusing clients. Shipped shape: refusal fires ONLY for `sacrificed` (guard `restore_capped 1` → 503 `{"reason":"sacrificed","retry_after":null}`, skipping the pointless 480 s queue); cold-loading keeps hold-by-queue; `bind-blocked` documented as future (needs the guard's verdict pre-wait). llama-chat leg skipped + documented (llama-server serves HTTP directly; no cheap intercept point).

## d. LIVE findings (the plan's incident classes, demonstrating themselves)

1. **Hermes rogue reranker on :8849, live RIGHT NOW**: cgroup `hermes.service`, our pinned 0.3.0 build, `--reranking --pooling rank`, ~14 h old at discovery — the exact 2026-09-18 class, invisible in the enabled era (the dark-guard runs only while the module is disabled; the port is reserved-but-unwatched). NOT killed (production unit's process; owner-gated) → [decision] row in docs/todo/ai-stack.md. ai-stack-status flags it as `:8849 HELD-UNVERIFIED`.
2. **The deployed leak metric has been FALSE-RED since llama-chat landed**: live `.prom` read `leaked_instances 3 / leaks_present 1` (llama-chat's llama-server + visibility gaps miscounted as module leaks) → the gatus "llama.cpp Leaked Instances" check stood RED on false positives — real leaks would drown. Fixed by the T3 semantics change (verified: smoke reads 0); goes green at deploy.
3. **flm.socket inactive** (pre-existing, documented state from the 09-30 corpse episode — restore_capped=0, so not a guard sacrifice; nothing to fix here, noting for the deploy-window check).

## e. Not done / blockers

- **Deploy-gated live proof** (all module changes land inert until the next switch): queued as the [blocked:deploy] live-verification cluster row. Deploys are ALREADY blocked by the foreign blanket-wave eval red (hermes IFD + crowdsec-via-unfetched-nixpkgs; tracked in the pipeline lock-heal [decision] row + the monitor365 deploy watch row) — NOT by this work (proven: the crowdsec eval error reproduces at `4cf457561`, pre-dating all my changes; the concurrent session is actively on it, crowdsec.nix edits riding `f60404e06`).
- Full `nix flake check --no-build` NOT run (same foreign eval red — it aborts at the host toplevel). Compensating verification: every touched surface narrow-evaled green (both guards' ExecStartPre, proxyConn ExecStart, leak-metrics ExecStart, the check derivation, the app), the check + mutation legs + live smokes all green. The pre-commit's eval leg on my commits would hit the same foreign red — committed with `--no-verify` + this justification if it persists at commit time (precedent 73145250).
- T5's `bind-blocked` reason + a rogue-while-enabled GAUGE (dark-guard parity for the enabled era): deliberately not built — new-metric+new-check+new-negative-test is a full guard of its own; the journal line + ai-stack-status cover observation today.

## f. Follow-ups (self-harvested — landed in TODO_LIST.md + libraries at authoring time)

1. [blocked:deploy] Berth-patterns live verification cluster (anchor → post-deploy → ai-stack-status → gatus Leaked-Instances green) — docs/todo/services.md. [harvested]
2. [decision] LIVE hermes rogue reranker on :8849 (kill vs bless) — docs/todo/ai-stack.md. [harvested]
3. Plan §7.8/§7.7 stay binding: no berth daemon ever; refusalReason stays dark until the consumer story is reviewed (the flag exists, off by default). [standing constraint, recorded in the plan + runbooks — no row needed]
4. Watch rows already live from the planning session (berth gfx1150 spike trigger; llama.cpp park/KV upstream watch) — verified present in docs/todo/ai-stack.md, no drift. [verified, no action]

**Deliberately not harvested:** nothing — every §f item landed or is recorded as a standing constraint.

## g. Evidence index

- Guards rendered: `/nix/store/ampg6x5a…-fastflowlm-port-guard.sh` (dry-fire rc 0, free :52626), `/nix/store/jcxxdgv26…-llama-rag-port-guard.sh` (dry-fire: spared owner pid 3503, rc 0)
- Check: `nix build .#checks.x86_64-linux.port-guard-check` → `ALL PORT-GUARD LEGS PASSED`; `CASES=portguard bash scripts/negative-test-lints.sh` → 3/3
- Leak smoke: `llama_rag_expected_instances 1 / leaked 0 / present 0 / errors 0`
- T4: system-health.nix:2680 (grep `Memory Guard Collector Fresh`); introduced `333062898` (2026-09-15)
- ai-stack-status live table: llama-chat :8850 owner pid 141297; embeddings :8848 owner pid 3503; :8849 HELD-UNVERIFIED → red with follow-up cmd
