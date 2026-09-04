{
  pkgs,
  lib,
  harden,
  serviceDefaults,
  onFailure,
}:
{
  mkDockerService =
    {
      name,
      composeFile,
      stateDir ? "/var/lib/${name}",
      envTemplate ? null,
      memoryMax ? "2G",
      extraHarden ? { },
      extraServiceConfig ? { },
      preStartCommands ? "",
      after ? [
        "docker.service"
        "sops-nix.service"
        "dnsblockd.service"
      ],
      # docker.service is deliberately in `wants`, NOT `requires`: a Requires=
      # dependency failure at boot (e.g. dockerd's containerd startup timing
      # out once under I/O storms, then self-healing via Restart) fails the
      # compose unit's start JOB with result=dependency — and job failures
      # NEVER re-trigger Restart=always (restarts only apply to executed
      # processes), so the whole stack stays down until a deploy/manual
      # restart (live 2026-08-31: manifest + twenty both). With Wants=, the
      # unit still orders after docker but its own ExecStart failure against
      # a not-yet-ready daemon feeds the normal Restart=always loop, which
      # converges as soon as docker returns.
      requires ? [ ],
      wants ? [
        "docker.service"
        "sops-nix.service"
        "dnsblockd.service"
      ],
      extraTmpfiles ? [ ],
      # backup = {
      #   execStart = ...;   # dump command (caller-owned)
      #   schedule = "...";  # OnCalendar
      #   dir ? "${stateDir}/backup"  # preStart mkdir target; REQUIRED when
      #                              # the dump writes elsewhere (e.g. the
      #                              # mirrored pool) — gates the unit on the
      #                              # mount so it can never fall through to
      #                              # the root fs and contaminate /mnt/pool.
      # }
      backup ? null,
      imagePull ? null,
    }:
    let
      envFlag = if envTemplate != null then "--env-file ${stateDir}/.env" else "";
      envPreStart =
        if envTemplate != null then
          "cp ${envTemplate} ${stateDir}/.env\nchmod 600 ${stateDir}/.env"
        else
          "";
      composeCmd = lib.getExe pkgs.docker-compose;
    in
    {
      tmpfiles = [
        "d ${stateDir} 0755 root root -"
      ]
      ++ lib.optional (
        backup != null && (backup ? dir) && backup.dir != "${stateDir}/backup"
      ) "d ${backup.dir} 0755 root root -"
      ++ lib.optional (backup != null && !(backup ? dir)) "d ${stateDir}/backup 0755 root root -"
      ++ extraTmpfiles;

      services = {
        ${name} = {
          description = name;
          after = after ++ lib.optional (imagePull != null) "${name}-pull.service";
          inherit requires;
          wants = wants ++ lib.optional (imagePull != null) "${name}-pull.service";
          wantedBy = [ "multi-user.target" ];
          inherit onFailure;
          path = [
            pkgs.docker
            pkgs.docker-compose
          ];

          preStart = ''
            ${composeCmd} -f ${composeFile} down --remove-orphans || true
            ${envPreStart}
            ${preStartCommands}
          '';

          serviceConfig = {
            ExecStart = "${composeCmd} ${envFlag} -f ${composeFile} up --remove-orphans";
            ExecStop = "${composeCmd} ${envFlag} -f ${composeFile} down --timeout 30";
            WorkingDirectory = stateDir;
            TimeoutStopSec = "60";
            KillMode = "process";
          }
          // harden (
            {
              MemoryMax = memoryMax;
              ReadWritePaths = [ stateDir ];
            }
            // extraHarden
          )
          // serviceDefaults { }
          // extraServiceConfig;
        };
      }
      // lib.optionalAttrs (imagePull != null) (
        lib.listToAttrs [
          {
            name = "${name}-pull";
            value = {
              description = "Pull ${name} Docker Image";
              after = [
                "docker.service"
                "network-online.target"
                "dnsblockd.service"
              ];
              wants = [
                "docker.service"
                "network-online.target"
                "dnsblockd.service"
              ];
              wantedBy = [ "${name}.service" ];
              path = [ pkgs.docker ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = "${lib.getExe pkgs.docker} pull ${imagePull}";
                TimeoutStartSec = 600;
              };
            };
          }
        ]
      )
      // lib.optionalAttrs (backup != null) (
        lib.listToAttrs [
          {
            name = "${name}-db-backup";
            value = {
              description = "${name} Database Backup";
              after = [
                "${name}.service"
                "docker.service"
              ];
              requires = [ "docker.service" ];
              inherit onFailure;
              unitConfig = lib.optionalAttrs (backup != null && (backup ? dir)) {
                RequiresMountsFor = [ backup.dir ];
              };
              serviceConfig = {
                Type = "oneshot";
                ExecStart = backup.execStart;
                WorkingDirectory = stateDir;
              };
              preStart = "mkdir -p ${backup.dir or "${stateDir}/backup"}";
            };
          }
        ]
      );

      timers = lib.optionalAttrs (backup != null) (
        lib.listToAttrs [
          {
            name = "${name}-db-backup";
            value = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = backup.schedule or "daily";
                Persistent = true;
                RandomizedDelaySec = "30m";
              };
            };
          }
        ]
      );
    };
}
