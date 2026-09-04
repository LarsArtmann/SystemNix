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
#      itself only loops accounts whose token file is missing. Extra
#      accounts are defined in the generated accounts TOML, so the auth
#      env MUST include INBOXCLEAN_CONFIG from the web unit (learned the
#      hard way 2026-08-29: without it the CLI only sees the env-default
#      main account and fails `no account matched --account "work"`,
#      exit 75):
#        sudo -u inboxclean env \
#          INBOXCLEAN_CONFIG="$(grep -oP 'INBOXCLEAN_CONFIG=\K\S+' /etc/systemd/system/inboxclean-web.service | head -1)" \
#          GMAIL_CREDENTIALS_FILE=/var/lib/inboxclean/credentials.json \
#          GMAIL_TOKEN_FILE=/var/lib/inboxclean/token.json \
#          DB_PATH=/var/lib/inboxclean/inboxclean.db \
#          /run/current-system/sw/bin/inboxclean auth --account work
#      Log in AS the Workspace identity when the browser asks. The work
#      token lands at /var/lib/inboxclean/token-work.json. If Google
#      answers access_denied, add that Google user under "Test users" on
#      the OAuth consent screen (Cloud Console) and retry.
#      TOKENS EXPIRE — re-auth is ROUTINE while the OAuth client is in
#      "Testing" (2026-09-04 incident): Google expires testing-mode refresh
#      tokens after exactly 7 days (main issued Aug 28 04:54 died Sep 04
#      07:34-08:04). Symptom: /labels card + sync WARN `could not refresh
#      OAuth token` → `invalid_grant "Token has been expired or revoked."`,
#      cursor frozen while other accounts advance, /health still says
#      `connected` (token-presence only — phantom green). Fix: switch the
#      OAuth consent screen to "In production" (Cloud Console) FIRST —
#      testing-issued tokens stay 7-day-bombed even after the flip — then
#      re-run steps 2 and 3; the auth CLI overwrites the existing token
#      files. `invalid_grant` is permanent: no retry, restart, or redeploy
#      fixes it.
#   4. Verify: curl -s http://127.0.0.1:8099/health | jq .services.gmail
#      must show every account "connected". NOTE: on InboxClean releases
#      before the lazy-reconnect fix (web a6ec3df), /health showed the
#      clients captured at web-service START — a token minted afterwards
#      kept showing not_connected until the next deploy/restart. Newer
#      builds self-heal within ~30s of the token landing.
#   5. Flip services.inboxclean.sync.enable to true and redeploy.
#      Until then the sync timer stays off: without a token every run fails
#      (Infrastructure family, exit 69) and would spam onFailure alerts.
#
# Paperless archiving go-live (one-time; services.inboxclean.paperless):
#   A. Create the API token on the box:
#        sudo -u paperless paperless-manage drf_create_token admin
#      (prints the token once; `admin` is fine on this single-user
#      instance. Alternative: Paperless admin UI -> the user -> Tokens.)
#   B. sudo sops platforms/nixos/secrets/inboxclean-paperless.yaml —
#      replace the PLACEHOLDER value with the token.
#   C. Flip services.inboxclean.paperless.enable = true (configuration.nix)
#      and deploy. B and C MUST land together: PAPERLESS_URL without a
#      real token is a config Rejection at EVERY inboxclean process start
#      (web + sync crash, gatus red), and a PLACEHOLDER token 401-warns
#      on every sync tick — hence the explicit enable gate.
#   Verify: journalctl -u inboxclean-sync | grep -i paperless shows the
#   pipeline run (or a clean skip); the /sync dashboard card shows the
#   Paperless stats; Gatus "InboxClean Paperless Archive Auth" is green.
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
      inboxcleanBackupDir = "/mnt/pool/backups/inboxclean";
    in
    {
      imports = [ inputs.inboxclean.nixosModules.default ];

      options.services.inboxclean.paperless = {
        enable = lib.mkEnableOption ''
          Gmail-attachment archiving into Paperless-ngx (upstream papersync
          integration: after every sync, InboxClean uploads new attachments
          and opt-in .eml bodies via the Paperless REST API; a local ledger
          plus Paperless checksum dedup make runs idempotent; failures are
          warnings, never fatal). Requires the real API token in
          platforms/nixos/secrets/inboxclean-paperless.yaml — see the header
          go-live runbook BEFORE flipping this on.
        '';
        url = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:${toString ports.paperless}";
          description = "Paperless-ngx base URL the sync hook uploads to.";
        };
        tags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "gmail" ];
          description = ''
            PAPERLESS_TAGS (comma-joined) applied to every upload — the
            provenance marker that makes archived attachments filterable
            in Paperless.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # CLI on PATH for the one-time `auth` runbook and operator use
        # (events/undo/export/doctor against the service database).
        environment.systemPackages = [ cfg.package ];

        assertions = [
          {
            assertion = cfg.paperless.enable -> (config.services.paperless.enable or false);
            message = ''
              services.inboxclean.paperless.enable requires services.paperless
              (Paperless-ngx) on this host — without the API the sync hook
              fail-fasts and warns on every tick.
            '';
          }
        ];

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
          # Runbook steps 1-4 complete (both tokens on disk since
          # 2026-08-29): the timer is on. OAuth tokens persist in the
          # state dir and survive redeploys.
          sync.enable = true;

          # Attachment archiving (upstream papersync pipeline). The token
          # rides the sops template — root-owned on purpose, systemd reads
          # EnvironmentFile as PID 1; URL + tags are non-secret and go
          # through extraEnvironment. Upstream applies both to web + sync
          # units (commonServiceConfig), so the /sync dashboard card lights
          # up with upload stats too. No systemd ordering against
          # paperless-web: the hook pings the document API fail-fast and the
          # next 30-min tick retries; the ledger keeps it idempotent.
          environmentFile = lib.mkIf cfg.paperless.enable (
            lib.mkDefault config.sops.templates."inboxclean-paperless-env".path
          );
          extraEnvironment = lib.mkIf cfg.paperless.enable {
            PAPERLESS_URL = cfg.paperless.url;
            PAPERLESS_TAGS = lib.concatStringsSep "," cfg.paperless.tags;
          };
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

        # Nightly WAL-safe backup of the event-store DB onto the mirrored
        # HDD pool (cv-backup pattern). The SQLite file holds both Gmail
        # accounts' sync state AND the paperless upload ledger — losing it
        # means a full Gmail re-sync plus lost upload idempotency.
        #
        # Mount-gated creator for the pool-side dir (atticd-storage-dir /
        # cv-backup-dir pattern): ReadWritePaths needs the path to exist
        # BEFORE namespace setup, and tmpfiles would pre-create it on the
        # root fs, shadowing the pool copy during a DAS outage.
        systemd.services.inboxclean-backup-dir = {
          description = "Create InboxClean backup directory on the HDD pool";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ inboxcleanBackupDir ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            # Targets the PARENT — pointing ReadWritePaths at the leaf
            # itself would 226/NAMESPACE before it can mkdir (cv lesson).
            (harden {
              MemoryMax = "128M";
              ReadWritePaths = [ "/mnt/pool/backups" ];
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            mkdir -p ${inboxcleanBackupDir}
            chmod 0755 ${inboxcleanBackupDir}
          '';
        };

        systemd.services.inboxclean-backup = {
          description = "InboxClean event-store SQLite backup (online .backup)";
          after = [
            "inboxclean-web.service"
            "inboxclean-backup-dir.service"
          ];
          wants = [
            "inboxclean-web.service"
            "inboxclean-backup-dir.service"
          ];
          # A detached DAS fails the run as a clean dependency error instead
          # of 226/NAMESPACE, and boot catch-up waits for the pool mount.
          unitConfig.RequiresMountsFor = [ inboxcleanBackupDir ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "inboxclean-backup" ''
                set -euo pipefail
                db="${cfg.dataDir}/inboxclean.db"
                if [ ! -f "$db" ]; then
                  echo "inboxclean-backup: no inboxclean.db yet — nothing to back up"
                  exit 0
                fi
                ts=$(date +%Y%m%dT%H%M%S)
                dst="${inboxcleanBackupDir}/inboxclean-$ts.db"
                ${lib.getExe pkgs.sqlite} "$db" ".backup '$dst'"
                # 14-day retention (pocket-id/cv pattern): the online .backup
                # rewrites every page, so nothing dedups between nights.
                find "${inboxcleanBackupDir}" -name "inboxclean-*.db" -mtime +14 -delete
                echo "inboxclean-backup: wrote $dst"
              '';
              ReadWritePaths = [
                inboxcleanBackupDir
                cfg.dataDir
              ];
            }
            (harden {
              # The state dir is foreign-owned (inboxclean); root with an
              # EMPTY CapabilityBoundingSet obeys DAC and cannot stat
              # through it — the cv-backup silent-no-op class.
              # CAP_DAC_READ_SEARCH = read-only traversal.
              CapabilityBoundingSet = "CAP_DAC_READ_SEARCH";
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        # 04:30 — staggered off the 01:00-03:00 btrbk peak and the
        # 03:17/03:30/04:00 dump backups (backup-coordination doctrine).
        systemd.timers.inboxclean-backup = {
          description = "Nightly InboxClean DB backup (04:30)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 04:30:00";
            Persistent = true;
            Unit = "inboxclean-backup.service";
          };
        };
      };
    };
}
