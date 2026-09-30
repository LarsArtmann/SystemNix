# Status Report — QLC prune backlog, btrbk kill-streak, pool catch-up gap

**Date:** 2026-09-30 04:37 CEST
**Session scope:** user Q&A on snapshot offload to the HDD pool, QLC space waste, docker volume doctrine; diagnosis of the 2026-09-26..29 btrbk-root kill streak; AGENTS.md + docs/todo/storage.md updates; docker-volume reclaimable correction.
**Format note:** skill default is styled HTML; user explicitly requested `.md` — honored (one-off override, not propagated).

---

## Session narrative (what actually happened)

1. **Q: "Are we moving them off to the HDD pool?"** — Verified the design and live state: yes, nightly `btrbk-root` sends every local `@`/`@home-hermes` snapshot to `/mnt/pool/backups/root` (root receives kept FOREVER, hermes 14d/4w). Live evidence: pool `@` receives current through **0927**, hermes stuck at **0925**; last night's run was SIGTERM'd at 23:09:57 mid-`btrfs receive` by memory-emergency-guard **zone-6 trip #1441** (io PSI some avg60 50.16%, disk busy 99.2%). The aborted 0928 receive left **no garbled subvol** (ls-verified).
2. **Kill streak found:** `journalctl -u btrbk-root` shows 4 consecutive killed runs — 09-26/27/28 died ~1 min in, 09-29 died 23:09:57 mid-catch-up. Prune runs AFTER sends in btrbk, so **12 expired local snapshots** are still alive past their windows: `@.20260913` weekly + `@` dailies 0922–0926, `@home-hermes.20260916` weekly + hermes dailies 0922–0926. This set pins the **~45G `.crush`-migration originals** (freed 09-16..18) plus ~2.5w of churn.
3. **Pool gate is red:** `btrfs-verify-pool-backups` FAILed 09-29 00:40 (`@` and hermes both 4d stale, threshold 3). Hermes (~5d) presumably still failing today — today's verify run was NOT re-checked (session gap, listed in b/c).
4. **Q: "We waste space on the QLC"** — Surveyed: root fs 91% (635G/723G, 68G free), `/data` 76% (775G/1.1T, retention healthy — the EIO gate still snapshots + prunes nightly, only the pool send is skipped), ClickHouse on its own 100G XFS (33G), `/data/.Trash-1000` 0, `/nix` on Samsung (121G/928G). Root-fs waste = the prune backlog + the 10G deliberate emergency reserve.
5. **Correction (user):** I mislabeled 4.6G of docker volumes as "reclaimable" — WRONG per house doctrine (volumes are real data, deliberately never auto-pruned; "reclaimable" only means no running container mounts them). Fixed the claim in-chat and fixed two stale spots in AGENTS.md (snapshot-pinning table row + docker-prune bullet).
6. **Doc updates landed:** AGENTS.md snapshot-deferral lesson (prune runs after sends; kill streak documented); storage.md row-17 UPDATE (escape condition fired, mechanism found, retention doctrine NOT falsified); new storage.md [watch] row for the kill streak/backlog/catch-up.
7. **Explained the compsize probe** (`nix build nixpkgs#compsize --print-out-paths` + sudo full-path run, why `sudo compsize` bare fails, ionice advice).

---

## a) FULLY DONE

| Item | Evidence |
|---|---|
| Root-cause the "snapshots not moving to pool" question — 4-kill streak + zone-6 trip #1441 identified with exact timestamps | `journalctl -u btrbk-root --since 2026-09-24` (09-26 23:01:22, 09-27 23:00:13, 09-28 23:00:15 `Failed with result 'signal'`; 09-29 23:09:57 mid-`btrfs send -p @.20260927 @.20260928`); `journalctl -t memory-emergency-guard-check` 23:09:56/57 trip #1441 |
| Pool-side state pinned: `@` through 0927 (39 receives), hermes through 0925, no garbled 0928 target | `ls /mnt/pool/backups/root/` grep/tail verified |
| Local expired set enumerated: 12 subvols (2 weeklies + 10 dailies across `@`/hermes) | user's `btrfs subvolume list /` paste + retention math (calendar-anchored 2w/3d) |
| `/data` retention confirmed HEALTHY (not a waste source) — repair gate takes snapshot + prune, skips only the send | snapshots.nix:140–183 (`btrbkDataGate`), journal 09-29 23:30:00 `+++ /data/.snapshots/data.20260929T2330` |
| Docker volumes doctrine correction — claim retracted in-chat, AGENTS.md table row (docker system df 2026-09-30: ~10.3G total, images-only reclaimable ~3.4G) + docker-prune bullet fixed | AGENTS.md line ~716 (table) + ~1044 (bullet), live `docker system df` |
| AGENTS.md prune-after-sends deferral lesson (kill streak → prune backlog) | AGENTS.md ~line 705, Snapshots bullet |
| storage.md row-17 UPDATE (predicted prunes did NOT run; escape condition fired; doctrine NOT falsified) | docs/todo/storage.md row 17 |
| storage.md NEW [watch] row: prune backlog + pool catch-up after the 4-kill streak, incl. DO-NOT-hand-delete warning (hermes 0926–0929 + `@` 0928/0929 are the unsent incremental chain) | docs/todo/storage.md tail row |
| Verified the btrbk /data gate's implementation (snapshot + prune legs, `/data/.repair-done` marker, cheap-fail design) | snapshots.nix:159–183 read in full |
| Explained the compsize probe mechanics + sudo secure-PATH trap + IO-weight caveat | chat (user-question answer) |

## b) PARTIALLY DONE

| Item | Works | Missing | Blocker |
|---|---|---|---|
| QLC waste quantification | Mechanism fully diagnosed; df surveyed (root 635G used / 68G free / 91%) | Actual pinned-bytes number (needs `compsize /` + `btrfs filesystem usage -T /` as root) | sudo blocked in agent sandbox — probe handed to user, no output yet |
| Tonight's self-heal prediction | Backlog release path fully documented (send 0927→0928→0929 + hermes 0925→…→0929, then one-pass prune) | Whether tonight's 23:00 run survives (catch-up slot bar 50% vs trips at 50.16% — missed by 0.16% last night) | Time + storm state; watch row filed |
| `btrfs-verify-pool-backups` today's verdict | 09-29 00:40 FAIL captured (both prefixes 4d) | Today's ~00:40 run result never re-checked (systemctl blocked, journal check window missed) | Sandbox; trivial re-check next session |
| Catch-up-slot / kill-streak design fix | Root cause + numbers documented in the watch row | No fix designed or landed (bar raise? reschedule? heavy-job wrap? prune-as-separate-unit?) | Owner decision — see §g Q1 |

## c) NOT STARTED

| Item | Why | Priority |
|---|---|---|
| Any scheduling change for btrbk-root (move hour / storm protection / separate prune unit) | Owner decision pending (§g Q1) | High once decided |
| Docker volume orphan inventory (221 inactive / 4.75G) | Owner decision pending (§g Q2); doctrine says never auto-prune | Medium |
| Hand-pruning the 12 pool-covered expired snapshots early | Owner decision pending (§g Q3); btrbk self-heals tonight | Medium |
| All pre-existing storage.md rows (Borg go-live gates, /data EIO T04-T08, hot-db vehicle defects, Caddy-logs-to-Samsung, 7d GC retention verify, …) | Out of session scope per user instruction; listed in §f as restatements | see storage.md |

## d) TOTALLY FUCKED UP

| What | Severity | Root cause | Mitigation |
|---|---|---|---|
| **My claim "docker volumes 4.6G reclaimable" was wrong.** House doctrine (in my context verbatim) says volumes are real data, deliberately never auto-pruned. A user acting on my summary could have planned volume deletion as space recovery. | Medium (misleading guidance; no data touched) | I summarized `docker system df` output instead of applying the doctrine to my own wording — the exact "challenge tool output" rule I'm required to apply | Corrected in-chat + both stale AGENTS.md spots fixed (2026-09-30); lesson now explicit in the bullet text |
| **System: 4 consecutive killed btrbk-root runs** → prune backlog (12 expired subvols pinning churn incl. ~45G `.crush` originals) + pool gap (@ missing 0928/0929, hermes missing 0926–0929) + `btrfs-verify-pool-backups` FAIL (OnFailure fired 09-29 00:40). Root fs at 91%, ~34G above the 95% deploy gate. | High (backup freshness gate red; deploy headroom shrinking) | Zone-6 trips fire at ~23:0x exactly when the run executes; catch-up slot bar (io avg60 <50%) sits ON the observed trip level (50.16%) | Self-heals on the first successful 23:00 run; fallback = manual run in quiet window; decision pending (§g Q1) |
| **System (pre-existing, re-observed): reboot owed** — freeze-#5/#6 recovery items (llama-rag disabled, flm corpse pinning :52626, D-state corpses) still unresolved; `journalctl -t memory-emergency-guard-check` 23:19:59 shows "restore capped (3 restores today)" — flm socket still DOWN. | High (flm dark for consumers; corpses only clear on reboot) | Staged v1.0.3 go-live is the candidate fix; reboot is owner-gated | `nix run .#pre-reboot-check` before any planned reboot (house rule) |

## e) WHAT WE SHOULD IMPROVE

1. **Guard-vs-backup collision design:** the backup catch-up slot bar (50% io avg60) is calibrated exactly AT the storm trip level (50.16% trip). Either raise the bar, move the backup window out of the 23:0x trip zone, or protect btrbk-root like the catch-up slot does but with a lower threshold. Impact: every multi-day storm currently starves backups AND defers prunes. (Owner call — §g Q1.)
2. **Prune starvation is structural:** btrbk prunes after ALL backup actions, so any kill mid-send defers prune indefinitely during kill streaks. A lightweight separate `btrbk prune` unit (or prune-first for already-pool-covered snapshots) would decouple space reclamation from send success. (Design idea — needs a small decision.)
3. **journalctl grep vocabulary:** my `grep -iE "deleting|prune"` found nothing because btrbk's deletes surface as sudo COMMAND lines (`btrfs subvolume delete …`), i.e. the word `delete`, not `deleting`. Match the actual log vocabulary, not your mental model of it — cost one near-misdiagnosis this session.
4. **Blocked-surface awareness:** burned probes on `sudo` and `systemctl` (both blocked in agent sessions) before checking the house docs. Check the known sandbox surface first when planning probes.
5. **Summarize state, don't soften it:** my first answer said "no action needed" while the pool verify gate was already FAILing (discovered three probes later). Lead with the red gates.
6. **Compsize probe hygiene:** use `--no-link` from the start (avoids the `./result` symlink side effect) — mentioned only when asked.

## f) Up to 50 things we should get done next

Ranked by impact. Harvest status marked per item (this session's rule: §f follow-ups are either already harvested, already existing rows, or deliberately not harvested with reason).

| # | Task | Impact | Effort | Category | Harvest status |
|---|---|---|---|---|---|
| 1 | Verify tonight's (09-30 23:00) btrbk-root run: 0928/0929 + hermes backlog sent, 12 expired subvols pruned, Deleting lines in journal | Critical | S | Ops | **Harvested this session** (storage.md [watch] row) |
| 2 | If tonight is killed again: start btrbk-root in a quiet window (sudo; check `journalctl -t memory-emergency-guard-check` first) | Critical | S | Ops | Harvested (same row) |
| 3 | Confirm `btrfs-verify-pool-backups` returns green after a hermes send lands (check today's 00:40 result too) | High | S | Ops | Harvested (same row) |
| 4 | Run the quantification probe: `sudo btrfs filesystem usage -T /` + `sudo ionice -c 3 "$p/bin/compsize" /` in a quiet window; record pinned-bytes figure | High | S | Ops | Delivered to user; awaiting output |
| 5 | Decide btrbk-root storm policy: move hour / raise catch-up bar / separate prune unit (§g Q1) | High | M | Decision | **Not harvested — pending §g Q1** |
| 6 | Decide: hand-prune the 12 pool-covered expired snapshots now vs wait for btrbk (§g Q3) | Medium | S | Decision | Not harvested — pending §g Q3 |
| 7 | Decide: docker volume orphan inventory (name + dangling-since report, owner-only deletion) vs doctrine stands unaudited (§g Q2) | Medium | M | Decision | Not harvested — pending §g Q2 |
| 8 | `nix run .#pre-reboot-check` then schedule the OWED reboot (flm corpse :52626, D-state corpses, llama-rag escape already fired) | High | M | Ops | Pre-existing (AGENTS.md flm/llama-rag sections) |
| 9 | /data EIO repair T04-T08 (P0): unblocks btrbk-data pool send + Borg path check + removes the repair gate | High | L | Bug | Pre-existing (docs/todo/storage.md P0 rows) |
| 10 | Offsite Borg go-live (owner inputs: StorageBox host/user + host-key pin), then real-repo drill | High | M | Feature | Pre-existing (storage.md [blocked:user] rows) |
| 11 | Land + verify the 7d GC retention change (deploy pending, generations being lost daily) | Medium | S | Ops | Pre-existing (storage.md [blocked:deploy]) |
| 12 | Journal-hot soak end: run `nix run .#pre-reboot-check` + reboot, then QLC shadow-dir cleanup decision | Medium | S | Ops | Pre-existing (storage.md [blocked:user]) |
| 13 | Caddy access logs → Samsung sibling subvol (1.6G, journal-hot pattern minus journald edge) | Medium | M | Feature | Pre-existing (storage.md [ready]) |
| 14 | Fix the 4 hot-db vehicle defects (prepare gate, finalize verification, dry-run crash, timer-stop window) | Medium | M | Bug | Pre-existing (storage.md [ready]) |
| 15 | Watch item: predicted weekly prune confirmations (row-17 [watch], now UPDATED with fired escape — close it when the backlog prunes) | Low | S | Verification | Harvested (row updated this session) |
| 16 | Pool-side hermes weekly prune watch (~mid-Oct, first ever) | Low | S | Verification | Pre-existing (storage.md row 18) |
| 17 | Decide explicit `snapshot_preserve` on @home-hermes block vs documented inheritance | Low | S | Decision | Pre-existing (storage.md [decision]) |
| 18 | Decide btrbk `transaction_log` persistence (retention-bounded) for prune/send forensics | Low | M | Decision | Pre-existing (storage.md [decision]) |
| 19 | Decide borgbackup-job-hetzner membership in Zone-6 ioChurnUnits | Medium | S | Decision | Pre-existing (storage.md [decision]) |
| 20 | Decide offsite repo append-only posture (restricted key + append-only) BEFORE first seed | Medium | S | Decision | Pre-existing (storage.md [decision]) |
| 21 | Decide replacement-host borg_known_hosts re-pin derivation (keyscan vs console pin) | Low | S | Decision | Pre-existing (storage.md [decision]) |
| 22 | Verify no clickhouse-migration shadowed originals remain under the root-fs mountpoint (bind-view/compsize on `@`) | Medium | M | Cleanup | Pre-existing (storage.md [ready]) |
| 23 | Decide trash-purge policy for `/data/.Trash-1000` (bless "leave it" permanently) | Low | S | Decision | Pre-existing (storage.md [decision]) |
| 24 | Add grep-gate for stale root-window restatements (`3d+1w`, `1-2w` live contexts) | Low | M | Quality | Pre-existing (storage.md [ready]) |
| 25 | Inventory docs/services/* runbooks for drift-prone operational figures (pin windows, retention) | Low | M | Documentation | Pre-existing (storage.md [ready]) |
| 26 | Cross-link the single-victim /data repair recipe from the AGENTS.md BTRFS section (discoverability) | Low | S | Documentation | Pre-existing (storage.md [ready]) |
| 27 | Reword the stale "deploy-pending" clause in the f2-era symlink-sweep row | Low | S | Documentation | Pre-existing (storage.md [ready]) |
| 28 | Measure /nix growth after ~1 week of 7d retention (Samsung, shared with hot tier) | Low | S | Verification | Pre-existing (storage.md [watch]) |
| 29 | Decide user/HM profile retention depth (root GC run applied 7d to all profiles) | Low | S | Decision | Pre-existing (storage.md [decision]) |
| 30 | After tonight's prune lands: re-run `compsize` diff and record the actual backlog release figure in the watch row | Medium | S | Verification | New, small — fold into item 1's verification (part of harvested row) |
| 31 | If catch-up slot keeps missing by <1%: consider logging the slot-bar delta on each kill for calibration data | Low | S | Quality | Not harvested — cosmetic until Q1 decides the policy |
| 32 | Optional: teach the AGENTS.md journal gotcha section the "grep the log's actual vocabulary" lesson (delete vs deleting) | Low | S | Documentation | Not harvested — single-occurrence diagnostic wobble, no recurrence evidence yet |

(32 items; the remaining headroom to 50 is deliberately unused — everything beyond this point is already tracked in docs/todo/storage.md and would be duplication, not new signal.)

## g) Up to 3 questions I can NOT figure out myself

1. **btrbk storm policy:** Zone-6 trips keep killing the 23:00 run (4 nights straight), and the backup catch-up slot bar (io avg60 <50%) missed by 0.16% last night. Do you want (a) the run moved out of the trip-prone window (e.g. early morning), (b) the catch-up slot bar raised so storms still grant backup slots, (c) a separate always-safe prune leg, or (d) current design stands and you'll manually run btrbk-root after multi-night storms?
2. **Docker volumes (221 inactive / 4.75G):** doctrine says never auto-prune. Do you want a one-time orphan inventory (volume name + last-used-by + dangling-since) as an owner-decision report, or does the doctrine stand without an audit?
3. **Space timing:** the 12 expired snapshots are all pool-covered and hand-deletable today (typed-`delete` fish guard + sudo, quiet window), which would reclaim the pinned churn ~18h before btrbk's own run — strictly wait for the self-heal, or prune early for deploy headroom (root is at 91%, gate at 95%)?

---

**Self-harvest statement:** session follow-ups were harvested at discovery time (storage.md row-17 UPDATE + new [watch] row + AGENTS.md edits). §f items 5–7 are decision-gated on §g answers (deliberately not harvested pending owner input); all other items are pre-existing tracked rows restated for this snapshot. `scripts/check-todo-system.sh` passes post-edit ("TODO queue/library structure clean").
