# AudibleSync Inventory Fix + Fleet Unblock — Session Status (2026-11-15 13:35 CET)

**Mission:** owner asked "why does audiblesync.home.lan still show ZERO for everything" with a
keep-going directive. Root cause found, fixed upstream, shipped to the SystemNix lock, docs
landed. **The deploy is NOT done** — the toplevel build is blocked by an unrelated cross-repo
cargo-dep breakage owned by the parallel storage-collector 0.2 migration session, plus the IO
storm. Session now WAITING for instructions.

---

## a) FULLY DONE

1. **Zero-books root cause, three layers, all live-proven:**
   - The WebUI inventory scan (`internal/app/files.go`) accepted ONLY exactly `ASIN.m4b`
     (`^([0-9A-Z]{10})\.m4b$`) while the weekly archive's decrypt output (`asin_ascii`
     download mode) is `ASIN_Title-<quality>.m4b` — probe against the live pool:
     **0/72 live files matched** the old pattern.
   - The WebUI unit NEVER received `AUDIBLESYNC_LIBRARY_DIR` (only ADDR/DB/SYNC_CMD in the
     rendered unit), so the local-files inventory page was disabled entirely on every deploy.
   - The dashboard counters (`books:0`, "Your library is empty") count the tracker's
     event-sourced READ MODEL (`/var/lib/audiblesync/audiblesync.db`), which is empty BY
     DESIGN: books enter only via the `Add a book` form; the weekly archive pipeline writes
     files to the pool and never touches the tracker DB. The two services share identity,
     not state.
2. **Upstream fix shipped — `github:LarsArtmann/audiblesync` `b04bf5b` (v0.1.0 → v0.1.1, pushed):**
   - `asinFromName`: three-shape scan — plain `ASIN.m4b`, ASIN-prefix `ASIN_Title….m4b`,
     trailing-paren `Title - Author (ASIN).m4b` (audible-cli title mode). Unknown names stay
     ignored (not errors).
   - New `services.audiblesync.libraryDir` option (`nullOr str`, default
     `"${poolDir}/books"` — derived from the archive's poolDir, so the SystemNix wrapper
     needed NO change), rendered as `AUDIBLESYNC_LIBRARY_DIR` on the unit; `null` disables
     the page.
   - `restartTriggers = [ cfg.package ]` on the WebUI unit (a floated lock previously
     shipped a new binary that a unit-text-identical switch never restarted).
   - Version bumped, CHANGELOG `### Fixed` entries written, tests extended with the real
     live filename shapes + negatives (`lowercase0.m4b`, 11-char run, short ASIN).
3. **Verification battery (audiblesync repo):** full `go test ./...` green,
   `nix flake check --no-build` green (incl. `checks.nixos-module-evals`), buildflow fast
   gate **exit 0** (49 success / 0 failed; findings = pre-existing statix W20 ×2 + vulnix
   CVE noise, none in touched hunks). Pattern proof re-run with the EXACT Go regexes against
   the live dir: **72/72 matched**.
4. **Daemon-race repair (audiblesync repo):** my fix commit was swept mid-flight into a
   footless `chore: auto-commit` (039567f, 4 files of my code under a heuristic message).
   Repaired while unpushed with the sanctioned `git reset --soft origin/master` squash → one
   properly-messaged commit `b04bf5b` (5 files, 87+/19−), foreign docs churn returned to
   staged-uncommitted. Tree equality verified.
5. **SystemNix lock + pre-verification:** audiblesync input at `b04bf5b` (landed via the
   parallel session's float sweep + a daemon commit — my own redundant lock commit was
   abandoned, see d-1); probe-build of the rev green BEFORE locking
   (`audiblesync-0.1.1` built from `github:…/b04bf5b`); rendered unit pre-verified via
   `systemd.units."audiblesync.service".text`: `AUDIBLESYNC_LIBRARY_DIR=/mnt/pool/services/audible/books`,
   `ReadWritePaths=/mnt/pool/services/audible`, `RequiresMountsFor=/mnt/pool`,
   `ExecStart=…-audiblesync-0.1.1` — all four legs green, no new eval warnings.
6. **BONUS root-cause (unrelated but deploy-blocking): storage-collector prepared-source FOD.**
   The pre-commit lock gate's toplevel build failed `sed: … Permission denied` in
   `crates/ui/`. Dug to ground truth: the LOCKED storage-collector rev's `buildCommand`
   (`nix derivation show` on the .drv) copies crane-cleaned store sources with `cp -r`
   (dirs land `dr-xr-xr-x`) and then `sed -i` into `crates/ui/Cargo.toml` with **no
   `chmod -R u+w`** — deterministic failure for any fresh build. Upstream already fixed it
   (`chmod -R u+w` landed `ad7df4d`, 12:47 today); SystemNix's storage-collector float
   (→ `4a9360e`, revCount 251) is now in the lock (rode daemon commit 75263afcb), and **both
   new preparedSource FODs build green** (cheap drv-only probe, exit 0).
7. **Docs landed (SystemNix, committed):** runbook `docs/services/audiblesync.md` line-28
   truth rewrite (inventory ON, three shapes, counters-vs-files distinction), new
   `[decision]` row in `docs/todo/services.md` (auto-populate: read-only vs
   reconcile-importer vs pipeline-in-Go), CHANGELOG entry. Commits `95f24b149`, `5f1494666`.
8. **Current-HEAD eval re-verified green** (toplevel drvPath resolves: `cxcjl5janp…`) — the
   parallel session's 13:06 "evaluation failed" was a mid-commit transient, not a tree break.

## b) PARTIALLY DONE

1. **The deploy (gen-1013).** Everything upstream of the switch is done; the switch is
   blocked on TWO independent walls:
   - **monitor365 cargo-dep inconsistency (upstream, fix in flight):** SystemNix's lock
     carries monitor365 `93bd8474` (requires `storage-collector = "^0.2"` in Cargo.toml,
     but its flake still pins storage-collector `0569c46` whose crate version is `0.1.0`)
     → `monitor365-deps` fails `candidate versions found which didn't match: 0.1.0`.
     The fix (flake pin → `4a9360e` = 0.2.0) EXISTS in the parallel session's monitor365
     LOCAL tree — **9 commits ahead of origin, unpushed**. I am polling origin for their
     push (watcher, ~90 s cadence); when it lands: `nix flake lock --update-input
     monitor365`, toplevel build, deploy.
   - **IO storm:** io PSI `some` avg10 has run 38–57% all session (deploy gate threshold
     20). The parallel session's 13:06 deploy was ALSO blocked — on PSI (48.57% + disk
     busy 102%) and the transient eval failure; their deploy exited code=1 at 13:10.
2. **Owner-question capture (handoff Q(a)):** effectively ANSWERED by your "why ZERO"
   message (you expect visible books — the fix delivers visible files). The recording of
   your exact choices on the remaining two handoff questions (tile taste, pipeline-in-Go)
   is folded into the new `[decision]` row but your verdicts are not yet in.
3. **The `books:0` counters themselves:** files are now visible but counters stay zero by
   design until books are imported — that's the queued `[decision]`, deliberately not
   implemented without your ruling (files.go's documented domain stance: a file on disk is
   not a completed sync).

## c) NOT STARTED

1. **Live verification of the fixed UI** (deploy-gated): unit env live after switch,
   `/healthz` still `books:0` (honest), `/library` page renders the 72 inventory rows
   (grep a known title-shape filename through the openssl vHost probe), journal clean.
2. **monitor365 float + toplevel build + deploy** — the moment their push lands.
3. **`audiblesync-backup` 02:35 tick verification** (yesterday's `[watch]` row) — was
   explicitly out of scope this session; still unverified.
4. **Tile-acceptance / re-add-archive-tile** (handoff Q2) — awaiting your taste ruling.
5. **Pipeline-in-Go** (handoff Q3 / self-review question 3) — awaiting appetite ruling.
6. **SystemNix push** — policy: never push unless you ask. Commits
   `75263afcb` (my lock float, daemon-swept), `95f24b149`, `5f1494666` (+ later doc
   commits) sit unpushed on master.

## d) TOTALLY FUCKED UP (honest)

1. **Stale-lock commit attempt.** I committed a flake.lock that had gone 15-nodes stale
   against the parallel session's just-landed float sweep — the hook's 4-minute
   flake-check + toplevel-build gate caught it after the fact. My own lock commit was
   redundant anyway (their sweep already carried `b04bf5b`). Cost: one wasted heavy gate
   run + a confusing 15-minute archaeology. The correct move was re-pin → re-check lock
   freshness IMMEDIATELY before any lock commit in a shared session.
2. **Half my fix rode a footless daemon commit.** First commit attempt was hook-rejected
   (golangci QF1001 — De Morgan form in my test), the failed attempt left files staged,
   and the auto-commit daemon swept them into `chore: auto-commit 4 changed file(s)`.
   Repaired cleanly (`b04bf5b`), but the window existed because I committed without
   running the lint the hook would run.
3. **I wrote the inventory regex BEFORE looking at the live filenames.** First version of
   the pattern forgot the ASIN-prefix suffix shape entirely (would have shipped a fix that
   still matched 0 real files). Caught on self-review of my own diff — the live evidence
   (72/72 → 71 prefix + 1 paren) should have been the INPUT to the pattern, not the check
   after it.
4. **Wasted heavy-eval cycles.** The pre-commit lock gate realized the full toplevel twice
   against trees I already knew were broken-ish; capture-once-then-grep discipline would
   have me building the cheap FOD-only probe FIRST (`nix build <preparedSource.drv^*`),
   which is what I ended up doing anyway after burning the long runs.
5. **Subject-length lint trip (87 > 72 chars)** on the docs commit — first-try avoidable
   round trip.

## e) WHAT WE SHOULD IMPROVE

1. **Encode live evidence before writing the fix** — for any pattern/scan/name change,
   dump the real-world corpus first and derive the matcher from it (this session's regex).
2. **Lock-commit freshness protocol:** immediately before ANY `flake.lock` commit,
   re-`git fetch`/status + diff the lock against HEAD — parallel float sweeps land here
   every few minutes today.
3. **FOD failure triage: read the `.drv` buildCommand FIRST** (`nix derivation show` /
   drv text) — the builder script is ground truth; I spent ~6 calls on repo archaeology
   before the direct read answered it in one.
4. **Pre-commit-parity lint locally:** run the hook's exact lint stage (staged-mode
   golangci) before `git commit` — buildflow fast mode did NOT catch QF1001 that the
   staged run did; the two batteries disagree.
5. **Cross-repo cargo-dep consistency gate (fleet gap this session exposed):**
   monitor365 requires `^0.2` while vendoring a 0.1.0 crate — latent for days behind
   FOD caches; a cheap pre-deploy/eval check (monitor365's flake storage-collector pin's
   crate version vs its Cargo.toml requirement) would have caught it the day the
   requirement bumped. Same class as the §11 vendorHash preview.
6. **Daemon-commit attribution:** two of my changes today shipped under heuristic
   messages (75263afcb lock float mixed with the parallel session's configuration.nix
   edit — unrepaired because repairing would rewrite THEIR landed commits). The
   repair-while-unpushed window keeps closing faster; consider a commit-storm mode where
   lock/docs changes get committed by the AUTHOR within one tool call, always.
7. **Never hand-derive versions across the 3-way pin chain** (Cargo.toml requirement ↔
   Cargo.lock ↔ flake.nix input pin): monitor365@tip shipped TWO of three updated. The
   chain should be bumped by one commit/tool, or gated.

## f) NEXT QUEUE (candidates — not auto-queued, your triage)

1. Deploy gen-1013 the moment monitor365's fix lands on origin: float `monitor365`,
   toplevel `--keep-going` gate, flock-holder check, PSI-window attempt, anchor verify.
2. Live-verify the audiblesync wave post-deploy (env, healthz, /library 72 rows, journal).
3. Owner ruling on auto-populate: (a) read-only inventory / (b) reconcile importer via the
   real sync pipeline / (c) pipeline-in-Go wave — then implement.
4. If (b): upstream audiblesync reconcile command (`library.json` ASINs → AddBook → run
   `{asin}` sync cmd idempotently) + SystemNix re-lock + one-shot run + counters proof.
5. If (c): the bigger wave — in-app scheduler + Go pipeline replacing oneshot+timer+shell.
6. Cross-repo cargo-dep consistency gate (e-5) as a pre-deploy check §-leg + selftest.
7. Monitor365-side guard: fail the build when `Cargo.toml` requirement and the flake-pinned
   storage-collector rev's crate version disagree (upstream monitor365 ticket/fix).
8. Storage-collector side: make the preparedSource builder chmod-proof by construction
   (cp without -p? explicit `chmod -R u+w` placement next to every cp) — verify the fix at
   `4a9360e` covers all three cp sites (it does — single `chmod -R u+w $out` after all
   cps; add a builder selftest asserting writability pre-sed).
9. Tick or retire the `audiblesync-backup` 02:35 `[watch]` row (verify last night's 02:35
   run + `/mnt/pool/backups/audiblesync/` freshness).
10. Capture your tile ruling: if the archive tile should come back, re-add a
    homepage-only `audible-sync` integration entry in the SystemNix wrapper.
11. Status-report §f harvest hygiene: this report's follow-ups are recorded in the
    `[decision]` row + this queue — tick-and-commit in one call when items land.
12. PSI calm-window deploy helper: a poll-until-admitted wrapper (`--psi-max 20`,
    bounded wait, dry-run first) so storm-day deploys stop burning manual gate round-trips.
13. Re-run `nix run .#pre-reboot-check` after the next successful deploy (anchor
    discipline).
14. Consider upstreaming the three-shape filename documentation into
    `docs/services/audible-sync.md` naming section (partially there — runbook mentions
    `ASIN-prefixed`; the paren shape is new).
15. audiblesync: `ScanLibraryDir` currently reads the pool dir on EVERY `/library` request
    — consider a small TTL cache or accepting the cost explicitly (72 files today;
    libraries 10× that will feel it on HDD).
16. audiblesync: inventory rows for orphan files show raw filenames as Name — consider
    deriving a display Title from the `ASIN_Title…` filename shape (split at first `_`,
    de-underscore) — cosmetic, improves the zero-state UX.
17. monitor365 push watcher: if the parallel session stalls >1 h, escalate to you for a
    takeover ruling (I will NOT push their unpushed work myself without your word).
18. After their push: verify their monitor365 stack actually builds BEFORE floating
    (their 9 local commits may include in-flux UI work — float the smallest rev that
    closes the ^0.2 pin gap, or confirm tip is build-complete).
19. SystemNix CHANGELOG: add the storage-collector FOD chmod root-cause entry once the
    deploy lands (it's referenced forward in my entry; the landing narrative belongs
    there).
20. `docs/todo/pipeline.md` convergence-deploy row (parallel session's) will be satisfied
    by the SAME gen-1013 deploy — coordinate rather than double-deploy.
21. FOD orphan cleanup: the failed FOD left a partial store path
    (`y7sbdq9…-storage-collector-prepared-source`, 12:58) — confirm nix GC reclaims it;
    if it lingers, note for `nix store gc`/`--debug` follow-up.
22. Check whether the OLD broken FOD drv (`xzkx8sgy…`) still gets referenced by any
    cached eval — should vanish once the lock is everywhere; sweep stale drvs after the
    deploy.
23. audiblesync repo: the parallel session is mid-edit in `internal/web/` RIGHT NOW
    (handlers/server/progress_test.go) — before ANY future audiblesync work, re-pin and
    re-read; do not eval claims of "their" files.
24. Consider a `restartTriggers` audit leg: services consuming floated package inputs
    without restartTriggers restart only on unit-text changes — audiblesync got the fix
    today; sweep the other upstream-consumed longruns (bank-sync pattern precedent).
25. Re-check `docs/services/audible-sync.md` naming claims against the paren-shape files
    (the `Propaganda - Bernard Woolner (B0741DTNNT).m4b` file proves audible-cli ALSO
    wrote title-mode for at least one item — why? one-off manual run vs mode fallback —
    worth one journal grep next Sunday).
26. Sunday 2026-11-22 05:06 archive run: expect +71 skip-if-exists no-ops; the run's
    `bookCount` line becomes the standing books-on-disk truth source for the reconcile
    decision.
27. If owner picks reconcile-importer: dry-run shape first (`--dry-run` listing 72
    ASIN+title pairs from library.json) before any dispatch.
28. Gatus: the "AudibleSync health" check body-pats `status":"ok"` — fine; consider adding
    a books-count presence pat AFTER populate (counter leg), only if (b)/(c) lands.
29. PapDashboard: the single AudibleSync tile's description merged the archive story —
    eyeball the render after deploy (the standing `[watch]` row) and tick it.
30. Long-tail: `internal/app/files.go` `asinFromName` deserves a fuzz/table test for
    pathological names (`ASIN.ASIN.m4b`, unicode, `()` pairs) — cheap table addition.
31. The 13:06 blocked-deploy log's second failure ("nix flake check failed") was
    transient — but no ledger row records WHY; add a one-line note to the deploy log
    triage doc if one exists, else skip (minor).
32. Retire my now-dead `storage-collector` era-rev assumptions in this report once their
    migration lands — keep the report dated-truthful, correct forward in the NEXT report.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Auto-populate the tracker read model?** (a) keep the read-only inventory (files
   visible, counters 0 until you add books), (b) a reconcile importer that seeds each
   `library.json` ASIN and runs the REAL sync command per book (idempotent no-op on disk →
   honest `synced` counters, no lying fields), or (c) the full pipeline-in-Go wave. My
   recommendation: **(b)** — it reuses the proven pipeline and answers "ZERO" completely
   without the (c) scope.
2. **Monitor365 unblock ownership:** their fix is unpushed (9 commits ahead) and their
   audiblesync-side UI work suggests they're mid-stream. Do I (a) keep waiting for their
   push (current posture, watcher live), or (b) author my OWN minimal upstream fix in
   monitor365 (flake pin bump commit) — accepting we'd race their tree? (I will not push
   THEIR unpushed commits without your word.)
3. **Deploy pressure posture:** io PSI has been 38–57% all day (gate 20) and your crash
   #3-precursor class fired at 13:06 (disk busy 102%). Do I wait for a genuine calm
   window (no ETA), or do you grant a `DEPLOY_FORCE_PRESSURE=2` exemption for gen-1013
   like the crash-loop wave got today (the twice-fatal class, used 5× today — it
   survived all five)?

---

**Waiting for instructions.** Live artifacts: watcher job `0B5` (monitor365 origin poll,
~90 s cadence, auto-stops when their push lands or after ~30 min); current HEAD eval green
(`cxcjl5janp`); SystemNix commits unpushed: `75263afcb` (lock float, daemon), `95f24b149`,
`5f1494666`, + this report's commit; audiblesync `b04bf5b` pushed (0.1.1).

## Resolution (2026-11-15 ~14:40)

Owner answered the report with the standing keep-going directive ("execute and verify one
step at a time… keep going until everything works") — that resolves §g by action:

1. **Q1 (auto-populate): proceeding with (b) reconcile importer** — decision row 1181
   re-tagged `[decision]` → `[ready]`. Implementation starts on the audiblesync tree
   once the parallel session's 6 unpushed commits push (their main.go/server.go are
   inside the unpushed delta — clean integration waits for their base).
2. **Q2 (monitor365 unblock): RESOLVED BY EVENTS** — they pushed (`9e332361`, storage
   -collector 0.2 re-vendored) and floated the SystemNix lock themselves (`d1eed8cd9`,
   13:39). My toplevel build with the floated lock went green first try (exit 0) — the
   breakage is dead, no racing needed.
3. **Q3 (deploy pressure): RESOLVED BY EVENTS** — their 13:52:04 deploy carried gen
   -1013 through the gate with `DEPLOY_FORCE_PRESSURE=1` (moderate band: PSI 41.19% /
   disk 101.7% at gate time — within the =1 envelope, not the ≥80/≥80 twice-fatal band).
   No exemption was needed from THIS session.

**Live battery (14:07 restart, all green):**

| Check | Result |
| ----- | ------ |
| Unit env | `AUDIBLESYNC_LIBRARY_DIR=/mnt/pool/services/audible/books` present in live unit |
| Binary | `audiblesync-0.1.1` ExecStart, PID restarted 14:07:00 |
| healthz | `{"status":"ok","version":"0.1.1","books":0}` — counters honestly 0 pending Q1 |
| `/files` inventory | All 72 rows render (ASIN-prefix + B-ASIN + `Propaganda - Bernard Woolner (B0741DTNNT).m4b` tail shapes), ASIN extraction correct on every row, `orphan` badges honest |
| Journal | Clean — INFO http-request lines only |
| Anchor | Pending: `switch-to-configuration test` (17+ min) holds behind `post-crash-calm-gate` (60-min no-trip window; memory-emergency-guard re-trips reset it). Profile still `system-1012-link`, current-system flipped to the new toplevel. Watcher live — flip to gen-1013 closes the battery |

Residual risk while unanchored: a reboot before the profile flip reverts the switch.
The calm gate + guard machinery is the parallel session's deploy tail and self-resolves
when the storm drains; watcher job polls stc completion + their audiblesync push.

## Final status (2026-11-22, close-out)

The mission completed through the parallel session's deploys — gen-1024 live and
anchored, every §Resolution item shipped:

- **Inventory + env wiring**: live since the Nov 15 battery (0.1.1, LIBRARY_DIR env,
  /files renders the archive rows).
- **Reconcile importer (Q1b)**: the parallel session built and pushed it upstream
  (startup reconcile from the weekly export, sync verification through the real
  pipeline's skip-if-present path, never downloads). Live journal 2026-11-19 14:45:
  `read model reconciled imported=86 existing=0 sync_checks=68`; healthz now answers
  `books:86`; /library renders the tracked rows with synced statuses; re-runs are
  idempotent (imported=0 existing=86 at every restart).
- **The zero-books question is fully closed**: counters were honest-0 by design; the
  read model is now seeded by the reconcile pass and stays coherent across restarts.
- **This session's residual**: a SystemNix lock float to audiblesync 9c519fd
  (post-wave executor hardening + docs, non-critical vs deployed 784ea835) is
  committed but deliberately NOT deployed — 57% io PSI storm, the delta is not worth
  a forced switch; it rides the next deploy. Discarded a duplicate web-route reconcile
  implementation developed in this session's sandbox (~/.cache/audiblesync-reconcile/)
  once the parallel session's upstream version landed first — theirs is richer
  (removed/skipped counters, startup wiring) and already proven live.
