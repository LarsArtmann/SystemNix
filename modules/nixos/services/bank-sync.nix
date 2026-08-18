# bank-sync — SystemNix deployment overlay for the bank-sync service
#
# Upstream module (inputs.bank-sync.nixosModules.default, imported in
# systems/evo-x2.nix like the crush-daily wiring) declares services.bank-sync
# options + the systemd unit. SystemNix adds the house wiring:
#
#   - Dashboard binds 127.0.0.1:<ports.bank-sync> — Caddy vHost
#     banksync.<domain> (protectedVHost: LAN bypass + external forward-auth)
#     is the sole external entry point
#   - SQLite database on the mirrored HDD pool (/mnt/pool/services/bank-sync,
#     btrbk-pool snapshotted) instead of the QLC NVMe — same placement
#     decision as atticd (2026-08-18)
#   - Wise API key + AES-256 event encryption key from the sops template
#     "bank-sync-env" (see sops.nix)
#   - Pool-gated storage-dir oneshot + house hardening (harden {},
#     serviceDefaults, onFailure, start limits, background I/O tier)
_: {
  flake.nixosModules.bank-sync =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.bank-sync;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        ports
        ioTier
        mkSecretCheck
        ;
      envTemplate = config.sops.templates."bank-sync-env";
      # House policy: this deployment always encrypts events at rest. An
      # empty/missing sops key would silently downgrade bank-sync to
      # UNENCRYPTED (it treats an empty env var as "no key") — fail the unit
      # instead. A missing YAML key leaves the {{ marker unreplaced, which
      # bank-sync then rejects loudly at base64 decode; this check catches
      # the remaining silent case (key present but empty).
      checkEncryptionKey = mkSecretCheck pkgs {
        name = "bank-sync-encryption-key";
        secretPath = envTemplate.path;
        message = ''
          bank-sync: BANK_SYNC_SECURITY_ENCRYPTION_KEY is missing or empty in ${envTemplate.path}
            Re-create platforms/nixos/secrets/bank-sync-encryption.yaml (sops-encrypt a 32-byte base64 key to the host age public key in .sops.yaml), then redeploy.'';
        extraCheck = ''
          ${pkgs.gnugrep}/bin/grep -qE '^BANK_SYNC_SECURITY_ENCRYPTION_KEY=..' "$secret_path"
        '';
      };
    in
    {
      config = lib.mkIf cfg.enable {
        services.bank-sync = {
          # Caddy is the sole external entry point (defense-in-depth: the raw
          # HTTP server stays unreachable even if a firewall rule appears).
          addr = "127.0.0.1:${toString ports.bank-sync}";

          # SQLite on the mirrored HDD pool, snapshotted nightly by btrbk-pool.
          dataDir = lib.mkDefault "/mnt/pool/services/bank-sync";

          # sops template renders BANK_SYNC_WISE_API_KEY=... and
          # BANK_SYNC_SECURITY_ENCRYPTION_KEY=... (KEY=VALUE env file).
          wiseApiKeyFile = config.sops.templates."bank-sync-env".path;
          encryptionKeyFile = config.sops.templates."bank-sync-env".path;
        };

        # The pool mounts nofail — systemd-tmpfiles could create the dir on the
        # ROOT filesystem under the /mnt/pool mountpoint before the pool is up
        # (contaminating the NVMe). This oneshot runs only while the pool is
        # actually mounted (RequiresMountsFor fails loudly on a detached DAS) and
        # creates the directory with the service-user ownership the upstream
        # module expects (createHome is deliberately false upstream).
        systemd.services.bank-sync-storage-dir = {
          description = "Create bank-sync data directory on the HDD pool";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ cfg.dataDir ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            (harden {
              # subvolume create needs CAP_SYS_ADMIN, chown CAP_CHOWN;
              # harden{} defaults to an empty bounding set which would EPERM
              # both. Write access to the PARENT is required to create the
              # subvolume (mkdir/chown/chmod on the dir itself is covered).
              CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_CHOWN CAP_DAC_OVERRIDE";
              ReadWritePaths = [ (dirOf cfg.dataDir) ];
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            dir=${toString cfg.dataDir}
            if [ ! -e "$dir" ]; then
              # Subvolume (not plain dir) so btrbk-pool can snapshot it —
              # mirrors the atticd pool placement. Falls back to a plain dir
              # only on non-btrfs filesystems.
              if ! ${pkgs.btrfs-progs}/bin/btrfs subvolume create "$dir"; then
                mkdir -p "$dir"
              fi
            else
              mkdir -p "$dir"
            fi
            chown bank-sync:bank-sync "$dir"
            chmod 0750 "$dir"
          '';
        };

        systemd.services.bank-sync = {
          after = [ "bank-sync-storage-dir.service" ];
          wants = [ "bank-sync-storage-dir.service" ];
          # AGENTS.md rule 5: every service sets start-limit bounds + onFailure.
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              ExecStartPre = [ (lib.getExe checkEncryptionKey) ];
            }
            (harden {
              MemoryMax = "512M";
            })
            (serviceDefaults { })
            # SQLite on spinning rust, synced every 15m — never compete with
            # the desktop for I/O.
            ioTier.background
          ];
        };
      };
    };
}
