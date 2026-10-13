# Status Report — bank-sync crash-loop root-cause + rollback, deploy unblock

**Authoring time:** 2026-10-13 15:13 CEST (`date` live)
**Session scope:** the two failures from the user's pasted deploy log — (1) `pre-deploy-check` build abort (shellcheck SC2001), (2) `bank-sync.service` exit-65 crash-loop. Plus everything noticed while executing. No other domains researched (owner instruction).
**Baseline pin at session start:** `978373c1`, clean tree, 3 heuristic daemon commits on top of `af526d2d` (docs).
**Format note:** user explicitly demanded `.md` at `docs/status/` — the status-report skill's HTML-canonical default is overridden by explicit instruction (flagged per skill contract; not propagated as a new default).

---

## TL;DR

| | |
| --- | --- |
| Deploy blocker (SC2001) | **FIXED** — pre-deploy went 94 passed / 0 failed |
| bank-sync crash-loop | **ROOT-CAUSED + FIXED by rollback** — not data loss; a library key-semantics break |
| Outage window | 2026-10-12 21:53:03 → 2026-10-13 14:53:31 (~17h, HTTP 502 on banksync.home.lan) |
| Data loss | **ZERO** (journal 171,945 rows intact; snapshots aligned; DB only ever opened read-only) |
| Deploy | **LANDED** 14:53 switch; post-deploy smoke 143 PASS / 4 FAIL (all ambient) / 15 WARN |
| Remaining bank-sync degradation | Wise syncs fail `bank.empty_sca_token` — the standing owner-gated SCA renewal (pre-existing, NOT this session's regression) |

---

## a) FULLY DONE

1. **SC2001 deploy blocker fixed and verified in the real derivation.** `scripts/pre-deploy-check.sh:903` (source) / line 910 (built script): `echo "$PVG_OUT" | sed 's/^/    /'` → `printf '%s\n' "$PVG_OUT" | sed 's/^/    /'` — a restructure, not a suppression (parameter expansion cannot anchor per-line; the lint is a true FP for multi-line indent, verified empirically against shellcheck 0.11.0 across four sed variants). The §15 pre-vacuum block (`echo | grep | sed`, line 900) never fired and was left alone. Proof: the actual `writeShellApplication` build ran clean inside the deploy's pre-deploy phase (**94 passed, 0 failed, 12 warnings**).
2. **bank-sync crash-loop root-caused with evidence, not inference.** Chain: preflight error `[Corruption:cqrs.journal_snapshot_divergence]` (45 streams, snapshot v3750 vs 0 journal events, exit 65) → read-only prod-DB probes (`meta_stream_log`: 171,945 rows all collection `events`; `snapshots`: exactly 45 rows, ALL readable keys, e.g. `('BalanceSync','profile:wise:14757634',3850)` vs journal count 3,856 → aligned; `events`=0 rows, `events_legacy_v4`=148,158 → the Oct-5 migration completed) → source diff of the two go-cqrs-lite pins (`7142e43` vs `d15e0a48`): `sqliteengine/stream_log.go` diff purely additive, but `id.ParseStreamID`/`StreamID.String()` changed from verbatim composite passthrough to brand-prefix + namespaced-hash round-trip. The preflight's `StreamVersion` counts `WHERE collection=? AND stream_id=?` — the new pin's derived key `BalanceSync:StreamMarker:<ulid-hash>` matches **zero** rows of either on-disk spelling (readable `BalanceSync:profile:wise:N` AND the older ULID variant `BalanceSync:<ulid>`, 3,787 rows, coexist; 8,260 distinct stream_ids). **The journal was never truncated — the binary lost the ability to ADDRESS it.**
3. **The daemon's own remedy proven a NO-OP for this class** (this kills the previous session's open owner question "migrate-in-place vs restore" — the premise was wrong): `bank-sync migrate-journal` is a legacy-`events`→journal copy, already executed 2026-10-05 (`events` empty, rename done); a re-run reports "already migrated". Neither migrate nor restore was ever needed.
4. **flake.lock rolled back, lock-coherent, eval-green.** bank-sync node `eb7818c6` (revCount 1780) → `67dd64526e5a55d86ff40ab49ce4a07794922962` (revCount 1700) and its transitive `go-cqrs-lite` node `d15e0a48` → `7142e43`, both spliced VERBATIM from the Oct-10 lock (`b6cdade2`) after node-by-node diffing bank-sync's 25-node transitive closure (only 3 nodes had moved; `nixpkgs_4`/`treefmt-nix_10` left at current pins — follows-safe). `nix flake check --no-build`: **all checks passed**.
5. **Rollback rev vetted on three gates before splicing:** (a) buildable — bank-sync's go.mod bump `719d476c` (the 2026-10-10 build-breaker) is NOT an ancestor of `67dd64526`; (b) clean ancestor of the current lock lineage; (c) both Gatus sentinel gauges (`bank_sync_sca_approval_pending`, `bank_sync_sync_sustained_failure`) exist AND are unit-tested at that rev (`metrics_test.go` asserts exact metric lines) — the "deploy order is load-bearing" constraint stays satisfied.
6. **Deploy executed through the full pipeline.** PSI pressure gate blocked once → verified live it was the documented corpse class (PID 731 `usb-storage` wedged in D, disks idle busy=2.0%, PSI 25–33% some) → forced per the established `DEPLOY_FORCE_PRESSURE=1` pattern → switch landed. `Resetting failed units` + all post-switch steps ran.
7. **Post-deploy verification of exactly what was claimed:** running binary confirmed `/nix/store/f56p45m4…-bank-sync-67dd64526…/bin/bank-sync run` (rev-drift clean by construction); `/health/ready` → HTTP 200 `{"status":"up"}`; `bank_sync_sync_total 1` (first sync cycle completed); `bank_sync_sca_approval_pending 0`; **0 DATAERR/Corruption lines since 14:53**; no failed units after 14:53:31; the ExecStartPre DB snapshot ran on the way up per module design.
8. **Findings recorded in the owned surfaces + self-harvest done at authoring time:** `docs/services/bank-sync.md` (new #1 gotcha: the key-semantics break, the no-op remedy, the rollback, the re-bump ceiling), `docs/todo/upstream.md` (`[blocked:push]` upstream compatibility row — landed before this report), plus two `services.md` rows and one `pipeline.md` row + matching `TODO_LIST.md` queue one-liners appended with this report (see Harvest Ledger).
9. **Daemon commits verified, not assumed** (`git show --stat`): my doc edits rode `1d1465c8`; script + lock swept earlier — contents checked each time.

## b) PARTIALLY DONE

1. **bank-sync is UP but not fully FUNCTIONAL**: the daemon serves (502 gone, dashboard reachable) while ALL Wise balance syncs fail `[rejection] bank.empty_sca_token` — the documented SCA renewal gated on the owner's OTP (runbook `docs/services/bank-sync-sca.md`, re-armed 2026-09-30). `bank_sync_sync_consecutive_failures{wise}` reads **124** and `bank_sync_sync_sustained_failure 1`, so the "Bank-Sync Sync Sustained" Gatus check is red by design until approval. Anomaly worth flagging: 124 × 15-min base interval ≈ 31h > the daemon's uptime — the runbook claims streaks "re-seed after daemon restarts", which this number contradicts (unresolved observation, queued).
2. **The deploy is landed but the pipeline exited 3**: post-deploy smoke 143 PASS / 4 FAIL / 5 SKIP / 15 WARN / 2 STORM-SUSPECT. All four FAILs assessed ambient, none deploy-caused: §18 CPU `discordsync=202%` + `nix-daemon=993%` (the build itself), §18 journal `discordsync=2161/min` + `node-exporter=364/min`; "NEW failure vs baseline" = the CPU check. discordsync's elevated journal rate demonstrably pre-dates the deploy (630 lines in the 13:30–14:45 window). The 2 STORM-SUSPECT checks are formally UNVERIFIED until a calm-box re-run.
3. **The upstream fix is recorded but NOT implemented**: bank-sync/go-cqrs-lite still lack stream-key compatibility; `67dd64526` is now a hard ceiling. Until landed, every `nix flake update` can silently re-land `eb7818c6` (no automated guard exists yet — queued as a [ready] tripwire row this session).

## c) NOT STARTED (noticed, deliberately untouched — report-only per owner instruction)

1. Gatus-side verdict check for the two bank-sync checks (I verified the daemon gauges, not gatus's own evaluation state).
2. Dashboard balances/transactions panel parity (runbook post-migration verification step 3) — the panels were never visually confirmed against pre-outage rows.
3. `/metrics` `cqrs_*` projection series presence (runbook step 2 — I only spot-checked `bank_sync_*`).
4. Pre-migrate backup rotation (runbook step 2b: keep 5 newest) and confirming the 14:53 ExecStartPre snapshot file actually exists on disk.
5. Attribution forensics: WHO/WHAT moved the bank-sync input to `eb7818c6` on Oct 12 (~21:4x, locks `faa795ad`/`9e7b43f5`) — crush.db protocol exists, not run (see Question 1).
6. The wedged `usb-storage` corpse (PID 731) — identified, not resolved; PSI still elevated when I left it.
7. Calm-box re-run of post-deploy-check to clear the 2 STORM-SUSPECT + §18 ambient FAILs.
8. Doc cross-links/annotations: `docs/agents/go-ecosystem.md` pointer to the new gotcha; ANNOTATE-mode note on the 13:01 status report (its migrate-vs-restore question is mooted); CHANGELOG guard-win entry for the preflight catch; closing the 13:01 report's crash-loop queue row substantively (re-dispatch verification protocol deliberately not executed this session).
9. Cross-project lesson ("library re-pin can silently change storage key formats — rehearse new binaries against prod-DB COPIES") → `references/lessons.md` in crush-config BY COMMIT, never in-session.

## d) TOTALLY FUCKED UP

1. **The Oct-12 bump itself (the event this session cleaned up):** someone/something shipped bank-sync `eb7818c6` — whose library re-pin silently changed event-store KEY FORMATS — straight to prod financial infrastructure with no DB-copy rehearsal. The binary could not address a single existing stream. Only the journal↔snapshot preflight (born from the 2026-10-03 two-day silent-brick incident) stood between that bump and a second silent disaster. Cost: ~17h of 502 on a live financial service. The preflight refusing loudly at startup is a guard WIN; the process around it (bump without rehearsal) is the failure.
2. **The preflight's remedy text lies for this class**: it says "run `bank-sync migrate-journal`" — a command that is a provable no-op here. An operator following the daemon's own instructions would have done nothing, twice. Recorded for upstream fix.
3. **No automated re-bump guard exists**: the rollback holds only until the next `nix flake update`. The single most likely re-fuck is one command away. (Queued [ready] this session.)
4. **My own missteps, uncensored:**
   - First lock splice attempt wrote a **github-shape `locked` block onto a git/ssh-type input** — would have produced a corrupt lock. Caught on the immediate read-back (the node's true shape was `type:"git", url:"ssh://…"`) and redone verbatim from the Oct-10 lock. The lesson is in item f.30 (codify the re-pin helper).
   - My runbook bullet initially overclaimed "**every** journal + snapshot row uses the OLD spelling" — a later probe showed a second historical spelling (ULID variant, 3,787 rows). The conclusion (new key matches zero rows) held, but the premise was sloppy. Corrected in-session.
   - I ran the deploy on a tree containing **another session's brand-new §15 pre-vacuum block unreviewed** — that block carried the SC2001 break. Multi-agent discipline says flag unfamiliar tree growth LOUDLY and immediately; I noted it in passing and proceeded to debug my own surfaces first. No damage (the block's logic was fine; its lint wasn't), but the flag should have led.
   - I verified "sentinel gauges present at the rollback rev" from a grep that matched ONLY docs files — would have been a wrong premise shipped as verified. Caught it myself (docs-only hits), re-proved in Go test source before claiming. Counted as a save, disclosed because the first claim was one breath from being asserted.
5. **Ambient but real, pre-existing (not this session's fuckup, listed because the smoke flags them):** inboxclean-web at **1,204,488** MemoryHigh reclaim events, forgejo **493,738**, papdashboard 106,144 — a fleet-wide watermark-retune debt; discordsync's named hotloop class still looping; the pressure gate's corpse class recurring (forced through twice in two days).

## e) WHAT WE SHOULD IMPROVE

**What I forgot:** to check Gatus verdicts (not just gauges), dashboard panel parity, and backup-file existence before closing — I asserted exactly what I probed and no more, but the runbook's own post-migration checklist has three unexecuted steps. Also forgot to identify the Oct-12 bump's actor before writing the gotcha (attribution would tell us whether the bump was manual or agent-driven, which changes the PREVENTION — see Question 1).

**What could have been done better:** the entire outage was preventable at two points — (1) a DB-copy rehearsal of the new binary BEFORE the Oct-12 switch (the runbook's T5 rehearsal pattern exists for exactly this class and was not invoked for an input bump), and (2) an eval-time/pre-deploy tripwire on the bank-sync rev. Both are now queued. Second: I should have flagged the foreign §15 block before building on top of its broken shellcheck, not after.

**What we should still improve:**
- **Rehearse bumps, not just migrations.** "Input bump = mini recovery window" for any journal-bearing service: stop-less dry-run of the new binary against a DB COPY is minutes of work and kills this entire class. Encode in the deploy protocol, not in tribal memory.
- **Guards over narratives.** Every fix this session is prose (gotcha bullet, todo row). The two durable forms are the rev tripwire (queued) and the upstream round-trip regression test (queued).
- **Smoke baseline hygiene.** The exit-3 "regression signal" fired on nix-daemon build load — self-inflicted, predictable noise. Baselines must classify during-build load or the signal desensitizes exactly the operator it exists for.
- **Watermark debt.** 13 services above the §17 sub-threshold, worst at 1.2M reclaim events. The §17 sweep keeps WARNing; nobody retunes. One pareto pass (forgejo, inboxclean-web, papdashboard first) buys down real freeze risk.
- **Answering the skill's questions directly:** Did I lie? No — two near-miss premises were caught and re-proved before assertion (disclosed in d.4). Ghost systems created? None. Split brains? One introduced knowingly and recorded: two go-cqrs-lite versions now coexist in one system (SystemNix's cqrs-lint CLI at `d15e0a48`, bank-sync's journal library at `7142e43`) — safe only because the CLI is journal-unbound; the skew rule should be written down (f.27). Tests? I added none; every verification this session was a live probe — the class-level tests belong upstream and are queued.

## f) 50 things to get done next

*Format: `#n` · tag · harvest status. Direct follow-ups were harvested to the TODO system at authoring time per AGENTS.md; everything else carries an explicit reason.*

**bank-sync / the outage**
1. `[blocked:push]` Upstream stream-key compatibility (verbatim composite passthrough or re-spelling migration + dual-spelling preflight) — **HARVESTED** (docs/todo/upstream.md, landed pre-report).
2. `[ready]` Guard the bank-sync lock input at `67dd64526`: eval/pre-deploy tripwire FAILS if the rev moves past it without an owner-set override — **HARVESTED** (pipeline.md + TODO_LIST.md queue).
3. `[ready]` Verify whether `bank_sync_sync_consecutive_failures` survives daemon restarts (124 streak > uptime/15m contradicts the §sentinels doc claim); fix the gauge or the doc — **HARVESTED** (services.md + queue).
4. `[ready]` Amend the deploy protocol: any bank-sync input bump requires a dry-run of the new binary against a COPY of the prod DB first ("input bump = mini recovery window") — **HARVESTED** (services.md + queue).
5. *(folded into row 1)* Upstream: fix the preflight remedy text (`migrate-journal` is a no-op for the key-basis-mismatch class) — recorded inside the harvested upstream row, not a separate row.
6. `[blocked:user]` Wise SCA dashboard OTP approval (clears `empty_sca_token` on all balances; standing runbook owns it) — *deliberately not harvested: already owned by `docs/services/bank-sync-sca.md` standing state.*
7. `[watch]` Post-approval: restart daemon, confirm error counters clear (restart-cumulative semantics) — *not harvested: chained to row 6, owned by the SCA runbook's follow-up chain.*
8. `[ready]` Check Gatus verdicts for both bank-sync checks (I verified gauges only) — *not harvested: 2-minute probe, fold into the calm-box pass (row 12).*
9. `[ready]` Visual dashboard parity check (balances/transactions panels vs pre-outage rows) — *not harvested: owner-eyes check, belongs in row 12's pass.*
10. `[ready]` Rotate pre-migrate backups (keep 5 newest) + confirm the 14:53 ExecStartPre snapshot file exists — *not harvested: runbook step 2b already prescribes it verbatim; duplicate row would drift.*
11. `[decision]` Consider pinning the bank-sync input URL with an explicit `?rev=` during the blocked window (tradeoff: fights `nix flake update` UX) — *not harvested: duplicate of row 2's mechanism, owner may prefer row 2 alone.*
12. `[ready]` Calm-box re-run of post-deploy-check (clears 2 STORM-SUSPECT + §18 ambient FAILs, refreshes baseline) — *not harvested: single execution, rides the next natural deploy.*
13. `[ready]` Confirm the parallel session's `inboxclean-canary-metrics` unit (new in this deploy's diff) is healthy — *not harvested: owned by that session's own follow-ups (14:02 report).*
14. `[ready]` Verify §12's stale "ExecStart not built yet" warnings are formally cleared post-build — *not harvested: informational warning class, self-evident from the running service.*

**Stability / pressure (all observed in this session's §17/§18/PSI output)**
15. `[ready]` Resolve the wedged `usb-storage` corpse (PID 731, D-state, crash3 signature) — identify the device via dmesg/usb history, detach or reset — *not harvested: needs dmesg/sudo forensics; stability.md row check must precede (unverified this session).*
16. `[ready]` §17 fleet watermark retune, pareto order: forgejo (493,738 hits), inboxclean-web (1,204,488), papdashboard (106,144), mr-sync-dashboard (43,034), clickhouse (33,824), discordsync (22,823), project-discovery-daemon (13,221), geometrikks (11,074), bank-sync (5,011), nix-daemon (3,880), cv-server (2,326) — *not harvested: the memory-watermark-audit + §17 sweep already own the class; retune is a session of its own (ROADMAP-scale).*
17. `[ready]` Root-cause forgejo's 493k MemoryHigh hits (worst single offender) — *not harvested: subsumed by row 16's pass.*
18. `[ready]` Root-cause inboxclean-web's 1.2M hits (most sustained) — *not harvested: subsumed by row 16.*
19. `[ready]` discordsync hotloop: 202% CPU + 2,161 journal lines/min (the §18 check's namesake class) — *not harvested: named class already; existing monitoring/services rows likely own it (unverified — did not research per instruction).*
20. `[ready]` prometheus-node-exporter journal rate 364/min — identify the chatty collector/series — *not harvested: small probe, fold into row 12's calm pass.*
21. `[watch]` Pre-vacuum clock: journal 7.1G vs 8G SystemMaxUse — pull any exposed-boot evidence before the vacuum eats it — *not harvested: the §15 gate itself enforces this at every deploy (that is its job).*
22. `[decision]` Two `DEPLOY_FORCE_PRESSURE=1` in two days: review the gate threshold vs corpse frequency (gate proven right today, but forced overrides are becoming the habit) — *not harvested: owner policy question.*
23. `[ready]` Automate corpse classification in the pressure gate (list D-state + wchan, match known classes — the gate's "verify the corpse pile" step is currently manual) — *not harvested: enhancement, ROADMAP fuel.*

**Deploy pipeline**
24. `[decision]` writeShellApplication fails builds on STYLE-severity findings (SC2001 blocked a deploy for an indent idiom): ratify a `--severity=warning` floor or keep strict — *not harvested: owner policy; today's fix works under either.*
25. `[ready]` Extract the indent-lines helper (`printf '%s\n' "$X" | sed 's/^/    /'`) into scripts/lib — now two call sites in pre-deploy-check — *not harvested: cosmetic, rides the next touch of that file.*
26. `[ready]` Enforcement for the documented daemon-race lint-skip class (daemon-swept script commits bypass staged-path pre-commit legs — the §15 block shipped with a shellcheck break exactly this way): standalone shellcheck leg for daemon-authored script commits — *not harvested: adjacent row already queued by the 14:02 report (drv-build verification leg); the daemon-commit leg is the delta, fold there next pass.*
27. `[ready]` Attribution forensics on the Oct-12 bump (crush.db + /proc/stat protocol) — *not harvested: see Question 1 — owner may answer it instantly.*

**Lock / dependency hygiene**
28. `[ready]` Write down the allowed go-cqrs-lite version-skew rule (cqrs-lint CLI may float at `d15e0a48`; journal-bound consumers pin `7142e43` until compat lands) — docs/agents/go-ecosystem.md — *not harvested: one-paragraph doc edit, fold with row 32.*
29. `[blocked:push]` Upstream go-cqrs-lite: ParseStreamID round-trip regression test (composite keys must survive verbatim) — the class guard that would have caught `d15e0a48` in CI — *not harvested: belongs inside the harvested upstream row's fix scope; separate row would drift.*
30. `[ready]` scripts helper: "re-pin lock input X to rev Y from an old lock" (the verbatim node splice I hand-rolled in python — kills the wrong-shape-splice class from d.4) — *not harvested: nice-to-have tooling, ROADMAP fuel.*
31. `[watch]` Re-measure the lock node count after today's churn (regrowth row in upstream.md tracks 387→454) — *not harvested: the existing priority row owns the metric.*

**Docs**
32. `[ready]` Cross-link the new bank-sync gotcha from `docs/agents/go-ecosystem.md` (Go inputs routing table) — *not harvested: fold with row 28.*
33. `[ready]` ANNOTATE the 13:01 status report (its migrate-vs-restore owner question is mooted — the data never needed either) — *not harvested: docs-health ANNOTATE pass, batched with 34/36.*
34. `[ready]` Annotate `bank-sync.md` §sentinels claim ("streaks re-seed after restarts") pending row 3's verdict — *not harvested: dependent on row 3.*
35. `[ready]` CHANGELOG entry: the preflight's correct refusal (guard-win, 2026-10-03-class catch #2) — *not harvested: docs-health prune pass owns CHANGELOG.*
36. `[ready]` Substantively close the 13:01 report's crash-loop follow-up rows (re-dispatch verification protocol; NOT ticked this session — I did not read/verify those rows) — *not harvested: same ANNOTATE batch as 33.*

**Verification debts (mine, small)**
37. `[ready]` Confirm `/metrics` carries the `cqrs_*` bridge series (runbook step 2 half-done) — *not harvested: fold into row 12.*
38. `[ready]` Full-tree audit for OTHER journal-bound go-cqrs-lite consumers in SystemNix (I verified only the root input = cqrs-lint CLI) — *not harvested: audit task, ROADMAP fuel.*

**Larger arcs (ROADMAP fuel, listed for completeness)**
39. Generalize the rehearsal gate: ALL journal-bearing services (browser-history, overview, …) get the DB-copy dry-run rule from row 4 — *not harvested: needs the consumer inventory from row 38 first.*
40. Upstream: preflight should classify "key-basis mismatch" vs "truncated journal" as distinct verdicts with distinct remedies — *not harvested: inside row 1's scope.*
41. `[watch]` Track go-cqrs-lite master for a compat release past `d15e0a48` — *not harvested: the upstream row's landing condition already implies it.*
42. `[decision]` Bank-sync MemoryHigh sizing (5,011 hits in its first 7 minutes post-start) — part of row 16's pass — *not harvested: dedupe of 16.*
43. `[ready]` Add the usb-storage corpse shape to the pressure-gate negative tests (row 23's test leg) — *not harvested: dedupe of 23.*
44. `[ready]` Smoke §18: classify during-deploy build load (nix-daemon) as expected — *not harvested: dedupe of row 12's baseline-refresh rationale; do both in one pass.*
45. `[watch]` After SCA approval: backfill window state per `sca.md`/`backfill.md` recovery chain (T3/T4) — *not harvested: owned by the SCA runbook chain.*
46. `[ready]` Record today's rollback in `docs/agents/systemd.md`? — NO: rejected, wrong domain (service-level, not systemd); recorded here deliberately so nobody re-litigates the placement.
47. `[decision]` Should the §15 gate (another session's, unreviewed by me) get a second-reviewer pass before it guards every deploy? It verified green today and its selftest exists (`pre-vacuum-gate-selftest`), but it entered the tree via daemon commit — *not harvested: owner judgment on review policy.*
48. `[ready]` Health-endpoint probe post-approval (row 7) should use the repo's `verify-deployment.sh` not ad-hoc python — *not harvested: tool-choice note, rides row 7.*
49. `[watch]` `bank_sync_sync_errors_total` restart-cumulative semantics vs smoke §checks (documented 2026-09-30) — re-verify still accurate post-rollback — *not harvested: fold into row 12.*
50. `[decision]` Keep `evo-x2` deploys local-only via nh (worked flawlessly today) vs the older raw-rebuild path still shown in some upstream runbooks (bank-sync's deploy.md shows `sudo nixos-rebuild switch`) — align the upstream doc — *not harvested: upstream doc PR, needs verify-before-filing first.*

**Harvest ledger (AGENTS.md obligation):** direct follow-ups landed at authoring time — rows 1 (upstream.md, pre-report), 2 (pipeline.md + queue), 3 (services.md + queue), 4 (services.md + queue). Rows 5–50 carry per-item reasons above; the dominant reasons: already-owned by standing runbooks/gates, dedupe with adjacent queued rows, sub-2-minute probes batched into the next calm-box pass, ROADMAP-scale, or owner-policy questions (section g).

## g) Questions I cannot answer myself (max 3)

1. **Who or what executed the bank-sync flake bump to `eb7818c6` on Oct 12 (~21:45–21:52)?** I can forensically narrow agent sessions via `.crush/crush.db`, but if this was a manual `nix flake update` in one of YOUR still-open terminals, fish history only lands on shell exit and I cannot see it. The answer decides the prevention: an unattended-update policy gap vs a session that skipped the rehearsal protocol. If you know it was you, one word saves the forensics.
2. **Do you ratify the hard tripwire (row 2: `nix flake check` FAILS when the bank-sync rev moves past `67dd64526` without an explicit owner-set override), or do you prefer a WARN + queue note?** Hard = the re-fuck is structurally impossible but every legitimate future bump needs a deliberate override; soft = the guard can be ignored under pressure. I built neither yet — your call lands before I write it.
3. **Will you run the Wise SCA dashboard OTP approval now?** (`docs/services/bank-sync-sca.md` — Sync State card → "Wise approval needed" → Approve now.) It is the ONLY path to clear `bank.empty_sca_token` on all 20 balances and turn the sustained-failure red (and its recurring Discord pushes) green. Everything else in bank-sync is now healthy; this is the last gate and it is yours alone.

---

### Evidence appendix (short-rev citations; full revs recoverable via the cited commands)

| Claim | Evidence |
| --- | --- |
| Pre-deploy green | deploy run §Summary: `94 passed, 12 warnings, 0 failed` |
| Root cause (library) | `git -C ~/projects/go-cqrs-lite diff 7142e43 d15e0a48 -- metaengine/sqliteengine/stream_log.go` (additive only) vs `git show 7142e43:id/stream_id.go` vs working-tree `id/stream_id.go` (`ParseStreamID` prefix-strip + hash round-trip) |
| Root cause (data intact) | read-only probes: `meta_stream_log` 171,945 rows / collection `events`; `snapshots` 45 rows, all readable keys, `('BalanceSync','profile:wise:14757634',3850)` vs journal 3,856; `events`=0, `events_legacy_v4`=148,158; ULID variant `BalanceSync:01M0D6ER1TFVK6DRREM400002B` = 3,787 rows; 8,260 distinct stream_ids |
| Rollback coherence | lock nodes spliced verbatim from `git show b6cdade2:flake.lock`; `nix flake check --no-build` → `all checks passed!` |
| Rollback rev gates | `git merge-base --is-ancestor 719d476c 67dd64526` → NOT ancestor; ancestor-of-current ✓; `metrics_test.go` gauge assertions at `67dd64526` |
| Deploy + health | switch `Started` 14:53:31; `/proc cmdline` = `f56p45m4…-bank-sync-67dd64526…/bin/bank-sync run`; `/health/ready` → `200 {"status":"up"}`; `bank_sync_sync_total 1`; 0 DATAERR since |
| Corpse class | `ps` PID 731 `usb-storage` D-state; PSI some avg10 25–33% with idle disks (busy 2.0%) |
| Smoke | `PASS: 143 FAIL: 4 SKIP: 5 WARN: 15 STORM-SUSPECT: 2`; exit 3 = "Service Sanity CPU" new-vs-baseline |
| Pre-existing sync failure | journal 14:53:42: `[rejection] bank.empty_sca_token: approval token is empty` ×20 balances; `bank_sync_sync_consecutive_failures{wise} 124`, `bank_sync_sync_sustained_failure 1` |
