# Rebuilding Qubes OS in NixOS: Technical Analysis & Roadmap

**Date:** January 21, 2026
**Status:** Research Complete - Ready for Implementation Planning

---

## Executive Summary

Rebuilding Qubes OS entirely in NixOS is **technically possible but highly complex**. While NixOS provides excellent virtualization capabilities, recreating Qubes OS would require implementing approximately **15-20 unique, tightly-coupled components** that form the core Qubes security model. The most viable path forward is **hybrid integration** (Qubes OS with NixOS templates) rather than a complete rewrite, at least in the short term.

---

## Part 1: Current State Analysis

### What Exists Today

#### Active Projects (Working Solutions)

1. **evq/qubes-nixos-template** ⭐ 32 stars
   - **Status:** Active and functional
   - **Approach:** NixOS as a TemplateVM for Qubes OS
   - **Features:**
     - RPM package installation
     - qrexec integration
     - Copy/paste, USB proxy support
     - ISO-based installation option
   - **Limitations:** Proxy configuration issues, memory resizing crashes

2. **CertainLach/nixos-qubes** ⭐ 34 stars
   - **Status:** Early development
   - **Approach:** NixOS packages/modules for Qubes OS
   - **Goal:** Merge into upstream NixOS eventually
   - **Challenge:** Maintenance complexity (NixOS/nixpkgs#341215)

#### Historical Attempts

- **4D Qubes Nexus OS / TetraQubes OS:** Discontinued concept
- **Hacker News (2017):** Early discussions on "marrying" NixOS and Qubes
- **Multiple Reddit threads:** Ongoing community interest

---

## Part 2: Architectural Comparison

### Qubes OS Architecture (Target State)

```
┌─────────────────────────────────────────────────────────────┐
│                     Hardware (Bare-Metal)                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Xen Hypervisor (Type-1)                    │
│              Hardware-assisted memory isolation              │
│              IOMMU/VT-d device passthrough                    │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌────────────────────────┐          ┌────────────────────┐
│       dom0             │          │   domU (qubes)     │
│  (Fedora-based)        │          │                   │
│  • Xen toolstack      │          │  • AppVMs          │
│  • GUI management     │◄────────►│  • ServiceVMs      │
│  • Security policies  │  qrexec  │  • DisposableVMs   │
│  • NO networking      │          │  • TemplateVMs     │
│  • Minimal attack surf│          │                   │
└────────────────────────┘          └────────────────────┘
```

### NixOS Architecture (Current State)

```
┌─────────────────────────────────────────────────────────────┐
│                     Hardware (Bare-Metal)                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Linux Kernel (monolithic)                   │
│             KVM/libvirt OR systemd-nspawn OR Docker          │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌────────────────────────┐          ┌────────────────────┐
│     Host (NixOS)       │          │  Containers/VMs    │
│  • Systemd services    │          │  • KVM VMs         │
│  • Nix package manager │          │  • OCI containers  │
│  • Declarative config  │          │  • systemd-nspawn  │
│  • Full networking     │          │                   │
└────────────────────────┘          └────────────────────┘
```

### Key Architectural Differences

| Aspect            | Qubes OS                    | NixOS                             |
| ----------------- | --------------------------- | --------------------------------- |
| **Hypervisor**    | Xen (Type-1, microkernel)   | KVM (Type-2, kernel module)       |
| **Isolation**     | Hardware-level, Xen domains | Kernel-level, namespaces          |
| **dom0**          | Minimal, no networking      | Full-featured, networking enabled |
| **VM Management** | qrexec, custom protocols    | libvirt, systemd services         |
| **GUI**           | Cross-VM virtualization     | Standard X11/Wayland              |
| **Configuration** | Imperative tools            | Declarative Nix expressions       |
| **Package Mgmt**  | Template-based + RPM        | Declarative Nix store             |

---

## Part 3: NixOS Xen Capabilities

### Current Xen Support

**Good News:** NixOS **does support Xen hypervisor** as of NixOS 24.11!

```nix
{
  virtualisation.xen = {
    enable = true;
    bootParams = [ "dom0=pvh" ];
    dom0Resources = {
      memory = 1024;
      maxVCPUs = 2;
    };
  };
}
```

### Critical Limitation: UEFI Boot

🚨 **BLOCKER:** NixOS Xen does **not support UEFI boot**

- GitHub Issue: #127404
- Restriction: `config.boot.loader.grub.efiSupport == false`
- Impact: Modern systems (2015+) default to UEFI

**Workarounds:**

1. Legacy BIOS boot mode (may require BIOS settings change)
2. Wait for upstream fix (active issue, no timeline)
3. Use KVM/libvirt instead (loses Xen-specific features)

### Other Limitations

1. **Imperative VM Management**
   - No declarative domU definitions
   - Must use `xl` commands manually
   - No equivalent to `containers.<name>` syntax

2. **Device Model Issues**
   - QEMU path problems with HVM guests
   - Requires manual overrides

3. **Limited Documentation**
   - Sparse examples
   - Community prefers KVM/libvirt

---

## Part 4: Missing Components (What Needs to Be Built)

### High-Priority Components (Security-Critical)

#### 1. **qrexec Inter-VM Communication Framework**

**Status:** ❌ Does not exist in NixOS
**Complexity:** High (8/10)
**Components:**

- vchan-based communication library (Xen-specific)
- qrexec-daemon (dom0 listener)
- qrexec-agent (VM connector)
- qrexec-client (initiation utility)
- Qubes RPC framework extension

**Why Critical:** Enables secure, authenticated cross-VM command execution
**Technical Challenge:** Requires Xen grant tables, secure channel setup, protocol versioning

---

#### 2. **GUI Virtualization System**

**Status:** ❌ Does not exist in NixOS
**Complexity:** Very High (9/10)
**Components:**

- qubes-gui (VM-side window composer)
- qubes-guid (dom0 window manager)
- Custom X drivers: `dummyqsb_drv`, `qubes_drv`
- shmoverride.so library (Xorg intercepts)
- Window content transmission via Xen grant tables
- Zero-copy rendering pipeline

**Why Critical:** Provides unified desktop experience across VMs
**Technical Challenge:** Requires deep X11/Wayland integration, memory mapping, event synchronization

---

#### 3. **Security Policy Management**

**Status:** ❌ Does not exist in NixOS
**Complexity:** Medium (6/10)
**Components:**

- Policy database (`/etc/qubes/policy.d/`)
- Rule evaluation engine with hierarchical override
- VM specification (tags, types, targets)
- Service argument handling (`+argument` syntax)
- Dynamic policy loading

**Why Critical:** Enforces security boundaries between VMs
**Technical Challenge:** Policy language design, performance optimization, user interface

---

#### 4. **Agent System**

**Status:** ❌ Does not exist in NixOS
**Complexity:** Medium-High (7/10)
**Components:**

- qubes-core-agent-linux (base integration)
- Service-specific agents (networking, updates, file operations)
- RPC service implementations (`/etc/qubes-rpc/`)
- Automatic service discovery

**Why Critical:** Provides VM integration with Qubes services
**Technical Challenge:** Agent architecture, cross-distribution compatibility, security hardening

---

### Medium-Priority Components

#### 5. **Template System**

**Status:** ⚠️ Partially possible via Nix modules
**Complexity:** Medium (5/10)
**Required Features:**

- Read-only root filesystem sharing
- Template-based AppVM creation
- DisposableVM templates
- Template updates without affecting derived VMs

**NixOS Advantage:** Declarative configuration makes this easier than RPM-based templates

---

#### 6. **Disposable VM Management**

**Status:** ⚠️ Partially possible via microvm.nix
**Complexity:** Medium (5/10)
**Required Features:**

- Stateless VM creation
- Unnamed disposables (auto-shutdown)
- Named disposables (manual shutdown)
- Ephemeral storage handling

**NixOS Advantage:** microvm.nix provides similar lightweight VM capabilities

---

#### 7. **ServiceVM Framework**

**Status:** ⚠️ Partially possible via containers/VMs
**Complexity:** Low-Medium (4/10)
**Required Features:**

- sys-net, sys-usb, sys-firewall templates
- Named disposable service VMs
- Device assignment (PCI passthrough)
- Service discovery

**NixOS Advantage:** Already has networking and container capabilities

---

### Low-Priority Components

#### 8. **USB Device Sandboxing**

**Status:** ✅ Possible with libvirt + IOMMU
**Complexity:** Medium (5/10)
**Required Features:**

- USB controller passthrough
- Device hotplug handling
- ServiceVM-based isolation

**NixOS Advantage:** libvirt already supports USB passthrough

---

#### 9. **Networking Proxy System**

**Status:** ⚠️ Partially possible via iptables/nftables
**Complexity:** Medium (5/10)
**Required Features:**

- VM-specific firewall rules
- Network policy enforcement
- Whonix integration

**NixOS Advantage:** Declarative firewall configuration already exists

---

#### 10. **GUI Security Markers**

**Status:** ⚠️ Partially possible with compositor
**Complexity:** Low-Medium (3/10)
**Required Features:**

- Colored window borders by VM
- VM name prefix in window titles
- Spoofing prevention

**NixOS Advantage:** Compositor plugins possible with GNOME/KDE

---

## Part 5: Technical Feasibility Assessment

### Feasibility Matrix

| Component          | NixOS Capability | Gap      | Complexity  | Timeline |
| ------------------ | ---------------- | -------- | ----------- | -------- |
| Xen Hypervisor     | ✅ Supported     | None     | Low         | N/A      |
| UEFI Boot Support  | ❌ Blocked       | Critical | High        | Unknown  |
| qrexec Framework   | ❌ None          | Complete | High        | 6-12mo   |
| GUI Virtualization | ❌ None          | Complete | Very High   | 12-24mo  |
| Security Policy    | ❌ None          | Complete | Medium      | 4-8mo    |
| Agent System       | ❌ None          | Complete | Medium-High | 6-10mo   |
| Template System    | ⚠️ Partial        | Medium   | Medium      | 2-4mo    |
| DisposableVMs      | ⚠️ Partial        | Medium   | Medium      | 2-4mo    |
| ServiceVMs         | ⚠️ Partial        | Low      | Low-Medium  | 1-3mo    |
| USB Sandboxing     | ✅ Possible      | Minor    | Medium      | 1-2mo    |
| Network Proxy      | ⚠️ Partial        | Medium   | Medium      | 2-4mo    |
| GUI Markers        | ⚠️ Partial        | Low      | Low         | 1-2mo    |

### Overall Feasibility: **Medium** (with caveats)

**Reasons for Feasibility:**

- NixOS supports Xen hypervisor (non-UEFI)
- NixOS has strong declarative VM/container management
- Microvm.nix provides lightweight VM foundation
- Nix packages can replace RPM templates
- Existing projects demonstrate integration is possible

**Reasons Against Feasibility:**

- UEFI boot blocker (critical for modern systems)
- GUI virtualization is extremely complex (requires deep X11/Wayland knowledge)
- qrexec framework must be ported from Xen to work with NixOS ecosystem
- Tight coupling of all components (10+ interdependent systems)
- No clear benefit over existing Qubes OS integration

---

## Part 6: Implementation Roadmaps

### Roadmap A: Complete Rebuild (High Risk, High Reward)

**Goal:** Recreate entire Qubes OS architecture in pure NixOS
**Timeline:** 18-36 months
**Team Size:** 5-10 developers with Xen/X11 expertise

#### Phase 1: Foundation (Months 1-6)

- **Fix UEFI boot support** for Xen on NixOS (BLOCKER)
- **Implement declarative domU management** in NixOS
- **Port qrexec framework** to NixOS (vchan + RPC)
- **Create agent system** skeleton

#### Phase 2: Core Components (Months 6-12)

- **Build security policy engine**
- **Implement template system** with Nix modules
- **Create disposable VM management**
- **Port GUI agents** from Qubes OS

#### Phase 3: GUI Virtualization (Months 12-24)

- **Implement qubes-gui** (VM-side compositor)
- **Implement qubes-guid** (dom0 window manager)
- **Port custom X drivers** (dummyqsb_drv, qubes_drv)
- **Create shmoverride.so** library
- **Integrate with NixOS desktop** (GNOME/KDE)

#### Phase 4: Integration (Months 24-30)

- **Port ServiceVM framework**
- **Implement USB sandboxing**
- **Create networking proxy system**
- **Add GUI security markers**

#### Phase 5: Polish (Months 30-36)

- **Performance optimization**
- **Security audit**
- **Documentation**
- **Testing and validation**

**Estimated Effort:** 15,000-25,000 hours
**Risk:** High (many unknowns, tight coupling)
**Reward:** Complete control, declarative everything, pure NixOS

---

### Roadmap B: Hybrid Integration (Recommended, Low Risk, High Practicality)

**Goal:** Use Qubes OS with NixOS templates (existing approach + enhancements)
**Timeline:** 3-6 months
**Team Size:** 2-3 developers

#### Phase 1: Enhance Existing Template (Months 1-2)

- **Fix proxy configuration** issues in evq/qubes-nixos-template
- **Improve memory handling** (resolve Firefox crashes)
- **Add more NixOS templates** (different configurations)
- **Optimize package management** (better Nix integration)

#### Phase 2: NixOS dom0 (Months 2-4)

- **Replace Fedora dom0** with NixOS
- **Implement qrexec daemon** in NixOS
- **Create NixOS qubes-core-agent**
- **Port security policies** to Nix expressions

#### Phase 3: Enhanced Workflow (Months 4-6)

- **Create declarative qube definitions**
  ```nix
  qubes = {
    work = {
      template = "nixos-work";
      type = "AppVM";
    };
    banking = {
      template = "nixos-minimal";
      type = "AppVM";
      services = [ "sys-firewall" ];
    };
  };
  ```
- **Integrate with NixOS configuration**
- **Add testing and CI/CD**
- **Document thoroughly**

**Estimated Effort:** 3,000-5,000 hours
**Risk:** Low (builds on working foundation)
**Reward:** Declarative configuration, NixOS templates, minimal rebuild

---

### Roadmap C: Alternative Architecture (Medium Risk, Medium Reward)

**Goal:** Recreate Qubes OS security model using NixOS native technologies
**Timeline:** 12-18 months
**Team Size:** 3-5 developers

#### Phase 1: Use KVM/libvirt Instead of Xen

- **Leverage existing NixOS KVM support**
- **Implement similar qube isolation** via libvirt
- **No UEFI boot issues**

#### Phase 2: Replace qrexec with Native IPC

- **Use systemd socket activation**
- **Implement secure IPC** over UNIX domain sockets + namespaces
- **Create policy engine** using Nix expressions

#### Phase 3: Replace GUI Virtualization

- **Use Wayland compositor protocols**
- **Implement window forwarding** via Pipewire + portals
- **Add security markers** via compositor plugins

#### Phase 4: Implement Qube Management

- **Create NixOS modules** for qube definitions
- **Use microvm.nix** for lightweight qubes
- **Implement disposable qubes** via temporary VMs

**Estimated Effort:** 8,000-12,000 hours
**Risk:** Medium (proven technologies, but architecture change)
**Reward:** UEFI support, native NixOS integration, avoids Xen complexity

---

## Part 7: Critical Path Analysis

### Showstopper: UEFI Boot Support

**Problem:** NixOS Xen does not support UEFI boot
**Impact:** Blocks development on modern hardware (2015+)
**Solutions:**

1. **Wait for upstream fix** (unknown timeline)
2. **Implement fix yourself** (requires bootloader expertise)
3. **Use legacy BIOS mode** (may not work on all systems)
4. **Switch to KVM/libvirt** (loses Xen-specific features)

**Recommended Action:** Start with legacy BIOS development, contribute to upstream UEFI fix

---

### Technical Challenges

#### Challenge 1: GUI Virtualization Complexity

**Problem:** Requires deep X11/Wayland integration
**Impact:** 12-24 month development timeline
**Solutions:**

- Start with simpler approach (separate X servers per VM)
- Gradually implement zero-copy rendering
- Consider Wayland alternative (more modern, better security)

#### Challenge 2: qrexec Dependency on Xen

**Problem:** qrexec uses Xen-specific vchan library
**Impact:** Cannot use with KVM/libvirt
**Solutions:**

- Port vchan to work with KVM (very difficult)
- Replace with native IPC (requires redesign)
- Stick with Xen hypervisor (UEFI blocker)

#### Challenge 3: Tight Component Coupling

**Problem:** All components depend on each other
**Impact:** Cannot build incrementally, requires full system
**Solutions:**

- Build simulation framework first
- Mock dependent components during development
- Parallelize development with careful interface definition

---

## Part 8: Resource Requirements

### Team Composition (Roadmap A - Complete Rebuild)

- **Xen Hypervisor Expert:** 1-2 developers (hypervisor, grant tables, vchan)
- **X11/Wayland Expert:** 2 developers (GUI virtualization, compositor)
- **NixOS Expert:** 1-2 developers (Nix modules, declarative config)
- **Security Expert:** 1 developer (policy engine, security audit)
- **Testing/QA:** 1 developer (validation, CI/CD)

**Total:** 5-10 developers

### Infrastructure Requirements

- **Build Servers:** Multiple NixOS machines for compilation
- **Test Hardware:**
  - Legacy BIOS system (for Xen development)
  - UEFI system (for final validation)
  - Varied hardware (GPU, USB devices)
- **CI/CD:** Automated testing on every commit
- **Documentation:** Dedicated technical writer

### Estimated Budget (18-36 months)

- **Developer Salaries:** $1.5M - $3M (5-10 developers × $150k × 2-3 years)
- **Infrastructure:** $50k - $100k
- **Testing Hardware:** $20k - $50k
- **Contingency:** $300k - $500k

**Total:** $1.87M - $3.65M

---

## Part 9: Risk Assessment

### High-Risk Items

1. **UEFI Boot Support** 🔴
   - Risk: Blocker for modern hardware
   - Mitigation: Contribute to upstream, use legacy BIOS during dev
   - Probability: 30% success within 18 months

2. **GUI Virtualization** 🔴
   - Risk: Extremely complex, requires deep expertise
   - Mitigation: Start with simpler approach, hire X11 expert
   - Probability: 50% success within 24 months

3. **qrexec Porting** 🟡
   - Risk: Xen-specific, difficult to test
   - Mitigation: Build simulation framework
   - Probability: 70% success within 12 months

4. **Team Coordination** 🟡
   - Risk: 5-10 developers managing complex interdependencies
   - Mitigation: Strict interface contracts, continuous integration
   - Probability: 60% successful team cohesion

### Medium-Risk Items

5. **Performance Degradation** 🟡
   - Risk: NixOS overhead vs Fedora
   - Mitigation: Benchmark early, optimize hot paths
   - Probability: 30% acceptable performance

6. **Maintenance Burden** 🟡
   - Risk: Keeping synced with upstream Qubes OS and NixOS
   - Mitigation: Automate updates, reduce coupling
   - Probability: 50% sustainable maintenance

### Low-Risk Items

7. **Documentation** 🟢
   - Risk: Incomplete docs
   - Mitigation: Technical writer, continuous documentation
   - Probability: 90% complete docs

8. **Testing** 🟢
   - Risk: Inadequate test coverage
   - Mitigation: CI/CD, automated testing
   - Probability: 80% comprehensive tests

---

## Part 10: Recommendations

### For Maximum Security & Control

**Recommended Approach:** **Roadmap B (Hybrid Integration)**

**Why:**

- **Leverages existing Qubes OS security model** (proven, battle-tested)
- **Adds NixOS declarative configuration** (huge usability improvement)
- **Minimal rebuild** (only templates and dom0)
- **Lower risk** (builds on working foundation)
- **Faster time-to-value** (3-6 months)

**Next Steps:**

1. **Fork evq/qubes-nixos-template**
2. **Fix known issues** (proxy, memory)
3. **Add NixOS dom0** (replace Fedora)
4. **Create declarative qube definitions**
5. **Release as "NixOS-powered Qubes OS"**

---

### For Pure NixOS Architecture

**Recommended Approach:** **Roadmap C (Alternative Architecture)**

**Why:**

- **Avoids UEFI boot blocker**
- **Uses native NixOS technologies** (KVM/libvirt)
- **Still provides strong isolation** (namespaces, containers, VMs)
- **Better long-term maintainability**
- **Faster than complete rebuild** (12-18 months)

**Next Steps:**

1. **Define qube management layer** in NixOS
2. **Replace qrexec with systemd socket IPC**
3. **Use Wayland compositor** for GUI forwarding
4. **Leverage microvm.nix** for lightweight qubes
5. **Build policy engine** with Nix expressions

**Why NOT Roadmap A:**

- **UEFI boot blocker** is critical for modern hardware
- **GUI virtualization** is prohibitively complex (12-24 months)
- **Tight coupling** makes incremental development impossible
- **No clear advantage** over Roadmap B or C

---

## Part 11: Quick Start Guide (If You Want to Proceed)

### Option 1: Enhance Hybrid Integration (Recommended)

```bash
# Clone existing template
git clone https://github.com/evq/qubes-nixos-template.git
cd qubes-nixos-template

# Build NixOS RPM
make rpm

# Install in Qubes OS TemplateVM
sudo rpm -ivh qubes-nixos-template-*.rpm

# Start template
sudo qubes-dom0-update -t fedora-38-x64
```

### Option 2: Experiment with NixOS Xen (Requires Legacy BIOS)

```nix
# configuration.nix
{
  virtualisation.xen = {
    enable = true;
    bootParams = [ "dom0=pvh" ];
    dom0Resources = {
      memory = 1024;
      maxVCPUs = 2;
    };
  };

  # Note: Must use GRUB with efiSupport = false
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    efiSupport = false;  # CRITICAL: UEFI not supported
  };
}
```

```bash
# Rebuild
nixos-rebuild switch

# Check Xen status
xl list

# Create test VM (imperative)
xl create -c /etc/xen/test-vm.cfg
```

---

## Part 12: Conclusion

### Summary Answer to "What Would It Take?"

**Complete Rebuild (Roadmap A):**

- **5-10 developers** with Xen/X11 expertise
- **18-36 months** of development
- **$1.87M - $3.65M** budget
- **15-20 unique components** to build from scratch
- **High risk** (UEFI blocker, GUI complexity)

**Hybrid Integration (Roadmap B - Recommended):**

- **2-3 developers** with NixOS expertise
- **3-6 months** of development
- **$300k - $750k** budget
- **Leverages existing Qubes OS** (proven security)
- **Low risk** (builds on working foundation)

**Alternative Architecture (Roadmap C):**

- **3-5 developers** with Linux/VM expertise
- **12-18 months** of development
- **$750k - $1.5M** budget
- **Avoids UEFI blocker**
- **Medium risk** (architecture change)

### Final Recommendation

**Start with Roadmap B (Hybrid Integration):**

1. Enhance existing `evq/qubes-nixos-template`
2. Fix proxy and memory issues
3. Replace Fedora dom0 with NixOS
4. Create declarative qube definitions
5. Release as "NixOS-powered Qubes OS"

**Long-Term Vision:**

- Learn from hybrid integration
- Evaluate if Roadmap A or C makes sense
- Potentially migrate to pure NixOS architecture over time

### Has Anyone Built This Already?

**Answer:** **Partially, yes.**

- **evq/qubes-nixos-template**: Working NixOS templates for Qubes OS
- **CertainLach/nixos-qubes**: Early NixOS modules for Qubes OS
- **No complete rebuild**: Nobody has fully recreated Qubes OS in pure NixOS
- **No UEFI support**: All attempts blocked by NixOS Xen limitations

**Why Not?**

- **Complexity:** 15-20 interdependent components
- **UEFI blocker:** Critical limitation for modern systems
- **No clear benefit:** Hybrid integration provides most advantages
- **Maintenance burden:** Keeping synced with both projects

---

## Appendix A: References & Resources

### Official Documentation

- [Qubes OS Architecture](https://doc.qubes-os.org/en/latest/developer/system/architecture.html)
- [Qubes GUI System](https://doc.qubes-os.org/en/latest/developer/system/gui.html)
- [Qubes qrexec RPC](https://doc.qubes-os.org/en/latest/developer/services/qrexec.html)
- [NixOS Xen Wiki](https://wiki.nixos.org/wiki/Xen_Project_Hypervisor)
- [NixOS Virtualization](https://nixos.wiki/wiki/Virtualization)

### Existing Projects

- [evq/qubes-nixos-template](https://github.com/evq/qubes-nixos-template)
- [CertainLach/nixos-qubes](https://github.com/CertainLach/nixos-qubes)
- [astro/microvm.nix](https://github.com/astro/microvm.nix)

### Key Issues

- [NixOS Xen UEFI Boot](https://github.com/NixOS/nixpkgs/issues/127404)
- [NixOS qubes Integration](https://github.com/NixOS/nixpkgs/issues/341215)

### Community Discussions

- [Qubes OS Forum - NixOS Templates](https://forum.qubes-os.org/t/starting-work-on-nixos-template/25591)
- [Hacker News - Marrying NixOS and Qubes](https://news.ycombinator.com/item?id=15734704)

---

**End of Analysis**

_This document provides a comprehensive technical assessment of rebuilding Qubes OS in NixOS. All research was conducted in January 2026 and reflects the current state of both projects._
