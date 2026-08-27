# CV — SystemNix wrapper around the upstream NixOS module.
#
# The upstream module (inputs.cv.nixosModules.default → services.cv-server)
# owns the service shape: package, typst pin (kept lockstep with the
# golden-tested compiler), generated config.yaml, content sync from the
# package share dir into the state dir, and baseline hardening.
#
# This file layers ONLY the SystemNix-specific concerns on top: sops
# EnvironmentFile wiring (CV_API_KEY), port registry, GOMEMLIMIT/MemoryMax,
# onFailure alert routing, and the reverse proxy / dashboard / monitoring
# integrations (caddy.nix, homepage.nix, gatus-config.nix).
{inputs, ...}: {
  flake.nixosModules.cv = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit
      (import ../../../lib/default.nix lib)
      ports
      onFailure
      harden
      ioTier
      serviceOneshotDefaults
      ;
    cfg = config.services.cv-server;
    domain = config.networking.domain;
    backupDir = "/mnt/pool/backups/cv";
  in {
    imports = [inputs.cv.nixosModules.default];

    config = lib.mkIf cfg.enable {
      services.cv-server = {
        package = lib.mkDefault inputs.cv.packages.${pkgs.stdenv.hostPlatform.system}.default;
        port = lib.mkDefault ports.cv;
        environmentFile = lib.mkDefault config.sops.templates."cv-env".path;

        settings = {
          # Forms (chat, A.Team, contact) POST same-origin through the
          # Caddy vHost — OriginCheck/CORS/nosurf require the vHost origin
          # in the allowlist. Loopback covers local curl/LAN-IP access.
          server.allowed_origins = [
            "https://cv.${domain}"
            "http://127.0.0.1:${toString ports.cv}"
            "http://localhost:${toString ports.cv}"
          ];
          # CV_ENVIRONMENT drives CSP strictness (production blocks inline
          # scripts without nonces) and skips dev rate-limit bypasses.
          environment = "production";
          # Tracked applications/evaluations must survive restarts: the
          # memory store (default) evaporates on every service restart,
          # and cv-backup below protects exactly this file. data/ ROOT
          # files are never touched by the upstream content sync (it only
          # replaces the 8 content SUBDIRS).
          pipeline = {
            event_store_driver = "sqlite";
            event_store_dsn = "/var/lib/cv/data/pipeline.sqlite";
          };
        };
      };

      systemd.services.cv-server = {
        after = ["sops-nix.service"];
        wants = ["sops-nix.service"];
        inherit onFailure;

        serviceConfig = lib.mkMerge [
          (harden {
            # Mostly idle; renders spike only during PDF export bursts.
            MemoryMax = "1G";
          })
          {
            # Keep GC headroom below the 1G cgroup cap (validate-gomemlimit).
            # OTEL_*: Go otlptracehttp — bare host:port, NO scheme (the SDK
            # builds the URL itself); registered in otel-endpoint-audit.
            Environment = [
              "GOMEMLIMIT=768MiB"
              "OTEL_EXPORTER_OTLP_ENDPOINT=localhost:${toString ports.signoz-otlp-http}"
              "OTEL_ENVIRONMENT=production"
            ];
          }
        ];
      };

      # Pipeline event-store backup: the tracked-applications state
      # (data/pipeline.sqlite) is irreplaceable. Online SQLite backup
      # (safe against the live WAL writer) onto the mirrored pool.
      systemd.services.cv-backup = {
        description = "CV pipeline SQLite backup (online .backup)";
        after = ["cv-server.service"];
        wants = ["cv-server.service"];
        inherit onFailure;
        startLimitBurst = 5;
        startLimitIntervalSec = 300;

        serviceConfig = lib.mkMerge [
          {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "cv-backup" ''
              set -euo pipefail
              db="/var/lib/cv/data/pipeline.sqlite"
              if [ ! -f "$db" ]; then
                echo "cv-backup: no pipeline.sqlite yet — nothing to back up"
                exit 0
              fi
              ts=$(date +%Y%m%dT%H%M%S)
              dst="${backupDir}/pipeline-$ts.sqlite"
              ${lib.getExe pkgs.sqlite} "$db" ".backup '$dst'"
              echo "cv-backup: wrote $dst"
            '';
            ReadWritePaths = [
              backupDir
              "/var/lib/cv"
            ];
          }
          (harden {})
          (serviceOneshotDefaults {})
          ioTier.background
        ];
      };

      systemd.timers.cv-backup = {
        description = "Nightly CV pipeline backup (03:17, staggered off the 01:00-03:00 peak)";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "*-*-* 03:17:00";
          Persistent = true;
          Unit = "cv-backup.service";
        };
      };

      systemd.tmpfiles.rules = [
        "d ${backupDir} 0755 root root -"
      ];
    };
  };
}
