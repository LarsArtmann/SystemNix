# perSystem devShells. Split out of flake.nix 2026-10-08.
{
  inputs,
  mkLarsPackages,
  root,
  ...
}:
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
          # Battery-class admission gate (2026-10-28 §7.1b, stability plan
          # M3/F16): a `nix` wrapper FIRST on PATH refuses build/shell/
          # develop/run/flake-check while the guard recently tripped or PSI
          # is in the storm band (deploy.sh's pressure doctrine at the
          # typing layer — the freezes #14-#33 battery class). Owner login
          # shells never include this PATH prefix => owner unaffected by
          # construction. Escape: ADMISSION_GATE_FORCE=1 (audit-logged).
          shellHook = ''
            export PATH="${
              pkgs.runCommand "nix-admission-gate" { } ''
                install -Dm555 ${root}/scripts/nix-admission-gate.sh $out/bin/nix
              ''
            }/bin:$PATH"
          '';
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
