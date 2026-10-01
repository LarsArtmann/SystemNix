let
  # GitHub repo hagezi/dns-blocklists is repeatedly locked by GitHub's fraud
  # detection. GitLab mirror is the primary reliable source.
  hagezi = subpath: "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/${subpath}";
in
{
  blocklists = [
    {
      name = "StevenBlack-everything";
      url = "https://raw.githubusercontent.com/StevenBlack/hosts/abe587abf7979d93b7a8267d5d3e1fbc32541163/alternates/fakenews-gambling-porn-social/hosts";
      hash = "sha256-xUUG5HQMETGa5lN3y8W8cxDz5LOO3Sdw85g/6wBXK3Y=";
    }
    {
      name = "HaGeZi-ultimate";
      url = hagezi "hosts/ultimate.txt";
      hash = "sha256-+Vk5H3Me01tiadRF0wjNRRvuCBfavUoU7tFUq13G1Qs=";
    }
    {
      name = "HaGeZi-tif";
      url = hagezi "hosts/tif.txt";
      hash = "sha256-vzIfdQCCCyiWbpt9OMIiLH8GJzFdSpv6R63XF5S9ZVI=";
    }
    {
      name = "HaGeZi-doh";
      url = hagezi "hosts/doh.txt";
      hash = "sha256-QehcUJmtVBU58QeJKDF/qm20nHRb7cebpFXS/2+26Yw=";
    }
    {
      name = "HaGeZi-native-apple";
      url = hagezi "hosts/native.apple.txt";
      hash = "sha256-jlIb5DfwXJOduNLExBGi29XyCmtdJPfDPELr4mD95ZY=";
    }
    {
      name = "HaGeZi-native-amazon";
      url = hagezi "hosts/native.amazon.txt";
      hash = "sha256-0hD+CJKBv5YZvivMtnOjmAHHy93jtpx6PEWLcLINpYQ=";
    }
    {
      name = "HaGeZi-native-samsung";
      url = hagezi "hosts/native.samsung.txt";
      hash = "sha256-oDtubaJoDe2AHFzdmOZPa+sJS6EQhTCVXlCDRCGjWE8=";
    }
    {
      name = "HaGeZi-native-xiaomi";
      url = hagezi "hosts/native.xiaomi.txt";
      hash = "sha256-J64Zk8gbJkjDn963lXbn8y9IviT0/8/1PPG+OvBIC3A=";
    }
    {
      name = "HaGeZi-native-huawei";
      url = hagezi "hosts/native.huawei.txt";
      hash = "sha256-juxfIKouagDVrrwDQlQN0ACCY7ZIr3Ql8nudJQSCCSI=";
    }
    {
      name = "HaGeZi-native-lgwebos";
      url = hagezi "hosts/native.lgwebos.txt";
      hash = "sha256-yS23pdXRsLgbi7pUCl5uAHS4EdhCntTula7DbJtkp8k=";
    }
    {
      name = "HaGeZi-native-oppo-realme";
      url = hagezi "hosts/native.oppo-realme.txt";
      hash = "sha256-zON47p/1GWyhv81oh4Y5jibNwpo0Zcg8Xp1Gn8UWKP0=";
    }
    {
      name = "HaGeZi-native-roku";
      url = hagezi "hosts/native.roku.txt";
      hash = "sha256-NjOiQjTphJVntt0N8rXvD/KmneToY8uS0y4pQs1mcbY=";
    }
    {
      name = "HaGeZi-native-vivo";
      url = hagezi "hosts/native.vivo.txt";
      hash = "sha256-9QwMj86PFQwgUWMN8WypuSOPDQuXnCXqMcQdk4ZGxbQ=";
    }
    {
      name = "HaGeZi-native-winoffice";
      url = hagezi "hosts/native.winoffice.txt";
      hash = "sha256-MaOnx5TGt1+Vqr0gwL2Vk0zuBWWt2TH086JCImNTUoY=";
    }
    {
      name = "HaGeZi-native-tiktok-extended";
      url = hagezi "hosts/native.tiktok.extended.txt";
      hash = "sha256-3bWdSiho/HyGX2EfoIHRHM3e5DBypkJ/d9uTX/C0qXs=";
    }
    {
      name = "HaGeZi-gambling";
      url = hagezi "dnsmasq/gambling.txt";
      hash = "sha256-xaX+D0wAvQv0Yoed+ZYZUdT7GA9p7m0PlCjWOKtXjqA=";
    }
    {
      name = "HaGeZi-nsfw";
      url = hagezi "dnsmasq/nsfw.txt";
      hash = "sha256-7wDm+ASC5aShVy3+8olMZAx/E4Gf42TEDJ7V8Yhda+Q=";
    }
    {
      name = "HaGeZi-social";
      url = hagezi "dnsmasq/social.txt";
      hash = "sha256-xt3/An4lJkRi9uV+b/bZfTOPbf6aKeFjauUvmG0Ndvw=";
    }
    {
      name = "HaGeZi-dyndns";
      url = hagezi "dnsmasq/dyndns.txt";
      hash = "sha256-wH2UfOImj6U8hgsrddalsh/pgQX+5hexjkaXFy67+cA=";
    }
    {
      name = "HaGeZi-hoster";
      url = hagezi "dnsmasq/hoster.txt";
      hash = "sha256-3TfqZAH8+06Fp6AjuaHgo6LiXwQj3meBs6Fy1mQAu7M=";
    }
    {
      name = "HaGeZi-urlshortener";
      url = hagezi "dnsmasq/urlshortener.txt";
      hash = "sha256-ChCulrHnwdJlQfcchRF2WHwn5XoYL6kCukZHoQ2lN9g=";
    }
    {
      name = "HaGeZi-nosafesearch";
      url = hagezi "dnsmasq/nosafesearch.txt";
      hash = "sha256-r1KeVIFm3FeGASvj3aSzsuF+gflWTjLYo4wHsREwgOg=";
    }
    {
      name = "HaGeZi-dga7";
      url = hagezi "domains/dga7.txt";
      hash = "sha256-17A3rc92Ux1S8Kk/MvpqU4rYaIQ4rHX74ePSkdLkf2Y=";
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
