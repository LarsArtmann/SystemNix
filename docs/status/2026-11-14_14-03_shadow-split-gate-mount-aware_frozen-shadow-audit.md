# Status Report — §18 Shadow-Split Gate Made Mount-Aware + Frozen-Shadow Audit

**Date:** 2026-11-14 14:03 CET · **Session:** single-agent, Crush (zai/glm-5.3) · **HEAD at authoring:** `ed504d37f` (9 unpushed heuristic daemon commits + `ddca5a53e`)

## Scope

**Verified live this session** (commands/artifacts): `findmnt` exact-target + FSROOT semantics against real mounts; the §18 gate before/after via `bash scripts/shadow-split-gate.sh` (production mode, nix eval + findmnt, log at `~/.cache/ss-gate-live.log`); fixture suite local (42 cases) + Nix sandbox via `nix build -L .#checks.x86_64-linux.shadow-split-gate-selftest` (39 — privileged leg skips by design); shellcheck on all three touched scripts; btrbk-projects journal (`journalctl -u btrbk-projects --since 2026-11-07`); pool receives (`ls /mnt/pool/backups/projects-subvol`, sudo cross-check); frozen shadows (`sudo du` over `/mnt/btrfs-root/@/…`, 14 paths); freshness metric (`sudo cat …/projects_subvol_backup.prom`); btrbk config (`platforms/nixos/system/snapshots.nix:528-547`); IO PSI at report time (`/proc/pressure/io`).

**NOT verified, and why:** the Gatus alert's own red state (the feeding metric `projects_subvol_backup_fresh 0` and the 36h-threshold alert config are verified; the Gatus API was not probed — "Gatus is red" is inference, flagged as such); the automount trigger+re-probe path against a genuinely *untriggered* automount (fixture-proven only — all live automounts were already triggered); a full `nix flake check` (only the single touched check attr was built — the selftests.nix edit is contained to one attr); whether the storm week's driver matters (explicitly out of scope per owner instruction).

---

## a) FULLY DONE

1. **§18 shadow-split gate: mount-state aware** — the core defect is fixed. Before: every steady-state line compared the hot-tier subvol **to itself** (content probes through a live mount read the subvol; parity band, PG_VERSION check, "both populated" PASS all self-comparisons — the output that misled the owner into reading dual-disk duplication). Now: `findmnt` exact-target probe first; fsroot-vs-declared-subvol match = PASS naming the real mount; foreign mount = FAIL (data) / WARN (cache); automount stacks trigger + re-probe once (WARN if backing never resolves); only unmounted shadows run the wave-6 ladder. Missing-`findmnt` exits 2 loudly (anti-phantom-green). Files: `scripts/shadow-split-gate.sh`, `scripts/test-predeploy-shadow-split.sh` (31→42 cases, incl. the anti-theater regression: populated shadow + EMPTY subvol + mounted row must PASS), `flake/parts/checks/selftests.nix` (+util-linux), `scripts/pre-deploy-check.sh` (wrapper text + header), `CHANGELOG.md`. **Live: 12/12 PASS with real fsroots, zero content probes through mounts.** Commits: `f6e95709a` + `f7ce7f352` (daemon-swept), `ddca5a53e` (amended, carries CHANGELOG + wrapper).
2. **Owner question 1 answered with evidence** (why 2 SSDs / pool ≠ second-SSD replacement): roles table, hot tier excluded from incremental-forever by doctrine C, QLC perf numbers, offsite-Borg dormant.
3. **Owner question 2 answered with evidence** (projects backup semantics): bounded `7d/14d/8w` pool retention by design (churn-hoarding rationale), 3d local snapshots, git remotes as the forever layer.
4. **Discovered + root-caused the stale btrbk-projects leg**: receives stopped after `projects.20261107T2310`; every 23:10 run since 11-08 REFUSED by `btrbk-admission` (IO PSI 40–87% storm nights + one memory-guard trip) — designed freeze-prevention (gate landed 2026-11-08), not a break. Metric honest (`fresh 0`, age ≈6.6d).
5. **Full frozen-shadow inventory measured** (the actual "data on 2 disks"): projects 132G + ~41G more (`~/tmp` 25G, journal 6.5G, discordsync 5.4G, dnsblockd 4.5G, go-build 4.4G, misc ~1G); caddy/forgejo/go-mod confirmed already clean.
6. **Todo harvest landed at finding time**: `docs/todo/storage.md` — projects row UPDATE (burn-in met + preconditions) + new [blocked:user] 41G-sweep row.

## b) PARTIALLY DONE

1. **Commit hygiene**: the gate/test/selftests code lives in heuristic daemon commits (`f6e95709a`, `f7ce7f352`) that were **already pushed** when I went to amend — only `ddca5a53e` (CHANGELOG + wrapper) carries a real message. Traceability preserved via the commit message naming them; readability residue is permanent (fixing = force-push, forbidden).
2. **btrbk-projects catch-up**: diagnosed + precondition documented; run not performed (correct in hindsight — PSI is 40% at report time, the gate would refuse anyway — but see §e.4: I verified that *after* deciding, not before).
3. **Automount trigger path (phase-2)**: fixture-proven, never live-proven against an untriggered automount.
4. **`nix flake check`**: not run over the selftests.nix change in a commit context (single-attr build is green; hook skipped it — amend carried no staged eval-relevant paths).

## c) NOT STARTED

- The shadow-cleanup itself (owner-gated by design: root + quiet window + 132G of IO).
- The 41G sweep execution (row queued this session).
- postgres 413M + incident residues (pre-existing [blocked:user] row, unchanged).
- Storm-week driver investigation (noticed, explicitly out of scope).
- `docs/services/projects-subvol.md` Phase F status sync (runbook still describes burn-in as open).

## d) TOTALLY FUCKED UP

**Nothing with lasting damage.** Process failures, all caught by guards, all wasted round-trips:

1. **`rg -rn` twice** — the documented replace-flag trap; hook-blocked both times. I tripped a known landmine the AGENTS.md file I was *operating from* explicitly warns about, twice, in one session.
2. **Edit-before-view ×3** (`selftests.nix`, `pre-deploy-check.sh`, `storage.md`) — I read regions with `sed` and then hit the edit tool's read-first gate. Each failure = one wasted round-trip into a racy shared tree.
3. **Daemon-push-before-amend**: I continued into CHANGELOG/docs work with a dirty tree instead of pathspec-committing the green test suite immediately; the daemon committed AND pushed the code first. The AGENTS amend-forward protocol only rescues the *unpushed* HEAD.

## e) WHAT WE SHOULD IMPROVE (self-review)

1. **Commit at every green boundary.** The test suite went green at ~12:20; the properly-messaged commit exists only for the tail files. Rule for next time: green suite → immediate pathspec commit, *then* docs.
2. **`rg -n`, always.** And read files with `view`, not `sed`, when an edit follows.
3. **Claim-grade discipline held, mostly**: "Gatus is paging" stayed hedged as inference in chat; the report names it as unverified. The "~126G" figure in my first answer was doc-sourced; measured 132G later — quotes should carry their provenance tag (estimate vs du).
4. **Probe-before-decide**: I chose recommend-only for the catch-up run on doctrine ("quiet window"), then verified PSI only at report time. The doctrine happened to be right; the *sequence* was luck-compatible, not verified. Cheap fix: 2-second `/proc/pressure/io` read before any "wait for calm" recommendation.
5. **Skill scan timing**: BuildFlow was loaded only mid-task when I noticed `.buildflow.yml`; the repo-coverage scan belongs at step 1 of any task that might format/build.
6. **Micro-split-brains found, not fixed** (harvested, §f.5): gate header still cites "storage.md ready row 1" (row evolved); §18 wrapper WARN summary text predates the new automount/foreign verdict vocabulary.
7. **No ghost systems created** — the new `SS_MOUNTS_FILE`/`after:` fixture mechanism is documented, wired, and tested; nothing exists unwired.

## f) NEXT (priority order; 1–5 harvested, 6+ owner-gated or watch)

1. `[ready]` §18 polish bundle: fix the stale "storage.md ready row 1" header pointer; add foreign-mount/automount vocabulary to the §18 wrapper WARN line; live-prove the automount trigger path against an untriggered automount.
2. `[watch]` btrbk-admission first-week observation: 6/6 refused nights (Nov 8–13) left the projects leg 7d stale while storms persist; if multi-week refusal streaks become normal, the nightly-only schedule needs a calm-window catch-up mechanism (Persistent=true only helps across reboots).
3. btrbk-projects catch-up run when PSI <20 (`sudo systemctl start btrbk-projects`) — precondition for #4.
4. Projects `shadow-cleanup` (132G; QLC 91%→~74%; tar.zst pool archive + bind-view delete per runbook).
5. The ~41G frozen-shadow sweep (new storage.md row; verify each family migrate script's cleanup leg before relying on it — cited, not verified).
6. postgres 413M + `17.empty-incident` + immich-diag residues (pre-existing row).
7. `docs/services/projects-subvol.md` Phase F sync (burn-in met 2026-11-14).
8. Full `nix flake check --no-build` or ride the next CI push for the selftests.nix change.
9. Owner: ack the "Projects subvol backup leg stale" Gatus alert (firing since ~Nov 9 by design).
10. Optional, NOT recommended now: emit a `shadow_split_mounted_entries` metric from §18 (the Gatus alerts already cover the underlying legs; a gate-output metric would be redundant signal).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Old `~/tmp` content (25G frozen on QLC)**: the live Samsung subvol holds only ~378KB — the pre-cutover tmp drained after migration. Is anything in the frozen 25G still wanted pulled forward, or is it dead weight? (Either way it survives forever in old `@` pool receives — this is about convenience, not data loss.)
2. **Catch-up window ownership**: when PSI drops below 20, do you want me to fire `btrbk-projects` myself, or do you own the timing? (The admission gate makes an agent attempt safe — a refusal is free.)
3. **The shadow-cleanup tar.zst archive**: the runbook archives the 132G shadow to the pool before deleting (~132G write IO, belt-and-suspenders on top of the Oct-28 receive + git remotes + forever `@` receives). Keep the archive step as designed, or skip it to save the IO window? (Skipping = script change; the insurance-vs-IO tradeoff is yours.)

---

## Addendum — owner answers 14:4x, same day (follow-up session)

1. **Q1 answered by inventory** (owner asked "what is in it?" → measured): the frozen 25G `~/tmp` is pure reproducible scratch — go-cache 13G, go-mod 4.7G, ~8 go-build* scratch dirs ~4G, go-lint 1.4G, tmpdir 812M, ~180 identical 4.2M `brandidlint.*` binaries (~0.75G), plus thousands of tiny `tmp.*`/`devshell-tools.*` droppings; all timestamps Oct 27–Nov 2 (pre-cutover), live Samsung subvol ~378KB. **Agent recommendation: dead weight, nothing to pull forward** — sweep with the ~41G bundle (storage.md row 14, still owner-gated; content survives in old `@` pool receives regardless).
2. **Q2 answered by owner directive — "PSI <20 unrealistic! <80 is fine"**: the `btrbk-admission` wrapper now passes `--psi-max 80` (commit 5013fd42c, pre-commit battery green incl. all-systems eval; shared maintenance-entry-gate default stays 20, 60-min guard-trip window untouched). Agent owns the catch-up firing: `sudo systemctl start btrbk-projects` when IO PSI <80 AND guard trip-free. Execution state at addendum time: memory storm active (guard re-tripping), deploy of the band change waits for the deploy gate's calm window; first green run + receive verify to follow. Follow-up (same session): the watch row's "needs a calm-window catch-up mechanism" ask is also answered structurally — btrbk-projects enrolled in the guard's ioChurnUnits + backupUnits (starvation slot: avg60 <50 → bounded 900s-protected start; pairs with the avg10<80 admission gate into an automatic catch-up, no agent in the loop), deploy-gated with the band change.
3. **Q3 (tar.zst archive keep-vs-skip) remains open** — shadow-cleanup stays owner-gated on it plus the Q1 sweep confirmation.


---

*Arte in Aeternum — report waits for instructions.*
