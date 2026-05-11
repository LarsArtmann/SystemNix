_: {
  flake.nixosModules.photomap = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.photomap;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults serviceTypes;
    immichMediaDir = config.services.immich.mediaLocation;
    immichUploadDir = "${immichMediaDir}/upload";
    immichLibraryDir = "${immichMediaDir}/library";
    photomapDataDir = "/var/lib/photomap";

    photomapConfig = pkgs.writeText "config.yaml" ''
      config_version: "1.0.0"
      albums:
        immich:
          name: "Immich Library"
          description: "All photos from local Immich server"
          image_paths:
            - /Pictures/upload
            - /Pictures/library
          index: /Pictures/index/immich-embeddings.npz
          umap_eps: 0.13
    '';
  in {
    options.services.photomap = {
      enable = lib.mkEnableOption "PhotoMap AI service";
      port = serviceTypes.servicePort 8050 "Port for the PhotoMap web interface";
    };

    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.photomap = {
        autoStart = true;
        image = "lstein/photomapai@sha256:ca975ca6b2a00a7943fec1f578815dccfdbc212630547c70e750c724e981435d";
        ports = ["127.0.0.1:${toString cfg.port}:${toString cfg.port}"];
        volumes = [
          "${immichUploadDir}:/Pictures/upload:ro"
          "${immichLibraryDir}:/Pictures/library:ro"
          "${photomapDataDir}/index/upload:/Pictures/upload/photomap_index"
          "${photomapDataDir}/index/library:/Pictures/library/photomap_index"
          "${photomapDataDir}/index:/Pictures/index"
          "${photomapDataDir}/config:/root/.config/photomap"
          "${photomapDataDir}/data:/root/.local/share/photomap"
        ];
        extraOptions = [
          "--health-cmd=python3 -c \"import urllib.request;urllib.request.urlopen('http://localhost:${toString cfg.port}/')\""
          "--health-interval=30s"
          "--health-timeout=10s"
          "--health-retries=3"
        ];
      };

      systemd.services.podman-photomap = {
        onFailure = ["notify-failure@%n.service"];
        after = ["immich-server.service" "postgresql.service"];
        wants = ["immich-server.service"];
        requires = ["immich-server.service" "postgresql.service"];
        startLimitBurst = 3;
        startLimitIntervalSec = 60;
        preStart = ''
          if [ ! -f ${photomapDataDir}/config/config.yaml ]; then
            cp ${photomapConfig} ${photomapDataDir}/config/config.yaml
            chmod 644 ${photomapDataDir}/config/config.yaml
          fi
        '';
        serviceConfig =
          harden {MemoryMax = "512M";}
          // serviceDefaults {RestartSec = "10s";};
      };

      systemd.tmpfiles.rules = [
        "d ${photomapDataDir} 0755 root root -"
        "d ${photomapDataDir}/config 0755 root root -"
        "d ${photomapDataDir}/data 0755 root root -"
        "d ${photomapDataDir}/index 0755 root root -"
        "d ${photomapDataDir}/index/upload 0755 root root -"
        "d ${photomapDataDir}/index/library 0755 root root -"
      ];
    };
  };
}
