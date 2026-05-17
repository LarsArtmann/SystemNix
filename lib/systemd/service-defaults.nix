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
# WatchdogSec is NOT included by default — it requires sd_notify() support
# in the service binary. Only pass it for services that implement sd_notify
# (e.g., Caddy, Gitea). For all others, omit it.
#
# StartLimitBurst/StartLimitIntervalSec are NOT included here because they
# belong in [Unit], not [Service]. Set them as top-level service options:
#   systemd.services.foo = {
#     startLimitBurst = 3;
#     startLimitIntervalSec = 60;
#     serviceConfig = harden {} // serviceDefaults {};
#   };
lib: let
  mkDefaults = useMkForce: {
    Restart ? "always",
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
  serviceDefaults = mkDefaults true;

  # Home Manager user services (no mkForce — HM doesn't support it)
  serviceDefaultsUser = mkDefaults false;

  # onFailure handler — route service failures to the notify-failure template
  onFailure = ["notify-failure@%n.service"];
}
