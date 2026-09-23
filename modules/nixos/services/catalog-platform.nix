# Catalog entries for services whose RUNTIME wiring is still hand-written
# in caddy.nix (the T15-T19 migration debt): they exist and serve the LAN,
# so the catalog must describe them — but no service module owns them yet.
# Each entry moves into its owning module when the vHost is migrated.
#
# alerts is DNS-only on purpose: it is a legacy PapDashboard alias kept so
# old bookmarks resolve; the wildcard catch-all redirects it to dash.
_: {
  flake.nixosModules.catalog-platform =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib) ports;
    in
    {
      # optionalAttrs wraps the WHOLE config module (leaf-level guard-shape
      # trap: an empty services.catalog attrset is still a definition and
      # fails "option does not exist" on hosts without catalog.nix).
      services.catalog = lib.optionalAttrs (options ? services.catalog) {
        auth = {
          subdomain = "auth";
          port = ports.pocket-id;
          description = "Pocket ID — passkey OIDC provider (SSO sign-in)";
        };
        dnsblock = {
          subdomain = "dnsblock";
          description = "dnsblockd admin UI redirect alias";
        };
        dnsblockd = {
          subdomain = "dnsblockd";
          description = "dnsblockd — LAN resolver, block pages, stats API";
        };
        alerts = {
          subdomain = "alerts";
          description = "Legacy dashboard alias (wildcard catch-all → dash)";
        };
        tasks = {
          subdomain = "tasks";
          port = ports.taskchampion;
          description = "Taskchampion sync server (tasks UI backend)";
        };
        seo = {
          subdomain = "seo";
          port = ports.openseo;
          description = "OpenSEO toolkit (GSC callback exempt from forward-auth)";
        };
      };
    };
}
