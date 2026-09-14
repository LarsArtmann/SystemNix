# Crush-Patched: Advanced Build Strategies

**Date**: 2026-02-06
**Purpose**: Alternative build strategies for crush-patched when standard approach fails

---

## 📋 Overview

This document describes advanced build strategies for crush-patched when the standard `vendorHash` approach encounters issues.

### Standard Approach (Current Default)

```nix
buildGoModule {
  # ...
  vendorHash = "sha256-...";
}
```

**Pros**:

- Fast rebuilds (vendor directory cached)
- Reproducible builds
- Works offline once dependencies cached

**Cons**:

- Requires vendorHash calculation
- Can fail with vendor directory issues
- More complex setup

---

## 🚀 Alternative Strategy 1: Vendor-Free Build

### Concept

Remove `vendorHash` entirely and let `buildGoModule` download dependencies from the network.

### Implementation

```nix
pkgs/buildGoModule rec {
  pname = "crush-patched";
  version = "v0.39.3";

  src = pkgs.fetchurl {
    url = "https://github.com/charmbracelet/crush/archive/refs/tags/v0.39.3.tar.gz";
    sha256 = "sha256:0d5q8c3c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c"; # Update this
  };

  # Remove or comment out vendorHash
  # vendorHash = "sha256-...";

  # OR explicitly set to null
  vendorHash = null;

  # Rest of configuration...
}
```

### When to Use

- ✅ Standard vendorHash approach fails
- ✅ Vendor directory issues persist
- ✅ Need simple, reliable build
- ✅ Can tolerate slower builds

### When NOT to Use

- ❌ Need fast rebuilds
- ❌ Build offline frequently
- ❌ Network is unreliable

### Expected Behavior

1. First build: Downloads all dependencies (~2-5 minutes)
2. Subsequent builds: Faster, but still downloads if cache invalid
3. Network required for every build (no offline mode)

### Modification to pkgs/crush-patched.nix

```nix
# Change this line:
  vendorHash = "sha256-uo9VelhRjtWiaYI88+eTk9PxAUE18Tu2pNq4qQqoTwk=";

# To this:
  vendorHash = null;
```

### Testing Vendor-Free Approach

```bash
# Backup current configuration
cp pkgs/crush-patched.nix pkgs/crush-patched.nix.backup-$(date +%s)

# Modify to vendorHash = null
# Edit pkgs/crush-patched.nix

# Test build (when disk space available)
nix build .#crush-patched

# If successful, apply
just switch

# If failed, restore
cp pkgs/crush-patched.nix.backup-* pkgs/crush-patched.nix
```

---

## 🔧 Alternative Strategy 2: Generate Vendor During Build

### Concept

Add `postUnpack` hook to generate vendor directory from go.mod, then use vendorHash.

### Implementation

```nix
pkgs/buildGoModule rec {
  pname = "crush-patched";
  version = "v0.39.3";

  src = pkgs.fetchurl {
    url = "https://github.com/charmbracelet/crush/archive/refs/tags/v0.39.3.tar.gz";
    sha256 = "sha256:...";
  };

  # Generate vendor directory during build
  postUnpack = ''
    cd $sourceRoot
    go mod vendor
  '';

  # vendorHash will be calculated on first build
  vendorHash = null;

  # Rest of configuration...
}
```

### First Build Process

1. Download source (no vendor directory)
2. `postUnpack` runs `go mod vendor` to create vendor/
3. `buildGoModule` calculates vendorHash from created vendor/
4. Build completes with error showing correct vendorHash
5. Update vendorHash in Nix file
6. Rebuild (now fast and cached)

### When to Use

- ✅ Want fast rebuilds
- ✅ Source has go.mod but no vendor/
- ✅ Can tolerate initial slower build
- ✅ Standard vendorHash calculation fails

### When NOT to Use

- ❌ Source already has broken vendor/
- ❌ Need simplest possible setup
- ❌ Don't want two-step build process

### Step-by-Step Implementation

**Step 1: Update version and source hash**

```bash
# Update version in pkgs/crush-patched.nix
# Update source URL and sha256
# Set vendorHash = null
# Add postUnpack hook
```

**Step 2: First build (will fail to get vendorHash)**

```bash
nix build .#crush-patched 2>&1 | tee /tmp/crush-build.log
```

**Step 3: Extract vendorHash from error**

```bash
grep "got:.*sha256-" /tmp/crush-build.log | \
  sed 's/.*sha256-//' | head -1
```

**Step 4: Update vendorHash in Nix file**

```nix
vendorHash = "sha256-<extracted-hash>";
```

**Step 5: Final build (should succeed)**

```bash
nix build .#crush-patched
```

---

## 🔍 Alternative Strategy 3: Force Network Mode

### Concept

Force `buildGoModule` to ignore any existing vendor directory and download from network.

### Implementation

```nix
pkgs/buildGoModule rec {
  # ...

  # Force network mode (ignore vendor/)
  proxyVendor = false;

  # Set vendorHash to null to trigger download
  vendorHash = null;

  # Rest of configuration...
}
```

### When to Use

- ✅ Source has broken vendor directory
- ✅ Want to bypass vendor completely
- ✅ Network is reliable

### When NOT to Use

- ❌ Need offline builds
- ❌ Network is unreliable
- ❌ Want fastest possible builds

---

## 📊 Strategy Comparison

| Strategy              | Build Speed                 | Complexity | Reliability | Offline | Best For                    |
| --------------------- | --------------------------- | ---------- | ----------- | ------- | --------------------------- |
| Standard (vendorHash) | ⚡⚡⚡ Fast                 | Medium     | High        | ✅ Yes  | Production, frequent builds |
| Vendor-Free           | ⚡⚡ Medium                 | Low        | Very High   | ❌ No   | Simple setups, testing      |
| Generate Vendor       | ⚡⚡⚡⚡ Fast (after first) | High       | High        | ✅ Yes  | Performance critical        |
| Force Network         | ⚡⚡ Medium                 | Low        | High        | ❌ No   | Broken vendor, testing      |

---

## 🎯 Decision Matrix

### Use Standard vendorHash when:

- Building for production
- Need fastest possible rebuilds
- Building frequently
- Offline builds needed
- ✅ **This is the current default**

### Use Vendor-Free when:

- Standard approach fails
- Want simplest setup
- Don't mind slower builds
- Network is reliable
- Testing new versions

### Use Generate Vendor when:

- Need performance but vendor missing
- Can tolerate two-step setup
- Building frequently
- Source has go.mod but no vendor/

### Use Force Network when:

- Source has broken vendor/
- Need to bypass vendor issues
- Network is reliable
- Testing or debugging

---

## 🧪 Testing Strategies

### Test Vendor-Free (Recommended First Step)

```bash
# Create test Nix expression
cat > /tmp/test-vendor-free.nix <<'EOF'
{ pkgs }:
pkgs.buildGoModule rec {
  pname = "crush-test";
  version = "v0.39.3";

  src = pkgs.fetchurl {
    url = "https://github.com/charmbracelet/crush/archive/refs/tags/v0.39.3.tar.gz";
    sha256 = "sha256:0d5q8c3c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c"; # Update this
  };

  vendorHash = null;

  env = {
    GOEXPERIMENT = "greenteagc";
    CGO_ENABLED = "0";
  };

  ldflags = [
    "-s" "-w"
    "-X=github.com/charmbracelet/crush/internal/version.Version=${version}"
  ];

  doCheck = false;
}
EOF

# Test build
nix-build /tmp/test-vendor-free.nix
```

### Test Generate Vendor

```bash
# Create test Nix expression with postUnpack
cat > /tmp/test-generate-vendor.nix <<'EOF'
{ pkgs }:
pkgs.buildGoModule rec {
  pname = "crush-test";
  version = "v0.39.3";

  src = pkgs.fetchurl {
    url = "https://github.com/charmbracelet/crush/archive/refs/tags/v0.39.3.tar.gz";
    sha256 = "sha256:...";
  };

  postUnpack = ''
    cd $sourceRoot
    go mod vendor
  '';

  vendorHash = null;

  # ... rest of config
}
EOF

# Test build (will fail to get vendorHash)
nix-build /tmp/test-generate-vendor.nix 2>&1 | tee /tmp/test-build.log

# Extract vendorHash
grep "got:.*sha256-" /tmp/test-build.log | sed 's/.*sha256-//' | head -1

# Update and rebuild
```

---

## 🔧 Integration with Automation

### Current Automation Flow

1. Detect latest version
2. Update version and source hash
3. Build with `vendorHash = null`
4. Extract vendorHash from error
5. Update vendorHash
6. Final build

### Enhanced Automation Flow (With Fallback)

1. Detect latest version
2. Update version and source hash
3. **Try standard vendorHash approach**
   - Build with `vendorHash = null`
   - Extract vendorHash
   - Final build
4. **If fails, try vendor-free**
   - Set `vendorHash = null`
   - Build (downloads from network)
   - No vendorHash needed

### Recommended Enhancement

Update `pkgs/update-crush-patched.sh` to try vendor-free as fallback:

```bash
# ... after standard approach fails ...

echo ""
echo "⚠️  Standard vendorHash approach failed"
echo "💡 Trying vendor-free approach as fallback..."

# Set vendorHash to null
sed -i.bak "s|^  vendorHash = \".*\";|  vendorHash = null;|" "$NIX_FILE"
rm -f "${NIX_FILE}.bak"

echo "🔨 Building vendor-free (downloads from network)..."
if nix build .#crush-patched 2>&1 | tee /tmp/crush-build-vendor-free.log; then
    echo ""
    echo "✅ Vendor-free build succeeded!"
    echo "   Note: Builds will be slower but more reliable."
    rm -f "$BACKUP_FILE"
    exit 0
else
    echo ""
    echo "❌ Vendor-free approach also failed"
    echo "   Check /tmp/crush-build-vendor-free.log"
    echo ""
    echo "🔄 Rolling back to previous version..."
    cp "$BACKUP_FILE" "$NIX_FILE"
    rm -f "$BACKUP_FILE"
    echo "✅ Rolled back to $CURRENT_VERSION"
    exit 1
fi
```

---

## 📝 Implementation Checklist

### Vendor-Free Approach

- [ ] Backup current configuration
- [ ] Set `vendorHash = null` in Nix file
- [ ] Update version and source hash
- [ ] Test build
- [ ] If successful, apply with `just switch`
- [ ] If failed, restore from backup

### Generate Vendor Approach

- [ ] Backup current configuration
- [ ] Add `postUnpack = "go mod vendor"` hook
- [ ] Set `vendorHash = null` initially
- [ ] Build first time (fails to get vendorHash)
- [ ] Extract vendorHash from error
- [ ] Update vendorHash in Nix file
- [ ] Build second time (should succeed)
- [ ] Apply with `just switch`

---

## 🚨 Troubleshooting

### Vendor-Free Build Fails

**Issue**: Build fails even with `vendorHash = null`

**Check**:

```bash
# Check build log for errors
cat /tmp/crush-build.log

# Look for network errors
grep "network\|download\|fetch" /tmp/crush-build.log

# Look for dependency conflicts
grep "conflict\|incompatible" /tmp/crush-build.log
```

**Solutions**:

1. Check network connectivity
2. Verify source URL and hash are correct
3. Try generating vendor instead (Strategy 2)

### Generate Vendor Fails

**Issue**: `postUnpack` hook fails

**Check**:

```bash
# Check for go command availability
nix-shell -p go --run "go version"

# Check if go.mod exists in source
tar -tzf source.tar.gz | grep go.mod
```

**Solutions**:

1. Ensure Go is available in build environment
2. Verify go.mod exists in source
3. Try vendor-free approach instead

### vendorHash Extraction Fails

**Issue**: Cannot extract vendorHash from build log

**Check**:

```bash
# Look for alternative hash messages
grep -E "hash|sha256" /tmp/crush-build.log

# Check if build succeeded
[ -f ./result ] && echo "Build succeeded" || echo "Build failed"
```

**Solutions**:

1. Try vendor-free approach
2. Check if build error is different than expected
3. Manual inspection of build log

---

## 📚 References

### Nix Documentation

- [buildGoModule](https://nixos.org/manual/nixpkgs/stable/#sec-functions-library-buildGoModule)
- [Vendor Hashes](https://nixos.org/manual/nixpkgs/stable/#sec-language-go-vendorHash)

### Go Documentation

- [go mod vendor](https://go.dev/ref/mod#go-mod-vendor)
- [Vendor Directory](https://go.dev/ref/mod#vendor-directories)

### Crush Repository

- [Crush Releases](https://github.com/charmbracelet/crush/releases)
- [Crush Issues](https://github.com/charmbracelet/crush/issues)

---

## 🎓 Summary

**Quick Decision Guide**:

1. **Production builds** → Use standard vendorHash (current default)
2. **Testing new versions** → Try vendor-free first (simplest)
3. **Performance needed** → Generate vendor during build
4. **Broken vendor/** → Force network mode

**Remember**:

- Vendor-free is simplest but slower
- Standard vendorHash is fastest but more complex
- Generate vendor gives best of both (after setup)
- Always backup before trying new approaches

---

**End of Document**
