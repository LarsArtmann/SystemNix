# Status Report: QLC Root Space — Root Causes + Agent-Side Reclaim

**Date:** 2026-10-25 20:21 CEST
**Session scope:** Single-question session — "why does `/` only have 28GB left!? ROOT CAUSES!" with an explicit execute-and-verify mandate. This session READ the 2026-10-20 space audit first (`docs/status/2026-10-20_09-39_qlc-root-space-audit-and-io-storm.md`), found its ~160G reclaim inventory untouched (owner "wait for instructions" gate), and treated the owner's new instruction as the go-ahead for the agent-safe subset.

---

## Executive Summary

`/` (QLC `@`, 723G partition, nvme0n1p6 this boot) sat at **97% / 689G used / ~24G avail** at session start, with `btrfs_device_unallocated_pct 0` (1 MiB) and `btrfs_health_critical 1` firing LIVE — the 2026-06-26 metadata-ENOSPC precursor state, right now.

Five root causes (C1-C5 below). The single biggest actionable one: **two project repos deliberately redirect Go caches onto the QLC root** (~96G live, +64G regrowth in 5 days), a fossilized workaround for 2026-09/10 buildcache outages.

**Executed (agent, no sudo): ~68G of verified-stale caches trashed AND purged** (not just staged — trash entries removed, unlink done). Avail 24G → 45G at write time; the remainder of the freed extents lands as the Oct 22-24 `@` snapshot pin window expires (~Oct 27-28).

**The structural half is NOT fixable by deletes:** chunk-unalloc stays 0% until a root-run balance consolidates chunks. Flagged as E1.

---

## Root Causes

### C1 — Live data inventory (all measured, 2026-10-25)

| Location | Size | Notes |
|---|---|---|
| `/home/lars` (in `@`) | 302G | projects 169G + tmp 69G + .local 15G + .config 14G + go 11G |
| `~/.cache` (`@cache-home` subvol, NOT snapshotted) | 122G → 70G after this session | was 97G on 10-20 — regrew +25G in 5 days |
| `/var` | ~45G | 3.4G readable + **~39G `/var/lib/monitor365-server` DuckDB** (perms-blind; size per the 2026-10-22 T04 safety-copy row: pool dropped 39.21 GB during its copy) |
| `/home/hermes` | unknown | perms-gated (`drwx------`), du reads 0; ~160G arithmetic bucket member (with C3) |
| system + metadata | ~38G | metadata pool 27.9G / 22G used (78%) |

### C2 — THE LEAK: project scripts steer Go caches onto the QLC root (~96G, actively regrowing)

- `~/projects/cv/scripts/go-env.sh:41,47` + `~/projects/CV/nix/apps.nix:270`: any `/mnt/*`-rooted GOCACHE/GOMODCACHE/GOLANGCI_LINT_CACHE/GOPATH/TMPDIR is **unconditionally redirected to `$HOME/tmp/*`**. Documented motive (apps.nix comment): the 2026-10-14 boot's "dead mount" — `/mnt/buildcache` writable-but-pruned-index import failures.
- `~/projects/go-cqrs-lite/scripts/go-env.sh:55-67` + `scripts/pre-commit.sh:18-22`: GOCACHE → `/home/lars/projects/.gocache-disk`, GOLANGCI → `.golangci-disk`, GOTMPDIR/TMPDIR → `.gotmp`. Documented motive: buildcache hit 100% / ENOSPC 2026-09-22.
- Live trees (all with fresh writes TODAY or within days, 15 `golangci-lint-langserver` + active `go test` pipelines running): `~/tmp/go-cache` 32G, `projects/.gocache-disk` 35G, `.golangci-disk` 15G, `.gotmp` 9.2G, `~/tmp/go-mod` 3.9G, `go-lint` 0.9G. Plus `~/.cache/uv` 21G (active), `.bun` 5.4G, `qmd` 2.3G.
- This is why root went 91% → 97% in 5 days despite the 10-20 inventory being known. `.gocache-disk` (35G) wasn't even in the 10-20 list — it grew since.

### C3 — Snapshot pinning (17 instances; exclusive extents + hermes ≈ 160G by arithmetic)

8 `@` + 7 `@home-hermes` snapshots in `.snapshots` + 2 rescue (`btrfs_root_snapshots 8`, `btrfs_rescue_snapshots 2`). df-used 666G − live ~481G − metadata 28G ≈ snapshot-exclusive + hermes. The Oct 22-24 snapshots pin every extent that existed at their times — trashes free only as they expire (root window 3d/2d-min).

### C4 — Chunk debt: device-unallocated 0% (1 MiB), allocated 99%

Every byte of the 723G partition is carved into chunks. Deleting files frees extents WITHIN chunks — df avail climbs, but `unallocated_pct` stays 0 until a **balance** consolidates. The weekly balance jobs self-skip when unallocated < 5G (metadata) / < 10G (data) bounce room → at 0% they NEVER run: the same gate-deadlock class as the 2026-08-17 GC-guard 5-night deadlock. Only a manual root-run balance (E1) breaks it.

### C5 — Burst snapshots inflate pin generations

2026-10-23 alone produced FIVE `@` snapshots (0244, 0255, 2300, 2304, 2315) vs ~1/day policy — boot/deploy catch-up triggers firing in bursts. Each burst generation extends the pin window for that day's churn.

---

## Executed This Session (agent-safe, no sudo, all verified)

| Target | Size | Staleness evidence | State |
|---|---|---|---|
| `~/.cache/gomod-r` | 29G | no file newer than 2026-10-17 | trashed → chmod 0555-wall → purged |
| `~/.cache/gocache-r` | 19G | no file newer than 2026-10-17 | trashed → purged |
| `~/tmp/[0-9a-f][0-9a-f]` (256 Go-cache buckets) | 12G | no top-dir mtime since 2026-08-18 | trashed → purged |
| `~/tmp/go-build{2748316702,257340542,1330595748}` | ~0.7G | mtimes 2026-10-20 | trashed → purged |
| `~/.cache/{go-mod-fresh,nsfw-dev-gocache,nsfw-gate-gocache,puppeteer}` | ~5.9G | no file newer than 2026-10-23 | trashed → purged |

Method: freshness probe first (`find <tree> -newermt <cutoff>` + dir mtimes; anything fresh = skip), then `trash`, then `trash-rm` purge by exact name, then df verify. Walks ran `ionice -c3 nice -n19 timeout` per the 10-20 hard rule.

**df trail:** 689G used / 24G avail → 666G / 45G at write time (async cleaner + pin expiry continue through ~Oct 28).

**Failures caught by verification (recorded as the discipline working):**
1. `trash-rm gomod-r` died mid-purge on Go's 0555 module dirs (`PermissionError: zombiezen.com/sqlite@v1.4.2`) — fixed with `chmod -R u+w` on the trash entry (same wall as the 2026-08-31 report).
2. The first purge loop matched `trash-list` **column $2 = TIME, not PATH** → zero iterations, counts unchanged. Silent-empty probe; caught only because the entry counts were re-checked. Correct field: `$3`.

## Deliberately NOT Touched

- **Live-writer cache trees** (fresh mtimes, active builds): `~/tmp/go-cache` 32G, `go-mod` 3.9G, `go-lint` 0.9G, `projects/.gocache-disk` 35G, `.golangci-disk` 15G, `.gotmp` 9.2G, `~/.cache/{uv 21G, .bun 5.4G, qmd 2.3G, go-build-httputil, gopls, overview}`. Trashing under running builds breaks parallel sessions' work; they free only after the E6 leak fix lands.
- **Work products**: `~/tmp/wevisone-spike` (14G, dir mtime 19:38 TODAY — active work), `~/tmp/cvdev` (1.6G cv2-cv13 datasets), `~/tmp/tmpdir` (1.1G test logs).
- **Other sessions' trash entries** left in place (CV `.git/index.lock`, invoices, webphone .kt, nsfw-classifier history...).

---

## Escalations (root/owner-gated, in execution order)

1. **E1 — manual balance on `/` (THE structural fix):** after tonight's frees land, in a quiet window (PSI < 20%, zram < 80%): `sudo rm /btrfs-emergency-reserve` → `sudo ionice -c 3 btrfs balance start -dusage=5 -dlimit=2 /` → re-provision the reserve (`sudo systemctl start btrfs-emergency-reserve`). Runbook: 2026-08-24 crash #3 procedure in `docs/agents/storage.md`. Success = `btrfs_device_unallocated_pct` > 0 and `btrfs_health_critical` back to 0.
2. **E2 — scrub overdue:** `btrfs_scrub_stale 1` on BOTH `/` and `/data` (no completed scrub in the 10-day budget; last runs interrupted). Root-run or next quiet weekly window.
3. **E3 — hermes home sizing (still open from 10-20):** `sudo du -xh -d1 /home/hermes | sort -rh | head -20` — the only unknown in C1/C3.
4. **E4 — `/var/lib/monitor365-server` ~39G DuckDB relocation decision** (hot-db pattern candidate; its off-NVMe safety copy exists since 2026-10-22 T04).
5. **E5 — btrbk burst-snapshot policy** (C5): why catch-up fired 5x on Oct 23; each burst extends pin windows.
6. **E6 — THE LEAK FIX (highest leverage):** move the Go cache home to the **Samsung hot tier** (380G free, internal NVMe, never flaps — doctrine-C `+C` subvol pattern, same as M12) OR add mount-alive conditional guards to the four leak sites. Then: repoint, let caches regrow in the right place, trash the ~96G QLC trees after builds quiesce. Owner design call — the redirects encode two real outage classes (ENOSPC 2026-09-22, pruned-index 2026-10-14) and must not be naively reverted onto a buildcache that is itself at 87%.

## §f Harvest (self-harvest rule)

- E1, E2, E3, E4, E5, E6 + the pin-window verification → `docs/todo/storage.md` rows (this date).
- Drain verification (time-gated) → `TODO_LIST.md` queue row.
- trash-cli gotchas (0555 wall, topdir routing, column order) → `docs/agents/storage.md` BTRFS gotcha list.
