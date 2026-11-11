# dnsblockd Startup-Wedge Loop — IO Storm vs the 300s Gate (2026-11-11 01:15)

**Session:** incident response, 00:53 → 01:15 CET, owner prompt "how can dnsblockd just be offline". First responder to the outage; continues the dnsblockd wedge lineage (2026-10-12 13:06 discriminator incident, runbook §Startup hang).

**Verdict first: dnsblockd is in a RESTART LOOP, not a one-off hang — and the loop is structurally unrecoverable while the current IO storm lasts.** Every start dies at the `dnsblockd-wait-listener` 300s gate with `server_init` still incomplete; the 2026-11-11 00:47 deploy died on the deploy flock (code=13, the 23:34 deploy held it until 00:49+), so NO new generation has switched tonight — the deployed unit still carries the 300s budget. Fix landed in-tree (budget 300→600s) + queue rows; deploy is the remaining step.

## What happened (journal-verified timeline)

| Time | Event |
| --- | --- |
| Nov 10 19:01:54 | Last healthy start (PID 3542633): `server_init` **220.2s** — longest healthy on record, 80s inside the 300s gate under moderate load. Served 5h43m without incident. |
| Nov 10 23:34:57 | Deploy starts (bank-sync SCA arc session). sops secret re-encrypts at 23:43. |
| Nov 11 00:30:13 | **`fstrim.service` starts — a NEW unit from that deploy's switch, its first full-pool trim.** `io.pressure full` pins ~50-58% for 45+ min (still running at 01:15). |
| 00:45:40 | Deploy switch lands; dnsblockd restarts (attempt 1, PID 1068087). OIDC secret written fine. |
| 00:45:49 → 00:51:01 | Attempt 1: 3 of 5 phases complete, then silence — gate kills at 300s (`no :53 listener … init wedged before listeners_start`). Attempt consumed only **2.3G disk read in 5m19s ≈ 7MB/s**. |
| 00:51-01:12 | Attempts 2-5 (PIDs 1400746, 1698855, 2021449, 2353306): identical 3-phase wedge, gate kill every cycle, ~5.3min/cycle, restart counter 1→5. Attempt reads as low as **510MB/5min ≈ 1.6MB/s** against a **9.7G journal.db + 3.3G tracking.db** init. OnFailure notify legs fire each cycle (Discord P0 pages). |
| 00:47:39 | Second deploy attempt **fails code=13** — deploy flock held by the still-running 23:34 deploy. No switch. |

## Root cause chain (each link evidence-backed)

1. `server_init` (`server.New`) synchronously reads the hot-tier DBs before `listeners_start` — runbook's journal-measured healthy distribution: 61.5-255.5s, and it GROWS with the DBs: `journal.db` doubled 4.6G (2026-10-27 audit) → **9.7G tonight**, arriving exactly at the predicted "~2× steady state".
2. Tonight's storm (fstrim's first full-pool trim + the 23:34 deploy's converge wave + forgejo/PMA on the same disks) held PSI at ~50%, dropping effective init read rate to ~1.6-7MB/s. The GB-scale load mathematically exceeds 300s.
3. The gate + `Restart=always` then make recovery IMPOSSIBLE, not just delayed: every start is killed at 300s before init finishes. Same trap class as the 60s→150s re-size history ("a budget inside the healthy distribution kills the resolver mid-load") — but tonight the DISTRIBUTION moved, not the budget being wrong per se.
4. NOT a port conflict: the orphaned debug instance `/tmp/f109dbg/dnsblockd` (PID 332163, since Nov 8 17:09, cwd `~/projects/dnsblockd`, ppid=1) binds only 127.0.0.1:18099/19099. NOT the binary or config: attempt 1's and 19:01's config hash (`3py79wzq…`), mapping store path (`7fhhd0yni…`), and entry count (3,415,478) are identical. NOT the OIDC secret reload: provisioning finished clean at 00:45:40.

**Impact:** evo-x2 :53 dead; LAN clients ride the VRRP failover (rpi3-dns serves the `.53` VIP — that contract is the designed asymmetry, unpageable by intent). On evo-x2 itself: `*.home.lan` names dead (public names fall through resolv.conf to 9.9.9.9), gatus OIDC gate crash-loops, deploy-blocking `cache.home.lan` resolution fails.

## Actions taken (all in-tree, committed)

1. **`modules/nixos/services/dns-blocker.nix`** — `listenerWaitBudgetSec` 300→600, `timeoutStartBudgetSec` 330→660 (same 30s margin, assertion `budget < envelope` still holds), comment block re-justified with tonight's journal measurements. Cost of a true wedge grows 5→10min/cycle — accepted against an unrecoverable-under-load outage; paging stays on the gatus/SigNoz legs.
2. **`docs/services/dnsblockd.md`** — gate section gained the 2026-11-11 storm case; size profile corrected (journal.db 9.7G steady state ARRIVED; tracking.db 3.3G).
3. **Queue rows** (TODO_LIST.md + docs/todo/services.md, paired): `[ready]` deploy + verify the bump; `[watch]` server_init cost scaling with journal.db toward the new budget (upstream lazy-init question).

## What closes the outage TODAY (owner, in order)

1. **Nothing if you can wait**: fstrim is transient (45+ min so far). Once PSI drops, the next auto-restart (~5min cadence) completes init in the historical 110-220s and DNS heals itself. Restart counter 8 by 01:29 with no StartLimit trip (cycles are ~5.3min apart, far outside the burst window).
2. **Immediate unblock (root)**: `sudo systemctl restart dnsblockd` AFTER fstrim finishes — clean restarts under quiet IO complete in ~16s-4min (2026-10-12 playbook step 3 precedent). NO goroutine dump is owed here: the cause is proven starvation (read-rate math), not a silent code wedge — the runbook's dump-first doctrine applies to unexplained silence.
3. **Deploy the tree** (carries the 600s budget + tonight's other parked fixes): a start needing >300s under load must be ABLE to finish; until that deploys, every storm window re-creates tonight's loop.

## NOT verified / open

**Provenance note (added 01:35):** the daemon's `cde293860` (01:31:24, "13 changed file(s)") carried this wave's five files (module + runbook + both todo surfaces + this report) in one footless heuristic commit alongside UNRELATED sibling work (flake.nix, `lib/flake-input-pin-audit.nix`, `.gitignore`, a 648MB `cvagent.db.pre-g02-backup` binary, the audible-dirs + pipeline.md rows). Not amended: the amend would absorb the siblings' files into this commit's message. Owner actions embedded there: the 648MB binary should never live in git history (rewrite before push or revert), and the staged `D cvagent.db.pre-g02-backup` deletion belongs to the sibling session that owns it.

- Whether fstrim's trim actually finishes before the next attempt's gate kill — monitored through 01:30, still running (PSI avg60 slowly falling: 58 → 41).
- The `[watch]` row's upstream question (`initJournal` runs inside `server.New` pre-listeners; cost scales with journal.db) — needs an upstream look, not this repo.
- The four sibling `crush -y` sessions (one owns the 23:34 deploy + SCA arc, see its 00:48 report) were NOT contacted — the notify-failure-p0 Discord pages have been carrying the outage signal since 00:51.
