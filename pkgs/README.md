# Custom Packages

Custom Nix package definitions used across SystemNix. All packages are built via overlays in `flake.nix` and exposed as flake outputs.

## Packages

| Package | Language | Platform | Description |
|---------|----------|----------|-------------|
| [dnsblockd](#dnsblockd) | Go | Linux | DNS block page HTTP server |
| [modernize](#modernize) | Go | All | Go code modernize linter |
| [jscpd](#jscpd) | Node.js | All | Copy/paste detector for source code |
| [aw-watcher-utilization](#aw-watcher-utilization) | Python | All | ActivityWatch system utilization watcher |
| [monitor365](#monitor365) | Rust | Linux | Personal device monitoring agent |
| [netwatch](#netwatch) | Rust | Linux | Real-time network diagnostics TUI |
| [openaudible](#openaudible) | AppImage | Linux | Audible audiobook manager |
| [file-and-image-renamer](#file-and-image-renamer) | Go | Linux | AI-powered screenshot renaming tool |

> **Note:** emeet-pixyd, dnsblockd, golangci-lint-auto-configure, mr-sync, and other tools are provided via upstream flake input overlays — no local package file needed.

---

### dnsblockd

Lightweight HTTP server that serves block pages for DNS-filtered domains. Paired with Unbound DNS resolver to provide visual feedback when a blocked domain is accessed.

- **Source:** `dnsblockd.nix` (derivation) + inline Go source in flake
- **Platform:** Linux only
- **Config:** `platforms/nixos/system/dns-blocker-config.nix`

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

### monitor365

Cross-platform personal device monitoring system agent. Rust CLI that collects system metrics via a plugin architecture. NixOS module available at `modules/nixos/services/monitor365.nix` (currently disabled).

- **Source:** `monitor365.nix` (Rust, source from `monitor365-src` flake input)
- **Platform:** Linux only
- **Builds:** Only the CLI agent binary (`--package monitor365-cli`)

### netwatch

Real-time network diagnostics TUI built in Rust. Shows connectivity, latency, DNS resolution, and port status.

- **Source:** `netwatch.nix` (Rust, fetched from nixpkgs)
- **Platform:** Linux only

### openaudible

Desktop application for managing Audible audiobooks. Wrapped AppImage.

- **Source:** `openaudible.nix` (AppImage, unfree)
- **Platform:** Linux only (x86_64)
- **Install:** Included in `platforms/common/packages/base.nix` for Linux

### file-and-image-renamer

AI-powered screenshot and image renaming tool using GLM-4.6V Vision API.

- **Source:** `file-and-image-renamer.nix` (Go, source from `file-and-image-renamer-src` flake input)
- **Platform:** Linux only
- **Config:** `modules/nixos/services/file-and-image-renamer.nix`

## Adding a New Package

1. Create `pkgs/<name>.nix` (or `pkgs/<name>/` directory with `package.nix`)
2. Add an overlay in `flake.nix` (follow existing patterns)
3. Add to the `packages` attrset in the `perSystem` block
4. Add to the appropriate overlay list (shared or Linux-only)
