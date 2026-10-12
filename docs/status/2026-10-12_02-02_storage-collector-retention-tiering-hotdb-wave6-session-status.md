# Session Status: storage-collector retention tiering + hot-db wave 6 + monitor365/storage forensics

**Date:** 2026-10-12 02:02 CEST
**Scope:** one Crush session on evo-x2 (`/home/lars/projects/SystemNix`), starting from
"do we still have a PostgreSQL cluster?" and ending with the landed
storage-collector retention redesign. All claims live-verified this session unless
marked otherwise. Machine state during the session: a monitor365 flamegraph
benchmark build (`cargo bench` + rustc + a parallel `go build/test`) kept io PSI
some avg10 oscillating 35–83% — no deploy was attempted (gate <20% by design).

---

## a) FULLY DONE (verified end-to-end)

1. **PostgreSQL cluster question** — answered with dual evidence: eval
   (`postgresql-17.11`, dataDir `/var/lib/postgresql/17`, enable via
   createLocally wiring) + live probes (loopback :5432 listener, postmaster
   workers, live connections from paperless/miniflux/geometrikks; TimescaleDB
   workers active). Docker-era sidecars confirmed gone (2026-10-08 removal).
2. **"On which disk?"** — QLC root (`nvme0n1p6`, `@` subvolume), no dedicated
   mount; explicitly the future wave in `docs/services/hot-db.md`. Samsung
   (nvme1n1) mounts enumerated live (forgejo Set-B subvol, journal, caddy-logs,
   /nix, caches, /mnt/hot).
3. **Hot-DB migration status ("where are we at?")** — live-reconciled: eval
   `services.hot-db.entries = {}` + findmnt (zero `hot/<name>` mounts) → prep
   100% (module, migrate vehicle, monitoring, 2026-10-04 pre-flight), execution
   0%; six waves enumerated risk-ascending with per-wave gates.
4. **Stale postgres wave snippet FIXED + re-verified** — the future-wave block
   in `docs/services/hot-db.md` still gated on "decide the paperless pg_dump
   gap first" (closed 2026-09-21) and missed `paperless-db-backup` +
   `geometrikks-db-backup` (landed after the snippet was written). Snippet
   refreshed; throwaway `extendModules` eval green: 0/2262 failed assertions,
   mount renders (`subvol=hot/postgres`, `nodatacow`), anti-shadow
   `ConditionPathIsMountPoint` + `RequiresMountsFor` confirmed landing on both
   new dump units.
5. **monitor365 data-location map** — three tiers, all live-verified:
   agent buffer `/mnt/pool/services/monitor365` (btrbk-pool snapshotted,
   snapshots.nix:338), cold archive `/mnt/pool/archive/monitor365-archive`
   (RAID1-only), server DuckDB `/var/lib/monitor365-server/monitor365.duckdb`;
   `/data/monitor365*` sources confirmed GONE (2026-08-18 migration self-
   neutralized). Fleet disabled since 2026-08-12 (private `wireguard-collector`
   dep); storage-collector is the live successor.
6. **The Oct 4 mystery mtime ATTRIBUTED** — `/var/lib/monitor365-server` dir
   mtime 2026-10-04 04:02:08 explained by journal evidence:
   `lars : ... trash /var/lib/monitor365-server/monitor365.duckdb.prepurge`
   (owner manual cleanup, not service activity). Zero monitor365 units render
   in config (eval: empty list).
7. **storage-collector StateDirectory explained** — rotation mechanics
   (size-triggered ~11 MB × keep-5 ≈ 66 MB ≈ documented ~60 MiB bound, ~7 h15 m
   cadence), fresh live writes, DynamicUser `nobody` view, private/ symlink
   pattern. Three orphaned `.state.json.*.tmp` files identified as interrupted
   atomic writes; two attributed to Sep 19, one to Oct 10 23:22 (journal:
   kernel boot 23:15:25, another hard cut ~7 min later). Follow-up queued
   (monitoring.md, tmp sweep at startup).
8. **The "~60 MiB bounded" rationale documented in the answer** —
   storage-collector.nix:50-52 arithmetic (60 s cycles, maxFileMb×keepFiles)
   - venue reasoning (QLC root churn + stopgap status vs monitor365's DuckDB).
9. **Telemetry analysis #1 (first 100 records)** — pipeline validated (60 s
   cadence, v1 schema, per-mount/disk/PSI/btrfs/zram records); PSI unit
   semantics pinned (JSON value = kernel percent ×100, verified against
   `/proc/pressure`); pool RAID1 mirror parity confirmed from cumulative
   counters; QLC-root btrfs unallocated measured at **11.6 GiB** (df shows
   72%/197G — allocator view much tighter); buildcache metric divergence
   documented (collector 82% used/total vs df-style 88% used/(used+avail)).
10. **"One year of data" sizing** — ~13 GB/yr logical at the measured rate
    (36 MB/day), ~1.5–2.5 GB/yr physical under zstd:3; conclusion: change the
    venue, not the bound.
11. **Telemetry analysis #2 + storm attribution** — second 100-record capture
    (14 min later) cross-read with the first: the io storm (65% → 80% some
    avg10 spikes, full 71–72%) attributed via `pgrep` to a LIVE monitor365
    flamegraph benchmark build (`cargo bench --no-run --profile flamegraph`,
    output stamped 20261012-014618) plus a parallel `go build/test`; rust-cache
    btrfs +7.5 GiB in 14 min with sdc at 99.97% busy; buildcache ~7 GB read;
    Samsung 7.6 GB/min read burst; QLC calmed from in_flight 183 → 0; 23:30
    btrbk rotation released ~3.5 GB on the QLC root (data chunk usage
    488.99 → 485.38 GB); zram ratio 2.27× → 1.93× with huge pages doubling.
12. **THE FEATURE: storage-collector retention redesign (owner picked tiering
    over a 5 GB cap)** — landed, committed, eval-verified:
    - `modules/nixos/services/storage-collector.nix`: `services.restic.backups.
      storage-history` → `/mnt/pool/backups/restic-storage-history`, nightly
      04:20 + jitter, **no pruneOpts = indefinite**, targets the REAL
      StateDirectory (`/var/lib/private/storage-collector`; root unit —
      rendered `User: root`, no cap drops, verified it can read the 0700 dir),
      `restic-storage-history-setup` password bootstrap, ioTier.background,
      `RequiresMountsFor /mnt/pool`, `.last_success` → integration registry
      `backup` row → backup-coordination + aggregate Gatus check.
    - `scripts/deploy.sh`: provisioner-loop entry + comment.
    - **Eval verification:** full toplevel eval 0 failed assertions (includes
      the deploy-restart-audit provisioner gate reading deploy.sh at eval
      time); rendered units checked (repo, paths, empty pruneOpts, 04:20
      calendar, setup wantedBy, backup unit exists, registry row).
    - **hot-db wave 6** (the 1 GiB Samsung half): snippets + fail-closed note
      in `docs/services/hot-db.md` (entry + `maxFileMb=50 keepFiles=20` =
      1 GiB ≈ 27 d hot window; `storage-collector-verify.service` in
      extraUnits), deliberately NOT in-tree (`entries = {}` stays — shadow-
      split hazard). Verified via throwaway extendModules: 0/2265 assertions,
      mount renders `subvol=hot/storage-collector`, daemon flags flip to
      `--max-file-mb 50 --keep-files 20`, anti-shadow wiring on service AND
      verify unit.
    - Queue rows (docs/todo/storage.md): restic first-run [blocked:deploy],
      wave-6 window [blocked:user]. CHANGELOG entry written.
13. **§f self-harvest at report authoring time** — two NEW direct follow-ups
    landed on BOTH surfaces: pre/post-deploy smoke entries for
    restic-storage-history (TODO_LIST + monitoring.md) and the daemon-skipped
    lint re-run for `a4ab0f82` (TODO_LIST + pipeline.md).
14. **On-sight doc fixes:** hot-db.md "All six snippets" wording updated to
    carry the 2026-10-12 re-verification lineage; earlier postgres-snippet
    staleness fix (§a.4).

## b) PARTIALLY DONE

1. **The retention goal itself** — code 100%, execution 0%: the restic leg
   needs a PSI-calm deploy + first-run verification; the 1 GiB Samsung tier
   needs the wave-6 sudo window. History keeps accreting ONLY in the 60 MiB
   hot window until then.
2. **Commit hygiene for the feature** — content complete and verified, but
   SPLIT across two commits by daemon races (see §d.1): `a4ab0f82` (code,
   heuristic message) + `c854c670` (docs, proper message). Amend-forward
   absorbed an unseen intermediate daemon grab; a further rebase was judged
   too risky on the shared tree.
3. **Lint coverage on the swept files** — bash -n (deploy.sh), treefmt
   (0 changed), and the full eval are green, but shellcheck/statix/deadnix
   were skipped by the daemon race (hook legs keyed on staged paths);
   standalone re-run queued (TODO_LIST + pipeline.md).
4. **Pre/post-deploy smoke coverage for the new leg** — registry + aggregate
   check wired, but the §13/§16 smoke entries (offsite-borg/clickhouse
   precedent) were forgotten at land time; harvested at authoring time
   (TODO_LIST + monitoring.md).
5. **monitor365 data freshness** — fully characterized (frozen since
   2026-08-12; owner cleanup Oct 4 attributed) but the ROOT unblock (publish/
   vendor `wireguard-collector`) remains an owner decision, untouched.
6. **The io-storm situation** — attributed and explained, not fixed: the
   monitor365 bench build is legitimately churning the USB caches (working as
   designed); no action taken or needed beyond the standing PSI gate.

## c) NOT STARTED (this session; mostly pre-existing queue)

- Waves 1–5 of the hot-DB tier (gatus, dnsblockd, pocket-id, browser-history,
  discordsync — each owner sudo windows; discordsync gated on a fresh dump).
- Wave 6 window execution (snippets + verification ready).
- The postgres hot-db wave (snippet refreshed + verified; still last).
- restic-storage-history first run + verification.
- Everything in the standing queue touched this session only as a reader:
  /data corruption T04–T08, offsite-borg go-live, P0 monitoring batch deploy,
  paperless collation refresh, /data/docker reclaim, catalog.home.lan, etc.
- No AGENTS.md changes — deliberate: per-service state is owned by
  `docs/services/*` + the todo libraries (routing table already points there).

## d) TOTALLY FUCKED UP (what went wrong, honestly)

1. **Daemon-race commit fragmentation — my amend missed its target.** The
   daemon swept my two code files into `a4ab0f82` ("chore: auto-commit …
   heuristic") while I was still writing docs. My `git commit --amend` then
   raced a SECOND daemon pass: the evidence (c854c670's parent IS a4ab0f82)
   shows my amend replaced an intermediate daemon grab, so the intended
   "one properly-messaged feature commit" became two commits — code under a
   heuristic message, docs under the real one. I verified contents of both
   (nothing foreign, nothing lost) and chose NOT to rebase on the shared
   tree — but the history is messier than it should be. The pipeline.md
   "[decision] daemon commit-message quality" row is exactly this class.
2. **Edit-tool discipline slip** — my first `docs/services/hot-db.md` edit
   failed ("must read the file first"): I had only `sed`-read it via bash.
   Cost: one failed call + a user instruction to re-read before editing.
3. **Forgotten smoke entries at land time** — the clickhouse/offsite-borg
   precedent (§13/§16 smoke additions) was in the module I cloned from and I
   still skipped it; caught in self-review, harvested, but it should have
   been part of the first edit.
4. **Unverified-at-land-time assumption: could the restic unit read the 0700
   DynamicUser StateDirectory?** I asserted "root reads it" from the
   restic-app-dumps precedent without checking the rendered unit. Settled
   AFTER landing (rendered `User: root`, no capability drops) — the claim is
   true, but I claimed it before proving it; the cv-backup silent-no-op class
   is exactly this shape.
5. **Formatter invocation flail** — `nix run .#formatter` errored
   ("attribute 'formatter.type' does not exist"); recovered via
   `.#formatter.x86_64-linux` without investigating the root cause (out of
   scope, but it is a latent flake-parts quirk nobody has pinned).

## e) WHAT WE SHOULD IMPROVE

1. **Daemon-race message protection**: the "[decision] daemon commit-message
   quality" queue row now has a second data point (this session lost a clean
   feature commit twice in one hour). A pre-commit-timed or post-commit
   rename mechanism would end the heuristic-message losses.
2. **Standalone-lint after daemon sweeps should be AUTOMATIC, not remembered**
   — the CONTRIBUTING rule exists; the hook could instead run the legs
   against the daemon's OWN commit (daemon runs its own lint pass).
3. **btrfs unallocated should be a first-class alert** — df showed 72% while
   the allocator view showed 11.6 GiB unallocated on the root; the collector
   now emits BtrfsTelemetry (unallocated_bytes) — a Gatus/SigNoz rule on
   `unallocated < N GiB` for `@`/`data` would close the df-blind spot.
4. **Buildcache/GC threshold denominators need pinning** — collector
   used/total (82%) vs df-style (88%) differ by 6 points around a 90% GC
   trigger; pick one definition and align the guard.
5. **Metric-absence vs metric-zero semantics** — the collector's fail-closed
   textfile doctrine is good; the same treatment for the new restic marker
   row landed, but the pre/post-deploy smoke gaps (now queued) show landing
   checklists for new backup legs should be a template, not memory.
6. **Monitor365 data lifecycle** — the fleet is frozen and the owner is
   actively curating by hand (Oct 4 trash); the wireguard-collector
   publish/vendor decision (or formal decommission + archive policy) would
   stop the drift between "disabled service" and "live dataset".
7. **The QLC-root unallocated 11.6 GiB trend** — every hot-db wave that
   leaves `@` improves it; the shadow-dir cleanup doctrine (contents out,
   directory stays) is the reclaim path — worth scheduling alongside the
   waves rather than after all of them.
8. **Report → queue harvest worked as designed** — both NEW §f follow-ups
   landed on both surfaces at authoring time; keeping this discipline is the
   improvement (it caught the smoke gap).

## f) UP TO 50 THINGS TO GET DONE NEXT

Session-direct (harvested at authoring time):

1. Deploy at the first PSI-calm window; then restic-storage-history first-run
   verification (repo init, first snapshot, `.last_success`, aggregate check,
   one `restic check`, repo size probe). [blocked:deploy] — queued
   (storage.md).
2. Wave-6 window: flip entry + knobs in-tree, run the 6-step runbook, verify
   the 1 GiB window + mount + collector restart. [blocked:user] — queued
   (storage.md).
3. Add pre/post-deploy smoke entries for restic-storage-history (§13/§16,
   offsite-borg/clickhouse precedent). [ready] — queued (TODO_LIST +
   monitoring.md).
4. Re-run daemon-skipped lint legs standalone on `a4ab0f82` (shellcheck
   deploy.sh; statix/deadnix storage-collector.nix). [ready] — queued
   (TODO_LIST + pipeline.md).
5. storage-collector tmp-orphan sweep at startup (ExecStartPre glob
   `.state.json.*.tmp`; doubles as a crash counter). [ready] — queued
   (monitoring.md).
6. Post-wave-6 (after soak): trash the shadowed QLC contents under
   /var/lib/private/storage-collector per the shadow-dir policy. Not
   harvested — contingent on #2.

Queue items this session Touched/read and re-confirmed as standing (no new
research; pointers only):

7. Hot-db waves 1–5 windows (gatus → dnsblockd → pocket-id → browser-history
   → discordsync; discordsync needs a fresh DB dump first — dump leg stalled
   in the freeze storms). [blocked:user]
8. Postgres hot-db wave (last; snippet refreshed + verified this session).
   [blocked:user]
9. Decide the wave order question raised by wave 6 (lowest-risk wave vs the
   numbered order — see §g Q1). [decision]
10. Restic storage-history prune policy: confirm "literally indefinite" vs a
    keep-within-10y safety prune (~13 GB/yr logical). [decision] — see §g Q2.
11. Fold `crush-hot-db` into `services.hot-db`'s projects design (two
    mechanisms on one Samsung; standing row). [ready]
12. Rebuild `hot-db` + `crush-hot-db` VM tests green on the current tree
    (quiet-IO window). [ready]
13. Shared PATH-stub scaffolding for script fixture tests (forgejo/migrations/
    hot-db hand-roll the same stubs). [ready]
14. Offsite Borg go-live inputs (repo target, sops placeholders → real
    values). [blocked:user]
15. Offsite Borg retention/prune policy + BX21 upgrade trigger sizing.
    [decision]
16. First timed Borg restore drill against the real StorageBox repo
    (selftest-only so far). [blocked:user]
17. P0 monitoring batch deploy + close-out battery (PSI percent thresholds,
    git-lag textfile, traces dashboard, thermal-ceiling/trip-rate rules,
    coverage ratchet, §18 sweep). [blocked:deploy]
18. PSI kernel-percent fixture selftest (pin /proc/pressure semantics in a
    flake-check fixture). [ready]
19. llama-chat depth health probe (completion smoke vs the green-/health/
    hung-brain class). [ready]
20. Confirm Gatus shows forgejo red on the designed degraded path.
    [ready]
21. Fix tq-agent-pool post-deploy-check detection (smoke vs journal
    disagreement). [ready]
22. monitoring.md conventions note: absence-proof rules + §10 canary
    conflict. [ready]
23. Paperless postgres collation refresh (`ALTER DATABASE paperless REFRESH
    COLLATION VERSION`). [ready, root]
24. /data corruption repair chain: T04 DuckDB safety copy → scrub delta gate
    → deletion sign-off → scrub-clean → btrbk-data resume. [blocked:user]
25. Triage the `node_btrfs_device_errors_total{nvme0n1p8}` ≈ 3.87e8 counter
    (artifact vs new signal; owner call). [blocked:user]
26. Mystery snapshot `data.20260905T2330` root-cause (sudo forensics).
    [blocked:user]
27. /data/docker reclaim (owner sudo; pre-Ledger Twenty PG volumes inside).
    [blocked:user]
28. Forgejo G1 tail: burn-in (≥2 btrbk legs + one mirror cycle) → trash
    `/var/lib/forgejo.qlc-pre-subvol` (67G QLC reclaim). [watch]
29. catalog.home.lan go-live (unblocked by the Forgejo migration;
    setup-forgejo.sh step 2). [ready]
30. Boot-mirror PartUUID/BootCurrent decode verification half (activated
    2026-09-30; post-activation audit leg still open). [blocked:user]
31. Post-crash resumable-reader pause automation (freeze-19/20/22 class:
    boot-time pause of migrations/rsync while guard-active). [ready]
32. wireguard-collector unblock decision for monitor365 (publish to crates.io,
    make public, or vendor) — re-enables agent + server. [decision] — see §g
    Q3 context.
33. Buildcache GC ≥90% guard: pin the denominator (df-style vs used/total)
    and align the collector metric + guard. [ready]
34. Btrfs-unallocated alert rule from BtrfsTelemetry (`@` + `data` + `tlc`
    headroom floors). [ready] — born from §e.3 this session.
35. btrbk snapshot→pool delay SLO (textfile metric + Gatus; needs ≥3-night
    sample). [ready]
36. service-health-check errexit bug (a down caddy/forgejo/dnsblockd/
    postgresql kills the screamer before notify; latent, documented
    2026-10-07). [ready]
37. Chromedp pin survey across repos (v0.19 migration exposure). [ready]
38. CONTRIBUTING daemon-race section: extend standalone-lint re-run rule to
    .nix files (this session is the proof case). [ready]
39. Daemon commit-message quality mechanism decision (second data point this
    session). [decision]
40. Investigate the `nix run .#formatter` "attribute 'formatter.type'" error
    (worked via `.#formatter.x86_64-linux`). [ready, low]

Deliberately NOT harvested (with reason):

- "Year-retention sizing" doc note — superseded by the landed tiering; the
  sizing math now lives in the CHANGELOG entry.
- "Monitor365 DuckDB safety-copy to pool archive" worry from the /data item —
  MOOT for the live data (already pool-side since 2026-08-18; migration
  module comment + heal phase verified this session).
- "PSI-storm deploy scheduling automation" — dropped pending §g Q3 (owner
  policy on who triggers calm-window deploys).
- Generic queue hygiene (rows 7–30 above) — already in their domain
  libraries; re-pointing them into TODO_LIST would duplicate surfaces.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Wave order + hot-window size:** should wave 6 (storage-collector, the
   lowest-risk, ~minutes) jump the queue and run FIRST at the next window,
   and is 1 GiB (~27 d full-res) the hot-window size you want, or should it
   be 2 GiB+ (~2 months) given the pool carries the indefinite tier?
2. **"Indefinitely" literally?** The restic repo has NO prune — unbounded
   growth (~13 GB/yr logical, less in-repo). Keep it literally indefinite, or
   add a keep-within-10y (or similar) safety prune so a future format
   accident can't strand unbounded growth?
3. **Storm-window deploy policy:** the monitor365 bench build occupied 01:00–
   02:00 at 35–83% io PSI (a legitimate build on the USB caches). When the
   gate clears, do you want me to auto-run pending deploys (restic first-run
   et al.) as soon as io PSI < 20% in future sessions, or do you prefer to
   pull the trigger yourself each time?

---

_Verification lineage: every "eval-verified/verified" claim in this report
was executed this session (toplevel eval 0 failed assertions at
`a4ab0f82`+docs; two throwaway extendModules runs: 0/2262 postgres snippet,
0/2265 wave-6 snippet; rendered-unit inspections for storage-collector,
postgres wiring, restic units; journal/stat/pgrep/findmnt live probes).
Commits: `a4ab0f82` (code, daemon message), `c854c670` (docs), plus the
report-time harvest edits._
