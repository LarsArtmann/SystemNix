{
  dnsblockd,
  emeet-pixyd,
  monitor365,
  file-and-image-renamer,
  crush-daily,
  bank-sync,
  overview,
  discordsync,
  ...
}:
let
  openaudibleOverlay = _final: prev: {
    openaudible = prev.callPackage ../pkgs/openaudible.nix { };
  };

  netwatchOverlay = _final: prev: {
    netwatch = prev.callPackage ../pkgs/netwatch.nix { };
  };

  # print-safe: Canon MG2500 black/white-safe printing (host-coupled: rides
  # the system CUPS filters + PPD). Replaces the hand-installed
  # ~/.local/bin/print-safe (nixified 2026-09-16).
  printSafeOverlay = _final: prev: {
    print-safe = prev.callPackage ../pkgs/print-safe.nix { };
  };

  systemdGraphOverlay = _final: prev: {
    systemd-graph-webui = prev.callPackage ../pkgs/systemd-graph/webui.nix { };
    systemd-graph = prev.callPackage ../pkgs/systemd-graph { };
  };

  # niri-flake's make-niri pins libdisplay-info_0_2 via callPackage.
  # nixpkgs removed the libdisplay-info_0_2 alias (throws).
  # niri's Cargo.lock now uses libdisplay-info-sys 0.3.0 Rust crate,
  # whose build script requires the C library to report < 0.4.0 via pkg-config.
  # The real C library is 0.4.0 (backward compatible — APIs are only added, never removed).
  # This shim: (1) sets derivation version=0.2.0 to pass niri-flake's stale assert,
  # and (2) patches the .pc file to report 0.3.0 so libdisplay-info-sys's pkg-config
  # constraint passes. Remove when niri-flake drops the libdisplay-info_0_2 pinning.
  niriLibdisplayInfoShim = _final: prev: {
    libdisplay-info_0_2 = prev.libdisplay-info.overrideAttrs (old: {
      version = "0.2.0";
      __intentionallyOverridingVersion = true;
      postFixup = (old.postFixup or "") + ''
        for pc in $out/lib/pkgconfig/libdisplay-info*.pc; do
          sed -i 's/^Version: [0-9.]\+$/Version: 0.3.0/' "$pc"
        done
      '';
    });
  };

  bunMemoryLimitOverlay = _final: prev: {
    bun = prev.writeShellApplication {
      name = "bun";
      runtimeInputs = [ prev.systemd ];
      text = ''
        REAL_BUN="${prev.bun}/bin/bun"
        if [ -z "''${XDG_RUNTIME_DIR:-}" ] || ! [ -S "''${XDG_RUNTIME_DIR}/systemd/private" ]; then
          exec "$REAL_BUN" "$@"
        fi
        exec systemd-run --user --quiet --scope --collect \
          -p MemoryMax=8G \
          -p MemorySwapMax=0 \
          ${prev.bash}/bin/bash -c 'echo 1000 > /proc/self/oom_score_adj 2>/dev/null; exec "$@"' _ "$REAL_BUN" "$@"
      '';
    };
  };

  # utoipa-swagger-ui build script PermissionDenied fix + libspa SPA_ID_INVALID fix.
  #
  # Root cause (swagger-ui): Rust's std::fs::copy propagates permissions from
  # the source file to the destination. Nix store files are mode 0444 (read-only)
  # after fixup — chmod in a builder is futile. Crane's buildDepsOnly runs
  # `cargo check --release` THEN `cargo build --release`. During `check`, the
  # utoipa-swagger-ui build script copies the swagger-ui zip from the nix store
  # to OUT_DIR — the copy inherits 0444. During `build`, the script re-runs and
  # fs::copy tries to truncate the existing 0444 file → EACCES.
  #
  # Fix (swagger-ui): override the deps buildPhase to delete swagger-ui zip copies
  # between `cargo check` and `cargo build`, so the second run creates the file fresh.
  #
  # Root cause (libspa): libspa-sys generates FFI bindings from system PipeWire
  # headers via bindgen. SPA_ID_INVALID is a C macro `((uint32_t)0xffffffff)` that
  # bindgen cannot evaluate (it involves a C cast). The constant is silently absent
  # from the generated bindings → `spa_sys::SPA_ID_INVALID` fails to compile.
  #
  # Fix (libspa): patch the vendored libspa crate to hardcode the constant value.
  monitor365SwaggerUiFixOverlay =
    final: prev:
    let
      cleanSwaggerZips = ''
        # Remove swagger-ui zip copies left by `cargo check` to prevent
        # PermissionDenied when `cargo build` re-runs the build script.
        find target -path '*/utoipa-swagger-ui-*/out/*.zip' -delete 2>/dev/null || true
      '';
      fixLibSpaIdInvalid = ''
        # libspa-sys generates FFI bindings from system PipeWire headers via bindgen.
        # SPA_ID_INVALID is a C macro ((uint32_t)0xffffffff) that bindgen cannot
        # evaluate (involves a C cast), so the constant is silently absent from
        # the generated bindings → spa_sys::SPA_ID_INVALID fails to compile.
        #
        # The vendored crates are in a read-only nix store FOD. We create a new
        # vendor dir that symlinks all original crates EXCEPT libspa, which gets
        # a real patched directory. We also update .cargo-checksum.json to skip
        # checksum verification for the patched crate.

        # Find the cargo config.toml
        CARGO_CFG="''${CARGO_HOME:-$PWD/.cargo-home}/config.toml"
        if [ ! -f "$CARGO_CFG" ]; then
          CARGO_CFG="$NIX_BUILD_TOP/source/.cargo-home/config.toml"
        fi
        ORIG_VENDOR_DIR=$(sed -n 's/^directory = "\([^"]*\)".*/\1/p' "$CARGO_CFG" | head -1)

        if [ -n "$ORIG_VENDOR_DIR" ] && [ -d "$ORIG_VENDOR_DIR" ]; then
          PATCHED_DIR="$NIX_BUILD_TOP/vendor-patched"
          rm -rf "$PATCHED_DIR"
          mkdir -p "$PATCHED_DIR"

          # Symlink all original crate dirs
          for entry in "$ORIG_VENDOR_DIR"/*; do
            ln -s "$entry" "$PATCHED_DIR/$(basename "$entry")"
          done

          # Replace libspa symlink with a patched real directory
          LIBSPA_DIR="$ORIG_VENDOR_DIR/libspa-0.10.0"
          if [ -d "$LIBSPA_DIR" ]; then
            rm "$PATCHED_DIR/libspa-0.10.0"
            mkdir -p "$PATCHED_DIR/libspa-0.10.0/src"
            # Symlink src files except constants.rs
            for f in "$LIBSPA_DIR"/src/*; do
              fname=$(basename "$f")
              if [ "$fname" = "constants.rs" ]; then
                sed 's/spa_sys::SPA_ID_INVALID/0xFFFFFFFFu32/g' "$f" > "$PATCHED_DIR/libspa-0.10.0/src/constants.rs"
              else
                ln -s "$f" "$PATCHED_DIR/libspa-0.10.0/src/$fname"
              fi
            done
            # Symlink non-src entries
            for entry in "$LIBSPA_DIR"/*; do
              name=$(basename "$entry")
              if [ "$name" != "src" ]; then
                ln -s "$entry" "$PATCHED_DIR/libspa-0.10.0/$name"
              fi
            done
            # Preserve original package checksum but disable file-level verification
            ORIG_PKG=$(grep -o '"package":"[^"]*"' "$LIBSPA_DIR/.cargo-checksum.json" | head -1 | cut -d'"' -f4)
            echo "{\"files\":{},\"package\":\"$ORIG_PKG\"}" > "$PATCHED_DIR/libspa-0.10.0/.cargo-checksum.json"
          fi

          # Replace pipewire symlink with a patched real directory
          PIPEWIRE_DIR="$ORIG_VENDOR_DIR/pipewire-0.10.0"
          if [ -d "$PIPEWIRE_DIR" ]; then
            rm "$PATCHED_DIR/pipewire-0.10.0"
            mkdir -p "$PATCHED_DIR/pipewire-0.10.0/src"
            for f in "$PIPEWIRE_DIR"/src/*; do
              fname=$(basename "$f")
              if [ "$fname" = "constants.rs" ]; then
                sed 's/pw_sys::PW_ID_ANY/0xFFFFFFFFu32/g' "$f" > "$PATCHED_DIR/pipewire-0.10.0/src/constants.rs"
              else
                ln -s "$f" "$PATCHED_DIR/pipewire-0.10.0/src/$fname"
              fi
            done
            for entry in "$PIPEWIRE_DIR"/*; do
              name=$(basename "$entry")
              if [ "$name" != "src" ]; then
                ln -s "$entry" "$PATCHED_DIR/pipewire-0.10.0/$name"
              fi
            done
            ORIG_PKG=$(grep -o '"package":"[^"]*"' "$PIPEWIRE_DIR/.cargo-checksum.json" | head -1 | cut -d'"' -f4)
            echo "{\"files\":{},\"package\":\"$ORIG_PKG\"}" > "$PATCHED_DIR/pipewire-0.10.0/.cargo-checksum.json"
          fi

          # Update config.toml to point to patched vendor dir
          substituteInPlace "$CARGO_CFG" --replace-fail "$ORIG_VENDOR_DIR" "$PATCHED_DIR"
        fi
      '';
    in
    {
      monitor365 = prev.monitor365.overrideAttrs (old: {
        # Replace upstream preBuild entirely — it tries to sed -i on read-only
        # Nix store vendor files (libspa-sys), which fails with Permission denied.
        # Our fixLibSpaIdInvalid handles all patching via writable symlinked dirs.
        preBuild = fixLibSpaIdInvalid + cleanSwaggerZips;
        cargoArtifacts = old.cargoArtifacts.overrideAttrs (_: {
          buildPhase = ''
            ${fixLibSpaIdInvalid}
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
  # TEMPORARY vendorHash shim (RE-PINNED 2026-10-03): the 2026-10-01 nixpkgs
  # bump (c59305b) re-vendored under go 1.26.8; the 2026-10-01 value
  # (W5e+pMcB…) no longer reproduces at locked rev 0bd519b (got
  # xoPCvuTn…; evo-x2 toplevel --keep-going enumeration evidence; class
  # comment at lib/lars-packages.nix). Upstream master is ahead; drop when
  # the lock moves past an upstream-fixed rev. Must stay
  # AFTER file-and-image-renamer.overlays.default in the list below.
  # prev (NOT final) — final would recurse into this overlay's own override.
  fileAndImageRenamerVendorHashShim = _final: prev: {
    file-and-image-renamer = prev.file-and-image-renamer.overrideAttrs {
      vendorHash = "sha256-xoPCvuTnR0qNmezn6Kxl899Tpi66kha2GCcJOWDnl0k=";
    };
  };
  # TEMPORARY vendorHash shims (2026-10-03, class comment at
  # lib/lars-packages.nix): overview (got gaRXLohu… at rev 25dd08e) and
  # discordsync (got /d/40ffY… at rev 1c20710) — 2026-10-01 nixpkgs bump
  # go-1.26.8 toolchain drift. prev (NOT final) — same recursion guard as
  # above; stay AFTER the respective upstream overlays in the list below.
  # Drop when upstreams re-pin or the lock moves past upstream-fixed revs.
  overviewVendorHashShim = _final: prev: {
    overview = prev.overview.overrideAttrs {
      vendorHash = "sha256-gaRXLohuCBTdVN5oCBk+0uzR33u6nD/mjM5vykjcFMA=";
    };
  };
  discordsyncVendorHashShim = _final: prev: {
    discordsync = prev.discordsync.overrideAttrs {
      vendorHash = "sha256-/d/40ffYAzSF9MUbK0RnMaJFvg+vnFDYWwvGZxhZvTc=";
    };
  };
  # TEMPORARY version pin (2026-10-03): nixpkgs 7a0f122f (the 2026-10-01
  # lock) produced clickhouse 26.8.7.19 with a derivation that is ALREADY
  # built in the local store; the 2026-10-02 bump (c59305ba) changed the
  # derivation (same version string) and cache.nixos.org does not carry
  # clickhouse, forcing a ~1.5 h from-source build on every deploy until
  # nixpkgs lands a cached rebuild. Importing that exact rev reproduces the
  # cached derivation bit-for-bit, so this pin costs ZERO builds. Drop when
  # current nixpkgs' clickhouse derivation matches a published binary cache
  # entry (check: nix eval nixpkgs#clickhouse.drvPath vs the pinned drv).
  clickhouseVersionPinOverlay = _final: prev: {
    clickhouse =
      (import
        (builtins.fetchTarball {
          url = "https://github.com/NixOS/nixpkgs/archive/7a0f122f5090cf4c2ade2a13a0e229d4e19ba71f.tar.gz";
          sha256 = "sha256-ZoxIApko70jCdbH3l20HWXOBaT2HZd87orzd2yJ9dVE=";
        })
        {
          system = prev.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        }
      ).clickhouse;
  };
in
[
  clickhouseVersionPinOverlay
  niriLibdisplayInfoShim
  openaudibleOverlay
  dnsblockd.overlays.default
  emeet-pixyd.overlays.default
  monitor365.overlays.default
  monitor365SwaggerUiFixOverlay
  netwatchOverlay
  file-and-image-renamer.overlays.default
  fileAndImageRenamerVendorHashShim
  crush-daily.overlays.default
  bank-sync.overlays.default
  overview.overlays.default
  overviewVendorHashShim
  discordsync.overlays.default
  discordsyncVendorHashShim
  bunMemoryLimitOverlay
  systemdGraphOverlay
  printSafeOverlay
]
