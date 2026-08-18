let
  mkRef =
    {
      image,
      tag,
      digest ? null,
    }:
    if digest != null then "${image}:${tag}@${digest}" else "${image}:${tag}";
in
{
  manifest = rec {
    image = "manifestdotbuild/manifest";
    tag = "6.18.0";
    digest = "sha256:6e4fe296afb530e494f01553d889fafa1ed9b0333f4ff1eedb1e6684f065a717";
    ref = mkRef { inherit image tag digest; };
  };
  manifest-postgres = rec {
    image = "postgres";
    tag = "16-alpine";
    digest = "sha256:cf78e76683b9ca8c5733cbbdce6c9262b45b6767934dd0a95e671f9a0fc20685";
    ref = mkRef { inherit image tag digest; };
  };
  twenty = rec {
    image = "twentycrm/twenty";
    tag = "v2.32.0";
    ref = mkRef { inherit image tag; };
  };
  twenty-postgres = rec {
    image = "postgres";
    tag = "16-alpine";
    ref = mkRef { inherit image tag; };
  };
  twenty-redis = rec {
    image = "redis";
    tag = "7-alpine";
    ref = mkRef { inherit image tag; };
  };
  whisper-rocm = rec {
    image = "beecave/insanely-fast-whisper-rocm";
    # Upstream's only tag is "main" — there is no "latest" tag; the digest pin
    # (2024-08-28 build) is what actually made the old "latest" ref resolve.
    tag = "main";
    digest = "sha256:1fa17f91846d30748751089a7ef37b490a8e3ec46e8ba4a1df15c28d1e60d3c1";
    ref = mkRef { inherit image tag digest; };
  };
}
