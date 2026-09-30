# Pure-eval test for services.nsfw-classifier (same pattern as
# test-port-registry-audit.nix): no VM boot — assertions over the resolved
# config of a minimal host importing ONLY the nsfw-classifier module (plus
# catalog.nix for the unconditional-entry case).
#
# Proves the zero-user-engagement extension contract:
#   1. Enabled: the unit runs the server in fast mode with --pair-token
#      auto, bound on all interfaces at the registered port — the
#      extension's discovery probes http://nsfw.home.lan:<port> and
#      refuses tokenless servers (nsfw-extension/url-utils.js).
#   2. Models come from the live checkout, so the unit runs as lars (the
#      0700 home) with a persistent XDG cache for the pairing token.
#   3. Disabled (default): no unit — hosts that never enable it stay clean.
#   4. The catalog entry exists even when the service is disabled
#      (ADR-008 "what exists" is unconditional).
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;

  module =
    (import ../modules/nixos/services/nsfw-classifier.nix { inherit inputs; })
    .flake
    .nixosModules
    .nsfw-classifier;
  catalogModule = (import ../modules/nixos/services/catalog.nix { }).flake.nixosModules.catalog;

  evalConfig =
    extra:
    (lib.nixosSystem {
      inherit system;
      modules = [ module ] ++ extra;
    }).config;

  enabledConfig = evalConfig [
    {
      services.nsfw-classifier.enable = true;
      users.users.lars = {
        isNormalUser = true;
        home = "/home/lars";
      };
    }
  ];
  disabledConfig = evalConfig [ ];
  catalogConfig = evalConfig [ catalogModule ];

  sc = enabledConfig.systemd.services.nsfw-classifier.serviceConfig;

  cases = [
    {
      name = "enabled-unit-exists";
      pass = enabledConfig.systemd.services ? nsfw-classifier;
    }
    {
      name = "fast-mode-flag";
      pass = lib.hasInfix "--fast" sc.ExecStart;
    }
    {
      name = "pairing-token-auto";
      # The extension refuses tokenless servers (pairingTokenFromReadyz
      # returns null → candidate rejected) — the token is the auth floor.
      pass = lib.hasInfix "--pair-token auto" sc.ExecStart;
    }
    {
      name = "lan-bind-on-registered-port";
      # Discovery resolves nsfw.home.lan to the LAN IP (dnsblockd
      # localRecords) — a loopback bind would never be reachable.
      pass = lib.hasInfix "--host 0.0.0.0" sc.ExecStart && lib.hasInfix "--port 8104" sc.ExecStart;
    }
    {
      name = "models-from-live-checkout";
      pass = lib.hasInfix "--models-dir /home/lars/projects/nsfw-classifier/models" sc.ExecStart;
    }
    {
      name = "runs-as-lars";
      # /home/lars is 0700 — a DynamicUser could not traverse to the models.
      pass = sc.User or "" == "lars";
    }
    {
      name = "pair-token-cache-persists";
      # os.UserCacheDir honors XDG_CACHE_HOME; CacheDirectory=nsfw-classifier
      # makes <XDG>/nsfw-classifier persistent across restarts so the
      # extension stays paired.
      pass =
        (sc.Environment.XDG_CACHE_HOME or "") == "/var/cache"
        && (sc.CacheDirectory or "") == "nsfw-classifier";
    }
    {
      name = "disabled-no-unit";
      pass = !(disabledConfig.systemd.services ? nsfw-classifier);
    }
    {
      name = "catalog-entry-unconditional";
      pass = catalogConfig.services.catalog ? nsfw;
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "nsfw-classifier-eval-test" { } "touch $out"
else
  pkgs.runCommand "nsfw-classifier-eval-test" { } ''
    echo "nsfw-classifier eval test FAILED: ${lib.concatStringsSep ", " broken}"
    exit 1
  ''
