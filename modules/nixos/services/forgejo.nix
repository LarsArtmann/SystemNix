# Forgejo self-hosted Git forge: GitHub sync, Actions runner, admin setup
_: {
  flake.nixosModules.forgejo =
    {
      pkgs,
      lib,
      config,
      options,
      utils,
      ...
    }:
    let
      inherit (config.users) primaryUser;
      cfg = config.services.forgejo;
      forgejoPkg = cfg.package;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        ports
        ioTier
        mkDnsGate
        mkOidcGate
        mkFilesystem
        ;
      forgejoPort = config.services.forgejo.settings.server.HTTP_PORT;
      forgejoUrl = "http://localhost:${toString forgejoPort}";
      stateDir = config.services.forgejo.stateDir;
      forgejoBackupDir = "/mnt/pool/backups/forgejo";
      # Dedicated Samsung-TLC subvolume storage (Set-B, 2026-09-18 staged-
      # primary plan docs/planning/2026-09-18_16-44_*). Inert until enabled.
      dedicated = config.services.forgejo.dedicatedSubvolume;
      dataDirMountUnit = "${utils.escapeSystemdPath stateDir}.mount";
      hostName = config.networking.hostName;
      runnerLabels = [
        "ubuntu-latest:docker://node:22-bookworm"
        "ubuntu-22.04:docker://node:22-bookworm"
        "native:host"
      ];
      runnerSettings = {
        log.level = "info";
        runner.capacity = 2;
        container.network = "host";
      };
      runnerConfigFile = (pkgs.formats.yaml { }).generate "runner-config.yaml" runnerSettings;

      inherit
        (import ./_forgejo-scripts.nix {
          inherit
            pkgs
            lib
            config
            primaryUser
            cfg
            forgejoPkg
            forgejoUrl
            stateDir
            hostName
            runnerLabels
            runnerConfigFile
            ;
        })
        mirrorGithubScript
        reconcileMirrorsScript
        mirrorStarredScript
        setupScript
        ensurePasswordFile
        adminSetup
        tokenGen
        hermesForgejoToken
        hermesForgejoTokenDeliver
        hermesCfg
        genRunnerToken
        registerRunner
        oidcSetupScript
        addKeysScript
        ;

      forgejoDnsGate = mkDnsGate {
        inherit pkgs;
        serviceName = "forgejo-oidc";
        hostname = "auth.home.lan";
        maxAttempts = 30;
      };

      # DNS resolving is not enough: on the 2026-08-22 crash-recovery boot
      # forgejo-oidc-setup failed 39s after boot with "dial tcp
      # 192.168.1.150:443: connection refused" — auth.home.lan resolved fine
      # (dnsblockd was up) but Caddy had not bound :443 yet. The OIDC gate
      # polls the discovery endpoint (DNS → TLS → HTTP) for up to 120s,
      # matching the gatus/oauth2-proxy/browser-history pattern.
      forgejoOidcGate = mkOidcGate {
        inherit pkgs;
        domain = config.networking.domain;
        serviceName = "forgejo-oidc-setup";
      };

      # The MAIN forgejo daemon resolves auth.<domain> exactly once at
      # startup to register the PocketID OIDC auth source, and with
      # ENABLE_INTERNAL_SIGNIN=false there is no fallback login. On the
      # 2026-08-22 boot forgejo started seconds before dnsblockd answered
      # its first query — "Unable to register source: PocketID ... lookup
      # auth.home.lan: no such host" — and logins stayed dead until the
      # next restart. DNS gate (getent probe) + ordering behind
      # dnsblockd/caddy/pocket-id fixes the class without hard-coupling
      # forgejo's availability to Caddy TLS (ordering only, no probe of
      # :443 — a hard down Caddy degrades logins, not the whole forge).
      forgejoMainDnsGate = mkDnsGate {
        inherit pkgs;
        serviceName = "forgejo";
        hostname = "auth.${config.networking.domain}";
        maxAttempts = 30;
      };

      # Notifications (issues, PRs, mirrors) ride the central Postfix
      # null-client relay. Without the relay, the mailer block stays empty →
      # [mailer] ENABLED stays unset → forgejo silently sends nothing (the
      # pre-relay status quo). PROTOCOL "" = plain SMTP: the relay is
      # loopback-only and unauthenticated; TLS/credentials live on the
      # relay→upstream leg.
      mailRelayEnabled = config.services.mail-relay.enable or false;
    in
    {
      options = {
        services.forgejo.sshKeys = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          default = { };
          description = ''
            Declarative SSH public keys for Forgejo users. Keys are idempotent:
            existing keys are matched by their raw string and left unchanged.
            Defaults to the primary user's NixOS authorized keys.
          '';
        };

        services.forgejo.dedicatedSubvolume = lib.mkEnableOption ''
          a dedicated BTRFS subvolume (subvol=hot/forgejo on the Samsung TLC
          disk, by-label tlc) mounted AT the existing stateDir — Set-B
          storage per docs/planning/2026-09-15_per-service-btrfs-subvolumes-
          analysis.md: primary-grade state that rides its OWN btrbk
          snapshot/send leg (8h) instead of the QLC @ snapshots.

          Ships INERT. Enable ONLY after scripts/migrate-forgejo-subvol.sh
          `finalize` has moved the data — mounting over the un-migrated dir
          would shadow it (the ClickHouse shadow-dir class), and the unit
          family below is mount-gated so an absent Samsung degrades to
          forgejo NOT starting (loud, Gatus-visible), never split-brain.
        '';
      };

      config = lib.mkIf config.services.forgejo.enable {
        services.forgejo = {
          sshKeys = lib.mkDefault {
            ${primaryUser} = config.users.users.${primaryUser}.openssh.authorizedKeys.keys;
          };

          package = pkgs.forgejo-lts;

          database.type = "sqlite3";

          lfs.enable = true;

          dump = {
            enable = true;
            interval = "weekly";
          };

          stateDir = "/var/lib/forgejo";

          settings = {
            DEFAULT.APP_NAME = "Local Git Forge";

            server = {
              HTTP_PORT = ports.forgejo;
              ROOT_URL = "https://forgejo.${config.networking.domain}/";
              DOMAIN = "forgejo.${config.networking.domain}";
            };

            repository = {
              DEFAULT_BRANCH = "main";
              ENABLE_PUSH_CREATE_USER = true;
              DEFAULT_PUSH_CREATE_PRIVATE = true;
            };

            mirror = {
              ENABLED = true;
              DEFAULT_INTERVAL = "8h";
              MIN_INTERVAL = "10m";
            };

            "cron.update_mirrors" = {
              ENABLED = true;
              SCHEDULE = "@every 30m";
              RUN_AT_START = false;
              PULL_LIMIT = 50;
              PUSH_LIMIT = 50;
            };

            ui = {
              DEFAULT_THEME = "forgejo-auto";
              THEMES = "forgejo-auto,forgejo-light,forgejo-dark,arc-green";
            };

            service = {
              DISABLE_REGISTRATION = true;
              REQUIRE_SIGNIN_VIEW = false;
              # SSO-only: hide password form, block password auth entirely.
              # Git HTTPS still works via access tokens (not affected).
              ENABLE_INTERNAL_SIGNIN = false;
              ENABLE_BASIC_AUTHENTICATION = false;
            };

            oauth2_client = {
              ENABLE_AUTO_REGISTRATION = true;
              USERNAME = "email";
              UPDATE_AVATAR = true;
              ACCOUNT_LINKING = "auto";
            };

            session = {
              COOKIE_SECURE = true;
            };

            log = {
              LEVEL = "Info";
              ROOT_PATH = "${stateDir}/log";
            };

            "git.timeout" = {
              MIRROR = 600;
              CLONE = 600;
              PULL = 600;
            };

            mailer =
              { }
              // lib.optionalAttrs mailRelayEnabled {
                ENABLED = true;
                PROTOCOL = "";
                SMTP_ADDR = "127.0.0.1";
                SMTP_PORT = ports.mail-relay;
                # User/PASSWD stay unset → no AUTH (the relay only accepts
                # loopback and authenticates upstream itself). FROM must be
                # on the provider-verified domain — same constraint as the
                # relay's fromAddress.
                FROM = "Forgejo <${config.services.mail-relay.fromAddress}>";
              };

            actions = {
              ENABLED = true;
              DEFAULT_ACTIONS_URL = "github";
            };

            other = {
              SHOW_FOOTER_VERSION = false;
              SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
            };

            federation = {
              ENABLED = true;
            };
          };
        };

        systemd = {
          services.forgejo = {
            after = [
              "caddy.service"
              "pocket-id.service"
            ]
            ++ forgejoMainDnsGate.after;
            wants = [
              "caddy.service"
              "pocket-id.service"
            ]
            ++ forgejoMainDnsGate.wants;
            unitConfig = lib.mkMerge [
              {
                StartLimitBurst = lib.mkForce 3;
                StartLimitIntervalSec = lib.mkForce 300;
              }
              # Dedicated-subvolume storage (plan gate G1): the daemon
              # pulls the subvol mount into its start transaction and
              # refuses to start against a shadow dir — an absent Samsung
              # degrades to forgejo DOWN (loud, Gatus), never split-brain.
              (lib.mkIf dedicated {
                RequiresMountsFor = [ stateDir ];
                ConditionPathIsMountPoint = stateDir;
              })
            ];
            serviceConfig = lib.mkMerge [
              (harden {
                ProtectHome = lib.mkForce false;
                NoNewPrivileges = false;
              })
              (serviceDefaults { })
              {
                ExecStartPre = lib.mkBefore [ ("+" + lib.getExe ensurePasswordFile) ];
                # DNS gate budget is 180s; ceiling must exceed it
                # (gate-timeout-audit floor: 4min).
                TimeoutStartSec = "4min";
              }
              { ExecStartPre = forgejoMainDnsGate.serviceConfig.ExecStartPre; }
            ];
            preStart = lib.getExe adminSetup;
          };

          services.forgejo-github-sync = {
            description = "Sync all GitHub repos to Forgejo";
            after = [
              "forgejo.service"
              "forgejo-generate-token.service"
              "network-online.target"
            ];
            wants = [ "network-online.target" ];
            requires = [ "forgejo.service" ];
            inherit onFailure;
            unitConfig.RequiresMountsFor = lib.optionals dedicated [ stateDir ];
            # Timer-driven oneshot: the timer IS the retry mechanism.
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            restartTriggers = [
              (lib.getExe mirrorGithubScript)
              (lib.getExe reconcileMirrorsScript)
            ];
            path = [
              pkgs.curl
              pkgs.jq
              pkgs.gh
            ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = primaryUser;
                EnvironmentFile = [
                  config.sops.templates."forgejo-sync.env".path
                  "-${stateDir}/.admin-token.env"
                ];
                # Sequential phases: (1) create missing mirrors (incl. private
                # repos since the listing switch to /user/repos), (2) reconcile
                # renames/transfers/deletions of existing mirrors.
                ExecStart = [
                  (lib.getExe mirrorGithubScript)
                  (lib.getExe reconcileMirrorsScript)
                ];
                # First run after the private-repo listing switch migrates
                # ~200 repos (2-8s each, synchronous migrate API) — the 3min
                # global default would kill it mid-batch. The migrate is
                # idempotent (existence checks), so a timeout converges on
                # the next 6h timer run.
                TimeoutStartSec = "2h";
              }
              (serviceOneshotDefaults { })
              (harden {
                ProtectHome = false;
                ProtectSystem = false;
                # The unit itself only runs curl/jq/gh — the git clones of a
                # migration happen server-side inside forgejo.service's cgroup.
                MemoryMax = "1G";
              })
              # Batch backup job: must never compete with the desktop or
              # interactive SSH for I/O on the QLC NAND.
              ioTier.background
            ];
          };

          timers.forgejo-github-sync = {
            description = "Sync GitHub repos to Forgejo every 6 hours";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "5m";
              OnUnitActiveSec = "6h";
              Unit = "forgejo-github-sync.service";
              Persistent = true;
            };
          };

          # Full forgejo dump (repos + DB + config + LFS) to the mirrored HDD
          # pool — forgejo previously had NO application-level backup at all,
          # only the nightly btrbk @-snapshot send. Zip is a restore-ready
          # unit even when the whole NVMe is gone (3-drive repurposing, 2026-08-16).
          services.forgejo-backup = {
            description = "Forgejo full dump to the HDD pool";
            after = [ "forgejo.service" ];
            wants = [ "forgejo.service" ];
            inherit onFailure;
            unitConfig.RequiresMountsFor = [ forgejoBackupDir ] ++ lib.optionals dedicated [ stateDir ];
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "1G";
                ReadWritePaths = [ forgejoBackupDir ];
              })
              (serviceOneshotDefaults { })
              ioTier.background
              {
                Type = "oneshot";
                User = "forgejo";
                Group = "forgejo";
                WorkingDirectory = stateDir;
                TimeoutStartSec = "30min";
              }
            ];
            script = ''
              set -euo pipefail
              stamp="$(date +%Y%m%d-%H%M%S)"
              # PrivateTmp gives the unit a writable /tmp namespace — the
              # dump tempdir lives there and is reaped automatically on stop.
              tmp="$(mktemp -d)"
              trap 'rm -rf "$tmp"' EXIT
              ${lib.getExe forgejoPkg} dump \
                --config ${stateDir}/custom/conf/app.ini \
                --tempdir "$tmp" \
                --type zip \
                --file ${forgejoBackupDir}/forgejo-$stamp.zip
              find ${forgejoBackupDir} -name "forgejo-*.zip" -mtime +7 -delete
              echo "forgejo-backup: wrote forgejo-$stamp.zip"
            '';
          };

          timers.forgejo-backup = {
            description = "Daily Forgejo dump to the HDD pool";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*-*-* 03:30:00";
              Persistent = true;
              RandomizedDelaySec = "15m";
            };
          };
        };

        # --- Hermes Agent read-only access (added 2026-08-19, PR: forgejo-hermes-agent) ---
        # mkIf hermes: the token is chown'd to the hermes user in ExecStartPost,
        # which only exists when the hermes service is enabled.
        # hermesCfg (from _forgejo-scripts.nix) uses 'or {}' so a standalone
        # nixosModules.forgejo consumer without nixosModules.hermes evaluates cleanly.
        systemd.services.forgejo-hermes-token = lib.mkIf (hermesCfg.enable or false) {
          description = "Provision hermes-agent Forgejo user + read-only token";
          after = [
            "forgejo.service"
            "forgejo-generate-token.service"
          ];
          wants = [ "forgejo.service" ];
          wantedBy = [ "forgejo.service" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          restartTriggers = [
            (lib.getExe hermesForgejoToken)
            (lib.getExe hermesForgejoTokenDeliver)
          ];
          unitConfig.RequiresMountsFor = lib.optionals dedicated [ stateDir ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              # forgejo-user idiom (tokenGen): CLI runs directly, no runuser —
              # PAM cannot open a session inside harden {} (documented gotcha,
              # 2026-07-17 forgejo-oidc-setup incident). The only root step is
              # the delivery below.
              User = "forgejo";
              Group = "forgejo";
              # 30 readiness tries × (curl --max-time 5 + sleep 1) + CLI ops ≈ 3min budget
              TimeoutStartSec = "4min";
              RemainAfterExit = true;
              # "+" = full-privilege escape hatch (gitea-runner's
              # +forgejo-gen-runner-token idiom): installs the staged token as
              # hermes:hermes 0400 into /run. Runs after ExecStart on every
              # successful start — i.e. on boot and on explicit restart of this
              # unit (deploy.sh restarts it post-switch). It does NOT rerun on a
              # plain forgejo.service restart because RemainAfterExit keeps this
              # unit active and wantedBy skips already-active units.
              ExecStartPost = [ ("+" + lib.getExe hermesForgejoTokenDeliver) ];
            }
            (harden { })
            (serviceOneshotDefaults { })
          ];
          script = lib.getExe hermesForgejoToken;
        };

        systemd.services.forgejo-generate-token = {
          description = "Generate Forgejo API token";
          after = [ "forgejo.service" ];
          wants = [ "forgejo.service" ];
          wantedBy = [ "forgejo.service" ];
          restartTriggers = [ (lib.getExe tokenGen) ];
          unitConfig.RequiresMountsFor = lib.optionals dedicated [ stateDir ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "forgejo";
              Group = "forgejo";
              RemainAfterExit = true;
            }
            (harden { })
          ];
          script = lib.getExe tokenGen;
        };

        systemd.services.forgejo-oidc-setup = lib.mkIf config.services.pocket-id-config.enable {
          description = "Configure Forgejo OIDC authentication source (Pocket ID)";
          after = [
            "forgejo.service"
            "pocket-id-provision.service"
            "dnsblockd.service"
          ]
          ++ forgejoOidcGate.after;
          wants = [
            "forgejo.service"
            "pocket-id-provision.service"
            "dnsblockd.service"
          ]
          ++ forgejoOidcGate.wants;
          wantedBy = [ "forgejo.service" ];
          restartTriggers = [ (lib.getExe oidcSetupScript) ];
          unitConfig.RequiresMountsFor = lib.optionals dedicated [ stateDir ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "forgejo";
              Group = "forgejo";
              RemainAfterExit = true;
              LoadCredential = [
                "forgejo-oidc-client-secret:${config.services.pocket-id.dataDir}/client-secrets/forgejo"
              ];
              ExecStartPre =
                forgejoDnsGate.serviceConfig.ExecStartPre ++ forgejoOidcGate.serviceConfig.ExecStartPre;
              # Must exceed the 300s OIDC gate budget (slow-boot dnsblockd)
              TimeoutStartSec = "6min";
            }
            (harden { })
            (serviceOneshotDefaults { })
          ];
          script = lib.getExe oidcSetupScript;
        };

        systemd.services.forgejo-ssh-keys = {
          description = "Add declarative SSH keys to Forgejo users";
          after = [
            "forgejo.service"
            "forgejo-generate-token.service"
          ];
          wants = [ "forgejo-generate-token.service" ];
          wantedBy = [ "forgejo.service" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          restartTriggers = [ (lib.getExe addKeysScript) ];
          unitConfig.RequiresMountsFor = lib.optionals dedicated [ stateDir ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "forgejo";
              Group = "forgejo";
              RemainAfterExit = true;
            }
            (harden { })
            (serviceOneshotDefaults { })
          ];
          script = lib.getExe addKeysScript;
        };

        # --- Dedicated Samsung-TLC subvolume at the dataDir (Set-B storage,
        # staged-primary plan gate G1). Everything below is mkIf dedicated:
        # the option flips on ONLY after the migration script moved the data.
        fileSystems.${stateDir} = lib.mkIf dedicated (mkFilesystem {
          device = "/dev/disk/by-label/tlc";
          fsType = "btrfs";
          options = [
            "subvol=hot/forgejo"
            "compress=zstd"
            "noatime"
            "nodiscard"
            "space_cache=v2"
            # nofail: a missing Samsung degrades to forgejo NOT starting
            # (ConditionPathIsMountPoint on the family head), never a dead
            # boot.
            "nofail"
          ];
        });

        systemd.services.forgejo-subvol-bootstrap = lib.mkIf dedicated {
          description = "Idempotently create the forgejo subvolume on the hot-DB disk";
          # The mount unit pulls this in (WantedBy → Wants) and waits
          # (before): fstab cannot create BTRFS subvolumes, so the subvol
          # must exist before ${dataDirMountUnit} can ever mount it — the
          # test-cv pool-fmt chicken-and-egg class.
          wantedBy = [ dataDirMountUnit ];
          before = [ dataDirMountUnit ];
          after = [ "mnt-hot.mount" ];
          wants = [ "mnt-hot.mount" ];
          unitConfig.RequiresMountsFor = [ "/mnt/hot" ];
          path = [
            pkgs.btrfs-progs
            pkgs.coreutils
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            (serviceOneshotDefaults { })
            (harden {
              # btrfs subvolume create is a privileged ioctl; chown for the
              # forgejo user (harden{}'s empty bounding set would EPERM both).
              CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_CHOWN CAP_DAC_OVERRIDE";
              # The MOUNT ROOT — never a subdir inside it (226 class):
              # RequiresMountsFor above guarantees the root exists before
              # the namespace is built.
              ReadWritePaths = [ "/mnt/hot" ];
            })
          ];
          script = ''
            set -euo pipefail
            subvol=/mnt/hot/hot/forgejo
            if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$subvol" >/dev/null 2>&1; then
              echo "forgejo-subvol-bootstrap: $subvol already exists"
            else
              mkdir -p /mnt/hot/hot
              ${pkgs.btrfs-progs}/bin/btrfs subvolume create "$subvol"
              echo "forgejo-subvol-bootstrap: created $subvol"
            fi
            chown forgejo:forgejo "$subvol"
            chmod 0750 "$subvol"
          '';
        };

        # Satellite mount-gating lives inside each unit's own block above
        # (unitConfig.RequiresMountsFor — same-module attrpaths cannot
        # re-open an already-defined unit from a second assignment).

        assertions = lib.optionals dedicated [
          {
            assertion = config.fileSystems ? "/mnt/hot";
            message = "services.forgejo.dedicatedSubvolume requires the /mnt/hot Samsung-toplevel mount (hardware-configuration.nix) — forgejo-subvol-bootstrap creates the subvol through it.";
          }
        ];

        services.gitea-actions-runner = {
          package = pkgs.forgejo-runner;
          instances.${hostName} = {
            enable = true;
            name = hostName;
            url = "${forgejoUrl}";
            tokenFile = "/run/forgejo-runner/token";
            labels = runnerLabels;
            settings = runnerSettings;
          };
        };

        systemd.services."gitea-runner-${utils.escapeSystemdPath hostName}" = {
          after = [ "forgejo.service" ];
          wants = [ "forgejo.service" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              EnvironmentFile = lib.mkForce "-/run/forgejo-runner/token";
              ExecStartPre = lib.mkForce [
                ("+" + lib.getExe genRunnerToken)
                (lib.getExe registerRunner)
              ];
              TimeoutStartSec = "3min";
              MemoryMax = "16G";
            }
            ioTier.build
          ];
        };

        # Fix ownership after Gitea→Forgejo data migration (recursively)
        systemd.tmpfiles.rules = [
          "Z ${stateDir} 0750 forgejo forgejo - -"
          "d ${forgejoBackupDir} 0750 forgejo forgejo -"
        ];

        environment.systemPackages = [
          mirrorGithubScript
          reconcileMirrorsScript
          mirrorStarredScript
          setupScript
        ];

        # Service-integration registry entry: the forgejo vHost (Layer 1 — native
        # OIDC via Pocket ID; forward-auth would double-auth), Gatus
        # health + mirror-sync checks, backup freshness, unit-state
        # monitoring, and the OIDC client registration. The homepage tile
        # stays static in homepage.nix (unconditional there).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          forgejo = {
            inherit (cfg) enable;
            subdomain = "forgejo";
            port = cfg.settings.server.HTTP_PORT;
            vHost.layer = "plain";
            checks = [
              {
                name = "Forgejo";
                group = "Development";
                url = "http://localhost:${toString cfg.settings.server.HTTP_PORT}/api/v1/version";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alert = "Forgejo down — git forge unavailable";
              }
              {
                name = "Forgejo Mirror Sync";
                group = "Development";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*system_forgejo_mirror_scrape_errors 0*)"
                  "[BODY] == pat(*system_forgejo_mirror_sync_stalled 0*)"
                  "[BODY] == pat(*system_forgejo_mirror_erroring 0*)"
                ];
                alert = "Forgejo pull-mirror syncing broken. stalled=1: freshest mirror sync >10h old — dead queue (restart forgejo.service; the unique queue wedges after a hard freeze, cron pushes then dedup-skip silently). erroring=1: syncs actively failing — journalctl -u forgejo --grep SyncMirrors (credential-helper ENOENT / DNS allowlist rejects). scrape_errors=1: forgejo sqlite unreadable.";
              }
              {
                # Reconcile OUTCOMES (renames/transfers/deletions) — the classes
                # that were journal-only before 2026-09-18. Absent metrics = the
                # sync unit has never completed a run since the reconcile script
                # shipped; scrape_errors=0 is only written by a completed run.
                name = "Forgejo Mirror Reconcile";
                group = "Development";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\nforgejo_mirror_reconcile_scrape_errors 0*)"
                  "[BODY] != pat(*\nforgejo_mirror_total 0*)"
                ];
                alert = "Forgejo mirror reconcile broken or never completed: journalctl -u forgejo-github-sync (listing failure, publish warn, or the unit never finished a run since the 2026-09-18 reconcile ship).";
              }
            ];
            backup = {
              # Daily forgejo dump (repos+DB+config, 03:30 + randomized delay).
              directory = "/mnt/pool/backups/forgejo";
              filePattern = "*.zip";
              maxAgeHours = 25;
            };
            monitored = true;
            oidc = {
              name = "Forgejo";
              clientId = "forgejo";
              launchURL = "https://forgejo.${config.networking.domain}";
              callbackURLs = [ "https://forgejo.${config.networking.domain}/user/oauth2/PocketID/callback" ];
            };
          };
        };

        # The sync unit itself (mirror-github + reconcile, timer-driven):
        # unit failure visibility via system-health state metrics — the
        # reconcile-outcome gatus check only sees COMPLETED runs, so a failed
        # phase (listing guard, reconcile error) must page through unit state.
        services.system-health = lib.optionalAttrs (options ? services.system-health) {
          extraMonitoredServices = lib.mkAfter [ "forgejo-github-sync" ];
        };
      };
    };
}
