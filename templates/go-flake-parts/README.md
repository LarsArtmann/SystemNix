# Go Flake-Parts Template

Standardized `flake.nix` for LarsArtmann Go projects using the Nix ecosystem stack.

## Usage

1. Copy `flake.nix` into your Go repo root
2. Replace all `REPLACE_ME` placeholders with your project name
3. Set `vendorHash = ""` and run `nix build` to get the correct hash
4. Uncomment private dep inputs + `mkPreparedSource` as needed

## Placeholders

| Placeholder | What to put |
|---|---|
| `REPLACE_ME` | Repo name (e.g. `go-auto-upgrade`) |
| `REPLACE_ME/internal/appversion` | Your version package import path |
| `cmd/REPLACE_ME` | Path to your main package |
| `vendorHash` | Leave as `""` for first build |

## Stack

- `flake-parts` — modular flake composition
- `treefmt-nix` — unified formatting (gofumpt, goimports, nixfmt)
- `buildGoModule` — Nix Go builds
- `go-nix-helpers` — private dependency injection

## Standard Outputs

| Output | What |
|---|---|
| `packages.default` | The compiled binary |
| `apps.default` | `nix run` support |
| `apps.test` | `go test -race -v ./...` |
| `apps.lint` | `golangci-lint run ./...` |
| `devShells.default` | Full dev shell (go, gopls, linter) |
| `devShells.ci` | Minimal CI shell |
| `checks.build` | Build verification |
| `checks.format` | Format verification |
| `overlays.default` | Makes package available as `pkgs.<name>` |
