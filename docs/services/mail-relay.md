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

| Consumer          | Wiring                                                              | What it gains                                        |
| ----------------- | ------------------------------------------------------------------- | ---------------------------------------------------- |
| Paperless-ngx     | `PAPERLESS_EMAIL_*` → 127.0.0.1:25 (paperless.nix, relay-gated)      | Share links, password-protected archives, account mail |
| Forgejo           | `[mailer]` plain SMTP → 127.0.0.1:25 (forgejo.nix, relay-gated)      | Issue/PR notifications                                |
| System/cron mail  | `recipient_canonical_maps` rewrites root@/postmaster@ recipients → `systemMailRecipient` (default `fromAddress`); `smtp_generic_maps` rewrites senders. aliases(5) is INERT on a null client (local(8) never runs) — the canonical map is the real mechanism | cron failure output reaches the inbox   |

**Pocket ID is deliberately NOT on the relay** — its go-kit emailer fails CLOSED
(`tls=auto` = mandatory STARTTLS) and the TLS mode lives in its DB, not env. It
keeps direct Resend implicit-TLS `:465` and needs its own NEW API key (the old
one was revoked 2026-08-18; one new key can be pasted into both sops files).

**Immich has no SMTP module options** (verified in nixpkgs) — notifications are
admin-UI-only: *Administration → Settings → Notification settings*, point them at
`127.0.0.1:25`, no auth, from = your verified from address. This survives deploys
(the config lives in Immich's DB).

## Go-live (operator, ~10 min)

1. **Resend account** (or any provider with an SMTP submission endpoint):
   create an API key (`re_...`). Resend's SMTP username is the literal string
   `resend`; the API key is the password.
2. **Verify `larsartmann.cloud` in Resend** (*Domains → Add domain* → add the
   shown SPF + DKIM DNS records → wait for "Verified"). Until then sends from
   `noreply@larsartmann.cloud` are REJECTED and defer — the Gatus "Mail Relay
   Queue" check fires as the pending go-live signal (expected).
3. **Set the credential** (interactive editor, never on a command line — the
   fish_history leak class):
   ```
   sudo sops platforms/nixos/secrets/mail-relay.yaml   # replace the PLACEHOLDER value
   sudo systemctl restart postfix
   ```
   The sops template restartUnits also restarts postfix on the NEXT deploy; the
   manual restart makes it immediate.
4. **From address already set**: the module default IS
   `noreply@larsartmann.cloud`; nothing to change in `configuration.nix`.
   Override `services.mail-relay.fromAddress` / `systemMailRecipient` only if
   system mail (root@, cron output) should land somewhere other than the
   from address's mailbox.
5. **End-to-end test** (no `mail`/`sendmail` on the system PATH — use the
   postfix package's sendmail binary):
   ```
   sp="$(ls -d /nix/store/*-postfix-*/bin/sendmail 2>/dev/null | head -1)"
   printf 'To: you@example.com\nSubject: mail relay test\n\nrelay test body\n' | sudo "$sp" -t
   mailq                        # must drain within ~30s
   journalctl -u postfix -n 50  # status=sent (2xx from upstream)
   ```
   Paperless: *Settings → Share links* → create a link with "Email" → check inbox.
   Forgejo: trigger a test notification (close an issue you're subscribed to).

## Paperless INBOUND mail (separate feature, UI-configured)

Mail consumption (poll a mailbox, consume attachments as documents) is configured
entirely in the Paperless UI (*Settings → Mail accounts* + *Mail rules*) — no env
vars, stored in its PostgreSQL. The polling task runs every 10 min by default
(`PAPERLESS_EMAIL_TASK_CRON` overrides the cron). Needs an IMAP mailbox decision
(app password for Gmail) — nothing to deploy, see paperless docs.

## Troubleshooting

- **Everything defers (`mailq` non-empty, `status=deferred`)**: credential still
  the PLACEHOLDER, or provider rejects the from-domain. Upstream 4xx/5xx lines
  land in `journalctl -u postfix`.
- **`Authentication failed`**: key rotated at the provider but sops not updated →
  `sudo sops platforms/nixos/secrets/mail-relay.yaml`, restart postfix.
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

**Verification**: `tests/test-mail-relay.nix` (VM: loopback-only listener, null-client
config, sender+recipient rewrite E2E, collector fail-closed) and
`scripts/post-deploy-check.sh` §12 (live: postfix active, SMTP banner, placeholder
WARN, paperless.conf wiring, collector textfile).
