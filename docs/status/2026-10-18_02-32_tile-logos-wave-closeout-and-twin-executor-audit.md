# Tile-Logos Wave Closeout + Twin-Executor Audit

**Session:** 2026-10-17 22:30 → 2026-10-18 02:32 CEST · **Instance:** first executor of the twin run
**Predecessors:** [2026-10-18_02-08 execution report](2026-10-18_02-08_tile-logos-go-live-verification-full-followthrough.md) (§g = instance 2's addendum, §h = mine) · [plan](../planning/2026-10-17_09-27_SUPERB-tile-logos-go-live.md)
**Trigger:** owner directive: execute the WHOLE plan, then report what was forgotten / botched / next.

## TL;DR

The logos are **live** (39 through Caddy, verified 23:2x). Every agent-actionable epic
(E1–E8, E10, E13) is implemented, verified, and pushed on both repos. This session ALSO
discovered it was one of **two concurrent instances of the same conversation** executing
the same plan (the other instance's reconciliation note is §g of the execution report);
their work interleaved via the auto-commit daemon. One real regression from the THIRD
in-flight session (ai-meter underscore queries) was fixed on sight with store-form
evidence. Tree evals green; all gates green; both repos pushed and gitleaks-clean.

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| E1 live verify (39 logos, 200+immutable ×3 icons through Caddy no-cookie, SW pap-v9, health 200) | execution report §c |
| Deploy-anchor repair: raw-stc activation had left current-system unanchored (profile stuck on gen 926, older); repaired to gen 927 = running toplevel, boot re-armed | §c, guarded self-elevating script |
| E2 post-deploy icon probes (fragment ≥1 `src="/icons/`, route 200 on a fragment-derived file, immutable header) — fail-closed, positive+negative tested on a local server (3 PASS / loud FAIL without `PAP_ICONS_DIR`) | scripts/post-deploy-check.sh |
| E2 pre-deploy §16 icon inventory (rendered icons ⊆ pinned pack; zero-icons fails; anti-blind-skip §13/§14 discipline) — isolated-leg negative tests (missing dir → 1 FAIL; empty dir → 39 FAILs) + full pre-deploy run **103 passed / 0 failed** | scripts/pre-deploy-check.sh §16 |
| E3 `build_case` harness surface (realizes a config attr whose string context carries the gate) + `tileicons` group (eval form gate + build existence gate + pristine control) — green AND neuter-proven (assertion→`true` / `exit 1`→no-op go phantom-green on throwaway copies) | scripts/negative-test-lints.sh |
| E3 `inputpin/lifted-pin-stale-allowlist` anchor fixed (bank-sync pin was lifted FOR REAL 2026-10-16; re-anchored on qmd's tag pin, verified green) | same file |
| E4 off-LAN determination: `forward_auth` has NO path matcher on the protected vHost → everything is intercepted off-LAN; authenticated browsers ride the cookie on `<img>`s; **no bypass** (would make artwork world-readable). Live LAN probe: `/icons/caddy.png` 200+immutable, no cookie. Runbook written | docs/services/papdashboard.md |
| E5 collector metrics `papdashboard_services_json_icons` + `_icons_ok`; Gatus anchored pair + RED non-vacuousness leg + trap-comment mock body; jq logic verified (real config 39/39 → ok; crafted 1-of-2 → not ok) | modules/nixos/services/papdashboard.nix, tests/test-gatus-patterns.nix |
| `gatus-patterns` VM test **exit 0** (both on the icon-legs drv and re-run on the settled tree) | nix build runs 02:0x + 02:3x |
| E6 pack-bump runbook (executable steps), staleness `[watch]` row, deliberate no-fallback-glyph decision | docs/services/papdashboard.md, docs/todo/services.md |
| E7 upstream (pushed through `88156eb`): `/icons/` image-only guard (svg 200, non-image-present-on-disk 404, separator/`..` rejected), `/api/services` additive `iconUrls` (`Config.IconURLs()`, shared `resolveIconURL`), startup WARN for broken pack (logger injected), DEPLOYMENT.md section, cache-shape decision recorded, SW bump pap-v10 for the JS change | ~/projects/PapDashboard |
| E8 upstream: bookmark chip icons (Link.Icon, img replaces abbr plate, dashboard.js drops failed chip imgs), validation + render + IconURLs tests, smoke icon pack + assertions, services-tab runbook — full smoke GREEN, 33-package battery GREEN, BuildFlow lint green | same |
| Upstream hygiene: go.mod normalized to 1.27.1 floor; `vendorHash.nix` fixed to the real hash; SystemNix consumer shim DROPPED (proven no-op: identical store path without it) | upstream vendorHash.nix + papdashboard.nix |
| E10 rules: CONTRIBUTING "Concurrent-edit discipline" (declaration-before-consumer, capability-vs-data merge checklist, PID-only kills, re-read-before-edit) + daemon-swept-history no-squash rule; AGENTS.md pkill rule + pre-deploy 15→16 row; gotchas row for the merge-lost-feature pattern; pipeline.md negative-leg row closed accurately | docs/CONTRIBUTING.md, AGENTS.md, docs/gotchas-archive.md |
| **On-sight fix (third session's regression):** `signoz-query-lint` controls were RED — `ai_meter_ttft_seconds_sum/_count` + `system_forgejo_mirror_sync_stale_count` queried the store in underscore form while the OTel receiver stores suffixes DOTTED (proven: working caddy dashboard uses `.sum`; exporter-side names are real — live :8108 probe, 2574 samples). Fixed both queries to the dotted form; lint green. The forgejo backlog alert had matched ZERO series since 2026-10-16 (could never fire) | ai-meter.json, _signoz-alerts.nix |
| Verification sweep: `nix flake check --no-build` all-green; pre-deploy 103/0; tileicons 3/3; signoz lint green; both repos pushed with gitleaks-clean ranges | this session |
| Twin-executor reconciliation (§g + §h of the execution report) + instance 2's monitoring row closed with the evidence-based correction | execution report, docs/todo/monitoring.md |

## b) PARTIALLY DONE

1. **E12 (visual/browser pass)** — server-side SW version verified (pap-v9 live, pap-v10 queued); E12.5 cross-links done. NOT done (needs a human browser): dark/light screenshots (E12.1), narrow-breakpoint check (E12.2), deliberately-broken-icon monogram fallback in devtools (E12.4).
2. **TODO_LIST/services queue rows** — the `[blocked:deploy]` wave row exists once per surface (dedupe-checked), but the row text predates the lint fix; a wording refresh (the wave now also carries the two dotted-query fixes) is owed at next queue touch.
3. **`docs/agents/monitoring.md`** — the icons_ok pair follows the documented pat() rules but the doctrine section does not cite it as an example yet.
4. **FEATURES.md** — the tile-logo feature (the headline of this wave) has NO row in the feature inventory. Gap, trivial to add.
5. **Live-metric truth for the dotted fix** — the dotted-store form rests on the caddy.json precedent + the lint's 2026-08-27 lesson + the live exporter probe; I did NOT query the SigNoz store API directly to confirm `ai_meter_ttft_seconds.sum` resolves as a series (the API attempt hit the UI shell on :8080; querier port unknown to this session).
6. **Upstream `pap-v10`** — bumped and pushed; its ARRIVAL in browsers is only provable post-deploy.

## c) NOT STARTED

1. **The deploy itself** (owner sudo; carries lock 88156eb + metrics + probes + §16 + dotted-query fixes).
2. **E9 neutral-icon-set decision** (owner; `[decision]` row queued) + optional authoring (~100 min).
3. **PapDashboard CI revival** (dead since 2026-07-15; queued upstream row — repair vs retire decision pending).
4. **Intent-lock tooling** for concurrent deploys (manual discipline documented; helper script queued in pipeline.md).
5. **A papdashboard NixOS VM test** (none exists; recorded in the sweep — candidate epic).
6. **Off-LAN phone probe** (E4.3 optional external vantage — config-level answer is deterministic, live foreign probe would complete it).

## d) TOTALLY FUCKED UP (all caught; listed for honesty)

1. **Twin-executor duplication was not detected for ~3 hours.** Two instances of the same conversation executed the same plan in parallel (identical trajectory: both built build_case+tileicons, both hit the same three bugs, both appended to the same upstream files). Wasted a fraction of effort on overlapping epics and produced interleaved daemon commits whose attribution needed a reconciliation section. Detection was accidental (file mtimes + a STATUS line I did not write). There is no plan-execution tombstone/lock convention — only deploy-intent locking exists.
2. **FileServer prefix bug (upstream):** the image guard stripped the URL prefix for the check but not for the FileServer — every VALID icon 404'd. Caught by the existing test suite in one run; fixed with StripPrefix + explicit separator/`..` rejection.
3. **slog global race (upstream):** warn tests swapped the GLOBAL default logger from `t.Parallel` subtests — green locally, FAILED in the hermetic Nix checkPhase. Exactly the "trust a local run" trap the Nix build exists to catch. Fixed by injecting the logger; proven `-race -count=2`.
4. **Harness silent fall-through:** my first `build_case` invocation had swapped arguments; the unknown `expect` value matched NO case branch and the case silently didn't count (a 3-legged run printed 2). A `*)` guard in the harness would have made it loud.
5. **Self-inflicted edit damage:** one edit dropped the `SIGNALERTS` line from negative-test-lints.sh (caught by grep one step later).
6. **Shell friction (repeated):** `curl` guard (moved into harness scripts), `kill` unsupported builtin (coreutils path + explicit PIDs), `/tmp/e2-test` wiped twice mid-sequence (one heredoc failed silently; every "written" claim re-verified afterward), commit-subject 72-char limit tripped twice.
7. **Instance 2's monitoring row had a wrong premise** ("fix the emitter + dashboard together") — refuted by the live probe (the emitter is correct; only queries needed the fix). Closed with the correction, but the wrong premise sat in the queue for ~20 minutes and could have triggered an unnecessary exporter rename.
8. **My §g section got clobbered by instance 2's §g** in the shared report during the race — re-added as §h. The report is the single trail; ordering is now a)…g,h.

## e) WHAT WE SHOULD IMPROVE

1. **Plan-execution tombstones.** Before executing a plan file, scan `docs/status/` + `git log --since` for a same-day execution marker (or write one FIRST: "instance <id> executing plan X"). Cheapest fix for the twin class; a flock lock is the heavier version.
2. **Store-truth verification for metric names.** The dotted-fix rests on precedent; a tiny helper that queries the SigNoz querier API for a metric name ("does this series exist?") would turn lint triage from precedent-based to fact-based, and could catch MORE phantom alerts mechanically.
3. **The lint could grow a "dead metric" entry** for the two retired underscore forms (`…_seconds_sum`, `…_stale_count`) so a regression re-adding them fails with the exact lesson instead of the generic suffix message.
4. **Harness hardening:** `*)` guard on unknown expect values; log each case's line to a file so failures survive job-output truncation.
5. **§16 could assert coverage (icons == tiles)** at deploy time, mirroring the runtime `icons_ok` — currently pre-deploy checks existence only.
6. **Stop relying on /tmp for harnesses** (wiped twice): a `.crush/workdir/` or mktemp-under-XDG pattern with cleanup-on-exit would have saved three round trips.
7. **PID-kill helper** (`scripts/lib`): the kill-builtin friction + the pkill production-match rule justify a 5-line `pid_of_port`/`kill_pid` helper all harnesses share.
8. **FEATURES.md freshness:** the wave shipped without a feature row — the docs-health pass should sweep new capabilities into FEATURES as part of the wave, not after.
9. **Queue-row premise checks caught it late:** instance 2 queued a fix-premise that the live probe refuted 20 minutes later. The "spot-verify config claims at queueing time" doctrine should extend to "verify runtime claims against the live service before writing the fix recipe".

## f) NEXT (prioritized, ~50)

1. **Owner: deploy** (`nix run .#deploy`) — carries lock 88156eb + metrics + probes + §16 + dotted-query fixes.
2. Post-deploy first-fire: `papdashboard_services_json_icons_ok 1` on :9100/metrics.
3. Post-deploy: §16 PASS line + icon probes PASS in the deploy log.
4. Post-deploy: SW serves pap-v10; hard-refresh once so the SW swaps.
5. Post-deploy: `signoz-query-lint` + `negative-test-lints` nightly green in CI.
6. Post-deploy: verify the forgejo-mirror-backlog rule provisioned with the dotted query (SigNoz UI → the rule's query string).
7. SigNoz UI: ai-meter TTFT panel renders data (dotted query resolves).
8. E12.1 browser screenshots (dark/light) of the Services tab.
9. E12.2 narrow/tablet breakpoint check for the 2.4rem icon plate.
10. E12.4 devtools broken-icon check → monogram fallback (one intentional 404).
11. E9 owner decision: accept semantic logos vs commission the neutral cyan set.
12. E9.2–E9.6 IF custom: define visual language, author ≤14 SVGs, local overlay dir, merge into `dashboardIcons`, re-render, visual pass.
13. Off-LAN phone probe: load `dash.home.lan` from cellular, confirm logos ride the SSO cookie (completes E4.3).
14. Query the SigNoz querier API for `ai_meter_ttft_seconds.sum` existence (close §b5's indirect-proof gap).
15. Add the icons_ok pair to `docs/agents/monitoring.md`'s pat() doctrine section as a worked example.
16. Add a FEATURES.md row for the tile-logo capability.
17. Refresh the `[blocked:deploy]` queue row wording to include the dotted-query fixes (§b2).
18. Twin-executor tombstone: write the plan-execution-marker rule into AGENTS.md Session Discipline (e)1 made doctrine).
19. SigNoz querier helper script (`scripts/lib/metric-exists.sh`) — e)2 made tooling.
20. Lint dead-metric entries for the two retired underscore forms — e)3.
21. Harness `*)` guard + per-case log file — e)4.
22. §16 coverage arm (icons == tiles) — e)5.
23. Move harness scratch dirs off /tmp — e)6.
24. `pid_of_port`/`kill_pid` helper in scripts/lib — e)7.
25. FEATURES.md sweep: audit the last 4 waves for missing feature rows — e)8.
26. Extend the queue-premise doctrine: runtime claims verified against the live service at queueing time — e)9.
27. PapDashboard CI decision (repair runner vs retire + codify probe-before-lock) — queued upstream row.
28. VendorHash shim fleet: the erraudit/crm/golangci trio row (refresh upstream hashes, drop shims whose drop condition fired).
29. After upstream bakes any future got-hash: re-check the shim-drop conditions fleet-wide.
30. Consider a minimal papdashboard NixOS VM test (boot with pack dir, probe /icons/) — c)5.
31. Pack rev staleness quarterly review (watch row) — calendar it.
32. The lint's scanned-surface set: confirm it covers every dashboard/alerts surface that can carry queries (new dashboards auto-included?) — else extend the glob.
33. SigNoz dead-metric list refresh: verify the existing `metrics` entries are still the right set.
34. Consider `iconUrls` consumption: any SDK consumer that should start rendering logos (crush-daily? tq?).
35. E2 probe generalization: the fragment-derived-probe pattern could serve other surfaces (bookmarks chips etc.).
36. Upstream: consider `/icons/<rev>/<file>` route versioning IF a real stale-cache incident ever appears (decision recorded; revisit trigger only).
37. Upstream: bookmark icon docs live in services-schema — verify the README quickstart mentions chip icons too.
38. Owner: confirm the forgejo backlog alert's new target (20) still matches ops expectations now that it can actually fire.
39. Confirm the ai-meter dashboard panel's legend/thresholds still make sense with the fixed query (it was never rendering).
40. Sweep OTHER upstream exporters for exporter-vs-store naming documentation gaps (the ai-meter lesson generalizes: any new exporter needs a dotted-query note in its runbook).
41. Add the "exporter names vs store names" distinction to monitoring.md's metric-naming section.
42. Check whether the signoz receiver's translation strategy is pinned explicitly in the signoz config (so the dotted-store behavior can never silently change under the dashboards).
43. Consider a weekly CI job that diffs lint findings vs a stored baseline (catches new trips within a day instead of at sweep time).
44. Retire the `/tmp/papd-*` test artifacts and the 18991-port habit into the documented harness pattern.
45. Verify instance 2's other queued rows (their §f harvests) for premise drift the way the lint row drifted.
46. E2E regression: after deploy, re-run `scripts/post-deploy-check.sh` in FULL and confirm zero NEW-baseline regressions.
47. Check whether `restartTriggers` correctly restarts papdashboard when the icons subset store path changes on future pack bumps (it references `servicesConfig`; the icons path rides the unit env — confirm a pack-only change still restarts).
48. Docs: papdashboard.md "Deploy evidence" gains the hardening-wave line after the next deploy (replace "queued" wording).
49. Decide the fate of the two upstream heuristic-commit waves (both repos): keep as-is per the no-squash rule; nothing to do — recorded so nobody "cleans them up" later.
50. Closure pass: when the deploy lands, flip every remaining `[blocked:deploy]` row from this wave (TODO_LIST + services.md) to DONE with first-fire evidence.

## g) Questions for the owner (max 3)

1. **Deploy now?** The wave (lock 88156eb + metrics + probes + §16 + two dotted-query fixes) is verified and waiting; IO was 40–58% all evening and it is 02:30. Deploy into the calm, or wait for morning?
2. **E9 — tile-logo style:** accept the current semantic pack glyphs for internal/agentic tiles (Crush Daily→openai, tq→opencode, NSFW→frigate, llama.cpp→open-webui/hugging-face, …), or commission the neutral cyan line-icon set (~100 min authoring + overlay dir)?
3. **The twin-executor run:** was running two instances of this conversation intentional (and should I expect it again)? If yes, do you want the cheap plan-execution tombstone convention (write an EXECUTING marker into the plan file before starting; f)18) made a hard rule — or even an flock lock — so future waves don't duplicate epics?
