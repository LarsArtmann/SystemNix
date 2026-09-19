# Samsung 2nd Boot Disk — Session 2: Queue Death, Eval-Blocker Fix, Parallel Deploy In Flight (Self-Review Status)

**Date:** 2026-09-19 09:48 · **Session:** continuation of 2026-09-18_20-48 · **Predecessor report:** `docs/status/2026-09-18_20-48_samsung-2nd-boot-disk-mirror-built-deploy-queued.md`

---

## Executive Summary

The overnight deploy queue **died silently** — the tmp-cleaner ate the poll script + log from `/tmp` (>4 h stale rule) and the background shell died with the session end. Nothing deployed overnight (profile still `system-785`, 16:32 yesterday, predates our code). No reboot happened.

This morning I found a **second, independent deploy blocker**: a parallel session's `llama-vlm.nix` (committed 08:54) declared `modelPath`/`mmprojPath` as `lib.types.path` with unquoted `/data/...` literals — forbidden in pure eval, killing **every** deploy at eval time. Fixed surgically (`types.str` + quoted strings, semantics identical — the values are only ever string-interpolated into ExecStart args). evo-x2 eval green again.

At 09:46 the IO-pressure gate went green for the first time (avg10 13–18 %) and my queue v2 fired — into **rc=13: another deploy already holds the lock** (PID 1721988, started 09:40, a parallel session's deploy). That deploy builds the CURRENT tree, which contains **all of our boot-mirror work plus my llama-vlm fix** (daemon-committed at `f0cfff20` 09:26). It is plausibly the carrier for our module. An observer shell (`04B`) is recording its outcome; no further action is being taken.

---

## a) FULLY DONE

1. **All boot-mirror code** (committed yesterday at `260f86ef`, still byte-intact, verified via `git log 260f86ef..HEAD -- <our files>` = empty):
   - `platforms/nixos/system/boot-mirror.nix` — mount + `boot-mirror-sync` converger + `diff -r` drift gate
   - `scripts/boot-mirror-activate.sh` — self-elevating, idempotent NVRAM flip (findmnt-derived devices, PARTUUID matching)
   - `scripts/pre-reboot-check.sh` §11 — mirror audit, severity escalates after activation
   - `scripts/deploy.sh` provisioner-loop entry, `flake.nix` app + efibootmgr runtimeInput
   - `configuration.nix` import, AGENTS.md runbook, plan doc, yesterday's status report
2. **Static verification** (yesterday): `nix flake check --no-build` PASS, evo-x2 eval PASS, both wrapped scripts shellcheck-green via pre-built drvs, activate-script parse-logic fixture-tested (4 scenarios).
3. **This session — dead-queue diagnosis**: root-caused in minutes (tmp-cleaner + session death), not a mystery.
4. **This session — llama-vlm eval blocker fixed**: `types.path` → `types.str` (+ comment why: multi-GB runtime files, store-copy is wrong) and 4 path literals quoted in configuration.nix. Eval re-verified green. Daemon-committed `f0cfff20`.
5. **Queue v2 established**: inline poller (no script file to eat), log at `~/.local/state/boot-mirror-deploy.log` (cleaner-proof), 6 h window, rc≠12 stops for diagnosis. It worked exactly as designed — and surfaced the parallel deploy within seconds of firing.

## b) PARTIALLY DONE

1. **Deploy** — gate green at 09:46, fired, hit rc=13 (lock held by parallel deploy, still running at 09:47, ~7 min elapsed). Outcome pending observer `04B`. If the parallel deploy succeeds, our module ships with it (tree HEAD carries everything); if it fails, re-queue.
2. **Live mirror verification** — blocked on that deploy completing (findmnt, unit journal, tree parity, SAMSUNG-EFI by-uuid mount).
3. **CHANGELOG.md entry** — not started (deliberately last, after post-reboot proof).

## c) NOT STARTED

1. `nix run .#boot-mirror-activate` (NVRAM: create `Linux Boot Manager (Samsung)`, BootOrder mirror-first) — needs deployed unit first.
2. `nix run .#pre-reboot-check` runs (§11 WARN-grade pre-activation, FAIL-grade post-activation).
3. Reboot (user decision — 3 questions from yesterday still unanswered).
4. Post-reboot verification (`bootctl status` → Current = Samsung PARTUUID `023f66c0-…`; chain green).
5. Plan-doc checklist items 6–9 closeout.
6. AGENTS.md gotcha entries for today's lessons (see d/e).

## d) TOTALLY FUCKED UP (own goals, no external blame)

1. **The overnight queue was a silent-failure trap I built myself.** I parked an operational script AND its log in `/tmp` — the tmp-cleaner (>4 h staleness, documented in this very repo's AGENTS.md, the forgejo 12-day-outage bullet) ate both; the background shell died when the session ended; no heartbeat, no deadline-lapse signal, nothing. Discovered 11 h after the 22:55 deadline only because the user pinged. I violated known repo doctrine the same day I had read it.
2. **Fire-and-forget background job with zero liveness signal.** A queue whose entire purpose is "act unattended" must leave a persistent trace and a way to learn it gave up. Mine left neither (the one thing it left — the log — was in the one directory guaranteed to be cleaned).
3. **rc=13 missing from the retry set.** deploy.sh's lock-contention exit (13) is exactly as transient as the pressure gate (12); my queue treated it as fatal. I wrote the queue without re-reading deploy.sh's full exit-code surface. Silver lining: stopping was safer than blind-retrying into another session's deploy.
4. **Minor: stale-read edit race.** First edit to configuration.nix bounced ("modified since read") because I hadn't re-read after overnight daemon commits. Recovered correctly (fresh view → exact match), but the re-read-before-edit discipline is documented and I skipped it.

## e) WHAT WE SHOULD IMPROVE (process, from this session)

1. **Never park operational scripts/logs in `/tmp`** — use `~/.local/state/` (cleaner ignores home) or `/run` (volatile by design, honest). This is a recurrence of a documented class; deserves an AGENTS.md line.
2. **Unattended jobs need a heartbeat + a "gave up" breadcrumb** that survives: persistent log + a final line with the resume command (queue v2 does this).
3. **Deploy-queue retry set = {12 gate, 13 lock}**; everything else stops for diagnosis.
4. **A queue that fires into a lock-held state should detect "someone else is shipping my work"** as a healthy outcome to observe, not an error.
5. **Eval-time lint candidate:** reject unquoted absolute path literals (`/data`, `/mnt`, …) in NixOS config values, or at least `types.path` options that get `/data`-style values — the llama-vlm class cost a morning of blocked deploys for every session on this box.
6. **Document deploy.sh exit codes** in one greppable place (header comment) so queue authors don't guess.

## f) Next — up to 50, scoped to this workstream

1. Wait for parallel deploy (observer `04B` logging to `~/.local/state/boot-mirror-deploy.log`)
2. On completion: check deploy rc + `system-786+` profile exists
3. Verify anchoring: `readlink /run/current-system` == `readlink /nix/var/nix/profiles/system` (exit-4 skip-profile class)
4. `findmnt /boot-mirror` — mounted, by-uuid `4F53-C156`, vfat
5. Confirm `boot-mirror-sync.service` ran (deploy.sh provisioner loop restarts it post-switch)
6. Spot-check mirror tree: `loader/loader.conf`, `EFI/systemd/systemd-bootx64.efi` present (the stale Sep-9 copy had neither)
7. Full drift gate proof: unit's own `diff -r` passed (journal) — no manual diff needed
8. Check `\EFI\BOOT\BOOTX64.EFI` now exists on mirror (bootctl fallback path → the inert `UEFI OS` 0x000B entry becomes a bonus third boot path)
9. ESP free space on Samsung p1 (4 G, kernels duplicated from QLC ESP)
10. Record current nvme0/nvme1 mapping for the report (they flip; findmnt truth only)
11. Run `nix run .#pre-reboot-check` — §11 WARN-grade green (mirror present, not yet first)
12. Dump `efibootmgr -v` (read-only) for the pre-activation baseline
13. Run `nix run .#boot-mirror-activate` — must end "✓ firmware now boots the Samsung mirror first"
14. Verify BootOrder: Samsung entry first, QLC `Linux Boot Manager` 0x0001 preserved as second
15. Re-run `pre-reboot-check` — §11 now FAIL-grade and green
16. **USER: reboot decision** (3 unanswered questions below)
17. Post-reboot: `bootctl status` — Current Boot Loader = PARTUUID `023f66c0-…`
18. Post-reboot: `pre-reboot-check` green end-to-end
19. Post-reboot: `post-deploy-check` optional full sweep
20. Post-reboot: one-time firmware boot-menu test that QLC fallback entry still boots (F8/F11/F12)
21. Watch guard Zone 6 during any switch in residual storm (btrbk churn re-arm semantics)
22. CHANGELOG.md entry
23. Tick plan-doc checklist items 6–9 (`docs/planning/2026-09-18_19-53_…PARETO-PLAN.md`)
24. AGENTS.md: tmp-cleaner recurrence lesson + queue-v2 pattern (persistent log, retry set, observer)
25. AGENTS.md: llama-vlm eval-blocker class (types.path vs absolute /data literals)
26. Add pointer from the 2026-09-18 report to this one (its "In flight" section references the dead /tmp script)
27. Evaluate: mirror freshness Gatus check vs system-health unit monitoring (extraMonitoredServices may suffice — the unit's diff gate fails LOUD via onFailure)
28. If parallel deploy FAILED: re-queue (queue v2 one-liner, log path known) after diagnosing whose failure
29. If parallel deploy exit-4'd on boot-mirror-sync start: fix module, re-deploy (known recoverable risk from yesterday's report)
30. Confirm daemon did not batch unrelated files into any future explicit commit (pathspec discipline — `git show --stat HEAD` before amending anything)
31. Post-activation: stale-mirror recovery drill documented (systemctl restart boot-mirror-sync) — no action, just runbook awareness
32. Scope decision (question 3): root `@` migration off QLC = separate task, own plan doc
33. Someday: pre-reboot-check could assert mirror sync freshness (unit ran within N hours)
34. Someday: `nix build` of the whole toplevel BEFORE pressure windows (pre-warm cache so switches are short) — the e554fab nixpkgs bump makes this build long
35. Noted, not mine: `programs.rofi.extraConfig` rename warning (pre-existing debt, rofi.nix)
36. Noted, not mine: `_forgejo-scripts.nix` dirty file from another session (still uncommitted at yesterday's snapshot)

## g) Questions I CANNOT answer myself

1. **Reboot timing** (unchanged from yesterday): once gates are green + activation done, WHEN do you want the reboot? It kills your desktop session — I will not reboot autonomously.
2. **The parallel deploy running right now (PID 1721988, started 09:40)** — do you want me to treat it as the carrier for the boot-mirror module (verify its outcome and proceed to activation), or re-run our own deploy after it finishes regardless?
3. **End-state scope** (unchanged): is ESP + `/nix` offload the finish line, or do you want root `@` migrated off the QLC next (full QLC-death survival = separate task)?

---

## Technical Context (carried forward)

- **Disk truth (live this session):** QLC = nvme1n1 (root, 100 % util in storm), Samsung = nvme0n1 (idle). nvme0/nvme1 flip across boots — all code derives devices from `findmnt`, never kernel names.
- **Firmware:** `Linux Boot Manager` 0x0001 on QLC ESP boots now; `UEFI OS` 0x000B on Samsung p1 inert until mirror creates `\EFI\BOOT\BOOTX64.EFI`.
- **Deploy gate:** exit 12 = pressure, exit 13 = lock contention (learned live this session).
- **Locks/logs:** deploy lock `/tmp/.systemnix-deploy.lock` (flock, PID-written); queue/observer log `~/.local/state/boot-mirror-deploy.log`.
- **Session commits:** our work `260f86ef` (yesterday) → llama-vlm fix daemon-committed `f0cfff20` 09:26 → daemon continues (HEAD `1ac795bc`).

## Verdict

Net progress this session: one blocker fixed (llama-vlm), one silent failure converted into a visible, persistent, retry-correct queue, and the deploy is — through no plan of mine — likely in flight via a parallel session carrying our module. Everything activation-side remains ready and untouched. Waiting for instructions.
