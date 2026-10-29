# Runbook: docs/services/journal.md
# journal-serve — the Hauptbuch web dashboard over the accounting kernel.
#
# Upstream tier-0 security posture (journal cmd/journal/serve.go): the
# dashboard carries NO authentication until T16 passkey login ships, so
# `journal serve` refuses any non-loopback bind — refusing loudly beats
# silently exposing a whole accounting kernel. This unit keeps that
# contract: it binds 127.0.0.1 ONLY and is fronted by the registry vHost
# (journal.home.lan, vHost.layer = "protected") — oauth2-proxy forward-auth
# for external clients, LAN bypass — the owner's g-2 answer (2026-10-26):
# "behind the same reverse proxy/domain that serves bank-sync's dashboard",
# which also fixes the T16 WebAuthn RP ID (journal.home.lan).
#
# Same books-home contract as journal-backup.nix (the sibling module):
#   - books live in ~/books, USER data outside /var/lib; the unit runs as
#     the primary user with a single ReadWritePaths hole for the books dir
#     (the dashboard MUTATES: waive + reconcile write to the kernel)
#   - WorkingDirectory = books dir: config's `database: journal.db` is
#     CWD-relative (config.AbsoluteDatabase → filepath.Abs)
#   - a missing books dir is a clean condition-skip, never a failure
#   - the serve CLI handles graceful drain itself (10s, SIGTERM → context
#     cancel), so no TimeoutStopSec override is needed
{ inputs, ... }: {
  flake.nixosModules.journal-serve =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.services.journal-serve;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        ports
        ioTier
        ;
      primaryUser = config.users.primaryUser;
    in
    {
      options.services.journal-serve = {
        enable = lib.mkEnableOption "the Hauptbuch web dashboard (journal serve, loopback-only) with an authenticated registry vHost in front";

        booksDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/${primaryUser}/books";
          description = ''
            The journal books home (journal.yaml + journal.db + charts),
            shared with journal-backup. Owned by the primary user and
            managed with the journal CLI; this unit serves the dashboard
            over it and may mutate it (waive, reconcile).
          '';
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.journalServe;
          description = "Loopback port for `journal serve`. Upstream CLI default (8484); also fronts the registry vHost.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          # Same store path as the PATH binary (lib/lars-packages.nix
          # journal = flakePkg inputs.journal) — single source of truth.
          # vendorHash shim 2026-10-29 float: journal@50b4941 spec R6w7rVD9…,
          # got OzU6YCvB… (first-hand,
          # ~/.cache/lockfloat/float-proof-20261029-180630.log); mirrors the
          # flakePkgShim in lars-packages.nix — edit ALL THREE.
          default = inputs.journal.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs {
            vendorHash = "sha256-OzU6YCvBTkDl9Jfj5fCOAczSzYMPbv397a7BuDF2rdA=";
          };
          defaultText = lib.literalExpression "inputs.journal.packages.\${pkgs.stdenv.hostPlatform.system}.default";
          description = "journal package to serve the dashboard with.";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            systemd.services.journal-serve = {
              description = "Hauptbuch web dashboard over the journal kernel (loopback, registry vHost in front)";
              inherit onFailure;
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              # Clean skip on hosts without books — never a failed unit.
              unitConfig.ConditionPathExists = [ "${cfg.booksDir}/journal.yaml" ];

              # Flapping the dashboard restart-hammers the SQLite WAL for no
              # gain; generous start-limit window.
              startLimitBurst = 5;
              startLimitIntervalSec = 300;

              serviceConfig = lib.mkMerge [
                (harden {
                  MemoryMax = "1G";
                  # Books live under /home: read-only home, one RW hole for the
                  # books dir (the dashboard's mutations — waive, reconcile —
                  # write the DB + WAL siblings).
                  ProtectHome = "read-only";
                  ReadWritePaths = [ cfg.booksDir ];
                })
                (serviceDefaults { })
                # Interactive dashboard, but the kernel rides SQLite on the QLC
                # root — never compete with the desktop for I/O.
                ioTier.background
                {
                  User = primaryUser;
                  Group = "users";
                  WorkingDirectory = cfg.booksDir;
                  Environment = [ "HOME=/home/${primaryUser}" ];
                  ExecStart = "${lib.getExe' cfg.package "journal"} --config journal.yaml serve --addr 127.0.0.1:${toString cfg.port}";
                }
              ];
            };
          }

          # Service-integration registry entry: fans out to the Caddy vHost
          # (Layer 2 protected — money data minimum exposure, bank-sync's
          # posture), the Gatus check, and the dashboard tile.
          (lib.optionalAttrs (options ? services.integration) {
            services.integration = lib.mkIf cfg.enable {
              journal-serve = {
                inherit (cfg)
                  enable
                  port
                  ;
                subdomain = "journal";
                vHost.layer = "protected";
                checks = [
                  {
                    name = "Journal Hauptbuch";
                    group = "Finance";
                    url = "http://127.0.0.1:${toString cfg.port}/";
                    interval = "60s";
                    conditions = [
                      "[STATUS] == 200"
                      "[RESPONSE_TIME] < 1000"
                      # Functional, not just liveness: every dashboard page
                      # title carries "· Hauptbuch" (views.go pageProps) —
                      # an error shell would not.
                      "[BODY] == pat(*Hauptbuch*)"
                    ];
                    alert = "Hauptbuch dashboard down — the journal accounting kernel's web UI at journal.home.lan is unreachable. Check: systemctl status journal-serve, journalctl -u journal-serve -n 50.";
                  }
                ];
                homepage = {
                  name = "Hauptbuch";
                  group = "Finance";
                  description = "Journal accounting kernel — status, exceptions, reconcile";
                  # The pack has no ledger/journal glyph; firefly-iii is the
                  # closest double-entry bookkeeping icon (bank-sync uses
                  # google-finance.png the same way).
                  icon = "firefly-iii.png";
                };
              };
            };
          })
        ]
      );
    };
}
