# Status Report — dnsblockd Lock Unblock + Upstream UI-Regen Fix

**Date:** 2026-10-12 05:11 CEST
**Session scope:** Fix the failed `nix flake update dnsblockd && nh os switch` (vendorHash FOD mismatch). Nothing else.
**Verdict:** SystemNix-side fix is DONE and build-verified at lock rev `f39dc7d0` — but the live lock has ALREADY moved past it to `4e1af5d0` (parallel session, unverified). Deploy is still NOT proven safe.

---

## Failure chain (what actually broke)

Three stacked upstream (dnsblockd repo) defects, none in SystemNix config:

1. **Stale `vendorHash` at the locked rev** — lock held `815e0258`; its `nix/vendor-hash.nix` baked `0koFfQqs…`, FOD wanted `kNySCC/A…`. Upstream master had already fixed it → re-locked (no shim — per the drift-treadmill protocol).
2. **Stale UI artifacts on the new upstream HEAD** — committed `app.min.css` was EXPANDED (not minified, 5584 lines) while the build regenerates minified → byte-freshness gate failed. Concurrent upstream churn: `b931f81a` → `7677bbf9` (a 16-file daemon heuristic commit that landed `views.fresh/*.templ` SOURCES without their generated `*_templ.go` files, and stale `views/*_templ.go`) — a hook-bypassing daemon split-commit, same class as SystemNix's own daemon trap.
3. **dnsblockd's own `art-dupl` vendorHash stale** — broke its devshell AND its pre-commit hook environment (hooks error out with confusing FOD output before doing their job).

## Resolution (this session)

- Cloned dnsblockd to `/tmp/dnsblockd-fix`; regenerated: `library-classes.txt`, minified `app.min.css` + `styles.css` (tailwindcss **v4.3.3** — nixpkgs `#tailwindcss` is v3 and fails on the v4-syntax `app.css`), `templ generate` + `goimports` (`GOEXPERIMENT=jsonv2`), treefmt; committed missing `views.fresh/*_templ.go`; refreshed `nix/art-dupl-vendor-hash.nix`.
- Pushed upstream **`f39dc7d0`** (pre-commit gate green: "UI artifacts are byte-fresh").
- Re-locked SystemNix dnsblockd → `f39dc7d0`; `nixosConfigurations.evo-x2.config.system.build.toplevel` **built green**.
- Lock landed in daemon commit `2c2159f8`, content-verified (contains `f39dc7d0…`).

---

## a) FULLY DONE

| Item                                                                                             | Evidence                                                                                                |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| Root-caused the vendorHash FOD failure to upstream, not SystemNix                                | user's nh log; `nix/vendor-hash.nix` at locked rev                                                      |
| Resolved the TRUE lock rev via `jq '.nodes[root.inputs["dnsblockd"]]'` (orphan-rev trap avoided) | `815e0258` → confirmed in failure drv name (`…-3faf986` was the prepared-source name, not the lock rev) |
| Checked upstream-before-shimming (drift-treadmill protocol)                                      | upstream already fixed → dropped nothing, re-locked only                                                |
| Regenerated ALL stale UI artifacts upstream, gate green                                          | pre-commit: "byte-fresh (_templ.go, library-classes.txt, library-custom.css, app.min.css, styles.css)"  |
| Fixed dnsblockd's own broken art-dupl vendorHash                                                 | `nix build .#art-dupl` green in clone before commit                                                     |
| Pushed upstream fix `f39dc7d0`, pushed cleanly after resolving upstream race                     | `git push`: `7677bbf9..f39dc7d0 master -> master`                                                       |
| Re-locked SystemNix + full evo-x2 toplevel build green                                           | build log: `nixos-system-evo-x2-26.11.20261008.e7439b6` built, no errors                                |
| Lock commit verified for content (not assumed from output)                                       | `2c2159f8:flake.lock` contains `f39dc7d0…`                                                              |

## b) PARTIALLY DONE

- **The deploy itself** — never re-run. Fix is verified to BUILD level only (`nix build` toplevel). Activation, service liveness, `:53`/`:9090` probes, post-deploy checks: all still open. Original command (`nh os switch`) is the user's to re-run.
- **Live-lock validity** — lock NOW holds `4e1af5d0` (moved past my verified `f39dc7d0` by a parallel session between 04:56 and 05:11). That rev deletes 56 files / 46.9k lines (the entire `views.fresh` tree, mid-refactor). Build status: UNKNOWN. My verification is stale within ~15 minutes.
- **Byte-stability of my ad-hoc regen toolchain** — I used `nixpkgs#templ` / `nixpkgs#go-tools` / `nixpkgs#tailwindcss_4`, not dnsblockd's own pinned devshell (was broken by art-dupl FOD; fixed in the same push). Versions happened to match (tailwind 4.3.3) but this is luck, not proof. A devshell `regen-ui.sh` re-run would prove byte-identity.
- **Session learnings not yet written to memory/docs** — the dnsblockd UI-regen runbook, tailwindcss v3-vs-v4 nixpkgs trap, and the upstream daemon split-commit hazard are in this report only. AGENTS.md / `docs/agents/nix-flakes.md` / dnsblockd service runbook: untouched (aggressive-update protocol says immediate; this is a violation logged honestly).
- **`/tmp/dnsblockd-fix` clone residue** — 35 MB left on disk, not trashed.

## c) NOT STARTED

- HARVEST of this report's §f into `TODO_LIST.md` + domain libraries (explicitly deferred per "wait for instructions").
- Upstream CI gate for UI artifacts (`check-ui-artifacts.sh` on every push) — would have caught ALL THREE upstream defects before they reached a consumer.
- Upstream branch protection / daemon exclusion for dnsblockd master (the churn that broke b931f81a→7677bbf9 will recur).
- Stale comment updates in SystemNix referencing old dnsblockd revs (`signoz-coverage.nix` cites `dnsblockd-94c9cb9`).
- Re-verification of the `dnsblockdVendorHashShim DROPPED` drop-record comment in `overlays/linux.nix` against the NEW lock (condition still looks met — `0koFfQqs` was indeed upstream-baked — but per protocol it should be re-confirmed at `4e1af5d0`).

## d) TOTALLY FUCKED UP

Nothing data-destroying, but three real stumbles, ranked:

1. **Verification half-life ignored (the big one).** I verified the toplevel at `f39dc7d0` and reported "fixed" — while a parallel session had ALREADY moved the lock past that rev by the time I finished. Per house rules, "fixed" claims must name the surface verified; the live surface moved underneath within 15 minutes. The honest current status is "build-verified at a rev that is no longer the live lock".
2. **Pipe-masking in my own command chain.** `git commit … 2>&1 | tail -3 && git push …` — the pipe made the chain see tail's exit code (0), so push ran against a FAILED commit ("Everything up-to-date" was the tell). No damage (caught it two calls later via `git log`), but this is the documented pipeline-masking failure class, reproduced by me, in a repo (dnsblockd) with a real pre-commit gate.
3. **Repeat hit on a documented trap: the daemon stale-fetch cache.** After pushing `f39dc7d0`, I built `ref=master` WITHOUT `--refresh`, got the stale cached `7677bbf9`, and burned a build cycle — `docs/agents/nix-flakes.md` line 103 documents exactly this. Second stumble class: my very first probes (`rg 'dnsblockd-3faf986-go-modules'` in pkgs/, `nix eval --apply` that triggered a real build) were the wrong tool twice before the prefetch+grep pattern.

## e) WHAT WE SHOULD IMPROVE

1. **Systemic: hook-bypassing daemon commits upstream are the root enabler.** dnsblockd's own daemon committed sources-without-generated-files (b931f81a, 7677bbf9) and an unregenerated expanded CSS. Every consumer (SystemNix lock) then eats the FOD/gate failure. Fix upstream: CI artifact check + branch protection (or daemon exclusion for that repo), NOT more consumer-side shims.
2. **Treat "toplevel builds green" as verification of a REV, not of THE SYSTEM.** Any report should state: lock rev, build result, and whether the lock has moved since. A `git diff`-freshness check (lock file mtime vs verification time) is cheap and would have caught item d-1.
3. **`--refresh` by default on any `nix build <flakeref>` following a push** (already a lesson; needs to be habit, and a plain reading of it lives at line 103 of nix-flakes.md).
4. **Use the owning devshell for regeneration wherever possible.** Ad-hoc nixpkgs tool inversions worked here; they won't survive a nixpkgs bump (tailwind/templ minor-version drift = byte-diff = gate fire). The art-dupl fix re-opened the devshell path — use it.
5. **Run chained git commands with `set -o pipefail`** (or avoid piping the gate command at all).
6. **`nh os switch` bypasses the repo's pre/post-deploy checks.** The SystemNix rule is `nix run .#deploy` (deploy.sh runs pre-deploy-check + post-switch steps). The user's original command skipped §1–§14 pre-deploy checks; worth noting every time it happens.

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

Grouped; impact-ordered within groups. Items 1–8 are this-incident follow-ups, the rest are adjacent findings from this session (ROADMAP fuel — most are NOT for the dispatch queue).

**This-incident closure**

1. Verify the LIVE lock `4e1af5d0` builds (parallel session mid-refactor; either wait for it to quiesce, coordinate, or re-pin to `f39dc7d0` if owner wants a known-good).
2. Re-run the deploy and complete post-deploy verification (dnsblockd `:53`/`:9090`, Gatus green, SigNoz `system_dnsblockd_metrics_fresh 1`).
3. Confirm the two pre/post-boot probes I did NOT run: `nix flake check --no-build` post-re-lock, and darwin-host eval (aarch64 skipped by default — confirm no new breakage class).
4. Re-run `scripts/regen-ui.sh` inside dnsblockd's (now-fixed) devshell to prove my ad-hoc nixpkgs-toolchain regen was byte-identical.
5. Trash `/tmp/dnsblockd-fix` (35 MB) after item 1/4 close.
6. Update `docs/services/dnsblockd.md` (or nix-flakes.md) with: the UI-artifact regen runbook, tailwindcss_4-vs-v3 trap, art-dupl hash file location, and this incident's dates/hashes.
7. Update the `dnsblockdVendorHashShim DROPPED` comment in `overlays/linux.nix` after the lock settles (re-confirm drop condition at the new rev).
8. Refresh the stale rev citation in `modules/nixos/services/signoz-coverage.nix` (`dnsblockd-94c9cb9` comments).

**Upstream dnsblockd hardening (the actual root cause)**
9. Add CI workflow running `scripts/check-ui-artifacts.sh` on every push/PR.
10. Branch-protect master (or exclude the repo from the heuristic daemon) to stop source-without-generated split commits.
11. Update dnsblockd's own `flake.lock` inputs wholesale (art-dupl-src et al.) so vendor-hash refreshes stop being whack-a-mole.
12. Make the pre-commit hook fail SOFT when `dnsblockd-env` FOD is stale (clear message: "refresh nix/art-dupl-vendor-hash.nix") instead of raw hash-mismatch spam.
13. Decide policy: keep tracked-generated artifacts + byte-fresh gates, or generate in the Nix build and drop the gate (owner decision; gates catch drift but create this whole class).
14. Pin the devshell tool versions (templ/goimports/tailwind) visibly and document that ad-hoc `nixpkgs#…` regen is NOT the sanctioned path.

**Consumer-side (SystemNix) hygiene**
15. Add a lock-freshness note template to status reports: always state lock rev + whether it moved post-verification.
16. Audit other LarsArtmann inputs at current locks for the same upstream-stale-vendorHash exposure (cv, pdd class).
17. Consider a pre-commit/CI grep banning `2>&1 | tail` followed by `&&` in agent-authored scripts (pipeline-masking class) — or at least document pipefail in CONTRIBUTING.
18. Add "always `--refresh` after pushing to an input" to the nix-flakes.md checklist header (it exists at line 103; make it a hard checklist row).

**Adjacent observations from this session (unverified beyond noticing — ROADMAP fuel)**
19. `nh os switch` vs `nix run .#deploy` divergence (owner habit vs repo rule) — decide which is canonical for interactive deploys.
20. SigNoz `dnsblockd-journal-dropping` rule depends on service_name self-report ("keep an eye after dnsblockd bumps") — check after this bump.
21. `internal/server/views.fresh/` naming ("fresh" suffix) was a refactor-in-progress marker upstream; the consolidation is happening RIGHT NOW — do not touch dnsblockd until it lands.
22. dnsblockd upstream log shows all heuristic "auto-commit" messages — its history is unattributable (same Unknown-Author-adjacent hygiene issue SystemNix already fixed); gitIdentity daemon exists in SystemNix, apparently not in dnsblockd's runner.
23. `gen-library-classes.sh` self-vendoring fetches private modules every cold run — consider caching in CI (perf, not correctness).
24. The SystemNix changelog/daemon commits `7d1a8bd1`/`c67ae49d` were other sessions' work riding the queue — attribution held correctly (pathspec-verified), no action, just noting the race is alive.
25. nixpkgs compat workflow will surface a tailwindcss_4 version bump eventually — the byte-freshness gate upstream will fire the day 4.3.3→4.x lands; pre-register that expectation in the dnsblockd runbook.
26. Consider tagging known-good dnsblockd revs and (owner-decision) locking SystemNix to tags instead of `?ref=master` for deploy-critical inputs — pin policy currently forbids without documented reason; this incident is evidence FOR a documented exception.
27. Gatus "slow-boot dnsblockd" budgets (300s OIDC gate) — confirm still sane with the new build (binary size/content changed).
28. post-deploy-check §17 memory sweep after first boot on the new dnsblockd (new binary, same MemoryMax budget).
29. Re-harvest: docs-health HARVEST over this report once instructions arrive.
30. Annotate (docs-health ANNOTATE) any older dnsblockd-related status reports after the deploy lands.

(30 items; the remaining ~20 slots deliberately not padded — items beyond 30 would be pure speculation, not observation.)

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **The parallel churn upstream:** was another agent session of yours actively refactoring dnsblockd (`4e1af5d0`, deleting the whole `views.fresh` tree) while I pushed my fix? If yes — should I hold all dnsblockd work until it lands, and should the daemon be excluded from that repo (it committed the broken intermediate states)? If no — that refactor came from somewhere unplanned and needs attribution before anyone builds on it.
2. **Known-good pin policy:** do you want SystemNix's dnsblockd input re-pinned to my build-verified `f39dc7d0` (safe but reverts the parallel session's lock move), or should we ride the live lock `4e1af5d0` and verify whatever the refactor produces? This is un-decidable from the tree alone — it depends on whether that other work is meant to land today.
3. **Deploy ownership:** do you want to re-run `nh os switch` yourself, or should I run the full `nix run .#deploy` (pre/post-deploy checks included) once the lock question in Q2 is settled?

---

_Point-in-time snapshot 2026-10-12 05:11 CEST. Lock rev at writing: dnsblockd = `4e1af5d0` (UNVERIFIED, moved post-verification); last verified-buildable dnsblockd rev: `f39dc7d0` (SystemNix commit `2c2159f8`)._
