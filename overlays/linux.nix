{
  dnsblockd,
  emeet-pixyd,
  monitor365,
  file-and-image-renamer,
  crush-daily,
  overview,
  ...
}:
let
  openaudibleOverlay = _final: prev: {
    openaudible = prev.callPackage ../pkgs/openaudible.nix { };
  };

  netwatchOverlay = _final: prev: {
    netwatch = prev.callPackage ../pkgs/netwatch.nix { };
  };

  # Pocket ID v2.10.0 — Francis actor framework for background jobs (PR #1556).
  # Fixes "lock ownership lost" crash under I/O stalls. See GitHub issues #1274, #1356.
  pocketIdUpgradeOverlay =
    _final: prev:
    let
      newVersion = "2.10.0";
      newSrc = prev.fetchFromGitHub {
        owner = "pocket-id";
        repo = "pocket-id";
        tag = "v${newVersion}";
        hash = "sha256-ad8YlWwWeGEwsrx29qpq1asEr4UNN7BueGTBPfFrRuE=";
      };
    in
    {
      pocket-id = prev.pocket-id.overrideAttrs (old: {
        version = newVersion;
        src = newSrc;
        vendorHash = "sha256-bQNeocRCmhiV7gwCJppjsNw7K5MnsJMK9M18jf0X/oM=";
        postPatch = ''
          sed -i 's/^go 1\.26\.[0-9]\+/go 1.26.4/' go.mod
        '';
        frontend = old.frontend.overrideAttrs {
          version = newVersion;
          src = newSrc;
          pnpmDeps = prev.fetchPnpmDeps {
            pname = "pocket-id";
            version = newVersion;
            src = newSrc;
            pnpm = prev.pnpm_10;
            fetcherVersion = 3;
            hash = "sha256-DwTvEf/t/DyMRANp4YJUVv97hzyU//tJaovzhTGbzWw=";
          };
        };
      });
    };

  # utoipa-swagger-ui build script PermissionDenied fix.
  #
  # Root cause: Rust's std::fs::copy propagates permissions from the source
  # file to the destination. Nix store files are mode 0444 (read-only) after
  # fixup — chmod in a builder is futile. Crane's buildDepsOnly runs
  # `cargo check --release` THEN `cargo build --release`. During `check`, the
  # utoipa-swagger-ui build script copies the swagger-ui zip from the nix store
  # to OUT_DIR — the copy inherits 0444. During `build`, the script re-runs and
  # fs::copy tries to truncate the existing 0444 file → EACCES.
  #
  # Fix: override the deps buildPhase to delete swagger-ui zip copies between
  # `cargo check` and `cargo build`, so the second run creates the file fresh.
  monitor365SwaggerUiFixOverlay =
    final: prev:
    let
      cleanSwaggerZips = ''
        # Remove swagger-ui zip copies left by `cargo check` to prevent
        # PermissionDenied when `cargo build` re-runs the build script.
        find target -path '*/utoipa-swagger-ui-*/out/*.zip' -delete 2>/dev/null || true
      '';
    in
    {
      monitor365 = prev.monitor365.overrideAttrs (old: {
        cargoArtifacts = old.cargoArtifacts.overrideAttrs (_: {
          buildPhase = ''
            runHook preBuild
            cargo --version
            cargoWithProfile check --locked
            ${cleanSwaggerZips}
            cargoWithProfile build --locked
            runHook postBuild
          '';
        });
      });

      # Rebuild monitor365-server with the fixed CLI.
      # The upstream symlinkJoin bakes in the original (unfixed) monitor365-cli.
      monitor365-server = final.symlinkJoin {
        name = prev.monitor365-server.name;
        paths = [
          final.monitor365
          prev.monitor365-ui
        ];
        nativeBuildInputs = [ final.makeWrapper ];
        postBuild = ''
          mkdir -p $out/share/monitor365/ui
          cp -r ${prev.monitor365-ui}/* $out/share/monitor365/ui/
          wrapProgram $out/bin/monitor365-server \
            --set-default UI_DIST_PATH "$out/share/monitor365/ui"
        '';
      };
    };
in
[
  openaudibleOverlay
  dnsblockd.overlays.default
  emeet-pixyd.overlays.default
  monitor365.overlays.default
  monitor365SwaggerUiFixOverlay
  netwatchOverlay
  file-and-image-renamer.overlays.default
  crush-daily.overlays.default
  overview.overlays.default
  pocketIdUpgradeOverlay
]
