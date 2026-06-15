let
  hageziRev = "489ce87162a4824080b8ab3fb4db7c8ea65fd38c";
  hagezi = subpath: "https://raw.githubusercontent.com/hagezi/dns-blocklists/${hageziRev}/${subpath}";
in {
  blocklists = [
    {
      name = "StevenBlack-everything";
      url = "https://raw.githubusercontent.com/StevenBlack/hosts/4a68876c7fc71ecd572ad74e491b75a52ef2d31b/alternates/fakenews-gambling-porn-social/hosts";
      hash = "sha256-62so0hxvFuvnt0attejVSkTEBScWLyY5i+6xvgFCIdk=";
    }
    {
      name = "HaGeZi-ultimate";
      url = hagezi "hosts/ultimate.txt";
      hash = "sha256-OoS3W2QCVqihKgUCRnhqNHruEEs8yCyx52mV8kMlwuw=";
    }
    {
      name = "HaGeZi-tif";
      url = hagezi "hosts/tif.txt";
      hash = "sha256-u54bw4tUl3ijuTpvc9AJ/l63fDk1u4fzCSwsl0pgv1A=";
    }
    {
      name = "HaGeZi-doh";
      url = hagezi "hosts/doh.txt";
      hash = "sha256-7ebNwvozNmdinyLhyNVtySiBccq+fxVE7V/Szl+DMAI=";
    }
    {
      name = "HaGeZi-native-apple";
      url = hagezi "hosts/native.apple.txt";
      hash = "sha256-+dHB5Kfp91Ry2k+5cyargGa78MZY4nEW68bYnJN7O+Q=";
    }
    {
      name = "HaGeZi-native-amazon";
      url = hagezi "hosts/native.amazon.txt";
      hash = "sha256-Wi503RglqMUysJi0XvSvDsSVuT/dZIzr8oauMzU/WPg=";
    }
    {
      name = "HaGeZi-native-samsung";
      url = hagezi "hosts/native.samsung.txt";
      hash = "sha256-jpMOvnPRyULJM074mgsH4ynwnq2ZLOGDBE3ac8IMQk8=";
    }
    {
      name = "HaGeZi-native-xiaomi";
      url = hagezi "hosts/native.xiaomi.txt";
      hash = "sha256-Y9P9vA7baXSn9BHRaXd2XUxxaz3tZss0G9x4zMPbWJ4=";
    }
    {
      name = "HaGeZi-native-huawei";
      url = hagezi "hosts/native.huawei.txt";
      hash = "sha256-Q5Cxf6BZqW4uTTZxZpc/LNj6qFjXAv8GxGFyWIdw+Yw=";
    }
    {
      name = "HaGeZi-native-lgwebos";
      url = hagezi "hosts/native.lgwebos.txt";
      hash = "sha256-cafJx9WcUVh5FV0rX60Po81K136oos8LHrNAz6BtBkA=";
    }
    {
      name = "HaGeZi-native-oppo-realme";
      url = hagezi "hosts/native.oppo-realme.txt";
      hash = "sha256-NyISSegOut0RUqZAnzTlj0UUW9gAsY+Eu2wQWlqflE4=";
    }
    {
      name = "HaGeZi-native-roku";
      url = hagezi "hosts/native.roku.txt";
      hash = "sha256-hAiQ5KVJDnsV/t+iuNhzDfjTbexdZsO3ab/Hcs49/Po=";
    }
    {
      name = "HaGeZi-native-vivo";
      url = hagezi "hosts/native.vivo.txt";
      hash = "sha256-dfFXeTZM85SoguEoGeuRbQVSKs4WbDsDNyUcItydIes=";
    }
    {
      name = "HaGeZi-native-winoffice";
      url = hagezi "hosts/native.winoffice.txt";
      hash = "sha256-QwdJlCi8gBubVJh4933VyH+PLRdw6BtmEAA6Gkbp4ms=";
    }
    {
      name = "HaGeZi-native-tiktok-extended";
      url = hagezi "hosts/native.tiktok.extended.txt";
      hash = "sha256-j72mjZ4pRTycOaAFusE5EEZgxrgp48yWnoeEXqRe94U=";
    }
    {
      name = "HaGeZi-gambling";
      url = hagezi "dnsmasq/gambling.txt";
      hash = "sha256-JOoNLq0OS8m7Lva2QePwOR5ICwzTac/XG4QElpwi8Gw=";
    }
    {
      name = "HaGeZi-nsfw";
      url = hagezi "dnsmasq/nsfw.txt";
      hash = "sha256-TActmblumABB35WCJOKwTP185nfhoZvIR71wtf2+LOU=";
    }
    {
      name = "HaGeZi-social";
      url = hagezi "dnsmasq/social.txt";
      hash = "sha256-vMrmq+Fzf+dxGB1AbaVD1dQWlvgU1rao78wRqk1ZxW4=";
    }
    {
      name = "HaGeZi-dyndns";
      url = hagezi "dnsmasq/dyndns.txt";
      hash = "sha256-XcKCT5e9YWAVGsAT9DZL4b/UgfDMkyhdia11CTYx+SU=";
    }
    {
      name = "HaGeZi-hoster";
      url = hagezi "dnsmasq/hoster.txt";
      hash = "sha256-TTl1Vw6ErGODGNvFA+REKZcA1toGLwK3CD8aR+MDxTg=";
    }
    {
      name = "HaGeZi-urlshortener";
      url = hagezi "dnsmasq/urlshortener.txt";
      hash = "sha256-iA7ZBaE0gdeorypEuES8tn+5aNgOKPe5i1Xc+fYtEaM=";
    }
    {
      name = "HaGeZi-nosafesearch";
      url = hagezi "dnsmasq/nosafesearch.txt";
      hash = "sha256-4/jcX6mM/6uyM4coCDQ/ANO6TAodZSSFsODqiUVOHIg=";
    }
    {
      name = "HaGeZi-dga7";
      url = hagezi "domains/dga7.txt";
      hash = "sha256-HYd05cvN2QSFgfdtPxmiHyJHQeCYuIEzcz6bfVH/dUA=";
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
    "licdn.com"
    "linktr.ee"
    "nominatim.openstreetmap.org"
    "tile.openstreetmap.org"
    "huggingface.co"
    "hf.co"
    "cdn-lfs.huggingface.co"
    "cdn-lfs-us-1.huggingface.co"
    "discord.gg"
    "discord.com"
    "gateway.discord.gg"
    "us.i.posthog.com"
    "movieffm.net"
    "www.movieffm.net"
    "deref-mail.com"
    "wbby.co"
    "9gag.com"
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

  localSubdomains = [
    "auth"
    "immich"
    "forgejo"
    "dash"
    "signoz"
    "tasks"
    "crm"
    "manifest"
    "status"
    "seo"
    "daily"
    "logs"
    "monitor"
  ];
}
