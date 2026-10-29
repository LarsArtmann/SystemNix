# Data Ownership — who owns which data (and who should)

One page that answers "who owns X?" for every personal-data domain this fleet
touches. Written 2026-10-29 from the Contacts/Calendar question; every claim is
grep-verified at the cited line — rows marked `?` are NOT verified and say so.

## The rule

You own data when you have all three:

1. **Write authority** — exactly one place accepts writes for that domain.
   Two writers is not redundancy, it is two owners about to disagree.
2. **A restore path you have actually run** — a backup leg *plus* a drill that
   proved it. An untested dump is a hope, not an asset.
3. **An export path** — you can leave with the data in a usable format.

Two things look like ownership and are not:

- **Mirror** — a one-way copy. Correct by construction *only* if one direction
  is inert (Forgejo pull mirrors, `google-sync`). A two-way sync creates a
  second writer and therefore a second truth.
- **Projection** — a derived read model rebuilt from the truth (CRM
  projections, dashboard tiles, metrics, the CV interviews `.ics` feed).

Corollary: owning the *data* is not owning the *box*. Holding the disk is the
strongest form (this fleet's in-house services), but a copy on someone else's
host that you can restore and export still beats a self-hosted copy you cannot
recover.

## Inventory

| Domain              | Owner (write authority)                                                                  | Class                  | Restore path                                                                                               | Evidence                                                   |
| ------------------- | ---------------------------------------------------------------------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Contacts            | Kith CRM — event journal (`~/.local/share/crm/ledger.db`); projections are disposable    | **truth** (in-fleet)   | `crm-backup` nightly 03:40 → `/mnt/pool/backups/crm` (30d, WAL-safe sqlite snapshots)                      | `crm.nix:128,372` · `crm.md:5,20`                          |
| Calendar            | **nobody** — no DAV server, no DAV client in the fleet                                   | **none**               | none                                                                                                       | `catalog-platform.nix:71` (CardDAV only) · `FEATURES.md:251` |
| Mail                | Stalwart at `mail.artmann.tech` (Hetzner VPS, off-fleet — the module targets that host)   | not in fleet           | none in-fleet; `mail-relay` here is an outbound null client only                                           | `nix-email.nix:112` ("future VPS target") · `catalog-platform.nix:71` · `configuration.nix:669` |
| Files (Drive)       | Google Drive — canonical                                                                 | **not yours**          | Google-side; the local mirror is DISABLED (`google-sync.enable = false`)                                   | `opencloud.md:3` · `configuration.nix:711`                 |
| Files (self-hosted) | OpenCloud — pilot, complement mode, LAN/VPN-only                                         | second write surface   | pool + `restic-app-dumps`                                                                                  | `opencloud.md:3`                                           |
| Photos / video      | Immich (`/mnt/pool/services/immich`)                                                     | **truth**              | `immich-db-backup` + `RequiresMountsFor` on the pool (fails loud, never shadow-writes)                     | `immich.md:5`                                              |
| Documents           | Paperless-ngx (+ `triage`, `gpt`, dashboard)                                             | **truth**              | `restic-app-dumps` repo carries the per-service dumps                                                      | `restic-app-dumps.nix:1-5` · `paperless.md:1-5`            |
| Tasks               | TaskChampion sync server (`tasks.home.lan`), Taskwarrior as client                       | **truth** (sync hub)   | `?` — no dump leg found in the module or runbook                                                           | `taskchampion.md:1-9`                                      |
| Source code         | GitHub canonical; Forgejo = read-only pull mirrors (+ push mirrors for `canonicalRepos`) | mirror of an external truth | 4 legs: daily pool zip, 8h btrbk subvol, weekly stateDir, Sunday drill                                | `forgejo.md:1-6,216`                                       |
| Chat                | Discord                                                                                  | **not yours** (archive) | `discordsync-db-backup` 03:45 → `/mnt/pool/backups/discordsync` (7d) + Sunday restore drill                | `discordsync.md:87`                                        |
| Money               | Wise / the bank                                                                          | **not yours**          | `bank-sync` archives into Paperless                                                                        | `bank-sync.nix:97`                                         |
| Reading (RSS)       | Miniflux                                                                                 | **truth** (subs + read state) | `miniflux-backup` 02:45 `pg_dump -Fc` → pool (14d)                                                   | `miniflux.md:18,162`                                       |
| Browser history     | the local browsers → `browser-history` archive                                            | archive of a local store | `browser-history-backup` 02:15 → pool (14d)                                                              | `browser-history.md:19`                                    |
| Identity / SSO      | Pocket ID (`auth.home.lan`)                                                              | **truth**              | `pocket-id-backup` reads the sqlite directly + `restic-app-dumps`                                          | `configuration.nix:780` · `restic-app-dumps.nix:4`         |
| What exists         | integration registry / `services.catalog`                                                | derived                | regenerated, never restored                                                                                | `integration.nix` · `catalog-inventory-sync.nix`            |

Note on identity: there are **two** identity authorities — Pocket ID for SSO,
and a separate Kith CRM identity DB (`identity-YYYY-MM-DD.db`, mode 0600) that
holds passkey/session bearer material (`crm.md:20`). Deliberate or not, know
which one a given login is answering to before migrating either.

## The offsite hole

Ownership's second test (a restore path you have run) currently stops at the
chassis for almost everything:

- The offsite leg (`services.offsite-borg`, Hetzner StorageBox) is **DORMANT** —
  `enable = false`, hostname/user absent from every secret (`offsite-borg.md:9-12`).
- The restic repo that dedups the app dumps is **pool-local** — "losing the host
  loses the repo" (`restic-app-dumps.nix:6-10`).
- So today durable data has btrbk same-disk snapshots + a pool copy: two copies,
  one chassis. "You own it" here means *you own it until the box is gone*.

Fix the second test before adding new surfaces, not after.

## Who should own a new X

1. **Name the thing in the domain**, not by the screen it appears on (a
   calendar entry is time + identity + recurrence, not "the events table").
2. **Pick the single writer.** Prefer an existing store whose backup leg already
   has a drill. A new store is a new restore path to prove.
3. **Decide the class out loud**: truth, mirror, or projection. Write the word
   in the module, so the next reader does not have to infer it.
4. **Mirrors get a direction and a guard.** One-way, and something that fails
   loud when the source drifts (the Forgejo rename-freeze is the cautionary
   tale: a mirror can freeze silently for 12 days).
5. **Wire the restore leg and the export path in the same change.** A truth with
   no drill is how you discover ownership is theoretical.
6. **Delete the loser.** Land the replacement, verify parity, *then* remove the
   old surface (the 2026-08-31 `glm-5.3-flash` lesson). Two surfaces that both
   claim to be truth is the one state that is never acceptable, not even
   briefly.

## Known gaps

- **Calendar has no owner at all** (see above). If one is wanted, it belongs on
  the same DAV boundary as contacts — Stalwart already advertises CardDAV
  (`catalog-platform.nix:71`) — rather than a second DAV server next to it,
  which would recreate the second-truth split that contacts just closed.
- **Contacts are declared-owned but thin**: the Kith journal holds **zero** people
  contacts; the 139 real ones sit in a dead Twenty dump awaiting an owner-picked
  import route (`docs/todo/services.md:363`), and the Google Contacts sync ladder
  is unconfigured — no client secret, no token, no button, and `ProtectHome`
  would block the token refresh (`docs/todo/services.md:364`).
- **`webphone` (pbx.artmann.tech) lists "contacts"** as a feature — an
  unexamined fourth surface with no stated direction relative to Kith
  (`catalog-platform.nix:67`).
- **Task restore path unverified** — the `?` row above is a to-do, not a
  finding.

## See also

- `docs/services/crm.md` — contacts truth, backup leg, cutover history
- `docs/services/*.md` — every row's per-service runbook (state, not doctrine)
- `docs/agents/integration-registry.md` — how a new service gets wired and gated
- `docs/agents/storage.md` + `docs/services/offsite-borg.md` — backup layers and
  the dormant offsite leg
