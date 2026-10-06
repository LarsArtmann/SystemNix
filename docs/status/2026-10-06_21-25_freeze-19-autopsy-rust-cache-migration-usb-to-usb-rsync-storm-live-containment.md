# Freeze #19 Autopsy — the Rust-Cache Migration's Own USB→USB rsync; Live Containment Executed on Boot 0 (2026-10-06)

**Session:** 2026-10-06 ~21:10 → ~21:25 — trigger: user asked "Why did we crash this time? DEEP DIVE!" after the 21:09 boot. Read-only forensics + ONE live containment action (SIGSTOP of the re-fired migration, freeze-5/6 doctrine). Autopsy of the 10-06 21:08:23 cut (#19 = boot -1, the post-#18 recovery boot, 5 h 26 m).

**Sibling context:** freeze #16/#17 autopsy (`15-30`), freeze #18 autopsy (`16-02` — predicted this cut at close: "freeze #19 conditions live at close"), rust-cache-ssd-split (`20-18` — the migration script that became the trigger landed THIS death boot, 2 h 50 m before the cut). FIFTH consecutive cut predicted by its predecessor's autopsy (#14→#15, #15→#16, #16/17→#18, #18→#19) with zero owner-leg execution between.

## Verdict

**Freeze #19 = the crash-#3/#6 stacked-full-disk-reader IO-collapse class, and for the first time in the family the acute trigger is NAMED, numbered, and ours: the rust-cache maintenance migration itself — `mkfs.btrfs` + a 79 GB USB→USB `rsync -a --delete /mnt/buildcache/rust/ → /mnt/rust-cache/rust/` — executed mid-storm, unserialized, with a parallel cargo/git/go battery in the same session.** Boot -1 rode the chronic Zone-6 storm whole-life (32 trips #2076 → #2107 at the ~10-min cadence, first ENTER of thermal-pstate-guard 6 min in at 96 °C); the migration mkfs'd sdc1 at 20:33 and re-ran `mkfs -f` + mounted at 21:04; trip #2107's own forensic bundle (21:01:56) caught the collapse: **loadavg 748.97, IO PSI some avg10 96.78 % / full 76.30 %, memory HEALTHY (44.2 GB of 130.4 GB available, memory PSI 3.6 %), CPU idle-in-wait (CPU PSI 0.5 %)** — pure IO livelock, with the D-state army naming the choke points: `jbd2/sdb1-8` (the ext4 buildcache journal), `flush-8:16` kworkers in `rq_qos_wait`/wbt throttle, `usb_sg_wait` (USB storage stack), and the workload itself blocked: `cargo-audit` (`blk_mq_get_tag`), 4× `git`, `go`, `rm` (all `wait_transaction_locked` on the sdb1 journal). Session-3072.scope (opened 19:19) alone moved **+47.7 GB in the final 10-min trip window** (user-1000 total +70.8 GB). Thermal re-entered throttle at 96 °C 21:06:00–:30 (4 ENTER-unit ticks), SEV1 latched `GUARD TRIPPED; FLM RESTORE CAPPED` at 21:07:50 — the family's death signature — and the journal cut mid-traffic at 21:08:23, zero shutdown ceremony, 0 OOM/MCE/BTRFS kernel events, last deploy 18:36 (NOT mid-deploy). Guard counter continuity held (#2107 → #2108).

The migration is a textbook violation of three standing rules at once: "serialize full-device readers" (freeze #3 — source AND dest are full-disk endpoints on the SAME USB DAS bus), "route repo-tree/heavy scans through heavy-job" (freeze #4), and "after a freeze, STOP the resumable readers at the next boot" (freeze #6 rule a) — instead it was RE-FIRED 90 s into the recovery boot (21:11) and had boot 0 at trip #2108 / IO PSI 85 % / sdb io_ticks 100 % within 3 minutes (freeze #20 forming live at autopsy time). **Live containment executed ~21:21: SIGSTOP on the migration wrapper + rsync PIDs (21006/23860/23861/23862) — fully reversible, `rsync -a` re-runs converge; within 60 s loadavg fell 34→9.6 and sdb io_ticks 100 %→~0.** The chronic physical cooling deficit (#8/#9/#11–#19) remains the standing amplifier — thermal re-entered 96 °C during the livelock — but #19's acute, preventable trigger is our own unserialized migration, not the deficit alone.

## Evidence

| # | Finding | Evidence |
|---|---------|----------|
| 1 | #19 hard cut, no ceremony | boot -1 (15:42:46 → 21:08:23, 5 h 26 m) ends on healthy ms-latency traffic (cv /health 200s, browser-history 200s, storage-collector WARNs); no shutdown/Stopping sequence in the tail; boot 0 starts 21:09:52 |
| 2 | Pure IO collapse, memory/CPU healthy | trip #2107 bundle `io-psi-forensics-20261006T190155Z/meta.txt`: loadavg 748.97/422.06/320.72, 7549 tasks; `psi.txt`: IO some avg10 96.78 / full 76.30, memory some 3.63, CPU some 0.51; MemAvailable 44.2 GB / 130.4 GB |
| 3 | Choke point = ext4 buildcache journal + USB stack | same bundle `dstate.txt`: `jbd2/sdb1-8` in `jbd2_journal_wait_updates`; 6× `flush-8:16` kworkers in `rq_qos_wait`/wbt_wait; `usb-storage` in `usb_sg_wait`; D-state userspace: cargo-audit (`blk_mq_get_tag`), git×4, go, rm (all `wait_transaction_locked` = jbd2) |
| 4 | The migration is the death-window workload | sudo journal boot -1: `mkfs.btrfs -L rust-cache … /dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713-part1` at 20:33:46 (pts/5), `mkfs.btrfs -f` + `mount` + mkdir/chown at 21:04:17–:19 (pts/37); trip #2107 (21:01:56) attribution: `session-3072.scope +47,721 MB`, `user-1000.slice +70,805 MB` in one 10-min window; source `/mnt/buildcache/rust` = **79 GB** |
| 5 | Escalation ramp into death | trip windows (10 min each): #2104 +8.5 GB, #2105 +9.4 GB, #2106 +27.0 GB, #2107 +71.6 GB — the migration + battery ramp from 20:52 |
| 6 | Whole-boot chronic storm | 32 Zone-6 trips #2076 (15:47) → #2107 (21:01) at ~10-min cadence; thermal ENTERs 15:48:39 (96 °C), 17:06, 18:23, 19:59, and 21:06:00–:30 (4 ENTER-unit ticks, last 113 s before the cut); EXIT only 4× — the boot spent most of its life ≥95 °C or within the re-entry band |
| 7 | SEV1 death signature | `SEV1 active (2 conditions): MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED` at 21:07:50–:57 (severity notify — policy held); guard check ran to 21:06:27; thermal unit ticks stopped after 21:06:30 while other units logged to 21:08:23 = the small-oneshot starvation ladder (freeze #3) |
| 8 | Not OOM/MCE/storage-error, not mid-deploy | boot -1 kernel scan: 0 OOM-kill, 0 MCE (beyond boot init), 0 BTRFS error lines; last switch-to-configuration 18:36:40 (`test`), 2.5 h pre-cut — excludes #4/#5 class |
| 9 | Guard counter continuity held 4th consecutive cut | #2107 (boot -1) → #2108 (boot 0, 21:12:20) |
| 10 | Freeze #20 was forming live on boot 0 | migration re-fired 21:11 (pts/6, `migrate-rust-cache` + rsync, 19→27 GB of 79 GB at ~2.7 GB/min); trip #2108 at 21:12:20 (avg60 53.2 %, disk busy 96.0 %, MemAvail 75.7 % — the guard's own line names "the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy"); live probe: sdb io_ticks 5013 ms/5 s (100 %), rsync ≈960 MB read + 984 MB write per 5 s, crush +117 MB/5 s; IO PSI some avg10 85.5 %, loadavg 34 climbing |
| 11 | Containment worked in <60 s | SIGSTOP 21006/23860/23861/23862 at ~21:21; 30 s later: loadavg 9.61, sdb io_ticks 2 ms/5 s, IO PSI some avg10 61.1 and draining |
| 12 | journald was 2 h behind at death | tail lines written 21:07:58 carry storage-collector inner timestamps 19:07:55 — delivery lag ≈120 min under the storm; last-node_exporter lines carry ~20 s lag; the cut is real either way (boot 0 starts 21:09:52) but tail timestamps ≠ event times under terminal PSI |

## Live regime at authoring

- Boot 0, post-containment: loadavg ~9 falling, sdb ~idle, IO PSI draining (avg10 61 → falling), migration SIGSTOPPED at 27/79 GB (`kill -CONT 21006 23860 23861 23862` resumes; a fresh `nix run .#migrate-rust-cache` re-runs converge — proven twice today). flm socket down per trip #2108 (guard restore-gated; will self-restore).
- The migration must NOT be resumed until the box is quiesced (see §f.1) — resuming into PSI ≥40 % re-creates #19/#20 conditions.

## a) FULLY DONE

1. Full #19 autopsy with all portable discriminators answered (table above); classified IO-collapse class with the acute trigger NAMED (the migration rsync/mkfs battery) on top of the chronic thermal deficit.
2. Live writer attribution per the documented protocol (5 s `/proc` io deltas + `/sys/block/*/stat` deltas) — named rsync (960/984 MB per 5 s) and crush, mapped the saturation to sdb (io_ticks 100 %), BEFORE containment.
3. **Live containment executed**: SIGSTOP of the re-fired migration within ~10 min of the recovery boot's trip #2108; verified drain (loadavg 34→9.6, sdb→idle). The first freeze-6-rule-(a) execution as it was written.
4. Guard counter continuity verified (#2107→#2108); kernel OOM/MCE/BTRFS scans clean; deploy-in-flight excluded (last switch 18:36).
5. Death-window regime quantified from the guard's OWN forensic bundle (io-psi-forensics zone6-trip transient, `/var/tmp/io-psi-forensics-20261006T190155Z`) — the first death where the box pre-staged its own evidence.

## b) NOTICED, NOT DIAGNOSED

1. The 20:33→21:04 gap: mkfs #1 (no `-f`) then a 31-min hole, then `mkfs -f` re-run — attempt #1 evidently wrote a filesystem (hence `-f` needed) but never mounted; what ran in the hole (the +27 GB #2106 window: cargo-audit/git/go battery vs an rsync into a dangling automount) is not per-command attributed. The battery itself (cargo-audit, git, go) is NOT part of migrate-rust-cache.sh — a second workload rode the same session.
2. cv fired `LowDiskSpace` (value 90.20 vs threshold 90.00, consolidated monitor) at 21:08:00 — pre-existing disk-full warning, not decomposed this session.
3. journald's 2-hour delivery lag (finding 12) — quantified, not root-caused (rate-limiting vs kmsg backpressure under PSI).
4. sdb io_ticks 100 % with only ~0.7 MB/5 s of DEVICE traffic in the live probe (rsync reads mostly page-cache hits) — consistent with wbt-throttled queue-latency saturation rather than throughput saturation; the 2026-10-05 "device-hang is the LAST hypothesis" correction stands, and the post-containment instant drain (2 ms/5 s) supports "saturated, not hung".

## c) DELIBERATELY NOT DONE

1. No resume of the migration — owner's window decision (§g.1); resuming mid-drain would re-fire #20.
2. No module edits (PSI gate for migrate scripts is a queue row, §f.1; mid-storm surgery needs the very builds the gate forbids).
3. pstore/btrfs-sysfs reads — standing owner-gated sandbox rows; kernel-log-clean stands as the weaker proof, as in #14–#18.
4. No ClickHouse thermal series extraction — same mid-storm cost argument as #14–#17; the guard's ENTER series carries the ceiling.
5. No stability.md freeze-entry writing — the standing #8–#13 backlog row owns it; #19 draft material appended there instead (§f.4).

## d) SELF-CRITICISM

1. First SIGSTOP attempt failed on the mvdan/sh `kill` builtin (no `-STOP` support) — burned a cycle at the exact live-risk moment; store-path binary used on retry. Under containment pressure, lead with absolute binary paths.
2. I nearly pattern-matched #19 to "thermal family again" from the prior report titles before the bundle named the rsync — the family label would have buried the NEW acute trigger. Lesson: assert the MECHANISM (which device, which D-state, which session), never the family name.
3. Containment came ~10 min after boot 0's trip #2108 (21:12) because the autopsy ran first — the freeze-6 doctrine says stop resumable readers at the NEXT boot, immediately. Under a live storm, containment outranks diagnosis.

## e) WHAT WE SHOULD IMPROVE

1. **Maintenance-window scripts are heavy jobs and must gate themselves**: `migrate-rust-cache.sh` (and the migrate-* class) needs a pre-flight PSI/thermal entry gate (refuse when IO PSI avg10 ≥ ~30 % or Zone-6 tripped within the hour), a `heavy-job` wrap, and USB→USB copies documented as dual full-disk readers (serialize; quiesced window only). Today the script ran twice mid-storm and killed the box once.
2. **The freeze-6 rule (a) needs automation**: a boot-ordered unit that pauses known resumable readers (crush-hot-db-migrate, discordsync-db-heal, migrate-rust-cache/rsync) while the guard is trip-active — today's re-fire 90 s into the recovery boot is the second crash-loop amplifier proof after #6.
3. **A crash should not be answerable by "re-run the script" within minutes** — the migration re-fired because it is idempotent AND un-gated; idempotency without an entry gate converts every crash into a crash loop.

## f) NEXT THINGS (self-harvested at authoring; routed per TODO rules)

1. **[ready] Entry gate + serialization for migrate-* maintenance scripts** — NEW row (stability.md library + TODO_LIST queue): pre-flight PSI/guard-active gate, heavy-job wrap, USB→USB = dual full-disk reader rule. **Source:** this report §e.1.
2. **[ready] Post-crash resumable-reader pause automation (freeze-6 rule a)** — NEW row (stability.md): boot-time pause of known resumable readers while guard-active; re-proven by the 21:11 re-fire. **Source:** this report §e.2.
3. **[blocked:user] physical cooling inspection** — standing row EXTENDED: BAIT TAKEN a 7th TIME (#19, migration-triggered IO collapse riding the deficit; thermal re-entered 96 °C during the livelock). **Source:** this report Verdict.
4. **[ready] Write the missing freeze #8–#13 entries** — standing row EXTENDED with #19 draft material (Verdict + Evidence table). **Source:** this report.
5. **[owner/live] Resume the migration in a quiet window** (`kill -CONT 21006 23860 23861 23862` or re-run; finish the remaining ~52 GB; then the rust-cache report's §f.6–10 post-migration proofs) — not a queue row; the owner's window call.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. When to resume the migration — now that the box drains within a minute of stopping, a quiesced evening slot (guard clean ≥1 h, PSI <20 %) finishes it in ~30 min without crash risk. It is currently SIGSTOPPED at 27/79 GB on pts/6.
2. Cooling inspection scheduling — nine cuts on one deficit; #19 proves even a "software-only" maintenance task now needs the box calm, which the deficit increasingly denies.
3. Whether the fish-guard/bc-fallback path held for any shells opened between the 18:36 deploy (rust-cache config) and the 21:04 mount — i.e., did anything write CARGO_HOME into the dangling automount era? (Only you know what terminals you opened 18:36→21:04.)

**Standing state at report close:** freeze #19 autopsied (IO-collapse class, migration-triggered, deficit-amplified); guard counter continuity intact (#2107→#2108); boot 0 CONTAINED (migration SIGSTOPPED, loadavg falling, PSI draining, flm socket guard-gated); freeze #20 averted pending the owner's resume-window call; migration 27/79 GB.

_Arte in Aeternum_
