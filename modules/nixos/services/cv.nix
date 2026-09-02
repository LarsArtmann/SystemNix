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

      options.services.cv-server.profileProbe = {
        enable = lib.mkEnableOption ''
          Weekly platform-session validity probe: runs
          `cv profile accounts --probe --all` against the operator checkout.
          Exit 0 = all sessions valid; exit 3 = at least one INVALID session,
          which FAILS the unit so onFailure alerts — logins rot visibly
          instead of at apply-time. Disabled by default: the probe is
          operator-local state (never a server surface) and pulls chromium
          into the closure.
        '';

        chromiumPackage = lib.mkOption {
          type = lib.types.package;
          default = pkgs.chromium;
          description = "Chromium derivation exported as CHROMIUM_EXECUTABLE_PATH for the Playwright-based probe (tests substitute a stub to keep the VM closure light).";
        };

        workingDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/home/lars/projects/CV";
          description = "CV checkout the probe runs from; session state (data/accounts) and the generated bun probe scripts live under it.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.cv-server = {
          # TEMPORARY (2026-09-02): upstream's vendorHash pins went stale
          # AGAIN — rev 7b2819a pinned BeI+…, its tree actually builds
          # VOXn…; the relock to d2f2752b carries mybz… ("tree-proven" in
          # 2aa17b68 — proven against the DIRTY WORKTREE, not the committed
          # tree; the classic CV source-only-churn class) while the committed
          # tree builds 9sLO…. Every commit's full `nix flake check` and
          # every deploy fails on the go-modules FOD until upstream
          # (LarsArtmann/CV) pushes a correct pin. Overridden with the
          # measured hash for d2f2752b to unblock; DROP this override the
          # moment upstream refreshes its vendorHash past d2f2752b.
          package = lib.mkDefault (
            inputs.cv.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (_old: {
              vendorHash = "sha256-9sLOrucubfamNchRkGrr2DyfY3gEl4fI5Dkqzt9wBsg=";
            })
          );
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

        # Mount-gated creator for the pool-side backup dir (atticd-storage-dir
        # pattern). cv-backup's ReadWritePaths requires the path to EXIST
        # before namespace setup: during the 9-day DAS outage a root-fs shadow
        # dir under /mnt/pool let cv-backup pass setup while early-exiting
        # ("no pipeline.sqlite yet"); the 2026-08-31 pool remount then failed
        # the boot catch-up run with 226/NAMESPACE because the POOL filesystem
        # never had the dir. tmpfiles must NOT create it either — pre-mount it
        # would land on the root fs and shadow the pool copy.
        systemd.services.cv-backup-dir = {
          description = "Create CV backup directory on the HDD pool";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ backupDir ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            # ReadWritePaths targets the PARENT (/mnt/pool/backups), which
            # always exists — pointing it at backupDir itself would 226 the
            # creator before it can mkdir the leaf.
            (harden {
              MemoryMax = "128M";
              ReadWritePaths = [ "/mnt/pool/backups" ];
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            mkdir -p ${backupDir}
            chmod 0755 ${backupDir}
          '';
        };

        # Pipeline event-store backup: the tracked-applications state
        # (data/pipeline.sqlite) is irreplaceable. Online SQLite backup
        # (safe against the live WAL writer) onto the mirrored pool.
        systemd.services.cv-backup = {
          description = "CV pipeline SQLite backup (online .backup)";
          after = [
            "cv-server.service"
            "cv-backup-dir.service"
          ];
          wants = [
            "cv-server.service"
            "cv-backup-dir.service"
          ];
          # Orders the unit AFTER the pool mount (a detached DAS fails the
          # run as a clean dependency error instead of 226/NAMESPACE — the
          # btrbk doctrine), and fixes the boot-race where Persistent timer
          # catch-up fires seconds before mnt-pool.mount completes.
          unitConfig.RequiresMountsFor = [ backupDir ];
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
            (harden {
              # cv-server's data/ is 0750 cv:cv. Root with an EMPTY
              # CapabilityBoundingSet obeys DAC bits and cannot even stat
              # through that dir: `[ ! -f $db ]` was TRUE with the DB sitting
              # right there, and every run exited 0 "no pipeline.sqlite yet" —
              # a silently green no-op backup since deployment (caught by the
              # 2026-08-31 VM regression test, masked until then by the 226).
              # CAP_DAC_READ_SEARCH = read-only traversal, the exact
              # backup-health-metrics precedent for root collectors reading
              # foreign-owned trees. Writing still targets root-owned paths.
              CapabilityBoundingSet = "CAP_DAC_READ_SEARCH";
            })
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

        # Platform-session validity probe (plan T23, 2026-08-30): weekly
        # `cv profile accounts --probe --all` against the operator checkout.
        # The probe reads/WRITES operator-local state (the accounts ledger +
        # session files under the checkout), so it runs as the operator user
        # with home access — deliberately NOT part of the hardened server
        # surface. Exit 3 (>=1 invalid session) fails the unit on purpose:
        # onFailure alerting is the entire value of the timer.
        systemd.services.cv-profile-probe = lib.mkIf cfg.profileProbe.enable {
          description = "CV platform session validity probe (exit 3 = invalid session -> alert)";
          inherit onFailure;
          startLimitBurst = 2;
          startLimitIntervalSec = 600;

          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "lars";
              Group = "users";
              WorkingDirectory = cfg.profileProbe.workingDirectory;
              Environment = [
                "HOME=/home/lars"
                "CHROMIUM_EXECUTABLE_PATH=${cfg.profileProbe.chromiumPackage}/bin/chromium"
                "PLAYWRIGHT_BROWSERS_PATH=/home/lars/tmp/playwright"
                "PATH=${
                  lib.makeBinPath [
                    pkgs.bun
                    pkgs.coreutils
                    pkgs.gnugrep
                  ]
                }:/run/current-system/sw/bin"
              ];
              ExecStart = "${lib.getExe cfg.package} profile accounts --probe --all";
            }
            (harden {
              # The probe mutates operator state under /home and runs a
              # browser; the server-grade home protection must not apply.
              ProtectHome = false;
            })
            (serviceOneshotDefaults { })
          ];
        };

        systemd.timers.cv-profile-probe = lib.mkIf cfg.profileProbe.enable {
          description = "Weekly CV platform session validity probe (Mon 09:41, off the backup window)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "Mon *-*-* 09:41:00";
            Persistent = true;
            Unit = "cv-profile-probe.service";
          };
        };

        systemd.tmpfiles.rules = [
          "d ${backupDir} 0755 root root -"
        ];
      };
    };
}
