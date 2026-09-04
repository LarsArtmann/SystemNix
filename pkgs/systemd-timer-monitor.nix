{
  lib,
  stdenvNoCC,
  python3,
}:
stdenvNoCC.mkDerivation {
  pname = "systemd-timer-monitor";
  version = "1.0.0";

  # Vendored 2026-08-28: upstream cappy-dev/systemd-timer-monitor was
  # deleted from GitHub (rev ff68e41 vanished, tarball 404). The script is
  # zero-dependency stdlib Python, copied verbatim from the last successful
  # build output. Replace with a maintained fork if one appears.
  src = lib.cleanSource ./.systemd-timer-monitor;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  buildInputs = [ python3 ];

  installPhase = ''
    runHook preInstall
    install -Dm755 ${./.systemd-timer-monitor/systemd-audit.py} $out/bin/systemd-audit
    runHook postInstall
  '';

  meta = {
    description = "Audit systemd services and timers into a static HTML report (vendored)";
    license = lib.licenses.unfree;
    platforms = lib.platforms.unix;
    mainProgram = "systemd-audit";
  };
}
