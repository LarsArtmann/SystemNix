# 2026-09-02 22:10 — SEV1 memory alerts demoted from fullscreen-page to notify (deployed live)

**Session context:** user complaint mid-movie — "High memory should NOT flash my entire screen and stop me from watching my movie. 1. DISABLE the alert right now! 2. Fix that only stuff like shutdowns and ACTUALLY-impacted-soon events page."

## TL;DR

The sev1-escalation bridge treated `MEMORY EMERGENCY GUARD TRIPPED` (plus sustained memory stall and guard dead) as `page` tier = fullscreen red overlay on every monitor. ALL memory conditions are now `notify` tier (one self-expiring normal-urgency notification + Gatus/Discord, per-key 30-min cooldown, NO overlay). The `page` tier is now reserved for infra hardware criticals ONLY (DAS USB link, LAN NIC, btrfs critical). Deployed and verified live at 21:46.

## Root cause (live evidence)

At 21:23 the alert file held `MEMORY EMERGENCY GUARD TRIPPED` with severity line `page`, rewritten every 10s by the root bridge; the overlay user unit (`Restart=always`) re-rendered it fullscreen. The guard's churn loop (trip → restore → consumer re-wake → re-trip) made it recur across the day — the same class as the earlier "MEMORY EMERGENCY all-day overlay spam". The page was wrong BY DESIGN, not just by frequency: the guard's entire job is to CONTAIN the emergency automatically (stop flm + socket); the user cannot act mid-movie; if containment fails the kernel freezes and no overlay can render anyway.

## New tier contract (user decision recorded in module header + AGENTS.md)

| Tier | Behavior | Conditions |
| ---- | -------- | ---------- |
| `page` | fullscreen overlay + persistent critical notification | **infra hardware criticals ONLY**: DAS link down, LAN NIC absent, btrfs critical |
| `notify` | one self-expiring normal-urgency notification + Gatus/Discord, NO overlay, cooldown-gated | guard trip, sustained memory stall (avg60 ≥45 or episodic bucket ≥4), guard dead, system monitoring stale, zram swap critical (combined gate), FLM restore capped |

Actual system shutdowns already have their own dedicated countdown overlay (`shutdown-overlay.nix`) — untouched.

## Files changed

- `modules/nixos/services/sev1-escalation.nix` — 3 severities `page`→`notify` (trip, stall, guard-dead); header now documents the hardened tier contract with the user quote; module description updated.
- `tests/test-sev1-escalation.nix` — tier contract flipped mechanically: trip/stall/episodic/guard-dead scenarios assert `severity=notify`, alert-file line 4 `notify`, `sev1_bridge_page_alerts_active 0`; only the DAS scenario asserts `page`. Header carries the tier-contract note.
- `modules/nixos/services/gatus-config.nix` — "SEV1 Escalation Bridge" check alert text updated (page = infra criticals only).
- `AGENTS.md` — sev1 bullet: HARD RULE documented ("NO memory condition may EVER fullscreen-page").
- `flake.lock` — cv node rolled back `a03ff09`→`7dee729` by this session to unblock the deploy; re-bumped to `6615eec` by the CV session at 22:04 (`5192ad1f`) after they pushed the upstream fix.

## Verification

- `nix build .#checks.x86_64-linux.sev1-escalation` — PASSED (12 scenarios against the REAL bridge script; only the prom inputs are faked): active trip → notify + page_alerts_active 0; avg60 stall and episodic stall → notify; guard-dead → notify; DAS → page (the only remaining page path); zram steady-state silent; boot grace intact; resolved trip clears.
- Deploy switched to `/run/current-system = r26nn0zq…` (nixos-system-evo-x2-26.11.20260831.34ab990) at 21:46.
- Live: deployed `sev1-bridge.service` ExecStart script (`gjap8b7y…`) contains exactly 6 `notify` severities and 3 `page` severities (DAS/NIC/btrfs only); trip detail text says "this alert clears automatically…".
- Live: `/run/systemnix/sev1/` empty (no alert); `sev1-bridge.prom`: `alerts_active 0`, `page_alerts_active 0`; `page_last_duration_seconds 607` = the movie-interrupting page that existed pre-fix (~21:14→21:33).
- Overlay user unit correctly deployed and retained (TTL 120, enabled under `graphical-session.target.wants`) — it stays for genuine infra pages.

## Deploy train story (parallel sessions)

1. First deploy attempt failed: `cv-prepared-source-a03ff09` (CV input bumped 21:37 by the CV session) failed `mkPreparedSource` validatePrivateDeps — `templ-components/datastar` matched the private glob with no replace/publicDeps entry.
2. The CV session fixed it upstream (CV `6615eec`, `nix/packages.nix` publicDeps += `templ-components/datastar` et al., 21:49) but remote master was still `a03ff09`, so the lock could not move forward.
3. This session rolled the lock's cv node back to last-known-good `7dee729` and deployed (user's fix is urgent; broken pins do not deploy).
4. The CV session pushed CV and re-bumped the lock to `6615eec` at 22:04 (`5192ad1f`). **NOT yet deployed** — current-system still carries cv=`7dee729`; a follow-up deploy ships the CV update.
5. Post-deploy smoke: the `post-deploy-check` APP failed to build (SC1091: `scripts/lib/pressure-report.sh` sourced but not packaged into the app — same lib-packaging class the same session fixed for pre-deploy-check's `metrics-gate.sh` at `f24492c6`). The switch and deploy.sh post-switch steps completed; only the smoke step failed. Owned by the parallel session's WIP refactor — not co-edited here per concurrent-session rules.

## Six-question self-review

### Edge cases not handled
- If the bridge itself dies, memory alerts never reach the desktop — but the Gatus "SEV1 Escalation Bridge" check + Discord still fire, and the guard (not the desktop) is the layer that saves the machine.
- DAS/NIC/btrfs pages will still fullscreen during a movie — that is the intended contract, but it is the user's call (asked at end of session).
- The VM test enforces the tier per CURRENT condition; a future NEW memory condition written as `page` would not be caught by a generic invariant (see improvements).

### Feature interactions checked
- `memory-emergency-guard`: unchanged; trip still feeds the bridge, now notify; `maxRestoresPerDay` / FLM RESTORE CAPPED path intact (test scenario 11).
- `sev1-overlay` QML: unchanged; `severityIsPage` still fails LOUD (missing severity line = page) so a parse gap can never silence a real emergency.
- Gatus: conditions unchanged (any `alerts_active ≥ 1` alerts); alert text updated; zram/stale notify delivery + per-key cooldown all green in tests.
- FastFlowLM consumers (PMA go-commit, papdashboard enricher): trip → socket-stop flow unchanged.
- Shutdown countdown overlay: separate module, untouched.

### Data-integrity risks
- None. No stores, databases, or secrets touched. Bridge state-file semantics unchanged. The lock rollback was superseded by the CV session's proper re-bump; git history shows both moves.

### Security vulnerabilities
- None introduced. No new PATH binaries, no secrets, no auth changes; alert file remains root-owned 0644 in boot-ephemeral `/run`.

### Empty-context danger
- Mitigated: the tier contract lives in three synced places (module header, AGENTS.md sev1 bullet, VM test header) with the user quote — a fresh session cannot re-page memory conditions without contradicting documented decisions, and the VM test enforces it mechanically for all six memory/meta conditions.
- Residual: a brand-new memory condition could be authored as `page`; only a generic lint would catch it (not built).

### If starting from an empty context
- The tier of every condition is asserted in `tests/test-sev1-escalation.nix` (scenarios 2, 3b, 3c, 4, 6, 9, 10, 11); the only page-tier conditions are DAS/NIC/btrfs (scenario 6). cv=`6615eec` is locked but undeployed; check the post-deploy-check app packaging before the next deploy.

## Improvements (ranked, intentionally NOT done — scope discipline)

1. Package `scripts/lib/pressure-report.sh` into the post-deploy-check app (mirror of the f24492c6 fix) — restores the deploy smoke gate. Owner: the session refactoring that script.
2. Follow-up deploy to ship cv=`6615eec`.
3. Generic tier lint: eval-time check that the bridge script contains exactly the 3 sanctioned page severities, mutation-tested via the `scripts/negative-test-lints.sh` pattern.
4. Optional counter `sev1_bridge_notify_suppressed_pages_total` — visibility into how often the old page tier WOULD have fired, to validate the contract hides nothing real.
5. User decision pending (asked): keep DAS/NIC/btrfs at page, or soften?

## Honest uncertainty

- The live trip→notify path is proven by the VM test against the deployed script, not by a live trip (none can be forced safely). First real trip post-deploy: `cat /run/systemnix/sev1/alert` line 4 must read `notify` (or journal: `SEV1 active (1 condition(s), severity=notify)`).
- DMS notification rendering was not visually verified (no graphical-session access from this context); the notify-send code path is unchanged and proven by prior notify-tier alerts.
