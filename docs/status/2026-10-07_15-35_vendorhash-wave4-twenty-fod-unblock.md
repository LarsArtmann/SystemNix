# Status: vendorHash wave-4 FOD unblock (20-FOD mass mismatch, 5 drops / 15 re-pins)

**Date:** 2026-10-07 ~15:04-16:00
**Trigger:** `nh` deploy build exited after 20 build failures at 15:04:16 — every FOD mismatch was a `*-go-modules` vendorHash FOD behind the 13:14 (`79a1014f`, 746-line lock diff) + 14:59 (`70fea115`) lock commits re-vendoring the module graph. Fourth vendorHash wave today (06:59 aftermath, 09:48 bank-sync, 12:17 wave3, this one).

## Timeline

1. 15:04 — deploy build fails: 20 `*-go-modules` FOD hash mismatches (signoz, signoz-otel-collector, visionreviewd, ledger-crm, health-hub, crush-daily, file-and-image-renamer, samber-linter, project-dependency-graph, projects-management-automation, meta, md-go-validator, library-policy, golangci-lint-auto-configure, go-auto-upgrade, go-humanize-linter, cv, erraudit, cqrs-lint, branching-flow).
2. ~15:10 — per the `--keep-going` FIRST rule: full toplevel re-enumeration captured all 20 `specified`/`got` pairs first-hand (`/tmp/toplevel-fix-20261007.log`).
3. ~15:15 — drop-protocol probes (docs/agents/nix-flakes.md): grep each upstream flake AT THE LOCKED REV for the got hash. Result: 5 upstream-already-correct (shim drops), 15 upstream-stale at locked rev AND HEAD (re-pins). Two non-failing module-surface shims (project-discovery-daemon, discordsync) also probed — both upstream-stale, shims stay.
4. ~15:30 — 20 surfaces fixed across 8 files: `lib/lars-packages.nix` (4 drops + 8 re-pins), `cv.nix` (drop), `visionreviewd.nix`, `health-dashboard.nix`, `projects-management-automation.nix` (re-pins), `overlays/linux.nix` (renamer re-pin + crush-daily vendorHash leg ADDED to the doCheck overlay), `crm.nix` (NEW consumer-side shim), `_signoz-packages.nix` (2 re-pins).
5. ~15:35 — verification toplevel build (`--keep-going`): 0 hash mismatches, 0 errors; all 20 FODs build green, packages compile.

## What was different this wave

- **The drop-protocol paid 5/20 (25%)** — branching-flow, go-auto-upgrade, golangci-lint-auto-configure, samber-linter, cv had upstream ALREADY carrying the got hash at the locked rev; their stale overrides were re-creating the exact drift the browser-history incident documented. Dropping beats re-pinning: one fewer surface to renew next wave.
- **Sweep feasibility is now CLASSIFIED** (upstream.md a7868a7-wave row): 8 of the 13 re-pinned repos follow root nixpkgs (overview class — upstream's own lock can never reproduce under our followed graph, so no upstream push will ever fix them; the fix is the un-follow decision row); 5 are non-followers an upstream push genuinely fixes (go-cqrs-lite/cqrs-lint, project-dependency-graph, projects-management-automation, file-and-image-renamer, crm).
- **crm had no prior shim surface** — its package is consumed directly in `crm.nix` (`inputs.crm.packages...default`); the wave added the first consumer-side override there.
- **Agents did NOT push upstream** — 12 upstream checkouts are stale at HEAD; per the queue policy ("agents never push; the owner push window gates it") all upstream fixes are captured in the [blocked:push] sweep row instead. crush-daily + file-and-image-renamer + go-cqrs-lite + library-policy + project-meta + project-dependency-graph checkouts are dirty (parallel-session owned) — untouched.

## Self-review verdict

- **a) FULLY DONE:** the deploy blocker itself — 20/20 FODs build green from the fixed tree; queue + library rows updated in the same session (drop-check row resolved 4/4, sweep row updated with the wave4 classification).
- **b) PARTIALLY DONE:** the wave record — this report + the sweep row carry the state, but the CHANGELOG row for the day's wave series (existing [ready] row) still lists 5 entries and now needs wave4 too.
- **c) NOT STARTED:** the 12 upstream pushes (owner window); the un-follow decision that would kill 8 of the 13 permanent re-pins.
- **d) TOTALLY FUCKED UP:** nothing new — but the wave cadence itself (4 in one day) is the systemic smell; each `nix flake update` re-vendors ~20 module graphs and re-breaks every rev-pinned shim. The un-follow decision + upstream sweep are the only exits.
- **e) WHAT WE SHOULD IMPROVE:** §11 catches stale FODs BEFORE deploy, but only when run; today's failure was caught by the deploy build itself (15:04), meaning the 13:14 lock wave landed without a §11 pass. Cheap fix: run `--section-11-only` right after any lock-wave commit, before the deploy attempt.

## f) Top things to get done next

1. Re-run `nix run .#deploy` on the fixed tree (all FODs proven; the deploy also re-runs pre-deploy gates incl. §11).
2. Owner push window: the 5 non-follower upstream hash pushes (sweep row) — drops 5 shims permanently.
3. Rule on the overview un-follow [decision] — extended to 8 repos by wave4's classification.
4. CHANGELOG row for the wave series (existing [ready] row, now covering wave4).

## Harvest record (TODO-system compliance)

- f1 (deploy) — deliberately NOT queued: it is the user's next command, and `nix run .#deploy` is a single existing app; queueing "run the deploy" adds no dispatch value.
- f2 + f3 — live in the existing [blocked:push] sweep row + [decision] un-follow row (docs/todo/upstream.md, updated this session with the wave4 classification; blocked rows are deliberately not harvested into the queue).
- f4 — already an open [ready] queue row (CHANGELOG wave-series row); wave4 folded into its scope.
- Drop-check queue row marked [x] with outcome (4/4 probed, 0 droppable) — pruned to CHANGELOG at the next pass.
