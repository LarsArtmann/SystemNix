# No-heavy-builds admission gate — the ENFORCEMENT leg for the gate the
# freeze-14→#25 autopsy chain kept catching violated as prose (violation
# count #3→#8, docs/todo/stability.md). The driver CLASS was identified in
# the freeze-15 autopsy — interactive agent-session verification batteries
# (`nix flake check`, VM-test builds, go/rust batteries) stacked onto an
# already-stalling box — and the ask narrowed to "block nix
# (flake check|build) when guard trips are recent", mirroring deploy.sh's
# entry gate.
#
# Mechanism: a `nix` PATH shim (environment.systemPackages — the system
# profile precedes user profiles in NixOS's default PATH order) that
# refuses eval/build-class subcommands while io PSI some avg10 is at/over
# the deploy-gate threshold or the memory-emergency-guard tripped inside
# the window, then execs the REAL nix by its baked store path (no PATH
# recursion). Cooperative by design: NIX_HEAVY_GATE_FORCE=1 bypasses
# loudly (the DEPLOY_FORCE_PRESSURE pattern — building the fix under
# pressure must stay possible), read-only subcommands pass through
# ungated, and an unreadable pressure/history file fails OPEN (a bricked
# nix would be its own incident class).
#
# Known bounds (deliberate): shell-level shims cannot stop every PATH
# shape (user-profile shadowing, absolute store paths) — this is the
# admission gate for agent + interactive sessions, not a jail. The
# deploy.sh, thermal-pstate-guard, and memory-emergency-guard legs own the
# rest of the stack.
#
# The escape hatch crosses sudo: deploy tooling re-invokes nix under
# `sudo env …` (nh's post-switch profile-set leg), so
# platforms/nixos/system/sudo.nix carries `Defaults env_keep +=
# "NIX_HEAVY_GATE_FORCE"` — without it the sudo'd leg runs the shim
# WITHOUT the var and refuses even though the caller forced every outer
# call (the 2026-10-14 UNANCHORED class, pinned by the gate selftest's
# tripwire).
{
  flake.nixosModules.nix-heavy-builds-gate =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.nix-heavy-builds-gate;

      gateScript = pkgs.writeShellApplication {
        name = "nix-heavy-builds-gate";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.gnugrep
        ];
        text = builtins.readFile ../../../scripts/nix-heavy-builds-gate.sh;
      };

      # The `nix` shim: substitutes the real nix store path and the module
      # options into the gate script and installs it under the name `nix`
      # so PATH resolution reaches the gate first.
      nixShim = pkgs.runCommand "nix" { } ''
        mkdir -p $out/bin
        substitute ${gateScript}/bin/nix-heavy-builds-gate $out/bin/nix \
          --replace-fail '@realNix@' '${lib.getExe config.nix.package}' \
          --replace-fail '{NIX_HEAVY_GATE_PSI:-80}' '{NIX_HEAVY_GATE_PSI:-${toString cfg.psiAvg10ThresholdPercent}}' \
          --replace-fail '{NIX_HEAVY_GATE_TRIP_WINDOW:-3600}' '{NIX_HEAVY_GATE_TRIP_WINDOW:-${
            toString (cfg.tripWindowMinutes * 60)
          }}' \
          --replace-fail '{NIX_HEAVY_GATE_HISTORY:-/var/lib/memory-emergency-guard/trip-history}' '{NIX_HEAVY_GATE_HISTORY:-${cfg.guardStateDir}/trip-history}'
        chmod +x $out/bin/nix
      '';
    in
    {
      options.services.nix-heavy-builds-gate = {
        enable = lib.mkEnableOption "No-heavy-builds admission gate: a `nix` PATH shim refusing eval/build-class invocations while io PSI is at/over the deploy-gate threshold or the memory-emergency-guard tripped within the window (the freeze-14-#25 interactive-battery death class)";

        psiAvg10ThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 80;
          description = "io PSI some avg10 percentage at/over which nix eval/build invocations are refused. Deliberately ABOVE deploy.sh's 20% deploy gate (owner call 2026-10-14): the shim's job is stopping fresh eval/build batteries INTO a death-band storm, not blocking ordinary work in the chronic 20-60% noise band; deploy.sh's trip-recency veto still covers the storm band";
        };

        tripWindowMinutes = lib.mkOption {
          type = lib.types.int;
          default = 60;
          description = "A memory-emergency-guard trip inside this window refuses nix eval/build invocations even during episodic PSI dips (the freeze-25 class: deploys raced a dip 5 min after a trip). Mirrors deploy.sh's zone6_recent gate";
        };

        guardStateDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/memory-emergency-guard";
          description = "The guard's state dir — its trip-history file (pruned to a 1h window by the guard itself) is the trip-recency source, read directly instead of a journal walk (a journalctl -n walk during a storm is an IO trap, the io-psi-forensics lesson)";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ nixShim ];
      };
    };
}
