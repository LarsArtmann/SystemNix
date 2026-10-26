# Runbook: docs/services/opencloud.md
# OpenCloud — self-hosted file sync & share platform (opencloud-eu/opencloud).
# Wraps the nixpkgs module (services.opencloud) with SystemNix wiring:
#   - Production line (opencloud-production 7.2.4, no-downgrade-across-lines)
#   - External OIDC via Pocket ID (Layer 1, plain reverse_proxy): ALL OpenCloud
#     clients (web/desktop/android) are PUBLIC PKCE clients with PREDEFINED
#     client IDs, discovered by the clients through OpenCloud's webfinger
#     service (ADR-0003). Pocket ID supports isPublic + pkceEnabled clients
#     and pins custom client IDs (provision createAttrs id), and its
#     callback_url_util implements the OIDC loopback-port exemption for the
#     desktop client's http://127.0.0.1:<random-port> redirect.
#   - Role bootstrap WITHOUT the two-deploy dance: PROXY_ROLE_ASSIGNMENT_DRIVER
#     = oidc + the UPSTREAM DEFAULT role mapping (claim values opencloudAdmin/
#     opencloudUser) + Pocket ID userGroups with exactly those names. Every
#     login maps groups -> roles declaratively; unmapped users fail CLOSED
#     (LAN-only pilot: only provisioned group members can log in at all).
#     Fallback if desktop login ever breaks on the oidc driver (the historical
#     opencloud-eu/desktop#217 class, closed 2026-09-02): flip
#     PROXY_ROLE_ASSIGNMENT_DRIVER to "default" + GRAPH_ASSIGN_DEFAULT_USER_ROLE
#     to "true" in ONE deploy — roles already assigned to users persist.
#   - stateDir is a POOL SUBVOLUME (Set-B storage, btrbk-pool snapshots the
#     services/* roster): created by the mount-gated opencloud-storage-dir
#     oneshot (tq-storage-dir pattern), NOT by tmpfiles (shadow-dir class).
#     The nixpkgs module's tmpfiles rules for stateDir/idm are neutralized for
#     the same reason; the oneshot owns both directories.
#   - Embedded IdP is EXCLUDED (OC_EXCLUDE_RUN_SERVICES=idp) but the embedded
#     IDM (LDAP) stays: auto-provisioning (PROXY_AUTOPROVISION_ACCOUNTS=true)
#     writes first-login users into it. `opencloud init` (the module's
#     opencloud-init-config oneshot) MUST run once to generate + persist the
#     IDM/service secrets into /etc/opencloud/opencloud.yaml — the service
#     itself cannot write there (read-only store config), so skipping init
#     would re-generate random secrets on every restart and corrupt the IDM.
#     ADMIN_PASSWORD feeds that init; it is a random sops value nobody ever
#     needs (the embedded admin cannot log in anywhere with the idp excluded).
#   - posix storage driver (default): metadata in xattrs, no database — fits
#     the plain-files BTRFS doctrine. rsync of the state tree needs -X.
_: {
  flake.nixosModules.opencloud =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.opencloud;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        ioTier
        ports
        ;
      domain = config.networking.domain;
      stateDir = "/mnt/pool/services/opencloud";
      provisionEnabled = config.services.pocket-id-config.provision.enable or false;
      issuer = "https://auth.${domain}";
      ocUrl = "https://cloud.${domain}";
    in
    {
      # Platform-truth catalog entry (ADR-008): unconditional — the service
      # exists platform-wide even where this host has it disabled. Missing
      # import of the catalog module fails loudly at eval (the point).
      imports = [
        {
          services.catalog.opencloud = {
            subdomain = "cloud";
            port = ports.opencloud;
            description = "OpenCloud file sync and share (Pocket ID SSO)";
            healthPath = "/";
          };
        }
      ];

      config = lib.mkIf cfg.enable {
        services.opencloud = {
          # Production line: no downgrade support across lines — never switch
          # an initialized instance from opencloud-production to opencloud.
          package = pkgs.opencloud-production;
          address = "127.0.0.1";
          port = ports.opencloud;
          url = ocUrl;
          inherit stateDir;

          # NO `settings` on purpose: an empty settings.opencloud is the
          # opencloud-init-config oneshot's trigger condition — providing any
          # file named opencloud.yaml would skip `opencloud init` and lose the
          # persisted IDM secrets (see module header). All overrides ride the
          # environment (env vars override YAML deterministically).
          environment = {
            # ── external IdP (Pocket ID) ──
            OC_EXCLUDE_RUN_SERVICES = "idp";
            OC_OIDC_ISSUER = issuer;
            # CSP/login-page wiring for the external IdP origin (no scheme).
            IDP_DOMAIN = "auth.${domain}";
            PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD = "jwt";
            PROXY_OIDC_REWRITE_WELLKNOWN = "true";
            PROXY_AUTOPROVISION_ACCOUNTS = "true";
            # preferred_username -> username is the proxy default mapping and
            # Pocket ID emits preferred_username; stated for the record.
            PROXY_USER_OIDC_CLAIM = "preferred_username";
            PROXY_USER_CS3_CLAIM = "username";

            # ── role assignment: declarative via Pocket ID groups ──
            # Upstream DEFAULT mapping applies (opencloudAdmin/opencloudUser/
            # opencloudSpaceAdmin/opencloudGuest) — Pocket ID userGroups below
            # carry exactly those names, so no role_mapping YAML is needed.
            PROXY_ROLE_ASSIGNMENT_DRIVER = "oidc";
            PROXY_ROLE_ASSIGNMENT_OIDC_CLAIM = "groups";
            # With the oidc driver every login maps from the claim; the
            # default-role fallback must stay off (upstream recommendation).
            GRAPH_ASSIGN_DEFAULT_USER_ROLE = "false";

            # ── internal service port (collision fix, 2026-10-26) ──
            # ocis defaults its embedded NATS to 127.0.0.1:9234 which
            # collides with signoz-clickhouse-raft: first deploy died as
            # bind-failure → supervisor 5-strike → systemd start-limit-hit.
            # 9233 stays clear of ocis's own 9235+ internal gRPC band;
            # server and in-process clients share this one config value.
            NATS_PORT = toString ports.opencloud-nats;

            # ── webfinger client discovery (defaults made explicit) ──
            # `groups` appended on every client: the role mapping reads the
            # groups claim from the user's token — a client that does not
            # request it produces the "no roles in user claims" login failure
            # (the desktop#217 class).
            WEBFINGER_WEB_OIDC_CLIENT_ID = "web";
            WEBFINGER_WEB_OIDC_CLIENT_SCOPES = "openid profile email groups";
            WEBFINGER_DESKTOP_OIDC_CLIENT_ID = "OpenCloudDesktop";
            WEBFINGER_DESKTOP_OIDC_CLIENT_SCOPES = "openid profile email offline_access groups";
            WEBFINGER_ANDROID_OIDC_CLIENT_ID = "OpenCloudAndroid";
            WEBFINGER_ANDROID_OIDC_CLIENT_SCOPES = "openid profile email offline_access groups";
          };

          # Consumed by opencloud-init-config (root oneshot) when it runs
          # `opencloud init`; inert afterwards. Random sops value — the
          # embedded admin has no login surface (idp excluded).
          environmentFile = config.sops.templates."opencloud-env".path;
        };

        # One secret only: the init-time embedded-admin password. The three
        # OIDC clients are PUBLIC (no secrets). Owner stays root — both
        # consuming units (init oneshot + opencloud.service) read the env file
        # as root/PID1 before dropping privileges.
        sops.secrets."opencloud_admin_password" = {
          sopsFile = ../../../platforms/nixos/secrets/opencloud.yaml;
          restartUnits = [ "opencloud.service" ];
        };
        sops.templates."opencloud-env" = {
          content = ''
            ADMIN_PASSWORD=${config.sops.placeholder.opencloud_admin_password}
          '';
          restartUnits = [ "opencloud.service" ];
        };

        # The nixpkgs module tmpfiles-creates stateDir (+idm) in early sysinit
        # — on a detached DAS that lands on the ROOT fs (shadow-dir class,
        # atticd doctrine). opencloud-storage-dir owns both, mount-gated.
        systemd.tmpfiles.settings."10-opencloud" = lib.mkForce { };
        users.users.opencloud.createHome = lib.mkForce false;

        systemd.services = {
          # The nixpkgs module's init oneshot (`opencloud init`, runs once per
          # host when /etc/opencloud/opencloud.yaml is absent) ships neither a
          # TimeoutStartSec nor an IO tier — both audit-gated (a wedged oneshot
          # start job defaults to an INFINITE timeout and holds the boot
          # transaction open). Convergence here, not an override of upstream.
          opencloud-init-config = {
            serviceConfig = lib.mkMerge [
              { TimeoutStartSec = "5min"; }
              ioTier.background
            ];
          };

          # Pool subvolume bootstrap (tq-storage-dir pattern): subvolume (so
          # btrbk-pool can snapshot it) + idm subdir the upstream tmpfiles
          # would have created. Idempotent; converges on every boot/deploy.
          # deploy-restart-audit: -storage-dir converger, restart per deploy
          # via the scripts/deploy.sh provisioner loop.
          opencloud-storage-dir = {
            description = "Create OpenCloud state subvolume on the HDD pool";
            wantedBy = [ "multi-user.target" ];
            before = [ "opencloud.service" ];
            unitConfig.RequiresMountsFor = [ stateDir ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "root";
                RemainAfterExit = true;
              }
              (harden {
                # subvolume create needs CAP_SYS_ADMIN, chown CAP_CHOWN, the
                # re-run chmod on the already-chowned dir CAP_FOWNER (tq
                # pattern); harden{}'s empty bounding set EPERMs all without.
                CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
                ReadWritePaths = [ "/mnt/pool/services" ];
              })
              (serviceOneshotDefaults { })
              ioTier.background
            ];
            script = ''
              dir=${stateDir}
              if [ ! -e "$dir" ]; then
                # Subvolume (not plain dir) so btrbk-pool can snapshot it —
                # mirrors the tq/atticd pool placement. Falls back to a plain
                # dir only on non-btrfs filesystems.
                if ! ${pkgs.btrfs-progs}/bin/btrfs subvolume create "$dir"; then
                  mkdir -p "$dir"
                fi
              else
                mkdir -p "$dir"
              fi
              chown opencloud:opencloud "$dir"
              chmod 0750 "$dir"
              # idm subdir: upstream tmpfiles created it; we own it now.
              mkdir -p "$dir/idm"
              chown opencloud:opencloud "$dir/idm"
              chmod 0750 "$dir/idm"
            '';
          };

          opencloud = {
            description = lib.mkForce "OpenCloud file sync and share platform";
            after = [
              "opencloud-storage-dir.service"
            ]
            ++ lib.optionals provisionEnabled [
              "pocket-id-provision.service"
              "pocket-id.service"
            ];
            wants = [
              "opencloud-storage-dir.service"
            ]
            ++ lib.optionals provisionEnabled [
              "pocket-id-provision.service"
              "pocket-id.service"
            ];
            # A detached DAS must fail the start as a dependency error, not
            # write into a root-fs shadow (immich/atticd doctrine).
            unitConfig.RequiresMountsFor = [ stateDir ];
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            serviceConfig = lib.mkMerge [
              # MemoryMax INTO harden (MemoryHigh derives; watermark audit)
              (harden { MemoryMax = "1G"; })
              (serviceDefaults { })
              # File platform on spinning RAID1 disks: BE/6 background.
              ioTier.background
              {
                # First start runs init + IDM/LDAP bootstrap under pool IO;
                # the global 3min ceiling is tight for it.
                TimeoutStartSec = "5min";
              }
            ];
          };
        };

        # Pocket ID: the three OpenCloud public PKCE clients + the role-mapping
        # user groups. Client IDs are PREDEFINED (OpenCloud webfinger hands
        # them to the clients); callbacks byte-match the clients' redirects
        # (upstream compose keycloak configs are the source of truth).
        services.pocket-id-config.provision = lib.optionalAttrs (options ? services.pocket-id-config) {
          extraOidcClients =
            let
              # All OpenCloud clients: public (no secret) + PKCE, matching the
              # upstream "public clients using authorization code flow with
              # PKCE" contract (docs external-idp.md requirements).
              opencloudClient = name: clientId: callbacks: {
                inherit name clientId;
                callbackURLs = callbacks;
                isPublic = true;
                pkceEnabled = true;
                launchURL = ocUrl;
              };
            in
            [
              (opencloudClient "OpenCloud Web" "web" [
                "${ocUrl}/oidc-callback.html"
                "${ocUrl}/oidc-silent-redirect.html"
              ])
              (opencloudClient "OpenCloud Desktop" "OpenCloudDesktop" [
                # Loopback redirects; Pocket ID's callback matcher implements
                # the OIDC loopback port exemption (any port matches these).
                "http://127.0.0.1"
                "http://localhost"
              ])
              (opencloudClient "OpenCloud Android" "OpenCloudAndroid" [
                "oc://android.opencloud.eu"
              ])
            ];

          # Role mapping groups: names MUST equal the upstream default role
          # mapping claim values (PROXY_ROLE_ASSIGNMENT_OIDC_CLAIM=groups +
          # default role_mapping). Unmapped users fail login — fail-closed is
          # the intended LAN-only pilot posture.
          userGroups = [
            {
              name = "opencloudAdmin";
              friendlyName = "OpenCloud Admins";
              memberUsernames = [ config.users.primaryUser ];
            }
            {
              name = "opencloudUser";
              friendlyName = "OpenCloud Users";
              memberUsernames = [ config.users.primaryUser ];
            }
          ];
        };

        # Service-integration registry entry (integration.nix): ONE
        # declaration fans out to Caddy vHost (plain — native OIDC, forward-
        # auth would double-auth), Gatus checks, dashboard tile, system-health
        # monitored unit. CAVEAT (flake-check-proven 2026-09-15): the
        # options?-guard does not survive a standalone import with enable=true
        # — VM tests MUST co-import integration.nix.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          opencloud = {
            subdomain = "cloud";
            port = ports.opencloud;
            # Layer 1 native OIDC — plain reverse_proxy, NEVER protectedVHost.
            vHost.layer = "plain";
            checks = [
              {
                # Liveness: `/` redirects (302) to the sign-in/IdP flow when
                # unauthenticated — "< 400" covers both the redirect and any
                # direct 200 render; a dead proxy answers nothing.
                name = "OpenCloud";
                group = "Files";
                path = "/";
                interval = "5m";
                conditions = [
                  "[STATUS] < 400"
                  "[RESPONSE_TIME] < 2000"
                ];
                alert = "OpenCloud down — cloud.${domain} unreachable. Check: systemctl status opencloud, journalctl -u opencloud";
              }
              {
                # Functional: webfinger is the client-discovery surface every
                # OpenCloud client (web/desktop/android) hits before login —
                # it proves the OIDC wiring answers, not just the web server.
                name = "OpenCloud WebFinger Discovery";
                group = "Files";
                path = "/.well-known/webfinger?resource=${ocUrl}";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*oidc-callback*)"
                ];
                alert = "OpenCloud webfinger discovery broken — clients cannot find their OIDC client config. Check journalctl -u opencloud";
              }
            ];
            homepage = {
              name = "OpenCloud";
              group = "Files";
              description = "File sync and share (Pocket ID SSO)";
              # No dashboard-icons pack icon exists for opencloud (404 at the
              # pinned pack rev AND main) — the eval-accepted http(s) URL form
              # is required (GitHub org avatar, stable).
              icon = "https://avatars.githubusercontent.com/opencloud-eu?size=256";
            };
            monitored = true;
            oidc = {
              # The web client rides the registry fan-out; OpenCloudDesktop/
              # OpenCloudAndroid are provisioned via extraOidcClients above
              # (this field carries a single client).
              name = "OpenCloud Web";
              clientId = "web";
              launchURL = ocUrl;
              callbackURLs = [
                "${ocUrl}/oidc-callback.html"
                "${ocUrl}/oidc-silent-redirect.html"
              ];
              isPublic = true;
              pkceEnabled = true;
            };
          };
        };
      };
    };
}
