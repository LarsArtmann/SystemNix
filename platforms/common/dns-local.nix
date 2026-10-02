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
  };
}
