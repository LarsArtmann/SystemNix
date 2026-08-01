# SearXNG: privacy-focused metasearch engine aggregating results from
# Google, Bing, DuckDuckGo, Brave, and dozens of other search services.
# Uses nixpkgs services.searx (package: searxng) with SystemNix hardening,
# a dedicated Redis instance (unix socket), Caddy reverse proxy, and Gatus
# monitoring. Access is gated by oauth2-proxy forward-auth (Layer 2 SSO) —
# SearXNG has no native OIDC support.
_: {
  flake.nixosModules.searxng =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.networking) domain;
      lanSubnet = config.networking.local.subnet;

      inherit (import ../../../lib/default.nix lib)
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
        runtimeInputs = [ pkgs.openssl ];
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
        runtimeInputs = [ pkgs.getent ];
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
    in
    {
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
              # GET: shareable/bookmarkable URLs. Safe because
              # Caddy sets Referrer-Policy: strict-origin-when-cross-origin
              # (origin only, no query string leaked to result sites).
              method = "GET";
              limiter = true;
              public_instance = false;
              # Keep-alive between Caddy and SearXNG's built-in server.
              http_protocol_version = "1.1";
            };
            search = {
              safe_search = 0;
              # Yandex autocomplete: keystrokes go to Yandex's API
              # via SearXNG (server IP, not user IP).
              autocomplete = "yandex";
              autocomplete_min = 4;
              default_lang = "auto";
              # Favicons next to results for a polished UI.
              favicon_resolver = "duckduckgo";
              formats = [ "html" ];
              ban_time_on_fail = 5;
              max_ban_time_on_fail = 120;
            };
            ui = {
              default_theme = "simple";
              default_locale = "en";
              infinite_scroll = true;
              center_alignment = true;
              # Explicit privacy: don't leak queries into browser tab titles.
              # Tab/window titles show the query for easy identification.
              query_in_title = true;
              results_on_new_tab = true;
              theme_args.simple_style = "auto";
            };
            # Generous timeouts for image/video-heavy searches.
            # Image engines (Google Images, Yandex Images, Baidu, Quark)
            # are slower than text — short timeouts drop them from results.
            outgoing = {
              request_timeout = 8.0;
              max_request_timeout = 20.0;
              enable_http2 = true;
            };

            # Hostname plugin: boost developer reference sites, remove spam.
            # The plugin is active by default but does nothing without this
            # section. These are objective quality improvements for a
            # developer homelab — docs bubble up, content farms disappear.
            hostnames = {
              high_priority = [
                "(.*\\.)?stackoverflow\\.com$"
                "(.*\\.)?developer\\.mozilla\\.org$"
                "(.*\\.)?docs\\.rs$"
                "(.*\\.)?pkg\\.go\\.dev$"
                "(.*\\.)?github\\.com$"
                "(.*\\.)?wiki\\.nixos\\.org$"
                "(.*\\.)?wiki\\.archlinux\\.org$"
                "(.*\\.)?nixos\\.org$"
              ];
              remove = [
                "(.*\\.)?pinterest\\..*$"
                "(.*\\.)?pinterest\\.com$"
              ];
            };

            # Re-enable Google (inactive in SearXNG defaults) and Bing
            # (disabled by default). Google is the highest-quality general
            # search engine — SearXNG proxies requests through itself, so
            # Google sees the server IP, not the user's. With image_proxy
            # and POST method, privacy is still far better than direct use.
            # Bing is enabled directly for result diversity beyond what
            # DuckDuckGo/Brave/Startpage already pull from its index.
            #
            # IMPORTANT: SearXNG has two separate off-switches per engine:
            #   disabled: true  — engine won't load at all
            #   inactive: true  — engine loads but is excluded from default searches
            # Setting inactive=false does NOT override disabled=true.
            # We set BOTH to false on every engine we want enabled.
            engines = [
              # General search engines
              { name = "google"; disabled = false; inactive = false; }
              { name = "google images"; disabled = false; inactive = false; }
              { name = "bing"; disabled = false; inactive = false; }
              { name = "yandex"; disabled = false; inactive = false; }
              { name = "yandex images"; disabled = false; inactive = false; }
              { name = "baidu images"; disabled = false; inactive = false; }
              { name = "quark images"; disabled = false; inactive = false; }

              # Package registries (!bang: !packages)
              { name = "alpine linux packages"; disabled = false; inactive = false; }
              { name = "cachy os packages"; disabled = false; inactive = false; }
              { name = "crates.io"; disabled = false; inactive = false; }
              { name = "docker hub"; disabled = false; inactive = false; }
              { name = "hex"; disabled = false; inactive = false; }
              { name = "hoogle"; disabled = false; inactive = false; }
              { name = "lib.rs"; disabled = false; inactive = false; }
              { name = "metacpan"; disabled = false; inactive = false; }
              { name = "npm"; disabled = false; inactive = false; }
              { name = "packagist"; disabled = false; inactive = false; }
              { name = "pkg.go.dev"; disabled = false; inactive = false; }
              { name = "pub.dev"; disabled = false; inactive = false; }
              { name = "pypi"; disabled = false; inactive = false; }
              { name = "rubygems"; disabled = false; inactive = false; }
              { name = "voidlinux"; disabled = false; inactive = false; }

              # Q&A forums (!bang: !q&a)
              { name = "askubuntu"; disabled = false; inactive = false; }
              { name = "caddy.community"; disabled = false; inactive = false; }
              { name = "discuss.python"; disabled = false; inactive = false; }
              { name = "pi-hole.community"; disabled = false; inactive = false; }
              { name = "stackoverflow"; disabled = false; inactive = false; }
              { name = "superuser"; disabled = false; inactive = false; }

              # Code repositories (!bang: !repos)
              { name = "bitbucket"; disabled = false; inactive = false; }
              { name = "codeberg"; disabled = false; inactive = false; }
              { name = "gitea.com"; disabled = false; inactive = false; }
              { name = "github"; disabled = false; inactive = false; }
              { name = "gitlab"; disabled = false; inactive = false; }
              { name = "huggingface"; disabled = false; inactive = false; }
              { name = "huggingface datasets"; disabled = false; inactive = false; }
              { name = "huggingface spaces"; disabled = false; inactive = false; }
              { name = "ollama"; disabled = false; inactive = false; }
              { name = "sourcehut"; disabled = false; inactive = false; }

              # Video search (!bang: !videos) — full coverage so the
              # video results show thumbnails + durations, not sparse text.
              { name = "google videos"; disabled = false; inactive = false; }
              { name = "bing videos"; disabled = false; inactive = false; }
              { name = "brave.videos"; disabled = false; inactive = false; }
              { name = "qwant videos"; disabled = false; inactive = false; }
              { name = "duckduckgo videos"; disabled = false; inactive = false; }
              { name = "youtube"; disabled = false; inactive = false; }
              { name = "dailymotion"; disabled = false; inactive = false; }
              { name = "vimeo"; disabled = false; inactive = false; }
              { name = "rumble"; disabled = false; inactive = false; }
              { name = "peertube"; disabled = false; inactive = false; }
              { name = "sepiasearch"; disabled = false; inactive = false; }
              { name = "odysee"; disabled = false; inactive = false; }
              { name = "bilibili"; disabled = false; inactive = false; }
              { name = "media.ccc.de"; disabled = false; inactive = false; }
              { name = "wikicommons.videos"; disabled = false; inactive = false; }
              { name = "pixabay videos"; disabled = false; inactive = false; }
              { name = "bitchute"; disabled = false; inactive = false; }
              { name = "google play movies"; disabled = false; inactive = false; }
              { name = "mediathekviewweb"; disabled = false; inactive = false; }
              { name = "naver videos"; disabled = false; inactive = false; }
              { name = "acfun"; disabled = false; inactive = false; }
              { name = "iqiyi"; disabled = false; inactive = false; }
              { name = "sogou videos"; disabled = false; inactive = false; }
              { name = "360search videos"; disabled = false; inactive = false; }
              { name = "adobe stock video"; disabled = false; inactive = false; }
              { name = "dogpile videos"; disabled = false; inactive = false; }
              { name = "findfiles videos"; disabled = false; inactive = false; }
              { name = "fireball videos"; disabled = false; inactive = false; }
              { name = "niconico"; disabled = false; inactive = false; }
              { name = "privacywall videos"; disabled = false; inactive = false; }
              { name = "tusksearch videos"; disabled = false; inactive = false; }
              { name = "vuhuv videos"; disabled = false; inactive = false; }
              { name = "ina"; disabled = false; inactive = false; }
            ];
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

        # Redis is pure cache for SearXNG (rate limiter / bot protection
        # state). Data loss is harmless — cap memory and evict cold keys.
        services.redis.servers.searx.settings = {
          maxmemory = "128mb";
          maxmemory-policy = "allkeys-lru";
        };

        systemd.services = {
          # Generate the persistent secret key before searx-init runs.
          searxng-secret-key = {
            description = "Generate SearXNG secret key";
            wantedBy = [ "multi-user.target" ];
            before = [
              "searx-init.service"
              "searx.service"
            ];
            serviceConfig = lib.mkMerge [
              (harden { })
              (serviceOneshotDefaults { })
              { StateDirectory = "searxng"; }
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
            wants = [ "dnsblockd.service" ];
            requires = [ "searxng-secret-key.service" ];
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
              (harden { MemoryMax = "512M"; })
              (serviceDefaults { })
            ];
          };

          searx-init = {
            after = [
              "searxng-secret-key.service"
              "dnsblockd.service"
            ];
            wants = [ "dnsblockd.service" ];
            requires = [ "searxng-secret-key.service" ];
          };
        };
      };
    };
}
