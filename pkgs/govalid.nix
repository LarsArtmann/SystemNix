{ pkgs }:
let
  inherit (pkgs) lib;
in
pkgs.buildGo127Module {
  pname = "govalid";
  # Built with go1.27 since 2026-09-17: the go1.26-built binary's
  # source-processing packages cannot type-check `encoding/json/v2` imports,
  # which broke govalid's markers analysis on go 1.27 workspaces (BuildFlow).
  version = "0-unstable-2026-09-17";

  src = pkgs.fetchFromGitHub {
    owner = "sivchari";
    repo = "govalid";
    rev = "8d6700c031967fa871a0e1739f507ab2e19f4615";
    hash = "sha256-yA2lMdy6HKgPkd0+yqNWJdAC7Jxwtmsgif6s2Q6LDRM=";
  };

  subPackages = [ "cmd/govalid" ];

  doCheck = false;

  vendorHash = "sha256-fKvE4wGU8PQbzgxTnUaRNqbTy6JlzDMBWcWGy9uUTqo=";

  meta = {
    description = "Type-safe struct validation code generator for Go";
    homepage = "https://github.com/sivchari/govalid";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "govalid";
  };
}
