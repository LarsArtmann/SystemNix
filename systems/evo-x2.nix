# evo-x2 — primary NixOS workstation (AMD Ryzen AI Max+ 395, 128 GB RAM)
#
# Assembles the full NixOS system: overlays, Home Manager wiring, all
# auto-discovered service modules, and the platform configuration.
{
  inputs,
  mkLarsPackages,
  sharedOverlays,
  linuxOnlyOverlays,
  pythonTest,
  discoveredModules,
  sharedHomeManagerConfig,
  sharedHomeManagerSpecialArgs,
}: let
  inherit (inputs) nixpkgs home-manager;
in
  nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit (inputs.self) inputs;
      inherit
        (inputs)
        helium
        nur
        niri
        otel-tui
        nix-amd-npu
        nix-ssh-config
        ;
      larsPackages = mkLarsPackages "x86_64-linux";
    };
    modules =
      [
        {
          nixpkgs = {
            hostPlatform = "x86_64-linux";
            config.allowUnfree = true;
            overlays =
              sharedOverlays
              ++ [
                inputs.niri.overlays.niri
              ]
              ++ linuxOnlyOverlays
              ++ [pythonTest];
          };
          system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
        }
        home-manager.nixosModules.home-manager
        inputs.nur.modules.nixos.default

        {
          home-manager =
            sharedHomeManagerConfig
            // {
              users.lars = _: {
                imports = [
                  ../platforms/nixos/users/home.nix
                ];
              };
              extraSpecialArgs =
                sharedHomeManagerSpecialArgs
                // {
                  wallpapers = inputs.wallpapers-src;
                  dankMaterialShell = inputs.dankMaterialShell;
                };
            };
        }

        inputs.niri.nixosModules.niri
        inputs.nix-amd-npu.nixosModules.default
        inputs.sops-nix.nixosModules.sops
        inputs.silent-sddm.nixosModules.default
      ]
      ++ (map (sm: inputs.self.nixosModules.${sm.module}) discoveredModules)
      ++ [
        inputs.nix-ssh-config.nixosModules.ssh
        inputs.niri-session-manager.nixosModules.niri-session-manager
        inputs.emeet-pixyd.nixosModules.default
        inputs.crush-daily.nixosModules.crush-daily
        inputs.overview.nixosModules.default
        ../platforms/nixos/system/configuration.nix
      ];
  }
