# FastFlowLM — AMD XDNA NPU LLM server (OpenAI-compatible)
#
# Wraps the FastFlowLM (https://github.com/ROCm/FastFlowLM) v1.0.1 NPU runtime
# as a socket-activated systemd service. The goal is "always-available" without
# "always-loaded" — zero processes, zero RAM, zero NPU until first connection.
#
# Architecture:
#
#   client → 127.0.0.1:52625  fastflowlm.socket (Accept=true, inetd-style)
#              └─ fastflowlm-proxy@.service (one instance per connection)
#                   └─ waits for 127.0.0.1:52626 to accept, then exec socat
#                      bridging the connection fd ↔ backend TCP stream
#                      └─ fastflowlm.service (flm serve)   ← model resident here
#                           └─ /dev/accel0 (NPU), /data/ai/models/fastflowlm (mmap)
#
# WHY no systemd-socket-proxyd: nixpkgs' systemd does not build it (verified
# 2026-08-18: absent from every systemd 261.1 store output on this machine;
# the resulting ExecStart exit 127 crashed the proxy into start-limit-hit and
# systemd deactivated the public socket — :52625 refused connections for
# hours, invisible to liveness-only checks). The Accept=true + per-connection
# socat design replaces it with zero resident daemons: flm binds :52626 early
# but only accepts after the model is loaded, so the KERNEL listen backlog is
# the cold-load gate — clients queue in TCP, no userspace HTTP polling (1 s
# probes churned flm's hard 10-connection limit during the 2026-08-18 test).
#
# Idle TTL: the fastflowlm-idle timer stops the backend (and any lingering
# per-connection instances) when the backend journal has no "TCP connection
# established" entries for ≥ keepAlive (default 1h) AND the backend has been
# active for ≥ 10 min (don't kill a cold load in progress).
#
# WHY socket activation: the model is 13.6 GB mmap'd from /data. Pinned in RAM
# 24/7, it would reserve ~25 GB of the 94 GB CPU-visible pool at idle. That's
# only affordable when the model is actually in use. Cold load is 1-3 min
# (acceptable for a background LLM); if it isn't, the warmCalendar option
# pre-loads before work hours.
#
# WHY Gatus MUST NOT probe :52625: every probe is a TCP connection = permanent
# keepalive. The system-health textfile collector emits fastflowlm_failed and
# fastflowlm_crash_loop so Gatus can alert on actual failure without keeping
# the model pinned.
#
# References:
#   - docs/planning/2026-08-15_19-22_fastflowlm-npu-server-systemd-integration.md
#   - pkgs/fastflowlm.nix
#   - ~/projects/anime-comic-pipeline/docs/npu-fastflowlm-llm-server.md
_: {
  flake.nixosModules.fastflowlm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.fastflowlm;
      inherit (import ../../../lib/default.nix lib)
        harden
        ports
        ioTier
        ;
      inherit (config.users) primaryUser;

      # Per-connection bridge (inetd-style, spawned per client connection by
      # the Accept=true socket): wait until :52626 accepts a TCP connection,
      # then exec socat bridging fd 0 (the client connection systemd handed
      # us) to the backend TCP stream. flm binds :52626 early (~20 s) but
      # starts its accept loop only after the model is loaded; connections
      # made in between queue in the kernel backlog — that queue IS the
      # cold-load hold, which is why this probes with bare TCP connects and
      # never HTTP (HTTP probes consumed flm's hard 10-connection limit —
      # live incident 2026-08-18). Deadline 300 s: cold load is 1-3 min worst
      # case; each refused probe closes instantly and consumes no slot.
      proxyConn = pkgs.writeShellApplication {
        name = "fastflowlm-proxy-conn";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          host="127.0.0.1"
          port="${toString cfg.backendPort}"
          deadline=$((SECONDS + 300))
          until (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; do
            if [ "$SECONDS" -ge "$deadline" ]; then
              echo "fastflowlm-proxy: backend $host:$port not reachable within 300 s" >&2
              exit 1
            fi
            sleep 1
          done
          exec ${lib.getExe' pkgs.socat "socat"} - "TCP:$host:$port"
        '';
      };

      # TTL checker: stop the backend (and proxy) if no traffic for ≥ keepAlive.
      # Uses journalctl --grep + -n cap (never `journalctl | grep` — the IO trap).
      # IMPORTANT: never stop fastflowlm.socket — the socket IS the re-activation
      # mechanism. Stopping it kills the :52625 listener until manual intervention.
      idleCheck = pkgs.writeShellApplication {
        name = "fastflowlm-idle-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.systemd
        ];
        text = ''
          if ! systemctl is-active --quiet fastflowlm.service; then
            exit 0
          fi
          # ActiveEnterTimestampMonotonic is in microseconds; 600000000 = 10 min.
          active_us=$(systemctl show fastflowlm.service -p ActiveEnterTimestampMonotonic --value)
          if [ -z "$active_us" ] || [ "$active_us" -lt 600000000 ]; then
            exit 0
          fi
          if ${lib.getExe' pkgs.systemd "journalctl"} -u fastflowlm --since "${cfg.keepAlive} ago" --grep "TCP connection established" -n 1 --output cat 2>/dev/null | grep -q .; then
            exit 0
          fi
          systemctl stop 'fastflowlm-proxy@*.service' fastflowlm.service
        '';
      };
    in
    {
      options.services.fastflowlm = {
        enable = lib.mkEnableOption "FastFlowLM NPU LLM server (socket-activated, OpenAI-compatible)";

        package = lib.mkPackageOption pkgs "fastflowlm" { };

        model = lib.mkOption {
          type = lib.types.str;
          default = "qwen3.6-moe:35b-a3b";
          description = "Single bound model — server cold-loads/swaps to other models on request.";
        };

        keepAlive = lib.mkOption {
          type = lib.types.str;
          default = "1h";
          description = "Idle TTL window before the backend (and proxy) are stopped. systemd time-span syntax (e.g. \"1h\", \"30min\").";
        };

        loadAsr = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Also load whisper-v3 for ASR (--asr 1).";
        };

        loadEmbed = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Also load embeddinggemma for embeddings (--embed 1).";
        };

        pmode = lib.mkOption {
          type = lib.types.enum [
            "powersaver"
            "balanced"
            "performance"
            "turbo"
          ];
          default = "performance";
          description = "NPU performance mode (--pmode).";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Backend bind address — keep loopback only.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.fastflowlm;
          description = "Public socket-activated port (stable for clients).";
        };

        backendPort = lib.mkOption {
          type = lib.types.port;
          default = ports.fastflowlm-backend;
          description = "Internal backend port — proxy forwards here.";
        };

        modelPath = lib.mkOption {
          type = lib.types.path;
          default = "/data/ai/models/fastflowlm";
          description = "On-disk model directory (mmap'd). Created by ai-models.nix.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = primaryUser;
          description = "User to run the service as.";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "users";
          description = "Group for the service user.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.port != cfg.backendPort;
            message = "services.fastflowlm.port and backendPort must differ (proxy hop).";
          }
          {
            assertion = cfg.host == "127.0.0.1" || cfg.host == "::1";
            message = "services.fastflowlm.host must be loopback. The NPU model is 13.6 GB mmap'd; expose via reverse proxy if you need remote access.";
          }
        ];

        systemd.sockets.fastflowlm = {
          description = "FastFlowLM NPU LLM server (public socket)";
          wantedBy = [ "sockets.target" ];
          listenStreams = [ "${cfg.host}:${toString cfg.port}" ];
          # inetd-style: systemd itself accepts connections and spawns one
          # fastflowlm-proxy@.service instance per connection, with the
          # accepted connection wired to the instance's fd 0/1. Routing
          # activation directly at fastflowlm.service would hand flm a
          # listening fd it never accepts (clients hang forever).
          socketConfig = {
            Accept = true;
            Service = "fastflowlm-proxy@.service";
            # flm enforces a hard 10-connection limit once its accept loop is
            # live; cap concurrent clients below it (each instance = 1 real
            # connection + 1 transient probe connection during cold load).
            MaxConnections = 8;
          };
        };

        systemd.services."fastflowlm-proxy@" = {
          description = "FastFlowLM per-connection proxy: client fd ↔ backend TCP";
          after = [ "fastflowlm.service" ];
          wants = [ "fastflowlm.service" ];
          serviceConfig = lib.mkMerge [
            {
              Type = "exec";
              ExecStart = lib.getExe proxyConn;
              # The accepted client connection arrives on fd 0/1 (inetd style).
              StandardInput = "socket";
              StandardOutput = "socket";
              # No Restart: instances are per-connection; the socket spawns a
              # fresh one for the next client. Type=exec is "started" at
              # exec — TimeoutStartSec cannot fire mid-wait-loop; the loop
              # carries its own 300 s deadline.
            }
            (harden {
              # socat holds one TCP stream; the harden default of 512M is
              # 100x what it needs. Tighten to catch runaway behavior.
              MemoryMax = "64M";
            })
          ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
        };

        systemd.services.fastflowlm = {
          description = "FastFlowLM NPU LLM server (backend, mmap'd model)";
          # Deliberately NOT wantedBy multi-user.target: the whole point of
          # socket activation is zero processes/RAM/NPU at boot. The backend is
          # pulled up exclusively by the proxy's after/wants on first
          # connection, and re-armed after idle-stop by the (still-listening)
          # socket.
          after = [
            "network-online.target"
            "data.mount"
          ];
          wants = [ "network-online.target" ];

          # Service user needs `video` group for /dev/accel/accel0 (root:video 0660).
          # memlock unlimited is required for NPU DMA.
          serviceConfig = lib.mkMerge [
            {
              Type = "exec";
              User = cfg.user;
              Group = cfg.group;
              SupplementaryGroups = [ "video" ];
              LimitMEMLOCK = "infinity";
              LimitNOFILE = "65536";

              # flm-real reads/writes $HOME/.config at startup (XDG paths).
              # harden {} sets ProtectHome=true, so /home/lars is INACCESSIBLE
              # (and WorkingDirectory there fails with 200/CHDIR). Redirect HOME
              # into a private writable StateDirectory instead — keeps the
              # service fully decoupled from the user's home.
              StateDirectory = "fastflowlm";
              WorkingDirectory = "/var/lib/fastflowlm";

              ExecStart =
                "${lib.getExe cfg.package} serve ${cfg.model} --host ${cfg.host} --port ${toString cfg.backendPort} --pmode ${cfg.pmode}"
                + (lib.optionalString cfg.loadAsr " --asr 1")
                + (lib.optionalString cfg.loadEmbed " --embed 1");

              Environment = [
                "HOME=/var/lib/fastflowlm"
                "FLM_MODEL_PATH=${cfg.modelPath}"
              ];

              Restart = "on-failure";
              RestartSec = "5";
              MemoryMax = "32G";
              MemoryHigh = "26G";
              MemorySwapMax = "20G";
              TimeoutStartSec = "3min";
            }
            (harden { })
            ioTier.background
          ];

          # startLimitBurst/Interval are top-level (systemd 261 silently ignores
          # them in [Service]). Required per the module hardening audit.
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
        };

        # TTL: every 5 min, check if the backend has had traffic in the last
        # keepAlive window — if not, stop proxy + backend (the socket keeps
        # listening, so the next :52625 connection re-activates everything).
        systemd.services.fastflowlm-idle = {
          description = "Stop FastFlowLM backend after idle TTL expires";
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

        systemd.timers.fastflowlm-idle = {
          description = "Probe FastFlowLM idle state every 5 minutes";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5min";
            OnUnitActiveSec = "5min";
            AccuracySec = "1min";
          };
        };

        # OTel traces → local SigNoz OTLP/HTTP collector (Go OTel SDK format).
        # Noop tracer when collector is absent.
        systemd.services.fastflowlm.environment.OTEL_EXPORTER_OTLP_ENDPOINT =
          lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";

        # Gatus MUST NOT probe :52625 (every probe is a TCP connection =
        # permanent keepalive). The system-health textfile collector emits
        # fastflowlm_failed and fastflowlm_crash_loop so Gatus can alert on
        # actual failure without pinning the model.
      };
    };
}
