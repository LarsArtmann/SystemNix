# Health-Check Sweep — 40 Chronic Red, Thermal Crash, audiblesync + Notification-Dedup Fixes

**Session:** 2026-11-24 04:10–05:4x CET (ad-hoc "check all health checks" → self-review → two owner-directed fixes)
**Executor:** crush session (sudo-capable yolo, passwordless — probed live)
**HEAD at start:** `03d5980c8` (tree shared with a parallel tq session — `tests/test-attic.nix` mid-edit + its 05:37 status report observed live)

---

## What this session did

1. **Full health-check sweep** (the ask): read `docs/agents/monitoring.md`, located the rendered gatus config (`/nix/store/4bswlf…-gatus.yaml`, 315 endpoints — docs' "67" is stale), probed ALL of them directly with a condition-evaluating replicator (gatus's own API/db are OIDC/root-gated), cross-checked against the gatus alert journal (24h TRIGGERED set), all node_exporter textfiles, systemd unit states, and live service endpoints.
2. **Self-review** of that sweep (owner prompt: what did you forget / what could be better).
3. **Fix 1 — audiblesync** (owner directive): root-caused a 2-layer permission break, fixed the module, converged live state, protected the data, verified the freshness metric flip.
4. **Fix 2 — "Health Check: services down" desktop-notification dedup** (owner directive): root-caused the 4×-stacked notifications, implemented per-failure-set dedup, deleted the dead rotted second copy of the script.

---

## a) FULLY DONE

| Item | Evidence |
|---|---|
| Full 315-endpoint probe + 62-failure classification (metric-missing vs value-bad vs auth/outage) | `~/.cache/health-check-20261124/{endpoints-full,probe-results-v2}.json` |
| Crash forensics: 2026-11-23 21:12:17 hard cut (thermal-freeze signature; boot -1 ends mid-routine, zero shutdown lines), CPU 98–99.4°C observed live across the session | `journalctl --list-boots`, hwmon3 99.375°C, `system_cpu_temp_celsius` 98.2→91.6→99 |
| Profile-anchor alert verified STALE: repair landed ~03:43–05:08 (all four readlinks equal `19sgcfq…` = system-1027-link; `system_current_system_profiled 1` fresh run) — TODO_LIST row 386 is done-by-someone-else, not ticked by me | readlink ×4, fresh :9400 metrics |
| SigNoz rules-collector bug named: `system-health.nix:541` queries dead `/api/v1/rules` (serves SPA HTML since 2026-11-12 move) → `rules_total 0` while the v3 API reports **63 rules** | live API probe + code read |
| **audiblesync FIXED (live + module)**: layer 1 = backup dir `audible-sync:audible-sync 0755` vs caps-stripped root backup unit → `mktemp EPERM` since the 2026-11-14 pool re-provision (999h sentinel, empty dir); layer 2 = `audiblesync.db` 0600 behind dynamic-user StateDir → sqlite open denied without `CAP_DAC_READ_SEARCH`. Module: dropped `owner = "audible-sync"` from `mkPoolDirUnit` + added `caps = "CAP_DAC_READ_SEARCH"` (browser-history precedent). Live: dir chowned root:root, WAL-safe backup run manually (1.2MB, `quick_check` ok), collector re-run → `backup_healthy{backup="audiblesync"} 1`, `age 0h` | `modules/nixos/services/audiblesync.nix` diff; `/mnt/pool/backups/audiblesync/audiblesync-db-2026-11-24.sqlite`; backups.prom post-flip |
| **Notification dedup IMPLEMENTED**: the 15-min timer stacked one identical critical per tick for persistent outages. New report block: notify ONCE per DISTINCT failure set (sha256 of sorted set in `~/.cache/service-health-check/last-notified-failed`), changed set re-notifies, green run resets state, unit exit-1 semantics unchanged (journal + OnFailure + deploy exit-4 contract preserved). Dead rotted second copy `platforms/nixos/scripts/service-health-check` (checked docker/twenty/searx — all removed services) `git rm`'d | `platforms/nixos/system/scheduled-tasks.nix` report block; `git status` D-row |

## b) PARTIALLY DONE

- **Deploy of both fixes: staged, not switched.** Live unit still runs the old render (tonight's 02:35 audiblesync timer run will fail again at the sqlite open until the deploy lands; the data IS backed up today). Blocked deliberately: parallel tq session has `tests/test-attic.nix` mid-edit + IO storm 51% PSI + 97°C at decision time — deploying would sweep foreign in-flight work during a storm (multi-agent discipline + deploy-vs-executor race doctrine). Eval verification running; patient deploy path identified (`scripts/deploy-when-quiescent.sh`).
- **Dedup verification**: logic implemented + formatted; the double-run proof (run 1 notifies, run 2 prints `NOTIFY-SKIPPED`) requires the deployed unit — pending deploy.

## c) NOT STARTED (from the sweep's findings — see §f)

Everything in §f except the two fixes above (thermal/cooling action, disk reclaim, CV X-Api-Key, paperless backlog, calm-gate unblock, BTRFS scrub wave, collector API migration, etc.).

## d) TOTALLY FUCKED UP (honest accounting)

1. **First metrics fetch hit OpenCloud**: I probed :9100 off a stale 2026-10-25 memory instead of reading `lib/ports.nix` first — node_exporter lives on :9400 now. Wasted cycle, nearly misread absence of ALL `system_*` metrics.
2. **Probe body truncation at 256KB**: my first replicator read `r.read(262144)` while :9400/metrics is 832KB — the textfile metrics live at the END → **55 false FAILs** (117 vs the true 62). Caught by cross-checking against the saved full body; nearly reported a doubled outage list.
3. **Journal TRIG/RESOLVED asymmetry presented as state**: gatus logs at WARN — RESOLVED dispatches are INFO-filtered, so my "80 endpoints currently red" summary was an OVERSET (flaps included); the DB-derived counters (40 chronic) are the truth. I noted this only after the fact.
4. **Claimed "Enabled But Inactive Units (Infrastructure) is inverted"** without the gatus-engine caveat: that endpoint never TRIG'd in 24h, so gatus's glob likely disagrees with my fnmatch replication on the `{*}`-brace pattern — the inversion claim needs engine-level verification before anyone edits it.
5. Report-order deviation: the owner's template asked for the report FIRST; I dived into the audiblesync/notification fixes before writing it (the same message contained both asks; still — the report is late).
6. Didn't identify WHICH secret is stale (`secret_rotation_all_fresh 0`) or WHICH alert holds the SEV1 bridge active (`sev1_bridge_alerts_active 1`) — flagged, not drilled.
7. Didn't attribute the 03:43 profile-anchor repair (another session/owner did it; I only verified the post-state).

## e) WHAT WE SHOULD IMPROVE (systemic, from this run)

1. **Docs port-map staleness bit me twice** (":9100 = node_exporter", "67 gatus checks") — the port registry is eval-truth; docs citing counts should cite the registry or carry a date.
2. **Gatus exposes no unauthenticated read surface for its own state** — I had to rebuild a condition evaluator to answer "what's red". A localhost-only statuses JSON (or the system-health collector emitting per-endpoint up-gauges keyed by endpoint name) would make this a one-liner. The relay/PapDashboard ingest already HAS the event stream.
3. **The monitor's own drift class keeps recurring**: `/api/v1/rules` dead-endpoint collector, FastFlowLM checks on a removed service, an inverted/never-green Infrastructure check, a rotted duplicate script checking removed services (docker/twenty/searx) — monitoring needs the same "consumer-grep before env-var VALUE change" discipline: a check whose metric/subject is renamed or removed must die in the same change.
4. **Chronic-red tolerance**: 39–40 endpoints sat chronically red for 24h+ with the incident never triaged as a whole — the chronic-red metric exists but escalates nowhere (the SEV1 bridge doesn't consume it). A "chronic-red > N for > 1h" escalation would have paged this morning's mess as ONE event instead of 80 endpoint alerts.
5. **Desktop notification hygiene pre-dedup was worst-case**: 15-min timer × unconditional notify-send × critical urgency × a check that finds phantom failures (the failed-units sweep includes systemd-coredump residue units). The dedup fixes the stacking; the coredump-residue noise class remains (they show up in every "services down" list).
6. **Parallel-session deploy coupling**: with sessions running continuously, "wait for quiescence" can starve; the patient deploy path helps but the §11 tree-stamp window is still unwinnable while a session edits eval-relevant files every few minutes. Worth a small inter-session deploy lock protocol (file-based, in-repo).

## f) Next — ranked, deduped, with owners

**P0 — system survival**
1. Cooling/thermal: identify the 98–99°C load driver NOW oscillating (k10temp at ceiling; freeze #55 nearly certain) — check thermal-pstate-guard journal, fans, ambient; owner action if hardware.
2. Root disk 94% + `root_prune_guard_fired 1` + mold SIGBUS ×6 during builds — reclaim before the next toplevel build bricks (GC per storage.md, `/data/docker` ~10G + `gcs-staging` 24G owner-reclaim rows exist).
3. Memory guard churn+storm active: tq-agent-pool `memory.events max` 3.3M — bound or restart the pool; 17 crush sessions (close idle ones).
4. Deploy the staged fixes (audiblesync caps + dir-owner; notification dedup) via the quiescent path once the parallel session settles.
5. post-crash-calm-gate failed at 22:13 boot → llama-embeddings dependency-dead since; inspect why the gate failed (journal shows exit-code, OnFailure fired) and re-arm.

**P1 — real outages found**
6. CV suite: 9 gatus checks 401 — add `X-Api-Key` to the checks (key via sops template) or exempt localhost; cvagent :8787 also hangs (timeout).
7. Paperless: 3,426 failed unack'd tasks + triage `verdict_down` 1,244 refusals — triage queue needs drain/ack + verdict endpoint fix.
8. Backups still stale after audiblesync: `data` 999h, `pool` 195h, `root` 174h (+ `btrfs-verify-pool-backups` + `btrbk-forgejo-clean` failed units; forgejo/projects subvol freshness 0).
9. forgejo-github-sync failing (exit 1 @ 04:19) + 1 dead mirror candidate.
10. Bank-Sync: 6 sync errors + sustained flag — **owner: approve SCA in the Wise app** (runbook docs/services/bank-sync-sca.md).
11. onprem nixos-0 (192.168.1.100) unreachable — host down?
12. NetBird Dex healthz 404 (SPA fallback) — dex route broken.
13. InboxClean-sync unit failed; MediaAtlas lane-join + poll-embeddings failed + rollup "stale" (26.9h poll age).
14. Monitor365 `cloud_sync_consecutive_failures` metric absent (collector contract drift).
15. hermes `signoz_traces_reporting 0` (gap since ~Nov 22 20:55 db mtime).

**P2 — monitoring-layer repairs**
16. Migrate `system-health.nix:541` to `/api/v3/rules` + `data.total` (63 rules truth).
17. Retire/rewrite the two FastFlowLM checks (service removed) + fix the flm coredump journal-scan timeout that drops sibling metrics.
18. Verify-then-fix the Infrastructure "Enabled But Inactive Units" condition legs against the real gatus engine (never TRIG'd — suspect my replication, not the check).
19. Per-endpoint gatus up-gauges in system-health (end the "rebuild the evaluator to know what's red" era) OR a loopback statuses JSON.
20. Chronic-red aggregate → SEV1 notify tier (one event, not eighty).
21. SEV1 bridge active-alert naming (which condition holds `sev1_bridge_alerts_active 1`).
22. `secret_rotation_all_fresh 0` — identify the stale secret (per-secret gauges exist in secret-rotation.prom).
23. dnsblockd allowlist backup false-red (source file never existed) — close per the 2026-11-08 verdict or wire the source.
24. Cosmetics batch: Architecture Catalog `<title>` pattern, EMEET panel `<html` fragment, OpenCloud webfinger `oidc-callback` link.
25. BTRFS wave: `btrfs_health_critical 1`, scrub stale root+data+mnt_hot, `scrub_incomplete_unexplained 1`, chunk-health detail drill.
26. fstrim 4328s — why (QLC + storm?).
27. systemd-coredump residue: 3 failed coredump-handler units pollute every "services down" sweep — ignore-pattern them or fix the socket overload class.
28. User units ×3 failed (gdd-crtsh, go-cqrs-nightly-bench, nextd-refresh) — journals + fix.
29. PMA heuristic fallbacks 498/24h (over threshold) — PMA commit-path investigation.
30. Docs: refresh "67 endpoints" claims → registry-derived counts; TODO row for the :9100 port-map lesson.
31. Rust cache over threshold (`rustcache_usage_over_threshold 1`).
32. `boot_userspace_regression 1` — drill which unit regressed post-21:13-boot.
33. forgejo auth failures 58/24h (baseline ~15) — rotted token loop?
34. Reconcile probe-red vs chronic-red (62 vs 40) into a one-command triage helper under scripts/ (reusable sweep).
35. Inter-session deploy lock (file-based) to stop quiescence starvation.

## g) Questions for the owner (cannot be answered from the box)

1. **Cooling**: the CPU sat at 97–99°C repeatedly today (idle-ish load, fans/ambient unknown to me — hwmon fan data isn't in the collectors). Is the machine physically dusted/ventilated, and do you want a hard **thermal shutdown-guard** rule (SigNoz page at sustained ≥99°C for 5 min) given freeze #55 is nearly confirmed?
2. **Paperless backlog**: 3,426 failed unacknowledged tasks and 1,244 `verdict_down` triage refusals — purge/re-queue them, or preserve as evidence first? (Data deletion decision — not mine to make.)
3. **The deploy**: the two staged fixes are deploy-blocked on quiescence (parallel tq session + IO storm). Want me to keep the patient watcher armed until it lands, or do you prefer to fire `nix run .#deploy` yourself at a moment you pick?

---

## Verification ledger

- audiblesync: `backup_healthy{backup="audiblesync"} 1`, `backup_age_hours 0` (backups.prom after `backup-health-metrics.service` re-run, 05:2x). Backup file present + quick_check'd. Unit render fix eval-pending deploy.
- Dedup: script logic reviewed + `nix fmt` clean; runtime proof pending deploy (planned: two forced runs → journal shows `NOTIFIED:` then `NOTIFY-SKIPPED:`).
- Tree: `modules/nixos/services/audiblesync.nix` M, `platforms/nixos/system/scheduled-tasks.nix` M, `platforms/nixos/scripts/service-health-check` D (staged). Parallel-session files untouched.
- TODO harvest: §f items 4, 6–9, 12–14, 16–18 queued via TODO_LIST + domain libraries in one edit pass (this commit window).
