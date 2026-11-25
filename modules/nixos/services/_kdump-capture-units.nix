# Capture-side units of the kdump path: what nixpkgs' boot.crashDump does not
# ship. Moved from platforms/nixos/system/boot.nix on 2026-11-25 so that the
# standalone kdump-capture-path module and its VM test
# (tests/test-kdump-capture-boot.nix) exercise the REAL units.
# The two legs that make the path work live in kdump-capture-path.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.boot.crashDump.enable {
    systemd.services = {
      # ── kdump vmcore retention ────────────────────────────────────────
      # vmcores of a 94 GB machine are multi-GB even filtered+compressed;
      # an unbounded /var/crash on the space-tight root fs would trade one
      # emergency for another. Keep the 2 newest dumps, hard-cap total at
      # 20G (oldest deleted first). Timer at boot + weekly - dumps are rare.
      kdump-retention = {
        description = "Bound /var/crash vmcore retention (2 newest, max 20G total)";
        serviceConfig = {
          Type = "oneshot";
        };
        script = ''
          set -euo pipefail
          CRASH_DIR="/var/crash"
          [ -d "$CRASH_DIR" ] || exit 0

          list_entries() {
            # kdump default layout: timestamp dirs; also tolerate flat vmcore files.
            ${pkgs.findutils}/bin/find "$CRASH_DIR" -mindepth 1 -maxdepth 1 \( -name 'vmcore*' -o -type d \) -printf '%T@ %p\n' | sort -rn
          }

          # Keep the 2 newest entries, delete the rest.
          list_entries | ${pkgs.gawk}/bin/awk 'NR > 2 { $1=""; sub(/^ /, ""); print }' | while read -r old; do
            [ -n "$old" ] && ${pkgs.coreutils}/bin/rm -rf -- "$old" && echo "kdump-retention: removed old dump $old"
          done

          # Hard cap: while total exceeds 20G, delete the oldest remaining entry.
          while :; do
            total_bytes=$(${pkgs.coreutils}/bin/du -sb "$CRASH_DIR" 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $1}')
            [ "''${total_bytes:-0}" -lt 21474836480 ] && break
            oldest=$(list_entries | tail -1 | ${pkgs.gawk}/bin/awk '{ $1=""; sub(/^ /, ""); print }') || true || true
            [ -z "$oldest" ] && break
            ${pkgs.coreutils}/bin/rm -rf -- "$oldest"
            echo "kdump-retention: 20G cap exceeded - removed $oldest"
          done
        '';
      };

      # ── kdump capture-side: write the evidence nixpkgs never writes ────
      # nixpkgs' boot.crashDump ONLY loads the panic kernel (postBootCommands
      # kexec -p) and boots the capture kernel into rescue (cmdline "… 1
      # boot.shell_on_fail") - it ships NO service that reads /proc/vmcore,
      # which is why /var/crash has never existed here despite crashDump
      # since 2026-08-22. This unit runs ONLY in the kexec-ed capture boot
      # (ConditionPathExists=/proc/vmcore - that file exists exclusively in a
      # crash-kexec boot; conditioned no-op otherwise). Budget: the capture
      # boot races the 90 s hardware WDT (watchdogd's last pet dies at panic,
      # the timer runs through kexec), so save the seconds-cheap evidence and
      # reboot - a full 124 GiB vmcore copy is deliberately NOT attempted.
      # kdump-retention above bounds what lands here.
      kdump-save = {
        description = "Save vmcore-dmesg evidence after crash-kexec boot";
        wantedBy = [ "rescue.target" ];
        unitConfig = {
          ConditionPathExists = "/proc/vmcore";
        };
        serviceConfig = {
          Type = "oneshot";
        };
        script = ''
          set -euo pipefail
          ${pkgs.coreutils}/bin/mkdir -p /var/crash
          dest="/var/crash/$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
          ${pkgs.coreutils}/bin/mkdir "$dest"
          if ${pkgs.kexec-tools}/bin/vmcore-dmesg /proc/vmcore > "$dest/vmcore-dmesg.txt"; then
            echo "kdump-save: wrote $dest/vmcore-dmesg.txt"
          else
            echo "kdump-save: vmcore-dmesg FAILED (rc=$?) - check pstore as fallback" >&2
          fi
          ${pkgs.util-linux}/bin/dmesg > "$dest/capture-boot-dmesg.txt" || true
          # Headroom evidence: proves (or refutes) that the capture boot
          # fits the crashkernel reservation (reservedMemory).
          ${pkgs.coreutils}/bin/cp /proc/meminfo "$dest/capture-boot-meminfo.txt" || true
          ${pkgs.coreutils}/bin/cat /proc/uptime > "$dest/capture-boot-uptime.txt" || true
          ${pkgs.coreutils}/bin/sync
          ${pkgs.systemd}/bin/reboot -f
        '';
      };
    };

    # /var/crash must exist from boot: the kdump-save capture unit mkdir -p's
    # at run time (tmpfiles can silently skip re-running on a plain switch -
    # the 2026-11-04 monitor365 class), but the pre-created dir keeps
    # kdump-retention's `[ -d ] || exit 0` honest and makes the evidence
    # location inspectable before the first panic ever lands a dump.
    systemd.tmpfiles.rules = [
      "d /var/crash 0755 root root -"
    ];

    # kdump vmcore retention - bound /var/crash growth (boot + weekly)
    systemd.timers.kdump-retention = {
      description = "Run kdump vmcore retention cleanup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10min";
        OnCalendar = "weekly";
        Persistent = true;
      };
    };
  };
}
