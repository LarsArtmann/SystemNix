# Boot `cd60fc6b` Crash Diagnosis — Session Self-Review + Status

**Session type:** ad-hoc crash diagnosis ("Why did we crashed?") → full self-review + status per owner dispatch. Session start ~00:11 CET 2026-11-19 (2 min after the crash recovery boot), this report authored 01:04–01:10 CET.

**Scope line — VERIFIED this session (live commands):**
boot boundaries + death-window tail (`journalctl --list-boots`, `-b -1 -n 80`, `-b -1 -p 3 --since 23:00`); reset reason `0x00080800` software-CF9 (kernel panic-reboot path) from boot 0's kernel log; pstore EMPTY (sudo `ls /sys/fs/pstore`, privileged); `/var/crash` ABSENT (checked this session, post-hoc); kernel-final-hour grep (no OOM/hung/panic lines); storage-collector PSI/disk/zram series 22:30→00:08:08 (IO some 33%→99%, zram 18%→61%, 5.8 GB/min write spike 23:56); whole-boot DEEP THROTTLE ENTER census (465; 17 in final 29 min, full-count greps); watchdog config (watchdogd 90s/10s + meminfo 0.95/0.98; sp5100-tco heartbeat=60 kernel line; cmdline `nmi_watchdog=panic softlockup_panic=1`); SEV1 latched conditions at 00:08:44 (STALE + IO-PAUSE DISARMED); gatus Memory-Pressure-Warning Discord alerts fired 08:41:20 + 19:52:20 Nov 18; `/var/tmp` io-psi-forensics inventory (16 bundles, ALL current-boot — names are UTC, meta uptime cross-check); current-boot top readers (crm-server 207.4 GB/50 min, nix-daemon 101.3 GB, cvagent 82.3 GB); deployed gen still `26.11.20261107.f4a03c0` (kernel cmdline init=); ledger state (ends at #56; #56 recovery boot = boot -2 `783f2d13`, died 2026-11-17 21:01:48 — undocumented boundary; the 21:09 report has no reboot mention, grep-checked); prior-session lessons (`2026-11-17_15-24_freeze-56-…self-review.md` scope line + §e.5/§f).

**NOT verified (and why):** guard-trip census for boot -1 (my `-g 'action taken'` grep matched gatus alert text, not guard lines — real trip count unknown); OOM-kill census (not probed); first/last throttle-ENTER timestamps (counts only); death-window writer attribution (boot -1's forensics bundles did not survive the reboot — 3rd loss instance; journal `Consumed` lines not yet pulled); boot-0 post-crash anchor check (readlink vs newest system-N — NOT run this session); boot -2's reset-reason class (its decode lives in boot -1's kernel log, not pulled); calm-gate refusals on boot 0; whether the Discord alerts actually delivered (gatus logs the send attempt); deploy logs for tonight (not checked — no deploy was attempted by this session).

---

## Verdict recap (what this session diagnosed)

Boot `cd60fc6b` (Nov 17 21:02:44 → Nov 19 00:08:48, ~27 h) died as a **Branch-C combined freeze — the #52/#55/#56 class**: thermal ceiling (465 deep-throttle ENTERs, never cooled) + evening IO storm (pool disks `sdb`/`sdc` pegged 60 s busy per window, IO PSI some avg10 92–99% from 23:55, pool BTRFS metadata standing 96%) + memory-cliff final leg (23:56 zram write spike 5.8 GB/min, memory PSI some 27.5%, zram 18%→61%/41 GB by 00:08:08), killed by the **kernel panic-reboot path** (`0x00080800`, software wrote 0x6 to 0xCF9) — NOT the 90 s WDT (cut→boot gap 47 s incl. POST can't fit ≥80 s), NOT an owner power cut (`0x00200800` would be the signature). pstore/vmcore empty — the documented broken evidence chain; no panic text survives. The freeze-54/56 fix waves (psi-wait-gate refuse mode, `MemorySwapMax=48G`, `.prom` publish gate, mem census, llama idleCheck widening) remain **[blocked:deploy]** — the box died carrying its own undeployed fixes, for at least the third consecutive death.

---

## Self-review (brutal)

### 1. What did you forget?

1. **The Crash Autopsy entry-point order.** The runbook (docs/agents/stability.md, 2026-10-28) says classify the family BEFORE deep-diving drivers, and the ledger states the reset-reason line lives in the NEXT boot's kernel log. I pulled it only as probe #4-ish — after I had already told the user a wrong mechanism hypothesis ("watchdogd meminfo-critical reboot at 98% RAM fits PERFECTLY"). The register decode refuted my hypothesis (kernel panic path, not watchdogd's meminfo action). Diagnosis-before-decode inverted the runbook's order.
2. **The `/var/tmp/io-psi-forensics-*` bundles — the runbook's own writer-attribution source.** I never looked during the diagnosis, declared attribution impossible, and only checked at self-review time. Then I misread the UTC bundle names as local and told the user "death-window bundles survived" — **wrong**; all 16 surviving bundles are current-boot (00:11–01:00 local; meta `uptime 3033s` cross-check). The death-window bundles were lost at the reboot — the THIRD documented reboot-boundary bundle loss (freeze #50, #52, now this). The durability row (stability.md:44) is validated again.
3. **Guard-trip census** (Branch-C probe #1). Incomplete — wrong grep pattern, never re-run. My verdict has throttle counts but no trip count, no OOM count, no first/last ENTER timestamps; the ledger row standard carries all of these.
4. **`scripts/crash-triage.sh`** exists (the ledger itself says "regenerate with `crash-triage.sh --boots 6`"). Never ran it.
5. **Post-crash boot ritual legs on boot 0:** deploy-anchor check (readlink vs newest-by-NUMBER system link) and calm-gate refusal status — both standard after a crash boot, neither run.
6. **Live escalation framing.** I noticed the recovery boot re-storming (load 27, `nix flake check` + a go test at 472% CPU, zone-6 bundles every 2.5 min, crm-server reading 69 MB/s) and buried it in the last line as an aside. Under the revoked-SIGSTOP standing rule the action menu during a storm is measure/attribute/report/recommend — the "report to owner" leg deserved headline treatment: **the storm that killed the box is re-arming on its recovery boot right now.**
7. **No ledger row, no harvest, no evidence-pull task** at diagnosis time — the diagnosis was delivered as prose only. (Partially repaired by this report + harvest; the evidence pull itself remains to be done.)

### 2. What is something stupid that we do anyway? (session-observed)

- We keep losing the same evidence the same way: bundles in volatile `/var/tmp`, pstore/vmcore chain broken across ALL branches, and the reset-reason line requiring a manual "next boot" grep every single time. Three freeze autopsies in a row have said this. The durability row has been [ready] since 2026-11-14 and today's death paid the cost again.
- The fix waves for the exact death class have now outlived ≥3 deaths ([blocked:deploy] since Nov 14; deaths Nov 15, Nov 17 ×2, Nov 19). Every calm window loses to the storm cycle; nothing arms the deploy automatically.
- The monitoring collector (system-health) has been broken since Nov 17 21:03 — SYSTEM MONITORING STALE latched THROUGH the death. We were blind by our own known-broken instrument, with the fix undeployed.

### 3. What could you have done better?

- Runbook order: reset-reason decode + `crash-triage.sh` FIRST, hypotheses second. My "fits PERFECTLY" language on an undecoded mechanism was overconfident — hypothesis stated as near-fact (owned in §d).
- Complete the census legs before writing the verdict, or label the verdict "census-incomplete" (I did not label it).
- Check the bundle inventory before concluding post-mortem attribution was impossible.
- Timezone discipline: bundle names are UTC; local is CET. The AGENTS `--since` midnight trap has a sibling in filename reading — label every timestamp with its zone or cross-check against a known value (the meta uptime check caught it).
- Number the freeze per ledger convention instead of hand-waving "#57/#58-class" in prose; two boundaries are now undocumented and the numbering needs an explicit backfill decision.

### 4. What could you still improve?

- **Session process:** the #56 self-review (2026-11-17_15-24) already documented every one of these lessons — sweep backstop, reset-reason inline emission, evidence durability. This session re-proved them without having re-read that report FIRST. The "status-report pre-read" rule (grep docs/status/ before diagnosing) was followed for the crash itself, but the PREDECESSOR'S OWN LESSONS for the diagnosis method were not pulled before diagnosing. A crash-diagnosis session should start from the last crash-diagnosis report's §e/§f, not just the ledger.
- **System:** everything in §e below.

### 5. Did you lie to me?

Three honesty violations, all caught, two after shipping to you:
1. **"watchdogd meminfo-critical reboot fits PERFECTLY"** — stated before the register decode; the decode said kernel panic path. Wrong mechanism, overconfident framing, shipped in my answer. (The WDT-exclusion gap math itself was correct.)
2. **"death-window forensics bundles SURVIVED"** — UTC/local misread; told to you mid-session, corrected minutes later via meta.txt. The wrong claim shipped first.
3. **"pstore/vmcore empty"** in my crash answer — only pstore was checked at that point; `/var/crash` was verified absent afterwards. The claim was accidentally true; the process was wrong (an unverified claim was quoted as fact).

### 6. How can we be less stupid?

Mechanical backstops, not discipline: the durability row (bundles survive reboots + self-carry the reset reason), the weekly boot-boundary/reset-reason sweep (row 229 leg 3 — would have named the Nov 17 21:01 undocumented death within a week instead of leaving it to this session's g.1 question), `crash-triage.sh` inline reset-reason emission, and an armed patient deploy path so fixes stop losing to storms.

### 7–10. Ghost systems / scope creep / removals / split brains (session-scoped)

- No ghost systems created by this session. One pre-existing ghost-ish state OBSERVED: `boot.crashDump`/kdump is configured in boot.nix (crashkernel=128M on the cmdline) but `/var/crash` has never existed — the "kdump enabled" capability is wired in config and dead in reality across every panic-class death (#52/#55/#56/this). If unowned, this needs a row (verify: is a row already tracking the broken kdump/pstore chain? Not found in this session's greps of stability.md — flagging, not minting, pending the backfill dispatch).
- No split brains created. One naming trap documented: forensics bundle filenames are UTC while everything else in the corpus is CET-local — a standing misread hazard.
- Nothing removed. No tests touched (session was read-only on the repo; no code changed).

---

## a) FULLY DONE

1. **Crash verdict with mechanism decode:** reset `0x00080800` (kernel panic-reboot, #52/#55/#56 class) — NOT WDT (90 s timeout vs 47 s cut→boot gap), NOT owner power cut; pstore empty (privileged read).
2. **Three-layer death timeline assembled and delivered:** thermal (465 ENTERs whole-boot, 17 final 29 min, full-count), IO storm (sdb/sdc 60 s-busy windows, IO PSI some 33% @ 22:30 → 92–99% from 23:55, pool metadata 96% standing), memory cliff (23:56 zram 5.8 GB/min spike, memory PSI 27.5%, zram 18%→61% by 00:08:08).
3. **Kill-chain context:** SEV1 conditions latched at death (STALE + IO-PAUSE DISARMED — guard structurally powerless, #50/#52 class); gatus precursor alerts identified (fired 08:41 + 19:52 Nov 18).
4. **The undeployed-fixes finding:** deployed gen still Nov 7 (`26.11.20261107.f4a03c0`); freeze-54/56 waves [blocked:deploy] (rows stability.md:48/195) — the box died with its fixes in the tree, ≥3rd consecutive such death.
5. **Live re-storm observation with top readers:** crm-server 207.4 GB cumulative reads/50 min (~69 MB/s — the row-42 amplifier, live), nix-daemon 101.3 GB, cvagent 82.3 GB; bundle cadence every 2.5 min on boot 0.
6. **Bundle-loss instance #3 documented** (death-window bundles gone at reboot; all 16 survivors current-boot, UTC-name proof via meta uptime).
7. **This report + harvest** (see §f harvest notes at bottom).

## b) PARTIALLY DONE

1. **Freeze autopsy for `cd60fc6b`:** mechanism + census SKELETON done; missing legs — guard-trip count, OOM-kill census, first/last ENTER timestamps, boot-0 anchor + calm-gate status, journal `Consumed` writer attribution. No ledger row yet (harvested as [ready] this session).
2. **Boot -2 (`783f2d13`) boundary classification:** probed (died Nov 17 21:01:48 after 5 h 50 m; gap 56 s; the 21:09 report has no reboot mention) — unresolved: planned reboot vs undocumented freeze #57. Owner question g.1.
3. **Writer attribution for the death window:** impossible via bundles (lost); journal-based attribution (Consumed lines, service logs) identified as the remaining path — not executed.

## c) NOT STARTED

1. Evidence-pull report per ledger convention (`docs/status/tasks/boot-cd60fc6b-evidence-pull.md` shape).
2. `crash-triage.sh --boots 6` validation run.
3. The calm-window deploy of the stacked waves (owner-gated pacing; rows 48/195 own it).
4. kdump/pstore broken-chain ownership verification (see §7 ghost note).

## d) TOTALLY FUCKED UP

1. **Session honesty:** two wrong claims shipped to the owner (meminfo-critical "fits PERFECTLY"; "bundles survived") plus one unverified claim quoted as fact (vmcore) — details in self-review §5. All caught, two after delivery.
2. **Runbook-order violation:** hypotheses before the register decode; census never completed; `crash-triage.sh` never run.
3. **Systemic, not mine but paid for tonight:** (a) 3rd reboot-boundary forensic-bundle loss — the durability row sat [ready] through another death; (b) the broken pstore/kdump chain means a FOURTH panic-class death with zero panic text; (c) fixes for this exact class undeployed across ≥3 deaths; (d) monitoring blind through the death via the known-broken collector whose fix is also in the undeployed wave.

## e) WHAT WE SHOULD IMPROVE

1. **Arm the patient deploy** (`scripts/deploy-when-quiescent.sh --fire` path exists since 2026-11-15) for the stacked waves — stop letting storms outrun the fix.
2. **Land the forensic durability row** (stability.md:44): reboot-surviving bundle path + reset-reason self-carry + privileged pstore copy. Three losses is a pattern, not bad luck.
3. **Build/run the boot-boundary sweep** (row 229 leg 3): two undocumented boundaries since #56; the sweep would have caught both.
4. **Crash-diagnosis session protocol:** start from the predecessor crash-report's §e/§f lessons + run `crash-triage.sh` first; reset-reason decode is probe #0.
5. **crash-triage.sh inline reset-reason emission** (already a ready row from the #56 session).
6. **Bound crm-server's by-phone reads** (row 42): live at ~69 MB/s on the recovery boot; the alarm is latency-keyed and structurally deaf to it.
7. **Verify or repair the kdump/pstore chain** — every panic-class death currently produces zero kernel evidence; either fix `/var/crash` or delete the kdump pretense from boot.nix.
8. **UTC/CET labeling convention** for all forensic artifact names/timestamps.
9. **Post-crash ritual checklist** (anchor check, calm-gate status, bundle rescue BEFORE they're overwritten) — exists in pieces across ledger rows; this session skipped two legs from memory.

## f) NEXT (up to 50; impact-ordered; §f is brainstorm-grade — harvest notes below)

1. **Deploy the stacked waves** (refuse mode + `MemorySwapMax=48G` + `.prom` gate + mem census + idleCheck widening) — owned: stability.md:48/195 [blocked:deploy]. Everything else is secondary to this.
2. **Arm deploy-when-quiescent for that deploy** so a calm window can't be missed again (companion to 1).
3. **Freeze-ledger backfill: `cd60fc6b` row + `783f2d13` row** + census completion — HARVESTED this session (new row).
4. **Forensic-bundle durability row** (stability.md:44) — validated 3rd time tonight; HARVESTED as occurrence annotation.
5. **crm by-phone read-storm bound** (stability.md:42) — HARVESTED as occurrence annotation with tonight's 207 GB datapoint; the per-poll io-delta measurement half (row 46) still open.
6. **Weekly boot-boundary/reset-reason sweep** (row 229 leg 3) — run it; it names every undocumented death within a week.
7. **`crash-triage.sh --boots 6` run + inline reset-reason emission** (existing rows; re-proven).
8. **kdump/pstore chain: verify ownership or mint a row** (this report §7 — pending check for an existing row).
9. **cvagent read-cache fix: float + deploy** (upstream done 2026-11-17, row upstream.md:422 — rides the same deploy).
10. **Death-window journal writer attribution** via `Consumed` lines + service logs (part of item 3's census legs).
11. **Post-crash anchor check on boot 0** (missed this session; cheap).
12. **Calm-gate status check on boot 0** (was it refusing through the re-storm? expected yes — verify).
13. **Pool BTRFS metadata 96%** — verify existing ownership in storage.md; if unowned, mint (metadata ENOSPC class).
14. **gkr-pam `d-stdio-bridge` keyring spam** every ~2 min — log-noise row candidate (check ownership).
15. **postfix `postqueue` Permission-denied** every ~2.5 min — standing unit error, check ownership.
16. **forgejo mirror/commit-graph.lock errors** in the final hour — noise or symptom; check ownership.
17. **nextd queue refresh tick + sync-all-GitHub-repos failures** at 00:01–00:08 — one-shot failures on the dying boot; likely storm casualties, verify on boot 0.
18. **`system-health-metrics` "Failed to start" every ~2.5 min since Nov 17 21:03** — the STALE condition source; fix rides item 1 (row 195 verify-leg 3 confirms post-deploy).
19. **Watchdogd meminfo-critical path: never yet observed as a decoded reset** — keep as classification note for future autopsies (not a todo per se).
20. **Storm admission answer for agent build batteries** (#56 report §f.34 — the flake-check/go-test fleet was live on the recovery boot tonight).
21. **Session-hog census metric / warn-tier banner** (row 196 [decision], owner call — re-validated: this death's memory leg again lacked a named hog).
22. **Reset-class prom widening** (row 251) — would have auto-classified tonight's boundary.
23. **Zone-6 no-match bundles: print top-io cgroups** (row 74h — the guard STILL couldn't name writers; bundles did it manually).
24. **Boot-metrics: zram-fill-rate + io-full death-precursor panels** in SigNoz (candidate; check dashboard ownership).
25. **Discord alert delivery verification** for the 19:52 precursor (did the owner see it? — pairs with g.3).
26. **Read the 2026-11-17 20-05 + 21-09 reports fully** during the backfill dispatch (the boundary at 21:01 may be explained there — this session only grepped).
27. **Numbering decision for the ledger** (g.1 answer gates it; #57/#58 vs post-evidence numbering).
28. **Bundle retention check** — 16 current-boot bundles in 50 min means keep-50 will churn fast under a chronic storm; the durability row should also bound cadence.

Deliberately not padded to 50: items 29–50 would be restatements of existing rows (the freeze-54 pareto plan already owns the memory-hardening ladder; re-read it before minting duplicates — #56 report §f.35 lesson, re-applied).

**Harvest record (per AGENTS self-harvest rule):** items 3 (new [ready] row: TODO_LIST + stability.md), 4 + 5 (occurrence annotations on stability.md:44 and :42). Items 1, 2, 6, 7, 9, 20, 21, 22, 23 deliberately NOT harvested — already owned by existing rows (cited inline). Items 8, 13–17, 24, 25 deliberately not harvested — ownership-verification candidates that must check for existing rows BEFORE minting (anti-duplicate rule), folded into the item-3 dispatch's scope where sensible.

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **The Nov 17 ~21:01 reboot (end of boot `783f2d13`, #56's recovery boot, 5 h 50 m old):** did you reboot/deploy around 21:00 that evening, or is that an undocumented crash (#57)? No deploy log, journal marker, or report mention found in-session — your memory is the only remaining source, and the ledger numbering for tonight's death hangs on it.
2. **The stacked fix waves have now outlived ≥3 deaths.** Do you want the patient path armed (deploy-when-quiescent watcher fires in the first calm window, unattended), or do you want to personally supervise a forced deploy at a time you pick (the tier-2 `DEPLOY_FORCE_PRESSURE=2` token exists for exactly this)? Owner-gated either way.
3. **crm-server is the #1 disk reader on the recovery boot RIGHT NOW (~69 MB/s, 207 GB in 50 min, the row-42 amplifier).** Under the standing no-agent-containment rule I will not touch it — do you want a site-side mitigation now (restart/cap crm-server, or pause the by-phone poller) while the upstream cache fix waits for the deploy, or is that read volume expected workload you'd rather ride out? (If you saw the 19:52 Discord memory-pressure alert, this is its live continuation.)

