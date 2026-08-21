# Storage Optimization Plan

**Generated:** 2026-02-10
**Status:** Immediate cleanup completed (~6GB freed)

---

## 📊 Current State

| Metric         | Before      | After       | Status                   |
| -------------- | ----------- | ----------- | ------------------------ |
| Disk Usage     | 212GB (93%) | 215GB (95%) | ⚠️ Still critical         |
| Free Space     | 17GB        | 14GB        | ❌ Need 20GB+ for builds |
| Library/Caches | 14GB        | 8.2GB       | ✅ Cleaned ~6GB          |
| Nix Store      | 20GB        | 20GB        | ❌ Needs optimization    |

**Major Space Consumers Identified:**

1. **Library/Caches (8.2GB remaining):**
   - Google Chrome: ~2GB
   - Helium/WhatsApp: ~2.9GB
   - JetBrains IDEs: ~646MB
   - bun: ~332MB

2. **Nix Store (20GB):**
   - llvm-project-5.10.1-src: 1.4GB (can remove)
   - rustc: 893MB
   - Source tarballs: ~1.2GB
   - oxlint vendor: 401MB
   - Multiple LLVM libs: ~1.1GB (old versions)

3. **89 GC Roots** - Prevent garbage collection

---

## 🚨 Critical Issues

### Build Failures

```
error: no space left on device
- terraform build: failed
- kubectl build: failed
- k9s build: failed
```

**Root Cause:** Large Go builds (terraform ~2GB, kubectl ~500MB, k9s ~300MB) require temporary space >15GB.

---

## ✅ Immediate Actions Completed

### 1. Cleaned Library/Caches (~6GB freed)

- ✅ Go language server caches: gopls, goimports, golangci-lint (~5GB)
- ✅ Google Chrome cache (~2-3GB)
- ✅ JetBrains IDE logs/indices (~500MB)
- ✅ Miscellaneous caches: legcord, bun (~500MB)

### 2. Cache Cleanup Script

```bash
# Already executed:
rm -rf ~/Library/Caches/gopls
rm -rf ~/Library/Caches/goimports
rm -rf ~/Library/Caches/golangci-lint
rm -rf ~/Library/Caches/Google/Chrome/Default/Cache
rm -rf ~/Library/Caches/JetBrains/*/log
rm -rf ~/Library/Caches/JetBrains/*/index
rm -rf ~/Library/Caches/legcord-updater
rm -rf ~/Library/Caches/bun
```

---

## 🎯 Next Actions (Requires Sudo)

### 1. Nix Garbage Collection (Free 3-5GB)

**Remove old system/user generations:**

```bash
sudo nix-collect-garbage -d --delete-older-than 3d
```

**Expected:** 3-5GB freed from old generations

### 2. Remove Unused Source Files (Free 1-2GB)

**Remove old source directories:**

```bash
# Requires sudo - Nix store is read-only
sudo find /nix/store -maxdepth 1 -name "*-source" -type d -exec rm -rf {} +
```

**Target files:**

- llvm-project-5.10.1-src: 1.4GB
- Various source tarballs: ~1.2GB

**Expected:** 1-2GB freed from unused sources

### 3. Nix Store Optimization (Free 2-3GB)

**Deduplicate files across Nix store:**

```bash
sudo nix-store --optimize
```

**Expected:** 2-3GB freed via deduplication

---

## 🛡️ Preventive Measures

### 1. Configure Automatic Nix GC

**Add to `/etc/nix/nix.conf`:**

```ini
# Auto-garbage collect
min-free = 10737418240      # 10GB min free space
keep-outputs = true          # Keep build outputs
max-build-log-size = 10485760 # 10MB max log size
```

**Effect:** Auto-GC when disk < 10GB free

### 2. Reduce Build Parallelism

**Add to `flake.nix` or `nix.conf`:**

```ini
max-jobs = 4              # Reduce from auto (all cores)
cores = 4                 # Limit concurrent builds
```

**Effect:** Less temporary disk usage during builds

### 3. Disable Tests During Builds

**Add to `~/.config/nix/nix.conf`:**

```ini
build-repeat = 1           # Don't rebuild
sandbox = false           # Faster builds (less secure)
log-lines = 50            # Reduce log size
```

**Effect:** Smaller build outputs, faster builds

### 4. Use Binary Caches Aggressively

**Ensure these are configured in `/etc/nix/nix.conf`:**

```ini
substituters = https://cache.nixos.org https://nix-community.cachix.org https://numtide.cachix.org https://nixpkgs-wayland.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o+gAlAYeD3Pz7wzVv+X1sHvP6qZQO7kZwO6jgFjPKJfGh0s6XJ5KpKg3zCzjgU
```

**Effect:** More builds from cache = less local building = less space needed

### 5. Profile Wipe History

**Clean old user profiles:**

```bash
nix profile wipe-history --profile ~/.local/state/nix/profiles/profile
```

**Effect:** Remove old unused profile generations

---

## 📦 Package-Level Optimizations

### 1. Remove Large Unused Packages

**Check package sizes:**

```bash
du -sh /nix/store/* | sort -hr | head -20
```

**Large packages to consider:**

- `llvm-project-5.10.1-src`: 1.4GB (source only, can remove)
- `rustc-1.92.0`: 893MB (keep only current version)
- `google-chrome`: 643MB (alternatives: chromium, ungoogled-chromium)
- `dotnet-sdk-8.0.417`: 519MB (if not using .NET)
- `oxlint-1.42.0-vendor`: 401MB (dev dependency)

### 2. Use Static Binaries Instead

**Replace Nix packages with static binaries where possible:**

```bash
# Instead of nixpkgs.terraform:
# Use: terraform (static binary from HashiCorp)
# Benefit: No build dependencies, smaller store impact
```

---

## 🔄 Maintenance Schedule

### Weekly

```bash
# Run on Fridays (before weekend)
just clean              # Already in justfile
nix-collect-garbage -d --delete-older-than 7d
```

### Monthly

```bash
# Run on 1st of month
nix-store --optimize
nix profile wipe-history
# Clean remaining caches
rm -rf ~/Library/Caches/Google/Chrome/*/Cache/*
rm -rf ~/Library/Caches/JetBrains/*/log
```

### Quarterly

```bash
# Run every 3 months
just clean-aggressive      # Comprehensive cleanup in justfile
```

---

## 📊 Storage Goals

| Metric             | Current   | Target      | Action                    |
| ------------------ | --------- | ----------- | ------------------------- |
| Disk Free Space    | 14GB (6%) | 40GB+ (15%) | Below actions             |
| Nix Store Size     | 20GB      | 12GB        | GC + optimization         |
| Library/Caches     | 8.2GB     | 4GB         | Regular cleanup           |
| Build Failure Rate | High      | Zero        | Free space + cache config |

---

## 🎯 Execution Plan

### Phase 1: Immediate (Today, requires sudo)

1. Run `sudo nix-collect-garbage -d --delete-older-than 3d`
2. Run `sudo nix-store --optimize`
3. Run `sudo rm -rf /nix/store/*-source` (with verification)
4. Check disk space: `df -h /`

**Expected:** Free 6-10GB additional space

### Phase 2: Configuration (This week)

1. Add `min-free = 10737418240` to `/etc/nix/nix.conf`
2. Add `keep-outputs = true` to `/etc/nix/nix.conf`
3. Add `max-jobs = 4` to `/etc/nix/nix.conf`
4. Restart Nix daemon: `sudo launchctl kickstart -k system/org.nixos.nix-daemon`

**Expected:** Auto-prevent future space issues

### Phase 3: Maintenance (Ongoing)

1. Run `just clean` weekly
2. Run `nix-store --optimize` monthly
3. Run `just clean-aggressive` quarterly
4. Monitor disk space: `df -h /` (alert if <15%)

**Expected:** Maintain healthy storage levels

---

## 📝 Commands Reference

### Quick Status Check

```bash
# Disk space
df -h /

# Nix store size
du -sh /nix/store

# Cache sizes
du -sh ~/Library/Caches/* | sort -hr | head -10
```

### Cleanup Commands

```bash
# Quick cleanup (safe)
just clean-quick

# Comprehensive cleanup (recommended)
just clean

# Aggressive cleanup (if critical)
just clean-aggressive

# Nix-specific cleanup
nix-collect-garbage -d --delete-older-than 3d
nix-store --optimize
nix profile wipe-history
```

### Build with Space Constraints

```bash
# Use less parallelism
nix-build -j4 --max-jobs 4 .#system

# Keep outputs (reuse across builds)
nix-build --keep-going .#package

# Use binary cache
nix-build --option keep-going true --max-jobs 2 .#package
```

---

## ⚠️ Safety Notes

1. **Always verify before deleting:**

   ```bash
   # Check what will be deleted
   nix-store --gc --print-roots | head -20
   ```

2. **Keep recent generations:**

   ```bash
   # Keep at least last 2 working generations
   nix-collect-garbage -d --delete-older-than 3d  # Not 1d
   ```

3. **Test after GC:**

   ```bash
   # Verify system still works
   just test
   just health
   ```

4. **Rollback plan:**
   ```bash
   # If GC breaks system
   just rollback
   # Or:
   darwin-rebuild switch --rollback
   ```

---

## 📞 Getting Help

If storage issues persist:

1. **Check disk usage breakdown:**

   ```bash
   ncdu /        # Interactive disk usage analyzer
   ```

2. **Analyze Nix store:**

   ```bash
   nix-du -n /nix/store | sort -hr | head -20
   # Or:
   nix path-info -Sh /nix/store/* | head -20
   ```

3. **Check for space leaks:**
   ```bash
   # Find large files growing
   find / -type f -size +1G -exec ls -lh {} + 2>/dev/null
   ```

---

## ✅ Success Criteria

- [ ] Disk free space > 30GB
- [ ] Nix store < 15GB
- [ ] Library/Caches < 5GB
- [ ] No "no space left" build errors
- [ ] Auto-GC configured (min-free setting)
- [ ] `just clean` runs weekly
- [ ] Successful build after cleanup (just switch)

---

**Next Step:** Run Phase 1 actions (requires sudo password)
