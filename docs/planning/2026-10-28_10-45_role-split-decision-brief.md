# Role-Split Decision Brief — One Box or Two?

**Author:** stability-extinction executor session, 2026-10-28 (plan [2026-10-28_01-25 §M25/F61-F62](../planning/2026-10-28_01-25_SUPERB-stability-crash-extinction-pareto-plan.md), owner-gated §7.3 appetite question)
**Status:** DECISION DOC — no infrastructure change here. The owner reads, decides, and either files it under "not now" or opens the procurement todo.

---

## 1. What one box costs today (the crash-cost table)

The evo-x2 does three jobs on one QLC-rooted, cooling-deficient chassis: **24/7 server** (40+ services: Forgejo, Paperless, Immich, SigNoz, DNS, backups…), **daily-driver desktop**, and **build/test farm** (nix builds, VM tests, go batteries, agent fleets). The stability record:

| Period | Documented freezes/resets | Root families |
| --- | --- | --- |
| Aug 22 – Oct 1 (#1–#14) | 14 | zram/memory livelock, IO livelock, thermal cuts begin |
| Oct 1 – Oct 7 (#8–#26) | 19 in 7 days | thermal ceiling era + battery class + migration storms |
| Oct 10 – Oct 25 (#27–#33) | 7 (multi-day boots) | combined storm+thermal, watchdog |
| Oct 25 – Oct 28 (#34–#37 + live re-fire) | 5 in 76 h + one 10-h live storm | SP5100 watchdog after combined storms |

**Direct, countable costs of the last 76 h alone:**
- 5 hard resets × (boot + service catch-up + journal-vacuum risk + every parallel session's in-flight work) — tonight alone: 3 agent sessions' batteries died or were paused mid-run, one deploy wave is stuck undeployed across 4 boots.
- The 2026-10-28 storm: **28+ guard trips on the live boot (10 h)**, LLM sockets killed repeatedly by the wrong-tool action (the ratified M2 split fixes the action, not the storms), tq-agent-pool +162 GB read windows, nsfw-classifier cold-start storms, a sudo rm wedging buildcache — all concurrent on one disk set.
- Journal at 7.9/8 G: every additional boot risks eating the evidence for the previous ones (evidence-pull discipline exists because of this).
- Owner time: three owner gates pending, BIOS windows needed, reboot batteries needed — the box's instability consumes the attention its maintenance needs.

**The structural fact:** the freeze families are all CONTENTION classes (IO bandwidth, memory, thermal budget). Software mitigation (guard, gates, pauses, caps — this plan) converts "storm = death" into "storm = pause and survive", but every mitigation is fighting for the same QLC QD1 queue and the same thermal envelope. Extinction-by-architecture means the jobs stop sharing those queues.

## 2. What moves, what stays (the split sketch)

**Stays on evo-x2 (desktop + latency-sensitive):** niri/DMS desktop, audio, browser, crush interactive sessions, Helium, Steam (models stay on /data — bandwidth-bound), the LLM stack (GTT-first wants the 124 GB RAM + GPU), PapDashboard, monitoring SIGNOZ? *(owner call — see options)*.

**Moves to box 2 (build/test farm + churning server tier):** nix build/VM-test batteries (the freezes #14–#33 class), tq-agent-pool + headless agent fleets (the +162 GB/window reader), Forgejo + runner (build farm adjacent), Forgejo/Paperless/Immich backups executing FROM box 2's schedule, ClickHouse (the 41 GB VM resident), attic/binary cache, maybe nsfw-classifier's cold-start storm.

**Signals that would immediately quiet down on evo-x2:** the entire battery-class freeze family (8 documented gate violations), the tq-pool reader family, the crash-RECOVERY storm amplifier (box 2's builds don't re-run cold on the desktop's boot), most of the 02:00–04:00 backup-window overlap storms.

## 3. Options (indicative, 2026-10 price levels — verify before deciding)

| Option | Hardware | Monthly power | What it buys | Honest downsides |
| --- | --- | --- | --- | --- |
| A. Mini-PC (used ThinkCentre/Beelink class, 32–64 GB) | ~200–450 € once | ~5–10 W idle | Batteries + agent pools + ClickHouse off the box; biggest freeze-family kill per euro | Single NVMe → same QLC-vs-build tension at smaller scale; no ECC |
| B. Mini-PC + SATA/NVMe SSD pair | ~350–650 € once | ~8–15 W | A + build cache on its own disk (the buildcache-USB wedge class dies) | Still one PSU fan-less thermal budget; fine for builds, not for GPU |
| C. Used tower/Rackable (ECC, 2×3.5") | ~400–800 € once | ~15–30 W | Server tier properly (ZFS/btrfs mirror, ECC RAM, backups executing) | Noise/space; overkill if the server tier stays small |
| D. No second box — accept MANAGED status | 0 € | 0 W | The full M2–M20 stack still lands; storms pause-not-kill; role stays single | Freeze families become contained-not-extinct; every new heavy workload re-negotiates the queues |

## 4. The decision framing

- If the answer is **D (managed)**: this plan's remaining legs are the whole story; the brief closes as "decided against, date, revisit trigger = next watchdog reset after M5 deploys".
- If the answer is **A/B/C**: the first procurement todo is the ONLY blocking item; build-farm migration (batteries + tq-pool + runner) is phase 1, server-tier migration phase 2, and the evo-x2 keeps its QLC for exactly one job: the desktop + LLM host it has the RAM/GPU for.

**My recommendation (one alternative rule): Option A now** — the battery/tq-pool class is the single largest documented freeze family (15+ of 37), a used mini-PC is one month of cloud-GPU spend, and it removes the class the admission gate can only REFUSE, never relocate. Option C is the right shape if the server tier keeps growing (Immich/Paperless/ClickHouse storage curves say it is).

## 5. What I could NOT figure out myself (owner inputs needed if A/B/C)

1. Budget ceiling + noise/space constraints for the second box (shelf next to the desk? basement?).
2. Whether SigNoz/monitoring stays on evo-x2 (single pane over both boxes) or moves (box 2 monitors box 1 — the "watcher outside the thing that dies" doctrine, ci-watchdog precedent).
3. Timeline: before or after the M5 deploy wave's ratification evidence lands (the split's first live storm behavior is the strongest data either way)?
