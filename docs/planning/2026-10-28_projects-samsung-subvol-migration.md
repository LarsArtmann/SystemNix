# ~/projects → Samsung Dedicated Subvolume Migration

**Created:** 2026-10-28
**EXECUTING (instance crush-executor-phaseB, 2026-10-28 10:38 CET, HEAD `7a59d5e42`):** executing (see AGENTS.md plan-execution tombstone)
**Date:** 2026-10-28 · **Status:** **PLAN — authored, NOT executed** (owner-gated execution window) · **Host:** evo-x2
**Executor note:** before executing ANY step of this file, write the `**EXECUTING …**` tombstone into this header per AGENTS.md plan-execution discipline (`scripts/plan-marker.sh <this-file> start`), and commit it immediately.

---

## 0. Goal

Move `/home/lars/projects` — live-verified 2026-10-28: **126 GiB raw, 342 top-level entries**, currently a plain directory inside the QLC root `@` subvolume — onto a **dedicated BTRFS subvolume on the Samsung 970 EVO Plus** (`tlc` filesystem; currently `/dev/nvme0n1p2`, but nvme0/nvme1 enumeration FLIPS across boots — `by-label tlc` is the only stable handle), 493 GiB free, **mounted at the exact same path** `/home/lars/projects`.

Path-invariant mount: every consumer path, symlink, unit WorkingDirectory, and flake `git+file://` input keeps resolving unchanged. Nothing downstream of the path moves; only the bytes beneath it change device and snapshot regime.

## 1. Why (ranked)

1. **IO class.** The QLC root sustains ~620/295 IOPS 4K QD1 (2026-08-31 `scripts/bench-disk.sh` baseline); the Samsung does **35.3k/79.2k** on the same axes — 50–270× on the latency axis that `git status`, `rg`, direnv, gopls, npm/cargo installs, and crush session tooling live on. 342 repos are read/walked constantly by the tq agent pool (watch row: 937 GB cumulative cgroup IO in one 27h boot walking/committing these trees), the project-discovery daemon, the auto-commit daemon, and every interactive session.
2. **QLC relief.** The single largest churning tree leaves `@`: SLC-cache write pressure drops, the 3d btrbk pin windows and the `.rescue/` second pin layer stop pinning project churn, and the nightly `@` send delta shrinks.
3. **Pool economics.** Today every byte `~/projects` ever wrote — including deleted cache and dead spikes — rides `@`'s pool receives with `target_preserve_min = "all"` (**FOREVER**). An own subvol with bounded retention ends the hoarding. This is the hermes migration's motivating problem, verbatim (`docs/planning/archived/2026-09-15_19-59_HERMES-HOME-SUBVOLUME-MIGRATION.md` §1).
4. **Independent rollback + snapshot policy.** Whole-tree rollback points decoupled from `@`; retention tuned per-tree instead of the root's crash-window 3d.
5. **It fits trivially.** 493 GiB free on the Samsung; real payload ≈ **50–55 GiB** once the doomed Go-cache leak trees are removed first (§5 Phase A).

## 2. Doctrine fit (decided from the ratified framework)

Per `docs/planning/2026-09-15_per-service-btrfs-subvolumes-analysis.md` (Set taxonomy §6, triggers §7): **Set B — own subvol + own btrbk entry + bounded pool target.**

- Satisfies triggers: "retention need > root's 3d" (unpushed work deserves >3d), "migration planned", "deploy-paired state rollback".
- **NOT Set C** (`+C`, unsnapshotted): projects hold irreplaceable unpushed branches, sops-encrypted secrets, and reports; forfeiting snapshots/pool sends for CoW-write-amp savings is the wrong trade here. `nodatacow` rejected for the same reason hermes rejected it (trades away checksums). Git's own hashing (`git fsck`) is the integrity layer for `.git`, but the working trees and non-git state have no such layer.
- **NOT a `services.hot-user-caches` entry.** That module is the doctrine-C cache family: automount, no legs, and its own comment says *"caches must never join a btrbk leg; the users/ tree has no legs — keep it that way when adding entries."* `projects` deliberately breaks the users/-no-legs invariant — it gets its own mount + btrbk instance, NOT an entry in that module. The 2026-10-26 owner directive ("NOT a projects subvol", `docs/todo/storage.md` row 184) applies to the ~59G Go-cache leak trees — those get deleted at source, not migrated (§5 Phase A).

## 3. Decisions

| # | Decision | Choice | Rationale | Rejected alternative |
|---|---|---|---|---|
| D1 | Subvol name | `users/lars/projects` on the Samsung toplevel | `users/<user>/<thing>` namespace precedent (`users/lars/cache/nix`, `users/lars/tmp`); user-owned, snapshotted data | `hot/projects` (hot/ = doctrine-C service family); `@home-lars-projects` (QLC-toplevel naming) |
| D2 | Mount shape | **Plain `fileSystems."/home/lars/projects"`** in `snapshots.nix` (hermesHomeMount pattern), device `/dev/disk/by-label/tlc`, options `subvol=users/lars/projects noatime nodiscard commit=300 nofail` | Plain mounts order before `local-fs.target`, so tmpfiles/HM activation only ever see the mounted subvol (automount+tmpfiles = shadow-dir class); `nofail` per the non-root-mount boot rule; compression is filesystem-wide on `tlc` already (no per-mount `compress`). Declare with the hermesHomeMount raw shape in `snapshots.nix` (file-local consistency; `mkFilesystem` is the hardware-configuration.nix-side validator) | automount (lazy mount + activation writes = the 2026-09-20..29 bootstrap incident class); nested unmounted subvol (no mount unit to gate writers on, no clean btrbk target name) |
| D3 | Backup | New `btrbk.instances."projects"` (forgejo-instance shape): `volume."/mnt/hot"`, `snapshot_dir = /mnt/hot/.snapshots`, `subvolume."users/lars/projects"` → `target = /mnt/pool/backups/projects-subvol`, local `snapshot_preserve_min 2d / snapshot_preserve 3d`, pool `target_preserve_min 7d / target_preserve 14d 8w`, `onCalendar = "23:10"` (staggered: root 23:00, data 23:30, pool 23:45, clean 23:50), seed-sized `TimeoutStartSec` (≥4h; first full send ~55 GiB) | Forgejo is the living Samsung-side btrbk precedent; bounded retention ends forever-hoarding; 23:10 slot keeps the nightly ladder staggered | riding the root instance (cross-filesystem — impossible, `@` is QLC, the subvol is Samsung); no btrbk entry (Set C — rejected §2) |
| D4 | Pre-deploy gate | Extend `scripts/shadow-split-gate.sh` (§18) enumeration with a third source (class `data`, shadow `/home/lars/projects`, subvol `/mnt/hot/users/lars/projects`) driven from the new config surface (nix-eval'd, same pattern as the `uc`/`hdb` legs) | The gate today only knows `hot-user-caches.caches` + `hot-db.entries` — a projects mount would be INVISIBLE to the wave-6 protection; the wave-6 signature (non-empty shadow + empty subvol) is exactly this plan's cutover failure mode | relying on the prepare script alone (one-shot, human-gated; §18 exists because prepare steps get skipped) |
| D5 | Old QLC tree | Stays in place **as the shadow beneath the mount** after cutover; after burn-in: archived to pool (`tar.zst` → `/mnt/pool/backups/home-lars-projects/`, family precedent from `migrate-user-tmp-hot.sh` shadow-cleanup) then `trash`ed. QLC space frees across the `@` 3d pin + `.rescue/` ~1–2d windows — NOT instantly (pinning doctrine; never size reclaim from post-rm `df`) | Rollback stays one `umount` away until the very end; the tar is the last full pre-migration copy (btrbk receives only cover post-migration state). Post-cutover rollback = umount + reverse-delta rsync of writes made since cutover (or accept their loss) — the one-umount instant path restores the PRE-cutover state only | deleting the old tree at cutover (no rollback ladder); keeping it forever (126 GiB QLC hostage) |
| D6 | Writer gating | Every unit that writes under `/home/lars/projects` gets `unitConfig.RequiresMountsFor = [ "/home/lars/projects" ]` (+ `ConditionPathIsMountPoint` on writers, clickhouse pattern) — **fail loud, never shadow-write** | The mount's nofail means a missing Samsung degrades boot to an empty mountpoint dir; a daemon writing there = split-brain divergence from the shadow copy — strictly worse than a dead service for source-of-truth repos (doctrine-C "degrade don't die" is for logs/caches, NOT for this) | wants-not-requires wiring (correct for regenerable logs, wrong for source of truth) |
| D7 | Sequencing | **Phase A hard-gates the rest:** the ~59G Go-cache leak trash (`docs/todo/storage.md` row 184, owner-directed) + the wevisone-spike decision (2026-10-26 plan §2.1) land FIRST; prepare's rsync excludes `.gocache-disk/ .golangci-disk/ .gotmp/` regardless | Never rsync 59 GiB of doomed cache 50× faster than it needs to be deleted | migrating everything including doomed trees |
| D8 | Provisioning | Subvol created by the migrate script's `prepare` phase through `/mnt/hot`; declared in `disko/samsung-tlc.nix` (`/users/lars/projects`, `mountpoint = null`) for re-provision parity; hot-user-caches' eval assertion pattern (disko-row must exist) mirrored | fstab cannot create subvols; the 2026-09-20..29 bootstrap saga proves runtime provisioners against mounts are banned (ordering cycles, D-state autofs waits, load 86) | any runtime bootstrap oneshot (banned class) |

## 4. Live-state inventory (verified 2026-10-28, this session)

| Fact | Value | Source |
|---|---|---|
| `~/projects` size / entries | 126 GiB / 342 | `du -sh` + `ls \| wc -l` |
| Doomed-before-migration | ~59 GiB leak trees (`.gocache-disk` 35G, `.golangci-disk` 15G, `.gotmp` 9.2G) + `wevisone-spike` 19G (owner decision pending) | `docs/todo/storage.md` row 184; 2026-10-26 plan |
| Biggest keepers | ojev-lab 10G, ssh-key-monitor 7.6G, faceswap 6.1G, anime-comic-pipeline 5.7G, nsfw-classifier 4.7G, monitor365 4.1G … | `du` top-25 |
| Samsung free | 493 GiB (`/dev/nvme0n1p2`, 45% used, `/nix` + `/mnt/hot` + hot subvols live there) | `df -h /mnt/hot` |
| QLC free | 250 GiB (65% used) | `df -h /` |
| Current snapshot regime | inside `@`: daily 23:00, local 2d/3d, pool FOREVER; rescue tier ×2 | `snapshots.nix` + storage.md |
| Mount target device | `/dev/disk/by-label/tlc` (nvme enumeration flips — by-label mandatory) | `hardware-configuration.nix:79,113` |

**Writer/reader units touching `/home/lars/projects`** (each needs the D6 gating sweep, verified by grep this session):

| Unit / surface | Path used | Today gated? |
|---|---|---|
| `projects-management-automation.service` + `pma-daemon-watchdog` (`modules/nixos/services/projects-management-automation.nix`) | watch trees under `~/projects` | audit + wire BOTH units (D6) |
| `project-discovery-daemon` (`modules/nixos/services/project-discovery-daemon.nix`) | `~/projects` discovery roots | audit + wire (D6) |
| `tq-agent-pool` agents (`modules/nixos/services/tq-agent-pool.nix`) | walk + commit `~/projects/*` repos | DB is pool-gated; projects side un-gated → wire (D6) |
| `cv-server` (`cv.nix`) | `profileDir = /home/lars/projects/CV` | wire (D6) |
| `bank-sync` importers | `~/projects/bank-sync/data/...` CSVs | wire (D6) |
| `nsfw-classifier` | `~/projects/nsfw-classifier/models` | wire (D6) |
| `_signoz-metrics` collector | `REPO=/home/lars/projects/SystemNix` (read) | wire — read-side failure must be loud, not phantom-zero (D6) |
| `hermes` `projectsDir` bind-mount | read-only bind of projects (when enabled) | already `RequiresMountsFor` stateDir+projectsDir (hermes T3a) — re-verify option value |
| rust-cache target symlinks (`snapshots.nix` activation) | creates `~/projects/<p>/target` symlinks | creation unit needs mount gating (symlink into unmounted shadow = shadow-dir writes) |
| flake inputs `git+file:///home/lars/projects/*` | read-only evals | none needed (fail loud by construction) |
| interactive sessions (crush, editors, shells) | everything | sessions start after `local-fs.target`; plain mount (D2) covers it |

Path-preserved surfaces needing NO change: `~/.config/crush/skills` fan-out symlinks, HM out-of-store symlinks, `post-deploy-check.sh` CV smoke, `hermes-state-audit.sh`, flake input URLs, systemd-timer-monitor repo paths, the crush-hot-db `~/projects/legal-cases/.crush` symlink.

## 5. Execution phases

> Agent-authorable work = Phases B and the scripts/tests inside C/E/F config. Phases C–F need one owner window (~45–90 min) for the sudo legs + writer quiesce.

### Phase A — prerequisites (hard gate, no config work before this)

- [ ] A1. Land `docs/todo/storage.md` row 184 (Go-cache leak source-removal + trash of `projects/{.gocache-disk,.golangci-disk,.gotmp}` ~59 GiB after builds quiesce). Cross-repo consent + owner directive already on the row.
- [ ] A2. Owner decision on `wevisone-spike` (trash vs keep — 2026-10-26 plan §2.1). If kept: it migrates like any repo; if trashed: gone before prepare.
- [ ] A3. Space asserts (script-enforced, not eyeballed): Samsung free ≥ payload×1.5; QLC unalloc > 10 GiB (the balance-jobs floor); pool free ≥ payload×1.5 (seed + shadow archive).
- [ ] A4. No active IO storm: the prepare script self-refuses while IO PSI some avg10 ≥ 20% / a balance or btrbk send is streaming (family entry gate, `migrate-user-tmp-hot.sh`).
- [ ] A5. Coordinate with the `~/tmp` hot-user-caches migration window (its todo row: E6 execution owner-gated) — two user-tree Samsung migrations share the quiet-window + PSI gates; never run two prepare/cutover passes concurrently.

### Phase B — agent: config + guards (deployable BEFORE any data exists — "loud but safe")

Deploy-before-prepare is explicitly safe: missing subvol + `nofail` = boot fine, writers fail loud on `RequiresMountsFor`, btrbk instance aborts at its mount gate. The §18 gate extension (B4) FAILS the deploy while the shadow is populated and the subvol is empty — that is the designed protection, do not bypass it; deploy Phase B's generation only after Phase C prepare, or accept a §18 FAIL (exit 1 blocks deploy) by design.

- [ ] B1. `platforms/nixos/system/snapshots.nix`: `projectsHomeMount` block (D2 exact options, hermesHomeMount shape + comment discipline) + `btrbk.instances."projects"` (D3). Also extend `btrbk-pool-clean`'s config loop (`for conf in root data pool forgejo` → `+ projects`, with the same `/mnt/hot`-detached clean skip forgejo has) and mirror the `btrbk-forgejo` service override block (User=btrbk + the sudo-backend `btrfs-progs-sudo` note, ioTier.background, seed-sized timeout). The btrbk sudo story is command-bounded via the nixpkgs module's sudoRule (subvolume list/show/delete through the wrapper) — no new allowlist paths needed (verified snapshots.nix:702-745).
- [ ] B2. `disko/samsung-tlc.nix`: `/users/lars/projects` subvol row, `mountpoint = null` (created on re-provision, not mounted there).
- [ ] B3. Mount-gating sweep (D6): every unit in the §4 table gets `RequiresMountsFor=/home/lars/projects` (+`ConditionPathIsMountPoint` where it writes); clickhouse's conditional pattern (`builtins.hasAttr "/home/lars/projects" config.fileSystems`) so VM/test hosts without the mount are unaffected.
- [ ] B4. `scripts/shadow-split-gate.sh`: third enumeration source (class `data`, name `projects`); extend its fixture/selftest (`flake/parts/checks/fixtures-storage.nix` + `scripts/negative-test-lints.sh` legs) with a projects case (empty-subvol FAIL + parity WARN + prepared PASS).
- [ ] B5. Verify legs: per-prefix freshness in `btrfs-verify-pool-backups` + `btrfs-verify-snapshots` (hermes pattern: expect `users*` — actual received-prefix name verified from the first seed — only while `systemctl is-active home-lars-projects.mount`); 12h-threshold freshness metric leg (forgejo `forgejo_subvol_backup_fresh` pattern) → Gatus check + integration-registry backup row. The local-snapshot freshness leg is NEW surface (forgejo has no btrfs-verify-snapshots leg — its freshness rides the collector): the 12h freshness metric is the PRIMARY detector, the pool per-prefix leg the hermes-precedent secondary.
- [ ] B6. `scripts/migrate-projects-subvol.sh` — family script (`migrate-user-tmp-hot.sh` + `migrate-hermes-subvol.sh` + `migrate-clickhouse-xfs.sh` synthesis), phases: `prepare` / `deploy` (hint only) / `finalize` / `shadow-cleanup`. Contract details in §6.
- [ ] B7. Tests: eval assertion (the `tests/test-hermes.nix` `systemctl show hermes -p RequiresMountsFor` probe, ≈:169) pinning `RequiresMountsFor` on the gated units; disko-row presence assertion (hot-user-caches assertion pattern); `bash -n` on new/edited scripts; selftest legs green.
- [ ] B8. Docs: this plan stays the execution map; runbook section → `docs/services/` new `projects-subvol.md` (port §5–§6); AGENTS/storage.md subvol-layout paragraph updates + CHANGELOG entry land at execution close-out (Phase F), not now.
- [ ] B9. Verify: `nix flake check --no-build`; targeted evals (fileSystems entry, btrbk instance, gated units, gate enumeration via `nix eval`); hand-probe new assertions once (eval-cache trap); **pre-build the toplevel** (`nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` first if anything upstream fails — the domino rule) so the cutover deploy is a fast switch. NOTE 2026-10-28: flake check is currently RED repo-wide from a parallel session's backup-coordination refactor (storage.md last row) — verify YOUR legs via targeted evals until that strand heals.
- [ ] B10. Pipeline integration: new oneshot/metric units → deploy.sh restart/converger list (deploy-restart-audit compliance) + pre-deploy §10 metric-presence legs + post-deploy §13 validation rows.
- [ ] B11. **Scrub coverage gap (found by this plan's review): the Samsung `tlc` fs is NOT in `btrfs.autoScrub.fileSystems`** (only `/`, `/data`, `/mnt/pool` — snapshots.nix:447). Projects would put checksummed source-of-truth on the only pre-pool-send copy of a NEVER-scrubbed filesystem. Add `/mnt/hot` (one scrub covers the whole fs incl. `/nix`) and verify `btrfs-health-metrics` emits per-mount scrub metrics for the 4th mount. Cost: ~400 GiB weekly read at idle priority on the fast Samsung; the scrub deferral guard already wraps the template unit (storms defer, never block).

### Phase C — owner window, part 1: `prepare` (no downtime, ~2–4 h throttled background)

- [ ] C1. Owner runs `sudo bash scripts/migrate-projects-subvol.sh prepare` (binary preflight resolves EVERY tool up front from the flake's nixpkgs — sudo's secure PATH hides user tools; the clickhouse `sgdisk` lesson: preflight BEFORE anything stops).
- [ ] C2. Script gates: refuses if `/home/lars/projects` is already a mountpoint; refuses a non-empty subvol (restart hygiene); refuses on PSI/balance storm (A4); creates `users/lars/projects` via `/mnt/hot` (mkdir -p users/lars path) and chowns the fresh subvol root to the primary user at creation (root-created via /mnt/hot).
- [ ] C3. Throttled double-pass rsync `ionice -c3 nice -n19 rsync -aHAXS --info=progress2 --exclude` the D7 leak dirs (first pass full, second pass converges deltas; re-runnable nightly until cutover; `-S` sparse-aware — ML trees carry sparse files, without it they land dense-but-correct). NO `--reflink` (rsync has no such flag — the 2026-08-17/09-16 trap, twice-burned).
- [ ] C4. Verify gate: file-count + byte parity within tolerance (churning source — bands not equality, shadow-split-gate semantics), spot `git -C ~/projects/SystemNix fsck --no-dangling` clean on the SUBVOL COPY via `/mnt/hot/users/lars/projects`.
- [ ] C5. Workdir for logs/state: `~/.cache/projects-migration/` (never `/tmp` — volatile-wipe trap).

### Phase D — cutover window (~30–60 min, all writers quiesced)

- [ ] D1. Owner closes interactive sessions/editors; agent stops the writer units (D6 list) — explicit PIDs from `pgrep -af` piped through `scripts/redact-argv.sh`, kills via absolute `/run/current-system/sw/bin/kill` (the mvdan/sh kill-builtin trap; `kill -0` liveness probes NEVER work — use `pgrep -f`/`test -d /proc/<pid>`).
- [ ] D2. Final delta rsync (writers stopped — converges to equality; `--checksum` pass on the top 20 repos by size, quote-scrutiny: sanity-check one known repo's file count through the same pipeline before quoting any number).
- [ ] D3. `nix run .#deploy` with the pre-built Phase-B generation: §18 gate PASSES (subvol populated, parity band), fstab mounts `users/lars/projects` OVER the live old dir (shadow intact beneath — recoverable), gated units restart against the mount.
- [ ] D4. Smoke: `findmnt /home/lars/projects` shows `tlc[/users/lars/projects]`; `git -C … fsck` ×2 repos; `test -L ~/.config/crush/skills/<one>` resolves; writers active; CV render smoke (`post-deploy-check.sh` legs); a `crush` session opens the SystemNix repo; `ls ~/projects | wc -l` ≈ 342.
- [ ] D5. Reboot-gap rule: from D3 on, the fstab is boot-persistent — no gap window exists. (If a manual mount had been used instead: deploy must complete before any reboot; D3's deploy-carries-fstab design eliminates the gap by construction.)
- [ ] D6. **Controlled boot proof (recommended inside the window):** `nix run .#pre-reboot-check` (house rule before every planned reboot), then one deliberate reboot with the owner present — exercises the fstab mount + RequiresMountsFor gating at BOOT time, the one path a live cutover never tests; verify mount + writer units green within 2 min of login.

### Phase E — `finalize` + first backup leg (same day)

- [ ] E1. `finalize` gates: mount is a mountpoint; user write probe onto the mount (ownership — the subvol must be chowned lars:users, `+C` NOT applied); `btrbk-projects` first seed (`systemctl start btrbk-projects`, ≥4h timeout, journal exit summary is the receipt); pool receive exists + verify OK.
- [ ] E2. First nightly ladder green: 23:10 snapshot + send, per-prefix verify legs PASS (first-night leg runs WARN-aware if the schedule boundary bites — do not page on the boundary case).
- [ ] E3. btrfs-health/gatus surfaces green; `btrfs-verify-pool-backups` sees both `@` and the projects prefix fresh.

### Phase F — burn-in + `shadow-cleanup` + close-out (≥7 days later)

- [ ] F1. Burn-in gates: ≥7 days, ≥5 green nightly sends, zero mount/gating alerts, IO sanity (optional `scripts/bench-hot-file.sh` on the mounted tree).
- [ ] F2. `shadow-cleanup` (script, sudo): derive root partition from `findmnt -no SOURCE /` (enumeration-flip trap; REFUSE if the mount is suddenly QLC-served = Samsung detached, the family guard); bind-view the shadow at a `/run` aux mount (clickhouse `--bind /` view — NO unmount/remount dance); `tar.zst` the shadow → `/mnt/pool/backups/home-lars-projects/projects-shadow-final-<date>.tar.zst`; then `trash` the shadowed tree through the bind view; verify via a fresh bind view that the shadow dir is empty.
- [ ] F3. QLC reclaim expectation documented: frees across `@` 3d pins + `.rescue/` (~1–2d) — expect the drop in `df` days later, never instantly; never size the success from post-trash `df`.
- [ ] F4. Close-out: AGENTS.md + `docs/agents/storage.md` subvol-layout paragraph (the "`~/projects` lives in `@`" row in the pin-window table retires); CHANGELOG entry; status report in `docs/status/` that SELF-HARVESTS its follow-ups (TODO_LIST + domain libraries, or explicit not-harvested-because notes); strike this plan's checkboxes with evidence; `scripts/plan-marker.sh <file> done`.

## 6. The migrate script contract (`scripts/migrate-projects-subvol.sh`)

- Phases `prepare | finalize | shadow-cleanup` (+ `--dry-run`), `set -uo pipefail`, root gate, `--dry-run` honored throughout.
- Binary preflight FIRST (sudo secure-PATH lesson): `rsync ionice nice timeout btrfs findmnt tar zstd` resolved from the flake's pinned nixpkgs before anything stops.
- PSI/storm entry gate + throttled walks (`ionice -c3 nice -n19 timeout`) on EVERY du/find/rsync (§d1 rule — filesystem walks are throttled ALWAYS).
- Idempotent + re-runnable: prepare re-runs do delta passes; finalize refuses unless mount live; shadow-cleanup refuses unless mount live AND ≥5 pool receives AND Samsung-served (root-part guard).
- Excludes (hardcoded + documented): `.gocache-disk/ .golangci-disk/ .gotmp/` (Phase A doom list).
- Never: `--reflink` on rsync; runtime subvol bootstrap units; writes to `/tmp`; secret values on command lines; `pkill -f` broad patterns; `kill` builtin (absolute path only).
- Logging: every phase appends a state record under `~/.cache/projects-migration/` (phases, timestamps, byte counts) — the shadow-split-gate's "state record" reference point.

## 7. Verification matrix × prevention layers

| Layer | What this change adds | Gate |
|---|---|---|
| Eval-time (Nix) | fileSystems entry via mkFilesystem-validated options; btrbk instance shape; RequiresMountsFor assertions; disko-row presence assertion; §18 enumeration eval | `nix flake check --no-build` + targeted evals (B9) |
| Pre-commit | shellcheck on new scripts; todo-system check (the storage.md row); templ/nix lints as always | `.githooks/pre-commit` |
| CI | negative-test leg for the §18 projects case; fixtures update | `negative-tests.yml` + `fixtures-storage` |
| Pre-deploy | **§18 shadow-split-gate now covers projects (data class)** — FAILs on empty-subvol-over-populated-shadow; §11 FOD preview unaffected (no FODs); disk-space check sees the fstab; §10 metric-presence legs for the new freshness metric | `scripts/pre-deploy-check.sh` |
| Post-deploy | mount-live smoke, writer liveness, CV render legs, first btrbk seed receipt, per-prefix backup freshness (12h threshold) | `scripts/post-deploy-check.sh` + E-phase gates |

## 8. Risks & mitigations

| Risk | Class (precedent) | Mitigation |
|---|---|---|
| Mount over populated dir with EMPTY subvol | wave-6 shadow-split (postgres, 2026-10-19) | §18 gate extension D4 FAILs the deploy; prepare must land first; parity-band check |
| Daemon writes into unmounted shadow dir | split-brain (the exact anti-goal) | D6 fail-loud gating; no wants-not-requires for source-of-truth writers |
| Runtime subvol bootstrap wedging boot | 2026-09-20..29 bootstrap saga (banned class) | D8: script-created subvol only, no units ordered against mounts |
| fstab-before-subvol deploy | hermes "loud but safe" | nofail + RequiresMountsFor; document that Phase B deploys before Phase C will §18-FAIL by design |
| Garbled first receive | "exists, but is not a receive target" | `btrbk-pool-clean` nightly + manual heal runbook (pool section, storage.md); never `incremental strict` |
| IO storm during prepare/cutover | freeze class (2026-08-24) | A4 PSI gate, throttled rsync, ionice, quiet-window scheduling (never during balance/scrub/btrbk windows) |
| Space math wrong (snapshots pin) | pinning doctrine | A3 asserts; F3 documents the delayed-free expectation |
| Tool traps | rsync-reflink, sudo PATH, kill builtin, `/tmp` wipes, jq-in-direnv, `rg -r`, kill -0 | §6 contract enumerates them; script avoids all |

## 9. What does NOT change

- Every path under `/home/lars/projects` (the mount is path-invariant — the whole design).
- Pre-migration pool history (existing `@` receives keep their FOREVER retention).
- `@`'s own snapshot policy; the rescue tier; the nightly ladder timings of existing instances.
- hot-user-caches, hot-db, `@cache-home`, buildcache/rust-cache wiring.
- No ports, no sops secrets, no new services beyond the btrbk instance + verify/metric legs.

### 9.1 Semantics that DO change (operational notes — land these in the F4 docs)

- `trash` inside `~/projects` reroutes to the Samsung subvol's `.Trash-1000` (mount-bound; storage.md trash-routing row) — big deletes now pin subvol snapshots (2d/3d local) and pool receives (bounded 14d/8w) instead of QLC `@` pins.
- `df /` no longer sees projects growth; the Samsung becomes the growth surface (btrfs-health composites cover it once B11's 4th mount lands).
- The weekly scrub set gains the `tlc` filesystem (B11) — a new recurring ~400 GiB read, storm-guarded, idle priority.

## 10. Open decisions for the owner (blocking window scheduling only)

1. **Window**: Phase C may run any throttled evening; Phase D needs ~30–60 min with all sessions/editors closed. Pick a quiet night (no balance Mon 04:00/05:00, no btrbk 23:00–00:00 ladder).
2. **wevisone-spike** fate (rides Phase A / the 2026-10-26 plan's g.3).
3. **Retention confirm**: proposed pool `14d 8w` (forgejo-parity for state-class). Longer (e.g. `30d 12w`) costs pool space only (~13 TiB free — trivial); shorter loses unpushed-work depth.
4. **Offsite**: when `offsite-borg` goes live, include `/home/lars/projects` in its paths? (Recommended YES — the pool is same-chassis; projects then get a true off-NVMe, off-house copy. Separate row at that go-live.)

## 11. Acceptance criteria (the plan is DONE when)

1. `findmnt /home/lars/projects` → `tlc[/users/lars/projects]`, survives a reboot (D6); `ls ~/projects | wc -l` ≈ 342; sizes match the C4 parity bands.
2. Every §4 writer unit carries `RequiresMountsFor=/home/lars/projects` (pinned by the B7 eval assertion) and is active.
3. Seven consecutive green `btrbk-projects` nightly runs; ≥5 pool receives; per-prefix verify legs PASS; freshness metric green ≤12h.
4. §18 gate covers `data/projects` with a fixture-proven FAIL on the empty-subvol case — negative-test leg green in CI.
5. Old tree archived (`projects-shadow-final-*.tar.zst` on pool, size-verified) then trashed; QLC `df` drops across the pin windows (F3 expectation, not instant); shadow verifiably empty via a fresh bind view.
6. Docs closed out: storage.md layout + pin-table rows, CHANGELOG, status report with self-harvested follow-ups, this plan's checkboxes struck with evidence, plan marker `done`.

## 12. Task table (dispatch view)

| # | Task | Phase | Owner | Effort | Depends |
|---|---|---|---|---|---|
| T1 | Go-cache leak trash + wevisone ruling | A | owner + agent | 90 min | row-184 consent (standing) |
| T2 | snapshots.nix: mount + btrbk instance + pool-clean loop + forgejo-override mirror | B | agent | M | T1 |
| T3 | disko row + eval assertions (disko-row presence, RequiresMountsFor) | B | agent | S | T2 |
| T4 | Writer-gating sweep (10 surfaces, §4) | B | agent | M | T2 |
| T5 | §18 gate third source + fixtures + negative legs | B | agent | M | T2 |
| T6 | Freshness metric + verify legs + Gatus + registry row | B | agent | M | T2 |
| T7 | `scripts/migrate-projects-subvol.sh` (prepare/finalize/shadow-cleanup) | B | agent | L | T2 |
| T8 | Scrub coverage (B11) + deploy.sh/§10/§13 integration (B10) | B | agent | S–M | T2 |
| T9 | flake check (targeted evals while sibling strand red) + pre-build toplevel | B | agent | M | T2–T8 |
| T10 | prepare (throttled seed, unattended) | C | owner (sudo) | 2–4 h wall | T9 + quiet window |
| T11 | cutover: quiesce → final delta → deploy → smoke → boot proof | D | owner + agent | 30–60 min | T10 |
| T12 | finalize + first btrbk seed + verify legs green | E | agent | 30 min | T11 |
| T13 | burn-in watch (passive) | F | agent | 7 d | T12 |
| T14 | shadow-cleanup (pool archive → trash) + close-out docs | F | owner (sudo) + agent | 60–90 min | T13 |
