# QLC Storm Night 2 — Triple Model Cold-Load + Weekly fstrim + Deploy Re-Arm: Live Attribution

**Date:** 2026-11-02, session ~01:52–02:05 CET
**Tree at write time:** HEAD `b4d4ecbc1` (parallel session active: FEATURES.md / TODO_LIST.md / docs/todo/services.md modified in tree; gen-968 deployed by that session 01:04/01:25)
**Trigger:** owner, live: "Why are fucking slow!??!?! Why is our I/O like 100% all the time!?"

---

## Verdict (one line)

The storm upgraded from yesterday's single-driver (~60% PSI, llama-chat cold-load) to **97% PSI with three simultaneous model cold-loads re-armed by the 01:04 gen-968 deploy (`llama-chat` attempt #3 of an OOM-loop, `fastflowlm` start #3 tonight, `llama-embeddings`), stacked on the weekly `fstrim` (running since 00:08:57, 105+ min) and a go/clippy/VM build battery** — guard firing every ~40 s and disarmed on every single trip.

---

## Evidence table (all live-probed this session)

| Signal | Value | When | Source |
| --- | --- | --- | --- |
| IO PSI some | avg10 96.29 / avg60 97.11 / **avg300 97.31** | 01:52:22 | `/proc/pressure/io` |
| Memory/CPU PSI | mem some 13.74 (full 4.54); cpu some 96.50 | 01:52 | `/proc/pressure/{memory,cpu}` |
| Load | **196.58 / 222.39 / 252.33**, 10,846 tasks, 57 users | 01:52 | `uptime` |
| Attribution window | llama-chat **129.3 MB/s**, fastflowlm **43.2**, llama-embeddings **30.2**, user.slice 17.2 (build battery), mr-sync-dashboard 1.6, nsfw-classifier 1.2 | 01:55:52–01:56:12 (20 s, measured) | cgroup `io.stat` delta, NR==FNR awk |
| Devices | QLC `nvme0n1` rd 170.9 MB/s (p8 `/data` = 169.9 — model reads; 1509 r_iops); Samsung `nvme1n1` rd 84.3 MB/s (absorbing) | same window | `/proc/diskstats` delta (fields verified: reads/sect_rd/sect_wr/ms_io) |
| llama-chat chain | OOM-killed 01:26:52 (instance up 1d7h since yesterday 18:20:30) → restart#1 01:27:02 → **FAILED 01:40:24 exit 22 after 13m34s (5.8 G read)** → restart#2 01:40:36, `load_model` since 01:40:40, **4.99 GB of ~20 GB read by 01:55** | journal + unit `io.stat` | `journalctl -u llama-chat` |
| Restart policy | `Restart=on-failure`, `RestartSec=10` (llama-rag.nix:74-75) — OOM-kill + failed load both re-fire the 20 GB cold-load; ensure wrapper PID 2541655 blocked in `systemctl start llama-chat.service`, timer ACTIVE | 01:53 | module + `pgrep` (redacted) |
| fastflowlm | Started **01:04:27 (deploy)** → Stopped 01:24:33 → Started 01:25:45 → Stopped 01:50:22 → Started 01:51:23 = **3 starts tonight**, 43.2 MB/s live at 01:56 | journal | `journalctl -u fastflowlm` |
| Deploy re-arm | `sudo … switch-to-configuration test` **01:04:21 from pts/61, PWD=this repo** (gen-968 `zwjfakpl…`; profile link mtime 01:25:31 = second activation); `nsfw-classifier` Started 01:04:26 — re-armed despite the owner's 10-31 stop batch; now sick: `/api/health` 503 (11.3 s) at 01:53:30, `.nsfw-wrapped` 192% CPU, etime 49 min | journal | sudo log + `journalctl -u nsfw-classifier` |
| fstrim | Started **00:08:57, still running at 01:53+ (105+ min)**; prior run (Nov 01) took 45m58s; discard traffic invisible in rbytes — competes for the QLC queue | journal | `journalctl -u fstrim` |
| Guard | trips **#5328 (20:32) → #5791 (01:53)**, 587 matched lines since 20:30, **ALL "NO eligible headless tree matched"**; pattern list CHANGED mid-window (added `monitor365-server.service app.slice/run-` = the stability.md:17 fix, deployed 01:04) — still no-match: tonight's churners are model cold-loads no pattern covers; **"escalation arms after 3 such trips" never fired** | journal | `journalctl -u memory-emergency-guard` |
| D-state census | 17 procs: llama-server (chat) + go ×3 + golangci-lint ×2 + link + clippy-driver + ar + find ×2 + sync + fstrim + flm-real + usb-storage + systemd-journal + kworker flush-8:16 | 01:53 | `ps` state sweep |
| Build battery | golangci-lint on `httputil` + `ChastityAPI/test/integration`, `bash -lc go build ./... && … LINT-GREEN`, live `git commit` (CI lint-timeout fix), qemu VM 73.9% CPU, 7+ golangci-lint-langserver, ≥5 crush sessions, iotop-c (11h49m) | 01:53 | `pgrep -af` (redacted) |
| Memory/thermal | MemAvailable 39.5 G (~31%); zram 7.5 G free of 65 G (**88% full**); k10temp **98.0 °C** | 01:53 | `/proc/meminfo`, hwmon |

**Causal chain:** chronic evening storm (~60% PSI, llama-chat refault baseline) → **00:08** weekly fstrim into an already-loaded box → **01:04** gen-968 activation re-arms owner-stopped units (nsfw-classifier, flm — freeze-4 stc-re-arm class, live again) → **01:26:52** kernel OOM kills llama-chat (zram full) → `Restart=on-failure`+10 s starts a 20 GB cold-load into the storm → attempt #1 fails 13.5 min in → attempt #2 crawls (5 GB / 15 min) → flm cycles twice more → QLC saturated (170 MB/s + discard queue), PSI ~97%, load 200+, thermal 98 °C. **The llama-chat loop is self-sustaining:** load 20 GB → OOM at 33 G peak vs zram 88% → reload, indefinitely.

**Containment delivered to the owner (doctrine: no agent kills; agent shell cannot systemctl anyway):** stop fstrim; stop+mask llama-chat (+ensure timer); stop+mask fastflowlm (10-29 disable never held — the 01:04 deploy restarted it); stop+mask nsfw-classifier. Durable = config-disable in llama-rag.nix / guard patterns, next calm-window deploy (deploy.sh pressure gate blocks now by design).

---

## a) FULLY DONE

1. **Pre-read discipline** — yesterday's attribution report read before any probe; stability.md storm sections pre-read; doctrine (measure/attribute/report/recommend, no agent kills) applied.
2. **Live attribution with a MEASURED window** — 20 s cgroup `io.stat` + `/proc/diskstats` delta, verified-field pipeline (known-value check against raw llama-chat io.stat: 4.99 GB @ 259:3).
3. **Full llama-chat lifecycle chain reconstructed** — OOM kill → 2 restarts → current attempt progress quantified; `Restart=on-failure`/`RestartSec=10` confirmed in the owning module (read this time — yesterday's §e4 lesson applied).
4. **The deploy re-arm named** — 01:04:21 pts/61 stc test (gen-968), sudo-layer attribution per the boot-mirror precedent; nsfw-classifier re-arm journal-proven; flm 3-start ledger extracted.
5. **fstrim identified as the overnight worsening leg** — onset 00:08:57, 105+ min runtime vs 46 min yesterday, D-state census corroboration.
6. **Guard disarm census** — #5328→#5791, 587 lines, 100% no-match, escalation hollow; pattern-list change mid-window detected and attributed to the stability.md:17 fix deploying.
7. **Owner verdict + levers delivered live** (the four stop/mask commands, impact-ordered) with the durable-fix path and the pressure-gate deploy caveat.

## b) PARTIALLY DONE

1. **flm stop/start cause** — 3 starts named (deploy 01:04 + two later cycles at 01:25/01:51); whether the 01:50 cycle was crash-restart or a restartTrigger is un-pulled. Effort: S.
2. **Second activation at ~01:25** (profile mtime) — not journaled out; what the 01:25 stc run was. Effort: S.
3. **Re-arm sweep of the full 10-31 stop batch** — nsfw-classifier + flm confirmed back; the other 6 units unverified. → harvested as ready row.
4. **Post-containment verification probe** — blocked on owner action. → harvested as blocked:user row.

## c) NOT STARTED

| Planned | Why not | Priority |
| --- | --- | --- |
| Any containment execution | Doctrine: owner hands only (and agent shell systemctl-blocked) | Critical (owner) |
| Config-disable edits in llama-rag.nix | Needs deploy; pressure gate blocks; owner ruling pending (2nd night same class) | Critical |
| Guard cold-load coverage / disarmed-condition design | Owner-visible proposal first (stability.md zone-6 action-split row owns the design space) | High |

## d) TOTALLY FUCKED UP (measurement hygiene — all caught before quoting, logged for the next session)

1. **Delta pipeline attempt #1:** wrong `/proc/diskstats` fields ($7/$11/$13 are ms counters, not sectors) + unsorted `join` → busy 286,559%, read 0.0. Caught by absurd values; never quoted.
2. **Attempt #2:** `join` output offset slip ($3−$8 crossed read/write between files) → negative IOPS, 12M% busy. Caught; never quoted.
3. **Attempt #3:** grepped io.stat for device NAMES — io.stat keys are `major:minor`; empty result. Fixed by reading the raw file; cgroup aggregation switched to `NR==FNR` awk (join locale pitfalls banned).
4. **Final busy% formula ran ×10 inflated** (`/10/W*100` vs `/W/10`) — the chat verdict deliberately quoted only rd/wr MB/s + IOPS + PSI + D-state (busy>100% is legitimate for NCQ anyway), but the raw transcript carries the inflated figure.
Standing lesson (AGENTS.md quote-scrutiny): one clean verified-number pipeline cost THREE attempts — this is the second consecutive storm session to re-learn it; the `scripts/io-attribution.sh` row is the fix (harvested).

## e) WHAT WE SHOULD IMPROVE

1. **Never hand-type delta pipelines under pressure** — the scriptified, measured-window attribution loop would have saved ~10 min of a live storm.
2. **Deploy-time re-arm check as a pre-deploy-check leg** — the 01:04 deploy re-armed units the owner stopped 31 h earlier, mid-storm; nothing warns (freeze-4 rule known, enforcement absent).
3. **fstrim is storm-blind** — a PSI-gated ConditionDirectoryNotEmpty/ExecCondition (or timer window move) would have avoided the 105+ min discard leg; pairs with the standing sdb fstrim decision row.

## f) Harvested follow-ups (landed at authoring time)

1. [ready] Re-arm sweep of the 10-31 owner stop batch vs gen-968 (→ services.md + queue)
2. [ready] llama-chat restart storm-gating / cold-load backoff (yesterday §f9, 2nd night evidence; → stability.md + queue)
3. [ready] `scripts/io-attribution.sh` measured-window attribution loop (yesterday §f16; tonight's §d1-4 re-proof; → stability.md + queue)
4. [ready] Guard "disarmed" distinct SEV1 condition (yesterday §f6; 463+ no-match trips tonight, escalation text hollow; → stability.md + queue)
5. [blocked:user] Post-containment verification probe (→ stability.md)
6. [decision] llama-chat disable-or-pin — 2nd consecutive night; landed in ai-stack.md citing both reports
7. Edits, not new rows: flm watch row (ai-stack.md) + fstrim decision row (stability.md) extended with tonight's evidence

## g) Questions for the owner

1. **Authorization to contain** (the four stop/mask commands already delivered live): fstrim, llama-chat+ensure, fastflowlm, nsfw-classifier. Nothing else will drop PSI tonight — the guard is disarmed and the llama-chat OOM-loop is self-sustaining.
2. **Whose deploy was 01:04 (pts/61)?** It landed the guard-pattern fix (good) but re-armed everything you stopped 10-31 (nsfw-classifier sick at 192% CPU/98 °C, flm on its 3rd cold-load). If that session is yours/known, the re-arm sweep row just records; if not, it needs the same attribution rigor as this report.
3. **Standing rulings from yesterday still open:** Q2 (is qwen chat supposed to be up?) and Q3 (QLC-vs-Samsung placement for the hot chat GGUF). Tonight is the second consecutive night of the identical class — the loop will be back tomorrow without a ruling.

---

**Cross-references:** `2026-10-31_20-32_qlc-io-storm-llama-chat-coldload-live-attribution-status.md` (night 1 — this is its direct sequel); `docs/agents/stability.md` (freeze-4 stop-is-not-containment / stc re-arm; storm action menu; family-C shape); `docs/todo/ai-stack.md` flm disable-or-pin + watch rows; `docs/todo/stability.md` fstrim decision row, guard coverage rows.
