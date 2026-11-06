# Shared DNS resolver profile for dnsblockd-based nodes
# Used by both evo-x2 (dns-blocker-config.nix) and rpi3-dns
#
# Static /etc/resolv.conf: resolvconf is DISABLED. The file is a Nix store
# symlink (read-only, immutable). This prevents ANY process from corrupting
# DNS — mullvad's talpid_dns was the known offender, writing 9.9.9.9/1.1.1.1
# directly to /etc/resolv.conf every ~90s, bypassing resolvconf entirely.
#
# dnsblockd's embedded sdns resolver handles DNSSEC, qname-minimisation,
# prefetch, and caching natively — no unbound required. Quad9 (9.9.9.9) is
# included as a fallback for resilience when dnsblockd is down or slow.
# A dnsblockd instance MUST be first so local names (*.home.lan) resolve
# correctly — but WHICH instance depends on gateway mode (below).
{
  lib,
  config,
  ...
}:
{
  # Gateway-aware resolver order (owner gateway enablement 2026-11-06):
  # with the DNS lie armed (services.dns-blocker.gatewayEnabled), the host
  # itself resolves through the gateway-FREE failover peer FIRST
  # (networking.local.piIP, default .151) and only falls back to the local
  # instance. WHY: the lie is a VALID DNS answer — glibc never falls
  # through on it — so with loopback-first the host's own by-name
  # non-TLS traffic (git@github.com SSH, ssh to public hosts) would land on
  # the gateway and be refused loudly (no_handler, ADR-0011). rpi3 serves
  # the SAME local zones, blocklists, DNSSEC and DoT forwarders (module
  # parity pinned by checks.dns-blocker-render), so host semantics are
  # unchanged except a ~1ms LAN hop; capture stays scoped to the household
  # devices instead of blinding the box that deploys this config. If rpi3
  # is down, glibc times out and falls back to the local lie — DNS keeps
  # working, only by-name SSH to public hosts degrades (loud, known).
  # Hosts without the gateway stay loopback-first (rpi3-dns queries its own
  # instance; its gateway is OFF).
  networking.nameservers =
    let
      gatewayArmed =
        (config.services.dns-blocker.enable or false)
        && (config.services.dns-blocker.gatewayEnabled or false);
    in
    if gatewayArmed then
      [
        (config.networking.local.piIP or "192.168.1.151")
        "127.0.0.1"
        "9.9.9.9"
      ]
    else
      [
        "127.0.0.1"
        "9.9.9.9"
      ];

  services.resolved.enable = false;

  # Disable dynamic resolvconf — we write /etc/resolv.conf statically below.
  # This prevents external writers (mullvad, NetworkManager, DHCP) from
  # injecting nameservers that bypass dnsblockd.
  networking.resolvconf.enable = false;

  # Static, immutable resolv.conf (Nix store symlink — cannot be overwritten).
  # Deliberately NO `search` line (2026-10-17): with the *.home.lan wildcard
  # local record live, search-domain completion resolved any failed public
  # name (offline, or typo'd/NXDOMAIN while online) through the wildcard onto
  # this host — offline connectivity checks read "up" and public-name typos
  # landed on the LAN. Accepted loss: bare-label typing (`ping forge`) stops
  # resolving; measured usage on these hosts was zero (shell history + config
  # sweep). Full diagnosis: docs/services/dnsblockd.md.
  # The nameserver ORDER mirrors networking.nameservers (gateway-aware; see
  # above for why the failover peer precedes loopback while the lie is armed).
  environment.etc."resolv.conf" = {
    text = lib.concatStringsSep "\n" (
      (map (ns: "nameserver ${ns}") (
        let
          gatewayArmed =
            (config.services.dns-blocker.enable or false)
            && (config.services.dns-blocker.gatewayEnabled or false);
        in
        if gatewayArmed then
          [
            (config.networking.local.piIP or "192.168.1.151")
            "127.0.0.1"
            "9.9.9.9"
          ]
        else
          [
            "127.0.0.1"
            "9.9.9.9"
          ]
      ))
      ++ [ "options edns0 trust-ad" ]
    );
    mode = "0444";
  };
}
