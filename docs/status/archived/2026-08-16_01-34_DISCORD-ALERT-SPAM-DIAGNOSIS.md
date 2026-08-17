# Discord Alert Spam — Diagnosis Session (Interrupted Mid-Research)

**Date:** 2026-08-16 01:34 CEST
**Trigger:** User pasted a Discord alert log (9:33 PM–10:51 PM) showing noisy, ugly, duplicated alerts and asked: *"This? Also how can we improve them (Discord Alerts)?"*
**State at interruption:** Root-cause diagnosis ~85% complete, research on fix mechanics ~85% complete. **Zero fixes applied yet.**

---

## The Evidence (user's paste, decoded)

The paste showed 16 Discord messages in ~80 minutes. Decoded against live system state:

| Alert in paste | Verdict | Root cause |
|---|---|---|
| "Systemd Service Failed" fired 4x, resolved 3x | Flapping + **duplicate ruleIds** | Provisioning churn + real failed units (unconfirmed source) |
| "Disk Space Critical (>90%)" fired 2x with DIFFERENT ruleIds | **Duplicate rules** + REAL condition | Provisioning churn + `/` actually at 90.2% |
| "NVMe SSD Spare Blocks Low" fired/resolved repeatedly | **False alert** | Collector reads wrong JSON keys → always 0 |
| "PMA Memory Pressure" resolved 9:33 PM → re-fired 10:14 PM | **Guaranteed flapping** | Threshold (5G) contradicts PMA's 12G/16G retune |
| Messages unreadable: label dumps, `localhost:8080` links, prometheusreceiver internals | Formatting | Default alertmanager templates + missing external URL |

Also: prior session's open question (i) is now **ANSWERED — alerts ARE delivered** to Discord.

---

## a) FULLY DONE

1. **Session-state re-verification** (before the paste arrived):
   - Git: prior session's work was committed at 22:56 (`2b04b3b6`) + daemon bumped Go deps at 23:03. Tree clean at check time.
   - Deployed units verified live: `buildcache-init` has no `ConditionPathExists`, ran clean 22:08; `buildcache-gc` has both `ReadWritePaths` (`/mnt/buildcache` + `~/.cache/pnpm`) and `TimeoutStartSec=45min`; timer = Sun 05:00, `Persistent=true`.
2. **Undid prior session's mistake d.1**: emptied `/mnt/buildcache/.Trash-1000` (33M — the `me/` test photos + `shallow.lock`) via `rm` (documented exception: trash-on-trash frees nothing) and removed the stale root-owned `.initialized` marker. `/mnt/buildcache` now 43% (89G/220G), clean.
3. **Live SigNoz state audit via API** (`localhost:8080/api/v1/rules`, `/api/v1/channels`):
   - 24 rules exist; **3 stale duplicate copies still firing alongside their 21:39-deploy replacements** ("Disk Space Critical" ×2, "Systemd Service Failed" ×2, "NVMe Spare" ×2 with different ruleIds).
   - Channel "Discord Alerts" (id `019fafa0-b278…`, created 07-29) uses `{{ template "discord.default.title"/".message" . }}` — i.e., alertmanager's default label-dump templates. `send_resolved: true`.
4. **Root-caused the four independent causes of the spam** (each verified against source or live data, not assumed):
   - **C1 — Provisioning churn** (`_signoz-scripts.nix:82-111`): every deploy DELETEs + re-creates ALL rules even when unchanged → new ruleId each time → old rule sends fake "RESOLVED", new rule sends "FIRING". Worse: the DELETE is `|| true` (`:93`) and the stale-list is fetched ONCE before the loop (`:84`) — deletes can fail silently and duplicates accumulate (exactly the 3 live stale copies).
   - **C2 — Ugly message bodies**: default templates confirmed in alertmanager source: `discord.default.title` → `__subject` (label dump), `discord.default.message` → `__text_alert_list` (labels + annotations dump). That's why every message contains `github.com/open-telemetry/opentelemetry-collector-contrib/receiver/prometheusreceiver dev Unspecified …` — those are the query-result labels (node-exporter scrape labels) mindlessly serialized.
   - **C3 — `localhost:8080` links**: `ruleSource` label = rule's `GeneratorURL()` = `<alertmanager ExternalURL>/alerts/overview?ruleId=<id>` (verified in `pkg/query-service/rules/base_rule.go:249-254` at our pinned rev `49749626`). Our `signoz.yaml` (`signoz.nix:165-191`) sets no alertmanager external URL → default localhost. Links are useless from Discord.
   - **C4 — PMA memory threshold stale** (`system-health.nix:49`): flat `5 GiB` threshold, but PMA's ceiling was retuned to MemoryHigh=12G/MemoryMax=16G on 2026-08-14 (AGENTS.md documents this). Legitimate scans now exceed 5G by design → the "PMA Memory Pressure" alert flaps forever. The comment at `system-health.nix:47-48` still says "MemoryHigh=6G" — provably stale.
   - **C5 — nvme collector reads nonexistent JSON keys** (`_signoz-metrics.nix:170,174`): emits `node_nvme_available_spare_percent 0` and `node_nvme_percentage_used 0` while the drive is healthy (critical_warning=0, media_errors=0, 44°C, endurance warning flag=0). 0% worn + 0% spare is physically impossible. `extract` uses `jq '.[$key] // 0'` → wrong key names silently become 0. `strings` on nvme-cli 2.16 shows `percentage_used` does NOT exist as a JSON key (short key `percent_used`/`avail_spare` family does; `available_spare` exists — exact key set emitted by the DEPLOYED runtime version still unconfirmed, see g.2). The `below 30` rule fires on the phantom 0 forever.
5. **Verified root disk crisis is REAL**: `/` = 90.2% (630G/723G) — "Disk Space Critical (>90%)" is a genuine condition, not noise (borderline at threshold; every deploy's store-path churn pushes it over).
6. **Verified fix feasibility from upstream source** (not vibes): custom inline `title`/`message` templates on discord channel configs are supported (alertmanager `notify/discord/config.go:28-30`, docs §discord, and SigNoz's own notifier tests); `preferredChannels` per rule already targets "Discord Alerts"; provisioning API shape (GET/POST/DELETE `/api/v1/rules`, GET `/api/v1/channels`) confirmed live.

## b) PARTIALLY DONE

7. **Research: exact config key for alertmanager external URL in `signoz.yaml`** — traced the chain this far: `GeneratorURL ← BaseRule.externalURL ← ManagerOpts.Alertmanager.Config().ExternalURL` (verified in `ee/query-service/rules/manager.go:63,87`). Was actively grepping the alertmanager factory/config schema for the YAML key name when interrupted. ~15 min from done.
8. **Diagnosis: "Systemd Service Failed" flapping** — the query is `node_systemd_units{state="failed"}` (`_signoz-alerts.nix:111`). This metric is NOT in node-exporter's standard output and I found no textfile collector emitting it; the alert's labels (`state = failed`, no service name) suggest an unlabeled series. Not root-caused. The 5 pre-existing Gatus FAILs (monitor365, browser-history) are separate.
9. **Incidental findings noticed but not pursued** (in the metrics dump during C5 verification): `monitor365_backup_healthy 0` / age 999h (backup broken — matches known baseline FAIL); `btrfs_scrub_status 3` (interrupted) on both mounts — scrub still never completes due to reboots; `node_btrfs_device_errors_total{device="nvme0n1p8",type="corruption"} 1.8e19` (uint64 -1 sentinel on the /data device — almost certainly a kernel reporting quirk, but unexamined).

## c) NOT STARTED (the fix plan — designed, not written)

10. **Fix C1**: rewrite `signoz-provision` rule deployment → skip when content unchanged (compare desired vs live), delete ALL copies by name (dedupe), VERIFY each delete (no `|| true` on state changes), final convergence assertion (`unique names == expected set`).
11. **Fix C2**: set custom `title`/`message` templates on the Discord channel (create-time + one-time migration since channel is only-created-when-absent — needs a PUT/update path or delete+recreate of the CHANNEL, which is safe because rules reference it by NAME).
12. **Fix C3**: add alertmanager external URL (`https://signoz.${domain}`) to `signoz.yaml` so GeneratorURL/ruleSource links work from Discord.
13. **Fix C4**: replace flat 5 GiB with per-service threshold = 90% of each service's own `MemoryMax` (read from unit config), or at minimum raise to 10G for PMA; update the stale comment.
14. **Fix C5**: correct nvme JSON keys AND remove the silent `// 0` fallback (fail loudly / skip emission when a key is missing — phantom zeros are exactly how this bug hid).
15. Also planned: fix "Systemd Service Failed" rule (query metric that actually exists — e.g. system_health collector's failed-state flags), gates (`nix fmt`, `flake check`), deploy, verify (no duplicate ruleIds, nvme.prom real values, clean alert format), AGENTS.md/CHANGELOG updates.

## d) TOTALLY FUCKED UP (honest ledger)

16. **`rg -rln` typo → false parallel-edit alarm**: I ran `rg -rln 'available_spare'` — `-r` is the REPLACE flag, not part of `-l`. The mangled output showed garbage like `node_nvme_ln_percent` and made me briefly believe a parallel session had rewritten the collector. Cost: one wasted verification round (`git diff --stat` → clean) and a self-correction detour. Lesson: I know `-r` is replace; I typed it anyway. Tool discipline slipped exactly when speed increased.
17. **Wasteful context pull**: fetched the FULL node-exporter `/metrics` (~100 KB) into context to check two metrics. The textfile `.prom` files on disk contained the answer (and I used them next). Should have gone straight to `/var/lib/prometheus-node-exporter/textfile_collectors/`.
18. **Overclaimed C5 root cause**: I said "wrong key names" with high confidence before confirming WHICH keys the deployed runtime emits. Evidence is strong (impossible 0/0 values + `percentage_used` absent from nvme-cli 2.16 strings) but the deployed collector's nvme-cli version + actual JSON output are unverified (needs root). The verify-external-claims standard applies to my own claims too.
19. **Todo list drift**: research task sat `in_progress` across ~6 tool calls of adjacent work; didn't checkpoint statuses as I went. (Repeated pattern from prior sessions.)
20. **Did not check the nvme-metrics service journal** — if the collector is erroring on some runs (e.g. permission), that's an alternative/supplementary cause for C5 flapping. One `journalctl -u nvme-metrics` call would have closed this; not done.

## e) WHAT WE SHOULD IMPROVE (systemic)

21. **Provisioning must be state-preserving**: the delete+recreate pattern is anti-idempotent — it works until it silently doesn't (live proof: 3 zombie rules). Deserves an AGENTS.md gotcha: "provisioners must diff-then-apply and VERIFY deletes; `|| true` on state mutation is a bug".
22. **Silent `// 0` fallbacks in collectors are landmines** (`_signoz-metrics.nix:148`, `nvme-health-monitor.nix:51-55` has the same pattern): a renamed upstream key becomes a permanent phantom-zero metric that feeds alerts. Missing key should be a loud error or omitted sample.
23. **Thresholds must derive from the thing they guard**: memory threshold hardcoded flat while MemoryMax lives one module away is a split brain waiting to fire (and it did). Read the unit's MemoryMax or centralize the pair.
24. **Two alert pipelines, two formats**: Gatus (`:helmet_with_white_cross:` clean messages) and SigNoz (label soup) hit the same Discord channel with different voices. After this fix they should at least agree on shape (title = alertname + severity emoji, body = description + value + link). Longer-term consider whether SigNoz rules that duplicate Gatus checks (disk, buildcache-adjacent) should exist at all.
25. **`send_resolved: true` + churn = alert storms**: every deploy currently emits a resolve+fire pair per rule. With a fixed provisioner this mostly disappears; consider whether resolved-messages for warning-severity rules are worth keeping at all.
26. **Alert rule queries should reference metrics that provably exist** (see AGENTS.md phantom-metrics rule — it already says this; the nvme and systemd-failed rules predate/violate it). The pre-deploy metric-presence check apparently doesn't cover SigNoz rules, only Gatus pats.
27. **Root disk at 90% is a standing crisis** — it re-triggers critical alerts on every deploy churn until nix-gc/snapshot expiry frees space. The alert is doing its job; the disk is the problem.

## f) NEXT — up to 50 items

**Fix batch (this arc, in order):**
1. ~~Finish research: alertmanager external-url YAML key in signoz config schema (g/7)~~ done — `alertmanager.signoz.external_url` (03-09 batch)
2. ~~Rewrite `_signoz-scripts.nix` rule provisioner: skip-unchanged, dedupe-by-name, verify deletes, convergence assert~~ done — v5 converger (03-09)
3. ~~Add channel title/message custom templates (minimal: alertname, severity, description, value, rule link)~~ done — custom title/message via `PUT /api/v1/channels/{id}` (03-09)
4. ~~Channel migration path: channel exists → needs update (PUT `/api/v1/channels/{id}` or safe delete+recreate — verify which the API supports)~~ done — PUT path works (03-09)
5. ~~`signoz.nix`: add alertmanager external URL `https://signoz.${domain}`~~ done — `alertmanager.signoz.external_url` + restartTriggers (03-09)
6. ~~`system-health.nix`: per-service threshold = 90% of unit MemoryMax; fix stale comment~~ done — thresholds derived at collection time (03-09)
7. ~~`_signoz-metrics.nix`: correct nvme keys; drop `// 0` → error+skip on missing key~~ done — `avail_spare`/`percent_used` + `node_nvme_collector_keys_missing` (03-09)
8. ~~`nvme-health-monitor.nix`: same key fix for the desktop-notify twin~~ done (03-09)
9. ~~Root-cause `node_systemd_units{state="failed"}`~~ done — rewired to per-unit `node_systemd_unit_state{state="failed"} == 1` (03-09)
10. ~~Fix "Systemd Service Failed" rule description~~ done (03-09)
11. ~~`journalctl -u nvme-metrics` — collector error check (d.20)~~ done — keys confirmed live (03-09)
12. ~~Clean the 3 live zombie rules~~ done — provisioner deduped them on first run (03-09)
13. ~~Gates: `nix fmt`, `nix flake check --no-build`~~ done (03-09)
14. ~~Deploy (`nix run .#deploy`)~~ done (03-09, ×2)
15. ~~Verify: `/api/v1/rules` shows exactly 21 unique names, zero duplicates~~ done — 20 rules/20 unique verified (03-09; count later 23 with the meta-alerts)
16. ~~Verify: `nvme.prom` has real spare/percent values (not 0)~~ done — 100% spare/13% used live (03-09)
17. ~~Verify: next real alert renders clean (title/body/link)~~ done — `vector(42)` probe rendered `probe value=[42]` + ruleSource link (06-38)
18. ~~AGENTS.md: add provisioner-idempotency gotcha + SigNoz alerting section~~ done (03-09/06-38)
19. ~~CHANGELOG entry~~ done (03-09)
20. ~~Status report for the fix round~~ done — `2026-08-16_03-09_DISCORD-ALERT-FIX-BATCH.md`

**Follow-on (queue):**
21. Root disk relief: `nix run .#` gc helpers / verify btrbk snapshot expiry is actually freeing extents
22. ~~monitor365 backup broken (999h stale) — separate incident, known baseline~~ moot — monitor365 disabled; backup gating rides the working-tree deploy (TODO_LIST P0)
23. btrfs scrub interrupted on both mounts — weekly scrub never completes (reboots); consider scrub resume strategy or accept
24. `node_btrfs_device_errors_total corruption 1.8e19` on nvme0n1p8 — verify it's the -1 sentinel, not real corruption
25. Decide Gatus-vs-SigNoz rule overlap policy (disk usage exists in both?)
26. Consider suppressing `send_resolved` for warning severity
27. Consider severity-based channel split or at least emoji prefix (🔴/🟡/🟢) in title template
28. ~~SigNoz dashboards still v1-format best-effort (`_signoz-scripts.nix:113-117` TODO) — v2 schema rewrite~~ done — 23-27 session (251 zombies → 5 native-v2, converging provisioner v7)
29. `Systemd Service Failed` rule: consider per-name series from textfile collector so the alert says WHICH service
30. Add eval-time or pre-deploy check: every SigNoz rule query references an existing metric (extend metric-presence validation)
31. VM test for provisioner idempotency (run twice → identical rule set, no duplicates)
32. Re-examine remaining rules for phantom-metric queries (audit all 21 queries against /metrics)
33. `CPU Runaway` Gatus alert and SigNoz CPU rule overlap — dedupe
34. Prior-session P0 remainder: `CARGO_INCREMENTAL=0` global in home.nix
35. Prior-session P0 remainder: monitor365 real cargo build + sccache stats check
36. Prior-session P0 remainder: buildcache-gc VM test
37. Sunday 05:00: first hardened GC journal check (`journalctl -u buildcache-gc.service`)
38. Gatus alert-reminder mechanism (03:37 buildcache alert sat ~18h unacknowledged)
39. ~~Annotate prior reports' open lists with closures~~ done — 2026-08-17 docs-health pass (this annotation)
40. Consider moving `discord.default.*` knowledge into AGENTS.md SigNoz section (template override point)

## g) QUESTIONS (cannot resolve myself)

1. **Discord format preference**: I plan minimal alerts — title `🔴 Disk Space Critical (>90%)` (severity emoji + alertname), body = rule description + current value + one clickable `https://signoz.home.lan/alerts/overview?ruleId=…` link; resolved messages one-liner `🟢 resolved: <name>`. Keep verbose label dumps anywhere? Any format you specifically want?
2. **nvme JSON keys**: `sudo nvme smart-log -o json /dev/nvme0n1 | head -30` is blocked for me (no root). Paste the output (or just confirm the key names for spare + percent-used: `avail_spare`/`percent_used` vs `available_spare`/`percentage_used`) so the collector fix uses your runtime's real keys — not nixpkgs-latest's.
3. **Standing commit instruction (carried from last session, still unanswered)**: should I commit my own session's work immediately after a green deploy+verify, or keep leaving it uncommitted for the auto-git daemon (which sometimes mis-attributes)?

---

**Session verdict:** diagnosis strong (4.5 of 5 causes verified with live evidence), execution zero (interrupted by design before edits), two self-inflicted round-trips (d.16, d.17), one overclaim (d.18). The fix plan is concrete and sequenced; nothing is deployed from this session.

---

## Resolution (2026-08-17, docs-health pass)

The entire fix batch (f.1-20) was executed by the 03-09 fix-batch session — all five root causes fixed, deployed twice, machine-verified (see CHANGELOG "Discord alert spam — all 5 root causes fixed" + the SigNoz routing entries). Follow-on verdicts: f.21 → TODO_LIST P0 free-root item; f.22 moot (struck); f.23/f.24 → untracked btrfs items (scrub now weekly incl. pool; corruption sentinel unverified); f.25-27 → partially resolved (templates carry 🔴/🟡 emoji; overlap policy + send_resolved tuning untracked); f.28 done (struck); f.29-33 → superseded by the 23-27 deep integration (rule audit + meta-alerts + dashboards rebuilt) — remaining overlap dedup untracked-minor; f.34 → untracked (CARGO_INCREMENTAL); f.35 moot (monitor365 disabled); f.36 → TODO_LIST (gc/provisioner VM tests); f.37 done — first hardened scheduled runs verified green (22-05 session + subsequent Sundays); f.38 → untracked (alert reminder mechanism); f.39 done (struck); f.40 done — AGENTS.md SigNoz section documents the template override point. b.7/b.8 resolved by the fix batch (external_url key found; systemd-failed rule rewired); b.9 incidental findings — scrub since stabilized (weekly, pool included), monitor365 moot, corruption-sentinel untracked. g.1 answered (format shipped as proposed); g.2 answered (`avail_spare`/`percent_used`); g.3 standing commit question — resolved by practice: sessions commit, daemon sweeps stragglers. Archived as resolution-complete.
