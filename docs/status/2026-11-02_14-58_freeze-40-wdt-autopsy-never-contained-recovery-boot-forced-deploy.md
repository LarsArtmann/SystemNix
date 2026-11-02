# Freeze #40 Autopsy — WDT reset: the never-contained recovery boot; forced deploy + boot-time timer re-arm of the llama-chat cold-load engine (boot `2a642827`)

**Session:** 2026-11-02 14:45–15:0x CET (post-crash triage; live probes + canonical evidence pull)
**Scope:** why the box crashed at 2026-11-02 14:42:00 — full-boot forensics for boot `2a64282777784771ae1c53f7279dbdfd` (the freeze-#39 recovery boot), family classification per the stability.md discriminator, evidence secured before journal vacuum.
**Canonical evidence:** `docs/status/tasks/2026-11-02_13-46_boot-2a642827-evidence-pull.md` (545 guard lines, boundary section; committed this session)
**Deploy anchor at writing:** INTACT — `system-971-link` == `/run/current-system` (`x17510yj…`, by-number newest, mtime 14:32:50); boot 0 booted the same path. No exit-14 risk from THIS cut.

## Verdict (one line)

Freeze #40 — **Branch C (storm-leading: IO livelock whole-boot, thermal + a late memory leg arriving at the death second), SP5100 WDT reset after a ≥30 s hang at 14:42:00**: the freeze-#39 recovery boot was re-armed at boot-second 8 (`llama-chat-ensure.timer` Started 11:35:53 — owner stops do not survive REBOOTS any more than deploys), llama-chat crash-looped 5 × ~13-min 20 GB QLC cold-loads before converging 12:51 and running ~25 GB resident to the death, the guard tripped a record 66 times in 3 h06 m (~21.3/h; #6011 at 11:39:38 = 4 min post-boot) with EVERY trip a no-match (llama-chat is not in the pause patterns), and a **`DEPLOY_FORCE_PRESSURE=1` float-deploy (gen-971, 14:19:41→14:32:50) forced through the pressure gate 4 minutes after that gate had correctly blocked (exit 12 at 14:15:15)** — the switch + ~40 provisioner restarts landed at IO PSI avg60 98.88 %, MemAvailable falling 41 %→20.9 %, and the box died 9 minutes later with gatus Memory-Pressure firing 14:41:52, thermal ENTER 14:41:57, SEV1 (GUARD TRIPPED + CRASH LOOP + ZRAM CRITICAL) 14:41:59, cut 14:42:00. Freeze #39 §d predicted this cut verbatim ("Expect freeze #40 if the battery continues on the recovery boot without a calm window").

## §a Family classification — discriminators (each verified this session)

| Discriminator | Reading | Source |
| --- | --- | --- |
| Journal cut | mid-traffic, last line 14:41:59 (atlas /health/ready 200 @ 124 ms + SEV1 line, sub-second healthy) | pull boundary section |
| Shutdown ceremony | NONE (zero PID-1 shutdown lines) | pull boundary section |
| Reset reason | `x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired` | boot 0 kernel log 14:43:39 |
| cut → boot gap | 99 s (inside the 92–131 s WDT signature) | `--list-boots` |
| Storm leg (LEADING) | IO PSI some avg60 52–98.88 % the WHOLE boot (trip #6011 at 11:39:38, 4 min post-boot); final heartbeat 14:33:02: avg60 98.88 %, disk 100 %, MemAvailable 20.9 % | guard lines in pull |
| Memory leg (LATE) | 0 OOM whole-boot, but MemAvailable 41.4 % (11:39) → 26.8 % (12:30) → 20.9 % (14:33) + SEV1 "ZRAM SWAP CRITICAL" 14:41:59 — llama-chat resident since 12:51:31 | guard heartbeats + SEV1 line |
| Thermal leg (TERMINAL) | 134 DEEP THROTTLE ENTERs (one per ~83 s while pegged; first 11:36 — boot never cooled); final ENTER window ends 14:41:57, 3 s pre-cut | full-count grep |
| Kernel panic/oops | NONE — the pull's 4 "Oops" hits are Go app log strings (file-renamer, pma git retry) | verified in pull |

→ **Branch C, the #34–#39 lineage; 5th consecutive WDT-confirmed cut. Storm-led this time (vs #39's thermal-led): 0 OOM and thermal only terminal.**

## §b Whole-boot census (full-count greps, cross-checked against the canonical pull)

| Metric | Value |
| --- | --- |
| Window | 11:35:45 → 14:42:00 CET (**3 h 06 m**) |
| Guard trips | **#6011 → #6076 = 66** (~**21.3/h** — new record rate; #39 = 19.4/h; storm band was 1.3–11.7 pre-#39); 65 IO-PAUSE + socket-action trips, **every single one "NO eligible headless tree matched"** |
| Guard log lines | 545 |
| DEEP THROTTLE ENTERs | **134** (vs #39's 2477 over 56 h — but the ~83 s cadence while pegged matches; this boot simply never had a cool minute from 11:36) |
| OOM invocations / kills | **0 / 0** (first Branch-C cut with zero OOM — the memory leg arrived as pressure + zram fill, not kills) |
| llama-chat lifecycle | ensure-timer Started 11:35:53 (boot-second 8) → cold-load fails at 11:49:14 / 12:02:46 / 12:16:07 / 12:29:28 / 12:42:50 (5 × ~13 min ≈ **110 GB of QLC reads in the first 75 min alone**) → attempt #6 converged **12:51:31** (health 200) → resident to death |
| Deploys in-boot | gen-970 12:24:30 (opencloud session, forced through pressure); **13:58:49 float-deploy gate-BLOCKED exit 12 at 14:15:15 (gate worked); 14:19:41 re-fire with `DEPLOY_FORCE_PRESSURE=1` → gen-971 switch completed 14:32:50** |
| gatus | Memory Pressure Warning TRIGGERED 14:41:52 (8 s pre-cut) |
| SEV1 at death | MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL (14:41:59) |

## §c Causal chain — five acts, every step evidenced

1. **Boot-time re-arm (11:35:53).** `llama-chat-ensure.timer` Started 8 s after boot — before any deploy ran this boot. The owner's Nov-2 08:48 stop (previous boot) and the Oct-31 batch are both dead on reboot: the timer is `wantedBy` the boot graph in the deployed config. New fact vs freeze #39: **deploys are not the only re-arm vector — every fresh BOOT re-arms it too.** Only a mask (or config-disable) survives both.
2. **Cold-load crash-loop, guard blind (11:35–12:51).** 5 failed ~13-min cold-loads of the 20 GB Qwen3.6-35B GGUF (`/data/ai/models/jan/...`), each failure → 10 s restart → next cold-load (the storm-gating row's loop, now boot-opening). Guard trips every ~2.5 min, all no-match: `llama-chat.service` matches none of the pause patterns (nix-daemon / tq-agent-pool / session- / monitor365-server / app.slice/run-).
3. **Two deploys into the storm (12:24 gen-970 forced; 13:58 gate-blocked exit 12).** The gate's refusal at 14:15:15 (986 s run, float proof RED on a file-and-image-renamer go-modules hash mismatch) is the gate WORKING. The float session then re-fired at 14:19:41 with the override.
4. **gen-971 forced switch + terminal 10 min (14:19–14:42).** `DEPLOY_FORCE_PRESSURE=1` logged verbatim in `/var/log/systemnix-deploys/2026-11-02_14-19-41.log` ("top-3 stalled cgroups … Deploying under this pressure risks contributing to a kernel freeze … DEPLOY_FORCE_PRESSURE=1 set — proceeding anyway"). Switch completed 14:32:50 (profile set), ~40 provisioner units restarted into IO PSI avg60 98.88 %. Last trip #6076 14:35:02. MemAvailable 20.9 % (llama-chat resident + churn), gatus memory-pressure 14:41:52, thermal ENTER 14:41:57, SEV1 14:41:59, journal cut 14:42:00 mid-traffic, zero ceremony → ≥30 s hang → WDT.
5. **Boot 0 re-armed the same recipe within seconds (14:43+).** ensure-timer Started 14:43:46, llama-chat cold-loading from 14:43:47 (verified live mid-load at 14:53), nsfw-classifier cold-loading (176 % CPU, 7.8 GB RSS — the freeze-#33 death-second amplifier), a parallel session's float-proof deploy (14:45:20, full `--keep-going` toplevel build = the dux-shell Go compile battery visible in `ps`), 21 user sessions. Load 90 at 2 min → **162.55 at 10 min**, IO PSI avg60 78 % at writing — freeze #41 forming unless the owner contains (see §d).

## §d Post-crash state (probed 14:45–14:54)

- **Anchor INTACT**: `system-971-link` == `/run/current-system` (`x17510yj…`) — the 14:32 switch's profile step completed before death; no unanchored-boot risk.
- **Boot 0 re-arm is LIVE and worsening**: load 22.76 (1 min) → 90.14 (2 min) → 162.55 (10 min); IO PSI some avg10 70–78 %. Drivers named via `ps`: nixbld Go compile battery (dux-shell build, part of the 14:45 float-proof), nsfw-classifier cold-load, llama-chat attempt #1 mid-load, `nix eval` from a parallel session, 21 user sessions. Memory still healthy (54 Gi avail) — pure IO/CPU storm, the #3/#19 class. **Agent action menu held: measure/attribute/report/recommend — this section IS the recommendation.**
- Owner-hands containment (the [blocked:user] policy row's decision, now with a 4th strike + the boot-time re-arm fact): `sudo systemctl mask llama-chat-ensure.timer llama-chat.service` (a mask survives boots AND deploys; stops demonstrably do not — freeze-4 rule, strikes 1–4), plus holding deploys until PSI calms. The physical cooling inspection row remains the standing deficit behind 11+ cuts.

## §e What worked / what didn't

**Worked:** the deploy pressure gate (exit 12 at 14:15 after a 986 s refusal — correct); evidence-before-vacuum doctrine (pull was this session's first journal-consuming act); `SyncIntervalSec=15s` again left a clean tail to the death second; SEV1 + gatus fired (notify tier, functionally invisible for <60 s deaths — known); guard counter continuity #6010→#6011→(boot 0)#6077+.

**Didn't:** the `DEPLOY_FORCE_PRESSURE=1` override — used at 12:11 (survived) and 14:19 (dead 9 min after switch); it is now load-bearing in two death windows today. The guard's pause patterns — 66/66 no-match trips while a HEADLESS SYSTEM UNIT cold-loaded 110 GB off the QLC; the pattern-extension row has terminal evidence for the fourth consecutive storm boot. `systemctl stop` containment — strikes: gen-968, gen-969, and now boot-time re-arm (11:35:53, no deploy in flight) — stops don't survive reboots either.

## §f NEXT (self-harvested at authoring time — queue + library rows landed with this report)

1. **[blocked:user] Deploy re-arm vs owner containment policy row UPDATE** — gains freeze #40: 4th strike, NEW VECTOR (boot-time timer start at boot-second 8, no deploy needed), and the 14:19 `DEPLOY_FORCE_PRESSURE=1` gen-971 forced switch 9 min pre-death. Recommendation hardened: mask `llama-chat-ensure.timer` + `llama-chat.service` (config-disable alternative: `llama-chat.enable = false` — needs a deploy, which needs a calm window).
2. **llama-chat restart storm-gating row UPDATE** — gains the freeze-#40 boot-open (5 × 13-min cold-load failures before convergence) and the 4th-boot re-arm; the loop is now boot-opening, not just night-recurring.
3. **DEPLOY_FORCE_PRESSURE discipline row NEW** — two forced deploys today, the second terminal; proposal: the override must also log an explicit "storm battery active" warning when zone-6 trips fired in the last hour (freeze-#5 doctrine already queues deploys on trip recency — the override bypasses that gate too).
4. **stability.md ledger + census table** — landed in the same commit as this report (not queued; done).
5. **DELIBERATELY NOT HARVESTED:** boot-0 live containment (owner hands per doctrine); the float-proof deploy's fate (owned by its session); the guard pattern-extension row (already queued from #39 with terminal evidence — this report only adds the 66/66 number to it).
