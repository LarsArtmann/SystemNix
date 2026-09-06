# Status Report — BTRFS Pool Snapshot Health + `/data` Backup-Worthiness Session

**Date:** 2026-09-06 00:30 CEST
**Session scope:** Read-only infrastructure audit + 2 doc edits. No config/deploy changes. Host: evo-x2 (live checks, user `lars` — no sudo, `systemctl` blocked in session).
**Trigger:** User questions: (1) How are BTRFS snapshots doing on the pool? (2) Snapshots for ALL subvolumes? (3) Retention per volume? (4) Snapshot→pool delay? Then: is `/data` really only tiny docker volumes worth backing up? Then: full status update.

---

## a) FULLY DONE

1. **Pool snapshot health audit, all 4 sub-questions answered with live evidence.**
   - Root leg (`@` → `/mnt/pool/backups/root`): **HEALTHY** — 13 received snapshots, latest `@.20260904T2300`, kept FOREVER (`target_preserve_min = "all"`, snapshots.nix:157). Evidence: live `ls` + journal `btrbk-root` Sep 04 23:00→23:41 finished clean (`>>> @.20260904T2300`).
   - Pool-local leg (8 service subvols, `snapshotOnly`): **HEALTHY** — 48 snapshots, 8/8 subvols × 6 nights, latest `*.20260904T2345`. Evidence: live `ls /mnt/pool/.snapshots`.
   - Data leg (`/data` → `/mnt/pool/backups/data`): **DEAD** — 0 received ever; Sep 05 02:42 run aborted on the known EIO inode after 3h12m / 258G read. Evidence: journal + empty target dir.
   - Gap Aug 22–30 in root receives = the 9-day DAS outage; auto-resumed, no reseed. Pool capacity: 1.2T used / 15T (9%), 26.4T unallocated.
2. **Subvolume coverage matrix + exclusion rationale verified** (against snapshots.nix:131–215 + `/proc/self/mountinfo`): snapshotted = `@`, `/data` toplevel, 8 pool services. Excluded by design = `@nix` (rebuildable store), `@cache-home` (rebuildable caches), pool `archive/` (RAID1-only tier), pool `backups/` (is the target), `/mnt/samsung-nix` staging subvol.
3. **Retention table verified from config**: root 3d+1w local / forever pool; `/data` 14d+4w local / 30d+12w pool policy (never materialized); pool services 7d+4w.
4. **Snapshot→pool delay measured**: root = same-run, 41 min last night (23:00 snapshot → 23:41 receive complete, 31.9G incremental over USB). Caveat honored: single-night sample. `/data` = infinite. Pool services = 0 (already on pool).
5. **`/data` backup-worthiness verdict, evidence-backed**: only stateful data = docker volumes (twenty/manifest postgres, already pool-covered via nightly pg_dumps) **+ Steam compatdata 2.5G**. Verified clean: Jan data dir EMPTY, ollama = models only, hf_cache = cache. NFS Hot Pursuit Remastered confirmed LOCAL save paths (`pfx/.../Documents` + `Saved Games`); CS2 cloud-only; Upload Labs prefix empty.
6. **ROADMAP.md entry added** (Theme 1): `/data` rename + 3-model-root consolidation + `saves/` carve-out, with full config touchpoint list (8 nix files) and sequencing note (Samsung wave + EIO repair). Committed by daemon.
7. **AGENTS.md `/data` composition line refreshed** (287→291G ai, + compatdata 2.5G note, dated 2026-09-06).
8. **Two anomalies flagged, not buried**: mystery snapshot `data.20260905T2330` (see d-2); `btrbk-data` ran 02:42 Sep 05 (deploy/catch-up path), same EIO abort.

## b) PARTIALLY DONE

1. **Mystery snapshot `data.20260905T2330` root-cause** — Works: existence, mtime (Aug 18 16:02), created between my two checks ~22:15 (before the 23:30 timer), flagged to user. Missing: actual origin (needs `sudo btrfs subvolume show` / creation-time via `btrfs subvolume list`, or "did you/another session do this?" answer). Blocker: sudo blocked in session. Effort: S once sudo available.
2. **`/data` rename plan** — Works: idea recorded in ROADMAP, blast radius mapped (hardware-configuration.nix, snapshots.nix ×3 touchpoints, default-services.nix docker data-root, ai-models.nix, fastflowlm.nix + llama-rag.nix modelDir defaults, home.nix Jan symlink, gatus alert texts). Missing: detailed runbook, naming decision, scheduling decision. Blocker: user decisions. Effort: L for execution.
3. **Steam save-game safety** — Works: located state (compatdata 2.5G, 3 prefixes), confirmed which games have local save paths. Missing: per-game Cloud-status verification (NFS HPRE, Upload Labs), backup mechanism decision. Blocker: user priority call. Effort: S.

## c) NOT STARTED (identified this session)

1. **`compatdata` → backed-up `saves/` carve-out** — waiting on user decision (are those saves worth it?). Still wanted: recommended yes, it's 2.5G on 15T.
2. **`.crush` session-DB policy on bulk disks** — session DBs (264K + 224K) accumulate in whatever CWD a session runs in; `/data` is nominally disposable. No policy exists. Low value, tiny size; cleanup-only.
3. **Multi-night btrbk send-time baseline** — 41-min delay is one night's sample; no metric/SLO for snapshot→pool delay exists.
4. **`/data` rename + model consolidation execution** — ROADMAP'd only, deliberately (coordination with Samsung wave + EIO repair).
5. **`btrbk-data` fast-fail during the known-broken window** — proposed (see e-1), not implemented.

## d) TOTALLY FUCKED UP

1. **`/data`→pool btrbk leg: dead since 2026-07 AND burning the NVMe nightly for nothing.** Severity: data-tier gap (mitigated — the only true state is dump-covered) + nightly waste: **every night ~3h12m wall, 258G read, 18G mem peak, 329G written — for a send that structurally cannot succeed** (EIO inode 1.35M csum errors, TODO P0). Root cause: known /data corruption. Mitigation: OnFailure alerting works (by-design tripwire), `btrbk-pool-clean` correctly removes garbled targets — but nothing stops the nightly 258G read burn. Fixable now without touching the corruption: marker-gate `btrbk-data` (skip fast until T04 executes). **The current stance wastes ~8TB of QLC reads/month.**
2. **Unexplained tree mutation during the session**: `data.20260905T2330` appeared in `/data/.snapshots` between two of my checks (~22:15, timer not due), with a **dir mtime of Aug 18 16:02** — inconsistent with btrbk's create-time naming; consistent with a rename/restore of an old subvol. Severity: low (retention ages it), but it means an actor (concurrent session or manual op) mutated snapshot state with zero audit trail. Needs: `sudo btrfs subvolume list -t /data/.snapshots` (creation times) + a "who else is working" check. Unknown until answered.
3. **Pre-existing, re-confirmed in passing**: flm zombie still holds :52626 (whole NPU LLM stack down, only a reboot releases it — TODO P0); leaked-key rotation still pending (Resend dead → Pocket ID email broken; Context7 live). Not touched this session; still the two biggest reds on the board.

## e) WHAT WE SHOULD IMPROVE

1. **Fast-fail `btrbk-data` until the EIO repair** (marker-file ExecStartPre gate or a `ConditionPathExists=/data/.repair-done` guard). Impact: stops ~258G/night of pointless QLC reads + 3h of background load; keeps OnFailure semantics by inverting to a deliberate skip. Effort: S.
2. **Snapshot-dir mutations need an audit trail** — any manual `mv`/`btrfs subvolume snapshot` in `.snapshots` is invisible to everyone else (this session proved it). Suggested: note in AGENTS.md gotchas — never rename snapshots by hand; if a snapshot must be preserved past retention, copy it to a `-kept` name instead.
3. **Session-tooling constraints belong in memory**: this session wasted 5 tool calls on `sudo`/`systemctl` (both blocked for the Crush session on this host). Lesson recorded here: go straight to `journalctl`, `/proc`, and filesystem reads. Should land in AGENTS.md gotchas.
4. **Measure first, then record**: I wrote the ROADMAP entry before the compatdata discovery and had to amend it (twice — a concurrent session raced me mid-edit). Order: finish verification sweep → then write docs.
5. **Quote ranges, not single samples**: "41 min" delay came from ONE night's journal. Baselines used for SLOs or capacity claims should sample ≥3 nights.
6. **My first `.snapshots` listing command was wrong for the flat naming scheme** (`awk -F.` printed date fragments; per-subvol loop returned 0 because snapshots are `services_immich.TS`-flat, not nested). Use `btrbk -c … list` output or name-prefix greps for pool snapshot inventory.

## f) NEXT TASKS (ranked; brainstorm for docs-health HARVEST — nothing here is committed yet)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Execute `/data` corruption repair T04–T08 (master plan: docs/planning/2026-08-17_14-41) | Critical | L | Bug |
| 2 | Reboot into kernel 7.2.2 + flm v1.0.3 retry (releases :52626 zombie; whole AI stack down until then) | Critical | L | Bug |
| 3 | Add marker-gate fast-fail to `btrbk-data` until repair done (stop nightly 258G burn) | High | S | Quality |
| 4 | Rotate leaked keys: Resend (→ Pocket ID email + mail relay go-live), Context7, verify Synthetic | Critical | S | Security |
| 5 | Root-cause mystery snapshot `data.20260905T2330` (`sudo btrfs subvolume list/show`, session audit) | Medium | S | Bug |
| 6 | Fix attic VM test (deterministic RED at `checks.x86_64-linux.attic`, found 2026-09-04) | High | M | Bug |
| 7 | `/data` rename: decide name, then execute with mountpoint change (hardware-configuration.nix et al.) | Medium | L | Feature |
| 8 | Consolidate 3 model roots under `/data/ai/models` (absorb `/data/models` + `/data/llamacpp-models`) | Medium | M | Cleanup |
| 9 | Carve out `saves/` (compatdata + docker volumes); verify NFS HPRE/Upload Labs Cloud status | Medium | S | Feature |
| 10 | Mail relay go-live: verify `larsartmann.cloud` in Resend + paste API key (queue check stays red by design until then) | High | S | Feature |
| 11 | Google Sync: go-live (OAuth client + rclone authorize + sops fill) or annotate DORMANT in AGENTS | High | M | Decision |
| 12 | Off-site 3-2-1 decision (Google acceptable? StorageBox+Borg? sdf rotation?) | High | S | Decision |
| 13 | DiscordSync Turso cloud-sync decision (quota dead since 2026-08-16; local healthy) | Medium | S | Decision |
| 14 | `ManagedOOMPreference=omit` on dnsblockd (sole resolver, killed 730×/day pre-mitigation) | High | S | Bug |
| 15 | Root reserve file snapshot-pin caveat (T14): periodic rewrite timer or documented caveat | Medium | S | Quality |
| 16 | Re-measure + prune `/data/docker` (~88% pruneable) before any docker data-root move | Medium | S | Cleanup |
| 17 | Docker data-root move runbook (docker down → rsync → re-point → verify volumes) | Medium | M | Documentation |
| 18 | Steam library re-add step for the rename runbook (Steam stores library paths in its own config) | Low | S | Documentation |
| 19 | Model-path migration steps: flm modelDir, llama-rag modelDir, Jan activation symlink, ollama | Medium | M | Feature |
| 20 | gatus-config.nix alert-text path updates (`/data/ai/models/...` strings) on rename | Low | S | Cleanup |
| 21 | snapshots.nix updates on rename (btrbk-data volume path, tmpfiles, RequiresMountsFor) | Medium | S | Feature |
| 22 | pre/post-deploy script + bench scripts: grep for `/data` path assumptions before rename | Low | S | Quality |
| 23 | Register compatdata in backup-coordination (if saves decision = yes) | Medium | S | Feature |
| 24 | btrbk delay SLO: textfile metric + Gatus check "snapshot age on pool ≤ N hours" for root leg | Medium | M | Quality |
| 25 | Multi-night btrbk-root timing sample (≥3 nights) to replace the single-sample 41-min figure | Low | S | Quality |
| 26 | `.crush` session-DB sweep policy for bulk/scratch disks (or teach crush to co-locate them) | Low | S | Cleanup |
| 27 | Remove legacy empty dirs `/data/cache`, `/data/containers` during the rename wave | Low | S | Cleanup |
| 28 | Clean `/data/tmp-crush-test` (380M scratch) | Low | S | Cleanup |
| 29 | AGENTS gotchas: "no sudo/systemctl in Crush sessions — use journalctl + /proc + fs reads" | Low | S | Documentation |
| 30 | AGENTS gotcha: never hand-rename snapshots in `.snapshots` (audit-trail rule) | Low | S | Documentation |
| 31 | Samsung migration phase execution (pre-existing TODO clusters; rename should ride this wave) | High | L | Feature |
| 32 | `/nix` on Samsung: build + switch per the decided BTRFS-zstd design (1.89× compression) | High | L | Feature |
| 33 | pg_dump restore drill for twenty/manifest (prove the dumps that justify "nothing else needs backup") | Medium | M | Quality |
| 34 | Verify btrfs-verify-pool-backups covers the data leg's permanent failure as loudly as assumed | Medium | S | Quality |
| 35 | docs: extend the `/data` rename idea into a planning runbook when scheduled (touchpoint list is in ROADMAP) | Low | S | Documentation |
| 36 | Harvest this f-list into TODO_LIST/ROADMAP (docs-health HARVEST) | Medium | S | Documentation |
| 37 | CHANGELOG entry for this session's doc edits | Low | S | Documentation |
| 38 | Consider excluding `.snapshots` churn sources (e.g. redirect scratch-heavy CWDs off `/data`) | Low | S | Quality |
| 39 | flm v1.0.3 module retune post-reboot (MemoryMax sizing for Q4_K weights, smoke timeout re-check) | Medium | M | Bug |
| 40 | Immich/paperless restore-path documentation review (backup-coordination coverage map) | Low | M | Documentation |

**HARVEST note:** items 1–6, 10–14, 31 are already in TODO_LIST/P0-P1 (no new entries needed — verify, don't duplicate). New harvest candidates: 3, 5, 7–9, 16–28, 30, 34, 39.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Did you (or another concurrent session) create or rename anything under `/data/.snapshots` around 22:15 today?** A snapshot named `data.20260905T2330` appeared between two of my checks with an Aug-18 directory mtime. I cannot inspect other sessions or run `sudo btrfs subvolume list`. If nobody claims it, it needs root-side forensics.
2. **Do NFS Hot Pursuit Remastered / Upload Labs save games matter to you?** I confirmed NFS HPRE stores saves locally in the Proton prefix (2.5G compatdata). If yes → compatdata goes into the backed-up `saves/` set; if no → `/data` really is 100%-minus-pg-volumes disposable and the rename is unconstrained.
3. **Bundle or standalone?** My recommendation: execute the `/data` rename + model consolidation together with the Samsung migration wave and AFTER the EIO repair (one coordination window instead of three). Do you agree, or do you want the rename standalone and sooner?

---

**Session tool calls:** ~15 (2 wasted batches on blocked `sudo`/`systemctl`). **Files touched:** ROADMAP.md (+1 bullet, amended), AGENTS.md (1 line refreshed), this report. **Nothing deployed, no config changed, no services touched.**

_Waiting for instructions._

---

**Resolution 2026-09-06 (docs-health pass):** audit answers delivered; /data rename + snapshot-drop ideas are ROADMAP Theme 1; marker-gate fast-fail + mystery snapshot are NEW TODO rows (2026-09-06 harvest — this file's f-item 36 executed); P0 rewrite done. Execution-complete (audit scope).
