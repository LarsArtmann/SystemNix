# BOOT/IO PARETO EXECUTION — BATCH 2 SESSION (11 TASKS, SELF-REVIEW INCLUDED)

**Date:** 2026-10-17 21:00 → 23:21 CEST
**Scope:** execution pass over `docs/planning/2026-10-17_20-25_BOOT-IO-INFINITE-BOOT-AFTERMATH-PARETO-PLAN.md` (M01–M20, 88 fine tasks) — every medium task that was NOT owner-gated or M02-dependent, plus live forensics on the two open anomalies (store-GC, FinishTimestamp gap). This report covers ONLY this session's work and what it noticed in passing.
**Context at start:** tree clean at `5a57339c`; 3+ parallel sessions active all evening (deploy-pipeline/boot-noise session, tq boot-mirror session, dnsblockd session); deploys 19:36→20:38 had left the live system unanchored.
**Session close state:** `nix flake check --no-build` exit 0 (twice — before and after the final edits), `check-todo-system.sh` structure clean, treefmt 0-changed on all touched files, TODO validator green after harvest. Nothing was pushed; the auto-commit daemon swept the work into heuristic batches (mixed with parallel sessions' files — deliberately NOT amended, per the never-amend-mixed-batches rule).

---

## a) FULLY DONE

### M01 — anchor triple + boot-safety (F01.1 + F01.3; F01.2 handed off by design)
- **Anchor triple recorded:** booted = `zmnzbs3f` (gen 922), live `/run/current-system` = `f703wg59` (**UNANCHORED — no profile generation points at it**), profile head = gen 926 `v4gdk8yj` (boot-linked, never activated).
- **Full activation trail reconstructed** from `_COMM=sudo` journal: 18:49 `sgjss8fz` (switch), 19:36 `zqlrxlv2`=gen925 (test+boot), 19:57 `v8f8v8rn`, 20:10 `rm56zlza`, 20:20 `p14vpxps`, 20:27+20:30 gen926 (test+boot), **20:38 `f703wg59` (test-only — the live system)**. The last four activates ran with zero new generations.
- **Incident-fix safety proven:** BOTH the live system and the boot-default gen 926 carry `After=netbird-evox2.service multi-user.target` + `TimeoutStartSec=2min` (unit-file grep in both closures) — a revert-on-reboot cannot lose the netbird/llama-chat fixes.
- `nix run .#pre-reboot-check` → **exit 0, "SAFE TO REBOOT with notes"** (16 passed, 6 warnings, 0 failed). Warnings noted: catalog-inventory-sync + service-health-check failed-with-changed-units (next deploy exit-4 class, deploy.sh reset-failed recovers); "no default entry resolved — gc-root audit skipped".
- **Repair not executed (deliberate):** the plan marks the repair leg owner-run (sudo is guard-banned for agent shells), AND the parallel session root-caused the same anomaly independently and shipped a systemic fix — `deploy.sh` now self-repairs the anchor post-switch (profile + boot entries re-armed). M01's anomaly self-heals at the next deploy. The upstream nh/nixos-rebuild-ng profile-leg vanishing stays open on its pipeline.md row.

### M03 — shape-audit class 7 (the plan's "class 5"): verified + closed
- Landed by a parallel session (heuristic commits) BEFORE my pass: predicate (boot-blocking Type=oneshot ∧ unset/"infinity" TimeoutStartSec → eval throw), `allowUnboundedOneshot` allowlist (shipped EMPTY — zero live users), `serviceOneshotDefaults` 5min mkDefault floor, `modules/nixos/services/boot-oneshot-bounds.nix` bounding the 10 foreign-rendered stragglers (cpufreq, sshd-keygen, logrotate-checkconf, linger-users, post-boot + 5 in-repo factories), negative leg `shapeaudit/oneshot-unbounded`.
- **My independent re-verification (re-dispatch protocol):** `CASES=shapeaudit bash scripts/negative-test-lints.sh` → **PASS** (mutation on a tree COPY throws the audit marker); `nix flake check --no-build` → all checks passed. Assertion-list eval on a healthy config is impossible (nixpkgs' lazy `fileSystems'.cycle` message breaks `nix eval config.assertions` — flake check is the only sanctioned gate; noted in-session).
- **Surfaces closed:** library row services.md:590 (`[x]` + DONE annotation) — the queue row TODO_LIST.md:394 had already been closed by the parallel session; the drift was the library side only.

### M04 — network-online sweep (F04.1–F04.3, F04.5 partially, F04.7)
- **17 files enumerated** (grep across modules/ platforms/ systems/), **all hits classified**:
  - **DROPPED (8 units, 6 modules — loopback-only binders, local assets):** llama-embeddings, llama-reranker (loopback-asserted; gate kept ONLY on `llama-rag-model-fetch` — the row's fetch-leg special case), llama-vlm-* backends (socket-activated, local models), fastflowlm (data.mount local model), nsfw-classifier (17 local ONNX), papdashboard (local icon pack; Discord paging is runtime outbound), systemd-graph (local dbus/journal).
  - **KEPT with per-unit reason:** model-fetch (HF downloads), hermes (outbound messaging login at start), forgejo-github-sync + forgejo-ensure-repos (outbound git), bank-sync ×3 (Wise API), pbx-backup-pull + geometrikks ×2 (outbound pulls), gatus (probes fire at start), dnsblockd-attach-ip (net-device machinery), dual-wan ×4 (defines the gate), crm-server (out of the row's suspect scope; carries its own bounded fail-open getent DNS wait — the cv-server house idiom), ai-meter + paperless-gpt (outbound LLM consumers), tq-agent-pool (comment only).
- Every drop carries an in-module justification comment. **Renders eval-verified:** `llama-embeddings.after = [ "llama-rag-model-fetch.service" ]`, `papdashboard.wants = [ ]`, `llama-rag-model-fetch.after = [ "network-online.target" ]` (gate retained).
- **F04.4** (llama-rag special case) folded into the embeddings/reranker edits. **F04.5:** evo-x2 covered via evals + flake check; darwin intentionally skipped by the check (expected); rpi3 not separately evaled (see §e).

### M08 — visionreviewd OnFailure + CHANGELOG (F08.1–F08.3)
- Fix landed by the parallel session at visionreviewd.nix:60 (unit-level `onFailure`). **My eval verification:** `config.systemd.services.visionreviewd.onFailure` renders `[ "notify-failure@%n.service" ]`; `serviceConfig.OnFailure` → attribute does not exist (the inert [Service] copy is gone).
- **Three queue rows closed** (TODO_LIST 210 — the 2026-10-06 duplicate discovery, 395 — my session's row, and the library row services.md:591) + CHANGELOG entry.
- Deploy owed (live /etc unit still carries the inert form until the next switch).

### M14 — btrbk IO tier at the definition site (F14.1–F14.3)
- Definition site located: `platforms/nixos/system/snapshots.nix` (the instances live there; the services/ glob that missed it was the original bug).
- All **five** units tiered `ioTier.background` (BE/6) via mkMerge: btrbk-root, btrbk-data, btrbk-pool, btrbk-forgejo (previously nixpkgs' bare best-effort class = BE/4-default), btrbk-pool-clean (hand-rolled `IOSchedulingClass = "best-effort"` without a priority → house helper). btrbk-forgejo-clean (forgejo.nix) already carried the helper — untouched.
- Doctrine honored: never idle (must-finish, borg precedent), always yields to interactive/desktop. **Renders verified:** IOSchedulingPriority = 6 on all five.
- No standalone TODO row existed for this ask (the plan cited "[ready] services.md" but no such row was found after three grep passes) — CHANGELOG entry written instead; no row fabricated.

### M06 — hermes-perms-heal audit (F06.1–F06.3): verdict JUSTIFIED-KEEP
- Unit already carries `ioTier.build` (BE/7 + Nice 10) with a definition-site comment deliberately rejecting idle (starvation tail) — from the 2026-10-06 restructure.
- **Live journal evidence:** CPU time is FLAT across runs (36s / 33s / 26s CPU) while wall varies 1m06s → 4m42s → **7m52s** — the walk's own cost is constant; the variance IS the yielding working. The "heal path" fires on EVERY run (perms drift continuously from agent churn — convergence is load-bearing at boot + every deploy restart), so deferring past boot-settle would extend the unconverged-perms window for zero CPU savings. ~1G metadata read per run.
- The 7m52s blame bar = the 18:16 recovery-boot storm data point (journal: Started 18:16:59 → converged 18:24:51). Row closed with the verdict + evidence; M02 owns the calm re-measure.

### M07 — compsize battery (F07.1–F07.4)
- **F07.1 answered from live state:** the deployed timer (read from `/run/current-system/.../btrfs-compsize.timer`) carries `OnBootSec=30min, OnUnitActiveSec=6h, AccuracySec=5m` — the 2026-10-12 fix IS deployed; the 23:57 run on the 23:29 boot was the **OnBootSec boot fire** (23:29 + 30min − 5min accuracy), landing inside the recovery-storm tail. nix-gc-style timer misfire ruled out.
- **F07.2+F07.3 landed:** `ExecStartPre = maintenance-entry-gate --name btrfs-compsize` (the shared refuse-and-refire contract, same as the balance/gc fleet) + `ioTier.maintenance` (idle + Nice 10, the row's fstrim pattern; the gate refuses storms, so idle only yields to admitted post-boot traffic). Render eval-verified (`IOSchedulingClass = "idle"` + the gate ExecStartPre).
- Row stability.md:246 closed with the live proof. Deploy owed.

### M13 — store-GC anomaly forensics (F13.1–F13.4)
- **F13.1: the path is BACK** — `/nix/store/a1awc19d…-netbird-client-0.80.0-wrapper-evox2/bin/netbird-evox2` exists again (the 19:36→20:38 deploy chain re-realized it); the CURRENT system's `netbird-evox2.service` references exactly that path.
- **F13.3: landmine DEFUSED** — the running daemon was restarted 19:15:55 (PID 1083316) from `k60vch2i…-netbird-client-0.80.0`, a LIVE path; `/proc/<pid>/exe` shows no "(deleted)".
- **F13.2 verdict:** the nix-gc TIMER never fired 18:00–20:00 (journal: no entries) — the ~19:07 deletion was a build's **min-free auto-GC** under the 182-proc build. **Root cause class: downstream symptom of the unanchored-deploy anomaly** (the 19:57→20:38 raw-stc activations left the running system's paths with NO profile gcroot → auto-GC was free to delete them). NOT an independent GC bug.
- **F13.4: no new guard row queued** (deliberate): the parallel session's deploy.sh anchor self-repair removes the enabling condition, and pre-reboot-check gate 10 already audits GC anchoring per boot. The upstream nh profile-leg row keeps the remainder.

### M17 — FinishTimestamp gap attribution (F17.1–F17.3)
- **Closer NAMED with to-the-second reconciliation:** `boot-metrics-emit.service`. netbird-evox2-login Finished 19:19:18 → boot-metrics-emit `Starting` at 19:19:18 (queued directly behind it) → `Finished` 19:43:18 (`Consumed 165ms CPU over 24min 317ms wall`) → PID-1's ONLY `Startup finished` line of the boot at 19:43:18 (`1h 29min 25.454s userspace = 1h 29min 40.387s`). **btime(1792253627) + 5371s = 19:43:18 CEST** — the monotonic reading resolves exactly.
- **Mechanism (corrected in-session — see §d):** the 24-min body is the emitter's OWN 12×120s unfinished-boot retry budget; every mid-loop `systemd-analyze` call necessarily refuses while the unit itself holds the transaction open — a self-referential wait that can only end by budget exhaustion (= 19:43:18). The 19:49:18 OnUnitActiveSec re-fire then converged the sample in 157ms. NO second login re-ignition.
- Fold note for M02: this boot's blame will show boot-metrics-emit ≈24min — a known storm artifact.

### M15 — transaction_open gauge (F15.1–F15.2; F15.3 observe-only by design)
- `boot-metrics.nix` now emits `transaction_open` + `transaction_open_seconds_past_graphical`: **written MID-RETRY** (every 120s refusal cycle atomically rewrites boot-metrics.prom with the open age = uptime − graphical.target ActiveEnterTimestampMonotonic, uptime fallback pre-graphical) so an infinite-boot box surfaces a number within the first cycle — the 2026-10-17 class was invisible to blame + systemd-analyze for 55+ min. Final sample carries 0/0 when closed; the give-up path keeps the last open age + scrape_errors=1 instead of a bare phase-less error.
- **Closed-path live dry-run verified** (script extracted via eval, redirected to /tmp, executed on the real boot): transaction_open 0, phases parsed, 28-line prom.
- **BONUS LIVE CATCH — pre-existing parser bug fixed:** `to_seconds`/`emit_phase` dropped a leading `1h ` (leftmost-longest substring match started at "29min") — the 18:13 boot emitted userspace **1765.454 for the true 1h 29min 25.454s**. Hours case + hours-bearing regexes added; **re-verified against ground truth to the decimal: userspace 5365.454 / total 5380.387** (matches the PID-1 Startup-finished line exactly).
- Row stability.md:244 closed (gauge ask + the 18:13 holder); CHANGELOG entry written. See §d for the honest annotation on the 3efe02cf half-ask.

### Session hygiene
- 4 CHANGELOG entries (aftermath tranche, network-online sweep, maintenance tiering + compsize gate, transaction_open gauge).
- 9 TODO surfaces closed across TODO_LIST.md / services.md / stability.md (3 of them parallel-session drift: queue 394's library side, queue 210+395 duplicates, deploy row already closed).
- check-todo-system.sh green at every checkpoint; scoped treefmt only (0 unintended files touched).

---

## b) PARTIALLY DONE

1. **M04/F04.5 (three-host eval):** evo-x2 evals + full flake check passed (which covers all evaluable systems; darwin skip is the documented default). rpi3 was NOT separately evaled — the 8 de-gated modules are evo-x2-only services so exposure is nil, but the plan's literal three-host leg wasn't executed.
2. **M15/F15.4 (selftest):** the gauge has NO automated pin. Closed path verified live once; **open path (mid-retry emission) has never executed anywhere** — queued as a [ready] row this session (see §f harvest).
3. **M07 sandbox interplay:** the maintenance-entry-gate under compsize's `harden{}` was REASONED (ProtectSystem blocks writes, not reads; the gate's own header claims harden-compatibility) but never executed — a wrong sandbox would fail OPEN to an inert gate. Queued as a post-deploy battery item.
4. **M03/F03.4 allowlist survey:** performed by the parallel session (boot-oneshot-bounds list = the survey product); I verified the outcome (eval green, empty allowlist) rather than redoing the survey — per the re-dispatch protocol that is legitimate, but the survey itself is not my first-hand work.

## c) NOT STARTED (all correctly gated per the plan's execution graph)

- **M02** quiet-window reboot battery — owner window (§g Q3 below); unlocks half the remaining plan.
- **M05** family audit — depends on M02's calm blame baseline.
- **M09–M12** model-load train (pre-warm → PSI gates → serialization → GGUF hot-tier) — M09/M11 need the M02 baseline; M12 has an owner space gate.
- **M16** flm/vlm waiting-gate — depends on M10.3's waiting-gate primitive.
- **M18** ioTier coverage eval gate — the boot-gated-units half was executable tonight; skipped for context budget (see §e). Owner Q2 gates the user.slice half.
- **M19** user.slice scoping — owner Q2.
- **M20** crush-DB off-QLC support pass (F20.1–F20.3) — small, executable, NOT started; the one genuinely free task I left on the table.

## d) TOTALLY FUCKED UP (caught + fixed in-session; nothing destructive)

1. **M17 first close-out asserted the WRONG mechanism.** I wrote "journal read starved by the concurrent deploy+build storm" — the truth (12 × 120s retry budget = 24min to the second) was available by arithmetic at first writing and only landed in my head 40 min later during M15 work. Corrected per the name-the-surface rule (row text rewritten, correction explicitly marked). LESSON: do the arithmetic before writing the verdict; "plausible" is not "verified".
2. **M15 row 244 overclose (caught during THIS self-review):** my close claimed the holder-identification half closed — true for the 18:13 boot (netbird-evox2-login), but the ORIGINAL 3efe02cf (23:29) instance's specific holder was never named (its candidates tq-agent-pool/snapshots/gatus were never adjudicated). Amended the row: the 3efe02cf holder stays UNNAMED (forensically stale); the class is instead structurally gated + measured, which is the durable fix — but the row's literal first ask went unanswered and the first close-out didn't say so.
3. **Two edit-tool failures from sloppy old_strings** ("compsite" vs "compsize"; "PID 1877" vs "1879") — cost two round trips, no damage. LESSON: copy, don't retype.
4. **jq misuse twice:** a `sed` filter inside jq (nonexistent function), then a silently-empty closure-refs filter for M13 that I abandoned with "not critical" instead of fixing (the unit-file grep substitute was adequate, but silent-empty is how phantom greens are born).

## e) WHAT WE SHOULD IMPROVE (process, from this session's own failures)

1. **Arithmetic before verdicts** — the 24min ≈ 12×120s check would have prevented the M17 wrong-mechanism close. Any duration claim gets compared against known budgets BEFORE it's written into a row.
2. **Scope close-outs to what was actually answered** — the 3efe02cf overclose is the second session in a row with a close-out-versus-ask mismatch (the 2026-09-18 browser-history gate class). Rule: reread the row's LITERAL asks and map each to evidence before flipping `[x]`.
3. **Untestable legs must say so AND queue their test** — the M15 open path. "Verified the closed path" in a close-out without a queued open-path test leaves the gauge's entire purpose unproven.
4. **Sandbox-interplay verification when wiring gates under harden{}** — reason + header-claim is not execution; the compsize gate could be silently inert. The post-deploy battery row now pins the journal line that proves it.
5. **Fix or finish abandoned probes** — the silent-empty jq (§d.4) should have been either fixed or explicitly recorded as dropped with the substitute named (I only did the latter implicitly).
6. **Context-budget triage should favor small executable items** — M20 (30 min, 3 fine tasks) lost to nothing; if I'd triaged by "smallest executable first" after M15 it would have fit.

## f) NEXT (session-harvested; first 3 are NEW rows landed this session in TODO_LIST.md + domain libraries)

1. **[blocked:deploy] Post-deploy battery for tonight's batch** — compsize gate journal line (PSI parse under harden), visionreviewd [Unit] OnFailure, 8 swept units' live after/wants, transaction_open 0 in prom, btrbk priority 6 live (services.md row).
2. **[ready] transaction_open OPEN-path test** — VM/fixture: stub systemd-analyze refusal, assert open gauge emission + growth + convergence (stability.md row).
3. **[watch] First night at btrbk BE/6 + compsize idle** — sends complete within windows; 6h compsize green (stability.md row).
4. **M02 reboot battery** (owner window) — systemd-analyze verdict, llama-chat/netbird post-boot ordering, gatus Boot-Userspace GREEN, calm-boot re-measure; closes the 10:44 report's §g.2 and the stability.md:209 re-measure row.
5. **M05 family audit** — multi-user wantedBy × calm blame join, >30s flags, fix-or-justify (stability.md:245).
6. **M09 llama-chat pre-warm** — streaming read ExecStartPre, blame delta vs M02 baseline.
7. **M10 PSI entry gates** — refactor tqPoolPsiGate into a reusable lib gate (refuse-style for boot units, waiting-style for socket-activated) + unit tests.
8. **M11 serialize concurrent cold loads** — heavy-job slot or After= chain across llama-chat → flm → vlm → rag.
9. **M12 GGUF hot-tier move** — Samsung space audit → +C subvol → PSI-gated migrate → repoint (owner space gate §g Q3).
10. **M16 flm/vlm waiting-gate** — on top of M10.3.
11. **M18 ioTier coverage eval gate** — predicate + census + allowlist + negative test (owner Q2 gates only the user.slice documentation half).
12. **M20 crush-DB off-QLC support pass** — verify crush-hot-db-migrate convergence, write the owner handoff checklist (storage.md row).
13. **user@1000 corrupted PSI bucket** — root-cause test #1 at the next reboot (CHANGELOG wave-2 STILL OPEN; the parallel session queued the tq-agent-pool gate hardening).
14. **nh/nixos-rebuild-ng profile-leg vanishing** — the upstream root cause of the unanchored-deploy class (pipeline.md row; deploy.sh self-repair is the mitigation).
15. **Failed-units sweep** — the 9 standing failures from the 2026-10-17 deploy log (services.md:595).
16. **Gatus/SigNoz rule on transaction_open** — owner call after observe-only period.
17. **papdashboard journal flood** (~664 lines/min, §18 class — parallel session's row).
18. **discordsync hotloop triage** (2812 lines/min, exit 69 — standing row).
19. First-night check: hermes-perms-heal calm-boot reading lands ≤~15s in M02's blame (the justified-keep verdict's confirmation leg).
20. Commit granularity debt: tonight's work rides heuristic daemon batches (mixed with parallel sessions' files — un-amendable by policy); if any close-out ever needs git archaeology, the CHANGELOG entries + this report are the provenance.

## g) QUESTIONS FOR THE OWNER (cannot be figured out from the box)

1. **Deploy timing:** tonight's batch (sweep + tiers + gate + gauge + visionreviewd fix) is deploy-pending and the anchor self-repair rides the next deploy — but the box has a corrupted user@1000 PSI bucket whose root-cause test is "the next reboot", and parallel sessions may still be mid-flight. Deploy now, or hold for a quiet window?
2. **transaction_open alerting:** observe-only (current state) until a natural reboot validates the emission, or wire the Gatus rule immediately so the first infinite-boot recurrence pages?
3. **M12 eviction policy (if Samsung free space is tight):** what yields — /nix shrink first, cold models stay on QLC, or defer the GGUF move until the crush-DB migration (M20) completes? (I can measure free space myself; the POLICY under tightness is yours.)

---

**Self-assessment:** 11 of 20 medium tasks executed (all non-owner-gated, non-M02-dependent except M18-partial and M20 — see §c/§e.6); every change eval- or live-verified; two honesty defects caught and corrected (one only at this self-review); zero destructive actions; TODO/CHANGELOG surfaces consistent at every checkpoint.

*Arte in Aeternum*
