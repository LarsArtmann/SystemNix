# Hermes Agent Gateway

Discord bot / AI agent gateway (`hermes gateway run`) running as a systemd
service. Module: `modules/nixos/services/hermes.nix`; upstream flake input:
`hermes-agent` (NousResearch), pinned in `flake.nix`.

- **User**: `hermes` (system user, uid 975, groups: `hermes`, `render` for GPU/TTS)
- **State**: `/home/hermes` (2770 hermes:hermes — only root and hermes can traverse)
- **Port**: none (connects OUT to Discord/platform APIs; no HTTP listener)
- **Monitoring**: Gatus via system-health unit-state metrics (no HTTP probe by design)

## Module Options

| Option                          | Default                          | Meaning                                                                                                          |
| ------------------------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `enable`                        | false                            | Install + start the gateway                                                                                      |
| `projectsDir`                   | `null`                           | Host directory bind-mounted READ-ONLY at `<stateDir>/workspace/projects`. `null` = no bind, no projects env vars |
| `user` / `group` / `stateDir`   | `hermes`/`hermes`/`/home/hermes` | Service identity                                                                                                 |
| `restartSec` / `timeoutStopSec` | `5` / `120`                      | Restart/stop pacing                                                                                              |

## Projects Access Model (the whole point)

The agent sees the primary user's code **read-only** and works on clones —
upstream's own worktree-isolation philosophy, enforced by the kernel:

1. `BindReadOnlyPaths = <projectsDir>:<stateDir>/workspace/projects` —
   MS_RDONLY bind set up by PID 1 as root (does NOT depend on traversing the
   0700 primary home, unlike the retired ACL grant).
2. `TERMINAL_CWD=<stateDir>/workspace` — terminal opens beside `./projects`.
   Explicit `terminal.cwd` in the runtime config.yaml WINS over this env
   (verified in upstream `gateway/run.py` + `cwd_placeholder.py`). Startup
   prints a cosmetic `TERMINAL_CWD found in .env` deprecation warning —
   **expected and harmless; do NOT "fix" it** by injecting config.yaml
   (runtime-owned, split-brain risk).
3. `HERMES_WRITE_SAFE_ROOT=<stateDir>` — upstream write_file/patch
   hard-block anything outside the state root before touching disk.
4. `GIT_CONFIG_GLOBAL=<store path>` — read-only gitconfig with
   `[safe] directory = <stateDir>/workspace/projects` + `…/*`: without it,
   git ≥2.35.2 refuses ALL ops on the bind's foreign-owned repos
   ("dubious ownership"). Side effect: `--global` git writes fail in agent
   sessions; identity must be set per-clone (documented in the workspace
   AGENTS.md delivered once by `hermes-workspace-doc` ExecStartPre).
5. `RequiresMountsFor=<projectsDir>` — fails loudly if the source vanishes.

**Workflow for the agent**: read `./projects/<repo>` directly (read-only git
works); `git clone ./projects/<repo> ./<repo>` to make changes; write scope
bounded to `/home/hermes`; never write into `./projects` (EROFS by design).

## ExecStartPre Chain (order matters)

1. `+hermes-acl-revoke` — converges away the retired `g:hermes` home-ACL
   grant (removed from primary home once; no-op afterwards). **Retirement
   TODO ≥2026-09-03**: delete after 2 clean weeks (`getfacl /home/lars |
   grep hermes` empty).
2. `+hermes-fix-permissions` — early-exits while `<stateDir>` is
   `hermes:hermes 2770`; on drift it chowns/chmods with
   `find <stateDir> -xdev -path '<stateDir>/workspace/projects' -prune -o …`
   and `|| true` per walk. **Never reintroduce `chown -R <stateDir>`**: the
   RO bind is inside the unit's mount namespace BEFORE ExecStartPre runs,
   so a recursive chown EROFS-es on every foreign file and crash-loops the
   unit into start-limit-hit (live incident 2026-08-20). Note `-xdev` alone
   is NOT sufficient — a same-filesystem bind (BTRFS subvol) shares st_dev;
   the `-prune` on the exact path is the real guard.
3. `+hermes-migrate-state` — SQLite integrity check + legacy state migration.
4. `hermes-merge-env` (as hermes) — strips deprecated keys from `.env`.
5. `hermes-lsp-bin-heal` (as hermes) — restores exec bits on
   `<stateDir>/lsp/bin/*` and `<stateDir>/lsp/node_modules/.bin/*`. The OLD
   perms walk used `chmod 0660` on all files, which stripped the execute
   bit from the agent's self-installed language servers
   (`PermissionError: .../lsp/bin/pyright-langserver` since 2026-08-16,
   agent lint tooling silently degraded). The walk is now exec-preserving
   (`u=rwX,g=rwX,o=`); this heals binaries stripped before that fix.
6. `hermes-workspace-doc` (projectsDir only) — version-marker install of
   `workspace/AGENTS.md` (see below).

## Workspace AGENTS.md versioning

Line 1 carries `<!-- systemnix-workspace-doc: vN -->`. Install semantics:
missing → install; older marker → deliberate upgrade (agent edits to the
old version are REPLACED); same/newer marker or agent-rewritten header →
untouched. So agent edits survive deploys within a version, and shipping a
new version (bump `workspaceDocVersion` in `hermes.nix`) is the sanctioned
way to update the doc. The script journals its decision on every start
(`hermes-workspace: …`) — that line is the smoke-check proof the mechanism
ran (the file itself is unreadable from lars: `<stateDir>` is 2770).

## Private-repo credentials (read-only, permanent no-push)

User decision 2026-08-20 (**Q1 yes / Q3 read-only forever**): hermes gets a
read-only GitHub token for cloning private LarsArtmann repos over HTTPS.
No push credentials will ever be wired — revisit only with an explicit
policy change.

- **Secret**: sops `hermes-github-token.yaml` → `hermes_github_read_token`
  → rendered into `hermes-env` as `HERMES_GITHUB_READ_TOKEN`. Ships as a
  PLACEHOLDER; every consumer treats non-`github_pat_`/`ghp_`/`gho_`
  values as "no token" (completely inert).
- **Auth**: `hermes-git-credential` store script answers GitHub HTTPS
  queries from the env var (git credential-helper protocol), wired via
  `[credential "https://github.com"]` in the read-only `hermes-gitconfig`.
  The token is never written to any repo config or file git could persist.
- **Canary**: `hermes-github-verify.service` (boot + every deploy) does one
  `git ls-remote` against `services.hermes.githubPrivateVerifyUrl`
  (default: a known private repo). Skips cleanly while the token is a
  placeholder; fails the unit (Discord via onFailure) when a real token
  stops working — expired/revoked surfaces within one boot, not at the
  agent's first failed clone.

**Go-live (user, one command)**: create a fine-grained PAT
(github.com → Settings → Developer settings → Fine-grained tokens:
Contents: Read-only, scoped to the LarsArtmann private repos), then

```bash
SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) \
  sops --set '["github_read_token"] "github_pat_…"' \
  platforms/nixos/secrets/hermes-github-token.yaml
nix run .#deploy   # canary flips from skip to verified in the journal
```

## Ops

```bash
journalctl -u hermes -n 100 --no-pager     # gateway + ExecStartPre logs
pgrep -f 'gateway run'                     # gateway PID
grep workspace/projects /proc/<pid>/mountinfo   # verify the ro bind
```

- Deploys restart the unit; the gateway drains up to 60s with active agent
  sessions, then exits 75 (`RestartForceExitStatus=75` forces the restart —
  an expected, designed `TEMPFAIL` in the journal, not an error).
  `deploy.sh` WARNs when the last 10 min show agent activity before
  switching. Chromium CDP children get SIGKILLed on every restart
  (`KillMode=mixed`) — expected, noisy, harmless.
- Agent scratch: `write_file`/`patch` only work under `/home/hermes`
  (`HERMES_WRITE_SAFE_ROOT`) — /tmp paths are denied. The workspace doc v2
  teaches using `./scratch/`; a `/tmp/...` denial in the journal is the
  agent learning that, not a bug.
- `MemoryMax=24G` / `CPUQuota=400%`: PyTorch/ROCm GPU mappings are NOT RSS;
  do not blind-cut after looking at `system_service_memory_bytes` (review
  pending with the disk audit — see TODO_LIST).
- Startup deps: `network-online`, `sops-nix`, `dnsblockd` (upstream does
  networked startup). Secrets: sops template `hermes-env` → EnvironmentFile.
- Known-benign journal noise: `TERMINAL_CWD … deprecated` (see above);
  `check_fn … returned False` tool-registry lines (optional tools without
  their extras installed); Discord slash-command sync 429 retries.

## Dedicated subvolume (@home-hermes, 2026-09-15)

`/home/hermes` is a toplevel BTRFS subvolume (`@home-hermes`), plain-mounted
via `snapshots.nix` (declared only while `services.hermes.enable` — never the
`@cache-home` automount style: tmpfiles rules under `/home/hermes` + automount
is the shadow-dir class). `hermes.service` carries
`RequiresMountsFor = [/home/hermes]`, so a missing mount fails loudly instead
of running against a shadowed home.

**Why:** inside `@`, hermes churn rode every nightly btrbk-root send with
`target_preserve_min=all` — every byte the agent ever deleted was hoarded on
the HDD pool forever, and `@` rollbacks always reverted hermes state. The
subvol gets its own btrbk entry: local snapshots inherit `@`'s 2d/3d-1w;
pool receives go to the same `/mnt/pool/backups/root` dir but with BOUNDED
retention (`target_preserve_min=7d`, `target_preserve=14d 4w`).
`btrfs-verify-pool-backups` and `btrfs-verify-snapshots` check the
`@home-hermes` prefix whenever the host mounts the subvol.

**Migration runbook** (sudo, quiet window outside 23:00–00:45;
plan: `docs/planning/2026-09-15_19-59_HERMES-HOME-SUBVOLUME-MIGRATION.md`).
Measured live 2026-09-16: the state is **92.3 GB / 948,341 files** (workspace
git clones dominate) — every state-wide operation (copies, perms walks,
backups) is hours-scale under IO load, minutes-scale when quiet. The first
full pool send is a ~92 GB transfer on the DAS USB link:

```bash
sudo bash scripts/migrate-hermes-subvol.sh prepare   # REFUSES while io PSI some avg10 >=20% (storm gate); wipes partial staging; idle-IO 2-phase rsync with live progress
nix run .#deploy                                      # activates home-hermes.mount, restarts hermes
sudo systemctl start btrbk-root.service              # seeds the first full pool send
sudo bash scripts/migrate-hermes-subvol.sh status    # verify mount + snapshots + receives
# ...days later, after settling:
sudo bash scripts/migrate-hermes-subvol.sh finalize  # gated: mount live + hermes active + snapshot exists; trashes /home/hermes.old
```

Deploy-before-prepare is safe but loud: mount fails `nofail`, hermes fails
into OnFailure alerting. Space from the old dir frees as `@` snapshots expire
(3d/1w). Old hermes history stays in the pre-migration pool receives forever.

## Landmine History

- **ACL grant death (pre-2026-08-20)**: original access used
  `setfacl -m g:hermes:r-x /home/lars`. Any later `chmod` on an ACL'd
  directory rewrites the ACL mask and silently disables every named entry
  (`mask::---` observed). Lesson: never grant service access via home-dir
  ACLs — bind mounts don't rot. Full narrative: `docs/gotchas-archive.md`.
- **D1 chown-vs-bind crash-loop (2026-08-20)**: shipped with the feature —
  `chown -R` in ExecStartPre vs the RO bind inside the pre-start mount
  namespace. Fixed with prune+xdev+tolerant walks; regression-tested in
  `tests/test-hermes.nix`.
- **D2 dubious ownership (2026-08-20)**: git refused all ops on the bind
  until `GIT_CONFIG_GLOBAL` shipped the safe.directory allow-list.
- **LSP exec-bit strip (2026-08-16→20, found 2026-08-20)**: the perms walk's
  `chmod 0660` stripped every executable under `<stateDir>` — the agent's
  self-installed pyright/bash-language-server died with `PermissionError`
  for four days. Fixed by exec-preserving chmod (`u=rwX,g=rwX,o=`) plus a
  heal for already-stripped binaries; regression-tested in the VM test.

## Related

- Workspace rules: `<stateDir>/workspace/AGENTS.md` (delivered once)
- VM test: `tests/test-hermes.nix` (`nix build .#checks.x86_64-linux.hermes`)
- Post-deploy smoke: hermes section in `scripts/post-deploy-check.sh`
- Upstream patch note (RESOLVED 2026-08-21): upstream ships
  `registration_lifecycle.py` in py-modules since v0.20.1 — the
  downstream extraction/PYTHONPATH override was deleted from
  `hermes.nix` after verifying the import inside the sealed venv.

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### Hermes

**v0.21.0 DEPLOYED LIVE 2026-09-05** (`hermes --version` confirms, no update nag; the deploy rode the 2026-09-05 ecosystem-repair wave — see the Private Go Repos section). The 2026-09-04 deploy blocker (sops `browser_history_agent_db_token` declared but absent) was resolved by the parallel session's oneshot route (db_token declaration REMOVED from sops.nix; agent provisioning via the provision oneshot) + the `sops-key-audit.nix` eval-time guard now catching the class at flake-check time.

Active pip extras (16, all verified present in upstream `pyproject.toml` at `0a374d16`, 2026-10-02): `messaging`, `anthropic`, `azure-identity`, `bedrock`, `daytona`, `dingtalk`, `edge-tts`, `exa`, `fal`, `feishu`, `firecrawl`, `matrix`, `modal`, `parallel-web`, `tts-premium`, `voice`. `hindsight` was dropped 2026-09-23 (upstream `73c598e319`) and `honcho` 2026-10-02 (upstream `7e53b3ef`, "remove bundled honcho provider; install from the plugin catalog"): both clients are now resolved by the catalog plugin installer via their `plugin.yaml` — consumers that pre-installed the extra must stop naming it. LESSON: an upstream extra removal breaks EVERY evo-x2 eval at `nix flake update` time with `Extra/group name '<extra>' does not match either extra or dependency group` — diff hermes.nix's `extraDependencyGroups` against the new rev's `[project.optional-dependencies]` first. Upstream ships 24+ more groups we do NOT enable (acp, computer-use, cron, google, google-chat, homeassistant, mcp, mem0, mistral, nemo-relay, otlp, pty, slack, sms, teams, termux, termux-all, uvloop, vercel, vertex, vision, wake, web, wecom, youtube) — integration-preference territory, review on demand. Do NOT add blindly. (The `supermemory` extra was itself dropped upstream `7b510cae`, 2026-10-02.)

**Projects access (read-only bind mount):** `services.hermes.projectsDir` (evo-x2: `/home/${primaryUser}/projects`) exposes the projects tree to the agent at `${stateDir}/workspace/projects` via `BindReadOnlyPaths` — kernel-enforced read-only, set up by PID 1 as root, so it does NOT depend on traversing the 0700 primary home. `TERMINAL_CWD=${stateDir}/workspace` lands the terminal tool beside `./projects` (an explicit `terminal.cwd` in runtime config.yaml overrides — intended precedence. Since v0.20.4 / upstream commit `31561e37` there is NO startup deprecation warning anymore: the warning now reads the `.env` FILE, and process-env `TERMINAL_CWD` — our systemd env bridge — is explicitly "legitimate" upstream; still do NOT inject config.yaml, which is runtime-owned and would split-brain). `HERMES_WRITE_SAFE_ROOT=${stateDir}` confines upstream `write_file`/`patch` to the state root (cron jobs/skills stay writable). `GIT_CONFIG_GLOBAL` points at a read-only store gitconfig with `[safe] directory = <stateDir>/workspace/projects` (+ `/*`) — without it git ≥2.35.2 refuses ALL ops on the foreign-owned bind repos ("dubious ownership"); side effect: `--global` git writes fail in agent sessions, identity is per-clone (documented in the workspace `AGENTS.md`, delivered once by the `hermes-workspace-doc` ExecStartPre — once-only `install`, so agent edits survive deploys). The agent makes changes by cloning into its writable workspace (upstream's worktree-isolation pattern) — it can NEVER edit lars' checkouts in place. Private 0700 dirs inside projects stay unreadable (only world-readable content is visible). **Why not home-dir ACLs:** the old `g:hermes:r-x` grant on the primary home died silently — any later `chmod` on an ACL'd dir rewrites the ACL _mask_, disabling every named entry while `getfacl` still shows the grant (observed live: `mask::---`), and setfacl's mask recalc would have re-enabled `group::r-x` for ALL `users` members. The `hermes-acl-revoke` ExecStartPre converges the stale grant away; hermes was dropped from the `users` group (projects read rides world-perms through the bind).

**Never `chown -R ${stateDir}` in hermes ExecStartPre (2026-08-20 live incident):** the RO bind is inside the unit's mount namespace BEFORE ExecStartPre runs — a recursive chown/chmod walk EROFS-es on every foreign file and crash-loops the unit into start-limit-hit (hermes was down 09:18→09:35 from exactly this). The fix-permissions script must keep `find <stateDir> -xdev -path '<stateDir>/workspace/projects' -prune -o …` with `|| true` per walk. `-xdev` ALONE is NOT sufficient — a same-filesystem bind (both paths in the `@` BTRFS subvol) shares st_dev; the `-prune` on the exact path is the real guard. Regression-tested in `tests/test-hermes.nix`.

**Restart-safe cron dispatch needs the user-manager bus (fixed 2026-09-12, the 1,302-error outage):** hermes v0.21.0 wraps EVERY cron fire in `systemd-run --user --scope` (upstream `tools/process_registry.py`, fail-closed BY DESIGN — falling back would let a gateway restart kill in-flight jobs; `_HERMES_GATEWAY=1` is set unconditionally by `gateway/run.py` and `INVOCATION_ID` is set for any systemd service, so the scope path is UNAVOIDABLE for a supervised gateway). As a SYSTEM service three things were missing and every cron job failed `Restart-safe cron worker dispatch failed: ... unavailable` from 2026-09-05 to 09-11: (1) no user manager for the hermes user → declarative `users.users.hermes.linger = true` + `after/wants user@975.service` (the pre-existing IMPERATIVE linger file — `loginctl enable-linger`, live since bring-up but owned by no module — is replaced; `users.manageLingering` defaults true and only touches DECLARED users, so lars' imperative linger is untouched); (2) **sd-bus never GUESSES the user bus socket** — a system service gets no XDG_RUNTIME_DIR, so the service needs `XDG_RUNTIME_DIR=/run/user/<uid>`, which requires a PINNED uid (`uid = 975`, matches live, eval-time computable — the "`uid` is null at eval" gotcha is exactly why the pin exists; a conflicting pin fails eval loudly); (3) **NixOS has NO `/bin/true`** and the upstream scope-availability probe execs `/bin/true` LITERALLY — tmpfiles `L+ /bin/true` → coreutils. All three verified empirically BEFORE landing (probe rc=0 with env + user manager inside the hardened sandbox incl. ProtectControlGroups — `systemd-run --scope` needs no writable cgroup mount; rc=1 without XDG_RUNTIME_DIR; rc=1 with /bin/true missing even with a working bus — the exec path is validated BEFORE the bus connect, which had masked cause #2 during the original 09-05 diagnosis). VM test §9 runs the EXACT probe + a no-env negative control. Probe failures cache for 60s (`_SYSTEMD_SCOPE_FAILURE_TTL_SECONDS`), so the ordering is belt, not load-bearing. The scoped worker lands in `user@975.slice` OUTSIDE the hermes.service cgroup — that IS the restart-safety (gateway restarts no longer kill in-flight cron jobs); worker MemoryMax = min(gateway cgroup limit, half RAM, 4G cap). **Lock rev `79445a496` identified (2026-09-12):** `fix(desktop): macOS parent-death watchdog…` (#103172, 2026-09-04) — ~20 commits past verified `d3630f85`, all desktop/dashboard UI churn + one Azure-gateway fix; nothing server-relevant, journal clean of new ERROR classes. The Discord 429 slash-command sync noise is GONE since ~09-08 (journal 429s after that date are zai/minimax LLM Token-Plan limits, not Discord).

**Monitoring:** hermes has NO HTTP endpoint by design — Gatus watches `system_service_state_failed` / `system_service_start_limit_hit` / `system_service_memory_over_threshold` / `system_service_restart_churn` from system-health (`hermes` in `monitoredServices`; the churn metric catches slow restart chains under the 3-in-2min crash-loop radar, e.g. exit-75 drain loops). Deploy smoke (`scripts/post-deploy-check.sh`): gateway-PID mountinfo shows the `ro` bind + the deployed unit carries `GIT_CONFIG_GLOBAL` with a parsing safe.directory + the workspace-doc ExecStartPre journaled this boot (the file itself is unreadable from lars — `<stateDir>` is 2770). deploy.sh WARNs when agent activity ran in the last 10 min. VM test: `tests/test-hermes.nix`. Runbook: `docs/services/hermes.md`.

**Perms walk is exec-PRESERVING (2026-08-20):** `chmod 0660` on `-type f` in the perms walk stripped execute bits from the agent's self-installed LSP binaries (`<stateDir>/lsp/bin/*` — `PermissionError` on spawn since 2026-08-16, silently degraded agent linting). The walk uses `chmod u=rwX,g=rwX,o=` (X = exec only where some class already has it) + `hermes-lsp-bin-heal` ExecStartPre restores stripped lsp/bin binaries; both regression-tested in the VM test. General rule: never blanket-`chmod 06xx` a tree that contains executables. **`~/.ssh` is PRUNED from the walk and converged owner-only on every restart (2026-08-21):** the same `g=rwX` made agent-created `~/.ssh/config` 0660 group-writable → OpenSSH refuses it ("Bad owner or permissions", live agent git-over-ssh failures). `converge_ssh` in the fix-permissions script heals it even on the fast-path early-exit; regression-tested in the VM test (6b).

**Private-repo creds (user decision 2026-08-20: Q1 yes read-only PAT / Q3 permanently no-push):** sops `hermes-github-token.yaml` → `HERMES_GITHUB_READ_TOKEN` in `hermes-env`. Ships as PLACEHOLDER — the `hermes-git-credential` store helper only answers GitHub HTTPS queries when the token matches `github_pat_|ghp_|gho_` (inert otherwise, public-repo clones unaffected; the token is never persisted anywhere git could write it out). `hermes-github-verify.service` (boot + deploy, DNS-gated) ls-remotes one private repo — skip-cleanly on placeholder, unit-fails (Discord) when a real token stops working. Go-live (user): fine-grained PAT Contents:Read-only + `sops --set` into the file — exact block in `docs/services/hermes.md`. Workspace layout decision: DEFER (stays on `@`, revisit trigger in docs/todo/services.md). **Forgejo WRITE exception (owner decision 2026-09-23, supersedes no-push FOR FORGEJO ONLY — GitHub stays read-only forever): `forgejo-hermes-token` now mints a `write:repository` token for `hermes-agent` (scope-marker file `hermes-agent.token.scope` next to the staged token forces regeneration on scope changes — the old read-only token stays cryptographically valid, so the missing marker IS the upgrade signal) and runs a per-repo collaborator sweep granting `write` on EVERY lars-owned forgejo repo (`GET /user/repos?type=owner` paginated + `PUT /repos/{o}/{r}/collaborators/hermes-agent`; converger — new repos pick up the grant on next boot/deploy; listing failure = systemic exit 1, 100%-grant-failure = systemic, partial = WARN per github-auto-assign doctrine; org-owned repos deliberately out of scope; mirror repos reject pushes at the forgejo level so the grant is inert there). Repo-level deletion stays STRUCTURALLY impossible (`DELETE /repos/{owner}/{repo}` needs OWNER/ADMIN on the repo; a write-role collaborator never has it) — but in-repo branch/tag/file deletion + force-push ARE possible (branch protection rules are the lever if that ever needs limiting). `hermes-git-credential` answers the forgejo host too (reads `/run/hermes-forgejo-token`, emits `username=hermes-agent`; missing/malformed = no credential → anonymous fallback), and the workspace AGENTS.md bumped v2→v3 teaching `git remote add forgejo https://forgejo.<domain>/lars/<repo>.git` + push, never-delete/force-push.

**Workspace AGENTS.md is VERSION-marker installed:** line 1 `<!-- systemnix-workspace-doc: vN -->`; missing → install, older marker → upgrade (replaces agent edits — the sanctioned update path is bumping `workspaceDocVersion`), same/newer/agent-rewritten header → untouched. The installer journals its decision every start (that line is the smoke-check proof). v2 teaches: scratch files go in the workspace (`write_file` is denied outside `/home/hermes`, INCLUDING `/tmp`), private-repo clones work via the credential helper, never push.

**`registration_lifecycle` patch DELETED (2026-08-21; drift class GONE upstream since v0.21.0):** upstream shipped the module in a static `[tool.setuptools]` py-modules list v0.20.1-v0.20.x; since v0.21.0 there is NO static list anymore — `setup.py`'s `_root_py_modules()` derives every root-level `*.py` (registration_lifecycle.py included) from the source tree at build time, with an upstream comment "Do not add the list back". Verified importable from the sealed uv2nix venv (`hermes-agent-env` site-packages) at `d3630f85`. The historical downstream patch (extract → `runCommand` → `wrapProgram --suffix PYTHONPATH`) was a second source of truth and is gone from `hermes.nix`. If a future bump ever reintroduces `ModuleNotFoundError` for a root module, check `setup.py` first — the symptom class is now upstream build-config changes, not our packaging.
