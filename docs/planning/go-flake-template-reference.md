# LarsArtmann Go Flake Template

Reference template for all Go projects. Uses flake-parts + standard env vars + sibling-dep helper.

## flake.nix

```nix
{
  description = "<PROJECT_NAME> — <ONE LINE DESCRIPTION>";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ADD sibling deps as flake inputs (SSH URL, flake = false):
    # go-finding = {
    #   url = "git+ssh://git@github.com/LarsArtmann/go-finding?ref=master";
    #   flake = false;
    # };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];

      imports = [
        ./nix/packages
        ./nix/checks
        ./nix/apps
        ./nix/devshells
        inputs.treefmt-nix.flakeModule
      ];

      perSystem = {config, ...}: {
        treefmt.config = {
          projectRootFile = "flake.nix";
          programs = {
            gofumpt.enable = true;
            alejandra.enable = true;
          };
        };
        formatter = config.treefmt.build.wrapper;
      };
    };
}
```

## nix/packages/default.nix

```nix
{...}: {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    version = "0.0.0-unstable";
    goPkg = pkgs.go_1_26;
    buildGoModule = pkgs.buildGoModule.override {go = goPkg;};

    # Standard env vars for ALL Go builds
    goEnv = {
      CGO_ENABLED = "0";
      GOWORK = "off";
    };

    # Sibling dep helper: append replace directives to go.mod
    # Usage: addSiblingReplaces [ "go-finding" "go-output" ]
    addSiblingReplaces = names: let
      lines = map (name: "echo 'replace github.com/larsartmann/${name} => ./_local_deps/${name}' >> go.mod") names;
    in
      lib.concatStringsSep "\n" lines;

    # Copy sibling deps into _local_deps/ and wire go.mod replaces
    # Usage: injectSiblingDeps { go-finding = inputs.go-finding; }
    injectSiblingDeps = deps: ''
      mkdir -p _local_deps
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: src: ''
          cp -r ${src} _local_deps/${name}
          chmod -R u+w _local_deps/${name}
        '')
        deps
      )}
      ${addSiblingReplaces (lib.attrNames deps)}
    '';
  in {
    packages.default = buildGoModule {
      pname = "<PROJECT_NAME>";
      inherit version;
      src = ./../..;

      vendorHash = "<COMPUTE_WITH_nix_build>";

      subPackages = ["cmd/<PROJECT_NAME>"];

      env = goEnv;

      # Uncomment if project has sibling deps:
      # postPatch = injectSiblingDeps {
      #   go-finding = inputs.go-finding;
      # };

      meta = with lib; {
        description = "<ONE LINE DESCRIPTION>";
        license = licenses.mit;
        mainProgram = "<PROJECT_NAME>";
        platforms = platforms.unix;
      };
    };

    # Overlay for downstream consumption
    flake.overlays.default = _final: prev: {
      <PROJECT_NAME> = self.packages.${prev.stdenv.system}.default;
    };
  };
}
```

## nix/checks/default.nix

```nix
{...}: {
  perSystem = {
    pkgs,
    config,
    ...
  }: let
    pkg = config.packages.default;
  in {
    checks = {
      build = pkg;

      test = pkgs.runCommand "test-check" {
        nativeBuildInputs = with pkgs; [go_1_26];
        src = ./../..;
      } ''
        export HOME=$(mktemp -d)
        export GOMODCACHE=$(mktemp -d)
        export CGO_ENABLED=0
        export GOWORK=off
        cp -r $src/* .
        chmod -R u+w .
        go mod download
        go test -race ./... 2>&1 | tee $out
      '';

      vet = pkgs.runCommand "vet-check" {
        nativeBuildInputs = with pkgs; [go_1_26];
        src = ./../..;
      } ''
        export HOME=$(mktemp -d)
        export GOMODCACHE=$(mktemp -d)
        export CGO_ENABLED=0
        export GOWORK=off
        cp -r $src/* .
        chmod -R u+w .
        go mod download
        go vet ./... 2>&1 | tee $out
      '';

      nix-fmt = pkgs.runCommand "nix-fmt-check" {
        src = ./../..;
        nativeBuildInputs = [pkgs.alejandra];
      } ''
        alejandra --check $src 2>&1 | tee $out
      '';
    };
  };
}
```

## nix/devshells/default.nix

```nix
{...}: {
  perSystem = {pkgs, ...}: {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        go_1_26
        gopls
        gotools
        gofumpt
        golangci-lint
        govulncheck
        just
        git
        ginkgo
      ];

      env = {
        CGO_ENABLED = "0";
        GOWORK = "off";
        GOPRIVATE = "github.com/LarsArtmann";
        GOTOOLCHAIN = "local";
      };

      shellHook = ''
        echo "<PROJECT_NAME> dev shell"
        echo "  Go: $(go version)"
      '';
    };
  };
}
```

## nix/apps/default.nix

```nix
{...}: {
  perSystem = {
    pkgs,
    config,
    ...
  }: {
    apps = {
      default = {
        type = "app";
        program = "${config.packages.default}/bin/<PROJECT_NAME>";
      };
    };
  };
}
```

## Standard Sibling Dep Pattern (art-dupl vendor swap)

For private deps that can't be fetched in the nix sandbox:

1. Add as flake input with `flake = false` and SSH URL
2. In `nix/packages/default.nix`, use `injectSiblingDeps` helper
3. The helper copies sources into `_local_deps/` and appends replace directives to `go.mod`

```nix
# flake.nix inputs
go-finding = {
  url = "git+ssh://git@github.com/LarsArtmann/go-finding?ref=master";
  flake = false;
};

# nix/packages/default.nix
postPatch = injectSiblingDeps {
  go-finding = inputs.go-finding;
};
```

## Checklist for New Projects

- [ ] Create `nix/` directory with 4 files
- [ ] Set `vendorHash` to `pkgs.lib.fakeHash`, run `nix build`, copy real hash from error
- [ ] Add `.envrc` with `use flake`
- [ ] Add `result`, `.direnv/` to `.gitignore`
- [ ] Update `AGENTS.md` with nix commands
- [ ] Add `overlays.default` output
