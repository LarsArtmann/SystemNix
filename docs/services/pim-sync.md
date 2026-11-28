# pim-sync (Google People ↔ Stalwart CardDAV contacts sync) — Agent Notes

> Module: `modules/nixos/services/pim-sync.nix` (thin wrapper around upstream `inputs.pim-sync.nixosModules.default`). Upstream repo: `github:LarsArtmann/pim-sync` (PRIVATE, git+ssh input, ref-tracked `refs/heads/master`, lock-pinned — monitor365/media-atlas pattern).

## State: ENABLED dry-run with a secret gate (2026-11-27); sops scaffold LANDED (2026-11-10); Stalwart leg LIVE (2026-11-18); dashboard fleet rows LANDED (2026-11-19); ui token REAL (2026-11-27)

`services.pim-sync.enable = true` + `service.pim-sync.live = false` in `platforms/nixos/system/configuration.nix` (2026-11-27). The wrapper pre-wires the package pin, the secret gate, OnFailure routing, the integration entry (`monitored`, headless — no vHost/subdomain/port/tile) and the unconditional catalog entry.

**2026-11-10 sops scaffold:** the full secret wiring landed as PLACEHOLDER (audible-sync precedent) — `platforms/nixos/secrets/pim-sync.yaml` holds 8 keys (`pim_sync_oauth_client_secret`, `pim_sync_token_{personal,work}{,_calendar}`, `pim_sync_stalwart_dav_{user,pass}`, `pim_sync_ui_token`); the wrapper renders the DAV env template, points `secretFile`/`environmentFile`/`tokenSeedDir` (`/var/lib/pim-sync-seed`, per-secret rendered paths in sops.nix) and adds a config-check ExecStartPre that fails loudly with this checklist while any placeholder remains. **Enabling with placeholders is still forbidden** (alert storm) — the owner paste below is the gate.

**2026-11-19 dashboard fleet rows LANDED:** the upstream `pim-sync ui` dashboard (fleet-ON by default, owner ruling 2026-11-18) is pre-wired over the mesh with auth required by construction. `lib/ports.nix` registers `pim-sync-ui = 8111` — deliberately NOT the upstream default 8099, because **inboxclean owns 127.0.0.1:8099 on evo-x2** and the collision would have failed the ui unit's bind at the flip. `configuration.nix` sets `pim-sync.dashboard.addr = "100.112.252.86:8111"` (this host's NetBird IP, live-verified via `netbird-evox2 status`) + `dashboard.authTokenFile = /run/secrets/pim-sync/ui-token`; the upstream eval assertion makes non-loopback-without-token unevaluable, so the flip cannot regress the posture. sops gained `pim_sync_ui_token` (PLACEHOLDER, single-blob surgical diff) in its OWN mkSecrets with `restartUnits = [ "pim-sync-ui.service" ]` — the entire token-rotation story per the 2026-11-19 ruling: **rotation = restart on sops redeploy**, the restarted unit re-reads the file at boot; no SIGHUP/hot-reload build. The wrapper adds `pim-sync-ui-token-check` as an ExecStartPre on the ui unit (it is boot-gated, so a PLACEHOLDER would otherwise become a weak bearer password before any sync-side check fires) and `ioTier.background` (BE/6) for io-tier-coverage-audit. Verified by eval: dormant option values carry the rows; the enabled shape (`extendModules` + `mkForce enable`) evaluates with ZERO failed assertions — ExecStart carries `--addr 100.112.252.86:8111 --auth-token-file /run/secrets/pim-sync/ui-token`, the sops secret renders path/owner/restart, and rpi3-dns evaluates the guarded block with no `pim_sync` leakage. Daemon commits carrying the diffs: 4bd582a74 (ports + config), 931c65dc1 (yaml key), 93384248e (wrapper + sops.nix) — this runbook section is the detailed rationale the daemon messages lack.

**2026-11-18 Stalwart leg DONE agent-side:** the dedicated DAV account `bot.pim-sync@larsartmann.cloud` was added to the pbx-artmann plan (commit 60530c21 there: `hosts/pbx/mail.nix` Account set, credential-less doctrine) and the pbx was switched (stalwart-provision created it, 0 failed). An app password was minted via the 0.16 admin JMAP — see the recipe in the sops.nix `cv_pipeline_mailbox_password` comment (0.16 renamed the envelope: `methodCalls`, `urn:stalwart:jmap`, `x:AppPassword/set` with `accountId` at the set-args level; principal id `g` from `x:Principal/get`) — and BOTH values landed in sops (commit 36244fdd1 here). CardDAV auth verified live: `/.well-known/carddav` 307→`/dav/card`, PROPFIND 200 on `/dav/card/bot.pim-sync%40larsartmann.cloud/` with the default addressbook present (doctor's "Contacts"-name check may warn — the OUT leg creates named books live, per the mesh invariant below). Remaining placeholders: the OAuth-side keys only (owner GCP console gate below).

**2026-11-27 secret state (verified by decrypting the file with the host age identity; no value printed):** `pim_sync_stalwart_dav_{user,pass}` (2026-11-18) and `pim_sync_ui_token` (2026-11-27) are REAL; the five Google-side keys — `pim_sync_oauth_client_secret` + the four `pim_sync_token_*` — remain PLACEHOLDER, so the flip stays blocked on the console/consent gates. The five are not interchangeable: the client secret is a Google-issued Desktop-client JSON (unforgeable, `.installed.client_id` + `.client_secret`), and each consent writes its OWN token file because one scope set rides one token (`<account>.json` for contacts, `<account>-calendar.json` for calendar → 2 accounts × 2 legs = 4).

**2026-11-27 ENABLED dry-run — why that is safe with placeholders:** upstream has NO idle no-op (`discoverAccounts` errors on an empty tokensDir, `cmd/pim-sync/sync.go:359`), so a plain `enable = true` would fail every 5 min, ride OnFailure into a Discord storm and trip the failed-unit exit-4 deploy trap. The wrapper therefore adds an **ExecCondition secret gate** (`pim-sync-secret-gate`): exit 1-254 makes systemd SKIP the unit (inactive, no failure state, OnFailure does not fire) while any material still says PLACEHOLDER, while a MISSING rendered sops file exits 255 as a real failure (a render defect must never read as "waiting for the owner"). Shape validation stays in the config-check ExecStartPre, which only runs once the gate passes. Two more pieces of the same posture: `SuccessExitStatus = [ 3 ]` while `live = false` (a dry-run cap abort is informational — the guard stops before any write and the run's value is its projected-change report; the flag default cap is 50 and a first projection against a fresh book exceeds it by design), and the dry-run ExecStart passes no `--max-changes` at all (upstream only adds it with `--live`). **Proven live 2026-11-28** (transient user units on this box, systemd 261): `ExecCondition=/bin/false` logs `Skipped due to 'exec-condition'` / `Condition check resulted in … being skipped` and leaves no failed unit; an exit 3 is a clean run under `SuccessExitStatus=3` and `Failed with result 'exit-code'` without it. `pim-sync-ui` additionally orders behind and `wants` `netbird-evox2.service` (it binds the NetBird IP).

**Three upstream defects surfaced by the first real enable (2026-11-27), all invisible while the module stayed disabled** (`enable = true` is simply never evaluated). Fixed locally in `~/projects/pim-sync` at commit `0d9dfeb` — **not pushed** (agent rule); the SystemNix input still points at the GitHub rev, so the wrapper carries three documented interim shims until the input floats:

| Defect | Symptom | SystemNix shim |
|---|---|---|
| `users.users.pim-sync.description` contained `:` | eval abort (NixOS rejects `:` in GECOS descriptions) | `lib.mkForce` with the colon removed |
| seed script rendered `[ -n "/var/lib/pim-sync-seed" ]` | SC2157 is fatal in `writeShellApplication` → `pim-sync-seed-tokens.drv` failed to BUILD | `seedTokens` replacement (same semantics, creates every dir) |
| `ReadWritePaths` without `-` prefixes | first start on a fresh host dies **226/NAMESPACE** before `ExecStartPre` can create the dirs (live-proven with `systemd-run`; the receipt writer `MkdirAll`s its dir, the tokens/state dirs need the seed script) | `lib.mkForce` with `-` prefixes |

Verify the upstream fix locally with a throwaway `nixosSystem` and `systemd.units."pim-sync.service".unit` — that build pulls the seed script, so a green build proves both the SC2157 and the namespace fixes.

## Flip ladder (owner-gated — plan: docs/planning/2026-11-04_19-35_pim-sync-systemnix-integration-wave.md)

1. 🧑 **Owner gates** (values into the landed scaffold — sops editor, never a command line):
   - GCP OAuth client secret JSON (publishing mode "In production" — testing-mode tokens die after 7 days, the InboxClean lesson) → `pim_sync_oauth_client_secret`. Path contract: `~/projects/pim-sync` `docs/oauth-setup.md` §2. **Console-only, airtight** (2026-11-18: the random-port loopback redirect needs a Desktop-type client; Desktop clients + External consent screens have no gcloud API — the 2026-11-11 openseo sweep's conclusion, reconfirmed for this shape).
   - ~~Stalwart DAV creds~~ **DONE agent-side 2026-11-18** (see State above).
   - ~~Dashboard bearer token~~ **DONE agent-side 2026-11-27**: generated on-host (`openssl rand -hex 32`) and written with `sops set --value-file` (JSON-encoded value file, so the token never appeared on a command line; stored value hash-verified against the generated file, temp files removed). The ui unit's placeholder guard now passes; rotation afterwards = sops write + redeploy (the sops restart bounces pim-sync-ui.service, ruling 2026-11-19).
   - Per-account consents (client JSON must land first): run in the owner's terminal
     `mkdir -p ~/.config/pim-sync-tokens && PIMSYNC_SECRET=<downloaded-client-json> PIMSYNC_TOKENS_DIR=~/.config/pim-sync-tokens nix run ~/projects/pim-sync#pim-sync -- auth --account personal` (repeat `work`, plus `--calendar` variants) → the agent ingests the 4 token JSONs into `pim_sync_token_*` (runtime-variable expansion, never inline). The agent can launch these — the browser opens on the owner's desktop session; the owner just clicks Google's consent screens.
     **Account mapping (owner-confirmed 2026-11-18): `personal` = `lartyhd@gmail.com`, `work` = `lars@helpless.ai`** — each consent click must pick the matching account (mirror: pim-sync repo `docs/oauth-setup.md` §4 table).
2. **agent**: wire sops — DONE 2026-11-10 as the placeholder scaffold (environmentFile template / secretFile / tokenSeedDir + config-check). Flip mechanics — DONE 2026-11-27: `enable = true`, `live = false`, the ExecCondition secret gate, the three upstream shims, and the dry-run exit-3 tolerance are in tree and verified (host eval: zero failed assertions; the rendered unit carries `ExecCondition=<gate>`, `ExecStartPre=<seed>,<check>`, `ReadWritePaths=-/var/lib/pim-sync/{tokens,state,receipts}`, `SuccessExitStatus=3`; `systemd.units."pim-sync.service".unit` builds). Remaining: ingest the client JSON + 4 consent tokens into sops (agent, on your handover), then `nix run .#deploy` and the first dry-run journal review 🧑 (Stalwart-single-truth plan §7.5 gate).
   **Known tree precondition for that deploy (found 2026-11-28, unrelated to pim-sync):** the lock waves of the same night re-stale go-modules FODs faster than they are repaired. At 02:28 the buildflow float to `0e3622de` killed `buildflow-0e3622d-go-modules` (`specified sha256-/tZCpXj…`, built `sha256-WnSBXpNXpx+pCyvVfCU4XV/dQfDgKhRUC7mc7zpbKEU=`) plus `system-path`, `man-paths` and `overview-compliance-evidence`; that one is SHIMMED in `lib/lars-packages.nix` with the first-hand got hash. The re-enumeration then died on `project-discovery-daemon-6b97c2c-go-modules` (`specified sha256-FzTrkH…`, `got sha256-NRdyIq…`), and five minutes later the 03:33 wave floated six more inputs (incl. project-discovery-daemon to `5cbc99c`), so the tree is NOT proven green. Before the credentials-wave deploy: run the documented enumeration and `scripts/fod-hash-diff.sh <log> --apply` (docs/todo/pipeline.md, "FOD cluster from the 2026-11-28 lock waves"), re-enumerate to green, then deploy.
3. 🧑 **GO** → **agent**: `live = true` + `maxChanges` cap + `metricsFile` textfile wiring + Gatus freshness check on `pimsync_leg_last_success_unix{leg,account}` (anchored-pat doctrine; dry-run never settles it — 0 = never — hence deferred to this step). Textfile dir precedent: `btrfs-health.nix` (`/var/lib/prometheus-node-exporter/textfile_collectors`); metrics file is mode 0600 owned by the service user — collector readability needs the shared-group pattern from that precedent.
4. Real Twenty import stays its own owner gate (docs/todo/services.md).

## Owner side: the least possible steps (2026-11-27)

Everything that needs no human is already done: the flip (`enable = true`, `live = false`), the secret gate, the sops scaffold, the dashboard bearer token, the Stalwart DAV credential, the registry/catalog rows, and the eval + toplevel build proof. What remains is console and browser only:

1. **GCP console** (`console.cloud.google.com`, project `pim-sync-prod-larsartmann` — created 2026-11-18, People + Calendar APIs already enabled): OAuth consent screen (User type External, app `pim-sync`, scopes `.../auth/contacts.readonly` + `.../auth/calendar.readonly`) → Credentials → Create credentials → OAuth client ID → **Desktop app** → **Publish app → In production** → Download JSON. Full walkthrough: `~/projects/pim-sync/docs/oauth-setup.md` §2.
2. **Hand over the JSON** — say the path (or drop it at `~/.config/pim-sync/client-secret.json`). The agent ingests it into `pim_sync_oauth_client_secret` with `sops set --value-file` (JSON-encoded value file: never on a command line, never echoed).
3. **Click four consent screens** — the agent launches the four flows (`personal`, `work`, `personal --calendar`, `work --calendar`); the browser opens on your desktop and each flow is one click plus the matching account (`personal` = lartyhd@gmail.com, `work` = lars@helpless.ai). The agent then ingests the four token files into sops.
4. **Say GO** after reading the first dry-run reports; the agent flips `live = true` + the maxChanges cap + metricsFile + the Gatus freshness check.

Prepared for you: `~/.config/pim-sync-tokens/` exists (0700) for the consent flow. The dashboard bearer token now lives only in sops — read it when you need it:

```bash
export SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key)
sops -d --extract '["pim_sync_ui_token"]' platforms/nixos/secrets/pim-sync.yaml
unset SOPS_AGE_KEY
```

The dashboard is `http://100.112.252.86:8111` over the NetBird mesh (no LAN/WAN vHost by design).

## Mesh invariants (2026-11-13 review)

Verified against the pim-sync source at the locked rev; the review is
`docs/architecture-understanding/2026-11-13_11-45_contacts-data-architecture.html`.

- **One book per source.** A full Google listing quarantines every book card
  absent from it, explicitly including foreign and hand-made cards
  (`internal/contactsin/quarantine.go:45`). Never merge two sources into one
  book, and never share a book across accounts: `--book` applies to _every_
  account in one invocation (`cmd/pim-sync/account.go:169-172`).
- **The cap is live even in dry-run, and defaults to 50.** A first run against
  a fresh book projects more creates than the cap and aborts with exit 3
  without `--live` (`internal/guard/guard.go:80-100`,
  `cmd/pim-sync/sync.go:30`). Read the projected count from the dry-run report,
  then set `maxChanges` above it for the first live run.
- **`--live` without an explicit cap is refused** (fail-closed, `ErrNoCap`);
  `--clear-deletion` is the only way a held deletion may propagate, keyed
  `contact:<uid>` / `event:<iCalUID>`.
- **Dry-runs leave nothing behind.** No state mutation, no receipt; the report
  goes to stdout and is not persisted (`cmd/pim-sync/report.go:10-45`).
- **Live runs append one receipt** (landed 2026-11-13, pim-sync `74e91f2`):
  `internal/receipt` appends one 0600 JSONL line per run to
  `--receipts <dir>/<command>.jsonl` — actor (`bot:pim-sync`), mode, per-leg
  counts, capped UID + quarantine-key lists, resolved exit code — with an
  fsync per append and a 5 MiB rotation to `<file>.1`. A receipt failure
  warns, never fails the run.
- **Receipt sink decision (T7.6): rotated JSONL file + Gatus freshness —
  NOT journal audit events.** Rationale: the trail must survive even when
  the journal pipeline is the thing being debugged, the rotation bounds it
  by construction, and the existing metrics textfile + Gatus pattern
  (anchored-pat doctrine) already covers freshness alarms. A journal
  event sink would add a second ingest path without adding durability the
  file lacks. The dir is wired at the flip via the upstream
  `services.pim-sync.receiptsDir` option (pim-sync `74bf91a`; the wrapper
  sets `/var/lib/pim-sync/receipts`).
- **Run `pim-sync doctor` before the first flip.** It exists
  (`cmd/pim-sync/doctor.go:16-45`, registered at `main.go:44`), checks token
  shapes, state dir and DAV books, and deliberately makes no Google API call;
  it has not yet run against real credentials. Its pass/fail contract is
  machine-pinned end-to-end (2026-11-13, pim-sync `74e91f2`): runtime-built
  fixture trees + byte-exact transcript goldens
  (`cmd/pim-sync/testdata/doctor/*.golden`). The GREEN fixture transcript —
  paths and DAV URL are fixture-relative — reads:

  ```
  ok:   oauth client secret <secret> parses
  ok:   contacts accounts: personal
  ok:   contacts token <fixtures>/tokens/personal.json (refresh token present)
  ok:   calendar accounts: personal
  ok:   calendar token <fixtures>/tokens/personal-calendar.json (refresh token present)
  ok:   carddav discovery at <dav>
  ok:   addressbook "Contacts" at /dav/card/user%40example.test/Contacts/
  ok:   caldav discovery at <dav>
  ok:   calendar "Personal" at /dav/cal/user%40example.test/Personal/
  doctor: all checks passed
  ```

  The FAILING fixture exits 1 naming its failure count; the transcript
  shows each check's verdict line (`FAIL: contacts token …: no refresh
  token — run pim-sync auth --account broken`).
- **One DAV endpoint and one Stalwart credential pair.** Multiple Google
  accounts are token stems (`personal`, `work`) processed sequentially; there
  is no second CardDAV server option. Do not add one.
- **No merge engine.** Duplicates are reported, conflicts are counted but not
  queued for review, and nothing auto-merges (`README.md:138`,
  `docs/CONTRACT.md:63-65`).
- **The model is lossy by design.** Only FN/first/last, one email, org and
  indexed phones cross the seam (`internal/personcard/personcard.go:44-50`);
  addresses, birthdays, notes, photos and extra emails live in the vCard but do
  not participate in field merge.
- **Metrics carry `{leg,account}` only** — five gauges
  (`changes`, `conflicts`, `quarantined`, `quarantine_depth`,
  `last_success_unix`), no `source`/`book` label
  (`internal/metrics/metrics.go:169-193`). README lists four (drift).
- **Twenty import is one-way into its own book** (`Twenty import`,
  `twenty:`-scoped UIDs); the 139-row rehearsal ran against an in-memory fake
  CardDAV server, not the production book.

## Gotchas

- **Package pin lives in the wrapper** (`services.pim-sync.package = inputs.pim-sync.packages.x86_64-linux.default`) because upstream's `package` option has NO default (bank-sync/index pattern). Do not "fix" it to a mkPackageOption — nixpkgs has no pim-sync attr.
- **Token rotation**: `tokenSeedDir` seeds ONLY empty slots; once the service refreshes a token, `/var/lib/pim-sync/tokens` owns it (sops is the seed, never the runtime store — the 7-day-rotation lesson).
- **Kill switch**: `systemctl disable --now pim-sync.timer` stops everything; nothing else runs on its own.
- **vendorHash**: upstream's FOD was measured against its own nixpkgs pin; SystemNix follows nixpkgs (root pin, go 1.27.3 ≥ upstream floor 1.27.2). If a future nixpkgs bump invalidates the hash: fix UPSTREAM first (fresh hash into upstream flake.nix), downstream `overrideAttrs` shim only as documented interim (drift-treadmill doctrine).
- Infra follows (flake.nix): `flake-parts`, `go-nix-helpers` (+ deep `go-nix-helpers.inputs.treefmt-nix`), `nixpkgs` — the deep edge kills pim-sync's nested treefmt copy (deep-treefmt audit leg; journal/papdashboard precedent).
