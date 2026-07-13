# Shared DNS resolver profile for dnsblockd-based nodes
# Used by both evo-x2 (dns-blocker-config.nix) and rpi3-dns
#
# Static /etc/resolv.conf: resolvconf is DISABLED. The file is a Nix store
# symlink (read-only, immutable). This prevents ANY process from corrupting
# DNS — mullvad's talpid_dns was the known offender, writing 9.9.9.9/1.1.1.1
# directly to /etc/resolv.conf every ~90s, bypassing resolvconf entirely.
#
# dnsblockd's embedded sdns resolver handles DNSSEC, qname-minimisation,
# prefetch, and caching natively — no unbound required.
{
  config,
  lib,
  ...
}:
{
  networking.nameservers = ["127.0.0.1"];

  services.resolved.enable = false;

  # Disable dynamic resolvconf — we write /etc/resolv.conf statically below.
  # This prevents external writers (mullvad, NetworkManager, DHCP) from
  # injecting nameservers that bypass dnsblockd.
  networking.resolvconf.enable = false;

  # Static, immutable resolv.conf (Nix store symlink — cannot be overwritten).
  environment.etc."resolv.conf" = {
    text = lib.concatStringsSep "\n" (
      ["nameserver 127.0.0.1"]
      ++ lib.optional (config.networking.domain != "") "search ${config.networking.domain}"
      ++ ["options edns0 trust-ad"]
    );
    mode = "0444";
  };
}
