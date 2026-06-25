# Common systemd service defaults for long-running daemons.
#
# Usage in service modules:
#   serviceDefaults = import ../../../lib/systemd/service-defaults.nix lib;
#   serviceConfig = harden {MemoryMax = "1G";} // serviceDefaults {};
#
# All values use lib.mkForce to override nixpkgs module defaults where needed.
#
# For Home Manager user services (where mkForce is invalid), use serviceDefaultsUser:
#   serviceDefaultsUser {} // { RestartSec = "10s"; }
#
# For Type=oneshot services, use serviceOneshotDefaults instead of serviceDefaults.
# serviceDefaults defaults to Restart=always which CRASHES oneshot services:
#   BAD:  harden {} // serviceDefaults {} // {Type = "oneshot";}  ← systemd refuses to start
#   GOOD: harden {} // serviceOneshotDefaults {} // {Type = "oneshot";}
#
# WatchdogSec is NOT included by default — it requires sd_notify() support
# in the service binary. Verify the service sends periodic WATCHDOG=1 (not just READY=1)
# before adding WatchdogSec.
#
# StartLimitBurst/StartLimitIntervalSec are NOT included here because they
# belong in [Unit], not [Service]. Set them as top-level service options:
#   systemd.services.foo = {
#     startLimitBurst = 3;
#     startLimitIntervalSec = 60;
#     serviceConfig = harden {} // serviceDefaults {};
#   };
lib: let
  mkDefaults = useMkForce: defaultRestart: {
    Restart ? defaultRestart,
    RestartSec ? "5s",
  }: {
    Restart =
      if useMkForce
      then lib.mkForce Restart
      else Restart;
    RestartSec =
      if useMkForce
      then lib.mkForce RestartSec
      else RestartSec;
  };
in {
  # System services (valid with mkForce)
  serviceDefaults = mkDefaults true "always";

  # Home Manager user services (no mkForce — HM doesn't support it)
  serviceDefaultsUser = mkDefaults false "always";

  # Type=oneshot services — Restart=always is INVALID for oneshot.
  # These default to Restart=no (the only universally safe value for oneshot).
  # Override to "on-failure" if retry-on-error is desired (still valid for oneshot).
  serviceOneshotDefaults = mkDefaults true "no";
  serviceOneshotDefaultsUser = mkDefaults false "no";

  # onFailure handler — route service failures to the notify-failure template
  onFailure = ["notify-failure@%n.service"];
}
