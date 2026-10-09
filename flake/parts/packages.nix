# perSystem packages — mkLarsPackages (LarsArtmann Go tools, single source of
# truth in lib/lars-packages.nix) + nixpkgs picks + Linux-only source builds.
# Split out of flake.nix 2026-10-08.
{
  inputs,
  root,
  mkLarsPackages,
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
      packages =
        (mkLarsPackages system)
        // {
          inherit (pkgs)
            aw-watcher-utilization
            govalid
            jscpd
            sqlc
            systemd-timer-monitor
            ;

          # Third-party source build (tag-pinned input, see
          # inputs.paperless-gpt-src). The paperless-gpt module
          # callPackages the SAME file with the same src → identical store
          # path on both surfaces. Lives in the isLinux block below: the
          # package meta pins platforms to x86_64-linux and the module is
          # NixOS-only — an unconditional exposure trips the meta.platforms
          # assert on the darwin `flake check --all-systems` leg.

          # Pre-deploy batch build (Pareto T17/F65): ONE command
          # surfaces every stale vendorHash / FOD breakage in the
          # LarsArtmann Go set BEFORE `nix run .#deploy` pays for a
          # full toplevel build mid-switch — the domino-deploy class
          # (2026-08-27: four sequential switch attempts, each dying
          # at the next FOD; --keep-going enumerates, this PREVENTS).
          # NOT included: bank-sync (rides the bank-sync home-manager
          # module import in systems/evo-x2.nix, not mkLarsPackages;
          # the old vendorHash-override exclusion reason died with the
          # override itself, dropped 2026-09-03 — the daemon build is
          # exercised by every `nixos-rebuild switch`), monitor365 (its
          # wireguard-collector git dep is a PRIVATE crate that 404s on
          # anonymous fetch — the documented reason the service is
          # disabled since 2026-08-12; a permanent red, not drift —
          # first quick-go run proved exactly this), cv (built with its
          # real module-level package by checks.x86_64-linux.cv), hermes
          # (Python/uv2nix, not a vendorHash class).
          quick-go = pkgs.symlinkJoin {
            name = "quick-go-batch";
            paths =
              (builtins.attrValues (mkLarsPackages system))
              ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
                pkgs.dnsblockd
                pkgs.emeet-pixyd
                pkgs.file-and-image-renamer
                pkgs.crush-daily
              ];
          };
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          # monitor365 REMOVED 2026-09-15: nix flake check derivationStrict's
          # every package, and monitor365's prepared source is permanently
          # unbuildable (private wireguard-collector crate — the 2026-08-12
          # disable reason). The entry only ever passed via a stale
          # store-cached drv; the first input bump after cache eviction
          # hard-blocked every deploy at pre-deploy check 1.
          inherit (pkgs)
            openaudible
            openseo
            dnsblockd
            netwatch
            systemd-graph
            systemd-graph-webui
            emeet-pixyd
            file-and-image-renamer
            crush-daily
            fastflowlm
            ;
          paperless-gpt = pkgs.callPackage (root + "/pkgs/paperless-gpt.nix") {
            src = inputs.paperless-gpt-src;
          };
          freebsd-zfs-vm = import (root + "/pkgs/freebsd-zfs-vm.nix") { inherit pkgs; };
          # Native GeoMetrikks (uv2nix + bun frontend; the Docker→native
          # migration pilot — see docs/planning/2026-09-29_*GEOMETRIKKS*).
          # The service module builds its own instance from the same file;
          # exposed here for `nix build .#geometrikks` FOD/dep-drift
          # probing (the quick-go doctrine for non-vendorHash packages).
          geometrikks = import (root + "/pkgs/geometrikks.nix") {
            inherit pkgs lib;
            inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
          };
        };

    };
}
