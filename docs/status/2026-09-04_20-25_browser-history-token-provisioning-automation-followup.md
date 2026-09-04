# Status: Browser-History Token Provisioning Automation — Follow-up Snapshot

**Date:** 2026-09-04, 20:25 CEST
**Branch:** `forgejo-hermes-agent` (SystemNix — still NOT master)
**Supersedes:** `docs/status/2026-09-04_19-45_browser-history-token-provisioning-automation.md` (same session; this is the post-settlement state at 20:25)
**Upstream:** browser-history `origin/master` at `8af2d39` (pushed, with `agent-token ensure` CLI + tests + CHANGELOG)

## The one-line answer to "Why can't Nix just natively handle it?!"

Because the token's value originated in a web UI — so I removed the UI from
the loop: upstream `agent-token ensure` CLI + a SystemNix provisioner oneshot
now mint the `bh_` token at deploy time. **No human ever touches a
browser-history token again.**

---

## What did I forget? (this session, complete list)

1. **The branch.** Worked the whole session assuming `master` (per the prior
   session's summary). Actually `forgejo-hermes-agent` — another session's
   branch. All SystemNix commits landed there. The branch's `flake.lock` was
   at `4e7604d`, missing BOTH the prior session's attribution fix (`9b2fe69`)
   AND my CLI (`8af2d39`). A deploy from this branch pre-bump would have
   shipped a provisioner whose CLI doesn't exist — the old binary ignores
   args and STARTS THE SERVER, so the provisioner would have hung a hardened
   socket until TimeoutStartSec. Caught only when I went to commit.
2. **The branded ID type.** `ids.UserID` is `cbid.ID[UserMarker, ulid.ULID]`
   — a struct, not a string. I wrote `ids.UserID("...")` conversions and
   `return ""` error paths before `go doc`-ing it. ~3 broken build cycles for
   something a 5-second doc lookup would have prevented.
3. **ShellCheck directive grammar.** `# shellcheck disable=SC1090 (text)` is
   SC1125 (invalid key=value after directive) and FAILS the
   `writeShellApplication` build → fails `nix flake check` → **blocked every
   commit on the box**. The concurrent session's em-dash cleanup produced
   exactly that parens form from my em-dash version. Directive must stand
   alone on its own line.
4. **Write capability.** I granted the provisioner `CAP_DAC_READ_SEARCH` only
   (copying backup-coordination precedent) — but minting WRITES the server's
   foreign-owned 0600 SQLite files. `SQLITE_READONLY(8)`, VM-proven. Needed
   `CAP_DAC_OVERRIDE` alongside.
5. **gitleaks scans the WHOLE INDEX, not my diff.** My VM-test constant
   `vmUserKey = "01ARZ3NDEKTSV4RRFFQ69G5FAV"` (canonical example ULID) tripped
   the generic-api-key entropy rule and blocked ALL commits box-wide (~15 min
   traffic jam for the concurrent session too). Renamed to `vmUserULID`.
6. **The VM port timeout.** Kept `timeout=30` from the old test; the first
   server boot on a busy builder host exceeded it. Raised to 120s. (Minor,
   but it cost a full VM test cycle.)
7. **That the auto-daemon had already committed my sops.nix / deploy.sh /
   test changes** — I nearly re-committed them; and conversely, because the
   daemon commits bypassed my file-read state, the pre-commit hook never
   alejandra-checked my final `.nix` content (hook said "No staged .nix
   files"). I only verified formatting at 20:25 (`nix fmt -- --ci`: 0
   changed — clean, but by luck, not by process).

## What could I have done better?

1. **Read repo state FIRST** (`git branch --show-current`, lock rev, `git
   status`) before writing any code. Five seconds vs. an hour of misframed
   baseline.
2. **`go doc` every type before writing Go code that touches it** — UserID,
   AgentTokenStore signatures, ParseUserID were all pre-discoverable.
3. **Use edit tools exclusively, never `sed -i`/`perl -pi` on files I'm also
   editing via tools** — the in-place bash edits invalidated my read state
   twice ("file modified since read") and once made ME look like the foreign
   session to myself.
4. **Run the VM test at the first working build, not after full wiring** —
   both real bugs (SQLITE_READONLY, fresh-host failure message) were only
   caught at the end; an early VM run would have caught the caps gap ~30 min
   sooner.
5. **Read the hook failure log the FIRST time.** I retried commits twice
   blaming "concurrent session churn" before properly reading
   `/tmp/nix-check.log` — the SC1125 error was sitting right there in the
   output the whole time.
6. **Not invoke `pre-commit run --files` as a diagnostic** — it's a different
   toolchain from the repo's `.githooks/pre-commit`, uses its own gitleaks
   config (11 false hits), and its trailing-whitespace hook left
   modifications in `docs/status/archived/*.md` that I never verified or
   reverted. My own diagnostic polluted shared state.

## What could still be improved?

1. **Provisioner cold-boot race:** `after=browser-history.service` is not
   enough on a FIRST boot (server is Type=simple — "active" before the DB is
   created/migrated). deploy.sh's provisioner loop self-heals, but a
   wait-for-file `ExecStartPre` or `Restart=on-failure` + short burst would
   remove the one-shot failure noise.
2. **Rotation observability:** a rotation silently rewrites `agent.env`; the
   agent picks it up next 5-min tick, but nothing METRICS it. A
   journal-grep counter (`agent-token ensure` rotated lines) would close it.
3. **Remote agents** (server on another host) still need the dashboard UI.
   If a second machine ever runs the agent: bootstrap-secret-guarded HTTP
   admin path upstream. Deliberate deferral, documented.
4. **The `mkForce` tokenFile override** — justified (two mkDefaults on a
   non-mergeable option conflict) but brittle if upstream ever changes
   option types. An eval-time assertion pinning the expectation would make
   it self-defending.
5. **Upstream test hygiene:** `TestUserCountGaugeExposedOnMetrics` isolation
   bug still unfiled; my CLI tests use a hand-built `users_view` fixture — a
   real-server-created-DB e2e test would pin the schema too.

---

## a) FULLY DONE

- **Upstream `agent-token ensure` CLI** (browser-history `8af2d39` on
  origin/master): convergent mint (idempotent steady state, re-mint after
  revocation, labeled rotation on file loss, duplicate-label cleanup),
  email-or-single-user resolution, atomic 0600 output, plaintext-on-stdout
  only without `-out`. Files: `api/agent_token_cli.go`,
  `api/agent_token_cli_test.go` (10 tests), `cmd/browser-history-server/main.go`
  dispatch, CHANGELOG. Full `go test ./...` exit 0. Compiled-binary smoke
  test verified end-to-end (create → 0600 → idempotent no-op).
- **SystemNix provisioner** `browser-history-agent-token-provision`:
  harden + `CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE`, StateDirectory
  `browser-history-agent-token`, onFailure routing, loud fresh-host failure
  (journal names the fix), added to deploy.sh provisioner restart list.
- **Agent rewiring:** co-located `tokenFile = mkForce
  /var/lib/browser-history-agent-token/agent.env`; remote-agent sops hex
  fallback kept; server keeps hex token as break-glass (values differ by
  construction — the resolveAgentAuth short-circuit trap).
- **flake.lock → `8af2d39`** (also picks up `9b2fe69` ingest attribution;
  go-sse follows subtree resynced).
- **VM test GREEN** (`tests/test-browser-history.nix`): no-user failure path
  (asserts journal message), seeded user → mint → root:0600 `bh_` env file,
  idempotent re-run, agent runs against provisioned token end-to-end. The VM
  test caught the caps bug and the boot-timing issue — it paid for itself.
- **AGENTS.md** Browser History section rewritten (two-token doctrine,
  attribution fix, caps, fresh-host runbook) — committed (`8cdd6d8e`).
- **Everything committed** (working tree clean at 20:25; daemon commits
  `8e7f7a58`, `cad02042`, `8cdd6d8e`, `9c191be3` on `forgejo-hermes-agent`).
- **Final formatting verified** at 20:25: `nix fmt -- --ci` over
  browser-history.nix + test + AGENTS.md → 0 changed.
- **`nix flake check` green** (with builds — hook-verified after the SC1125
  fix).

## b) PARTIALLY DONE

- **Branch placement:** work is committed but on `forgejo-hermes-agent`,
  not master. OWNER decision: cherry-pick now vs. ride the merge.
- **Deploy-readiness:** everything is verified and deploy-safe, but NOT
  deployed. The deploy itself + the post-deploy token mint + backfill are
  the remaining half of the actual "zero data" fix.
- **`docs/status/archived/*.md` trailing-whitespace modifications** left by
  my `pre-commit run` diagnostic — unverified whether the concurrent session
  made some of them; not cleaned up by me (not mine to revert blindly, but I
  created the risk).

## c) NOT STARTED

- **Deploy** (`nix run .#deploy`) — provisioner will mint evo-x2's real
  token automatically. The prior session's "user must create a bh_ token in
  the UI and paste it into sops" instruction is **OBSOLETE — no action
  needed from you**.
- **`--full-sync` backfill** to re-stamp the orphaned `user_id=''` rows in
  place (deterministic visit IDs + INSERT OR REPLACE make it safe and
  resumable).
- **Dashboard verification** after backfill (data actually visible).
- **Helium ingestion volume** (`raw=46, filtered_out=46, kept=0` — the noise
  filter drops ~100%; real profile path still unknown, `~/.config/helium`
  was wrong).
- **Upstream filings:** gauge-test isolation bug; v1 env-token anonymous-
  attribution WARN log.
- **Rotation-observed metric** (see improvements).

## d) TOTALLY FUCKED UP (all recovered, all my fault)

1. **Wrong branch, whole session.** Commits on `forgejo-hermes-agent`;
   branch lock 2 upstream revs behind at session start; master still lacks
   this work. Nothing lost — but the "where am I" check that costs 1 second
   was skipped and cost the session its baseline.
2. **Box-wide commit blockade, twice.** (a) The ULID constant tripped
   gitleaks against the whole index (~15 min); (b) the SC1125 directive
   failure failed `nix flake check` → every commit aborted, including the
   concurrent forgejo-hermes session's. The concurrent session inherited my
   debris. Both fixed; the jam was avoidable (VM-test the script before
   committing; read logs before retrying).
3. **Diagnostic pollution.** `pre-commit run --files` (wrong toolchain) left
   modifications in archived docs I didn't author and never reconciled.
4. **Blamed the hook three times before reading its log.** The real failures
   (SC1125, then the VM) were in `/tmp/nix-check.log` from the first retry.
   Retrying without reading is exactly the anti-pattern this repo's AGENTS.md
   preaches against.

## e) WHAT WE SHOULD IMPROVE

1. Cold-boot DB-race tolerance in the provisioner (wait-for-file or retry).
2. Rotation-observed textfile metric + Gatus condition.
3. Eval-time assertion pinning the `tokenFile = agentEnvFile` expectation.
4. Upstream e2e CLI test against a real server-created DB.
5. `agent-token list` / `revoke` subcommands for CLI parity with dashboard.
6. Upstream WARN when a v1 anonymous env token authenticates (operator
   visibility for exactly the zero-data trap we just escaped).
7. Never allow "formatting hook modified files" to go unreviewed — the
   em-dash cleanup that broke the shellcheck directive came in through
   exactly that door.
8. Session bootstrap ritual for THIS repo: `git branch --show-current` + lock
   rev of the touched input + `git status` — every session, before edit #1.

## f) NEXT 50 (prioritized; owner calls the top ones)

1. OWNER: cherry-pick/merge browser-history commits to master.
2. OWNER: deploy window — `nix run .#deploy`.
3. Watch deploy journal: `agent-token ensure` → "agent env file written".
4. Verify `/var/lib/browser-history-agent-token/agent.env` (root, 0600, `bh_`).
5. Run the one-time `--full-sync` agent backfill.
6. Verify dashboard shows data (user-attributed).
7. Verify journal `batch sent ... accepted=1` with the new token.
8. Confirm provisioner is a no-op on the NEXT deploy (idempotency live).
9. Gatus browser-history checks green through the deploy.
10. Post-deploy-check script run.
11. Pre-deploy-check §10 (metric presence) before the deploy.
12. Confirm server restartTriggers picked up the 8af2d39 binary.
13. SigNoz: browser-history spans still flowing on the new rev.
14. Check no rows remain `user_id=''` after backfill; else cleanup decision.
15. Helium: discover real profile path; quantify volume loss.
16. Decide Helium fate (fix filter vs. skip browser entirely).
17. File upstream: gauge-test isolation bug.
18. File upstream: v1 env-token WARN log.
19. Add rotation-observed metric (journal grep).
20. Provisioner cold-boot retry/wait.
21. Eval-time assertion on tokenFile override.
22. Upstream CLI e2e test vs. real server DB.
23. `agent-token list` / `revoke` subcommands.
24. Update `docs/services/` browser-history runbook with the provisioner flow.
25. Reconcile/revert the `docs/status/archived/*.md` whitespace mods.
26. Update TODO_LIST with backfill + Helium items (docs-health flow).
27. Confirm the sops `browser-history.yaml` needs NO `browser_history_agent_db_token`
    (prior plan obsolete — remove any placeholder if one was added).
28. Verify agent timer still fires post-deploy (5-min cadence).
29. Confirm onFailure wiring alerts if the provisioner ever fails on evo-x2.
30. VendorHash watch on the 8af2d39 bump at first real build (source-churn class).
31. If forgejo-hermes merge touches deploy.sh, re-verify my provisioner entry.
32. Re-run full `nix flake check` on master post-merge.
33. Add `-user-email` explicitly once the real account email is confirmed.
34. Audit token ID in provisioner journal (audit trail; CLI prints it).
35. Consider `-label` default = hostname (drop a required flag).
36. Rollback semantics note: downgraded lock + existing token file still
    works (token lives in DB) — document, don't test unless cheap.
37. Sweep other LarsArtmann services for the same ensure-CLI pattern.
38. README/docs: document the CLI in browser-history's README.
39. gendoc for the subcommand if docs are auto-generated upstream.
40. Check `machineId` option requirement messaging (future hosts get a clear
    eval error if unset — verify message quality).
41. Review `resolveCLIUser` ambiguity error for operator clarity.
42. Ensure `browser-history-env` sops template restartUnits list dropping the
    agent isn't needed (it's harmless — verify and close).
43. Tag browser-history (e.g. v0.x with the CLI) so SystemNix pins semver.
44. Consider CHANGELOG "Unreleased" → release cut if other items landed.
45. Verify `notify-failure@` stub in test-helpers (VM warning noise).
46. Backfill runbook: exact one-liner in docs/services (needs root env file
    + agent binary path).
47. Measure backfill duration on evo-x2 (19.7k entries, 10-min ctx budget).
48. Confirm no OTHER service consumed the old hex token as its agent path
    (only evo-x2 agent exists today).
49. Consider making the provisioner unit `PartOf=browser-history.service`
    (restart coupling semantics review).
50. Post-mortem the gitleaks-index-scan cost: pre-commit scanning 26 MB per
    commit is slow — consider scoping to staged diff if gitleaks supports it.

## g) Three questions for the owner

1. **Branch:** cherry-pick the browser-history commits to master now, or let
   them ride the forgejo-hermes-agent merge? (Deploy timing depends on this.)
2. **Deploy + backfill window:** the provisioner mints evo-x2's token on the
   next deploy; visibility of the stranded week requires the `--full-sync`
   backfill afterwards (re-reads ~19.7k entries). Run both at the next
   natural deploy, or do you want a dedicated window?
3. **Helium:** ~100% of its visits are noise-filtered (`kept=0`). Do you
   actually want Helium history? If yes I'll chase the real profile path and
   filter behavior; if no, the cheaper fix is skipping it in the agent.

WAITING FOR INSTRUCTIONS.
