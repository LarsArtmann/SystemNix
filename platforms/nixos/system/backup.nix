# Offsite Borg leg: Hetzner StorageBox (BX11, 1 TB) over SSH port 23.
#
# Third copy for 3-2-1 (btrbk snapshots = same-disk, HDD pool = same-chassis).
# Decision + rationale: docs/research/hetzner-storagebox-borgbackup.md.
# Client-side repokey-blake2 means Hetzner sees only opaque ciphertext.
#
# DORMANT UNTIL GO-LIVE (enable = false default): the StorageBox hostname and
# username are user-held inputs that do not exist in any secret yet
# (docs/todo/storage.md "Offsite Borg go-live inputs"). With the placeholder
# still in sops, the first run would fail loudly at the go-live tripwire —
# so the whole module (units, sops secrets, backup-coordination row) only
# materializes when services.offsite-borg.enable flips true. Go-live
# checklist: docs/services/offsite-borg.md.
#
# Sizing doctrine (BX11 is 1 TB): the job MUST exclude rebuildable trees
# (/data ai/models/Steam/llamacpp ~700 G, code trees backed by GitHub,
# btrfs receive mirrors + restic repo on the pool) so the irreplaceable set
# (home, /etc, service data, app dumps) fits with dedup + prune headroom.
# Upgrade BX11 → BX21 if the irreplaceable set passes ~800 G — first-run
# `borg create --stats` output is the measurement (docs/todo/storage.md
# retention/sizing row).
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  inherit (import ../../../lib/default.nix lib)
    onFailure
    harden
    ioTier
    serviceOneshotDefaults
    ;
  cfg = config.services.offsite-borg;
  jobUnit = "borgbackup-job-hetzner";

  # Restore-drill env-path pin: the drill's real mode hand-writes the
  # rendered env path (a plain repo script cannot interpolate the
  # template), so its exact BORG_ENV_FILE default is pinned to the sops
  # template path by the assertion below — if the literal drifts,
  # `nix flake check` fails naming the expected literal instead of the
  # drill silently sourcing a stale path mid-incident. Deliberately
  # TOP-LEVEL (not inside the mkIf below): when the template is declared
  # it pins the template's exact .path (catches overrides); while the
  # module is dormant it pins the sops-nix default shape so the guard
  # still fires in the default gate (proven: an in-mkIf placement passed
  # flake check on a drifted script).
  drillScript = builtins.readFile ../../../scripts/borg-restore-drill.sh;
  borgEnvRenderPath =
    if options ? sops.templates && config.sops.templates ? "borg-env" then
      config.sops.templates."borg-env".path
    else
      "/run/secrets/rendered/borg-env";
  drillEnvLiteral = ''BORG_ENV_FILE="''${BORG_ENV_FILE:-${borgEnvRenderPath}}"'';
in
{
  options.services.offsite-borg = {
    enable = lib.mkEnableOption "offsite Borg backup to the Hetzner StorageBox";

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        Source trees for the offsite archive: home (user data), /etc
        (mutable config + host keys), /data (with rebuildable trees
        excluded below), and the pool's app-dump + irreplaceable service
        dirs.
      '';
      default = [
        "/etc"
        "/home/lars"
        "/data"
        "/mnt/pool/backups"
        "/mnt/pool/services/immich"
        "/mnt/pool/services/paperless"
      ];
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        Borg exclude patterns (exact absolute paths). Everything here is
        rebuildable or a redundant local copy — keeping them out is what
        makes the 1 TB BX11 budget work.
      '';
      default = [
        # /data rebuildables (blueprint sizing list: ai 291 G + models 210 G
        # + Steam 106 G + llamacpp 92 G — model weights re-pull, Steam
        # re-downloads; save-game/compatdata exceptions are the owner's
        # call, tracked in docs/todo/storage.md).
        "/data/ai/models"
        "/data/ai/cache"
        "/data/ai/venv-anime-comic"
        "/data/models"
        "/data/SteamLibrary"
        "/data/cache"
        "/data/docker"
        "/data/tmp-bench"
        "/data/tmp-crush-test"
        # Home tool/rebuildable trees. Code lives on GitHub (pushed repos,
        # incl. private); the 2026-08-22 freeze history also makes a nightly
        # full re-read of the projects tree an IO-storm generator.
        "/home/lars/.cache"
        "/home/lars/projects"
        "/home/lars/forks"
        "/home/lars/worktrees"
        "/home/lars/go"
        "/home/lars/immich-temp"
        "/home/lars/.local/share/Trash"
        # Pool btrbk receive mirrors: full local copies of @ and /data
        # (local redundancy, not offsite content — and the /data leg is
        # EIO-corrupt, so reading it would fail the job outright).
        "/mnt/pool/backups/root"
        "/mnt/pool/backups/data"
        # The restic repo IS the dumps backed up directly by this job —
        # archiving it would double-store everything with ~0 dedup.
        "/mnt/pool/backups/restic-app-dumps"
        # Forgejo mirror repos are re-mirrorable from GitHub (forgejo
        # is the READ mirror; the origin never dies with this host).
        "/mnt/pool/backups/forgejo-subvol"
        # Paperless: derived/redundant subtrees (export = pre-PG copy of
        # media; index/llm_index = rebuildable search indexes; trash =
        # deleted docs; consume = staging).
        "/mnt/pool/services/paperless/export"
        "/mnt/pool/services/paperless/index"
        "/mnt/pool/services/paperless/llm_index"
        "/mnt/pool/services/paperless/trash"
        "/mnt/pool/services/paperless/consume"
        # Immich derivatives (re-generable from the originals; the
        # originals + DB dump stay included).
        "/mnt/pool/services/immich/thumbs"
        "/mnt/pool/services/immich/encoded-video"
      ];
    };

    startAt = lib.mkOption {
      type = lib.types.str;
      description = "systemd OnCalendar for the nightly run (staggered after the pool dump/restic window).";
      default = "*-*-* 06:30:00";
    };

    pruneKeep = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      description = ''
        Borg prune retention (blueprint defaults). Deliberately
        conservative — dedup makes generous retention cheap, and the
        final retention policy is still an owner decision
        (docs/todo/storage.md).
      '';
      default = {
        daily = 7;
        weekly = 4;
        monthly = 6;
      };
    };
  };

  config = lib.mkMerge [
    # Forced by `nix flake check` (pre-commit + CI) — scheduled-tasks.nix
    # self-assertion pattern. UNCONDITIONAL branch: the guard must fire in
    # the default gate while the module is still dormant (an in-mkIf
    # placement passed flake check on a drifted script).
    {
      assertions = [
        {
          assertion = lib.hasInfix drillEnvLiteral drillScript;
          message = ''
            borg-restore-drill env-path pin: scripts/borg-restore-drill.sh no
            longer defaults BORG_ENV_FILE to the rendered sops template path
            (${borgEnvRenderPath}). A plain repo script cannot interpolate
            config.sops.templates."borg-env".path, so the literal is pinned by
            this assertion — update the drill's BORG_ENV_FILE default to
            BORG_ENV_FILE="''${BORG_ENV_FILE:-${borgEnvRenderPath}}" (or flake-wrap the
            drill to interpolate at build time; see docs/todo/storage.md).
          '';
        }
      ];
    }
    (lib.mkIf cfg.enable (
      let
        # Rendered sops template (root-owned 0400): BORG_REPO=<user>@<host>:…
        # EnvironmentFile entries override the unit's static Environment=, so
        # the rendered value wins over the placeholder `repo` below at
        # runtime. Interpolated via the template's .path — never the literal
        # /run/secrets-rendered path (audit-textfile-tmp rule).
        envPath = config.sops.templates."borg-env".path;

        # Fail fast with the go-live pointer while the repo target is still
        # the placeholder (google-sync-config-check pattern) — without this,
        # a go-live deploy with an unfilled secret degrades into an opaque
        # ssh "Could not resolve hostname" failure instead of instructions.
        goliveCheck = pkgs.writeShellScript "borg-offsite-golive-check" ''
          if grep -q "PLACEHOLDER" "${envPath}"; then
            echo "offsite-borg: BORG_REPO is still the go-live placeholder."
            echo "Go-live checklist: docs/services/offsite-borg.md"
            echo "  sops platforms/nixos/secrets/borg.yaml   (borg_repo, borg_known_hosts)"
            echo "  services.offsite-borg.enable = true + nix run .#deploy"
            exit 1
          fi
        '';
      in
      {
        # nixpkgs borgbackup module owns the job unit + timer (init-on-first-run,
        # create + prune + compact, idle IO/CPU scheduling, ssh in unit PATH).
        services.borgbackup.jobs.hetzner = {
          inherit (cfg) paths exclude startAt;
          # Remote-shaped placeholder so the unit gets remote handling (no
          # local-path mount wiring); overridden at runtime by the borg-env
          # EnvironmentFile.
          repo = "PLACEHOLDER@go-live.invalid:backups/evo-x2";
          environment = {
            # Dedicated deploy-style key from sops; fail closed on unknown host
            # keys (github knownHosts pin doctrine) until the StorageBox host
            # key is pinned into borg_known_hosts at go-live. -p 23 is
            # LOAD-BEARING: the repo string is scp-form (no port), so the port
            # can only come from here — StorageBox serves Borg on 23 ONLY
            # (port 22 is SCP/SFTP; blueprint protocol table), and the
            # ssh-keyscan -p 23 known_hosts pin is [host]:23-shaped, so a
            # default-port connect would refuse on the host-key lookup anyway.
            BORG_RSH = "ssh -p 23 -i /run/secrets/borg_ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/run/secrets/borg_known_hosts";
            # Borg's chunk cache/config live on the Samsung hot tier — multi-GB
            # caches on @ would be pinned pool-side by btrbk snapshots forever
            # (emergency-reserve pinning doctrine). Cache loss is harmless
            # (rebuilt on the next run, at WAN-upload cost).
            BORG_CACHE_DIR = "/mnt/hot/borg/cache";
            BORG_CONFIG_DIR = "/mnt/hot/borg/config";
          };
          encryption.mode = "repokey-blake2";
          encryption.passCommand = "cat /run/secrets/borg_password";
          # auto: skip incompressible chunks — the sources are already
          # zstd-compressed btrfs data (blueprint's zstd,9, with auto in front).
          compression = "auto,zstd,9";
          archiveBaseName = "evo-x2";
          persistentTimer = true;
          # The cache/config dir must exist before the unit's mount namespace
          # is built (226/NAMESPACE class) — created by borg-offsite-dir below.
          readWritePaths = [
            "/mnt/hot/borg"
            "/var/lib/borg-offsite"
          ];
          prune.keep = cfg.pruneKeep;
        };

        # Mount-gated cache-dir bootstrap (miniflux-backup-dir pattern): the
        # nofail hot mount must be up, and the leaf dir must exist before the
        # job unit starts. Restarted by deploy.sh's provisioner loop.
        systemd.services.borg-offsite-dir = {
          description = "Create borg cache dir on the Samsung hot tier";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ "/mnt/hot" ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            (harden {
              MemoryMax = "128M";
              ReadWritePaths = [ "/mnt/hot" ];
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            mkdir -p /mnt/hot/borg/cache /mnt/hot/borg/config
          '';
        };

        # SystemNix layer over the nixpkgs-rendered job unit.
        systemd.services.${jobUnit} = {
          inherit onFailure;
          after = [ "borg-offsite-dir.service" ];
          wants = [ "borg-offsite-dir.service" ];
          # Clean dependency failure when the hot tier or pool is detached —
          # never a mid-read failure and never a root-fs shadow dir.
          unitConfig.RequiresMountsFor = [
            "/mnt/hot"
            "/mnt/pool"
          ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              EnvironmentFile = envPath;
              StateDirectory = "borg-offsite";
              # First run seeds the whole irreplaceable set over WAN.
              TimeoutStartSec = "2d";
              MemoryMax = "4G";
              ExecStartPre = lib.getExe' goliveCheck "borg-offsite-golive-check";
              # Freshness marker for backup-coordination — only after create +
              # prune + compact all succeeded.
              ExecStartPost = "${pkgs.coreutils}/bin/touch /var/lib/borg-offsite/.last_success";
            }
            # Background IO tier (BFQ BE/6): chunking reads are local NVMe
            # work. nixpkgs renders IOSchedulingClass = "idle", which on this
            # box STARVES — an idle-class job only gets IO when nothing else
            # needs it, so a busy machine would keep the nightly job unread
            # for days and backup-coordination would page stale with no path
            # to green. BE/6 guarantees progress below every interactive tier
            # (lib/default.nix ioTier doctrine). mkForce required: plain
            # values collide with nixpkgs' idle.
            {
              IOSchedulingClass = lib.mkForce ioTier.background.IOSchedulingClass;
              IOSchedulingPriority = ioTier.background.IOSchedulingPriority;
            }
          ];
        };

        # Registry fan-out: freshness row feeds backup_healthy{backup="offsite-borg"}
        # + the aggregate "All Backups Healthy" Gatus check (the Gatus
        # registration for a daemon-less backup unit). No vHost/port — layer
        # "none" (restic-app-dumps shape).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          offsite-borg = {
            vHost.layer = "none";
            # Fan the job unit into system-health's state metrics so a FAILED
            # job reaches Gatus → Discord within one 2m check cycle — the
            # notify-failure@ OnFailure template only covers the DESKTOP;
            # this entry is the Discord leg (borgbackup-job-hetzner is the
            # real unit name, not the entry name).
            unit = jobUnit;
            monitored = true;
            checks = [
              {
                name = "Offsite Borg Job Service";
                group = "Filesystem";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "2m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*system_service_state_failed{service=\"borgbackup-job-hetzner\"} 0*)"
                  "[BODY] == pat(*system_service_start_limit_hit{service=\"borgbackup-job-hetzner\"} 0*)"
                ];
                alert = "Offsite Borg job unit failed or start-limit hit — the third 3-2-1 copy is NOT landing. Check: journalctl -u borgbackup-job-hetzner -n 100 (go-live tripwire, StorageBox reachability, stale repo lock → borg break-lock, docs/services/offsite-borg.md).";
              }
            ];
            backup = {
              directory = "/var/lib/borg-offsite";
              filePattern = ".last_success";
              maxAgeHours = 25;
            };
          };
        };
      }
    ))
  ];
}
