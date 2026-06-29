# rpi3-dns — Raspberry Pi 3 DNS cluster backup node (aarch64-linux)
#
# Minimal NixOS image: DNS failover + sops only. Imports the rpi3 platform
# config and the nixos-hardware Raspberry Pi 3 profile + SD-card image builder.
{
  inputs,
  linuxOnlyOverlays,
  sharedHomeManagerConfig,
  sharedHomeManagerSpecialArgs,
}: let
  inherit (inputs) nixpkgs home-manager nixos-hardware;
in
  nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit (inputs.self) inputs;
      inherit (inputs) nix-ssh-config nixos-hardware;
    };
    modules = [
      {
        nixpkgs = {
          hostPlatform = "aarch64-linux";
          config.allowUnfree = true;
          overlays = [inputs.nur.overlays.default] ++ linuxOnlyOverlays;
        };
      }
      home-manager.nixosModules.home-manager
      inputs.nur.modules.nixos.default
      {
        home-manager =
          sharedHomeManagerConfig
          // {
            users.root = _: {
              programs.home-manager.enable = true;
              home = {
                enableNixpkgsReleaseCheck = false;
                stateVersion = "25.11";
                file.".config/crush".source = inputs.crush-config;
              };
            };
            extraSpecialArgs = sharedHomeManagerSpecialArgs;
          };
      }
      inputs.self.nixosModules.dns-failover
      inputs.sops-nix.nixosModules.sops
      inputs.self.nixosModules.sops
      nixos-hardware.nixosModules.raspberry-pi-3
      "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      ../platforms/nixos/rpi3/default.nix
    ];
  }
