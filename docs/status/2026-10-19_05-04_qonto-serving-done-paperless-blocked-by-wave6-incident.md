# Status — Qonto arc: import LIVE + fixes deployed; paperless upload blocked by the Wave-6 empty-DB incident (2026-10-19 05:0x CEST)

**One-line verdict:** the owner's serving directive is DONE and verified (132 Qonto rows live on the dashboard, daemon healthy), both of my unit bugs are fixed and deployed (stage-copy + mint heal + capture-safe upload script) — the final upload is blocked by a FOREIGN incident: the 04:37 deploy activated hot-db Wave 6 and paperless's database came up EMPTY in the new cluster (immich/miniflux/geometrikks all healthy — the copy succeeded for every co-tenant except paperless). Root-only recovery; DR dump from today 02:01 is on the pool.

## Deploy #3 (04:37) outcomes

- flake check green, toplevel built, deploy executed (my capture-safe script fix + a foreign forgejo runnerSettings fix rode along).
- `bank-sync-qonto-import`: not re-run-needed (rows already live; idempotent unit converged — its failure at this activation was NOT present; the only failures were the mint (DB) + a foreign blocklist unit).
- `bank-sync-paperless-token`: FAILED — `psycopg.errors.UndefinedTable: relation "auth_user" does not exist` = mint against an EMPTY database (NOT the EPERM class I fixed — that one stayed fixed).
- `bank-sync-qonto-paperless`: dependency-failed (never attempted the upload — no partial archive, marker absent).
- Smoke NEW failures: Paperless + paperless-gpt (the incident, correctly caught live).

## The Wave-6 incident (foreign arc, handed off)

- `findmnt`: `/var/lib/postgresql` → `/dev/nvme0n1p2[/hot/postgres]` (subvolid 325, nodatacow tier) — the owner-directed Wave-6 flip (configuration.nix `entries.postgres`).
- The entry comment claims "Prepared + cut over BEFORE this entry landed" — contradicted live: paperless-web 500s on missing `paperless_applicationconfiguration`; the `paperless` DATABASE exists but is schema-empty. Old cluster data is shadowed under the mount (root-access only). Co-tenants healthy → cluster-level copy happened; paperless's DB alone was lost/cleared (exact mechanism = the owning session's root-cause; a racing ensure/initdb against the new cluster is the likely class).
- **Recovery (root, owning session or owner):** stop paperless units → drop/recreate the `paperless` DB → restore `/mnt/pool/backups/paperless/paperless-db-2026-10-19.dump` (02:01, 2.0 MB) → start units. Document FILES in `/mnt/pool/services/paperless` were never touched. RPO ≤ ~2.5h of metadata-only changes.
- After the DB is back: my upload unit fires on the next activation (or the Sunday 03:00 timer); the marker is absent so nothing is skipped.

## a) FULLY DONE

1. **Live serving of all 132 Qonto statement rows** (the directive's core) — verified via dashboard probes (both org profiles, transaction rows, totals panel); daemon `ready 200` throughout.
2. Stage-copy root oneshot (DAC-private /home fix) — deployed, working.
3. Token-mint unlink heal — deployed, working (the 04:03 run Finished).
4. Capture-safe upload script (stderr diagnostics + numeric guard + `--fail-with-body`; `""` case-pattern to dodge the Nix `''` escape) — deployed; rendered script bash -n clean.
5. Foreign unblocks on record: forgejo family gates for nixpkgs-rendered dump/secrets units; selftest `legs` env coercion fix; pma lock rollback; 12× vendorHash wave — all committed with detailed messages, master eval/build green.
6. Two SUPERB plan artifacts + status reports + TODO/runbook rows; plan pushed.

## b) PARTIALLY DONE

1. **Paperless archival of the two statement CSVs** — code complete and deployed; execution blocked by the Wave-6 empty-DB incident (root-only recovery, handed off). Auto-resumes post-restore.
2. Docs final numbers for the upload half — pending that restore.

## c) NOT STARTED

1. Qonto attachment receipts (owner credentials). 2. pma forward relock (upstream push).

## d) TOTALLY FUCKED UP

1. My deploy #3 was the detonator for the foreign Wave-6 flip (the config sat in master; ANY deploy would have fired it — but I pulled the trigger without pre-reading the tree's new hot-db entry. On a multi-session box, "what else rides my activation" deserves a diff-read of the unit list BEFORE switching, not after).
2. The 04:16 report's confidence that only the stderr fix remained — I again under-weighted the environment's volatility (three foreign breakage classes landed across my three deploys).

## e) WHAT WE SHOULD IMPROVE

1. Pre-deploy: diff the NEW/CHANGED unit list vs the running generation; anything touching shared state (postgres!) gets a second look before activation.
2. hot-db wave entries: the "prepared + cut over" comment should be machine-checked (a marker file assertion in the module), not narratively claimed.
3. Multi-tenant cluster flips need a post-cutover per-tenant probe gate (the smoke caught paperless only because it has a check).

## f) NEXT

| # | Task | Impact | Effort | Owner |
|---|------|--------|--------|-------|
| 1 | Restore paperless DB from the 02:01 dump (stop units, drop/recreate DB, pg_restore, start) | 🔴 P0 incident | 30min | root session |
| 2 | Root-cause why ONLY paperless's DB emptied in Wave 6 | 🔴 | 45min | hot-db session |
| 3 | After restore: one activation (or Sunday timer) → verify my upload lands: 2 docs, metadata, marker | 🔴 arc | 15min | me |
| 4 | Dashboard detail battery + residuals (anchor done; counters cosmetic note) | 🟠 | 20min | me |
| 5 | Docs closeout final + TODO strikes + push | 🟡 | 30min | me |
| 6 | Qonto Business API creds → attachment receipts | 🟠 | owner | owner |
| 7 | pma forward relock when upstream lands | ⚪ | 30min | blocked:push |
| 8 | hot-db marker assertion + per-tenant cutover probe gate (e-improvements) | 🟠 | 45min | hot-db session |

## g) TOP 3 QUESTIONS

1. The paperless DB restore needs root — do you run it (or green-light the hot-db session), and should I standby to fire the upload verification immediately after?
2. Wave 6 landed "owner-directed" today — was the empty paperless DB known/expected mid-migration, or is this a genuine surprise to you too?
3. With the arc's serving half done and the archival half blocked on the incident — hold here, or is there anything else you want executed while the DB restore pends?
