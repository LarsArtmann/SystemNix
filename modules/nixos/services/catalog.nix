# Platform service catalog: the host-independent "what exists" registry.
#
#   services.catalog.<name> = {
#     subdomain = "rss";        # DNS name under networking.domain (the
#                               # source for dnsblockd localRecords)
#     port = ports.miniflux;    # backend port (informational; the port
#                               # allocator stays lib/ports.nix)
#     owner = "lars";           # accountable owner (mesh contract)
#     description = "…";        # one line, human-readable
#     healthPath = "/health";   # readiness probe path, null = none
#   };
#
# The catalog answers "what EXISTS on this platform" — in contrast to
# services.integration ("what RUNS here", declared inside each service
# module's mkIf cfg.enable). Catalog entries are therefore declared
# UNCONDITIONALLY by their service modules (an inline `imports` module next
# to the integration entry keeps that guard-shaped and surgical), so every
# host that imports the module set sees the full platform surface. This is
# the D1 decision of ADR-008: the DNS hand-list
# (platforms/common/dns-local.nix) derives from here instead of drifting.
#
# Entries may exist without a matching integration entry (declared-but-
# never-run services, and the hand-wired caddy vHosts awaiting T15-T19);
# an integration entry with a subdomain WITHOUT a catalog entry is the
# drift direction the cross-check warning/assertion hunts.
{ lib, ... }:
{
  flake.nixosModules.catalog =
    { config, lib, options, ... }:
    {
      options.services.catalog = lib.mkOption {
        description = ''
          Platform service catalog: one unconditional entry per service,
          declaring existence (subdomain, port, owner, description,
          healthPath). Derived consumers: dnsblockd localRecords (both DNS
          hosts), the integration cross-check, and later mesh product
          contracts. See ADR-008.
        '';
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              subdomain = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "DNS subdomain under networking.domain; null = no DNS presence.";
              };

              port = lib.mkOption {
                type = lib.types.nullOr lib.types.port;
                default = null;
                description = "Backend port (from lib/ports.nix); informational.";
              };

              owner = lib.mkOption {
                type = lib.types.str;
                default = "lars";
                description = "Accountable owner (mesh product contract).";
              };

              description = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "One-line human-readable description.";
              };

              healthPath = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Readiness probe path served by the service; null = none.";
              };
            };
          }
        );
        default = { };
      };

      # Cross-check (T04), guard-shaped per doctrine: the whole branch is
      # optionalAttrs on the integration DECLARATION (never read its values
      # in a condition here); inside, values are plain config reads.
      #
      # MIGRATION (plan T03-T06): only exemplar modules + the hand-wired
      # platform entries declare catalog entries so far, so this surfaces
      # as a WARNING LIST; it hardens into an assertion in the same change
      # that populates every module, derives localRecords from the catalog,
      # and deletes the hand-list.
      config = lib.optionalAttrs (options ? services.integration) {
        warnings =
          let
            catalogSubdomains = lib.catAttrs "subdomain" (
              lib.attrValues (lib.filterAttrs (_: e: e.subdomain != null) config.services.catalog)
            );
            enabledIntegration = lib.filterAttrs (_: e: e.enable) config.services.integration;
            missing = builtins.filter (
              e: e.subdomain != null && !(builtins.elem e.subdomain catalogSubdomains)
            ) (builtins.attrValues enabledIntegration);
          in
          lib.optional (missing != [ ])
            "catalog: integration subdomain(s) without catalog entries — they will vanish from derived DNS once platforms/common/dns-local.nix is deleted: ${
              lib.concatStringsSep ", " (map (e: e.subdomain) missing)
            }";
      };
    };
}
