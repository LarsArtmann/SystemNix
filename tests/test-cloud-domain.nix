# Pure-eval regression test for the split-horizon cloud domain
# (larsartmann.cloud alias zone — brainstorming 2026-09-30). Asserted against
# the REAL evo-x2 + rpi3-dns configurations (inputs.self) — no stubs, so this
# also guards the integrated host eval, not an isolated reconstruction.
#
#   1. dnsblockd serves BOTH zones on BOTH DNS hosts; every subdomain has a
#      cloud twin record (no wildcard — sdns ignores them).
#   2. Caddy mirrors every home.lan vHost under the cloud domain, plus a
#      cloud catch-all redirecting to the cloud dashboard.
#   3. TLS comes from the boot-minted dual-zone cert: vHosts reference
#      /run/dnsblockd-certs, the mint unit exists, orders itself before
#      Caddy, after sops-nix, and its SAN list covers both zones.
#   4. oauth2-proxy whitelists the cloud domain (post-login redirects from
#      *.larsartmann.cloud origins must pass the whitelist gate).
#   5. The NetBird client stays gated OFF (Phase 2 delivers the setup key)
#      and its port is registered in lib/ports.nix.
{
  pkgs,
  inputs,
  ...
}:
let
  home = "home.lan";
  cloud = "larsartmann.cloud";
  subdomains = (import ../platforms/common/dns-local.nix).localSubdomains;
  ports = (import ../lib/ports.nix).ports;

  evox2 = inputs.self.nixosConfigurations.evo-x2.config;
  rpi3 = inputs.self.nixosConfigurations.rpi3-dns.config;

  dnsRecords = evox2.services.dns-blocker.localRecords;
  zones = evox2.services.dns-blocker.localZones;
  vhosts = evox2.services.caddy.virtualHosts;
  mint = evox2.systemd.services.dnsblockd-cert-mint;
  tls = vhosts."auth.${home}".extraConfig;

  missingDnsRecords = builtins.filter (s: !dnsRecords ? "${s}.${cloud}.") subdomains;
  mirroredFrom = builtins.filter (s: vhosts ? "${s}.${home}" && !vhosts ? "${s}.${cloud}") subdomains;
  rpi3MissingCloud = builtins.filter (
    s: !rpi3.services.dns-blocker.localRecords ? "${s}.${cloud}."
  ) subdomains;
  rpi3ZonesOk =
    rpi3.services.dns-blocker.localZones == [
      "${home}."
      "${cloud}."
    ];

  checks = [
    {
      ok =
        zones == [
          "${home}."
          "${cloud}."
        ];
      msg = "evo-x2 dnsblockd localZones must contain both zones";
    }
    {
      ok = missingDnsRecords == [ ];
      msg = "subdomains missing cloud DNS records: ${toString missingDnsRecords}";
    }
    {
      ok = rpi3MissingCloud == [ ] && rpi3ZonesOk;
      msg = "rpi3-dns failover parity broken: missing ${toString rpi3MissingCloud}";
    }
    {
      ok = mirroredFrom == [ ];
      msg = "home.lan vHosts without cloud mirror: ${toString mirroredFrom}";
    }
    {
      ok = vhosts ? "https://*.${cloud}";
      msg = "cloud catch-all vHost missing";
    }
    {
      ok = builtins.match ".*tls /run/dnsblockd-certs/server.crt.*" tls != null;
      msg = "vHosts do not reference the minted dual-zone cert";
    }
    {
      ok = mint != null && builtins.elem "caddy.service" mint.before;
      msg = "dnsblockd-cert-mint not ordered before caddy";
    }
    {
      ok = mint != null && builtins.elem "sops-nix.service" mint.after;
      msg = "dnsblockd-cert-mint must start after sops-nix (reads CA secrets)";
    }
    {
      ok = mint != null && builtins.match ".*DNS:\\*\\.${cloud}.*" (mint.script or "") != null;
      msg = "mint SAN list does not cover *.${cloud}";
    }
    {
      ok = builtins.elem ".${cloud}" (evox2.services.oauth2-proxy.extraConfig.whitelist-domain or [ ]);
      msg = "oauth2-proxy whitelist missing the cloud domain";
    }
    {
      ok = !(evox2.services.netbird-client.enable or true);
      msg = "netbird client must stay gated off until Phase 2";
    }
    {
      # Positive surface probe: the pinned nixpkgs client module shape
      # (services.netbird.clients.<name> + login.setupKeyFile) must accept
      # the gated config when enabled — catches option renames that a
      # disabled mkIf would silently hide.
      ok =
        let
          enabled =
            (inputs.self.nixosConfigurations.evo-x2.extendModules {
              modules = [ { services.netbird-client.enable = true; } ];
            }).config;
        in
        enabled.services.netbird.clients ? evox2
        && enabled.services.netbird.clients.evox2.port == ports.netbird
        && (enabled.systemd.services ? "netbird-evox2-login");
      msg = "netbird client module surface mismatch (services.netbird.clients)";
    }
    {
      ok = ports.netbird == 51820;
      msg = "netbird port not registered in lib/ports.nix";
    }
  ];

  failed = builtins.filter (c: !c.ok) checks;
in
if failed != [ ] then
  pkgs.runCommand "cloud-domain-test" { } ''
    echo "cloud-domain regression failures:"
    ${builtins.concatStringsSep "\n" (map (c: "echo ' - ${c.msg}'") failed)}
    exit 1
  ''
else
  pkgs.runCommand "cloud-domain-test" { } ''
    echo "split-horizon cloud domain: DNS both hosts, Caddy mirror, dual-zone cert, oauth2 whitelist, gated netbird OK" > $out
  ''
