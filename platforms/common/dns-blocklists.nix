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
      hash = "sha256-JjT81Ya22Fm1FRao/iodzZRduZ2ptECLzQcnlnlwATg=";
    }
    {
      name = "HaGeZi-tif";
      url = hagezi "hosts/tif.txt";
      hash = "sha256-swzsG8Q6MUzHk0UynktGLAbnu+/4FacmGRs1n9IaeDU=";
    }
    {
      name = "HaGeZi-doh";
      url = hagezi "hosts/doh.txt";
      hash = "sha256-ERTWIn4wzgbdLXifYmMkD0c95Bsj4Y1Rt4roU5RoLhI=";
    }
    {
      name = "HaGeZi-native-apple";
      url = hagezi "hosts/native.apple.txt";
      hash = "sha256-RTK5WhFc1sWnutDkRy+Lfcj8ys5SjFnFLi7c2Xn8qp4=";
    }
    {
      name = "HaGeZi-native-amazon";
      url = hagezi "hosts/native.amazon.txt";
      hash = "sha256-fOdp2YbyP8Hl8wlBsCid1pZaJ8XDJ2m1Oa57mTLecs0=";
    }
    {
      name = "HaGeZi-native-samsung";
      url = hagezi "hosts/native.samsung.txt";
      hash = "sha256-Y/07IH5SYyD24eJnfd18Yjm90MAzPIffIrA+x6jtBQk=";
    }
    {
      name = "HaGeZi-native-xiaomi";
      url = hagezi "hosts/native.xiaomi.txt";
      hash = "sha256-0TFOOSW6kOos8huTq/iZpyTAJbDgZ9X0CsHoxDuk4Bc=";
    }
    {
      name = "HaGeZi-native-huawei";
      url = hagezi "hosts/native.huawei.txt";
      hash = "sha256-S0Twsy6KDuMj/VFp3U/SwxpjdUXklLJLq0881GESGrc=";
    }
    {
      name = "HaGeZi-native-lgwebos";
      url = hagezi "hosts/native.lgwebos.txt";
      hash = "sha256-xlLWC2zGSxIrhLMNgqh75TR5zMQaUuIN5XVrb6of1rU=";
    }
    {
      name = "HaGeZi-native-oppo-realme";
      url = hagezi "hosts/native.oppo-realme.txt";
      hash = "sha256-26DbGxOGeByNCAOgOh1ur866t4uySYCh2ZZ46sb7OHs=";
    }
    {
      name = "HaGeZi-native-roku";
      url = hagezi "hosts/native.roku.txt";
      hash = "sha256-VdpKYQXSSXtzzJi1yNMNbwn4a9ihB9PwYnJsalKm6XU=";
    }
    {
      name = "HaGeZi-native-vivo";
      url = hagezi "hosts/native.vivo.txt";
      hash = "sha256-OUJ4QLR5+xVqBkv8PYL7X/bqmAK7DZ15B3acvZ+pxlU=";
    }
    {
      name = "HaGeZi-native-winoffice";
      url = hagezi "hosts/native.winoffice.txt";
      hash = "sha256-3jS4KyRtMlW6E0mLYUoQw7HvrFFztq6q/8qlrWY6dE0=";
    }
    {
      name = "HaGeZi-native-tiktok-extended";
      url = hagezi "hosts/native.tiktok.extended.txt";
      hash = "sha256-R1UpS94d4+pEsczgMjrjjPtTgbYktLR/TFuKQ+nOiw8=";
    }
    {
      name = "HaGeZi-gambling";
      url = hagezi "dnsmasq/gambling.txt";
      hash = "sha256-SdRIIG4hk63dBLJwiZnQFT4d1CoovHNjG4k6DXu9z/g=";
    }
    {
      name = "HaGeZi-nsfw";
      url = hagezi "dnsmasq/nsfw.txt";
      hash = "sha256-KrXVSWdf50156NM33EhPSs6ZdBVodUSQ/H7TADNdDJg=";
    }
    {
      name = "HaGeZi-social";
      url = hagezi "dnsmasq/social.txt";
      hash = "sha256-3x+v+iF8tlw2F2K4toILHAeN5Hw38XDShVjGitxqeN4=";
    }
    {
      name = "HaGeZi-dyndns";
      url = hagezi "dnsmasq/dyndns.txt";
      hash = "sha256-apxCgp6kwifCEQ8tsb13D6mvDhs8E9H85aRii9FCnWc=";
    }
    {
      name = "HaGeZi-hoster";
      url = hagezi "dnsmasq/hoster.txt";
      hash = "sha256-pmY+wjiGWPhK9C0xyOPcaH0DoituEzaJ9CiY3n8n54o=";
    }
    {
      name = "HaGeZi-urlshortener";
      url = hagezi "dnsmasq/urlshortener.txt";
      hash = "sha256-jX9phBZWPfXT2XK9ndCnZqeY/JDdV2sEolxIHSp1Y+U=";
    }
    {
      name = "HaGeZi-nosafesearch";
      url = hagezi "dnsmasq/nosafesearch.txt";
      hash = "sha256-t6+r+8Y15MSk/3qaTTwAu2X6KeuMg4WMHFcMKiNdAGY=";
    }
    {
      name = "HaGeZi-dga7";
      url = hagezi "domains/dga7.txt";
      hash = "sha256-JMiR3fdmsM5SSl0YKpxS9BXz9DtQRJqttIRH03zW3Sw=";
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
