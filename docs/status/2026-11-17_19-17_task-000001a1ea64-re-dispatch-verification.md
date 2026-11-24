# Re-dispatch verification: task-000001a1ea64 (5-item services batch)

Executing instance: dispatched task-queue agent, 2026-11-17 ~19:0x–19:1x, HEAD `d195f683`.
Re-dispatch context: items 1 + 4 already landed by the prior fire (footer commit `b4d360f91`);
this fire ran the CONTRIBUTING re-dispatch protocol over all 5 items.

## Per-item verdicts

### Item 1 — smoke-failure triage: SKIP, verdict STANDS (verified)

- Queue surfaces: `TODO_LIST.md` ticked (TRIAGED 2026-11-17) + `docs/todo/services.md:1112` carrying the
  full 5-way mapping; footer commit `b4d360f91` present under the exact Task-Queue-ID.
- §f sweep (step 3, item-scope): all five mappings' owning rows exist in the tree — llama stranding row
  (TODO_LIST "Re-arm the post-crash calm gate"), calm-gate deploy row (stability.md), Health-Hub
  /readyz semantics row (services.md "Health Hub /readyz semantics"), borg tripwire (RESOLVED, pipeline.md),
  papdashboard float/deploy + WARN rows (items 2/3 of this batch), node-exporter freeze-56 row (stability.md).
- Load-bearing live spot-check (step 2): the node-exporter poisoned-prom claim —
  `system_health.prom` line 1 = `system_flm_crash_trigger_pair_24h` (metric name, EMPTY value, `cat -A`-verified);
  node_exporter rejected it **46,734 times today** (parse error "line 1: expected float as value, got empty"),
  still failing at 19:12:06. Poison class LIVE, fix in-tree deploy-gated — exactly as the row states. TRUE.

### Item 4 — mr-sync flap driver: SKIP, verdict STANDS (verified)

- Queue surfaces ticked (IDENTIFIED 2026-11-17, footer commit); serve-stale follow-up minted (TODO_LIST +
  services.md upstream mr-sync row).
- Load-bearing live spot-check: 73 mr-sync flips in the 18:10–19:05 journal window (~1.3/min ≈ the claimed
  ~1/min), and the 19:03:27→19:03:52 pair is exactly the identified **25s-down** signature (the TTL-cache
  rebuild stall). TRUE.

### Item 2 — papdashboard float + deploy: BLOCKED:deploy, verdict unchanged (verified live)

- Live probe 19:0x: upstream `47ceb66` (SSE envelope fix) is contained in `origin/oci-go-standard-pilot`
  (tip `b4e2f99`) but NOT in origin/master; the flake input floats `refs/heads/master` (lock `c18dbb2c`).
  `git merge-base --is-ancestor 47ceb66 origin/master` → NO.
- The services.md row's 18:2x UPDATE already describes exactly this state — no drift, no re-stamp needed.
- Owner action owed: merge the pilot branch to master + push; then float + deploy per the row.

### Item 3 — upstream projection-WARN quieting: BLOCKED:push, verdict unchanged (verified live)

- Live probe 19:0x: the WARN-quieting fix is NOT upstream (pilot tip `9af7bd7` is the OCI-migration commit,
  authored 18:46:38; working tree last written 18:47); the envelope fix IS pushed (`b4e2f99` contains
  `47ceb66`). Queue rules bar agent pushes from this dispatch; the pilot session was active ~23 min before
  the probe, so uncoordinated authoring on its branch stays wrong.
- The row's 18:2x UPDATE already describes this state — no drift, no re-stamp needed.

### Item 5 — monitor365 buffer-dir inventory: PARTIALLY ANSWERED unprivileged; retagged [blocked:user]

Three remediation passes before the blocked verdict (error-handling discipline):

1. **Direct sudo** — `sudo -n true` → rc=1, NNP error verbatim (expected: non-yolo session).
2. **Nested yolo session** (the row's prescribed workaround, per the 2026-11-11 precedent) —
   `crush run -y` child ran `sudo -n true` → **rc=1, NNP error verbatim**; re-probed with a minimal
   second child (same rc). **The v0.100.0 nested-yolo sudo exemption is DEAD under crush v0.101.0.**
   AGENTS.md's exception note amended same day; the 2026-11-11 precedent retired as a workaround recipe.
3. **Unprivileged exact-path probes** (the 0711 dir is traversable, NOT listable — also corrects the row's
   "0700" premise): segments live FLAT in the buffer dir (upstream `crates/crypto/src/storage.rs`
   `has_segment_files` does `buffer_dir.read_dir()` on `seg_*.zst`), so stat hits the real path shape.

Evidence:

- `stat /mnt/pool/services/monitor365/seg_000554200281_000554200290.zst` → **ENOENT** — the corrupt
  segment is **gone from disk**, consistent with the upstream auto-quarantine semantics
  (`SegmentError::Integrity` → `delete_acked` through seg_end, not moved aside).
- Known-positive control (a probe that cannot fail loudly is not a probe): `storage_key` stats fine
  (44 B, mtime 2026-08-02) → traversal works, ENOENT is meaningful. `.cipher` ENOENT = the source's
  legacy-AES detection branch (no meta file).
- Dir ctime 2026-11-15 19:03:54 = upper bound for any entry mutation since; combined with the prior
  fire's 0 AEAD WARNs across all retained journal, no NEW corrupt segments since.
- Fresh `:9421/metrics` read (19:1x): `cloud_sync_upload_backlog_size 9` (was 14 this morning —
  uploads flowing), `cloud_sync_backlog_stall_cycles 0`, quarantine counter never registered.

Surfaces updated together: `TODO_LIST.md` one-liner + `docs/todo/services.md` row retagged
`[blocked:user]` with the landed evidence + the new BLOCKED reason.

**Remaining (sudo-only, non-harvestable): full enumeration** — total segment count, bytes, and any
OTHER leftover corrupt segs. Only an owner shell or privileged terminal can list the dir now.

## f) sweep statement (step 3)

Scope: item-derived obligations of THIS batch's Source pointers (task-000001a1ea32 closeout §b/§passing,
2026-11-08 §f.24, papdashboard journal-noise row). The prior fire's own §f list (footer commit b4d360f91 +
closeout 2736f1cc5) diffed against queue surfaces: every minted row it named exists (mr-sync serve-stale,
float/deploy, WARN-quiet, buffer-inventory, Health-Hub semantics). No un-landed follow-ups found; the one
new obligation this fire minted is recorded inline in the item-5 row (owner-run enumeration) rather than
as a separate queue row, because it IS the item's own remainder.

## Follow-ups minted this fire

None as new rows: the item-5 remainder is the row itself (retagged, not split), and the nested-yolo sudo
death is recorded in AGENTS.md (supersedes, doesn't open work — the TODO_LIST NNP row is already closed
with its own dated datapoint chain).
