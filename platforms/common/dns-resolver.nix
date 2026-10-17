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
# 127.0.0.1 MUST be first so local names (*.home.lan) resolve correctly.
{
  lib,
  ...
}:
{
  # dnsblockd (127.0.0.1) is primary; 9.9.9.9 is fallback for when dnsblockd
  # is down or slow. Order matters: 127.0.0.1 MUST be first so local names
  # (*.home.lan) resolve via dnsblockd. If dnsblockd refuses/times out, glibc
  # falls through to Quad9 for external queries.
  networking.nameservers = [
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
  environment.etc."resolv.conf" = {
    text = lib.concatStringsSep "\n" [
      "nameserver 127.0.0.1"
      "nameserver 9.9.9.9"
      "options edns0 trust-ad"
    ];
    mode = "0444";
  };
}
