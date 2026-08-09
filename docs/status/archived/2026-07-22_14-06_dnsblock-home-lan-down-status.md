# Status Report: `dnsblock.home.lan` Outage & Fix

**Date:** 2026-07-22 14:06 CEST  
**Session focus:** Why `dnsblock.home.lan` was down and fixing the Caddy/DNS routing gap.  
**Reporter:** Crush (autonomous session)  
**Branch:** `master` (working tree clean before edits)

> **Update 2026-07-24:** Deployed. `dnsblock.home.lan` resolves (verified via `getent hosts` → `192.168.1.150`) and serves the dashboard behind Caddy. The canonical subdomain decision from the follow-up report (`2026-07-22_14-50`) shipped: `dnsblock.home.lan` is the `protectedVHost`, `dnsblockd.home.lan` 301-redirects to it. Post-deploy smoke test checks `https://dnsblock.$DOMAIN/health`. See AGENTS.md "dnsblockd wildcard `*.home.lan` does not resolve" for the local-subdomain requirement.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## a) FULLY DONE

1. **Root-cause diagnosis** — Caddy had no virtual host for `dnsblock.home.lan` or `dnsblockd.home.lan`. The wildcard `*.home.lan` DNS record resolves both to the server IP, and Caddy’s catch-all `https://*.home.lan` vhost (added in `123a27f5`) redirects every unknown subdomain to `dash.home.lan`. The dnsblockd dashboard actually runs on `localhost:9090`, not behind a Caddy subdomain.
2. **Service chain mapping** — traced the full chain: dnsblockd binary (`dnsblockd serve`) → block-page HTTP server on `192.168.1.200:80/443` + stats/dashboard server on `127.0.0.1:9090` → Caddy TLS termination → wildcard DNS → Homepage tile.
3. **Upstream source inspection** — pulled the locked dnsblockd source (`github:LarsArtmann/dnsblockd/0d875de68bf792a71b00d4ec01e6637beca1c257`) and confirmed endpoints:
   - `blockRouter`: `GET /`, `POST /api/allow`, `POST /api/report`, `POST /api/csp-report` (no `/health`).
   - `statsRouter`: `GET /health`, `GET /dashboard`, `GET /api/dashboard-data`, `GET /stats`, `/metrics`.
4. **Baseline verification** — ran `nix flake check --no-build` before any edits; passed.
5. **Caddy fix** — added in `modules/nixos/services/caddy.nix:170`:
   - `dnsblockd.home.lan` as a `protectedVHost` reverse-proxying to `localhost:9090` (LAN direct, external via Pocket ID forward-auth).
   - `dnsblock.home.lan` as a permanent redirect to `dnsblockd.home.lan`.
6. **Post-deploy smoke test** — added `scripts/post-deploy-check.sh:93` to verify `https://dnsblockd.home.lan/health` returns HTTP 200.
7. **Re-verification** — `nix flake check --no-build` passes after edits.
8. **Config validation** — `nix eval` confirms both `dnsblock.home.lan` and `dnsblockd.home.lan` are present in `services.caddy.virtualHosts`, with the expected `reverse_proxy localhost:9090` and redirect directives.
9. **Script syntax check** — `bash -n scripts/post-deploy-check.sh` passed.

---

## b) PARTIALLY DONE

1. **The fix is in the repo but not deployed.** The Caddy config is correct in the Nix store derivation, but `nix run .#deploy` has not been run yet, so the live system still serves the redirect.
2. **Live smoke test not executed.** The new `post-deploy-check.sh` line is written but cannot be exercised until the deploy completes.
3. **Dashboard auth not configured.** The dnsblockd dashboard currently has no `auth_token`/`auth_token_file` set; it relies solely on Caddy forward-auth for external access.

---

## c) NOT STARTED

1. Deploy the change to evo-x2 (`nix run .#deploy`).
2. Live validation of `https://dnsblockd.home.lan/health` and `/dashboard`.
3. Decision on dashboard auth (`auth_token_file` via sops).
4. Cleanup of the redundant `dnsblockd` infraServices tile in `homepage.nix`.
5. Gatus domain-level checks for `dnsblockd.home.lan` and `dnsblock.home.lan`.
6. Documentation update in AGENTS.md/DOMAIN_LANGUAGE.md for the block-page vs dashboard architecture.
7. Audit of all other homepage tiles for missing Caddy vhosts.
8. Audit of all Caddy vhosts for missing post-deploy checks.

---

## d) TOTALLY FUCKED UP!

1. **The `DNS Blocker` homepage tile was silently broken.** It linked to `https://dnsblockd.home.lan`, but Caddy had no route for that subdomain. Instead of a clear 404, users were redirected to the dashboard (`dash.home.lan`), making the failure invisible.
2. **The `dnsblockd` infraServices tile is a zombie.** It has `statusStyle = "dot"` but no `siteMonitor`, so the dot has no data and conveys no real status.
3. **Dashboard has no service-level auth.** The dnsblockd dashboard can flush cache, manage temp-allowlists, and review false-positives. With no `auth_token` configured, it is only protected by Caddy’s forward-auth for external access. LAN access or any Caddy misconfiguration leaves it wide open.
4. **The gap existed because the Caddy catch-all masked it.** Adding a homepage tile without a matching Caddy vhost is a recurring anti-pattern in this repo; the wildcard catch-all makes it look like it works.
5. **No post-deploy check existed for the domain.** The `dnsblockd` service health was checked via `localhost:9090/health`, but the user-facing URL was never tested.

---

## e) WHAT WE SHOULD IMPROVE!

1. **Every new homepage tile must ship with a matching Caddy vhost.** The wildcard catch-all should be treated as a safety net, not a substitute for explicit routing.
2. **Every tile with `statusStyle = "dot"` must have a `siteMonitor`.** A dot without a monitor is visual noise.
3. **Services with admin dashboards should have defense-in-depth auth.** Caddy forward-auth is not enough for dnsblockd; add `auth_token_file` via sops.
4. **Post-deploy checks should cover user-facing domains, not just localhost ports.** This is the second time a service looked healthy on localhost but its public URL was broken.
5. **Add a flake-level or pre-commit check that detects `svcUrl` entries without matching Caddy vhosts.** This would prevent regressions.
6. **Document the split between the block-page HTTP server (block IP) and the dashboard (stats port).** This distinction is non-obvious and caused the routing error.
7. **Stop adding redirects-as-a-service.** Either make `dnsblock.home.lan` canonical or drop it; having both is a debt if the user doesn’t actually want the shorter alias.

---

## f) Up to 50 Things We Should Get Done Next

1. Deploy the new Caddy vhosts to evo-x2.
2. Run live `post-deploy-check` and confirm `dnsblockd.home.lan/health` returns 200.
3. Verify `dnsblock.home.lan` performs a 301 redirect to `dnsblockd.home.lan`.
4. Verify the dashboard loads at `https://dnsblockd.home.lan/dashboard`.
5. Add `auth_token_file` for dnsblockd and wire it through sops.
6. Expose `auth_token_file` (or `auth_token`) in the `dns-blocker` SystemNix wrapper module.
7. Remove or consolidate the redundant `dnsblockd` infraServices tile in `homepage.nix`.
8. Add `siteMonitor` to the remaining dnsblockd tile if kept.
9. Add a Gatus HTTP check for `https://dnsblockd.home.lan/health`.
10. Add a Gatus check for the `dnsblock.home.lan` redirect.
11. Update AGENTS.md with the new dnsblockd vhost and auth note.
12. Update the monitoring runbook with dnsblockd dashboard troubleshooting steps.
13. Add `dnsblock` and `dnsblockd` to `dns-local.nix` explicit subdomain list for clarity.
14. Audit every `svcUrl` usage in `homepage.nix` for a matching Caddy vhost.
15. Audit every Caddy vhost for a matching `siteMonitor` in `homepage.nix`.
16. Audit every `protectedVHost` service for service-level auth where admin functions exist.
17. Add a pre-commit or flake check that parses Caddy virtualHosts and homepage services.yaml for mismatches.
18. Add a Caddy config syntax validation step (`caddy validate` or equivalent) to the flake checks.
19. Document the block-page vs dashboard architecture in `docs/DOMAIN_LANGUAGE.md`.
20. Verify dashboard static assets (CSS/JS) load correctly through Caddy.
21. Test external access to the dashboard through Pocket ID forward-auth.
22. Test LAN access bypasses forward-auth correctly.
23. Verify the dashboard’s CSRF/token auth still works behind Caddy reverse proxy.
24. Add a Prometheus scrape target for `localhost:9090/metrics` (or through Caddy).
25. Create a Grafana dashboard for dnsblockd stats.
26. Add a Gatus alert if `dnsblockd.home.lan` returns non-200.
27. Add a check that the block IP (`192.168.1.200`) is attached to `eno1` at runtime.
28. Verify the dnsblockd CA cert is not near expiry.
29. Add a check that `dnsblockd.home.lan` DNS resolves to the server IP.
30. Add a test that the Caddy catch-all does not intercept known service subdomains.
31. Update the post-deploy-check script to parse health response bodies for an `"ok"` or `status` field where applicable.
32. Add a runbook entry: “If `dnsblockd.home.lan` redirects to the dashboard, the Caddy vhost is missing.”
33. Consider whether the block-page HTTP server should also be proxied by Caddy (e.g., under a separate path or subdomain).
34. Evaluate whether `dnsblock.home.lan` should serve the block page and `dnsblockd.home.lan` the dashboard, or vice versa.
35. Add a system-health metric for dnsblockd process state.
36. Add a Gatus check that DNS blocking still returns the block IP for `ads.google.com`.
37. Backfill a brief note in the changelog for the missing vhost fix.
38. Schedule a quarterly audit of Caddy vhosts vs homepage tiles vs DNS records.
39. Add a `caddy validate` wrapper to the devShell for quick config checks.
40. Ensure the Darwin CA trust for `dnsblockd-CA` (already in TODO_LIST.md) is tracked and completed.
41. Verify homepage-dashboard icon pack includes the `blocky.png` and `adguard-home.png` icons used for dnsblockd tiles.
42. Add a flake check that ensures no two Caddy vhosts share the same hostname.
43. Add a flake check that every `protectedVHost` backend port is declared in `lib/ports.nix`.
44. Review the `dnsblockd` systemd hardening for any restriction that breaks Caddy proxying.
45. Confirm the `dnsblockd` service still needs `CAP_NET_BIND_SERVICE` after the Caddy proxy change (it binds 53/80/443, so yes, but review).
46. Add a dashboard shortcut to the DMS Quickshell menu if desired.
47. Add a note in the README/service table that the dashboard is at `dnsblockd.home.lan`.
48. Add a check that the post-deploy smoke test fails if the Caddy vhost is missing.
49. Consider renaming the `DNS Blocker` tile to `DNS Blocker Dashboard` to clarify it links to stats.
50. Add a linter rule that forbids `mkService` with `statusStyle = "dot"` and no `siteMonitor`.

---

## g) Questions I Cannot Answer Myself

1. **Canonical subdomain:** Should `dnsblock.home.lan` be the canonical URL and `dnsblockd.home.lan` the redirect, or should `dnsblockd.home.lan` remain canonical? I kept `dnsblockd` canonical because the existing Homepage tile uses it, but you asked about `dnsblock.home.lan`.
2. **Dashboard auth depth:** Should we add a dedicated `auth_token_file` for the dnsblockd dashboard via sops, or is Caddy’s Pocket ID forward-auth sufficient for now? The dashboard currently has no service-level auth.
3. **Block-page exposure:** Should the block-page HTTP server on `192.168.1.200:80` also be exposed through Caddy (e.g., under a separate path or subdomain), or is the dashboard on `dnsblockd.home.lan` sufficient?

---

## Files Changed

- `modules/nixos/services/caddy.nix` — added `dnsblockd.home.lan` vhost and `dnsblock.home.lan` redirect.
- `scripts/post-deploy-check.sh` — added smoke test for `https://dnsblockd.home.lan/health`.

## Verification Artifacts

- `nix flake check --no-build` — passed before and after edits.
- `nix eval .#nixosConfigurations.evo-x2.config.services.caddy.virtualHosts` — confirmed `dnsblock.home.lan` and `dnsblockd.home.lan` are present.
- `bash -n scripts/post-deploy-check.sh` — syntax OK.

## Next Action Required

Run `nix run .#deploy` on evo-x2 to apply the Caddy vhost change, then validate the live URLs.

---

## Resolution Update (2026-07-22, same session)

**User decision:** Make `dnsblock.home.lan` the canonical subdomain (not `dnsblockd.home.lan`).

### Changes applied

- **`modules/nixos/services/caddy.nix:170`** — swapped roles:
  - `dnsblock.home.lan` is now the `protectedVHost` reverse-proxying to `localhost:9090`.
  - `dnsblockd.home.lan` is now the 301 redirect to `dnsblock.home.lan`.
- **`modules/nixos/services/homepage.nix:206,210`** — updated the `DNS Blocker` tile:
  - `href = svcUrl "dnsblock"`.
  - `siteMonitor = "${svcUrl "dnsblock"}/health"`.
- **`scripts/post-deploy-check.sh:93`** — health check now targets `https://dnsblock.$DOMAIN/health`.

### Verification

- `nix flake check --no-build` passes.
- `nix eval` confirms `dnsblock.home.lan` contains `reverse_proxy localhost:9090`, and `dnsblockd.home.lan` contains `redir * https://dnsblock.home.lan{uri} permanent`.
- `bash -n scripts/post-deploy-check.sh` passes.

### What was not done

- The `dnsblockd` infraServices tile in `homepage.nix:166` still has no `href`/`siteMonitor` — left intact because it carries a different visual role ("DNS Resolver + Blocker").
- `dns-blocker.nix` still doesn't expose `auth_token_file`; no service-level dashboard auth added.
- No deploy performed.

### Open questions still pending

- Should we add `auth_token_file` for dnsblockd dashboard auth via sops?
- Should the block-page HTTP server on `192.168.1.200:80` also be exposed through Caddy?

(Question 1 from the original report — "canonical subdomain" — is now resolved.)


---

## Item Resolution (2026-07-30)

dnsblock.home.lan outage. DONE: Caddy vHost added, deployed, dnsblock.home.lan serving. Subdomain canonicalized in follow-up (14-50). All items resolved.
