# InboxClean /health timeout FAIL triage + smoke storm-mode landed

- **Date:** 2026-10-10 02:54 → 03:18
- **Trigger:** `FAIL InboxClean - /health exceeded its handler budget (status 'timeout': box under load? …)` — the check's own text names the 2026-10-06 class; this session triaged it to root cause and landed the queue's prescribed durable fix.
- **Repo pin at start:** `480cf300` (HEAD moved twice mid-session via the auto-commit daemon — see §e).
- **Tree state:** shared; one parallel session active the whole time (see §e).

## a. Live triage of the FAIL

1. **PSI confirmed a real storm** (`/proc/pressure/io` some avg10 52→74→61% across the session; load 1min 7→24→9). Not a flaky check.
2. **inboxclean-web is UP and is the deployed rev**: unit ExecStart = `/nix/store/5d3jicd…-inboxclean-171de0d/bin/inboxclean web`, listening `127.0.0.1:8099` (`ss -ltnp`), cgroup alive.
3. **Storm driver identified (read-only /proc/io delta sampling, 5s window):** a parallel session's `buildflow --fix --build-mode=full` (~14 MB/s writes) + `nix flake check --no-build` (~14 MB/s reads) + a second `crush -y` agent (~6.5 MB/s writes). The known busy-deploy class, watched live.
4. **/health probes:** 3× HTTP 503 `{"status":"timeout"}` at exactly **8.00–8.02s** — see §b for why that number is the key evidence.

## b. Research: the "deploy the timeout fix" row was already satisfied

- Upstream master `e067cb5b` (fresh `git ls-remote`); local clone fetched.
- `git merge-base --is-ancestor c4d62a3 171de0d1` → **TRUE**: the fix commit (budget 3s→8s + 60s gmail verdict caching) is in the locked rev.
- Lock `171de0d1` == deployed unit store path rev `171de0d` → **no drift**; the fix is LIVE.
- The 8.00–8.02s probe timings are the runtime proof: the handler runs its full NEW 8s budget before answering `timeout` (the old 3s cap would have cut at ~3s).
- Upstream master is **3 commits ahead** of the lock (`fb6a954` docs + 2 auto-commits) — nothing warranting a re-lock.
- **Close-out:** `TODO_LIST.md` queue row + `docs/todo/services.md` row closed as VERIFIED DEPLOYED (both surfaces, this session); CHANGELOG entry added.

## c. Storm-mode implementation (the [ready] pipeline row)

`systemnix_io_storm_active` in `scripts/lib/pressure-report.sh` (io PSI `some avg60` > 20%, strict; fixture-testable file params; missing-file-safe). Detected ONCE per `post-deploy-check.sh` run → loud banner; then the four named legs (InboxClean /health timeout, CV render smoke ×2, catchall probe, Pocket ID latency probes) use explicit **3-way probes** (pass / STORM-SUSPECT / fail) so the storm branch records NOTHING in the fail set or baseline; first-class `report_storm_suspect` verdict + summary count + re-run-when-calm banner; exit semantics unchanged. Pocket ID's SQLITE_BUSY journal scan deliberately stays FAIL (journal text is evidence, not a latency artifact).

**Mid-course correction (caught by the first live run):** v1 used post-hoc FAIL→SUSPECT conversion (`FAIL-1` + baseline-line removal). Replacement-style legs (InboxClean, CV) never incremented FAIL first, so the summary undercounted (printed 9 FAIL lines, summary said 8) and the baseline removal could have eaten a sibling leg's legitimate entry. v2 removes post-hoc conversion entirely — storm branches simply never record. Lesson: a downgrade helper must be paired 1:1 with the branch that recorded the fail it reverts.

## d. Verification evidence

| # | Proof | Result |
|---|-------|--------|
| 1 | `bash -n` + `shellcheck` (both files) | clean |
| 2 | `scripts/test-post-deploy-pressure.sh` — 5 new detector cases (active/calm/strict-boundary/custom-threshold/missing-file) + all pre-existing cases | SELFTEST OK |
| 3 | Live run 1 (io avg60 74%): banner fired; InboxClean timeout + catchall downgraded; baseline kept clean | exposed the §c counter bug |
| 4 | Live run 2 (io avg60 61%): printed FAIL lines == FAIL counter (9); STORM-SUSPECT == 3 (InboxClean timeout, catchall `000`, CV proxy-path); CV loopback render PASSed; baseline = exactly the 9 genuine fails (Forgejo ×5+catchall-subvol set, FastFlowLM, Bank-Sync, Kith CRM), zero storm-leg names | arithmetic exact |
| 5 | Ancestry + deployed-rev + 8s-budget chain (§b) | fix VERIFIED DEPLOYED |

Deferred: `nix flake check --no-build` eval not re-run this session (storm + parallel sessions; the script-only change is fully covered by the direct harness run — the same invocation the `post-deploy-pressure-selftest` flake check performs).

## e. Shared-tree notes

- The auto-commit daemon swept this session's edits mid-flight: `26ee62f3` (lib), `f2727291` (main script v1 + tests), `95e84b71` (main script v2 fix). Contents verified via `git show --stat`; the final `M scripts/post-deploy-check.sh` diff is the v2 correction on top.
- A parallel session (npm/buildcache) edited `TODO_LIST.md` (rows ~71-74), `flake.lock` (crm input `bcaf689`→`2db45bb6`), and `docs/todo/services.md` in `0ecad207`. Not mine, not touched; my row edits in the same files were disjoint-line exact-match edits after re-reading.

## f. Direct follow-ups (harvest status)

1. **Timeout-fix row** → CLOSED both surfaces + CHANGELOG (§b). Harvested by closure.
2. **Storm-mode row** → CLOSED both surfaces + CHANGELOG (§c). Harvested by closure.
3. **Escape-hatch green probe** (`/health` 200 once calm) → storm RESURGED at report time (avg60 back to 54% under the same buildflow cycle); probe still 503@8.02s at 03:14. Harvested as a `[watch]` row in `docs/todo/services.md` — one green probe closes it.
4. Pre-existing `Identify the 30s /health poller on :8099` row — NOT this session's finding, deliberately not harvested (already open in services.md).
