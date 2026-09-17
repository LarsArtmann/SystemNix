# Status Report: guard deep-dive, attribution correction, disk-layout findings

**Date:** 2026-09-17 13:20 CEST
**Session segment covered:** ~06:35–13:20 — guard analysis + "too aggressive?" answer, QLC confirmation, `/mnt/hot` naming question (researched, **answer still owed**), the "1) fix guard 2) send backup 3) disk layout" directive, and the step-by-step execution pass that was interrupted mid-analysis.
**Predecessor:** `2026-09-17_06-33_home-hermes-backup-gap-and-verify-phantom-green-fix.md` (hermes backup gap + verify phantom-green fix — its open items carry into section f here).
**Format:** Markdown per explicit user instruction (status-report skill default is HTML — one-off override, flagged, not propagated).

---

## Executive summary

Three directives were given (~09:40): fix the guard, send the backup, answer the disk-layout question. **Zero code was written before the interrupt** — the segment produced analysis, four significant findings, and one correction of a false claim I made earlier: the guard DOES capture IO attribution (io-psi-forensics fires on every trip; bundles sit unread in `/var/tmp`), while I had told the user "no attribution exists." The IO storm is STILL running (12+ h, avg60 66% at 09:40, trip #337 at 09:38), the backup seed remains sudo-gated for this harness, and the `/mnt/hot` naming + per-service migration question is **unanswered after two turns** — both are top items in section f.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| A1 | "Is the guard too aggressive with 128 GB?" answered with data: **256/256 trips in 7 days were Zone 6 (IO)** — zones 1–5 (memory/zram) fired ZERO times; daily Zone-6 counts 39/89/105/23 (Sep 14→17). Memory thresholds self-scale and have gone silent; RAM cannot fix io-PSI (freeze #4 happened post-RAM-bump, memory pristine) | `journalctl -u memory-emergency-guard --since "-7 days"` |
| A2 | "Was killing btrbk right?" answered: yes — freeze #3's stack literally included a btrbk full re-send; last night's kill happened at io avg60 60–85% with disk-busy corroboration up to 98%; kill decision and 40%/20% thresholds endorsed (matches the TODO #515 recalibration verdict) | guard journal + crash forensics history |
| A3 | `@home-hermes` QLC placement **definitively confirmed**: `nvme0n1` = **Lexar NQ790 2TB (QLC)**, p6 = the `@` filesystem → hermes stays on QLC exactly as the owner wants; Samsung 970 EVO = `nvme1n1` this boot (enumeration flipped again) carrying only `/nix` + `/mnt/hot` | `lsblk -o NAME,MODEL,SERIAL`, `findmnt /home/hermes` |
| A4 | USB-wedge theory RULED OUT for last night's storm: **zero** usb/uas/sg_wait kernel events since 20:00, no D-state processes at snapshot — the 2026-09-15 `usb_sg_wait` forensics finding does not explain the current storm | `journalctl -k --since "2026-09-16 20:00"`, `ps -eo stat` |
| A5 | **NEW FINDING — doctrine violation:** `/nix` and `/mnt/hot` mounts both **lack `commit=300` and `nodiscard`** (options: `rw,noatime,compress=zstd:3,ssd,space_cache=v2` only) — every other BTRFS mount on the box carries both per the 2026-08-27 doctrine | `findmnt -no OPTIONS /nix /mnt/hot` vs `/home/hermes` |
| A6 | Disk-usage snapshot: `/` (QLC) **77% used (547G/723G)** — the ENOSPC-cliff precedent was 99.76% on 09-12, and the 118G dead `@nix` subvol deletion is still pending user action; `/nix` 15%, `/mnt/pool` 12% | `df -h` |
| A7 | Guard source understood where it matters: churn-stop records a state file (epoch + which units were actually active), re-arm fires when io avg60 < trip threshold with its own counter file, **attribution wiring exists** (see D1), restore-cap logic located | module lines 424–498, 570–579 |
| A8 | io-psi-forensics script located and its bundle format documented: per-cgroup io.stat top-40, top processes by cumulative bytes, D-state stacks, PSI, diskstats, journal tail → `/var/tmp/io-psi-forensics-<UTC>/` | `scripts/io-psi-forensics.sh` (read) |
| A9 | Per-service migration research complete: ratified Set A/B/C doctrine + Phase-2 waves (crush → pocket-id → postgres → forgejo, then dnsblockd/papdashboard; discordsync is a Set-C candidate pending fsync measurement; gatus explicitly WITHOUT `+C`) | `docs/planning/2026-09-15_per-service-btrfs-subvolumes-analysis.md`, TODO_LIST #20 |

---

## b) PARTIALLY DONE

| # | Item | Works now | Open gap | Blocker | Effort |
|---|------|-----------|----------|---------|--------|
| B1 | **Guard fix (directive 1)** | Deficiency list finalized and CORRECTED to 4 items: (i) staged backup catch-up re-arm (resume `btrbk-*` on a quiet streak at a lower threshold before balances/scrubs — fixes the silent +24h slip), (ii) backup-starvation escalation metric + sev1/Gatus consumer, (iii) restore-capped log spam (fires every 30 s), (iv) surface one top-offender line into the trip message from the forensics bundle | **No code written** — interrupted mid-source-reading | none but time; module is ~800 lines and I read it in small slices | M |
| B2 | **Backup send (directive 2)** | Blockers fully characterized: harness blocks `sudo`/`systemctl` (never bypass a security control); storm at avg60 66% makes seeding now counterproductive (kill-or-freeze outcome) | Hand the owner `sudo systemctl start btrbk-root.service` for a quiet window; tonight 23:00 Persistent timer is the fallback; B1's catch-up makes the guard itself converge the send in the first quiet window | owner action + quiet window | S |
| B3 | **Disk-layout answer (directive 3)** | All facts gathered (A3–A6, A9 + predecessor report findings) | The synthesized answer — what you're missing + the step plan — was never delivered; folded into section f items 11–16 here | none | S |
| B4 | `/mnt/hot` naming + per-service question | Research done (toplevel `subvolid=5` mount; only `nix/` + nothing else on it — the `crush/` tree doesn't exist yet; Phase-2 wants `hot/<svc>` subvols mounted AT each dataDir) | **Question unanswered for two turns**; rename candidates never formally proposed; rename interacts with the Phase-2 fold-in (interim `crush-hot-db` vs `services.hot-db` must not both run) | owner taste (name) + decision (rename now vs at fold-in) | S |

---

## c) NOT STARTED

| # | Item | Why | Priority |
|---|------|-----|----------|
| C1 | Reading the existing forensics bundles (`/var/tmp/io-psi-forensics-*`, one per trip since ~09-14) — the storm driver's name has been sitting there all along; I was one `ls` away when interrupted | Interrupted; explicitly not researched further per this report's constraints | **Critical** |
| C2 | Guard code changes (the 4 items in B1) + VM-test extension (staged re-arm positive/negative cases per the negative-test convention) | Interrupted before first edit | Critical |
| C3 | `commit=300` + `nodiscard` fix for `/nix` + `/mnt/hot` (verify declaration site first: hardware-configuration.nix / crush-hot-db.nix; `/nix` remount/reboot implications) | Found at 09:40, not acted on | High |
| C4 | Per-service migration implementation, DiscordSync first (Set C: Samsung subvol at dataDir, `chattr +C`, dump-only RPO registered in backup-coordination; fsync measurement first per the ratified plan) | Design ratified upstream of me; zero implementation | High |
| C5 | Samsung monitoring (smartd, btrfs-health, Gatus mount/space) — required BEFORE moving any service DB there (single-device, currently invisible) | Pre-existing TODO #128 remainder | High |
| C6 | Offsite leg (Hetzner + Borg), `/data` EIO repair, docker data-root relocation — pre-existing backup-chain debts, untouched | Out of segment scope | High/Med |

---

## d) TOTALLY FUCKED UP

1. **I made a false capability claim to the owner and left it uncorrected for two turns.** I told you "No attribution — 256 trips and the log still doesn't name the reader." **Wrong:** `ioPsiForensics` is wired into every trip (module line 483) since ~2026-09-14 and has captured a bundle per trip into `/var/tmp`. The accurate statement: capture exists but is **unsurfaced** (trip messages/metrics don't name offenders, `/var/tmp` cleanup silently destroys evidence, and nobody read the 300+ bundles). This is exactly the "fabricated premise" class this repo's own rules reject — I asserted absence without grepping source I had open. Correction now on record here.
2. **Two direct questions left hanging**: `/mnt/hot` naming + per-service migration (asked ~07:00, researched, never answered), and directive 3's synthesized answer (only findings exist). The redirect traffic is no excuse — answers should ride the same turn.
3. **Analysis-to-action ratio: zero.** Three turns of reading (guard module in 75-line slices, forensics script header) produced no edit, no test, no handed-off command. The smallest shippable fixes (log dedup, mount options) sat undone while the storm ran.
4. **The storm is STILL running at report time** (~12+ h continuous, avg60 53–66%, trip #337 at 09:38; last check 09:40) — the box has lived in the freeze-risk regime for half a day while every session (mine included) analyzes instead of reading the already-captured evidence.
5. **Root fs at 77% with a known 118G reclaim pending since 09-12** (`@nix` dead subvol) — the ENOSPC cliff precedent sits at 99.76% and the guard keeps suppressing the very maintenance (balance) that manages headroom.

---

## e) WHAT WE SHOULD IMPROVE

1. **Grep before absence claims.** Any "X doesn't exist" statement requires a source-level check first (`grep -rn ioPsiForensics` was one command). Encode into personal review checklist.
2. **Read whole files up front.** The 800-line module was read in slices across turns — a single full read would have surfaced the attribution wiring before I made claim D1.
3. **Surface the forensics bundles**: a top-offender summary line in each trip message + a retention-managed bundle dir (not `/var/tmp`) + optionally a `guard_trip_top_offender` metric. Capture without surfacing is a tree falling in an empty forest.
4. **Answer in-turn**: user questions get answered the turn they're asked, even mid-investigation; unfinished analysis gets a stub answer with follow-ups listed.
5. **Staged re-arm design** (B1-i): the current re-arm is a thundering herd (backups + balances + scrubs all at once) gated only at the trip threshold; backups deserve priority resumption at a quieter threshold, balances/scrubs later.
6. **Mount-option drift is systematic**: two Samsung-era mounts missed `commit=300`/`nodiscard` — the doctrine lives in AGENTS prose, not in an eval-time check. A `mkFilesystem`/audit rule enforcing doctrine options on all btrfs mounts would have caught both.

---

## f) Next tasks (ranked; 34 honest items, no padding)

Impact: C/H/M/L · Effort: S <30min, M 30min–2h, L >2hr

| # | Task | Impact | Effort | Cat |
|---|------|--------|--------|-----|
| 1 | **Read `/var/tmp/io-psi-forensics-*` from last night — name the storm driver** (evidence already captured, one ls+cat away) | C | S | Investigation |
| 2 | Quiet/stop the storm driver once identified | C | S | Operational |
| 3 | Seed the backup send in the quiet window: `sudo systemctl start btrbk-root.service` (owner-run; harness is sudo-blocked) | C | S | Backup |
| 4 | Implement guard staged catch-up re-arm (btrbk-* resume on quiet streak <20%, balances/scrubs keep <40 gate) | C | M | Bug |
| 5 | Implement backup-starvation escalation (churn window open >6h with backup units stopped → metric + sev1/Gatus page) | H | M | Feature |
| 6 | Verify tonight's run lands `@.20260917T2300` + first `@home-hermes.*` receive | C | S | Verification |
| 7 | **Answer the verify-gate posture question (predecessor report Q1, still open)** — fatal vs WARN-until-first-receive; interacts with the guard-fix deploy | C | S | Decision |
| 8 | Deploy guard fix + snapshots.nix verify fix (posture decided, ideally post-receive) | H | S | Bug |
| 9 | Implement restore-capped log dedup (once per state change, not per 30s tick) | L | S | Quality |
| 10 | Add top-offender line to trip messages from the forensics bundle + move bundles out of `/var/tmp` | M | S | Feature |
| 11 | Wire io-psi-forensics into deploy.sh's pressure gate (TODO 439 remainder) | M | S | Feature |
| 12 | **Deliver the `/mnt/hot` rename proposal + decide rename-now vs at Phase-2 fold-in** (candidates + Samsung subvol alignment) | H | S | Decision |
| 13 | **Deliver the per-service migration design answer (DiscordSync first: Set C, fsync measurement, dump-only RPO)** | H | M | Design |
| 14 | Fix `commit=300` + `nodiscard` on `/nix` + `/mnt/hot` (find declaration sites first) | H | S | Bug |
| 15 | Add eval-time mount-doctrine audit (all btrfs mounts carry commit/nodiscard unless allowlisted) | M | M | Quality |
| 16 | Run crush-hot-db first migration in a live-session-free window (276 dirs, ~42 GiB; structural storm fix) | H | S | Feature |
| 17 | Samsung monitoring: smartd by-id + btrfs-health + Gatus mount/space (prereq for any service move) | H | M | Monitoring |
| 18 | Owner: `sudo btrfs subvolume delete /mnt/btrfs-root/@nix` (118G; root at 77%, cliff precedent 99.76%) | H | S | Cleanup |
| 19 | Owner: `sudo systemctl start btrfs-emergency-reserve` (absent since ~Sep 7; its Gatus check should be RED — verify alert delivery) | M | S | Operational |
| 20 | Reboot decision (owed): clears flm :52626 corpse pin, storm-era wedges; also applies mount-option changes to `/nix` | H | S | Operational |
| 21 | Reconcile interim `crush-hot-db` vs Phase-2 `services.hot-db` (fold, never run both) before first big wave | M | M | Design |
| 22 | VM-test extension for guard changes (staged re-arm + starvation negative cases) | H | M | Quality |
| 23 | DiscordSync fsync measurement → confirm Set C placement (before moving its 11 GB SQLite) | M | M | Investigation |
| 24 | Per-service Set-declaration eval guard (every `/var/lib` nested subvol declares exactly one Set A/B/C — ratified doctrine item 78) | M | M | Quality |
| 25 | Post-first-receive: run `migrate-hermes-subvol.sh status`, root-diff shadowed dirs, then `finalize` (carried from predecessor report) | H | S | Backup |
| 26 | oomd journal check for the 04:01 hermes SIGKILL (carried, one command) | M | S | Bug |
| 27 | Confirm Sep 16 23:06 OnFailure Discord alert fired (carried) | M | S | Verification |
| 28 | /data EIO corruption repair → restore btrbk-data hard-FAIL (carried P0) | H | L | Bug |
| 29 | Hetzner StorageBox + BorgBackup offsite leg (carried, decided 09-11) | H | L | Feature |
| 30 | clickhouse-backup coverage (carried) | M | M | Feature |
| 31 | Docker data-root relocation with Phase 2 (carried) | M | M | Feature |
| 32 | Root-usage trend alert tighter than ENOSPC cliff (77% today; gc-guard floor ≠ early warning) | M | S | Monitoring |
| 33 | Post-guard-fix: PSI before/after measurement for crush-hot-db migration (TODO #19 remainder) | M | S | Verification |
| 34 | HARVEST this report's f-items into TODO_LIST/ROADMAP via docs-health when instructed | L | S | Process |

---

## g) Questions I cannot answer myself (3)

1. **`/mnt/hot` replacement name.** Pure taste + architecture: candidates I'd offer are role-based (`/mnt/fast`, `/mnt/state`) vs device-property (`/mnt/tlc`), and the choice interacts with the Phase-2 `hot/<svc>` subvol naming — renaming twice is churn, so pick the name the Phase-2 layout can live with. Which do you want?
2. **Verify-gate posture (carried, now urgent).** The snapshots.nix fix from the predecessor report will make the hermes freshness check hard-FAIL once deployed; with zero receives today that means a chronically failing unit → exit-4 hazard on the next deploy. Keep fatal (deploy only after a receive lands) or downgrade to WARN until first receive (the `/data` precedent)? Owner risk-tolerance call.
3. **Reboot window.** The owed reboot clears the flm corpse, storm-era wedges, and is the clean way to apply the `/nix` mount-option fix (root store remount). When can I schedule it / when will you run it?

---

*Point-in-time snapshot — goes stale. All evidence from this session's tool log; timestamps CEST. No secrets.*
