# CV — SystemNix wrapper around the upstream NixOS module.
#
# The upstream module (inputs.cv.nixosModules.default → services.cv-server)
# owns the service shape: package, typst pin (kept lockstep with the
# golden-tested compiler), generated config.yaml, content sync from the
# package share dir into the state dir, and baseline hardening.
#
# This file layers ONLY the SystemNix-specific concerns on top: sops
# EnvironmentFile wiring (CV_API_KEY), port registry, GOMEMLIMIT/MemoryMax,
# onFailure alert routing, and the reverse proxy / dashboard / monitoring
# integrations (caddy.nix, homepage.nix, gatus-config.nix).
{ inputs, ... }: {
  flake.nixosModules.cv =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        ports
        onFailure
        harden
        ioTier
        serviceOneshotDefaults
        ;
      cfg = config.services.cv-server;
      domain = config.networking.domain;
      backupDir = "/mnt/pool/backups/cv";
      # Where the cv-oidc-env bridge writes CV_OIDC_CLIENT_SECRET (the
      # StateDirectory below owns /var/lib/cv-oidc; dnsblockd pattern).
      oidcEnvFile = "/var/lib/cv-oidc/client-secret.env";
    in
    {
      imports = [ inputs.cv.nixosModules.default ];

      options.services.cv-server.profileProbe = {
        enable = lib.mkEnableOption ''
          Weekly platform-session validity probe: runs
          `cv profile accounts --probe --all` against the operator checkout.
          Exit 0 = all sessions valid; exit 3 = at least one INVALID session,
          which FAILS the unit so onFailure alerts — logins rot visibly
          instead of at apply-time. Disabled by default: the probe is
          operator-local state (never a server surface) and pulls chromium
          into the closure.
        '';

        chromiumPackage = lib.mkOption {
          type = lib.types.package;
          default = pkgs.chromium;
          description = "Chromium derivation exported as CHROMIUM_EXECUTABLE_PATH for the Playwright-based probe (tests substitute a stub to keep the VM closure light).";
        };

        workingDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/home/lars/projects/CV";
          description = "CV checkout the probe runs from; session state (data/accounts) and the generated bun probe scripts live under it.";
        };
      };

      config = lib.mkIf cfg.enable {
        # The cv CLI on the machine PATH. The systemd unit ExecStarts the
        # store binary directly — invisible to interactive shells — and the
        # same derivation IS the CLI (cv serve / cv approve / cv track ...).
        # CLI commands resolve config.yaml + data/ from CWD, so repo work
        # still runs from the CV checkout (nix run .#cv / go run ./cmd/cv);
        # this PATH entry exposes the pinned machine version everywhere else.
        # Freshness = the flake.lock `cv` input: bump the lock and rebuild
        # to ship new CLI/server features (PATH cv and the service move
        # together — one derivation).
        environment.systemPackages = [
          inputs.cv.packages.${pkgs.stdenv.hostPlatform.system}.cv
        ];

        services.cv-server = {
          package = lib.mkDefault inputs.cv.packages.${pkgs.stdenv.hostPlatform.system}.default;
          port = lib.mkDefault ports.cv;
          environmentFile = lib.mkDefault config.sops.templates."cv-env".path;

          settings = {
            # Forms (chat, A.Team, contact) POST same-origin through the
            # Caddy vHost — OriginCheck/CORS/nosurf require the vHost origin
            # in the allowlist. Loopback covers local curl/LAN-IP access.
            server.allowed_origins = [
              "https://cv.${domain}"
              "http://127.0.0.1:${toString ports.cv}"
              "http://localhost:${toString ports.cv}"
            ];
            # CV_ENVIRONMENT drives CSP strictness (production blocks inline
            # scripts without nonces) and skips dev rate-limit bypasses.
            environment = "production";
            # Tracked applications/evaluations must survive restarts: the
            # memory store (default) evaporates on every service restart,
            # and cv-backup below protects exactly this file. data/ ROOT
            # files are never touched by the upstream content sync (it only
            # replaces the 8 content SUBDIRS).
            pipeline = {
              event_store_driver = "sqlite";
              event_store_dsn = "/var/lib/cv/data/pipeline.sqlite";
              # EUR/day price floor (owner decision 2026-09-03, ratifying the
              # CV repo's 600 proposal): below-floor discoveries skip at
              # evaluation regardless of score (RateFloor axis + `< FLOOR`
              # dashboard chips, upstream 2026-09-02/03). 615 €/day was the
              # PEA benchmark; 600 keeps a small negotiation band.
              evaluation.min_day_rate = 600;
              # The generated config.yaml IS the whole config (settings are
              # not merged over the repo's config.yaml), so the portal list
              # must live HERE or the server has nothing to scan. Keep in
              # sync with the CV repo's config.yaml pipeline.portals.
              # freelance.de is deliberately absent (WAF + crawling
              # guideline: detail-page URLs only). Skill-slug URLs
              # (/projects/golang, ...) are dead anonymously — never add
              # them (see CV AGENTS.md, Portal Scanners).
              portals = [
                # The operator's primary German GCP search (upstream
                # config.yaml portal #1, live-pinned by
                # TestLiveContract_FreelancermapGermanGCPSearch; path-aware
                # canonicalization sends /projekte... paths to the .de
                # host). Missing here since the 2026-09-01 upstream sync —
                # the highest-paying project class was invisible to the
                # production funnel (upstream issue #563).
                {
                  url = "https://www.freelancermap.de/projekte/web-und-softwareentwicklung?categories%5B0%5D=8&categories%5B1%5D=11&projectContractTypes%5B0%5D=contracting&query=%28%22Google+Cloud%22+OR+CGP+OR+%22Google+Cloud+Platform%22%29&sort=1&pagenr=1";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                # German defense/clearance GCP search (Sicherheitsüberprüfung,
                # Verteidigung, Bundeswehr, Rüstung — upstream config.yaml
                # 2026-09-12): same freelancermap surface as the primary
                # search, second query axis.
                {
                  url = "https://www.freelancermap.de/projekte/web-und-softwareentwicklung?categories%5B0%5D=8&categories%5B1%5D=11&projectContractTypes%5B0%5D=contracting&query=%28%22Sicherheits%C3%BCberpr%C3%BCfung%22+OR+%22Verteidigung%22+OR+%22Bundeswehr%22+OR+%22R%C3%BCstung%22%29&sort=1&pagenr=1";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/remote";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/germany";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/austria";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/switzerland";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/development";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/it";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/engineering";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                {
                  url = "https://www.freelancermap.com/projects/software-development";
                  company = "Freelancermap";
                  provider = "freelancermap";
                }
                # HN "Who is Hiring" monthly thread (scanner resolves the
                # current thread via Algolia author-tagged search; premium
                # remote Go/GCP/platform roles, upstream 2026-09-03).
                {
                  url = "https://news.ycombinator.com/hiring";
                  company = "Hacker News";
                  provider = "hn";
                }
                # Workable aggregate search (10th zero-auth scanner,
                # upstream 2026-09-05): the public JSON API the search page
                # itself calls carries the full JD per job. Filters map 1:1
                # from the search URL (query, repeatable employment_type,
                # workplace, location); limit<=20/page, pageToken cursor.
                # No portal `company` — workable is an aggregate across
                # per-posting employers (the scanner resolves each job's
                # own company; a portal company would only be a fallback).
                {
                  url = "https://jobs.workable.com/search?query=Google+Cloud&employment_type=contract&employment_type=other";
                  provider = "workable";
                }
                # Workable portfolio v2 (owner-approved 2026-09-05, live-
                # verified variants; each returns full result pages):
                # broaden discovery within the proven surface. German
                # surface note (upstream AGENTS): location=Germany works,
                # translated queries mangle — add a DE portal only via
                # the location filter.
                {
                  url = "https://jobs.workable.com/search?query=golang&employment_type=contract&employment_type=other";
                  provider = "workable";
                }
                {
                  url = "https://jobs.workable.com/search?query=Terraform&employment_type=contract&employment_type=other";
                  provider = "workable";
                }
                {
                  url = "https://jobs.workable.com/search?query=Google+Cloud&workplace=remote&employment_type=contract&employment_type=other";
                  provider = "workable";
                }
                # Structured remote-job feeds (upstream 2026-09-09, issue
                # #601, live-verified): the pure-automation tier — official
                # public feeds, no accounts, no scraping. WWR's category feed
                # IS the filter (feed choice, never skill URLs); Remotive is
                # filtered client-side to engineering categories; RemoteOK is
                # a firehose — the scanner applies the HN-style tech-signal
                # pre-filter.
                {
                  url = "https://weworkremotely.com/categories/remote-back-end-programming-jobs.rss";
                  company = "We Work Remotely";
                  provider = "wwr";
                }
                {
                  url = "https://remotive.com/api/remote-jobs";
                  provider = "remotive";
                }
                {
                  url = "https://remoteok.com/api";
                  provider = "remoteok";
                }
              ];
              # One-click funnel tail. STAGED FLIP (2026-09-17, gate Q1):
              # enabled=true + send_on_approve=true while autosend_driver
              # stays DRY-RUN (the honest dry-run contract: Success:false,
              # records NOTHING). The funnel moves end-to-end — tailor →
              # approve — and every approval holds honestly at
              # approved-pending-send with ZERO email risk.
              # THE TRANSPORT IS THE GATE, not send_on_approve: the real
              # go-live is the driver flip to agentmail (+ sops cv-env
              # creds, see the agentmail comment below), and it DRAINS
              # every approved-pending-send in one sweep. Before flipping
              # the driver: land pipeline.autoapply.max_approval_age_days
              # (staleness cap) and review per-row pending-send ages —
              # decision table in owner-gate-package-going-live.md gate Q1.
              # After the flip, the cv-scan timer's auto-apply POST
              # activates on its next tick.
              autoapply = {
                enabled = true;
                # worth-trying added 2026-09-03 with the recalibrated score
                # bands (4.5-max corpus tops out ~3.2): apply-only starves
                # the funnel to zero candidates. The approval click stays
                # the human gate either way.
                recommendations = [
                  "apply"
                  "worth-trying"
                ];
                max_per_pass = 5;
                strategy = "nudge";
                send_on_approve = true;
                never_reapply_rejected_companies = true;
              };
              # Reply loop + calendar feed (interview replies → /pipeline
              # Interviews stage → /calendar/interviews.ics). enabled=true
              # is INERT until the agentmail env vars below exist — the
              # poller provider self-disables without creds. Subscribe the
              # owner calendar once: /calendar/interviews.ics?key=<CV_API_KEY>
              # (the calendar guard reuses the pipeline API key).
              replyloop = {
                enabled = true;
                # Alert-mail router (upstream 2026-09-03): platform
                # new-jobs digests classified + tracked as discoveries.
                # Same inertness as replyloop itself — no creds, no polls.
                alert_router = true;
              };
              # Gate Q1 flip (do ALL of it in one change):
              #   1. sops cv-env template += CV_PIPELINE_AUTOSEND_DRIVER=agentmail
              #      CV_PIPELINE_AGENTMAIL_API_KEY=<am_...>
              #      CV_PIPELINE_AGENTMAIL_INBOX_ID=<inbox id>
              #      (identity: lars.artmann@agentmail.to — PERMANENT, gate Q3:
              #      switching it later orphans SentTo reply matching)
              #   2. settings: pipeline.autoapply.enabled = true
              #   3. rebuild; verify boot log "Application sender: AgentMail"
              #   4. first real send probe per gate-package A2, then done.
              # Keys stay empty here so env overrides win and no secret
              # ever lands in the nix store.
              agentmail = {
                api_key = "";
                inbox_id = "";
              };
            };
            # journald/SigNoz ingestion friendliness: structured JSON lines
            # instead of the text default (internal/config LogFormatJSON).
            logging.format = "json";
            # Absolute state-dir path: the default (data/graphrag.sqlite) is
            # CWD-relative, which happens to resolve correctly today but only
            # because WorkingDirectory = /var/lib/cv. Pin it so graphrag can
            # be enabled later without a relative-path surprise (module is
            # disabled by default; the key is inert until then).
            graphrag.store_dsn = "/var/lib/cv/data/graphrag.sqlite";
            # Operator sign-in via Pocket ID (native OIDC, Layer 1 — moved
            # off protectedVHost 2026-09-13 per the AGENTS.md double-auth
            # doctrine): the locked /admin access card renders the provider
            # sign-in button; a successful passkey login mints the app's own
            # operator session. redirect_url MUST equal the callbackURLs
            # entry in pocket-id.nix byte-for-byte. client_secret stays
            # EMPTY here — it rides env only (cv-oidc-env.service below,
            # LoadCredential from the PocketID provisioner's client-secrets
            # file; dnsblockd bridge pattern). CV_API_KEY remains the
            # machine path: cron timers still POST with X-API-Key.
            oidc = {
              enabled = true;
              issuer_url = "https://auth.${domain}";
              client_id = "cv";
              redirect_url = "https://cv.${domain}/admin/auth/oidc/callback";
            };
          };
        };

        # Bridges the Pocket ID client secret into an env file cv-server can
        # consume (dnsblockd-oidc-secret pattern). When the secret is
        # missing the unit exits 0 WITHOUT writing the env file, so OIDC
        # sign-in stays off instead of blocking the service (the API-key
        # machine path keeps working).
        systemd.services.cv-oidc-env =
          lib.mkIf
            (
              (cfg.settings.oidc.enabled or false) && (config.services.pocket-id-config.provision.enable or false)
            )
            {
              description = "CV — Pocket ID OIDC client secret provisioning";
              after = [ "pocket-id-provision.service" ];
              wants = [ "pocket-id-provision.service" ];
              before = [ "cv-server.service" ];
              wantedBy = [ "cv-server.service" ];
              startLimitBurst = 5;
              startLimitIntervalSec = 300;

              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                StateDirectory = "cv-oidc";
                LoadCredential = [
                  "pocket-id-secret:${config.services.pocket-id.dataDir or "/var/lib/pocket-id"}/client-secrets/cv"
                ];
              };

              path = [ pkgs.coreutils ];

              script = ''
                SECRET_FILE="$CREDENTIALS_DIRECTORY/pocket-id-secret"

                if [ ! -s "$SECRET_FILE" ]; then
                  echo "cv-oidc-env: Pocket ID secret not found — removing env file so OIDC sign-in stays off"
                  rm -f "${oidcEnvFile}"
                  exit 0
                fi

                install -d -m 0755 "$(dirname "${oidcEnvFile}")"
                echo "CV_OIDC_CLIENT_SECRET=$(cat "$SECRET_FILE")" > "${oidcEnvFile}"
                chmod 600 "${oidcEnvFile}"
                echo "cv-oidc-env: Pocket ID client secret written"
              '';
            };

        systemd.services.cv-server = {
          after = [
            "sops-nix.service"
            # State-dir ownership heal MUST complete before the upstream
            # content sync runs (its assets rm -rf dies on foreign-owned
            # entries). Explicit here beside the heal unit's own before /
            # wantedBy wiring — the same belt-and-braces as cv-oidc-env.
            "cv-state-perms.service"
          ]
          ++
            lib.optionals
              (
                (cfg.settings.oidc.enabled or false) && (config.services.pocket-id-config.provision.enable or false)
              )
              [
                "pocket-id-provision.service"
                "cv-oidc-env.service"
              ];
          wants = [
            "sops-nix.service"
            "cv-state-perms.service"
          ]
          ++
            lib.optionals
              (
                (cfg.settings.oidc.enabled or false) && (config.services.pocket-id-config.provision.enable or false)
              )
              [
                "pocket-id-provision.service"
              ];
          inherit onFailure;

          serviceConfig = lib.mkMerge [
            (harden {
              # Mostly idle; renders spike only during PDF export bursts.
              MemoryMax = "1G";
            })
            {
              # Keep GC headroom below the 1G cgroup cap (validate-gomemlimit).
              # OTEL_*: Go otlptracehttp — bare host:port, NO scheme (the SDK
              # builds the URL itself); registered in otel-endpoint-audit.
              Environment = [
                "GOMEMLIMIT=768MiB"
                "OTEL_EXPORTER_OTLP_ENDPOINT=localhost:${toString ports.signoz-otlp-http}"
                "OTEL_ENVIRONMENT=production"
              ];
            }
            (lib.mkIf
              (
                (cfg.settings.oidc.enabled or false) && (config.services.pocket-id-config.provision.enable or false)
              )
              {
                # mkForce: upstream sets EnvironmentFile as a plain single-value
                # list from services.cv-server.environmentFile (the sops
                # cv-env template); this wrapper EXTENDS it with the OIDC
                # bridge's env file. cfg.environmentFile is this wrapper's
                # own mkDefault (the sops template), so no duplication.
                EnvironmentFile = lib.mkForce [
                  cfg.environmentFile
                  oidcEnvFile
                ];
              }
            )
          ];
        };

        # Heals foreign-owned entries in the state dir BEFORE the upstream
        # content sync runs as the service user. The sync's assets mirror
        # (rm -rf "$state/assets" under set -e) cannot unlink entries the cv
        # user does not own — operator root intervention leaves such entries
        # behind — and one unlink EPERM took the whole service boot down
        # (2026-09-20: assets/fonts owned by root). Root oneshot carrying
        # just the three caps the chown/chmod walk needs; the cv-server
        # daemon itself keeps CapabilityBoundingSet="". Re-runs on EVERY
        # cv-server start (no RemainAfterExit). Tolerance mirrors
        # hermes-perms: a single unhealable entry is tolerated, never fatal —
        # foreign-owned files must never take the boot down.
        systemd.services.cv-state-perms = {
          description = "CV — heal state-dir ownership before the content sync";
          # The heal walks /var/lib/cv WITHOUT owning its StateDirectory
          # entry (the main unit's), so order it after the state filesystems
          # explicitly — a not-yet-mounted /var would read as "missing dir"
          # and silently skip the heal for this start.
          after = [ "local-fs.target" ];
          before = [ "cv-server.service" ];
          wantedBy = [ "cv-server.service" ];

          serviceConfig = lib.mkMerge [
            { Type = "oneshot"; }
            (harden {
              # CAP_CHOWN: the ownership walk. CAP_FOWNER: chmod on entries
              # owned by another uid. CAP_DAC_OVERRIDE: traverse foreign
              # dirs whose mode (e.g. root-owned 0700) denies the walk.
              CapabilityBoundingSet = [
                "CAP_CHOWN"
                "CAP_DAC_OVERRIDE"
                "CAP_FOWNER"
              ];
            })
            (serviceOneshotDefaults { })
          ];

          path = [
            pkgs.coreutils
            pkgs.findutils
          ];

          script = ''
            state="${cfg.stateDir}"
            [ -d "$state" ] || exit 0

            # Fast path: every entry already service-owned AND fully
            # traversable — find exits nonzero when it cannot descend a
            # foreign 0700 dir, which is drift too (then-branch skipped).
            if stray=$(find "$state" -xdev \( ! -user ${cfg.user} -o ! -group ${cfg.group} \) -print -quit 2>/dev/null); then
              if [ -z "$stray" ]; then
                exit 0
              fi
            fi

            echo "cv-state-perms: foreign-owned entries under $state — healing for ${cfg.user}:${cfg.group}"
            chown ${cfg.user}:${cfg.group} "$state" 2>/dev/null || true
            find "$state" -xdev -exec chown ${cfg.user}:${cfg.group} {} + 2>/dev/null || true
            # Write permission, not just ownership: the sync's rm -rf
            # unlinks via DIR-write and its cp overwrites files in place —
            # a root-owned 0555 tree stays unwritable after chown alone.
            # Split by type so the config.yaml symlink is never chmod'd
            # through to its read-only store target.
            find "$state" -xdev -type d -exec chmod u+w {} + 2>/dev/null || true
            find "$state" -xdev -type f -exec chmod u+w {} + 2>/dev/null || true
          '';
        };

        # cv-state-perms matches no deploy-restart-audit converger pattern
        # and has no RemainAfterExit (it MUST re-run on every cv-server
        # start, not converge once): it is converged by cv-server's own
        # start via wantedBy/wants — a deploy re-runs it when cv-server
        # restarts, so a deploy-restart of the unit itself is meaningless.
        services.deploy-restart-audit.allowUnits = lib.mkIf (options ? services.deploy-restart-audit) [
          "cv-state-perms"
        ];

        # Mount-gated creator for the pool-side backup dir (atticd-storage-dir
        # pattern). cv-backup's ReadWritePaths requires the path to EXIST
        # before namespace setup: during the 9-day DAS outage a root-fs shadow
        # dir under /mnt/pool let cv-backup pass setup while early-exiting
        # ("no pipeline.sqlite yet"); the 2026-08-31 pool remount then failed
        # the boot catch-up run with 226/NAMESPACE because the POOL filesystem
        # never had the dir. tmpfiles must NOT create it either — pre-mount it
        # would land on the root fs and shadow the pool copy.
        systemd.services.cv-backup-dir = {
          description = "Create CV backup directory on the HDD pool";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ backupDir ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            # ReadWritePaths targets the MOUNT ROOT (/mnt/pool), not a
            # subdirectory: on a FRESH pool nothing creates /mnt/pool/backups
            # before this unit's namespace is set up, and a ReadWritePaths
            # entry under it aborts with 226/NAMESPACE before the script can
            # mkdir (2026-09-04: caught by the VM test after the 2026-09-02
            # tmpfiles removal left cv-backup-dir as "the only sanctioned
            # creator" of a path its own namespace setup required to
            # pre-exist). RequiresMountsFor guarantees /mnt/pool is mounted,
            # so the root scope always resolves; the script mkdirs the leaf.
            (harden {
              MemoryMax = "128M";
              ReadWritePaths = [ "/mnt/pool" ];
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            mkdir -p ${backupDir}
            chmod 0755 ${backupDir}
          '';
        };

        # Pipeline event-store backup: the tracked-applications state
        # (data/pipeline.sqlite) is irreplaceable. Online SQLite backup
        # (safe against the live WAL writer) onto the mirrored pool.
        systemd.services.cv-backup = {
          description = "CV pipeline SQLite backup (online .backup)";
          after = [
            "cv-server.service"
            "cv-backup-dir.service"
          ];
          wants = [
            "cv-server.service"
            "cv-backup-dir.service"
          ];
          # Orders the unit AFTER the pool mount (a detached DAS fails the
          # run as a clean dependency error instead of 226/NAMESPACE — the
          # btrbk doctrine), and fixes the boot-race where Persistent timer
          # catch-up fires seconds before mnt-pool.mount completes.
          unitConfig.RequiresMountsFor = [ backupDir ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "cv-backup" ''
                set -euo pipefail
                db="/var/lib/cv/data/pipeline.sqlite"
                if [ ! -f "$db" ]; then
                  echo "cv-backup: no pipeline.sqlite yet — nothing to back up"
                  exit 0
                fi
                ts=$(date +%Y%m%dT%H%M%S)
                dst="${backupDir}/pipeline-$ts.sqlite"
                ${lib.getExe pkgs.sqlite} "$db" ".backup '$dst'"
                # 14-day retention (pocket-id-backup pattern): the online
                # .backup rewrites every page, so nothing is shared between
                # nights — without pruning the pool dir grows forever.
                find "${backupDir}" -name "pipeline-*.sqlite" -mtime +14 -delete
                echo "cv-backup: wrote $dst"
              '';
              ReadWritePaths = [
                backupDir
                "/var/lib/cv"
              ];
            }
            (harden {
              # cv-server's data/ is 0750 cv:cv. Root with an EMPTY
              # CapabilityBoundingSet obeys DAC bits and cannot even stat
              # through that dir: `[ ! -f $db ]` was TRUE with the DB sitting
              # right there, and every run exited 0 "no pipeline.sqlite yet" —
              # a silently green no-op backup since deployment (caught by the
              # 2026-08-31 VM regression test, masked until then by the 226).
              # CAP_DAC_READ_SEARCH = read-only traversal, the exact
              # backup-health-metrics precedent for root collectors reading
              # foreign-owned trees. Writing still targets root-owned paths.
              CapabilityBoundingSet = "CAP_DAC_READ_SEARCH";
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        systemd.timers.cv-backup = {
          description = "Nightly CV pipeline backup (03:17, staggered off the 01:00-03:00 peak)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 03:17:00";
            Persistent = true;
            Unit = "cv-backup.service";
          };
        };

        # Continuous funnel automation: every 6h, scan ALL configured portals
        # and bulk-evaluate tracked-but-unscored applications. Drives the
        # server over HTTP (the server owns the SQLite lease — a CLI timer
        # against the same store file would conflict with it). Both endpoints
        # are async and 409-guarded against double runs, so an overlap with a
        # dashboard-triggered run is harmless. The scan itself evaluates every
        # newly ingested job inline; the follow-up no-force evaluate pass only
        # catches rows whose scan-time evaluation failed. Forced re-scoring of
        # the whole inventory stays MANUAL (criteria/keyword changes) — a
        # periodic force pass would append one job.evaluated event per tracked
        # application per run for identical verdicts.
        #
        # Requires a CV package whose server skips CSRF for X-API-Key-bearing
        # requests (CV repo 2026-08-29 or later); older servers answer 403
        # csrf_invalid to these POSTs. Deploy the flake-input bump together
        # with this timer.
        systemd.services.cv-scan = {
          description = "CV pipeline portal scan + bulk evaluation (HTTP, lease-safe)";
          after = [ "cv-server.service" ];
          wants = [ "cv-server.service" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              # Same sops template the server reads — the systemd manager
              # injects it, so the hardened sandbox never touches the
              # secret file itself.
              EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [
                cfg.environmentFile
              ];
              ExecStart = pkgs.writeShellScript "cv-scan" ''
                set -euo pipefail
                base="http://127.0.0.1:${toString cfg.port}"
                key="''${CV_API_KEY:?CV_API_KEY missing — check the cv-env sops template}"
                curl_bin="${lib.getExe pkgs.curl}"

                # 200 = accepted, 409 = a scan/evaluation is already running
                # (dashboard button or previous tick) — both fine. Anything
                # else fails the unit so onFailure alerting picks it up.
                post() {
                  code=$("$curl_bin" -sS -o /dev/null -w '%{http_code}' -X POST \
                    -H "X-API-Key: $key" -H 'Content-Type: application/json' "$1")
                  case "$code" in
                    200|409) echo "cv-scan: $1 -> $code (ok)" ;;
                    *) echo "cv-scan: $1 -> $code (unexpected)" >&2; exit 1 ;;
                  esac
                }

                # Funnel-tail variant (staged flip 2026-09-17): the tail is
                # ENABLED in config now, so 200/409 is the expected shape.
                # 503 stays a WARN through the rollback window — it means
                # the deployed server still predates the flip (flake-input
                # lag) or the config was rolled back on purpose; neither
                # should fail the scan/evaluate core alerting. 404 still
                # fails: the deployed server predates the endpoint and
                # this script needs a flake-input bump.
                post_funnel_tail() {
                  code=$("$curl_bin" -sS -o /dev/null -w '%{http_code}' -X POST \
                    -H "X-API-Key: $key" -H 'Content-Type: application/json' -d '{}' "$1")
                  case "$code" in
                    200|409) echo "cv-scan: $1 -> $code (ok)" ;;
                    503) echo "cv-scan: $1 -> 503 (auto-apply disabled on the deployed server — rollback window or stale flake pin, warn only)" ;;
                    *) echo "cv-scan: $1 -> $code (unexpected)" >&2; exit 1 ;;
                  esac
                }

                post "$base/api/pipeline/scan"
                post "$base/api/pipeline/evaluate-tracked"
                # Funnel tail (2026-09-02, gate Q2): tailor the top
                # recommended applications into the approval queue every
                # tick + sweep approved-but-unsent sends. It never sends
                # anything un-approved (send_on_approve: the dashboard
                # Approve click IS the send confirmation).
                post_funnel_tail "$base/api/pipeline/auto-apply"
                # (staged flip 2026-09-17: the tail now runs every tick —
                # dry-run transport holds approvals at approved-pending-
                # send; NOTHING emails until the agentmail driver lands.)
              '';
            }
            (harden { })
            (serviceOneshotDefaults { })
          ];
        };

        systemd.timers.cv-scan = {
          description = "Continuous CV pipeline scanning (every 6h, :23 stagger off the top of the hour)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 00/6:23:00";
            Persistent = true;
            Unit = "cv-scan.service";
          };
        };

        # Platform-session validity probe (plan T23, 2026-08-30): weekly
        # `cv profile accounts --probe --all` against the operator checkout.
        # The probe reads/WRITES operator-local state (the accounts ledger +
        # session files under the checkout), so it runs as the operator user
        # with home access — deliberately NOT part of the hardened server
        # surface. Exit 3 (>=1 invalid session) fails the unit on purpose:
        # onFailure alerting is the entire value of the timer.
        systemd.services.cv-profile-probe = lib.mkIf cfg.profileProbe.enable {
          description = "CV platform session validity probe (exit 3 = invalid session -> alert)";
          inherit onFailure;
          startLimitBurst = 2;
          startLimitIntervalSec = 600;

          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "lars";
              Group = "users";
              WorkingDirectory = cfg.profileProbe.workingDirectory;
              Environment = [
                "HOME=/home/lars"
                "CHROMIUM_EXECUTABLE_PATH=${cfg.profileProbe.chromiumPackage}/bin/chromium"
                "PLAYWRIGHT_BROWSERS_PATH=/home/lars/tmp/playwright"
                "PATH=${
                  lib.makeBinPath [
                    pkgs.bun
                    pkgs.coreutils
                    pkgs.gnugrep
                  ]
                }:/run/current-system/sw/bin"
              ];
              ExecStart = "${lib.getExe cfg.package} profile accounts --probe --all";
            }
            (harden {
              # The probe mutates operator state under /home and runs a
              # browser; the server-grade home protection must not apply.
              ProtectHome = false;
            })
            (serviceOneshotDefaults { })
          ];
        };

        systemd.timers.cv-profile-probe = lib.mkIf cfg.profileProbe.enable {
          description = "Weekly CV platform session validity probe (Mon 09:41, off the backup window)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "Mon *-*-* 09:41:00";
            Persistent = true;
            Unit = "cv-profile-probe.service";
          };
        };

        # NO tmpfiles rule for ${backupDir} — deliberately (atticd-storage-dir
        # doctrine): /mnt/pool is nofail, so local-fs.target does NOT wait for
        # it and systemd-tmpfiles-setup (After=local-fs.target) can run BEFORE
        # the pool mounts — a rule would create a ROOT-fs shadow dir during
        # every DAS outage (the exact 226/NAMESPACE masking class fixed
        # 2026-08-31). cv-backup-dir above is the only sanctioned creator.

        # Service-integration registry entry: fans out to the Caddy vHost
        # (plain — native OIDC, protectedVHost would double-auth), the six
        # Gatus checks, the homepage tile, the backup-freshness row, and
        # the Pocket ID OIDC client. Replaces rows in caddy.nix /
        # gatus-config.nix / homepage.nix / configuration.nix /
        # pocket-id.nix.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          cv = {
            inherit (cfg) enable;
            subdomain = "cv";
            port = ports.cv;
            vHost.layer = "plain";
            checks = [
              # Liveness: go-health probe served from the raw mux (always
              # 200 once the process is up; connection-refused when down).
              {
                name = "CV";
                group = "Productivity";
                url = "http://localhost:${toString ports.cv}/health/live";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alert = "CV server down — resume site and PDF export at cv.home.lan unreachable. Check: systemctl status cv-server, journalctl -u cv-server.";
              }
              # Functional: the CV page renders real HTML (liveness alone
              # would stay green through a broken render/config path).
              {
                name = "CV Page Renders";
                group = "Productivity";
                url = "http://localhost:${toString ports.cv}/cv";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 2000"
                  "[BODY] == pat(*<html*)"
                ];
                alert = "CV /cv page no longer renders HTML — content sync, config, or the render layer is broken (cv.home.lan)";
              }
              # Functional: the PDF export actually compiles — this stayed
              # green through a real incident where the typst template
              # vanished from the state dir and /export/pdf 404'd while
              # /cv kept rendering (2026-08-27). 5m interval stays far
              # inside the export rate limit (5/min burst 8 per client).
              {
                name = "CV PDF Export";
                group = "Productivity";
                url = "http://localhost:${toString ports.cv}/export/pdf";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 10000"
                  "[BODY] == pat(*%PDF*)"
                ];
                alert = "CV /export/pdf broken — typst template missing from /var/lib/cv/assets or the typst renderer failed (cv.home.lan). Check: journalctl -u cv-server, restart re-syncs assets.";
              }
              # Funnel freshness: the newest job.discovered event must be
              # younger than 26h (four missed 6h scan ticks). The server
              # encodes the verdict as the funnelStale boolean so this needs
              # no JSONPath support; the API key rides the same sops secret
              # the cv-scan timer uses, rendered into gatus-env.
              {
                name = "CV Funnel Freshness";
                group = "Productivity";
                url = "http://localhost:${toString ports.cv}/api/pipeline/sse-stats";
                interval = "30m";
                # sse-stats scans the WHOLE event log per call (newest
                # job.discovered). Under IO PSI that took 2.4-12s live
                # (2026-09-03): the old [RESPONSE_TIME] < 2000 condition
                # flapped the check 4x/12h while funnelStale stayed false,
                # and the client's default 10s timeout failed the rest —
                # every flap paged "funnel stale" for a latency problem.
                # Liveness stays guarded by [STATUS] + this 30s ceiling;
                # the freshness verdict IS the check's job.
                client.timeout = "30s";
                headers = {
                  X-API-Key = "$CV_API_KEY";
                };
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\"funnelStale\":false*)"
                ];
                alert = "CV funnel stale — no new job discovered in 26h+ (cv-scan timer dead or every portal failing). Check: systemctl list-timers | grep cv-scan; journalctl -u cv-scan -u cv-server --since -24h";
              }
              # Funnel DB health: /health's PipelineStore check pings the
              # SQLite event store (the irreplaceable tracked-applications
              # state cv-backup protects). /health migrated to the go-health
              # rich format with the 2026-09-15 defense-portal bundle
              # (ed8b92f): checks are keyed by fully-qualified Go type
              # (typetostring.GetType) with compact {"status":"..."} values.
              # Pattern anchors on the short type suffix plus the compact
              # status pair; "warn"/"fail"/absent all fail the pat.
              # "disabled" (in-memory backend) also fails: in production
              # event_store_driver=sqlite by config, so a degraded verdict
              # means the persistence config regressed (the config-validation
              # gap the CV repo flagged). DEPLOY-ORDER: binaries before the
              # go-health migration carry the compact legacy key instead and
              # would sit permanently red on this check.
              {
                name = "CV Pipeline Store Health";
                group = "Productivity";
                url = "http://localhost:${toString ports.cv}/health";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 2000"
                  "[BODY] == pat(*eventstore.PipelineStore\":{\"status\":\"pass\"*)"
                ];
                alert = "CV pipeline event store unreachable — tracked-applications persistence is degraded (cv.home.lan). Check: journalctl -u cv-server --since -15min; sqlite store at /var/lib/cv/data/pipeline.sqlite.";
              }
              # Auto-apply surface check: the cv_autoapply_* gauges must be
              # REGISTERED on /metrics. Presence-only by decision — the
              # counters are cumulative, so any pat on a VALUE ("errors 0")
              # permanently breaks after the first transient 429 and pages
              # forever (the same value-threshold trap as the funnel
              # freshness RESPONSE_TIME flap). Pass CADENCE is covered by
              # Funnel Freshness (the timer POSTs scan→evaluate→auto-apply
              # in sequence; a dead auto-apply leg alone is a CV-side
              # last-pass-file gap, not alertable here).
              {
                name = "CV Auto-Apply Metrics";
                group = "Productivity";
                url = "http://localhost:${toString ports.cv}/metrics";
                interval = "30m";
                headers = {
                  X-API-Key = "$CV_API_KEY";
                };
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*cv_autoapply_passes*)"
                  "[BODY] == pat(*cv_autoapply_pass_errors*)"
                ];
                alert = "CV auto-apply gauges missing from /metrics — the autoapply DI provider or metrics registration regressed (cv.home.lan). Check: journalctl -u cv-server --since -15min; GET /metrics | grep cv_autoapply.";
              }
              # Auto-apply pass observability (2026-09-15 bundle): the
              # last-pass endpoint carries the APPLY-side sibling
              # data/last-autoapply-pass.json — the wire answer to "the
              # timer POSTs fire but the pass never completes" (a 503 on
              # the auto-apply POST is warn-not-fail in cv-scan, so scan
              # + evaluate keep Funnel Freshness green while tailoring
              # silently dies). Presence-only pat by the same decision as
              # the metrics check above: RFC3339 timestamps can't be
              # date-compared in a gatus pat, so this catches
              # NEVER-completed (key omitted via omitempty when no pass
              # ever ran), not stale — cadence stays a human read on
              # /pipeline. DEPLOY-ORDER: needs a CV binary with the
              # autoApply last-pass wire field (shipped 2026-09-10) —
              # pin is already past that.
              {
                name = "CV Auto-Apply Last Pass";
                group = "Productivity";
                url = "http://localhost:${toString ports.cv}/api/pipeline/last-pass";
                interval = "30m";
                client.timeout = "10s";
                headers = {
                  X-API-Key = "$CV_API_KEY";
                };
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\"autoApply\":{\"ranAt\":\"20*)"
                ];
                alert = "CV auto-apply has never completed a pass (last-pass wire lacks autoApply.ranAt) — the auto-apply timer leg is silently dead while scans stay fresh (cv.home.lan). Check: journalctl -u cv-scan --since -24h for 503s on /api/pipeline/auto-apply; the pass file is data/last-autoapply-pass.json in the state dir.";
              }
              # Approvals API surface check (staged flip 2026-09-17): the
              # guarded approvals endpoint must answer 200. PRESENCE-ONLY
              # by decision — a "pending > 0" pat would page forever once
              # the queue is legitimately drained (the value-threshold
              # trap documented on the metrics checks above), and a
              # DRY-RUN-banner pat on the /pipeline HTML is flappy the
              # same way (the banner renders only while approvals are
              # pending). Queue health stays a human read on /pipeline:
              # DRY-RUN banner + per-row pending-send ages.
              {
                name = "CV Approvals API";
                group = "Productivity";
                url = "http://localhost:${toString ports.cv}/api/pipeline/approvals";
                interval = "30m";
                client.timeout = "10s";
                headers = {
                  X-API-Key = "$CV_API_KEY";
                };
                conditions = [
                  "[STATUS] == 200"
                ];
                alert = "CV approvals API unreachable — the approval queue surface regressed or the server is down (cv.home.lan). Check: journalctl -u cv-server --since -15min; GET /api/pipeline/approvals with the CV API key.";
              }
            ];
            homepage = {
              name = "CV";
              group = "Development";
              description = "Resume Generator & Career Pipeline";
            };
            backup = {
              # Nightly online .backup of the pipeline event store
              # (cv-backup.timer, 03:17) onto the mirrored pool.
              directory = "/mnt/pool/backups/cv";
              filePattern = "pipeline-*.sqlite";
              maxAgeHours = 25;
            };
            # Native OIDC in CV's admin hub (coreos/go-oidc,
            # authorization-code + PKCE S256): the locked /admin access
            # card renders the provider sign-in button; success mints
            # the app's operator session. The secret lands in
            # /var/lib/pocket-id/client-secrets/cv and reaches the
            # service via the cv-oidc-env bridge (above). The API key
            # stays CV's machine path (cron timers keep X-API-Key).
            oidc = {
              name = "CV";
              clientId = "cv";
              launchURL = "https://cv.${domain}";
              callbackURLs = [ "https://cv.${domain}/admin/auth/oidc/callback" ];
              pkceEnabled = true;
            };
          };
        };
      };
    };
}
