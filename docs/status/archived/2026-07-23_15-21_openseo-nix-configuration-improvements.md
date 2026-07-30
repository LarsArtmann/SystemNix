# Status: OpenSEO Nix Configuration Improvements

**Date:** 2026-07-23 15:21
**Scope:** Session to improve OpenSEO self-hosted SEO suite Nix configuration
**Status:** SUPERSEDED — see corrections below (2026-07-23 16:20). Deployed 2026-07-24.

> **Update 2026-07-24:** OpenSEO is deployed and running (`openseo.service` in deployed generation). The v0.1.1 config improvements (telemetry opt-out `OPENSEO_TELEMETRY_DISABLED=1`, conditional GSC/AI feature options, `openseo-validate` ExecStartPre) are all live. MCP integration into Crush `mcpServers` remains an open follow-up (TODO_LIST). D1 database backup relies on BTRFS local snapshots only (no off-site backup — TODO_LIST Priority 0).

> **CORRECTION (2026-07-23 16:20):** Section d) below was **wrong**. The GSC OAuth callback was never "TOTALLY FUCKED UP". The OAuth Authorization Code flow is **browser-initiated** (Google redirects the user's browser to the callback URL, not a server-to-server call). The browser carries the `_oauth2_proxy` cookie (`SameSite=lax`, domain `.home.lan`), which IS sent on top-level GET navigations. The callback would pass forward-auth regardless.
>
> **What WAS done (defensive best practice, not bug fix):** A hand-rolled Caddy vHost exempting `/api/gsc/oauth/callback` from forward-auth was implemented. The callback path was **verified** against OpenSEO v0.1.1 source (`src/routes/api/gsc/oauth/callback.ts` + `src/server/features/gsc/selfHostedOAuth.ts:138`). Eval-time assertions were replaced with a runtime `openseo-validate` ExecStartPre that checks env vars are non-empty. AGENTS.md was updated (Layer 2 SSO table + OpenSEO native build gotcha). All changes pass `nix flake check --no-build`.

---

## What Was Done

### a) FULLY DONE

| # | Change | File(s) | Verified |
|---|--------|---------|----------|
| 1 | Version bump v0.0.26 → v0.1.1 (5 releases of new features) | `pkgs/openseo.nix` | `nix build .#openseo` succeeded |
| 2 | Telemetry opt-out (`OPENSEO_TELEMETRY_DISABLED=1`) | `modules/nixos/services/openseo.nix` | `nix flake check --no-build` passed |
| 3 | `restartTriggers = [ pkg ]` to prevent stale vite preview serving GC'd static files | `modules/nixos/services/openseo.nix` | `nix flake check --no-build` passed |
| 4 | New module options: `googleSearchConsole.enable` + `aiFeatures.enable` | `modules/nixos/services/openseo.nix` | `nix flake check --no-build` passed |
| 5 | Conditional sops secret + template wiring for GSC and AI features | `modules/nixos/services/sops.nix` | `nix flake check --no-build` passed |
| 6 | Post-deploy smoke test (HTTP 200 + HTML body) | `scripts/post-deploy-check.sh` | Not yet deployed |
| 7 | Updated source hash and pnpmDeps hash for v0.1.1 | `pkgs/openseo.nix` | Full build succeeded |

### b) PARTIALLY DONE

- **GSC (Google Search Console) integration wiring**: Module options and sops are wired, but the Caddy vHost has a critical gap (see section d). The GSC OAuth callback path will be blocked by `protectedVHost` forward-auth.
- **AGENTS.md documentation**: The OpenSEO section in AGENTS.md was NOT updated with the new version, new options, or telemetry opt-out.

### c) NOT STARTED

- MCP integration (OpenSEO exposes an MCP server for AI agents — not wired into Crush `mcpServers` config)
- Homepage tile description update (still says "SEO Suite (Rank Tracking, Keywords, Backlinks)" — v0.1.x adds AI Visibility, Prompt Explorer, MCP)
- Homepage icon verification (`google-search-console.png` existence in icon pack — AGENTS.md warns many "obvious" icons don't exist)
- D1 database backup (no backup strategy beyond BTRFS local snapshots)
- NixOS assertion to catch enabling GSC/AI features without the required sops keys

### d) CORRECTED — Was "CRITICAL GAPS", Actually Defensive Hardening

> **CORRECTION (2026-07-23 16:20):** The analysis below was **factually wrong**. Read the correction block at the top of this file. The OAuth callback is browser-initiated, not server-to-server. The browser carries the `_oauth2_proxy` cookie. The callback would pass forward-auth regardless. The fix was applied as defensive best practice, not as a bug fix for a broken flow.
>
> **Original (incorrect) analysis preserved below for audit trail:**

#### 1. ~~GSC OAuth Callback Behind protectedVHost — WILL BREAK~~ FIXED (defensive, not a bug fix)

**The problem:** The Caddy vHost for OpenSEO uses `protectedVHost "seo"` which applies oauth2-proxy forward-auth to ALL paths. When Google Search Console integration is enabled, Google's servers call back to `https://seo.home.lan/api/gsc/oauth/callback` after the user authorizes. Google's servers do NOT carry the oauth2-proxy session cookie → they get redirected to the Pocket ID login page → the OAuth flow fails silently.

**Impact:** If anyone enables `services.openseo.googleSearchConsole.enable = true`, it will appear to work (the "Connect with Google" button renders) but the callback will fail with a redirect loop or auth wall.

**Fix needed:** Caddy needs a path exception for `/api/gsc/oauth/callback` that bypasses forward-auth. Something like:
```nix
"seo.${domain}" = {
  # GSC OAuth callback must bypass forward-auth (Google's servers have no session cookie)
  extraConfig = ''
    ${tlsConfig}
    ${commonConfig}
    @gsc_callback path /api/gsc/oauth/callback
    handle @gsc_callback {
      reverse_proxy localhost:${toString config.services.openseo.port}
    }
    handle {
      ${forwardAuth}
      reverse_proxy localhost:${toString config.services.openseo.port}
    }
  '';
};
```
This requires refactoring `protectedVHost` to allow path exclusions, OR hand-rolling the vHost when GSC is enabled.

#### 2. ~~No Assertion for Missing Sops Keys~~ FIXED (runtime validation instead)

> **CORRECTION (2026-07-23 16:20):** Eval-time assertions checking `config.sops.secrets ? "google_client_id"` would be tautological — the secret is conditionally declared by the same `googleSearchConsole.enable` flag, so it always exists at eval time. Instead, an `openseo-validate` ExecStartPre script checks at runtime that `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `BETTER_AUTH_SECRET` (for GSC) and `OPENROUTER_API_KEY` (for AI) are non-empty. This catches the real failure mode: sops placeholders rendering as empty strings for missing keys.

### e) WHAT WE SHOULD IMPROVE

1. **Fix the GSC OAuth callback Caddy issue** before anyone enables the feature
2. **Add NixOS assertions** for required sops keys when GSC/AI features are enabled
3. **Update AGENTS.md** with the new version, new options, and the GSC callback caveat
4. **Wire MCP integration** — OpenSEO's MCP server is a killer feature for AI-assisted SEO work
5. **Update Homepage description** to reflect v0.1.x features (AI Visibility, MCP)
6. **Verify Homepage icon** `google-search-console.png` exists in the dashboard-icons pack
7. **Add D1 database to backup strategy** — keyword research and rank tracking data is valuable
8. **Consider `VITE_SHOW_DEVTOOLS=false` at build time** — currently set at runtime AND build time (redundant but harmless)

### f) Up to 50 Things to Do Next

#### Critical (blocks GSC feature)
1. Add Caddy path exception for `/api/gsc/oauth/callback` to bypass forward-auth
2. Refactor `protectedVHost` to support per-path forward-auth exclusions (or hand-roll the OpenSEO vHost)
3. Add `lib.assertMsg` assertion: if `googleSearchConsole.enable` then the 3 sops keys must exist
4. Add `lib.assertMsg` assertion: if `aiFeatures.enable` then `openrouter_api_key` must exist
5. Document the GSC redirect URI (`https://seo.home.lan/api/gsc/oauth/callback`) in the module comment

#### High Priority
6. Update AGENTS.md OpenSEO section with v0.1.1 version, new options, telemetry opt-out, GSC caveat
7. Wire OpenSEO MCP server into Crush `mcpServers` config (like qmd MCP)
8. Add functional post-deploy check (verify DataForSEO API key is configured, not just HTML response)
9. Verify `google-search-console.png` icon exists in homepage icon pack
10. Update Homepage tile description to include AI Visibility and MCP
11. Add Gatus body-content check (beyond just `[STATUS] == 200`)
12. Consider adding the GSC OAuth callback to the Gatus check set

#### Medium Priority
13. Add D1 database backup (systemd oneshot + timer, like monitor365 backup pattern)
14. Consider `btrbk` snapshot of `/var/lib/openseo` (currently inside `@`, so already snapshotted, but worth documenting)
15. Explore OpenSEO `DO_NOT_TRACK=1` as a second telemetry opt-out (belt + suspenders)
16. Check if v0.1.x needs larger `MemoryMax` (new project dashboard feature)
17. Consider exposing `ALLOWED_HOST` as a module option instead of hardcoding `seo.${domain}`
18. Consider exposing telemetry opt-out as a module option (`services.openseo.telemetry.enable`)
19. Add `systemd.services.openseo.serviceConfigReadWritePaths` if D1 backup writes elsewhere
20. Add a `services.openseo.package` option (like other SystemNix modules) for overriding the package
21. Consider adding `journalctl` log rotation awareness for vite preview output

#### MCP-Specific
22. Research OpenSEO MCP endpoint format (HTTP vs stdio)
23. Configure MCP in Crush `mcpServers` if HTTP-based
24. Document MCP setup in AGENTS.md or docs/services/
25. Consider MCP authentication (is it behind protectedVHost or open on localhost?)

#### Monitoring & Alerting
26. Add Gatus check for OpenSEO MCP endpoint (if it exists)
27. Add response time threshold tuning (2s may be too generous for a vite preview)
28. Add a Gatus check for DataForSEO connectivity (indirect — check if OpenSEO can reach the API)
29. Consider adding OpenSEO to the Homepage "Monitoring" group alongside Gatus
30. Add log-based alerting for vite preview crashes (beyond systemd restart)

#### Documentation
31. Document the GSC setup steps in `docs/services/openseo-gsc-setup.md`
32. Document the AI/SAM (OpenRouter) setup steps
33. Add OpenSEO to `docs/DOMAIN_LANGUAGE.md` if SEO terms are used elsewhere
34. Update FEATURES.md with OpenSEO v0.1.1 feature inventory
35. Add OpenSEO to the "Consuming External Services" pattern documentation
36. Document the `AUTH_MODE=local_noauth` security model explicitly

#### Code Quality
37. Consider extracting `protectedVHost` path-exclusion support (generic, reusable for other OAuth callbacks)
38. Audit whether other Layer 2 services have similar OAuth callback gaps
39. Consider a pre-commit check for `protectedVHost` + OAuth callback path conflicts
40. Review whether `NODE_OPTIONS=--max-old-space-size=1536` is optimal for v0.1.x
41. Consider adding `ProtectSystem = "strict"` + `ReadWritePaths` for tighter sandboxing
42. Consider `PrivateUsers = true` compatibility (vite preview may need it disabled)

#### Future Features
43. Consider wiring OpenSEO rank tracking results into the Homepage dashboard widget
44. Consider OpenSEO + Hermes integration (AI agent consuming SEO data)
45. Consider exposing OpenSEO project defaults (country/language) via Nix options
46. Consider declarative OpenSEO project configuration (like qmd's `bootstrapCollections`)
47. Explore OpenSEO Skills integration (pre-built agent workflows)
48. Consider per-project DataForSEO budget limits (prevent runaway API costs)
49. Consider multi-user OpenSEO (if ever needed — currently single-user via noauth)
50. Monitor OpenSEO release cadence — fast-moving project (10+ releases in ~1 month)

### g) Questions (cannot determine without user input)

1. **Do you actually use or plan to use Google Search Console with OpenSEO?** The GSC OAuth callback behind `protectedVHost` is a real blocker — if you want GSC, I need to fix the Caddy vHost. If not, the GSC option can stay dormant and I'll just document the limitation.

2. **Do you want the OpenSEO MCP server wired into Crush?** OpenSEO's MCP exposes keyword research, backlinks, rank tracking etc. to AI agents. If you want this, I need to know whether you prefer HTTP MCP (always-on, like qmd) or stdio MCP (per-session).

3. **Do you have a DataForSEO API key already set up, or does the `dataforseo_api_key` sops secret contain a real key?** If the key is a placeholder, the v0.1.1 upgrade will show clear error messages (v0.1.x improved the "wrong API key" UX), but it's worth confirming the key is valid before deploying.

---

## Summary

The OpenSEO configuration is **functionally better** than before: latest version, telemetry opt-out, stale-process prevention, and declarative options for optional features. The v0.1.1 package builds and all flake checks pass.

> **CORRECTION (2026-07-23 16:20):** The original claim that "the GSC OAuth callback behind protectedVHost is a known gap that would bite if GSC is enabled" was **wrong**. The callback is browser-initiated and would pass forward-auth regardless. A defensive vHost exemption was applied anyway, the callback path was verified against source, and runtime validation was added. AGENTS.md was updated. The MCP integration was not started (still valid).
