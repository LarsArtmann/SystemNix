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
#
# RestartSec convention (2026-08-14 audit): the 5s default fits most daemons.
# Intentional outliers: dnsblockd 3s (DNS must recover fast), browser-history
# 2-5min (avoid crash-loop amplification), immich 10s (heavy startup; the
# former twenty 10s died with the module, 2026-10-08). Do NOT normalize
# these — each is tuned to the service's restart cost.
#
# TimeoutStopSec convention: no global default. Systemd default (90s) applies;
# services with slow graceful shutdown set their own (15s-60s). A manager-level
# DefaultTimeoutStopSec could be added later if 90s proves too generous.
#
# Deliberately NOT in harden() (service-specific, not safe as defaults):
# - ProcSubset / ProtectProc: breaks services that pgrep other processes
#   (monitor365 already overrides ProtectProc=default via mkForce)
# - RestrictAddressFamilies: service-specific socket needs (only dnsblockd sets it)
# - UMask: application-specific file permission model
# - PrivateDevices: audio/video/DVB services need /dev device access
lib:
let
  mkDefaults =
    useMkForce: defaultRestart:
    {
      Restart ? defaultRestart,
      RestartSec ? "5s",
    }:
    {
      Restart = if useMkForce then lib.mkForce Restart else Restart;
      RestartSec = if useMkForce then lib.mkForce RestartSec else RestartSec;
    };
in
{
  # System services (valid with mkForce)
  serviceDefaults = mkDefaults true "always";

  # Home Manager user services (no mkForce — HM doesn't support it)
  serviceDefaultsUser = mkDefaults false "always";

  # Type=oneshot services — Restart=always is INVALID for oneshot.
  # These default to Restart=no (the only universally safe value for oneshot).
  # Override to "on-failure" if retry-on-error is desired (still valid for oneshot).
  #
  # TimeoutStartSec (2026-10-17 infinite-boot class): a Type=oneshot start
  # job has an INFINITE default timeout in systemd — a wedged boot-blocking
  # oneshot (netbird-evox2-login's unguarded login poll held
  # FinishTimestampMonotonic=0 for 55+ min) freezes the boot transaction
  # forever. mkDefault (not mkForce): units with a legitimate LONG leg
  # (llama-rag-model-fetch 20min, monitor365-schema-migrate 3min, …) declare
  # their own value and win the merge; the 5min floor only catches units
  # that never stated a need. Enforced repo-wide by systemd-shape-audit
  # class 7 for boot-blocking (multi-user/graphical) oneshots.
  serviceOneshotDefaults =
    args:
    (mkDefaults true "no" args)
    // {
      TimeoutStartSec = lib.mkDefault "5min";
    };
  serviceOneshotDefaultsUser =
    args:
    (mkDefaults false "no" args)
    // {
      TimeoutStartSec = lib.mkDefault "5min";
    };

  # onFailure handler — route service failures to the notify-failure template
  onFailure = [ "notify-failure@%n.service" ];
}
