# InboxClean — SystemNix wrapper around upstream nixos-module.
#
# The upstream module (inputs.inboxclean.nixosModules.default, nix/module.nix
# in the InboxClean repo) provides every option (enable, package, addr, dataDir,
# environmentFile, gmailCredentialsFile, gmailTokenFile, extraEnvironment,
# sync.{enable,interval,persistent}) plus inboxclean-web.service, the
# inboxclean-sync.service oneshot and its timer, with OAuth seeding into the
# state dir. This file layers ONLY SystemNix-specific concerns: sops secret
# wiring, port from lib/ports.nix, onFailure alert routing, GOMEMLIMIT,
# systemd hardening, and IO tiering.
#
# Runbook (one-time, per Google account):
#   1. The sops secret inboxclean_gmail_credentials holds the Google OAuth
#      client credentials.json (plaintext source: ~/.inboxclean/credentials.json).
#   2. Complete the OAuth flow ONCE on the evo-x2 desktop:
#        sudo -u inboxclean \
#          GMAIL_CREDENTIALS_FILE=/var/lib/inboxclean/credentials.json \
#          GMAIL_TOKEN_FILE=/var/lib/inboxclean/token.json \
#          DB_PATH=/var/lib/inboxclean/inboxclean.db \
#          /run/current-system/sw/bin/inboxclean auth
#      (browser opens for the Google login; the token lands in the state dir
#      and persists — the module never overwrites an existing token.json).
#   3. Authenticate extra accounts the same way, one per identity —
#      `--account <name>` limits the flow to one account, and the CLI
#      itself only loops accounts whose token file is missing:
#        sudo -u inboxclean \
#          GMAIL_CREDENTIALS_FILE=/var/lib/inboxclean/credentials.json \
#          GMAIL_TOKEN_FILE=/var/lib/inboxclean/token.json \
#          DB_PATH=/var/lib/inboxclean/inboxclean.db \
#          /run/current-system/sw/bin/inboxclean auth --account work
#      Log in AS the Workspace identity when the browser asks. The work
#      token lands at /var/lib/inboxclean/token-work.json. If Google
#      answers access_denied, add that Google user under "Test users" on
#      the OAuth consent screen (Cloud Console) and retry.
#   4. Verify: curl -s http://127.0.0.1:8099/health | jq .services.gmail
#      must show every account "connected".
#   5. Flip services.inboxclean.sync.enable to true and redeploy.
#      Until then the sync timer stays off: without a token every run fails
#      (Infrastructure family, exit 69) and would spam onFailure alerts.
{ inputs, ... }: {
  flake.nixosModules.inboxclean =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        ports
        onFailure
        serviceDefaults
        serviceOneshotDefaults
        ioTier
        ;
      cfg = config.services.inboxclean;
      inboxcleanPkg = inputs.inboxclean.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      imports = [ inputs.inboxclean.nixosModules.default ];

      config = lib.mkIf cfg.enable {
        # CLI on PATH for the one-time `auth` runbook and operator use
        # (events/undo/export/doctor against the service database).
        environment.systemPackages = [ cfg.package ];

        services.inboxclean = {
          package = lib.mkDefault inboxcleanPkg;
          addr = lib.mkDefault "127.0.0.1:${toString ports.inboxclean}";
          gmailCredentialsFile = lib.mkDefault config.sops.secrets.inboxclean_gmail_credentials.path;
          # Google Workspace mailbox. Shares the personal account's OAuth
          # client (same credentials.json) — the browser login during
          # `inboxclean auth --account work` picks the Workspace identity.
          # Its token lands in /var/lib/inboxclean/token-work.json.
          extraAccounts = [
            {
              name = "work";
              credentialsFile = lib.mkDefault config.sops.secrets.inboxclean_gmail_credentials.path;
            }
          ];
          # See runbook above: enable after the one-time OAuth flow.
          sync.enable = lib.mkDefault false;
        };

        systemd.services.inboxclean-web = {
          after = [ "sops-nix.service" ];
          wants = [ "sops-nix.service" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "512M";
              ReadWritePaths = [ cfg.dataDir ];
            })
            (serviceDefaults { })
            ioTier.background
            { Environment = [ "GOMEMLIMIT=384MiB" ]; }
          ];
        };

        systemd.services.inboxclean-sync = {
          after = [ "sops-nix.service" ];
          wants = [ "sops-nix.service" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "1G";
              ReadWritePaths = [ cfg.dataDir ];
            })
            (serviceOneshotDefaults { })
            ioTier.background
            { Environment = [ "GOMEMLIMIT=768MiB" ]; }
          ];
        };
      };
    };
}
