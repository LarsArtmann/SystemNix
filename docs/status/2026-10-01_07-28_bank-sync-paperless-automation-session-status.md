# Status Report — bank-sync→Paperless automation session

**Written:** 2026-10-01 07:28 CEST · **Scope:** this session only (user directive: no unrelated research) · **Format:** .md per explicit user instruction (skill default is HTML — override flagged)

**Session arc:** "Why is bank-sync to paperless not configured?" → root cause (a 2026-09-13 enable-gate whose token-paste half never happened, untracked by any TODO) → documentation + queueing → the user's "why can't we automate this via nix!?" → **full automation landed**: runtime token minting replaces the paste-into-sops flow entirely.

**Commits (mine, this session):** `e52b9f90` (docs tracking the forgotten go-live), `d73810f0` + `358d47aa` + `7a5cf497` + `b545a74f` (daemon-swept mechanism + iterations — heuristic messages, see d5), `04a9fc2c` (TODO count fix), plus the smoke-probe harvest + stub fix pending in-tree.

---

## a) FULLY DONE

1. **Root cause, evidence-backed**: the weekly archival was built 2026-09-13 (`50ddba86`) enable-gated on pasting a Paperless DRF token into sops; the token file has exactly ONE sops save (its creation, `lastmodified 2026-09-13T10:25:05Z`, PLACEHOLDER per the commit message) — the flip never happened and NO TODO tracked the leftover half. Feature sat dark 18 days.
2. **The manual go-live is GONE**: `bank-sync-paperless-token` oneshot mints the token at archival time — `drf_create_token` proven idempotent against upstream DRF source (`get_or_create`), runs as the paperless user (PG peer-auth identity), writes `/run/bank-sync-paperless/env` (tmpfs only, 0400 bank-sync via root `+`ExecStartPost), `RuntimeDirectoryPreserve=true` so the file survives oneshot deactivation. URL derives from `lib/ports.nix` (paperless 2892).
3. **Secret surface removed**: placeholder-only `platforms/nixos/secrets/bank-sync-paperless.yaml` deleted TOGETHER with its `sops.nix` mkSecrets block + `bank-sync-paperless-env` template (symmetric removal — no sops atomic-decrypt break; zero plaintext-token-at-rest anywhere).
4. **Flag flipped**: `paperlessArchive.enable = true` in configuration.nix with rationale comment; coupling assertion fails eval if archival is on while paperless is off; both units additionally gate on paperless actually being enabled (nixpkgs assigns the read-only `manage` option only then).
5. **Regression test rewritten**: `tests/test-bank-sync-paperless.nix` — 14 cases covering the mint (idempotent oneshot, paperless identity, datadir mount-gate + probe-write access, tmpfs-only storage, Preserve, root handover), archival wiring (env files incl. the minted one, requires+after ordering, URL-from-port-registry), disabled shapes, and the coupling assertion. Discovered and fixed my own test bug (`archivalPaperlessOff.config` → `.assertions`).
6. **Verification, all green**: 14-case pure-eval test ✅ · evo-x2 toplevel eval clean through every audit module ✅ · rendered units spot-checked on the real config (mint User=paperless; archival env files = daemon env + minted env + SCA drop-in; requires=token; URL 2892) ✅ · `nix flake check --no-build` all checks passed ✅ · check-todo-system structure clean ✅.
7. **Docs self-consistent**: runbook section rewritten (docs/services/bank-sync.md — mechanism + rotation via `drf_create_token -r`), FEATURES.md row, CHANGELOG entry, TODO queue + library rows kept non-drifting across three supersessions (blocked:user → blocked:deploy → automated).
8. **Daemon-swept lint gap closed**: my final .nix files rode heuristic commits, so the pre-commit statix/deadnix legs could have silently skipped — re-ran both standalone: clean.
9. **Micro-hygiene**: `meta.mainProgram` on the test stub (kills the `getExe` deprecation warning); smoke-probe follow-up self-harvested into both TODO surfaces at authoring time (per the §f self-harvest contract).

## b) PARTIALLY DONE

1. **The feature end-to-end**: everything in-tree and eval-verified, but NOT DEPLOYED — the first real mint + first real archival upload are unproven. Queued `[blocked:deploy]` (TODO_LIST + services.md).
2. **TODO-system hygiene**: my rows are drift-free; the TREE-WIDE debt observed by the checker (58 unharvested §f-bearing status reports; ~63 queue/library drifts incl. several concrete wrong-link rows) is untouched — out of this session's scope, now enumerated in (f).
3. **Tree cleanliness**: two foreign-modified files (`docs/status/2026-09-30_08-06_dmarc-*.md`, `docs/todo/pipeline.md`) + one untracked tq report belong to parallel sessions — flagged per the multi-agent rule, deliberately not touched or co-verified.

## c) NOT STARTED

1. Deployment + first-run verification of the archival pair (the queued blocked:deploy item).
2. `bank-sync-paperless` smoke probe in post-deploy-check.sh — **harvested this session** as `[ready]` (queue + services.md).
3. Success-side observability for archival runs (e.g., last-archival-timestamp textfile metric + Gatus check) — deliberately NOT harvested: owner call after first production run shows whether OnFailure-only alerting suffices.
4. Per-consumer least-privilege token (bank-sync + inboxclean now share the SAME admin DRF token — the mint returns the existing one) — needs the owner's security-posture answer (see g1).
5. Cross-path statement dedup analysis: inboxclean (Gmail attachments) and bank-sync (DB statements) can deliver the SAME PDF; paperless `delete-duplicates` is the belt, but which copy should WIN is a product decision (see g2).
6. Everything session-independent (SCA OTP, llama.cpp bisect, mail relay, hot-db waves, …) — intentionally untouched.

## d) TOTALLY FUCKED UP

Nothing is fucked up — nothing shipped broken, no data at risk, tree eval-green. Honest near-miss ledger instead:

1. **`RuntimeDirectoryPreserve` bug — caught by self-reflection, not by any test**: default behavior deletes the runtime dir the moment the mint oneshot deactivates → the archival unit's EnvironmentFile would have been missing on EVERY run. This would have shipped a broken feature to production (loud, via OnFailure, but broken). The 14-case eval test CANNOT catch systemd lifecycle semantics — see e3.
2. **`unitConfig` nested inside `serviceConfig`** — invalid shape, caught reviewing my own diff before any build.
3. **Three consecutive test failures before green** (paperless option collision → read-only `manage` → `package.apply` tesseract5 override on a runCommand stub). Each was the test doing its job; ~3 wasted build cycles from not reading the nixpkgs module's option semantics BEFORE writing the test (e2).
4. **Commit-history fragmentation**: the daemon swept my work across 4 heuristic commits (+1 mixed 11-file commit carrying a foreign status report) — per the daemon-race policy I verified contents and landed on top instead of amending shared commits, but the history tells the story poorly vs one well-formed commit (d-adjacent: e1).
5. **Process friction, recovered**: one no-op edit (same-string), two edit attempts burned on read-state mtime races, one transient "unable to write new index file" (NOT disk — 52G free; concurrent index churn; commit succeeded on retry) — the shared-tree tax, logged not suffered silently.

## e) WHAT WE SHOULD IMPROVE

1. **Pathspec-land each file IMMEDIATELY after writing** (CONTRIBUTING daemon-race policy says exactly this — I batched edits and the daemon won 4 times). The window only narrows by committing sooner.
2. **Read the real option semantics before writing tests against them**: the three test failures were all "nixpkgs module does something clever with the option" (module-list always loaded; readOnly; apply-with-override). Ten minutes with the module source first would have saved them.
3. **Eval tests are blind to systemd lifecycle semantics** — the Preserve bug proves it. Candidates: a house VM-test fixture for "oneshot A writes runtime file → oneshot B (Requires/After) reads it" (catches the class for every future mint/consume pair), or a lint rule flagging RuntimeDirectory without Preserve/Preserve=restart on producer units.
4. **Decision-before-documentation ordering**: I updated queue/library/FEATURES/runbook for the MANUAL go-live first, then automated it away hours later, forcing three rewrites of every surface. When a session is clearly heading toward a design change, defer surface updates until the design settles.
5. **The 18-day dark period is itself the lesson**: an enable-gate whose second half is a MANUAL step needs a queue row at COMMIT time (`50ddba86` shipped none). A grep-gate or checklist for "enable-gated + manual-step" patterns would have caught it — candidate for the pre-commit suite.
6. **Foreign dirty files in a shared tree**: correct handling observed (flag, don't touch), but the dmarc/pipeline edits have now sat dirty across my whole session — parallel sessions leaving work uncommitted for hours keeps the tree permanently unquiescent for everyone's evals.

## f) Up to 50 things to get done next

_Sources: strictly this session's observations (checker output, rows read while editing, my own chain). Harvest disposition per item. Items already queued elsewhere are listed here as pointers, NOT re-queued (no duplicate rows)._

**A. This session's direct chain (harvested/queued already):**

1. Deploy + verify first archival run (both units result=success, docs in paperless) — `blocked:deploy`, queued.
2. **bank-sync-paperless post-deploy smoke probe** in post-deploy-check.sh — `[ready]`, harvested into queue + services.md this session.
3. Archival success-side observability (last-archival-age metric + Gatus) — deliberately not harvested (owner call after first run, c3).
4. Statement dedup policy across inboxclean/bank-sync ingestion paths — blocked on g2.
5. Per-consumer least-privilege paperless token — blocked on g1.
6. Add a one-line rotation drill (`drf_create_token -r admin` → next run re-materializes) to the bank-sync runbook's maintenance cadence — not harvested (runbook already documents it; cadence owner-gated).
7. Fix `docs/todo/services.md` bank-sync row reference to ALSO mention the smoke probe after it ships — keep-alive drift risk, watch.

**B. TODO-system debt (observed via check-todo-system.sh this session — concrete, in ITS output):**
8. Sweep the **58 unharvested §f-bearing status reports** → docs-health HARVEST.
9. Fix the **~63 queue/library drifts** (checker WARN list; several concrete wrong-link rows named: nsfw root-cause row→services.md, avatar row→desktop.md, gc-retention rows→monitoring.md, etc.).
10. Decide `CHECK_TODO_PAIRING=strict` flip after drift cleanup.
11. Decide `CHECK_TODO_HARVEST=strict` flip.
12. Re-queue the rejected/absent-link rows the checker names individually (each is a dropped thread).

**C. Ops blockers visible in rows I touched/read:**
13. Bank-Sync Wise SCA re-approval (user OTP, 618 challenges; keeps deploy smoke red via restart-cumulative counter) — `blocked:user`.
14. **Deploy authority decision** (queue-fired vs user-manual `nix run .#deploy`) — gates EVERY runtime item incl. #1.
15. bank-sync smoke counter windowing (restart-cumulative `sync_errors_total`) — `[ready]`.
16. llama.cpp 0.3.0 mid-load CPU-spin bisect — THE gate for re-enabling llama-rag → paperless RAG.
17. InboxClean `main` OAuth re-consent (Gmail sync dead since 09-04; blocks statement archiving/decryption path).
18. Paperless statement decryption go-live (sops `inboxclean-decrypt.yaml` placeholder-inert) + duplicate cleanup + retro-decrypt.
19. Paperless admin password handover (UI change).
20. Mail relay go-live (user steps; paperless+forgejo mail deferred in mailq until then).
21. Paperless T13: block REST-API password auth at Caddy (owner answer: mobile app or not).
22. Rotate the InboxClean→Paperless API token (user-gated since 2026-09-03).
23. Paperless DRF-token age metric + Gatus check — MORE relevant now: the minted token never rotates on its own.
24. Paperless VM-test regression: first green VM RUN (assertions landed 09-22, PSI-gated).
25. Root-cause InboxClean→Paperless `gmail` tag demote PATCH rejection (80× since 09-06).
26. nsfw-classifier: activation (blocked:deploy) + smoke probe + owner calls + interim-input unpin.
27. geometrikks: smoke probe + ingestion data-plane Gatus check + OIDC fixture persistence (three `[ready]` rows).
28. DMARC fleet follow-ups bundle (TLS-RPT, annotations, flip-time checks).
29. go-nix-helpers own-pinned consumer sweep (4 lock nodes on pre-fix rev).
30. Hot tier: "Hot Tier Mounted" Gatus green + first `discordsync-db-backup` proof + `hot_db_entry_mounted` fold (three queued rows).
31. Forgejo G1 subvolume migration window (flip staged 09-30, owner steps).
32. Boot-mirror: document `boot-mirror-activate` log destination; owed-reboot vs hot-db windows priority call.
33. Scrub catch-up slot owner decision (coverage stale since Sep 21/28; frozen-7 forensics correction).
34. Kill-or-legitimize hermes-cron-resurrected llama-servers (stability row).
35. Mail-wiring PASS status into the paperless runbook monitoring map (`[ready]`, services.md).
36. Paperless scheduled-task failure monitoring + encrypted-tag alert (`[ready]`, closes the 22h UI-only red class).
37. upstream paperless-ngx: empty-vocabulary classifier training should degrade, not FAIL.

**D. Hygiene/polish noticed this session:**
38. Foreign dirty files need their owners to land: `docs/status/2026-09-30_08-06_dmarc-*.md`, `docs/todo/pipeline.md`, untracked `docs/status/2026-10-01_07-16_task-…md`.
39. Fix the `audit-serviceconfig-merge` SELFTEST failing on a clean tree (fixture flagged by its own scanner — pre-commit gate dark, noted in CHANGELOG).
40. Caddy `logDir` placement decision (QLC root, 1.7G, snapshot-pinned) — `[decision]`.
41. Per-vHost access-log roll bounds — `[decision]`.
42. Explicit `servers { protocols h1 h2 h3 }` pin in caddy.nix (5-min change).
43. voice/whisper dns-local exemption removal when voice-agents lands — `[watch]`.
44. Layer classification keys on the `forward_auth` substring — `[watch]`.
45. geometrikks runtime-log lines in the global access.log — `[ready]`.
46. Storage drift rows (docker volume inventory cross-ref, /data composition figure refresh, root-window grep-gate) — named in checker drift output.
47. tq claim/lease markers (anonymous parallel implementer accountability) — pipeline row.
48. Reject flag-shaped tracked filenames at pre-commit + CI — pipeline row.
49. go-taskqueue upstream: `task.reprioritized` journal fact — upstream row.
50. Promote two doctrines to AGENTS.md Critical Rules (multi-agent amend bypass; report-claim surface rule) — rows exist.

**Harvest ledger (self-harvest rule):** #2 harvested into TODO_LIST + services.md at authoring time. #1 was already queued. #3–#7 recorded above with explicit dispositions (owner-gated / not-yet-evidence-backed / documentation-only). #8–#50 are pointers to EXISTING rows or observations owned by other surfaces — deliberately not re-queued to avoid duplicate drift.

## g) Questions I cannot figure out myself

1. **Token posture:** the mint returns the SAME admin DRF token inboxclean already uses — bank-sync archival and inboxclean now share full-admin Paperless access. Do you want a dedicated least-privilege `archiver` paperless user (mint token for THAT user, limited collection permissions), or is shared-admin acceptable on a single-user host?
2. **Dedup precedence:** the same bank-statement PDF can arrive via inboxclean (Gmail attachment) AND bank-sync archival (DB statement export). Paperless `PAPERLESS_CONSUMER_DELETE_DUPLICATES=true` deletes one copy — which path should WIN (i.e., which source's metadata/tags do you want kept), and is a dedup audit wanted after the first bank-sync run?
3. **Deploy + first-run window:** the next deploy activates the archival (Persistent catch-up fires it immediately, within the 30-min jitter). Do you want that bundled into the next routine deploy, or held for a deliberate window (e.g., together with the SCA approval + post-approval restart that also clears the deploy-smoke counter)?

---

_Report authoring per status-report skill; .md override honored per explicit user instruction. No manual commit performed (harness contract) — the auto-commit daemon picks this file up._
