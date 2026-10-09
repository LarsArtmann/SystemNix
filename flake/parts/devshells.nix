# perSystem devShells. Split out of flake.nix 2026-10-08.
{ inputs, mkLarsPackages, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    {
      # Development shells for different program categories
      devShells = {
        default = pkgs.mkShellNoCC {
          # avatar-dms.png (54K) deliberately NOT excluded: BuildFlow's file-size
          # check scans **/*.go only and no wired provider flags images (source-
          # verified BuildFlow 2026-09-30); the 4MB original keeps a belt exclusion.
          BUILDFLOW_EXCLUDE_PATTERNS = "assets/avatar.png";
          packages =
            with pkgs;
            [
              git
              nixfmt
              alejandra
              treefmt
              deadnix
              shellcheck
              statix
              gitleaks
              jq
              sqlc
            ]
            ++ [
              (mkLarsPackages system).buildflow
            ];
        };
      }
      # Quickshell development — hot-reload QML shell development.
      # Linux-only: dms-shell (DankMaterialShell) is Wayland/Linux-only
      # upstream (meta.platforms), so evaluating this shell on aarch64-
      # darwin dies "not available on the requested hostPlatform" —
      # which plain `nix flake check` on Linux never sees (it silently
      # omits incompatible systems; caught via --all-systems 2026-09-28).
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        quickshell = pkgs.mkShellNoCC {
          packages = [
            inputs.dankMaterialShell.packages.${system}.default
            pkgs.qt6.qtdeclarative
            pkgs.qt6.qttools # provides qmlls (QML LSP)
          ];
        };
      };

    };
}
