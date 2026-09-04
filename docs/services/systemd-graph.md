# systemd-graph

Live systemd dependency graph web UI at `https://graph.home.lan`.

## Overview

D-Bus-driven systemd dependency graph visualizer. The Go backend queries
systemd via D-Bus for all units, their dependencies, and relationships, then
serves a React SPA (Cytoscape.js) that renders the full dependency graph
interactively.

- **Upstream**: [icholy/systemd-graph](https://github.com/icholy/systemd-graph)
- **Port**: 8847 (localhost only, proxied via Caddy)
- **Auth**: None (LAN-only, read-only public systemd data)
- **State**: None (DynamicUser, no persistent state)

## Architecture

- **Go backend** (`cmd/server`): queries D-Bus `org.freedesktop.systemd1`
  for all units + dependencies, serves `/api/snapshot` (JSON) and static
  SPA files (embedded via `//go:embed dist`)
- **React SPA** (`webui/`): Vite + Cytoscape.js + TanStack React Virtual
  for rendering the graph
- **Package**: `pkgs/systemd-graph/` — separate webui derivation (pnpm +
  Vite build) injected into Go source via `runCommand` re-pack

## Nix Build Notes

- **`pnpmConfigHook` runs in the configure phase** — `dontConfigure = true`
  silently skips it, leaving `node_modules` empty and breaking the build.
  Let the hook handle `pnpm install` (offline, frozen-lockfile, pnpm 11
  `trust_lockfile`).
- **`buildGoModule` names binaries after the source dir** —
  `subPackages = ["cmd/server"]` produces `$out/bin/server`, not
  `$out/bin/systemd-graph`. Fixed with `postInstall = 'mv $out/bin/server
  $out/bin/systemd-graph'`.
- **`fetchPnpmDeps` doesn't honor `sourceRoot`** — for pnpm in a
  subdirectory, pass `src = "${finalAttrs.src}/webui"` to `fetchPnpmDeps`.

## Module Options

| Option          | Default                      | Description        |
| --------------- | ---------------------------- | ------------------ |
| `enable`        | `false`                      | Enable the service |
| `package`       | `pkgs.systemd-graph`         | Package override   |
| `port`          | `ports.systemd-graph` (8847) | Listen port        |
| `listenAddress` | `127.0.0.1`                  | Bind address       |

## Service Details

- **Type**: `simple` (DynamicUser)
- **MemoryMax**: 128M
- **I/O tier**: `background`
- **After**: `dbus.service`, `network-online.target`
- **restartTriggers**: `[ cfg.package ]` (restarts on package update)
