# Status: Browser-History Dashboard "Still Only Basic Stats" — Verdict + Render-Latency Finding

**Session:** 2026-10-14, ~20:19–21:15 CEST · **Scope:** the owner question "Why can I STILL only see [9 stat cards] on `https://history.home.lan/`" · **Verdict:** NOTHING is missing — the full dashboard renders; a separate verified finding (13-19s prod render latency) queued.

## a) The question, answered

The nine items the owner listed (Total visits 1739 / Unique domains 96 / Browsing sessions 126 / Search queries 100 / Downloads 56 / Productivity visits 40% / Productivity duration 47% / the 1031 pre-granular-era note / the 2h 19m redirect note) are **the complete stat-card set the upstream dashboard offers** (upstream `8900354` `statGrid` = exactly these 5 cards + 2 productivity cards + 2 conditional notes) — and they are **correct and live** (see c).

Everything else the product promises lives in the sections BELOW that grid, and all of them render: Activity heatmap, Goals, Recent visits (filterable per-visit table with dwell/intent), Recent searches, Top-domains-by-duration leaderboard, 14-day trend sparkline, Machines, Agent Tokens, Top domains, Sessions, Domain Overrides. One scroll below the stats. The "1031 visits without duration" note is **permanent by design** — those visits predate granular duration capture and can never gain dwell times; Productivity (duration) is computed only over the ~708 granular visits.

## b) Evidence chain

1. **Rev parity:** deployed binary = `browser-history-server-8900354` (unit ExecStart store path, read off `/etc/systemd/system/browser-history.service`) == upstream HEAD `8900354` (2026-10-13 21:12) == SystemNix flake.lock node. Nothing undeployed.
2. **Server renders 200, full page:** journal shows the owner's authenticated `GET /` returning 200 all evening (13-19s — see e); the handler's errgroup is all-or-nothing for visits/domains/sessions, so 200 + populated stats proves every section load succeeded.
3. **Local render of the owner's exact data (the decisive probe):** ran the deployed `8900354` binary on a throwaway copy of tonight's 02:15 pool backup, registered a local user, re-attributed the data-owner's rows to it in the copy, and fetched `/` with that session: **200, 463,185 B, 0.1 s, all sections present** (heatmap, leaderboard, trend, visits table with the owner's real rows: tq.home.lan, yandex.com, catalog.home.lan, …). Harness recipe kept in crush.db session `f4cd5352` (fresh-DB registration bypasses the closed registration gate; never do this against prod).
4. **Data freshness:** owner's visits run Sep 4 22:24 → Oct 13 23:05 (backup) and ingest keeps flowing (empty-dedupe `/ingest` batches every 5 min, `accepted=1` on new data at 20:01).

## c) Stat values verified against the 02:15 backup (per-user scoped)

| Stat (evening) | Backup (02:15) | Cross-check |
| --- | --- | --- |
| Visits 1739 | 1727 | +12 by evening ✓ |
| Sessions 126 | 123 (user-scoped) | +3 ✓ |
| Searches 100 | 100 user-scoped (225 total) | exact ✓ |
| Downloads 56 | 56 user-scoped (114 total) | exact ✓ |
| Domains 96 | 96 user-scoped (336 total) | exact ✓ |
| 1031 no-duration / 704 granular | 1023 / 704 | +8 zero-duration among the 12 new ✓ |

The remaining 3179 visits (Jan 1 → Sep 4 22:04) sit under the all-zeros `user_id` — the pre-attribution era, invisible to the owner by design.

## d) Not done / deliberately not harvested

No config or code change was needed — the answer is a verdict, not a fix. The only actionable output is the latency finding below (harvested at authoring time). The cosmetic `browser_history_users` zombie-dupes row (known since 2026-10-04) stays parked behind the upstream DeleteUser surface.

## e) Direct follow-up (harvested)

- ~~**13-19s prod dashboard renders vs 0.1s local on identical data**~~ **RETRACTED 21:47 same night (unit misread):** the journal `duration` field is NANOSECONDS — tonight's renders were 13-19 **ms**, not seconds (prod is faster than the 0.1s local repro, not slower). The queue row this section originally spawned was replaced by a [watch] row for the two GENUINE historical slow-render bursts (Oct 10 16:33-17:00 ×8, 10.7-37.7s; Oct 12 03:51 ×1, 49.2s — both pre-hot-tier, none today). Full retraction narrative: `docs/status/2026-10-14_21-47_browser-history-stats-full-status-retraction.md` §d.
