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
  todoListAiOverlay
  jscpdOverlay
  govalidOverlay
  # library-policy: disabled — go.mod has local replace directive for go-finding that breaks Nix sandbox
  # (mkPackageOverlay library-policy "library-policy" {})
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {vendorHash = "sha256-Q9i+2iW0reClN+R9VUHYWoLMPoyGUXDXy4SeWkxKq20=";})
  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {})
  (mkPackageOverlay mr-sync "mr-sync" {vendorHash = "sha256-K/dPpkbgJQOctBxphuqndErswaNA7puubhT21JJ5Y0A=";})
  # buildflow: disabled — upstream compilation error (syntax error in migrator.go)
  # (mkPackageOverlay buildflow "buildflow" {vendorHash = "sha256-ChZeHvlRg6Y4meeO+5FiECI0szH6FnW4rmc7o36sZUA=";})
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {})
  # go-structure-linter: disabled — inconsistent vendoring (missing go-branded-id in _local_deps)
  # (mkPackageOverlay go-structure-linter "go-structure-linter" {vendorHash = "sha256-crYOyOJkQkJaAlg4z0xHAkzr39E4VczkqPPETLpnCf0=";})
  (mkPackageOverlay branching-flow "branching-flow" {})
  (mkPackageOverlay art-dupl "art-dupl" {})
  # projects-management-automation: disabled — missing branching-flow/pkg/stats in _local_deps
  # (mkPackageOverlay projects-management-automation "projects-management-automation" {vendorHash = "sha256-ma/7D1sUaAERTi/t/1d+syp7oHxSH5VamjHUIUWIJbk=";})
  d2DarwinOverlay
]
