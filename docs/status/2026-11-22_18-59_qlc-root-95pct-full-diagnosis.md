# 2026-11-22 18:59 — QLC root 95% full: full diagnosis (why "again")

Owner question: "Why are our (SSD) disks so full again?!?" — Answer below. Read-only
session; no deletions performed, no config changed. All figures live-probed
2026-11-22 18:0x-19:0x under this session's working sudo.

## a) Live state

| Filesystem | Use | Note |
| --- | --- | --- |
| `/` (QLC nvme0n1p6, `@`+subvols) | **679G/723G, 95%**, free 37G | the full one |
| `/data` (QLC p8) | 661G/1.1T, 66% | fine |
| `/nix`+`/mnt/hot` (Samsung nvme1n1p2) | 610G/928G, 71% | fine |
| `/mnt/pool` (HDD) | — | fine |

BTRFS `/`: device FULLY allocated (unalloc **1.0 MiB** — the metadata-ENOSPC
precursor class, same as 2026-10-27); metadata DUP 25.26/29.17 GiB = **86.5%**
(CRITICAL cliff at 90%); data 627G. `btrfs_health_critical` should be 1
(Gatus "BTRFS Chunk Health" + "Root fs >=93%" + "backup starvation" alerts all
cover this state).

Growth: **580G used on Nov 3 → 677G on Nov 22 (+97G/19d)**.

## b) The ledger (where 677G lives; du -x + subvol walks)

| Consumer | Size | State |
| --- | --- | --- |
| `@cache-home` subvol (unsnapshotted) | **190G** | cv-go **64G** (19G Nov 3 → +45G = biggest grower, LIVE, owner-triage per buildcache.nix gc-exclude), glac-fleet 25G, m365fix 22G, go-tmp 14G (GC pattern matches but live writer), `.Trash-1000` 8G (frees INSTANTLY — no snapshot leg), ds-gate 4.9G, ec-hub 3G |
| Trash: `~/.local/share/Trash` 91G + `/root/.local/share/Trash` 39G | **130G** | lars trash grew +36G since Oct (was ~55G); root trash frozen Nov 11 (shrink-session debris) |
| Frozen `~/projects` QLC shadow | **132G** | frozen at the 2026-10-28 Samsung cutover; Phase F reclaim pending |
| `@home-hermes` subvol | **108G** | hermes ACTIVE (live data, own btrbk) — growth question, not reclaim |
| `/var/lib/monitor365-server` | **77G** | `.pre-shrink` **41.7G** (runbook said trash after next 03:00 export — exports landed Nov 13+, NEVER trashed), legacy `archives/` **16G** on-host (frozen Nov 9; BindPaths→pool live since Nov 21, pool dir empty), live DB 5G + rolling backups 13.1G+4.8G |
| `~/pdg-cache` (gobuild 26G + gomod 17G) | **43G** | ORPHANED: no GOCACHE wiring in unit env/pma-env/system config, zero writes since Nov 4 17:13; regenerable |
| `/var/lib/inboxclean` | 15G | live state (pool mirror is the 100G one) |
| `~/go` 21G, `~/.config` 15G, `cv-verify` 11G, Steam 6.8G, containers 4.6G | ~59G | assorted |
| `/root` rest (`.debug` 2.7G, Setup-Mac) + `/var` rest | ~14G | |
| `/btrfs-emergency-reserve` | 10G | pinned, last-ditch |
| `.snapshots/@.20261116T2300` + `.rescue` ×2 (Nov 20/21) | ~40G+ deltas | pins everything that existed Nov 16 |

## c) WHY "again": the recovery loop is FROZEN (the real finding)

`btrbk-root` AND `btrbk-data` have been **condition-skipped every night since
Nov 17** — `ExecCondition=btrbk-admission` refuses because the
memory-emergency-guard trips continuously on **chronic I/O PSI storms**
("I/O PSI some avg60=48.70%, max disk busy 99.8%" — trip **#12470**, zone 6,
"NO eligible headless tree matched"), so the 60-min trip-free admission window
never occurs at 23:00. Verified: refusal verbatim in journal for Nov 21
23:00 ("tripped 0 min ago") and live at 18:5x ("tripped 1 min ago").

Consequences (all verified):
1. **5-night backup gap** — no root or /data snapshots/sends since Nov 16
   (pool receives starving; Gatus starvation alert's own runbook advice applies).
2. **Pin rotation frozen** — the Nov-16 snapshot is btrbk's force-preserved
   incremental send parent; with no successful send it is never pruned, so it
   pins ALL bytes present Nov 16 (incl. most of the 130G trash, pre-shrink,
   archives). Today's 17:24 root-prune-guard fire = `<no_action>` (nothing
   prunable). Emptying trash NOW frees only the post-Nov-16 share.
3. Catch-up slots: **zero grants since Nov 20** — the guard has no functioning
   starvation escape, so this does not self-heal.
4. Unalloc=1MiB means deletions inside `@` cannot return chunks to the pool
   until a metadata balance (needs ≥5G unalloc or the 10G reserve) — the
   E1-class final step, only after space is actually freed.

IO PSI at session end: some avg60=31.6% — storm ongoing; a manual send NOW
would feed the freeze class. The unlock needs a genuinely calm window.

## d) Reclaim menu (ranked, ~340G+ identified)

| # | Action | Frees | When |
| --- | --- | --- | --- |
| 1 | **One quiet-window `sudo systemctl start btrbk-root` (+ btrbk-data)** — advances the send parent, closes the 5-night gap, re-enables pruning | unlocks #2-#5 | calm window (PSI low ≥60 min) |
| 2 | `trash-empty` (lars) + root trash empty + monitor365 `.pre-shrink` trash (runbook-sanctioned since Nov 12) | ~130G + 41.7G | after #1 rotates the Nov-16 parent (~3d) |
| 3 | Migrate legacy monitor365 `archives/` 16G → pool BindPaths target, delete local | 16G | anytime (pinned till rotation) |
| 4 | Delete orphaned `~/pdg-cache` | 43G | anytime (pinned till rotation) |
| 5 | Phase F: frozen projects shadow | 132G | owner-gated (existing plan; re-probed 2026-11-22: shadow frozen since Oct 29 14:38, soak gate now 3/5 — see runbook STATUS + storage [decision] row) |
| 6 | cv-go/glac-fleet/m365fix triage (111G live dev caches) + `.Trash-1000` 8G instant | up to 119G | owner-triage |
| 7 | Metadata balance to return chunks (unalloc 1MiB→) | n/a (health) | after frees land |

Structural legs queued separately: the admission-gate starvation fix
(stability [decision]) and the monitor365 placement row update (storage.md:209).

## e) Probes of record

`df -h`; `btrfs filesystem usage -T /`; `btrfs subvolume list -s /` + `/data`;
du -x -d1 walks (/home/lars, /var, /root, .local, monitor365-server,
@cache-home, pdg-cache, projects shadow); /proc/mounts + findmnt (archives NOT
host-bind-mounted); pgrep/env of PMA daemon; `systemctl cat btrbk-root`;
journal: btrbk-root since Nov 16, memory-emergency-guard, root-prune-guard;
admission live rc=1; /proc/pressure/{memory,io}.
