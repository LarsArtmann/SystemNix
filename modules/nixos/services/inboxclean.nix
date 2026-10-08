# Runbook: docs/services/inboxclean.md
# InboxClean — SystemNix wrapper around upstream nixos-module.
#
# Deployment note (2026-10-04): repeatable paperless --checksum/--document
# flags only work on nix-built binaries from upstream rev 5d81308 or newer
# (bumps cmdguard to the released v4.1.0 slice-flag fix; proxy cmdguard
# v4.0.2 mis-parses pflag's bracketed render). Check the locked inboxclean
# input rev before relying on those flags in a manual run.
#
# The upstream module (inputs.inboxclean.nixosModules.default, nix/module.nix
# in the InboxClean repo) provides every option (enable, package, addr, dataDir,
# environmentFile, gmailCredentialsFile, gmailTokenFile, extraEnvironment,
# sync.{enable,interval,persistent}, paperless.{enable,url,tags} incl. the
# PAPERLESS_URL/TAGS env + qpdf on the sync PATH, backup.{enable,dir,calendar,
# retentionDays} incl. the mount-gated dir creator, the WAL-safe backup units
# and timer, the CLI on system PATH, and mkDefault MemoryMax/GOMEMLIMIT/
# start-limit guards) plus inboxclean-web.service, the inboxclean-sync.service
# oneshot and its timer, with OAuth seeding into the state dir — all pinned by
# upstream's `nixos-module` QEMU VM test. Since the 2026-10-08 migration this
# file layers ONLY SystemNix-specific concerns: sops secret wiring, port from
# lib/ports.nix, the llama-chat LLM brain, onFailure alert routing, the fleet
# harden baseline + IO tiering, and the Gatus/Caddy integration registry.
# DEPLOY GATE: this wrapper requires an inboxclean input rev at or past the
# 2026-10-08 module migration — against the pre-migration lock it fails eval
# on the paperless/backup options. Bump with `nix flake lock --update-input
# inboxclean` once upstream master is pushed, then merge this branch.
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
#      kept showing not_connected until the next deploy/restart. The
#      self-heal claim is BROKEN AGAIN on deployed 01d2c5e (2026-10-04):
#      the health-driven reconnect passed the brand-prefixed id form
#      ("Account:main") where the prod closure matches plain "main", so
#      every attempt failed silently and a freshly re-minted token NEVER
#      healed /health (stays auth_expired). Upstream fix e9735c7 (unpushed
#      as of 2026-10-04). Until it deploys: restart inboxclean-web after
#      any re-auth — startup builds clients fresh from the token files.
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
      options,
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

          # Attachment archiving (upstream papersync pipeline): options,
          # PAPERLESS_URL/TAGS env, and qpdf on the sync PATH all live
          # UPSTREAM now. This layer contributes the host port (Paperless
          # answers on the lib/ports.nix port, not upstream's 8000 default)
          # and the sops token template — root-owned on purpose, systemd
          # reads EnvironmentFile as PID 1. No systemd ordering against
          # paperless-web: the hook pings the document API fail-fast and
          # the next 30-min tick retries; the ledger keeps it idempotent.
          paperless.url = lib.mkDefault "http://127.0.0.1:${toString ports.paperless}";
          environmentFile = lib.mkIf cfg.paperless.enable (
            lib.mkDefault config.sops.templates."inboxclean-paperless-env".path
          );

          # Nightly backup chain (units + timer + retention) lives UPSTREAM
          # now; this layer pins the host facts: the mirrored HDD pool dir
          # and the 04:30 stagger (backup-coordination doctrine — off the
          # 01:00-03:00 btrbk peak and the 03:17/03:30/04:00 dump backups).
          # mkDefault true preserves the pre-migration always-on behavior.
          backup = {
            enable = lib.mkDefault true;
            dir = "/mnt/pool/backups/inboxclean";
            calendar = "*-*-* 04:30:00";
          };
          # Chat AI (/chat dashboard): the brain is llama-chat (CPU MoE
          # llama-server), overriding the upstream module's keyless
          # LLM_PROVIDER=ollama placeholder. NOT FastFlowLM (socket-activated
          # NPU: 2-5 min cold load + memory-guard sacrifice — async
          # workloads only). Keyless: llama-server ignores Authorization.
          # LLM_MODEL tracks llama-chat's alias (single source); chat agent
          # turns send native OpenAI-format tool calls, so the model must
          # keep a tool-call chat template. 2026-10-08 incident: without an
          # explicit model the built-in Ollama default silently 404'd every
          # chat turn — `inboxclean doctor` now probes /v1/models and fails
          # loudly if base URL or model id ever drifts.
          extraEnvironment = {
            LLM_PROVIDER = "openai";
            OPENAI_BASE_URL = "http://127.0.0.1:${toString config.services.llama-chat.port}/v1";
            LLM_MODEL = config.services.llama-chat.alias;
          };
        };

        # Fleet baseline only: MemoryMax 512M (harden default) and the
        # GOMEMLIMIT=384MiB / start-limit guards now ship upstream with
        # identical mkDefault values; ReadWritePaths=dataDir likewise.
        systemd.services.inboxclean-web = {
          after = [ "sops-nix.service" ];
          wants = [ "sops-nix.service" ];
          inherit onFailure;

          serviceConfig = lib.mkMerge [
            (harden { })
            (serviceDefaults { })
            ioTier.background
          ];
        };

        # MemoryMax stays explicit: harden{}'s 512M default and upstream's
        # mkDefault 1G would collide at eval time the day upstream changes
        # its default — fail-closed by design. GOMEMLIMIT/start-limits/
        # qpdf-on-PATH now ship upstream.
        systemd.services.inboxclean-sync = {
          after = [ "sops-nix.service" ];
          wants = [ "sops-nix.service" ];
          inherit onFailure;

          serviceConfig = lib.mkMerge [
            (harden { MemoryMax = "1G"; })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        # Service-integration registry entry: fans out to the Caddy vHost
        # (Layer 2), the Gatus checks (liveness + render + projections +
        # per-account tabs + Paperless archive auth), the homepage tile,
        # and the backup-freshness row. Replaces rows in caddy.nix /
        # gatus-config.nix / homepage.nix / configuration.nix.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          inboxclean = {
            inherit (cfg) enable;
            subdomain = "inbox";
            port = ports.inboxclean;
            vHost.layer = "protected";
            checks = [
              # Liveness: /health behind a 3s TimeoutHandler (always 200
              # once the process is up; connection-refused when down).
              {
                name = "InboxClean";
                group = "Productivity";
                url = "http://localhost:${toString ports.inboxclean}/health";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alert = "InboxClean dashboard down — inbox.home.lan unreachable. Check: systemctl status inboxclean-web, journalctl -u inboxclean-web.";
              }
              # Functional: the dashboard renders real HTML from CQRS data
              # (works even before the Gmail OAuth flow completes).
              {
                name = "InboxClean Dashboard Renders";
                group = "Productivity";
                url = "http://localhost:${toString ports.inboxclean}/";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*<html*)"
                  "[RESPONSE_TIME] < 2000"
                ];
                alert = "InboxClean dashboard not rendering HTML — check inboxclean-web logs";
              }
              # Projection readiness: the endpoint 503s while a worker
              # drains/fails and 404s on pre-c766c44 binaries (where the
              # 404 JSON would false-alarm), so this probe only makes the
              # route's absence visible once — acceptable noise for the
              # one generation it takes to converge.
              {
                name = "InboxClean Projections Ready";
                group = "Productivity";
                url = "http://localhost:${toString ports.inboxclean}/health/projections";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*email_state*)"
                ];
                alert = "InboxClean projections endpoint degraded — check /health services.projections and journalctl -u inboxclean-web";
              }
            ]
            # Per-extra-account render probes: the ?account=<name> inbox tab
            # must render HTML for every configured mailbox (graceful
            # degradation keeps it 200 even when that account awaits its
            # one-time OAuth runbook).
            ++ map (account: {
              name = "InboxClean ${account.name} Inbox Renders";
              group = "Productivity";
              url = "http://localhost:${toString ports.inboxclean}/inbox?account=${account.name}";
              interval = "5m";
              conditions = [
                "[STATUS] == 200"
                "[BODY] == pat(*<html*)"
              ];
              alert = "InboxClean ${account.name} inbox tab not rendering — check inboxclean-web logs and the account OAuth runbook";
            }) cfg.extraAccounts
            # All-Gmail-dead paging (N4, 2026-09-20): the dashboard and
            # per-account tabs stay 200 even when every OAuth grant is
            # dead (auth_expired since 2026-09-12 proved silence is the
            # failure mode). This check fires only when NO account is
            # connected — slugs are evaluated at deploy time from
            # extraAccounts plus the implicit main, so a single dead
            # account stays quiet while a total die-off pages. Gatus
            # JSON-path conditions AND together: every listed account must
            # be NOT connected for the alert.
            ++ [
              {
                name = "InboxClean All Gmail Dead";
                group = "Productivity";
                url = "http://localhost:${toString ports.inboxclean}/health";
                interval = "5m";
                conditions = map (slug: "[BODY].services.gmail.${slug} != \"connected\"") (
                  [ "main" ] ++ map (account: account.name) cfg.extraAccounts
                );
                alert = "ALL InboxClean Gmail accounts are dead (none connected) — mailbox is silently uncleaned. Check: journalctl -u inboxclean-web, re-run inboxclean auth, inspect /health services.gmail.";
              }
            ]
            # Authenticated probe of the Paperless REST API with the SAME
            # token inboxclean-sync uploads attachments with — the
            # unauthenticated Paperless login-page check cannot see token
            # death, so archiving would degrade silently (upstream treats
            # upload failures as warnings by design). Endpoint is the
            # auth-required document list, NOT the API root: paperless
            # serves the root as browsable HTML only (any JSON Accept is
            # answered 406 regardless of token — the bug that broke the
            # InboxClean ping upstream, 2026-09-03), and unauthenticated
            # browser-y requests get a 302 login redirect instead of 401.
            # /api/documents/ is unambiguous: valid token -> 200,
            # dead token -> 401.
            ++ lib.optionals cfg.paperless.enable [
              {
                name = "InboxClean Paperless Archive Auth";
                group = "Productivity";
                url = "http://localhost:${toString ports.paperless}/api/documents/";
                interval = "5m";
                headers = {
                  Authorization = "Token $PAPERLESS_TOKEN";
                };
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alert = "InboxClean Paperless archiving auth failing — Gmail attachments are NOT being archived. Check: token in platforms/nixos/secrets/inboxclean-paperless.yaml vs paperless-manage drf_create_token; journalctl -u inboxclean-sync | grep -i paperless";
              }
            ];
            homepage = {
              name = "InboxClean";
              group = "Sync & Backup";
              description = "Gmail AI Assistant — Backup, Sorting & Tagging";
              icon = "gmail.png";
            };
            backup = {
              # Nightly online .backup of the event-store DB
              # (inboxclean-backup.timer, 04:30) onto the mirrored pool.
              # Same value as services.inboxclean.backup.dir (single source).
              directory = cfg.backup.dir;
              filePattern = "inboxclean-*.db";
              maxAgeHours = 25;
            };
          };
        };
      };
    };
}
