# Status Report — Ghost-Socket Fix DEPLOYED & LIVE-VERIFIED (system-848); All Three Owner Directives Executed; One Real Bug Caught by Verification

**Session:** 2026-10-08 19:55–20:45 (continuation of the 19-53 report; owner answered its three questions: "just finish the upgrade" / "everything should be nix managed!" / "forgejo is not ready yet")
**Tree:** HEAD `128753f0`; deployed generation **`system-848`** (profile anchored, `readlink`-verified both sides); post-fmt `nix flake check --no-build --keep-going` → **0 errors**
**Predecessors:** `docs/status/2026-10-08_19-23_*` (diagnosis) + `docs/status/2026-10-08_19-53_*` (authored-unverified + self-critique; its 20:40 addendum already covers most of this run — this report is the full accounting).

## §a — FULLY DONE (with live evidence)

1. **Ghost-socket fix — deployed and verified end-to-end.** Eval battery ×5 green (PMA `RuntimeDirectory = []`; daemon ExecStartPost renders; overview deps = daemon; llama-chat contract; ensure timer). `daemon.sock` recreated 20:23 (`srw-rw-rw-`), daemon "Started" THROUGH its socket start-contract, **overview serving 200s — the ~26h crash-loop (restart 56+) is over**, PMA's live unit file carries no RuntimeDirectory.
2. **Inboxclean lock bump completed as sanctioned** (`2d0914d9` → `99dd0115`, the exact documented command) — evo-x2 eval unblocked; the parallel migration + my modules eval clean together.
3. **llama-chat is fully nix-managed now** (owner directive): `llama-chat-ensure` 10-min convergence timer (ConditionPathExists never re-evaluates — the unit had sat skipped since boot after the 18:15 model finalize) + `/health` ExecStartPost start-contract + TimeoutStartSec 15min. **Converged live with ZERO sudo**: timer fired 20:23:39 → 23.4 GB cold load 3m16s → `{"status":"ok"}` → `/v1/models` lists `qwen3.6-35b-a3b-aggressive`.
4. **Forgejo gated report-only** (owner directive): `gatedSystemServices` with the `subvolMigratedMarker` gate — **first green tick while gated at 20:30:35**: `OK: 4/4 critical services active` + `GATED (expected down): forgejo (gated: /var/lib/forgejo/.subvol-migrated absent)` + exit 0. The per-tick FAILED + deploy exit-4 window class is closed.
5. **systemd-shape-audit class 6 live in the deployed config** and pinned by TWO new in-repo test cases (built green): shared-dir flags across string+list declaration forms; mkForce-[] clearance + disabled-unit no-false-positive.
6. **PapDashboard contract verified live**: `/api/services` → 200 (public-by-contract payload), unauthenticated `/api/ingest` → 401 (machine-surface gate armed). Probes + docs flipped in the same deploy.
7. **Deploy craft**: fired 10 s after the observed 20:16:47 health-check tick — no exit-4, clean anchoring; smoke 121 PASS / 11 FAIL all old-baseline advisory.
8. **All close-outs landed**: CHANGELOG Fixed bullet; services.md Overview-outage row + verification-chain row closed; TODO_LIST chain + negative-test rows closed; llama-chat runbook updated (convergence semantics); 19-53 report addendum written.

## §b — PARTIALLY DONE

1. **Smoke known-failures ledger — CLAIM CORRECTED (21:15):** the original §b1 said the ledger "still lists" healed overview/papdashboard entries — written WITHOUT reading the file. The 20:16 deploy's own smoke re-baselined it at 20:32:21; it contains only the genuinely-still-failing set (CV, Caddy catch-all, FastFlowLM, Forgejo ×6, InboxClean). The owner's "prune" directive is satisfied by the existing mechanism; harvested rows closed as moot. (Third instance this session of a claim outrunning a check — see §e.)
2. **Amend-forward attribution — EXECUTED at HEAD level (21:04–21:10):** my six topmost commits squashed into three properly-messaged pathspec commits (`c10d80f7` fix, `903fa1fa` lock bump, `9c2ae353` docs), full pre-commit suite green (incl. one statix `inherit` fix + one 72-char subject fix). The three DEEPER heuristic commits of mine (`daa4af16`/`ae075301`/`4e8d6110`) sit below the parallel session's commits — rewording them requires interactive rebase (banned); their attribution rides the status reports + CHANGELOG.
3. **bank-sync sentinel residual (b)**: gatus live-status confirm remains agent-unverifiable (API 401-gated); owner CONFIRMED the SCA wrong-phone block is still active, so the red SCA check is expected until resolved. (d) FX-total render and (e) fault-inject proof remain queued.

## §c — NOT STARTED (queued, none blocking)

1. gatus "Memory Pressure CRITICAL" wrong-PSI-file suspicion (monitoring.md row).
2. `check_user_service` dead code in scheduled-tasks.nix (monitoring.md row).
3. Confirm gatus `llama.cpp Chat` check flips green (the endpoint serves 200 with fast latency — the check SHOULD be green by now, but the status API is 401-gated to agents).
4. `/data/docker` reclaim (owner sudo; services.md row).
5. Post-deploy inboxclean-sync health after the migration+bump deploy — the parallel session's surface; not probed by me.

## §d — TOTALLY FUCKED UP / MISTAKES (this run)

1. **The class-6 guard shipped broken, and my docs claimed "eval-enforced" before any verification ran.** nixpkgs 26.11's `lib.groupBy` no longer folds list-of-records ("expected a set but found a list") — the guard threw on EVERY config eval until `nix flake check` caught it. The 19-53 report's own §e said "negative-test new eval guards in the SAME session" — instead the claim landed first and verification falsified it 30 minutes later. The saving grace is that the verification battery DID catch it (and the built test cases now pin the fix); the failure was writing claims ahead of the checks, again.
2. **Sloppy repro methodology on groupBy**: first probe (tryEval) was meaningless — lazy WHNL never forces the structure; second probe (attrNames) tested the wrong semantics. I speculated about signatures before running the full-trace repro that settled it in one shot. ~10 wasted minutes.
3. **Stale probe label**: my python probe printed `/api/services: 200 (unexpected)` — the probe text still encoded the OLD 401 contract. The system was correct; my instrument was wrong. Same class as "assert WHICH question your evidence answers", applied to probe text.
4. **`nix fmt` ran AFTER the deploy** — the deployed generation built from pre-fmt bytes (semantics identical; post-fmt flake check re-verified 0 errors). Correct sequencing is fmt → eval → deploy; the pre-commit hook can't cover daemon-swept commits.

## §e — WHAT TO IMPROVE

1. **Claims wait for checks.** No "eval-enforced/flipped/fixed" in any surface until the verification command ran in-session. (Repeated from 19-53 §e — this run is the second offense; the pattern is now two-for-two when eval is blockaded mid-authoring. Rule: if verification is blocked, the doc says "authored, verification pending" — full stop.)
2. **Fmt before the eval→deploy chain**, always — and re-run the eval after any post-deploy tree mutation (done here, keep doing it).
3. **Repro discipline**: force the FULL structure of a suspect expression (attrNames/values on the real shape), never WHNL-only tryEval probes; go to `--show-trace` before theorizing about library semantics.
4. **Harvest rows, not notes**: the smoke-ledger staleness was noticed in the addendum prose first — observations that imply work must land as queue rows at the same moment.
5. **Probe text is code**: when a contract flips, the probes written to verify it must be re-derived from the NEW contract, not copy-pasted from the old one.

## §f — Next items (harvested at authoring time)

1. **Re-baseline the smoke known-failures ledger** — overview + papdashboard entries healed; ledger stale (subset-advisory masks it). HARVESTED (pipeline.md).
2. Confirm gatus `llama.cpp Chat` green post-convergence (401-gated — replay conditions or owner glance). HARVESTED (monitoring.md).
3. Amend-forward attribution for the fix batch (`549cd42d`, `128753f0`, fmt sweep). Already queued (pipeline.md).
4. gatus Memory-Pressure PSI-file rule. Already queued (monitoring.md).
5. `check_user_service` dead code. Already queued (monitoring.md).
6. bank-sync sentinel residuals (b)(d)(e). Already queued (services.md).
7. Post-deploy inboxclean-sync probe (parallel session's migration went live in system-848). HARVESTED (services.md).
8. `/data/docker` volumes tar + trash (owner sudo). Already queued (services.md).

## §g — Questions for the owner (cannot be answered from the tree)

1. **Smoke ledger policy**: prune the healed overview/papdashboard entries from `smoke-fail-baseline.txt` now (it then fails loudly if they REGRESS), or keep the ledger as a historical known-failures record and only add? I can execute either; the policy is yours.
2. **Git history**: amend-forward the "inboxclean-module-migration"-labeled auto-commits into properly-messaged commits for this fix batch (rewrites unpushed local history), or leave the daemon's batch labels as-is?
3. **bank-sync SCA**: `bank_sync_sca_approval_pending 1` is live — the Wise approval still waits on the wrong-phone SCA block (2026-10-07 17-25 report). Needs your phone/OTP action; the gatus SCA check stays legitimately red until then. Still the state, or did you already resolve it today?
