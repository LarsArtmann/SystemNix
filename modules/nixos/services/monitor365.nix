# Monitor365 device monitoring agent with ActivityWatch integration
_: {
  flake.nixosModules.monitor365 = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.monitor365;
    inherit (config.users) primaryUser;
    sd = import ../../../lib/default.nix lib;
    inherit (sd) serviceDefaultsUser hardenUser mkStateDir ports;

    runtimeDeps = with pkgs; [
      xdotool
      xprintidle
      scrot
      networkmanager
      lm_sensors
      bluez
      util-linux
      coreutils
      procps
    ];

    runtimePath = lib.makeBinPath runtimeDeps;

    mkCollectorEnabled = enabled: ''
      enabled = ${lib.boolToString enabled}
    '';

    mkCollector = enabled: interval: ''
      enabled = ${lib.boolToString enabled}
      interval_seconds = ${toString interval}
    '';

    authTokenFile = config.sops.secrets.cloud_auth_token.path;
    sopsEnvPath = config.sops.templates."monitor365-env".path;

    agentConfig = pkgs.writeText "monitor365-config.toml" ''
      [device]
      id = "${cfg.device.id}"
      name = "${cfg.device.name}"
      type = "${cfg.device.type}"
      os_family = "${cfg.device.osFamily}"

      [collectors.location]
      ${mkCollector cfg.collectors.location cfg.collectors.locationInterval}

      [collectors.screenshots]
      ${mkCollector cfg.collectors.screenshot cfg.collectors.screenshotInterval}
      quality = ${toString cfg.collectors.screenshotQuality}
      ${lib.optionalString (cfg.collectors.screenshotMaxDimension != null) ''
        max_dimension = ${toString cfg.collectors.screenshotMaxDimension}
      ''}

      [collectors.camera]
      ${mkCollector cfg.collectors.camera cfg.collectors.cameraInterval}
      camera = "${cfg.collectors.cameraSelection}"
      ${lib.optionalString (cfg.collectors.cameraMaxDimension != null) ''
        max_dimension = ${toString cfg.collectors.cameraMaxDimension}
      ''}

      [collectors.app_usage]
      ${mkCollectorEnabled cfg.collectors.window}

      [collectors.keystrokes]
      ${mkCollectorEnabled cfg.collectors.keystroke}

      [collectors.mouse]
      ${mkCollectorEnabled cfg.collectors.mouse}

      [collectors.network]
      ${mkCollectorEnabled cfg.collectors.network}

      [collectors.battery]
      ${mkCollectorEnabled cfg.collectors.battery}

      [collectors.notifications]
      ${mkCollectorEnabled cfg.collectors.notifications}

      [collectors.afk_status]
      ${mkCollectorEnabled cfg.collectors.afk}
      idle_threshold_seconds = ${toString cfg.collectors.afkIdleThreshold}

      [collectors.fs_event]
      ${mkCollector cfg.collectors.fsEvent cfg.collectors.fsEventInterval}
      watch_paths = ["${builtins.concatStringsSep ''", "'' cfg.collectors.fsEventWatchPaths}"]
      recursive = ${lib.boolToString cfg.collectors.fsEventRecursive}

      [collectors.clipboard]
      ${mkCollectorEnabled cfg.collectors.clipboard}

      [collectors.bluetooth]
      ${mkCollector cfg.collectors.bluetooth cfg.collectors.bluetoothInterval}

      [collectors.sensor]
      ${mkCollector cfg.collectors.sensor cfg.collectors.sensorInterval}

      [collectors.wifi_scan]
      ${mkCollector cfg.collectors.wifi cfg.collectors.wifiInterval}

      [collectors.process]
      ${mkCollector cfg.collectors.process cfg.collectors.processInterval}

      [collectors.system_info]
      ${mkCollector cfg.collectors.systemInfo cfg.collectors.systemInfoInterval}
      collect_fingerprint = ${lib.boolToString cfg.collectors.systemInfoFingerprint}

      [storage]
      path = "${cfg.home}"
      retention_days = ${toString cfg.retentionDays}
      encryption = ${lib.boolToString cfg.storage.encryption}
      compression_level = ${toString cfg.storage.compressionLevel}
      ${lib.optionalString (cfg.storage.maxSizeMb != null) ''
        max_size_mb = ${toString cfg.storage.maxSizeMb}
      ''}

      ${lib.optionalString (cfg.cloud.endpoint != "") ''
        [cloud]
        endpoint = "${cfg.cloud.endpoint}"
        sync_interval_seconds = ${toString cfg.cloud.syncInterval}
        batch_size = ${toString cfg.cloud.batchSize}
        ${lib.optionalString (cfg.cloud.persistencePath != null) ''
          persistence_path = "${cfg.cloud.persistencePath}"
        ''}
        ${lib.optionalString (cfg.cloud.caCertPath != null) ''
          ca_cert_path = "${cfg.cloud.caCertPath}"
        ''}
        ${lib.optionalString (cfg.cloud.clientCertPath != null) ''
          client_cert_path = "${cfg.cloud.clientCertPath}"
        ''}
        ${lib.optionalString (cfg.cloud.clientKeyPath != null) ''
          client_key_path = "${cfg.cloud.clientKeyPath}"
        ''}
      ''}

      [activitywatch]
      enabled = ${lib.boolToString cfg.activityWatch.enable}
      host = "${cfg.activityWatch.host}"
      port = ${toString cfg.activityWatch.port}

      [logging]
      level = "${cfg.logging.level}"
      format = "${cfg.logging.format}"
      ${lib.optionalString (cfg.logging.file != null) ''
        file = "${cfg.logging.file}"
      ''}

      [metrics]
      enabled = ${lib.boolToString cfg.metrics.enable}
      bind_address = "${cfg.metrics.bindAddress}"

      ${lib.optionalString cfg.otel.enable ''
        [otel]
        enabled = true
        otlp_endpoint = "${cfg.otel.otlpEndpoint}"
        service_name = "${cfg.otel.serviceName}"
        sampling_ratio = ${toString cfg.otel.samplingRatio}
      ''}

      ${lib.optionalString (cfg.pluginDir != null) ''
        plugin_dir = "${cfg.pluginDir}"
      ''}
    '';

    serverConfig = pkgs.writeText "monitor365-server.toml" ''
      database_url = "${cfg.server.databaseUrl}"
      listen_addr = "${cfg.server.listenAddr}"
      pool_size = ${toString cfg.server.poolSize}
      request_timeout_secs = ${toString cfg.server.requestTimeoutSecs}
      rate_limit_max_requests = ${toString cfg.server.rateLimitMaxRequests}
      rate_limit_window_secs = ${toString cfg.server.rateLimitWindowSecs}
      access_token_ttl_secs = ${toString cfg.server.accessTokenTtlSecs}
      refresh_token_ttl_secs = ${toString cfg.server.refreshTokenTtlSecs}
      device_stale_minutes = ${toString cfg.server.deviceStaleMinutes}
      ${lib.optionalString (cfg.server.corsOrigins != []) ''
        cors_origins = [${builtins.concatStringsSep ", " (map (o: "\"${o}\"") cfg.server.corsOrigins)}]
      ''}
    '';

    serverStateDir = "${cfg.home}/server";
  in {
    options.services.monitor365 = {
      enable = lib.mkEnableOption "Monitor365 device monitoring agent";

      user = lib.mkOption {
        type = lib.types.str;
        default = primaryUser;
        description = "User account for the monitoring agent";
      };

      home = lib.mkOption {
        type = lib.types.str;
        default = "/home/${config.services.monitor365.user}/.local/share/monitor365";
        defaultText = "/home/<user>/.local/share/monitor365";
        description = "Data directory for event storage";
      };

      configPath = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to custom config.toml. Overrides generated config.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.monitor365;
        description = "Monitor365 package to use (agent binary `monitor365`)";
      };

      device = lib.mkOption {
        type = lib.types.submodule {
          options = {
            id = lib.mkOption {
              type = lib.types.str;
              default = config.networking.hostName;
              description = "Unique device identifier";
            };
            name = lib.mkOption {
              type = lib.types.str;
              default = config.networking.hostName;
              description = "Human-readable device name";
            };
            type = lib.mkOption {
              type = lib.types.enum ["laptop" "desktop" "server" "phone" "tablet"];
              default = "desktop";
              description = "Device type";
            };
            osFamily = lib.mkOption {
              type = lib.types.str;
              default = "linux";
              description = "Operating system family";
            };
          };
        };
        default = {};
        description = "Device identity configuration";
      };

      collectors = lib.mkOption {
        type = lib.types.submodule {
          freeformType = with lib.types; attrsOf anything;
          options = {
            battery = lib.mkEnableOption "battery monitoring" // {default = true;};
            network = lib.mkEnableOption "network monitoring" // {default = true;};
            wifi = lib.mkEnableOption "WiFi scanning" // {default = true;};
            bluetooth = lib.mkEnableOption "Bluetooth monitoring" // {default = true;};
            window = lib.mkEnableOption "window/app usage tracking" // {default = true;};
            process = lib.mkEnableOption "process monitoring" // {default = true;};
            afk = lib.mkEnableOption "AFK/idle detection" // {default = true;};
            sensor = lib.mkEnableOption "hardware sensor monitoring" // {default = true;};
            location = lib.mkEnableOption "location tracking" // {default = false;};
            screenshot = lib.mkEnableOption "screenshot capture" // {default = false;};
            keystroke = lib.mkEnableOption "keystroke logging" // {default = false;};
            mouse = lib.mkEnableOption "mouse activity tracking" // {default = false;};
            camera = lib.mkEnableOption "camera capture" // {default = false;};
            clipboard = lib.mkEnableOption "clipboard monitoring" // {default = false;};
            notifications = lib.mkEnableOption "notification tracking" // {default = false;};
            fsEvent = lib.mkEnableOption "filesystem event watching" // {default = false;};
            systemInfo = lib.mkEnableOption "system info collection" // {default = true;};

            locationInterval = lib.mkOption {
              type = lib.types.ints.positive;
              default = 60;
              description = "Location update interval (seconds)";
            };
            screenshotInterval = lib.mkOption {
              type = lib.types.ints.positive;
              default = 300;
              description = "Screenshot capture interval (seconds)";
            };
            screenshotQuality = lib.mkOption {
              type = lib.types.ints.between 1 100;
              default = 80;
              description = "JPEG quality (1-100)";
            };
            screenshotMaxDimension = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              default = null;
              description = "Optional max dimension to resize screenshots";
            };
            cameraInterval = lib.mkOption {
              type = lib.types.ints.positive;
              default = 300;
              description = "Camera capture interval (seconds)";
            };
            cameraSelection = lib.mkOption {
              type = lib.types.enum ["auto" "front" "back"];
              default = "auto";
              description = "Camera selection";
            };
            cameraMaxDimension = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              default = null;
              description = "Optional max dimension for camera images";
            };
            afkIdleThreshold = lib.mkOption {
              type = lib.types.ints.positive;
              default = 180;
              description = "AFK idle threshold (seconds)";
            };
            fsEventInterval = lib.mkOption {
              type = lib.types.ints.positive;
              default = 1;
              description = "Filesystem event poll interval (seconds)";
            };
            fsEventWatchPaths = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = ["~/Documents"];
              description = "Paths to watch for filesystem events";
            };
            fsEventRecursive = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Watch paths recursively";
            };
            bluetoothInterval = lib.mkOption {
              type = lib.types.ints.positive;
              default = 10;
              description = "Bluetooth scan interval (seconds)";
            };
            sensorInterval = lib.mkOption {
              type = lib.types.ints.positive;
              default = 30;
              description = "Sensor poll interval (seconds)";
            };
            wifiInterval = lib.mkOption {
              type = lib.types.ints.positive;
              default = 60;
              description = "WiFi scan interval (seconds)";
            };
            processInterval = lib.mkOption {
              type = lib.types.ints.positive;
              default = 10;
              description = "Process monitoring interval (seconds)";
            };
            systemInfoInterval = lib.mkOption {
              type = lib.types.ints.positive;
              default = 60;
              description = "System info collection interval (seconds)";
            };
            systemInfoFingerprint = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Collect hardware fingerprint (serial, MAC, IPs)";
            };
          };
        };
        default = {};
        description = "Collector enablement and per-collector settings";
      };

      activityWatch = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "ActivityWatch integration" // {default = true;};
            host = lib.mkOption {
              type = lib.types.str;
              default = "localhost";
              description = "ActivityWatch API hostname";
            };
            port = lib.mkOption {
              type = lib.types.port;
              default = ports.activitywatch;
              description = "ActivityWatch API port";
            };
          };
        };
        default = {};
        description = "ActivityWatch integration settings";
      };

      storage = lib.mkOption {
        type = lib.types.submodule {
          options = {
            encryption = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable local event store encryption";
            };
            compressionLevel = lib.mkOption {
              type = lib.types.ints.between 0 9;
              default = 6;
              description = "Event store compression level (0-9)";
            };
            maxSizeMb = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              default = null;
              description = "Optional max storage size in MiB";
            };
          };
        };
        default = {};
        description = "Storage settings";
      };

      cloud = lib.mkOption {
        type = lib.types.submodule {
          options = {
            endpoint = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Cloud sync endpoint URL (e.g. https://monitor.home.lan). Leave empty to disable cloud sync.";
            };
            syncInterval = lib.mkOption {
              type = lib.types.ints.positive;
              default = 60;
              description = "Cloud sync interval (seconds)";
            };
            batchSize = lib.mkOption {
              type = lib.types.ints.positive;
              default = 100;
              description = "Events per batch upload";
            };
            persistencePath = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Path for offline queue persistence";
            };
            caCertPath = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Custom CA certificate path";
            };
            clientCertPath = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "mTLS client certificate path";
            };
            clientKeyPath = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "mTLS client key path";
            };
          };
        };
        default = {};
        description = "Cloud sync configuration";
      };

      logging = lib.mkOption {
        type = lib.types.submodule {
          options = {
            level = lib.mkOption {
              type = lib.types.enum ["trace" "debug" "info" "warn" "error"];
              default = "info";
              description = "Log verbosity level";
            };
            format = lib.mkOption {
              type = lib.types.enum ["pretty" "json" "compact"];
              default = "pretty";
              description = "Log output format";
            };
            file = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional log file path";
            };
          };
        };
        default = {};
        description = "Logging configuration";
      };

      metrics = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "Prometheus metrics endpoint" // {default = false;};
            bindAddress = lib.mkOption {
              type = lib.types.str;
              default = "127.0.0.1:${toString ports.monitor365-metrics}";
              description = "Address to bind the Prometheus metrics endpoint";
            };
          };
        };
        default = {};
        description = "Prometheus metrics configuration";
      };

      otel = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable OpenTelemetry trace export (requires build with --features otel)";
            };
            otlpEndpoint = lib.mkOption {
              type = lib.types.str;
              default = "http://localhost:${toString ports.signoz-otlp-grpc}";
              description = "OTLP gRPC endpoint";
            };
            serviceName = lib.mkOption {
              type = lib.types.str;
              default = "monitor365";
              description = "Service name in traces";
            };
            samplingRatio = lib.mkOption {
              type = lib.types.numbers.between 0.0 1.0;
              default = 1.0;
              description = "Trace sampling ratio (0.0 = none, 1.0 = all)";
            };
          };
        };
        default = {};
        description = "OpenTelemetry configuration";
      };

      pluginDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Native plugin directory";
      };

      retentionDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 90;
        description = "Days to retain events before cleanup";
      };

      server = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "Monitor365 server (dashboard + API)" // {default = false;};

            package = lib.mkOption {
              type = lib.types.package;
              default = pkgs.monitor365-server or pkgs.monitor365;
              description = "Monitor365 server package";
            };

            listenAddr = lib.mkOption {
              type = lib.types.str;
              default = "0.0.0.0:${toString ports.monitor365-server}";
              description = "Address to bind the server to";
            };

            databaseUrl = lib.mkOption {
              type = lib.types.str;
              default = "sqlite:///${cfg.home}/server/monitor365.db";
              description = "Database connection URL";
            };

            corsOrigins = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "Allowed CORS origins (e.g. [\"http://localhost:${toString ports.monitor365-server}\"])";
            };

            poolSize = lib.mkOption {
              type = lib.types.ints.positive;
              default = 5;
              description = "Database connection pool size";
            };

            requestTimeoutSecs = lib.mkOption {
              type = lib.types.ints.positive;
              default = 30;
              description = "Request timeout in seconds";
            };

            rateLimitMaxRequests = lib.mkOption {
              type = lib.types.ints.positive;
              default = 100;
              description = "Max requests per rate-limit window";
            };

            rateLimitWindowSecs = lib.mkOption {
              type = lib.types.ints.positive;
              default = 60;
              description = "Rate-limit window in seconds";
            };

            accessTokenTtlSecs = lib.mkOption {
              type = lib.types.ints.positive;
              default = 3600;
              description = "Access token TTL in seconds";
            };

            refreshTokenTtlSecs = lib.mkOption {
              type = lib.types.ints.positive;
              default = 604800;
              description = "Refresh token TTL in seconds";
            };

            deviceStaleMinutes = lib.mkOption {
              type = lib.types.ints.positive;
              default = 5;
              description = "Minutes before a device is marked offline";
            };
          };
        };
        default = {};
        description = "Monitor365 server (dashboard/API) configuration";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [cfg.package];

      systemd.tmpfiles.rules =
        [
          (mkStateDir cfg.home "0750" cfg.user "users")
        ]
        ++ lib.optionals cfg.server.enable [
          (mkStateDir serverStateDir "0750" cfg.user "users")
        ];

      environment.etc."monitor365/config.toml".source =
        if cfg.configPath != null
        then cfg.configPath
        else agentConfig;

      home-manager.users.${cfg.user} = lib.mkMerge [
        {
          xdg.configFile."monitor365/config.toml".source =
            if cfg.configPath != null
            then cfg.configPath
            else agentConfig;

          systemd.user.services.monitor365 = {
            Unit = {
              Description = "Monitor365 Device Monitoring Agent";
              After = ["network.target" "graphical-session.target" "sops-nix.service"];
              Wants = ["network.target"];
              PartOf = ["graphical-session.target"];
              StartLimitIntervalSec = 600;
              StartLimitBurst = 5;
            };

            Service =
              serviceDefaultsUser {RestartSec = "10";}
              // hardenUser {MemoryMax = "256M";}
              // {
                Type = "simple";
                ExecStartPre = let
                  injectAuth = pkgs.writeShellApplication {
                    name = "monitor365-inject-auth";
                    runtimeInputs = [pkgs.coreutils pkgs.gnused pkgs.gnugrep];
                    text = ''
                      CFG_DIR="$XDG_RUNTIME_DIR/monitor365"
                      mkdir -p "$CFG_DIR"
                      cp ${agentConfig} "$CFG_DIR/config.toml"
                      if [ -f "${authTokenFile}" ] && [ -s "${authTokenFile}" ]; then
                        TOKEN=$(cat "${authTokenFile}")
                        if grep -q '^\[cloud\]' "$CFG_DIR/config.toml"; then
                          sed -i "/^\[cloud\]/a auth_token = \"$TOKEN\"" "$CFG_DIR/config.toml"
                        else
                          printf '\n[cloud]\nauth_token = "%s"\n' "$TOKEN" >> "$CFG_DIR/config.toml"
                        fi
                      fi
                    '';
                  };
                in ["${lib.getExe injectAuth}"];
                ExecStart = "${lib.getExe cfg.package} --config \$XDG_RUNTIME_DIR/monitor365/config.toml run";
                WorkingDirectory = cfg.home;
                KillMode = "mixed";
                TimeoutStopSec = "30";
                StandardOutput = "journal";
                StandardError = "journal";

                Environment = [
                  "PATH=${runtimePath}:/run/wrappers/bin:%h/.nix-profile/bin:/run/current-system/sw/bin"
                  "DISPLAY=:0"
                ];
                EnvironmentFile = [sopsEnvPath];
              };

            Install = {
              WantedBy = ["graphical-session.target"];
            };
          };
        }
        (lib.mkIf cfg.server.enable {
          xdg.configFile."monitor365/server.toml".source = serverConfig;

          systemd.user.services.monitor365-server = {
            Unit = {
              Description = "Monitor365 Dashboard Server";
              After = ["network.target"];
              Wants = ["network.target"];
              StartLimitIntervalSec = 600;
              StartLimitBurst = 5;
            };

            Service =
              serviceDefaultsUser {RestartSec = "10";}
              // hardenUser {MemoryMax = "256M";}
              // {
                Type = "simple";
                ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${serverStateDir}";
                ExecStart = "${lib.getExe' cfg.server.package "monitor365-server"} --config ${serverConfig}";
                WorkingDirectory = serverStateDir;
                KillMode = "mixed";
                TimeoutStopSec = "30";
                StandardOutput = "journal";
                StandardError = "journal";

                Environment = [
                  "MONITOR365_SERVER__DATABASE_URL=${cfg.server.databaseUrl}"
                  "MONITOR365_SERVER__LISTEN_ADDR=${cfg.server.listenAddr}"
                  "MONITOR365_SERVER__POOL_SIZE=${toString cfg.server.poolSize}"
                ];
                EnvironmentFile = [sopsEnvPath];
              };

            Install = {
              WantedBy = ["default.target"];
            };
          };
        })
      ];
    };
  };
}
