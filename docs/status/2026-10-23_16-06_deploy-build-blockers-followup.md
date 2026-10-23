# Deploy build blockers, second pass — the FOD realignment and what is still broken

_2026-10-23 16:06 CEST · follow-up to `2026-10-23_12-38_deploy-blocker-triage-status.md` · scope: the build (not eval) failures hit while force-deploying, what was fixed, and the four independent defects that remain._

---

## Headline

The three **eval/gate** blockers from the first pass are gone (eval green, pre-vacuum gate pass, icon pack built) and the deploy now reaches the **build** phase — where it fails for a different set of reasons:

1. **9 stale blocklist FOD hashes + 1 stale signoz pnpm hash + 3 stale pnpm hashes + 3 stale upstream `vendorHash`es** — all realigned from first-hand probes. Committed.
2. **Four independent build defects remain**, none of which the hash work touches:
   - `nodejs-26-npm-12` (node **26.12.1**, the npm-bundled build from our pinned nixpkgs) **segfaults on startup** on this host. Every npm/pnpm package that lands on it dies: `hermes-tui`, `web-0.0.0`, `overview`. Node **26.12.0** from a newer nixpkgs runs fine (`v26.12.0`) — so this is a regression in the pinned revision, not the machine.
   - `linux-7.3-modules` (exit 123): `cat: kernel/drivers/net/ethernet/realtek/r8125.ko.cer: No such file or directory` — the r8125 out-of-tree module does not build against kernel 7.3.
   - `dms-shell-2.0.0+date=2026-10-20_9b41329` (exit 1): passes buildPhase and checkPhase, dies in `installPhase` with no error line in the captured log.
   - `python3.14-aw-core-0.5.17`, `signoz-…-patched` (exit 1): patch/source failures, logs truncated.
3. **A `flake.lock` rollback does not help.** I restored the pre-float lock (08:31 state) and rebuilt: the exact same four defects persisted — proof they are *not* caused by today's 15:17 float, and that the node-26 breakage comes from the pinned nixpkgs rev (`02c087f3`), which never moved. Lock restored to HEAD afterwards.

**Deploy is still not possible.** Nothing was activated; no generation was switched.

---

## a) FULLY DONE (this pass)

1. **Enumerated every build failure instead of fixing the first one** — `nix build … --keep-going` (the repo's documented rule) produced the full graph: 6 FOD hash mismatches, then 7 leaf drv failures.
2. **Blocklists re-pinned (22 entries probed, 15 hashes changed)** — `nix store prefetch-file` per `hagezi` URL; content sanity-checked (`# Title: HaGeZi's Encrypted DNS Bypass`, 3,705 `0.0.0.0` lines for `doh.txt`, 682,069 lines for `ultimate`, 2,063,709 for `tif`). Two entries (`dyndns`, `hoster`) have comment blocks between `url` and `hash` and were missed by my line-offset rewrite on the first attempt — fixed by value match, then verified in the file.
3. **`signoz-frontend` pnpm deps hash re-measured** — the hint path (empty hash → build → read `got:`) yielded `sha256-6yhnUvjO…`; `nix build .#signoz-frontend` then succeeded end-to-end (the rolldown-vite build itself is healthy).
4. **Three local pnpm hashes re-measured** (`jscpd`, `systemd-graph-webui`, `openseo`) — all three files already carried comments saying this drift recurs on every nixpkgs bump.
5. **Three upstream `vendorHash` shims re-added with probe evidence** (`library-policy`, `projects-management-automation`, `papdashboard`) using the documented `flakePkgShim` pattern, each comment recording specified vs got. Dropped-again conditions documented.
6. **`flake.lock` rollback tested and rejected on evidence** — restored `407920f98:flake.lock`, eval passed (so today's module changes are lock-compatible), but the build failed identically. Restored HEAD's lock; tree clean.
7. **Guard storm fix landed** (from the earlier phase, still in HEAD): `inboxclean-web.service` added to `ioChurnUnits`, eval-verified list.
8. **Node regression isolated** — three first-hand comparisons: `node-26.12.1` → exit 139 even with `setarch -R` (ASLR ruled out), `nodejs-24.21.0` → runs, registry `nodejs_26` (26.12.0) → `v26.12.0`. Store path integrity verified (`nix-store --verify-path` clean), so it is a build defect, not corruption.

## b) PARTIALLY DONE

1. **The deploy**: pre-deploy gates pass, eval green, most FODs fixed — four build defects and an unbuilt toplevel remain.
2. **`projects-management-automation` shim**: applied in `lib/lars-packages.nix`, but the build still used the unpatched drv (`specified U9F6gATv`). The consumer of that package evidently does not go through the `lars-packages.nix` attribute — needs one more wiring check.
3. **Dirty-tree attribution**: my commits were repeatedly swept into daemon heuristic commits; three were re-split into real messages (`2cd8da68f`, `2e22717c3`, `3e48da147`), then the daemon swept the FOD fixes into `b5f9bce7d`/`98f469e28`. Several of today's commits still carry heuristic messages.

## c) NOT STARTED

1. **Node-26 workaround** — no overlay, no nixpkgs bump, no per-package node pin yet.
2. **r8125/kernel-7.3** — module build failure untouched.
3. **`dms-shell` installPhase**, **`aw-core`**, **`signoz-…-patched`** — logs not yet deep-dived.
4. **Full pre-deploy battery re-run** (the §1–§19 pass) with the fixed tree.
5. **Deploy + anchor verification** (`readlink /run/current-system` vs newest `system-N-link`).

## d) TOTALLY FUCKED UP!

1. **Two sessions have been floating `flake.lock` all day and nothing gates it.** Lock commits: 03:20, 04:25, 07:09, 08:20, 08:26, 08:31, 15:17 — each one re-stales every pnpm/vendor hash. My first hash fixes were stale within the hour; the auto-commit daemon swept four of my files into a heuristic commit mid-work. This is the same "lock float without a build gate" class the 08:35 report named, now with a second day of evidence.
2. **I burned three build cycles re-fixing the same class** (blocklists → signoz → pnpm/vendor) because I fixed files one at a time instead of regenerating *every* pinned hash in one sweep. The `--keep-going` enumeration was right; my repair loop was not batched.
3. **I let a line-offset rewrite (`sed` on `url-line + 1`) corrupt the intent** for the two entries with intervening comments. Caught only because the next build complained — value-matched replacement is the correct method for generated edits.
4. **A lock rollback experiment ran before I had proven the float was the cause.** It was cheap and reverted, but the hypothesis should have been tested by diffing *which* input moved (hermes/overview did, nixpkgs did not) before touching the lock.
5. **Three hours vanished between the 12:38 report and this one** (long build waits under a 95–100 % busy pool). The first report's "deploy now" framing is now stale — this file supersedes it.

## e) WHAT WE SHOULD IMPROVE!

1. **A lock-float gate with teeth**: no `flake.lock` commit without `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` (or at minimum a `--dry-run` FOD preview) on the float. Today's cascade is exactly what that gate would have caught.
2. **Batch hash regeneration as one tool**: walk every `fetchPnpmDeps`/`fetchurl`/`vendorHash` constant in the tree, probe each, emit one diff. Today it was 9 manual probes.
3. **Node version policy**: pin the node major for build tooling (24) instead of inheriting whatever the pinned nixpkgs ships. A 26.12.1 build that segfaults should never be able to block a deploy.
4. **Kernel-module compat assertions**: `linux-7.3-modules` failing on `r8125` should surface at eval (version gate), not after 40 minutes of building.
5. **Report the lock churn to the user at the first sign**, not after the third hash fix goes stale.

## f) NEXT (ordered, from this session's evidence)

1. Check why the `projects-management-automation` shim did not take (find the actual consumer; mirror the `papdashboard` override style).
2. Decide the node-26 route: (a) overlay `nodejs_26` → `nodejs_24` for build tooling, (b) bump the pinned nixpkgs past the 26.12.1 regression, or (c) pin the three affected packages to node 24 individually.
3. Deep-dive `dms-shell` installPhase (rerun the drv and capture the full log; the current tail stops right after "Running phase: installPhase").
4. Deep-dive `aw-core`, `signoz-…-patched` (patch hunk offsets suggest source drift).
5. Fix or gate the r8125 build for kernel 7.3 (package bump, or `boot.extraModulePackages` conditional).
6. Re-run the full pre-deploy battery once the toplevel builds.
7. Deploy with anchor verification, then the post-deploy sweep (new metrics, monitor365 :9191, inboxclean storm behaviour under the new guard list).
8. Clean up the heuristic commits that contain today's fixes (amend-forward, per the daemon-race policy).
9. Land the lock-float build gate (e) #1 so this cannot recur tonight.
10. Report the concurrent-session lock churn to the owner and agree a quiet window for deploys.

## g) QUESTIONS I CANNOT ANSWER MYSELF (3)

1. **Node 26**: force the build tooling to node 24 (fast, local, hides the regression), or bump the pinned nixpkgs to a rev where node 26 works (correct, re-breaks hashes again)?
2. **r8125 / kernel 7.3**: is the realtek out-of-tree module still required on evo-x2, or can it be dropped from `extraModulePackages` in favour of in-tree `r8169`?
3. **Lock churn**: should I add the build gate to the auto-commit path tonight, and freeze lock floats until the next successful deploy?

---

## Evidence (this pass)

| Fact | Command | Result |
| --- | --- | --- |
| Full failure enumeration | `nix build …toplevel --keep-going --no-link` | 6 FOD mismatches, 7 leaf drv failures |
| Blocklist probe | `nix store prefetch-file --json <gitlab raw>` ×22 | 15 hashes changed, all content sanity-checked |
| signoz pnpm deps | empty hash → build → `got:` | `sha256-6yhnUvjO…`, then `.#signoz-frontend` builds |
| pnpm drift | first-hand `got:` values | jscpd / systemd-graph-webui / openseo re-pinned |
| vendorHash drift | first-hand `got:` values | library-policy 7EyJHHnw, PMA NBQcjrwD, papdashboard mi1+rwiO |
| Lock rollback test | `git show 407920f98:flake.lock > flake.lock` + build | identical 7 leaf failures → float not the cause |
| Node 26.12.1 | `/nix/store/gzr0…-node-26.12.1/bin/node --version` | exit 139 (also with `setarch -R`) |
| Node 26.12.0 | `nix run nixpkgs#nodejs_26 -- --version` | `v26.12.0`, exit 0 |
| Node 24 | store binary | runs |
| r8125 | build log | `cat: …/r8125.ko.cer: No such file or directory` |
| Lock churn | `git log -- flake.lock` | 7 floats today, all heuristic commits |

---

## Third pass (16:20–16:30) — the "bump nixpkgs" route is unavailable, and the causes are now pinned down

**`nix flake lock --update-input nixpkgs` is a no-op**: our input is `nixos-unstable` and it is already at the tip (`02c087f3`; the registry resolves to the same rev). There is no newer nixpkgs to bump to tonight — and a bump would not have fixed the node problem anyway:

1. **`node-26.12.1` is not a nixpkgs build.** It is a *prebuilt npm-distributed tarball* (`node-v26.12.1-linux-x64`) fetched by the hermes-agent flake's binary-fetch machinery (derivation `node-26.12.1.drv`: `dontBuild=1`, install script handles `uv-…`, `node-v26.12.1-linux-x64`, `package/`). The binary segfaults on startup here (exit 139, also with `setarch -R`), while nixpkgs' own `nodejs_26` (26.12.0) runs. No nixpkgs revision can touch it; only the hermes input can.
2. **`aw-core` fails on a nixpkgs packaging regression**: `peewee==3.* not satisfied by version 4.4.0` (our pinned nixpkgs ships peewee 4.4.0). The running system was built from `26.11.20261015.fe13242`; the tree is pinned to `26.11.20261020.02c087f3` — the gap between those two dates is where the packaging broke.
3. **`dms-shell`**: the older `1.6.3+date=2026-10-07_4a87e82` derivation builds clean; `2.0.0+date=2026-10-20_9b41329` dies in `installPhase` with no error line.
4. **`signoz-…-patched`**: same silent `installPhase` failure after patches apply with large offsets.
5. **`linux-7.3-modules` / r8125**: another Crush session committed `9a5e59a97` at 16:11 documenting the **kmodigest/modules_install convention change** that broke it and queued the remaining work. Do not duplicate that fix from here.

**Consequence:** a clean build needs either (a) nixpkgs rolled back to the running rev `fe13242` (which would re-open the crowdsec module rewrite that today's work was built for), (b) local patches for five upstream/nixpkgs defects, or (c) disabling the affected services (`activitywatch`, `signoz`, `dms-shell`, `hermes`, `overview`) in this generation.
