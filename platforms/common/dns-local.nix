{
  localSubdomains = [
    "auth"
    "immich"
    "paperless"
    "forgejo"
    "dash"
    "signoz"
    "tasks"
    "crm"
    "status"
    "seo"
    "daily"
    "logs"
    "monitor"
    "discordsync"
    "overview"
    "renamer"
    "history"
    "alerts"
    "dnsblock"
    "dnsblockd"
    "search"
    "cache"
    "banksync"
    "graph"
    "timers"
    "cv"
    "inbox"
    "tq"
    "rss"
    "mr-sync"
    "geo"
    "health"
    "catalog"
    "nsfw"
    "index"
    "emeet-pixyd"
    "llama"
  ];

  # Public hosts living UNDER the split-horizon cloud zone. dnsblockd is
  # AUTHORITATIVE for larsartmann.cloud (localZones in dns-blocker-config.nix
  # and rpi3/default.nix), so any cloud-zone name without an explicit local
  # record NXDOMAINs locally even when a public record exists. Discovered
  # 2026-10-02: netbird.larsartmann.cloud + relay.larsartmann.cloud (NetBird
  # control plane on pbx, 46.62.241.133) resolved via public resolvers but
  # NXDOMAINed from BOTH evo-x2 and rpi3 — which would have broken phase-1
  # client enrollment (management URL), the phase-1 DNS nameserver group
  # (VPN clients would query rpi3), and any hostname-based monitoring from
  # the LAN. Explicit records are the only override (sdns ignores wildcard
  # local records — gotchas-archive.md). Guarded by tests/test-cloud-domain.nix.
  cloudPublicRecords = {
    netbird = "46.62.241.133";
    relay = "46.62.241.133";
    # The pbx Pocket ID (pbx-artmann SSO, 2026-10-12). Same shadow class as
    # netbird/relay but with a twist: "auth" is ALSO a localSubdomain (the
    # evo-x2 Pocket ID at auth.home.lan), so the alias zone maps
    # auth.larsartmann.cloud -> evo-x2 — where nothing serves that origin —
    # while the public record points at the pbx. LAN/VPN browsers would hit
    # the wrong box and every pbx gate login from the LAN dies (found
    # 2026-10-12, TODO §38 row 1). cloudPublicRecords wins over the alias
    # zone (the // chain in dns-blocker-config.nix), so this entry repoints
    # the cloud name at the pbx IdP without touching auth.home.lan.
    auth = "46.62.241.133";
  };
}
