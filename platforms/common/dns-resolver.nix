# Shared DNS resolver profile for unbound-based nodes
# Used by both evo-x2 (dns-blocker-config.nix) and rpi3-dns
#
# Prevents config drift for critical resolver settings:
# - nameservers = ["127.0.0.1"] only (resolvconf bug: 9.9.9.9 reorders)
# - do-ip6 = false (link-local IPv6 causes SERVFAIL with root servers)
# - DNSSEC hardening, prefetch, qname-minimisation
{lib, ...}: {
  networking.nameservers = ["127.0.0.1"];

  services.resolved.enable = false;

  services.unbound = {
    resolveLocalQueries = true;
    enableRootTrustAnchor = true;

    settings.server = {
      do-ip6 = false;

      prefetch = true;
      prefetch-key = true;

      qname-minimisation = true;
      hide-identity = true;
      hide-version = true;

      harden-glue = true;
      harden-dnssec-stripped = true;
      harden-below-nxdomain = true;
      harden-referral-path = true;
    };

    settings.remote-control = {
      control-enable = true;
      control-interface = "/run/unbound/unbound.ctl";
    };
  };
}
