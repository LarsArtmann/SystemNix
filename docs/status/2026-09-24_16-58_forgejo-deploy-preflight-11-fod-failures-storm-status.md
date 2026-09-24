# Session Report: Forgejo Catppuccin Deploy — Preflight Enumerates 11 Broken FODs in the Parallel Lock Wave; IO Storm Persists All Day

**Date:** 2026-09-24 16:58 (session 12:10 → 16:58)
**Session goal:** execute the pending Forgejo theme deploy end-to-end (deploy → anchor → smoke → live verification), autonomously.
**Outcome:** deploy is HARD-BLOCKED at build level — the toplevel at HEAD cannot build (11 root failures, all from the parallel session's mass lock wave, none from the theme change). Separately, an IO storm ran the entire session (12:10 → 16:57+, no calm window). Both blockers are fully enumerated with evidence below.

**Defaults I assumed (from yesterday's 3 open questions):** (1) deploy normally, force-with-evidence only if the box is provably calm — never into an active storm; (2) keep blue-primary `catppuccin-auto` as built; (3) logo phase 2 stays a decision row, not executed.

---

## a) FULLY DONE (this session)

1. **Tree verification** — HEAD `d3143bc8` (3 daemon commits past the parallel session's `5f9740c4`), tree clean. Theme code intact: `modules/nixos/services/forgejo.nix:38-40` (3 delta themes), `:283-284` (`DEFAULT_THEME = "catppuccin-auto"`, `THEMES` list). Smoke checks intact at `scripts/post-deploy-check.sh:1283-1291`. mr-sync lock node = `6c1d3f6d` — the parallel session's go-floor fix is in and builds green from our lock.
2. **Smoke-contract audit** — the `2>/dev/null || true` suffixes on the forgejo checks looked like they might neutralize failure semantics. Verified they do NOT: `check()` accumulates `FAIL` + `record_fail` internally, and the summary exits 3 on NEW failures vs the baseline. The `|| true` is the script-wide pattern (the pre-existing "Forgejo (HTTPS)" check carries it too). The 4 theme checks ARE hard regression gates. No fix needed.
3. **Verification method de-risked + pre-deploy baseline captured** — fetch tool works against `forgejo.home.lan` TLS. Theme asset `theme-catppuccin-auto.css` = **404 today** (expected pre-deploy). Landing baseline (download + grep): `data-theme="forgejo-auto"`, `<title>Local Git Forge</title>`, "Powered by Forgejo" PRESENT, upstream-default meta description. Every post-deploy assertion is now a defined delta against a captured baseline.
4. **Gate scripts syntax-validated** — `bash -n` on `pre-deploy-check.sh`, `post-deploy-check.sh`, `deploy.sh` (the parallel session modified two of them in the batch riding this deploy): all OK.
5. **Storm diagnosis** — active crash-#3-class IO storm at session start: load peaked 122, io PSI some avg10 oscillating 17-75%, avg60 60-70% sustained, disk 100% busy, guard trips #970/#971 observed firing live (5-6/hour), MemAvailable 33-45% (memory healthy — the pure IO class). Drivers: **20 crush sessions**, Rust compile storm (327%+320% CPU), go builds in D-state, a qemu VM test, flush kworkers on 8:16. Per-device 6s sample: **sdb (pool member, via the ONE DAS USB link) is the saturated device** (~22% in-sample, 100% in guard windows); Samsung nvme1n1 5.7%, QLC nvme0n1 1.8%, buildcache sda 0.1% — consistent with attic cache traffic (`cache.home.lan` storage lives on the pool) from the parallel build storm.
6. **Preflight enumeration (the session's key result)** — `nix build #nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` enumerated the ENTIRE blocker set in one pass: **the toplevel at HEAD cannot build** (11 root failures, table below). All introduced by the parallel mass lock wave (nixpkgs 20260920.44a9189 → 20260922.6774f7b + signoz pair, hermes 0.21.4, inboxclean, PMA, discordsync, bank-sync, taskqueue 0.3.1, cqrs-lint, papdashboard, health-hub, erraudit, go-structure-linter all moved). **None of the failures touch the forgejo/theme change.** The mr-sync session verified ONE package and declared the deploy pending; the other 11 waves' worth of breakage had never been built.
7. **Clean shutdown of the preflight** — killed after enumeration completed (the store retains everything already built: hermes 0.21.4 chain, discordsync 9f2bae8 prepared-source, bank-sync, go-taskqueue 0.3.1, crush-daily, go-auto-upgrade, golangci-lint-auto-configure all built green mid-storm). No reason to keep feeding an active storm with the task build-blocked regardless.

### The 11 root failures (complete, from the full build log)

| # | Derivation | Failure | Got-hash / detail |
|---|---|---|---|
| 1 | cqrs-lint-6170c4e76 go-modules | FOD hash mismatch | `mY+mdZEz…` vs `De0v4pUL…` |
| 2 | branching-flow-0.2.0 go-modules | FOD hash mismatch | `Vezc2hYk…` vs `yPHQjgzZ…` |
| 3 | inboxclean-9b02133 go-modules | FOD hash mismatch | `5WsuTeAO…` vs `ViWUbqFO…` |
| 4 | projects-management-automation-0401824 go-modules | FOD hash mismatch | `FtTo9R75…` vs `IBX7hU/H…` |
| 5 | signoz-frontend-5a1be60 pnpm-deps | FOD hash mismatch | `3IiQUkVB…` vs `7r+rqIcc…` |
| 6 | signoz-otel-collector-a52dc57 go-modules | FOD hash mismatch | `BYYyzlC8… vs pJ9Qufxl…` |
| 7 | erraudit-1c85610 go-modules | FOD hash mismatch | `dPMFk3hy…` vs `eGg9GDlf…` |
| 8 | go-structure-linter-721c62a go-modules | FOD hash mismatch | (same class; in truncated log section) |
| 9 | health-hub-ecccf63 go-modules | `go: updates to go.mod needed; go mod tidy` | the mr-sync "local tidy lies" class |
| 10 | papdashboard-bfa5f786 prepared-source | mkPreparedSource validation: `go-etag/entitytag` + `go-etag/server` "modules without local replace" | publicDeps gap — CV `ed8b92f` precedent |
| 11 | project-discovery-daemon-73b7d32 go-modules | `go.mod requires go >= 1.27.1 (running go 1.26.7; GOTOOLCHAIN=local)` | the 2026-09-17 three-wiring-points class |

Downstream casualties (units that cannot build): signoz.service, signoz-collector.service (+prestart), papdashboard.service, inboxclean-web/sync, PMA, project-discovery-daemon, health-dashboard, cqrs-lint + fish-completions, branching-flow. The toplevel `nixos-system-evo-x2-26.11.20260922.6774f7b` is unreachable — **no deploy can build until this wave is repaired or rolled back.**

---

## b) PARTIALLY DONE

1. **Deploy campaign** — blocked twice over: (1) *weather*: 90-min poller + second poller show the storm ran 12:10 → 16:57 continuous (trips/hour dropped 5-6 → 1-2 by late afternoon; avg10 hit 14.15 at 16:57 but load simultaneously spiked to 119 — still no true calm window); (2) *build*: the 11 FOD failures above make any deploy unbuildable regardless of weather. Force-with-evidence stays moot.
2. **Live theme verification** — method validated and baseline captured (see a.3); cannot run until the theme actually deploys.

## c) NOT STARTED

- The deploy itself, anchoring check, `post-deploy-check` live run, live theme verification (asset/landing/title/meta/footer/arc-green), post-deploy convergence sweep (forgejo-github-sync start, hermes health).

## d) TOTALLY FUCKED UP (honest)

1. **Re-committed the pipefail sin**: launched the preflight as `nix build … | tail -5; echo "BUILD_RC=$?"` — the EXACT trap this session's own summary warns about (rc would be tail's, not nix's). Caught it within seconds, killed, relaunched unpiped. Zero damage, second documented occurrence — this is a personal recurring failure mode now.
2. **Poller bug, found during report prep**: the second poller's avg60 extraction (`/^some avg60/`) can never match — avg60 lives on the SAME line as avg10 in `/proc/pressure/io`. `io_avg60=` was empty in EVERY heartbeat and I never looked. awk coerced `""` to 0, so the `avg60 < 20` calm criterion was a silent no-op; the calm signal was effectively avg10-only. (First poller also died instantly: `$SECONDS` arithmetic is rejected by mvdan/sh — "not a valid test operator: 5400"; fixed with an iteration counter.)
3. **jq filter error**: `.nodes.mr-sync.locked.rev` — the hyphen parses as arithmetic; needs `.nodes["mr-sync"]`. Trivial, but embarrassing.
4. **Process miss**: I did NOT inspect the flake.lock diff before starting the preflight — `git diff --stat` showed 61 files changed and I only checked the two scripts I cared about. The mass input move was visible in advance and would have predicted FOD carnage BEFORE burning ~2.5h of build into an active storm box.

## e) WHAT WE SHOULD IMPROVE

1. **Lock-wave preflight rule**: whoever lands a mass input bump must run a toplevel `--keep-going` build (or per-package FOD probes) BEFORE calling the tree deployable. The mr-sync session verified one package and stopped; 11 others were broken. Candidate AGENTS.md/CONTRIBUTING rule.
2. **Diff flake.lock before any big build** — `git log --stat -- flake.lock` + locked-rev comparison is cheap and predicts FOD storms. I skipped it (see d.4).
3. **Why didn't the nightly `go-deps-audit.yml` catch this?** — worth investigating whether its scope misses the toplevel FOD set (or whether it simply hasn't run since the wave landed).
4. **Poller discipline**: validate heartbeat fields on the FIRST sample (the empty avg60 was visible immediately); use positional awk fields, not anchored patterns, for /proc/pressure parsing.
5. **rc-capture discipline**: never type `| tail` on a command whose exit code matters. The documented lesson exists; I still re-failed it.

## f) NEXT — up to 50, prioritized

**P0 — decide repair direction, then unblock the build:**
1. Check whether a parallel session is ALREADY repairing the wave (commits/lock edits newer than ~12:08, new docs/status files) — do not duplicate or race
2. `git log -p -- flake.lock` since `5f9740c4` — attribute each input bump to its committing session
3. Decide: fix-forward (repair all 11) vs targeted rollback (revert ONLY the broken input nodes to last-buildable revs; keep mr-sync `6c1d3f6d` + all script/doc work)
4. Locate vendorHash ownership per package (SystemNix `flake.nix` mkLarsPackages vs upstream `nix/packages.nix`) before touching any
5. cqrs-lint vendorHash refresh (probe got-hash at locked rev → paste upstream → push → re-lock; the proven protocol)
6. branching-flow vendorHash refresh
7. inboxclean vendorHash refresh
8. PMA vendorHash refresh
9. erraudit vendorHash refresh
10. go-structure-linter vendorHash refresh
11. signoz-frontend pnpm hash refresh
12. signoz-otel-collector vendorHash refresh
13. health-hub: upstream go mod tidy under prepared-source semantics (mr-sync `6c1d3f6d` recipe; `GOWORK=off`, never trust local go.work tidy)
14. papdashboard: upstream `publicDeps += [ "go-etag/entitytag" "go-etag/server" ]` (CV `ed8b92f` recipe); vendorHash likely ALSO stale after that
15. PDA: go-1.27 wiring — find which of the three wiring points (module-lambda `goPkg` / `goPkgAttr = "go_1_27"` / `mkPreparedSource` goPkg + `buildGoModule.override { go = go_1_27; }`) is missing at rev 73b7d32
16. Re-run preflight `--keep-going` → expect green or next domino
17. If rollback chosen: python round-trip lock edit reverting the 11 broken nodes (keep `original`/`locked` consistent), keep mr-sync node, re-preflight
**P0 — deploy + verify (once build is green):**
18. Confirm calm window (avg10 < 15 sustained + zero trips in trailing 60 min; poller needs the avg60 fix from e.4 first if reused)
19. `nix run .#deploy` — unpiped, rc captured directly
20. rc=12 → evidence snapshot → re-ask owner; NEVER force into active trips
21. Anchoring check: `readlink -f /nix/var/nix/profiles/system` == `readlink -f /run/current-system` (rc=14 discipline if mismatched)
22. `nix run .#post-deploy-check` — first live run of the 4 new theme checks
23. Live: `theme-catppuccin-auto.css` → 200 + `@import` body (fetch)
24. Live: landing `data-theme="catppuccin-auto"` (download + grep)
25. Live: `<title>` contains "Beyond coding. We forge."
26. Live: custom meta description ("Self-hosted git forge: code, mirrors, CI…")
27. Live: "Powered by Forgejo" ABSENT from landing body
28. Live: arc-green gone from picker (authed check — needs owner browser) + asset stays 404
29. forgejo-github-sync started by deploy.sh (`--no-block`) — check journal
30. hermes 0.21.4 healthy (rides this deploy — first toplevel with the bump)
31. Check lars' browser-stored per-user theme pref (may override DEFAULT_THEME client-side)
32. Watch tonight's btrbk window (23:00/23:30/23:45) for guard-churn starvation after today's trip budget burn
**P1 — storm/infra follow-ups:**
33. Queue the structural fix candidate: attic storage lives on the pool behind the ONE DAS USB link — every parallel build storm saturates it. Candidate: move attic storage to the Samsung hot tier (size it first)
34. Owner decision: cap concurrent agent sessions during guard-active windows (`system_crush_sessions` already emitted; alerting exists at >6)
35. Investigate go-deps-audit coverage gap (see e.3)
36. Poller v3: positional-field extraction + disk-busy corroboration; keep it as a reusable script under scripts/ instead of inline
**P2 — theme polish + leftovers:**
37. Chroma-exact Catppuccin syntax highlighting (`[ready]` row exists)
38. Logo/favicon phase 2 (decision row — owner taste)
39. Automated negative fixture for the theme-audit throw (negative-test-lints pattern)
40. VM test for theme tmpfiles + picker contract
41. nixpkgs deprecation-warning sweep (zsh `initExtra`, `stdenv.isLinux`, `'system'` rename — all fired in this build's eval)
42. Displaced-buildcache investigation (carried from yesterday's report)
43. cv :8098 metrics check (carried)
44. Confirm the "catalog subdomains vanish from derived DNS" eval warning is a known accepted state (it fired in this build)
45. llama-vlm soak-test warning fired in eval — confirm the module's checklist item is tracked (from the build's eval output)
46. /tmp scratch (`forgejo-landing-before.html`) — tmp-cleaner owns it; do not persist
47. This report file: daemon sweeps it (harness rule — no hand commit)
48. If rollback chosen: leave lock-state breadcrumbs in affected services' runbooks (doctrine)
49. Before the real deploy: re-read the deploy rc table (12 = pressure/trip-recency, 13 = lock contention, 14 = unanchored, 3 = new smoke failures)
50. After green deploy: consider a one-line "deployed live" note appended to the CHANGELOG theme entry (optional)

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Fix-forward or targeted rollback for the 11 broken FODs?** Fix-forward ≈ 8 upstream vendorHash refreshes + 3 semantic fixes (health-hub tidy, papdashboard publicDeps, PDA go-1.27 wiring) — likely hours, touches many upstream repos. Rollback = revert the 11 broken input nodes to last-buildable revs (fast, keeps mr-sync fix + theme + all script work; defers the wave to a proper session). My default if you say "go": check for a parallel repair session first, else rollback the 11 nodes and fix forward later — but this partially discards a parallel session's lock work, so I want your call.
2. **Is a parallel session currently owning the lock-wave repair?** I can see fresh daemon commits but cannot know intent or scope. If one is running, I'll stand down on items 1-17 entirely to avoid racing their lock edits (the lock-revert race from this morning is exactly this hazard).
3. **Deploy policy once the build is green** (carry-over from this morning, still unanswered): wait-for-calm vs force-with-evidence vs you run it in a personal quiet window. Today's evidence: storms are now multi-hour (12:10→17:00+ continuous), so "wait for calm" plausibly means tonight. And if you have opinions on the other two carry-overs — palette (keeping blue-primary `catppuccin-auto` as built unless you say otherwise) and logo phase 2 (holding) — those still gate nothing but taste.

---

**Runtime state left behind:** storm poller (bg shell 06A) still running, self-terminating after its 120th iteration (~17:10-17:30) — heartbeat-only, negligible cost. Preflight build killed at 16:5x after enumeration (store retains all completed derivations). Box: storm ongoing at last sample (16:57: avg10=14.15 but load=119), guard containing, zero freezes today.

**Awaiting instructions.**
