# PapDashboard Adoption Unblocked + Verification Closeout — Status Report

**Date:** 2026-10-08 19:28 CEST
**Scope:** Continuation of [`2026-10-08_15-35_papdashboard-overlay-deletion-session.md`](./2026-10-08_15-35_papdashboard-overlay-deletion-session.md). This session: (1) re-verified the deletion session's artifacts survived daemon commits, (2) caught a stale `result` symlink and re-proved the build+smoke after GC, (3) when the user announced the push landed — verified it and drove the adoption chain from step 1 to step 3 + post-lock toplevel proof. **Deploy is now one sudo window away.**
**Surfaces touched:** `flake.lock` (committed by daemon `f12d5604`), `TODO_LIST.md`, `docs/todo/upstream.md`, PapDashboard `result` symlink. No source code, no deployed state.

---

## a) FULLY DONE

| #  | Item                                                          | Evidence                                                                                                                                                                                                                                                                                             |
| -- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | **Repo recon, both sides**                                    | PapDashboard: HEAD `81201c8`, tree clean, was `ahead 1` (origin `eda3e89`). SystemNix: tree clean, HEAD advanced `808e5c9f`→`b3f4ee46`→`54295257`→`f12d5604` under the daemon — all daemon heuristic commits, none hostile                                                                           |
| 2  | **Prior session's 3 artifacts survived daemon commits**       | Status report committed in `8a62feff`; adoption rows present and drift-free at `TODO_LIST.md:142` + `docs/todo/upstream.md:136` (grep-verified both, byte-identical to authored text)                                                                                                                |
| 3  | **Stale `result` symlink caught**                             | `result` pointed at `/nix/store/h7ambdjx…-papdashboard-415217de…-dirty` — an OLD dirty-tree rev from a previous session. The authoring-time "hermetic build green" store path had been **GC'd**; the claim was unverifiable until re-proven                                                          |
| 4  | **Fresh hermetic probe build (local clean tree @ `81201c8`)** | `nix build .#server` EXIT 0 → `/nix/store/pz4lk6wc41r2fjz3kbb2h64q2gg5n4a3-papdashboard-81201c88b9788ad3fdc14b195dd5b3141056e33c` (prepared-source → go-modules → server, full rebuild, not cache-hit)                                                                                               |
| 5  | **Full smoke re-run against the fresh binary**                | `scripts/smoke.sh --skip-build result/bin/server` — **8/8 suites green, EXIT 0** (HTML pins, services surface, SSE down-flip, fragment round-trip, audit-run collector, unix-socket ingest, socket bearer-auth variant, SSE subscribe→ingest→list→lifecycle). Local ports 18333/18334 only, non-prod |
| 6  | **Push landed and full-rev verified**                         | `git fetch` → `origin/master = 81201c88b9788ad3fdc14b195dd5b3141056e33c` (user announced it; independently verified — never trust output text alone)                                                                                                                                                 |
| 7  | **Probe-before-lock (chain step 2)**                          | `nix build github:LarsArtmann/PapDashboard/81201c88…#server --no-link` EXIT 0 — store path **BYTE-IDENTICAL** to the local build (`pz4lk6wc…`). The pushed tarball is cryptographically the same content that passed smoke twice                                                                     |
| 8  | **flake.lock updated (chain step 3)**                         | `nix flake lock --update-input papdashboard`: `eda3e89` (2026-10-07T11:14:34Z) → `81201c88`. 6-line surgical diff; daemon committed it as `f12d5604` (verified `git show --stat`: exactly 1 file, nothing swept in)                                                                                  |
| 9  | **Post-lock toplevel build**                                  | `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --no-link --keep-going` EXIT 0 — eval green with the new input, FOD closure resolves, system links. Lock is deploy-ready                                                                                                        |
| 10 | **Queue rows advanced, both surfaces, no drift**              | `TODO_LIST.md` + `docs/todo/upstream.md`: `[blocked:push]` → `[blocked:deploy]`, chain steps 1–3 marked DONE with store-path + commit-hash evidence, REMAINING = steps 4–6. Verified: 0 stale rows, 1 new row per surface                                                                            |

## b) PARTIALLY DONE

| # | Item                                         | State                                                                                                                                                                                 |
| - | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Adoption chain (6 steps)**                 | Steps 1–3 DONE + post-lock toplevel proof. Steps 4–6 (deploy → flip post-deploy-check probe → flip morning docs) remain — deploy needs the user's sudo window and timing answer (Q3)  |
| 2 | **Report obligations for the 15-35 session** | Its §g questions remain open (see §g); its chain row is now `[blocked:deploy]` with 3 of 6 steps banked. Its "deploy timing" question was never answered — the push event overtook it |
| 3 | **This session's own close-out**             | Complete with this report; HARVEST ledger at bottom: zero new queue rows owed (everything is already queued, user-gated, or ledgered below)                                           |

## c) NOT STARTED

| # | Item                                                                                                                                    | Why not started                                                                                                                     |
| - | --------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Deploy evo-x2 with the new lock** (chain step 4)                                                                                      | Sudo window + user timing decision (Q3)                                                                                             |
| 2 | **Flip `scripts/post-deploy-check.sh` `/api/services` probe 401→200** (step 5)                                                          | Sequenced AFTER deploy by doctrine — flipping early would false-PASS a broken deploy                                                |
| 3 | **Flip morning docs back to auth-less model** (step 6): `docs/services/papdashboard.md`, `FEATURES.md` row, `papdashboard.nix` comments | Sequencing doctrine: docs describe the DEPLOYED state until adoption deploys                                                        |
| 4 | **Key rotation** (`papdashboard_api_key`)                                                                                               | Conditional on Q1 ("was the Oct-6 16:50 failed login you?"); runbook already exists upstream at `docs/runbooks/api-key-rotation.md` |
| 5 | **Pocket-ID group restriction on external `dash` vhost**                                                                                | Awaiting Q2 decision                                                                                                                |

## d) TOTALLY FUCKED UP

**Nothing this session.** Near-misses caught before they became damage (details in §e):

1. **Stale `result` symlink** — one step away from citing a GC'd, pre-deletion rev (`415217de-dirty`) as if it were the authoring-time verification. Caught by reading the store path name before citing it.
2. **"9 suites" miscount** — an interim message said the smoke re-run was "all 9 suites"; the transcript shows **8** named suites. Corrected here; the canonical count is 8.
3. **Three mid-edit file races** on shared surfaces (daemon committing my files; a parallel session touching `upstream.md` mid-multiedit) — all handled by content-pin + re-read + byte-identical verification before re-apply. No lost work.

**Noticed, not mine, flagged:** gatus-coverage-audit advisory on **port 8850** (`inboxclean-sync`, `inboxclean-web`, `llama-chat` referenced, never probed) printed during the toplevel build — non-blocking (EXIT 0); it tracks the parallel session's `9e19dff2` llama-chat/InboxClean work. Left for that session per shared-tree rules.

## e) WHAT WE SHOULD IMPROVE

1. **Build-verification claims must record the store path.** The prior session closed with "hermetic `nix build .#server` green" — uncorroboratable hours later because GC ate the path. This report records `pz4lk6wc41r2fjz3kbb2h64q2gg5n4a3` so any later session can `nix path-info` it in one command. Candidate one-line doctrine for AGENTS.md → "Consuming-Flakes" (deliberately not harvested — see ledger).
2. **Count evidence from the transcript, not memory.** The "9 suites" slip happened because I summarized from recollection. The report's evidence table re-counts from the actual output headers.
3. **"Await user answers" was too passive.** After the push landed, chain steps 2–3 + toplevel proof were agent-safe and answer-independent — banking them converted "waiting" into "one sudo window away". Prep-ahead-of-answers is the default posture for gated chains.
4. **`result`-symlink staleness is a recurring footgun** (nix GC + result symlinks silently diverge). A `nix path-info "$(readlink result)"` check before citing any prior build — or a note in PapDashboard's AGENTS.md — would systematize the catch.
5. **Parallel-session race discipline held under fire** (3 races, zero lost work). Keep edits atomic: content-pin → edit → immediate verify, re-read on any "modified since read".

## f) Up to 50 things we should get done next

_Cap-50 respected, not padded — 25 real items; everything beyond this lives in the domain libraries. Tags: [queued N] = already in TODO_LIST/domain library (no new row needed); [gated Qx] = user decision; [new] = this report, harvest reason in the ledger._

**Tier 1 — finish the adoption chain (the only deployment-critical work):**

1. Deploy evo-x2 with lock `81201c88` — sudo window (`nix run .#deploy`) [gated Q3; queued upstream.md:136 step 4]
2. Flip `scripts/post-deploy-check.sh` `/api/services` probe 401→200 (will false-FAIL otherwise) [queued upstream.md:136 step 5]
3. Flip 2026-10-08 morning docs back to auth-less: `docs/services/papdashboard.md`, `FEATURES.md`, `papdashboard.nix` comments [queued upstream.md:136 step 6]
4. Post-deploy smoke: `dash.home.lan` render (overlay GONE), `/api/health` 200, Gatus ingest 200, services.json drift metric green [queued upstream.md:90]
5. If still no login overlay post-deploy: verify no stale client session asserts otherwise — assert WHICH surface serves the request (2026-08-31 rule) [new, rides step 4 — deliberately not a separate row]

**Tier 2 — user-gated decisions (block Tier-1 variants):**

6. Q1: Oct-6 16:50 failed login — user or unknown? If unknown → rotate `papdashboard_api_key` BEFORE deploy (sops; upstream runbook `docs/runbooks/api-key-rotation.md`) [gated Q1]
7. Q2: restrict external `dash` vhost to a Pocket-ID group? [gated Q2]
8. Q3: deploy now (prioritized) or normal queue? [gated Q3]

**Tier 3 — upstream PapDashboard (adjacent debt, all previously ledgered):**

9. Repair-or-retire PapDashboard CI (dead since 2026-07-15) + decision recorded in upstream.md:90 [queued]
10. Daemon push-time build gate for PapDashboard (same unverified channel pushed the 2026-09-30 break AND its fix ~1h apart) [queued upstream.md:90]
11. Codify `_local_deps`/nix-sandbox test gotcha into PapDashboard AGENTS.md [queued upstream.md:90]
12. Sweep LarsArtmann repos for the `_local_deps` tree-walking-test class (browser-history, CV, go-cqrs-lite candidates) [queued TODO_LIST.md:401]
13. papdashboard OTel span instrumentation upstream [queued TODO_LIST.md:399 / upstream.md:89]
14. 53 latent golangci findings in untouched PapDashboard packages (a2ui/auditruns/fragments/auditbridge/auditsocket/bus_race) — watch, upstream backlog [deliberately not harvested, prior report §81]
15. Identify the 30s `:8099` `/health` poller (NOT gatus-config.nix) [queued TODO_LIST.md:291]
16. 4-repo trace-gap decision: queue real instrumentation vs. keep passive budget debt [queued upstream.md:62, decision]

**Tier 4 — repo hygiene / watch (this session's direct observations):**

17. Store-path-in-verification-claims doctrine into AGENTS.md Consuming-Flakes [new — ledger item 1]
18. `result`-symlink GC check habit / PapDashboard AGENTS.md note [new — ledger item 4]
19. Watch: gatus port-8850 advisory (inboxclean-sync/-web/llama-chat unprobed) — owner: the parallel llama-chat/InboxClean session [new, not mine — no row filed from this session]
20. SystemNix daemon push: local is ahead 11+ of origin (incl. `f12d5604` lock + 2 queue rows) — normal batched behavior, verify landed before any external consumer relies on it [watch, no row]

**Tier 5 — broader, noticed while verifying (pre-existing queue entries, untouched):**

21. Service-completeness manifest audit (service ⇒ gatus + tile + backup + docs) [queued TODO_LIST.md:516]
22. Upstream the 11+ stale self-vendorHashes from the 2026-10-01 blanket lock wave [queued upstream.md:95]
23. a7868a7-wave upstream re-pin sweep (~20 shims) [queued upstream.md:113]
24. Verify upstream CI green for the 2026-10-07 vendorHash paste pushes (bank-sync, InboxClean) [queued upstream.md:123]
25. After deploy: open-new-terminal discipline + post-deploy check run (AGENTS.md Build & Deploy) [standing rule, rides item 1]

## g) Questions I cannot figure out myself

1. **Was the 2026-10-06 16:50 failed `dash.home.lan` login you** (wrong key typed during your overlay fight) **or an unknown client?** If unknown → I rotate `papdashboard_api_key` (you paste the new value interactively into sops — never inline) before the deploy.
2. **Restrict the external `dash.larsartmann.cloud` vhost to a Pocket-ID group** (e.g. `admins`) instead of "any authenticated identity"? LAN stays bypass-only either way.
3. **Deploy timing:** run the sudo window now (everything is pre-verified: probe, lock, toplevel all green), or let it ride the normal deploy queue?

---

## Harvest ledger (doctrine: self-harvest §f direct follow-ups at authoring time)

- **Items 1–8, 9–16, 21–25:** already queued with pointers — harvesting again would duplicate rows (anti-pattern: queue/library drift).
- **Items 6–8:** user-gated — deliberately NOT harvested (tq pool harvests `[ready]` only; gated work is excluded by design).
- **Items 17–18 [new]:** one-line doctrine improvements; deliberately not queued — they are AGENTS.md/AGENTS-adjacent edits awaiting an owner nod, recorded here so they are not lost. On a nod they are 2-minute edits.
- **Item 19:** another session's live work; this session has no authority to file rows against it — flagged here and in the final message instead.
- **Item 20:** watch-only; the adoption chain's own step-1 verification already covers the PapDashboard half.
- **Item 14:** re-states the prior report's explicit not-harvest decision (§81 of the 15-35 report) — unchanged.

## Timeline (all 2026-10-08 CEST)

| Time         | Event                                                                                       |
| ------------ | ------------------------------------------------------------------------------------------- |
| 15:34:47     | `81201c8` committed in PapDashboard (deletion, single squashed commit)                      |
| 15:38:57     | Daemon commits prior session's status report (`8a62feff`)                                   |
| ~16:45–17:03 | This session: recon, artifact verification, stale-`result` catch, fresh rebuild + 8/8 smoke |
| ~17:03       | User announces push landed; `origin/master = 81201c88…` full-rev verified                   |
| ~17:05       | github: probe EXIT 0 — store path byte-identical to local build                             |
| ~17:07       | Lock `eda3e89` → `81201c88`; daemon commits it (`f12d5604`)                                 |
| ~17:09       | Post-lock evo-x2 toplevel build EXIT 0                                                      |
| 17:10–17:12  | Queue rows updated both surfaces (2 file-races re-read + re-applied)                        |
| 19:28        | This report                                                                                 |
