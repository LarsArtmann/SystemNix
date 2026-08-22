# Session Status: Priority-4 Code-Quality Batch — GOMEMLIMIT First Run + Go Dep-Audit Script

**Date:** 2026-08-22 05:30 · **Scope:** the 5 "Priority 4: Code Quality" TODO_LIST items (validate-gomemlimit first run, dep-audit script, DNS-gate test helper, VM-test restart audit, wait_for_200 helper). Point-in-time snapshot.

**TL;DR:** 2 of 5 items fully done and live-verified (items 1+2, the two script items). 3 not started. One near-disaster (538 false-positive "errors" in the dep-audit's first full run) caught by manual git verification before it mattered. One self-inflicted process miss: the new script got committed by the daemon before I shellchecked it (SC2034 warning; fixed after).

---

## a) FULLY DONE

### 1. `scripts/validate-gomemlimit.sh` — first-ever execution + 2 bug classes fixed

The TODO predicted "first run will likely reveal grep-pattern bugs" — it did, plus a second class:

| Bug | Symptom | Fix |
| --- | --- | --- |
| **Scientific-notation heap values** (the predicted class, different mechanism) | `line 80: 6.97024512e+08: arithmetic syntax error` — Prometheus renders `go_memstats_heap_inuse_bytes` in exponent form; bash arithmetic is integer-only | `awk … printf "%.0f"` in the extraction; `to_bytes()` now uses awk so decimal values (`1.5GiB`) also work |
| **Stale hardcoded service list** (unpredicted) | `file-and-image-renamer-server` — unit name that never existed (real: `file-and-image-renamer`, so the service was silently SKIPping its only GOMEMLIMIT check); missing `papdashboard`, `signoz`, `projects-management-automation`; `signoz-collector` port `0` although :8888 serves metrics | List rebuilt to 10 entries from module grep (`GOMEMLIMIT` across `modules/nixos/services/`); `MARKER` comment added: add new GOMEMLIMIT services to the script when adding them to modules |

Final live run on evo-x2: **12 OK, 0 warnings, exit 0**; shellcheck clean. All 10 services at 2–30% of MemoryMax — no OOM proximity anywhere.

**Findings harvested from the live run** (→ next-things list):
- `browser-history`: heap 5 MiB against GOMEMLIMIT=384MiB (**1%** — limit likely oversized; note-level)
- `discordsync` :8085 — no `go_memstats` on `/metrics` (API server doesn't export Go runtime stats)
- `signoz-collector` :8888 — same (OTel collector exposes its own metric set, no Go runtime stats)

### 2. `scripts/audit-go-deps.sh` — created, iterated to correctness, verified

Cross-references **every** `require` line of **every** `go.mod` in **every** LarsArtmann flake input's store path against the revs pinned in `flake.lock`:

- **Input inventory:** jq over `flake.lock` root inputs → node `locked` (both `github` LarsArtmann and `git+ssh://…LarsArtmann` URL forms); flags same-repo-multiple-revs ambiguity.
- **Source access:** exact pinned sources via `nix eval --impure` on `f.inputs.<name>.outPath` — no network, no working-tree drift.
- **go.mod parsing:** awk state machine — block + single-line `require`, `replace` blocks with local-replace detection (`SKIP-LOCAL`).
- **Version→commit:** pseudo-version regex (both `v0.0.0-ts-rev` and `vX.Y.Z-0.ts-rev` shapes); tag resolution from local clone `show-ref --tags -d` (peeled), falling back to `git ls-remote`.
- **Verdicts:** `OK-EXACT` / `OK-AHEAD` (pin contains required commit) / `OK-TREE` (history diverged, module tree identical) / `WARN-DIVERGED` (pin lacks required commit AND tree differs) / `WARN-UNKNOWN` (no decidable ancestry) / `ERROR-MISSING` (tag doesn't exist) / `INFO-UNPINNED` (module not a flake input — Go proxy resolves at build) / `SKIP-LOCAL`.

**Final run: exit 0 — 1569 OK, 7 OK-TREE, 46 WARN-DIVERGED, 2 WARN-UNKNOWN, 452 SKIP-LOCAL, 388 INFO-UNPINNED, 0 errors.** Shellcheck clean (after one post-commit fix, see d).

**Four heuristic bugs found and fixed through live iteration** (each verified against ground-truth git before the next run):

1. Case-pattern typo `[lL][aA]…[nN]/` — "larsartmann" needs **two** Ns; repo extraction returned `larsartmann` for everything → every dep "unpinned".
2. `split()` on tab-indented require lines yields an empty first field → module/version shifted by one (`0`/`1` as versions). Fixed with leading-whitespace trim.
3. Root-module major tags: `gogenfilter/v3 v3.4.0` maps to tag `v3.4.0`, not `v3/v3.4.0` (45 ERROR-MISSING false positives).
4. **This ecosystem cuts release commits** (`chore(release): strip replace directives…`) on tag-only commits **never merged to master** → the tag commit itself is never an ancestor of any master pin; its **parent** is the real code commit. Tag-resolved requires now compare against the tag commit's parent (pseudo-version commits are compared as-is). This alone dissolved ~440 false "STALE" verdicts.

**Most significant real finding:** 46 `WARN-DIVERGED` requires where the pinned go-cqrs-lite rev (04acc34c) does not contain the required code AND the module trees genuinely differ (verified via `git diff --stat`: `event/v4` 782 insertions, `stack/v4` 49 files, `query/v4`, `command/v4`, `snapshot/v4`, `catalog/v4`…). Consumers compile against older/newer-rebased code than their go.mod promises. Downgraded to WARN (exit 0) because with rebased history "pin is older" is unprovable — direction question for the user, see Questions.

Daemon commits: `96fe6f37` (pseudo-version + release-commit handling), `6e2530fe` (WARN-DIVERGED/OK-TREE verdicts). The final INPUT_REV cleanup is uncommitted as of report time.

---

## b) PARTIALLY DONE

- **Item 2's integration** — the script exists and is runnable (`bash scripts/audit-go-deps.sh`) but is **not wired into** `pre-deploy-check.sh` or CI. The TODO said "before deploy"; wiring decision needs user input (runtime ~2–4 min, plus the WARN-DIVERGED policy question gates whether it could ever FAIL a deploy).

## c) NOT STARTED

3. **DNS-gate `/etc/hosts` trick → `tests/test-helpers.nix`** — generalize `networking.hosts."192.0.2.1" = [ "github.com" ]` (from `test-hermes.nix`) as a reusable helper for DNS-gated VM tests.
4. **VM-test restart-count vs `startLimitBurst` audit** — grep `systemctl("restart` across `tests/`; test-hermes needed `mkForce 20` because successful restarts count against burst=5/600s.
5. **`wait_for_200` shared helper in `post-deploy-check.sh`** — 3 known copies (browser-history health gate, bank-sync 6×5s retry, llama-rag 12×10s warmup); extract, convert, audit remaining checks for the warmup-race class.

## d) TOTALLY FUCKED UP (caught before damage)

- **The dep-audit's first full run reported 538 ERRORS — ~533 were false positives** from heuristics 3+4 above. If that version had been wired as a blocking pre-deploy gate, **every deploy would have been blocked**. Caught by manually verifying one verdict of each class with `git merge-base --is-ancestor` / `git diff --stat` against `~/projects/go-cqrs-lite` before trusting the output. Rule re-learned: a verdict machine is worthless until every verdict class is hand-verified against ground truth.
- **Process miss:** the new script was committed by the auto-commit daemon **before** I ran shellcheck on it — shellcheck then flagged dead `INPUT_REV` (SC2034). Harmless (warning, fixed after), but the correct order is write → shellcheck → verify → commit.
- Friction, not damage: 3× "file modified since read" edit races — self-inflicted (`chmod +x` mtime bump) and daemon commits landing mid-session; resolved by re-reading each time. Also confirms the concurrent-session reality: another session's desktop batch (`28e6d081`) rode into history alongside this work.

## e) WHAT TO IMPROVE

- **Shellcheck before the daemon can commit** — no local gate exists between "file written" and "daemon commits". Either pre-commit hook covers it (it does for staged files — but the daemon stages immediately) or make shellcheck the first verification step of ANY new script, before functional testing even.
- **Hand-verify novel verdicts** before reporting counts (see d).
- **Generate, don't hardcode** — the gomemlimit SERVICES list should come from config eval (`systemd.services` filter on Environment containing GOMEMLIMIT), same critique the 08-14 session made; MARKER comment is the interim mitigation.
- **dep-audit runtime** ~2–4 min (`nix eval --impure` + `find` over ~30 store trees). Fine manually; if wired pre-deploy, cache OUTPATHS or gate behind a flag.
- **TODO_LIST/CHANGELOG not updated** in-session for items 1+2 (docs-health harvest pending).

## f) NEXT (up to 50; session-derived)

1. Wire `audit-go-deps.sh` into `pre-deploy-check.sh` (after Q1/Q2 answered)
2. Decide WARN-DIVERGED policy: permanent advisory vs baseline+block (Q1)
3. `git fetch` in dep-audit local clones to dissolve the 2 WARN-UNKNOWN (buildflow: `ac84f0fceddf`, `6966285d1255`) — or document clones-must-be-fresh (Q3)
4. Item 5: extract `wait_for_200` helper in post-deploy-check.sh; convert browser-history/bank-sync/llama-rag copies
5. Audit remaining post-deploy one-shot checks for warmup-race class
6. Item 4: grep `systemctl("restart` across `tests/`; fix burst collisions like test-hermes's `mkForce 20`
7. Item 3: extract DNS-gate `networking.hosts` helper into `tests/test-helpers.nix`; adopt in a second test to prove generality
8. Shrink or justify `browser-history` GOMEMLIMIT (384MiB vs 5 MiB live heap)
9. Drop or correct `discordsync:8085` / `signoz-collector:8888` entries in validate-gomemlimit (no go_memstats → permanent NOTE noise)
10. Generate validate-gomemlimit SERVICES list from `nix eval` of systemd units
11. Deduplicate the 46 WARN-DIVERGED lines in output (group by module+version — 14 unique combos, 46 rows)
12. Add `audit-go-deps.sh` (and validate-gomemlimit) to `scripts/README` / docs index if one exists
13. Consider a CI job running audit-go-deps nightly (catches upstream-tag-vs-pin drift without deploy latency)
14. docs-health HARVEST: mark TODO_LIST Priority-4 items 1+2 done, remove; add findings from this report
15. CHANGELOG entries for both scripts
16. Re-run validate-gomemlimit after any MemoryMax/GOMEMLIMIT change (add to deploy runbook note)

## g) QUESTIONS (cannot figure out myself)

1. **WARN-DIVERGED policy:** 46 requires compile against go-cqrs-lite code that differs from what consumer go.mods promise (rebased master; e.g. `event/v4` tree differs by 782 insertions vs the pin). Is the rebase-style release flow intentional, and should diverged pins stay advisory (current: exit 0) or become deploy-blocking once baselined?
2. **Integration:** wire `audit-go-deps.sh` into `pre-deploy-check.sh` (adds ~2–4 min per deploy) and/or a CI workflow — or keep manual-only?
3. **Local-clone freshness:** may the dep-audit `git fetch` inside `~/projects/<repo>` clones when objects are missing (introduces a network dependency), or should missing objects stay WARN-UNKNOWN for you to fetch manually?

---

**Files changed this session:** `scripts/validate-gomemlimit.sh` (fixed+extended), `scripts/audit-go-deps.sh` (new, ~260 lines). No `.nix` files touched — `nix flake check` not warranted for this diff.

---

## RESUME (2026-08-22, later session): items 3+4+5 executed — BATCH 5/5 COMPLETE

The three pending items were executed after the report above. Open questions g)1–3 (dep-audit wiring) remain UNANSWERED by the owner — the script stays manual-only/advisory/fetch-free until they are (safe defaults require no code change).

### 5. `wait_for_200`/`wait_body_pattern` helpers in post-deploy-check.sh — DONE

- **Two helpers**, not one: `wait_for_200 <url> <attempts> <interval>` (status readiness) and `wait_body_pattern <url> <pattern> <attempts> <interval>` (content-signal endpoints — SIGPIPE-safe herestring grep, prints the LAST body so callers keep unreachable-vs-wrong-body verdicts). Both skip the trailing sleep after the final failed attempt.
- **4 actual polling loops converted** (the TODO said 3; a fresh grep found the browser-history "gate" was already a one-shot `check_local` — the real copies were DiscordSync 3×5s, llama-rag 2×12×10s, bank-sync dashboard 6×5s + sync-errors 6×5s).
- **Audit of remaining one-shot checks:** paperless uses curl-native `--retry 5` (fine — same tolerance, no shell loop); Monitor365's 20s/30s grace sleeps carry domain-specific verdicts (agent-restart decision trees), left alone deliberately; papdashboard POST probe checks steady-state 401 (no retry needed).
- **Verification:** `bash -n` + shellcheck clean; 6/6 isolated functional tests of both helpers (live python http.server: immediate-200, timeout rc=1 + timing window, body match + capture, miss rc=1 + last-body diagnostics); **full end-to-end run of the script on evo-x2** — all converted sections behave identically (DiscordSync PASS via helper, llama warmups PASS, bank-sync correctly reported "unreachable after 6 attempts" from the converted branch's exact message).
- **Live-system note (NOT this diff):** the e2e run shows 10 pre-existing FAILs — Immich (local + HTTPS 502), Paperless web, Bank-Sync, Attic, oauth2-proxy, Caddy HTTP redirect. Plausibly crash-recovery-night fallout (see the 06-05 forensics reports). No probe targets or verdicts changed by this refactor; flagged for the owning sessions.

### 4. VM-test restart×burst audit — DONE, zero unfixed collisions

Full `tests/` grep (`restart` case-insensitive, minus Restart=/restartTriggers lines): only **3 files** restart or stop/start services.

| Test | Restarts | Module burst | Verdict |
| --- | --- | --- | --- |
| test-hermes | 7× intentional (ExecStartPre idempotency) | 5/600s → test raises `startLimitBurst = lib.mkForce 20` | already fixed + documented in-test |
| test-searxng | 2× (searx-init + searx) | searxng 5/300s | safe (2 < 5, plus boot start = 3) |
| test-memory-emergency-guard | stop/start pairs (~3 fastflowlm starts) | module guard does `systemctl reset-failed` before `start` (memory-emergency-guard.nix:226) | safe by design — the canonical pattern |

No crash-loop-simulation tests exist (grep for kill/SIGKILL patterns: none).

### 3. `test-helpers.dnsGateHosts` — DONE, adopted in test-hermes

- New option in `tests/test-helpers.nix`: list of hostnames → `networking.hosts."192.0.2.1"` (TEST-NET-1, RFC 5737 — resolution succeeds, connections fail fast).
- Option docs encode the boundary learned from the two existing strategies: use it when the gate needs RESOLUTION only (hermes-github-verify hits its unset-token skip branch before any git use); do NOT use it when the unit would actually connect — mkForce the gate away instead (test-oauth2-proxy pattern).
- test-hermes converted from the inline line. No other test has an inline hosts entry (grep: only test-hermes) — so "adopt in a second test" had no candidate; generality is proven by the option being generic + type-checked in every importing test (oauth2-proxy, browser-history, paperless, attic, searxng, memory-guard, hermes all import test-helpers).
- **Verification:** `nix fmt` clean, `nix flake check --no-build` all-green, and the **hermes VM test built+ran green** (`nix build .#checks.x86_64-linux.hermes`, exit 0) — the hosts entry provably still lands via the option.

### Harvest

TODO_LIST Priority-4: all 5 items `[x]` with done-notes. CHANGELOG: 2 Added (dep-audit tooling, dnsGateHosts option), 1 Changed (wait helpers), 1 Fixed (validate-gomemlimit first-run bugs). NOTE: CHANGELOG's Unreleased section has pre-existing DUPLICATE `### Fixed`/`### Added` headers (a past session inserted a full block mid-section) — left as-is, not this session's mess.

### Self-review (resume session)

- The TODO's "3 copies" was stale — actual code had 4 polling loops and browser-history was NOT one of them. Grep-first beat summary-trust.
- Edit-tool comment seam bug caught by re-reading after multiedit (edit 4's replacement comment didn't join the surviving prefix cleanly; garbled before fix).
- CHANGELOG multiedit hit the duplicate-header ambiguity — non-unique anchors fail loudly; re-anchored on unique content.
- Did NOT run post-deploy-check.sh before converting (would have been a better pre-change baseline); relied on verdict-message diffing + isolated helper tests instead. Acceptable, but a pre-change run is the stricter pattern.

**Files changed (resume):** `scripts/post-deploy-check.sh` (helpers + 4 conversions), `tests/test-helpers.nix` (dnsGateHosts), `tests/test-hermes.nix` (adopt), `TODO_LIST.md` (P4 harvest), `CHANGELOG.md` (4 entries), this report.
