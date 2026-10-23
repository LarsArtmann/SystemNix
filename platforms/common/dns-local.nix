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
  # NOT a closed boundary since 2026-10-23: the cloud zone rides alias twin
  # records (Unbound local-data semantics hold regardless of zone
  # registration) + FORWARDING for unknown names (local-zone "transparent",
  # offline-proven against the live engine) — the closed-zone NXDOMAIN burn
  # class (2026-10-02 netbird/relay, 2026-10-12 auth) and the live MX defect
  # died with the boundary. See dns-blocker-config.nix for the full policy.
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
