# Draft — amd-gfx mailing-list reply — "Accelerator/GPU top" thread

**Send as:** reply-all on the thread root
https://lore.kernel.org/amd-gfx/CADnq5_MTX8CifP25UvE5kdMbCYxgK+A+KGdd-_Ef1m4VYv+WRQ@mail.gmail.com/
(all participants' addresses are on that message; plain text only, mail client strips nothing important below)

**Headers:** `To: amd-gfx@lists.freedesktop.org`
`In-Reply-To: <CADnq5_MTX8CifP25UvE5kdMbCYxgK+A+KGdd-_Ef1m4VYv+WRQ@mail.gmail.com>`
`Subject: Re: Accelerator/GPU top`

---

Subject: Re: Accelerator/GPU top

From: Lars Artmann <lars@larsartmann.de> (adjust to your sending identity)

Hi Alex,

A data point from the consumer side of the fence: Strix Halo (Ryzen AI Max+ 395, Radeon 8060S / gfx1151), NixOS, kernel 7.2.10, running llama.cpp ROCm servers 24/7.

This thread finally pushed me to quantify what Umio described in February: KFD/ROCm workloads are invisible in fdinfo engine accounting, and on an APU they are also invisible to every "who is using the GPU" tool a desktop user has.

Reproduction (all numbers from one run, ~12 s wall):

  $ curl 127.0.0.1:8848/v1/embeddings  # llama.cpp, ROCm/HIP backend, 412 tokens
  # verified real work: response returned (21,849 bytes), and during the
  # request /sys/class/drm/card1/device/gpu_busy_percent read 99-100% for
  # ~7 s, dropping to 0-2% right after the response completed.

  $ grep -h drm-engine /proc/<llama-pid>/fdinfo/* | wc -l
  0          # during the busy window and after

So: a process that demonstrably drove the GPU at 100% for seconds exposes zero engine-ns in its fdinfo. Memory is a different story - the same fdinfo does report drm-memory-gtt correctly (the KFD allocations land on the bound render-node fd), which is why nvtop master can at least show the memory. Engine usage is simply absent, which matches my reading of amdgpu_show_fdinfo() feeding drm-engine-* from amdgpu_ctx_mgr_usage() (DRM contexts only) - happy to be corrected on the mechanism.

Contrast: in the same window the Wayland compositor's fdinfo accumulated drm-engine-gfx normally (12.2 s of engine time across an ~8 s wall window, parallel queues per fd).

Practical consequences on this box:

  - nvtop (master 71094a9) shows the ROCm processes with correct memory
    but gpu_usage null; released 3.3.2 additionally shows ~0 memory on
    APUs (per-process GTT counting is unreleased, d3f91f78 Jul 13).
  - CPU time is useless as a proxy: the same embedding call consumed
    ~50 ms of utime while doing 7 s of GPU work.

Whatever interface comes out of this thread, if per-engine (or at least per-process aggregate) utilization can cover KFD queues, that would close the biggest blind spot left on Linux AMD desktops. I am glad to test candidate patches on this hardware - it runs a fixed ROCm workload daily and I keep fdinfo-based probes around.

(Disclosure: measurements and draft prepared with Crush AI assistance; reviewed and sent by me.)

Lars
