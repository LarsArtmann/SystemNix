# Status Report: Deploy-Round-2 Prep — tq Pin Rescue, BuildFlow Push, Smoke-Check Truth-Telling

**Date:** 2026-09-11 02:21 CEST
**Session scope:** continuation of "fix deploy" — executed on the three owner answers (deploy now / BuildFlow push authorized / SSO-only posture), then diagnosed and repaired everything the first deploy exposed. Covers 01:38 → 02:21 CEST; supersedes the deploy-state portions of the 01:38 report (its sections a–f are point-in-time; anything not restated here still stands).
**Format note:** User explicitly requested `.md`; status-report skill's HTML default overridden for this report (flagged, not propagated).

---

## Executive Summary

The first deploy (01:39–01:49) **activated the config but exit-4'd** — no profile generation landed (the 2026-09-09 anchoring class: a reboot would revert everything). This session root-caused the exit-4 and all ten smoke failures, fixed four things, pushed one upstream commit, and got the tree to a fully-verified re-deployable state.

**The exit-4 chain:** the deploy output's `tq-agent-pool.service` failure was real — a parallel session added `task-closeout` to the tq pool.conf, but the locked tq rev (`ca8a2f4`) predates that upstream feature → "unknown key" → exit 1 → restart loop → start-limit-hit → `switch-to-configuration` exit 4 → **profile bump skipped**. Fixed by re-pinning tq to `200213a` (newest rev with BOTH the feature and an in-sync vendorHash — master HEAD is also stale-hash broken upstream).

**The Miniflux smoke FAIL was my own check's bug:** miniflux 2.3.3 serves the sign-in page at `/`; `/login` is the POST target and 405s on GET. The actual deployed OIDC wiring is **live and correct** (verified: `/` renders `<a href="/oauth2/oidc/redirect">` with "Pocket ID"). Check fixed.

**BuildFlow:** upstream vendorHash fix committed and **pushed** (`d082b7e70`, per owner authorization); SystemNix re-locked and tracking master again.

**New real signal:** the deploy's own builds consumed the last root chunk headroom — `nix-build-cleanup`'s BTRFS gc-guard correctly aborted at 0% unalloc (4.8 GB < 5 GiB floor). The 2026-08-24 crash-#3 runbook is printed and waiting for a quiet sudo window.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | **BuildFlow upstream vendorHash fix pushed** — `vendorHash.nix` → `sha256-0NQwe…`, commit `d082b7e70` on `LarsArtmann/BuildFlow` master | `git push` output: `b693c505d..d082b7e70 master -> master`; commit body documents the repin-stale-hash cause and the downstream interim pin |
| 2 | **SystemNix buildflow re-locked to healthy master** (`d082b7e70`) — interim `56c755f0e` pin posture dropped | `nix flake lock --update-input buildflow` output; lock node rev verified; `.#buildflow` builds green (`/nix/store/cxi13v39…-buildflow-d082b7e`) |
| 3 | **tq-agent-pool exit-4 root-caused and fixed** — `task-closeout` (parallel session, module line 97) vs pinned rev `ca8a2f4` lacking it | Journal: `unknown key "task-closeout"` ×6 → start-limit-hit; `git grep` at `ca8a2f4` empty, at HEAD present |
| 4 | **tq pin → `200213a0be`** — the ONLY rev satisfying both constraints: contains `task-closeout` (descendant of `142b7b9` which introduced it) AND has a committed vendorHash in sync (probed lock-free: FOD green; HEAD `3426afc` fails `specified /rKFWq got NQi6Xp`) | `.#tq` builds: `/nix/store/hm7fsy2…-go-taskqueue-0.2.0`; lock node clean (`rev`, no `dirtyRev`), now `github:` type so **CI can fetch tq again** (was git+file, CI-dark) |
| 5 | **Miniflux smoke check URL bug fixed** — probes `/` (serves the sign-in page) instead of `/login` (POST-only, GET=405, live-verified 405 + 19-byte body) | `bash -n` clean; comment documents the 405 fact with date; **the deployed Gatus check and VM test were already correct** (both hit `/` — verified, not assumed) |
| 6 | **`services.miniflux.disableLocalAuth` option shipped** — SSO-only posture, owner's Q3 answer | Evals: default `false`; env attrset has NO `DISABLE_LOCAL_AUTH` when false, `OAUTH2_PROVIDER=oidc` present; option description encodes the go-live gate + break-glass; refused without OIDC (impossible-state avoidance) |
| 7 | **Live OIDC verification without a browser** — unit file inspected (all `OAUTH2_*` env vars present, `LoadCredential` bound — the unit starting at all proves the secret file exists), journal shows clean start (migrations 132, admin `lars` created, second start skips), page fetched: sign-in page with OIDC route + provider name | journalctl + python urllib probes of `127.0.0.1:8101` |
| 8 | **BTRFS gc-guard abort diagnosed as CORRECT fail-closed behavior** — not a regression; the deploy's builds consumed root chunk-unalloc from 10% → 0% (4.8 GB < 5 GiB floor) | journalctl: `BTRFS GUARD: ABORT` with the full crash-#3 runbook printed |
| 9 | **Full re-verification sweep**: evo-x2 toplevel builds (`/nix/store/56c1q7cg…`), `.#buildflow` + `.#tq` green, `nix flake check --no-build` clean, `nix fmt --ci` 0 changed, disableLocalAuth evals verified | Build outputs + command results this session |
| 10 | **docs/services/miniflux.md updated** — login-page-at-`/` fact (with the 405 evidence), SSO-only posture section with go-live gate + break-glass | File edited this session |

---

## b) PARTIALLY DONE

| # | Item | Works now | Remains open | Blocker | Effort |
|---|------|-----------|--------------|---------|--------|
| 1 | **The deploy (round 2)** | All inputs fixed, toplevel built, tq crash cause eliminated → the re-run should activate cleanly AND complete the skipped profile generation (fixing the anchoring debt from round 1) | The switch itself + post-switch verification | sudo (user-run) | S |
| 2 | **SSO-only posture** | Option shipped, documented, gated off | Flip `disableLocalAuth = true` — owner chose SSO-only, but flipping in the SAME deploy as the first-ever live OIDC login risks total lockout (paperless locked-out-middle doctrine). Flip = 1 line + redeploy after ONE proven login at `rss.home.lan` | Owner's first live login | S |
| 3 | **AGENTS.md currency** — I CREATED docs drift this session: the tq section still says "Flake input is git+file INTERIM … ca8a2f4", now false (frozen github `200213a`); the Miniflux section lacks the login-at-`/` fact and the disableLocalAuth option | — | AGENTS.md edits | Report-then-wait; queued as task #9 in (f) | S |
| 4 | **Subtree-blast-radius proof** | Toplevel closure (buildflow + tq both in it) builds green | `nix build .#quick-go` for the full LarsArtmann Go set — the lock moved TWICE more (buildflow subtree, tq subtree); non-toplevel consumers (devshell-only lars packages) unproven | Effort (M, mostly cached) | M |
| 5 | **Smoke-failure triage from deploy round 1** | Diagnosed: flm :52625 + llama 503s = the documented corpse class (reboot-only fix); nix-build-cleanup = correct guard abort | CV browser-render smoke FAIL (new vs baseline — possibly transient under deploy load) and bank-sync `sync_errors_total > 0` (SCA class or transient) NOT investigated | Owner priority call (asked in g/Q3) | S–M |

---

## c) NOT STARTED

| # | Item | Why | Wanted? |
|---|------|-----|---------|
| 1 | Live SSO login test at `rss.home.lan` (retires the OAUTH2_REDIRECT_URL derivation risk — still the biggest unverified Miniflux item) | Needs the re-deploy + a human browser session | Yes — gates the SSO-only flip |
| 2 | BTRFS chunk-headroom recovery runbook (rm reserve → quiet → bounded balance → re-provision) | sudo + quiet-window decision; machine was mid-deploy churn | Yes — unalloc at 0% is the 2026-08-24 crash-#3 precondition |
| 3 | The owed reboot (clears flm :52626 corpse, llama D-state pile, lands everything in a clean generation; pre-reboot-check green at 18/0) | Owner timing | Yes |
| 4 | TODO_LIST HARVEST from both of today's status reports | Report-then-wait | Yes |
| 5 | CI green check for the new lock (github:-type tq input is NEW — first CI run that can actually fetch it; the CI-dark class demands an explicit look) | No push of SystemNix yet this session | Yes |
| 6 | Upstream go-taskqueue vendorHash refresh (HEAD `3426afc` is broken; then flip the pin back to `?ref=master`) | Needs push authorization (g/Q2) | Yes |
| 7 | `post-deploy-check.sh` regression-diff tooling bug: `comm: file 1 is not in sorted order` — the fail-set baseline diff runs comm on unsorted input (cosmetic but the regression signal could mis-diff) | Spotted in deploy output, not fixed | Yes |
| 8 | Miniflux restore/rotation drills, OPML onboarding, runbook verification pass | Post-go-live | Medium |
| 9 | Cross-repo audit for the buildflow/tq class (locked input whose lock subtree violates its own go.mod requirements / stale vendorHash on HEAD) | Larger sweep | [R] ROADMAP |

---

## d) TOTALLY FUCKED UP

1. **I violated my own probe-before-lock discipline on tq.** For buildflow I probed the FOD lock-free BEFORE moving the lock. For the tq flip to `github:?ref=master` I re-locked directly — and landed the lock on broken HEAD (`3426afc`, stale vendorHash), discovering it only when `.#tq` failed. Cost: one wasted build cycle, one extra lock move, and a window where the tree was re-deployable with a broken tq. The `200213a` rescue recovered fully, but the discipline exists precisely to prevent that window.
2. **I shipped a smoke check with an unverified URL.** I verified the OIDC route string against the deployed binary's embedded template — but never verified the ROUTE-TO-URL mapping (`/login` POST-only). The deploy then produced a false "Miniflux OIDC not picked up" FAIL that cost attention during an already-messy deploy. The embarrassing part: the VM test (which passed) fetches `/` — cross-checking my smoke against the VM test's proven probes would have caught it in seconds.
3. **I created AGENTS.md docs drift myself.** The tq section's "git+file INTERIM, flip after push" guidance is now stale (flip happened, but to a frozen rev, not `?ref=master`), and the Miniflux section predates today's live facts. A future session reading AGENTS.md gets the old story. (Queued as (f)#9 — not silently ignored.)
4. **The deploy consumed the machine's last BTRFS chunk headroom.** Round-1's builds drove root unalloc from 10% → 0%, tripping the gc-guard fail-closed. Not a bug — but the pre-deploy gate reported 97% root (22G free) as a ✓ without a chunk-level unalloc check, so the deploy walked into the 2026-08-24 crash-#3 precondition with no gate. The system got lucky the guard exists. (Fix in (e)#3.)
5. **Round-1 deploy left the system UNANCHORED for ~40 minutes** (config activated, profile generation skipped). Any crash/reboot in that window would have silently reverted miniflux + the buildflow fix. This is the documented exit-4 class working exactly as documented — but it means the tree MUST be re-deployed ASAP; every hour of delay is exposure.

---

## e) WHAT WE SHOULD IMPROVE

1. **Probe-before-lock, no exceptions — including "trivial" flips.** The tq `?ref=master` flip skipped the FOD probe because "the push landed, master is fine." Master had a stale hash. Rule: ANY lock move for a Go-flake input gets a lock-free `goModules` probe first, full stop. (Codify in the `scripts/relock-input-at-rev.sh` tool from the previous report — it should take `--verify` and refuse to move the lock without a green probe.)
2. **New smoke checks must cite a VM-test-proven probe or a live response capture.** My `/login` check was written from the binary's route strings, not from a rendered response. Cheap fix: any new post-deploy probe gets validated against the VM test's URLs OR a one-off live capture BEFORE landing. The buildflow chain cost a deploy cycle; the smoke URL cost another.
3. **Pre-deploy gate needs a chunk-headroom awareness check.** §8 checked filesystem free space (22G ✓) while chunk-unalloc was 10% heading to 0% under the deploy's own build load. The gc-guard floor is 5 GiB; deploys demonstrably eat ≥5 GiB of unalloc. Suggestion: pre-deploy-check reads the same unalloc figure and WARNs (or requires `DEPLOY_FORCE_HEADROOM=1`) below ~8 GiB.
4. **AGENTS.md updates in the same change-set as input flips.** I flipped the tq input and left the tq section describing the old world. Rule: an input-posture change isn't done until its AGENTS.md paragraph matches reality.
5. **Fix the `comm` unsorted-input bug in the smoke regression diff** — the baseline comparison (the deploy's actual regression signal) currently prints comm warnings; a silent mis-diff here would be a phantom-green/phantom-red generator.
6. **Keep the upstream-CI push momentum:** BuildFlow got its vendorHash fix + needs a build-its-own-flake CI job; go-taskqueue needs the same (its HEAD is broken right now — the frozen pin is load-bearing). Every LarsArtmann flake without a self-build CI job is one auto-commit batch away from this session's tq situation.

---

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

Sorted by impact; carries over the still-open items from the 01:38 report where relevant. **HARVEST input** — [R] = ROADMAP-fuel.

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Re-run `nix run .#deploy` (round 2) — completes anchoring, lands tq fix + buildflow | Critical | S | Feature |
| 2 | After switch: verify `readlink /run/current-system` == newest numbered profile AND `system-764` advanced (the round-1 anchoring debt MUST clear) | Critical | S | Quality |
| 3 | Confirm `tq-agent-pool` starts and stays active (the exit-4 cause is gone; journal must show pool accepting config) | Critical | S | Quality |
| 4 | Re-run `nix run .#post-deploy-check` — Miniflux section should now PASS (sign-in at `/`), regression baseline re-diffed | Critical | S | Quality |
| 5 | Live SSO login at `rss.home.lan` (human, browser) — retires the OAUTH2_REDIRECT_URL risk | High | S | Feature |
| 6 | After #5: flip `services.miniflux.disableLocalAuth = true` + redeploy (owner's Q3 choice) | Medium | S | Feature |
| 7 | BTRFS chunk-headroom recovery: rm `/btrfs-emergency-reserve` → quiet check → `ionice -c 3 btrfs balance start -dusage=5 -dlimit=2 /` → re-provision reserve (runbook in the nix-build-cleanup journal) | High | M | Bug |
| 8 | The owed reboot (clears flm corpse + llama D-state pile + lands clean generation); pre-reboot-check re-run first | High | S | Feature |
| 9 | AGENTS.md updates: tq section (frozen `200213a` pin, why, flip-back trigger), Miniflux section (login-at-`/`, disableLocalAuth option, live facts) | High | S | Documentation |
| 10 | `nix build .#quick-go` — prove the full Go set against both new lock subtrees (b#4) | High | M | Quality |
| 11 | Check CI green on next SystemNix push — tq is github:-type for the first time; confirm NIX_GITHUB_RO_TOKEN fetches it (CI-dark class) | High | S | Quality |
| 12 | Upstream go-taskqueue: refresh vendorHash at HEAD (`NQi6Xp…`), commit+push (needs g/Q2), then flip the pin back to `?ref=master` | High | S | Bug |
| 13 | Investigate CV browser-render smoke FAIL (new-vs-baseline; `/tmp/.smoke-cv-render.log`) — transient under deploy load or real regression? | Medium | S | Bug |
| 14 | Investigate bank-sync `sync_errors_total > 0` (SCA statement-gate class vs transient; journal per AGENTS.md pattern) | Medium | S | Bug |
| 15 | Fix the smoke regression-diff `comm` unsorted-input bug (e#5) | Medium | S | Bug |
| 16 | Pre-deploy chunk-headroom gate (e#3): WARN/block below ~8 GiB root unalloc | High | S | Quality |
| 17 | Add build-own-flake CI to BuildFlow AND go-taskqueue (e#6) | High | M | Quality |
| 18 | HARVEST both reports into TODO_LIST/ROADMAP (docs-health) | Medium | S | Documentation |
| 19 | Verify miniflux-backup chain post-deploy: pool dir postgres-owned, PGDMP dump, backup-coordination green | High | S | Quality |
| 20 | Interactive sops decrypt round-trip on `miniflux.yaml` (still never verified; needs user sudo) | Medium | S | Quality |
| 21 | Confirm deploy.sh's miniflux restart block + provisioner restarts behaved in round 1 (they ran — verify the LoadCredential re-bind worked, i.e. OIDC still green after the restart cycle) | Medium | S | Quality |
| 22 | Verify `miniflux-dbsetup` + `miniflux-wait-oidc` units converged clean (new units in the deploy diff; journal check) | Medium | S | Quality |
| 23 | Gatus "Miniflux" + "Miniflux Login Renders" green in deployed config after round 2 | Medium | S | Quality |
| 24 | Homepage Media tile renders + `rss.home.lan` DNS resolves via dnsblockd | Low | S | Quality |
| 25 | Confirm miniflux DB landed in postgres (peer auth, `miniflux` database) and survives a unit restart | Medium | S | Quality |
| 26 | OAUTH2_REDIRECT_URL: if #5 succeeds, record the verified fact in the runbook; if it fails, capture the Pocket-ID-side error and fix the registered callback | High | S | Quality |
| 27 | Decide miniflux reader-API requirement (native-only vs GReader-class) — still open from Q3 round 1 | Medium | S | Decision |
| 28 | Record the tq pin posture in docs/services/tq.md (round-9 runbook + the 200213a story) | Low | S | Documentation |
| 29 | `relock-input-at-rev.sh` script with mandatory `--verify` FOD probe (e#1 codification) | Medium | M | Quality |
| 30 | Smoke-check authoring rule into CONTRIBUTING.md: cite VM-test-proven URL or live capture (e#2) | Medium | S | Documentation |
| 31 | Verify the parallel session's kernel-hardening/boot changes deploy green together in round 2 (shared activation, shared anchoring debt) | Medium | S | Quality |
| 32 | Miniflux restore drill (dump → scratch PG restore) | Low | M | Quality |
| 33 | Miniflux secret-rotation drill; document admin-password break-glass removal steps for the SSO-only era | Low | S | Quality |
| 34 | OPML import + reader client onboarding (user) | Low | S | Feature |
| 35 | Confirm miniflux backup joins the offsite/Google-Drive backup review cadence | Low | S | Quality |
| 36 | Document the accepted FreshRSS-feature gap (XPath scraping) in the runbook | Low | S | Documentation |
| 37 | [R] Lock-health guard: assert locked rev exists on origin for `github:` inputs; detect stale-vendorHash HEADs before locking | Medium | M | Quality |
| 38 | [R] Cross-repo locked-input-vs-go.mod audit script (the buildflow/tq class, ecosystem-wide) | Medium | L | Quality |
| 39 | Triage the 19 pre-deploy warnings carried from round 1 (vendorHash-status check blind spots, stale sandboxes) | Low | M | Cleanup |
| 40 | Post-reboot: verify `/run/booted-system` == `/run/current-system` (doctrine) | Medium | S | Quality |
| 41 | Post-reboot: confirm flm socket serves + llama 8848/8849 health green (corpse class should be gone) | High | S | Quality |
| 42 | Confirm the flm memory-emergency-guard restore-cap interaction is gone post-reboot (P1 corpse-aware-restore skip remains a candidate) | Low | S | Cleanup |
| 43 | Keep `tests/test-miniflux.nix` green through nixpkgs bumps (it now pins the correct `/` probe — keep it that way) | Low | S | Quality |
| 44 | Note in miniflux.md: the smoke section's stable FAIL names (baselining depends on them) | Low | S | Documentation |
| 45 | Commit hygiene: the tree now carries 6+ modified files across 3 workstreams (lock fixes, miniflux, docs) — pathspec-commit or review the daemon batch before push | Medium | S | Housekeeping |
| 46 | Verify `miniflux.yaml` values decrypt correctly BEFORE relying on admin break-glass (ties to #20) | Medium | S | Quality |
| 47 | Consider a miniflux feed-refresh IO tier review once feeds are loaded (QLC doctrine; default service tier probably fine) | Low | S | Quality |
| 48 | After SSO-only flip: verify the smoke check still passes (asserts OIDC route — should hold; the password form disappearing must not break it) | Low | S | Quality |
| 49 | Docs-health ANNOTATE: mark the 01:38 report's "blocked" items resolved after round 2 lands | Low | S | Documentation |
| 50 | Close the loop on this session's open questions (g) — answers route tasks #7, #12, #13/#14 | — | — | Decision |

---

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

Asked via the interactive prompt after this report:

1. **Sequencing of the BTRFS recovery vs the reboot** — unalloc is at 0% NOW; the runbook wants a quiet machine, the reboot wants to happen anyway. Before (recover headroom, then reboot clean) or after (reboot first, recover on the fresh boot)?
2. **go-taskqueue push authorization** — same as BuildFlow: may I commit + push the vendorHash refresh to go-taskqueue master so the tq pin can go back to tracking `?ref=master`?
3. **Priority of the two unexplained round-1 smoke failures** — investigate CV-render + bank-sync now, or defer both to after the reboot (they may be deploy-load transients that vanish on a clean boot)?

---

## Current Tree State (02:21 CEST)

UPDATE 02:24: the auto-commit daemon batched ALL of the below into three commits while this report was written — `c0fe99bf`, `62906d4c`, `b07174e8` (flake.lock + flake.nix in the last). Working tree now carries ONLY the two staged status reports. The commits are NOT pushed; the next push carries the daemon batch + this session's SystemNix work mixed together — mind the pathspec-commit rule (AGENTS.md Critical Rules) when anything else is staged.

Session changes (all committed as of 02:24):
```
flake.lock                              # buildflow → d082b7e70, go-taskqueue → 200213a (github:)
flake.nix                               # tq input posture + comments
modules/nixos/services/miniflux.nix     # disableLocalAuth option (default false)
scripts/post-deploy-check.sh            # miniflux smoke probes / not /login
docs/services/miniflux.md               # login-page fact + SSO-only section
platforms/nixos/secrets/miniflux.yaml   # force-added (was breaking every eval)
```

**Waiting for instructions.**
