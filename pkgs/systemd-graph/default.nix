{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  runCommand,
  systemd-graph-webui,
}:

let
  pname = "systemd-graph";
  version = "0-unstable-2026-06-08";

  src = fetchFromGitHub {
    owner = "icholy";
    repo = "systemd-graph";
    rev = "601521bda0303f44fd53637ed74f50161ff23d99";
    hash = "sha256-yb3w6/5UTI1ghY1/jl1PTma9wi9aEumNAG04FeHg8fY=";
  };

  # Re-pack the source with webui/dist injected from the webui derivation.
  # webui/embed.go uses `//go:embed dist`, so the dist directory MUST be in
  # the source tree when `go build` runs. We can't pass it as a separate
  # go package — embed.FS resolves at the package's source location.
  #
  # runCommand + cp preserves file modes/timestamps that go's embed cares
  # about less than the existence of dist/index.html and the asset dir.
  srcWithWebui = runCommand "systemd-graph-src-with-webui" { } ''
    cp -R ${src} $out
    chmod -R u+w $out
    rm -rf $out/webui/dist
    cp -R ${systemd-graph-webui}/. $out/webui/dist/
  '';
in
buildGo126Module {
  inherit pname version;

  src = srcWithWebui;

  # Only build the server binary. `cmd/dump` is an offline snapshot tool
  # not used at runtime.
  subPackages = [ "cmd/server" ];

  # Single direct dep: godbus/dbus/v5. vendor tree is tiny.
  vendorHash = "";

  # systemd-graph has no Go test suite.
  doCheck = false;

  meta = with lib; {
    description = "Live web UI for the systemd unit dependency graph (D-Bus driven, React SPA)";
    homepage = "https://github.com/icholy/systemd-graph";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "systemd-graph";
  };
}
