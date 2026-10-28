# System boot review — boot-chain findings + 5 fixes landed (deploy pending)

**Session:** 2026-10-28 00:44–01:15 · ad-hoc "review system boot" dispatch
**HEAD at start:** `305c5d4f6` · **Eval-verified:** evo-x2 toplevel green post-changes (`nix eval …toplevel.drvPath` → `arr0sfzb…`), scoped `nix fmt` clean
**Method:** live boot forensics on the 00:42:59 boot (journal, busctl, bootctl, blame, milestones) + repo config reading; no plan file existed for this topic (planning/brainstorming grep clean).

## a) The measured boot (2026-10-28 00:42:59, the boot under review)

| Phase | Duration | Note |
| --- | --- | --- |
| firmware | 1min 2.5s | BIOS POST — see (e)5 |
| loader | 1.45s | timeout 1 + menu |
| kernel | 1.9s | |
| initrd | 5.5s | switch-root at 5.5s |
| **userspace → multi-user/graphical** | **285.7s** | prior boots: 127.9s; **26min 31.8s** (the 2026-10-27 storm boot) |
| SDDM (login screen) | **~33s** | `display-manager.service` started at 33.2s — the desktop was READY 250s before the boot transaction completed |

Load average at 1min uptime: **98** (thundering herd of ~100 concurrent start jobs; all timer+boot units at once).

## b) Root causes found (boot-critical-chain class)

1. **cv-server.service WAS the boot transaction's tail** — multi-user.target completed the literal instant cv-server started (285.702 journal-proven). Its chain drags `pocket-id-provision`'s fail-retry cycle (the open [ready] OpenCloud-secret row — it failed at 16.7s and re-fired at 60s+) + the `crm-server` After/Wants + the 120s `/dev/tcp` socket-wait ExecStartPre. None of it is boot-critical; it simply was never migrated in the gen-955 late-applications wave (its after-edges are legal, so the ordering-cycle audit's boot-blocker assertion did not fire — that assertion only catches the transitive After=late-applications class, not direct multi-user membership with long activation).
2. **bless-boot fires ~11s into userspace, not at end of boot** — `systemd-bless-boot-generator` wires `systemd-bless-boot.service` into `basic.target.wants` at runtime (`/run/systemd/generator.early/basic.target.wants/systemd-bless-boot.service`, live-verified), and upstream `boot-complete.target` only Requires/After `sysinit.target`. With `bootCounting.enable = true`, a fresh entry's counter was stripped ~11s in — before 99% of the boot transaction ran. **The tries=3 auto-rollback could never fire for any failure past basic.target** (failed multi-user chain, hung desktop, the 26min storm class — all "good"). boot.nix's own comment describes the intended end-of-boot semantics; the mechanism did not deliver them.
3. **home-manager-lars failed 5× then start-limit-hit at every boot** — the `migrate-buildcache-fallback-caches` activation reap `rm -rf`'d `~/.cache/gomod`, whose go-toolchain trees carry read-only dirs (`go` sets 0555 itself); rm as the owner EPERMs inside them → activation abort → 5-restart loop (journal: "cannot remove … Permission denied" ×hundreds, then start-limit-hit). User environment left stale.
4. **fstrim re-fires AT BOOT on reboot-storm nights** — the daily timer is Persistent; 4 boots on 2026-10-27 → a full-pool trim at boot #1, competing with the boot IO storm itself (this boot: fstrim started at 40s, still running 11min in, at ioTier.maintenance idle priority).
5. **udev err-level spam every boot** — (a) amd-gpu.nix's bfq rule matched USB-attached disks (sda/sdb/sdd): scheduler writes at USB attach fail EBUSY mid-enumeration; (b) boot.nix's JMicron nr_requests rule matched partition devices (sdb1/sdc1), which have no `queue/` subdir ("Could not chase sysfs attribute").

## c) Fixes landed this session (eval-green, deploy pending)

| # | Fix | File |
| --- | --- | --- |
| 1 | `systemd.targets.boot-complete` asDropin: `After/Wants = multi-user.target` — bless now runs when the boot transaction actually completed; counting rollback protects the WHOLE boot. Cycle-safe (nothing in the multi-user graph orders after boot-complete/bless-boot; ordering-cycle-audit green) | `platforms/nixos/system/boot.nix` |
| 2 | `cv-server.wantedBy = mkForce [ "late-applications.target" ]` — the gen-955 class-fix placement; multi-user no longer waits on cv→pocket-id-provision→crm chains | `modules/nixos/services/cv.nix` |
| 3 | `chmod -R u+w` before both reap `rm -rf` loops — home-manager activation survives read-only go toolchain dirs | `platforms/nixos/users/home.nix` |
| 4 | `fstrim.timerConfig.Persistent = mkForce false` — daily cadence keeps the SLC doctrine; no boot-time catch-up trims | `platforms/nixos/system/boot.nix` |
| 5 | udev: bfq rule `SUBSYSTEMS!="usb"` + whole-disk `sd[a-z]`; JMicron rule `KERNEL=="sd[a-z]"` + `TEST=="queue/nr_requests"` | `platforms/nixos/hardware/amd-gpu.nix`, `platforms/nixos/system/boot.nix` |

Expected next-boot userspace: from 285s toward the calm ~40–60s baseline (SDDM already at 33s; remaining multi-user tail: clickhouse 55s + bank-sync/discordsync oneshots + rescue-snapshot class — watch one boot before further migration).

**Parallel-session rescue:** daemon commit `72d801815` (01:02:41) swept a Nix SYNTAX ERROR into btrfs-health.nix (`''|*[!0-9]*)` — bare `''` terminates the indented string; needs `'''`). It broke every eval tree-wide (mine included) minutes after my green proof. Fixed mechanically to `'''|` ×2 lines (shell semantics unchanged) — flagged to the user at session end, per shared-tree discipline.

## d) Known-benign / explained (no action)

- **`systemd-bless-boot` "Can't find boot counter source file" failures on 2nd+ boots of a generation**: inherent bless semantics (blessed = counter stripped; re-bless attempts exit 1). Every failure since 2026-10-17 correlates exactly with an earlier successful bless of the same entry hash. Journal noise only.
- **Boot mirror**: decode green (Samsung ESP `023f66c0` first, expected WARNING signature), boot-mirror-sync finished at 34.4s, path-unit re-trigger class closed.
- **initrd 5.5s / kernel 1.9s**: healthy; serial8250 blacklist + APST disable + tpm.disabled already claim their savings.

## e) Findings NOT fixed this session (deliberately)

1. **`FinishTimestampMonotonic = 0` for the whole 00:42 boot** with an empty job queue (systemd 261.3): `systemd-analyze` refuses; boot-metrics-emit burned its 12×120s retry budget then converged via the 30min reEmit (by design — transaction_open gauge fired). Previous boots set Finish normally. If it repeats on the next boot, it deserves a systemd-upstream look; the collector already measures the class.
2. **`/home/lars/tmp` automount fail-loop** (mount exit 32, `fsconfig() ENOENT`, every starship prompt triggers it): the fstab references `by-label/tlc subvol=users/lars/tmp` — the subvol is GONE from the Samsung toplevel (`/mnt/hot/users/lars/` holds only `cache/`; the storage-crisis sessions wiped it). gen-953 §42's "fails fast-loud" state confirmed, now with root cause. Fix needs sudo (subvol recreate via migrate-user-tmp-hot.sh) or retiring the fstab entry — owner/crisis-session decision. QUEUED (storage.md).
3. **pocket-id-provision OpenCloud-secret failure**: already [ready] in services.md; boot exposure ends with fix (c)2 regardless.
4. **~60 units still direct multi-user members** (immich stack, bank-sync chain, atticd, dnsblockd, inboxclean, indexer-web, …): tonight only cv-server proved boot-gating; migrate the next tail only with a measured boot as evidence (the 2026-10-18 ratified off-critical-chain intent covers them, but each move deserves its own boot-proof).
5. **Firmware POST 62s**: BIOS-side (memory training / USB enumeration suspected; tpm already kernel-disabled but firmware TPM enumeration may still cost). Owner BIOS investigation; not OS-controllable.
6. **`late-applications.target` finish at 285.7s** — its members (forgejo 1:47, llama-chat 2:28, oauth2-proxy 2:01 …) inherit whatever the boot IO storm does; fixing the storm sources (monitor365 quiesce row, root-fs space) helps more than further unit surgery.

## f) Self-harvested follow-ups

1. REBOOT-VERIFY the boot-chain batch (bless at end-of-boot, cv-server under late-applications, home-manager-lars clean first-try, no udev bfq/nr_requests err lines, userspace phase ≪ 180s regression line) → [blocked:user] services.md.  ← this row
2. /home/lars/tmp automount root cause + fix options → [blocked:user] storage.md.  ← this row
3. FinishTimestamp=0 recurrence watch → [watch] row folded into (e)1 via this report; no separate queue row (boot-metrics transaction_open already alerts the class via Gatus "Boot-duration metrics missing or erroring").

## g) Questions for the owner

1. The Samsung hot tier: is `users/lars/tmp` intended to return (recreate subvol + re-run migrate) or is the /home/lars/tmp hot-tier era over (retire the fstab entry)? Decides (e)2's direction.
2. BIOS: is there a fast-boot/POST option worth 60s/boot to you? (e)5.
