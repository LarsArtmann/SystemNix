# Paperless-ngx document management (OCR, consume, archive) on the mirrored pool
_: {
  flake.nixosModules.paperless =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        ioTier
        onFailure
        ports
        ;
    in
    {
      config = lib.mkIf config.services.paperless.enable {
        services.paperless = {
          port = ports.paperless;
          address = "127.0.0.1";

          # All state (sqlite db, search index, media, consume dir, exporter
          # output) lives on the dedicated pool subvol so it is independently
          # snapshottable via the btrbk-pool instance and survives an NVMe loss.
          dataDir = "/mnt/pool/services/paperless";

          # Sets PAPERLESS_URL only (correct CSRF/absolute URLs behind the
          # proxy). configureNginx stays off — Caddy is the house proxy and
          # exposure goes through the standard Layer-2 protectedVHost.
          domain = "paperless.${config.networking.domain}";

          # sops secret; consumed by paperless-scheduler via systemd
          # LoadCredential (read by PID 1, root ownership is sufficient).
          # Re-set on every scheduler start only when the value changed
          # (upstream manage_superuser + superuser-state guard).
          passwordFile = config.sops.secrets.paperless_admin_password.path;

          # Daily documentexporter -> dataDir/export; freshness is watched by
          # services.backup-coordination (see configuration.nix).
          exporter.enable = true;

          settings = {
            # Rebuilds tesseract with equ+osd+eng+deu (upstream package apply).
            PAPERLESS_OCR_LANGUAGE = "deu+eng";
          };
        };

        systemd.services =
          let
            mountGate = {
              unitConfig.RequiresMountsFor = [ "/mnt/pool/services/paperless" ];
              inherit onFailure;
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
            };
          in
          {
            # Upstream defaultServiceConfig already hardens thoroughly (strict
            # ProtectSystem, empty CapabilityBoundingSet, SystemCallFilter). Only
            # resource ceilings + I/O tier are layered on top.
            paperless-web = mountGate // {
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "1G";
                  CPUQuota = "200%";
                }
              ];
            };
            # Scheduler runs DB migrations + superuser bootstrap in preStart;
            # give the first start (migration + index init) headroom over the
            # global 3min DefaultTimeoutStartSec.
            paperless-scheduler = mountGate // {
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "512M";
                  CPUQuota = "100%";
                  TimeoutStartSec = "5min";
                }
              ];
            };
            # Task queue does OCR + classification — the heavyweight.
            paperless-task-queue = mountGate // {
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "2G";
                  CPUQuota = "200%";
                }
              ];
            };
            paperless-consumer = mountGate // {
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "1G";
                  CPUQuota = "200%";
                }
              ];
            };
          };
      };
    };
}
