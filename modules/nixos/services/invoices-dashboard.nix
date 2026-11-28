# Runbook: docs/services/invoices-dashboard.md
# invoices-dashboard — read-model dashboard over the invoice SQLite DB
# (`invoices dashboard`, github:LarsArtmann/invoices). Loopback
# (127.0.0.1:8110, BY UPSTREAM DESIGN: internal/dashboard defaultHost is
# "loopback only: single-user CLI dashboard, never LAN-exposed", pinned by
# server_loopback_test) behind the protected registry vHost
# invoices.home.lan (oauth2-proxy forward-auth for external clients, LAN
# bypass): the dashboard has NO authentication of its own and shows
# revenue/client data — the journal-serve posture.
#
# THIN LAYER (2026-11-28) over inputs.invoices.nixosModules.default: the
# upstream repo owns the options, the unit shapes, the backup script and
# the portable hardening (extraction recipe in
# docs/agents/integration-registry.md). This file adds ONLY the host
# facts: port registry, site paths and account, alert routing (onFailure),
# memory ceilings, the background I/O tier, the pool-dir unit for the
# backup directory on the removable /mnt/pool mount, and the registry
# entry (vHost, Gatus checks, dashboard tile, backup freshness).
#
# BOOT CONTRACT: `invoices dashboard` REQUIRES config.yaml in the CWD
# (viper AddConfigPath "."; no --config flag) and exits 69 without it.
# The unit's WorkingDirectory is therefore the data dir ~/invoices, and
# the PRODUCTION config.yaml lives there — the repo checkout's config.yaml
# (environment: DEVELOPMENT) stays the dev copy. /health aggregates
# database + read-models checks and answers 503 when either fails.
#
# Data ownership (docs/agents/data-ownership.md): the SQLite store in
# ~/invoices is the TRUTH for invoice records. The invoices CLI is the
# write path (invoice/solcom/importallocations commands with --db
# pointing here); the dashboard is the read window + facts projection
# onto the same single store. USER data outside /var/lib, deliberately
# (journal books precedent): the unit runs as the primary user with a
# single ReadWritePaths hole for the data dir.
{ inputs, ... }: {
  flake.nixosModules.invoices-dashboard =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      cfg = config.services.invoices-dashboard;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        mkPoolDirUnit
        onFailure
        ports
        ioTier
        ;
      primaryUser = config.users.primaryUser;
      backupDir = "/mnt/pool/backups/invoices";
    in
    {
      imports = [ inputs.invoices.nixosModules.default ];

      config = lib.mkIf cfg.enable {
        services.invoices-dashboard = {
          port = ports.invoices-dashboard;
          dataDir = "/home/${primaryUser}/invoices";
          user = primaryUser;
          group = "users";
          createUser = false;
          home = "/home/${primaryUser}";
          onFailureUnits = onFailure;
          backup = {
            directory = backupDir;
            # The directory lives on the removable pool mount: the
            # mount-gated invoices-dashboard-backup-dir unit creates it
            # (tmpfiles would leave a shadow dir on the root filesystem).
            createDirectory = false;
            serviceDeps = [
              "invoices-dashboard.service"
              "invoices-dashboard-backup-dir.service"
            ];
            timerAfter = [ "mnt-pool.mount" ];
            onFailureUnits = onFailure;
          };
        };

        systemd.services.invoices-dashboard.serviceConfig = lib.mkMerge [
          # No ReadWritePaths here: upstream owns it through mkDefault.
          (harden {
            MemoryMax = "1G";
            ProtectHome = "read-only";
          })
          (serviceDefaults { })
          ioTier.background
        ];

        systemd.services.invoices-dashboard-backup.serviceConfig = lib.mkMerge [
          {
            # The data dir is owned by the primary user; this unit runs as
            # root and only needs to READ the DB + config —
            # ProtectHome=read-only keeps /home visible read-only while
            # the pool dir carries the only RW hole.
            # CAP_DAC_READ_SEARCH: /home/<user> itself is 0700, and
            # harden{}'s empty default CapabilityBoundingSet strips
            # root's DAC bypass, so without this cap the unit cannot
            # even STAT the DB (live 2026-11-10: "no DB — nothing to
            # back up" while the file existed; cv-backup precedent).
            # READ_SEARCH grants traversal+read only — pool writes stay
            # ordinary root-owner DAC (cv.nix backup pattern).
            CapabilityBoundingSet = "CAP_DAC_READ_SEARCH";
          }
          (harden {
            MemoryMax = "1G";
            ProtectHome = "read-only";
          })
          (serviceOneshotDefaults { })
          ioTier.background
        ];

        # Pool dir creator — the ONLY sanctioned creator of a directory
        # under the removable /mnt/pool mount (mkPoolDirUnit invariants).
        systemd.services.invoices-dashboard-backup-dir = mkPoolDirUnit {
          description = "Create invoices DB backup directory on the HDD pool";
          directory = backupDir;
        };

        # Service-integration registry entry: fans out to the Caddy vHost
        # (protected — billing data, no app auth), the Gatus checks, the
        # dashboard tile, backup freshness, and system-health metrics.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          invoices-dashboard = {
            enable = true;
            inherit (cfg) port;
            subdomain = "invoices";
            vHost.layer = "protected";
            checks = [
              {
                name = "Invoices dashboard health";
                group = "Finance";
                path = "/health";
                interval = "30s";
                conditions = [
                  "[STATUS] == 200"
                  # Honest health: /health aggregates the database +
                  # read-models checks and answers 503 when either fails,
                  # so the body shape proves both legs, not just liveness.
                  "[BODY] == pat(*\"status\":\"healthy\"*)"
                ];
                alert = "Invoices dashboard down — invoices.home.lan unreachable or its DB/read-model checks fail. Check: systemctl status invoices-dashboard, journalctl -u invoices-dashboard -n 50.";
              }
              {
                name = "Invoices dashboard page";
                group = "Finance";
                path = "/";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                  # Functional, not just liveness: the dashboard page
                  # title is "Invoice Ledger" (since invoices
                  # b4f32117; was "Invoice Dashboard") — an error shell
                  # would not carry it.
                  "[BODY] == pat(*Invoice Ledger</title>*)"
                ];
                alert = "Invoices dashboard page broken — / no longer renders the Invoice Ledger page. Check: systemctl status invoices-dashboard, journalctl -u invoices-dashboard -n 50.";
              }
            ];
            homepage = {
              name = "Invoices";
              group = "Finance";
              description = "Invoice dashboard — revenue, status, live facts";
              # Closest pack glyph for invoicing (dashboard-icons
              # invoiceplane); no project-specific icon exists.
              icon = "invoiceplane.png";
            };
            backup = {
              directory = backupDir;
              filePattern = "invoices-db-*.db.gz";
              maxAgeHours = 25;
            };
            monitored = true;
          };
        };
      };
    };
}
