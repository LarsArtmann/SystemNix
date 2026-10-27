# Browser-history AI rewire session — comprehensive status + brutal self-review

**Session:** 2026-10-27 20:47–23:12 · **Scope of this report:** THIS session's run only (per owner directive). Companion fix report: `2026-10-27_21-40_browser-history-ai-endpoint-rewire-status.md`.

---

## a) FULLY DONE (verified)

1. **Root-cause diagnosis, journal-proven**: browser-history AI "never worked" because it was wired (2026-10-15) at FastFlowLM `:52625` — the memory-emergency-guard's designated sacrifice. Trips stop `fastflowlm.socket` (the re-activation listener); the 3/day restore cap leaves the port refused for hours; trips are near-daily since Sept. Live evidence: socket `inactive`, SEV1 "FLM RESTORE CAPPED", `dial tcp 127.0.0.1:52625: connect: connection refused` on every AI click (incl. owner's 20:49).
2. **The rewire, implemented + eval-green ×2** (21:24 and 23:1x, the latter incl. parallel sessions' tree): `browser-history.nix` → ai-meter `/v1/llama-chat` (`aiMeterEnabled` option-guarded; model single-sourced from `llama-chat.alias`; `LLM_API_KEY` via minted env file; flm kept ONLY as standalone VM-test fallback), `configuration.nix` → `ai-meter.clients.browser-history` (root-owned key, DynamicUser-correct).
3. **Self-caught defect fixed pre-deploy (23:1x)**: `EnvironmentFile` without `-` prefix would fail the WHOLE unit on a missing mint file → now `-/run/ai-meter-keys/browser-history.env` (AI-only, fail-visible degradation). This was the one bug in my own wiring that could have repeated the original outage class in a new costume.
4. **In-passing: un-broke eval-broken HEAD** — the parallel session's 20:57 `gitea-runner-…-ensure` keep-alive lacked the forgejo-family subvol gate; EVERY evo-x2 eval (thus every deploy) was failing. Added `ConditionPathExists = subvolMigratedCondition` + family `RequiresMountsFor` per the audit's own prescription.
5. **Docs**: browser-history.md AI bullet (full incident + doctrine), ai-meter.md routing + clients tables.
6. **TODO surfaces, drift-free**: 3 new rows (monitoring `[ready]` TTFT alert, ai-stack `[decision]` CPU floor, services `[ready]` paperless embeddings) with queue one-liners; the 2026-10-16 first-use-smoke row premise updated on BOTH surfaces (queue + library).
7. **Layer diagnostics that de-risked the fix**: ai-meter `/health` ok, llama-chat `/health`+`/v1/models` ok, slots+journal cross-read proving the path is CORRECT though slow; the 502 identified as (probable — unverified, see §d) client-abort echo, not a proxy defect.
8. **Discipline held**: pre-read before diagnosing; status-report pre-read surfaced no known-broken row; 4×60s eval-quiescence polls before deploy; entry-gate refusal respected (no `DEPLOY_FORCE_PRESSURE`); flm socket restore deferred (21.6 GB cold read mid-storm = harmful); probes via sanctioned throwaway scripts under `~/.cache` (not /tmp); no secret ever in a command line.

## b) PARTIALLY DONE

1. **Deploy**: attempted once at a properly-quiesced moment, refused by the ENTRY pressure gate (PSI 83.6%); two 45-min drain-watch windows (21:36–22:18, 22:21–23:03) both ended STILL_STORMING (57–96% — the monitor365 uncapped drain, owner-decision pending). Everything lands with one `nix run .#deploy` when PSI <20 and the tree is quiet.
2. **Post-deploy verification checklist** (report-1 §e): 0 of 4 legs runnable pre-switch (journal init line, mint-file presence, proxied e2e 200, owner smoke).
3. **flm socket restore** (un-darkens PMA/paperless-gpt/enricher): designed manual unblock, deliberately deferred until after the storm; NOT yet done.
4. **Report #1**: written pre-deploy; §b/§d amended 23:1x (dash fix + second window); §e still pending its post-deploy results.

## c) NOT STARTED

1. Post-deploy e2e as the `browser-history` ai-meter client (only crush-client path proven, and only up to a timeout under storm).
2. Owner first-use smoke (summary + one chat turn) — `[blocked:user]`, premise updated.
3. VM test of the new standalone-fallback shape (non-ai-meter branch) — heavy build, correctly refused mid-storm.
4. TTFT SigNoz alert, CPU-floor change, paperless embeddings routing — queued rows only.
5. CHANGELOG entry for the rewire (post-deploy, per convention).
6. llama-chat.md consumers line update (browser-history now rides it).

## d) TOTALLY FUCKED UP (honest ledger)

1. **The EnvironmentFile dash omission** (§a.3) — my own wiring could have taken browser-history FULLY down on a mint failure while "fixing" its AI. Caught only at self-review, 2.5h after writing it. The pre-deploy checklist SHOULD have included a missing-file simulation.
2. **"Wedged" misdiagnosis of llama-chat** (~21:31): from a /slots snapshot BETWEEN tasks I concluded deadlocked-server; the journal (checked before any restart — the save) showed ultra-slow-but-processing. Conclusion-order error: journal FIRST, snapshot second.
3. **Probe design ignored known load**: I'd seen 8×8-thread whisper workers at first pgrep, yet fired a 120s-timeout e2e probe and treated the timeout as a routing failure → a diagnosis detour that the load number alone could have discounted.
4. **The documented rg trap bit me TWICE in one session** (`rg -rn`, then `rg -v`) — the rule is printed in AGENTS.md and a hook block costs a full round trip each time.
5. **Tool-mechanics waste**: 3× "must read before edit" refusals (bash-viewed files fed to edit), 1× printf-vs-`%{http_code}` botch, 1× multiedit partial-apply from a stale match — five avoidable round trips total.
6. **Unverified mechanism asserted as fact**: the "502 = my client-timeout echo" explanation was never checked against `pkgs/ai-meter/proxy.go` — it is plausible, not proven. Same class the repo's own evidence rules warn about.

## e) WHAT WE SHOULD IMPROVE (process + system, from this run)

1. **Interactive-consumer guard as CODE**: doctrine lives in prose (llama-chat.nix header, runbook) — an eval-time audit "no service may point an LLM base URL at `ports.fastflowlm` unless tagged latency-tolerant" would have prevented the original 2026-10-15 wiring error mechanically.
2. **/health is a lie under load** (llama-chat 200-ok at 6m38s/token) — health checks for inference tiers should include a generation probe or ride ai-meter TTFT (row queued).
3. **Missing-file semantics of systemd knobs belong in the pre-deploy checklist** (`EnvironmentFile`, `ExecStartPre` paths): simulate absence once in the VM test.
4. **Load-aware probe sizing**: check `/proc/loadavg` before ANY latency probe; a timeout under loadavg>100 is evidence about the LOAD, not the path.
5. **Parallel-session construction-site deploys**: tonight the tree changed shape 4+ times while my deploy waited — the quiescence poll worked, but a "deploy intent" flag (like plan tombstones) would let sessions coordinate instead of racing windows.
6. My own: journal-before-snapshot conclusions; `rg -n` muscle memory; write-tool-first for scripts.

## f) NEXT — up to 50, ordered (session-spawned + noticed in passing)

**Unblock the landing (1–8):**
1. Owner: monitor365 drain run-vs-suspend → gates 2–8 (question 1)
2. Deploy the consolidated switch when PSI<20 + tree quiet
3. Verify bh journal `AI client initialized, base_url …8107/v1/llama-chat`, `api_key_set:true`
4. Verify `/run/ai-meter-keys/browser-history.env` (root 0400) + mirror in `config/`
5. E2E proxied completion (any client key → 200; expect slow under load)
6. Restore `fastflowlm.socket` (busctl StartUnit) post-storm; watch guard re-arm
7. Verify PMA LLM commits resumed (no `heuristic fallback`, duration=10–20s)
8. Owner first-use smoke (summary + chat turn) — close the `[blocked:user]` row

**Hardening + observability (9–18):**
9. SigNoz TTFT alert (row queued — probe :8108 labels first)
10. CPU-floor decision for llama-chat (row queued — question 2)
11. Eval-time audit: LLM base URLs may not target flm from interactive-tier modules
12. Verify the 502-on-client-abort path in `pkgs/ai-meter/proxy.go`; document in ai-meter.md
13. Baseline llama-chat latency at normal load (TTFT alert threshold input)
14. VM-test the standalone fallback branch (`aiMeterEnabled=false`) of browser-history.nix
15. Negative-test lint leg for the EnvironmentFile `-` prefix class (missing-file tolerance)
16. Verify gitea-runner-ensure condition-skips pre-finalize (journal, post-deploy)
17. Check inboxclean chat's 3-min bound under storms (same exposure class)
18. ai-meter.md: document that non-streaming (embeddings) legs meter tokens/latency but no TTFT

**Ride-alongs noticed tonight (19–31):**
19. Paperless embeddings through ai-meter (row queued)
20. monitor365 cap restore before ANY next agent restart (`[blocked:user]` row — urgent, the drain re-fires on every restart)
21. T09 drain disarm after drain completion (watch row)
22. ghostty interactive-scope IO storm root-cause (pre-existing row; storm-adjacent again tonight)
23. whisper/cv-verify: cap concurrent workers or nice them (8×8 threads contributed loadavg 324)
24. CI runner buildcache IO tiering (sdb/sdd ~109% during builds; buildcache on HDD pool)
25. flm v1.0.7 staged go-live decision (pre-existing row)
26. hermes rogue :8849 kill-or-bless (pre-existing row, still live)
27. llama-vlm live verification + soak (pre-existing watch row)
28. Read the 2026-10-16 01:45 deploy battery log (pre-existing `[ready]`)
29. browser-history VM test at lock 87c6d4a (pre-existing `[ready]`)
30. kimi-removal + signoz project_id + opencloud port rows all verify after the same switch (their `[blocked:deploy]` rows)
31. Verify expected-locks.nix/flake.lock 22:07 churn is whole (parallel-owned, rides the switch)

**Docs + hygiene (32–40):**
32. CHANGELOG entry for the rewire (post-deploy)
33. llama-chat.md consumers line += browser-history
34. fastflowlm.md: note the guard-cap dark-window UX explicitly (consumers list context)
35. Consider a "deploy intent" coordination marker for multi-session nights
36. Amend report #1 §e results post-deploy; prune its checklist into CHANGELOG
37. Re-run `scripts/check-todo-system.sh` (new rows added tonight)
38. Sweep my `~/.cache/bh-ai-fix/` scripts into notes or delete after landing
39. Confirm no AGENTS.md edit needed (AI consumers live in runbooks — verified no)
40. Post-deploy gatus sweep: bh checks + AI tile unaffected

**Bigger questions tonight surfaced (41–50):**
41. Should the guard's restore-cap alert SEV1 auto-notify the OWNER of consumer dark-time (it did — but nobody correlated it to "AI never works" until tonight)?
42. Should paperless-gpt also get an always-on fallback upstream (llama-chat) for cap windows, or is async-latency fine?
43. Papdashboard insight enricher: same flm exposure — acceptable or re-route?
44. Whisper batching: schedule big transcriptions in storm-free windows?
45. monitor365 drain: IO-weight cgroup for drain windows?
46. Interactive tier memory: llama-chat 48G MemoryMax vs guard trips — interplay audit?
47. ai-meter: per-client upstream ACL (crush key hitting llama-chat worked — feature or hole?)
48. bge-m3 route-through (row 19) — also probe /v1/rerank consumer demand
49. A "sacrifice hierarchy" doc: which AI surfaces die first under memory pressure (now: flm > everything local CPU)
50. Revisit my §d.3: load-shedding probe protocol into docs/agents/monitoring.md?

## g) Questions I cannot answer myself

1. **monitor365 drain: run to completion or suspend + restore the cap?** ~380M backlog at ~500k events/min ≈ half a day of storm; it blocks the deploy, the flm restore, AND makes even the fixed AI path painfully slow tonight. (Your 20-47 session queued the cap row; the run-vs-suspend call is yours.)
2. **llama-chat CPU floor:** raise `CPUWeight` so the interactive tier structurally wins against batch scopes, cap the storm sources instead, or accept storm-time slowness? One line either way once you call it.
3. **Deploy timing for the consolidated switch:** the moment PSI + tree are quiet it carries MY rewire plus three parallel sessions' pending legs (signoz project_id fix, opencloud port fix, kimi removal, lock-strand repair) — fire it immediately, or hold until those sessions have verified their own legs first?

**Status: waiting for instructions.**
