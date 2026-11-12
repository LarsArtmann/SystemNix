let
  # GitHub repo hagezi/dns-blocklists is repeatedly locked by GitHub's fraud
  # detection. GitLab mirror is the primary reliable source.
  #
  # COMMIT-PINNED, not branch-tracking (2026-11-06): `main` moves daily and
  # every hagezi list is a fetchurl FOD, so a branch URL re-breaks ~20 hashes
  # the moment upstream re-publishes — live: the owner's 07:4x deploy died on
  # HaGeZi-hoster-raw (specified mME4che8, got BBE5rsFW). A moving ref with a
  # pinned hash is a self-arming deploy bomb; bump this commit + every hash
  # together (same doctrine as the paperless-gpt tag pin).
  hagezi =
    subpath:
    "https://gitlab.com/hagezi/mirror/-/raw/f8c1f9f8121b91e264ef15e5aed011f226200799/dns-blocklists/${subpath}";
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
      hash = "sha256-NsfDbvTOH9SN+As/g84AnKWQG7nPb6RtKkg6FET6OK4=";
    }
    {
      name = "HaGeZi-tif";
      url = hagezi "hosts/tif.txt";
      hash = "sha256-98CmbNLoVloo0VlYnkZrODxFr0FRs09b6PWF4TsdE0M=";
    }
    {
      name = "HaGeZi-doh";
      url = hagezi "hosts/doh.txt";
      hash = "sha256-1oBp8E/r4gOgJEasH6O2C6Cq6sdDr0RFTGX+d/DM3gE=";
    }
    {
      name = "HaGeZi-native-apple";
      url = hagezi "hosts/native.apple.txt";
      hash = "sha256-Zafh4TkSewGRnWuPwxjKACtplxp8eA7qhJqQCTzvXNE=";
    }
    {
      name = "HaGeZi-native-amazon";
      url = hagezi "hosts/native.amazon.txt";
      hash = "sha256-6l6Q407mRoOLDFiJDeO/ntRuhL7bD+mxWuhaYJhpLMc=";
    }
    {
      name = "HaGeZi-native-samsung";
      url = hagezi "hosts/native.samsung.txt";
      hash = "sha256-E1k8dSqJZR/yjAftgMs357JZwFLNp8xwca+Mc1Ta5cY=";
    }
    {
      name = "HaGeZi-native-xiaomi";
      url = hagezi "hosts/native.xiaomi.txt";
      hash = "sha256-9hWNYUv9ZKOuNFtjHfvAVLYegmZOYWDmWhQP+gfRMBA=";
    }
    {
      name = "HaGeZi-native-huawei";
      url = hagezi "hosts/native.huawei.txt";
      hash = "sha256-A1SNFjWH0y8VA97STxdPIPUPeSNtTTUQwesemGZBKP0=";
    }
    {
      name = "HaGeZi-native-lgwebos";
      url = hagezi "hosts/native.lgwebos.txt";
      hash = "sha256-QjV/hzuFRN6Vcuh30oyapDrxRLeDB4aKghbGKuwOq6E=";
    }
    {
      name = "HaGeZi-native-oppo-realme";
      url = hagezi "hosts/native.oppo-realme.txt";
      hash = "sha256-gtGDPRIPpPjcj+GSNLyBlvnPIhuaPcWdWlsBmclzKXE=";
    }
    {
      name = "HaGeZi-native-roku";
      url = hagezi "hosts/native.roku.txt";
      hash = "sha256-vHGTeEZ4YjMACLWVU7fLQmFSzagEVBxlQrak/5bLYpA=";
    }
    {
      name = "HaGeZi-native-vivo";
      url = hagezi "hosts/native.vivo.txt";
      hash = "sha256-yOPCBXnQiE6JJqKFELDiGPSB4fzsHnK7pJtjPD0RVsQ=";
    }
    {
      name = "HaGeZi-native-winoffice";
      url = hagezi "hosts/native.winoffice.txt";
      hash = "sha256-XhX/0KysO3Btb5GMZaKXjNrHiCCOXO0Q54XS5JiEk3w=";
    }
    {
      name = "HaGeZi-native-tiktok-extended";
      url = hagezi "hosts/native.tiktok.extended.txt";
      hash = "sha256-AH6OB18RoJkwE2G9p0792MbXfJajmAutCBJYqw5UHLs=";
    }
    {
      name = "HaGeZi-gambling";
      url = hagezi "dnsmasq/gambling.txt";
      hash = "sha256-rfzw1cWR33ZJsHwy1Skm7c4nOMjn7j08VtHHfI73KKk=";
    }
    {
      name = "HaGeZi-nsfw";
      url = hagezi "dnsmasq/nsfw.txt";
      hash = "sha256-9ktP6tJ+Yy8kYXUIgPuNgH638PAQwc8TD+zjOHApPCw=";
    }
    {
      name = "HaGeZi-social";
      url = hagezi "dnsmasq/social.txt";
      hash = "sha256-J59WgQcvK8oL0Xw2j7Y1N56PD4Ym83UVvXMcFYBOPKQ=";
    }
    {
      name = "HaGeZi-dyndns";
      url = hagezi "dnsmasq/dyndns.txt";
      # Re-pinned 2026-11-12: this hash was STALE SINCE the 2026-11-06
      # commit-pin wave — it kept the 2026-10-16 branch-era value, and the
      # wave never re-measured it because the old content's store path was
      # still warm (FOD sat "satisfied" without fetching). A GC collected the
      # path and the 05:24 deploy's build exposed the truth: content at
      # f8c1f9f8 is c1sqvguO, not the pinned yb9EEGbS. Full pin-set audited
      # against the commit the same day (see 2026-11-12 status); probed
      # STABLE twice 20s apart via nix store prefetch-file before this edit.
      # Commit-pinned URLs are immutable, so no oscillation is possible —
      # future mismatches here mean GitLab history rewrite, not drift.
      hash = "sha256-AKy6BbjTCYNC0j5bhdwI0HSEXVDsNYivKKxBl5YtU+c=";
    }
    {
      name = "HaGeZi-hoster";
      url = hagezi "dnsmasq/hoster.txt";
      # Re-pinned 2026-10-14: upstream content update broke the build with a
      # hash mismatch (old yq5KLUId…); new content probed STABLE twice 20s
      # apart via nix store prefetch-file before this edit.
      hash = "sha256-5FWz69pZ+EXJXHDD+/fAbAYFR7JkK1+a/HN2fWAyaWM=";
    }
    {
      name = "HaGeZi-urlshortener";
      url = hagezi "dnsmasq/urlshortener.txt";
      hash = "sha256-x41Whrjz+aDjmy5dBE7gVtwlV09hVOHpBIE6Oa6SAnY=";
    }
    {
      name = "HaGeZi-nosafesearch";
      url = hagezi "dnsmasq/nosafesearch.txt";
      hash = "sha256-cPFBVkpJqhavxUO3Q9JuVV8Mgzk/YHF8LYpFMNyUv3M=";
    }
    {
      name = "HaGeZi-dga7";
      url = hagezi "domains/dga7.txt";
      hash = "sha256-Ro4lblt46lHLwWAWA46maBe4jdnIEMO07XXNQwIzuxM=";
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
