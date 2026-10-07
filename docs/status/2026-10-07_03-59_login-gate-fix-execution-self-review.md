# Login-Gate Fix Execution — Self-Review of the Re-Dispatch (2026-10-07)

**Session phase 2:** 2026-10-07 ~03:50 → 04:01 — trigger: user directive "DO MORE RESEARCH AND IMPROVE THINGS FOR REAL" on the findings of `2026-10-07_03-36_systemd-optimization-followup-live-measure-self-review.md` (§f.1 HM gate diagnosis + §f.3 hook triage). READ → probe → fix → eval-verify → close-out, PSI-gated throughout. Tree anchor: fixes landed in daemon commit `cf8aa52e`, close-outs in `82476acf`.

**Scope:** this session's execution run and what I noticed about my own work. Nothing else researched.

## What was executed (summary)

Both dispatchable items from the 03-36 report were diagnosed to root cause, fixed, and eval-verified — but **not deployed** (IO PSI held 40-60% avg10 through the whole phase; the deploy's validation battery is the freeze-22 death class):

1. **96 s login gate** — mechanism proven at unit level: `activitywatch-theme.service` ALONE (Started 02:51:25.596 → Finished 02:53:01.743; server + both watchers ~1 ms). Unbounded curl POST (`--retry 5`, no `--max-time`) against a storm-slow aw-server; HM activation blocks on every enabled oneshot it starts. Fix: theme de-gated from HM activation → `systemd.user.timers.activitywatch-theme` (OnBootSec=2min, Persistent=false) + curl bounded (`--connect-timeout 3 --max-time 30`) — `platforms/common/programs/activitywatch.nix`.
2. **Dead hook** — `migrate-buildcache-fallback-caches` is the live 2026-09-22 cache-fallback convergence, a silent no-op since it landed (activate PATH has no util-linux → 4× `mountpoint` rc=127 → pre-creates AND reaps never ran). Fix: all 4 call sites → absolute `${pkgs.util-linux}/bin/mountpoint` — `platforms/nixos/users/home.nix:511`.

Since the 03-36 report's addendum already documents the execution in detail, this report is the **self-review layer**: what I got wrong, what stayed open, what to do next.

## a) FULLY DONE

1. Mechanism diagnosis (unit-level, journal-proven, candidates eliminated) + root cause of the dead hook (PATH-proven against the generated activate script).
2. Both fixes implemented and eval-verified: targeted HM-shape eval + FULL toplevel eval green (every assertion battery) + `nix fmt` 0-diff + alejandra standalone (daemon-race doctrine).
3. **Live guard proof (added for this review):** the exact fixed binary `/nix/store/vhz3kzcd…-util-linux-2.42.3-bin/bin/mountpoint -q` returns rc=0 on BOTH `/mnt/buildcache` and `/mnt/rust-cache` right now — the fixed guards will evaluate true on this machine, not merely render.
4. **Pool-mount timing closes the last inference chain:** `/mnt/pool` mounted 02:51:22.3→24.8; user-manager evaluated the activitywatch conditions at 02:51:23.1 (pre-mount → clean skip) and hm-activate started the units at 02:51:25.55 (post-mount → run). aw-server's 13 GB sqlite therefore began its cold open on the just-mounted, storm-choked pool exactly when the theme curl connected — the response-wait attribution is now backed by the elimination argument too (connrefused retries cap at ~10 s of the 96 s; connect succeeds once listening).
5. Close-outs on all four surfaces: report addendum, queue rows pruned (prune-wins contract), stability.md rows `[x]` with evidence, CHANGELOG `### Fixed` entry with post-deploy checklist. `check-todo-system.sh`: structure clean.
6. Deploy correctly NOT run under the PSI doctrine; deferral documented with a concrete post-deploy verification checklist.

## b) PARTIALLY DONE

1. **Runtime verification of the fix's core premise is still pending:** I verified EVAL shapes, but "HM activation no longer starts the theme unit" rests on the inference that HM only `systemctl --user start`s enabled units. I tried to pin the start-list computation from the deployed artifacts (activate script → hm-setup-env → generation) — the start logic lives outside the grep-reachable scripts (likely HM-internal helper); 3 probes, diminishing returns, stopped. Post-deploy journal check (`Starting units:` list must NOT contain activitywatch-theme) is the closure step — already in the CHANGELOG checklist.
2. **The deploy itself** — fixes live in-tree (`cf8aa52e`) but the RUNNING system still has the old theme unit enabled and the dead hook. Until deploy + HM activation, the 96 s gate and the hook landmine are both still live on every boot/activation.
3. Old report §g annotations — Q1 (activitywatch deferral) is mooted by the fix and Q3 (delete-vs-fix) is answered by execution, but the 03-36 report's §g text doesn't say so (the addendum covers substance, not the question list).

## c) NOT STARTED

1. Deploy + post-deploy verification + calm-boot re-measure (stability.md:169 — unchanged, correctly blocked on a calm window).
2. VM test for the new user-unit shape — deliberate skip (qemu builds on a storming box are the freeze-20/22 class; no existing test covers user units), but the skip was made silently, not documented with reasoning until now.
3. Everything else already queued (stampede admission, BIOS walk, verify sweep, boot-duration collector) — untouched, no drift introduced.

## d) TOTALLY FUCKED UP

1. **I closed both rows without queueing THE DEPLOY.** "Deploy pending a calm window" is unowned prose — exactly the pattern that left the hot-user-caches cycle fix in-tree-undeployed since 09-25 while its class kept biting. A fixed-but-undeployed login gate helps no boot. Fixed by this report's §f.1 (new [ready] row).
2. **Evidence-strength pattern recurred in softened form:** the addendum states the curl "connected but waited on its response" as fact; at writing time that link was inference (strong, but inference). I have since closed it (§a.4 pool-mount timing + retry-budget elimination) — but the honest write-up would have shown the elimination argument, not just the conclusion. Two reports in a row, same sin, smaller magnitude. The rule needs internalizing, not re-discovering: **state the proof, not the conclusion.**
3. Minor: two wasted `nix eval` invocations from tool-fumbling (wrong dag accessor `.text`, then a `2>/dev/null`-silenced pipeline with no output) — on a box at PSI 40-60, every extra eval is a small bet against the freeze doctrine. Won on volume, lost on form.

## e) WHAT WE SHOULD IMPROVE

1. **Every "fix landed, deploy pending" MUST mint or extend a [ready] deploy row with its checklist** — the dispatch loop's last step (land it) needs an owner. (Doing it now, §f.1.)
2. **Runtime-behavior claims about HM/systemd actors deserve the same live-state discipline as service claims:** read the actor's logic or label the claim as projected. My "HM activation should now complete at ~3 s" is a projection until the post-deploy journal proves it.
3. **Run the 2-second live checks when they exist** (the mountpoint rc=0 proof should have been in the original close-out, not this review).
4. **Annotate answered/mooted §g questions in prior reports** when later work resolves them — reports are one conversation.

## f) NEXT THINGS (self-harvested at authoring time)

1. **[ready] Deploy the login-gate fixes at the first PSI-calm window** (`nix run .#deploy`, expects rc=0 or documented rc; then the CHANGELOG `### Fixed` checklist: no `Starting units: activitywatch-theme` in the HM activation window, timer fires ~+2 min bounded, no `mountpoint: command not found`) → stability.md + queue. (§f.1)
2. **Extend stability.md:169** (re-measure row) with the theme-fix expectations + pointer to the CHANGELOG checklist so the re-measure ask knows what "deployed" now includes. (§f.2)
3. **Annotate the 03-36 report §g** (Q1 moot via timer, Q3 answered: fix-not-delete) — one-line appendix note each. (§f.3)
4. Post-deploy: pin the HM start-list behavior (the §b.1 gap) — journal evidence that enabled-set drives the start list.
5. Post-deploy calm boot: `systemd-analyze time` + critical-chain — userspace floor should now expose whatever follows HM (bank-sync [decision] row is the next known 47.7 s straggler).
6. Post-deploy: one clean `systemctl restart hermes` WAL-gate falsification check (stability.md:170, unchanged).
7. If the deploy surfaces the old theme unit still enabled after activation (HM wants-symlink migration doubt, §b.1): `systemctl --user disable activitywatch-theme` is the manual converge; file the HM-behavior finding either way.
8. Deliberately NOT queued: VM test for the user-unit shape (storm); activitywatch watcher wantedBy changes (explicitly forbidden by the 2026-08-18 black-screen comment in the module); any aw-server DB relocation (data-location is an owner call).

## g) QUESTIONS (cannot figure these out myself)

1. **Who/when deploys:** should the next calm-window agent session run `nix run .#deploy` for these two fixes autonomously, or do you want it bundled into your deliberate reboot window (deploy → reboot → re-measure as one quiet block, which also serves stability.md:169 and the boot-mirror PartUUID verify)?
2. **Reboot authority:** given 5 crashes since midnight, are reboots owner-only for now, or may a post-deploy session reboot to produce the calm-boot measurement?
3. **Eval floor policy:** my session ran 4 single `nix eval`s + `nix fmt` at PSI 40-60 (checked before each, never stacked, no builds/VM tests). The queued entry-gate rows propose ≥30 PSI admission for heavy jobs — do you want a hard interactive floor for agent evals too (e.g. "no nix eval above PSI 50 avg10"), or is single-eval-with-preflight the accepted line?

---
*Self-harvest: §f.1 → NEW [ready] row (both surfaces); §f.2 → extension of stability.md:169 + TODO_LIST re-measure one-liner; §f.3 → annotation of the 03-36 report. §f.4-§f.7 are post-deploy steps folded into §f.1's row/checklist — not separately queued. §f.8 records deliberate non-queues.*
