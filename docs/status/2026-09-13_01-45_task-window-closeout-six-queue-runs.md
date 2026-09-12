# Task-Window Closeout — Six Queue Runs (2026-09-12) — Status Report

**Date:** 2026-09-13 01:45 CEST
**Scope:** the six task-queue items completed in the 2026-09-12 window, their closing commits, and what this docs-health pass noticed in passing. Every claim below was re-verified this pass against `git show`, the window's own reports, and the live docs — nothing is taken from the dispatch text alone.
**Method:** `git show` on each closing commit; full reads of the window's status reports; reference-checks for archiving; file-existence and file:line checks for every CHANGELOG/FEATURES claim added.

---

## Window inventory

| # | Task (dispatch ID) | Subject | Closing commit | Verdict |
|---|--------------------|---------|----------------|---------|
| 1 | `000001a0927c6b70…` | Hermes v0.21.0 cron scheduler ERRORS every few minutes | `9502c138` | Fix verified + queue footer landed; **fix NOT yet live** |
| 2 | `000001a092aa3219…` | Paperless `PAPERLESS_EMAIL_HOST` missing in smoke — "real config bug" | `8f3a21c7` | **NO-BUG — premise falsified**; stale-harvest phantom closed with evidence |
| 3 | `000001a092ca3d30…` | Corrupt GGUF (`gemma-4-31b-…Q8_0.gguf`) blocking Jan imports | `28261b3b` | Resolved (trashed 2026-09-12) + AGENTS ghost instruction repaired |
| 4 | `000001a0935cb937…` | InboxClean `main` OAuth re-consent (Gmail sync dead since 09-04) | `8605c6bd` | Correctly BLOCKED (human-only); new contradiction documented |
| 5 | `000001a0936f08bb…` | Miniflux SSO-only flip | `cb885959` | Correctly NOT executed — go-live gate unsatisfied; BLOCKED (human-only) |
| 6 | `000001a093815838…` | Paperless statement decrypt go-live + dupes + retro-repair | `8d7c1ede` (+ daemon `3963d0ae`) | Verification complete; **runbook defect #3 found + fixed**; go-live still user-gated |

---

## a) FULLY DONE (verified)

1. **Hermes cron-dispatch fix re-verified at all four wiring points, and the queue↔git cross-reference finally exists.** The fix itself landed earlier on 2026-09-12 (fixing session rode heuristic daemon commits, so no footer existed): `modules/nixos/services/hermes.nix` carries `linger = true` (:519), pinned `uid = 975` with `after/wants user@975.service` (:514-571), `XDG_RUNTIME_DIR=/run/user/975` (:616), and the tmpfiles `L+ /bin/true` → coreutils (:552 — the upstream scope-availability probe execs `/bin/true` literally; NixOS ships none). `tests/test-hermes.nix` §9 runs the EXACT upstream probe plus a no-env negative control (:268-272). This run's deliverables: `nix flake check --no-build` green, hermes VM test green (store-cached), flake.lock `hermes-agent` node confirmed at `79445a496` (nothing server-relevant in the ~20 commits past verified `d3630f85`), and commit `9502c138` carrying the `Task-Queue-ID` footer. Companion findings closed: Discord 429 slash-sync noise gone since ~09-08 (remaining 429s = zai/minimax LLM Token-Plan limits).
2. **The "Paperless email config bug" is provably a phantom.** Full trace: `paperless.nix:56` gates on `mailRelayEnabled`; relay enabled (`configuration.nix:340`); the settings render into the deployed unit LIVE (`/etc/systemd/system/paperless-web.service` carries `PAPERLESS_EMAIL_HOST=127.0.0.1`, `PORT=25`, `FROM=noreply@larsartmann.cloud`), and the smoke's exact grep PASSES today. Root cause of the 2026-09-02..05 red era: the old smoke grepped `/var/lib/paperless/paperless.conf` — a file nothing generates — fixed in `da439c95` (2026-09-05). The "real config bug, red on EVERY deploy" framing was manufactured by three later docs passes that carried the claim forward without re-running anything. Closed in TODO_LIST `[x]` with the full evidence chain (commit `8f3a21c7`).
3. **The corrupt GGUF is gone and the doc split-brain it left is repaired.** The file was trashed to `/data/.Trash-1000` (same-btrfs rename — extents free as /data snapshots expire; first concrete /data-corruption victim outside the btrbk leg) by a parallel session ~2 h before the task ran; this run independently re-verified the EIO with `dd`, confirmed the trash location, and fixed the third doc surface: AGENTS.md still instructed future agents to delete a file that no longer existed. AGENTS.md now records the resolution + the re-validate-before-import lesson (commit `28261b3b`); TODO row `[x]`; jan.md updated by the prior session.
4. **InboxClean `main` re-consent: diagnosis complete, blocked state honestly encoded.** Live-verified 2026-09-12 04:00-04:12: `main` is `auth_expired` (`invalid_grant` every 30-min tick, cursor frozen at `start_history_id=5152620` since Sep 04 07:34); `work` is `connected`, cursor ADVANCING, zero `token_revoked` since Sep 04. The fix is proven (not assumed) agent-impossible: the upstream auth CLI is a copy-paste browser flow (`cmd/inboxclean/commands.go` — no device-code flow), token files are service-user-owned, `sudo` banned. TODO row left open with `— BLOCKED:` + evidence (commit `8605c6bd`). **New finding that corrects the item's own causal claim:** the `gmail` tag AUTO→NONE demote PATCH has failed at the PAPERLESS side (`[rejection:paperless.client_error]`, 80× since Sep 06) under the CONNECTED `work` account — the dead `main` token does not explain it.
5. **Miniflux SSO-only flip: gate-proof established; the flip was deliberately withheld.** Full journal sweep of `miniflux.service` (coverage proven back to first boot): the ONLY `/oauth2/oidc/callback` hits ever are the two 2026-09-11 14:39 `user_already_exists` 400 collisions — the "Link your Pocket ID account" flow was never executed and ZERO successful SSO logins exist. The self-audit pass (`docs/status/2026-09-12_04-37_…`) closed the work run's weakest link by validating the success signature: the runbook's documented `User authenticated successfully using OAuth2 … username=lars` line WOULD have matched the sweep's grep and appears zero times — the absence-proof is valid. Deployed unit confirmed carrying `OAUTH2_PROVIDER=oidc` with NO `DISABLE_LOCAL_AUTH`. Flipping now would remove the password break-glass while the callback still collides = the documented lockout class (upstream refuses unlinking once flipped). TODO row BLOCKED (commit `cb885959`).
6. **Paperless statement-decrypt: every prior claim re-verified, and the runbook's third defect caught by actually executing the mandated test.** Verified: upstream `--backfill --decrypt-repair` fully implemented at InboxClean `7aa5c3f` (ancestor of HEAD, commit message carries this very queue ID); SystemNix lock still `c65c7973` (deployed binary lacks the flag); origin 10+ commits behind master (push agent-banned); sops password still PLACEHOLDER (user-gated, by design untestable without sudo). The queue-mandated live test of the runbook env reconstruction FAILED against the deployed CLI: without `LLM_PROVIDER` the binary's global config gate exits `config.api_key_required` BEFORE dispatch (default provider `openai`; the unit runs `ollama`), and the runbook's `INBOXCLEAN_TOKEN_FILE` appears NOWHERE in the InboxClean source — an invented knob (real: `GMAIL_CREDENTIALS_FILE`/`GMAIL_TOKEN_FILE`, both in the deployed unit; the main account's re-fetch client builds from `cfg.Gmail`, `cmd/inboxclean/main.go:604`). Corrected five-var reconstruction gate-tests clean to exactly the root-owned `PAPERLESS_TOKEN` stop point. Fixed in all three live surfaces (`docs/services/paperless.md`, AGENTS.md, TODO row) via daemon commit `3963d0ae` + footer commit `8d7c1ede`. The interim `git+file?rev=` pin + live deploy was considered and correctly rejected: the repair cannot run until the user fills the password anyway.

## b) PARTIALLY DONE

1. **The Hermes cron fix is committed but NOT live.** The TODO row reads `[x] … goes live with the next deploy`, but the deployed generation predates the fix — production cron errors (the original ~1,302-error outage signature) continue until `nix run .#deploy`. The row's completion claim overstates reality by exactly one deploy. Independent live-journal re-verification also did not happen (agent sandbox: no sudo, journal root-readable only) — the journal-clean claims rest on the fixing session's documentation.
2. **Paperless decrypt: engineering done, go-live 0%.** All three parts end user/upstream-side: sops password (human), `--backfill --prune` + `--decrypt-repair` live runs (sudo + root-owned token), upstream push + tag + `nix flake lock --update-input inboxclean` + deploy before part 3 can run at all.
3. **InboxClean and Miniflux: diagnosis 100%, fix 0%** — both correctly BLOCKED, but the services remain in their broken/disabled states until a human acts (main sync dead since Sep 04; Miniflux on password break-glass with SSO collision unresolved).
4. **Corrupt GGUF: two unverified residuals** — the Jan model registry was never grepped for dangling references to the trashed file ("never imported" is inferred from the path-guard bullet), and the EIO re-verification was header-only.
5. **All VM greens in this window are store-cached**, not fresh runs — valid (deterministic derivations, clean tree) but the committed artifacts say "green" without the qualifier.

## c) NOT STARTED (skipped by the window, now tracked)

1. **The deploy itself** and the post-deploy verification bundles (hermes cron journal check, `/bin/true` persistence, first real cron fire in `user@975.slice`, pool-smart first live root run + `KNOWN_NEW_METRICS` loan cleanup).
2. **Every prevention layer the window's own reports proposed** — verify-before-harvest, harvest resolution-grep, pre-commit fast path, HUMAN-capability tag, daemon-race procedure doc, tq minimum-verification gate. All are now TODO items; none built. These are the actual 80/20: two of this window's six tasks existed only because the rules are missing.
3. **The gmail-tag PATCH rejection root cause** (HTTP status never captured), **stale-historyId risk assessment** (main will retry with a 9+ day old cursor), **papersync blind-window coverage** (~9 days of unarchived mail), and the **`/health` phantom-green upstream filing** (overall `ok` while an account is 8+ days dead).
4. **Miniflux follow-ups**: runbook gate-proof block, VM-test `DISABLE_LOCAL_AUTH` biconditional, post-flip drill, unlink-refusal option description.
5. **/data single-victim repair recipe + damage-set inventory** (proposed by the GGUF run, not built).

## d) TOTALLY FUCKED UP

Nothing in this window destroyed work or broke gates — all six runs are docs-only and the repo is green. What actually sucked:

1. **Two of six queue tasks were phantom-premise work, and the class is now confirmed twice.** The Paperless email task existed because three consecutive docs passes re-manufactured "real config bug, red on EVERY deploy" from a falsified premise — while the closing PASS evidence sat five hours newer in the same archive directory. The sibling 2026-09-13 window then falsified the attic "deterministic RED" the same way (9 days stale, one flaky observation on a storm day, belief propagated through three more reports without a re-run). This is a process hole with a per-instance cost of one full agent session each.
2. **Two tasks were dispatched to agents structurally incapable of executing them.** InboxClean re-consent needs a Google Cloud Console flip + an interactive Google browser login + `sudo -u inboxclean`; Miniflux's gate needs the user's browser + passkey. Both runs spent their session proving what an enqueue-time HUMAN tag would have said instantly. Routing failure, not effort failure.
3. **The Hermes fix's value is hostage to an un-run deploy, while its TODO row is already `[x]`.** Production cron errors continued throughout the window; the closure artifact ("goes live with the next deploy") is accurate but the tracker cannot distinguish "fixed" from "fixed-and-shipped". Same shape as the runbook trap below: verification evidence ≠ live outcome.
4. **The paperless decrypt runbook shipped THREE defects across as many runs** (`INBOXCLEAN_CONFIG` missing → unit `PATH` missing → `LLM_PROVIDER` gate + invented `INBOXCLEAN_TOKEN_FILE` knob). Each would have dead-ended the user's live repair run at a different point. Root lesson, stated by the run itself: "verified the extraction" (greps match the unit) is not "verified the command" — a runbook command is only verified when its failure surface is the EXPECTED one.
5. **Queue-ID churn on the InboxClean item (observed in passing, sibling window):** the item now maps to THREE IDs — first enqueue `000001a0935cb937…` (which this window's dispatch ALSO used, and which the landed footers carry), canonical `000001a0936f08db…` per the reviewer, and re-dispatch `000001a097a2c87f…` for the remap task itself. Landed footers cannot be reworded (already pushed; agent pushes forbidden), so greppability rides a remap note. Canonical-ID authority flip-flopped within hours; near-collinear IDs (`936f08db…` canonical vs this window's Miniflux `936f08bb…`) make manual matching error-prone.
6. **The `[x]` rows are re-accumulating in TODO_LIST** (Hermes, email-smoke, GGUF this window) against the docs-health "done items NEVER stay in TODO_LIST" contract — because the queue contract for this pass is append-only. The two contracts conflict; the conflict is recorded in the banner and deferred, not silently ignored.
7. **Foreign working-tree change noticed (not mine, not touched):** `scripts/pre-deploy-check.sh` is modified in the working tree by a parallel session/daemon at report time. Flagged per the shared-tree doctrine; excluded from this pass's commit; not co-verified.

## e) WHAT WE SHOULD IMPROVE

1. **Verify-before-harvest (the 80/20).** Any "X red since DATE" claim carried into TODO_LIST must cite a re-run of that specific check within the carrying pass, or be tagged `unverified-carry-forward`. Kills both phantom classes at the source. Companion: harvest must grep `docs/status/` (incl. `archived/`) for later resolutions before re-queuing.
2. **HUMAN-capability tag at enqueue** — browser/sudo/interactive-login tasks never reach agent pools.
3. **Pre-commit fast path** — docs-only staged diffs run gitleaks + fast guards + `nix flake check --no-build`; the VM-building full check only for code diffs. Ends the normalized `--no-verify` habit (which also skips gitleaks) that the now-unblocked attic check had forced.
4. **Encode "a runbook command is verified when its failure surface is the expected one"** in the tq runbook, with the amend-on-daemon-race repair as the standard commit procedure and a minimum verification gate for no-code-change closures.
5. **First commit of every queue run carries the footer** — heuristic daemon commits cannot, so landing sessions leave an audit hole between fix and footer.
6. **Reconcile the TODO contracts** — at the next pass permitted to delete, harvest the re-accumulated `[x]` rows into CHANGELOG (docs-health contract), and decide whether queue closure rows are exempt.
7. **Smoke FAIL strings must name the probed artifact** (the paperless FAIL pointed investigators at the config for 3 days while the bug was the check's own path).
8. **Single canonical /data damage-set doc** — victims + scrub evidence + pinning timeline in ONE place; other surfaces link instead of restating state (the GGUF resolution went stale in AGENTS within hours for exactly this reason).

## f) NEXT THINGS

43 items appended to TODO_LIST ("Added 2026-09-13 01:45" section): 40 tasks + 3 owner questions. Highest leverage, in order:

1. **Deploy** (hermes cron fix + pool-smart + btrfs-rescue are all stacked, verified, un-deployed) → post-deploy verification bundles for each.
2. **Build the verify-before-harvest + resolution-grep rules** (docs-health HARVEST + dispatcher) — the two phantoms of this window never recur.
3. **User steps that unblock the two blocked services**: Google Console flip + `main` re-consent; Miniflux link flow + one SSO login, then the one-line flip.
4. **Root-cause the gmail-tag PATCH rejection** and assess the stale-historyId / papersync blind-window exposure before `main` comes back.
5. **Pre-commit fast path** so gitleaks stops being skipped.
6. Then the long tail: runbook gate-proof blocks, VM-test extensions, smoke-string nameability, archive/ consolidation, damage-set inventory.

## g) QUESTIONS (owner-only)

1. **Deploy timing:** the hermes cron fix, pool-smart metrics, and btrfs-rescue all await `nix run .#deploy` — should the deploy ride the same window as the owed :52626-corpse reboot (reboot → deploy → verify) or run standalone first?
2. **InboxClean `work` history:** `work` is alive 14 days past its recorded Aug-29 grant while `main` died exactly on schedule — was `work` silently re-consented, and is the Google Cloud Console consent screen now "In production"? (Determines whether `main`'s re-consent needs the flip first, and whether `work` still carries the 7-day bomb.)
3. **Go-live evidence policy:** is a store-cached VM-test green acceptable go-live evidence for the Hermes cron fix, or do you want one fresh uncached `checks.x86_64-linux.hermes` run before deploying?

---

## Docs-health pass actions (this pass)

- **Annotated (inline, non-destructive):** the two live reports still carrying the falsified email-smoke premise (`2026-09-11_07-21` item 39, `2026-09-12_00-42` item 12) now point at the no-bug closure. The third stale instance (`2026-09-06_07-16`) is already in `archived/`.
- **Archived (`git mv` → `docs/status/archived/`):** four window reports whose work is fully done and which nothing references: `2026-09-12_03-54` (GGUF), `04-13` (InboxClean), `04-37` (Miniflux self-audit), `06-20` (decrypt self-review). `00-42` and `00-59` stay in `docs/status/` — they are cited by live reports (`00-59` ← `2026-09-13_00-19`; `00-42` ← `00-59`).
- **Living docs reconciled:** CHANGELOG gained entries for the four verifiably-shipped-but-undocumented features found in passing (Miniflux service, Hermes restart-safe cron dispatch, pool SMART metrics + dashboard overhaul, btrfs-rescue tier). FEATURES gained Miniflux / pool-SMART / btrfs-rescue rows, the Hermes cron-fix note, a corrected FastFlowLM entry (the "retry gated on a 7.2.2 reboot" premise was falsified 2026-09-11 — amdxdna is byte-identical v7.2→v7.2.3), and a fresh `Updated:` stamp. AGENTS.md gained the live-correction on the InboxClean `work`-account 7-day-bomb prediction (falsified 2026-09-12: `work` alive 14 days past its recorded grant — unresolved which hypothesis holds). TODO_LIST banner refreshed; 43 items appended.

*Point-in-time snapshot — 2026-09-13 01:45 CEST. Report per repo task-queue convention; nothing pushed.*
