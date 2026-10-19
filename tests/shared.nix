# Shared fixtures for the service tests — the pieces every consumer-module
# test kept re-copying:
#
#   mod               flake-parts wrapper-module loader (`_: { flake… }`
#                     functions, plain attrsets, and inputs-taking shapes)
#   enableStubs       bulk `.enable` option stubs for sibling namespaces the
#                     real consumer modules read unguarded
#   siblingEnableStubs the canonical sibling list (refresh with:
#                     grep -oE "config\.services\.[a-zA-Z0-9_-]+\.enable"
#                     over the imported modules, minus `or false` readers)
#   portStubs         port-shaped options the unconditional caddy base
#                     vHosts force (signoz/openseo/crush-daily/dns-blocker)
#   baseStubs         the minimal non-port options the caddy-family modules
#                     read unconditionally (subnet, oauth2-proxy port,
#                     dns-blocker enable/interface)
#   poolDiskFixture   a REAL mounted btrfs HDD pool for the VM (empty disk,
#                     by-label mount, pool-fmt formatter)
lib:
let
  inherit (lib)
    mkOption
    types
    ;
in
rec {
  # Wrapper modules are flake-parts modules — `_: { flake.nixosModules.X = …; }`
  # functions — while a few are plain attrsets; handle all shapes. Function
  # modules that take `inputs` (e.g. papdashboard.nix) get the flake inputs;
  # their input-dependent values stay lazy unless the test forces them.
  # Curried on inputs: `mod = shared.mod inputs;` keeps the `mod "file" "name"`
  # call shape unchanged at the (many) use sites.
  mod =
    inputs: file: name:
    let
      imported = import ../modules/nixos/services/${file};
      wrapper =
        if !builtins.isFunction imported then
          imported
        else if (builtins.functionArgs imported) ? inputs then
          imported { inherit inputs; }
        else
          imported { };
    in
    wrapper.flake.nixosModules.${name};

  # Bulk `.enable` stubs for sibling namespaces read unguarded by the real
  # consumer modules (all default false — the test enables none of them).
  # Nested option paths — a flat "services.<n>.enable" STRING key would
  # declare a literally-named option, not the path config reads.
  enableStubs = names: {
    services = lib.listToAttrs (
      map (
        n:
        lib.nameValuePair n {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
        }
      ) names
    );
  };

  siblingEnableStubs = enableStubs [
    "ai-stack"
    "attic-config"
    "bank-sync"
    "buildcache"
    "browser-history"
    "crush-daily"
    "cv-server"
    "discordsync"
    "fastflowlm"
    "file-and-image-renamer"
    "google-sync"
    "hermes"
    "inboxclean"
    "llama-rag"
    "mail-relay"
    "monitor365"
    "monitor365-server"
    "overview"
    "pool-recovery"
    "pool-smart-metrics"
    "projects-management-automation"
    "signoz"
    "systemd-graph"
    "systemd-timer-monitor"
    "tq-agent-pool"
  ];

  # Port-shaped options the UNCONDITIONAL caddy base vHosts force.
  portStubs = {
    services.signoz.settings.queryService.port = mkOption {
      type = types.port;
      default = 8080;
    };
    services.openseo.port = mkOption {
      type = types.port;
      default = 8084;
    };
    services.crush-daily.port = mkOption {
      type = types.port;
      default = 8085;
    };
    services.dns-blocker.statsPort = mkOption {
      type = types.port;
      default = 8086;
    };
    services.dns-blocker.blockIP = mkOption {
      type = types.str;
      default = "0.0.0.0";
    };
  };

  # Minimal stubs for options the real consumer modules read unconditionally
  # from siblings that are not part of a test's import set.
  baseStubs = {
    networking.local.subnet = mkOption {
      type = types.str;
      default = "192.168.1.0/24";
    };
    services.oauth2-proxy-config.port = mkOption {
      type = types.port;
      default = 4180;
    };
    services.dns-blocker.enable = mkOption {
      type = types.bool;
      default = false;
    };
    services.dns-blocker.blockInterface = mkOption {
      type = types.str;
      default = "lo";
    };
  };

  # A real mounted HDD pool for the VM: second virtio disk, formatted btrfs
  # with label `pool`, mounted at /mnt/pool. A module FUNCTION (pkgs comes as
  # a module argument — referencing pkgs in `imports` call position would
  # recurse through _module.args). Merge into the node's imports directly.
  # Richer multi-disk variants live in test-pool-recovery.nix (the reference
  # implementation).
  #
  # MUST be virtualisation.fileSystems, NOT fileSystems: qemu-vm.nix replaces
  # the whole `fileSystems` option at priority 900 (mkVMOverride), so a plain
  # entry silently VANISHES from the guest fstab — until 2026-09-02 the
  # cv test's pool never mounted and every cv-backup assertion ran against a
  # root-fs shadow directory, weaker than believed.
  #
  # pool-fmt must complete BEFORE mnt-pool.mount starts (its by-label device
  # unit only exists once mkfs has run) — a sibling under local-fs.target
  # with no ordering races the mount.
  poolDiskFixture =
    { pkgs, ... }:
    {
      boot.supportedFilesystems = [ "btrfs" ];
      virtualisation.emptyDiskImages = [ 512 ];
      virtualisation.fileSystems."/mnt/pool" = {
        device = "/dev/disk/by-label/pool";
        fsType = "btrfs";
        options = [ "nofail" ];
      };
      systemd.services.pool-fmt = {
        description = "Format the virtio disk as btrfs label pool (test-only)";
        wantedBy = [ "local-fs.target" ];
        before = [
          "mnt-pool.mount"
          "local-fs.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = [
          pkgs.btrfs-progs
          pkgs.util-linux
          pkgs.systemd
        ];
        script = ''
          if ! blkid /dev/vdb | grep -q 'LABEL="pool"'; then
            mkfs.btrfs -f -L pool /dev/vdb
          fi
          udevadm settle
        '';
      };
    };
}
