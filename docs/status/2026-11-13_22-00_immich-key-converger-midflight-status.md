# Status — Immich key converger mid-flight + plan for the Takeout fleet

**2026-11-13 22:00 CET** · HEAD `751ecfd78` (6 commits ahead of origin, 0 behind)
· tree: one FOREIGN staged file from a parallel session, otherwise clean

---

## a) FULLY DONE (verified)

1. **Comprehensive plan.** `docs/planning/2026-11-13_19-27_takeout-fleet-completion-and-immich-key-converger.md`
   (317 lines): Pareto layers (1 % / 4 % / 20 % / remaining 80 %), a Level-1
   table of 19 tasks at 30–100 min each, a Level-2 breakdown of ~60 micro-tasks
   at ≤12 min each, a mermaid execution graph, owner-blocked separation, and
   guardrails. Committed via daemon sweep `ef4a66aec`.
2. **`lib/immich-api-key-provision.nix`** (151 lines) — canonical root
   converger: direct `api_key` INSERT via peer-auth postgres, `sha256(token)`
   as `bytea`, file-first reconcile (converged / re-insert after DB restore /
   mint), 0400 render, env-or-plain format, per-key `restartUnits`, per-key
   `|| fail=1`. Committed `472b84e4a`.
3. **`services.immich.apiKeys.<name>` option** in
   `modules/nixos/services/immich.nix` — `permissions`, `keyFile`, `owner`,
   `group`, `url`, `restartUnits`, documented rotation contract. `472b84e4a`.
4. **Converger unit + daily timer generated** from that option
   (`immich-api-key-provision`, guarded on non-empty keys, `harden` +
   `ioTier.background` + `ProtectSystem=strict` + `ReadWritePaths` from the key
   files). Added this turn; swept into `ef4a66aec`. **Eval-probed:**
   `serviceExists=true`, `timerExists=true`, `OnCalendar=daily`,
   `ExecStart=/nix/store/94vbsr8d…-immich-api-key-provision/bin/immich-api-key-provision`
   — and that wrapper **builds clean (shellcheck gate passes)**.
5. **Concrete consumer declared:**
   `services.immich.apiKeys.takeout-import` in
   `platforms/nixos/system/configuration.nix` — immich-go's documented
   permission set minus `asset.delete`, owner `lars:users`, env format,
   URL derived from `ports.immich`.
6. **`scripts/deploy.sh` carries `immich-api-key-provision`** in the
   provisioner loop with a justifying comment (commit `f6072fd39`, daemon
   sweep; content is correct — see §d for the provenance caveat).
7. Parse checks pass on all three touched Nix files.
8. **Fleet state re-confirmed unchanged** (no accidental work): racedriver8k
   0/23; helpless.ai 7 parts / 22 GB CRC-clean; ledger 1,300 rows; `balance`
   BALANCED; 11 TB free; nothing ingested; nothing deleted.

---

## b) PARTIALLY DONE

1. **The key rework is ~70 %.** The module side exists; the CONSUMER side does
   not. `scripts/takeout-ingest-photos.sh:39` still requires
   `<staging>/immich-api-key` — the exact thing the owner objected to. Until
   that line changes, the feature is dead code and the insecure path remains
   the documented one.
2. **Verification is 70 %.** Parse green; eval probe green (unit + timer,
   daily calendar, wrapper path); wrapper build green (shellcheck). Still
   missing: the negative leg (unit absent with zero keys), a permissions-SQL
   inspection, and a tree-wide `nix flake check`. The FIRST eval probe failed
   with `The option 'systemd.immich-api-key-provision' does not exist` — the
   timer must be written `timers.<name>` at the `systemd` level, not `<name>`
   inside a `timers = { … }` attrset (this module uses the flat
   `timers.foo = …` form). Restored and re-probed green.
3. **Plan document vs execution:** Level-1 tasks K1/K2 are done, K4 is done by
   someone/daemon; K3/K5 are open. Everything from V1 onward is untouched.
4. **Documentation:** the plan exists, but `docs/services/immich.md` key
   lifecycle, the fleet-plan delta, TODO rows and CHANGELOG are NOT updated —
   so the repo currently contradicts itself about where the takeout key lives.

---

## c) NOT STARTED

- K3 repoint of `takeout-ingest-photos.sh` (env-file read, `TAKEOUT_IMMICH_ENV`
  override, env fallback, 0400 assertion, honest error text).
- K5 build + shellcheck + negative leg + `nix flake check`.
- V1/V2 `takeout-verify.sh` manifest-trap fix + leakage selftest.
- C1/C2 selftest wiring into `flake/parts/checks/selftests.nix` (dedup 16
  legs, intake 7 legs, CRC corruption fixture).
- X1 `takeout-extract.sh` (member-scoped, rc-11 aware, capacity-gated).
- L1 ledger relpath normalization.
- G1–G4 ingest gates (blocked on extraction + credentials).
- T1–T3, O1, H1–H2 (observability, intake hardening, rename wrapper, rhythm,
  docs/monitoring).
- Commit + push of this turn's own fixes (explicitly requested, not yet done).

---

## d) TOTALLY FUCKED UP (honest list)

1. **I broke the timer line twice.** The module uses the flat
   `systemd.timers.<name>` form; inside the `services = { … }`/`timers.foo`
   layout my new timer must be written `timers.immich-api-key-provision`.
   Commit `92ccead09` (20:32) carried exactly that correction (plus an
   alejandra reformat) — most plausibly a parallel session or a formatter pass
   fixing my bug. I then misread it as a regression, removed the `timers.`
   prefix, and produced `The option 'systemd.immich-api-key-provision' does
   not exist` on the next eval. Caught by my own probe, restored minutes ago;
   eval re-running. Lesson: in this shared tree, re-read the file and evaluate
   BEFORE "correcting" someone else's line.
2. **I left a half-feature in `main` twice.** First as "options + helper only"
   (reported as dead code), now as "module complete, consumer not repointed".
   A reader of `immich.nix` would reasonably believe takeout ingest is wired;
   it is not.
3. **deploy.sh provenance is unclear.** The entry appeared in a daemon sweep
   at 20:40 and references my new lib file. Either a parallel session wired it
   or the sweep captured an edit I do not remember making. I am reporting it
   as unverified authorship rather than claiming it.

---

## e) WHAT WE SHOULD IMPROVE

1. **Finish one vertical slice before starting another.** The key work is the
   only unblocked gate; it should have been end-to-end (module → declaration →
   script → verify) in a single pass.
2. **Re-read a file immediately before editing** in this shared tree; the
   `file has been modified since it was last read` guard exists because
   parallel sessions rewrite lines mid-flight.
3. **Claim discipline:** "the converger exists" and "takeout ingest uses it"
   are different claims; only the first is true.
4. **Stop queueing fixes as TODOs when they gate live data** — the
   `takeout-verify.sh` manifest trap should have been fixed the moment the
   second account's data landed.
5. **One implementation per contract:** discordsync and media-atlas still carry
   bespoke copies of the converger; the new lib is the third. Migrate them.
6. **Plan the owner hand-offs into the plan itself** (B1–B7 already are), so
   agent effort is always pointed at unblocked work.

---

## f) NEXT — up to 50 concrete actions (ordered by impact)

1. Repoint `takeout-ingest-photos.sh` at the env file; delete the
   `<staging>/immich-api-key` requirement.
2. Build the converger wrapper and let shellcheck gate it.
3. Eval-probe: unit + timer exist with a key, absent with none.
4. Inspect the rendered permissions SQL for `takeout-import`.
5. `nix flake check --no-build` green.
6. Update `docs/services/immich.md` with the key lifecycle + rotation.
7. Update TODO_LIST.md + docs/todo/services.md rows (106 / 126 / 626 / 480).
8. CHANGELOG entry for the converger + takeout key.
9. Commit + push (explicitly requested).
10. Fix `takeout-verify.sh` manifest inheritance.
11. Add the no-leakage selftest leg.
12. Wire `takeout-dedup.sh --selftest` into flake checks.
13. Wire `takeout-intake.sh --selftest` into flake checks.
14. Add a CRC corruption fixture for the rename loop.
15. Write `takeout-extract.sh` with the capacity gate.
16. Make rc 11 explicit in every extraction path.
17. Normalize ledger relpaths.
18. Document the ledger schema + re-index recovery.
19. Add `index` progress output.
20. Add `plan` byte totals.
21. Add `balance --summary`.
22. Add `balance --preflight` (capacity rule as code).
23. Harden intake with an account-email check.
24. Add `--ingest` chaining to intake.
25. Promote the rename loop out of `~/.cache`.
26. Migrate discordsync onto `services.immich.apiKeys`.
27. Migrate media-atlas's outbound key onto the option.
28. Migrate drive-paperless off the sops paste path (TODO 626).
29. Add the converger to system-health monitoring.
30. Emit a staging-size textfile metric.
31. Extract `Takeout/Google Photos` for helpless.ai.
32. Run the G3 dry-run and reconcile counts.
33. Run the real G3 import.
34. Spot-check 3 albums.
35. Obtain the OpenCloud app password.
36. Install/configure `rclone`.
37. G4 dry-run copy.
38. G4 real copy + `rclone check` + count 1,300.
39. Rate `dedup/other.txt`.
40. G5 Paperless run + reconciliation.
41. G6 `balance` after each ingest.
42. Build the 2-monthly rhythm (timer + runbook).
43. Decide the Mail end state.
44. Offsite/Borg coverage for the takeout archive.
45. racedriver8k: owner click-through (B1).
46. helpless.ai: owner exports-page save (B2).
47. Accounts 3–N registry rows.
48. Capacity watchdog before bulk extracts.
49. Restore-path test: one file from zip → extract → hash match.
50. Archive the two superseded status reports' open rows into the domain files.

---

## g) THREE QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Accounts 3–N:** which Google accounts remain, and for each: retire
   (full Takeout) or keep (incremental Drive/Mail sync)? That sets the
   registry, the cadence and the capacity plan.
2. **helpless.ai ingest precedence:** do we (a) finish Photos→Immich first,
   (b) finish Drive→OpenCloud first, or (c) run them in parallel? Only one
   transient extract at a time is the constraint; the order changes what is
   provable this week.
3. **The 7-part helpless.ai download:** is it complete as far as the exports
   page shows? If the page lists more parts, G2 stays UNPROVEN and I need the
   saved page to close it.
