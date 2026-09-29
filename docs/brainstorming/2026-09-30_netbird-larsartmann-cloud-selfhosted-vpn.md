# NetBird + larsartmann.cloud: Self-Hosted Remote Access Architecture

_Status: PLAN — agreed 2026-09-30. Nothing implemented yet; this document is the
source of truth for the upcoming phases._

_Goal: reach all self-hosted services from anywhere, for Lars only, fully
self-hosted on own hardware — no third-party services at any layer._

---

## 1. Constraints (owner-fixed)

| #  | Constraint                                                                                                                                   | Consequence                                                                        |
| -- | -------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| C1 | **No third-party services.** No NetBird managed cloud, no Tailscale, no Headscale-at-CF, no Cloudflare Tunnel/Access, no NetBird-managed SSO | NetBird control plane must be self-hosted on a public box; IdP must be self-hosted |
| C2 | **Minimal VPS count.** No new VPS if an existing one can serve                                                                               | Control plane goes on the pbx-artmann server                                       |
| C3 | **Auth must work when the VPS is down AND when evo-x2 is down**                                                                              | Drives the IdP placement analysis (§5)                                             |
| C4 | **E-mail + telephony on the VPS, backups on the home HDD pool** (evo-x2 ZFS)                                                                 | Matches existing pbx backup-pull pattern; extends to nix-email                     |
| C5 | **Everything else stays on evo-x2**                                                                                                          | Home stays the service host; no service migration in scope                         |
| C6 | Home network stays **completely dark**: no port-forwards, no dynamic DNS, no public records pointing at the residential IP                   | Ingress exists only on the VPS                                                     |
| C7 | `larsartmann.cloud` replaces `home.lan` as the user-facing namespace going forward (unused domain, owner-provided)                           | Split-horizon design (§6)                                                          |

## 2. Current state (verified 2026-09-30)

- **evo-x2** (home server + workstation, 192.168.1.150): runs ALL services
  behind Caddy `*.home.lan` (~34 explicit subdomains in
  `platforms/common/dns-local.nix`; wildcard does NOT resolve — dnsblockd
  limitation), oauth2-proxy + Pocket ID SSO (`auth.home.lan`), dnsblockd DNS
  (127.0.0.1:53 + DoQ 853) with rpi3 VRRP failover (VIP 192.168.1.53),
  internal dnsblockd CA with sops'd certs (`dnsblockd-certs.yaml`:
  ca_cert/ca_key/server_cert/server_key), firewall LAN-trust only. No VPN
  anywhere (no wireguard/netbird/tailscale in any of the three repos).
- **pbx-artmann** (Hetzner Cloud, Helsinki): public — nginx TLS 443/5061,
  FreeSWITCH 5060, Telnyx trunk 5080, TURN/STUN 3478, SSH 22. Domain
  `pbx.artmann.tech` (Namecheap-managed via the domains repo). evo-x2 pulls
  backups every 6h (pattern to reuse for mail).
- **nix-email** (planned, not deployed): own Hetzner VPS intended; public MX
  25/465/587/993; Stalwart admin loopback-only (currently planned via SSH
  tunnel — this plan replaces that with VPN access). Blocked on Hetzner
  port-25 unblock (1 month + paid invoice gate — start the clock early).
- **domains repo** (`~/projects/domains`): Terraform + Namecheap
  (`namecheap_domain_records`). `larsartmann.cloud` today: apex + wildcard A
  → 37.27.217.205 (private-cloud hetzner-0) + Resend DKIM/SPF for
  transactional sending (keep!). IPv6 2a01:4f9:c012:e010::1.
- **NetBird facts** (verified against docs 2026-09-30): self-host needs
  management + signal + relay + dashboard + IdP (quickstart embeds Dex;
  NixOS `services.netbird.server` module exists and REQUIRES an external
  IdP); v0.29+ consolidates relay over TCP 443 (coturn/3478 legacy-optional);
  peers enroll via setup keys (no browser/IdP at enrollment); MagicDNS
  domain configurable via `--dns-domain` on self-hosted. Free managed tier
  (5 users/100 machines) exists but is EXCLUDED by C1.
- **Dex**: CNCF OIDC connector/federation service; static-users file mode
  (bcrypt YAML) makes it a minimal standalone IdP; nixpkgs has
  `services.dex`. Not a full IdP (no MFA/passkeys on static connector).
- **Phones**: Pixel 6 retired; new Motorola accepts user-CA import →
  dnsblockd-CA trust is viable on all client devices.

## 3. Options considered (why NetBird self-hosted won)

| Option                         | Verdict                                                                                                                             |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| NetBird managed free           | Rejected — C1                                                                                                                       |
| Headscale + Tailscale clients  | Rejected — control-plane software is fine but needs a host anyway; NetBird's NixOS server module + OIDC/ACL model fits better       |
| Tailscale managed              | Rejected — C1                                                                                                                       |
| Plain WireGuard hub on VPS     | Rejected — hub decrypts spoke-to-spoke traffic; no on-demand client UX, no pushed DNS, no ACLs; rebuilds NetBird's features by hand |
| Cloudflare Tunnel/Access       | Rejected — C1, and CF sees all traffic                                                                                              |
| SSH bastion + port-forwards    | Kept only as admin fallback; no phone/DNS story                                                                                     |
| Control plane on evo-x2 (home) | Dead end — peers outside can't reach management through the NAT the tunnel hasn't crossed                                           |

Domain layer: **split-horizon private** chosen over MagicDNS-only, public+SSO
wall, and public-reverse-proxy designs — no public A records for service
names, names resolve only via dnsblockd (LAN) or NetBird matched-domain
forwarding (VPN).

## 4. Target architecture

```
                    pbx-artmann server (Hetzner, Helsinki) — "the VPS"
                    ├─ FreeSWITCH/telephony (unchanged, public — SIP/RTP
                    │    never goes over the VPN; Telnyx trunk stays public)
                    ├─ NetBird control plane: management + signal + relay + dashboard
                    │    netbird.larsartmann.cloud  (LE HTTP-01 via existing nginx)
                    ├─ Dex-static sidecar (NetBird dashboard logins ONLY)
                    └─ [Phase 3] nix-email (Stalwart) — public MX,
                         admin UI via VPN instead of SSH tunnels

evo-x2 (home — stays dark, zero inbound ever)
├─ NetBird client → WireGuard P2P to phone/MacBook (VPS relays only on NAT failure)
├─ advertises network route 192.168.1.0/24 (whole LAN reachable via VPN)
├─ Caddy serves <sub>.larsartmann.cloud aliases on existing vhosts
│    cert: minted from existing dnsblockd CA (same sops pattern as home.lan)
├─ dnsblockd serves larsartmann.cloud zone (records → 192.168.1.150,
│    same subdomain list as home.lan — single source: dns-local.nix)
├─ Pocket ID STAYS here (auth.larsartmann.cloud resolves via VPN → LAN IP)
│    — services SSO keeps working with VPS down
└─ rpi3-dns keeps VRRP DNS failover (192.168.1.53)

Clients: MacBook (retire Tailscale after burn-in), Motorola phone (user CA),
evo-x2 itself. Peers enroll with setup keys.
```

Naming/TLS rules:

- **VPS names** (`netbird.`, `auth.`—only if ever needed) get normal Let's
  Encrypt HTTP-01 through the pbx nginx. No DNS-01, no Namecheap API, no
  IP-whitelist footgun.
- **Home-side wildcard** `*.larsartmann.cloud` is minted from the dnsblockd
  CA → zero new cert machinery; devices already trust (or can import) the CA.
  Documented upgrade path: public LE wildcard via DNS-01 IF a future device
  cannot take the CA (would need Namecheap API IP-whitelist workaround or
  zone migration to Hetzner DNS — deferred, not needed for v1).
- **DNS resolution**: ONE source of truth — dnsblockd on evo-x2. LAN clients
  query it directly; VPN clients get `home.lan` + `larsartmann.cloud`
  queries forwarded (NetBird matched-domain nameserver group) through the
  advertised route to 192.168.1.53. No records authored in NetBird.
  Non-matched domains resolve via each client's normal resolver.
- **Public DNS** (domains repo): trim to apex + `netbird.` + Resend records.
  Remove the wildcard A → 37.27.217.205 (namespace stops leaking; nothing
  must resolve publicly).

## 5. IdP placement (the C3 analysis)

Key fact: **NetBird peers authenticate with setup keys; the IdP is only
touched by human dashboard logins** (create keys, approve routes, ACLs).
The VPN itself never dials the IdP at runtime.

|                                                                                                                                         | evo-x2 down                                                                       | VPS down                                                                                       | Cost                                                                               |
| --------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **A. Split by availability domain (CHOSEN)** — Pocket ID stays on evo-x2 for services SSO; Dex-static on VPS only for NetBird dashboard | Pocket ID down but every service it guards is down too; VPN still up (setup keys) | No new VPN enrollments/dashboard until back; existing tunnels persist; services SSO unaffected | One extra password, used a few times a year                                        |
| B. Pocket ID moves to VPS                                                                                                               | Services SSO dead while services still run — worst case                           | Everything auth dead                                                                           | Single credential                                                                  |
| C. HA Pocket ID (Litestream standby + failover)                                                                                         | Failover dance                                                                    | Failover dance                                                                                 | High complexity; NetBird IdP URL + oauth2-proxy endpoints must flip; slow recovery |

A satisfies C3 by aligning each credential's failure domain with exactly what
it guards. Earlier "split brain" objection applied to two sources for the
SAME consumers — these consumer sets are disjoint (VPN dashboard vs services
SSO), so it is not a split brain.

**Auth/DNS "sync" doctrine**: no runtime sync anywhere. DNS "sync" =
deployment (both resolver views render from the same Nix config). Auth has
no sync by design (single Pocket ID instance; no dual-active ever).

**Bootstrap chain (no loops)**: VPN login does not need Pocket ID →
`auth.larsartmann.cloud` may live behind the VPN. Services SSO from outside
needs the VPN → acceptable, since using the services needs the VPN anyway.

## 6. Decisions (all owner-ratified 2026-09-30)

| ID | Decision                                                                                  |
| -- | ----------------------------------------------------------------------------------------- |
| D1 | Option A: Pocket ID stays on evo-x2; Dex-static sidecar on VPS for NetBird dashboard only |
| D2 | pbx-artmann server hosts NetBird control plane + Dex (accepted risks §7)                  |
| D3 | dnsblockd CA wildcard for `*.larsartmann.cloud` on evo-x2 Caddy; LE HTTP-01 for VPS names |
| D4 | Trim public `larsartmann.cloud` DNS to apex + `netbird.` + Resend records                 |
| D5 | No NetBird-hosted DNS records; matched-domain forwarding → dnsblockd (192.168.1.53)       |
| D6 | Retire MacBook Tailscale after NetBird burn-in                                            |
| D7 | Motorola phone imports dnsblockd CA (user store)                                          |
| D8 | Telephony stays public; SIP/RTP never over VPN                                            |
| D9 | NetBird on pbx box is admin-optional, skip for v1                                         |

## 7. Accepted risks / trade-offs (owner-accepted)

1. **Blast radius on the pbx box**: it is the most-scanned host (SIP scanners
   on 5060/5080 daily). A FreeSWITCH/nginx compromise now reaches the VPN
   control plane → attacker could approve their own peer. Mitigations: strong
   Dex password (password manager), setup-key rotation, tight firewall on the
   NetBird vhost paths, keep 5080 ACL work un-deferred.
2. **Single-VPS consolidation**: mail + telephony + VPN control plane on one
   IP couples mail deliverability to SIP-scanner reputation and couples all
   three lifecycles (a pbx rebuild takes mail + VPN dashboard down). Port-25
   unblock must be granted for THAT IP. Keep a future split option open in
   the nix-email design (module-level, not architecture-level).
3. **Internal CA on clients**: browsers respect user stores; some apps never
   will. Upgrade path documented in §4.
4. **evo-x2 remains a workstation-server hybrid**: its reboots take
   services + VPN-side DNS down together. Long-term fix = separate
   workstation from server — explicitly out of scope, noted here.

## 8. Phases (each gated; nothing runs ahead of its gate)

### Phase 1 — Home side (SystemNix) — IdP-independent

1. dnsblockd: serve `larsartmann.cloud` zone — records for the dns-local.nix
   subdomain list → 192.168.1.150 (LAN + VPN-forwarded resolution both work).
2. Caddy: serve `<sub>.larsartmann.cloud` aliases on existing vhosts +
   catch-all; dnsblockd CA mints the wildcard server cert (extend
   `dnsblockd-certs.yaml` sops file; same owner= pattern for caddy).
3. NetBird client on evo-x2: `services.netbird.tunnels` (verify exact option
   surface in the pinned nixpkgs), management URL
   `https://netbird.larsartmann.cloud`, sops-gated setup key — service stays
   disabled/stopped until Phase 2 provides the key.
4. Firewall: trust the NetBird interface like `eno1`; zero new open ports.
5. Eval tests per repo patterns (zone rendering, vhost aliases, firewall
   trust, ports.nix entries); BuildFlow; dry-activate → switch.

Standalone win: `*.larsartmann.cloud` works on LAN with CA-trusted TLS
immediately, before any VPN exists.

### Phase 2 — VPS side (pbx-artmann + domains repos)

1. domains repo: trim wildcard (D4), add explicit `netbird.larsartmann.cloud`
   A/AAAA → pbx server IPs (LE HTTP-01 needs 80 reachable).
2. pbx-artmann: `services.netbird.server` (management/signal/dashboard;
   relay rides 443; coturn OFF unless legacy clients prove needed) fronted
   by the EXISTING nginx as a new server block (do not fight its TLS setup);
   Dex-static sidecar (`services.dex`, static user, bcrypt in sops); LE
   cert for the name via the pbx ACME pattern.
3. NetBird configuration (dashboard, one-time): ACLs (single user),
   setup keys, approve evo-x2's 192.168.1.0/24 route, nameserver group
   forwarding `home.lan` + `larsartmann.cloud` → 192.168.1.53.
4. Enrollment: evo-x2 (flip the Phase-1 gate), MacBook, Motorola. Burn-in,
   then retire Tailscale (D6).
5. Post-deploy checks + Gatus coverage for the new endpoints; pbx backup
   job extended to cover NetBird/Dex state dirs.

### Phase 3 — Mail (nix-email repo + VPS)

1. Deploy per its own README plan (public MX ports; Hetzner port-25 unblock
   request FIRST — 1-month gate).
2. Stalwart admin/JMAP reached via VPN (replaces the SSH-tunnel plan).
3. Backup pull to evo-x2 HDD pool — clone the pbx-artmann pattern.
4. Optional: NetBird peer on the mail box only if admin access needs it.

### Verification strategy (all phases)

Eval-time assertions in SystemNix (zone, vhosts, firewall, ports registry)
→ BuildFlow (`buildflow`, fast mode for iteration, full before deploy) →
`nixos-rebuild dry-activate` → switch → post-deploy smoke (dig, curl --cacert,
netbird status) → Gatus checks (VPN-side DNS forwarding, netbird management
reachability). pbx-artmann has its own test/docs-freshness gates.

## 9. Facts to verify at implementation time (not blocking the plan)

- Exact `services.netbird.tunnels` / `services.netbird.server` option surface
  in the pinned nixpkgs revision (client port, environmentFile, server
  dnsDomain/IdP settings, coturn toggle).
- NetBird peer sessions surviving IdP outages (expected: yes — setup-key
  model; confirm in code/docs during Phase 2 testing).
- Relay-over-443 with no coturn for current client versions (expected: yes,
  v0.29+; keep coturn config ready as fallback).
- dnsblockd CA minting workflow for a second zone (where the CSR/mint
  happens — dnsblockd repo tooling; the existing certs were minted
  somewhere — reproduce that path for the wildcard).
- pbx nginx: gRPC/websocket proxying requirements for signal/relay paths.

## 10. Explicitly rejected (do not revisit without new constraints)

- Any managed/third-party control plane or IdP (C1)
- Dual Pocket ID with runtime sync (split brain — §5)
- Second dnsblockd on the VPS "for symmetry" (zero consumers)
- SIP/RTP over the VPN (Telnyx trunk + mobile PUSH need public ingress)
- NetBird control plane on hetzner-0 without checking what private-cloud
  runs there (superseded: D2 chose the pbx box)
- Public exposure of home IP via dynamic DNS + port-forward (C6)
