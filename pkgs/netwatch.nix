{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  libpcap,
}:
rustPlatform.buildRustPackage rec {
  pname = "netwatch";
  version = "0.14.1";

  src = fetchFromGitHub {
    owner = "matthart1983";
    repo = "netwatch";
    tag = "v${version}";
    hash = "sha256-8Q8TNcUgw/H2fzbKYMmHmBiCF3SP0XVepq8FMiZwu8c=";
  };

  cargoHash = "sha256-GYjtERr+M5lY8/Y77hedizJcNsyRh8XOaCAMBiz/Dk0=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ libpcap ];

  meta = with lib; {
    description = "Real-time network diagnostics TUI — interfaces, connections, packets, health probes, and AI insights";
    homepage = "https://github.com/matthart1983/netwatch";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "netwatch";
  };
}
