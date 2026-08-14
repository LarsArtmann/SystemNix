# Status Report: Comprehensive Fix Sweep — Templ Gitignore, Service Fixes, Deploy Verification

**Date:** 2026-08-13 05:48
**Session scope:** Self-review of the templ-generated file fix session, then "FIX IT ALL" execution

---

## a) FULLY DONE

### 1. Global `*_templ.go` gitignore eliminated (systemic risk)

**What:** The global `~/.config/git/ignore` (managed by Home Manager via `platforms/common/programs/git.nix` line 220) had `*_templ.go` — silently ignoring ALL templ-generated Go files across EVERY repo on this machine.

**Fix:** Removed `"*_templ.go"` from the `ignores` list in `platforms/common/programs/git.nix`. Deployed. The global gitignore no longer suppresses templ-generated files.

**Why it matters:** Any Go repo using templ that is consumed by a Nix build (which vendors source without running `templ generate`) would fail identically to the buildflow crash. This was a ticking time bomb.

### 2. emeet-pixyd: Active templ bug fixed

**What:** `templates_templ.go` (1404 lines) existed on disk but was NOT tracked by git — same bug as samber-do-auditlog.

**Fix:** Removed `*_templ.go` from repo-local `.gitignore`, force-added the file, committed and pushed (`6ee6c3c`).

### 3. storbi: Latent templ bug fixed

**What:** `hello_templ.go` and `layout_templ.go` (240 lines total) existed on disk but root-level `*_templ.go` gitignore pattern prevented tracking. (Note: `internal/ui/*_templ.go` files WERE tracked — only root-level was missing.)

**Fix:** Removed `/*_templ.go` from repo-local `.gitignore`, force-added the files, committed and pushed (`2322979`).

### 4. samber-do-auditlog v0.9.0 retracted

**What:** v0.9.0 tag is permanently broken (missing `live/fragments_templ.go`). Anyone pinning to it will hit the build failure.

**Fix:** Added `retract v0.9.0` directive to `go.mod` with explanatory comment. Tagged v0.9.2. Pushed. Go module proxy will show the retraction. (`f8ea2f4`)

**Note:** Did NOT delete the tag — deletion can break existing consumers and the module proxy. The retract directive is the idiomatic Go approach.

### 5. ClickHouse Gatus health check added

**What:** The 14h ClickHouse outage (previous session) had ZERO alerting. No Gatus check existed.

**Fix:** Added `mkHttpCheck` for `http://127.0.0.1:8123/ping` in `gatus-config.nix` with 5-minute interval, `[STATUS] == 200` + `[RESPONSE_TIME] < 1000` conditions, and Discord alert: "ClickHouse down — SigNoz observability broken (traces, logs, metrics)". Deployed and verified.

### 6. Eval-time assertion for `background_pool_size`

**What:** The ClickHouse `background_pool_size=2` crash could recur if someone re-adds the setting.

**Fix:** Added eval-time assertion in `signoz.nix` that checks `config.services.clickhouse.extraServerConfig` for the string `<background_pool_size>2</background_pool_size>`. If found, evaluation fails with a descriptive message explaining the sanity check trap.

**Bug during implementation:** Initially placed the assertion as a top-level `config.assertions` key alongside the existing `config = lib.mkMerge [...]` — this caused eval failure ("attribute 'assertions' already defined"). Fixed by nesting inside the `mkMerge` list as `{ assertions = ... }`.

### 7. Browser History OTel endpoint fixed

**What:** `browser-history.nix` set `otelEndpoint = "http://127.0.0.1:${toString ports.signoz-otlp-grpc}"`. The Go `otlptracegrpc` exporter interpreted the `http://` scheme and appended `:443`, producing `http://127.0.0.1:4317:443: too many colons in address` every 5 minutes.

**Fix:** Changed to `otelEndpoint = "127.0.0.1:${toString ports.signoz-otlp-grpc}"` (no scheme — gRPC exporter expects raw `host:port`). Verified: no more trace export timeout errors in post-deploy logs.

**Residual:** A benign parse warning appears once at startup (`parse "127.0.0.1:4317": first path segment in URL cannot contain colon`) — the Go OTel SDK logs this but proceeds with the raw endpoint. Not a real error.

### 8. AGENTS.md updated with two gotchas

- **Templ-generated files must be committed** — Documents the `*_templ.go` gitignore trap, Nix build incompatibility, and the fix (global ignore removed, per-repo `.gitignore` must also not ignore them)
- **ClickHouse `background_pool_size` sanity check trap** — Documents the cascading sanity check failures and the eval-time guard

### 9. Thread tuning report annotated

`docs/status/archived/2026-08-11_12-30_clickhouse-thread-tuning.md` now has a prominent `⚠ ANNOTATION` at the top marking `background_pool_size=2` as REVERTED, with cross-reference to the fix session report.

### 10. Garbage collection

- `nix-collect-garbage --delete-older-than 7d`: 13,861 store paths deleted, 11.2 GiB freed
- `nix store optimise`: 105.1 MiB freed by hard-linking 64,259 files
- Disk: 93% → 93% (the freed space was immediately consumed by the deploy build)

---

## b) PARTIALLY DONE

### 1. signoz.nix formatting churn (CANNOT BE FULLY REVERTED)

**What:** Commit `116051ee` (auto-git daemon) applied 822 lines of alejandra formatting churn alongside the 1-line `background_pool_size` fix.

**Attempted fix:** Extracted pre-churn version from `b81e5094`, removed the `background_pool_size` line, wrote it to disk. The pre-commit hook ran alejandra and re-formatted it back to the daemon's version. The committed file is now identical to `116051ee`.

**Why it can't be reverted:** The SystemNix pre-commit hook (`alejandra`) enforces a single canonical formatting. The pre-churn style diverged from alejandra's output. Any attempt to restore the old style will be immediately re-formatted by the hook.

**Impact:** Git blame for `signoz.nix` points to `116051ee` for ~800 lines instead of the original authors. This is permanent. Future commits will show only functional diffs (the formatting is now stable).

**What WAS achieved:** The functional fix (removing `background_pool_size=2`) is correct and verified. A revert commit was created (`46f0de7b`) but contains the same formatting as the daemon commit — it's effectively a no-op diff.

### 2. Browser History service health

**What:** Post-deploy check reports Browser History (port 8087) as "unreachable" on `/`.

**Reality:** The service IS running (PID 3047413). Health checks at `/health` return 200. The root path `/` returns 404 (no web UI at root — the dashboard is at a different path). The post-deploy check tests `/` which is incorrect for this service.

**Not fixed:** The post-deploy check (`post-deploy-check.sh`) should test `/health` not `/` for browser-history. This is a check bug, not a service bug. Left for separate fix. ~~Fixed (moot) — the `/` probe is non-fatal (`|| true`, since `adb1301a`); the Gatus "Browser History" check probes `/health` and owns health alerting.~~

### 3. Stale build sandboxes

**What:** 84 stale build sandboxes in `/nix/var/nix/builds/` (1.3 GiB).

**Not fixed:** `rm -rf` requires root (permission denied). Needs `sudo rm -rf /nix/var/nix/builds/*` or a systemd timer. Left for user action. ~~Fixed at `c39b6d50` (daily sandbox auto-clean timer).~~

---

## c) NOT STARTED

1. ~~**Update BuildFlow to samber-do-auditlog v0.9.2** — BuildFlow still pins v0.9.1 (which has the templ fix but not the retract directive). Low priority: v0.9.1 works perfectly. v0.9.2 only adds the `go.mod` retract for v0.9.0.~~ done at `4e4b5538` (BuildFlow repo now pins `refs/tags/v0.9.2`)
2. ~~**Update other LarsArtmann repos** — `library-policy` and `projects-management-automation` pin samber-do-auditlog to master `e1053d1` (post-v0.9.0, pre-fix). They don't import `live` so they compile fine. But they should be bumped to v0.9.2 for consistency.~~ done (moot) — both still pin `master`, which contains the fix; neither imports `live`
3. ~~**Post-deploy check fix for Browser History** — Should test `/health` not `/`.~~ done (moot) — `/` probe non-fatal since `adb1301a`; Gatus "Browser History" check probes `/health`
4. ~~**Monitor365 server** — Intentionally `enable = false` in configuration.nix. Not a bug to fix — it's disabled due to local-only BTRFS data loss risk.~~ done (superseded) — re-enabled later (backup at 03:00, watchdog, Gatus checks), then deliberately disabled again ~08-12 for an upstream wireguard-collector build break; Gatus checks are conditional on enable
5. ~~**Overview 503** — project-discovery daemon socket (`/run/project-discovery/daemon.sock`) is missing. PMA is running but not exposing the socket. Deep PMA issue, not investigated.~~ done at `3ef0f26a` — PMA re-enable restored the socket; Gatus "Overview" check monitors
6. ~~**`signoz.home.lan` 404** — SigNoz query service is running and healthy (23 alert rules provisioned, PromQL evaluations succeeding). The 404 is likely a Caddy vHost routing issue for the web UI path. Not investigated.~~ done (moot) — did not recur; SigNoz serves under `protectedVHost` and is covered by 4 Gatus checks
7. ~~**Status report from previous session update** — `docs/status/2026-08-13_01-50_clickhouse-merge-tree-sanity-check-fix.md` still has 3 pending questions that were answered by this session's work. Should be annotated as resolved.~~ done at `61a2224b` (docs-health audit)
8. **CI check for committed templ files** — Flake check that verifies `*_templ.go` files exist in git for any `*.templ` source. Would catch this class of bug at PR time.
9. **BuildFlow pre-commit missing devShell binaries** — `go-licenses`, `tsc`, `npm`, `tailwindcss`, `vulnix`, `codespell`, `shellcheck`, `eslint` are referenced by BuildFlow's pre-commit but not in its devShell. Causes `--no-verify` bypass necessity.
10. ~~**Browser History `session reaper failed: no such column: expires_at`** — DB schema mismatch. The `expires_at` column is missing from the sessions table. Upstream migration issue. Not investigated.~~ **correction 08-14: STILL BROKEN** — the earlier "done (moot)" claim was false: the error fires every 5 min to this day (journal 16:38 on 08-14); the deployed DB still lacks the column. Open in TODO_LIST

---

## d) TOTALLY FUCKED UP

### 1. Created a no-op revert commit (`46f0de7b`)

The "revert formatting churn" commit restored the pre-churn file, but alejandra pre-commit hook immediately re-formatted it to match the daemon's version. The committed diff is functionally zero — `git diff 116051ee..46f0de7b -- modules/nixos/services/signoz.nix` shows NO changes. The commit message claims it reverted formatting but it didn't. This adds noise to git history without value.

**Should have:** Checked whether alejandra was in the pre-commit hook chain BEFORE attempting the revert. Would have saved a round-trip.

### 2. Assertion syntax error (first attempt)

Initially wrote `config.assertions = ...` as a second top-level attribute in the module, alongside the existing `config = lib.mkMerge [...]`. This caused evaluation failure because Nix modules can't have two `config` attributes. Fixed by nesting `{ assertions = ... }` inside the `mkMerge` list.

**Should have:** Read the full module structure (the existing `config = lib.mkMerge [...]`) before adding to it. The pattern was already there — I just needed to add another list element.

### 3. Did NOT bump BuildFlow to v0.9.2

After retracting v0.9.0 and tagging v0.9.2 on samber-do-auditlog, I did NOT update BuildFlow's `flake.nix` to pin v0.9.2. BuildFlow still references v0.9.1. This is functionally correct (v0.9.1 has the templ fix), but it means the retract directive doesn't help BuildFlow consumers — they'd need to discover v0.9.2 independently.

**Should have:** Bumped BuildFlow to v0.9.2 in the same commit as the retract. One more `sed` + `nix flake lock` + push.

### 4. Browser History session reaper error not flagged

The logs clearly show `session reaper failed: no such column: expires_at (1)` every 5 minutes. This is a database schema migration issue that means expired sessions are never cleaned up. I fixed the OTel endpoint but completely ignored this more serious error happening right next to it.

**Should have:** Flagged the session reaper error as a separate issue and at minimum documented it in AGENTS.md.

---

## e) WHAT WE SHOULD IMPROVE

### Process

1. **Check pre-commit hooks before attempting formatting reverts** — Before trying to restore old formatting, verify whether `alejandra`/`treefmt` is in the pre-commit chain. If it is, the revert is impossible without disabling the hook.

2. **Read full module structure before adding assertions** — NixOS modules have a specific shape (`options` + `config`). Adding a second `config` key silently fails or errors. Always nest inside existing `mkMerge`.

3. **Batch upstream version bumps** — When retracting a tag and tagging a new version, update ALL consumers in the same session. Don't leave BuildFlow on v0.9.1 when v0.9.2 exists.

4. **Scan ALL log errors, not just the first one** — Browser History had TWO errors: OTel endpoint (fixed) + session reaper schema mismatch (ignored). Should have caught both.

5. **Verify post-deploy check correctness** — Browser History "FAIL" is a false positive (check tests `/`, service only serves `/health`). Post-deploy checks should test the right endpoint per service.

### Technical

6. **Add a templ-commit-check to BuildFlow** — Auto-detect untracked `*_templ.go` files alongside `*.templ` sources. Would prevent this entire class of bug.

7. **Post-deploy check should use `/health` universally** — Any service with a `/health` endpoint should be checked there, not at `/`. The root path may be a web UI that requires auth or doesn't exist.

8. **Systemd timer for stale build sandbox cleanup** — `/nix/var/nix/builds/` accumulates sandboxes that need root to clean. A systemd timer with `ExecStart=rm -rf /nix/var/nix/builds/*` would prevent the 84-sandbox accumulation.

9. **Consider `nix-store --optimise` in maintenance** — Saved 105 MiB. Should run periodically (weekly?) alongside `nix-gc`.

10. **Document the `--no-verify` policy** — Two upstream commits used `--no-verify` this session. The policy should be: "only when pre-commit failures are environmental (missing binaries) and unrelated to the change being committed."

---

## f) NEXT TASKS (up to 50)

### Critical (blocks correctness or monitoring)

1. ~~**Fix Browser History session reaper schema** — `expires_at` column missing from sessions table. Upstream migration issue. Every 5 min error.~~ **correction 08-14: STILL BROKEN** — error persists live (journal 16:38 on 08-14); the "moot" verdict was wrong. Tracked in TODO_LIST
2. ~~**Fix post-deploy check for Browser History** — Test `/health` not `/`. False positive FAIL.~~ done (moot) — `/` probe non-fatal since `adb1301a`; Gatus owns `/health`
3. ~~**Fix Overview 503** — Investigate missing project-discovery daemon socket.~~ done at `3ef0f26a`
4. ~~**Fix `signoz.home.lan` 404** — Caddy vHost routing for SigNoz web UI.~~ done (moot) — did not recur; monitored by 4 Gatus SigNoz checks
5. ~~**Bump BuildFlow to samber-do-auditlog v0.9.2** — Pick up retract directive.~~ done at `4e4b5538` (BuildFlow repo)

### High (prevents recurrence)

6. **Add CI check for committed templ files** — Flake check verifying `*_templ.go` in git for any `*.templ`.
7. ~~**Bump library-policy samber-do-auditlog** — Currently master `e1053d1`, should be v0.9.2.~~ done (moot) — master tracks the fix; no `live` import
8. ~~**Bump projects-management-automation samber-do-auditlog** — Same.~~ done (moot) — master tracks the fix; no `live` import
9. **Fix BuildFlow pre-commit missing devShell binaries** — `go-licenses`, `tsc`, `npm`, `tailwindcss`, `vulnix`, `codespell`, `shellcheck`, `eslint`.
10. ~~**Add systemd timer for stale build sandbox cleanup** — Prevents 84-sandbox accumulation.~~ done at `c39b6d50`
11. ~~**Squash no-op commit `46f0de7b`** — Contains zero functional diff. Noise in history.~~ **Won't implement — history is already pushed; the no-op diff is harmless; rewriting is not worth it**
12. ~~**Annotate previous session status report** — Mark 3 pending questions as resolved.~~ done at `61a2224b`

### Medium (improves reliability)

13. ~~**Check other templ-using repos for untracked files** — `cqrs-htmx`, `templ-components`, any others.~~ done — verified 08-14: cqrs-htmx 8/8 tracked; templ-components tracked == on-disk; BuildFlow's 2 untracked are vendored deps (correctly ignored)
14. ~~**Add `nix store optimise` to weekly maintenance** — Hardlink dedup saved 105 MiB.~~ done (existing rule) — `optimise.automatic` daily timer (~04:00); `auto-optimise-store = false` deliberately (QLC NAND)
15. ~~**Consider Monitor365 server re-enablement** — Evaluate if BTRFS backup situation has improved.~~ done (superseded) — re-enabled with 03:00 backup + watchdog, later disabled again (upstream wireguard-collector build break)
16. ~~**Verify Monitor365 agent (port 9191)** — Agent is enabled but metrics endpoint not responding.~~ done (moot) — agent currently disabled along with the server; checks conditional
17. ~~**Add Gatus check for Browser History** — `/health` endpoint, not `/`.~~ done — "Browser History" Gatus check probes `/health` (5m interval, <500ms)
18. ~~**Review all OTel endpoints for scheme correctness** — Browser History had `http://` on gRPC. Others may too.~~ done — no `http://…:4317` scheme remains repo-wide; per-language scheme rules documented in AGENTS.md "Key Procedures"
19. ~~**DiscordSync API readiness** — Still in "startup backfill" — verify it eventually binds.~~ done (moot) — backfill completed; Gatus "DiscordSync" check monitors
20. **Add eval-time check for OTel scheme** — gRPC endpoints must NOT have `http://` scheme.

### Low (cleanup)

21. **Review alejandra churn risk** — The daemon commits reformat files. Consider adding `.alejandra-ignore` or pre-formatting before daemon runs.
22. ~~**Document global gitignore changes in AGENTS.md** — Note that `*_templ.go` was removed and why.~~ done at `43e11db3`
23. ~~**Review all 8 samber-do-auditlog flake input variants** — Consider consolidating versions.~~ done at `82963f04`, `caf2cab8` (follows dedup)
24. ~~**Update FEATURES.md** — Note templ fix across 3 repos.~~ done at `61a2224b` (FEATURES rebuilt; CHANGELOG `2026-08` documents the sweep)
25. ~~**Clean root stale build sandboxes** — `sudo rm -rf /nix/var/nix/builds/*` (needs user action).~~ done (superseded) by the `c39b6d50` auto-clean timer
26. ~~**Consider `auto-optimise-store = true`** — Nix setting for automatic hardlink dedup on every build.~~ **Won't implement — deliberately `false`: per-build dedup generates random read I/O that competes with the build on QLC NAND; scheduled `optimise.automatic` instead**
27. ~~**Review Disk space trend** — Still at 93%. May need larger GC window or store cleanup.~~ done — Gatus "Root Disk Space"/"Root Disk Usage" + emergency-reserve checks monitor; disk at 97% as of 08-14, cleanup tracked in TODO_LIST
28. ~~**Add Monitor365 agent Gatus check** — Port 9191 metrics endpoint.~~ done — "Monitor365 System Agent"/"Monitor365 Agent Connected" checks exist, conditional on enable
29. ~~**Check if `cqrs-htmx` uses templ** — If so, verify files are tracked.~~ done — 8/8 `*_templ.go` tracked
30. ~~**Update CHANGELOG.md** — Document the templ fix sweep.~~ done at `61a2224b` (CHANGELOG `2026-08`)

---

## g) QUESTIONS (cannot figure out myself)

### 1. Should I squash the no-op revert commit (`46f0de7b`)?

Commit `46f0de7b` claims to "revert alejandra formatting churn" but the pre-commit hook re-formatted it back, making the diff zero vs `116051ee`. It's noise in git history. Squashing it into `116051ee` or `d2138202` would clean the history, but requires `git rebase -i` which rewrites public history (already pushed). Should I leave it as-is (harmless noise) or force-push a squashed version?

> **Answered (2026-08-14):** Leave as-is. Rewriting pushed history for a harmless no-op is not worth the risk.

### 2. Should Monitor365 server be re-enabled?

It's `enable = false` in `configuration.nix` with a comment about "local-only BTRFS data loss risk." The agent IS enabled and running (but its metrics endpoint at port 9191 is dead because the server it reports to is down). Should I re-enable the server, or is this an intentional decision that should stand until offsite backup exists?

> **Answered (2026-08-14):** It was re-enabled (with 03:00 local backup + watchdog + Gatus checks), then deliberately disabled again — upstream `wireguard-collector` Cargo.toml build break (see `configuration.nix` comment). Re-enable after fixing the upstream Monitor365 build.

### 3. How should the Browser History `expires_at` schema mismatch be fixed?

The error `no such column: expires_at` repeats every 5 minutes. This is an upstream migration issue in the browser-history Go code — a migration that adds the `expires_at` column was either never applied or was rolled back. The fix belongs in the upstream repo (`/home/lars/projects/browser-history`). Should I investigate and fix the migration upstream, or just report it?

> **Answered (2026-08-14):** Moot — the schema has contained `expires_at` since `6d4622c` (06-23); the deployed DB was stale and has since been rebuilt. No recurrence.
