# DNS Blocker - Declarative DNS with ad blocking and block pages
# Uses dnsblockd (embedded sdns recursive resolver + Go HTTP server for block pages)
#
# Coverage: ~4M+ unique domains across 23 blocklists
# - Ads, malware, phishing, scams, fakenews, gambling, porn, social trackers
# - DNS-over-HTTPS/VPN/TOR/Proxy bypass prevention
# - Native telemetry: Apple, Amazon, Samsung, Xiaomi, Huawei, LG WebOS,
#   Oppo/Realme, Roku, Vivo, Windows/Office, TikTok
# - DGA/NRD blocking, anti-piracy, NSFW, social, gambling, URL shorteners
# - Dynamic DNS, badware hosters, safesearch enforcement
#
# Blocklists are shared with rpi3-dns via platforms/common/dns-blocklists.nix
# Local DNS records are in platforms/common/dns-local.nix
# DNS resolution: forwarded via DNS-over-TLS to Cloudflare + Quad9 — a
# deliberate choice (filtered upstream, no root-server exposure). Root
# recursion WORKS without forwarders since dnsblockd 8e598c01 (T299,
# resolver seams wired; deployed with lock rev f625cfee 2026-09-30) — drop
# the forwarders block only if a future owner decision wants full recursion.
{
  config,
  lib,
  ...
}:
let
  inherit (config.networking) domain;
  inherit (config.networking.local) blockIP virtualIP cloudDomain;
  blocklists = import ../../common/dns-blocklists.nix;
  inherit (import ../../../lib/default.nix lib) ports;
  dnsLocal = import ../../common/dns-local.nix;
  lanIP = builtins.head config.networking.interfaces.eno1.ipv4.addresses;
  serverIP = lanIP.address;
in
{
  services = {
    dns-blocker = {
      enable = true;

      inherit blockIP;
      blockPort = 80;
      blockTLSPort = 443;
      blockInterface = "eno1";
      blockIPPrefix = 24;
      statsPort = ports.dns-blocker-stats;

      # Caddy reverse-proxies dnsblock.${domain} to the loopback stats API;
      # trust its X-Forwarded-For so the audit log records the real LAN
      # client instead of 127.0.0.1. Spoof-safe: 127.0.0.1 is the stats
      # bind address, so only Caddy (and root-local processes) can connect.
      trustedProxies = [ "127.0.0.1" ];

      inherit (blocklists)
        blocklists
        whitelist
        extraDomains
        categories
        ;

      enableDNSSEC = true;

      # DoS belt: per-client-IP token bucket (50 q/s, burst 100). A single
      # runaway client (browser prefetch storm, misconfigured app) must not
      # be able to starve the sole LAN resolver. The wrapper default stays 0
      # (upstream-matching) — this is an evo-x2 stance; rpi3's failover
      # instance stays unlimited until it ever serves standalone.
      dnsRateLimitPerSec = 50;
      dnsRateLimitBurst = 100;

      # Household device registry — named attribution in Top Clients,
      # per-device pause, device-scoped temp-allows. Inventory 2026-09-30
      # (/proc/net/arp + repo knowledge); unknown-identity entries carry
      # owner-confirm markers to verify at the next deploy window (plan M11).
      # The VRRP virtualIP (.53) and blockIP (.200) are NOT devices.
      devices = [
        {
          id = "evo-x2";
          name = "evo-x2 (this host)";
          ips = [ "192.168.1.150" ];
        }
        {
          id = "rpi3-dns";
          name = "Raspberry Pi 3 (DNS failover)";
          ips = [ "192.168.1.151" ];
        }
        {
          id = "lan-router";
          name = "LAN Router / Gateway";
          ips = [ "192.168.1.1" ];
        }
        {
          # owner-confirm: Realtek NIC (00:e0:4c:…) — LG TV SSCR2 by
          # elimination; wired TVs keep stable MACs but confirm anyway.
          id = "lg-tv";
          name = "LG TV (SSCR2)";
          ips = [ "192.168.1.62" ];
        }
      ];
      users = [
        {
          name = "Lars";
          devices = [
            "evo-x2"
          ];
        }
      ];

      # Forward via DNS-over-TLS. The sdns embedded resolver's root recursion
      # is broken in dnsblockd (middleware pipeline not wired up), so we
      # forward to trusted DoT resolvers. Local zones, blocklists, and ACLs
      # are still handled by dnsblockd before forwarding.
      dnsForwarders = [
        "tls://1.1.1.1:853"
        "tls://9.9.9.9:853"
      ];

      # Temporarily allow all DNS queries (disable blocking)
      # Set to true to bypass all DNS blocking
      tempAllowAll = false;

      # Local DNS records: home.lan zone with all service subdomains.
      # Zone boundary ensures unknown *.home.lan names return NXDOMAIN
      # (like Unbound's local-zone "static").
      localRecords =
        builtins.listToAttrs (
          map (subdomain: {
            name = "${subdomain}.${domain}.";
            value = serverIP;
          }) dnsLocal.localSubdomains
        )
        // {
          "*.${domain}." = serverIP;
          "${domain}." = serverIP;
        }
        # Split-horizon alias zone (brainstorming 2026-09-30): the same
        # service set under the cloud domain so VPN clients get one
        # namespace everywhere. No wildcard entry — sdns ignores wildcard
        # local records (gotchas-archive.md), explicit records only.
        // builtins.listToAttrs (
          map (subdomain: {
            name = "${subdomain}.${cloudDomain}.";
            value = serverIP;
          }) dnsLocal.localSubdomains
        )
        // {
          "${cloudDomain}." = serverIP;
        }
        # Public hosts inside the authoritative cloud zone (see
        # dns-local.nix cloudPublicRecords): the NetBird control plane on
        # pbx must resolve to its public IP instead of being
        # shadow-NXDOMAINed by the alias zone. Without this, evo-x2 cannot
        # reach netbird.larsartmann.cloud at all — client enrollment AND
        # Gatus checks die on DNS (found live 2026-10-02).
        // lib.mapAttrs' (
          sub: ip: lib.nameValuePair "${sub}.${cloudDomain}." ip
        ) dnsLocal.cloudPublicRecords;
      localZones = [
        "${domain}."
        "${cloudDomain}."
      ];
      allowedNetworks = [
        "127.0.0.0/8"
        "::1/128"
        "${config.networking.local.subnet}"
      ];
      dnsIPv6Enabled = false; # evo-x2 has no global IPv6

      # Native OIDC SSO for the dashboard via Pocket ID (passkeys).
      # Client secret is bridged by the dnsblockd-oidc-secret oneshot from
      # Pocket ID's client-secrets provisioning; audit entries record the
      # signed-in identity. The Bearer token was RETIRED 2026-08-21: SSO is
      # the only dashboard credential (decision: no LAN bypass — one passkey
      # per 12h everywhere; DMS widget waits for Pocket ID machine creds).
      oidcIssuerURL = "https://auth.${domain}";
      oidcClientID = "dnsblockd";
      oidcRedirectURL = "https://dnsblock.${domain}/auth/oidc/callback";
      oidcButtonText = "Sign in with Pocket ID";

      # Reverse-proxy temp-allowed domains so "Continue to site" works
      # without waiting for the browser's cached block IP to expire.
      # CA cert/key are trusted via security.pki.certificates below.
      proxyEnabled = true;
      proxyConnectTimeout = "10s";
      proxyUpstreamDNS = [
        "1.1.1.1:53"
        "9.9.9.9:53"
      ];
    };

    dnsblockd-cert-trust = {
      enable = true;
      caCertPath = config.sops.secrets.dnsblockd_ca_cert.path;
    };

    dns-failover = {
      enable = true;
      inherit virtualIP;
      interface = "eno1";
      priority = 100;
      routerID = 53;
      subnetPrefix = 24;
      passwordFile = config.sops.templates."dns-failover-env".path;
    };
  };

  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
      MIIFSzCCAzOgAwIBAgIUDqspDh2XW/f9Souz6bcD+o2XNzYwDQYJKoZIhvcNAQEL
      BQAwLTEUMBIGA1UECgwLRE5TIEJsb2NrZXIxFTATBgNVBAMMDGRuc2Jsb2NrZC1D
      QTAeFw0yNjA0MTUyMDM5NTFaFw0zNjA0MTIyMDM5NTFaMC0xFDASBgNVBAoMC0RO
      UyBCbG9ja2VyMRUwEwYDVQQDDAxkbnNibG9ja2QtQ0EwggIiMA0GCSqGSIb3DQEB
      AQUAA4ICDwAwggIKAoICAQCmvcU/AZkvI+HjHceuiwDHeGWKpHDX7JTmNwX5qjHL
      H+h6KLW6HfnHEyK95uSNd+yVf9ElWm6SpRS6CqgtGgpcJd+LZz3CJIeVGxl9RElw
      hK2HO6dglKVNQ9cLNfDiAEX3yoK3s6WnALiOxbb+0TKjkthMvOoIUDRfHk1pos+z
      Opyt8UQutHHW/21b+HKK0l9BIQCTh3Z2+psD4HlD5Vr8aVIsNFz2WCDoo3sDcHGh
      O4OnPC4kXBs4niehufYxb50LO2aXsHK5drCi5RKldtleIoRmOkahLHMqdyyd2Cni
      kYuiVNZAc48KbogUylXW0RUPwy4WlSGrOLyNUQMPrv5hm8ssALiYQUJDgBXpNIY2
      O85BJz19PIlNuhQfHgYZtslJLyw3S8ysC374QHuD3ujEaXAo1YvXerYjMhGx9Iaq
      uOL0IVk9rEP6zgJFD8rFiUg4DYL0geaW9OxLB6B7xsyBxTdvCAfqw3H0zC/9qh2D
      AdWX/tTjSMkg1veCFSajWHJgSZ5ifWuupeoGwmCIt+/D5hGlu3/W1vHu/35Lpi38
      ztaLZSbVSt6fPgLkSbvJsCl4c5rAfVFJjEfAOYPqJIsCLiFqk1VbPl+Hq8BhFpM5
      Mmq6flA1saBeGTWjX4WA8jFYoWo9vIiKEk5Vhu4flS5SuqFDNFzjg4tnrGpc0auK
      1QIDAQABo2MwYTAdBgNVHQ4EFgQUBinFT/s3XD7Yev2b7n0lN4x6+wQwHwYDVR0j
      BBgwFoAUBinFT/s3XD7Yev2b7n0lN4x6+wQwDwYDVR0TAQH/BAUwAwEB/zAOBgNV
      HQ8BAf8EBAMCAYYwDQYJKoZIhvcNAQELBQADggIBACjMqd5/Hm3Z+E7umhFmJ+1U
      t8kDoK8QS5GyUY2LKh5mcnYhO875Dtf/PCqwkZPD/BUNULQkzIe6TTJS1zBNx9LJ
      UyCpTQgLnFPY14uAX8PtWs17v8RmMw5l1GA+qLTJUbtKFOke473XRLbUyTgojVcv
      qoGXDyWQCfyFyB0JCpvLnn8EvIkJqHjdOpYSBurhyvbe0TGTExGCAqJU8RquSbkZ
      Yzh+irQOTPAVqcfollcYyHmNmsBO15AH546XQ+/zZbyy+V+y/Edu2yiw7jlGO7ns
      /I0aIzxEqjYoc+97C8Z51ghpbMGxt21nZDFHG5VaarOAYmPog6eYdY9c+kIDXQy5
      OBr5DW9yQdygwrFGO/7G3IfagFAvBFh0eYdb7fLSjALZ10rXpW5cLF4I+JYPpIAF
      Xj0aM0p1W5PUkoaoX/GiqGa16zWIkKOzweSBaoujMG+ECwj7FJ/9pBambugLzLHj
      TIEv0cruwnVH3b2xB7xlJxG+xqOZc9dzwVJBuQrxGy9sBKRkVhZ1jTYpZHiMXkOy
      FfCJC+loveVYUATxtcDodFKdkrPcbRuePq5Gc5hhz6spclnpqU51sNIT9WbnzcNX
      lYZb3Fj7sC81t6Q79iJT0tZYIArAlEuFIMS3gpkJ9OmYnvolhguNYEWOl0DyQomY
      p1rA+kCu1d6iiQ3gN2va
      -----END CERTIFICATE-----
    ''
  ];
}
