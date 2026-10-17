# Boot-Order & IO-Tier Opinions + Verification Session — 2026-10-17 10:44 CEST

**Session arc:** Oct 15 23:44 → Oct 17 10:44 (owner Q&A across ~34h; parallel sessions worked overnight).
**Turns:** (1) boot-speed status check → report `2026-10-16_00-31`; (2) "boot order?" opinion; (3) "io priorities?" opinion; (4) this verification pass.
**Scope discipline:** read-only forensics + opinions; the only writes were queue/doc harvests (list in §a). No code, no config, no deploys.
**Environment:** 3 concurrent writers in the window (me + overnight session(s) — stalwart email report 2026-10-17_05-39 + untracked `scripts/bench-samsung-livefs.sh` are NOT mine; HEAD moved fd0e2cc3→dbfabb6a→53fae6f0; 5 mid-edit race refusals absorbed, all writes landed clean).

---

## TL;DR

Two opinion turns produced three durable findings: **the Samsung mirror-first boot order is live and was re-activated deliberately by the owner** (heatsink + reseat + re-activation, Oct 15 22:23 — solved from the journal, not asked); **the box has now survived 35h+ on one boot post-heatsink** (first real cooling-fix signal); and **the ioTier system structurally cannot see the storm** — its top stalled cgroups live in user.slice, which no tier covers. One of my own claims got falsified in the process: "activation runs leave NO journal/file trace" — sudo journalled the whole invocation.

---

## Evidence base (new since the 00-31 report)

| Probe | Result |
|---|---|
| efivarfs decode (Oct 16 00:50, re-read Oct 17 10:44) | BootOrder `000C`-first, `BootCurrent` `000C`, `LoaderDevicePartUUID` = Samsung ESP — mirror-first LIVE, green across 35h one-boot uptime |
| `journalctl _COMM=sudo` since Oct 12 | **Oct 15 22:23:21 + 22:23:29**: `lars … TTY=pts/1 … MIRROR=/boot-mirror bash ./boot-mirror-activate.sh` — desktop terminal, minutes before the 22:30 clean shutdown |
| `.crush/crush.db` `boot-mirror-activate` query | Zero agent-session hits (positive-validated against 'compsize', 2485 hits) → owner-manual is the best-supported read; AGENTS.md + storage.md row 38 independently confirm "owner re-activation" post-heatsink |
| boot-metrics.prom (Oct 17 10:44) | Boot `3efe02cf` final verdict: **userspace 37m33s, total 37m49s**, phase-COMPLETE (the unfinished-boot retry worked); boot_uptime 126,826s and counting |
| Live stalled-cgroup ranking (Oct 16 ~00:45) | `user@1000.service` **92.8%**, `session-194.scope` 59.9% vs tiered units ≤5% (fstrim idle 4.4% = yielding by design; clickhouse heavyDB 4.8%) |
| ioTier census | 41 modules / 70 uses (59 background, 5 build, 3 maintenance, 2 heavyDB, 1 service); **llama-chat: NO tier** (verified in its module); tq-agent-pool build ✓; inboxclean tiered ✓; btrbk/compsize: "no tier found" (weak glob — see §d.4) |

---

## a) FULLY DONE

1. **Boot-speed status report + both-surface harvest** (00-31 report; 4 library rows + 4 dispatch one-liners, lint green).
2. **NVRAM decode protocol, three times** — mirror-first verified live Oct 16 00:50, still green Oct 17 10:44 after 35h on the same boot. Byte-level: BootOrder/BootCurrent/LoaderDevicePartUUID all match the Samsung expectation.
3. **Mirror-activation attribution SOLVED without asking** — sudo journal lines name the actor path (pts/1 desktop terminal, 22:23 Oct 15); crush.db rules out agent sessions (positive-validated); AGENTS.md/storage.md row 38 independently record the heatsink + reseat + owner re-activation arc, which also explains both clean reboots and the 7.2.9→7.2.10 jump.
4. **AGENTS.md falsification corrected** — "Activation runs leave NO journal/file trace" replaced with the sudo-layer truth + the grep-first guidance (`journalctl _COMM=sudo`), with the live evidence inline; decode re-verification dates added.
5. **Boot-0 final verdict captured** — 37m49s total, phase-complete prom: the transaction drained ~24 min AFTER graphical (23:43 → ~00:07), confirming the transaction-open class is real and now measured. My queued prom-check leg closes.
6. **ioTier census + tier folds** — compsize row (both surfaces) now carries the idle-class leg with the live-yield evidence; user.slice coverage gap documented in opinion + report.
7. **Two exploration-mode opinions delivered** (boot order; io priorities) with zero uninvited implementation.

## b) PARTIALLY DONE

1. **btrbk/compsize tier absence** — hedged "no tier found" is honest but the check was a filename glob over `services/`; the units' defining modules may live elsewhere (compsize's module didn't even match "compsize" there). The tier CLAIM for btrbk remains unverified at its definition site.
2. **user@1000 92.8% internal attribution** — WHO inside the user manager (crush DB churn? activitywatch? HM units?) not resolved; session-194 identification came back empty (scope ended by probe time). The storage.md crush-DB row already targets the structural fix.
3. **Calm-boot classification** — 37m49s is still storm-class; the calm re-measure remains blocked. The 35h+ freeze-free uptime is a promising post-heatsink signal, not a measurement.
4. **Prior report §g.1** — obsoleted by evidence (self-answered); formally withdrawn HERE, correction recorded. §g.2/§g.3 still open (see §g).

## c) NOT STARTED (queued/opinion only, awaiting dispatch or owner)

1. llama-chat de-gating (+ Gatus-precondition check before the move; tier choice BE/5-ish after).
2. Boot transaction-open gauge (`transaction_open_seconds_past_graphical`).
3. Multi-user-gating + tier-coverage family audit (order AND io-tier, one sweep).
4. compsize: scheduling trace + PSI entry gate + idle tier (row updated, execution queued).
5. Calm-boot re-measure + warm-firmware repro (blocked on a calm window — §g.2).
6. user.slice tiering design — not scoped, not queued (owner-direction question in §g.3).
7. Everything carried in §f — no dispatches fired on them this window.

## d) TOTALLY FUCKED UP

1. **I asked the owner a question the journal had already answered.** Last report §g.1 ("were the reboots yours / did anyone re-run boot-mirror-activate?") was answerable via `journalctl _COMM=sudo` in one grep — and I had REPEATED the docs' "activation runs leave NO journal/file trace" lore as fact in my boot-order answer ("no recorded actor"). The claim was falsified by the first probe I finally ran. The ask-only-what-you-cannot-figure-out rule requires the documented forensic battery (sudo lines, crush.db WITH positive-validation) BEFORE asking; docs lore is a claim to verify, not a fact to inherit. Corrected in AGENTS.md; the wrong claim stood ~34h and rode in two answers.
2. **The NVRAM discovery went unrecorded for ~34h.** Memory mandate: record at discovery, not end of session. A parallel writer beat me to the state update (AGENTS.md:150 + storage.md row 38 already carried the full arc by the time I returned); my unique residue (the sudo-trace falsification) only landed in this pass. Same failure shape as the half-queue in the first report: discovery discipline collapsing on non-primary turns.
3. **Three tier fixes lived as prose for two turns** — compsize idle-tier, btrbk background, llama-chat post-de-gate tier. The compsize fold (a 1-line edit to MY OWN row from the same session) landed only after the third prompt. The repo's fold-immediately culture exists because this is the natural failure mode.
4. **Shallow verification carried into steering claims** — the "NO ioTier" checks for btrbk/compsize were glob-based, not definition-resolved. The spot-verify rule (grep the actual config line before queueing an ask) applies to opinion answers that will steer fixes just as much as to queue rows.
5. **My own row's cheap leg sat untaken** — the boot-0 prom check was one command, queued by me, and I skipped it across two subsequent turns until report-writing forced it. In-passing is the house style; I treated it as out-of-scope twice.
6. **Concurrency handled, but by luck at the margins** — every write this window survived races (two files edited under me twice; HEAD moved twice). The content-pin + atomic-edit discipline worked WHEN I applied it (this pass) and I skipped it at least once earlier in the session (already owned in the 00-31 report). Flagging the residual risk: shared-file writes remain dice-rolls on this tree.

## e) WHAT WE SHOULD IMPROVE

1. **Before ANY owner question: run the forensic battery.** sudo journal lines → crush.db (positive-validated) → THEN ask. And treat docs lore ("no trace", "always X") as testable claims — this session falsified one that cost an owner question and ~34h of wrong memory.
2. **Discovery→record applies to opinion turns.** New state facts get recorded at discovery even when the turn is "just" a discussion — the mode governs implementation, not memory.
3. **Opinions that will steer fixes need queue-grade verification** — resolve the unit's defining module before asserting absence/tier claims.
4. **In-passing legs**: when a probe is one command and the row is mine, take it during the turn that touches the topic.
5. **Docs candidate:** "silent scripts are not traceless — sudo/dbus/journal layers log invocations" (sudo-trace lesson generalizes beyond boot-mirror; would fold into the CONTRIBUTING journal-convention paragraph already queued).
6. **Mirror persistence posture (owner call, dissent noted):** current posture is conditional — a decode tripwire only after a THIRD reversion. My opinion: a standing 2-efivar-read check (Gatus or pre-reboot-check leg) is cheaper than post-hoc forensics and would have caught reversion #2 same-day. Recorded posture respected; row 38 re-opens it automatically on reversion.
7. **Post-heatsink stability watch:** 35h+ single-boot uptime is the first genuine cooling-fix signal in the freeze lineage. The cooling row is [blocked:user] and the owner's fix landed silently — a short stability-watch note (freeze-lineage entry) would make the baseline explicit instead of folk knowledge.

## f) 50 things to get done next (carried = prior report §f, updated; CLOSED entries removed)

**A. Boot measurement & verification debt**
1. Calm-boot re-measure of the 2026-10-06/12 batteries (userspace ≤40s) — [blocked:deploy] stability.md
2. Warm-reboot repro ×2-3 (~6.8s firmware systematic?) — stability.md
3. Per-boot reset-reason sweep — stability.md
4. WAL-gate falsification on clean hermes restart — stability.md
5. Name the unit(s) holding the boot transaction open past graphical — stability.md (prom half of the leg CLOSED this pass)
6. `transaction_open_seconds_past_graphical` gauge — stability.md
7. Family audit: multi-user-wantedBy units >30s boot-window starts (+ their io-tiers, merged scope) — stability.md
8. Execute llama-chat de-gating (Gatus-precondition check first; then BE/5-ish tier) — stability.md
9. Verify the 2026-10-12 compsize boot-window fix + PSI entry gate + idle tier (row updated this pass) — stability.md
10. Audit the initrd 31s outliers — stability.md
11. Finish crash-cadence quantification on the corrected two-clean-boundaries premise — stability.md
12. Loader timeout 2→1 — [decision] stability.md
13. `systemd-analyze verify` sweep over ALL unit files — [ready] pipeline.md
14. Boot-scoped vs window-scoped journal convention paragraph (fold in the sudo-trace/silent-scripts lesson) — [ready] pipeline.md
15. NVRAM decode standing check (Gatus/pre-reboot-check leg) — posture-dissent item, owner call via row 38's conditional

**B. IO priority coverage (new cluster from this window)**
16. Scope user.slice tiering: HM `IOSchedulingClass` defaults for churner units + dedicated agent-session slice — §g.3 direction call
17. io-tier coverage audit as eval gate (boot-gated units must carry a tier; user.slice documented out-of-scope) — fits the house audit pattern
18. Verify + fix btrbk tier at its defining module (background/maintenance at boot) — definition site unresolved
19. Attribute the 92.8% user@1000 stall internally (crush DB churn vs HM units) — feeds #16

**C. Storm & thermal (amplifier)**
20. URGENT cooling inspection row — [blocked:user], heatsink landed 2026-10-15: update the row + freeze lineage with the post-fix baseline (35h+ boot)
21. Zone-6 guard trip-RATE alert — [ready] monitoring.md
22. Phantom-PSI root-cause — [ready] stability.md
23. Guard trip-rate escalation paging — [ready] stability.md
24. Freeze #8–#13 entries into docs/agents/stability.md — [ready] stability.md
25. Freeze-#27 death-minute ranking verdict — [ready] stability.md
26. io-PSI-with-idle-disks signature — [ready] stability.md
27. fastflowlm pre-bind port forensics — [ready] stability.md
28. FLM restore budget boot-reset — [decision] stability.md
29. llama-rag-dark-guard timeout — [ready] stability.md
30. Guard silence (09:56 boot) root-cause — [ready] stability.md
31. Freeze-14 death-minute nix-eval driver + enforcement leg — [ready] stability.md
32. thermal-pstate-guard tick-starvation observability — [ready] stability.md
33. tq-agent-pool harvest-tick full-state rescan IO — [ready] stability.md
34. inboxclean-web IO storm hardening — [ready] stability.md
35. Desktop-state snapshot collector for freeze autopsies — [ready] stability.md

**D. Storage under the boot path**
36. ClickHouse → Samsung hot-DB relocation — [ready] storage.md
37. Hot-db shadow-split guard — [ready] storage.md
38. Crush session DBs off the QLC root — [blocked:user] storage.md (feeds #16/#19)
39. legal-cases root-owned target heal — [blocked:user] storage.md
40. Boot-mirror persistence watch (row 38 conditional: tripwire on a third reversion) — [watch]
41. /data docker residue owner reclaim — [blocked:user] services.md
42. Deploy the no-heavy-builds gate removal + post-deploy verify — [ready] TODO_LIST.md

**E. Firmware / BIOS**
43. BIOS boot-time walk (MCR / Fast Boot / POST trim) — [blocked:user] stability.md
44. BIOS fix for DAS boot hang — [blocked:user] stability.md

**F. Meta**
45. check-todo-system lint leg: every `[ready]` library row must have a dispatch one-liner
46. Storm-context marker in boot-metrics.prom (PSI at finish) so the calm re-measure auto-fires
47. Harvest-mode reminder in CONTRIBUTING: library row + dispatch one-liner in the SAME edit pass
48. Mirror-activation traceability: keep the sudo-trace evidence path documented next to the efivar decode protocol (landed in AGENTS.md this pass — verify it survives the next docs restructure)
49. Post-deploy §battery for the next deploy carrying llama-chat/compsize changes (de-gate + tier verification legs)
50. Close-out sweep of THIS session's rows after first dispatches (5/7/9/16 verification legs)

## g) Three questions I cannot figure out myself

1. **llama-chat warm-up tradeoff (carried, now doubled):** de-gating means login unblocks but chat goes ready ~8 min later; tiering it BE/5-ish additionally yields to other bulk IO under storms. Acceptable for your usage, or must llama-chat be hot-at-login and untiered? (This single answer unblocks rows 8 + part of 7 + the llama-tier question.)
2. **Deliberate quiet-window reboot for the calm-boot re-measure + warm-firmware repro?** The 35h+ post-heatsink boot looks like the first stable baseline in the freeze lineage — a planned reboot in a quiet window would finally take the userspace-≤40s verdict AND test cooling across a boot cycle. Or keep waiting for organic boots (which have been storm-class every time)?
3. **user.slice IO policy — in or out of scope?** The storm's top cgroups are your own user manager and session scopes (agents, crush DBs, terminals). Do you want a scoping pass for tiering that half of the box (HM unit defaults + a dedicated agent slice), or is user.slice IO your own interactive territory that system policy shouldn't touch?

---

*Probes this window: efivarfs decodes ×3, `journalctl _COMM=sudo`, crush.db (positive-validated), boot-metrics.prom, PSI + cgroup io.pressure ranking, ioTier census greps, `last -x`, module greps. Writes: AGENTS.md (sudo-trace correction), stability.md + TODO_LIST.md (compsize tier fold, both surfaces). Parallel-session writes observed (stalwart report, bench script) — untouched. No commits; daemon sweeps.*
