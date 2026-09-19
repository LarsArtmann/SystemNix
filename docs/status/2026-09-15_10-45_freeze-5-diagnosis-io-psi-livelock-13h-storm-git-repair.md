# Freeze #5 Diagnosis — 13-hour IO-PSI livelock, hard reset, git object loss (session report)

**Date:** 2026-09-15 10:45 CEST
**Session type:** Incident diagnosis + emergency git repair
**Scope:** The "how did we crash this time" investigation of the 09:32:40 unclean death (boot -1), collateral repo repair, and the live-recurrence check in the current boot.

---

## Executive summary

The box froze at **09:32:38** (boot -1, kernel 7.2.5, up since 2026-09-14 20:16:40 — 13 h 16 m uptime) — journal cut mid-normal-activity, **no shutdown record in wtmp, no panic, no vmcore** = the scheduler-livelock class (#3/#4 lineage). Hard reset, back at 09:36:59.

This freeze was NOT an ambush: **the machine spent its entire last boot inside an IO-PSI storm and died at its far end.**

1. **The storm predated the boot.** Guard Zone 6 (IO-PSI) read avg60=46%, disk busy 99.7% **two minutes into boot -1** (20:18) — carried over from boot -2, which itself ended at 20:11:57 mid-activity with ClickHouse at "100% busy for 600s", PMA git staging failing (exit 128), and a parallel session already capturing io-psi-forensics bundles.
2. **All night 20:16 → 09:32**: IO PSI some avg60 oscillated 45–98% with the data disk pinned at 100% busy, **while MemAvailable stayed healthy at 48–84% the whole time** — memory was never the constraint. The guard tripped Zone 6 continuously (cumulative trip **#107** logged at 20:22:38; FLM sacrificed pointlessly, restore capped). Gatus "I/O Stall Rate" ran red through the night (resolved once at 08:30:55, re-armed); **"Stuck D-State Processes" TRIGGERED at 09:08:41**.
3. **Terminal state** (forensics bundle captured by the zone6-trip hook at 09:25:13, 7 min before death): IO PSI some avg60=**97.7%**, **full avg60=71.4%** (every task on the box stalled 71% of wall time), load 311/536/582, 6216 threads, memory PSI ~5%, CPU PSI ~4%. Journal cut at 09:32:38 between completely normal entries (PMA batches, discordsync requests, gatus checks).

**Drivers** (cgroup `io.stat`, cumulative over the 13 h boot — the QLC root NVMe absorbed ~**1 TB read + 277 GB written**):

| Cgroup                                                                    | IO (r+w) | What it is                                                                                        |
| ------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------- |
| system.slice total                                                        | 1.58 TB  | everything below + the rest                                                                       |
| user-1000.slice                                                           | 511 GB   | interactive + agent crush sessions (one `session-257.scope` alone: 238 GB)                        |
| nix-daemon.service                                                        | 205 GB   | builds — 9 parallel `ld.mold` linkers seen D-state in `balance_dirty_pages` at 09:25              |
| user-975 (hermes)                                                         | 170 GB   | gateway + cron external-workers cycling every 2–4 min                                             |
| tq-agent-pool.service                                                     | 133 GB   | agent pool (daily budget 30/30 exhausted by morning)                                              |
| llama-embeddings + llama-reranker                                         | 103 GB   | **the 09-14 "containment" did not survive the reboot — units re-armed at boot and ran all night** |
| clickhouse / papdashboard / project-discovery / journald / coredump-slice | ~145 GB  | steady service churn                                                                              |

Plus the one-USB-link class at death: `usb-storage` kthread stuck in `usb_sg_wait`, a flush kworker stuck in `blk_mq_get_tag` on 8:16 (USB-attached disk queue full), `node-MainThread` in `read_extent_buffer_pages`, sqlite3/grep in `folio_wait_bit_common`.

**Collateral damage — this repo's git (repaired this session):** PMA's auto-commit at 09:32:11 (27 s before the cut) lost its objects to the freeze: the commit object `4f0b9081` and three staged blobs (`flake.lock` `1a7c4c11`, the 09-22 status doc `2598286203`, `modules/nixos/services/nix-email.nix` `a6b15010`) survived as **zero-byte files**; the ref update survived, the reflog line did not. Symptom: `fatal: bad object HEAD`. A parallel session repaired the ref to the last durable commit (`689e6c10`, reflog "recover:" entry 10:26); this session restored all three blobs **hash-exact from the working tree** via `git hash-object -w`. Repo-wide zero-byte-object sweep across `~/projects` + `~/forks`: **no other repository damaged**.

**The storm partially recurred in the current boot:** IO PSI full avg60 39% at 10:09 → 21% at 10:40 (decaying; spread across agent sessions + kernel writeback, no single hog >100 MB/12 s by 10:24), and **both llama-servers re-armed a third consecutive boot**, wedged in the documented mid-load CPU-spin (~95% of a core each, 2762 s CPU in ~3040 s wall). The freeze-#4 recommendation (`services.llama-rag.enable = false` — declarative, not `systemctl stop`) is still not deployed.

---

## a) FULLY DONE (this session)

1. **Death time + mode pinned**: boot -1 journal last entry 09:32:38.334 (pam session-close on normal chatter), boot 0 at 09:36:59, gap 4:20 min; `last -x` shows no shutdown record; `/var/crash` empty (no vmcore — livelocks never panic, kdump cannot capture this class). Freeze #5, hard reset.
2. **Guard history for the whole dead boot extracted**: Zone 6 active from 20:18 (2 min after boot, avg60=46.2%, disk 99.7%, MemAvailable 83.9%) through 09:31 (avg60=68.5%, MemAvailable 70.6%); first action of the boot = trip #107 (20:22:38, sockets + flm stopped); `FLM RESTORE CAPPED` all morning; guard had no lever against the actual drivers.
3. **Pre-crash terminal state recovered** from the zone6-trip forensics bundle `/var/tmp/io-psi-forensics-20260915T072513Z/`: PSI full avg60=71.37% / some=97.74%, load 311–582, 6216 threads, MemAvailable 53.3/130.4 GB, memory PSI ~5%.
4. **IO attribution by cgroup and by disk** (13 h cumulative): table above; diskstats show nvme0n1 (QLC: root `@`/home, `/data`) ≈ 1.03 TB read + 277 GB written vs nvme1n1 (Samsung `/nix`) 114 GB read + 267 GB written — the storm was overwhelmingly a **QLC-root read storm** (agent-session DB/repo churn), not a store problem.
5. **D-state composition at death**: 9× `ld.mold` (`balance_dirty_pages`), `usb_sg_wait`, `blk_mq_get_tag` on 8:16, `read_extent_buffer_pages`, `folio_wait_bit_common` — throttled writers + blocked readers, the livelock textbook picture.
6. **llama containment regression confirmed**: llama-embeddings/reranker each accrued ~50 GB IO in boot -1 (units enabled at boot despite the 09-14 "stopped" containment) and re-armed again in the current boot, spinning ~95%/core.
7. **Git corruption root-caused and repaired**: zero-byte objects from lost page-cache writeback at freeze; ref repaired (parallel session) to `689e6c10`; 3 blobs restored hash-exact with `git hash-object -w`; fsck clean; no damage in any other repo.
8. **Live-recurrence check in current boot**: PSI trajectory measured (55→35→25 avg10 over 20 min), no dominant single process at 10:24 (clean 12 s `/proc/PID/io` delta join).
9. **Boot-drive assessment answered** (user question): Samsung `tlc` has 763 GB free, root `@` needs 464 GB → root can move in as sibling subvols **without repartitioning and without moving `/nix`** (sidesteps the 09-07 stuck-boot `init=` class); effort ≈ half a day + soak. This is the structural fix for the freeze #4/#5 IO-livelock class.
10. **Memory-caps question answered** (user): zram is percentage-based (`memoryPercent = 50`, boot.nix — auto-scaled to 62 GiB at the 124 GiB MemTotal; the 50% sizing lesson already documented), while systemd caps are absolute strings (nix-daemon `MemoryHigh=32G`, user-1000 slice 56G/64G per the live gatus alert text) — they did NOT silently rescale with the carveout flip, which is fine for per-service budgets but worth knowing for machine-level slices.

## b) PARTIALLY DONE / open threads

1. **Storm composition by hour for the dead boot** is cumulative-only (cgroup io.stat counters): the night's peak attribution (which of hermes/tq/agent-sessions dominated at which hours) would need SigNoz PSI/disk telemetry history — not pulled this session.
2. **The 238 GB `session-257.scope`** was identified as the top single cgroup but never mapped to its SSH session/agent (session records rotated).
3. **Why boot -2 ended at 20:11:57**: same abrupt-journal-cut signature (no shutdown record) — either a second unclean death ~5 min before the user reset, or a reset-into-reboot. Not investigated further.
4. **btrfs post-crash fallout not swept** (unclean-shutdown scrub/csum check, DAS link re-verify, `system_lan_nic_present`) — the post-crash peripheral-instability doctrine runbook was not run this session.

## c) NOT STARTED (deliberately or by constraint)

1. **llama-rag declarative disable** — still not deployed (3rd re-armed boot); `systemctl` policy-blocked for the agent; needs `services.llama-rag.enable = false` (or mask) + deploy.
2. **crush-hot-db migration** — built, gated on the /nix soak (~2026-09-17); the largest single structural driver (`.crush` DBs on QLC root) stays in place until then.
3. **Samsung-as-boot-drive migration** — assessed only; no runbook written, no execution.
4. **AGENTS.md freeze-#5 entry** — this report is the source material.

## d) TOTALLY FUCKED UP (lessons, not excuses)

1. **The llama containment failed exactly the way the freeze-#4 report predicted it would.** `systemctl stop` is not containment on this host (stc re-arms stopped units; boots trivially re-arm enabled ones). It re-armed for a THIRD consecutive boot and contributed ~103 GB + 2 spun cores to the death boot. The declarative fix was identified on 09-14 and not deployed before 20:16.
2. **My first live-hog measurement was wrong and nearly named an innocent process.** A `printf` format-argument mismatch in a join/awk pipeline attributed 4.3 GB of IO deltas to the wrong PID (a crush session whose fresh direct delta measured zero). Caught only by re-measuring the named process directly. Same class as the pipeline-masking doctrine: **verify the surprising attribution with an independent direct measurement before acting on it.**
3. **`git add` cannot repair a missing staged blob when the cached stat matches.** After object loss, `git add <path>` no-ops ("unchanged" per index stat) and the missing blob survives every add. `git hash-object -w <file>` is the correct repair — it unconditionally writes, and if the printed hash equals the missing one the index is already correct. (Repos on this box now have two precedents: ref-repair via reflog file + blob-repair via hash-object.)
4. **The guard is structurally incapable of stopping this freeze class.** Zone 6's only lever is sacrificing flm — irrelevant when the drivers are the agent fleet itself (interactive sessions, tq, hermes cron, builds). 107+ trips bought nothing but a capped-restore banner. Containment for IO storms must act on the IO producers (admission control / unit disable), and the structural fix is moving root churn off the QLC (crush-hot-db now, Samsung boot-drive for the class).
