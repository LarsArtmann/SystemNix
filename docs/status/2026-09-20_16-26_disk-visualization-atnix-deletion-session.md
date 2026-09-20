# Session Status: Disk/BTRFS Visualization + Old @nix Deletion — 2026-09-20

**Session window:** ~15:00–16:26 · **Author:** crush agent (glm-5.3) · **Host:** evo-x2, tree clean at start (`44128cf0` era)

---

## a) FULLY DONE

1. **Current+target disk/BTRFS visualization** — `docs/planning/2026-09-20_15-17_disk-layout-current-and-target.html`
   - Single self-contained page, **3.6 MB**, mermaid.js v11.17.2 **inlined** (MIT, fetched npm-registry→jsdelivr, `node --check` validated) — renders fully offline
   - **6 mermaid graphs** (physical topology, NVMe subvol trees, bulk tier /data+pool+buildcache, backup dataflow, target end-state, boot chain current-vs-target), all Bauhaus-Light house style
   - **11 sections**: capacity bars, drive+partition inventory with the by-id serials that ARE the config, service→storage placement map (20 rows, Set A/B/C), full mount table, btrbk retention matrix, phase roadmap, gotchas, TOC nav
   - **Verified by actually rendering the deliverable** in headless Chromium (Helium `--headless=new --dump-dom` + `--virtual-time-budget`): 6/6 flowchart SVGs with real node labels, 0 mermaid error-bombs, all nav anchors resolve — re-verified after every revision round (4 render passes total)
   - Content sourced from live state (`lsblk`, `findmnt`, `df`, dir listings of `/mnt/hot` `/mnt/pool` `/mnt/btrfs-root` `/data`, by-id serials) + `hardware-configuration.nix`, `snapshots.nix`, `hot-db.nix`, `hot-user-caches.nix`, `crush-hot-db.nix`, `boot-mirror.nix`, both Samsung planning docs, per-service subvol analysis, Hetzner research, `docs/todo/storage.md`, AGENTS.md

2. **Old `@nix` subvolume DELETED** (user-executed, agent-verified)
   - Pre-flight built and run: every boot entry `init /nix/store/…` path resolves on the live Samsung store; every ESP `initrd` present (after correcting my own buggy first check — see §d); rollback ladder 3/3 closure-OK (`p0ccbqj5` flip gen lives on the Samsung)
   - User ran the delete through the fish guard (typed `delete`) → subvol 398 gone
   - Result: **605G → 545G used, 85% → 78%**, ~60G freed, settled across `commit=300` transactions (watched it drain 596→545)
   - Bookkeeping updated: `docs/todo/storage.md` (Phase-1 row + 2026-09-12 STILL-PENDING), `AGENTS.md` subvolume-layout section, `hardware-configuration.nix` stale comment, HTML viz (5 spots)

3. **HTML inflation incident resolved** — at 16:07 something pretty-printed the whole HTML (bundle 3.57→7.82 MB, body wrapped). Diagnosed precisely (bundle ×1 but expanded; `</html>` ×2 was a DOMPurify string inside the JS, not duplication), confirmed the inflated JS was still valid, **restored the compact bundle** (3.6 MB), re-render-verified 6/6 graphs. Root cause of WHO/WHAT formatted it: **unidentified** (see §e)

## b) PARTIALLY DONE

1. **HTML "best version" round** — the self-review upgrades landed (inventory, placement map, boot-chain graph, honest tree, recolors, TOC, full-size+scroll), but the file now carries formatting I did not author (the mystery formatter's wrapped body) layered under my edits. Content is correct and verified; provenance is muddied.
2. **The visualization is a snapshot artifact** — accurate as of 15:17 + the 16:2x @nix edits, but several numbers (pool PoH figures quoted from Aug/Sep measurements, `/data` dir sizes from the 08-31 doc) were taken from docs rather than re-measured live this session.

## c) NOT STARTED

- `btrfs-emergency-reserve` re-provision (needs user root; reminded twice, still absent since ~Sep 7)
- Offsite Borg leg, hot-db Phase-2 migrations, boot-mirror EFI activation — all user-gated items I only *visualized*; no implementation work was in scope
- Nothing else: this session was visualization + deletion only, per instructions

## d) TOTALLY FUCKED UP (and fixed)

1. **My boot-entry pre-flight had two bugs**: (a) `grep '^init'` also matched `initrd` lines; (b) initrd paths are ESP-relative but I tested them against `/` — produced 8 scary false "DEAD" lines. Caught by reading the user's pasted output, corrected to `'^initrd'` + `/boot$p` base, re-ran clean. Lesson: test paths against the namespace the CONSUMER (systemd-boot) resolves them in.
2. **My fish one-liner didn't run in fish** (`do/done`, `read -r`) — I gave the fish translation only after the user hit the error; should have led with it on a fish-default box.
3. **Glob-expansion sudo trap in my fish snippet** — fish expands `*` as the calling user BEFORE sudo; entries dir is 0700 → "No matches for wildcard". The `sudo bash -c` version I'd already provided was the right answer; I let the user hit the failure first.
4. **Stale capacity stat shipped**: first HTML version said "≈35.6 TB / 20+ subvols / 3-2-½" — mixed decimal/TiB sloppiness and cryptic labels. Fixed to 35.5 TB (32.4 TiB) / 19 (now 18) / "2 of 3 copies" only after the "is that the BEST?" challenge. Should never have shipped.
5. **multiedit vs python-splice freshness**: my first edit batch failed on "modified since read" (the splice had touched mtime). Cost: one round trip. Should have re-`view`ed immediately after any out-of-band write.

## e) WHAT WE SHOULD IMPROVE

1. **Identify the HTML formatter** — something rewrote a 3.6 MB HTML at 16:07 (pretty-print body + expanded JS bundle, semantics preserved). Candidates: auto-commit daemon sidecar, parallel-session tooling (a parallel session WAS active — AGENTS.md system-health edit), or an editor hook. Unknown formatters mutating deliverables is the "modified since read" class writ large; worth one focused look (inotify on docs/planning, or check daemon logs) before it eats another artifact.
2. **Git history now carries one 7.9 MB blob** (daemon committed the inflated version at 16:15 before my restore). No rewrite (banned); just be aware for the eventual history-diet.
3. **`docs/planning/` has no size lint** — a 3.6 MB artifact is accepted silently. Either accept big-HTML policy (inline-mermaid is genuinely nice offline) or codify "CDN + graceful offline fallback" as the house pattern in html-report-kit.
4. **Headless render verification should be a reusable script** — I hand-rolled the Helium `--dump-dom` + python SVG-assert dance four times; it belongs in `scripts/` (or as a skill asset) so the next HTML artifact gets it for free.
5. **My verification discipline slipped once**: shipped stale-number stat cards in v1 because I verified RENDERING (mermaid works) but not every NUMBER against sources. "Verify what the artifact claims" ≠ "verify the artifact renders".
6. **Fish-first snippets**: this user's interactive shell is fish — default to fish-native commands or `sudo bash -c` wrappers from the start.

## f) NEXT — up to 50 things, prioritized

**User-gated (root/hands):**
1. `sudo systemctl start btrfs-emergency-reserve` (absent since ~Sep 7; Gatus should be red over it — verify alert delivery)
2. Boot-mirror activation: `nix run .#boot-mirror-activate` + planned reboot (module deployed 09-19)
3. /data EIO repair execution (T04–T08) — the only never-completed backup leg
4. First `hot-db` Phase-2 migration window (pocket-id first per plan)
5. Decide go-build hot-cache design (HM symlink canonicalization trap — needs gating design)
6. Hetzner Borg go-live inputs: StorageBox credentials + passphrase recovery policy + exclusion exceptions
7. Mystery snapshot `data.20260905T2330` forensics (root)
8. SSD-2 (sdc1 ssd-btrfs) tenant decision
9. `e2fsck -f /dev/sdb1` buildcache fsck in an unplug window
10. Docker PG-volume NOCOW standalone change (decided 09-05, still open)
11. Delete `/mnt/buildcache/swapfile-emergency` (16G, owner-approved deletion pending)
12. monitor365 `cargo clean` (~100G reclaim on buildcache, owner window)
13. btrbk-root/pool MemoryHigh/OOMScoreAdjust hardening (ready)
14. `snapshot_preserve` widening 3d→7d decision (DAS-outage lesson)

**Agent-actionable [ready] (from docs/todo/storage.md, not touched this session):**
15. Wire `crush-hot-db-migrate` onFailure alerting + monitoredServices entry
16. Add `--dry-run` to migrate-hot-db / crush-hot-db scripts
17. Depth-cap tripwire for `.crush` dirs deeper than maxdepth 3
18. Per-project liveness guard in crush-hot-db (open-fd check)
19. `btrfs-verify-pool-backups` 2-day WARN boundary
20. Second nightly btrbk-root retry window (04:00) decision
21. restic repo on pool for app dumps (dedup; forgejo zips share ~0 extents)
22. discordsync + browser-history NVMe→pool migrations (subvols reserved empty)
23. Browser-history DB backup (folds into #22)
24. Offsite Borg implementation once #6 lands (backup.nix module per blueprint)
25. Offsite Borg restore runbook + timed drill
26. Borg monitoring extras (`backup_ever_succeeded`, ioTier, pre/post-deploy smoke)
27. ClickHouse backup before next SigNoz upgrade
28. `/data` damage-set inventory doc (single source of truth)
29. Codify single-victim /data repair recipe
30. Shadow-dir cleanup under `/mnt/pool`, `/data`, `/var/lib/clickhouse`
31. `pool-subvols-ensure` declarative oneshot
32. Consolidate device constants into one lib file (pool by-ids in 3 places)
33. btrbk snapshot→pool delay SLO metric + Gatus
34. pg_dump restore drill for twenty/manifest
35. btrfs-health: add `/mnt/pool` scrub metrics loop + Samsung coverage (Phase-1 leftovers)
36. disko draft alongside the deferred reinstall (T16/T17 pattern exists)
37. Cache-minting tools sweep for dead-mount fallback names
38. btrbk catch-up `--no-block` trigger on boot/deploy (closes multi-day gaps)
39. paperless-exporter RandomizedDelaySec fix
40. `docs/services/das-recovery.md` runbook
41. Sweep other cache-minting tools (pnpm/cargo/sccache/pip) symlink/mount convergence
42. hot-db fold: delete interim crush-hot-db module in the same change when Phase-2 lands
43. Post-migration `PRAGMA integrity_check` on one migrated crush DB
44. Verify migrate unit journal SKIP lines while sessions live; capture in docs/services/crush.md

**This-session follow-ups:**
45. Identify the 16:07 HTML formatter (§e.1) before it mutates another artifact
46. Make headless-render verification a `scripts/verify-html-diagrams.sh`
47. Consider a docs/planning size lint or big-HTML policy note in AGENTS.md
48. Re-verify `df /` after tonight's btrbk cycle (confirm 545G holds with no surprise pin)
49. Update the 2026-08-31 Samsung visualization HTML or mark it SUPERSEDED by the new page (two "current" visualizations now exist)
50. Post-reboot (when it happens): confirm `@nix` absence didn't orphan anything (it can't, but the boot-menu screenshot closes the loop)

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Who/what formatted the HTML at 16:07?** Did you (or a parallel session/tool) run a formatter over `docs/planning/` around then — e.g. an editor format-on-save, the daemon growing a formatting step, or a `dprint`/`prettier` pass? It rewrote my deliverable mid-session and I'd like to name it before it happens again.
2. **Big-HTML policy:** keep mermaid inlined (~3.6 MB per artifact, fully offline) as the house pattern, or switch to CDN-with-offline-fallback (small files, needs network)? This decides whether I codify it in AGENTS.md for future reports.
3. **The 2026-08-31 Samsung visualization** is now outdated in parts (pre-boot-mirror, pre-crush-migration, `@nix` still alive). Keep it as a historical snapshot with a superseded-by header, or should I fold a one-line pointer into it on the next docs pass?

---

**Bottom line:** deliverable shipped and re-verified end-to-end (twice upgraded after a fair challenge); `@nix` safely deleted with ~60G freed and every dependent doc updated; five real mistakes made and fixed, all five with lessons recorded; one unexplained environmental incident (formatter) diagnosed-and-contained but not attributed.

**Waiting for instructions.**
