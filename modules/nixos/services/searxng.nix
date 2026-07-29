# SearXNG: privacy-focused metasearch engine aggregating results from
# Google, Bing, DuckDuckGo, Brave, and dozens of other search services.
# Uses nixpkgs services.searx (package: searxng) with SystemNix hardening,
# a dedicated Redis instance (unix socket), Caddy reverse proxy, and Gatus
# monitoring. Access is gated by oauth2-proxy forward-auth (Layer 2 SSO) —
# SearXNG has no native OIDC support.
_: {
  flake.nixosModules.searxng = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.networking) domain;
    lanSubnet = config.networking.local.subnet;

    inherit
      (import ../../../lib/default.nix lib)
      harden
      serviceDefaults
      serviceOneshotDefaults
      onFailure
      ports
      ;

    cfg = config.services.searx;

    # SearXNG requires a secret_key for cookie/CSRF signing. Generated once
    # on first boot and persisted to /var/lib/searxng/searxng.env. systemd
    # reads EnvironmentFile as PID 1 (root), so mode 0600 is safe — the
    # DynamicUser searx process never reads the file directly, it receives
    # the env var from systemd.
    secretKeyFile = "/var/lib/searxng/searxng.env";

    generateSecretKey = pkgs.writeShellApplication {
      name = "searxng-generate-secret-key";
      runtimeInputs = [pkgs.openssl];
      text = ''
        set -eu
        mkdir -p /var/lib/searxng
        if [ ! -s "${secretKeyFile}" ]; then
          printf 'SEARX_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" > "${secretKeyFile}"
          chmod 600 "${secretKeyFile}"
          echo "searxng: generated new secret key"
        fi
      '';
    };

    # DNS-gate: SearXNG engine init() runs at process startup and makes
    # network calls (wikidata fetches SPARQL properties, radio browser
    # resolves its server list, ClearURLs downloads tracker-pattern rules).
    # If DNS isn't ready at boot, these engines fail init PERMANENTLY and
    # stay disabled for the entire process lifetime — no retry. dnsblockd
    # is Type=simple, so after/wants ordering alone doesn't guarantee
    # readiness; this ExecStartPre actively probes resolution.
    waitDnsReady = pkgs.writeShellApplication {
      name = "searxng-wait-dns";
      runtimeInputs = [pkgs.getent];
      text = ''
        echo "searxng: waiting for DNS resolution..."
        for _ in $(seq 1 60); do
          if getent hosts wikidata.org >/dev/null 2>&1; then
            echo "searxng: DNS resolution ready"
            exit 0
          fi
          sleep 2
        done
        echo "searxng: DNS not ready after 120s — engines requiring init-time network will be disabled" >&2
        exit 0
      '';
    };
  in {
    config = lib.mkIf cfg.enable {
      services.searx = {
        # Dedicated Redis via unix socket (isolated from Immich's Redis).
        # Required for the rate limiter / bot protection (server.limiter = true).
        redisCreateLocally = true;
        environmentFile = secretKeyFile;

        faviconsSettings = {
          favicons = {
            cfg_schema = 1;
            cache = {
              db_url = "/var/cache/searx/faviconcache.db";
              HOLD_TIME = 5184000;
              LIMIT_TOTAL_BYTES = 2147483648;
              BLOB_MAX_BYTES = 40960;
              MAINTENANCE_MODE = "auto";
              MAINTENANCE_PERIOD = 600;
            };
          };
        };

        settings = {
          use_default_settings = {
            engines.remove = [
              "ahmia"
              "torch"
            ];
          };
          general = {
            instance_name = "SearXNG";
            debug = false;
            enable_metrics = true;
            donation_url = false;
          };
          server = {
            port = ports.searxng;
            bind_address = "127.0.0.1";
            base_url = "https://search.${domain}/";
            secret_key = "$SEARX_SECRET_KEY";
            image_proxy = true;
            method = "POST";
            limiter = true;
            public_instance = false;
            # Keep-alive between Caddy and SearXNG's built-in server.
            http_protocol_version = "1.1";
          };
          search = {
            safe_search = 0;
            autocomplete = "google";
            autocomplete_min = 4;
            default_lang = "auto";
            # Favicons next to results for a polished UI.
            favicon_resolver = "duckduckgo";
            formats = ["html"];
            ban_time_on_fail = 5;
            max_ban_time_on_fail = 120;
          };
          ui = {
            default_theme = "simple";
            default_locale = "en";
            infinite_scroll = true;
            center_alignment = true;
            # Explicit privacy: don't leak queries into browser tab titles.
            query_in_title = false;
            results_on_new_tab = true;
            theme_args.simple_style = "auto";
          };
          outgoing = {
            request_timeout = 3.0;
            max_request_timeout = 10.0;
            enable_http2 = true;
          };
        };

        # Bot protection / rate limiter config. Caddy proxies from
        # 127.0.0.1, which is in the default trusted_proxies — SearXNG
        # extracts the real client IP from X-Forwarded-For. The LAN
        # subnet is passlisted for unrestricted access (private instance).
        limiterSettings = {
          botdetection = {
            trusted_proxies = [
              "127.0.0.0/8"
              "::1"
              lanSubnet
            ];
            ip_lists.pass_ip = [
              "127.0.0.0/8"
              lanSubnet
            ];
          };
        };
      };

      systemd.services = {
        # Generate the persistent secret key before searx-init runs.
        searxng-secret-key = {
          description = "Generate SearXNG secret key";
          wantedBy = ["multi-user.target"];
          before = [
            "searx-init.service"
            "searx.service"
          ];
          serviceConfig = lib.mkMerge [
            (harden {})
            (serviceOneshotDefaults {})
            {StateDirectory = "searxng";}
          ];
          script = lib.getExe generateSecretKey;
        };

        # Layer SystemNix specifics on top of the nixpkgs searx module.
        # The nixpkgs module already has comprehensive hardening (ProtectSystem=strict,
        # DynamicUser, etc.) — harden {} values use mkDefault so upstream's explicit
        # settings take precedence. We only fill gaps (MemoryMax, Restart policy).
        # DNS-gate: dnsblockd must resolve before engine init (wikidata,
        # radio browser, ClearURLs all need network at init time).
        searx = {
          after = [
            "searxng-secret-key.service"
            "dnsblockd.service"
          ];
          wants = ["dnsblockd.service"];
          requires = ["searxng-secret-key.service"];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          restartTriggers = [
            config.services.searx.package
            (builtins.toJSON config.services.searx.settings)
            (builtins.toJSON config.services.searx.limiterSettings)
          ];
          serviceConfig = lib.mkMerge [
            {
              ExecStartPre = "+${lib.getExe waitDnsReady}";
            }
            (harden {MemoryMax = "512M";})
            (serviceDefaults {})
          ];
        };

        searx-init = {
          after = [
            "searxng-secret-key.service"
            "dnsblockd.service"
          ];
          wants = ["dnsblockd.service"];
          requires = ["searxng-secret-key.service"];
        };
      };
    };
  };
}
