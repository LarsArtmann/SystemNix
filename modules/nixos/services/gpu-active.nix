# GPUActive / GPUReclaim textfile collector for node_exporter.
#
# evo-x2 (Strix Halo) has 128 GiB physical RAM but only ~94 GiB visible to Linux
# because 34 GiB is BIOS VRAM carveout. GPUActive (GTT buffer objects) can consume
# 50+ GiB of that and is invisible to standard tools like `free` and `htop`.
# This collector exposes the values from /proc/meminfo as Prometheus metrics so
# SigNoz, Gatus, and dashboards can see them.
#
# See AGENTS.md gotcha: "Strix Halo unified memory — GPUActive is the #1 RAM consumer".
_: {
  flake.nixosModules.gpu-active = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit
      (import ../../../lib/default.nix lib)
      harden
      serviceOneshotDefaults
      onFailure
      mkStateDir
      ;

    cfg = config.services.gpu-active;
    textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

    gpuActiveMetrics = pkgs.writeShellApplication {
      name = "gpu-active-metrics";
      runtimeInputs = [pkgs.gnugrep pkgs.coreutils];
      text = ''
        OUT="${textfileDir}/gpu_active.prom"
        TMP="''${OUT}.tmp"
        MEMINFO="/proc/meminfo"

        if [ ! -r "$MEMINFO" ]; then
          echo "Cannot read $MEMINFO" >&2
          exit 1
        fi

        # GPUActive and GPUReclaim are kB fields added by the amdgpu driver on Strix Halo.
        read_kb() {
          local key="$1"
          local line
          line=$(grep -E "^$key:" "$MEMINFO" 2>/dev/null) || true
          if [ -n "$line" ]; then
            echo "$line" | awk '{print $2}'
          else
            echo "0"
          fi
        }

        GPU_ACTIVE_KB=$(read_kb "GPUActive")
        GPU_RECLAIM_KB=$(read_kb "GPUReclaim")
        GPU_ACTIVE_BYTES=$((GPU_ACTIVE_KB * 1024))
        GPU_RECLAIM_BYTES=$((GPU_RECLAIM_KB * 1024))

        mkdir -p "${textfileDir}"

        {
          echo "# HELP node_gpu_active_bytes GPUActive memory from /proc/meminfo (amdgpu GTT buffer objects)"
          echo "# TYPE node_gpu_active_bytes gauge"
          echo "node_gpu_active_bytes $GPU_ACTIVE_BYTES"

          echo "# HELP node_gpu_reclaim_bytes GPUReclaim memory from /proc/meminfo (amdgpu reclaimable pages)"
          echo "# TYPE node_gpu_reclaim_bytes gauge"
          echo "node_gpu_reclaim_bytes $GPU_RECLAIM_BYTES"

          echo "# HELP node_gpu_active_kb GPUActive memory in kB"
          echo "# TYPE node_gpu_active_kb gauge"
          echo "node_gpu_active_kb $GPU_ACTIVE_KB"
        } > "$TMP"
        mv "$TMP" "$OUT"

        echo "gpu_active: GPUActive=''${GPU_ACTIVE_KB}kB GPUReclaim=''${GPU_RECLAIM_KB}kB"
      '';
    };
  in {
    options.services.gpu-active = {
      enable = lib.mkEnableOption "GPUActive / GPUReclaim textfile collector for node_exporter";
      interval = lib.mkOption {
        type = lib.types.str;
        default = "1min";
        description = "Interval at which the collector runs";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd = {
        tmpfiles.rules = [
          (mkStateDir textfileDir "1777" "nobody" "nogroup")
        ];

        services.gpu-active = {
          description = "GPUActive / GPUReclaim textfile collector for node_exporter";
          inherit onFailure;
          serviceConfig =
            harden {
              MemoryMax = "64M";
            }
            // serviceOneshotDefaults {}
            // {
              Type = "oneshot";
              ExecStart = lib.getExe gpuActiveMetrics;
              ReadWritePaths = [textfileDir];
            };
        };

        timers.gpu-active = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "10s";
            OnUnitActiveSec = cfg.interval;
          };
        };
      };
    };
  };
}
