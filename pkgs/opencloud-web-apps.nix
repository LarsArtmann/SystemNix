# Web apps (extensions) for OpenCloud, installed declaratively instead of the
# imperative `$OC_DATA_DIR/web/assets/apps` copy the upstream docs describe.
# WEB_ASSET_APPS_PATH (modules/nixos/services/opencloud.nix) serves the tree.
#
# Sources are the official opencloud-eu/web-extensions release archives — the
# same artifacts the in-app store downloads.
#
# Version pinning rule: each app builds against @opencloud-eu/web-client ^7 or
# ^8 and shares module-federation packages with the running web line
# (opencloud-production 7.2.4 ships web 7.1.5). Check the tag's package.json
# `devDependencies` before bumping: json-viewer >= 2.2.0 and unzip >= 2.2.1
# target web ^8 and will not load on the production line. Excalidraw needs
# web >= 8.1.0 (shared Yjs runtime, opencloud-eu/web#3398) and is therefore
# absent until opencloud-production reaches the 8.x line.
{
  lib,
  stdenvNoCC,
  fetchzip,
}:
let
  apps = {
    json-viewer = {
      version = "2.1.0";
      hash = "sha256-hLeyNYbcrv6mgmuupK3xCf606eEkUeOPeCa0fhL7lzo=";
    };
    unzip = {
      version = "2.2.0";
      hash = "sha256-xAUKQSSVN+LdO+QX/2mU8kmUn4fcjNQhB0HB9Gi0V3Q=";
    };
  };

  release =
    name: spec:
    fetchzip {
      pname = "opencloud-web-app-${name}";
      inherit (spec) version;
      url = "https://github.com/opencloud-eu/web-extensions/releases/download/${name}-v${spec.version}/${name}-${spec.version}.zip";
      inherit (spec) hash;
    };
in
stdenvNoCC.mkDerivation {
  pname = "opencloud-web-apps";
  version = "7";
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/apps
    ${lib.concatLines (
      lib.mapAttrsToList (name: spec: ''
        cp -r ${release name spec} $out/apps/${name}
      '') apps
    )}
    runHook postInstall
  '';

  meta = {
    description = "OpenCloud web apps (extensions) pinned to the web-client 7 line";
    homepage = "https://github.com/opencloud-eu/web-extensions";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.all;
  };
}
