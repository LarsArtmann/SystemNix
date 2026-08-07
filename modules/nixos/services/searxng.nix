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
          # No Redis/Valkey — the rate limiter (server.limiter) is disabled
          # for this private LAN instance. Redis was only used for bot detection
          # sliding-window counters, which is pointless when all traffic is
          # passlisted (127.0.0.0/8 + LAN subnet). Removing Redis eliminates a
          # synchronous unix-socket round-trip on every search request.
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
              limiter = false;
              public_instance = false;
              # Keep-alive between Caddy and SearXNG's built-in server.
              http_protocol_version = "1.1";
            };
            search = {
              safe_search = 0;
              # DuckDuckGo autocomplete: faster from EU than Yandex.
              # Keystrokes go to DDG's API via SearXNG (server IP, not user IP).
              autocomplete = "duckduckgo";
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
            # Aggressive timeouts for fast TTFB. SearXNG queries all active
            # engines concurrently — TTFB ≈ slowest engine (capped by timeout).
            # 3s cuts stragglers; fast engines (Google, Bing) return <1s.
            # Slow engines simply drop from results instead of blocking the page.
            outgoing = {
              request_timeout = 3.0;
              max_request_timeout = 5.0;
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
              {
                name = "google";
                disabled = false;
                inactive = false;
              }
              {
                name = "google images";
                disabled = false;
                inactive = true;
              }
              {
                name = "bing";
                disabled = false;
                inactive = false;
              }
              {
                name = "yandex";
                disabled = false;
                inactive = false;
              }
              {
                name = "yandex images";
                disabled = false;
                inactive = true;
              }
              {
                name = "baidu images";
                disabled = false;
                inactive = true;
              }
              {
                name = "quark images";
                disabled = false;
                inactive = true;
              }
              {
                name = "bing images";
                disabled = false;
                inactive = true;
              }
              {
                name = "duckduckgo images";
                disabled = false;
                inactive = true;
              }
              {
                name = "qwant images";
                disabled = false;
                inactive = true;
              }
              {
                name = "tineye";
                disabled = false;
                inactive = true;
              }

              # Package registries (!bang: !packages)
              {
                name = "alpine linux packages";
                disabled = false;
                inactive = true;
              }
              {
                name = "cachy os packages";
                disabled = false;
                inactive = true;
              }
              {
                name = "crates.io";
                disabled = false;
                inactive = true;
              }
              {
                name = "docker hub";
                disabled = false;
                inactive = true;
              }
              {
                name = "hex";
                disabled = false;
                inactive = true;
              }
              {
                name = "hoogle";
                disabled = false;
                inactive = true;
              }
              {
                name = "lib.rs";
                disabled = false;
                inactive = true;
              }
              {
                name = "metacpan";
                disabled = false;
                inactive = true;
              }
              {
                name = "npm";
                disabled = false;
                inactive = true;
              }
              {
                name = "packagist";
                disabled = false;
                inactive = true;
              }
              {
                name = "pkg.go.dev";
                disabled = false;
                inactive = true;
              }
              {
                name = "pub.dev";
                disabled = false;
                inactive = true;
              }
              {
                name = "pypi";
                disabled = false;
                inactive = true;
              }
              {
                name = "rubygems";
                disabled = false;
                inactive = true;
              }
              {
                name = "voidlinux";
                disabled = false;
                inactive = true;
              }

              # Q&A forums (!bang: !q&a)
              {
                name = "askubuntu";
                disabled = false;
                inactive = true;
              }
              {
                name = "caddy.community";
                disabled = false;
                inactive = true;
              }
              {
                name = "discuss.python";
                disabled = false;
                inactive = true;
              }
              {
                name = "pi-hole.community";
                disabled = false;
                inactive = true;
              }
              {
                name = "stackoverflow";
                disabled = false;
                inactive = true;
              }
              {
                name = "superuser";
                disabled = false;
                inactive = true;
              }

              # Code repositories (!bang: !repos)
              {
                name = "bitbucket";
                disabled = false;
                inactive = true;
              }
              {
                name = "codeberg";
                disabled = false;
                inactive = true;
              }
              {
                name = "gitea.com";
                disabled = false;
                inactive = true;
              }
              {
                name = "github";
                disabled = false;
                inactive = true;
              }
              {
                name = "gitlab";
                disabled = false;
                inactive = true;
              }
              {
                name = "huggingface";
                disabled = false;
                inactive = true;
              }
              {
                name = "huggingface datasets";
                disabled = false;
                inactive = true;
              }
              {
                name = "huggingface spaces";
                disabled = false;
                inactive = true;
              }
              {
                name = "ollama";
                disabled = false;
                inactive = true;
              }
              {
                name = "sourcehut";
                disabled = false;
                inactive = true;
              }

              # Video search (!bang: !videos) — full coverage so the
              # video results show thumbnails + durations, not sparse text.
              {
                name = "google videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "bing videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "brave.videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "qwant videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "duckduckgo videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "youtube";
                disabled = false;
                inactive = true;
              }
              {
                name = "dailymotion";
                disabled = false;
                inactive = true;
              }
              {
                name = "vimeo";
                disabled = false;
                inactive = true;
              }
              {
                name = "rumble";
                disabled = false;
                inactive = true;
              }
              {
                name = "peertube";
                disabled = false;
                inactive = true;
              }
              {
                name = "sepiasearch";
                disabled = false;
                inactive = true;
              }
              {
                name = "odysee";
                disabled = false;
                inactive = true;
              }
              {
                name = "bilibili";
                disabled = false;
                inactive = true;
              }
              {
                name = "media.ccc.de";
                disabled = false;
                inactive = true;
              }
              {
                name = "wikicommons.videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "pixabay videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "bitchute";
                disabled = false;
                inactive = true;
              }
              {
                name = "google play movies";
                disabled = false;
                inactive = true;
              }
              {
                name = "mediathekviewweb";
                disabled = false;
                inactive = true;
              }
              {
                name = "naver videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "acfun";
                disabled = false;
                inactive = true;
              }
              {
                name = "iqiyi";
                disabled = false;
                inactive = true;
              }
              {
                name = "sogou videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "360search videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "adobe stock video";
                disabled = false;
                inactive = true;
              }
              {
                name = "dogpile videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "findfiles videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "fireball videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "niconico";
                disabled = false;
                inactive = true;
              }
              {
                name = "privacywall videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "tusksearch videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "vuhuv videos";
                disabled = false;
                inactive = true;
              }
              {
                name = "ina";
                disabled = false;
                inactive = true;
              }
            ];
          };

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
            ];
            serviceConfig = lib.mkMerge [
              {
                ExecStartPre = "+${lib.getExe waitDnsReady}";
                TimeoutStartSec = "3min";
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
