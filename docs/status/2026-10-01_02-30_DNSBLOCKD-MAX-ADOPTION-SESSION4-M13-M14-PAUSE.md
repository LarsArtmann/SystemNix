# DNSBLOCKD Max-Adoption — Session 4 (M13 + pixel6 decommission + M14 in-flight, PAUSED on user order)

Date: 2026-10-01 02:30 CEST. Plan: `docs/planning/2026-09-30_12-13_DNSBLOCKD-MAX-ADOPTION.md`.
Session 4 resumed from the session-3 WAIT on the user's execution directive, then was
interrupted mid-M14 by the user's status-report order ("REPORT … WAIT"). This report covers
the ~20 minutes of work in between. Standing guards held throughout: NO deploy, NO
tracking_mode flip, NO amend of foreign commits, pathspec-only commits, never pushed.

Prior reports: `docs/status/2026-09-30_13-07_DNSBLOCKD-MAX-ADOPTION-W1-W4-EXECUTED.md`
(sessions 1-2), `docs/status/2026-10-01_02-11_DNSBLOCKD-MAX-ADOPTION-SESSION3-M10-M12.md`
(session 3; NOTE: that file is still UNTRACKED — the daemon never committed it, see §d5).

## a) DONE this session

1. **M13 TODO harvest — annotations complete, 1 of 3 files committed.**
   - `docs/todo/upstream.md`: both tag rows updated — COMMITTED as `6e2559ae`
     ("docs(todo): dnsblockd tag rows updated - lock deployed at f625cfee", subject 66 chars,
     pre-commit green). Housekeeping row: lock bump DONE+DEPLOYED, only the 2 daemon docs
     commits + pin-stance ratification remain; the 2026-09-17 duplicate tag-cut row marked
     SUPERSEDED.
   - `TODO_LIST.md`: all 5 dnsblockd queue rows (:222-226) annotated with deployed-live
     facts (system-810, lock f625cfee, config store 0ry4913f, smoke probe 4ba06298). Kept
     `[ ]` deliberately — no `[x]` until the user dashboard walk (session-3 Q3). IN WORKING
     TREE, uncommitted (see §d6).
   - `docs/todo/services.md`: all 8 library rows (:61-68) annotated with the same facts,
     including the extraDomains resolved-by-wiring note and the M11 deploy-attribution-open
     note. IN WORKING TREE, uncommitted.
   - `bash scripts/check-todo-system.sh` → OK (structure clean).
2. **Pixel 6 decommissioned from the dnsblockd registry (owner input, this session:
   "I do NOT use pixel6 anymore (it broke!)").**
   - `platforms/nixos/system/dns-blocker-config.nix`: pixel6 device entry (id, MAC-note,
     192.168.1.29) DELETED; Lars's user ownership reduced to `evo-x2`. Registry now:
     evo-x2, rpi3-dns, lan-router, lg-tv. Rides the next (user-owned) deploy.
   - Swept the whole config surface (`platforms/ modules/ lib/ flake.nix`): ZERO other
     pixel6 / 192.168.1.29 references — dns-blocker-config.nix was the only one.
   - Queue/library annotations updated to "pixel6 DECOMMISSIONED by owner 2026-10-01
     (entry removed, rides next deploy), lg-tv identity confirm open".
   - `docs/todo/pixel6.md` header annotated: DEVICE DECOMMISSIONED; all 21 open items work
     on the EXTRACTED archive and stay valid (nothing new can be pulled).
3. **M14 (policies option) — researched + authored, verification interrupted.**
   - Upstream contract captured from source (dnsblockd @ f625cfee): `PolicyConfig` =
     {name, groups, devices, allow, block, schedule} (config.go:263); caps 64 policies /
     512 domains per arc / 16 windows (policy.go:20-23); slug names a-z0-9- 1-64 (validSlug);
     ErrNoTargets = policy without devices or groups is invalid (policy.go:168);
     refs must resolve against the declared device registry incl. groups
     (validation.go:456-507); schedule grammar = comma-separated HH:MM-HH:MM, Atoi-based
     clocks, empty = always (policy.go:346). Shadow endpoints verified:
     `GET /api/policies/shadow` (handlers.go:511, protected/Bearer) and
     `GET /api/policies/shadow/impact` (insight_handlers.go:214/407) — shadow aggregates
     would_block on allowed queries; config-carried policies have NO separate enabled flag
     (remove to stop enforcing) — description written to match.
   - Wrapper option `services.dns-blocker.policies` AUTHORED (submodule: name strMatching
     slug / groups / devices / allow / block / schedule str, defaults []/"").
   - Render wired: `// lib.optionalAttrs (cfg.policies != [ ]) { policies = cfg.policies; }`
     after the users block (verbatim pass-through, same pattern as devices/users).
   - 6 assertions added mirroring upstream: caps (64/512/16), duplicate names, no-targets,
     dangling device refs, dangling group refs, schedule format (zero-padded HH:MM-HH:MM
     — deliberately stricter than upstream's Atoi tolerance, documented in the assertion).
   - Eval: `nix eval .#nixosConfigurations.evo-x2.config.services.dns-blocker.policies` → `[]` (green).
   - deadnix: clean. statix: 1 pre-existing documented non-gating (:395) + **1 NEW at :385
     from my policies render line** (Assignment instead of inherit) — fix queued, see §f1.

## b) PARTIALLY DONE

- **M14**: option+render+assertions+upstream-research done; MISSING: render-test extension
  (positive variant targeting `lg-tv` + host-config "policies absent" content assert),
  negative eval cases (bad slug / dangling refs / no-targets / cap overflow / bad schedule
  — assertions must fire via the config.assertions forcing pattern), worktree negative-proof
  (mutate → check derivation must fail), commit.
- **M13**: content complete everywhere; commit state split — upstream.md in (6e2559ae),
  TODO_LIST.md + services.md pending (§d6).
- **M11 agent side**: unchanged from session 3 (deploy live, verification done); user
  dashboard walk + attribution still open (§g3).

## c) NOT STARTED

M15 (trial blocklists + persistent cache dir), M16 (ECS), M17 (h3), M18 (mapping table +
baseline), M19-M20 (W8 migration impl), M21 (migration verification), M22 runbook,
close-out report.

## d) TOTALLY FUCKED UP (this session)

1. **Left one NEW statix warning in the tree at pause** (:385, my `policies = cfg.policies;`
   — statix prefers `inherit (cfg) policies;`). Known fix, not applied because the user's
   report-now order interrupted. First action on resume.
2. **Wrote "4 devices" in the M13 annotations while the FILE held 5** — the number came
   from the deployed-config probe (4) while dns-blocker-config.nix had 5 entries at
   authoring time. Ambiguous claim; only became consistent after the pixel6 removal made
   the file 4 too. Lesson restated: count claims must name WHICH surface (file vs deployed).
   Post-removal the deployed set is unverified against the file (which 4?) — next user
   deploy converges; verify then (§f25).
3. **Three edit-tool stale-read failures this session** (docs/todo/services.md, TODO_LIST.md,
   docs/todo/pixel6.md) — all parallel-session mtime races; the known rule is re-read before
   every edit in an active tree, and I still paid three roundtrips. Used a python
   assert-single-replace fallback once (worked, single-count asserted).
4. Session-3 carryover reminder: two overlong commit subjects (73/74 chars) — the ≤70 +
   awk-verify rule is now mechanical; this session's one commit (6e2559ae) was 66.
5. **The session-3 status report (02-11 file) is STILL UNTRACKED** — I never verified its
   landing (it was left "for the daemon" and the daemon has not fired since ~6dfcf827).
   It now sits beside two other untracked parallel-session reports. On resume: check where
   it landed before writing ANY new status file (this one included — same exposure).
6. **M13 annotations for TODO_LIST.md/services.md are uncommitted** with foreign hunks in
   both files (parallel caddy-session rows). Pathspec-committing would sweep foreign work
   into my commit (forbidden); the 75s daemon wait produced nothing. Left riding — if the
   daemon stays idle they sit indefinitely. Mitigation queued (§f6).

## e) WHAT I SHOULD IMPROVE

1. Persist the smoke-block test harness (stub systemctl + report_* + sourced block) as a
   committed fixture — third time rebuilt from scratch across sessions (offsite-borg
   `test-offsite-borg-smoke.sh` precedent).
2. Session-start checklist gains two probes: `git status --short` (parallel density) AND
   daemon-cadence check (last heuristic commit age) — decides wait-for-daemon vs
   annotate-and-move-on before touching shared files.
3. Write statix-clean Nix at authoring time for this file (the inherit-from suggestions are
   now known shapes); linting after the fact costs a context switch every time.
4. The "count surfaces by name" rule from §d2 should apply to ALL inventory prose, not
   just device counts.

## f) NEXT (ordered, resumable)

1. Fix statix :385 — switch the policies render to `inherit (cfg) policies;` (or accept as
   non-gating per precedent; prefer clean).
2. Extend `tests/test-dns-blocker-render.nix`: policies positive variant (extendModules,
   one policy targeting `lg-tv`, assert ExecStart differs from host = anti-phantom),
   content assert on the variant's realized YAML (policies[0] shape, schedule passthrough),
   host-config assert `"policies" not in cfg` (optionalAttrs omission).
3. Negative eval cases: bad slug (tryEval on option force), dangling device ref, dangling
   group ref, no-targets, cap overflow (513 domains), bad schedule ("25:00-26:00",
   "9am-5pm") — each must produce a failing dns-blocker.policies assertion in
   config.assertions (gate-timeout-audit forcing pattern).
4. Worktree negative-proof: `git worktree add /tmp/X HEAD`, sed-mutate the assertion out,
   `nix build .#checks.x86_64-linux.dns-blocker-render` from the worktree must FAIL.
5. M14 commit (pathspec, subject ≤70 awk-verified).
6. Commit the pending M13 annotations (TODO_LIST.md + services.md) the moment the files
   carry no foreign hunks (daemon fired or parallel session settled).
7. M15: author `blocklistTrialUrls` (listOf str, default []).
8. M15: `blocklistCacheDir` — PERSISTENT `/var/lib/dnsblockd/blocklist-cache` (PrivateTmp
   eats the /tmp default); StateDirectory + ReadWritePaths + mount-gating-audit compliance;
   render `dns_blocklist_trial_urls` + `dns_blocklist_cache_dir` behind optionalAttrs.
9. M15: render-test extension + commit.
10. M16: `dnsEcsEnabled` (bool, default false) + `dnsEcsIpv4Prefix` (24) / `dnsEcsIpv6Prefix`
    (56) — INERT defaults, owner nod required before evo-x2 flips them.
11. M16: doc the privacy tradeoff (forwarders observe the client /24) in the option text.
12. M16: render-test extension + commit.
13. M17: `tlsH3Enabled` (bool, default false) — inert default + why-comment.
14. M17: firewall review note — UDP 443 must be open for h3 block pages when enabled
    (check `platforms/nixos/system/networking.nix` open-ports at that point).
15. M17: render-test extension + commit.
16. M18: option-by-option mapping table (wrapper ↔ upstream `nix/modules/nixos/` module).
17. M18: overlay list — runtime whitelist pre-filter, attach-ip unit + ordering, omd
    exemption, sops CA material (things upstream cannot express).
18. M18: pre-migration baseline — worktree eval JSON of rendered YAML + unit text
    (surface-preservation set-compare input; paperless-/admin lesson).
19. M19: migration impl A — consume upstream nixosModules, map W1-W7 keys.
20. M20: migration impl B — re-add SystemNix overlays (whitelist filter → blocklistFiles
    post-processing; harden/oomd layering; sops CA).
21. M21: migration verification — baseline set-compare (order-insensitive where semantic)
    - VM test green; zero silent surface loss.
22. M22: prepare the USER cutover runbook (deploy + smoke + watch DNS one restart cycle) —
    agent never deploys.
23. Close-out report superseding `docs/status/2026-09-30_13-07_*`: dead-SHA corrections
    (`accb0522`/`40eeac48` → content citations), M12 attribution note (content landed via
    `6dfcf827` + `bba88c9e`), full M01-M22 disposition table in the plan doc.
24. Verify where the 02-11 session-3 report landed (and this one) — cite, never duplicate.
25. After the next user deploy: verify pixel6 absent + 4-device convergence in the live
    config (deployed store path grep), close the §d2 ambiguity.
26. Adjacent queued rows (NOT this plan, already owned elsewhere): HaGeZi SRI refresh
    cadence; h2 block-page coverage + ALPN gotcha; dnsblockd /health cached-response
    live probes (sudo/user-gated).
27. If the owner sanctions the tracking flip (§g2): flip `tracking_mode` in the SAME commit
    as the test-assertion update (M09 gate procedure).

## g) THREE QUESTIONS (cannot resolve myself)

1. **lg-tv confirm (narrowed Q1):** is 192.168.1.62 (Realtek NIC 00:e0:4c:…) really the
   LG TV SSCR2 — and are the `rpi3-dns` (.151) and `lan-router` (.1) registry entries
   wanted as-is? (pixel6 half of Q1 is resolved by your decommission — entry already
   removed, rides your next deploy.)
2. **Tracking dial (Q2, unchanged):** hold METADATA_ONLY or flip to METADATA_AND_DNS?
   Memo with the tradeoffs: `docs/services/dnsblockd-tracking-dial.md`. Flipping needs
   your sanction + a same-commit test-assertion update (planned, ready to execute on nod).
3. **M11 attribution (Q3, unchanged):** did YOU run the system-810 deploy (or a parallel
   session), and has the dashboard walk happened? Closes the M11 checklist, the queue rows'
   `[ ]` → `[x]`, and the session-3 report's open question.

— Session paused per user order. All guards intact; nothing deployed; nothing pushed.
