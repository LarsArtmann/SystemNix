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

      # Catppuccin themes (Mocha matches the box-wide theme; Latte for light
      # pref; auto follows prefers-color-scheme). Each file is a small delta
      # that @imports the upstream theme (stable unhashed filename) and
      # overrides variables only. tmpfiles L+ symlinks them into the custom
      # dir on every activation; forgejo serves custom assets over built-ins.
      forgejoThemes = {
        "theme-catppuccin-auto.css" = ./_forgejo-themes/theme-catppuccin-auto.css;
        "theme-catppuccin-mocha.css" = ./_forgejo-themes/theme-catppuccin-mocha.css;
        "theme-catppuccin-latte.css" = ./_forgejo-themes/theme-catppuccin-latte.css;
      };

      # ui.THEMES audit: every listed entry must resolve to a served
      # theme-<name>.css or the picker 404s (the dead arc-green entry,
      # fixed 2026-09-23). Custom files come from forgejoThemes; upstream
      # files ship in the package data output (re-verify on package bumps).
      upstreamThemeNames = [
        "forgejo-auto"
        "forgejo-auto-deuteranopia-protanopia"
        "forgejo-auto-tritanopia"
        "forgejo-dark"
        "forgejo-dark-deuteranopia-protanopia"
        "forgejo-dark-tritanopia"
        "forgejo-light"
        "forgejo-light-deuteranopia-protanopia"
        "forgejo-light-tritanopia"
        "gitea-auto"
        "gitea-dark"
        "gitea-light"
      ];
      customThemeNames = map (file: builtins.head (builtins.match "theme-(.*)[.]css" file)) (
        builtins.attrNames forgejoThemes
      );
      listedThemes = lib.remove "" (lib.splitString "," (cfg.settings.ui.THEMES or ""));
      unbackedThemes = lib.subtractLists (upstreamThemeNames ++ customThemeNames) listedThemes;
      defaultTheme = cfg.settings.ui.DEFAULT_THEME or "";
      themeAuditErrors =
        lib.optionals (unbackedThemes != [ ]) [
          "ui.THEMES entries with no backing theme-<name>.css: ${lib.concatStringsSep ", " unbackedThemes} (custom files: forgejoThemes attrset; upstream set: ${forgejoPkg.name})"
        ]
        ++ lib.optionals (defaultTheme != "" && !builtins.elem defaultTheme listedThemes) [
          "ui.DEFAULT_THEME '${defaultTheme}' is not listed in ui.THEMES"
        ];
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
        pushMirrorScript
        flipRepoScript
        mirrorHealthScript
        censusScript
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

        # Repos that are CANONICAL on forgejo (native, NOT mirrors) and must
        # push outbound to GitHub (staged-primary plan M05). Every listed
        # repo gets a push mirror attached (interval 8h + sync_on_commit) by
        # forgejo-push-mirror, phase 3 of forgejo-github-sync. The script
        # REFUSES any repo that is still a pull mirror — flip it first with
        # forgejo-flip@<name>.service (plan M06). Default [] = the phase is
        # absent entirely; do NOT add a repo before it exists natively.
        services.forgejo.canonicalRepos = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Repo names owned by the primary forgejo user that are canonical
            (native) on forgejo. Each gets an outbound GitHub push mirror
            (8h interval, sync-on-commit) attached idempotently by the sync
            unit's third phase. Repos still marked as pull mirrors are
            refused loudly — run forgejo-flip@<name>.service first.
          '';
        };
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
            DEFAULT = {
              APP_NAME = "Local Git Forge";
              APP_SLOGAN = "Beyond coding. We forge.";
            };

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
              DEFAULT_THEME = "catppuccin-auto";
              THEMES = "catppuccin-auto,catppuccin-mocha,catppuccin-latte,forgejo-auto,forgejo-light,forgejo-dark";
            };

            # settings is 2-level (section.key atoms): nested subsections
            # like ui.meta.DESCRIPTION must use a quoted flat section key.
            "ui.meta" = {
              DESCRIPTION = "Self-hosted git forge: code, mirrors, CI, and packages on the home lab.";
              KEYWORDS = "git,forge,forgejo,ci,home-lab";
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
              SHOW_FOOTER_POWERED_BY = false;
            };

            # Avatars stay local: no external gravatar lookups (privacy +
            # latency). OIDC-provided avatars (oauth2_client.UPDATE_AVATAR)
            # are unaffected — they are uploaded copies.
            picture = {
              DISABLE_GRAVATAR = true;
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
              (lib.getExe pushMirrorScript)
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
                # renames/transfers/deletions of existing mirrors, (3) attach
                # GitHub push mirrors to canonical repos (plan M05).
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
              # Phase 3, gated: with canonicalRepos = [] (default) the phase
              # is absent; a non-empty list runs forgejo-push-mirror after
              # reconcile, which refuses any repo still marked mirror==true.
              (lib.mkIf (cfg.canonicalRepos != [ ]) {
                Environment = [
                  "FORGEJO_CANONICAL_REPOS=${lib.concatStringsSep " " cfg.canonicalRepos}"
                ];
                ExecStart = [ (lib.getExe pushMirrorScript) ];
              })
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

        # --- Staged-primary Phase 1 capability units (plan M05-M08) ---

        # Operator-run flip (plan M06): converts a disposable pull mirror to
        # a native canonical repo + GitHub push mirror. Template unit so the
        # operator path gets the sync unit's env (sops GITHUB_TOKEN + forgejo
        # admin token) and OnFailure paging without any secret landing on a
        # command line:
        #   sudo systemctl start forgejo-flip@<name>.service
        systemd.services."forgejo-flip@" = {
          description = "Flip %i from disposable pull mirror to native canonical repo";
          after = [
            "forgejo.service"
            "forgejo-generate-token.service"
          ];
          wants = [ "forgejo.service" ];
          inherit onFailure;
          startLimitBurst = 2;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = primaryUser;
              EnvironmentFile = [
                config.sops.templates."forgejo-sync.env".path
                "-${stateDir}/.admin-token.env"
              ];
              ExecStart = "${lib.getExe flipRepoScript} %i";
              # A migrate (clone + issues/PRs/wiki/LFS import) of a large
              # repo can take minutes — clear of the 3min global default.
              TimeoutStartSec = "30min";
            }
            (serviceOneshotDefaults { })
            (harden {
              # reads the reconcile state (pending-deletes) under $HOME
              ProtectHome = "read-only";
              MemoryMax = "1G";
            })
            ioTier.background
          ];
        };

        # Dry-run twin: precondition checks + the flip PLAN with zero
        # changes. No onFailure — a refused precondition is a report, not
        # an incident.
        systemd.services."forgejo-flip-check@" = {
          description = "Dry-run precondition check for flipping %i (no changes)";
          after = [
            "forgejo.service"
            "forgejo-generate-token.service"
          ];
          wants = [ "forgejo.service" ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = primaryUser;
              EnvironmentFile = [
                config.sops.templates."forgejo-sync.env".path
                "-${stateDir}/.admin-token.env"
              ];
              ExecStart = "${lib.getExe flipRepoScript} %i --dry-run";
              TimeoutStartSec = "5min";
            }
            (serviceOneshotDefaults { })
            (harden {
              ProtectHome = "read-only";
              MemoryMax = "1G";
            })
          ];
        };

        # Dead pull-mirror detection (plan M07, redesigned 2026-09-18):
        # per-repo failing syncs from forgejo's notice table, minus the
        # reconcile script's known-stale set. TouchMirror-proof — see
        # mirrorHealthScript's header for the falsified-heuristic evidence.
        systemd.services.forgejo-mirror-health = {
          description = "Dead pull-mirror detection (notice table, TouchMirror-proof)";
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              ExecStart = lib.getExe mirrorHealthScript;
            }
            (serviceOneshotDefaults { })
            (harden {
              # reads the reconcile state under the primary user's 0700 home
              ProtectHome = "read-only";
              # mktemp+rename over a possible foreign-owned leftover in the
              # sticky 1777 textfile dir (audit-textfile-tmp pattern)
              CapabilityBoundingSet = "CAP_FOWNER";
              ReadWritePaths = [ "/var/lib/prometheus-node-exporter/textfile_collectors" ];
            })
          ];
        };

        systemd.timers.forgejo-mirror-health = {
          description = "Periodic dead pull-mirror detection";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* *:00/5:00";
            Persistent = true;
          };
        };

        # Live-forge census (plan M08): native-vs-mirror split per owner —
        # the flip-rollout tracking numbers. Manual, no timer:
        #   sudo systemctl start forgejo-census && journalctl -u forgejo-census
        systemd.services.forgejo-census = {
          description = "Live-forge census: native vs mirror split per owner";
          after = [
            "forgejo.service"
            "forgejo-generate-token.service"
          ];
          wants = [ "forgejo.service" ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = primaryUser;
              EnvironmentFile = [
                config.sops.templates."forgejo-sync.env".path
                "-${stateDir}/.admin-token.env"
              ];
              ExecStart = lib.getExe censusScript;
              TimeoutStartSec = "10min";
            }
            (serviceOneshotDefaults { })
            (harden {
              MemoryMax = "512M";
            })
            ioTier.background
          ];
        };

        # --- Hermes Agent forgejo access (added 2026-08-19 read-only; owner
        # decision 2026-09-23: write:repository token + write-collaborator on
        # every lars-owned repo — converger sweep; repo-level deletion stays
        # structurally impossible via the collaborator role) ---
        # mkIf hermes: the token is chown'd to the hermes user in ExecStartPost,
        # which only exists when the hermes service is enabled.
        # hermesCfg (from _forgejo-scripts.nix) uses 'or {}' so a standalone
        # nixosModules.forgejo consumer without nixosModules.hermes evaluates cleanly.
        systemd.services.forgejo-hermes-token = lib.mkIf (hermesCfg.enable or false) {
          description = "Provision hermes-agent Forgejo user + write token + repo grants";
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
              # 30 readiness tries × (curl --max-time 5 + sleep 1) + CLI ops + the
              # per-repo collaborator sweep (~50-200ms per PUT on loopback across
              # ~200 repos) ≈ 6min budget
              TimeoutStartSec = "6min";
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
              # forgejo user; CAP_FOWNER for the chmod on the freshly chown'd
              # subvol — chmod is FOWNER-gated for non-owners and
              # CAP_DAC_OVERRIDE does NOT cover it (the sibling
              # hot-user-caches bootstrap failed live on exactly this,
              # 2026-09-20). harden{}'s empty bounding set would EPERM all.
              CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER";
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

        assertions = lib.optionals dedicated [
          {
            assertion = config.fileSystems ? "/mnt/hot";
            message = "services.forgejo.dedicatedSubvolume requires the /mnt/hot Samsung-toplevel mount (hardware-configuration.nix) — forgejo-subvol-bootstrap creates the subvol through it.";
          }
        ];

        # 8h btrbk leg freshness collector (fail-closed): reads the newest
        # RECEIVED subvol pool-side and emits forgejo_subvol_backup_* — the
        # Gatus check on the registry entry below fails on absence of the
        # fresh=1 metric (no phantom greens; scrape failure writes only
        # scrape_errors 1). Threshold 12h = one missed 8h slot tolerated.
        systemd.services.forgejo-subvol-backup-metrics = lib.mkIf dedicated {
          description = "Forgejo subvol backup freshness metrics (8h btrbk leg)";
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
            }
            (serviceOneshotDefaults { })
            (harden {
              # mktemp+rename over a possible foreign-owned leftover in the
              # sticky 1777 textfile dir (audit-textfile-tmp pattern).
              CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_READ_SEARCH";
              ReadWritePaths = [ "/var/lib/prometheus-node-exporter/textfile_collectors" ];
            })
          ];
          path = [
            pkgs.coreutils
            pkgs.gnugrep
          ];
          script = ''
            set -euo pipefail
            dir=/mnt/pool/backups/forgejo-subvol
            tf=/var/lib/prometheus-node-exporter/textfile_collectors
            tmp=$(mktemp "$tf/forgejo-subvol.XXXXXX")
            chmod 644 "$tmp"
            trap 'rm -f "$tmp"' EXIT

            if [ ! -d "$dir" ]; then
              echo "forgejo-subvol-backup-metrics: $dir missing (btrbk target never created?)" >&2
              # scrape error — the fresh metric is deliberately ABSENT so the
              # Gatus check fails (fail-closed absence class).
              printf '# forgejo subvol backup metrics\nforgejo_subvol_backup_scrape_errors 1\n' > "$tmp"
              mv "$tmp" "$tf/forgejo_subvol_backup.prom" 2>/dev/null || echo "warn: publish failed (foreign-owned leftover?)" >&2
              exit 0
            fi

            newest=$(ls -1 "$dir" | grep -E '^forgejo\.' | sort | tail -1 || true)
            now=$(date +%s)
            if [ -n "$newest" ] && [ -d "$dir/$newest" ]; then
              recv=$(stat -c %Y "$dir/$newest")
              age=$(( now - recv ))
              if [ "$age" -lt 43200 ]; then fresh=1; else fresh=0; fi
              printf '# forgejo subvol backup metrics\nforgejo_subvol_backup_scrape_errors 0\nforgejo_subvol_backup_last_age_seconds %s\nforgejo_subvol_backup_fresh %s\n' "$age" "$fresh" >> "$tmp"
            else
              # Leg never completed a receive: fresh=0 pages (by design
              # until the first 8h slot after the option flip).
              printf '# forgejo subvol backup metrics\nforgejo_subvol_backup_scrape_errors 0\nforgejo_subvol_backup_last_age_seconds -1\nforgejo_subvol_backup_fresh 0\n' >> "$tmp"
            fi
            mv "$tmp" "$tf/forgejo_subvol_backup.prom" 2>/dev/null || echo "warn: publish failed (foreign-owned leftover?)" >&2
          '';
        };

        systemd.timers.forgejo-subvol-backup-metrics = lib.mkIf dedicated {
          description = "Periodic forgejo subvol backup freshness collection";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* *:00/5:00";
            Persistent = true;
          };
        };

        # Restore drill (plan M04): weekly, prove BOTH recovery paths —
        # (1) newest `forgejo dump` zip (transaction-consistent: DB + repos
        # + config + LFS), (2) newest btrbk-received subvol pool-side
        # (crash-consistent whole-state). Any failure exits 1 → OnFailure
        # pages. Deliberate-event alerting (unit-state, github-auto-assign
        # pattern) instead of a freshness collector — a drill is an event,
        # not a continuous signal (plan deviation noted: F19's metric+Gatus
        # simplified to onFailure + monitoredServices).
        # "Backups you have never restore-tested are hopes, not backups."
        systemd.services.forgejo-restore-drill = lib.mkIf dedicated {
          description = "Weekly restore drill: verify forgejo dump zip + received subvol";
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
          inherit onFailure;
          path = [
            pkgs.unzip
            pkgs.git
            pkgs.sqlite
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              TimeoutStartSec = "30min";
            }
            (serviceOneshotDefaults { })
            (harden {
              MemoryMax = "2G";
            })
            ioTier.background
          ];
          script = ''
            set -euo pipefail
            fails=0

            fsck_sample() {
              # $1 = label, $2.. = repo dirs (bare or normal)
              local label="$1"; shift
              local n=0
              for repo in "$@"; do
                n=$((n + 1))
                if git -C "$repo" fsck --no-progress >/dev/null 2>&1; then
                  echo "  drill[$label]: fsck OK  $repo"
                else
                  echo "  drill[$label]: fsck FAILED $repo" >&2
                  fails=$((fails + 1))
                fi
                [ "$n" -ge 5 ] && break
              done
              [ "$n" -gt 0 ] || { echo "  drill[$label]: NO repos found" >&2; fails=$((fails + 1)); }
            }

            # ---- Path 1: newest dump zip ----
            zip=$(ls -1 /mnt/pool/backups/forgejo/forgejo-*.zip 2>/dev/null | sort | tail -1 || true)
            if [ -n "$zip" ]; then
              echo "drill: dump path — $(basename "$zip")"
              scratch=$(mktemp -d)
              unzip -q "$zip" -d "$scratch"
              # DB integrity: forgejo dump carries the DB as forgejo-db.sql
              # (sqlite backend dumps to SQL text). Rebuild + integrity-check.
              dbsql=$(find "$scratch" -maxdepth 2 -name '*db*.sql' | head -1 || true)
              if [ -n "$dbsql" ]; then
                if sqlite3 "$scratch/drill.db" < "$dbsql" \
                  && sqlite3 "$scratch/drill.db" 'PRAGMA integrity_check;' | grep -q '^ok$'; then
                  echo "  drill[dump]: db rebuild + integrity_check OK"
                else
                  echo "  drill[dump]: db integrity FAILED" >&2
                  fails=$((fails + 1))
                fi
              else
                echo "  drill[dump]: no *.sql db found in zip" >&2
                fails=$((fails + 1))
              fi
              mapfile -d "" -t repos < <(find "$scratch" -type d -name objects -prune \
                -execdir test -d '{}/../refs' \; -print0 2>/dev/null \
                | head -z -n 5 || true)
              # normalize: we want the repo ROOT (parent of objects/), not objects/
              roots=()
              for r in "''${repos[@]}"; do roots+=("$(dirname "$r")"); done
              fsck_sample dump "''${roots[@]}"
              rm -rf "$scratch"
            else
              echo "drill: dump path — NO zip found in /mnt/pool/backups/forgejo" >&2
              fails=$((fails + 1))
            fi

            # ---- Path 2: newest btrbk-received subvol (read in place) ----
            recv=/mnt/pool/backups/forgejo-subvol
            newest=$(ls -1 "$recv" 2>/dev/null | grep -E '^forgejo\.' | sort | tail -1 || true)
            if [ -n "$newest" ]; then
              echo "drill: subvol path — $newest"
              mapfile -d "" -t rrepos < <(find "$recv/$newest" -type d -name objects -prune \
                -execdir test -d '{}/../refs' \; -print0 2>/dev/null \
                | head -z -n 5 || true)
              rroots=()
              for r in "''${rrepos[@]}"; do rroots+=("$(dirname "$r")"); done
              fsck_sample subvol "''${rroots[@]}"
            else
              echo "drill: subvol path — no received subvol yet (pre-first-slot is expected once; persistent absence = btrbk-forgejo broken)" >&2
              fails=$((fails + 1))
            fi

            if [ "$fails" -gt 0 ]; then
              echo "drill: FAILED ($fails problem(s))" >&2
              exit 1
            fi
            echo "drill: OK — both recovery paths verified"
          '';
        };

        systemd.timers.forgejo-restore-drill = lib.mkIf dedicated {
          description = "Weekly forgejo restore drill";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            # Sunday 06:00 — after the 03:30 dump + the 05:40 btrbk slot.
            OnCalendar = "Sun *-*-* 06:00:00";
            Persistent = true;
          };
        };

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
        systemd.tmpfiles.rules =
          lib.throwIf (themeAuditErrors != [ ])
            "forgejo theme audit: ${lib.concatStringsSep "; " themeAuditErrors}"
            [
              "Z ${stateDir} 0750 forgejo forgejo - -"
              "d ${forgejoBackupDir} 0750 forgejo forgejo -"
            ]
          ++ lib.mapAttrsToList (
            name: path: "L+ /var/lib/forgejo/custom/public/assets/css/${name} - - - - ${path}"
          ) forgejoThemes;

        environment.systemPackages = [
          mirrorGithubScript
          reconcileMirrorsScript
          mirrorStarredScript
          pushMirrorScript
          flipRepoScript
          censusScript
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
              {
                # Dead pull-mirror candidates (plan M07, redesigned 2026-09-18):
                # per-repo failing syncs from forgejo's notice table, minus
                # known-stale names — catches the redirect-frozen 12-day
                # outage class that mirror_updated freshness can NEVER see
                # (TouchMirror advances it on failed syncs too; verified
                # against v15.0.8 source + live data). Fail-closed: an
                # absent dead_candidates line = scrape error = RED.
                name = "Forgejo Dead Mirror Candidates";
                group = "Development";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\nforgejo_mirror_health_scrape_errors 0*)"
                  "[BODY] == pat(*\nforgejo_mirror_dead_candidates 0*)"
                ];
                alert = "Forgejo pull mirrors failing every sync for 24h+ (redirect-frozen / credential-dead class). Triage: journalctl -u forgejo-mirror-health (names printed), forgejo admin notices. Known-stale (renamed/deleted upstream) are subtracted via reconcile state.";
              }
            ]
            ++ lib.optionals dedicated [
              {
                # 8h subvol backup leg (btrbk-forgejo): fail-closed — absence
                # of fresh=1 (never ran / scrape error) is RED by design.
                name = "Forgejo Subvol Backup (8h)";
                group = "Development";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\nforgejo_subvol_backup_scrape_errors 0*)"
                  "[BODY] == pat(*\nforgejo_subvol_backup_fresh 1*)"
                ];
                alert = "Forgejo 8h subvol backup leg stale: no received subvol pool-side within 12h — journalctl -u btrbk-forgejo (send failure, pool absent, or first run still pending post-flip).";
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
          extraMonitoredServices = lib.mkAfter (
            [ "forgejo-github-sync" ] ++ lib.optionals dedicated [ "forgejo-restore-drill" ]
          );
        };
      };
    };
}
