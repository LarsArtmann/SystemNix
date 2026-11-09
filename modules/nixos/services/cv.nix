# Runbook: docs/services/cv.md
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
        mkPoolDirUnit
        serviceOneshotDefaults
        ;
      cfg = config.services.cv-server;
      domain = config.networking.domain;
      backupDir = "/mnt/pool/backups/cv";
      # Where the cv-oidc-env bridge writes CV_OIDC_CLIENT_SECRET (the
      # StateDirectory below owns /var/lib/cv-oidc; dnsblockd pattern).
      oidcEnvFile = "/var/lib/cv-oidc/client-secret.env";
      # Scoped store-master-key template (P6 split, 2026-11-09): only
      # cv-server + cv-relogin reference it — the two units that boot the
      # sealed credentials store. cv-scan/cv-agent keep cv-env WITHOUT the
      # key (they never call the store).
      cvStoreKeyEnvFile = config.sops.templates."cv-store-key-env".path;
      # Playwright is a JS package and the SERVED state dir carries no
      # node_modules (the CV checkout that has them is lars-owned and closed
      # to the service user). Expose nixpkgs' playwright-core as
      # node_modules/playwright so bun's NODE_PATH resolution finds it and
      # the relogin unit can drive a browser as cv (mechanism verified live
      # 2026-11-09: bun 1.4.4 + playwright-core 1.64.1 + the system
      # chromium launch headless as this user).
      playwrightModules = pkgs.runCommand "cv-playwright-node-modules" { } ''
        mkdir -p $out/lib/node_modules
        ln -s ${cfg.relogin.playwrightPackage} $out/lib/node_modules/playwright
      '';
      # cv vendorHash shim DROPPED (2026-10-12): its own drop condition met
      # ("the lock moves past an upstream-fixed rev") — the lock moved
      # e425ffa → 533ddc9 and upstream 533ddc9 bakes a GREEN through-our-lock
      # hash (first-hand probe: inputs.cv.packages.x86_64-linux.default.
      # goModules built clean, store 3w5hsmnp…, declared EI2rt1uF…; the
      # shim's uY1ZAA4r… was measured at e425ffa and hash-mismatched in the
      # 2026-10-12 toplevel keep-going enumeration). The queued
      # paste-upstream → push → re-drop cycle is thereby closed
      # upstream-side: no cv edit was needed. Serves BOTH consumers below
      # (PATH CLI and service package are the same derivation, two attrs).
      # Re-add ONLY via nix-hash-fix evidence, never by hand.
      # TEMPORARY vendorHash shim RE-ADDED (2026-10-14 wave-2 toplevel build,
      # first-hand FOD evidence — the documented bootstrap exception): got
      # XLIgHM1V… at locked rev 0ad2a6b (first-hand keep-going enumeration,
      # /tmp/w2-build.log; the 2026-10-14 flake.lock rewrite moved cv
      # 533ddc9 → 0ad2a6b = upstream master tip, which STILL bakes the stale
      # NeXR9Ened… — no upstream-fixed rev exists to float to, gh-verified
      # same day). Same shape as the 2026-10-10 shim. Drop when upstream
      # re-pins or the lock moves past an upstream-fixed rev
      # (paste-upstream → push → re-lock → re-drop, docs/todo/upstream.md).
      # SHIM DROPPED (2026-10-17 wave): upstream cv nix/packages.nix:70 at
      # tip 0ec5eac3 (== lock) bakes the last shim value mnvM9S+l… (the CV
      # session pasted it upstream themselves). Re-add ONLY via
      # nix-hash-fix evidence, never by hand.
      # TEMPORARY vendorHash shim RE-ADDED (2026-10-25 exec-3 lock-float
      # proof, first-hand keep-going evidence — build4 log,
      # ~/.cache/lockfloat/toplevel-build4.log): cv-88e0d12-go-modules
      # specified GEC+h65F… got SkTcNXE…, and the 64e41fe probe specified
      # SkTcNX…/got 1o2UQt… — a re-served upstream dependency moved BOTH
      # revs' module graph (the pma RE-STALE class, 2026-10-23; no
      # upstream-fixed rev exists to float to). Drop when upstream re-bakes
      # (paste-upstream → push → re-lock, docs/todo/upstream.md); re-add
      # ONLY via first-hand keep-going evidence, never by hand.
      # SHIM UPDATED (2026-10-25 exec-3, third re-float — owner's blanket
      # `nix flake update`): cv@09e0882 specified 1o2UQtLN (this shim, baked
      # for 29868e05), got IzjuTWg… (first-hand keep-going proof,
      # ~/.cache/lockfloat/float-proof-20261025-172436.log) — the module
      # graph moved AGAIN. Upstream keeps baking stale values, so dropping
      # the shim cannot work; drop only when upstream bakes IzjuTWg…
      # (paste-upstream → push → re-lock, docs/todo/upstream.md).
      # FOURTH RE-STALE 2026-10-26 lock float: cv@24fc6623 spec IzjuTWgn,
      # got 5Xjd8Czb (float-proof-20261026-161006.log) — drop only when
      # upstream bakes 5Xjd8Czb.
      # FIFTH RE-STALE 2026-10-27 lock float: cv@5165e44 spec 5Xjd8Czb,
      # got N9Zsy7bb (float-proof-20261027-172949.log) — drop only when
      # upstream bakes N9Zsy7bb.
      # SIXTH RE-STALE 2026-10-27 lock float: cv@0d50fb7 spec N9Zsy7bb,
      # got 0YovMWLa (float-proof-20261027-202139.log) — drop only when
      # upstream bakes 0YovMWLa.
      # SEVENTH RE-STALE 2026-10-27 lock DE-FLOAT: cv back to 5165e44
      # (registry+lock in sync at 5165e44), spec 0YovMWLa, got N9Zsy7bb
      # (float-proof-20261027-212821.log — same truth as the fifth re-stale
      # above; 5165e44's modules hash is N9Zsy7bb, two proofs agree).
      # EIGHTH RE-STALE 2026-10-27 strand re-float: cv@f22274e spec
      # N9Zsy7bb, got 0YovMWLa (float-proof-20261027-220636.log — f22274e's
      # module set matches 0d50fb7's; the strand flaps between two upstream
      # states and this hash tracks the LOCKED rev, whatever it is).
      # INTERIM-ROLLBACK (2026-10-28, deploy-fix session): cv@8243b2d (the
      # 10-27/28 strand-float rev this shim last tracked) parses its OWN
      # embedded config defaults badly — the binary dies at boot ("yaml:
      # line 426: mapping values are not allowed", defaults seam mid-refactor
      # de9822178). Rolled the input back to 5165e44, the gen-956-proven rev
      # that ran healthy until the strand float (modules hash N9Zsy7bb…,
      # two float-proofs agree). The fix (de9822178, config tests green
      # locally) is NOT pushed — do NOT float cv until origin/master carries
      # it and the boot parse is re-proven; re-add shims ONLY via
      # nix-hash-fix evidence, never by hand.
      # LIFTED 2026-10-28 (owner blanket `nix flake update`): the rollback
      # condition is met — origin/master tip 1e22121 CONTAINS de9822178
      # (`git merge-base --is-ancestor`, 64 commits back), so the config
      # parse fix the interim rollback waited for is published. The boot
      # parse re-proof rides the deploy (post-deploy cv smoke +
      # `journalctl -u cv-server`); if it still dies on its embedded
      # defaults, roll the input back to 5165e44 instead of re-pinning.
      # NINTH RE-STALE 2026-10-28 float: cv@1e22121 spec N9Zsy7bb, got
      # MeDzARcT (first-hand,
      # ~/.cache/lockfloat/float-proof-20261028-214409.log).
      # TENTH RE-STALE 2026-10-28 (deploy-fix session, post-push float): the
      # fix-bearing tip dd201874b (42 commits past 1e22121, pushed with owner
      # permission) spec MeDzARcT, got autqYveR (first-hand,
      # ~/.cache/lockfloat/float-proof-20261028-cvdd201.log) — the strand
      # keeps flapping; this hash tracks the LOCKED rev.
      # ELEVENTH RE-STALE 2026-10-29 float: cv@e168e6d spec autqYveR, got
      # g1hKglo (first-hand,
      # ~/.cache/lockfloat/float-proof-20261029-180630.log).
      # TWELFTH RE-STALE 2026-11-02 04:12 lock float: cv@aa878d2 spec
      # g1hKglo, got bPvMOBEz (first-hand,
      # ~/.cache/lockfloat/float-proof-20261102-043225-lars.log).
      # THIRTEENTH RE-STALE 2026-11-02 21:03 lock float: cv@80c2c88 spec
      # bPvMOBEz, got ENX8uAcw (first-hand,
      # ~/.cache/lockfloat/float-proof-20261102-210359.log).
      # ROLLBACK 2026-11-03 (deploy session): rev back to 16a656f4,
      # restoring the proven hash. ORIGINAL CAUSAL CLAIM RETRACTED
      # 2026-11-03 ~21:15 (journal + source verification): "80c2c88
      # panic-loops / 16a656f4 gen-973-green" was FALSE — the
      # rehydration-timeout → samber/do healthcheck nil-deref
      # (sessions_chatstore.go:112) is rev-independent (identical code at
      # HEAD), first SIGSEGV was 2026-11-02 14:06 on cv@aa878d2 with the
      # restart counter already at 17, 228 SIGSEGVs hit the pinned rev
      # across boot deed9c84, and 16a656f4 panicked identically
      # post-rollback (18:52/19:08/19:24). Trigger: pipeline_events
      # outgrew the 5 s sqliteOperationTimeout on full-scan All(). The
      # rollback's real value: bPvMOBEz is the PROVEN hash (gen-972/973
      # built and ran it; gen-975 rebuilt it deterministically),
      # superseding the thirteenth entry's ENX8uAcw. The pin is build-hash
      # stability ONLY — the real fix is upstream CV (nil-guard + chunked
      # rehydration; TODO row in docs/todo/upstream.md).
      # FOURTEENTH RE-STALE 2026-11-06 lock float: cv@64e0e10 spec
      # bPvMOBEz, got aCVmXAeF (first-hand keep-going,
      # ~/.cache/buildwave/proof-090209.log).
      # FIFTEENTH FLOAT 2026-11-06 (A.Team stored-login deploy): cv@bb27417
      # (pushed tip carrying the chatstore nil-guard fix 8f999a2de + the
      # credentials-store waves) — FOD probe GREEN under the SystemNix graph
      # with the UNCHANGED aCVmXAeF shim (the go.mod module set is stable
      # across 64e0e10 → bb27417; graphs converged, no re-stale).
      # SIXTEENTH RE-STALE 2026-11-07 20:04 lock float: cv@da7f3cbc spec
      # aCVmXAeF, got EKiWDhsV (first-hand keep-going,
      # ~/.cache/lockfloat/float-proof-20261107-200453.log).
      # SHIM DROPPED 2026-11-09 (seventeenth entry, first-hand): the lock
      # moved to cv@ff70e6a in 3b46b915d and the EKiWDhs… shim FOD-failed
      # with `got: sha256-khUW8NWGXB3YdZrmYUV2vFhzYYldBhBsOYHrYreayKY=`.
      # Upstream nix/packages.nix:79 AT THAT REV bakes exactly that hash
      # (`git show ff70e6a:nix/packages.nix` — the 2026-11-08 pareto-P15
      # upstream re-pin), so the documented drop condition is met: the shim
      # was tracking a rev whose node graph upstream had already re-baked.
      # Re-add ONLY via fresh first-hand nix-hash-fix evidence, never by hand.
      cvPkg = inputs.cv.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      imports = [
        inputs.cv.nixosModules.default
        # Platform-truth catalog entry (ADR-008): unconditional — the CV site
        # exists platform-wide even where this host has it disabled. The
        # catalog OPTION comes from nixosModules.catalog, which every host
        # (and VM test) importing cv.nix must also import — a missing import
        # fails LOUDLY at eval, which is the point (no silent absence).
        {
          services.catalog.cv = {
            subdomain = "cv";
            port = ports.cv;
            description = "CV site and PDF export";
            healthPath = "/health/live";
          };
        }
      ];

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

      options.services.cv-server.relogin = {
        enable = lib.mkEnableOption ''
          Scheduled platform re-login: a oneshot runs
          `cv profile relogin --platform <id> --headless` as the cv service
          user from the served state dir, resolving each platform login from
          the SEALED credentials store (sops carries only the master key).
          The refreshed session lands in the state dir's
          data/accounts/<id>/state.json — the same seam `cv profile
          accounts` and the ateam verb chain read. Inert-safe before the
          owner seeds a password credential: an unseeded platform is SKIPPED
          with a WARN instead of paging (a seeded-but-failing relogin DOES
          fail the unit into onFailure — same for a broken store, while a
          fully-unseeded store exits 10 which SuccessExitStatus keeps green).
        '';

        platforms = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "ateam"
            "freelancermap"
            "gun.io"
          ];
          description = ''
            Platform slugs to refresh. Each needs a deployed spec carrying
            automation_spec.login_url + session_cookie under
            data/freelance-platforms/ AND a kind=password credential in the
            sealed store; either half missing skips that platform with a
            WARN (all three ship both spec fields since CV 2026-11-07).
          '';
        };

        schedule = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 09:11:00";
          description = "OnCalendar for the expiry-gated refresh sweep (daily default, 09:11 — 30 min before the session probe so it verifies the FRESH session). Each run only ACTS on platforms whose session is not fresh or expires within relogin.leadDays.";
        };

        leadDays = lib.mkOption {
          type = lib.types.ints.positive;
          default = 7;
          description = "Refresh lead time in days: a due platform (sessionState not fresh, or earliestExpiry inside this window) is re-logged-in on the daily run; fresh sessions with far expiry are skipped without launching a browser.";
        };

        chromiumPackage = lib.mkOption {
          type = lib.types.package;
          default = pkgs.chromium;
          description = "Chromium exported as CHROMIUM_EXECUTABLE_PATH to Playwright (tests substitute a stub to keep the VM closure light).";
        };

        playwrightPackage = lib.mkOption {
          type = lib.types.package;
          default = pkgs.playwright;
          description = "playwright-core JS package exposed on NODE_PATH as node_modules/playwright (the served state dir has no node_modules).";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = cfg.package;
          description = "CV derivation the relogin loop invokes (the due gate's accounts listing AND the relogin verb). Tests substitute a stub to assert the invoke path without a browser or a real portal login.";
        };

        metrics = {
          enable = lib.mkEnableOption ''
            Textfile metrics for the credentials loop: cv_stored_logins per
            platform+kind from the sealed store's read model, and
            cv_relogin_last_result / cv_relogin_last_result_age_seconds per
            platform from the relogin run's status file (data/relogin-status.tsv
            under the state dir). Written to the node_exporter textfile dir as
            cv-credentials.prom — counts only, never secret material.
          '';
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
          cvPkg
        ];

        services.cv-server = {
          package = lib.mkDefault cvPkg;
          port = lib.mkDefault ports.cv;
          environmentFile = lib.mkDefault config.sops.templates."cv-env".path;

          # go-credentials-store (2026-11-06, A.Team stored-login + relogin):
          # sealed platform credentials (A.Team password first) resolve
          # server-side via credentials.Active(); the admin UI at
          # /admin/credentials/ (same Pocket-ID/API-key guard as /admin) is
          # the ONLY write path (store SDK has no public write API). The
          # master key rides CREDENTIALS_MASTER_KEY_V1 in the sops cv-env
          # template (env wins over the state-file fallback). The flag is
          # kept as the EXPLICIT contract even though CV is store-on-by-
          # default since 2026-11-06 (auto-boots on a provisioned key):
          # =1 makes a broken key FATAL here instead of degrading to the
          # env seam — production wants the fail-closed posture.
          environment = {
            CV_CREDENTIALS_STORE_ENABLED = "1";
            # Absolute pin (the graphrag.store_dsn precedent): the default
            # data/credentials-store is CWD-relative and only resolves right
            # because WorkingDirectory = /var/lib/cv. data/ ROOT files are
            # never touched by the upstream content sync, so the sealed
            # credentials.db persists across restarts — but NOT covered by
            # cv-backup (pipeline.sqlite only); re-seed via the admin UI if
            # the state dir is ever lost.
            CV_CREDENTIALS_STORE_DIR = "/var/lib/cv/data/credentials-store";
          };

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
              # One-click funnel tail. LIVE 2026-10-17 (gate Q1 decided:
              # local-relay SMTP, not agentmail — the AgentMail API key was
              # never provisioned and the shared mail relay needs zero new
              # secrets; see the autosend_driver comment below):
              # enabled=true + send_on_approve=true with autosend_driver
              # "smtp". Approvals now send real email, bounded by
              # max_per_pass=5 per sweep and the max_approval_age_days=7
              # staleness cap (the 379 dry-run-era approvals older than 7
              # days stay approved-pending-send, never fire).
              # THE TRANSPORT IS THE GATE, not send_on_approve. First-send
              # probe evidence lands in owner-gate-package-going-live.md
              # gate Q1 (A2: recipient inbox + From/Reply-To + PDF).
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
                # Drain-burst guard (funnel.md): skip sends for approvals
                # older than 7 days when the driver flips live — the 379
                # queued dry-run-era approvals must NOT all fire at once.
                max_approval_age_days = 7;
                never_reapply_rejected_companies = true;
                # Recruiter replies must not hit the no-reply From (the
                # relay's sending domain has no inbound mailbox). The
                # PERMANENT public identity is applications@artmann.tech
                # (owner ruling 2026-10-27, fam.22.1 — gate-Q3: switching
                # reply_to later orphans SentTo reply matching, so this is
                # the ONE-TIME cutover, free while zero real sends carry
                # it). artmann.tech MX stays Google Workspace: the address
                # is a Google-side alias/forward (owner action, zero DNS)
                # funneling into the polled Stalwart mailbox below; until
                # that forward exists, replies to this address rest at
                # Google — nothing is lost while no live application
                # carries it.
                reply_to = "applications@artmann.tech";
              };
              # Send transport: SMTP through the LOCAL postfix null client
              # (127.0.0.1:25, loopback-trusted, no AUTH) → smtp.resend.com
              # (mail-relay module, live since 2026-09-18: real key,
              # test send `status=sent (250)`, larsartmann.cloud verified
              # via the send./rsend. CNAMEs). NO sops secret rides the CV
              # unit — apps never hold the upstream credential (that is
              # the whole point of the shared relay).
              # AgentMail stays a LEGACY reply surface, not the send
              # transport — its API key was never provisioned, and the
              # relay path needs zero.
              autosend_driver = "smtp";
              smtp = {
                host = "127.0.0.1";
                port = 25;
                username = "";
                password = "";
                from = "noreply@larsartmann.cloud";
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
              # Self-hosted Stalwart reply inbox (JMAP reader, migration P1
              # landed 2026-10-26): takes DI priority over the legacy
              # agentmail reader. INERT until CV_PIPELINE_MAILBOX_PASSWORD
              # exists in the sops cv-env template AND the account exists
              # on the mail host (pbx-artmann hosts/pbx/mail.nix provision
              # plan: applications@larsartmann.cloud, added 2026-10-27).
              # The PUBLIC identity applications@artmann.tech forwards
              # here (Google-side alias); the legacy agentmail.to forwards
              # here too before that account closes (owner Q3 ruling:
              # audit -> forward -> close).
              mailbox = {
                enabled = true;
                host_url = "https://mail.artmann.tech";
                username = "applications@larsartmann.cloud";
                # password: CV_PIPELINE_MAILBOX_PASSWORD via the sops
                # cv-env template overrides this at load time (set the
                # account password once in the Stalwart webadmin, then
                # sops). Empty here = the poller self-disables, inert.
                password = "";
                mailbox = "";
              };
              # AgentMail (LEGACY — owner Q3 ruling 2026-10-27, fam.22.3:
              # AUDIT -> FORWARD -> CLOSE, not immediate delete): before
              # this account closes, (1) audit its inbox for unretrieved
              # mail, (2) set an agentmail-side forward to
              # applications@larsartmann.cloud (single source of truth on
              # the own server), only then (3) close the account + run the
              # M14 code sweep. reply_to above already moved to
              # applications@artmann.tech — the forward is what keeps the
              # historical agentmail identity's replies foldable. Keys stay
              # empty (the Stalwart reader owns the poll now):
              #   CV_PIPELINE_AGENTMAIL_API_KEY / _INBOX_ID in the sops
              #   cv-env template would re-enable the legacy reader as a
              #   DI fallback (Stalwart > AgentMail > off).
              agentmail = {
                api_key = "";
                inbox_id = "";
              };
            };
            # Kith CRM sync (Twenty-compatible REST subset — the pipeline
            # mirrors applications into the Kith CRM as deals; runbook:
            # ledger repo docs/ops/CV-SYNC.md). base_url is the ledger
            # crm-server's -addr (loopback, behind its -api-token bearer
            # gate). Same env-secret pattern as agentmail: api_key stays
            # empty here and CV_CRM_API_KEY (sops cv-env template) overrides
            # it at load time. NOTE: applyEnvOverrides is a PULL over keys
            # that exist in the loaded yaml — with no crm block at all the
            # syncer boots "disabled (no crm.enabled or crm.api_key)" even
            # with the env var set, so both keys must be present here.
            crm = {
              enabled = true;
              # Port-registry derived (ports.crm = 8091, lib/ports.nix) —
              # never a hardcoded literal (port-registry-audit rule).
              base_url = "http://127.0.0.1:${toString ports.crm}";
              api_key = "";
              timeout = "30s";
              # Durable replay checkpoint (cv c3d3bfc76, repo config.yaml
              # checkpoint_path): persists the appID → CRM link map across
              # restarts so a full-journal replay cannot re-create
              # opportunities. WITHOUT it every pipeline event re-drives the
              # syncer from scratch — measured 175k CRM events/day churn
              # (journal-growth alarm 2026-11-08, 100% bot:cv-pipeline).
              # Absolute state-dir pin (the graphrag.store_dsn precedent):
              # data/ root survives the upstream content sync and exists
              # today; a relative default would only resolve via
              # WorkingDirectory luck.
              checkpoint_path = "/var/lib/cv/data/crm-checkpoint.json";
            };
            # journald/SigNoz ingestion friendliness: structured JSON lines
            # instead of the text default (internal/config LogFormatJSON).
            logging.format = "json";
            # openaicompat ENABLED 2026-11-02 (owner order, superseding the
            # same-day disable): chat runs on Synthetic — base_url +
            # syn:large:text per the openseo precedent, auth + a live
            # completion verified HTTP 200 pre-copy. The key rides
            # OPENAICOMPAT_API_KEY (cv-env sops template; cv.yaml
            # cv_openaicompat_api_key) and landed in the SAME commit — the
            # FLIP-TIMING rule stands: never enable without the key (the
            # retired warn class was exactly enabled-with-empty-key).
            # TTS/STT stay OFF: the Go defaults are Groq-shaped
            # (canopylabs/orpheus-v1-english, whisper-large-v3) and Synthetic
            # serves no /audio/* surface — enabled voice = broken calls.
            # HealthCheck is wiring-only (zero network calls), so
            # enabled+keyed adds no warn row.
            openaicompat = {
              enabled = true;
              base_url = "https://api.synthetic.new/openai/v1";
              api_key = ""; # rides OPENAICOMPAT_API_KEY (cv-env template)
              chat = {
                enabled = true;
                model = "syn:large:text"; # required when chat.enabled (no default)
              };
              tts.enabled = false; # Groq-shaped default unusable on Synthetic
              stt.enabled = false; # whisper default unusable on Synthetic
            };
            # Absolute state-dir path: the default (data/graphrag.sqlite) is
            # CWD-relative, which happens to resolve correctly today but only
            # because WorkingDirectory = /var/lib/cv. Pin it so graphrag can
            # be enabled later without a relative-path surprise (module is
            # disabled by default; the key is inert until then).
            graphrag.store_dsn = "/var/lib/cv/data/graphrag.sqlite";
            # Operator sign-in via Pocket ID (native OIDC, Layer 1 — moved
            # off protectedVHost 2026-09-13 per the docs/agents/sso-dns.md double-auth
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
              ]
          # Kith CRM replay ordering: the pipeline syncer's startup event
          # replay (career-pipeline/crm Syncer.Start) fires thousands of REST
          # calls with NO retry — a joint restart where cv-server comes up
          # while crm-server is still binding loses the whole backfill
          # (2026-10-03 switch: 10489 refused company creates in 11 s, all
          # dropped until the next cv restart). after+wants orders the
          # restart; the ExecStartPre socket wait below closes systemd's
          # started-but-not-yet-listening gap.
          ++ lib.optionals (config.services.crm-server.enable or false) [
            "crm-server.service"
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
              ]
          ++ lib.optionals (config.services.crm-server.enable or false) [
            "crm-server.service"
          ];
          inherit onFailure;

          # late-applications (2026-10-28 boot-critical-chain review): the
          # 2026-10-28 00:42 boot sat 285s in the boot transaction on this
          # unit — multi-user.target completed the INSTANT cv-server started
          # (journal-proven). Its chain drags pocket-id-provision's fail-retry
          # cycle (the OpenCloud Web secret TODO) plus the 120s crm-server
          # socket wait, none of which is boot-critical for a desktop+server
          # hybrid. Same placement as the 2026-10-26 ordering-cycle class fix
          # (16 units, gen-955). mkForce: the upstream cv module defaults to
          # multi-user.target.
          wantedBy = lib.mkForce [ "late-applications.target" ];

          # ~/projects writer (2026-10-28 projects-subvol plan D6): the CV
          # checkout (workingDirectory/profileDir) lives under ~/projects —
          # fail loud when the Samsung subvol mount is absent instead of
          # rendering from the stale @ shadow. Conditional on the mount being
          # declared (VM/test hosts unaffected).
          unitConfig.RequiresMountsFor =
            lib.optionals (builtins.hasAttr "/home/lars/projects" config.fileSystems)
              [ "/home/lars/projects" ];

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
              # Wait (bounded, fail-open) for crm-server's socket before the
              # event replay runs — see the after/wants note above. The
              # /dev/tcp probe needs no caps and no curl in the closure
              # (same idiom as fastflowlm's proxy-conn wait).
              ExecStartPre = lib.optionals (config.services.crm-server.enable or false) [
                "${pkgs.bash}/bin/bash -c 'deadline=$$((SECONDS + 120)); until (exec 3<>\"/dev/tcp/127.0.0.1/${toString ports.crm}\") 2>/dev/null; do if [ \"$$SECONDS\" -ge \"$$deadline\" ]; then echo \"cv-server: crm-server 127.0.0.1:${toString ports.crm} not reachable within 120s — starting anyway (CRM sync backfill waits for the next restart)\" >&2; exit 0; fi; sleep 1; done'"
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
                # bridge's env file AND the scoped store-key template
                # (cv-store-key-env, the P6 split). cfg.environmentFile is
                # this wrapper's own mkDefault (the sops template), so no
                # duplication.
                EnvironmentFile = lib.mkForce [
                  cfg.environmentFile
                  oidcEnvFile
                  cvStoreKeyEnvFile
                ];
              }
            )
            (lib.mkIf
              (!(
                (cfg.settings.oidc.enabled or false) && (config.services.pocket-id-config.provision.enable or false)
              ))
              {
                # Non-OIDC shape still gets the key template (P6): the store
                # must boot wherever cv-server runs.
                EnvironmentFile = lib.mkForce [
                  cfg.environmentFile
                  cvStoreKeyEnvFile
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

            # Fast path: every entry already service-owned, owner-writable,
            # AND fully traversable — find exits nonzero when it cannot
            # descend a foreign 0700 dir, which is drift too (then-branch
            # skipped). The -perm clause is load-bearing (2026-09-20 13:50):
            # cv-OWNED entries can still carry read-only modes (store-mode
            # copies / operator chmod) — ownership alone passes this check
            # while the sync's rm -rf EPERMs on the write-less parents, so
            # the fast path must flag missing owner-write bits exactly as
            # broadly as the heal below repairs them. Symlinks are safe:
            # find's -perm/-user test the LINK itself (mode 0777), never
            # the read-only store target.
            if stray=$(find "$state" -xdev \( ! -user ${cfg.user} -o ! -group ${cfg.group} -o ! -perm -u+w \) -print -quit 2>/dev/null); then
              if [ -z "$stray" ]; then
                exit 0
              fi
            fi

            echo "cv-state-perms: foreign-owned entries under $state — healing for ${cfg.user}:${cfg.group}"
            # Heal summary: what + how much + sample, so a RECURRING writer
            # (the upstream sync's store-mode copies re-materialize read-only
            # trees on every start until the upstream post-copy chmod reaches
            # the lock) is visible in the journal instead of an anonymous
            # green fast-path.
            drift_count=$(find "$state" -xdev \( ! -user ${cfg.user} -o ! -group ${cfg.group} -o ! -perm -u+w \) -print 2>/dev/null | wc -l)
            drift_sample=$(find "$state" -xdev \( ! -user ${cfg.user} -o ! -group ${cfg.group} -o ! -perm -u+w \) -print 2>/dev/null | head -3 | tr '\n' ' ')
            echo "cv-state-perms: healing $drift_count drifted entries (sample: ''${drift_sample:-none})"
            chown ${cfg.user}:${cfg.group} "$state" 2>/dev/null || true
            find "$state" -xdev -exec chown ${cfg.user}:${cfg.group} {} + 2>/dev/null || true
            # Write permission, not just ownership: the sync's rm -rf
            # unlinks via DIR-write and its cp overwrites files in place —
            # a root-owned 0555 tree stays unwritable after chown alone.
            # Split by type so the config.yaml symlink is never chmod'd
            # through to its read-only store target.
            find "$state" -xdev -type d -exec chmod u+w {} + 2>/dev/null || true
            find "$state" -xdev -type f -exec chmod u+w {} + 2>/dev/null || true
            # Convergence check: a non-empty leftover names an unhealable
            # residue (e.g. a mount the caps cannot touch) — warn loudly,
            # never fail the boot.
            leftover=$(find "$state" -xdev \( ! -user ${cfg.user} -o ! -group ${cfg.group} -o ! -perm -u+w \) -print -quit 2>/dev/null) || true
            if [ -n "$leftover" ]; then
              echo "cv-state-perms: WARNING — unhealable residue remains: $leftover" >&2
            else
              echo "cv-state-perms: converged ($drift_count entries healed)"
            fi
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
        # The only sanctioned creator of the pool leaf (mkPoolDirUnit carries
        # the full 226/NAMESPACE + tmpfiles-shadow doctrine; gate resolves to
        # the /mnt/pool mount prefix either way).
        systemd.services.cv-backup-dir = mkPoolDirUnit {
          description = "Create CV backup directory on the HDD pool";
          directory = backupDir;
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
                store="/var/lib/cv/data/credentials-store/credentials.db"
                ts=$(date +%Y%m%dT%H%M%S)
                if [ ! -f "$db" ]; then
                  echo "cv-backup: no pipeline.sqlite yet — nothing to back up"
                else
                  dst="${backupDir}/pipeline-$ts.sqlite"
                  ${lib.getExe pkgs.sqlite} "$db" ".backup '$dst'"
                  # 14-day retention (pocket-id-backup pattern): the online
                  # .backup rewrites every page, so nothing is shared between
                  # nights — without pruning the pool dir grows forever.
                  find "${backupDir}" -name "pipeline-*.sqlite" -mtime +14 -delete
                  echo "cv-backup: wrote $dst"
                fi
                # SEALED credentials store (2026-11-09): the portal logins the
                # cv-relogin unit decrypts. The artifact is ciphertext — the
                # master key lives only in sops — but losing it costs a manual
                # re-seed of every login (the store SDK has no public write
                # API, so the server cannot restore it), which is exactly what
                # a nightly copy prevents. Read-only URI: the live server owns
                # the WAL writer.
                if [ -f "$store" ]; then
                  sdst="${backupDir}/credentials-$ts.sqlite"
                  ${lib.getExe pkgs.sqlite} "file:$store?mode=ro" ".backup '$sdst'"
                  find "${backupDir}" -name "credentials-*.sqlite" -mtime +14 -delete
                  echo "cv-backup: wrote $sdst"
                else
                  echo "cv-backup: no credentials store yet — skipped"
                fi
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
              # Boot-race close (2026-10-17): cv-server is Type=simple —
              # systemd marks it Started at fork, ~15s before the Go app
              # binds ${toString cfg.port} (2026-10-17 boot: cv-scan curl
              # exit-7 at 18:14:18 while the listener came up 18:14:31 —
              # after/wants alone cannot close that gap). Bounded fail-open
              # /dev/tcp wait, same idiom as the crm-server wait above: if
              # cv-server is genuinely down the curls below fail loudly
              # (that is the unit's job), and 60s stays under the 90s
              # systemd start-timeout default.
              ExecStartPre = "${pkgs.bash}/bin/bash -c 'deadline=$$((SECONDS + 60)); until (exec 3<>\"/dev/tcp/127.0.0.1/${toString cfg.port}\") 2>/dev/null; do if [ \"$$SECONDS\" -ge \"$$deadline\" ]; then echo \"cv-scan: cv-server 127.0.0.1:${toString cfg.port} not reachable within 60s - proceeding (curl will fail loudly if it is really down)\" >&2; exit 0; fi; sleep 1; done'";
              TimeoutStartSec = 180;
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
                # (LIVE 2026-10-17: the tail now tailors AND drains
                # approved-pending-send through the local-relay SMTP
                # transport — bounded by max_per_pass=5 + the 7-day
                # staleness cap.)
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

        # Agent-brain pass (CV prepared diff, docs/operations/cv-agent-timer.md,
        # deployed 2026-11-02 with CV_AGENT_API_KEY): review findings +
        # conditional self-learning distill, daily. Advisory-only by
        # construction (the agent never sends and never writes the funnel
        # store; the human approval gate is untouched). 503 = the brain is
        # dark again (CV_AGENT_API_KEY missing/rotated — warn, not fail: the
        # enable-window shape); 409 = a pass or manual mission is already in
        # flight (fine); 404 = the deployed server predates the route →
        # flake-input bump needed (fail).
        systemd.services.cv-agent = {
          description = "CV agent brain pass (review + self-learning, HTTP)";
          after = [ "cv-server.service" ];
          wants = [ "cv-server.service" ];
          inherit onFailure;
          startLimitBurst = 2;
          startLimitIntervalSec = 600;

          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              # Same Type=simple boot-race as cv-scan (2026-10-17 lesson:
              # after/wants alone cannot close the ~15s bind gap; the
              # 04:41 Persistent catch-up after a 04:40 boot would hit it).
              # Bounded fail-open wait — if cv-server is genuinely down the
              # curl below fails loudly, which is the unit's job.
              ExecStartPre = "${pkgs.bash}/bin/bash -c 'deadline=$$((SECONDS + 60)); until (exec 3<>\"/dev/tcp/127.0.0.1/${toString cfg.port}\") 2>/dev/null; do if [ \"$$SECONDS\" -ge \"$$deadline\" ]; then echo \"cv-agent: cv-server 127.0.0.1:${toString cfg.port} not reachable within 60s - proceeding (curl will fail loudly if it is really down)\" >&2; exit 0; fi; sleep 1; done'";
              TimeoutStartSec = 180;
              # Same sops template the server reads — the systemd manager
              # injects it, so the hardened sandbox never touches the
              # secret file itself.
              EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [
                cfg.environmentFile
              ];
              ExecStart = pkgs.writeShellScript "cv-agent-pass" ''
                set -euo pipefail
                base="http://127.0.0.1:${toString cfg.port}"
                key="''${CV_API_KEY:?CV_API_KEY missing — check the cv-env sops template}"
                code="$(${lib.getExe pkgs.curl} -sS -o /dev/null -w '%{http_code}' -X POST \
                  -H "X-API-Key: $key" "$base/api/agent/pass")"
                case "$code" in
                  200) echo "cv-agent: pass started (findings land in /api/agent/status)" ;;
                  409) echo "cv-agent: a pass is already in flight (ok)" ;;
                  503) echo "cv-agent: 503 (agent.api_key not set — CV_AGENT_API_KEY missing from cv-env; warn, not fail)" >&2 ;;
                  *) echo "cv-agent: $code (unexpected — 404 means the server predates /api/agent/pass: bump the flake input)" >&2; exit 1 ;;
                esac
              '';
            }
            (harden { })
            (serviceOneshotDefaults { })
          ];
        };

        systemd.timers.cv-agent = {
          description = "CV agent brain pass (daily, :41 stagger off cv-scan)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 04:41:00";
            Persistent = true;
            Unit = "cv-agent.service";
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

        # Scheduled re-login from the SEALED credentials store (2026-11-09,
        # expiry-gated since 2026-11-09 v2): this is the app's OWN login loop.
        # The store is the only place a portal password lives — sops carries
        # just its master key — so the operator seeds a password ONCE at
        # https://cv.<domain>/admin/credentials/ and every later session
        # refresh is unattended (which is also why no agent ever needs the
        # plaintext: the unit holds the key, the agent reads the journal).
        #
        # Runs as the SERVICE user from the state dir on purpose: the store
        # dir/key and every session file are cv-owned 0700, and the operator
        # checkout is closed to this user — so this is the only identity that
        # can both decrypt the credential and write the session the served
        # CLI reads. The DUE gate reads `cv profile accounts --json` (the
        # probe's own sessionState/earliestExpiry classification): only
        # not-fresh or expiring-within-leadDays platforms launch a browser.
        # Exit contract (SuccessExitStatus=10 keeps unseeded green):
        #   0 refreshed/nothing due · 10 skipped-unseeded (WARN, no page)
        #   20 a due relogin failed (2FA/SSO, drifted form) · 30 store/gate
        #   broken (fail-closed — pages via onFailure).
        systemd.services.cv-relogin = lib.mkIf cfg.relogin.enable {
          description = "CV platform re-login from the sealed credentials store";
          inherit onFailure;
          startLimitBurst = 3;
          startLimitIntervalSec = 1800;

          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = cfg.user;
              Group = cfg.group;
              WorkingDirectory = cfg.stateDir;
              # 3 platforms × the script's 240s cookie wait + browser start,
              # with slack; the timer slot has no successor to overlap.
              TimeoutStartSec = 1200;
              # The systemd manager injects the SCOPED key template
              # (cv-store-key-env) — the store's CREDENTIALS_MASTER_KEY_V1 is
              # this unit's ONLY secret env (it needs nothing else from
              # cv-env; the P6 split, 2026-11-09).
              EnvironmentFile = [ cvStoreKeyEnvFile ];
              Environment = [
                "HOME=${cfg.stateDir}"
                # Explicit fail-closed posture (production): a broken master
                # key must kill this unit, never silently degrade to the env
                # seam — the server's flag carries the same contract.
                "CV_CREDENTIALS_STORE_ENABLED=1"
                "CV_CREDENTIALS_STORE_DIR=${cfg.stateDir}/data/credentials-store"
                "CHROMIUM_EXECUTABLE_PATH=${cfg.relogin.chromiumPackage}/bin/chromium"
                "NODE_PATH=${playwrightModules}/lib/node_modules"
                "PATH=${
                  lib.makeBinPath [
                    pkgs.bun
                    pkgs.coreutils
                    pkgs.gnugrep
                    pkgs.jq
                    pkgs.sqlite
                  ]
                }"
              ];
              # Exit 10 (skipped-unseeded) is a GREEN run: an unseeded
              # store is a pending owner act, never a page. 20/30 stay
              # failures and hit onFailure.
              SuccessExitStatus = [ 10 ];
              ExecStart = pkgs.writeShellScript "cv-relogin" ''
                                set -euo pipefail
                                # Exit contract (mirrors the unit comment):
                                #   0 ok · 10 skipped-unseeded · 20 relogin failed · 30 broken
                                store_dir="''${CV_CREDENTIALS_STORE_DIR:-${cfg.stateDir}/data/credentials-store}"
                                store_db="$store_dir/credentials.db"
                                sqlite_bin="${lib.getExe pkgs.sqlite}"
                                jq_bin="${lib.getExe pkgs.jq}"
                                cv_bin="${lib.getExe cfg.relogin.package}"
                                # Command indirection through a function (nullglob-audit
                                # class A/B: a $var in command position is banned here).
                                run_cv() { "$cv_bin" "$@"; }
                                # Generated scripts live OUTSIDE the content dirs: the sync
                                # overwrites shipped files inside the eight data/<content>
                                # dirs on every start, and these are runtime artifacts.
                                out_dir="${cfg.stateDir}/data/relogin-scripts"
                                mkdir -p "$out_dir"

                                if [ ! -f "$store_db" ]; then
                                  echo "cv-relogin: sealed store missing at $store_db (it boots from the sops master key; cv-server creates it) — cannot re-login" >&2
                                  exit 30
                                fi

                                # The DUE gate's input: the probe's own session classification.
                                # A listing failure means we cannot classify safely — fail closed.
                                if ! accounts="$(run_cv profile accounts --json)"; then
                                  echo "cv-relogin: 'cv profile accounts --json' failed — cannot classify due platforms" >&2
                                  exit 30
                                fi

                                deadline=$(( $(date +%s) + ${toString cfg.relogin.leadDays} * 86400 ))
                                seeded_any=0
                                failed=0
                                # Per-platform results for the metrics collector (tsv written
                                # atomically at the END of a completed sweep; a broken-store
                                # run exits before this and leaves the previous file aging).
                                status_file="${cfg.stateDir}/data/relogin-status.tsv"
                                status_lines=""
                                for platform in ${lib.escapeShellArgs cfg.relogin.platforms}; do
                                  # Seed gate first: no kind=password credential = nothing to
                                  # log in with YET (owner seeding step) → WARN + skip. An
                                  # unreadable store is a real failure (bad key/schema) → 30.
                                  if ! seeded=$("$sqlite_bin" "file:$store_db?mode=ro" \
                                    "select count(*) from meta_planned_credentials_by_platform where platform = '$platform' and kind = 'password';"); then
                                    echo "cv-relogin: could not read the store read model at $store_db" >&2
                                    exit 30
                                  fi
                                  state=$(printf '%s' "$accounts" | "$jq_bin" -r --arg p "$platform" \
                                    '([.[] | select(.platform == $p)][0] // {}) | .sessionState // "unknown"')
                                  expiry=$(printf '%s' "$accounts" | "$jq_bin" -r --arg p "$platform" \
                                    '([.[] | select(.platform == $p)][0] // {}) | .earliestExpiry // ""')
                                  if [ "$seeded" = "0" ]; then
                                    echo "cv-relogin: $platform state=$state expiry=''${expiry:--} -> skip (unseeded; seed at https://cv.${domain}/admin/credentials/ — platform + kind password)" >&2
                                    status_lines="$status_lines$platform|skipped-unseeded|$(date +%s)
                "
                                    continue
                                  fi
                                  seeded_any=1

                                  # Due rule: not-fresh is due; fresh-but-expiring inside the
                                  # lead window is due too. An unparsable expiry counts as due
                                  # (safe side: attempt the refresh).
                                  due=1
                                  reason="state=$state"
                                  if [ "$state" = "fresh" ] && [ -n "$expiry" ]; then
                                    exp_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
                                    if [ "$exp_epoch" -gt "$deadline" ]; then
                                      due=0
                                    else
                                      reason="expiry=$expiry"
                                    fi
                                  fi
                                  if [ "$due" != "1" ]; then
                                    echo "cv-relogin: $platform state=$state expiry=''${expiry:--} -> skip (not due)"
                                    status_lines="$status_lines$platform|skipped-not-due|$(date +%s)
                "
                                    continue
                                  fi

                                  echo "cv-relogin: $platform $reason expiry=''${expiry:--} -> refresh (headless)"
                                  # tee streams live to the journal while keeping a copy for
                                  # the ErrNoStoredLogin classification (a credential lost
                                  # between gate and run is WARN-class, not a page).
                                  if out="$(run_cv profile relogin --platform "$platform" --headless --output-dir "$out_dir" 2>&1 | tee /dev/stderr)"; then
                                    echo "cv-relogin: $platform refreshed"
                                    status_lines="$status_lines$platform|refreshed|$(date +%s)
                "
                                  elif printf '%s' "$out" | grep -q "no stored login credentials for relogin"; then
                                    echo "cv-relogin: WARN — '$platform' lost its stored login between the gate and the run (ErrNoStoredLogin); the next run re-gates" >&2
                                    status_lines="$status_lines$platform|lost-login|$(date +%s)
                "
                                  else
                                    echo "cv-relogin: '$platform' relogin FAILED — the typed reason is in the journal lines ABOVE (2FA/SSO needing a human, or a drifted login form); runbook: docs/services/cv.md §Credential storage" >&2
                                    status_lines="$status_lines$platform|failed|$(date +%s)
                "
                                    failed=1
                                  fi
                                done

                                tmp_status="$(mktemp "''${status_file}.XXXXXX")"
                                printf '%s' "$status_lines" > "$tmp_status"
                                mv "$tmp_status" "$status_file"

                                if [ "$failed" -ne 0 ]; then
                                  exit 20
                                fi
                                if [ "$seeded_any" -eq 0 ]; then
                                  exit 10
                                fi
                                exit 0
              '';
            }
            (harden {
              # Chromium runs a renderer per tab; the 512M default throttles
              # it to death (the 2026-10-08 watermark class).
              MemoryMax = "3G";
              CPUQuota = "200%";
              # The state dir is the only writable surface (session files,
              # generated scripts, the store's WAL).
              ReadWritePaths = [ cfg.stateDir ];
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        systemd.timers.cv-relogin = lib.mkIf cfg.relogin.enable {
          description = "Daily expiry-gated CV platform re-login (09:11, 30 min before the session probe)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.relogin.schedule;
            Persistent = true;
            Unit = "cv-relogin.service";
          };
        };

        # Credentials-loop textfile collector (SUPERB plan P4, 2026-11-09):
        # makes "the store is empty" and "relogin keeps failing" VISIBLE
        # outside the journal (AC4). Runs as the cv user — the store dir is
        # 0700 cv:cv, so this is the identity that can read it without
        # capability games — and publishes COUNTS only, never secret
        # material:
        #   cv_stored_logins{platform,kind}     rows in the store read model
        #   cv_relogin_last_result{platform}    0 ok/not-due · 10 unseeded or
        #                                       lost login · 20 failed (the
        #                                       unit exit-contract mirror)
        #   cv_relogin_last_result_age_seconds  staleness of the last sweep
        #   cv_credentials_scrape_errors        1 = read failed (fail-closed,
        #                                       never a phantom green)
        # Sticky-1777 textfile doctrine: mktemp inside the dir + atomic mv
        # (boot-metrics / forgejo-mirror pattern); absent dir = WARN skip.
        systemd.services.cv-credentials-metrics = lib.mkIf cfg.relogin.metrics.enable {
          description = "CV credentials-loop metrics collector (textfile)";
          startLimitBurst = 3;
          startLimitIntervalSec = 1800;
          inherit onFailure;
          path = [
            pkgs.coreutils
            pkgs.sqlite
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = cfg.user;
              Group = cfg.group;
              TimeoutStartSec = 60;
            }
            (harden {
              ReadWritePaths = [ "/var/lib/prometheus-node-exporter/textfile_collectors" ];
              MemoryMax = "64M";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            out_dir="/var/lib/prometheus-node-exporter/textfile_collectors"
            if [ ! -d "$out_dir" ]; then
              echo "cv-credentials-metrics: textfile dir absent — skipping prom publish" >&2
              exit 0
            fi
            out="$out_dir/cv-credentials.prom"
            tmp="$(mktemp "$out_dir/cv-credentials.prom.XXXXXX")"
            chmod 644 "$tmp"
            trap 'rm -f "$tmp"' EXIT

            errors=0
            sqlite_bin="${lib.getExe pkgs.sqlite}"
            store_db="${cfg.stateDir}/data/credentials-store/credentials.db"
            status_file="${cfg.stateDir}/data/relogin-status.tsv"
            now="$(date +%s)"

            {
              echo "# HELP cv_stored_logins Sealed credential rows per platform and kind (read-model counts; no secret material)"
              echo "# TYPE cv_stored_logins gauge"
              if [ -f "$store_db" ]; then
                rows="$("$sqlite_bin" "file:$store_db?mode=ro" "select platform || '|' || kind || '|' || count(*) from meta_planned_credentials_by_platform group by platform, kind;" 2>/dev/null)" || errors=1
                if [ -n "$rows" ]; then
                  printf '%s\n' "$rows" | while IFS='|' read -r p k n; do
                    [ -n "$p" ] || continue
                    echo "cv_stored_logins{platform=\"$p\",kind=\"$k\"} $n"
                  done
                fi
              else
                errors=1
              fi

              echo "# HELP cv_relogin_last_result Last sweep result per platform (0 refreshed/not-due, 10 unseeded or lost login, 20 failed)"
              echo "# TYPE cv_relogin_last_result gauge"
              echo "# HELP cv_relogin_last_result_age_seconds Seconds since the last completed sweep recorded this platform"
              echo "# TYPE cv_relogin_last_result_age_seconds gauge"
              if [ -f "$status_file" ]; then
                cat "$status_file" | while IFS='|' read -r p r ts; do
                  [ -n "$p" ] || continue
                  [ -n "$ts" ] || ts="$now"
                  case "$r" in
                    refreshed|skipped-not-due) code=0 ;;
                    skipped-unseeded|lost-login) code=10 ;;
                    *) code=20 ;;
                  esac
                  echo "cv_relogin_last_result{platform=\"$p\"} $code"
                  echo "cv_relogin_last_result_age_seconds{platform=\"$p\"} $(( now - ts ))"
                done
              fi

              echo "# HELP cv_credentials_scrape_errors 1 when the store read failed this run (fail-closed, never a phantom green)"
              echo "# TYPE cv_credentials_scrape_errors gauge"
              echo "cv_credentials_scrape_errors $errors"
            } > "$tmp"
            mv "$tmp" "$out"
            echo "cv-credentials-metrics: published $out"
          '';
        };

        systemd.timers.cv-credentials-metrics = lib.mkIf cfg.relogin.metrics.enable {
          description = "CV credentials-loop metrics (6-hourly textfile)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 00/6:25:00";
            Persistent = true;
            Unit = "cv-credentials-metrics.service";
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
              # CRM mirror dead-letter alarm (2026-10-27 incident bundle):
              # the Kith-mirror syncer PARKS an application after 3
              # consecutive not-found updates — nonzero means real funnel
              # deals are missing from the CRM board until revival. The
              # counter is cumulative since boot, but parked apps do NOT
              # self-heal (revival needs a repair + re-discover/restart),
              # so "any nonzero" is the honest threshold here — the exact
              # opposite of the value-threshold trap on the metrics checks
              # above. Admin card: /admin "CRM mirror".
              {
                name = "CV CRM Mirror Parked";
                group = "Productivity";
                url = "http://localhost:${toString ports.cv}/api/pipeline/crm-status";
                interval = "30m";
                headers = {
                  X-API-Key = "$CV_API_KEY";
                };
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\"deadLettered\":0*)"
                ];
                alert = "CV CRM mirror has parked applications — their CRM link is dead and the funnel deals are missing from the Kith board. Revive: repair the mirror views, then re-discover the apps or restart cv-server (admin hub → CRM mirror). Check: curl -s -H 'X-API-Key: …' http://localhost:8091/api/pipeline/crm-status | jq .deadLettered";
              }
              # CRM mirror endpoint liveness: the guarded crm-status JSON
              # must answer with its contract key present. Catches the
              # mirror surface going dark (DI regression, guard drift,
              # route rename) independently of the parked alarm above.
              # DELTA NOTE: a ">50 sync errors/hour" rate alarm is NOT
              # expressible here (syncErrors is cumulative since boot; a
              # value pat would page forever after the first transient) —
              # the growing-count read lives on the admin hub's CRM mirror
              # card and `journalctl -u cv-server | grep -c 'crm sync'`.
              {
                name = "CV CRM Mirror Status";
                group = "Productivity";
                url = "http://localhost:${toString ports.cv}/api/pipeline/crm-status";
                interval = "30m";
                headers = {
                  X-API-Key = "$CV_API_KEY";
                };
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\"deadLettered\":*)"
                ];
                alert = "CV crm-status endpoint is not answering its JSON contract — the CRM mirror surface is dark (DI, guard, or route regression). Check: journalctl -u cv-server --since -15min; the admin hub's CRM mirror card.";
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
              icon = "open-resume.png";
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
