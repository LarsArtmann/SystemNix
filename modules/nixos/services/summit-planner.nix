# Runbook: docs/services/summit-planner.md
# summit-planner — local single-user conference-attendance & budget
# planner (Go + go-cqrs-lite + cqrs-htmx identity bundle).
#
# Upstream: github:LarsArtmann/summit-planner (PRIVATE; git+ssh input,
# floats on ?ref=refs/heads/master — see the summit-planner.nixpkgs
# deliberate row in lib/lock-audit.nix). The upstream flake exports
# packages only (no nixosModules), so SystemNix authors the unit here and
# consumes inputs.summit-planner.packages.<system>.default.
#
# Deployment contract (2026-11-21):
#   - LOOPBACK-ONLY by design: the app's WebAuthn posture is RPID
#     `localhost` + origin `http://localhost:<port>`, and its
#     guardLocalRequest refuses non-loopback Host headers. There is NO
#     vHost, NO DNS row, NO dashboard tile — the owner browses
#     http://localhost:7612 from the evo-x2 desktop. A LAN/reverse-proxy
#     deployment needs upstream changes first (-rpid/-origin flags exist;
#     the guard relaxation does not).
#   - STATE ADOPTED IN PLACE (crm doctrine): the unit runs as the primary
#     user against the app's own default data dir
#     ~/.config/summit-planner/ — the pre-deploy dev database is adopted
#     with zero migration. The planner journal IS the schema.
#   - identity.db (passkeys, MaxUsers 1) is created beside the planner DB
#     on first registration; a lost passkey = stop unit, delete
#     identity.db, re-register (planner DB never touched).
{ inputs, ... }:
{
  flake.nixosModules.summit-planner =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        ioTier
        ports
        ;
      cfg = config.services.summit-planner;
      user = config.users.primaryUser;
      group = "users";
      # The LIVE data directory (home, NOT StateDirectory — the crm
      # adopt-in-place standing decision; the dev DB is the seed data).
      stateDir = "/home/${user}/.config/summit-planner";
      backupDir = "/mnt/pool/backups/summit-planner";
      # Same derivation the upstream `nix build` produces (its own lock
      # governs the vendorHash — NON-FOLLOWER class, see the input block).
      pkg = inputs.summit-planner.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      options.services.summit-planner = {
        enable = lib.mkEnableOption "summit-planner, the local conference planner web app (loopback-only)";

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.summit-planner;
          description = "Loopback listen port (lib/ports.nix registry).";
        };
      };

      imports = [
        # Platform-truth catalog entry (ADR-008): unconditional — requires
        # nixosModules.catalog (auto-discovered; VM tests must co-import).
        {
          services.catalog.summit-planner = {
            subdomain = null;
            inherit (cfg) port;
            description = "summit-planner — conference-attendance & budget planner (passkey-gated, loopback-only by design: WebAuthn RPID localhost + non-loopback Host guard)";
            healthPath = "/healthz";
          };
        }
      ];

      config = lib.mkIf cfg.enable {
        services.integration.summit-planner = lib.optionalAttrs (options ? services.integration) {
          enable = true;
          subdomain = null;
          inherit (cfg) port;
          unit = "summit-planner.service";
          # No vHost exists: loopback-only app (see header). Tile coverage
          # is subdomain-gated, so no homepage tile and no opt-out flag.
          vHost.layer = "none";
          monitored = true;
          checks = [
            {
              name = "summit-planner";
              group = "Productivity";
              # /healthz is PUBLIC (200 ok / 503 when the cqrs system is
              # unhealthy) and accepts loopback Host headers — the one
              # probe surface that needs no session.
              path = "/healthz";
              interval = "1m";
              conditions = [
                "[STATUS] == 200"
                "[RESPONSE_TIME] < 500"
              ];
              alert = "summit-planner down — conference planner unreachable on loopback (http://localhost:${toString cfg.port})";
            }
          ];
          backup = {
            directory = backupDir;
            filePattern = "*.db";
            maxAgeHours = 25;
          };
        };

        systemd.services.summit-planner = {
          description = "summit-planner — local conference planner web app";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            # Home must stay reachable (adopted-in-place data dir) but
            # read-only; the ONLY writable exception is the app's own dir
            # (sqlite journal + WAL sidecars write there).
            (harden {
              ProtectHome = "read-only";
              ReadWritePaths = [ stateDir ];
            })
            (serviceDefaults { })
            # BE/4 — the standard service tier: tiny single-user sqlite
            # app, nothing that should contend with interactive tiers.
            ioTier.service
            {
              User = user;
              Group = group;
              ExecStart = "${pkg}/bin/summit-planner -addr 127.0.0.1:${toString cfg.port} -db ${stateDir}/summit-planner.db -identity-db ${stateDir}/identity.db";
            }
          ];
        };

        # Pool leaf creator (cv-backup-dir / crm-backup-dir pattern).
        systemd.services.summit-planner-backup-dir = {
          description = "Create summit-planner backup directory on the HDD pool";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            # ReadWritePaths targets the MOUNT ROOT (226/NAMESPACE
            # lesson): on a fresh pool the leaf does not exist yet.
            (harden {
              MemoryMax = "128M";
              ReadWritePaths = [ "/mnt/pool" ];
              CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
            })
            (serviceOneshotDefaults { })
          ];
          path = [ pkgs.coreutils ];
          script = ''
            mkdir -p ${backupDir}
            chown ${user}:${group} ${backupDir}
            chmod 0755 ${backupDir}
          '';
        };

        # Nightly WAL-safe snapshots of BOTH durable databases (the sqlite
        # backup API against the RUNNING server; crm-backup pattern).
        # Deviation from crm: identity.db legitimately does not exist
        # until the first passkey registration (MaxUsers 1), so an absent
        # identity DB is a SKIP-with-note, not a refusal — only a missing
        # planner DB fails the run (sqlite would mint a healthy-looking
        # empty artifact otherwise).
        systemd.services.summit-planner-backup = {
          description = "summit-planner journal + identity backup (WAL-safe sqlite snapshots)";
          after = [
            "summit-planner.service"
            "summit-planner-backup-dir.service"
          ];
          wants = [ "summit-planner-backup-dir.service" ];
          unitConfig.RequiresMountsFor = [ backupDir ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          path = [ pkgs.python3 ];
          script = ''
            set -euo pipefail
            python3 - ${stateDir} ${backupDir} <<'PY'
            import datetime, os, sqlite3, sys

            state_dir, backup_dir = sys.argv[1], sys.argv[2]
            stamp = datetime.date.today().isoformat()
            for name in ("summit-planner", "identity"):
                src_path = os.path.join(state_dir, name + ".db")
                if not os.path.exists(src_path):
                    if name == "identity":
                        print(f"summit-planner-backup: {src_path} absent — no passkey registered yet, skipping")
                        continue
                    raise SystemExit(f"summit-planner-backup: {src_path} missing — refusing empty backup")
                dst_path = os.path.join(backup_dir, f"{name}-{stamp}.db")
                src = sqlite3.connect(src_path)
                dst = sqlite3.connect(dst_path)
                src.backup(dst)
                dst.close()
                src.close()
                # identity.db carries passkey/session tables (bearer
                # material) — tighter mode than the journal snapshot.
                os.chmod(dst_path, 0o600 if name == "identity" else 0o644)
                print(f"summit-planner-backup: wrote {dst_path}")
            PY
            # 30-day retention: one snapshot per night per database,
            # oldest fall off.
            find ${backupDir} \( -name "summit-planner-*.db" -o -name "identity-*.db" \) -mtime +30 -delete
          '';
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = user;
              Group = group;
              ReadWritePaths = [ backupDir ];
            }
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        systemd.timers.summit-planner-backup = {
          description = "Nightly summit-planner backup (journal + identity)";
          wantedBy = [ "timers.target" ];
          after = [ "mnt-pool.mount" ];
          timerConfig = {
            # 03:55 — staggered after crm (03:40), before work hours.
            OnCalendar = "*-*-* 03:55:00";
            RandomizedDelaySec = "10min";
            Persistent = true;
          };
        };
      };
    };
}
