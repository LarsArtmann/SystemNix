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

  art-duplOverlay = _final: prev: let
    pkg = art-dupl.packages.${prev.stdenv.system}.default or null;
  in
    if pkg == null
    then {}
    else {
      art-dupl = pkg.overrideAttrs (old: {
        vendorHash = "sha256-HSgFUbQEOScJqVG8/J9JRwJtgjFtWfCdli8b7VcdYVY=";
        preBuild =
          old.preBuild
          + ''
            mkdir -p vendor/github.com/a-h/templ/runtime
            cp -r ${prev.templ.src}/runtime/. vendor/github.com/a-h/templ/runtime/
            sed -i '/^github.com\/a-h\/templ\/safehtml$/a github.com/a-h/templ/runtime' vendor/modules.txt
          '';
      });
    };
in [
  awWatcherOverlay
  activitywatchOverlay
  jscpdOverlay
  govalidOverlay
  (mkPackageOverlay library-policy "library-policy" {vendorHash = "sha256-8/Yn3hoW/GHgq+bUxxTlGVi6pjChw6Unq/baluyrj04=";})
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {vendorHash = "sha256-GqKxPN8k9jJO31fw21zC+h2hsUS++0phpHXmyO/e3V0=";})
  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {vendorHash = "sha256-LCz14+53dif4m6fq8I11hHkKwSueYKnjVjTl4EUQUl0=";})
  (mkPackageOverlay mr-sync "mr-sync" {vendorHash = "sha256-1+kYoA90tD+DSuoiHFBE+jyprPo4IWuiaOIMHcOYSNU=";})
  (mkPackageOverlay buildflow "buildflow" {vendorHash = "sha256-C2GLGX7b/zJ9Ss9zo1Umm6LVlWuHk9raXK6Zd8xbcY0=";})
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {vendorHash = "sha256-EhKRJczms0gw0JniX+TFBanwIt0muK+PX0WMUk0EHxE=";})
  (mkPackageOverlay go-structure-linter "go-structure-linter" {vendorHash = "sha256-eKUG52pOYWW131NMpfA+yLMpayovvJUXs38Hwa08Fsk=";})
  (mkPackageOverlay branching-flow "branching-flow" {vendorHash = "sha256-BGKYeWl9rxBDvZYOW5/IbMQRxv2toaxexmJm4iMKsic=";})
  art-duplOverlay
  (mkPackageOverlay projects-management-automation "projects-management-automation" {})
  (mkPackageOverlay project-meta "project-meta" {})
  (mkPackageOverlay todo-list-ai "todo-list-ai" {})
  d2DarwinOverlay
]
