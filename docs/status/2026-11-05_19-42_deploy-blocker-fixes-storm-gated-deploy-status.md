# Deploy-blocker fixes (§16 icons realize + gate self-heal, crush_events 0600, ci-watchdog answer) — storm-gated deploy

**Scope.** This report covers ONLY this session's work: unblocking the 19:0x `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` attempt (blocked at pre-deploy §16), fixing the actionable warning classes, and the storm-gated deploy decision. VERIFIED live in this session: the icons subset realize + §16-only green (twice, before and after the gate edit), the crush-events writer diff + eval green (drvPath probe), the 27-writer chmod sweep, bank-sync :8097 metrics (609 lines), the ci-watchdog journal (billing annotation verbatim), the textfile EACCES root cause (live prometheus-node-exporter journal naming crush_events.prom), TODO battery `check-todo-system.sh` OK. NOT VERIFIED: the deploy itself (storm-gated, see §e — NOT started), post-deploy behavior of any kind.

---

## §a The §16 blocker: derived-but-never-realized, THIRD occurrence — now self-healing

The 19:0x deploy died at §16 (`PAP_ICONS_DIR /nix/store/zw6lf23…-papdashboard-icons does not exist as a directory`) with everything else green (123 passed / 11 warnings / this 1 failed). Same class as 2026-10-23 and 2026-10-27: eval derives the subset path but nothing realizes it (tile churn ⇒ new subset drv; the running generation anchors only the OLD path; eval does not realize).

1. **Realized the subset** — `nix build --no-link --print-out-paths .#nixosConfigurations.evo-x2.config.systemd.services.papdashboard.environment.PAP_ICONS_DIR` → `zw6lf23…` (the exact probed path; ~40 file copies, seconds). §16-only green: **42 tiles, 40 pack icons + 2 URL, all present**.
2. **Made the gate self-heal** — `scripts/pre-deploy-check.sh` §16 now REALIZES the derivation when `-d` fails (the proven flake-attr build verb) and downgrades to a WARN ("built the subset on the fly"); it fails loudly only if the realize itself breaks (hash mismatch, broken iconPackSrc). Both branches verified by composition: the heal path IS the manual sequence that produced `zw6lf23…`; the fail path re-tested with a fake missing dir (nix build succeeds, `-d` fails → loud fail). `bash -n` + treefmt clean; §16-only re-run green post-edit.
3. The recurring class should now be a WARN, never a deploy block. If it fails again, the drv itself is broken — a different, real problem.

## §b `node_textfile_scrape_error=1` root-caused + fixed at the writer: crush_events.prom was 0600 root:root

Live evidence: `journalctl -u prometheus-node-exporter.service` errors every scrape — `open …/crush_events.prom: permission denied`; the file on disk is `-rw------- root root` (rewritten every ~1m by the collector timer). The writer (crush-events.nix) used `mktemp` (creates 0600) + `mv` (preserves mode) — while **every one of the other 27 textfile writers** in modules/ carries `chmod 644` after mktemp (sweep: grep `mktemp.*\.prom` vs `chmod.*644` — crush-events was the ONLY miss). Fix: the sibling-mandated `chmod 644 "$tmp"` + comment naming the live failure. Eval green with the change; goes live with the next deploy (the timer rewrites the .prom within 1m of switch).

**Rows closed (both surfaces, full-line edits):** TODO_LIST 365 + monitoring.md 14 (the permission-denial fix), TODO_LIST 1408 + monitoring.md 119 (the standing-error root-cause — the 10-12 era's 7 absent families are all PRESENT now per live /metrics + §10 ✓ rows; that cause self-resolved, crush_events re-broke the surface from ~10-30).

## §c ci-watchdog: root cause = the GitHub Actions BILLING BLOCK (owner action, already tracked)

Live journal 18:56: `CI WATCHDOG FAIL: GitHub Actions is BILLING-BLOCKED (annotation: 'recent account payments have failed or your spending limit needs to be increased')` + `conclusion=failure age=456h` + the exact fix command. The unit fails every run BY DESIGN (loud canary); its ~2s exit-1 IS the signal. Not freeze-related (the 03:31:43 pre-crash timing was coincidence). **Rows closed:** TODO_LIST 467 + 1788, services.md 14. The owner-action row (TODO_LIST 495, blocked:user) stays open — GitHub → Billing & plans, then `gh workflow run "Runner Health"`.

## §d Remaining deploy-output warnings: triaged, none agent-actionable

- **bank-sync :8097 "not responding"** — STORM TRANSIENT: service active/running, listening, `/metrics` answers 609 lines live. No defect.
- **cv :8098 + cv-scan failed** — the known rev-independent cv-server SIGSEGV loop (pin-registry root cause, upstream fix pending). Known state.
- **fastflowlm@×6 failed** — residue of the still-listening socket (:52625 LIVE, flm-real idle behind the psi-wait-gate); the in-tree disable rides the next deploy = the real containment (per the 09-58 session's own conclusion).
- **home-lars-tmp.mount failed** — `fsconfig() ENOENT`: subvol `users/lars/tmp` does not exist on the Samsung (only `cache/` + `projects/`); owner-gated repair with mandatory order (`migrate-user-tmp-hot.sh prepare` → deploy → finalize) already fully tracked at docs/todo/storage.md:132 + :237. Not touched.
- **stale build sandboxes (§8) + shadow-split sudo-ticket WARNs (§18)** — both need sudo, which is DEAD in agent shells (2026-11-05 doctrine); the 4h nix-build-cleanup timer covers the sandboxes. Left for owner/daemon.
- **§12 "not built yet" binaries** — expected pre-build; realized by the deploy itself.

## §e The storm: deploy DEFERRED until calm — the user's force flag was NOT silently inherited

The 19:0x entry gate measured io PSI some avg10 98.89% with real disk busy (nvme0n1 + the three DAS disks all ~101%). At session time it is STILL 98.95%, load 1194, 50 D-state. Driver identified via per-scope io.pressure + /proc cwd forensics: **three parallel crush agent sessions running golangci-lint/gopls/go-build waves in OTHER repos** (Zlota44 et al. — NOT this tree; 3 of 5 sampled heavies already exited). No system.slice service above 30 PSI — the storm is 100% user-session tooling.

Decision: a poller waits for io PSI some avg10 < 20 across 3 consecutive minutes, then the deploy fires (its own battery re-owns every gate; per the 2026-10-25 deploy-vs-executor doctrine, no separate §11 probe). The user's `DEPLOY_FORCE_PRESSURE=1` predates this session and the freeze doctrine (both 2026-08-22 freezes had builds as contributing load; freezes #46-48 are <48h old, calm-gates were wired for exactly this class) says a forced full build+switch at load ~1200 is how freeze #49 happens; §16 is fixed and nothing forces the window. Tree is eval-quiescent (no eval-relevant mtime < 5min; only the parallel session's stable home.nix zed desktop-file rename + this session's edits).

**Parallel-session flag (per shared-tree discipline):** `platforms/nixos/users/home.nix` carries a zed desktop-file rename (`zed.desktop` → `dev.zed.Zed.desktop`, 5 mimetype rows) NOT authored by this session — it will ride the deploy; left untouched.

## §f Follow-ups

1. **The deploy itself** (this session, when the poller fires): carries the flm-disable containment, media-atlas WatchdogSec removal, monitor365 tmpfiles mkBefore, crush_events chmod, the §16 self-heal, quotaboard wiring, and the parallel zed rename. This session executes it if the storm drains in-session.
2. **Post-deploy verify battery** (same): anchor discipline (newest `system-N-link` by NUMBER vs `readlink /run/current-system`; full nh/stc process-tree drain), `node_textfile_scrape_error 0` + `crush_events_lines_total` present on :9400, fastflowlm socket+units gone, `ss` :52625 closed.
3. Deliberately NOT harvested as rows: §a/§b fixes are DONE in-tree (rows closed above); the storm itself is another session's active work; the deferred-deploy decision is recorded here, and if the storm outlives this session the deploy remains the standing pending-deploy state the CHANGELOG entries already carry.

**Sources:** deploy output (user-pasted, 19:0x); live probes as cited inline; docs/agents/nix-flakes.md nix-CLI-verbs lesson (2026-10-27); docs/status/2026-11-05_09-58_fastflowlm-disable-self-review-status.md.

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** already-tracked f.1 f.2 (stability.md:298 pending-deploy row) · OBSOLETE f.3 (meta-note)
