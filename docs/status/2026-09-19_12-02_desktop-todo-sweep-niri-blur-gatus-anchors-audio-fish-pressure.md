# Status: Desktop-Domain TODO Sweep — 6/6 Ready Items Closed, Deploy-Gated, Two Foreign Toplevel Breakers Flagged

**Session focus:** Execute every agent-actionable (`[ready]`) item in `docs/todo/desktop.md` end-to-end: implement, verify at the strongest available gate, bookkeep the TODO system, and flag anything belonging to parallel sessions.

**Session scope:** One window, 2026-09-19 ~10:15–12:02 CEST. Repo: SystemNix `master`. **NOTHING IS DEPLOYED** — all config ships at the next `nix run .#deploy`, which is currently **blocked by two failures in files owned by parallel sessions** (details in §d).

**Verification posture:** `nix flake check --no-build` green · `nix fmt --no-update-lock-file -- --ci` green (2262 files, 0 changed — after fixing two pre-existing broken HTMLs that had the gate red tree-wide) · `tests/test-gatus-patterns.nix` VM test **passed** (real gatus evaluating the new anchored patterns against adversarial HELP comments) · all four touched derivations build individually (niri collector unit, gatus unit, post-deploy-check app, niri-config.kdl with `niri validate`) · deadnix/statix/doc-links clean · pressure-aware fish check fixture-tested across 5 synthetic branches.

---

## a) FULLY DONE

| #  | Item                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Where                                                                                                                                          | Proof                                                                                                                                                                                                                         |
| -- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A1 | **Four sibling niri VALUE-0 Gatus checks anchored** — "Niri Desktop Died" / "Crash Loop" / "Zombie Session" / "AW Watcher Attached" moved from bare `pat(*niri_desktop_died 0*)` (safe only while `niri.prom` has no HELP/TYPE comments — one collector rewrite from the 2026-08-22 phantom-green class) to the line-anchored `pat(*\n<metric> 0\n*)`                                                                                                                                                                                                                                                                                                                                                                        | `modules/nixos/services/gatus-config.nix` (~815–846)                                                                                           | Rendered YAML inspected: 4 anchored, **0 bare forms remain**; encoding byte-identical to the known-good `system_niri_metrics_fresh` pair                                                                                      |
| A2 | **VM regression coverage for the anchoring** — mock body grew the four metrics WITH adversarial HELP comments that deliberately repeat the metric names + value text (`… niri_desktop_died 1 if the desktop died`); one endpoint carries the exact four production conditions verbatim; a `[TEST-RED]` inverse asserts the anchored value-1 form must NOT match (catches the anchored pattern going vacuous)                                                                                                                                                                                                                                                                                                                 | `tests/test-gatus-patterns.nix`                                                                                                                | VM test **built and passed** (`vm-test-run-gatus-patterns`) — real gatus, real glob engine                                                                                                                                    |
| A3 | **Collector journalctl greps timeout-bounded (§f25)** — both `journalctl --grep` counts in `niri-health-metrics` wrapped in `timeout 10` per the 2026-08-31 journal-stall doctrine (a wedged journalctl must not stall the 30s collector into a stale-textfile fleet-blind window); comment cites the doctrine and the journalctl-exit-1-is-valid-empty trap                                                                                                                                                                                                                                                                                                                                                                 | `modules/nixos/desktop/niri-config.nix:237–247`                                                                                                | Realized script contains exactly 2 `timeout 10 journalctl`; `bash -n` OK; sibling `niri-drm-healthcheck.sh` already had `timeout 15`, `display-watchdog.sh` has no journalctl — collector was the only gap in the niri family |
| A4 | **Freshness-composite contract documented (§f24)** — AGENTS.md niri bullet now states: the "Niri Compositor" check owns collector-death alerting for ALL niri checks (node_exporter serves frozen textfiles forever; a dead collector blinds every sibling at last values); new niri metric checks must NOT grow their own freshness condition; records the anchoring + timeout work                                                                                                                                                                                                                                                                                                                                         | `AGENTS.md` (niri bullet, "Intentionally headless" entry)                                                                                      | —                                                                                                                                                                                                                             |
| A5 | **audio.nix WirePlumber-vs-smart-audio conflict RESOLVED** — the `51-hdmi-monitor-priority` block removed. Verdict from verification: it was **doubly dead** — (1) its `alsa_card.pci-0000_c5_00.1` match pinned the pre-crash PCI address that renumbered to `c6` on 2026-08-31, so it matched NOTHING since (the exact "never pin PCI addresses" trap smart-audio already fixed for itself); (2) `device.restore-profile = false` would have re-applied static priorities on every device event against smart-audio's focus-driven switches. WirePlumber now keeps the default restore-profile, so device events re-apply the _daemon's_ last choice. AGENTS smart-audio "coexistence unverified" note updated to RESOLVED | `modules/nixos/desktop/audio.nix`, `AGENTS.md:339`                                                                                             | Semantic analysis against smart-audio.nix source + the AGENTS-documented c5→c6 renumber; config builds (`wireplumber-*-config` derivations green in the toplevel attempt)                                                     |
| A6 | **Fish startup check is pressure-aware** — the recurring 200–3700 ms WARNs were deploy-IO page-cache contention (measured decay series 460→366→250→218 ms tracked one storm; 60–70 ms calm), not shell regressions. The check now reads io PSI some avg10 (deploy.sh's exact parser) BEFORE timing: <200 ms → PASS; ≥200 ms with PSI ≥5% → WARN "UNDER IO PRESSURE — pressure-attributed"; ≥200 ms calm → WARN "real regression, profile it"                                                                                                                                                                                                                                                                                 | `scripts/post-deploy-check.sh` (~1319–1347)                                                                                                    | Fixture harness: all 5 branches correct (calm+fast / calm+slow / storm+slow / elevated 6.5% / missing PSI file); derivation builds (shellcheck gate)                                                                          |
| A7 | **`nix fmt --ci` gate unblocked tree-wide** — two 2026-09-16 report HTMLs carried one stray `</div>` each after `</main>` (prettier `SyntaxError: Unexpected closing tag "div"` → every fmt run exited 1 over the whole tree). Removed both closers                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | `docs/reviews/2026-09-16_20-52_brutal-self-review.html`, `docs/status/2026-09-16_20-52_status-hermes-live-unanchored-generation-io-storm.html` | `nix fmt --no-update-lock-file -- --ci` now rc=0, 0 changed. Note: this gate being red predates the session — it was red since Sep 16                                                                                         |
| A8 | **Bookkeeping** — `docs/todo/desktop.md`: 5 items pruned, blur item converted to `[blocked:deploy]` visual-verify, live-gatus item extended with the anchored-siblings clause; `TODO_LIST.md`: desktop queue section emptied of ready items + 3 broken `**Source:**` husk lines removed (harvest-artifact class); `CHANGELOG.md`: 5 entries added (blur under Added, 3 under Changed, 1 under Fixed)                                                                                                                                                                                                                                                                                                                         | three files                                                                                                                                    | doc-links check OK                                                                                                                                                                                                            |

---

## b) PARTIALLY DONE

1. **Niri blur (the headline item)** — _implemented and machine-verified, but invisible until deploy + re-login, and the LOOK is unverified._ niri-flake's typed settings have NO options for niri 26.04's `background-effect` nodes (checked upstream `main` — only a shadow-docstring mentions blur), so `niri-wrapped.nix` appends a catch-all `window-rule { background-effect { blur true } }` to the rendered `programs.niri.finalConfig` and re-validates the whole file with `niri validate` at build (same gate niri-flake itself uses — a bad KDL fails the build, not the session). Xray defaults ON with blur active (wallpaper blurred once per output and reused — the cheap path). **Open halves:** (a) deploy; (b) visual verification by a human (filed as `[blocked:deploy]` in desktop.md); (c) global blur params left at niri defaults (passes 3 / offset 3 / noise 0.02 / saturation 1.5) — untuned; (d) DMS/quickshell **layer-rule** blur deliberately NOT wired — the layer namespace is unverified and I refused to guess an app-id/namespace.
2. **Everything else in §a is config-complete but DEPLOY-GATED** — the gatus anchors, collector timeouts, audio removal, and fish check all ride the next switch. Until then the deployed generation still runs the old bare patterns / unbounded journalctl / static audio rules.
3. **Live verification of the niri gatus surface** — item extended (anchored siblings must stay green post-deploy) but still `[blocked:user]`: the bounce-cadence replay and a real SDDM login are owner-performed.
4. **Roadmap/feature docs** — CHANGELOG updated, but `ROADMAP.md` still lists "Niri blur" as an open idea (now stale — the HM-module-absence rationale is superseded by the KDL-append approach) and `FEATURES.md` has no niri-blur row. Not done this session; listed in §f.

---

## c) NOT STARTED (deliberately out of scope, still open in the domain)

1. `[blocked:user]` Runtime-verify wf-recorder screen recording on niri (build-proven only).
2. `[blocked:user]` Smart-audio audible verification + reverse direction, incl. the never-tested DP-2 cross-output path (test-tone tooling on PATH since 08-22).
3. `[decision]` btop privileges + terminal-restore policy (sudoers NOPASSWD vs unprivileged; restore ONE ghostty vs ZERO).
4. `[blocked:user]` Post-storm niri-session-manager live confirmation (one login/restart cycle, exactly one restore pass, no ghostty pile).
5. `[decision]` Signal Desktop backlog (green preset in UI vs SQLCipher seeding script; `docs/services/signal.md`; verify-or-retract the "appearance syncs to linked devices" claim).
6. `[blocked:user]` The live niri gatus replay (above).
7. **Fleet-wide bare-VALUE-0 sweep** — ~20 remaining bare `pat(*metric 0*)` checks outside niri (system-health ×~10, mail-relay ×2, attic, bank-sync, signoz, gatus-config ×~5). Scoped OUT of §f23 (which asked for exactly the four sibling checks); already covered by the existing "extend gatus-pattern-lint to ENFORCE anchored value-checks" item in `docs/todo/monitoring.md`. The four niri anchors shrink that future lint's blast radius but don't close it.
8. No new work started on any other domain (per instructions: report, don't research).

---

## d) TOTALLY FUCKED UP (nothing by this session — but two things I must flag loudly)

1. **The shared toplevel build is BROKEN by parallel sessions — and therefore so is the next deploy.** `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` fails on two derivations in files I never touched:
   - `system-health-metrics` — shellcheck **SC2034** (`INACTIVE_SCRAPE_ERRORS` appears unused) inside a new `collectEnabledInactive` feature block that another session is mid-flight on (`modules/nixos/services/system-health.nix`).
   - `systemd-graph-webui-pnpm-deps` — **fixed-output hash mismatch** (`specified sha256-zZQ2…` vs `got sha256-MkUf…`) → cascades through `systemd-graph-webui`, `systemd-graph-src-with-webui`, go-modules, the package, and its restart-triggers (`pkgs/systemd-graph`).
     I did NOT touch or "fix" either — they are another session's in-flight work (destroying or co-editing it is the documented sabotage class). My own derivations were proven green **individually** precisely because the shared toplevel cannot go green until those clear.
2. **The auto-commit daemon swept this session's work into shared commits with other sessions' files.** Commit `12f814d9` ("auto-commit 10 changed file(s)") contains my `audio.nix` + `niri-wrapped.nix` + `AGENTS.md` edits **alongside** foreign files (`llama-vlm.nix` 190 lines, `papdashboard.nix` +95, `flake.nix` ±15, boot-mirror scripts, a planning doc). Commit-level attribution for my core work points at a shared commit. File-level attribution is clean; no amend was attempted (daemon-race discipline: never amend into a daemon commit without verifying what it staged). `CHANGELOG.md` is still uncommitted at report time — the daemon will pick it up.
3. **(Minor, own it) The repo's fmt gate had been silently red since Sep 16** — anyone running `nix fmt --ci` or CI fmt in that window hit the prettier SyntaxError. I fixed it (A7), but the three-day red window is a process observation: the gate only ran tree-wide when someone invoked it, and no CI signal surfaced it (or CI fmt is not wired to fail loudly). Worth checking whether `nix-check.yml` actually gates on fmt.

**Nothing in this session's own work is fucked up** — every failure hit during the session was recovered in-place (see §e for the honest list).

---

## e) WHAT WE SHOULD IMPROVE (including my own misses this session)

**My misses / inefficiencies (owning them):**

1. **Two failed edits from not copying text verbatim.** The audio.nix edit failed because I retyped a comment from memory ("app interconnection" vs the file's "audio app interconnection") despite having the file in context; the test-file multiedit failed on whitespace context. Both recovered with exact-match retries — but each cost a round trip. The read-then-exact-copy discipline has no exceptions, even when I "just read it".
2. **Blur research probed in the wrong order.** I grepped niri-flake for `blur` support before reading niri's OWN wiki at the deployed rev — the schema had changed (v26.04 moved blur behind `background-effect` rules; the old "top-level enable" mental model from the 2026-08-03 report is obsolete). Reading the deployed source's `docs/wiki/` first would have cut ~5 tool calls. Lesson recorded here: **the deployed rev's wiki is the first stop for any compositor config work.**
3. **The fmt-gate failures were initially assumed to be mine.** I re-ran the formatter twice before extracting the actual prettier error and checking file ownership. First move should have been `git log -1` on the failing file.
4. **The toplevel build ran too late.** Discovering the two foreign breakers at the END of the session meant the user hears about them only now. A toplevel build attempt (or eval + targeted builds) early would have surfaced them in the first minutes. Counter-consideration: a full toplevel build is expensive; a middle path is running it in background from the start.
5. **The `[TEST-RED]` inverse has a known blind spot I only half-documented:** it proves the anchored form is not VACUOUS (matches nothing → red → meta-pass), and the green endpoint proves it matches real lines. But the _bare-form phantom-green trap itself_ (bare pattern matching the HELP comment while the real value is flipped) is NOT demonstrated in the VM — a green bare-form endpoint would fail the meta-assertion, so the test cannot both pass and display the trap. Closing this needs a second mock body with flipped values (listed in §f).
6. **The catch-all blur rule was an autonomous design decision** (blur behind EVERY transparent window, including the 0.95 tiled opacity, rather than terminals-only). Reversible and xray makes it cheap, but it's a look decision made without the user — flagged in the questions below.
7. **Timeout wrappers degrade silently.** If `journalctl` times out, the collector emits a partial/0 count with no scrape-error gauge (the freshness composite catches collector DEATH, not silent wrong values). The repo's fail-closed doctrine (`*_scrape_errors` gauges) says this collector should grow one.
8. **PSI ≥5% attribution threshold is a calibration guess.** It aligns with pressure-report.sh's "elevated" floor (which is the MEMORY threshold; io elevated there is 20%) and one measured storm series backs the attribution story — but only one. Expect to recalibrate after a few real deploys.
9. **`niri-wrapped.nix` now hard-couples to niri-flake wiring.** `config.programs.niri.finalConfig` only exists where `inputs.niri.nixosModules.niri` is imported (today: only `systems/evo-x2.nix`). Flake check passes because only evo-x2 uses `home.nix` — but the coupling is undocumented in the file. One comment would prevent a future host-reuse foot-gun.
10. **Daemon attribution** — nothing actionable beyond the existing rule, but per the concurrent-session doctrine I should have opened the session by checking `git log`/`git status` (I did check, but only reached the commit-level attribution discovery late, while chasing the fmt failure).

**Process/systemic improvements:**
11. The fmt gate should fail loudly in CI (verify `nix-check.yml` actually runs and gates `nix fmt -- --ci`; if it does, why was Sep 16–19 red unnoticed?).
12. Harvest-bug class: `TODO_LIST.md` carried 3 empty `**Source:**` husk rows under desktop — the harvest step that produced them should be checked for the same artifact in OTHER domain sections.
13. `docs/todo/desktop.md` blur item, the CHANGELOG blur entry, and this report now describe the same mechanism in three places — the runbook-shaped detail (append + validate mechanism) arguably belongs in a future `docs/services/niri.md` instead of CHANGELOG prose.

---

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

**Immediate — unblock and land this session's work (1–6):**

1. Clear the two foreign toplevel breakers (owner sessions): `system-health-metrics` SC2034 (system-health.nix, `collectEnabledInactive` block) and `systemd-graph-webui-pnpm-deps` hash refresh (`pkgs/systemd-graph`) — OR get owner confirmation they're abandoned and fix them.
2. `nix run .#deploy` once green — carries: 4 anchored gatus checks, collector timeouts, audio.nix removal, blur KDL, pressure-aware fish check.
3. Post-deploy §10: confirm the metric auto-loans show no stale entries (§f26 of the 2026-09-17 closeout — no metrics changed this session, but verify the WARN-free pass).
4. Post-deploy: `nix run .#post-deploy-check` end-to-end — confirm the new fish labels render (pressure-attributed vs real-regression) and nothing else regressed.
5. Re-login once and visually verify blur (terminals at 0.88 opacity should show frosted wallpaper) — the filed `[blocked:deploy]` item.
6. Confirm the four anchored sibling checks stay GREEN on the healthy post-deploy box (stricter conditions — a false red would mean the collector emits something other than clean integer lines).

**Blur follow-ups (7–13):**
7. Tune `blur {}` params if the default look (passes 3 / offset 3) is too weak/strong — single top-level node in the appended KDL.
8. Hunt the DMS/quickshell layer namespace from the LIVE session (`niri msg layers` / quickshell sources) and wire layer-rule blur for spotlight/clipboard/notification surfaces.
9. Re-check terminal opacity: 0.88 was tuned for NO blur; with blur it may be darker than needed (0.90–0.92 might read better).
10. Visual-check blur × shadow interaction (`shadow.draw-behind-window = true` + blur could double-darken window edges).
11. Visual-check the focus-ring-over-transparency FAQ class (ring tint showing through semitransparent windows).
12. Perf spot-check: xray blur under load (frame counters / `niri msg` metrics) on Strix Halo — expected cheap, confirm.
13. Document the niri-flake coupling (`finalConfig` requires `inputs.niri.nixosModules.niri`) as a comment in niri-wrapped.nix.

**Docs/bookkeeping debt from this session (14–17):**
14. Update `ROADMAP.md` — resolve the now-stale "Niri blur" line (HM-module-absence rationale superseded).
15. Add a FEATURES.md row for niri blur.
16. Consider `docs/services/niri.md` runbook: monitoring chain, blur mechanism, timeout doctrine, the freshness contract (currently spread across AGENTS + CHANGELOG + this report).
17. Sweep OTHER `TODO_LIST.md` domain sections for the empty `**Source:**` husk pattern (desktop had 3; check for the harvest bug elsewhere).

**Monitoring hardening directly continuing this session (18–24):**
18. Add `niri_health_scrape_errors` gauge to the collector (timeout-degraded counts currently degrade silently; fail-closed doctrine).
19. Extend `gatus-pattern-lint` to reject bare `pat(*<metric> <digit>*)` value forms (the monitoring.md item) — AFTER or WITH the fleet sweep.
20. Fleet sweep: anchor the ~20 remaining bare VALUE-0 pats (system-health ×~10, mail-relay ×2, attic, bank-sync, signoz, gatus-config ×~5) — one mechanical PR, big phantom-green-class closure.
21. Mutation-test upgrade for `test-gatus-patterns.nix`: second mock body (flipped values `/metrics-bad` route) so a bare-form endpoint can be demonstrated green-on-bad (the trap itself) and the anchored form red-on-bad — closes the §e.5 blind spot.
22. Extend the trap HELP text to all four niri metrics (only desktop_died currently carries the contiguous `niri_desktop_died 1` trap string).
23. Timeout-wrap the collector's `loginctl list-sessions/show-session` loop (outside §f25's journalctl scope, same stall class, cheap).
24. Add fish-startup-time + PSI to a textfile metric for trend visibility (old 2026-08-03 idea, still open, now has a calibrated threshold to alert on).

**Calibration/verification (25–28):**
25. Recalibrate the fish PSI ≥5% attribution threshold after a few real deploys (log the labels across one storm).
26. Live-verify the 2026-09-16/17 niri gatus fix end-to-end (blocked:user — bounce replay or real bounce; `system_niri_metrics_fresh 1` in :9100/metrics).
27. Real SDDM login to close the 2026-08-24 report's last open item (pairs with 26 in one sitting).
28. Post-deploy smart-audio sanity: with restore-profile back at default, verify a DP-1↔DP-2 focus switch still flips profiles (user hands; pairs with item 32).

**The domain's standing blocked/decision items (29–34) — unchanged, listed for one consolidated pass:**
29. `[blocked:user]` wf-recorder runtime verification on niri.
30. `[blocked:user]` Smart-audio audible output + reverse direction incl. DP-2 cross-output (never tested).
31. `[decision]` btop privileges + terminal-restore policy (sudoers NOPASSWD vs unprivileged btop; ONE ghostty vs ZERO on login).
32. `[blocked:user]` Post-storm niri-session-manager live confirmation (one restore pass, no ghostty pile).
33. `[decision]` Signal Desktop backlog (green preset vs SQLCipher script; docs/services/signal.md; verify-or-retract sync claim).
34. Bundle 26/27/29/30/32 into a single ordered user-verification runbook (one sitting, every item needs owner hands anyway).

**Adjacent hygiene noticed during the session (35–43):**
35. Verify CI actually gates `nix fmt -- --ci` (the gate was red Sep 16–19 with no signal — see §e.11).
36. Attribution hygiene note: my work landed inside daemon commit `12f814d9` mixed with foreign files — no action possible post-hoc; re-confirm the pathspec-commit rule for the NEXT explicit commit.
37. `CHANGELOG.md` at report time is uncommitted — the daemon will sweep it; check `git show --stat` afterward that it didn't batch a foreign half-file into the same commit.
38. Re-verify the stray-div sweep: I fixed the 2 HTMLs prettier named and confirmed tree-green — a one-shot tag-balance pass over ALL `docs/**.html` would prove no near-miss siblings remain (prettier only reports the FIRST syntax error per run, so there could be more hiding behind the two fixed).
39. The collector's 30s cadence + 2×`timeout 10` worst case = up to ~20s of journalctl per tick under pathological conditions — acceptable, but if a third journal query ever lands, revisit the budget arithmetic.
40. `tests/test-gatus-patterns.nix` boots a full VM inside `nix flake check` — monitoring.md already carries "run heavy-job-wrapped once to verify field assumptions"; also consider whether the check belongs in the fast pre-commit path at all.
41. AGENTS.md niri bullet is now very long — candidate for splitting into sub-bullets (docs hygiene only).
42. gatus "Niri Compositor" freshness conditions are `optionals`-gated on `system-health.enable` — confirm intent (a host without system-health loses the freshness contract silently; today only evo-x2 matters).
43. The 3 husk-row harvest bug (17) plus the queue/library drift rule suggests a small `check-doc-links.sh`-style lint: every TODO_LIST one-liner must have non-empty text and a matching library row.

**Larger arcs this session touched but did not drive (44–50):**
44. `blur`/`background-effect` support upstream in niri-flake — when it lands, retire the KDL-append derivation and move to typed settings (drop-in; watch niri-flake releases).
45. The niri 26.04 `ext-background-effect` protocol — ghostty doesn't request blur; if it ever implements it, the window-rule becomes redundant (harmless to keep).
46. Non-xray blur (experimental upstream: real behind-window blur, currently breaks during open/close animations) — revisit only if xray's see-through-to-wallpaper look disappoints.
47. Parallel-session toplevel-breakage handoff protocol — consider a tiny convention: sessions mid-refactor drop a one-line WIP marker file or commit message tag so the next deploy-triaging session knows whose breakage it is (today it took derivation-level archaeology).
48. `systemd-graph` pnpm-deps drift is the same class as prior FOD-hash drift — if it recurs, the owner should check whether the upstream lockfile moved (same dance as go vendorHash).
49. The monitoring.md "extend gatus-pattern-lint" item and this session's four anchors are staged halves of one arc — sequence them (lint last, after 20) to avoid a red-lint limbo.
50. Keep the pending reboot (owed for the flm corpse) in mind: the blur + audio + gatus changes ride the NEXT deploy, and a reboot after that deploy would clear the :52626 pin in the same window.

---

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

**Q1 — Deploy authority vs the two foreign breakers:** `system-health-metrics` (SC2034) and `systemd-graph-webui` (pnpm hash) are mid-flight work from parallel sessions whose completion state is invisible to me. Do you want me to (a) wait for those sessions to finish, (b) treat them as abandoned and fix both myself, then deploy this session's batch — or (c) deploy with `DEPLOY_FORCE_PRESSURE`-style override once only eval passes (not recommended, the unit genuinely fails shellcheck)?

**Q2 — Blur look policy:** I shipped a CATCH-ALL rule (blur behind every transparent window, incl. the 0.95-opacity tiled ones) with niri's default params, xray mode. Is that the intended first look — or do you want terminals-only blur, and should I proactively dig the DMS/quickshell layer namespace out of the running session to blur spotlight/clipboard/notification modals too?

**Q3 — Consolidated owner-verification sitting:** items 26/27/29/30/32 (SDDM login bounce, real login, wf-recorder, smart-audio tones incl. DP-2 reverse, post-storm session confirm) all need your hands. Want me to prepare a single ordered runbook (one sitting, ~20 minutes, exact commands + expected outputs per step) so they close together instead of dribbling across sessions?

---

_Point-in-time snapshot 2026-09-19 12:02 CEST. Scope: this session's desktop-domain sweep only — no unrelated research performed, per instructions. Section (f) items 1–24 + 34 are HARVEST candidates for TODO_LIST/library routing; the rest are ROADMAP fuel._
