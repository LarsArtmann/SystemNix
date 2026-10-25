# Runbook: docs/services/hermes.md
# Hermes AI Agent Gateway: Discord bot, cron scheduler, messaging
# Projects access: services.hermes.projectsDir bind-mounts the primary
# user's projects tree READ-ONLY into the agent sandbox — see the option
# and the BindReadOnlyPaths wiring below for the rationale.
{ inputs, ... }: {
  flake.nixosModules.hermes =
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
        mkStateDir
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        serviceTypes
        ports
        mkDnsGate
        ioTier
        ;
      cfg = config.services.hermes;
      # Hermes v0.21.0 dispatches restart-safe cron workers through
      # `systemd-run --user --scope` (upstream tools/process_registry.py,
      # fail-closed by design: falling back would let a gateway restart
      # kill in-flight jobs). A system service needs three pieces of
      # wiring for that bus topology: a running user manager (linger),
      # XDG_RUNTIME_DIR pointing at its bus socket, and an FHS /bin/true
      # — the scope availability probe execs /bin/true literally and
      # NixOS has no /bin (missing it kept every cron job failing with
      # "Restart-safe cron worker dispatch failed" since v0.21.0,
      # 2026-09-05..09-11). Pinned to the live uid (975) so the runtime
      # dir path is computable at eval time and the existing home
      # ownership is untouched; a conflicting uid pin on another host
      # fails the eval loudly instead of silently breaking the path.
      hermesUid = 975;
      hermesPkg =
        let
          # Upstream packaging needs no hash patching (true since v2026.7.20
          # through v0.21.4 / 33a30fdd — the uv2nix machinery now lives in
          # nix/python.nix, fetcherVersion is gone). Extras dropped upstream
          # must stop being named here: `hindsight` (73c598e319, 2026-09-23)
          # and `honcho` (7e53b3ef, 2026-10-02 — "remove bundled honcho
          # provider; install from the plugin catalog") are both resolved by
          # the catalog plugin installer via their plugin.yaml at first use;
          # naming a removed extra fails every eval with "Extra/group name
          # '<extra>' does not match either extra or dependency group".
          baseOverlay = inputs.hermes-agent.overlays.default;
          # registration_lifecycle ships upstream: v0.20.x carried it in a
          # static [tool.setuptools] py-modules list; since v0.21.0 setup.py's
          # _root_py_modules() derives all root-level modules from the source
          # tree at build time (no static list to drift). The former
          # downstream extraction + PYTHONPATH-suffix patch was a second
          # source of truth and was deleted 2026-08-21.
          patchedOverlay =
            final: prev:
            let
              base = baseOverlay final prev;
            in
            base
            // {
              hermes-agent = base.hermes-agent.override {
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
                  "messaging"
                  "matrix"
                  "modal"
                  "parallel-web"
                  "tts-premium"
                  "voice"
                ];
              };
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
        runtimeInputs = [ pkgs.gnused ];
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
          # OpenSSH refuses group-writable files under ~/.ssh ("Bad owner or
          # permissions on /home/hermes/.ssh/config", live 2026-08-21: the
          # exec-preserving walk below makes agent-created ssh config 0660,
          # breaking the agent's own git-over-ssh usage). Converge ~/.ssh to
          # owner-only on EVERY run — also on the fast-path exit below — so
          # the agent's ssh keeps working regardless of walk drift.
          converge_ssh() {
            ssh_dir="${cfg.stateDir}/.ssh"
            [ -d "$ssh_dir" ] || return 0
            find "$ssh_dir" -xdev -type f -exec chmod u=rwX,g=,o= {} + 2>/dev/null || true
            # numeric 0700 + explicit `g-s`: on this kernel chmod preserves
            # the dir setgid bit (2770 from the dir-walk → "2700") for both
            # numeric and u/g/o symbolic forms; only an explicit s-symbol
            # (or root) clears it
            chmod 0700 "$ssh_dir" 2>/dev/null || true
            chmod g-s "$ssh_dir" 2>/dev/null || true
          }

          # Fast path must flag exactly what the heal's chown walk repairs —
          # ownership drift on ANY entry under stateDir, not just the root
          # (cv-state-perms lesson 2026-09-20: a root-only probe goes
          # phantom-green against child drift the heal exists to fix). The
          # walk mirrors the heal's chown branch (same -xdev, same
          # workspace/projects prune — .ssh is deliberately INCLUDED: the
          # chown walk covers it too). Mode drift on files is NOT probed:
          # the heal's exec-preserving X semantics cannot be expressed as a
          # find predicate; ownership is the axis that breaks the service
          # user. Cost: one metadata walk per start (the heal branch already
          # pays three on drift).
          tree_converged() {
            stray=$(find ${cfg.stateDir} -xdev -path '${cfg.stateDir}/workspace/projects' -prune -o \( ! -user ${cfg.user} -o ! -group ${cfg.group} \) -print -quit 2>/dev/null) # dead-guard-ok: fn runs in if-tested context — errexit suppressed body-wide
            [ -z "$stray" ] \
              && [ "$(stat -c '%U:%G' ${cfg.stateDir} 2>/dev/null)" = "${cfg.user}:${cfg.group}" ] \
              && [ "$(stat -c '%a' ${cfg.stateDir} 2>/dev/null)" = "2770" ]
          }

          if tree_converged; then
            converge_ssh
            # Completion markers (both paths): the hermes-perms-heal unit is
            # async post-start, so tests and runbooks wait on THESE lines
            # instead of unit state (a finished oneshot reads inactive).
            echo "hermes-perms: converged (fast path)"
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
          # ~/.ssh is pruned: group-write there makes OpenSSH reject the
          # config (converge_ssh handles it owner-only instead).
          find ${cfg.stateDir} -xdev \( -path '${cfg.stateDir}/workspace/projects' -o -path '${cfg.stateDir}/.ssh' \) -prune -o -type f -exec chmod u=rwX,g=rwX,o= {} + 2>/dev/null || true

          converge_ssh
          echo "hermes-perms: converged (heal path)"
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
        runtimeInputs = [ pkgs.coreutils ];
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
          primaryHome=$(getent passwd ${config.users.primaryUser} 2>/dev/null | cut -d: -f6) || true || true
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
      workspaceDocVersion = "3";
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
        - Cloning PRIVATE LarsArtmann GitHub repos over HTTPS works — a
          READ-ONLY token is wired via the git credential helper. Never
          paste or store tokens yourself. github.com stays read-only by
          permanent policy: you can never push there.
        - Forgejo WRITE access (owner decision 2026-09-23): to publish
          work, add a remote and push —
          `git remote add forgejo https://${forgejoHost}/lars/<repo>.git`
          then `git push forgejo <branch>`. Auth is automatic (credential
          helper, account hermes-agent). NEVER delete branches or tags,
          force-push, or rewrite pushed history. Repo deletion/transfer is
          impossible for your account; mirror repos reject pushes by design.
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

      # Forgejo host for credential + workspace-doc wiring. Only wired into
      # the gitconfig when forgejo is enabled on the host (standalone hermes
      # consumers / the VM test have no forgejo and stay GitHub-only).
      forgejoEnabled = config.services.forgejo.enable or false;
      forgejoHost = "forgejo." + toString (config.networking.domain or "invalid");

      # git credential helper (T14): answers GitHub HTTPS auth from the
      # HERMES_GITHUB_READ_TOKEN unit env var (sops-rendered, READ-ONLY —
      # permanent policy, user decision 2026-08-20). Since 2026-09-23 it
      # ALSO answers the forgejo host with the hermes-agent WRITE token
      # (owner decision 2026-09-23) that forgejo-hermes-token delivers to
      # /run/hermes-forgejo-token (0400 hermes:hermes) — a missing file or
      # malformed token = exit 1 = no credential (git falls back to
      # anonymous; public-repo clones keep working). Emits NO credential
      # until the token is real, so placeholder values are completely
      # inert. store/erase are no-ops: tokens are never persisted anywhere
      # git could leak them back out.
      hermesGitCredential = pkgs.writeShellApplication {
        name = "hermes-git-credential";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
        text = ''
          op="''${1:-}"
          [ "$op" = "get" ] || exit 0
          host=""
          while IFS= read -r line; do
            [ -z "$line" ] && break
            case "$line" in
              host=*) host="''${line#host=}" ;;
            esac
          done
          case "$host" in
            github.com)
              token="''${HERMES_GITHUB_READ_TOKEN:-}"
              case "$token" in
                github_pat_*|ghp_*|gho_*) ;;
                *) exit 1 ;;
              esac
              echo "username=hermes-read-token"
              echo "password=$token"
              ;;
            ${forgejoHost})
              [ -r /run/hermes-forgejo-token ] || exit 1
              ftoken=$(cat /run/hermes-forgejo-token)
              printf '%s' "$ftoken" | grep -qE '^[0-9a-f]{40}$' || exit 1
              echo "username=hermes-agent"
              echo "password=$ftoken"
              ;;
            *) exit 1 ;;
          esac
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
      hermesGitConfig = pkgs.writeText "hermes-gitconfig" (
        ''
          [safe]
          	directory = ${cfg.stateDir}/workspace/projects
          	directory = ${cfg.stateDir}/workspace/projects/*
          [credential "https://github.com"]
          	helper = ${lib.getExe hermesGitCredential}
        ''
        + lib.optionalString forgejoEnabled ''
          [credential "https://${forgejoHost}"]
          	helper = ${lib.getExe hermesGitCredential}
        ''
      );

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
          MARKER="$DB.integrity-pending"
          # Start-path budget for the integrity census (env seam for tests +
          # ops). The census runs ONLY on the unclean-shutdown signal (a
          # PRESENT -wal) or when a previous boot deferred it (marker) — and
          # those are exactly the storm boots where the 1.4 GB walk does not
          # fit any start budget (boot -1 2026-10-18: two FULL 3min
          # TimeoutStartSec timeouts, SIGKILLed mid-walk, gateway down ~8min
          # until a third retry's walk finished in 103s). So the start-path
          # attempt is now BOUNDED: on timeout it drops a marker, starts the
          # gateway anyway (sqlite recovers the wal on open; the census is a
          # corruption census, not a recovery step), and hermes-db-health
          # converges the verdict post-start.
          CHECK_BUDGET="''${HERMES_DB_CHECK_BUDGET:-60s}"
          rc=0
          # Integrity check ONLY after an unclean shutdown: with
          # journal_mode=WAL, sqlite deletes state.db-wal when the last
          # connection closes cleanly, so a PRESENT -wal file is the
          # unclean-shutdown signal (freeze/crash class). The unconditional
          # full-scan integrity_check on the 1.4 GB db was half of the
          # ~96s boot-IO-storm ExecStartPre cost that gated
          # multi-user.target (2026-10-06 boot research) — and a no-op after
          # every clean stop. journal_mode is persistent in the db header,
          # so the clean path needs no pragma re-assert either.
          if [ -f "$DB" ] && { [ -f "$DB-wal" ] || [ -f "$MARKER" ]; }; then
            INTEGRITY=$(timeout "$CHECK_BUDGET" sqlite3 "$DB" "PRAGMA integrity_check;" 2>&1) || rc=$?
            if [ "$rc" -eq 124 ]; then
              touch "$MARKER"
              echo "hermes-migrate: integrity census exceeded ''${CHECK_BUDGET} under boot IO — deferred to hermes-db-health (marker: $MARKER); starting without the verdict"
            elif [ "$INTEGRITY" != "ok" ]; then
              BACKUP="$DB.malformed-$(date +%Y%m%d-%H%M%S)"
              echo "hermes-migrate: SQLite database malformed (unclean shutdown), backing up to $BACKUP"
              mv "$DB" "$BACKUP"
              rm -f "$DB-wal" "$DB-shm" "$MARKER"
            else
              sqlite3 "$DB" "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;" 2>/dev/null || true
              rm -f "$MARKER"
            fi
          elif [ ! -f "$DB" ] && [ -f "$MARKER" ]; then
            rm -f "$MARKER"
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

      # Converges the integrity census that hermes-migrate-state DEFERRED
      # (marker: state.db.integrity-pending) once the boot IO storm has
      # drained. Runs post-start on every hermes start (boot + deploy
      # restarts) — off the boot critical path, hermes-perms-heal wiring
      # shape. The gateway is already up and serving when this runs: a
      # clean census just clears the marker; a malformed one moves the db
      # aside and restarts the gateway onto a fresh state (the same
      # fail-closed-to-fresh contract the start-path census always had —
      # serving on an unverified db for the storm minutes beats a gateway
      # start-limit-dead for the whole boot).
      hermesDbHealthScript = pkgs.writeShellApplication {
        name = "hermes-db-health";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.gnugrep
          pkgs.sqlite
          pkgs.systemd
        ];
        text = ''
          NEW="${cfg.stateDir}"
          DB="$NEW/state.db"
          MARKER="$DB.integrity-pending"
          PSI_FILE="''${HERMES_DB_HEALTH_PSI_FILE:-/proc/pressure/io}"
          PSI_LIMIT="''${HERMES_DB_HEALTH_PSI_LIMIT:-20}"
          # Wait cap before the census runs regardless: 12 × 30s = 6 min,
          # inside the unit's own 15min start budget (a cold 1.4 GB census
          # takes ~2-5 min once calm).
          WAIT_CYCLES="''${HERMES_DB_HEALTH_WAIT_CYCLES:-12}"
          POLL_SEC="''${HERMES_DB_HEALTH_POLL_SEC:-30}"

          if [ ! -f "$MARKER" ]; then
            echo "hermes-db-health: no pending integrity census — nothing to do"
            exit 0
          fi
          if [ ! -f "$DB" ]; then
            echo "hermes-db-health: $DB gone (fresh state) — clearing stale marker"
            rm -f "$MARKER"
            exit 0
          fi

          n=0
          while [ "$n" -lt "$WAIT_CYCLES" ]; do
            avg10=$(grep '^some ' "$PSI_FILE" 2>/dev/null | grep -o 'avg10=[0-9.]*' | cut -d= -f2 || echo 0)
            if awk -v a="''${avg10:-0}" -v l="$PSI_LIMIT" 'BEGIN { exit !(a < l) }'; then
              break
            fi
            n=$((n + 1))
            sleep "$POLL_SEC"
          done
          if [ "$n" -ge "$WAIT_CYCLES" ]; then
            # Maintenance-entry gate (2026-10-25, stability.md row 38 /
            # freeze-33 T+5 finding: this census ran INTO a 60%+ recovery
            # storm when the 6-min cap expired — freeze-6 rule (a) class).
            # The census is off the critical path (the gateway is already
            # serving; the marker persists), so a storm that outlasts the
            # wait budget DEFERS instead of running into it. exit 0:
            # deferral is a successful no-op, not a unit failure; the next
            # hermes start re-pulls this unit and retries.
            echo "hermes-db-health: io storm persisted for the full $WAIT_CYCLES-cycle budget — census deferred (marker kept; maintenance never enters a storm)"
            exit 0
          fi
          echo "hermes-db-health: running deferred integrity census on $DB (io calm after $n of $WAIT_CYCLES wait cycles)"

          INTEGRITY=$(sqlite3 "$DB" "PRAGMA integrity_check;" 2>&1) || true
          if [ "$INTEGRITY" = "ok" ]; then
            rm -f "$MARKER"
            echo "hermes-db-health: census converged ok — marker cleared"
          elif printf '%s' "$INTEGRITY" | grep -qi "database is locked"; then
            # Transient: the live gateway holds the db (WAL readers usually
            # coexist; a checkpoint window does not). Keep the marker — the
            # next hermes start re-pulls this unit and retries.
            echo "hermes-db-health: census hit a lock window — marker kept, retrying on next start"
            exit 1
          else
            # Anything ≠ ok is the malformed verdict (integrity_check
            # reports violations as rows with exit 0; sqlite-level errors
            # are corruption-class too) — the same fail-closed-to-fresh
            # contract the start-path census always had.
            BACKUP="$DB.malformed-$(date +%Y%m%d-%H%M%S)"
            echo "hermes-db-health: SQLite database malformed — backing up to $BACKUP and restarting hermes onto a fresh state"
            mv "$DB" "$BACKUP"
            rm -f "$DB-wal" "$DB-shm" "$MARKER"
            # A crash-looping gateway may have burned its start-limit budget
            # on the corrupt db — clear it so the restart is admitted.
            ${pkgs.systemd}/bin/systemctl reset-failed hermes.service 2>/dev/null || true
            ${pkgs.systemd}/bin/systemctl restart hermes.service
          fi
        '';
      };
    in
    {
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
            2026-08-20): hermes never gets GitHub push credentials.
            GitHub-scoped only — forgejo push access was granted separately
            (owner decision 2026-09-23, see hermes-git-credential).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        users.groups.${cfg.group} = { };

        users.users.${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
          # `render` = GPU access for TTS/voice extras. The former `users`
          # membership existed only for the (mask-fragile) home-ACL traversal
          # grant; projects access now rides the read-only bind mount, which
          # only needs world-read perms on the mounted tree.
          extraGroups = [ "render" ];
          home = cfg.stateDir;
          createHome = true;
          description = "Hermes AI Agent Gateway service user";
          uid = hermesUid;
          # Starts user@<uid>.service at boot so `systemd-run --user` (the
          # restart-safe cron dispatch, above) can reach the user bus.
          # users.manageLingering defaults true and only touches declared
          # users — imperatively-lingering users (lars) are unaffected.
          linger = true;
        };

        environment.systemPackages = [ hermesPkg ];

        # Directory creation and ownership handled declaratively via tmpfiles.
        # The stale-ACL revoke runs via ExecStartPre (aclRevokeScript — it
        # cannot be expressed as tmpfiles rules). The full-tree permission
        # fix-up moved to the post-start hermes-perms-heal unit (see below:
        # its metadata walk over the whole state tree cost ~96s of boot IO
        # storm while gating multi-user.target via this unit, 2026-10-06).
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
            # FHS compat for the systemd-run --user --scope availability
            # probe (execs /bin/true literally; NixOS only ships /bin/sh).
            "L+ /bin/true - - - - ${pkgs.coreutils}/bin/true"
          ];

        systemd.services.hermes = {
          description = "Hermes Agent Gateway - Messaging Platform Integration";
          wantedBy = [ "multi-user.target" ];
          after = [
            # Post-gate (application readiness, llama-chat owner-ruling
            # shape): the 2026-10-18 family audit caught hermes holding
            # multi-user for its FULL 3min TimeoutStartSec and then failing
            # (hermes-migrate-state sqlite walk, 1.6G read under post-boot
            # IO, boot -1) — the worst gate in the family. The migrate
            # start-budget problem is its own row; this only stops it
            # gating the boot.
            "multi-user.target"
            "network-online.target"
            "sops-nix.service"
            "dnsblockd.service"
            # The user manager must own its bus before the first
            # restart-safe cron dispatch probes it (probe failures are
            # cached 60s — ordering avoids the one-shot stale probe).
            "user@${toString hermesUid}.service"
          ];
          wants = [
            "network-online.target"
            "sops-nix.service"
            "dnsblockd.service"
            "user@${toString hermesUid}.service"
            # Pull the post-start perms heal on EVERY start (boot + every
            # deploy restart) — see hermes-perms-heal below for why the
            # walk no longer lives in ExecStartPre.
            "hermes-perms-heal.service"
            # Same cadence for the deferred integrity census (marker set by
            # the bounded ExecStartPre check on storm boots) — see
            # hermes-db-health below.
            "hermes-db-health.service"
          ];
          inherit onFailure;
          startLimitIntervalSec = 600;
          startLimitBurst = 5;

          unitConfig = {
            # Order against (and require) the mounts backing the unit's paths:
            # stateDir lives on the dedicated @home-hermes subvolume since
            # 2026-09-15 (declared in snapshots.nix) — a no-op on hosts where
            # it is a plain dir, but fails loudly instead of running against
            # a shadowed/empty home when the mount is missing (e.g. a deploy
            # that landed before scripts/migrate-hermes-subvol.sh prepare).
            # projectsDir backs the read-only bind — same loud-failure
            # guarantee if it ever moves onto removable storage.
            RequiresMountsFor = [
              (toString cfg.stateDir)
            ]
            ++ lib.optionals (cfg.projectsDir != null) [ (toString cfg.projectsDir) ];
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
                "+${lib.getExe migrateScript}"
                "${lib.getExe mergeEnvScript}"
                "${lib.getExe lspBinHealScript}"
              ];
              # -v (verbosity=1): stderr logs at INFO — without it the
              # gateway logs WARNING+ only and the "[Discord] Connected as"
              # on_ready line never reaches journald, leaving the post-deploy
              # Discord-connectivity smoke with no positive signal.
              ExecStart = "${lib.getExe' hermesPkg "hermes"} gateway run --replace -v";
              WorkingDirectory = cfg.stateDir;
              Environment = [
                "HOME=${cfg.stateDir}"
                "HERMES_HOME=${cfg.stateDir}"
                "HERMES_MANAGED=true"
                "GATEWAY_ALLOW_ALL_USERS=true"
                "LD_LIBRARY_PATH=${pkgs.libopus}/lib"
                # sd-bus refuses to GUESS the user bus socket: without this
                # the `systemd-run --user --scope` cron dispatch (and its
                # availability probe) fails "Failed to connect to user scope
                # bus ... not defined" even with the user manager running.
                "XDG_RUNTIME_DIR=/run/user/${toString hermesUid}"
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
              EnvironmentFile = [ sopsEnvPath ];
              RestartForceExitStatus = 75;
              # Upstream 0.21.x gateway exits 1 on a SIGTERM-initiated
              # shutdown ("so the service manager can revive the gateway"),
              # which marks every clean stop failed and exit-4s any
              # activation restarting the unit (2026-09-20: stc
              # test-activation aborted on hermes, profile bump skipped,
              # gateway left down). Revival paths are unaffected: exit 75
              # stays the explicit restart request (RestartForceExitStatus)
              # and serviceDefaults' Restart=always covers every other
              # exit; exit-1 crash visibility moves to the restart-churn
              # metric + journal.
              SuccessExitStatus = 1;
              KillMode = "mixed";
              KillSignal = "SIGTERM";
              TimeoutStopSec = cfg.timeoutStopSec;
              # Budget history: the 6min era existed for the full-tree perms
              # walk + unconditional integrity_check (2026-08-31 boot hit the
              # full 3min, 2026-10-06 boot -1 hit the full 6min and paid a
              # restart retry). Both scans left ExecStartPre 2026-10-06
              # (perms walk → hermes-perms-heal post-start; integrity check
              # → WAL-gated in the migrate script). The census is BOUNDED
              # since 2026-10-19 (boot -1 2026-10-18 burned the full 3min
              # TWICE on it): a storm-timeout defers to hermes-db-health
              # post-start instead of failing the unit, so 3min now absorbs
              # only genuinely-start-shaped work.
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
              ExecStartPre = [ "${lib.getExe workspaceDocInstall}" ];
            })
            (serviceDefaults { RestartSec = cfg.restartSec; })
            (harden {
              MemoryMax = "24G"; # PyTorch + ROCm + HIP libraries require significant GPU memory mapping
              CPUQuota = "400%"; # PyTorch data preprocessing + inference can spike multi-core
              ProtectHome = false;
              ReadWritePaths = [ cfg.stateDir ];
            })
          ];
        };

        # Post-start ownership convergence for the hermes state tree.
        # Moved OUT of hermes' ExecStartPre 2026-10-06: the probe walk
        # (full-tree find over stateDir on the QLC root) cost ~96s under the
        # boot IO storm on a CONVERGED tree — with Type=simple that entire
        # cost gated multi-user.target (the login screen waited on it), and
        # the 2026-10-06 boot -1 first attempt even hit the 6min start
        # timeout, paid a restart cooldown, and finished its ExecStartPre at
        # ~534s. Probe+heal move here TOGETHER, unchanged — the cv-state-perms
        # lesson (2026-09-20) requires the probe to flag exactly what the
        # heal repairs; splitting them would re-create the phantom-green
        # class. Wiring: hermes.service Wants= this unit, this unit is
        # After=hermes.service — so it still runs on every boot AND every
        # deploy restart (same convergence cadence), but only AFTER the
        # gateway process forked, i.e. off the boot critical path. Failure
        # here does not fail hermes (Wants, not Requires) — it alerts via
        # OnFailure and retries on the next hermes start. The script logs a
        # completion line per run (fast/heal path); the VM test waits on
        # those because a finished oneshot reads inactive, not active.
        systemd.services.hermes-perms-heal = {
          description = "Hermes state-tree ownership convergence (post-start)";
          after = [ "hermes.service" ];
          inherit onFailure;
          startLimitBurst = 3;
          startLimitIntervalSec = 3600;
          unitConfig = {
            # Same loud-failure mount gate as hermes.service: never converge
            # against a shadow dir if the @home-hermes mount is missing.
            RequiresMountsFor = [ (toString cfg.stateDir) ];
          };
          serviceConfig = lib.mkMerge [
            (serviceOneshotDefaults { })
            (harden {
              # chown on foreign-owned entries (CAP_CHOWN), chmod on files
              # owned by others (CAP_FOWNER), traversal of the 2770 state
              # dirs (CAP_DAC_OVERRIDE) — same capability needs as the old
              # root-prefixed ExecStartPre (+fixPermissionsScript).
              CapabilityBoundingSet = "CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER";
              ProtectHome = false;
              ReadWritePaths = [ cfg.stateDir ];
            })
            {
              Type = "oneshot";
              User = "root";
              ExecStart = lib.getExe fixPermissionsScript;
              # The walk is IO-bound metadata traffic by design — ioTier.build
              # (BE/7 + Nice 10) keeps it behind the gateway warmup, desktop
              # login, and every foreground workload, without the starvation
              # tail of the idle class.
              TimeoutStartSec = "10min";
            }
            ioTier.build
          ];
        };

        # Converges the storm-deferred sqlite integrity census (marker left
        # by the bounded ExecStartPre attempt in hermes-migrate-state).
        # Wiring mirrors hermes-perms-heal: Wanted by hermes.service, After=
        # it — runs on every boot AND deploy restart, off the boot critical
        # path; failure does not fail hermes (Wants, not Requires). The
        # census waits (bounded) for an IO-calm window first — deferral
        # exists precisely because the walk cannot compete with boot storms
        # (freezes #19-#22 class). A malformed verdict moves the db aside
        # and restarts the gateway fresh: the same contract the start-path
        # census always had, executed when it can actually run.
        systemd.services.hermes-db-health = {
          description = "Hermes deferred SQLite integrity census (post-start)";
          after = [ "hermes.service" ];
          inherit onFailure;
          startLimitBurst = 3;
          startLimitIntervalSec = 3600;
          unitConfig = {
            # Same loud-failure mount gate as hermes.service.
            RequiresMountsFor = [ (toString cfg.stateDir) ];
          };
          serviceConfig = lib.mkMerge [
            (serviceOneshotDefaults { })
            (harden {
              # mv/rm on hermes-owned db files (CAP_FOWNER + dir traversal
              # CAP_DAC_OVERRIDE); systemctl talks to the manager socket
              # (bank-sync-rev-drift precedent: no cap needed for it).
              CapabilityBoundingSet = "CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER";
              ProtectHome = false;
              ReadWritePaths = [ cfg.stateDir ];
            })
            {
              Type = "oneshot";
              User = "root";
              ExecStart = lib.getExe hermesDbHealthScript;
              # 6min calm-wait cap + a cold 1.4 GB census (~2-5 min) fit
              # with headroom.
              TimeoutStartSec = "15min";
            }
            # The census is pure deferred maintenance I/O — idle class is
            # exactly the tier for it (fstrim pattern).
            ioTier.maintenance
          ];
        };

        # Auth canary for the read-only GitHub token (T14): boot + deploy
        # time git ls-remote against one private repo. Sits beside the
        # gateway unit, shares its sops env, skips inert while the token is
        # a placeholder. DNS-gated (github.com) so a boot racing dnsblockd
        # skips cleanly instead of failing.
        systemd.services.hermes-github-verify =
          let
            dnsGate = mkDnsGate {
              inherit pkgs;
              serviceName = "hermes-github-verify";
              hostname = "github.com";
            };
          in
          lib.mkIf (cfg.projectsDir != null) {
            description = "Hermes: verify read-only GitHub token can read private repos";
            wantedBy = [ "multi-user.target" ];
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
                EnvironmentFile = [ sopsEnvPath ];
                ExecStartPre = dnsGate.serviceConfig.ExecStartPre;
                ExecStart = lib.getExe githubVerifyScript;
                # DNS gate alone can wait 2min; give the probe headroom.
                TimeoutStartSec = "5min";
              }
              (serviceOneshotDefaults { })
              (harden { MemoryMax = "512M"; })
            ];
          };

        # Service-integration registry entry: the Hermes homepage tile +
        # unit-state monitoring (the gateway has no HTTP health endpoint
        # by design; the Hermes Agent Gateway Gatus check on the
        # system-health metrics stays in system-health.nix's own entry).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          hermes = {
            inherit (cfg) enable;
            vHost.layer = "none";
            homepage = {
              name = "Hermes";
              group = "Infrastructure";
              description = "AI Agent Gateway (Discord, Cron, Messaging)";
              icon = "self-hosted-gateway.png";
            };
            monitored = true;
          };
        };
      };
    };
}
