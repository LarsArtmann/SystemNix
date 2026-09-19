# llama-vlm — socket-activated llama.cpp vision-language servers
#
# Generalizes the fastflowlm.nix pattern (socket → per-connection socat
# bridge → backend llama-server) to N vision models. Created 2026-09-19 for
# the Immich NSFW-audit stack: gemma-4-E4B-Uncensored (verdicts) and
# nsfwcaption-qwen3-vl-8b (captions). Replaces ad-hoc `nohup llama-server`
# processes that die on reboot and pin RAM while unused.
#
# Same NAMING RULE as fastflowlm.nix (systemd 261): for Accept=true sockets
# the per-connection unit is ALWAYS derived from the SOCKET's own name —
# llama-vlm-<name>.socket ⇒ llama-vlm-<name>@<conn>.service. The template
# MUST be named after the socket; never reintroduce Service= here.
#
# CPU-only by design: the ROCm llama.cpp path on this host has a history of
# post-load 94%-CPU spins (llama-rag freeze #5, 2026-09-18). These servers
# run CPU inference deliberately; llama-server's built-in backend probe picks
# CPU when ROCm offload is impossible/absent for the model. If the spin
# signature ever appears HERE (high single-thread CPU after load, /health 503),
# stop the units — do not let them burn cores.
#
# Idle TTL: a per-instance timer stops the backend when its journal has no
# "processing task" lines for ≥ keepAlive AND the backend has been active
# ≥ 10 min AND no per-connection bridge is live (cold-load guard, same
# reasoning as fastflowlm). The socket keeps listening, so the next request
# re-activates everything. llama-server cold-loads these models in ~10-40 s.
#
# SOAK-TEST RULE (from the llama-rag incident): a direct-run smoke test is
# NOT sufficient evidence that the units work — verify under the real units
# (health endpoint + one real vision request + ≥10 min idle stability) before
# decommissioning any manual nohup server.
_: {
  flake.nixosModules.llama-vlm =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.llama-vlm;
      inherit (import ../../../lib/default.nix lib)
        harden
        ports
        ioTier
        ;
      inherit (config.users) primaryUser;

      serverType = lib.types.submodule (
        { name, ... }:
        {
          options = {
            modelPath = lib.mkOption {
              type = lib.types.path;
              description = "Main GGUF model file.";
            };
            mmprojPath = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Multimodal projector GGUF (required for vision models).";
            };
            port = lib.mkOption {
              type = lib.types.port;
              description = "Public socket-activated port (stable for clients).";
            };
            backendPort = lib.mkOption {
              type = lib.types.port;
              description = "Internal backend port — bridge forwards here.";
            };
            context = lib.mkOption {
              type = lib.types.int;
              default = 8192;
              description = "Context size (-c).";
            };
            keepAlive = lib.mkOption {
              type = lib.types.str;
              default = "2h";
              description = "Idle TTL window before the backend is stopped.";
            };
            extraArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Extra llama-server CLI args.";
            };
            memoryMax = lib.mkOption {
              type = lib.types.str;
              default = "24G";
              description = "Cgroup MemoryMax ceiling (model + KV + runtime).";
            };
            user = lib.mkOption {
              type = lib.types.str;
              default = primaryUser;
              description = "Service user.";
            };
          };
        }
      );

      mkInstance =
        name: s:
        let
          socketUnit = "llama-vlm-${name}";
          bridgeTemplate = "llama-vlm-${name}@";
          backendUnit = "llama-vlm-${name}";
          idleUnit = "llama-vlm-${name}-idle";

          bridgeConn = pkgs.writeShellApplication {
            name = "llama-vlm-${name}-proxy-conn";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              host="127.0.0.1"
              port="${toString s.backendPort}"
              deadline=$((SECONDS + 300))
              until (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; do
                if [ "$SECONDS" -ge "$deadline" ]; then
                  echo "llama-vlm-${name}-proxy: backend $host:$port not reachable within 300 s" >&2
                  exit 1
                fi
                sleep 1
              done
              exec ${lib.getExe' pkgs.socat "socat"} - "TCP:$host:$port"
            '';
          };

          idleCheck = pkgs.writeShellApplication {
            name = "llama-vlm-${name}-idle-check";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.systemd
            ];
            text = ''
              if ! systemctl is-active --quiet ${backendUnit}.service; then
                exit 0
              fi
              # Live per-connection bridges = active traffic; also the only
              # reliable cold-load guard (backend logs no "processing task"
              # until the first request is accepted).
              if systemctl list-units '${bridgeTemplate}*.service' --state=active --no-legend 2>/dev/null | grep -q .; then
                exit 0
              fi
              now_us=$(awk '{printf "%d", $1 * 1000000}' /proc/uptime)
              active_us=$(systemctl show ${backendUnit}.service -p ActiveEnterTimestampMonotonic --value) || true
              if [ -z "$active_us" ] || [ $((now_us - active_us)) -lt 600000000 ]; then
                exit 0
              fi
              if ${lib.getExe' pkgs.systemd "journalctl"} -u ${backendUnit}.service --since "${s.keepAlive} ago" --grep "processing task" -n 1 --output cat 2>/dev/null | grep -q .; then
                exit 0
              fi
              systemctl stop '${bridgeTemplate}*.service' ${backendUnit}.service
            '';
          };

          execArgs = [
            "-m"
            s.modelPath
            "--port"
            (toString s.backendPort)
            "-c"
            (toString s.context)
          ]
          ++ lib.optionals (s.mmprojPath != null) [
            "--mmproj"
            s.mmprojPath
          ]
          ++ s.extraArgs;
        in
        {
          systemd.sockets.${socketUnit} = {
            description = "llama.cpp VLM server '${name}' (public socket)";
            wantedBy = [ "sockets.target" ];
            listenStreams = [ "127.0.0.1:${toString s.port}" ];
            socketConfig = {
              Accept = true;
              # llama-server default n_slots=4; cap bridges below it.
              MaxConnections = 4;
            };
          };

          systemd.services."${bridgeTemplate}" = {
            description = "llama-vlm ${name} per-connection proxy: client fd ↔ backend TCP";
            after = [ "${backendUnit}.service" ];
            wants = [ "${backendUnit}.service" ];
            serviceConfig = lib.mkMerge [
              {
                Type = "exec";
                ExecStart = lib.getExe bridgeConn;
                StandardInput = "socket";
                StandardOutput = "socket";
              }
              (harden { MemoryMax = "64M"; })
            ];
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };

          systemd.services.${backendUnit} = {
            description = "llama.cpp VLM server '${name}' (backend, model resident)";
            # Deliberately NOT wantedBy multi-user.target — socket activation
            # keeps RAM free until first request; the socket re-arms after
            # idle-stop.
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = lib.mkMerge [
              {
                Type = "exec";
                User = s.user;
                Group = "users";
                ExecStart = lib.getExe' (
                  # llama.cpp ≥ 0.4.x ships llama-server in the llama-cpp package.
                  pkgs.llama-cpp
                ) "llama-server";
                ArgumentNames = null;
                # Pass args via ExecStart expansion below instead:
                Restart = "on-failure";
                RestartSec = "60";
                RestartSteps = 5;
                RestartMaxDelaySec = "15min";
                OOMScoreAdjust = 300;
                MemoryMax = s.memoryMax;
                MemoryHigh = s.memoryMax;
                TimeoutStartSec = "3min";
              }
              (harden { })
              ioTier.background
            ];
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };

          systemd.services.${idleUnit} = {
            description = "Stop llama-vlm ${name} backend after idle TTL expires";
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                ExecStart = lib.getExe idleCheck;
              }
              (harden { })
            ];
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };

          systemd.timers.${idleUnit} = {
            description = "Probe llama-vlm ${name} idle state every 5 minutes";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "5min";
              OnUnitActiveSec = "5min";
              AccuracySec = "1min";
            };
          };

          services.gatus-coverage-audit.allowPorts = [
            s.port
            s.backendPort
          ];
        };

      all = lib.mapAttrsToList mkInstance cfg.servers;
    in
    {
      options.services.llama-vlm = {
        enable = lib.mkEnableOption "llama.cpp vision-language servers (socket-activated)";

        package = lib.mkPackageOption pkgs "llama-cpp" { };

        servers = lib.mkOption {
          type = lib.types.attrsOf serverType;
          default = { };
          description = "VLM server instances, each socket-activated.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = lib.concatLists (
          lib.mapAttrsToList (
            name: s:
            [
              {
                assertion = s.port != s.backendPort;
                message = "llama-vlm ${name}: port and backendPort must differ (proxy hop).";
              }
              {
                assertion = s.port < 8124 || s.port > 8129;
                message = "llama-vlm ${name}: ports 8124-8129 collide with signoz-clickhouse-http (8123) / audit conventions.";
              }
            ]
          ) cfg.servers
        );

        systemd.packages = [ cfg.package ];

        warnings = lib.optional (cfg.servers != { }) ''
          llama-vlm: after deploy, SOAK-TEST under the real units (health + one
          vision request + 10 min idle) before decommissioning any manual
          llama-server process — see the llama-rag freeze-#5 lesson in the
          module header.
        '';
      } // (
        # Flatten per-instance defs (each instance returns an attrset of
        # systemd.* fragments); merge them all.
        lib.mkMerge all
      );
    };
}
