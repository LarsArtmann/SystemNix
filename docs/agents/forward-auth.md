# Forward-auth doctrine — who authenticates a subdomain

> Rule: **exactly one auth layer per subdomain.** Either the app owns
> authentication natively, or Caddy's `protectedVHost` (oauth2-proxy
> forward-auth) owns it — never both, never neither-for-external.

## The decision

When a service registers a dashboard subdomain (integration registry,
`modules/nixos/services/README.md`):

1. **Does the app speak OIDC natively** (a Pocket ID client, its own login
   page/session)? → register a **`plain` vHost**. The app is the single
   auth layer. `protectedVHost` on top would **double-auth the OAuth
   redirect flow**: the app redirects the browser to Pocket ID, oauth2-proxy
   intercepts that trip with ITS OWN login redirect, and the two redirect
   loops interleave — login breaks. "Belt and braces" here is the failure
   mode, not extra safety.
2. **Does the app have no native user auth** (metrics UIs, internal tools
   with no accounts)? → register a **`protected` vHost**
   (`modules/nixos/services/caddy.nix`, `forwardAuth` applies to `@external`
   only — LAN clients pass through unfettered by design).
3. **Public-by-design** (landing pages, health probes)? → `plain`, no auth
   anywhere, and say so in the registry row so audits do not "fix" it.

## The two counter-examples (both are `plain` on purpose)

- **paperless** — native OIDC via Pocket ID (django-allauth, Layer 1).
  The blind-spot row in `caddy.nix` (`registryBlindSubdomains`) documents
  why its hand-written vHost is plain: `protectedVHost` would double-auth.
- **browser-history** — upstream module handles OIDC natively (passkeys
  disabled server-side since 2026-10-16); the server entry in
  `modules/nixos/services/browser-history.nix` replaces the registry's
  protected default with a plain vHost for exactly the redirect-flow reason.

## The positive case

- **gatus** — no user accounts of its own; the oauth2-proxy forward-auth
  gate IS the auth layer. This is what `protectedVHost` is for.

## Orthogonal: startup gating is not request auth

`lib/mkOidcGate` (ExecStartPre probing Pocket ID + DNS + TLS) orders service
STARTUP behind the OIDC stack being reachable — it authenticates nothing at
request time. A service can use `mkOidcGate` and `plain` vHost together
(browser-history does: gate for boot ordering, native OIDC for requests).

## Review hook

A new subdomain row that pairs a native-OIDC app with `protected` (or an
auth-less app with `plain` reachable externally) fails this doctrine — fix
the row, not the audit.
