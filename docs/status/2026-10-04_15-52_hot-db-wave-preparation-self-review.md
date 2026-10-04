# Hot-DB Wave Preparation — Status & Self-Review (2026-10-04 15:52)

**Session scope:** DiscordSync/hot-db five-service migration — understanding → procedure → preparation → vehicle hardening. Scoped to THIS session's run and what it directly touched. All revs short-form; commands recover the full hashes.

**One-line verdict:** The five waves are eval-proven, vehicle-hardened, and gate-documented — but ZERO have run (correctly: they are owner sudo windows), the box is still mid IO storm (PSI avg10 44% at close), and my session's one big process miss was a wrong root-cause attribution on the flake gate (repaired the right thing for a partially-wrong reason).

---

## a) FULLY DONE

1. **Wave procedure distilled** — the complete 6-step-per-service runbook (Phase 0 → per-wave → Phase Z) from `docs/services/hot-db.md` + `scripts/migrate-hot-db.sh`, including rollback ladder, parallel-deploy hazard, shadow-dir policy, and per-wave functional probes.
2. **All six entry snippets eval-verified** (5 waves + postgres future wave) via throwaway `extendModules` (`/tmp/hotdb-wave-eval.nix`, never in-tree): `failed_assertions: []`, mounts render (`subvol=hot/<name>`, `nofail`, `/dev/disk/by-label/tlc`; postgres carries `nodatacow`), anti-shadow `RequiresMountsFor`/`ConditionPathIsMountPoint` on every unit **merged with pre-existing pool gating** (discordsync: attachments + dataDir; browser-history-backup: pool backup dir + dataDir; postgres: `/var/lib/postgresql/17` + dataDir), bootstrap `wantedBy` carries all six systemd-escaped mount unit names, 7 anchored Gatus checks render, `hot-db-metrics` in system-health's monitored set.
3. **Negative eval probes (eval-cache-trap doctrine)**: btrbk landmine guard FIRES (forgejo-shaped entry rejected with the right message), duplicate-path guard FIRES. Both proven, not assumed.
4. **Under-hot guard bug found + fixed** (`5ee20393`, `modules/nixos/services/hot-db.nix`): the validation checked the literal `/hot/` prefix and let `/mnt/hot/foo` through — now also checks `cfg.toplevelMount`. Probe-proven both directions (negative fires; six canonical entries stay green).
5. **Fixture vehicle hardened — 3 queue rows closed** (all surfaces, TODO_LIST + storage.md):
   - **Row: extend coverage** (`4c98d269`): marker's FILES/BYTES/BIG_PATH/BIG_SIZE asserted against the live tree; per-entry `status` rendering for missing AND populated/marker branches + full-registry form; `--dry-run finalize` path; dead `assert_contains` helper removed (SC2329).
   - **Row: self-verifying count**: in-run PASS_COUNT vs anchored-sites comparison; two real subtleties found and encoded (ANCHOR_RE self-match, the check's own late-emitting site); **negative-tested live** (phantom-site injection → red, restore → green). 32/32, no hand-maintained number.
   - **Row: wave-1 smoke fold** (`2e8058ae`): closed as already-done — landed 2026-10-01 in `95944afb`, only the queue closure was missed.
6. **Flake gate RED → GREEN**: `nix flake check --no-build` rc=0 "all checks passed" on the final tree (verified twice).
7. **Pre-flight Phase 0 (non-sudo)**: tree quiescent, `/mnt/hot` mounted, `hot_tier_mounted 1` / `hot_db_scrape_errors 0` live, Samsung ~768 GB free, all three dump-leg unit+timer pairs deployed and wired into `timers.target.wants` (system-821), pocket-id + browser-history dumps fresh (metrics-confirmed `backup_healthy 1`).
8. **Real pre-flight catch**: discordsync dump leg STALLED (newest dump 2026-10-01, `backup_healthy{discordsync} 0`, age 82 h; Persistent does not retry FAILED activations). Corrected on ALL THREE surfaces (TODO_LIST row premise-fixed, storage.md residual updated, runbook gate added) — the count-claim lesson applied.
9. **Hermes orphan diagnosis + repair**: `hermes-python-source` IFD path GC'd → gate brick; realized via `nix build .#checks.x86_64-linux.hermes`; orphan-class finding appended to the owning pipeline row (it recurs at EVERY rev, incl. the held-back one).

## b) PARTIALLY DONE

1. **Hermes lock rollback** (`f1153508`): executed per the documented twice-proven pattern (temp pin → re-lock → strip `original.rev`) and it restores the flake.nix-documented invariant — **but my causal claim was wrong** (see d1): the gate breakage was the FOD orphan at BOTH revs; the rollback was policy-restoration, not the gate fix. Whether the hold should be LIFTED is now an open owner question (g1).
2. **CI verification**: inspected today's runs (all red) and identified two classes (vm-tests/nix-check on the pre-rollback lock; secret-scan long-standing) — but did NOT read the vm-tests failure logs to confirm the hermes theory, and cannot trigger the next run myself (no push). "Next run should green" is a prediction, not a result.
3. **Runbook pre-flight block**: landed (`ba97766a`) with verified state + both gates — but the inter-wave soak policy (days between waves? back-to-back?) is genuinely unspecified (g2).
4. **PSI monitoring**: two point samples (54% → 44%) + 5 guard trips/h from the metrics scrape — direction unknown; no trend instrumented (not my place to add one mid-storm).

## c) NOT STARTED (deliberately — owner sudo windows)

1. **The five actual migrations** (gatus → dnsblockd → pocket-id → browser-history → discordsync): zero entries in `services.hot-db.entries`, zero prepare/cutover/finalize runs. Correct per doctrine — an entry deployed before its prepare shadow-splits a live service.
2. **discordsync-db-backup manual restart + dump proof** (sudo).
3. **Phase Z**: shadow-dir soaks, cleanups, wave close-outs.
4. Postgres future wave (ratified, snippet verified — blocked on nothing technical, owner scheduling).

## d) TOTALLY FUCKED UP!

1. **Wrong root-cause attribution on the flake gate (the session's real mistake).** I saw red gate + lock-at-8b66a510, matched the documented pattern ("bot re-broke the eval"), and rolled the lock back — THEN discovered the failure persisted at `bafb42b4` with a different path hash. The real cause was the GC'd FOD path (present at both revs). The rollback remains defensible (it re-enforces the flake.nix hold), but my mid-session framing "8b66a510 re-broke the gate" asserted causation my evidence didn't support — the exact AGENTS class ("assert WHICH question your evidence answers"). The discriminating experiment (build the FOD, re-gate at 8b66a510) still has not been run, so whether 8b66a510 is eval-clean-with-FOD-realized is UNKNOWN.
2. **The under-hot guard fix shipped without a persisted regression test** — protected only by this session's throwaway probes; `tests/test-hot-db-assertions.nix` does not carry the case. If someone re-simplifies the check, only CI's existing cases (which don't cover toplevelMount) stand guard. Harvested as §f1.
3. Minor: the self-count check took three iterations (two self-inflicted off-by-ones: pattern self-match + own-site emission). Working code, sloppy first draft.

## e) WHAT WE SHOULD IMPROVE!

1. **Discriminate before rollback** — the repo even documents the FOD-orphan-vs-rev question (pipeline row); I had both hypotheses in hand and chose the pattern-match. A 2-minute `nix build` at the current rev first would have separated them.
2. **Every fixed guard deserves its persisted test the same day** — probes rot the moment the session ends; the repo's own negative-test convention says exactly this.
3. **`Persistent=true` timers do not retry failures** — the discordsync stall is the second observed instance of this class in this repo (storm-era backup misses). The dump legs need a failure catch-up path (OnFailure-driven retry or a coordination-triggered rerun), not just miss-catch-up.
4. **Bot rollback-on-red still not implemented** — this session is a THIRD instance of the single-input eval-break class (discordsync 09-23, hermes 10-02, hermes-again 10-04). The queued row's procedure exists; nothing enforces it.
5. **The hermes hold's premise is stale in flake.nix** — "bafb42b4 evals clean under --no-build" is store-state-dependent, not rev-inherent (proven this session). The comment should say so or the hold should be lifted with FOD anchoring instead (g1).

## f) Up to 50 things next (session-derived; routing marked)

Direct follow-ups of THIS session (harvested at authoring time — §f1-2 new queue rows, §f3 evidence-update landed):

1. **[harvested→storage.md]** Persist the under-hot/toplevelMount guard case in `tests/test-hot-db-assertions.nix` (probe-only today).
2. **[harvested→storage.md]** discordsync-db-backup failure catch-up mechanism (Persistent misses ≠ failures; second observed instance).
3. **[evidence-update landed]** pipeline.md rollback-on-red row: thrice-observed now (was twice-proven).
4. Owner: run `sudo systemctl start discordsync-db-backup.service` + verify fresh dump (wave-5 gate; queue row exists).
5. Owner: wave 1 (gatus) in a PSI-quiet window — the whole runbook is armed.
6. Waves 2-5 per the runbook, one window each.
7. Owner decision: lift or keep the hermes lock hold (g1) — if lifted, flake.nix comment must be rewritten either way.
8. §10 GC-anchoring (or pre-commit build-ifd) for `hermes-python-source` — appended to the orphan pipeline row this session.
9. Verify the next CI run greens on vm-tests/nix-check after `f1153508` (watch; prediction unconfirmed).
10. `nix flake check` WITH builds locally once PSI drains (full CI-equivalent, incl. VM tests my session only eval'd).

Observed pre-existing (owned elsewhere, deliberately NOT harvested — duplicate risk):

11. secret-history-scan red 30/30 on documented fixtures (masked `sk-00000…` shape-descriptions + `leak-canary.tmp.md`) — owner/secrets-domain decision (g3).
12. Zone-6 storm + thermal deficit: freeze-#14 autopsy's owner actions (cooling inspection, stop recovery readers) still open in stability.md.
13. `backup_healthy 0` on forgejo (104 h) + monitor365 backup never-succeeded + crm-server/pbx-backup-pull 999 h — backup-coordination domain, not touched here.
14. `btrfs_health_critical 1` (root fs 95% allocated / unalloc 4%) — the waves themselves relieve this; monitor.
15. `forgejo_mirror_health_scrape_errors 1` + `forgejo_subvol_backup_fresh 0` — forgejo domain.
16. 9 dead `systems` follows overrides still warn on every nix invocation (queued pipeline row exists).
17. Catalog subdomain warning (21 names) — queued row exists.
18. `llama_rag_leaked_instances 2` — llama-rag domain, queued.
19. scrub staleness (`btrfs_scrub_stale 1` both mounts) — storage row exists (Persistent=false scrub timers + storm).
20. Eval warnings: `stdenv.isLinux` deprecations (×4) — queued eval-warning batch row.

Vehicle/polish candidates from this session (small, [ready]-shaped, not harvested to avoid queue noise):

21. `migrate-hot-db.sh status` could print the wave ORDER + next-action hint (it prints state only).
22. The wave runbook could carry the per-wave stance comment pre-written (I described them in conversation; not yet in the snippets).
23. `hot-db.md` could link `/tmp/hotdb-wave-eval.nix`-style probe as a snippet for future re-verification (it's ephemeral; the pattern lives in nix-flakes.md).
24. TODO: fold the `?rev=`-pin trap (silent no-op on update) into the bot runbook header — it rode this session's rollback (documented in nix-flakes.md already; cross-link only).
25. The fixture's `du -sb --apparent-size` assumption (rsync -a is mtime/size-preserving) could get a comment tie to the script's `counts()` (they must not diverge).

Rest of the 50-slot budget: deliberately unfilled — no honest session-derived items beyond 25; padding would be entombment fuel.

## g) Questions I cannot answer myself

1. **Hermes lock hold: lift or keep?** My session proved the gate-breaker was the GC'd FOD path (fires at `bafb42b4` too), which invalidates the hold's stated premise — but NOT whether `8b66a510`+ is otherwise healthy. Do you want (a) hold kept + FOD anchored, (b) hold lifted + forward-locked, or (c) hold lifted only after someone re-verifies upstream eval-with-build green?
2. **Inter-wave soak policy for the five windows:** separate days (soak each) or back-to-back in one quiet window? The runbook mandates one window per wave but is silent on minimum spacing; it changes total wall-clock from ~a week to ~an hour.
3. **Secret-history-scan disposition:** the 30/30 red is hitting your own documented shape-description examples (2026-09-15 report) and a canary file. Change the docs (real placeholders), allowlist the scanner for those blobs, or accept-red-until-rewrite? (Scanner-vs-docs is a policy call I won't make alone.)

---

*Harvest record: §f1-2 landed as new rows in docs/todo/storage.md + TODO_LIST.md; §f3 evidence-update landed in docs/todo/pipeline.md; §f4-10 owner/watch items ride existing rows or this report; §f11-20 deliberately NOT harvested (owned by existing rows/domains); §f21-25 deliberately NOT harvested (polish, below queue bar).*
