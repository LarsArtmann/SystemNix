# Boot ee085387 Thermal-Trip Crash — Diagnosis, Self-Review & Status

**Session:** 2026-10-18 00:44–01:00 CEST (post-crash diagnosis turn + status-report turn)
**Trigger:** owner asked "Why did we fucking crash again?"
**Scope:** this session's crash investigation only (per owner instruction — no unrelated research).
**Format note:** owner demanded explicit `.md` at `docs/status/` — overrides the status-report/brutal-self-review HTML defaults (flagged per skill contract). Prior `docs/reviews/*.html` self-review episodes deliberately not skimmed (owner scope restriction).

---

## Diagnosis (what this session established)

**Boot `ee085387` (2026-10-17 18:13:49 → 2026-10-18 00:40:44) ended in a firmware-level power cut with the SoC pinned at its thermal ceiling. Best-supported hypothesis: hardware thermal trip (THERMTRIP class). Not software.**

Evidence chain:

1. **Journal stops mid-normal-traffic** at 00:40:44 (emeet-pixyd /metrics 200 OK is the last line). No shutdown sequence, no unit stops, no "Reached target Shutdown".
2. **Census (canonical pull):** 0 kernel OOM lines; 4 "panic" lines are cmdline/drm false-positives (verified — kernel cmdline `panic` strings + `drm panic` planes); 910 memory-emergency-guard lines (I/O PSI pressure, separate axis); 11 throttle ENTER/EXIT transitions.
3. **`softlockup_panic=1` + `nmi_watchdog=panic` + `pstore.backend=efi pstore.record_console=true` are all configured** — none fired; **pstore is empty** (caveat in §b: backend functionality itself unverified).
4. **Thermal trajectory:** guard ENTER at 95-98°C at 18:29, 19:42, 20:34, 20:44, 21:42, 23:21 — each EXIT only after 30-60 min of throttling (cooling to 62-76°C), then **re-ENTER within ~2 min** (21:41:59 EXIT → 21:42:19 ENTER at 98°C). The **23:21 ENTER never exited**. From 00:25→00:39 DEEP THROTTLE (60% freq cap) re-entered every ~70s with k10temp 98-99°C — a losing oscillation. 2538 total thermal-guard lines in one boot.
5. **This is chronic, not a one-off:** prior boots show the same signature — boot -2: 817 deep throttles; -5 (crash-marked Oct 15 02:19): 23, hit 96°C; -6 (Oct 14): 289, 98°C; -7 (crash-marked Oct 11): 97°C. The SigNoz rule description confirms the class history: "freeze #8/#9/#11 pre-crash signature (95-99°C rode zero CPU-temp alerting; T12 2026-10-10)". Tonight the ceiling graduated from freeze to power cut.
6. **Heat load at crash time (stacked, same Strix Halo package — CPU+GPU share k10temp):** nsfw-classifier-go-rocm (15-model ROCm ensemble, `resolved=rocm`, ran the entire boot), crm-server, 3-4 crush sessions, clickhouse, granian×3, hermes, flm-real — plus I/O PSI storms on a second axis (guard trip #3445 at 18:20: I/O PSI some avg60=60%, disk 100% busy, MemAvailable 72.6% — the "crash #3 class" full-disk-reader livelock).

**Live state while writing this report (15 min post-boot):** load average **111** — three concurrent parallel-session builds (nsfw-classifier `go compile -c=32`, monitor365 libduckdb `cc1plus -c=32`, art-dupl `go compile -c=32`) + nsfw server at **167% CPU**. k10temp 64°C at the sample moment (85-90°C was seen at 3 min uptime). The `workload-admission` heavy-job wrapper does **not** gate these dev-shell builds — the pressure cooker is being re-assembled right now by parallel sessions.

**Canonical artifact:** `docs/status/tasks/2026-10-17_22-46_boot-ee085387-evidence-pull.md` (boundary discriminator + full census; written by `scripts/boot-evidence-pull.sh -b -1`).

---

## a) FULLY DONE

1. **Root-cause diagnosis with timeline** — thermal-trip power cut, evidence chain above, distinguishing it from the freeze/OOM/panic classes by census + pstore + configured-watchdog absence.
2. **Canonical boot evidence pull written** — `docs/status/tasks/2026-10-17_22-46_boot-ee085387-evidence-pull.md`, per §15 pre-vacuum-gate discipline (id8 `ee085387` cited in the hex-boundary form the gate greps).
3. **Chronic-class confirmation** — throttle census across boots -2/-5/-6/-7 proving this is a recurring pre-crash signature, not a novel event.
4. **Fix surfaces precisely located** — `modules/nixos/services/thermal-pstate-guard.nix` (hysteresis + missing escalation rung), nsfw-classifier unit (ensemble/CPUQuota), `modules/nixos/services/_signoz-alerts.nix` (`cpu-thermal-ceiling.json` rule EXISTS — T12 2026-10-10).
5. **Live-state verification** — uptime/boot map, temps, load, process census; each claim traced to a probe output rather than doc statements.

## b) PARTIALLY DONE

1. **Evidence file written but NOT COMMITTED.** `git index.lock` held >15 min by a parallel session's `pma` amend (pid 101682, its commit-message LLM call was failing → hanging amend). Consequence: **§15 pre-vacuum gate cannot pass → deploys are blocked** until the daemon sweeps the file or a pathspec commit lands. I left it pending with a fallback note only in chat — not durable.
2. **Trip mechanism named but trip point unverified.** `temp1_crit` is not exposed in sysfs for k10temp/acpitz; my "~100°C THERMTRIP" figure is platform knowledge, not on-box evidence.
3. **Heat attribution is circumstantial.** nsfw-classifier flagged prime burner from: all-boot presence + post-boot snapshots (80%→167% CPU) + ensemble design. I did NOT pull pre-crash per-process CPU/PSI (node_exporter/SigNoz, 23:00→00:40 window) to prove it was THE burner during the death spiral. crm-server/builds/crush are unexonerated.
4. **pstore leg has an unverified premise.** "No panic because pstore empty" assumes the EFI pstore backend works on this firmware — never tested. If broken, a real panic would also leave nothing.

## c) NOT STARTED

1. Whether the existing **"CPU Thermal Ceiling (>=95°C sustained 30m)" SigNoz rule actually fired** during the 6.5h thermal ride (rule exists; firing state unchecked — one of the biggest open questions: did the observability layer see the death spiral and just watch?).
2. **pstore EFI backend functionality test.**
3. **Fixes:** thermal-guard hysteresis rework, escalation/shed rung, nsfw-classifier resource caps, build-admission enforcement.
4. **Full evidence pulls for prior crash boots** (-5, -7) — only the throttle census was run.
5. **Physical inspection** (fans/heatsink contact/paste) — owner-gated, not queued at authoring time (fixed in §f).

## d) TOTALLY FUCKED UP (session self-critique)

1. **First-turn answer overstated certainty.** I wrote "THERMTRIP ~100°C" and a "no panic" chain built on an unverified pstore backend and unread trip points. Correct form: "thermal power cut is the best-supported hypothesis; trip point and pstore health unverified." Per this repo's own close-out rule — *assert WHICH question your evidence answers* — my evidence answered "not software"; I phrased it as "firmware thermal trip confirmed".
2. **Burner attribution generalized from a snapshot.** A 2-3 min post-boot `ps` sample became "the heat driver" narrative. Directionally supported now (167% at 15 min), but at answer time it was one data point.
3. **Walked away from the gate-blocking commit** after ~3 min of lock contention with no watcher, no retry loop, no in-file pending note. The §15 blocking state was left silent — exactly the "silently co-verify / silently abandon" pattern the multi-agent discipline warns about.
4. **Anomalies scrolled past in turn 1:** the `flm-real` GPF in `libqwen2_npu.so` (kernel traps line, 19:06 — a real userspace fault signal), and the **truncated journal file** (`system@00065dd5ffec988d-….journal~ is truncated, ignoring file` — possible crash-boundary evidence loss). Neither flagged in the first answer; the GPF never would have surfaced without the evidence pull.
5. **Repo's own alerting story unchecked while answering "why did we crash".** The `cpu-thermal-ceiling` rule (which names this exact class) was one grep away during diagnosis; I only ran it during this review turn.

## e) WHAT WE SHOULD IMPROVE

**Session-level (me):**
- Verify the mechanism's constants before naming the mechanism (trip points, pstore health).
- Attribute load from pre-crash metrics, not post-boot snapshots.
- Never leave gate-blocking artifacts uncommitted without a durable retry (background watcher or in-file note).
- Flag every anomaly noticed in passing — GPFs and truncated journals are signals, not noise.

**System-level (the box):**
1. **The thermal guard is an oscillating band-aid on a dissipation deficit.** 60% freq cap demonstrably cannot hold the ceiling; restore hysteresis re-arms the spiral within 2 min. It needs a *shed-load* escalation (stop sacrifice units, like memory-emergency-guard does) when sustained ≥95°C — throttling alone fights physics with a percentage.
2. **Heavy builds bypass workload admission.** Dev-shell `go build -c=32` / cargo `cc1plus -c=32` are the dominant heat source tonight and are not wrapped by `workload-admission.nix` — admission control has a hole exactly where the heat comes from.
3. **nsfw-classifier `--all` (15-model ROCm ensemble) is a standing thermal weapon** on a package that shares CPU+GPU thermal budget. Needs caps or a smaller default ensemble (owner decision).
4. **Alerts that watch but don't act.** If `cpu-thermal-ceiling` fired during 6h at 95-99°C and nothing shed load, the observability layer is a spectator to the death spiral (unverified — see §c.1).
5. **Evidence-commit flow is fragile under lock contention** (§15 gate + hanging pma amends).

## f) Next things (session-derived, ≤50 — brainstorm beyond the harvested subset)

**Harvested to TODO_LIST.md + domain libraries (see harvest note at bottom):**

1. Commit `docs/status/tasks/2026-10-17_22-46_boot-ee085387-evidence-pull.md` + re-run `scripts/pre-vacuum-evidence-gate.sh` — **deploy-blocking**. [ready|stability]
2. Verify whether SigNoz `cpu-thermal-ceiling` rule FIRED during ee085387 18:13→00:40; if not, root-cause the rule/metric gap (rule exists since T12 2026-10-10). [ready|monitoring]
3. thermal-pstate-guard: add escalation rung — sustained ≥95°C for >10 min → shed load (stop sacrifice units, memory-guard pattern), not just 60% cap. [ready|stability]
4. thermal-pstate-guard: fix restore hysteresis — require ≥5 min continuously ≤80°C before restoring active; current 12-cool-tick restore re-enters within 2 min at 98°C (21:41:59→21:42:19). [ready|stability]
5. Pull pre-crash per-process CPU/PSI from SigNoz/node_exporter for 23:00→00:40 to prove/disprove nsfw-classifier as THE burner (attribution correction duty). [ready|monitoring]
6. Alert on stuck-throttled state: "THERMAL THROTTLE ENTER without EXIT for >60 min" (exactly tonight's 23:21→death spiral). [ready|monitoring]
7. flm-real `libqwen2_npu.so` GPF (19:06, boot ee085387): reproduce, report/pin away NPU path. [ready|stability]
8. Investigate truncated journal file at crash boundary (`system@00065dd5ffec988d-….journal~`) — is crash-boundary evidence being lost? [ready|monitoring]
9. Identify the full-disk readers behind memory-guard trip #3445 (I/O PSI 60%, disk 100%, MemAvailable 72.6% — crash #3 class). [ready|stability]
10. Wrap dev-shell builds (go/cargo) in heavy-job admission — tonight's load-111 came from three unwrapped parallel builds. [ready|stability]

**Deliberately NOT harvested (owner-gated / decision / lower-value — recorded here per report rules):**

11. [decision:user] nsfw-classifier: reduce `--all` 15-model ensemble to core set and/or add CPUQuota/CPUWeight to the unit.
12. [blocked:user] Physical inspection: fans/heatsink contact/paste/chassis airflow after chronic 95-99°C weeks.
13. [blocked:user] Owner fact: was the 00:42 reboot manual (power button) or firmware-automatic? Discriminates controlled-restart vs pure cold cut.
14. [ready|stability] Read actual THERMTRIP threshold from ACPI DSDT/community docs; document beside the guard thresholds.
15. [ready|stability] pstore EFI backend functionality test (proves/disproves the "no panic" leg retroactively).
16. [ready|monitoring] Thermal-aware admission: refuse/lower MAX_CONCURRENT heavy jobs while k10temp > 85°C.
17. [ready|monitoring] DEEP THROTTLE oscillation detector (ENTER events/hour > N → alert).
18. [ready|monitoring] Post-boot thermal baseline: k10temp > 80°C within 5 min of boot → alert.
19. [ready|pipeline] boot-evidence-pull: durable commit retry under lock contention (watcher or daemon-side confirmation).
20. [ready|pipeline] Add thermal census (throttle ENTER count, max k10temp) to post-deploy-check.
21. [watch] boots -5/-7 (crash-marked Oct 11/15): full evidence pulls for class-series record.
22. [watch] I/O PSI + thermal co-occurrence audit: which units feed both axes (clickhouse merges? nsfw history-db writes?).
23. [decision:user] Consider capping parallel crush sessions (metric exists: `system_crush_sessions` >6 alert) given their standing CPU contribution.
24. [ready|stability] hermes 429-rate-limit storm (zai glm-5.3-flash, visible at 00:40:40) — backoff review; contributes log noise during incidents.
25. [watch] cv health-check `overall_status=warn` (42 checks, 00:40:39, pre-crash) — enumerate which check warned; may corroborate the degradation window.

## g) Questions for the owner (cannot figure out myself)

1. **Physical:** after weeks of chronic 95-99°C, is opening the chassis acceptable (fans/heatsink contact/paste)? Only you can do/authorize this — software cannot fix a dissipation deficit.
2. **Product tradeoff:** is the nsfw-classifier 15-model `--all` ensemble worth its thermal cost on this box, or may we cut to a core ensemble + CPUQuota? (Accuracy-vs-uptime call.)
3. **Fact only you know:** was the 00:42 reboot you pressing power, or did it come back on its own? (No pre-boot EC state is observable from here.)

---

**Harvest note:** items 1-10 landed in `TODO_LIST.md` (queue one-liners) + `docs/todo/stability.md` / `docs/todo/monitoring.md` (domain rows) at authoring time. Items 11-25 deliberately not harvested: user-gated, decisions, or watch-class — they live here until owner acts or a later harvest promotes them.

**Standing observations for whoever picks this up:** git `index.lock` was held by parallel session pid 101682's pma amend for >15 min (LLM call failing → hang) — the evidence file commit and this report ride the auto-commit daemon unless committed manually. Load 111 at report time: three parallel builds + nsfw ensemble; expect the thermal guard to be busy tonight.
