{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "systemd-timer-monitor";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "cappy-dev";
    repo = "systemd-timer-monitor";
    rev = "ff68e4152ffb85c2f86ad4dd1373db02db42cb15";
    hash = "sha256-MH3E9BzUoSTjmcvUdXK5KbL3z7EDYuftvJcxB/+SC7Y=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 systemd_audit.py $out/bin/systemd-audit

    runHook postInstall
  '';

  meta = with lib; {
    description = "Lightweight systemd services+timers audit report — single-file Python, zero deps, read-only HTML output";
    homepage = "https://github.com/cappy-dev/systemd-timer-monitor";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "systemd-audit";
  };
}
