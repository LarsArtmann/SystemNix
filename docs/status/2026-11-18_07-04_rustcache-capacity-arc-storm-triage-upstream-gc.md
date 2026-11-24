# Rust-Cache Capacity Arc: Storm Triage → rustCacheProjects Expansion → GC v2 → Upstream target-gc

**2026-11-18 07:04 CET · single session, two repos (SystemNix + monitor365)**

---

## Scope: what this report VERIFIED vs did NOT verify

**VERIFIED with live commands this session** (each backed by a probe whose output is quoted in-line below or in the session transcript):

- IO-storm attribution: `/proc/pressure/io` (some avg10 70→89, avg300 86–90), `/proc/loadavg` (157/520/807 descending), D-state census (`ps -eo stat` → 17 tasks), per-process parents (`ps -o ppid` chains), 4-second `/proc/diskstats` deltas (sdc write 16.7 MB/s, nvme0n1 write 84.8 MB/s)
- Symlink resolution: `stat -c '%F %m'` (monitor365 `target/debug` mount point = `/mnt/rust-cache`), `readlink`
- tmpfiles `L+` semantics: live probe on a scratch dir (real dir + content replaced by symlink, exit 0)
- Capacity census: `df` (92% → 33% across the owner's mid-session clean), `du -sh` per dir, `find -printf` age histogram (zero bytes >7d; 168G <1d, 46G 1-7d), GC journal (`journalctl -u rust-cache-gc` 28% on 11-15)
- Fingerprint-orphan census: stem-vs-`.fingerprint` pairing walks (1935 orphan files / 4208MB, 484 reverse orphans, 152 orphan build dirs), libduckdb-sys fingerprint JSON feature diff (lean-empty vs bundled)
- Implementation gates: `shellcheck` CLEAN on extracted rendered scripts; two stub-tree sandbox matrices (provisioner 7 branches, GC 12 branches, both green including idempotence runs); `nix eval` toplevel drvPath rc=0 on **both** evo-x2 and rpi3-dns; rendered-surface probes (ExecStart with 14 seed names, timer `*-*-* 04:40:00`, `rustProjects` = 14, derivation script renders `read -r -d ''` ×2, service `User = "lars"`); full `nix flake check --no-build --all-systems` **rc=0 twice**; `cargo check -p monitor365-db --offline` rebuilt-and-passed green (7m33s) after the target-GC apply

**NOT verified (and why):**

- **Nothing is deployed.** Both SystemNix waves (rustCacheProjects expansion + GC v2) are in-tree only — the timer has never fired, the provisioner has never run on the real box, the 13 links are still real dirs. Deploy is owner-gated (PSI gates were active at session time).
- `scripts/target-gc.sh` was proven on a **freshly-cleaned 43G tree** (≈8GB reclaimed), NOT at wave scale (~214G) nor over weeks of regrowth.
- The upstream working-set shrink is NOT measured to be sufficient — owner chose it over placement; if a full wave regrows the target past ~150G the placement question returns (queued [watch]).
- `docs/services/rust-cache.md` existence never checked (flagged as a [ready] row instead of silently assumed).
- The 04:40 timer + weekly GC v2 have zero observed fires; the Gatus counters/staleness checks for them do not exist yet (queued).
- Overnight foreign-session commits (qmd-igpu arc: `68cdfca51`, `4eaf7abd2` in SystemNix) were identified and NOT reviewed — out of scope.

---

## The session in one paragraph

Started as "why is IO 100% on many disks?!" — answered as a build storm (monitor365 Rust linker waves + BuildFlow nix build + two agent sessions' buildflow.db forensics stacked on one box). The storm triage surfaced that monitor365's target had grown to **199G of the 224G rust-cache SSD (89%)**; owner directed "add all known Rust projects to rustCacheProjects + a daily discovery timer"; implementation surfaced that the naive path (tmpfiles `L+`) would have **destroyed ~15G of warm caches** (live-probed `L+` deletes real dirs), so a migration-aware provisioner landed instead. The capacity question ("clean it so monitor365 never hits disk-empty") was then **measured to death**: the working set is stable ~214G with **zero stale bytes** — no GC can reclaim it — demand ≈265G vs 224G supply. Owner chose **upstream shrink**; landed `scripts/target-gc.sh` in monitor365 (fingerprint-aware orphan GC, cargo-safe proven by a green rebuild) plus rust-cache-gc v2 in SystemNix (aged pair-sweep + orphan prune + ladder; the destructive cold-prune-ALL removed). The owner separately cargo-cleaned ~170G mid-session (disk 92% → 31%).

---

## a) FULLY DONE

1. **IO-storm triage + attribution** — PSI/load/D-state census; writers named: monitor365 rustc+sccache+mold linker waves (via the target symlink), BuildFlow `nix build` (nixbld app.test/cli.test), two crush sessions' `buildflow.db` sqlite `.backup` jobs + a 34-min `find /home/lars`, a root find over ci-runner-cache; btrfs kworkers correctly classified as writeback symptom. Aggregate throughput 102 M/s read — iotop's IO% column explained as per-task wait, not disk utilization.
2. **Self-correction of a published wrong claim** — first answer said monitor365 wrote "to the QLC root"; `stat -c %m` proved `target/debug` resolves onto `/mnt/rust-cache`. Corrected with evidence the same session.
3. **rustCacheProjects expansion** (snapshots.nix): eval list `[monitor365]` → **all 14 top-level Rust projects** (live census); seed feeds `rust-cache-init` + provisioner.
4. **`rust-cache-link-projects` provisioner** (replaces bare tmpfiles `L+`): move-aside renames (`target.migrated-<ts>`, never deletes), wrong-symlink repair, post-clean cache-dir recreation (ENOENT guard), stale-seed skip, flock serialization, XDG_RUNTIME_DIR lock, space guard (defers provisioning above `usageThresholdPercent`).
5. **`rust-cache-projects-links.timer`** — daily 04:40 Persistent; new `~/projects/*/Cargo.toml` roots link without redeploy. Unit stays in deploy.sh's provisioner loop (name unchanged).
6. **Realtime discovery rejected deliberately** — project-discovery-daemon SSE considered and rejected (FS-event mutation races in-flight cargo builds); rationale documented in the unit comment.
7. **The decisive capacity measurement** — zero stale bytes (churn-in-place), composition 165G deps + 30G build, libduckdb-sys 1.6G `libduckdb.a` + 1.6G rlib **per fingerprint variant** (8+ live pre-clean), demand ≈265G vs 224G supply: structurally over capacity, unfixable by cleaning.
8. **Owner capacity decision taken via structured question** → **upstream shrink** chosen (over Samsung placement / bigger device / status quo).
9. **GC v2** (rust-cache.nix): aged artifact-pair sweep (artifact + companion `.fingerprint/<stem>` — unpaired deletion makes cargo relink redundantly or fail at link), reverse-orphan fingerprint leg, orphan-dir prune with own-mtime grace window, ladder to 7d at `gc.actThresholdPercent` (80), **cold-prune-ALL leg removed** (GC never wipes resident projects), Gatus alert text fixed (its old manual-prune advice would have wiped active caches).
10. **monitor365 `scripts/target-gc.sh`** — fingerprint-aware orphan GC: artifact-without-fingerprint, fingerprint-without-artifact, unreferenced build dirs (JSON-mention check); cargo-running guard; DRY-RUN default; chained reclamation (pass order compounds: 1935 files + 484 fingerprints + 152 build dirs ≈ 8GB on first apply); variant cause documented (lean-empty vs bundled feature unification = legitimate resolver-v2 behavior, not a bug).
11. **Verification battery** — both sandbox matrices green including idempotence; shellcheck on rendered forms; both host evals rc=0; full flake check rc=0 ×2; derivation-rendering proof; monitor365 `cargo check` rebuild-and-pass proof.
12. **Docs + ledger hygiene** — SystemNix: storage.md What-it-holds + GC bullets rewritten, CHANGELOG ×2 entries, `[decision]` capacity row annotated with the measured verdict, split-thresholds todo ticked **both sides** (storage.md:137 + TODO_LIST:1301), stale cold-prune references swept; monitor365: `_ACTIVE.md` claim registered then struck DONE, CHANGELOG entry landed.
13. **Authoring-time self-harvest** — 6 follow-up rows landed in docs/todo/storage.md + TODO_LIST (§f below marks them).

## b) PARTIALLY DONE

1. **Both SystemNix waves are in-tree but NOT deployed** — the whole rust-cache feature set (expansion, provisioner, timer, GC v2) is inert until `nix run .#deploy`; post-deploy cutover of the 13 links unproven.
2. **Upstream shrink is tooling, not yet shrinkage** — target-gc landed and proven at small scale; the actual reduction levers (feature-variant collapse, `incremental=false` for dev tests, per-wave test-matrix trim) are NOT implemented and their ceiling is unknown (working set is inherently 100G+ in debug).
3. **Regrowth protection unproven at scale** — target-gc reclaimed 8GB on a fresh 43G tree; whether it keeps the next full wave bounded below the disk ceiling is a [watch] row.
4. **The storm arc's paper trail** — attribution answered and the 2026-11-15 report §21 annotated, but the freeze-ledger cross-check ("no freeze rode the 807-load storm") was never written down.
5. **This report** — the earlier status-report request was superseded twice by engineering mandates; this file closes it (a day late, content current through 07:04).

## c) NOT STARTED

1. Fixture tests for the two new scripts as flake checks (SystemNix fixture doctrine; pairs with the open buildcache-init fixture row) — sandbox matrices ran ad-hoc only.
2. Provisioner/GC counters → `rust-cache.prom` + a Gatus staleness check (a silently-dead timer is invisible today).
3. Wave-scale validation of target-gc + a cadence decision (manual-only today).
4. `docs/services/rust-cache.md` runbook (existence never verified; facts scattered in storage.md).
5. The fingerprint-aware orphan leg ported INTO rust-cache-gc (currently monitor365-only tooling).
6. ActivityWatch nested target (`aw-server-rust`) policy — documented as exception, no decision.
7. `target.migrated-*` reaping policy (owner-manual by default; no age-reap leg).
8. Samsung-placement prep work (provisioner exclusion list) — only relevant if the [watch] row trips.
9. Merge-SanDisks IO tests (existing [decision] row, untouched).
10. 2026-11-15 report §22/§23/§24/§25 follow-ups (foreign items seen in the same list, out of scope).

## d) TOTALLY FUCKED UP

1. **Published a wrong write-location claim** (the session's worst moment): first storm answer asserted monitor365's writes "land on the QLC root, not buildcache" based on the rustc cmdline PATH STRING without resolving the symlink. The owner's angry follow-up exposed it; `stat -c %m` corrected it. Violated "assert WHICH path/entity" at publish time — the exact doctrine this repo's rules encode. Cost: credibility + one wasted correction cycle.
2. **The ORIGINAL GC design was one wave away from destroying monitor365's cache**: the blanket `-mtime +14` whole-dir stale prune keyed on the DIR's own mtime — meaningless in a churn-in-place tree — and the ≥85% cold-prune would have wiped the active 199G cache wholesale. Only Sunday-timing luck (28% usage) prevented it before the redesign. The redesign wasn't polish; it was defusing a loaded gun.
3. **Nix indented-string `''` trap, twice**: `-d ''` in a `''…''` script terminates the string at parse time. Two eval cycles burned (the `replace_all` fix missed the `fp`-variant line the first time). A pre-eval grep for bare `''` occurrences would have caught both.
4. **Timer nesting error** — `systemd.timers` written inside `systemd.services`; caught by eval, one more cycle.
5. **Missed the amend-forward window** — verified daemon commit `d25b8ebfc` contents but didn't amend its heuristic message before the next sweep; three later commits sealed it (rebase out of scope). The wave's core commit keeps a "chore: auto-commit" message.
6. **Sandbox harness self-cannibalization ×2** — setup.sh and gc.sh placed inside the tree the harness `rm -rf`s; plus an inverted threshold test and a sed anchor miss. ~4 wasted cycles, all test-side, nothing shipped broken. <!-- format:allow -->
7. **Honesty ledger**: one wrong published claim (item 1), corrected same-session with evidence. No fabricated numbers; every figure in this report traces to a quoted probe.

## e) WHAT WE SHOULD IMPROVE

1. **Path-resolution before location claims**: `readlink` / `stat -c %m` every path before asserting where writes land — reflex, not correction.
2. **Amend-forward immediately** after daemon-commit verification — the window is minutes, not end-of-task.
3. **Fixture-test doctrine covers new provisioners/GCs by default** — the sandbox harnesses (python extraction + stub trees + controlled mtimes) are 80% of a flake check already; productize instead of re-deriving.
4. **Measure capacity/workload BEFORE implementing "put everything on disk X" directives** — the 214G finding reshaped the design mid-build; a 2-minute `df`+`du` up front would have reshaped the PLAN instead.
5. **`''`-escape audit before eval** for any script-in-Nix-string work: `grep -n "''" file.nix` and classify each occurrence (escape vs terminator).
6. **Prefer fingerprint-aware reclamation over age-based** in churn-in-place trees — age is meaningless when same-hash artifacts refresh mtimes (cargo-sweep's niche, now ours too).
7. Question-tool choice descriptions cap at 200 chars — write tight the first time.
8. Cross-repo capacity decisions belong in the structured-question flow EARLY (the owner answered in one click once the numbers were on the table — ask sooner next time).

## f) Up to 50 things to get done next

Legend: **[harvested]** = landed in TODO_LIST + docs/todo/storage.md during this report's authoring; **[exists]** = already-queued row elsewhere; **[idea]** = brainstorm/ROADMAP fuel, deliberately NOT harvested (no bounded ask yet, or unverified premise). Direct follow-ups of this session's work were harvested at authoring time per the status-report discipline; the rest are recorded here so they are not entombed.

| #  | Item                                                                                     | Domain     | Status                                                                                                    |
| -- | ---------------------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------- |
| 1  | Deploy both SystemNix waves at first PSI-calm window                                     | rust-cache | **[harvested]** [ready]                                                                                   |
| 2  | Post-deploy verify: 13 links, timer armed, provisioner journal, monitor365 untouched     | rust-cache | **[harvested]** (part of #1)                                                                              |
| 3  | Fixture-test provisioner + GC v2 as flake checks (pair with buildcache-init fixture row) | rust-cache | **[harvested]** [ready]                                                                                   |
| 4  | Port target-gc's fingerprint-orphan logic into rust-cache-gc (+ builder guard)           | rust-cache | **[harvested]** [ready]                                                                                   |
| 5  | Provisioner/GC counters → rust-cache.prom + Gatus staleness check                        | monitoring | **[harvested]** [ready]                                                                                   |
| 6  | [watch] monitor365 regrowth — placement question returns at ~150G                        | capacity   | **[harvested]** [watch]                                                                                   |
| 7  | Check/create docs/services/rust-cache.md runbook                                         | docs       | **[harvested]** [ready]                                                                                   |
| 8  | sccache 33G vs 32G cap — verify LRU is actually holding                                  | rust-cache | **[harvested]** (folded into #5 metrics)                                                                  |
| 9  | Upstream shrink levers: collapse libduckdb-sys feature-variant hashes                    | monitor365 | [idea] — needs upstream duckdb-sys investigation                                                          |
| 10 | `incremental = false` for dev-test profile — measure speed-vs-size                       | monitor365 | [idea] — benchmark first                                                                                  |
| 11 | Per-wave test-matrix trim (owner workflow decision)                                      | monitor365 | [idea] — owner call                                                                                       |
| 12 | Wave-scale target-gc validation + cadence decision                                       | monitor365 | [idea] — after next full wave                                                                             |
| 13 | Wire target-gc into monitor365 flake (`nix run .#target-gc`) or CI                       | monitor365 | [idea]                                                                                                    |
| 14 | Top-20 largest test-binary audit (per-bin size vs linked deps)                           | monitor365 | [idea]                                                                                                    |
| 15 | duperemove/bedup identical-`libduckdb.a` dedup experiment on btrfs                       | storage    | [idea]                                                                                                    |
| 16 | Emergency sweep leg: 15-min df check at ≥88%                                             | rust-cache | [idea] — weekly GC + guards may suffice                                                                   |
| 17 | `target.migrated-*` age-reap policy (or document manual-only as final)                   | storage    | [exists-adjacent] — decision row carries it                                                               |
| 18 | Merge-SanDisks IO tests                                                                  | storage    | **[exists]** storage.md [decision]                                                                        |
| 19 | Split-GC thresholds                                                                      | storage    | **DONE this session** — ticked                                                                            |
| 20 | buildcache-init/rust-cache-init provisioning fixture                                     | storage    | **[exists]** TODO_LIST:1240 (paired with #3)                                                              |
| 21 | Annotate 2026-11-15 report §21 with storm attribution                                    | docs       | **DONE this session** (during authoring)                                                                  |
| 22 | Freeze-ledger note: no freeze rode the 807-load storm (WDT held)                         | stability  | [idea] — one-paragraph ledger addendum                                                                    |
| 23 | nice/ionice policy for owner linker waves                                                | stability  | [idea] — owner workflow decision                                                                          |
| 24 | activitywatch `aw-server-rust` nested-target policy                                      | storage    | [idea] — nix-built tree, likely no-op                                                                     |
| 25 | rust-cache-metrics first-scrape race                                                     | monitoring | **[exists]** storage.md                                                                                   |
| 26 | Sweep stale frozen-spare references                                                      | docs       | **[exists]** TODO_LIST:1302                                                                               |
| 27 | Home-tree space audit batch (projects 144G pre-clean figure is stale post-clean)         | storage    | **[exists]** storage.md [blocked:user] — figures need refresh after the owner's clean                     |
| 28 | Samsung nvme0n1p2 16.6TiB write-rate attribution                                         | storage    | **[exists]** storage.md — monitor365 churn through the projects subvol feeds this if placement ever moves |
| 29 | psi-wait-gate units must not hold boot transactions open                                 | stability  | **[exists]** TODO_LIST:3667 [decision]                                                                    |
| 30 | Resumable-reader pause automation (freeze-6 rule)                                        | stability  | **[exists]** TODO_LIST:214                                                                                |
| 31 | Root-cause phantom-PSI deploy gate                                                       | stability  | **[exists]** storage.md/stability                                                                         |
| 32 | Productize the sandbox-extract harness (python renderer + stub trees) as a repo test lib | pipeline   | [idea] — subsumed by #3 if done well                                                                      |
| 33 | Dangling-WARN noise suppression for deferred-provision links                             | rust-cache | [idea] — cosmetic                                                                                         |
| 34 | Provisioner end-of-run: name deferred projects explicitly                                | rust-cache | [idea] — cosmetic                                                                                         |
| 35 | Recreate-dir events should surface (a manual wipe signal)                                | rust-cache | [idea]                                                                                                    |
| 36 | `flake.nix` `?ref=`+`?rev=` combo parse-trap audit                                       | flake      | **[exists]** 2026-11-15 report §23 (foreign list)                                                         |
| 37 | pin-audit selftest leg for path-form rev pins                                            | flake      | **[exists]** §24 (foreign list)                                                                           |
| 38 | §10 loan mechanism for boot-window-unavailable metrics gate                              | stability  | **[exists]** §20 (foreign list)                                                                           |
| 39 | nixfmt-over-nixpkgs session attribution                                                  | stability  | **[exists]** §22 (foreign list)                                                                           |
| 40 | Rust-cache SSD SMART trend watch (SandForce 60TBW class under 100G/day bursts)           | storage    | [idea] — the wear question hides behind "rebuildable cache"                                               |

Items 9–14 are the owner-chosen upstream track's concrete backlog (monitor365 repo). Items 36–39 are foreign-session lists observed in passing, listed only so they are not lost — not researched this session.

## g) Questions I cannot answer myself

**Q1 — Deploy consent + timing:** both waves are in-tree and the disk is now at 31% (post-clean). Do you want `nix run .#deploy` fired at the next calm window (the §0.5 quiescence probe will judge), or hold — and if the deploy lands, do you want the 13 projects provisioning immediately on the first provisioner run (they will: 31% < 80), or held back until the upstream shrink proves out?

**Q2 — The regrowth cliff:** if monitor365's next full wave regrows the target past ~150G despite `scripts/target-gc.sh` (the working set is inherently 100G+ in debug and the GC only removes orphans), does the Samsung-placement option (target → projects subvol, ~490G free, ~10× faster) come back on the table — or do we double down upstream (`incremental=false`, matrix trim) even at build-speed cost?

**Q3 — target-gc integration level:** stay manual (`bash scripts/target-gc.sh` when you feel like it), become a monitor365 flake app (`nix run .#target-gc`), or get wired into CI/devshell with a budget cap — and should the same fingerprint-aware logic replace the age sweep inside SystemNix's rust-cache-gc (queued as row 4)?

---

## Brutal self-review fold-in (per the session's standing questions)

- **Did I lie?** One wrong published claim (§d.1), corrected same-session with live evidence. All other figures trace to quoted probes; nothing asserted beyond what was run.
- **Ghost systems?** None created — the provisioner/timer/GC are wired (unit + timer + deploy.sh loop + docs), but they are INERT until deploy (§b.1); the [watch] and [ready] rows keep them from rotting silently.
- **Split brains introduced?** One, deliberate and queued: SystemNix's age-based sweep vs monitor365's fingerprint-aware GC are two reclamation philosophies for the same disks — row 4 merges them.
- **Something useful removed?** Yes, on purpose: the cold-prune-ALL leg and the tmpfiles L+ rules. Both were destructive under measured conditions; their replacements are strictly safer, and the removal rationale is recorded in the module comment + storage.md + CHANGELOG.
- **Scope creep?** Held: monitor365 src/Cargo.toml/CI untouched (per the _ACTIVE NOT-touching list); SystemNix foreign overnight commits identified and not reviewed.

_WAITING FOR INSTRUCTIONS._
