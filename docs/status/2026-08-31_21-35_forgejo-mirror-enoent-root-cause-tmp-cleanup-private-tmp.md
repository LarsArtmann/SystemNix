# Forgejo Mirror ENOENT — Root Cause Found & Fixed (tmp-cleanup vs systemd-private-*)

**Date:** 2026-08-31 21:35
**Session scope:** Resolve TODO_LIST item "Forgejo mirror syncs spam `AddAuthCredentialHelperForRemote Error` 2,450×/day since 2026-08-18 15:28" (from the 2026-08-21 brutal self-review).
**Outcome:** ROOT CAUSE FOUND, FIXED, DEPLOYED (rode the 21:16 switch tonight), MONITORED. Several of the TODO's own claims were proven wrong along the way.

---

## 1. Investigation trail (what was checked, in order)

| # | Hypothesis | Verdict | Evidence |
|---|------------|---------|----------|
| 1 | Still happening? | YES, until Aug 30 23:03 | 4,750 error lines Aug 29-30; exactly 100/hour; last line 23:03:01; ZERO since |
| 2 | forgejo 15.0.6 → 15.0.7 fixed it (nixpkgs 9fbb54b, deploy Aug 30 22:30) | **WRONG** | Journal `_EXE` fields: the errored process (PID 1498340, Aug 28 09:33 → Aug 30 23:25) ran `forgejo-lts-15.0.7` — the SAME store path running clean today. Source diff 15.0.6↔15.0.7: **zero** changes in `modules/git/command.go` / `services/mirror/` |
| 3 | nixpkgs module hardening change | **WRONG** | `nixos/modules/services/misc/forgejo.nix` byte-identical between e5bdc4a and 9fbb54b except `MemoryDenyWriteExecute` toggle (unrelated; SystemNix already overrode it) |
| 4 | Upstream code bug | **WRONG** | `AddAuthCredentialHelperForRemote` (modules/git/command.go:455) is correct: only enters the credential branch when the remote URL has `://` AND `@`; failure is `os.CreateTemp("", "forgejo-clone-credentials-")` returning ENOENT — i.e. **`/tmp` did not resolve inside forgejo's mount namespace** |
| 5 | PrivateTmp absent from main unit (TODO's claim) | **WRONG** | Deployed unit HAS `PrivateTmp=true` (nixpkgs module). `/proc/<pid>/mountinfo` shows the private bind mount present and rw in the CURRENT (healthy) process |
| 6 | systemd-tmpfiles-clean swept /tmp | **WRONG** | Run history (daily ~06:47-07:14) does not bracket either flip moment; systemd's own cleaner also excludes `systemd-private-*` |
| 7 | **tmp-cleanup timer deleted systemd-private-\* dirs** | **ROOT CAUSE** | `scheduled-tasks.nix` tmp-cleanup (every 4h, root): globs `/tmp/*`, `rm -rf`s entries with no descendant touched in 4h — **no `systemd-private-*` exclusion** (they are NOT dotfiles, so the "dotfiles are protected" design didn't cover them). Runs at 11:11 ("removed 49") and 15:12 ("removed 1") on Aug 18 bracket the 15:28:18 onset; the forgejo unit had started 06:58 with an empty private-tmp (nothing written since boot) — precisely the "stale" profile the script deletes |

## 2. Mechanism (as far as it is proven)

- systemd's `PrivateTmp` backs each unit's `/tmp` with a host-side dir `/tmp/systemd-private-<boot-id>-<unit>-<rand>/` bind-mounted into the unit's namespace (slave of host mount group — host mount events propagate in).
- Deleting that backing dir (host-side) invalidates the private `/tmp` for the running process: from that moment every `CreateTemp` under `/tmp` fails ENOENT **until the unit restarts on a healthy host state**.
- The failure is **self-perpetuating**: failed syncs write nothing into the private tmp, so the (recreated) dir always profiles as "stale >4h" and every tmp-cleanup pass deletes it again. This is why the breakage survived ~9 boots/process restarts Aug 18–30.
- Honest caveat: the deleted-backing-dir → namespace-`/tmp`-vanishes step is proven by strong correlation (cleanup runs bracket the onset; nothing else on the box deletes `/tmp` entries; the class healed exactly when deletion stopped mattering) plus the observed ENOENT signature — the exact kernel/systemd-level unmount path was **not** reproduced live (would need a repro harness with a sacrificial PrivateTmp service). See §7 item 4.

## 3. Blast radius (corrected understanding)

- The TODO claimed "mirrors still complete". **False**: `runSync` returns `nil, false` BEFORE the git fetch on this error — every credentialed pull mirror (~100; PULL_LIMIT=50 × 2 cycles/h = the 100 errors/hour) aborted every cycle Aug 18 → Aug 30 23:03.
- `mirror.updated_unix` advances on FAILURE too (known blind spot, documented in system-health.nix) — the syncs LOOKED fresh while fetching nothing.
- All mirrors caught up in the Aug 31 ~15:02 sync wave (journal `mirror_sync_push` action for wise-go proves real commits flowed; freshest-sync age 4.7h = waiting for next 8h interval; `errors_30m=0`, `scrape_errors=0`).
- Residue: 2 repos (DynamicMinecraftNetwork, golangci-lint) still carry stale `commit-graph.lock` files from crash-killed syncs (cosmetic; syncs complete; cleanup needs root as forgejo user).
- NOT audited (out of scope, see §7): whether OTHER PrivateTmp services (~70 units) suffered silent damage during the same window.

## 4. Changes made (all shipped)

1. **Fix** — `platforms/nixos/system/scheduled-tasks.nix` (tmp-cleanup loop): skip `/tmp/systemd-private-*` entries before the staleness check, with a why-comment citing the incident. Behavior-tested (see §5). Format-clean. **Deployed** by the 21:16:25 switch tonight (nixpkgs 20260829.d2f6794 generation) — verified present in the RUNNING system's tmp-cleanup script.
2. **TODO_LIST.md** — item marked `[x]` with the full corrected root-cause narrative and the three corrections to its original claims.
3. **AGENTS.md** — new Systemd gotcha bullet: "NEVER let any /tmp cleaner touch `systemd-private-*`" with the full mechanism, the diagnosis traps, and the monitoring's blind spot.

## 5. Verification performed

- `nix flake check --no-build` → **all checks passed** (assertions forced; aarch64-darwin omission expected).
- Script derivation builds (writeShellApplication shellcheck passes); deployed script inspected — guard present.
- Behavioral test of the loop logic with aged fixtures: stale junk (mtime Aug 1) REMOVED; identically-aged `systemd-private-*` dirs SURVIVE; fresh-content dirs survive. (The identically-aged junk removal doubles as the negative control proving the guard is load-bearing.)
- Live metrics verified: all 5 `system_forgejo_mirror_*` gauges present, scrape_errors 0, errors_30m 0, stalled 0, freshest age 4.7h.
- Gatus "Forgejo Mirror Sync" check confirmed in gatus-config.nix with 3 fail-closed pat() conditions + Discord runbook alert.

## 6. What was NOT done / process misses (honest accounting)

1. **No VM/regression test added** — repo convention for exactly this class (test-hermes.nix perms-walk regression, test-attic.nix) would be a NixOS VM test running the real tmp-cleanup unit against a fake `systemd-private-*` fixture. My behavioral test ran a hand-copied loop, not the built derivation inside the unit — the standalone-copy-vs-real-artifact trap AGENTS.md warns about (signoz-query-lint lesson). The built script WAS inspected but not executed against fixtures.
2. **No eval-time/lint regression guard** — the fix is comment-protected only. The repo pattern (udev-block-letter-audit, gatus-pattern-lint) would put an eval-time check that rejects any future `/tmp/*`-globbing cleaner without the exclusion. Not built.
3. **Mechanism not reproduced live** (see §2 caveat).
4. **Deploy was initially deferred** by me out of parallel-session caution; in fact the 21:16 switch shipped it anyway — my "deferred, not live" statement in the previous message was already stale minutes later. Status now verified live.
5. **Parallel-session flag came late** — the tree grew docker-prune/sops/home.nix/crush.yaml changes mid-session; I only surfaced that in the final summary instead of immediately (AGENTS.md asks for immediate flagging).
6. The 50-vs-100 errors/hour detail (last batch = PULL_LIMIT cap) was inferred, not exhaustively verified.

## 7. Improvement candidates (prioritized)

1. **Eval-time audit** (new `tmp-cleaner-audit.nix` or extend an existing audit): assert every systemd unit whose ExecStart references a script globbing `/tmp/*` also references `systemd-private-` — machine-enforced regression cover for the whole class.
2. **VM regression test** (`tests/`): run tmp-cleanup in a VM with an aged fake private dir; assert survival + junk removal.
3. **Blast-radius sweep**: journal-grep the Aug 18–30 window for other services' ENOENT/`no such file` temp-file failures (any PrivateTmp consumer with >4h idle gaps was exposed).
4. **Live repro harness** (one-off, root): sacrificial `PrivateTmp=true` sleep service + delete its backing dir → confirms/denies the kernel-level unmount path and whether `TemporaryFileSystem=/tmp` would be a stronger per-unit hardening for /tmp-critical services like forgejo.
5. Root cleanup of the 2 stale `commit-graph.lock` files (user, needs sudo).
6. Consider whether the 4h tmp-cleanup timer is still worth its risk now that /tmp is a boot-wiped 48G tmpfs (cleanOnBoot) — the marginal value is intra-boot junk only.

## 8. Monitoring state (already shipped by Aug 22 sessions; verified live this session)

- `system_forgejo_mirror_{scrape_errors,last_sync_age_seconds,sync_stalled,errors_30m,erroring}` via system-health textfile collector (fail-closed on DB read errors).
- Gatus "Forgejo Mirror Sync" (5m interval, 3 fail-closed body conditions, Discord alert with runbook text).
- Known blind spot (documented, accepted): `updated_unix` advances on failed syncs → DB-age metric alone cannot see fetch-failure storms; only `errors_30m` can.
