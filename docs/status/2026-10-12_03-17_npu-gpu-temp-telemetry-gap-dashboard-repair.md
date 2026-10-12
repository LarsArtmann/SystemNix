# Status: NPU/GPU Temperature Telemetry Gap — Diagnosis, Dashboard Repair, and Session Self-Review

**Authored:** 2026-10-12 ~03:17-03:30 CEST
**Session scope:** single intake question ("Why is SigNoz missing temp for NPU? or GPU") carried through diagnosis → on-sight fixes → verification → close-out + self-review. Per operator demand: NO research beyond this session's run and what it directly noticed. Point-in-time snapshot — expect staleness.

---

## Executive summary

The intake question had two different answers hiding in it:

1. **NPU temp is missing because the data does not exist at the kernel interface.** The in-tree amdxdna driver (kernel 7.2.9) registers **no hwmon device** — verified three ways (sysfs: `accel0` at `0000:c7:00.1` has no hwmon child and the 6-chip hwmon list is exhaustive; `/proc/kallsyms`: zero `amdxdna_hwmon*` symbols; SigNoz: zero NPU-flavored series). Upstream `amd/xdna-driver` **does** have hwmon (temp labeled `NPU_temperature` + power, `amdxdna_sensors.c`), but only registers it when amd_pmf sensor support answers. Nothing monitoring-side can fix this; it is a kernel-side gap, now filed as an owner decision.
2. **GPU temp was never missing from the database — the dashboard was blind.** The 2026-10-10 bus renumber (GPU chip `c5:00_0` → `c6:00_0`) stranded the gpu dashboard's pinned selector `.*c5:00_0` at 0 series. The alert rule was fixed that same day; **the dashboard was not** — a two-surface half-fix that left both GPU temp panels empty in the UI for ~2 days. Repair landed this session: in-repo AND live (direct PUT convergence, byte-compared).

Bonus finding: the documented ClickHouse fallback metric `ClickHouseAsyncMetrics_Temperature_amdgpu_edge` **no longer exists** (0 series across a full 24h range query; CH now emits 8 bare `Temperature` series that are thermal-zone-derived). The "CH async metric name is stable" doctrine — baked into the alert comment and the dashboard description on 2026-10-10 — was already false when written. The dead OR-operand is retired from the alert; the dashboard is hwmon-only.

Both thermal alert rules are **live and armed** (verified via the rules API: `GPU Thermal` ✓, `CPU Thermal Ceiling` ✓, 35 rules total).

---

## Session timeline (with evidence)

| # | Step | Evidence |
| - | ---- | -------- |
| 1 | Intake routed per AGENTS.md knowledge table → `docs/agents/monitoring.md` read | monitoring.md hwmon fingerprint table (live-derived 2026-10-10) showed 6 chips, NO NPU row |
| 2 | Live hwmon triage on evo-x2 | `hwmon0/1` = nvme, `hwmon2` = amdgpu (one temp sensor, `edge` label), `hwmon3` = k10temp, `hwmon4` = acpitz, `hwmon5` = mt7925_phy0 — **exhaustive, no NPU chip** |
| 3 | NPU device located | `accel0` → `/sys/devices/pci0000:00/0000:00:08.2/0000:c7:00.1`; no hwmon anywhere under it |
| 4 | In-tree driver capability check | `grep -c amdxdna_hwmon /proc/kallsyms` → **0**; amd_pmf carries only SPS symbols, no sensor-bridge symbols |
| 5 | Upstream capability check | `amd/xdna-driver` `amdxdna_sensors.c` (sourcegraph): registers `HWMON_T_INPUT|HWMON_T_LABEL` + power; label literal `NPU_temperature`; `amdxdna_hwmon_init` bails with *"No HWMON support due to missing PMF sensor support"* |
| 6 | SigNoz live inventory | `max by (chip, sensor) (node_hwmon_temp_celsius)` → 11 series incl. GPU chip `0000:00:08_1_0000:c6:00_0` @ 52°C; `{__name__=~"(?i).*(npu|xdna).*"}` → only substring false-positives ("I**npu**t"), zero real NPU metrics |
| 7 | Dashboard post-mortem | `dashboards/gpu.json` lines 109 + 256 still `chip=~".*c5:00_0"` → matches nothing (GPU moved to c6; nvme chips are `nvme_nvmeN`-labeled, so no accidental match either) → **both panels empty in the UI** |
| 8 | CH fallback death certificate | exact-name instant query: 0 series; **full 24h range query: 0 series**; regex sweep finds 8 fresh (0.0 min ago) bare `ClickHouseAsyncMetrics_Temperature` series — values (99/99/53/99.25/42/56.85/56.85/63.85) map onto thermal zones, not hwmon chips |
| 9 | Fixes applied | `gpu.json` both panels → `.*:c[0-9a-f]+:00_0` hwmon-only + truthful descriptions; `_signoz-alerts.nix` dead operand retired + evidence comment; `monitoring.md` NPU-telemetry + CH-death bullets; `ai-stack.md` `[decision]` row |
| 10 | Verification gates | `signoz-query-lint` PASS; full `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` PASS; scoped `nix fmt` → 0 changed; live dashboard PUT (`systemnix-gpu`, id `01a00c44-76b4-77f7-951f-0ee51de11490`) → **CONVERGED** (sorted-spec byte-compare); both repaired panel PromQLs live-verified: **1 series @ 52°C each** |
| 11 | Close-out sweep (status demand) | repo-wide grep for other `ClickHouseAsyncMetrics_Temperature`/`amdgpu_edge` consumers → **none** (only the two intentional doc references); live rules API check; guard-trip state query; 2 harvest rows landed; `amd-npu.nix` stale kernel comment fixed on sight |

---

## Self-review (brutally honest)

### What did I forget?

1. **The content-pin before the first write.** The multi-agent discipline says pin `git rev-parse HEAD` + diff-review before every write in a shared tree; I ran `git status` at conversation start but never pinned the rev. No conflict materialized — that is luck, not compliance.
2. **The dead-metric consumer sweep should have been part of the ORIGINAL change**, not a close-out item. I edited two surfaces (alert + dashboard) and only at report time grepped the whole repo for other consumers of the dead CH name. Result was clean, but the verification ORDER was wrong — the same two-surface half-fix class I ended up criticizing.
3. **One wasted tool call** — my first `multiedit` on gpu.json carried identical old/new strings (sloppy paste). Harmless, but it is exactly the kind of round-trip discipline the workflow demands.
4. **`amd-npu.nix`'s stale kernel comment** ("6.19.8 current" on a 7.2.9 box) sat right next to the module I was diagnosing and I did not fix it on sight during the NPU work — only during the status cycle.

### What is stupid that we do anyway (observed this session)

1. **Docs assert properties that no check guards.** "ClickHouse's async metric name (amdgpu_edge) is stable" was written into two surfaces as a resilience doctrine — and the metric was already gone/unstable. No lint, no zero-series sweep, no canary guarded that claim.
2. **Two-surface half-fixes.** The 2026-10-10 session fixed the alert rule and left the dashboard stranded on the same dead selector — for two days the UI showed nothing while alerting worked, and nobody noticed because nothing watches DASHBOARD liveness (the provisioner's convergence verifier checks the name SET, not per-panel data).
3. **Hardware-keyed labels in prose and selectors** keep breaking (this is at least the second renumber on this box). The renumber-tolerant regex helps selectors, but descriptions/comments/docs still name concrete chip labels and will silently rot at the next shift.

### What could I have done better?

1. **State the convergence boundary upfront.** I converged the dashboard live via the documented direct-PUT path but left the alert rule deploy-gated (functionally identical query since the operand contributes nothing — but "file fixed, live not" is a partial state I should have named in the first close-out, not at report time).
2. **Probe before believing doctrine.** My session initially trusted the 2026-10-10 comment ("CH fallback kept the rule alive / name is stable") until the range-query falsified it. A one-command range query was available all along.
3. **Quote enforcement-side telemetry in the first pass.** The `thermal_pstate_guard_trips_total` check (72 lifetime, **0 in 2h** while Tctl held ~99°C at load 42.6) came at report time — it contextualizes the 99°C flag and should have shipped with it.

### What could I still improve?

See §e — most of it is process (verification ordering, premise-checking decision rows, guarded doc claims).

### Did I lie?

No. Every load-bearing claim carries a live command + output in the appendix. One claim is explicitly inference, not verification: *"CH now emits bare Temperature series from thermal zones"* — the mechanism is inferred from value mapping (98/99/52/42 ↔ zone values) and freshness; what is VERIFIED is the name's absence (24h range, 0 series) and the 8 fresh bare-name series.

---

## a) FULLY DONE

1. **NPU root-cause, triple-verified** — no hwmon on `accel0` (`0000:c7:00.1`), zero `amdxdna_hwmon*` kallsyms symbols (in-tree 7.2.9 predates hwmon), zero NPU series in SigNoz. Upstream has the hwmon, gated on amd_pmf sensors. It is a kernel-side gap, not a SigNoz/collector misconfiguration.
2. **GPU dashboard repair — in-repo AND live** — both temp panels re-keyed to the renumber-tolerant selector; live `systemnix-gpu` dashboard PUT-converged with byte-compare; both panel PromQLs return 1 series @ 52°C against the live API.
3. **Dead CH fallback retired** — `Temperature_amdgpu_edge` proven absent (24h range, 0 series); OR-operand dropped from the GPU Thermal rule query; comment rewritten with the falsification evidence. Repo-wide sweep confirms no other consumers existed.
4. **Docs brought current** — `monitoring.md` gained the NPU-telemetry bullet (with the fix path) and the CH-metric-death bullet (explicitly superseding the 2026-10-10 "stable CH name" half-claim); `gpu.json` descriptions rewritten to describe what actually exists.
5. **TODO system fed** — `ai-stack.md`: `[decision]` NPU-telemetry row + `[ready]` premise-check row; `monitoring.md`: `[ready]` dashboard selector-freshness guard row.
6. **On-sight fix** — `amd-npu.nix` stale kernel comment corrected + NPU-hwmon note added.
7. **All gates green** — `signoz-query-lint`, full evo-x2 eval, scoped `nix fmt` (0 changed), pre-commit legs on the pathspec commit.
8. **Live thermal alerting state verified** — GPU Thermal + CPU Thermal Ceiling rules both live (rules API, 35 rules total).

## b) PARTIALLY DONE

1. **Live GPU Thermal rule still carries the dead CH operand** — the file is fixed; the live instance gets it at the next deploy (provisioner PUTs in place, preserves ruleId, no fake resolve/fire). Functionally identical today (empty operand).
2. **NPU telemetry decision** — the row is filed and the premise-check row exists, but the decision itself (out-of-tree driver vs wait) is unmade and the premise (upstream builds vs 7.2.9) is unverified.
3. **Thermal context at close-out** — reading + armed rules verified; guard-trip correlation queried; but the 99°C observation is NOT investigated as an incident (deliberately — see §g2) and the PPT power probe returned 0 series (my chip-label guess was wrong; not pursued — out of scope).
4. **Shared-tree attribution** — daemon commit `e40c383a` mixed my 3 files with a foreign session's `TODO_LIST.md` edit + new status report; flagged, not amended (per the mixed-commit policy), so history carries a heuristic message over 2 foreign files.

## c) NOT STARTED

1. The NPU telemetry DECISION itself (out-of-tree xdna-driver via `nix-amd-npu` vs kernel wait) — owner's call, row filed.
2. NPU temp/power ingestion work — structurally blocked until kernel hwmon exists.
3. Dashboard selector-freshness guard implementation — row filed, zero code.
4. xdna-driver build-vs-7.2.9 premise verification — row filed, zero research done.
5. Anything from the parallel session (its `selftests.nix` edit is in-flight in the tree — untouched, per shared-tree rules).

## d) TOTALLY FUCKED UP

Nothing I shipped this session broke. But the session surfaced four things that genuinely are:

1. **The GPU dashboard was blind for ~2 days** (2026-10-10 renumber → this session): both temp panels returned nothing in the UI while the alert worked — the era's two-surface half-fix. Inherited, found, closed; the class remains unguarded (see §e2).
2. **The resilience doctrine was already dead when documented.** Two surfaces taught "one source covers the other's blind spot" while the second source had silently vanished (≥24h, unbounded backwards — 24h is just how far I measured). Monitoring redundancy that exists only in comments is worse than no redundancy: it manufactures false confidence.
3. **The NPU has been thermally invisible for the box's entire life** — the ai-stack's own accelerator (running flm inference) has never had a temperature signal anywhere in the stack. Now articulated and decision-filed; not fixed (kernel-side).
4. **History attribution noise**: `e40c383a` is a heuristic daemon commit carrying 3 of my files plus 2 foreign files; fixing it means rebase surgery on a live shared tree — deliberately not done.

## e) WHAT WE SHOULD IMPROVE

1. **Verification ordering: sweep consumers in the SAME change.** When a metric-name/selector dies, grep ALL consumers (rules, dashboards, docs, scripts) before declaring the fix done — not at wrap-up.
2. **Guard doc claims with checks, or don't write them.** "Stable", "always", "never" in comments/descriptions about external systems (CH naming, hwmon labels, upstream APIs) need a canary (the existing `[ready]` zero-series-sweep row is exactly this class — my CH-death finding is its poster child) or softer wording.
3. **Premise-check decision rows before they reach the owner** (the AGENTS.md rule applied at queue-authoring time): my `[decision]` row presupposes the out-of-tree driver is a viable option on 7.2.9 — unverified. That is why the companion `[ready]` premise-check row exists; the standard should be: verified before asked.
4. **Convergence-boundary statements.** Any fix that lands in-file but not live should SAY so in the same breath ("live at next deploy via ruleId-preserving PUT"), so no one mistakes the file diff for system state.
5. **Content-pin discipline in shared trees** — rev-pin before the FIRST write, not just `git status`. Luck is not a process.
6. **Per-panel dashboard liveness** — the provisioner's convergence assertion counts dashboards; it cannot see that a panel's query returns nothing. That gap is what let the 2-day blindness happen.

## f) Up to 50 things we should get done next

Grounded ONLY in this session + rows directly noticed while in the todo libraries. Section A items are session-derived (harvest disposition noted per the self-harvest mandate); Section B is pointers to EXISTING tracked rows noticed in passing — listed once, not duplicated into new rows.

### A. Session-derived (new)

1. **Premise-check the NPU-telemetry decision row** — verify upstream amd/xdna-driver builds against kernel 7.2.9 headers and inspect the `nix-amd-npu` input's kernel-module wiring, so both decision options are real and costed. **[LANDED: `ai-stack.md` `[ready]`]**
2. **Dashboard selector-freshness guard** — lint/provisioner assertion that hardware-keyed selectors (`chip=~`, PCI-address shapes) are renumber-tolerant, or that every panel query returns ≥1 series before "OK provisioned". **[LANDED: `monitoring.md` `[ready]`]**
3. **NPU temp/power telemetry: chase kernel-side hwmon or accept blind** — the decision itself (out-of-tree driver vs wait for in-tree PMF support). **[LANDED: `ai-stack.md` `[decision]` — owner]**
4. **Deploy the alert-file change** (dead-operand removal + comment). **[deliberately NOT harvested: rides any next deploy; provisioner converges in-place preserving ruleId; a dedicated row would be queue noise]**
5. **Sustained-Tctl-99°C with 0 guard trips in 2h** — determine whether boost-at-Tjmax-without-guard-trips is expected `thermal-pstate-guard` semantics or a gap (needs the guard's trip-condition semantics read first; alerting side already owned by the live CPU Thermal Ceiling rule). **[deliberately NOT harvested: premise not verified; queueing an unverified stability row violates the spot-verify rule — §g2 asks the owner whether to investigate at all]**
6. **CPU Thermal Ceiling Discord-delivery check** — rule is armed and the current pattern (≥95°C sustained 30m) should have fired it if held; successful notifies are journal-silent, so delivery is only owner-visible. **[deliberately NOT harvested: owner-side verification — §g3]**
7. **ROADMAP fuel: provisioner per-panel liveness assertion** (superset of item 2 — daily probe that every panel of every owned dashboard returns ≥1 series). **[not harvested: overlaps item 2's smaller scope; ROADMAP belongs in ROADMAP.md]**
8. **ROADMAP fuel: NPU temp/power panels + alert once kernel hwmon exists** (contingent on item 3; node_exporter picks it up automatically — the work is dashboard/rule wiring only). **[not harvested: contingent on an unmade decision]**

### B. Existing tracked rows noticed this session (not re-filed — from `docs/todo/monitoring.md`)

9. Gatus "Memory Pressure CRITICAL" PSI rule likely reads the wrong PSI file `[ready]`
10. `check_user_service` in scheduled-tasks.nix defined-but-never-called `[ready]`
11. Gatus UI "Logs" button → `logs.home.lan` (Dozzle button removed with Docker) `[ready]`
12. CI green on the Docker-removal stub cleanup — VM tests never RUN yet `[watch]`
13. Textfile-collector exit-0/empty-value class audit (psql `ON_ERROR_STOP` proven instance) `[ready]`
14. Textfile-collector fixed-name `.tmp` audit + stale btrfs-compression tmp `[ready]`
15. k10temp thermal Gatus check + fan-telemetry gap (sustained-Tctl paging + no fan RPM anywhere) `[ready]`
16. flm crash-trigger composite alert (PMA 30s-band fallbacks × flm coredumps) `[ready]`
17. Zone-6 guard trip-RATE alert (trips/hour sustained) `[ready]`
18. system-health-metrics worst-case section sum (≈500s) exceeds 180s unit ceiling — structural `[ready]`
19. `scripts/backup-catchup-report.sh` (report half; metric half landed 2026-09-23) `[ready]`
20. btrbk receive-freshness + pool-snapshot-freshness gauges `[ready]`
21. Deferred-scrub observability + scrub-guard VM test `[ready]`
22. Zero-series sweep automation + provisioner-Result assertion generalization — **my CH-metric-death finding is exactly this class** `[ready]`
23. Browser-test the SigNoz UI + eyeball the 5 `systemnix-*` dashboards (API-verified only, never rendered) `[blocked:user]`
24. Extend user-unit monitoring to remaining blind spots (flm smoke PSI-skip, noise convention, dnsblockd profiling, hermes state-check, discordsync gap, imagetoraster segfault) `[ready]`
25. Commit the dashboard generator + eval-time dashboard JSON lint `[ready]`
26. Test-fire "Telemetry Export Failures" → Discord in a maintenance window `[ready]`
27. SigNoz migrator-gap guard (the 1010 squash-gap class) `[ready]`
28. `file_storage` cursor persistence for the journald receiver `[ready]`
29. Caddy access.log ingestion + log-silence anomaly alert `[ready]`
30. buildcache-gc observability (last-success timestamp + prune-ok + Discord) `[ready]`
31. Declarative health-check (`criticalSystemServices` hand-maintained) `[ready]`
32. System-health collector hardening (timeouts, NRestarts, MemoryMax headroom) `[ready]`

### B (cont.) — from `docs/todo/ai-stack.md`

33. MiniMax quota decision (carried ×5) `[decision]`
34. flm upstream release watch — v1.0.3+ SIGABRT-class recurrence `[watch]`
35. llama-rag monitoring depth (functional probes + GPU-util metric + alert) `[watch]`
36. llama-rag re-enable soak execution (harness shipped, root+owner-gated) `[blocked:user]`
37. FastFlowLM staged go-live v1.0.2 → upstream (no crash-class fix in release notes; bump is accuracy/features only) `[decision]`
38. llama-vlm live verification + soak (ports listening, never inference-tested) `[watch]`

*(8 new + 30 pointers = 38 items; the user's "up to 50" is satisfied without padding — the remaining items the session did NOT notice stay unlisted on purpose.)*

## g) Three questions I cannot figure out myself

1. **NPU telemetry: build the out-of-tree `xdna-driver` (hwmon-capable) now — accepting a per-kernel-bump maintenance tax on an APU-centric box — or wait for in-tree PMF-wired sensors?** I can verify buildability (the `[ready]` row), but the maintenance appetite is yours. Until decided, the NPU stays thermally invisible.
2. **The box held Tctl ~99°C for 15+ min at 03:17 under load 42.6 with ZERO guard trips in 2h.** Is heavy-compile-at-ceiling expected overnight behavior I should leave to the armed CPU Thermal Ceiling rule, or do you want an incident-style look at what is loading the box and why the pstate guard never trips in this pattern?
3. **Did the CPU Thermal Ceiling (≥95°C sustained 30m) page actually reach your Discord in the last hours?** The rule is live and armed (API-verified) and the trigger pattern was present, but successful Discord notifies are journal-silent — delivery health is only visible on your side.

---

## Harvest disposition ledger (per the AGENTS.md self-harvest mandate)

| §f item | Disposition |
| ------- | ----------- |
| 1 (xdna premise-check) | LANDED: `docs/todo/ai-stack.md` `[ready]` |
| 2 (selector-freshness guard) | LANDED: `docs/todo/monitoring.md` `[ready]` |
| 3 (NPU decision) | LANDED (during session): `docs/todo/ai-stack.md` `[decision]` |
| 4 (deploy rides next deploy) | deliberately NOT harvested (rationale inline above) |
| 5 (99°C/0-trips semantics) | deliberately NOT harvested (premise unverified; owner question §g2 gates) |
| 6 (Discord delivery) | deliberately NOT harvested (owner-side only; §g3) |
| 7, 8 (roadmap fuel) | deliberately NOT harvested into todo libraries (ROADMAP-class, contingent on unmade decision) |
| B items 9-38 | already tracked in their libraries — intentionally NOT duplicated |

No `TODO_LIST.md` queue rows were added this session: every session-derived item is `[ready]`-in-library or non-agent-actionable, and the tq pool harvests only the queue — the two landed `[ready]` rows are eligible for queue promotion at the next harvest pass.

## Evidence appendix (commands → key outputs)

```
hostname; ls /sys/class/hwmon/                       → evo-x2; hwmon0..5 (6 chips, exhaustive)
for h in /sys/class/hwmon/hwmon*; ...                → nvme, nvme, amdgpu(temp1 only, label "edge"),
                                                       k10temp, acpitz, mt7925_phy0 — NO NPU chip
readlink -f /sys/class/accel/accel0/device           → .../0000:00:08.2/0000:c7:00.1 (no hwmon child)
grep -c amdxdna_hwmon /proc/kallsyms                 → 0
sourcegraph amd/xdna-driver amdxdna_sensors.c        → HWMON_T_INPUT|LABEL + power; "No HWMON support
                                                       due to missing PMF sensor support" bail-out
SigNoz instant: max by (chip,sensor)(node_hwmon_…)   → 11 series; GPU chip 0000:00:08_1_0000:c6:00_0 @ 52
SigNoz 24h range: ClickHouseAsyncMetrics_…amdgpu_edge→ 0 series (name dead)
SigNoz 24h range: ClickHouseAsyncMetrics_Temperature.*→ 8 series, bare name, fresh (0.0 min)
nix build .#checks.x86_64-linux.signoz-query-lint    → PASS
nix eval .#nixosConfigurations.evo-x2…toplevel.drvPath → PASS (drv emitted)
PUT /api/v2/dashboards/01a00c44-… (systemnix-gpu)    → HTTP 200; post-PUT sorted-spec byte-compare CONVERGED
repaired panel PromQLs against live API              → 1 series @ 52°C each
rules API                                            → GPU Thermal ✓, CPU Thermal Ceiling ✓, 35 rules
thermal_pstate_guard_trips_total / increase[2h]      → 72 lifetime / 0 in 2h (at Tctl 15m-max 99.125, load1 42.62)
grep -rn 'ClickHouseAsyncMetrics_Temperature|amdgpu_edge'
  modules/ platforms/ docs/ scripts/ tests/          → only the 2 intentional doc references
nix fmt <touched .nix + .json>                       → "formatted 2 files (0 changed)"
```

*Report ends. Point-in-time snapshot — annotate, never rewrite (docs-health ANNOTATE mode).*
