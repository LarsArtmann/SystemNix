# Freeze #28 — niri `Error::DeviceMissing` death-minute verdict (item: symptom or contributor?)

**Date:** 2026-10-13 · **Boot -1:** bf8a454c, Oct 11 11:09:43 → hard cut Oct 12 13:04:01
**Question:** boot -1's last journal lines are `niri::backend::tty: error doing early import: Error::DeviceMissing` at 13:04:00–01 — symptom or contributor in the IO-livelock story?

## Verdict: SYMPTOM (persistent background noise), NOT a contributor

## Evidence

Live `journalctl -b -1` query (2,181,770 lines still present, pre-vacuum evidence file `2026-10-13_01-25_freeze-28-boot-minus-1-evidence-preservation.md` covers the guard lines):

- **51,808** `Error::DeviceMissing` WARN lines in boot -1, ALL from the same niri PID (2148409), same message, zero variation.
- **First occurrence 08:19:30 Oct 12** — 4.75 h BEFORE the 13:04:01 cut. Not a death-minute event.
- Cadence is steady ~3/s from session start to death; per-hour counts: 08h 7,862 · 09h 10,812 · 10h 10,818 · 11h 10,810 · 12h 10,781 · 13h 725 (boot ends 13:04:01, so the 13h hour is on pace).
- The death minute shows **no cadence change, no escalation, no new message** — niri's retry loop writes at the same rate at 13:04:01 as it did at 09:00 while the system was otherwise quiet. It appears as the "last lines" only because a ~1 Hz journal writer is among the last flushable lines when everything else stalls.
- The actual death signature is unchanged and fully attributed elsewhere: I/O PSI some avg60=87.4%, max disk busy 100%, memory-emergency trip #2803 at 13:00:00 with user.slice +39 GB / inboxclean-web-class IO — the crash-#3 stacked-readers livelock class. niri contributes neither the IO (a few hundred WARN writes/hour ≈ KBs) nor memory.
- Cross-check: at 13:03:58 inboxclean-web still served `GET / 200` in 584 ms — user-space IO was alive at the cut; nothing GPU/niri-specific precipitated it.

## Interpretation

`error doing early import: Error::DeviceMissing` is niri's TTY-backend device import retry: it re-attempts the DRM device import roughly every second and WARNs on each failure. On boot -1 that import NEVER succeeded for the whole 4.75 h session — meaning the failure predates and outlives every PSI storm of that boot and is independent of system load. It is a standing condition of this niri session (likely seat/VT device handoff), not a degradation that tracks the livelock.

## Follow-ups

- Journal spam: 51.8k identical WARN lines per boot (~3/s) land in `/var/log/journal` (hot subvol). Worth an upstream look at why the early import persistently fails on evo-x2 and at rate-limiting the retry WARN. Queued in `TODO_LIST.md` / `docs/todo/stability.md`.
