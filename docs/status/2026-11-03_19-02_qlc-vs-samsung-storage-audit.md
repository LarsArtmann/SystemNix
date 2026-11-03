# QLC vs Samsung Storage Audit — Full Status

**2026-11-03 19:02 CET · session: storage audit + doc repairs + harvest**
**Tree at authoring:** HEAD `85e4aaf09` (daemon-swept); my doc edits in `248c26be3` + working tree (AGENTS.md, TODO_LIST.md, docs/todo/{storage,services}.md).

**Scope line — VERIFIED here (command → result):**

- Topology: `lsblk` + `findmnt -t btrfs` — Samsung 970 EVO Plus (nvme0n1) holds `/nix`, `/mnt/hot` (+ all hot subvols), `/boot-mirror`, `~/.cache/nix`, `~/projects`; Lexar QLC (nvme1n1) holds `/`, `/data`, ClickHouse XFS, `/boot`, `@cache-home`, `@home-hermes`.
- Usage: `df -h` — Samsung fs 588G/928G (65%); QLC root 580G/723G (83%); `/data` 657G/1.1T (65%); ClickHouse 39G/100G.
- Storm check: `pgrep -af 'btrfs (balance|scrub)|btrbk' | scripts/redact-argv.sh` — empty; all walks ran `ionice -c3 nice -n19 timeout` (§d1 rule).
- Size walks (idle-priority du): `/data` md1, `/mnt/hot` md2, `/home/lars -x` md1, `~/.cache -x` md1, `/nix`.
- Snapshots: `ls` on `/mnt/btrfs-root/.snapshots`, `.rescue`, `/data/.snapshots` — root 3 dailies + rescue 2 (+2 known zz-test fixtures), hermes 3 dailies, `/data` dailies current through 2026-11-02 23:30.
- btrbk-data state: `journalctl -u btrbk-data --since 2026-11-02` — nightly send DELIBERATELY SKIPPED by the EIO repair gate ("remove the gate after the T04-T08 repair"); `/data/.repair-done` absent (probe: `ls`).
- gcs-staging evidence: `ls -la` + newest-file `find` + file count — 2 subtrees, 98,718 files, newest 2026-10-01 02:22.
- Doc/row cross-reads: docs/agents/storage.md, AGENTS.md, TODO_LIST.md, docs/todo/{storage,services}.md, `_signoz-alerts.nix` (rg).

**Scope line — NOT verified here (and why):**

- `/home/hermes` size — `drwx------ hermes:hermes`, sudo blocked at the agent-tool level ("command is not allowed"). du read `0` = permission artifact.
- `/data/docker` contents + true size — agent-side `du`/`ls` PERMISSION-BLIND (`drwx--x--- root root`, documented); figures cited are the 2026-09-30 `docker system df` from docs.
- Root-owned `/var/lib` trees — my `/var -x` walk read 3.9G, but `/var/lib/monitor365-server` alone is ~39G (T04 rsync measured a 39.21 GB pool delta) and is invisible to a lars-side du. Root-fs real usage is therefore HIGHER than the 580G walk decomposition suggests.
- Exclusive-vs-shared extents — all du figures are LOGICAL (CoW-shared with snapshots double-count); no compsize pass.
- The 6× `~/.cache` gap attribution — 119G today vs "~20G" on 10-28: regrowth vs walk-miss not discriminated (triage row queued).
- Steam `compatdata` 2.5G, Samsung SMART — carried from docs (existing owner row for SMART), not re-probed.

---

## Owner questions answered (mid-session)

**1. What is `gcs-staging/`?**
Two finished one-off staging trees from the private-cloud/paperless merge work: `paperless-merge/` (paperless export2 + `run-import.sh`) and `private-cloud-v1-2026-09-29/`. 98,718 files, 24G, newest file 2026-10-01 02:22 — **33 days untouched**. Looks reclaimable once you confirm the merge landed in paperless; deletion frees 24G but /data extents stay pinned ~4-5w by the snapshot window. Evidence stamped into the standing decision row (docs/todo/storage.md, TODO_LIST.md:48).

**2. What is in `docker/`? Did we back up the important files to the HDD?**
Contents (per the last `docker system df`, 2026-09-30): images 5.6G (re-pullable) + volumes 4.8G — the volumes **may hold the pre-cutover Twenty DB**, the only potentially-unique data (owner reclaim decision pending, docs/todo/services.md). Agent-side inspection is permission-blind, so this is doc-sourced, not fresh.
Backup answer: **NO current HDD-pool copy of /data.** btrbk-data has been deliberately skipped nightly by the EIO repair gate since the corruption discovery (journal 2026-11-02 23:30: "nightly pool send deliberately SKIPPED (known /data EIO)… This failure is the tripwire"; `/mnt/pool/backups/data` has zero received backups since 2026-08-20). What DOES exist: local `/data` snapshots daily through 2026-11-02 (14d+4w retention, same-disk), and the one safety copy that mattered most — the monitor365 DuckDB — was rsync'd to the pool archive 2026-10-22 (T04, owner-run, 39.21 GB verified). The 10 corrupt files blocking the pool send are all re-downloadable AI models awaiting the T06a sign-off sequence.

**3. Placement confirmations (all already true, no change needed):**
- **ClickHouse stays on QLC** — it is on QLC (dedicated XFS p9). Your directive RETIRES the standing relocation row ("relocate ClickHouse onto the Samsung", storage.md + TODO_LIST) — both stamped RETIRED 2026-11-03 (owner directive). Boot-storm mitigations remain the active levers.
- **`/boot` stays on QLC, Samsung mirror-only** — matches live: canonical `/boot` is QLC p7 (NixOS-managed), Samsung p1 is the verified byte-mirror (boot-order-first, path unit re-syncs after every gen-install).
- **AI models stay on QLC** — they are: `/data` (p8) holds `ai/` 543G. Your follow-on idea (better mount name / file layout / possibly different FS) is queued as a design-doc decision row.

---

## a) FULLY DONE

| Item | Evidence |
|---|---|
| QLC-vs-Samsung comparison delivered (sizes per tree, both disks) | du walks + df, figures in this report + session answer |
| `~/.cache` true size measured after the automount-stub miss | `du -x` 119G (glac-fleet 25G, m365fix 22G, cv-go 19G, vra-gocache 8G, negative-test-lints.PR7oGL 6.4G, ds-gate 4.9G, `.Trash-1000` 4.8G) |
| storage.md stale claims fixed: `~/projects`-in-`@` row → Samsung subvol + Phase F note; `@cache-home` "~16G" → ~126G (2026-11-03 probe); layout paragraph gains the projects-subvol clause | edits in `248c26be3` (daemon), verified by rg |
| New gotcha documented: `du -x` silently skips idle automount stubs (autofs `st_dev` differs) | storage.md gotchas bullet, 2026-11-03 |
| AGENTS.md `/data` composition refreshed (2026-09-06 → 2026-11-03 probe): ai 543G / models 28G / SteamLibrary 107G / gcs-staging 24G / llamacpp-models ~0 / docker 10.3G + permission-blind note | edit applied this session (working tree) |
| gcs-staging staleness evidence gathered (the pending TODO_LIST row) | 2 subtrees / 98,718 files / newest 2026-10-01; row ticked DONE with pointer |
| ClickHouse relocation row RETIRED on both surfaces per owner directive | storage.md row 156 + TODO_LIST row 1392 stamped |
| crush-hot-db retention row updated with today's 73G tree measurement | storage.md row 169 UPDATE stamp |
| Self-harvest: 5 new rows + 3 UPDATE stamps + 1 tick + 1 retirement landed in TODO_LIST + domain libraries | `check-todo-system.sh`: "OK: TODO queue/library structure clean" |

## b) PARTIALLY DONE

1. **Storage comparison** — topology + sizes delivered; open: hermes/docker true sizes (root-only), exclusive-extent split (compsize), `/var/lib` root-owned trees. Blocker: agent-side sudo. Effort: S for owner, M for compsize.
2. **Doc repairs** — storage.md/AGENTS.md figures now current; not yet committed by the daemon at authoring time (AGENTS.md + TODO + services rows are in the working tree). Risk: another daemon sweep or parallel session could interleave; content-pinned before edits.
3. **Phase F (projects cutover closure)** — burn-in day 6 of ≥7; the ~137G QLC shadow + root-snapshot pins remain until cleanup. Blocked on burn-in clock + owner go. Effort: M.
4. **gcs-staging decision** — evidence complete; the reclaim itself waits on your confirm-the-merge call. Effort: S.

## c) NOT STARTED

- `/data` FS/layout/mount-name design doc (your directive; decision row queued).
- Root-fs per-folder 1-by-1 review wave (your directive; queued, starting `.local` 34G / `.config` 15G / `go` 13G / `.gotmp` 6.4G).
- `~/.cache` regrowth triage (writer identification + purge; queued).
- journald retention check vs 7.8G Samsung journal (queued).
- dnsblockd growth check (8.5G hot subvol, +3.7G since 10-14; queued in services.md).
- T04→T09 /data corruption repair chain (existing P0 row; root-only + sign-off gated).
- crush/ retention policy decision (existing row, now scoped to the full 73G tree).

## d) TOTALLY FUCKED UP

1. **`~/.cache` = 119G of unmanaged per-project cache on the 83%-full, snapshot-pinned QLC** — 6× the 10-28 "~20G" reading; root fs grew +126G in 6 days; no GC loop, no metric, no alert on this surface (alerts exist for `/data` 85%/90% and buildcache, NOT `@cache-home`). `negative-test-lints.PR7oGL` (6.4G) is literally one test-run's residue. Severity: capacity trend toward the ENOSPC cliff class; unattributed growth is the 10-11 "+76G/17h burst" pattern repeating one mount over. Root cause: per-run GOCACHE-style dirs written by project tooling, never pruned. Mitigation: purge is instant (`@cache-home` unsnapshotted); triage row queued.
2. **The `du -x` automount blind spot nearly shipped a wrong report** — my first `/home/lars` walk read 94G while truth was ~213G; caught only because `.cache` was suspiciously absent from the top-20. Any agent re-running that pattern gets the same silent under-report. Documented in storage.md today; ledger tooling decision row is the structural fix.
3. **/data has NO current off-box backup** — the pool send has been dead-by-design since July's EIO discovery; the only copies of everything on /data (543G AI models incl. likely-unique trained/LoRA trees, Steam saves, staging) are local same-disk snapshots. Tracked as P0, but it is an ACTIVE single-chassis exposure, not a footnote. (2026-10-22 T04 closed the one flagged-unique hole: monitor365 DuckDB.)
4. **Core-doc state figures rotted silently** — storage.md's `@cache-home` "~16G" understated reality 8×, its `~/projects`-in-`@` claim was 12 days stale, AGENTS.md's `/data` composition was 58 days stale with wrong dir names (`Steam` vs `SteamLibrary`, 210G models now 28G). All fixed today; the class is "state paragraphs without probe dates in the need-to-know docs".

## e) WHAT WE SHOULD IMPROVE

1. **df-crosscheck before quoting**: every du walk's total gets arithmetic-checked against `df used` before it enters an answer (this is what caught the `.cache` miss).
2. **Per-child throttled-du helper** (existing decision row): today's five walks hand-rolled the budgets; a helper would make ledger refreshes a one-command falsifiable artifact — pair it with the machine-readable du -sb baseline row.
3. **Observability gap**: add `@cache-home` usage (+ Trash) to a textfile collector/Gatus tier — the only big QLC consumer with zero alerting today.
4. **Probe-date discipline for AGENTS.md/storage.md size claims** — composition lines now carry "(YYYY-MM-DD probe)"; keep that pattern mandatory for any figure that can drift.
5. **Automount-aware walk pattern**: trigger the mount (`du -sh <mnt>`) before any `-x` walk; candidate for a scripts/lib guard or shell-func wrapper so the trap dies at tooling level, not memory level.

## f) Up to 50 things to get done next (ranked by impact; routing tagged)

**HARVESTED at authoring time → TODO_LIST + library** (1–5):
1. Triage `~/.cache` regrowth: identify the per-project GOCACHE writer workflow, purge stale dirs, decide redirect-to-buildcache vs gc leg — Impact: Critical, Effort: M, Cleanup. *(queued)*
2. Root-fs per-folder 1-by-1 review wave (`.local` 34G Trash-share, `.config` 15G, `go` 13G vs "nothing churning" claim, `.gotmp` 6.4G regrowth) — Impact: High, Effort: M, Cleanup. *(queued)*
3. Verify journald retention vs the 7.8G Samsung journal subvol — Impact: Medium, Effort: S, Quality. *(queued)*
4. Owner decision: `/data` filesystem/layout/mount-name redesign design doc — Impact: High, Effort: L, Feature. *(queued, decision)*
5. dnsblockd growth sanity check (8.5G hot subvol, +3.7G/3w) — Impact: Medium, Effort: S, Bug-candidate. *(queued in services.md)*

**Owner decisions pending (evidence ready):**
6. gcs-staging (24G): confirm the paperless merge landed → trash — Impact: Medium, Effort: S, Cleanup.
7. crush/ 73G retention policy (cap + prune vs accept) — Impact: Medium, Effort: M, Decision.
8. `/data/docker` reclaim ( Twenty-DB volume check needs root inventory) — Impact: Medium, Effort: S, Decision.
9. ollama 15G reclaim (dormant tree, existing row) — Impact: Medium, Effort: S, Cleanup.
10. Phase F go/no-go: schedule the ~137G QLC shadow reclaim when burn-in ends (~11-04/05) — Impact: Critical, Effort: M, Cleanup.

**Existing tracked rows this audit re-confirms as live/urgent:**
11. T04→T09 /data corruption repair chain (unblocks the ONLY pool backup of /data) — Impact: Critical, Effort: L, Bug.
12. btrbk-forgejo stray receive target heal — Impact: Medium, Effort: S, Bug.
13. btrbk-projects nightly ladder green verify (first days post-cutover) — Impact: High, Effort: S, Verification.
14. D6 boot proof for the projects subvol (`pre-reboot-check` + owner-present reboot) — Impact: High, Effort: S, Verification.
15. QLC-root PSI baseline after the projects cutover (the storm-engine hypothesis test) — Impact: Medium, Effort: M, Quality.
16. Machine-readable du -sb baseline artifact for the /data watch — Impact: Medium, Effort: S, Quality.
17. /data watch MB-grain re-verification — Impact: Low, Effort: S, Verification.
18. Hot-db shadow soak-end reclaims (dnsblockd 4.82G QLC original + gatus/browser-history/pocket-id shadows) — Impact: Medium, Effort: S, Cleanup.
19. Samsung SMART owner check post-reseat/heatsink — Impact: Medium, Effort: S, Verification.
20. Post-EIO-repair btrbk-data `memory.peak` ≤4G proof — Impact: Low, Effort: S, Verification.
21. Ledger tooling decision: per-child throttled-du helper vs collector surface — Impact: Medium, Effort: M, Tooling.

**New observations from this session (not yet queued):**
22. compsize pass over `/data`, root `@`, `/mnt/hot` for true shared-vs-exclusive splits (all today's figures are logical; snapshot-pin math inherits the fuzz) — Impact: Medium, Effort: M, Quality.
23. Add `@cache-home` usage + Trash size to textfile metrics/Gatus (closing the only unalerted QLC consumer) — Impact: High, Effort: S, Monitoring.
24. `/data/tmp-bench` + `/data/cache` + `/data/containers`: verify empty/owner, delete known residue (0-readings may be perm artifacts; containers is root-owned) — Impact: Low, Effort: S, Cleanup.
25. `negative-test-lints.PR7oGL` (6.4G): one-off test residue, purge + consider a run-dir cleanup flag in the harness — Impact: Low, Effort: S, Cleanup.
26. glac-fleet/m365fix activity check: are these projects live? If dead, their 47G of cache dies with item 1 — Impact: Medium, Effort: S, Cleanup.
27. Samsung free-space policy: 326G free at 65% with `/nix` at 449G and growing — set a watch threshold (Gatus row exists for mount presence; usage alert level unreviewed) — Impact: Medium, Effort: S, Monitoring.
28. Automount-aware walk guard: a `scripts/lib` wrapper or documented pattern so `du -x` walks pre-trigger automount stubs — Impact: Medium, Effort: S, Tooling.
29. `/var/lib` root-owned tree visibility: monitor365-server ~39G is invisible to agent du; consider a root-run textfile collector for `/var/lib` top consumers — Impact: Medium, Effort: M, Monitoring.
30. verify `/data/.Trash-1000` emptiness (0-read artifact?) — Impact: Low, Effort: S, Verification.
31. Steam `compatdata` 2.5G re-probe (AGENTS.md claim carried from 2026-09-06) — Impact: Low, Effort: S, Verification.
32. Docker-size doc conflict (AGENTS.md 15.5G@09-25 vs storage.md 10.3G@09-30): fold the newer figure everywhere at the next touch — Impact: Low, Effort: S, Documentation. *(AGENTS.md now carries the 09-30 figure)*
33. hermes subvol size unknown (perm-walled): fold into the owner-probe batch (question g.2) — Impact: Low, Effort: S, Verification.
34. `.rescue/zz-test-*` fixture deletion needs the designed chattr -a cycle or a module-owned cleanup path (existing row documents the EPERM) — Impact: Low, Effort: S, Cleanup.
35. Re-verify `~/go` composition (13G) against storage.md's "nothing churning" claim — covered by item 2, listed for visibility — Impact: Medium, Effort: S, Verification.
36. Consider per-project `.cache` GC legs in the tq pool teardown (if the writer is tq/session tooling, purge at session close) — Impact: High, Effort: M, Tooling. *(feeds item 1)*

(Rows 22–36: deliberately NOT harvested as queue rows yet — 22/23/27/28/29/36 graduate to the queue on your nod or at the next docs-health pass; the rest are sub-S verifications folded into items 1–2 scope.)

## g) Questions I cannot answer myself

1. **Phase F go/no-go** — burn-in (started 2026-10-28) completes ~2026-11-04/05. Do you want the shadow-cleanup + QLC reclaim (~137G, root-snapshot pin window 3d) executed right after burn-in, or do you want to re-verify parity yourself first?
2. **Root-only probes** — agent shells cannot sudo: (a) `/home/hermes` true size, (b) `/data/docker` inventory (is the Twenty DB in volumes? → reclaim verdict), (c) Samsung SMART post-reseat check (existing row). Want to run these, or should I prepare a one-shot owner script with the exact commands?
3. **`/data` redesign priority** — for the design doc: which constraint outranks the others — (a) keeping btrbk CoW snapshot/backup semantics (pool sends depend on btrfs), (b) model-load latency (the QLC's weakness), (c) mount-name/layout clarity? And is a filesystem change genuinely on the table given it would sever the /data→pool btrbk pipeline?

---

### Self-harvest ledger (AGENTS.md TODO-system obligation)

- Harvested this session: items 1–5 above → TODO_LIST.md (storage + services sections) + docs/todo/storage.md + docs/todo/services.md; gcs-staging evidence row TICKED (TODO_LIST) + decision rows UPDATED on both surfaces; ClickHouse relocation RETIRED on both surfaces (owner directive); crush-hot-db row UPDATED; root-ledger row UPDATE-stamped.
- Deliberately not harvested: items 22–36 (brainstorm/verification-grain — ROUTMAP-fuel or sub-S items folded into harvested scope); items 6–20 are pre-existing tracked rows this report re-confirms (no duplicate rows created per the no-duplication rule).

### Multi-agent note

The auto-commit daemon swept my storage.md fixes mid-session (`248c26be3`); a parallel session committed flake changes (`85e4aaf09`) and holds uncommitted `flake/parts/checks/lint-static.nix` + `lib/lars-packages.nix` — not mine, untouched, flagged per the shared-tree discipline.

_Arte in Aeternum_
