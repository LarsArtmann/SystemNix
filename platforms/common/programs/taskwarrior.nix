{
  pkgs,
  lib,
  config,
  ...
}: let
  machineSeed = "${config.home.username}@${pkgs.stdenv.hostPlatform.system}";

  toVariantNibble = {
    "0" = "8";
    "1" = "9";
    "2" = "a";
    "3" = "b";
    "4" = "8";
    "5" = "9";
    "6" = "a";
    "7" = "b";
    "8" = "8";
    "9" = "9";
    "a" = "a";
    "b" = "b";
    "c" = "8";
    "d" = "9";
    "e" = "a";
    "f" = "b";
  };

  deriveUuid = seed: let
    h = builtins.hashString "sha256" "taskchampion-${seed}";
    p1 = lib.strings.substring 0 8 h;
    p2 = lib.strings.substring 8 4 h;
    p3 = builtins.substring 0 3 (lib.strings.substring 12 4 h) + "4";
    p4raw = lib.strings.substring 16 4 h;
    p4 = toVariantNibble.${builtins.substring 0 1 p4raw} + builtins.substring 1 3 p4raw;
    p5 = lib.strings.substring 20 12 h;
  in "${p1}-${p2}-${p3}-${p4}-${p5}";

  syncEncryptionSecret = builtins.hashString "sha256" "taskchampion-sync-encryption-systemnix";
in {
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3.overrideAttrs {
      cmakeFlags = [
        (pkgs.lib.cmakeBool "SYSTEM_CORROSION" true)
        (pkgs.lib.cmakeBool "ENABLE_TLS_NATIVE_ROOTS" true)
      ];
    };

    config = {
      confirmation = false;
      recurrence = {
        enabled = "yes";
        confirmation = false;
      };

      report = {
        minimal = {
          filter = "status:pending";
          columns = "id,project,tags,start.age,description";
          labels = "ID,Project,Tags,Started,Description";
          sort = "project+,description+";
        };

        next = {
          filter = "status:pending limit:20";
          columns = "id,start.age,entry.age,project,tags,recur,wait.remaining,scheduled,urgency,due,description";
          labels = "ID,Active,Age,Project,Tag,Recur,Wait,Sched,Urg,Due,Description";
          sort = "urgency-";
        };

        agent = {
          filter = "status:pending +agent limit:50";
          columns = "id,source,start.age,description";
          labels = "ID,Source,Active,Description";
          sort = "entry+";
        };
      };

      uda.source.type = "string";
      uda.source.label = "Source";

      sync = {
        server = {
          url = "https://tasks.home.lan";
          client_id = deriveUuid machineSeed;
        };
        encryption_secret = syncEncryptionSecret;
      };
    };

    extraConfig = ''
      # Catppuccin Mocha color theme (xterm-256 palette)
      color.title=on color0
      color.header=on color0
      color.footnote=on color0
      color.message=on color0
      color.error=on color0
      color.debug=on color0

      color.overdue=color203
      color.due.today=color222
      color.due=color222
      color.scheduled=color115
      color.active=color147
      color.recurring=color183
      color.blocked=color203
      color.blocking=color216

      color.tagged=on color238
      color.tag.none=
      color.project.none=

      color.uda.priority.H=color203
      color.uda.priority.M=color222
      color.uda.priority.L=color115

      color.summary.background=on color236
      color.summary.bar=on color75
      color.history.add=color115
      color.history.done=color115
      color.history.delete=color203

      color.burndown.pending=color75
      color.burndown.done=color115
      color.burndown.started=color216

      color.sync.added=color115
      color.sync.changed=color222
      color.sync.rejected=color203

      color.calendar.today=color232 on color222
      color.calendar.due=color232 on color203
      color.calendar.overdue=color232 on color203
      color.calendar.weekend=color244
      color.calendar.holiday=color183

      color.report.minimal.filter=on color242
      color.report.next.filter=on color242
      color.report.agent.filter=on color242

      color.alternate=on color238
    '';
  };

  systemd.user = lib.mkIf pkgs.stdenv.isLinux {
    services = {
      taskwarrior-backup = {
        Unit = {
          Description = "Taskwarrior backup — export all tasks as JSON";
          OnFailure = ["taskwarrior-backup-failure.service"];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.writeShellScript "taskwarrior-backup" ''
            set -euo pipefail
            BACKUP_DIR="$HOME/backups/taskwarrior"
            mkdir -p "$BACKUP_DIR"
            STAMP="$(${pkgs.coreutils}/bin/date '+%Y-%m-%d_%H-%M-%S')"
            ${pkgs.taskwarrior3}/bin/task export > "$BACKUP_DIR/tasks-$STAMP.json"
            ${pkgs.findutils}/bin/find "$BACKUP_DIR" -name "tasks-*.json" -mtime +30 -delete
            echo "taskwarrior-backup: exported to tasks-$STAMP.json"
          ''}";
        };
      };
      taskwarrior-backup-failure = {
        Unit = {
          Description = "Notify on taskwarrior backup failure";
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.libnotify}/bin/notify-send -u critical 'Taskwarrior backup failed' 'Check systemctl --user status taskwarrior-backup'";
        };
      };
    };
    timers.taskwarrior-backup = {
      Unit = {
        Description = "Daily Taskwarrior backup timer";
      };
      Timer = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
      Install = {
        WantedBy = ["timers.target"];
      };
    };
  };
}
