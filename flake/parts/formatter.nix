# perSystem formatter — treefmt-full-flake's treefmt with ONE local patch.
# Split out of flake.nix 2026-10-08 (flake/parts convention: see
# docs/agents/nix-flakes.md). `inputs` comes from the flake-parts top-level
# module args (mkFlake specialArgs); perSystem bodies close over it lexically
# exactly as they did in the flake.nix outputs scope.
{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      # Formatter: treefmt-full-flake's treefmt with ONE local patch —
      # generated HTML report bundles under docs/ are NEVER formatted
      # (docs/CONTRIBUTING.md "Big self-contained HTML reports": the inline mermaid
      # JS is generated content; prettier expands the 3.6 MB bundle to
      # 7.8 MB and that churn has oscillated the blob in git history
      # repeatedly — 2026-09-20 and 2026-09-21). The upstream wrapper
      # bakes its --config-file store path; the config text is
      # regenerated with the excludes added and the formatter programs
      # and their versions stay untouched.
      formatter =
        let
          upstream = inputs.treefmt-full-flake.formatter.${system};
          # The wrapper's --config-file path is extracted in the BUILDER,
          # never at eval: reading "${upstream}/bin/treefmt" at eval forces
          # realization of the treefmt package during EVERY flake check,
          # and after nixpkgs churn invalidates the drv the eval dies
          # `path '...treefmt.drv' is not valid` (the niri-class
          # package-output-coercion gotcha; dead pre-commit gate
          # 2026-09-24..25). A failed extraction fails the BUILD loudly.
          patchedConfig = pkgs.runCommand "treefmt-systemnix-excludes.toml" { } ''
            wrapper="${upstream}/bin/treefmt"
            configLine="$(grep -m1 -- '--config-file=' "$wrapper" || true)"
            case "$configLine" in
              *--config-file=*) ;;
              *)
                echo "treefmt-full-flake wrapper no longer carries --config-file; rework the formatter override in flake/parts/formatter.nix" >&2
                exit 1
                ;;
            esac
            upstreamConfig="$(printf '%s\n' "$configLine" | sed -n 's/.*--config-file=\([^[:space:]]\+\).*/\1/p')"
            substitute "$upstreamConfig" "$out" \
              --replace 'excludes = ["*.lock"' 'excludes = [
            "docs/**/*.html",
            "*.lock"'
          '';
        in
        pkgs.writeShellScriptBin "treefmt" ''
          exec ${upstream}/bin/treefmt --config-file=${patchedConfig} --tree-root-file=flake.nix "$@"
        '';
    };
}
