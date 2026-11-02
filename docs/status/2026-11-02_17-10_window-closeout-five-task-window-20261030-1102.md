# Window Close-Out: Five-Task Window 2026-10-30 → 2026-11-02 (dnsblockd batch, TTFT alert, freeze-#38 triage trio)

**Authored:** 2026-11-02 ~17:10 CET · HEAD `8a65b418e` · host evo-x2
**Window tasks:** 000001a1858ad24… (dnsblockd 3-item batch), 000001a181b7a97a… (SigNoz TTFT alert), 000001a18b1604272… (freeze-#38 calm-window crash-triage + ledger), 000001a18f409c32… (boot `27580a79` evidence + stability 3-item batch), 000001a18fe8842b… (guard ioPause cgroupPatterns extension)
**Evidence base:** closeout reports `docs/status/tasks/2026-10-30_05-05_task-…58ad24….md` + `docs/status/tasks/2026-10-31_01-40_task-…409c32….md`, commits `392ad4476`, `db568283c`, `a2a3f195f`, `5d2c5a631`, `22345c8ff`, `ec8010426`, `3012a21d3`, `a4010e23a`, `b8f6f56ca`, and the in-tree verification below. tq facts/journal queries from this shell returned ZERO facts (DB not reachable here), so §h is bounded by that.

---

## a) FULLY DONE (verified)

1. **dnsblockd 3-item stability batch — all three closed (`392ad4476`, `db568283c`).**
   - OTel 4318-refused journal spam: `LogFilterPatterns` silence filter live in-tree (dns-blocker.nix:1538, landed 2026-10-29); out-of-band alarm path (`dnsblockd-otel-observer` + Gatus `dnsblockd_otel_export_broken`) intact.
   - Readiness gate proves :53 over UDP+TCP: `checks.dnsblockd-readiness-gate` re-built green in the closeout session.
   - Trust-bundle "second writer" RESOLVED: nixpkgs `security.pki.certificates` → `cacert.override` → buildcatrust emits each user CA twice (plain + p11-kit TRUSTED blocks); evidence chain (base64-body count 2 vs 1 in the no-trust-rules sibling, identical DER fingerprints, pristine store output) documented in `docs/services/dnsblockd.md`. Queue row 207 ticked RESOLVED.
2. **SigNoz TTFT alert for local interactive inference — CLOSED (`a2a3f195f`, 2026-10-30).** Both rules (warn >30 s / critical >120 s, `ai_meter_ttft_seconds`, upstream=llama-chat) live in `/run/current-system/etc/signoz/rules/` and present in the live `/api/v1/rules` payload (state inactive — armed but vacuous until the first streaming call; see §f.4).
3. **Freeze-#38 calm-window crash-triage + ledger entry — CLOSED (`5d2c5a631`, 2026-10-31).** `crash-triage --boots 6` for the 2026-10-30 03:32 watchdog death; stability.md #38 census row landed; the follow-up session then OVERTURNED two committed numbers (trips 40→412, boot-0 0→169 — crash-triage's trips grep counted only socket-stops) and the metric was fixed (`3012a21d3`, grep alternation at scripts/crash-triage.sh:96, selftest both-eras fixtures, `--boots 6` regenerated: #38 boot `b0d70d73` now 413 trips). SUPERB extinction-plan mapping landed (`ec8010426`): #38 CONFIRMS actor presence but REFUTES the IO/thermal kill hypotheses — died of MEMORY; OOM-swap-exhaustion added as a new extinction hypothesis; nsfw cold-restart premise refuted. Queue rows 147/148/151 ticked DONE 2026-10-31/11-02.
4. **Freeze-#34 boot `27580a79` evidence pull — CLOSED (`a4010e23a`).** 2,848-line canonical evidence file committed (`docs/status/tasks/2026-10-31_00-01_boot-27580a79-evidence-pull.md`); WDT reset reason `0x02000800` independently verified in next-boot kernel log; fix-on-sight: boot-evidence-pull.sh EXIT-trap `set -u` bug fixed (was leaking ~400 MB scratch per pull). Pre-vacuum gate: all 6 exposed boots guarded — the oldest-boot vacuum race is closed. (This was the un-evidenced boot the 2026-10-31 crash-triage run flagged.)
5. **Guard ioPause cgroupPatterns extension — LANDED and verified 2026-11-02 (queue row 149 ticked DONE).** `monitor365-server.service` + `app.slice run-*.scope` patterns in `modules/nixos/services/memory-emergency-guard.nix:1578` (attribution-informed: the freeze-#38 census showed 373 whole-boot NO-eligible IO-PAUSE trips while monitor365 held +13.2 GB windows and agent sessions live under `run-*.scope`, which `session-*` never matched); §9d no-match→match VM-test leg with tty-less-ness asserted (`tests/test-memory-emergency-guard.nix:1014`); evo-x2 toplevel evals green.

**Window verdict: 5/5 tasks fully closed, every closeout committed with a Task-Queue-ID footer, all follow-up rows self-harvested into TODO_LIST + domain libraries.**

## b) PARTIALLY DONE

1. **The trips-metric contradiction shipped unresolved in an intermediate commit** — the census quoted "40 trips" alongside "39 + 373 action lines"; reconciled 30 min later at closeout (412/169 real). Final state correct; sequencing violated quote-scrutiny (own §d.2 of the 01-40 closeout).
2. **The 865 vs 880 vs 579 guard-line count reconciliation is approximate** (±15 residue, report's exact grep shape not reproduced). No decision depends on it; still open.
3. **Attribution drift on the dnsblockd batch:** the item-3 resolution text's authoritative commit (`9296af280`) is footerless (daemon-swept); the footer-carrying `db568283c` carries the summary. The task's own report §d.1 owns this.
4. **TTFT rules are armed but never exercised** — no streaming llama-chat call has fired them since provisioning; "alert works" is unproven until a real fire or a synthetic probe.

## c) NOT STARTED (window skipped; owned by existing rows)

- The remaining freeze-#38/#39/#40 stability rows: llama-stack MemoryMax floors (row 156), post-crash deploy-anchor check (157), 96 °C thermal re-open (158), wtmp shutdown-record doc (159), OOM-cascade anatomy rows (153, 166), flm-real restarter sweep (152), scratch age-gate (154), PAUSE_FILE observability (155).
- Journal vacuum clock: ZERO retention margin (8G/8G); vacuum-schedule-audit row still open.
- monitor365-server wedge fix `5555a89ec` still undeployed (re-evidenced by the #38 census: 1,584 death-window lines).
- Guard memory-leg action design (§g.3 of the 01-40 closeout) — deliberately parked behind the owner policy question.

## d) TOTALLY FUCKED UP (honest, from the window's own self-reviews)

1. **Two near-miss inverted-verdict traps in one session** (2026-10-31 closeout §d.1–§d.2): an unquoted `$J` journalctl variable fed literal quote chars to journalctl and returned impossible zeros (caught only by leaked stderr); and two irreconcilable census numbers were committed before reconciliation. Both caught; both are exactly the quote-scrutiny / empty-output-is-never-evidence classes.
2. **Footer/daemon-race losses:** the auto-commit daemon swept the dnsblockd item-3 close-out into footerless `9296af280` (~18 min write window); a dangling commit `30a77f9e4` was created and absorbed by an amend that skipped the verify-what-the-daemon-staged check (content verified clean after).
3. **Metric-artifact class:** crash-triage's trips metric silently undercounted the ioPause era 10× and two committed ledger numbers inherited it — a self-test fixture gap, now fixed (`3012a21d3`).
4. **Pathspec-amend lint bypass nearly shipped unlinted shell** (hook legs key on the index; caught by reading hook output; standalone shellcheck re-run clean).
5. **The dnsblockd batch was even dispatched at all:** both 2026-10-29 close-outs marked row bodies `[x] DONE` but left the line checkbox `- [ ]`, re-dispatching a two-line fix as a whole task — the checkbox-flip discipline gap the 05-05 closeout §e.5 names.

## e) WHAT WE SHOULD IMPROVE

1. **Close-outs must flip the ACTUAL checkbox** (the harvest reads the line prefix) — repeat of the §e.5 rule; consider a `check-todo-system.sh` leg that flags DONE-marked rows whose line checkbox is still `- [ ]`.
2. **Ban variable-held journalctl command strings with embedded quotes**; extend "empty output is never evidence" to count-zeroes when any sibling baseline implies nonzero (AGENTS.md shell-trap candidates).
3. **Reconcile-or-annotate BEFORE committing** when one census yields two numbers for the same population.
4. **Metric-definition headers on census tables** ("trips = grep …") so consumers can't inherit artifacts silently — landed for trips via the fix; apply the pattern to every crash-triage column.
5. **Per-item immediate commits on shared trees** — the daemon wins any write window longer than ~10 minutes.
6. **Post-pathspec/amend standalone lint re-run** belongs on the commit checklist (CONTRIBUTING).

## f) NEXT THINGS (dedup-checked against the 1,564 unchecked rows; the window's own §f self-harvests — buildcatrust upstream 1757, ca-bundle pointer 1758, stability rows 152–159 — already exist and are NOT re-queued)

1. Confirm rpi3-dns carries the same buildcatrust CA duplicate (same module, same inline PEM) at its next deploy probe — one grep on the raw bundle base64 body → docs/todo/services.md (Source: 05-05 closeout §f.5)
2. Sweep `docs/services/*.md` for other "second writer unidentified" phrasings that may hide the same cacert.override mechanism (one rg) → docs/todo/services.md (Source: 05-05 closeout §f.6)
3. Add the eval-time comment/assertion in dns-blocker-config.nix documenting the inline PEM is INTENTIONALLY also in the cacert output (comment-claim hygiene) → docs/todo/services.md (Source: 05-05 closeout §f.7)
4. Exercise the TTFT alert rules with one real streaming llama-chat call (or synthetic probe) — both rules inactive/vacuous since provisioning → docs/todo/monitoring.md (Source: a2a3f195f commit message)
5. Reconcile the 865 vs 880 vs 579 guard-line counts (report's exact grep shape; ±15 residue) → docs/todo/stability.md (Source: 01-40 closeout §b.2/§f.25)
6. Read the ioPause attribution/top-IO selection code path for a second bug beside the pattern list — why did attribution match NOTHING even when tq/nix-daemon were live (341 nix-daemon final-window lines)? → docs/todo/stability.md (Source: 01-40 closeout §f.24)
7. Consider structured telemetry for the §22 trust-bundle duplicate-WARN (textfile metric making drift from the 2-copy steady state alarmable) → docs/todo/monitoring.md (Source: 05-05 closeout §e.4)

## g) QUESTIONS FOR THE OWNER

1. **buildcatrust bundle hygiene:** is the plain+TRUSTED duplicate acceptable as permanent state (§22 WARN as tripwire), or should `security.pki.useCompatibleBundle` be evaluated (strips trust rules AND carries the CA once — a trust-semantics call across all consumers)? Filing upstream rides row 1757 either way.
2. **Attribution for footerless `9296af280`:** leave history as-is with the pointer in `db568283c`, or author a quiet-window history rewrite (unpushed, mechanically safe, checklist applies)?
3. **SUPERB §g.3 (carried, evidence now corrected):** re-prioritize the plan against #38 — promote M23 (ZRAM/watermark) to the critical tier and add a memory-leg guard-action design as a new act — or keep executing as sequenced? And the companion policy call: is kernel-OOM adj-ranking an ACCEPTED sacrificer for the swap-exhaustion class, or should the guard own it?

## h) BAND DRIFT

**None recorded.** `tq facts` / journal queries from this shell returned zero facts (the tq DB is not reachable from this environment; `tq tasks` returned null), and no task.reprioritized markers surfaced in the window's closeout reports. All five tasks were harvested at their enqueued `[ready]` band. Caveat: this section is bounded by that tool inaccessibility, not by a positive empty-journal read.

---

## Docs-health pass notes

- CHANGELOG: appended the dnsblockd OTel-silence + trust-bundle resolution entry (2026-10-30) — user-visible journal-spam fix + resolved mystery that had no CHANGELOG row. Other window deliverables: TTFT rules live outside the repo (SigNoz runtime state, not tree config — no CHANGELOG row owed); guard ioPause pattern extension is covered by the existing 2026-10-25/11-02 memory-emergency-guard entry's ioPause sections.
- FEATURES/README/ROADMAP/AGENTS: no stale claims found against this window's changes (AGENTS.md already carries the trust-bundle-adjacent dnsblockd facts; the ioPause cgroupPatterns addition is module-internal, nothing in the living docs asserts the old 3-pattern list).
- Archives: the window's two closeout reports live under `docs/status/tasks/` per the task-report convention and are referenced by live queue rows (1757/1758 cite the 05-05 file) — not archived.
- No report under docs/status/ dated 2026-* required inline annotation from this window's findings; the window's own closeouts are self-annotating (their §d sections ARE the corrections).
