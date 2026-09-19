# rpi3-dns — Raspberry Pi 3 DNS cluster backup node (aarch64-linux)
#
# Minimal NixOS image: DNS failover + sops only. Imports the rpi3 platform
# config and the nixos-hardware Raspberry Pi 3 profile + SD-card image builder.
{
  inputs,
  linuxOnlyOverlays,
  sharedHomeManagerConfig,
  sharedHomeManagerSpecialArgs,
}:
let
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
        overlays = [ inputs.nur.overlays.default ] ++ linuxOnlyOverlays;
      };
    }
    home-manager.nixosModules.home-manager
    inputs.nur.modules.nixos.default
    {
      home-manager = sharedHomeManagerConfig // {
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
    inputs.self.nixosModules.dns-blocker
    # dns-blocker declares a services.integration registry entry (mkIf-wrapped
    # options?-guard caveat, 2026-09-15): the guard does NOT survive an
    # enclosing mkIf cfg.enable with enable=true, so the option must exist.
    # integration.nix guards its own fan-out per consumer (optionalAttrs on
    # options ?), so importing it on a host without caddy/gatus/pocket-id is inert.
    inputs.self.nixosModules.integration
    inputs.self.nixosModules.dns-failover
    inputs.sops-nix.nixosModules.sops
    inputs.self.nixosModules.sops
    # The sops eval-time guards. rpi3-dns lists modules explicitly (no
    # auto-discovery like evo-x2), and until 2026-09-16 evaluated its sops
    # config WITHOUT them — exactly the host where recipient coverage is
    # actually broken (dns-failover.yaml carries only evo-x2 while this
    # host consumes it; see the dns-failover item in docs/todo/services.md).
    inputs.self.nixosModules.sops-key-audit
    inputs.self.nixosModules.sops-recipient-audit
    nixos-hardware.nixosModules.raspberry-pi-3
    "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    ../platforms/nixos/rpi3/default.nix
  ];
}
