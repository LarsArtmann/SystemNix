# 2026-10-23 Session: T04 Executed + Verified, the IO Storm's Driver Unmasked (InboxClean), Self-Review

**Session window:** 2026-10-23 ~03:30–06:37 CEST (probes 04:12–04:30, authoring 06:37)
**Session lane:** BTRFS health question → repair plan → T04 safety copy (owner-executed, agent-verified) → "what next" → storm-driver diagnosis (inboxclean-web) → this self-review.
**Prior episodes of this conversation:** `2026-10-21_03-30_health-notifications-review.md` + `2026-10-22_02-16_health-notifications-review-self-review.md`.
**Concurrent session acknowledged:** `2026-10-23_01-09_monitor365-db-io-diagnosis-self-review.md` (their rows landed in storage.md tail + a monitor365 fixture commit; overlap reconciled in §e/f — no conflicts found in my edit surfaces). Working tree carries an `M flake.lock` I did not author — left untouched per concurrent-edit discipline.

---

## a) FULLY DONE

1. **"What is the BTRFS health problem?" — decomposed with live evidence.** No NEW corruption: kernel journal since 2026-10-20 contains only the boot-time dev-stats census (nvme1n1p8 corrupt 386,583,705 — +86 over the freeze-22 reading 386,583,619; nvme0n1p2 corrupt 12; nvme1n1p6 corrupt 1), zero active btrfs error/csum/EIO lines. The situation = the documented bounded `/data` damage set + counter drift + monitoring noise (btrfs-compression.prom cadence, weekly scrub exit-3 by design).

2. **Resolution path laid out properly.** The ratified T04–T08 sequence as a gated table (storm quiescence → gate (b) scrub delta → T06a sign-off → delete 10 files → T09 seed ~1 day → T08 scrub-green ~4–5w), plus what-NOT-to-do (no scrub under storm, no delete before gate (b), no Trash-purge space expectations). Verified live that the scrub mechanism works: the Oct 19 00:00 fire DEFERRED correctly at IO PSI avg10=64% ("scrubbing under pressure froze the machine" classes) — so gate (b) is purely storm-blocked, not broken.

3. **T04 premise audit — the plan was stale and I caught it before execution.** T04 had never run (`/mnt/pool/archive/monitor365-nvme-safety/` absent), and its 54G/two-leg estimate was wrong: the 31G `/data/monitor365` leg moved pool-side 2026-08-18 (`data-to-pool-migration.service` → `/mnt/pool/services/monitor365`, monitor365.nix:56-66). Remaining leg: the DuckDB at `/var/lib/monitor365-server` (750 `monitor365-server:monitor365-server`, agent-unreadable — the /data/docker permission-blind class). Also established: the nightly backup wrapper exports INTO the same dir on the same NVMe — same-disk redundancy only.

4. **T04 EXECUTED and VERIFIED.** Owner ran `sudo rsync -a /var/lib/monitor365-server/ /mnt/pool/archive/monitor365-nvme-safety/` (33m57s), taken from the QUIESCED DB (server down in the pool-acquire wedge since 2026-10-21 03:10 — no lock/WAL in flight; cleanest possible window). Agent-side verification: dir present with rsync-preserved 750 + source mtime 2026-10-22 03:06:05; pool `node_filesystem_avail_bytes` 12,948.42 → 12,909.21 GB (**−39.21 GB**) across the copy window (SigNoz query_range). Recorded: `docs/todo/storage.md` P0 row annotated (T04 DONE + premise correction + evidence) and `docs/services/monitor365.md` runbook note added. `check-todo-system.sh`: structure clean.

5. **"What next" answered with a full attribution chain.** Live IO PSI some avg10 76.55% / full avg10 69.25% (storm WORSE than the 10-22 drift check). A 5-s `/proc/*/io` sampler caught only 0.09 GB — process-level enumeration is BLIND for this class; pivoted to the guard's own cgroup io.stat telemetry (the authoritative source, per the AGENTS.md live-probe doctrine): **trips #4106–#4109, zone 6, ~10-min cadence** (03:42/03:52/04:02/04:12), MemAvailable 61–62% healthy, heartbeat avg60 78–84%, top reader named every window: **inboxclean-web.service +16–26 GB/10 min** (system.slice aggregate +34–67 GB).

6. **The storm driver unmasked: inboxclean-web.** Cumulative cgroup io.stat: **3.28 TB read / 255,063,257 read-IOs on 259:3 (whole Lexar nvme1n1)**, only 21 MB written lifetime. Process started 19.35 s after the 2026-10-20 14:58 boot → ~2.4-day window → **~57 GB/h ≈ 16 MB/s sustained around the clock**. Its DB is a **1.5 GB SQLite** (`/var/lib/inboxclean/inboxclean.db`, root fs) → the entire DB is rescanned **~38×/hour (~every 95 s)**. Scale: forgejo (busy git server) read 562 GB in the same window — inboxclean read **6×**, with **47× the IO count** (avg ~13 KB/read = small-random full-scan signature). Mechanism in its journal: every poll of `/` runs "top senders all" + "paperless uploads summarize" queries that hit the ~5s context cancel (`context canceled` lines, request durations 4.998/5.104 s, client_ip = own IP = Caddy proxy front) and get re-polled — a cancel-retry scan loop running since boot. **The 2026-10-21 review's classification of InboxClean as storm-VICTIM ("recovered", 1.5–5 s latencies) is OVERTURNED: it is a primary DRIVER.**

7. **Guard blind-spot found.** The zone-6 action stops sockets + sacrifice units only — inboxclean-web is in NEITHER set, so the guard has tripped every 10 min for 2+ days without ever touching the actual reader. It fights the storm blind.

## b) PARTIALLY DONE

1. **T04:** copy landed and structurally verified; plan step 04f (file inventory + sha256 hashes) NOT done — contents root-only (750 preserved). Optional owner pass: `sudo sha256sum /mnt/pool/archive/monitor365-nvme-safety/monitor365.duckdb`.
2. **Gate (b):** mechanism proven alive (Oct 19 deferral), baseline 1,351,271 csum stands, but NO completed scrub yet — blocked solely by the storm.
3. **Driver diagnosis:** WHO polls `/` unverified — "gatus/dashboard via Caddy" was an attribution hypothesis, not a config-grep-verified fact (gatus check vs papdashboard tile vs open browser tab).
4. **Stop instruction delivered but UNHARDENED** (see §d.2): no check for an inboxclean socket unit, no check whether the memory-guard RESTORE branch re-arms a stopped inboxclean-web while memory is healthy (the documented 2026-09-09 flm behavior). A bare `systemctl stop` may not survive.
5. **Victim→driver correction:** stated in conversation; the 2026-10-21 report's §3/§7 text NOT yet amended in-source (row queued in §f).

## c) NOT STARTED (this session's lane; none executed)

1. Owner stop of inboxclean-web (pending go — question g.1).
2. Gate (b) scrub run + delta read.
3. T06a sign-off → 10-file deletion → T09 seed verify → T08 clock.
4. Guard sacrifice-set gap fix (config change).
5. InboxClean dashboard-query cost fix (upstream cache/index/limit).
6. Poller identification (config grep).
7. In-source amendment of the 10-21 review.
8. This report's harvest rows (landing with this authoring pass, per contract).

## d) TOTALLY FUCKED UP

1. **Device misattribution shipped, self-caught only under challenge.** First io.stat read named 259:3 "the /data device" — wrong: 259:3 is the WHOLE Lexar nvme1n1 (root fs + /data + ESP; this kernel rolls partition IO up to the parent devt). The `/sys/dev/block` resolution should have preceded the number, not followed the user's "WHAT?!". Same violation class as the repo's own rule: assert WHICH entity the evidence names — generalized now to devts (the smartd by-id trap, again).
2. **Unstable intervention recommended.** I delivered `sudo systemctl stop inboxclean-web.service` as THE next action without checking (a) whether a socket unit re-arms it and (b) whether the guard's RESTORE branch restarts it while memory is healthy — both documented live behaviors on this box (the 2026-09-09 flm corpse saga). The repo docs contained the precedent; I recommended as if a bare stop were durable. It may be undone within minutes.
3. **Attribution order inverted.** I built a custom `/proc/*/io` sampler BEFORE reading the guard's cgroup telemetry — the probe that ALREADY had per-window per-unit attribution. The sampler's near-zero result briefly framed the storm as "reclaim, not a bulk reader" in-session; the guard's io.stat windows corrected me within one step, but the order was backwards and wasted a probe cycle. This repeats the 10-22 self-review's own lesson ("use the repo's scripts first") in a new costume.
4. **(Inherited, flagged not fixed)** The 10-21 review parked the single biggest storm driver in its "recovered/verified" section — a P0-class miss in shipped work, discovered only because the owner asked "what next" 2 days later while the box burned.

Honesty check (skill): no lies told; two precision errors (d.1, d.2), one unverified attribution presented as likely (b.3), all disclosed here. No ghost systems, no split brains created; the T04-done state intentionally lives in exactly two surfaces (storage.md P0 row = repair-gate state, monitor365.md = per-service state) with distinct scopes.

## e) WHAT WE SHOULD IMPROVE

1. **Guard telemetry before custom probes** for any storm attribution — `journalctl -u memory-emergency-guard` + cgroup io.stat windows are the authoritative, pre-built attribution tool on this box.
2. **devt resolution discipline:** any io.stat/device citation resolves through `/sys/dev/block/<maj:min>` BEFORE the device gets a name in prose or reports.
3. **Intervention recommendations must be precedented:** any stop/restart suggestion gets a socket-unit + guard-restore + stc-cascade check first (all three are documented re-armers on this box).
4. **In-source corrections land in the discovery session** — the amendments convention exists; overturning a prior report's classification without amending it leaves a lying doc in the pool (row queued).
5. **Name the poller from config, not inference.**

## f) NEXT (honest list — not padded to 50)

1. [owner] Stop inboxclean-web PROPERLY: stop service + socket (if any), verify it STAYS stopped ≥ 10 min (guard restore-branch / socket re-arm check); mask if it re-arms.
2. [agent] Verify the storm clears: IO PSI avg10 < 20% within minutes of the stop; report with before/after.
3. [owner] Gate (b): `sudo systemctl start btrfs-scrub@data` in the quiet window (guard refuses if PSI ≥ 20%).
4. [agent] Scrub delta read vs the 1,351,271 baseline (btrfs.prom errors_total) — bounded-static confirm or hardware-triage pivot.
5. [owner→agent] T06a sign-off → trash the 10 files (~49G, `lars:users`, no root needed).
6. [agent] Verify the next 23:30 `/data` snapshot is clean and the btrbk-data full send completes (T09 — first-ever pool-side /data seed).
7. [agent] Start the T08 clock (~4–5 w to scrub-green post-deletion, snapshot expiry gated) and record it in the storage.md P0 row when deletion lands.
8. [agent] Amend the 2026-10-21 review §3/§7: InboxClean storm-victim → primary driver, with the io.stat evidence.
9. [queue→stability] Guard zone-6 action-set gap: the top reader survived 2.4 days of trips (#4106+) — add inboxclean-web (or dynamic top-io reader inclusion) to the stop set.
10. [queue→upstream] InboxClean dashboard query cost: "top senders all" + "paperless uploads summarize" need cache/index/limit — each dashboard round ≈ full 1.5 GB DB rescan; at poll cadence that is 3.28 TB/2.4d.
11. [agent] Identify the poller of `/`: grep gatus checks + papdashboard tiles for inboxclean probes (interval, timeout, which one retries).
12. [agent] Verify guard-restore semantics for inboxclean-web (restore list + socket wiring in the memory-guard config).
13. [owner, optional] 04f completion: `sudo sha256sum` the safety-copy DuckDB, record in the storage.md row.
14. [owner] monitor365-server restart decision — down since 2026-10-21 03:10 (2+ days); the fresh safety copy de-risks a wedged-DB restart.
15. [owner] The three open review questions remain unanswered: FLM disable-or-pin, SEV1 escalation policy, GH Actions billing.
16. [agent] Standing IO mitigation for inboxclean-web (IOWeight/io.max) as defense-in-depth for the next query storm.
17. [agent] Reconcile with the concurrent 2026-10-23_01-09 monitor365 session: did their DB-IO diagnosis observe the same Lexar pressure signature?
18. [queue] The 10-21 review's remaining P0/P1 remediations (23-h drift confirmed none executed) — monitor365 wedge row, gatus per-endpoint names, flap suppression, catalog-inventory-sync PATH fix, tmpfiles rerun.
19. [agent] Post-stop InboxClean catch-up verify: queued email processes, gatus endpoint recovery, no query backlog stampede on restart (staggered).
20. [agent] Post-repair (post-T09): restore hard-FAIL on `btrfs-verify-pool-backups`'s /data branch (WARN-only stance ends when the pool seed exists).

## g) QUESTIONS (cannot self-answer)

1. **InboxClean disposition:** stop outright and keep it down until the query fix lands (email processing pauses), or throttle it (io.max) and accept a slower storm while it stays up? Risk/appetite call — both end the P0 storm pressure differently.
2. **T06a pre-authorization:** once gate (b) shows delta ≈ 0, may I trash the 10 files (~49G, all re-downloadable AI blobs) without another sign-off round-trip, or do you want the list re-presented at that moment?
3. **The dashboard polling InboxClean:** I can find WHAT polls it, but not whether you WANT it — is anyone actively using that dashboard view (keep + fix the queries), or is it an orphan poll I should treat as removable?

---

**Self-harvest (landing with this report):** rows 8/9/10/11-12/16 → TODO_LIST.md queue one-liners + `docs/todo/{services,stability,upstream}.md` library rows; monitor365-restart + open-questions already rowed by the 10-21 harvest (not duplicated); T08-clock row deliberately deferred until deletion lands (the storage.md P0 row already owns the sequence). README addendum prepended.
