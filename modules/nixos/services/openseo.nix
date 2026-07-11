# OpenSEO self-hosted SEO suite (keyword research, rank tracking, audits)
# Native NixOS service — builds from source, no Docker container.
# SSO: no built-in auth (AUTH_MODE=local_noauth). Access is gated by
# oauth2-proxy forward-auth (Layer 2 SSO) on seo.<domain>.
_: {
  flake.nixosModules.openseo = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.openseo;
    inherit (config.networking) domain;
    libHelpers = import ../../../lib/default.nix lib;
    inherit (libHelpers) harden serviceDefaults onFailure serviceTypes ports;

    pkg = pkgs.openseo;
    stateDir = "/var/lib/openseo";
    storeDir = "${pkg}/lib/openseo";

    # Stage: symlink read-only project files from Nix store into a writable
    # project directory, preserving the persistent .wrangler state dir.
    stageScript = pkgs.writeShellScriptBin "openseo-stage" ''
      set -euo pipefail
      PROJECT="${stateDir}/project"
      STORE="${storeDir}"

      mkdir -p "$PROJECT" "${stateDir}/.wrangler"

      # Remove old symlinks (preserves .wrangler which is a real dir at stateDir)
      find "$PROJECT" -maxdepth 1 -type l -delete

      # Symlink all files and dotfiles from the Nix store
      for item in "$STORE"/* "$STORE"/.[!.]*; do
        [ -e "$item" ] || continue
        ln -s "$item" "$PROJECT/$(basename "$item")"
      done

      # Link .wrangler to persistent state directory (writable D1 SQLite)
      ln -sfn "${stateDir}/.wrangler" "$PROJECT/.wrangler"
    '';

    # Migrate: apply D1 (SQLite) migrations locally
    migrateScript = pkgs.writeShellScriptBin "openseo-migrate" ''
      set -euo pipefail
      cd "${stateDir}/project"
      exec "${storeDir}/node_modules/.bin/wrangler" d1 migrations apply DB --local
    '';
  in {
    options.services.openseo = {
      enable = lib.mkEnableOption "OpenSEO — self-hosted SEO suite (keyword research, rank tracking, backlinks, site audits)";
      port = serviceTypes.servicePort ports.openseo "HTTP port for OpenSEO dashboard";
    };

    config = lib.mkIf cfg.enable {
      users.users.openseo = {
        isSystemUser = true;
        group = "openseo";
        home = stateDir;
      };
      users.groups.openseo = {};

      systemd.services.openseo = {
        description = "OpenSEO — self-hosted SEO suite";
        inherit onFailure;
        wantedBy = ["multi-user.target"];
        after = ["network.target" "sops-nix.service"];
        wants = ["sops-nix.service"];
        path = [pkgs.nodejs];
        startLimitBurst = 5;
        startLimitIntervalSec = 300;

        serviceConfig = lib.mkMerge [
          (harden {
            MemoryMax = "2G";
          })
          (serviceDefaults {})
          {
            User = "openseo";
            Group = "openseo";
            StateDirectory = "openseo";
            WorkingDirectory = "${stateDir}/project";
            EnvironmentFile = config.sops.templates."openseo-env".path;

            Environment = [
              "PORT=${toString cfg.port}"
              "AUTH_MODE=local_noauth"
              "ALLOWED_HOST=seo.${domain}"
              "VITE_SHOW_DEVTOOLS=false"
              "NODE_OPTIONS=--max-old-space-size=1536"
              "CLOUDFLARE_INCLUDE_PROCESS_ENV=true"
              "HOME=${stateDir}"
            ];

            ExecStartPre = [
              (lib.getExe stageScript)
              (lib.getExe migrateScript)
            ];
            ExecStart = "${storeDir}/node_modules/.bin/vite preview --host 127.0.0.1 --port ${toString cfg.port}";
          }
        ];
      };
    };
  };
}
