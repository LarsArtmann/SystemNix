# VM test for the Miniflux service module (modules/nixos/services/miniflux.nix).
#
# Verifies the runtime behavior nix eval CANNOT check:
#   1. miniflux boots against a real PostgreSQL (createDatabaseLocally:
#      migrations + CREATE_ADMIN bootstrap) and answers /healthcheck
#   2. The login page renders HTML and the sops-provided admin credentials
#      authenticate against the REST API (end-to-end EnvironmentFile chain)
#   3. Layer 1 OIDC wiring lands in the unit: OAUTH2_* env + LoadCredential of
#      the Pocket ID client secret (fake-seeded — LoadCredential cannot
#      tolerate a missing path). The OIDC gate's curl probe is neutered
#      because auth.home.lan cannot exist inside the VM.
#   4. The backup chain lands dumps on a REAL mounted pool (virtualisation
#      fileSystems — the plain fileSystems vanish trap, test-cv 2026-09-02):
#      the mount-gated dir oneshot creates the postgres-owned leaf, pg_dump
#      writes a PGDMP-magic artifact, and the timer exists.
_:
let
  minifluxFlakeOutput = (import ../modules/nixos/services/miniflux.nix) { };
  minifluxModule = minifluxFlakeOutput.flake.nixosModules.miniflux;

  # Options-only mock: the module reads services.pocket-id-config.{enable,
  # provision.enable} and falls back to /var/lib/pocket-id for the dataDir
  # (`or` idiom, dns-blocker pattern) — the full Pocket ID module is not
  # needed in the VM.
  pocketIdConfigMock =
    { lib, ... }:
    {
      options.services.pocket-id-config = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        provision.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };
    };

  adminUser = "admin";
  adminPassword = "vm-test-password";
  minifluxPort = 8101;
in
{
  name = "miniflux";

  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = [
        minifluxModule
        pocketIdConfigMock
        ./mock-sops.nix
        ./test-helpers.nix
      ];

      system.stateVersion = "25.11";
      virtualisation.memorySize = 2048;
      # networking.domain is already pinned to "test.local" by test-helpers.nix
      # — the OIDC-wiring assertions below assert against that derived value.

      services.miniflux.enable = true;
      services.pocket-id-config.enable = true;
      services.pocket-id-config.provision.enable = true;

      # sops mock: point the admin-credentials secret at a plain etc file so
      # CREATE_ADMIN has real content (an empty mock file would make miniflux
      # refuse to start — ADMIN_USERNAME/ADMIN_PASSWORD are mandatory).
      sops.secrets."miniflux_admin_credentials".path = "/etc/miniflux-test-credentials";
      environment.etc."miniflux-test-credentials".text = ''
        ADMIN_USERNAME=${adminUser}
        ADMIN_PASSWORD=${adminPassword}
      '';

      # Boot-time fake Pocket ID client secret (test-paperless pattern):
      # miniflux.service carries LoadCredential on that path, and the unit
      # fails to LOAD if the source file is missing.
      systemd.services.vm-pocket-id-secret = {
        description = "VM test: fake Pocket ID client secret";
        wantedBy = [ "miniflux.service" ];
        before = [ "miniflux.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          mkdir -p /var/lib/pocket-id/client-secrets
          printf 'vm-fake-oidc-client-secret' > /var/lib/pocket-id/client-secrets/miniflux
        '';
      };

      # The OIDC gate curls https://auth.home.lan — unresolvable in the VM.
      # Neuter ONLY the probe; the LoadCredential/OAUTH2 assertions below
      # still pin the real wiring.
      systemd.services.miniflux.serviceConfig.ExecStartPre = lib.mkForce [ ];

      # Real mounted HDD pool (test-cv recipe): MUST be virtualisation.fileSystems
      # — qemu-vm.nix replaces the whole `fileSystems` option at priority 900.
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

  testScript = ''
    machine.start()

    # 1. Service + DB bootstrap (migrations + CREATE_ADMIN run pre-listen)
    machine.wait_for_unit("miniflux.service", timeout=180)
    machine.wait_for_open_port(${toString minifluxPort}, timeout=120)
    health = machine.succeed("curl -sf http://127.0.0.1:${toString minifluxPort}/healthcheck")
    assert health.strip() == "OK", f"/healthcheck must answer OK, got: {health!r}"

    # 2. Login page renders; admin credentials from the env file authenticate
    page = machine.succeed("curl -sf http://127.0.0.1:${toString minifluxPort}/")
    assert "<html" in page, "login page must render HTML"
    me = machine.succeed(
      "curl -sf -u '${adminUser}:${adminPassword}' http://127.0.0.1:${toString minifluxPort}/v1/me"
    )
    assert '"username"' in me, f"admin API auth failed, got: {me!r}"

    # 3. Layer 1 OIDC wiring in the unit (env + credential bind)
    unit = machine.succeed("systemctl cat miniflux")
    for needle in [
        "OAUTH2_PROVIDER=oidc",
        "OAUTH2_CLIENT_SECRET_FILE=%d/miniflux-oidc-secret",
        "OAUTH2_OIDC_DISCOVERY_ENDPOINT=https://auth.test.local",
        "OAUTH2_USER_CREATION=1",
        "LoadCredential=",
    ]:
        assert needle in unit, f"missing OIDC wiring {needle!r} in unit"
    machine.succeed("test -f /var/lib/pocket-id/client-secrets/miniflux")

    # 4. Pool-mounted backup chain (findmnt pins the REAL mount — the
    # root-fs shadow-dir class)
    machine.succeed("findmnt -n -o FSTYPE /mnt/pool | grep -q btrfs")
    machine.wait_for_unit("miniflux-backup-dir.service")
    machine.succeed("test -d /mnt/pool/backups/miniflux")
    owner = machine.succeed("stat -c %U /mnt/pool/backups/miniflux").strip()
    assert owner == "postgres", f"backup dir must be postgres-owned, got: {owner!r}"
    machine.systemctl("start miniflux-backup.service")
    dumps = machine.succeed("ls /mnt/pool/backups/miniflux")
    assert ".dump" in dumps, f"no pg_dump artifact landed, got: {dumps!r}"
    magic = machine.succeed(
      "head -c 5 /mnt/pool/backups/miniflux/miniflux-*.dump"
    )
    assert magic == "PGDMP", f"artifact is not a pg_dump custom file, magic: {magic!r}"
    machine.succeed("systemctl list-timers | grep -q miniflux-backup")
  '';
}
