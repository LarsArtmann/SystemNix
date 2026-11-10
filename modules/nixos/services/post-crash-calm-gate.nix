# Post-crash calm gate — boot-time admission barrier for the crash-recovery
# cold-reader fleet (freeze-6 rule (a), finally wired 2026-11-05).
#
# WHY THIS MODULE EXISTS: every Branch-C WDT reset since freeze #33 has been
# followed by a recovery boot that re-arms the SAME IO storm that caused the
# cut — GB-scale cold readers (llama-embeddings backlog re-embed, nsfw
# ensemble ONNX loads, dnsblockd blocklist, flm/llama-vlm model cold-loads)
# all start into a cold page cache on the QLC root simultaneously, re-enter
# IO-PSI livelock + thermal ceiling, and the box dies again (freezes
# #40–#46: six consecutive recovery-boot deaths; #47 died 2026-11-05 03:03
# after ~8 h, its recovery boot #48 died EIGHT MINUTES after boot). The
# `post-crash-calm-gate` package (pkgs/post-crash-calm-gate.nix) was built
# for exactly this on 2026-10-17 but its wiring module never landed — this
# module is that missing wiring.
#
# MECHANISM: a Type=oneshot barrier unit runs once per boot at
# multi-user.target. It polls maintenance-entry-gate (io-PSI some avg10 <
# psiMax AND no memory-emergency-guard trip within tripWindowMin — the trip
# state file survives the crash, so a post-crash boot waits out its own
# pre-crash trip window) for up to maxWaitMin, then:
#   - ADMITS (exit 0, RemainAfterExit): gated units start. On a calm boot
#     this costs seconds.
#   - REFUSES (exit 1): still storming after the cap — gated units' start
#     jobs fail (Requires+After), OnFailure toasts once, and the AI cold
#     reader fleet stays DOWN for the boot. A refused reader is free
#     (next boot / manual start re-arms it); a reader inside the storm has
#     killed this box 10+ times (freezes #19/#20/#22/#25/#28/#40–#48).
#
# SPLIT OF DUTIES with psi-wait-gate (also wired 2026-11-05):
#   post-crash-calm-gate (this module): REFUSE-class barrier for
#     boot-started, deferrable heavy readers (llama-embeddings,
#     llama-reranker, nsfw-classifier).
#   psi-wait-gate (ExecStartPre in fastflowlm.nix / llama-vlm.nix):
#     WAIT-never-refuse for socket-activated must-come-up backends — their
#     clients see slow answers, never refusals, and every (re)start of a
#     multi-GB model load re-arms the wait (kills the crash-loop pile-driver
#     class: flm-real SIGABRT ×2 + 12 GB reload per retry, freeze #48).
#
# KILL-SWITCH PROPERTY: gated units are Requires+After this barrier, so
# `systemctl stop post-crash-calm-gate` stops the whole gated fleet in one
# command (the containment that survives reboots AND deploys — freeze-4
# rule; stopping individual units never survives either).
_: {
  flake.nixosModules.post-crash-calm-gate =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      libHelpers = import ../../../lib/default.nix lib;
      inherit (libHelpers)
        harden
        ioTier
        onFailure
        serviceOneshotDefaults
        ;

      cfg = config.services.post-crash-calm-gate;
    in
    {
      options.services.post-crash-calm-gate = {
        enable = lib.mkEnableOption "post-crash calm gate (boot-time IO-PSI admission barrier for the crash-recovery cold-reader fleet)";

        psiMax = lib.mkOption {
          type = lib.types.int;
          default = 40;
          description = "Admit gated readers only when io-PSI some avg10 is below this percent (the recovery-reader band; stricter than psi-wait-gate's 30 would strand backends, looser admits the storm).";
        };

        tripWindowMin = lib.mkOption {
          type = lib.types.int;
          default = 60;
          description = "Keep waiting while the memory-emergency-guard tripped within this many minutes (episodic-storm dips are not calm; freeze #5/#21 class).";
        };

        maxWaitMin = lib.mkOption {
          type = lib.types.int;
          default = 60;
          description = "Refuse (keep the gated fleet down for the boot) if still storming after this many minutes.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.post-crash-calm-gate = {
          description = "Post-crash calm gate — wait for IO calm before admitting the cold-reader fleet";
          wantedBy = [ "multi-user.target" ];
          # NO network-online.target: reads /proc + a local state file only.
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              RemainAfterExit = true;
              # The wait loop runs up to maxWaitMin; the +5 slack covers the
              # final poll + refuse path so systemd never kills a gate that
              # is about to decide on its own.
              TimeoutStartSec = "${toString (cfg.maxWaitMin + 5)}min";
              ExecStart = ''
                ${lib.getExe pkgs.post-crash-calm-gate} --name post-crash-calm-gate --psi-max ${toString cfg.psiMax} --trip-window-min ${toString cfg.tripWindowMin} --max-wait-min ${toString cfg.maxWaitMin}
              '';
            }
            (harden { MemoryMax = "128M"; })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };
      };
    };
}
