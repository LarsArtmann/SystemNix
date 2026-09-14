# amdgpu: NULL deref in isp_genpd_remove_device on Strix Halo unbind after OOM

## Summary

On AMD Ryzen AI Max+ 395 (Strix Halo), after a severe OOM event that killed
session services while GPU compute was active, the amdgpu driver enters an
unrecoverable state. Attempting to recover via driver unbind/rebind triggers:

1. **NULL pointer dereference** in `isp_genpd_remove_device()` (ISP power domain cleanup)
2. **Rebind hangs** in D-state, creates no DRM devices
3. **CPU power management broken** — all cores stuck at 600 MHz (min is 2 GHz)

Only recovery: full system reboot.

## Hardware

```
CPU/APU:    AMD Ryzen AI Max+ 395 (Strix Halo, gfx1151, 16C/32T)
GPU:        AMD [1002:1586] Strix Halo [Radeon 8060S Graphics] (same die as CPU)
PCI:        0000:c5:00.0 (class 0380, rev c1)
VRAM:       65536M LPDDR5 (256-bit, unified with system RAM)
Display:    DCN 3.5.1 (Display Core v3.2.369)
SMU:        smu_v14_0_0
ISP:        isp_v4_1_1
BIOS:       GMKtec EVO-X2 1.11 (10/17/2025)
ATOM BIOS:  113-STRXLGEN-001
DMUB:       version 0x09004100
amdgpu:     3.64.0 (module)
```

## Software

```
Kernel:              7.0.1 #1-NixOS PREEMPT(lazy) x86_64
Kernel config:       CONFIG_DRM_AMDGPU=m, CONFIG_DRM_AMD_DC=y, CONFIG_AMD_PSTATE=guided
NixOS:               26.05.20260423.01fbdee (config: e68cf647983924b1c5449dff2b1566ae39e0658a)
Compositor:          niri (Wayland, scrollable-tiling)
Config repo:         https://github.com/LarsArtmann/SystemNix (commit e68cf647983924b1c5449dff2b1566ae39e0658a)
```

## Kernel boot parameters (relevant)

```
amdgpu.deepfl=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1
amdgpu.gttsize=131072 amdgpu.ttm.pages_limit=31457280
amd_iommu=on amd_pstate=guided
```

## amdgpu module parameters at runtime

```
gpu_recovery = -1 (auto)
lockup_timeout = 30000
reset_method = -1 (auto)
ppfeaturemask = 0xfff7bfff
mes = 0
ip_block_mask = 4294967295 (all blocks enabled)
dc = -1 (auto)
```

## Boot-time driver initialization (clean boot)

```
[drm] ATOM BIOS: 113-STRXLGEN-001
[drm] Detected VRAM RAM=65536M, BAR=65536M
[drm] RAM width 256bits LPDDR5
[drm] GTT size: 137438953472, TTM size: 128849018880
[drm] PCIE GART of 512M enabled
[drm] Loading DMUB firmware via PSP: version=0x09004100
[VCN 0] Version ENC: 1.24 DEC: 9 VEP: 0 Revision: 16
[VCN 1] Version ENC: 1.24 DEC: 9 VEP: 0 Revision: 16
SMU is initialized successfully!
[drm] Display Core v3.2.369 initialized on DCN 3.5.1
[drm] HDMI-A-1 + DP-1 through DP-8 (8 outputs)
detected ip block number 4  <smu_v14_0_0> (smu)
detected ip block number 12 <isp_v4_1_1> (isp_ip)
```

## Timeline (all times UTC+2)

| Time           | Event                                                                                                                                                                                                      |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| May 04 22:38   | Clean boot. amdgpu 3.64.0 initializes. SMU OK. DCN 3.5.1 OK. ISP v4.1.1 detected.                                                                                                                          |
| May 05 ~23:14  | AI workloads running: llama-server (multimodal GPU compute via libhsa-runtime64), Minecraft (java), 30+ node/vtsls processes                                                                               |
| 23:14:40       | System under memory pressure. journald flushing caches repeatedly.                                                                                                                                         |
| 23:14:52       | earlyoom triggers: SIGTERM llama-server (947 MiB). Memory at 9%, swap at 10%.                                                                                                                              |
| 23:15:05-08    | earlyoom kills dozens of node processes (vtsls), java (Minecraft), python3, helium                                                                                                                         |
| 23:16:03-19    | Swap exhausted (0 MiB free). earlyoom SIGKILLs: systemd-coredump, awww-daemon, wallpaper-set, dunst, pipewire-pulse, gcr-ssh-agent, **dbus-broker**, systembus-notify, swayidle, dconf-service, **waybar** |
| ~23:16:19      | niri loses DRM master. First "Permission denied" on DRM page flip. libinput reports "system is too slow".                                                                                                  |
| 23:16:19       | GPU device change detected. niri: "error emitting MonitorsChanged: BrokenPipe"                                                                                                                             |
| 23:16:28-25:33 | Multiple python3.13 segfaults in libhsa-runtime64.so (GPU compute library)                                                                                                                                 |
| 23:39:19       | Memory recovered: 84.77% RAM free, 76.10% swap free                                                                                                                                                        |
| May 06 00:22   | First niri restart attempt (systemd Restart=always). New PID gets "DeviceMissing" DRM errors.                                                                                                              |
| 02:50:05       | GPU reset attempted via sysfs. "resetting" / "reset done". DRM still broken.                                                                                                                               |
| 04:46:25       | Driver unbind attempted for recovery. Console switches to dummy device.                                                                                                                                    |
| 04:46:25       | `amdgpu: VM memory stats for proc (0) task (0) is non-zero when fini` — GPU VM already corrupted                                                                                                           |
| 04:46:25       | `kfd: Sending SIGBUS to process 3550225`                                                                                                                                                                   |
| 04:46:29       | **KERNEL OOPS**: NULL deref in `isp_genpd_remove_device+0x1c`                                                                                                                                              |
| 04:46:29       | `note: tee[1700675] exited with irqs disabled`                                                                                                                                                             |
| 04:50:27       | perf interrupt latency: 2508 > 2500                                                                                                                                                                        |
| ~05:00         | CPU frequency stuck at 600 MHz on all cores (user observation)                                                                                                                                             |
| 05:00:40       | perf interrupt latency: 3344 > 3135                                                                                                                                                                        |
| 05:34          | Driver rebind attempted. Hangs in D-state, no Ctrl+C possible.                                                                                                                                             |
| 05:34          | CPU at 600 MHz, 100% load, 89°C, 144W. Not thermal throttling.                                                                                                                                             |

## Bug 1: NULL Pointer Dereference in isp_genpd_remove_device

**Trigger:** `echo 0000:c5:00.0 > /sys/bus/pci/drivers/amdgpu/unbind`

**Call chain:** `unbind_store` → `device_release_driver_internal` → `pci_device_remove` →
`amdgpu_pci_remove` → `amdgpu_device_fini_hw` → `amdgpu_ip_block_hw_fini` →
`isp_v4_1_1_hw_fini` → `device_for_each_child` → `isp_genpd_remove_device`

**Crash:**

```
BUG: unable to handle page fault for address: ffffffffffffffb8
#PF: supervisor read access in kernel mode
#PF: error_code(0x0000) - not-present page
Oops: 0000 [#1] SMP NOPTI
CPU: 16  PID: 1700675  Comm: tee  Tainted: G O

RIP: 0010:isp_genpd_remove_device+0x1c/0xc0 [amdgpu]
Code: 90 90 90 90 90 90 90 90 90 90 90 90 90 90 f3 0f 1e fa 0f 1f 44 00 00
      48 83 ff 10 0f 84 98 00 00 00 55 53 48 8b 47 58 48 89 fb <48> 8b 6e b8

RAX: 0000000000000000  RBX: ffff8c10cbd66400  RCX: 0000000000000003
RDX: ffff8c10cb66f300  RSI: 0000000000000000  RDI: ffff8c10cbd66400
RBP: ffffffffc194ac60  R08: 0000000000000286  R09: 0000000000000087
R10: 0000000000000003  R11: ffff8c10cbc57800  R12: ffff8c10e8854460
R13: ffffffffc1a5fd08  R14: ffff8c10cbd70158  R15: 0000000000000000
CR2: ffffffffffffffb8
```

**Analysis:** `ffffffffffffffb8` = -72 (NULL base + field offset 0x48). RBP points into
amdgpu module space (`c194ac60`). The ISP genpd cleanup walks child devices and
dereferences a NULL provider/parent pointer. The ISP block (`isp_v4_1_1`) was detected
at boot (ip block 12) but its genpd state was corrupted during the OOM event — the GPU
VM was already in inconsistent state (`proc (0) task (0) is non-zero when fini`).

**Additional:** Process exited with `irqs disabled`, potentially leaving CPU 16 in
broken interrupt state.

## Bug 2: Rebind Hangs in D-state

**Trigger:** `echo 0000:c5:00.0 > /sys/bus/pci/drivers/amdgpu/bind`

- Not interruptible by Ctrl+C, SIGINT, or SIGTERM
- Only closing the terminal (SIGHUP to session) terminates it
- No DRM devices created (`/sys/class/drm/` contains only `version`)
- No PCI device listed under `/sys/bus/pci/drivers/amdgpu/`
- No kernel log output from amdgpu during bind attempt
- Process stuck in D-state (uninterruptible sleep)

## Bug 3: DRM State Unrecoverable After OOM

After the OOM event kills dbus-broker and logind:

- GPU reset (`/sys/class/drm/card1/device/reset`) reports "resetting" / "reset done" but DRM remains broken
- New niri process gets `Error::DeviceMissing` on DRM operations
- GPU hardware is functional (amdgpu loaded, card1 exists, SMU responsive)
- DRM/KMS cannot initialize outputs or do page flips
- The ISP block (`isp_v4_1_1`) genpd state is corrupted (confirmed by Bug 1 crash)

## Bug 4: CPU Power Management Corrupted

**Onset:** ~30 minutes after the kernel oops (gradual, not immediate)

**Symptoms:**

```
scaling_driver:              amd-pstate
amd_pstate status:           guided
amd_pstate prefcore:         enabled
boost:                       1 (enabled)
scaling_min_freq:            2000000 (2.0 GHz)
scaling_max_freq:            5187500 (5.1 GHz)
scaling_cur_freq:            ~603000 (600 MHz)    ← BELOW min!
cpuinfo_cur_freq:            (empty)               ← kernel can't read HW freq
energy_performance_preference: (empty)
scaling_available_frequencies: (empty)

All 16 cores: 98-100% utilization at 600 MHz
Temperature: 89°C  Power: 144W  (NOT thermal throttling)
```

**Context:** Strix Halo has CPU + GPU + SMU + ISP on the same die. The SMU manages
power and frequency for the entire SoC. The `isp_genpd_remove_device` crash in the
ISP power domain cleanup appears to have corrupted the SMU's power state machine,
preventing CPU boost. The `exited with irqs disabled` note suggests interrupt state
on CPU 16 was also corrupted.

**Kernel timing anomalies after oops:**

```
perf: interrupt took too long (2508 > 2500), lowering sample_rate to 79000
perf: interrupt took too long (3344 > 3135), lowering sample_rate to 59000
hrtimer: interrupt took 307571 ns   (normally <10us)
```

## Additional Context: GPU compute segfaults during OOM

Multiple `python3.13` processes segfaulted in `libhsa-runtime64.so` (AMD HSA runtime)
while the OOM was in progress:

```
python3.13[pid]: segfault at 34 ip 00007ffeeb048930 error 4
  in libhsa-runtime64.so[48930,7ffeeb01d000+11c000]
Code: ... 4c 8b 66 68 4d 39 e5 74 30 <41> 83 7c 24 34 03 49 8b 44 24 20 74 43
```

These occurred at 23:16:28, 23:22:36, 23:25:16, 23:25:33, 23:29:48, 23:31:41 — all
same IP, same code path. The GPU compute queues were actively running when memory
exhaustion hit, likely leaving the GPU VM and compute ring buffers in an inconsistent
state that the driver's cleanup paths don't handle.

## Expected Behavior

1. `isp_genpd_remove_device()` must handle NULL genpd provider gracefully — add NULL
   check before dereferencing the provider pointer in the ISP power domain cleanup path.

2. Driver rebind must not hang in D-state. If hardware reinitialization fails, return
   an error to userspace.

3. GPU reset via sysfs must fully reset the DRM/KMS subsystem, not just report success
   while leaving internal state corrupted.

4. A GPU driver crash must not affect CPU power management. The SMU power state must
   remain independent of the amdgpu driver lifecycle.

## Reproduction

1. System: AMD Ryzen AI Max+ 395 (Strix Halo) with DCN 3.5.1, SMU v14.0.0, ISP v4.1.1
2. Run GPU compute workloads (llama-server multimodal, ROCm/PyTorch via libhsa-runtime64)
3. Exhaust all system RAM + swap (128GB + 42GB swap in this case)
4. Have earlyoom kill dbus-broker and logind during OOM recovery
5. Observe: DRM permanently broken, GPU reset ineffective
6. Attempt: `echo 0000:c5:00.0 > /sys/bus/pci/drivers/amdgpu/unbind`
7. Result: NULL deref oops in isp_genpd_remove_device
8. Attempt: `echo 0000:c5:00.0 > /sys/bus/pci/drivers/amdgpu/bind`
9. Result: Hangs in D-state, no DRM devices created
10. Observe: CPU frequency stuck at 600 MHz across all cores
