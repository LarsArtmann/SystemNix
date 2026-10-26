# Runbook: docs/services/media-atlas.md
# MediaAtlas federation hub — GROUNDWORK module (v0.1 plan L11 + L03
# enabler, repo ~/projects/media-atlas):
#   1. media_atlas PG role with READ-ONLY access to the immich DB
#      (smart_search embeddings for the hub's vector store) — converged by
#      a root oneshot (peer-auth postgres via runuser, the
#      discordsync-immich-key-provision pattern).
#   2. Optional: Immich read-only access to the DiscordSync attachment
#      archive (DiscordSync ADR-061 external-library runbook): the immich
#      user joins the discordsync group for DAC read, and
#      BindReadOnlyPaths enforces RO at the namespace level (the runbook's
#      "read-only from Immich's perspective" defense in depth).
# The hub service itself (systemd unit, port, caddy vHost, gatus) lands
# with the v0.1 deploy PR (plan task L25).
{ ... }:
{
  flake.nixosModules.media-atlas =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib) ioTier onFailure;
      cfg = config.services.media-atlas;
      archivePath =
        if cfg.immichExternalLibrary.importPath != null then
          cfg.immichExternalLibrary.importPath
        else if config.services.discordsync.attachmentsDir != null then
          config.services.discordsync.attachmentsDir
        else
          "${config.services.discordsync.dataDir}/attachments";

      # Root converger: idempotent read-only grants for the hub role. Peer
      # auth on the local socket means the LOGIN role is only usable by the
      # OS user of the same name (TCP requires a password this role does not
      # have) — zero new trust surface.
      pgRoConverger = pkgs.writeShellApplication {
        name = "media-atlas-pg-ro";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.postgresql
          pkgs.util-linux
        ];
        text = ''
          set -euo pipefail
          role="${cfg.user}"
          db="${cfg.database.name}"
          psql() { runuser -u postgres -- psql -d "$db" -v ON_ERROR_STOP=1 "$@"; }

          if ! psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$role'" | grep -q 1; then
            psql -c "CREATE ROLE $role LOGIN"
            echo "media-atlas-pg-ro: created role $role"
          fi
          psql -c "GRANT CONNECT ON DATABASE $db TO $role" >/dev/null
          psql -c "GRANT USAGE ON SCHEMA public TO $role" >/dev/null
          psql -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $role" >/dev/null
          # Keep tables created by FUTURE Immich migrations readable: Immich
          # runs its migrations as the immich role, so default privileges are
          # set FOR ROLE immich (requires the superuser this converger runs as).
          psql -c "ALTER DEFAULT PRIVILEGES FOR ROLE immich IN SCHEMA public GRANT SELECT ON TABLES TO $role" >/dev/null
          echo "media-atlas-pg-ro: converged ($role has read-only access to db $db)"

          # Schema fingerprint: Phase-0 evidence (media-atlas TODO item 1) and
          # the anchor the hub's `atlas doctor` pins against the deployed Immich
          # version (plan L16). Absent table = WARN, not FAIL — the grants above
          # are the convergence contract; smart_search presence is Immich's
          # business (ML smart-search toggle), not this converger's.
          if psql -tAc "SELECT to_regclass('smart_search')" | grep -q smart_search; then
            echo "media-atlas-pg-ro: smart_search schema fingerprint:"
            psql -c "SELECT column_name || ' ' || data_type FROM information_schema.columns WHERE table_name='smart_search' ORDER BY ordinal_position"
            echo "media-atlas-pg-ro: smart_search rows: $(psql -tAc 'SELECT count(*) FROM smart_search')"
          else
            echo "media-atlas-pg-ro: WARN smart_search table not found in $db (ML smart search disabled or schema drifted past the converger)" >&2
          fi
        '';
      };
    in
    {
      options.services.media-atlas = {
        enable = lib.mkEnableOption "MediaAtlas hub groundwork: read-only Postgres role on the immich DB (smart_search) plus optional Immich external-library read access to the DiscordSync archive. The hub service itself (unit, port, vHost) lands in a later PR.";

        database.name = lib.mkOption {
          type = lib.types.str;
          default = "immich";
          defaultText = "immich";
          description = "Target database for the read-only role (the shared-cluster immich DB).";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "media_atlas";
          description = "Hub OS user and matching PG role (peer auth on the local socket requires role name == OS user name).";
        };

        immichExternalLibrary.enable = lib.mkEnableOption "Immich read-only access to the DiscordSync attachments archive (external library, DiscordSync ADR-061 runbook: group read + namespace-level RO bind)";

        immichExternalLibrary.importPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          defaultText = "resolved from services.discordsync (attachmentsDir when set, else <dataDir>/attachments)";
          description = "Override for the archive path Immich reads (null = derive from the discordsync module).";
        };
      };

      config = lib.mkIf cfg.enable {
        # Peer-auth principal for the hub: OS user == PG role. The hub service
        # unit (L25) runs as this user and connects over the local socket.
        users.groups.${cfg.user} = { };
        users.users.${cfg.user} = {
          isSystemUser = true;
          group = cfg.user;
          description = "MediaAtlas federation hub (read-only peer-auth PG access to immich smart_search)";
        };

        systemd.services.media-atlas-pg-ro = {
          description = "MediaAtlas read-only Postgres role converger (grants on the immich DB via peer-auth postgres)";
          after = [
            "postgresql.service"
          ];
          wants = [
            "postgresql.service"
          ];
          # multi-user-wanted (crowdsec-setup pattern): the deploy.sh
          # provisioner loop's is-enabled gate admits it, so every deploy
          # re-converges the grants. Boot-time run covers DB-restore healing.
          wantedBy = [ "multi-user.target" ];
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = lib.getExe pgRoConverger;
              TimeoutStartSec = "2min";
              # Root BY DESIGN (discordsync-immich-key-provision pattern):
              # peer-auth postgres via runuser and ALTER DEFAULT PRIVILEGES FOR
              # ROLE immich need superuser; no secret exists to authenticate
              # with. NoNewPrivileges stays OFF — runuser is setuid and the
              # script legitimately needs it.
              NoNewPrivileges = false;
              ProtectSystem = "strict";
              PrivateTmp = true;
            }
            # io-tier-coverage-audit: every boot-gated unit carries a tier.
            ioTier.background
          ];
        };

        # --- Immich external-library read access (ADR-061 runbook) ---
        users.users.immich.extraGroups = lib.mkIf cfg.immichExternalLibrary.enable [
          config.services.discordsync.group
        ];
        systemd.services.immich-server = lib.mkIf cfg.immichExternalLibrary.enable {
          # Mount-gated (226 class): a detached DAS fails the unit loudly
          # instead of scanning a root-fs shadow path.
          unitConfig.RequiresMountsFor = [ archivePath ];
          # Namespace-level RO over the group-rwx archive dir: Immich never
          # writes external-library files, and the bind makes that a kernel
          # guarantee instead of an application promise.
          serviceConfig.BindReadOnlyPaths = [ archivePath ];
        };
      };
    };
}
