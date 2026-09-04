# Common test infrastructure for NixOS VM tests.
# Import alongside mock-sops.nix to reduce boilerplate in service tests.
#
# Provides:
#   - networking.domain (required by most modules for vHost/subdomain config)
#   - networking.local.* (required by Caddy, SearXNG, security-hardening, etc.)
#   - Prometheus textfile collector directory (required by metrics services)
#   - users.primaryUser option (required by many SystemNix modules)
#   - test-helpers.dnsGateHosts (deterministic /etc/hosts resolution for DNS-gated ExecStartPre)
#
# This module DEFINES users.primaryUser and networking.local (same as their
# respective platforms/nixos/system/ modules). Do NOT also import those modules
# in tests that use this helper — duplicate option definitions cause errors.
{
  lib,
  config,
  ...
}:
{
  options = {
    test-helpers.dnsGateHosts = lib.mkOption {
      type = lib.types.listOf lib.types.nonEmptyStr;
      default = [ ];
      description = ''
        Hostnames that must resolve inside the VM without real network.
        Set this on nodes whose services carry a DNS gate (mkDnsGate getent
        probe or mkOidcGate curl probe from lib/default.nix): inside the
        sandboxed VM, slirp host-side DNS is NOT guaranteed, so a gate that
        needs name resolution can nondeterministically fail or hang to its
        timeout at boot. Every hostname listed here resolves to 192.0.2.1
        (TEST-NET-1, RFC 5737 — routable-looking but never connected to).

        Use when the unit under test only needs RESOLUTION to succeed
        (hermes-github-verify hits its unset-token skip branch before any
        real git use). Do NOT use for units that will actually connect to
        the hostname afterwards — they would hang connecting to TEST-NET
        (mock a local listener or mkForce the gate away instead, like
        tests/test-oauth2-proxy.nix does).
      '';
    };

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

    # Deterministic DNS for DNS-gated ExecStartPre (see the option's
    # description). 192.0.2.1 = TEST-NET-1: resolution succeeds, connection
    # attempts fail fast instead of hanging on an unroutable name.
    networking.hosts."192.0.2.1" = config."test-helpers".dnsGateHosts;

    # Many services emit Prometheus metrics to this directory.
    systemd.tmpfiles.rules = [
      "d /var/lib/prometheus-node-exporter/textfile_collectors 0755 root root - -"
    ];
  };
}
