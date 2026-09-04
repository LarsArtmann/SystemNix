# Status: Browser-History Token Provisioning Automation (sops step eliminated)

**Date:** 2026-09-04, 19:45 CEST
**Branch:** `forgejo-hermes-agent` (SystemNix — NOT master, see "Fucked Up" #1)
**Upstream:** browser-history pushed `9b2fe69..8af2d39` (origin/master)
**Question that drove this session:** "Why can't Nix just natively handle it?!?!"

## Answer to the driving question

Nix/sops can never natively ingest a value that only exists inside a human's
clipboard. But the value did NOT have to exist in a UI: the browser-history
server owns the token store, so a **non-interactive mint path** makes the
whole flow machine-provisionable. That path did not exist upstream, so this
session built it. The `bh_` token now never touches sops, git, or a human:
server binary → CLI → root-owned runtime file → agent EnvironmentFile. This
is the same doctrine the repo already uses for Pocket ID client secrets
(`pocket-id-provision`): **user-supplied secrets belong in sops;
machine-provisionable secrets belong in runtime provisioning.**

## Answers to the three questions

### What did I forget?

1. **The branch.** I worked for the entire session believing the tree was
   `master` (per the previous session's summary). It was `forgejo-hermes-agent`
   — another session's branch. My SystemNix commits landed there, and the
   `flake.lock` on this branch was at `4e7604d`, missing BOTH the previous
   session's attribution bump (`9b2fe69`) AND my new CLI (`8af2d39`). I only
   noticed when I went to commit. Deploying from this branch before the bump
   would have shipped a provisioner whose CLI does not exist (the old binary
   would have started a SERVER instead of minting a token and hung until
   TimeoutStartSec).
2. **The branded ID type.** I wrote `ids.UserID("...")` conversions before
   checking the type; `UserID` is `cbid.ID[UserMarker, ulid.ULID]` — a struct,
   not a string. Cost ~3 broken build cycles. `go doc` FIRST would have been
   free.
3. **ShellCheck directive grammar.** I wrote `# shellcheck disable=SC1090 (explanation)`
   — the parenthetical after `disable=` trips SC1125 and fails the
   `writeShellApplication` build (and therefore `nix flake check`, and
   therefore every commit). The concurrent session's em-dash "cleanup"
   converted my em-dash into exactly that parens form; I should have put the
   explanation on its own comment line from the start.
4. **DAC_WRITE.** I granted the provisioner `CAP_DAC_READ_SEARCH` only
   (backup-coordination precedent) — but minting WRITES the server's
   foreign-owned 0600 SQLite files: `SQLITE_READONLY(8)`, VM-proven. Needed
   `CAP_DAC_OVERRIDE` too.
5. **That the hook scans the whole index, not my diff.** My VM test constant
   `vmUserKey = "01ARZ3NDEKTSV4RRFFQ69G5FAV"` (a canonical example ULID)
   tripped the generic-api-key entropy rule and blocked commits until renamed
   to `vmUserULID`.

### What could I have done better?

1. **Read the repo state before writing code** — `git branch --show-current`
   and a lock-rev check would have taken 5 seconds and reframed the whole
   session's baseline (the previous session's lock bump is NOT on this branch).
2. **Type-check my assumptions via `go doc` before writing Go** — the UserID
   struct, the `ParseUserID` constructor, and `AgentTokenStore` signatures
   were all discoverable up front.
3. **Use the edit tools consistently instead of `sed -i`/`perl -pi`** — the
   in-place bash edits invalidated my file-read state twice ("file modified
   since read") and made my own edits look like foreign changes.
4. **Run the VM test EARLY, not after the module was fully wired.** The
   SQLITE_READONLY and fresh-host-no-user behaviors were only discovered by
   the VM test at the end; a first boot of the unit in a VM after writing the
   script would have caught both sooner.
5. **Smoke-test with a REAL ULID the first time.** I fabricated a ULID for the
   first CLI smoke run and got a (correct, but noisy) parse error instead of
   the end-to-end proof.

### What could still be improved?

1. **Provisioner retry on cold boot:** `after=browser-history.service` is not
   enough on a FIRST boot — the server is Type=simple ("active" before it has
   created/migrated the DB), so the CLI can race a missing DB file and fail
   once (deploy.sh's provisioner loop self-heals it, but a small
   `ExecStartPre` wait-for-file or `Restart=on-failure` with a short burst
   would remove the noise).
2. **Rotation visibility:** a rotation rewrites `agent.env`; the agent picks
   it up on its next 5-min tick automatically (EnvironmentFile is read per
   run), but nothing ALERTS that a rotation happened. A journal-grep metric
   (`agent_token rotated` count) would make silent rotations observable.
3. **Remote-agent story:** agents on OTHER machines still need the dashboard
   UI (or sops). If a second machine ever needs the agent, the CLI could grow
   an HTTP admin path guarded by a bootstrap secret — deliberate future work,
   not a gap to fix today.
4. **Upstream `TestUserCountGaugeExposedOnMetrics` isolation bug** (pre-existing,
   fails after any other server-creating test) still unfiled.
5. **`notify-failure@` unit missing in the VM** — the provisioner's OnFailure
   dependency logs a warning in tests (harmless; test-helpers could provide a
   stub).

## DONE

- **Upstream `agent-token ensure` CLI** (browser-history, pushed `8af2d39`):
  non-interactive mint/converge — idempotent re-runs, re-mint after
  revocation, labeled rotation on file loss, duplicate-label cleanup, user
  resolution by email or single-user DB, atomic 0600 token file, plaintext to
  stdout only when `-out` is absent. `api/agent_token_cli.go` +
  `cmd/browser-history-server/main.go` dispatch + 10 regression tests +
  CHANGELOG. Full `go test ./...` exit 0. Binary smoke-tested end-to-end.
- **SystemNix provisioner oneshot** (`browser-history-agent-token-provision`):
  harden + `CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE`, StateDirectory
  `browser-history-agent-token`, onFailure routing, loud fresh-host failure,
  idempotent on every deploy (added to deploy.sh provisioner restart list).
- **Agent rewired:** co-located `tokenFile = mkForce
  /var/lib/browser-history-agent-token/agent.env`; remote agents keep the
  sops hex fallback; server keeps hex token as break-glass (values differ by
  construction).
- **flake.lock → `8af2d39`** (picks up CLI + the `9b2fe69` ingest attribution
  fix; go-sse follows subtree resynced as a side effect).
- **VM test extended and GREEN** (`tests/test-browser-history.nix`): failure
  path without users (asserts the journal names the fix), seeded user → mint
  → root:0600 env file with `bh_` prefix, idempotent re-run, agent runs
  against the provisioned token. Two real bugs it caught: SQLITE_READONLY
  caps gap, plus boot-timing (port timeout raised to 120s).
- **AGENTS.md** Browser History section rewritten (token doctrine,
  attribution fix, caps, remote-agent fallback).
- **`nix flake check` green** (hook-verified three times, including builds).

## PARTIALLY DONE

- **Commit hygiene:** all changes are committed (daemon commits + my
  pathspec commits), but on the `forgejo-hermes-agent` branch, not master.
  Moving them to master (cherry-pick or merge) is a user/owner decision while
  the forgejo-hermes session owns the branch.
- **Gitleaks relief:** the index scan now passes, but the framework-level
  `pre-commit run` tool (different from the repo hook) still reports 11 hits
  repo-wide under its own config — pre-existing, not mine, unfixed.

## NOT STARTED

- **Deploy** (`nix run .#deploy`) — everything is verified but NOT deployed.
  On deploy the provisioner will mint evo-x2's real token automatically; NO
  manual sops step is needed anymore (the previous session's "user must paste
  bh_ into sops" instruction is OBSOLETE).
- **`--full-sync` backfill** to re-stamp the orphaned `user_id=''` rows in
  place (agent CLI flag; needs the deployed bh_ token).
- **Dashboard data verification** after backfill.
- **Helium ingestion volume** (`raw=46, filtered_out=46, kept=0` — noise
  filter drops everything; real profile path still unknown).
- **Upstream filings:** gauge-test isolation bug; v1 env-token anonymous-
  attribution operator warning (a WARN log when an env token is used).

## TOTALLY FUCKED UP (recoverable, but embarrassing)

1. **Worked on the wrong branch for the whole session** — commits sit on
   `forgejo-hermes-agent`; the branch's lock was two upstream revs behind.
   Caught late; fixed by the lock bump. Nothing is lost, but master does not
   yet contain this session's SystemNix work.
2. **Blocked every commit on the box for ~15 minutes** via the ULID-named
   constant (gitleaks) and then the ShellCheck directive — the concurrent
   forgejo-hermes session inherits my hook failures on their commits. Both
   fixed; sorry for the traffic jam.
3. **Three transient commit aborts blamed on the hook** before realizing
   `nix flake check` (with builds) was evaluating a mid-edit tree from the
   concurrent session — I re-ran instead of reading the log the first time;
   the actual failures (SC1125, then the VM) were only surfaced when I read
   `/tmp/nix-check.log` properly.

## Improvements delivered beyond the ask

- Upstream got a genuinely useful CLI (convergent, tested, documented) — any
  deployment of browser-history can now provision agents declaratively.
- The VM test now pins the ENTIRE provisioning loop (failure path included),
  so the next person who touches the token flow gets machine-verified truth.

## Next 50 (prioritized, not all mine to do)

1. OWNER: merge/cherry-pick this branch's browser-history commits to master.
2. Deploy (`nix run .#deploy`) — provisioner mints the real evo-x2 token.
3. Verify journal: `browser-history-agent-token-provision: agent env file written`.
4. Verify `/var/lib/browser-history-agent-token/agent.env` (root, 0600, `bh_`).
5. One-time `--full-sync` backfill (agent binary from unit ExecStart + env
   file; root-readable).
6. Verify dashboard shows attributed data (`user_id` non-empty in DB).
7. Confirm agent pushes still accepted post-attribution-fix (server now 8af2d39).
8. Gatus: confirm browser-history checks green through the deploy.
9. File upstream: `TestUserCountGaugeExposedOnMetrics` isolation bug.
10. File upstream: WARN log when a v1 env (anonymous) token is used.
11. Add rotation-observed metric (journal grep on `agent-token ensure` output).
12. Consider provisioner `Restart=on-failure` + short burst for cold-boot race.
13. Remove the sops `browser-history-env` template from the AGENT side
    (currently the agent's restartUnits entry references it; harmless but stale).
14. Orphan-row cleanup decision: full-sync re-stamps; verify no rows remain
    `user_id=''` afterwards; else `DELETE WHERE user_id=''` (user decision).
15. Helium profile path discovery (real path unknown; `~/.config/helium` wrong).
16. Quantify Helium volume loss (raw/kept ratio) once path is known.
17. Evaluate noise-filter knobs upstream (popup <5s etc.) — maybe CLI flags.
18. Behavioral ingest attribution test (upstream tests exist; run them).
19. SigNoz: confirm browser-history spans still flowing on new rev.
20. Confirm `browser-history.service` restartTriggers picked up 8af2d39 binary.
21. Pre-deploy-check §10 run (metric presence) before the deploy.
22. Post-deploy-check run after the deploy.
23. Update docs/services browser-history runbook (docs/ tree) with the
    provisioner flow.
24. Consider `agent-token list` subcommand for auditability.
25. Consider `agent-token revoke` subcommand (parity with dashboard).
26. Upstream: e2e test for the CLI against a REAL server-created DB (not
    hand-built fixture).
27. ShellCheck the provision script standalone (writers lint already covers).
28. Add the provisioner to `systemd-timer-monitor`/graph sanity (it appears
    automatically).
29. Homepage tile unaffected; verify after deploy anyway.
30. Check `go.mod` floor of browser-history vs nixpkgs go_1_26 (currently fine).
31. Watch for vendorHash drift on the browser-history input bump (source-only
    churn class) — lock already resolved; first deploy confirms.
32. If the forgejo-hermes branch merge touches deploy.sh, re-check my
    provisioner entry survives the merge.
33. Alert-dedup: ensure the fresh-host provisioner failure alert doesn't spam
    (onFailure → Discord; one-shot per deploy is acceptable).
34. Document the two-token doctrine (hex break-glass vs bh_ primary) in the
    service runbook.
35. Test rollback semantics: downgrade lock → agent keeps old token file →
    still works (token survives in DB); confirm in a VM run if cheap.
36. Confirm `agent.env` SELinux/AppArmor N/A (no MAC on this host).
37. Consider passing `-user-email` explicitly on evo-x2 once the real user
    email is known (single-user DB resolves automatically today).
38. Add provisioner journal line with token ID for audit trail (CLI prints it).
39. Evaluate whether `harden{}`'s PrivateTmp breaks mktemp in StateDirectory
    (VM test proved it does NOT — keep as verified fact).
40. Upstream: gendoc for the new CLI subcommand if docs are generated.
41. Sweep for other services that could adopt the same ensure-CLI pattern
    (forgejo? pocket-id already has provisioner).
42. Review `resolveCLIUser` ambiguity error message for operator clarity.
43. Consider `-label` default = hostname to remove a required flag.
44. Add CHANGELOG "Fixed" entry upstream for the SC1125-class footgun? (N/A —
    SystemNix-side; skip.)
45. Re-run `nix flake check` on master after merge (this session validated the
    branch).
46. Update TODO_LIST with the backfill + Helium items (docs-health flow).
47. Close the loop on the previous session's sops plan: the sops file
    `browser-history.yaml` needs NO change; if a `browser_history_agent_db_token`
    placeholder was ever added interactively, remove it.
48. Verify the `browser-history-agent.timer` still fires and pushes after the
    deploy (5-min cadence, journal `batch sent ... accepted=1` with new token).
49. Long-term: upstream admin API for remote agents (bootstrap-secret guarded).
50. Celebrate: the user never pastes a browser-history token again.

## Three questions for the owner

1. **Branch topology:** this session's SystemNix commits (provisioner, lock
   bump 8af2d39, VM test, AGENTS.md) sit on `forgejo-hermes-agent`, not
   master. Do you want them cherry-picked to master now, or ride the
   forgejo-hermes merge?
2. **Deploy window:** the provisioner will mint the REAL evo-x2 token on the
   next deploy, and the backlog of orphaned visits is only visible after the
   `--full-sync` backfill (which re-reads ~19.7k entries and re-stamps rows).
   Deploy now, or after the forgejo-hermes work lands?
3. **Helium volume:** the noise filter drops ~100% of Helium visits
   (`filtered_out=46, kept=0`). IsHelium history even wanted, or should the
   agent skip it entirely (cheaper than filter churn)?
