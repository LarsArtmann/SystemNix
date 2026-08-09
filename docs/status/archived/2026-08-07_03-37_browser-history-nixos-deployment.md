# Status: browser-history NixOS Deployment — Upstream Build Infrastructure

**Date:** 2026-08-07 03:37
**Session goal:** Deploy `/home/lars/projects/browser-history` on NixOS via SystemNix
**Outcome:** UPSTREAM BUILD INFRASTRUCTURE ~80% DONE, SystemNix SIDE 0% DONE, BUILD NOT YET VERIFIED

---


## Executive Summary

The task was to deploy the browser-history server (a Go CQRS/ES multi-module monorepo) as a systemd service on the evo-x2 NixOS machine via SystemNix. The upstream `flake.nix` had NO real binary package — only a no-op `packages.default` that creates an empty directory. The entire session was spent adding `buildGoModule` infrastructure to the upstream flake so it can produce a deployable server binary. The SystemNix integration (service module, Caddy vHost, Gatus, configuration.nix) has NOT been started.

The upstream build is one `GOFLAGS=-mod=mod` edit away from potentially working, but this last edit has NOT been verified by a successful `nix build`. The vendorHash will likely need updating if the mod-phase go.sum changed.

---

## a) FULLY DONE

1. **Explored browser-history project structure** — understood the 7-module Go workspace (api, domain, extraction, projection, storage, cmd/server, cmd/agent), the `GOEXPERIMENT=jsonv2` requirement, templ generation, and the existing upstream agent NixOS module (`nix/agent-module.nix`)

2. **Studied SystemNix consumption patterns** — read Monitor365 (gold standard), DiscordSync (Go service reference), lib/ports.nix, lib/default.nix, flake.nix (mkLarsPackages + inputs), caddy.nix (protectedVHost/proxyTo), gatus-config.nix (mkHttpCheck/discordAlert), configuration.nix

3. **Identified all LarsArtmann dependencies** — mapped every `replace` directive in go.work to the corresponding local repo, checked which are private (only go-cqrs-lite), got pushed revs for all repos

4. **Added 10 flake inputs to browser-history/flake.nix** — go-nix-helpers, go-cqrs-lite (SSH), cqrs-htmx, go-error-family, go-branded-id, go-httputil, templ-components, go-sse, go-idempotency, go-retry

5. **Added mkPreparedSource + buildGoModule infrastructure** — including the multi-module workspace handling: root go.mod promotion from cmd/server, sibling module replace directives, cmd/server/go.mod removal to prevent nested module paths

---

## b) PARTIALLY DONE

1. **Upstream `packages.browser-history-server` build** — The buildGoModule derivation is written and gets through the prepared-source phase and go-modules FOD phase (vendor hash obtained: `sha256-2cZ6mtOdUux89Yb/r6iSfCqtRxPHnOQ/I8aYKhx2hm8=`). The FINAL build phase fails because templ-generated Go files introduce imports not in the vendored go.mod. Last edit added `GOFLAGS=-mod=mod` to allow auto-update during build, but this is UNVERIFIED.

2. **Vendor hash** — Currently `sha256-2cZ6mtOdUux89Yb/r6iSfCqtRxPHnOQ/I8aYKhx2hm8=` but may need updating if `GOFLAGS=-mod=mod` changes what the FOD phase downloads.

---

## c) NOT STARTED (SystemNix side — 0%)

1. **Flake input in SystemNix flake.nix** — `inputs.browser-history` not added
2. **Port in lib/ports.nix** — no `browser-history` port entry
3. **Service module** — `modules/nixos/services/browser-history.nix` not created
4. **Caddy vHost** — no `history.${domain}` reverse proxy
5. **Gatus health check** — no endpoint monitoring
6. **configuration.nix** — service not enabled
7. **Homepage tile** — not added
8. **Backup coordination** — not wired (SQLite DB at `/var/lib/browser-history/`)
9. **Sops secrets** — no secrets created (WebAuthn config, agent token)
10. **DNS local subdomain** — `history.home.lan` not added to dnsblockd

---

## d) TOTALLY FUCKED UP / MISTAKES MADE

1. **Used unpushed git revs** — I grabbed `git rev-parse HEAD` for go-cqrs-lite, httputil, and go-sse WITHOUT checking if those commits were pushed to the remote. go-cqrs-lite's local HEAD (3e3b6ee) was 5 commits ahead of origin/master. The first `nix build` failed with HTTP 404. **Fix:** found pushed revs via `git rev-parse origin/master`. Should have checked `git log origin/master..HEAD` BEFORE writing revs into the flake.

2. **Assumed all repos were public** — go-cqrs-lite is PRIVATE. Using `github:LarsArtmann/go-cqrs-lite` URL fails with 404 on the tarball fetch. **Fix:** changed to `git+ssh://git@github.com/LarsArtmann/go-cqrs-lite`. Should have run `gh repo view --json visibility` for every dep upfront.

3. **Used `lib.fakeSha256` instead of `lib.fakeHash`** — `buildGoModule`'s `vendorHash` expects SRI format (`sha256-AAA...=`), not raw hex (`000...`). `lib.fakeSha256` returns raw hex. **Fix:** `lib.fakeHash`. Wasted a build cycle.

4. **Missing root go.mod in fileset** — The `lib.fileset.unions` didn't include `./go.mod` and `./go.sum`, so mkPreparedSource's `postPatch` couldn't find `go.mod` to patch. **Fix:** added `./go.mod` and `./go.sum` to the fileset.

5. **Didn't remove cmd/server/go.mod** — After copying cmd/server/go.mod to root, the original cmd/server/go.mod still existed as a nested module. `buildGoModule` with `subPackages = ["cmd/server"]` then tried to build `cmd/server/cmd/server` (double-nested path). **Fix:** `rm -f cmd/server/go.mod cmd/server/go.sum` in postPatchExtra.

6. **templ + buildGoModule impedance mismatch** — `templ generate` creates new `.go` files with imports that aren't in the original go.mod/go.sum. With `proxyVendor = true`, the build phase can't download these missing deps (network blocked). With `proxyVendor = false` (vendoring), the FOD references store paths from patched local-dep shebangs (FOD purity violation). **Current attempt:** `GOFLAGS=-mod=mod` in the build phase to let Go auto-update go.mod against the proxy-vendored module cache — UNVERIFIED.

7. **Iterative trial-and-error instead of studying the DiscordSync pattern more carefully** — DiscordSync's flake uses `proxyVendor = true` with `go mod tidy` in BOTH `overrideModAttrs.preBuild` AND the main `preBuild`. I tried removing `go mod tidy` from the main build first, which failed. Should have copied the proven pattern verbatim from the start.

---

## e) WHAT WE SHOULD IMPROVE

1. **Check pushed status + visibility of every dep BEFORE writing flake inputs** — `git log origin/master..HEAD` and `gh repo view --json visibility` for each repo. This is now documented in the SystemNix AGENTS.md gotchas but wasn't followed.

2. **Start from the proven pattern (DiscordSync) verbatim** — The DiscordSync flake has solved all these problems already. Copy the mkPreparedSource + proxyVendor + go mod tidy pattern wholesale, then adapt for the multi-module workspace.

3. **The multi-module Go workspace pattern should be documented** — browser-history is the first LarsArtmann project with a Go workspace (7 modules). The "promote cmd/server/go.mod to root + add sibling replaces + delete original" strategy in `postPatchExtra` is novel and should be documented in the upstream AGENTS.md if it works.

4. **Don't split upstream and downstream work across a session boundary** — The upstream build should be FULLY WORKING (green `nix build`) before touching SystemNix. Half-finished upstream + zero downstream = maximum context loss between sessions.

5. **The `GOFLAGS=-mod=mod` approach may not work with proxyVendor** — proxyVendor creates a read-only module cache. `-mod=mod` tries to UPDATE go.mod, which may conflict. The real fix might be to run `go mod tidy` in the main `preBuild` as well (like DiscordSync does), accepting that it needs network during the build phase (proxyVendor provides it).

---

## f) NEXT 50 THINGS TO DO

### Upstream (browser-history repo)
1. Verify `GOFLAGS=-mod=mod` build works — run `nix build .#browser-history-server`
2. If it fails, add `go mod tidy` to the main `preBuild` (matching DiscordSync pattern exactly)
3. Update vendorHash if the FOD output changed
4. Verify the binary actually runs: `./result/bin/server --help` or similar
5. Check `meta.mainProgram` — is it `server` or `browser-history-server`?
6. Run `nix flake check --no-build` on the upstream flake
7. Commit and push the upstream changes (need `git push`)
8. Verify `nix build github:LarsArtmann/browser-history#browser-history-server` works from the pushed rev
9. Consider adding `packages.browser-history-agent` (cmd/agent) for multi-machine sync
10. Document the multi-module workspace build pattern in browser-history/AGENTS.md

### SystemNix flake.nix
11. Add `inputs.browser-history` to SystemNix flake.nix (`url = "github:LarsArtmann/browser-history?ref=master"` with nixpkgs.follows)
12. Run `nix flake lock --update-input browser-history` to populate flake.lock
13. Verify the input resolves: `nix flake show .#browser-history`

### SystemNix lib/ports.nix
14. Add `browser-history = <PORT>;` (suggest 8087 — 8086 is taken by file-and-image-renamer-health)

### SystemNix service module (modules/nixos/services/browser-history.nix)
15. Create the module file following the `{ inputs, ... }: { flake.nixosModules.browser-history = ...; }` pattern
16. Define `options.services.browser-history` with `enable`, `package`, `dataDir`, `port`, `domain` options
17. Set up systemd service with `harden {} // serviceDefaults {}`
18. Configure environment variables: `ADDR`, `DB_PATH`, `REQUIRE_AUTH=true`, `WEBAUTHN_RPID`, `WEBAUTHN_ORIGINS`, `COOKIE_SECURE=true`, `OTEL_EXPORTER_OTLP_ENDPOINT`
19. Set `startLimitBurst = 5; startLimitIntervalSec = 300;`
20. Wire `after = [ "sops-nix.service" "dnsblockd.service" ]` + `wants`
21. Add `onFailure` for Discord alert routing
22. Set `StateDirectory = "browser-history"` (creates `/var/lib/browser-history/`)
23. Add DNS-gate `ExecStartPre` (waitDnsReady pattern)
24. Consider SQLite WAL corruption self-heal ExecStartPre (like DiscordSync/Monitor365)
25. Set `MemoryMax` appropriately (Go service with SQLite — 1G should suffice)

### SystemNix Caddy
26. Add `history.${domain}` vHost in caddy.nix — decide: `protectedVHost` (Layer 2 forward-auth) or plain `reverse_proxy` (if browser-history gets native OIDC)
27. Browser-history has its OWN WebAuthn/Passkey auth — this is neither Layer 1 (Pocket ID native OIDC) nor Layer 2 (oauth2-proxy). It's a THIRD auth model. Need to decide whether to also gate behind `protectedVHost` or expose directly with TLS.
28. If using `protectedVHost`: WebAuthn origins need to include the external URL with HTTPS
29. If direct TLS proxy: use plain `reverse_proxy` with `${proxyTo}` and `${commonConfig}`

### SystemNix Gatus
30. Add health check: `mkHttpCheck` for `http://localhost:${PORT}/health`
31. Add `discordAlert "Browser History server down"`
32. Add `[RESPONSE_TIME] < 1000` condition

### SystemNix configuration.nix
33. Enable: `services.browser-history = { enable = true; };`
34. Wire WebAuthn RP ID to the real domain (not localhost)
35. Wire WebAuthn origins to `https://history.${domain}`
36. Consider backup-coordination for `/var/lib/browser-history/`

### SystemNix DNS
37. Add `history` to `dnsLocal.localSubdomains` in dnsblockd config

### SystemNix Homepage
38. Add Homepage tile for browser-history (if desired)

### SystemNix Sops
39. Create sops secret for `BROWSER_HISTORY_AGENT_TOKEN` (for multi-machine sync)
40. Create sops template or environment file for the service

### SystemNix OTel
41. Verify `OTEL_EXPORTER_OTLP_ENDPOINT = "localhost:${toString ports.signoz-otlp-http}"` works with browser-history's OTel instrumentation

### Testing & Verification
42. Run `nix flake check --no-build` on SystemNix
43. Run `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` (full eval)
44. Deploy: `nix run .#deploy`
45. Verify service starts: `systemctl status browser-history`
46. Verify health endpoint: `curl http://localhost:${PORT}/health`
47. Verify Caddy proxy: `curl https://history.${domain}/health`
48. Register a WebAuthn credential and test login
49. Run an extraction: `curl -X POST .../extract -d '{"browser":"chrome","limit":10}'`
50. Verify Gatus shows the service as healthy

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Auth architecture decision:** Browser-history has its OWN WebAuthn/Passkey auth system (completely independent of Pocket ID). Should we (a) expose it directly via TLS Caddy proxy and use browser-history's built-in auth, (b) gate it behind `protectedVHost` (oauth2-proxy/Pocket ID) for SSO consistency — creating a double-auth situation, or (c) try to replace browser-history's auth with Pocket ID native OIDC (requires upstream code changes)? This is a genuine architecture decision with tradeoffs I can't resolve without your preference.

2. **Agent deployment:** Do you want the browser-history AGENT deployed on evo-x2 as well (to extract local browser history from the NixOS machine), or is this server-only (agents run on macOS/other machines and push to this server)? The agent module exists upstream (`nix/agent-module.nix`) but the NixOS machine may not have browsers whose history you want to track.

3. **Port allocation:** I suggest 8087 for browser-history (8086 is taken by file-and-image-renamer-health, 8088+ is open). Is there a preferred port, or should I just use 8087?

---

## File-Level Summary of Changes Made

### `/home/lars/projects/browser-history/flake.nix` (auto-committed as cc98eca)
- **Added 10 flake inputs:** go-nix-helpers, go-cqrs-lite (SSH URL, private), cqrs-htmx, go-error-family, go-branded-id, go-httputil, templ-components, go-sse, go-idempotency, go-retry
- **Added to outputs function signature:** all 10 new inputs destructured
- **Added `mkPreparedSource` setup:** with deps map for all 9 LarsArtmann repos
- **Added `preparedServerSrc`:** with postPatchExtra that promotes cmd/server/go.mod to root, removes cmd/server/go.mod, adds sibling module replaces
- **Added `packages.browser-history-server`:** buildGoModule with proxyVendor=true, templ nativeBuildInput, go mod tidy in overrideModAttrs, GOFLAGS=-mod=mod in preBuild
- **Current vendorHash:** `sha256-2cZ6mtOdUux89Yb/r6iSfCqtRxPHnOQ/I8aYKhx2hm8=`

### `/home/lars/projects/SystemNix/` — NO CHANGES MADE

---

## Tech Stack Context

- **Go 1.26.5** with `GOEXPERIMENT=jsonv2` (non-negotiable — code imports `encoding/json/v2`)
- **Go workspace** (go.work) with 7 modules — buildGoModule can't handle workspaces directly, requires root go.mod promotion
- **a-h/templ** — generates Go code from `.templ` files, must run BEFORE `go build`
- **modernc.org/sqlite** — pure-Go SQLite (no CGO needed, `CGO_ENABLED=0` is fine)
- **WebAuthn/Passkeys** — browser-history has its own auth (not Pocket ID/OIDC)
- **OTel tracing** — `OTEL_EXPORTER_OTLP_ENDPOINT` env var for SigNoz

---

> **RESOLVED — Browser-history fully deployed (port 8087, history.home.lan). All SystemNix wiring done: module, port, DNS, Caddy, Gatus, Homepage, sops. Server healthy with 2,927 events. Remaining items harvested to TODO_LIST.md Priority 7.**
> All forward-looking items in this report were completed in subsequent sessions.
