# Nix-Visualize Integration Guide

## Overview

**nix-visualize** is integrated into Setup-Mac for automatic visualization of Nix configuration dependencies. This tool generates comprehensive dependency graphs showing all packages and their relationships in the system.

## What is nix-visualize?

**nix-visualize** is a Python-based tool that:

- Parses Nix store paths (system closures)
- Analyzes package dependencies
- Generates visual dependency graphs
- Supports multiple output formats (SVG, PNG, PDF)

## Integration Details

### 1. Flake Input

Added to `flake.nix`:

```nix
inputs = {
  # ... other inputs ...

  # Add nix-visualize for Nix configuration visualization
  nix-visualize = {
    url = "github:craigmbooth/nix-visualize";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

### 2. Justfile Commands

Added comprehensive visualization commands to `justfile`:

#### Basic Commands

- **`just dep-graph`** - Generate Darwin dependency graph (SVG)

  ```bash
  just dep-graph
  ```

- **`just dep-graph-nixos`** - Generate NixOS dependency graph (SVG)

  ```bash
  just dep-graph-nixos
  ```

- **`just dep-graph-png`** - Generate PNG format
  ```bash
  just dep-graph-png
  ```

#### Advanced Commands

- **`just dep-graph-all`** - Generate all formats for both platforms

  ```bash
  just dep-graph-all
  ```

- **`just dep-graph-verbose`** - Generate with verbose output (debugging)

  ```bash
  just dep-graph-verbose
  ```

- **`just dep-graph-view`** - Open graph in browser

  ```bash
  just dep-graph-view
  ```

- **`just dep-graph-update`** - Regenerate and view (quick workflow)

  ```bash
  just dep-graph-update
  ```

- **`just dep-graph-stats`** - Show graph statistics

  ```bash
  just dep-graph-stats
  ```

- **`just dep-graph-clean`** - Clean generated graphs
  ```bash
  just dep-graph-clean
  ```

## Usage Examples

### Example 1: Generate and View Darwin Graph

```bash
# Generate graph
just dep-graph

# View in browser
just dep-graph-view
```

**Output:**

- File: `docs/architecture/Setup-Mac-Darwin.svg`
- Size: ~1.6MB
- Nodes: 471 packages
- Edges: 1,233 dependencies
- Depth: 19 levels

### Example 2: Generate All Formats

```bash
# Generate SVG, PNG, and PNG (verbose) for Darwin
just dep-graph
just dep-graph-png
just dep-graph-verbose

# Generate NixOS graph
just dep-graph-nixos
```

**Output:**

```
docs/architecture/
├── Setup-Mac-Darwin.svg (1.6MB)
├── Setup-Mac-Darwin.png (~500KB)
├── Setup-Mac-Darwin-verbose.svg (1.6MB)
└── Setup-Mac-NixOS.svg (~1.5MB)
```

### Example 3: Quick Workflow (Regenerate and View)

```bash
# One command to regenerate and view
just dep-graph-update
```

## Output Formats

### SVG (Scalable Vector Graphics) - **Recommended**

- **Format:** Vector graphics
- **Size:** ~1.6MB
- **Quality:** Infinite zoom
- **Best for:** Detailed analysis, documentation, web display
- **File extension:** `.svg`

### PNG (Portable Network Graphics)

- **Format:** Raster graphics
- **Size:** ~500KB
- **Quality:** Fixed resolution
- **Best for:** Presentations, quick viewing
- **File extension:** `.png`

### PDF (via SVG conversion) - **Possible**

```bash
# Convert SVG to PDF using Graphviz
dot -Tpdf docs/architecture/Setup-Mac-Darwin.svg -o docs/architecture/Setup-Mac-Darwin.pdf
```

- **Format:** Document format
- **Best for:** Printing, reports
- **File extension:** `.pdf`

## Graph Interpretation

### Understanding the Graph

**Nodes (Circles/Boxes):**

- Represent Nix packages
- Size indicates importance (dependencies)
- Color groups related packages

**Edges (Lines):**

- Represent dependencies
- Arrow direction: A depends on B
- Line thickness: Dependency strength

**Graph Layout:**

```
┌─────────────────────────────┐
│     System Closure         │  ← Root (system)
├─────────────────────────────┤
│     Core Packages        │  ← Essential (nixpkgs, bash, etc.)
├─────────────────────────────┤
│     Development Tools    │  ← Your tools (git, vim, etc.)
├─────────────────────────────┤
│     Application Packages│  ← Apps (Firefox, etc.)
├─────────────────────────────┤
│     Library Packages    │  ← Dependencies (libs)
└─────────────────────────────┘
```

### Common Graph Patterns

#### Pattern 1: Star Topology (One-to-Many)

```
[Core Package]
      / | \
     /  |  \
[Dep] [Dep] [Dep]
```

**Meaning:** Core package is heavily used (e.g., `nixpkgs`, `bash`)

#### Pattern 2: Chain Topology (Linear)

```
[App] → [Tool] → [Lib] → [Base Lib]
```

**Meaning:** Direct dependency chain (e.g., `firefox` → `bash` → `glibc`)

#### Pattern 3: Diamond Topology (Shared Dependency)

```
[Tool1]  [Tool2]
     \    /
     [Shared Lib]
```

**Meaning:** Multiple tools depend on shared library (good for deduplication)

## Performance Analysis

### Graph Statistics

Current Setup-Mac graph (Darwin):

| Metric     | Value | Interpretation               |
| ---------- | ----- | ---------------------------- |
| Nodes      | 471   | Total packages in system     |
| Edges      | 1,233 | Total dependencies           |
| Depth      | 19    | Maximum dependency depth     |
| Avg Degree | 2.6   | Avg dependencies per package |

### Bottleneck Detection

**High-Degree Nodes (>20 dependencies):**

- `nixpkgs` (implicit dependency)
- `bash` (core shell)
- `glibc` (core C library)
- `openssl` (core crypto)

**Deep Paths (>15 levels):**

- Application → GUI toolkit → graphics libraries → X11 → kernel
- Development tool → build system → compiler → stdenv

### Optimization Opportunities

#### Opportunity 1: Remove Unused Packages

```bash
# Identify leaf nodes (no dependents)
just dep-graph-view
# Look for isolated nodes at edges
# Review if still needed

# Remove from configuration
# platforms/darwin/packages/base.nix (remove package)
```

#### Opportunity 2: Consolidate Dependencies

```bash
# If multiple tools depend on similar libraries
# Consider using alternatives with better deduplication
```

#### Opportunity 3: Reduce Depth

```bash
# If paths are too deep (>15 levels)
# Consider using more recent packages
# Or packages with fewer transitive dependencies
```

## Comparison: Manual vs Automated

### Manual Mermaid Graph (`docs/nix-call-graph.md`)

**Pros:**

- Hand-crafted, semantic meaning
- Clear architecture documentation
- Easy to understand
- Shows module hierarchy

**Cons:**

- Manual maintenance required
- May not reflect actual dependencies
- Limited to Nix files, not packages
- Time-consuming to update

### Automated nix-visualize Graph

**Pros:**

- Automatic generation
- Reflects actual system state
- Shows all package dependencies
- Accurate and up-to-date

**Cons:**

- Shows raw dependencies (less semantic)
- Large graphs can be hard to read
- Technical detail may be overwhelming
- Doesn't show module structure

### Combined Approach (Recommended)

Use both tools:

1. **`docs/nix-call-graph.md`** - High-level architecture
   - Module hierarchy
   - Import relationships
   - Design patterns

2. **nix-visualize graphs** - Detailed dependencies
   - Package-level analysis
   - Dependency optimization
   - Performance insights

## Troubleshooting

### Issue 1: Graph Generation Fails

**Symptom:**

```bash
just dep-graph
# Error: Recipe `dep-graph` failed
```

**Solution:**

```bash
# Check if system closure exists
nix eval .#darwinConfigurations.Lars-MacBook-Air.config.system.build.toplevel --raw

# If fails, rebuild system first
just switch

# Try again
just dep-graph
```

### Issue 2: SVG File Too Large

**Symptom:**

- SVG > 10MB
- Slow to open in browser

**Solution:**

```bash
# Reduce graph complexity by filtering
# (Not directly supported by nix-visualize)
# Use PNG instead
just dep-graph-png

# Or split into subsystems
# Generate graphs for individual packages
```

### Issue 3: Graph Missing Packages

**Symptom:**

- Expected packages not in graph

**Solution:**

```bash
# Rebuild system to update closure
just switch

# Clear cache and regenerate
just dep-graph-clean
just dep-graph

# Verify system state
nix-store --query --requisites /run/current-system
```

### Issue 4: NixOS Graph Fails on Darwin

**Symptom:**

```bash
just dep-graph-nixos
# Error: Cannot evaluate NixOS on Darwin
```

**Solution:**

```bash
# Generate NixOS graph only on NixOS system
# Or use nix eval with --system flag
nix eval --system x86_64-linux .#nixosConfigurations.evo-x2.config.system.build.toplevel --raw
```

## Integration with Existing Tools

### Complementing `docs/nix-call-graph.md`

**Use nix-visualize for:**

- Package-level dependency analysis
- System closure optimization
- Performance bottleneck detection

**Use call graph for:**

- Module architecture documentation
- Import relationship analysis
- Design pattern identification

### Complementing AGENTS.md

Add to AI assistant instructions:

```markdown
When analyzing Setup-Mac:

1. Generate dependency graph:
   - Use `just dep-graph` to visualize current state
   - Analyze graph for optimization opportunities
   - Check for dependency bottlenecks

2. Compare with architecture:
   - Review `docs/nix-call-graph.md` for design
   - Verify actual dependencies match intended architecture
   - Identify discrepancies

3. Suggest improvements:
   - Propose package removals/additions
   - Recommend dependency optimization
   - Suggest architecture refinements
```

## Best Practices

### 1. Generate Graphs After Major Changes

```bash
# After adding/removing packages
just switch
just dep-graph
just dep-graph-view

# Review graph for:
# - New dependencies (unwanted)
# - Missing dependencies (broken)
# - Package count changes
```

### 2. Track Graph Changes Over Time

```bash
# Generate timestamped graphs
DATE=$(date +%Y-%m-%d)
just dep-graph
mv docs/architecture/Setup-Mac-Darwin.svg \
   "docs/architecture/Setup-Mac-Darwin-$DATE.svg"

# Compare versions
# Look for dependency creep
# Identify optimization opportunities
```

### 3. Use Graphs for Documentation

```bash
# Include in architecture documentation
![System Dependencies](../architecture/Setup-Mac-Darwin.png)

# Add to status reports
## Current System State
- Packages: 471
- Dependencies: 1,233
- Depth: 19
```

### 4. Analyze Before Optimization

```bash
# Before optimization
just dep-graph
# Note current stats (nodes, edges, depth)

# Make changes
# (add/remove packages)

# After optimization
just dep-graph
# Compare stats
# Verify improvements
```

## Future Enhancements

### Planned Improvements

1. **Graph Filtering**
   - Filter by package category
   - Exclude transitive dependencies
   - Focus on user packages only

2. **Interactive Viewing**
   - Zoom and pan capabilities
   - Click for package details
   - Search functionality

3. **Comparison Views**
   - Before/after comparison
   - Platform comparison (Darwin vs NixOS)
   - Time-lapse view

4. **Performance Metrics**
   - Build time estimation
   - Store size analysis
   - Dependency cost calculation

## References

- **nix-visualize Repository:** https://github.com/craigmbooth/nix-visualize
- **Matplotlib Documentation:** https://matplotlib.org/
- **Graphviz Documentation:** https://graphviz.org/documentation/
- **Setup-Mac Architecture:** `docs/nix-call-graph.md`

## Changelog

### 2026-01-12 - Initial Integration

- Added nix-visualize as flake input
- Created comprehensive justfile commands
- Generated initial dependency graphs
- Created integration documentation

---

**Last Updated:** 2026-01-12
**Maintainer:** Lars Artmann
**Status:** ✅ Production Ready
