# disko geometry spec for the Samsung 970 EVO Plus 1TB (evo-x2, `tlc`).
#
# Deliberately NOT imported by nixosConfigurations (the flake-discovery
# trap: an imported module makes `disko --flake .#<host>` apply destructive
# modes). This is an eval-checked executable spec of the LIVE layout —
# a reinstall/rescue reference (destructive disko is rescue-only, never on
# disks with data). Plan:
# docs/planning/2026-09-14_13-27_SAMSUNG-PHASE2-HOT-DB-NATIVE-PARETO-PLAN.md
# (T16); live-geometry source of truth: /etc/fstab (subvol=nix, hot
# toplevel) + platforms/nixos/system/boot-mirror.nix (SAMSUNG-EFI).
#
# Geometry notes:
# - Device pinned by-id: kernel NVMe enumeration FLIPS across boots.
# - p1 = 4G FAT32 `SAMSUNG-EFI` (boot-mirror target; mounted by the QLC
#   primary's fstab, so disko leaves it unmounted).
# - p2 = btrfs `-L tlc`; TOPLEVEL (subvolid=5) mounts at /mnt/hot — the
#   hot-db bootstrap creates `hot/<name>` service subvolumes through it
#   (modules/nixos/services/hot-db.nix), so /mnt/hot must NOT be a named
#   subvolume.
{
  disko.devices.disk.samsung-tlc = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0RA01856V";
    content = {
      type = "gpt";
      partitions = {
        esp = {
          type = "EF00";
          size = "4G";
          label = "esp";
          priority = 1;
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = null; # mounted by the primary boot's fstab (boot-mirror)
            extraArgs = [
              "-n"
              "SAMSUNG-EFI"
            ];
          };
        };
        main = {
          size = "100%";
          label = "main";
          content = {
            type = "btrfs";
            extraArgs = [
              "-L"
              "tlc"
            ];
            mountpoint = "/mnt/hot"; # toplevel (subvolid=5), nofail in live fstab
            mountOptions = [
              "compress=zstd"
              "noatime"
              "nodiscard"
              "space_cache=v2"
            ];
            subvolumes = {
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                  "nodiscard"
                  "space_cache=v2"
                ];
              };
              "/users/lars/cache/nix" = {
                mountpoint = "/home/lars/.cache/nix";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                  "nodiscard"
                ];
              };
            };
          };
        };
      };
    };
  };
}
