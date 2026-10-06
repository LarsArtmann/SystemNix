# HDD Helium / SMART Inspection Session — Status Report

**Date:** 2026-10-06 19:28 CEST
**Session scope:** Ad-hoc Q&A — "how much helium is in my HDDs?" → drive inventory, SMART inspection of both pool drives over the USB DAS, full attribute triage from user-run `smartctl` output. **Zero repo or system mutations; read-only diagnostic session.**
**State at report time:** Both drives helium-sealed and healthy; no self-test or overall-verdict run; findings captured here only (no docs/monitoring changes — report-then-wait was ordered).

---

## a) FULLY DONE

All evidence is the live command output from this session (`lsblk`, user-run `sudo smartctl -A /dev/sd{a,d}`) — no commits, nothing deployed.

1. **Drive inventory + helium identification.** `lsblk` confirmed 2× Toshiba MG08ACA16TE 16TB (rotational, USB TRAN) + 2× SanDisk SDSSDA240G (same DAS) + 2 NVMe + zram. Both HDDs are helium-sealed drives; cross-referenced against prior reports: they are the pool RAID1 members behind the single USB link (`8-1`, JMicron bridge).
2. **The root question answered with the correct mechanism.** The actual helium *quantity* is unreadable by design (hermetically sealed, no absolute sensor). What software CAN read is the seal-condition SMART attributes. On this firmware those are **IDs 23/24 (`Helium_Condition_Lower`/`Helium_Condition_Upper`)** — not the ID 22 I first quoted (see §d).
3. **Verdict: both drives fully sealed.** Attrs 23/24 on both: VALUE 100 / WORST 100 / THRESH 75 / RAW 0, Pre-fail class. Zero helium degradation detected. Both drives also zero on every media counter (5, 196, 197, 198, 199 raw = 0).
4. **Full attribute triage of both drives.** Young drives (PoH 1907h / 2111h ≈ 80–88 days, 15 power cycles); temps 32°C current, 40–41°C lifetime max (ideal); G-Sense 2 and 4 — exactly consistent with the 2026-09-12 vibration baseline (G-Sense 2 @ 1523h, 4 @ 1319h → no new shock events); Disk_Shift raw values are vendor-packed, matching the prior decode, only trend matters; Load_Cycle ≈ Start_Stop (no aggressive APM parking); Spin_Up_Time raw ~7.8–7.9s is normal for 16TB helium ramp + USB bridge latency.
5. **TYPE column explained** (Pre-fail = health-critical, below THRESH means failing; Old_age = wear indicator) — asked and answered.
6. **New actionable signal surfaced: `Power-Off_Retract_Count` = 9 on BOTH drives against only 15 power cycles.** That is ~9 unclean power cuts (heads unloaded under power) — nearly every other power event is dirty. Plausibly tied to the known DAS USB-drop / AC-drain incident era, but NOT yet correlated. This is the session's key finding and is recorded in §f.

## b) PARTIALLY DONE

1. **Health verification is attribute-level, not verdict-level.** Attribute table analyzed (above); the explicit overall verdict (`smartctl -H` → "PASSED") and offline self-tests (`-t short` / `-t long`) were recommended but never run. Blocker: needs interactive sudo; user ordered report-then-wait. Effort: S.
2. **Retract root-cause is a hypothesis, not a diagnosis.** 9× attr-192 correlated in my head with the known DAS drop class + "AC-DRAIN-PENDING" incident naming, but **no journal correlation was run** (session was scoped to Q&A). Until correlated, "unclean power cuts" is inference from a vendor counter. Blocker: user scope order. Effort: M.
3. **Knowledge capture is report-only.** This file records the session, but `docs/agents/storage.md` and the pool service runbook still lack the MG08 helium attribute mapping (IDs 23/24, Pre-fail, THRESH 75) and the current baselines. Blocker: report-only instruction. Effort: S.

## c) NOT STARTED

Nothing below was begun (by instruction — report-then-wait):

1. **Helium seal monitoring gap (verified, not assumed):** `pool-smart-metrics.nix` parses attrs **5, 196, 197, 198, 199, 191, 220, 9, 194 only**. The exact attributes this session's question is about — **23/24 — are not collected, not dashboards, not alerted**. Extension + Gatus check + dashboard panel: not started.
2. **Attr 192 (power-off retract) delta tracking** in the collector: not started.
3. Journal correlation of retract events with USB/power history: not started.
4. `smartctl -H`, short self-test, extended self-test on both drives: not started.
5. Storage docs/runbook update (helium attr IDs, new baselines, SAT-over-USB note): not started.
6. Full §f list (37 items) — all not started; triage pending §g answers.

## d) TOTALLY FUCKED UP

Nothing was broken — the session was read-only, made zero mutations, and touched no shared state. What follows is the honest defect list at the fact/precision level:

1. **I asserted the wrong SMART attribute ID from memory.** First answer: "attribute 22 (Helium_Level/Condition)". This MG08 firmware actually reports **23/24 Helium_Condition_Lower/Upper**. Caught within one turn by the user's paste; no action was ever taken on the wrong ID; corrected before the verdict. Root cause: quoting a vendor attribute ID before seeing the drive's own output — precisely the repo's verify-before-claiming class. Severity: none (chat-only). Mitigation going forward: quote attribute IDs from the live output, never from recall.
2. **One wasted round-trip on a predictable permission failure.** My first `smartctl -A /dev/sda` (no root) failed with Permission denied — SMART passthrough requires root, which this agent cannot elevate to. I could have stated the sudo requirement upfront and batched ALL root commands into a single paste (I split it into two). Minor inefficiency, but it cost the user a turn.
3. **Mechanism overreach in the "insights" answer.** I described the 9 retracts as "heads slammed to ramp while spinning" — the *count* semantics of attr 192 are vendor-specific and I decoded no Toshiba vendor doc. The actionable core (9 unclean power events vs 15 cycles = investigate) stands; the physical mechanism narrative was inference dressed as fact. Flagged so it is not repeated as established.

## e) WHAT WE SHOULD IMPROVE

1. **Attribute-ID verification habit** — any vendor-specific claim (attribute IDs, raw encodings, threshold semantics) must come from the live `smartctl` output or a vendor doc in the same session, never from memory. This session produced the counterexample and the fix in one.
2. **Batch root-needing diagnostics into one user paste.** When a check requires sudo, enumerate every command up front (`-H`, `-A`, `-i`, self-test status) so the user pastes once. Cost of not doing it: one round-trip per omission.
3. **Session knowledge capture timing.** The G-Sense/Disk_Shift/PoH baselines now live in two chat messages and this report; the durable home (`storage.md` / runbook) is still empty of them. Systems-diagnosis sessions should write findings to their domain doc when the signal is found, not only when a report is ordered.
4. **Third smartctl consumer → shared parse lib.** The collector and `hdd-vibration-check.sh` already duplicate parsing (flagged 2026-09-12); adding helium attrs would create a third consumer. The shared-parse-lib item should be pulled forward when the helium extension lands.
5. **Helium attr knowledge is tribal right now.** "MG08 helium = attrs 23/24, Pre-fail, THRESH 75, raw 0 = sealed" exists nowhere in the repo. It belongs in `docs/agents/storage.md` the next time that file is touched.

## f) NEXT (session-derived, up to 50 — brainstorm awaiting triage, sorted by impact)

Impact: Critical/High/Medium/Low · Effort: S <30min, M 30min–2h, L >2h

**Immediate verification (user sudo, single paste):**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Run `sudo smartctl -H /dev/sd{a,d}` — capture the explicit overall-health verdict per drive | Critical | S | Verification |
| 2 | Short offline self-test both drives (`smartctl -t short`), read results via `-l selftest` | High | S | Verification |
| 3 | Extended self-test in an idle window (`-t long`) | Medium | S | Verification |
| 4 | Capture `smartctl -i` for both drives: serial + firmware recorded in runbook | Medium | S | Documentation |
| 5 | Map sd-letter ↔ serial via `/dev/disk/by-id` (sdX order is unstable across replugs) | Medium | S | Quality |

**Retract investigation (the session's new signal):**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 6 | Correlate 9× attr-192 with journal power/USB events (`journalctl -k -g 'usb 8-1\|power'`, shutdown records) | High | M | Bug |
| 7 | Determine whether retracts date from the DAS-drop/AC-drain incident era or are ongoing | High | M | Bug |
| 8 | Clean-unmount → unplug → replug test: confirm attr 192 does NOT increment on clean removal | High | S | Verification |
| 9 | Physical check: is the DAS power brick on UPS/protected power? (gated on §g Q3) | High | S | Decision |
| 10 | If ongoing: fix enclosure power behavior (port/cable, UAS quirks, USB autosuspend off for the bridge) | Medium | M | Bug |

**Monitoring gap (verified against collector source this session):**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 11 | Extend `pool-smart-metrics.nix`: parse attrs 23/24 → `pool_smart_attribute_raw{attr="helium_lower"/"helium_upper"}` + delta flag | High | M | Feature |
| 12 | Gatus check: helium raw > 0 → Discord alert (anchored `pat()` form, lint-safe) | High | S | Feature |
| 13 | Decide alert semantics: Pre-fail THRESH 75 — alert on raw > 0 or on normalized VALUE < 100 (raw>0 is the earlier signal) | Medium | S | Decision |
| 14 | Add attr 192 retract count as a delta-flagged attribute in the collector | Medium | M | Feature |
| 15 | SigNoz `systemnix-pool-storage` dashboard: helium + retract panels | Medium | S | Feature |
| 16 | Regression-test the collector change with the proven fake-smartctl method — and persist the harness (it was /tmp-only in 2026-09-12) | Medium | M | Quality |
| 17 | Shared smartctl parse lib before a third consumer lands (collector + vibration script + helium ext) | Medium | L | Refactoring |
| 18 | Second alert channel: smartd-notify → Discord bridge (mail relay still dead per 2026-09-12 §e5) | Medium | M | Feature |

**Docs / memory (this session's knowledge into durable files):**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 19 | `docs/agents/storage.md`: MG08 helium = attrs 23/24, Pre-fail, THRESH 75, raw 0 = sealed | High | S | Documentation |
| 20 | Pool service runbook: current baselines (G-Sense 2 @ 2111h, 4 @ 1907h; PoH; temp min/max) appended to the 2026-09-12 baseline | Low | S | Documentation |
| 21 | Runbook note: the DAS USB bridge passes SAT passthrough — smartctl works over USB on this enclosure | Low | S | Documentation |
| 22 | Runbook note: Disk_Shift raw is vendor-packed on MG08 (already decoded 2026-09-12) — repeat where helium lands so the pair stays together | Low | S | Documentation |

**Pool / data safety (session-adjacent, light-touch):**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 23 | Verify both MG08s are actual mounted RAID1 members right now (`btrfs filesystem show`) — presence ≠ mounted | High | S | Verification |
| 24 | `btrfs device stats` on the pool — confirm zero errors after the USB-drop era | High | S | Verification |
| 25 | `btrfs scrub status` + verify the scrub schedule covers the pool | High | S | Verification |
| 26 | Confirm these drives are inside the offsite backup-freshness scope | Medium | S | Verification |
| 27 | Warranty clock: note 5-yr warranty end dates from serials (once captured, #4) | Low | S | Documentation |

**SanDisk SSDs (same DAS, seen in `lsblk`, unexamined):**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 28 | SMART check on both SanDisk 240G units (one carries buildcache) | Medium | S | Verification |
| 29 | Confirm buildcache ext4 is healthy post-drop era (e2fsck decision was left open 2026-08-22) | Medium | M | Bug |

**Firmware / policy:**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 30 | Check Toshiba firmware updates for MG08ACA16TE | Low | M | Cleanup |
| 31 | Decide spin policy for pool drives (24/7 vs idle spin-down); watch Load_Cycle growth after deciding | Low | S | Decision |

**DAS topology (structural — single-link SPOF still open since 2026-08-22, this session re-confirms the stakes):**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 32 | Second physical USB path for the pool members (one JMicron flap still takes out all 4 disks) | High | L | Feature |
| 33 | JMicron bridge flap root-cause: kernel quirk table / enclosure firmware | Medium | M | Bug |
| 34 | Verify the udev `SYSTEMD_WANTS` + recovery stack still catches flap-with-reconnect on current config | Medium | S | Verification |

**Process:**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 35 | Triage this §f list into TODO_LIST.md + `docs/todo/` libraries once §g is answered | High | S | Cleanup |
| 36 | Adopt "batch all root commands into one user paste" for sudo-gated diagnostics | Low | S | Quality |
| 37 | Adopt "verify vendor attribute IDs against live output" as a stated convention in storage docs | Low | S | Quality |

**Harvest decision (per AGENTS.md status-report rule):** §f is **deliberately not auto-harvested** into TODO_LIST.md / domain libraries at authoring time — the user ordered report-then-wait, items 9–10 are gated on §g Q3, items 11–15 on §g Q2, and item 35 exists precisely to route the rest after triage. This paragraph is the explicit not-harvested record.

## g) TOP QUESTIONS I CANNOT ANSWER MYSELF (3)

1. **Are the 9 power-off retracts already explained?** Do they map onto the known DAS USB-drop / AC-drain incidents (historical, acceptable), or are they unexplained and worth a dedicated investigation? I can correlate journals myself next session — but only you know whether that era was already supposed to account for them.
2. **Should helium monitoring become a standing alert?** Extend `pool-smart-metrics` + Gatus (~1–2h total, items 11–13), or is the periodic manual `smartctl` check enough? Scope/product call.
3. **Is the DAS on protected power, and is unplug-without-eject part of your normal workflow?** Physical-world fact — no amount of system inspection can answer it. It decides whether the retract fix is infrastructure (UPS/enclosure) or behavior (eject discipline).

---

*Report-only session: no code, no config, no deploy. The auto-commit daemon will pick this file up; no manual commit (harness rule: no commit without explicit request).*
