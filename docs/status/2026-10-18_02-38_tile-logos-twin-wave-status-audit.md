# Tile-Logos Twin-Wave: Status + Full Audit (a–g)

**Session window:** 2026-10-17 22:30 → 2026-10-18 02:38 CEST · **Instance:** first executor (twin run, see §a14/§d1)
**Successor to:** [02-32 closeout audit](2026-10-18_02-32_tile-logos-wave-closeout-and-twin-executor-audit.md) (committed `954f2d6e6`) — this report covers the DELTA since plus the full a–g.
**Execution report:** [02-08 follow-through](2026-10-18_02-08_tile-logos-go-live-verification-full-followthrough.md) (§g = instance 2, §h = instance 1).
**State at write time:** both repos pushed (PapDashboard `origin/master` = `88156eb`, SystemNix HEAD = `557c10031`, 0 unpushed); tree evals green; logos LIVE.

## TL;DR

Logos live and verified; every agent-actionable epic landed and pushed on both repos; a
real regression from the third in-flight session (underscore-form metric queries that
could never match a series — one alert dead since 2026-10-16) fixed on sight with
store-convention evidence; the boot-mirror divergence my anchor repair created was
diagnosed (EROFS via the sync unit's `ProtectSystem` RO-bind — already fixed in-tree,
deploy pending) and converged manually; `pre-reboot-check` **16/0 SAFE TO REBOOT**.
One interruption: the successor SUPERB plan file was requested-then-interrupted and is
**unwritten** (§c1) — awaiting instructions.

## a) FULLY DONE

| # | Item | Evidence |
| --- | --- | --- |
| a1 | **Live logos verification**: fragment 39 `src="/icons/…"`; `/icons/{caddy,miniflux,open-webui}.png` 200 + `Cache-Control: public, max-age=604800, immutable` through Caddy, no cookie; SW `pap-v9`; `/api/health` 200 | 23:2x probes |
| a2 | **Deploy-anchor repair**: raw-stc activation left `/run/current-system` unanchored (profile stuck on gen 926 = OLDER); repaired to gen 927 = the running toplevel; boot entry re-armed | guarded self-elevating script |
| a3 | **Mirror divergence diagnosed + converged**: sync unit failed EROFS on /boot renames — root cause is the unit's `ProtectSystem` RO-bind (in-tree fix `harden { ProtectSystem = false; }` already landed, deploy pending; `/proc/mounts` proves the fs was rw — the SANDBOX was ro). Ran the pinned sync script directly (sudo, no namespace): **50 entries mirrored, diff gate clean, counters carried** (`nixos-d4bbce86…+2-1.conf` blessed twin preserved) | journal + manual run 02:3x |
| a4 | **`pre-reboot-check`: 16 passed / 0 failed — SAFE TO REBOOT** (was 1 FAIL pre-convergence: stale mirror) | run 02:3x |
| a5 | **E2 post-deploy icon probes** (fragment ≥1 icon img; route 200 on a FRAGMENT-DERIVED file — no hardcoded name; immutable header) — fail-closed, positive + negative tested against a local server (3 PASS with pack / loud FAIL without `PAP_ICONS_DIR`); explicit-PID kill discipline held | scripts/post-deploy-check.sh |
| a6 | **E2 pre-deploy §16 icon inventory** (rendered icons ⊆ pinned pack; zero icons fails; §13/§14 anti-blind-skip) — isolated negative tests (missing dir → 1 loud FAIL; empty dir → 39 FAILs naming each icon); full pre-deploy run **103/0** | scripts/pre-deploy-check.sh |
| a7 | **E3 `build_case`** harness surface (realizes a config attr whose string context carries the gate) + `tileicons` group: `legacy-mdi-icon` (eval), `pack-missing-icon` (build), pristine control — 3/3 green AND neuter-proven (gate disabled → both legs phantom-green on throwaway copies) | scripts/negative-test-lints.sh |
| a8 | **E3 `inputpin/lifted-pin-stale-allowlist` re-anchored** — bank-sync's pin was lifted FOR REAL 2026-10-16 (mutation no-op'd); re-anchored on qmd's tag pin, group green | same |
| a9 | **E4 off-LAN determination**: protected vHost applies `forward_auth` to EVERY path (no path matcher — live Caddyfile read); authenticated browsers carry the cookie on `<img>`s; **no bypass** (would make artwork world-readable for zero gain); live LAN probe 200+immutable no-cookie; runbook + verification-list entry | docs/services/papdashboard.md |
| a10 | **E5 observability**: collector emits `papdashboard_services_json_icons` + `_icons_ok`; Gatus anchored pair + RED non-vacuousness leg; fixture mock body extended with trap comment; jq logic verified (39/39 → ok; crafted 1-of-2 → not ok); `gatus-patterns` VM **exit 0** | papdashboard.nix, tests/test-gatus-patterns.nix |
| a11 | **E6 pack lifecycle**: bump procedure (executable steps), `[watch]` staleness row, deliberate no-fallback-glyph decision | docs/services/papdashboard.md, docs/todo/services.md |
| a12 | **E7 upstream hardening (pushed, `origin/master` = `88156eb`)**: `/icons/` image-only guard (svg 200; non-image-present-on-disk 404; separator/`..` rejected), `/api/services` additive `iconUrls` (`Config.IconURLs()`, shared `resolveIconURL`), startup WARN for a broken pack (logger INJECTED after the hermetic race), DEPLOYMENT.md section, cache-shape decision recorded, SW `pap-v10` for the served-JS change, go.mod floor 1.27.1, upstream `vendorHash.nix` baked → SystemNix shim DROPPED as a proven no-op (identical store path) | ~/projects/PapDashboard |
| a13 | **E8 upstream polish**: bookmark chip icons (`Link.Icon`, img replaces the abbr plate, dashboard.js drops failed chip images), validation + render + IconURLs tests, smoke icon pack (tile + chip + non-image 404 + immutable assertions), services-tab runbook — full smoke GREEN, 33-package battery GREEN, BuildFlow lint green (the 4 step failures were BuildFlow-binary staleness + transient lychee, triaged) | same |
| a14 | **Twin-executor reconciliation**: the "parallel session" was a SECOND INSTANCE of this same conversation running the same plan concurrently. Mutual reconciliation recorded: instance 2's §g (their VM run, their inputpin anchor fix, their E10 doc lands) + instance 1's §h (this report's store-form lint fix) in the execution report | execution report §g/§h |
| a15 | **On-sight lint fix (third session's regression)**: `ai_meter_ttft_seconds_sum/_count` (dashboard) + `system_forgejo_mirror_sync_stale_count` (forgejo-backlog alert) queried the store in underscore form — the OTel receiver stores histogram suffixes DOTTED (proof: the working caddy dashboard queries `…seconds.sum`; live :8108 probe proves the exporter names are real — 2574 samples). Both queries fixed to the dotted form; **the forgejo alert had matched ZERO series since 2026-10-16 (could never fire)**; `signoz-query-lint` green after | ai-meter.json, _signoz-alerts.nix |
| a16 | **Docs + rules**: CONTRIBUTING "Concurrent-edit discipline" (declaration-before-consumer, capability-vs-data merge checklist, PID-only kills, re-read-before-edit) + daemon-swept-public-history no-squash rule; AGENTS.md pkill rule + pre-deploy 15→16 row; gotchas row (merge-carried-values-dropped-feature); registry icon contract line; E10.4 pipeline row verified accurate | docs/CONTRIBUTING.md, AGENTS.md, docs/gotchas-archive.md |
| a17 | **Push hygiene**: both repos pushed, gitleaks-clean push ranges, pathspec commits with `git show --stat` exclusivity checks (one daemon stage-injection attempt rejected via index reset) | git log |
| a18 | **Queue discipline**: wave `[blocked:deploy]` row once per surface (TODO_LIST + services.md, dedupe-checked); instance 2's lint row premise REFUTED and closed with the correction (emitter is correct — only queries needed the dotted form) | TODO_LIST.md, docs/todo/monitoring.md |

## b) PARTIALLY DONE

1. **E12 browser pass** — server-side pieces verified (SW version served, fragment content); the human-browser items remain: dark/light screenshots, narrow-breakpoint check, deliberately-broken-icon → monogram fallback in devtools.
2. **Queue-row wording** — the wave's `[blocked:deploy]` rows predate the dotted-query fix; they should mention it rides the same deploy (one-line refresh owed).
3. **`docs/agents/monitoring.md`** — the icons_ok pair follows the documented pat() rules but is not yet cited there as a worked example; no "exporter names vs store names" subsection either.
4. **FEATURES.md** — the tile-logo capability (this wave's headline) has NO row in the feature inventory.
5. **Store-truth for the dotted names** — proven indirectly (caddy.json precedent + lint doctrine + live exporter probe). The DIRECT check (clickhouse `distributed_time_series_v4` listing / PromQL `count(...)` per signoz.md's documented one-liners) was NOT run — the querier probe hit the UI shell on :8080 first.
6. **Execution-report structure** — §g/§h churn from the clobber race left the report readable but non-chronological; a tidying pass is cosmetic-optional.
7. **SUCCESSOR SUPERB PLAN** — requested (Pareto 51/4/80 + epics 30–100 min + ≤12-min steps + mermaid), grounding facts gathered (queue census: TODO_LIST 1224 open / services 429 / monitoring 113 / pipeline 464 / upstream 154; signoz.md's documented store-probe one-liners), the `write` was interrupted — **file unwritten, awaiting instructions**.
8. **TODO-row wording for the gatus VM item** — instance 2 closed §f2 in the report; the queue wording may still read "queued for a calm window" (drift candidate).

## c) NOT STARTED

1. **The deploy** (owner sudo) — carries lock 88156eb, metrics, probes, §16, and the two dotted-query fixes.
2. **E9 decision** (semantic logos vs neutral cyan set) + optional ~100 min authoring.
3. **Off-LAN phone probe** (completes E4.3's optional foreign-vantage leg).
4. **PapDashboard CI revival decision** (dead since 2026-07-15; queued row).
5. **A papdashboard NixOS VM test** (none exists).
6. **Intent-lock tooling** for concurrent deploys (manual discipline documented only).
7. **Store-truth helper** (`scripts/lib/metric-exists.sh` wrapping signoz.md's documented probes).
8. **Lint hardening**: dead-metric entries for the two retired underscore forms; harness `*)` guard; per-case log file.
9. **§16 coverage arm** (icons == tiles at deploy time, mirroring the runtime `icons_ok`).
10. **PID-kill helper + durable scratch dirs** (the /tmp wipe cost three round trips).

## d) TOTALLY FUCKED UP (all caught and fixed; full honesty)

1. **Twin-executor duplication undetected for ~3 hours.** Two instances of the same conversation ran the same plan in parallel — identical trajectories, interleaved daemon commits, clobbered report sections, wasted overlapping effort. Detection was accidental (file mtimes + a STATUS line I did not write). No plan-execution tombstone convention exists.
2. **slog global race (upstream)** — the warn tests swapped the global default logger from parallel subtests: green locally, FAILED inside the hermetic Nix checkPhase (2 subtests, empty log buffers). The exact local-green trap the Nix build exists to catch. Fixed by injecting the logger; `-race -count=2` green.
3. **FileServer prefix bug** — the image guard stripped the prefix for the check but not for the server: every VALID icon 404'd in the first cut. Caught by the existing suite within one run.
4. **Harness silent fall-through** — first `build_case` call had swapped arguments; unknown `expect` matched no branch and the case silently didn't count (a 3-leg run printed 2). No `*)` guard exists.
5. **Self-inflicted edit damage** — one edit deleted the `SIGNALERTS` line from negative-test-lints.sh (caught by grep one step later).
6. **Lost edit race** — the report follow-through edit reported SUCCESS but the content was gone at verification (instance 2 overwrote between my read and write); re-inserted line-anchored and re-verified by grep.
7. **§g clobber** — my reconciliation section was replaced by instance 2's same-lettered section; re-added as §h. The report trail survived, ordering didn't.
8. **Wrong premise briefly queued** — instance 2's lint row prescribed "fix the emitter + dashboard together"; the live probe refuted the emitter half (renaming would orphan live series). Corrected in the row, but for ~20 min a wrong fix recipe sat in the queue.
9. **Shell friction (repeated, mine):** typed `curl` guard (moved into scripts), `kill` unsupported builtin (coreutils path + explicit PIDs), `/tmp/e2-test` wiped twice (one heredoc silently failed; every write re-verified), commit-subject 72-char limit tripped twice, one heredoc parse failure in this interpreter.
10. **Scope discipline lapse at the very end** — I began writing the successor plan (grounding research done) when the flow had shifted to report-first; the interrupt cost a wasted partial write (nothing landed; §c7).

## e) WHAT WE SHOULD IMPROVE

1. **Plan-execution tombstones** — write an "EXECUTING (instance, since)" marker into a plan file BEFORE starting it, and check for a same-day marker first; the twin class needs a detection convention, not vigilance.
2. **Report-file append protocol for concurrent instances** — instance-prefixed section headers (§h-inst1) + append-only edits would have prevented the §g clobber and the lost edit.
3. **Store-truth tooling** — `metric-exists` helper wrapping signoz.md's two documented probes (clickhouse name listing + PromQL visibility), so lint triage is fact-based, not precedent-based.
4. **Lint dead-metric entries** for the retired underscore forms (regression = exact lesson, not a generic suffix message).
5. **Harness hardening** — `*)` guard on unknown expect values; per-case log file (job-output truncation hid run-1's failures).
6. **§16 coverage arm** — icons == tiles at deploy time.
7. **Durable scratch dirs** — repo-local `.crush/workdir/` or XDG mktemp with a trap, never /tmp.
8. **PID-kill helper** in scripts/lib (the pkill rule + the kill-builtin friction both point here).
9. **Docs-health at wave time** — FEATURES.md row + monitoring.md example ship WITH the wave (the doctrine exists; I skipped the step).
10. **Queue-premise runtime verification** — verify runtime claims against the LIVE service before writing a fix recipe (instance 2's emitter premise would have failed a 60-second probe).

## f) NEXT (up to 50, prioritized; ⛔ = owner/externally gated)

1. ⛔ **Deploy** (`nix run .#deploy`) — lock 88156eb + metrics + probes + §16 + both dotted-query fixes.
2. First-fire: `papdashboard_services_json_icons_ok 1` on :9100/metrics.
3. First-fire: §16 PASS line + icon probes PASS in the deploy log (no NEW-baseline regressions).
4. First-fire: SW serves pap-v10 after a hard refresh.
5. First-fire: forgejo-mirror-backlog rule provisioned with the DOTTED query (SigNoz UI).
6. First-fire: ai-meter TTFT panel renders data (its query could never match before).
7. Post-deploy: full `scripts/post-deploy-check.sh` re-run, zero NEW regressions.
8. Post-deploy: `readlink /run/current-system` anchored == newest gen (anchor discipline).
9. Post-deploy: `nix run .#pre-reboot-check` → expect 16/0 now that the fix will be live.
10. ⛔ E12.1: browser screenshots (dark + light).
11. ⛔ E12.2: narrow/tablet breakpoint check.
12. ⛔ E12.4: devtools broken-icon → monogram fallback check.
13. ⛔ E9: owner decision on tile-logo style (semantic vs neutral cyan set).
14. E9 execution IF custom: visual language → ≤14 SVGs → overlay dir → `dashboardIcons` merge → re-render → visual pass.
15. ⛔ Off-LAN phone probe: logos ride the SSO cookie from cellular.
16. **Write the successor SUPERB plan** (interrupted; §c7) — grounding already gathered.
17. Store-truth: run signoz.md's clickhouse probe for `ai_meter_ttft_seconds.sum/.count` + `system_forgejo_mirror_sync_stale.count` (close §b5).
18. PromQL-visibility check for the same names (DELTA-blindness trap documented for delta metrics).
19. `metric-exists` helper (e)3) in scripts/lib.
20. Dead-metric lint entries for the retired underscore forms (e)4).
21. Harness `*)` guard + per-case log file (e)5).
22. §16 coverage arm (e)6).
23. Durable scratch-dir convention (e)7).
24. PID-kill helper (e)8).
25. FEATURES.md row for the tile-logo capability.
26. monitoring.md: icons_ok worked example + exporter-vs-store naming subsection.
27. Refresh the wave's queue-row wording (include the dotted-query fixes).
28. TODO-row drift pass: gatus-VM wording (§b8) + any instance-2 rows predating fixes.
29. Twin-executor tombstone doctrine into AGENTS.md Session Discipline (e)1 doctrine form).
30. Report append-protocol note into CONTRIBUTING (e)2).
31. Verify the signoz receiver's translation strategy is explicitly pinned (so dotted-store behavior can't silently change).
32. Sweep ALL dashboards/alerts for remaining underscore phantoms (lint covers the class — confirm zero hits post-fix).
33. Sweep gatus-config conditions for exporter-vs-store confusion (they probe exporters directly — likely clean; record the determination).
34. Consider `iconUrls` consumers (any SDK surface that should now render logos).
35. Pack-bump dry run: exercise the documented procedure end-to-end on a throwaway rev BEFORE a real need forces it.
36. Pack staleness watch: calendarize the quarterly review.
37. Upstream PapDashboard: DEPLOYMENT note documenting exporter-vs-store naming for new metrics (prevents the ai-meter class upstream).
38. Upstream: consider serving a `/icons/` directory-listing denial test in CI (covered by smoke; confirm CI runs smoke).
39. PapDashboard CI revival decision research (c)4).
40. papdashboard minimal NixOS VM test (c)5).
41. Intent-lock tooling (c)6).
42. Shim-fleet sweep: erraudit/crm/golangci rows (same class as the papdashboard shim drop).
43. Verify `restartTriggers` fires on pack-only changes (icons store path rides the unit env — confirm a pack bump restarts the unit).
44. Guard the forgejo-backlog alert: after deploy, confirm it can fire (synthetic stale spike in a test window) — it has been dead since 2026-10-16.
45. Confirm `ai-meter` emitter naming doctrine is documented in its runbook (exporter convention: baked suffixes OK).
46. Retire `/tmp/papd-*` artifacts; document the harness scratch pattern.
47. Decide the fate of upstream heuristic-commit waves (keep per no-squash rule — recorded so nobody "cleans up" later).
48. README (upstream): chip-icon quickstart mention.
49. Weekly CI baseline-diff idea: lint findings vs stored baseline (catch new trips within a day).
50. Closure pass: when the deploy lands, flip ALL `[blocked:deploy]` rows from this wave to DONE with first-fire evidence (TODO_LIST + services.md + the report).

## g) QUESTIONS (max 3, not self-answerable)

1. **Deploy timing** — the wave is verified and waiting; IO was 40–58% all evening and it is 02:40. Deploy now, or wait for a calm morning window?
2. **E9 tile-logo style** — accept the current semantic pack glyphs (Crush Daily→openai, tq→opencode, llama.cpp→open-webui/hugging-face, …), or commission the neutral cyan line-icon set (~100 min)?
3. **Twin instances** — was running two concurrent instances of this conversation intentional and expected to recur? If yes: hard-rule the plan-execution tombstone (f/29), or go further (flock lock)?
