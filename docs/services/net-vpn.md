# Net VPN (NetBird + larsartmann.cloud) — runbook

_Architecture: `docs/brainstorming/2026-09-30_netbird-larsartmann-cloud-selfhosted-vpn.md`.
Rollout plan: `docs/planning/2026-09-30_04-51_netbird-larsartmann-cloud-rollout.md`._

## What exists (Phase 1, deployed with this change)

- **Split-horizon alias zone**: dnsblockd (evo-x2 + rpi3 failover) resolves
  every `home.lan` service also as `<sub>.larsartmann.cloud` → 192.168.1.150.
  Never published in public DNS — public `larsartmann.cloud` carries only
  apex, `netbird.`, `relay.`, and the Resend records (domains repo).
- **Dual-zone TLS**: `dnsblockd-cert-mint.service` mints ONE leaf cert at
  every boot into `/run/dnsblockd-certs/` (SANs: `home.lan`, `*.home.lan`,
  `larsartmann.cloud`, `*.larsartmann.cloud`) from the sops'd dnsblockd CA.
  All Caddy vHosts serve it (same CA the clients already trust — home.lan
  behavior unchanged; the old static sops server cert stays declared as
  fallback material). Fail-closed: no mint, no Caddy start.
  RUNTIME-VERIFIED by `checks.caddy-mint` (VM test: the mint actually runs,
  caddy starts, SANs/CA-chain/key-pairing + real TLS handshakes on BOTH
  zones are asserted).
- **Caddy mirror**: every home.lan vHost is mirrored under the cloud domain
  with identical routing (auth redirects still target `auth.home.lan` by
  design — VPN clients resolve both zones). Cloud catch-all redirects to
  `dash.larsartmann.cloud`. oauth2-proxy whitelists `.${cloudDomain}`.
- **NetBird client** (`services.netbird-client`, modules/nixos/services/netbird.nix):
  GATED OFF (`enable = false`) until the Phase-2 setup key lands in
  `platforms/nixos/secrets/netbird.yaml` (key `netbird_setup_key`).
  Uses pinned-nixpkgs `services.netbird.clients.evox2` + automated
  setup-key login. Port 51820/udp (`ports.netbird`).

## Phase 2 handover (user-run, in order)

1. **Push secrets + deploy pbx** (pbx-artmann repo, `hosts/pbx/netbird.nix`):
   `~/.pbx-prod-secrets/push-secrets.sh` (now also pushes
   `netbird_mgmt_datastore_key`, `netbird_relay_auth_secret`), then
   `nixos-rebuild test --flake .#pbx --target-host root@pbx.artmann.tech`,
   verify units (`netbird-management netbird-signal netbird-relay dex nginx`),
   then `switch`. DNS records `netbird.`/`relay.` already live (applied
   2026-09-30); ACME issues on first start.
2. **First dashboard login**: https://netbird.larsartmann.cloud → Dex login
   (`lars@artmann.tech`; password in `~/.pbx-prod-secrets/netbird_dex_admin_password`
   — put it in the password manager, it is the ONLY copy).
3. **Create a setup key** (dashboard → Setup Keys → reusable, expires 30d).
4. **Land the key in sops** (this machine):
   `SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops platforms/nixos/secrets/netbird.yaml`
   — create the file with `netbird_setup_key: <key>` (encrypt to the evo-x2
   age recipient per `.sops.yaml`). Exact minimal file content:

   ```yaml
   netbird_setup_key: <paste-the-setup-key>
   ```

   (`.sops.yaml`'s creation rule for `platforms/nixos/secrets/*` already
   picks the right age recipients — no per-file keys stanza needed.)
5. **Enable the client**: set `services.netbird-client.enable = true` in the
   evo-x2 platform config, rebuild. Enrollment is automatic (login oneshot).
6. **Dashboard one-time network config** (runbook step in pbx docs):
   - Routes: approve evo-x2's advertised `192.168.1.0/24`
   - DNS: nameserver group forwarding `home.lan` + `larsartmann.cloud`
     → `192.168.1.53` (matched domains only)
   - ACLs: default single-user policy
7. **Enroll clients**: MacBook + Motorola (install NetBird app; import the
   dnsblockd CA into the phone's user store for `*.larsartmann.cloud` TLS).
8. **Burn-in**, then retire Tailscale on the MacBook (D6).

## Verification (post-deploy)

- `dig @127.0.0.1 dash.larsartmann.cloud` → 192.168.1.150 (evo-x2 + rpi3)
- `openssl s_client -connect 127.0.0.1:443 -servername dash.larsartmann.cloud`
  → SANs cover both zones; issuer = dnsblockd CA
- `curl --resolve dash.larsartmann.cloud:443:192.168.1.150 --cacert <CA>
  https://dash.larsartmann.cloud` → 200/redirect (LAN bypass)
- `systemctl status dnsblockd-cert-mint caddy` — mint Before/Requires caddy
- Eval regression: `nix build .#checks.x86_64-linux.cloud-domain` (asserts
  zones both hosts, vHost mirror, mint SANs, oauth2 whitelist, gated client,
  AND the positive module-surface probe)

## Gotchas

- **The mint unit needs `RuntimeDirectory` alongside `ReadWritePaths`** —
  systemd sets up the mount namespace BEFORE any script line runs; a
  `ReadWritePaths` target that no earlier unit creates kills the unit at
  NAMESPACE setup (`226/NAMESPACE`) and the fail-closed ordering then
  blocks caddy — ALL home.lan web services down at boot. `checks.caddy-mint`
  guards this exact failure. Script binaries are absolute store paths
  (`${pkgs.openssl.bin}/bin/openssl`) — never ambient PATH in a hardened
  oneshot.
- The mint unit re-mints at every boot (tmpfs `/run`, 365d validity) — cert
  identity changes each boot by design (random serial + key); clients trust
  the CA, not the leaf.
- `localRecords` has NO cloud wildcard entry — sdns ignores wildcard local
  records (gotchas-archive); explicit subdomain list only, same as home.lan.
- Native-OIDC apps (paperless/forgejo) still register `*.home.lan` redirect
  URIs in Pocket ID; cloud-originated logins hop via home.lan names (works
  over VPN; polish later only if it ever annoys).
- NetBird `ManagementUrl` lives in the client's `config` option (not
  `settings`) — the positive test probe guards this against module renames.

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### Net VPN: split-horizon larsartmann.cloud + NetBird (2026-09-30)

Architecture/decisions: `docs/brainstorming/2026-09-30_netbird-larsartmann-cloud-selfhosted-vpn.md`; phases + user gates: `docs/planning/2026-09-30_04-51_netbird-larsartmann-cloud-rollout.md`; runbook: `docs/services/net-vpn.md`. Facts an agent must know:

- `networking.local.cloudDomain` (default `larsartmann.cloud`) is the alias zone — dnsblockd serves it on evo-x2 AND rpi3 (`dns-blocker-config.nix` + `rpi3/default.nix`, records fold from the same `dns-local.nix` list; NO wildcard local record — sdns ignores them). NEVER publish cloud service names in public DNS (domains repo keeps only apex + `netbird.` + `relay.` + Resend).
- TLS: `dnsblockd-cert-mint.service` (in caddy.nix) mints ONE dual-zone cert from the sops'd dnsblockd CA into `/run/dnsblockd-certs/` at EVERY boot (random serial/key, 365d) — Caddy `tlsConfig` points there, After+Requires ordering (`systemd.services.caddy.requires` in caddy.nix — the literal fail-closed mechanism, aligned 2026-09-30), fail-closed. The old static sops server cert stays declared as fallback material. Client trust is unchanged (same CA). RUNTIME-VERIFIED by `checks.caddy-mint` (VM test: mint → caddy starts → SANs/CA/pairing/TLS-handshake on both zones; the mint unit also SELF-ASSERTS the four SANs before install — a broken extfile fails the mint, not the first handshake). **FIRST LIVE ACTIVATION DIED ANYWAY (2026-09-30 05:50, deployed rev `10602885`): 226/NAMESPACE — the deployed rev PREDATED the RuntimeDirectory fix (landed `d22ccd48` 06:11; the shared-tree deploy lagged its verification session's commit by 20 min)**. caddy fail-closed (by design), browser-history-agent + oauth2-proxy cascade-failed (the agent's readiness gate accepts any ANSWERED status — connection-refused to a down caddy is the expected transient; the 5-min timer converges it once caddy is up), exit-4 left the profile unanchored (reboot-revertible until re-deploy — run the anchor check from the deploy-generation gotcha first). Deploy-vs-fix-commit race rule: before the FIRST live deploy of a unit a same-morning session just fixed, confirm the deployed rev CONTAINS the fix commit (`git merge-base --is-ancestor <fix> <deployed-rev>`) — "verified in the tree" ≠ "verified in the rev you deployed". Two eval-invisible gotchas pinned there: (a) `ReadWritePaths` needs `RuntimeDirectory` — systemd sets up the mount namespace BEFORE any script runs, and a ReadWritePaths target that nothing creates kills the unit at NAMESPACE setup (`226/NAMESPACE`), fail-closing the whole web stack at boot; (b) script binaries must be absolute store paths (`${pkgs.openssl.bin}/bin/openssl` etc.) — ambient PATH is generation-dependent.
- Caddy vHosts are mirrored 1:1 under the cloud domain via `mirrorCloud` in caddy.nix (filter + replaceStrings on keys) — do NOT hand-write cloud vHosts; new vHosts under home.lan mirror automatically. Auth redirects deliberately stay on `auth.home.lan` (VPN resolves both zones; oauth2-proxy whitelists the cloud domain for the post-login redirect only).
- NetBird client module: `services.netbird-client` (wrapper) → `services.netbird.clients.evox2` (pinned-nixpkgs surface; the JSON fragment option is `config`, NOT `settings` — `checks.cloud-domain` has a positive extendModules probe guarding renames). GATED OFF until the Phase-2 setup key exists in sops (`platforms/nixos/secrets/netbird.yaml`, key `netbird_setup_key`); enabling without the file fails activation BY DESIGN.
- Control plane lives on the pbx server (pbx-artmann repo `hosts/pbx/netbird.nix`): NetBird server + relay(STUN 3479) + Dex (dashboard logins only). Deploy is owner-run (pbx AGENTS policy); handover: pbx `docs/runbooks/netbird-deploy.md`.

**Gate-timeout floors are EVAL-ENFORCED (`gate-timeout-audit.nix`)** — any unit whose ExecStartPre contains a `-wait-oidc` script MUST set `TimeoutStartSec ≥ 6min` (gate budget 300s), any `-wait-dns` unit ≥ 4min (budget 180s), or `nix flake check` fails naming the unit. Both gate helpers return `TimeoutStartSec = mkDefault <floor>` in their serviceConfig fragment, so consumers merging the whole fragment are covered automatically; consumers that cherry-pick only `ExecStartPre` (searxng, forgejo, discordsync's hand-rolled clone) must set it explicitly. Hand-rolled gate CLONES that follow the `<service>-wait-dns` naming convention are caught by the same audit (discordsync is). Negative test pattern: `extendModules` + `mkForce "2min"` on a gate unit → assertion message must appear in `config.assertions`.

