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
    in
    {
      config = lib.mkIf cfg.enable {
        services.searx = {
          # Dedicated Redis via unix socket (isolated from Immich's Redis).
          # Required for the rate limiter / bot protection (server.limiter = true).
          redisCreateLocally = true;
          environmentFile = secretKeyFile;

          settings = {
            use_default_settings = true;
            general = {
              instance_name = "SearXNG";
              debug = false;
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
            };
            search = {
              safe_search = 0;
              autocomplete = "google";
              default_lang = "auto";
            };
            ui = {
              default_theme = "simple";
              default_locale = "en";
              infinite_scroll = true;
              center_alignment = true;
            };
            outgoing = {
              request_timeout = 3.0;
              enable_http2 = true;
            };
          };
        };

        # Generate the persistent secret key before searx-init runs.
        systemd.services.searxng-secret-key = {
          description = "Generate SearXNG secret key";
          wantedBy = [ "multi-user.target" ];
          before = [
            "searx-init.service"
            "searx.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = lib.getExe generateSecretKey;
        };

        # Layer SystemNix specifics on top of the nixpkgs searx module.
        # The nixpkgs module already has comprehensive hardening (ProtectSystem=strict,
        # DynamicUser, etc.) — harden {} values use mkDefault so upstream's explicit
        # settings take precedence. We only fill gaps (MemoryMax, Restart policy).
        systemd.services.searx = {
          after = [ "searxng-secret-key.service" ];
          requires = [ "searxng-secret-key.service" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            (harden { MemoryMax = "512M"; })
            (serviceDefaults { })
          ];
        };

        systemd.services.searx-init = {
          after = [ "searxng-secret-key.service" ];
          requires = [ "searxng-secret-key.service" ];
        };
      };
    };
}
