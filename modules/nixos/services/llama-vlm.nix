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
# NIX EVALUATION NOTE: all dynamic-key attrsets (systemd.sockets,
# systemd.services, systemd.timers) are built with mapAttrs UNDER STATIC
# option paths. Do NOT convert this to a `mkMerge (map ...) instances` list
# at the config spine — forcing a definition list that reads
# `config.services.llama-vlm` recurses through `_module.freeformType`
# (live incident 2026-09-19).
#
# CPU-only by design: the ROCm llama.cpp path on this host has a history of
# post-load 94%-CPU spins (llama-rag freeze #5, 2026-09-18). These servers
# run CPU inference; llama-server picks CPU when the model cannot offload.
# If the spin signature ever appears HERE (high single-thread CPU after
# load, /health 503), stop the units — do not let them burn cores.
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
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.llama-vlm;
      inherit (import ../../../lib/default.nix lib)
        harden
        ioTier
        ;
      inherit (config.users) primaryUser;

      serverType = lib.types.submodule {
        options = {
          modelPath = lib.mkOption {
            # str, not path: these are multi-GB runtime files on /data —
            # types.path would copy them into the nix store (and forbids
            # absolute paths in pure eval). Only ever interpolated into
            # ExecStart args, so a string is the honest type.
            type = lib.types.str;
            description = "Main GGUF model file.";
          };
          mmprojPath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
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
            description = "Extra llama-server CLI args (each element = one argv token).";
          };
          memoryMax = lib.mkOption {
            type = lib.types.str;
            default = "24G";
            description = "Cgroup MemoryMax ceiling (model + KV + runtime).";
          };
          user = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Service user (null = primary user).";
          };
        };
      };

      # NOTE: systemd.serviceConfig.ExecStart takes ONE command LINE per entry —
      # a Nix list renders as MULTIPLE ExecStart lines (systemd rejects the unit
      # at load: the argv tokens are not absolute executable paths). Join to a
      # single string (caught by pre-deploy-check §12, 2026-09-19).
      execStart =
        s:
        lib.concatStringsSep " " (
          [
            (lib.getExe' cfg.package "llama-server")
            "-m"
            "${s.modelPath}"
            "--port"
            (toString s.backendPort)
            "-c"
            (toString s.context)
          ]
          ++ lib.optionals (s.mmprojPath != null) [
            "--mmproj"
            "${s.mmprojPath}"
          ]
          ++ s.extraArgs
        );

      bridgeConn =
        name: s:
        pkgs.writeShellApplication {
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

      idleCheck =
        name: s:
        pkgs.writeShellApplication {
          name = "llama-vlm-${name}-idle-check";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.systemd
          ];
          text = ''
            if ! systemctl is-active --quiet llama-vlm-${name}.service; then
              exit 0
            fi
            # Live per-connection bridges = active traffic; also the only
            # reliable cold-load guard (the backend logs no "processing
            # task" until the first request is accepted).
            if systemctl list-units 'llama-vlm-${name}@*.service' --state=active --no-legend 2>/dev/null | grep -q .; then
              exit 0
            fi
            now_us=$(awk '{printf "%d", $1 * 1000000}' /proc/uptime)
            active_us=$(systemctl show llama-vlm-${name}.service -p ActiveEnterTimestampMonotonic --value) || true
            if [ -z "$active_us" ] || [ $((now_us - active_us)) -lt 600000000 ]; then
              exit 0
            fi
            if ${lib.getExe' pkgs.systemd "journalctl"} -u llama-vlm-${name}.service --since "${s.keepAlive} ago" --grep "processing task" -n 1 --output cat 2>/dev/null | grep -q .; then
              exit 0
            fi
            systemctl stop 'llama-vlm-${name}@*.service' llama-vlm-${name}.service
          '';
        };
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
          lib.mapAttrsToList (name: s: [
            {
              assertion = s.port != s.backendPort;
              message = "llama-vlm ${name}: port and backendPort must differ (proxy hop).";
            }
          ]) cfg.servers
        );

        warnings = lib.optional (cfg.servers != { }) ''
          llama-vlm: after deploy, SOAK-TEST under the real units (health + one
          vision request + 10 min idle stability) before decommissioning any
          manual llama-server process — see the llama-rag freeze-#5 lesson in
          the module header.
        '';

        systemd.sockets = lib.mapAttrs' (
          name: s:
          lib.nameValuePair "llama-vlm-${name}" {
            description = "llama.cpp VLM server '${name}' (public socket)";
            wantedBy = [ "sockets.target" ];
            listenStreams = [ "127.0.0.1:${toString s.port}" ];
            socketConfig = {
              Accept = true;
              # llama-server default n_slots=4; cap concurrent bridges below it.
              MaxConnections = 4;
            };
          }
        ) cfg.servers;
        systemd.services =
          # Per-connection bridges — template name MUST match the socket
          # name (systemd 261 naming rule, see module header). The three
          # families never collide: "<name>@", "<name>", "<name>-idle".
          lib.mapAttrs' (
            name: s:
            lib.nameValuePair "llama-vlm-${name}@" {
              description = "llama-vlm ${name} per-connection proxy: client fd ↔ backend TCP";
              after = [ "llama-vlm-${name}.service" ];
              wants = [ "llama-vlm-${name}.service" ];
              serviceConfig = lib.mkMerge [
                {
                  Type = "exec";
                  ExecStart = lib.getExe (bridgeConn name s);
                  StandardInput = "socket";
                  StandardOutput = "socket";
                }
                (harden { MemoryMax = "64M"; })
              ];
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
            }
          ) cfg.servers
          // lib.mapAttrs' (
            name: s:
            lib.nameValuePair "llama-vlm-${name}" {
              description = "llama.cpp VLM server '${name}' (backend, model resident)";
              # Deliberately NOT wantedBy multi-user.target — socket activation
              # keeps RAM free until first request; the socket re-arms after
              # idle-stop.
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              serviceConfig = lib.mkMerge [
                {
                  Type = "exec";
                  User = if s.user != null then s.user else primaryUser;
                  Group = "users";
                  ExecStart = execStart s;
                  # Backoff after OOM kills: a fast restart of a multi-GB cold
                  # load pile-drives an exhausted machine (fastflowlm lesson,
                  # 2026-08-18). Exponential: 60→120→240→480→900 s.
                  Restart = "on-failure";
                  RestartSec = "60";
                  RestartSteps = 5;
                  RestartMaxDelaySec = "15min";
                  # Preferred global-OOM victim: stateless, socket-activated,
                  # self-heals on the next connection.
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
            }
          ) cfg.servers
          // lib.mapAttrs' (
            name: s:
            lib.nameValuePair "llama-vlm-${name}-idle" {
              description = "Stop llama-vlm ${name} backend after idle TTL expires";
              serviceConfig = lib.mkMerge [
                {
                  Type = "oneshot";
                  ExecStart = lib.getExe (idleCheck name s);
                }
                (harden { })
              ];
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
            }
          ) cfg.servers;

        systemd.timers = lib.mapAttrs' (
          name: s:
          lib.nameValuePair "llama-vlm-${name}-idle" {
            description = "Probe llama-vlm ${name} idle state every 5 minutes";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "5min";
              OnUnitActiveSec = "5min";
              AccuracySec = "1min";
            };
          }
        ) cfg.servers;

        services.gatus-coverage-audit.allowPorts = lib.concatMap (s: [
          s.port
          s.backendPort
        ]) (lib.attrValues cfg.servers);
      };
    };
}
