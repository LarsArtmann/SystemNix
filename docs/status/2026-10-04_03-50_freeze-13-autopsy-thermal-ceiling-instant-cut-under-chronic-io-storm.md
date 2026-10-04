# Freeze #13 Autopsy — Thermal-Ceiling Instant Cut Under the Chronic IO Storm (2026-10-04 03:36)

**Session:** 2026-10-04 03:38 → ~03:55 — single-question session ("why did we crashed?"): prose verdict delivered at the turn boundary FIRST, then this report + the mandated harvest. Read-only forensics plus ONE in-tree fix (tq `startLimit*` passthrough cleanup, §a.4); no deploys, no service actions (agent sandbox blocks sudo/systemctl — owner legs flagged in the Live section).

**Sibling context:** freeze #12 autopsy (`2026-10-03_14-23`) and the storm/anchoring session (`2026-10-04_03-05`, "storm-gated 9h") — this crash is the continuation of exactly the regime both documented.

## Verdict

**Freeze #13 = the thermal-ceiling instant-cut family (#8/#9/#11/#12), sustained by the chronic zone-6 IO storm.** Boot -1 (Oct 03 14:15:36 → Oct 04 03:36:03, 13h20m) rode 43 guard trips (#1770→#1812, driver: the tq-agent-pool agent fleet — +155,623 MB at trip #1771, +146,606 MB at #1810 — plus nix-daemon build bursts) on the STANDING cooling deficit that freeze #12 measured and row `stability.md:117` flagged URGENT — that row literally named this outcome "freeze-#13 bait", and the bait was taken: no cooling inspection happened, heavy load ran all night, the box died again. At 03:35:46 the guard's final trip fired (IO PSI some avg60 64.41 %, disk busy 100 %, MemAvailable 55.9 %); **17 seconds later power cut mid-write** with zero shutdown ceremony, healthy millisecond-latency traffic on the last journal lines, and no OOM/MCE/btrfs error anywhere in the boot. The storm was not the kill mechanism — it was the sustained heat load that rode the deficit to the ceiling; the cut signature (instant, mid-traffic) is the thermal/EC discriminator, not the livelock family's progressive collapse. No pre-death Tctl series exists (thermal alerting still dark — finding 8), so the thermal leg rests on the live boot-0 analog: the SAME deficit state measured minutes after the crash.

**Freeze #14 risk is live at authoring**: Tctl 99.1 °C / PPT 118.3 W / load 38.8 / IO PSI avg60 61 % on boot 0 — nearly identical to freeze-12's live probe (99.1 °C / 112.7 W). See Live section.

## Evidence

| # | Finding | Evidence |
|---|---------|----------|
| 1 | Hard cut, no ceremony | journal cuts 03:36:03 mid-traffic; `last -x` shows zero shutdown entries; no reboot-request messages in the final window |
| 2 | Healthy-to-silence < 1 s = instant-cut discriminator | last lines: BullMQ cron jobs processed in 1.1–1.8 ms at 03:36:00, cv health 200 at 03:35:59, guard cycle completing normally — no escalating stall cascade (the #3–#7 livelock terminals degrade progressively before silence) |
| 3 | Not OOM, not storage, not hardware-error | kernel scan of boot -1: zero OOM-kill lines (only boot-time oomd startup), zero MCE/EDAC, zero btrfs/IO errors (matches are all boot-time registrations) |
| 4 | Guard ran to the last second | trip #1812 logged 03:35:47 (zone 6, IO PSI some avg60 64.41 %, max disk busy 100.0 %, MemAvailable 55.9 % — "the crash #3 class" message); SEV1 bridge fired ("MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED"); bundle write claimed 03:35:51 |
| 5 | Storm spanned the entire boot | trips #1770 (14:18:06, 3 min after the freeze-12 reboot) → #1812 (03:35:47), cooldown-cycling every ~10 min all night; forensics bundles in /var/tmp confirm cadence 00:33→01:40 UTC |
| 6 | btrfs counters identical pre/post crash | boot -1 mounts vs boot 0 mounts: corrupt **1 / 12 / 386,583,438** on the three btrfs devices (nvme0/nvme1 flip accounted) — **zero new corrupt events from the hard cutoff** (freeze-12 protocol row 15, executed for #13 this session) |
| 7 | Thermal at ceiling on boot 0 minutes after the crash | 03:40: Tctl 97.1 °C @ PPT 59.9 W; 03:46: **Tctl 99.1 °C @ PPT 118.3 W, load 38.8** — the standing deficit persists across the crash; freeze-12's live probe read 99.1 °C / 112.7 W |
| 8 | Thermal alerting STILL dark | no k10temp/Tctl check in `gatus-config.nix` (grep this session; rows monitoring.md:17 + :79 open since 10-02) — **fourth thermal-family crash with zero CPU-temperature alerting** |
| 9 | Death-minute forensics bundle LOST | journal: "bundle written to /var/tmp/io-psi-forensics-20261004T013546Z" at 03:35:51; the directory does not exist (listing jumps 012545Z → 014053Z) — a "written" bundle that vanishes at the cut asserts evidence that is not there |
| 10 | Panic-dump discriminators still unavailable | `/var/crash` still ABSENT (kdump row stability.md:106 open since freeze-11); pstore unreadable from the agent sandbox (stated unreadable, NOT empty — freeze-11 §d1 discipline) |
| 11 | Guard trip counter did not persist the death trip | boot -1's last trip AND boot 0's first trip (03:40:54) both log **#1812** — the increment never survived the power cut; duplicate trip numbers degrade every future cadence analysis |
| 12 | Storm driver active at the death minute | tq-dispatched e2e probe (`bun e2e/probe-settings-media-doc.mjs`, oom_score_adj=1000) started 03:35:45; 4 stale gopls killed 03:35:53; tq's daily budget exhausted only at 03:38:29 on boot 0 (32/30) |

## Live regime at authoring (freeze-8 rule: verdicts carry current-boot state)

- **Tctl 99.1 °C / PPT 118.3 W / load 38.8 / IO PSI some avg10 46, avg60 61** — the box is re-entering the death regime while this report is written. tq's budget is exhausted (32/30) so the primary churner is self-paused for today; remaining pressure is recovery reads (boot-0 trip at 03:40:54 named hermes +2,528 MB, boot fsck +247 MB, discordsync +133 MB) and cold caches.
- **Owner actions that cannot wait for a queue cycle:** (1) the physical cooling inspection (row stability.md:117) — second day it is the direct kill mechanism; (2) if IO PSI avg60 holds ≥ 60: stop the recovery readers `crush-hot-db-migrate` + `discordsync-db-heal` per freeze-6 rule (a) — sudo legs; (3) NO heavy builds / toplevel attempts on this box until (1) answers (the 03-05 report's gated-deploy discipline stands).

## a) FULLY DONE

1. **Full autopsy with every discriminator answered** (table above); verdict delivered in prose at the turn boundary BEFORE this report was written (the freeze-12 §d.1 lesson), with live-boot state embedded (freeze-11 §e.2 lesson).
2. **btrfs pre/post comparison executed for #13** — counters identical; row stability.md:109 updated with the #13 result.
3. **Root-caused the tq-agent-pool "Unknown key 'startLimitBurst' in section [Service]" warning** (journal 03:40:35, every unit load) to a stale `[x]` premise: the verified-fixed row (services.md:114, 2026-09-22) checked upstream at lock rev `9411f46f`; the lock has since moved to `e845a925` (upstream lastModified 2026-09-28, deployed with system-814) and the new upstream rev sets `serviceConfig.startLimitBurst`/`startLimitIntervalSec` — lowercase passthroughs that render into `[Service]` where systemd rejects them. Proof: the LIVE unit carries BOTH the correct `[Unit] StartLimit*` keys (from our top-level options, tq-agent-pool.nix:194/240/268) AND the invalid lowercase `[Service]` copies (lines 42–43); `nix eval …services.tq-agent-pool.serviceConfig` on the CURRENT tree returns `{"startLimitBurst":5,"startLimitIntervalSec":300}`; our lib helpers set none (comment-only). The old row's eval-proof checked `serviceConfig.StartLimitBurst` (capital S) — the passthrough is lowercase, so the proof verified the wrong attribute name.
4. **Local fix attempted and REVERTED — no omission idiom exists in this renderer**: `serviceConfig.<key> = lib.mkForce null` renders `startLimitBurst=` (EMPTY value), not an omitted key — the locked nixpkgs unit renderer (`nixos/lib/systemd-lib.nix`, `toOption`/`attrsToSection`) maps EVERY attr with no null filter (read from the locked source). A whole-serviceConfig `mkForce` rebuild or unit-text override would be brittler than the disease. The correct fix is UPSTREAM (go-taskqueue — owner repo): move the two keys out of `serviceConfig` to the module top level (the shape SystemNix already uses everywhere — dual-wan.nix/btrfs-health.nix verified same-shape this session), then bump the input. Tree left at HEAD shape; queued [blocked:push] (§f.5).
5. **§f self-harvest at authoring time** — stability.md (freeze #13 section + rows 102/109/117 updated), services.md (row 114 correction note + upstream-fix row), desktop.md (niri flood + ssh-suspend-guard inhibitor rows), TODO_LIST.md queue one-liners; `scripts/check-todo-system.sh` green after the edits.
6. **Renderer verification ran both ways**: pre-attempt eval proved the current tree carries the lowercase passthroughs (`serviceConfig` → `{"startLimitBurst":5,"startLimitIntervalSec":300}`); post-attempt eval proved null → empty-value rendering — the eval pair is what justified reverting instead of shipping a no-op fix.

## b) NOTICED, NOT DIAGNOSED (out of scope or owner-gated)

1. **niri tty `error doing early import: Error::DeviceMissing` per-second flood** — 140,411 lines in boot -1 (started 14:36:50 Oct 03, 21 min after boot; boot -2 had ZERO) ≈ ~18 MB journal noise per boot. Steady state the whole boot, so NOT a death signal — but a new chronic noise source. Queued (desktop).
2. **ssh-suspend-guard's inhibitor attempt fails every cycle** — `systemd-inhibit … Failed to inhibit: Access denied … requires interactive authentication` (e.g. 03:35:43) right after "SSH session active — holding sleep inhibitor". Whether ANY inhibitor actually holds is unverifiable from this sandbox (loginctl returned nothing). If none holds, SSH-session sleep protection is inert. Queued (desktop).
3. **hermes is the top boot-0 IO reader** (+2,528 MB at the 03:40:54 trip) — recovery-read class, bounded; its config.yaml duplicate-key break (services.md:20, row open) still parses-fail every cycle.
4. `backup-health-metrics` `sort: broken pipe` at 03:35:53 — cosmetic pipe race in a collector timer, noticed only.
5. **1,716 io-psi-forensics bundles in /var/tmp (since 09-14), no pruning policy** — disk impact minor, but no retention rule exists (folded into the new durability row).

## c) DELIBERATELY NOT DONE

1. **crash-autopsy.sh not written** (row stability.md:121, queued since freeze-12) — this is the fifth manual protocol re-derivation (#6/#8/#11/#12/#13), but shipping a new forensics script mid-incident without its verification legs (shellcheck legs, daemon-race amend discipline) is how untested tooling lands; left as the queued dispatch it already is.
2. **No guard code edits** (the #1812-duplicate counter-persistence fix) — the guard has a VM-test gate (`checks.x86_64-linux.memory-emergency-guard`); editing it under storm with no calm window to run the check repeats the deploy-gating trap.
3. pstore / trip-history file reads — sudo-blocked in this sandbox; reported as unreadable, never as empty.

## d) SELF-CRITICISM

1. **The sensors leg ran in the second evidence batch**, parallel with journal archaeology — the freeze-12 rule ("one sensors call BEFORE any journal archaeology") asks for it first. Impact nil here, but the rule exists because anchoring happens fast.
2. **The instant-cut verdict was declared before the btrfs counters were compared** — the counters then confirmed it. Right answer, loosely ordered evidence; recorded for honesty.
3. **The inhibitor question got a row without a verification** — the row carries its uncertainty explicitly, and the owner's root shell closes it in one `loginctl` call; flagged as an owner leg rather than left vague.

## e) IMPROVEMENTS

1. **Prediction-to-reality closed exactly as forecast and nothing happened** — row :117 named "freeze-#13 bait" on 10-03; #13 arrived on schedule. The gap is EXECUTION against known-risk rows, not knowledge. Standing URGENT owner rows need escalation on each new crash that matches their prediction (same class as the trip-RATE alert row, monitoring.md:18).
2. **Guard forensics bundles need durability semantics** — atomic rename + fsync (or a journal-adjacent write); finding 9 shows a bundle can log "written" and not survive the next 12 seconds.
3. **The thermal-alerting gap is now blocking DEATH MECHANISM discrimination**, not just pre-warning: with no k10temp series, #13's thermal leg rests on live-boot analogs instead of the dead boot's own telemetry (monitoring.md:17/79, open since 10-02).

## f) HARVEST (at authoring time — all landed)

1. **[NEW stability, ready]** io-psi-forensics bundle retention + durability: prune policy for the 1,716 /var/tmp bundles; atomic-rename/fsync (or journal-adjacent) writes so a "bundle written" line implies a surviving bundle (finding 9). → TODO_LIST + stability.md
2. **[NEW stability, ready]** guard trip-counter persist-before-log: boot-0 trip reused #1812 — persist the incremented counter BEFORE the action log line so crash-cut trips keep unique numbers (finding 11). VM-test-gated. → TODO_LIST + stability.md
3. **[NEW desktop, ready]** niri tty DeviceMissing per-second journal flood — new since 10-03 14:36 (140k lines/boot, boot -2 zero); root-cause the missing DRM device + contain the log rate. → TODO_LIST + desktop.md
4. **[NEW desktop, ready]** ssh-suspend-guard inhibitor verify — the systemd-inhibit call fails every cycle; verify whether any inhibitor actually holds; if none, SSH-session sleep protection is inert (owner `loginctl` leg closes the question). → TODO_LIST + desktop.md
5. **[NEW services, blocked:push]** go-taskqueue upstream: move `startLimitBurst`/`startLimitIntervalSec` out of serviceConfig (rev e845a925 sets them there; systemd rejects the `[Service]` copies at every unit load) — then bump the flake input; SystemNix's top-level keys already render the working `[Unit]` copies, so the warning dies with the upstream fix alone. Local omission verified impossible (§a.4). → services.md only (push-gated, not queued)
6. **[UPDATED stability:102]** freeze-taxonomy row extended: entries #8–#12 → #8–#13 owed to docs/agents/stability.md.
7. **[UPDATED stability:109]** btrfs-baseline row: #13 comparison RUN, counters identical (#11 remains the open one).
8. **[UPDATED stability:117]** the "#13 bait" row: freeze #13 occurred 2026-10-04 03:36 under exactly the predicted conditions; cooling inspection STILL gates all heavy builds.
9. **[UPDATED services:114]** correction note appended: `[x]` premise falsified at lock rev `e845a925`; eval-proof had checked the wrong attribute case; fix = upstream move + input bump (f.5).
10. **Deliberately NOT harvested:** monitoring.md:17/79 (k10temp alerting) and :18 (trip-rate alert) — rows exist with the right asks; this report adds evidence to their case, not new asks. hermes duplicate-key (services.md:20) and gitea-runner aftermath (freeze-12 §f.11) likewise already tracked.

**Bottom line for the owner:** the box died of heat it could not shed, on a deficit documented two days ago, under a storm our own task fleet drove all night — and it is back at 99 °C right now. The cooling inspection is the only action on the critical path; everything else in this report is cleanup around a known cause.
