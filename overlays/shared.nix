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
  jscpdOverlay
  govalidOverlay
  (mkPackageOverlay library-policy "library-policy" {vendorHash = "sha256-MH4E5+SpDPSGBaRE23Ez+qjRAgkEMs4/Y/FUT6sXz3U=";})
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {vendorHash = "sha256-oerBC3M2vcec6dD4tdi3e7ZwqUGwFTNykrbPQSyceEg=";})
  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {vendorHash = "sha256-MMVy22Zx0ui4LCYxGe3bbu1lz7ODolYeef1eq/xrG5Y=";})
  (mkPackageOverlay mr-sync "mr-sync" {})
  (mkPackageOverlay buildflow "buildflow" {})
  # buildflow — Zero-configuration build automation
  # go-structure-linter is required by buildflow but missing from the prepared source's go.sum.
  # We override goModules to patch go.sum before `go mod vendor` runs (in preBuild).
  (let
    buildflowOverrideOverlay = final: prev: {
      buildflow =
        let
          base = prev.buildflow;
          # Hardcoded h1 hashes for go-structure-linter and its sub-modules.
          # These modules are in go.mod but missing from go.sum, causing
          # `go mod vendor` to fail with "missing go.sum entry" during buildPhase.
          patch-go-sum = ''
            set -x
            if ! grep -q "github.com/LarsArtmann/go-structure-linter v0.1.0" go.sum 2>/dev/null; then
              echo "PATCH: Adding go-structure-linter entries to go.sum"
              echo "github.com/LarsArtmann/go-structure-linter v0.1.0 h1:609b8c640752944e5f862ee32d958eb6a040a74d2b42f5b948758b09dfa6b4df" >> go.sum
              echo "github.com/LarsArtmann/go-structure-linter v0.1.0/go.mod h1:1b84a9790fa0fb0a32e052d7e522e5dcc804c96528153b8dfa69c1b2d54db14a" >> go.sum
              echo "github.com/LarsArtmann/go-structure-linter/modules/checks v0.0.0 h1:08e54b8988e7aed4b7fd24d4bea4fed1dfb2b5d8820c2cd7bb256323c07843ca" >> go.sum
              echo "github.com/LarsArtmann/go-structure-linter/modules/checks v0.0.0/go.mod h1:6d86bfa2f469163ba707025c6b1d26aa3be95295044610b9e3a2a26a9e1c4298" >> go.sum
              echo "github.com/LarsArtmann/go-structure-linter/modules/errorkit v0.0.0-20260530170432-2f005b1d93d8 h1:5013decde05bddaa29cb91b37641cbbe4324acb1ad9689d1f6c7cf26a7adbb3e" >> go.sum
              echo "github.com/LarsArtmann/go-structure-linter/modules/errorkit v0.0.0-20260530170432-2f005b1d93d8/go.mod h1:f404ae1a83afac30226e696fc7c0d31f100eadeb0e642a888bf39981d633cfbf" >> go.sum
              echo "github.com/LarsArtmann/go-structure-linter/modules/types v0.0.0 h1:7bc0838c7747e07eb24d3c137524463d6b95d6ccd97d8f720af66ef943d1e5eb" >> go.sum
              echo "github.com/LarsArtmann/go-structure-linter/modules/types v0.0.0/go.mod h1:33b0ad69d4ab53988ebcdcef0b26ef888de8cc19f081bd6dea43ae6d907a7688" >> go.sum
              echo "github.com/LarsArtmann/go-structure-linter/modules/utils v0.0.0-20260530170432-2f005b1d93d8 h1:530ea1e946231dce3c12faf768adee74fedd3453e56db3ce94ab1b17bec3d44d" >> go.sum
              echo "github.com/LarsArtmann/go-structure-linter/modules/utils v0.0.0-20260530170432-2f005b1d93d8/go.mod h1:116579e9251fb4e728f2b5e822be946acde9b7be1b7f363336f2ea5892dabc76" >> go.sum
            else
              echo "PATCH: go-structure-linter already in go.sum"
            fi
            set +x
          '';
        in
          base.overrideAttrs (_old: {
            goModules = base.goModules.overrideAttrs (old: {
              preBuild = (old.preBuild or "") + "\n" + patch-go-sum + ''
              # GONOSUMDB and GOPRIVATE allow go mod to work with private repos without checksum DB
              export GONOSUMDB="github.com/LarsArtmann/*"
              export GOPRIVATE="github.com/LarsArtmann/*"
              # Point go mod to use the pre-built go-structure-linter from the environment
              export GOPATH="${prev.go-structure-linter}/share/go-structure-linter:$GOPATH"
              # Create a local replace directive for go-structure-linter
              if ! grep -q "replace.*go-structure-linter.*=>" go.mod 2>/dev/null; then
                echo "replace github.com/LarsArtmann/go-structure-linter => ${prev.go-structure-linter}/share/go-structure-linter" >> go.mod
              fi
            '';
              vendorHash = null;
            });
          });
    };
  in buildflowOverrideOverlay)
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {vendorHash = "sha256-WwiJCOCEOggCIeqL930SxtirurrNO8rT8vuKLFZvEgU=";})
  (mkPackageOverlay go-structure-linter "go-structure-linter" {vendorHash = "sha256-PrcJm4ZgMOMgxFF2C5bBF997b9upQBE5I+0EtSTWvTw=";})
  (mkPackageOverlay branching-flow "branching-flow" {vendorHash = "sha256-eL+rRV9nTzMod+U1vzMnMtbrl6GLEHOP2E1DJTKkbZk=";})
  (mkPackageOverlay art-dupl "art-dupl" {})
  (mkPackageOverlay projects-management-automation "projects-management-automation" {})
  (mkPackageOverlay todo-list-ai "todo-list-ai" {})
  d2DarwinOverlay
]
