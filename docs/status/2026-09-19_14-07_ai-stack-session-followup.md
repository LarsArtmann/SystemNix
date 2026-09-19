# Status — ai-stack session FOLLOW-UP + self-corrections (2026-09-19 14:07)

**Delta since the 12:31 report** (`2026-09-19_12-31_ai-stack-todo-execution-session.md`): **no execution happened** — I was instructed to wait. This follow-up exists because the status pass itself surfaced TWO self-corrections (one invalidates a shipped-code design, one invalidates a verification claim). Both are captured here so no follow-up session executes against wrong premises.

**Tree state:** clean; the auto-commit daemon landed the 12:31 report (`7af9fbf9`, `3cde5040`). Still zero code edits authored by this session.

---

## NEW FINDINGS SINCE 12:31 (both from re-probing my own session's claims)

1. **CORRECTION — `journalctl` as lars does NOT work. My 12:31 claim was wrong.**
   - 12:31 evidence: `journalctl -u fastflowlm.service -n 1 … | head -3; echo rc=$?` → printed nothing, `rc=0` — but that rc belonged to `head`, not journalctl. **The same pipeline-masking trap I documented in §d of my own report, committed by me a second time.**
   - 14:07 re-test, no pipe: `timeout 10 journalctl -u fastflowlm.service -n 2 --output cat` → **rc=124 (TIMED OUT), zero output**. lars has no usable system-journal read access for these units.
   - **Consequence for Item C (corpse gate):** the 12:31 design ("grep the fastflowlm journal for `bind: Address already in use`") would have shipped a SILENT NO-OP: post-deploy-check runs as lars → every gate run burns its timeout (20s) and sees empty output → gate never fires → a phantom check inside a smoke script. Caught only because the status pass demanded re-verification. **Revised design (better than v1): gate on the world-readable textfile instead of the journal** — `grep system_health.prom` for `system_service_state_failed{service="fastflowlm"} 1` / `system_service_start_limit_hit{service="fastflowlm"} 1` (the collector computes these as root, cadence 5-min → max 5-min staleness, zero journal dependency). The corpse state IS start-limit-hit, so the signal is equivalent. Optional journal enrichment becomes a root-only/debug branch, not the gate.

2. **Rogue PIDs still live at 14:07 — and the spin signature is INTERMITTENT, not constant.**
   - PID 995413 (:8848 bge-m3 rogue, uid 975 hermes, PPid 1): CPU time 2:02:18 over 30,369s (8.4h) elapsed → ~24% lifetime average; **last-window math: +15m38s CPU over +3h22m wall ≈ 7.7% recent** — vs 37.4% measured at 12:31 over its first 4.7h. The wedge spins in bursts, not continuously.
   - PID 995415 (:8849 reranker rogue): CPU time UNCHANGED since 12:31 (2:36) — idle but still holding the port.
   - Design consequences: (a) alert/collector text must not claim "sustained X% CPU"; (b) the soak-harness sampler (Item J) must judge on **CPU-time deltas over windows** (cumulative `utime+stime` sampled every 10s), never instantaneous `%CPU`; (c) Gatus/Grafana-style point-in-time CPU checks would under-detect this class — the port-rogue count metric remains the robust signal.

3. **PMA journal line-text pre-verification is root-gated too.** My `-26h` probe for `"committed changes"` / `"committed via heuristic fallback"` as lars returned empty — meaningless for the same reason as finding 1 (lars can't read the PMA unit journal; the collector's counts of 1337/24h run as root inside the unit). The ratio-metric design (§f.2 of the 12:31 report) still works DEPLOYED (its journalctl runs inside the root collector), but the "verify the exact success line first" step must ride a root context (one-liner handed to the user, or verify via the deployed collector after step 2 lands).

---

## a) FULLY DONE (unchanged from 12:31, plus)

1. Jan dangling-ref check — verified zero references; closable.
2. Crush source-check — no native global per-project data-dir override; symlink layer stays; closable with the research note.
3. TODO 434 investigation — stop-list never built; close as moot.
4. flm-dark aggregate check — already exists ("FastFlowLM NPU LLM", fail-closed on `state_failed`/`start_limit_hit`); history-delivery proof remains root-gated.
5. **NEW:** both self-corrections above (they are completed work: wrong claim found + root-caused + design repaired before any code shipped).

## b) PARTIALLY DONE (unchanged, with revisions)

6. flm smoke model-name assertion — already in tree (post-deploy-check.sh:287-299, another session); idle-check test still to write (§f.1).
7. PMA recalibration — count threshold verified tripping live (1337/24h, 19/1h); ratio metric designed, not implemented; line-text pre-verification now explicitly root-gated (§3 above).
8. Rogue defense — motivation proven live (2 orphans, 8.4h, >2h CPU burned, intermittent spin); full design complete with the §2 sampling corrections; not implemented.
9. Paperless-RAG-dark visibility — design complete, not implemented.
10. Corpse gate — design REVISED to the textfile gate (finding 1); not implemented.
11. Bisect harness — designed; sampler spec corrected to CPU-delta windows (finding 2); not written; execution root+owner-gated.
12. Pin-expiry probe — designed, not written.

## c) NOT STARTED (unchanged)

13. All code edits (llama-rag.nix dark-guard; system-health.nix ratio; post-deploy-check.sh corpse gate; tests/test-fastflowlm-idle.nix; scripts/llama-rag-soak.sh; .github/workflows/llama-rag-pin-expiry.yml).
14. Todo bookkeeping: `docs/todo/ai-stack.md` closures/retags, `TODO_LIST.md` queue sync, CHANGELOG pruning.
15. Verification gates (nothing to verify yet).
16. `[watch]`/`[decision]` items — untouched by design.

## d) TOTALLY FUCKED UP

17. **Claimed "journalctl works as lars (rc=0)" — false, pipe-masked.** Two pipeline-masking offenses in one session (Jan grep rc, then this). The 12:31 report itself carries the wrong claim in §a.5 — this file supersedes it. The failure class is exactly the repo's documented one; the mitigations are: direct-rc verification for any claim (no `| head` in evidence commands), and — done here — a self-re-verification pass before shipping designs.
18. **A shipped corpse gate would have been a phantom check** (timeout-stall → empty → never fires). Root cause chain: unverified access assumption → masked rc → design built on it. Caught pre-ship, zero damage.
19. Carried from 12:31: designs instead of code (the corpse gate is now a ~10-line textfile grep and still didn't land); /data EIO spotted late (`llmfan46/…/mmproj.gguf`).

## e) WHAT WE SHOULD IMPROVE

20. **Never verify a command's behavior through a pipe that eats the rc.** Evidence commands print `DIRECT_RC=$?` with no pipe, or capture both. (This is now my own thrice-bitten rule; worth a line in docs/CONTRIBUTING verification patterns.)
21. **Prefer machine-readable local signals over journal reads in user-context scripts.** The system-health textfile already publishes exactly the unit-state signals user-run checks need (start_limit_hit, state_failed) — post-deploy-check should consume `.prom` files wherever possible; journal reads belong to root collectors.
22. **CPU-signature detection must be delta-based** (finding 2) — applies to the soak harness, any new collectors, and the rogue alert copy.
23. Carried from 12:31: orphan-recurrence root question unowned (why hermes cron spawns llama-server); no mechanical soak-before-re-enable gate; PMA thresholds volume-blind; malformed `**Source:**` queue rows (systemic); stale root-owned `.prom.tmp` leftovers; queue-vs-tree drift on the smoke item.

## f) NEXT (updated order; full mechanical designs in the 12:31 report §f, with these revisions)

1. Idle-check stub-injection test (unchanged design, 12:31 §f.1).
2. PMA ratio metric (12:31 §f.2) — plus the root-gated line-text verification from §3 above (fold into the deploy-verification or hand the user a one-liner).
3. **llama-rag dark-guard (12:31 §f.3) — now the HIGHEST-urgency item: it detects the two live rogues and the paperless capability loss in one deploy.** Revisions: rogue alert text says "intermittent-spin orphan class (2h+ CPU burned across 8h)"; no point-in-time CPU claims.
4. **Corpse gate — REVISED (finding 1):** inside the flm smoke block of post-deploy-check.sh, BEFORE the curl: read `system_health.prom` (path verified live: `/var/lib/prometheus-node-exporter/textfile_collectors/system_health.prom`, world-readable); if `system_service_start_limit_hit{service="fastflowlm"} 1` or `system_service_state_failed{service="fastflowlm"} 1` → `report_fail` fast (no curl, no doomed start, no 480s stall). No journal, no timeout stall. Message keeps the reboot-only guidance.
5. Soak harness (12:31 §f.5) — sampler corrected to CPU-delta windows (finding 2).
6. Pin-expiry monthly CI probe (12:31 §f.6, unchanged).
7-11. Owner-gated (unchanged): kill rogues 995413/995415 (re-verify PIDs first; note PID-reuse risk grows with time) + hermes-cron root question; bisect execution; /data EIO triage; root gatus-sqlite history check; pressure-gated deploy of items 1-6.
12-15. Bookkeeping + verification (12:31 §f.12-15, unchanged).
16. **NEW small item:** add the "evidence commands carry DIRECT_RC, no pipe-masking" convention to docs/CONTRIBUTING verification patterns (pairs with §e.20).

## g) QUESTIONS FOR THE OWNER (unchanged — still unanswered, still not self-answerable)

1. **Rogues:** kill PIDs 995413/995415 now (sudo; re-verify PIDs first), and do you want hermes cron workers barred from spawning llama-server at the source (hermes workspace cron definitions)?
2. **Smoke item drift:** the flm model-name assertion already exists in-tree (post-deploy-check.sh:287-299) — mark that half done as-is, or did you intend a different probe?
3. **Decisions:** MiniMax quota (carried ×5) and paperless reranking direction (drop :8849 at re-enable vs. upstream feature request first) — defer or decide, so the re-enable work can bake in the outcome?

---

*Supersedes §a.5 ("journalctl works as lars") and §f.4 (journal-based corpse gate) of `2026-09-19_12-31_ai-stack-todo-execution-session.md`. All other content of that report stands.*
