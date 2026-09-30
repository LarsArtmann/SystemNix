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
   age recipient per `.sops.yaml`).
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
