# Browser History AI endpoint rewire (ai-meter → llama-chat) — status

**Session:** 2026-10-27 ~20:55–ongoing · **Trigger:** owner — "the AI endpoint we supply to browser-history NEVER worked and it's pathetic"

## §a Verdict

The browser-history AI suite was wired (2026-10-15) directly at FastFlowLM `:52625/v1`. That endpoint is dead most of the time the owner could ever click: flm is the memory-emergency-guard's designated sacrifice — trips stop `fastflowlm.socket` itself (the re-activation listener) and the 3/day restore cap leaves `:52625` connection-refused for hours. Live evidence at session start: socket `inactive`, SEV1 bridge "MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED", server journal full of `dial tcp 127.0.0.1:52625: connect: connection refused` on every AI attempt since boot (20:49 owner click included). Guard trips are near-daily since Sept (`restores-2026xxxx` state files for almost every day). "NEVER worked" was accurate from the UI's perspective.

**Fix:** interactive AI now rides ai-meter `/v1/llama-chat` (always-on CPU llama.cpp :8850, same Qwen3.6-35B-A3B family) with a runtime-minted per-client key — metered into SigNoz + the usage ledger like every other AI call, per the owner's same-session "single endpoint" direction. Direct-flm values survive only as the standalone-module fallback (VM tests).

## §b What changed (all eval-green at 21:24; deploy gate-blocked, see §d)

- `modules/nixos/services/browser-history.nix` — `aiMeterEnabled` (option-guarded) selects `llm.baseUrl = :8107/v1/llama-chat`, `llm.model` single-sourced from `services.llama-chat.alias`; `LLM_API_KEY=local` only on the non-ai-meter fallback; `EnvironmentFile=/run/ai-meter-keys/browser-history.env` (minted `LLM_API_KEY`); unit `after/wants ai-meter-keys.service`. Mint failure ⇒ empty key ⇒ AI fails VISIBLE-unconfigured (api/server.go:557 gate), never silent 401s.
- `platforms/nixos/system/configuration.nix` — `ai-meter.clients.browser-history` (`user = "root"`: DynamicUser has no stable uid; the mint's chown-to-root path is designed; systemd reads the env file as root).
- `modules/nixos/services/forgejo.nix` — **in-passing eval-unbreak of HEAD**: the parallel session's 20:57 `gitea-runner-…-ensure` keep-alive unit lacked the forgejo-family condition gate (every evo-x2 eval failed, blocking ALL deploys). Added `unitConfig.ConditionPathExists = subvolMigratedCondition` + family `RequiresMountsFor` per the audit's own prescription — pre-finalize the ensure oneshot now condition-skips instead of 5-min reset-failed churn.
- Docs: browser-history.md AI bullet, ai-meter.md routing + clients tables.

## §c Collateral finding: llama-chat starves under batch storms (new, queued)

Path verification (crush client key → `/v1/llama-chat`) timed out at 120s — NOT a routing bug: llama-chat `/health` 200, slots show the task accepted, journal shows it *completed* — a 13-token/16-max generation took **6m38s** (direct: 1m43s), ~25% of one core, under **loadavg 324** (monitor365 uncapped backlog drain ~500k events/min since 20:33 + 8×8-thread whisper batch + revived CI runner builds). The 502 metered was the probe's own client-timeout echo (proxy has no upstream timeout). Every health-shaped check is blind to serve-path starvation → queued `[ready]` SigNoz TTFT alert row (monitoring.md) + `[decision]` CPU-floor row (ai-stack.md).

## §d Deploy: gate-blocked by the real IO storm — deliberately NOT forced

`nix run .#deploy` refused at the ENTRY pressure gate (I/O PSI some avg10 83.6%, disk busy 106.8%) — the monitor365 drain (owner deciding run-vs-suspend, 20-47 report §g.1; `[blocked:user]` cap-restore row exists). Quiescence discipline held: 4×60s green polls (clean tree, no eval-relevant mtimes <5 min) before firing. A drain-watch (`~/.cache/bh-ai-fix/io-drain-watch.sh`, PSI avg10 <20 ×2) gates the retry — **second window 22:21–23:03 also failed (82–96% sustained; the drain is not draining)**; deploy remains blocked on the owner's run-vs-suspend call. When it fires, the switch also carries the parallel sessions' pending tree state (signoz project_id fix, opencloud port fix, kimi removal — all deploy-blocked rows that ride the same switch). **ADDENDUM 23:1x (self-review):** the EnvironmentFile here originally LACKED the `-` prefix — a missing mint file would have failed the WHOLE unit; fixed to `-/run/ai-meter-keys/browser-history.env` (AI-only degradation) and re-verified eval-green. Full session self-review: `docs/status/2026-10-27_23-12_browser-history-ai-rewire-session-self-review.md`.

## §e Post-deploy verification checklist (pending §d)

1. `journalctl -u browser-history` init line: `AI client initialized, base_url http://127.0.0.1:8107/v1/llama-chat`, `api_key_set:true`; `/run/ai-meter-keys/browser-history.env` exists (root 0400).
2. E2E through the proxy with a valid client key → 200 + tokens (expect SLOW if the storm persists — correctness, not speed, is the gate here).
3. Restore `fastflowlm.socket` (manual start = the guard's designed unblock after RESTORE CAPPED) so PMA/paperless-gpt/enricher wake paths return; expect the guard to re-sacrifice on the next trip — that is the design.
4. Owner first-use smoke (summary + one chat turn) — the standing `[blocked:user]` row, premise updated to the new path.

## §f Follow-up harvest (done at authoring time)

- `[ready]` SigNoz TTFT alert for llama-chat starvation — monitoring.md + queue ✅
- `[decision]` interactive-inference CPU floor — ai-stack.md ✅
- `[ready]` Paperless AI embeddings through ai-meter — services.md + queue ✅
- First-use-smoke row premise updated on BOTH surfaces (queue + services.md) ✅
- Deliberately NOT harvested: monitor365 drain cap (already `[blocked:user]`, owned by the 20-47 session).
