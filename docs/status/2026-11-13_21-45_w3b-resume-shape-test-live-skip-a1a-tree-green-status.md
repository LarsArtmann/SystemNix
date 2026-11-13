# 2026-11-13 21:45 — W3b resume: shape-test root-caused+fixed, live-skip verified LIVE, A1a tree-green, rows ticked

Session scope: resumed the paused W3b/A1a handoff (report 10:48) under the owner's standing GO.
Absorbed the parallel gen-1005 deploy, diagnosed and fixed the 5 red shape-test legs, verified the
crush-hot-db live-skip guard LIVE on the deployed generation, ticked the plan rows, and minted a
pipeline gap row. Times CET.

## a) Task & verdict

**Verdict: A1a TEST-GREEN + W3b LIVE-SKIP VERIFIED LIVE + rows ticked. The full `--all-systems`
sweep is BLOCKED by a foreign in-flight break (immich), not by A1a surfaces.**

## b) Resume-gate findings (owner questions resolved by events)

1. **§g.1 (cvagent serve posture) — answered by events**: the gen-1005 activation restarted serve
   10:31; it re-entered the loop (236G read / 164G written over 4h43m — the row's exact prediction);
   the deploy session stopped it 15:10 per my W3b row's standing authorization. Unit inactive now.
   Default posture holds: stopped pending the upstream full-scan fix; the next deploy's activation
   will restart it again — the standing watch-and-stop row (TODO_LIST:3549) owns that.
2. **§g.2 (DEPLOY_FORCE_PRESSURE) — MOOT**: the owner personally fired `DEPLOY_FORCE_PRESSURE=2`
   at 01:29; deploy #3 landed 10:31 as gen system-1005 (`d825m2l3`), anchored by-number, smoke
   170 PASS / 6 FAIL all-attributed (their reports 14:40 + 15:12). The question has evolved into
   the 15:12 report's §g Q1 (gate split phantom/real) — still owner-open, not mine to decide.
3. **§g.3 (monitor365-ui-sdk 21:48 stranding)** — STILL UNANSWERED (re-asked in §g below).
4. **Watcher v4** (pid 461418, armed 10:48) never fired — windows lost to PSI/head movement all
   afternoon. Killed at resume: the deploy it waited for had already landed via the parallel
   session. No double-deploy risk from it anymore.
5. **Anchor/timer/CAP live state (verified this session)**: `readlink /run/current-system` =
   `d825m2l3…` = newest gen BY NUMBER (system-1005-link); `crush-hot-db-migrate.timer` NEXT armed
   Sat 2026-11-14 04:10; `systemctl cat` shows `CapabilityBoundingSet=…cap_sys_ptrace` (the W3b
   fix IS deployed); wifi-failover active; zero warning-journal entries for
   crush-hot-db-migrate/wifi-failover since the 10:31 switch.
6. **gen-1005 does NOT carry A1a** — the delegation layers landed on disk ~10:45+, after the
   10:25/10:31 deploy fired/switched. A1a rides the NEXT deploy.

## c) The shape-test 5-red-legs diagnosis (FIRST code task — closed)

**Root cause: red-on-arrival; the A1a delegation is innocent.** Chain of evidence:

1. Reproduced: `nix build -L --no-link .#checks.x86_64-linux.systemd-shape-audit` → builder exit 1,
   `FAILED for: allowlist-not-honored, pathchanged-falsely-flagged, clean-timer-oneshot-falsely-flagged, percent-h-falsely-flagged, runtime-dir-cleared-falsely-flagged` (the exact 5 from the handoff).
2. Evaluated the 5 failing fixtures directly (throwaway getFlake harness, `~/.cache/shape-diag.nix`):
   EVERY fixture's only audit failure is the same assertion —
   `systemd-shape-audit: boot-blocking Type=oneshot unit(s) with unbounded TimeoutStartSec:
   linger-users, logrotate-checkconf, post-boot, resolvconf`.
   The bare `nixosSystem` fixture eval includes the nixpkgs base module set, whose 4 boot-blocking
   oneshots are unbounded; the real host floors them via `serviceOneshotDefaults` (5min mkDefault),
   which a bare eval lacks — hence evo-x2 parity byte-identical while fixtures fail.
3. Why exactly those 5 legs: they are the zero-failure legs (`failing … == [ ]`); the
   expect-flagged legs pass because their classes (1-6) precede class 7 in the assertion list, so
   the class-7 noise never becomes `head` there.
4. Delegation innocence proven: class-7 walk byte-equal (whitespace-normalized) between the
   pre-delegation in-tree module (928ecd774) and the collection copy at 46e36b7; the whole module
   body diff is formatting-only (wrapper + alejandra style).
5. **Fix** (`tests/test-systemd-shape-audit.nix`): floor the 4 base oneshots with explicit
   `TimeoutStartSec = "5min"` inside `evalAssertions` — the collection contract-check idiom
   (same four floored there on unstable). Deliberately NOT `allowUnboundedOneshot`: when the
   nixpkgs pin moves and grows a NEW unbounded base oneshot, the check must go red on purpose.
6. Verify: shape-audit build rc=0; tmp-cleaner sibling rc=0; `nix fmt --` no-op (0 changed).

### c.1 Pipeline gap exposed (row minted, pipeline.md + TODO_LIST twin)

The red test sat **~11h unnoticed** (05:24 extension → 16:4x catch) because NOTHING builds
`checks.*` derivations: the pre-commit hook and CI eval legs run `flake check --no-build` (pure-eval
legs are builder-time, never forced), nix-check.yml builds only VM tests — AND
`scripts/lib/eval-relevant-paths.sh` omits `tests/`, so the hook's eval leg is SKIPPED entirely on
tests-only commits. Fix row: checks-build CI job + `tests` in EVAL_RELEVANT_PATHS.

## d) Live-skip verification (W3b close-out leg — GREEN, live on gen-1005)

No natural pair existed (all live sessions already on the hot tier), so I synthesized one:

- Scratch project `~/projects/live-skip-verify/.crush/` with `crush.db`+wal, mtimes 2h old
  (clears the 10-min fresh-write window, verified from the DEPLOYED script at
  `/nix/store/l6z87cgh…-crush-hot-db-migrate-start`).
- Holder: copied bash named `crush` (comm=`crush`), fd 9 on the scratch db, held via a
  `run_in_background` job running `while true; do sleep 60; done` (loops survive bash's
  last-command exec optimization; verified `/proc/3587590/comm`=crush, fd9→scratch db).
- `sudo systemctl restart crush-hot-db-migrate.service` (21:14:10):
  **`skip live-skip-verify: live crush session holds it open`** — plus, unprompted, the guard
  correctly skipped 3 REAL live sessions (`audiblesync`, `graph-features-language`, `legal-cases`),
  fresh-write-skipped `touchbase`, manual-merge-refused `games`, relocated 0, exit 0. The DBG scan
  line shows the holder's fd list read fine under yama ptrace_scope=1 — the exact regime that
  blinded the historical 3-cap set.
- Cleanup verified: holder killed, scratch + helper trashed (trash, not rm), no
  `/mnt/hot/crush/live-skip-verify` residue, no fd residue in any crush pid.

## e) Verification ledger

| Surface | Verdict |
| --- | --- |
| shape-audit negative test | build rc=0 (was exit-1 on 5 legs) |
| tmp-cleaner-audit negative test | build rc=0 |
| evo-x2 parity (A1a) | byte-identical 2675/0 (pre-pause, still valid — delegation surfaces unchanged since) |
| live-skip guard | live-proven 21:14 (§d); 0 relocated; timer NEXT Sat 04:10 |
| anchor | gen-1005 by-number = `/run/current-system` (parallel session's deploy, verified) |
| full `nix flake check --no-build --all-systems` | **rc=1 — FOREIGN**: `systemd.immich-api-key-provision does not exist` (immich.nix, parallel session's 19:29/20:32 commits; their pipeline row confirms "immich eval repairs" in flight). Hands off; re-run after their fix lands. |
| CI (nix-check) | red all day on VM-test builder failures + eval legs — already queued in pipeline.md rows (not mine) |

## f) Harvest ledger

- TICKED both surfaces: shape-test 5-red-legs row (TODO_LIST:3550 + upstream.md:411) with full
  resolution narrative.
- ANNOTATED both surfaces: plan-waves row (TODO_LIST:677 + upstream.md:402) — W3b landed +
  live-skip verified; A1a tree-green, rides next deploy; next = A1b.
- ANNOTATED storage.md:69 (VM-tests row) with the live proof; row stays open for the VM BUILDS.
- MINTED: CI-checks-build + EVAL_RELEVANT_PATHS gap (pipeline.md EOF + TODO_LIST twin).
- Deliberately NOT harvested: the immich eval break (owning session actively repairing it —
  their pipeline row says so); the nix-check/VM CI cluster (already queued by the deploy session);
  the 15:12 report's 50-item list (owned there).

## g) Owner questions (carried)

1. **monitor365-ui-sdk 21:48 stranding** (re-asked from 10:48 §g.3, origin 01:00): the
   cap-blind-era live relocation left that project's session DB state needing a ruling — same
   manual-merge class as today's `games` skip (`target /mnt/hot/crush/games already exists
   (manual merge needed)`). What's the desired disposition: manual merge, or drop the hot-side
   copy and let the next run converge?
2. cvagent serve: stays stopped per the standing row unless you say otherwise — the next deploy
   activation WILL restart it (the row prescribes watch-and-stop).

## h) Mistakes owned

1. First diag attempt piped `nix eval` through a python parser — the eval error was swallowed by
   the pipe and I nearly read "empty" as data (my own no-masked-verdicts rule). Re-ran with
   separated stdout/stderr rc-cited.
2. `cp $(which sleep) lskv/crush` → `coreutils: unknown program 'crush'` — multicall binary
   dispatch; switched to a copied bash (argv0-agnostic ELF).
3. `setsid … &` holders never survived the tool shell (silently reaped); and the first
   run_in_background holder tail-exec'd into `sleep` (comm=sleep, the comm=crush layer gone).
   Working shape: run_in_background job exec'ing a copied bash running a `while/sleep` loop.
4. `systemctl start` on a RemainAfterExit oneshot that is `active (exited)` is a NO-OP — the
   21:1x "run" never ran (status showed the 16:35 invocation). Restart required.
5. Two edit-tool races (TODO_LIST, test file mtimes moved mid-flight) — both handled by fresh
   VIEW reads before re-applying; no corrupted rows.

## Next

A1b (mount-gating 163 + memory-watermark 142 + dynamic-user 88 + capability-grant 111; rpi3-dns
eval too) per `docs/planning/2026-11-10_05-07_SUPERB-nixos-module-collection-extraction.md`,
collection-side first, then the SystemNix burst — A1a rides the next deploy window.
