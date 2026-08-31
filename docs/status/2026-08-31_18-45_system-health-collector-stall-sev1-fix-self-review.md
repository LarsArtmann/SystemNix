# 2026-08-31 18:45 — system-health collector stall (sev1 desktop page) — fix + brutal self-review

**Session scope:** the user's desktop showed a sev1 overlay "system-health-metrics metrics missing or stale".
This report covers ONLY this session's work and what it surfaced. No unrelated research.

---

## TL;DR

`system-health-metrics` wedged 11-28 MIN per run in an unbounded `journalctl --grep` scan (entire 7.2G journal,
page cache charged to the unit's 128M MemoryMax) against a 2-min timer → textfile stale → sev1 paged all afternoon.
Fixed with a bounded scan + hard timeouts + fail-closed gauge; collector now runs in **1.3s flat**,
sev1 alert cleared, 0 unit failures since. Three side-conditions surfaced and are flagged (not mine): flm v1.0.3 NPU
failure (parallel session mid-holdback), BTRFS root chunk-headroom CRITICAL (known P0, now visible), and the
global `DefaultTimeoutStartSec` being phantom on the deployed system.

---

## a) FULLY DONE (verified live)

1. **Root-caused the sev1 page.** Chain: unbounded oomd journal scan → cgroup page-cache reclaim thrash at
   MemoryMax=128M → 11-28 min runs vs 2-min timer → `system_health.prom` stale most of the time →
   sev1-bridge `monitoring-stale` condition → desktop overlay. Evidence: stuck ps tree
   (`journalctl --grep | wc -l` at 12+ min, 1G read, memory pinned 127.9M/128M), journal run durations.
2. **Bounded the oomd scan** (`modules/nixos/services/system-health.nix`):
   - `--since "-24h"` window (measured: full-history ~28 min in-unit vs 24h ≈ 10s cold / ~1s warm)
   - `timeout 60` hard ceiling
   - **journalctl exit-code semantics handled**: journalctl exits **1 when NO entries match** (0 = entries shown,
     ≥2 = real error). First deployed version treated exit 1 as scrape failure (my bug, see §d); fixed with
     `out=$(timeout 60 journalctl … | wc -l) || status=$?` + `[ "$status" -le 1 ]`.
3. **Fail-closed monitoring for the scan**: new gauge `system_oomd_kills_scrape_errors` (0/1); on timeout/error the
   totals are held at last-known (no phantom delta, no phantom reset); Gatus "OOMD Kills" check gained
   `[BODY] == pat(*system_oomd_kills_scrape_errors 0*)` (follows the `system_gatus_meta_scrape_errors` pattern).
4. **Fixed the `sort | head` SIGPIPE unit-killer**: census pipeline `… | sort -rn | head -8` got `|| true`
   (head's early close SIGPIPEs sort → exit 2 "fflush failed" → pipefail+errexit killed the whole unit into
   OnFailure at 17:13, live-observed).
5. **Explicit `TimeoutStartSec = "3min"`** on `system-health-metrics` and `btrfs-health` units — belt for the
   phantom global default (below).
6. **btrfs ioctl wedges hardened** (`platforms/nixos/system/btrfs-health.nix`): `btrfs scrub status`,
   `btrfs-chunk-check` (metrics collector AND gc-guard) all `timeout 30`-wrapped. The gc-guard timeout fails
   CLOSED (UNALLOC defaults 0 → abort GC). Live trigger: `btrfs scrub status /` hung 1h+ from boot 14:31
   (btrfs.prom stale since Aug 30, orphaned `.tmp` from the open emit-block redirect).
7. **Deployed** (after 3 blocked/aborted/killed attempts + 1 corrective deploy — see §d) and **verified live**:
   runs 1.27s wall every 2 min, `system_oomd_kills_total 0` (truthful for the window; stale state-file 87 reset),
   `scrape_errors 0`, sev1 alert file empty, 0 unit failures since 17:37, btrfs.prom fresh.
8. **Pre-deploy bootstrap lifecycle** (`scripts/pre-deploy-check.sh`): added `system_oomd_kills_scrape_errors` to
   `KNOWN_NEW_METRICS` when the §10 phantom-metric gate (correctly) blocked the first deploy; **removed it again
   the same day** after live confirmation, per the list's own rule.
9. **AGENTS.md lessons recorded** (3 bullets): the `--grep`-without-`--since` MemoryMax trap, the journalctl
   exit-1-on-no-match trap + sort/head SIGPIPE, and the phantom global `DefaultTimeoutStartSec`.

## b) PARTIALLY DONE

1. **Gatus "OOMD Kills" green-state**: verified the metrics at source (textfile correct, patterns follow proven
   sibling conventions); did NOT read gatus's sqlite to observe the check actually green. High confidence, unobserved.
2. **`timeout 60` headroom under the unit cgroup**: validated empirically post-deploy (1.3s runs), but the 9.8s
   "measurement" that sized it was run as `lars`, uncapped, warm cache. A cold journal + IO pressure could still
   occasionally exceed 60s → transient `scrape_errors 1` → Gatus flap. Fail-closed, not fail-silent — but the
   false-positive rate is unknown.
3. **Global `DefaultTimeoutStartSec` phantom**: documented (evaluates fine on evo-x2, yet deployed
   `/etc/systemd/system.conf.d/` is EMPTY; a 28-min wedged job was never killed). Root cause NOT found — is it
   nixpkgs option rendering, a stale generation, or the module not being imported into the host? Systemic hole
   affecting EVERY unit on the box; I only patched the two units I touched.

## c) NOT STARTED (deliberately, with reasons)

1. **Regression test for the collector logic** — no VM/unit test written for the oomd counting block
   (no-match → 0 + scrape_errors 0; timeout → held totals + scrape_errors 1). The repo's culture demands one.
2. **MemoryMax headroom bump** (128M → 256M) for the collector — cheap insurance against journal growth; skipped
   to keep the change minimal.
3. **journald size cap** — the 7.2G journal (flm echoes full LLM bodies, `all=true` era) is the amplifier of this
   whole incident class. No `SystemMaxUse` tuning proposed/applied yet.
4. **Repo-wide audits** this incident motivates: all `journalctl` calls for `--since` bounds; all
   `sort|head` / `grep -q` SIGPIPE-prone pipelines; all timer-driven oneshot collectors for explicit
   `TimeoutStartSec`.
5. **flm v1.0.2 holdback deploy** — parallel session's dirty `pkgs/fastflowlm.nix`; I flagged it and did NOT
   deploy their in-flight work (concurrency rules).
6. **BTRFS chunk-headroom runbook** — CRITICAL (5.6 GiB unalloc, 0%) + interrupted scrubs now VISIBLE in fresh
   metrics. Manual balance is a documented USER decision; not executed.

## d) TOTALLY FUCKED UP (honest ledger)

1. **THE BIG ONE: shipped a broken first version and only caught it post-deploy.** My first oomd block used
   `if oomd_out=$(journalctl … | wc -l); then … else SCRAPE_ERRORS=1`. Under the unit's `set -o pipefail`,
   journalctl's no-match exit 1 poisoned the pipeline → `scrape_errors 1` permanently (the 24h window had 0
   kills). I had even "verified" the command pre-deploy — **in my own shell, which lacks pipefail**, so I saw
   exit=0 and concluded it worked. This is EXACTLY the repo's documented "validate with the SAME tool/semantics
   the check uses" trap (python-urlopen-vs-curl class). Cost: one extra deploy cycle + a window of
   fail-closed-red Gatus state. Lesson written into AGENTS.md.
2. **Anticipated the Gatus condition but not the deploy gate.** I added the new metric to gatus-config and got
   blocked by pre-deploy §10 (phantom metric absent on the running system). The bootstrap mechanism is documented
   in AGENTS; I should have run `nix run .#pre-deploy-check` BEFORE the first deploy attempt — it costs seconds.
3. **Deploy churn on a shared box.** 4 deploy attempts in ~1h (1 blocked by §10, 1 killed by my own session
   interruption mid-run, 2 completed). Each restarts services — the discordsync API outage I then waited out was
   very likely caused by MY deploy restarting it (documented 5-11 min startup). I also did not `git status`
   immediately before deploy #3, which raced the parallel session's uncommitted flm holdback (harmless here —
   their edit landed after my build started — but I got lucky, not careful).
4. **Tool sloppiness**: used `rg -rn` (the `-r` is REPLACE, not regex-recursion) twice — once produced mangled
   output I initially misread as a different metric name before catching it. Wasted a diagnostic cycle.
5. **Background-job handling**: let the deploy move to background, then an interruption killed it silently;
   recovery was clean (verified current-system before re-running) but the pattern (long deploys in background
   shells that die with the session) is fragile.

## e) WHAT WE SHOULD IMPROVE (process, from this session)

1. **Pre-deploy the pre-deploy**: when adding any gatus condition/metric, run `nix run .#pre-deploy-check` first —
   it catches the bootstrap-gap class in seconds (this session: one wasted deploy).
2. **Test pipefail semantics with pipefail**: any verification of a pipeline that runs under `set -o pipefail`
   must itself run under pipefail (`bash -o pipefail -c '…'`). Interactive shells mask exit-code contracts.
3. **Every journal read in a collector**: `--since` window + `timeout` + fail-closed gauge. No exceptions —
   make it an auditable rule, then audit.
4. **Every kernel-ioctl call in a collector** (btrfs, nvme, smartctl): `timeout`-wrapped, skip-that-cycle on
   expiry. `btrfs scrub status` hanging 1h was invisible because nothing bounded it.
5. **Root-cause the phantom `DefaultTimeoutStartSec`** — until then, per-unit explicit timeouts are the only real
   guard; an eval-time audit ("every timer-driven oneshot collector MUST set TimeoutStartSec") would encode it.
6. **Cap the journal** (`SystemMaxUse`): 7.2G of journal is an IO trap multiplier for every future collector bug.
7. **Deploy restart cost awareness**: deploys restart discordsync (5-11 min API gap) every time; consider
   deploy.sh ordering or a restart-rationing policy when multiple deploys land in one hour.

## f) NEXT UP TO 50 (from this session's observations only)

**Directly from this incident:**
1. Verify Gatus "OOMD Kills" check green via gatus sqlite (read-only, per repo doctrine).
2. Root-cause phantom `DefaultTimeoutStartSec`: check how nixpkgs renders `systemd.settings.Manager` in the
   pinned rev; check whether the booted generation ever contained it; fix or replace the mechanism.
3. Eval-time audit module: every `systemd.services.<name>` with a timer AND Type=oneshot MUST carry explicit
   `TimeoutStartSec` (the phantom-default defense).
4. Audit ALL `journalctl` invocations repo-wide for `--since`/`-n`/`timeout` bounds (monitor365-server-watchdog,
   niri-health-metrics, watchdogs, deploy/post-deploy scripts).
5. Audit all `| sort | head` / `| grep -q` pipelines in collector scripts for SIGPIPE-under-pipefail.
6. Write a unit test for the oomd collector block (fixture journal: no-match/has-match/timeout paths).
7. Bump `system-health-metrics` MemoryMax 128M → 256M (journal-growth headroom).
8. Add journald `SystemMaxUse` cap (e.g. 2-3G) — shrinks every future journal-walk.
9. Watch one full day of `system_oomd_kills_scrape_errors` for timeout false-positives; tune window/ceiling if any.
10. Consider `-n` early-termination cap on the oomd query (semantics allow "≥N kills" if alerting only needs ≥1).

**Flagged side-conditions (other owners / user decisions):**
11. Land the flm v1.0.2 holdback deploy (parallel session's `pkgs/fastflowlm.nix` dirty change) — flm has been
    down since 14:30 boot (15× `No such device with index '0'` under XRT 2.25).
12. After flm is back: confirm the PapDashboard enricher cold-load feedback loop guard still holds (alert →
    insight → flm socket → 21.6G load — AGENTS-documented risk).
13. BTRFS chunk headroom (CRITICAL, 5.6 GiB unalloc): user decision — emergency-reserve runbook now vs waiting
    for Monday 04:00 balance (gawk fix deployed today; last night's balance died awk-missing).
14. Scrub status `3` (interrupted) on both mounts with `btrfs_scrub_error_free 0` — ties into 13 / scrub deferral.
15. Post-deploy smoke currently ends FAIL:1 (flm) on EVERY deploy — alert-fatigue risk; clears when 11 lands.
16. discordsync 5-11 min API gap per deploy — consider deploy.sh wait-or-skip logic.

**Minor observations logged during the session (uninvestigated):**
17. Pre-deploy WARN "fish startup 267ms" under deploy IO pressure (was 60ms when calm) — threshold flapping?
18. Post-deploy WARN "1 error line in quickshell journal (last 1h)" — not inspected.
19. Deploy-time IO PSI avg10 hits 75-80% (healthy threshold 80%) — deploys themselves are the pressure source;
    consider ionice on build/switch phases.
20. `monitor365-backup.prom` mtime Aug 2 — service disabled, expected; confirm intentional in a docs-health pass.
21. The `.system_health_oomd_state` now holds window-semantics values while any OLD dashboards may assume
    all-history — check SigNoz dashboards for `system_oomd_kills_total` panels.

## g) QUESTIONS FOR THE USER (cannot be determined from the system)

1. **BTRFS CRITICAL now visible (5.6 GiB unalloc):** run the chunk-headroom runbook now
   (`rm /btrfs-emergency-reserve` → verify QUIET → `sudo ionice -c 3 btrfs balance start -dusage=5 -dlimit=2 /`
   → re-provision reserve), or wait for tonight-with-gawk-fixed Monday 04:00 balance? The runbook marks this as
   your call (freeze-incident history).
2. **flm holdback:** the parallel session left `pkgs/fastflowlm.nix` dirty (v1.0.3 → 1.0.2 holdback,
   "retry after reboot into kernel 7.2.2"). Should I verify + deploy their change, or is that session still
   owning the thread? (flm = down since boot; PMA/papdashboard/paperless-ai consumers degraded.)
3. **oomd window semantics:** `system_oomd_kills_total` now means "kills in trailing 24h" (was: all-history).
   Gatus only alerts on the per-collection delta either way — keep 24h, or prefer current-boot-only (`-b 0`)?

---

*State at session end: collector runs 1.27s/2min, `system_oomd_kills_*` truthful, sev1 clear, 0 unit failures.
Tree edits (system-health.nix, btrfs-health.nix, gatus-config.nix, pre-deploy-check.sh, AGENTS.md) committed by
the auto-commit daemon; no secrets touched; deploys left the system on a green collector + flagged flm/btrfs.*
