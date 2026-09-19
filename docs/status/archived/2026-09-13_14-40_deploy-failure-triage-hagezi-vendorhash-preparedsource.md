# Deploy-Failure Triage: HaGeZi Drift + vendorHash Staleness + preparedSource Validation (2026-09-13 14:40)

> **[docs-health 2026-09-19] RESOLVED + ARCHIVED:** superseded the SAME DAY by the 17:26 full repair (system-774 deployed + anchored) — kept as the interim forensics record.


**Session scope:** ~~Root-cause and repair the failed `nix run .#deploy` (exit after 2h24m, 40 build failures at 14:09:30)~~ superseded same day by the 17:26 full repair, system-774 deployed + anchored (docs/status/2026-09-13_17-26_*).

---

## 1. Root Cause (one paragraph)

At ~11:53 today a **full `nix flake update` landed** (commit `f8f2965e`, 877+/662- in flake.lock), snapping every `?ref=master` moving-ref input to upstream HEADs. The deploy started immediately after and failed 2h24m later against revs that were, in several cases, **broken at upstream HEAD** (no CI on private LarsArtmann repos — Actions hosted-minutes exhausted since ~2026-09-10, so nothing upstream catches these). Independently of the lock churn, **all 21 HaGeZi blocklists drifted** (mutable GitLab mirror `main` branch + SRI pinning — the documented content-drift class). A parallel session re-locked mr-sync **mid-deploy** (13:43, `793b8ad` → `91bcb4c`), which incidentally healed mr-sync. Three sibling repos have **active parallel sessions right now** (dnsblockd commits 14:12–14:18, mr-sync dirty file + commits to 14:16, go-cqrs-lite 3 unpushed commits at 14:10).

## 2. Failure Taxonomy (all 6 classes, with evidence)

| # | Failure                                        | Class                                                                                                                                                                        | Locked rev               | Verdict                                     |
| - | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ | ------------------------------------------- |
| 1 | 21× `HaGeZi-*-raw` hash mismatch               | Mutable-source content drift                                                                                                                                                 | n/a (main branch)        | **FIXED**                                   |
| 2 | `art-dupl-0.6.1-go-modules` hash mismatch (5s) | vendorHash staleness from **source-only churn** (no go.mod/go.sum changes)                                                                                                   | `3533d6f` = local tip    | **FIXED upstream**                          |
| 3 | `branching-flow-prepared-source-0.2.0` exit 1  | `mkPreparedSource` private-dep validation rejected `github.com/larsartmann/samber-linter` (dep added upstream 09-10 `00fb7cef`, never declared)                              | `eedf7ee2` = local tip   | **FIXED upstream** (not yet build-verified) |
| 4 | `cqrs-lint-7d4a6d0…-go-modules` hash mismatch  | Same source-only-churn class; 29 commits since lock, **zero** go.mod/go.sum/flake.nix changes; upstream unfixed; parallel session owns repo (3 unpushed commits)             | `7d4a6d0` (origin@13:02) | **OPEN — decision needed**                  |
| 5 | `dnsblockd-ebea648` buildPhase exit 1 (7s)     | Generated-artifact staleness: `app.min.css is stale` (the AGENTS "ONE artifact at a time" class — `styles.css` was regenerated upstream in `70951c9`, `app.min.css` was not) | `ebea648` (today 13:02)  | **OPEN — fix path known**                   |
| 6 | `mr-sync-793b8ad…` exit 1                      | Stale lock rev — already healed by the parallel session's 13:43 re-lock                                                                                                      | now `91bcb4c`            | **RESOLVED (probe exit 0)**                 |

Everything else in the 2h24m build **succeeded** (2813 builds): niri 26.4.0 (193 tests green in-build), hermes-agent 0.21.2, herdr 0.9.0, web UI, nixpkgs `eaad089` (09-11) — the update itself was mostly good.

## 3. Status by Category

### a) FULLY DONE

1. **Root-cause analysis** — full taxonomy above; traced the trigger to `f8f2965e` (11:53) and the mid-deploy lock move at 13:43.
2. **HaGeZi refresh (21/21)** — `nix store prefetch-file --json` per URL → SRI hash → scripted rewrite of `platforms/common/dns-blocklists.nix` (StevenBlack untouched: pinned to a full commit SHA, correctly immutable). Landed as SystemNix `961257d5` (auto-commit daemon). `HaGeZi-native-roku` was the only list that had NOT drifted.
3. **art-dupl vendorHash fix upstream** — pasted the FOD `got:` hash (`ejRPEDAL…`) into `/home/lars/projects/art-dupl/flake.nix:53`, committed **`9c370324`** on `fork`, **build-verified: exit 0**.
4. **mr-sync verification** — `nix build .#mr-sync` exit 0 at the current lock; no action needed.
5. **samber-linter visibility check** — public (unauthenticated `git ls-remote` over HTTPS works; not in GOPRIVATE list) → `publicDeps` is the correct fix branch of the validation error.
6. **go-cqrs-lite forensics** — no flake.nix/go.mod/go.sum commits between lock and local HEAD ⇒ source-only-churn hash drift (same class as CV `4004de64`); local HEAD `87fb1b01` is **3 commits ahead of origin (unpushed)** and an active session owns it — hand-editing their master was ruled out.

### b) PARTIALLY DONE

1. **branching-flow `publicDeps` fix** — added `publicDeps = [ "github.com/larsartmann/samber-linter" ]` to the `mkPreparedSource` call; landed as branching-flow **`4c58b75f`** (auto-commit daemon). **NOT yet build-verified** (prepared-source FOD + full build still to run).
2. **SystemNix tree repair** — HaGeZi half committed; the **flake.nix interim URL pins are NOT started** (needed because art-dupl/branching-flow fixes are local-only: `github:` inputs cannot fetch unpushed commits).
3. **go-cqrs-lite strategy** — decided in principle (preferred: roll the input back to the pre-update rev via `?rev=` pin + docs breadcrumb; fallback: `git worktree` fix branch at `7d4a6d0` + `git+file?rev=` pin). **Not executed.**
4. **dnsblockd** — root cause identified; plan sketched (re-lock to origin/master → probe; fallback `git+file?rev=` to local HEAD `b2b82e4`, which is 2 unpushed commits of suspiciously fix-shaped parallel work). **Not executed.**

### c) NOT STARTED

- SystemNix flake.nix interim pins (`art-dupl` → `git+file:///home/lars/projects/art-dupl?rev=9c370324…`, branching-flow ditto after verification, go-cqrs-lite rollback pin).
- dnsblockd re-lock + probe.
- HaGeZi **verification build** (`dns-blocker-processed` — prove the 22 fetch+filter pass).
- `nix flake check --no-build` → full toplevel `--keep-going` enumeration → fix stragglers.
- `nix run .#deploy` + profile-anchoring check (`/run/current-system` vs numbered profile) + `post-deploy-check`.
- Docs breadcrumb for the interim pins + TODO_LIST entries (AGENTS requirement for every pin).
- Scratch cleanup (`/tmp/hagezi.tsv`, `/tmp/hagezi-results.txt`, `/tmp/blocklists.json`, …).

### d) TOTALLY FUCKED UP

Nothing destroyed; no data loss; no wrong "fixes" shipped (every change is either verified or unverified-and-unconsumed). Honest failures, small ones:

1. **Todo-list discipline** — task 1 was marked in_progress at session start and never updated while 5 sub-efforts completed; the list lied about session state the whole time.
2. **One wasted round trip** — first HaGeZi eval ran without `--impure` (pure-eval path denial), junking the whole prefetch loop.
3. **Verification-before-declare-done violated at the margin** — I reported art-dupl "fixed" after its build but left the HaGeZi edit unverified and branching-flow unverified when the interrupt came; the honest state was "2 of 4 fixes verified".
4. **Process (inherited, not mine, but worth owning):** the 11:53 `nix flake update` → immediate full deploy cost **2h24m to discover the first failure**. The Critical-Rule flow (`--keep-going` enumeration first, or per-FOD probes at 5–10s each) would have surfaced all 40 failures in one fast pass. This is the same domino-deploy lesson from 2026-08-27, repeated with a bigger bill.

### e) WHAT WE SHOULD IMPROVE

1. **Never deploy straight after a lock update.** Probe each moved input's package individually (seconds) or run one `--keep-going` toplevel build first. 40 failures were knowable in ~2 minutes; they cost 2h24m instead.
2. **HaGeZi drift is a standing 21-hash chore that blocks deploys.** Today's `nix store prefetch-file --json | jq` loop is the fastest known refresh primitive — it should be a flake app (`nix run .#refresh-hagezi`), not session archaeology.
3. **Pinned-hashes vs deploy-stability tradeoff is unmade:** StevenBlack (pinned to a commit SHA) never breaks; HaGeZi (mutable `main`) breaks monthly-ish. Consider pinning GitLab SHAs with a scheduled refresh workflow.
4. **Upstream repos have zero CI signal** (private Actions minutes exhausted) — three of four Go failures were _broken upstream master_. Either budget Actions minutes back, add a self-hosted runner, or accept that every lock update needs a local probe pass.
5. **Concurrent-session hygiene worked** (I detected and routed around the active dnsblockd/mr-sync/go-cqrs-lite sessions instead of editing their in-flight trees), but the mr-sync lock move mid-deploy went unattributed — parallel sessions should announce lock churn.
6. **The `--no-push` rule vs deploy unblocking needs a standing policy:** fixes landed locally can't be consumed by `github:` inputs, forcing interim `git+file?rev=` pins (tq precedent) with CI darkness and cleanup debt. A pre-authorized "hash-fix pushes may proceed" policy would erase the whole pin dance.

### f) NEXT — up to 50 things to get done

**Deploy-blocking (this thread, in order):**

1. Build-verify branching-flow `4c58b75f` locally (prepared-source FOD must pass validation, then full build).
2. Verify HaGeZi refresh: build the `dns-blocker-processed` derivation (all 22 fetch+filter).
3. Decide go-cqrs-lite strategy (rollback pin vs worktree-fix — see §7 questions).
4. Re-lock `dnsblockd` to origin/master (`nix flake lock --update-input dnsblockd`) and probe the build — watch for the _next_ stale artifact (one-at-a-time lesson).
5. If origin still fails staleness: decide between waiting for the active session vs `git+file?rev=b2b82e4` pin (ships 2 unpushed parallel commits — flag first).
6. Pin `art-dupl` input URL to `git+file:///home/lars/projects/art-dupl?rev=9c370324…` (interim, tq precedent).
7. Pin `branching-flow` input URL to `git+file:///home/lars/projects/branching-flow?rev=4c58b75f…` after step 1 passes.
8. Execute the go-cqrs-lite decision from step 3.
9. Write the docs breadcrumb for every interim pin (AGENTS rule: never a bare pin).
10. `nix flake check --no-build` (eval + audit assertions + gatus-pattern-lint).
11. Full `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` — enumerate ALL remaining root failures in one pass.
12. Fix any stragglers the enumeration surfaces (there may be more behind the 40).
13. Check deploy-pressure gate inputs (PSI/zram/MemAvailable) before the switch; consider `heavy-job` wrapper for the build given parallel sessions.
14. `nix run .#deploy`.
15. Verify profile anchoring: `readlink /run/current-system` == `readlink /nix/var/nix/profiles/system` (2026-09-09 exit-4 skip class).
16. `nix run .#post-deploy-check`.
17. Confirm dnsblockd came back healthy and parses the NEW blocklist content (journal: no malformed-line rejects from 21 drifted lists).
18. Confirm Gatus DNS checks green; spot-check `*.home.lan` resolution.
19. niri 26.4.0 + hermes 0.21.2 land with this deploy: after deploy, check hermes journal for scope-probe/cron-dispatch regressions (v0.21.0 lessons), and note niri needs a re-login to take effect.
20. Clean up `/tmp` scratch files from this session (hagezi.tsv, hagezi-results.txt, blocklists.json, pf.err, bl-eval.err).

**Push / upstream follow-ups (owner decisions pending):**

21. Push art-dupl `9c370324` to `origin/fork` → flip SystemNix URL back to `github:…?ref=fork`, re-lock, drop pin.
22. Push branching-flow `4c58b75f` → flip URL back to `github:…?ref=master`.
23. Fix go-cqrs-lite `cqrs-lint` vendorHash upstream (line 778, got: `1xSG1HTlDu8IKDBAZnDgEyAmEmpRdWKtzdaKYl9wteE=` at `7d4a6d0`) — coordinate with the active session; push; drop the rollback pin.
24. Deliver dnsblockd `app.min.css` regeneration upstream (or confirm the active session's 14:15/14:18 commits already did).
25. TODO_LIST entries: interim pins (items 21–24 as the cleanup map), HaGeZi refresh app, update-then-deploy process rule.
26. AGENTS.md memory update: `nix store prefetch-file --json` = fastest SRI refresh primitive (no fakeHash dance); "probe FODs individually after any lock update, before any deploy".

**Noticed during this run — hygiene / hardening:**

27. Add `nix run .#refresh-hagezi` flake app automating prefetch+rewrite (today's loop as the seed).
28. Evaluate pinning HaGeZi to GitLab commit SHAs (StevenBlack style) + scheduled refresh; freshness vs deploy-stability tradeoff needs an owner decision.
29. Root-cause who/what re-locked mr-sync mid-deploy at 13:43 (parallel session? a hook?) — unattributed lock churn during deploys is the actual race that made the failing set shift under the deploy.
30. CI blindness: private repos have no Actions signal — decide between restoring minutes, self-hosted runner, or a scheduled `nix build` cron per repo that pages on red.
31. Upstream dnsblockd: the "regenerate ALL generator outputs in one pass" rule keeps being violated one artifact at a time (`styles.css` fixed 09-13, `app.min.css` still stale) — propose an upstream pre-push hook running the staleness check.
32. Add a flake check that fails loudly on `git+file` input URLs (interim pins must never leak into pushed states silently; tq precedent currently relies on prose).
33. Verify no other mutable-URL fetches exist in the tree besides HaGeZi (StevenBlack is pinned; sweep for other raw-`main` fetches before they become the next 21-hash morning).
34. Check whether the 2h24m build starved textfile collectors (system_health stale → sev1 notify tier) — verify no false pages fired during the build window.
35. Verify no wedged `switch-to-configuration` lock survived the failed deploy (deploy.sh's >30min stc guard never got a chance to run — the build died before stc).
36. Disk-space check on the Samsung `/nix` store after 2813 builds before the next full build.
37. `herdr 0.9.0` is a NEW package entering the closure via this lock — confirm what consumes it and that it's wanted on evo-x2.
38. hermes 0.21.2 (lock) vs 0.21.0 (deployed): post-deploy, verify the restart-safe cron dispatch probe still passes (§ "user-manager bus" invariants) — the lock's ~20 upstream commits were reviewed as desktop-only, re-verify at runtime.
39. mr-sync has a dirty working file (`cmd/mr-sync/dashboard_events.go`) in the active session — do not consume mr-sync origin blindly until that session lands; leave the lock at `91bcb4c`.
40. go-cqrs-lite: 3 unpushed commits on master (`87fb1b01`) — owning session should push; until then the lock cannot advance cleanly past `7d4a6d0` anyway (vendorHash stale).
41. art-dupl-src (plain `github:LarsArtmann/art-dupl`, flake=false, consumed transitively by dnsblockd): confirm the dnsblockd re-lock in step 4 still resolves it and builds.
42. Consider caching the `got:` hashes observed today in the report for quick re-pins (done — see §5 of this report).
43. Sweep TODO_LIST for the 2026-08-27 "domino deploy" lesson and upgrade it to name the per-FOD probe command explicitly so the next session doesn't relearn it at 2h24m cost.
44. Check `nixpkgs` `eaad089` (09-11) against the eval-time package-output trap class (niri fix shipped; `nix flake check --no-build` in step 10 is the regression gate).
45. After deploy: confirm PMA auto-commit health is unaffected (its lock is PMA-side, but the flm socket-activation churn during builds is worth one journal glance).
46. Verify the failed deploy didn't leave `atticd-bootstrap`-style failed units blocking the NEXT activation (reset-failed sweep before deploy).
47. Consider a `nix flake lock --snapshot`-style pre-update backup habit (or commit the lock BEFORE the update as its own commit) so rollbacks like go-cqrs-lite's are one `git show` away — today it was, keep it that way.
48. Document in AGENTS.md: the auto-commit daemon commits agent edits within minutes — mid-task "uncommitted work" assumptions are invalid here; always re-check `git status` before declaring file state.
49. Add the six failure classes of §2 as a short "lock-update triage playbook" (hash-mismatch → paste got:; prepared-source-validation → publicDeps/deps; staleness → regenerate upstream; old-rev-in-lock → re-lock or pin) to docs/CONTRIBUTING.md.
50. Close the loop on this report: annotate items resolved as they land (this file is point-in-time; TODO_LIST carries the live ones).

### g) Questions only you can answer

1. **Push policy:** art-dupl `9c370324` and branching-flow `4c58b75f` are committed locally but unpushed (per the never-push rule). Should I push hash/one-line fixes to their origins so SystemNix can use clean `github:` URLs (no interim `git+file` pins, CI stays able to fetch) — or keep the interim pins until you push?
2. **Parallel sessions:** dnsblockd (commits 14:12–14:18 + 2 unpushed), mr-sync (dirty file, unpushed HEAD), go-cqrs-lite (3 unpushed commits) all have an active session right now. Are those yours/expected, and may I re-lock dnsblockd to its **origin** master (8 commits, includes a styles.css regen) while that session runs — or should I hold off entirely?
3. **go-cqrs-lite:** rollback the SystemNix input to the pre-update rev via `?rev=` pin (safe, loses ~29 commits of cqrs-lint progress, sticky until manually dropped), worktree-fix at the locked rev, or wait for the active session to bump the vendorHash upstream — which do you want?

---

## 5. Reference — exact hashes/revs from this session

- HaGeZi: 21 refreshed hashes in `961257d5` (e.g. ultimate `JjT81Ya22Fm1FRao/iodzZRduZ2ptECLzQcnlnlwATg=`); `native-roku` unchanged.
- art-dupl vendorHash at `3533d6f`: `sha256-ejRPEDAL6bHvYsqAfn0tsLVuQtiVkfZRTbFblkPzBpE=`.
- cqrs-lint vendorHash at `7d4a6d0`: got `sha256-1xSG1HTlDu8IKDBAZnDgEyAmEmpRdWKtzdaKYl9wteE=` (specified `pjCZGc0…` is stale at BOTH the lock and origin/master — flake.nix untouched since before the lock).
- Pre-update lock for go-cqrs-lite: `git show f8f2965e^:flake.lock` (not yet extracted — first act of the rollback path).
- dnsblockd failing rev `ebea648`; origin/master +8 (incl. `70951c9` styles.css regen); local `b2b82e4` +2 unpushed.
- mr-sync: lock `91bcb4c` builds (exit 0); origin +2 (`228a6d3`, `08e5cc8`) — deliberately NOT consumed while the session is dirty.
