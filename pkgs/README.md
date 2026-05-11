# Custom Packages

Custom Nix package definitions used across SystemNix. All packages are built via overlays in `flake.nix` and exposed as flake outputs.

## Packages

| Package | Language | Platform | Description |
|---------|----------|----------|-------------|
| [modernize](#modernize) | Go | All | Go code modernize linter |
| [jscpd](#jscpd) | Node.js | All | Copy/paste detector for source code |
| [aw-watcher-utilization](#aw-watcher-utilization) | Python | All | ActivityWatch system utilization watcher |
| [netwatch](#netwatch) | Rust | Linux | Real-time network diagnostics TUI |
| [openaudible](#openaudible) | AppImage | Linux | Audible audiobook manager |

> **Note:** The following tools are provided via upstream flake input overlays — no local package file needed:
> dnsblockd, emeet-pixyd, monitor365, file-and-image-renamer, golangci-lint-auto-configure,
> mr-sync, hierarchical-errors, library-policy, buildflow, go-auto-upgrade, go-structure-linter,
> branching-flow, art-dupl, todo-list-ai.

---

### modernize

Builds the `modernize` analysis pass from `golang.org/x/tools` with Go 1.26. Detects Go code that can use newer language features.

- **Source:** `modernize.nix` (fetches from `golang/tools` repo)
- **Platform:** All platforms
- **Install:** Available as `nix build .#modernize`

### jscpd

Copy/paste detector for programming source code — finds duplicated code across 150+ languages. Used in the project devShell.

- **Source:** `jscpd.nix` (npm package, vendored lockfile in `jscpd-package-lock.json`)
- **Platform:** All platforms
- **Install:** Available in devShell via `nix develop`

### aw-watcher-utilization

Monitors CPU, RAM, disk, network, and sensor usage, reporting to ActivityWatch. Fork build from [Alwinator/aw-watcher-utilization](https://github.com/Alwinator/aw-watcher-utilization) with modernized poetry build.

- **Source:** `aw-watcher-utilization.nix` (Python, fetched from GitHub)
- **Platform:** All platforms
- **Config:** `platforms/darwin/services/launchagents.nix` (macOS LaunchAgent)

### netwatch

Real-time network diagnostics TUI built in Rust. Shows connectivity, latency, DNS resolution, and port status.

- **Source:** `netwatch.nix` (Rust, fetched from nixpkgs)
- **Platform:** Linux only

### openaudible

Desktop application for managing Audible audiobooks. Wrapped AppImage.

- **Source:** `openaudible.nix` (AppImage, unfree)
- **Platform:** Linux only (x86_64)
- **Install:** Included in `platforms/common/packages/base.nix` for Linux

## Adding a New Package

1. Create `pkgs/<name>.nix` (or `pkgs/<name>/` directory with `package.nix`)
2. Add an overlay in `flake.nix` (follow existing patterns)
3. Add to the `packages` attrset in the `perSystem` block
4. Add to the appropriate overlay list (shared or Linux-only)
