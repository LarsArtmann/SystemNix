# 2026-10-12 15:49 — Boot-time dispatch: full status + brutal self-review

Session: the "Boot is slow; should I enable Fast Boot?" dispatch (~13:05 → 15:49),
one agent session among at least three (parallel: crm/PocketID outage + dnsblockd
hang, discordsync backup gate, freeze-28 crash diagnosis, image/go/nix build load).
Format note: `.md` per explicit owner request (repo dispatch convention), not the
skill-default HTML.

---

## a) FULLY DONE

1. **Boot measured end-to-end, chronic series, not a single sample.** Boot 0:
   `14min19.244s` = firmware 1m02.654s + loader 4.036s + kernel 1.909s + initrd
   13.329s + **userspace 12m57.314s**. 16-boot series extracted; userspace
   swings 1m42s → 15m51s (IO-storm class), firmware 62.5-62.7s on 14 boots.
2. **Userspace root causes identified with mechanism, not guesses:**
   - `llama-chat` ~13min of critical path: ExecStartPost probe budget (240 × 2s
     = 8min) exhausted exactly as the 23.4G page-in starved → status=22 →
     Restart=on-failure → full 4m36s remap on attempt 2.
   - `pool-usb-recovery` 12m44s wall / 193ms CPU: blocking `systemctl start`
     serialized convergence behind the slowest consumer + held the flock.
   - `discordsync-db-heal` 12m44s wall / 193ms CPU: unconditional GB-scale
     integrity_check starved on the QLC root.
   - `clickhouse` 10m52s starting (state findmnt-verified on QLC root subvol) —
     the storm's eye; `crush-hot-db-migrate` 10m2s its timer-fed contributor.
   - `btrfs-compsize` OnBootSec=5min fired into the storm, timed out (530ms
     CPU / 2m08s wall) → OnFailure noise.
   - `forgejo` DNS-gate override (60s) undid the library's ratified 180s
     slow-boot fix → 5 restarts + start-limit-hit + 4 dependent unit failures.
3. **Four fixes landed, eval-gated, deployed, live-asserted:**
   - pool-recovery.nix: `systemctl start --no-block` ×2 (store-script verified).
   - btrfs-health.nix: compsize OnBootSec 5min→30min, TimeoutStartSec 120s→10min.
   - forgejo.nix: both DNS gates drop `maxAttempts = 30` (inherit 180s; store
     script `seq 1 90` verified).
   - llama-chat.nix: ExecStartPost `--retry 240→400` (~13.3min budget inside
     the 15min TimeoutStartSec).
   - `nix flake check --no-build` green (all eval audits), treefmt 0 diffs,
     pre-deploy 78/78 passed twice, deploy landed, **profile system-876
     anchored**, all four changes asserted on the live system,
     `is-system-running` = running, zero failed units.
4. **The Fast Boot question answered CORRECTLY after owner challenge — the
   session's best finding:** firmware time is a **warm-vs-cold split**: the one
   clean warm reboot in the record (boot -13, the 7.2.9 deploy reboot Oct 5,
   28s turnaround) posted **6.789s**; all 14 cold/watchdog boots 62.5-62.7s
   (AMI 5.36 retraining 128G LPDDR5X on cold power-on). Today's 62.7s was a
   **watchdog reset** (`x86/amd: Previous system reset reason [0x02000800]:
   hardware watchdog timer expired` — freeze-28). BIOS levers: plain Fast Boot
   - Memory Context Restore / MRC Fast Boot where exposed. Expected cold
     firmware → ~7-15s.
5. **Memory/queue surfaces updated consistently:** systemd.md converger
   `--no-block` gotcha; stability.md BIOS row enriched twice (warm/cold split
   - MCR knob + NVRAM verify); storage.md ClickHouse-relocation row +
     TODO_LIST queue one-liner (both surfaces, no drift); Source pointers
     de-dangled against the dispatch report.
6. **Smoke FAIL triage (3/3 not-mine, evidenced):** nix-daemon 1479% = parallel
   sessions' builds; node_exporter 317 lines/min = two textfile-collector
   defects already filed by freeze-28 session (monitoring.md:20);
   bank-sync sync_errors "since restart" = restart transient, zero errors in
   the 15min after, unit active.
7. **Runaway `find /` (my own mistake, §d) killed promptly.**

## b) PARTIALLY DONE

1. **Deploy verification** — live asserts green, but the TRUE verdict (next
   boot's `systemd-analyze` with all four fixes active) is **unverified**: no
   reboot window was taken (other sessions active; not my call to make alone).
2. **Warm/cold firmware split** — proven by ONE warm sample + one proven
   watchdog reset + absence of any shutdown records. I did NOT check the reset
   reason of the other 13 cold boots individually; the split is inference from
   one clean boundary, not per-boot proof.
3. **bank-sync re-verification incomplete** — my 90s counter re-check failed to
   locate the prom file (wrong path guess); verdict rests on "zero journal
   errors in 15min + unit active", not on the counter being flat.
4. **stability.md row for loader timeout** — inspected (`timeout 2`), decided
   to leave, never recorded the decision anywhere but this report.
5. **UNANCHORED profile root cause** — caught the symptom (first deploy left
   `/run/current-system != system-875`), re-ran deploy to anchor, but did NOT
   root-cause why the first switch failed to set the profile (the deploy's own
   "RACE RISK: HEAD moved 247s ago AND first-activates units" hint unexplored).

## c) NOT STARTED

1. BIOS Fast Boot + MRC enable (owner hands — queued [blocked:user]).
2. ClickHouse state relocation to the hot-DB disk (structural 10min fix —
   queued [ready]).
3. Warm-reboot repro experiment (`systemctl reboot`, expect ~7s firmware × 2-3
   samples to confirm MRC-on-warm behavior is systematic, not one lucky boot).
4. Post-fix calm-boot `systemd-analyze blame` re-measurement.
5. Boot-mirror NVRAM decode verify (standing open item, predates session).
6. dnsblockd startup-hang fix + discordsync-db-backup failure (owned by
   parallel sessions; I only cross-referenced).

## d) TOTALLY FUCKED UP (brutal honesty)

1. **My first Fast Boot answer was prematurely confident.** I told the owner
   "firmware is flat 62.6s — memory training dominates" — asserting a CAUSE I
   had not verified, framing 62.7s as quasi-normal for this hardware. The
   owner had to push back ("62.7s sounds like a lot already!") before I dug
   into the boot series and found the 6.8s warm boot. The flatness to ±0.1s
   should have been my OWN trigger that something deterministic was going on.
   The session's best finding exists because the owner challenged me, not
   because I was thorough. That is a failure of the "A 'verified' label must
   cover every fact asserted" rule.
2. **I misattributed the 6.8s boot mid-session.** My first per-boot loop
   misaligned output (boot -14 empty, "-13: 6.789s" concatenated on one line)
   and I told the user "boot -14 did 6.8s" before verifying which boot it was.
   Caught it only because boot -14's journal start showed session scopes with
   2.7M PIDs (impossible for a fresh boot) and the 7.2.9 kernel-change
   correlation confirmed -13. The final table is right; the intermediate claim
   was sloppy and unverified.
3. **I ran a full-filesystem `find /` during an IO-sensitive window** on a box
   I had myself just diagnosed as IO-fragile (PSI 60%+). It auto-backgrounded,
   IO-hogged, and had to be pkill'd. The path was knowable from unit
   definitions; I was lazy.
4. **The drain-poll condition was too eager.** I fired the queued deploy at
   avg10 < 20% while avg60 was still 45% — a real-storm rebound risk. The
   deploy then hit the phantom-PSI leg anyway. Correct end state, sloppy gate
   design (avg10 AND avg60 should both gate).
5. **Two edit-tool failures on long single-line rows** (storage.md, stability.md
   old_string mismatches) — resolved by bash append / python line-replace.
   Correct outcome, but I reconstructed long lines from wrapped terminal
   output instead of byte-exact reads. Root cause: terminal-wrap illusions.
6. **wtmp's "no shutdown records AT ALL" datum sat in my own evidence for two
   hours before I noticed what it means:** since Oct 1 the box has had ZERO
   clean reboots — every boot is crash/watchdog class (15 crash-class boots in
   12 days). That is a first-order stability signal for the freeze-28
   investigation and I nearly shipped the report without surfacing it.
7. **Killed a background shell by ID that had already exited** (042-era probe)
   and had a `/tmp/probe-boot2.sh` heredoc land in a weird half-state once —
   small, but each wasted a round trip through inattention.

## e) WHAT WE SHOULD IMPROVE

1. **Flat-to-the-tenth-of-a-second numbers are signatures, not norms** —
   normalize-nothing: a ±0.03s constant across boots demands immediate
   mechanism-hunting (it WAS a bimodal distribution hiding in a mean).
2. **Check `x86/amd: Previous system reset reason` FIRST in any boot-time
   analysis** — one grep classifies every boot as warm/cold/crash and
   reframes the whole series (I did it only under pressure).
3. **Journal queries: bounded per-boot windows from the start** (the two
   auto-backgrounded full-history greps cost minutes under storm).
4. **PSI drain gates must require avg10 AND avg60** below threshold (rebound
   protection); the phantom-vs-real discriminator (disk busy + D-state scan)
   worked well and belongs in deploy.sh proper (existing queued row).
5. **Pre-stage post-deploy verification as ONE script before switching** —
   my asserts were assembled ad-hoc after the switch landed.
6. **Ask for the reboot window early** — "next boot tells the truth" without
   a scheduled verification leaves the dispatch's central claim unverified.
7. **Verify counter-based smoke checks by reading the counter, not adjacent
   signals** (bank-sync: I inferred from journal silence instead of the prom
   file I failed to find).

## f) Next things (session-scoped; 50 max, impact-ordered)

Already queued this session (rows exist, do not re-file):
ClickHouse hot-disk relocation (storage.md), BIOS Fast Boot+MCR with NVRAM
verify (stability.md), dnsblockd hang (services.md, parallel session),
node_exporter textfile defects (monitoring.md:20).

NEW items:

1. Reboot in a quiet window → `systemd-analyze` verdict on the four fixes.
2. Warm-reboot repro ×2-3 (`systemctl reboot`; expect ~7s firmware each).
3. Per-boot reset-reason sweep across the journal record → confirm the
   warm/cold split boot-by-boot (closes §b.2).
4. Quantify crash-class boot cadence: 15 crash boots since Oct 1, zero clean
   reboots — feed the freeze-cluster evidence (freeze-28 session).
5. Boot-time textfile metric (parse `Startup finished`) + Gatus trend check —
   makes boot regressions visible without dispatches.
6. Post-fix calm-boot blame/critical-chain re-measure (doc rule: calm boot).
7. Root-cause the UNANCHORED-profile mechanism from the first deploy (was it
   the HEAD-moved race path?).
8. ExecStartPost-budget-vs-TimeoutStartSec eval audit (generalize the
   llama-chat 8min-exhaust class across all units).
9. discordsync-db-heal: WAL-gate the integrity_check (hermes pattern,
   systemd.md:67) — skip the 12min scan on clean shutdowns.
10. crush-hot-db-migrate: why 10m wall for 0 relocations (scan cost; cap depth
    or move out of the boot window).
11. initrd outliers: boots -8/-2 at 31-32s vs 5-13s typical — audit contents.
12. bank-sync: re-verify the error counter properly (prom file path from unit
    definition), and consider window-based smoke semantics vs since-restart.
13. Loader `timeout 2` → 1 (one-liner; menu still reachable with held key).
14. Document the warm/cold firmware split in docs/agents/systemd.md boot
    section (currently only in the todo row + this report's successor).
15. If MRC is NOT exposed in BIOS 1.11: check GMKtec for a BIOS update.
16. After Fast Boot enable: confirm the USB DAS still enumerates at kernel
    level (firmware skip is fine; verify pool mounts first Fast Boot).
17. pstore (backend=efi, max_reason=3): confirm freeze-28's console record was
    pulled by that session; my watchdog line corroborates.
18. Boot-time admission control (existing stability row) — this session's
    data strengthens it: llama-chat page-in + clickhouse recovery + migrate
    all collide in the same window.
19. Re-check the "models are bandwidth-bound" /data claim for llama-chat: the
    23.4G page-in is 10s at seq speed but 4.5min under storm — contention,
    not bandwidth; hot-disk model placement might be worth it anyway.
20. Post-relocation: re-run scripts/bench-disk.sh hot-vs-QLC for the
    clickhouse merge pattern.
21. Consider `systemd-analyze critical-chain` diff as a standing post-boot
    check (boot regression early warning, pairs with #5).
22. sdb1 buildcache wedge: my iostat sample caught it at 29.8% util with
    4MB/s reads — corroborates the standing stability row; owner disposition
    still pending.
23. Loader 2.7s→4.0s variance on some boots (random-seed refresh write?) —
    micro, only after the big items.
24. Update/close the storage.md ClickHouse row when relocation lands (row
    self-lifecycle).
25. Smoke baseline churn: node_exporter journal FAIL line count changes
    (308→317/min) flip "known" to "NEW failure" — baseline should match on
    unit name, not line text.

NOT harvested (deliberately): #13/#23 (micro, ROADMAP-fuel), #19-20 (ride the
existing storage row's execution), #24 (row-lifecycle duty, not a new item),
#25 (belongs to the smoke-baseline owner's next touch).

## g) Questions I cannot answer myself

1. **Reboot window:** when can the box be rebooted for the verification boot
   (no in-flight agent sessions / builds)? This dispatch's central claim —
   "userspace boot drops by the 8min llama-chat cycle + storm mitigations" —
   is unverifiable without one, and you told the parallel sessions' work is
   still in flight.
2. **BIOS menu contents:** does EVO-X2 BIOS 1.11's advanced/AMD menu expose
   "Memory Context Restore" / "MRC Fast Boot"? I cannot read firmware setup
   from the OS — if absent, the cold-boot 62.7s only falls to plain Fast Boot
   levels (and question #2b: is a GMKtec BIOS update acceptable to you?).
3. **Priority call:** ClickHouse hot-disk relocation (big, touches the storm's
   eye, ~10min of every boot) vs. waiting for freeze-28 stabilization first —
   the box crashed TODAY at 13:04; doing a large storage migration on a box
   in an active freeze cluster is a risk trade only you can rank.

---

_Sources: live probes (systemd-analyze, journalctl per-boot windows, pidstat/
iostat, /proc/pressure, bootctl, last -x, /boot-mirror verify scripts) and the
session's own dispatch report `2026-10-12_13-40_boot-slow-fastboot-dispatch-
four-bootpath-fixes.md`, both surfaces current as of 15:49._
