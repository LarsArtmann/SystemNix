# Status Report: nixpkgs-bump deploy blocker (niri eval) — fix + deploy + verification

**Date:** 2026-09-06 20:57 CEST
**Session scope:** the failed pre-deploy validation after the nixpkgs lock bump (0968519e → c043004d), root-cause, fix, verification, deploy, post-deploy verification.
**Basis:** this session's own work and direct observations only. No unrelated research.
**Note on format:** written as `.md` at the user-specified path — the status-report/brutal-self-review skills default to styled HTML; user instruction wins (flagged per skill rules).

---

## Session timeline (what actually happened)

| Time (CEST) | Event |
| --- | --- |
| ~20:15–20:31 | Parallel sessions visible all evening (5+ `crush -y` agents). One session fought the same eval failure (nix-daemon "interrupted by the user" 19:56–20:17) and built the new niri into the store at ~20:31 (registration time verified via `nix path-info`). |
| ~20:20 | Reproduced: `nix flake check --no-build` → `error: path 'sf38kqmr5n4b9cxvv06vgkphnbbxa3q5-niri-unstable-2026-08-02-feb3e43.drv' is not valid`, trace through `session-boot-audit` → `systemd.user.units` → `niri-config.nix`. |
| ~20:25 | Root cause: `niri-config.nix` read unit texts from the **built** package output (`readDir/readFile "${niriPkg}/lib/systemd/user"`) — eval-time realization of niri. Every nixpkgs bump changes the drv; eval-only commands fail until niri happens to be rebuilt. Deploy evals survived only because build-allowed evals silently build niri mid-eval. |
| ~20:27 | Fix: read unit texts from the niri **source tree** (`${niriPkg.src}/resources/`, pure), replicate niri-flake's single install substitution (`ExecStart=niri` → `ExecStart=$out/bin/niri`; confirmed in niri-flake `postFixup` that the `/usr/bin` branch is the meson flavor, not ours). |
| ~20:30 | Verification: generated `niri.service` byte-identical to deployed except the expected ExecStart store-path bump; `niri-shutdown.target` byte-identical; eval succeeds with niri still unbuilt (purity proven); formatter applied (one hunk, semantics unchanged); full `nix flake check --no-build` → **all checks passed**. |
| ~20:32 | Pre-deploy-check: **117 passed / 30 warnings / 0 failed**. |
| ~20:38–20:42 | Deploy via `nix run .#deploy` (nh). Switch succeeded fast — the closure was largely pre-built by the parallel session's earlier build-allowed eval. |
| ~20:43–20:50 | Post-deploy verification: generation **774**, `current-system` == `profiles/system` (no mismatch), deployed `niri.service` ExecStart = new niri build. Smoke: **94 PASS / 1 FAIL / 4 SKIP / 3 WARN**. |

**Commits (auto-commit daemon):** `bfe62ce8` (niri-config.nix fix) → `4f103269` (AGENTS.md lesson) → `6ac26d74` (formatter delta).

---

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| Root-cause the deploy blocker: eval-time `readFile`/`readDir` on the built niri output forces realization; breaks every eval-only command after any nixpkgs bump | Trace + code read (`modules/nixos/desktop/niri-config.nix:59-63` pre-fix); class confirmed unique repo-wide (grep over modules/platforms/lib/pkgs found exactly one instance) |
| Fix `niri-config.nix`: unit texts read from `${niriPkg.src}/resources` + replicated `ExecStart=niri` substitution | Commit `bfe62ce8`; substitution semantics verified against niri-flake source (prefetched `9ee3e13b`, `postFixup` block) and against the deployed artifact |
| Byte-identity verification of generated units | `diff` of evaluated `.text` vs deployed `/etc/systemd/user/niri.service` (only diff = ExecStart store path jvv9wj… → 450jpf…, the new niri) and `niri-shutdown.target` (identical) |
| Purity verification | Eval of the unit text and toplevel succeeded while the new niri **output** was not yet built; `nix flake check --no-build` → **all checks passed** (was the failing gate) |
| Formatter compliance | `nix fmt --no-update-lock-file -- --ci` clean after treefmt reformatted one hunk (commit `6ac26d74`) |
| Pre-deploy validation | `scripts/pre-deploy-check.sh`: **117 passed / 0 failed** (30 known-benign warnings: not-yet-built ExecStart binaries of the new closure, goModules probes) |
| Deploy to evo-x2 | `nix run .#deploy` → generation **774**, `current-system` = `…26.11.20260905.c043004d` = `profiles/system` (anchored; the 2026-09-06 generation-mismatch gotcha did NOT fire) |
| Post-deploy smoke (deploy.sh runs it) | **94 PASS / 1 FAIL / 4 SKIP / 3 WARN**; FAIL and WARNs all pre-existing classes (see b/d) |
| dnsblockd start-timeout during deploy restart: verified self-heal | `Failed with result 'timeout'` 20:44:25 → OnFailure fired → restarted pid 3719617 answering; `dig auth.home.lan @127.0.0.1` + `getent cache.home.lan` both resolve (documented self-heal pattern held) |
| bank-sync smoke FAIL classified with evidence | Journal shows exactly the known `[corruption] db.scan: unparseable sync_states.statement_coverage` RFC3339 class (upstream fix committed but unpushed) |
| AGENTS.md updated with the class lesson (eval must never coerce a package output) | Commit `4f103269`, Nix & Nixpkgs gotchas section |

## b) PARTIALLY DONE

| Item | What works | What remains | Effort |
| --- | --- | --- | --- |
| Deploy verification of niri units | ExecStart line verified on the deployed unit; smoke green | Full byte-diff of deployed vs generated unit text was done pre-deploy, not repeated post-deploy; not wired into post-deploy-check as a permanent step | S |
| IO pressure forensics at deploy end | Ruled out: corpse-pile (no persistent D-states), memory pressure (~0), zram (47%), btrbk/scrub (not running). Established system disk is now **nvme0 (Samsung)** with ~33 MB/s reads while IO PSI sat at ~70–77% some/full | The **cause of 70% full-stall PSI at only 33 MB/s is UNEXPLAINED** — I stopped at "parallel churn" (load fell 7.7→1.7 by 20:52, but avg10 PSI was still 77% at last check). On a box with this freeze history, that is an unfinished investigation | M |
| Parallel-session coordination | Detected the concurrent session that built niri and the second post-deploy `flake.lock` movement (see d-6) | Did NOT detect it **before** deploying; no reconciliation step run; deploy.sh has no "other sessions active?" warning | S |
| Regression protection for the fixed class | AGENTS.md documents the rule ("eval must never coerce a package OUTPUT") | **No automated guard** — no lint/check rejects `readFile/readDir "${pkg…}"` output coercions, no negative test. Given this repo's 5-layer prevention doctrine, documentation-only is weak | S (lint) / M (test) |
| Self-review deliverable | This report answers the brutal-self-review questions | The skill's canonical HTML output at `docs/reviews/` was overridden by the user's `.md` instruction — flagged, not produced | S if wanted |

## c) NOT STARTED

| Item | Why | Priority |
| --- | --- | --- |
| Eval-purity lint (pre-commit + CI + `nix flake check`) rejecting output-coercion patterns in modules | Discovered this session; not built | High |
| dnsblockd `TimeoutStartSec` headroom fix (blocklist load ~2min nominal vs 3min `DefaultTimeoutStartSec` — 1min headroom, bit during this deploy's restart) | Noticed mid-deploy; self-healed; deliberately not fixed inline (out of session scope), logged instead | High |
| AGENTS.md correction: the Samsung 970 is **no longer "BLANK, role PENDING"** — live `findmnt` shows root `@`, `@nix`, `@cache-home`, `/data`, `/boot`, and the ClickHouse XFS all on **nvme0**; Lexar (nvme1) idle. Parallel sessions migrated the system disk; docs now lie about the boot disk | Noticed at 20:53; user said report-only, so flagged here instead of edited | High |
| Reboot into the new generation | `booted-system` = 2026-08-31 generation while `current-system` = 774; the new kernel/system activates only on reboot. Timing is a user call (and a parallel session may deploy again first) | High (user timing) |
| Reconcile the second lock movement: `flake.lock` went dirty again post-deploy (parallel session; ≥3 input revs changed, nixpkgs → `94c9cb93…`) — deployed generation 774 now lags the tree | Discovered at 20:57 while writing this report; explicitly NOT touched (another session owns it) | High (coordination) |
| VM-test / check **builds** for the c043004d bump | `--no-build` all session; the bump's checks/VM tests have not been built yet | Medium |
| Quickshell "1 error line in journal (1h)" smoke WARN triage | Not investigated (WARN, likely cosmetic) | Low |

## d) TOTALLY FUCKED UP

Nothing I shipped this session is broken — the fix is deployed and verified. But brutal honesty about what is fucked up around it:

1. **The deploy gate was store-state-dependent for its entire life until today.** `nix flake check --no-build` (the FIRST pre-deploy step) silently required niri to be physically built. It worked only because deploys had warmed the store. One nixpkgs bump + an unbuilt drv = gate dark. Every future module reading a package output re-introduces this. (Fixed for niri; **no lint prevents recurrence** — see c.)
2. **dnsblockd has 1 minute of start-timeout headroom and it bit during this deploy.** ~2min blocklist load vs 3min global `DefaultTimeoutStartSec`; the deploy restart + IO churn pushed it over; OnFailure (Discord/sev1) fired for a self-healing transient. Known pattern (llama-embeddings 2026-09-05), still unfixed.
3. **Multiple uncoordinated agent sessions deploy to the same box.** This session: a parallel session built niri *while* I was diagnosing; another moved `flake.lock` again *after* my deploy (gen 774 already lags the tree). The 2026-09-06 one-link-IO-storm class, live. deploy.sh's flock prevents *concurrent switches* but nothing surfaces "who else is working / is the tree about to move under you".
4. **AGENTS.md is factually wrong about the boot disk right now** (claims Samsung blank/role-pending; the box boots root from it). Docs drift on the most safety-critical machine facts.
5. **Pre-existing, unchanged, still failing:** bank-sync RFC3339 corruption loop (fix unpushed upstream — the smoke FAIL will stay red until push + flake bump + deploy); InboxClean main Gmail `auth_expired` since 09-04 (needs the user's OAuth runbook); mail relay go-live blocked on Resend domain verification.
6. **My own sloppiness, named:** (a) I stated "parallel sessions had built most of the closure" as fact — it is a plausible inference from a ~5-minute build, not verified evidence; (b) my first two `/proc/diskstats` awk field maps were wrong (garbage deltas) before I got a clean measurement; (c) I declared the IO pressure "environmental, trending down" on the strength of load average while PSI itself was still ~77% — an unverified comfort statement.

## e) WHAT WE SHOULD IMPROVE

1. **Mechanize the class, not the instance.** The niri fix removed one landmine; a lint (grep-based like `audit-shell-nullglob.sh` / `audit-textfile-tmp.sh`) removes the class. This repo's superpower is prevention layers — use it.
2. **Deploy-time coordination surfacing.** deploy.sh should WARN when other `crush`/nix clients are active and when `flake.lock` mtime is newer than the current-system link ("tree is moving under you").
3. **"Self-healed transients" still deserve tickets.** dnsblockd's timeout self-healed; self-healing is not a fix. Every OnFailure that recovers should still produce a task (this report logs it).
4. **Post-deploy byte-checks for generated artifacts.** The single most valuable verification this session was diffing generated unit text against the deployed file — make it a standing post-deploy step for declaratively-generated units.
5. **Verify inference before asserting it.** Twice this session I almost trusted an inference (closure prebuilt; pressure passing). The repo's own rule — "never assert success from output text alone; assert WHICH entity served it" — applies to my prose too.
6. **Docs at discovery time.** I noticed the Samsung-migration docs drift mid-session and deferred it to a report line; per the owner's standing 2026-09-06 permission, two-line fixes like this should be fixed on sight. This one is more than two lines (machine topology), so: ticket, not skip.

## Self-review Q&A (brutal-self-review, all 11)

1. **What did you forget?** A regression guard for the fixed class (docs-only); AGENTS.md boot-disk correction; post-deploy byte-check; explicit reconciliation step after spotting the second lock movement.
2. **What is something stupid we do anyway?** The pre-deploy gate ordering assumed a warm store; "self-healed = done" mindset around deploy-restart transients; 5+ concurrent agent sessions on one box with one NVMe and one lock file.
3. **What could you have done better?** Detect the parallel session's build *before* deploying (daemon connections + lock mtime + running processes were checkable in one command); identify the PSI source instead of hand-waving; write the lint in-session (it's ~30 lines in the established audit-script pattern).
4. **What could you still improve?** Same as (3) plus: keep a standing habit of re-reading AGENTS claims against live state when they bear on safety (boot disk).
5. **Did you lie to you/user?** Two overstatements flagged above (prebuilt closure; pressure trending). Corrected here. The byte-identity and checks-passed claims are backed by tool output.
6. **How can we be less stupid?** Section e, items 1–5.
7. **Ghost systems?** None created; the old `${niriPkg}/lib/systemd/user` read is fully removed. Checked: the fix doesn't orphan anything in session-boot-audit (niri units are *always* in the graph now — strictly better coverage than a tryEval fallback would have been).
8. **Scope creep?** Resisted fixing dnsblockd timeout and the AGENTS boot-disk rewrite inline (user directive: report-only). Two temptations, both logged as tasks instead.
9. **Did we remove something useful?** No — the source-tree read preserves the original intent (track upstream unit text) while removing the realization; `niri-shutdown.target` byte-identical proves no behavior loss.
10. **Split brains?** One new, small, accepted: the module now duplicates niri-flake's `postFixup` substitution knowledge ("ExecStart=niri" → bin path). If niri-flake changes its install substitutions, our replication silently diverges. Mitigated by comment only; a future niri bump should re-diff. Flagged deliberately here rather than hidden.
11. **Tests?** The class has zero automated coverage (see b/c). The repo's negative-test harness (`scripts/negative-test-lints.sh` pattern) fits an eval-purity lint perfectly. Everything else this session was verified by direct tool evidence, not test suites.

---

## f) Top things to get done next (up to 50, ranked; feeds docs-health HARVEST)

Impact: Critical/High/Medium/Low · Effort: S <30min / M 30min–2h / L >2h

| # | Task | Impact | Effort | Category |
| --- | --- | --- | --- | --- |
| 1 | Reboot evo-x2 into the new generation (booted-system is 2026-08-31; new kernel/system activate on reboot; clears the owed-reboot backlog) | Critical | S | Ops |
| 2 | Reconcile the post-deploy flake.lock movement by the parallel session (nixpkgs → 94c9cb93 etc.): either it deploys next or gen 774 is re-validated — never let deployed-lock ≠ tree-lock drift silently | Critical | S | Ops |
| 3 | Write eval-purity lint (`scripts/audit-eval-output-coercion.sh`, pre-commit + CI + flake check): reject `readFile/readDir/hashFile` on `${pkgs…}` output paths in modules | High | S | Quality |
| 4 | dnsblockd: explicit `TimeoutStartSec = "6min"` (blocklist ~2min + deploy-restart IO churn exceeded the 3min global today) | High | S | Bug |
| 5 | Correct AGENTS.md platform facts: Samsung 970 (nvme0) is the live system disk (root/@nix//data/boot/clickhouse); Lexar nvme1 idle — record migration as done, plan Lexar disposition | High | S | Documentation |
| 6 | Investigate the unexplained ~70% full-stall IO PSI at ~33 MB/s on nvme0 (freeze-history box); identify the reader (iotop session was already running) | High | M | Bug |
| 7 | deploy.sh: WARN when other nix/crush clients are active or flake.lock is newer than current-system before switching | High | S | Quality |
| 8 | Push bank-sync (tolerant timestamp read + V10) upstream, `nix flake lock --update-input bank-sync`, deploy — clears the standing smoke FAIL | High | S | Bug |
| 9 | Build the c043004d bump's checks/VM tests (`nix flake check` WITH builds) post-reboot | High | M | Quality |
| 10 | Add post-deploy byte-diff of generated niri user units vs deployed files to post-deploy-check.sh | Medium | S | Quality |
| 11 | Verify niri session live after next login (new binary 450jpf… starts; GPU/GTT sane) | High | S | Ops |
| 12 | Verify post-reboot: GTT-first values, uas/udev DAS rules, zram 50% sizing, pool mount — the 2026-08-31-boot debt list | High | M | Ops |
| 13 | InboxClean main Gmail re-auth (auth_expired since 09-04) via the OAuth runbook, then re-enable sync | High | S | Ops |
| 14 | Resend: verify larsartmann.cloud domain (SPF/DKIM) to clear the mail-relay 550 | High | S | Ops |
| 15 | Pocket ID: paste a NEW Resend key into sops (old revoked 2026-08-18) | High | S | Ops |
| 16 | dnsblockd upstream health-cache fix: push, tag, flake bump, deploy (working-tree fix from 2026-09-06) | High | S | Bug |
| 17 | /data EIO inode corruption (btrbk-data blocked since 2026-08-20) — the P0 repair decision still owed | High | L | Bug |
| 18 | FastFlowLM v1.0.3+ bump: only after reboot + live serve validation + full weight re-pull discipline | Medium | M | Feature |
| 19 | FastFlowLM v1.0.2 prefill segfault: report upstream with the core-dump evidence | Medium | S | Bug |
| 20 | Paperless: run `inboxclean paperless --backfill --prune` to purge the 2 duplicate statements | Medium | S | Cleanup |
| 21 | CV: decide `pipeline.evaluation.min_day_rate` (EUR/day floor) owner value | Medium | S | Decision |
| 22 | CI: add `NIX_GITHUB_RO_TOKEN` secret (CI dark for 120+ runs) | High | S | Infra |
| 23 | Drop now-droppable go-tarball overrides upstream (browser-history, papdashboard, crush-daily, PMA) — drop-day reached 2026-08-29 | Medium | M | Cleanup |
| 24 | Delete/re-download `/data/models/llm/gemma-4-31b-abliterated-Q8_0.gguf` (EIO-corrupt) | Low | S | Cleanup |
| 25 | Jan: verify all 92G models visible after the data-folder path fix | Medium | S | Ops |
| 26 | Secret-history purge: revisit the held push once rotations are confirmed (context7/Resend/synthetic status check) | Medium | S | Security |
| 27 | Watch bank-sync statement_coverage post-SCA-approval: if RFC3339 values reappear, goroutine-dump the daemon (writer-inside proof) | Medium | S | Bug |
| 28 | gatus/deploy drift detector: alert when deployed system's lock rev ≠ tree lock rev (today's class) | Medium | S | Feature |
| 29 | Eval-time guard for `StartLimitBurst/IntervalSec` misplacement (documented class, "no eval-time guard yet" in AGENTS) | Medium | M | Quality |
| 30 | Triage quickshell journal error line (smoke WARN) | Low | S | Bug |
| 31 | niri-session-manager upstream: dedupe single-instance surfaces at save (storm class) | Medium | M | Feature |
| 32 | clickhouse-backup coverage gap (telemetry has NO backup leg) — TODO_LIST P0 follow-up | High | L | Infra |
| 33 | Wise SCA: re-approval workflow if statements are still paused | Medium | S | Ops |
| 34 | Paperless old SQLite export: user decision (recover vs delete) | Low | S | Decision |
| 35 | Hermes workspace layout: revisit per TODO_LIST trigger | Low | S | Decision |
| 36 | AGENTS.md: document the dnsblockd deploy-restart start-timeout pattern (self-heal + fix #4) | Medium | S | Documentation |
| 37 | Consider `watchdogd`/PSI guard calibration after #6: did the 70% full-stall episode trip anything? If not, why not | Medium | M | Quality |
| 38 | Sweep AGENTS.md machine-facts against live state post-Samsung-migration (disk letters, by-id smartd targets, /data composition) | High | M | Documentation |
| 39 | smartd/nvme-health by-id targets: confirm they now point at the right disks post-migration (enumeration-shift trap) | High | S | Bug |
| 40 | btrbk config: confirm snapshot sources/targets still correct after the disk migration | High | S | Ops |
| 41 | mail relay: decide null-sender (NDR) handling given Resend rejects `MAIL FROM <>` | Low | S | Decision |
| 42 | `system_gatus_meta_scrape_errors`-style check for "deployed unit texts == current eval" drift detector (generalize #10) | Low | M | Feature |
| 43 | Minimax crush provider: re-enable decision (Token Plan state) | Low | S | Decision |
| 44 | Clean up `iotop-c`-style stray debugging processes left by sessions at deploy end | Low | S | Cleanup |
| 45 | HARVEST this list into TODO_LIST.md / ROADMAP.md (docs-health) — items 1–11 minimum | Medium | S | Documentation |

*(45 items — the extra headroom over 25 is brainstorm material; HARVEST should apply routing rigor: 1–17 belong in TODO_LIST, most of the tail is ROADMAP fuel.)*

## g) Questions I cannot answer myself

See the three questions raised at the end of this session (concurrent lock movement ownership, Samsung-migration intent, reboot timing).
