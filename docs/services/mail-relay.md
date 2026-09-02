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
| System/cron mail  | root + postmaster aliases → `fromAddress`; `smtp_generic_maps` rewrites locally-generated senders | cron failure output reaches the inbox |

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
2. **Verify a sending domain** in the provider (add DNS records). Until then the
   default from address `onboarding@resend.dev` works but ONLY delivers to your
   own account's email — fine for testing.
3. **Set the credential** (interactive editor, never on a command line — the
   fish_history leak class):
   ```
   sudo sops platforms/nixos/secrets/mail-relay.yaml   # replace the PLACEHOLDER value
   sudo systemctl restart postfix
   ```
   The sops template restartUnits also restarts postfix on the NEXT deploy; the
   manual restart makes it immediate.
4. **Set the real from address** (once the domain is verified): set
   `services.mail-relay.fromAddress` in `configuration.nix` (e.g.
   `noreply@your-domain`) and `nix run .#deploy`. Paperless/Forgejo FROM values
   derive from it automatically.
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
- **Monitoring**: Gatus "Mail Relay (SMTP)" (TCP :25) + "Mail Relay Service"
  (`system_service_state_failed`/`start_limit_hit` for postfix). A red TCP check
  with postfix active = listen socket wedged (restart postfix).
