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
        # pbx.artmann.tech family (2026-10-19): services that run on the
        # Hetzner VPS from OTHER LarsArtmann repos (pbx-artmann deployment
        # flake + nix-international-telephony stack) — no SystemNix service
        # module owns them, so the platform registry is their catalog home
        # (same "what exists, deployed off-fleet" shape as auth). Zero
        # deployments is the honest state: the harvest only sees SystemNix
        # hosts; the descriptions carry the real location.
        pbx = {
          subdomain = null;
          description = "FreeSWITCH PBX at pbx.artmann.tech (nix-international-telephony telephony stack)";
        };
        pbx-lens = {
          subdomain = null;
          description = "Unified call-history index over FreeSWITCH CDRs, Telnyx, and receiver webhooks (pbx.artmann.tech)";
        };
        webphone = {
          subdomain = null;
          description = "Unified-communications web app: calls, messages, fax, voicemail, contacts (pbx.artmann.tech)";
        };
        mail-server = {
          subdomain = null;
          description = "Stalwart mail stack (SMTP/IMAP/JMAP/CardDAV) at mail.artmann.tech (nix-email) — CardDAV contacts are a mirror planned to be fed from Kith CRM (the contacts source of truth)";
        };
      };
    };
}
