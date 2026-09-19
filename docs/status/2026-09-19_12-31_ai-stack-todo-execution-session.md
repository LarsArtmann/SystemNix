# Status — ai-stack TODO execution session (2026-09-19 12:31)

**Session scope:** execute `docs/todo/ai-stack.md` (all `[ready]` items, triage the rest). Read/understand/research/reflect first, then execute-and-verify step by step.

**Outcome headline: the session completed the READ/UNDERSTAND/RESEARCH phase for every `[ready]` item — including full implementation designs and two live verifications that RESOLVE items outright — but landed ZERO code edits.** The tree is clean (`git status` empty; last human-ish commit `aff31b77`, not mine). Every design below is complete enough to execute mechanically; nothing needs re-research.

---

## a) FULLY DONE

1. **Item "Check Jan's model registry for dangling references to the trashed gemma GGUF" — VERIFIED, closable.**
   `grep -rl "gemma-4-31b-abliterated"` over `/data/ai/models/jan/`, `~/.config/Jan/`, `~/.local/share/Jan/` → **zero matches**. The path-guard bullet's "never imported" inference is now VERIFIED: no dangling registry references exist. The model inventory (14 dirs under `/data/ai/models/jan/llamacpp/models/`) contains no `31b-abliterated` entry. `trash` of the corrupt GGUF left no references behind.

2. **Item "Source-check crush for a native state-dir/XDG_STATE override" — RESEARCH COMPLETE, resolvable as "no migration; keep symlinks".**
   Sourcegraph over `github.com/charmbracelet/crush` (deployed binary is v0.95.0):
   - `internal/config/config.go`: `defaultDataDirectory = ".crush"` — the per-project session dir IS a config option (`cfg.Options.DataDirectory`, set via `cfg.setDefaults(workingDir, dataDir)` in `internal/config/load.go`).
   - Env/global overrides exist ONLY for home-side paths: `CRUSH_GLOBAL_CONFIG`, `CRUSH_GLOBAL_DATA`, `CRUSH_CACHE_DIR`, `CRUSH_SKILLS_DIR`, `XDG_DATA_HOME` (all under `~/.local/share/crush` etc., none of which are the QLC problem).
   - **No global/env knob relocates the per-project data dir.** Using the native knob would mean writing an `options.data_directory = /mnt/hot/crush/<project>` `.crushrc` into EVERY repo — tracked-file pollution + merge churn in 260+ repos, strictly worse than the existing symlink fan-out (crush-hot-db module).
   - Per-project `crush.db` confirmed real and huge (`~/projects/SystemNix/.crush/crush.db` = 3.4 GB, actively written by this very session).

3. **Item "Re-scope or close TODO 434 (deploy.sh llama containment stop-list)" — INVESTIGATION COMPLETE, close as moot.**
   `grep -n "llama" scripts/deploy.sh` → the ONLY llama reference is `llama-rag-model-fetch` in the provisioner restart list (line 438). **The containment stop-list was never implemented**, and the item's own instruction is "do not build dead defense" now that the 0.3.0 pin-back fixed the root cause. Closure rationale: not-built AND not-needed.

4. **Item "flm-dark aggregate monitoring check" — the "add an aggregate check" half is ALREADY SATISFIED by an existing check.**
   `modules/nixos/services/system-health.nix:1763-1776`: Gatus **"FastFlowLM NPU LLM"** already watches `system_service_state_failed{service="fastflowlm"} 0` + `system_service_start_limit_hit{service="fastflowlm"} 0` (fail-closed: metric absent = red). The corpse era kept the unit in permanent failed/start-limit-hit — that check could not have been silent. Remaining sub-question (did Discord actually DELIVER during Sep 4–11) needs gatus sqlite history → root-only, stays `[blocked:user]`.

5. **Live verifications that anchor several items:**
   - `journalctl -u fastflowlm.service` **works as lars** (rc=0) — the corpse-gate design (Item C) needs no privilege changes.
   - PMA metrics read live from `/var/lib/prometheus-node-exporter/textfile_collectors/system_health.prom`.

---

## b) PARTIALLY DONE

6. **Item "FastFlowLM smoke: assert model NAME in `/v1/models` + idle-check unit test" — half of it is already in the tree.**
   `scripts/post-deploy-check.sh:287-299` ALREADY derives the bound model from the deployed unit's ExecStart (`systemctl cat fastflowlm.service | sed -n 's/.*flm serve \([^ ]*\).*/\1/p'`) and asserts it in the `/v1/models` body, with a distinct FAIL for answered-but-wrong-model. That sub-item is DONE (by a prior/parallel session). The **idle-check unit test does not exist** — full design below (§f.1).

7. **Item "flm-dark aggregate monitoring check" — PMA recalibration half.**
   Live probe answers the item's literal question: **`fallbacks_over_threshold` IS tripping right now** — `system_pma_commit_fallbacks_24h = 1337`, `system_pma_commit_failures_1h = 19` (threshold 3 → `failures_over_threshold 1`), `scrape_errors 0`. The count threshold works at high volume. The real residual gap: a week of 100% fallbacks at LOW commit volume (e.g. 2 heuristic commits/24h) trips NOTHING (2 < 20). Designed but not implemented: ratio-based signal (§f.2).

8. **Item "Rogue-listener defense for :8848/:8849 while llama-rag is disabled" — MOTIVATION PROVEN LIVE, design complete, not implemented.**
   **TWO rogue orphan llama-servers are live RIGHT NOW** on the wedged `llama-cpp-0.4.0` build (the module's pinned build is 0.3.0 — anything 0.4.0 on these ports is by definition foreign):
   - PID **995413** — `bge-m3` on **:8848** — uid 975 (hermes), PPid 1, cgroup `user@975.service/app.slice/hermes-worker-cron-ed3fc8b0…scope` — **State S, 37.4% CPU sustained, 1h46m40s CPU over 4h45m elapsed = the mid-load spin class, ACTIVE**.
   - PID **995415** — `bge-reranker-v2-m3` on **:8849** — same orphan shape, 0.9% CPU.
   This is the 2026-09-18 orphan class RECURRED (third time: 09-18, the 09-19 report, now). Nothing detects it today. I cannot kill uid-975 processes (no sudo in agent sandbox). Full design at §f.3 — the new collector would flag both rogues immediately on first run.

9. **Item "Paperless RAG degradation visibility" — design complete, not implemented.** §f.3 covers it (same collector + second Gatus check).

10. **Item "Gate the flm smoke probe on the corpse signature" — design complete, not implemented.** §f.4.

11. **Item "Bisect the llama.cpp 0.3.0 mid-load CPU-spin upstream" — harness design complete, script not written.** §f.5. (The bisect EXECUTION itself is root-gated + owner-consent-gated: it needs GPU soak runs on this freeze-prone box.)

12. **Item "`nixpkgs-llama-rag` pin expiry review" — probe design complete, workflow not written.** §f.6.

---

## c) NOT STARTED

13. **ALL code edits.** Nothing in the tree changed this session. Specifically not started:
    - `modules/nixos/services/llama-rag.nix` dark-guard (Items K+L) — §f.3.
    - `modules/nixos/services/system-health.nix` PMA ratio metric — §f.2.
    - `scripts/post-deploy-check.sh` corpse gate — §f.4.
    - `tests/test-fastflowlm-idle.nix` + `tests/default.nix` registration — §f.1.
    - `scripts/llama-rag-soak.sh` + flake app — §f.5.
    - `.github/workflows/llama-rag-pin-expiry.yml` — §f.6.
14. **Todo bookkeeping:** `docs/todo/ai-stack.md` updates (close Items B/E/F with outcomes; retag D-history + J-execution as `[blocked:user]`), `TODO_LIST.md` queue sync, CHANGELOG pruning of closed items. None touched.
15. **Verification gates:** no `nix fmt`, no `nix flake check --no-build`, no evals run (nothing to verify — no edits).
16. **The `[watch]` / `[decision]` items** (flm v1.0.2 SIGABRT watch, llama-rag monitoring depth, post-deploy llama-rag verification chain, MiniMax quota, paperless reranking direction) — untouched by design (owner/time-gated).

---

## d) TOTALLY FUCKED UP

Nothing destructive happened — but three honest failures:

17. **The session produced designs instead of code.** The instruction was execute-and-verify step by step; I front-loaded inventory so heavily that the context budget burned on research before the first edit. The corpse gate (Item C) is a ~15-line edit and should have landed in the first hour.
18. **Pipeline-masking trap caught in my own probe.** My first Jan grep ended with `| head; echo "grep rc=$?"` — the rc was `head`'s, not grep's (the EXACT lesson AGENTS.md codifies). I re-ran it correctly, but I should have written it right the first time.
19. **Missed signal for ~30 minutes:** the first Jan-grep run printed an `Input/output error` on `/data/ai/models/jan/llamacpp/models/llmfan46/gemma-4-26B-A4B-it-ultra-uncensored-heretic-Q4_K_M/mmproj.gguf` and I initially treated it as noise. That is a **live EIO on /data** — the known /data damage domain (storage.md owns the repair). Flagged now (§f.9); earlier attention could have started the csum/scrub-delta triage sooner.

---

## e) WHAT WE SHOULD IMPROVE

20. **The orphan-recurrence loop is unowned.** Three occurrences of hermes-cron-spawned llama-servers (09-18, 09-19 report, live now) and the TODO only asks for detection. The ROOT question — why does a hermes cron worker spawn `llama-server` against `:8848/:8849` at all — lives in the hermes workspace (cron job definitions), not in this repo, and no tracked item owns it.
21. **`llama-rag` re-enable gate has no mechanical enforcement.** The soak-before-re-enable doctrine lives in AGENTS + status docs; nothing in the flake blocks flipping `llama-rag.enable = true` without a recorded soak pass. §f.7 proposes an eval-time gate keyed on a soak-evidence file.
22. **PMA Commit Health thresholds are volume-blind** (absolute counts only). The ratio design (§f.2) fixes the silent class; consider also whether `failures_1h ≥ 3` is right when the daemon legitimately retries.
23. **The dispatch queue has systemic malformed rows** — bare `- [ ] **Source:** → [docs/todo/…].md` lines in storage/stability/monitoring/ai-stack/pipeline/desktop (docs-health HARVEST artifact). Out of ai-stack scope, but every section is affected; a pipeline-docs item should own the harvest fix.
24. **Textfile-dir stale tmp leftovers** (`niri.prom.tmp`, `niri.prom.sXCFYd`, `buildcache.prom.bKDc8n`, `system_health.prom.{1AbqhL,3HUT6H,5CdOla}`) — the tracked monitoring item covers the audit; the existing files are root-owned and need a one-time root cleanup.
25. **Item A's "already implemented" half shows queue/AGENTS drift** — the smoke assertion exists in the tree but the TODO still lists it as open. Queue items asserting system state need the reconcile-before-execution step (the upstream.md queue-intake rule) applied here too.

---

## f) TOP THINGS TO DO NEXT (ordered; designs included so execution is mechanical)

**Code items (agent-actionable, in execution order):**

1. **Idle-check unit test** — new `tests/test-fastflowlm-idle.nix` + register in `tests/default.nix` (`fastflowlm-idle-check = import ./test-fastflowlm-idle.nix { inherit pkgs self; };`). runCommand-based (no VM): pull the SHIPPED script via `self.nixosConfigurations.evo-x2.config.systemd.services.fastflowlm-idle.serviceConfig.ExecStart`, sed-inject stubs for `systemctl` (bare command → `$STUBS/systemctl`) and `journalctl` (`/nix/store/…-systemd…/bin/journalctl` → `$STUBS/journalctl`; runtimeInputs shadow PATH stubs — the DMS lesson), then 5 mode-file-driven cases: (i) backend inactive → exit 0, no stop; (ii) live `fastflowlm@*` instance → exit 0, no stop; (iii) active <10 min (stub returns `now_us - 300e6`, `now_us` computed from real `/proc/uptime` via gawk in the stub) → exit 0, no stop; (iv) old + journal traffic ("TCP connection established") → exit 0, no stop; (v) old + silent → exit 0 AND stop recorded for BOTH `'fastflowlm@*.service'` and `fastflowlm.service` AND **no `socket` token in the recorded stop args** (the 2026-08-18 never-stop-the-socket regression guard). Assert sed coverage (stub path count) before running, so a failed injection fails loudly instead of phantom-green.

2. **PMA fallback-ratio recalibration** in `system-health.nix`: add `PMA_COMMITS_24H` journal count (`--since "-24h" --grep "committed changes"`, same timeout-60/exit≤1 discipline; init `""`, merge its status into the existing fail branch), compute `PMA_COMMIT_RATIO_OVER=1` when `total ≥ 3 && fallback*100/total ≥ 90`, emit `system_pma_commit_fallback_ratio_over_threshold` UNCONDITIONALLY in the success block (0 when below floor — never a value-less line, never absent-on-quiet-week) + optional `system_pma_commit_fallback_ratio_percent` only when computable. Add `[BODY] == pat(*\nsystem_pma_commit_fallback_ratio_over_threshold 0\n*)` to the "PMA Commit Health" conditions (system-health.nix:1754-1759). Verify the exact success journal line first (`journalctl -u projects-management-automation --since -25h --grep "committed"` sample) before trusting the grep.

3. **llama-rag dark-guard (Items K+L)** in `modules/nixos/services/llama-rag.nix`:
   - Restructure `config = lib.mkIf cfg.enable { … }` (line 304) → `config = lib.mkMerge [ (lib.mkIf cfg.enable { … }) (lib.mkIf (!cfg.enable) { …dark guard… }) ]`.
   - In the `let`: `paperlessWantsRag = ((config.services.paperless or { }).enable or false);` + `darkGuardScript` (writeShellScript, exact leakMetricsScript hygiene: mktemp XXXXXX + chmod 644 + trap EXIT + mv + CAP_FOWNER in unit). Emission: `llama_rag_ports_rogue_listeners` (`grep -cE ":(embPort|rrPort)[^0-9]"` over `timeout 10 ss -tln`, `|| true`, emit only when computed), `llama_rag_dark_scrape_errors`, and — only when `paperlessWantsRag` — `paperless_rag_embeddings_dark 1` (always 1 while the collector exists, BY CONFIG: a rogue listener must never turn this green).
   - Unit `llama-rag-dark-guard` + 5-min timer, mirroring `llama-rag-leak-metrics` (lines 410-436: harden{} merge, Type oneshot, CAP_FOWNER CAP_DAC_OVERRIDE, TimeoutStartSec 1min, ioTier.background, startLimit 3/300s). No deploy.sh entry needed (timer-driven like the leak collector).
   - Second registry entry in the disabled branch: `services.integration.llama-rag-dark = { enable = true; vHost.layer = "none"; checks = [ rogue-check ] ++ lib.optionals paperlessWantsRag [ dark-check ]; }`. Rogue check: node-exporter :9100, `[BODY] == pat(*\nllama_rag_ports_rogue_listeners 0\n*)` + `[BODY] != pat(*\nllama_rag_dark_scrape_errors 1*)` — **first run will be RED: both live rogues (§b.8) are the alert working as designed**. Dark check: `[BODY] == pat(*\npaperless_rag_embeddings_dark 0\n*)` — deliberately red while disabled (one alert, standing dashboard red, Turso precedent), disappears on re-enable when the enabled-side entry's /health checks take over. Verified against integration.nix assertions: absolute `url` avoids checkWithoutPort; no subdomain avoids dnsMissing; layer "none" avoids vhost fan-out; homepage/otel/backup/monitored default null/false → no other fan-out.

4. **Corpse gate** in `scripts/post-deploy-check.sh` (inside `if $flm_enabled; then`, before the curl at line 287): capture `timeout 20 journalctl -u fastflowlm.service --since "-2h" --grep "bind: Address already in use" --output cat --no-pager -n 1` into a var (`|| true`, no pipe), and when non-empty `report_fail` immediately with the reboot-only message — `elif` the existing curl block. Prevents the 480s stall + doomed-start + 21.6 GB cold-load churn per smoke.

5. **Soak harness** `scripts/llama-rag-soak.sh` (root-run; the bisect EXECUTION gate): assert EUID 0 + llama-rag disabled (or `--force`); `systemd-run --unit=llama-rag-soak-embeddings --collect` with the EXACT sandbox mirrored from `lib/rocm.nix` `deviceCgroup` (DevicePolicy=strict; DeviceAllow /dev/null,/dev/zero,/dev/full,/dev/random,/dev/urandom,/dev/dri/,/dev/dri/renderD128,/dev/kfd) + `Environment=HSA_OVERRIDE_GFX_VERSION=11.5.1` + `HSA_ENABLE_SDMA=0` (rocm.nix `env`); candidate server binary + real GGUF + scratch port (18848); sampler: per-process `%CPU` from `/proc/<pid>/stat` every 10s + `/health` poll; verdict SPIN when sustained >50% CPU after warmup with /health dark (the freeze-5 signature was ~94% ×2 with /health 503); ≥10 min default (`--minutes`); exit 0 pass / 1 spin / 2 usage. Optionally register as flake app via the `mkApp` pattern (flake.nix:2077-2097). First real run must validate the property capture.

6. **Pin-expiry probe** `.github/workflows/llama-rag-pin-expiry.yml`: monthly cron (e.g. `0 8 1 * *`, staggered), DeterminateSystems nix-installer + NIX_GITHUB_RO_TOKEN access-token conf (copy nixpkgs-compat.yml:15-21), eval `nixpkgs-llama-rag.legacyPackages.x86_64-linux.llama-cpp.version` (pinned, expect 0.3.0) and `github:NixOS/nixpkgs/nixos-unstable` llama-cpp version; if they differ, create/refresh ONE standing issue (label `llama-rag-pin`, image-updates.yml dedupe pattern) instructing the §f.5 soak against a fresh 0.4.x build; closing the issue = "reviewed this month", next run reopens → a working monthly review loop. No issue once versions converge (pin dropped).

**Owner/user-gated (hand over):**

7. **Kill the live rogues** (root): `sudo kill 995413 995415` (verify PIDs still the llama-servers first — PID reuse). Then decide the ROOT question: why hermes cron workers spawn llama-server at all (hermes workspace cron definitions — §e.20).
8. **Bisect execution** (root + owner consent): run §f.5 soak against candidate 0.4.x builds (and, if the spin survives across llama.cpp versions — as freeze-5 proved — bisect ROCm runtime/kernel/GPU-state upstream of llama.cpp, per the item).
9. **/data EIO triage**: `smartctl -A` + scrub delta on the `mmproj.gguf` file's volume (llmfan46 model dir) — storage.md owns; file may be a single-victim repair candidate.
10. **flm-dark history verification** (root): gatus sqlite (`/var/lib/private/gatus/gatus.db`) — confirm "FastFlowLM NPU LLM" fired during Sep 4-11 (mechanism analysis says it must have been red; this closes the item's first half with evidence instead of inference).
11. **Deploy the batch** once items 1-6 land: pressure-gated `nix run .#deploy` (expect the two new AI checks red — rogue real, dark by-design — plus §10 auto-loan for the new metrics).

**Bookkeeping (agent-actionable, quick):**

12. Update `docs/todo/ai-stack.md`: mark Jan-registry + crush-source items done (move to CHANGELOG), close TODO 434 as moot (rationale: never built + root cause fixed), retag bisect-execution + flm-dark history as `[blocked:user]`, trim the smoke item to idle-check-test only, note the aggregate-check half already exists.
13. Sync `TODO_LIST.md` ai-stack queue rows accordingly.
14. Prune closed rows to `CHANGELOG.md` per house rules.
15. Verify: `nix fmt --no-update-lock-file` on touched files only, `nix flake check --no-build`, run the new idle-check test derivation, extendModules probe of the `llama-rag-dark` entry on evo-x2 (registry checks render, assertions pass), and the negative-eval-cache discipline for any new assertion case.

---

## g) QUESTIONS FOR THE OWNER

1. **The two live rogues (PID 995413 :8848 @37% CPU, 995415 :8849, uid 975 hermes-cron orphans on the wedged 0.4.0 build):** shall I hand you the exact kill commands now, and do you want hermes cron workers barred from spawning llama-servers at the source (hermes workspace cron definitions)?
2. **The flm smoke model-name assertion already exists in the tree** (post-deploy-check.sh:287-299, landed by another session) — OK to mark that half of the ai-stack item done, or was a DIFFERENT assertion intended (e.g. probing an instance other than the deploy smoke)?
3. **Two standing `[decision]` items in this domain** — MiniMax quota (carried ×5) and paperless reranking direction (drop :8849 at re-enable vs. file upstream first): still deferring both, or decide now so the re-enable work items can incorporate the outcome?

---

**Design-artifact note:** every design in §f.1-6 was derived against the current tree this session (file:line references verified). A follow-up session can execute items 1-6 + 12-15 without re-doing ANY of the research; the only new information needed since this report is whether the rogues were killed and whether the tree moved (rebase/re-read before editing — parallel sessions are active).
