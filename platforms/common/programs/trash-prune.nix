# Trash-prune closing loop (2026-11-06, storage.md "trash-prune mechanism"
# row): trash doctrine on this box had NO expiry — 55G of tmp Go caches sat
# parked in ~/.local/share/Trash for a month (2026-10-08 →) with nothing
# ever emptying it, and the owner rows kept deferring the manual
# trash-empty. Weekly `trash-empty 30d` gives trashed items a bounded
# 30-day recovery window while guaranteeing the reclaim lands without a
# human step. The unit journals before/after sizes so the realized-reclaim
# number (storage.md "measure realized reclaim" row) is greppable from
# `journalctl --user -u trash-prune` at every fire.
#
# Scope: the HOME Trash only (~/.local/share/Trash). /data/.Trash-1000 is
# deliberately out of scope — its purge policy is a separate owner
# [decision] row (snapshot pinning makes immediate purge worthless there).
{
  pkgs,
  lib,
  ...
}:
let
  trashPrune = pkgs.writeShellApplication {
    name = "trash-prune-unit";
    runtimeInputs = [
      pkgs.trash-cli
      pkgs.coreutils
      pkgs.gawk
    ];
    text = ''
      trash_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
      if [[ ! -d "$trash_dir" ]]; then
        echo "trash-prune: no Trash dir; nothing to do"
        exit 0
      fi
      before=$(du -sb "$trash_dir" 2>/dev/null | cut -f1)
      before=''${before:-0}
      trash-empty 30d
      after=$(du -sb "$trash_dir" 2>/dev/null | cut -f1)
      after=''${after:-0}
      echo "trash-prune: before=''${before}B after=''${after}B freed=$((before - after))B (30d age expiry)"
    '';
  };
in
{
  systemd.user.services = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    trash-prune = {
      Unit = {
        Description = "Expire trashed items older than 30 days (trash-empty closing loop)";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${trashPrune}/bin/trash-prune-unit";
      };
    };
  };

  systemd.user.timers = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    trash-prune = {
      Timer = {
        OnCalendar = "weekly";
        # Age expiry is idempotent: a missed week while powered off should
        # still catch up — no storm risk, unlike interval watchers.
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
