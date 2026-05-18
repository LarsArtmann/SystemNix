# Reusable `mkPreparedSource` helper for private Go repo overlays
#
# Problem: Go repos with private dependencies can't fetch them inside the Nix
# sandbox (no SSH, no network for go mod download). Solution: fetch deps as
# flake inputs, copy them into _local_deps/, add `replace` directives to go.mod.
#
# Usage in a flake.nix:
#   let
#     mkPreparedSource = import path/to/mkPreparedSource.nix { inherit pkgs lib goPkg; };
#     preparedSrc = mkPreparedSource {
#       name = "my-app";
#       src = srcFiltered;  # or ./.
#       deps = {
#         "github.com/larsartmann/go-output" = go-output;
#         "github.com/larsartmann/go-branded-id" = go-branded-id;
#       };
#       subModules = [ "enum" "escape" "sort" "table" ];  # for go-output sub-modules
#       postPatchExtra = ''
#         # Additional sed commands, e.g. remove incompatible deps
#       '';
#     };
#   in
#   buildGoModule { src = preparedSrc; vendorHash = "..."; }
#
# Parameters:
#   - name: derivation name prefix
#   - src: source derivation/path
#   - deps: attrset of { "import/path" = flake-input; }
#   - subModules: list of sub-module names (optional)
#   - postPatchExtra: additional shell commands (optional)
{
  pkgs,
  lib,
  goPkg,
}: {
  name,
  src,
  deps,
  subModules ? [],
  postPatchExtra ? "",
}: let
  # Generate copy commands for each dep
  copyDeps =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (
        path: _: let
          basename = lib.last (lib.splitString "/" path);
        in ''cp -r ${deps.${path}} _local_deps/${basename}''
      )
      deps);

  # Generate replace directives for each dep
  replaceLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (
        path: _: let
          basename = lib.last (lib.splitString "/" path);
        in ''echo "  ${path} => ./_local_deps/${basename}" >> go.mod''
      )
      deps);

  # Generate sub-module replace directives
  subModuleLines =
    lib.concatStringsSep "\n"
    (map (
        sub:
          lib.concatStringsSep "\n"
          (lib.mapAttrsToList (
              path: _: let
                basename = lib.last (lib.splitString "/" path);
              in ''echo "  ${path}/${sub} => ./_local_deps/${basename}/${sub}" >> go.mod''
            )
            deps)
      )
      subModules);
in
  pkgs.stdenv.mkDerivation {
    pname = "${name}-prepared-source";
    version = "dev";
    inherit src;

    dontBuild = true;
    nativeBuildInputs = [goPkg];

    postPatch = ''
      mkdir -p _local_deps
      ${copyDeps}
      chmod -R u+w _local_deps

      ${postPatchExtra}

      # Add replace directives for all private deps
      if [ -n "$(cat go.mod | tr -d '\\n')" ]; then
        echo "" >> go.mod
      fi
      echo 'replace (' >> go.mod
      ${replaceLines}
      ${subModuleLines}
      echo ')' >> go.mod
    '';

    installPhase = ''
      mkdir $out
      cp -r . $out/
    '';
  }
