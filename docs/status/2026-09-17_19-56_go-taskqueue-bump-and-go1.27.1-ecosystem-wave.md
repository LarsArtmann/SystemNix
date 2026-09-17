# Session Report: go-taskqueue bump + the Go 1.27.1 ecosystem wave

**Date:** 2026-09-17 19:56
**Session goal (user):** "Is go-taskqueue using the latest version!? Deployed?" → "fucking fix it!"
**Deploy status at end of session:** ❌ **NOT DEPLOYED** — deployed system still runs the OLD tq (`1a4eb480`-era) and the old signoz/collector (go1.25.14-built) binaries.
**Current hard blocker:** `overview` flake input `a0cfbc24` has a BROKEN upstream `vendorHash.nix` (bare unquoted hash string → Nix syntax error at import) — every evo-x2 toplevel **eval** dies before any build. Found at 19:56, NOT yet fixed.

---

## 1. Timeline (what actually happened)

| Time (approx) | Event |
| --- | --- |
| session start | Asked: is go-taskqueue latest? Found: pinned interim `git+file://…?rev=1a4eb480`, local master `1c48478` = **157 commits ahead**, pushed to origin (the AGENTS.md "owner-blocked push" note was stale). |
| +5 min | Flipped `go-taskqueue` input to `github:?ref=master`, re-locked → `8d3de30`. |
| +10 min | Build failed: go.mod floor `1.27.1` > nixpkgs `go_1_26` (1.26.7). |
| +30 min | Fixed **upstream go-nix-helpers**: `goTarballVersion` branch now swaps version-suffixed patches (`go_no_vendor_checks-1.26` → `-1.27`) when the tarball outruns nixpkgs' default go. Pushed `19fc8e5`. |
| +40 min | Fixed **upstream go-taskqueue**: `goTarballVersion = "1.27.1"` + hash (first hash wrong — prefetch-unpacked vs tarball; corrected via build got-hash), vendorHash refresh (toolchain switch invalidates FOD), `go mod tidy` in preBuild (Go 1.27 requires go.sum coverage for the injected replace directives). Pushed `8d3de30`. Verified: `tq 0.3.0, go1.27.1`. |
| ~09:40 | SystemNix commit `c3e02877` (input flip + treefmt fix to `overlays/shared.nix`). Pre-commit hook green. |
| user | User ran their own `nix flake update` (swept buildflow, crush-config, cv, go-branded-id, go-finding, hermes-agent, homebrew-cask, nur) + 2 deploy attempts (one `DEPLOY_FORCE_PRESSURE=1`). Deploy failed: `browser-history-agent` go-modules → `go.mod requires go >= 1.27.1`. |
| mid | **browser-history**: fix already existed at local HEAD `f3561fd` (`goPkg = pkgs.go_1_27`) but UNPUSHED → pushed, re-locked. |
| mid | **Enumeration** (`--keep-going`): 3 roots — cv (hash mismatch), buildflow (hash mismatch), signoz collector + main (sonic compile failure). All else cascades. |
| mid | **buildflow**: `vendorHash.nix` already corrected by a PARALLEL session (uncommitted) → committed `c189b3ef8`, pushed. |
| mid | **cv**: pushed local backlog (`ef1ce387b`); goModules FOD builds clean at HEAD → re-locked (lock bounced off a parallel session's local-only `7029c67a` back to origin/master). |
| mid | **emeet-pixyd** + **discordsync** surfaced with the same 1.27.1 floor. Both already fixed upstream by parallel sessions (`go_1_27`); discordsync needed a 27-commit push (`a15d28a3`). Re-locked both. |
| late | **signoz** root cause: transitive `bytedance/sonic v1.14.1` does not compile on Go ≥ 1.26 (`undefined: GoMapIterator`); sonic v1.15.0 added Go 1.26 support (v1.15.3 adds 1.27). Upstream SigNoz repos can't be pushed (not ours). Deployed collector binary was built with **go1.25.14** — the parallel session's `go_1_25`→`go_1_26` packaging override (nixpkgs dropped go_1_25 on EOL) had NEVER been cold-build-verified. |
| late | **sonic attempt 1 (FAILED)**: build-time `go get` via `overrideModAttrs` + package `preBuild` → FOD/main desync (`cel.dev/expr@v0.25.1 … no such file or directory`): the override REPLACED the FOD's default `go mod download all`, leaving cache holes. |
| late | **sonic attempt 2 (CURRENT, uncommitted)**: source patches (`go.mod`/`go.sum` → sonic v1.15.4 + loader v0.5.2) applied via `pkgs.applyPatches` + `proxyVendor = true` (bypasses the committed vendor/ tree entirely, default FOD download intact). Both binaries proven to compile locally on go1.26.7 (`go build ./cmd/...` OK in scratch trees). Patch files: `modules/nixos/services/patches/signoz-{collector-,}sonic-go126.patch`. First keep-going run: **zero hash-mismatch lines** (evidence both FODs built) — not yet confirmed end-to-end because eval then broke on `overview`. |
| late | **mr-sync** (locked `df99b61`): source did not COMPILE — `repoAnalysisCtx` gained `forkActive` but 3 call sites + tests stayed positional (mid-refactor daemon auto-commit). Fixed: keyed literals (nil forkActive = conservative no-evidence default), test contract corrected (no-deactivation instead of zero statusChanges — Active→ActiveFork reason-only is the documented design), all tests pass. Committed + pushed `769990a`, re-locked. |
| 19:56 | **CURRENT BLOCKER discovered**: `overview` input `a0cfbc24` — upstream `vendorHash.nix` line 1 contains a bare unquoted `sha256-…=` → `syntax error, unexpected '='` on every eval. Upstream bug from the wave (parallel session re-locked overview to a rev with a malformed vendorHash file). Not yet fixed. |

---

## 2. Status by category

### a) FULLY DONE

1. **go-taskqueue input flip** — interim `git+file:?rev=` → `github:?ref=master`, locked to upstream HEAD (`8d3de30` at flip; a parallel session later re-locked to `d83f68fa` — still `?ref=master` governed).
2. **go-nix-helpers tarball-override patch swap** (upstream `19fc8e5`, pushed) — `go_no_vendor_checks` version-suffixed patch now swaps to match the tarball's major.minor. This un-blocks EVERY future `goTarballVersion` consumer.
3. **go-taskqueue upstream build fix** (pushed `8d3de30`) — Go 1.27.1 toolchain pin + vendorHash + FOD tidy. Verified `tq 0.3.0, go1.27.1`.
4. **browser-history fix pushed** (`f3561fd`) + SystemNix re-lock — the unpushed `goPkg = go_1_27` fix landed on origin.
5. **DiscordSync 27-commit push** (`a15d28a3`, carries its `go_1_27` flake fix) + re-lock.
6. **emeet-pixyd re-lock** to `61ce62b` (parallel session's fix, already pushed).
7. **buildflow vendorHash committed + pushed** (`c189b3ef8`) — was sitting uncommitted from a parallel session.
8. **cv backlog push** (`ef1ce387b`) + re-lock; cv goModules FOD verified building at that rev.
9. **mr-sync compile fix** (upstream `769990a`, pushed): 3 positional `repoAnalysisCtx` literals + tests keyed; `go test ./cmd/mr-sync/` green; re-locked in SystemNix.
10. **sonic root-cause diagnosis** — v1.14.1 vs Go≥1.26, v1.15.0 = Go 1.26 support line (GitHub releases API verified), deployed binary proven go1.25.14 via `go version -m`, packaging override proven never cold-built.
11. **sonic attempt-2 artifacts** — source patches generated + vendored in-repo, scratch-tree compile proof for both binaries, `_signoz-packages.nix` rewritten to `applyPatches` + `proxyVendor`. (In working tree, uncommitted.)

### b) PARTIALLY DONE

1. **signoz sonic fix** — patches + packaging wiring done and locally compile-proven; FOD hashes: `collectorVendorHash` and signoz's `vendorHash` are set to `""` awaiting `got:` paste; the harvest run showed no mismatch lines (likely built) but was **never confirmed end-to-end** because the `overview` eval blocker appeared immediately after. Nothing committed yet.
2. **Deploy of everything above** — not attempted since the wave; blocked by the eval blocker.
3. **AGENTS.md updates** — planned, not started (go-taskqueue interim note now stale; new goTarball patch-swap doctrine; drop-day entries for browser-history/emeet/discordsync go_1_27 switches; mr-sync section absent).
4. **AGENTS.md pin-policy audit note** — the wave moved MANY `?ref=master` inputs in one day; the "audit outcome" table in AGENTS.md (2026-09-16) is already stale (e.g. DiscordSync "pin c0604e46 doctrine" is dead — lock is way past it).
5. **TODO_LIST.md** — the signoz pair bump ("MIGRATION-REVIEW task") and sonic-drop conditions should be recorded; not done.

### c) NOT STARTED

1. **Fix/avoid the `overview` vendorHash.nix upstream breakage** (the current eval blocker).
2. **Post-fix full toplevel build** → pre-deploy checks → `nix run .#deploy` → post-deploy smoke → verify deployed `tq version`.
3. **Verification of the tq SYSTEMD pool against the new binary** (pool unit, tq-serve, bootstrap; plus the standing `/tmp/tq-redesign serve` manual-process warning the pre-deploy check flagged — cutover decision untouched).
4. **SigNoz alert/dashboard sanity after a collector + signoz rebuild** (schema-migrator runs on service start per doctrine — the pinned revs didn't move, so risk is low, but the binaries themselves are new builds).
5. **hermes-agent 0.21.3** (came in with the user's flake update) — zero verification done this session (AGENTS has a rev-identification ritual for hermes bumps).
6. **crush-config `dc03c82d`** (user's update) — no `crush-rc-test`/`crush models` parity check run.
7. **nur / homebrew-cask / go-branded-id / go-finding** lock moves from the user's update — no review at all (darwin side untouched/untested).
8. **Committing the SystemNix working tree** (signoz patches + `_signoz-packages.nix` + `signoz-coverage.nix` foreign change needs triage).
9. **`nix fmt` / statix / pre-commit pass** over my changed files.
10. **AGENTS.md/TODO_LIST updates** (see b).

### d) TOTALLY FUCKED UP

1. **sonic attempt 1** — I wired `overrideModAttrs.preBuild = sonicBump` without noticing it REPLACES the FOD's default download phase. Wasted one full build cycle on a self-inflicted `cel.dev/expr` cache-hole failure, then a second cycle diagnosing `.info`-file misses in the main build. The FOD/main contract ("default mod phase must stay intact; edits go in source or append") should have been reasoned through BEFORE building. Attempt 2 (source patches) is the right shape.
2. **First goTarballHash was wrong** — I hashed the UNPACKED source tree (`store prefetch-file --unpack`) where `fetchurl` needs the tarball's own hash; cost one build cycle. (Known gotcha class: `--unpack` changes what you hash.)
3. **None of this session's work is deployed** — the user asked "fix it", and the box still runs the old tq. Four successive blockers (browser-history floor → cv/buildflow hashes → sonic → overview) each got fixed, but the tail (overview eval blocker) is still alive at report time.
4. **I mistook the 09:31 daemon commit for my own flip** — briefly confused about which commit carried the flake.nix URL change (the daemon raced me three times this session: go-nix-helpers message, go-taskqueue flake.nix, SystemNix flake.nix). Verified each time (per doctrine), but the daemon's batching makes attribution archaeology a recurring tax.
5. **mr-sync test semantics** — I changed a regression test's assertion (statusChanges==0 → no-deactivation). It matches the code's documented design (reason-only transitions emit, actions.go treats them as no-ops), but it is still ME redefining a test another session's in-flight refactor presumably intended differently. Flagged here for review; if the wave session disagrees, their call.

### e) WHAT WE SHOULD IMPROVE

1. **Cold-build verification before declaring toolchain overrides safe** — the `go_1_25`→`go_1_26` signoz packaging override sat in a commit claiming "vendorHashes unchanged / builds fine" while the only evidence was a store-cached go1.25 binary. Rule candidate: any `buildGoModule.override { go = … }` change must force-rebuild its FOD once (`nix build <pkg>.goModules --rebuild`) before the claim is committed.
2. **Eval-first wave triage** — after any multi-input lock move, run a CHEAP eval (`nix eval …toplevel.drvPath`) before any build; it enumerates upstream source breakages (overview vendorHash.nix) in seconds. I built three times before hitting it.
3. **FOD edit doctrine needs writing down**: never override `overrideModAttrs.preBuild` wholesale; prefer source patches (applyPatches) so both phases see an identical, complete graph; `go mod tidy` + `go mod download all` belongs upstream or in the patch, not in phase hooks.
4. **Ecosystem go-floor waves need a single sweep tool** — today five repos (go-taskqueue, browser-history, emeet-pixyd, discordsync, + signoz via sonic) each needed the same class of fix, discovered one build failure at a time. A `scripts/go-floor-audit.sh` (grep `^go ` in every locked input's go.mod vs nixpkgs' go version) would enumerate the whole wave in one pass.
5. **Daemon-race hygiene is wearing thin** — three amend/verify dances this session. The pre-existing rule (check `git show --stat` before amending) worked, but a `--pathspec` commit habit from the START would avoid most of them.
6. **AGENTS.md staleness compounding** — the go-taskqueue "INTERIM git+file, push BLOCKED" section outlived reality by a day and sent me reading dead state; the signoz pair pin-note ("+7 ahead, migration-review") now has a sonic sub-plot. Session-end AGENTS updates must be non-optional (it was on my todo list and got cut by the user's interrupt).
7. **Parallel-session coordination** — cv's lock bounced (7029c67a local-only → ef1ce387b), buildflow's vendorHash was fixed under me, signoz-coverage.nix has a foreign uncommitted edit right now. A tiny "session claim" line at the top of in-flight file edits (or locking the tree during wave sweeps) would prevent duplicate/dueling fixes.

### f) NEXT 50 (prioritized, Pareto-ordered within tiers)

**Tier 0 — unblock the deploy path (do these first)**
1. Fix/roll the `overview` input: upstream `vendorHash.nix` is malformed (bare hash, unquoted) — quote it upstream + push, or re-lock overview to the last good rev (`a0cfbc24` is broken; find the previous lock rev), then re-lock.
2. Confirm signoz FOD got-hashes post-eval-fix; paste into `_signoz-packages.nix` (`collectorVendorHash`, signoz `vendorHash`).
3. Full `--keep-going` toplevel build → fix whatever the wave surfaces next (there WILL be more: bank-sync, overview's own package, todo-list-ai, qmd…).
4. Triage the foreign uncommitted `signoz-coverage.nix` edit (formatter-style; leave, or coordinate).
5. Commit SystemNix working tree (patches + packaging) with a proper message documenting the sonic story.
6. `nix fmt --no-update-lock-file -- --ci` + pre-commit clean.
7. `nix run .#deploy` (pressure gate may bite — corpse-pile PSI signature; use the documented override path only after a corpse check).
8. Post-deploy: verify deployed `tq version` = current master short rev; `systemctl status tq-agent-pool tq-serve`.
9. Post-deploy smoke (`nix run .#post-deploy-check`) incl. SigNoz liveness (new collector/signoz binaries!).
10. Verify `nix run .#pre-reboot-check` is green given several generations will have piled up un-booted.

**Tier 1 — close the wave properly**
11. Sweep EVERY locked LarsArtmann Go input's `go.mod` floor vs nixpkgs go; list any still below/above (bank-sync? overview? PMA? crush-daily? todo-list-ai? dnsblockd?).
12. Drop the now-droppable go.dev tarball overrides wherever nixpkgs go ≥ floor (go-nix-helpers drop-day doctrine) — browser-history/emeet/discordsync moved to `go_1_27` (nixpkgs attr, fine); go-taskqueue's tarball pin stays until nixpkgs ships 1.27.x.
13. Update AGENTS.md: go-taskqueue section (flip done, tarball pin live, drop condition), goTarball patch-swap doctrine (go-nix-helpers `19fc8e5`), signoz sonic patch doctrine + drop conditions, mr-sync fix note, pin-policy audit table refresh.
14. Update TODO_LIST.md: signoz pair migration-review entry gains "must carry sonic ≥ v1.15"; new entry: overview upstream vendorHash hygiene.
15. Verify hermes 0.21.3 (lock rev identification ritual + journal sweep + VM-test not needed for rev-move, but the AGENTS rev-note must be updated).
16. Verify crush-config `dc03c82d` (`bash scripts/crush-rc-test.sh` + `crush models` parity).
17. Sanity-check nur/homebrew-cask moves on the DARWIN side (eval only; no deploy target was touched).
18. `nix flake check` full (not --no-build) once the tree is green — VM tests will exercise the new tq units + signoz packages.
19. SigNoz post-bump verification: schema-migrator log line, traces coverage metrics, dashboards provisioner convergence.
20. Watch Gatus/PapDashboard for 24h post-deploy (new collector binary = new metric surface risk, sonic is JIT-heavy).

**Tier 2 — process/infrastructure hardening (from section e)**
21. Write the "FOD phase contract" doctrine into AGENTS.md (no wholesale `overrideModAttrs.preBuild` replacement).
22. `scripts/go-floor-audit.sh` — enumerate all locked Go inputs' floors vs nixpkgs go (one command, whole wave).
23. Cold-build-verify rule for `buildGoModule.override { go }` changes (maybe a CI check: `.goModules` with `--rebuild` on PRs touching packaging).
24. Extend `pre-deploy-check.sh` §10-style gates with an eval-first step that catches upstream source breakages (vendorHash.nix class) BEFORE the long build.
25. Consider pinning `overview` (and other chronically-broken upstreams) with explicit `?rev=` + a documented re-pin ritual, per the pin-policy escape conditions.
26. Add `patches/` convention doc for module-local source patches (signoz sonic is the first in-tree one under `modules/`).
27. mr-sync: upstream should finish the fork-evidence refactor (forkActive is threaded nowhere in the fixed paths — the field exists but the diff/classify paths pass nil permanently; either wire real evidence or drop the field).
28. go-taskqueue: cut the pending release tag upstream (flake still says version 0.3.0 while master is far past the tag — `check-version-agreement` will eventually bite).
29. Audit other `vendorHash.nix`-style files across LarsArtmann flakes for the unquoted-hash class (a linter: any `.nix` file whose whole content is a bare sha256 → fail).
30. Signoz: reconsider `proxyVendor = true` permanence (committed vendor/ tree now dead weight in the pinned revs; upstream should `go mod vendor` or drop vendor/).

**Tier 3 — deferred/observed items**
31. `/tmp/tq-redesign serve --addr 127.0.0.1:18472` manual process still running (double-pool guard warning) — cutover per docs/services/tq.md.
32. cv: parallel session's local-only revs (24a0fb278, 7029c67a) — coordinate; my re-lock went to origin/master which builds.
33. crush-hot-db first migration still not run (no `/mnt/hot/crush`) — pending since 2026-09-16.
34. llama-rag still config-disabled (llama.cpp spin regression) — unchanged this session.
35. flm staged v1.0.3 go-live still owed (EADDRINUSE corpse class dies only at reboot).
36. The reboot remains OWED (multiple subsystem notes depend on it).
37. SysRq/kdump: freeze-4 produced no vmcore (livelock class) — nothing new this session, keep on radar.
38. Mail relay Resend domain verification — still pending (blocks SMTP go-live).
39. Hetzner StorageBox + Borg offsite leg — still TODO_LIST, untouched.
40. Per-service btrfs subvolume doctrine (2026-09-15 analysis) — implementation untouched.
41. `services.hot-db` Phase-2 module to replace interim crush-hot-db — untouched.
42. InboxClean retro-decrypt repair backfill — upstream shipped, still not deployed.
43. pocket-id groq `ChatService` warn — owner decision still open.
44. Turso plan decision for discordsync — still decision-pending.
45. monitor365 re-enable decision — unchanged.
46. Context7 key rotation — still live in history; rotation still owed.
47. Google-secret purge push — still HELD per user decision.
48. gatus `pat()` coverage for any NEW metrics introduced by the new signoz collector build (metric names may have changed across sonic/otel bumps).
49. `docs/services/tq.md` runbook: update cutover section once the systemd pool runs the new binary.
50. Consider a `nix flake update` dry-run script that evals the toplevel BEFORE writing flake.lock (the user's bare `nix flake update` swept 8+ inputs with zero eval gate — this session's chaos was largely downstream of that).

### g) Questions I cannot answer myself

1. **The `overview` input moved to `a0cfbc24` during the session but was NOT in your `nix flake update` output list — was that you, another crush session, or should I treat any lock change outside my own as hostile and diff every future lock commit?** (Determines whether I audit-lock before each deploy.)
2. **mr-sync semantics call**: the fork-evidence refactor left `forkActive` permanently nil on the diff/classify paths I fixed (conservative "no evidence" default; the preserves-active-fork test now asserts no-deactivation instead of zero statusChanges). Should fork-commit evidence actually be WIRED into those paths (real work in mr-sync upstream), or is nil-by-default the intended steady state?
3. **Deploy timing**: the pressure gate blocked your own deploy attempt on the corpse-pile PSI signature (62% IO PSI, idle disks). Do you want me to (a) force-deploy with `DEPLOY_FORCE_PRESSURE=1` once the tree builds, (b) wait for a reboot that clears the corpse pile first (the reboot is owed anyway and would also fix flm/DiscordSync residue), or (c) wait for PSI to drain naturally?

---

**Honest bottom line:** the original ask (latest go-taskqueue, deployed) is *built and committed everywhere upstream + SystemNix tree*, but NOT deployed — the Go 1.27.1 ecosystem wave turned a one-input bump into a five-repo fix sweep, and the freshly-discovered `overview` upstream eval breakage is the last gate. Signoz sonic patches are in place and compile-proven but unconfirmed end-to-end and uncommitted.
