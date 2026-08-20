# Hermes AI Agent Gateway: Discord bot, cron scheduler, messaging
# Projects access: services.hermes.projectsDir bind-mounts the primary
# user's projects tree READ-ONLY into the agent sandbox — see the option
# and the BindReadOnlyPaths wiring below for the rationale.
{inputs, ...}: {
  flake.nixosModules.hermes = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit
      (import ../../../lib/default.nix lib)
      harden
      mkStateDir
      serviceDefaults
      serviceOneshotDefaults
      onFailure
      serviceTypes
      ports
      mkDnsGate
      ;
    cfg = config.services.hermes;
    hermesPkg = let
      # Upstream (v2026.7.20+) uses fetcherVersion=2 in nix/lib.nix, no hash patching needed.
      baseOverlay = inputs.hermes-agent.overlays.default;
      # registration_lifecycle.py is a top-level module in the upstream
      # source but is missing from pyproject.toml's [tool.setuptools]
      # py-modules list, so uv2nix doesn't install it into the sealed
      # venv. hermes_cli/plugins.py imports it at module level, causing
      # ModuleNotFoundError on every startup. We extract the file from
      # the flake source and inject it via PYTHONPATH until upstream
      # adds it to py-modules.
      registrationLifecycle = pkgs.runCommand "hermes-registration-lifecycle" {} ''
        mkdir -p $out/lib/python3.12/site-packages
        cp ${inputs.hermes-agent}/registration_lifecycle.py \
          $out/lib/python3.12/site-packages/
      '';
      pythonPath = "${registrationLifecycle}/lib/python3.12/site-packages";
      patchedOverlay = final: prev: let
        base = baseOverlay final prev;
      in
        base
        // {
          hermes-agent =
            (base.hermes-agent.override {
              extraDependencyGroups = [
                "anthropic"
                "azure-identity"
                "bedrock"
                "daytona"
                "dingtalk"
                "edge-tts"
                "exa"
                "fal"
                "feishu"
                "firecrawl"
                "hindsight"
                "honcho"
                "messaging"
                "matrix"
                "modal"
                "parallel-web"
                "tts-premium"
                "voice"
              ];
            }).overrideAttrs
            (old: {
              nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.makeWrapper];
              postInstall =
                (old.postInstall or "")
                + ''
                  for bin in $out/bin/hermes $out/bin/hermes-agent $out/bin/hermes-acp; do
                    if [ -f "$bin" ]; then
                      wrapProgram "$bin" --suffix PYTHONPATH : "${pythonPath}"
                    fi
                  done
                '';
            });
        };
      pkgs' = pkgs.extend patchedOverlay;
    in
      pkgs'.hermes-agent;
    sopsEnvPath = config.sops.templates."hermes-env".path;
    oldStateDirs = [
      "/home/${cfg.user}/.hermes"
      "/var/lib/hermes"
    ];

    mergeEnvScript = pkgs.writeShellApplication {
      name = "hermes-merge-env";
      runtimeInputs = [pkgs.gnused];
      text = ''
        ENV_FILE="${cfg.stateDir}/.env"

        if [ ! -f "$ENV_FILE" ]; then
          touch "$ENV_FILE"
          chmod 600 "$ENV_FILE"
        fi

        # shellcheck disable=SC2043
        for dep_key in MESSAGING_CWD; do
          if grep -q "^''${dep_key}=" "$ENV_FILE" 2>/dev/null; then
            sed -i "/^''${dep_key}=/d" "$ENV_FILE"
            echo "hermes-merge: removed deprecated key $dep_key from .env"
          fi
        done

        for pair in "OLLAMA_API_KEY=ollama" "TERMINAL_ENV=local"; do
          key="''${pair%%=*}"
          value="''${pair#*=}"
          [ -z "$key" ] && continue
          if grep -q "^''${key}=" "$ENV_FILE" 2>/dev/null; then
            sed -i "/^''${key}=/d" "$ENV_FILE"
          fi
          echo "$key=$value" >> "$ENV_FILE"
        done
      '';
    };

    fixPermissionsScript = pkgs.writeShellApplication {
      name = "hermes-fix-permissions";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
      ];
      text = ''
        if [ "$(stat -c '%U:%G' ${cfg.stateDir} 2>/dev/null)" = "${cfg.user}:${cfg.group}" ] \
           && [ "$(stat -c '%a' ${cfg.stateDir} 2>/dev/null)" = "2770" ]; then
          exit 0
        fi

        echo "hermes-perms: fixing ownership and permissions in ${cfg.stateDir}"
        # Never chown -R the whole stateDir: the read-only projects bind
        # mount (<stateDir>/workspace/projects) turns the recursive chown
        # into EROFS failures, and set -e converts those into a
        # crash-looping ExecStartPre (2026-08-20 start-limit-hit incident).
        # Chown the root explicitly, then walk with find: prune the bind
        # target, stay on one filesystem (-xdev), and tolerate per-entry
        # failures so a foreign mount can never kill the unit again.
        chown ${cfg.user}:${cfg.group} ${cfg.stateDir}
        find ${cfg.stateDir} -xdev -path '${cfg.stateDir}/workspace/projects' -prune -o -exec chown ${cfg.user}:${cfg.group} {} + 2>/dev/null || true
        find ${cfg.stateDir} -xdev -path '${cfg.stateDir}/workspace/projects' -prune -o -type d -exec chmod 2770 {} + 2>/dev/null || true
        # Exec-PRESERVING file chmod: plain `chmod 0660` stripped the
        # execute bit from every binary under stateDir — it killed the
        # agent's self-installed language servers (/home/hermes/lsp/bin,
        # PermissionError on spawn since 2026-08-16). chmod's X flag only
        # adds execute where some class already has it, so data files
        # converge to 0660 while binaries keep (or gain back) their x.
        find ${cfg.stateDir} -xdev -path '${cfg.stateDir}/workspace/projects' -prune -o -type f -exec chmod u=rwX,g=rwX,o= {} + 2>/dev/null || true
      '';
    };

    # Heals LSP binaries stripped by the OLD (0660) perms walk above.
    # Upstream hermes installs language servers into <stateDir>/lsp/bin
    # and <stateDir>/lsp/node_modules/.bin — everything in those
    # convention directories is meant to be executable. Runs as the
    # service user (files are hermes-owned); idempotent no-op once healed
    # or when upstream has not installed any LSPs yet.
    lspBinHealScript = pkgs.writeShellApplication {
      name = "hermes-lsp-bin-heal";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        healed=0
        for dir in "${cfg.stateDir}/lsp/bin" "${cfg.stateDir}/lsp/node_modules/.bin"; do
          [ -d "$dir" ] || continue
          for f in "$dir"/*; do
            [ -f "$f" ] || continue
            if [ ! -x "$f" ]; then
              chmod u+x,g+x "$f"
              healed=$((healed + 1))
            fi
          done
        done
        if [ "$healed" -gt 0 ]; then
          echo "hermes-lsp-heal: restored execute bit on $healed LSP binaries"
        fi
      '';
    };

    # The original approach granted `g:hermes:r-x` on the primary user's
    # home via ACL "so it can navigate to shared project directories".
    # That grant died silently in practice: any later `chmod` on an ACL'd
    # directory rewrites the ACL *mask*, which disables every named entry
    # while `getfacl` still shows the grant (observed live: `mask::---`).
    # Worse, setfacl's mask recalculation would re-enable `group::r-x` for
    # ALL members of `users`, not just hermes. Replaced by the read-only
    # bind mount (projectsDir). This oneshot converges the stale grant
    # away; it is a no-op once removed. Runs as root via the ExecStartPre
    # `+` prefix (cannot be expressed via tmpfiles).
    aclRevokeScript = pkgs.writeShellApplication {
      name = "hermes-acl-revoke";
      runtimeInputs = [
        pkgs.acl
        pkgs.coreutils
        pkgs.getent
        pkgs.gnugrep
      ];
      text = ''
        primaryHome=$(getent passwd ${config.users.primaryUser} 2>/dev/null | cut -d: -f6)
        [ -n "$primaryHome" ] && [ -d "$primaryHome" ] || exit 0
        if getfacl -p "$primaryHome" 2>/dev/null | grep -q "^group:${cfg.group}:"; then
          setfacl -x "g:${cfg.group}" "$primaryHome"
          echo "hermes-acl-revoke: removed stale g:${cfg.group} ACL from $primaryHome"
        fi
      '';
    };

    # Delivered into the writable workspace with a version marker on line
    # 1 (NOT tmpfiles `f`, which would clobber agent edits every boot):
    # the agent gets its operating rules for the projects mirror without
    # discovering them by failing. Install semantics: missing → install;
    # older marker → deliberate upgrade (agent edits to the OLD version
    # are replaced); same/newer marker or agent-rewritten header → leave
    # untouched, so agent edits survive deploys within a version.
    workspaceDocVersion = "2";
    # Byte-exact copy of the PRE-marker doc (delivered 2026-08-20 by the
    # old once-only installer). A marker-less workspace AGENTS.md that
    # still equals this is OUR unmodified v1 — upgrade it to the current
    # version. A marker-less file that differs was agent-edited — leave
    # it alone (their edits always win).
    workspaceAgentsDocV1 = pkgs.writeText "hermes-workspace-AGENTS-v1.md" ''
      # Hermes Workspace Guide

      - `./projects/` is a READ-ONLY live mirror of the primary user's
        checkouts on the host. The kernel blocks every write — `touch`,
        `git commit`, formatters: all EROFS. Do not fight it.
      - To work on code, CLONE first: `git clone ./projects/<repo> ./<repo>`
        and work inside the clone. The mirror is a reference, never a
        workspace.
      - `git` works read-only directly on `./projects/...` (dubious-ownership
        is allow-listed via GIT_CONFIG_GLOBAL). In YOUR clones set identity
        per-repo (`git config user.name …`, `user.email …`) — the global
        config is a read-only system file, `--global` writes will fail.
      - Writes outside /home/hermes are hard-blocked
        (HERMES_WRITE_SAFE_ROOT); /tmp in your sessions is private and
        ephemeral.
      - Private (0700) directories inside ./projects stay unreadable to
        you — intentional, do not report it as a bug.
      - Disk is finite: remove clones you no longer need.
    '';
    workspaceAgentsDoc = pkgs.writeText "hermes-workspace-AGENTS.md" ''
      <!-- systemnix-workspace-doc: v${workspaceDocVersion} -->
      # Hermes Workspace Guide

      - `./projects/` is a READ-ONLY live mirror of the primary user's
        checkouts on the host. The kernel blocks every write — `touch`,
        `git commit`, formatters: all EROFS. Do not fight it.
      - To work on code, CLONE first: `git clone ./projects/<repo> ./<repo>`
        and work inside the clone. The mirror is a reference, never a
        workspace.
      - `git` works read-only directly on `./projects/...` (dubious-ownership
        is allow-listed via GIT_CONFIG_GLOBAL). In YOUR clones set identity
        per-repo (`git config user.name …`, `user.email …`) — the global
        config is a read-only system file, `--global` writes will fail.
      - Writes outside /home/hermes are hard-blocked
        (HERMES_WRITE_SAFE_ROOT) — including /tmp for the write_file/patch
        tools. Use a scratch dir INSIDE the workspace (e.g. `./scratch/`)
        for throwaway files; do not probe /tmp paths.
      - Cloning PRIVATE LarsArtmann repos over HTTPS works — a read-only
        token is wired via the git credential helper. Never paste or store
        tokens yourself. You can never push: the token is read-only by
        permanent policy.
      - Private (0700) directories inside ./projects stay unreadable to
        you — intentional, do not report it as a bug.
      - Disk is finite: remove clones you no longer need.
    '';

    workspaceDocInstall = pkgs.writeShellApplication {
      name = "hermes-workspace-doc";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.diffutils
        pkgs.gnused
      ];
      text = ''
        DOC="${cfg.stateDir}/workspace/AGENTS.md"
        CUR_V=${workspaceDocVersion}
        doc_v=$(sed -n '1s/^<!-- systemnix-workspace-doc: v\([0-9][0-9]*\) -->$/\1/p' "$DOC" 2>/dev/null || true)
        if [ ! -f "$DOC" ]; then
          install -m 0644 ${workspaceAgentsDoc} "$DOC"
          echo "hermes-workspace: installed AGENTS.md (v$CUR_V)"
        elif [ -z "$doc_v" ]; then
          if cmp -s "$DOC" ${workspaceAgentsDocV1}; then
            install -m 0644 ${workspaceAgentsDoc} "$DOC"
            echo "hermes-workspace: upgraded marker-less AGENTS.md (was unmodified v1) -> v$CUR_V"
          else
            echo "hermes-workspace: AGENTS.md present (agent-rewritten header, untouched)"
          fi
        elif [ "$doc_v" -lt "$CUR_V" ]; then
          install -m 0644 ${workspaceAgentsDoc} "$DOC"
          echo "hermes-workspace: upgraded AGENTS.md v$doc_v -> v$CUR_V"
        else
          echo "hermes-workspace: AGENTS.md present (v$doc_v, agent edits preserved)"
        fi
      '';
    };

    # git credential helper (T14): answers GitHub HTTPS auth from the
    # HERMES_GITHUB_READ_TOKEN unit env var (sops-rendered). Read-only by
    # construction (fine-grained PAT, Contents: Read-only). Emits NO
    # credential until the token is real, so the placeholder value that
    # ships until the user pastes one is completely inert — public-repo
    # clones keep working anonymously. store/erase are no-ops: the token
    # is never persisted anywhere git could leak it back out.
    hermesGitCredential = pkgs.writeShellApplication {
      name = "hermes-git-credential";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        op="''${1:-}"
        [ "$op" = "get" ] || exit 0
        host=""
        while IFS= read -r line; do
          [ -z "$line" ] && break
          case "$line" in
            host=github.com) host=github.com ;;
          esac
        done
        [ "$host" = "github.com" ] || exit 1
        token="''${HERMES_GITHUB_READ_TOKEN:-}"
        case "$token" in
          github_pat_*|ghp_*|gho_*) ;;
          *) exit 1 ;;
        esac
        echo "username=hermes-read-token"
        echo "password=$token"
      '';
    };

    # Repos on the read-only projects bind are owned by the primary user
    # while the gateway runs as hermes; git >= 2.35.2 refuses ALL
    # operations on such repos ("detected dubious ownership") unless the
    # repo root is allow-listed in a PROTECTED config scope (system/global
    # only, never repo-local — GIT_CONFIG_GLOBAL counts as global).
    # Entries: the mount root itself (exact) plus <root>/* (covers every
    # repo beneath it at any depth, per `git help config` safe.directory).
    # The store path is read-only, so the agent cannot amend it; identity
    # for commits in clones must be set repo-locally (documented in the
    # workspace AGENTS.md). The credential section wires private-repo
    # clones (T14) — inert while the token is a placeholder.
    hermesGitConfig = pkgs.writeText "hermes-gitconfig" ''
      [safe]
      	directory = ${cfg.stateDir}/workspace/projects
      	directory = ${cfg.stateDir}/workspace/projects/*
      [credential "https://github.com"]
      	helper = ${lib.getExe hermesGitCredential}
    '';

    # Auth canary (T14.4): proves the read-only token can actually read
    # a private repo (git ls-remote = one authenticated GET, no clone).
    # Skips cleanly while the token is still the placeholder, so the
    # scaffolding ships inert and goes live the moment the user pastes a
    # real PAT. Runs at boot AND via deploy.sh restart — an expired or
    # revoked token surfaces here within one boot cycle, not at the
    # agent's first failed clone.
    githubVerifyScript = pkgs.writeShellApplication {
      name = "hermes-github-verify";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.git
      ];
      text = ''
        token="''${HERMES_GITHUB_READ_TOKEN:-}"
        case "$token" in
          github_pat_*|ghp_*|gho_*) ;;
          *)
            echo "hermes-github-verify: read token not set (placeholder) — skipping private-repo auth canary"
            exit 0
            ;;
        esac
        if git ls-remote --exit-code "${cfg.githubPrivateVerifyUrl}" HEAD >/dev/null 2>&1; then
          echo "hermes-github-verify: private-repo read auth OK (${cfg.githubPrivateVerifyUrl})"
        else
          echo "hermes-github-verify: FAILED private-repo read auth (${cfg.githubPrivateVerifyUrl}) — token expired/revoked, wrong repo scope, or PAT not granted this repo" >&2
          exit 1
        fi
      '';
    };

    migrateScript = pkgs.writeShellApplication {
      name = "hermes-migrate-state";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.sqlite
        pkgs.rsync
      ];
      text = ''
        NEW="${cfg.stateDir}"

        if command -v chattr &>/dev/null; then
          chattr +C "$NEW" 2>/dev/null || true
        fi

        DB="$NEW/state.db"
        if [ -f "$DB" ]; then
          INTEGRITY=$(sqlite3 "$DB" "PRAGMA integrity_check;" 2>&1 || echo "error")
          if [ "$INTEGRITY" != "ok" ]; then
            BACKUP="$DB.malformed-$(date +%Y%m%d-%H%M%S)"
            echo "hermes-migrate: SQLite database malformed, backing up to $BACKUP"
            mv "$DB" "$BACKUP"
            rm -f "$DB-wal" "$DB-shm"
          else
            sqlite3 "$DB" "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;" 2>/dev/null || true
          fi
        fi

        if [ -f "$NEW/state.db" ] && [ "$(stat -c%s "$NEW/state.db" 2>/dev/null)" -gt 1048576 ]; then
          echo "hermes-migrate: $NEW has existing state ($(stat -c%s "$NEW/state.db") bytes), skipping migration"
          exit 0
        fi

        for OLD in ${lib.concatStringsSep " " (map (p: "\"${p}\"") oldStateDirs)}; do
          if [ -d "$OLD" ] && [ "$(ls -A "$OLD" 2>/dev/null)" ]; then
            echo "hermes-migrate: migrating state from $OLD to $NEW"
            mkdir -p "$NEW"
            rsync -a --chown=${cfg.user}:${cfg.group} "$OLD/" "$NEW/"
            echo "hermes-migrate: migration complete (from $OLD)"
            exit 0
          fi
        done

        echo "hermes-migrate: no old state found, skipping migration"
      '';
    };
  in {
    options.services.hermes = {
      enable = lib.mkEnableOption "Hermes AI Agent Gateway";

      inherit
        (serviceTypes.systemdServiceIdentity {
          defaultUser = "hermes";
          defaultStateDir = "/home/hermes";
        })
        user
        group
        stateDir
        ;

      restartSec = serviceTypes.restartDelay "5";

      timeoutStopSec = serviceTypes.stopTimeout "120";

      # Host directory exposed to the agent READ-ONLY inside its sandbox at
      # <stateDir>/workspace/projects. null = no bind. Read-only by design:
      # the agent reads the real code and makes changes by cloning into its
      # writable workspace (upstream's recommended worktree isolation), so a
      # compromised or prompt-injected agent can never modify the primary
      # user's checkouts — enforced by the kernel (MS_RDONLY bind mount),
      # not by hermes' own write guards.
      projectsDir = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/home/lars/projects";
        description = ''
          Host projects directory bind-mounted read-only into the hermes
          sandbox at <stateDir>/workspace/projects. Set by the host, never
          writable by the agent. Requires only world-read permissions on
          the mounted tree; 0700-private subdirectories inside stay
          unreadable to the agent.
        '';
      };

      githubPrivateVerifyUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://github.com/LarsArtmann/go-cqrs-lite";
        description = ''
          Private repository probed by hermes-github-verify to prove the
          read-only GitHub token (HERMES_GITHUB_READ_TOKEN, sops-rendered)
          can actually read private repos. Must be a repo the token is
          scoped to. Read-only by permanent policy (user decision
          2026-08-20): hermes never gets push credentials.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      users.groups.${cfg.group} = {};

      users.users.${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group;
        # `render` = GPU access for TTS/voice extras. The former `users`
        # membership existed only for the (mask-fragile) home-ACL traversal
        # grant; projects access now rides the read-only bind mount, which
        # only needs world-read perms on the mounted tree.
        extraGroups = ["render"];
        home = cfg.stateDir;
        createHome = true;
        description = "Hermes AI Agent Gateway service user";
      };

      environment.systemPackages = [hermesPkg];

      # Directory creation and ownership handled declaratively via tmpfiles.
      # The stale-ACL revoke and recursive file permission fix-up run via
      # ExecStartPre (aclRevokeScript + fixPermissionsScript) — they cannot
      # be expressed as tmpfiles rules.
      systemd.tmpfiles.rules =
        map (path: mkStateDir path "2770" cfg.user cfg.group) (
          [
            cfg.stateDir
            "${cfg.stateDir}/sessions"
            "${cfg.stateDir}/skills"
            "${cfg.stateDir}/memories"
            "${cfg.stateDir}/cron"
            "${cfg.stateDir}/cache"
            "${cfg.stateDir}/logs"
            "${cfg.stateDir}/logs/curator"
            "${cfg.stateDir}/workspace"
          ]
          ++ lib.optionals (cfg.projectsDir != null) [
            # Mount point for the read-only projects bind
            # (BindReadOnlyPaths below). Pre-created so the bind cannot
            # race a missing destination; the mount overlays it.
            "${cfg.stateDir}/workspace/projects"
          ]
        )
        ++ [
          "f ${cfg.stateDir}/.managed 0644 ${cfg.user} ${cfg.group} -"
        ];

      systemd.services.hermes = {
        description = "Hermes Agent Gateway - Messaging Platform Integration";
        wantedBy = ["multi-user.target"];
        after = [
          "network-online.target"
          "sops-nix.service"
          "dnsblockd.service"
        ];
        wants = [
          "network-online.target"
          "sops-nix.service"
          "dnsblockd.service"
        ];
        inherit onFailure;
        startLimitIntervalSec = 600;
        startLimitBurst = 5;

        unitConfig = lib.mkIf (cfg.projectsDir != null) {
          # Order against (and require) the mount backing projectsDir — a
          # no-op while it lives on the root fs, but fails loudly instead of
          # binding a dead path if it ever moves onto removable storage.
          RequiresMountsFor = [(toString cfg.projectsDir)];
        };

        path = [
          hermesPkg
          pkgs.bash
          pkgs.binutils
          pkgs.coreutils
          pkgs.git
        ];

        serviceConfig = lib.mkMerge [
          {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            ExecStartPre = [
              "+${lib.getExe aclRevokeScript}"
              "+${lib.getExe fixPermissionsScript}"
              "+${lib.getExe migrateScript}"
              "${lib.getExe mergeEnvScript}"
              "${lib.getExe lspBinHealScript}"
            ];
            ExecStart = "${lib.getExe' hermesPkg "hermes"} gateway run --replace";
            WorkingDirectory = cfg.stateDir;
            Environment =
              [
                "HOME=${cfg.stateDir}"
                "HERMES_HOME=${cfg.stateDir}"
                "HERMES_MANAGED=true"
                "GATEWAY_ALLOW_ALL_USERS=true"
                "LD_LIBRARY_PATH=${pkgs.libopus}/lib"
                # OTLP tracing — Python SDK expects full URL with scheme.
                # Noop until upstream Hermes adds opentelemetry-sdk instrumentation.
                "OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:${toString ports.signoz-otlp-http}"
              ]
              ++ lib.optionals (cfg.projectsDir != null) [
                # Land the agent's terminal in the writable workspace, beside
                # the read-only ./projects bind (see BindReadOnlyPaths). An
                # explicit terminal.cwd in runtime config.yaml (settings UI)
                # still overrides this — intended precedence: explicit user
                # choice beats the system default. Startup prints a cosmetic
                # "TERMINAL_CWD found in .env" deprecation warning; it is
                # expected and harmless (we never write .env).
                "TERMINAL_CWD=${cfg.stateDir}/workspace"
                # Upstream write_file/patch sandbox: targets outside the
                # hermes state root are hard-blocked BEFORE touching disk.
                # The RO bind would EROFS anyway; this yields a clean
                # agent-facing denial. stateDir covers HERMES_HOME, so cron
                # jobs, skills, and profile state stay writable.
                "HERMES_WRITE_SAFE_ROOT=${cfg.stateDir}"
                # Un-breaks git on the RO bind (foreign-owned repos): see
                # hermesGitConfig above. Read-only store file, so it also
                # SHADOWS any $HOME/.gitconfig — identity etc. must be
                # repo-local in clones.
                "GIT_CONFIG_GLOBAL=${hermesGitConfig}"
              ];
            EnvironmentFile = [sopsEnvPath];
            RestartForceExitStatus = 75;
            KillMode = "mixed";
            KillSignal = "SIGTERM";
            TimeoutStopSec = cfg.timeoutStopSec;
            # State migration (535 MB) + ACL revoke + permission fix can exceed
            # systemd's default 90s during system switches. 3 min covers
            # worst observed case (~96s on cold I/O).
            TimeoutStartSec = "3min";
            ExecReload = "/bin/kill -USR1 $MAINPID";
            StandardOutput = "journal";
            StandardError = "journal";
            UMask = "0026";
          }
          (lib.optionalAttrs (cfg.projectsDir != null) {
            # Read-only bind of the primary user's projects into the agent
            # sandbox. Kernel-enforced (MS_RDONLY): even a compromised agent
            # cannot write. Set up by PID 1 as root, so it does NOT depend
            # on traversing the 0700 primary home — unlike the old ACL
            # grant, which any later `chmod` on the home dir silently
            # masked away. Unprefixed source: if projectsDir disappears the
            # unit fails loudly instead of running with a missing bind.
            BindReadOnlyPaths = [
              "${toString cfg.projectsDir}:${cfg.stateDir}/workspace/projects"
            ];
            # Deliver the workspace AGENTS.md once (runs as the service
            # user — the workspace dir is hermes-owned).
            ExecStartPre = ["${lib.getExe workspaceDocInstall}"];
          })
          (serviceDefaults {RestartSec = cfg.restartSec;})
          (harden {
            MemoryMax = "24G"; # PyTorch + ROCm + HIP libraries require significant GPU memory mapping
            CPUQuota = "400%"; # PyTorch data preprocessing + inference can spike multi-core
            ProtectHome = false;
            ReadWritePaths = [cfg.stateDir];
          })
        ];
      };

      # Auth canary for the read-only GitHub token (T14): boot + deploy
      # time git ls-remote against one private repo. Sits beside the
      # gateway unit, shares its sops env, skips inert while the token is
      # a placeholder. DNS-gated (github.com) so a boot racing dnsblockd
      # skips cleanly instead of failing.
      systemd.services.hermes-github-verify = let
        dnsGate = mkDnsGate {
          inherit pkgs;
          serviceName = "hermes-github-verify";
          hostname = "github.com";
        };
      in
        lib.mkIf (cfg.projectsDir != null) {
          description = "Hermes: verify read-only GitHub token can read private repos";
          wantedBy = ["multi-user.target"];
          inherit (dnsGate) after wants;
          inherit onFailure;
          startLimitIntervalSec = 300;
          startLimitBurst = 5;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = cfg.user;
              Group = cfg.group;
              Environment = [
                "HOME=${cfg.stateDir}"
                "GIT_CONFIG_GLOBAL=${hermesGitConfig}"
              ];
              EnvironmentFile = [sopsEnvPath];
              ExecStartPre = dnsGate.serviceConfig.ExecStartPre;
              ExecStart = lib.getExe githubVerifyScript;
              # DNS gate alone can wait 2min; give the probe headroom.
              TimeoutStartSec = "5min";
            }
            (serviceOneshotDefaults {})
            (harden {MemoryMax = "512M";})
          ];
        };
    };
  };
}
