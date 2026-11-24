# Stalwart live inventory — pbx.artmann.tech (verified 2026-11-18)

The next audit's one-stop answer to "which Stalwart accounts, books, and
domains are LIVE" — every fact below was SSH-verified on 2026-11-18 unless
marked **inferred**, and every section carries its re-verification command.

## Service facts (verified)

| Fact            | Value                                                                                                           |
| --------------- | --------------------------------------------------------------------------------------------------------------- |
| Host            | `pbx.artmann.tech` (root SSH works: `ssh root@pbx.artmann.tech`)                                                |
| Service         | `stalwart.service` — **active** (`systemctl is-active stalwart`)                                                |
| Binary version  | stalwart **0.16.27** (store path in the unit's ExecStart)                                                       |
| Store           | RocksDB at `/var/lib/stalwart/db` (config JSON declares only the store)                                         |
| Config          | `/nix/store/jvyji802…-stalwart.json` = `{"@type":"RocksDb","path":…}`                                           |
| Admin bootstrap | `STALWART_RECOVERY_ADMIN=admin:$(systemd-creds cat admin)` in ExecStart                                         |
| Listeners       | `127.0.0.1:8082` (inner HTTP/admin API), `*:993` IMAPS, `*:995` POP3; public HTTPS via the host nginx on `:443` |
| Webmail         | Bulwark at `webmail.artmann.tech` (hosts/pbx/bulwark.nix)                                                       |

Re-verify:

```sh
ssh root@pbx.artmann.tech 'systemctl is-active stalwart && ss -tlnp | grep stalwart'
```

## Domains (verified via DNS + module notes)

- **larsartmann.cloud** — the only fleet domain whose MX points at this
  VPS (DMARC collector domain; see docs/services/nix-email.md).
- **artmann.tech** — MX = Google Workspace (verified via dig); mail for it
  is NOT served here. The CRM contact hub still uses this VPS for CardDAV
  only.
- Stalwart local domains/accounts are STORE data provisioned via the
  webadmin/API — config cannot declare them; the authoritative list lives
  in the RocksDB store, readable only through the admin API.

Re-verify: `dig +short MX artmann.tech larsartmann.cloud`

## Accounts and address books (inferred — verify via admin API)

The admin API answers on `http://127.0.0.1:8082` (Basic auth as the
recovery admin; endpoint paths are 0.16-admin API):

```sh
ssh root@pbx.artmann.tech '
  PW=$(systemctl-creds-in-unit-context)   # the cred is unit-scoped: query
                                          # from inside the unit or via the
                                          # webadmin session instead
  curl -sk -u "admin:$PW" http://127.0.0.1:8082/api/principals'
```

- The `systemd-creds cat admin` credential is NOT readable from a root
  SSH session (verified 2026-11-18: "Credential 'admin' not set") — it is
  bound to the unit context. Use the webadmin UI (nginx vhost) or run the
  query inside the unit namespace.
- **Inferred book set**: every Stalwart account carries the default
  personal address book ("Contacts"); the CRM's CardDAV out-mirror pushes
  the Kith book (`Contacts (Kith)` — naming per pim-sync's book
  convention: ""/default/personal → "Contacts", else "Contacts (<name>)").
  Exact book names per account: verify via the pim-sync dry-run review
  list once its timer is live (docs/services/pim-sync.md).

## The mesh role (why this doc exists)

- Contacts hub per `docs/DATA-MODESH.md` (crm repo): this Stalwart is the
  CardDAV hub; Google edge syncs via pim-sync; the CRM's `carddavin`
  projection reads ONE book per account back into the CRM (IN leg).
- The CRM out-mirror (`crm-server -carddav-sync`) writes the Kith book
  here; the roster currently carries ~6.3k cards (the unblock-or-retire
  decision row in the crm TODO_LIST).
