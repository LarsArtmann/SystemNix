{
  dnsblockd,
  emeet-pixyd,
  monitor365,
  file-and-image-renamer,
  crush-daily,
  overview,
  ...
}: let
  openaudibleOverlay = _final: prev: {
    openaudible = prev.callPackage ../pkgs/openaudible.nix {};
  };

  netwatchOverlay = _final: prev: {
    netwatch = prev.callPackage ../pkgs/netwatch.nix {};
  };

  # Pocket ID v2.10.0 — Francis actor framework for background jobs (PR #1556).
  # Fixes "lock ownership lost" crash under I/O stalls. See GitHub issues #1274, #1356.
  pocketIdUpgradeOverlay = _final: prev: let
    newVersion = "2.10.0";
    newSrc = prev.fetchFromGitHub {
      owner = "pocket-id";
      repo = "pocket-id";
      tag = "v${newVersion}";
      hash = "sha256-ad8YlWwWeGEwsrx29qpq1asEr4UNN7BueGTBPfFrRuE=";
    };
  in {
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
in [
  openaudibleOverlay
  dnsblockd.overlays.default
  emeet-pixyd.overlays.default
  monitor365.overlays.default
  netwatchOverlay
  file-and-image-renamer.overlays.default
  crush-daily.overlays.default
  overview.overlays.default
  pocketIdUpgradeOverlay
]
