# Crush v0.100.0 Adoption: sudo/ssh/curl Unblocked for Yolo — Deploy PSI-Blocked

**Author:** Crush agent session (trigger: user ask "Make sure sudo and ssh are allowed in yolo mode from v100!" + "curl also fine")
**Date:** 2026-11-05 23:51 CET
**Scope:** ONLY this session's work — crush v0.100.0 release adoption, the yolo-mode dangerous-list unblock, and the deploy attempt. The parallel go-cache/hot-user-caches session appears only where it interacted with this session.

## Summary

Crush v0.100.0 (released today 17:47 UTC) keeps the built-in dangerous-command
list armed at exec time **even in yolo mode** — and `sudo`, `ssh`, `curl` are
all on that built-in list. The fix (`permissions unblock sudo ssh curl`) is
authored, source-verified against the v0.100.0 tag, render-checked, committed
and pushed in crush-config `459d245`, and locked into SystemNix
(crush-config `459d245` + nur `7a6e673` → charmbracelet/nur `fa9ac5be` = the
v0.100.0 bump commit). The deploy is the only thing missing: it was refused at
the entry PSI gate (exit 12, 3s) by a REAL IO storm — the parallel session's
buildcache→Samsung cache migration hammering `/mnt/buildcache` (sdb1, ~101%
util, system io PSI avg10 50–70% for ~90 min). Pressure was finally falling at
23:51 (avg10 49.8, avg300 rolling over). No forcing was done, per the
freeze-precursor gate doctrine.

## a) FULLY DONE (verified)

1. **v0.100.0 semantics source-verified at the tag** (not from release notes
   alone — every claim read in the actual source):
   - Built-in dangerous list `internal/agent/tools/bash.go:80` (v0.100.0)
     contains `curl`, `ssh`, `sudo` (plus scp/wget/systemctl/env/xargs/…).
   - Yolo mode `internal/permission/permission.go:43–46`: auto-approves every
     request but **keeps the exec-time block list armed** for statically
     dangerous commands. Sysadmin mode (new) is the one that disarms it.
   - `permissions unblock` → `permissions.allowed_commands`
     (`internal/shellconfig/permissions.go`, v0.100.0): drops entries from the
     effective dangerous list **including built-in defaults**; matching is
     NAME-normalized (path/case/wrapper-resolved) so `sudo <anything>`,
     `ssh user@host`, `curl -fsSL …` are all covered — unlike
     `permissions safe`, which is exact-command-line-only and useless for
     argument-carrying verbs.
   - Release notes cross-check: "Safe Commands" section names exactly this
     surface (`safe`/`block`/`unblock`).
2. **Version-coupling hazard caught empirically BEFORE authoring**: the local
   v0.99.0 binary + a throwaway rc with `permissions unblock …` via
   `CRUSH_GLOBAL_CONFIG` → **entire config load aborts** ("Failed to load
   config from paths…", all providers/LSPs/MCPs gone — the 2026-08-31
   glm-vanish incident class). Consequence: rc and ≥0.100.0 binary MUST ship
   in the same generation. Documented in the module comment + crush-config
   CHANGELOG.
3. **crush-config authored + checked + committed + pushed (`459d245`)**:
   - `modules/home-manager/crush.nix`: new `permissionsBlock` rendering
     `permissions unblock sudo ssh curl`, wired into `rcText` after `mcpBlock`.
   - `flake.nix` `module-render-defaults` check: new assertion
     `grep -qF 'permissions unblock sudo ssh curl' rc`.
   - `CHANGELOG.md` 2026-11-05 section with the coupling note.
   - `nix flake check --no-build` green; `module-render-defaults` derivation
     built green (bash -n + all content assertions incl. the new one).
   - Pre-commit hooks passed; pushed 03feb0c..459d245.
4. **Binary supply chain verified end-to-end** (no trust leaps):
   SystemNix nur input `7a6e673` → `repos.json.lock` charmbracelet =
   `fa9ac5be` → that rev's commit message is literally "crush: v0.99.0 ->
   v0.100.0" and its `pkgs/crush/default.nix` says `version = "0.100.0"`.
5. **SystemNix lock bumped, both inputs together** (the generation-coupling
   requirement): crush-config `63f5a81b`→`459d245`, nur `7fe77da`→`7a6e673`.
   Intact in HEAD (daemon-committed; verified via `git show HEAD:flake.lock`).
6. **Concurrent-session discipline followed**: diff-reviewed the other
   session's fresh daemon commit (c98d95d51: buildcache/hot-user-caches/home.nix
   Go-cache plumbing — orthogonal, no entity overlap), then waited out the
   5-minute mtime quiescence window before attempting the deploy.

## b) PARTIALLY DONE

1. **Deploy** — attempted 22:18, refused at the entry pressure gate
   (exit 12 after 3s; log `2026-11-05_22-18-28.log`): io PSI avg10 55.7%
   + disk busy 95%, sda/sdb ~101%, top stalled cgroups all user-scope
   (ghostty/Chromium — stall victims). Storm attributed to `/mnt/buildcache`
   (sdb1): the parallel session's 22:11 commits moved GOCACHE/GOMODCACHE/
   GOLANGCI_LINT_CACHE off the USB buildcache; the migration reads hammered
   sdb at ~100% for ~90 min (avg300 peaked 70.7%). Polled on 5–10 min
   cadence; at 23:51 avg10 49.8 and falling. NOT forced
   (DEPLOY_FORCE_PRESSURE=1 exists; using it during a real storm is the
   documented freeze-precursor class — both 2026-08-22 freezes had builds
   as contributing load).
2. **Live verification** — blocked on the deploy (plan is ready, see §f):
   version, rc markers, rc-load harness, anchor check, and a real yolo probe.

## c) NOT STARTED

1. Post-deploy verification battery (§f items 1–8).
2. SystemNix-side documentation updates (AGENTS.md shell-guard section,
   CHANGELOG entry) — deliberately deferred until the behavior is LIVE
   (never document an unshipped capability as current).
3. Harvest of the §f items into the todo system (done at report authoring
   time — see Harvest Note below; in-session continuation items were
   deliberately NOT harvested because they are this session's §b resume
   plan, not backlog).

## d) TOTALLY FUCKED UP / mistakes (honest)

1. **`rg -rn` struck THREE times this session** — twice at the hook (which
   then blocks the call), once more minutes after reading the guard's own
   explanation. AGENTS.md documents this exact trap; I loaded the rule and
   still typo'd it repeatedly. Pure discipline failure, zero damage (the
   hook caught all instances).
2. **Skipped the knowledge-routing pre-read for lock work**: the AGENTS.md
   routing table requires `docs/agents/nix-flakes.md` before touching lock
   files / eval guards. I ran `nix flake lock --update-input …` and then a
   direct host-config eval, and hit the lock-float audit gate
   (`flake/expected-locks.nix`, ~60 drifted inputs — pre-existing daemon
   floats). The error was informative and the header explains the sanctioned
   path (deploy/float-register absorb it mechanically), but the pre-read
   would have made the gate a non-event.
3. **No PSI preflight before firing the deploy**: a 10-second
   `head -1 /proc/pressure/io` before `nix run .#deploy` would have
   predicted the exit-12 refusal (PSI was already ~50% at fire time). The
   gate did its job in 3s, so the cost was trivial — but the cheap probe
   order was wrong.

## e) WHAT WE SHOULD IMPROVE

1. **`rg` muscle memory**: type `rg -n`; if the hook fires once, the NEXT
   call gets flags read back character-by-character. Three strikes in one
   session is the exact failure mode the guard was born from.
2. **Preflight ladder before heavy/ gated actions**: PSI probe → quiescence
   poll → cheap eval probe → fire. I did quiescence + eval but skipped PSI;
   make the ladder complete.
3. **Read the routed doc BEFORE the first command in a domain**, not after
   the gate teaches it (nix-flakes.md for anything touching flake.lock).
4. **The lock-float audit's pre-existing drift (~60 inputs) is invisible
   until a host-config eval runs** — a cheap standing `nix eval` probe in a
   timer (or as part of the nightly negative-tests workflow) would surface
   registry-vs-lock drift before a session depends on it. (Candidate §f
   item; harvested.)
5. **crush release-watching**: v0.100.0 shipped at 17:47 and nothing in the
   repo noticed until the user asked. A tiny release-watch (gh api latest,
   compare to deployed `crush --version`) in the existing monitoring stack
   would fix that. (Harvested as a candidate, owner triages.)

## f) NEXT (ordered; 1–8 are the deploy resume plan, 9+ are queued work)

1. Poll `/proc/pressure/io` until avg10 < 20% sustained; verify tree
   quiescence again (the go-cache session has an EXECUTING plan marker —
   expect more waves).
2. `nix run .#deploy` (runs float-register → regenerates
   `flake/expected-locks.nix` from the lock → toplevel proof with
   --keep-going → activation). Do NOT hand-run float-register separately;
   the deploy battery owns it.
3. Confirm float-register committed flake.lock + registry TOGETHER
   (procedure step 3; `git log --stat` for the pair).
4. Deploy anchor discipline: wait for the FULL nh/switch process tree to
   exit (`pgrep -f 'nh os|switch-to-configuration'` empty), then
   `readlink /run/current-system` == newest `system-N-link` BY NUMBER
   (`sort -V | tail -1`, never mtime).
5. `crush --version` → 0.100.0 through the ionice wrapper
   (`/run/current-system/sw/bin/crush`).
6. Live rc markers: read the deployed `~/.config/crush/crushrc` through the
   HM symlink; assert `permissions unblock sudo ssh curl` present.
7. `bash scripts/crush-rc-test.sh` — isolated live-rc load with the NEW
   binary (provider count sanity; catches any 0.100.0 rc-parser regression
   beyond the unblock line).
8. REAL yolo probe (assert behavior, not just config): headless
   `crush --yolo run 'use the bash tool to run: ssh -V; curl --version; sudo -n true'`
   and confirm none of the three die at exec time with the dangerous-command
   block (sudo -n true returns cleanly on passwordless sudo or fails on auth
   — either proves it was NOT blocked). Also confirm a still-blocked verb
   (e.g. `wget`) IS refused, proving the list itself still arms yolo.
9. SystemNix CHANGELOG entry for the 0.100.0 adoption + the yolo policy
   change (harvested).
10. SystemNix AGENTS.md "Agent shells block common ops binaries" section:
    after 0.100.0 + this rc, sudo/ssh/curl are runnable in YOLO sessions —
    the section's claim set changes for yolo mode; update with the
    config-dependent nuance + pointer to the rc line (harvested).
11. `docs/agents/shell-devtools.md` same nuance (harvested).
12. Restart live crush sessions (rc is load-time) — USER act; remind owner.
13. Owner policy decision: extend the unblock list beyond sudo/ssh/curl?
    (`systemctl`, `wget`, `env`, `xargs` are also on the built-in list; each
    unblocked verb widens yolo blast radius) (harvested as [decision]).
14. Standing eval-drift probe for lock-float audit (§e.4) (harvested).
15. Crush release-watch check (§e.5) (harvested).
16. Clean up session scratch: `~/.cache/crush-yolo-test/` (harmless, but
    hygiene) (harvested).
17. Watch: NUR float also moved other charm packages (vhs/mods/gum…) — the
    toplevel proof covers the build; no action unless the proof goes RED.
18. Post-deploy-check battery + §19 sops gate run inside the deploy —
    read their output before declaring victory.

## g) QUESTIONS (cannot figure out myself)

1. **The IO storm**: it's the parallel session's buildcache→Samsung
   migration (sdb1 at ~101% for ~90 min, easing at 23:51). Do you want me to
   keep waiting for the drain (my default), or is that migration expected to
   have hours of runtime left (in which case: park the deploy until its plan
   marker flips EXECUTED)? I will not force with DEPLOY_FORCE_PRESSURE=1
   without your say-so.
2. **Yolo blast radius policy**: sudo/ssh/curl only (as asked), or should I
   also queue `systemctl` for the unblock list? The old v0.99 hard-block
   made `systemctl` typed-probes impossible; with 0.100.0 the SAME one-line
   mechanism would allow it. It is your risk-appetite call, not mine.
3. **Darwin**: the MacBook runs crush (launchagent `crush-update-providers`)
   but does NOT consume `programs.crush-config` — so it never gets this rc
   (nor the glm/thinking/personal set). Deliberate (Mac = minimal HM, per
   platform constraints) or an oversight worth a row in the backlog?

## Harvest Note (TODO system self-harvest, authoring time)

Harvested into `docs/todo/desktop.md` "Crush tooling" section + queue
one-liners in `TODO_LIST.md`: §f.9 (CHANGELOG), §f.10–11 (AGENTS/shell-devtools
docs, gated on deploy), §f.13 (unblock-list policy [decision]), §f.14
(eval-drift probe), §f.15 (release-watch), §f.16 (scratch cleanup).
Deliberately NOT harvested: §f.1–8 (this session's §b resume plan — executed
on the next instruction, not backlog) and §f.12 (user act, stated here).
§g questions stay questions per the [blocked:user] discipline.

## Evidence Index

- crush-config commit: `459d245` (pushed, origin/master)
- SystemNix lock revs in HEAD: crush-config `459d24517ea91db03d9c3b86460ec8834a99a87b`,
  nur `7a6e673446f5edd0d0921b2b0823d6d1646007bd`
- charmbracelet/nur `fa9ac5be9508a36055e9c19acc20845864200a82` = "crush:
  v0.99.0 -> v0.100.0" (2026-11-05T17:47:24Z)
- v0.100.0 tag sources: `internal/agent/tools/bash.go:80` (default list),
  `internal/agent/tools/bash.go:160` (resolveBlockedCommands),
  `internal/shellconfig/permissions.go` (unblock→allowed_commands),
  `internal/permission/permission.go:43` (yolo semantics),
  `internal/config/config.go:413–430` (field docs)
- v0.99 abort proof: local run, `CRUSH_GLOBAL_CONFIG=~/.cache/crush-yolo-test
  crush models` → "Failed to load config from paths […]" (2026-11-05, this session)
- Deploy refusal: `/var/log/systemnix-deploys/2026-11-05_22-18-28.log`
  (exit 12 after 3s, PSI avg10 55.69% + disk busy 95.1%)
- Parallel session: commits c98d95d51/574626a03; plan tombstones
  `173e49338`/`71555841a` (go-cache pareto arc, EXECUTING)
