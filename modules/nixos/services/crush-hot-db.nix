# Runbook: docs/services/hot-db.md
# crush-hot-db — relocate per-project crush session DBs off the QLC root.
#
# The 2026-09-14 boot IO storm (docs/todo/storage.md): `~/projects/**/.crush/crush.db`
# (2-5 GB each + WALs, 5+ concurrent sessions) churns seeky SQLite on the QLC
# `@` subvolume, pinning io PSI some avg60 at 40-60% for hours while memory
# stays pristine. This module moves each project's `.crush/` directory onto
# the Samsung TLC NVMe (`/mnt/hot`) and leaves a symlink in its place.
#
# DELEGATED to the collection module (inputs.nixos-modules.nixosModules.
# hot-dir-migrate, repo github:LarsArtmann/nixos-modules): the migrate engine
# (bounded-depth discovery, per-project /proc comm+fd liveness guard,
# fresh-write skip, empty-target auto-heal vs populated refusal, dry-run,
# single-flight flock, fail-loud exits), the unit + timer, and ALL hardening
# live upstream — VM-tested in the collection's own checks.hot-dir-migrate-vm
# (the full behavior matrix this fleet's test-crush-hot-db VM covers, ported),
# contract-checked (hardcoded expectations), and mutation-proven in its
# tests/negative/ harness. The delegation is also the fix vehicle for the
# 2026-11-12 live finding: the host runs yama ptrace_scope=1, under which
# reading foreign /proc/<pid>/fd symlink targets requires CAP_SYS_PTRACE —
# the historical 3-cap set blinded the liveness guard (live sessions were
# relocated, e.g. monitor365-ui-sdk 2026-11-12 21:48); upstream carries
# the cap + the regression comment + the `cap-stripped` negative leg.
#
# This file layers ONLY the SystemNix facts (collection-delegation recipe,
# docs/agents/integration-registry.md):
#   - the historical unit name (crush-hot-db-migrate: deploy.sh's explicit
#     restart block + the audits reference it)
#   - fleet paths/owner (projects under the primary user, ${primaryUser}:users)
#   - the fleet dry-run env var (CRUSH_HOT_DB_DRY_RUN — runbooks reference it)
{
  inputs,
  ...
}: {
  flake.nixosModules.crush-hot-db =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.crush-hot-db;
      primaryUser = config.users.primaryUser or "lars";
    in
    {
      imports = [inputs.nixos-modules.nixosModules.hot-dir-migrate];

      options.services.crush-hot-db = {
        enable = lib.mkEnableOption "relocate per-project crush session DBs to the hot-DB disk";
        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/hot";
          description = "Hot-DB disk mount point (Samsung TLC NVMe, by-label tlc).";
        };
        projectsDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/${primaryUser}/projects";
          defaultText = lib.literalExpression ''"/home/${primaryUser}/projects"'';
          description = "Directory tree scanned for `.crush/` session dirs (any checkout down to depth 3, e.g. `<dir>/group/repo`).";
        };
      };

      config = lib.mkIf cfg.enable {
        services.hot-dir-migrate = {
          enable = true;
          # Historical unit name: deploy.sh's explicit restart block, the
          # audits, and the runbooks reference crush-hot-db-migrate.
          unitName = "crush-hot-db-migrate";
          inherit (cfg) projectsDir mountPoint;
          # Fleet ownership: sessions run as the primary user (group users).
          ownerUser = primaryUser;
          # Historical env var: CRUSH_HOT_DB_DRY_RUN=1 rehearses a run.
          dryRunEnvVar = "CRUSH_HOT_DB_DRY_RUN";
        };
      };
    };
}
