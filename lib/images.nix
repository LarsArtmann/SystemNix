let
  mkRef = {
    image,
    tag,
    digest ? null,
  }:
    if digest != null
    then "${image}:${tag}@${digest}"
    else "${image}:${tag}";
in {
  openseo = rec {
    image = "ghcr.io/every-app/open-seo";
    tag = "v0.0.15";
    ref = mkRef {inherit image tag;};
  };
  manifest = rec {
    image = "manifestdotbuild/manifest";
    tag = "6.6.1";
    ref = mkRef {inherit image tag;};
  };
  manifest-postgres = rec {
    image = "postgres";
    tag = "16-alpine";
    digest = "sha256:20edbde7749f822887a1a022ad526fde0a47d6b2be9a8364433605cf65099416";
    ref = mkRef {inherit image tag digest;};
  };
  twenty = rec {
    image = "twentycrm/twenty";
    tag = "v2.7.3";
    ref = mkRef {inherit image tag;};
  };
  twenty-postgres = rec {
    image = "postgres";
    tag = "16-alpine";
    ref = mkRef {inherit image tag;};
  };
  twenty-redis = rec {
    image = "redis";
    tag = "7-alpine";
    ref = mkRef {inherit image tag;};
  };
  whisper-rocm = rec {
    image = "beecave/insanely-fast-whisper-rocm";
    tag = "latest";
    digest = "sha256:1fa17f91846d30748751089a7ef37b490a8e3ec46e8ba4a1df15c28d1e60d3c1";
    ref = mkRef {inherit image tag digest;};
  };
  photomap = rec {
    image = "lstein/photomapai";
    tag = "latest";
    digest = "sha256:ca975ca6b2a00a7943fec1f578815dccfdbc212630547c70e750c724e981435d";
    ref = mkRef {inherit image tag digest;};
  };
}
