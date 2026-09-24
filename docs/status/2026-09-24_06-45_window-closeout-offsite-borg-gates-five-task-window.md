# Window Closeout — Offsite-Borg Gate & Drill Verification (5-task queue window)

**Date:** 2026-09-24 06:45 CEST · **Repo:** SystemNix @ master (`8e465d62` at report time) · **Reporter:** status-report dispatch `000001a0d1898c4825b6cf5ef2469503ea29`
**Window:** 2026-09-23 ~09:30 → 2026-09-24 06:45 CEST
**Tasks in the window (per the queue):** 5 — every one of them an offsite-borg verification/hardening item; 4 of the 5 turned out to be RE-DISPATCHES of already-closed work.

---

## Executive summary

The window's five dispatched tasks all belong to the offsite-borg reliability campaign, and all five close clean: the drill env-path eval pin (task 1, work `818d0ca4`), the DR-runbook sops-gating reviewer fix (task 2, `502db45d`), the borg-restore-drill flake fixture (task 3, `d7a54819` + daemon `860b63b9`), the pre-deploy §13 silent-skip fix (task 4, `eb2c6b3e`), and the positive-path render probe (task 5, `14fc6816`). Every deliverable was verified in-tree by this run (grep/eval evidence below). The dominant process finding: **the queue re-fired closed items 7 times across 4 task IDs in ~40 hours** — every re-dispatch produced verification-only reports and zero code. Two latent defects were surfaced by the window and are NOT yet fixed (§16 enable-blind SKIP; the EIO `/data` inode as a first-real-borg-run blocker) — both routed to the queue this pass. Band drift: **none recorded** (`tq facts --type task.reprioritized` → 0 facts).

---

## a) FULLY DONE (verified, not just claimed)

Every claim below was re-verified by THIS run against the tree, not copied from the closeouts.

| # | Task | Deliverable | Evidence verified this run |
|---|------|-------------|----------------------------|
| a1 | `000001a0cd8228…` — **Pin the borg-restore-drill env path to the sops template** | Eval-time literal assertion in `platforms/nixos/system/backup.nix` (unconditional top-level `mkMerge` branch — the in-`mkIf` placement was proven blind); pins `BORG_ENV_FILE="\${BORG_ENV_FILE:-<borg-env template .path>}"` (sops-nix default shape while dormant); fixed the parallel commit's missing paren that had broken every evo-x2 eval | Work landed `818d0ca4` (2026-09-23 13:58, same Task-Queue-ID) — the window dispatch was a **verification-only re-dispatch** (closeout `2026-09-23_14-24_…`): drift probe fired, real tree 0 failed assertions, `nix flake check --no-build` rc 0. This run: `grep -n BORG_ENV_FILE platforms/nixos/system/backup.nix` → pin + guard comment present (lines 41-56, 167-182). TODO_LIST:27 `[x]`, docs/todo/storage.md:109 `[x]` |
| a2 | `000001a0cd86bbf…` — **Fix EXACTLY one reviewer finding** (DR-runbook sops re-render claim) | `docs/services/offsite-borg-restore.md` step-2 paragraph corrected: the three borg secrets are gated behind `services.offsite-borg.enable = true`, render only after the go-live checklist runs on the replacement host; step 3 rides the owner recovery copy + manual key, NOT `/run/secrets` | Commit `502db45d` (2026-09-23 15:07, 9+/3- docs-only), closeout `2026-09-23_15-12_…`: both factual claims verified against the tree BEFORE editing (enable flag in configuration.nix; step-3 env block). One Task-Queue-ID footer, gitleaks clean |
| a3 | `000001a0d08c5ae…` — **Flake fixture test for `scripts/borg-restore-drill.sh`** | `checks.x86_64-linux.borg-restore-drill-fixture` (flake.nix:1435+) — PATH-stubs `nix` AND `borg` (the drill resolves borg via `nix build --print-out-paths --expr`, so both are needed) + `id` stub; covers root-gate die (+FAIL record), bogus `--local`, repo-without-config, PLACEHOLDER tripwire, secrets-missing die, happy-path PASS, `--verify-data` 1.x `--dry-run` fallback + `--archive` pin | Authored by dispatch #1 (`d7a54819` queue ticks; the fixture CODE rode daemon commit `860b63b9`); re-verified by dispatches #2/#3 (`01-31`, `01-39` — the window input). This run: check attr present at flake.nix:1435; TODO_LIST:33 `[x]`, storage.md:46 `[x]` with the honest sandbox note (mountpoint gate not directly assertable — `[ -e ]` is a bash builtin) |
| a4 | `000001a0d0d1f8b…` — **Fix pre-deploy §13 silent-skip** | §13 captures eval stderr; `ob_classify_eval_error` (shared lib) SKIPs ONLY the disabled shape ("does not provide attribute …borgbackup-job-hetzner.serviceConfig"); every other eval failure FAILs LOUD with raw stderr. ADJACENT FIX: the §13/§16 lib was never staged into the `nix run .#pre-deploy-check`/`post-deploy-check` wrappers (every deploy died at the §13 source line) — both wrappers now stage it | Commit `eb2c6b3e` (2026-09-24 02:59), closeout `2026-09-24_03-14_…`. This run: `ob_classify_eval_error` at scripts/lib/offsite-borg-smoke.sh:22 + wiring at pre-deploy-check.sh:768; BOTH gates `source …/lib/offsite-borg-smoke.sh` (pre:51, post:165); 18-branch fixture + `offsite-borg-smoke-selftest`; full packaged gate 64 passed / 36 warnings / 0 failed. TODO_LIST:35 `[x]`, storage.md:49 `[x]` |
| a5 | `000001a0d13bb97…` — **Persist the positive-path render probe** | `checks.x86_64-linux.offsite-borg-positive-render` (flake.nix:1936-1964) — `extendModules` render of evo-x2 with `enable = lib.mkOverride 50 true` (plain `enable = false` forces ≤50) + deepSeq eval asserts on the rendered job unit: BE/6 ioTier intact, golive-tripwire ExecStartPre, `.last_success` marker ExecStartPost, EnvironmentFile == the borg-env template path; exec-line asserts list-normalized | Commit `14fc6816` (04:45); THREE dispatches total (04:45 authored → 05:05 verify → 05:36 verify, the window input). This run: check present at flake.nix:1936; drift-sensitivity proven twice independently (priority-49 idle override throws; ≥50 leaves BE/6); registration proven via the checks attrset. TODO_LIST:37 `[x]`, storage.md:51 `[x]` |

**Same-window sibling dispatches (completed in passing, all closed `[x]`):** drill hardening (`d04c…`, row 31), restore-runbook accuracy pass + the missing Discord failure leg wired (`d067…`, `4221f607`, row 32), §13/§16 smoke-block fixture + lib extraction (`d0b0…`, `84f7ab33`, row 34), IO-tier gate in both smokes (`d112…`, `751cbc18`, row 36), extendModules probe-override gotcha in AGENTS.md (`…8ba3`, `16719c10`, row 38).

## b) PARTIALLY DONE

1. **The offsite-borg leg overall** — every guard, gate, fixture, drill, and runbook the window could build is landed and verified; the leg itself stays DORMANT pending owner inputs (storage.md:63 `[decision]`): StorageBox hostname/username, passphrase recovery-copy policy, exclusion exceptions. Nothing agent-side remains before the enable flip except the items in (c)/(d).
2. **Drill-fixture coverage** — 8 of 9 failure/success shapes asserted; the real-mode `/mnt/hot` mountpoint gate is only covered via its "direct predecessor" (secrets-missing die) because it sits behind unstubbable `[ -e ]` bash builtins (01-39 closeout §b1). Cheap fix identified (overridable mountpoint resolver) — queued.
3. **Classifier durability** — `ob_classify_eval_error` matches the disabled shape by hand-written fixture strings; no committed artifact proves REAL nix stderr against nix-version reword drift (safe direction: a reword flips SKIP→FAIL-loud, but noisy). Already queued (TODO_LIST:72).
4. **TODO_LIST:291 ↔ pipeline.md drift** — the 05-36 closeout found the queue-dedup row's library entry MISSING from docs/todo/pipeline.md and its evidence line stale. The library entry is **backfilled by this run** (docs-health maintenance); the stale evidence line on row 291 itself is left untouched (append-only contract — rewording existing rows is not allowed).
5. **Runbook accuracy follow-ups from task 2** — items f2/f3/f4 of its closeout (explicit re-pin checklist row, drill `/run/secrets` gating note, DR-claim lint tripwire) are partially absorbed: the block-by-block env sweep landed in `4221f607`, the provenance-checklist idea is queued (TODO_LIST:67), and the host-key-pin derivation question is routed as a blocked item this pass. The drill `/run/secrets` gating note specifically is folded into the new §16/§13 gate-behavior note added to `docs/services/offsite-borg.md` by this run.

## c) NOT STARTED (backlog the window skipped)

- **The entire go-live operational chain** (owner-gated): sops-paste `borg_repo`/`borg_known_hosts`, `ssh-keyscan -p 23` host-key pin, `enable = true` flip, first WAN seed, real-repo restore drill (= go-live checklist step 9), OnFailure delivery proof. StorageBox inputs row unchanged since 2026-09-22.
- **VM test for `platforms/nixos/system/backup.nix`** (TODO_LIST:62) — the only backup-producing module with zero VM coverage; runtime FAIL shapes (tripwire gating start on PLACEHOLDER env, §16 greps vs a booted unit) are proven nowhere.
- **EIO `/data` inode vs the first real borg run** (newly surfaced, 03-14 closeout §d2) — `/data` is a Borg source path, the known-bad inode (root 256, ino 1331118) is not excluded, and a borg read error exits non-zero → `.last_success` never lands → backup-coordination pages. Identify-path + repair-vs-exclude decision: not started; routed this pass.
- **Zone-6 `ioChurnUnits` membership for `borgbackup-job-hetzner`** (newly surfaced, §d3) — the nightly multi-hour read burst is invisible to the IO-storm guard's stop/re-arm list. Decision not started; routed this pass.
- **§16 enable-awareness fix** (newly surfaced, §d1) — not started; routed this pass (see d1 below).
- Storage-section queue rows the window never reached: rows 39-40 (shellcheck coverage proof, snapshot-pinning sweep), 44-51 (/data repair program, hot-db waves, boot-mirror reboot), 53-59 (batch deploy follow-through, buildcache fallback provisioning, restic proof chain, paperless DR completion, discordsync-attachments fixture), 65-70 (ClickHouse restore drill, help-slicer sweep, DR provenance line, third-copy decisions).

## d) TOTALLY FUCKED UP

Nothing repo-damaging landed in this window, and this run's verification sweep found no regressions. The honest ledger:

1. **The queue re-dispatch loop dominated the window.** 4 of the 5 dispatched task IDs were already closed when re-fired: task 1 (2nd dispatch), task 3 (3rd dispatch — three reports, one deliverable), task 4 (2nd), task 5 (3rd in 51 minutes). Seven full agent sessions produced zero code changes. The failure mode is triple-queued (TODO_LIST:197/200/291) but UNFIXED — this window is the strongest evidence yet: harvest should preflight `[x]` rows + footer commits + existing `docs/status/*_task-<ID>.md` reports before dispatch.
2. **The §13/§16 smoke lib shipped missing from the packaged gates** (`84f7ab33` extracted the lib but staged only metrics-gate.sh/pressure-report.sh into the wrappers) — every deploy would have died at the §13 source line until `eb2c6b3e` staged it. Caught by the first real gate run, but it shipped broken.
3. **Daemon-commit attribution erosion continued.** The window's work cores were repeatedly swept into heuristic commits before the footer commits landed: drill code → `d5a3321f`, fixture code → `860b63b9`, IO-tier core diff → `64fe390a`/`d7672c57`; the footer'd commits carry only queue-row ticks. The queue↔git cross-reference is weakened every time (queued rows 251/262/265/280 own the class).
4. **Latent defects surfaced and deliberately NOT fixed by the discoverers** (per no-drive-by-fix discipline — all three now routed):
   - **§16 phantom-SKIP** (`scripts/lib/offsite-borg-smoke.sh` `ob_post_deploy`): SKIPs "not deployed (enable = false)" whenever the unit file is absent WITHOUT reading the enable flag — on the go-live deploy itself, a botched activation green-SKIPs the exact block that gates go-live (same class §13 just fixed, other side of the deploy).
   - **EIO `/data` inode will likely fail the first REAL borg run** (read errors → non-zero exit → marker never lands → paging; partial seed).
   - **`borgbackup-job-hetzner` absent from Zone-6 `ioChurnUnits`** — unstopped multi-hour read burst during an IO storm.
5. **Standing fleet-gate breakage observed in passing:** `checks.disko-layout` fails eval intermittently (`disko-samsung-tlc-vm.nix.drv is not valid` — stale store drv), making full `nix flake check` runs unpredictable; the pre-commit flake-check gate is effectively dead for all agents until it lands (TODO_LIST:43, still open, red across multiple windows now).

## e) WHAT WE SHOULD IMPROVE (process and code)

1. **Verify-first re-dispatch protocol, codified:** before starting ANY queue task, `git log --all --grep=<Task-Queue-ID>` + `ls docs/status/ | grep <task-id-prefix>`; if found, the prior report is ground truth — verify deltas only, read it BEFORE planning (the 05:36 dispatch planned from scratch and re-ran two probes its sibling had already run).
2. **Concept-level grep before any backlog append** — exact-phrase grep misses reworded duplicates (a near-miss happened live in the 05:36 run; the queue's duplicate-row noise grows by exactly this mechanism).
3. **Real-stderr fixture branches for string-matched classifiers** (`ob_classify_eval_error` disabled shape; §13's jq key casing) — pin the true nix message shapes so version drift is caught at eval, not at deploy (queued, TODO_LIST:72).
4. **Wrapper↔lib parity flake check** — assert both packaged gates source `scripts/lib/offsite-borg-smoke.sh` (hash parity) so the extraction-miss class (d2 above) is structurally impossible. Queued this pass.
5. **Gate WARN baseline** — the pre-deploy gate carries ~36 standing warnings (26× "ExecStart binary not built yet", input-hygiene false-positives for bun inputs); a committed known-good set would make NEW warnings stand out; also classify substitutability-aware ones down to INFO.
6. **Assert what the smokes claim** — §13/§16 verify tripwire/marker/env wiring but not the `BORG_RSH` shape (`-p 23`, `StrictHostKeyChecking=yes`); one grep-assert each closes it. Queued this pass.
7. **Mountpoint-gate fixture reachability** — an env-var mountpoint override (like the existing `BORG_ENV_FILE` fixture hook) would let the fixture assert the flagship real-mode gate directly. Queued this pass (touches the hardened drill — smallest change).
8. **Keep the drift-probe habit for eval-cache-prone positive checks** — a green store path on a content-stable check proves nothing; the priority-49 throwaway probe is what gave the positive-render check its teeth (done twice this window; keep doing it after the shared-lib extraction, TODO_LIST:71).
9. **Daemon-sweep mitigation on task work:** the single-command pathspec-commit + immediate `git log -1` verify rule exists (AGENTS.md multi-agent discipline) — the window shows it is NOT being applied to task-work commits. Re-emphasize in CONTRIBUTING (queued rows 251/262 already cover; consider promoting to the queue-worker runbook, docs/services/tq.md).

## f) NEXT THINGS (impact-ordered; top items appended to TODO_LIST this pass)

1. **§16 enable-awareness fix** — pass the enable state into `ob_post_deploy`; enabled+absent unit = FAIL, disabled+absent = SKIP; extend the fixture. (d-fix, S)
2. **Locate the EIO `/data` inode's path (root 256, ino 1331118) and decide repair vs temporary Borg exclude BEFORE the offsite go-live flip.** (d-fix; locate = agentable, decision = owner; pairs with rows 44/45)
3. **StorageBox go-live inputs** (owner): hostname/username, recovery-copy policy, exclusion exceptions (storage.md:63 — unchanged, the standing blocker).
4. **Zone-6 `ioChurnUnits` decision** for `borgbackup-job-hetzner`: include-with-re-arm vs document-why-not. (decision, S)
5. **Offsite posture decision** (owner): append-only/restricted `authorized_keys` on the StorageBox repo (ransomware resistance) vs unrestricted key — changes go-live key provisioning + drill prerequisites; cheapest before the first seed.
6. **Host-key pin derivation decision** (owner): replacement-host `borg_known_hosts` re-pin via `ssh-keyscan` (TOFU) vs Hetzner-console-published fingerprint.
7. **BORG_RSH shape asserts** in §13 eval + §16 deployed-unit grep (`-p 23`, `StrictHostKeyChecking=yes`, `UserKnownHostsFile`). (S)
8. **Wrapper↔lib parity flake check** for `scripts/lib/offsite-borg-smoke.sh` in both packaged gates. (S)
9. **VM test for `backup.nix` before go-live** — tripwire fires on PLACEHOLDER, job shape, `.last_success`, fake borg on PATH (TODO_LIST:62). (M)
10. **Mountpoint-gate fixture hook** (env-var override) + assert the gate directly. (S)
11. **§11 input-hygiene ghost probe:** the hygiene step still probes `monitor365.goModules` though monitor365 left the packages surface 2026-09-15 — verify the probe list derives from the live lock. (S)
12. Real-stderr fixture branch for `ob_classify_eval_error` (TODO_LIST:72 — already queued).
13. Extract the positive-render guard into a shared pure lib fn so probes drive the REAL guard (TODO_LIST:71).
14. VM rehearsal of offsite-borg runtime FAIL shapes with mock sops (TODO_LIST:73).
15. Fixture-negative for the drill fixture: mutated drill copy must FAIL the fixture (TODO_LIST:42 / storage.md:110).
16. Fold the env-path-pin negative case into the drill fixture (TODO_LIST:41).
17. Fix `checks.disko-layout` stale-drv eval failure — the pre-commit flake-check gate is dead for all agents until this lands (TODO_LIST:43).
18. StorageBox quota monitoring leg (remote-side usage check) before the repo can silently hit the BX11 1 TB ceiling — post-go-live `[watch]`.
19. Day-2 freshness verification post-go-live: 06:30 job vs the 25h backup-coordination maxAge; `backup_ever_succeeded` MTIME gate distinguishes never-worked from stale.
20. OnFailure delivery proof post-go-live (synthetic unit failure → Discord + desktop legs; the Discord leg is wired but delivery is unproven until a real failure).
21. Post-first-real-run watch items: archive-vs-exclude audit vs the 27 excludes; irreplaceable-set size vs the ~800 G BX21 trigger; AGENTS.md DORMANT→live flip (storage.md:54).
22. Post-go-live prune-ladder verification (7d/4w/6m) + `borg compact` cadence decision after month one.
23. /data offsite-coverage interim posture: with `backups/{root,data}` excluded, /data's third copy is same-chassis-only until the inode repair — decide the interim stance (owner).
24. Document the DORMANT→go-live rollback (flip enable=false + redeploy mid-incident) in the runbook.
25. Verify the drill's `--verify-data` capability probe against the REAL borg 1.4.5 binary (guarded, unproven on the real binary).

## g) QUESTIONS (owner-only)

1. **Done-signal for verification-only re-dispatches:** the queue re-fired 4 closed task IDs 7 times in this window. What should terminate re-dispatch — harvest-time preflight against `[x]` rows + footer commits + existing `docs/status/*_task-<ID>.md` reports, or is a re-verification pass intentional policy? (TODO_LIST:200 asks the general form; rows 197/291 the preflight; this window is the concrete case.)
2. **Offsite repo posture:** should the StorageBox borg repo be hardened append-only (restricted `authorized_keys` command, ransomware resistance) accepting that restores then need an unrestricted key held offline? Cheapest to decide BEFORE the first seed — it changes the go-live runbook.
3. **EIO `/data` inode disposition:** repair-by-delete (it has failed nightly btrbk since 2026-08-18) vs temporary exclude from the Borg path set before the enable flip — and should the general repair recipe (TODO_LIST:44/45) simply absorb this, with borg go-live formally gated on it?

## h) BAND DRIFT (ADR-0015 accountability)

**None recorded.** `tq facts --type task.reprioritized` → 0 facts for the entire journal (re-checked this run); the window-era task session logs (`~/.local/state/tq/logs/000001a0c[d-f]*`, `000001a0d*`) contain no `task.reprioritized` mentions either. No priority moved in the window by marker, AI, unblock, or importance — the queue ordered the offsite-borg verification chain purely by harvest order, and the owner-input blockers (storage.md:63) stayed blocked throughout.

---

## Archival note (docs-health pass, this run)

Archived to `docs/status/archived/` (same-ID duplicate dispatch reports, superseded by the chain keepers, all with inline resolution banners): `2026-09-24_00-17_…d04c…` + `2026-09-24_00-24_…d04c…` (keeper `00-30`), `2026-09-24_00-52_…d067…` + `2026-09-24_00-56_…d067…` (keeper `01-05`), `2026-09-24_01-31_…d08c…` (keepers `01-27` + `01-39`). Kept in place: all five window closeouts (this report's §a cites them and new queue rows cite them as Sources), plus `01-27`, `05-05`, `02-22`, `04-02` (cited or canonical for their IDs).

## State at close

- TODO_LIST.md: 9 new rows appended (7 actionable + 2 owner-decision blocked rows), 0 existing rows edited.
- docs/todo/storage.md: 8 matching library entries appended; docs/todo/pipeline.md: 1 backfilled library entry (TODO_LIST:291 drift) + 1 new entry.
- docs/services/offsite-borg.md: §13/§16 gate-behavior note added (SKIP/FAIL semantics on the go-live deploy).
- CHANGELOG.md: 2026-09-24 offsite-borg gate/fixture batch entry added. ROADMAP.md: stale pre-go-live list updated (restore drill + deploy smokes now done).
- 5 duplicate-dispatch reports archived with resolution banners. Nothing pushed.
