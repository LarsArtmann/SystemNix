# DNS Blocker - Declarative DNS with ad blocking and block pages
# Uses unbound + dnsblockd (Go HTTP server for block pages)
#
# Coverage: ~2.5M+ unique domains across 25 blocklists
# - Ads, malware, phishing, scams, fakenews, gambling, porn, social trackers
# - DNS-over-HTTPS/VPN/TOR/Proxy bypass prevention
# - Native telemetry: Apple, Amazon, Samsung, Xiaomi, Huawei, LG WebOS,
#   Oppo/Realme, Roku, Vivo, Windows/Office, TikTok
# - DGA/NRD blocking, anti-piracy, NSFW, social, gambling, URL shorteners
# - Dynamic DNS, badware hosters, safesearch enforcement
#
# Blocklists are shared with rpi3-dns via platforms/common/dns-blocklists.nix
# DNS resolution: full recursive from root hints (no third-party resolver)
{
  pkgs,
  config,
  ...
}: let
  inherit (config.networking) domain;
  inherit (config.networking.local) blockIP virtualIP;
  blocklists = import ../../common/dns-blocklists.nix;
  lanIP =
    builtins.head
    config.networking.interfaces.eno1.ipv4.addresses;
  serverIP = lanIP.address;
in {
  services = {
    dns-blocker = {
      enable = true;

      inherit blockIP;
      blockPort = 80;
      blockTLSPort = 443;
      blockInterface = "eno1";
      blockIPPrefix = 24;
      statsPort = 9090;

      inherit (blocklists) blocklists whitelist extraDomains categories;

      enableDNSSEC = true;

      # DoQ (DNS-over-QUIC) port — RFC 9250, uses QUIC transport encryption
      # No TLS certificates needed — QUIC handles encryption natively
      # DISABLED: the unboundDoQOverlay that patches unbound for DoQ support
      # kills binary cache hits (cascades to ffmpeg, linux, pipewire, etc.)
      # doqPort = 853;

      # Temporarily allow all DNS queries (disable blocking)
      # Set to true to bypass all DNS blocking
      tempAllowAll = false;
    };

    unbound.settings.server = {
      verbosity = 1;
      local-zone = [''"${domain}." static''];
      local-data =
        map
        (subdomain: ''"${subdomain}.${domain}. IN A ${serverIP}"'')
        ["auth" "immich" "forgejo" "dash" "signoz" "tasks" "crm" "manifest" "status" "seo" "daily" "logs" "monitor"];
    };

    dns-failover = {
      enable = true;
      inherit virtualIP;
      interface = "eno1";
      priority = 100;
      routerID = 53;
      subnetPrefix = 24;
      passwordFile = pkgs.writeText "keepalived-vrrp-env" "VRRP_AUTH_PASSWORD=DNSClusterVRRP-evox2";
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
