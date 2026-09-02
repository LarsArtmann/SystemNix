# Pure-eval guard for the niri-session-manager app-list invariants
# (2026-08-31 terminal-storm class). No VM, no host eval: the test imports
# the SAME data file home.nix consumes, so the guarded surface is the real
# single source of truth — a second implementation could drift.
#
# Positive case: the shipped lists must satisfy mkInvariantViolations.
# Negative cases: the historical bug (a terminal app-id dropped from
# single_instance_apps) and the transient-dialog regression (gcr-prompter
# dropped from skip_apps) must both be CAUGHT — a checker that passes on
# everything is phantom-green and worthless.
{
  pkgs,
}:
let
  apps = import ../platforms/nixos/users/niri-session-manager-apps.nix;

  violations = apps.mkInvariantViolations apps;

  # The exact historical bug: ghostty silently disappears from
  # single_instance_apps (the entry that stopped the 152-terminals-per-login
  # storm) while staying a known terminal app-id.
  terminalDropped = apps // {
    singleInstanceApps = pkgs.lib.filter (id: id != "com.mitchellh.ghostty") apps.singleInstanceApps;
  };
  terminalDroppedViolations = apps.mkInvariantViolations terminalDropped;

  # The transient-dialog regression: gcr-prompter dropped from skip_apps.
  transientDropped = apps // {
    skipApps = pkgs.lib.filter (id: id != "gcr-prompter") apps.skipApps;
  };
  transientDroppedViolations = apps.mkInvariantViolations transientDropped;

  cases = [
    {
      name = "shipped-lists-violate-invariants";
      pass = violations == [ ];
    }
    {
      name = "terminal-dropped-from-single_instance-not-caught";
      pass =
        terminalDroppedViolations != [ ]
        && pkgs.lib.any (v: pkgs.lib.hasPrefix "niri-session-manager: terminal app-id \"com.mitchellh.ghostty\"" v) terminalDroppedViolations;
    }
    {
      name = "gcr-prompter-dropped-from-skip_apps-not-caught";
      pass =
        transientDroppedViolations != [ ]
        && pkgs.lib.any (v: pkgs.lib.hasPrefix "niri-session-manager: gcr-prompter" v) transientDroppedViolations;
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "niri-session-config-guard-test" { } "touch $out"
else
  throw ''
    niri-session-manager config guard regression: ${toString broken}

    Either the shipped app lists violate the storm-prevention invariants
    (fix the lists in platforms/nixos/users/niri-session-manager-apps.nix)
    or the checker stopped catching the historical bugs (fix
    mkInvariantViolations — the negative cases in this test are the proof
    it still bites).
  ''
