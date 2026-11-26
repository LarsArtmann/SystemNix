# Status 2026-11-26 18:45: audiblesync is Forgejo-primary, the commit hook is unblocked, the llama idle checks read the journal for minutes on every run (fixed in tree, not live)

**Written:** 2026-11-26 18:45 CET (`date`), boot `0737ecd7` (31.6 h up), HEAD `982934d0a`, `master` 1 commit ahead of `origin/master`. Live system gen-1032 (profile and `/run/current-system` agree; switched 06:50 by a sibling). io PSI some avg10 read 32-49 in every reading of this leg.

**Trigger:** the owner answered question 3 of the [05:37 report](./2026-11-26_05-37_plan-v6-second-leg-t07-t08-live-t05-t06-t10-t11-landed-13-tasks-open-status.md) with "yes" (make `audiblesync` Forgejo-primary) and re-sent "get it all done".

**Plan:** [2026-11-25 00:06 SUPERB backlog masterplan v6](../planning/2026-11-25_00-06_SUPERB-backlog-masterplan-v6.md). Its marker still reads `EXECUTING`. Plan counts after this leg are unchanged from the 05:37 report: 7 done, 4 partial, 15 not started, 1 not due. T05's hook leg and ratchet are done; its strict harvest leg waits on T15.

## TL;DR

1. **`audiblesync` is Forgejo-primary since 07:24.** The flip ran with its dry-run twin first, the local clone's origin was switched in the same command, the next hourly sync exited 0, and a later real commit flowed Forgejo to GitHub (`2f104f2be50b` on all three, 16:11).
2. **Every commit through the hook was refused for ten hours, 02:01 to 12:01.** The bulk guard's selftest built a scratch git repo that inherited the hook's `GIT_INDEX_FILE`, wrote the scratch queue into the real index and failed its own leg. Fixed; proven with a real commit that passes and a real 60-row commit that is refused.
3. **The llama idle checks read the journal for one to two minutes on every run and never found a bridge.** One `llama-vlm-cap-idle` run read 72 GB. Both defects are fixed in tree and are not live.
4. **The all-systems flake check is green again (18:02).** Between 17:19 and 18:03 HEAD carried a parse error in `flake/parts/checks/selftests.nix` that this session wrote.
5. **The deploy is the owner's call.** The pressure gate refuses at io PSI some avg10 >= 20 %; readings were 32-49 and the crosscheck verdict is INCONCLUSIVE.
6. **Open owner questions:** the block ruling, the Borg key, and two consequences of the flip (section e).
7. **dnsblockd's GitHub twin was forced backwards twice.** Its flip to Forgejo happened without switching the local clone's origin, so the push mirror reverted GitHub's master on 2026-11-25 08:51 and 2026-11-26 10:11 CET. The clone's origin is switched now; a push of 356 local commits is owed.

## Scope: what was verified here, and what was not

| # | Claim | Command and result |
| --- | --- | --- |
| 1 | The flip preconditions held | `forgejo-flip-check@audiblesync.service`: `Result=success`, `DRY RUN: no changes made`; pre-state: `mirror: true`, master `89d2e04f05e3` on GitHub, on Forgejo and in the clone |
| 2 | The flip succeeded | `forgejo-flip@audiblesync.service`: `FLIPPED audiblesync: native + full import (branch=master issues=0) + push mirror attached`, 12.25 s |
| 3 | The repo is native now | sudo API probe: `mirror: false`, `id 549`, `has_actions: true`, master `028474df1ea5` (same sha on GitHub), dependabot branch `9b287b0d5c54`, 4 PRs (1 open) |
| 4 | The push mirror works | hand-triggered `push_mirrors-sync`: HTTP 200, `last_update 07:31:33`, `last_error ""`; later run `last_update 16:11:02`, `last_error ""` |
| 5 | A real commit flowed | Forgejo master, GitHub master and clone HEAD all `2f104f2be50b` at 18:38 |
| 6 | The hourly sync passes | `forgejo-github-sync.service` `Result=success ExecMainStatus=0` at 07:42:34; journal `✓ audiblesync: push mirror already attached`, `✓ audiblesync: master protected` |
| 7 | The clone pushes to Forgejo | `git -C ~/projects/audiblesync remote -v`: origin `forgejo@evo-x2.home.lan:lars/audiblesync.git`, github `git@github.com:LarsArtmann/audiblesync.git`; upstream `origin/master` |
| 8 | The hook refusal was the bulk selftest | `GIT_INDEX_FILE=<copy of the real index> bash scripts/check-todo-bulk.sh --selftest` before the fix: rc=1, `SELFTEST FAIL: exactly 50 staged open rows pass`, the copied index's `TODO_LIST.md` entry rewritten; after the fix: `SELFTEST OK`, entry untouched |
| 9 | The hook passes real commits again | `a7544a933` 12:01:58 through the hook; scratch worktree commit adding 60 open rows: rc=1 after 97 s, `FAIL: 60 staged open rows in TODO_LIST.md exceed the limit of 50` |
| 10 | The glob query's cost | `journalctl -u 'llama-chat@*.service' --since "60min ago" -n 1`: 66 s, 0 lines; a 10-minute window: 62 s; unit journal of each run: `Consumed … 3.2-4.1G memory peak, 1.9-2.4G read from disk`; `llama-vlm-cap-idle` 13:17:30: `72.2G read from disk` over 4 min 15.4 s |
| 11 | The glob query finds nothing | three windows, glob versus indexed match: llama-chat 10:00-10:59 CET, 0 versus 18 lines; llama-vlm-cap 11:00-13:40 CET, 0 versus 60 lines; an empty window, 0 versus 0 |
| 12 | The indexed match is cheap | built helper: `template-activity-since 'llama-chat@' 60min` 0.59 s rc=0; `'llama-vlm-cap@' 2h` 0.95 s rc=0; `'no-such-template@' 5min` rc=1 |
| 13 | Message ids were read from the journal | census over the 253 llama-chat bridges of the preceding 6 hours: `Starting` 253, `Started` 253, `Consumed` 253, `Deactivated successfully` 237, `Failed` 16, `Main process exited` 16, plus two single lines |
| 14 | The failed instances are deadline exits | `llama-chat@1326-…`: 08:18:15 to 08:48:15, status 1, 4.3 s CPU; `llama-vlm-cap@129-…`: 08:22:04 to 08:27:04, status 1 |
| 15 | The backend cannot start under pressure | `journalctl -u llama-chat.service --since "2026-11-25 20:01:00"`: 13 `Started`, 38 `Failed with result`, 1280 `WAIT` lines |
| 16 | The tree evaluates | `nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath`: rc=0, `ickjna6a4…` (18:14, idle-check fix included); `nix flake check --no-build --all-systems` inside the hook: passed (18:02) |
| 17 | The lint works both ways | `nix build --no-link .#checks.x86_64-linux.journal-glob-lint`: rc=0 on the tree; `CASES=journalglob bash scripts/negative-test-lints.sh`: 7 passed, 0 failed |
| 19 | dnsblockd is native with a push mirror | sudo API: `mirror: false`; push mirror `8h0m0s`, `sync_on_commit: true`, `last_update 10:11:26`, `last_error ""` |
| 20 | GitHub's dnsblockd master regressed twice | `gh api repos/LarsArtmann/dnsblockd/events` (UTC): `2026-11-25T07:51:37Z head=9fe62ce before=29bd806`, `2026-11-24T19:20:05Z head=29bd806 before=9fe62ce`, `2026-11-26T09:11:26Z head=9fe62ce before=389b6c0` |
| 21 | The clone was ahead of both twins | Forgejo master `9fe62ce7` (2026-11-10) = GitHub master at 18:42; `~/projects/dnsblockd` HEAD `5322c6b11760`, 356 commits later; its `origin/master` tracking ref `f5c159ce` dated 2026-11-26 |
| 22 | The locked input commit still exists on GitHub | `gh api repos/LarsArtmann/dnsblockd/commits/29bd80680cb9…`: HTTP 200 |
| 23 | The other canonical repos are in step | audit over the 20 entries of `services.forgejo.canonicalRepos` at 18:45, after the dnsblockd switch: 20 of 20 clone origins on Forgejo, 20 of 20 with Forgejo and GitHub at the same commit on the default branch; 7 clones ahead with unpushed local commits (dnsblockd 356, media-atlas 30, modloc 25, networking 7, three by 1) |
| 18 | The pressure class is not settled | `scripts/io-psi-crosscheck.sh verdict`: `INCONCLUSIVE: D-state tasks present with high PSI`; `full`: devices at most 7.4 % busy, ghostty terminal scopes at 27.6-75.6 % stall, D-state on `blkcg_punt_bio`, `flush-btrfs-2`, `events_freezable` and one `amdgpu_amdkfd_gpuvm_alloc_memory` in `llama-server` |

**Not verified:**

- How much of the 36-58 % io PSI baseline the idle checks contribute. They are a real burst source (288.9 MiB/s read on one NVMe at 67.2 % busy in a 20 s sample inside the 13:13 run). They are not proven to be the baseline: the 06:37 deploy log shows PSI 39 % with every disk at or below 1.9 % and the stall in the terminal scopes.
- That the idle-check fix behaves under the real units (needs the deploy). The built helper was run by hand only.
- Why the hook's flake check failed with `path '…-dashboards' is not valid` at 18:21-18:25 (section d1).
- The Borg 06:30 fire (not read in this leg).

## a) Live now

1. **audiblesync on Forgejo.** Sequence as run: dry-run twin first; first live attempt stopped by this session's own precondition (a sibling was mid-wave in the clone: four unpushed commits and a dirty file); second attempt 07:24: flip, then `git remote rename origin github` plus the new origin and `git branch --set-upstream-to`, in one command. The sibling's next pushes went to Forgejo and the mirror carried them to GitHub. Config comment now carries the real date; the runbook logs the flip; the row is closed on both queue surfaces; the macOS clone row names audiblesync.
2. **The commit hook.** `scripts/check-todo-bulk.sh --selftest` now unsets the inherited git environment before its first scratch command. Commit `a7544a933` was the first non-daemon commit through the hook since 02:01; between `db2576666` and it the history holds 35 daemon commits and no named one.
3. **Gate and probe.** `scripts/check-todo-system.sh` warns on a stale NOW bullet, a row-shaped bullet, a double cite, more than ten bullets and a bullet citing neither a row nor a document (three selftest legs). `scripts/session-start-probe.sh` groups failed template instances (`failed units: 38 — llama-vlm-cap@… 19, llama-chat@… 16, …`). Writing that line exposed a defect in the probe's first version: `systemctl --failed --plain` prints no state glyph, so the glyph filter matched nothing and the probe reported 0 failed units on a host with 37.
4. **Rows closed this leg:** the audiblesync row (queue and library), "Backlog size ratchet in scripts/check-todo-system.sh", "TODO gate and session-start probe: a NOW-block WARN leg and collapsed template instances". Ratchet cap lowered from 3558 to 3555. NOW block re-ranked to ten current pointers.
5. **All-systems flake check.** `memory-emergency-guard-host-shape-build` evaluated `pkgs.systemd` on aarch64-darwin and threw; it is Linux-only now with a named no-op on darwin (`982934d0a`).
6. **dnsblockd clone origin switched (18:44).** `git remote rename origin github`; origin `forgejo@evo-x2.home.lan:lars/dnsblockd.git`; upstream `origin/master`. Forgejo's master is an ancestor of the clone HEAD. Not pushed: this session does not push.

## b) In tree, waiting on a deploy or a commit

1. **Idle checks** (`1d6aa1cf8`, 13:33): `modules/nixos/services/_llama-idle-activity.nix` matches the bridge lifecycle lines by message id and filters on `UNIT`; both idle checks use it; both reset their template's failed state first. The toplevel evaluates (row 16).
2. **Failed-bridge sweep** (`8bcbcbd2c`): same idle checks, `systemctl reset-failed '…@*.service'`.
3. **journal-glob lint** with seven negative cases: in the working tree, not committed (section d1).
4. Siblings' work in the same tree: four canonical repos, the crash-capture path, ai-meter dashboards (mid-edit at writing).

## c) Not done, and why

- **Deploy.** Not attempted: the entry gate would refuse (PSI 32-49), the pre-switch gate reads again, and forcing is the owner's.
- **Plan v6 T12 to T27, T09's write-up, f5 (root backup chain).** Not started in this leg; the three findings of section d came first.
- **The three owner questions** were not acted on beyond the one answered.

## d) Findings for the next session

- **d1. The hook's flake check fails while dashboards are being edited.** At 18:21-18:25, with a sibling's three dashboard JSON edits uncommitted, the all-systems walk died in `checks.x86_64-linux.signoz-query-lint` with `path '/nix/store/krns6mj…-dashboards' is not valid`; the same walk passed at 18:02 and `nix build .#checks.x86_64-linux.signoz-query-lint` passed at 18:3x. `nix eval … signoz-query-lint.drvPath` left the path invalid. Root cause not proven (the check evaluates the dashboard rules over that directory at eval time). Effect while it lasts: every session's commit that touches an eval-relevant path is refused, and only the daemon's sweeps land. Row queued.
- **d2. The pressure baseline is not explained by disk load.** Disks were at most 7.4 % busy with PSI some 34 % and PSI full 18 %; the stalled cgroups are three ghostty terminal scopes, plus four D-state tasks. The llama backends' start gate (`psi-wait-gate --psi-max 30`) refused 38 of 51 starts since 20:01 on 2026-11-25, so the chat backend was down for most of the storm.
- **d3. This session tripped a fleet-wide fuse.** The first patch to `flake/parts/checks/selftests.nix` left a `;` before `else`. The batch printed `parse rc=1` and went on (it had been auto-backgrounded, so the line was read 25 minutes later); the daemon committed the broken file at `efb2be25e`. From 17:19 to 18:03 every `nix flake check` on the shared tree failed. Repair: `982934d0a`. AGENTS.md now says the parse step must restore and exit non-zero.
- **d4. A daemon commit's time is not its landing time.** HEAD was `efb2be25e` at 17:46:20 and `1d7a7ccc9` (dated 17:32:05) at 17:59, with content from before the 17:47 fix. Timelines built from `git log` dates alone mislead.
- **d5. Analysis one-liner with wrong field offsets.** The first IO sampler of this leg reported one process "writing 150 GiB in 12 s": its awk join read the wrong columns (cumulative totals against each other). Caught by reading `/proc/<pid>/io` directly. Rule stands: verify one known value through the pipeline first.
- **d6. The llama proxy row's premise was wrong.** The 29 min 59 s instances are the bridge's "backend unreachable" deadline (1800 s chat, 300 s vlm-cap), not idle-ended connections. Triage is in the library row; the vlm-cap deadline (300 s) is shorter than its backend's start gate (900 s), an open question.

## e) Owner asks

1. **Deploy.** `nix run .#deploy` is refused while io PSI some avg10 is 20 % or more (readings 32-49 all day). Either wait for a calm window, close the idle ghostty terminals the crosscheck names, or force with `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` after reading `scripts/io-psi-crosscheck.sh full` (verdict at 18:3x: INCONCLUSIVE). The deploy carries the idle-check fix, the failed-bridge sweep and the siblings' work since 06:50.
2. **Block ruling (unchanged):** keep, re-park, or re-park and stamp the 2026-11-07 block. Recommendation C.
3. **Borg key (unchanged):** re-store the original r2 private key, or generate a new pair.
4. **audiblesync on other machines:** a macOS clone, if one exists, must switch origin before its next push; the push mirror replaces GitHub-only commits.
5. **dnsblockd needs a push.** `git -C ~/projects/dnsblockd push origin master` (356 commits, fast-forward). Until GitHub catches up, do not float the SystemNix `dnsblockd` input: GitHub's master is at 2026-11-10 and the lock is at 2026-11-24.
6. **Dependabot on the audiblesync GitHub twin:** it will keep opening PRs there and the mirror keeps closing them, as on `domains` and `gogenfilter` since their flips. Remove `.github/dependabot.yml` there or leave it.

## Harvest log

- Minted: `docs/todo/stability.md` "Deploy the llama idle-check fix and verify: sub-second idle checks, no failed-bridge pile, keep-alive honored" (`[blocked:deploy]`, library only, section b1).
- Minted, queue and library: `docs/todo/pipeline.md` "Commit hook's flake check failed while dashboards were being edited: `path '…-dashboards' is not valid` (root cause open)" (`[ready]`, section d1).
- Annotated: `docs/todo/ai-stack.md` "llama-chat and llama-vlm-cap proxy instances fail with exit 1 after 30 minutes and pile up in the failed-unit list" (moved to the library as `[blocked:deploy]`, section d6).
- Annotated and retagged `[blocked:user]`: `docs/todo/services.md` "Execute forgejo-flip@dnsblockd once the dns-blocker wave lands" (flip is done; push and verification owed, section e6).
- Annotated: `docs/todo/services.md` "macOS clone origin switch for forgejo-canonical repos" (audiblesync joins, section e4).
- Deliberately not harvested: d2 (owned by the open ghostty CQ-waiter decision rows), d4 (no fix proposed; a one-line observation in this report), d5 (covered by the existing quote-scrutiny rule in AGENTS.md).
