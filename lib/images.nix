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
  openseo = {
    image = "ghcr.io/every-app/open-seo";
    tag = "v0.0.15";
    ref = mkRef {
      image = "ghcr.io/every-app/open-seo";
      tag = "v0.0.15";
    };
  };
  manifest = {
    image = "manifestdotbuild/manifest";
    tag = "6.6.1";
    ref = mkRef {
      image = "manifestdotbuild/manifest";
      tag = "6.6.1";
    };
  };
  manifest-postgres = {
    image = "postgres";
    tag = "16-alpine";
    digest = "sha256:20edbde7749f822887a1a022ad526fde0a47d6b2be9a8364433605cf65099416";
    ref = mkRef {
      image = "postgres";
      tag = "16-alpine";
      digest = "sha256:20edbde7749f822887a1a022ad526fde0a47d6b2be9a8364433605cf65099416";
    };
  };
  twenty = {
    image = "twentycrm/twenty";
    tag = "v2.7.3";
    ref = mkRef {
      image = "twentycrm/twenty";
      tag = "v2.7.3";
    };
  };
  twenty-postgres = {
    image = "postgres";
    tag = "16-alpine";
    ref = mkRef {
      image = "postgres";
      tag = "16-alpine";
    };
  };
  twenty-redis = {
    image = "redis";
    tag = "7-alpine";
    ref = mkRef {
      image = "redis";
      tag = "7-alpine";
    };
  };
}
