# Boot-mirror ARMED — Samsung first in BootOrder (2026-09-20)

**Scope:** continuation session 13:15→~15:35, resumed after the 13:58 wait-state was lifted
("keep going until everything works"). Everything in the M1–M6 / F01–F16 spine is now DONE;
the single remaining action is the USER REBOOT (M7/F17+). All times CEST.

---

## Headline

The Samsung 970 EVO Plus mirror ESP is verified, armed, and FIRST in firmware BootOrder:

```
BootOrder: 000C,0001,0004,0006,000B,...
Boot000C* Linux Boot Manager (Samsung)  HD(1,GPT,023f66c0-…,0x800,0x800000)/\EFI\SYSTEMD\SYSTEMD-BOOTX64.EFI
Boot0001* Linux Boot Manager             (QLC — untouched, now fallback)
```

`nix run .#pre-reboot-check` → **23 passed, 0 failed, "SAFE TO REBOOT"** at the STRICT §11
grade (armed state). With `/nix` on the Samsung (`tlc`), the next reboot boots
loader+kernel+initrd+store entirely off the Samsung; only root `@` stays on the QLC.

## Timeline

| Time | Event |
| --- | --- |
| 13:39–14:00 | Queue v7 cycled deploy #2; smoke rc=3 on a NEW failure (Bank-Sync — transient, see below) → queue self-stopped by design |
| 14:05 | **Parallel session** fixed the cv-server exit-4 root cause: `cv-state-perms` fast-path added `-o ! -perm -u+w` (`fc49dbe5`; their report `2026-09-20_15-02`) — the exact blindspot this session's report had predicted (ownership-only probe vs mode-drift) |
| 14:08 | cv-server started clean; **system-786 created + ANCHORED** — the 90-minute un-anchored window (reboot-revert risk) CLOSED |
| 15:06 | system-787 built+anchored (parallel inboxclean work included); three-way anchor verified: profile == current-system == default boot entry |
| 15:1x | Mirror evidence collected: sync unit green ("OK — 8 entries, 312M mirrored"), df 312M/4.0G, FS UUID `4F53-C156` |
| 15:2x | pre-reboot-check first run: its OWN BUILD failed (shellcheck SC1087) → fixed → exit 0 (21 pass, WARN-grade §11) |
| 15:2x | boot-mirror-activate first run: `lsblk: unknown column: PARTNUM` → fixed (`PARTN`) → **activation succeeded** (Boot000C first) |
| 15:2x | pre-reboot-check re-run: **23 pass / 0 fail, strict §11 grade** — armed state sound |

## Fixed this session (beyond the 13:58 report's five deploy-blocker fixes)

1. `scripts/pre-reboot-check.sh` — unbraced `$MIRROR_DIR` immediately before `[[:space:]]`
   parsed as an array subscript → shellcheck SC1087 killed the script derivation at build
   (the auditor could not run itself). Braced `${MIRROR_DIR}`.
2. `scripts/boot-mirror-activate.sh` — `lsblk -no PARTNUM` (column does not exist; correct
   column is `PARTN`) aborted the script BEFORE any firmware mutation (verified: no partial
   state — re-checked §11 showed pre-activation). Fixed and re-run → clean activation.

Both are first-run bugs in code that had never been executed end-to-end (built only via
`--no-build` checks before today). Recorded in CHANGELOG.

## M/F table status (2026-09-19 finish plan, lines 48–95)

- **M1 ✓** deploy + anchor (system-787; the cv fix was the parallel session's, credit logged)
- **M2 ✓** mirror verified live (F06–F09: findmnt/UUID, sync journal + diff gate, df, §11)
- **M3 ✓** pre-reboot-check WARN-grade exit 0 (F10)
- **M4 ✓** activate; Samsung FIRST, QLC `0001` SECOND (F11–F12)
- **M5 ✓** pre-reboot-check strict-grade exit 0, 23/0 (F13)
- **M6 ✓** CHANGELOG (2 entries) + plan ticks 6/7/9 + commit + push (F14–F16)
- **M7 ⏳ USER: reboot** — then F18 (`bootctl status` → Current Boot Loader PARTUUID
  `023f66c0-…`), F19 (pre-reboot-check green from booted state), F20 (QLC still second;
  optional firmware-menu fallback boot)
- **M8 ⏳** first-nightly drift watch (post-23:00 sync re-run, no drift)
- M9–M12 follow-up pool unchanged (llama-vlm models owner-gated; ExecStart-list audit;
  optional hardening; root-`@` investigation)

## Open threads surfaced (not blocking the reboot)

1. **Bank-Sync rc=3 (14:00 smoke)** — transient: the 14:58 sync completed
   (`profiles=5, sync completed successfully`). Standing state unchanged: SCA challenge
   pending (`bank-sync sca approve` — user action, ~90-day renewal class).
2. **Rogue hermes llama-servers** PID 805159/805161 (since 05:40) still hold
   8848/8849/8127/8128; the dark-guard collector sees them (`llama_rag_leaked_instances 2`,
   scrape healthy) — the RED Gatus check is the alert WORKING. Kill decision stays with the
   user (hermes-user processes; not killable from this sandbox).
3. **inboxclean-sync failed 14:56** (exit 1, OnFailure fired) — between the parallel
   session's inboxclean.nix edits (14:35/14:40) and system-787 (15:06); that session owns
   the thread. Watch the next sync tick.
4. **Browser History quiet-day 503** — by-design until upstream ships an empty-batch
   heartbeat (upstream issue to be filed in `~/projects/browser-history`).
5. FastFlowLM smoke 000 — corpse-gate class (EADDRINUSE corpse until the owed reboot;
   heals itself after the reboot clears :52626).

## Reboot handoff (the one remaining user action)

When ready: plain reboot. Nothing to prepare — the chain is audited (loader default →
kernel/initrd on ESP → `init=` on live store → GC anchors → mirror §11 all green).
Afterwards verify `bootctl status | grep PARTUUID` shows `023f66c0-…` and `nix run
.#pre-reboot-check` exits 0 from the booted state. Rollback if anything looks wrong:
firmware boot menu (F8/F11/F12) → QLC `Linux Boot Manager`, or `efibootmgr -o` QLC-first.

---

*Report 15:30. System: system-787 anchored, cv-server serving, mirror armed. No secrets.*
