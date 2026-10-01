# Runbook: docs/services/nix-email.md
# nix-email — SystemNix wrapper around the upstream LarsArtmann/nix-email
# flake (github:LarsArtmann/nix-email, public).
#
# Upstream (inputs.nix-email.nixosModules.default) owns everything product:
#   services.mail-server   — Stalwart all-in-one (SMTP/IMAP/JMAP) wrapper,
#                            RFC listener set, relay/metrics/certificate
#                            options, own VM E2E suite
#   services.dmarc-monitor — parsedmarc DMARC/TLS-RPT collector (IMAP
#                            polling, JSON/CSV output, no search stack)
#
# This file layers ONLY the SystemNix-specific concerns: sops secrets for
# the IMAP password / fallback-admin / relay password, LoadCredential
# wiring for Stalwart, onFailure alert routing, and the integration
# registry entry (monitored unit + backup-coordination freshness for the
# parsedmarc reports directory).
#
# DEPLOYMENT STATE (2026-09-29): dmarc-monitor fully wired on evo-x2 but
# enable = false until the mail stack is live on pbx-artmann (the rua
# mailbox must exist first — a failing parsedmarc unit exit-4s deploys).
# Flip services.dmarc-monitor.enable in configuration.nix as the FINAL
# step of pbx-artmann docs/runbooks/mail-go-live.md, then paste the real
# dmarc-imap-password secret (platforms/nixos/secrets/nix-email.yaml,
# placeholder value shipped).
#   - services.mail-server is now ENABLED on the pbx-artmann VPS — but it
#     consumes the upstream module DIRECTLY (that repo has no sops; its
#     runtime-file secrets doctrine differs), not through this wrapper.
#     The mail-server half below still targets the general "a host that
#     consumes this module wants a mail server" case and stays
#     eval-verified by tests/test-nix-email.nix (mock-sops pattern).
{ inputs, ... }: {
  flake.nixosModules.nix-email =
    {
      config,
      options,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib) onFailure;
      cfg = config.services.dmarc-monitor;
      msCfg = config.services.mail-server;
      dmarcSecret = "dmarc-imap-password";
      # Upstream mirrors nixpkgs: the unit is stalwart-mail.service below
      # stateVersion 26.05 and stalwart.service since — onFailure must land
      # on the real unit name.
      stalwartUnit = if lib.versionOlder msCfg.stateVersion "26.05" then "stalwart-mail" else "stalwart";
    in
    {
      imports = [ inputs.nix-email.nixosModules.default ];

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          # --- dmarc-monitor (evo-x2 target) -------------------------------
          # The IMAP password is a _secret path contract upstream (absolute
          # path STRING, rendered into the ini at unit start) — feed it the
          # sops-rendered file, never a store path.
          sops.secrets.${dmarcSecret}.sopsFile =
            lib.mkDefault ../../../platforms/nixos/secrets/nix-email.yaml;

          services.dmarc-monitor.settings.imap.password._secret =
            lib.mkDefault
              config.sops.secrets.${dmarcSecret}.path;

          systemd.services.parsedmarc = {
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };

          # Registry fan-out: no vHost/subdomain/port (no HTTP surface —
          # parsedmarc polls outbound). The health signals are the unit
          # state (system-health metrics) and reports-dir freshness: with
          # 16 domains reporting, aggregate reports land daily; 72h stale
          # means the poller is broken (or every sender stopped talking to
          # us — worth a page either way). Empty-mailbox ramp-up stays
          # under one maxAge window.
          services.integration = lib.optionalAttrs (options ? services.integration) {
            dmarc-monitor = {
              unit = "parsedmarc.service";
              subdomain = null;
              port = null;
              vHost.layer = "none";
              checks = [ ];
              monitored = true;
              backup = {
                directory = cfg.outputDirectory;
                filePattern = "*.json";
                maxAgeHours = 72;
              };
            };
          };
        })

        (lib.mkIf msCfg.enable {
          # --- mail-server (future VPS target) ------------------------------
          # Stalwart secrets ride systemd LoadCredential: paths registered
          # in services.stalwart.credentials appear at
          # /run/credentials/stalwart.service/<key> and are referenced from
          # settings via the %{file:...}% macro (verified upstream pattern).
          # stateVersion >= 26.05 renamed the unit stalwart-mail -> stalwart;
          # the macro path must match — upstream's stateVersion option
          # documents this, keep both in sync if ever changed.
          sops.secrets = {
            stalwart-fallback-admin.sopsFile = lib.mkDefault ../../../platforms/nixos/secrets/nix-email.yaml;
            stalwart-relay-password.sopsFile = lib.mkDefault ../../../platforms/nixos/secrets/nix-email.yaml;
          };

          services.stalwart = {
            # Relay password becomes a LoadCredential only once a relay is
            # configured (upstream asserts the half-configured shapes
            # itself; secretFile without username never reaches Stalwart).
            credentials = {
              fallback-admin = lib.mkDefault config.sops.secrets.stalwart-fallback-admin.path;
              mail-server-relay = lib.mkIf (msCfg.relay != null && msCfg.relay.username != null) (
                lib.mkDefault config.sops.secrets.stalwart-relay-password.path
              );
            };
            settings.authentication.fallback-admin.secret = lib.mkDefault "%{file:/run/credentials/${stalwartUnit}.service/fallback-admin}%";
          };

          systemd.services.${stalwartUnit} = {
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };
        })
      ];
    };
}
