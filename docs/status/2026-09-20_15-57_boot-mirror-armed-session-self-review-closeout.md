# Boot-mirror armed — session self-review & closeout (2026-09-20 15:57)

**Scope:** this session only (resumed ~15:10 after the 13:58 wait-state was lifted; report
written 15:57). Parent narrative: `2026-09-20_13-58_boot-mirror-deploy2-one-unit-left-cv-unanchored.md`
(the 11:30–13:58 deploy saga) + the parallel session's `2026-09-20_15-02_cv-state-perms-heal-deploy-blocker-fix.md`.
All times CEST.

---

## Headline

The Samsung mirror ESP is verified, armed, and FIRST in firmware BootOrder (`Boot000C*`,
QLC `0001` fallback). pre-reboot-check: **23 pass / 0 fail at the strict §11 grade**.
Profile anchored (system-787, three-way). Everything committed (`541fab97`) and pushed.
**The single remaining action on the critical path is the USER REBOOT.**

## What actually happened this session

| Time | Event |
| --- | --- |
| 15:10 | Resumed; state gather revealed the parallel session had fixed cv-server at 14:08 (`fc49dbe5` — the `-perm -u+w` fast-path fix, exactly the e.1 patch my 13:58 report proposed) and anchored system-786 → 787. My queue v7 had self-stopped at 14:00 (rc=3, NEW failure: Bank-Sync) — by design. |
| 15:1x | Mirror evidence: sync green ("OK — 8 entries, 312M mirrored"), diff gate PASS, df 312M/4.0G, FS UUID `4F53-C156`, dark-guard metrics live (2 rogue llamas detected). |
| 15:2x | pre-reboot-check: **its own derivation failed to build** (shellcheck SC1087 — unbraced `$MIRROR_DIR` before `[[:space:]]`). Fixed → exit 0, 21 pass, §11 WARN-grade. |
| 15:2x | boot-mirror-activate: **aborted before any firmware mutation** (`lsblk: unknown column: PARTNUM`). Fixed (`PARTN`) → activation succeeded: Samsung entry first, QLC second. |
| 15:2x | pre-reboot-check re-run: **23 pass / 0 fail, strict §11 grade, "SAFE TO REBOOT"**. |
| 15:3x | CHANGELOG (2 entries), plan ticks 6/7/9, session report `15-30`, pathspec commit `541fab97` (hooks green) → pushed. browser-history upstream issue #26 filed (voice-checker passed). |
| 15:5x | Self-review fact-checks: inboxclean failure age (Sep 05!), Bank-Sync 14:00 FAIL detail. |

---

## a) FULLY DONE

1. **State reconciliation**: queue verdict (rc=3/STOPPED — not the handoff's predicted rc=0
   loop), anchor state (787), cv-server health (serving, PDF export working), rogue llama
   state (still alive), git/daemon-commit state — all verified before acting.
2. **F05 anchor verification**: `readlink /nix/var/nix/profiles/system` == `/run/current-system`
   == default boot entry (three-way, pre-reboot-check §1/§4 corroborated).
3. **F06–F09 mirror evidence**: findmnt (nvme1n1p1, vfat rw), FS UUID `4F53-C156`, sync-unit
   journal green with diff-gate PASS, df 312M/4.0G, `llama_rag` dark-guard collector healthy
   (`leaked_instances 2` — the rogues ARE detected).
4. **F10**: pre-reboot-check exit 0 (after fixing its SC1087 build bug — the auditor could
   not run itself; nobody had ever built the script derivation end-to-end before).
5. **F11–F12**: `Boot000C* Linux Boot Manager (Samsung)` created on the mirror PARTUUID
   `023f66c0-…`, ordered FIRST; QLC relative order preserved; activation verified idempotent
   by the entry-match design; no partial state from the failed first run (verified §11 before
   re-running).
6. **F13**: strict-grade re-run 23/0 — armed state independently audited (BootOrder, EFI
   entry, systemd-boot install, tree identity).
7. **F14**: CHANGELOG — Added (boot-mirror armed, incl. both first-run bug fixes) + Fixed
   (the 2026-09-20 six-unit activation-blocker batch, crediting the parallel session's cv fix).
8. **F15**: Samsung plan items 6/7/9 ticked with evidence; 8 (reboot) deliberately open.
9. **F16**: pathspec commit `541fab97` (gitleaks/shellcheck/flake-check hooks all green) →
   pushed `4b0c6153..541fab97`.
10. **F17 (artifact)**: `docs/status/2026-09-20_15-30_boot-mirror-armed-samsung-first-bootorder.md`
    + chat report with M/F tables and the reboot handoff.
11. **Upstream filing**: browser-history issue #26 (empty-batch heartbeat; source-verified
    `main.go:108` early-return, `config.go:78` freshness default; github-voice checker passed).
12. **d) fact-checks for this report**: inboxclean failure onset = **Sep 05 00:05** (~16 days,
    ~48 failures/day since — NOT a fresh event); Bank-Sync 14:00 FAIL = the
    `bank_sync_sync_errors_total > 0` counter check (degraded-SCA/restart-window class,
    self-resolved by 14:58, will flap until SCA approval).

## b) PARTIALLY DONE

1. **Rogue llama handling**: detected, metric-verified, dark-guard confirmed working — but
   the SPAWNER (a hermes cron worker scope, per the 13:58 report) was never investigated, so
   nobody knows if killing PIDs 805159/805161 is durable or if the next cron fire respawns
   them. Also: these rogues hold llama-vlm's ports 8127/8128 — llama-vlm stays dark partly
   because of them (connection noted at 13:58, not chased this session).
2. **Gatus check states**: CV group + "llama-rag-dark" RED-on-rogues inferred from metrics
   and journal (`/health` 200 live) — the Gatus API itself is OIDC-gated and was not queried.
3. **Browser History quiet-day 503**: root-caused (previous session), upstream issue filed,
   agent-side gate fixed — but the live heal (a 200 on real browsing) is unproven; nobody
   browsed yet.
4. **Smoke baseline**: pre-reboot-check reports "4 known FAIL(s)" — I never enumerated them
   by name in this session's report (from the 13:58 record: CV-era status 000 ×4, BH 503,
   flm 000, Pocket ID journal — the set has partially self-healed since 14:08; next deploy
   refreshes the baseline).

## c) NOT STARTED

1. **M7/F18–F20**: user reboot + post-reboot proof (`bootctl status` PARTUUID `023f66c0-…`,
   pre-reboot-check green from booted state, QLC fallback second, optional firmware-menu
   fallback boot test).
2. **M8/F21**: first-nightly drift watch (post-23:00 boot-mirror-sync re-run, no drift, df
   stable) — not scheduled/reminded anywhere.
3. **Routing debt — parked items live only in prose**: the go-build hot-cache relocation gap
   (HM-symlink canonicalization), the deploy.sh hardening items (Zone-6 trip-recency gate,
   in-deploy anchoring assertion, exit-4 failed-unit dump, heal-summary journal), and the
   lint/audit candidates (readiness-gate `-sf` rejection, FOWNER-vs-chmod, mountPoint-vs-
   HM-symlink eval assertion) were NOT routed into `docs/todo/*.md` libraries. The 13:58 and
   15:02 reports both carry them; the todo system does not.
4. **Regression tests for my two script fixes** — shellcheck (pre-commit) covers the SC1087
   class now, but `PARTNUM`→`PARTN` is a runtime-lsblk-column class no static check catches;
   `scripts/test-scripts.nix` fixture not written.
5. **CV recurrence question** (parallel session's b.2): does the upstream content sync
   preserve store modes (`cp -a`) so the drift re-materializes every sync? CV repo copy flags
   not checked.
6. **M9–M12 pool**: llama-vlm model downloads (owner), ExecStart list-shape audit, optional
   mirror-freshness hardening, root-`@` off QLC investigation.
7. **Handoff side-questions lost**: the 11:06 root nixpkgs-lock bump provenance + 04:17
   reboot ownership attribution questions (handoff step 13) were never surfaced to the user.

## d) TOTALLY FUCKED UP (this session's honest ledger)

1. **Dismissal-without-evidence, twice**: (a) Bank-Sync's 14:00 NEW-failure was labeled
   "transient" from the 14:58 green BEFORE reading the actual FAIL line — the exact sin the
   parallel session flagged in their own report; I read the line only at 15:55 for THIS
   report. (b) inboxclean's 14:56 failure was initially misattributed to the parallel
   session's mid-flight edits ("they own that thread") — the real cause is the standing
   `main` OAuth token death, and I read the error text ~40 minutes after first noticing.
2. **Under-weighted a 16-day standing outage**: inboxclean `main` has failed since **Sep 05
   00:05** (~80 failures since Sep 19 alone). I knew the class (documented), saw the failure
   live, and still framed it as a routine footnote instead of checking duration FIRST — a
   one-line `journalctl --since` would have reclassified it immediately as a top open item.
   The 2026-09-04 incident's re-consent action NEVER happened.
3. **Dropped the handoff's side-questions** (nixpkgs bump provenance, 04:17 reboot ownership)
   — silently, not deliberately.
4. **Prediction never reconciled**: the 13:58 handoff predicted "rc=0 retry loop"; the actual
   verdict was rc=3 STOP at 14:00 (Bank-Sync was NEW vs the claimed baseline). I noticed in
   passing but never explicitly flagged "the prediction model was wrong" — which matters
   because the smoke-baseline reasoning that produced it is reusable and uncorrected.
5. **No test left behind** for the two flake-app bugs I fixed (see c.4) — fixed-and-shipped
   on a `nix run` probe alone; the house bar for script classes is a fixture test.
6. **Time discipline sloppiness**: CHANGELOG/plan ticks cite "~15:25" live state without a
   `date` run at write time (times were reconstructed from generation/commit timestamps —
   accurate, but the habit is evidence-first, not reconstruction-first).

## e) WHAT WE SHOULD IMPROVE (systemic)

1. **Duration-first triage**: for ANY failing unit, run `journalctl -u <unit> --since <wide
   window> | grep -c "Failed with result"` BEFORE classifying. Fresh vs standing changes the
   priority of everything downstream (inboxclean would have jumped the queue 40 min earlier).
2. **Never classify a smoke/regression failure before reading its FAIL line** — "it's green
   now" is a hypothesis, not a diagnosis (Bank-Sync). The failure line also tells you whether
   it will FLAP again (it will, until SCA approval — baseline-worthy knowledge I almost
   shipped without).
3. **Route or lose it**: every parked item in a session report needs a `docs/todo/*.md`
   library entry in the SAME session, or it dies in prose. Both my reports and the parallel
   session's reports currently violate this (6+ items un-routed).
4. **Flake apps need one end-to-end build before their first "green" claim**: both bugs I
   fixed (SC1087, PARTNUM) were invisible to every `--no-build` check; a single `nix run` of
   each app in the shipping session would have caught both. Convention candidate: flake-app
   smoke in the check that BUILDS the app derivation.
5. **Runtime-column fixtures**: lsblk/efibootmgr/findmnt column names should be
   fixture-tested (scripts/test-scripts.nix class) — static linters cannot see them.

## f) NEXT (ordered, ~44 items)

**User actions (the critical path):**
1. **REBOOT** — the armed mirror's first real boot. Everything is audited green; nothing to
   prepare. (Rollback: firmware menu F8/F11/F12 → QLC `Linux Boot Manager`, or `efibootmgr -o` QLC-first.)
2. Post-reboot: `bootctl status | grep -i partuuid` → expect `023f66c0-…` (F18).
3. Post-reboot: `nix run .#pre-reboot-check` from the booted state → exit 0 (F19).
4. Post-reboot: confirm QLC entry still second in BootOrder (F20, optional menu test).
5. Decide the rogue llamas: `sudo kill 805159 805161` (they hold 8848/8849 + llama-vlm's
   8127/8128) — or leave if a hermes cron job is legitimately using them (see g.1).
6. InboxClean re-consent (16-day outage): flip the Google OAuth client to "In production"
   FIRST, then run the `inboxclean auth` runbook (docs/services/ docs) for `main` (+ verify
   `work` still healthy).
7. Bank-Sync SCA approval: `bank-sync sca approve` (clears the degraded statements/transfers
   fallback AND stops the sync-errors counter flap that produced the 14:00 smoke failure).

**This-session follow-ups (agent-executable):**
8. Enumerate the current smoke-baseline FAIL set by name; re-baseline on the next deploy.
9. Watch tonight's 23:00+ boot-mirror-sync run (M8/F21): journal + df + no drift alert.
10. Verify browser-history `/health` flips 200 after the user's first real browsing session.
11. Investigate the rogue-llama SPAWNER (hermes cron worker scope at 05:40): which job, is it
    recurring, does it need the embedding server — root-cause before/after the kill decision.
12. Route the un-routed parked items into `docs/todo/{storage,stability,services,monitoring}.md`:
    go-build relocation gap; deploy.sh Zone-6 trip-recency gate; in-deploy anchoring assertion;
    exit-4 failed-unit dump; cv-state-perms heal-summary journal; smoke-baseline last-seen stamps.
13. Write the lsblk-column fixture test (PARTNUM class) + a build-the-app-derivation check for
    flake apps (scripts/test-scripts.nix / flake check).
14. Check the CV repo content-sync copy flags (`cp -a`?) — answers whether the perms drift
    re-materializes every sync (parallel session's b.2) and whether an upstream post-copy
    chmod is the durable fix.
15. Post-reboot: verify `hot-user-caches-go-build-bootstrap` runs green and the subvol mounts
    (parallel session's b.3 residual: 0755 → 0700).
16. Post-reboot: confirm the flm EADDRINUSE corpse is gone (:52626 released), flm smoke heals.
17. Post-reboot: `bootctl` random-seed/entries sanity on BOTH ESPs; watch `/boot` vs
    `/boot-mirror` entry count through the next generation.
18. Sweep Gatus CV group + llama-rag-dark checks green/red-as-expected post-reboot.
19. Watch `cv-backup` tonight (03:30 pool receive lands).
20. Observe `cv-scan` at the 18:23 tick — proves the CV stack end-to-end post-heal.
21. inboxclean: after user re-consent, confirm `main` cursor advances past 5152620.
22. DiscordSync/immich go-live key paste (standing user-gated item from the libraries).

**Deploy-stability improvements (route to owning session / TODO):**
23. deploy.sh: refuse deploys when Zone-6 trips advanced in the last 60 min (exit 12).
24. deploy.sh: post-switch anchoring assertion (profile vs current-system, loud on mismatch).
25. deploy.sh: on `Exited(4)`, print the transaction's failed-unit list inline.
26. cv-state-perms: journal a heal SUMMARY (count + sample) — 40-min diagnosis → 10 min.
27. Smoke baseline entries get last-seen timestamps (phantom-red prevention).
28. Readiness-gate lint: reject `curl -sf` (or any success-only probe) in ExecStartPre gates.
29. Eval-time lint: FOWNER-required chmod class (heal units that chown+chmod need CAP_FOWNER).
30. Eval-time assertion: mountPoint paths that resolve through HM out-of-store symlinks
    (canonicalization trap — the go-build class).
31. Extend systemd-shape-audit with the isList-ExecStart class (M10, 60–100 min).
32. hermes-perms probe symmetry sweep (ownership-only fast paths across the tree — the
    cv-state-perms class generalized; parallel session's f.22).

**Samsung / storage follow-ups:**
33. First-weekly mirror observation after several generations (entry growth, df trend).
34. llama-vlm model downloads decision (M9/F23 — feature dark until the GGUFs land AND the
    rogue 8127/8128 listeners are gone).
35. Root `@` off QLC investigation (M12 — separate Pareto doc, owner-gated).
36. hot-db waves (crush → pocket-id → postgres → forgejo → dnsblockd/papdashboard) —
    owner-gated migrations per the Phase-2 plan.
37. Old dead `@nix` subvol deletion on the QLC (tracked in docs/todo/storage.md).

**Monitoring / verification debt:**
38. Add a Gatus/check for "boot-mirror-sync freshness" (or system-health mirror-age metric —
    M11, only if the skipped-sync class is ever observed).
39. Verify the gatus-pattern lint + §10 gate stay green with the new `llama_rag_dark` metrics.
40. Post-reboot: run one deliberate QLC-fallback boot from the firmware menu (F20 optional
    half — proves the rollback path physically).
41. Confirm the 4-report-deep smoke baseline chain (11:53 → 14:00 → next) actually shrinks:
    CV-era fails must drop out after the 14:08 heal.
42. File/track the upstream browser-history heartbeat implementation (issue #26) — SystemNix
    gate stays any-status meanwhile.

**Attribution / bookkeeping:**
43. Ask the user about the 11:06 nixpkgs lock-bump provenance + 04:17 reboot ownership (the
    lost handoff questions — attribution only, both moot for correctness now).
44. Fold the 13-58/15-02/15-30/15-57 report chain into the next docs-health harvest pass.

## g) QUESTIONS (cannot resolve from this sandbox)

1. **The rogue llama-servers (PIDs 805159/805161, hermes user, since 05:40)**: they hold
   llama-rag's disabled ports 8848/8849 AND llama-vlm's 8127/8128. Do you want them killed
   (`sudo kill 805159 805161`), and — the part I cannot know — **is a hermes cron job
   legitimately using them** (e.g. an embedding-dependent scheduled task)? If yes, killing
   breaks that job and the right fix is re-pointing the job, not the kill.
2. **InboxClean OAuth client status**: is the Google OAuth client still in "Testing"
   publishing status? The `main` refresh token has been dead since Sep 05 (16 days, ~2
   failures/hour with OnFailure alerts) — the fix order is production-flip FIRST, then
   `inboxclean auth` re-consent on the desktop. Do you want the exact commands staged for
   your next desktop session?
3. **Reboot timing**: now, or tonight (so the first-nightly drift watch M8 lands on the same
   evening), or after you've handled the llama/inboxclean decisions? Any preference for
   being at the machine for the first Samsung boot?

---

*Report 15:57. System: system-787 anchored, mirror armed (Boot000C first), zero failed
system units since 15:00, tree pushed at `541fab97`. No secrets included.*
