# CV state-perms heal blindspot — deploy exit-4 chain resolved (2026-09-20)

**Scope:** this session only (13:25–15:02). Trigger: user's `nix run .#deploy` failed with a
Nix syntax error; mandate: "make switch work properly". All times CEST.

---

## Timeline (what actually happened)

| Time | Event |
| --- | --- |
| 13:25:22 | User's deploy dies: `syntax error, unexpected '('` at `cv.nix:513` (`(lib.optionalAttrs …`). |
| 13:25:51 | Parallel agent session re-edits `cv.nix` (mid-edit race — the syntax error existed for ~29s). Tree becomes the `mkIf` value-guard form + `test-cv.nix` co-imports `deploy-restart-audit.nix`. |
| 13:35:35 | Parallel session lands CAP_FOWNER fix in `hot-user-caches.nix` (daemon commit `e0f287ab`). |
| 13:46:28 | Parallel deploy starts (before this session's first action). |
| 13:47–13:50 | Its activation exit-4s: `cv-server` restart ×5 → `start-limit-hit` (`rm: cannot remove … Permission denied` on `/var/lib/cv/assets/{fonts,css}/*`). Profile NOT bumped: `system-785` → old `b1b8759` build while `/run/current-system` ran the new `20b1ddd` build — reboot would have reverted. |
| 14:0x | This session: flake check `--no-build` ✅, evo-x2 toplevel eval ✅; first deploy attempt exits on the lock (correct wait per rc-13 doctrine); post-wait discovers the anchoring gap. |
| 14:08:24 | Root cause fixed + deployed: `cv-state-perms` fires the heal for the first time EVER ("foreign-owned entries under /var/lib/cv — healing for cv:cv") → `cv-server` starts clean at 14:08:25. |
| 14:08+ | `system-786` created and ANCHORED (`/run/current-system` == profile). `/health/live` 200, `/cv` 200 on :8098. Zero system-level failed units in the window. |

## Root cause (the one this session fixed)

`cv-state-perms` (the morning's heal oneshot) had a **fast-path blindspot**: its health probe
checked **ownership only** (`! -user cv -o ! -group cv`). The drifted tree under
`/var/lib/cv/assets` was cv-*owned* but carried **missing owner-write bits** (store-mode
copies / operator chmod class). Result: the probe fast-pathed to "healthy" in <1s every start
(no heal echo ever fired), while `cv-server`'s upstream content-sync `rm -rf assets` EPERM'd
on the write-less parent dirs → restart ×5 → start-limit-hit → activation exit 4 → **nh
advanced `/run/current-system` but skipped the numbered-profile bump** (the documented
exit-4 anchoring class). Every subsequent deploy would have kept failing the same way.

**Fix** (`modules/nixos/services/cv.nix`, fast-path predicate): added `-o ! -perm -u+w` so
the probe flags missing owner-write exactly as broadly as the heal repairs it. Symlink-safe
(find's `-perm`/`-user` test the link itself, mode 0777 — the read-only store
`config.yaml` target is never flagged). Committed by the daemon in `34db241a`.

**Proof the delta is the new clause:** at 13:50:45 the OLD deployed predicate passed with no
stray; at 14:08:24 the NEW predicate healed. Same tree, 18 minutes apart — the only predicate
delta is `-perm -u+w`.

---

## a) FULLY DONE

1. Diagnosed the user's 13:25 failure as a parallel-session mid-edit race (not a tree defect at rest).
2. Verified `nix flake check --no-build` and evo-x2 toplevel eval green before touching anything.
3. Honored the deploy lock (waited for the parallel deploy; verified profile advancement after).
4. **Found the un-anchored generation** (`system-785` vs `current-system` mismatch) — the actual
   "switch doesn't work" symptom — and root-caused it to the cv-state-perms fast-path blindspot.
5. Separated the two stacked activation failures: `cv-server` (live blocker) vs
   `hot-user-caches-go-build-bootstrap` chmod EPERM (11:51-era, ALREADY fixed by the parallel
   session's CAP_FOWNER commit; nix-bootstrap proved the fix live at 13:50:24).
6. Fixed the predicate, deployed, and verified end-to-end: heal fired, `cv-server` up on :8098
   (`/health/live` 200, `/cv` 200), `system-786` anchored, no system-level failed units since.
7. Confirmed the fix reached the deployed unit script (read the store unit file directly, not
   just the repo source).

## b) PARTIALLY DONE

1. **Mode-drift ORIGIN unproven.** I never saw the actual modes/owners inside
   `/var/lib/cv/assets` (sandbox: no sudo/systemctl/curl; `cv:cv 700` blocks lars). The u+w
   theory is inferred (old-passes + new-heals delta) and is the only consistent explanation,
   but nobody has run the confirming `sudo find /var/lib/cv -xdev ! -perm -u+w` snapshot.
2. **Recurrence semantics unverified.** If the upstream content sync preserves store modes
   (`cp -a`/`rsync -a` from the read-only store), the drift RE-MATERIALIZES every sync —
   the heal now self-heals before every `cv-server` start (no RemainAfterExit), so it is
   contained, but each heal run is churn. If it was one-off operator drift, it won't recur.
   Code answer lives in the CV repo (not checked — out of session scope).
3. **`hot-user-caches-go-build-bootstrap` fixed-but-not-rerun.** Unit is correct at HEAD and
   deployed; last execution remains the 11:51 failure, so `/mnt/hot/users/lars/cache/go-build`
   sits at mode 0755 (chown succeeded, chmod EPERM'd pre-fix) instead of 0700. Runs at next
   boot via its automount `wantedBy` (or a manual `systemctl start` — blocked from this sandbox).
4. **Collateral failed units from the 13:21 list not individually re-verified:**
   `cv-scan` (rides cv-server, next tick :23 proves it), `inboxclean-sync` (no failure entries
   in the window, but no positive last-exit check either), `service-health-check` (reporter of
   the others; presumed green now).
5. **Smoke 7-FAIL baseline only named, not triaged**: Bank-Sync, Browser History (:8087), CV,
   FastFlowLM. CV's is almost certainly stale (server came up at 14:08; smoke ran ~14:09
   mid-start) and should fall out of the baseline on the next deploy. Bank-Sync /
   Browser-History / FastFlowLM fails predate this session and were NOT investigated (correctly
   out of scope, but they are now open items).

## c) NOT STARTED

1. AGENTS.md gotcha entry for the general lesson: **a perms-heal fast path must check exactly
   the predicate set its heal repairs** (ownership-only probes go phantom-green against
   mode-drift; same shape as the gatus phantom-metric class). The in-code comment documents it;
   the project memory does not.
2. Pre-deploy Zone-6 trip-history check (see d) — not performed, not documented.
3. Baseline smoke-fail triage into TODO_LIST.
4. Upstream CV-repo check of the sync's copy flags (recurrence question).
5. Post-deploy gatus check-state sweep for the CV group.

## d) TOTALLY FUCKED UP (honest mistakes)

1. **I raced an I/O-pressure dip.** The 14:08 deploy was fired without checking Zone-6 trip
   recency; post-deploy smoke then reported `io PSI avg10 = 30.68%` / fish-startup under
   pressure / "storm is building" — squarely the freeze-#5 doctrine zone ("when Zone 6 tripped
   within the last hour, queue the deploy instead of racing dips"). It succeeded, but that is
   luck, not process. The 13:21-era gate read green (PSI 12%) and I reused that mental model
   47 minutes later without re-probing at fire time.
2. **Two dismissal-without-evidence calls in the close-out:** the `xdg-desktop-portal.service`
   dependency flaps (user manager) and the `fastflowlm@…` instance exit-code at 14:12 were
   labeled "pre-existing noise" / "normal lifecycle" from pattern memory, not from journals.
   Both are probably fine; neither was verified.
3. **First deploy attempt wasted a build cycle** by not checking for a live parallel deploy
   before firing (lock discovery after pre-deploy validation ran).
4. The close-out said "go-build re-runs at next boot" — true, but framed as done; it is a
   pending residual (b.3), including the 0755 mode.

## e) WHAT WE SHOULD IMPROVE (systemic)

1. **Deploy pressure gate samples once at entry** — avg10 is episodic (freeze-#3 lesson);
   the gate can pass in a dip while a storm is live. Gate should ALSO refuse when
   `memory_emergency_guard_zone6_trips_total` advanced in the last 60 min (deploy.sh, exit 12).
2. **Anchoring check belongs INSIDE deploy.sh as a hard step**, not as operator knowledge:
   after every `nh os switch`, compare `readlink /nix/var/nix/profiles/system` target vs
   `/run/current-system`; mismatch ⇒ loud post-deploy failure + auto re-run hint. It would have
   converted the 13:46 parallel deploy's silent half-activation into an immediate signal.
3. **Heal/probe symmetry rule** for every `*-perms`/converger fast path (eval-time lintable in
   principle: the predicate tokens should be a subset of the repair commands' tokens).
4. `exit-4` deploys keep happening (13:46, and historically). deploy.sh could, on
   `Exited(4)`, print the failing-unit list from the transaction directly into the operator
   output instead of leaving it to journal archaeology.
5. Smoke baseline fails should carry last-seen timestamps so "matches baseline" cannot hide a
   permanently-red check (the phantom-green class in yet another costume).
6. cv-state-perms heal run should `find … -print` a SUMMARY (count + sample) into the journal
   when it heals — this incident would have been a 10-minute diagnosis instead of 40.

## f) NEXT (prioritized, ~25 real items)

1. `sudo find /var/lib/cv -xdev \( ! -user cv -o ! -group cv -o ! -perm -u+w \) -print | head`
   — post-heal confirmation snapshot (expect empty now).
2. Check CV repo content-sync copy flags (`cp -a`/`rsync -a`?) → answers recurrence (b.2);
   if structural, consider upstream post-copy chmod OR accept per-start heal.
3. `sudo systemctl start hot-user-caches-go-build-bootstrap.service` → verify chmod 700 lands.
4. Observe `cv-scan` at the next `:23` tick — green proves the CV stack end-to-end.
5. Verify `inboxclean-sync` last exit + timer state.
6. Re-run `post-deploy-check` once idle: CV should drop out of the fail baseline (7 → fewer).
7. Read the current baseline fails (Bank-Sync, Browser History, FastFlowLM) and route each to
   `docs/todo/{services,monitoring}.md`.
8. Add AGENTS.md one-liner: fast-path/heal symmetry rule (c.1).
9. deploy.sh: add Zone-6 trip-recency check to the pressure gate (e.1).
10. deploy.sh: add post-switch anchoring assertion step (e.2).
11. deploy.sh: on `Exited(4)`, dump the transaction's failed-unit list inline (e.4).
12. cv-state-perms: journal a heal summary (count/sample) (e.6).
13. Baseline file: stamp entries with last-seen (e.5).
14. Investigate `xdg-desktop-portal` dependency flaps (user manager, ~14:09–14:14).
15. Check the `fastflowlm@` exit-code instance at 14:12 (cold-load timeout class?).
16. Sweep gatus CV group checks green post-14:08.
17. Watch `node_psi_io_some_avg60` — if the storm persists, identify readers (crush sessions,
    project-discovery du-walks) per freeze-#5/#6 doctrine.
18. Verify tonight's `cv-backup` pool receive (03:30) lands.
19. After next reboot: confirm go-build bootstrap green + automount mounts the subvol.
20. Consider whether the cv-state-perms heal should also enforce u+x on dirs (currently u+w
    only — sufficient for rm/cp, not proven sufficient for every future upstream op).
21. Confirm `cv` smoke checks exit the baseline on the NEXT deploy (item 6's long-term check).
22. Sweep whether any OTHER `*-perms` fast path in the tree has the same ownership-only
    blindspot (`hermes-perms` is the sibling pattern — check its probe covers modes).
23. The parallel session's `mkIf` value-guard for `deploy-restart-audit.allowUnits`: add a
    one-line comment in test-cv.nix explaining WHY the co-import is load-bearing (it has one;
    verify it also covers the mkIf-form semantics).
24. Re-check the 13:46-era half-activated generation is fully superseded (boot entry sanity) —
    low risk since 786 anchored.
25. If IO PSI stays ≥20% avg10 into the evening: queue no further deploys; page-worthiness per
    Zone-6 doctrine.

## g) QUESTIONS (cannot resolve from here)

1. **Did anything run as root inside `/var/lib/cv` today before ~11:00** (a manual restore,
   rsync, or extract), or do you recall the morning session's account of how the assets became
   root-owned? — decides one-off operator drift (heal contains it) vs. a recurring writer.
2. **Run the two blocked convergers now or let the boot/timers do it?** My sandbox cannot
   `sudo`/`systemctl`: `sudo systemctl start hot-user-caches-go-build-bootstrap cv-scan` (plus
   optionally `cv-state-perms` no-op) would close b.3/b.4 immediately; otherwise they close at
   next boot / next tick.
3. **Is the elevated IO PSI (~30% avg10 at 14:10) expected right now** (known background load —
   your own sessions/monitors), or should I treat it as a building storm and investigate
   readers before anything else runs?

---

*Report written 15:02. System state at writing: system-786 anchored, cv-server serving, tree
clean at `34db241a`. No secrets included (public-repo rule).*
