# CRASH-CAPTURE PATH (2026-11-25): keep the kdump capture boot alive and make
# the main kernel's panic text reach pstore before kexec.
#
# Why this module exists (two cuts on 2026-11-25, 08:57:47 and 11:05:51, both
# with zero panic evidence although kexec_crash_loaded read 1):
#
#  1. nixpkgs' boot.crashDump loads the SAME kernel, the same initrd and the
#     same system init into the crashkernel reservation and boots it with
#     "irqpoll maxcpus=1 reset_devices 1". That boot is a full systemd boot,
#     so systemd-sysctl applied the host sysctl bag there too, including
#     vm.min_free_kbytes = 2097152: a 2 GiB zone watermark inside a 512 MiB
#     kernel. Every GFP_KERNEL allocation then fails below a mark the zone can
#     never reach; the capture kernel OOM-killed its own boot (udevd,
#     systemd-remount-fs, firewall-start) and panicked "System is deadlocked
#     on memory" at uptime 11-13 s. kdump-save never ran, /var/crash stayed
#     empty and the box rebooted through the capture kernel's own panic.
#     /proc/vmcore exists only in that boot, so it is the discriminator: the
#     sysctl bag is conditioned away there and the capture boot runs kernel
#     defaults plus the one tunable it needs (auto-reboot on its own panic).
#
#  2. With a crash image loaded, vpanic() (kernel 7.3, kernel/panic.c) calls
#     __crash_kexec() BEFORE kmsg_dump_desc(KMSG_DUMP_PANIC): the EFI pstore
#     dump of the crashed kernel is never written and "Rebooting in N seconds"
#     never happens. crash_kexec_post_notifiers reorders that (stop other
#     CPUs, panic notifiers, kmsg dump, then kexec), so the last kmsg_bytes of
#     the crashed kernel land in pstore and systemd-pstore archives them.
#
#  3. The crash image is loaded once per boot (nixpkgs: boot.postBootCommands
#     "kexec -p /run/current-system/kernel") with the init of the BOOTING
#     generation in its cmdline. A deploy does not reload it: every leg here
#     is live only after the next boot.
#
# Proof is a capture, not a load. The acceptance test is one deliberate crash
# after a reboot (echo c | sudo tee /proc/sysrq-trigger): it must leave
# /var/crash/<ts>/vmcore-dmesg.txt and a main-kernel pstore dump
# (scripts/crash-triage.sh prints the verdict). VM regression test:
# tests/test-kdump-capture-boot.nix (fixed and unfixed nodes). The
# capture-side units (kdump-save, kdump-retention, /var/crash) live in
# _kdump-capture-units.nix and are imported here.
_: {
  flake.nixosModules.kdump-capture-path =
    { config, lib, ... }:
    let
      captureMarker = "/proc/vmcore";
      # Single source: the main boot's own kernel.panic (the sysctl bag), so
      # the capture kernel reboots after the same delay if it panics itself.
      panicTimeout = toString (config.boot.kernel.sysctl."kernel.panic" or 10);
    in
    {
      imports = [ ./_kdump-capture-units.nix ];

      config = lib.mkIf config.boot.crashDump.enable {
        boot.kernelParams = [ "crash_kexec_post_notifiers" ];

        systemd.services.systemd-sysctl = {
          unitConfig.ConditionPathExists = "!${captureMarker}";
        };

        systemd.services.kdump-capture-boot-sysctl = {
          description = "Kernel tunables of the kdump capture boot (auto-reboot if the capture kernel panics)";
          wantedBy = [ "sysinit.target" ];
          before = [ "sysinit.target" ];
          unitConfig = {
            ConditionPathExists = captureMarker;
            DefaultDependencies = false;
          };
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStartSec = "30s";
          };
          script = ''
            echo ${panicTimeout} > /proc/sys/kernel/panic
          '';
        };

        assertions = [
          {
            assertion = config.systemd.services.systemd-sysctl.unitConfig.ConditionPathExists == "!${captureMarker}";
            message = "kdump-capture-path: systemd-sysctl must stay conditioned on !/proc/vmcore, the capture boot must not apply the host sysctl bag (2026-11-25 cuts 08:57:47 + 11:05:51).";
          }
          {
            assertion = builtins.elem "crash_kexec_post_notifiers" config.boot.kernelParams;
            message = "kdump-capture-path: crash_kexec_post_notifiers must stay on the main kernel cmdline, otherwise the crashed kernel's panic text never reaches pstore.";
          }
        ];
      };
    };
}
