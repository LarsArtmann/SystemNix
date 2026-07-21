# Custom Packages

Custom Nix package definitions used across SystemNix. All packages are built via overlays in `flake.nix` and exposed as flake outputs.

## Packages

| Package                                           | Language | Platform | Description                              |
| ------------------------------------------------- | -------- | -------- | ---------------------------------------- |
| [jscpd](#jscpd)                                   | Node.js  | All      | Copy/paste detector for source code      |
| [qmd](#qmd)                                       | Node.js  | All      | On-device markdown hybrid search engine  |
| [govalid](#govalid)                               | Go       | All      | Go validation code generator             |
| [aw-watcher-utilization](#aw-watcher-utilization) | Python   | All      | ActivityWatch system utilization watcher |
| [netwatch](#netwatch)                             | Rust     | Linux    | Real-time network diagnostics TUI        |
| [openaudible](#openaudible)                       | AppImage | Linux    | Audible audiobook manager                |

> **Note:** The following tools are provided via upstream flake input overlays — no local package file needed:
> dnsblockd, emeet-pixyd, monitor365, file-and-image-renamer, golangci-lint-auto-configure,
> mr-sync, hierarchical-errors, library-policy, buildflow, go-auto-upgrade, go-structure-linter,
> branching-flow, art-dupl, todo-list-ai.

---

### govalid

Go validation code generator — generates type-safe validators from struct tags.

- **Source:** `govalid.nix` (Go, fetched from GitHub)
- **Platform:** All platforms

### jscpd

Copy/paste detector for programming source code — finds duplicated code across 150+ languages. Used in the project devShell.

- **Source:** `jscpd.nix` (pnpm package, vendored lockfile in `jscpd-pnpm-lock.yaml`)
- **Platform:** All platforms
- **Install:** Available in devShell via `nix develop`

### qmd

Query Markup Documents — on-device hybrid search engine for markdown notes. Combines SQLite FTS5 (BM25), vector embeddings via node-llama-cpp, and LLM reranking — all local, no API keys. Exposes both a CLI (`qmd search`, `qmd query`, `qmd get`) and an MCP server (stdio + HTTP).

- **Source:** `qmd.nix` (GitHub source + `pnpmConfigHook`, builds `dist/` from TypeScript)
- **Platform:** All platforms (x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin)
- **CLI:** Installed system-wide via `base.nix` — `qmd --help` after deploy
- **Service:** `modules/nixos/services/qmd-config.nix` runs `qmd mcp --http` as a user systemd service on `127.0.0.1:8181`. Connect MCP clients to `http://localhost:8181/mcp`. CPU-only by default.
- **Index:** `~/.cache/qmd/index.sqlite` (FTS5 + sqlite-vec vectors). Models cached in `~/.cache/qmd/models/`.

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
