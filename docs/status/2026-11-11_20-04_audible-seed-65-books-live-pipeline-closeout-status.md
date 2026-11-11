# Audible pipeline LIVE: 65 books / 28 GB seeded, deploy-storm close-out

**When:** 2026-11-11 20:04 CET · **HEAD:** `68260eb1e` (mine: `c79279e6a` annotation + `850f5a559` nostdin fix) · **Live gen:** 1003, anchored · **Books:** 65 / 28 GB
**Session:** closes the audible arc opened by the owner's "how many books are backed up / how can I play 1?" — scope: everything after the `2026-11-11_15-55_audible-seed-aax-pivot-four-runtime-bugs-status.md` report (which is annotated in-place with the closure).

**Owner's opener answered in one line each:**
- **Forgot:** to `nix build` the touched derivations BEFORE deploying (shellcheck runs at BUILD time and `nix flake check --no-build` — my pre-commit confidence source — never builds scripts; three deploys burned on a 1-second shellcheck failure I could have seen in 1 minute), and that `.crush/skills` is a symlink — my sops-skill recipe landed in the delivery layer, not any git repo.
- **Could have done better:** after deploy9's mystery build failure I fired deploy10 and deploy11 on GUESSES instead of forcing the rebuild first (`--rebuild` surfaced nothing because the store already held a cached output — I mistook cache-hits for builds); and I race-checked "no nh running" then fired deploy12/13 seconds later, losing two flocks to the exact window I had just measured.
- **Can still improve:** the winning strategy (poll for the FOREIGN deploy's success instead of racing for a window) should become the documented default under multi-agent storms; pre-deploy "build touched drvs" belongs next to the drv-equality pre-flight; the daemon's own behavior (visible in the process list: a `crush run` instructed to `git commit` with `--no-verify if needed`) explains every daemon-race anomaly of the last week and deserves a design row.

**Scope — VERIFIED here (fresh commands this session):**
- Books state: `ls /mnt/pool/services/audible/books/ | wc -l` → **65**; `du -sh` → **28 GB**; filenames show ASIN-prefixed 128 kbps LC stereo M4Bs (Atomic Habits, Dopamine Nation, Beyond Order, Ordinary Men, Traffic Secrets, …).
- Seed journal (17:45→18:12): `New aax files: 64` → "64 AAX files present (library: 86 items)" → "65 M4B in books/, 64 newly decrypted, 0 decrypt failures" → "run complete — last_success updated". Raw AAX deleted post-remux (downloads/ .aax count = 0, by design).
- SC2095: deploy11's log carries shellcheck's verdict verbatim (`ffmpeg may swallow stdin … Use ffmpeg -nostdin`); fix `-nostdin` committed `850f5a559` with the FULL pre-commit battery green (flake check included — doc-counts stamps held).
- Deploy record 15:55→18:12: deploy9 (quiescence-gated, 15:50 window) → audible-sync-run.drv "cannot build"; deploy10 → same; deploy11 → SC2095 verdict visible; deploy12/13 → flock-refused by foreign deploys; gen-1003 landed 17:32 via a FOREIGN deploy of HEAD (anchored, verified by `readlink -f` three-way equality), seed auto-started and completed by 18:12.
- Anchor: gen-1002 was live-anchored all afternoon until 1003; three-way anchor equality re-verified at 17:32 and again at 18:1x.
- Commits mine this window: `850f5a559` (nostdin), `c79279e6a` (report annotation). Everything else in HEAD is foreign (monitor365 shrink rows, takeout session's staged files).
- 15:55 report's §b.1 annotated in-place with the closure (annotation, not rewrite).

**Scope — NOT verified:**
- **The 21 non-downloaded items are UNATTRIBUTED** — Plus borrowals vs podcasts vs gone-server-side; the per-asin license errors sit in the journal and a library.json↔books/ diff would name them. Not derived yet.
- **Sunday-tick semantics risk NOT tested**: the 21 refused items DID get covers/chapters/PDFs written into downloads/ — if audible-cli's skip-if-exists keys on those side files, next Sunday's run may skip their AUDIO as "already downloaded" forever. Unverified, potentially silent.
- **Backup Freshness Gatus endpoint for audible-sync**: `last_success` is touched (verified in the unit dir); the freshness endpoint going green was NOT probed (deemed adjacent-scope).
- **PapDashboard audible tile** renders with a real library behind it: not probed.
- **sops skill recipe persistence**: the edit lives in `/mnt/hot/crush/SystemNix/skills/…` (verified writable + live) — that dir is NOT a git repo (verified `rev-parse` fatal), so the SOURCE repo (crush-config?) still holds the recipe only in SystemNix's runbook. Not located this session.
- AAX quality vs AAXC: no comparison possible (AAXC is account-refused); the 128 kbps LC stream is what Audible serves this account.

---

## a) FULLY DONE

1. **65 audiobooks archived, DRM-free, zero failures** — 28 GB in `/mnt/pool/services/audible/books/`, ASIN-prefixed names, 128 kbps LC stereo with chapters; playback verified via ffprobe duration + the chain proven by construction (`mpv "<file>.m4b"` for any of them).
2. **The seed ran END-TO-END through the module** — 86 library items → export ✓ → 64 AAX downloads + the Propaganda manual book → 65 remuxes, 0 failures → raw deleted → `last_success` touched with real books behind it. The unit is no longer a paper design: Sunday 05:00 weekly incremental (skip-if-exists) is armed on a proven pipeline.
3. **SC2095 caught and fixed before it could bite at runtime** — ffmpeg inside the `while read -print0` loop would have consumed the file stream and starved the library after the first book; `-nostdin` fix committed (`850f5a559`) with the full pre-commit battery green.
4. **The deploy-storm was beaten by strategy, not luck**: after losing two flock races, the poll-for-foreign-success loop caught gen-1003 landing at 17:32 (foreign-carried HEAD = all my fixes) and auto-started the seed — verified anchored before starting.
5. **doc-counts discipline held**: my stamps from 15:55 survived every battery since (0 gate failures on the four subsequent deploy attempts).
6. **All work committed** — `850f5a559` + `c79279e6a` mine; foreign sessions' monitor365/takeout/forgejo work landed alongside without collision (my pathspec commits stayed clean).

## b) PARTIALLY DONE

1. **The 21-item library gap** — works: 65 owned titles archived; the refusal errors are in the journal; library.json snapshots exist for diffing. Remains: attribute the 21 (Plus borrowals / podcasts / gone-server-side) via `library.json` ↔ `books/` name diff. Effort: S. Owner question §g2 hangs on this.
2. **sops-skill recipe persistence** — works: the recipe is LIVE in the delivery layer (`/mnt/hot/crush/SystemNix/skills/sops-secret-management/SKILL.md`, every future agent session sees it) and DURABLY in SystemNix's runbook (committed). Remains: the delivery dir is not a git repo — the recipe is one redeploy away from vanishing; locate the source repo (crush-config?) and commit there. Blocker: source location unknown to this session. Effort: S once found.
3. **Post-seed observability legs** — `last_success` touched (verified on disk); remains: confirm the Backup Freshness endpoint + PapDashboard tile went green with real data (two probe commands, not yet run).
4. **Weekly-run robustness** — the skip-if-exists-vs-refused-items semantics question above (§ scope) could silently cap the archive at 65 forever; needs a one-run verification next Sunday or a forced re-run test on one refused asin. Effort: S.

## c) NOT STARTED

1. **AAXC license escalation with Audible support** (owner-only; account-side refusal proven twice today).
2. **Plus-catalog download flow** (newer audible-cli / `--plus` semantics) — only if §g2 says wanted.
3. **stamp-counts helper** — queued (blocked 2 commits + 2 deploys today).
4. **Runtime canary start in deploy battery** — queued (would have caught all four audible bugs pre-deploy).
5. **Shared deploy-claim file** — queued (flock collisions all afternoon; my deploy12/13 losses).
6. **deploy.sh tree-reap post-rc** — queued (4 live evidences today).
7. **DEPLOY_FORCE_PRESSURE authority rule** — queued (overrides used again today, same justification).
8. **Pre-deploy "build touched drvs" step** — NEW this window, not started.
9. **pma storm adjudication** — queued; the storm ran ~16 h today (40-71% PSI through everything).
10. **pim-sync flip / google-sync console / docker+gcs reclaim** — queued owner-gated items, untouched.
11. **forgejo-github-sync / forgejo-runner / tq-agent-pool / bank-sync-qonto-corpus triage** — foreign-owned failures flagged in prior reports, untouched.

## d) TOTALLY FUCKED UP

1. **Three deploys (9/10/11) failed on a build failure one `nix build` would have caught** — ~90 minutes of storm-load battery time wasted; worse, my deploy11 diagnosis was WRONG (I declared "the store now holds a valid output, next deploy skips it" — the failure then repeated identically; only deploy11's verbose nh log surfaced shellcheck's actual message). The meta-lesson: when a build result contradicts your model, STOP firing deploys and read the raw builder output first.
2. **Two flock races lost in a row (deploy12/13)** by the check-then-fire gap — I verified "no nh running", then the battery took minutes before nh started, and a foreign session's nh beat mine to it. The fix is behavioral: after a flock refusal, do NOT retry fast — poll for gen advancement (the strategy that actually worked).
3. **The sops-skill recipe is unpersisted work pretending to be done** — I appended to `.crush/skills/…` without checking it was a symlink (pathspec "beyond a symbolic link" told me), landed it in a non-repo deployment dir, and only THEN verified persistence. The work is live but one redeploy from gone.
4. **The 09:13 report's effort estimate "S once a window opens" was fantasy** — the window battle took 2.5 h and five deploy attempts because the estimate ignored the multi-agent storm class entirely. Effort estimates in this environment must include the storm tax.
5. **The zero-download guard could not be validated** — it never fired (the successful run had downloads). Shipping a guard whose failure-path is untested contradicts my own "prove it" discipline; the next all-refused scenario (e.g. auth expiry) will be its first real test.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-deploy: build the touched derivations** (`nix build` the unit/run drvs before `nix run .#deploy`) — shellcheck + stdenv validation run at BUILD time, invisible to `flake check --no-build` and to the commit gate; today this cost 90 min.
2. **Multi-agent deploy protocol: poll, don't race** — on flock refusal, subscribe to gen advancement (the 17:32 win) instead of retrying windows; codify in the deploy docs next to the flock note.
3. **The auto-commit daemon is itself an agent** — the process list shows a `crush run` instructed to commit with `--no-verify if needed` using a synthetic model for messages: that explains the bypassed pre-commit legs, the heuristic messages, and the index-lock contention (a foreign session's 7m47s commit held the lock while its flake-check ran under storm). A design row exists for the honor-file; add "daemon should not hold index.lock across battery-length hooks" as a concrete sub-item.
4. **skip-if-exists vs refused-items semantics** need a test (§b.4): if side files (chapters/covers) mark an item "downloaded", the archive silently caps at today's 65 forever.
5. **Ship-with-untested-failure-paths discipline**: the zero-download guard (§d.5) — either fixture-test the guard branch or accept and record it as untested insurance in the module comment.
6. **Effort estimates under storms**: multiply by the observed deploy-storm tax (today: ×5 attempts) or say "unbounded under foreign storm" explicitly.
7. **Delivery-layer edits need a persistence check**: after ANY write beyond a symlink, immediately `git -C <resolved> rev-parse` — not-a-repo means "queue the source-repo commit before moving on".

## f) NEXT — up to 50 things to get done next

1. **Attribute the 21 missing library items** (diff `library.json` ↔ `books/`, classify Plus/podcast/gone) — High / S / Verification (NEW).
2. **Test skip-if-exists semantics for refused items** (does next Sunday skip their audio because covers/chapters exist?) — High / S / Bug-risk (NEW; silent-cap risk).
3. **Probe post-seed observability**: Backup Freshness endpoint green + PapDashboard audible tile renders — Medium / S / Verification (NEW).
4. **Persist the sops recipe in its source repo** (locate: likely crush-config) — Medium / S / Documentation (carried).
5. **Owner: accept 128 kbps AAX quality or escalate to Audible support for AAXC** — High / S / Owner call.
6. **Owner: Plus borrowals in archive scope?** (needs the plus-download flow if yes) — High / S / Owner call.
7. **Owner: pma storm kill/pause** (hour ~18) — High / S / Owner call.
8. **Pre-deploy "build touched drvs" step** — High / S / Quality (NEW; §d.1).
9. **Multi-agent deploy protocol: poll-for-gen on flock refusal** — Medium / S / Quality (NEW; §e.2).
10. **Runtime canary start in deploy battery** — High / M / Quality (queued).
11. **`nix run .#stamp-counts` helper** — Medium / M / Quality (queued).
12. **deploy.sh tree-reap post-rc** — High / M / Quality (queued; 4 evidences).
13. **Shared deploy-claim file** — Medium / M / Quality (queued).
14. **Daemon honor-file / lock hygiene** (incl. not holding index.lock across hook batteries) — Medium / M / Policy (queued; §e.3 sharpened).
15. **DEPLOY_FORCE_PRESSURE authority rule** — High / S / Policy (queued).
16. **Deploy pre-flight codify (PSI + drv-equality + NOW: build-touched-drvs)** — High / S / Quality (queued; extend).
17. **Post-provisioner is-failed sweep** — High / M / Quality (queued).
18. **Poll-loop float-quiescence gate** — Medium / S / Quality (queued).
19. **Smoke battery persistent-vs-self-healed re-probe** — Medium / M / Quality (queued).
20. **forgejo-github-sync exit 6/NOTCONFIGURED root-cause** — High / M / Bug (queued).
21. **forgejo-runner ensure-timer non-convergence** — High / S / Bug (queued).
22. **tq-agent-pool cgroup escape + 32.7G swap** — Critical / M / Bug (queued).
23. **bank-sync-qonto-corpus failed unit triage** — Medium / S / Bug (NEW-ish).
24. **pim-sync enable flip** (proven sops recipe applies) — Medium / S / Feature (queued).
25. **google-sync + pim-sync OAuth console unblock** — Medium / S / Owner action (queued).
26. **/data/docker + gcs-staging reclaim** — Medium / S / Owner call (queued).
27. **google-sync + paperless runbook parent-vs-leaf RWP wording** — Low / S / Documentation (queued).
28. **AGENTS.md harden{} caps note** — Low / S / Documentation (roadmap).
29. **PSI-aware battery fast-path** — Medium / M / Quality (roadmap).
30. **Per-provisioner result summary** — Medium / S / Quality (roadmap).
31. **service-health-check storm tolerance** — Medium / M / Bug (queued).
32. **Heartbeat file for long foreign sessions** — Medium / S / Quality (roadmap).
33. **startLimitBurst provisioner note** — Low / S / Quality (roadmap).
34. **nvme by-id re-resolve discipline** — Low / S / Quality (queued).
35. **jq-in-direnv recurrence check** (hit again today on `-Rs`) — Low / S / Documentation (roadmap).
36. **eval-cache SQLite busy under concurrent nix** — Low / S / Watch (roadmap).
37. **Cover/PDF handling for audible** (86 covers + 20 PDFs sit loose in downloads/; decide keep/prune/dedupe into M4B) — Low / M / Cleanup (NEW observation).
38. **Per-title download-refusal metric** (textfile collector reading the journal class) — Low / M / Feature (queued-adjacent).
39. **Newer audible-cli evaluation** (plus-download support, AAXC license changes) — Medium / M / Feature (queued-adjacent).
40. **Weekly audible run watch after the first Sunday tick** (2026-11-15 05:00) — Medium / S / Verification (NEW; first real timer run).

*(deliberately NOT harvested: 5-7 are owner questions in §g; 1-4 + 8-9 + 40 are NEW — pipeline/services rows appended below per the standing self-harvest rule; the rest carry queue rows from today's earlier reports.)*

## g) Questions I can NOT figure out myself

1. **Archive quality:** AAXC (modern, higher-quality) is refused for your customer ID under every auth shape — proven with your own full quickstart credentials. Is the 128 kbps AAX archive acceptable permanently, or do you want to escalate with Audible support (owner-only) to un-block AAXC?
2. **Plus borrowals:** of your 86-item library, 65 archived. If the remaining ~21 are Plus-catalog borrowals ("listened to" rather than owned), they need a separate plus-download flow to archive. Build it, or accept owned-only?
3. **The pma library-reports session** has now storm-loaded the box for ~18 hours (every deploy, gate, and build today ran under 40-71% IO PSI because of it). Should it be paused/killed so the box can breathe, or is it doing something you're waiting on?
