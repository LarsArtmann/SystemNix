# Default system services: Docker (auto-prune) + weekly Nix GC timer
_: {
  flake.nixosModules.default-services = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.default-services;
  in {
    options.services.default-services = {
      enable =
        lib.mkEnableOption "Default system services (Docker + Nix GC timer)"
        // {
          default = true;
        };
    };

    config = lib.mkIf cfg.enable {
      virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
        storageDriver = "overlay2";
        daemon.settings = {
          data-root = "/data/docker";
          # Docker 29.x moved docker-proxy to the internal moby derivation,
          # which nixpkgs doesn't expose. Disable userland proxy — Docker
          # falls back to iptables rules for port forwarding, which is
          # the recommended production approach.
          userland-proxy = false;
        };
      };

      # Docker should start early at multi-user.target, not block graphical.target
      systemd.services.docker.wantedBy = lib.mkForce ["multi-user.target"];

      # nix.gc is defined in platforms/common/nix-settings.nix (shared)
    };
  };
}
