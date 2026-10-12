# Session Status — llama-chat exposure, ollama removal, Vulkan path (2026-10-12 17:56)

**Machine:** evo-x2 (AMD Ryzen AI Max+ 395, gfx1150, 128 GiB unified, NixOS unstable, kernel 7.2.9)
**Scope:** THIS session only — the llama-chat port/domain work, the unified-management + "better model" explorations, the owner's ollama directive and its full execution, the memory-guard analysis, and the Vulkan iGPU path. Concurrent sessions (bootpath dispatch, inboxclean-module-migration, eventcatalog, hot-db wave5) touched the same tree; their work is NOT claimed here, only the races with it.
**Commits (mine):** `32cb2e77` (ollama directive recorded) → daemon swept the code removal (`09f4dafa`, exclusively mine) → `38379e05` (removal close-out docs) → daemon-swept batches (`e84228f1`, `424a0a1e`, `87377294`, `dc2a4c0f` — contents verified per batch). Earlier same-session: `2e8a32f9`/`abcba6d2` (llama-home.lan exposure) + the `3740fa0b` soft-reset split (dangling after another session's rebase — content verified survived).

---

## a) FULLY DONE

1. **llama-chat exposed at `https://llama.home.lan`** — integration-registry entry upgraded (`vHost.layer = "protected"`, subdomain `llama`, port fan-out), DNS record in `dns-local.nix` (cross-host truth, rpi3 included), PapDashboard "AI"-tab tile `llama.cpp Chat` with loopback `/health` checkUrl, `monitored = true` (system-health). Loopback-bind assertion intact; Caddy proxies. Eval-verified on evo-x2 + full `nix flake check`. CHANGELOG Added bullet + runbook updated.
2. **Ollama owner-directive recorded durably** — with the owner's stated reason ("bad abstraction on top of llama.cpp — I do not want ollama", standing 2026-10-12, fleet-wide) in `docs/services/llama-chat.md`, the `llama-chat.nix` header, `docs/todo/ai-stack.md` scope line, and (as removal) AGENTS.md GPU section + FEATURES.md.
3. **Ollama REMOVED — 9 code + 8 doc surfaces:** service unit + hardening block, gatus check, dashboard tile, SigNoz "Ollama Down" rule, Quickshell DMS widget (plugin dir `git rm`'d), searxng engine entry, port 11434, ai-models paths + `OLLAMA_MODELS`/`OLLAMA_HOST` env, `ai-stack` integration entry, plus ioTier/boot/configuration comment fixes and the AGENTS GPU-section GTT-pattern rewrite (fact preserved, service gone). Verified: `nix flake check` all-pass, evo-x2 toplevel eval, deadnix+statix clean on every touched file. CHANGELOG Removed bullet landed.
4. **paperless-gpt dead vision-route guarded** — its `OLLAMA_HOST` env silently targeted the corpse port (masked by an `or` fallback at eval). Now an eval-time `throw` on `ocrProvider = "llm"` with re-decision pointers (llama-vlm bridge vs upstream OPENAI_BASE_URL split). Option descriptions de-staled.
5. **Live guard data pulled** — `journalctl` works from agent shells (verified live-probe set extension): **293 Zone-6 trips 2026-10-10 → now (~2.5 days, ~117/day)**, +5 zone-2, +4 zone-1. Zone 6 stops flm + churn sources — quantifies the owner's "why is flm getting killed so often".
6. **Vulkan iGPU path queued with verified packaging** — `vulkanSupport` confirmed as a real callPackage arg on the PINNED nixpkgs llama-cpp (override args eval-checked; vulkan-loader/shaderc/spirv-headers inputs present). Experiment row (owner-gated) carries the protocol: small-model llama-bench first, systemd-run sandbox mirroring deployed units (the direct-run lesson), `--ubatch-size ≤ 512` (gfx1151 device-lost class), memory-capped, PSI-watched.
7. **TODO hygiene per system rules** — reclaim row closed `[x]` (owner trashed the tree), post-deploy verification chain row `[blocked:deploy]`, vision-route `[decision]` row, doc-tail `[ready]` row (ai-stack.md); guard 48h re-baseline `[watch]` (stability.md); trash pin-window free-verification `[watch]` (storage.md); concurrent-edit-loss policy `[decision]` (pipeline.md). CHANGELOG entries for both the exposure and the removal.
8. **Daemon-race handling** — one soft-reset split executed per policy (exclusivity check, zero-content-loss proof), 5 daemon sweeps verified per batch (`git show --stat` each), 2 silently-lost edits recovered by per-surface re-verification.

## b) PARTIALLY DONE

1. **EVERYTHING IS UNDEPLOYED.** The running system still serves ollama on :11434 with its widget polling every 5s; `llama.home.lan` does not resolve into Caddy yet. All of section a) is git-side only until `nix run .#deploy` (owner-gated calm window; the deploy pressure gate decides timing).
2. **"Better model" thread** — research shortlist delivered (same-arch quant upgrade / empero distill at zero speed cost; gpt-oss-120b for tool-reliability at ~parity speed; Qwen3-Next CPU-hostile, GLM/Llama4 disqualified by active params), but NO bench ran and the candidate set is gated on the unanswered abliterated question (§g Q1).
3. **Unified-management analysis** — delivered as analysis (pooling flag is process-global; engine/hardware heterogeneity; failure isolation). Not converted into any code/roadmap item — correctly so (the docs already own the "two servers is the FLOOR" doctrine), but the per-model-pooling upstream watch row doesn't exist yet (folded into §f).

## c) NOT STARTED

1. Vulkan experiment itself (owner-gated; row queued with full protocol).
2. llama-bench A/B for the better-model candidates (parked pending §g Q1).
3. paperless-gpt vision route re-decision (row queued).
4. Post-deploy verification chain for the removal + exposure (row queued).
5. The ollama.png icon cleanup + llama-rag comment cross-ref + AGENTS revisit-condition mention (the doc-tail row).
6. Nothing in this session touched rpi3-dns/darwin beyond the shared DNS list (eval-verified harmless).

## d) TOTALLY FUCKED UP

1. **Two edits silently destroyed by the concurrent session's branch dance** — my configuration.nix + lib/default.nix comment edits vanished from the worktree (checkout `inboxclean-module-migration` → rebase onto origin). Caught ONLY because the close-out re-verified every edit surface individually; the first survival check ALSO false-negatived llama-chat.md (case-sensitive + line-bound rg pattern vs wrapped text). Net cost: one re-edit round + policy row. Had I trusted "the edit tool said success", the removal would have shipped with two stale "Ollama" comments.
2. **Truncated reference map nearly shipped a dangling wire** — the initial ollama sweep was `| head -50`-truncated; paperless-gpt.nix's LIVE `config.services.ollama.port or 11434` reference escaped it and surfaced only in the final verification pass. The `or` fallback made it eval-silent: enabling vision-OCR would have pointed at a corpse port with zero errors anywhere.
3. **rg flag footgun** — `rg -rln` is `-r ln` (REPLACE matches with "ln"), not "recursive list"; an entire grep output came back mangled and I decoded it mentally instead of re-running clean. Risked acting on garbage.
4. **Wrong formatter first** — `nix develop -c alejandra` produced a 428-line restyle churn before the repo's own `nix fmt` wrapper re-formatted; should have used the repo wrapper from the start.
5. **CHANGELOG initially missed** — a fleet-significant removal landed without its CHANGELOG bullet (fixed in this close-out; both bullets now in).
6. **Analysis framing lag** — I presented CPU-only as the stable end-state twice before surfacing the Vulkan bypass; the owner's "iGPU has fucking unified memory" push was the trigger. The alternative-backend research should have preceded the "only stable option" framing.

## e) WHAT WE SHOULD IMPROVE

1. **Removal protocol needs an exhaustive-consumer gate**: reference maps via `rg -l` (file lists, never truncated head-pipes) + a three-axis sweep (port refs, env-var refs, path refs) + a "grep the RENDERED config" pass. The paperless-gpt near-miss is the template failure.
2. **Per-surface verification sweeps after every daemon-adjacent window** — saved this session twice; make them a standing step in multi-session work, not a close-out luxury.
3. **Formatter discipline**: repo wrapper only (`nix fmt` / `fmt-cached.sh`), never ad-hoc alejandra from a dev shell.
4. **CHANGELOG-first closeout**: significant changes get their bullet in the same session as the code.
5. **rg hygiene**: `-r` is replace; `-l` lists. Never combine blind.
6. **"Only-option" claims require an alternatives scan** (Vulkan was one search away).

## f) Next things (session-derived; honest count, not padded to 50)

1. **[owner] Deploy** — `nix run .#deploy` at the next PSI-calm window; carries the ollama removal, llama.home.lan, tile, paperless-gpt guard, and the login-gate fixes from the parallel session.
2. **[blocked:deploy row, queued]** Post-deploy verification chain: `llama.home.lan` 200 via Caddy; tile green; ollama absent + :11434 free (`ss`); gatus "Ollama" check/tile gone; SigNoz rules without ollama-down; no dead DMS widget; `nix run .#post-deploy-check`.
3. **[watch row, queued]** Guard 48h re-baseline — expect the ~117 trips/day Zone-6 cadence to drop with the 32G standing footprint gone; if not, the tq-agent-pool IO-storm rows own it.
4. **[blocked:user row, queued]** Vulkan experiment — build `pkgs.llama-cpp.override { vulkanSupport = true; }`, small-model bench under the sandbox protocol, then (PASS) wire llama-chat with `-ngl` and re-bench vs 17 tok/s.
5. **[decision, §g Q1-gated]** Better-model A/B bench: UD-Q4_K_M + `--cache-type-k/v q8_0` vs current Q4_K_P; empero Qwen3.8 distill probe.
6. **[decision row, queued]** paperless-gpt vision route: llama-vlm bridge vs upstream env split vs drop the OCR leg.
7. **[watch row, queued]** Ollama-tree pin-window verification (~4-5w): df actually frees ~15 G; next /data re-measure should show ai ~15 G lighter.
8. **[ready row, queued]** Doc tail: `ollama.png` icons on llama tiles, llama-rag "why not ollama" cross-ref, AGENTS revisit-condition mentions Vulkan.
9. **[decision row, queued]** Concurrent-edit-loss policy for CONTRIBUTING (§d1).
10. Fold the llama.cpp per-model-pooling upstream watch into the router-mode revisit row (llama-rag consolidation precondition).
11. AGENTS.md "agent live-probe set": add `journalctl -u <unit>` (verified working) next to `ss`/`pgrep`/openssl.
12. Consider a `rg -l`-based removal-precheck helper script (consumer enumeration) — candidate for scripts/ if a third removal happens (two data points so far: Docker, ollama).

_Deliberately not padded to 50: this report is scoped to this session's run per the owner's instruction; items 1-12 are the real session-derived set, all of which are queued (2-9) or owner-gated (1, 5)._

## g) Questions I cannot answer myself

1. **Is abliterated/uncensored a hard requirement for the llama-chat brain?** It gates the entire better-model candidate set: YES → Qwen3.6-family quant/distill swaps only (the HauhauCS tunes); NO → gpt-oss-120b class enters (best tool-calling, ~same CPU speed, MXFP4 ~63 GB fits).
2. **Deploy go?** Run `nix run .#deploy` now / next calm window / bundle with something else? (I can watch PSI but the window call is yours — the removal also deletes a running service mid-widget-poll, which is safe but final.)
3. **Vulkan GPU soak approval:** OK to run the memory-capped, sandboxed small-model experiment on the live box at a quiet moment (sudo systemd-run, PSI-watched), given the freeze history is ROCm-specific and Vulkan's failure modes look different?

---

_Report format note: `.md` at the owner's explicit path demand (the status-report skill's HTML default was overridden by instruction; flagged per skill convention)._

## Addendum (2026-10-12, post-report)

**§g Q1 ANSWERED by the owner:** "gpt-oss-120b is OLD and NOT Abliterated so fucking no!" — abliterated/uncensored is a HARD requirement for the llama-chat brain. Doctrine recorded in `docs/services/llama-chat.md` (Model section) + the `llama-chat.nix` header; the §f.5 bench item is un-gated and queued as a `[ready]` row in `docs/todo/ai-stack.md` with the narrowed candidate set (abliterated Qwen3.6-35B-A3B family quants/distills/tunes ONLY). Q2 (deploy go) and Q3 (Vulkan soak approval) remain open.
