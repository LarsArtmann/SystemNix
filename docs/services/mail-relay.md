# Mail Relay — Central Outbound SMTP (Postfix Null Client)

**Module:** `modules/nixos/services/mail-relay.nix` (`services.mail-relay`, enabled in `platforms/nixos/system/configuration.nix`)
**Deployed:** 2026-09-02 — ships with a PLACEHOLDER credential; go-live is a 10-minute operator task (below).

---

## What it is

One Postfix null client on `127.0.0.1:25` (loopback-only, unauthenticated, **no local
delivery**) that relays every outbound mail through ONE authenticated upstream
submission endpoint:

```
paperless / forgejo / cron+system mail
        │  plain SMTP (no auth, no TLS — loopback only)
        ▼
postfix null client (127.0.0.1:25, mydestination="")
        │  AUTH + mandatory TLS (smtp_tls_security_level=encrypt)
        ▼
smtp.resend.com:587  (credential: sops mail_relay_password)
```

Why a shared relay instead of per-app SMTP credentials: one sops secret to rotate,
provider rejections visible in one `mailq`, local queue + retry when the provider
hiccups, and apps never hold the upstream credential. Why not direct-to-MX:
residential egress has no rDNS — every provider rejects it.

## Consumers

| Consumer         | Wiring                                                                                                                                                                                                                                                       | What it gains                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------ |
| Paperless-ngx    | `PAPERLESS_EMAIL_*` → 127.0.0.1:25 (paperless.nix, relay-gated)                                                                                                                                                                                              | Share links, password-protected archives, account mail |
| Forgejo          | `[mailer]` plain SMTP → 127.0.0.1:25 (forgejo.nix, relay-gated)                                                                                                                                                                                              | Issue/PR notifications                                 |
| System/cron mail | `recipient_canonical_maps` rewrites root@/postmaster@ recipients → `systemMailRecipient` (default `fromAddress`); `smtp_generic_maps` rewrites senders. aliases(5) is INERT on a null client (local(8) never runs) — the canonical map is the real mechanism | cron failure output reaches the inbox                  |

**Pocket ID is deliberately NOT on the relay** — its go-kit emailer fails CLOSED
(`tls=auto` = mandatory STARTTLS) and the TLS mode lives in its DB, not env. It
keeps direct Resend implicit-TLS `:465` and needs its own NEW API key (the old
one was revoked 2026-08-18; one new key can be pasted into both sops files).

**Immich has no SMTP module options** (verified in nixpkgs) — notifications are
admin-UI-only: _Administration → Settings → Notification settings_, point them at
`127.0.0.1:25`, no auth, from = your verified from address. This survives deploys
(the config lives in Immich's DB).

## Go-live (operator, ~10 min)

1. **Resend account** (or any provider with an SMTP submission endpoint):
   create an API key (`re_...`). Resend's SMTP username is the literal string
   `resend`; the API key is the password. Leave the key's domain restriction on
   "All domains" (or scope it to `larsartmann.cloud`) — a key scoped to another
   domain gets `550 ... not authorized to send emails from larsartmann.cloud`.
2. **Verify `larsartmann.cloud` in Resend** (_Domains → Add domain_ → add the
   shown SPF + DKIM DNS records → wait for "Verified"). Until then sends from
   `noreply@larsartmann.cloud` are REJECTED with
   `550 This API key is not authorized to send emails from larsartmann.cloud` —
   the message BOUNCES and the queue drains instantly (live 2026-09-06), so
   `mailq` stays empty and the "Mail Relay Queue" check stays green; the
   `status=bounced` line in the postfix journal is the real signal.
   **Status 2026-09-18:** steps 1+3 are DONE (real key deployed,
   `mail_relay_credential_placeholder 0`) and the runbook test send is ACCEPTED
   (`status=sent (250 ...)`, live 2026-09-18). SPF CORRECTION 2026-09-21
   (live dig + domains repo): the SPF records are DONE — the apex lockdown
   `v=spf1 -all` DELIBERATELY STAYS (non-sending-domain hardening; Resend
   never sends with an apex envelope-from), and Resend's SPF verification
   rides the LIVE routing-subdomain CNAMEs `send.larsartmann.cloud` →
   `send.forge.rmta.net` + `rsend.larsartmann.cloud` →
   `rsend-euw1.forge.rmta.net` (domains repo `318affa`; NEVER add
   `include:amazonses.com` to the apex). The 250 may still be the
   owner-address allowance (`lars@larsartmann.cloud`): confirm "Verified" in
   the dashboard, then confirm a paperless share-link / forgejo notification
   reaches a non-owner inbox.
3. **Set the credential** (interactive editor, never on a command line — the
   fish_history leak class):
   ```
   SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) \
     sops platforms/nixos/secrets/mail-relay.yaml   # replace the PLACEHOLDER value (as your user)
   sudo systemctl restart postfix
   ```
   The sops template restartUnits also restarts postfix on the NEXT deploy; the
   manual restart makes it immediate.
4. **From address already set**: the module default IS
   `noreply@larsartmann.cloud`; nothing to change in `configuration.nix`.
   Override `services.mail-relay.fromAddress` / `systemMailRecipient` only if
   system mail (root@, cron output) should land somewhere other than the
   from address's mailbox.
5. **End-to-end test** (`sendmail` IS on the system PATH as the postfix
   setgid wrapper, live-verified 2026-09-06):
   ```
   printf 'Subject: relay test\n\nok\n' | sudo sendmail -f noreply@larsartmann.cloud you@example.com
   journalctl -u postfix -n 50   # status=sent (2xx from upstream)
   ```
   Paperless: _Settings → Share links_ → create a link with "Email" → check inbox.
   Forgejo: trigger a test notification (close an issue you're subscribed to).

## Paperless INBOUND mail (separate feature, UI-configured)

Mail consumption (poll a mailbox, consume attachments as documents) is configured
entirely in the Paperless UI (_Settings → Mail accounts_ + _Mail rules_) — no env
vars, stored in its PostgreSQL. The polling task runs every 10 min by default
(`PAPERLESS_EMAIL_TASK_CRON` overrides the cron). Needs an IMAP mailbox decision
(app password for Gmail) — nothing to deploy, see paperless docs.

## Troubleshooting

- **`550 This API key is not authorized to send emails from larsartmann.cloud`
  (`status=bounced`, queue drains instantly)**: the credential AUTHENTICATED —
  the from-domain lacks authorization. Either `larsartmann.cloud` is not yet
  Verified in Resend (go-live step 2) or the API key is domain-scoped to a
  different domain (recreate with "All domains" / `larsartmann.cloud`).
- **No bounce notifications ever arrive**: by design — Resend rejects
  null-sender DSNs (`MAIL FROM <>` → `550 Invalid from field`, live
  2026-09-06), so postfix's NDRs are discarded. No loop, but failed sends are
  visible ONLY in `journalctl -u postfix`.
- **Everything defers (`mailq` non-empty, `status=deferred`)**: credential still
  the PLACEHOLDER, or provider rejects the from-domain. Upstream 4xx/5xx lines
  land in `journalctl -u postfix`.
- **`Authentication failed`**: key rotated at the provider but sops not updated →
  sops-edit `platforms/nixos/secrets/mail-relay.yaml` with the SOPS_AGE_KEY one-liner
  (go-live step 3), restart postfix.
- **Config changed but postfix didn't pick it up**: shouldn't happen — the module
  stamps settings into a `postfix-config-stamp` restartTrigger (the nixpkgs
  module has none of its own). Secret changes ride the sops template
  `restartUnits`.
- **Monitoring**: Gatus "Mail Relay (SMTP)" (TCP :25), "Mail Relay Service"
  (postfix failed/start-limit states from system-health), and "Mail Relay
  Queue" (the `mail-relay-metrics` collector: queue depth vs
  `queueAlertThreshold`, credential PLACEHOLDER flag — fail-closed). A red TCP
  check with postfix active = listen socket wedged (restart postfix). A firing
  queue check AFTER go-live = genuine upstream rejections (provider outage,
  expired key, unverified sender) — read `mailq` + `journalctl -u postfix`.
  The collector itself failing (`mv ... Operation not permitted`) is the
  textfile foreign-owner class — fixed 2026-09-06 (mktemp + AmbientCapabilities
  CAP_FOWNER, self-healing; regression-tested), guarded by
  `scripts/audit-textfile-tmp.sh` (pre-commit + CI). Do NOT reintroduce a
  fixed `.tmp` name or a hardcoded `/run/secrets-rendered` path — real sops
  renders under `/run/secrets/rendered`, and the SASL path must stay
  interpolated from the sops template definition.

**Verification**: `tests/test-mail-relay.nix` (VM: loopback-only listener, null-client
config, sender+recipient rewrite E2E, collector fail-closed) and
`scripts/post-deploy-check.sh` §12 (live: postfix active, SMTP banner, placeholder
WARN, paperless.conf wiring, collector textfile).

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### Mail Relay (central outbound SMTP, 2026-09-02)

**Module:** `modules/nixos/services/mail-relay.nix` (`services.mail-relay`) — Postfix NULL CLIENT on `127.0.0.1:25` (`lib/ports.nix` `mail-relay`): loopback-only, unauthenticated, NO local delivery (`mydestination=""`), everything relayed through ONE authenticated upstream submission endpoint (default Resend `smtp.resend.com:587`, `smtp_tls_security_level=encrypt`). Runbook + go-live: `docs/services/mail-relay.md`.

- **Consumers:** Paperless (`PAPERLESS_EMAIL_*` → 127.0.0.1:25, relay-gated — Django's `EMAIL_ENABLED` flips on precisely because the host is no longer the literal string `localhost`; paperless 3.1.0 `settings.py`), Forgejo (`[mailer]` PROTOCOL "" plain SMTP, relay-gated), and system/cron mail (`recipient_canonical_maps` rewrites root@/postmaster@ → `systemMailRecipient`; `smtp_generic_maps` texthash rewrites locally-generated senders — generic maps hit envelope AND headers). **aliases(5) is INERT on a null client** — aliases only apply in local(8) delivery and `mydestination=""` means local(8) NEVER runs, so the nixpkgs `rootAlias` option is decorative here; the recipient canonical map (applied at cleanup, BEFORE queuing) is the real mechanism.
- **`texthash:` NOT `hash:`** — `postfix-setup` only postmaps `services.postfix.mapFiles` when its OWN unit changes, so a sops-rotated credential would never reach a `.db` map; texthash reads the rendered file live. The smtp client daemon runs as `mail_owner` (postfix) and is NOT chrooted (nixpkgs master.cf renders `-`), hence the sops template `mail-relay-sasl` is postfix:postfix 0400. Raw secret stays root-owned (only the template is read).
- **Collector outage 2026-09-02..06 (845+ failed runs, Gatus "Mail Relay Queue" red 4 days — postfix itself NEVER failed):** commit `64d68d7d` switched `mail-relay-metrics` from root to `User = postfix` (fixing a real showq-EACCES) but the LAST root-era run left a root-owned `mail-relay.prom` behind; in the sticky 1777 textfile dir the postfix user cannot rename over a foreign-owned file without CAP_FOWNER, so EVERY run died at `mv` and the textfile froze. Compounding it, the collector probed a HAND-WRITTEN `/run/secrets-rendered/mail-relay-sasl` path that does not exist (real sops-nix renders under `/run/secrets/rendered/` — check the deployed postfix main.cf, not the fixture) and flagged the credential missing on every run. **The VM test VALIDATED the bug:** `mock-sops.nix`'s template-path DEFAULT was itself `/run/secrets-rendered/` — fixture and bug agreed, prod disagreed (same class as the `email_states` fixture trap). Fixes: SASL path INTERPOLATED from `config.sops.templates."mail-relay-sasl".path` (single source of truth with postfix's texthash map — never a literal), unique `mktemp` tmp + `chmod 644` + `trap rm EXIT` + `CapabilityBoundingSet = "CAP_FOWNER"` on the unit (self-heals the stale root-owned file — NO manual rm needed), mock-sops default corrected to `/run/secrets/rendered/`, and a VM-test regression step that seeds a root-owned prom + asserts the collector recovers and the journal never says "missing or unreadable". **Class-wide:** ALL textfile collectors (attic, backup-coordination, buildcache, gpu-active, psi/nvme/amdgpu, system-health, pool-recovery, signoz clickhouse-xfs, signoz-coverage, pocket-id secret-rotation, snapshots pool-metrics) were converted to the same mktemp+CAP_FOWNER pattern; `scripts/audit-textfile-tmp.sh` (pre-commit + CI) rejects fixed-tmp writes and `/run/secrets-rendered` literals — negative-tested. memory-emergency-guard/sev1-escalation are ALLOWLISTED: both already carry CAP_FOWNER + CAP_DAC_OVERRIDE, so the caps defeat the sticky-dir rule and conversion is cosmetic there — revisit on touch.
- **The nixpkgs postfix module has NO restartTriggers** — a config change re-links main.cf via postfix-setup but the RUNNING master keeps the old config. The module stamps settings into a store-path `postfix-config-stamp` trigger; sops rotation restarts postfix via the template's `restartUnits`.
- **Go-live state (2026-09-06, live E2E-verified):** the REAL Resend key is deployed (`mail_relay_credential_placeholder 0`) and the full chain works mechanically: local inject → queue → TLS+AUTH to `smtp.resend.com:587` ACCEPTED → Resend rejects at DATA with `550 This API key is not authorized to send emails from larsartmann.cloud` — auth PASSES, the FROM DOMAIN is not authorized (domain unverified in Resend, or the key is domain-scoped elsewhere — Resend keys can carry a domain restriction; create one with "All domains" or scoped to `larsartmann.cloud`). **Monitoring consequence:** a 550 BOUNCES and drains the queue instantly, so the "Mail Relay Queue" check is GREEN again and no longer signals the pending go-live — the journal `status=bounced` line is the pending signal now. **Resend rejects null-sender DSNs** (the auto-bounce riding `MAIL FROM <>` got `550 Invalid from field`, live 2026-09-06) → NDRs are silently discarded (no double-bounce loop, queue self-drains, but senders never learn of failures). Remaining user step: verify `larsartmann.cloud` in Resend (Domains → SPF/DKIM records) — then re-run the runbook test send. **UPDATE 2026-09-18 (E2E re-test): Resend now ACCEPTS** (`status=sent (250 ...)`, `dsn=2.0.0`, queue drains clean) — the 550 era is over; likely Resend's account-owner-address allowance (`lars@larsartmann.cloud` IS the owner). SPF CORRECTION (2026-09-21, live dig + domains-repo evidence): the earlier "replace the apex SPF" instruction was WRONG — the SPF records are DONE. The domains repo onboarded Resend 2026-09-06 (`318affa`) with SPF-ROUTING SUBDOMAINS, not apex SPF: `send.larsartmann.cloud` → `send.forge.rmta.net` and `rsend.larsartmann.cloud` → `rsend-euw1.forge.rmta.net` (both LIVE, both carry valid SPF — the euw1 target answers `v=spf1 include:amazonses.com ~all`), alongside DKIM `resend._domainkey` and strict `_dmarc p=reject; adkim=s` (satisfied by DKIM exact alignment, `d=larsartmann.cloud`). The apex `v=spf1 -all` is DELIBERATE non-sending-domain hardening (Resend's envelope-from never uses the apex) and MUST NOT be replaced — replacing it would WEAKEN the domain (SPF pass for apex-aligned mail from any SES sender). Remaining user steps: confirm "Verified" in the Resend dashboard, then the non-owner delivery probe (paperless share link / forgejo notification).
- **Pocket ID stays direct-Resend :465 (implicit TLS), NOT on the relay** — routing it through the plaintext relay would fail (pocket-id validates `smtpTls` and the plaintext relay offers no TLS). It needs its own NEW Resend key (old one revoked 2026-08-18; the replacement sits in sops `pocket-id.yaml` `pocket_id_smtp_password`, re-pasted 2026-09-06 via `467983e8`).
- **Pocket ID SMTP root cause + fix (2026-09-17, "Failed to send test email / SMTP host is not configured")**: Pocket ID 2.x moved the application configuration into a DB-backed actor — the `SMTP_HOST`/`SMTP_PORT`/`SMTP_USER`/`SMTP_FROM` env vars the nixpkgs module renders are read ONLY when `UI_CONFIG_DISABLED=true` (source-verified v2.14.0 `appconfig/service.go` `loadDbConfigFromEnv`; the actor bootstraps from the `config_migrated` kv row or defaults, never env). Our DB actor state had empty SMTP values, so every send failed `failed to configure emailer: SMTP host is not configured` while the env vars sat uselessly in the unit. Fix: the module sets `UI_CONFIG_DISABLED = true` + `SMTP_TLS` (new `smtp.tls` option, enum `none|starttls|tls`, default `tls` = implicit TLS for :465; the model default `none` would plaintext-handshake :465 and die) and configuration.nix overrides `smtp.from = "noreply@larsartmann.cloud"` (the module default `noreply@home.lan` can NEVER deliver — Resend rejects unverified domains; Resend's allowance for sending to the ACCOUNT OWNER's own address may still make the test email work before domain verification). The nixpkgs wrapper exports `SMTP_PASSWORD` from the sops credential at start (`systemd-creds cat`), so the key never touches the sqlite DB or its backups. CONSEQUENCES: (1) the admin UI Application Configuration page is now read-only — ALL app config (passkeys, email toggles, CIMD, LDAP) is env/schema-default owned; (2) UI-era DB overrides are inert; (3) the env path validates the WHOLE config at startup (`validateEnvConfig`), so a bad SMTP env value = IdP boot failure = fleet-wide SSO outage — check `journalctl -u pocket-id` right after any smtp.* change. Remaining go-live step: verify `larsartmann.cloud` in Resend (Domains → SPF/DKIM) for delivery beyond the account owner's own address; deploy + re-click "Send test email" (admin user `lars@larsartmann.cloud`).
- **Immich SMTP is admin-UI-ONLY** (zero nixpkgs module options — verified): notifications live in Immich's DB (Administration → Settings → Notifications → 127.0.0.1:25, no auth). Survives deploys.
- **Monitoring:** Gatus "Mail Relay (SMTP)" (raw TCP check, `[CONNECTED]`) + "Mail Relay Service" (`system_service_state_failed`/`start_limit_hit` for postfix) + "Mail Relay Queue" (`mail-relay-metrics` textfile collector: queue depth vs `queueAlertThreshold` 5, credential PLACEHOLDER flag — fail-closed, kills the "sends defer silently" phantom-green) + `postfix` in system-health `monitoredServices` default list (missing-unit-tolerant, monitor365 precedent). **Verified by:** `tests/test-mail-relay.nix` (VM: loopback-only :25, null-client config, sender+recipient rewrite E2E via `postqueue -j` JSON, collector fail-closed — the offline relayHost `127.0.0.2:1` makes delivery REFUSE deterministically, so the message defers instead of bouncing on internet-connected build hosts) + `post-deploy-check.sh` §12 (live: postfix active, SMTP banner via `/dev/tcp`, credential verdict derived from the collector textfile — the rendered SASL map is 0400 postfix under the 0700 root sops dir, so a direct read from the user-run smoke is a permanent false "SASL map missing" WARN even with a real key deployed, live 2026-09-06 — `paperless-web.service` wiring grep, collector textfile).

