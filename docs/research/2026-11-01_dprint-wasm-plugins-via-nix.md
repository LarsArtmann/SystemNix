# dprint WASM plugins via Nix — mechanics & decision support

**Date:** 2026-11-01
**Subject:** How to install `dprint` and resolve its `.wasm` plugins hermetically through Nix, without network at format time.
**Trigger context:** the repo root carries a fully-configured `dprint.json` (json, g-plane/pretty_yaml, markdown, dockerfile plugins) that NOTHING runs — no pre-commit leg, no treefmt program, no CI step, no `dprint` in `devShells.default`. The wire-or-delete decision is open in `docs/todo/pipeline.md` ("Wire `dprint.json` into something, or delete it"); the devShell absence is a separate row ("Add the 9 dep-less BuildFlow tools to devShells.default"). This doc records the verified upstream mechanics either outcome needs.

## Verified upstream facts

Checked 2026-11-01 via a sourcegraph pull of `dprint/dprint` (website docs + CLI source) and `numtide/treefmt-nix`. Cite the upstream files, not this doc, when the details matter.

| Claim                                                                                                                                                                                                                                                                                                            | Source                                                                                                           |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| The `plugins` array accepts **npm specifiers, URLs, or file paths** to a WebAssembly file                                                                                                                                                                                                                        | `website/src/config.md` ("These may be npm specifiers, URLs, or file paths to a WebAssembly file of the plugin") |
| Relative file paths resolve against the **config file's directory** (walking up, for the `./node_modules/...` form)                                                                                                                                                                                              | `website/src/config.md` npm section                                                                              |
| `--plugins <url-or-path>...` CLI flag **overrides** the config file                                                                                                                                                                                                                                              | `crates/dprint/src/arg_parser.rs`, `website/src/config.md`                                                       |
| Plugin/config cache dir: `~/.cache/dprint` (Linux) by default; `DPRINT_CACHE_DIR` overrides it and **must be an absolute path**; the CLI **may periodically delete** that directory                                                                                                                              | `website/src/setup.md`, `crates/dprint/src/environment/real_environment.rs`                                      |
| **No lockfile exists.** A sourcegraph search for `.lock` across the dprint docs returns zero matches; determinism comes from version-pinned plugin URLs plus dprint's own `@<sha256>` checksum suffixes. Do not wait for or fabricate a `dprint.json.lock`                                                       | sourcegraph `repo:dprint/dprint lang:markdown "\.lock"` → 0 results                                              |
| Exit code **13** = no plugins found; **14** = no files found (suppressible with `--allow-no-files`, dprint ≥ 0.43)                                                                                                                                                                                               | `website/src/cli.md` exit-codes table                                                                            |
| treefmt-nix ships `programs.dprint` (`programs/dprint.nix`): it **generates** a `dprint.json` from `settings.*` and passes it via `--config`; its own docs note URL-based plugins work **only outside the nix sandbox**, so `nix flake check` fails with them — the recommended form is nixpkgs-packaged plugins | `numtide/treefmt-nix/programs/dprint.nix` example block                                                          |

## Two Nix routes for the plugins

### Route 1 — nixpkgs-packaged plugins (treefmt-nix recommended form)

`pkgs.dprint-plugins.getPluginList` materializes every packaged dprint plugin as a store path and emits the absolute-path plugin list:

```nix
(pkgs.dprint-plugins.getPluginList (
  plugins: with plugins; [
    dprint-plugin-json
    dprint-plugin-markdown
    dprint-plugin-dockerfile
    g-plane-pretty_yaml
  ]
))
```

- Sandbox-safe (no network): survives `nix flake check` / `checks.formatting` and VM-style evaluation.
- Version is owned by the pinned nixpkgs revision — plugin upgrades ride flake-lock floats, not hand edits.
- **Probe before wiring:** confirm the pinned nixpkgs actually carries all four variants (`nix eval --raw nixpkgs#dprint-plugins.getPluginList` against the same set, or list `nix eval nixpkgs#dprint-plugins.plugins --apply 'p: builtins.attrNames p'`). The treefmt-nix example only demonstrates toml/dockerfile/pretty_yaml.

### Route 2 — `fetchurl` per plugin (exact-version control)

```nix
let
  dprint-plugin-json = pkgs.fetchurl {
    url = "https://plugins.dprint.dev/json-0.23.0.wasm";
    hash = "sha256-<nix-prefetch-url once>";
  };
in
  # dprint.json plugins array = absolute store paths
  [ dprint-plugin-json dprint-plugin-markdown dprint-plugin-dockerfile dprint-plugin-pretty-yaml ]
```

- Also sandbox-safe; no network at format time, and integrity moves from dprint's `@<sha256>` URL suffix to the Nix hash.
- Plugin bumps become explicit flake edits (URL version + re-prefetch) — the right shape for a formatter that should move slowly.
- Note: the repo's current `dprint.json` URLs carry **no** `@checksum` suffixes. That is valid (dprint's own plugin test harness runs no-checksum configs) but unpinned; Route 2 restores pinning via the Nix hash regardless.

### Cache note (both routes)

When plugins come from store paths, dprint never downloads, but the incremental-formatting cache still wants a writable dir. In devShells the default `~/.cache/dprint` is fine; in a `runCommand`/sandbox context set `DPRINT_CACHE_DIR` to a writable absolute path (relative values are rejected with an explicit error).

## Wiring options against repo doctrine

One style arbiter per repo is doctrine; the pinned treefmt formatter (`nix fmt`, `flake/parts/formatter.nix`) is the only wired arbiter here.

- **A. treefmt wraps dprint (the wire outcome).** `programs.dprint.enable = true` in `flake/parts/formatter.nix` with `settings.plugins` from Route 1 or 2, `settings.excludes` mirroring the root file (`vendor/**`, `.git/**`, `node_modules/**`, `**/CHANGELOG.md`). treefmt-nix generates its own config file, so the root `dprint.json` must then be deleted (or treefmt pointed at it explicitly) — two live dprint configs would be the same split brain the dms-paste repo hit (see `docs/status/2026-10-17_01-59_dms-paste-extraction-status-self-review.md` §10.1). Payoff: markdown tables and YAML in `modules/` get a real gate; `nix fmt` stays the single entry point.
- **B. devShell-only.** `dprint` in `devShells.default` with pinned plugins; nothing gates. Cheapest, but leaves the "declared standard no gate enforces" problem.
- **C. Delete `dprint.json`.** If dprint is not adopted, the file stops implying an enforced standard.

**Churn constraint (either wire shape):** the first dprint pass over ~1,900 files is a style-churn diff this repo already rejected once for alejandra (2026-10-14, `platforms/common/packages/base.nix` incident, AGENTS.md Build & Deploy). Scope the rollout: land formatting as one dedicated commit, or start with `settings.includes` limited to markdown/YAML, before opening it to the whole tree.

## Historical exit-14 context

The bank-sync BuildFlow hook bug (2026-08-18) was exactly exit code 14: `dprint fmt <staged files>` with no staged file matching any plugin exits 14 and fails the hook; fixed upstream-side by `--allow-no-files` (dprint ≥ 0.43). Any wiring here that formats a staged subset must pass that flag or handle empty match sets. Narratives: `docs/status/archived/2026-08-18_21-15_papdashboard-discord-rendering-fix-and-btrfs-critical.md`, `docs/status/archived/2026-08-19_15-43_wise-sca-deployed-sigpipe-smoke-fix-self-review.md`.

## Refresh trigger

dprint major bump, the wire-or-delete decision landing, or a treefmt-nix change to `programs.dprint`.
