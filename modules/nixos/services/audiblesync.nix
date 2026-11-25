# Runbook: docs/services/audiblesync.md (+ docs/services/audible-sync.md for
# the weekly archive oneshot).
# audiblesync — SystemNix layer over the UPSTREAM nixosModules.default
# (github:LarsArtmann/audiblesync; extraction wave 2026-11-15 per
# docs/agents/integration-registry.md "Extraction recipe").
#
# The upstream module owns BOTH services — the WebUI tracker
# (audiblesync.service) AND the weekly full-library archive oneshot
# (audible-sync.service + audible-sync-dirs + audible-sync.timer) — as ONE
# system sharing the `audible-sync` identity, the sops-rendered auth, and the
# archive tree. Unit names are unchanged, so deploy.sh's provisioner list,
# pool-recovery's roster, sops.nix's svcEnabled gating, and both runbooks
# keep working unchanged. The fleet facts (poolDir, authFile, addr, alert
# routing, DNS gate) are PLAIN-priority assignments here — the upstream
# module declares them as mkDefault options, so plain beats mkDefault
# without force (CPUQuota-trap direction inverted: upstream PLAIN would need
# mkForce downstream; its mkDefaults don't).
#
# This file layers ONLY the SystemNix-specific concerns (the recipe's "What
# to layer" list): sops authFile wiring, lib/ports.nix addr, DNS gate,
# onFailure alert routing, harden{} + ioTier + serviceDefaults ceilings, the
# nightly SQLite backup pair, backup-coordination freshness, and the ONE
# PapDashboard tile — the old second "Audible Sync" tile merged away (the
# 2-tile dash.home.lan duplication was this extraction's trigger).
#
# NOTE on ReadWritePaths: upstream derives it mkDefault from poolDir, and
# harden{} always adds its own mkDefault [] — wrapper passes NO
# ReadWritePaths into harden so each unit keeps exactly ONE non-empty
# definition (a second non-empty mkDefault list would CONCAT, duplicating
# the path in the rendered unit).
{ inputs, ... }: {
  flake.nixosModules.audiblesync =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        ports
        ioTier
        mkDnsGate
        mkPoolDirUnit
        mkSqliteBackupUnit
        ;

      cfg = config.services.audiblesync;
      archiveCfg = config.services.audible-sync;

      apiHost = "api.audible.${archiveCfg.countryCode}";

      dnsGate = mkDnsGate {
        inherit pkgs;
        serviceName = "audible-sync";
        hostname = apiHost;
      };
    in
    {
      imports = [ inputs.audiblesync.nixosModules.default ];
      config = lib.mkMerge [
        (lib.mkIf archiveCfg.enable {
          # Fleet facts for the upstream module (PLAIN — beats upstream
          # mkDefault; see header). authFile under this mkIf stays lazy on
          # hosts without sops (the secret only exists when this service is
          # enabled — sops.nix gates on the same flag).
          services.audible-sync = {
            poolDir = "/mnt/pool/services/audible";
            dataDir = "/var/lib/audible-sync";
            authFile = config.sops.secrets.audible_sync_auth_json.path;
            onFailureUnits = onFailure;
            extraAfter = dnsGate.after;
            extraWants = dnsGate.wants;
            extraExecStartPre = dnsGate.serviceConfig.ExecStartPre;
          };

          # Ceilings + fleet audits (io-tier, timeout floors via the
          # oneshot defaults). NO ReadWritePaths here — upstream owns it
          # (header note). NO CapabilityBoundingSet on the sync unit.
          systemd.services.audible-sync.serviceConfig = lib.mkMerge [
            (harden { MemoryMax = "1G"; })
            (serviceOneshotDefaults { })
            ioTier.background
          ];

          # The dirs converger runs as ROOT and chowns the pool leaves —
          # harden{}'s empty bounding set strips CAP_CHOWN from root, so the
          # chown EPERMs inside the namespace without this (mkPoolDirUnit
          # invariant, lib/default.nix; 2026-09-22 EPERM class — live again
          # 2026-11-10 23:43 after the 226 fix).
          systemd.services.audible-sync-dirs.serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "128M";
              CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];

          # Archive freshness (Gatus alerts via the global backup_all_healthy
          # check when this goes stale). The upstream oneshot touches
          # last_success only when download AND every decrypt passed.
          services.backup-coordination.backups.audible-sync = {
            directory = archiveCfg.dataDir;
            filePattern = "last_success";
            inherit (archiveCfg) maxAgeHours;
          };
        })

        (lib.mkIf cfg.enable {
          services.audiblesync = {
            # The upstream module declares `package` with NO default (its
            # flake can't self-reference across consumer locks) — supply it
            # from this input, overridable per-host (bank-sync pattern).
            package = lib.mkDefault inputs.audiblesync.packages.${pkgs.stdenv.hostPlatform.system}.default;
            # Loopback-only (upstream default shape); the port comes from the
            # registry (8481) so a registry change propagates.
            addr = "127.0.0.1:${toString ports.audiblesync}";
            dataDir = "/var/lib/audiblesync";
            onFailureUnits = onFailure;
          };

          # Nightly WAL-safe SQLite online backup (lib generator, plan E1):
          # 02:35 — staggered off paperless-db (02:00), browser-history
          # (02:15), and miniflux (02:45). Root reads the audible-sync-owned
          # StateDirectory directly (no DynamicUser 0700 — no caps needed).
          systemd = lib.mkMerge [
            {
              services.audiblesync.serviceConfig = lib.mkMerge [
                (harden { MemoryMax = "1G"; })
                (serviceDefaults { })
                ioTier.service
              ];

              services.audiblesync-backup-dir = lib.mkMerge [
                (mkPoolDirUnit {
                  description = "Create AudibleSync DB backup directory on the HDD pool";
                  directory = "/mnt/pool/backups/audiblesync";
                  # owner is root (the browser-history pattern): the backup
                  # unit runs as hardened root with an empty
                  # CapabilityBoundingSet, so it CANNOT write a 0755 dir owned
                  # by another user — owner = "audible-sync" made every
                  # nightly mktemp fail EPERM from 2026-11-14 (the pool
                  # re-provision) until 2026-11-24; backup_healthy sat 0 with
                  # age pinned at the 999h sentinel. Spelled out, not omitted:
                  # the generator grants CAP_CHOWN/CAP_FOWNER only for a
                  # non-null owner, and the directory on disk stayed owned by
                  # audible-sync after the pool re-provision, so with no owner
                  # the chmod EPERMed and this unit failed on every deploy
                  # from 2026-11-24 21:36 to 2026-11-25 (the nightly backup
                  # never ran: its service depends on this unit).
                  owner = "root";
                })
                # mkPoolDirUnit bakes no IO tier; the boot-transaction audit
                # requires one on every wantedBy multi-user unit
                # (audible-sync-dirs carries ioTier.background for the same
                # reason).
                { serviceConfig = ioTier.background; }
              ];
            }

            (mkSqliteBackupUnit {
              inherit pkgs;
              name = "audiblesync-backup";
              description = "AudibleSync DB backup (online sqlite .backup)";
              dbPath = "/var/lib/audiblesync/audiblesync.db";
              backupDir = "/mnt/pool/backups/audiblesync";
              prefix = "audiblesync-db-";
              retentionDays = 14;
              # The live DB is 0600 behind the dynamic-user StateDirectory —
              # caps-stripped root cannot read it without this (the
              # browser-history precedent, its call site line ~797; without
              # it: sqlite "unable to open database file", live 2026-11-24).
              caps = "CAP_DAC_READ_SEARCH";
              startAt = {
                OnCalendar = "*-*-* 02:35:00";
              };
              serviceDeps = [
                "audiblesync.service"
                "audiblesync-backup-dir.service"
              ];
              timerAfter = [ "mnt-pool.mount" ];
              onFailureDeps = onFailure;
              extraServiceConfig = [ ioTier.background ];
            })
          ];

          # Service-integration registry entry: ONE declaration fans out the
          # Caddy vHost (protected layer — the app has NO auth of its own),
          # dnsblockd record, Gatus checks, the PapDashboard tile, and backup
          # freshness (integration.nix; miniflux is the reference entry).
          # This is the ONE Audible tile: the archive oneshot has no vHost
          # and no port, so its former "Audible Sync" tile (Sync & Backup
          # group) merged into this entry's description instead.
          services.integration = lib.optionalAttrs (options ? services.integration) {
            audiblesync = {
              inherit (cfg) enable;
              port = ports.audiblesync;
              subdomain = "audiblesync";
              vHost.layer = "protected";
              monitored = true;
              checks = [
                {
                  name = "AudibleSync health";
                  group = "Media";
                  path = "/healthz";
                  conditions = [
                    "[STATUS] == 200"
                    # Honest health: /healthz pings the system composition
                    # root AND the read model (503 + "error" status on
                    # failure), so the body shape proves both legs.
                    "[BODY] == pat(*\"status\":\"ok\"*)"
                  ];
                }
                {
                  name = "AudibleSync dashboard";
                  group = "Media";
                  path = "/";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 1000"
                  ];
                }
              ];
              homepage = {
                name = "AudibleSync";
                group = "Media";
                description = "Audible library archive + sync tracker (weekly archive = audible-sync.timer)";
                # No Audible glyph exists in the dashboard-icons pack (checked
                # upstream 2026-11-01); openaudible.png is the nearest
                # semantic one — both former Audible tiles already used it.
                icon = "openaudible.png";
              };
              backup = {
                directory = "/mnt/pool/backups/audiblesync";
                filePattern = "audiblesync-db-*.sqlite";
                maxAgeHours = 25;
              };
            };
          };
        })
      ];
    };
}
