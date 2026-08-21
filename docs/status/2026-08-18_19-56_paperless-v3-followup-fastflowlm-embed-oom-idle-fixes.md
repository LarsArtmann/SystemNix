# Paperless v3 Follow-up: FastFlowLM Embed Revert, OOM Storm, Idle-Check Fixes, PG Bootstrap

**Session:** 2026-08-18 ~17:45–19:56 (resumed the paused 17-44 paperless session)
**Host:** evo-x2 · **Branch:** master · **Baseline:** commits `ca6dd474` + `7e28b6e1` (prior session), then this session's work tree-committed by the auto-commit daemon (bank-sync and other concurrent-session files also in tree)

---

## Mission (this session)

Resume the paused paperless v3 "superb" upgrade at its two unresolved post-deploy failures: (1) FastFlowLM `:52625` unreachable — suspect `loadEmbed = true`, (2) Pocket ID SQLITE_BUSY/panic. Then finish live verification, functional proof, and docs.

---

## a) FULLY DONE (verified)

1. **FastFlowLM root cause found + reverted — `--embed 1` breaks the main model.** Journal proof: with `loadEmbed`, flm loads embed-gemma, then the Qwen 13.6 GB model fails `xrt::ext::bo` mmap / `DRM_IOCTL_AMDXDNA_CREATE_HWCTX` with ENOMEM, and flm **starts the server WITHOUT the default model** (silent partial degradation). First observed run even loaded _only_ the embed model. Reverted `loadEmbed` in `platforms/nixos/system/configuration.nix`; removed `PAPERLESS_AI_LLM_EMBEDDING_*` from `paperless.nix` with a full explanatory comment. Verified in paperless source (`paperless/config.py:239`): `llm_index_enabled = ai_enabled AND llm_embedding_backend` — unset backend disables RAG/semantic index only; AI classification/tagging keeps working. Clean degradation, no error path.
2. **Pocket ID: deploy-IO collateral, self-recovered, no action.** All SQLITE_BUSY/actor-panic errors cluster exactly in the 16:15–16:28 deploy window; zero errors since 17:00; background jobs green; OIDC discovery `https://auth.home.lan` → HTTP 200. Known collateral class (same-filesystem IO storms), already documented in AGENTS.md.
3. **Deploy #2 shipped (19:08)**: loadEmbed revert + paperless bootstrap fix + fastflowlm OOM resilience. Verified in `/etc/systemd/system/fastflowlm.service`: `OOMScoreAdjust=300`, `RestartSec=60`, `Restart=on-failure` live. Post-deploy smoke: **44 PASS / 1 FAIL** (was 44/2 at pause; remaining FAIL was the paperless bootstrap itself, fixed by this same deploy — see #4).
4. **Paperless PG bootstrap root-caused + fixed + verified live.** The nixpkgs scheduler preStart gates `manage.py migrate` on `${dataDir}/src-version` and `manage_superuser` on `${dataDir}/superuser-state`. BOTH files survived the sqlite→PG engine swap with matching values (same package version, same password) → fresh PG DB got no tables and no admin → scheduler crash-looped `UndefinedTable: relation "auth_user" does not exist` → start-limit-hit → web/consumer/task-queue failed as dependencies. The `paperless-sqlite-to-pg-migration` oneshot now drops BOTH files (still Condition-gated on legacy `db.sqlite3`, still self-neutralizing). Live-verified after deploy: migrate ran, all 4 paperless units up, celery beat dispatching, login page HTTP 200 with `Paperless-ngx sign in` body. Tika `:9998/` → 200; Gotenberg `:3199/health` → 200.
5. **OOM storm forensics (18:04–18:11) + resilience fix (deployed).** Kernel OOM dump: flm's 22.5 GB cold load got OOM-killed 4× in 6 min during the deploy window; each 5s-restart re-faulted ~22 GB from disk into an exhausted machine; the kernel killed user-session services (pipewire-pulse, dbus-broker, dconf — oom_score_adj 200) instead of the actual pressure source. Fix deployed: flm is now the _preferred_ global-OOM victim (`OOMScoreAdjust=300` — stateless, socket-activated, self-heals on next connection; the desktop must never be the victim) + `RestartSec=60` (a 5s restart of a 22.5 GB cold load is an I/O bomb). Also proven: post-storm `CREATE_HWCTX ENOMEM` was transient driver-level exhaustion, not a wedge (6th attempt loaded fine; 24 GB shmem released cleanly on stop).
6. **Gotenberg OTel root-caused (fix committed, NOT deployed).** Gotenberg 8.36 ships an always-on OTel autoexport metrics uploader defaulting to `https://localhost:4318` (TLS-vs-plaintext error every 60s). Read upstream `pkg/gotenberg/internal/otel/otel.go`: it uses otel `autoexport`, which parses the endpoint as a URL — schemeless `localhost:4318` (the usual Go otlphttp form, and the house convention) parses as scheme "localhost" → posts to `https:///v1/metrics` ("no Host in request URL"). Correct value for THIS consumer: `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318` (WITH scheme). This is a deliberate exception to the house bare-host:port rule — documented in the module comment.
7. **fastflowlm idle-check: two real bugs found (fix committed, NOT deployed).** Live incident 19:20: idle-check killed a backend 2.5 min into a cold load (socat SIGTERM mid-request). (1) `ActiveEnterTimestampMonotonic` is an ABSOLUTE monotonic timestamp, not an age — the `[ "$active_us" -lt 600000000 ]` 10-min guard never fired on any host with >10 min uptime. Fixed: compute `now_us` from `/proc/uptime` and compare the real age. (2) During cold load the backend hasn't run its accept loop, so backlog-queued connections leave NO "TCP connection established" journal lines — the journal grep alone sees "idle". Fixed: early-exit while ANY `fastflowlm@*.service` instance is active (a live instance = live connection, queued or served — the only reliable cold-load guard).
8. **post-deploy-check.sh: Paperless section added** (enable-gated): login-page body check (`Paperless-ngx sign in` — functional, catches the start-limit-hit class), tika.service active check, Gotenberg `/health` probe. `bash -n` clean. Would have caught the PG bootstrap failure within one deploy.
9. **Docs updated** (all committed to tree by daemon):
   - `AGENTS.md`: new dedicated **Paperless-ngx (v3)** section (PG bootstrap trap, AI wiring + UI-over-env gotcha, no-embed rationale, Tika/Gotenberg + OTel scheme exception, v3 features, monitoring, old-data status); 4 new FastFlowLM bullets (`--embed 1` broken, OOM resilience, idle-check bugs); trimmed the pool-section paperless bullet to a pointer.
   - `FEATURES.md`: paperless row rewritten for the v3 config.
   - `CHANGELOG.md`: 1 Added (paperless v3 superb config), 3 new Fixed entries (FastFlowLM compound bugs, paperless PG bootstrap, gotenberg OTel).

## b) PARTIALLY DONE

1. **FastFlowLM E2E through `:52625` — still failing live, but fully diagnosed.** Two probes at 19:51–19:56 both failed, each by a DIFFERENT already-known killer: attempt 0 died at 76 s to an **OOM-kill** (19:53:10 journal: `Failed with result 'oom-kill'` — the machine is genuinely too full: 78/93 GiB used, swap 22/28 GiB, llama-server 7.5 G + PMA 5.3 G resident; ~15 GiB available vs a 22.5 G peak cold load); attempt 1 died at 171 s to the **old (still-deployed) idle-check** (stopped at 19:56:02, 3 min into load #2 — exactly the bug fixed in the tree). Both fixes (idle-check + RestartSec/OOMScore already live) need the pending deploy; the OOM side additionally needs memory headroom (see questions).
2. **Final deploy blocked by a concurrent session.** `nix flake check --no-build` fails at `systems/evo-x2.nix:75`: `inputs.bank-sync.nixosModules.default` — attribute missing (the bank-sync session's WIP flake input; earlier in the session their module file was mid-edit and also broke eval; both self-healed over time except this one). The undeployed batch: idle-check fix, gotenberg `http://` endpoint fix, post-deploy-check paperless section. NOT my file to fix (concurrent-session race rules).
3. **VM test re-run** — blocked by the same flake eval failure (test itself unchanged; paperless env changes removed only embedding vars the test never asserted).

## c) NOT STARTED

1. **Paperless functional proof**: consume a real PDF (OCR deu+eng → `{{ created_year }}/{{ correspondent }}/{{ title }}` layout), AI classification/tag smoke, `.docx` via Gotenberg, `.eml` via Tika, trash delete/restore.
2. **`nix build .#checks.x86_64-linux.scripts`** (post-deploy-check change) — blocked by flake eval.
3. **Old SQLite cleanup**: `/mnt/pool/services/paperless/db.sqlite3*` still present (migration oneshot still armed — harmless, by design). Remove after PG proves stable ≥1 day.
4. **Dedicated embed-only flm instance** for paperless RAG (researched: `flm serve embed-gemma:300m --port X` is architecturally possible; not attempted — only worth it if the user wants RAG).

## d) TOTALLY FUCKED UP (honest accounting)

1. **The `loadEmbed = true` change (prior session) broke FastFlowLM for all three consumers** (PMA auto-commit, PapDashboard enricher, paperless AI) on the assumption "embed co-loads safely" — unverified at the time. Root-caused and reverted this session, but the endpoint was degraded from ~16:22 to ~19:08 (and is STILL not reliably serving — see b.1/b.2).
2. **Gotenberg fix took two rounds because I applied the house convention (bare host:port) before reading upstream code.** The autoexport URL-parsing behavior is upstream-documented in source; one `fetch` of `otel.go` before the first edit would have shipped the correct value on deploy #2. Current live state: gotenberg logs the WRONG error (`no Host in request URL`) every 60 s until the pending deploy lands.
3. **I raced a known-buggy timer.** I diagnosed the idle-check kill at 19:20, could not deploy the fix (flake blocked), and still ran two more E2E probes at 19:51–19:56 against the OLD script — attempt 1 died exactly at the 19:55:43 tick. Additionally attempt 0 burned a 76 s cold load into an OOM (memory pressure was visible in `free` beforehand — 78/93 GiB used). ~10 min of NPU/disk churn for data I already had.

## e) WHAT WE SHOULD IMPROVE (systemic)

1. **Verify new integrations immediately at the smallest scope.** `loadEmbed` should have been probe-tested (`/v1/models` + a generation) the moment it was enabled — before it rode a deploy that three other services depend on. The socket-activation smoke in post-deploy-check is the only gate that caught it, one deploy late.
2. **Read the consumer's SDK parsing rules before setting endpoint-shaped env vars.** House conventions (bare host:port for Go) describe _code-configured_ SDKs; autoexport/URL-parsing consumers need schemes. The otel-endpoint-audit module could grow a `url-parser` expectation type to encode this class.
3. **The flm "server-up-but-model-dead" partial degradation is under-gated.** The smoke checks `"data"` in `/v1/models` — unverified whether that catches a missing default model. Strengthen: assert the configured model NAME appears in the response body.
4. **Idle/OOM interplay makes `:52625` availability a function of machine memory pressure.** With llama-server + PMA resident, a 22.5 G cold load only fits when the machine is quiet. Options: memory ceilings on the big user-session AI processes, or accept flm as best-effort under pressure (current design intent — OOMScoreAdjust=300 encodes it).
5. **Deploy-blocked queues grow silently.** Three verified fixes sat undeployed for ~40 min behind another session's WIP. Worth a convention: sessions owning eval-breaking host imports (bank-sync in `systems/evo-x2.nix`) keep them committed-green or gate them behind `enable`.

## f) NEXT — up to 50, in priority order

1. ~~Poll `nix flake check --no-build` until the bank-sync session unblocks evo-x2 eval~~ done (unblocked — checks green through the 08-18 sessions)
2. ~~Deploy the pending batch (idle-check fix, gotenberg `http://` fix, post-deploy-check section)~~ done (deployed by the 20-52 session (gen 690))
3. ~~Verify gotenberg journal clean of OTel errors (60 s window) post-deploy~~ done (gotenberg OTel metrics land in SigNoz, errors gone (CHANGELOG entry))
4. ~~E2E fastflowlm probe again — fresh, timed right after an idle-tick, with memory headroom visible~~ done (E2E green in the 20-52 deploys)
5. Verify `/v1/models` response actually contains `qwen3.6-moe:35b-a3b` (gate strength — see e.3)
6. ~~If OOM recurs on cold load: quantify headroom needed; consider llama-server ceiling (user decision — it's theirs)~~ done (mitigations deployed (OOMScoreAdjust=300, RestartSec=60); no recurrence since)
7. Verify PMA auto-commit resumes LLM usage (journal: heuristic-fallback gone)
8. Verify PapDashboard enricher end-to-end (trigger a test Gatus alert)
9. `nix build .#checks.x86_64-linux.scripts`
10. Re-run paperless VM test post-unblock
11. Paperless: consume a real German PDF → OCR deu → check filename layout
12. Paperless: AI suggestion smoke (classify/tag/title on the consumed doc)
13. Paperless: `.docx` consume via Gotenberg
14. Paperless: `.eml` consume via Tika
15. Paperless: trash delete → dir → restore round-trip
16. ~~Gatus: confirm "Paperless", "Paperless Tika", "Paperless Gotenberg" green ≥1 cycle~~ done (all three paperless Gatus checks deployed and green (20-52 smoke 53 PASS))
17. Ask user the 3 pending questions (see g)
18. After PG stable ≥1 day: `rm /mnt/pool/services/paperless/db.sqlite3*` (neutralizes migration oneshot)
19. Decide old-export fate (`/mnt/pool/services/paperless/export`): import or discard
20. If RAG wanted: dedicated embed-only flm instance on its own port + re-add `PAPERLESS_AI_LLM_EMBEDDING_*`
21. Strengthen post-deploy flm smoke (model-name assertion) per e.3
22. Consider a fastflowlm idle-check unit test (the script is pure shell — cheap shellcheck + fixture test)
23. Consider otel-endpoint-audit `url-parser` expectation type (autoexport consumers)
24. Monitor swap pressure (22/28 GiB) — machine runs hot; revisit zram sizing only if OOMs recur
25. ~~Update TODO_LIST.md with any of the above that become owned tasks~~ done (docs-health pass 2026-08-18)
26. Watch pocket-id SQLITE_BUSY recurrence (only if discordsync-style IO storms return)

## g) QUESTIONS (cannot figure out myself)

1. **Memory priority on evo-x2**: the fastflowlm cold load needs ~22.5 G peak and currently OOMs because the machine runs at 78/93 GiB + 22/28 GiB swap (your `llama-server` 7.5 G + PMA 5.3 G resident). Should flm stay best-effort (current design: preferred OOM victim, works when the machine is quiet), or do you want a guaranteed slot (e.g. MemoryMax on llama-server / running it on demand)?
2. **Old paperless data**: the pre-PG SQLite DB held one synthetic test doc; the pool-side `export/` has the full export. Import via `document_importer`, or discard and start clean on PG?
3. **Barcode + e-mail consume**: keep `ENABLE_BARCODES`/`ENABLE_ASN_BARCODE` on (assumes your scanner emits PATCHT/Code-39 — false-positive splits are possible if not), and do you want e-mail consumption wired (needs an IMAP account + sops creds)?

---

## State at stop

- **Paperless: fully live and healthy on PG** (all 4 units, login 200, Tika/Gotenberg 200, Gatus checks in place).
- **FastFlowLM: fixes committed, final deploy pending** on the concurrent bank-sync session; live endpoint still flaky (OOM + old idle-check deployed).
- **Tree: committed by daemon** (docs + all fixes); no uncommitted work of mine.
- **Stopped, awaiting instructions.**
