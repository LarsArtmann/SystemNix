# Incident: Immich "set up fresh / restore" wizard — PG cluster shadow-split by wave-6 hot-tier mount

**Date:** 2026-10-21 01:15–01:55 (+0200) — incident began 2026-10-19 04:37
**Severity:** high (4 services on blank DBs for 2.5 days; zero permanent data loss)
**Status:** RECOVERED live 2026-10-21 01:51; follow-up gates queued

## Symptom

Immich web showed the v3.3 setup/restore wizard ("set up fresh or restore from
backup"). Probe: `GET /api/server/config` returned `"isInitialized": false` —
the server believed no admin user existed.

## Root cause

Wave 6 (2026-10-19 04:37 deploy) added `entries.postgres` in
`platforms/nixos/system/configuration.nix`: a `var-lib-postgresql.mount` of the
Samsung subvol `/hot/postgres` over `/var/lib/postgresql`. The config comment
claimed "Prepared + cut over BEFORE this entry landed" — **it was not**. The
subvol was empty at first mount (`btrfs subvolume list` shows one subvol;
`PG_VERSION` mtime = mount activation second 04:37:34). PostgreSQL restarted
onto the empty directory, ran a fresh `initdb`, and NixOS's `ensureDatabases`
recreated blank `immich`/`paperless`/`miniflux`/`geometrikks` databases, onto
which all four apps happily re-ran their migrations. The real PG17 cluster was
cleanly stopped and **shadowed** — not destroyed — on QLC subvol `@` at
`var/lib/postgresql/17` (413 MB, cluster state: "shut down").

The immich 3.3.1 → 3.3.3 bump in the same deploy window was a red herring:
migration sets are byte-identical between the two packages (verified by
diffing both store paths' migration ID lists).

## Blast radius

| Service | State Oct 19 04:37 → Oct 21 01:51 | Loss |
| --- | --- | --- |
| immich | blank DB; web blocked at wizard (no users ⇒ no logins ⇒ no uploads) | none |
| paperless | blank DB, web up, consumer idle (no docs in) | none observed |
| miniflux | blank DB (entries=0 even in fresh cluster — feeds not refetched) | none observed |
| geometrikks | blank DB, schema-only | none observed |

## Timeline (evidence)

- 2026-10-19 01:05 `immich-db-backup` dump: 1 user, 3,895 assets (last good dump)
- 2026-10-19 04:37:31 journal: `Stopped target PostgreSQL` … `var-lib-postgresql.mount: Directory /var/lib/postgresql to mount over is not empty, mounting anyway`
- 04:37:34 fresh `PG_VERSION` created on the Samsung subvol; immich logs all 100 migrations "succeeded" at 04:37:40 (fresh-schema signature)
- 2026-10-20 01:06 dump: 0 users, 0 assets, 52 MB (geodata seed only)

## Recovery (owner-approved, 2026-10-21 01:45)

1. Stopped all PG writers (immich-server, paperless \*, miniflux, geometrikks, bank-sync \*).
2. `systemctl stop postgresql`; renamed fresh cluster → `17.empty-incident-20261019` (kept, subvol-side).
3. Read-only mounted QLC subvol `@`, `rsync -aHAX` the shadowed 17 (413 MB, clean shutdown, checkpoint `1/6E1ADA0`) into `/var/lib/postgresql/17`.
4. Started PG: `users=1 assets=3895 isAdmin=1`; `isInitialized: true` externally; apps restarted, all active.
5. `ALTER DATABASE … REFRESH COLLATION VERSION` on all four (pre-existing glibc 2.42→2.44 mismatch, unrelated to this incident).

## Residue (reclaim pending owner)

- QLC `@` `/var/lib/postgresql/17` — shadowed original, 413 MB
- Samsung `/hot/postgres/17.empty-incident-20261019` — the 2.5-day blank cluster
- `~/.cache/immich-diag/` — diagnostic harness scripts (trash after review)

## Follow-ups (harvested)

- Pre-deploy gate: detect "PG cluster replaced/blank while services expect data" (`docs/todo/storage.md`)
- Wave close-out discipline: "prepared + cut over" claims require the migrate-state evidence attached — this is the fabricated-closeout class again (`docs/todo/storage.md`)
- `.migrate-state` forensics on the Samsung: what did the wave-6 prepare step actually do? (`docs/todo/storage.md`)

**Source of truth for the wave table:** `platforms/nixos/system/configuration.nix` wave-6 comment (corrected this session).
