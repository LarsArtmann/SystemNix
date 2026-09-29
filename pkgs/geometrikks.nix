{
  pkgs,
  lib,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}:
# GeoMetrikks — access-log geo analytics (github:GilbN/geometrikks), packaged
# from source for services.geometrikks (native Nix replacement of the former
# mkDockerService deployment; see docs/planning/2026-09-29_*GEOMETRIKKS*).
#
# Layout mirrors the upstream Dockerfile's runtime image EXACTLY (that is the
# only proven-good non-source layout):
#   - Python app installed into a uv2nix virtualenv built from uv.lock
#     (wheel-preferred: cryptography/pydantic-core/granian/asyncpg ship
#     manylinux wheels — no native toolchain dance)
#   - $out/share/geometrikks/public/     <- vite build + source-root index.html
#   $out/share/geometrikks/migrations/ + alembic.ini  <- runtime-CWD copies
#   - $out/bin/geometrikks-server / -cli <- litestar CLI wrappers
#
# At runtime the module copies public/, migrations/ and alembic.ini into the
# writable StateDirectory (the app writes .litestar.json + logs there; alembic
# resolves `migrations/` relative to CWD).
#
# UPDATES: bump `version`, refresh the three hashes (src, bunDeps) via the
# got-hash loop, and check upstream CHANGELOG for migration notes.
let
  version = "0.19.0";

  src = pkgs.fetchFromGitHub {
    owner = "GilbN";
    repo = "geometrikks";
    rev = "v${version}";
    hash = "sha256-9aeOeALvSd4kUWM+E+g8yrIY9BkFvkfuHSglfxjJfFo=";
  };

  # ---- Python: uv2nix virtualenv from uv.lock ----
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = src;
  };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  # Legacy sdists that use setuptools' legacy backend without declaring it
  # (uv2nix docs "patching deps" pattern: resolveBuildSystem injection).
  pyprojectOverrides = final: prev: {
    geohash2 = prev.geohash2.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
    });
    ipy = prev.ipy.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
    });
  };

  python = pkgs.python313;

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.wheel
          overlay
          pyprojectOverrides
        ]
      );

  venv = pythonSet.mkVirtualEnv "geometrikks-${version}-env" workspace.deps.default;

  # ---- bun node_modules FOD ----
  # nixpkgs has no buildBunPackage/fetchBunDeps (verified 2026-09-29), so this
  # is the hand-rolled equivalent of qmd-upstream's bun FOD. --ignore-scripts:
  # every platform binary (esbuild/rolldown/oxide) ships as a prebuilt
  # optionalDependency; postinstalls are unnecessary for `bun run build` and a
  # sandbox hazard. Hash covers ONLY node_modules content (bun.lock frozen).
  bunDeps = pkgs.stdenv.mkDerivation {
    name = "geometrikks-${version}-bun-deps";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.bun ];

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      export XDG_CACHE_HOME="$TMPDIR/cache"
      export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"
      cp "${src}/package.json" "${src}/bun.lock" ./
      bun install --frozen-lockfile --ignore-scripts
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      # A fixed-output derivation must not reference store paths. Two classes
      # leak them into a bun-installed node_modules:
      # 1) transitive packages shipping repo flake.lock files with /nix/store
      #    source pins (lodash et al.) — inert for the build, delete them
      # 2) bun rewrites `#!/usr/bin/env X` shebangs of package scripts to the
      #    sandbox-resolved interpreter store path (playwright-core .sh class)
      #    — restore portable env shebangs
      find node_modules -name flake.lock -delete
      while IFS= read -r -d "" f; do
        first="$(head -n 1 "$f" 2>/dev/null || true)"
        case "$first" in
          "#!/nix/store/"*/bin/sh) repl='#!/usr/bin/env sh' ;;
          "#!/nix/store/"*/bin/bash) repl='#!/usr/bin/env bash' ;;
          "#!/nix/store/"*/bin/node) repl='#!/usr/bin/env node' ;;
          *) continue ;;
        esac
        printf '%s\n' "$repl" > "$f.tmp" && tail -n +2 "$f" >> "$f.tmp" && mv "$f.tmp" "$f"
      done < <(find node_modules -type f -print0)
      # Self-test: fail loudly if any store path still remains.
      if grep -a -r -q "/nix/store" node_modules 2>/dev/null; then
        echo "geometrikks-bun-deps: /nix/store references remain after scrub:" >&2
        grep -a -r -l "/nix/store" node_modules 2>/dev/null | head -5 >&2
        exit 1
      fi
      cp -r node_modules "$out"
      runHook postInstall
    '';

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-cshXAV1upoGsuO4M50h/kGBwLHblZQQFt1124nGAXBU=";
  };

  # ---- vite frontend build (upstream Dockerfile frontend-builder stage) ----
  frontend = pkgs.stdenv.mkDerivation {
    name = "geometrikks-${version}-frontend";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.bun ];

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      export XDG_CACHE_HOME="$TMPDIR/cache"
      export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"
      cp -r "${src}/resources" ./resources
      cp "${src}/package.json" "${src}/bun.lock" "${src}/vite.config.ts" "${src}/tsconfig.json" "${src}/components.json" "${src}/index.html" ./
      cp -r "${bunDeps}/node_modules" ./node_modules
      chmod -R u+w ./node_modules ./resources
      bun run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      # Upstream ships the source-root index.html (the SPA shell served at /)
      # as public/index.html — replicate that.
      cp index.html public/index.html
      cp -r public "$out"
      runHook postInstall
    '';
  };
  # ---- wrappers ----
  serverWrapper = pkgs.writeShellScriptBin "geometrikks-server" ''
    exec ${venv}/bin/litestar --app geometrikks.server.core:create_app run \
      --host "''${GEOMETRIKKS_HOST:-127.0.0.1}" \
      --port "''${GEOMETRIKKS_PORT:-8102}" \
      --workers 1 --no-subprocess --workers-kill-timeout 15
  '';

  cliWrapper = pkgs.writeShellScriptBin "geometrikks-cli" ''
    exec ${venv}/bin/litestar --app geometrikks.server.core:create_app "$@"
  '';
in
pkgs.stdenv.mkDerivation {
  pname = "geometrikks";
  inherit version;
  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/geometrikks" "$out/bin"

    cp -r "${frontend}" "$out/share/geometrikks/public"
    cp -r "${src}/migrations" "$out/share/geometrikks/migrations"
    cp "${src}/alembic.ini" "$out/share/geometrikks/alembic.ini"

    cp "${serverWrapper}/bin/geometrikks-server" "$out/bin/geometrikks-server"
    cp "${cliWrapper}/bin/geometrikks-cli" "$out/bin/geometrikks-cli"
    runHook postInstall
  '';

  passthru = {
    inherit venv frontend bunDeps;
  };

  meta = with lib; {
    description = "GeoMetrikks — reverse-proxy access-log geo analytics";
    homepage = "https://github.com/GilbN/geometrikks";
    license = licenses.unfree; # upstream carries no license file at v0.19.0
    mainProgram = "geometrikks-server";
    platforms = platforms.linux;
  };
}
