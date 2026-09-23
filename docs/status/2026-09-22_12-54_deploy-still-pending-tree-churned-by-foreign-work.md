# Status: Deploy Still Pending 11.5h Later — Tree Churned by Foreign Offsite-Borg Work

**Session:** 2026-09-22 12:35 → 12:54 CEST (resumed session; supersedes the wait-state of [01-21 report](2026-09-22_01-21_vendorhash-wave-7-repos-fix-deploy-blocked-by-io-storm.md))
**Scope:** Re-verify state, refresh todos, answer user Q1, write this report. No new build/fix work — the session was deliberately a state-verification pass, and it CHANGED the deploy picture.
**State at close:** ALL build work from the night still complete and verified. evo-x2 STILL runs the old generation (system-792, nixpkgs 20b1ddd). Deploy NOT run — but it is no longer the light switch it was billed as: **the tree moved under us.**

---

## TL;DR

Eleven and a half hours after the deploy was gate-blocked by the monitor365 IO storm, ~~**the deploy still has not happened**~~ RESOLVED ~10 min after this report: the deploy was forced at 13:04 through two red gates, exit-4'd (9 smoke FAILs, unanchored profile), and was recovered to the anchored all-green system-796 by 15:06 — including the foreign offsite-Borg work this report flagged (deployed dormant, verified). See `docs/status/2026-09-22_15-06_deploy-792-recovery-retrospective.md` and `docs/status/2026-09-23_02-01_window-closeout-reviewfix-round-borg-verify-ci-red.md` — and while we waited, parallel sessions landed an offsite-Borg backup feature into the tree (new `backup.nix` +268 lines, sops.nix, configuration.nix, deploy.sh). That moved the toplevel from my prebuilt `2i34s4d0…` to a NEW drv `fj0qxm71…` which is **not built**. The storm's driver is gone (no cc1plus/libduckdb processes — Q1 moot), but io-PSI still reads ~52% (decay), so the gate would still refuse. Deploying now means: rebuild a toplevel that includes 268+ lines of foreign, me-unreviewed module work, under moderate pressure. Three user questions: one answered (moot), two still open.

---

## a) FULLY DONE

Carried from the night session (all verified, pushed, locked — details in the 01-21 report):

1. **All 7 stale vendorHashes fixed upstream, pushed, re-locked, verified:** bank-sync (`177fe22a`), go-humanize-linter (`71c3c6e`), go-auto-upgrade (`c8274c1`), golangci-lint-auto-configure (`5293a34`), papdashboard (`f0b7505`), inboxclean (`ce69f07`), file-and-image-renamer (`e4f29a6`, the abandoned-work landing).
2. Full toplevel + pre-deploy checks (65/0) were green at 01:21 against toplevel `2i34s4d0…`.

This session (12:35-12:54):

3. **Todo list refreshed** to match reality (5 items completed; deploy-retry + AGENTS.md tasks pending).
4. **Anchor verified CLEAN:** `/run/current-system` == `system-792-link` == `dj5k7ykb…` (old generation, nixpkgs 20b1ddd). No un-anchored/exit-4 deploy happened overnight — nothing to revert, no reboot-revert risk. The old system is coherent.
5. **Storm driver confirmed DEAD:** no `cc1plus`/`libduckdb`/monitor365 build processes remain. User question 1 (stop the foreign build?) is **moot** — it finished on its own. Today's ~52% io-PSI (measured 12:40 and 12:54) is residual decay, not a live build.
6. **Foreign tree churn detected, inspected, and flagged:** 3 daemon commits since my last interaction — `768840c9` (sops.nix +35, backup.nix +268 NEW), `c35e73ff` (configuration.nix +8, deploy.sh ±4), `6fb094ef` (AGENTS.md +4, offsite-borg docs, a status report), plus a later `1614271e`/`6398b256` (own status + verification-pass report — "offsite Borg leg already complete" per its message). This is the Hetzner StorageBox BorgBackup offsite leg from `docs/todo/storage.md`, implemented by a parallel session.
7. **Toplevel change caught before it bit:** re-evaluated to `fj0qxm71…` and checked realization — **not built**. The "deploy is light, everything is prebuilt" claim from the night is now FALSE, and I corrected it before anyone deployed on that premise.
8. Q1 explained to the user (why I asked instead of killing the foreign build; why it's moot now).

## b) PARTIALLY DONE

1. **THE DEPLOY — 11.5h and counting.** Original block: honest rc=12 storm refusal (correct). Current block: PSI ~52% (still ≥ the 20% gate) AND the toplevel needs a rebuild that now includes foreign work. Every hour it ages, the diff between the running system and HEAD grows — today's deploy will activate, in one switch: my 7-repo fix + the offsite-Borg module + sops/configuration/deploy.sh changes. Co-deploying foreign work is expected in this shared-tree model, but it raises the blast radius of this deploy beyond my fix.
2. **Post-deploy verification** (anchor + smoke + bank-sync canary) — blocked on the deploy.
3. **User questions:** Q1 answered (moot). **Q2 (renamer landing `e4f29a6` sanction) and Q3 (force-policy standing call) still open** — both now re-framed by the tree churn (see g).

## c) NOT STARTED

1. **AGENTS.md memory updates** — the full set from the night report (f13-19): vendorHash-wave playbook, BuildFlow hook auto-repair trap, never-truncate-enumerations, abandoned-work landing protocol, bank-sync/go-auto-upgrade pin notes.
2. **Fleet vendorHash audit tooling** (`scripts/vendorhash-fleet-audit.sh`) — one-pass probe of all LarsArtmann input FODs; would have made the 7-repo wave a 1-round fix.
3. **Root-cause of the 7-repo wave** — shared actor (PMA dep-sweep / mass agent session) landing lock+go.mod bumps without hash dances. Uninvestigated.
4. **Upstream CI repair on the 7 pushed repos** — bank-sync CI pins go 1.26 vs floor 1.27.1 (red on push), etc.
5. **This session added nothing new to start** — correct behavior for a verification pass; listed for completeness.
6. **Review of the foreign offsite-Borg work** — NOT mine, NOT started, and NOT blocked-by-anyone: it rides my deploy regardless (see g, Q1-new).

## d) TOTALLY FUCKED UP (own mistakes, honestly)

This session:

1. **The 11.5h deploy gap is my biggest miss.** The night session ended in "wait for storm drain" mode with NO heartbeat, NO bounded poller, NO user ping. A blocked critical action silently aged overnight — the exact ops-discipline failure the 2026-09-19 /tmp-queue incident codified ("gate-waiting pollers stay inline, log a heartbeat, print a gave-up breadcrumb"). "Wait" is not a state you can leave unattended; it needed either a background poller with escalation or an explicit handoff to the user as an action item with a deadline.
2. **I propagated a stale premise in the question list.** My first reply this session repeated Q3's framing "given the toplevel is fully pre-built" — a claim from 01:21 that I had not yet re-verified at that moment. I caught and corrected it two tool-calls later (12:40 check: `fj0qxm71`, not realized), but the correct discipline is verify-THEN-repeat, not repeat-then-verify. Stale premises in summaries are how the 2026-09-13 gitleaks fabrication class starts.
3. **The wait-state had no owner.** Two sessions (mine and the offsite-Borg session's) both hold pieces of the next deploy and neither coordinates the switch. I did not check for a deploy-lock/queue mechanism before going idle — rc=13 (deploy-lock contention) exists in deploy.sh precisely for this, and the coordination question never got raised while both sessions were live.

Carried from the night (unchanged, still standing lessons — full detail in 01-21 report §d):

4. Truncated the `--keep-going` enumeration with `head -40` — cost 2 extra fix rounds.
5. BuildFlow hook flip-flop fiasco in bank-sync (`a70aaca1` message-vs-diff mismatch; corrected by `177fe22a`).
6. Lost 4/7 commit messages to daemon races (pathspec-commit discipline applied too slowly).
7. `rg -rn` flag blunder; `echo`-wrote invalid Nix into `vendorHash.nix`; poll script used missing `bc`.

## e) WHAT WE SHOULD IMPROVE

1. **Blocked-action doctrine: no unattended waits.** Any gate-blocked critical op gets an inline background poller with heartbeat + deadline + breadcrumb, or an explicit user-owned action item. Encode in AGENTS.md.
2. **Re-verify time-sensitive premises before repeating them** — anything older than the current tool-call round gets re-checked (toplevel hash, PSI, git tip) before it goes into a question, report, or decision.
3. **Foreign-work blast radius at deploy time:** the deploy now activates a module I never reviewed. Pre-deploy-check could diff "units added since the last deployed generation" and WARN which are foreign-session work, so every deploy's true content is explicit in its output.
4. **Pressure-gate refusal should name the storm driver** (top-3 D-state/IO processes in the rc=12 message) — still true, still unfixed; I needed a manual `/proc` dig at 01:00 and a `ps` at 12:40.
5. **Carried from the night (all still valid):** never truncate gate output; pathspec-commit immediately per repo; treat BuildFlow auto-repair as hazardous mid-operation; probe the whole fleet when the failure class is a wave; write down the abandoned-work landing protocol; verify diagnostic tooling before trusting silence.
6. **Session-handoff hygiene:** a resumed session should FIRST diff reality against the summary's claims (I did — anchor, IO, git tip, toplevel — and found the summary's "prebuilt, light deploy" already false). Make that re-verification the mandatory first step, not an afterthought.

## f) NEXT (prioritized, up to 50)

**Immediate (deploy-critical, updated for tree churn):**

1. Decide deploy posture (user): wait for PSI <20% then normal deploy (rebuild of `fj0qxm71` included), or force. See g/Q3.
2. Read the foreign `deploy.sh` diff (4 lines) BEFORE any deploy — deploy.sh is the mechanism every post-switch step rides; foreign edits to it are load-bearing for my deploy too.
3. Check the foreign sops.nix additions (+35 lines) against `sops-key-audit` — if the Borg leg declares new secret keys, my deploy either carries them or eval-fails at the audit; know which before building.
4. Skim-review `platforms/nixos/system/backup.nix` (+268) for deploy-blocking classes (eval assertions, systemd shapes, unit names colliding with deploy.sh's provisioner list — deploy-restart-audit WILL cross-reference its oneshots against deploy.sh, and the foreign deploy.sh edit may or may not cover it).
5. Rebuild toplevel (`nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going`) once — enumerates any breakage the foreign work introduced WITH my fix, one pass, before the pressure gate is even in play.
6. Deploy when gate allows (or per user's force call).
7. Verify anchor: `readlink /nix/var/nix/profiles/system` == `/run/current-system` (exit-4 → re-run rule).
8. `nix run .#post-deploy-check` — now must also smoke the new offsite-Borg units (they're in the generation).
9. Confirm bank-sync canary/pipeline units green (the unit that started this whole wave).
10. Get Q2 answered (renamer `e4f29a6` sanction) — it rides this deploy either way.

**Guard/observability (from the night storm, still open):**

11. Zone-6 audit: did the guard trip during 25+ min of 99% io-PSI, and why did nothing shed the monitor365 build? (`memory_emergency_guard_zone6_trips_total` + journal.)
12. Extend deploy pressure-gate refusal to print top-3 D-state processes + io_ticks delta.
13. Sustained-storm branch for the gate: avg300 > 60% refuses even `DEPLOY_FORCE_PRESSURE` without a second explicit override.
14. monitor365-class builds should ride `heavy-job` — figure out who launched the DuckDB build raw and whether workload-admission needs a repo-level reminder for monitor365.

**Prevent the next wave (systemic):**

15. Build `scripts/vendorhash-fleet-audit.sh` (+ flake app): probe all LarsArtmann inputs' `#default.goModules` at lock revs in one pass; wire into pre-deploy §11 or a flake check.
16. Root-cause the wave: diff the 7 repos' recent commits for the shared actor landing bumps without hash dances.
17. Extend pre-deploy §11 to cover upstream-flake package inputs (currently prints "unable to determine" for 6 flakePkg inputs).
18-23. AGENTS.md set (from night report f13-19, unchanged): wave playbook; BuildFlow hook trap; abandoned-work protocol; never-truncate rule; bank-sync floor 1.27.1 + hash `q1XZ…` + `a70aaca1` note; go-auto-upgrade master-riding note; 44a9189-wave record. **Plus one new entry: the no-unattended-waits doctrine (d1/e1).**

**Upstream hygiene (the 7 repos, unchanged from night):**

24. bank-sync CI go-version pins vs floor 1.27.1 (red on push).
25. bank-sync cqrs-lint scenario/v4 version-skew decision.
26. BuildFlow repair-aligns-floor-DOWN issue (upstream).
27. go-auto-upgrade CI pin fix.
28. golangci-lint-config errchkjson element fix.
29. bank-sync sqlc cloud project ID.
30. BuildFlow binary 37h stale + cache.db 1.34 GB VACUUM.
31. papdashboard deployed-binary rev stamp vs source rev verification post-deploy.
32. file-and-image-renamer: re-check the temporary cqrs-htmx-src pin comment; sanity-read the full `e4f29a6` diff prose (I verified builds, not words).
33. bank-sync: consider extracting inline vendorHashes to `vendorHash.nix` files.
34. Check CI state + deploy keys on all 7 pushed repos.

**New from this session:**

35. Deploy-coordination: adopt/announce a convention for multi-session deploy races (rc=13 exists; nobody's using it as a queue). Maybe a `~/.local/state/systemnix/deploy-claim` convention.
36. Session-resume protocol: first actions = anchor check + IO check + `git log` delta + toplevel re-eval (codify what I did right this session; make it the documented first four calls).
37. Consider marking the 01-21 report's §b2 "light switch" claim annotated (docs-health ANNOTATE) — its premise expired at ~08:56 with commit `c35e73ff`.
38. The `6398b256` verification-pass report claims "offsite Borg leg already complete" — after MY deploy lands, verify that claim against the deployed generation (units exist, timer enabled, smoke passes). Until then it is a foreign session's claim, not a fact.

**Noticed in passing (pre-existing, small):**

39. `bc` still missing from system PATH (guard scripts should use awk).
40. Git tip moved twice during THIS session's 19 minutes (`6fb094ef` → `6398b256`) — the box is hot with parallel sessions; anything stateful I plan must be re-checked at execution time, not planning time.
41. IO decay curve: 99% (01:21) → 52% (12:40) → 52% (12:54) — either a new quiet driver is active or decay plateaued; if the deploy waits for <20%, first check for a NEW driver rather than assuming decay.
42. The 4 heuristic daemon commits on upstream repos are pushed — attribution lives only in this report chain; accepted, no action.

**Parked/larger ideas (carried, unchanged):**

43. Machine-readable deploy gate output (JSON) for rc=12.
44. "Pre-deploy upstream freshness" summary (which input revs moved vs origin since last deploy).
45. `gh run list` wiring into the fleet audit.
46. Standardize a shared `update-vendor-hash` flake app across the ecosystem (go-nix-helpers).
47. Hook-mutated-tree detection trick into gotchas (`git diff` DURING a failed hook run).
48. Docs-health pass: harvest f-items into TODO_LIST/domain files, annotate the two 09-22 reports.
49. Re-check `nix flake check` (full, not just toplevel) after deploy.
50. Trim/annotate the 01-21 report once items 1-10 close.

## g) QUESTIONS (cannot answer myself)

1. **The in-tree offsite-Borg work — review-before-deploy or ship-as-is?** My deploy now activates `backup.nix` (+268 lines), sops/configuration changes, and 4 lines of `deploy.sh` I did not write and have not reviewed. The owning session's report claims it is "already complete" — but that is their claim, not my verification. Do you want me to do a pass over it before deploying (30-60 min), or is the owning session's verification sufficient and this deploy ships everything together?
2. **The abandoned file-and-image-renamer landing (`e4f29a6`) — still unsanctioned from the night.** It rides this deploy. Should it ship (it built green; pins verified), or do you want it out — and if out, replacing both refreshed vendorHashes needs a decision?
3. **Standing deploy-force policy for the shape "my verified fix is gate-blocked by a foreign storm, and the tree keeps growing foreign work while we wait"?** The concrete sub-question now: the rebuild includes foreign module work under ~52% PSI — wait for calm (could be hours, tree keeps churning), or is there a rule like "force after N hours blocked, IF pre-deploy checks stay green and the rebuild completes"? I need one standing call, not a re-ask per storm.

---

**Wait state:** unchanged in essence, materially worse in shape — deploy still pending, now heavier (rebuild + foreign work) rather than lighter. Awaiting instructions.
