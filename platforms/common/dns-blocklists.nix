let
  # GitHub repo hagezi/dns-blocklists is repeatedly locked by GitHub's fraud
  # detection. GitLab mirror is the primary reliable source.
  hagezi = subpath: "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/${subpath}";
in
{
  blocklists = [
    {
      name = "StevenBlack-everything";
      url = "https://raw.githubusercontent.com/StevenBlack/hosts/4a68876c7fc71ecd572ad74e491b75a52ef2d31b/alternates/fakenews-gambling-porn-social/hosts";
      hash = "sha256-62so0hxvFuvnt0attejVSkTEBScWLyY5i+6xvgFCIdk=";
    }
    {
      name = "HaGeZi-ultimate";
      url = hagezi "hosts/ultimate.txt";
      hash = "sha256-5HZC3sF3iPQ5F634YknL9aRmbUeQlu6ijZZL49l3zig=";
    }
    {
      name = "HaGeZi-tif";
      url = hagezi "hosts/tif.txt";
      hash = "sha256-pCkD3R7iGOyQfDwZIaeEzy1C09wWIcsgzUSBW6WlNAI=";
    }
    {
      name = "HaGeZi-doh";
      url = hagezi "hosts/doh.txt";
      hash = "sha256-/oo+Um4BjCup9d8vzY9heqCn8+ogYxaumbuMJ8JvG7w=";
    }
    {
      name = "HaGeZi-native-apple";
      url = hagezi "hosts/native.apple.txt";
      hash = "sha256-NAYdzfcADJF9y4CyOzN5kEbuyfDQgcvP1hVZmWGwbpU=";
    }
    {
      name = "HaGeZi-native-amazon";
      url = hagezi "hosts/native.amazon.txt";
      hash = "sha256-0P4PIz38EzFFHG6gKv5uADRDwhHev7ttrYJrk/5EzgU=";
    }
    {
      name = "HaGeZi-native-samsung";
      url = hagezi "hosts/native.samsung.txt";
      hash = "sha256-Ka1qQIyk6tIAYvzqKgeOy8sx4MdcRHUhk6fxEvR+IS0=";
    }
    {
      name = "HaGeZi-native-xiaomi";
      url = hagezi "hosts/native.xiaomi.txt";
      hash = "sha256-9IJfRloREHkQovSnZ0dv6RlN6HqsQSRJySquRPOaIP4=";
    }
    {
      name = "HaGeZi-native-huawei";
      url = hagezi "hosts/native.huawei.txt";
      hash = "sha256-mziWfMLCoyFshgFkp/Ld51hVC3SZbbkQR6JmEpGUh/w=";
    }
    {
      name = "HaGeZi-native-lgwebos";
      url = hagezi "hosts/native.lgwebos.txt";
      hash = "sha256-F0G724ZjjF7wQEDGjl/ucUi1b/9q4JNrNkiB282TYO8=";
    }
    {
      name = "HaGeZi-native-oppo-realme";
      url = hagezi "hosts/native.oppo-realme.txt";
      hash = "sha256-zg4LnhmstdbFt7MffZ9v20LYXceb2lW0n15XGulSsIA=";
    }
    {
      name = "HaGeZi-native-roku";
      url = hagezi "hosts/native.roku.txt";
      hash = "sha256-VdpKYQXSSXtzzJi1yNMNbwn4a9ihB9PwYnJsalKm6XU=";
    }
    {
      name = "HaGeZi-native-vivo";
      url = hagezi "hosts/native.vivo.txt";
      hash = "sha256-qV5QAZ+suzQVkxcTx7hBtJrInH9d342Z3CRcVX9P8rc=";
    }
    {
      name = "HaGeZi-native-winoffice";
      url = hagezi "hosts/native.winoffice.txt";
      hash = "sha256-PD4XDmGzMAHOviKdMBRNw35z3LS7nIfHOjae6vdxB9s=";
    }
    {
      name = "HaGeZi-native-tiktok-extended";
      url = hagezi "hosts/native.tiktok.extended.txt";
      hash = "sha256-BFB+gjbt/QIZJsvs7GhFCxo5znS7fygAVgEAcTzJcqo=";
    }
    {
      name = "HaGeZi-gambling";
      url = hagezi "dnsmasq/gambling.txt";
      hash = "sha256-PBgNcb4Vl7E0wi4439heYCyTN4JJHRxA4zT7eqUech8=";
    }
    {
      name = "HaGeZi-nsfw";
      url = hagezi "dnsmasq/nsfw.txt";
      hash = "sha256-DuyM6NOyZrnTNlUMR3UpJD92O3dBIXXyH6tlHfKAetg=";
    }
    {
      name = "HaGeZi-social";
      url = hagezi "dnsmasq/social.txt";
      hash = "sha256-9e+iETaU/bDVlIXwgneRTXtlCXQt4G5Diet0YE5jXiM=";
    }
    {
      name = "HaGeZi-dyndns";
      url = hagezi "dnsmasq/dyndns.txt";
      hash = "sha256-eD0RWCPSPVc0kCMO7EG3nAkN/tXyTMudts22s+ePfYk=";
    }
    {
      name = "HaGeZi-hoster";
      url = hagezi "dnsmasq/hoster.txt";
      hash = "sha256-/GP92ZgpgYJOicZ0vw+Z/Bpskm8Cw4DNglPgJDnDhA4=";
    }
    {
      name = "HaGeZi-urlshortener";
      url = hagezi "dnsmasq/urlshortener.txt";
      hash = "sha256-otvrTYgRNahDDU0MLoFEc/3sTXlB7V2wAWOlZrRrD6A=";
    }
    {
      name = "HaGeZi-nosafesearch";
      url = hagezi "dnsmasq/nosafesearch.txt";
      hash = "sha256-nzOtxGkQa0kHMKLXGlw+kCisK2LVFa3D2oagafr15f0=";
    }
    {
      name = "HaGeZi-dga7";
      url = hagezi "domains/dga7.txt";
      hash = "sha256-tLDK1Y1X0o11B449hy93jBnWeCYtkdHeB1UILa5MlEw=";
    }
  ];

  whitelist = [
    "mullvad.net"
    "api.immich.app"
    "immich.app"
    "github.com"
    "github-releases.githubusercontent.com"
    "objects.githubusercontent.com"
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
    "us.i.posthog.com"
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
