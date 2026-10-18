# Status: Browser-History Unblock + HaGeZi Nine-List Revert Re-pin + dns-update.sh Hardening

**Session window:** 2026-10-16 ~04:35–06:25 CEST · **Agent:** Crush (GLM-5.3-flash)
**Scope:** two deploy-blocking waves owned by this session — (1) the browser-history `StateShape` build failure, (2) the HaGeZi blocklist hash drift (dyndns + 9 lists) — plus the canonical-tooling hardening that fell out of wave 2.
**Tree at report time:** local HEAD `c3cdf7a5` (daemon, one other session's file) on top of my `4f2fdf14` (= origin/master, pushed outside this session — I do not push without ask). Working tree: only this report + the four harvested TODO surfaces.
**Deploy state at report time:** `/run/current-system` still = `jqhch2smw…` (the 20261014 generation). The build surface is GREEN (toplevel `nix build --keep-going` verified at `l7qfx5zf…`), but the switch is blocked by the **IO storm**, not by any hash — see the parallel session's report `docs/status/2026-10-16_06-19_pareto-wave-21of27-done-deploy-blocked-on-io-storm.md` (its deploy-intent lock is LIVE; do not race it).

---

## Timeline (verified against store paths, commits, and build logs)

| Time | Event |
| --- | --- |
| 04:33 | Deploy fail #1 — `browser-history-server` build: `unknown field StateShape in struct literal of type snapshot.Snapshot` (vendored `_local_deps/cqrs-htmx/usermgmt`) |
| ~04:35–05:00 | Diagnosed + fixed the browser-history pin pair (commit `11c42ca`); handoff executed by owner (push + `nix flake update browser-history`) |
| 05:11 | Deploy fail #2 — `HaGeZi-dyndns-raw` hash mismatch → re-pinned (probe protocol), oscillation documented |
| 05:49 | Deploy fail #3 — `HaGeZi-doh-raw` (same class, second list) → inventory run revealed **9 drifted raw FODs** |
| ~05:50–06:10 | Wave 2: canonical `scripts/dns-update.sh` found; its latent hash-lookup bug fixed; `--hashes-only` added; selftests extended; 9 hashes re-pinned; toplevel GREEN; committed `4f2fdf14` (full pre-commit battery incl. shellcheck + flake check) |
| ~06:1x | `4f2fdf14` pushed to origin (outside this session); daemon committed `c3cdf7a5` (other session's file) on top |
| 06:19 | Parallel session's report lands: wave work in-tree, switch blocked on IO storm |

---

## a) FULLY DONE

1. **browser-history dependency-pin repair.** The flake pinned `go-cqrs-lite@68585881e` (2026-10-10, predates `snapshot.Snapshot.StateShape`, introduced by `e72572094`) and `templ-components@3f1a254` (predates `display.ButtonProps.Children`), while pinned `cqrs-htmx@30646713f` requires both — the Nix build substitutes those libraries for the pins, so compilation failed inside `_local_deps/`. Re-pinned `go-cqrs-lite → 1f4872b4d` (current origin/master AND the exact rev the repo's go.work workspace builds against) and `templ-components → 620998bd`; `vendorHash.nix` server hash refreshed for the new go.sum. Evidence: both `.#browser-history-server` and `.#browser-history-agent` build green; `nix flake check` green; commit `11c42ca` pushed; SystemNix lock → `11c42ca`; the parallel session probe-built the drv **rc=0**. (The two daemon heuristic commits carrying my edits were squashed via verified soft-reset — `git show --stat` confirmed both held only my files.)
2. **HaGeZi-dyndns re-pin (wave 1).** Hash `sEWGDR5z… → msvz1YA…` after the 2026-10-14-precedent protocol (two `nix store prefetch-file` probes 20 s apart, STABLE). Discovery: the fresh bytes are **byte-identical (`cmp`) to the previously-built-and-served store output** — upstream had *reverted*, not advanced. Comment in `dns-blocklists.nix` documents the oscillation risk and the commit-pinned-URL escalation path. (Landed inside daemon commit `11074d64` mixed with five other sessions' files — deliberately NOT amended, per the daemon-race policy.)
3. **HaGeZi nine-list re-pin (wave 2).** Inventory from a `--keep-going` build: `ultimate, tif, doh, gambling, nsfw, social, hoster, urlshortener, dga7` raw FODs drifted. Re-pinned via the canonical script; `git diff` verified as **exactly 9 hash-line changes**, each equal to the build's `got:` value. Evidence: toplevel `nix build --keep-going` GREEN (`/nix/store/l7qfx5zf…-nixos-system-evo-x2-…`); commit `4f2fdf14` with all pre-commit legs passing (deadnix, statix, treefmt, **shellcheck on the staged script**, `nix flake check`); pushed.
4. **`scripts/dns-update.sh` hardening.** Three changes, one commit: (a) the hash-line lookup assumed the `hash = "…"` line sat *immediately* below each url — entries carrying a re-pin rationale comment (hoster 2026-10-14, dyndns 2026-10-16) were reported `FAILED` instead of updated; replaced with `find_hash_line` (forward scan over comment/blank lines, stops at the next structural line, bounded `HASH_LOOKAHEAD=15`); (b) new `--hashes-only` flag skips the StevenBlack commit-pin advance so a build fix never bundles an unrelated list refresh (upstream HEAD `82f0b508` ≠ pin `21605cca` — running the script verbatim would have advanced it); (c) `--selftest` extended from 4 to **8 cases** (comment-between, blank-between, decoy comment mentioning a hash, missing-hash), all passing. Header documents the flags; the NEVER-rewrite-HaGeZi-URLs warning preserved.
5. **Re-pin evidence protocol (all 10 lists).** Every new hash was verified three ways before pinning: (i) STABLE across a 20 s double-probe, (ii) equal to the build's `got:` hash, (iii) **byte-identical to the store output this system previously built and served** — so the wave restores known-good content rather than accepting new upstream data. Zero functional change to the blocklists themselves.
6. **Self-harvest at authoring time (the no-drift rule).** Updated in this cycle: `docs/todo/pipeline.md` churn row (recurrence + oscillation evidence + script state), `docs/todo/services.md` nightly-automation row (same + `--hashes-only`-for-CI + wire-the-selftest), and both `TODO_LIST.md` queue mirrors (lines 416, 1294). Updated existing rows — no parallel rows created.

## b) PARTIALLY DONE

1. **The deploy/switch itself.** Fix is committed AND pushed, toplevel verified green — but `/run/current-system` is still the 20261014 generation. Remaining: run `nix run .#deploy` when the IO storm clears (respect the live deploy-intent lock from the parallel session; open a fresh intent after theirs goes stale). Blocker: IO PSI, not hashes. Effort: S.
2. **`dns-update.sh --selftest` wiring.** The 8 offline selftests exist and pass, but **no flake check runs them** (no `*.nix` references the script — the selftesting-scripts pattern of `audit-shell-nullglob`/`check-todo-system` was not applied here). Remaining: wire into `flake/parts/checks/selftests.nix`-style check. Effort: S. Harvested into the services.md row.
3. **The blocklist refresh MODEL decision.** Both fix shapes are still open `[ready]` rows and they *conflict*: dated mirror-snapshot pins (pipeline.md) vs nightly auto-repin workflow (services.md). My oscillation evidence feeds the decision but doesn't make it. Remaining: owner arbitration (question 1 below). Effort: M (whichever shape wins).

## c) NOT STARTED (session-scoped)

1. **Nightly drift automation + `--check` CI mode** (services.md `[ready]` row) — the structural fix so drift lands as a green scheduled commit instead of a failed deploy. Not started; directly unblocked by `--hashes-only`.
2. **Mirror git-history audit of the transient content** — the 2026-10-14/15-era bytes the *running* dnsblockd still serves are unrecoverable locally (outputs GC'd; upstream reverted away). Cloning `gitlab.com/hagezi/mirror` and diffing its history would identify exactly what was served during that ~24 h window. Not started; owner may waive (question 2).
3. **Re-hash drill documentation** in `docs/services/dnsblockd.md` (the pipeline.md row's fallback shape if the model stays rolling-main). Not started.
4. **CHANGELOG entry for the HaGeZi wave** — the StateShape blocker got one (another session); this wave (5th churn incident, 10 lists, tooling hardening) has none yet. Not started. Effort: S.
5. **Broken-toplevel-build signal** (existing pipeline.md `[ready]` row) — re-confirmed by this window: three failed deploys over 75 minutes were the *only* detection mechanism. Not started by anyone.

## d) TOTALLY FUCKED UP

1. **The HaGeZi churn class is structural and accelerating.** Deploy windows killed: 2026-10-01, 10-03, 10-14, and now 10-16 twice (dyndns 05:11, nine lists 05:49). New evidence this session: the GitLab mirror **oscillates between content states** rather than only drifting forward — every one of the 10 stale pins had caught a transient state that upstream later reverted. Hash-chasing will keep biting until the fetch model changes (snapshot-pin vs scheduled auto-refresh). Severity: every occurrence is a tree-wide build failure blocking ALL deploys; no data loss.
2. **The running dnsblockd serves unverifiable list bytes.** The 2026-10-14/15-era content it currently enforces is the transient mirror state: unrecoverable from the local store (GC'd) and no longer served upstream. Most likely benign regeneration; **unproven**. Mitigation: the next switch replaces all lists with bytes verified three ways (see a.5); the mirror-history audit (c.2) would close the question retroactively.
3. **Deploy-failure detection is still deploy-time-only.** 04:33 / 05:11 / 05:49 — each failure surfaced only when someone ran the deploy. The "broken-toplevel build signal" row has predicted this pain since 2026-10-16 04:43; this window is its third confirmation in one morning.
4. **My own missteps (same-session honesty):**
   - Hand-patched dyndns **before** searching for canonical tooling — `scripts/dns-update.sh` existed the whole time. The patch was correct, but the order violated the "check for existing tooling first" discipline; had I looked first, wave 1 and wave 2 would have been one script run plus one bug fix.
   - First probe script had **broken output parsing** (empty paths → 9 spurious fetch errors, one wasted cycle) — I scripted around an output format I hadn't sampled. The redo used `--json`; the one-URL format check should have been step one.
   - `--keep-going … | tail -15` **truncated the root-failure enumeration** on the first wave-2 build — the roots scrolled past and I burned two extra build cycles re-running with filters. Capture to a file, filter after.
   - I never checked whether pre-commit's shellcheck leg would run on the script after the daemon committed it (the daemon-race blind spot). It *did* run — because my final pathspec commit re-staged the file — but that is luck wearing discipline's clothes.

## e) WHAT WE SHOULD IMPROVE

1. **"Check for tooling" must cover repairs, not only builds.** `grep scripts/` for a canonical fix path BEFORE hand-patching anything. Impact: would have collapsed this session's two waves into one script run; prevents one-off patches that the canonical tool then reports as FAILED.
2. **Never tail an error enumeration.** `--keep-going` exists to list ALL root failures; piping it through `tail` keeps only the cascades. Standard move: `2>&1 | tee /tmp/build.log`, then grep the file. Impact: two build cycles saved per incident.
3. **Sample unfamiliar output before scripting it** — or prefer `--json` variants (`nix store prefetch-file --json`). Impact: one wasted probe cycle this session.
4. **Selftesting-scripts pattern should be universal**: a `--selftest` that no check executes is documentation, not verification. Wire script selftests into flake checks as they're added.
5. **`--hashes-only` should be the documented default for any automated/CI use** of dns-update.sh; the StevenBlack pin advance stays a deliberate operator action. (Recorded in the services.md row.)
6. **Selective re-pin comments work** — the hoster/dyndns precedent comments are what made the oscillation discoverable today. Keep them for non-obvious cases (reverts, security-adjacent, protocol changes); skip them for routine advances to avoid comment noise.

## f) Top things to get done next (ranked; impact / effort / category)
> **Harvest disposition (docs-health 2026-10-18):** NOT HARVESTED as new rows — §f carries explicit per-item dispositions in-file (deliberate non-harvest reasons recorded above); nothing untracked remains.

In-scope first (this session's surfaces), then the cross-cutting items this window re-confirmed. The crowdsec/geo wave backlog is deliberately NOT duplicated here — it lives in the 06-19 report's §f and the todo libraries.

| # | Task | Impact | Effort | Category | Harvest status |
| --- | --- | --- | --- | --- | --- |
| 1 | Run `nix run .#deploy` when the IO storm clears (all blockers are hash-green; honor the deploy-intent convention) | Critical | S | Bug | pending owner/parallel session |
| 2 | Arbitrate the HaGeZi fetch model: dated mirror-snapshot pins vs nightly auto-repin vs status quo (question 1) | Critical | M | Decision | rows exist (pipeline.md + services.md) |
| 3 | Build the nightly drift workflow + `--check` mode, using `--hashes-only` | High | M | Feature | existing services.md row |
| 4 | Wire `dns-update.sh --selftest` into a flake check | High | S | Quality | harvested into services.md row |
| 5 | Mirror git-history audit of the transient 10-14/15 content (c.2), verdict into dnsblockd.md | Medium | M | Investigation | harvested into pipeline.md row |
| 6 | Document the re-hash drill in `docs/services/dnsblockd.md` (if model stays rolling-main) | Medium | S | Documentation | existing pipeline.md row option |
| 7 | CHANGELOG entry for the 2026-10-16 HaGeZi wave (5th incident, 10 lists, tooling hardening) | Medium | S | Documentation | NEW — deliberately not queue-harvested (single-line doc task, ride the next docs pass) |
| 8 | Broken-toplevel-build signal (metric/hook so tree-red pages before a deploy attempt) | High | M | Feature | existing pipeline.md row (3rd confirmation this window) |
| 9 | Post-switch: run `post-deploy-check.sh` and eyeball the dnsblockd sections (mapping.json size, list freshness) | Medium | S | Verification | NEW — rides item 1, no separate queue row |
| 10 | StevenBlack pin policy: freeze at `21605cca` (always `--hashes-only`) vs advance-on-refresh — fold into question 1's answer | Medium | S | Decision | folded into services.md row via this report |
| 11 | After 2–3 more re-pins (or immediately, if item 2 picks snapshots): delete the now-hand-patched hash comments if the model makes them moot | Low | S | Cleanup | deliberate non-harvest (conditional on item 2) |
| 12 | Sweep `/tmp/probe*.sh` leftovers from this session (and adopt the capture-to-file convention from e.2 in any future scripts) | Low | S | Cleanup | deliberate non-harvest (ephemeral) |
| 13+ | Fleet backlog continues in `TODO_LIST.md` (dispatch queue) + `docs/todo/*.md` libraries and the 06-19 report §f — highest-impact neighbors this window re-confirmed: deploy-intent tooling build-out (pipeline.md), un-red the CI nix-check workflow's token leg (blocked:user on `NIX_GITHUB_RO_TOKEN`), dnsblockd upstream-module migration (blocked:push) | — | — | — | already queued |

## g) Questions (owner-only; what I tried first)

1. **HaGeZi fetch model + StevenBlack policy.** The mirror provably *oscillates*, and hash-chasing has now killed five deploy windows. Which model do you want: (a) pin the GitLab mirror by commit SHA (builds never break on content; list updates become deliberate bumps), (b) keep rolling `main` + the nightly auto-repin workflow (freshness wins; drift lands as green scheduled commits), or (c) status quo manual re-pin? And should the StevenBlack commit pin stay frozen (always `--hashes-only`) or advance on every refresh? I cannot decide this: it is a freshness-vs-stability policy call, and the two existing `[ready]` rows propose conflicting shapes.
2. **Audit the transient content, or waive it?** The bytes the *running* dnsblockd enforced since ~2026-10-14 are unrecoverable locally. I can clone `gitlab.com/hagezi/mirror` and identify from its git history exactly what those transient lists contained (and whether they were degraded/partial). Want that audit (≈30 min, closes the question with evidence), or do you accept "benign upstream regeneration" and let the next deploy replace the bytes?
3. **Next window priority once the deploy lands:** the nightly drift automation (item 3, stops the bleeding) or the broken-toplevel-build signal (item 8, stops the blindness)? Both fired repeatedly this morning; I can't rank your pain for you.

---

*Report written per the status-report skill; the user explicitly requested `.md` at this path, which overrides the skill's HTML-canonical default (flagged per protocol). Per the harness contract this file is NOT manually committed — the auto-commit daemon picks it up. Section (f) items marked "harvested" already landed in `TODO_LIST.md` / `docs/todo/{pipeline,services}.md` during authoring (no-drift rule); the rest carry their disposition inline.*
