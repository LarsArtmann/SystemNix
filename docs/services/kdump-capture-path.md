# kdump-capture-path

**Module:** `modules/nixos/services/kdump-capture-path.nix` (auto-discovered as `flake.nixosModules.kdump-capture-path`; active whenever `boot.crashDump.enable` is true)
**Capture-side units:** `modules/nixos/services/_kdump-capture-units.nix` (`kdump-save.service`, `kdump-retention.service` + timer, the `/var/crash` tmpfiles rule)
**VM regression test:** `checks.x86_64-linux.kdump-capture-boot` (`tests/test-kdump-capture-boot.nix`, one fixed node and one unfixed control node)
**Gates that read it:** `scripts/pre-reboot-check.sh` section 12 (contract of the generation the reboot boots), `scripts/post-deploy-check.sh` (kdump capture contract), `scripts/crash-triage.sh` (`kdump=` verdict per boot), `scripts/boot-evidence-pull.sh` (pstore section)
**Created:** 2026-11-25, after the two evidence-less panic cuts #64 (08:57:47) and #65 (11:05:51)

## What it does (three legs)

1. **The capture boot is not the main boot.** nixpkgs' `boot.crashDump` loads the same kernel, the same initrd and the same system init into the crashkernel reservation and boots it with `irqpoll maxcpus=1 reset_devices 1`. Until 2026-11-25 that boot ran `systemd-sysctl` like any other and inherited the host sysctl bag, including `vm.min_free_kbytes = 2097152`: a 2 GiB zone watermark inside 512 MiB. Every `GFP_KERNEL` allocation then fails, the capture kernel OOM-kills its own boot and panics `System is deadlocked on memory` at uptime 9-13 s. The module adds `ConditionPathExists=!/proc/vmcore` to `systemd-sysctl.service` and a unit `kdump-capture-boot-sysctl.service` (`ConditionPathExists=/proc/vmcore`) that sets only `kernel.panic`, to the host's own value, so a capture kernel that panics for any other reason still reboots by itself.
2. **The crashed kernel's log reaches pstore before kexec.** With a loaded crash image, `vpanic()` (kernel 7.3, `kernel/panic.c`) calls `__crash_kexec()` before `kmsg_dump_desc(KMSG_DUMP_PANIC)`, so the EFI pstore dump was never written and the "Rebooting in N seconds" loop never ran. `crash_kexec_post_notifiers` (added to `boot.kernelParams`) runs the panic notifiers and the kmsg dump first: the newest ~36 KB of the crashed kernel's log land in pstore, `systemd-pstore` archives them.
3. **A deploy never reloads the crash image.** nixpkgs loads it once per boot (`boot.postBootCommands`, `kexec -p /run/current-system/kernel`) with the init of the BOOTING generation baked into its cmdline. Every change to legs 1 and 2 is live only after the next boot. `scripts/pre-reboot-check.sh` section 12 audits exactly that generation before a planned reboot.

## What a panic leaves behind (once the fix has booted)

| Artifact | Path | Written by | Content |
| -------- | ---- | ---------- | ------- |
| vmcore-dmesg | `/var/crash/<YYYYmmdd-HHMMSS>/vmcore-dmesg.txt` | `kdump-save.service` in the capture boot | full dmesg of the crashed kernel: panic line, call trace, everything the journal never flushed |
| capture-boot evidence | same directory: `capture-boot-dmesg.txt`, `capture-boot-meminfo.txt`, `capture-boot-uptime.txt` | `kdump-save.service` | headroom of the capture kernel (proves or refutes that `reservedMemory` is large enough) |
| pstore archive | `/var/lib/systemd-pstore/<epoch>/001/dmesg.txt` (files root-only) | `systemd-pstore` | newest ~36 KB of the crashed kernel's log; the same text is readable by everyone through the journal `FILE=` lines of `systemd-pstore` |

Retention: `kdump-retention` keeps the 2 newest entries, 20 G cap, boot + weekly timer.

## How to read a dump

- `N pages RAM` below about 2000000 in a pstore dump = the 512 MiB capture kernel is speaking, not the crashed one. `min:2097152kB` plus `System is deadlocked on memory` = the capture kernel OOM-panicked (the pre-fix signature of #61, #62, #64, #65).
- Parts are stored newest-first (`Panic#1 Part1` holds the last lines); the archive's `dmesg.txt` is already chronological.
- `scripts/crash-triage.sh` prints one `kdump=` verdict per boot: `main-kernel-panic-captured`, `capture-kernel-OOM`, `capture-kernel-panicked`, `none`.

## Verification (2026-11-25)

- VM test green (`nix build .#checks.x86_64-linux.kdump-capture-boot -L`, 2 min 13 s): the fixed node crashes (`echo c > /proc/sysrq-trigger`), the capture kernel runs `kdump-save` at 7.15 s, reboots at 7.58 s, and the next boot holds `/var/crash/<ts>/vmcore-dmesg.txt` with `sysrq triggered crash` plus the main kernel's panic text under `/var/lib/systemd-pstore/`. Capture-boot memory in the VM (256 MiB reservation): `MemTotal 202224 kB, MemAvailable 113532 kB`.
- The unfixed control node: the capture boot dies right after `Apply Kernel Variables` (5.2 s), `/var/crash` stays empty and the box only returns through the capture kernel's own panic.
- Host eval green with the module (evo-x2 toplevel, 2026-11-25).

## Live acceptance (owner, one deliberate crash)

After the next reboot (both legs are boot-time): `echo c | sudo tee /proc/sysrq-trigger`, wait for the box to return (budget: the capture boot races the 90 s hardware watchdog; the VM needed 8 s), then `scripts/crash-triage.sh` must print `kdump=main-kernel-panic-captured` and `/var/crash` must contain a directory with `vmcore-dmesg.txt`. Before that reboot: `nix run .#pre-reboot-check` section 12 must pass.

## Rules

- `kexec_crash_loaded = 1` proves that the image is loaded and nothing else. It read 1 through four cuts that captured nothing.
- Do not add `pstore.*` kernel parameters. The kernel 7.3 pstore core has `backend`, `compress`, `kmsg_bytes`, `update_ms` only; `pstore.record_console` and `pstore.max_reason` sat inert on the cmdline for years (removed 2026-11-25).
- A sysctl that must reach the capture boot goes through `kdump-capture-boot-sysctl`, never into `boot.kernel.sysctl`.
- `platforms/nixos/system/boot.nix` owns only `boot.crashDump` (enable, `reservedMemory`) and the host sysctl bag.
