# # NixOS VM for ZFS pool access on incompatible host kernel
# #
# # The host (evo-x2) runs kernel 7.1 which ZFS doesn't officially support yet.
# # This VM boots kernel 6.18 (ZFS's latestCompatibleLinuxPackages) with ZFS
# # enabled, receives the USB controller via VFIO PCIe passthrough, and exposes
# # SSH so you can zpool import and access data.
# #
# # Build:  nix build .#nixosConfigurations.zfs-vm.config.system.build.vm
# # Run:    sudo ./result/bin/run-nixos-vm
# # Access: serial console (telnet) or ssh root@localhost -p 2222
{inputs}: let
  # The USB controller hosting the JMicron JMS567 bridge (bus 8).
  # IOMMU group 29 — isolated, only this device.
  usbController = "0000:c7:00.4";
in
  inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
      (
        {
          pkgs,
          lib,
          ...
        }: {
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "25.11";

          boot.kernelPackages = pkgs.zfs.latestCompatibleLinuxPackages;
          boot.supportedFilesystems = ["zfs"];
          networking.hostId = "a1b2c3d4";

          services.openssh = {
            enable = true;
            settings = {
              PermitRootLogin = "yes";
              PasswordAuthentication = true;
            };
          };
          users.users.root.password = "zfs";

          services.getty.autologinUser = lib.mkForce "root";

          environment.systemPackages = with pkgs; [
            zfs
            usbutils
            pciutils
            smartmontools
            tmux
            vim
          ];

          virtualisation = {
            memorySize = 4096;
            cores = 4;
            diskSize = 4096;
            forwardPorts = [
              {
                from = "host";
                host.port = 2222;
                guest.port = 22;
              }
            ];
            qemu.options = [
              # VFIO PCIe passthrough of the entire USB controller.
              # Host must unbind xhci_hcd and bind vfio-pci before VM start.
              "-device vfio-pci,host=${usbController}"
            ];
          };
        }
      )
    ];
  }
