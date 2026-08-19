# PR 139 Review Session — Forgejo hermes-agent Token Provisioning

**Date:** 2026-08-19 04:14 CEST
**Scope:** Review of [PR 139](https://github.com/LarsArtmann/SystemNix/pull/139) `feat(forgejo): hermes-agent read-only user + token provisioning` (branch `forgejo-hermes-agent`, 2 commits, +115 lines across `_forgejo-scripts.nix` + `forgejo.nix`). Nothing else touched. This report covers only this session's work and what was directly noticed during it.

---

## Executive Summary

PR reviewed and verdict posted on GitHub as a **COMMENT** review ("Request changes" semantics — GitHub rejects `--request-changes` on your own PR). **2 blockers, 3 major, 3 minor** found. The PR's design (dedicated identity + `read:repository`-scoped token, not `--restricted`) is sound; its execution mechanism (runuser-as-root inside `harden {}`) is a **git-proven broken pattern** already reverted once in this repo (`118e75f2`), and the token-validity probe 403s for the token's own scope. After posting, Blocker 2 was source-verified against upstream. The PR was NOT modified; fixes are queued as next steps.

---

## a) FULLY DONE

1. **PR 139 read and understood end-to-end**: both changed files, plus all surrounding context — `_forgejo-scripts.nix` (9 sibling scripts, the `tokenGen`/`adminSetup`/`genRunnerToken` idioms), `forgejo.nix` (all 6 provisioning units + their ordering/hardening conventions), `lib/systemd.nix` (`harden` helper — confirms no SystemCallFilter, `NoNewPrivileges=true` default, `CapabilityBoundingSet=""` default), `lib/systemd/service-defaults.nix`, `hermes.nix` (user only exists under `mkIf cfg.enable`), `configuration.nix` (forgejo + hermes both enabled on evo-x2), `deploy.sh:145` (provisioner restart list).
2. **Evaluation verification on the PR branch**: fetched to isolated worktree `/tmp/systemnix-pr139`, `nix flake check --no-build` **green**, merged unit config evaled via `nix eval --json` (root, oneshot, caps `CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE CAP_SETUID CAP_SETGID`, `ReadWritePaths=["/run"]`, `TimeoutStartSec=4min`, `wantedBy=[forgejo.service]` — all as the PR intended).
3. **Git-history forensics for Blocker 1**: traced the runuser-in-harden failure to commits `118e75f2` (fix + rationale) and `8e503916` (docs: crash-looped 2 days, PAM session init fails even with caps + `NoNewPrivileges=false`). Confirmed the PR's cited "buildcache idiom" does not exist — `buildcache.nix` never calls `runuser`.
4. **Review posted** to PR 139 with: 2 blockers (runuser PAM + fix recipe; scope-mismatch probe + fix recipe), 3 major (missing startLimit burst/interval, unguarded hermes-user coupling, missing from deploy.sh provisioner list), 3 minor (no `serviceOneshotDefaults`/`onFailure`, no-op dependency, fail-fast vs graceful degradation), plus explicit positives. Includes concrete fix guidance referencing repo idioms (`forgejo-generate-token` User= pattern, `+`-prefixed ExecStartPost delivery like gitea-runner's genRunnerToken).
5. **Blocker 2 source-verified after posting** (session follow-through): `GET /api/v1/user` is wrapped in `tokenRequiresScopes(AccessTokenScopeCategoryUser)` (go-gitea `routers/api/v1/api.go:1173`; Forgejo inherits this routing) — a `read:repository`-only token is rejected. The review's claim is factually correct; no correction comment needed.
6. **Cleanup**: worktree removed, `pr-139-review` local branch deleted, `/tmp/pr139-review.md` removed. Working tree left untouched by this session (zero edits to tracked files).

---

## b) PARTIALLY DONE

1. **Runtime verification of Blocker 1** — proven via git history + docs, but not re-demonstrated live on this host (sudo blocked in session; a transient unit test would need it). Confidence is high (documented twice, once as a 2-day outage), but "proven by documentation" ≠ "proven by experiment".
2. **Forgejo 15.0.6 CLI contract** — the `--random-password`, `--must-change-password=false`, `--raw`, `--scopes read:repository` flags and the `^[0-9a-f]{40}$` token format were accepted by precedent (`tokenGen` uses the identical calls in production on this very forgejo), not re-verified against the pinned binary's help output.
3. **Review coverage of "what's good"** — included, but the PR's own Verification section claim ("`nix-instantiate --parse` green") was never explicitly called out in the review as inadequate verification for a provisioning unit (syntax parse only — no flake check, no boot test, no live run; the runtime blockers prove the gap). Should have been a named point.

---

## c) NOT STARTED (deliberately out of review scope, queued)

1. Fixing the PR (rewrite unit to `User = "forgejo"` + `+`ExecStartPost delivery, scope-correct probe, stateDir persistence, guards, limits, deploy.sh entry) — review-only session per instructions.
2. Post-deploy verification plan for the token (file exists, `hermes:hermes 0400`, API 200 with it).
3. Wiring the actual hermes consumer (how the daemon reads the token — env file, path, rotation contract).
4. Token lifecycle hygiene: old `hermes-agent-<epoch>` tokens accumulate on every regen; no cleanup pass exists.
5. Any monitoring for the provisioning outcome (repo rule #9: "every new service MUST be monitored"; onFailure routing alone was suggested, no Gatus/textfile check proposed).
6. AGENTS.md/memory updates from this session (candidate: "own PR ⇒ `gh pr review --comment`", "review verify-claims discipline" — minor).

---

## d) TOTALLY FUCKED UP

1. **`gh pr review --request-changes` failed** ("Can not request changes on your own pull request") — predictable: `gh` is authenticated as LarsArtmann and the PR author is LarsArtmann. Wasted a round trip; recovered immediately with `--comment`. Should have anticipated from the PR metadata I had already fetched.
2. **Posted Blocker 2 as unqualified fact BEFORE verifying it.** The review states the 403 behavior as a blocker on knowledge alone; verification happened only afterward (and did confirm it). If it had been wrong, a public review would have contained a false blocker. The right order was verify → post. This is the session's real process failure, even though the claim turned out true.
3. (Small) **Missed review points found only during this retrospective**:
   - `ReadWritePaths = [ "/run" ]` is both **overbroad** (grants write to ALL runtime state incl. sops-adjacent runtime) and **redundant** (ProtectSystem=full only protects /usr, /boot, /etc — /run is already writable). Under the proposed User=forgejo fix it disappears anyway, but it deserved a minor bullet.
   - The PR body's "Verification" section (parse-only) not challenged (see b.3).
   - The username existence check `grep -q "$FORGEJO_USER_NAME"` is substring-match (false-positive prone), unlike `tokenGen`'s anchored regex — trivia, but inconsistent with sibling scripts.
4. **Did NOT flag the pre-existing staged change** `M scripts/pre-deploy-check.sh` (present in the git snapshot at session start). Per repo Critical Rules, unexpected tree changes I didn't author must be flagged to the user immediately — I noticed it only in retrospect. It remains unexamined and untouched. FLAGGING NOW (see questions).

---

## e) WHAT WE SHOULD IMPROVE (process, from this session)

1. **Verify external-behavior claims before publishing them in reviews** — 403-on-scope-mismatch, CLI flags, token formats. The repo has `verify-external-claims` discipline for skills/docs; reviews deserve the same. Sourcegraph against go-gitea/forgejo took one query.
2. **Check `gh` auth identity vs PR author before choosing review mode** — if they match, `--comment` is the only option; encode as reflex.
3. **Read the git-status snapshot at session start and act on it** (flag foreign changes) rather than ignoring it until a retrospective forces the issue.
4. **Reviews should grade the PR's own verification claims** — a provisioning unit "verified" by parse-only deserves pushback; that's how Blockers 1+2 slipped through the author's self-check.
5. **Offer fix-as-patch**: for a two-blocker review on an own-repo PR, a concrete diff would converge faster than prose fix recipes. Ask whether to push fixes to the branch.
6. **Consider a lightweight provisioning-unit smoke pattern** (transient systemd-run with the unit's exact directives) for cases where sudo is available — would have upgraded Blocker 1 from "documented" to "demonstrated" in 30 seconds.

---

## f) NEXT — up to 50 things (ordered: P0 blockers first)

**PR 139 fixes (P0 — must land before merge):**
1. Rewrite unit: `User = "forgejo"; Group = "forgejo";` + plain `harden { }`; drop root, drop all five caps.
2. Script: remove `runuser -u forgejo --` prefixes; call the forgejo CLI directly (tokenGen idiom); drop `util-linux` runtimeInput.
3. Add `+`-prefixed `ExecStartPost`: `install -o hermes -g hermes -m 0400 ${stateDir}/hermes-agent.token /run/hermes-forgejo-token` (root escape hatch; mirrors gitea-runner `+forgejo-gen-runner-token`).
4. Change validity probe from `GET /api/v1/user` to `GET /api/v1/user/repos` (repository scope category — 200 on empty list).
5. Persist raw token forgejo-only at `${stateDir}/hermes-agent.token` (mode 600) so reuse survives reboots; `/run` copy is the delivery artifact.
6. Wrap unit in `lib.mkIf config.services.hermes.enable` (hermes user coupling).
7. Add `startLimitBurst = 5; startLimitIntervalSec = 300;` (top-level, [Unit]-safe placement).
8. Add `(serviceOneshotDefaults { })` + `inherit onFailure;` to match sibling provisioners.
9. Drop the no-op `after`/`wants` on `forgejo-generate-token.service`.
10. Drop `ReadWritePaths = [ "/run" ]` (redundant under User=forgejo rewrite; staging file lives in stateDir).
11. Anchor the user-exists grep (e.g. `grep -qE "^.*\s${FORGEJO_USER_NAME}\s"` or match `tokenGen`'s strictness).

**Wiring + deploy (P1):**
12. Add `forgejo-hermes-token` to the provisioner restart list in `scripts/deploy.sh:145`.
13. Re-run `nix flake check --no-build` + eval on the fixed branch; re-review.
14. Merge → `nix run .#deploy` → post-deploy check: unit `inactive (dead)` + `RemainAfterExit`, token file `hermes:hermes 0400` at `/run/hermes-forgejo-token`.
15. Live-verify: `curl -H "Authorization: token $(cat /run/hermes-forge-token)" https://forgejo.home.lan/api/v1/user/repos` → 200; `/api/v1/user` → 403 (proves the scope is actually narrow).
16. Define the hermes consumer contract: env var pointing at the file path vs. content injection (LoadCredential on the hermes unit?) — needs decision.
17. Token regeneration cadence: with stateDir persistence, regen only on invalidity; document expected lifetime.

**Hygiene/monitoring (P2):**
18. Add stale-token cleanup (delete old `hermes-agent-*` tokens via admin API when regenerating) to prevent DB accumulation.
19. Consider a textfile metric `forgejo_hermes_token_valid` (probe result) consumed by system-health + Gatus — satisfies repo rule #9 for this provisioning path; alternatively document why onFailure suffices.
20. Add an `assertions` guard or comment in forgejo.nix: hermes coupling is conditional and why.
21. Update AGENTS.md Forgejo section with the hermes-agent identity + token path once landed.
22. Note the delivery path in docs/services/ if a forgejo doc exists (check `docs/services/` convention).

**Session-adjacent, noticed but untouched (P2, need user input/ownership):**
23. Inspect the staged `M scripts/pre-deploy-check.sh` — identify author/session; it predates this session and was never examined (flagged in d.4).
24. Re-verify after concurrent sessions settle: evo-x2 eval + flake check still green (shared-tree rule — my green check only covered the PR worktree).

**Debts noticed in passing (P3, out of scope but real):**
25. `tokenGen` readiness loop lacks fail-fast (curl without `-f`) — inconsistent with the PR's stricter loop; align when touching the file anyway.
26. `mirrorGithubScript`/`mirrorStarredScript` write tokens into URLs (push-mirror remote) — pre-existing pattern, worth an audit someday.
27. No forgejo VM test exists at all (`tests/` has paperless/searxng/etc.); a minimal provisioning-unit test would have caught both blockers pre-review — candidate for `tests/test-forgejo.nix`.
28. Sibling-provisioner audit: `forgejo-ssh-keys`, `forgejo-oidc-setup` all carry `onFailure` — confirm no other unit in the repo lacks both `onFailure` and monitoring.
29. `genRunnerToken` writes `TOKEN=` file mode 644 into `/run/forgejo-runner/` — world-readable runner registration token; check whether directory perms save it (0755 default + 644 file = readable). Pre-existing, not this PR.
30. Consider `RestartSec`/burst audit across ALL oneshot provisioners for the restart-vs-timer gotcha class (one live incident already in AGENTS.md).

---

## g) QUESTIONS (cannot be answered from the repo)

1. **Should I push the blocker fixes to `forgejo-hermes-agent` myself now** (I have the full fix recipe and the worktree pattern ready), or do you want to apply them and have me re-review?
2. **The staged change `M scripts/pre-deploy-check.sh` predates this session** — is that yours or another live agent session's work? Per the shared-tree rules I will not touch or evaluate it until ownership is clear.
3. **How should hermes actually consume the token at runtime** — a `FORGEJO_TOKEN_FILE=/run/hermes-forgejo-token` env var on the hermes unit (file read per use), a sops-independent EnvironmentFile rendered from it, or LoadCredential? The PR ships no consumer wiring, and the right shape depends on the Mnemosyne GraphRAG consumption pattern you intend (process restart tolerance vs. live rotation).

---

*Session artifacts: review posted at https://github.com/LarsArtmann/SystemNix/pull/139 (COMMENTED). Worktree/branch cleaned. Zero edits to tracked files this session.*
