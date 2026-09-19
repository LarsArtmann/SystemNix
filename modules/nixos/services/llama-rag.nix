# llama.cpp RAG stack - embeddings + reranking on the GPU (ROCm)
#
# Two lightweight llama-server instances for retrieval-augmented generation:
#
#   llama-embeddings  127.0.0.1:8848  bge-m3          --embedding
#   llama-reranker    127.0.0.1:8849  bge-reranker-v2-m3  --reranking --pooling rank
#
# Both models are ~568M params: cold load ~1s, VRAM ~1-2 GB each. No socket
# activation needed (unlike FastFlowLM's 13.6 GB NPU model) - always-on is
# affordable for services that need instant embedding/rerank responses.
#
# Why two instances: llama.cpp's --embedding and --reranking modes are
# mutually exclusive per server process. Ollama could serve embeddings but
# does NOT support reranking (issue #3368, open since Mar 2024). Using
# llama-server for both keeps the RAG stack on a single engine, fully
# Nix-native, zero Docker.
#
# Model files (GGUF) are downloaded at activation into modelDir
# (/data/ai/models/gguf, created by ai-models.nix) by the
# llama-rag-model-fetch oneshot, then the servers are started:
#   /data/ai/models/gguf/bge-m3.gguf
#   /data/ai/models/gguf/bge-reranker-v2-m3.gguf
# Sources are gpustack's verified GGUF conversions of the BAAI checkpoints
# (gpustack/bge-m3-GGUF, gpustack/bge-reranker-v2-m3-GGUF).
_: {
  flake.nixosModules.llama-rag =
    {
      config,
      options,
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      cfg = config.services.llama-rag;
      libHelpers = import ../../../lib/default.nix lib;
      inherit (libHelpers)
        harden
        ports
        ioTier
        ;
      inherit (config.users) primaryUser;

      # REV-PINNED nixpkgs (flake.nix `nixpkgs-llama-rag`): llama.cpp 0.3.0,
      # the last build proven serving on gfx1150. The 0.4.0 build from the
      # root nixpkgs wedges BOTH servers mid-model-load (94% single-thread
      # CPU spin right after "model vocab missing newline token", GPU idle,
      # /health 503 - live 2026-09-14, 3/3 repros). The whole ROCm runtime
      # is taken from the same pinned tree so the binary's userspace is
      # exactly the stack it was built and verified against. Drop the pin
      # (flake input + this import) once the 0.4.0+ regression is fixed
      # upstream and re-verified live.
      llamaPkgs = import inputs.nixpkgs-llama-rag {
        inherit (pkgs) system;
        config.allowUnfree = true;
      };
      rocm = libHelpers.rocm { pkgs = llamaPkgs; };
      llama-cpp-rocwmma = llamaPkgs.llama-cpp.override { rocmSupport = true; };
      llamaServer = lib.getExe' llama-cpp-rocwmma "llama-server";
      ldLibPath = rocm.makeLdLibraryPath lib;

      commonServiceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;
        SupplementaryGroups = [ "render" ];
        NoNewPrivileges = false;
        Restart = "on-failure";
        RestartSec = "10";
        OOMScoreAdjust = 300;
        MemoryMax = cfg.memoryMax;
        CPUQuota = "200%";
        # Bounded stop budget. A restart while the disk is saturated can
        # wedge the server in uninterruptible I/O (SIGTERM/SIGKILL both stay
        # pending until the read completes); without an explicit bound
        # systemd's 90s default applies and the unit fails into stop-timeout
        # anyway. This documents the budget; true D-state corpses can only
        # be unwound by their I/O completing (monitor: the leak-metrics
        # collector + Gatus check below).
        TimeoutStopSec = "2min";
      };

      # Deterministic per-model download specs. The fetch oneShot installs
      # each file into modelDir (same filesystem → atomic rename from .part),
      # verifies the GGUF magic, and stamps the source URL next to the model
      # (a URL change re-fetches; a truncated/partial file is re-downloaded).
      modelFetches = [
        {
          url = "https://huggingface.co/gpustack/bge-m3-GGUF/resolve/main/bge-m3-FP16.gguf";
          file = cfg.embeddingsModel;
        }
        {
          url = "https://huggingface.co/gpustack/bge-reranker-v2-m3-GGUF/resolve/main/bge-reranker-v2-m3-FP16.gguf";
          file = cfg.rerankerModel;
        }
      ];

      fetchScript = pkgs.writeShellScript "llama-rag-model-fetch.sh" ''
          set -euo pipefail
          fetch_one() {
            local url="$1" file="$2"
            local target="${cfg.modelDir}/$file"
            local part="$target.part"
            local stamp="$target.source"
            if [ -e "$target" ]; then
              local magic
              magic="$(head -c 4 "$target" 2>/dev/null)" || true
              if [ "$magic" = "GGUF" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$url" ]; then
                echo "llama-rag: $file present and current"
                return 0
              fi
              echo "llama-rag: $file stale (magic or source changed), re-fetching"
            fi
            echo "llama-rag: downloading $file from $url"
            if ! curl -fLsS --retry 3 --retry-delay 5 --connect-timeout 30 -o "$part" "$url"; then
              echo "llama-rag: FAILED to download $url" >&2
              rm -f -- "$part"
              return 1
            fi
            local magic
            magic="$(head -c 4 "$part" 2>/dev/null)" || true
            if [ "$magic" != "GGUF" ]; then
              echo "llama-rag: downloaded $file is not GGUF, aborting" >&2
              rm -f -- "$part"
              return 1
            fi
            mv -f -- "$part" "$target"
            printf '%s' "$url" > "$stamp"
            echo "llama-rag: installed $file"
          }
        ${lib.concatMapStrings (m: "fetch_one '${m.url}' '${m.file}'\n") modelFetches}
          echo "llama-rag: all models ready"
      '';

      embeddingsExecStart =
        "${llamaServer} --embedding"
        + " -m ${cfg.modelDir}/${cfg.embeddingsModel}"
        + " --alias ${cfg.embeddingsAlias}"
        + " --host ${cfg.host}"
        + " --port ${toString cfg.embeddingsPort}"
        + " --ctx-size ${toString cfg.ctxSize}";

      rerankerExecStart =
        "${llamaServer} --reranking --pooling rank"
        + " -m ${cfg.modelDir}/${cfg.rerankerModel}"
        + " --alias ${cfg.rerankerAlias}"
        + " --host ${cfg.host}"
        + " --port ${toString cfg.rerankerPort}"
        + " --ctx-size ${toString cfg.ctxSize}";

      # Orphan-port guard: kill any llama-server holding this unit's port
      # that is NOT managed by this module's units. The 2026-09-18 deploy hit
      # the class live: a rogue 0.4.0 llama-server (spawned by a hermes cron
      # worker and orphaned to PID 1) survived the config-disable era holding
      # :8849, so the re-enabled reranker unit bind-failed into
      # start-limit-hit while the rogue kept serving stale code. Runs
      # `+`-privileged (root) because the rogue runs as a foreign user;
      # spares anything inside this module's own unit cgroups. Idempotent:
      # after the kill the port is free and the real server binds.
      portGuardScript = pkgs.writeShellScript "llama-rag-port-guard.sh" ''
        set -euo pipefail
        port="$1"
        pids="$("${pkgs.iproute2}/bin/ss" -tlnp "sport = :$port" 2>/dev/null \
          | "${pkgs.gnused}/bin/sed" -n 's/.*pid=\([0-9]*\).*/\1/p' \
          | "${pkgs.coreutils}/bin/sort" -u || true)"
        for pid in $pids; do
          cgroup="$("${pkgs.coreutils}/bin/cat" "/proc/$pid/cgroup" 2>/dev/null || true)"
          case "$cgroup" in
            *llama-embeddings.service*|*llama-reranker.service*) ;;
            *)
              echo "llama-rag: stale listener on :$port (pid $pid, foreign cgroup) - killing"
              "${pkgs.coreutils}/bin/kill" "$pid" 2>/dev/null || true
              "${pkgs.coreutils}/bin/sleep" 2
              "${pkgs.coreutils}/bin/kill" -9 "$pid" 2>/dev/null || true
              ;;
          esac
        done
      '';

      # Leak monitor (2026-09-02 incident: 10 leaked llama-server pairs in
      # D-state up to 55h, each restart under QLC saturation stranding
      # another pair that ignores SIGKILL). A llama-server process that does
      # NOT own a listener on either configured port is leaked/leaking -
      # either wedged pre-bind or an orphan the unit lost track of.
      # Fail-closed: on scrape failure the leak gauges are OMITTED (absence
      # fails the Gatus pats) and llama_rag_scrape_errors goes to 1.
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      leakMetricsScript = pkgs.writeShellScript "llama-rag-leak-metrics.sh" ''
        set -euo pipefail
        OUT="${textfileDir}/llama-rag-leaks.prom"
        mkdir -p "${textfileDir}"
        TMP="$(mktemp "${textfileDir}/llama-rag-leaks.prom.XXXXXX")"
        chmod 644 "$TMP"
        trap 'rm -f "$TMP"' EXIT

        scrape_errors=1
        leaks=""
        if ss_out="$(timeout 10 ${pkgs.iproute2}/bin/ss -tlnp 2>/dev/null)"; then
          scrape_errors=0
          leaks=0
          for pid in $(${pkgs.procps}/bin/pgrep -x llama-server 2>/dev/null || true); do
            if ! grep -F "pid=''${pid}," <<<"$ss_out" | grep -Eq ":(${toString cfg.embeddingsPort}|${toString cfg.rerankerPort})[^0-9]"; then
              leaks=$((leaks + 1))
            fi
          done
        fi

        {
          echo "llama_rag_expected_instances 2"
          if [ -n "$leaks" ]; then
            echo "llama_rag_leaked_instances $leaks"
            if [ "$leaks" -gt 0 ]; then
              echo "llama_rag_leaks_present 1"
            else
              echo "llama_rag_leaks_present 0"
            fi
          fi
          echo "llama_rag_scrape_errors $scrape_errors"
        } > "$TMP"
        mv -f "$TMP" "$OUT"
        trap - EXIT
      '';

      paperlessWantsRag = (config.services.paperless or { }).enable or false;

      # Dark guard (module DISABLED): once this module is off, the llama-rag
      # ports have NO legitimate owner - any listener is a foreign orphan.
      # The 2026-09-18/19 hermes-cron orphan class recurred 3x (rogue
      # llama-servers holding :8848/:8849 for 8h+ on the WEDGED 0.4.0
      # build while the module ran the pinned 0.3.0 one; intermittent-spin,
      # 2h+ CPU burned) with zero detection. This collector is its
      # tripwire. When paperless is enabled it also keeps the RAG
      # capability loss visible: the embedding endpoint is dark, so
      # paperless semantic search silently degrades - a standing signal
      # (Turso precedent), emitted BY CONFIG so a rogue listener can never
      # turn it green. Fail-closed: on scrape failure the rogue gauge is
      # omitted (absence fails the Gatus pat) and
      # llama_rag_dark_scrape_errors goes to 1.
      darkGuardScript = pkgs.writeShellScript "llama-rag-dark-guard.sh" ''
        set -euo pipefail
        OUT="${textfileDir}/llama-rag-dark.prom"
        mkdir -p "${textfileDir}"
        TMP="$(mktemp "${textfileDir}/llama-rag-dark.prom.XXXXXX")"
        chmod 644 "$TMP"
        trap 'rm -f "$TMP"' EXIT

        rogues=""
        scrape_errors=1
        if ss_out="$(timeout 10 ${pkgs.iproute2}/bin/ss -tln 2>/dev/null)"; then
          scrape_errors=0
          rogues="$(grep -cE ":(${toString cfg.embeddingsPort}|${toString cfg.rerankerPort})[^0-9]" <<<"$ss_out")" || rogues=0
        fi

        {
          if [ -n "$rogues" ]; then
            echo "# HELP llama_rag_ports_rogue_listeners Listeners on the llama-rag ports while the module is disabled - foreign orphans by construction (hermes-cron orphan class, intermittent-spin)"
            echo "# TYPE llama_rag_ports_rogue_listeners gauge"
            echo "llama_rag_ports_rogue_listeners $rogues"
          fi
          echo "# HELP llama_rag_dark_scrape_errors Scrape status of the dark-guard collector: 0 = OK, 1 = failed (fail-closed)"
          echo "# TYPE llama_rag_dark_scrape_errors gauge"
          echo "llama_rag_dark_scrape_errors $scrape_errors"
          ${lib.optionalString paperlessWantsRag ''
            echo "# HELP paperless_rag_embeddings_dark 1 while llama-rag is disabled and paperless consumes the embedding endpoint - standing capability-loss signal (RAG semantic search degraded), not an actionable outage. Config-emitted: a rogue listener must never turn this green."
            echo "# TYPE paperless_rag_embeddings_dark gauge"
            echo "paperless_rag_embeddings_dark 1"
          ''}
        } > "$TMP"
        mv -f "$TMP" "$OUT"
        trap - EXIT
      '';
    in
    {
      options.services.llama-rag = {
        enable = lib.mkEnableOption "llama.cpp RAG stack (embeddings + reranking, ROCm GPU)" // {
          default = false;
        };

        modelDir = lib.mkOption {
          type = lib.types.str;
          default = "/data/ai/models/gguf";
          description = "Directory containing GGUF model files. Created by ai-models.nix.";
        };

        embeddingsModel = lib.mkOption {
          type = lib.types.str;
          default = "bge-m3.gguf";
          description = "GGUF model filename for the embeddings server (BERT-family, --embedding mode).";
        };

        embeddingsAlias = lib.mkOption {
          type = lib.types.str;
          default = "bge-m3";
          description = "Model alias reported via the /v1/models endpoint and accepted in API requests.";
        };

        rerankerModel = lib.mkOption {
          type = lib.types.str;
          default = "bge-reranker-v2-m3.gguf";
          description = "GGUF model filename for the reranking server (cross-encoder, --reranking mode).";
        };

        rerankerAlias = lib.mkOption {
          type = lib.types.str;
          default = "bge-reranker-v2-m3";
          description = "Model alias reported via the /v1/models endpoint and accepted in API requests.";
        };

        ctxSize = lib.mkOption {
          type = lib.types.int;
          default = 8192;
          description = "Context window size (tokens). bge-m3 and bge-reranker-v2-m3 both support 8192.";
        };

        memoryMax = lib.mkOption {
          type = lib.types.str;
          default = "2G";
          description = "Memory ceiling per service. 568M-param models need <1 GB; 2G gives headroom.";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Bind address - keep loopback only.";
        };

        embeddingsPort = lib.mkOption {
          type = lib.types.port;
          default = ports.llama-embeddings;
          description = "Port for the embeddings server (/v1/embeddings).";
        };

        rerankerPort = lib.mkOption {
          type = lib.types.port;
          default = ports.llama-reranker;
          description = "Port for the reranking server (/v1/rerank).";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = primaryUser;
          description = "User to run the services as.";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "users";
          description = "Group for the service user.";
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = cfg.embeddingsPort != cfg.rerankerPort;
              message = "services.llama-rag.embeddingsPort and rerankerPort must differ (two separate instances).";
            }
            {
              assertion = cfg.host == "127.0.0.1" || cfg.host == "::1";
              message = "services.llama-rag.host must be loopback. Expose via reverse proxy if you need remote access.";
            }
          ];

          systemd.services.llama-rag-model-fetch = {
            description = "Fetch llama.cpp RAG GGUF models (bge-m3 + bge-reranker-v2-m3)";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            before = [
              "llama-embeddings.service"
              "llama-reranker.service"
            ];
            path = [
              pkgs.curl
              pkgs.coreutils
            ];
            unitConfig.ConditionPathIsDirectory = cfg.modelDir;
            serviceConfig = {
              Type = "oneshot";
              User = cfg.user;
              Group = cfg.group;
              ExecStart = "${fetchScript}";
              # Two ~1.2 GB downloads from HuggingFace; slow links need headroom
              # (the global 3min default cannot cover a cold first fetch).
              TimeoutStartSec = "20min";
              # Stay active after success: the servers' Requires= pulls must be
              # no-ops — re-running this fetch per server restart piled up starts
              # past the burst limit and exit-4'd activations (2026-09-18).
              RemainAfterExit = true;
            };
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };

          systemd.services.llama-embeddings = {
            description = "llama.cpp embeddings server (bge-m3, ROCm GPU)";
            after = [
              "network-online.target"
              "llama-rag-model-fetch.service"
            ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            requires = [ "llama-rag-model-fetch.service" ];

            environment = rocm.env // {
              LD_LIBRARY_PATH = ldLibPath;
            };

            serviceConfig = lib.mkMerge [
              commonServiceConfig
              {
                ExecStart = embeddingsExecStart;
                ExecStartPre = "+${portGuardScript} ${toString cfg.embeddingsPort}";
              }
              rocm.deviceCgroup
              (harden { })
              ioTier.background
            ];

            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };

          systemd.services.llama-reranker = {
            description = "llama.cpp reranking server (bge-reranker-v2-m3, ROCm GPU)";
            after = [
              "network-online.target"
              "llama-rag-model-fetch.service"
            ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            requires = [ "llama-rag-model-fetch.service" ];

            environment = rocm.env // {
              LD_LIBRARY_PATH = ldLibPath;
            };

            serviceConfig = lib.mkMerge [
              commonServiceConfig
              {
                ExecStart = rerankerExecStart;
                ExecStartPre = "+${portGuardScript} ${toString cfg.rerankerPort}";
              }
              rocm.deviceCgroup
              (harden { })
              ioTier.background
            ];

            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };

          # Leak monitor: 5-min textfile collector counting llama-server
          # processes that hold no :8848/:8849 listener (wedged pre-bind or
          # orphaned - the 2026-09-02 D-state leak class). Root + CAP_FOWNER
          # per the sticky-textfile-dir doctrine (unique mktemp, rename-over-
          # foreign fails without it).
          systemd.services.llama-rag-leak-metrics = {
            description = "llama-rag leaked llama-server instance metrics";
            after = [
              "llama-embeddings.service"
              "llama-reranker.service"
            ];
            serviceConfig = lib.mkMerge [
              (harden { })
              {
                Type = "oneshot";
                ExecStart = leakMetricsScript;
                CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_OVERRIDE";
                TimeoutStartSec = "1min";
              }
              ioTier.background
            ];
            startLimitBurst = 3;
            startLimitIntervalSec = 300;
          };

          systemd.timers.llama-rag-leak-metrics = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*:0/5";
              Persistent = true;
            };
          };

          # Service-integration registry entry: loopback-only servers (no
          # vHost - a direct probe policy and port registry forbid external
          # exposure), the two Gatus health checks, and the decorative
          # homepage tile. The embeddings/reranker units self-register with
          # system-health (moved out of monitoredServices' default list).
          # Replaces rows in gatus-config.nix / homepage.nix.
          services.integration = lib.optionalAttrs (options ? services.integration) {
            llama-rag = {
              inherit (cfg) enable;
              vHost.layer = "none";
              checks = [
                {
                  name = "llama.cpp Embeddings";
                  group = "AI";
                  url = "http://localhost:${toString cfg.embeddingsPort}/health";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 1000"
                  ];
                  alert = "llama.cpp embeddings server down - RAG indexing and semantic search unavailable";
                }
                {
                  name = "llama.cpp Reranker";
                  group = "AI";
                  url = "http://localhost:${toString cfg.rerankerPort}/health";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 1000"
                  ];
                  alert = "llama.cpp reranker down - RAG reranking unavailable, search quality degraded";
                }
                {
                  # Metric-based (node-exporter textfile): leaked llama-server
                  # processes holding no port listener - the restart-under-QLC-
                  # saturation D-state leak class. Fail-closed: a dead or
                  # wedged collector omits the gauges and fails the pats.
                  name = "llama.cpp Leaked Instances";
                  group = "AI";
                  url = "http://localhost:${toString ports.signoz-node-exporter}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nllama_rag_leaks_present 0*)"
                    "[BODY] != pat(*\nllama_rag_scrape_errors 1*)"
                  ];
                  alert = "llama.cpp leaked server instances detected (llama-server procs holding no :${toString cfg.embeddingsPort}/:${toString cfg.rerankerPort} listener) - the restart-under-IO-saturation D-state leak class. Check: pgrep -ax llama-server, journalctl -u llama-embeddings -u llama-reranker -n 50; a clean reboot unwinds D-state corpses";
                }
              ];
              # Decorative tile: loopback-only embeddings + reranking on GPU.
              # Gatus alerts on /health endpoints; no vHost.
              homepage = {
                name = "llama.cpp RAG";
                group = "AI";
                description = "Embeddings + Reranking (bge-m3, bge-reranker-v2-m3)";
                icon = "ollama.png";
              };
            };
            llama-embeddings = {
              inherit (cfg) enable;
              vHost.layer = "none";
              monitored = true;
            };
            llama-reranker = {
              inherit (cfg) enable;
              vHost.layer = "none";
              monitored = true;
            };
          };
        })

        # Module DISABLED: the ports have no legitimate owner, so watch
        # them for foreign orphans and keep paperless' RAG loss visible.
        (lib.mkIf (!cfg.enable) {
          systemd.services.llama-rag-dark-guard = {
            description = "llama-rag dark-guard metrics (rogue port listeners + paperless RAG loss)";
            serviceConfig = lib.mkMerge [
              (harden { })
              {
                Type = "oneshot";
                ExecStart = darkGuardScript;
                CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_OVERRIDE";
                TimeoutStartSec = "1min";
              }
              ioTier.background
            ];
            startLimitBurst = 3;
            startLimitIntervalSec = 300;
          };

          systemd.timers.llama-rag-dark-guard = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*:0/5";
              Persistent = true;
            };
          };

          services.integration = lib.optionalAttrs (options ? services.integration) {
            llama-rag-dark = {
              enable = true;
              vHost.layer = "none";
              checks = [
                {
                  # Rogue-orphan tripwire (node-exporter textfile): ANY
                  # listener on the llama-rag ports while the module is
                  # disabled is foreign by construction - this module's own
                  # units cannot run when disabled. First post-ship cycle
                  # is expected RED: the live rogues are exactly the alert
                  # working as designed.
                  name = "llama.cpp Port Rogues (dark)";
                  group = "AI";
                  url = "http://localhost:${toString ports.signoz-node-exporter}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nllama_rag_ports_rogue_listeners 0\n*)"
                    "[BODY] != pat(*\nllama_rag_dark_scrape_errors 1*)"
                  ];
                  alert = "Rogue llama-server listener(s) on :${toString cfg.embeddingsPort}/:${toString cfg.rerankerPort} while llama-rag is DISABLED - the hermes-cron orphan class (2026-09-18/19, 3 recurrences; intermittent-spin, 2h+ CPU burned). Consumers may be pinned to the stale wedged 0.4.0 build. Fix: verify identity (ps -o user:16 -p <pid>; cat /proc/<pid>/cgroup), kill the orphan, then trace WHY it spawned (hermes cron definitions).";
                }
              ]
              ++ lib.optionals paperlessWantsRag [
                {
                  # Standing capability-loss signal (Turso precedent):
                  # red BY DESIGN while llama-rag is disabled with
                  # paperless enabled - one persistent alert + standing
                  # dashboard red instead of a silent degradation. The
                  # metric is config-emitted (never listener-probed), so a
                  # rogue cannot turn it green. Disappears on re-enable,
                  # when the enabled entry's /health checks take over.
                  name = "Paperless RAG Embeddings Dark";
                  group = "AI";
                  url = "http://localhost:${toString ports.signoz-node-exporter}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\npaperless_rag_embeddings_dark 0\n*)"
                  ];
                  alert = "Paperless RAG semantic search is degraded: llama-rag is disabled (2026-09-18 mid-load CPU-spin escape condition) so the embedding endpoint :${toString cfg.embeddingsPort} is dark. Stays red until llama-rag re-enables behind the upstream soak gate - standing signal, not an actionable outage.";
                }
              ];
            };
          };
        })
      ];
    };
}
