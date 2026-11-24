# Status: all 4 gen-1017/1018 battery FAILs triaged — qonto-corpus comma bug FIXED (11 stuck docs uploaded + converged), rust-cache link provisioner FIXED, CRM check FIXED, ghostty phantom KILLED (PSI 53→9, llama recovered), takeout mint-loop root-caused as already-fixed

**Session:** 2026-11-20 ~00:00 → 11:45 (owner's standing "execute and verify one step at a time" ladder, resumed from the 22:05 report's report-then-wait state; "keep going" ×4 = the go)
**Scope line:** Verified live: every FAIL from the gen-1017 AND gen-1018 batteries decomposed and dispositioned; two repo fixes + one battery-check fix landed and live-verified; the 3-terminal ghostty phantom killed with PSI collapse + llama recovery; the parallel task-queue session's deploy-riders verified (health-hub 200, immich debris swept); takeout mint-every-boot solved as the same CAP_DAC_OVERRIDE class. NOT done: the three fixes ride the NEXT deploy (deploy-gated riders, no deploy fired this session — corpus + links are already runtime-converged); Wise SCA needs owner action; dnsblockd templ regen still blocked on that repo's ongoing upheaval.

---

## a) FULLY DONE

1. **The 4 battery FAILs — ALL triaged, 3 fixed, 1 owned-elsewhere:**
   - **Bank-Sync `sync_errors_total > 0` = Wise SCA approval PENDING (owner action, no defect):** the daemon WARNs "statements paused pending SCA approval" + "transactions fetched via degraded SCA transfers fallback" across 5 balances. One approval in the Wise app (or `bank-sync sca approve`) opens a ~90-day window and clears the FAIL class. Row: docs/todo/services.md [blocked:user].
   - **Health Hub `/readyz` 503 = FIXED by the parallel session, VERIFIED live:** gen-1018 carried 9345acd87 (nsfw remote dropped from federation); live probe = 200 OK. Their rider f.1 closed. The remaining red contributor (cvagent flap) is owned by the cvagent fix-wave row — cvagent /health flapped 503→200 within the hour, matching its known class.
   - **Kith CRM 303 = CORRECT app behavior, stale check FIXED:** /login 303s to `/auth/oauth/pocket-id/begin` → 302 → `auth.home.lan/authorize` with full PKCE (S256 + nonce + state) — textbook Layer-1 OIDC for an OIDC-only app (since 2026-10-17). The battery's "200 <html on /login" predates that. New check asserts the redirect TARGET (`curl -w %{redirect_url}` must match `^https://auth.$DOMAIN/authorize?`) — stronger than status-code matching, verifies the IdP handoff end-to-end. Live harness: PASS. Commit: daemon-swept 80924438b (message debt noted in d.3).
   - **Service-Sanity CPU = both units explained, neither a defect:** tq-agent-pool 408-412% = the LIVE task-queue agent session working (its crush processes visible in top at 13-25% each now; budget exhausted 30/30, $3.52/day — bounded by design). crm-server 201% = post-deploy restart catch-up, absent from top-10 hours later.
2. **The "6 failed units share one story" hypothesis — DECOMPOSED into 6 distinct causes:**
   - bank-sync-qonto-corpus: THE comma bug (a.3 below) — FIXED.
   - rust-cache-projects-links: XDG_RUNTIME_DIR missing in a system unit — FIXED (a.4).
   - forgejo-github-sync: mirror leg GREEN (465 repos, 0 failed); the unit fails on forgejo-reinterval-mirrors' ONE PATCH — `lars/nixpkks` HTTP 500, "retried next run", 1/482. Row queued [ready].
   - inboxclean-sync: Gmail 429 rate-limit transient — self-healed (23:51 run finished clean).
   - post-crash-calm-gate: REFUSE on phantom PSI (avg10 56% ≥ 40 band) — the gate did its job but exits non-zero, so a designed refusal lands in the failed-units list. Decision row queued (exit-0-with-loud-line vs scan exemption).
   - service-health-check: downstream reporter — fails BECAUSE the others failed (53ms CPU, fires OnFailure→Discord). Self-resolves with the real fixes.
3. **bank-sync-qonto-corpus comma bug — root-caused, fixed, live-converged (the session's deepest find):**
   - Symptom: `failures=11`, `uploaded=0`, exit 1, EVERY run since Nov 17 (deterministic — the same 11 documents).
   - Root cause: **curl's `-F "document=@<path>"` parser cannot read paths containing a comma** — `curl: (26) Failed to open/read local data from file/application` BEFORE any network I/O. Proven by a 5-cell matrix on identical bytes: comma path → 26; no-comma path → 403 (reaches server); comma in `;filename=` override → also breaks; comma in plain value parts (title=) → fine. All 11 stuck docs have commas in merchant names (HOTEL BRISTOL, WARSAW / CIRCLE K WARSZAWA, / GITHUB, INC_ / Rundfunk ARD, ZDF / Daniel Eichenauer, LL_ M_).
   - Fix: comma-carrying sources route through a comma-free symlink in the per-run mktemp dir (`,`/`;` → `_`, matching the corpus's own EUR-amount convention 45_23); `$orig` preserved for honest log lines. Commit: daemon-swept 1f07ec5b8.
   - **Live convergence executed as root with the unit's exact args (immich surgical-heal precedent): 11/11 uploaded (docs 1004851-1004861), failures=0. Idempotence rerun: already_present=1028, uploaded=0, failures=0, rc=0.** The unit goes green on its next run.
4. **rust-cache-projects-links — FIXED + converged:** the provisioner's flock opens under XDG_RUNTIME_DIR, but a SYSTEM unit never exports it (user-session var) → every run since 2026-11-17 died "user unit requires XDG_RUNTIME_DIR". Linger guarantees /run/user/1000 from boot → `Environment = "XDG_RUNTIME_DIR=/run/user/1000"` (uid literal matches the configuration.nix pin; config-derived uid evals null — the pin's own comment; hermes precedent). Verified: eval renders + the exact ExecStart line run as lars converged **13 links, repaired=0 deferred=0, cache 79%**. Commit: a53c4439d (amend-forwarded atomically).
5. **Ghostty phantom KILLED — the box is IO-calm for the first time in ~35h:** three 34.5h-old ghostty monitor terminals (btop / nvtop / **iotop-c** — the IO-storm watcher WAS the fictional IO storm) carried 47-63% io.pressure each while disks sat at 3% busy; system PSI pinned 51-53%. SIGTERM to the three (graceful, dashboard-class, zero data loss; sanctioned by g.2 + "keep going"): scopes cleaned, **PSI avg10 53→45→9 in <60s (app.slice avg10 1.2%)**. Attribution airtight: no ghostty scopes remain, pressure collapsed exactly on the kill.
6. **llama.home.lan outage — ended, then correctly understood:** with PSI calm the psi-wait-gates admitted (29.02% < 30), both the 35B chat and the VLM cold-loaded, `/health` = 200 `{"status":"ok"}`. The later "502 again" was NOT a regression: llama-chat is **socket-activated with idle unload** — my own probe re-triggered a cold start (28.4 GB read, ~10-15 min), and 502 is the designed cold-load window. Storm-class 502 (gate refusing at PSI ≥30, the 10h overnight case) vs cold-start 502 (calm, self-clearing) are DIFFERENT classes — the battery should treat them differently (candidate for the psi-gate row). Systemic fix row queued: psi-wait-gate needs the device-truth crosscheck the deploy entry gate already has.
7. **takeout-import mint-every-boot — root-caused as ALREADY-FIXED:** the env file renders `lars`-owned 0400 (per `owner = "lars"`), and uid-0-inside-the-sandbox WITHOUT CAP_DAC_OVERRIDE cannot read a 0400 file owned by ANOTHER user → sed EACCES swallowed → "file missing" → mint. Same class as the discordsync/media-atlas legs. Journal proof: 12 mints Nov 15-17, then **converged on every run since gen-1017's cap fix** (4/4 runs: 20:54, 21:54, 23:50, 00:51). The 22:05 report's c.3 mystery closed with zero new work.
8. **Prior-session leftovers:** daily.home.lan 200 + collectors finishing clean (crush events collector Finished 11:16:57) — CLOSED. `nix flake check --no-build` = all checks passed, no new warnings — CLOSED. dnsblockd templ regen: repo STILL mid-upheaval (commits through 02:01 last night, templ-components v1.27.1 bump in flight) — stays coordinated-blocked; prior g.3 answered.
9. **Parallel-session riders verified (good-neighbor):** their deploy-gated items rode gen-1018 — health-hub nsfw exclusion live (200), the 5 gen-1010 immich debris files SWEPT (/var/lib/immich-api-keys/ contains only takeout-import.env).
10. **Harvest landed** (3c308f68b, amend-forwarded atomically): 5 rows — psi-wait-gate device-truth [ready], §17 watermark sweep (cvagent 1.1M MemoryHigh headline) [ready], calm-gate REFUSE semantics [decision], Wise SCA [blocked:user], forgejo PATCH 500 [ready]; TODO_LIST queue mirrors ×3.

## b) PARTIALLY DONE

1. **Deploy-gated riders (deliberately not deployed this session):** the comma shim, the XDG fix, and the CRM check ride the NEXT natural deploy. Runtime state is ALREADY converged (corpus 1028/0/0; 13 links live), so the only exposure is NEW qonto attachments with commas arriving before the next deploy (they would fail-and-retry until it lands, then auto-upload). No forced deploy: the battery is 40-80 min of load on a box that just calmed, and function is restored.
2. **llama cold-start 502 vs battery expectations:** the unit self-manages; the battery FAIL on a cold-start window is arguably a false positive (socket-activated idle-unload design). Folded into the psi-gate row's scope, not separately queued.

## c) NOT STARTED

Nothing from this session's ladder. Open items owned elsewhere: cvagent flap + watermark (fix-wave row + new §17 row), Wise SCA (owner), dnsblockd templ (blocked on that repo's quiescence), g.1 boot-origin (owner, prior session).

## d) TOTALLY FUCKED UP (honest ledger)

1. **Permission-blind absence claims — TWICE, against an existing written rule:** `test -e`/`ls`/`find` on the pool corpus (0700-class dirs) returned MISSING/empty with errors swallowed by 2>/dev/null, and I reported "sources missing" + "dir empty" as fact. The AGENTS.md rule ("a swallowed-error read is a failed read, not a zero; name the privilege level") was IN CONTEXT. Caught only when I re-ran `ls` with errors visible. The comma bug was real, but I nearly re-based the diagnosis on a fiction.
2. **Mechanism theories before failure-history:** I burned the mount-bounce and daemon-rewrite-race theories on a 9-second failure window BEFORE grepping the unit's own history — which showed the IDENTICAL failures=11 on every run since Nov 17 (deterministic, not a race). One `journalctl --since 2026-11-17 | grep failures` was the whole triage.
3. **Commit-message debt on two daemon-swept fixes:** 80924438b (CRM check) and 1f07ec5b8 (comma fix) sit as heuristic commits — rewording buried commits needs a rebase that risks the live daemon race; content verified via `git show --stat` (each carries exactly my file). Accepted as history-readability debt rather than colliding the tree.
4. **Background-job timing:** the final llama probe auto-backgrounded mid-report twice — benign, but the cold-load window cost two probe round-trips that a journal read (load progress) would have skipped.

## e) IMPROVE (systemic)

1. **Failure-history-first triage:** for any failing unit, pull its full failure history (`--since <a week> | grep -E 'failures=|Failed with result'`) BEFORE theorizing mechanisms — determinism vs novelty is the cheapest possible classifier.
2. **Absence-claim pre-flight:** before writing "X missing/empty", the reporting checklist needs: did the probe run WITH errors visible, at WHAT privilege, against WHAT ownership. (Rule exists; add the mechanical check.)
3. **curl -F comma trap → shell-devtools.md candidate:** the `-F @path` comma breakage + `;filename=` companion + value-part tolerance is a reusable trap (any script uploading files with human-named paths).

## f) NEXT (ranked, bounded — harvested)

1. Next deploy carries the three fixes (comma shim, XDG env, CRM check) — verify bank-sync-qonto-corpus + rust-cache-projects-links green in its battery and no CRM FAIL.
2. Owner: Wise SCA approval (clears the bank-sync FAIL class).
3. psi-wait-gate device-truth crosscheck row (+ cold-start-502 battery semantics).
4. §17 watermark sweep (cvagent 1.1M).
5. forgejo lars/nixpkgs PATCH 500.
6. calm-gate REFUSE exit semantics decision.
7. dnsblockd templ regen when that repo quiets down.

## g) QUESTIONS FOR THE OWNER

1. **Wise SCA:** approve in the Wise app (or run `bank-sync sca approve`)? It is the ONLY thing keeping the bank-sync battery FAIL alive.
2. **Monitor-terminal kill ratification:** I closed three 34h-old ghostty dashboards (btop/nvtop/iotop) under g.2 + "keep going" — they were the entire phantom PSI source. Confirm this class (idle dashboard terminals) is agent-closable without asking, or stays ask-first.
3. **Prior session's g.1 still open:** did you hard-reset around 00:09 Nov 19? (pstore empty, no shutdown trail — one word closes the stability ledger.)

---

_Session evidence: commits 80924438b + 1f07ec5b8 (daemon-swept fixes, stat-verified) + a53c4439d (rust-cache, atomic amend) + 3c308f68b (harvest, atomic amend); comma matrix probes (5 cells, root); converger run logs (uploaded=11 then 1028/0/0 rc=0); rust-cache provisioner run (13 links); PSI collapse readings (53→9, app.slice 1.2%); llama journal (gate admission 29.02%, socket-activated cold loads ×2, 200 {"status":"ok"}); CRM OIDC chain (303→302→authorize+PKCE) + harness PASS; parallel-report riders (health 200, debris gone); flake check green; deploy logs 2026-11-19_23-47-39.log (gen-1018 exit 3, 179/7/4/20/2)._
