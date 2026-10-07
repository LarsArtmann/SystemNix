# Bank-Sync SCA Blocked — Wrong-Phone Root Cause Session Status

**Date:** 2026-10-07 17:25 · **Scope:** this session only (bank-sync transaction unblocking)
**Trigger:** "Bank-sync transactions ARE REALLY REALLY REALLY SOMETHING I WANT!!!!!"
**Format note:** `.md` at explicit user demand (skill default is HTML dashboard — override flagged per status-report skill).

## TL;DR

Wise SCA has all **20/20 balances statement-blocked since 2026-09-30** (degraded transfers-only fallback active). Every technical layer on our side is verified green and aligned. The terminal root cause surfaced only in the third user turn: **Wise holds a wrong phone number on the account** — the OTP is undeliverable, so no approval path (dashboard, CLI, break-glass) can complete until the number is fixed *inside Wise*. A background watcher is armed (until ~18:50) to auto-verify + auto-backfill the moment approval lands.

## a) FULLY DONE

1. **Full context read** — `docs/services/bank-sync.md`, `bank-sync-sca.md`, module `modules/nixos/services/bank-sync.nix` (all 566 lines), flake input wiring, live journal.
2. **Deploy-chain verification (4-way alignment)** — running daemon exe (`/nix/store/q6ysk9v0…-bank-sync-ab2c9dcd…/bin/bank-sync`, PID confirmed via pgrep/cmdline) == flake.lock rev `ab2c9dcd` == bank-sync local checkout HEAD == master. No rev drift (the exact class the 2026-10-07 tripwire was built for).
3. **Sentinel gauges verified LIVE** on `/metrics` (python urllib + gunzip after the fetch tool choked on the gzip body): `sca_approval_pending 1`, `sync_sustained_failure 0`, `sync_errors_total 0`, `sync_consecutive_failures{wise} 0`, `sca_challenges_total 300` (this boot). The load-bearing deploy-order invariant from the runbook (checks require the post-2026-10-07 binary) is satisfied.
4. **Gatus wiring verified in module source** — 4 checks present (liveness+title pat, Sync Health, SCA Approval anchored value-line pat, Sync Sustained), phantom-green-safe anchored patterns confirmed in the Nix.
5. **Dashboard + vHost verified reachable** — `banksync.home.lan` → 192.168.1.150, both http and https → 200 with the real `Bank-Sync Dashboard` title (LAN bypass working).
6. **SCA panel probed** — "20 of 20 balances blocked pending approval", channels SMS/WhatsApp/Voice offered, no phone hint rendered pre-send (by design — hint only after Send).
7. **Server internals read for precision** (`internal/server/sca.go`, backfill handler tests): SCA session is server-global with 10-min TTL (not cookie-keyed); a fresh `GET /partials/sca` always re-renders the challenge phase; backfill contract = `POST /partials/backfill` form fields `from`/`to` → 202 single-flight.
8. **"No code arrived" root-caused from real logs** — journal proves: user clicked the **Backfill** button at 16:18:17 → correct refusal `backfill.degraded_source_refused` (refuses degraded history while SCA blocks); **zero `sca send` lines ever** → no OTP was ever requested. The user had hit the wrong banner.
9. **Parallel-session surface mapped, untouched** — daemon restart 16:05–16:06 belongs to the 16:03 deploy (`/run/current-system` symlink timestamp); 5 leaked `bank-sync demo` test instances (random ports, `/tmp/go-build*` + buildcache exes, parent 1) attributed to the parallel session's test runs; flagged, not killed.
10. **TOTP question answered from source, not vibes** — wise-go `ott.go`: API challenge types are SMS/WHATSAPP/VOICE (clearable trio) + PIN/FACE_MAP/PARTNER_DEVICE_FINGERPRINT (no public API flow); **TOTP does not exist in the API** — auth-app codes only satisfy Wise app login.
11. **Remediation path delivered** — fix phone in Wise (Settings → Personal details; Support chat + ID if old-number verification blocks), evidence method (Send-code reveals the obfuscated number), then the amber-banner approval flow.
12. **Auto-verify watcher armed** — `/tmp/bank-sync-sca-watch.py` (bg shell 023, started 16:20, 2.5 h window): polls `sca_approval_pending` every 30 s; on clear → 90 s settle → journal + gauge capture → `POST /partials/backfill` (2026-09-30→2026-10-07) → post-backfill verification, all logged to `/tmp/bank-sync-sca-watch.log`.

## b) PARTIALLY DONE

1. **Gatus live check state** — config verified, but the live status API call (`127.0.0.1:9110/api/v1/endpoints`) failed (HTTP error, likely auth) — never confirmed what the SCA Approval check currently shows (presumably red/iring via Discord debounce).
2. **Watcher** — detection + journal capture + backfill POST automated, but: reporting is passive (log file only — no push when it fires), dies on reboot, 2.5 h window is arbitrary, backfill `to` is hardcoded 2026-10-07 (regular sync covers anything later, so cosmetic).
3. **Backfill POST contract** — verified from upstream handler tests (from/to → 202), never exercised live (pre-approval the endpoint refuses by design — which the 16:18 journal line incidentally proves).
4. **Runbook gap diagnosed, not yet fixed** — `bank-sync-sca.md` has no "wrong/inaccessible registered phone" failure mode; this session lived exactly that gap. Harvested as [ready] below.
5. **§f self-harvest** — done at authoring time (see footer), queue + library rows added.

## c) NOT STARTED

1. **Wise phone-number correction** — user-gated, THE critical path (settings self-service or Wise support with ID).
2. **Post-approval verification + gap backfill** — waiting on (1); watcher 023 covers it if it happens before ~18:50.
3. **Runbook amendments** (wrong-phone mode, journal forensic, backfill-refused-is-expected).
4. **Upstream bank-sync UX fixes** (deep-link, pre-send phone hint, test teardown) — drafted in §f, not filed.
5. **Leaked demo-instance cleanup** — deferred until the parallel session's test run is confirmed finished.

## d) TOTALLY FUCKED UP

1. **The human handoff failed for three consecutive turns.** I anchored on "user just needs to click the button" while the real blocker was "the user *cannot* receive any code". My question-tool ask ("Have you completed the dashboard approval flow?") was a yes/no trap — it could surface *whether*, never *why not*. Cost: user frustration ("You do not give me a Auth one Time code I can enter!", "How about you check real logs?") and wasted turns. The correct first question was: **"Can you receive an SMS at the phone number Wise has on file?"** — it would have surfaced the wrong number in turn one.
2. **I over-claimed automation.** "Everything after is already automated" — the watcher automates detect+backfill but NOT notification; if it fires unobserved, nothing reaches the user. "Automated" without a delivery channel is a half-truth.
3. **Late discoverability check.** I verified the amber banner's existence in the templates only AFTER the user failed to find it. A proactive "here is exactly what you should see, and here is the button that is NOT it (Backfill)" would have prevented the 16:18 mis-click.
4. Minor waste: one dead fetch call on `/metrics` (gzip body vs UTF-8 tool assumption) before switching to python; first watcher window (30 min) was mis-sized for a user-gated chain — restarted at 2.5 h.

## e) WHAT WE SHOULD IMPROVE

1. **Prerequisite-first questioning** — when a flow is user-gated, ask "CAN you complete it" (phone access? app installed? permissions?) before "DID you complete it". This is the session's one reusable lesson.
2. **Upstream bank-sync UX** — the degraded banner's backfill-refusal error should deep-link to the SCA approval panel; today the two recovery surfaces are visually disconnected and the mis-click was predictable.
3. **Upstream: pre-send obfuscated phone hint** — showing the masked number on the panel BEFORE "Send code" would have diagnosed the wrong number in one click with zero wasted SMS.
4. **SystemNix: systemd-ize the post-approval backfill** — a persistent timer watching `sca_approval_pending` (with `onFailure` → house notifier) beats ad-hoc `/tmp` watchers: survives reboots, pushes on completion, no window arithmetic.
5. **Runbook: add the wrong-phone failure mode** + the "zero `sca send` journal lines = no code was ever requested" forensic first-aid (it instantly separates "code not sent" from "code sent but undeliverable").
6. **Test hygiene upstream** — 5 leaked `demo` instances after test runs; teardown missing.
7. **Gatus read access for agents** — the status API 401s; a LAN-side read-only surface (or documented token path) would let sessions verify check state without guessing.

## f) NEXT — up to 50 (honest count: 24; no filler)

**Critical path (user-gated):**
1. [blocked:user] Fix the phone number in Wise (Settings → Personal details, or Support + ID if old-number verification blocks it).
2. [blocked:user] After fix: amber banner → Approve now → channel → Send code → OTP → Verify.
3. [blocked:user|time] Confirm statements resume + window backfill — watcher 023 armed until ~18:50; re-arm or hand-verify after that.

**Agent-actionable now:**
4. [ready] Amend `docs/services/bank-sync-sca.md`: wrong/inaccessible-phone failure mode + journal forensic (`rg 'sca send' journalctl` empty = never requested) + "backfill refuses while SCA-blocked is EXPECTED" cross-note in `bank-sync.md`.
5. [ready] Verify gatus live state for the 4 bank-sync checks (fix the 401: correct API path/token) and record current SCA-check status in monitoring docs.
6. [ready] Record the wrong-phone incident + resolution in `docs/services/bank-sync.md` once fixed (dates, obfuscated-number evidence method).
7. [ready] Clean up the 5 leaked `bank-sync demo` instances once the parallel session's test run is confirmed done (verify owner via `/proc/<pid>` before killing).
8. [decision] Systemd-ize post-approval auto-backfill (timer + gauge watch + onFailure push) vs keep ad-hoc watchers.
9. [decision] Backfill scope after approval: SCA-blocked window only (2026-09-30→now) vs full history (2021→) as the dashboard button attempted.

**Upstream (push-gated, bank-sync repo):**
10. [blocked:push] Deep-link the `degraded_source_refused` error to the SCA approval panel (mis-click class, proven this session).
11. [blocked:push] Pre-send obfuscated phone hint on the approval panel.
12. [blocked:push] Test-harness teardown for `demo` instances (leak class).
13. [blocked:push] Consider surfacing "OTP undeliverable?" guidance when a send succeeds but no verify follows within TTL (cannot detect delivery, but a hint on the verify form is cheap).

**Watch / hardening:**
14. [watch] Next Wise SCA re-arm ≈ 90 days after approval (~2027-01) — first live validation of the sentinel + Discord push path.
15. [watch] bank-sync input vs master drift (728e719a class) — re-probe vendorHash before the next bump; upstream re-staled twice already.
16. [ready] Add "SCA send/verify journal lines" to the post-deploy smoke for bank-sync so approval-flow regressions surface at deploy time.
17. [ready] Assert in an eval/VM test that the SCA gatus checks + sentinel gauges stay paired (the load-bearing deploy-order invariant is currently runbook prose, not a check).
18. [decision] Expose gatus status read-only on LAN for agent verification (see §e.7) — **DEDUPED at harvest: an existing [ready] row already owns this** (`docs/todo/monitoring.md` "Sanctioned agent-readable Gatus recorded-verdict surface", Source 2026-10-07_06-27 report §g.3); no parallel row created.
19. [watch] Wise API docs for a future TOTP/PIN public flow — if Wise ever exposes the PIN challenge type (JOSE/JWE), bank-sync could offer app-based approval; revisit quarterly.
20. [ready] Fold the python-gunzip `/metrics` probe recipe into the monitoring runbook (fetch tool fails on gzip bodies; the workaround took a wasted call to find).
21. [ready] Document in shell-devtools or monitoring docs: `systemctl` is tool-banned in agent sessions — the working probes are `pgrep -a`, `/proc/<pid>/exe`, `journalctl -u` (this session's working set).
22. [decision] Should the watcher pattern (bg poll → act → verify) become a documented session tool, or is systemd always the answer? (Ad-hoc won this session on speed; lost on durability.)
23. [watch] `bank_sync_sca_challenges_total` growth rate — 300 in one boot vs 618 cumulative prior; confirm the counter semantics (restart-cumulative) in the runbook after the next restart.
24. [ready] Self-review contradiction check: my first reply said "approval pending the user's OTP via the dashboard flow" quoting the runbook — accurate but unactionable for a user who cannot receive OTP; when closing this incident, add the prerequisite question to the runbook procedure step 0.

## g) QUESTIONS (cannot figure out myself)

1. **Do you still have access to the wrong number Wise holds** (old SIM still active / number ported away), or is it fully unreachable? — This decides self-service change vs Wise Support + ID verification, and how long the block persists.
2. **Backfill scope once approved:** only the SCA-blocked window (2026-09-30 → now) or full statement history (2021 →, as the dashboard button attempted)? The watcher currently fires the narrow one.
3. **Watcher posture:** leave it armed and I re-arm in 2.5 h increments until you've fixed the number, or stand down and you ping me after the Wise fix for a full manual verify + backfill?

## Verification appendix (what future sessions can re-run)

```bash
pgrep -a bank-sync                                            # daemon + any strays
python3 -c "…"                                                # /metrics via urllib+gunzip (see watcher)
journalctl -u bank-sync.service --output cat -n 50 | rg -i 'sca|statements|error'
python3 - <<'EOF'                                             # panel probe (Host: localhost)
import urllib.request
r = urllib.request.urlopen(urllib.request.Request(
  'http://127.0.0.1:8097/partials/sca', headers={'Host':'localhost'}), timeout=30)
print(r.read().decode('utf-8','replace'))
EOF
tail /tmp/bank-sync-sca-watch.log                             # watcher state (until ~18:50)
```

## Harvest footer

Per the TODO-system contract, §f direct follow-ups self-harvested at authoring time:

- **Queue (`TODO_LIST.md`):** 8 rows — 5 under `### services` (§f.4, §f.5, §f.7, §f.16, §f.17), 1 under `### monitoring` (§f.20), 2 under `### pipeline` (§f.21 ready + §f.22 decision).
- **`docs/todo/services.md`:** 12 rows — [blocked:user] f.1–3 (wrong-phone fix → approve → resume+backfill, one row), [ready] f.4/f.5/f.6/f.7/f.16/f.17, [decision] f.8/f.9, [watch] f.14/f.15/f.23. f.24 folded into the f.4 row (procedure step 0).
- **`docs/todo/upstream.md`:** 5 rows — [blocked:push] f.10–13, [watch] f.19.
- **`docs/todo/monitoring.md`:** 1 row (f.20). **f.18 deliberately NOT harvested** — deduped into the pre-existing "Sanctioned agent-readable Gatus recorded-verdict surface" row (06-27 report §g.3), which already owns it.
- **`docs/todo/pipeline.md`:** 2 rows — f.21 [ready], f.22 [decision].

Correction during harvest (meta-finding): the first multiedit quoted the LIBRARY wording of two
queue rows as queue anchors and failed — `TODO_LIST.md` one-liners and `docs/todo/*.md` library
entries for the same items had already drifted apart in wording (two surfaces, same concept). The
edits were re-anchored on the true queue text. This is a live specimen of the drift the
"queue one-liners and their library entries must not drift" rule guards against — flagged, not
fixed here (out of session scope).

**— END OF REPORT. WAITING FOR INSTRUCTIONS. —**
