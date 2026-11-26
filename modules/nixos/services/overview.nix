# Runbook: docs/services/overview.md
# Overview — SystemNix wrapper around the upstream overview module.
#
# Two problems make Overview return HTTP 503 after every deploy:
#   1. Overview runs project discovery exactly ONCE at startup and never retries.
#   2. Its discovery request to the PMA project-discovery daemon times out
#      (~2 min) whenever PMA is mid-scan on restart (PMA re-scans ~293 projects,
#      which is slow). Overview then caches a nil result and 503s forever.
#
# Mitigations layered here:
#   - ExecStartPre gate: wait for the daemon socket to answer before starting.
#     Fails (exit 1) with a clear warning if the daemon is not available,
#     preventing overview from starting and immediately crashing with exit 69.
#   - Eval-time assertion: if daemon mode is enabled but PMA is not, fail the
#     build with an actionable message instead of deploying a crash-loop.
#   - partOf PMA: restart Overview whenever PMA restarts (re-discover after PMA
#     recovers).
#   - discovery-watchdog timer: if Overview is 503 while the daemon is healthy
#     (PMA's scan finished), restart Overview so it re-discovers successfully.
#     This converges on its own once PMA settles, with no extra deploy.
#   - StartLimitBurst/StartLimitIntervalSec: placed at the top-level (maps to
#     [Unit] section) because upstream sets them in serviceConfig ([Service])
#     where systemd 261+ silently ignores them, causing infinite crash-loops.
{ inputs, ... }:
{
  flake.nixosModules.overview =
    {
      config,
      options,
      pkgs,
      lib,
      larsPackages,
      ...
    }:
    let
      cfg = config.services.overview;
      inherit (import ../../../lib/default.nix lib) ports ioTier;
      domain = config.networking.domain;
      daemonSock = "/run/project-discovery/daemon.sock";
      daemonMode = cfg.daemonSocket != "";

      primaryUser = config.users.primaryUser;
      projectsDir = "/home/${primaryUser}/projects";

      # ── Compliance evidence (BuildFlow) ───────────────────────────────────
      # The unprivileged overview user cannot read BuildFlow's state DB (it
      # lives under the primary user's 0700 home), so the documented daemon
      # recipe applies instead of the in-process source: a timer running AS
      # the primary user renders the frozen v1 JSON contract to a file the
      # service CAN read. Active exactly when the host points the upstream
      # option at that file (configuration.nix), so a host that leaves
      # complianceSource empty pays nothing.
      evidenceDir = "/var/lib/overview-evidence";
      complianceEvidenceFile = "${evidenceDir}/compliance.json";
      complianceEvidenceEnabled = cfg.complianceSource == "file:${complianceEvidenceFile}";
      # Single source of truth for Lars tool packages (lib/lars-packages.nix)
      # — the same derivations the fleet installs on PATH, shims included, so
      # the units can never drift from the CLI the owner has.
      inherit (larsPackages) buildflow;
      goHotspot = larsPackages.go-hotspot;

      # ── Code-risk hotspots (go-hotspot) ───────────────────────────────────
      # go-hotspot analyzes ONE repository per invocation, and the upstream
      # consumer feeds it the ABSOLUTE paths the discovery daemon reports
      # (~/projects), so the analysis must run against those paths.
      hotspotEnabled = cfg.hotspotSource == "auto";
      waitDaemonReady = pkgs.writeShellApplication {
        name = "overview-wait-daemon";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          end=$((SECONDS + 60))
          while [ $SECONDS -lt $end ]; do
            if curl -sf --max-time 2 --unix-socket ${daemonSock} \
              http://localhost/v1/health >/dev/null 2>&1; then
              exit 0
            fi
            sleep 1
          done
          echo "overview: project-discovery daemon not available at ${daemonSock} after 60s — not starting overview." >&2
          echo "Enable services.project-discovery-daemon or set services.overview.daemonSocket = \"\" for in-process discovery." >&2
          exit 1
        '';
      };
      # Overview caches a failed discovery and never retries. If it is 503 while
      # the daemon is healthy (PMA finished its startup scan), restart Overview
      # so it re-discovers. Runs as root so it can call systemctl restart.
      discoveryWatchdog = pkgs.writeShellApplication {
        name = "overview-discovery-watchdog";
        runtimeInputs = [
          pkgs.curl
          pkgs.systemd
        ];
        text = ''
          set -u
          ov_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://127.0.0.1:${toString ports.overview}/ 2>/dev/null || echo 000)
          # Only act on an explicit 503. Other codes (200, 000/down, redirects)
          # mean Overview is fine or not worth restarting.
          [ "$ov_status" = "503" ] || exit 0
          if ! curl -sf --max-time 3 --unix-socket ${daemonSock} http://localhost/v1/health >/dev/null 2>&1; then
            # Daemon not healthy either — restart would not help. Wait.
            exit 0
          fi
          echo "overview is 503 but the discovery daemon is healthy — restarting overview to re-discover"
          systemctl restart overview.service
        '';
      };

      # Renders the BuildFlow compliance evidence the dashboard's /compliance
      # heatmap consumes. Atomic (temp file + rename) because the service
      # re-reads the file on its TTL: a half-written JSON body would flip the
      # whole heatmap to Unknown.
      complianceEvidence = pkgs.writeShellApplication {
        name = "overview-compliance-evidence";
        runtimeInputs = [
          buildflow
          pkgs.coreutils
        ];
        text = ''
          set -euo pipefail
          tmp="$(mktemp "${evidenceDir}/compliance.XXXXXXXX")"
          trap 'rm -f "$tmp"' EXIT
          buildflow compliance --json --since 14d --stale-after 336h >"$tmp"
          chmod 0644 "$tmp"
          mv -f "$tmp" "${complianceEvidenceFile}"
          trap - EXIT
        '';
      };

      # git ≥2.35.2 refuses read-tree work on foreign-owned checkouts
      # ("dubious ownership") — the hotspot pass runs as the overview service
      # user over the primary user's repos.
      gitSafeConfig = pkgs.writeText "overview-gitconfig" ''
        [safe]
        	directory = *
      '';
    in
    {
      imports = [ inputs.overview.nixosModules.default ];

      config = lib.mkIf cfg.enable {
        # No vendorHash shim: the input floats on master (2026-10-25 owner
        # directive) and upstream's own vendorHash.nix is correct under the
        # pinned nixpkgs — first-hand probe at e7b2cbb: specified + got both
        # sha256-NQ0ICMtk+bY9fQDcLR8AkVEVaOv6/jmXv3kQHjS5dMM=. The old
        # NXdLbWt+ shim belonged to the rolled-back 4b48040 rev.

        # The upstream module renders OVERVIEW_HOTSPOT_COMMAND from this
        # option (default: a PATH lookup for "go-hotspot", which the unit's
        # sandboxed PATH never carries). Pin it to the store path.
        services.overview.hotspotCommand = lib.mkIf hotspotEnabled (
          lib.mkDefault "${goHotspot}/bin/go-hotspot"
        );

        assertions = lib.optional daemonMode {
          assertion =
            (config.services.project-discovery-daemon.enable or false)
            || (config.services.projects-management-automation.enableDiscoveryDaemon or false);
          message = ''
            overview.service is configured with daemonSocket = "${cfg.daemonSocket}"
            but no discovery daemon is enabled.
            The socket at ${daemonSock} is owned by the standalone
            project-discovery-daemon service (2026-09-07 flip) — either:
              1. Enable it: services.project-discovery-daemon.enable = true
              2. Use in-process discovery: services.overview.daemonSocket = ""
          '';
        };

        systemd = {
          services.overview = {
            # The socket consumer depends on the SOCKET OWNER, not PMA
            # (2026-10-08 ghost-socket fix completing the 2026-09-07 flip):
            # partOf PMA bounced overview on every PMA deploy/restart — the
            # exact coupling the standalone-daemon flip removed. PMA is just
            # another client of the daemon socket now.
            after = [ "project-discovery-daemon.service" ];
            wants = [ "project-discovery-daemon.service" ];
            partOf = [ "project-discovery-daemon.service" ];
            # Fix: upstream sets these in serviceConfig ([Service] section)
            # where systemd 261+ silently ignores them. Top-level options
            # map to [Unit] where they actually take effect.
            # NOTE: do NOT try to null out the upstream serviceConfig entries —
            # nixpkgs renders null as an empty key ("StartLimitBurst="), which
            # systemd rejects with a parse warning. Upstream moved them to the
            # top level (see LarsArtmann/overview module.nix); once the flake
            # input is bumped past ac307aa8 the stale [Service] copies vanish.
            startLimitBurst = 3;
            startLimitIntervalSec = 60;
            serviceConfig = lib.mkMerge [
              {
                ExecStartPre = lib.mkIf daemonMode "+${lib.getExe waitDaemonReady}";
                TimeoutStartSec = "3min";
              }
              (lib.mkIf hotspotEnabled {
                # Code-risk analysis reads the primary user's checkouts, which a
                # 0700 home makes impossible for a service user, and home-dir
                # ACLs are forbidden (mask-recalc trap, hermes 2026-08-20). A
                # fresh tmpfs over the home with ONLY the projects tree
                # bind-mounted in keeps every discovered absolute path valid
                # while exposing nothing else from the home.
                TemporaryFileSystem = "/home/${primaryUser}:ro";
                BindReadOnlyPaths = [ projectsDir ];
                ProtectHome = lib.mkForce false;
              })
              # Per-repo `git log --numstat` over the whole fleet is bulk IO on
              # the freeze-prone QLC root: background tier, never desktop's.
              (lib.mkIf hotspotEnabled ioTier.background)
            ];
            # go-hotspot shells out to `git` for the churn collection.
            path = lib.mkIf hotspotEnabled [ pkgs.git ];
            environment = {
              OTEL_EXPORTER_OTLP_ENDPOINT = lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";
            }
            // lib.optionalAttrs hotspotEnabled {
              # The home is a tmpfs — keep the XDG fallbacks writable.
              HOME = "/var/lib/overview";
              GIT_CONFIG_GLOBAL = gitSafeConfig;
            };
          };

          services.overview-discovery-watchdog = {
            description = "Restart Overview when it is 503 but the discovery daemon is healthy";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = lib.getExe discoveryWatchdog;
            };
          };

          timers.overview-discovery-watchdog = {
            description = "Periodically recover Overview from a stale 503 discovery failure";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "3min";
              OnUnitActiveSec = "2min";
              AccuracySec = "30s";
            };
          };

          # Compliance evidence refresher — the producer half of the
          # `file:` source documented upstream. Runs AS the primary user:
          # BuildFlow's state DB lives under that user's home (0700, so the
          # service cannot reach it) and its SQLite WAL needs writable
          # sidecars — a root run would leave root-owned -wal/-shm files in
          # the user's state dir.
          services.overview-compliance-evidence = lib.mkIf complianceEvidenceEnabled {
            description = "Render BuildFlow fleet-compliance evidence for Overview";
            serviceConfig = {
              Type = "oneshot";
              User = primaryUser;
              # `+` = privileged: the evidence dir must belong to the primary
              # user for the atomic rename, and tmpfiles application has
              # proven unreliable across switches (2026-11-04 lesson).
              ExecStartPre = "+${pkgs.coreutils}/bin/install -d -m 0750 -o ${primaryUser} -g ${cfg.group} ${evidenceDir}";
              ExecStart = lib.getExe complianceEvidence;
              TimeoutStartSec = "10min";
              PrivateTmp = true;
              NoNewPrivileges = true;
              ProtectSystem = "full";
            };
          };

          timers.overview-compliance-evidence = lib.mkIf complianceEvidenceEnabled {
            description = "Refresh Overview's BuildFlow compliance evidence";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "15min";
              OnUnitActiveSec = "6h";
              AccuracySec = "5min";
            };
          };
        };

        # Service-integration registry entry: the Overview homepage tile, the
        # overview vHost (Layer 2 — no native auth), and the Gatus checks
        # (backend :8083 liveness + full-chain vHost probe).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          overview = {
            inherit (cfg) enable;
            subdomain = "overview";
            port = ports.overview;
            vHost.layer = "protected";
            checks = [
              {
                name = "Overview";
                group = "Productivity";
                url = "http://localhost:${toString ports.overview}";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                  "[BODY] == pat(*<html*)"
                ];
                alert = "Overview dashboard down — project stats unavailable";
              }
              {
                # Full serving-chain probe (dnsblockd TLS + Caddy + LAN-bypass
                # forward-auth + backend) — catches the auth-gateway 502 class
                # while :8083 is green. Title-anchored body so a Caddy or
                # oauth2-proxy error page cannot phantom-green on status alone.
                name = "Overview vHost";
                group = "Productivity";
                url = "https://overview.${domain}/";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 2000"
                  "[BODY] == pat(*<title>Overview*)"
                ];
              }
            ];
            homepage = {
              name = "Overview";
              group = "Development";
              description = "Project Dashboard (Git Repos, Stats, Activity)";
              icon = "code.png";
            };
          };
        };
      };
    };
}
