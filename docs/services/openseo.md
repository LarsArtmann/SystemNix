# openseo (self-hosted SEO suite)

**Service:** `services.openseo` — `modules/nixos/services/openseo.nix`, native NixOS service (`pkgs.openseo`, no Docker). Port 3002 (`lib/ports.nix`), loopback `vite preview`. URL: `seo.<domain>` — a **hand-rolled Caddy vHost** in `caddy.nix` (NOT the registry's protectedVHost) that exempts `/api/gsc/oauth/callback` from forward-auth: OAuth callback endpoints must stay deterministic and immune to SameSite policy changes (best practice; the browser carries the cookie anyway). All other paths follow Layer 2 behavior. DNS `seo`. `AUTH_MODE=local_noauth` — the app itself has no login; external auth is Caddy's.

## What it serves

| Route                     | Auth                        | What                                              |
| ------------------------- | --------------------------- | ------------------------------------------------- |
| `/`                       | forward-auth / open LAN     | SEO dashboard (keywords, ranks, audits)           |
| `/api/gsc/oauth/callback` | EXEMPT from forward-auth    | Google Search Console OAuth callback              |

## Ops

- **Startup chain (ExecStartPre)** — `validate` (feature keys non-empty — enabling GSC or AI without the sops keys REFUSES to start, catching the empty-placeholder-render class) → `stage` → `migrate` → `vite preview`. Stage symlinks read-only store files into `/var/lib/openseo/project/` while keeping persistent writable state: `.wrangler` (D1 SQLite lives there) and `node_modules/.vite-temp` as REAL dirs (Vite's config loader writes into it — a plain store symlink EROFS-crashes preview). Migrate applies D1 migrations locally via wrangler.
- **Secrets (sops `platforms/nixos/secrets/openseo.yaml` → `openseo-env` template)** — `google_client_id`, `google_client_secret`, `better_auth_secret` (GSC integration), `openrouter_api_key` (SAM in-app SEO agent). Features gate on `services.openseo.googleSearchConsole.enable` / `aiFeatures.enable` with startup validation.
- **GSC redirect URI** — `https://seo.<domain>/api/gsc/oauth/callback` (must match the Google Cloud OAuth client config exactly).
- **restartTriggers on the package** — prevents a stale vite preview serving GC'd store files from the old path (homepage-dashboard pattern).
- **Telemetry opted out** — `OPENSEO_TELEMETRY_DISABLED=1` (anonymous heartbeats; unnecessary self-hosted).
- **Monitoring** — Gatus "OpenSEO" (`http://localhost:3002`, gatus-config.nix — the hand-rolled vHost also means no registry checks); unit carries onFailure.

## Related

- [docs/agents/sso-dns.md](../agents/sso-dns.md) — the OpenSEO vHost exemption footnote + gotcha table
- [docs/agents/nix-flakes.md](../agents/nix-flakes.md) — `pkgs.openseo` packaging
