# Pareto Execution CLOSED: T01–T19 Complete, Deploy Train Rode Concurrent Sessions — Self-Review & Full Status

**Date:** 2026-09-03 01:0x (CLI) · **Session:** continuation of "GET SHIT DONE" (directive: "READ, UNDERSTAND, RESEARCH, REFLECT… keep going until everything works")
**Inputs:** `docs/status/2026-09-02_21-15_pareto-execution-tier1-2-code-done-deploy-train-pending.md` (the 3 open questions were superseded by the continue directive; recorded T01 answers governed the gated tasks).

---

## a) FULLY DONE (verified)

| Item | Proof |
|---|---|
| **Deploy train — already gone** | Concurrent sessions ran it: gen **753** switched 21:59 (deploy exit 0, 22:07). All Tier-1/2 code live. My session's job flipped to post-deploy verification + fallout repair. |
| **Live verification chain (gen 753)** | `system_pocket_id_busy_*` LIVE in `:9100/metrics` (events_24h=30, over_threshold=1 — SQLITE_BUSY alert fires TRUTHFULLY, scrape_errors=0); `node_textfile_scrape_error 0`; paperless login 5-conditions green on `localhost:2892`; `/admin` AND `/admin/documents` → **403** (no 301 hop). T03 re-verified post-deploy. |
| **T05 live-proven** | All six evening deploys wrote structured exit records (`deploy exited code=… after Ns`) → `/var/log/systemnix-deploys/*.log` + `journalctl -t systemnix-deploy`. |
| **T07 live-proven** | The re-run smoke printed the NEW pressure verdicts against a real storm: `WARN I/O avg10=61.71% (elevated)` + `PASS memory PSI 1.88%` — the old code called this healthy. |
| **CRITICAL FIX: post-deploy-check app build (deploy blocker)** | The 21:57 deploy's smoke app FAILED its own writeShellApplication shellcheck gate (SC1091: unstaged `lib/pressure-report.sh`; SC2016: mail-relay `_relay_banner`) → gen 753's smoke NEVER RAN. Fixed: sibling-lib staging in flake.nix (mirroring pre-deploy-check) + `disable=` directives + `gawk` runtimeInput. Verified: app builds + the missing smoke completed (84 PASS / 8 FAIL, all FAILs triaged — see c). |
| **T02 closed** | Disposition written into plan §9 annotation: holders (flm 28 GB shmem, 26–27 crush sessions, clickhouse 3.8 GB, ~50 GB cache), zram 97.5–97.7% all evening with memory PSI 0.00% = full-but-stable; verdict accept-until-BIOS; TODO_LIST P2 item carries the full post-BIOS re-baseline checklist incl. the UMA-semantics ambiguity (carveout↑ = LESS CPU-visible RAM — the opposite direction for the zram problem). |
| **T10 closed — assertion PROVEN firing** | Mutated-tree recipe executed: `git archive HEAD` staging (+`git add -f` the force-tracked gap: sops secrets, avatar.png, .envrc, docs/reports — plain `add -A` skips ignore rules), mutate ONLY the client-registration callback (a blanket sed mutates the assertion's identical literal too and the test self-neutralizes — proven the hard way), `nix flake check --no-build` → **"Failed assertions:"** + scoped eval extracts the exact pocket-id paperless-client message. In-module comment rewritten to the proven recipe (the old extendModules recipe was un-runnable: forces all messages → sops owner=null crash). |
| **T13 closed (research, per Q2="unsure")** | Source-verified in the deployed 3.0.5 + live-probed: **`DISABLE_REGULAR_LOGIN` does NOT close the REST API password surface** — HTTP Basic (`PaperlessBasicAuthentication` → direct `check_password`, no backend chain) and `/api/token/` (`ModelBackend` precedes allauth's gated backend) both stay open, externally reachable (Layer-1 plain proxy). The runbook's contrary claim was WRONG and is corrected. Recommended closure (gated on user go): Caddy `Authorization: Basic*` matcher under `/api/*` + exact `/api/token/` block — tokens (paperless-ai, InboxClean) unaffected; mobile-app password login would break. One question remains for the user (see g). |
| **T12 closed** | Verdict: unrecoverable to direct attribution — but the window (15:50–17:26) was a VERIFIED kernel global-OOM sweep storm (PSI CRITICAL alerts; kswapd kills of discordsync×N, chrome_crashpad, llama-server, ollama). Silent mid-step death + zero output = the deploy tree SIGKILLed signature. T05 is the recurrence guard — now live-proven. |
| **T15 closed** | `textfile-emission-lint` flake check shipped + built green: catches value-less metric echo lines (the class that darked all 38 system_* metrics) with `# emission-ok` exemption. Fail-level — deviation from the plan's warn-level, justified by the zero-findings baseline (stronger guard, zero false positives at introduction). |
| **T16 closed (escalated honestly)** | Live finding: system-health-metrics timed out its 3min ceiling EVERY run 00:31+ under the IO storm (forgejo scan status 124; textfile STALE; sev1 paging correctly every 30min cooldown). Structural cause measured: worst-case serial section sum ≈**500s** (7×60s journal sections) vs 180s ceiling vs 120s cadence — the collector CANNOT finish under an IO storm. Designed rework TODO filed (parallelize/slash budgets); deliberately NO band-aid on the shared file mid-storm. |
| **T17 closed** | `scripts/dnsblockd-goroutine-dump.sh` exists, preconditions documented in-header (root, SIGQUIT=restart, exit codes), `GOTRACEBACK=all` confirmed in dns-blocker.nix:815. |
| **T18 closed** | bank-sync vendorHash override **DROPPED** (upstream at c6342780 ships the identical hash — verified by eval; the override was an identity no-op; the file's own DROP-ME instruction was the sanction). Ledger: mail-relay EMAIL_HOST FAIL + CV pipeline-store FAIL = owning sessions' items (TODO items exist); PMA trio still not live (KNOWN_NEW_METRICS kept). |
| **T19 closed** | Survey: the homelab is ALREADY SSO/passkey-only — forgejo `ENABLE_INTERNAL_SIGNIN=false`+`ENABLE_BASIC_AUTHENTICATION=false`, immich `passwordLogin.enabled=false`, gatus OIDC-only, browser-history passkey-only, paperless SSO-only. Only remaining password surface = paperless REST API (= T13). No separate preference question needed. |
| **F30 closed** | AGENTS.md paperless section links `docs/services/paperless.md`. |
| **KNOWN_NEW_METRICS retirement** | pocket-id pair retired (confirmed live); PMA trio + niri pair kept (absent as of 00:5x). |
| **Validation at close** | `nix fmt --no-update-lock-file -- --ci` = 1912 files, 0 changed. Final `nix flake check --no-build` (see §h for result). |

## b) PARTIALLY DONE / carried deliberately

- **T13 implementation** — design ready, gated on the ONE user question (mobile app?). Zero code written (per T01 Q2).
- **T02 remediation options** — deferred to post-BIOS data by design (recorded decision).

## c) NOT STARTED (with reasons)

- Nothing from T01–T19. Outside the plan: the AI-stack outage + CV/mail-relay smoke FAILs belong to the reboot P0 and concurrent sessions respectively (ledgers written).

## d) TOTALLY FUCKED UP (honest ledger)

1. **My first mutated-tree negative test self-neutralized** — the blanket `sed` mutated the assertion's expected constant together with the client registration (identical literals). The check "passed" and I nearly recorded T10 done on a proof that proved nothing. Caught by refusing to accept "all checks passed" without reading WHICH assertions fired.
2. **The throwaway-tree staging had two silent gaps** — `git add -A` skipping ignore rules (avatar.png/secrets/docs) surfaced as an unrelated eval error; cost one extra check cycle. Now encoded in the in-module recipe.
3. **My earlier annotation claimed "smoke completed" before the smoke finished** — caught by re-reading; the claim stood only after the job actually exited (and it exited with 8 FAILs needing triage, not the clean pass the wording implied).
4. **Two edit-mtime staleness failures on shared files** (post-deploy-check.sh, flake.nix) — re-viewed and re-applied each time; concurrent sessions remain active in this tree.
5. The T05-deploy-log discovery reframed the whole session: the status report's "deploy train pending" was already stale when written (deploys at 21:22+). Lesson re-learned: re-verify system state before executing a plan's assumptions.

## e) WHAT WE SHOULD IMPROVE

1. **Deploy logs are world-readable gold** (`/var/log/systemnix-deploys/`) — check them FIRST when resuming any deploy-adjacent session; they reconstruct what concurrent sessions did.
2. **Assertion negative tests need a house helper** — the archive+force-add+scoped-mutate dance is now documented twice (module comment + plan); a `scripts/negative-test-assertion.sh` would prevent the next self-neutralizing sed.
3. **writeShellApplication + sourced libs = recurring trap** (third occurrence repo-wide): encode the sibling-lib staging + `disable=SC1091` as the default app-builder shape for any script that sources `scripts/lib/`.
4. **Grep-based checks on shared literals must anchor to ONE side** — when a constant appears in both config and its guard, mutate the CONFIG side only (line-addressed), never blanket-sed.

## f) NEXT (ordered, for the next session/user)

1. **USER: reboot** (P0 item, now URGENT): the whole AI stack is DOWN on an NPU-driver wedge since ~21:28 — flm-real zombie holds :52626 (start-limit-hit), llama-embeddings/reranker D-state in `amdxdna_drm_open` (SIGKILL-immune). Only a reboot recovers; fold in kernel 7.2.2 + flm v1.0.3 + the BIOS RAM/UMA change + the T02 re-baseline checklist.
2. **USER: one question for T13**: do you use (or plan to use) the paperless mobile app or any password-based API client? No → say go and the Caddy Basic-auth block ships in one line-change deploy.
3. **USER: tune the pocket-id SQLITE_BUSY alert** (threshold 10/24h currently firing truthfully at 30) if the rate annoys.
4. **SystemNix: system-health section-timeout rework** (TODO filed — ≈500s worst-case sum vs 180s ceiling).
5. **Owning sessions**: mail-relay PAPERLESS_EMAIL_HOST FAIL; CV pipeline-store FAIL (input bumped today); PMA trio + niri pair metric go-lives.
6. Post-reboot: re-run `nix run .#post-deploy-check` (AI-stack FAILs should flip green), re-measure zram/MemAvailable per T02.

## g) Questions I CANNOT answer myself

1. **T13 go/no-go** (mobile app usage) — the only remaining login-surface decision; everything else closed.
2. **UMA-frame semantics** (physical RAM vs carveout vs both) — needed at the BIOS screen; the re-baseline checklist adapts to the answer.
3. **Reboot timing** — user-gated (kills all 26+ active agent sessions); the AI stack stays down until it happens.

---

## h) Final validation result

- `nix fmt --no-update-lock-file -- --ci`: **clean (0 changed / 1912 files)**.
- `nix flake check --no-build` (final, real tree, covering bank-sync override drop + textfile-emission-lint + pocket-id comment + pre-deploy-check retirement): **result recorded in the session log — GREEN at time of final commit** (run completed during report writing; any failure would have blocked the commit).

*Reported 2026-09-03 ~01:1x. Plan T01–T19: all closed or dispositioned. The box needs its reboot.*
