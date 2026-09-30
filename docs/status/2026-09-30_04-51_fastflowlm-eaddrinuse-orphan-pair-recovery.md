# FastFlowLM outage: EADDRINUSE via orphaned socket pair — diagnosis + recovery

**Date:** 2026-09-30 04:51 · **Session scope:** flm outage diagnosis + recovery only (user ask: "why is fastflowlm down?")
**Content-pin:** `3ce83f41` (HEAD at authoring) · **Repo changes by this session:** none to code/config — docs + todo harvest only
**Outcome:** flm SERVING again (`/v1/models` 200, 36 models) without a reboot.

---

## TL;DR

`fastflowlm.service` was crash-looping `bind: Address already in use` on backend port :52626 → start-limit-hit. The pin was **not** the documented flm corpse class — there was **no flm process at all**. The port was held by an **orphaned ESTABLISHED loopback socket pair** `127.0.0.1:52626 ↔ 127.0.0.1:1411`, owned by **gatus** (DynamicUser uid 63216) on one side and **pocket-id** (uid 970) on the other — both live, healthy services whose peer sockets survived flm's earlier death. Restarting **gatus** (the holder) released the pair (→ TIME_WAIT → expired); the backend then cold-loaded and is serving.

During recovery the first `curl` probe looked like a new bug (`HTTP/0.9 when not allowed`) — it was not: the backend had been up 55s into its 21.6 GB cold load when the **memory-emergency-guard Zone-6 trip #1468 killed it mid-load** (io PSI avg60 58–76% sustained; the box is in a crash-#3-class IO storm whose dominant reader is the **tq agent-pool, 168 GB cumulative read**). The guard's daily **restore budget was already capped (3/3)**, so even with the port free, flm stays down across trips until a manual start — the user's final start + probe (attached) succeeded.

## Timeline (journal-exact)

| Time                              | Event                                                                                                                                                                                                                                                                                |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-09-29 23:48–2026-09-30 00:22 | Backend starts fail repeatedly: `bind: Address already in use` (:52626) → exit 1 → `start-limit-hit`. Each :52625 client connection re-requests a start (socket-activation churn).                                                                                                   |
| 2026-09-30 ~00:15                 | (Parallel session) a stability-row probe found NO `:CDB2` entry and concluded "corpse GONE, backend CAN start once pressure drains" — see Falsification F2 below.                                                                                                                    |
| 04:39–04:44 (this session)        | Rootless diagnosis (systemctl is blocked in the agent sandbox): `journalctl -u fastflowlm` + `/proc/net/tcp` hex grep + `/proc/*/fd` inode walk. Found the gatus↔pocket-id established pair, no flm process/zombie, no LISTEN on 52626.                                              |
| ~04:40                            | User: `sudo systemctl restart gatus` → pair drops to state `06` (TIME_WAIT, uid 0, inode 0). User: `reset-failed` → "Unit fastflowlm.service not loaded" (harmless — unit GC'd; the `&&` skipped the socket start).                                                                  |
| 04:41:30                          | Socket started (user), client connect pulled the backend up: `Loading model: /data/ai/models/fastflowlm/models/Qwen3.6-35B-A3B-NPU2`.                                                                                                                                                |
| 04:42:25–31                       | **Guard Zone-6 trip #1468** (io PSI avg60 = 61.13%, max disk busy 70.2%, MemAvailable 63.8%): stops sockets + `fastflowlm.service` mid-cold-load (15 GB read at death; 30.2G mem peak). Trip top-io: `system.slice +24.3 GB`, `user.slice +10.6 GB` per window.                      |
| ~04:42–04:44                      | More trips logged (04:21 #?, 04:32 already before); `restore capped (3 restores today >= 3)` at 04:17 and 04:31 — auto-restore dead for the day.                                                                                                                                     |
| 04:44 (check)                     | Live PSI still storming: `some avg10=57.79 avg60=60.21 avg300=65.89`. Top reader: `tq agent-pool` — **168 GB** `read_bytes` (proc 3791468); project-discovery-daemon 9.2 GB distant second. Advice: wait for calm, then manual `systemctl start fastflowlm.socket` (restore capped). |
| ~04:50                            | User attachment: `curl http://127.0.0.1:52625/v1/models` → **200, 36 models**. flm UP.                                                                                                                                                                                               |

## Evidence (reproducible)

```bash
# 52626 in hex = CD92 — /proc/net/tcp lists HEX; decimal greps false-negative
grep -i CD92 /proc/net/tcp
# pre-fix: two state-01 (ESTABLISHED) rows, uids 63216 (gatus) and 970 (pocket-id)
# post-gatus-restart: single state-06 (TIME_WAIT) row, uid 0 inode 0 → self-expires

# who owns the uids
getent passwd 970 63216   # pocket-id, gatus (DynamicUser)

# no flm anywhere (rules out the corpse class)
ps -eLo pid,ppid,stat,comm | grep -i flm          # empty
ps -eo pid,stat,comm | awk '$2 ~ /Z/'             # no zombies

# inode→process walk found NO owner for either socket fd (live services hold them)
```

**Why bind fails with no LISTEN socket:** an ESTABLISHED connection with local port 52626 is enough — flm binds without SO_REUSEADDR, and any live socket on the addr:port (established or TIME_WAIT) makes `bind(2)` return EADDRINUSE.

## New knowledge / falsifications

- **F1 — "ONLY a reboot releases the socket" is SUPERSEDED for the non-corpse variant.** AGENTS.md (flm section) says SIGKILL is meaningless and only a reboot frees :52626. True for a flm corpse (unreapable zombie threads). False for the new variant: when the holder is a **live foreign service**, restarting THAT service releases the port — no reboot. Distinguisher: corpse = dead flm threads present; orphan-pair = no flm process, established pair with foreign uids.
- **F2 — the stability row closed 2026-09-30 00:15 as "DONE-MOOT (corpse GONE)" was falsified ~6 min later** — the backend died 3× on EADDRINUSE at 00:21–00:22. Its closure was honest at probe time but (a) the pin came back in a different shape within minutes and (b) **the row's probe hex is wrong**: it greps `:CDB2` "=52626", but 52626 = **0xCD92** (0xCDB2 = 52658). A CDB2 grep false-greens this check forever. Annotated in `docs/todo/stability.md`.
- **F3 — `curl: (1) Received HTTP/0.9 when not allowed` was a red herring**, not a bridge/socat bug: the client connected, the backend began cold-loading, then the guard killed the unit mid-load and the socket served teardown garbage. Any "garbage bytes on the flm port" symptom should first be checked against guard trips in the same minute (`journalctl -u memory-emergency-guard --since ...`).
- **F4 — the IO storm's dominant reader is the tq agent-pool (168 GB cumulative read)** at check time, an order of magnitude above everything else. This strengthens the existing `docs/todo/stability.md` row "IO admission for tq pool + parallel build slices" (from the 03:29 report); no new row added (no dupes).
- **F5 — `systemctl reset-failed` on a GC'd unit errors "Unit not loaded"** — harmless, but under `&&` it silently skips the chained next command (the socket start). Use `;` or `systemctl start` directly.

## a) FULLY DONE

1. Root-caused the flm outage to the orphaned gatus↔pocket-id socket pair on :52626 (new failure variant, fully evidence-backed above) — despite `systemctl` being blocked in the agent sandbox (worked rootless via `/proc/net/tcp` + `/proc/*/fd` walks).
2. Executed the recovery path end-to-end through the user: gatus restart → TIME_WAIT expiry → socket start → backend cold load → **`/v1/models` 200 with 36 models (flm serving, confirmed by user attachment)**.
3. Correctly triaged two red herrings mid-recovery: the harmless `reset-failed "Unit not loaded"` and the `HTTP/0.9` garbage (F3, guard kill).
4. Identified the actual storm driver (tq agent-pool, 168 GB) and the restore-cap state (3/3) — the two facts that decide when/how flm may return.
5. Zero code/config changes; nothing committed by this session (pure diagnosis + docs).

## b) PARTIALLY DONE

1. **The gatus↔pocket-id pair is explained WHO, not WHY.** Neither direction fits normal socket semantics: gatus (a client) holds LOCAL port 52626 — not in any ephemeral range — and its peer is pocket-id on :1411 (also below the default ephemeral range). No gatus endpoint may probe flm ports by doctrine. Something created this pair; I identified the holders and freed the port but did not find the creating path (folded into the monitoring harvest item below).
2. **AGENTS.md memory update** — the supersession (F1) and the hex lesson are written in this session's harvest (flm bullet annotation), but a fuller rewrite of the corpse bullet (variant table, diagnosis flow) was left as a follow-up to keep the mid-storm session surgical.
3. **Guard notify delivery unverified** — the guard logged `restore capped` twice today; I did NOT verify the sev1 `FLM RESTORE CAPPED` notify actually reached DMS/Discord (log line ≠ delivery).

## c) NOT STARTED (identified this session, untouched)

1. Gatus endpoint audit for flm-port probes (must be zero) + root-cause the mystery pair (b1).
2. Pre-bind forensics on `fastflowlm.service` (self-diagnosing EADDRINUSE — see f2).
3. tq agent-pool IO admission decision (existing row; today's datapoint strengthens it — still unowned).
4. flm v1.0.6 staged-bump probe (existing ai-stack row; today's banner again advertised v1.0.6).
5. Recovery runbook for this class (holder-restart procedure) — nowhere written until today's AGENTS.md annotation; a proper runbook entry is still open.

## d) TOTALLY FUCKED UP

1. **My first recovery advice skipped the pressure check.** I told the user to start the socket and probe (cold load = 2–5 min) WITHOUT checking `/proc/pressure/io` or the guard state first — even though AGENTS.md's freeze doctrine explicitly says never start flm's resident load into a storm. Result: the user's 04:41 curl cold-loaded 21.6 GB INTO an active Zone-6 storm (avg60 ~60%), the guard had to kill it mid-load (trip #1468), adding ~15 GB of IO to the exact storm I was supposed to respect. The correct sequence was: PSI check → calm → manual start. The user's patience covered for me; the second attempt (after the storm dipped) succeeded. This is the session's one real own-goal.
2. Minor: first port probe grepped the wrong hex (`:CDA2`) — 52626 is `CD92`. Caught on the next command, but it cost a round trip and is exactly the decimal/hex confusion that also poisoned the 00:15 stability row (F2).

## e) WHAT WE SHOULD IMPROVE

1. **Pre-flight before ANY flm (or heavy-model) start: PSI + guard state, always.** `/proc/pressure/io` avg60 and `journalctl -u memory-emergency-guard --since '-15min'` are two commands; skipping them turns a recovery into a storm contributor. Worth a line in the flm runbook and in agent muscle memory.
2. **Rootless systemd diagnosis is viable and should be first-choice in sandboxes:** `/proc/net/tcp` (hex!), `/proc/*/fd` inode walks, `getent passwd`, `ps -eLo`. systemctl being blocked is not a diagnosis blocker.
3. **Make EADDRINUSE self-diagnosing** (f2): the unit should journal the port's socket states + owning uids on bind failure, so the next occurrence is a `journalctl` read, not a 20-minute forensic session.
4. **Port-forensics greps must be hex-normalized** — one bad hex in a harvest row survived a full closure review (F2). Any runbook that greps `/proc/net/tcp` should carry the decimal→hex conversion inline.

## f) Up to 50 things to get done next

Honest count from THIS session's scope: **13 items** (5 new/harvested, 8 pointers to existing rows or watch items). I am deliberately not padding to 50 — everything else I could list would be fabricated scope outside this session's evidence, which the task forbids.

**New (harvested at authoring time — see Harvest record):**

1. `[ready]` **Pre-bind port forensics ExecStartPre on fastflowlm.service** — on EADDRINUSE, journal `/proc/net/tcp` entries for `:CD92` + owning uids + a corpse-check (`ps` for flm threads) before exiting; turns the corpse-vs-orphan-pair distinguisher (F1) into a log line. → stability.md
2. `[ready]` **Gatus flm-port audit + mystery-pair root-cause** — assert zero gatus endpoints target 52625/52626 (doctrine: Gatus must never pin the model); explain how a gatus-owned socket got LOCAL port 52626 with a pocket-id peer on :1411 (check `net.ipv4.ip_local_port_range`; 1411 is below the default ephemeral range — something is nonstandard). → monitoring.md
3. `[decision]` **Guard restore-cap policy (3/day) review** — today the cap kept flm dark even after the port was freed; the sev1 FLM-RESTORE-CAPPED notify exists but the POLICY (cap size, or a manual-start nudge to the user) is owner territory. → stability.md
4. `[decision]` **Upstream ask: bind resilience for flm** — SO_REUSEADDR or graceful rebind on the backend port would make the whole class self-healing (verify-before-filing gate first; upstream is active — v1.0.6 banner). → upstream.md
5. `[watch]` **Verify sev1 FLM-RESTORE-CAPPED + trip notifies actually delivered today** (guard log lines exist; delivery to DMS/Discord unverified). → monitoring.md (watch)

**Existing rows this session strengthens (no new entries — no dupes):**

6. `stability.md` "IO admission for tq pool + parallel build slices" — today's 168 GB tq datapoint is the strongest yet; still needs the owner tradeoff call.
7. `stability.md` DONE-MOOT row — annotated (not reopened); its hex bug fixed in the annotation.
8. `ai-stack.md` "FastFlowLM staged go-live v1.0.2 → v1.0.6" — unchanged; today adds one more clean cold-load proof on v1.0.2 (and one more guard-kill reminder that socket health ≠ binary health).

**Watch / small (from this session's observations, not yet harvested):**

9. `[watch]` Post-recovery idle-TTL behavior: confirm the model unloads after the 1h idle window now that it's warm (it should; nothing suggests otherwise).
10. `[watch]` PMA commit health during the pin window (00:21–04:50): the enricher/go-commit consumers silently degraded; check today's `heuristic_fallbacks_24h` for whether the pin window shows up there (metrics exist, one query).
11. `[watch]` flm's per-start "New version detected!" banner is journal noise on every activation; check upstream for a quiet flag before the next bump.
12. `[ready]` Fold F5 (`reset-failed` under `&&` skips the chained command) into the systemd gotchas the next time that file is touched — one-line lesson, not worth its own session.
13. `[watch]` After the tq storm drains, re-check Zone-6 trip count for today; if trips continue with tq idle, the driver attribution needs a second look.

## g) Questions I cannot figure out myself (3)

1. **tq agent-pool vs IO storms:** the pool was the storm's dominant reader (168 GB). Do you want harvest velocity preserved (accept Zone-6 trips + flm dark during heavy harvest), or should I wire the pool through IO admission (heavy-job routing / `io.max` on its cgroup / storm-aware concurrency cap) — knowing it slows harvests? (This is the owner tradeoff the existing stability row has been waiting on; today adds a flm-outage cost to the "accept" side.)
2. **flm bump policy:** upstream is at v1.0.6 while we hold v1.0.2 (the 1.0.3 revert + crash history). With the corpse obstacle gone and today's clean cold-load, do you want the staged v1.0.6 go-live probed this week (live-serve validation + one-time weights re-pull discipline), or does v1.0.2 keep serving until a release notes a fix for the v1.0.2 crash class?
3. **The mystery pair's origin:** did anything on your side around 00:15–00:25 touch gatus or pocket-id — a manual curl at the flm/dashboard endpoints, a gatus config reload, or any script that would chain gatus↔pocket-id connections? I can audit gatus's rendered config for flm probes myself (and will), but a socket with LOCAL port 52626 on a client process doesn't arise from any config I know — knowing what was run in that window would cut the investigation to minutes.

## Harvest record (mandated by AGENTS.md TODO System)

| Item                                                   | Landed in                                                                                       |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| Pre-bind forensics ExecStartPre                        | `docs/todo/stability.md` (new `[ready]` row)                                                    |
| Restore-cap policy review                              | `docs/todo/stability.md` (new `[decision]` row)                                                 |
| Gatus flm-port audit + :1411 mystery                   | `docs/todo/monitoring.md` (new `[ready]` row)                                                   |
| FLM-RESTORE-CAPPED delivery verification               | `docs/todo/monitoring.md` (new `[watch]` row)                                                   |
| Upstream SO_REUSEADDR ask                              | `docs/todo/upstream.md` (new `[decision]` row)                                                  |
| DONE-MOOT row correction (falsified closure + hex bug) | annotated in place, `docs/todo/stability.md`                                                    |
| AGENTS.md flm bullet supersession (F1) + hex lesson    | annotated in place, `AGENTS.md` (flm corpse bullet)                                             |
| tq IO admission, flm v1.0.6 bump                       | deliberately NOT re-harvested — existing rows own them (no-dupes rule); referenced as §f.6/§f.8 |

_Deliberately not harvested:_ §f.9–13 (watch items below the queue bar; re-evaluate on next touch).
