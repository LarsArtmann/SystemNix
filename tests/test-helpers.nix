# Common test infrastructure for NixOS VM tests.
# Import alongside mock-sops.nix to reduce boilerplate in service tests.
#
# Provides:
#   - networking.domain (required by most modules for vHost/subdomain config)
#   - networking.local.* (required by Caddy, SearXNG, security-hardening, etc.)
#   - Prometheus textfile collector directory (required by metrics services)
#   - users.primaryUser option (required by many SystemNix modules)
#
# This module DEFINES users.primaryUser and networking.local (same as their
# respective platforms/nixos/system/ modules). Do NOT also import those modules
# in tests that use this helper — duplicate option definitions cause errors.
{ lib, ... }: {
  options = {
    users.primaryUser = lib.mkOption {
      type = lib.types.str;
      default = "testuser";
      description = "Primary user account (test mock — see test-helpers.nix)";
    };

    networking.local = {
      lanIP = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "192.168.1.150";
      };
      subnet = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "192.168.1.0/24";
      };
      gateway = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "192.168.1.1";
      };
      blockIP = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "192.168.1.200";
      };
      virtualIP = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "192.168.1.53";
      };
      piIP = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "192.168.1.151";
      };
    };
  };

  config = {
    networking.domain = "test.local";

    # Many services emit Prometheus metrics to this directory.
    systemd.tmpfiles.rules = [
      "d /var/lib/prometheus-node-exporter/textfile_collectors 0755 root root - -"
    ];
  };
}
