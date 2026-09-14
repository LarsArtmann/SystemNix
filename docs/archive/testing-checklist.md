# Setup-Mac Testing Checklist

**Created:** 2025-12-26
**Purpose:** Comprehensive testing procedures for validating Nix configuration changes
**Scope:** Both Darwin (macOS) and NixOS configurations

---

## 🎯 Testing Philosophy

**Automate Everything Possible**

- Use `just test` before `just switch`
- Always run `just pre-commit-run` before committing
- Validate with `nix flake check` for syntax and imports
- Run `just health` for comprehensive validation

**Test Hierarchy** (fastest → slowest):

1. **Syntax Check**: `nix flake check` (< 1 min)
2. **Pre-commit**: `just pre-commit-run` (~2-3 min)
3. **Build Test**: `just test` (~5-10 min)
4. **Health Check**: `just health` (~1-2 min)
5. **Apply**: `just switch` / `sudo nixos-rebuild switch` (~10-30 min)

---

## ✅ Pre-Commit Checklist

**Must pass before ANY commit:**

- [ ] **Syntax Validation**

  ```bash
  nix flake check
  # Expected: All outputs evaluate successfully
  # Critical check: Verifies all imports exist and are valid
  ```

- [ ] **Pre-commit Hooks**

  ```bash
  just pre-commit-run
  # Expected: All hooks pass (gitleaks, trailing whitespace, Nix linters)
  # Critical checks:
  #   - Gitleaks: No secrets in staged files
  #   - Trailing whitespace: No trailing spaces/tabs
  #   - Nix linters: No statix or deadnix warnings
  ```

- [ ] **Code Formatting** (if Nix files changed)
  ```bash
  just format
  # Expected: All files reformatted by treefmt
  ```

---

## 🧪 Pre-Apply Testing Checklist

**Must pass before applying changes to system:**

- [ ] **Configuration Build Test** (Darwin)

  ```bash
  just test
  # Expected: Build completes successfully
  # Note: This tests configuration WITHOUT applying to system
  ```

- [ ] **Configuration Build Test** (NixOS)

  ```bash
  sudo nixos-rebuild test --flake .#evo-x2
  # Expected: Build completes successfully
  # Note: This tests configuration WITHOUT applying to system
  ```

- [ ] **Health Check** (both platforms)
  ```bash
  just health
  # Expected: No critical errors or warnings
  # Checks: System status, outdated packages, configuration validity
  ```

---

## 🚀 Post-Apply Verification Checklist

**Verify after applying changes to system:**

- [ ] **System Build** (Darwin)

  ```bash
  just switch
  # Expected: New generation activated successfully
  ```

- [ ] **System Build** (NixOS)

  ```bash
  sudo nixos-rebuild switch --flake .#evo-x2
  # Expected: New generation activated successfully
  ```

- [ ] **Package Availability** (spot check)

  ```bash
  # Test critical packages:
  git --version    # Version control
  fish --version   # Shell
  nvim --version   # Editor
  # Expected: All commands succeed
  ```

- [ ] **Configuration Validity**
  ```bash
  just health
  # Expected: System shows healthy status
  ```

---

## 🔧 Platform-Specific Testing

### Darwin (macOS) Testing

**Critical Areas:**

- [ ] Homebrew integration works
- [ ] Touch ID for sudo enabled
- [ ] System services (if any) running
- [ ] Nix apps registered in Launch Services
- [ ] File associations work (duti)

**Commands:**

```bash
# Test Homebrew
brew --version

# Test Touch ID sudo
sudo -v  # Should prompt for Touch ID, not password

# Test Nix apps
ls /Applications/Nix Apps

# Test file associations
duti -e com.sublimetext.4 .txt
```

### NixOS Testing

**Critical Areas:**

- [ ] Display manager starts (SDDM)
- [ ] Hyprland/Wayland sessions available
- [ ] GPU acceleration works (AMD ROCm)
- [ ] Ollama service running with GPU support
- [ ] Network connectivity (Ethernet + WiFi)
- [ ] SSH daemon running and hardened
- [ ] Monitoring services active (Netdata, ntopng)

**Commands:**

```bash
# Test GPU
rocminfo | head -20
clinfo 2>/dev/null | head -20

# Test Ollama
systemctl status ollama
ollama list  # Should show installed models
# Test with GPU:
ollama run tinyllama "Hello"

# Test network
nmcli device status  # Should show both interfaces

# Test SSH
systemctl status sshd
ssh -T git@github.com  # Test SSH to GitHub

# Test monitoring
curl http://localhost:19999  # Netdata (should show dashboard)
curl http://localhost:3000  # ntopng (should login page)
```

---

## 🐛 Debugging Checklist

**When things fail:**

### Syntax Errors

- [ ] Check error message for file path and line number
- [ ] Look for missing braces, commas, or quotes
- [ ] Verify variable names are spelled correctly
- [ ] Check import paths are correct

### Import Errors

- [ ] Verify imported file exists at specified path
- [ ] Check for circular dependencies
- [ ] Ensure file has correct `.nix` extension
- [ ] Verify file has correct function signature

### Build Errors

- [ ] Check package availability with `nix search nixpkgs <package>`
- [ ] Verify package names are correct (may need to rename)
- [ ] Check for conflicting packages
- [ ] Review error log for missing dependencies

### Runtime Errors

- [ ] Check service status: `systemctl status <service>`
- [ ] Review journal logs: `journalctl -xeu <service>`
- [ ] Verify environment variables: `systemctl show <service> -p Environment`
- [ ] Check permissions and user groups

### Darwin Build Errors

- [ ] Check for `boost::too_few_args` errors (format string issues)
- [ ] Verify all referenced variables are in scope
- [ ] Check for undefined variables (`pkgs`, `lib`, etc.)
- [ ] Run with `--show-trace` for detailed stack traces

---

## 🔄 Continuous Testing Workflow

**Daily Testing (during development):**

1. Make configuration changes
2. Run `just format` (if Nix files changed)
3. Run `just pre-commit-run`
4. Run `nix flake check`
5. Run `just test` (build test)
6. Commit changes with detailed message
7. Run `just switch` / `sudo nixos-rebuild switch`
8. Run `just health` to verify
9. Spot-check critical packages/services

**Weekly Testing:**

1. Run `just update` (update packages and flake inputs)
2. Run full testing workflow above
3. Run `just benchmark-all` to check performance
4. Review `just health` for outdated packages
5. Create backup with `just backup`

**Monthly Testing:**

1. Run full daily + weekly testing
2. Run `just clean` to remove old generations
3. Test on both platforms (Darwin + NixOS)
4. Review and update documentation
5. Audit packages for duplications (see M1 task)

---

## 📊 Test Result Documentation

**Track results in status reports:**

```markdown
## Test Results (YYYY-MM-DD)

### Syntax Validation

- Status: ✅ PASS / ❌ FAIL
- Details: [Notes]

### Pre-commit Hooks

- Status: ✅ PASS / ❌ FAIL
- Details: [Notes]

### Build Test (Darwin)

- Status: ✅ PASS / ❌ FAIL
- Details: [Notes]

### Build Test (NixOS)

- Status: ✅ PASS / ❌ FAIL
- Details: [Notes]

### Health Check

- Status: ✅ PASS / ❌ FAIL
- Details: [Notes]

### Post-Apply Verification

- [ ] All packages available
- [ ] Services running
- [ ] Configuration valid

### Issues Found

- [ ] Issue 1: [Description]
- [ ] Issue 2: [Description]
```

---

## 🚨 Critical Failures

**Stop and fix immediately:**

1. **Gitleaks detects secret** - Do not commit, remove secret immediately
2. **Syntax error** - Cannot proceed until fixed
3. **Import error** - Configuration broken, fix import
4. **Build fails** - Cannot apply, resolve build error
5. **Service fails to start** - System may be unstable
6. **GPU acceleration broken** - Critical for AI workloads

**Warning failures (can proceed with caution):**

1. **Statix warnings** - Fix in next commit
2. **Dead code warnings** - Remove in next cleanup
3. **Trailing whitespace** - Fix with `just format`
4. **Outdated packages** - Update during weekly maintenance

---

## 📋 Quick Reference Commands

```bash
# Fastest checks (run these frequently)
nix flake check              # Syntax validation
just pre-commit-run           # Pre-commit hooks

# Medium speed checks (run before applying)
just test                     # Build test (Darwin)
just health                   # Health check

# Slow checks (run after major changes)
just switch                   # Apply Darwin config
sudo nixos-rebuild switch     # Apply NixOS config
just benchmark-all            # Performance benchmarks

# Maintenance
just update                   # Update packages
just clean                    # Clean old generations
just backup                   # Create backup
just rollback                 # Emergency rollback
```

---

## 🎯 Success Criteria

**Testing is complete when:**

- [ ] All pre-commit checks pass
- [ ] All syntax checks pass
- [ ] Both platform configurations build successfully
- [ ] Health check shows no critical issues
- [ ] Post-apply verification passes
- [ ] Critical packages and services verified
- [ ] Test results documented in status report

**System is considered stable when:**

- [ ] All automated tests pass
- [ ] No critical errors or warnings
- [ ] All services running normally
- [ ] GPU acceleration functional (NixOS)
- [ ] Package availability verified
- [ ] Performance benchmarks within acceptable range

---

_This checklist should be updated as new testing requirements are discovered._
_Last updated: 2025-12-26_
