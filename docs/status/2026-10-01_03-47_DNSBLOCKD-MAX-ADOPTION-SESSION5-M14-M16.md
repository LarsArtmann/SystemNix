# DNSBLOCKD Max-Adoption — Session 5 (M14–M16 executed, M17+ pending)

Date: 2026-10-01 03:47 · Host: evo-x2 · Repo: SystemNix (master)
Scope of this report: THIS session only (resumed from the 02-30 pause report at user directive "READ, UNDERSTAND, RESEARCH, REFLECT… Keep going").

## Executive summary

Resumed at the M14 resume point and executed M14, M15, M16 to completion — each with build-proven tests AND worktree negative proofs (mutation → check fails). Root-caused one foreign repo-wide commit blocker (checks.paperless) and fixed it (`3e85cf1a`, my only attributed commit this session; every other change rode daemon/parallel sweeps — content-cited below). M17 (h3) through M22 plus close-out remain.

---

## a) FULLY DONE (this session)

1. **M14 — policies option complete.**
   - Statix warning root-caused and FIXED: it was never `policies = cfg.policies;` — statix misattributes the `users = cfg.users;` assignment onto the next `//` operand. Converted both `users` and `policies` renders to `inherit (cfg) …;`. Module is now statix-CLEAN (0 warnings; deadnix clean too).
   - Render test extended (10 new checks): host-inert (`policies == []`), anti-phantom (`policiesExec != exec`), and SEVEN negative eval proofs — 512-domain cap, 64-policy cap, duplicate names, no-targets, dangling device, dangling group, bad schedule — plus slug type-check via tryEval.
   - **New hard-won lesson (build-proven twice):** submodule field type errors (strMatching) are DEFERRED into the value. Forcing the option, or `builtins.map` over it, SUCCEEDS; the error lives in the field. The witness must strictly force each field — `builtins.all (p: builtins.isString p.name)` does; the lazy variants phantom-passed (check build FAILED with the lazy witness, new store path passed with the strict one).
   - Content asserts: host config has NO `policies` key (optionalAttrs guard); variant renders the policy verbatim (name/devices/groups/allow/block/schedule).
   - Worktree negative proof: sed-mutating the two dangling-ref assertions to `true;` made exactly those two checks fail.
   - Landed: bulk via daemon `d89029cf`; final strict-witness + statix form via parallel `deab8469` (my commit attempt hit "no changes" — swept mid-flight).
2. **Foreign repo-wide commit blocker FIXED — `3e85cf1a` (attributed to me).** `deab8469` (foreign, "wire Paperless SSO group mapping") sets `services.pocket-id-config.provision.userGroups` behind an `options ?` guard — but an empty attrset is still a definition, so `checks.x86_64-linux.paperless` died "option does not exist" and the pre-commit flake-check leg blocked EVERY commit in the repo. Extended the test's `pocketIdEnableMock` with `provision.userGroups` + `provision.adminUser.username` leaves (the file's own documented mock pattern). Check evals green; hooks passed.
3. **M15 — trial blocklists + persistent URL cache dir.**
   - `blocklistTrialUrls` (listOf str, default []): feeds upstream T197 shadow-only trial blocklist (`request_tracks.would_block`, `trial:` source prefix, never enforcing).
   - `blocklistCacheDir` (str, DEFAULT `/var/lib/dnsblockd/blocklist-cache`): upstream's `os.TempDir()` default is eaten by PrivateTmp — a reboot + upstream outage would boot an EMPTY blocklist. StateDirectory already grants the write surface; no unit wiring needed (verified: `StateDirectory = "dnsblockd"`, WorkingDirectory matches).
   - Two eval assertions mirroring upstream validation: http(s)-URL-with-host shape (mirrors `errInvalidBlocklistURL` semantics for the trial fetcher), absolute path (`errInvalidBlocklistCacheDir`).
   - Test extension: `trialExec` anti-phantom variant, host-default content asserts (`dns_blocklist_cache_dir` present, `dns_blocklist_trial_urls` absent), both negative proofs. Worktree mutation of both assertions → exactly both checks fail.
   - Landed: daemon `bbfd04fa` (my pathspec commit raced to "no changes").
4. **M16 — EDNS Client Subnet options, INERT.**
   - `dnsEcsEnabled` (bool, default false — owner-gated privacy tradeoff documented in the option text: forwarder learns /24 or /56 locality), `dnsEcsIpv4PrefixLen`/`dnsEcsIpv6PrefixLen` (int, default 0 = upstream's 24/56).
   - Range assertion (IPv4 1-32, IPv6 1-128 when non-zero) mirroring upstream `ipv4BitLength`/`ipv6BitLength` constants — upstream has NO config-level validation here, eval-time is the only gate.
   - Test extension: `ecsExec` variant, inert-host asserts (`dns_ecs_enabled: false` rendered, prefix keys OMITTED at 0), verbatim-render asserts, negative proof (IPv4=33 fires). Worktree-mutation verified.
   - Landed: daemon `cb914fd1`.
5. **Verification receipts:** render test final store `a7z8v64g…` (content marker names all seven pinned surfaces); negative-proof failure derivations logged per mutation; `nix flake check --no-build --all-systems` green at session end; statix+deadnix clean on both files.

## b) PARTIALLY DONE

- **Session-4 leftovers consolidated by the daemon:** TODO_LIST.md, docs/todo/services.md, docs/todo/pixel6.md, dns-blocker-config.nix (pixel6 removal), both status reports (02-11, 02-30) all landed via daemon `6d5bbd1a` early this session — so the "uncommitted" state from the pause report is RESOLVED (content-cited, not attributed).
- **Working tree at pause (03:47):** `paperless.nix` + `test-paperless.nix` carry FOREIGN modifications (a parallel session is extending the same area — do NOT touch), `scripts/check-todo-system.sh` foreign-modified. Nothing of mine is uncommitted.

## c) NOT STARTED

- **M17** — `tlsH3Enabled` (bool, default false, inert) + UDP-443 firewall review note; render test.
- **M18** — wrapper↔upstream option mapping table + pre-migration baseline (worktree eval JSON: rendered YAML + unit text).
- **M19–M20** — W8 migration: consume upstream `nix/modules/nixos/` module, map W1–W7 keys, re-add SystemNix overlays (runtime whitelist pre-filter, attach-ip unit ordering, omd exemption, sops CA, harden/oomd).
- **M21** — migration verification: baseline set-compare + VM test green, zero silent surface loss.
- **M22** — user cutover runbook ONLY (deploy + smoke + one DNS restart cycle watch). NO deploy by me, ever.
- **Close-out report** superseding `docs/status/2026-09-30_13-07_*` (dead-SHA corrections `accb0522`/`40eeac48` → content citations; M12 attribution note).
- **Plan-doc disposition table** (M01–M22 status in the plan file) — not updated this session.

## d) TOTALLY FUCKED UP (honest ledger)

1. **Statix :385 was misdiagnosed in the session-4 pause report.** I blamed `policies = cfg.policies;`; the real offender was the `users = cfg.users;` assignment mispositioned by statix onto the next operand. My first "fix" (policies→inherit) changed nothing; only converting BOTH assignments cleared it. The pause report documents the wrong root cause.
2. **Three daemon-commit races burned roundtrips.** M14-witness, M15, and M16 pathspec commits all hit "no changes added to commit" because the daemon swept the files between my build verification and the commit (seconds to minutes). I verified first and committed last — the safe order for correctness, the losing order for attribution.
3. **Self-inflicted edit churn:** my cosmetic rename (`policyAssertionFires` → `assertionFires`) was half-reverted by my own follow-up edit (replace-first-occurrence semantics); I kept the old name. Sloppy edit chaining on a file under daemon formatting pressure.
4. **Three mtime-race edit failures** (stale reads on the shared test file as the daemon's formatting leg reflowed it). Each cost a re-view roundtrip. The discipline (re-view before every edit) worked, but I re-learned it three times in one session.
5. **One transient foreign block misread as mine:** my first M15 commit died on a `manifestPort` eval error from the parallel session's dirty `mr-sync.nix` mid-edit; I re-ran the identical all-systems check minutes later — green, nothing changed by me. Correctly diagnosed as transient on the second probe, but the first reaction was "reproduce and fix" rather than "wait for the tree to quiesce".

## e) WHAT WE SHOULD IMPROVE

1. **Commit racing the daemon:** for small verified diffs, commit IMMEDIATELY after the build gate (before writing docs/reports), or deliberately let the daemon take attribution and record content citations in the NEXT status report (current de-facto pattern — make it explicit policy).
2. **Negative-proof witness library:** the deferred-error/tryEval/isString pattern is now proven twice — copy it verbatim for any future submodule-type negative tests instead of rediscovering the laziness semantics.
3. **Statix position reports are untrustworthy across `//` chains** — when a statix warning points at an optionalAttrs CONDITION, suspect the PRECEDING sibling assignment. Worth a line in AGENTS.md if it recurs.
4. **The empty-attrset-is-still-a-definition trap** (paperless/deab8469) is the THIRD occurrence of the class in this repo's history (integration.nix 2026-09-15, catalog 2026-09-23, now paperless). A general eval-time lint ("any `optionalAttrs (options ? X)` whose result is ASSIGNED to `services.X` without mkIf-wrapping inside an existing declaration context") would kill the class — candidate flake check.
5. **Parallel sessions are now densely interleaved** (three foreign commits landed during my statix fix alone). For W8 (M19–M20) — a large structural change — coordinate: check `git log` immediately before each phase and prefer small verifiable steps over one big migration commit.

## f) NEXT UP TO 50 (ordered)

1. M17: `tlsH3Enabled` option (inert false) + render behind optionalAttrs.
2. M17: UDP-443 firewall review (check networking firewall ports for dnsblockd TLS/h3 surface) — note in option text + runbook.
3. M17: test extension (`h3Exec` variant + host-inert assert) + worktree negative proof if an assertion exists (h3 likely needs none — pure passthrough).
4. M17: commit (fast, post-build).
5. M18: enumerate wrapper options (grep `mkOption` in dns-blocker.nix) → build the mapping table against upstream `nix/modules/nixos/` options.
6. M18: write the mapping table into the plan doc (or a dedicated migration doc under docs/planning/).
7. M18: pre-migration baseline — worktree at current HEAD, `nix eval` rendered config JSON + `systemd.services.dnsblockd` unit text to /tmp JSONs.
8. M18: overlay inventory list (whitelist pre-filter, attach-ip ordering, omd exemption, sops CA, harden/oomd, ioTier) with current code refs.
9. M19: read upstream `nix/modules/nixos/` module in full (option names, defaults, unit rendering).
10. M19: impl A — import upstream nixosModules in a VM-test-first shape (extendModules probe before touching evo-x2).
11. M19: map W1–W7 keys (allowlist_path, extraDomains→?, rate limits, log sampling, tracking_mode, devices/users/policies, trial/cache/ECS).
12. M19: keep `services.dns-blocker` name or introduce `services.dnsblockd` alias decision (avoid split-brain during migration).
13. M20: re-add runtime whitelist pre-filter overlay as blocklistFiles post-processing.
14. M20: re-add attach-ip unit + ordering constraint.
15. M20: re-add omd exemption.
16. M20: re-add sops CA wiring (dashboard TLS).
17. M20: re-add harden/oomd/ioTier serviceConfig overlays.
18. M20: confirm StateDirectory/WorkingDirectory/allowlist persistence survive.
19. M21: set-compare baseline vs migrated (rendered config keys, unit serviceConfig keys) — order-insensitive, store-path-noise filtered.
20. M21: VM test green (existing test-dns-blocker-render must pass unchanged against migrated module).
21. M21: diff gatus checks + integration registry entry survived.
22. M22: write the user cutover runbook (deploy command, post-deploy smoke list, DNS restart-cycle watch procedure, rollback).
23. M22: pre-populate the runbook's verification commands from scripts/post-deploy-check.sh §-list.
24. Close-out: supersede `docs/status/2026-09-30_13-07_*` with final M01–M22 disposition.
25. Close-out: correct dead-SHA citations (`accb0522`/`40eeac48`) to content citations.
26. Close-out: M12 attribution note (`6dfcf827`/`bba88c9e`).
27. Plan doc: fill the M01–M22 disposition table.
28. Q1-dependent: adjust lg-tv/rpi3-dns/lan-router device entries per owner answer.
29. Q2-dependent: tracking_mode flip (ONLY with owner sanction + same-commit test-assertion update).
30. Q3-dependent: mark the 5 TODO_LIST queue rows `[x]` once the dashboard walk is confirmed.
31. Update docs/services/dnsblockd.md runbook with M14–M17 surfaces (policies, shadow API usage, trial observation workflow, ECS tradeoff, cache dir).
32. Add `GET /api/policies/shadow` observation examples (Bearer) to the runbook.
33. Consider a first REAL policy config after owner nod (e.g. tv-night on lg-tv) — config addition, rides a user deploy.
34. Consider promoting 1–2 trial blocklists after a soak (owner decision).
35. AGENTS.md: one-line lesson for the deferred-submodule-type-error witness pattern.
36. AGENTS.md: statix misattribution-across-`//` note (if it recurs).
37. Candidate flake check: empty-attrset-definition lint (see e.4).
38. Sweep: does any OTHER module assign `optionalAttrs (options ? X)` to `services.X`? (grep; fix or lint.)
39. Verify the parallel session's current paperless.nix/test-paperless.nix edits don't conflict with my mock fix (re-read once they land).
40. Watch: `scripts/check-todo-system.sh` foreign modification — ensure TODO edits still validate (`bash scripts/check-todo-system.sh`) before my next TODO-file edit.
41. After W8: retire dead wrapper code paths (options fully subsumed upstream) per plan F-rows.
42. After W8: update `docs/todo/upstream.md` housekeeping row (module migration state).
43. Confirm evo-x2 config still evals after EVERY phase (nix eval toplevel drvPath — cheap gate).
44. Keep `nix flake check --no-build --all-systems` green at each commit boundary (hook does this; rely on it, don't duplicate).
45. If lock moves during W8 (it must NOT — f625cfee hold), re-verify FOD probe first.

(45 concrete items; the remaining five slots stay reserved for Q1–Q3 answers which gate device/policy/tracking work.)

## g) QUESTIONS (cannot resolve myself)

1. **Device registry identity (blocks Q1 follow-through):** is `lg-tv` at 192.168.1.62 (Realtek 00:e0:4c OUI) really the LG TV — and do you want `rpi3-dns` (.151) and `lan-router` (.1) kept as managed devices, or is the registry meant to be evo-x2 (+lg-tv) only?
2. **Tracking dial:** flip `tracking_mode` off METADATA_ONLY per the memo at `docs/services/dnsblockd-tracking-dial.md`, or hold? (Flip requires your sanction + same-commit test-assertion update — I will not touch it otherwise.)
3. **M11 deploy provenance + dashboard walk:** did YOU run the system-810 deploy (02:xx window), and did the dnsblockd dashboard walk-through happen? (Determines whether the 5 TODO_LIST queue rows get `[x]`, and closes the attribution question from the 02-30 report.)

---

**State at WAIT:** tree carries only foreign modifications (paperless.nix, test-paperless.nix, check-todo-system.sh — parallel session's); my M14–M16 all landed (daemon/parallel-swept, content-verified); `3e85cf1a` is my attributed fix. WAITING FOR INSTRUCTIONS.
