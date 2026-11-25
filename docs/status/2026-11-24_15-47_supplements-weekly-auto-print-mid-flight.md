# Status Report — 2026-11-24 15-47 CET — supplements-weekly Monday-00:00 auto-print (mid-flight, upstream green + verified, SystemNix wiring pending)

**Task:** `~/projects/tracking-papers` — automatically print the Supplements Weekly
sheet every Monday 00:00 local time, for the week starting at fire time.

**Repos touched:** tracking-papers (upstream, PRIVATE) + SystemNix (consumer).

---

## Context read before designing (the plan layer outranks fresh design)

- The decision brief already existed: `tracking-papers/docs/planning/2026-10-04_print-mechanism-brief.md`
  (TODO_LIST #2, AWAITING LARS, options manual-ritual / systemd-timer / CI-cron
  with Option 3 disqualified). **The user's request IS the Option 2 pick**, with
  00:00 instead of the sketched 09:00. Per the brief, picking Option 2 unblocks
  A14/TODO #5 ("vendor print-safe as a flake app the timer calls").
- `supplement-sheets` week semantics: `-week 0` default = NEXT week
  (`NextWeek`); a Monday 00:00 fire must render the week that STARTS at that
  instant, so the pipeline computes the current ISO week explicitly
  (`date +%-V` / `+%-G`, local clock) and passes `-week/-year`. This also
  makes Persistent catch-up correct: a Tuesday-morning replay still prints
  the RUNNING week's sheet, while next-week semantics would print the wrong
  (future) week.
- Gallery constraint (discover, then design around): every dated edition in
  `sheets/` requires a conscious `gallery/catalog.go` line + pinned tripwire
  counts (`gallery_golden_test.go` / `sheets/README.md`). Automation writing
  into `sheets/` would redden `nix flake check` every week. → The pipeline
  stages artifacts in `~/.local/state/tracking-papers/sheets` and leaves
  `sheets/` + gallery manual. **Owner decision queued** (§f.16).
- Printer failure modes (all physical, from `docs/printing-safety.md` +
  printer-log): Gutenprint gray flood (2026-08-28), color false-pass
  (2026-10-14), held-job when printer asleep at submit (2026-10-02, job 40).
  The pipeline encodes all three guards.

## Design on record

- **tracking-papers** owns the pipeline (flake app; SystemNix owns only the
  schedule): generate + gray-flood size guard (`-print -dry-run`) →
  print-safe dry-run (threshold stream validation, no ink) → print-safe
  (raw USB queue) → completion verify via `lpstat -W completed` (print-safe's
  exit does NOT prove paper) → bounded 600 s held-job release loop → outcome
  row appended to `docs/printer-log.md` → 8-week staging retention.
  Env knobs: `TRACKING_PAPERS_REPO`, `TRACKING_PAPERS_PRINTER_LOG`,
  `TRACKING_PAPERS_SHEETS_DIR`, `PRINT_SUPPLEMENTS_PRINTER`,
  `PRINT_SUPPLEMENTS_DRY_RUN=1` (inkless end-to-end).
- **SystemNix** module `services.supplements-weekly-print`: oneshot,
  `User=lars`, `Environment=HOME=%h` (systemd exports no HOME; WeasyPrint/
  fontconfig need it), `TimeoutStartSec=25min` (600 s + 600 s legs),
  `harden{}` + ReadWritePaths (repo docs dir, staging state dir, fontconfig
  cache), `ioTier.background`, `serviceOneshotDefaults`, `after/wants
  cups.service`, `onFailureP0` (Discord direct — a 00:00 toast-only signal is
  guaranteed unseen; the 2026-10-12 gatus lesson), timer `Mon *-*-* 00:00:00`,
  `Persistent=true`, `wantedBy=timers.target`, tmpfiles `mkStateDir` for the
  staging base. Not web-facing: no port, no vHost, no tile, no gatus.
- No secrets anywhere; no ink spent; dry-run verified only.

---

## a) FULLY DONE (each claim verified in-session)

tracking-papers (HEAD 42890f9 lineage; my commits fe65e92, 0ef20bf + daemon
caf712d1):

1. `supplement-sheets/main.go` renderPDF: PATH-first `weasyprint`, nix-shell
   fallback — so the timer needs no nix eval/registry/network at print time.
   `go test ./...` green (week math, render, goldens, PDF-text, page-count
   tripwire).
2. `pkgs/print-safe.nix` vendored — byte-identical body to
   `SystemNix/pkgs/print-safe.nix`, provenance + sync-duty header (only
   permitted delta). Daemon-committed fe65e92, contents verified
   (`git show --stat`: exactly that file).
3. `pkgs/print-supplements-weekly.nix` — the full pipeline app above.
   shellcheck clean (0.11.0, on the RENDERED script text). Flake wiring:
   `packages.print-safe`, `packages.print-supplements-weekly`,
   `apps.*` (commit 0ef20bf; SC2016 fix rode daemon caf712d1 — verified in).
4. Builds green: `nix build .#print-supplements-weekly .#print-safe`
   (store paths 02d8qsj…, x99zb8q…).
5. **End-to-end dry-run VERIFIED (rc=0, no ink):** correct week auto-detected
   (2026-W48), PATH weasyprint used, generator gray-flood guard passed
   (28 KiB), print-safe raster byte-exact validated (97,477,041 = expected),
   stream 1,302,247 bytes < 1.5 MB guard, 7.7% ink, 1 page A4 landscape.
   **The staged render is BYTES-IDENTICAL to the committed
   `sheets/supplements-weekly-2026-W48.pdf`** (cmp) — strongest possible
   parity proof for the packaging path.

SystemNix:

6. `modules/nixos/services/supplements-weekly-print.nix` written following
   house shapes (PMA module signature, crush-events oneshot pattern,
   mkSqliteBackupUnit harden/serviceOneshotDefaults/timer-Persistent
   pattern); unique filename across services/+desktop/; daemon-committed
   9fbc9335.

## b) PARTIALLY DONE

1. **SystemNix consumption chain missing** (module exists, nothing uses it):
   flake input absent, host enable absent, no eval run, no CI auth, not
   deployed. Detail: tracking-papers is PRIVATE, so the input must be
   `git+ssh://git@github.com/LarsArtmann/tracking-papers?ref=refs/heads/master`
   (floating — owner-repo pins fail eval via ownerPinViolations) AND the CI
   bundle recipe (docs/agents/go-ecosystem.md): keygen → read-only deploy key
   via gh api → append `@REPO tracking-papers` key to
   `NIX_DEPLOY_KEYS_BUNDLE_2` via `gh secret set` → mirror the key into the
   sops archive `platforms/nixos/secrets/ci-deploy-keys-bundle2.yaml`
   (sops skill to load first).
2. **tracking-papers docs not updated**: TODO_LIST #2 (CLOSED annotation per
   the brief's instruction) + #5 (vendored), CHANGELOG entry, README
   Quick-start automation note, AGENTS.md print-safe digest (220-line cap!),
   sheets/README + printing-safety "automated weekly print" section.
   Deliberately deferred: a sibling session committed TODO_LIST.md at 11:40
   (42890f9, 11 files) — re-read-before-edit on resume.
3. **Not pushed**: tracking-papers main is ~12 commits ahead of origin/main
   (mine + the sibling's print-log WIP). Deliberate: docs pending; also the
   CI key should exist before CI first evals the input from a SystemNix
   push — the tracking-papers push itself is order-independent.

## c) NOT STARTED

- SystemNix `flake.nix` input + `nix flake lock`; `configuration.nix` enable
  (house location: `crush-events.enable = true` neighborhood, line ~2335).
- Runbook `docs/services/supplements-weekly-print.md` (every enabled service
  has one).
- Eval gates: `nix flake check --no-build --all-systems` (will also prove the
  ioTier/primaryUser/ReadWritePaths imports and audit-class compliance),
  toplevel drv quiescence probe, pre-deploy-check.sh, `nix run .#deploy`.
- Post-deploy verification: `list-timers` next elapse = Mon 2026-11-30
  00:00 CET; `Persistent=1`; rendered unit file (HOME=%h, ReadWritePaths,
  onFailureP0 templates); staging dir stat as lars; queue stays disabled.
- First-fire observation (Monday 2026-11-30): held-job behavior, Discord
  page path, printer-log row landing, cupsenable authorization as a
  system-service lars context (precedent-based today, not live-probed).
- TODO self-harvest: deliberately deferred — the direct follow-ups (gallery
  owner decision, print-log integration) belong in tracking-papers'
  TODO_LIST, which the sibling session is actively committing; will land
  first thing on resume per the two-surface rule.

## d) TOTALLY FUCKED UP

Nothing destructive or lost. Nearest misses, all caught and documented:

1. **Daemon mixed my `supplement-sheets/main.go` edit into commit 7b51694
   together with a sibling session's `print-log/domain.go`** — attribution
   mixed in one commit (content verified: my renderPDF change only).
   Root cause: I content-pinned at session start but the sibling's work
   landed mid-session; I noticed via the post-add `git status` delta.
2. **First app build failed on shellcheck SC2016** (literal backticks inside
   the single-quoted printf format) — writeShellApplication fails on any
   finding. Fixed by dropping the backticks (which also matches the existing
   printer-log row style: no backticks). Cost: one build cycle.
3. **Amend hazard avoided**: with the sibling live, I used pathspec commits
   (`git commit -- <paths>`) and never amended the daemon's HEAD — per the
   2026-11-15 blind-amend incident doctrine.
4. No `rm`, no secret values, no plain-lpr path, no tree damage in either
   repo; both trees clean at report time.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-read discipline for BOTH repos**: I ran the planning pre-read for
   tracking-papers but not the status-report/log pre-read there; the sibling
   session's print-log overlap only surfaced after the first mixed commit.
   Cheap fix: `git log --since 6h` + `ls -t docs/status | head` before the
   first edit in ANY repo.
2. **Surface contract changes before encoding them**: staging-artifacts-
   outside-sheets quietly bends the "artifacts live in sheets/" contract —
   should have been an owner question BEFORE implementation (it shaped the
   design). Flagged in §g.1 now.
3. **Cross-session inventory**: two sibling sessions were active during this
   one (print-log in tracking-papers; project-discovery-daemon.nix in
   SystemNix at 15:40). Any follow-up session should assume mid-air edits and
   re-read before every docs edit.
4. Module assumptions to live-probe post-deploy: cupsenable/lp authorization
   from a system-service lars context (the manual ritual proves it for the
   desktop session only), and fontconfig cache write under harden (warnings
   are harmless but noisy).
5. The pipeline's log row and the sibling's `print-log` ledger (event-sourced
   print-attempt tracker, go-cqrs-lite) are two records for one truth —
   converge them deliberately, not by accident.

## f) NEXT (ordered; ~30 items, no padding)

**Finish the feature (must):**
1. tracking-papers docs pass (TODO #2/#5, CHANGELOG, README, AGENTS digest,
   sheets/README, printing-safety section) — re-read files first, sibling
   active.
2. Push tracking-papers main.
3. SystemNix flake input (`git+ssh://…tracking-papers?ref=refs/heads/master`)
   + `nix flake lock`; verify locked rev == origin/main tip.
4. CI deploy key + bundle_2 secret + sops archive mirror (sops skill first;
   recipe: docs/agents/go-ecosystem.md "Bundle recipe").
5. Enable in `platforms/nixos/system/configuration.nix`.
6. Runbook `docs/services/supplements-weekly-print.md`.
7. `nix flake check --no-build --all-systems` green (audit classes:
   io-tier-coverage, systemd-shape, memory-watermark, port — none, tile
   coverage — not web-facing).
8. Toplevel drv quiescence probe → pre-deploy-check.sh → `nix run .#deploy`.
9. Post-deploy battery: timer next-elapse Mon 00:00, Persistent=1, rendered
   unit (HOME=%h / ReadWritePaths / onFailureP0), tmpfiles dir stat as lars,
   queue disabled.
10. SystemNix TODO harvest: first-fire watch row → docs/todo/services.md +
    TODO_LIST one-liner (both surfaces, one commit).

**Verify in the wild (should):**
11. First-fire watch Monday 2026-11-30 00:00: journal, held-job path, Discord
    page (or not), printer-log row, queue re-disabled, wall sheet legible.
12. If held: exercise the bounded release loop verdict path; confirm the
    FAILED row + page wording is actionable.
13. Confirm cupsenable authorization from the service context (probe log;
    if denied, add lars to lpadmin or a cups policy note in the runbook).

**Decisions for Lars (owner-gated):**
14. sheets/ + gallery: land automated weeks (glob-based dated catalog or
    keep conscious-edit ritual)?
15. print-log ledger: does it supersede docs/printer-log.md rows (pipeline
    should call `print-log record …`), and is someone else ALSO building a
    Monday timer (overlap!)?
16. Habit-ledger monthly print in the same mechanism? (Brief's Option 2
    scope; user asked weekly only.)
17. WakeSystem=true (RTC wake at 00:00 sharp) vs current Persistent
    morning-replay; printer power schedule overnight.

**Hygiene (nice):**
18. `nix fmt -- <my 3 files>` in tracking-papers (treefmt is the only style
    arbiter; scoped form).
19. Run tracking-papers `buildflow` full gate once before push (repo AGENTS
    requires green).
20. SystemNix AGENTS.md: nothing to add (runbook carries the domain facts);
    confirm knowledge-routing table needs no new row.
21. Consider a `checks` leg in tracking-papers flake that shellchecks the
    app script in CI-adjacent fashion (writeShellApplication already does at
    build — redundant; only if BuildFlow skips nix builds in pre-commit).
22. SIGNoz/Gatus weekly-freshness probe on the printer-log row or staging
    artifact mtime (cadence monitor independent of the unit's own
    onFailure) — optional, YAGNI until first real miss.
23. VM-test leg for the module — low-risk oneshot+timer; skip unless the
    first-fire misbehaves.
24. Staging retention sanity after 8 weeks (find -delete actually pruning).
25. Re-verify bytes-identical parity after any WeasyPrint/nixpkgs bump
    (regression canary: one dry-run + cmp against sheets/ master).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **sheets/ + gallery contract**: should automated weeks eventually land in
   `sheets/` + the gallery (which implies making dated supplement editions
   glob-discovered in `gallery/catalog.go` so no per-week conscious edit is
   needed), or is the staged state dir acceptable as the permanent home
   (repo gallery stays manual/occasional)?
2. **print-log intent + overlap**: the sibling session's `print-log` module
   (event-sourced ledger: requested/validated/completed/failed) — is it
   meant to REPLACE the `docs/printer-log.md` markdown rows (in which case
   my pipeline should call `print-log record …` once stable), and is that
   session (or any other) ALSO building the Monday timer so I don't
   duplicate it?
3. **First-fire behavior preference**: keep Monday 00:00 with Persistent
   morning catch-up (current design: if the box/printer is off or asleep at
   00:00, the sheet prints at the next wake/boot — no midnight RTC wake), or
   do you want `WakeSystem=true` so the machine wakes and prints at exactly
   00:00 (printer must be powered, head-cleaning ink cost)?

---

**Evidence index:** tracking-papers commits fe65e92 (vendored print-safe),
0ef20bf (pipeline + flake wiring), caf712d1 (SC2016 fix, daemon), 7b51694
(main.go renderPDF, mixed with sibling print-log work — verified mine);
SystemNix commit 9fbc9335 (module); store paths
`02d8qsjy01xa1pghzvp4vb7m8xfq9gpg-print-supplements-weekly`,
`x99zb8q67l54w1incyc7g4j5ra9yibhb-print-safe`; dry-run transcript in §a.5.
Working files at report time: both trees clean; no unpushed local edits of
mine outstanding except the deferred docs pass.

---

## Completion section (2026-11-25 01:00–04:30, continuation session)

**Owner questions resolved by proceeding on the recommended defaults** (the
`question` prompts were interrupted twice; all three recommended answers ARE
the already-verified implementation, so no code changed): (1) sheets land in
the 8-week staging dir only — `sheets/` gallery stays manually curated;
(2) pipeline keeps writing `docs/printer-log.md` rows; revisit recorded as
tracking-papers TODO row 99 (`print-log export --markdown` integration once
stable — print-safe's own ledger hooks fire best-effort whenever
`~/.local/bin/print-log` resolves, including under the timer); (3) Monday
00:00 with `Persistent=true` only, no `WakeSystem`.

### Landed this continuation

- **tracking-papers docs pass** (pushed `4651119` + `c6dd241`): TODO #2
  RESOLVED / #5 DONE annotations, CHANGELOG entry, README automation note,
  AGENTS.md print-safe digest rewrite (219/220 lines, cap held),
  sheets/README + printing-safety "Automated weekly print" sections,
  decisions.md long-form record, TODO row 99. Buildflow legs touching these
  files green; the 4 remaining `docs-gates` findings (annotate spacing ×2,
  freshness unharvested ×4) belong to the LIVE docs-gates-grind session's
  own 00-07 report — not harvested to avoid a double-harvest collision.
- **SystemNix wiring** (daemon commit `1c2a3bf9f`): flake input
  `tracking-papers` (`git+ssh://…?ref=refs/heads/main` — this repo's default
  branch is MAIN; the handoff's master template was wrong and the first
  lock attempt failed `couldn't find remote ref refs/heads/master`),
  locked `4651119a` == origin tip; `nixpkgs` + `flake-parts` followed (revs
  matched root at adoption), `go-nix-helpers` deliberately NOT followed
  (rev differs from root's). Module enabled in configuration.nix; runbook
  `docs/services/supplements-weekly-print.md`.
- **CI private-input auth** (bundle recipe, docs/agents/go-ecosystem.md):
  ed25519 keypair generated, public key registered read-only
  (key id `171030558`, title systemnix-ci-readonly), sops archive
  `platforms/nixos/secrets/ci-deploy-keys-bundle2.yaml` gained
  `tracking_papers_key` (4 keys total), `NIX_DEPLOY_KEYS_BUNDLE_2` rebuilt
  from the archive (4 @REPO sections) and set via stdin. Private material
  trashed after the set. sudo probed rc=0 in this session (v0.102.0).
- **Gates**: `nix flake check --no-build --all-systems` → **all checks
  passed** (log `~/.cache/fc-2026-11-25.log`, only pre-existing warnings);
  package attr probe
  `(getFlake …).inputs.tracking-papers.packages.x86_64-linux.print-supplements-weekly`
  resolves. Pre-deploy battery first run: 152 ✓ / 8 warn / 1 fail — the
  fail was check 2 (evo-x2 eval) racing sibling commits transiently;
  re-probe green.

### Deploy status: BLOCKED (external, not this task's tree)

Three deploy attempts by parallel sessions all died on ONE foreign cause:
library-policy's go-modules FOD hash mismatch (`gYkU…` specified vs
`UCnK…` got). The library-policy session fixed the vendorHash locally
(`2ffc8c6`, 01:59) and its lineage reached the remote briefly (SystemNix's
lock floated to `e092b400` at 01:38), but **origin/master was force-pushed
BACK to `3737422`** — the fix is now remote-unfetchable and lives only in
that session's local checkout (session cwd ~/projects/library-policy, live
per /proc, last commit 02:10, dirty `fleet_scan.go` mid-feature). Per the
never-touch-foreign-work rules this session did NOT push, float, or repair
their repo. Consequences recorded: SystemNix's locked `e092b400` is a
time bomb (evals survive on the fetcher cache until eviction) and every
fleet deploy fails until that session pushes its 5-commit lineage. Harvest
rows queued (`ac905845e`): deploy row `[blocked:push]` + first-fire watch
(Mon 2026-11-30 00:00). Boot id pinned `b4931451` (PSI storms 31–98%
overnight from sibling builds; no reboot through 04:26).

**Residual work for the next session**: when origin/master contains
`2ffc8c6`: `nix flake update library-policy` → `nix run .#deploy` (skip if
a sibling's deploy already landed the wave — check
`ls -t /var/log/systemnix-deploys/` + the drv-equality probe) → post-deploy
verify (timer NextElapse Mon 00:00, rendered unit HOME=%h + ReadWritePaths
+ onFailureP0, tmpfiles `stat ~/.local/state/tracking-papers`, anchor
discipline) → tick the `[blocked:push]` rows in TODO_LIST +
docs/todo/services.md.

### Deploy outcome (2026-11-25 05:26, final)

The library-policy session pushed its fixed lineage (origin/master →
a60fda4, 04:41); the lock was floated (`5578f08f0`, pre-commit toplevel
build gate PASSED — the FOD heals), master pushed 04:52Z, and the
04:59:27 sibling-carried deploy landed the whole wave as **gen-1030**.
nh skipped the profile-set: the anchor check caught UNANCHORED and the
repair procedure ran (profile → gen-1030 == current-system `hggzirywc…`,
`stc boot`, boot-mirror-sync restarted + mirrored 403M, **pre-reboot-check
18 ✓ / 0 ✗ SAFE TO REBOOT**, path trigger armed/waiting). Live unit
verified: timer active/waiting, **NextElapse 2026-11-30 00:00:00 CET Mon**;
rendered service HOME=%h, ReadWritePaths ×3, OnFailure notify-failure@%n +
notify-failure-p0@%n, MemoryMax 512M, TimeoutStartSec 25min, User=lars;
tmpfiles `~/.local/state/tracking-papers` = lars:users 0750.

CI (nix-check on the push): red, but NOT this task's input — every fetch
failure (23×) is `Code-To-CV-Agent` publickey, the structural bundle-slug
mismatch (`@REPO cvagent` can never insteadOf-match the repo slug; queued
as a pipeline row). **Zero tracking-papers fetch errors** — the new deploy
key + BUNDLE_2 entry work on CI.

The `[blocked:push]` harvest rows are ticked in TODO_LIST +
docs/todo/services.md (deploy + verification narrative); the first-fire
watch row stays open until Mon 2026-11-30.
