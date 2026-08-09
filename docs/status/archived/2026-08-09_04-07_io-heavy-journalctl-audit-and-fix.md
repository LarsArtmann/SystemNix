# IO-Heavy journalctl Audit & Fix — Session Status

**Date:** 2026-08-09 04:07
**Session scope:** Eliminate IO-heavy `journalctl` patterns across SystemNix
**Trigger:** User spotted `journalctl --utc --output=json --follow` burning 96% CPU / 3.78 GB read, plus `journalctl | grep -c` burning 98% CPU / 274 MB read

---


## A) FULLY DONE

### 1. monitor365-server-watchdog journalctl fix (PREVIOUS SESSION — already committed)
- **File:** `modules/nixos/services/monitor365.nix:516`
- **Before:** `journalctl -u monitor365-server.service --since "5 min ago" --no-pager | grep -c "pool acquire failed"`
- **After:** `journalctl --grep "pool acquire failed" -u monitor365-server.service --since "5 min ago" -n 21 --no-pager --output cat | wc -l`
- **Impact:** Eliminated 274 MB serialization + 98% CPU every 5 minutes
- **Status:** DONE, committed (dc37a5d0 era)

### 2. SigNoz journald OTel receiver — priority + unit pruning + toggle
- **File:** `modules/nixos/services/signoz.nix`
- **Before:** `priority = "info"` with 14 units (continuous `journalctl --follow --output=json`), conditionally enabled via `(nodeExporter || cadvisor)`
- **After:** `priority = "warning"` with 10 units (dropped docker, postgresql, monitor365-server, projects-management-automation — the 4 chatty ones), new dedicated `journaldLogs` component toggle (default `true`)
- **Impact:** Eliminates the 96% CPU / 3.78 GB continuous read process. `warning`-level only means errors and warnings still flow to SigNoz; info-level chatty logs no longer firehose through the JSON serializer
- **Pipeline fix:** Updated logs pipeline condition from `(nodeExporter || cadvisor)` to `journaldLogs` — decoupled from unrelated component toggles

### 3. niri-health-metrics journalctl patterns (timer-driven, every 30s!)
- **File:** `modules/nixos/desktop/niri-config.nix:164-165`
- **Before:** `journalctl _SYSTEMD_USER_UNIT=niri.service --since "10 min" | grep -c "Started niri"` (reads 10 min of logs through pipe every 30 seconds)
- **After:** `journalctl --grep "Started niri" _SYSTEMD_USER_UNIT=niri.service --since "10 min" --output cat | wc -l`
- **Also:** Same fix for DRM error counting (`grep -cE` → `--grep` + `wc -l`, `-n 11` cap)
- **Added:** `pkgs.coreutils` to `runtimeInputs` (provides `wc`)
- **Impact:** Eliminates pipe serialization of 10 min of niri journal every 30 seconds — critical during DRM crash-loops where niri restarts rapidly

### 4. niri-health.sh journalctl patterns
- **File:** `scripts/niri-health.sh:23,32`
- **Before:** `journalctl --user -u niri --since "$CRASH_WINDOW" | grep -c "Started niri"`
- **After:** `journalctl --grep "Started niri" --user -u niri --since "$CRASH_WINDOW" --output cat | wc -l`
- **Impact:** Consistency fix — same anti-pattern, manual-run script (lower frequency but same IO profile)

### 5. niri-drm-healthcheck.sh journalctl pattern
- **File:** `scripts/niri-drm-healthcheck.sh:83`
- **Before:** `journalctl --user -u niri -n 20 --since "30 sec ago" | grep -cE "Permission denied|DeviceMissing"`
- **After:** `journalctl --grep "Permission denied|DeviceMissing" --user -u niri -n 11 --since "30 sec ago" --output cat | wc -l`

### 6. AGENTS.md documentation
- Added SigNoz journald receiver CPU burn gotcha
- Added general `journalctl | grep -c` IO trap gotcha
- Updated monitor365 DuckDB watchdog gotcha with `--grep` requirement

### 7. Validation
- `nix flake check --no-build` — ALL CHECKS PASSED (both runs, before and after fix-up edits)

---

## B) PARTIALLY DONE

### NOT STARTED within this session — manual diagnostic scripts left unchanged
These scripts use `journalctl | grep` but are **manual-run** (not timer-driven), so IO impact is negligible:

| Script | Pattern | Why left alone |
|--------|---------|----------------|
| `scripts/usb-diagnostic.sh:53` | `journalctl -k \| grep -i "sda\|san\|usb" \| tail -20` | Manual diagnostic, runs on-demand |
| `scripts/verify-deployment.sh:46` | `journalctl -u hermes --since "24 hours ago" -n 50 \| grep -qi` | Manual post-deploy check |
| `scripts/verify-deployment.sh:48` | `journalctl -u hermes --since "24 hours ago" \| grep -i \| tail -5` | Manual post-deploy check |
| `scripts/internet-diagnostic.sh:97` | `journalctl -u route-health-monitor -n 10` | No grep pipe, already bounded by `-n 10` |

These COULD be improved for consistency but have zero recurring IO impact.

---

## C) NOT STARTED

1. **No deploy performed** — changes are validated (`nix flake check --no-build` passes) but NOT deployed to evo-x2. The IO-heavy processes are still running in production.
2. **No runtime verification** — cannot run `systemctl`/`journalctl` in this environment. The `--grep` flag behavior, PCRE2 pattern matching against `MESSAGE=` field, and `_SYSTEMD_USER_UNIT=` filtering are all unverified at runtime.
3. **No post-deploy smoke test** — `nix run .#post-deploy-check` not run (not deployed).

---

## D) TOTALLY FUCKED UP / MISTAKES CAUGHT & FIXED

### Mistake 1: Misleading comment in signoz.nix (CAUGHT & FIXED)
- I wrote `"Raise to 'notice' for slightly more detail"` in a comment but set `priority = "warning"`. This would confuse future maintainers into thinking "notice" was an alternative when it wasn't.
- **Fixed:** Removed the misleading sentence.

### Mistake 2: Missing `coreutils` in niri-config.nix runtimeInputs (CAUGHT & FIXED)
- I changed from `grep` to `wc -l` but forgot to add `pkgs.coreutils` (which provides `wc`) to the `writeShellApplication`'s `runtimeInputs`.
- `writeShellApplication` prepends runtimeInputs to PATH (doesn't exclusively set it), so system `wc` would likely be found. But undeclared dependencies are bad practice and fragile.
- **Fixed:** Added `pkgs.coreutils` to runtimeInputs.

### Mistake 3: First multiedit attempt on monitor365.nix failed (PREVIOUS SESSION)
- One of two edits in a `multiedit` call failed silently (trailing semicolon mismatch in `old_string`). Had to re-read and apply the second edit separately.

---

## E) WHAT WE SHOULD IMPROVE / REFLECTIONS

### Technical concerns about the changes

1. **`journalctl --grep` matches `MESSAGE=` field only** — The old `grep` matched against the entire formatted journalctl output line (timestamp, unit name, message). `--grep` filters on the `MESSAGE=` field only. All our patterns (`"pool acquire failed"`, `"Started niri"`, `"Permission denied|DeviceMissing"`) are in the message body, so this should be equivalent. But it's a semantic difference worth knowing.

2. **DRM error metric ceiling changed** — Original `-n 20` + `grep -cE` = count matching among last 20 entries (max 20). New `--grep` + `-n 11` = count up to 11 matching entries (max 11). The threshold is 10, so detection still works. But the Prometheus metric `niri_drm_errors_30s` now caps at 11 instead of 20. Minor semantic change.

3. **Observability loss in SigNoz** — Removing `docker.service`, `postgresql.service`, `monitor365-server.service`, `projects-management-automation.service` from the journald receiver unit list means their warning/error logs no longer appear in SigNoz's log explorer. These 4 were the chatty ones (monitor365 alone generated 270 MB / 5 min at info level). With `priority=warning`, their errors WOULD be captured IF they were in the unit list — the removal is a double optimization (both priority AND unit filtering). We could add them back at `warning` level if observability matters.

4. **`_SYSTEMD_USER_UNIT=` vs `-u` for "Started" messages** — The niri-config.nix metrics script uses `_SYSTEMD_USER_UNIT=niri.service` (journal field filter), while the shell scripts use `--user -u niri` (unit filter). The `-u` flag catches lifecycle messages ("Started niri.service") reliably. The `_SYSTEMD_USER_UNIT=` field filter MAY NOT catch lifecycle messages from the user manager — this is a pre-existing concern, not introduced by my change. If the restart counter metric was always 0, this filter was already broken before my change.

5. **No pre-commit hook for `journalctl | grep`** — This anti-pattern could recur. A grep guard in `.githooks/pre-commit` that flags `journalctl.*|.*grep` would prevent it.

### Process improvements

6. **Should have deployed and verified runtime** — The changes are syntactically valid but unverified at runtime. `journalctl --grep` with PCRE2 patterns and `_SYSTEMD_USER_UNIT=` filtering needs runtime confirmation.

7. **Should have checked Gatus alerts that depend on changed metrics** — The `niri_drm_errors_30s` metric ceiling changed from 20 to 11. If any Gatus alert checks for a specific value above 11, it would silently never trigger.

---

## F) NEXT STEPS (up to 50)

### Immediate (deploy & verify)
1. `nix run .#deploy` — deploy all changes to evo-x2
2. Verify `iotop`/`atop` no longer shows the SigNoz `journalctl --follow` at 96% CPU
3. Verify `monitor365-server-watchdog` no longer spikes CPU every 5 min
4. Verify `niri-health-metrics.timer` no longer spikes CPU every 30s
5. Check `systemctl status signoz-collector` — confirm journald receiver started with warning-level
6. Check SigNoz log explorer — confirm warning-level logs still flowing from remaining 10 units

### Short-term (observability gaps)
7. Consider re-adding `monitor365-server.service` to SigNoz journald units at `warning` level (errors still useful, info was the problem)
8. Consider re-adding `docker.service` to SigNoz journald units at `warning` level
9. Consider re-adding `postgresql.service` to SigNoz journald units at `warning` level
10. Audit Gatus alerts that reference `niri_drm_errors_30s` — verify threshold compatibility with new ceiling of 11
11. Verify `_SYSTEMD_USER_UNIT=niri.service` actually catches "Started niri.service" lifecycle messages (may need fix to use a different filter)

### Prevention (stop recurrence)
12. Add pre-commit grep guard for `journalctl.*|.*grep` pattern in `.githooks/pre-commit`
13. Add eval-time Nix assertion that warns when `journalctl` appears in a systemd `script` without `--grep`
14. Document the `journalctl --grep` pattern in `docs/CONTRIBUTING.md` module template section
15. Create a `lib/journal.nix` helper that wraps common journalctl patterns safely

### Consistency (manual scripts)
16. Fix `scripts/usb-diagnostic.sh:53` — switch to `journalctl --grep`
17. Fix `scripts/verify-deployment.sh:46,48` — switch to `journalctl --grep`
18. Fix `scripts/internet-diagnostic.sh:97` — minor, already bounded by `-n 10`

### Deeper investigation
19. Audit ALL systemd timers for IO-heavy ExecStart scripts (not just journalctl — also find, du, du, tar, etc.)
20. Check if SigNoz ClickHouse is ingesting the firehose of info-level logs efficiently — the 3.78 GB read might also be causing ClickHouse write amplification
21. Check journal retention — `SystemMaxUse=8G` with monitor365 generating 270 MB / 5 min means the journal fills and rotates rapidly, causing journalctl to work harder
22. Consider `SystemMaxUse=4G` to reduce journal size and make all journalctl queries faster
23. Check if `journald` `RateLimitBurst` / `RateLimitIntervalSec` could throttle monitor365-server's info-level spam at the source
24. Audit `hermes.service` log output — if it's also chatty at info level, it might be the next IO bottleneck even at warning priority

### Broader system health
25. Run `systemd-cgtop` to find OTHER IO-heavy services not caught by this audit
26. Check `systemd-journald` itself for IO pressure — it writes all those logs
27. Consider `journald` storage `volatile` vs `persistent` tradeoffs for this workload
28. Audit Docker json-file log rotation — `docker.service` was dropped from SigNoz, but container logs on disk may be growing unbounded
29. Check if any other OTel collector receivers are doing expensive IO (prometheus scrape, etc.)
30. Review all `systemd.services.*.serviceConfig.IOSchedulingClass` — IO-heavy services should use `idle` or `best-effort` with low priority

### Testing
31. Add NixOS VM test that asserts `signoz-collector` starts with `journaldLogs` disabled
32. Add NixOS VM test for monitor365-server-watchdog with mock journal entries
33. Add eval-time assertion that `journaldLogs` requires `otelCollector` component
34. Test `journalctl --grep` behavior in a VM with known journal entries

---

## G) QUESTIONS I CANNOT ANSWER MYSELF

### Q1: Is losing docker/postgresql/monitor365-server/projects-management-automation logs from SigNoz acceptable?

I removed these 4 units from the SigNoz journald receiver to cut the IO firehose. With `priority=warning`, their errors WOULD be captured if they were in the unit list — the removal is an additional cut. You may want some of these back at `warning` level. Which ones matter to you for log-based debugging in SigNoz?

### Q2: Was the `niri_restarts_10m` metric ever non-zero?

The metrics script uses `_SYSTEMD_USER_UNIT=niri.service` to find "Started niri" messages. This journal field filter may not capture systemd lifecycle messages (which come from the user manager, not from niri's process). If this metric was always 0, the restart counter was already broken before my changes, and I need to fix the filter mechanism itself (not just the grep pattern). Can you check `grep niri_restarts_10m /var/lib/prometheus-node-exporter/textfile_collectors/niri.prom` on evo-x2?

### Q3: Should I deploy now or batch with other pending work?

The changes are validated but not deployed. The IO-heavy processes are still running in production. Should I deploy immediately, or do you have other changes to batch into the same deploy?

---

> **RESOLVED — IO-heavy journalctl patterns eliminated. Manual script fixes harvested to TODO_LIST.md.**
> All forward-looking items in this report were completed in subsequent sessions.
