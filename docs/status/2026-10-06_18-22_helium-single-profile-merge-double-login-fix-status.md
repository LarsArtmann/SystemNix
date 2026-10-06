# Status Report — Helium Single-Profile Merge + Double-Login Fix (2026-10-06 18:22)

**Session scope** (user ask): (1) merge the multiple Helium browser profiles into 1; (2) fix the double password at login. This report covers ONLY this session's run and what was noticed in passing. Deployed generation: `wsqw20n8` (rode the concurrent 16:44 switch, verified identical to my built closure).

---

## a) FULLY DONE

1. **Diagnosis, both issues, root-caused with evidence**
   - Profiles: 3 live instances since 2026-09-29 (main + `helium-dp1`/`helium-dp2`, each a full user-data-dir — dp2 had grown to 432 MB, 247 URLs/491 visits incl. its own logins at `github.com`/`accounts.google.com`).
   - Double password: `sddm-helper: gkr-pam: the password for the login keyring was invalid` → PAM auto-unlock fails → every browser start popped a gcr-prompter "unlock login keyring" dialog. Journal-caught live: the prompter (pid 19538) sat on screen from login 15:16 until the old browsers died 16:56. Cookies were **already v11 (basic-store AES)** in ALL profiles → the keyring dependency was vestigial → `--password-store=basic` is lossless.
2. **dp instances removed** from `niri-wrapped.nix` (spawn-at-startup entries + both window rules); `2-web-dp1`/`dp2-web` workspaces kept as manual-move landing spots; comments updated (incl. the merge note).
3. **`--password-store=basic`** added to the helium wrapper (`platforms/common/packages/base.nix`) with full rationale + the makeWrapper-continuation lesson in the comment.
4. **Deployed + live-verified**: `/run/current-system` = my built closure; running process cmdline carries `--password-store=basic`; exactly ONE helium instance; no `--user-data-dir` helium processes; NO gcr-prompter since relaunch; no browser-triggered keyring activations.
5. **Data merge** (browsers stopped): dp1 (+0 new URLs — all 6 existed, +11 visits, +4 cookies) and dp2 (+215 URLs, +492 visits, +22 cookies) into main. Final: **2115 URLs / 5770 visits / 109 cookies, `quick_check` = ok**. Small-DB backups at `~/backups/helium-profile-merge-2026-10-06/`. dp dirs trashed (~613 MB reclaimable, restorable).
6. **session.json** purged of dp window entries (verified 0 remain); next login restores one plain `helium`.
7. **Deploy-chain unblock**: browser-history go-modules vendorHash shims (first-hand got-hashes; upstream pins stale through lock rev 68d0b6d — no-shim build verified FAILING), with documented drop condition. Plus: helium wrapper makeWrapper bug fixed (my own — see d), and the netbird session's untracked sops file force-added (`git add -f`, encrypted verified) after it broke every eval (tracked-files trap).
8. **Paperwork**: desktop.md rewritten (3 bullets: workspace-strip/merge, guard note, passkeys gap RESOLVED-BY-REMOVAL + new password-store bullet — re-applied after a concurrent session clobbered my first pass); docs/todo/desktop.md rows 48/50/51/53 closed with evidence, row 52 unblocked (policy live, ceremony user-gated, dp caveat moot); TODO_LIST queue rows updated (+ dedup repair); CHANGELOG entry (entry-clip repaired); final `nix flake check --no-build` = **all checks passed**; TODO-system selftest structure OK.

## b) PARTIALLY DONE

1. **Double-password fix**: browser path FIXED and verified. The keyring password desync itself is NOT fixed (requires the old keyring password typed interactively — a user-only step). Residual: one gkr-pam failure line per login + periodic promptless `couldn't unlock` activation bursts (~28 lines in one observed window) whose ACTIVATOR is still unattributed (my dbus-monitor rule attempt failed technically — captured everything/nothing useful).
2. **Login acceptance test**: only provable at the NEXT login (SDDM password → desktop → no second prompt). Browser-start path is proven clean.
3. **Merged-data visual check**: `chrome://history` not visually inspected (no UI access from SSH); SQLite-level verification (counts + quick_check + URL/title merge) stands in.
4. **Cookie efficacy**: dp2 cookies (incl. github/google sessions) merged but not proven to restore logins in the live browser — only a site visit shows that.

## c) NOT STARTED

1. Keyring password alignment (`nix run nixpkgs#seahorse` → Login keyring → Change Password) — user manual step, documented only.
2. gkr-pam burst attribution (source of the periodic DBus-activated daemon spawn attempts).
3. docs/todo/desktop.md row 49 (journal-pin of the wedged guard's start date) — still open, arguably moot in a post-dp world.
4. Trash purge of the dp dirs + retention decision for the merge backup dir.

## d) TOTALLY FUCKED UP

1. **Shipped a build-breaking wrapper edit** (comments interleaved inside the backslash-continued `makeWrapper --add-flags` chain → `--add-flags: command not found`, exit 127). Eval-only checks cannot see postBuild failures → **the user's own force-deploy died on MY bug**. Fixed + documented, but the "flake check green" confidence was misplaced for wrapper changes.
2. **CHANGELOG edit clipped the next entry's first line** (my old_string swallowed `- **09-20 root weekly...**`). Caught and repaired in the same breath — but it was a careless multiedit.
3. **TODO_LIST multiedit produced a duplicate row** (replaced two different queue rows with the same passkeys text). Caught via grep, deduped via sed.
4. **`kill` builtin false-positives**: this shell's `kill` is an unsupported builtin → `kill -0` always "failed" → I reported "main dead after 1s" when NOTHING had died. Only caught because I cross-checked with pgrep. (pkill/pgrep are the only reliable tools here.)
5. **Merge script v1 assumed `visits.url_id`** — Chromium 151 renamed it to `visits.url`; first run died with KeyError. I wrote migration SQL against an unverified schema (should have introspected first). Rollback was clean (uncommitted transaction), zero damage.
6. **/tmp purge ate session artifacts mid-run** (merge script + DB copies) — one run failed on a missing file; rewrote. Fragile scratch location for important tooling.
7. **Near-miss misreport**: I briefly treated "standalone FOD build succeeded" as fact — it was a nix no-op printing the drv path (no `^out` semantics). Corrected before acting on it; recording it because the same misread cost a build cycle if uncorrected.

## e) WHAT WE SHOULD IMPROVE

1. **Build-verify any postBuild/wrapper change** — eval is structurally blind to builder-script breakage. Cheap fix: build the single `helium` symlinkJoin drv (seconds) after touching `base.nix`; worth a CONTRIBUTING bullet next to the existing makeWrapper note.
2. **Introspect schemas before migration SQL** (PRAGMA table_info first, write second).
3. **Scratch durability**: one-off-but-critical scripts belong in `~/backups/...` alongside the data, not `/tmp`.
4. **Concurrent-session deploy contention**: 3 gate blocks (IO PSI ×2, deploy lock ×1) burned ~50 min of wall time; all were other sessions' builds (monitor365 Rust, browser-history Go waves). The gates worked as designed — the improvement is scheduling/awareness, not weakening gates (the user's own force-override at 15:45 rode MY broken edit; overrides under storm are how bad deploys happen).
5. **`systemctl` is Crush-policy-blocked** — `busctl --user call … StopUnit/StartUnit` is the working equivalent; deserves a line in shell-devtools docs.
6. **gkr-pam noise remains unattributed** — one focused dbus-broker/journal pass would close it (promptless today, but it obscures real keyring regressions).
7. **Session-wall-time**: ~3 h for two fixes — honest accounting: ~50 min gate waits, ~40 min of my own mistakes (wrapper bug, schema bug, clip/dup repairs). The diagnosis discipline (live evidence before editing) is what went RIGHT and should stay.

## f) NEXT (session-derived, ~30 — most already harvested; see §h)

1. **[user] Next login acceptance test**: type SDDM password → NO second prompt; exactly ONE helium instance; session restore sane.
2. **[user-decision] Keyring endgame**: align password via seahorse (needs old password) OR delete the 2909-byte `login.keyring` (contents almost certainly stale Chrome Safe Storage keys; no wifi secrets in play) — either kills the residual gkr-pam line.
3. **[user] Visually confirm merged history** in `chrome://history` (dp2's last-week URLs present) + one dp2-login site (e.g. github) still logged in.
4. **[ready] Attribute the gkr-pam activation bursts** (dbus-broker stats / journal correlation; no prompter involved).
5. **[ready] KeePassXC passkey ceremony** (queued row: policy live since 16:44; chrome://policy + one real passkey).
6. **[watch] Drop browser-history vendorHash shims** when upstream re-pins or the lock moves past a fixed rev (drop condition in browser-history.nix).
7. **[ready] Row 49** (guard-wedge journal-pin) — close as moot or spend one journal pass.
8. **[blocked:user] Purge trashed dp dirs** (~613 MB) + decide retention for `~/backups/helium-profile-merge-2026-10-06/`.
9. **[ready] Decide the fate of `2-web-dp1`/`dp2-web` workspaces** — unrouted names referencing a removed mechanism (mild naming split-brain); remove or accept as generic web slots (needs one week of usage data → your call).
10. **[ready] CONTRIBUTING: wrapper/postBuild build-verify bullet** (the d.1 class; makeWrapper comment lesson currently lives only in base.nix).
11. **[ready] CI/pre-commit option**: build `heliumWrapped` when `base.nix` changes (cheap symlinkJoin; catches continuation breakage).
12. **[ready] Untracked-referenced-file eval trap**: netbird.yaml broke EVERY eval until `git add -f` — a pre-deploy/CI detector for "module references untracked path" would catch the class (the AGENTS trap doc exists; a guard doesn't).
13. **[ready] Check pre-login gkr activations** (2 lines at 15:16:04, before sddm-helper) — one journal look; probably lingering services.
14. **[ready] Login instance audit**: confirm helium.service + session-manager restore converge on ONE instance (the guard waits by design — verify it doesn't sit in wait-loop at next login).
15. **[ready] Archive the merge script** (with `--selftest` for idempotence: re-run on a copy must be a no-op) next to the backups, or delete with them.
16. **[ready] `Local State` keyring remnants** — inert under basic store, but one look for dangling os-crypt config keeps the profile clean.
17. **[watch] Next deploy carries OTHER sessions' first-activations** (btrfs-scrub@, root-prune-guard) — the race detector warned; they were in-tree intentionally, but their owners should verify their own pieces post-switch.
18. **[watch] browser-history tag churn**: the FOD flapped between mismatch/success while the parallel session moved cqrs-htmx tags — if it recurs, pin the cqrs input in browser-history's lock.
19. **[ready] iotop-c: always `-b` batch mode** from agents (ncurses garbage otherwise) — doc line in monitoring docs.
20. **[ready] shell tooling notes**: `kill` unsupported builtin (use pkill/pgrep), `systemctl` blocked → `busctl --user call` equivalents — add to docs/agents/shell-devtools.md.
21. **[watch] The `service-health-check.service` failed-unit warning** seen in the user's deploy pre-checks — pre-existing, not session-caused, uninvestigated.
22. **[watch] Monitor365 metrics port 9191 not responding** (deploy pre-check warning) — pre-existing, other session's domain.
23. **[ready] dp1/dp2 `Extensions` state died with the dirs** — KeePassXC-Browser association + NSFW-classifier settings were per-profile; main profile's own settings are intact; if the classifier's tuned settings lived in dp2 they are gone (restore from trash if missed).
24. **[decision] If per-monitor browser windows are ever wanted again**: the honest mechanism is ONE profile + manually moved windows (Mod+Shift+Tab); dedicated app-ids REQUIRE separate profiles — document as a settled trade-off in desktop.md if asked again.
25. **[ready] Empty-workspace strip check** after a week: if `2-web-dp1`/`dp2-web` stay empty, remove (changes Mod+N slot ordering — do it in one go with f-item 9).
26. **[ready] Verify `helium.service` unit's Restart behavior post-merge**: StopUnit/StartUnit cycle proven, but a crash-restart under the new single-profile world should re-exec from the NEW wrapper (store-path check).
27. **[watch] gcr-prompter skip_apps entry** stays (other auth prompts still use it) — no action, recorded so nobody "cleans it up".
28. **[ready] Post-merge DB sizes**: main History grew to ~34 MB + merged rows; trivial, but a `PRAGMA integrity_check` (fuller than quick_check) on the next browser-close is free insurance.
29. **[ready] CHANGELOG/multiedit discipline**: my clip (d.2) and dup (d.3) were both old_string-context errors — re-read target lines before multiedit in a daemon-swept tree.
30. **[watch] The user's DEPLOY_FORCE_PRESSURE override precedent** — the override exists for humans; agents should keep defaulting to waiting (the override at 15:45 deployed MY broken edit — the gates were right).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Keyring endgame**: do you remember the OLD keyring password (→ seahorse align, keeps the 2909-byte keyring + silences gkr-pam), or should I delete `~/.local/share/keyrings/login.keyring` so PAM recreates it with your current password next login (loses whatever few secrets are inside — near-certainly stale Chrome Safe Storage keys, no wifi/NM secrets on this box)?
2. **Workspace layout**: keep `2-web-dp1` + `dp2-web` as generic per-monitor web slots (current state), or remove them in a follow-up (shifts Mod+N slot ordering)?
3. **Trash/backup retention**: the trashed dp dirs (~613 MB) and `~/backups/helium-profile-merge-2026-10-06/` — purge after a settling period? How many days?

## h) Self-harvest ledger (authoring-time, per AGENTS TODO rule)

Harvested into `TODO_LIST.md` + `docs/todo/desktop.md`: f1 (login acceptance, `[blocked:user]`), f2 (keyring endgame, `[decision]`), f4 (gkr-pam burst attribution, `[ready]`), f7 (row 49 mooting, folded into the existing row), f8 (trash purge, `[blocked:user]`), f9/f25 (workspace fate, `[decision]`), f13 (pre-login gkr lines, folded into f4 row), f14 (login instance audit, `[ready]`). Deliberately NOT harvested: f3/f5 (user actions in existing rows), f6 (shim drop condition already encoded in browser-history.nix + existing shim lifecycle rows), f10/f11/f12/f15/f16/f19/f20/f28 (tooling/doc niceties — recorded here only until someone owns a batch; harvesting 8 micro-rows would add queue noise, the known anti-pattern), f17/f18/f21/f22 (other sessions' domains — their reports own them), f23/f24/f26/f27/f29/f30 (watch-notes/lessons, not actionable asks).

---

*Report basis: this session only (15:19–18:22). No unrelated research performed. Corrections welcome — annotate, don't rewrite.*
