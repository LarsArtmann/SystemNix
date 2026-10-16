# Status: Offline Banner v2/v3 Iteration (bar push-down, timestamp, dismissable)

**Date:** 2026-10-16 04:43 CEST
**Scope:** this session segment only (02:26 → 04:43, after the 02:26 report): owner feedback iterations on the banner (animated bar push-down, "last online X ago" caption, click-to-dismiss), the deploy battle (PSI phantom storm + a broken shared build), and the standalone-demo discovery. No unrelated research.
**Deploy state:** v3 is COMMITTED (`e062ce9e`, daemon sweep) but NOT deployed — the live system (gen 904) still runs the v1 look. Deployment is blocked by the concurrent session's broken `browser-history-server` build.

---

## Direct answers to your three questions (brutal)

**What did I forget?**
1. **Docs drift, created by me.** desktop.md and FEATURES.md still describe the v1 banner (Overlay, static, click-through, no caption) while the module header + committed code are v3 (Top layer, exclusive-zone push-down, caption, dismissal). I updated the module header on every iteration but never went back to the two doc surfaces — while deployment is blocked, the docs describe behavior nobody can see. Fixed during this report's harvest (see Harvest record), but it should never have taken a report to catch.
2. **The stale `[blocked:user]` row I queued myself.** The bar-overlap question (report 1, §f.3) was ANSWERED by your feedback ("animate my waybar down") and implemented — but the queue row still sat there asking. Resolved in this harvest.
3. **Click-to-dismiss is shipped unverified.** No machine click was possible, and you didn't click during the 180 s demo window. Same anti-pattern I named in the 02:26 report's §d, repeated one report later: a committed, unverified interaction path. (Mitigation: it is one `MouseArea.onClicked` feeding the already-twice-proven slide binding — but "trivial" is not "verified".)
4. **The demo windows ran against a possibly-absent viewer.** Both demos auto-closed on a timer; the dismissal demo expired unclicked. A "tell me when you're looking" gate (or leaving it up until acknowledged) would have gotten the interaction verified in one pass.

**What could I have done better?**
- **Second deploy attempt was low-information.** After the first failure named `StateShape` in the other session's `browser-history-server`, retrying ~20 min later mostly re-measured their in-flight state. The correct move — which I eventually took — was: identify the blocker as external, flag it, switch to the standalone demo vehicle.
- **The standalone quickshell instance should have been the demo vehicle from demo #1.** It needs no deploy, no PSI-gate dances, no lock coordination — I only discovered it after being blocked by all three. Cost: ~40 min of gate-wait loops across the session for what a 10-second standalone run shows.
- **PSI attribution was nearly wrong.** I first read the `ghostty-7844` scope (nvtop) as the storm's cause; it was a stall VICTIM. The correct picture — sdb phantom-busy with zero waiters, already queued by the 01:06 session — stands, and I self-corrected before reporting. The near-miss goes on the pile: cgroup `io.pressure` measures EXPERIENCED stalls, not caused ones.
- **I executed `DEPLOY_FORCE_PRESSURE=1` autonomously.** The reasoning was stated (marginal I/O ≈ zero, storm = phantom-busy sdb, you actively iterating) and the gate documents the hatch — but a freeze-class gate override while you were present could have been a one-line heads-up with the action, not after.

**What could I still improve?**
- **A demo/force-offline mode in the module** (`OFFLINE_BANNER_DEMO=1` → skip probes, force show) would make every future demo and post-deploy verification a one-liner instead of a drop-in + unroutable-IP hack. Queued (§f.3).
- **Local-tree build breaks are invisible.** The browser-history break failed two of my deploys and paged nobody (CI only sees pushed trees). A tiny "toplevel build failing" signal (deploy-log watcher metric or nh-failure hook) would have told the other session someone was blocked on their break at 03:00 instead of 04:13. Queued (§f.6).
- **Concurrent-session chronology:** the `flake.lock` bump (bank-sync → go-cqrs-lite `d15e0a4`) landed mid-`flake check` and rode a heuristic daemon commit containing my files (`e062ce9e`). Nothing to fix — recorded here so the adjacency isn't misread as mine later.

---

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| v2 — animated bar push-down: banner switched to `WlrLayer.Top` + `ExclusionMode.Auto` with a `Behavior`-animated height; the DMS bar is repositioned per animation frame (your requested "slowly animate my bar down"), slides back on recovery | committed in `e062ce9e`; `nix flake check --no-build` green; qmllint no errors |
| v2 — "last online X ago" caption (1 s display tick; `unknown` until first clean probe — never lies) | committed; visible in both demos |
| v3 — click-to-dismiss: click anywhere on the strip slides it up for the rest of the outage; next clean probe re-arms; pointer-hand cursor; caption hint "· click to dismiss"; click-through mask removed (bar is pushed below, nothing clickable underneath) | committed; NOT machine-verified (see §b) |
| Two live demos of v2 behavior via a STANDALONE quickshell instance (`/tmp/offline-banner-demo`, session `WAYLAND_DISPLAY`), zero deploy needed; surface confirmed via `niri msg layers` before each window; clean exits after | demo logs (trashed post-session); "Looks better now" — owner verdict in chat |
| Correct PSI-storm attribution: `ghostty-7844`/nvtop scope is a stall VICTIM; the cause is the sdb phantom-busy churn already queued by the 01:06 session (100% util, zero waiters) | deploy-gate device-truth output + existing queue row |
| Two PSI-gate refusals honored, then a JUSTIFIED override (`DEPLOY_FORCE_PRESSURE=1`) — marginal-I/O argument documented in-session; deploy then proceeded past the gate to the REAL blocker | deploy logs (trashed); §b below |
| Harvest hygiene from report 1 maintained; the lock bump (`bank-sync` → go-cqrs-lite `d15e0a4`) that rode the daemon commit `e062ce9e` is flagged as the concurrent session's, not mine | commit `e062ce9e` contents |

## b) PARTIALLY DONE

| Item | Works | Open | Blocker | Effort |
| --- | --- | --- | --- | --- |
| **Deploy banner v3** | committed, eval+lint green | live system runs v1 (gen 904): no push-down, no caption, no dismissal | KNOWN ENUMERATED DEPLOY-BLOCKER (CHANGELOG 2026-10-16, the concurrent session): upstream `browser-history` master `cbe6bac` has a drifted vendored cqrs-htmx copy (`snapshot.go:200` `StateShape`) — fix is upstream-side, then SystemNix relock; "NO evo-x2 deploy can go green until this lands". My two failed attempts hit exactly this documented blocker | external — upstream browser-history fix + relock; S once landed |
| Click-to-dismiss | logic committed (one MouseArea → proven slide binding) | never clicked by human or machine | needs a live click (deploy first) or a virtual-pointer harness | S |
| v1→v3 doc parity | module header is v3 | desktop.md + FEATURES.md still say v1 — being fixed in THIS report's harvest (fix-on-sight, not queued) | none | done in harvest |
| Bar-overlap question (report 1 §f.3) | RESOLVED by owner decision + v2 implementation (push-down chosen) | stale `[blocked:user]` row being closed in this harvest | none | done in harvest |

## c) NOT STARTED (deliberate)

| Item | Why |
| --- | --- |
| Demo/force-offline mode (`OFFLINE_BANNER_DEMO=1`) | discovered the need mid-session; queued §f.3 |
| Broken-toplevel build signal (metric/hook) | noticed this segment; queued §f.6 (pipeline) |
| Snooze-style dismissal (re-show after N min) | current dismiss-for-this-outage semantics await your verdict (§g.2) |
| Machine click verification (virtual-pointer harness) | needs deploy first; queued with the live-verification debts |
| Automated click test infra | same |

## d) TOTALLY FUCKED UP

Nothing shipped is broken; the honest failures this segment:

1. **Docs describe undeployed behavior while the deployed behavior is undocumented-as-changed.** For ~2 hours, desktop.md/FEATURES (v1), the running banner (v1), the committed code (v3) and the module header (v3) told four partially-divergent stories. Split brain, self-inflicted, caught by writing this report. Fixed in harvest.
2. **"Committed" still means "unverified" for the dismissal click.** I named this exact anti-pattern in the 02:26 report and then repeated it within two hours. The difference: this time it is named in the same breath as the ship, and the verification path is written down (§f.4).
3. **Two full deploy attempts against a tree another session had broken.** The first failure's error named their file; the second attempt bought nothing. Pattern: I re-measure instead of escalating on external blockers.
4. **Storm-cause near-miss.** nvtop-scope-as-cause almost became the session's stated attribution; self-caught (victims ≠ causes), and the already-queued sdb phantom row is the truth. One more instance of "grep the existing queue before concluding".

## e) WHAT WE SHOULD IMPROVE

1. **Doc surfaces travel WITH behavior changes** — module header alone is not documentation; desktop.md/FEATURES are the read-first surfaces (repo's own routing table sends every session there first).
2. **Standalone-instance demos are the default demo vehicle** — no deploy, no gates, no lock; keep a trashed-`/tmp` harness recipe in desktop.md (added in harvest).
3. **Queue grepping before re-derivation** (repeated from report 1, and it fired AGAIN this segment: sdb churn + lock staleness were already queued).
4. **External blockers escalate immediately after the FIRST confirming failure** — the error naming another session's file is the signal; retrying re-measures their progress at full deploy cost.
5. **PSI override discipline:** when overriding, the justification (marginal I/O, phantom-storm class, owner present) belongs in the same message as the action.

## f) Things to get done next (ranked; harvest state marked)

| # | Task | Impact | Effort | Category | Harvest |
| --- | --- | --- | --- | --- | --- |
| 1 | Deploy banner v3 once the KNOWN deploy-blocker clears: upstream `browser-history` StateShape fix + SystemNix relock (enumerated in CHANGELOG 2026-10-16 by the concurrent session; blocked 2 of my deploys tonight) | High | S | Feature | → TODO_LIST + desktop.md [blocked:deploy] |
| 2 | Click-to-dismiss verification: first live outage/deploy click, or virtual-pointer harness | Medium | S | Verification | → merged into existing [watch] live-debts row |
| 3 | `OFFLINE_BANNER_DEMO=1` env: force-show without probes (makes demos + post-deploy checks a one-liner; retires the unroutable-IP drop-in hack) | Medium | S | Feature | → TODO_LIST + desktop.md [ready] |
| 4 | Broken-toplevel build signal: local-tree `nh`/toplevel failures page nowhere (two silent failures tonight); deploy-log watcher metric or failure hook | High | M | Feature | → TODO_LIST + pipeline.md [ready] |
| 5 | Banner observability (journal line + fail-closed presence metric) — timestamps are UI-only; a dead banner is still silent | High | S | Feature | already queued (report 1 §f.1) — unchanged |
| 6 | Banner VM/negative test (env-overridable sysroot + probe injection) | High | M | Quality | already queued (report 1 §f.2) — unchanged |
| 7 | v4 candidate: dismissal semantics options — snooze (re-show after N min) vs current dismiss-for-outage | Low | S | Feature | pending §g.2 |
| 8 | sdb buildcache phantom-busy churn — ALREADY QUEUED (01:06); this segment adds: sustained avg10 65-98% for 2.5 h+, blocked/refused 4 deploys total, nvtop scope is victim not cause | High | M | Bug | existing row, no change |
| 9 | deploy.sh lock liveness via fd-scan holder — ALREADY QUEUED+sharpened (report 1 §f.10) | Medium | S | Bug | existing row |
| 10 | IPv4-only probe blind spot — already queued | Medium | S | Feature | existing row |
| 11 | iface-exclude dedupe + "DMS plugins cannot render layer-shell" claim verify — already queued | Low | S | Cleanup | existing rows |
| 12 | Multi-monitor (2 surfaces w/ DP-2), reboot auto-start, CHANGELOG row — already queued [watch]/[ready] | Low | S | Verification | existing rows |
| 13 | Future-dated foreign status file `2026-10-29_…` — still unfixed, still foreign | Low | S | Cleanup | deliberately NOT harvested (foreign file) |
| 14 | Demo recipe → repo script (`scripts/prove-layer-banner.sh <namespace>` with LOUD harness errors) | Low | S | Quality | ROADMAP fuel |
| 15 | Reason-escalation emphasis (link→net change re-nudges even if dismissed?) — needs §g.2 semantics verdict first | Low | S | Feature | pending §g.2 |
| 16 | lessons.md candidate (crush-config): "victims vs causes in cgroup io.pressure attribution" + "harness errors must not launder into verdicts" | Medium | S | Quality | cross-project → lessons.md by commit, not this repo |
| 17 | `flake.lock` mid-session updates by concurrent sessions deserve a one-line flag in the touching session's report — recorded here; no mechanism yet | Low | S | Documentation | deliberate NOT-harvest (policy row already exists in pipeline.md for adjacent case) |

(Honest count: 17 — items 5-6/8-12 are carried from report 1 and still open; nothing padded to 50.)

## g) Questions I cannot answer myself

1. **Dismissal semantics:** when you click the banner away and stay offline, should it stay gone until recovery (current), or re-appear after a snooze (e.g. 10 min)? And should a reason escalation (link-down → internet-down) re-nudge a dismissed banner?
2. **"Last online" scope:** is per-session honest ("unknown" until first clean probe, resets every reboot) enough, or do you want the last online timestamp persisted across sessions (state file) so a morning boot shows "last online 9h ago"?
3. **Deploy etiquette:** when the tree heals, do you want me to auto-retry the v3 deploy, or always announce-and-wait for your go when another session is active?

---

## Harvest record (self-harvest at authoring time)

- **Fix-on-sight (no queue row needed):** desktop.md bullet + FEATURES.md row rewritten to v3 behavior (docs drift from §d.1 closed); bar-overlap `[blocked:user]` row (report 1 §f.3) RESOLVED in TODO_LIST + desktop.md; CHANGELOG row added for the banner (v1+iteration) and its queued row closed (CHANGELOG.md was clean at authoring time, 04:43).
- **Landed in `TODO_LIST.md` + `docs/todo/desktop.md`:** deploy-v3 [blocked:deploy] row (§f.1); demo-mode env [ready] (§f.3); live-debts [watch] row extended with the click-path (§f.2).
- **Landed in `TODO_LIST.md` + `docs/todo/pipeline.md`:** broken-toplevel build signal (§f.4).
- **Unchanged carried rows:** observability, VM test, IPv4/v6, dedupe, claim-verify, sdb churn, lock liveness, multi-monitor/reboot debts.
- **Deliberately NOT harvested:** §f.13 (foreign file), §f.15/§g items (pending answers), §f.14 (ROADMAP), §f.16 (cross-project → crush-config lessons by commit), §f.17 (recorded here only).
