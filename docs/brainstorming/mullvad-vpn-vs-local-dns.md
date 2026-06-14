# Mullvad VPN vs Local DNS Resolver

## Context

SystemNix runs unbound as a full recursive resolver on evo-x2 (192.168.1.150).
It applies blocklists (HaGeZi, StevenBlack, etc.) and resolves local zones
(`*.home.lan`). When Mullvad VPN connects, DNS breaks — all non-cached domains
fail to resolve.

## Root Cause

Mullvad's nftables firewall **blocks all outbound port 53 traffic** except to
specifically allowlisted DNS server IPs. This prevents DNS leaks — a core
security feature of the VPN.

Unbound runs as a **full recursive resolver**: it queries root DNS servers
(`198.41.0.4`, `192.36.148.17`, etc.) directly on **port 53**.

```
App → 127.0.0.1:53 (unbound) → root servers on port 53 → BLOCKED by Mullvad firewall
```

The `mullvad dns set custom 192.168.1.150` setting only allows apps to reach
unbound — it doesn't help unbound reach upstream servers. Any non-cached domain
fails to resolve.

## Options Considered

### 1. DNS-over-TLS Forwarding (port 853) — RECOMMENDED

Switch unbound from full recursion (root hints, port 53) to DoT forwarding
(port 853). Mullvad's firewall only intercepts port 53. DoT traffic on port 853
flows through the VPN tunnel as normal TLS traffic — not intercepted, not
blocked.

```
App → 127.0.0.1:53 (unbound) → blocklist check → DoT on port 853 → through VPN tunnel → resolver
```

**Pros:**
- Low effort — change unbound config only
- Blocklists still work (applied before forwarding)
- Local zones (`*.home.lan`) still work
- Works with and without VPN (DoT reachable directly)
- Encrypted upstream — better privacy than plain recursion

**Cons:**
- Loses "no third-party resolver" purity
- Trusts upstream resolver (e.g. Mullvad DNS `194.242.2.2` or Quad9 `9.9.9.9`)
- Adds one hop of latency for cache misses

### 2. Disable Mullvad's nftables Firewall

Not possible. The firewall is deeply integrated into the Mullvad daemon — it
is the kill switch, DNS leak protection, and WireGuard routing all in one.

**What happens if you force-disable it:**
- No kill switch — if the tunnel drops, all traffic leaks in cleartext
- No DNS leak protection — any app can bypass your DNS config
- Must manually manage WireGuard routing rules, mark-based policy routing,
  and table priorities
- Mullvad re-applies its rules on every connect/disconnect/reconnect, so any
  custom nftables rules get clobbered

**Verdict:** Not viable. The daemon cannot function without its firewall.

### 3. Raw WireGuard (No Mullvad Daemon)

Use `networking.wireguard` directly in NixOS with Mullvad's server endpoints
and your own key pair. Full control over routing, DNS, and firewall.

**Pros:**
- Full control over nftables, kill switch, DNS routing
- No interference with local resolver — recursion works as-is
- Declarative in NixOS config

**Cons:**
- Lose Mullvad GUI, CLI (`mullvad relay list`, location switching)
- Must hand-build kill switch (nftables rules to block non-tunnel traffic)
- Must handle DNS leak prevention yourself
- No Mullvad multihop, DAITA, or bridge mode
- Key management is manual (generate, register via API)
- Mullvad server list changes — need periodic updates
- Significant maintenance burden

**Verdict:** Viable for someone who wants full control, but high effort and
loses Mullvad's convenience features.

## Decision

**Option 1 (DoT forwarding)** — IMPLEMENTED.

Unbound now forwards via DNS-over-TLS to Mullvad DNS (`194.242.2.2@853#dns.mullvad.net`)
with Quad9 (`9.9.9.9@853#dns.quad9.net`) as fallback. This works *with* Mullvad's
security model — port 853 is not intercepted by the firewall.

## Implementation

- **`modules/nixos/services/dns-blocker.nix`**: Replaced `root-hints` with
  `forward-zone` using `forward-tls-upstream: yes`. Blocklists, local zones,
  and DNSSEC validation still apply before forwarding.
- **`platforms/nixos/system/configuration.nix`**: `mullvad-config.service`
  uses `bindsTo` + `Restart` to re-apply LAN sharing and custom DNS after
  daemon restarts.
- **`platforms/nixos/system/dns-blocker-config.nix`**: Updated comment.
