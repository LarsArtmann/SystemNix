# Runbook: docs/services/journal.md
# journal-mesh — real-time x.v1 fact ingestion over NATS JetStream.
#
# Replaces the timer-shaped `journal-import` glue (bank-sync export → staging
# file → journal import → reconcile every 15 min) with the ADR-0009 seam:
# bank-sync publishes transactions.v1 envelopes the moment a sync cycle
# completes, and `journal mesh subscribe` ingests them through the SAME
# kernel import path the file drop uses. At-least-once + no-op-by-ID keeps
# redeliveries harmless; reconcile runs after a quiet window, so tier 1/2
# auto-booking follows the facts without polling.
#
# The broker is transport, never truth (sovereignty law): NATS holds a
# bounded replay buffer (90 days, file storage) and journal's event store
# stays the only record. Broker loss degrades latency; the kernel still
# boots, imports files, and closes periods. The file pipeline remains the
# break-glass path — `journal-import` is kept as an explicit opt-in module,
# never silently re-enabled alongside this one.
#
# Authority stays where it was: journal.yaml owns source mappings; the
# consumer ingests exactly the balances the producer sends, and unmapped
# balances surface as per-row rejections in the journal log (never silent).
_: {
  flake.nixosModules.journal-mesh =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.journal-mesh;
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
      options.services.journal-mesh = {
        enable = lib.mkEnableOption "real-time x.v1 mesh ingestion into the journal kernel (NATS JetStream consumer)";

        booksDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/${primaryUser}/books";
          description = ''
            The journal books home (journal.yaml + journal.db), shared with
            journal-backup and journal-serve. This unit mutates it (import +
            reconcile under the kernel's own gates).
          '';
        };

        url = lib.mkOption {
          type = lib.types.str;
          default = "nats://127.0.0.1:${toString ports.nats}";
          description = "NATS JetStream URL the consumer dials (loopback by default).";
        };

        subject = lib.mkOption {
          type = lib.types.str;
          default = "mesh.banksync.transactions.v1";
          description = ''
            Seam subject. ADR-0009 names it mesh.<producer>.<fact>.v1.
            Cross-surface contract: keep in sync with journal's
            internal/mesh pin test and bank-sync's
            TestMeshSeamCoordinatesAgreeWithJournal.
          '';
        };

        stream = lib.mkOption {
          type = lib.types.str;
          default = "TRANSACTIONS_V1";
          description = ''
            JetStream stream that stores the seam subject. Same
            cross-surface contract as the subject option.
          '';
        };

        durable = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = ''
            Durable consumer name override; empty (the default) lets the
            kernel derive one per books database
            (journal-transactions-v1-<db-path hash>). Two books homes
            sharing one durable would steal each other's deliveries —
            leave this empty unless a seam shares books across hosts.
          '';
        };

        reconcile = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Run the matcher after the seam goes quiet (tier 1/2 auto-book,
            tier 3 proposals). Judgment stays human: confirm/reject/waive
            remain operator actions on the Exceptions queue.
          '';
        };

        reconcileDebounce = lib.mkOption {
          type = lib.types.str;
          default = "5s";
          description = "Quiet window before reconcile runs (coalesces a cycle's envelopes).";
        };

        broker = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Bring up the local nats-server (services.nats, JetStream on).
              Set false when another module owns the broker or a remote NATS
              is used.
            '';
          };

          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/var/lib/nats";
            description = ''
              JetStream store dir. Deliberately NOT on /mnt/pool: the stream
              is a bounded transport buffer (90-day replay), not truth — a
              pool dropout must never gate the kernel's real-time ingress,
              and the nixpkgs module's StateDirectory handling only covers
              the default path.
            '';
          };
        };

        package = lib.mkOption {
          type = lib.types.package;
          # Single source of truth: the same store path journal-serve and
          # journal-backup consume. Do NOT add another overrideAttrs copy.
          default = config.services.journal-serve.package;
          defaultText = lib.literalExpression "config.services.journal-serve.package";
          description = "journal package to run the mesh consumer with.";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (lib.mkIf cfg.broker.enable {
            services.nats = {
              enable = true;
              jetstream = true;
              port = ports.nats;
              dataDir = cfg.broker.dataDir;
              # The nixpkgs module binds 0.0.0.0 unless told otherwise; this
              # broker is single-host transport, so loopback ONLY (matching
              # the journal-serve posture — no vHost, no external client).
              settings.host = "127.0.0.1";
            };

            # nixpkgs-rendered unit: overlay the IO tier here (the audit's
            # stock-unit overlay pattern). JetStream fsyncs every message
            # batch to /var/lib/nats (QLC root); the broker is the mesh's
            # latency-critical transport, so it queues above its own
            # BE/6 consumer (journal-mesh) but below desktop (BE/3).
            systemd.services.nats.serviceConfig = ioTier.heavyDB;
          })

          {
            systemd.services.journal-mesh = {
              description = "journal mesh consumer: real-time x.v1 ingest + reconcile (NATS JetStream)";
              inherit onFailure;

              after = [ "network.target" ] ++ lib.optional cfg.broker.enable "nats.service";
              wants = lib.optional cfg.broker.enable "nats.service";
              wantedBy = [ "multi-user.target" ];

              # Clean skip on hosts without books — never a failed unit.
              unitConfig.ConditionPathExists = [ "${cfg.booksDir}/journal.yaml" ];

              # A broker restart is expected; retry with backoff instead of
              # letting a short outage exhaust the start limit.
              startLimitBurst = 20;
              startLimitIntervalSec = 300;

              serviceConfig = lib.mkMerge [
                (harden {
                  MemoryMax = "1G";
                  ProtectHome = "read-only";
                  ReadWritePaths = [ cfg.booksDir ];
                })
                (serviceDefaults { })
                ioTier.background
                {
                  Type = "notify";
                  User = primaryUser;
                  Group = "users";
                  WorkingDirectory = cfg.booksDir;
                  Environment = [ "HOME=/home/${primaryUser}" ];
                  ExecStart = lib.concatStringsSep " " (
                    [
                      "${lib.getExe' cfg.package "journal"}"
                      "--config journal.yaml"
                      "mesh subscribe"
                      "--url ${cfg.url}"
                      "--subject ${cfg.subject}"
                      "--stream ${cfg.stream}"
                      "--reconcile=${lib.boolToString cfg.reconcile}"
                      "--reconcile-debounce ${cfg.reconcileDebounce}"
                    ]
                    ++ lib.optionals (cfg.durable != "") [ "--durable ${cfg.durable}" ]
                  );
                  RestartSec = "5s";
                }
              ];
            };
          }

        ]
      );
    };
}
