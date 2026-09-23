# Window Closeout — ClickHouse-backup verification + offsite-Borg restore path + 3 review-finding fixes

**Date:** 2026-09-23 ~14:55 CEST
**Window:** 5 queue tasks (2026-09-23 04:00 – 10:49), all storage-domain, all in the backup/DR family
**Task-Queue-ID (this closeout):** 000001a0cd82286c5732569a0096d8289a60
**Sources read:** the five window closeout reports (linked per section), the tq facts journal (`/mnt/pool/services/tq/tq.db`), and direct verification of every cited commit (`git cat-file -e` — all present and ancestors of HEAD).

| Task | Subject | Work commit | Report |
| --- | --- | --- | --- |
| `…cb25e960` | ClickHouse backup before the next SigNoz upgrade (verification-only; already closed by `f264a805`) | `bd60d8d3` (report only) | `docs/status/2026-09-23_04-00_task-000001a0cb25e96009674c891282a42ef057.md` |
| `…8af769f4` | Offsite Borg restore path: runbook + first timed drill (3rd dispatch; work landed in `f845d1e9`) | `af5a9726` (+ on-sight fixes in `08b43662`) | `docs/status/2026-09-23_07-47_task-000001a0cc8af769f497a7204704871623f0.md` |
| `…d068f792` | Review fix: banned `/run/secrets-rendered` literal in drill + runbooks | `f16f6cc5` | `docs/status/2026-09-23_09-30_task-000001a0cd068f79239e5320030b96d20ad4.md` |
| `…d068f909` | Review fix: false "host-key pin rides in the archive's etc/" claim in the restore runbook | `49677fd3` | `docs/status/2026-09-23_10-25_task-000001a0cd068f9098f0cc0f10671a06716e.md` |
| `…d068fb02` | Review fix: `--help` truncation in `scripts/borg-restore-drill.sh` (hardcoded `sed -n '2,30p'` → derive-from-first-non-comment awk) | `27c081e4` | `docs/status/2026-09-23_10-49_task-000001a0cd068fb027be90286d1e88ac57b8.md` |

Post-window, same family: `818d0ca4` (env-path eval pin in `backup.nix` + repair of a parallel commit's missing paren that had broken every evo-x2 eval at HEAD) and `f089c982`/`592559ec` verification docs — verified present; the tq review verdict on `…cd822838` approved the pin with independent re-eval evidence.

---

## a) FULLY DONE

1. **ClickHouse native server-side backup** — implemented and independently re-verified: `clickhouse-db-backup.service` runs `BACKUP ALL EXCEPT DATABASES system, INFORMATION_SCHEMA, information_schema TO File(...)` into timestamped runs under `/mnt/pool/backups/clickhouse` (3-run retention, failed-run self-clean), `<backups><allowed_path>` legality in extraServerConfig, mount-gated `clickhouse-db-backup-dir` leaf (deploy.sh provisioner loop), `User=clickhouse` + `RequiresMountsFor` + ioTier.background, `.last_success` → backup-coordination → "All Backups Healthy". **Code+eval done; first run deploy-gates — the pre-upgrade rollback case is NOT yet covered on the host.** (04:00 report §a, verified against `signoz.nix` + `deploy.sh`.)
2. **Offsite-Borg restore path** — `docs/services/offsite-borg-restore.md` runbook + `scripts/borg-restore-drill.sh` (real/`--local`/`--selftest` modes, timed connect/extract/verify, sha256 byte-verify, scratch-only extract, per-run records). Drill **live-executed**: `--selftest` PASS (best 230/233/6 ms = 469 ms; 5 PASS records 469–739 ms under `~/.local/state/borg-restore-drill/`). Real-repo drill deliberately parked at go-live checklist step 9 (owner-held StorageBox inputs). (`f845d1e9` + `08b43662`; verified this session.)
3. **Review finding 1 (rendered-env literal):** all 3 in-scope `secrets-rendered` literals fixed (`f16f6cc5` — drill real-mode default, restore runbook :62, pre-existing literal in offsite-borg.md :78); repo re-sweep = 0 remaining; module side already interpolated (`backup.nix:147`). Shellcheck + audit-script + pre-commit green.
4. **Review finding 2 (provenance):** the false "host-key pin rides in the archive's `etc/`" sentence replaced with the true sops re-render mechanism (`49677fd3`, +8/−3 docs-only), verified against `sops.nix:479-497` (tmpfs render) and `backup.nix:52-57` (archive paths exclude `/run`); contradiction with the dead-host table resolved.
5. **Review finding 3 (`--help` truncation):** usage printer no longer slices a hardcoded range; live-verified full help through `Exit codes:`, exit 2 preserved, byte-identical body (`27c081e4`); drill `--selftest` re-run PASS (478 ms).
6. **Drill env-path eval pin** (follow-on from finding 1): `backup.nix` carries an unconditional top-level `mkMerge` assertion branch pinning the drill's `BORG_ENV_FILE` literal to `config.sops.templates."borg-env".path`; drift fails `nix flake check` naming the expected literal. Reviewer-approved (`…cd822838` verdict) with an independent re-eval; includes the paren fix that repaired the broken evo-x2 eval.
7. **Queue hygiene:** all window items `[x]` in TODO_LIST with coherent `docs/todo/storage.md` library rows; `scripts/check-todo-system.sh` green; every work commit carries exactly one matching `Task-Queue-ID` footer; nothing pushed.

## b) PARTIALLY DONE

1. **ClickHouse backup is code-done, not operationally done** — zero backup runs have executed (deploy-gated 03:00 timer). No ClickHouse restore drill exists; a never-restored backup is a claim, not a capability.
2. **Drill verification is stand-in depth** — real-repo (WAN/SSH/decrypt) leg never exercised; `--archive`/`--subset`/`--keep` flags never run; negative tests trusted from a prior session rather than re-derived (07:47 report §b). Real-mode `BORG_REPO` quoting assumption unverified.
3. **The banned-literal scanner gap is diagnosed, not fixed** — `audit-textfile-tmp.sh` class B scans only `.nix` under modules/platforms/tests/lib; `.sh`/`.md` surfaces (where this finding lived) are invisible. Backlogged (`docs/todo/pipeline.md`), not implemented.
4. **Reviewer's "ideally interpolate the env path"** — superseded: the eval-time pin (a.6) landed the stronger form; the drill still hand-writes the literal, but drift is now machine-caught.
5. **Offsite-Borg itself remains DORMANT by design** (`enable = false`, system-796) — all of this window's work is pre-positioning; go-live waits on owner inputs.

## c) NOT STARTED (backlog items the window skipped — untracked before, now routed)

- ClickHouse native-BACKUP restore drill (dir-mode → scratch cluster) — **appended this pass**.
- Repo-wide sweep for the hardcoded help-slicer idiom (`sed -n '2,Np'` over comment headers) — **appended this pass**.
- DR-runbook provenance checklist line in `docs/CONTRIBUTING.md` — **appended this pass** (library entry in storage.md).
- Everything owner-gated: go-live inputs, recovery-copy policy, real-repo drill, deploy authority decision (3+ closeouts blocked on it; unchanged).

## d) TOTALLY FUCKED UP (defects surfaced/fixed; debt introduced)

1. **The rejected original commit (`f845d1e9`) shipped under a false coherence claim.** Two new artifacts hardcoded the banned `/run/secrets-rendered` literal and a third pre-existing instance sat one line above text the same commit edited — while its message claimed the fix was "now coherent in both runbooks and the drill". Root cause: `.sh`/`.md` invisible to the path-literal scanner; the recurrence was a **17-day-old entombed follow-up** (2026-09-06 sweep report item 29) that never got harvested. All 3 sites fixed in `f16f6cc5`; scanner extension backlogged.
2. **A false DR-runbook provenance claim** ("pin rides in the archive") that would have cost an operator critical DR time; contradicting evidence sat in the SAME document (dead-host table). Fixed `49677fd3`. Lesson: derive "what the backup contains" from rendered-path × archive-path, never recall.
3. **An evo-x2 eval outage at HEAD mid-window** — a parallel rework commit dropped a paren in `backup.nix`, breaking every evo-x2 eval; repaired in `818d0ca4`. (Fixed, disclosed, reviewer-approved.)
4. **Queue waste: 3 dispatches for one queue ID.** The restore-path item was dispatched after its work commit AND report already existed; run 3 detected done-state in the first tool call. The "done-filter / same-ID idempotency" rule is queued upstream (`docs/todo/upstream.md`) and remains unimplemented — this window adds a third data point.
5. **Daemon-race churn (3× in one window):** the auto-commit daemon captured in-flight files in heuristic commits in three separate sessions; each was hand-verified (`git show --stat`) and amended forward per AGENTS.md discipline. No foreign files absorbed; the vigilance remains manual every time.
6. Cosmetic but real: two sessions edited TODO_LIST without View-first (rejected round-trips); one commit body used ` - ` as an em-dash stand-in (banned shape, permanent in history).

**Noticed in passing (out-of-repo, report-only):** (1) a CV task dead-lettered after 3 verify failures — `GOEXPERIMENT=jsonv2 go test ./tests/integration` FAILs on the CV repo (facts journal 2026-09-23; CV-side, tracked there). (2) A second LIVE `gho_…` GitHub token (the operator's own `gh auth token` output, 2025-05) was found in the `learnings` repo and neutralized locally (redaction committed there, **unpushed** — the token is on the private remote and still live until rotated/rotated-and-pushed). Rotation is owner action.

## e) WHAT WE SHOULD IMPROVE

1. **Sweep siblings before claiming coherence** — any "X is now consistent across A, B, C" commit must include the same-class grep over A, B, C in the same change.
2. **Guard scope must track artifact surface** — when new artifact classes start embedding infra paths (drill `.sh`, runbook `.md`), the scanner gains the surface or the artifact interpolates the value, decided at write time.
3. **Harvest status-report follow-ups at write time** — numbered follow-ups entombed in `docs/status/` are invisible to the queue (the 17-day recurrence is the proof); convention candidate: every follow-up lands in a domain todo file in the same commit or is marked report-only.
4. **Queue-runner rule (still open, 3rd data point):** footer-commit + report both present ⇒ skip/auto-close the ID.
5. **Derive, don't hardcode, structural ranges** — the awk-until-first-non-comment idiom should become the house pattern for script help printers; machine-check human surfaces (`--help` has no test until the fixture test lands).
6. **Make the status-report step atomic with the work commit** — runs 1 and 3 of the restore-path item both created reconciliation work by treating the report as optional.
7. **Run the artifact whose output a reviewer will see** — the `--help` truncation survived because nobody executed the print path after the header grew.

## f) NEXT THINGS (top items; most small and concrete)

1. **Deploy** (`nix run .#deploy`) so `clickhouse-db-backup` takes its first run; verify `/mnt/pool/backups/clickhouse` + `.last_success` + "All Backups Healthy" green — **before any SigNoz upgrade**.
2. **ClickHouse native-BACKUP restore drill** (dir-mode → scratch cluster) — queued this pass.
3. Real-repo timed Borg restore drill (go-live checklist step 9) once owner inputs exist; annotate real timings in the runbook.
4. Offsite-Borg go-live sequence: StorageBox hostname/username sops paste, `ssh-keyscan -p 23` pin (verify against Hetzner's published fingerprints), `enable = true`, first nightly run, tripwire exercised LIVE once.
5. Implement the scanner extension: `audit-textfile-tmp.sh` class B gains `scripts/*.sh` + `docs/**/*.md` (prose allowlist for incident docs) + negative test via `scripts/negative-test-lints.sh`.
6. Drill hardening batch (already queued): `/mnt/hot` mountpoint gate, FAIL records from the top, flake-pinned borg, deep-integrity mode.
7. Flake fixture test for the drill (PATH-stub borg) incl. the env-path-pin negative case AND a help-completeness assertion (folds the `--help` fix permanently).
8. Repo-wide hardcoded help-slicer sweep — queued this pass.
9. Decide + execute the third-copy placement for `/mnt/pool/backups/clickhouse` (restic-app-dumps vs offsite Borg vs neither; BX11 budget) — owner question below.
10. Persist fixture tests for the offsite-borg pre/post-deploy smoke blocks (§13/§16) + the ioTier assertion + the positive-path render probe (all already queued).
11. Confirm the borg passphrase recovery copy exists off-host and DECRYPTS (go-live step 1 — the single blocker between "repo exists" and "restore possible").
12. VM test for `backup.nix` before go-live (tripwire, job shape, marker write) — already queued.
13. Cross-machine restore verify semantics: live-`cmp` is meaningless on a dead host; add/document a manifest-based mode before the first real drill — owner question below.
14. Rotate the second live `gho_` token (learnings repo) and push the redaction — owner action, then update `docs/security` ledger item.
15. Extend `ioChurnUnits` with `crush-hot-db-migrate` + `discordsync-db-heal` (freeze-#6 lesson, still pending); the OWED reboot behind `pre-reboot-check`.

(Full per-task lists of 15–50 items live in the five window reports; everything actionable and not already queued is captured in items 1–15 + the appends below.)

## g) QUESTIONS FOR THE OWNER (also appended to TODO_LIST as BLOCKED items)

1. **ClickHouse third copy:** should `/mnt/pool/backups/clickhouse` (~3.7 GiB/run × 3) ride restic-app-dumps, the offsite Borg job, or stay pool-RAID1-only? I cannot judge the BX11 1 TB budget or how important ClickHouse dumps are for a 3rd copy.
2. **Borg drill verify semantics for the real-repo drill:** compare extracted bytes against the LIVE evo-x2 files (current design — same-host only) or against a manifest baked into the archive (proves the dead-host restore, the actual disaster case)? This shapes the drill before its first real run.
3. **Is the Borg repokey passphrase recovery copy physically stored off-host** (password manager/paper) and proven to decrypt? Nothing in the repo can verify owner-side state; host loss + sops loss without it = permanent data loss.

## h) BAND DRIFT (ADR-0015)

Read the tq facts journal (`/mnt/pool/services/tq/tq.db`, facts table) across the window: **no `task.reprioritized` facts recorded** — the window's activity is claims/requeues (dirty-tree and deadline prefights), completions with approve verdicts, and one CV dead-letter. **None recorded.** Priority movement this window came only through the normal harvest order; nothing was manually re-banded, and nothing needs retroactive justification.

---

## Docs-health notes

- CHANGELOG: window deliverables appended under `[Unreleased] → Added` (ClickHouse backup; restore runbook + drill + the three review fixes + env-path pin); the pre-existing borg entry's "restore drill" open-item line is superseded by the new entry (append-only respected — prior entry untouched).
- AGENTS.md offsite-borg section already carries the restore-runbook/drill/eval-pin state (updated by `818d0ca4`/`f089c982`) — verified current, no edit needed. FEATURES.md backup rows already reflect the dormant leg — no edit needed.
- No `docs/status/` reports archived this pass: the window's five reports are fresh and referenced by the appends below; older 2026-09 reports still carry open pointers (e.g. the 09-30 report is the cited Source of the queued scanner item). Annotation deferred until their items resolve.
- TODO_LIST: 3 new `[ready]` items + 3 BLOCKED owner questions appended; zero duplicates (dedup-checked against all unchecked rows, incl. the upstream done-filter items); no existing items ticked (all window work was already `[x]` before this pass).
