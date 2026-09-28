# M6 disk attribution + deletion proposal (OWNER gate)

**Date:** 2026-09-28 22:30
**Status:** Attribution COMPLETE (the plan's "~460 GB /home media" assumption was WRONG); every deletion below needs owner approval. Raw data: `~/.local/share/cv-verify/disk-{home-depth2,root-subvol}.txt`.
**Deployed alert:** the new gatus "Root FS Early Warning (93%)" fires at collector-scale 93% (currently 86% — df's 90% is reserve-inflated; statvfs is the truthful scale).

## The attribution (df 628G used on `/`, 723G total)

| Where | Size | Class | Evidence |
|-------|------|-------|----------|
| `/home/lars` (subvol @home) | 196 GB | mixed: projects 92G, tmp 36G, go 18G (module cache), .local 13G, .config 10G | `du -x --max-depth=2` |
| `/home/lars/.cache` (subvol @cache-home) | 43 GB | REBUILDABLE caches | separate subvol mount, own du |
| `/var` (in @ root subvol) | 12 GB | system state | du -x / |
| everything else visible | ~1 GB | — | du -x / |
| **Visible total** | **≈ 262 GB** | | |
| **UNATTRIBUTED (btrfs-level)** | **≈ 366 GB** | **snapshots / reflink-shared extents / deleted-but-referenced** — du cannot see it; subvol list shows only `@ @cache-home @home @home-hermes` | 628 − 262 |

**The single biggest lever is the 366 GB btrfs-level pool, not any user directory.** Owner diagnosis commands (all root):
```bash
sudo btrfs filesystem usage -T /
sudo btrfs subvolume list -a /            # snapshots live somewhere (btrbk "Rescue snapshot of @" ran TODAY 18:05)
sudo btrfs filesystem df /                # data vs metadata split
journalctl -u btrbk* --since '7 days ago' | grep -iE 'snapshot|send|delete' | tail -30
```
Candidate causes: btrbk snapshot retention never expiring (each snapshot pins the FULL extent set of the day it was taken), or reflink-heavy churn (VM images, container layers, the CV pipeline sqlite copies) — 366 GB is consistent with months of unexpired snapshots.

## Deletion proposal (ordered by size/effort; each row = one owner decision)

| # | Item | Size | Risk | Command (after approval) |
|---|------|------|------|--------------------------|
| P1 | btrfs snapshot audit + retention fix | up to 366 GB | LOW if snapshots are pure btrbk history (backup targets on /data + offsite exist); verify restore drill first | `sudo btrfs subvolume list -a /` → btrbk retention config → expire |
| P2 | `/home/lars/tmp` | 36 GB | LOW (scratch; includes go-cache/go-mod/playwright redirections — RECREATED on demand) | review `du -sh /home/lars/tmp/*` then `trash` stale dirs |
| P3 | `/home/lars/.cache` deep clean | up to 43 GB | LOW (caches: playwright browsers re-download, pip/npm/insightface) | selective `trash` of aged dirs |
| P4 | `/home/lars/go` (GOMODCACHE) | 18 GB | LOW (re-downloads on next build) | `go clean -modcache` or trim |
| P5 | coredumps | 958 MB | ZERO (triaged: quickshell test-script aborts + flm xdna-driver core, both read) | `sudo coredumpctl vacuum-time=2days` |
| P6 | nix store GC | on `/nix` (nvme0, 119G/928G — NOT the 90% disk) | LOW but unnecessary for the alert | optional; auto-blocked below 5GiB btrfs unalloc anyway |

**Projection:** P1 alone plausibly returns `/` from 90% (df) to under 60%; P2+P3+P4 add ~15 points. The 93% early-warning alert buys reaction time; the cliff (97.3% CV health-fail) is then unreachable.
