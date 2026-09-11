# Status Report — Task-Queue Window Closeout: Five Decision/Documentation Tasks (000001a08e…f057)

**Date:** 2026-09-11 09:41 CEST
**Scope:** the five-task window dispatched to this repo — T14 emergency-reserve pinning (…d84088), Google Sync DORMANT (…b020c), off-site backup decision (…f1cb), 🔑 key-rotation nag (…30976), Turso plan decision (…f057)
**Window commits:** `a84f8701`, `9bcf79d9`, `84c70af5` + `09d481b0` (+ verification dispatches `91e387fd`, `e500d65b`), `4a2d5fd2`, `cee81cbe` (+ idempotent re-verification `6278f909`); supporting research `docs/research/hetzner-storagebox-borgbackup.md`
**Character of the window:** every task was a decision record, an annotation, or a triage. Zero `.nix`, zero code, zero config changes. All verification was docs/repo/live-read-only.
**Report format:** Markdown per the dispatch (the status-report skill's HTML default overridden by explicit instruction — flagged per skill contract, consistent with all five per-task reports).

---

## a) FULLY DONE (verified against commits and tree state, not claims)

| # | Completed | Evidence |
|---|-----------|----------|
| 1 | **T14 — emergency-reserve snapshot-pinning caveat documented, TODO closed** | AGENTS.md BTRFS "Emergency reserve" bullet now carries the caveat: the 10 GiB reserve's extents are pinned by daily btrbk root snapshots — `rm` frees them only as snapshots expire (3d+1w), not instantly; a periodic rewrite timer was evaluated and REJECTED (CoW churn for near-zero benefit with ~222 GiB chunk-unalloc as the real headroom); the `unalloc >10G` re-check stays the safety gate. TODO row `[x]` with DONE note. Commit `a84f8701` (2 files, clean, footer present). |
| 2 | **Google Sync declared DORMANT with an explicit go-live checklist** | AGENTS.md Google Sync section header now carries: `STATUS: DORMANT (2026-08-31 finding, confirmed 2026-09-11) — NOT deployed`, `enable = false`, no units on evo-x2, "nothing below describes a running service", plus the full 5-step user go-live sequence (OAuth client in production, `rclone authorize` ×3, sops scaffold fill, enable+deploy, 1.9 TB seed verify). The session went beyond the 2026-08-31 doc finding and verified dormancy is STRUCTURAL: no `services.google-sync` line in configuration.nix, backup-coordination registration inside `mkIf cfg.enable` (`google-sync.nix:307`), Homepage tile guarded (`homepage.nix:53`), sops declaration `optionalAttrs` (`sops.nix:414`). TODO row `[x]`. Commit `9bcf79d9`. |
| 3 | **Off-site backup 3rd-copy decision made, recorded everywhere, implementation spawned** | DECIDED: Hetzner StorageBox BX11 + BorgBackup (repokey-blake2, port 23; BX11 already purchased = zero new recurring spend). Rejections recorded with reasons: Google Photos/Drive (`google-sync` DORMANT + mirrors live data, not snapshots — fails 3-2-1 alone) and sdf WOOACME vault rotation (drive FROZEN by user decision, manual cadence = unbounded RPO). Blueprint updated and committed (`84c70af5`); TODO decision row `[x]` + NEW unchecked implementation item spawned (`platforms/nixos/system/backup.nix`, sops `borg_password`, port-23 SSH key, monitoring, the 1 TB BX11 sizing caveat: exclude ~700 G of rebuildable /data trees, BX21 upgrade trigger at ~800 G irreplaceable). AGENTS BTRFS Backups paragraph synced (`09d481b0`). A SECOND dispatch of the same queue item found the closure complete, independently re-verified it, and closed the one gap the first session had flagged: the stale DEFERRED stances in ROADMAP.md and FEATURES.md (3 locations) now read DECIDED + not-yet-deployed + TODO pointer. |
| 4 | **Key-rotation nag triaged from live state — the item was ~80% already done, undocumented** | (1) Resend: the REAL new key IS deployed — live textfile `mail_relay_credential_placeholder 0`; the Pocket ID paste is CIPHERTEXT-CONFIRMED (commit `467983e8` changed exactly ONE of `pocket-id.yaml`'s six data blobs; the session proved experimentally that sops preserves unchanged values' ciphertexts, so a single-blob diff proves the plaintext changed — 2026-09-06, same sitting as the relay key). (2) Synthetic: rotated 2026-08-18 (`43e11129`) — row was stale. (3) Context7 "update MCP config" half MOOT — zero references in rendered crushrc AND crush.json (verified). The TODO row now carries the verified triage with an honest `— BLOCKED:` tail (remaining steps are external Resend/Context7 dashboard actions + sudo-only checks). Commit `4a2d5fd2`. New durable repo knowledge: **sops ciphertext-preservation** (a value's ENC blob changes iff its plaintext changes) turns `git log -p` into a sanctioned no-sudo rotation verifier. |
| 5 | **Turso plan decision closed: local-first stance encoded, upgrade declared user-owned** | Live journal re-verified: the push failures are `SQL read operations are forbidden … code: BLOCKED` — the free plan is ACCOUNT-level blocked while the token still AUTHENTICATES, so re-auth cannot fix it and only "upgrade" remains live (a billing action). The module already encodes the strictly-superior posture (`discordsync.nix`: `backend = "turso-sync"` + upstream quota fallback = fully local SQLite with AUTOMATIC cloud-resume on upgrade, vs bare sqlite which would lose auto-resume AND cost a 40+ min FTS5 backfill). Gatus "DiscordSync Turso Sync Active" stays RED by design (the stale-mirror signal); sops TURSO_* keys retained for the resume. AGENTS DiscordSync section carries the full rationale + re-open triggers. TODO row `[x]`. Commits `cee81cbe` + `6278f909` (the re-verification dispatch's NEW finding: an upstream circuit breaker — 5 consecutive failures → 1h backoff — bounds the noise to 167 failures/24h measured, not a literal 5-min cadence; AGENTS amended accordingly). |
| 6 | **Every closure followed the file conventions** | All five TODO rows marked `[x]` in place with rationale kept (this file's convention); all work commits carry the exact `Task-Queue-ID:` footers; `nix flake check --no-build` green at each step; nothing pushed; no secret values ever written to any file or command line (ciphertext-only inspection for the sops work). |

## b) PARTIALLY DONE

1. **The 3-2-1 posture itself (the offsite task's substance)** — the DECISION is done; the PROTECTION is not. Until the Borg leg deploys, the third copy does not exist and the pool still dies with the house. The implementation item (TODO_LIST, spawned this window) is the single real remaining gap; it is blocked only on user-side StorageBox credentials (see g.2).
2. **Key rotation** — agent-executable portion 100% done and verified; the outcome is ~2 user dashboard steps away (verify `larsartmann.cloud` in Resend → unblocks BOTH relay and Pocket ID delivery; rotate Context7). One sudo-only check remains (does the Pocket ID key byte-equal the relay key?). The PERSISTENT NAG row stays open with the BLOCKED tail.
3. **Google Sync** — the DORMANT arm of the either/or is done; the go-live arm is untouched by design (interactive OAuth + secret values). Pre-work an agent could do (runbook, free-space pre-check, VM test) deliberately not started — gated on the go-live intent question (g.3).
4. **Turso** — decision encoded and documented; the user-owned billing branch (upgrade vs permanent local-only, and if local-only: what happens to the stale cloud DB) is the entire remaining substance.
5. **"Confirmed 2026-09-11" honesty gradient** — the Google Sync DORMANT banner's confirmation is DOC-level + repo-eval (correct and verified), NOT a fresh `systemctl` probe (sandbox-blocked). The 05-56 report self-flagged the overclaim risk; the wording discipline item is harvested below.
6. **TODO_LIST ↔ AGENTS reconciliation debt** — this window's triage falsified one AGENTS claim (the Secret-Leak table still asserted the DEAD Resend key was deployed for Pocket ID). Corrected in this closeout pass (living-doc maintenance, see CHANGELOG), but it is the recurring pattern: verification rounds land in TODO_LIST first, AGENTS reconciliation lags.

## c) NOT STARTED (backlog the window skipped — tracked, not forgotten)

1. **Implement the offsite Borg leg** (the spawned item) — module, sops secret, SSH key, timer, monitoring, exclusion list.
2. **All 5 Google Sync go-live steps** — user-owned, gated on intent (g.3).
3. **Resend domain verification + Context7/Gemini dashboard actions** — user-owned (existing rows cover these; the nag row's triage sharpened them).
4. **Turso upgrade or local-only cleanup** — user-owned billing decision (g.1).
5. **Everything else in TODO_LIST P0** — the window did NOT touch: the /data corruption repair chain (gate (b) scrub still pending the scrubGuard-fix deploy + a root run; T06a deletion sign-off), the owed flm reboot (:52626 corpse recurred on the 2026-09-07 boot; v1.0.3 staged and build-verified, kernel-premise falsified), btrbk-data marker-gate, Hermes cron errors, paperless email-smoke red. Correctly out of scope for five decision tasks; listed so the skip is explicit.
6. **Per-task section-(f) harvests** — the five per-task reports brainstormed ~200 next-things; none were mass-inserted (HARVEST's job). This closeout pass performs the routing (see the TODO_LIST additions and the report's f-section).

## d) TOTALLY FUCKED UP (regressions, broken gates, debt — verified)

Nothing in this window broke the build, the tree, or the system — `nix flake check --no-build` green throughout, zero non-doc files touched. The honest damage list:

1. **The queue re-dispatched at least two already-closed items.** The offsite decision (task …f1cb) and the Turso decision (task …f057) each got a SECOND dispatch hours after their closing commits landed under the SAME Task-Queue-ID. Both re-dispatch sessions detected it in ~2 tool calls and converted into verification passes (the Turso one even produced a genuine new finding — the circuit breaker), so the waste was recycled. But the system survived by process luck, not guardrails: a worker who skipped the `git log --grep <Task-Queue-ID>` idempotency check would have re-made the decisions and clobbered richer closure lines with thinner ones. Queue-side done-filter: still missing.
2. **Auto-commit daemon raced three of five task sessions mid-commit.** Each session's staged files were swept into a heuristic batch commit before their pathspec commit ran; each recovered by verifying the batch contained only their files and amending into a proper message. Recovered ≠ safe: on a busier tree (parallel sessions are the norm here) the amend gambles with foreign files.
3. **One evidence claim was committed wrong and self-corrected 30 minutes later (key task).** The session first reasoned that sops re-encrypts everything per save (making blob diffs meaningless), committed "plausible but UNVERIFIABLE" — then a 60-second throwaway-keypair experiment proved the exact opposite, upgrading the verdict to CIPHERTEXT-CONFIRMED. Root cause: hanging a conclusion on remembered tool semantics instead of running the trivial test first. Cost: the repo carried an under-claim for ~2 hours. Lesson harvested (60-second-experiment rule).
4. **AGENTS.md lied about the Resend/Pocket ID state for 5 days.** The Secret-Leak table asserted "Pocket ID email sending is BROKEN until a new Resend key is generated" while the real key had been deployed 2026-09-06 (ciphertext-provable from git history the whole time). Anyone reading AGENTS would have re-done finished work or misdiagnosed. Corrected in this closeout pass; the class (AGENTS asserting stale secret states in present tense) is the same one the docs-health pass exists for.
5. **Stale DEFERRED vs fresh DECIDED stance split-brain lived ~20 minutes.** The first offsite session closed the TODO + AGENTS but left ROADMAP/FEATURES carrying the 2026-09-05 DEFERRED stance; the re-dispatched second session caught and fixed it. Two sessions to reach what the "decisions must atomically spawn TODOs + sweep living docs" convention does in one commit.
6. **Found in passing (not window damage, now tracked):** the mail relay's 550-bounce state is invisible to every check (queue drains instantly → "Mail Relay Queue" green while sending is broken — 5 days of silence); `/run/secrets/sops-nix-age-key` is referenced by quickshell.nix + the DMS sops widget but absent at runtime (probable ghost system, one root `ls` from a verdict); AGENTS' purge-runbook block still carries full plaintext leaked key values (stale the moment rotation kills them); the mail-relay P1 TODO row still says "PLACEHOLDER credential" (stale since 09-06). All appended to TODO_LIST rather than fixed here (hard scope: docs-only, and TODO rows are append-only this session).

## e) WHAT WE SHOULD IMPROVE (process + code, concrete)

1. **Queue idempotency contract (highest leverage).** Step 1 of every queue task: `git log --grep=<Task-Queue-ID>` + check the TODO row's `[ ]`/`[x]` state; on a hit, downgrade to verify-and-close-gaps. Two of five window items would have been single-dispatch. Queue-side done-filter is the permanent fix; the worker-side check is the portable one.
2. **Decisions must land atomically: decision + implementation TODO + AGENTS/ROADMAP/FEATURES sync in ONE commit.** The offsite decision took two sessions and a re-dispatch to reach consistency. Make the living-doc sweep part of the closure checklist, not a follow-up.
3. **Auto-commit daemon vs queue-task attribution.** Adopt: single-command pathspec commit immediately after verification, followed by `git log --oneline -1` verification; on daemon-race detection, verify the batch composition before amending. Longer term: daemon-side skip for files named in an active task, or queue-work commits within one daemon tick.
4. **Never hang a conclusion on untested tool semantics** — the 60-second-experiment rule. The sops ciphertext finding (the window's most useful new fact) came from exactly the test the session should have run BEFORE its first commit.
5. **Freshness-first for PERSISTENT NAG rows.** First action on any nag: verify each sub-claim against live state. The key-rotation item was 2/3 stale when picked up; discovering that in round N instead of round 1 wasted the session's best hour.
6. **Date-stamp WHAT KIND of confirmation** — "confirmed <date>" must say doc-finding vs live-probe. Cheap wording discipline; prevents the DORMANT-banner overclaim class.
7. **Sanctioned read-only host probes for agent sandboxes.** `systemctl list-unit-files` is blocked, so deployed-state claims stay doc-inferred. An allowlisted inventory script would let queue tasks verify against reality (needs an owner decision — see TODO).
8. **Generalize the DORMANT/DISABLED banner pattern.** monitor365 and google-sync now have explicit banners; a VERIFY sweep for other ships-disabled sections reading as-live would prevent the next 11-day-old doc bug.
9. **Split atomic NAG rows + actor tags.** One row bundling three keys (plus USER/ROOT/AGENT steps) forces all-or-nothing closure semantics; `(USER)/(ROOT)/(AGENT)` prefixes would let sessions skip without archaeology.
10. **Rotation ledger.** This task was 100% archaeology. `docs/security/rotations.md` (per key: created/rotated dates, sops location, residue map, verification command) kills the class; the ciphertext-diff pipeline becomes its standard tool.

## f) UP TO 50 NEXT THINGS (most valuable first; harvested into TODO_LIST with dedupe — items already tracked there are not repeated)

**Direct follow-through of the window:**
1. Implement the offsite Borg leg per the blueprint (tracked item exists — execution now unblocked once g.2 lands).
2. Offsite restore path: runbook + first timed restore drill — the blueprint covers backup only; an untested restore is Schrödinger's backup.
3. Offsite retention/prune policy + archive-size metric with the BX11→BX21 trigger at ~800 G irreplaceable set.
4. google-sync pre-work (gated on g.3): `docs/services/google-sync.md` runbook, pool free-space pre-check (≥2 TB incl. grace), config-check fail-fast VM test, rclone flag re-check.
5. Create `docs/security/rotations.md` + backfill from the key triage verdict table.
6. postfix `status=bounced` journal-rate metric + Gatus check (kill the 550-invisibility class); after domain verification add a weekly relay canary send + a Pocket ID SMTP failure signal.
7. ROOT: sudo decrypt cross-check Pocket ID key == relay key; relay E2E test send; one Pocket ID email — closes the rotation orbit.
8. ROOT: settle the `sops-nix-age-key` ghost (fix render or retire the DMS/quickshell references).
9. Self-document the deliberately-red Turso Gatus check; create `docs/services/discordsync.md` (local-first stance + circuit-breaker cadence + DLQ replay pointers).
10. Scrub the full plaintext key values from AGENTS' purge-runbook block once Context7 + Gemini are dead (values → REDACTED; command stays).
11. Queue: done-filter / idempotency short-circuit; document the idempotency-first step in `docs/services/tq.md`; contract note that zero-change runs skip builds.
12. Daemon-race convention: single-command pathspec commit + immediate verify (or daemon-side task-file skip).
13. Fix the stale mail-relay P1 TODO row (placeholder wording → real key deployed 2026-09-06).
14. docs-health pass: move the four closed 2026-09-11 `[x]` rows to CHANGELOG and trim narratives (per the file's own lifecycle).
15. Re-verify live chunk-unalloc (the 222.41 GiB figure cites 2026-09-02) and prefer the `btrfs_device_unallocated_bytes` metric over frozen figures in AGENTS/TODO.
16. AGENTS DORMANT-banner sweep over other ships-disabled sections; adopt the "confirmed <date> (doc-finding|live-probe)" wording convention.
17. Sanctioned read-only host-state probe script for agent sessions (owner decision).
18. Decide agent sops-write capability (user age key as `.sops.yaml` recipient) — converts the sudo-only BLOCKED class into executable work; widens agent blast radius to every secret.
19. Snapshot-pinning doctrine sweep: document pinning for other large intentionally-deletable trees (flm weight staging, jan model tree) before an ENOSPC teaches it.
20. AGENTS.md size: split per-service runbooks fully into `docs/services/` with short pointers (fresh-session context cost keeps growing).

**Neighboring P0s the window saw in passing (already tracked — execution order matters):**
21. /data corruption repair: deploy the scrubGuard `lib.getExe` fix, complete gate (b), then the user-signable 10-file deletion recipe (btrbk-data resumes ~1 day later; scrub greens ~4w later).
22. The owed reboot: clears the flm :52626 corpse + D-state wedges; then the staged flm v1.0.3 go-live runbook (build-verified; kernel-premise falsified; revert path defined). `nix run .#pre-reboot-check` first.
23. Resend domain verification → mail relay + Pocket ID delivery go-live (the single step that unblocks the most user-facing brokenness).
24. `NIX_GITHUB_RO_TOKEN` CI secret (120+ dark runs; 10-minute user step).
25. Hermes cron scheduler ERRORS (live since 09-05); Hermes PAT go-live.
26. memory-emergency-guard corpse-aware restore skip (P1 candidate, post-soak).
27. CV `min_day_rate` value decision (user); InboxClean decrypt password paste (user); paperless mobile-app T13 decision (user).
28. ClickHouse telemetry backup coverage (no backup leg today); legacy paperless SQLite export decision.
29. btrbk receive-freshness + pool-snapshot freshness gauges; `backup_ever_succeeded` metric (both feed the Borg leg's monitoring).
30. tq pool: flip the interim `git+file?rev=` input to `github:` once go-taskqueue pushes (CI cannot fetch git+file).

**(30 substantive items — the remaining slots would be padding; TODO_LIST's existing 211 open rows are the rest of the backlog.)**

## g) QUESTIONS ONLY THE OWNER CAN ANSWER (3)

1. **Turso: upgrade the plan, or make local-only permanent?** Upgrade = sync auto-resumes on the next discordsync start, zero config change, the red-by-design Gatus check goes green. Permanent local-only = remove TURSO_* from the sops template + drop the check (a cleanup task). Sub-question if local-only: does the stale cloud DB (frozen since 2026-08-16) have any retention value, or should it be deleted Turso-side? *Tried: live journal (plan BLOCKED at account level, token authenticates), module posture, AGENTS — everything except the billing intent is settled.*
2. **Offsite Borg go-live inputs:** (a) StorageBox hostname + username (uXXXX) so SSH connectivity can be provisioned; (b) where should the `borg_password` recovery copy live (password manager / printed / split — a wrong answer here is unrecoverable data loss on the first dead disk); (c) is anything inside the "rebuildable" trees actually irreplaceable to you (Steam save games / Proton prefixes, personal fine-tunes, curated GGUFs) that must be INCLUDED despite the 1 TB budget? *Tried: repo, blueprint, sops scaffold — no credentials or policy exist anywhere in the tree.*
3. **Google Sync: do you actually want the Drive mirror live — and if so, roughly when?** The DORMANT annotation closed the agent-executable arm; whether to invest in the pre-work now (runbook, free-space check, VM test — one bounded agent task) or leave the service parked indefinitely is a pure intent call. The 5-step go-live itself remains yours either way (interactive OAuth + secret values). *Tried: TODO/AGENTS/ROADMAP for a timeline signal — none exists.*

---

*Point-in-time snapshot — goes stale by design. The five per-task reports (`05-32`, `05-56`, `06-31`, `06-50`, `07-21`, `08-52`) carry each session's full evidence chains; `07-21` stays top-level (its nag row is open) as do `08-02`/`08-23` (cited by the open reboot row). The closed-task reports are archived per convention.*
