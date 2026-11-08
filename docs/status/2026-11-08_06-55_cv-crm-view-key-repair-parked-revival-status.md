# CV→CRM mirror view-key repair: 3 parked apps revived, sync errors 6,945 → 1,234

**Window:** 2026-11-08 ~03:35 → 06:55, single agent session.
**Trigger:** owner pasted the CV dashboard CRM-mirror card: "Parked applications 3 — their CRM link is dead … Sync errors 4233 counted since boot … CV?? fix properly!"

## a. What was actually broken

Not CV, not crm-server liveness — both healthy (`/health/live` pass, `/healthz` ok). The break was the **Kith read model's view keys**: the 2026-10-27 branded-id era (`StreamMarker:` display prefix, `docs/status/2026-10-27_18-05_crm-journal-key-split-status.md`) left **1,993 deal + 178 company view rows keyed `StreamMarker:<ulid>`** while everything else — `ParseStreamID` (strips the prefix), the /rest echo (`app.BareID`), CV's stored links (bare ULIDs) — went bare. Result:

- `GET/PATCH /rest/opportunities/<bare>` → `system.Get(deal-views, bare)` → row sits under the prefixed key → **404 forever** (poison: never self-heals).
- The W12 self-heal re-link (find-or-create) **re-found the same ghost** (title+company match on the prefixed row, echoed bare) → retry 404 → loop.
- CV's 2026-11-07 20:50 boot replay: 3,046 "opportunity not found" + 1,184 "409 deal does not exist or is closed" + 6,945 sync errors; **3 applications dead-lettered** (app-7761, app-7674, app-8315) at 20:58–20:59 — the tile's "3 parked".
- Evidence chain: ghost view row `{key: "StreamMarker:01M5JVBY…", id: "StreamMarker:01M5JVBY…"}`; journal events under `Deal:StreamMarker:01M5JVBY…` (created→lost, storm close-out); `ParseStreamID` prefix-strip confirmed in go-cqrs-lite id/v4 `stream_id.go:75`.

## b. Repair (the CRM repo's outstanding "re-key the 1,993 orphan views" half)

Surgical, server-stopped, transactional — chosen over a full projection replay after a reference audit proved the prefixes live in exactly two tables (all other metaengine ADT tables 0 rows, no materialized views, no cross-refs; deal values' `company_id`/`contact_id` census: 229 ghost deals also carried prefixed `company_id`):

1. `systemctl stop crm-server`; safety snapshot `sqlite3 .backup` → `/mnt/pool/backups/crm/ledger-pre-viewrepair-2026-11-08.db` (integrity-checked; plus the routine 03:46 `ledger-2026-11-08.db`).
2. Single transaction: `meta_planned_deal_views` 1,993 rows — key `substr(key,14)` + value strips `"id":"StreamMarker:` and `"company_id":"StreamMarker:`; `meta_map` company-views same for its rows.
3. **5 company UNIQUE collisions**: prefixed rows whose bare twin already existed — dual-generation journal streams of the SAME ulid (bare + marker rows). Adjudicated per-pair: bare twin newer (10-30 folds, domains filled) → deleted the 5 stale prefixed rows, rekeyed the remaining 173. Deal-side had zero collisions.
4. Post-audit: prefixed refs **0** in every table; counts intact (deals 10,886 / companies 4,828 / contacts 6,266; journal 1,516,492 untouched; counter sums equal; `PRAGMA integrity_check` ok). The 5 "dangling" deal refs are not dangling — twins share the ulid, the surviving bare row carries it.
5. Restart crm-server → `/health` ok both checks; **all 4 ghost ids (incl. the 3 parked) answer `/rest` 200** with payloads; prefixed URL form 200 (normalized).

## c. Revival (the tile's "re-discover / restart the syncer")

`systemctl restart cv-server` → boot replay 44,431 events in 10m9.8s (binds :8098 only after the sync — the 10-min "still binding" window is expected). `crm-status` after: **`deadLettered: 0`** (all 3 parked revived), `notesSynced: 1472`, errors **1,234** — ALL one-shot `notes fold failed → 409 deal.not_open` (operator notes onto storm-closed deals; the documented domain behavior; does not park, does not loop). Zero "opportunity not found", zero dead-letter WARNs, stage PATCHes 200 (the parked deals' views reopened to `qualified`). Creates 133 (fresh apps) vs 542 under the broken mirror.

## d. Also landed (crm repo, committed `df4e49a`, NOT pushed)

`cmd/crm-reset-projections` (flake subPackage): offline whole-projection reset via the system's own `ResetProjection`/metaengine `Store.Reset` (journal survives per ADR-0143) — the sanctioned instrument for future fold-code changes; snapshot-drilled before landing (reset verified: journal intact, all derived state zeroed, replay re-keyed everything bare, ghosts resolvable). CAVEAT recorded: a full replay re-forks prefixed view rows for every marker-form journal stream (~2,000) until the fold normalizes stream keys — queued in the crm TODO_LIST.

## e. Verification commands (canonical)

```bash
sqlite3 -readonly ~/.local/share/crm/ledger.db \
  "SELECT count(*) FROM meta_planned_deal_views WHERE key LIKE 'StreamMarker:%' OR value LIKE '%StreamMarker:%';"  # 0
curl -s -H "X-API-Key: $(…cv-env CV_API_KEY…)" localhost:8098/api/pipeline/crm-status   # deadLettered 0
journalctl -u cv-server --since "-30 min" | grep -c "opportunity not found"              # 0
```

## f. Follow-ups (self-harvested at authoring time)

1. **CV upstream: classify notes-fold `deal.not_open` as skip-not-error** (1,234 replay WARNs per boot onto CRM-closed deals; syncErrors counter grows by that class every restart) → TODO_LIST + docs/todo/upstream.md.
2. **crm upstream: fold-level marker-form stream normalization** (any future full replay re-forks prefixed views until fixed) → crm repo TODO_LIST (landed there) + noted in SystemNix crm.md.
3. Deliberately NOT harvested: pushing the crm repo commit (owner action — never push unasked); SystemNix lock float for the crm input (the deployed binary already folds bare; the tool ships on the next natural crm deploy).
