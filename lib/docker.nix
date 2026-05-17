{pkgs, lib, harden, serviceDefaults}: {
  mkDockerService = {
    name,
    composeFile,
    stateDir ? "/var/lib/${name}",
    envTemplate ? null,
    memoryMax ? "2G",
    extraHarden ? {},
    extraServiceConfig ? {},
    preStartCommands ? "",
    after ? ["docker.service" "sops-nix.service"],
    requires ? ["docker.service"],
    wants ? ["sops-nix.service"],
    extraTmpfiles ? [],
    backup ? null,
  }: let
    envFlag =
      if envTemplate != null
      then "--env-file ${stateDir}/.env"
      else "";
    envPreStart =
      if envTemplate != null
      then "cp ${envTemplate} ${stateDir}/.env\nchmod 600 ${stateDir}/.env"
      else "";
    composeCmd = "${pkgs.docker-compose}/bin/docker-compose";
  in {
    tmpfiles =
      ["d ${stateDir} 0755 root root -"]
      ++ lib.optional (backup != null) "d ${stateDir}/backup 0755 root root -"
      ++ extraTmpfiles;

    services =
      {
        ${name} = {
          description = name;
          inherit after requires wants;
          wantedBy = ["multi-user.target"];
          onFailure = ["notify-failure@%n.service"];
          path = [pkgs.docker pkgs.docker-compose];

          preStart = ''
            ${composeCmd} -f ${composeFile} down --remove-orphans || true
            ${envPreStart}
            ${preStartCommands}
          '';

          serviceConfig =
            {
              ExecStart = "${composeCmd} ${envFlag} -f ${composeFile} up --remove-orphans";
              ExecStop = "${composeCmd} ${envFlag} -f ${composeFile} down --timeout 30";
              WorkingDirectory = stateDir;
              TimeoutStopSec = "60";
              KillMode = "process";
            }
            // harden (
              {
                MemoryMax = memoryMax;
                ReadWritePaths = [stateDir];
              }
              // extraHarden
            )
            // serviceDefaults {}
            // extraServiceConfig;
        };
      }
      // lib.optionalAttrs (backup != null) (
        lib.listToAttrs [{
          name = "${name}-db-backup";
          value = {
            description = "${name} Database Backup";
            after = ["${name}.service"];
            requires = ["docker.service"];
            onFailure = ["notify-failure@%n.service"];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = backup.execStart;
              WorkingDirectory = stateDir;
            };
            preStart = "mkdir -p ${stateDir}/backup";
          };
        }]
      );

    timers =
      lib.optionalAttrs (backup != null) (
        lib.listToAttrs [{
          name = "${name}-db-backup";
          value = {
            wantedBy = ["timers.target"];
            timerConfig = {
              OnCalendar = backup.schedule or "daily";
              Persistent = true;
              RandomizedDelaySec = "30m";
            };
          };
        }]
      );
  };
}
