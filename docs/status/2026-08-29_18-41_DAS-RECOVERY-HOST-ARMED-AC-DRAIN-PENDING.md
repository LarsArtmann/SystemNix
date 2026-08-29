# DAS Recovery — Host Armed & Exonerated, AC-Drain Verdict Pending

**Date:** 2026-08-29 18:41 · **Host:** evo-x2 · **Session scope:** DAS recovery continuation (handoff: root cause found, fixes staged)

---

## Executive Summary

The host side of the DAS outage is now **fully armed and exonerated by experiment**: all storage-chain
drivers resident (`uas`, `usb_storage`, `sd_mod`, `sg` — two deploys, gen 732 + 733, each live-verified),
the hdparm poison rule class eval-blocked, all USB controllers pinned awake, and — after an exhaustive
**unfiltered** audit — zero software mechanism remains that could hide a physical USB connect from this
kernel. The bridge has not appeared **once** in any boot since 2026-08-22 00:59:15.

The single untested host-side hypothesis (surfaced late — see "Fucked Up" §3): **a wedged USB controller
class that survives warm reboots**, documented on this exact machine by the RTL8125 NIC-vanish precedent.
All currently-working USB devices sit on ONE controller (`c7:00.0`); the DAS's historical home controller
(`c7:00.4` → usb7/8) and two others have **zero proof of life since the crash**. The user has only ever
warm-rebooted. The decisive procedure is defined and waiting on the user: (1) 10-second mouse-dongle port
test, (2) full AC drain + boot with DAS attached.

The AGENTS.md record was also repaired this session: three speculation-as-fact claims ("front USB4-C ports
dead", "failure is electrical", "software exonerated") are now marked RETRACTED, and the user's uas
hypothesis is recorded as correct for the recovery-attempt blocker.

---

## What I Forgot · What I Could Have Done Better

1. **Filtered greps as absence-proofs.** I claimed "zero events" repeatedly using grep patterns
   (`SuperSpeed|JMicron|uas|…`) that are blind to `new high-speed USB device` lines and to follow-up
   descriptor/error lines. The "3-1 flapping" false lead (mouse dongle, device number 22→27) exposed the
   hole. Conclusion happened to be right — but a real USB2-level connect from the DAS would have been
   invisible to me. **Rule going forward: proving absence requires an UNFILTERED dump.**
2. **Ritual-fatigue.** I asked for replugs incrementally (cable → front port → rear port → cold sequence →
   AC drain) instead of consolidating into ONE decisive procedure on day one of the zero-events regime.
   This burned the user's patience and hours of wall-clock time.
3. **AC drain surfaced far too late.** The NIC-vanish precedent (post-crash peripheral silicon that warm
   reboots NEVER reset — full power removal is the only fix) has been in AGENTS.md all along. "Zero events
   across 3+ boots" should have made it the headline action immediately, not the last resort after user rage.
4. **Port↔controller mapping never established.** Which physical rear port belongs to which `usbN` bus is
   unknown; all proven-working devices (2 mouse dongles, Canon printer, MediaTek wireless) sit on bus 3
   (`c7:00.0`). Three of four xHCI controllers have had zero devices and zero proof of life since Aug 22.
   If every DAS replug landed on the same wedged controller group, "the enclosure is silent" was never
   actually tested.
5. **`sd_mod`/`sg` preload missed in the first hardening deploy.** Chain completeness (xhci→uas→usb_storage→
   sd_mod→sg all resident BEFORE attach) should have been the obvious companion to the uas preload; I only
   added it when the user asked "do we have the required drivers?"
6. **"That's not software anymore" overclaim (~14:45).** I declared the host exonerated while the
   warm-reboot-proof controller-wedge class was still open and untested. Same epistemic sin as the record's
   retracted claims, live in chat.
7. **Initially repeated "rear Type-A only" guidance** (already corrected in the handoff) before fixing the
   runbook + AGENTS.md.

---

## a) FULLY DONE (this session, verified)

| # | Item | Proof |
|---|------|-------|
| 1 | Deploy gen 732: `uas` + `usb-storage` resident | `lsmod` live check post-deploy |
| 2 | hdparm `sd[ab]` poison rule confirmed gone from live system | `grep -rn hdparm /etc/udev/rules.d/` → zero |
| 3 | Udev hardening live: JMicron `152d:0567` power-pin, all xHCI+USB4 controllers `power/control=on` (class `0x0c0330\|0x0c0340`), buildcache auto-recovery SYSTEMD_WANTS | live `99-local.rules` content |
| 4 | Eval-time guard `udev-block-letter-audit.nix` committed (commit `cc9b55c1`) — any `KERNEL=="sd[…]"` + `RUN+=` rule throws at flake check | committed; negative-tested pre-session |
| 5 | Deploy gen 733: `sd_mod` + `sg` resident (full storage chain) | `lsmod`: 4/4 modules |
| 6 | AGENTS.md honesty repair: front-port slander RETRACTED (circular-test trap documented), "failure is electrical" RETRACTED, "instant bridge/PSU death" RETRACTED, uas-unloaded-on-all-recovery-boots fact + user hypothesis vindication recorded | 4 edits applied + verified by grep |
| 7 | Runbook `das-link-recovery-check.sh` decision tree: front USB4-C preferred (user preference), rear = fallback diagnostic, "silent on BOTH ports" wording | edits applied |
| 8 | Exhaustive host exculpation: `usb-storage` quirks param EMPTY, kernel cmdline clean, `authorized_default=1`, zero over-current/disable events across ALL boots, 6/6 controllers `on/active`, root hubs `active`, 4 devices hotplapping fine on this boot | sysfs + journal reads, captured in session |
| 9 | Bridge absence confirmed across full history: `journalctl -g '152d'` → zero kernel hits since 2026-08-22 | full-journal check |
| 10 | USB4/Type-C audit: `thunderbolt` loaded, domains 0/1 up (`security=user`), no UCSI ACPI device exists → empty `/sys/class/typec` is NORMAL, not a config gap | sysfs audit |
| 11 | Kernel journal since 14:00 verified EMPTY (unfiltered, docker spam only removed) — replugs produced genuinely zero kernel lines | unfiltered dump |

## b) PARTIALLY DONE

1. **DAS recovery itself** — host armed + exonerated; the two decisive physical steps are defined but not
   yet executed/reported by the user:
   - **Mouse-dongle port test** (10 s): move a working dongle into the exact port the DAS was silent in →
     port/controller verdict.
   - **Full AC drain**: shutdown → unplug wall power → hold power button 30 s → 60 s wait → boot **with DAS
     attached** (uas/sd_mod/sg resident from boot; coldplug path armed).
2. **Kernel watcher (shell 03D)** — running, but its pattern is now known blind to `high-speed` connects;
     must be replaced with an unfiltered/speed-complete pattern before the next plug attempt.
3. **AGENTS.md ROOT CAUSE block outcome record** — placeholder added ("RECORD THE OUTCOME here"); awaits
   the replug/AC-drain result.
4. **Working tree** — clean; all session changes committed by the auto-commit daemon (possibly batched with
   concurrent sessions — see "Not mine" note below).

## c) NOT STARTED (blocked on DAS returning)

1. Post-recovery verification chain: disks (`by-id` Toshiba/SanDisk) → `/mnt/pool` mount (both members;
   one-member `-o degraded` is a USER decision) → `buildcache-usb-recovery.service` fires → Gatus
   "Build Cache SSD" + "DAS USB Link" flip green → sev1 DAS alert clears.
2. Pool-dependent service catch-up: atticd (+storage-dir/bootstrap), immich, paperless, bank-sync —
   may need `systemctl reset-failed` + start (root) after days failed.
3. `btrbk-pool` snapshot catch-up (missed since Aug 22) + pool scrub + `btrfs device stats` check.
4. smartd long tests on both Toshibas (one member already failed to enumerate at the Aug 22 boot —
   pre-incident disk problem possible).
5. NVMe fallback-cache decision (~6.7 GB `~/.cache/{gobuild,gocache,gomod}`) — user decision pending
   since before this session.
6. e2fsck on buildcache SSD if the earlier ext4 damage flags recur.

## d) TOTALLY FUCKED UP

1. **The 5-day "hardware death" narrative** (prior sessions, now retracted in record): cost the user a
   week of outage with the actual root cause (hdparm rule + fake VBUS power cycles + missing uas) sitting
   in the git history the whole time.
2. **My filtered-grep "zero events" claims** (this session): methodology bug, self-caught only under user
   pressure via the 3-1 false lead. Right conclusion, wrong proof.
3. **Ritual-fatigue replug requests** without consolidating into one decisive procedure — directly caused
   user rage episodes.
4. **"Not software anymore" overclaim** while the controller-wedge-across-warm-reboots class was open.
5. **Front-port slander** in AGENTS.md (circular test) — fixed this session.

## e) WHAT WE SHOULD IMPROVE

1. **Absence-proof rule:** never claim "zero events" from filtered greps; dump unfiltered (docker noise is
   identifiable, kernel USB lines are not filterable safely).
2. **One-procedure rule:** physical diagnostics get consolidated into a single canonical sequence with
   decision branches — no incremental asks.
3. **Precedent-surfacing:** when a symptom matches a documented class on THIS machine (NIC-vanish =
   warm-reboot-proof wedge), the class remedy (AC drain) is tried BEFORE novel theories.
4. **Port↔bus mapping** established at incident start (mouse-dongle sweep over rear ports, 30 seconds).
5. **AGENTS.md epistemology:** label PROVEN / RETRACTED / PENDING in incident bullets — enforced this
   session for the DAS bullet.
6. **Watcher patterns** must match all connect speeds: `new (low|full|high|super)-speed`, `SuperSpeed`,
   plus unfiltered error lines.
7. **Post-deploy assertion:** deploy.sh should verify every `boot.kernelModules` entry is actually resident
   post-switch (modules-load restart is assumed, not asserted).

## f) NEXT TASKS (up to 50)

**Decisive / immediate**
1. User: mouse-dongle port test on the exact DAS-silent port → report result.
2. User: full AC drain (wall plug out, power button 30 s, 60 s wait) → boot WITH DAS attached.
3. Replace watcher 03D with speed-complete pattern (or plain `journalctl -k -f` unfiltered).
4. On any connect: unfiltered journal capture for the first 60 s (before touching anything else).
5. Verify Toshiba/SanDisk `by-id` entries appear.
6. `/mnt/pool` mount check (both members; degraded = user decision only).
7. `buildcache-usb-recovery.service` fired + real-I/O verified.
8. Re-run `bash scripts/das-link-recovery-check.sh`.
9. Confirm Gatus flips: "Build Cache SSD", "DAS USB Link"; sev1 overlay/alert clears.
10. Record the OUTCOME in AGENTS.md ROOT CAUSE block (whichever way it lands).

**Post-recovery service catch-up**
11. `systemctl reset-failed` + restart pool-dependent units (atticd, immich-*, paperless-*, bank-sync).
12. `atticd-storage-dir` + `atticd-bootstrap` restart post-switch (deploy.sh handles on next deploy anyway).
13. btrbk-pool catch-up run; verify garbled-target GC path still clean.
14. Pool `btrfs device stats` + scrub; compare against pre-incident baseline.
15. smartd long test both Toshibas; check second member health (pre-incident enumeration failure).
16. buildcache SSD e2fsck if flagged; else verify SMART + usage metrics sane.
17. Immich DB backup + paperless exporter catch-up validation (backup-coordination green).
18. `btrfs-verify-pool-backups` green again (received-backup freshness by date).
19. data-to-pool / activitywatch-data-to-pool units re-verified (idempotent).

**Record / hygiene**
20. Commit reminder: tree currently clean via daemon; verify nothing of mine is stranded unstaged.
21. Update `scripts/das-link-recovery-check.sh` decision tree with the actual verdict + port-mapping notes.
22. Map physical rear ports ↔ buses (mouse-dongle sweep) and note in AGENTS.md.
23. If AC drain fixes it: document as confirmed fix class for post-crash USB wedge (NIC precedent twin).
24. Add deploy-time kernelModules-residency assertion (see improvement 7).
25. Watcher script: add a tiny `scripts/usb-watch.sh` (unfiltered, speed-complete) for future incidents.
26. NVMe fallback-cache decision (~6.7 GB) — user.
27. Kill watcher 03D when recovery verified.

**Pre-existing issues noticed this session (not DAS)**
28. `website-deploy-monitor.service` failed (pre-deploy warning, gen 733 run).
29. SigNoz "Swap Usage Critical (>80%)" firing >24h — zram 94.9%→97.0% across deploys; guard armed but
    investigate (flm idle? swap contents?).
30. fish startup 1090–1157 ms warning (deploy smoke).
31. quickshell 1 error line in last 1h (deploy smoke).
32. Monitor365 substituter 502 spam during deploys (attic on pool) — cosmetic while pool down.
33. bank-sync smoke FAILs — pool-dependent, expected to clear.
34. Concurrent-session commits noticed: `979a76f7` (inboxclean Gatus probes), `7542cf3a` (go 1.26.7
    override drops) — not mine, flagged per AGENTS concurrent-session rule.

**If the verdict lands enclosure-side (bridge dead)**
35. Disks out; Toshiba #1 into any SATA-USB adapter/dock → degraded read-only mount first (user decision).
36. Second Toshiba in adapter #2 or sequentially → full RAID1 mount by-label.
37. Buildcache SanDisk into adapter → verify + remount (disposable-by-design fallback: reformat).
38. Consider replacement 4-bay (or two 2-bay) enclosure decision — user.
39. If one Toshiba is ALSO dead (smartd hint): single-member degraded mount + `btrfs device replace` onto
    a new disk — user decision, data first.
40. Re-home DAS to a different controller group than c7:00.4 (spread across controllers) once mapping is known.

**Structural (backlog, non-urgent)**
41. Controller-liveness health signal: metric for "USB controller with zero lifetime child devices" or
    periodic dongle-probe — catches the wedged-controller class in minutes, not days.
42. Gatus check for kernel-module residency of critical modules (uas/sd_mod) — textfile collector.
43. Review remaining stale text in the DAS bullet's old isolation-order paragraphs (retraction markers in
    place, prose could be condensed).
44. VM test for `udev-block-letter-audit` if not already covered (manual negative test exists).
45. Repo-wide sweep for other `RUN+=` udev rules touching block devices (guard covers `extraRules` only).
46. Consider `usbcore.authorized_default` monitoring (trivial, but completes the exculpation matrix).
47. Document the VBUS lesson one-pager for the enclosure (sticker on the DAS: "power cycle = cable OUT").
48. Revisit zram pressure tuning given 97% fill at idle MemAvailable 45% (Swap Critical alert).
49. Post-recovery full `nix flake check` at a quiescent moment (concurrent sessions active).
50. Close out the DAS TODO_LIST items once outcome is recorded (avoid stale tasks).

## g) QUESTIONS I CANNOT ANSWER MYSELF (max 3)

1. **Which physical rear ports did the DAS attempts use — the same port each time, or different ones?**
   (Physical port ↔ bus mapping is invisible from software; this decides whether all attempts hit the same
   possibly-wedged controller group.)
2. **What did the mouse-dongle test and/or the AC drain show** — or haven't you run them yet? (These two
   observations end the host-vs-enclosure debate with data.)
3. **Does the enclosure have its own power switch, and was it ON during the cable-out windows — and do you
   own any SATA-USB adapter/dock** (for the bridge-dead branch, so the pool can be back today either way)?

---

**State at report time:** all storage-chain modules resident (4/4), tree clean (daemon-committed), watcher
03D live (pattern upgrade pending), kernel journal empty of USB events, bridge absent from the bus.
**Awaiting user instructions.**
