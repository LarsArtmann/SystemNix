# Immich OAuth Self-Signed Cert Fix — 2026-04-09

**Session Date:** 2026-04-09 08:02 CEST
**Branch:** master
**Scope:** Immich OAuth via Authelia, TLS trust for self-signed certs
**Validation:** `just test-fast` passes cleanly

---

## A) FULLY DONE ✅

### Immich OAuth 500 Error — Root Cause & Fix

**Symptom:** Clicking "Login with Authelia" on `immich.home.lan` redirected to Authelia successfully, but the callback to `/api/oauth/authorize` returned **HTTP 500** every time. Browser console showed repeated:

```
/api/oauth/authorize:1  Failed to load resource: the server responded with a status of 500
```

**Root Cause:** Immich's Node.js server makes a server-side outbound request to `https://auth.home.lan` during the OAuth token exchange. Caddy terminates TLS using sops-managed **self-signed certificates**. Node.js rejects self-signed certs by default — there was no `NODE_TLS_REJECT_UNAUTHORIZED` override, and the internal CA was not in the system trust store.

The Authelia side was fine (forward-auth worked, OIDC discovery worked from the browser). The failure was specifically Immich's server-side callback to Authelia's token endpoint.

**Fix:** Added `environment.NODE_TLS_REJECT_UNAUTHORIZED = "0"` to the Immich service config in `modules/nixos/services/immich.nix:22`.

| File                                | Change                                                 |
| ----------------------------------- | ------------------------------------------------------ |
| `modules/nixos/services/immich.nix` | Added `environment.NODE_TLS_REJECT_UNAUTHORIZED = "0"` |

### Authelia Email Investigation

Investigated why Authelia doesn't send emails. The notifier writes to a **local file** instead:

```nix
notifier.filesystem.filename = "/var/lib/authelia-main/notification.txt";
```

No SMTP configuration exists anywhere in the codebase. This means password reset, 2FA setup links, etc. are only readable from the server filesystem.

---

## B) PARTIALLY DONE 🔶

Nothing partially done.

---

## C) NOT STARTED ⬜

| Item                              | Notes                                                                                                                   |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Deploy with `just switch`         | Fix is code-complete but not yet applied to the running system                                                          |
| SMTP/email for Authelia           | Notifier still writes to file. Would need a mail relay (e.g. Postfix relayhost, or external SMTP like Sendgrid/Mailgun) |
| Internal CA in system trust store | Cleaner alternative to `NODE_TLS_REJECT_UNAUTHORIZED=0`. Would fix all services at once                                 |

---

## D) TOTALLY FUCKED UP 💥

Nothing blown up this session.

---

## E) WHAT WE SHOULD IMPROVE

1. **System-wide CA trust** — Adding the sops-managed CA to `/etc/ssl/certs` via `security.pki.certificateFiles` would fix this for Immich and any future service that calls internal HTTPS endpoints, without disabling TLS verification entirely.

2. **Authelia notifications via email** — Without SMTP, 2FA enrollment and password reset notifications are invisible to users. The file-based notifier is only useful for single-user homelab setups.

3. **Same cert likely breaks Gitea OAuth** — Gitea is also an Authelia OIDC client (`modules/nixos/services/authelia.nix`). If it makes server-side calls to `auth.home.lan`, it would hit the same self-signed cert issue.

---

## F) Top Things to Do Next

| #   | Priority | Item                                                                    | Effort  |
| --- | -------- | ----------------------------------------------------------------------- | ------- |
| 1   | P0       | Run `just switch` to deploy the Immich fix                              | 5 min   |
| 2   | P1       | Add internal CA to system trust store (`security.pki.certificateFiles`) | Low     |
| 3   | P1       | Remove `NODE_TLS_REJECT_UNAUTHORIZED=0` once CA is trusted              | Trivial |
| 4   | P2       | Verify Gitea OAuth works (same cert chain)                              | Low     |
| 5   | P2       | Configure Authelia SMTP notifier for real emails                        | Medium  |
| 6   | P3       | Check other OIDC clients for same TLS trust issue                       | Low     |

---

## G) Top #1 Question I Cannot Answer

**Should the internal CA be added to the macOS trust store too?** The darwin platform also uses sops-managed certs if any service makes cross-service HTTPS calls. Unclear if any darwin services currently do.
