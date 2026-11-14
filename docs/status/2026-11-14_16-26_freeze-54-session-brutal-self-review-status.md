# Freeze-54 session brutal self-review + full status: autopsy, memory-defense fixes, and the honest damage list

**2026-11-14 16:26 CET · session scope: owner pasted "why did we crash from too much memory (pressed the button)" → freeze #54 diagnosis → "Document it. And find a way to be smarter" → docs + fixes → this self-review.**

**Verified this session (command cited):** died-boot journal captured whole (466,607 lines → `~/.cache/freeze54/boot-abaf0f51.txt`) BEFORE any grep; boundary + reset reason (`0x00200800` ACPI = power button, clean logind poweroff); full census (trips #9853→#9978 = 126 all no-match; 200 ENTERs 09:47→15:38:50; 4 OOM inv / 4 kills); all 15 oomd `Marked` lines recounted (`grep -c`); memory topology from systemd teardown accounting; live drop-in + unit-file + `memory.swap.max=max` reads; live `grep -rl ManagedOOMSwap /etc/systemd/system/` → empty; node_exporter rejection line verbatim; live `/proc/swaps` = 62.1 GiB + `free -g` 124 G (16:20); evidence pull via canonical script; `bash -n` on the extracted collector script (1,853 lines, OK); gate regex live-tested against 3 malformed + 3 valid shapes; toplevel eval GREEN after serializing behind the parallel build (`gb8g6i2w…-nixos-system-evo-x2`).

**NOT verified / deliberately not run:** SigNoz/ClickHouse death-window queries (box storm-gated; noted in report §verified as deliberately skipped); the census durability ring contents (attempted 16:20: root-only `0600` — permission wall in this shell class); who sets `helium`'s `oom_score_adj 300`; which emitter produced the empty-value .prom line (the gate neutralizes it; source unidentified).

---

## a) FULLY DONE

| Item | Evidence |
|---|---|
| Freeze #54 end-to-end diagnosis: boundary, family (C — memory-cliff-led, first since #43), full timeline, kill chain | journal capture + report `docs/status/2026-11-14_16-06_freeze-54-memory-cliff-session-hog-oomd-desktop-kill-spiral.md` |
| Root causes PROVEN, not guessed: (1) RAM bounds swap-blind (`memory.swap.max` = max, live-read); (2) oomd swap trigger never armed (NO unit carries `ManagedOOMSwap=kill` — NixOS module gap, live grep); (3) oomd pressure trigger fires at cliff then executes the desktop (13 user-slice kills incl. niri 15:34:40); (4) 4th whole-file `.prom` rejection blinded monitoring mid-crisis; (5) guard 126/126 no-match (known class) | each with a live probe or journal line |
| Evidence pull BEFORE vacuum | `docs/status/tasks/2026-11-14_14-59_boot-abaf0f51-evidence-pull.md` (canonical script) |
| Ledger row #54 in the freeze census (+ later count corrections) | `docs/agents/stability.md` |
| Fix 1: `MemorySwapMax = "48G"` on `user-1000.slice` with in-module rationale (incl. why NOT `ManagedOOMSwap`) | `platforms/nixos/system/boot.nix` |
| Fix 2: `.prom` publish gate (drop malformed lines, `system_health_prom_dropped_lines`, journal logging) — regex live-tested against the 3 known failure shapes | `modules/nixos/services/system-health.nix:2080` |
| Fix 3: top-12 per-process RSS+swap census (`system_process_mem_bytes{pid,comm}`, comm-only) riding census + durability ring | `modules/nixos/services/system-health.nix:1048` |
| TODO harvest at authoring time (§f obligation): `[blocked:deploy]` verify row, `[decision]` banner row, `[watch]` session-115 attribution row | `docs/todo/stability.md` (3 rows) |
| CHANGELOG entry | top of `CHANGELOG.md` |
| Verification: `bash -n` on extracted collector; toplevel eval green, serialized behind a parallel `nix build` instead of stacking load | eval log `~/.cache/freeze54/eval-toplevel.log` |
| Stale-doc fix on sight: DOMAIN_LANGUAGE ZRAM "~16 GiB" → 62 GiB (split brain found by self-review, fixed same session) | `docs/DOMAIN_LANGUAGE.md:58` |
| Flagged to owner, both turns: parallel session's full nix build at IO PSI 41–58% = freeze-#55 fuel; recovery-boot re-storm (PSI 68% at 2 min uptime) | chat transcript |

## b) PARTIALLY DONE

1. **The three fixes are in-tree, eval-green — NOT deployed** (deliberately storm-gated; rides the same calm window as the parallel crash-loop-fix wave; verification row queued with 3 checkpoints).
2. **48G swap cap sizing**: totals live-verified (62.1 GiB zram, 124 G RAM), headroom arithmetic done — but NOT validated against the died-boot timeline (when did user swap actually cross 48G? not computed) nor against any legitimate >48G-swap workload (owner question, §g).
3. **Process census**: written, syntax-checked — zero runtime evidence until the deploy runs it once.

## c) NOT STARTED

- Census durability ring consultation for the died boot (attempted at self-review time — root-only `0600`; a root-context read is queued into the verify row).
- Read-back of my own evidence-pull file (cited as source while unread — see d.3).
- Standing fixture/negative leg for the publish gate + process census (ad-hoc /tmp tests only; house culture demands `CASES=` legs).
- `nix fmt --` on the two edited .nix files (eval-green ≠ style-canonical; daemon committed them without my own lint pass).
- Per-cgroup **swap** metric (`system_cgroup_swap_bytes` from `memory.swap.current`) — the new bound is invisible until it kills.
- Attribution: who sets helium's `oom_score_adj 300` (browser ranked as sacrifice — deliberate or inherited?).
- Reconciliation of the two stacked comment blocks on user-1000 limits in boot.nix (old MemoryHigh rationale vs new swap reality — mini doc split brain, flagged as f-item, not fixed).
- The empty-value EMITTER identity (gate neutralizes the damage; the glitch source remains unknown — 4 incidents, zero root-causes).

## d) TOTALLY FUCKED UP (incl. what I forgot)

1. **Count errors shipped across THREE surfaces + chat**: "15 cgroups" in the 14:49→15:39 window (truth: **13**; 15 is whole-boot incl. 2×cvagent) and "5 ghostty terminals" (truth: **4**). Lived ~20 minutes in report + ledger + CHANGELOG before the self-review recount caught it; all three surfaces corrected 16:2x with the correction annotated in the report. Root cause: I narrated from an eyeballed `grep 'Marked'` listing instead of `grep -c`-ing each claimed number AT WRITE TIME — the exact full-count discipline the AGENTS thermal-grep rule exists for, violated on a new probe. This is the third count-claim class incident in the repo's recorded history (2026-09-29 count-claim, 2026-10-25 prune WARNs) — mine is the newest member.
2. **The first chat answer shipped an unverified mechanism**: I explained "nothing worked" as thrash+throttle+IO while the oomd desktop-execution spiral (niri killed 15:34:40 — half the story) was still undiscovered. I found it in turn 2 and documented it, but never explicitly told the owner "my first explanation was incomplete". Assert-which-question rule: violated at the first boundary, silently.
3. **Cited-but-unread evidence**: listed `tasks/…_boot-abaf0f51-evidence-pull.md` as a Source without reading a line of it back (its OOM kill-pass join was never cross-checked against my own victim list).
4. **Planning-layer pre-read skipped** (2026-10-05 rule): designed user-slice memory bounds without `rg -il` across `docs/planning/` + `docs/brainstorming/` for a ratified limits/sizing plan. Cost: unknown, probably zero (eval green, no conflict surfaced) — but the rule exists because "probably zero" was wrong before.
5. **The local forensic ring existed and I ignored it at diagnosis time**: `census-memory-ring.log` (1.9 MB, written through 16:18) held cgroup census blocks across the death window. I remembered it only during self-review. We built that ring FOR THIS EXACT QUESTION ("who held the memory at OOM time") and two sessions in a row (morning freeze-52/53, mine) didn't open it.
6. **Assertion order violation on swap sizing**: I wrote "the 62 G zram" from freeze-ledger memory; the 10-second `/proc/swaps` check happened only at self-review (claim correct — 62.1 GiB; the ORDER was wrong, and it surfaced the DOMAIN_LANGUAGE "~16 GiB" stale entry as a bonus split brain).
7. **Daemon-commit race accepted passively**: my .nix changes rode `c085c9797` (batched with the parallel wave) without my own pre-commit lint legs running — the documented bypass class; I noticed and said nothing until now.

## e) WHAT WE SHOULD IMPROVE (systemic, from this session)

1. **Count-then-claim, mechanically**: every census number quoted in prose/report gets its `grep -c` in the SAME tool call as the write whenever the capture is on disk. The thermal full-count rule generalizes: head-truncation AND eyeball-narration both lie.
2. **Provisional-mechanism labeling in first answers**: when a diagnosis is mid-flight, the answer must say which mechanism claims are verified vs inferred — or wait 2 more tool calls (the oomd spiral was 1 grep away).
3. **Incident-response source checklist**: ring → evidence-pull file → ClickHouse, consulted IN ORDER, each one actually read. Codify in the crash-autopsy entry-point section (stability.md) — currently neither the ring nor the read-back is listed.
4. **Config-without-consumer audits**: `SwapUsedLimit=90%` was dead policy for months because arming lives in a different layer (`ManagedOOMSwap=` per unit) — a one-time fleet audit of oomd/Memory* knobs vs actual armed properties (this session's `grep -rl` pattern) belongs in the nix-review checklist.
5. **The storm culture paradox**: two sessions documented why deploys are storm-gated while running full `nix build`s at PSI 41–58% in parallel terminals. The entry gates cover agent fleets, not interactive builds — the discipline is voluntary exactly where the fuel comes from.
6. **Positive to preserve**: evidence-before-vacuum worked; capture-once-then-grep worked; serialization behind the parallel build worked; self-harvest at authoring time worked; fix-on-sight for the stale doc worked. The session's process spine was solid — the failures were all in the claim layer, not the action layer.

## f) NEXT (up to 50; derived strictly from this session)

**Self-harvest (authoring-time, per house rule):** items 8/9, 20/21/22, 16 → TODO_LIST.md `[ready]` + `docs/todo/stability.md` full rows; items 24–28 → one consolidated `[decision]` library row; items 1–7 ride the existing `[blocked:deploy]` verification row; item 23 (fmt) was executed at self-review time (0 changed — canonical), item 31 verified coherent when the #54 row landed. Everything else stays report-only until triaged.

1. Deploy the freeze-54 hardening (rides the crash-loop wave's calm window; both `[blocked:deploy]` rows name the checkpoints).
2. Post-deploy verify: `memory.swap.max` reads 48G.
3. Post-deploy verify: `system_process_mem_bytes` in SigNoz after one collector run.
4. Post-deploy verify: `system_health_prom_dropped_lines` = 0 + zero node_exporter parse errors.
5. Root-read the census ring for the died boot → session-115/session-46 trajectory (extends the `[watch]` row).
6. Read back `tasks/…_boot-abaf0f51-evidence-pull.md`, cross-check its OOM kill-pass join against my report's victim list.
7. Compute when user-1000 swap crossed 48G on the died boot (journal guard trips quoting zram) — validates the cap's firing lead time.
8. Standing `CASES=promgate` negative leg: corrupt-line fixture → gate drops it, gauge counts it, file stays parseable.
9. Standing leg for the process census (stub or live self-assertion).
10. Emit `system_cgroup_swap_bytes` (from `memory.swap.current`) in the cgroup census — make the 48G bound observable BEFORE it kills.
11. Gatus check: user-slice swap > 35G sustained = early warning under the kill line.
12. Gatus check: `system_health_prom_dropped_lines > 0` (gate firing = emitter glitch, alert it).
13. Gatus/alert: oomd kill rate > 3/10 min = desktop-execution spiral forming (today it was visible only in postmortem).
14. Session-leader identity logging (logind hook or tiny per-session oneshot) — the next session-115 must be nameable from the journal alone.
15. Identify the empty-value emitter (4th .prom incident root cause; the gate is treatment, not cure).
16. Attribute helium's `oom_score_adj 300` (deliberate sacrifice ranking or inherited default?).
17. Fleet audit: any other dead-policy knobs configured-but-never-armed (the `SwapUsedLimit` pattern).
18. Guard Zone-7 candidate: user-slice swap fill (global zram only today) — trip warn at user swap > 35G.
19. memcg OOM body-pat: gatus check for `Memory cgroup out of memory` mentioning user-1000 (cap hits must be loud).
20. Reconcile boot.nix's stacked user-1000 comment blocks into one coherent rationale (mini split brain).
21. Add "census ring + evidence-pull read-back" to the crash-autopsy entry points in stability.md (the source checklist).
22. Document the SwapUsedLimit-needs-ManagedOOMSwap fact in the defense-stack section (today it lives only in ledger #54 + report).
23. `nix fmt --` both edited .nix files (style canonicality still unverified).
24. Consider earlyoom-style per-PROCESS badness ranking (rss+swap) as a complement to oomd's per-cgroup ranking — the 14:47 global OOM killed the browser because adj, not badness. `[decision]`.
25. Consider `ManagedOOMSwap=kill` on selected SYSTEM.slice units (llama stack) as a scoped backstop — needs per-unit analysis, never user slices.
26. Interactive nix-build entry gate (extend the psi-wait-gate/calm-gate pattern to shells, not just agent fleets) — storm culture fix.
27. SEV1 warn-seen re-arm policy: a condition latched >4h with no resolution deserves re-notification (ZRAM CRITICAL was silent-amber 5.5h).
28. Boot.nix: consider exposing swap-cap size as a module option with the sizing rationale attached (owner-tunable without reading history).
29. The `[decision]` row answer (§g Q3) — banner policy for >40G single-scope hogs.
30. Post-deploy: one-boot observation of `system_process_mem_bytes` + `memory.swap.current` to re-validate the 48G number against real usage distribution.
31. Cross-check: does the freeze-52/53 morning report's "freeze-#54 watch" wording now resolve cleanly to the new ledger row (queue/library drift check).
32. If session-115's identity surfaces (owner answer or ring): fix the WORKLOAD, not just the bound — a session writing 54 GB and 820 MB network-out at 78 GB RSS is a specific misbehaving thing with a name.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **What did you launch around ~10:02 today?** session-115 (77.9 G RAM + 53.6 G swap, 54 GB written, 820 MB out, 2h52m CPU over 5h37m) — big model load, download, training, a runaway agent? The leader identity died with the boot; only you can name the workload class. (If unknown even to you, say so — then the ring/process-census is the only path and the `[watch]` row stands.)
2. **Is a user session legitimately allowed to exceed ~48 G swap ever** (big interactive model jobs/VMs), or is hitting the cap an unconditional "that workload belongs in system.slice with its own MemoryMax"? Determines whether 48G is a fence or a wall.
3. **The memory-banner `[decision]`**: keep your 2026-09-02 absolute no-memory-overlays rule, or allow ONE non-pulsing amber banner when a single session scope holds >40 G (it would have named the killer ~5 h before the cliff, while the guard sat powerless at 126/126 no-match)?

---
**Sources:** journal capture `~/.cache/freeze54/boot-abaf0f51.txt` · autopsy `2026-11-14_16-06_…` (counts corrected in-place) · ledger #54 · daemon commit `c085c9797` (both sessions' work batched) · eval `~/.cache/freeze54/eval-toplevel.log`
