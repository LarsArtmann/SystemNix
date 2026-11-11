# Audible seed-start arc: four runtime bugs, the AAX pivot, first book delivered

**When:** 2026-11-11 15:55 CET · **HEAD:** `6fcc00df0`+ (module landed via daemon `3e7b08806`) · **Live gen:** 1002 (`f3jgwq68…`, anchored)
**Session:** continuation of the audible arc (reports `2026-11-11_01-13…` + `2026-11-11_09-13…`). Owner asked: "how many audiobooks are backed up? how can I play 1 to verify?" — the answer cascaded into four first-run runtime bugs, an empirically-proven pipeline pivot, and the first DRM-free book on the pool.

**Direct answers to the opener:**
- **Forgot:** to load the project's sops skill before the sops work (derived the host-key→age recipe the hard way), and that `git status` after every daemon-race is cheaper than reconstructing where a fix landed.
- **Could have done better:** verified the download flags against the real CLI BEFORE the first deploy instead of shipping three dead flags; read the calm-gate's `--max-wait-min` before wondering why activations took an hour; started the single-asin AAX test before rewriting the module (the Propaganda test is what revealed everything).
- **Can still improve:** runtime-first verification for new service units (eval gates are structurally blind to CLI flags, license servers, and path resolution); a stamp-counts helper so foreign count drift stops blocking everyone's commits.

**Scope — VERIFIED here (fresh commands this session):**
- Books count at question time: `find /mnt/pool/services/audible -type f | wc -l` → **0**; main unit never ran (empty journal since go-live); timer = Sunday 05:00 +10min jitter, `Persistent=true`.
- Bug #1 (auth symlink): full traceback from `journalctl -u audible-sync` — `FileNotFoundError: '/nix/store/auth.json'`, `status=3/NOTIMPLEMENTED`; CLI source read (`config.py:48` — `pathlib.Path(filename).resolve()` follows the config.toml symlink; `dirname` → `/nix/store`).
- Bug #1 fix live: rendered config.toml greps `auth_file = "/var/lib/audible-sync/config/auth.json"`; re-run passed the export phase.
- Bug #2 (flag): `Error: No such option '--no-progress'`, `status=2/INVALIDARGUMENT`; all flags audited against the built CLI's `--help` + the decrypt plugin's argparse.
- Bug #3 (licenses): `License not granted to customer [A3W1O8PELJKINR]` for ALL 86 asins; proven auth-shape-independent — the FULL quickstart auth (`~/.audible/audible.json`, 12 keys incl. refresh_token + WebPlayer cookies) fails the single-asin AAXC test identically; AAX download of B0741DTNNT SUCCEEDED (131MB in 25s).
- Bug #4 (freshness lie): the 14:51 run printed "0 AAXC files present (library: 86 items)" then "run complete — last_success updated" — script fixed to fail loud on zero downloads with a non-empty library.
- AAX chain proven live: `audible activation-bytes` → `feb67135`-length key fetched; `ffmpeg -activation_bytes … -c copy` → **`books/Propaganda - Bernard Woolner (B0741DTNNT).m4b`, 134MB, duration 16960s (4h42m)**, owned `audible-sync:audible-sync` — play it: `mpv "/mnt/pool/services/audible/books/Propaganda - Bernard Woolner (B0741DTNNT).m4b"`.
- Sops full-auth ingest: `--set` landed (diff = one re-encrypted string blob + mac/lastmodified); verified key lengths only (activation_bytes 8, adp_token ~1.5k, refresh_token ~0.9k) — values never printed.
- Anchor repair: current-system `f3jgwq68…` was UNANCHORED (profile still 1001 after the 14:09 foreign switch died mid-flight); repaired → `system-1002-link` == profile == current-system; boot entry re-stamped (`switch-to-configuration boot`).
- Deploys this arc: #6 gen-999 (mine, rc=3 smoke noise), gen-1000 (13:48 foreign, exited 0, 80min), gen-1001 (12:22→13:39 foreign, ksqwkq2r), the 14:09 foreign switch (DIED mid-flight → the unanchor above), my deploy7 (rc=1 doc-counts ×2, then nh-lock), deploy7b (rc=1 nh-lock), deploy8 (rc=1 etc.drv build failure on foreign half-staged `_forgejo-scripts.nix`).
- doc-counts whack-a-mole: README gatus 297→298 (foreign "DNS Forwarder Cold" endpoint, `513084277`) and FEATURES packages 52→53 (foreign `io-surface` input, `6a832fbd1`) — both re-stamped and committed; the gate then passed.

**Scope — NOT verified:**
- The seed has NOT yet completed a run with the AAX pipeline: the fix is committed (HEAD) but the deploy carrying it kept losing the window to the foreign deploy-storm (nh locks, half-staged trees); a quiescence-gated loop is running in the background and will deploy + start the seed when the tree quiets.
- Whether Plus-catalog titles (borrowals inside the 86) are AAX-downloadable: untested — owned titles are proven; Plus titles may still be refused account-side.
- AAX audio quality: the delivered file is the 64 kbps LC stream (legacy format); I have no AAXC comparison (the license path is dead account-side).
- The foreign `takeout` session's work (cookies probe, forgejo-scripts edits): observed only — their `f9faf6023` commit and the half-staged `_forgejo-scripts.nix` that broke my deploy8's build.
- pma storm: still ongoing (entry gates read 40-71% IO PSI all session); no attribution re-run.

---

## a) FULLY DONE

1. **First DRM-free audiobook delivered and playable** — `books/Propaganda - Bernard Woolner (B0741DTNNT).m4b` (134MB, 4h42m), full chain proven live: AAX download → activation-bytes remux → pool. Playback: `mpv "/mnt/pool/services/audible/books/Propaganda - Bernard Woolner (B0741DTNNT).m4b"`.
2. **Auth-symlink bug found, root-caused in CLI source, fixed, deployed, verified** (`config.py:48` resolve-follows-symlink → absolute `auth_file` in the generated config.toml; live run passed the export phase).
3. **`--no-progress` dead-flag bug found and fixed** (flags audited against the built 0.3.3 `--help`; download/decrypt/export option sets verified).
4. **AAXC license refusal root-caused as ACCOUNT-side, not ours** — proven with the full quickstart auth (the strongest possible credential set): the license server refuses this customer for AAXC grants; not an auth-shape, marketplace, or pipeline issue.
5. **AAX pivot implemented end-to-end**: `--aax` download, ffmpeg activation-bytes remux (plugin retired), raw-AAX-deleted-on-success, zero-download guard against the freshness lie; module + runbook committed (daemon `3e7b08806` + `6fcc00df0`), lints re-run standalone green.
6. **Sops secret upgraded to the full auth shape** (one encrypted blob, `132c12c70`), with the host-key→age conversion recipe derived and documented in the runbook (sops 3.13 dropped ssh-key env support).
7. **Anchor repaired**: the 14:09 foreign switch left current-system ≠ profile (unanchored — boot would have reverted gen); profile → system-1002, boot entry re-stamped.
8. **doc-counts unblocked for everyone**: README gatus 297→298 (attributed `513084277`) + FEATURES packages 52→53 (attributed `io-surface`, `6a832fbd1`), both re-stamped with the derivation commands (`fb07f1b2c`, `ef17ab5de`).
9. **The 08:47 dirs re-fire mystery resolved as benign by observation**: it has not recurred; both recorded runs finished clean.
10. **One-time activation-bytes fetch executed** (`audible activation-bytes` via WebPlayer cookies) and baked into the sops auth — future re-auths documented in the runbook.

## b) PARTIALLY DONE

1. **The automated seed run** — module rewritten + committed, but NOT yet activated: every deploy window this afternoon was won by foreign sessions (nh locks, half-staged trees breaking etc.drv). Works: everything up to the pipeline (chain proven manually). Remains: deploy gen with `6fcc00df0`, start `audible-sync.service`, watch 86 AAX downloads (~11GB) + remux. Blocker: foreign deploy-storm (a quiescence-gated loop is running). Effort: S once a window opens.
2. **Library coverage** — owned titles proven downloadable; Plus-borrowal titles inside the 86 untested under AAX. Remains: one seed run to see the real per-title results.
3. **tq-agent-pool / forgejo-github-sync / forgejo-runner** (flagged in the 09:13 report) — untouched; bank-sync now also shows a NEW failed unit (`bank-sync-qonto-corpus.service`, foreign wave).
4. **This arc's queue harvest** — the sops-age recipe landed in the runbook; moving it into the project's sops skill + the doc-counts stamping-discipline row remain open.

## c) NOT STARTED

1. **AAXC license escalation with Audible support** — the 64k AAX stream is an archive-quality tradeoff; fixing AAXC (higher quality) is account-side, owner-only.
2. **Plus-catalog download support** (`--plus` flow / newer audible-cli) — needed only if the owner wants borrowed titles in the archive.
3. **stamp-counts helper** (`nix run .#stamp-counts` re-deriving README/FEATURES counts) — would have saved three blocked commits/deploys today.
4. **Persistent-vs-self-healed smoke re-probe** — queued this morning, not started.
5. **deploy.sh tree-reap post-rc** — queued this morning, not started (a 12:22 wrapper held the flock 1h17m past its nh's exit today — fourth live evidence).
6. **Pressure-gate authority rule** — queued, still awaiting owner verdict.
7. **pma session adjudication** — queued, storm un-drained (40-71% PSI all day).

## d) TOTALLY FUCKED UP

1. **I shipped a module with three dead CLI flags and an unverified license path** — the eval gates cannot see runtime reality, and I treated "eval green" as "works". The seed then failed FOUR times (symlink path, dead flag, license refusals, freshness lie) before one book moved. Each failure was diagnosed within the session, but the whole class was avoidable by running the single-asin AAX/AAXC probe BEFORE the first deploy.
2. **The freshness lie shipped by me**: the script (which I did NOT write this session but maintained) touched `last_success` after a 0-book run — backup-coordination would have shown fresh-healthy with zero books. Guard added only after observing it.
3. **I nearly shipped the whole library as AAXC-less noise**: had `--ignore-errors` + zero-guard not been added, every weekly run would "succeed" while downloading nothing — a fully green phantom archive.
4. **My deploy7/7b/8 attempt cycle burned three windows** by racing the foreign sessions without re-checking nh locks mid-sequence (deploy7b's nh-lock refusal was predictable from deploy7's refusal 3 minutes earlier).
5. **I loaded the sops skill only after deriving the recipe** — the skill exists in-repo for exactly this; the rules require loading it first.
6. **The doc-counts drift was fixed by ME twice for foreign sessions** — correct outcome, but each fix was reactive mid-deploy rather than the foreign sessions stamping at commit time; the discipline gap stays open (§c.3).

## e) WHAT WE SHOULD IMPROVE

1. **Runtime probe BEFORE pipeline deploy** for any new external-API service: one manual end-to-end command (single item) before wiring the unit — would have caught all four bugs in one shell session.
2. **`--ignore-errors` commands need an explicit outcome guard**: whenever a CLI swallows per-item errors, the wrapper must assert on counts (this pattern generalizes: forgejo-runner, journal-import…).
3. **Stamp counts at commit time, not deploy time**: the doc-counts gate now blocked 2 commits + 2 deploys for foreign drift; a `nix run .#stamp-counts` that re-derives and edits the docs would make the fix mechanical.
4. **sops 3.13 recipe belongs in the sops skill**: host ssh key → `ssh-to-age -private-key` → `SOPS_AGE_KEY` (the `_FILE`/`_CMD` ssh vars are dead); harvest it into `.crush/skills/sops-secret-management/` this pass.
5. **Foreign deploy-storm coordination**: five sessions retried deploys against each other's locks today (13:48/13:56/14:09/15:21/15:25/15:31…); the nh "Could not acquire lock" aborts are pure waste — a shared deploy-claim file (path + PID + start time) would let sessions wait instead of colliding.
6. **First-run services need a canary start in the deploy battery**: after switch, start the new unit once and fail the deploy on non-zero — every first-run bug today was found by ME starting units manually.
7. **Keep proving the anchor**: two of today's five switches died mid-flight (current-system flipped, profile lagging); the repair recipe works but the 14:09 one sat unanchored for ~4h until I noticed — the post-deploy anchor check should be mandatory in the wrapper even on rc=1 aborts.

## f) NEXT — up to 50 things to get done next

*(ranked by impact; NEW items from this arc are harvested at authoring time; queued items marked)*

1. **Land the AAX-pipeline deploy and start the seed** (quiescence loop running) — Critical / S / Feature (unblocks the whole archive).
2. **Verify first full seed**: 86 items → AAX downloads → M4B count, journal three-phase check, freshness row appears — Critical / M / Verification (seed-gated).
3. **Owner: accept or reject 64 kbps AAX archive quality** (AAXC is account-refused; support-ticket escalation is owner-only) — High / S / Owner call (NEW).
4. **Owner: Plus-catalog titles in scope?** (borrowals may refuse AAX too; needs the plus-download flow if wanted) — High / S / Owner call (NEW).
5. **Move the sops-3.13 age recipe into `.crush/skills/sops-secret-management/SKILL.md`** — High / S / Documentation (NEW; harvest this pass).
6. **`nix run .#stamp-counts` helper** (re-derive README/FEATURES counts mechanically) — High / M / Quality (NEW).
7. **Runtime canary start in deploy battery** (start new/changed oneshots post-switch, fail deploy on non-zero) — High / M / Quality (NEW; would have caught all four bugs).
8. **deploy.sh tree-reap post-rc** (flock outliving the deploy; 4th evidence today) — High / M / Quality (queued).
9. **Post-crash-calm-gate vs forced deploys**: forced deploys bypass the entry gate but activations still wait on the calm gate 60 min then refuse — define the forced-deploy activation policy — Medium / S / Policy (NEW observation).
10. **Root-cause forgejo-github-sync exit 6/NOTCONFIGURED** — High / M / Bug (queued).
11. **Diagnose forgejo-runner ensure-timer non-convergence** — High / S / Bug (queued).
12. **Root-cause tq-agent-pool cgroup escape + swap** — Critical / M / Bug (queued).
13. **bank-sync-qonto-corpus.service failed unit triage** (new foreign-wave unit) — Medium / S / Bug (NEW).
14. **Poll-loop float-quiescence gate** — Medium / S / Quality (queued).
15. **Smoke battery persistent-vs-self-healed re-probe** — Medium / M / Quality (queued).
16. **DEPLOY_FORCE_PRESSURE authority rule** — High / S / Policy (queued; fourth override used today).
17. **Deploy pre-flight codify** — High / S / Quality (queued).
18. **Post-provisioner is-failed sweep** — High / M / Quality (queued).
19. **pma session kill/pause decision** — High / S / Owner call (queued; storm persists).
20. **pim-sync enable flip** (audible precedent + proven sops recipe apply directly) — Medium / S / Feature (queued).
21. **Fix audible runbook quickstart line** (`auth.json` → `audible.json` in config-check's hint text, module line ~104) — Low / S / Documentation (queued adjacent; noticed again today).
22. **google-sync + pim-sync OAuth console unblock** — Medium / S / Owner action (queued).
23. **/data/docker + gcs-staging reclaim** — Medium / S / Owner call (queued).
24. **Check google-sync + paperless runbooks for parent-vs-leaf RWP wording** — Low / S / Documentation (queued).
25. **AGENTS.md harden{} caps note** — Low / S / Documentation (roadmap).
26. **PSI-aware battery fast-path** — Medium / M / Quality (roadmap).
27. **Per-provisioner result summary** — Medium / S / Quality (roadmap).
28. **service-health-check storm tolerance** — Medium / M / Bug (queued).
29. **Heartbeat file for long foreign sessions** — Medium / S / Quality (roadmap).
30. **startLimitBurst provisioner note** — Low / S / Quality (roadmap).
31. **nvme by-id re-resolve discipline** — Low / S / Quality (queued).
32. **jq-in-direnv recurrence check** (bit me again today on `-Rs`) — Low / S / Documentation (roadmap).
33. **Audible: report per-title license refusals as a summary metric** (textfile collector reading the journal class) — Low / M / Feature (NEW, follows from §e.2).
34. **Audible: cover/PDF dedup into the M4B** (covers currently land as loose .jpg in downloads/) — Low / M / Feature (NEW observation: 86 covers + 20 PDFs downloaded fine and now sit next to the audio).
35. **Consider audible-cli newer version** (0.3.3 vs upstream; may carry plus-download + AAXC license fixes) — Medium / M / Feature (NEW).

*(deliberately NOT harvested: items 3-4 are owner questions carried in §g; item 1-2 are the active loop's work; the rest either have queue rows already or are roadmap-class.)*

## g) Questions I can NOT figure out myself

1. **Audible archive quality**: the license server refuses AAXC (the modern format) for your customer ID under every auth shape I can create — account-side, not fixable from here. Is the 64 kbps AAX archive acceptable permanently, or do you want to escalate with Audible support to get AAXC grants working?
2. **Plus-catalog coverage**: your 86-item library includes Plus borrowals ("listened to" titles). If those also refuse AAX download (likely — they're not owned), the archive covers owned purchases only. Is owned-only acceptable, or should I build the Plus-download flow (a bigger feature, newer audible-cli)?
3. **The pma storm is now on hour ~14** (40-71% IO PSI through every deploy and gate today). Do you know if it's producing anything, and should it be paused so the box (and everyone's deploys + the seed) can breathe?
