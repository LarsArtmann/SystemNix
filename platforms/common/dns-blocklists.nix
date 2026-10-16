let
  # GitHub repo hagezi/dns-blocklists is repeatedly locked by GitHub's fraud
  # detection. GitLab mirror is the primary reliable source.
  hagezi = subpath: "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/${subpath}";
in
{
  blocklists = [
    {
      name = "StevenBlack-everything";
      url = "https://raw.githubusercontent.com/StevenBlack/hosts/21605ccaecf26941005d4a7a3c1267af234599cf/alternates/fakenews-gambling-porn-social/hosts";
      hash = "sha256-E2yOYxYa0iPVZq5AKrLtqs/dlYt+dxCeT2cV+zBfLbY=";
    }
    {
      name = "HaGeZi-ultimate";
      url = hagezi "hosts/ultimate.txt";
      hash = "sha256-EhTG2hTsybKbmQZp3/ydVcyVUpRwT6vc8DbxmczbZQ4=";
    }
    {
      name = "HaGeZi-tif";
      url = hagezi "hosts/tif.txt";
      hash = "sha256-ReEh7Mum9YsCeQJLCymUXErvpVlyRsG6EA92cjpKCWQ=";
    }
    {
      name = "HaGeZi-doh";
      url = hagezi "hosts/doh.txt";
      hash = "sha256-z00/JP8zQiCjlo3gdtgPzLgyz5WrWRSc2OKnEjb/Qmo=";
    }
    {
      name = "HaGeZi-native-apple";
      url = hagezi "hosts/native.apple.txt";
      hash = "sha256-OGE9IwfmyM9gtZgxMpYCkWHZK93Hl+kt58Oj2urb5Nw=";
    }
    {
      name = "HaGeZi-native-amazon";
      url = hagezi "hosts/native.amazon.txt";
      hash = "sha256-XaSnAUtsuAZwxm/cd5AhFtwPo7WXwQKDZJeGnmzEa+A=";
    }
    {
      name = "HaGeZi-native-samsung";
      url = hagezi "hosts/native.samsung.txt";
      hash = "sha256-uhLpFsVHB3CGcYn/4d0b9xmZwG1MI9gQkysQwpwm558=";
    }
    {
      name = "HaGeZi-native-xiaomi";
      url = hagezi "hosts/native.xiaomi.txt";
      hash = "sha256-J64Zk8gbJkjDn963lXbn8y9IviT0/8/1PPG+OvBIC3A=";
    }
    {
      name = "HaGeZi-native-huawei";
      url = hagezi "hosts/native.huawei.txt";
      hash = "sha256-oSs3Ex32dTzFVPvDBsSwHFrGIxZ1CrXxmV9XnKrLPFM=";
    }
    {
      name = "HaGeZi-native-lgwebos";
      url = hagezi "hosts/native.lgwebos.txt";
      hash = "sha256-q7TpFrD1pVppTFPFbUdx65Wn/ppinurWGUv8gz8bVmo=";
    }
    {
      name = "HaGeZi-native-oppo-realme";
      url = hagezi "hosts/native.oppo-realme.txt";
      hash = "sha256-751AGK6URIuSShX0OPz4Gol+FMs47b0Qx5UYAE0gwEY=";
    }
    {
      name = "HaGeZi-native-roku";
      url = hagezi "hosts/native.roku.txt";
      hash = "sha256-NjOiQjTphJVntt0N8rXvD/KmneToY8uS0y4pQs1mcbY=";
    }
    {
      name = "HaGeZi-native-vivo";
      url = hagezi "hosts/native.vivo.txt";
      hash = "sha256-t4oce4IkzjU7hO6S9W6BzXwq/Amg/CbPlI5QF27NgcI=";
    }
    {
      name = "HaGeZi-native-winoffice";
      url = hagezi "hosts/native.winoffice.txt";
      hash = "sha256-3tz5bBE35iB8LTjTVFG3UBGz2Hpdi3GSRKYQ9In/KwA=";
    }
    {
      name = "HaGeZi-native-tiktok-extended";
      url = hagezi "hosts/native.tiktok.extended.txt";
      hash = "sha256-xcg+6KzTVYw/YvjAKeCVis4iEHihje9Auvl8/akKg4E=";
    }
    {
      name = "HaGeZi-gambling";
      url = hagezi "dnsmasq/gambling.txt";
      hash = "sha256-buvN31Nlcg2F4dnJTbskCFSp77KT13e+MC/YCkuTPOA=";
    }
    {
      name = "HaGeZi-nsfw";
      url = hagezi "dnsmasq/nsfw.txt";
      hash = "sha256-gtSwYCrGSZ4PO2msFin844qwMjIRxgEwlwtkKttdTvc=";
    }
    {
      name = "HaGeZi-social";
      url = hagezi "dnsmasq/social.txt";
      hash = "sha256-mxTyflhNFLuGl4Sfvd7M0va5GM38fz+d9dZ2FnTUoCk=";
    }
    {
      name = "HaGeZi-dyndns";
      url = hagezi "dnsmasq/dyndns.txt";
      # Re-pinned 2026-10-16: upstream reverted to an older content state
      # (matches the store output of a pre-sEWGDR5z build, byte-identical),
      # so this value may flip back on a future mismatch — if it does,
      # upstream is oscillating and the list needs a commit-pinned URL
      # instead of hash bumps. Probed STABLE twice 20s apart via
      # nix store prefetch-file before this edit.
      hash = "sha256-msvz1YA+TtLril0jY2SUpogtEPiAtpCxNE+lxjDG56E=";
    }
    {
      name = "HaGeZi-hoster";
      url = hagezi "dnsmasq/hoster.txt";
      # Re-pinned 2026-10-14: upstream content update broke the build with a
      # hash mismatch (old yq5KLUId…); new content probed STABLE twice 20s
      # apart via nix store prefetch-file before this edit.
      hash = "sha256-xiO3b1plZhSRR1+BfGlhUivcAneiJ6oApdiJX9g0qDc=";
    }
    {
      name = "HaGeZi-urlshortener";
      url = hagezi "dnsmasq/urlshortener.txt";
      hash = "sha256-KYstcKMWiwZ+A14q+3RECCdhtml3A/TnELEGDG8n4lc=";
    }
    {
      name = "HaGeZi-nosafesearch";
      url = hagezi "dnsmasq/nosafesearch.txt";
      hash = "sha256-WNYasp5RDyXMCVqHeiZn4OHlijBocB+9CfTnvcEB0qU=";
    }
    {
      name = "HaGeZi-dga7";
      url = hagezi "domains/dga7.txt";
      hash = "sha256-6fDRn6q1L66O8gRCWEc7N3e71jMzh8Ljtn/nX2KuqSw=";
    }
  ];

  whitelist = [
    "mullvad.net"
    "api.immich.app"
    "immich.app"
    "github.com"
    "github-releases.githubusercontent.com"
    "objects.githubusercontent.com"
    # Google Cloud Monitoring API — the SigNoz GCP integration's collector
    # scrapes this endpoint; blocklists classify it as telemetry and
    # dnsblockd served its block page at 192.168.1.200 (HTTP 200 HTML, so
    # scrapes failed with JSON parse errors, not network errors — found
    # live 2026-09-29 during the integration go-live probe). oauth2.
    # googleapis.com (token endpoint) is NOT blocked, listed nowhere.
    "monitoring.googleapis.com"
    "linkedin.com"
    "linkedin.at"
    "linkedin.be"
    "linkedin.cn"
    "linkedin.nl"
    "licdn.com"
    "lnkd.in"
    "linktr.ee"
    "nominatim.openstreetmap.org"
    "tile.openstreetmap.org"
    "huggingface.co"
    "hf.co"
    "cdn-lfs.huggingface.co"
    "cdn-lfs-us-1.huggingface.co"
    # Discord — always allowed. Covers the full discord brand surface so any
    # subdomain (gateway, CDN, status, media, etc.) resolves. The filter
    # walks parent domains, so `discord.com` alone strips `*.discord.com` but
    # not `discord.gg` / `discordapp.com` — those are listed explicitly.
    "discord.com"
    "discord.gg"
    "discordapp.com"
    "discordapp.net"
    "discordapp.io"
    "discordcdn.com"
    "discordactivities.com"
    "discord-activities.com"
    "discordmerch.com"
    "discordpartygames.com"
    "discordsays.com"
    "discordstatus.com"
    "gateway.discord.gg"
    "discord.co"
    "discord.design"
    "discord.dev"
    "discord.gift"
    "discord.gifts"
    "discord.media"
    "discord.new"
    "discord.store"
    "discord.tools"
    "9gag.com"
    "9cache.com"
    "movieffm.net"
    "www.movieffm.net"
    "deref-mail.com"
    "wbby.co"
    "olevod.com"
    "www.olevod.com"
    "apache.org"
    "www.apache.org"
    "downloads.apache.org"
    "archive.apache.org"
    "maven.apache.org"
    "repo.maven.apache.org"
    "dlcdn.apache.org"
    "myip.is"
    "extreme-ip-lookup.com"
    # Public-IP echo for GeoMetrikks's MAP_PUBLIC_IP_URL default
    # (https://api64.ipify.org?format=json). HaGeZi-ultimate blocks it
    # (telemetry category), so DNS answered 192.168.1.200 and the app's
    # JSON parse died with "Expecting value: line 1 column 1 (char 0)" ->
    # the map-home-undetected advisory + hidden home marker (live
    # 2026-10-14). The filter walks parent domains, so `ipify.org` unblocks
    # api.ipify.org / api64.ipify.org too.
    "ipify.org"
    "itv.com"
    "cpt.itv.com"
    "tom.itv.com"
    "gtm.bde.itv.com"
    "cassiecloud.com"
    "cscript-cdn-irl.cassiecloud.com"
    "splunkcloud.com"
    "http-inputs-itv.splunkcloud.com"
    "toots-a.akamaihd.net"
    "akamaihd.net"
    "region1.analytics.google.com"
    # CrowdSec hub CDN + data hosts (2026-10-16): `cscli hub update` runs
    # start-fatal at every crowdsec start and fetches from cdn-hub.crowdsec.net
    # (Cloudfront) + hub-data.crowdsec.net (Cloudflare); HaGeZi intermittently
    # TLS-intercepts the CDN host ("remote error: tls: internal error",
    # dnsblockd class) — two fatal starts 2026-10-15 22:37/23:30 = ~2h18m
    # engine outage. The www.crowdsec.net whitelist entry misses the CDN;
    # whitelisting makes the start-critical fetch deterministic.
    "cdn-hub.crowdsec.net"
    "hub-data.crowdsec.net"
    # SBS On Demand streaming — required for video playback
    "pubads.g.doubleclick.net"
    "licensing.bitmovin.com"
    "smetrics.sbs.com.au"
  ];

  extraDomains = [
    "reddit.com"
    "redd.it"
    "redditmedia.com"
    "redditstatic.com"
    # PostHog US analytics ingest (crush telemetry endpoint) — removed from the
    # whitelist 2026-09-16; DO_NOT_TRACK=1 already keeps crush silent, this
    # blocks the endpoint itself at DNS level.
    "us.i.posthog.com"
  ];

  categories = {
    ".doubleclick.net" = "Advertising";
    ".googlesyndication.com" = "Advertising";
    ".googleadservices.com" = "Advertising";
    ".adnxs.com" = "Advertising";
    ".adsrvr.org" = "Advertising";
    ".facebook.net" = "Tracking";
    ".analytics.google.com" = "Analytics";
    ".google-analytics.com" = "Analytics";
    ".pornhub.com" = "Adult Content";
    ".xvideos.com" = "Adult Content";
    ".xnxx.com" = "Adult Content";
    ".redtube.com" = "Adult Content";
    ".onlyfans.com" = "Adult Content";
    ".chaturbate.com" = "Adult Content";
    ".tiktok.com" = "Social Media";
    ".tiktokcdn.com" = "Social Media";
    ".reddit.com" = "Social Media";
    ".redd.it" = "Social Media";
    ".redditmedia.com" = "Social Media";
    ".redditstatic.com" = "Social Media";
  };
}
