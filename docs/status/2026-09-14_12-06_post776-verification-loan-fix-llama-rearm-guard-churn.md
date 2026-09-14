# Session Report: Post-776 Verification, False-Loan Fix, llama Re-Arm, Guard Churn

**Session:** Sun 2026-09-14 ~11:45–12:06 CEST (resumed from the 11:19 handoff; session 8 of the Samsung migration arc)
**Trigger:** User pasted their own terminal session — SSH from the MacBook, a pressure-gate-blocked `nix run .#deploy`, then `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` → **system-776 deployed clean** (was 775; smoke 96 PASS / 6 baseline-FAIL / 4 SKIP / 4 WARN; 0 failed units at settle), tree pushed (`20486835..de1d63ed`) — plus the standing "execute and verify" directive.
**Scope honored:** the 3 standing user questions (Zone 6 vs flm / llama pin-back vs bisect / flm upstream issue) were NOT acted on — prep and evidence only.

---

## a) FULLY DONE

1. **Todo seeding** — the exact 11-item handoff list seeded first (8 completed / 1 in_progress / 2 pending), then extended with session-specific items; tracked throughout.
2. **Post-776 anchoring verified** — current-system = profile = `fnq2s2xrf…` (system-776); booted = `pvxdlg20` (774, expected — no reboot since 10:34). Boot chain audited: `nix run .#pre-reboot-check` vs 776 → **19 PASS / 2 WARN / 0 FAIL, "SAFE TO REBOOT"** (three-way anchor holds: ESP default `nixos-2111767c…` = profile = running; 13/13 menu entries bootable from the live store; 3 ladder pins resolve; next nix-gc rooted; booted-system gcroot intact).
3. **776-vs-775 delta explained — NO parallel code changes** — the 3 pushed commits are the handoff session's own daemon batches (fastflowlm revert 10:48, AGENTS+TODO 11:16, status doc 11:21); the 22-path / +1.40 KiB closure churn is dirty-tree→clean-tree `self.rev`/`dirtyShortRev` propagation (775 built dirty, 776 built from committed HEAD). Benign.
4. **The "new-metric loan" mystery ROOT-CAUSED and FIXED** — the pre-deploy §10 auto-loan (`cloud_sync_consecutive_failures`, `cloud_sync_upload_backlog_size`, `collector_events_collected`) fired on every deploy forever because the TO-BE-DEPLOYED side read the raw `.nix` source (`GATUS_CONFIG="modules/nixos/services/gatus-config.nix"`, pre-deploy-check.sh:234) where monitor365's checks live inside `lib.optionals (config.services.monitor365.enable …)` — while the deployed YAML (store `7b9mba23…-gatus.yaml`) contains **zero** monitor365 pats (verified: `grep -c` = 0). Monitor365 has been disabled since 2026-08-12, so those metrics can NEVER "appear post-switch". **Fix:** the to-be-deployed side now evals the RENDERED config — `nix eval --json .#nixosConfigurations.evo-x2.config.services.gatus.settings | jq '.. | strings | gsub("\n";"\\n")'` (the gsub re-escapes real newlines so anchored `pat(*\n<metric>` forms stay extractable), with a warn-labeled source-grep fallback if the eval fails. **Verified BEFORE editing** (`/tmp/loanverify.sh`): old mechanism reproduces the exact false trio; rendered-vs-deployed diff is EMPTY both directions. `bash -n` clean; classifier fixture selftest (`scripts/test-pre-deploy-metrics.sh`) all green.
5. **Docs updated** — AGENTS.md loan bullet (line ~709) now records the rendered-vs-source rule; TODO_LIST line-33's "correctly auto-loans the 3 monitor365 metrics" claim corrected inline (it was the false-positive, not a feature).
6. **llama containment RESTORED** — the 776 deploy's stc target cascade RE-ARMED both stopped llama units (~11:19) straight into the known 94%-CPU mid-load spin regression (verified live: both at 93.9% CPU, elapsed 28:16, `:8848/:8849` → 503, GPU idle). Stopped both at 11:52 (inactive, clean). The every-deploy re-arm hazard is documented in TODO_LIST (llama-rag item).
7. **Guard Zone 6 restore path SOURCE-VERIFIED (Q1 evidence, no action)** — restore fires on MEMORY-calm gates only (MemAvailable ≥ threshold, memory-PSI avg10/avg60 < thresholds, episode bucket, 600s cooldown — memory-emergency-guard.nix:451-488); **no io-PSI gate exists**. Consequence observed live 11:24→11:47: Zone 6 trips (#71, #72) → memory-calm restore (11:44, restore 2 of 3 daily) → consumer reconnect (11:46:15) → 21.6 GB cold load (15.7 GB read / 32G mem peak in 1m44s) → re-trip (#73, 11:47:51) → socket down. A pure-IO storm with calm memory produces a trip→restore→cold-load→re-trip churn loop bounded only by the 3/day restore budget.
8. **nix-gc truth established** — the timer DID fire Sep-14 00:00 (`LastTriggerUSec`; next: Sep-15 00:00); the "no runs since Sep 11 00:04" journal read is the weekend **journald ENOSPC silence** class (documented in the handoff — the runs happened, the journal couldn't record them). All 3 ladder rung targets verified present in the store post-gc (`g9ghy625`, `zkaacn2a`, `p0ccbqj5`).
9. **BTRFS Emergency Reserve red RESOLVED** — `btrfs_emergency_reserve_present 1` (the boot unit recreated the file at 10:34); the weekend Gatus red self-healed. No action needed.
10. **Quick wins swept** — my previous session's tmux helpers: already gone (no server); the stray tq e2e process (PID 517154 from the deploy's double-pool warning): already exited; `systemctl reset-failed 'fastflowlm@*'`: no-op (the deploy's reset had cleared it). Failed units = exactly the 2 known (inboxclean-sync = user-step blocker; service-health-check = reporter).
11. **Monitoring reconciliation** — SigNoz coverage: 6 services reporting spans (dnsblockd/bank-sync among them), renamer+gotenberg 0 (event-driven, 720h budget — by design), hermes/overview/papdashboard/PMA 0 (known `wiring="upstream"` gaps) → the "traces_missing 3" baseline FAIL composition confirmed benign. `node_psi_io_alert 0`.

## b) PARTIALLY DONE

1. **Soak clock (day 1 of 3, through ~Sep-17)** — daily cadence 2/3 done today (pre-reboot-check ✓, failed-units ✓); no independent smoke-baseline diff run (reused the user's 11:35 deploy smoke: 96/6/4/4, all FAILs baseline-matched; one PASS→WARN drift = quickshell 1-error-line + memory-PSI 5.97%, noted, not chased).
2. **False-loan fix** — landed in the tree (daemon will commit); NOT yet proven through a REAL §10 run post-deploy, and NOT yet shellcheck-validated through the mkApp build gate (shellcheck absent locally; `bash -n` + fixture selftest only).
3. **llama containment** — restored now, but nothing prevents the NEXT deploy from re-arming the units again (no deploy.sh stop-guard; encoding one pre-empts Q2's shape).
4. **crush-DB structural item** — TODO_LIST item ADDED (P1) with live evidence; design + PSI measurement not started.

## c) NOT STARTED

1. flm E2E (`:52625/v1/models` + baseline retirement) — correctly deferred: IO storm active (avg10 14.7% and draining at 11:57, avg60 still ~40%), guard holds the socket until calm; when it restores (3rd of 3 daily budget), the first client cold-load IS the E2E.
2. llama version-delta record + `llama-cpp-rocwmma` pin-back (Q2-gated).
3. Zone 6 io-restore gate / flm exemption design (Q1-gated).
4. `scripts/io-psi-forensics.sh` — per-cgroup `io.stat` + D-state stack capture at trap time (the 09:31 doc's e-1 rule; I walked past a live storm without capturing attribution — see d.4).
5. deploy.sh llama stop-guard (post-switch, the flm corpse-guard pattern).
6. service-health-check journal read (confirm what it is currently reporting — asserted from memory, not verified).
7. Tonight's watches: nix-gc 00:00 (4th `g9ghy625` + 2nd `p0ccbqj5` + first 776 survival), btrbk-root 23:00 (timer re-fires units the guard stopped at trip #73; Zone 6 will re-trip if IO is still hot — expected, not a fault).
8. mkApp shellcheck validation of the edited pre-deploy-check.sh.

## d) TOTALLY FUCKED UP (self-identified, this session)

1. **Wrong interim claim: "nix-gc missed 3 daily slots"** — `systemctl show` with wrong property casing (`NextElapseUSEcRealtime` vs `NextElapseUSecRealtime`) returned EMPTY output; I narrated a false "timer hasn't run since Sep 11" before checking properly. Worse: the correct explanation (journald ENOSPC silence, NOT missed runs) was in MY OWN handoff notes. Corrected within minutes via `list-timers`, but the interim claim was wrong.
2. **TODO_LIST multiedit 1-of-3 failure** — I rebuilt the line-33 old_string from an `rg` snippet instead of anchoring on the shortest unique substring; nested parens didn't match. One wasted round trip. Lesson (again): anchor edits on minimal unique text.
3. **`comm` direction mislabeled in the verification script** — `/tmp/loanverify.sh` section D labeled `comm -13 SRC TOBE` as "in source, not in tobe" (it is the reverse: column 2 = only-in-TOBE). The decisive checks (B and C) were correct and the fix stands, but the artifact carries a wrong label.
4. **No PSI attribution captured during the LIVE storm** — the guard tripped 3× while I worked (11:24/11:34/11:47) and I read only the guard journal + a top-CPU `ps`. The known improvement rule (09:31 doc e-1: capture per-cgroup `io.stat` + D-state stacks at trap time) was walked past. Evidence for "crush DBs are the driver" remains circumstantial (CPU% + handoff forensics), not this-session-attributed.
5. **Unverified claim repeated**: "service-health-check is just the checker reporting other failed units" — stated from AGENTS memory without reading its journal this session.
6. **Marginal storm-adjacent IO from my own probes** — full `ps -eo --sort`, journal sweeps, and a `nix eval` (~30s) executed while IO PSI sat at 40-60%. Each was small and justified, but the 09:31 doc's own rule (heavy jobs ride admission control; diagnostics stay bounded) deserves more discipline than I showed.

## e) WHAT WE SHOULD IMPROVE

1. **Anchor file edits on the shortest unique substring** — second occurrence of the multiedit-miss class; reconstructed long strings from tool echoes are a reliability hole.
2. **Property-name precision, or avoid `systemctl show` for timer forensics** — `list-timers --all` is casing-proof and self-describing; empty `show` output must be treated as "wrong query", never as "unit dead".
3. **Implement the PSI-attribution runbook** (`io-psi-forensics.sh`) so the NEXT storm yields attribution by default instead of another lost evidence window.
4. **Containment needs to survive deploys** — a manual `systemctl stop` of an enabled unit is reverted by the next stc target cascade (proven twice now: flm socket 2026-09-09, llama 2026-09-14). Containment stances should ship with a deploy.sh post-switch stop-guard or a config-disable in the same change.
5. **Measure gate latency when adding eval steps to deploy gates** — my fix adds a `nix eval` (~10-30s) to every pre-deploy; correctness verified, cost unmeasured.
6. **Interim conclusions about "missing" activity must clear the known journal-blindness classes first** (ENOSPC silence, cross-boot `-k` filtering) — both are already documented as recurring traps.

## f) NEXT — session-derived, prioritized

**Immediate (today):**
1. flm E2E once IO calms + guard restores the socket: probe `:52625/v1/models` (expect 200, v1.0.2 weights); retire the FastFlowLM baseline entry if green.
2. Next deploy: confirm §10 prints NO auto-loan (the fix's end-to-end proof) and mkApp shellcheck passes on the edited script.
3. Read `journalctl -u service-health-check` — confirm what it is reporting (should be inboxclean-sync).
4. Watch Zone 6: if restore #3 fires and caps, flm stays down until tomorrow — expected self-limiting, do not fight it.

**Tonight (timers):**
5. nix-gc Sep-15 00:00 — verify 4th `g9ghy625` + 2nd `p0ccbqj5` + first 776-closure survival via the ladder pins.
6. btrbk-root 23:00 vs the still-hot IO storm — Zone 6 re-trip on the resumed send is the designed behavior; verify btrbk-pool-clean heals any interrupted receive.

**Q-gated (user answers pending — no action until then):**
7. Q1 follow-up: either exempt flm from Zone 6's sacrifice list (its cold load reads `/data`, not the storming QLC root) or add an io-avg60 restore gate — today's churn loop (trips #71-73, restores 2/3) is the decision evidence.
8. Q2 follow-up: record the llama-cpp version delta (20260905 vs 20260911 nixpkgs), pin `llama-cpp-rocwmma` back OR bisect upstream; until decided, add the deploy.sh llama stop-guard (or config-disable).
9. Q3 follow-up: file the flm v1.0.3 upstream issue (gate met: live failure with `/dev/accel/accel0` present, kernel + loader theories both dead) or drop 1.0.3 permanently (upstream is at v1.0.5).

**Structural (this session's findings):**
10. ~~crush-DB migration design (new TODO_LIST P1 item): per-project `.crush/` symlink to Samsung hot-DB dir or /data, or XDG_STATE redirect; measure io PSI before/after. This is the root disease behind today's forced deploys AND the Zone 6 churn.~~ done (TODO_LIST P1 row landed same day)
11. ~~`scripts/io-psi-forensics.sh` (e.3 / 09:31 e-1) — attribution capture at gate/guard fire.~~ done (scripts/io-psi-forensics.sh landed 2026-09-14 14:42 + guard wiring (CHANGELOG))
12. deploy.sh generic "stopped-for-containment" post-switch stop-list (flm corpse-guard pattern generalized; llama is the first consumer).
13. Verify the pre-deploy §10 eval-added latency (e.5) during the next calm-window deploy.
14. Soak cadence through ~Sep-17: daily pre-reploy-check + failed-units + smoke-baseline diff; surface new reds (candidates to watch: quickshell 1-error WARN, memory-PSI WARN).
15. After Q2 lands: retire the 4 llama smoke baseline entries; verify `/v1/embeddings` 1024-dim + `/v1/rerank` ranking per post-deploy-check.
16. After Q3 lands (either branch): update AGENTS flm bullet with the disposition (v1.0.2 permanent vs upstream-triaged).

**User-owned (reminders, unchanged):**
17. InboxClean `main` re-consent (consent screen → "In production" FIRST, then the auth runbook).
18. Resend domain verification (`larsartmann.cloud`) — completes Mail Relay go-live + Pocket ID delivery.
19. Paperless retro-decrypt: upstream push + lock bump, then the user-run backfill runbook.
20. Miniflux SSO link flow (Settings → "Link your Pocket ID account") → then the disableLocalAuth flip decision.
21. Samsung p1 pull (post-soak): ESP mirror fate + P1 backlog sweep.

## g) QUESTIONS (cannot be answered from the system — unchanged, now with new evidence)

1. **Zone 6 vs flm (Q1)** — keep flm on the IO-zone sacrifice list, or exempt it? New evidence this session: the restore path keys on MEMORY-calm gates only, so a pure-IO storm with calm memory produces a bounded but real churn loop (3 trips + 2 restores before noon; each restore re-arms a 21.6 GB cold load that itself worsens the storm). Exempting flm stops the churn but leaves the NPU model loading into a storm; an io-restore gate fixes the loop without exempting.
2. **llama RAG (Q2)** — quick pin-back of `llama-cpp-rocwmma` to the 20260905-era build (restores RAG + retires 4 smoke reds today), or leave dark and bisect the gfx1150 regression upstream? Note: until decided, EVERY deploy re-arms the stopped units into the 94% spin (needs a manual stop or the Q2 config change).
3. **flm v1.0.3 upstream issue (Q3)** — file now or drop 1.0.3 permanently? The "file only if it fails post-fix" gate is met (live failure with `/dev/accel/accel0` present; kernel-ABI and loader-path theories both falsified; v1.0.2 proven loading on the same kernel). If dropped permanently, the AGENTS "staged v1.0.3" narrative should be closed out instead.

---

**Machine state at report time (12:06):** system-776 current=profile (anchoring triple green, SAFE TO REBOOT per audit); booted 774; guard Zone 6 active (io avg60 ~40% decaying, avg10 14.7%), flm socket DOWN (trip #73, cooldown 547s/600s at 11:57), restores 2/3 used; llama units stopped (containment); failed units = the 2 known; reserve present; ladder 3/3; next nix-gc Sep-15 00:00. Parallel-session activity noticed: a CV build (`ab38c4f`) was compiling mid-session — flagged, not touched.
