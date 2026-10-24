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
          # exercised by every `nixos-rebuild switch`), monitor365 (master-
          # tracking heavy Rust workspace — kept out of the Go-focused
          # batch after the 2026-10-18 service re-enable: the toplevel
          # build/§11 dry-run surfaces its FODs at deploy time; a full
          # Rust rebuild inside every pre-deploy batch is freeze-class
          # build load, not early signal), cv (built with its
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
          # monitor365 back on the surface 2026-10-18 — the 2026-09-15
          # removal premise ("prepared source permanently unbuildable,
          # private wireguard-collector crate") is obsolete: upstream
          # restructured to the preparedSrc pattern (family crates as flake
          # inputs fetched OUTSIDE the sandbox), locked here since
          # 2026-10-16 (d2c77df8c). Still excluded from quick-go (see
          # comment above).
          inherit (pkgs)
            monitor365
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
          # ai-meter — in-tree Go source (pkgs/ai-meter/), stdlib only,
          # vendorHash = null forever (no FOD, no toolchain-skew re-hash
          # waves). Same callPackage + src on the module side → identical
          # store path.
          ai-meter = pkgs.callPackage (root + "/pkgs/ai-meter.nix") {
            src = lib.sources.cleanSource (root + "/pkgs/ai-meter");
          };
          # gatus-alert-relay — in-tree Go source (pkgs/gatus-alert-relay/),
          # stdlib only, vendorHash = null forever (ai-meter doctrine).
          # Gates gatus' Discord webhook: boot grace, SEV1 parent-incident
          # mute, flap collapse, re-arm guard (T-007, 2026-10-24).
          gatusAlertRelay = pkgs.callPackage (root + "/pkgs/gatus-alert-relay.nix") {
            src = lib.sources.cleanSource (root + "/pkgs/gatus-alert-relay");
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
