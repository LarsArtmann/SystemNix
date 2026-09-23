# Session Status: Notifications / DND / Alert-Tier Investigation (Q&A session, read-only)

**Date:** 2026-09-24 00:07 (Thursday)
**Session type:** Two user questions, answered via investigation. ZERO repo changes (read-only session — no edits, no commits, no deploys).
**Scope:** "Why does Do Not Disturb not work? What handles notifications — 'Dark Theme' or something else?" + "Are all my notifications/alerts IMPORTANT?" — plus this status report with brutal self-review.
**Format note:** user explicitly requested `.md`; the status-report skill's HTML default was overridden per its own rule.

---

## Brutal Self-Review (asked first by the user — answered first, honestly)

### What did I forget?
- **I misidentified the running DMS version for the entire Q&A.** I located DMS source via `ls /nix/store | grep dms` and analyzed a **stale v1.5.3** store path (`…-dms-shell-1.5.3+date=2026-07-27_069ddab`) while the live user unit actually ExecStarts **`dms-shell-1.6.2+date=2026-09-17_2db7646`** (`~/.config/systemd/user/dms.service`). Caught and corrected only while writing this report. Conclusions survived re-verification — **by luck, not by method**.
- I did not offer to act on the live sev1 alert I discovered (flm socket down, restore capped). I reported the fix command but never asked "want me to restart it?" — scope discipline taken slightly too far.

### What could I have done better?
- **Resolve "what is deployed" from the live unit's `ExecStart` / running process FIRST**, never from a store-path listing. The version string in my first answer ("deployed DMS 1.5.3") was flat wrong.
- **I made an unverified external claim**: "upstream stable is newer". Verification (during this report): our lock sits at `2db7646` = **v1.6.2 = stable branch HEAD and latest tag** — the lock is CURRENT; nothing to bump. The claim was both unverified and wrong in implication.
- Label claims verified-vs-assumed at write time. Two session claims were below my own bar (the upstream claim; "DMS toasts bypass DND" — asserted from one grep, ToastService never read).

### What could I still improve?
- The v1.6.2 DND code is **materially different** from what I quoted: it has a bypass mechanism (`_allowedInDnd`: per-app rules with `bypassDnd: true` + global `notificationDndAllowCritical`). Today both are OFF (`notificationDndAllowCritical` absent in settings.json, `notificationRules` empty), so the user-visible answer stands — but had the user enabled one bypass toggle, my v1.5.3-derived answer would have been **wrong**, and the REAL answer to "DND doesn't work" lives in exactly those toggles. Future sessions: check the live settings for both keys before answering DND questions.
- No live/visual DND test was possible from here (no graphical session running at 00:07 — `pgrep dms` empty).

### Did I lie?
No intentional lies. One factually wrong version statement (corrected above) and one unverified-then-falsified implication ("upstream newer"). Both are now corrected in this report.

### Ghost systems / split brains?
None created (no code this session). **Observed knowledge split-brain risk:** the desktop-alerting tier semantics live scattered across AGENTS.md, sev1-escalation.nix comments, and DMS upstream code — no single runbook exists (see improvement f-7).

---

## a) FULLY DONE

1. **Q1 answered (verified): notification stack identity.** DankMaterialShell (DMS) on Quickshell owns `org.freedesktop.Notifications`; Dunst retired 2026-06; no other notification daemon; no GNOME/KDE settings app installed (only DMS's own settings window). "Dark Theme" was the user's shorthand for DMS; the theme itself is static Catppuccin Mocha (dynamic theming disabled).
2. **Q1 answered (verified, after correction): DND mechanics in the RUNNING version (v1.6.2).** Settings toggle wires `SessionData.setDoNotDisturb` (NotificationsTab.qml:421-427). Popup gate: `dndBlocked = doNotDisturb && !_allowedInDnd(urgency, bypassDnd)` (NotificationService.qml:710,719); queue drain is DND-gated (:1117); DND enable hides live popups (:1446); AudioService mutes notification sounds during DND. Bypass paths exist but are both OFF in live config (`notificationDndAllowCritical` absent → false; `notificationRules` empty).
3. **Live state confirmed:** `~/.local/state/DankMaterialShell/session.json` has `"doNotDisturb": true`, no expiry (`doNotDisturbUntil` unset → indefinite). The user's DND toggle works and persists.
4. **DND is popup-suppression, not blocking (by design):** notifications still arrive, accumulate in the notification center (bell badge), sounds muted. Overlays/toasts are separate surfaces DND cannot touch.
5. **Q2 answered (verified): alert-importance tier table.** `page` (fullscreen red, RESERVED, no emitter) > `warn` (amber top-strip banner once per alert set: DAS USB link / LAN NIC / BTRFS criticals — hardware, act soon) > `notify` (normal notification: memory-guard trips, memory stall, FLM restore capped, ZRAM critical, monitoring stale, guard dead — self-healing, act later) > independent monitors (nvme-health-monitor, disk-monitor, website-deploy-monitor) > DMS toasts (cosmetic). Most service alerting (Gatus/SigNoz/PapDashboard insights) goes to **Discord**, never the desktop.
6. **sev1 urgency mapping verified:** page tier → `notify-send -u critical` (persistent, expiry 0); warn/notify tiers → `-u normal` (30s expiry, per-key 30-min cooldown). So sev1 notify-tier can never DND-bypass even if `notificationDndAllowCritical` were enabled.
7. **Mid-report corrections completed:** lock = v1.6.2 (current, `2db7646` = stable HEAD = latest tag — nothing to bump); running binary = v1.6.2 (2026-09-17 build); DND logic re-verified against the correct version.

## b) PARTIALLY DONE

1. **DND verification is source-level only** — no on-screen test (no graphical session at time of writing; I cannot see the screen). If the user genuinely saw popups under DND, the exact visual (popup vs toast vs amber banner) remains unidentified.
2. **"DMS toasts bypass DND" is asserted, not verified** — ToastService never read in either version. Low risk, but below my evidence bar.
3. **Active sev1 alert investigated to the alert file only:** "MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" (notify tier, 3 trips in the last hour, restore budget spent, `fastflowlm.socket` DOWN). The re-waking consumer was not identified (out of session scope).

## c) NOT STARTED

- Any repo change (edits, docs, commits) — none; session was read-only Q&A.
- TODO_LIST/docs harvest of this report's (f) items — deliberately deferred: user said "wait for instructions".
- Restarting `fastflowlm.socket` / diagnosing the flm trip churn.
- Live DND visual test; ToastService read; DMS notification-rules setup.

## d) TOTALLY FUCKED UP

1. **Analyzed the wrong DMS version for both answers** (v1.5.3 stale store path instead of the running v1.6.2) — methodology failure: version resolved by store-path listing instead of the live unit. **Impact: zero for this user** (re-verified: both versions suppress all popups under DND with our config since both bypass mechanisms are off), but the cited line numbers and the absence of the `_allowedInDnd` mechanism in my quotes were wrong, and the failure mode was real.
2. **One unverified external claim** ("upstream stable is newer") — falsified on verification: lock is at stable HEAD. This is exactly the `verify-external-claims` class I am supposed to gate on.

## e) WHAT WE SHOULD IMPROVE

1. **Version-first discipline:** for any "how does the deployed X behave" question, read the LIVE unit's ExecStart (or `/proc/<pid>/exe`) before touching source — never trust `ls /nix/store`.
2. **Claim labeling:** mark each session claim verified/assumed; verify external claims (versions, upstream state) before asserting them.
3. **Proactive action offers:** when a live sev1 alert is discovered incidentally, offer the one-line fix, don't just cite it.
4. **Docs consolidation:** desktop alerting semantics (tiers, DND scope, what bypasses it, urgency mapping, Discord channels) deserve a single runbook `docs/services/desktop-alerting.md` instead of AGENTS.md + code comments + DMS upstream.
5. **AGENTS.md one-liner:** add "DMS DND suppresses popups only; center still accumulates; warn-banner/overlays/toasts bypass; v1.6.2 has bypassDnd rules + notificationDndAllowCritical (both off)".
6. **DMS bypass toggles are undiscoverable tribal knowledge** — the very feature that answers "DND doesn't work" (per-app bypassDnd rules, allow-critical toggle) is documented nowhere in our tree.

## f) Next things (impact-sorted; session-derived, not padded to 50)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | Restart `fastflowlm.socket` in a calm window (live sev1 alert; flm consumers dark) | HIGH | 1 min |
| 2 | Identify the consumer re-waking flm (3 trips/h churn; PMA go-commit / papdashboard enricher suspects) | HIGH | 30 min |
| 3 | Get the user's exact DND observation (popup text/app vs toast vs banner) — decides bug vs design | HIGH | ask |
| 4 | Write `docs/services/desktop-alerting.md` runbook (tiers, DND scope, bypass toggles, urgency map, Discord channels) | MED-HIGH | 1 h |
| 5 | AGENTS.md Quickshell section: add DND semantics + bypass-toggle one-liner | MED | 5 min |
| 6 | Live DND visual test next graphical session (`notify-send -u normal` + `-u critical` with DND on) | MED | 5 min |
| 7 | Read ToastService (v1.6.2) — confirm/deny toasts bypass DND; document | LOW-MED | 15 min |
| 8 | Consider per-app `notificationRules` for noisy apps (e.g., sev1 notifications → bypassDnd OFF explicitly, browser → muted popups) | MED | 20 min |
| 9 | Decide policy: should `notificationDndAllowCritical` stay off? (Currently off = even critical sev1 pages sit in center under DND — matches movie-night rule, but `page` tier intends drop-everything; if a page emitter ever ships, re-visit) | MED | decision |
| 10 | Warn-tier banner "movie/presentation mode" — owner decision whether hardware criticals may be deferred | MED | decision |
| 11 | Check `settings.json.bak` accumulation in `~/.config/DankMaterialShell/` (deploy.sh backup hygiene; old known finding, still observed live) | LOW-MED | 15 min |
| 12 | DMS runtime-expanded settings.json (530+ keys) vs declarative 19 keys — drift check tooling | LOW-MED | 1-2 h |
| 13 | Verify `notificationFocusedMonitor` on DP-2 when 2nd monitor returns (known pending AGENTS item) | LOW | 10 min |
| 14 | Check whether `dms ipc` exposes DND control for automation (movie-mode toggle integration) | LOW | 20 min |
| 15 | Investigate DMS crash → in-flight notification loss (Quickshell UAF class): does history persist? | LOW | 30 min |
| 16 | nvme/disk/website monitor notifications: document their urgency levels alongside sev1 tiers in the runbook | LOW | 15 min |
| 17 | Optional design: desktop surfacing of select Discord alerts via papdashboard (opt-in digest) | LOW | decision |
| 18 | DND-aware sev1 behavior: when DND is on, notify-tier alerts are invisible until center is opened — consider end-of-DND digest | LOW | design |
| 19 | Sweep old `dms-shell-1.5.3` store paths confusion source — nothing to do in repo, but note nix-store ls is never version truth (feeds e-1) | — | — |
| 20 | HARVEST this report's (f) into TODO_LIST/docs/todo — pending user go-ahead | MED | 15 min |

## g) Questions I cannot figure out myself

1. **What EXACTLY did you see while DND was on** — a real popup (which app/text?), a small DMS toast, or the amber top-strip banner? This single observation decides between "working as designed", "bypass toggle on", and "genuine DMS bug". I cannot see your screen and no graphical session is running for me to test.
2. **Policy:** should hardware-critical `warn` banners (DAS/NIC/BTRFS) respect a manual "movie/presentation mode", or stay always-on as decided 2026-09-02?
3. **Action:** the flm socket is down right now (restore budget spent, memory guard active). Restart `fastflowlm.socket` now, or leave flm down until you're done for the night?

---

**Verification trail:** flake.lock rev `2db7646` = stable HEAD = tag v1.6.2 (git ls-remote); running unit ExecStart → `dms-shell-1.6.2+date=2026-09-17_2db7646`; DND gates read in that exact store path (NotificationService.qml:710,719,1117,1446; NotificationsTab.qml:421-427; `_allowedInDnd` :480-482); live settings (settings.json: no `notificationDndAllowCritical`, no `notificationRules`; session.json: `doNotDisturb: true`); sev1 urgency mapping (sev1-escalation.nix:401-410); live alert file `/run/systemnix/sev1/alert`.
