# VM test for the kdump capture path (modules/nixos/services/kdump-capture-path.nix).
#
# Proves, against the REAL modules, that one deliberate kernel panic leaves
# evidence behind, and that the 2026-11-25 defect reproduces without the fix:
#
#   node `fixed`  imports kdump-capture-path. After the crash the box comes
#                 back with /var/crash/<ts>/vmcore-dmesg.txt containing the
#                 main kernel's panic line, and /var/lib/systemd-pstore holds
#                 the main kernel's pstore dump (crash_kexec_post_notifiers).
#   node `broken` imports only _kdump-capture-units (the capture-side units
#                 without the two legs). The capture kernel inherits
#                 vm.min_free_kbytes from the host sysctl bag, a watermark
#                 larger than its own RAM, OOM-panics ("System is deadlocked
#                 on memory"), nothing lands in /var/crash and the only pstore
#                 dump is the capture kernel's own: the live signature of the
#                 cuts #61, #62, #64 and #65.
#
# Sizing mirrors evo-x2 in miniature: a 256 MiB crashkernel inside 2048 MiB,
# and a main-boot watermark (307 MiB) that is harmless in the main boot and
# fatal in the capture boot. The capture boot runs under EFI so the
# efi_pstore backend exists, exactly like the host.
{ pkgs, ... }:
let
  capturePath = (import ../modules/nixos/services/kdump-capture-path.nix { }).flake.nixosModules.kdump-capture-path;
  captureUnits = import ../modules/nixos/services/_kdump-capture-units.nix;
in
{
  name = "kdump-capture-boot";

  nodes = {
    fixed.imports = [ capturePath ];
    broken.imports = [ captureUnits ];
  };

  defaults = {
    virtualisation.memorySize = 2048;
    virtualisation.cores = 2;
    virtualisation.useEFIBoot = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.crashDump.enable = true;
    boot.crashDump.reservedMemory = "256M";
    boot.kernel.sysctl = {
      "vm.min_free_kbytes" = 314572; # 307 MiB
      "kernel.panic" = 10;
      "kernel.sysrq" = 1;
    };
  };

  testScript = ''
    def crash_cycle(machine):
        machine.wait_for_unit("multi-user.target")
        machine.succeed("test \"$(cat /sys/kernel/kexec_crash_loaded)\" = 1")
        machine.succeed("grep -q crashkernel=256M /proc/cmdline")
        machine.execute("echo c > /proc/sysrq-trigger", check_return=False, check_output=False)
        machine.wait_for_shutdown()
        machine.switch_root()


    start_all()

    with subtest("main boot: the sysctl bag is applied and the crash image is loaded"):
        for node in (fixed, broken):
            node.wait_for_unit("multi-user.target")
            node.succeed("test \"$(cat /proc/sys/vm/min_free_kbytes)\" = 314572")

    with subtest("fixed: capture-path legs are present in the main boot"):
        fixed.succeed("grep -q crash_kexec_post_notifiers /proc/cmdline")
        fixed.succeed("grep -q 'ConditionPathExists=!/proc/vmcore' /etc/systemd/system/systemd-sysctl.service")
        fixed.succeed("systemctl is-active systemd-sysctl.service")
        fixed.fail("systemctl is-active --quiet kdump-capture-boot-sysctl.service")

    with subtest("broken: the control node has neither leg"):
        broken.fail("grep -q crash_kexec_post_notifiers /proc/cmdline")

    with subtest("fixed: the panic is captured"):
        crash_cycle(fixed)
        fixed.wait_for_unit("multi-user.target")
        dump = fixed.succeed("ls -1 /var/crash | tail -1").strip()
        fixed.succeed("test -s /var/crash/%s/vmcore-dmesg.txt" % dump)
        fixed.succeed("grep -q 'sysrq triggered crash' /var/crash/%s/vmcore-dmesg.txt" % dump)
        fixed.succeed("test -s /var/crash/%s/capture-boot-meminfo.txt" % dump)
        fixed.log("capture-boot memory: " + fixed.succeed("grep -E 'MemTotal|MemAvailable' /var/crash/%s/capture-boot-meminfo.txt | tr '\\n' ' '" % dump).strip())
        fixed.succeed("grep -rq 'sysrq triggered crash' /var/lib/systemd/pstore/")

    with subtest("broken: without the module the capture boot dies and nothing is captured"):
        crash_cycle(broken)
        broken.wait_for_unit("multi-user.target")
        broken.succeed("test -z \"$(ls -1 /var/crash)\"")
        broken.succeed("grep -rq 'System is deadlocked on memory' /var/lib/systemd-pstore/")
        broken.fail("grep -rq 'sysrq triggered crash' /var/lib/systemd-pstore/")
  '';
}
