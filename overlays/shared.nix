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
  project-meta,
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


  buildflowOverlay = _final: prev: let
    pkg = buildflow.packages.${prev.stdenv.system}.default or null;
  in
    if pkg == null
    then {}
    else {
      buildflow = pkg.overrideAttrs (old: {
        vendorHash = "sha256-3yDIdB2xCIKgfQ+SqwH0FCj2s5feiZhI2NuKufdPMEI=";
        preBuild =
          (old.preBuild or "")
          + ''
            chmod -R u+w vendor
            go mod edit -require dario.cat/mergo@v1.0.2
            go mod edit -require github.com/Microsoft/go-winio@v0.6.2
            go mod edit -require github.com/ProtonMail/go-crypto@v1.4.1
            go mod edit -require github.com/cloudflare/circl@v1.6.3
            go mod edit -require github.com/cyphar/filepath-securejoin@v0.6.1
            go mod edit -require github.com/emirpasic/gods@v1.18.1
            go mod edit -require github.com/go-git/gcfg@v1.5.1-0.20230307220236-3a3c6141e376
            go mod edit -require github.com/go-git/go-billy/v5@v5.9.0
            go mod edit -require github.com/go-git/go-git/v5@v5.19.1
            go mod edit -require github.com/golang/groupcache@v0.0.0-20241129210726-2c02b8208cf8
            go mod edit -require github.com/jbenet/go-context@v0.0.0-20150711004518-d14ea06fba99
            go mod edit -require github.com/kevinburke/ssh_config@v1.6.0
            go mod edit -require github.com/klauspost/cpuid/v2@v2.3.0
            go mod edit -require github.com/pjbgf/sha1cd@v0.6.0
            go mod edit -require github.com/skeema/knownhosts@v1.3.2
            go mod edit -require github.com/xanzy/ssh-agent@v0.3.3
            go mod edit -require golang.org/x/crypto@v0.52.0
            go mod edit -require gopkg.in/warnings.v0@v0.1.2
            sed -i 's/dario.cat\/mergo v1.0.2$/dario.cat\/mergo v1.0.2 \/\/ indirect/' go.mod
            sed -i 's/github.com\/Microsoft\/go-winio v0.6.2$/github.com\/Microsoft\/go-winio v0.6.2 \/\/ indirect/' go.mod
            sed -i 's/github.com\/ProtonMail\/go-crypto v1.4.1$/github.com\/ProtonMail\/go-crypto v1.4.1 \/\/ indirect/' go.mod
            sed -i 's/github.com\/cloudflare\/circl v1.6.3$/github.com\/cloudflare\/circl v1.6.3 \/\/ indirect/' go.mod
            sed -i 's/github.com\/cyphar\/filepath-securejoin v0.6.1$/github.com\/cyphar\/filepath-securejoin v0.6.1 \/\/ indirect/' go.mod
            sed -i 's/github.com\/emirpasic\/gods v1.18.1$/github.com\/emirpasic\/gods v1.18.1 \/\/ indirect/' go.mod
            sed -i 's/github.com\/go-git\/gcfg v1.5.1-0.20230307220236-3a3c6141e376$/github.com\/go-git\/gcfg v1.5.1-0.20230307220236-3a3c6141e376 \/\/ indirect/' go.mod
            sed -i 's/github.com\/go-git\/go-billy\/v5 v5.9.0$/github.com\/go-git\/go-billy\/v5 v5.9.0 \/\/ indirect/' go.mod
            sed -i 's/github.com\/go-git\/go-git\/v5 v5.19.1$/github.com\/go-git\/go-git\/v5 v5.19.1 \/\/ indirect/' go.mod
            sed -i 's/github.com\/golang\/groupcache v0.0.0-20241129210726-2c02b8208cf8$/github.com\/golang\/groupcache v0.0.0-20241129210726-2c02b8208cf8 \/\/ indirect/' go.mod
            sed -i 's/github.com\/jbenet\/go-context v0.0.0-20150711004518-d14ea06fba99$/github.com\/jbenet\/go-context v0.0.0-20150711004518-d14ea06fba99 \/\/ indirect/' go.mod
            sed -i 's/github.com\/kevinburke\/ssh_config v1.6.0$/github.com\/kevinburke\/ssh_config v1.6.0 \/\/ indirect/' go.mod
            sed -i 's/github.com\/klauspost\/cpuid\/v2 v2.3.0$/github.com\/klauspost\/cpuid\/v2 v2.3.0 \/\/ indirect/' go.mod
            sed -i 's/github.com\/pjbgf\/sha1cd v0.6.0$/github.com\/pjbgf\/sha1cd v0.6.0 \/\/ indirect/' go.mod
            sed -i 's/github.com\/skeema\/knownhosts v1.3.2$/github.com\/skeema\/knownhosts v1.3.2 \/\/ indirect/' go.mod
            sed -i 's/github.com\/xanzy\/ssh-agent v0.3.3$/github.com\/xanzy\/ssh-agent v0.3.3 \/\/ indirect/' go.mod
            sed -i 's/golang.org\/x\/crypto v0.52.0$/golang.org\/x\/crypto v0.52.0 \/\/ indirect/' go.mod
            sed -i 's/gopkg.in\/warnings.v0 v0.1.2$/gopkg.in\/warnings.v0 v0.1.2 \/\/ indirect/' go.mod
          '';
      });
    };

  projectMetaOverlay = _final: prev: let
    pkg = project-meta.packages.${prev.stdenv.system}.default or null;
  in
    if pkg == null
    then {}
    else {
      project-meta = pkg.overrideAttrs (old: {
        preBuild =
          (old.preBuild or "")
          + ''
            chmod -R u+w vendor
            sed -i 's|github.com/charmbracelet/x/exp/charmtone v0.0.0-20260607010151-cd19a2bba55f|github.com/charmbracelet/x/exp/charmtone v0.0.0-20260602025833-85a30b5e440a|' go.mod
          '';
      });
    };
in [
  awWatcherOverlay
  activitywatchOverlay
  jscpdOverlay
  govalidOverlay
  (mkPackageOverlay library-policy "library-policy" {vendorHash = "sha256-h5wkT10v14GEnN7RBtWqKTXRMsX6+Qj0AanE4dOSz8U=";})
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {})

  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {vendorHash = "sha256-Wiu9zbLx9ukznrzlJg4oumHA/Qx3Bh6xLPfwe4MEjgQ=";})
  (mkPackageOverlay mr-sync "mr-sync" {vendorHash = "sha256-6WcsIlYdwo4IvlddwHs8Df2v6f5RpWpXkCkCJHg5qF4=";})
  buildflowOverlay
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {vendorHash = "sha256-bTdDHFF4wKpsfcEmnHzphXG/JsfTo2z6wy80+zNUR7w=";})
  (mkPackageOverlay go-structure-linter "go-structure-linter" {vendorHash = "sha256-Bt0ZxNcvDg31AtFE6Xm/kryUC9OOqtoBbQfsE3sB8Ks=";})
  (mkPackageOverlay branching-flow "branching-flow" {vendorHash = "sha256-bv1wRqBTEYThsNp7uTF41FbqoZ/Uq3yrgcn/REFmfRE=";})
  (mkPackageOverlay art-dupl "art-dupl" {vendorHash = "sha256-p8mldrn+sJYbpswh29zdEfxsqdBunwOmhWX+vTPZh1U=";})
  projectMetaOverlay
  (mkPackageOverlay projects-management-automation "projects-management-automation" {})
  (mkPackageOverlay todo-list-ai "todo-list-ai" {})
  d2DarwinOverlay
]
