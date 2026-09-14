# GitHub Issues Batch Recommendations (Issues #132, #131, #130, #125, #122)

**Generated:** 2025-01-13
**Repository:** LarsArtmann/Setup-Mac

---

## 🚨 CRITICAL: Issue #132 - Deploy & Validate EVO-X2 NixOS Configuration

### Summary

Deploy production-ready NixOS configuration on GMKtec EVO-X2 (AMD Ryzen AI Max+ 395) to complete cross-platform development environment.

### Current Status

- ✅ Configuration complete in `dotfiles/nixos/configuration.nix`
- ✅ Flake integration with `evo-x2` target
- ✅ Hardware optimization configured (CPU, GPU, storage, memory)
- ❌ No real hardware testing
- ❌ No production validation
- ❌ No performance verification

### Recommendation: **EXECUTE IMMEDIATELY**

**Priority:** 🔴 **CRITICAL** (Blocker for all NixOS work)
**Verdict:** This is the **highest priority issue** - must be completed before any other NixOS work.

---

### Action Plan

#### Week 1: Preparation & Deployment

1. **Hardware Verification** (2 hours)
   - Confirm EVO-X2 availability
   - Prepare bootable USB with NixOS
   - Backup existing data

2. **Configuration Validation** (2 hours)

   ```bash
   # Pre-deployment checks
   nix flake check --target evo-x2
   nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel
   ```

3. **Base Installation** (4-6 hours)
   - Install NixOS from USB
   - Partition storage per `hardware-configuration.nix`
   - Configure network
   - Verify system boots

4. **Setup-Mac Deployment** (2 hours)
   ```bash
   # Clone and apply configuration
   git clone https://github.com/LarsArtmann/Setup-Mac.git
   sudo nixos-rebuild switch --flake .#evo-x2
   ```

#### Week 2: Validation & Testing

5. **Hardware Verification** (3-4 hours)

   ```bash
   # CPU validation
   lscpu | grep "Model name"
   cat /proc/cpuinfo | grep "cpu MHz"

   # GPU validation
   lspci | grep VGA
   vulkaninfo --summary

   # Performance validation
   just benchmark-all
   ```

6. **Development Environment Testing** (4-6 hours)
   - Test all development tools
   - Run `just go-dev`
   - Validate AI/ML stack
   - Test TypeScript/Bun tooling

7. **Production Readiness** (4-6 hours)
   - System hardening
   - Monitoring setup (Netdata, ntopng)
   - Backup configuration
   - Documentation updates

---

### Blockers & Solutions

| Blocker                 | Solution                               | Timeline |
| ----------------------- | -------------------------------------- | -------- |
| Hardware not received   | Use QEMU virtualization for testing    | 1 week   |
| Driver issues           | Research AMD Ryzen GPU drivers         | 2 weeks  |
| Configuration conflicts | Incremental deployment, rollback ready | 1 week   |

---

### Success Metrics

- [ ] NixOS boots reliably on EVO-X2
- [ ] Configuration deploys without errors
- [ ] All hardware components work correctly
- [ ] Development tools function properly
- [ ] `just health` passes
- [ ] Performance baselines established via `just benchmark-all`

---

### Dependencies

**Must Complete Before:**

- Issue #122 (Fix Nix Testing Pipeline) - for safe testing
- Issue #131 (Performance Baselines) - for validation metrics

**Enables:**

- Issue #133 (Advanced Network Configuration) - NixOS networking
- Issue #134 (Isolated Program Modules) - ZFS features
- Issue #130 (RISC-V Support) - cross-platform testing

---

### Estimated Effort

**Total:** 20-30 hours (2-3 weeks)

- Preparation: 4 hours
- Deployment: 6 hours
- Testing: 10 hours
- Documentation: 4 hours
- Contingency: 6 hours

---

### Just Commands for Deployment

```bash
# Pre-deployment validation
just test              # Test configuration (if Issue #122 fixed)
just benchmark-all     # Establish macOS baseline for comparison

# Deployment
sudo nixos-rebuild switch --flake .#evo-x2
sudo nixos-rebuild test --flake .#evo-x2
sudo nixos-rebuild build --flake .#evo-x2

# Post-deployment validation
just health            # System health check
just benchmark-all     # Establish NixOS baseline
just go-dev           # Test development environment
just network-status    # Verify networking
```

---

### Key Risks

1. **Hardware Issues:** GPU or CPU drivers may not work correctly
   - **Mitigation:** Research AMD Ryzen AI Max+ 395 support, have alternative configurations ready

2. **Configuration Conflicts:** Unexpected build errors or dependencies
   - **Mitigation:** Incremental deployment, keep rollback available (`sudo nixos-rebuild switch --rollback`)

3. **Performance Issues:** System slower than expected
   - **Mitigation:** Performance baseline from Issue #131, optimization opportunities identified

---

## 📊 COMPREHENSIVE: Issue #131 - Establish Performance Baselines & Regression Detection

### Summary

Complete comprehensive performance baseline establishment for cross-platform development environment to enable optimization tracking and regression detection.

### Current Status

- ✅ Shell startup benchmarking (`just benchmark-shells`)
- ✅ Performance monitoring tools (ActivityWatch, Netdata)
- ✅ System health checks (`just health`)
- ❌ No comprehensive baseline measurements
- ❌ No automated regression detection
- ❌ No application-level performance tracking

### Recommendation: **PROCEED AFTER #132**

**Priority:** 🔴 **HIGH** (depends on Issue #132)
**Verdict:** Essential for measuring success of other improvements. Create baselines after EVO-X2 deployment.

---

### Action Plan

#### Phase 1: Core Baselines (Week 1 - High Priority)

1. **Shell Performance Baseline** (2 hours)

   ```bash
   # Measure shell startup times
   just benchmark-shells

   # Document results in docs/performance/baseline-shell.md
   mkdir -p docs/performance
   just benchmark-shells > docs/performance/baseline-shell.md
   ```

2. **System Performance Baseline** (2 hours)

   ```bash
   # CPU, memory, disk, network benchmarks
   hyperfine 'git status'
   dd if=/dev/zero of=/tmp/testfile bs=1M count=1000
   iperf3 -c server

   # Document in docs/performance/baseline-system.md
   ```

3. **Development Tool Performance** (2 hours)

   ```bash
   # Measure build times
   time go build ./test-project
   time nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel

   # Document in docs/performance/baseline-tools.md
   ```

4. **Create Performance Data Structure** (1 hour)
   ```json
   // docs/performance/baseline.json
   {
     "baseline": {
       "shell": { "zsh_startup_ms": 850, "fish_startup_ms": 620 },
       "system": { "cpu_single_core": 2800, "disk_read_mb_s": 3200 },
       "tools": { "go_build_s": 2.3, "nix_eval_s": 4.1 }
     },
     "thresholds": {
       "shell_regression_percent": 15,
       "system_regression_percent": 10,
       "tools_regression_percent": 20
     },
     "date": "2025-01-13",
     "platform": "Lars-MacBook-Air"
   }
   ```

#### Phase 2: Automated Regression Detection (Week 2 - High Priority)

5. **Implement Just Commands** (3 hours)

   ```bash
   # Add to justfile
   baseline-establish:
     @echo "📊 Establishing performance baseline..."
     @just benchmark-shells > docs/performance/baseline-shell-$(date +%Y%m%d).md

   baseline-check:
     @echo "🔍 Checking performance against baseline..."
     @# Compare current with baseline.json, alert if thresholds exceeded

   perf-track:
     @echo "📈 Daily performance tracking..."
     @# Run benchmarks, append to history

   perf-report:
     @echo "📊 Performance report generation..."
     @# Generate report from historical data
   ```

6. **Add Performance Alerts** (2 hours)
   - Alert if shell startup exceeds baseline by 15%
   - Alert if system performance degrades by 10%
   - Alert if tool performance degrades by 20%

#### Phase 3: Cross-Platform Comparison (Week 3 - Medium Priority)

7. **macOS vs NixOS Comparison** (4 hours)
   - Run identical benchmarks on both platforms
   - Document platform-specific differences
   - Create performance comparison matrix
   - Identify optimization opportunities

---

### Success Metrics

- [ ] All performance areas measured and documented
- [ ] Baseline JSON structure created
- [ ] Automated regression detection implemented
- [ ] Performance alerts working
- [ ] Cross-platform comparison complete

---

### Estimated Effort

**Total:** 12-16 hours (2-3 weeks)

- Phase 1 (Baselines): 6 hours
- Phase 2 (Automation): 5 hours
- Phase 3 (Cross-Platform): 5 hours

---

### Dependencies

**Requires:**

- Issue #132 (EVO-X2 Deployment) - for NixOS baseline
- Issue #122 (Fix Testing) - for automated baseline establishment

**Enables:**

- Issue #134 (Program Modules) - measure performance impact
- Issue #125 (Dynamic Library Management) - performance validation
- Issue #104 (Wrapper Optimization) - performance measurement

---

## 🔵 MEDIUM: Issue #130 - Add Comprehensive RISC-V Support to NixOS Configurations

### Summary

Add RISC-V architecture support to NixOS configurations for deployment on RISC-V hardware and virtualization environments.

### Current Status

- ✅ flake.nix supports multiple systems (aarch64-darwin, x86_64-linux)
- ❌ No RISC-V architecture support
- ❌ No RISC-V specific configurations
- ❌ No RISC-V package compatibility validation

### Recommendation: **DEFER - LOW PRIORITY**

**Priority:** 🟢 **LOW** (research-heavy, limited hardware)
**Verdict:** Interesting long-term enhancement, but **not urgent**. RISC-V hardware is emerging, Nixpkgs support is maturing but not yet critical.

---

### Rationale for Deferral

1. **Hardware Availability:** RISC-V development boards are expensive and hard to acquire
2. **Testing Environment:** Need QEMU RISC-V virtualization, adds complexity
3. **Package Coverage:** Many packages not yet available for RISC-V
4. **Use Case:** Unclear if RISC-V will be used in production
5. **Higher Priorities:** Issues #132, #122, #133 are more impactful

---

### If Implementing (Future)

#### Research Phase (Week 1)

1. **Document Current NixOS RISC-V Support** (4 hours)
   - Check NixOS wiki: https://nixos.wiki/wiki/RISC-V
   - Review Nixpkgs RISC-V support
   - Identify package availability

2. **Virtualization Testing** (4 hours)
   - Test QEMU RISC-V emulation
   - Validate basic system boot
   - Test core packages (git, curl, bash)

#### Implementation Phase (Week 2-3)

3. **Add RISC-V Target to Flake** (2 hours)

   ```nix
   systems = ["aarch64-darwin" "x86_64-linux" "riscv64-linux"];

   flake.nixosConfigurations."riscv-test" = lib.nixosSystem {
     system = "riscv64-linux";
     # ... configuration
   };
   ```

4. **Create RISC-V Specific Configurations** (6 hours)

   ```nix
   # platforms/riscv/system/configuration.nix
   {
     # RISC-V specific kernel parameters
     boot.kernelParams = ["riscv" "noefi"];

     # RISC-V specific packages
     environment.systemPackages = with pkgs; [
       # RISC-V development tools
     ];

     # Architecture detection
     system.stateVersion = config.hardware.isRiscv ? "24.11" : "24.05";
   }
   ```

5. **Document RISC-V Deployment** (4 hours)
   - Installation guide for RISC-V
   - QEMU emulation setup
   - Hardware-specific notes

---

### Success Criteria

- [ ] Flake can build for riscv64-linux target
- [ ] System boots on RISC-V hardware/emulator
- [ ] Essential packages available (git, curl, editors)
- [ ] Documentation covers RISC-V deployment

---

### Estimated Effort

**Total:** 20-24 hours (3-4 weeks)

- Research: 8 hours
- Implementation: 12 hours
- Testing: 4 hours

---

### When to Revisit

- **Trigger 1:** RISC-V hardware becomes available/affordable
- **Trigger 2:** NixOS declares RISC-V as stable release
- **Trigger 3:** Production use case for RISC-V emerges
- **Trigger 4:** Community demand increases

---

## 🟡 MEDIUM: Issue #125 - Enhance Dynamic Library Management System

### Summary

Enhance existing wrapper system with automatic library dependency detection, enhanced macOS-specific dynamic library management, and migration guides from Homebrew.

### Current Status

- ✅ Advanced wrapper system exists (`dotfiles/nix/wrappers/`)
- ✅ Template-based wrapper generation
- ✅ GUI and CLI application support
- ✅ Configuration management integration
- ❌ No automatic library dependency detection
- ❌ No macOS-specific dylib optimization
- ❌ No Homebrew migration guides

### Recommendation: **PROCEED IN PHASES**

**Priority:** 🟡 **MEDIUM** (quality-of-life improvement)
**Verdict:** Useful enhancement that improves developer experience. Implement incrementally, starting with highest-impact features.

---

### Action Plan

#### Phase 1: Enhanced Wrappers (Week 1 - High Impact)

1. **Add Automatic Library Detection** (4 hours)

   ```bash
   # Create wrapper helper function
   # Add to dotfiles/nix/wrappers/lib/detect-deps.sh

   # Example usage
   detect_dependencies /path/to/binary

   # Output:
   # /usr/lib/libSystem.B.dylib
   # /opt/homebrew/lib/libssl.dylib
   ```

2. **Create Enhanced Wrapper Template** (3 hours)

   ```nix
   # dotfiles/nix/wrappers/templates/dynamic-library.nix
   { pkgs, appName, binaryPath, libraries ? [] }:

   pkgs.writeShellScriptBin "${appName}" ''
     #!/usr/bin/env bash
     export DYLD_LIBRARY_PATH="${lib.concatStringsSep ":" libraries}"
     exec ${binaryPath} "$@"
   ''
   ```

3. **Debug Mode** (1 hour)
   ```bash
   # Add WRAPPER_DEBUG=1 support
   # Provide detailed library loading information
   # Help troubleshoot dylib issues
   ```

#### Phase 2: Documentation & Migration (Week 2 - Medium Impact)

4. **Homebrew Migration Guide** (3 hours)

   ```markdown
   # docs/migration/homebrew-to-nix.md

   ## Common Homebrew Packages → Nix Equivalents

   | Homebrew             | Nix     | Notes           |
   | -------------------- | ------- | --------------- |
   | brew install python3 | python3 | Version matches |
   | brew install node    | nodejs  | Use nodejs      |
   ```

5. **Troubleshooting Guide** (2 hours)
   ```markdown
   # docs/troubleshooting/dynamic-libraries.md

   ## Common Issues

   ### dylib not found

   ### Wrong architecture error

   ### System Integrity Protection conflicts
   ```

#### Phase 3: Testing & Validation (Week 3 - Quality Assurance)

6. **Create Test Suite** (4 hours)
   - Test wrapper functionality
   - Validate library path resolution
   - Performance testing

7. **Real-World Testing** (3 hours)
   - Test with VS Code, Docker, JetBrains IDEs
   - Validate with database clients (PostgreSQL, MySQL)
   - Test creative applications (graphics, media)

---

### Success Metrics

- [ ] Automatic dependency detection works
- [ ] Enhanced wrapper template created
- [ ] Debug mode provides useful information
- [ ] Migration guide completed
- [ ] Troubleshooting guide created
- [ ] Tests pass for common applications

---

### Estimated Effort

**Total:** 20-24 hours (3-4 weeks)

- Phase 1 (Enhancements): 8 hours
- Phase 2 (Documentation): 5 hours
- Phase 3 (Testing): 7 hours

---

### Dependencies

**Related to:**

- Issue #134 (Program Modules) - could integrate dynamic library management
- Issue #97 (Wrapper Library) - performance optimization
- Issue #105 (Wrapper Documentation) - comprehensive docs

---

## 🚨 CRITICAL: Issue #122 - Fix Nix Testing Pipeline

### Summary

Fix `just test` command which currently requires sudo privileges, blocking automated testing workflows.

### Current Status

- ❌ `just test` fails - needs sudo for `darwin-rebuild check`
- ❌ No non-privileged validation method
- ❌ Cannot safely validate configuration changes
- ❌ Development blocked - manual verification required

### Recommendation: **FIX IMMEDIATELY**

**Priority:** 🔴 **CRITICAL** (Blocker for all Nix work)
**Verdict:** This is a **showstopper** - must be fixed before any Nix configuration work to ensure safe development practices.

---

### Root Cause

```bash
# Current justfile test command
test:
  darwin-rebuild check --flake .
  # ⚠️ Requires sudo - fails in automated workflows
```

**Problem:**

- `darwin-rebuild check` requires root privileges
- Security policy: Cannot use sudo in automated workflows
- No alternative validation method available

---

### Recommended Solution: Use Build-Only Testing (Option 3)

**Why Option 3 (Build-Only):**

- ✅ No sudo required
- ✅ Tests actual build process
- ✅ More comprehensive than `nix flake check`
- ✅ Validates package availability
- ✅ Catches syntax errors
- ✅ Fast (no system changes)

**Alternative Options Considered:**

- Option 1 (`nix flake check`): Less comprehensive
- Option 2 (Two-stage): More complex, still needs sudo for final check

---

### Implementation

#### Step 1: Update Justfile (5 minutes)

```makefile
# Replace existing test command
test:
  @echo "🧪 Testing Nix configuration..."
  @echo "📦 Building system (dry-run)..."
  nix build .#darwinConfigurations.Lars-MacBook-Air.system --dry-run
  @echo "✅ Build successful - configuration is valid"

# Add test-fast command
test-fast:
  @echo "🧪 Fast syntax check..."
  nix flake check

# Add test-nixos command
test-nixos:
  @echo "🧪 Testing NixOS configuration..."
  nix build .#nixosConfigurations.evo-x2.system --dry-run
  @echo "✅ NixOS configuration is valid"
```

#### Step 2: Add Pre-Commit Hook (10 minutes)

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: nix-test
        name: Test Nix Configuration
        entry: just test
        language: system
        pass_filenames: false
```

#### Step 3: Verify (5 minutes)

```bash
# Test the new command
just test

# Verify it works without sudo
# Should succeed with: "✅ Build successful"
```

---

### Enhanced Testing Strategy

#### 1. Multi-Level Testing

```bash
# Fast: Syntax only (5 seconds)
just test-fast

# Medium: Build validation (2 minutes)
just test

# Slow: Full dry-run rebuild (10 minutes)
just test-full

# Cross-Platform: Test both macOS and NixOS
just test-all
```

#### 2. Add to CI/CD (if applicable)

```yaml
# .github/workflows/test.yml
name: Test Nix Configuration
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v22
      - name: Test configuration
        run: just test
```

---

### Success Metrics

- [ ] `just test` works without sudo
- [ ] Test catches syntax errors
- [ ] Test catches missing dependencies
- [ ] Test completes in <5 minutes
- [ ] Pre-commit hook validates changes
- [ ] CI/CD pipeline validates PRs

---

### Estimated Effort

**Total:** 30 minutes (immediate fix)

- Update justfile: 5 minutes
- Add pre-commit hook: 10 minutes
- Verify: 5 minutes
- Document: 10 minutes

---

### Dependencies

**Blocks:**

- Issue #132 (EVO-X2 Deployment) - need safe testing
- Issue #131 (Performance Baselines) - need validation
- Issue #134 (Program Modules) - need testing
- **ALL** Nix configuration work

**Enables:**

- Safe development practices
- Automated validation
- CI/CD integration
- Confident configuration changes

---

## 📊 Summary & Recommendations

### Priority Order (Must Fix First)

1. **🔴 CRITICAL - Issue #122 (Fix Nix Testing Pipeline)**
   - **Time:** 30 minutes
   - **Impact:** Unblocks all Nix work
   - **Action:** Fix immediately

2. **🔴 CRITICAL - Issue #132 (Deploy EVO-X2 NixOS)**
   - **Time:** 20-30 hours (2-3 weeks)
   - **Impact:** Completes cross-platform development environment
   - **Action:** Start after Issue #122 fixed

3. **🔴 HIGH - Issue #131 (Performance Baselines)**
   - **Time:** 12-16 hours (2-3 weeks)
   - **Impact:** Essential for measuring success
   - **Action:** Start after Issue #132 complete

4. **🔴 HIGH - Issue #133 (Advanced Network Configuration)**
   - **Time:** 20-30 hours (excluding WiFi 7)
   - **Impact:** Enhanced security and performance
   - **Action:** Phase 1 (VPN) after Issue #132

5. **🟡 MEDIUM - Issue #125 (Dynamic Library Management)**
   - **Time:** 20-24 hours (3-4 weeks)
   - **Impact:** Improved developer experience
   - **Action:** Incremental implementation

6. **🟢 LOW - Issue #130 (RISC-V Support)**
   - **Time:** 20-24 hours (3-4 weeks)
   - **Impact:** Future-proofing, limited current use
   - **Action:** Defer until hardware available

---

### Next Actions

**This Week:**

1. ✅ Fix Issue #122 (30 minutes) - Unblock testing
2. ✅ Review Issue #132 requirements (1 hour) - Plan deployment

**Next Week:** 3. ✅ Start Issue #132 deployment (4-6 hours) - Base installation 4. ✅ Continue Issue #132 (4-6 hours) - Complete deployment

**Following Weeks:** 5. ✅ Complete Issue #132 (10-12 hours) - Validation 6. ✅ Start Issue #131 (6 hours) - Baseline establishment 7. ✅ Start Issue #133 Phase 1 (4-6 hours) - VPN integration

---

### Risk Assessment

| Issue | Risk                        | Impact | Mitigation                          |
| ----- | --------------------------- | ------ | ----------------------------------- |
| #122  | Test not comprehensive      | Medium | Add `test-full` for thorough checks |
| #132  | Hardware driver issues      | High   | Research drivers, have alternatives |
| #131  | Baseline becomes outdated   | Low    | Regular re-baselining               |
| #133  | WiFi 7 not available        | High   | Defer WiFi 7, focus on VPN/VLAN     |
| #125  | Wrapper performance impact  | Low    | Benchmark before/after              |
| #130  | RISC-V packages unavailable | Low    | Research package coverage           |

---

### Resource Requirements

**Hardware:**

- Issue #132: EVO-X2 hardware needed
- Issue #130: RISC-V board (optional)

**Software:**

- Issue #122: None (just command fix)
- Issue #131: Benchmarking tools (hyperfine, iperf3)
- Issue #133: VPN server (WireGuard, OpenVPN)
- Issue #125: Development tools (otool, install_name_tool)

---

### Dependencies Graph

```
#122 (Fix Testing) ──► #132 (EVO-X2 Deploy) ──► #131 (Baselines)
                                            │
                                            ├─► #133 (Network Config)
                                            ├─► #134 (Program Modules)
                                            └─► #125 (Dynamic Libs)

#130 (RISC-V) ──► (Independent, can proceed anytime)
```

---

## 📚 Additional Resources

### Documentation References

- **AGENTS.md:** Agent guidance for all tasks
- **TECHNITIUM-DNS-EVALUATION.md:** DNS configuration (Issue #133)
- **docs/architecture/**: Technical architecture docs
- **docs/status/**: Development history and status

### Just Commands Reference

```bash
# Testing
just test           # Test configuration (after #122 fix)
just test-fast       # Syntax only
just test-nixos      # Test NixOS config

# Development
just go-dev          # Go development workflow
just go-lint         # Go linting
just go-format       # Go formatting

# Performance
just benchmark-all   # Comprehensive benchmarks
just benchmark-shells # Shell performance

# System
just health          # System health check
just network-status  # Network status
```

---

**End of Batch Recommendations**
**Next Steps:** Review remaining issues (#119-117, #116-113, #105, #104, #100-99, #98-97, #92, #42, #39-38, #22, #17-15, #12-10, #9, #7-6, #5)

---

**Last Updated:** 2025-01-13
