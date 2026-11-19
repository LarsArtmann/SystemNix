{
  lib,
  buildGoModule,
  buildNpmPackage,
  go_1_27,
  nodejs_24,
  src,
}:
# paperless-gpt — AI metadata enrichment + custom-field extraction for
# Paperless-ngx (github:icereed/paperless-gpt). Consumed by
# modules/nixos/services/paperless-gpt.nix (same callPackage + src input on
# both sites → identical store path) and exposed as `nix build .#paperless-gpt`.
#
# Build shape mirrors upstream's multi-stage Dockerfile:
#   1. npm stage: web-app (Vite + TS + React) → dist/
#   2. go stage: dist copied to web-app/dist, then `go build .`
#      (embedded_assets.go `//go:embed web-app/dist/*` REQUIRES dist in the
#      tree — it is not committed upstream)
#
# Runtime contract (module side): the binary writes prompts/, config/ and db/
# RELATIVE TO ITS WORKING DIRECTORY and copies prompt templates from
# default_prompts/ next to it — shipped under $out/share/paperless-gpt for a
# preStart copy into the state dir. CGO is REQUIRED (mattn/go-sqlite3).
#
# Keep `version` in sync with the tag-pinned input ref in flake.nix.
let
  version = "0.31.0";
  # Vite frontend embedded into the Go binary.
  frontend = buildNpmPackage {
    pname = "paperless-gpt-web";
    inherit version src;
    sourceRoot = "source/web-app";

    npmDepsHash = "sha256-6ZkO5pVQfJKYGpgUEKS/AXy/bfuot8cOJ2o+Z087HWM=";

    # cpu-features (transitive dev-dep: testcontainers -> ssh2) is a Nan
    # addon that no longer compiles on Node 24 and is never imported at
    # build time; vite/esbuild/swc ship prebuilt platform binaries via
    # optionalDependencies, so no install scripts are needed.
    npmFlags = [ "--ignore-scripts" ];

    # Upstream builds with node 24 (Dockerfile: node:24-alpine).
    nodejs = nodejs_24;

    # `npm run build` = `tsc -b && vite build --base=./` → dist/
    #
    # @swc/core 1.16.13 (pulled in by @vitejs/plugin-react-swc 4, new in
    # v0.31.0) ships its native addon as a self-loading ELF carrier with a
    # zstd "SWCNZSTD" payload embedded in a read-only section. On load the
    # addon self-extracts into a per-user cache and refuses to load unless
    # that cache root *and every one of its ancestors* is owned by the
    # effective uid or root and is not group/other-writable. The nix
    # sandbox root "/" is owned by an unmapped uid, so NO
    # SWC_NATIVE_BINDING_CACHE location can satisfy the check, and the
    # SWC_NATIVE_BINDING_CACHE(_SKIP_SECURITY_CHECK) opt-outs only exist
    # in @swc/core >= 1.16.17 — we pin 1.16.13. Overwrite each carrier
    # with its decoded raw addon (nixpkgs' bookorbit pattern, pinned
    # nixpkgs pkgs/by-name/bo/bookorbit): the raw N-API addon loads
    # directly, no cache, no carrier. Decode runs in-build, so
    # npmDepsHash is unaffected.
    preBuild = ''
      find node_modules -name 'swc.*.node' -exec node -e '
        const fs = require("node:fs"), z = require("node:zlib");
        const signature = Buffer.from("SWCNZSTD\u0001\u0000\u0060\u0000", "latin1");
        for (const p of process.argv.slice(1)) {
          const b = fs.readFileSync(p);
          const i = b.indexOf(signature);
          if (i < 0) continue;
          const frameLen = Number(b.readBigUInt64LE(i + 16));
          const raw = z.zstdDecompressSync(b.subarray(i + 96, i + 96 + frameLen));
          fs.chmodSync(p, 0o644);
          fs.writeFileSync(p, raw);
        }
      ' {} +
    '';
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';

    meta = {
      description = "paperless-gpt web frontend (Vite build, embedded asset)";
      platforms = [ "x86_64-linux" ];
    };
  };

  buildGoModule' = buildGoModule.override { go = go_1_27; };
in
buildGoModule' {
  pname = "paperless-gpt";
  inherit version src;

  # go:embed needs web-app/dist present in the unpacked tree.
  postPatch = ''
    cp -r ${frontend} web-app/dist
    chmod -R u+w web-app/dist
  '';

  # go.mod requires go >= 1.27.1.
  vendorHash = "sha256-81a3B16v4rF8ut2HcT0w/KgT8XaZahQ3GPv/oEenXPk=";

  # Upstream tests are E2E (docker-compose paperless + LLM mock, pdfcpu
  # wants $HOME) — not hermetic. Binary verification happens via the
  # module's deploy smoke + version print, not here.
  doCheck = false;

  # mattn/go-sqlite3 (gorm local DB) needs CGO_ENABLED=1.
  env.CGO_ENABLED = 1;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.commit=v${version}"
    "-X main.buildDate=1970-01-01T00:00:00Z"
  ];

  # Prompt templates the binary copies into prompts/ on first run
  # (loadTemplates reads default_prompts/<name> RELATIVE to its CWD).
  postInstall = ''
    mkdir -p $out/share/paperless-gpt
    cp -r default_prompts $out/share/paperless-gpt/
  '';

  meta = {
    description = "AI metadata enrichment + custom-field extraction for Paperless-ngx";
    homepage = "https://github.com/icereed/paperless-gpt";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "paperless-gpt";
  };
}
