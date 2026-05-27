# Default system services: Docker (auto-prune) + weekly Nix GC timer
_: {
  flake.nixosModules.default-services = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.default-services;
  in {
    options.services.default-services = {
      enable = lib.mkEnableOption "Default system services (Docker + Nix GC timer)" // {default = true;};
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
        };
      };

      # Docker should start early at multi-user.target, not block graphical.target
      systemd.services.docker.wantedBy = lib.mkForce ["multi-user.target"];

      # nix.gc is defined in platforms/common/nix-settings.nix (shared)
    };
  };
}
