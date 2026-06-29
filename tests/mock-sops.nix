# Mock sops-nix module for nixosTests
# Creates empty files at secret paths so services that depend on sops can evaluate and start.
# Usage: add to imports list alongside the service module being tested, then set
#   sops.secrets.<name> = {}; for each secret the module references.
{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption types;
in {
  options.sops = {
    secrets = mkOption {
      type = types.attrsOf (
        types.submodule (
          {name, ...}: {
            freeformType = types.anything;
            options.path = mkOption {
              type = types.str;
              default = "/run/secrets/${name}";
            };
          }
        )
      );
      default = {};
    };
    age = {
      keyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      generateKey = mkOption {
        type = types.bool;
        default = false;
      };
      sshKeyPaths = mkOption {
        type = types.listOf types.str;
        default = [];
      };
    };
    gnupg = {
      home = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      sshKeyPaths = mkOption {
        type = types.listOf types.str;
        default = [];
      };
    };
    defaultSopsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
    };
    defaultSopsFormat = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
    environment = mkOption {
      type = types.attrs;
      default = {};
    };
    templates = mkOption {
      type = types.attrsOf (
        types.submodule (
          {name, ...}: {
            freeformType = types.anything;
            options.path = mkOption {
              type = types.str;
              default = "/run/secrets-rendered/${name}";
            };
          }
        )
      );
      default = {};
    };
    validateSopsFiles = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config.systemd.tmpfiles.rules =
    lib.mapAttrsToList (
      _name: secret: "f ${secret.path} 0400 root root -"
    )
    config.sops.secrets;
}
