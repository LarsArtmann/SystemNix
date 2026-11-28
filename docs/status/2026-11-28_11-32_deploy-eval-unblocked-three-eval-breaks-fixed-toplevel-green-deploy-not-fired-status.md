# Deploy eval unblocked: three eval breaks behind the 09:33 `DEPLOY BLOCKED` fixed (session-boot-audit split crash, ai-meter toJSON precedence, reports-system-backup-dir audits); toplevel evaluates green; deploy NOT fired (storm gates)

**Date:** 2026-11-28 11:32 CET (session ran ~09:50 to 11:32)
**Repo:** SystemNix @ `3f9d2145e` (tree clean at report time). HEAD moved 14 times during the session; every move was a daemon "heuristic" commit carrying work from several parallel sessions.
**Trigger:** owner pasted the 09:33 deploy log (`nix flake update && DEPLOY_FORCE_PRESSURE=2 nix run .#deploy`, HEAD `302b798`, "149 passed, 362 warnings, 4 failed", `DEPLOY BLOCKED`) and typed `fixfix`.

---

## Scope line: what this report verified, and what it did not

**Verified here (fresh commands, this session):**

| Claim | Command or artifact | Result |
| --- | --- | --- |
| Sops manifest evaluates (battery failure #19, eval leg) | `nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.sops-nix-manifest.drvPath`, 11:05:48 to 11:05:59 | rc=0, `/nix/store/ipl6np51x8gvpk27m29cli5wib7k792g-manifest.json.drv` |
| The original "cannot coerce a list to a string" crash and the sops "expected a set" error are gone; two masked assertions surfaced | `nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath`, run 1, 11:09:50 to 11:10:55, HEAD `aa7d993` | rc=1, "Failed assertions: io-tier-coverage-audit … reports-system-backup-dir; deploy-restart-audit … reports-system-backup-dir" (log: `~/.cache/deployfix-20261128/toplevel.err`) |
| The evo-x2 toplevel evaluates (battery failure #2; assertions, sops manifest, #11's dry-run input) | same command, run 2, 11:21:13 to 11:24:22, HEAD `44a19b1` before AND after, tree clean | rc=0, `/nix/store/2189dy135skafpsjsz9kcwbf83h6617f-nixos-system-evo-x2-26.11.20261124.58d0d3e.drv` (log: `~/.cache/deployfix-20261128/toplevel2.err`) |
| `lib.split` separator shape on this nix (2.35.6) | `nix eval --impure --expr 'builtins.split "[[:space:]]+" "a b"'` | `[ "a" [ ] "b" ]` (separators are empty lists, not null) |
| The `//` precedence bug reproduces in isolation | `nix eval --expr 'builtins.toJSON { a = 1; } // { b = 2; }'` | `error: expected a set but found a string: "{\"a\":1}"` |
| The 06:14 "toplevel green" proof did not cover the ai-meter break | `git merge-base --is-ancestor ff84ab1 6ad1f82` (false) and `git show 6ad1f82:modules/nixos/services/ai-meter.nix` (no `quotaSource`) | proven tree `6ad1f82` contains neither `0a81061` nor `ff84ab1` |
| Lock movement since that proof | python diff of `flake.lock` nodes, `da6239c` against HEAD at about 10:00 | 44 nodes changed (43 moved, 1 new: `reports-system`) out of 637 |
| Edits are syntactically and stylistically valid | `bash -n scripts/deploy.sh`; `shellcheck -S warning scripts/deploy.sh`; `nix-instantiate --parse` on both `.nix` files; `nix fmt -- modules/nixos/services/io-tier-coverage-audit.nix --fail-on-change` | all rc=0; formatter "0 changed" |
| Running system unchanged and anchored (11:06 and 11:32) | `readlink /run/current-system`, newest `system-N-link` by number, `/proc/cmdline` | all three name `…-nixos-system-evo-x2-26.11.20261121.2786a2a` = `system-1033-link` |
| The box reset mid-session | `journalctl --list-boots`, kernel log of boot 0 | boot `-1` ended 10:43:28, boot `0` started 10:46:06; "Previous system reset reason [0x02000800]: hardware watchdog timer expired" |

**NOT verified here:**

- **The pre-deploy battery as a whole.** No deploy reached the validation battery after the fixes. The 11:26:54 attempt (not started by this session) was refused after 1 s at the ENTRY guard trip-recency gate (exit code 12, `/var/log/systemnix-deploys/2026-11-28_11-26-54.log`). So check #1 (`nix flake check --no-build`) and #11 (vendorHash freshness) are inferred green from the toplevel eval, not proven by the battery.
- **Check #19's build leg** (`sops-install-secrets -check-mode=sopsfile`): only the manifest's evaluation was proven.
- **Stale go-modules FODs after the lock waves (#11):** not probed. Probing means realising FODs (builds) on a box that was 35 minutes past a watchdog reset in an IO storm.
- **Negative tests and selftests** (`scripts/negative-test-lints.sh`, `flake/parts/checks/selftests.nix`) and the darwin eval (`--all-systems`): not run.
- **The regression test another session added** (`tests/test-session-boot-audit.nix`, case `multi-token-directive-line-not-caught`): read, not run.
- **Which unit carries the multi-token directive line** that tripped the session-boot-audit crash: not identified.
- **Cause of the 10:43 watchdog reset and of the ongoing IO storm:** not investigated beyond the read-only samples quoted in §d.1 and §d.2.
- **No deploy was fired by this session.** Nothing was switched.

---

## §0 The three questions

### What did you forget

1. **`scripts/session-start-probe.sh` was never run** (AGENTS.md "Session Discipline" asks for it at session start).
2. **The boot id was not re-pinned when the session resumed after the reset.** I only noticed the reboot because the `/proc/pressure/io` `total` counter had dropped (117471474904 at 10:40, 554132588 at 11:05), about 20 minutes after it happened.
3. **No commit carries the reasoning.** All three fixes rode message-less daemon commits (`e6e051a`, `aa7d993`, `44a19b1`). The "why" lives only in this report. The repo's own rule is to re-message such commits; the harness forbids commits without an explicit request, so I left them.
4. **No CHANGELOG entry, no lesson in `docs/agents/nix-flakes.md`, no TODO rows** for what this session learned. The follow-ups are listed in §f and deliberately not harvested (see the note under §f).
5. **`nix fmt -- --fail-on-change` is not a dry check.** It reformats first and exits 1 afterwards. It rewrote 529 lines of `ai-meter.nix` (other sessions' unformatted hunks) and the daemon committed that together with three foreign files (`aa7d993`). I tried to drop it a minute too late.
6. **My first IO sampler was wrong.** It read `/proc/<pid>/io`, which is unreadable for root-owned processes, and printed an all-zero "top" list. I discarded it, but a root-caused storm was exactly the case it could not see. The `io.stat` cgroup sampler replaced it.
7. **A tool-output redactor mangled a diff line** ("multi-token value)" came back as "multi-token=REDACTED"). I re-read the file from disk before believing it; worth knowing that displayed diffs can be rewritten.

### What I could have done better

- **Probe first, theorise second.** I spent a long time reasoning about Nix precedence and about `lib.split` semantics and got both wrong at first (`or` binds tighter than `++`; separators are `[ ]`, not null). Two one-line `nix eval` probes settled each in seconds.
- **Ask nix where its inputs live.** Six tool calls went into globbing `/nix/store/*-source` on the false assumption that inputs carry `.git-revision` (one loop even used basenames without the store prefix). The answer was one `nix eval --impure` with `builtins.fetchTree <locked attrs>`, 11 seconds.
- **Re-read files that another session touched.** `session-boot-audit.nix` changed under me at 10:03 while I was still deriving the cause of its crash. A parallel session had already fixed it. Pinning HEAD before each step caught it, but about ten minutes of analysis were wasted on a solved problem.
- **Time.** About 95 minutes from start to a green toplevel for what is a two-line fix plus two list entries. Most of the time went into the two detours above while the owner had no deploy.
- **The proof eval ran on the shared tree**, not a frozen worktree (the 06:14 report's own doctrine candidate). It passed with HEAD unchanged, so no harm, but the risk was taken knowingly.

### What I can still improve (concrete)

1. Write the one-line lesson into `docs/agents/nix-flakes.md`: `builtins.toJSON { … } // x` applies `//` to the JSON string; a frozen-worktree "green" proves only the commit it froze.
2. Add a `lint-static` pattern for `toJSON {` blocks closed by `} //`, and a selftest pinning the `lib.split` separator shape the session-boot-audit relies on.
3. Run the negative tests and `nix flake check --no-build` in the first calm window, and fire the deploy unforced (§f.1, §f.4).
4. Clean up `~/.cache/nixsrc-list.txt` (stray file outside the topic dir `~/.cache/deployfix-20261128/`).

---

## §a FULLY DONE

### a.1 Root cause of failure #19 (sops gate): `builtins.toJSON { … } // quotaSource` in `modules/nixos/services/ai-meter.nix`

- Function application binds tighter than `//`, so the update operator ran on the JSON **string**: `expected a set but found a string: "{…}"` while evaluating `sops.templates.ai-meter-config.content`. Reproduced in isolation (scope line).
- Introduced by `0a81061` (05:51, quota-source work of another session). Dormant today: no `quotaSource.enable` and no `quotaProvider` anywhere under `modules/`, `platforms/`, `systems/` (rg), so `quotaSource` is `{ }`.
- **Fixed** by me: `proxyConfig = builtins.toJSON ( { … } // quotaSource );`. Two-line edit committed by the daemon as `e6e051a` (11:01:02); the formatter's re-indent of the file's older unformatted hunks rode `aa7d993` (11:08:12).
- Evidence: manifest eval rc=0; toplevel eval run 2 rc=0.

### a.2 Root cause of failures #1, #2, #11: session-boot-audit crashed on `lib.split` separators

- `splitTokens` in `modules/nixos/desktop/session-boot-audit.nix` kept every element with `t != ""`. On nix 2.35.6 the separators of a capture-free `lib.split` are `[ ]` (empty lists), which pass that test; `canonical` then calls `stringLength [ ]` and the eval dies with `cannot coerce a list to a string: [ ]` inside `lib.asserts.checkAssertWarn` (`nixos/modules/system/activation/top-level.nix:64`). One crash, three battery failures: flake check, evo-x2 eval, and #11's toplevel dry-run.
- **Fixed by a parallel session**, not by me: `c8bb36e` (10:03:45) filters `builtins.isString t && t != ""`; `057ac28` (10:09:17) adds the regression case `multi-token-directive-line-not-caught` to `tests/test-session-boot-audit.nix`.
- My part: confirmed the separator shape with a probe (scope line) and confirmed the guard now evaluates and passes (toplevel run 2 rc=0).

### a.3 The two assertions the crash had masked: `reports-system-backup-dir`

- Surfaced in toplevel run 1 (rc=1). The unit comes from `modules/nixos/services/reports-system.nix` (another session's new service, enabled in `d7b4838` at 09:48).
- `io-tier-coverage-audit`: boot-gated unit without an IO tier. **Fixed** by me: allowlisted in `modules/nixos/services/io-tier-coverage-audit.nix` (lines 131 to 133, with a justification comment), the same metadata-only group as its 15 sibling `*-backup-dir` units (`mkPoolDirUnit` is mkdir + chown on the HDD pool).
- `deploy-restart-audit`: converger oneshot missing from `scripts/deploy.sh`. **Fixed** by me: added to the provisioner restart loop (line 996) with a comment (lines 1033 to 1034).
- Both landed in the daemon commit `44a19b1` (11:18:36). `bash -n`, `shellcheck -S warning`, `nix-instantiate --parse` and the pinned formatter all pass.
- Evidence: toplevel run 2 rc=0 at `44a19b1`.

### a.4 Running system untouched and anchored

- Still generation 1033 (`nixpkgs 20261121.2786a2a`); `current-system`, newest profile link and `init=` agree (11:06 and 11:32). After the 10:46 reset the box booted the same generation; no silent revert.

---

## §b PARTIALLY DONE

| Item | Works now (evidence) | Open | Blocker | Effort |
| --- | --- | --- | --- | --- |
| Deploy unblock | evo-x2 toplevel evaluates (`44a19b1`, rc=0); sops manifest evaluates | Battery checks #1 and #11 unproven; no deploy fired | Storm gates: the 11:26:54 attempt was refused at the entry gate (guard tripped 10 times in the prior 60 minutes) | S once calm |
| §11 vendorHash freshness after the lock waves | Nothing stale is known | 44 lock nodes moved since the last FOD repair (`da6239c`, 06:14 report); stale go-modules FODs are likely and unprobed | Realising FODs means builds in an IO storm | M |
| IO-storm attribution | One 3 s `io.stat` sample and one `io.pressure` read (§d.2) | Driver not established; samples are single-window | Out of scope for this session | M |
| Docs for this fix | This report | CHANGELOG entry, lesson in `docs/agents/nix-flakes.md`, queue rows | Intake control (at most 3 new rows a session); owner instruction to report and wait | S |

---

## §c NOT STARTED

1. **Fire the deploy** and carry it through post-switch verification (profile anchor, boot-entry anchor, `ai-meter.service`, `reports-system` first-run registration, failed-unit sweep).
2. **Battery-level proof**: `nix flake check --no-build`, `--section-11-only`, the sops check-mode build.
3. **Negative tests and selftests** for the audits I touched (`CASES=iotier`, `CASES=deployrestart`, the session-boot-audit test file).
4. **Crash close-out for the 10:43 watchdog reset**: `scripts/crash-triage.sh --boots 6`, `scripts/boot-evidence-pull.sh`, a stability row with a committed evidence file (the §15 pre-vacuum gate keys on it).
5. **CHANGELOG, lesson, queue rows** for this session.
6. **Cleanup**: `~/.cache/nixsrc-list.txt`; `~/.cache/deployfix-20261128/` once the report's numbers are no longer needed.

---

## §d TOTALLY FUCKED UP

### d.1 The box watchdog-reset at 10:43 and is still storming

- Boot `-1` (`0737ecd7…`, up since Nov 25 11:06) ends 10:43:28 with ordinary request logs; boot `0` (`56ba232e…`) starts 10:46:06. Kernel: "Previous system reset reason [0x02000800]: hardware watchdog timer expired".
- That is about 70 minutes after the owner's forced deploy attempt (09:33) and inside the same IO storm the deploy gate had refused. Severity: the whole host; every session on it.
- The storm continues in the new boot. Guard log 11:19:59: "MEMORY EMERGENCY IO-PAUSE (trip #13910, zone 6): NO eligible headless tree matched the attribution"; 11:20:17: "I/O PSI some avg60=45.75% sustained (max disk busy 99.5%, MemAvailable=60.9% … the crash #3 class: stacked …)". The deploy gate counted 10 trips in the hour before 11:26.
- `post-crash-calm-gate` refuses every 15 s ("memory-emergency-guard tripped 4 to 5 min ago (window 60 min)", 11:09:48 to 11:10:33). At 11:20 the systemd job list showed `graphical.target` and `late-applications.target` in `start/waiting`: the desktop was still held behind the gate. Not re-verified after 11:20.
- Root cause: not established. Mitigation: none applied.

### d.2 Two services produced about 700 MB/s in one 3 s sample

`io.stat` byte-counter deltas, one 3 s window between 11:24 and 11:32 (cumulative per cgroup, children included):

| Cgroup | read MB/s | write MB/s |
| --- | --- | --- |
| root (`/sys/fs/cgroup`) | 538.59 | 266.59 |
| `system.slice` | 531.39 | 257.18 |
| `crm-server.service` | 232.50 | 245.88 |
| `overview.service` | 226.75 | 0.00 |
| `hermes.service` | 49.60 | 0.02 |
| `user.slice` | 8.65 | 2.23 |

Most IO-stalled cgroups in the earlier `io.pressure` read (some avg10): `forgejo-runner-evo\x2dx2-cache-repair.service` 28.89 %, `hermes.service` 13.62 %, `session-17.scope` 11.89 %, `media-atlas.service` 6.97 %.

One sample, no verdict. It says where the bytes went in those three seconds, not what started it or whether it is wanted.

### d.3 Eval was broken for hours before anyone saw the real list

Between the 08:01 lock wave and 10:03 every evo-x2 eval died inside the session-boot-audit crash, so three unrelated problems stacked behind it: the crash, the `toJSON` precedence bug (05:51), and two unsatisfied audits for a unit enabled at 09:48. The 06:14 "toplevel green" proof was taken on a frozen tree (`6ad1f82`) that contained none of them. Severity: every deploy attempt; no data loss.

### d.4 Fix history is message-less

`e6e051a`, `aa7d993`, `44a19b1` are "chore: auto-commit N changed file(s) (heuristic)"; `aa7d993` mixes my whitespace re-indent with three foreign files. A reader of `git log` cannot tell that these three commits unblock deploys.

### d.5 From the owner's paste, noticed and not worked

- 15 failed units at 09:33 (among them `borgbackup-job-hetzner`, `btrbk-forgejo-clean`, `btrfs-verify-pool-backups`, `btrfs-verify-snapshots`, `clickhouse-db-backup`, `crm-alarm-byphone`, `cv-backup`, `disk-growth-check`, `catalog-inventory-sync`).
- Running nixpkgs `2786a2a` against pinned `58d0d3e` (advisory: "expect hash whack-a-mole").
- `check-contact-registry-drift.sh missing`; `PAP_ICONS_DIR … never realized — recurring class`; new-metric loan `collector_cycles`; root filesystem 95 % full (39G free).

---

## §e WHAT WE SHOULD IMPROVE

| # | Pattern | Impact | Suggested fix |
| --- | --- | --- | --- |
| 1 | A crash inside one module's assertion hides every other failed assertion | Hours: three stacked breaks surfaced one at a time | `session-boot-audit` should catch its own data errors per unit and emit a failing assertion naming the unit, instead of letting the eval crash inside `checkAssertWarn` |
| 2 | "Green in a frozen worktree" is quoted as if it proved HEAD | The 06:14 proof excluded two later daemon commits | A proof report must state which commits HEAD had that the frozen tree lacks, or freeze at the commit it names |
| 3 | `builtins.toJSON { … } // x` parses and looks right | One deploy-blocking eval error | A `lint-static` grep for `} //` closing a `toJSON {` block; lesson line in `docs/agents/nix-flakes.md` |
| 4 | New `*-backup-dir` units fail two audits on first enable | One eval round trip per new service | Document the three-line recipe (unit, allowlist entry, deploy.sh loop entry) in `docs/agents/integration-registry.md` step 6, or fold both lists into one declaration next to `mkPoolDirUnit` |
| 5 | Daemon commits carry fixes without reasons | Attribution and review cost | Allow sessions to re-message their own daemon commits, or have the daemon use a hook-safe path |
| 6 | `nix fmt -- --fail-on-change` rewrites before failing | Surprise 529-line diffs | Say so in AGENTS.md next to the scoped-formatter paragraph; a check-only form would be better |
| 7 | The agent's displayed output is redacted (`token <word>` sequences) | Misread diffs | Keep byte-checking anchors from disk; note the redactor in `docs/agents/shell-devtools.md` |
| 8 | Heavy proofs are the only accepted evidence on a storming box | Either risk the box or have no proof | A cheap "which FODs are stale" preview that compares locked revs against upstream bakes without building (the 06:14 report did it by hand) |

---

## §f Up to 50 things to get done next (ranked by impact)

**Harvest note:** none of these rows was written into `TODO_LIST.md` or a domain library. Deliberately not harvested: the owner asked for a report and a stop, and the queue's intake control caps a session at 3 new rows and requires closing as many as are minted. Rows 1, 2 and 8 are the direct follow-ups of this session and are written as queue-ready one-liners.

| # | Task | Impact | Effort | Category |
| --- | --- | --- | --- | --- |
| 1 | Fire `nix run .#deploy` unforced once the guard has stayed quiet for 60 minutes, then verify profile anchor, boot-entry anchor, `ai-meter.service` and `reports-system.service` | Critical | S | Bug |
| 2 | Repair the stale go-modules FODs the 08:01 and 09:3x lock waves created (feed the deploy log to `scripts/fod-hash-diff.sh <log> --apply`), then re-prove the toplevel | Critical | M | Bug |
| 3 | Classify the 10:43 watchdog reset: `scripts/crash-triage.sh --boots 6`, `scripts/boot-evidence-pull.sh`, stability row with committed evidence (§15 gate) | Critical | M | Bug |
| 4 | Run `nix flake check --no-build` and `--section-11-only` in the first calm window to turn the inferred-green checks #1 and #11 into proven ones | Critical | M | Quality |
| 5 | Establish what drives `crm-server.service` (478 MB/s) and `overview.service` (227 MB/s read) in a storm; stop, tier or schedule it | Critical | M | Bug |
| 6 | Check why `graphical.target` and `late-applications.target` were still waiting at 11:20 and whether the desktop came up | Critical | S | Bug |
| 7 | After the deploy: create the first `reports.home.lan` account (bootstrap registration: first account becomes administrator, registration closes) | High | S | Feature |
| 8 | Add a `lint-static` guard for `toJSON {` blocks closed by `} //` and a selftest pinning the `lib.split` separator shape | High | S | Quality |
| 9 | Make `session-boot-audit` fail with a named unit instead of crashing the eval on malformed unit data | High | S | Quality |
| 10 | Run `scripts/negative-test-lints.sh` with `CASES=iotier` and `CASES=deployrestart`, plus `tests/test-session-boot-audit.nix` | High | S | Quality |
| 11 | Write the CHANGELOG entry for the three eval fixes | High | S | Documentation |
| 12 | Add the two lesson lines to `docs/agents/nix-flakes.md` (toJSON precedence; frozen-tree proofs cover only their commit) | High | S | Documentation |
| 13 | Fold the IO-tier allowlist and the deploy.sh provisioner loop into one declaration next to `mkPoolDirUnit`, or document the three-line recipe in `docs/agents/integration-registry.md` | Medium | M | Quality |
| 14 | Triage the 15 failed units listed at 09:33 (backups and verifiers first) | High | M | Bug |
| 15 | Decide whether the quota-source wave should switch `services.ai-meter.quotaSource.enable` on in this tree (dormant today; upstream `b0eb30e` has `quotasource.go`) | Medium | S | Decision |
| 16 | Identify the unit whose multi-token directive line tripped the session-boot-audit crash and record it in the test comment | Medium | S | Documentation |
| 17 | Note in AGENTS.md that `nix fmt -- --fail-on-change` rewrites before failing | Medium | S | Documentation |
| 18 | Note the display redactor (`token <word>` sequences) in `docs/agents/shell-devtools.md` | Medium | S | Documentation |
| 19 | Give `e6e051a`, `aa7d993`, `44a19b1` proper messages, or record their meaning in CHANGELOG (row 11) | Medium | S | Cleanup |
| 20 | Root filesystem at 95 % (39G free): reclaim before the next build wave | Medium | M | Cleanup |
| 21 | Resolve the running-pinned nixpkgs mismatch by deploying forward (row 1) and re-reading §0 of the battery | Medium | S | Bug |
| 22 | `check-contact-registry-drift.sh missing` (WARN, advisory): restore or drop the battery step | Low | S | Cleanup |
| 23 | `PAP_ICONS_DIR` "derived but never realized" recurring class: realize the pack or drop the derivation | Low | S | Cleanup |
| 24 | New-metric loan `collector_cycles`: confirm the metric is live after the next deploy and close the loan | Low | S | Monitoring |
| 25 | Remove `~/.cache/nixsrc-list.txt` and, once this report's numbers are no longer needed, `~/.cache/deployfix-20261128/` | Low | S | Cleanup |

---

## §g Questions I could not answer myself

1. **Deploy authority under storm.** The eval is green; the gates are the only blocker (10 guard trips in the hour before 11:26; the box watchdog-reset 70 minutes after the last forced attempt). An attempt I did not start was refused at 11:26:54. Do you want the deploy fired **unforced** as soon as the guard has been quiet for 60 minutes, and is anyone else about to fire it (so we do not race two deploys)?
2. **Is the `crm-server` IO wanted?** `crm-server.service` read 232 MB/s and wrote 246 MB/s in one 3 s sample, and `overview.service` read 227 MB/s. I cannot tell from the outside whether that is a job you started (a backfill or re-index) or the storm driver to stop. If it is yours, when does it end; if not, may it be stopped or tiered?
3. **Was the quota-source wave meant to go live now?** The Nix for it landed at 05:51 but nothing under `modules/`, `platforms/` or `systems/` enables `quotaSource` or sets a `quotaProvider`. I fixed its syntax, not its intent: should this deploy carry the enabling config, or stay dormant?

---

_Artifacts of this session outside the repo: `~/.cache/deployfix-20261128/` (eval logs, probe scripts, lock diff) and the stray `~/.cache/nixsrc-list.txt`._
