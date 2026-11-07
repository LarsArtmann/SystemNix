# Offsite Borg go-live — auth FIXED via documented `install-ssh-key`; pre-seed audit catches the `.snapshots` trap; deploy still pressure-gated

**Authored:** 2026-11-04 06:25 CET · **Session window:** 2026-11-03 ~22:00 → 2026-11-04 06:25
**Trigger:** owner said go on the StorageBox go-live ("for dummies" checklist issued), pasted the r2 pubkey into the Hetzner console, then reset the box password; ordered READ/UNDERSTAND/RESEARCH/REFLECT execution, then this report.
**Tree:** clean at authoring (daemon commits; no repo config changes this session — all work products live in `~/.cache/borg-golive/`).

## Live state at authoring

| What | State |
| --- | --- |
| io PSI some avg10 | 79.4% (avg60 85.5%) — storm UNBROKEN since session open (04:46→05:06 watcher samples: 78–92%) |
| Deploy watcher | KILLED (job 032) at ~06:1x after the sizing audit turned the seed budget RED — never fired |
| Pool breakdown du (job 037) | STILL RUNNING (idle-class du under storm; no output yet) |
| Box (sftp `df -h`) | 1.0 TB total · **18.5 GB used** · 1006 GB free |
| Auth to box | **rc=0 key-only** (probe = `ls` over port 23, pinned known_hosts) |
| 06:30 borg timer | will NOT fire today — service not yet switched live (enable committed, deploy pending) |

## §a FULLY DONE

1. **Auth saga root-caused and closed.** Probe rc=255 `Permission denied (publickey,password)` after the owner's console paste → verbose probe proved the client offers the correct key (`SHA256:PDrUYQYYQ+c9eR4EUwBVyaE/Oy8IhRgCCzgH3nmLfp0`) and the server rejects it → local `ssh-keygen -y` proved the sops-held key is byte-identical to the pubkey the owner was given (our side provably correct) → 10-min retry loop ruled out activation delay. Docs research: `docs.hetzner.com` is a JS SPA (plain fetch empty ×2; archive.org chrome-only); **r.jina.ai reader proxy delivered the doc**. Root cause: **StorageBoxes keep two key stores — port 22 reads RFC4716 format, port 23 (borg) reads one-line OpenSSH; console pastes do not reach the port-23 store.** Documented fix executed: `cat pubkey | ssh -p23 u453585@… install-ssh-key` → "installed in RFC4716 format / installed in OpenSSH format", rc=0.
2. **Auth verified end-to-end:** probe remote command fixed from `true` (restricted shell: `Command not found`, rc=8) to `ls` → **AUTH rc=0** + box root listing: existing `borg-repository/`, `pihole/`, `pvc-0b0973b3…/`, `pvc-8c06f2b1…/` (not our target; our repo path is `backups/evo-x2`).
3. **Box quota measured** via key-only sftp `df -h` (harness `sftp-df.sh`): 18.5 GB used of 1.0 TB.
4. **Password security handling:** owner pasted the reset box password into the transcript — flagged immediately, never echoed; consumed once via write-tool 0600 file (never a command line / shell history / output), shredded in-run by `provision-key.sh`, **absence verified afterward** (`ls` of the harness dir). Rotation reminder issued (transcript exposure). sshpass obtained via `nix run nixpkgs#sshpass` (not installed locally).
5. **Job config re-verified in-tree** (`platforms/nixos/system/backup.nix:216-280`): repo placeholder + borg-env runtime override, `BORG_RSH` port-23 load-bearing comment, hot-tier cache dirs (`/mnt/hot/borg/{cache,config}`), prune 7d/4w/6m, `borg-offsite-dir` mount-gated bootstrap, ioTier BE/6.
6. **Pre-seed exclude audit (visible-dirs pass):** 5 unexcluded `/data` dirs sized (`gcs-staging` 24 G, docker ~15 G permission-blind, backups 5.8 M, var 80 M, containers 0) — and the du walk (§b) escalated the audit to RED (§d).
7. **Deploy watcher built, syntax-checked, armed, then killed** (`deploy-watcher.sh` + log): 6 h PSI polling, sustained <20% ×2 trigger, quiescence (no in-flight deploy, clean tree, no eval-relevant mtime <5 min) → green-eval probe → `nix run .#deploy` → anchor check. Killed before ever triggering.

## §b PARTIALLY DONE

1. **Backup-set sizing** — agent-readable legs done: `/etc` 1.2 M · `/home/lars` effective **104 G** (mapped: .local 34 G, .config 15 G, Downloads 2.4 G, Desktop 1.4 G, Documents 131 M…; **~51 G unmapped dotdirs**) · `/data` effective **13 T nominal** — dominated by **`/data/.snapshots` (NOT excluded — the trap, §d)**; live-tree remainder ≈ 39 G + `/data/ai` remainder **UNSIZED** (ai total 543 G; models/cache/venv excluded; the rest unknown) · `/mnt/pool/backups` effective **1.2 T** with hogs UNIDENTIFIED (breakdown job 037 still running) · immich **0** (whole dir root-only, blind) · paperless 11 M (media/documents blind). Root-owned legs need a sudo sizing pass — not yet run.
2. **Exclude triage designed, not landed:** `/data/.snapshots` must be excluded; home `.local/share/containers` (podman) and the pool hogs pending breakdowns. **No config edit made.**
3. **Deploy watcher:** exists and is correct, disarmed pending the config fix + eval green.
4. **gcs-staging:** rides the seed per committed config (safe default: include); owner word still pending.
5. **docs/services/offsite-borg.md step 3** is now PROVEN WRONG (console paste does not reach port 23) — correction designed (install-ssh-key + two-store lesson), not landed. **Harvested as a [ready] row** (see ledger).

## §c NOT STARTED

- Exclude config edit + module comment-count update + `nix flake check --no-build`
- Re-arm watcher; the deploy itself (PSI gate or owner "force" word)
- Anchor verification; §13 offsite-borg smoke first activation; §16 tile-icon gate
- Unit/timer verification (`borgbackup-job-hetzner`, 06:30 Persistent, `borg-offsite-dir`), `/run/secrets/{borg_password,borg_ssh_key,borg_known_hosts}` + rendered `borg-env` (no PLACEHOLDER)
- First seed run (busctl StartUnit, journal watch, TimeoutStartSec 2d), `.last_success` marker, `backup_healthy 1`, `backup_ever_succeeded 1`, Gatus green, full post-deploy battery
- `borg-restore-drill.sh` real mode + timings → `offsite-borg-restore.md`
- Docs flip to LIVE (offsite-borg.md header, docs/agents/storage.md, CHANGELOG); close `docs/todo/storage.md:58` go-live-inputs row + the two 2026-11-03 rows (pre-seed audit probe, dormant-gate eval-gap probe)
- StorageBox password rotation (owner act)

## §d TOTALLY FUCKED UP (all near-misses; nothing irreversible)

1. **Deploy automation armed BEFORE the pre-seed audit finished.** Had PSI drained between 04:00–06:10, the watcher would have deployed a job whose seed reads **13 T + 1.2 T** against a 1 TB box mid-storm (job would run for days/timeout, hammer IO). Saved by storm persistence + the later kill. Root cause: sequencing violation — automation armed on "config eval-green" while the seed-budget audit was still open. Fix in §e.1.
2. **First exclude reconcile missed `/data/.snapshots` entirely** — plain `ls /data` hides dotdirs; I declared "budget-safe ~40 G extra" on incomplete data. The du walk (launched for the budget question, not the audit!) caught it. An audit claim was published that a `ls -A` would have falsified in one command.
3. **The owner's borg-vs-BTRFS question was never answered in prose** — sizing.log was read and triage started, but the actual answer (chunk-level dedup, incremental-forever, per-archive point-in-time restores) was never delivered to the owner. Still owed (§f.1).
4. Minor: `borg_fp_key.pub` + `keyscan.err` left in the harness dir (public/noise, harmless); original auth probe used `true`, which the restricted shell lacks — cost one confusing rc=8 read before the probe was fixed to `ls`.

## §e WHAT TO IMPROVE

1. **Arm deploy automation only after the pre-seed audit is green** — make "seed-budget audit complete (incl. dotdirs + sudo legs)" an explicit runbook gate before any watcher/deploy trigger (encode into docs/services/offsite-borg.md go-live checklist).
2. **Exclude audits must walk, not list:** `ls -A` minimum, du-based reconcile, plus a sudo leg for root-owned trees; never publish "budget-safe" from visible dirs alone.
3. **Answer the asked question before acting on its adjacent findings** — triage can follow, but the answer comes first.
4. **Remote-shell probes must use commands the shell supports** (StorageBox restricted shell: `ls`, `help`, `df` via sftp; no `true`).
5. **r.jina.ai reader proxy is the working route for JS-SPA docs** (docs.hetzner.com returns empty to plain fetch) — record for future Hetzner doc needs.

## §f NEXT (ranked, ≤50 — 37 real items)

1. Answer the owner's borg-vs-BTRFS incremental question (prose; no research needed)
2. Read/kill job 037 → pool/backups hog identification
3. sudo sizing pass: immich, paperless/media, pool root-owned dirs (pocket-id, forgejo, geometrikks, clickhouse, restic-storage-history), `/data/docker` true size
4. Full `/home/lars` top-level du incl. dotdirs (find the ~51 G unmapped; break down .local 34 G — containers vs share)
5. Size `/data/ai` remainder (543 G total minus models/cache/venv)
6. Decide podman `.local/share/containers`: exclude image storage (overlay), keep volumes? or whole-dir exclude
7. **Land the exclude edit** in `platforms/nixos/system/backup.nix`: `/data/.snapshots` (mandatory) + decided others
8. Update the module's exclude-count comment (27 → actual) + docs table if changed
9. `nix flake check --no-build` (eval gate)
10. Correct `docs/services/offsite-borg.md` step 3 → install-ssh-key procedure + two-store lesson *(harvested, see ledger)*
11. Update `docs/services/offsite-borg.md` exclude runbook table with the audit's additions
12. Re-arm `deploy-watcher.sh` (only after 7+9 green)
13. PSI gate: wait for drain or owner "force"
14. Deploy (`nix run .#deploy`, quiescence protocol)
15. Anchor verify (`readlink /run/current-system` == newest `system-N-link` by NUMBER)
16. §13 offsite-borg smoke (first activation)
17. §16 tile-icon inventory gate
18. Verify units/timers via scripts (job unit, 06:30 Persistent timer, borg-offsite-dir)
19. Verify `/mnt/hot/borg/{cache,config}` exist post-activation
20. Verify sops renders (`/run/secrets/*`, `borg-env`, no PLACEHOLDER)
21. Start seed in a low-pressure window (busctl StartUnit); journal watch
22. Watch seed PSI impact (ioTier BE/6 expected to bound it)
23. Verify `.last_success` marker
24. Verify `backup_healthy{backup="offsite-borg"} 1` + `backup_ever_succeeded 1`
25. Gatus offsite-borg endpoint green
26. Full `post-deploy-check.sh` battery
27. `borg-restore-drill.sh` real mode + timings → `offsite-borg-restore.md`
28. Docs flip LIVE: offsite-borg.md header, docs/agents/storage.md, CHANGELOG
29. Close `docs/todo/storage.md:58` (go-live inputs row)
30. Close the 2026-11-03 rows: pre-seed audit probe (findings = this report §a.6/§b.1), dormant-gate eval-gap probe
31. Owner: StorageBox password rotation (post-go-live)
32. Owner: borg_password recovery-copy policy
33. Owner: gcs-staging + docker-residue include/exclude word
34. Owner: identify existing box contents (`borg-repository`, `pihole`, `pvc-*`) — keep/quota claims
35. Post-go-live: append-only RESTRICTED authorized_keys hardening revisit (storage.md [decision] row)
36. Post-go-live: DR known_hosts re-pin derivation decision (storage.md [decision] row)
37. Steady-state quota watch: 1006 GB free vs final set size + growth; re-check prune 7/4/6 at first prune cycle

## §g QUESTIONS FOR THE OWNER (cannot self-answer)

1. **Existing box contents** — `borg-repository/`, `pihole/`, `pvc-0b0973b3…/`, `pvc-8c06f2b1…/` (18.5 GB total): yours? keep? Any of them a standing quota claim against the borg budget?
2. **Include/exclude word for the maybes** — `gcs-staging` (24 G, finished one-off staging) and the dormant `/data/docker` residue (~15 G): include in the offsite seed (current default) or exclude to save the budget?
3. **borg_password recovery copy** — password manager, printed, or split? (If host AND sops are lost without a copy, the offsite repo is cryptographically dead — the answer gates true 3-2-1 completeness, not the deploy.)

## Harvest ledger (TODO-system discipline)

- **NEW row harvested:** offsite-borg.md step-3 correction (install-ssh-key + two-store lesson) → `docs/todo/storage.md` [ready] + `TODO_LIST.md` twin (this session authored both).
- **Updated row:** `docs/todo/storage.md:58` go-live-inputs row — pubkey-paste leg marked ✅ 2026-11-04 (install-ssh-key, auth rc=0); blockers now: recovery-copy policy, gcs-staging/exceptions word, exclude-fix, deploy.
- **Mapped to EXISTING rows, not re-harvested:** deploy/verify/seed/drill/docs-flip items = scope of the storage.md:58 row + go-live checklist (docs/services/offsite-borg.md); sudo-sizing + pool hogs = the 2026-11-03 "pre-seed exclude-vs-live-tree audit probe" row (still open, §b.1 extends it); append-only + known_hosts = standing [decision] rows.
- **Deliberately NOT harvested:** watcher re-arm (session-scoped orchestration, not durable work), §f.1 prose answer (conversational debt, no repo artifact), harness tidy-up (§e.5, one-off).

*Auth leg complete and verified; seed budget audit RED and blocking the deploy by design — the trap it caught is the reason the audit gate exists. Waiting for instructions.*

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE f.2-5 f.7-11 f.14 f.15 f.17 f.32-34 · already-tracked f.16 f.18-20 f.22-26 f.28-30 f.35-37 · OBSOLETE f.1 f.6 f.12 f.13 f.21 · NEW rowed: f.27(+07-05 §f.18+07-19) → storage [watch], f.31(+07-05 §f.6+07-19) → security [blocked:user]
