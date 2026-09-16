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
}:
let
  inherit (inputs) nixpkgs home-manager;
in
nixpkgs.lib.nixosSystem {
  specialArgs = {
    inherit (inputs.self) inputs;
    inherit (inputs)
      helium
      herdr
      nur
      niri
      otel-tui
      nix-amd-npu
      nix-ssh-config
      ;
    larsPackages = mkLarsPackages "x86_64-linux";
  };
  modules = [
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
          ++ [ pythonTest ];
      };
      system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    }
    home-manager.nixosModules.home-manager
    inputs.nur.modules.nixos.default

    {
      home-manager = sharedHomeManagerConfig // {
        users.lars = _: {
          imports = [
            ../platforms/nixos/users/home.nix
            # bank-sync CLI on PATH (programs.bank-sync) — the admin surface
            # for the daemon deployed via inputs.bank-sync.nixosModules below.
            # Explicit package pin: SystemNix's nixpkgs carries no bank-sync
            # attr, so the module's mkPackageOption default cannot resolve.
            inputs.bank-sync.homeManagerModules.default
          ];
          programs.bank-sync = {
            enable = true;
            package = inputs.bank-sync.packages.x86_64-linux.default;
          };
        };
        extraSpecialArgs = sharedHomeManagerSpecialArgs // {
          wallpapers = inputs.wallpapers-src;
          inherit (inputs) dankMaterialShell;
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
    inputs.bank-sync.nixosModules.default
    inputs.go-taskqueue.nixosModules.default
    ../platforms/nixos/system/configuration.nix
  ];
}
