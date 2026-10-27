# 2026-10-27 16:09 deploy-abort: float-proof root-cause and full unblock (fix session)

**Session start trigger:** user paste of `nix flake update && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` aborting at the float-register proof with `services.monitor365-server.compactionExtendedRetentionDays does not exist`, "I hate this shit, fix it once and for all".

**Owner arbitration (question tool, ~17:20):** push monitor365 now (vs wait for the live drain session) — chosen; extend float-register.sh RED path with unpushed-session hints — approved yes.

## a. Diagnosis

The proof error was the LAST link of a chain, not the disease:

1. The T05 drain session (live crush session in ~/projects/monitor365, executing `docs/planning/2026-10-27_14-20_SUPERB-backlog-drain-execution-plan.md`) landed `drain_filter` + `compactionRetentionDays` + `compactionExtendedRetentionDays` usage in SystemNix's `modules/nixos/services/monitor365.nix` while monitor365's master sat **16 commits unpushed** — the option definitions existed only locally.
2. SystemNix's auto-commit daemon committed the consumer side immediately; every evo-x2 eval was then red at ANY lock rev until upstream shipped.
3. The 16:09 `nix flake update` floated monitor365 to 9b98c94 (the pre-option remote tip). Proof red, registry reverted, deploy aborted — correct behavior, unhelpful error.
4. The drain session's own mitigation (an existence guard) was itself buggy: `options.services.monitor365-server.type.getSubOptions` throws — an options-tree NAMESPACE node has no `.type`. Working probe: `options ? services.monitor365-server && options.services.monitor365-server ? <option>` (they fixed this themselves in-session at ~17:27, racing my identical fix; I stood down per never-fight-a-live-session).

## b. Remediation (all verified)

| Surface | Fix | Evidence |
| --- | --- | --- |
| monitor365 upstream | Pushed master f0ad66cf4 (18 commits; pre-push hook first rejected a mid-edit `config.rs` unclosed delimiter — waited for the session's own fix, retried clean) | `git ls-remote` = f0ad66cf4→e92eb4927→b2809e024 |
| monitor365 preparedSrc FOD | Root cause: workspace dep `ssh-key-monitor = "0.4"` + lock regenerated against the local 0.4.1 checkout, but monitor365's flake pinned sibling tag **v0.4.0** → prepared tree resolved 0.4.0 vs lock 0.4.1 → `cargo check --locked` refused. Fix: tag pin bumped to v0.4.1 (monitor365 commit b2809e024, pushed) | FOD green in float-proof-20261027-185300.log (rc=0) |
| SystemNix lock | monitor365 floated to b2809e024; `nix flake update monitor365 --refresh` | flake.lock jq-verified |
| cv vendorHash (5th re-stale) | 5Xjd8Czb → N9Zsy7bb (modules/nixos/services/cv.nix) | first-hand got-hash, float-proof-20261027-172949.log |
| branching-flow vendorHash | r/LYNVd → iS5Z/XOU (lib/lars-packages.nix; upstream still ships sha256-AAAA placeholders at f28419e) | same log |
| mr-sync vendorHash (both surfaces) | TENDT6NZ → p4C0Ob7i (lib/lars-packages.nix + modules/nixos/services/mr-sync.nix) | same log |
| go-taskqueue vendorHash | upstream-baked 2zqvcUaJ re-staled → 7YE9PJMW added to BOTH surfaces (lib/lars-packages.nix `tq` + modules/nixos/services/tq-agent-pool.nix `tqPkg` — the service module builds its OWN package; the CLI shim alone did not cover the failing units) | same log, round-2 proof isolated tq as the last root |
| dms-shell go 1.27.3 floor | DankMaterialShell 5442f39 go.mod floors go ≥ 1.27.3; pinned nixpkgs fe13242 ships 1.27.2. Fix per owner's 2026-10-25 "always on latest" directive + the inboxclean precedent: `dankMaterialShell.inputs.nixpkgs.follows = "nixpkgs-unstable"` (flake.nix) — NOT a rev pin (pinning back would contradict the owner directive) | flake.nix comment; proof green |
| float-register.sh hardening (owner-approved) | (a) RED path prints unpushed-session hints (`unpushed_hints`: sibling checkout ahead of the floated rev = in-flight session); (b) RED-path revert rewrites the entry-snapshot rows instead of `git restore` (restore no-ops after the daemon sweeps unproven rows mid-proof — live: daemon commit bcaa65167 shipped unproven rows); (c) `--selftest` (4 fixture legs) wired as `checks.x86_64-linux.float-register-selftest`; shellcheck-clean | selftest PASS ×2; check attr evals |

## c. Verification state at report time (19:01)

- **Proof GREEN:** float-proof-20261027-185300.log `rc=0` (run by the parallel drain session at 18:53 against the daemon-committed fixed tree — the whole root set closed, monitor365 + dms-unstable + all four vendorHash FODs included).
- My own ceremony round (182857) had gone red on go-taskqueue only — expected: it evaluated before the tq-agent-pool fix; its other builds cached the green round.
- **NOT deployed:** `/run/current-system` == system-955 == 83klzcdb (mtime 07:14 this morning). The green toplevel sits unbuilt-into-profile; no `nh`/deploy process is running.
- **Registry commit gap:** the green ceremony's registry rows are STAGED but uncommitted (`git diff --cached` = flake/expected-locks.nix 2 rows) — its pathspec commit lost a race with the daemon (latest commits are heuristic batches, no `float: register` commit). The staged body is the green-proven one; a one-file pathspec commit formalizes it.

## d. Session discipline notes

- Mid-edit races honored throughout: monitor365.nix guard fixed by the live session seconds before my identical edit (stood down); flake.nix monitor365 sed swept by the daemon between edit and commit (pathspec commit landed the lock; verified).
- Two pushes executed under the owner's explicit push-now mandate: monitor365 master e92eb4927..b2809e024 (session work + my ssh-key-monitor tag bump). No other repos pushed; go-taskqueue/mr-sync fixes deliberately kept SystemNix-local (shim protocol) instead of upstream pastes.
- IO PSI ~43-70% throughout (the drain itself on sdb/sdc + a Rust release build); memory PSI ~0; guard cycling ~2/min at peak — no freeze occurred.

## e. Documentation landed this session

- docs/agents/nix-flakes.md: new bullet — consumer edits must never reference upstream options that exist only in unpushed local commits; namespace-vs-submodule option probing; the three float-register hardening changes.
- docs/services/monitor365.md: ship-path line updated with the push/float/guard-bug state.
- docs/todo/monitoring.md: `[watch]` row added — T09 drain disarm (tighten compaction 365/365 → defaults, delete drain_filter) after drain completion.

## f. Follow-ups (harvest state)

1. **Commit the staged green-proven registry rows + deploy gen-956** (`DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`; anchor discipline: wait for the full nh process tree, compare newest generation BY NUMBER, verify `readlink /run/current-system`; post-deploy checks; the 2026-10-25 quiescence heat-check applies — root-level lock files in the mtime sweep). NOT harvested into TODO_LIST: user-gated by this report's wait directive; it is the immediate next command, not backlog.
2. **T09 drain disarm** — harvested (docs/todo/monitoring.md watch row, this session).
3. **DMS unstable-follow flip-back** when the nixpkgs pin lifts past go 1.27.3 — deliberately not harvested as a todo row: the LIFT condition lives in the flake.nix comment at the follow site (same pattern as the hermes-agent pin), and docs/todo/pipeline.md is mid-edit by the parallel session.

## g. Open questions for the owner

1. Fire the deploy now (forced through the drain-driven IO storm, precedent set 3× today), or wait for a PSI quiet window first?
2. The un-quiesce decision (drain runbook: agent restart re-fires the 380M backlog drain; `max_events_per_day` cap unverified) — yours, unchanged from the runbook.
3. The staged registry rows lost their ceremony commit to a daemon race — commit them as-is (content green-proven), or re-run `scripts/float-register.sh` for a fresh no-drift instant pass and its audit-log commit?

## h. Addendum — resumption close-out (~19:55): DEPLOYED as system-956

All three open questions resolved or mooted by events:

1. **Registry rows (Q3 → moot):** the daemon committed the staged green-proven rows itself in `9961a58ea` (19:02:12, `flake/expected-locks.nix` 2-row diff riding the heuristic batch). Verified at resumption: HEAD registry monitor365=`b2809e024…`, dankMaterialShell=`853b3999…` — both match flake.lock exactly. Green-eval probe clean (toplevel drvPath `4mphv8g1…`).
2. **Deploy (Q1 → landed):** **system-956** active, `/run/current-system` = `vv4ckkahmq31aq7a312rx2d13r308nv1-nixos-system-evo-x2-26.11.20261015.fe13242`, **ANCHOR-OK** (profile system-956 == current-system, compared BY NUMBER per the 2026-10-23 procedure). Landed by a parallel session's deploy of the SAME quiescent tree (`6b1aa4c58`) after a three-actor lock race — the `/tmp/.systemnix-deploy.lock` discipline serialized every attempt, no interference:
   - Actor A (parallel, ~19:2x): died ~6 min into pre-deploy-check with 1 FAIL — a transient storm-flapped runtime probe (two consecutive clean reruns after: `109 passed, 14 warnings, 0 failed`, script AND app forms). Flap root cause not pinned; PSI avg10 39-48% at the time.
   - Actor B (mine, 19:41): refused politely (lock held).
   - Actor C (parallel, PID 89791, ~19:45): completed in ~22 min on the identical tree → system-956.
3. **Post-deploy (159 PASS / 4 FAIL / 10 WARN):** all 4 FAILs match the previous run's baseline (advisory exit): gitea-runner inactive, signoz traces_missing, nsfw-classifier 212% CPU, node-exporter journal rate — all predate this deploy. This arc's surfaces verified LIVE on 956: monitor365 API+UI 200 (localhost:3001), **agent metrics 9421 now RESPONDING** (dark pre-deploy — the floated generation brought it up), agent connected to server, server-watchdog timer active, CV `/health/live` (version 5165e44) + real-PDF compile + pipeline-store + browser render + proxy-path, tq dashboard + agent pool + `/mnt/pool/services/tq/tq.db`, `mr-sync.home.lan` 200, `tq.home.lan` 200, DMS wallpaper IPC.
4. **Un-quiesce (Q2 → STILL HELD, owner-gated):** the deploy did NOT restart `monitor365-agent.service` (zero unit transitions in the 40-min journal window — timestamp-scoped read, the sound form) — the drain-refire gate is untouched. The docs/todo/monitoring.md watch row owns it.
5. **Residue flagged:** `oc-e2-deploy7-sequencer.sh` (PID 2530517) is a zombie waiter — its Phase 1 polls `float-proof-20261027-172949.log` for an `rc=` line that will never arrive (that ceremony was killed mid-run by the daemon race); it sleeps harmlessly in 30s loops but would fire a deploy if anyone ever appended an rc line to that log. Owner may kill PID 2530517.
6. **Observed at close:** IO PSI avg10 spiked to 75% post-deploy (avg60 79%) — attribution not established here (drain on sdb/sdc is the parallel session's domain); memory PSI ~0, no freeze this arc.
