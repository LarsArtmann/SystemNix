# Central service-integration registry: ONE entry per service fans out to
# every cross-cutting surface a SystemNix service must plug into:
#
#   services.integration.<name> = {
#     subdomain = "rss";              # DNS guard + vHost hostname + tile href
#     port = ports.miniflux;          # vHost backend + relative health URLs
#     vHost.layer = "plain";          # "plain" (Layer 0/1) | "protected" (Layer 2)
#     checks = [ { ... } ];           # Gatus endpoints (auto Discord alerting)
#     homepage = { ... };             # dashboard tile
#     backup = { ... };               # backup-coordination freshness entry
#     monitored = true;               # system-health unit-state metrics
#     otel = { ... };                 # OTEL env + signoz-coverage registration
#     oidc = { ... };                 # Pocket ID client registration
#   };
#
# Service modules declare their entry inside their own `mkIf cfg.enable`
# block (a disabled service's entry vanishes). The fan-out below is guarded
# per consumer so a host importing only a subset of modules still evaluates.
#
# What still belongs ELSEWHERE (by design):
#   - the port itself: lib/ports.nix (the registry only consumes it)
#   - the DNS record: platforms/common/dns-local.nix — the shared file is the
#     cross-host truth (rpi3-dns serves the same list); this module ASSERTS
#     consistency so a forgotten entry fails `nix flake check` instead of
#     silently NXDOMAINing.
#   - the systemd unit, hardening, and sops secrets: the service module.
_: {
  flake.nixosModules.integration =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      cfg = config.services.integration;
      inherit (config.networking) domain;
      inherit (import ../../../lib/default.nix lib)
        mkHttpCheck
        discordAlert
        ports
        serviceTypes
        ;
      dnsLocalSubdomains = (import ../../../platforms/common/dns-local.nix).localSubdomains;

      enabledEntries = lib.filterAttrs (_: e: e.enable) cfg;

      unitOf = name: e: if e.unit != null then e.unit else name;

      vhostEntries = lib.filterAttrs (
        _: e: e.subdomain != null && e.port != null && e.vHost.layer != "none"
      ) enabledEntries;

      # Relative check URLs resolve against the entry's port; absolute URLs
      # (tcp://, https://, other hosts) pass through verbatim.
      checkUrl =
        name: e: check:
        if check.url != null then
          check.url
        else
          "http://127.0.0.1:${toString e.port}${check.path}";

      entryChecks = lib.concatLists (
        lib.mapAttrsToList (name: e: map (check: { inherit name e check; }) e.checks) enabledEntries
      );

      # Alerting is default-ON (AGENTS.md: every service must be monitored):
      # a check without an explicit alert description gets an auto-generated
      # one; set `alert = ""` explicitly for a deliberately silent check.
      checkAlert =
        name: e: check:
        if check.alert != null && check.alert != "" then
          discordAlert check.alert
        else if check.alert == "" then
          [ ]
        else if e.subdomain != null then
          discordAlert "${check.name} down — ${e.subdomain}.${domain} unreachable"
        else
          discordAlert "${check.name} (unit ${unitOf name e}) failed";

      otelEntries = lib.filterAttrs (_: e: e.otel != null) enabledEntries;

      otelEndpoint =
        shape:
        if shape == "grpc-url" then
          "http://localhost:${toString ports.signoz-otlp-grpc}"
        else if shape == "http-url" then
          "http://localhost:${toString ports.signoz-otlp-http}"
        else
          "localhost:${toString ports.signoz-otlp-http}";

      homepageTile =
        name: e:
        {
          name = e.homepage.name;
          inherit (e.homepage) group;
          href =
            if e.homepage.href != null then
              e.homepage.href
            else if e.subdomain != null then
              "https://${e.subdomain}.${domain}"
            else
              null;
          inherit (e.homepage) description icon;
        };

      backupEntries = lib.filterAttrs (_: e: e.backup != null) enabledEntries;
      monitoredEntries = lib.filterAttrs (_: e: e.monitored) enabledEntries;
      oidcEntries = lib.filterAttrs (_: e: e.oidc != null) enabledEntries;
    in
    {
      options.services.integration = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }:
            {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = ''
                    Whether this entry's fan-out is active. Service modules
                    typically define the whole entry inside `lib.mkIf cfg.enable`
                    instead; this switch covers entries declared unconditionally
                    (e.g. from configuration.nix).
                  '';
                };

                unit = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Systemd unit name for monitored/otel fan-out. Defaults to
                    the entry's attribute name.
                  '';
                };

                subdomain = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    DNS subdomain under networking.domain (served by dnsblockd
                    via platforms/common/dns-local.nix). MUST be listed there —
                    enforced by an eval-time assertion (rpi3-dns serves the same
                    shared list, so the file stays the cross-host truth).
                    Drives the vHost hostname and the homepage tile href.
                  '';
                };

                port = lib.mkOption {
                  type = lib.types.nullOr lib.types.port;
                  default = null;
                  description = "Backend port (from lib/ports.nix) for the vHost and relative check URLs";
                };

                vHost.layer = lib.mkOption {
                  type = lib.types.enum [
                    "plain"
                    "protected"
                    "none"
                  ];
                  default = "protected";
                  description = ''
                    "protected" = Layer 2 (oauth2-proxy forward-auth for
                    external clients, LAN bypass) — for apps without their own
                    auth. "plain" = Layer 0/1 direct reverse_proxy — LAN-only
                    UIs and apps with native OIDC (forward-auth would
                    double-auth). "none" = no vHost (DNS/homepage only).
                  '';
                };

                checks = lib.mkOption {
                  type = lib.types.listOf (
                    lib.types.submodule {
                      options = {
                        name = lib.mkOption {
                          type = lib.types.str;
                          description = "Gatus endpoint name";
                        };
                        group = lib.mkOption {
                          type = lib.types.str;
                          default = "Infrastructure";
                          description = "Gatus endpoint group";
                        };
                        path = lib.mkOption {
                          type = lib.types.str;
                          default = "/health";
                          description = "Path appended to the loopback URL when `url` is null";
                        };
                        url = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = ''
                            Absolute URL override (tcp://…, https://…, other
                            hosts). Defaults to
                            http://127.0.0.1:<entry.port><path>.
                          '';
                        };
                        interval = lib.mkOption {
                          type = lib.types.str;
                          default = "30s";
                          description = "Check interval (gatus duration)";
                        };
                        conditions = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ "[STATUS] == 200" ];
                          description = ''
                            Gatus conditions. Follow the AGENTS.md pat()
                            escape rules — `nix fmt`-surviving single-backslash
                            newlines, no ?/+ wildcards, anchored metric forms.
                          '';
                        };
                        alert = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = ''
                            Discord alert description. null = auto-generated
                            ("<name> down — <sub>.<domain> unreachable");
                            "" = deliberately silent check.
                          '';
                        };
                        client = lib.mkOption {
                          type = lib.types.attrs;
                          default = { };
                          description = "Gatus client settings (e.g. timeout)";
                        };
                        headers = lib.mkOption {
                          type = lib.types.attrs;
                          default = { };
                          description = "Extra request headers (e.g. auth)";
                        };
                      };
                    }
                  );
                  default = [ ];
                  description = "Gatus health/liveness checks for this service";
                };

                homepage = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.submodule {
                      options = {
                        name = lib.mkOption {
                          type = lib.types.str;
                          description = "Tile label";
                        };
                        group = lib.mkOption {
                          type = lib.types.str;
                          description = "Dashboard tab (existing name appends, new name opens a tab)";
                        };
                        href = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Link target; null derives https://<subdomain>.<domain>";
                        };
                        description = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Tile subtitle";
                        };
                        icon = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Icon from the bundled dashboard-icons pack";
                        };
                      };
                    }
                  );
                  default = null;
                  description = "Homepage dashboard tile";
                };

                backup = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.submodule {
                      options = {
                        directory = lib.mkOption {
                          type = lib.types.str;
                          description = "Directory containing backup files";
                        };
                        filePattern = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Glob pattern for backup files (default: *)";
                        };
                        maxAgeHours = lib.mkOption {
                          type = lib.types.int;
                          default = 25;
                          description = "Maximum age before the backup alerts as stale";
                        };
                      };
                    }
                  );
                  default = null;
                  description = "backup-coordination freshness entry (the service still owns its backup unit/timer)";
                };

                monitored = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Register the unit in system-health monitoredServices (state/restart/crash-loop metrics)";
                };

                otel = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.submodule {
                      options = {
                        serviceName = lib.mkOption {
                          type = lib.types.str;
                          description = "resource.service.name the binary reports to SigNoz";
                        };
                        shape = lib.mkOption {
                          type = lib.types.enum [
                            "grpc-url"
                            "http-url"
                            "http-host-port"
                          ];
                          description = ''
                            OTLP endpoint contract (must match the binary's
                            SDK — see otel-endpoint-audit): "http-host-port" =
                            Go otlptracehttp (host:4318, NO scheme);
                            "http-url" = Python/Node/Docker SDKs
                            (http://host:4318); "grpc-url" = Go otlptracegrpc /
                            Rust tonic (http://host:4317).
                          '';
                        };
                        maxAgeHours = lib.mkOption {
                          type = lib.types.int;
                          default = 26;
                          description = "Span freshness budget (event-driven services: 720)";
                        };
                      };
                    }
                  );
                  default = null;
                  description = "OTLP tracing wiring: sets OTEL_EXPORTER_OTLP_ENDPOINT on the unit and registers it in signoz-coverage + otel-endpoint-audit";
                };

                oidc = lib.mkOption {
                  type = lib.types.nullOr serviceTypes.oidcClientType;
                  default = null;
                  description = ''
                    Pocket ID OIDC client registration (native OIDC / Layer 1
                    services). The callback URLs MUST match the consumer's
                    redirect configuration byte-for-byte.
                  '';
                };
              };
            }
          )
        );
        default = { };
        description = "Service-integration registry: one entry per service, fanned out to Caddy/Gatus/Homepage/backup/monitoring/OTel/OIDC";
      };

      # Guard shape (both halves load-bearing, proven by probe):
      #   - `options ?` reads only DECLARATIONS, never values — a condition
      #     reading an option VALUE here (e.g. `<ns>.enable or false`)
      #     infinite-recurses through the very option being merged.
      #   - top-level `optionalAttrs` (NOT leaf-level mkIf) — a mkIf-wrapped
      #     definition of an UNDECLARED option is still collected and fails
      #     "option does not exist" on hosts importing a module subset.
      #   - branches combine via mkMerge, NEVER `//` — every branch carries
      #     the top-level `services` key, and `//` is SHALLOW: a chain keeps
      #     only the LAST branch's services subtree, silently dropping every
      #     earlier fan-out (the serviceConfig = X // Y class at module-config
      #     level; caught live 2026-09-14 when only the pocket-id branch fired).
      config =
        lib.mkMerge [
        {
          assertions =
            let
              dnsMissing =
                e: e.enable && e.subdomain != null && !builtins.elem e.subdomain dnsLocalSubdomains;
              vhostIncomplete =
                e: e.enable && e.vHost.layer != "none" && (e.subdomain == null || e.port == null);
              checkWithoutPort =
                e: e.enable && builtins.any (c: c.url == null) e.checks && e.port == null;
            in
            [
              {
                assertion = lib.all (e: !dnsMissing e) (builtins.attrValues cfg);
                message = "integration: subdomain(s) missing from platforms/common/dns-local.nix (the cross-host DNS truth served by dnsblockd AND rpi3-dns): ${
                  lib.concatStringsSep ", " (map (e: e.subdomain) (builtins.filter dnsMissing (builtins.attrValues cfg)))
                }";
              }
              {
                assertion = lib.all (e: !vhostIncomplete e) (builtins.attrValues cfg);
                message = "integration: vHost layer != none requires BOTH subdomain and port: ${
                  lib.concatStringsSep ", " (lib.attrNames (lib.filterAttrs (_: vhostIncomplete) cfg))
                }";
              }
              {
                assertion = lib.all (e: !checkWithoutPort e) (builtins.attrValues cfg);
                message = "integration: relative-path checks need the entry's port: ${
                  lib.concatStringsSep ", " (lib.attrNames (lib.filterAttrs (_: checkWithoutPort) cfg))
                }";
              }
            ];

          systemd.services = lib.mapAttrs' (
            name: e:
            lib.nameValuePair (unitOf name e) {
              environment.OTEL_EXPORTER_OTLP_ENDPOINT = otelEndpoint e.otel.shape;
            }
          ) otelEntries;
        }
        // (lib.optionalAttrs (options ? services.caddy-config) {
          # Keyed by SUBDOMAIN (caddy renders <key>.<domain>) — duplicate
          # subdomains across entries collide loudly here by design.
          services.caddy-config.extraVHosts = lib.mapAttrs' (
            _: e:
            lib.nameValuePair e.subdomain {
              inherit (e) port;
              inherit (e.vHost) layer;
            }
          ) vhostEntries;
        })
        // (lib.optionalAttrs (options ? services.gatus-config) {
          services.gatus-config.extraEndpoints = map (
            { name, e, check }:
            mkHttpCheck {
              inherit (check) name group interval conditions;
              url = checkUrl name e check;
              alerts = checkAlert name e check;
            }
            // lib.optionalAttrs (check.client != { }) { inherit (check) client; }
            // lib.optionalAttrs (check.headers != { }) { inherit (check) headers; }
          ) entryChecks;
        })
        // (lib.optionalAttrs (options ? services.homepage) {
          services.homepage.extraTiles = lib.mapAttrsToList homepageTile (
            lib.filterAttrs (_: e: e.homepage != null) enabledEntries
          );
        })
        // (lib.optionalAttrs (options ? services.backup-coordination) {
          services.backup-coordination.backups = lib.mapAttrs (_: e: e.backup) backupEntries;
        })
        // (lib.optionalAttrs (options ? services.system-health) {
          services.system-health.extraMonitoredServices = lib.mapAttrsToList unitOf monitoredEntries;
        })
        # Registry keys are UNIT names (the signoz-coverage reverse assertion
        # maps units that set the OTLP env var to expected keys), not entry
        # names — honor the unit override.
        (lib.optionalAttrs (options ? services.signoz-coverage) {
          services.signoz-coverage.expected = lib.mapAttrs' (
            name: e:
            lib.nameValuePair (unitOf name e) {
              serviceName = e.otel.serviceName;
              wiring = "env";
              maxAgeHours = e.otel.maxAgeHours;
            }
          ) otelEntries;
        })
        // (lib.optionalAttrs (options ? services.otel-endpoint-audit) {
          services.otel-endpoint-audit.expectations = lib.mapAttrs' (
            name: e: lib.nameValuePair (unitOf name e) e.otel.shape
          ) otelEntries;
        })
        // (lib.optionalAttrs (options ? services.pocket-id-config) {
          services.pocket-id-config.provision.extraOidcClients = lib.mapAttrsToList (_: e: e.oidc) oidcEntries;
        });
    };
}
