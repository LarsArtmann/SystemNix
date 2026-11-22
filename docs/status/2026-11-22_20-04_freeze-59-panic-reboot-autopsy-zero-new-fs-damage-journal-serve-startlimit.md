# 2026-11-22 20:04 — freeze #59 autopsy: panic-reboot cut at 19:52:29, ZERO new filesystem damage, journal-serve the only service casualty

**Session type:** owner question "Why did we crashed and what got damaged?" — read-only
forensics, no config changed, nothing deployed. All evidence live-probed 19:56–20:04
(boot 0 `69ee350d`, up 19:53:18).

## Verdict

**Freeze #59 of the established thermal/storm family** (ledger: the stability.md thermal
row, baits 1–17; last documented #58 2026-11-18). Boot -1 `e5cad2ec` (since 2026-11-19
00:09:35, 91.7 h) was cut at **19:52:29** and boot 0 started 19:53:18 (49 s gap).

- **Mechanism (kernel-decoded):** boot 0 logs `x86/amd: Previous system reset reason
  [0x00080800]: software wrote 0x6 to reset control register 0xCF9` — the software warm
  reset, i.e. the **panic-reboot path**, armed live via `/proc/sys/kernel`: `panic=10`,
  `softlockup_panic=1`, `hung_task_panic=1`, `hung_task_timeout=120` (+ cmdline
  `nmi_watchdog=panic`). Identical decode to freeze #52 (2026-11-14 report), distinct
  from WDT `0x02000800` (#53) and ACPI power button `0x00200800` (#54).
- **Instant-cut discriminator SATISFIED:** 423 journal lines in the final 29 s
  (19:52:00→19:52:29, ~14.6/s — health checks, CRM requests, SigNoz evals, all
  ms-latency) then the boot marker. Zero shutdown ceremony, zero OOM/MCE/BTRFS-error
  lines in the window. The kernel was alive and serving to the last line; no clean
  `systemctl reboot` trace exists (grep for reboot/shutdown in the 19:47+ window matches
  only the 19-47 report's FILENAME via the pma commit log line).
- **The corner it died in (all probed ≤5 min pre-cut, from the 19:47 halt report):**
  Tctl 98.125 °C / acpitz 98.0 °C at load 32, io PSI some avg60 27–30 % (chronic storm),
  `/` 95 % with **unalloc=0 % meta=86→82 % CRITICAL** (btrfs-health CRITICAL every 5 min
  since ≥ Nov 22 00:01), 4 failed units standing.
- **Honest caveat:** the CF9 decode covers kernel-panic-reboot and an owner-forced
  `reboot -f`/reset-button equally; pstore captured nothing (efi_pstore-only backend,
  `/sys/fs/pstore` empty at boot 0 — `systemd-pstore` skipped on
  ConditionDirectoryNotEmpty; same gap as #52), so no panic text exists. Classification
  as freeze family rests on: no shutdown ceremony, the #52 precedent, and the
  storm+thermal corner; the owner's last sudo was 19:51:51 (mid disk-diagnosis), no
  reboot command anywhere in the journal. If the owner DID hand-reset a wedged session,
  the wedge is still the freeze-class lockup — same proximate cause.

## a) Damage inventory (what got damaged / what did not)

| Surface | Verdict | Evidence |
| --- | --- | --- |
| BTRFS root `nvme0n1p6` (`@`) | **CLEAN** — zero new corruption | clean tree-log replay at mount; `bdev errs … corrupt 1` = the standing baseline since freeze #8 era (Oct 1 report), byte-identical through freezes #12/#13/#18/#59 |
| BTRFS `tlc` `nvme1n1p2` (`/nix`+`/mnt/hot`) | **CLEAN** — zero new corruption | clean tree-log replay; `corrupt 12` = the documented cumulative-historical baseline (static since ≥ Oct 1, static through the #52/#53 cuts) |
| `/data` | not re-probed (not a crash surface; its 386 M counter is the known repair-era artifact) | — |
| Boot chain | **HEALTHY, anchored** | booted gen-1024 (`pwwl6n66`) = `/run/current-system` = `system-1024-link` = newest by number; cmdline init matches; Samsung-first BootOrder held; boot counting worked (gen-1024 entry `+3` → `+2-1`); boot-time `boot-mirror-sync` finished 19:56:27 "OK — 50 entries" (3 min under the storm); the bootctl "Created directory" lines are every-boot normal (boot -1's 00:09:50 run logged the identical set) |
| Git / repo work | **nothing lost** | tree clean; the crash DID eat the pma daemon's in-flight 19:52:24 auto-commit (journal shows the heuristic-fallback commit of report+projects-subvol+flake.lock, but no such commit exists) — the content sat safe on disk and the post-reboot session recommitted it as `7b1669ac5` (19:56:10) + `eee1f24aa` (19:56:19); `git fsck` clean at close-out |
| **journal-serve** (Hauptbuch dashboard) | **DAMAGED — down** | `SQLITE_BUSY (5)` in the cqrs sqlite WAL backfill at boot → status=69/UNAVAILABLE ×5 restarts in 35 s → **start-limit-hit 19:54:13, unit DOWN**; same signature fired once at boot -1's start (Nov 19 00:09:53) and recovered on restart #1 — this boot it burned the budget. OnFailure alert deps fired |
| buildcache-init | self-recovered | TERM-stopped 19:53:35 (boot-time stop/re-run pattern), re-ran OK 19:54:58 |
| system-health-metrics / rust-cache-projects-links / file-and-image-renamer | standing failures, NOT crash damage | 560 / 7 / 2 failure lines in boot -1 respectively |
| btrbk | no in-flight send harmed | only planning-phase sudo helpers at 19:49:43; no btrbk system unit ran in either boot's death window; the 20:00 btrbk sudo activity is the hermes instance's user-level run |

## b) The corner is STILL live (freeze #60 risk, probed 19:56–20:04, boot 0)

io PSI some avg60 52.9→54.8 %, load 24–35, **k10temp 98.4 °C at 19:59 (94.5 °C at
20:03)**; drivers: six+ parallel crush sessions (owner-launched 19:55–19:59, `last -x`),
discordsync-wr 69 % CPU, crm-server 52 %, clickhouse 27 % — on a box whose root FS is
95 % / unalloc=0 % CRITICAL and whose btrbk recovery loop stays frozen (18-59 report:
5-night gap, Nov-16 parent pin, admission guard starving on the same storm). Nothing
about the reboot changed any of the causal stack.

## c) Probes of record

`journalctl --list-boots | tail -4`; `journalctl -b 0 -k | grep -iE 'btrfs|reset|thermal|panic'`;
`journalctl -b -1 --since 19:45 | tail -60`; final-minute density `journalctl -b -1
--since "19:52:00" --until "19:52:29" | wc -l` = 423; `journalctl -b -1 -k | grep -iE
'k10temp|thermal|throttl'`; `journalctl _COMM=sudo --since 19:40 --until 19:53:30`;
`last -x`; `/proc/sys/kernel/{panic,panic_on_oops,hung_task_panic,softlockup_panic}`;
`/proc/pressure/*`; hwmon walks; `df -h`; `journalctl -b -1/-0 -u btrfs-health`;
`journalctl -b -0 -u boot-mirror-sync` + `journalctl -b -1 -u boot-mirror-sync | head`;
`findmnt /boot /boot-mirror`; `readlink /run/{booted,current}-system` + profile listing
by number; `journalctl -b -0 | grep -aE 'systemd\[1\]: .*[Ff]ailed'`; per-unit boot -1
failure counts; `ls /var/lib/systemd/pstore` (empty, expected); `ps` top; pma journal
lines vs `git log --format='%h %ci %s'`.

## d) Follow-ups (self-harvested at authoring time)

1. **journal-serve boot-time SQLITE_BUSY → start-limit-hit** — queued (TODO_LIST +
   docs/todo/services.md): diagnose the boot-time DB lock race (journal-backup sibling
   sharing the same SQLite books-home is the suspect) and add boot resilience
   (RestartSec/start-limit breathing or an explicit wait). Interim owner remediation:
   `sudo systemctl reset-failed journal-serve.service && sudo systemctl start
   journal-serve.service`.
2. **Freeze #59 datum appended** to the thermal-row ledger in docs/todo/stability.md
   (numbering continues #58 → #59; decode + zero-new-damage protocol result recorded).
3. Deliberately NOT harvested (rows already exist and were re-verified live): the deaf
   boot-mirror trigger fix+deploy (TODO_LIST ready row), the quiet-window btrbk unlock,
   the QLC-root dead-bytes reclaim batch (storage.md:3875), and the thermal
   containment strategy (owner verdict 2026-11-14: physical remediation waived —
   software containment only). The storm continuing through boot 0 at 98 °C belongs to
   that standing decision, not a new row.
