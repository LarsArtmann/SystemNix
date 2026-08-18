# Paperless-ngx v3 "Superb to the Max" Upgrade — Full Status Report

**Date:** 2026-08-18 17:44 CEST
**Session task:** "Make sure our Paperless is setup SUPERBLY to the MAX for the latest version! Start with private-cloud, then improve."
**System state at session end:** DEPLOYED (second deploy switched cleanly), post-deploy smoke **44 PASS / 2 FAIL / 7 SKIP / 1 WARN** — the 2 FAILs are unresolved and listed under (d).

---

## Context & Ground Truth Established

| Fact | Value | Source |
|---|---|---|
| Latest paperless-ngx | **v3.0.5** (2026-08-01) | GitHub releases |
| SystemNix package | **3.0.5 already** (nixpkgs `2fcb964`) | `nix eval ...package.version` |
| v3 headline features | Tantivy search, **Paperless AI** (LLM suggestions/chat/embeddings), trash, doc versions, share links, remote OCR | settings.py + release notes (read from the installed package source — docs.paperless-ngx.com 403s fetches) |
| Private-cloud heritage | PG via unix socket, OCR deu+eng, Berlin TZ, filename format, 2 workers, ZFS storage | `/home/lars/projects/private-cloud/nixos/hosts/onprem/nixos-0/services/native-apps.nix` |
| FastFlowLM auth | **None** — no Authorization handling in the binary; dummy API key is safe | binary grep |
| Embedding model | `embed-gemma:300m` → `Embedding-Gemma-300M-NPU2`, in flm catalog | `model_list.json` |

**Conclusion:** "latest version" was already pinned; the work became *configuring v3 superbly* — AI on the NPU, PostgreSQL, Tika/Gotenberg, trash, barcodes, monitoring, tests.

---

## a) FULLY DONE ✅

1. **Full research chain** — private-cloud setup read; SystemNix baseline read; nixpkgs module source read end-to-end (database.createLocally, configureTika, exporter, secret-key service, trash tmpfiles, superuser-state guard); paperless 3.0.5 `settings/__init__.py` full env-var surface extracted (all ~180 `PAPERLESS_*` vars); `paperless_ai/{client,embedding,chat,ai_classifier}.py` read to confirm the openai-like path, prompt-injection system prompt, and embedding fallbacks.
2. **`modules/nixos/services/paperless.nix` rewritten** (committed `ca6dd474` + `7e28b6e1`):
   - **PostgreSQL backend** (`database.createLocally = true`) — shared instance with Immich, peer-auth unix socket, no DB password anywhere.
   - **Tika + Gotenberg** (`configureTika = true`) — Office documents and e-mail consumable.
   - **Paperless AI live on the NPU**: `openai-like` → `http://127.0.0.1:52625/v1`, model `qwen3.6-moe:35b-a3b` (derived from `config.services.fastflowlm.model`), dummy API key (FastFlowLM ignores auth), 300s request timeout (cold-load aware), embedding backend `embed-gemma:300m` on the same endpoint.
   - **Trash**: `PAPERLESS_TRASH_DIR` + tmpfiles rule, 30d purge (nightly celery task).
   - **Filename format**: v3-native `{{ created_year }}/{{ correspondent }}/{{ title }}` + `REMOVE_NONE`.
   - **Barcode consume**: PATCHT separators, Code-39 ASN, recursive subdirs.
   - Hygiene: `ENABLE_UPDATE_CHECK=false`, `TASK_WORKERS=2`.
   - **Resource layering**: tika+gotenberg get `ioTier.background` + 2G MemoryMax + CPUQuota + start limits + onFailure; paperless-web MemoryMax 1G→2G.
   - **`paperless-sqlite-to-pg-migration` oneshot**: drops `superuser-state` while `db.sqlite3` exists so the admin bootstrap re-runs against the fresh PG DB (otherwise NO superuser = no login). Self-neutralizing via ConditionPathExists.
3. **Port registry** — `lib/ports.nix`: `tika = 9998`, `gotenberg = 3199` (3199 chosen; gotenberg's nixpkgs default 3000 collides with forgejo).
4. **`loadEmbed = true`** on fastflowlm (`configuration.nix`) + `flm pull embed-gemma:300m` executed (620 MB, relocated to `/data/ai/models/fastflowlm/models/` — the CLI defaulted to `~/.config/flm`).
5. **Monitoring wired** — 6 services added to `system-health` monitoredServices (4 paperless units + tika + gotenberg); Gatus: Paperless check now body-verifies `*Paperless-ngx sign in*` (functional, not just 200), NEW "Paperless Tika" (`:9998/`) and "Paperless Gotenberg" (`:3199/health`) checks with Discord alerts, 5m interval.
6. **Homepage** tile description updated (OCR, Office/E-Mail, AI, Archive).
7. **VM test** `tests/test-paperless.nix` (registered in `tests/default.nix`): boots the full stack against real PostgreSQL, asserts all 4 units up, sign-in page body, AI/trash/filename/DB env vars in the unit environment, trash dir exists, exporter timer enabled, `paperless` DB + role exist in PG. **PASS** (twice).
8. **Bug caught BY the VM test**: v3 deprecation warning on single-curly filename format → fixed to double-curly (this is exactly why the test exists).
9. **Two pre-existing/adjacent bugs fixed on sight**:
   - `scripts/deploy.sh` shellcheck SC2086 (unquoted `$wedged` in `sudo kill`) — was **blocking every deploy build**; fixed with a proper loop. (My first edit attempt mangled the file — joined two lines — caught on review and fixed correctly.)
   - `scripts/pre-deploy-check.sh` phantom-metric extractor: human-text body patterns (e.g. `pat(*Paperless-ngx sign in*)`) extracted `Paperless` as a "metric" → **hard deploy block**. Root-caused (Prometheus metric names are lowercase) → extractor now drops uppercase candidates. Verified the extraction output is clean.
10. **Verification gates**: `nix flake check --no-build` passed 3× (incl. all assertions — `toplevel.drvPath` eval does NOT check assertions); VM test built green 2×; evo-x2 evals of settings + migration unit confirmed correct.
11. **Deploy executed** (second attempt after the two blocks above): switch completed, 175 ExecStart binaries verified, post-deploy smoke ran: 44 PASS.

---

## b) PARTIALLY DONE ⚠️

1. **Live verification of the new stack** — deployed but NOT verified: paperless units' post-switch state, admin login against PG, the migration oneshot's actual run, Tika/Gotenberg responding, Gatus' three checks green. The post-deploy smoke covers none of these (paperless isn't in it; see (f) #5).
2. **Documentation** — explicitly deferred "until live-verified", and live verification never happened: AGENTS.md Paperless section still describes the old sqlite setup; FEATURES.md row stale; CHANGELOG entry missing. The auto-commit daemon committed the CODE (good) but the docs debt is real.
3. **AI end-to-end** — config + model pull done; an actual suggestion request, chat query, and embedding call (`/v1/embeddings`) have NOT been exercised. Blocked by the FastFlowLM failure below.
4. **Data continuity sqlite→PG** — the superuser bootstrap is handled (oneshot), but the old SQLite *content* (the single 2026-08-17 verification document + its metadata) is NOT in the fresh PG DB. Recoverable from `/mnt/pool/services/paperless/export` (manifest includes the admin user with password hash) via `document_importer`, or disposable. Decision needed (question 1).

---

## c) NOT STARTED ❌

1. AGENTS.md / FEATURES.md / CHANGELOG.md updates (see above).
2. Live consume test on the new stack (PDF → OCR → archive → v3 filename layout on disk).
3. Office/e-mail consume test through Tika+Gotenberg (`.docx`, `.eml`).
4. Barcode workflow test (PATCHT split, ASN assignment).
5. Trash lifecycle test (delete → trash dir → restore/30d purge).
6. AI index build (`document_llmindex`) + semantic search + AI chat test.
7. pg_dump backup of the paperless DB (exporter output is the monitored backup; a DB dump would be belt+suspenders like immich's).
8. Homepage tiles / dns / Caddy changes — intentionally none needed (protectedVHost unchanged) — nothing to do, listed for completeness.

---

## d) TOTALLY FUCKED UP 💥 (or potentially so — unresolved at session end)

1. **FastFlowLM `:52625` UNREACHABLE after deploy** (post-deploy FAIL). **Likely caused by MY change** (`loadEmbed = true` → `flm serve … --embed 1`). Blast radius is NOT just paperless: PMA auto-commit and the PapDashboard insight enricher also depend on this endpoint. NOT investigated yet (session stopped per instructions). First move: `journalctl -u 'fastflowlm*' -n 50`, check whether the backend even starts with both models, then `/v1/models` + `/v1/embeddings`. If embed co-load is broken on NPU, revert `loadEmbed` and re-point paperless embeddings (or disable the embedding backend) until fixed.
2. **Pocket ID SQLITE_BUSY/panic in recent journal** (post-deploy FAIL). Unknown: deploy-IO collateral (documented pattern: SQLITE_BUSY spikes during IO storms) vs. real regression. Not investigated.
3. **Process self-inflicted wounds, all caught and fixed same-session** (listed for honesty): duplicate `systemd.services` key eval error; deploy.sh edit mangling; first deploy blocked by my own gatus body pattern tripping the phantom-metric extractor. Net lesson: my changes fed three distinct pipeline layers exactly the kind of edge they exist to catch — the pipeline worked, but each cost a round trip that reading the consumer (extractor, shellcheck gate) beforehand would have saved.

---

## e) WHAT WE SHOULD IMPROVE (systemic, from this session)

1. **Read the gates before feeding them**: shellcheck rules and the pre-deploy extractor are deterministic — 2 of 3 round-trip failures were predictable by reading `scripts/*` before introducing new patterns.
2. **Gaps in the deploy pipeline**: (a) deploy.sh's SC2086 shipped earlier and broke EVERY deploy until touched — the script lint gate should run in CI on scripts/, not only when rebuilt; (b) the post-deploy smoke has NO paperless functional check (login page, consume, tika/gotenberg) despite pre-deploy covering phantom metrics — add one.
3. **`docs.paperless-ngx.com` 403s agents** — reading the installed package source was the right fallback and should be the documented default for any packaged app ("the store path is the docs").
4. **flm CLI model path defaults to `~/.config/flm`** — a `FLM_MODEL_PATH` passthrough for `flm pull` (or a module option wrapping it) would prevent manual 620 MB relocations.
5. **UI-over-env precedence gotcha (undocumented anywhere)**: paperless v3's `AIConfig` resolves `app_config.x or settings.X` — values saved in the web UI (ApplicationConfiguration DB rows) OVERRIDE our env vars. Must be in AGENTS.md or a future session will "fix" env vars that the DB silently ignores.
6. **Engine migrations need a data plan, not just a bootstrap plan** — I handled the superuser but improvised on content (export re-import pending user decision). A checklist item for any DB engine swap: users, content, sequences, settings.
7. **Session hygiene**: I deferred docs past the deploy and then hit FAILs — docs should describe verified state only, which means verify-then-document must be one motion, not two phases that can be interrupted.

---

## f) NEXT — up to 50 things, priority-ordered

**P0 — investigate the two FAILs (now)**
1. ~~`journalctl -u 'fastflowlm*' -n 50` — did `--embed 1` break backend startup?~~ done (YES — embed co-load broke the main model; loadEmbed reverted off (2026-08-18 19-56 session, CHANGELOG entry))
2. ~~Test `:52625/v1/models` E2E (240s cold-load budget); confirm socket + bridge + backend chain.~~ done (E2E green via the 20-52 deploys (post-deploy smoke 53 PASS / 0 FAIL))
3. ~~Test `:52625/v1/embeddings` with `embed-gemma:300m` (does the embed model co-load on NPU?).~~ done (moot — embed co-load reverted; embeddings deliberately OFF (RAG gates on embedding backend))
4. ~~If embed co-load broken: revert `loadEmbed`, keep chat/suggestions (no embeddings), file/triage separately.~~ done (reverted 2026-08-18 19-56 session (CHANGELOG: FastFlowLM embed co-load entry))
5. `journalctl -u pocket-id --since -30min` — SQLITE_BUSY collateral or regression?
6. ~~Verify all 4 paperless units active post-switch (`systemctl`): no crash-loop on PG.~~ done (all 4 units up post-fix (2026-08-18 20-52 session))
7. ~~Verify `paperless-sqlite-to-pg-migration` ran once (state file dropped, admin created) — then login at `paperless.home.lan`.~~ done (migrate ran, admin created, login page serves (CHANGELOG PG bootstrap entry))

**P1 — prove the new stack functionally**
8. Decide old-data fate: `document_importer` from export vs discard (question 1).
9. Live consume test: PDF → OCR deu+eng → archived under `{{ created_year }}/{{ correspondent }}/{{ title }}`.
10. AI suggestion smoke on the imported/test doc (expect 1-3 min cold load first).
11. AI chat query in the UI; verify referenced documents render.
12. Build AI index (`paperless-manage document_llmindex`) once embeddings work; semantic search test.
13. Consume a `.docx` (Gotenberg→LibreOffice path) and an `.eml` (Tika path).
14. Delete a doc → appears in trash dir → restore; confirm nightly purge schedule exists in celery beat.
15. Verify Gatus green: Paperless body check, Paperless Tika, Paperless Gotenberg.
16. After PG verified stable ≥ a day: remove `/mnt/pool/services/paperless/db.sqlite3*` (neutralizes the migration oneshot, removes ambiguity).

**P2 — close the session's own debts**
17. ~~AGENTS.md: rewrite the Paperless section (PG, AI wiring incl. dummy-key rationale + embed pull steps, Tika/Gotenberg, trash, filename v3 syntax, UI-over-env precedence gotcha, ports).~~ done (AGENTS.md ### Paperless section rewritten (PG, traps, sops))
18. ~~FEATURES.md paperless row update.~~ done (FEATURES.md paperless row updated 2026-08-18)
19. ~~CHANGELOG.md entry for this upgrade.~~ done (CHANGELOG Unreleased: Paperless-ngx v3 entry)
20. ~~Verify the auto-committed tree matches intent (`git log` audit of `ca6dd474`, `7e28b6e1`).~~ done (commits ca6dd474 + 7e28b6e1 landed)
21. ~~Add paperless login-page check to `scripts/post-deploy-check.sh` (body + status, like gatus).~~ done (post-deploy-check carries the login-body smoke (CHANGELOG smoke entry))
22. ~~Add tika/gotenberg reachability to post-deploy smoke (localhost only).~~ done (tika/gotenberg localhost smoke in post-deploy-check (same entry))
23. ~~Run `.#checks.x86_64-linux.scripts` to confirm the extractor change didn't break test-scripts.~~ done (full checks ran in pre-commit/CI through the 08-18 sessions)
24. CI gap: lint `scripts/*.sh` with shellcheck on every PR (would have caught SC2086 pre-ship).
25. ~~Concurrent-session awareness: `configuration.nix` carries another session's PMA `cachePurgeIntervalSeconds` diff uncommitted + `AGENTS.md`/`ai-stack.nix` modified — do NOT touch or revert; coordinate.~~ done (coordinated — PMA purge landed separately (2bed8fea))

**P3 — hardening & polish**
26. pg_dump timer for the paperless DB → pool (mirror immich-db-backup pattern; exporter is primary, this is belt+suspenders).
27. Watch MemoryMax ceilings under real load (task-queue 2G w/ 2 workers + AI, tika 2G Java heap interplay) — tune on evidence.
28. Tika first-request latency (Java cold start) vs the 2s gatus RESPONSE_TIME — loosen if flapping.
29. Set `PAPERLESS_AI_LLM_OUTPUT_LANGUAGE` (English/German) — currently model-default.
30. Evaluate `PAPERLESS_DB_READ_CACHE_ENABLED` (v3 PG read cache; needs a redis DB).
31. Audit-log growth monitoring in PG (auditlog is on by default, unbounded).
32. Confirm `PAPERLESS_TIME_ZONE=Europe/Berlin` arrives via module (`config.time.timeZone`).
33. Mobile app / external API access through protectedVHost — test or document LAN-only (forward-auth may break app flows).
34. Consider `PAPERLESS_SESSION_COOKIE_AGE` (default 3 weeks) — fine for homelab, decide deliberately.
35. Webhook/post-consume integration with PapDashboard notifications (optional nicety).
36. Add `flm pull` FLM_MODEL_PATH handling (module option or docs) so future models land in `/data` directly.
37. Paperless export → candidate google-sync target once that service goes live (off-site leg).
38. Verify btrbk-pool snapshots now carry the trash dir (deleted docs double-covered by 30d snapshots — document the interplay).
39. VM test: add a consume-file assertion once a fast fixture exists (currently boot+env only — OCR in VM is slow).
40. Consider barcode sanity fixture (PDF w/ PATCHT) as a test asset in-repo.
41. Homepage: decide whether Tika/Gotenberg deserve tiles (currently internal-only — lean no).
42. Document FastFlowLM dependency graph (paperless AI, PMA, papdashboard) in AGENTS.md — one endpoint, three consumers, one blast radius.
43. Re-check `KNOWN_NEW_METRICS` bypass list in pre-deploy-check after new metrics appear.
44. Revisit `system-health` per-service memory thresholds vs the new 2G ceilings (they derive from MemoryMax — confirm derivation picked up the change).
45. Idle-TTL interplay: AI browsing sessions re-wake the 13.6 GB model up to hourly — acceptable, but note the trade-off in AGENTS.md.
46. Paperless e-mail consumption (`PAPERLESS_EMAIL_*`) — needs an account/credentials (question 2).
47. Second paperless user / groups for family access + permissions model (question 3 adjacent).
48. Verify celery beat schedule includes empty-trash + trainer tasks post-migration (journal after a day).
49. Add `docs/status` link from the AGENTS.md paperless section once verified (session narrative).
50. Retrospective: add "read consumer gates before new patterns" to the AGENTS.md workflow canon (generic lesson, cheap insurance).

---

## g) Questions I CANNOT answer myself

1. **Old SQLite data:** the fresh PostgreSQL DB starts empty; the previous state (one synthetic verification document + admin user) is recoverable from `/mnt/pool/services/paperless/export` via `document_importer`. **Import it, or discard as test data?**
2. **E-mail consumption:** v3 can auto-consume from a mailbox (`PAPERLESS_EMAIL_*`). Setting it up needs a real e-mail account + credentials (sops) — **do you want this, and which account?** (I cannot create credentials.)
3. **Scanner reality:** I enabled PATCHT barcode splitting + Code-39 ASN tagging + recursive consume based on private-cloud heritage. **Do you actually use separator sheets/ASN stickers with your scanner — or is this unused noise I should leave off until you adopt a workflow?**

---

## Commit trail (this session)

- `ca6dd474` — feat(paperless): expand document processing and AI capabilities (module rewrite, ports, loadEmbed, monitoring, homepage; batched by the auto-commit daemon with a concurrent session's status doc)
- `7e28b6e1` — fix(paperless): migrate filename format to v3 + bootstrap PG engine swap (double-curly format, sqlite→PG oneshot, deploy.sh SC2086 fix, pre-deploy extractor fix rode along)

**Session stopped here per instruction — awaiting direction. First action on resume should be (f) #1-#4: the FastFlowLM investigation.**
