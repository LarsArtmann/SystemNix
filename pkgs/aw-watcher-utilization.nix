{ pkgs }:
let
  inherit (pkgs) lib python3Packages fetchFromGitHub;
  inherit (python3Packages) buildPythonApplication;
in
buildPythonApplication rec {
  pname = "aw-watcher-utilization";
  version = "1.2.2";

  src = fetchFromGitHub {
    owner = "Alwinator";
    repo = "aw-watcher-utilization";
    tag = "v${version}";
    hash = "sha256-CZsJ8itg6wI19uD9nXl/H0A1EFbt87C0yFLHZAsvGQY=";
  };

  pyproject = true;
  build-system = [ python3Packages.poetry-core ];

  # Patch pyproject.toml to use modern poetry backend
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'requires = ["poetry>=0.12"]' 'requires = ["poetry-core>=1.0.0"]' \
      --replace-fail 'build-backend = "poetry.masonry.api"' 'build-backend = "poetry.core.masonry.api"'
  '';

  dependencies = with python3Packages; [
    aw-client
    psutil
  ];

  # Relax dependency constraints since we use nixpkgs versions
  pythonRelaxDeps = [
    "aw-core"
    "aw-client"
    "psutil"
  ];

  # Disable pythonImportsCheck because aw-core tries to create config dirs
  # in $HOME which is /homeless-shelter in the Nix sandbox
  doCheck = false;
  pythonImportsCheck = [ ];

  meta = {
    description = "Monitors CPU, RAM, disk, network, and sensor usage for ActivityWatch";
    homepage = "https://github.com/Alwinator/aw-watcher-utilization";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.all;
    mainProgram = "aw-watcher-utilization";
  };
}
