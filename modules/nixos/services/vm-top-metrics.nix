# Runbook: docs/services/vm-top-metrics.md
# Top-N total-vm (VmSize) textfile collector.
#
# 2026-11-07 (monitoring row, b0d70d73 reservation-cascade postmortem):
# reservation-pressure cascades announce nothing until the swap-exhausted
# kill pass — a top-5 VmSize gauge family makes the balloons visible on the
# node dashboard BEFORE the OOM, and the metric history answers "what was
# ballooning" in the postmortem without journal archaeology. VmSize is
# RESERVED address space (not RSS): the metric tracks reservation pressure,
# the exact currency of the oom-kill cascade class.
_: {
  flake.nixosModules.vm-top-metrics =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        mkStateDir
        ;

      cfg = config.services.vm-top-metrics;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      collectorScript = pkgs.writeShellApplication {
        name = "vm-top-metrics";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
        ];
        # Single source of truth: the committed script (shellcheck'd by
        # pre-commit, selftested via `vm-top-metrics.sh selftest`).
        text = builtins.readFile ../../../scripts/vm-top-metrics.sh;
      };
    in
    {
      options.services.vm-top-metrics = {
        enable = lib.mkEnableOption "top-N total-vm (VmSize) textfile collector (node_vm_top_vmsize_bytes)";

        topN = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "How many top VmSize processes to emit";
        };

        checkInterval = lib.mkOption {
          type = lib.types.str;
          default = "5min";
          description = "Timer cadence. A /proc walk is cheap; balloons develop over minutes";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd = {
          tmpfiles.rules = [
            (mkStateDir textfileDir "1777" "nobody" "nogroup")
          ];

          services.vm-top-metrics = {
            description = "Top-N total-vm (VmSize) textfile collector";
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "64M";
                # Same sticky-textfile-dir reclaim rationale as the other
                # collectors: a foreign-owned stale .prom must not wedge the
                # atomic rename.
                CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_OVERRIDE";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                ExecStart = "${lib.getExe collectorScript} ${textfileDir}/vm-top.prom";
                Environment = [ "VM_TOP_N=${toString cfg.topN}" ];
                ReadWritePaths = [ textfileDir ];
                # Start contract (the socket-existence doctrine): an empty or
                # missing .prom means the collect silently produced nothing —
                # fail the unit instead of serving stale metrics forever.
                ExecStartPost = "${pkgs.bash}/bin/bash -c 'test -s ${textfileDir}/vm-top.prom || { echo vm-top.prom missing/empty after collect; exit 1; }'";
              }
            ];
          };

          timers.vm-top-metrics = {
            description = "Run the top-N total-vm collector";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2min";
              OnUnitActiveSec = cfg.checkInterval;
            };
          };
        };
      };
    };
}
