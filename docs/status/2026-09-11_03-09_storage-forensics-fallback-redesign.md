# Status Report: Storage Forensics + Fallback Redesign — "I hate this" → /tmp/bc-fallback

**Date:** 2026-09-11 03:09 CEST
**Session scope:** continuation since the 02:21 report — executed the owner answers (push go-taskqueue / investigate smoke failures now), answered "EXPLAIN WHAT HAPPENED?" (BTRFS), answered "Where is all the storage?" + "What can we delete in ~/tmp?", and redesigned the buildcache fallback mechanism the owner declared hatred for. Covers 02:21 → 03:09; the 02:21 report's open items carry forward unless restated.
**Format note:** `.md` per explicit user instruction (status-report skill's HTML default overridden — flagged, not propagated).

---

## Executive Summary

Three threads ran this turn:

1. **Both broken upstream repos are now healed end-to-end.** go-taskqueue's vendorHash fix was committed and **pushed** (`aea63da`, owner-authorized); SystemNix re-locked and tracking master again; `.#tq` builds green. Together with buildflow's `d082b7e70` earlier, every LarsArtmann flake input in this deploy is once again buildable at its tracked head.
2. **Both unexplained round-1 smoke failures are root-caused.** CV render: the smoke pins `chromium`, which does not exist in the system closure — the box ships **Helium** (ungoogled-Chromium 151). Fixed with a chromium→helium fallback in CV's `render-smoke.ts` and **verified live: PASS** (both pages render real DOM). Bank-sync: **not a regression** — the documented Wise SCA challenge gate; fresh single-use OTTs are in the journal awaiting the owner's in-app approval.
3. **The storage question became a design fix.** Mapping the 693 GiB (answer: `/home/lars/projects` 315 G, `~/tmp` 51 G — mostly dead pin-era caches — `/nix` 115 G, journal 7.9 G, remainder snapshot-pinned churn) exposed that `00-go-cache-guard.fish` redirects **nine cache env vars into `$HOME/tmp` during buildcache outages** — the mechanism that produced the opaque 51 G mess. Owner: "I hate this btw". The fallback now lands in **`/tmp/bc-fallback` on the 48 G tmpfs** with automatic sweeping by `buildcache-usb-recovery` — outages keep working, user scratch stays clean, nothing snapshot-pins, nothing silently chews the QLC NVMe.

**Standing exposure:** the round-2 deploy has NOT run yet. `/run/current-system` is still the round-1 activation with **no profile generation** — a reboot would revert miniflux + the buildflow fix (the anchoring debt from round 1). Everything for a clean round-2 is built and gated.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | **go-taskqueue upstream vendorHash fix pushed** — `flake.nix` hash `/rKFWq…` → `NQi6Xp…` (the probe-observed FOD hash of HEAD's module set), commit `aea63da` | Push output: `3426afc..aea63da master -> master`; commit body names the source-only-churn class and the downstream frozen pin |
| 2 | **SystemNix tq re-locked to master** (`aea63da`), frozen `200213a` pin dropped, `?ref=master` moving-ref restored | Lock diff output; `.#tq` builds: `/nix/store/4s55irrn…-go-taskqueue-0.2.0` |
| 3 | **CV render smoke root-caused AND fixed AND live-verified** — `chromium` absent from system closure (old gen too — checked system-764-link), `helium` present; `render-smoke.ts` gained a `resolveChromiumPath()` fallback (env override → chromium → helium); rerun: `PASS CV name heading` + `PASS admin hub surface group`, rc=0 | Live bun run output; screenshots written; the 2 console-401 WARNs are the auth-gated metrics fetches (pre-existing, non-fatal) |
| 4 | **Bank-sync smoke failure diagnosed: the documented SCA gate, not a regression** — journal shows balances syncing (NZD balance 243ms, diff previews clean) + per-balance "statements paused pending SCA approval" WARNs with FRESH single-use OTTs (issued 02:17 post-deploy restart) | journalctl scan; matches `docs/services/bank-sync-sca.md` semantics exactly (403 + x-2fa headers, degraded transfers fallback) |
| 5 | **Full storage map delivered** (root fs): projects 315 G (`.git` 18 G), `~/tmp` 51 G, `/nix` 115 G (≈61 G physical at the measured 1.89× zstd), `/var` 12 G (journald 7.9 G), ~148 G+ delta = 6 root snapshots pinning post-Aug-31 churn | du sweeps (sequential, timeout-bounded), snapshot dir listing (Aug 31 + Sep 6–10), journalctl --disk-usage |
| 6 | **`~/tmp` fully classified** — dead pin-era caches (~25 G: `lint-tree-*` 6.3 G with zero config references, hex GOCACHE index dirs, `go-buildNNN` family, leaked chromium temp profiles, `ats_test.test` binary) vs actively-written keepers (`bunx-1000-@tailwindcss`, `playwright*`) vs named user scratch (`pw-bun-repro2`, `systemnix-pr139`, `cv-app` — owner's call) | find+du classification, mtime freshness check, consumer grep |
| 7 | **The fallback redesign implemented** — `platforms/nixos/users/home.nix`: all 9 guard fallbacks (`TMPDIR`, `GOCACHE`, `GOMODCACHE`, `GOLANGCI_LINT_CACHE`, `CARGO_HOME`, `PIP_CACHE_DIR`, `SCCACHE_DIR`, `npm_config_cache`, `PLAYWRIGHT_BROWSERS_PATH`) now target `/tmp/bc-fallback/*` on the 48 G tmpfs (TMPDIR → `/tmp` itself), with a comment documenting the failure history that motivates it | home.nix diff; design table (outage-still-works / zero home pollution / zero NVMe churn / nothing snapshot-pinned / loud ENOSPC when exhausted) delivered to owner |
| 8 | **Recovery-side self-cleanup wired** — `buildcache-usb-recovery` step 6 `rm -rf /tmp/bc-fallback` after the mount heals AND verifies real I/O; tmpfs reclaims instantly | buildcache.nix diff; eval green |
| 9 | **My own Nix interpolation bug caught by the gate before it could land** — `${freed_before}` inside a `''…''` string failed eval; fixed by dropping the variable (the escaping trap the repo has documented before) | First eval error output named line 362; re-eval: `all checks passed!` |

---

## b) PARTIALLY DONE

| # | Item | Works now | Remains open | Blocker | Effort |
|---|------|-----------|--------------|---------|--------|
| 1 | **Deploy round 2** | All inputs healed (buildflow `d082b7e70`, tq `aea63da`), tq exit-4 cause eliminated, toplevel built, smoke fixes in | The switch + anchoring completion (round-1's debt) + post-deploy smoke re-run | Owner runs it (sudo); it's 03:00 and they're doing storage cleanup instead — their call, but the exposure is real | S |
| 2 | **`~/tmp` safe-batch deletion (~25 G)** | Fully classified, exact `rm` command written and delivered | Not executed — owner hasn't said go; ~22 G was already deleted by the owner mid-session (`go-cache`, `go-mod`, `go-lint`) before my classification landed | Owner word (du-size frees now; physical space lands as snapshots prune) | S |
| 3 | **BTRFS recovery sequencing** | Explained the `btrfs filesystem usage` output (21.9 G file-free vs 4.48 G unallocated; metadata-DUP crash mechanics; why the gc-guard aborted); reserve file confirmed present (10 G, Aug 17) | The before-reboot vs after-reboot sequencing decision was never actually answered (the owner pasted the usage output instead) — my recommendation stands: **recover first** (balance wants quiet; and the reserve's "instant 10 GiB" is now snapshot-caveated, see e#3) | Owner decision (re-asked in g/Q3) | — |
| 4 | **CV render-smoke fix propagation** | Fixed in the local CV checkout (bun runs the checkout directly — the smoke is already healed); CV's auto-commit daemon will batch it | Commit is local; push to CV origin not requested/authorized | Owner's CV workflow | S |
| 5 | **Guard redesign rollout** | Source changed, eval + flake check green | Live fish file updates only at the next HM activation (deploy); current sessions keep old env until re-login | Same deploy as #1 | — |

---

## c) NOT STARTED

| # | Item | Why | Wanted? |
|---|------|-----|---------|
| 1 | **`golangci-lint-lsp-wrapper` fallback audit** — AGENTS.md says it "re-pins the lint cache with the same SIGKILL-bounded alive-check fallback for env-less launch paths"; I did NOT check where ITS fallback points. If it's also `~/tmp/*`, it needs the same redesign | Not researched this turn (flagged immediately rather than assumed clean) | Yes — S |
| 2 | Live SSO login at `rss.home.lan` → then flip `disableLocalAuth` (owner's standing choice) | Gated on deploy round 2 + human browser session | Yes |
| 3 | journalctl vacuum (7.9 G → ~2 G frees ~6 G of du-size; snapshot-caveat applies) | Needs sudo + owner go | Yes |
| 4 | BTRFS runbook snapshot-era caveat: the reserve-file "instant 10 GiB" claim is imprecise while snapshots pin its extents (created Aug 17 → pinned by Aug-31+ snapshots); gc-guard print + AGENTS.md deserve the correction | Discovered this turn, not yet written anywhere | Yes — S |
| 5 | TODO_LIST HARVEST from three reports now (00:22, 01:38, 02:21, this one) | Report-then-wait | Yes |
| 6 | CI green check on next SystemNix push (tq is `github:`-type for the first time — the CI-dark class) | No push yet | Yes |
| 7 | Everything else carried from the 02:21 report's (c): OAUTH2_REDIRECT_URL live verification, miniflux restore/rotation drills, OPML onboarding, cross-repo locked-input audit | Post-go-live items | Medium |
| 8 | [R] Periodic storage-map report (du/compsize snapshot as a textfile metric or monthly doc) — this session proved the box lacked one | Idea born this turn | ROADMAP |

---

## d) TOTALLY FUCKED UP

1. **I classified `~/tmp` entries as "dead caches" before checking all their consumers.** My first classification message called `go-cache`/`go-mod`/`go-lint` dead — minutes later the fish-guard read revealed those are the guard's ACTIVE fallback targets. ~22 G was deleted by the owner mid-session (before or around my message). No data was lost (rebuildable, recreated on demand by design) — but the classification process was backwards: consumers first, verdict second. The final classification in this report's (a)#6 IS consumer-verified.
2. **I shipped `${freed_before}` into a `''…''` Nix string** — the exact interpolation trap this repo has documented — and the eval caught it. One wasted cycle; the fix removed the variable rather than escaping it (simpler log, fewer traps).
3. **The anchoring debt is now ~1.5 hours old and counting.** Round-1 activated without a profile generation; every minute until round-2, a crash or reboot silently reverts miniflux + buildflow. Nothing new broke — but the box is sitting on a loaded spring because the deploy hasn't been re-run (owner's timing, flagged every report).
4. **The BTRFS runbook's "instant 10 GiB" claim is wrong in the snapshot era** — the reserve file (created Aug 17) is extent-pinned by the Aug-31+ local snapshots, so `rm` frees du-size but `df` only moves as snapshots prune. The claim lives in the gc-guard's own printed runbook and AGENTS.md prose. I propagated it twice tonight before catching the nuance myself. Needs the caveat written back into the runbook (c#4).
5. **The old fallback design was a slow-motion footgun that ran for months** — nine env vars silently redirecting into a user-scratch dir during outages, writing the boot disk full, snapshot-pinning the evidence. Tonight's 51 G mystery was its exhaust. The design is fixed now, but the pattern deserved a harder look in August when the pins were removed.

---

## e) WHAT WE SHOULD IMPROVE

1. **Consumer-check before any "this is dead" verdict** — every path, env var, or file slated for deletion gets a grep across fish config, HM modules, wrappers, and unit scripts FIRST. The `~/tmp` classification shipped a verdict before its own due diligence; the guard redesign required reading `00-go-cache-guard.fish` in full — that read should have PRECEDED the classification, not followed the owner's deletion.
2. **Fallback-design doctrine: never fall back into `$HOME`, never onto the boot disk.** The tmpfs-fallback + recovery-sweep pattern from tonight's redesign is the template; audit the remaining "dead-mount fallback" implementations (golangci-lint-lsp-wrapper first — c#1) for the same disease.
3. **Runbook claims need mechanism-math.** "Instant 10 GiB" ignored snapshot pinning; the repo's own doctrine ("rm doesn't free space when snapshots reference data") contradicts its own runbook. Sweep the BTRFS runbooks for physical-vs-logical reclaim claims and annotate them with the snapshot-lag reality.
4. **The Nix-string interpolation trap keeps collecting scalps** (mine tonight). The rule "in `''…''` scripts, `${` is Nix" should be grepped for in pre-commit (a lint that flags `${` in shell-y script strings where `''${` was likely intended — with allowlist).
5. **Upstream repo self-build CI (carried, now urgent by success):** both BuildFlow and go-taskqueue broke at HEAD this session and were fixed by hand-pushed hash commits. A 5-minute self-build CI job per LarsArtmann flake blocks this class at the push. Two down (pending), N to go.
6. **Answer-the-question-you-were-asked discipline:** the owner's Q1 ("sequencing?") was answered with a btrfs output + a different question; I explained (correctly) but let the actual decision silently stay open. Re-ask crisply (done — g/Q3). Decisions that stay open across turns become tomorrow's exposure.

---

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

Carried-forward items keep their intent; new items from this turn are marked (new). **HARVEST input** — [R] = ROADMAP-fuel.

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Re-run `nix run .#deploy` (round 2) — clears the anchoring debt, lands tq/buildflow/miniflux/guard-redesign | Critical | S | Feature |
| 2 | Verify anchoring post-switch: current-system == newest profile generation (round-1 debt MUST clear) | Critical | S | Quality |
| 3 | Confirm `tq-agent-pool` starts on the new tq (the exit-4 cause; journal must show pool accepting `task-closeout`) | Critical | S | Quality |
| 4 | Re-run `nix run .#post-deploy-check` — expect Miniflux PASS (sign-in at `/`), CV PASS (helium fallback), tq PASS; baseline re-diff | Critical | S | Quality |
| 5 | Execute the `~/tmp` safe batch (~25 G dead caches — exact command already delivered) on owner go | High | S | Cleanup |
| 6 | BTRFS recovery sequencing decision + execution (g/Q3): free reserve → quiet → bounded balance → re-provision | High | M | Bug |
| 7 | Audit `golangci-lint-lsp-wrapper`'s fallback target; redesign to tmpfs if it's `$HOME`-based (new, c#1) | Medium | S | Quality |
| 8 | Live SSO login at `rss.home.lan`; then flip `services.miniflux.disableLocalAuth = true` + redeploy | High | S | Feature |
| 9 | AGENTS.md updates: tq section (tracking master, aea63da story), Miniflux section (login-at-`/`, disableLocalAuth, live facts), fallback-redesign pattern note | High | S | Documentation |
| 10 | Write the snapshot-era caveat into the BTRFS runbook + gc-guard print (reserve "instant" claim — d#4, c#4) | Medium | S | Documentation |
| 11 | `nix build .#quick-go` — prove the full Go set against the final lock (carried) | High | M | Quality |
| 12 | CI green check on next SystemNix push (tq `github:` fetchability) | High | S | Quality |
| 13 | journalctl vacuum to ~2 G (sudo; snapshot-caveat applies) | Medium | S | Cleanup |
| 14 | The owed reboot (flm corpse + llama D-state + clean generation); pre-reboot-check re-run first | High | S | Feature |
| 15 | Investigate remaining smoke WARNs post-reboot: flm :52625, llama 8848/8849 should self-clear; anything still red is a real bug | High | S | Quality |
| 16 | Upstream CI: build-own-flake jobs for BuildFlow AND go-taskqueue (both proved breakable-at-HEAD this week) | High | M | Quality |
| 17 | HARVEST all four status reports into TODO_LIST/ROADMAP | Medium | S | Documentation |
| 18 | CV render-smoke fix: commit + push to CV origin (owner workflow) | Low | S | Housekeeping |
| 19 | Verify miniflux-backup chain post-deploy (pool dir, PGDMP dump, backup-coordination green) | High | S | Quality |
| 20 | Interactive sops decrypt round-trip on `miniflux.yaml` (never verified; sudo) | Medium | S | Quality |
| 21 | miniflux Gatus checks green in deployed config; Homepage tile; rss DNS | Medium | S | Quality |
| 22 | Confirm deploy.sh's miniflux restart block re-bound LoadCredential correctly post-restart cycle | Medium | S | Quality |
| 23 | Verify `miniflux-dbsetup` + `miniflux-wait-oidc` converged clean (journal) | Medium | S | Quality |
| 24 | OAUTH2_REDIRECT_URL: record verified-fact or fix callback after #8 | High | S | Quality |
| 25 | Decide miniflux reader-API requirement (native-only vs GReader-class) — still open | Medium | S | Decision |
| 26 | Wise SCA owner action: approve challenge in the Wise app, token.env runbook, restart, remove token (fresh OTTs expire; regenerated each sync) | Medium | S | Feature |
| 27 | `relock-input-at-rev.sh` with mandatory `--verify` FOD probe (carried; tonight validated the need twice more) | Medium | M | Quality |
| 28 | Smoke-authoring rule into CONTRIBUTING.md: cite VM-test-proven URL or live capture (carried) | Medium | S | Documentation |
| 29 | Fix the smoke regression-diff `comm` unsorted-input bug (carried) | Medium | S | Bug |
| 30 | Pre-deploy chunk-headroom gate: WARN below ~8 GiB root unalloc (carried; tonight proved the deploy itself eats it) | High | S | Quality |
| 31 | [R] Fallback-design doctrine doc: tmpfs targets + recovery sweep, applied ecosystem-wide (born tonight) | Medium | S | Documentation |
| 32 | [R] Cross-repo locked-input-vs-go.mod audit script (carried) | Medium | L | Quality |
| 33 | [R] Lock-health guard: locked rev exists on origin; stale-vendorHash HEAD detection (carried) | Medium | M | Quality |
| 34 | Kernel-hardening + boot.nix changes (parallel session) verified green in the SAME round-2 activation | Medium | S | Quality |
| 35 | Miniflux restore drill (dump → scratch PG) | Low | M | Quality |
| 36 | Miniflux secret-rotation drill + SSO-era break-glass doc | Low | S | Quality |
| 37 | OPML import + reader client onboarding (user) | Low | S | Feature |
| 38 | miniflux dumps join the offsite backup review cadence | Low | S | Quality |
| 39 | FreshRSS-feature gap documented in runbook | Low | S | Documentation |
| 40 | `tests/test-miniflux.nix` stays green through nixpkgs bumps (it probes `/` — keep) | Low | S | Quality |
| 41 | [R] Periodic storage-map report (du/compsize → textfile metric or monthly doc) — born tonight (c#8) | Low | M | Feature |
| 42 | Verify the HM `.backup` sibling of the guard file post-deploy is benign (backupFileExtension artifact) | Low | S | Cleanup |
| 43 | Post-reboot: `/run/booted-system` == `/run/current-system` (doctrine) | Medium | S | Quality |
| 44 | Post-reboot: memory-emergency-guard restore-cap interaction gone (corpse-aware restore skip remains P1 candidate) | Low | S | Cleanup |
| 45 | Commit hygiene: pathspec-commit the mixed workstreams before any push | Medium | S | Housekeeping |
| 46 | Track snapshot-pinned reclaim timeline: tonight's deletions land as Sep-6/7 prunes land at 23:00, Aug-18-era caches at the Aug-31 weekly rotation (~next week) — verify df actually moves on both dates | Low | S | Quality |
| 47 | Consider `~/go/{pkg,build}` (13 G dead GOPATH-era caches) deletion alongside the tmp batch — same consumer-check first | Medium | S | Cleanup |
| 48 | `pw-bun-repro2` / `systemnix-pr139` / `cv-app` in `~/tmp`: owner decides keep/delete (named scratch) | Low | S | Cleanup |
| 49 | docs-health ANNOTATE: mark prior reports' blockers resolved as round-2 lands | Low | S | Documentation |
| 50 | Close this report's three questions — they route tasks #1/#5/#6 | — | — | Decision |

---

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

Asked via the interactive prompt after this report:

1. **Deploy round 2 timing** — the anchoring debt is live exposure; run now or after the storage work?
2. **`~/tmp` safe batch** — execute the delivered `rm` command now? (owner go was never given)
3. **BTRFS sequencing** — recovery before or after the reboot? (asked twice, still unanswered)

---

## Current Tree State (03:09 CEST)

```
M  platforms/nixos/users/home.nix           # guard fallbacks → /tmp/bc-fallback
M  modules/nixos/services/buildcache.nix    # recovery sweep step 6
(committed by daemon earlier tonight:      # flake.lock → buildflow d082b7e70,
                                            # tq aea63da; smoke /-fix; miniflux
                                            # option; miniflux.yaml; docs)
Local CV checkout: render-smoke.ts helium fallback (unpushed, daemon will commit)
Local go-taskqueue: clean (aea63da pushed)
Local BuildFlow: clean (d082b7e70 pushed)
```

SystemNix branch is several daemon commits ahead of origin; next push carries everything mixed — pathspec-commit discipline applies.

**Waiting for instructions.**
