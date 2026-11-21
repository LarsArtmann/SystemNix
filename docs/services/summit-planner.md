# summit-planner

Local single-user conference-attendance & budget planner (Go +
go-cqrs-lite + cqrs-htmx identity bundle) at
`github:LarsArtmann/summit-planner` (PRIVATE; checkout
`/home/lars/projects/summit-planner`). The planner journal
(`summit-planner.db`) IS the schema — one `Event` aggregate per slug;
projections are disposable. Identity is the cqrs-htmx satellite bundle
(WebAuthn passkeys, MaxUsers 1 — the FIRST registration bootstraps the
only user, then registration closes) in a separate `identity.db`.

**Owning module:** `modules/nixos/services/summit-planner.nix` (SystemNix
authors the unit; upstream exports packages only, no nixosModule).
Deployed 2026-11-21.

## Surfaces

| Surface | Value |
| ------- | ----- |
| Unit    | `summit-planner.service` (system, `User=lars`, group `users`) |
| Port    | `ports.summit-planner` = 7612 — **loopback only** (`127.0.0.1:7612`) |
| URL     | `http://localhost:7612` (from the evo-x2 desktop; `127.0.0.1` in the address bar FAILS WebAuthn — RPID is `localhost`, browse the `localhost` spelling) |
| vHost   | **NONE — loopback-only by design.** The app's WebAuthn posture is RPID `localhost` + origin `http://localhost:7612`, and `guardLocalRequest` refuses non-loopback Host headers. A LAN/reverse-proxy deployment needs upstream changes first (`-rpid`/`-origin` flags exist; the guard relaxation does not) |
| Auth    | Built-in passkeys (identity satellite, NOT Pocket ID): first visit bootstraps registration, then it closes (MaxUsers 1). Lost passkey: stop unit → delete `identity.db` → restart → re-register; the planner DB is never touched |
| State   | `~/.config/summit-planner/` — `summit-planner.db` (journal + projections; adopted in place from the 2026-11-19/20 dev use, NO /var/lib migration — crm doctrine) + `identity.db` (created on first registration). A legacy pre-cqrs file is renamed aside by the app itself, never deleted |
| Gatus   | "summit-planner" on `/healthz` (public: 200 ok / 503 when the cqrs system is unhealthy), 1m |
| Backup  | `summit-planner-backup.timer` 03:55 nightly — WAL-safe sqlite snapshots (backup API) of BOTH dbs → `/mnt/pool/backups/summit-planner/{summit-planner,identity}-YYYY-MM-DD.db` (planner 0644, identity 0600 — passkey/session bearer material), 30-day retention. An absent `identity.db` (no passkey registered yet) is a skip-with-note, not a failure; a missing planner DB refuses the run |
| Catalog | `services.catalog.summit-planner` (subdomain null, port 7612, healthPath `/healthz`) |

## Package input

`inputs.summit-planner` (`git+ssh://git@github.com/LarsArtmann/summit-planner?ref=refs/heads/master`,
floats per the owner-pin policy). NON-FOLLOWER class for nixpkgs
(invoices precedent): upstream bakes the vendorHash validated under its
own lock; see the `summit-planner.nixpkgs` deliberate row in
`lib/lock-audit.nix`. `flake-parts` + `treefmt-nix` follow the root.
First-hand probe: built green from the remote ref at `8573311`
(2026-11-21) before locking.

## Operational notes

- **Seed at boot:** every start re-runs the fact-only catalog seed
  (`internal/seed`); statuses/notes/cost lines are decisions on the event
  stream and survive BY CONSTRUCTION (`TestSeedRefreshPreservesDecisions`).
  Exclusion rules live in `internal/rules` upstream (Africa/Virtual/
  PyTorch filtered + pruned on re-seed).
- **WebAuthn origin discipline:** the browser MUST use the
  `http://localhost:7612` spelling; `127.0.0.1` fails every ceremony with
  a cryptic browser error (RPID mismatch).
- **CI auth:** the private input rides the deploy-keys bundle recipe
  (`docs/agents/go-ecosystem.md` → "Bundle recipe") — summit-planner's
  read-only deploy key must be present in `NIX_DEPLOY_KEYS_BUNDLE_2` or
  CI nix-check fails fetching the input.
- The tq/monitor surfaces do not apply (no OTel instrumentation
  upstream; system-health `monitored = true` covers unit state).
