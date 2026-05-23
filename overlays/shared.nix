{
  todo-list-ai,
  library-policy,
  golangci-lint-auto-configure,
  mr-sync,
  hierarchical-errors,
  buildflow,
  go-auto-upgrade,
  go-structure-linter,
  branching-flow,
  art-dupl,
  projects-management-automation,
  mkPackageOverlay,
  ...
}: let
  awWatcherOverlay = _final: prev: {
    aw-watcher-utilization = prev.callPackage ../pkgs/aw-watcher-utilization.nix {};
  };

  # aw-webui jest tests fail with missing vue-template-compiler.
  # The aw-webui package is not a top-level nixpkgs attribute — it's defined
  # inside pkgs/applications/office/activitywatch/default.nix and passed to
  # aw-server-rust via AW_WEBUI_DIR. We can't easily override it via overlays.
  # Instead, override activitywatch to skip the broken npm test phase.
  activitywatchOverlay = final: prev: let
    awPkgs = prev.qt6Packages.callPackage (prev.path + "/pkgs/applications/office/activitywatch/default.nix") {
      buildNpmPackage = args: prev.buildNpmPackage (args // {doCheck = false;});
    };
  in {
    aw-server-rust = awPkgs.aw-server-rust;
    activitywatch = prev.activitywatch.override {
      aw-server-rust = final.aw-server-rust;
    };
  };

  jscpdOverlay = _final: prev: {
    jscpd = prev.callPackage ../pkgs/jscpd.nix {};
  };

  govalidOverlay = _final: prev: {
    govalid = prev.callPackage ../pkgs/govalid.nix {};
  };

  todoListAiFixedHash = "sha256-iBUuLvpAI2p3OW0OvDEiwJEgNDITzqzsphQvzK0YJvw=";

  todoListAiOverlay = _final: prev: let
    bun = prev.bun;
    upstream = todo-list-ai.packages.${prev.stdenv.system}.default;
    patchedDeps = prev.stdenv.mkDerivation {
      name = "todo-list-ai-deps";
      src = upstream.src;
      nativeBuildInputs = [bun];
      buildPhase = "bun install";
      installPhase = "rm -rf node_modules/.cache && cp -r node_modules $out";
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = todoListAiFixedHash;
      dontFixup = true;
    };
  in {
    todo-list-ai = upstream.overrideAttrs (_: {
      buildPhase = ''
        runHook preBuild
        cp -r ${patchedDeps} node_modules
        chmod -R u+w node_modules
        find node_modules -type f -exec grep -q '^#!/usr/bin/env node' {} \; -print0 \
          | xargs -0 -r sed -i '1s|^#!/usr/bin/env node|#!${bun}/bin/bun|'
        patchShebangs node_modules/.bin

        bun build ./index.ts --compile --outfile ./dist/todo-list-ai
        runHook postBuild
      '';
    });
  };

  d2DarwinOverlay = _final: prev:
    prev.lib.optionalAttrs prev.stdenv.isDarwin {
      d2 = prev.callPackage (prev.path + "/pkgs/by-name/d2/d2/package.nix") {
        libgbm = prev.runCommand "libgbm-stub" {} "mkdir $out";
        playwright-driver = {browsers = prev.runCommand "playwright-stub" {} "mkdir $out";};
      };
    };
in [
  awWatcherOverlay
  activitywatchOverlay
  todoListAiOverlay
  jscpdOverlay
  govalidOverlay
  (mkPackageOverlay library-policy "library-policy" {})
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {vendorHash = "sha256-Q9i+2iW0reClN+R9VUHYWoLMPoyGUXDXy4SeWkxKq20=";})
  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {})
  (mkPackageOverlay mr-sync "mr-sync" {vendorHash = "sha256-K/dPpkbgJQOctBxphuqndErswaNA7puubhT21JJ5Y0A=";})
  (mkPackageOverlay buildflow "buildflow" {vendorHash = "sha256-Jsi00lElQE9bu2EOuAwIdZFT5V7vCzxzARQSP5xV95I=";})
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {})
  (mkPackageOverlay go-structure-linter "go-structure-linter" {vendorHash = "sha256-BfHABJAHErFY8slMYjeYPPRzs9LGnVy+HOjBLI50hMk=";})
  (mkPackageOverlay branching-flow "branching-flow" {})
  (mkPackageOverlay art-dupl "art-dupl" {})
  (mkPackageOverlay projects-management-automation "projects-management-automation" {vendorHash = "sha256-wiGmT6ibqaR1afYday12whPQXU1hTwbndA8nPpMCER0=";})
  d2DarwinOverlay
]
