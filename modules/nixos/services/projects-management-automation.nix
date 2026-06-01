# Projects Management Automation — auto-commit daemon
# Watches configured project directories, generates AI commit messages (MiniMax/Groq/OpenAI via go-commit),
# and auto-commits + optionally pushes changes.
{inputs, ...}: {
  flake.nixosModules.projects-management-automation = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure;
    cfg = config.services.projects-management-automation;
    pmaPkg = pkgs.projects-management-automation;
    sopsEnvPath = config.sops.templates."pma-env".path;
    primaryHome = "/home/${config.users.primaryUser}";
  in {
    options.services.projects-management-automation = {
      enable = lib.mkEnableOption "Projects Management Automation auto-commit daemon";

      user = lib.mkOption {
        type = lib.types.str;
        default = config.users.primaryUser;
        description = "User to run PMA as (needs access to git repositories)";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "users";
        description = "Group for the PMA service";
      };

      configPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to PMA service.yaml (null = auto-generate)";
      };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["${primaryHome}/projects"];
        description = "Project directories to watch";
      };

      autoPush = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically push after committing";
      };

      debounceSeconds = lib.mkOption {
        type = lib.types.int;
        default = 5;
        description = "Seconds to debounce file change events";
      };

      minCommitIntervalSeconds = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = "Minimum seconds between commits for the same project";
      };
    };

    config = lib.mkIf cfg.enable {
      # Generate service.yaml if no custom path provided
      environment.etc."projects-management-automation/service.yaml" = lib.mkIf (cfg.configPath == null) {
        text = ''
          mode: active
          commit_strategy: on-change
          debounce_duration: ${toString cfg.debounceSeconds}s
          min_commit_interval: ${toString cfg.minCommitIntervalSeconds}s
          paths:
          ${lib.concatMapStrings (p: "  - ${p}\n") cfg.paths}
          ignore_patterns:
            - .git
            - node_modules
            - vendor
            - .cache
            - dist
            - build
            - .direnv
            - result
            - result-*
          auto_stage: true
          auto_push: ${lib.boolToString cfg.autoPush}
          commit_message_style: detailed
          ai_provider: auto
        '';
        mode = "0644";
      };

      systemd.services.projects-management-automation = {
        description = "Projects Management Automation - Auto-Commit Service";
        documentation = ["https://github.com/LarsArtmann/projects-management-automation"];
        wantedBy = ["multi-user.target"];
        after = ["network-online.target" "sops-nix.service"];
        wants = ["network-online.target" "sops-nix.service"];
        inherit onFailure;

        path = [
          pmaPkg
          pkgs.git
          pkgs.bash
        ];

        serviceConfig =
          {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            ExecStart = "${lib.getExe pmaPkg} service start --config ${
              if cfg.configPath != null
              then cfg.configPath
              else "/etc/projects-management-automation/service.yaml"
            }";
            WorkingDirectory = primaryHome;
            Environment = [
              "HOME=${primaryHome}"
              "PATH=${lib.makeBinPath [pmaPkg pkgs.git pkgs.bash]}"
            ];
            EnvironmentFile = [sopsEnvPath];
            Restart = "on-failure";
            StandardOutput = "journal";
            StandardError = "journal";
            SyslogIdentifier = "pma";
          }
          // serviceDefaults {RestartSec = "5";}
          // harden {
            MemoryMax = "512M";
            ProtectHome = false;
            ReadWritePaths = [primaryHome];
          };
      };
    };
  };
}
