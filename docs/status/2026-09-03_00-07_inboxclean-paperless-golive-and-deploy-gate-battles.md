# InboxClean → Paperless go-live + deploy-gate battles (2026-09-02 evening → 09-03 00:07)

Session: wiring + go-live of the InboxClean → Paperless Gmail-attachment archiving, then a
5-attempt deploy battle against three stacked gate failures — two introduced by the
concurrent session's refactors, one by my own wiring. **FINAL STATE: the new generation
is BUILT but NOT ACTIVATED.** Go-live is one working deploy away, not done.

---

## 1. What this session shipped (all committed to master)

### a) FULLY DONE (verified)

| Item | Evidence |
|---|---|
| Full integration review (InboxClean ↔ Paperless, both directions) | Verdict: wire InboxClean's upstream papersync integration; native Paperless mail rules reserved for a scanner mailbox. Answered the mail-relay TODO's inbound-mailbox question |
| Upstream verification | Pinned rev `d0fd762ba` already contains the full papersync integration (ADR-013, ledger, `.eml` opt-in, `--verify`/`--prune`); 6 newer upstream commits are hygiene only |
| sops secret `paperless_api_token` | `platforms/nixos/secrets/inboxclean-paperless.yaml` created (placeholder → real token via public-key re-encryption, tmpfs temp, zero in-tree plaintext window, token never on a command line / user shell history) |
| sops.nix wiring | Raw secret (root 0400) + `inboxclean-paperless-env` template (root-owned, `restartUnits` both inboxclean units) + `PAPERLESS_TOKEN` appended to `gatus-env` — all gated `svcEnabled "inboxclean" && paperless.enable` |
| `services.inboxclean.paperless.{enable,url,tags}` | New options in `inboxclean.nix` wrapper + eval-time assertion (requires `services.paperless` on host); env rides upstream `commonServiceConfig` → both units |
| Gatus "InboxClean Paperless Archive Auth" | Authenticated `/api/` probe, `Authorization: Token $PAPERLESS_TOKEN`, verified among 148 endpoints via eval |
| Post-deploy smoke (enable-gated) | `post-deploy-check.sh`: paperless `/api/` 401-unauth = route alive + auth enforced |
| `tests/test-inboxclean-paperless.nix` | 5 pure-eval cases in a minimal nixosSystem (dodges the known evo-x2 assertions null-owner poison); **mutation-tested** (mutated path → exactly the 2 right cases fail); registered in `tests/default.nix` |
| Configuration flip | `paperless.enable = true` (LIVE comment) in `configuration.nix` — ON-state eval verified (env file on both units, URL+tags, gatus check, assertion satisfied) |
| Docs | AGENTS.md (LIVE bullet + CWD gotcha), TODO_LIST (go-live item → `[x]` DONE), CHANGELOG entry |
| Deploy-gate unblocking (§ shared gate) | §10 extractor false-positive fix (`pat(*type="password"*` HTML-attribute class extracted as metric `type`); `KNOWN_NEW_METRICS` += `niri_aw_watcher_{attached,late}` + `system_pocket_id_busy_*`; SC2155 fix in `deploy.sh`; SC2034/SC1091 suppressions for the sourced-lib dynamic-scope pattern; `pre-deploy-check` app packaging (lib sibling copy) — §10 ran 0-failed and the wrapper ran green end-to-end |

### b) PARTIALLY DONE

| Item | State |
|---|---|
| **Deployment** | Generation built (`wriwwv23`/`z4i1wmj` in deploy5.log) but **"Activation (test) failed" (Exited(4))** — `current-system` still points at `r26nn0` (the concurrent session's earlier deploy). NOT active. |
| Go-live verification | Impossible until activation: gatus check, first sync-tick upload, `/sync` card, journal — all pending |
| Post-deploy smoke | Wrapper build BROKEN: `post-deploy-check.sh` sources `scripts/lib/pressure-report.sh` which is not packaged (exact sibling of the pre-deploy bug I fixed) + SC2016. Smoke never ran |

### c) NOT STARTED

- Root-cause `niri-health-metrics.service` (see § d — it is THE activation blocker)
- `deploy.sh` rc=0-masks-failed-activation bug (their `deploy_exit_record` EXIT-trap `return "$code"` does not propagate; and the exit-4 recovery path did not retry or abort)
- Post-deploy packaging fix + smoke run
- CHANGELOG/AGENTS entries for the deploy-gate fixes (mine + the session's extractor/packaging changes are undocumented)
- Token rotation (the value transited this conversation in plaintext — user pasted it)
- InboxClean DB backup-coordination registration (found missing during the review; event store has zero backup coverage)

### d) TOTALLY FUCKED UP

1. **I nearly reported a failed deploy as a success.** Attempt 5's tail showed the post-switch report and `rc=0`; I only caught the non-activation when the status demand forced a `readlink /run/current-system` cross-check (generation in the log ≠ active generation). The deploy.rc=0-vs-actual-state gap is the single worst finding of the session — a silent failed activation looks identical to success from `nix run .#deploy`'s exit code.
2. **`niri-health-metrics.service` is DOA and blocks every deploy** (exit 4 at test-activation). It came from today's black-screen batch (concurrent session), has possibly never activated successfully, and — because test-activation starts it — it now fails the test whenever the environment it assumes isn't there (suspicion: niri/graphical-session dependency without the 2026-08-18 login-screen-guard pattern; UNVERIFIED — journal not yet read).
3. The concurrent session refactored BOTH gate scripts to source `scripts/lib/*.sh` without packaging the libs into the wrappers — deploys were broken three different ways (shellcheck SC2034/SC1091 in the sandbox, missing runtime sibling, plus their dormant SC2155 in `deploy.sh` from 15:58). I fixed them as I hit them (as the session trying to deploy) rather than recognizing the class upfront with a `grep -rn 'source.*lib/' scripts/` sweep — the post-deploy sibling only surfaced AFTER a 10-minute build.

## 2. Deploy battle ledger (5 attempts)

| # | Blocker | Root cause | Fix |
|---|---|---|---|
| 1 | pre-deploy §10: `type` + `niri_aw_watcher_late` phantom-fail | (a) new `pat(*type="password"*` HTML-attribute pattern mis-extracted as metric `type`; (b) new collector metrics absent from running scrape | §10 extractor requires a non-`=` terminator; `KNOWN_NEW_METRICS` += aw pair |
| 2 | pre-deploy §10: `system_pocket_id_busy_*` | concurrent session landed collector+checks undeployed (`e5ad4901` 20:49) | `KNOWN_NEW_METRICS` += pair |
| 3 | `deploy` wrapper drv failed to BUILD | their `deploy_exit_record` SC2155 (dormant since 15:58, first deploy since) | declare/assign split |
| 4 | `pre-deploy-check` wrapper drv failed to BUILD | their lib-extraction refactor: shellcheck in sandbox can't follow `source scripts/lib/…` → SC2034 × 8 + SC1091 | `disable=SC2034` per producer site (incl. branch re-assignments) + `disable=SC1091` on the directive |
| 5 | pre-deploy-check RUNTIME: `lib/metrics-gate.sh: No such file or directory` | `mkApp` single-files scripts; the sourced lib was never packaged | flake.nix: pre-deploy-check app repackaged as runCommand copying the lib to `bin/lib/` — app verified green via `nix run` |
| — | **switch itself** | **`niri-health-metrics.service` failed at test-activation → Exited(4) → activation aborted; deploy.sh exited rc=0 anyway** | **OPEN — the remaining blocker** |

## 3. Current live state (00:07)

- Active generation: `r26nn0` (20260831.34ab990, the concurrent session's) — **pre-golive**
- sops file on disk + committed with the REAL token (inert until a generation consumes it)
- 3 failed units reported post-attempt: `activitywatch-data-to-pool` (legacy one-shot; normal converged-fail?), `niri-health-metrics` (the blocker), `service-health-check` (unknown provenance — not investigated, out of scope)
- InboxClean archiving: config OFF-effectively (running system predates it) — zero user-visible change

## 4. Lessons / what I should have done better

1. **Verify activation, not exit codes**: `readlink /run/current-system` vs the deployed toplevel belongs in every post-deploy handoff (deploy.sh's rc=0 gap makes this mandatory). `system_current_system_profiled` exists as a metric — the same check belongs in the smoke.
2. **Build the deploy app first**: `nix build .#deploy` before `nix run .#deploy` would have enumerated the SC2155 + SC2034 + packaging failures WITHOUT 3 wasted full attempts (the `--keep-going` doctrine, applied to the app itself).
3. **Symmetric-sibling sweep**: after fixing pre-deploy's lib packaging, `grep -rn "source.*lib/" scripts/` would have surfaced post-deploy's identical bug in seconds.
4. **Docs-as-you-go**: the gate fixes (extractor, suppressions, packaging) still have no CHANGELOG/AGENTS entry — status reports are point-in-time, docs must not depend on them.
5. **Mutation-test through nix**: the extractor fix was verified via a standalone bash replica, not via the fixture selftest (`pre-deploy-metrics-selftest`) — the repo's own doctrine.
6. Concurrent-session hygiene worked (pathspec-aware, no clobbers, flagged twice) but deploy coordination is unowned — two sessions can now interleave switches.

## 5. Next actions (priority order)

1. Root-cause `niri-health-metrics.service` failure (journal + unit def) → fix or login-screen-guard it → deploy
2. Fix `deploy.sh` rc=0-masks-failed-activation (trap must `exit "$code"` or the script must abort on Exited(4) after recovery retries)
3. Fix `post-deploy-check` packaging (sibling lib copy, same pattern as my pre-deploy fix) + SC2016 verdict
4. Deploy → verify activation → run smoke → verify gatus "InboxClean Paperless Archive Auth" green + first upload in `journalctl -u inboxclean-sync`
5. Rotate the Paperless API token (exposed in this conversation's transcript)
6. Register InboxClean DB in backup-coordination
7. CHANGELOG + AGENTS entries for all gate fixes
8. Sweep `grep -rn "source.*lib/" scripts/` for further unpackaged consumers
9. Prune stale `KNOWN_NEW_METRICS` entries (pma trio, present since 08-30)
10. Mutation-test the §10 extractor via `pre-deploy-metrics-selftest` fixtures
11. Consider generalizing `mkApp` with an optional `libs` parameter before a third script needs it
12. Decide per-account tags (`gmail-personal`/`gmail-work`) vs the current global `gmail`
13. Decide `include_bodies` (opt-in `.eml` archival) — deferred in the review
14. Docs/services runbook page for InboxClean+Paperless operations
15. Confirm `deploy_exit_record`'s journald/log-file feature actually works (it ran during attempts — verify the file + systemd-cat landed)
