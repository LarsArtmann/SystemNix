# Rescue snapshot tier for the @ root subvolume (2026-09-12 incident).
#
# WHY THIS EXISTS: at 02:20 on 2026-09-12 ALL six local btrbk snapshots were
# glob-deleted from /mnt/btrfs-root/.snapshots/ by an interactive shell
# (`sudo btrfs subvolume delete /mnt/btrfs-root/.snapshots/@.20260*` where the
# operator meant `du`). Sudo is passwordless here, btrfs subvolume delete has
# no confirmation, and the glob expanded to every snapshot before the command
# ran. The pool copies survived; the cost was the lost incremental-send anchor
# (one unavoidable full re-send) and a zero-rollback window until 23:00.
#
# This module guarantees a survivor OUTSIDE btrbk's snapshot_dir:
#   /mnt/btrfs-root/.rescue/@.rescue-<timestamp>   (read-only, total = keep)
#
# Protection layers:
#   1. LOCATION — a glob over .snapshots/* cannot reach .rescue.
#   2. chattr +a on .rescue — append-only blocks entry deletion even for
#      root (btrfs subvolume delete inside it fails EPERM). The script opens
#      the append-only window only for its own prune/create/verify sequence.
#   3. SELF-TEST — every run PROVES the append-only flag still blocks the
#      subvolume-delete ioctl and stamps the verdict to
#      /var/lib/btrfs-rescue/protection. If a future kernel ever stops
#      enforcing it, the stamp flips to 0 and the "BTRFS Rescue Snapshots"
#      Gatus check goes red — protection can never silently become
#      location-only.
#
# Deliberately NOT chattr +a on .snapshots itself: btrbk prunes there nightly
# (snapshot_preserve 3d 1w) — an append-only .snapshots would wedge retention
# and stack up snapshots forever on the space-tight QLC NVMe.
#
# A side benefit: a rescue snapshot is a valid incremental-send parent
# (uuid-matched against the pool target), so if .snapshots is ever wiped
# again, tonight's btrbk run sends a cheap incremental instead of a full send.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (import ../../../lib/default.nix lib)
    harden
    serviceOneshotDefaults
    onFailure
    ;

  cfg = config.services.btrfs-rescue;

  rescueScript = pkgs.writeShellApplication {
    name = "btrfs-rescue-snapshot";
    runtimeInputs = [
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.e2fsprogs # chattr
    ];
    text = ''
      set -euo pipefail
      RESCUE_DIR="/mnt/btrfs-root/.rescue"
      # KEEP = TOTAL snapshots retained after a run (prune to keep-1, then
      # create one fresh — never keep+1).
      KEEP=$(( ${toString cfg.keep} - 1 ))
      STAMP_DIR="/var/lib/btrfs-rescue"
      STAMP="$STAMP_DIR/protection"
      mkdir -p "$STAMP_DIR"

      if [ ! -d /mnt/btrfs-root ]; then
        echo "btrfs-rescue: /mnt/btrfs-root is missing — not a root-toplevel-layout host?" >&2
        exit 1
      fi
      mkdir -p "$RESCUE_DIR"

      # Rotation window: append-only off so this script may prune and create.
      chattr -a "$RESCUE_DIR" 2>/dev/null || true

      # Prune to the newest KEEP entries. Glob expansion is sorted and names
      # are chronological, so the OLDEST prune_count entries get deleted.
      # ([ -e ] guard makes this correct under both default and null globbing.)
      snapshots=("$RESCUE_DIR"/@.*)
      prune_count=$(( ''${#snapshots[@]} - KEEP ))
      if [ "$prune_count" -gt 0 ]; then
        for old in "''${snapshots[@]:0:prune_count}"; do
          [ -e "$old" ] || continue
          echo "btrfs-rescue: pruning old rescue snapshot: $old"
          btrfs subvolume delete "$old"
        done
      fi

      # Fresh rescue snapshot. CoW: metadata-only, zero data copy, seconds.
      name="@.rescue-$(date +%Y%m%dT%H%M%S)"
      if [ ! -e "$RESCUE_DIR/$name" ]; then
        btrfs subvolume snapshot -r /mnt/btrfs-root/@ "$RESCUE_DIR/$name"
        echo "btrfs-rescue: created $RESCUE_DIR/$name"
      else
        echo "btrfs-rescue: $name already exists (same-second run) — skipping create"
      fi

      # Re-arm append-only, then PROVE it: deleting inside the dir must fail.
      chattr +a "$RESCUE_DIR"
      probe="$RESCUE_DIR/@.append-only-probe"
      btrfs subvolume snapshot -r /mnt/btrfs-root/@ "$probe" >/dev/null 2>&1 || true
      if btrfs subvolume delete "$probe" >/dev/null 2>&1; then
        echo "btrfs-rescue: WARNING — append-only did NOT block subvolume delete (kernel semantics changed?); protection is location-only" >&2
        echo 0 >"$STAMP"
      else
        echo 1 >"$STAMP"
        echo "btrfs-rescue: append-only verified — subvolume deletion inside .rescue is blocked"
        # Remove the probe through a second rotation window.
        chattr -a "$RESCUE_DIR"
        btrfs subvolume delete "$probe" >/dev/null 2>&1 || true
        chattr +a "$RESCUE_DIR"
      fi
    '';
  };
in
{
  options.services.btrfs-rescue = {
    enable = lib.mkEnableOption "rescue snapshots of @ outside btrbk retention (glob-delete survivor, 2026-09-12 incident)";

    keep = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Total rescue snapshots retained after a run (prune keeps keep-1, then creates one).";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "22:30";
      description = "Timer calendar — 22:30 by default, before btrbk-root's 23:00 window.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.btrfs-rescue-snapshot = {
      description = "Rescue snapshot of @ outside btrbk retention (glob-delete survivor)";
      # Boot-run converges the tier on every deploy/reboot (idempotent);
      # the daily timer keeps it fresh between boots.
      wantedBy = [ "multi-user.target" ];
      inherit onFailure;
      startLimitBurst = 3;
      startLimitIntervalSec = 3600;
      unitConfig.RequiresMountsFor = [ "/mnt/btrfs-root" ];
      serviceConfig = lib.mkMerge [
        (serviceOneshotDefaults { })
        (harden {
          MemoryMax = "128M";
          # CAP_SYS_ADMIN: btrfs snapshot/delete ioctls. CAP_LINUX_IMMUTABLE:
          # chattr +a/-a. ProtectSystem=false: snapshot creation must write to
          # the /mnt/btrfs-root mount (balance-service precedent).
          CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_LINUX_IMMUTABLE";
          ProtectSystem = false;
        })
        {
          Type = "oneshot";
          ExecStart = lib.getExe rescueScript;
          StateDirectory = "btrfs-rescue";
          TimeoutStartSec = "10min";
        }
      ];
    };

    systemd.timers.btrfs-rescue-snapshot = {
      description = "Daily rescue snapshot of @ (outside btrbk retention)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        Unit = "btrfs-rescue-snapshot.service";
      };
    };
  };
}
