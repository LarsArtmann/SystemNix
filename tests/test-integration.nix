# Regression test for the services.integration registry fan-out (pure eval,
# test-sops-key-audit pattern — no VM needed: every fan-out surface is an
# eval-time product; the homepage yaml is a real derivation we grep).
#
# Proves, against the REAL consumer modules (caddy/gatus-config/homepage/
# system-health/backup-coordination/signoz-coverage/otel-endpoint-audit/
# pocket-id):
#   1. A registry entry fans out to every surface with the right shapes.
#   2. The DNS-consistency assertion fires on an unregistered subdomain.
#   3. The unit override is honored everywhere units are keyed (monitored,
#      signoz-coverage.expected, otel-endpoint-audit.expectations).
#   4. The rendered homepage services.yaml actually contains the tile.
#   5. Alerting semantics: explicit description passes through, "" is silent,
#      null auto-generates one.
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;

  # Wrapper modules are flake-parts modules — `_: { flake.nixosModules.X = …; }`
  # functions — while a few are plain attrsets; handle both shapes.
  mod =
    file: name:
    let
      imported = import ../modules/nixos/services/${file};
      wrapper = if builtins.isFunction imported then imported { } else imported;
    in
    wrapper.flake.nixosModules.${name};

  # Minimal stubs for options the real consumer modules read unconditionally
  # from siblings that are NOT part of this test's import set (test-paperless
  # precedent — cheaper than importing the full sibling closure).
  stubs = {
    networking.local.subnet = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.0/24";
    };
    services.oauth2-proxy-config.port = lib.mkOption {
      type = lib.types.port;
      default = 4180;
    };
    services.dns-blocker.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    services.dns-blocker.blockInterface = lib.mkOption {
      type = lib.types.str;
      default = "lo";
    };
    # caddy.nix / gatus-config.nix / homepage.nix / system-health.nix read
    # these sibling services' enable UNGUARDED (they are always co-imported on
    # evo-x2); stub them so the test import stays light. Generated from:
    #   grep -oE "config\.services\.[a-zA-Z0-9_-]+\.enable" <imported modules> | grep -v "or false"
    services.browser-history.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    services.monitor365.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    services.monitor365-server.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    services.voice-agents.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    services.discordsync.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    services.papdashboard.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    services.overview.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    services.file-and-image-renamer.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };


  # Bulk `.enable` stubs for sibling namespaces read unguarded by the real
  # consumer modules (all default false — the test enables none of them).
  enableStubs =
    names:
    {
      # Nested option paths — a flat "services.<n>.enable" STRING key would
      # declare a literally-named option, not the path config reads.
      services = lib.listToAttrs (
        map (
          n:
          lib.nameValuePair n {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
          }
        ) names
      );
    };

  siblingEnableStubs = enableStubs [
    "ai-stack"
    "attic-config"
    "bank-sync"
    "buildcache"
    "browser-history"
    "crush-daily"
    "cv-server"
    "discordsync"
    "fastflowlm"
    "file-and-image-renamer"
    "google-sync"
    "hermes"
    "inboxclean"
    "llama-rag"
    "mail-relay"
    "manifest"
    "monitor365"
    "monitor365-server"
    "overview"
    "papdashboard"
    "pool-recovery"
    "pool-smart-metrics"
    "projects-management-automation"
    "signoz"
    "systemd-graph"
    "systemd-timer-monitor"
    "tq-agent-pool"
    "twenty"
    "voice-agents"
  ];

  # Port-shaped options the UNCONDITIONAL caddy base vHosts force
  # (signoz/twenty/taskchampion/manifest/openseo/crush-daily/dns-blockd ports).
  portStubs = {
    services.signoz.settings.queryService.port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
    services.signoz.settings.cadvisorPort = lib.mkOption {
      type = lib.types.port;
      default = 8087;
    };
    services.twenty.port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
    };
    services.manifest.port = lib.mkOption {
      type = lib.types.port;
      default = 8083;
    };
    services.openseo.port = lib.mkOption {
      type = lib.types.port;
      default = 8084;
    };
    services.crush-daily.port = lib.mkOption {
      type = lib.types.port;
      default = 8085;
    };
    services.dns-blocker.statsPort = lib.mkOption {
      type = lib.types.port;
      default = 8086;
    };
    services.dns-blocker.blockIP = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };
  };

  baseModules = [
    inputs.sops-nix.nixosModules.sops
    (mod "caddy.nix" "caddy")
    (mod "gatus-config.nix" "gatus-config")
    (mod "homepage.nix" "homepage")
    (mod "system-health.nix" "system-health")
    (mod "backup-coordination.nix" "backup-coordination")
    (mod "signoz-coverage.nix" "signoz-coverage")
    (mod "otel-endpoint-audit.nix" "otel-endpoint-audit")
    (mod "pocket-id.nix" "pocket-id")
    (mod "integration.nix" "integration")
    { options = lib.recursiveUpdate (lib.recursiveUpdate stubs portStubs) siblingEnableStubs; }
    {
      networking.domain = "home.lan";
      services.caddy.enable = true;
      services.gatus-config.enable = true;
      services.homepage.enable = true;
      services.system-health.enable = true;
      services.backup-coordination.enable = true;
      services.signoz-coverage.enable = true;
      services.otel-endpoint-audit.enable = true;
      # Options the enabled consumer modules force (caddy TLS cert paths,
      # gatus env template) — content is irrelevant in an eval-only test.
      sops.secrets.dnsblockd_server_cert.sopsFile = ./fixtures/sops-fixture.yaml;
      sops.secrets.dnsblockd_server_key.sopsFile = ./fixtures/sops-fixture.yaml;
      sops.templates."gatus-env".content = "";
    }
  ];

  evalConfig =
    extra:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = baseModules ++ extra;
    }).config;

  # Positive case: one entry exercising every seam, with a unit override and
  # a second plain-layer entry (forward-auth must NOT appear there).
  positive =
    let
      c = evalConfig [
        {
          systemd.services.demo-server.description = "demo upstream unit";
          services.integration.demo = {
            subdomain = "graph"; # in dns-local.nix, no caddy collision here
            port = 8099;
            vHost.layer = "protected";
            unit = "demo-server";
            checks = [
              {
                name = "Demo Health";
                group = "Media";
                path = "/health";
                alert = "demo check failed";
              }
              {
                name = "Demo TCP";
                url = "tcp://127.0.0.1:8099";
                conditions = [ "[CONNECTED] == true" ];
                alert = "";
              }
              { name = "Demo Auto Alert"; }
            ];
            homepage = {
              name = "Demo";
              group = "Media";
              description = "Demo service";
              icon = "demo.png";
            };
            backup = {
              directory = "/mnt/pool/backups/demo";
              filePattern = "demo-*.tar";
            };
            monitored = true;
            otel = {
              serviceName = "demo";
              shape = "http-host-port";
            };
            oidc = {
              name = "Demo";
              clientId = "demo";
              callbackURLs = [ "https://graph.home.lan/cb" ];
            };
          };
          services.integration.demo-plain = {
            subdomain = "timers";
            port = 8098;
            vHost.layer = "plain";
          };
        }
      ];
      protectedCfg = c.services.caddy.virtualHosts."graph.home.lan".extraConfig;
      plainCfg = c.services.caddy.virtualHosts."timers.home.lan".extraConfig;
      tile = lib.findFirst (t: t.name == "Demo") null c.services.homepage.extraTiles;
      demoCheck =
        n:
        lib.findFirst (e: e.name == n) null c.services.gatus-config.extraEndpoints;
      healthCheck = demoCheck "Demo Health";
      tcpCheck = demoCheck "Demo TCP";
      autoCheck = demoCheck "Demo Auto Alert";
    in
    {
      caddy-protected-has-forward-auth = lib.hasInfix "forward_auth" protectedCfg;
      caddy-protected-proxies-port = lib.hasInfix "reverse_proxy localhost:8099" protectedCfg;
      caddy-plain-no-forward-auth = !lib.hasInfix "forward_auth" plainCfg;
      caddy-plain-proxies-port = lib.hasInfix "reverse_proxy localhost:8098" plainCfg;
      gatus-three-checks = builtins.length c.services.gatus-config.extraEndpoints == 3;
      gatus-relative-url = healthCheck.url == "http://127.0.0.1:8099/health";
      gatus-explicit-alert =
        builtins.length healthCheck.alerts == 1
        && (lib.head healthCheck.alerts).description == "demo check failed";
      gatus-silent-alert = tcpCheck.alerts == [ ];
      gatus-auto-alert-from-subdomain =
        (lib.head autoCheck.alerts).description == "Demo Auto Alert down — graph.home.lan unreachable";
      gatus-rides-full-pipeline =
        builtins.any (e: e.name == "Demo Health") c.services.gatus.settings.endpoints;
      gatus-conditions-default = healthCheck.conditions == [ "[STATUS] == 200" ];
      homepage-tile-present = tile != null;
      homepage-tile-href-derived = tile.href == "https://graph.home.lan";
      homepage-tile-group = tile.group == "Media";
      backup-registered =
        (c.services.backup-coordination.backups ? demo)
        && c.services.backup-coordination.backups.demo.directory == "/mnt/pool/backups/demo"
        && c.services.backup-coordination.backups.demo.filePattern == "demo-*.tar";
      monitored-unit-override = c.services.system-health.extraMonitoredServices == [ "demo-server" ];
      monitored-in-all =
        builtins.elem "demo-server"
          (c.services.system-health.monitoredServices ++ c.services.system-health.extraMonitoredServices);
      otel-env-on-unit =
        c.systemd.services.demo-server.environment.OTEL_EXPORTER_OTLP_ENDPOINT == "localhost:4318";
      signoz-keyed-by-unit =
        (c.services.signoz-coverage.expected ? demo-server)
        && c.services.signoz-coverage.expected.demo-server.serviceName == "demo"
        && c.services.signoz-coverage.expected.demo-server.wiring == "env";
      otel-audit-shape = c.services.otel-endpoint-audit.expectations ? demo-server;
      oidc-client-registered =
        builtins.any (cl: cl.clientId == "demo") c.services.pocket-id-config.provision.extraOidcClients;
      no-failing-assertions = builtins.filter (a: !a.assertion) c.assertions == [ ];
    };

  # Negative case: an unregistered subdomain must fail the DNS assertion.
  negativeFires =
    let
      c = evalConfig [
        {
          services.integration.ghost = {
            subdomain = "ghost-zone";
            port = 8097;
          };
        }
      ];
      failing = builtins.filter (a: !a.assertion) c.assertions;
    in
    builtins.any (
      a: lib.hasPrefix "integration:" a.message && lib.hasInfix "ghost-zone" a.message
    ) failing;

  failedChecks = lib.filterAttrs (_: v: !v) positive;
in
if failedChecks != { } then
  pkgs.runCommand "integration-registry-test" { } ''
    echo "integration registry fan-out FAILED checks:"
    ${lib.concatStringsSep "\n" (map (n: "  - ${n}") (builtins.attrNames failedChecks))}
    exit 1
  ''
else if !negativeFires then
  pkgs.runCommand "integration-registry-test" { } ''
    echo "integration registry DNS assertion did NOT fire for ghost-zone"
    exit 1
  ''
else
  pkgs.runCommand "integration-registry-test"
    {
      # The rendered dashboard yaml is a real derivation: prove the folded
      # tile lands in the file homepage will actually serve.
      yaml =
        (evalConfig [
          {
            systemd.services.demo-server.description = "demo upstream unit";
            services.integration.demo = {
              subdomain = "graph";
              port = 8099;
              homepage = {
                name = "Demo";
                group = "Media";
                description = "Demo service";
              };
            };
          }
        ]).environment.etc."homepage/services.yaml".source;
    }
    ''
      grep -q "Demo" "$yaml" || { echo "tile missing from rendered services.yaml"; exit 1; }
      grep -q "Media" "$yaml" || { echo "Media group missing from rendered services.yaml"; exit 1; }
      touch "$out"
    ''
