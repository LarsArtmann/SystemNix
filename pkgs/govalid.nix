{pkgs}: let
  inherit (pkgs) lib;
in
  pkgs.buildGo126Module {
    pname = "govalid";
    version = "0-unstable-2026-05-16";

    src = pkgs.fetchFromGitHub {
      owner = "sivchari";
      repo = "govalid";
      rev = "8d6700c031967fa871a0e1739f507ab2e19f4615";
      hash = "sha256-yA2lMdy6HKgPkd0+yqNWJdAC7Jxwtmsgif6s2Q6LDRM=";
    };

    subPackages = ["cmd/govalid"];

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
