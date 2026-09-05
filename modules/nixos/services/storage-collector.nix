# storage-collector — long-term filesystem capacity tracking.
#
# A lightweight standalone daemon (Rust) that tracks every real mounted
# filesystem each cycle — capacity, usage, inodes — and appends a rotating
# JSONL record under /var/lib/storage-collector. This is the storage-trend
# data source that keeps working while monitor365 is disabled (see the
# monitor365.nix module for that blocker); the crate is built for later
# adoption as a monitor365 extracted collector.
#
# What it gives this fleet:
#   - /mnt/pool (16T btrfs DAS), /data, NVMe subvolumes, /tmp tmpfs —
#     growth history per mount instead of point-in-time df thresholds.
#   - Threshold events at warn% with hysteresis (default 85/80), so a
#     filesystem hovering at the boundary emits one event, not a flood.
#   - Removal debounce: a mount must be missing 3 consecutive cycles
#     before it is reported removed (absorbs statvfs flaps and USB DAS
#     re-enumeration windows).
#
# The service module (options: intervalSecs, warnPercent, clearPercent,
# removalCycles, textfile, skipFsTypes, trackFsTypes, maxFileMb,
# keepFiles, dataDir) lives in the storage-collector flake.
{ inputs, ... }: {
  flake.nixosModules.storage-collector =
    {
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.storage-collector.nixosModules.default ];

      config = lib.mkIf config.services.storage-collector.enable {
        services.storage-collector = {
          # 60 s cycles → ~525k telemetry lines/year per mount before
          # rotation; maxFileMb=10 with keepFiles=5 bounds disk use at
          # ~60 MiB regardless.
          intervalSecs = lib.mkDefault 60;
          dataDir = lib.mkDefault "/var/lib/storage-collector";
        };
      };
    };
}
