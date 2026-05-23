lib: let
  inherit (lib) mkOption types;
in {
  systemdServiceIdentity = {
    defaultUser,
    defaultGroup ? defaultUser,
    defaultStateDir ? "/var/lib/${defaultUser}",
  }: {
    user = mkOption {
      type = types.str;
      default = defaultUser;
      description = "User account for the service";
    };
    group = mkOption {
      type = types.str;
      default = defaultGroup;
      description = "Group for the service";
    };
    stateDir = mkOption {
      type = types.str;
      default = defaultStateDir;
      description = "State directory for the service";
    };
  };

  servicePort = default: description:
    mkOption {
      type = types.port;
      inherit default description;
    };

  restartDelay = default:
    mkOption {
      type = types.str;
      inherit default;
      description = "Delay before restarting after failure";
    };

  stopTimeout = default:
    mkOption {
      type = types.str;
      inherit default;
      description = "Timeout for graceful shutdown";
    };

  dockerImageTag = default:
    mkOption {
      type =
        types.str
        // {
          check = x: types.str.check x && x != "latest";
          description = types.str.description + " (must not be 'latest')";
        };
      inherit default;
      description = "Pinned Docker image tag (must not be 'latest')";
    };
}
