# Debugging the amdgpu Strix Halo Bug

Practical guide to reproducing, debugging, and fixing the four bugs documented in
`amdgpu-kernel-bug-report.md`.

## Source Code Navigation

### Key files in `drivers/gpu/drm/amd/amdgpu/`

| File                    | Purpose                                                                    |
| ----------------------- | -------------------------------------------------------------------------- |
| `isp_v4_1_1.c`          | ISP v4.1.1 block — contains `isp_genpd_remove_device()` (Bug 1 crash site) |
| `isp_v4_1_1.h`          | ISP v4.1.1 header — struct definitions                                     |
| `isp_common.c`          | Shared ISP functions                                                       |
| `amdgpu_device.c`       | `amdgpu_device_fini_hw()` — calls ip block fini chain                      |
| `amdgpu_ip_block.c`     | `amdgpu_ip_block_hw_fini()` — iterates IP blocks during teardown           |
| `smu_v14_0_0.c`         | SMU v14.0.0 — power/frequency management (Bug 4)                           |
| `smu_v14_0_0_pptable.c` | SMU power play table                                                       |
| `amdgpu_reset.c`        | GPU reset handling (Bug 3 — "reset done" but still broken)                 |
| `amdgpu_drv.c`          | Module parameters, `amdgpu_pci_probe()` / `amdgpu_pci_remove()`            |
| `kfd_device.c`          | KFD (Kernel Fusion Driver) — the `Sending SIGBUS` message comes from here  |

### The crash call chain (Bug 1)

```
unbind_store()                          <- userspace writes to /sys/bus/pci/drivers/amdgpu/unbind
  device_release_driver_internal()
    pci_device_remove()
      amdgpu_pci_remove()               <- amdgpu_drv.c
        amdgpu_device_fini_hw()          <- amdgpu_device.c
          amdgpu_ip_block_hw_fini()      <- amdgpu_ip_block.c
            isp_v4_1_1_hw_fini()         <- isp_v4_1_1.c
              device_for_each_child()
                isp_genpd_remove_device() <- isp_v4_1_1.c  ** CRASH HERE **
```

### The bind path (Bug 2 — hangs)

```
bind_store()                            <- userspace writes to /sys/bus/pci/drivers/amdgpu/bind
  device_driver_attach()
    amdgpu_pci_probe()                  <- amdgpu_drv.c  ** HANGS HERE (no log output) **
      amdgpu_device_init()
        smu_v14_0_0_init()              <- smu_v14_0_0.c  (likely hangs here)
```

No log output during bind means it hangs before any `dev_info`/`dev_err` call.
Likely in SMU firmware loading or ISP power domain re-initialization.

## Getting the Kernel Source

### Option A: NixOS (matching your kernel)

```bash
# Get the exact kernel source used by your NixOS system
nix-shell -p linux.dev

# Inside the shell, source is at:
ls /build/source/drivers/gpu/drm/amd/amdgpu/isp_v4_1_1.c
```

### Option B: Upstream

```bash
git clone --depth=1 https://github.com/torvalds/linux.git
cd linux
# Or if you want the exact version:
git clone --depth=1 --branch v7.0 https://github.com/torvalds/linux.git
```

## Building a Test Kernel

### On NixOS

Add to your flake or use `nix-build`:

```nix
# Example: custom kernel with debug options
boot.kernelPatches = [{
  name = "amdgpu-debug";
  patch = null;
  extraConfig = ''
    CONFIG_DRM_AMDGPU y
    CONFIG_DRM_AMD_DC y
    CONFIG_DEBUG_INFO y
    CONFIG_DEBUG_INFO_DWARF4 y
    CONFIG_GDB_SCRIPTS y
    CONFIG_FTRACE y
    CONFIG_DYNAMIC_FTRACE y
    CONFIG_FUNCTION_TRACER y
  '';
}];
```

### Quick test build (single module)

```bash
# Get kernel source
cd /path/to/linux

# Use your current kernel's build directory
make M=drivers/gpu/drm/amd/amdgpu modules

# Install and load (dangerous — test on non-production system first)
sudo insmod ./drivers/gpu/drm/amd/amdgpu/amdgpu.ko
```

## Decoding the Crash

### What the bytes mean

The crash instruction bytes:

```
Code: ... 55 53 48 8b 47 58 48 89 fb <48> 8b 6e b8
```

The `<48> 8b 6e b8` is the faulting instruction. In x86-64:

- `48` = REX.W prefix (64-bit operand)
- `8b` = MOV r64, r/m64
- `6e` = ModRM byte: rbp, [rsi+disp8]
- `b8` = displacement: -72 (0xb8 = -0x48 in signed byte)

So: `mov rbp, [rsi - 0x48]` where RSI=0 → reads address `0xFFFFFFFFFFFFFFB8` → page fault.

### Disassembling

```bash
# Method 1: GDB on vmlinux
nix-shell -p gdb --run "gdb /path/to/vmlinux"
(gdb) disas isp_genpd_remove_device

# Method 2: objdump
objdump -d -S vmlinux | grep -A30 "isp_genpd_remove_device"

# Method 3: Use the Code bytes directly
echo "0:  55                      push   rbp
1:  53                      push   rbx
2:  48 8b 47 58             mov    rax,QWORD PTR [rdi+0x58]
6:  48 89 fb                mov    rbx,rdi
9:  48 8b 6e b8             mov    rbp,QWORD PTR [rsi-0x48]" | less
```

## Likely Fix for Bug 1 (NULL deref)

The function `isp_genpd_remove_device()` walks child devices and tries to remove
them from their generic power domain. After the OOM corruption, the ISP block's
genpd provider pointer is NULL.

Expected fix pattern:

```c
// In isp_v4_1_1.c, isp_genpd_remove_device()
static void isp_genpd_remove_device(struct device *dev, void *data)
{
    struct generic_pm_domain *genpd;

    // Likely missing this NULL check:
    if (!dev || !dev->pm_domain)
        return;

    genpd = pd_to_genpd(dev->pm_domain);
    if (IS_ERR_OR_NULL(genpd))
        return;

    // ... rest of function
}
```

But this only fixes the symptom (crash). The root cause is why the ISP power
domain is in a broken state after OOM. That requires understanding the ISP init
sequence and what happens when GPU compute processes die uncleanly.

## Debugging Bug 2 (Bind Hang)

The bind hangs with zero log output. To find where:

### Step 1: Add debug prints to amdgpu_pci_probe

```c
// In amdgpu_drv.c, amdgpu_pci_probe()
static int amdgpu_pci_probe(struct pci_dev *pdev,
                            const struct pci_device_id *ent)
{
    dev_info(&pdev->dev, "amdgpu: probe starting\n");  // ADD THIS

    // ... existing code ...

    // Before each major step:
    dev_info(&pdev->dev, "amdgpu: calling device_init\n");
    r = amdgpu_device_init(adev, ...);

    dev_info(&pdev->dev, "amdgpu: calling device_resume\n");
    // etc.
}
```

### Step 2: Trace with ftrace

```bash
# Enable function graph tracer for amdgpu functions
echo function_graph > /sys/kernel/debug/tracing/current_tracer
echo "amdgpu_*" > /sys/kernel/debug/tracing/set_ftrace_filter
echo > /sys/kernel/debug/tracing/trace

# Trigger bind
echo 0000:c5:00.0 > /sys/bus/pci/drivers/amdgpu/bind

# Check where it's stuck (from another terminal)
cat /sys/kernel/debug/tracing/trace
```

### Step 3: Check if SMU is responsive

The bind likely hangs waiting for SMU firmware response:

```bash
# SMU response timeout is usually the culprit
# Check smu_v14_0_0.c for smu_send_msg_with_param() calls
# These use amdgpu_dpm_wait_for_event() which can block forever
```

## Debugging Bug 4 (CPU Frequency)

### Check SMU state

```bash
# After reproducing the OOM:
cat /sys/kernel/debug/amd_pstate/* 2>/dev/null

# SMU firmware logs (if debugfs is mounted)
cat /sys/kernel/debug/amd_smu/* 2>/dev/null

# Check if amd-pstate lost contact with SMU
dmesg | grep -i "smu\|amd_pstate\|cppc"
```

### Trace frequency transitions

```bash
# Enable frequency transition tracing
echo 1 > /sys/kernel/debug/tracing/events/power/cpu_frequency/enable
echo function > /sys/kernel/debug/tracing/current_tracer

# Watch in real-time
cat /sys/kernel/debug/tracing/trace_pipe | grep cpu_frequency
```

### Key files for CPU freq on Strix Halo

| File                                         | Purpose                                                 |
| -------------------------------------------- | ------------------------------------------------------- |
| `drivers/cpufreq/amd-pstate.c`               | amd-pstate governor                                     |
| `drivers/cpufreq/amd-pstate-ut.c`            | amd-pstate unit tests                                   |
| `arch/x86/kernel/acpi/cppc.c`                | ACPI CPPC (Collaborative Processor Performance Control) |
| `drivers/gpu/drm/amd/pm/swsmu/smu_v14_0_0.c` | SMU firmware interface                                  |

On Strix Halo, amd-pstate reads CPPC tables from ACPI, but the actual frequency
control goes through the SMU firmware via SMU messages. If the amdgpu crash
corrupts SMU state, amd-pstate's CPPC reads succeed but SMU ignores frequency
change requests.

## Reproducing the Bug

### Safe reproduction method

```bash
# 1. Start GPU compute workloads
ollama run gemma4:26b  # or any multimodal model that uses GPU
# Also run: a few node/vtsls processes, java (Minecraft)

# 2. Simulate OOM by consuming all memory
# WARNING: This WILL kill processes. Run from SSH, not from the desktop.
stress-ng --vm-bytes $(awk '/MemAvailable/{printf "%dM\n",$2/1024-2048}' /proc/meminfo) --vm 1 --timeout 60s

# 3. Alternatively, use a controlled memory hog:
python3 -c "
import time
chunks = []
try:
    while True:
        chunks.append(b'x' * (1024*1024*1024))  # 1GB at a time
        time.sleep(0.5)
except MemoryError:
    time.sleep(120)  # Hold at OOM
"

# 4. Observe earlyoom killing processes

# 5. Test recovery:
systemctl --user stop niri
echo 0000:c5:00.0 > /sys/bus/pci/drivers/amdgpu/unbind
echo 0000:c5:00.0 > /sys/bus/pci/drivers/amdgpu/bind
systemctl --user start niri
```

### Minimal reproduction (if full OOM is too destructive)

The key ingredient is GPU compute dying while the driver is active. Try:

```bash
# 1. Start a ROCm compute workload
python3 -c "
import torch
x = torch.randn(100000, 100000, device='cuda')
# Hold the allocation
import time; time.sleep(9999)
" &

# 2. Kill it with SIGKILL (simulates OOM kill)
sleep 5
killall -9 python3

# 3. Immediately unbind
echo 0000:c5:00.0 > /sys/bus/pci/drivers/amdgpu/unbind
```

This may not reproduce it (the OOM state corruption is likely needed), but it's
a safer first attempt.

## Submitting a Fix

### Patch format

```
From: Your Name <your@email.com>
Subject: [PATCH] drm/amdgpu/isp: add NULL check in isp_genpd_remove_device

When the GPU driver is unbound after an OOM event that corrupted GPU VM
state, the ISP power domain provider pointer can be NULL. This causes a
NULL pointer dereference in isp_genpd_remove_device when it tries to
remove child devices from their power domains.

Add a NULL check before dereferencing the genpd provider.

Fixes: <commit that introduced isp_v4_1_1>
Signed-off-by: Your Name <your@email.com>
---
 drivers/gpu/drm/amd/amdgpu/isp_v4_1_1.c | 3 +++
 1 file changed, 3 insertions(+)
```

### Where to send

```
To: amd-gfx@lists.freedesktop.org
Cc: alexander.deucher@amd.com, christian.koenig@amd.com,
    Xinhui.Pan@amd.com, david1.zhou@amd.com, airlied@gmail.com,
    daniel@ffwll.ch, dri-devel@lists.freedesktop.org,
    linux-kernel@vger.kernel.org
```

Use `scripts/get_maintainer.pl -f drivers/gpu/drm/amd/amdgpu/isp_v4_1_1.c`
to get the exact maintainer list for the file.

### Git format

```bash
git format-patch -1 --to=amd-gfx@lists.freedesktop.org
git send-email --smtp-server=your.smtp.server 0001-*.patch
```

Or use `git send-email` with your email provider's SMTP.

## Useful Links

- AMD GPU driver source: https://github.com/torvalds/linux/tree/master/drivers/gpu/drm/amd/amdgpu
- SMU v14 interface: https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/pm/swsmu/smu_v14_0_0.c
- amd-pstate driver: https://github.com/torvalds/linux/blob/master/drivers/cpufreq/amd-pstate.c
- Kernel bugzilla: https://bugzilla.kernel.org/
- AMD GPU mailing list archives: https://lists.freedesktop.org/archives/amd-gfx/
- DRM subsystem maintainer handbook: https://drm.pages.freedesktop.org/maintainer-tools/
