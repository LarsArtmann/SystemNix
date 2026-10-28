# Status Report: Deploy Fix → ~/projects Samsung Cutover LIVE (gen-957/958)

**Date:** 2026-10-28 18:50 CEST
**Session scope:** User prompt "fix deploy!!!!!!!!1" — the DEPLOY_FORCE_PRESSURE=1 deploy was blocked at §18 (shadow-split gate, by design: `data/projects` STRICT entry, subvol empty). This session executed Phase C (prepare), Phase D (cutover deploy), Phase E1 (finalize + first btrbk seed) of [the ratified plan](../planning/2026-10-28_projects-samsung-subvol-migration.md), plus every downstream domino the blocked deploy had been hiding.
**Result:** `/home/lars/projects` NOW LIVES ON THE SAMSUNG (`users/lars/projects`, fs-uuid-proven == `/mnt/hot`), mounted at the same path, zero gap writes, first pool receive landed, writer fleet restored, generation 958 anchored.

---

## a) FULLY DONE (verified, not claimed)

1. **§18 root cause confirmed as designed protection.** Phase B config had landed (commit a5a8f2c44, tombstone EXECUTING since 10:38); Phase C had never run. No prepare state dir, no live executor — the gate FAIL was the plan working.
2. **Storm unblocked.** The episodic IO storm behind the guard trips = `tq-agent-pool.service` (897G read + 796G write cumulative — the exact 937GB watch-row engine) sustaining the baseline, with the guard's own flm restore→cold-load→trip cycle on top. Pausing the pool (new `scripts/projects-cutover-quiesce.sh storm-stop`) ended the trips: none in the last 3+ h of the window (16:15 → past 19:00). Entry gate admitted at 17:16.
3. **Four hidden build failures fixed** (the user's battery never reached the toplevel build — §18 aborted first; the B9 prebuild caught them):
   - erraudit / kith-crm / cv vendorHash re-stales (the strand-flap class, ninth round) — shimmed with first-hand keep-going evidence (`~/.cache/lockfloat/toplevel-keepgoing-20261028-1655.log`).
   - `memory-emergency-guard-check` failing its own shellcheck gate (SC2013 ×2 in a parallel session's edit) — converted to while-read loops.
   - crush-daily master broken (daemon-committed `internal/report` tone import without the vendored package): walked back three revs to `f20d0ba` (last tone-free report.go), full float ceremony (lock + registry + green proof `float-proof-20261028-1755.log`).
4. **btrfs usage parser bug fixed** (`scripts/migrate-projects-subvol.sh`): our btrfs-progs emits `Device unallocated:` on an indented per-device line; the awk expected inline `Unallocated:` and refused a healthy 48 GiB filesystem as "0 B ENOSPC-precursor". Both forms parsed now; the refusal that cost one gate window is documented in the commit (43a5c1014).
5. **prepare (Phase C):** entry-gated (lock + PSI + trip-window + btrbk-ladder + space asserts all green), subvol created through `/mnt/hot`, double-pass throttled rsync 1,640,979 files / 136.9 GB literal (~7.5 min first pass), delta pass converged, parity **100.0%** (src=1,640,980 / dst=1,640,982 files; bytes equal to 5 significant digits), `git fsck` clean on the subvol SystemNix copy.
6. **cutover (Phase D):** full writer fleet stopped via the quiesce helper (pma/auto-commit, discovery, cv, nsfw, git-lag timer, crush-daily; pool already paused) → final delta prepare → `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` → **gen-957 switched and anchored** (readlink equality vs newest `system-N-link` by NUMBER). Mount answers `/dev/nvme0n1p2[/users/lars/projects]`, **UUID `ca83e15b…` == `/mnt/hot`** (universe proof; findmnt's device-node display is cosmetic). **Zero gap writes**: writers were stopped before the final delta, post-mount HEAD == last pre-delta commit, tree clean. `ls ~/projects | wc -l` = 341. fsck #2 (monitor365) clean.
7. **finalize (Phase E1):** mount + lars write probe OK; `btrbk-projects` seed finished 18:17:58 (14 min 37 s, 85.2 G read / 113.8 G written) — **first pool receive exists**.
8. **cv repaired.** cv@8243b2d (strand-float rev) dies parsing its own embedded defaults (`yaml: line 426` — half-committed defaults refactor; the fix `de9822178` sits UNPUSHED in the local checkout, config tests green there). Rolled the input back to `5165e44`, the gen-956-proven rev with its twice-proven modules hash (discordsync INTERIM-ROLLBACK precedent) → **gen-958 deployed and anchored**; cv listening on :8098, /health 200, CRM sync live.
9. **Post-deploy scanner false positive fixed** (`scripts/post-deploy-check.sh`): the projects-subvol universe check grepped findmnt's SOURCE for the `tlc` label; the kernel displays the resolved device node → fresh-mount false FAIL. Now compares fs UUID against `/mnt/hot` (commit e7338b5d9).
10. **Writer fleet fully restored** (pool drained its 45-min graceful stop — whisper-cli transcription finished — and restarted; all writers active).

## b) PARTIALLY DONE

1. **Phase E2/E3 (first nightly ladder + verify legs)** — pending tonight's 23:10 run; the first seed exists so per-prefix verify should find the receive. Freshness metric fresh=0 is EXPECTED until then (collector WARN by design).
2. **Post-deploy battery**: PASS 162 / FAIL 7, storm-mode active during both runs (avg60 26–32%). Residual FAILs at last probe: CV ×3 (mid-startup probes — cv WAS still syncing; live-verified listening+200 after settle), SigNoz traces_missing + Health Hub 503 (ride cv's restart; expect green now), §18 sanity CPU (tq pool 410% = normal multi-core agent work; nsfw 204% post-restart) + journal-rate (node-exporter 437/min, crm 2856/min startup catchup). **Re-run `nix run .#post-deploy-check` when the box is calm** to convert STORM-SUSPECTs and settle the baseline.
3. **D2 deviation (documented):** the plan's `--checksum` top-20 pass was not run — writers were stopped before the final delta, so standard rsync + parity bands + fsck carried the convergence guarantee; zero-divergence verified post-mount instead.

## c) NOT STARTED (pre-existing, noticed in passing — harvested, not touched)

- The 12 pre-battery failed units (inboxclean-sync, monitor365-pool-copy, home-lars-tmp automount, btrbk-forgejo + clean, ci-watchdog, home-manager-lars, paperless-exporter …) — pre-date this session.
- ~/tmp hot-user-caches half-provisioned WARN (subvol missing; the OTHER owner-gated migration, row 182/184 remainder).
- btrbk-forgejo stray receive target on the pool (13:40 failure, "btrbk clean" heal runbook).

## d) TOTALLY FUCKED UP (owned, same-session corrections)

1. **Two `-r` rg strikes** (`rg -rln`, `rg -rn`) — the hook caught both; grep/`rg -ln` used after. The display-mangling trap remains live for me.
2. **`git restore` no-op misread:** after the daemon committed my in-flight lock work, my restore "revert" silently restored FROM the daemon's commit (net no-op) — re-derived state from `git show --stat HEAD` before proceeding. No damage, but the command's direction (restore-from-HEAD vs revert-to-previous) deserved a second look before typing.
3. **Stale `.git/index.lock` (499 KB, from a daemon git killed mid-stage at 17:18)** blocked two commits; verified zero live git processes before trashing it. Watch for this after mount switches — the daemon's git dying mid-stage is a new failure shape worth a row if it repeats.
4. **crush-daily de-float took three attempts** (93697af → 43da017 → 6f22def → f20d0ba) because I chased the test-file red herring before reading the REAL build error (`undefined: tone` in report.go, present since 6f22def). The keep-going log was there the whole time; -S archaeology before log reading is the wrong order.

## e) WHAT WE SHOULD IMPROVE

1. **§11's FOD preview does not cover the service-binary go-modules FODs** (erraudit/kith-crm/cv/crush-daily all bypassed "4 FODs built clean" and died in the toplevel build). The B9 prebuild caught them — consider wiring `nix build toplevel --keep-going` into pre-deploy §11 or CI as the authoritative FOD net.
2. **The §18 CPU sanity check flags multi-core services by design** (tq pool at 410% is 4 busy cores, not a hotloop). Needs a per-service allowlist or a cgroup-relative threshold, else it cries wolf every deploy.
3. **crush-daily master is being daemon-committed into unbuildable states** (tone import without vendored dep). The daemon has no build gate; a pre-commit build hook for that repo (or vendoring automation) is the systemic fix.
4. **The strand floats keep landing broken revs** (cv 9 re-stales + one boot-broken rev; crush-daily broken master). The float proof is eval-only — a toplevel BUILD proof before registering would have caught both.

## f) NEXT — harvested into TODO_LIST.md + docs/todo/storage.md (see rows; count 9)

1. [ready] Re-run post-deploy-check on a calm box; confirm CV/SigNoz/HealthHub green + STORM-SUSPECTs cleared.
2. [ready] Tonight 23:10: verify first btrbk-projects ladder run + per-prefix verify legs + freshness metric flips to 1.
3. [blocked:push] CV repo: push `de9822178` (defaults fix, tests green locally) → float cv forward past 5165e44 → drop the interim-rollback shim.
4. [blocked:push] crush-daily upstream: vendor `templ-components/utils/tone` (or drop the import) + push; then float past f20d0ba.
5. [decision] §18 sanity check redesign for multi-core services (tq pool false-flag class).
6. [watch] node-exporter journal rate 437/min — what is it logging? (pre-existing, baseline-tracked)
7. [blocked:user] ~/tmp hot-tier prepare (the half-provisioned WARN; serialize AFTER the projects soak, never concurrent).
8. [decision] wevisone-spike ruling (14G bare .venv, now ON the snapshotted subvol — strictly safer than before, ruling still open).
9. [watch] Phase F burn-in gates (≥7 days, ≥5 green sends) → shadow-cleanup + QLC reclaim expectation + plan marker `done`.

## g) QUESTIONS FOR THE OWNER

1. May sessions **push** the CV + crush-daily fix commits (both repos are yours; the no-push rule is blocking the clean forward-float path — the rollback shims are holding the line until then)?
2. The tq pool's 1.7 TB/boot QLC churn was the storm engine — now it walks the Samsung. Want a watch row confirming the QLC baseline actually drops over the next boot?

## h) BAND DRIFT — none recorded (no tq reprioritize facts in this window; this session ran outside the pool as an interactive fix).

---

**Phase F remains open** (burn-in → shadow-cleanup → close-out docs); the plan stays EXECUTING under this session's marker until then. Rollback ladder until shadow-cleanup: `umount /home/lars/projects` + reboot regresses to the QLC shadow (pre-cutover state; post-cutover writes live on the subvol only).
