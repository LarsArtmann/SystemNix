# Freeze #39 Autopsy — WDT reset: deploy re-arm of the owner-stopped cold-load engine + overnight fleet battery (boot `7b12c3db`)

**Session:** 2026-11-02 11:37–12:05 CET (post-crash triage; live probes + canonical evidence pull)
**Scope:** why the box crashed at 2026-11-02 11:34 — full-boot forensics for boot `7b12c3db75ba4d95b86901594936b7b5`, family classification per the stability.md discriminator, evidence secured before journal vacuum.
**Canonical evidence:** `docs/status/tasks/2026-11-02_10-49_boot-7b12c3db-evidence-pull.md` (24 oom-lines / 12,527 guard-lines, boundary + CH sections; committed this session)
**Deploy anchor at writing:** INTACT — `system-969-link` == `/run/current-system` (`3w43hr7…`, by-number newest; verified per the 2026-10-23 procedure)

## Verdict (one line)

Freeze #39 — **Branch C (combined storm + thermal ceiling), SP5100 hardware-watchdog reset after a ≥30 s kernel hang at ~11:34**: the freeze-#38 recovery boot NEVER cooled (first DEEP THROTTLE ENTER 3.6 min post-boot; 2477 ENTERs — new record), rode 1090 guard trips in 56 h (~19.4/h, above the storm-band ceiling of 11.7 — record rate), and died at the end of an overnight sequence in which **the 01:04 gen-968 deploy re-armed the owner-stopped llama-chat cold-load engine into the weekly fstrim + a build battery (triple model cold-load, IO PSI avg300 97.3 %), the kernel OOM'd the giant-VM llama-servers (41.7 GiB llama-chat — the victim's THIRD documented kill — + 10.8 GiB llama-embeddings + flm-real), and the morning quotaboard compile storm (load 231–288) never drained**; final window: IO PSI avg60 98.71 % with MemAvailable 41.1 %, k10temp cycling 98–99 °C to the death second, every guard trip a no-match no-op.

## §a Family classification — discriminators (each verified this session)

| Discriminator | Reading | Source |
| --- | --- | --- |
| Journal cut | mid-traffic, last line 11:34:07.159 (crm-server GET 200, sub-second healthy) | `journalctl -b -1` tail |
| Shutdown ceremony | NONE (zero PID-1 shutdown lines; user-manager lines absent too; wtmp crash class) | pull boundary section |
| Reset reason | `x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired` | boot 0 kernel log, 11:35:45 |
| cut → boot gap | 98 s (inside the 92–131 s WDT signature measured on #36/#37) | `--list-boots` |
| pstore / vmcore | /var/crash absent (no vmcore — verified); pstore NOT probed this session (root-only dir on this box) — "empty" rests on the 8-boot doctrine, not a live read | probe + doctrine |
| Thermal leg | 2477 DEEP THROTTLE ENTERs, first Oct 30 03:37:28 (3.6 min post-boot, 98 °C), last 11:33:35 (32 s pre-cut) | full-count grep |
| Storm leg | IO PSI some avg60 98.71 %, disk busy 100 % at the 11:27:25 guard heartbeat | journal |
| Memory leg | 9 OOM invocations / 10 kills whole-boot (global cascade 01:26–03:21); SEV1 "ZRAM SWAP CRITICAL" 11:33:25 (cleared by 11:33:55) | journal + pull |

→ **Branch C, the #34–#38 lineage; 4th consecutive WDT-confirmed cut of the retained series.**

## §b Whole-boot census (full-count greps, no head truncation; cross-checked against the canonical pull)

| Metric | Value |
| --- | --- |
| Window | Oct 30 03:33:49 → Nov 2 11:34:07 CET (**2 d 8 h 0 m** ≈ 56.0 h) |
| DEEP THROTTLE ENTERs | **2477** (record; #38 = 1394); one per ~82 s while pegged |
| Guard trips | **#4921 → #6010 = 1090** (~**19.4/h**, above the storm band 1.3–11.7/h — record rate); 26 carried socket/sacrifice actions (final-hour churn: "23 trips in the last hour" per the SEV1 notify text); the ioPause-era majority were no-matches |
| Guard log lines | 12,527 |
| OOM | 9 invocations / 10 kills — see §c act 4 for the victim list with memcgs |
| journald "Under memory pressure, flushing caches" | **105 whole-boot** (corrected 12:18 from the first draft's "36+", which was eyeballed from tail-truncated probe output; events span the whole boot with the 07:42→11:27 stretch the densest) | full-count grep |
| tq-agent-pool | crash-looping from ~08:00: 197 restart/fail lifecycle lines to death (the SEV1 "UNIT CRASH LOOP" condition) |
| Deploys in-boot | gen-967 Oct 31 03:57, **gen-968 Nov 2 01:25:31, gen-969 Nov 2 08:12:06** |

## §c Causal chain — six acts, every step evidenced

1. **Recovery boot that never cooled (Oct 30 03:33).** `7b12c3db` is freeze-#38's recovery boot. First DEEP THROTTLE ENTER at 03:37:28 @ 98 °C — 3.6 minutes post-boot. The standing physical cooling deficit ([blocked:user] inspection row, now the predicted-and-ignored mechanism behind 10+ cuts) got no cool-down window at any point in 56 h.
2. **Chronic engine named + owner-contained (Oct 31 18:14).** The `2026-10-31_20-32` live attribution root-caused the chronic QLC storm as `llama-chat.service` cold-loading the ~20 GB Qwen3.6-35B GGUF (87 % of all QLC traffic in window); the owner stopped 8 units (llama-chat + `llama-chat-ensure.timer`, tq-agent-pool, monitor365, nsfw-classifier, …).
3. **Deploy re-arm into the weekly fstrim (Nov 2 00:08–01:25).** Weekly fstrim from 00:08:57 (105+ min). **gen-968 (switch ~01:04, profile 01:25:31) re-armed the owner-stopped units** — `llama-chat-ensure.timer` Started 01:04:26 — producing the triple model cold-load (llama-chat OOM-loop attempt #3, fastflowlm start #3, llama-embeddings) stacked on the fstrim + a go/clippy/VM build battery: IO PSI avg300 97.31 %, guard firing every ~40 s and disarmed on every trip (the `2026-11-02_01-58` live-attribution session, owner-triggered). `systemctl stop` is NEVER containment on this host (freeze-4 rule; stc re-arms) — this is the rule's third documented strike.
4. **Kernel OOM cascade (Nov 2 01:26–03:21).** 01:26:54 GLOBAL: bun (adj 1000, `app.slice/run-p746179…scope`) + geckodriver (adj 1000, `run-p886378…scope`) + **llama-server 41.7 GiB total-vm (adj 300, `/system.slice/llama-chat.service`)** — the SAME victim as freeze #34 (Oct 25 16:54) and #38 (Oct 30 03:15): third documented kill. 03:20:10 llama-server 10.8 GiB (`/system.slice/llama-embeddings.service`). 03:21:01 flm-real 25.9 GiB (the guard's own sacrifice target, restarted after its stops — the flm-real-restart-sweep row's class). Earlier whole-boot: 5 memcg OOM kills of nix builds (7.7–8.2 GB anon each), ALL inside `/system.slice/tq-agent-pool.service` (its MemoryMax working as designed — but tq was building hard around the clock). Owner stop/mask batch lands ~02:00 (blocked:user verification row); `llama-chat-ensure.timer` stopped again 08:48:17.
5. **Morning fleet battery (Nov 2 03:40–08:35).** The overnight session fleet: deploy-exit4/opencloud bind-race, discordsync SigNoz wiring, lock-float unblock with **11 FOD shim builds**, bank-sync, health-hub federation ×2 + CV warns, crush-config superb, openaicompat, quotaboard ×2. The quotaboard report (08:35): "IO storm STILL active (PSI some avg10 98.95 %, load 231) … the switch itself blocked 90+ minutes by the parallel-session compile storm (PSI 92→99 %, load 112→288, desktop processes in D-state)". gen-969 deploys 08:12:06 (second re-arm window). tq-agent-pool crash-loops from ~08:00. journald memory-pressure flushes from 07:42.
6. **Terminal 15 minutes (11:19–11:34).** IO-PAUSE trips #6006–#6010, every one "NO eligible headless tree matched the attribution" — the actual churners (model cold-loads, user-scope builds) sit outside every pattern. 11:27:25 heartbeat: **IO PSI some avg60 98.71 %, disk busy 100 %, MemAvailable 41.1 %** — the crash-#3 stacked-full-disk-readers signature with healthy-looking memory. Thermal ENTER/DROP cycling 98–99 °C every 60–90 s to the death second. The guard itself degrading: 11:32:39 run took 44.03 s wall for 1.215 s CPU. User-facing latency collapse: crm-server PATCH 906 ms vs the 20 µs baseline (≈45,000×); forgejo UpdateLog 3.46 s. Gatus: User Slice Memory >72 G (11:26:04), Pocket ID SQLite lockup (11:33:20), Bank-Sync down (11:33:31), Memory Pressure CRITICAL (11:33:45). SEV1 latched 11:33:25 (GUARD TRIPPED + UNIT CRASH LOOP + ZRAM CRITICAL). A llama-server was still mid-inference at 11:26:58 (19 tok/s prompt processing). Journal cut 11:34:07 mid-traffic → ≥30 s hang → WDT reset → boot 0 at 11:35:45.

## §d Post-crash state (probed 11:37–11:50)

- **Anchor INTACT**: `system-969-link` == `/run/current-system` (`3w43hr7…`) — the 08:12 gen-969 deploy survived the WDT reset; no exit-14 unanchored-boot risk before any future reboot.
- **Boot 0 has re-armed the crash-loop amplifier (freeze-6 class) — LIVE at writing**: load 88.71/106.68/71.82 (11:50); IO PSI some avg10 80.96 / avg60 72.33; hottest: `vet` 333 % CPU, nsfw-classifier 181 % (cold-loading, 6.6 % mem), golangci-lint 100 %, `link` 64.7 %; 25 user sessions (MacBook fleet pts/10–15 from 11:37). Memory healthy (57 Gi available, swap 71 Mi used) — a pure IO/CPU storm. **Expect freeze #40 if the battery continues on the recovery boot without a calm window.** Agent-side action menu during an IO storm is measure/attribute/report/recommend — containment (stopping the builds/cold-loads) is owner hands.
- Post-crash peripheral checks (NIC-on-PCIe, DAS USB) not re-run this session; the documented class says power-cycle, never warm-reset-trust, if either is absent.

## §e What worked / what didn't

**Worked:** the WDT kept its 30 s contract (no vmcore expected — livelock pets it); deploy-anchor discipline; gatus + SEV1 fired correctly (notify tier — functionally invisible for <60 s deaths, known); `SyncIntervalSec=15s` left a clean journal tail to the death second; the pre-vacuum doctrine ran as designed (canonical pull was this session's FIRST journal-consuming act after the bounded death-window probes).

**Didn't:** thermal-pstate-guard — 2477 ENTERs meets its own deficit-masking criterion ("≥95 °C through a whole boot even with deep_throttled==1"); memory-emergency-guard — 1090 trips with a 100 % no-match final window (pattern-blind to model cold-loads and user-scope builds; the queued pattern-extension and "disarmed"-SEV1 rows now carry terminal evidence); **deploys as re-arm vectors** — gen-968 (01:04) and gen-969 (08:12) each re-armed owner-stopped containment, the second into an already-fatal morning storm.

## §f NEXT (self-harvested at authoring time — queue + library rows landed with this report)

1. **[blocked:user] Deploy re-arm vs owner containment policy** — QUEUED (TODO_LIST + `docs/todo/stability.md`): stc cannot re-arm a MASK, only a stop; owner call on masking the Oct-31 containment batch (at minimum `llama-chat-ensure.timer`) vs a deploy-time re-arm warning vs accept. Third strike of the freeze-4 rule.
2. **llama-chat restart storm-gating row UPDATE** — the existing [ready] row gains freeze #39 as its terminal outcome (night 3 of the cold-load loop ended the boot).
3. **Guard "disarmed" distinct SEV1 condition row UPDATE** — gains the #39 final-window numbers (5 no-match trips in the final 11 min; 1090 whole-boot; "escalation arms after 3 such trips" never fired across 460+).
4. **stability.md ledger + census table** — landed in the same commit as this report (not queued; done).
5. **DELIBERATELY NOT HARVESTED:** boot-0 re-fire containment (agent doctrine restricts to measure/attribute/report/recommend during storms; owner hands only — this section IS the recommendation); the physical cooling inspection row (already [blocked:user], #39 is its latest confirming data point, no new row needed); quotaboard's blocked deploy (owned by its own 08:35 report's §f).
