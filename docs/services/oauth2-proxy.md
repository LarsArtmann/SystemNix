# oauth2-proxy (Layer 2 forward-auth bridge)

**Service:** `services.oauth2-proxy-config` — `modules/nixos/services/oauth2-proxy.nix` (wrapper over nixpkgs `services.oauth2-proxy`). Port 4180 (`lib/ports.nix`), loopback only — never has its own vHost; Caddy `protectedVHost`s call it via `forward_auth localhost:4180`. The `auth.<domain>` vHost routes `/oauth2/*` here (login/callback legs).

One instance fronts EVERY Layer 2 service (SigNoz, SearXNG, Twenty, Dozzle, Crush Daily, indexer-web, dashboards, …). It is down ⇒ external access to all of them breaks (LAN bypass unaffected — `protectedVHost` keeps LAN traffic off this path entirely). Layer semantics: [docs/agents/sso-dns.md](../agents/sso-dns.md).

## What it serves

| Route              | Auth | What                                                                     |
| ------------------ | ---- | ------------------------------------------------------------------------ |
| `/oauth2/auth`     | none | The forward-auth decision endpoint Caddy calls on every external request |
| `/oauth2/sign_in`  | none | Login redirect target (Caddy 401-handler sends users here)               |
| `/oauth2/callback` | none | OIDC code callback (redirectURL `https://auth.<domain>/oauth2/callback`) |
| `/oauth2/sign_out` | none | Logout — clears the shared `.<domain>` cookie for ALL Layer 2 apps       |
| `/ping`            | none | Liveness (ExecStartPost gate)                                            |

## Ops

- **Provider wiring** — oidc, issuer `https://auth.<domain>`, clientID `oauth2-proxy` (the one client in the provisioner's DEFAULT list; everything else registers via its own module). Scope `openid profile email`; **PKCE S256** (`code-challenge-method`). Client secret comes from the provisioner path (`/var/lib/pocket-id/client-secrets/oauth2-proxy`) when provision is enabled, else sops `oauth2_proxy_client_secret`.
- **`whitelist-domain` is load-bearing** — `[".<domain>"]` + `.<cloudDomain>` when set. Without it the OIDC callback succeeds but the post-login redirect back to the original vHost 500s (`domain / port not in whitelist`). Any new top-level domain serving protected vHosts must land here.
- **Cookie secret format is unit-gated** — `oauth2_proxy_cookie_secret` (sops) must base64-decode to EXACTLY 16/24/32 bytes; a `+`-privileged ExecStartPre fails the unit at start with the byte count if not. Rotate: `openssl rand -base64 32` → sops → restart (invalidates all Layer 2 sessions).
- **Provision restart chain** — `partOf pocket-id-provision.service`: the client secret loads via systemd `LoadCredential` at process start, so a provisioner secret regeneration must bounce this unit (the partOf does it). Same reason a manual secret rotation needs `systemctl restart oauth2-proxy`.
- **Boot ordering** — `mkOidcGate` (DNS → TLS → discovery-endpoint curl, 300s budget; dnsblockd needs ~2min at boot) with `TimeoutStartSec = 6min` (> the gate budget). StartLimit deliberately 10/300s (boot races).
- **`SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt`** — the NixOS-merged bundle including the dnsblockd-CA. Without it Go's TLS silently misses the custom CA and token exchanges against `auth.<domain>` fail 500.
- **Symptoms** — post-login redirect 500 ⇒ whitelist-domain; token-exchange 500 ⇒ SSL_CERT_FILE; `invalid_client` at exchange ⇒ secret desync (see [pocket-id.md](./pocket-id.md) recovery); 401-loop on a native-OIDC app ⇒ that app should not be behind `protectedVHost` (double-auth rule, sso-dns.md).
- **`setXauthrequest` + `X-Auth-Request-User/Email`** — `protectedVHost` copies these headers to backends; apps wanting the identity read them, they are NOT trusted on LAN-bypass paths (set only after forward-auth).

## Related

- [pocket-id.md](./pocket-id.md) — the IdP side; client provisioning + secret desync recovery
- [docs/agents/sso-dns.md](../agents/sso-dns.md) — Layer 0/1/2 table, `protectedVHost` semantics, double-auth rule
- [caddy.md](./caddy.md) — the `protectedVHost` renderer calling `forward_auth`
