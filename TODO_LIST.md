# SystemNix TODO — Dispatch Queue

**This file is the QUEUE**: every agent-actionable (`[ready]`) open item, one line each, linking into its domain library. The tq pool (`repos = "CV,SystemNix,go-taskqueue"`) harvests THIS file only — blocked, watch, decision and upstream-push items are deliberately NOT here, so agents stop being dispatched at work they are banned from doing (sudo, pushes, browser ceremonies).

**Routing rules** (docs-health HARVEST writes at append time — NEVER as dated sections; the 2026-09-19 split retired that growth pattern):

- actionable engineering → one line here + the full entry (ask + blocker + `**Source:**`) in the domain library
- blocked on sudo / browser / external console / owner hands → library only, `[blocked:user]`
- blocked on an upstream push/tag → library only, `[blocked:push]` (agents implement locally, never push)
- waits on a deploy or a time window → library only, `[blocked:deploy]` / `[watch]`
- owner question → library only, `[decision]`
- vague / long-term → `ROADMAP.md`

Done items are pruned to `CHANGELOG.md` at every pass — a `[x]` row must never persist here. Verification narratives go to the status report, never the item. Full contract: `AGENTS.md` → "TODO System".

## Queue

### storage

- [ ] **Phase 2: hot DBs off the QLC root** → [docs/todo/storage.md](docs/todo/storage.md) — BLOCKED: remaining work (pocket-id/postgres/discordsync migration waves + docker data-root) is owner sudo windows; fsync measurement, verdicts, entry snippets and runbook landed (storage.md + status report)
- [ ] **Pool + disk-domain quality (2026-08-28 review)** → [docs/todo/storage.md](docs/todo/storage.md) — RUN 2026-09-22 (task queue `000001a0c5fdb2dd3166a37c82d89dc5be6c`): cache-fallback sweep executed + converged (storage.md row marked done; HM symlinks for pnpm cache/state + cargo registry, deploy-gated). NOT finished: remaining [ready] library items — the VM-test rebuild is PSI-gated (io avg10 ~68% at session time, gate <20%) and the mountPoint-vs-HM-symlink eval guard is a later run — BLOCKED: PSI-gated item cannot run mid-storm; guard item left for queue pacing
- [x] **VM test for the restic-app-dumps module** → [docs/todo/storage.md](docs/todo/storage.md)
- [x] **Own-tools NVMe→pool migrations: discordsync + browser-history remain** → [docs/todo/storage.md](docs/todo/storage.md) — BLOCKED: config landed (discordsync attachmentsDir pool leg + browser-history dbBackup leg, eval-green 2026-09-22); the ~40 GB migration run needs one `nix run .#deploy` (2026-09-22 io storm refused the pressure gate)
- [x] ~~**Browser-history DB backup**~~ DONE (code) 2026-09-22 → [docs/todo/storage.md](docs/todo/storage.md) — `dbBackup.enable` leg landed (02:15 sqlite .backup, CAP_DAC_READ_SEARCH, 14d retention, registry row); first run deploy-gates with the migration item above
- [x] **Implement offsite Borg leg to Hetzner StorageBox** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-22 (implemented + eval-verified; dormant until the owner go-live inputs — runbook: docs/services/offsite-borg.md)
- [x] **ClickHouse backup before the next SigNoz upgrade** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-23 (code + eval-verified; first run deploy-gates) — native `BACKUP ALL EXCEPT DATABASES system,...` nightly 03:00 → `/mnt/pool/backups/clickhouse`, 3-run retention, backup-coordination + Gatus freshness; do NOT upgrade SigNoz before a backup dir exists post-deploy
- [x] **Pin the borg-restore-drill env path to the sops template (flake-wrap or eval-time literal assertion)** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-23: eval-time literal assertion in `backup.nix` (unconditional `mkMerge` branch — the in-`mkIf` placement was proven blind); drift probe-verified both directions; fixed the parallel rework commit's missing paren that broke every evo-x2 eval at HEAD (Source: docs/status/2026-09-23_09-30_task-000001a0cd068f79239e5320030b96d20ad4.md §f.10)
- [x] **disko config for the already-deferred reinstall** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-23: geometry spec + eval guard + VM rehearsal landed 2026-09-14 (T16/T17); this run closed the remaining T24 rescue-path decision one-pager (`docs/services/disko.md`: manual rescue rebuild default, nixos-anywhere deferred, destructive disko rescue-only on a blank by-id-verified Samsung, discovery trap stays closed). Eval-verified green.
- [x] **Implement offsite Borg leg restore path: runbook + first timed restore drill** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-23 (restore page docs/services/offsite-borg-restore.md + timed-drill script scripts/borg-restore-drill.sh; first drill executed against a local stand-in, PASS — real-repo drill rides go-live checklist step 9; BORG_RSH port-23 go-live fix included)
- [x] **Offsite Borg monitoring extras: `backup_ever_succeeded` integration, ioTier.background on the unit, pre/post-deploy smoke entries** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-23 (metric in the shared backup-coordination loop; ioTier.background via mkForce over nixpkgs idle; pre-deploy §13 + post-deploy §16 enable-gated smoke entries; eval-verified, first smoke exercise deploy-gates)
- [x] **Harden the offsite-borg restore drill: real-mode `/mnt/hot` mountpoint gate, FAIL records from the top, flake-pinned borg, deep-integrity mode** — **DONE 2026-09-24 (task queue):** all four + record retention in `scripts/borg-restore-drill.sh` — real mode gates on `mountpoint -q /mnt/hot` (unmounted Samsung ⇒ borg caches onto the ROOT fs, shadow-dir class; mirrors the job unit's `RequiresMountsFor`); record setup + tee moved BEFORE every env/mode check so early dies (root gate, PLACEHOLDER repo) leave records, with `die` appending `result : FAIL` + record path directly to the file (tee-race-proof); borg ALWAYS resolved from THIS flake's locked nixpkgs via `builtins.getFlake` (drill binary == job binary, version logged per record); `--verify-data` adds a timed deep-integrity phase — CORRECTION vs the source report: borg 1.x extract has NO `--verify-data` flag, but 1.x `--dry-run` already reads + hash/HMAC-checks + decompresses every chunk (help-text-verified on 1.4.5), so the phase probes for the borg2 flag and falls back to plain dry-run; records pruned to newest 100. Verified: `bash -n` green; selftest PASS ×2 (plain 497 ms, deep-integrity 947 ms); early-fail probes (non-root real-mode die, bogus `--local`) each left FAIL records with rc=1. Runbook + AGENTS.md drill blocks updated. → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-23_07-20_task-000001a0cc8af769f497a7204704871623f0.md §e.2-4/§f.2-5/16/18)
- [x] **Restore-runbook accuracy pass: stale-lock (`borg break-lock`) section, OnFailure Discord proof command, block-by-block env sweep, `borg mount` FUSE verify** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-24 (task queue): stale-lock section (remote lock, local `pgrep -af borg` safety check, `borg break-lock` recipe in both runbooks); delivery-proof block in offsite-borg.md ops + the missing Discord leg WIRED (`monitored = true` + "Offsite Borg Job Service" registry check on `system_service_state_failed`/`start_limit_hit` — the false "OnFailure → Discord" claim corrected, notify-failure@ is desktop-only); block-by-block env-sweep checklist table in the restore runbook (5 blocks, all MATCH `sops.nix`/`backup.nix`, RSH byte-identical); FUSE facts verified (`fusermount3` setuid wrapper present, `user_allow_other` commented out ⇒ `allow_other` hedge CONFIRMED with the enable recipe; interactive mount verify staged in the runbook — the agent sandbox EPERMs unprivileged mounts and blocks sudo). Eval-verified green. (Source: same report §f.8/13/17/29)
- [x] **Flake fixture test for `scripts/borg-restore-drill.sh` (PATH-stub borg)** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-24: `checks.x86_64-linux.borg-restore-drill-fixture` (forgejo-scripts-fixture pattern) — stubs `nix` AND `borg` (the drill resolves borg via `nix build --expr`, so both are needed) plus an `id` stub to fake root; covers root-gate die (+FAIL record persisted), bogus `--local`, repo-without-config, PLACEHOLDER tripwire via fixture `BORG_ENV_FILE`, secrets-missing die (mountpoint gate's direct predecessor — the gate itself is sandbox-unreachable behind the `/run/secrets` existence checks), happy-path `--local` PASS incl. record content, and `--verify-data` 1.x `--dry-run` fallback + `--archive` pin. Build-verified PASS. (Source: same report §f.6)
- [x] **Persist a fixture test for the offsite-borg pre/post-deploy smoke blocks (§13/§16, pass/fail/skip branches)** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-23_09-01_task-000001a0ccdd5cd962579627f522f4c4082d.md §b1) — DONE 2026-09-24 (task queue): the §13/§16 logic extracted VERBATIM (byte-verified: message + grep-pattern sets identical to the pre-extraction blocks) into `scripts/lib/offsite-borg-smoke.sh`, sourced by both gates; `scripts/test-offsite-borg-smoke.sh` runs 14 fixture branches through the SAME sourced code (pre: skip/pass/pass-pass-pass/three single-branch FAILs; post: skip, 4×PASS happy path with stub unit + executable tripwire + prom row, wrong-tripwire, non-executable tripwire, missing marker/env/prom FAIL, prom-without-row WARN) — `offsite-borg-smoke-selftest` flake check builds it against the sourced lib (metrics-gate pattern); real pre-deploy §13 + post-deploy §16 re-run green (both SKIP branches live). (Source: docs/status/2026-09-23_09-01_task-000001a0ccdd5cd962579627f522f4c4082d.md §b1)
- [x] **Fix pre-deploy §13 silent-skip: distinguish offsite-borg disabled from a transient eval error — fail loud on the latter** → [docs/todo/storage.md](docs/todo/storage.md) (Source: same report §d3) — DONE 2026-09-24 (task queue): §13 captures the eval's raw stderr instead of `|| echo ""`; `ob_classify_eval_error` (in the shared lib, fixture-tested) SKIPs ONLY the disabled shape (the mkIf-wrapped job's "does not provide attribute …borgbackup-job-hetzner.serviceConfig" eval error) and any other eval failure (daemon restart, config error, path-specificity guarded) FAILs LOUD with the raw error; fixture grew 14→18 branches (`offsite-borg-smoke-selftest` green). ADJACENT FIX (found on first real gate run): the §13/§16 lib was NEVER STAGED into the `nix run .#pre-deploy-check`/`post-deploy-check` wrappers (lib-extraction commit copied only metrics-gate.sh/pressure-report.sh) — every deploy died at the §13 source line "No such file or directory"; both wrappers now stage it. Verified: full packaged gate end-to-end green (§13 SKIP live via the real disabled eval), fail-loud branch exercised on the exact committed block with a stubbed daemon failure.
- [x] **Assert the offsite-borg IO tier in pre-deploy §13 + post-deploy §16 — the ioTier.background deliverable has no automated gate** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-24 (task queue): the shared lib (`scripts/lib/offsite-borg-smoke.sh`, sourced by both gates) grew the assert each gate runs: §13 jq-reads `IOSchedulingClass`/`IOSchedulingPriority` from the eval'd `borgbackup-job-hetzner.serviceConfig` (FAIL unless exactly best-effort/6 — absent AND nixpkgs' idle class both fail), §16 greps both directives in the deployed unit file; fixtures 18→21 branches incl. the idle-class mutation; positive-path render re-proven live (`extendModules enable=true` → `{"class":"best-effort","prio":6}`); full packaged pre-deploy + post-deploy gates re-run green (SKIP branches live), `offsite-borg-smoke-selftest` flake check green. (Source: docs/status/2026-09-23_10-05_task-000001a0ccdd5cd962579627f522f4c4082d.md §d4/§f1)
- [x] **Persist the offsite-borg positive-path render probe (eval-time flake check: BE/6 + tripwire/marker/borg-env on enable=true)** → [docs/todo/storage.md](docs/todo/storage.md) (Source: same report §f3) — DONE 2026-09-24 (task queue): `checks.x86_64-linux.offsite-borg-positive-render` in flake.nix — extendModules render of evo-x2 with `enable = mkOverride 50 true` (plain-value enable=false in configuration.nix forces ≤50) + deepSeq'd eval asserts on the job unit's rendered serviceConfig: `IOSchedulingClass == best-effort` + priority 6 (ioTier.background mkForce intact), tripwire ExecStartPre (`borg-offsite-golive-check`), `.last_success` marker ExecStartPost, and EnvironmentFile == `sops.templates."borg-env".path` (drift on either side fails). Fires on every flake check incl. `--no-build` (disko-samsung-tlc deepSeq pattern). Verified: check builds green; negative hand-probes — priority-49 idle override renders `idle` and the guard expression throws (`string '"idle"' is not equal to string '"best-effort"'`), priority ≥50 (mkDefault/plain/mkForce-tie) correctly leaves BE/6 untouched (mkForce IS priority 50)
- [x] **Document the nixpkgs override-shape change (inline overrides now need `content`, not `value`) + the plain-`enable=false` conflict class for probe authors** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: same report §f2) — DONE 2026-09-24 (task queue): landed as a gotcha bullet in AGENTS.md (Non-Obvious Gotchas → Nix & Nixpkgs, after the `nix eval …drvPath does NOT check NixOS assertions` bullet); both error shapes (`attribute 'content' missing` at `lib/modules.nix:1458`, `has conflicting definition values … Use lib.mkForce value or lib.mkDefault value`) re-verified live against the locked nixpkgs before writing; working recipe `lib.mkOverride 50 true` (mkForce IS mkOverride 50)
- [x] **Prove shellcheck covers `scripts/*.sh` in pre-commit** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-24 (task queue): leg proven sound (predates the borg drill; drill shellcheck-CLEAN at landing rev `f845d1e9`) + the REAL gap closed: 18 latent SC2034 warnings in 5 scripts (each would hard-fail the next commit touching the file — CI's error-level job never sees them); persisted proof `scripts/test-precommit-shellcheck.sh` + `precommit-shellcheck-leg-selftest` flake check, wired into CI trap-lint
- [x] **Snapshot-pinning doctrine sweep** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-25 (task queue): doctrine block in AGENTS.md BTRFS section (per-fs pin windows + live-size tree table + free-immediately contrast set) + jan.md jan-tree cleanup bullet; sizes/snapshot inventories probed live
- [x] **Fold the borg env-path-pin negative case into the borg-restore-drill fixture test (drifted `BORG_ENV_FILE` literal → `backup.nix` assertion must fire)** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-25 (task queue): eval-time negative case folded into `checks.x86_64-linux.borg-restore-drill-fixture` (deepSeq guards, fires on every flake check incl. `--no-build`) — control (real module passes in the harness), script drift (sed-drifted drill copy fed to a single-anchor copy of `backup.nix` → the REAL assertion fires naming the expected literal), and template-path override (forced `sops.templates."borg-env".path` → fires naming the override), all in a minimal nixosSystem co-importing the integration module (evo-x2's full assertions list is deliberately NOT forced — on the enabled shape it realizes the monitor365 prepared-source context). Both drift directions + the control hand-probed live per the eval-cache doctrine; fixture PASS line grew the `env-pin-drift` marker. (Source: 2026-09-23 env-path-pin close-out — negative probe hand-run once, ephemeral)
- [x] **Fixture-negative for `borg-restore-drill-fixture`: mutate a drill copy (e.g. drop the root gate) and assert the fixture FAILS** — proves the fixture exercises the real script, not a phantom (the repo's negative-test doctrine applied to behavioral script fixtures). → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-25 (task queue): fixture case 8 `mutation-negative` in `checks.x86_64-linux.borg-restore-drill-fixture` — a sed-neutered drill COPY (`[ "$(id -u)" -eq 0 ]` → `true`, anchor-drift-guarded so a no-op sed fails loudly) must invert case 1: rc 1 with the NEXT gate's env-file message PRESENT and the root-gate message ABSENT; PASS line grew the `mutation-negative` marker. Eval-time drift guards + behavioral case hand-verified live (sandbox down this boot: `/run/binfmt` missing — see pipeline row). (Source: docs/status/2026-09-24_01-27_task-000001a0d08c5ae1231c46d370f5b7d55560.md §f6)
- [ ] **Fix the pre-existing `checks.disko-layout` eval failure (`disko-samsung-tlc-vm.nix.drv is not valid`) — the pre-commit flake-check gate is dead for ALL agents until this lands** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-09-24_01-27_task-000001a0d08c5ae1231c46d370f5b7d55560.md §d1) — SECOND instance observed 2026-09-25: `treefmt.drv is not valid` at clean HEAD (proven pre-existing at the pre-change rev; enumerated 2026-09-25 via `--keep-going`: treefmt + hermes-source + disko `/run/binfmt` probe + evo-x2 assertions, 3 distinct shapes (see pipeline row); docs/status/2026-09-25_00-20_task-000001a0d56f35ccee2a991988d7c3a9ebd1.md §d3/b3) — UPDATE 2026-09-25 05:33: gate GREEN at clean HEAD (full `nix flake check --no-build` passes; `/run/binfmt` reappeared 05:32 — environmental heal, NO repo change, actor unknown). The gate deaths were environmental, not structural; keep open for post-reboot proof + the durable fix (stability row, TODO 109). — UPDATE 2026-09-25 06:40 (fix dispatch): gate re-verified GREEN at HEAD `97711fdd` (`nix flake check --no-build --keep-going` rc=0); root cause = the boot-tmpfiles ordering cycle (stability row below, TODO 109), NOT a repo defect; durable fixes landed in-tree `af87ce31` (bootstrap → `.mount` anchoring + `tests/test-hot-user-caches.nix` tmpfiles tripwire) + `d827f478` (`binfmt-sandbox-dir` belt) but are UNDEPLOYED (host on gen 797, old automount-anchored wiring) — BLOCKED: post-reboot proof needs an owner deploy of the landed fixes + a reboot; a gen-797 reboot re-manifests the cycle (re-check: `ls /run/binfmt && nix flake check --no-build`)
- [x] **Codify the single-victim /data repair recipe** → [docs/todo/storage.md](docs/todo/storage.md) — DONE 2026-09-25 (task queue): recipe codified in jan.md ("Single-victim /data repair recipe" section: same-fs trash → `dd` header re-verify on the trashed copy, unmasked → atomic doc sweep across every live surface in ONE commit); jan.md RESOLVED bullet + AGENTS.md corrupt-GGUF bullet cross-linked
- [ ] **Build the /data damage-set inventory** → [docs/todo/storage.md](docs/todo/storage.md) — the inventory CONSUMES the AGENTS.md snapshot-pinning doctrine table for its timeline (cites it, never duplicates it) (Source: 2026-09-25 sweep report §b4)
- [ ] **Cross-link the flm AGENTS bullet to the snapshot-pinning doctrine table (one-line symmetry with jan.md)** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-25_00-20_task-000001a0d56f35ccee2a991988d7c3a9ebd1.md §f2)
- [ ] **Refresh the doctrine table's `/data/docker` sizing via `docker system df` (docker group, no sudo)** → [docs/todo/storage.md](docs/todo/storage.md) (Source: same report §f4)
- [ ] **Reconcile the root `@` retention anomaly (12-day-old weekly vs `snapshot_preserve 3d 1w`) and restate the doctrine's root window** → [docs/todo/storage.md](docs/todo/storage.md) (Source: same report §g1/f7)
- [ ] **Drop unknown flags (the drill's borg2 `--help` probe) in the borg-restore-drill fixture's borg stub instead of extracting them as paths — the junk file lands in the invoking cwd, got daemon-committed twice, and breaks the push-protection hook repo-wide** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-25_03-01_task-000001a0d5f3f62584a64bc4cb7a6d1f8f83.md §b1 UPDATE)
- [ ] **Codify "status reports self-harvest §f at authoring time" in the AGENTS.md TODO-system section (one sentence)** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-09-25_00-39_task-000001a0d56f35ccee2a991988d7c3a9ebd1.md §f2)
- [ ] **Codify the re-dispatch verification protocol (footers+closure → live spot-check → §f sweep → footer-bearing landing) in docs/CONTRIBUTING.md** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: same report §f3)
- [ ] **Commit-msg hook leg: reject commit subjects >72 chars** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-09-25_02-20_task-000001a0d5af4c01977b1f874e6689edcaae.md §d1)
- [ ] **Classify tq verify failures before burning attempts (pre-existing/environmental → gate-dead holding state; deadline-timeout-with-progress at exit 0 → gate-slow retry with warm cache; only introduced failures count)** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-09-25_05-33_task-000001a0d68672297273301d23247ceeae6a.md §e2 + attempt-3 report)
- [ ] **Gate triage runbook paragraph in docs/CONTRIBUTING.md: verify failing across unrelated tasks → /run/binfmt → clean-HEAD flake check → nix-daemon restart → IO-pressure vs the 30-min verify budget → only then suspect the task** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-09-25_05-33_task-000001a0d68672297273301d23247ceeae6a.md §e4)
- [ ] **Heal-attribution breadcrumb convention: manual system heals (tmpfiles --create, nix-daemon restart, socket starts) leave one journaled line or state-file stamp so forensics can attribute recoveries** → [docs/todo/stability.md](docs/todo/stability.md) (Source: docs/status/2026-09-25_05-33_task-000001a0d68672297273301d23247ceeae6a.md §b2/§e5 — the 05:32 /run/binfmt heal's actor is unknown)
- [ ] **Dedupe the ffprobe-sweep rows in docs/todo/pixel6.md (same ask in the prioritized list AND the backlog)** → [docs/todo/pixel6.md](docs/todo/pixel6.md) (Source: third-dispatch self-review §d)
- [ ] **Crush-DB migration: baseline + follow-through** → [docs/todo/storage.md](docs/todo/storage.md)
- [ ] **Rebuild `hot-db` + `crush-hot-db` VM tests green on the current tree (quiet-IO window)** → [docs/todo/storage.md](docs/todo/storage.md)
- [ ] **Samsung 2nd boot disk (boot-mirror): activation + reboot pending (deploy landed 2026-09-19)** → [docs/todo/storage.md](docs/todo/storage.md)
- [ ] **T14 hot-db tier monitoring: mount-presence textfile metric (fail-closed) + Gatus checks for `/mnt/hot` + per-entry mounts** → [docs/todo/storage.md](docs/todo/storage.md)
- [ ] **`migrate-hot-db.sh` stub-fixture test BEFORE its first user migration window** → [docs/todo/storage.md](docs/todo/storage.md)
- [ ] **Update the Phase-2 plan doc's T-task table with completion status (T3/T4/T6/T7/T8 done; T5/T9-T15 pending)** → [docs/todo/storage.md](docs/todo/storage.md)

- [x] **Fire the pending batch deploy in the first calm-IO window (io avg10 <20%, no Zone-6 trip in 60 min)** → [docs/todo/storage.md](docs/todo/storage.md) — carries restic-app-dumps + paperless-db-backup + discordsync attachments leg + browser-history dbBackup + the 3 cache-fallback symlinks + hot-db shared-unit fix + scrub-mechanism fix + vendorHash wave + boot-mirror sync; expect the known exit-4 classes (cv-perms, db-heal, hot-user-caches), fix-forward (Source: docs/status/2026-09-22_05-55 window closeout §f.1)
- [ ] **buildcache-init must provision the new fallback targets (pnpm-cache, pnpm-state, cargo/registry)** → [docs/todo/storage.md](docs/todo/storage.md) — today only the mount-gated HM activation creates them; after a mount recovers via buildcache-usb-recovery the HM symlinks dangle ENOENT until the next deploy (Source: 2026-09-22 buildcache reap review-fix §c.4)
- [ ] **Single-source the env-less cache reap inventories (deploy.sh .cache loop + non-.cache loop + buildcache-usb-recovery step 2.5 + home.nix activation)** → [docs/todo/storage.md](docs/todo/storage.md) — 4 hand-kept name lists, no parity enforcement; the reviewer finding rode exactly this drift (Source: same report §c.3)
- [ ] **Restic repo post-deploy proof chain: first run + `restic check` + one-file restore smoke + dedup-ratio measurement + a post-deploy smoke block** → [docs/todo/storage.md](docs/todo/storage.md) — eval-green is the weakest signal for a backup pipeline; nothing has backed up yet (Source: 2026-09-22 restic task reports)
- [ ] **Paperless DR completion: pg_restore drill into a scratch cluster + dump-integrity gate (`pg_restore --list`) + dump-size/pool-growth note after the first 02:00 run** → [docs/todo/storage.md](docs/todo/storage.md) (Source: paperless PG-dump re-dispatch report §f)
- [ ] **Stub/fixture test for the destructive `discordsync-attachments-migrate` oneshot BEFORE the deploy that triggers it** → [docs/todo/storage.md](docs/todo/storage.md) — stop → rsync → checksum verify → rm -rf ~40 GB source → restart currently has zero automated coverage (Source: 2026-09-22 04-30 own-tools report; storage.md row 87)
- [ ] **Converge `~/.npm` (103M stale fallback) onto the buildcache + give `~/tmp/go-lint` (1.8G, live) a reclamation path** → [docs/todo/storage.md](docs/todo/storage.md) (Source: 2026-09-22 cache-sweep report §b/§f.3-4)
- [ ] **Deploy authority: queue-fired vs user-manual `nix run .#deploy`** → [docs/todo/storage.md](docs/todo/storage.md) — BLOCKED: every task since 2026-09-21 is runtime-zero behind this decision; asked unanswered by 3+ closeouts (restic, paperless re-dispatch, pool-quality runs)
- [ ] **Restic repo's offsite role: local dedup layer only vs THE offsite leg (replicated to Hetzner)** → [docs/todo/storage.md](docs/todo/storage.md) — BLOCKED: decides whether forgejo-subvol/github-voice-corpus/pixel6 join `paths` and how the Borg leg (2026-09-11 decision) interacts; owner owns the DR architecture
- [ ] **VM test for the offsite-borg module BEFORE go-live** → [docs/todo/storage.md](docs/todo/storage.md) — zero test coverage on `platforms/nixos/system/backup.nix` (every other backup-producing service has one): assert the go-live tripwire fires on the PLACEHOLDER repo, job shape (paths/prune/compression/06:30 Persistent), and the `.last_success` marker write; fake borg on PATH (Source: docs/status/2026-09-23_02-01 window closeout §b3, from task-…faaa9 §e1)
- [ ] **storage.md cache-sweep lineage annotations** → [docs/todo/storage.md](docs/todo/storage.md) — row 80 append "deploy.sh pre-switch reap leg completed by review fix `d60d598c`"; row 82 [watch] tickable (all three HM symlinks verified resolved 13:04 2026-09-22 post-deploy); TODO_LIST:21 parent note cites the fix (Source: docs/status/2026-09-23_02-01 §b5)
- [ ] **Offsite-borg go-live: should it gate on the recovery-copy policy? — BLOCKED: the Borg passphrase is a real random sops value; if host AND sops are lost the repo is dead — record a recovery copy (password manager/paper) as a hard go-live prerequisite, or go live and accept the window?** → [docs/todo/storage.md](docs/todo/storage.md)
- [ ] **ClickHouse native-BACKUP restore drill: script + runbook section (dir-mode backup → scratch cluster, prove signoz dbs recover)** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-23_04-00_task-000001a0cb25e96009674c891282a42ef057.md §f.4 + 14-55 window closeout §f.2)
- [ ] **Repo-wide sweep for hardcoded help-slicer ranges (`sed -n '2,<N>p'` over comment headers) in `scripts/` — same truncation class as the borg drill `--help` bug** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-23_10-49_task-000001a0cd068fb027be90286d1e88ac57b8.md §f.8)
- [ ] **Add the DR-runbook provenance checklist line to `docs/CONTRIBUTING.md` (derive "what the backup contains" from rendered-path × archive-path intersection; ban "rides in the archive" phrasing for sops/tmpfs state)** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-23_10-25_task-000001a0cd068f9098f0cc0f10671a06716e.md §f.15)
- [ ] **ClickHouse dump third-copy placement — BLOCKED: should `/mnt/pool/backups/clickhouse` (~3.7 GiB/run × 3) ride restic-app-dumps, the offsite Borg job, or stay pool-RAID1-only? Owner owns the BX11 1 TB budget and the 3-2-1 importance call** → [docs/todo/storage.md](docs/todo/storage.md)
- [ ] **Borg real-repo drill verify semantics — BLOCKED: compare extracted bytes against the LIVE evo-x2 files (current `cmp` design, same-host only) or against a manifest baked into the archive (proves the dead-host restore)? Shapes the drill before its first real run** → [docs/todo/storage.md](docs/todo/storage.md)
- [ ] **Borg passphrase recovery copy — BLOCKED: is it physically stored off-host (password manager/paper) and proven to decrypt? Host loss + sops loss without it = permanent data loss; nothing in the repo can verify owner-side state** → [docs/todo/storage.md](docs/todo/storage.md)
- [ ] **Extract the offsite-borg positive-render guard into a shared pure lib function (`(svc, envTemplate) → asserts`) consumed by the flake check — inline deepSeq guards cannot be negative-probed without tree edits (the 05:05 verification had to replicate the assert)** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-24_05-05_task-000001a0d13bb97f785bd705387c539b4235.md §b3)
- [ ] **Pin the pre-deploy §13 classifier's eval shapes in a committed fixture (disabled-shape error text + JSON key casing §13's jq reads) — a nix reword must fail at eval, not flip classification at the next deploy gate** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-24_05-05_task-000001a0d13bb97f785bd705387c539b4235.md §b2)
- [ ] **VM rehearsal of offsite-borg runtime FAIL shapes: enable with mock sops in a NixOS VM — tripwire gates start with the checklist pointer on PLACEHOLDER env; §16 grep patterns proven against a REAL booted unit file (eval asserts prove the render, not a booted unit)** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-24_05-05_task-000001a0d13bb97f785bd705387c539b4235.md §b1)
- [ ] **Fix §16's enable-blind SKIP: `ob_post_deploy` claims "not deployed (enable = false)" whenever the unit file is absent WITHOUT reading the enable flag — pass the enable state in; enabled+absent = FAIL, disabled+absent = SKIP; extend the fixture** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-24_03-14_task-000001a0d0d1f8b552f5e3c0ea6cab70a19e.md §d1)
- [ ] **Locate the EIO /data inode's PATH (root 256, ino 1331118) and decide repair vs temporary Borg exclude BEFORE the offsite go-live flip — a borg read error on it fails the first real run and starves `.last_success` (partial seed + paging)** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-24_03-14_task-000001a0d0d1f8b552f5e3c0ea6cab70a19e.md §d2)
- [ ] **Assert the BORG_RSH shape in pre-deploy §13 eval'd serviceConfig + post-deploy §16 deployed-unit grep (`-p 23`, `StrictHostKeyChecking=yes`, `UserKnownHostsFile`) — today only "EnvironmentFile contains borg-env" is checked** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-24_03-14_task-000001a0d0d1f8b552f5e3c0ea6cab70a19e.md §e.6/§f27)
- [ ] **Flake check asserting BOTH packaged deploy gates source `scripts/lib/offsite-borg-smoke.sh` (hash parity) — makes the §13/§16 lib-extraction-miss class (wrappers shipped without the lib, found on a live run) structurally impossible** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-24_03-14_task-000001a0d0d1f8b552f5e3c0ea6cab70a19e.md §e.5)
- [ ] **Make the drill's real-mode mountpoint gate fixture-reachable (env-var mountpoint override like the existing BORG_ENV_FILE hook) so the fixture asserts the gate itself, not its "direct predecessor" — touches the hardened drill, smallest change** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-24_01-39_task-000001a0d08c5ae1231c46d370f5b7d55560.md §b1/§f3)
- [ ] **borgbackup-job-hetzner in Zone-6 ioChurnUnits — BLOCKED: include-with-re-arm (nightly read burst stoppable during an IO storm) or document-why-not (06:30 slot + ioTier.background judged sufficient)? A multi-hour read burst can outlast a storm window either way** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-24_03-14_task-000001a0d0d1f8b552f5e3c0ea6cab70a19e.md §d3/§g3)
- [ ] **Offsite repo append-only posture — BLOCKED: harden the StorageBox borg repo with a restricted authorized_keys command (ransomware resistance), accepting restores then need an unrestricted key held offline? Changes go-live key provisioning + drill prerequisites; cheapest to decide BEFORE the first seed** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-24_05-36_task-000001a0d13bb97f785bd705387c539b4235.md §g2)
- [ ] **Replacement-host borg_known_hosts re-pin derivation — BLOCKED: ssh-keyscan output directly (TOFU against a brand-new host) or the fingerprint re-derived from the Hetzner console's published host key? The runbook's dead-host column currently says ssh-keyscan** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-23_15-12_task-000001a0cd86bbfaedbf87be3d95691fe9ee.md §g1)
- [ ] **Cross-link the single-victim /data repair recipe from the AGENTS.md BTRFS /data-damage context (one line near the snapshot-pinning doctrine)** → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-09-25_05-19_task-000001a0d68672297273301d23247ceeae6a.md §b1)

### stability

- [ ] **USB flap-counter metric + pre-deploy zombie-mount detector** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **ADR: zram-only swap decision** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **Scoped polkit rule: service restarts without interactive auth** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **Boot-time catch-up stampede control** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **Root-cause the 13:36:13 `mnt-pool.mount` same-second SIGTERM** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **Evaluate systemd `Upholds=` as the declarative auto-restart for mount-dependent services** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **Zone 6 alert fatigue** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **Automated post-hard-reset check** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **Wire `io-psi-forensics` into deploy.sh's IO-pressure-gate block** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **sev1-bridge emitter for booted≠newest** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **journald `SystemMaxUse` cap (7.7G on the QLC root, proven ENOSPC-silence failure mode)** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **Guard VM-test extensions** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **Guard/crash-forensics follow-ups (crash2 + freeze-3 reviews)** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **pool-recovery residual wiring** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **Root-cause idle-disk/no-D-state IO PSI accounting (pressure gate's corpse heuristic is stale)** → [docs/todo/stability.md](docs/todo/stability.md)
- [ ] **Break the `hot-user-caches-nix-bootstrap` ↔ `systemd-tmpfiles-setup` boot ordering cycle (systemd deletes tmpfiles-setup from the boot transaction → NO boot tmpfiles rules → `/run/binfmt` missing → EVERY sandbox build fails `getting attributes of path "/run/binfmt"`, the root cause of the pipeline row's 2026-09-25 `treefmt.drv`/`disko-layout` "is not valid" instances) + add a tmpfiles-applied boot tripwire** → [docs/todo/stability.md](docs/todo/stability.md) (Source: docs/status/2026-09-25_02-00_task-000001a0d5af4c01977b1f874e6689edcaae.md §c)

### monitoring

- [ ] **Textfile-collector fixed-name `.tmp` audit (the niri EACCES class) + stale `btrfs-compression.prom.tmp` check** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **system-health-metrics worst-case section sum (≈500s) exceeds the 180s unit ceiling AND the 120s timer cadence — the collector structurally cannot finish under an IO storm** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **backup-catchup report script (`scripts/backup-catchup-report.sh`)** → [docs/todo/monitoring.md](docs/todo/monitoring.md) — the `backup_ever_succeeded` metric half landed 2026-09-23; remaining: stamps vs OnCalendar + prom diff + btrbk dry-run
- [ ] **btrbk receive-freshness + pool-snapshot-freshness monitoring** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Deferred-scrub observability + scrub-guard VM test** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Zero-series sweep automation + provisioner-Result assertion generalization + GOTRACEBACK=all sweep** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Extend the user-unit monitoring pattern to remaining blind spots** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Commit the dashboard generator + eval-time dashboard JSON lint** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Test-fire "Telemetry Export Failures" → Discord** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **SigNoz migrator-gap guard** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **`file_storage` cursor persistence for the journald receiver** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Caddy access.log ingestion (filelog receiver)** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **buildcache-gc observability** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Declarative health-check** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **System-health collector hardening** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Gatus lint residuals + synthetic ingest probe + smoke enable-gate sweep** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Consider gatus `alerting` dedup** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Persisted regression tests for the pool-smart collector script** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Enabled-but-inactive consumer detection net** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Gatus "I/O Stall Rate" permanently-red review** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Signoz-coverage/observability test+panel additions** → [docs/todo/monitoring.md](docs/todo/monitoring.md)
- [ ] **Pool-usage Gatus thresholds** → [docs/todo/monitoring.md](docs/todo/monitoring.md)

### ai-stack

- [ ] **Bisect the llama.cpp 0.3.0 mid-load CPU-spin upstream (ROCm runtime / kernel / GPU-state — upstream of llama.cpp) — THE gate for re-enabling llama-rag and unblocking the paperless RAG item** → [docs/todo/ai-stack.md](docs/todo/ai-stack.md)

### services

- [ ] **Paperless scheduled-task failure monitoring + encrypted-tag consistency alert** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Attic-class follow-ups from the exit-4 fix** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Docker image retention follow-through (post-rework)** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **mkDockerService hardening follow-ups** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Recreate remaining json-file Docker containers** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Investigate Pocket ID SQLITE_BUSY restart bursts** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Caddy reload root-cause fix** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Hermes periodic bump workflow** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Hermes: classify live `tools.registry` journal warnings** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Hermes build-time import smoke test** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Standardize Docker container hardening helper** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **SearXNG streaming exploration** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Migrate `dns-blocker.nix` to the upstream dnsblockd module** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **PMA: commit-failure + journald-staleness Gatus checks** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **hermes: verify ROCm env + runtime llama-server VRAM verify** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **dns-blocker: link the OIDC recovery runbook from the docs index** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **HaGeZi blocklist refresh workflow** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **postfix `status=bounced` journal-rate textfile metric + Gatus check** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Self-document the deliberately-red Turso Gatus check (runbook half done 2026-09-19)** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Root-cause the InboxClean→Paperless `gmail` tag demote PATCH rejection** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Miniflux runbook gate-proof block** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Miniflux VM test extension** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Add the mail-wiring PASS-since-2026-09-05 status to the paperless runbook monitoring map** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Paperless VM-test regression: assert the relay-gated email settings render into the unit file** → [docs/todo/services.md](docs/todo/services.md) — assertions landed 2026-09-22 (eval-verified); first green VM run PSI-gated
- [ ] **Paperless VM-test regression: assert paperless-db-backup timer/service + the backup-coordination paperless-db entry** → [docs/todo/services.md](docs/todo/services.md) — assertions landed 2026-09-22 (eval-verified); first green VM run PSI-gated
- [x] **VM test for the restic-app-dumps module** → [docs/todo/storage.md](docs/todo/storage.md) — written + eval-verified 2026-09-22; first green VM run PSI-gated
- [ ] **`projects-management-automation` Environment= splitting** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **project-discovery-daemon IO taming** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Hermes deferred-cleanups cluster (partly PAST DUE)** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **DNS-blocker h2 block-page coverage + ALPN gotcha** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Forgejo mirror monitoring depth** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Pocket ID regenerateSecretsFor guard** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Post-deploy smoke for the browser-history registration gate using the CSRF double-submit dance** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Gatus check on `browser_history_users`: alert on DECREASE or exceed of its pre-probe baseline** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **browser-history registration-surface audit: verify `/auth/import` is unreachable unauthenticated on the deployed vHost path + sweep cqrs-htmx for OTHER user-creation paths bypassing `registrationMu`** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **DiscordSync Immich cross-archive wiring: deploy + go-live chain (FOD wave → deploy → user API key → post-deploy verify)** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Health Hub: expose fetch-timeout/push-cadence as module options** → [docs/todo/services.md](docs/todo/services.md)
- [x] **Health Hub: add post-deploy smoke section to post-deploy-check.sh** → [docs/todo/services.md](docs/todo/services.md) — landed 2026-09-22 (enable-gated /healthz + /readyz + HTTPS vHost + AUTH_VHOSTS leg, shellcheck-green); goes live with the module's first deploy
- [ ] **Remove the self-neutralized `probeRegistrationCleanup` block (purge EXECUTED 2026-09-20 11:33:55, journal-verified) — BLOCKED: keep or rip the generic mechanism (option + script + fixture check) after the executed purge — reusable probe-cleanup pattern or YAGNI rip?** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Browser-history quiet-day 503 (agent freshness lapses when there is nothing to ingest): local Gatus-condition mitigation + upstream empty-batch heartbeat** → [docs/todo/services.md](docs/todo/services.md)
- [ ] **Fix jan.md Architecture-table GPU row: truncated verify command + unclosed backtick (the Verification section carries the full commands)** → [docs/todo/services.md](docs/todo/services.md) (Source: docs/status/2026-09-25_05-19_task-000001a0d68672297273301d23247ceeae6a.md §f3)

### upstream

- [ ] **browser-history gate-count gap: read-model `Count()` = 0 despite existing users (found live 2026-09-18)** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Upstream cqrs-htmx usermgmt: an ES-registered user was LOST across restarts (found live 2026-09-19)** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **PMA discovery daemon starvation — upstream root cause** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **PMA upstream: CI guard against go-commit pin regression (recurred 2026-09-07)** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Satellite GOEXPERIMENT sweep (21 repos)** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **go-nix-helpers: default `GOEXPERIMENT=jsonv2` in template/devShell** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Verify go-codec floor vs nixpkgs go (1.26.7)** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Hermes upstream: propose `projectsDir` RO-bind pattern for the NixOS module** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Pin go-cqrs-lite benchstat `rev = "master"`** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Switch root `go-cqrs-lite` flake input from `git+ssh://` to `github:`** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **DiscordSync: rebase the `nix/aa56b582-vendorhash` branch into master now that nixpkgs ships go 1.26.7** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **`aw-watcher-utilization` poetry-core migration** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **`valkey` / `aiocache` / `timm` / `xformers` broken tests** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **`taskwarrior3` build flags** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Kitty GC resilience patch** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Darwin user definition requirement** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **`jscpd` lockfile** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **PMA daemon: stop committing broken flake.lock** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Kernovia: reconcile `pkg/eventsourcing/shared` with TypeSpec-generated types** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **BuildFlow: root-cause the flake.lock flip-flopper** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **InboxClean upstream: `/health` should validate refresh tokens (not presence) + `invalid_grant` should surface a re-auth action** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **paperless-ngx upstream: empty-vocabulary classifier training should degrade, not FAIL the task** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Migrate `overview` + `project-dependency-graph` off the removed `project-discovery-sdk/daemon` module** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **BuildFlow: materialize the pre-commit hook on evo-x2** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **picoclaw: triage the latent test failures exposed by the sqlite v1.56 bump** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Overview upstream: retry discovery** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Queue: done-filter / same-ID idempotency short-circuit** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Upstream InboxClean: `/health` phantom-green** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Fix the website repo's `builtAt` stamping (larsartmann.com serves the 1980-01-01 placeholder sent…** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Repo-generic CI do-analyzer across all LarsArtmann Go repos** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **go-taskqueue: queue-level work-claiming/dedup** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **go-taskqueue: visibility surface for the citation check (journal fact or harvest counter)** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Queue intake freshness rule: items asserting live system state ("X is re-enabled and ACTIVE") get a mandatory reconcile-against-the-relevant-AGENTS.md-section step before execution** → [docs/todo/upstream.md](docs/todo/upstream.md)
- [ ] **Queue done-signal semantics — BLOCKED: what does the queue actually consume to mark a task done, and is the re-dispatch loop intended to terminate on something agents cannot see from inside the repo? (8 repeat dispatches past closure/blocking in the 2026-09-19 window)** → [docs/todo/upstream.md](docs/todo/upstream.md)

### security

- [ ] **Create `docs/security/rotations.md` rotation ledger** → [docs/todo/security.md](docs/todo/security.md)
- [ ] **ROOT: settle the `/run/secrets/sops-nix-age-key` ghost** → [docs/todo/security.md](docs/todo/security.md)
- [ ] **Crush key-hygiene leftovers** → [docs/todo/security.md](docs/todo/security.md)

### pipeline

- [ ] **Pre-deploy batch build of mkLarsPackages + cv + hermes inputs** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Known-outage classification in post-deploy-check** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Eval-time audits for unit-shape contracts (the cv-226 class)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Surprise bulk `nix flake update` validation gate** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Structural §10 fix: URL-aware phantom-metric extraction** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **§11 vendorHash freshness: wire real FOD dry-run checks** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Service-completeness manifest audit (eval-time or CI): every enabled service ⇒ Gatus check + dashboard tile (PapDashboard services.json) + backup registration + docs page** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Pre-commit nix-eval gate for `*.nix` (daemon broken-intermediate class)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **crush-config phase 2: serve AGENTS.md + references from the module, retire the local `~/.config/crush` dotfiles git repo** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **deploy.sh: lock-wait on activation contention** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Flake-check guard: HTML `pat()` needles must start with `<`** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Derive AUTH_VHOSTS from caddy.nix (or eval-time assert)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Centralize curl in `scripts/lib.sh` `fetch()` helper** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **User-env single-source enforcement: profile-emptiness + `~/go/bin` shadow-detector checks** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **deploy-queue systemd user unit (queued deploys survive sessions)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **deploy.sh pressure gate: re-measure immediately pre-switch (rebound race)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **golines → base.nix, emptying `~/go/bin` entirely** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Prune the stale `flake: false` `go-health-dashboard` lock node (input resolving as `_4`)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Investigate + gate the unformatted-commit path (geometrikks.nix + 3 scripts landed pre-`nix fmt`)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **File the daemon-beat-precommit-hook incident into the fleet lessons** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **deploy wrapper: refuse early with a clear message in agent sandboxes (no sudo)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Identify residual post-deploy WARNs** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Extend audit-textfile-tmp class B to .sh + .md surfaces (borg drill escaped the scan)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **post-deploy-check: poll browser-history /health + drop deploy.sh explicit restart** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Extend mkOidcGate with optional diagnostic output** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Post-deploy-check failure semantics + escalation** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **VM tests for the 2026-08-14 Gatus patterns** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Verify vendorHash pre-deploy check patterns at runtime** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Add `--force` flag to deploy.sh for phantom metrics** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Refactor discordsync to use a shared HTTP gate helper** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Retire stale ZFS-VM scripts/workflow remnants** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **sops manifest check-mode in pre-deploy-check** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **deploy-window journal anchoring + retry/backoff on external HTTP checks** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Add 3 gotcha entries from the fastflowlm 203-fix session** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Annotate appendix-only ARCHIVED reports** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **AGENTS.md compression session** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Second-pass annotation of the PARTIALLY-annotated August reports (~30 files in docs/status/ still carrying unstruck items)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Triage `docs/planning/` remaining UNDATED files (3; the dated 2026-05→09 sweep completed 2026-09-21: 21 archived, 1 OPEN kept, 7 REFERENCE kept)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **gotchas-archive narratives missing** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Verify docs/CONTRIBUTING + docs/DOMAIN_LANGUAGE freshness** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Deploy.sh backup retention** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Auto-commit daemon vs queue-task commit race: adopt single-command pathspec commit + immediate `git log -1` verify (or a daemon-side skip for active-task files)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **AGENTS DORMANT/DISABLED banner sweep + confirmation-wording convention** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Sanctioned read-only host-state probe for agent sessions** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **AGENTS.md size diet: split per-service runbooks fully into `docs/services/` with 3-line pointers** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Fresh uncached `checks.x86_64-linux.hermes` VM run** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Verify-before-harvest rule in docs-health HARVEST** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Harvest resolution-grep** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Pre-commit fast path for docs-only diffs** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Audit recent `--no-verify` commits for skipped-guard exposure** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Human-capability tag at task enqueue** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Task-queue dispatcher guard: grep newer status docs before dispatching trace items** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Document the amend-on-daemon-race repair as the standard queue-worker commit procedure** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **tq runbook: minimum verification gate for no-code-change closures** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Task reports: "verified live this pass: yes/no" column per item** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Queue-footer discipline: each run's FIRST commit carries its Task-Queue-ID footer** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Sweep remaining TODO rows phrased "red on every deploy"/"red since DATE" for unverified premises** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Reword smoke FAIL strings to name the probed artifact** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Eval-time assertion: every smoke-grep target path in post-deploy-check.sh exists in the deployed closure shape** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Consolidate `docs/status/archived/` (571 files, Jan-2026 era) into `docs/status/archived/`** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Document agent-safe verification patterns in docs/CONTRIBUTING.md** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **`stdenv.isDarwin`/`isLinux` deprecation-warning sweep** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **flake.lock node-printer helper** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **`systemd-analyze verify` sweep over ALL unit files** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **deploy.sh generic "stopped-for-containment" post-switch stop-list** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Eval-guard follow-ups (from the 17-49 session's P0/P1)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **AGENTS prevention-table sweep** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Stop flm/guard `/tmp/z6*` probe leftovers** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **tmp-cleanup prevention depth** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Eval-guard additions (extends the 17-49 eval-guard row above)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Convention: DONE-stamped TODO items carry the completing task's Task-Queue-ID** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Closeout/task runs verify the footer commit landed before emitting TQ_RESULT** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Pre-commit: classify `path ... is not valid` eval failures as a loud WARN naming the repair command** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **docs/CONTRIBUTING.md convention: boot-scoped vs window-scoped journal assertions** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Nix `--json` deprecation sweep over scripts/ + docs call sites** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Encode the repeat-dispatch report policy for verification-only queue repeats (annotate-only vs full report) — BLOCKED: which convention should be encoded — full report per dispatch, or TODO/library annotation only with reports reserved for state changes?** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Formatter-exclusion regression guard (flake check asserting `docs/**/*.html` in the effective treefmt excludes)** → [docs/todo/pipeline.md](docs/todo/pipeline.md)

- [x] **Negative-test the pre-commit GOTOOLCHAIN guard (pin the interactive-fish FP + both violation shapes)** → [docs/todo/pipeline.md](docs/todo/pipeline.md) — DONE 2026-09-22 (`scripts/test-gotoolchain-guard.sh`, extracts the live predicate from the hook and pins the boundary; review-fix found the narrowed predicate had dropped the unquoted/spaced nix shape — also restored)
- [ ] **`scripts/verify-status-citations.sh`: verify every bare SHA cited in docs/status/*.md against its actual diff (+ CI WARN); add the post-edit verification gate (`git log -1 -- <file>`) to the docs-health contract** → [docs/todo/pipeline.md](docs/todo/pipeline.md) — two false docs claims in 24h (the corpus-sweep "fixed" claim + the 05-07 closeout's AGENTS-buildcache claim that never landed) (Source: review-fix task 000001a0c10023cd §f.3 + 05-55 closeout §d.1)
- [ ] **Re-splice the formatter-inflated disk-layout HTML (`docs/planning/2026-09-20_15-17_disk-layout-current-and-target.html` measures 7.9 MB vs the ~3.6 MB compact bundle) and verify with `bash scripts/verify-html-diagrams.sh`** → [docs/todo/pipeline.md](docs/todo/pipeline.md) — third occurrence of the 2026-09-20 class, re-landed in daemon commit 9cce5bfd and still live on the tree (Source: 05-55 closeout §d.5)
- [ ] **Queue dedup preflight so closeout/review-fix dispatches stop re-firing on already-closed work (3+ same-day duplicates on 09-21/22 incl. a second five-task closeout)** → [docs/todo/pipeline.md](docs/todo/pipeline.md) — BLOCKED: should the harvester preflight items against storage.md [x] rows / existing closeout filenames before dispatch, and was the duplicate closeout intentional? (owner owns the queue config)
- [ ] **Fix the statix finding in `modules/nixos/services/hot-user-caches.nix` (`device = cfg.device;` → `inherit (cfg) device;`)** → [docs/todo/pipeline.md](docs/todo/pipeline.md) — kills the CI main job at "Run statix linter" and silently skips EVERY later gate (deadnix, fmt, eval, trap-lints, ports, templ, nullglob, textfile, push-protection, serviceConfig-merge, the new GOTOOLCHAIN selftest, flake-input hygiene); red ≥6 pushes on 09-21 and still red 2026-09-23 02:00 (run 35799069755) (Source: docs/status/2026-09-23_02-01 §c1, from 06-48 report §d1)
- [ ] **Fix CI VM-test jobs: branching-flow git+ssh fetch fails (deploy key `NIX_DEPLOY_KEY_BRANCHING_FLOW` not loaded in the vm-tests job); audit CV + go-cqrs-lite keys for the same gap** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-09-23_02-01 §c1, from 06-48 §d1/§f19)
- [ ] **Single-source the GOTOOLCHAIN purity predicate: CI "Flake input hygiene" step (nix-check.yml:156) + orphan `scripts/check-flake-inputs.sh:37` still carry the bare `GOTOOLCHAIN.*auto` grep that false-positives home.nix's fish override — the exact class 744f3882 fixed in the hook; delete the orphan or make CI consume the hook/selftest extraction** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-09-23_02-01 §c2, from 06-48 §d2/d3)
- [ ] **Allowlist the secret-history scanner's own canaries** → [docs/todo/pipeline.md](docs/todo/pipeline.md) — CI `secret-history-scan` red on the historical `leak-canary.tmp.md` blob (6d07ec6ed15e) + the `sk-00000…` fixture shapes quoted in docs/status/2026-09-15_07-32; add a canary-marker allowlist or runtime-derived synthetic shapes (GH013 doctrine: no rule-matching literal ever tracked) (Source: docs/status/2026-09-23_02-01 §c1/§d4)
- [ ] **Eval-time audit: reject units whose Exec/script redirects into a secret-looking path (`*password*|*secret*|*token*`) without `UMask = "0077"` or an adjacent chmod** → [docs/todo/pipeline.md](docs/todo/pipeline.md) — converts the restic 0644 class into a flake-check failure; self-tested via negative-test-lints.sh (Source: 07-40 restic report §c4/§f7)
- [ ] **CI-awareness tripwire: page when `nix-check.yml` has ≥3 consecutive red pushes** → [docs/todo/pipeline.md](docs/todo/pipeline.md) — master CI dark ≥2 days across three stacked failures, a deploy was forced through two red gates, nothing alerted (Source: docs/status/2026-09-23_02-01 §d1/§e1)
- [ ] **Regression test for BOTH env-less cache reap sites (deploy.sh pre-switch + usb-recovery step 2.5)** → [docs/todo/pipeline.md](docs/todo/pipeline.md) — temp-home fixtures: real-dir reaped, symlink kept, absent no-op; extract the loops into shell functions first for testability (Source: 06-21 report §f3)
- [ ] **End-to-end staged-file drill for the GOTOOLCHAIN guard block (stage a violating fixture, hook exits 1, unstage — daemon-race-safe)** → [docs/todo/pipeline.md](docs/todo/pipeline.md) — closes "patterns proven, plumbing unexercised" (Source: 06-48 §b1/§f6)
- [ ] **Is GitHub CI on SystemNix live signal or known-dark? — BLOCKED: master red ≥2 days across three stacked failures (statix, VM ssh fetch, secret-scan canaries), a deploy was forced through two red gates, nothing paged — if signal: dispatch the statix + VM-key fixes immediately and want the consecutive-red tripwire; if known-dark: which failure class convinced you, and should the workflows pause instead of failing on every push?** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **GOTOOLCHAIN `off` exclusion: dead relic or supported escape hatch? — BLOCKED: no tree line has used an off marker in months (selftest pins a synthetic shape) — if dead, three greps lose an exclusion; if alive, it needs a sanctioned line shape + live fixture** → [docs/todo/pipeline.md](docs/todo/pipeline.md)
- [ ] **Eval-Time Guards doctrine note in docs/CONTRIBUTING.md: inline deepSeq guards (offsite-borg-positive-render, disko-samsung-tlc) are only negative-probeable via replicated asserts; shared-lib guards are directly probe-drivable — guards should document which pattern they use** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-09-24_05-05_task-000001a0d13bb97f785bd705387c539b4235.md §e4)
- [ ] **§11 input-hygiene ghost probe: monitor365 was removed from the flake packages surface 2026-09-15 yet the hygiene check still probes `monitor365.goModules` — verify the probe list derives from the live lock, not a stale hand list** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-09-24_03-14_task-000001a0d0d1f8b552f5e3c0ea6cab70a19e.md §f38)
- [ ] **Codify the daemon-race policy for task-queue agents (unanswered 2026-09-12 g-2, hit again 2026-09-25): amend the verified-single-file daemon HEAD vs land a separate footer-bearing commit on top — pick one, write it down, and carve out the docs' "ONE commit" rules accordingly** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-09-25_05-19_task-000001a0d68672297273301d23247ceeae6a.md §d1)

### pixel6

- [ ] **Udev rule for Google USB vendor 18d1 (adb access)** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Enrich `universal-call-recorder/index.csv` with call-log contact names** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **SHA256SUMS for Signal + WhatsApp + Cube ACR sets** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Full ffprobe sweep over all 591 UCR WAVs** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Add `backups/pixel6` to btrbk-pool snapshot set + backup-coordination freshness** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Recover `/tmp/pixel6-*.sh` transfer scripts into `scripts/`** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **WAV→FLAC mirror of UCR archive** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Navidrome audio-archive server (DECIDED over Jellyfin)** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Whisper transcription batch (GPU) over the 591 calls** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Call analytics + prefix decode** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Immich ingestion of DCIM + WhatsApp media** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Human-friendly renamed mirror tree** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Pool README day-2 update** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Full ffprobe sweep over all 591 UCR WAVs** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **WAV→FLAC/opus mirror + browsable web archive (player/search) over the UCR call archive** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **Contacts VCF export to the pool + per-contact card decode** → [docs/todo/pixel6.md](docs/todo/pixel6.md)
- [ ] **RAG query CLI over the archive** → [docs/todo/pixel6.md](docs/todo/pixel6.md)

## Libraries

| Library                                            | Owns                                                                                                     |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| [docs/todo/storage.md](docs/todo/storage.md)       | BTRFS, btrbk + pool backups, /data repair, Samsung hot-DB tier, buildcache, offsite Borg, ClickHouse XFS |
| [docs/todo/stability.md](docs/todo/stability.md)   | freezes, memory-guard + sev1, PSI/IO storms, boot resilience, journald/oomd, USB/NIC hardware            |
| [docs/todo/monitoring.md](docs/todo/monitoring.md) | Gatus, SigNoz, textfile collectors, system-health, alert routing (cross-service)                         |
| [docs/todo/ai-stack.md](docs/todo/ai-stack.md)     | FastFlowLM, llama-rag/llama.cpp, ollama, GPU/ROCm, RAG consumers, whisper                                |
| [docs/todo/services.md](docs/todo/services.md)     | per-service debt + go-lives (paperless, hermes, forgejo, miniflux, …)                                    |
| [docs/todo/upstream.md](docs/todo/upstream.md)     | LarsArtmann Go-ecosystem chains, nixpkgs/HM/third-party contributions, go-taskqueue                      |
| [docs/todo/security.md](docs/todo/security.md)     | key rotation, secrets/sops, gitleaks policy, leak residues                                               |
| [docs/todo/pipeline.md](docs/todo/pipeline.md)     | deploy.sh, pre/post-deploy checks, flake checks + eval audits, CI, repo/docs hygiene, queue conventions  |
| [docs/todo/desktop.md](docs/todo/desktop.md)       | niri, DMS/Quickshell, Qt, audio, shell UX, Signal                                                        |
| [docs/todo/pixel6.md](docs/todo/pixel6.md)         | Pixel 6 recovery → media-archive project                                                                 |

_Completed work: [CHANGELOG.md](./CHANGELOG.md). Long-term ideas: [ROADMAP.md](./ROADMAP.md)._
