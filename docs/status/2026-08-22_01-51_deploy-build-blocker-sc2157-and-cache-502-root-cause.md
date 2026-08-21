# Status Report: Deploy Build Blocker (SC2157) + cache.home.lan 502 Root Cause

**Date:** 2026-08-22 01:51 CEST
**Session scope:** User pasted a failed `nh os boot` run (build error SC2157 in `system-health-metrics` + `cache.home.lan` 502s). This session diagnosed both, verified the fix that a concurrent session had already landed, and confirmed the 502s are a hardware DAS USB drop (not a config bug).
**Machine state at report time:** evo-x2 running, DAS USB link `8-1` down since 00:59:15, pool + buildcache offline, atticd failing on mount dependency, all NVMe services healthy. Tree clean at `e977fd73`.

---

## a) FULLY DONE

1. **Root-caused the `nh os boot` build failure.** The build died on `system-health-metrics` with ShellCheck SC2157 (error): `if [ -n "eno1" ] && [ ! -e "/sys/class/net/eno1" ]; then` — the Nix literal `cfg.lanInterface` was interpolated into a shell `[ -n ... ]` test, which is ALWAYS true (literal string, not a variable). `writeShellApplication` runs shellcheck with errors fatal, so the derivation failed → 48-derivation cascade blocked the whole toplevel build.

2. **Diagnosed the fix that was already in the tree.** A concurrent session had committed `384ee901` ("properly quote LAN interface name") before my edit landed: it assigns `LAN_IF="${cfg.lanInterface}"` and tests `[ -n "$LAN_IF" ]` — the correct shell-variable form. My own multiedit was redundant; I detected the mid-edit race (file mod-time changed between read and edit), re-read, and confirmed the committed fix is correct rather than fighting it.

3. **Verified the fix end-to-end.**
   - `nix build '.#nixosConfigurations.evo-x2.config.system.build.toplevel' --keep-going` → **builds clean**, no SC2157, no download errors.
   - `nix flake check --no-build` → **all checks passed** (only the expected aarch64-darwin skip).

4. **Root-caused the `cache.home.lan` 502s — hardware, not config.** Evidence chain:
   - `lsblk` / `/dev/disk/by-id/` show ZERO Toshiba/SanDisk devices → all four DAS disks gone.
   - `/proc/mounts` shows only the autofs stub for `/mnt/buildcache`; `/mnt/pool` is unmounted.
   - `journalctl -u atticd` shows repeated `Dependency failed for atticd.service` → `RequiresMountsFor` on `/mnt/pool/services/atticd/storage` fails because the pool is down.
   - `attic.nix:153` confirms this is **by-design fail-loud** (detached DAS must fail the unit, never write NARs to the root fs). The 502s are the correct consequence of atticd being down.
   - `fetch https://cache.home.lan/nix-cache-info` → still 502 at report time (atticd down).

5. **Confirmed the outage is already being surfaced.** Gatus has an "Attic Binary Cache" check (`gatus-config.nix:595-606`, gated on `attic-config.enable`) that is red while atticd is down. The concurrent session's phantom-green fix series (commits `b1296c38` → `3aa2856f`) also hardened the `system_lan_nic_present` Gatus condition to the anchored form (`[BODY] != pat(*system_lan_nic_present 0\n*)` + presence check) so the HELP-comment collision can't mask a real 0.

## b) PARTIALLY DONE

1. **My own fix attempt — superseded by the concurrent session.** I prepared a multiedit (eval-level `lib.optionalString (cfg.lanInterface != "")` gating) but the file changed under me; the committed fix uses the simpler shell-variable form. The build is unblocked either way. My gating idea (skip metric emission when `lanInterface = ""`) was NOT adopted — see e(1).

2. **The DAS drop itself is unresolved** (out of my control): pool + buildcache still offline, atticd still down, cache 502ing. Recovery is physical (reseat cable + enclosure power + reboot), per the concurrent session's runbook in `docs/status/2026-08-22_01-46_das-usb-drop-gatus-phantom-green-fix.md`.

## c) NOT STARTED (observed, out of scope for a diagnosis session)

1. **No code changes authored by me this session** — the fix was already committed; I verified rather than re-fixed.
2. **`lanInterface = ""` disable path is still inconsistent** (see e(1)) — the metric and Gatus check are unconditional while the watchdog unit is gated. Not fixed because the user asked for a report, not changes.
3. **DAS-link-presence monitoring** (`system_das_link_present` from `/sys/bus/usb/devices/8-1`) does not exist yet — the concurrent doc lists it as improvement #7. We alert on consequences (buildcache 0, pool 0, attic down) but not the cause.
4. **The 00:27 freeze / memory-emergency-guard effectiveness** — the previous boot died mid-activity at 00:27 despite the guard existing. Not investigated (user said don't research unrelated stuff; concurrent doc notes the same).

## d) TOTALLY FUCKED UP

1. **Nothing in my session reached a bad end state.** The only near-miss was the mid-edit race: had I blindly re-applied my multiedit after the mod-time change, I could have clobbered the concurrent session's fix or double-applied gating. I caught it by re-reading before editing (AGENTS.md's concurrent-session rule). The tree never contained a broken checkpoint from me.

2. **The machine state itself is degraded but not broken:** DAS storage tier fully offline (backups stale, cache down, buildcache gone), root fs at 2% unallocated (`btrfs_health_critical 1` — pre-existing, documented in the concurrent doc). NVMe-only operation is stable.

## e) WHAT WE SHOULD IMPROVE

1. **`lanInterface = ""` disable path is inconsistent (concrete, fixable now).** The `lan-nic-watchdog` service + timer are gated on `cfg.lanInterface != ""` (`system-health.nix:906,921`), but the `system_lan_nic_present` metric emission (`:607-609`) and the Gatus "LAN NIC Present" check (`gatus-config.nix:1041`) are NOT gated. With `lanInterface = ""` the metric emits `system_lan_nic_present 1` (empty `$LAN_IF` → `[ -n "" ]` false → stays 1) and Gatus stays green — a phantom green exactly when the feature is disabled. Fix: wrap metric emission AND the Gatus check in `lib.optionalString`/`lib.optionals (cfg.lanInterface != "")`, mirroring the watchdog gating. This is a 2-line-per-file change.

2. **My session should have checked `git log` + grep BEFORE preparing an edit.** The concurrent fix landed between my initial grep and my multiedit. The cheap pre-edit check (`git log --oneline -3` + `grep` for the exact line) would have shown the fix already existed and saved the redundant edit attempt. AGENTS.md already warns about mid-edit races — the lesson is to make "is this already fixed in HEAD?" a mandatory pre-edit step, not just a mid-edit reflex.

3. **The phantom-green class has a structural root still open** (from the concurrent doc, echoed here): Gatus `pat()` against a whole `/metrics` body is fragile because HELP/TYPE comments share the body with values. The anchored form works; the durable fix is per-metric evaluation (Prometheus recording rules or gatus jsonpath once v5.36.0 unreliability is resolved). Every new textfile-metric + gatus pair should default to the anchored form.

4. **DAS single-link topology is the real availability bug.** All 4 external disks share USB link `8-1`. One JMicron bridge drop takes out buildcache + both pool members + both SSDs simultaneously. The recovery stack handles flaps-with-reconnect (7 recoveries this week) but a drop-without-reconnect has no software answer. A second USB path for the pool members would eliminate the single point of failure for backups.

5. **No first-class "DAS link down" alert.** We alert on consequences (buildcache 0, pool 0, attic down — three+ Discord alerts) but not the cause (usb `8-1` absent). A `system_das_link_present` metric + one Gatus check would fire one precise alert.

6. **Recovery runbook is tribal knowledge.** The reseat/power/reboot/e2fsck decision tree lives in AGENTS.md prose. A `scripts/das-link-recovery-check.sh` (read-only diagnostics + printed decision tree) would make the next occurrence faster.

## f) NEXT UP TO 50 THINGS (prioritized, session-scoped)

**Immediate (this outage):**
1. User: physically reseat DAS USB cable + enclosure power, then `sudo reboot`.
2. Post-boot: verify `findmnt /mnt/pool` and `findmnt /mnt/buildcache` return real btrfs/ext4 mounts.
3. If sda1 stays EIO after reconnect: `sudo e2fsck -y /dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1` before remount.
4. `nix run .#deploy` to ship the phantom-green fix + SC2157 fix; confirm Discord receives TRIGGERED alerts for buildcache + pool (proving the anchored patterns fire), then RESOLVED after recovery.
5. Verify gatus journal shows `success=false` for both endpoints after deploy (canary that the anchored patterns evaluate).

**Fix the `lanInterface = ""` inconsistency (my finding, ready to implement):**
6. Gate `system_lan_nic_present` metric emission on `cfg.lanInterface != ""` in `system-health.nix`.
7. Gate the Gatus "LAN NIC Present" check on the same condition in `gatus-config.nix`.
8. Add a comment noting the metric+check+watchdog must stay gated together (three-way consistency).

**Monitoring hardening (the bug class):**
9. Migrate the 4 allowlisted metrics (`btrfs_scrub_error_free`, `btrfs_emergency_reserve_present`, `backup_all_healthy`, `secret_rotation_all_fresh`) to the anchored pat form; delete the lint allowlist.
10. Add `system_das_link_present` metric (from `/sys/bus/usb/devices/8-1`) to system-health + a Gatus check, so the cause alerts once instead of N consequences.
11. Add the HELP-comment collision trap explanation to the `gatus-pattern-lint` failure message.
12. Write the pattern.Match semantics (no `!` negation, whole-string anchor, HELP collision) into AGENTS.md's Gatus section.
13. Extend `scripts/pre-deploy-check.sh` section 10 (phantom metrics) to also flag gatus conditions matching `pat(*<metric> 1*)` on metrics whose collector emits HELP text.

**Resilience:**
14. Evaluate a second USB path for the two pool Toshiba members (separate from the buildcache/SSD link) so backups survive a single bridge drop.
15. Review memory-emergency-guard thresholds/cadence against the 00:27 freeze timeline (did it trip? if not, why not?).
16. Write `scripts/das-link-recovery-check.sh` (read-only: usb tree, by-id presence, zombie mounts, e2fsck-needed heuristic, printed decision tree).
17. Consider gatus `alerting` dedup so N endpoints down from one root cause produce one Discord message, not N.

**BTRFS space (observed, pre-existing):**
18. `btrfs_health_critical 1` (unalloc 2%) needs attention independent of this incident — confirm the balance/gc-guard stack runs as designed after the pool returns.

**Process:**
19. Add "is this already fixed in HEAD?" (`git log` + grep) as a mandatory pre-edit step for any diagnosis-then-fix session — this session's redundant edit attempt is the canonical example.
20. Add "fetch and read the actual upstream source before writing pattern/config fixes" as an explicit verification step (concurrent session's near-miss is the canonical example).

(Items 21-50 intentionally left unpopulated — inventing 30 more would be noise. These 20 are real, session-grounded, and ordered.)

## g) QUESTIONS I CANNOT ANSWER MYSELF (max 3)

1. **Physical access:** Are you physically at the evo-x2 right now to reseat the DAS cable and enclosure power? If not, everything in f(1-5) blocks on your next physical visit — the machine is stable on NVMe and can run indefinitely without the pool, but backups stay stale and the cache stays down until then.

2. **e2fsck vs reformat on the buildcache:** If sda1 comes back with ext4 errors, do you want the careful path (`e2fsck -y`, keep whatever cache survives) or the fast path (`mkfs.ext4 -L buildcache`, rebuild caches — costs one full go/cargo/pnpm rebuild, zero forensic time)? Module docs bless both; only you can price time-vs-churn.

3. **Second USB path appetite:** Is there physical capacity (free USB port on a different controller, spare enclosure) to split the pool members onto their own link, or is the single-link topology a hardware constraint we must accept? This decides whether f(14) is actionable or documentation-only.
