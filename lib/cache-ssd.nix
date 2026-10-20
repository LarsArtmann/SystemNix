# Shared plumbing for the USB cache-SSD modules (buildcache.nix, rust-cache.nix).
#
# The two modules are deliberate structural twins (same enclosure class, same
# automount/recovery architecture) but their GC semantics and filesystems
# differ, so only the mechanically identical pieces live here: the by-id
# serial parser, the systemd unit-name escape, and the textfile metrics
# script. Anything domain-specific stays in its module.
lib: {
  # ID_SERIAL parsed from a by-id device path ("ata-<model>_<serial>-partN").
  # null for non-by-id devices — callers skip the udev recovery trigger then
  # (x-systemd.device-bound still protects the mount).
  deviceSerialFromDevice =
    device:
    let
      m = builtins.match "(ata|scsi|usb|virtio)-(.+)-part[0-9]+" (baseNameOf device);
    in
    if m == null then null else builtins.elemAt m 1;

  # systemd unit name for a mountpoint path ("/mnt/buildcache" →
  # "mnt-buildcache"). Valid for paths without dots; systemd-escape of '.'
  # differs.
  mountUnitNameFor = mountPoint: lib.concatStringsSep "-" (lib.tail (lib.splitString "/" mountPoint));

  # The textfile .prom generator for a cache SSD (buildcache/rust-cache
  # metrics units): mount/SMART/usage gauges. Always writes the .prom file —
  # including when the drive is absent — so a dead/unmounted drive flips
  # <prefix>mounted to 0 and Gatus alerts, instead of silently serving a
  # stale green file.
  #
  # Mount-table presence is not health: a hot-unplugged USB drive leaves a
  # zombie VFS entry (stale device major:minor) that still satisfies findmnt
  # while every read returns EIO. The script gates on real I/O so a dead
  # mount reports 0, not phantom green.
  #
  # The mktemp'd tmp file: a fixed .tmp name collides with stale
  # foreign-owned leftovers in the sticky 1777 textfile dir (mail-relay
  # 2026-09-02..06 outage class).
  metricsScript =
    {
      prefix,
      promName,
      mnt,
      wholeDiskDevice,
      threshold,
      textfileDir,
    }:
    ''
      set -eu
      OUT="${textfileDir}/${promName}"
      mkdir -p "${textfileDir}"
      TMP="$(mktemp "${textfileDir}/${promName}.XXXXXX")"
      chmod 644 "$TMP"
      trap 'rm -f "$TMP"' EXIT
      mnt="${mnt}"
      dev="${wholeDiskDevice}"
      threshold=${toString threshold}

      mounted=0
      if
        findmnt -n -o TARGET "$mnt" 2>/dev/null | grep -qx "$mnt" \
          && timeout 15 ls -A "$mnt" >/dev/null 2>&1
      then
        mounted=1
      fi

      smart_healthy=0
      if smartctl -d sat -H "$dev" 2>/dev/null | grep -q "PASSED"; then
        smart_healthy=1
      fi

      usage=0
      over=0
      free_bytes=0
      total_bytes=0
      if [ "$mounted" = 1 ]; then
        usage="$(df --output=pcent "$mnt" | tail -n1 | tr -dc '0-9')"
        free_bytes="$(df -B1 --output=avail "$mnt" | tail -n1 | tr -dc '0-9')"
        total_bytes="$(df -B1 --output=size "$mnt" | tail -n1 | tr -dc '0-9')"
        if [ "''${usage:-0}" -ge "$threshold" ] 2>/dev/null; then
          over=1
        fi
      fi

      cat > "$TMP" <<METRICS
      # HELP ${prefix}mounted 1 if the cache SSD is mounted, 0 otherwise
      # TYPE ${prefix}mounted gauge
      ${prefix}mounted ''${mounted}
      # HELP ${prefix}smart_healthy 1 if SMART overall-health self-assessment is PASSED
      # TYPE ${prefix}smart_healthy gauge
      ${prefix}smart_healthy ''${smart_healthy}
      # HELP ${prefix}usage_percent Cache filesystem usage percentage (0-100)
      # TYPE ${prefix}usage_percent gauge
      ${prefix}usage_percent ''${usage}
      # HELP ${prefix}usage_over_threshold 1 if usage >= ${toString threshold}%
      # TYPE ${prefix}usage_over_threshold gauge
      ${prefix}usage_over_threshold ''${over}
      # HELP ${prefix}free_bytes Free bytes on the cache filesystem
      # TYPE ${prefix}free_bytes gauge
      ${prefix}free_bytes ''${free_bytes}
      # HELP ${prefix}total_bytes Total bytes on the cache filesystem
      # TYPE ${prefix}total_bytes gauge
      ${prefix}total_bytes ''${total_bytes}
      METRICS
      mv "$TMP" "$OUT"
    '';
}
