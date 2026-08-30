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
{ inputs, ... }: {
  flake.nixosModules.cv =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        ports
        onFailure
        harden
        ioTier
        serviceOneshotDefaults
        ;
      cfg = config.services.cv-server;
      domain = config.networking.domain;
      backupDir = "/mnt/pool/backups/cv";
    in
    {
      imports = [ inputs.cv.nixosModules.default ];

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
              # The generated config.yaml IS the whole config (settings are
              # not merged over the repo's config.yaml), so the portal list
              # must live HERE or the server has nothing to scan. Keep in
              # sync with the CV repo's config.yaml pipeline.portals.
              # freelance.de is deliberately absent (WAF + crawling
              # guideline: detail-page URLs only). Skill-slug URLs
              # (/projects/golang, ...) are dead anonymously — never add
              # them (see CV AGENTS.md, Portal Scanners).
              portals = [
                {
                  url = "https://www.freelancermap.com/projects";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/remote";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/germany";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/austria";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/switzerland";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/development";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/it";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/engineering";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/software-development";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
              ];
            };
            # journald/SigNoz ingestion friendliness: structured JSON lines
            # instead of the text default (internal/config LogFormatJSON).
            logging.format = "json";
            # Absolute state-dir path: the default (data/graphrag.sqlite) is
            # CWD-relative, which happens to resolve correctly today but only
            # because WorkingDirectory = /var/lib/cv. Pin it so graphrag can
            # be enabled later without a relative-path surprise (module is
            # disabled by default; the key is inert until then).
            graphrag.store_dsn = "/var/lib/cv/data/graphrag.sqlite";
          };
        };

        systemd.services.cv-server = {
          after = [ "sops-nix.service" ];
          wants = [ "sops-nix.service" ];
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
          after = [ "cv-server.service" ];
          wants = [ "cv-server.service" ];
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
            (harden { })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        systemd.timers.cv-backup = {
          description = "Nightly CV pipeline backup (03:17, staggered off the 01:00-03:00 peak)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 03:17:00";
            Persistent = true;
            Unit = "cv-backup.service";
          };
        };

        # Continuous funnel automation: every 6h, scan ALL configured portals
        # and bulk-evaluate tracked-but-unscored applications. Drives the
        # server over HTTP (the server owns the SQLite lease — a CLI timer
        # against the same store file would conflict with it). Both endpoints
        # are async and 409-guarded against double runs, so an overlap with a
        # dashboard-triggered run is harmless. The scan itself evaluates every
        # newly ingested job inline; the follow-up no-force evaluate pass only
        # catches rows whose scan-time evaluation failed. Forced re-scoring of
        # the whole inventory stays MANUAL (criteria/keyword changes) — a
        # periodic force pass would append one job.evaluated event per tracked
        # application per run for identical verdicts.
        #
        # Requires a CV package whose server skips CSRF for X-API-Key-bearing
        # requests (CV repo 2026-08-29 or later); older servers answer 403
        # csrf_invalid to these POSTs. Deploy the flake-input bump together
        # with this timer.
        systemd.services.cv-scan = {
          description = "CV pipeline portal scan + bulk evaluation (HTTP, lease-safe)";
          after = [ "cv-server.service" ];
          wants = [ "cv-server.service" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              # Same sops template the server reads — the systemd manager
              # injects it, so the hardened sandbox never touches the
              # secret file itself.
              EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [
                cfg.environmentFile
              ];
              ExecStart = pkgs.writeShellScript "cv-scan" ''
                set -euo pipefail
                base="http://127.0.0.1:${toString cfg.port}"
                key="''${CV_API_KEY:?CV_API_KEY missing — check the cv-env sops template}"
                curl_bin="${lib.getExe pkgs.curl}"

                # 200 = accepted, 409 = a scan/evaluation is already running
                # (dashboard button or previous tick) — both fine. Anything
                # else fails the unit so onFailure alerting picks it up.
                post() {
                  code=$("$curl_bin" -sS -o /dev/null -w '%{http_code}' -X POST \
                    -H "X-API-Key: $key" -H 'Content-Type: application/json' "$1")
                  case "$code" in
                    200|409) echo "cv-scan: $1 -> $code (ok)" ;;
                    *) echo "cv-scan: $1 -> $code (unexpected)" >&2; exit 1 ;;
                  esac
                }

                post "$base/api/pipeline/scan"
                post "$base/api/pipeline/evaluate-tracked"
              '';
            }
            (harden { })
            (serviceOneshotDefaults { })
          ];
        };

        systemd.timers.cv-scan = {
          description = "Continuous CV pipeline scanning (every 6h, :23 stagger off the top of the hour)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 00/6:23:00";
            Persistent = true;
            Unit = "cv-scan.service";
          };
        };

        systemd.tmpfiles.rules = [
          "d ${backupDir} 0755 root root -"
        ];
      };
    };
}
