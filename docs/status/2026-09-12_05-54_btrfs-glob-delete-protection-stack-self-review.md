# Session Status — BTRFS Glob-Delete Protection Stack (Self-Review)

**Date:** 2026-09-12 05:54 CEST · **Host:** evo-x2 · **Scope:** this session only
**Trigger:** user asked "how do I stop myself from running `sudo btrfs subvolume delete … @.20260*` when I meant `du`?" — i.e. the go-signal for the protection stack pending since the 03:30 incident report (`2026-09-12_03-30_qlc-enospc-cliff-snapshot-glob-loss-incremental-chain-recovery.md`).
**Format note:** written as `.md` per explicit user instruction (status-report skill default is HTML — override honored, not propagated).

---

## Live state at session start (05:15, verified)

- `/mnt/btrfs-root/.snapshots/` still EMPTY (glob-delete aftermath; next btrbk run tonight 23:00 = the unavoidable full re-send)
- No `.rescue/` tier existed; emergency reserve still absent (`btrfs_emergency_reserve_present 0` since ~Sep 7)
- Root fs recovered: 403G/723G used, 68.5 GiB unallocated, `btrfs_health_critical 0`
- Memory healthy (77G avail) → VM test builds safe

---

## a) FULLY DONE

1. **`services.btrfs-rescue` module** (`platforms/nixos/system/btrfs-rescue.nix`, NEW) — daily 22:30 (before btrbk 23:00) + boot/deploy-run (wantedBy multi-user) read-only snapshots of `@` into `/mnt/btrfs-root/.rescue/`, total `keep = 2`, dir pinned `chattr +a`, **per-run self-test** that append-only still blocks the subvol-delete ioctl (verdict stamped to `/var/lib/btrfs-rescue/protection` → `btrfs_rescue_append_only` metric; kernel regression = red check, never phantom). Caps: `CAP_SYS_ADMIN CAP_LINUX_IMMUTABLE`, `ProtectSystem=false` (balance-service precedent), harden+oneshot defaults, start-limit, onFailure.
2. **Wiring** — imported + enabled in `platforms/nixos/system/configuration.nix` with incident comment.
3. **Tripwire metrics** (`btrfs-health.nix` collector) — `btrfs_root_snapshots`, `btrfs_rescue_snapshots` (glob-loop counters, fail-closed: unreadable dir = 0 = alert), `btrfs_rescue_append_only` from the stamp.
4. **Two anchored Gatus checks** (`gatus-config.nix`, "Filesystem" group, 10m) — "BTRFS Snapshot Canary" (zero root snapshots = chain anchor + rollback window gone; alert text explains the 23:00 self-heal) and "BTRFS Rescue Snapshots" (count>0 AND append-only verified). Anchored `\n` pat() form per repo doctrine; gatus-pattern-lint passes.
5. **Fish guard** (`platforms/common/programs/fish.nix`, `btrfsGuardHook` via interactiveShellInit) — `sudo`/`btrfs … subvolume delete` (incl. `sub del`-style unique-prefix abbreviations) and `rm`/`mv`/`trash` on `.snapshots`/`.rescue` paths print the **post-glob-expansion** target list and require typing `delete`. Handles sudo flag stripping (incl. value flags `-u/-g/…`). Scripts/bash/non-interactive fish untouched. **Live-tested 5/5**: incident command aborts; `du` (the intended command) passes silently; `sub del` extraction works; `rm -rf .snapshots` aborts; passthrough functions defined. This matters doubly because sudo is PASSWORDLESS here (`sudo.nix`) — it was the only confirmation layer that existed at all.
6. **VM test** (`tests/test-btrbk-rescue.nix`, registered in `tests/default.nix`) — **PASSING** against a real btrfs disk: boot-run creates 1 rescue snapshot + stamp=1; **independent kernel-semantics proof: `btrfs subvolume delete` inside the +a dir FAILS as root and the snapshot survives**; snapshot captures @ content (canary.txt); rotation: 3 fakes + run → exactly 2, fakes pruned; no probe leftovers.
7. **Verification stack for everything above** — `nix flake check --no-build` PASS; evo-x2 toplevel EVALS and **BUILDS** (`--keep-going` clean — this also build-proved the collector's shellcheck gate and the fish/gatus renders, which the VM test alone did NOT cover); `nix fmt -- --ci`: 0 changed.
8. **AGENTS.md** — added the incident + protection-stack + incremental-chain doctrine block (incl. "never `incremental strict`"); FIXED two stale claims found last session: "`/nix` lives INSIDE `@`" (false since the Sep-5/7 Samsung flip) and "retention 3d+1w" (actual: `min 2d` floor + `3d 1w`).
9. **TODO_LIST** — Phase 1 row updated with the 2026-09-12 ENOSPC cliff + incident + still-pending user-side ops.
10. **Reserve check phantom-suspicion RESOLVED** — "BTRFS Emergency Reserve" is live and evaluating `success=false` every 10 min (633 journal hits since Sep 8). The check works; the fact that 5 days of red went unnoticed is an alert-*delivery*/fatigue question, not a phantom check.

## b) PARTIALLY DONE

1. **Fish guard automation** — manual /tmp tests only; nothing in `tests/` persists the behavior, so a future fish.nix refactor can silently rot the guard.
2. **Guard coverage gaps (known, unfixed)** — (i) btrfs GLOBAL flags between `btrfs` and `subvolume` (`sudo btrfs -q sub del …`) break the token-walk detection; (ii) flags AFTER the delete token (e.g. `--verbose`) get listed as "paths" (cosmetic); (iii) `sudo -i` / `sudo -s` drop into an unguarded root bash — inherent, can only be narrowed, never closed; (iv) clearing the flag itself (`sudo chattr -a /mnt/btrfs-root/.rescue`) is unguarded — that's the disarm step of the whole tier.
3. **Deploy-time convergence of the rescue unit** — boot-run proven in the VM; deploy-time start relies on stc starting newly-wanted multi-user units (same pattern as btrfs-emergency-reserve) — reasoned, not yet observed live. First deploy verifies.
4. **Alert delivery for the 5-day reserve red** — confirmed the CHECK evaluates red; did NOT confirm Discord delivery or why the user never noticed.

## c) NOT STARTED (identified this session, deliberately deferred)

1. `chattr -a` disarm confirmation in the fish guard.
2. Protection for the **/data leg** (`/data/.snapshots` — the only local rollback for /data!) and the **pool leg** (`/mnt/pool/.snapshots`) — same glob-delete class, zero coverage added.
3. Post-deploy smoke additions (post-deploy-check.sh): `.rescue` non-empty, stamp=1, unit active.
4. Fish guard test harness (test-scripts.nix pattern or a build-time check).
5. `system-health` `monitoredServices` entry for `btrfs-rescue-snapshot` (onFailure alerting exists in the module; the systemd-state metrics don't track the unit).
6. SigNoz/panel visibility for the three new metrics (Gatus-only right now).
7. deploy.sh restart-list decision documented (deliberately absent — see b.3).

## d) TOTALLY FUCKED UP (session errors — ALL caught by gates, zero reached production)

1. **Module lambda missing `config`** — `cfg = config.services.btrfs-rescue` crashed flake check. Caught by the cheap `--no-build` gate. Sloppy boilerplate.
2. **shellcheck SC2010 (`ls | grep`) written TWICE in one session** — rescue script AND the collector addition. One wasted VM build; the collector instance I caught by reasoning, not by a gate — and its build gate stayed UNVERIFIED until the closing toplevel build (a deploy could have hit it if I'd stopped after the VM test). Same anti-pattern twice = not a typo, a blind spot.
3. **Two unescaped `${` in Nix indented strings** (`${#snapshots[@]}`, `${snapshots[@]:0:prune_count}`) — bash array expansions parsed as Nix antiquotation; two more failed builds. The `''${` escape rule is documented all over this repo (`''${UNALLOC_PCT:-0}`) and I still paid for it twice.
4. **Stale job-output read** — fetched the old background build's output (shell 030) while diagnosing the new one and briefly treated a stale error as current. No damage, but the "independently verify tool output" rule exists exactly for this.
5. **Verification-order miss (the important one):** I declared the collector change "done" on eval + formatting evidence while its shellcheck build gate had never run — the VM test doesn't import btrfs-health.nix and `--no-build` doesn't run builders. Discovered during THIS self-review and closed with the toplevel build. Had the session ended one hour earlier, the claim "all green" would have been one shellcheck warning away from a blocked deploy.

## e) WHAT WE SHOULD IMPROVE (process, from d)

1. **Pre-build embedded-shell lint pass**: before any build, grep the diff for `ls -1? .* \| grep` (SC2010) and `[^']\$\{` (unescaped antiquotation). Both classes are documented; both still cost builds. A `scripts/audit-embedded-shell.sh` pre-commit hook would mechanize it (same shape as `audit-shell-nullglob.sh`).
2. **Never declare an embedded writeShellApplication change done on eval-only evidence** — its real gate is the BUILD. A one-liner habit: build the script derivation (or the consuming toplevel) before the summary sentence.
3. **Persist interactive-shell guards in tests** — the fish guard is the only layer standing between the operator and the exact incident; it currently survives on zero automated proof.
4. **Alert-delivery observability**: a check red for 5 days with nobody noticing means red ≠ seen. Either a periodic "still red after N days" re-notify escalation or a daily digest — the sev1-bridge already has per-key cooldowns to build on.
5. **Protect ALL snapshot legs or say so loudly**: the /data leg remains glob-vulnerable; if it matters, extend the rescue pattern or at least add count canaries (`btrfs_data_snapshots`).

## f) NEXT (session-scoped, impact-sorted — not a repo-wide harvest)

**P0 — user actions / tonight:**
1. `nix run .#deploy` (activates the whole stack; rescue tier converges at activation)
2. Post-deploy verify: `systemctl status btrfs-rescue-snapshot` (active, stamp=1), `ls /mnt/btrfs-root/.rescue/` (≥1), metrics present; open a NEW fish terminal and dry-run the guard
3. EXPECT exactly one red window: "BTRFS Snapshot Canary" until 23:00 (true state, self-heals)
4. Tomorrow: verify the 23:00 full send + chain re-anchor (`journalctl -u btrbk-root --since "2026-09-12 23:00"`, incremental `>>>` lines)
5. `sudo systemctl start btrfs-emergency-reserve` (5 days absent; check confirmed red over it)
6. Attic store-rebuild sanity → `sudo btrfs subvolume delete /mnt/btrfs-root/@nix` (118G)
7. Confirm the reserve alert actually DELIVERED to Discord over the last 5 days (gatus journal vs channel)

**P1 — hardening this stack:**
8. Fish guard: chattr -a/-i disarm confirmation on `.rescue`/`.snapshots`
9. Fish guard: tolerate btrfs global flags before the subcommand; filter post-delete flags from the path list
10. Fish guard test harness (build-time; source the hook text into fish -c cases)
11. /data + pool snapshot legs: count canaries first (`btrfs_data_snapshots`, `btrfs_pool_snapshots`), rescue tier for /data if wanted
12. post-deploy-check.sh §: rescue unit active + `.rescue` non-empty + stamp=1 + fish hook present in rendered config
13. `scripts/audit-embedded-shell.sh` pre-commit gate (SC2010 + unescaped `${` classes)
14. Observe + document whether stc starts the rescue unit at deploy (b.3) — if not, add to deploy.sh restart list per AGENTS rule
15. system-health `monitoredServices` += btrfs-rescue-snapshot

**P2 — polish/observability:**
16. SigNoz panel (snapshot counts + append-only gauge history)
17. `.rescue` extent-size metric (`compsite`-based) to quantify the pinning cost of keep=2
18. Consider keep=3 after observing a week of rotation
19. Alert-fatigue audit: enumerate checks red >48h (one-off script) — the reserve case is the template
20. docs runbook: fold the rescue tier + guard + canary into a `docs/services/btrfs.md` (currently the knowledge lives in AGENTS.md only)
21. Re-check the three prior-session open questions' status in TODO (deleted-contents inventory, timing, go/no-go — #3 now answered by this session)

## g) QUESTIONS (cannot figure out myself)

1. **The ~205G you deleted besides the snapshots (contents still unknown):** everything deleted from `@` before ~02:20 today exists pool-side (Sep-11 23:00 receive, `target_preserve_min all`) — so nothing unique was lost. Want me to reconstruct WHAT you deleted (du-diff `@` vs the pool's `@.20260911T2300` receive) so you can sanity-check it was all intentional?
2. **Timing of the two pending sudo ops:** delete `@nix` + re-provision the reserve NOW (my recommendation — neither touches tonight's send; @nix frees 118G, reserve writes 10G against 297G free), or after tonight's 23:00 full send?
3. **Guard friction preference:** extend the confirmation to `chattr -a` on the protected dirs (the disarm step) and/or to the /data + pool snapshot legs — or keep it minimal (root subvol + `.snapshots`/`.rescue` only)?

---

**Honesty check:** every "PASSING/DONE" claim above is backed by a command run this session (VM test log inspected line-by-line; toplevel build completed; fmt `0 changed`; guard cases executed). The one claim I initially made WITHOUT full evidence (collector "done" on eval-only) is documented in d.5 and closed. Nothing else is asserted beyond what was observed.

*Session closed — WAITING FOR INSTRUCTIONS.*
