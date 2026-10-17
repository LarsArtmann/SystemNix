# Boot-blocking oneshot TIMEOUT BOUNDS (2026-10-17 infinite-boot class).
#
# systemd-shape-audit class 7 makes an unbounded TimeoutStartSec on a
# multi-user/graphical-wanted Type=oneshot unit unrepresentable — a wedged
# one holds the boot transaction open forever (netbird-evox2-login kept
# FinishTimestampMonotonic=0 for 55+ min). NOTE: timeout-audit.nix's global
# DefaultTimeoutStartSec=3min does NOT cover this class — systemd's oneshot
# default is INFINITY independent of the manager default.
#
# The serviceOneshotDefaults 5min mkDefault floor covers every unit that
# uses the house helper; these are the units rendered WITHOUT it (nixpkgs
# modules, flake-input modules, computed-name factories) — bounded here in
# one place instead of being allowlisted, because each is a fast
# system-setup job with no legitimate long leg. If one ever gains a long
# leg, move its bound to the owning module with the real number.
_: {
  flake.nixosModules.boot-oneshot-bounds =
    { lib, ... }:
    {
      systemd.services = lib.genAttrs
        [
          # nixpkgs/foreign-rendered boot setup oneshots
          "cpufreq"
          "sshd-keygen"
          "logrotate-checkconf"
          "linger-users"
          "post-boot"
          # in-repo factories that do not route through serviceOneshotDefaults
          "inboxclean-backup-dir"
          "mglru-thrash-protection"
          "restic-app-dumps-setup"
          "restic-storage-history-setup"
          "signoz-clickhouse-log-ttl"
        ]
        (_name: {
          serviceConfig.TimeoutStartSec = lib.mkDefault "5min";
        });
    };
}
