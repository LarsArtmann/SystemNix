# Startup Error Review — Boot Failures Diagnosed & Fixed, Deploy Pipeline Blocked by bank-sync FOD

**Session:** 2026-08-22 ~06:00–08:55 CEST
**Task:** "Review all startup errors" — inventory every boot-time error on the 05:55 boot, root-cause, fix in Nix, deploy, verify.
**Host state at start:** boot fe625d01 (05:55:36), DAS entirely offline (pool Toshiba ×2, both SanDisks, buildcache SSD ALL absent from lsblk), load 13.95, zram-only swap.

---

## Self-Critique — What I Forgot / Did Wrong / Could Do Better

1. **Did not check `git log`/`git status` at session start** while concurrent sessions were actively committing (memory-guard, forgejo-mirror, dnsblockd-H2 sessions all landed 06:13–06:33). I discovered the interleaving only when the first deploy failed on files I never touched. My first five edits got batched by the auto-commit daemon into OTHER sessions' commits (`fd56f3ab`, `9f240824`) — attribution blurred. The AGENTS.md concurrent-session rule exists precisely for this; I applied it reactively, not proactively.
2. **Shipped shellcheck-invalid bash.** My first `dms-wallpaper-init` rewrite used `[ "$out" != "No running instances"* ]` — SC2081 (glob in single brackets) — which `writeShellApplication` rejects AT BUILD TIME. That cost a full deploy cycle (build 26s → fail → rewrite → redeploy). I even attempted to pre-build the derivation, failed to locate it quickly, and gambled on the full deploy instead of pinning it down.
3. **Wasted a deploy cycle on a no-op lock resync.** For the bank-sync vendorHash mismatch I ran `nix flake lock --update-input bank-sync` (produced zero diff — root cause not understood), then redeployed anyway → same FOD failure. I also never captured the `got:` hash from the failed FOD build log, which is the documented recovery currency for exactly this class.
4. **Did not update AGENTS.md / gotchas** with the four durable lessons from this session (memory-maintenance protocol violation — the other sessions wrote status docs; I wrote none until now).
5. **Smoke-verification gaps:** I proved `certutil` import works manually as lars (proving perms fix), but the `dnsblockd-cert-import` unit itself hasn't re-run since (it fires on graphical-session start; next login exercises it). Same for the rewritten `dms-wallpaper-init` script — the "DMS wallpaper IPC responding" smoke PASS tests DMS, not my script.
6. **Noticed but didn't investigate:** attic binary cache 502s (`cache.home.lan/monitor365/*.narinfo`) — almost certainly attic storage living on the offline pool; left unexplained in the deploy logs.

---

## a) FULLY DONE (verified live on the deployed 06:44 generation)

| # | Failure (05:55 boot)                                                                                                                                                                                      | Root cause                                                                                                                                                                                                                                                                                                                         | Fix                                                                                                                                                                                                                                                                                        | Live verification                                                                                                                           |
| - | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | browser-history, oauth2-proxy, gatus, papdashboard-ingest chain all FAILED at 05:57:52 + OnFailure Discord alerts                                                                                         | **Caddy was ordered `after`/`wants` oauth2-proxy**, whose ExecStartPre OIDC gate probes `https://auth.home.lan/...` — served BY Caddy. Deadlock for the gate's full 120s timeout; Caddy "Started" 2min05s into boot, one second after the gates gave up. Every gated consumer failed its first start, then self-healed on restart. | Removed oauth2-proxy from Caddy's after/wants (`modules/nixos/services/caddy.nix`, comment documents the deadlock). Cost: a few seconds of 502s on external forward-auth paths at boot; LAN bypass unaffected.                                                                             | `/etc/systemd/system/caddy.service.d/overrides.conf` now reads `After=pocket-id.service sops-nix.service atticd.service` (no oauth2-proxy). |
| 2 | `dnsblockd-cert-import.service` exit 255 (user unit)                                                                                                                                                      | `dnsblockd_ca_cert` sops secret was root:root **0400**; the user-unit's certutil (and Firefox `Certificates.Install` policy) got EACCES. Reproduced manually: `-5966, 13`.                                                                                                                                                         | Mode **0444** in `modules/nixos/services/sops.nix` — CA cert is public trust material by design.                                                                                                                                                                                           | `/run/secrets/dnsblockd_ca_cert` = `-r--r--r-- root root`; manual import succeeded; `dnsblockd-ca C,,` present in NSS DB.                   |
| 3 | smartd exit 16 → "Failed to start S.M.A.R.T. Daemon" → **NVMe unmonitored the whole boot**                                                                                                                | Pool Toshiba absent (DAS offline) + no `-d removable` → smartd treats missing device as fatal registration error and exits.                                                                                                                                                                                                        | `-d sat -d removable` on all 4 USB disks (`platforms/nixos/system/configuration.nix`). Verified against smartmontools 7.5 binary: `-d sat,removable` is INVALID syntax; only the separate second `-d removable` token tolerates absence.                                                   | Journal: `Monitoring 0 ATA/SATA, 0 SCSI/SAS and 1 NVMe devices` + `Started S.M.A.R.T. Daemon` — absent disks logged, not fatal.             |
| 4 | ActivityWatch server panic-loop (`Unable to create data dir: AlreadyExists` = mkdir over DANGLING symlink into offline pool) → start-limit-hit, dragging theme-setter + both watchers into crash cascades | Data dir is a symlink into `/mnt/pool` (activitywatch-data-to-pool); pool offline ⇒ dangling.                                                                                                                                                                                                                                      | `ConditionPathIsDirectory = "%h/.local/share/activitywatch"` on all 4 AW user units (`platforms/common/programs/activitywatch.nix`). Verified with `systemd-analyze condition` that systemd chases symlinks: dangling → skip, live → run. Pre-migration and pool-mounted states both pass. | Journal: all four units `skipped, unmet condition check ConditionPathIsDirectory=...` — clean per-session skip instead of panic-loop.       |
| 5 | `dms-wallpaper-init.service` exit 1 (`FATAL go: Error running IPC command: exit status 255` / "No running instances")                                                                                     | DMS IPC not yet serving 35s+ past its "Started" journal line; script FATALed the set instead of skipping.                                                                                                                                                                                                                          | Rewritten wait loop (60×1s, `case`-statement glob match — shellcheck-clean), clean exit 0 when DMS never appears; also made "no images" and "set rejected" non-fatal warnings (`platforms/nixos/desktop/niri-wrapped.nix`).                                                                | Built + activated in the 06:44 generation. Behavioral exercise pending next login (see b).                                                  |
| 6 | Pre-deploy-check phantom-metric FALSE BLOCK on `system_forgejo_mirror_*`                                                                                                                                  | Other session's new Gatus checks reference metrics the RUNNING (pre-deploy) collector didn't emit yet — pre-deploy §10 can't know they ship in THIS tree.                                                                                                                                                                          | Added the three metrics to `KNOWN_NEW_METRICS` with a removal-verification note (`scripts/pre-deploy-check.sh`).                                                                                                                                                                           | Deploy unblocked; metrics present post-switch (though currently `scrape_errors 1` — see b).                                                 |
| 7 | Full error inventory of the 05:55 boot, triaged                                                                                                                                                           | —                                                                                                                                                                                                                                                                                                                                  | 22 error classes catalogued; benign ones (dbus duplicate-name noise, gkr-pam SDDM stashed-password, iwd NSS spam) identified as no-action.                                                                                                                                                 | This document.                                                                                                                              |

Deploy at **06:44 succeeded and activated** (smoke: 63 PASS / 8 FAIL / 4 SKIP — every FAIL is pool-offline hardware fallout, see d). `nix flake check --no-build` passes.

## b) PARTIALLY DONE

1. **forgejo mirror collector read access (CAP_DAC_READ_SEARCH)** — `system-health-metrics` runs under `harden {}` (empty CapabilityBoundingSet) and as root cannot traverse forgejo's 0700 stateDir; the `-r` gate silently fail-closed `system_forgejo_mirror_scrape_errors 1`, making the brand-new "Forgejo Mirror Sync" Gatus check fire Discord alerts on a healthy forgejo (API-verified: 100+ mirrors, fresh syncs). Fix committed (`52395c47`) alongside the other session's SQLITE_BUSY `.timeout 5000` hardening, **but NOT YET ACTIVATED** — the two subsequent deploys failed on bank-sync (see d). Live metric still says `1`. Needs one successful deploy + collector cycle + Gatus-green verification, then whitelist removal.
2. **dnsblockd-cert-import unit re-verification** — perms fix proven via manual certutil run; the unit itself only re-runs on next graphical-session start.
3. **dms-wallpaper-init behavioral test** — new script deployed; exercises only at next login (needs DMS slower than 60s to prove the skip path, or a manual run).
4. **bank-sync lock subtree resync** — command executed, zero diff produced, root cause of the no-op NOT understood (see d).

## c) NOT STARTED (from this session's inventory)

- dbus duplicate-name log noise (portal/keyring/dconf services shipped in both system-path and HM profiles) — cosmetic, no functional impact.
- `gkr-pam: unable to locate daemon control file` at SDDM login — password stashed and retried later; keyring appears to work; no fix attempted.
- Helium exit 21 at 05:59 (self-healed via Restart=always within 5s; root cause not investigated).
- systemd `Timed out waiting for device …SanDisk…` repeating every ~30s all boot — inherent to DAS-offline + nofail mounts; could be quieted with `x-systemd.device-timeout=` shortening.
- attic cache 502 investigation (see e).
- Reboot E2E test proving the Caddy fix eliminates the first-start OIDC-gate failure window (everything self-heals now, but the REAL proof is a fresh boot).
- AGENTS.md gotcha entries for this session's lessons.

## d) TOTALLY FUCKED UP (current blockers)

1. **Deploy pipeline BLOCKED: bank-sync go-modules FOD hash mismatch** (`bank-sync-c1c332fb…-go-modules.drv`). Two consecutive deploy attempts (07:08, 07:12) failed with the same hash mismatch → **config NOT activated**; the cap fix, the mirror busy-timeout fix, the daemon's lock bump (`261fa827`), and everything since 06:44 is stuck in the tree. Root cause: the other session's flake.lock bump moved bank-sync (or its deliberately-unfollowed go-nix-helpers subtree) such that the vendored tree no longer matches the pinned vendorHash (vendorHash lives in bank-sync's own upstream flake). My recovery attempt (`nix flake lock --update-input bank-sync`) was a **verified no-op** (zero lock diff) and I redeployed anyway — wasted cycle. Recovery options: (a) upstream: set `vendorHash = ""` in `/home/lars/projects/bank-sync`, build, paste got-hash, tag+push, bump input; or (b) roll bank-sync input back to the last building rev.
2. **My SC2081 blunder** — one full deploy cycle burned on shellcheck-invalid script (fixed; lesson recorded).
3. **Attribution blur** — my first five fixes live inside two other sessions' commits thanks to the auto-commit daemon. Not damaging (single copies on disk, verified), but history attribution for the caddy/smartd/sops/wallpaper/AW fixes points at the wrong "authoring" commits.
4. **8 smoke FAILs on the ACTIVATED 06:44 generation** — paperless :2892 down, immich 502, banksync 502/:8097 down, attic cache check, gatus immich/paperless/attic red. ALL are direct pool-offline (DAS hardware) fallout — dataDirs and attic storage live on `/mnt/pool`. Config-correct, hardware-gated; heals when the DAS returns. Not config bugs — verified by dependency analysis, not by testing with the pool up (can't).

## e) WHAT WE SHOULD IMPROVE (systemic, from this run)

1. **Pre-deploy §11 (vendorHash freshness) does not cover bank-sync** — it warned on dnsblockd/monitor365/netwatch/emeet-pixyd/file-renamer/crush-daily as "unable to determine status" but said NOTHING about bank-sync, which then hard-failed the build. The FOD-coverage map has a gap exactly where it bit us.
2. **Deploy-time cost of config-level script errors is too high** — shellcheck runs inside `writeShellApplication` during the full system build. A cheap pre-deploy "changed writeShellApplication scripts build standalone" check (or `nix-build` of just those drvs) would have caught SC2081 in seconds.
3. **Attic binary cache on the offline pool** means every DAS-offline deploy 502-spams `cache.home.lan` and builds locally — acceptable but noisy/slow; consider marking the substituter as optional-with-short-timeout during known DAS outages.
4. **No eval-time guard for the Caddy↔oauth2-proxy ordering class** — a tiny assertion ("no unit that oauth2-proxy-gated consumers order after may itself be gated on Caddy") or a docs-level gotcha would prevent reintroduction. Same for smartd USB devices without `-d removable`.
5. **sops consumption audit for user units** — the dnsblockd_ca_cert 0400-root class could exist elsewhere (any secret read by `systemd.user.services` or browser policies). One systematic grep beats per-incident fixes.
6. **Concurrent-session discipline** — check `git log` BEFORE first edit; my own status doc should be written at fix time, not end-of-session.

## f) NEXT TASKS (prioritized)

**P0 — unblock & restore**

1. Fix bank-sync vendorHash (upstream `vendorHash = ""` → got-hash → tag → bump input) OR roll input back; capture got-hash from `nix log /nix/store/kp1xj2pbp6jnqrh8ip9djyyy7mcwpv9p-bank-sync-…-go-modules.drv` first.
2. Understand why `--update-input bank-sync` was a no-op before trusting the lock again.
3. Redeploy → activate cap fix + mirror busy-timeout + daemon's lock bump.
4. Verify `system_forgejo_mirror_scrape_errors 0` + Gatus "Forgejo Mirror Sync" green; then REMOVE the three `system_forgejo_mirror_*` whitelist entries.
5. USER (physical): reseat DAS USB cable + enclosure power, clean reboot (also clears the post-crash peripheral state per AGENTS).
6. After DAS return: verify pool mounts (both Toshiba members!), buildcache automount, btrfs-verify-pool-backups, AW units start (conditions now pass), smartd picks up 4 USB disks, paperless/immich/banksync/attic recover, Gatus flaps green.
7. Expect btrbk catch-up sends after multi-day outage — watch for OOM (known oom-kill class on /data sends).
8. Reboot E2E: confirm no first-start OIDC-gate failures (browser-history/oauth2-proxy/gatus start clean on attempt #1) and Caddy up ~1min into boot.
9. Next login: verify `dnsblockd-cert-import` unit runs clean (exit 0) under 0444 perms.
10. Next login: verify `dms-wallpaper-init` seeds or skips cleanly (no FATAL).

**P1 — close verification loops**
11. Remove stale `KNOWN_NEW_METRICS` entries once each verified live (`bank_sync_*`, `system_das_link_present`, forgejo mirror trio).
12. Verify Firefox loads the dnsblockd CA without warnings (policy path readable now).
13. Write AGENTS.md gotchas: smartd `-d sat -d removable` (NOT comma-joined); Caddy must never order behind an OIDC-gated unit; ConditionPathIsDirectory symlink-chasing as pool-absent gate; world-readable CA certs for user-unit consumers; SC2081/shellcheck pre-build lesson.
14. Update `docs/gotchas-archive.md` with the four boot-fix narratives (or cross-link the other session's docs).
15. Investigate helium exit 21 (one journal dive; self-heals but the cause is unknown).
16. Decide on quieting the SanDisk device-timeout spam (`x-systemd.device-timeout`) or accept as DAS-offline signal.
17. Run `nix-build-cleanup` for the 6 stale build sandboxes (pre-deploy warning).

**P2 — systemic hardening**
18. Extend pre-deploy §11 to cover bank-sync (and attic) FODs — map every `vendorHash`/`outputHash` in the tree.
19. Add standalone pre-build of changed `writeShellApplication` scripts to deploy.sh (or a flake check).
20. Eval-time assertion: Caddy not ordered after OIDC-gated consumers (generalize: no unit may order after a unit whose ExecStartPre probes a URL Caddy serves).
21. Eval-time assertion or lint: smartd by-id USB devices must carry `-d removable`.
22. sops audit: every secret consumed by `systemd.user.services` / browser policies must be mode ≥0444 or user-owned.
23. Per-disk presence gauges in system-health (smartd "not available" is per-device but unalerted when removable) — or a staleness alert on `system_das_link_present` duration.
24. Consider `After=dms.service`-style ordering (or DMS socket gate) for wallpaper-init instead of the 60s poll.
25. Decide substituter behavior during DAS outages (attic 502 noise vs local builds).
26. dbus portal service dedup across system-path/HM profiles (log noise only).
27. gkr-pam/SDDM keyring timing (cosmetic; verify keyring unlock UX).
28. Pre-existing P0 unchanged: /data EIO inode corruption repair (btrbk-data aborts nightly).
29. bank-sync Wise SCA window (~90d cadence) — check when service returns.
30. Consider a "boot error delta" smoke: diff `journalctl -p err -b` between boots in post-deploy-check to catch regressions like today's cluster automatically.
31. ActivityWatch pool-absence design decision: local fallback dir (data continuity) vs clean skip (current) — user call.
32. Document in AGENTS that the deploy currently 502s against attic when DAS-offline so future sessions don't misdiagnose it as an attic bug.
33. Attribution hygiene: when the daemon batches concurrent sessions, add session-tagged status docs (this one) so history stays reconstructable.

## g) QUESTIONS (cannot resolve myself)

1. **DAS hardware:** the pool Toshiba pair, both SanDisks, and the buildcache SSD are ALL offline (whole-link absence, post-crash class). Will you reseat the DAS USB cable + enclosure power and reboot — and do you want me to prep anything first (e.g. degraded-mount decision is yours per AGENTS)? Nothing pool-dependent can be verified until then.
2. **bank-sync recovery direction:** roll FORWARD (I update vendorHash in `/home/lars/projects/bank-sync`, which requires tagging/pushing upstream) or roll BACK (pin the SystemNix input to the last building rev)? Forward keeps the daemon's lock bump; back is faster but discards it.
3. **Attic during DAS outages:** leave `cache.home.lan` as a failing substituter (502 spam, forced local builds) or should the config degrade it gracefully (short timeout / temporary removal) while the pool is known-offline?

---

**State at handoff:** system runs the 06:44 generation (all five boot fixes LIVE). Deploy pipeline blocked by bank-sync FOD. DAS hardware offline pending physical reseat. No secrets touched beyond mode change of a public CA cert.
