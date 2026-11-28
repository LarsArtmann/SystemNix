# Five stale FODs behind the 2026-11-28 deploys repaired (pdd shim dropped, pma + tq re-pinned, timesheets shimmed); toplevel green in a frozen worktree; deploy NOT fired

**Date:** 2026-11-28 06:14 CET (session ran ~04:31–06:14)
**Repo:** SystemNix @ `ff84ab102` (tree clean at report time). HEAD moved more than 15 times during the session; every move was a daemon "heuristic" commit carrying work from 5+ sessions (5 `crush` processes had this repo as cwd at 06:08).
**Trigger:** owner pasted the 03:47 deploy log (pre-deploy §11: 5 × "vendorHash STALE", `DEPLOY BLOCKED`) and typed `jfix`.
**Proven tree:** `6ad1f8253`, evaluated and fully built from a frozen worktree (`~/.cache/fodfix-20261128/wt`): drvPath eval rc=0, `--keep-going` toplevel build rc=0, 0 hash mismatches.
**Worktree state at report time:** main tree clean. One worktree of MINE is on disk and active: `~/.cache/fodfix-20261128/wt` (detached at `6ad1f8253`). It is this session, not a twin executor; it is removed at close-out.

---

## §0 The three questions — what I forgot, what I could have done better, what I can still improve

### What I forgot

1. **The deploy is not fired.** The blocker is gone and proven, but 80 minutes in the owner still has no deploy. The restraint was deliberate (two open decisions, §g) and unasked until now.
2. **The CHANGELOG entry.** I minted an upstream row whose `**Source:**` names a CHANGELOG entry ("Five stale FODs behind the 2026-11-28 deploys") that does not exist yet. That is a dead pointer for every reader until the entry lands.
3. **The two backlog rows are not ticked** (`TODO_LIST.md` "Batch-repair the FOD cluster …" + `docs/todo/pipeline.md` "FOD cluster from the 2026-11-28 lock waves …") although the row's own ask (batch-repair, re-prove the toplevel green) is met.
4. **No linter pass over the six edited files.** I ran `nix-instantiate --parse` and the locked formatter; deadnix, statix and the flake's lint-static check never ran. Daemon commits skip the pre-commit hook, so nothing ran them for me.
5. **No `nix flake check --no-build --all-systems`** (darwin eval unproven).
6. **I did not re-evaluate after the foreign eval break was fixed.** I saw the `ai-meter.nix` fix on disk at 06:10:15 and did not run an eval on it.
7. **I did not reconcile the build plan against the log**: the plan said "these 58 derivations will be built", the log shows 48 `building '…'` lines, exit rc=0. The gap of 10 is unexplained.
8. **I reformatted a line another session authored.** The scoped `nix fmt` over `lib/lars-packages.nix` also wrapped the buildflow shim line written the night before (whitespace only); it rode my daemon commit.
9. **I hand-typed one hash literal** (timesheets: no `*.nix` site carries the stale value, so `fod-hash-diff.sh` could not place it). It was verified byte-for-byte against the log afterwards, but the class is exactly what "never paste by hand" exists for.
10. **I did not check the other surfaces that describe shim state**: the `lib/lock-audit.nix` `timesheets.nixpkgs` deliberate entry (the runbook cites "vendorHash probed 2026-11-10 at 0304e2a"), and the pdd / pma / tq runbooks if they record the shim values.
11. **No lesson is written into `AGENTS.md` or `docs/agents/nix-flakes.md`** for what this session learned (§e).
12. **One wrong number reached my own eyes.** My first `/proc/diskstats` sample printed cumulative counters under `busy%` / `rMB/s` labels (wrong awk fields). I discarded it and did not quote it, but I had asked for it as evidence.

### What I could have done better

- **Gone to the worktree first.** The previous report's own doctrine candidate said so. My first eval ran on the shared tree and died rc=102 after 3m22s; the worktree eval passed first time.
- **Read the store before theorising about it.** The valid `7VswA7CM`-keyed pdd path was first read by me as "someone built it upstream". The deriver query showed the path's deriver is the derivation that specifies the OLD hash. The first reading was wrong and would have gone into this report unflagged.
- **Asked the origin question earlier.** I reached the deploy decision point at ~06:10; the report request arrived then. The two decisions in §g are the owner's, and I should have put them in front of you at ~05:55 when the shared tree turned out to be eval-broken by another session.
- **Shell discipline.** Four slips, all caught before a number was quoted: `rg -E` (that flag is an encoding), `-g '*.nix'` placed after `--`, an f-string with escaped quotes, and `echo rc=$?` after a pipeline (it reported `sed`'s rc, not the script's).
- **Batched the doc close-out with the repair** instead of leaving a dangling pointer behind the upstream row.

### What I can still improve (concrete)

1. Write the CHANGELOG entry (first action; it repairs the dead pointer).
2. Tick both FOD-cluster rows (full-line edits, both surfaces) with the close-out: repair done, proof at `6ad1f8253`, deploy receipt pending or landed.
3. Run deadnix + statix + lint-static over the six edited files.
4. Run `nix flake check --no-build --all-systems` from the worktree.
5. Fire the deploy on the origin you choose (§g.1) and carry it through post-switch verification.
6. Remove `~/.cache/fodfix-20261128/wt` when the repair closes; keep the logs in `~/.cache/fodfix-20261128/` until then.
7. Write the two one-line lessons (§e.6, §e.7) into `AGENTS.md` and `docs/agents/nix-flakes.md`.
8. Check and correct the `lib/lock-audit.nix` deliberate-entry text and the runbooks that record shim state.

---

## §a FULLY DONE

### a.1 Root cause: which lock waves staled which FOD (first-hand, lock history)

| Wave (commit, time) | Inputs it moved |
| --- | --- |
| 02:28 `ba3437f5b` | buildflow, pma `52322091 → 71795cc9`, timesheets `2697de8b → f22a31a`, pdd `a3ba4ea2 → 6b97c2cb`, go-taskqueue `af5b6ec5 → bd360ad5` |
| 03:33 `ec99c8956` | pdd `6b97c2cb → 5cbc99c`, go-taskqueue `bd360ad5 → c9f67c88`, four non-Go inputs |
| 04:47 `0b2965058` | monitor365 `9040947c → 4bd78837` only (landed during this session; no Go FOD) |

The 02:58 and 03:47 deploys failed on the same four FODs plus (after 03:33) go-taskqueue. No lock wave landed between 04:47 and report time.

### a.2 Drop-safety classification (first-hand: `git show <locked rev>:flake.nix` in the local checkouts)

| FOD | specified (before) | got (§11, two logs) | upstream bake at the locked rev | verdict | action |
| --- | --- | --- | --- | --- | --- |
| `project-discovery-daemon-5cbc99c-go-modules` | `FzTrkHOx…` (our shim) | `7VswA7CM…` | `7VswA7CM…` (flake.nix:76, "build: bump go-daemon to v0.5.0") | got == bake: drop-safe | shim **DROPPED** |
| `admin-5cbc99c-go-modules` | `FzTrkHOx…` (our shim) | `7VswA7CM…` | same shared bake | drop-safe | shim **DROPPED** |
| `projects-management-automation-71795cc9…-go-modules` | `IPEw5b8P…` (our shim) | `X0q2Dlin…` | `qofX4VUl…` (flake.nix:121) | got ≠ bake | **re-pinned** |
| `go-taskqueue-0.4.2-go-modules` | `HqHkPDVQ…` (our shim, REUSED in cache) | `fneDiCvx…` | `+JIm293yLj…` (flake.nix:78) | got ≠ bake | **re-pinned** |
| `timesheet-f22a31a-go-modules` | `5HuSKGky…` (upstream bake, no local site) | `VD4UNBfk…` | `5HuSKGky…` | bake stale upstream | consumer shim **ADDED** |

The timesheets bake was introduced at `1819c6e` (2026-11-22 18:35:52); the only later `go.sum` change is `d3b759d` (2026-11-27 18:40:47). So the bake predates the module change it is supposed to cover. That the upstream repo's OWN build is red at tip is an inference (non-follower input, identical derivation inputs); an own-checkout build was not run.

### a.3 Repair applied

- `scripts/fod-hash-diff.sh /var/log/systemnix-deploys/2026-11-28_03-47-10.log --apply` (after a report-mode pass that listed every site): 7 live lines in 4 files.
- By hand, each with its evidence and drop condition as a comment in the file's established form:
  - `lib/lars-packages.nix`: pdd → `flakePkg inputs.project-discovery-daemon` (shim gone); timesheets `overrideAttrs` gains `vendorHash`; the comment that claimed "upstream-baked vendorHash stays valid at branch tip" corrected.
  - `modules/nixos/services/project-discovery-daemon.nix`: daemon and admin packages un-shimmed (the shape of the 2026-11-18 drop); header comment corrected.
  - `modules/nixos/services/timesheets.nix`: `package` default gains the same `vendorHash` (same `overrideAttrs` on both surfaces, so one derivation).
  - `modules/nixos/services/projects-management-automation.nix`, `modules/nixos/services/tq-agent-pool.nix`: re-pin stamps.
  - `flake.nix`: comment only, on the `timesheets` input ("no consumer shim" is no longer true); written and `nix-instantiate --parse`d in one command.
- Daemon-swept commits: `6a70518cd` (04:51, the script's apply), `e9d33d83d`, `88bf5c881`, `df101c19b`, `973487038` (05:01, the formatter's two wraps).

### a.4 Proof of the literals

- The script's own parser extracted the 5 pairs from the log; each `got` was searched byte-exact in the tree: pma and timesheet and tq each on exactly their two surfaces; pdd on none (dropped), and equal to the upstream bake (1 occurrence at `5cbc99c`).
- None of the four stale literals remains in any `*.nix` file (count 0, four times). Remaining carriers are history and one test fixture (`scripts/test-pre-deploy-vendor.sh` uses `HqHkPDVQ…` as a fixture value, unrelated to the live shim).
- All six files parse; `nix fmt -- <six files> --fail-on-change` is clean on its second run.

### a.5 The toplevel is green at `6ad1f8253` (frozen worktree)

| Step | Time | Result |
| --- | --- | --- |
| shared-tree drvPath eval (`973487038`) | 05:04:18 → 05:07:40 | rc=102, "contents have changed during evaluation" (a parallel session committed `monitor365.nix` + `configuration.nix` at 05:06:58) |
| worktree drvPath eval (`6ad1f8253`) | 05:14:01 → 05:17:01 | rc=0, `…-nixos-system-evo-x2-26.11.20261121.2786a2a.drv` |
| worktree `nix build <toplevel> --keep-going --no-link --print-build-logs` | 05:19:02 → 05:54:05 | rc=0; plan "these 58 derivations will be built"; 48 `building` lines; 0 "hash mismatch"; 0 `^error` |
| toplevel output in the store | 06:10 | VALID (`66871j6i…-nixos-system-evo-x2-26.11.20261121.2786a2a`) |

The build included the four repaired Go packages compiling against their module trees (a stale-but-reused tree dies at compile time, the 2026-10-28 trap) and monitor365's cargo FOD after the 04:47 float. No eval warning names a repaired package.

### a.6 Docs on disk (committed by the daemon; tree clean at 06:14:48)

- `docs/services/timesheets.md` line 23: the "re-stales only when its own lock moves" claim replaced by the two real cases; the float command corrected to `nix flake update timesheets` (`nix flake lock --update-input` is a silent no-op on this nix).
- `docs/todo/upstream.md`: new `[blocked:push]` row, timesheets upstream re-measure + float + shim drop.
- `scripts/check-todo-system.sh`: rc=0, "OK: TODO queue/library structure clean", 94 unharvested §f reports before this report (93 at the previous report; the 03:47 report added one).

### a.7 A store observation worth knowing (inference, labelled as such)

Before my build, the FOD output paths keyed by the three got hashes (`X0q2Dlin…`, `VD4UNBfk…`, `7VswA7CM…`) were already valid, and `nix-store -q --deriver` names for each the derivation that specifies the OLD hash. My reading: nix kept the mismatching output of the failed §11 builds at the path its real content hashes to. Consequences seen: those FODs were not in the worktree build plan, while go-taskqueue's `fneDiCvx…` path (a REUSED FOD, never rebuilt by the gate) was built by my run. Not checked against nix's source. What it means for the deploy: §11's cached-FOD audit will not accept them by deriver identity and will check-rebuild four FODs (pdd daemon, admin, pma, timesheets) before it passes.

---

## §b PARTIALLY DONE

1. **The owner's deploy.** The blocker is removed and the tree is proven at `6ad1f8253`. Nothing is deployed: live system is still `system-1033-link` / `zp0384i8…`. Two decisions were open when the report was requested (§g).
2. **§11's own verdict on the repaired tree** is unobserved. The equivalent proof exists (the flake-attr toplevel build is the documented truth for FOD questions), but the gate's line "N realised + M verified" has not been printed for this wave.
3. **Verification depth.** Parse + formatter + full build at one commit. No linters, no all-systems flake check, no eval of anything after `0a8106116`.
4. **Docs close-out.** Runbook line and upstream row are in; the CHANGELOG entry and both row ticks are not.
5. **Live proofs.** None of the changed units has been observed after a switch, because there was no switch.

---

## §c NOT STARTED

1. The deploy itself and its post-switch verification (anchors, boot mirror, changed units, smoke test).
2. CHANGELOG entry "Five stale FODs behind the 2026-11-28 deploys".
3. Ticks on `TODO_LIST.md` and `docs/todo/pipeline.md` for the FOD cluster.
4. deadnix / statix / lint-static over the six edited files.
5. `nix flake check --no-build --all-systems`.
6. The `AGENTS.md` and `docs/agents/nix-flakes.md` lessons (§e.6, §e.7).
7. Staleness check of `lib/lock-audit.nix`'s `timesheets.nixpkgs` deliberate entry and of the pdd / pma / tq runbooks' shim-state text.
8. An own-checkout build of timesheets at `f22a31a` (to turn "the upstream bake is red upstream" from an inference into a measurement).
9. Upstream rows for pma and go-taskqueue (got ≠ bake on both; no row exists).
10. Removal of the worktree.

---

## §d TOTALLY FUCKED UP

1. **The deploy was not fired.** Eighty minutes of correct proof work, and the owner's request ("make the deploy go through") is still open. The last ~20 minutes of that were spent deciding alone what should have been a question to you at ~05:55.
2. **A dead `Source:` pointer is in the backlog now.** The upstream row cites a CHANGELOG entry I had not written.
3. **Intake is negative for this session until the tick lands**: 1 row minted (upstream, library-only), 0 closed.
4. **A foreign line was reformatted** by my scoped formatter run (buildflow shim, `lib/lars-packages.nix`); whitespace only, but it is another session's line in my commit.
5. **Four shell slips of the "quote-scrutiny" class** (§0), plus one garbage disk-stat sample that I had requested as evidence.

---

## §e WHAT WE SHOULD IMPROVE (process / doctrine candidates)

1. **Every feature session that floats its own input re-stales that input's FOD, and only a deploy finds out.** Tonight: 02:28, 03:33, 04:47; two owner deploys blocked; five FODs; three upstream repos whose bakes no longer reproduce under our graph. The enforcement-point question is an open `[decision]` row (`docs/todo/pipeline.md` "§11-after-any-lock-wave enforcement point"). It needs an owner ruling; nothing I can do closes it.
2. **The shared tree is not a deploy surface while 5+ sessions are active.** Observed in 110 minutes: one rc=102 (tree changed during my eval), one ~17-minute total eval outage caused by another session's in-flight edit (`ai-meter.nix`, top-level `inherit assertions;` beside an explicit `config`, 05:51 → fixed 06:08), and more than 15 HEAD moves. A frozen worktree passed every eval and build first time. The §11 tree stamp voids the battery on ANY eval-relevant mid-battery change, so a 21-minute battery on the shared tree is a coin toss tonight.
3. **`fod-hash-diff.sh` cannot place a shim when no `*.nix` site carries the stale literal** (timesheets). Its output says "add a consumer shim" but does not name the twin surfaces, and the literal ends up hand-typed. A mode that prints the surfaces (or inserts the shim) would remove the class.
4. **"Update BOTH surfaces together" is a comment convention.** pdd, pma, tq and now timesheets each live in `lib/lars-packages.nix` and in a service module. A per-package index of its shim surfaces (or the open twin-surface eval audit, `docs/todo/pipeline.md` "Eval-time audit: same `pname` reaching the toplevel with DIFFERENT vendorHash") would make a one-surface repair impossible instead of merely wrong.
5. **§11 proves go-modules FODs only.** monitor365's cargo FOD rode the 04:47 float unproven and happened to build (open row "Extend pre-deploy §11's FOD proof beyond go-modules").
6. **Lesson for `AGENTS.md` (session discipline):** when more than a couple of sessions are active, evaluate and build from a frozen worktree at a pinned commit, and read `nix-store -q --deriver` before explaining a valid path. Receipts: rc=102 at 05:07:40; foreign module error 05:56:31; worktree rc=0 05:17:01 and 05:54:05.
7. **Lesson for `docs/agents/nix-flakes.md`:** "NON-FOLLOWER, so the upstream bake stays valid" is conditional on the upstream re-measuring after `go.sum` changes. A daemon-committed upstream does not do that (timesheets `d3b759d`, 2026-11-27).
8. **The shim comment trail is not a reliable record.** The pdd comment in `lib/lars-packages.nix` said "got kEd17MIY" while the value on the next line was `FzTrkHOx…` (a value moved without its stamp, before this session). The receipt is the rev in the drv name plus the log file, as the drop-safety rule already says.

---

## §f Up to 50 things to get done next

**Close-out of this session (mine, in order)**

1. Write the CHANGELOG entry (repairs the dead pointer in the upstream row).
2. Tick both FOD-cluster rows in their final state (full-line edits on both surfaces).
3. Answer §g.1 and §g.2, then fire the deploy and watch it through battery, switch and smoke test.
4. If the origin is the live HEAD: re-prove it first in the worktree (drvPath eval + delta build); the ai-meter fix at `ff84ab102` is unevaluated by me.
5. If §11 voids on "eval-relevant tree MUTATED" or an eval dies rc=102: do not retry-loop; use `scripts/deploy-when-quiescent.sh --fire` or the frozen worktree.
6. Record the deploy's §11 verdict line (realised + verified counts) as the gate's receipt for this wave.

**Post-switch verification**

7. Profile anchor: `readlink /run/current-system` equals the newest `system-N-link` by number.
8. Boot-entry anchor: `preferred` in `/boot/loader/loader.conf` names an entry whose `init=` is the running store path.
9. Boot mirror: `sudo diff -rq /boot/loader/entries /boot-mirror/loader/entries` prints nothing.
10. Units live: project-discovery-daemon, project-discovery-admin, projects-management-automation, tq-api, tq-serve, tq-agent-pool, tq-bootstrap, timesheets (`/readyz` 200, `/version` = deployed rev), monitor365, monitor365-server, monitor365-graphical-helper, pim-sync (expected: skipped by ExecCondition while 5 materials are placeholders), llama-chat, ai-meter.
11. Read the first journal report of each unit that changed package this deploy (pdd 5cbc99c, pma 71795cc9, tq 0.4.2, timesheet f22a31a).

**Verification depth**

12. deadnix + statix + lint-static over the six edited files.
13. `nix flake check --no-build --all-systems` from the worktree.
14. Reconcile "58 will be built" against 48 `building` lines (plausible cause: another session built the same derivations concurrently, so my run skipped them; unverified).
15. Turn the "nix keeps a failed FOD's output at its got-hash path" reading into a fact (nix source or a tiny throwaway FOD) and write it next to the 2026-10-28 trap in `docs/agents/nix-flakes.md`.

**Upstream (owner-push)**

16. timesheets: `buildflow -s nix-hash-fix --fix` at tip, push, `nix flake update timesheets`, delete both shim lines (row in `docs/todo/upstream.md`).
17. buildflow: re-measure `vendorHash.nix` at `0e3622de` or later, push, float, drop the shim (carried from the 03:47 report, still open).
18. Decide whether pma and go-taskqueue get upstream rows too (their bakes do not reproduce under our graph; shims carry the drop condition only).

**Docs / memory**

19. `AGENTS.md`: one session-discipline line for §e.6.
20. `docs/agents/nix-flakes.md`: one line for §e.7 next to the non-follower doctrine.
21. Check `lib/lock-audit.nix`'s `timesheets.nixpkgs` deliberate entry and the runbooks that cite it.
22. Check whether `docs/services/` runbooks for pdd, pma and tq record shim values; stamp X0q2Dlin / fneDiCvx and the pdd drop where they do.
23. CHANGELOG line for the pim-sync enable (still missing from the 03:47 report).

**Process / owner rulings**

24. Ruling on "§11-after-any-lock-wave enforcement point" (`docs/todo/pipeline.md`).
25. Decide whether a frozen worktree may be the deploy origin during multi-session storms (it deviates from "deploy the checkout", and it was the only stable surface tonight).
26. Identify who floated the 02:28 wave (`ba3437f5b` moved five Go inputs in one lock commit; 03:33 and 04:47 look like targeted per-input floats by feature sessions).
27. `fod-hash-diff.sh`: print (or insert) the consumer shim for a no-site literal and name the twin surfaces.
28. FOD shim-surface index, or land the twin-surface eval audit.
29. §11 beyond go-modules (open row).

**Harvest debt**

30. The unharvested §f count was 94 before this report and rises by one with it (expected 95, not re-measured). "Run a dedicated unharvested-§f-report sweep" is in the NOW block.

**Noticed, foreign, left alone**

31. `~/.cache/sn-verify` is another session's worktree (created 04:48:46, moved to `87504d9ef` by 06:14).
32. Pre-existing eval warnings on evo-x2: cv-server graphrag keys inert; stray units forgejo-dump, systemd-tmpfiles-clean, tmpfiles-clean-debug; catalog subdomains without entries; caddy ghost entry `nsfw`; `services.pipewire.jack.enable` deprecated.
33. Riding the next deploy from other sessions: monitor365 "every collector runs" (owner decision 2026-11-28), pim-sync enabled in dry-run behind the secret gate, llama-chat on the iGPU, and (once green) the ai-meter priority / quota options.

---

## §g Three questions I cannot answer myself

1. **Deploy origin.** Do I fire from the frozen, fully built snapshot `6ad1f8253` (every eval and the whole build passed there; it excludes the ai-meter options another session is iterating on), or from the live HEAD once it is green (carries everything, but any eval-relevant commit by the other sessions during the ~21-minute battery voids §11)?
2. **Pressure token.** Your two attempts used `DEPLOY_FORCE_PRESSURE=2` at io PSI ~45 % / disk ~101 % / 15–17 guard trips per hour. Now: io PSI avg10 23.5 %, avg60 30.4 %, disk busy not re-sampled, 4 trips in the last 60 min. Do I use `=2` again as you did, or wait for a calm window (the next lock wave can re-stale the FODs while waiting)?
3. **timesheets upstream.** May I commit the re-measure locally in `~/projects/timesheets` (a parallel session has uncommitted test edits there; the daemon would batch both into one commit), or is that strictly your push-time step?

---

## §h Harvest record (self-harvest at authoring time)

| Follow-up | Where it landed |
| --- | --- |
| timesheets upstream re-measure, push, float, drop both shim lines | `docs/todo/upstream.md` `[blocked:push]` row (library-only per the routing rules) — minted this session |
| FOD cluster rows (`TODO_LIST.md` + `docs/todo/pipeline.md`) | **Not ticked in this pass**, deliberately: the instruction was report-then-wait. The row's own ask is met (repair done, toplevel green at `6ad1f8253`); the deploy receipt is not. Tick both surfaces first thing. |
| CHANGELOG "Five stale FODs behind the 2026-11-28 deploys" | **Not written**, and already cited by the upstream row. First action after this report. |
| Deploy-origin doctrine, `fod-hash-diff.sh` no-site mode, shim-surface index, pma/tq upstream rows | Deliberately not harvested: intake (1 row minted, 0 closed until the tick) and each needs an owner ruling; carried in §e and §f. |
| The two lessons (§e.6, §e.7) | Deliberately not harvested: they are one-line doc edits for the close-out pass, listed in §f items 19–20. |

---

## §i Addendum 2026-11-28 11:50 — the repaired set is exposed again; a parallel session owns the re-repair

- **A blanket lock wave landed after the proof.** Between `6ad1f8253` (proven) and `44a19b11a` (11:18) 44 lock nodes moved (first-hand: `flake.lock` parsed at both revs): root `nixpkgs 2786a2a → 58d0d3e` (re-tools every go-modules FOD), `projects-management-automation 71795cc → 8a91533`, `timesheets f22a31a → 46da16c`, `buildflow 0e3622d → 2cc0389`, node `project-discovery-daemon_3 5cbc99c → 98426e7`, plus the new `reports-system` input. Three of the five repairs above are therefore open again (pma, timesheets, pdd) and nothing at the new lock has been enumerated or proven by me. The proof in §a.5 covers `6ad1f8253` only.
- **Five deploy attempts by other sessions since the report; none reached the FOD set** (logs in `/var/log/systemnix-deploys/`): 08:00:42 exit 12 (io PSI 48.97% with disk busy 83.3%, 5 guard trips in 60 min), 08:07:40 exit 1 (eval red: `attribute 'reports-system' missing` at `modules/nixos/services/reports-system.nix:62`, so the §11 dry-run, §13 and §14 could not evaluate), 09:30:16 exit 12 (entry gate), 09:33:12 exit 1 (eval red: `cannot coerce a list to a string: [ ]` through the `session-boot-audit.nix` assertions; sops manifest red on `sops.templates.ai-meter-config.content`), 11:26:54 exit 12 (guard tripped 10× in 60 min). Live system unchanged: generation 1033.
- **A parallel session is enumerating the set right now.** `/proc` forensics at 11:40: `bash scripts/pre-deploy-check.sh --section-11-only` started 11:38:34 in the shared tree by crush PID 1301182 (sshd → fish → crush), already in `nix-store --realise --keep-going` on `forgejo-runner-13.2.2-go-modules.drv`, `buildflow-2cc0389-go-modules.drv` and the rest of the list. **I am standing down from a second enumeration or repair of the same shim lines** (twin-edit risk on `lib/lars-packages.nix`, and FOD builds stacked on a box at 10 guard trips an hour). The cluster rows stay open until that re-repair is proven at the current lock; whoever lands it ticks both surfaces.
- **Still the owner's:** the pressure override (every attempt since 08:00 needed `DEPLOY_FORCE_PRESSURE=2` or a calm hour) and the timesheets upstream re-measure (§g item 3).
