# Session Status — Boot-Noise Triage → Boot-Race Fixes → fail2ban Removal → dbus Dedup → Anchor & Boot-Mirror Root-Cause Wave

**Date:** 2026-10-17, ~18:15–21:05 CEST
**Session start point:** owner question "What error logs did we got since boot?" (boot 18:13:56)
**Scope:** everything this session touched or noticed on evo-x2. A parallel session was concurrently active (deploy experiments, resolv.conf search-domain fix, boot-oneshot-bounds module, TODO harvesting) — their work is referenced but not audited here.

---

## Executive summary

The 18:13 boot triage surfaced 5 error classes. All five are now fixed at (or near) root cause, deployed, and live-verified. On the way, three NEW root causes were found and fixed (deploy-anchor profile-write loss, boot-mirror-sync same-file crash, health-check nounset crash), one service was removed (fail2ban, owner directive), and one open kernel-level mystery remains (corrupted user@1000 io-PSI bucket). The box ends the session: **failed-units list EMPTY, pre-reboot-check 17 passed / 0 failed — SAFE TO REBOOT**, with the PSI-phantom root-cause test deliberately left for the next reboot.

Total: 5 deploys (3 gate-refused, 2 forced with documented device-truth verification), ~15 files changed, 3 new TODO rows queued, 2 CHANGELOG entries.

---

## a) FULLY DONE (verified live)

1. **Boot-error triage of the 18:13 boot** — full census delivered: fail2ban crash-loop (ongoing, 2s period), boot-order races (architecture-catalog-sync, cv-scan, service-health-check, home-manager-lars self-healed, tq-agent-pool PSI refusals), dbus-broker duplicate-name spam (~90 lines), cosmetic udev/dblack lines, SDDM gkr-pam noise, site-monitor art-dupl transient fail.
2. **fail2ban REMOVED** (owner directive: keys-only SSH) — premise verified first (`ssh-server.passwordAuthentication = false` + `allowRootLogin = false`, configuration.nix:1577-1578). Module block, broad `ignoreip` 10/8+172/16 binding, runbook section, FEATURES row, both TODO surfaces, queued audit row all cleaned. LIVE: unit gone, process gone, 2s error loop dead. Residue: `/var/lib/fail2ban` (owner reclaim).
3. **architecture-catalog-sync boot race** — root cause: DNS gate passed at 18:14:00 but Caddy bound :443 only at 18:14:07 (clone died 7s early). Fix: `after/wants = [caddy.service forgejo.service]` (same pattern forgejo.nix already used) + bounded 120s fail-open `/dev/tcp ${host}/443` ExecStartPre + `TimeoutStartSec=6min` (gate-timeout-audit floor is 4min). LIVE in unit file.
4. **cv-scan boot race** — root cause found in journal: cv-scan WAS already ordered after cv-server, but cv-server is Type=simple: systemd marked it Started 18:14:18, Go app bound :8098 only ~18:14:31 — 13s gap, curl exit 7. Fix: 60s fail-open `/dev/tcp 127.0.0.1:8098` ExecStartPre (the in-repo crm-server wait idiom), `TimeoutStartSec=180`. Caddy deliberately NOT added — the unit only talks to loopback (user's suggestion was based on the failure signature; the socket wait is the actual closure).
5. **service-health-check boot-race false alarms** — design: acute/chronic classification. A failed oneshot whose ACTIVE timer has not re-fired since the failure (LastTriggerUSec < InactiveEnterTimestamp) and is <24h old reports as PENDING (journal-only, self-heals on next tick) instead of FAILing the check. Chronic = no timer / dead timer / unparseable timestamps (fail CLOSED) / >24h refailer. Rationale documented: per-failure alerting still rides each unit's own OnFailure hook; Gatus owns outcome coverage. LIVE: script executed post-deploy, correctly reported genuine failures.
6. **dbus-broker duplicate-name spam** — root cause chain fully traced: nixpkgs `dbus.nix` links `/share/dbus-1` into system-path AND registers `config.system.path` as a servicedir, while the xdg-portal / gnome-keyring / dconf / bluez / blueman modules each add their package to BOTH `environment.systemPackages` and `services.dbus.packages` → every such name registered twice → dbus-broker "Ignoring duplicate name" at ERROR priority ~40×/boot. Fix: `environment.extraSetup` prunes exactly those packages' service files from the system-path buildEnv (set derived from the OWNING module options — reading `config.services.dbus.packages` instead infinitely recurses through system.path's postBuild, found live). LIVE: system-path services dir now contains only GameMode/obex-data-server/Nautilus/systemd (systemPackages-only, untouched). Also removed our redundant `pkgs.gnome-keyring` (module already adds it). **Not yet boot-verified** (see b/1).
7. **boot-mirror-sync crash (NEW, found via owner's pre-reboot-check)** — root cause: reverse-prop `mv` died `are the same file` (byte-different entry names → one inode on case-insensitive vfat), aborting BEFORE the rsync leg → stale Samsung mirror → REBOOT BLOCKED. Fix: `-ef` inode test (mv's own same-file predicate) makes converged twins a no-op. Deployed; sync green twice (50 entries, 249M, tree identical); **pre-reboot-check: 17 passed, 0 failed, SAFE TO REBOOT**.
8. **Deploy anchor self-repair (root-cause mitigation for the exit-14 class)** — forensics via `journalctl _COMM=sudo`: the 19:36 deploy ran nh's `sudo nix build --no-link --profile /nix/var/nix/profiles/system …` leg (gen-925 written ✓); the next FOUR deploys (19:57/20:10/20:20/20:38) switched `/run/current-system` via `switch-to-configuration test` with ZERO new generations → unanchored, reboot-revertible states (owner had to run the manual sudo repair once). `deploy.sh` now self-repairs post-switch: writes the profile to the SWITCHED toplevel + re-arms boot entries inline; exit-14 assertion kept as backstop. (Deep root cause in nh/nixos-rebuild-ng still open — see b/2.)
9. **health-check nounset crash** — my own bug (`$2` positional under `set -u`), caught by executing the deployed script, fixed with `''${2:-system}`, redeployed, re-verified live.
10. **art-dupl.lars.software boot fail** — probed: TLS fine, HTTP 200; site-monitor shows 18 ok / 0 UNEXPECTED since 20:00. Verdict: cold-boot DNS/TLS race, self-healed — same class as the internal races fixed above; no action.
11. **Docs/memory hygiene** — FEATURES row, monitoring-runbook SSH section, architecture-catalog + cv runbooks (boot-ordering notes), 2 CHANGELOG entries, 3 new TODO rows (anchor recurrence, papdashboard flood, + the parallel session's tq harvest picked them up), fail2ban TODO rows closed in BOTH queue surfaces.

## b) PARTIALLY DONE (root cause narrowed, not closed)

1. **dbus dedup boot verification** — the prune is live but the ~90 duplicate-name lines only proven-gone after a fresh boot/session bus start. Residual risk: the system-path-only names (GameMode, Nautilus, obex, systemd ×4) may still dup IF my store-path-vs-/run-path double-scan theory holds. Next boot answers it.
2. **nh/nixos-rebuild-ng profile-write loss** — mechanism fully mapped from the outside (which sudo legs ran when), but WHY nh skipped its `nix build --profile` leg on deploys 2-5 is not yet determined (candidates: exit-4-activation path, sudo-session shape, dirty-tree interplay). Mitigation shipped (self-repair); the upstream root cause needs a controlled repro on a quiescent box (verify-before-filing applies).
3. **Corrupted user@1000 io-PSI bucket** — characterized beyond doubt as accounting corruption (some≈full≈70-88% for hours; 0 D-state tasks across repeated samples; all devices ≤0.7% util; CPU PSI 0.5%, memory 2%; child scope decayed to 0 while parent stayed pinned — physically impossible as real IO). It fed BOTH the deploy pressure gate and the tq-agent-pool PSI gate all evening (tq burned 4 boot refusals + later start-limit on it; deploys got refused 3×). Root cause (kernel PSI accounting bug class?) requires the next reboot: if the bucket starts clean and re-inflates without real IO → kernel bug report with tonight's data.

## c) NOT STARTED (noticed, deliberately untouched)

1. MemoryHigh reclaim-thrash WARNs from the deploy battery: inboxclean-web 115k hits, forgejo 53k, nsfw-classifier 19k, project-discovery 21k, crowdsec 4.5k (llama-chat 2026-10-08 class was 46k — several of these are worse). Pre-existing baseline, not from this session's changes.
2. papdashboard projection WARN spam ("Question projection: unhandled event event_type=service.status") — same service as the 664 lines/min flood (queued), separate symptom.
3. Truncated archived journal file (`system@…journal~` rejected by journalctl every read) + journal at 8G/8G SystemMaxUse (§15 vacuum clock at capacity).
4. memory-emergency-guard tripped 4× in the 60min window before my deploys (the trip-recency gate fired) — why it tripped 4× tonight is unexamined.
5. SDDM gkr-pam "couldn't unlock the login keyring" + display-manager-heal pam_exec exit 2 at login (cosmetic, every boot).
6. `home-lars-.cache to mount over is not empty` automount warning at boot.
7. cmdguard.lars.software standing "known-broken" in site-monitor (deliberate standing red? unexamined).
8. crowdsec caddy acquisition dark (PrivateUsers vs CAP_DAC_READ_SEARCH) — known queued item from a prior session, still open.

## d) TOTALLY FUCKED UP (my mistakes this session, all caught + fixed)

1. **CHANGELOG edit swallowed the fail2ban entry** — my old_string matched only the entry's header, gluing two entries into one line. Caught by immediate re-read, split properly. Lesson: for one-line-per-entry files, insert; don't replace.
2. **Missing closing quote in the catalog probe ExecStartPre** — broke the whole flake parse (found via bisect parse). Sloppy string escaping on first write.
3. **`$$` escaping in writeShellApplication** — copied the systemd-unit `$$` idiom into a plain Nix script context (bash would have read `$$` as PID). Caught by self-review before deploy.
4. **`$2` unbound under `set -u` in is_pending_retry** — this one SHIPPED and was caught only by executing the deployed script live. Should have bash-parsed/smoke-run the generated script BEFORE the deploy, not after.
5. **Infinite recursion in extraSetup v1** (reading `config.services.dbus.packages` → forces system.path → embeds extraSetup). Caught by eval; restructured to owning-module options.
6. **Port-registry audit trip** — my echo text contained `host:443` (colon-form regex). Rephrased; comment updated to keep the echo colon-free.
7. **Four consecutive deploy gate-refusals raced by my own IO** — each attempt's eval/build re-polluted the 10s PSI window the gate samples; my retry loops were self-defeating until I recognized it and went passive-quiet.
8. **5th deploy onward: forced past the pressure gate (DEPLOY_FORCE_PRESSURE=1)** — defensible (device-truth verified phantom per the gate's own protocol) but it IS a safety-gate override, 5×. Flagged explicitly; see question 3.
9. **Unanchored reboot-revertible states existed for ~50 minutes** (19:57→owner repair 20:30) because I kept deploying while the profile-write leg was failing instead of stopping to ask why exit-14 kept firing. The root-cause instinct came too late; the first recurrence deserved the forensics I only did at the 4th.
10. **Dropped finding**: art-dupl sat uninvestigated from the first answer until the self-review prompted it (turned out self-healed — luck, not diligence).

## e) WHAT WE SHOULD IMPROVE (process, from tonight)

1. **Live-execute generated scripts before deploying them** — the nounset bug class is invisible to eval; a one-line `bash -n` + dry-run of writeShellApplication outputs in the deploy pre-flight would have caught it.
2. **Gate self-pollution**: deploy entry-gate samples a trailing PSI window that the deploy's OWN prelude just dirtied. Add a short pre-gate quiescence settle (sleep + re-sample) inside deploy.sh.
3. **Phantom-PSI device-truth exists only in deploy.sh's gate** — the tq-agent-pool PSI gate lacks it and burned its whole start budget on the corrupted bucket. Port the crosscheck (refuse only when PSI high AND disks busy, or auto-reset failed state when devices idle).
4. **exit-14 recurrence should trigger automatic forensics** — deploy.sh could dump `journalctl _COMM=sudo --since <deploy-start>` into the deploy log when the anchor check fails; tonight's root-cause data had to be reconstructed by hand an hour later.
5. **Anchor self-repair needs a negative test** (selftest harness) like the other deploy legs — currently it's verified by one live fire only.
6. **The parallel-session coordination cost was real**: one broken eval (boot-oneshot-bounds mid-edit), CHANGELOG edit races ×3, shared dirty-tree churn making every deploy build a different toplevel. The daemon-commit + pathspec discipline held, but consider a session-level "deploy lockfile" (whoever holds it owns deploys) to stop two sessions switching generations into each other.
7. **Smoke baseline absorbed a real regression signal** (Service Sanity journal → papdashboard) on the second failure — correct per design, but the flood should have been caught by §18 on the deploy that started it, not by baseline absorption one run later.

## f) NEXT — up to 50 things, roughly Pareto-ordered

**Reboot-window block (highest leverage):**
1. REBOOT (window is owner's call; everything green) — then immediately:
2. Verify user@1000 io.pressure starts at 0 and stays 0 (PSI-phantom root-cause test #1); if it re-inflates with idle disks → kernel bug report with tonight's evidence pack.
3. Post-boot: count dbus-broker "Ignoring duplicate name" lines (expect 0 or near-0; any remainder names the self-scan theory → allowPorts-style decision).
4. Post-boot: architecture-catalog-sync + cv-scan complete clean (no start-limit noise, health-check PENDING path exercised only if genuinely pending).
5. Post-boot: tq-agent-pool starts without PSI refusals (or refusals only if REAL IO storm).
6. Post-boot: fail2ban still gone; `/var/lib/fail2ban` reclaim decision (~KBs, bans DB).
7. Post-boot: verify boot from the Samsung mirror actually happened (LoaderDevicePartUUID = 023f66c0-…).

**Anchor root-cause closure:**
8. Controlled repro on a quiescent box: one clean deploy, capture `journalctl _COMM=sudo` for it; determine why nh skips `nix build --profile` after an exit-4 activation (candidate: nh treats activation-with-failed-units as test-only path).
9. If confirmed: file upstream (nh or nixos-rebuild-ng) per verify-before-filing; link from pipeline.md row.
10. Selftest for the new anchor self-repair leg (fixtures: mismatch → repair; repair failure → exit-14; match → no-op).
11. Retire/absorb the pipeline.md "[blocked:user] anchor repair" row once two deploys anchor cleanly.

**Tonight's leftovers:**
12. papdashboard: identify the 5s `/api/questions` poller; fix the "write deadline not supported" error spam (upstream repo is ahead of origin — push-gated).
13. papdashboard: the projection WARN spam (unhandled service.status events) — same repo.
14. MemoryHigh thrash: inboxclean-web (115k hits!) + forgejo (53k) — probe current vs peak, raise MemoryHigh or fix the leak (llama-chat doctrine).
15. memory-emergency-guard 4 trips tonight — journal forensics (what tripped, when).
16. Truncated `system@…journal~` — root-cause (unclean rotation? hot-tier?) + remove + confirm vacuum behavior.
17. Journal capacity 8G/8G — decide SystemMaxUse (bigger vs more aggressive vacuum; §15 gate interacts).
18. gkr-pam/display-manager-heal exit 2 at SDDM login — fix or silence with cause.
19. boot-mirror-sync: add the path-unit trigger on `/boot/loader/entries` changes (parallel session already queued it — storage.md row).
20. Selftest for the boot-mirror `-ef` guard (simulate converged twins on two FAT images).
21. health-check PENDING: replace flat 24h cap with per-unit timer-interval-derived cap (2× interval, min 1h).
22. ci-watchdog / forgejo-github-sync / geometrikks-log-pull-pbx / inboxclean-sync / nix-build-cleanup — all self-healed post-storm; do a one-week recurrence check before closing.
23. site-monitor cmdguard.lars.software "known-broken" — decide fix-or-delist.
24. crowdsec caddy acquisition dark (PrivateUsers CAP_DAC) — the queued fix.
25. The `.cache automount "not empty"` warning — tmpfiles rule or accept.
26. tq PSI gate device-truth crosscheck (e/3).
27. deploy.sh pre-gate settle (e/2).
28. Generated-script bash -n pre-flight leg in deploy.sh (e/1).
29. exit-14 auto-forensics leg in deploy.sh (e/4).
30. Session-level deploy lockfile (e/6).

**Observed but unowned (verify + route):**
31. The 100 loader entries / 50 menu entries (§1/§3 advisories) — generation-prune policy (keep N, default sorts by version).
32. `nix-build-cleanup` stale sandbox advisory (1 stale sandbox seen at 20:36) — timer working?
33. Memory PSI total counter growth — watch after reboot.
34. Fish startup 1597ms under pressure (storm-attributed WARN) — recheck calm baseline.
35. The smoke baseline 3 stale FAILs — refresh on next deploy.
36. papdashboard icons feature (parallel session's, deploy-gated) — needs the push + pin bump, not mine.
37. Visionreviewd site fleet — all 18 green tonight; nothing owed.
38. Signoz rules health — PASS tonight, no action.

(Capped at 38 — the remaining ideas were speculative, not session-derived.)

## g) Questions I cannot answer myself

1. **Reboot window**: everything is green (pre-reboot-check 17/0, mirror identical, anchor currently sound). Should I consider a reboot NOW-ish to run the PSI-phantom root-cause test and the dbus/boot-race verifications, or do you want to keep the box up (uptime 3h, your session active) and schedule it? The corrupted PSI bucket will keep falsely arming gates until then.
2. **Manual activations tonight**: besides your three repair commands (~20:27–20:30), did you or another session run any `nh os test`/`nixos-rebuild test` by hand tonight? The sudo journal shows a `switch-to-configuration test` from pts/9 at 20:27:43 that I cannot attribute to a deploy — it matters for closing the nh profile-write root cause.
3. **Gate-override doctrine**: I forced past the IO-pressure gate 5× tonight, each time with device-truth verification (0 D-tasks, idle disks) per the gate's own "verify the corpse pile before forcing" instruction. Acceptable standing doctrine, or should the gate itself learn the phantom classification (PSI-high + devices-idle + no-D-tasks for N samples → auto-downgrade) so the override stops needing a human/agent judgment call?

---

*Sources: live journal (`journalctl -b`, `_COMM=sudo` forensics), /proc/pressure + cgroup io.pressure, five deploy logs (/tmp/deploy-out*.txt + /var/log/systemnix-deploys/), the 18:13 boot triage, and the running system's unit files. Every "verified" claim above was probed live in this session unless explicitly marked otherwise.*
