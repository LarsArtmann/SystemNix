# Status Report: Wise SCA root cause → wise-go v0.6.1 → bank-sync wiring (2026-08-19 05:10)

**Session scope:** Continuation of the bank-sync/ActivityWatch session (03:29 report). User said "GO FIX" on the remaining Wise 403 (zero transactions syncing). This report covers the Wise-dead-sync investigation and the cross-repo fix pipeline (wise-go → bank-sync → SystemNix), plus what was observed en route. Format `.md` per explicit user request (skill default HTML — override flagged, same as previous report).

---

## Executive Summary

| Category             | Count |
| -------------------- | ----- |
| FULLY DONE           | 6     |
| PARTIALLY DONE       | 3     |
| NOT STARTED          | 5     |
| TOTALLY FUCKED UP    | 4     |
| Next-task candidates | 28    |

**Headline:** The Wise 403 mystery is SOLVED at the root cause: `statement.json` is **SCA-protected** (UK/EEA profiles) — Wise answers 403 with an EMPTY body and puts the verdict + one-time token in `x-2fa-approval*` response headers, which wise-go discarded. The SDK fix is **released as wise-go v0.6.1** (pushed, tests green). bank-sync consumes it (go.mod + flake lock + env wiring) but is **UNCOMMITTED and its nix build is UNVERIFIED** — the session was interrupted right after the vendorHash was set. The SystemNix deploy leg has not started. The final unlock requires a human step: approving the SCA challenge in the Wise app.

---

## a) FULLY DONE

1. **Root cause of the Wise 403s — identified with documented evidence.**
   - Ruled out systematically: endpoint retirement (v1 answers 401 unauthenticated = exists; v3 = 404 = doesn't), our `type=` param (optional filter, correctly omitted), SDK error-swallowing (wise-go captures bodies properly — the live 403 body is genuinely empty).
   - Positive identification: Wise docs (via API-docs study + live web verification) state balance statements are SCA-protected for UK/EEA; the documented SCA rejection is a 403 with empty body + `x-2fa-approval-result: REJECTED` + `x-2fa-approval: <OTT>` headers. Matches every observed symptom, including 403-from-the-very-first-sync (bring-up, never-worked).
   - Secondary documented possibility (personal-token regional restriction for non-US/CA/AU/NZ/SG/MY accounts) is distinguishable ONLY by the response headers — which is exactly what the SDK now surfaces.

2. **wise-go SCA feature — implemented, tested, released as v0.6.1 (commit `88f3e20`, pushed).**
   - `APIError.Headers` now carries response headers (previously discarded — the entire diagnosis gap).
   - New `*SCAChallengeError` (code `wise.sca_challenge`, family Rejection): 403 + either 2FA header → typed error whose `Error()` prints the header values and the unlock instructions; `TwoFAApprovalToken()` exposes the OTT.
   - New `WithSCAApprovalToken(token)` option sends `x-2fa-approval` on every request — the documented way to complete the challenge after user approval.
   - Header constants in canonical MIME form (`X-2fa-Approval`) — the pre-commit `canonicalheader` linter caught my first (lowercase) attempt; fixed before landing.
   - 4 new tests (classification, plain-403-stays-AuthError, token header pass-through, error-message content). Suite: 43+ specs green. golangci-lint: 0 issues.

3. **wise-go lineage integration.** Local master had diverged from origin (v0.5.2/v0.5.3 were released from elsewhere). Union-merged both test suites and preserved the richer upstream CHANGELOG entries (merge commit `40de709`).

4. **wise-go v0.6.0 retraction + v0.6.1 release.** The daemon raced my tag push and published v0.6.0 on the pre-merge lineage (missing the v0.5.2/v0.5.3 fixes); the Go proxy cached it within seconds → immutable. Issued `retract v0.6.0` in go.mod + CHANGELOG note + tagged v0.6.1 on the integrated lineage. v0.6.1 pushed and confirmed fetchable (`go get` resolved it during the bank-sync bump).

5. **bank-sync config wiring for the SCA token (code side complete).**
   - `WiseConfig.SCAApprovalToken` (`koanf: sca_approval_token`) → auto-exposed as `BANK_SYNC_WISE_SCA_APPROVAL_TOKEN` env var by the existing env-key map (verified the derivation is single-source-of-truth).
   - Threaded: config → `bank.Config.SCAApprovalToken` → wise adapter → `wisesdk.WithSCAApprovalToken`. Doc comments explain the lifecycle (set only to clear the challenge, then remove).
   - go.mod: wise-go v0.5.3 → v0.6.1; full test suite green.

6. **bank-sync nix blocker diagnosed and patched.** Flake-pinned go-codec demands go ≥ 1.26.6 (security-driven toolchain bump, no language changes — verified in go-codec's history) while nixpkgs ships 1.26.5. Added floor-lowering sed (`go 1.26.6` → `1.26.5`) on the writable `_local_deps` in modBuildPhase + preBuild, with removal condition documented (nixpkgs ships 1.26.6). This is the legitimate build-environment patch class per AGENTS.md. vendorHash re-captured: `sha256-RLvx…GYlA=`.

---

## b) PARTIALLY DONE

1. **bank-sync release state — code done, NOT committed, build NOT verified.** 8 modified files sit uncommitted (`go.mod`, `go.sum`, `flake.nix`, `flake.lock`, `pkg/config/config.go`, `internal/bank/bank.go`, `internal/bank/wise/adapter.go`, `cmd/bank-sync/providers.go`). The vendorHash was pasted in as the very last action before this report — **the build that proves it green was never run.** No CHANGELOG entry added yet.
2. **SystemNix leg — only researched, not executed.** Needs: flake input bump to the future bank-sync commit, sops template addition for the (optional) `BANK_SYNC_WISE_SCA_APPROVAL_TOKEN`, deploy, journal verification. None started.
3. **The actual SCA unlock — blocked on a human step by design.** After deploy, the journal should print the challenge verdict + OTT. Clearing it needs: approve in Wise app/web → `sops --set` the OTT → redeploy → sync once → remove token. (SCA is only required once per ~90 days; viewing a statement in the app/web also satisfies it per docs.)

---

## c) NOT STARTED

1. bank-sync nix build verification + commit + push.
2. SystemNix flake bump, sops wiring, deploy, post-deploy journal check.
3. bank-sync CHANGELOG entry + test for the SCA token pass-through (wise-go has tests; the bank-sync adapter/config side has none).
4. Gatus/alert path for "bank-sync sync failing permanently" (currently the service logs WARN and stays green on dashboards — the original silent-failure complaint).
5. wise-go GitHub Release page for v0.6.1 (go-release Phase 7) — not verified whether wise-go even uses GH releases.

---

## d) TOTALLY FUCKED UP

1. **The v0.6.0 tag race — my sequencing error, permanently visible in the ecosystem.** I created the annotated tag LOCALLY before the push had succeeded and while the lineage was still unsettled (push rejected for being behind → rebase → daemon aborted the rebase → daemon pushed master+tag during the chaos). Result: v0.6.0 on the proxy forever points at a lineage missing two fixes; a retraction is baked into go.mod history. Cost: ~20 min recovery + a permanently poisoned version number. **The rule I violated: tag only after the branch push has succeeded and the tree is quiescent** (this repo has a documented daemon that pushes — I knew, and tagged anyway).
2. **Blind commit retry.** The first wise-go commit failed in BuildFlow; I retried the IDENTICAL command once before reading which step failed (it was the foreign `dprint.json` staged by a concurrent session — exit 14, no files matched). One wasted ~60s cycle and noise. Should have diagnosed on first failure.
3. **Declared "vendorHash captured" without the verification build.** The very next step (rebuild with the hash in place) never ran — interrupted by this report request. If the hash is wrong (or the floor-patch interacted badly), the deploy build will fail at the worst moment. Unverified claims are how phantom states enter the pipeline.
4. **Near-miss caught by luck, not process:** my initial CHANGELOG rewrite would have silently REPLACED the richer upstream 0.5.2/0.5.3 entries with my shorter summaries — the merge conflict is the only thing that surfaced the upstream detail. I resolved content conflicts without first `git show origin/master:CHANGELOG.md`. Correct outcome, wrong procedure.

---

## e) WHAT WE SHOULD IMPROVE

1. **Tag-after-push discipline.** Concretely for daemon-raced repos: `git push origin master` FIRST, confirm, then tag, then push the tag. Add to wise-go AGENTS.md alongside the existing daemon-race note (bank-sync already has one from `b702d75`).
2. **Failed pre-commit = read the failing step before retrying.** BuildFlow prints exactly which step failed; `--no-verify` is legitimate WITH the evidence named in the commit message (I did this correctly on later commits — make it the only pattern).
3. **Never report a captured FOD hash as done without the confirming green build.** One command, minutes.
4. **Content-conflict resolution requires reading both sides from git, not the working tree.** Markers in the tree show the conflict, not the full upstream context.
5. **The foreign `dprint.json` in wise-go still breaks BuildFlow pre-commit (exit 14).** A concurrent session left it staged/committed; it needs its config fixed or removed, or every future commit in that repo needs `--no-verify`.
6. **wise-go master moved again after my push** (`47655fd` "errors modernization" — another session). v0.6.1 is unaffected (immutable tag, bank-sync pins `88f3e20` by rev), but my uncommitted-at-the-time work and theirs are now interleaved in that repo's history — same shared-tree rule as SystemNix applies.

---

## f) NEXT — ranked

**P0 — finish the pipeline (blocking the actual data sync):**

1. `nix build .#default` in bank-sync with the new vendorHash — must be green.
2. Add bank-sync CHANGELOG `[Unreleased]` entry: SCA approval-token config + wise-go v0.6.1 bump.
3. Add a bank-sync test: `BANK_SYNC_WISE_SCA_APPROVAL_TOKEN` set → adapter constructed with the option (factory-level assertion).
4. Commit bank-sync atomically (8 files, one commit), push.
5. SystemNix: `nix flake lock --update-input bank-sync`.
6. SystemNix: add the SCA token to the sops `bank-sync-env` template as an OPTIONAL/empty-safe key (verify bank-sync treats empty as unset — the config default is empty, so likely fine; confirm the template renders an empty var harmlessly or omit until needed).
7. `nix run .#deploy`.
8. **Verify the diagnostic goal:** journal must now show `wise: sca challenge (403): … x-2fa-approval-result="REJECTED" … x-2fa-approval="<OTT>"` instead of the bare `api error (403):`. If instead it stays a plain AuthError with no 2FA headers → the personal-token regional restriction applies (see question 2).

**P1 — the human unlock + hardening:**
9. USER: approve the SCA challenge in the Wise app/web (or just view a statement there — counts per docs), then `sops --set` the OTT, redeploy, verify `total_new > 0` on the next sync, then REMOVE the token from sops.
10. Gatus/alerting for permanent sync failure (metric or log-probe — bank-sync emits `sync failed permanently` WARN; wire `system-health` or a watchdog).
11. Previous session's still-open P0: `startLimitBurst`/`startLimitIntervalSec`/`onFailure` on `bank-sync-storage-dir` (house rule 5).
12. post-deploy Bank-Sync body check: log first ~200 bytes of body on failure (previous session's d-2 fix, still open).
13. wise-go: review concurrent `47655fd` sweep (touches errors modernization — may have reworked my files; verify tag integrity unaffected, it is, but keep an eye).
14. wise-go GitHub release for v0.6.1 with retraction note (confirm repo even uses GH releases first).

**P2 — hygiene:**
15. wise-go AGENTS.md: tag-after-push rule + SCA gotcha entry (headers-only 403 diagnosis story).
16. bank-sync AGENTS.md: SCA runbook (deploy → read OTT from journal → approve → sops → deploy → remove).
17. SystemNix AGENTS.md: bank-sync SCA ops pointer (where the token lives, 90-day cadence).
18. Fix or remove the foreign `dprint.json`/BuildFlow breakage in wise-go.
19. bank-sync: extract vendorHash to `vendorHash.nix` (nix-checker suggestion, cleaner diffs).
20. Track nixpkgs go 1.26.6 arrival → delete the go-codec floor-lowering patch.
21. Verify proxy.golang.org serves v0.6.1 correctly for non-flake consumers (flake uses git+ssh, so deploy is independent).

**P3 — observed, non-blocking:**
22. `/data` EIO inode repair window (btrbk-data + pool backups still failing by documented stance).
23. 10 stale build sandboxes → `sudo systemctl start nix-build-cleanup.service`.
24. Monitor365 pre-deploy warnings enable-gating.
25. wise-go govulncheck reported 36 stdlib findings (GO-2026-6218 etc.) — toolchain-bump class, fold into next wise-go release.
26. Another session's SystemNix report (`04-14_pr139_forgejo-hermes-token-review.md`) sits staged — not mine, untouched.

---

## g) QUESTIONS — cannot be answered from here

1. **SCA approval:** once deployed, are you ready to approve the challenge in the Wise app and hand me the OTT (or view a statement in the app so the challenge window is satisfied, then I retry without a token)? This step is inherently yours — 2FA exists to require you.
2. **If the journal shows a plain 403 WITHOUT the 2FA headers** (not an SCA challenge), the documented cause is the personal-token regional restriction (statements via personal tokens are unsupported outside US/CA/AU/NZ/SG/MY). Do you know your Wise account's registration region, and is the token a personal API token or an OAuth partner token? (Determines whether the fix is "approve challenge" vs "different token type/partnership".)
3. **go-codec floor patch:** I lowered `go 1.26.6 → 1.26.5` inside bank-sync's FOD build (build-environment patch class, documented, removable when nixpkgs ships 1.26.6). Acceptable to keep short-term, or would you rather pin go-codec back to a 1.26.5-floor rev upstream instead?

---

_Report written 2026-08-19 05:10 CEST. bank-sync tree intentionally left uncommitted mid-pipeline (P0 items 1-4 next). wise-go clean at v0.6.1 (`88f3e20`). SystemNix untouched this session beyond the previous session's staged docs. Auto-commit daemon will batch this report._
