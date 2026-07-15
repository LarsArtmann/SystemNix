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

  # monitor365's upstream .cargo/config.toml mandates -fuse-ld=mold for native
  # targets (devShell convenience), but the regular package build doesn't include
  # mold in nativeBuildInputs. Without this, gcc's collect2 fails with
  # "cannot find 'ld'" when linking native cdylib crates like wasm-streams.
  # We must patch BOTH the CLI and the server (which is a symlinkJoin wrapping
  # the CLI) because the upstream overlay bakes the unpatched CLI into the server.
  monitor365MoldFixOverlay = final: prev: {
    monitor365 = prev.monitor365.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.mold ];
    });
    monitor365-server = final.symlinkJoin {
      name = prev.monitor365-server.name;
      paths = [ final.monitor365 prev.monitor365-ui ];
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
  monitor365MoldFixOverlay
  netwatchOverlay
  file-and-image-renamer.overlays.default
  crush-daily.overlays.default
  overview.overlays.default
  pocketIdUpgradeOverlay
]
