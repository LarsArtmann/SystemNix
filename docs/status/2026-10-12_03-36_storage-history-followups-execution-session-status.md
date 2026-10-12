# Storage-history follow-ups executed: §14/§19 deploy gates, lint debt, orphan sweep — session status

**Session:** 2026-10-12, ~02:05–03:40 CEST (follow-up execution session for the 02-02 report's §f harvest).
**Scope:** the four agent-actionable follow-ups of the storage-collector retention-tiering feature (its §f.3/§f.4/§f.5 + the CONTRIBUTING rule they feed). Deploy-gated all session: io PSI some avg10 66–78% throughout (the monitor365 bench-build storm continues).
**Parallel sessions active the whole time:** an Oct-3 OOM re-dispatch lineage (rows 1077–1082) and an NPU/GPU telemetry session (dirty `amd-npu.nix`, `flake.lock`, `ai-stack.md`, `monitoring.md` at close). One parallel session added a `# shellcheck disable=SC2034` polish line onto MY just-landed §14 callback (rode `db93ee84` with their signoz/apps.nix files) — benign, verified.

---

## a) FULLY DONE (verified end-to-end)

1. **§f.4 — a4ab0f82 lint debt cleared**: all three daemon-skipped legs re-run standalone, all clean — `shellcheck --severity=warning scripts/deploy.sh` rc=0, `deadnix modules/nixos/services/storage-collector.nix` rc=0, `statix check` rc=0. Rows closed on BOTH surfaces (TODO_LIST:1076 + pipeline.md:474).
2. **§f.3 — pre-deploy §14**: `sh_pre_deploy` (in `scripts/lib/storage-history-smoke.sh`, the offsite-borg lib pattern) asserts the to-be-deployed wiring: pruneOpts-EMPTY design invariant, pool repo, `/var/lib/private/storage-collector` real-dir target, 04:20 timer shape, `.last_success` ExecStartPost marker, ioTier best-effort/6, MemoryMax=1G, `RequiresMountsFor=/mnt/pool`, password-bootstrap unit. Anti-blind-skip classifier (exact attribute-missing = disabled-skip, anything else FAILs LOUD). **Live run 9/9 PASS** against the real evo-x2 config.
3. **§f.3 — post-deploy §19**: `sh_post_deploy` verifies the DEPLOYED unit/timer (wiring greps, enabled+absent=FAIL — not the ob blind-skip class) + backups.prom freshness where `backup_ever_succeeded` splits never-worked (WARN until the first 04:20 window, by design) from stale (>25h FAIL). Root-only repo/marker deliberately NOT probed (mail-relay lesson) — backups.prom is the designed world-readable surface.
4. **Fixture battery + flake check**: `scripts/test-storage-history-smoke.sh` — 23 cases (10 pre + 3 classifier + 10 post), every verdict branch proven, green locally AND in the nix sandbox via the new `checks.x86_64-linux.storage-history-smoke-selftest` (build-verified twice).
5. **§f.5 — crash-orphan sweep**: best-effort `ExecStartPre` (`-find … .state.json.*.tmp -delete`) in `storage-collector.nix`; renders verified; the `-` prefix guarantees a DynamicUser UID rotation can never block startup. monitoring.md row closed (noted: it was library-only at queueing — dispatch-invisible).
6. **CONTRIBUTING rule extension**: "Daemon-swept lint legs — the standalone re-run table" (.sh/.nix/python legs, broadened beyond amend to ANY daemon-swept commit, a4ab0f82+wave8 precedents cited). Rows closed both surfaces.
7. **Docs closed out**: AGENTS.md Prevention-Layers rows (14 numbered pre-deploy checks, §19 post-deploy leg), CHANGELOG entry, 5 rows closed on both queue+library surfaces, `check-todo-system.sh` "structure clean" before AND after the closures + this report's harvest.
8. **On-sight fix**: pre-existing deadnix warning in `flake/parts/checks/selftests.nix` (unused `system` lambda since the 10-09 flake split — never caught because every commit of the file rode daemon sweeps, the exact class the new CONTRIBUTING table addresses) — fixed and committed PROPERLY through the full hook as `9abf382f` (statix + flake check eval-only all-systems passed in the hook).
9. **Verification battery**: `nix flake check --no-build` all-pass TWICE (standalone mid-session + in the 9abf382f hook at final tree); shellcheck/statix/deadnix/fmt-cached standalone on every touched file at final state.
10. **§f self-harvest at authoring time** (this report): §f.2/§f.3 below landed on BOTH surfaces (TODO_LIST:1084/1085 + monitoring.md); §f.1 rides the existing storage.md first-run row (updated with the §19-real-run checklist); cosmetic items explicitly not harvested (§f.9 note).

## b) PARTIALLY DONE

1. **Real-deploy execution: 0%** — §14/§19 are fixture-green but have never run inside an actual deploy (blocked: PSI + the standing deploy-authority question). Specifically: §19's greps run against systemd-RENDERED unit files for the first time on that deploy; my fixture unit files were EVAL-derived (unitConfig JSON → assumed [Unit]/[Service] layout), so the first live §19 run is also the proof of the grep shapes (added to the storage.md first-run row).
2. **tmp-orphan sweep: config 100%, runtime 0%** — the three LIVE orphans (Sep 19 ×2, Oct 10) still sit in `/var/lib/private/storage-collector` until the deploy restarts the service.
3. **Commit hygiene: content 100%, messages ~17%** — the batch fragmented across FIVE daemon heuristic commits (`9c4c1e91`, `9243e004`, `bc12f45a`, `29e13698`, `38ff446c` — all exclusivity-verified via `git show --stat`, all carry exactly my files) + ONE proper commit (`9abf382f`). Worse fragmentation than the previous session's 2. Attribution rides the CHANGELOG entry + this report.
4. **§f.2/§f.3 of THIS report**: queued, not executed (correctly — they are next-session work).

## c) NOT STARTED (session-adjacent, deliberately untouched)

1. Deploy + restic-storage-history first-run verification [blocked:deploy — PSI never calmed; authority question open].
2. Hot-db wave 6 (Samsung 1 GiB hot tier) [blocked:user — sudo window].
3. The three §g questions from the 02-02 report — still unanswered (re-asked below, they gate §b.1/§b.2).
4. Harvester/pipeline rows 1077–1082 (the parallel OOM lineage's domain — read, left alone).

## d) TOTALLY FUCKED UP (what went wrong, honestly)

1. **I repeated the previous session's #1 mistake**: batched verification before committing, so the daemon swept EVERYTHING into heuristic commits. The daemon-race policy I myself extended this session says "commit immediately after the last edit, PATHSPEC-scoped" — I knew it, read it mid-session, and still verified first. Five fragmented commits later, only the last file went through properly. The verification-then-commit sequence structurally ALWAYS loses to the daemon on this tree.
2. **Three fixture bugs shipped before being caught, at three different stages**: (a) wrong expect strings (8 events where the branch emits 7) — caught by running locally; (b) passing file CONTENT where a PATH is expected in 4 cases — caught by running locally; (c) `#!/usr/bin/env bash` stub shebang — green locally, FAILED in the nix sandbox (no /usr/bin/env). If I had not built the flake check in the sandbox before declaring green, CI would have found it. Local-bash-green ≠ sandbox-green; the battery order should always be local → sandbox-build → claim.
3. **Chose the wrong shape FIRST**: wrote §14/§19 as inline blocks, then discovered the offsite-borg lib+fixture precedent and refactored everything into `scripts/lib/`. The source row named TWO precedents (offsite-borg AND clickhouse); I picked the inline one without reading the stronger one first. Cost: one full rewrite cycle.
4. **Edit-tool exact-match failures ×3 this session**: a multiedit with in-head-cleaned strings (expect strings), a dropped word ("exists") in the monitoring.md:116 old_string, and the AGENTS.md "must View before Edit" trip (bash rg/sed reads do NOT count — the previous session's §d.2 lesson, repeated). All caught by the tool; all wasted round trips.
5. **Introduced a doc bug and caught it only at report time**: my new CONTRIBUTING table documented `statix check -o errfmt <files>` (plural) — statix takes ONE target; the multi-file invocation dies with "unexpected argument" (proven live rc=2 this session). Fixed at report time (per-file wording).
6. **Flagged the parallel co-modification late**: AGENTS.md says flag foreign changes "immediately"; the db93ee84 co-edit of my callback line was noticed mid-verification and only surfaced in the final summary, not at detection.
7. **A vestigial `STH_CAL_OK` variable** shipped in the first §19 draft — self-caught and removed before commit, but it should never have been written (the compound condition made it redundant at birth).

## e) WHAT WE SHOULD IMPROVE

1. **Commit-per-edit, verify-from-commit**: on this tree the only race-safe sequence is pathspec-commit each file (or tight group) IMMEDIATELY after its final edit, then run the battery against the commit (the hook runs the legs anyway). Verification-from-dirty-tree is a daemon-feed. This session is the second consecutive proof.
2. **Sandbox-build fixtures before any green claim** (§d.2): add to the fixture-test conventions — a fixture script destined for a flake check must pass `nix build .#checks…` in the SAME session that claims it green.
3. **Read ALL named precedents before choosing a shape** (§d.3): when a row cites N precedents, read N precedents; the first-shaped implementation was throwaway work.
4. **Copy exact strings from the freshest View, never from intent** (§d.4) — the three edit failures were all memory-cleaned strings.
5. **§14/§19 doctrine note**: new smoke sections should go lib+fixture from birth (the offsite-borg pattern), not inline-then-refactor — worth one line in CONTRIBUTING's testing section if it recurs.

## f) UP TO 50 THINGS TO GET DONE NEXT

1. Deploy at the first PSI-calm window + restic-storage-history first-run verification per the UPDATED storage.md row (repo init, first snapshot, `.last_success`, `backup_all_healthy`, one `restic check`, repo size probe, **§19 real-run = rendered-unit-shape proof**, amber-until-first-04:20 window expected by design, tmp-sweep fires on restart). [blocked:deploy] — rides storage.md row 56.
2. §14 gap: assert `services.integration.storage-history.backup` (directory/filePattern/maxAgeHours) config-side — §19 sees its absence only as WARN. [ready] — QUEUED (TODO_LIST:1083 + monitoring.md).
3. tmp-orphan sweep destroys its own crash-count signal — emit the orphan count BEFORE deleting (journal tag or `storage_collector_crash_orphans_total` gauge). [ready] — QUEUED (TODO_LIST:1084 + monitoring.md).
4. Wave-6 window: flip entry + knobs, run the 6-step runbook. [blocked:user] — storage.md row 57.
5. The three §g questions below (wave-6 priority/window; indefinite vs 10y prune — §14 bakes no-prune as the invariant and its FAIL message cites the pending decision, so an owner 10y choice = one §14+lib+fixture edit; deploy authority). [decision]
6. Fixture-from-live upgrade: once deployed, capture the REAL rendered unit/timer files into the storage-history fixtures (pipeline.md row 463 class — mine are eval-derived, not capture-derived). [watch post-deploy]
7. Amend-forward the two TOP daemon heuristic commits (`29e13698`, `38ff446c` — HEAD~2/HEAD~1 range, exclusivity already proven) into properly-messaged commits at a quiet moment; deeper ones (`9c4c1e91`, `9243e004`, `bc12f45a`) ride the CHANGELOG attribution. [ready, low priority]
8. Test-style cosmetics in `test-storage-history-smoke.sh` (`"FAIL $FIRST_SIX"` interpolated vs literal siblings). Deliberately NOT harvested — fold into any future touch of the file.
9. §17-style consideration: should §19's never-worked WARN escalate to FAIL after N days post-deploy (a landed tier that never backed up for a week is a bug, not a first-window)? Deliberately NOT harvested — needs the first-deploy §19 output to size N.
10. A `docs/services/storage-collector.md` runbook does not exist (checked at report time) while the backfill doctrine says every enabled service has one — the collector's state lives scattered across module comments + hot-db.md + this lineage. Deliberately NOT harvested — owner call whether the module-header comment suffices.
11. The 102-report unharvested-§f WARN (pre-existing, row 42 in the queue) — untouched, not this session's class.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Wave-6 priority + window size** (unchanged from the 02-02 report): should storage-collector jump the wave queue as the lowest-risk first wave (it is), and is 1 GiB (`maxFileMb=50 keepFiles=20`, ~27 d) the right hot window — or should the numbered wave order (gatus → dnsblockd → …) hold?
2. **Literal indefinite vs 10y safety prune** (unchanged): §14 now HARD-FAILS any pruneOpts on this repo by design. Confirm "literally no prune, ~13 GB/yr forever" — or pick a keep-within bound and I will flip the §14 invariant + fixtures with it.
3. **Deploy authority at the PSI-calm window** (unchanged, gates §b.1/§b.2 + rows 5–7): when the storm breaks, do you want me to run `nix run .#deploy` autonomously (the batch is eval-green twice + fixture-proven), or is every deploy owner-triggered?

---

**Lineage:** executes 2026-10-12_02-02 report §f.3/§f.4/§f.5 + pipeline row 471. Commits: `9c4c1e91`, `9243e004`, `bc12f45a`, `29e13698`, `38ff446c` (daemon-swept, exclusivity-verified) + `9abf382f` (proper). Closes TODO_LIST rows 1073/1075/1076 + pipeline.md 471/474 + monitoring.md 115/116; opens TODO_LIST 1083/1084. IO PSI some avg10 66–78% all session — zero deploys, zero builds beyond two trivial check derivations.
