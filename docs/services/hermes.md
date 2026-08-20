# Hermes Agent Gateway

Discord bot / AI agent gateway (`hermes gateway run`) running as a systemd
service. Module: `modules/nixos/services/hermes.nix`; upstream flake input:
`hermes-agent` (NousResearch), pinned in `flake.nix`.

- **User**: `hermes` (system user, uid 975, groups: `hermes`, `render` for GPU/TTS)
- **State**: `/home/hermes` (2770 hermes:hermes — only root and hermes can traverse)
- **Port**: none (connects OUT to Discord/platform APIs; no HTTP listener)
- **Monitoring**: Gatus via system-health unit-state metrics (no HTTP probe by design)

## Module Options

| Option | Default | Meaning |
|--------|---------|---------|
| `enable` | false | Install + start the gateway |
| `projectsDir` | `null` | Host directory bind-mounted READ-ONLY at `<stateDir>/workspace/projects`. `null` = no bind, no projects env vars |
| `user` / `group` / `stateDir` | `hermes`/`hermes`/`/home/hermes` | Service identity |
| `restartSec` / `timeoutStopSec` | `5` / `120` | Restart/stop pacing |

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
5. `hermes-workspace-doc` (projectsDir only) — installs
   `workspace/AGENTS.md` ONCE (agent edits survive deploys).

## Ops

```bash
journalctl -u hermes -n 100 --no-pager     # gateway + ExecStartPre logs
pgrep -f 'gateway run'                     # gateway PID
grep workspace/projects /proc/<pid>/mountinfo   # verify the ro bind
```

- Deploys restart the unit; the gateway drains up to 60s with active agent
  sessions, then exits 75 (`RestartForceExitStatus=75` forces the restart —
  an expected, designed `TEMPFAIL` in the journal, not an error).
- `MemoryMax=24G` / `CPUQuota=400%`: PyTorch/ROCm GPU mappings are NOT RSS;
  do not blind-cut after looking at `system_service_memory_bytes` (review
  pending with the disk audit — see TODO_LIST).
- Startup deps: `network-online`, `sops-nix`, `dnsblockd` (upstream does
  networked startup). Secrets: sops template `hermes-env` → EnvironmentFile.
- Known-benign journal noise: `TERMINAL_CWD … deprecated` (see above);
  `check_fn … returned False` tool-registry lines (optional tools without
  their extras installed); Discord slash-command sync 429 retries.

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

## Related

- Workspace rules: `<stateDir>/workspace/AGENTS.md` (delivered once)
- VM test: `tests/test-hermes.nix` (`nix build .#checks.x86_64-linux.hermes`)
- Post-deploy smoke: hermes section in `scripts/post-deploy-check.sh`
- Upstream patch note: `registration_lifecycle.py` py-modules gap (module
  header comment) — delete the override when upstream fixes it.
