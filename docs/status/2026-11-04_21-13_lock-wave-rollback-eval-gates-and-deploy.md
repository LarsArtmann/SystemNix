# Status: unproven lock-wave rollback, eval gates fixed, deploy landed (gen 979)

**2026-11-04 21:13 CET — single session; started from a pasted `nix run .#deploy` failure (`flake.lock infra-follows audit failed`).**

**Scope line — what this report VERIFIED (fresh command output this session):**

- The eval chain: `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` (exit 0 after the fix), `nix eval .#checks.x86_64-linux.doc-counts` (green), the float ceremony proof log `~/.cache/lockfloat/float-proof-20261104-200145.log` (`rc=0`, zero `hash mismatch|builder failed`).
- Broken-wave census from the two RED proof logs: `float-proof-20261104-192713.log` (23 FOD hash mismatches, `grep -c`) and `float-proof-20261104-194945.log` (main-build failures at even the rolled-back rev, the cache-hit-FOD divergence class).
- The lock state: `flake.lock` byte-identical to `git show e9b353742^:flake.lock` (python compare), node count −1 (deep treefmt node GC'd), `go-nix-helpers_3.inputs.treefmt-nix = ["treefmt-nix"]`.
- The deploy: pre-deploy battery `124 passed, 9 warnings, 0 failed`; switch + activation (nh exit 4, known class); anchor `readlink /run/current-system` == `system-979-link` == `/nix/store/p10k64kfrsz6xxvmflgrd3rik93h6sn7-nixos-system-evo-x2-26.11.20261015.fe13242`, plus nh's own "✓ anchor repaired".
- Post-deploy battery: 29 PASS, 4 FAIL (3× CV, 1× FastFlowLM), 2 STORM-SUSPECT (io PSI some avg60=57.37% — STORM MODE downgrade active).
- Failed units after convergence: `home-lars-tmp.mount`, `forgejo-github-sync.service` (exit 1 at 21:00:01 after successfully attaching the pim-sync push mirror), `media-atlas.service` (start-limit-hit, restart counter 6, 252M peak), `service-health-check.service` (reports the others).
- **NOT verified:** darwin eval (`nix flake check --no-build --all-systems` never run this session); the parallel-session changes that rode the deploy (boot.nix, buildcache-agent units, templ 0.3.1114) only as far as the shared proof covers them; the media-atlas / forgejo-github-sync / home-lars-tmp root causes (only the unit-state symptoms above); CV's 3 FAILs are the documented pinned-rev SIGSEGV loop, not re-diagnosed; the 28 discarded healthy floats were never individually re-proven (only the reverted graph was).

---

## a) FULLY DONE

1. **Eval gate #1 fixed — infra-follows deep-treefmt violation.** The 19:01 lock refresh re-resolved `docs-gates`, which now carries its own nested `erraudit` copy (`erraudit_3`, same rev as our root pin `3d1f7ed3`), whose `go-nix-helpers` pin locks a private `treefmt-nix` (`27b3b12a` vs root `0d6d739a`). Added the depth-3 override `docs-gates.inputs.erraudit.inputs.go-nix-helpers.inputs.treefmt-nix.follows = "treefmt-nix"` (flake.nix, journal/papdashboard precedent), re-ran `nix flake lock`: only the expected edges moved, the deep node was garbage-collected, `-25/+4` lines.
2. **The 19:01 lock wave was proved DOA and rolled back.** It committed 55 floated revs with NO toplevel proof (its own deploy died at the eval gate first; the registry header's 2026-11-03 round-9 row even says "proof pending"). The keep-going proof enumerated 23 stale go-modules vendorHashes (bank-sync, cqrs-lint/go-cqrs-lite, cvagent, discordsync, emeet-pixyd, erraudit, go-auto-upgrade, golangci-lint-auto-configure, go-structure-linter, go-health-dashboard, md-go-validator, crm, library-policy, project-meta, journal, mr-sync, overview, papdashboard, project-dependency-graph, project-discovery-daemon, samber-linter, pma, vision-review-agent), 3 main-build failures (art-dupl, go-taskqueue, branching-flow), quotaboard's vendor/modules.txt-vs-go.mod desync, dnsblockd's unwired `go-cqrs-lite/schema/v4` prepared-source dep, and buildflow's FOD download-scope failure. A first surgical 27-input rollback attempt STILL failed on the old cqrs-lint rev (fresh main build wanted `a-h/templ@v0.3.1100` while its cache-hit FOD holds the v0.3.1070-era set) — the cache-hit-vs-fresh-build divergence. Decision: full revert of `flake.lock` byte-exact to `e9b353742^` (the last proven graph), keeping the forward-fixing flake.nix override (dormant until docs-gates re-floats).
3. **Float ceremony ran green.** `scripts/float-register.sh` found one residual registry skew (crush-daily `07cf5ca4` vs lock `95bf8a0` — a round-9 artifact), re-registered it, proved the full toplevel (`rc=0`, zero failures, `float-proof-20261104-200145.log`), and the auto-commit daemon landed the `flake.lock` + `flake/expected-locks.nix` pair together (content verified by the script's daemon-race branch).
4. **Eval gate #2 fixed — doc-counts.** `FEATURES packages asserts 48, eval truth is 49`: a parallel-session commit (6369e3ba5, 18:40) added `templ = flakePkg inputs.templ` to the mkLarsPackages surface while the doc was stamped at 48 earlier the same day. Re-derived (`nix eval .#packages.x86_64-linux --apply 'x: builtins.length (builtins.attrNames x)'` → 49), re-stamped FEATURES.md (count row + header) with the newcomer named; `checks.x86_64-linux.doc-counts` evals green.
5. **Deploy executed and verified.** Pre-deploy battery: 124 passed / 9 warnings / 0 failed (§11 all go-modules FODs cached, §19 sops gate green). Switch + activation ran; nh exit 4 (activation completed with failed units — known class); `home-lars-tmp.mount` failed, start-limit reset + retry, then nh self-repaired the profile anchor: `/run/current-system` == `system-979-link` == `p10k64kf…fe13242` (verified again after the fact).
6. **Post-deploy battery executed.** 29 PASS lines; FAILs are exactly the two known classes: 3× CV (the rev-pinned `16a656f4` SIGSEGV loop documented in flake.nix/pin-audit — pre-existing, NOT a deploy regression) and 1× FastFlowLM socket (the documented IO-storm class); 2 CV render checks downgraded to STORM-SUSPECT under 57% PSI.
7. **Upstream triage queued.** Two rows in `docs/todo/upstream.md`: the wave's full got-hash bake list + builder breaks (one `[blocked:push]` row naming all ~23 repos and the ritual), and a `[watch]` row for the cache-hit-FOD-vs-fresh-build divergence (carrier UNIDENTIFIED — cqrs-htmx v4.15.0's .mod probe falsified the first hypothesis; do not assume re-tagging). `scripts/check-todo-system.sh`: "OK: TODO queue/library structure clean".
8. **Co-deploy disclosed and anchor discipline honored.** Parallel sessions' changes rode the deployed toplevel: `platforms/nixos/system/boot.nix` (freeze-#46 arc), the buildcache-agent cache-gc units, and `templ 0.3.1020 → 0.3.1114` (the toplevel diff). They are inside the same green proof, but this session did not author or independently verify them.

## b) PARTIALLY DONE

1. **Wave re-landing.** The full revert discarded ~28 floats that were provably healthy in the wave (e.g. browser-history `98cfec0`, monitor365, media-atlas `3cbd374`, docs-gates, HM `b787c48e`, sops-nix, dnsblockd). They re-land for free via the automated ceremony once upstream heals — not re-floated tonight.
2. **Failed-unit triage.** `media-atlas.service` and `forgejo-github-sync.service` failed AFTER tonight's deploy and are NOT triaged (symptoms only: start-limit-hit ×6 for media-atlas; exit 1 for forgejo-github-sync at 21:00:01 immediately after a successful pim-sync mirror attach). `home-lars-tmp.mount` is a recurring unit failure seen in the pre-deploy advisory too. `service-health-check` reports the rest.
3. **Carrier identification for the re-serve divergence.** Observed and documented, not identified: an old locked rev's FOD cache-hits with the v0.3.1070 templ set while a fresh main build resolves v0.3.1100; cqrs-htmx v4.15.0 (first suspect) carries NO templ requirement.
4. **Darwin coverage.** `nix flake check --no-build` ran (default systems) inside the battery; `--all-systems` (the darwin eval doctrine) was NOT run by this session.

## c) NOT STARTED

1. Triage of `media-atlas.service` (atlas is the 2026-10-28 federation hub; start-limit-hit suggests a crash loop — DB/port/perms unknown).
2. Triage of `forgejo-github-sync.service` exit 1 (the push-mirror attach itself succeeded; something later in the sync failed).
3. Resolution or masking of `home-lars-tmp.mount` (long-running failed unit).
4. The upstream got-hash bake wave (23 repos) — push-gated.
5. Re-running the two CV STORM-SUSPECT render checks in a calm window, and restarting the FastFlowLM socket when IO is quiet.
6. Re-floating the ~28 healthy inputs (a new, proven float wave).
7. `nix run .#pre-reboot-check` for the next planned reboot (the deploy left boot entries at the same version; a reboot would currently land on this gen — worth the static audit anyway).

## d) TOTALLY FUCKED UP

1. **The 19:01 wave (not authored by this session, but the trigger of everything here).** A 55-input blanket float was committed with zero toplevel proof while ~30 of its revs were red today; it turned every subsequent eval/deploy into a gate failure parade and this session into an unplanned triage shift. The registry's own history shows the previous round also shipped with "proof pending".
2. **Deploy exit 4 is still normal.** Activation completed with 4 failed units; the `service-health-check`/`OnFailure` chain fires every deploy. The two genuinely NEW-looking failures (media-atlas, forgejo-github-sync) were not caught by a pre-switch gate — post-deploy smoke only covers the HTTP surface.
3. **This session's first plan was under-built.** The surgical 27-input rollback looked right but shipped an under-proven, wave-derived graph and still died on the cache-hit divergence; the correct call (full revert to the last proven graph) came only after that experiment. The experiment cost ~25 minutes and one extra proof cycle.
4. **Report written last.** The status report existed only at the end; a running draft during the 25-minute proof would have cost nothing.
5. **Volatile intermediates.** The surgical-rollback lock backup still sits in `/tmp/flake.lock.surgical-27-rollback.json` (this box wipes /tmp; the durable evidence is the two proof logs under `~/.cache/lockfloat/` — the backup itself is redundant, but the habit is wrong).

## e) WHAT WE SHOULD IMPROVE

1. **Never commit an unproven lock refresh.** `scripts/float-register.sh` already automates regen → proof → commit; the wave skipped it. A cheap mechanical guard is possible: a pre-commit leg that blocks a staged `flake.lock` whose registry does not match (the float audit exists at eval; move a copy of it to commit time, or at least warn on `>10` drifted inputs).
2. **Prefer small, proven float waves.** One-input-at-a-time floats with immediate proof make a RED wave cost one revert, not a night. The 30% upstream-stale-hash rate in this fleet makes blanket waves near-certain DOA.
3. **Run the eval chain before the deploy, not inside it.** `nix eval .#nixosConfigurations.evo-x2...drvPath` + `nix flake check --no-build` cost seconds-to-minutes and would have surfaced both gates before the 25-minute battery.
4. **Name every failed unit in the deploy close-out.** "Activation completed with failed units" is not a result; `media-atlas` and `forgejo-github-sync` deserve one-line causes at deploy time, not a next-day triage.
5. **Split the wave todo row per repo eventually** (one mega row is a dispatch unit that cannot land green in one pass).
6. **Keep the "last proven graph" concept explicit.** The revert restored it exactly; documenting the invariant ("flake.lock always equals the last proven toplevel, unless a float is in flight") in `docs/agents/nix-flakes.md` would make the next incident a two-line decision.

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

1. `journalctl -u media-atlas.service -n 100` — find why atlas crash-loops (start-limit-hit) and fix or disable until understood.
2. `journalctl -u forgejo-github-sync.service -n 100` — find the exit-1 step (mirror attach already passed).
3. Decide `home-lars-tmp.mount`: fix its ExecStart/conditions or remove it from the config.
4. Restart `fastflowlm` socket in an IO-quiet window and re-probe `:52625`.
5. Re-run the two CV STORM-SUSPECT render checks when PSI < 20%.
6. Bake the got hashes upstream for the 23-repo list (start with bank-sync, cvagent, go-cqrs-lite — the three that also failed at their proven revs).
7. After (6): re-float the ~28 healthy inputs through float-register (one proven wave).
8. Identify the templ v0.3.1100 carrier: probe `.mod` files of each LarsArtmann module in cqrs-lint's graph at the locked versions.
9. Add a pre-commit/eval guard: `flake.lock` drift without registry update blocks or loudly warns.
10. Add a "wave size" advisory in float-register (warn when drifted inputs > 10).
11. Run `nix flake check --no-build --all-systems` (darwin eval) once.
12. Move `/tmp/flake.lock.surgical-27-rollback.json` to `~/.cache/lockfloat/` (or drop it; logs are the durable record).
13. Document the "lock == last proven graph" invariant + tonight's gate order in `docs/agents/nix-flakes.md`.
14. Correct discordsync's stale INTERIM comment (it names `b3077aa2`; the proven rev was `c624aca`).
15. Verify media-atlas end-to-end once it runs (vHost `map.home.lan`, tile, PG ro role).
16. Recheck `browser-history-agent`, `catalog-inventory-sync`, `ci-watchdog` (pre-deploy advisory failures, not re-verified tonight).
17. Queue per-repo rows for the got-hash wave (replace the mega row when one repo lands).
18. Check `nix-build-cleanup`/buildcache-gc effects after tonight's build storm (`du` on `/nix/store`).
19. `nix run .#pre-reboot-check` before any reboot; confirm boot-mirror sync fired for gen 979.
20. Review the 9 pre-deploy battery warnings (only 4 were triaged into failed units).
21. Consider pinning the pma-class hash treadmills with documented LIFT rows (4 re-stales in 9 days).
22. Re-verify the FEATURES header/rows for other count-bearing claims (only packages was gated).
23. Re-run `scripts/post-deploy-check.sh` in a calm window as the authoritative post picture.
24. Confirm gatus still reports green for the restarted services (media-atlas/gatus/pocket-id restarts).
25. Spot-check the three parallel-session changes shipped tonight (boot.nix, buildcache-agent gc units, templ 0.3.1114 on PATH).
26. Harvest tonight's `[watch]` row's trigger into a real task if the divergence recurs in the next float.
27. Update `docs/todo/upstream.md`'s mega row with tonight's proof-log pointers if re-dispatched.
28. Re-derive the registry's "round-9 proof pending" note once the re-float lands (the note is now two waves stale).
29. Add the gate-order line to `docs/CONTRIBUTING.md`'s re-dispatch protocol (eval gates fire before the battery).
30. Decide whether the deploy battery should fail on `media-atlas`-class failures (a service the flake ships, not an external one).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Re-float now or wait?** The ~28 healthy floats were discarded tonight. Re-floating is one automated ceremony but re-touches the exact surface that burned the evening; waiting costs freshness. Which do you want: re-float immediately (I run float-register on a fresh `nix flake update` subset), or hold until the upstream got-hash wave lands?
2. **Is media-atlas supposed to be live?** It crash-loops (start-limit-hit) and hit OnFailure; its 2026-10-28 rollout notes suggest owner-side state (pool paths, PG role, archive perms) I cannot judge. Fix now, disable until understood, or leave it failing?
3. **Priority order for the remaining work:** (a) upstream got-hash wave in 23 repos (needs push permission), (b) re-float + proof, (c) failed-unit triage (media-atlas, forgejo-github-sync, tmp.mount), (d) docs/prevention guard. What do you want first?
