# Browser-History AI Rewire — Resume Session: Deploy-Slot Status + Self-Review

**Date:** 2026-10-28 00:21 CET · **Session:** resume executor (lineage: 20:47 fix session → 23:12 self-review → this, 23:16–00:21)
**Task:** land the browser-history AI rewire (flm-direct → ai-meter `/v1/llama-chat`, fix complete + eval-green since 23:1x) — deploy + verify.
**Companions:** fix report `2026-10-27_21-40_browser-history-ai-endpoint-rewire-status.md`, self-review `2026-10-27_23-12_browser-history-ai-rewire-session-self-review.md` (this file does NOT repeat them), storage-crisis machinery: `~/.cache/storage-crisis/{trainb-sequencer,posttrainb}.{sh,log}`.

**One-line verdict:** **The fix is intact and eval-green but NOT LIVE: the only deploy attempt tonight — the parallel storage session's armed sequencer, fired 23:32 with force — was REFUSED by the deploy battery on three failures (PSI avg10 65%/disk 103% re-measured at fire time; memory-emergency-guard 6 trips in 60 min; README doc-counts 139≠140); sequencer and orchestrator are both dead since 23:36, the slot is free, PSI is trending down (97→46) but still above the 20% entry gate — and my session watched none of it happen live.**

---

## 0. Live state at 00:21

- I/O PSI some avg10=46.55 avg60=50.81 (trajectory 23:19 → 23:31 → 23:33 → 00:21: **97.6 → 0.0 → 65.3 → 46.6** — violently oscillating, drain-driven).
- Load 238 (was 264). Storm sources at 23:19: monitor365 + monitor365-server drain still running; whisper workers down from 8 → **1** (cv-verify chunk_012).
- Live system: `system-956-link` (built 20:27) — **grep-proven to NOT carry the fix** (no `8107`/`ai-meter-keys`/`aiMeterEnabled` in the live `browser-history.service`). browser-history is still wired direct to flm `:52625` → still broken for the owner until a deploy lands.
- Tree: fix markers all present (see §a.4); only dirt = `M flake/expected-locks.nix` (parallel session lock churn).
- Deploy machinery: trainb-sequencer **dead** (single-shot, fired 23:32:25, EXIT=1 at 23:36:59); posttrainb orchestrator **halted by design** ("train B did not exit 0 — orchestrator stopping (manual triage)"). No 600G re-seed misfire. Slot is free.
- flm socket: `inactive` (guard-sacrifice state, as designed); PMA/paperless-gpt still on heuristic fallback.

## a) FULLY DONE (verified this session)

1. **Live-state re-verification** (journal/config-grep, not doc claims): generations, flm socket ActiveState (`busctl`), storm composition (`pgrep -af` + redact-argv), PSI/load trend. Established the fix is not live and why (system-956 predates 21:2x edits).
2. **Parallel-machinery discovery + full read**: found the storage-crisis session's armed pair at 23:19 (sequencer pid 2103180, orchestrator pid 3810769), read BOTH scripts end-to-end. Established race-safety: the sequencer aborts on a foreign deploy (`pgrep 'nh os|switch-to-config|float-regis[t]er'` guard) and is single-shot; the orchestrator only chains on `EXIT=0` else halts for manual triage. No scenario where my deploy and their chain collide destructively.
3. **Strategy pivot, documented before acting**: their fire gate (PSI≤80 2-min, owner policy per script header, force) is far looser than mine (avg10 <20, no force) → under a draining storm their sequencer fires first and delivers the SAME tree (which carries my fix). Decision: ride theirs, verify after; do not race. Vindicated at 23:32 when their fire happened while my gate had never opened.
4. **Fix intact in tree**: `browser-history.nix` lines 171/267/273/308-311/323-329/336-337 (aiMeterEnabled, baseUrl/model single-sourcing, wants/after ai-meter-keys, conditional LLM_API_KEY, `-`-prefixed EnvironmentFile) + `configuration.nix` 567/596/603 (ai-meter client registration). Daemon commits did not disturb it.
5. **Green-eval probe PASSED** (23:20→~23:22, 1m12s under storm): `nix eval --raw …toplevel.drvPath` → `f9qpgmglilpcirv8anddh8nrkhsdsrqg-…drv`. Tree-as-is evals. (Noted in passing: eval WARNING "catalog: integration subdomain(s) without catalog entries … catalog, cache, banksync, history, …" — a parallel session's dns-local/catalog surface, not mine, flagged in §f.)
6. **Post-mortem of the 23:32 refused fire, root-caused from the sequencer log** (the session's single most important finding): the battery refused on exactly three ✗ —
   - `I/O PSI some avg10 = 65.27% (>= 20%) WITH disk busy = 103.2%` — the entry gate RE-MEASURED at fire time; the sequencer's 2-min ≤80 window (0.0% at 23:31!) was a lull, not the end of the storm;
   - `memory-emergency-guard tripped 6× in the last 60 min` — the drain itself now trips the guard ~6×/h (new fact: the guard is no longer only sacrificing flm for llama-chat loads; the drain's IO is pushing it);
   - `nix flake check --no-build` → `doc-counts: README nixosModules asserts 139, eval truth is 140` — a parallel session added a module without re-stamping the README count. **Two-line doc fix, in my lane, not yet applied (owner's report-first order).**
   Plus one ⚠ auto-derived new-metric loan `paperless_triage_refusals_total` (paperless session's new check, expected on first deploy — benign).

## b) PARTIALLY DONE

1. **Deploy**: 0 attempts mine, 1 refused (theirs). Remaining blockers in order: (i) README doc-counts 139→140 re-stamp (fix known, 2 lines); (ii) `M flake/expected-locks.nix` churn (decide: commit via pathspec or wait for the owning session); (iii) guard-trip recency (6/60min at 23:36 — needs the drain to stop tripping it); (iv) PSI avg10 <20 + disk <20 at the battery's own re-measure.
2. **Post-deploy verification**: 0/4 legs (init line, mint file, e2e 200, anchor) — all blocked on the deploy.
3. **Close-out docs** (21-40 §e amendment, CHANGELOG, llama-chat.md consumers line): blocked on the deploy by design (they record live results).

## c) NOT STARTED (this session deliberately did not touch)

- README doc-counts re-stamp (withheld per the owner's report-now directive).
- flm socket restore (post-quiet `busctl StartUnit`) and PMA LLM-commit verification.
- Owner first-use smoke ([blocked:user], premise already updated in the queue).
- Queued rows: SigNoz TTFT alert (probe `:8108/metrics` labels first), llama-chat CPU floor ([decision], owner), paperless embeddings via ai-meter ([ready], rides next deploy).

## d) TOTALLY FUCKED UP (radical honesty)

1. **I watched nothing for ~45 minutes.** The strategy I chose and documented at ~23:20 was "ride their fire, then verify" — and I never ARMED a watcher for the fire. The sequencer fired at 23:32, was refused at 23:36, both machineries died, and my session learned all of it only at 00:21 when the owner prompted. The deploy slot sat idle 45 min with PSI trending down; with the doc-counts fix applied at 23:2x (`nix flake check --no-build` is cheap and I already had the eval result at 23:22), a retry in a 23:4x lull could plausibly have landed the fix hours ago. This is the storage session's own §d.7 "armed-is-not-running" lesson — which I had literally just read and still failed to apply to my own watching plan.
2. **Deferred work without follow-up ownership.** The green-eval probe auto-backgrounded at 23:20; I never peeked its result until 00:21 (it had passed at 23:22 — useful information sat unread for an hour). Same failure class as #1: backgrounded/deferred ≠ tracked.
3. **Green-eval ≠ deployable — I knew it and acted as if it weren't.** I validated eval-greenness and implicitly outsourced deploy-health to the sequencer's eval step. The battery's static legs (`nix flake check --no-build`, doc-counts) were cheap, knowable at 23:20, and would have saved the 23:32 fire. The three ✗ were all predictable: two were the exact storm I was watching, one was a two-line doc stamp.
4. **Minor, caught in time: I planned a racing deploy before enumerating armed actors.** My first plan (23:16) was "fire MY deploy at my stricter gate"; reading their scripts first — which I did before acting — revealed the armed sequencer and changed the plan. The instinct was wrong; the read-first discipline saved it. Lesson: `pgrep` for armed machinery + `ls ~/.cache/* sequencer/orchestrator patterns` belongs at the TOP of any deploy-planning session, not as a step I nearly skipped.

## e) WHAT WE SHOULD IMPROVE (structural)

1. **Follow-up discipline for deferred work**: every backgrounded probe / deferred check gets a todo entry with an explicit "peek by HH:MM" — otherwise it is lost. Two instances tonight (#1, #2 in §d) from one root cause.
2. **Pre-fire battery preview is the deployer's job, not the machinery's**: before betting the night's only deploy slot on any armed fire, run the cheap static legs yourself (`nix flake check --no-build`; optionally §11-only preview). Eval-green is necessary, never sufficient — the 23:32 waste proves it.
3. **Deploy-slot coordination is folklore**: armed actors live in `~/.cache/<session>/` scripts and status reports; no shared claim file exists. Minimum viable fix: a pre-fire ritual that checks `pgrep -f 'nh os|switch-to-config'` AND scans for live sequencer scripts (`pgrep -af 'sequencer|orchestrator'`) — and a note in the session's report when riding someone else's fire (I did document mine, at least).
4. **Doc-counts stamp must ride the module-add commit**: the 139→140 drift means a parallel session added a `modules/nixos/*` module without the README stamp. The eval-time check caught it (working as designed), but under tonight's 5-parallel-session pressure the stamp step was skipped — it belongs in CONTRIBUTING's module-template checklist as a hard step, not a convention.
5. **Oscillating PSI defeats windowed gates**: 0.0% (23:31) → 65.3% avg10 (23:33) within two minutes. Single-window gates (the sequencer's 2-min ≤80) will false-pass in lulls; the battery's fire-time re-measure is the correct last line (it held). Any future sequencer should gate on avg10 AND the battery re-measure, i.e. just not force.

## f) NEXT (ranked)

1. README doc-counts 139→140: re-derive with the README-embedded command, re-stamp (2 lines) — unblocks the flake-check leg.
2. `flake/expected-locks.nix` churn: identify owning session; pathspec-commit if it's finished work, else wait.
3. Re-run `nix flake check --no-build` + green-eval → zero static blockers confirmed.
4. Watch the guard-trip window (6/60min at 23:36) drain out while the storm subsides; verify the battery's threshold from `scripts/pre-deploy-check.sh`.
5. Quiescence polls (clean tree + no eval-relevant mtime <5 min, ≥4×60s), then fire `nix run .#deploy` — normal or force per owner answer (g.1).
6. Post-deploy leg 1: `journalctl -u browser-history --since <switch> | grep 'AI client initialized'` → expect `base_url http://127.0.0.1:8107/v1/llama-chat`, `api_key_set:true`.
7. Post-deploy leg 2: mint evidence — root-read `/run/ai-meter-keys/browser-history.env` + `config/browser-history` mirror (sudo harness script; the dir is 0700 root, my `ls` correctly failed).
8. Post-deploy leg 3: e2e `~/.cache/bh-ai-fix/probe-llama-chat.sh` → HTTP 200 (slow acceptable; correctness gates).
9. Post-deploy leg 4: anchor discipline — `readlink /run/current-system` == newest `system-N-link` BY NUMBER (`ls … | sort -V | tail -1`, never mtime); repair per the 2026-10-14 procedure on mismatch.
10. Restore flm socket post-quiet (`busctl call … StartUnit ss fastflowlm.socket replace`) for PMA/paperless-gpt — timing per owner answer (g.3); the guard re-sacrifices on next trip by design.
11. Verify PMA LLM commits resumed: `journalctl -u projects-management-automation | grep 'committed changes'` (10–20s durations, no heuristic fallback).
12. Owner first-use smoke: one summary + one chat turn in browser-history ([blocked:user]).
13. Close-out: amend 21-40 report §e with results; CHANGELOG entry; `docs/services/llama-chat.md` consumers line; optionally fastflowlm.md consumer note.
14. Flag for the storage session/owner: their train-B chain died at 23:36 (EXIT=1 → orchestrator halted); their overnight 600G re-seed + drill did NOT run — morning manual triage per their report §f.1. My deploy will carry their train B (same tree) whenever it lands.

## g) QUESTIONS (cannot figure out myself)

1. **Deploy-slot retry policy now that it's free:** once the doc-counts fix lands and the guard/PSI gates clear, may I fire `nix run .#deploy` unattended at the first passing entry gate — even if that lands at ~3am while you sleep (it carries: my browser-history fix, train B's 5 storage fixes, opencloud/signoz/kimi/flake.lock from tonight's parallel sessions) — or hold for a morning window you pick? (Their script header says force-under-≤80 was owner policy; their forced fire was still refused on real PSI, so I default to NON-forced + first passing gate unless you say otherwise.)
2. **monitor365 drain** (re-ask of my 23:12 Q1, still unanswered, now blocking harder): it is still running uncapped, it tripped the memory-emergency-guard 6× in one hour, and PSI oscillates 0↔97 with load 238. Run it to completion, or suspend it and restore the 3/day cap (before any agent restart re-fires it uncapped)?
3. **flm restore timing:** restore `fastflowlm.socket` the moment IO quiets (PMA/paperless-gpt have been on heuristic fallback since ~21:xx; cost = a 21.6G cold read under residual storm), or hold until AFTER the browser-history deploy + its 4 verification legs (clean attribution: a post-deploy wedge then can't be flm's cold-read IO)?

---

**Machinery state at handoff:** deploy slot FREE (sequencer dead 23:36, orchestrator halted, no nh in flight); fix eval-green (`f9qpgmglilpcirv8…drv`) but NOT live (system-956); PSI 46 and trending down; README doc-counts 2-line fix is the only static blocker I own. **Waiting for instructions.**
