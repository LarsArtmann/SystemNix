# LaunchAgent Management for macOS (nix-darwin)
# Declarative service management to replace imperative bash scripts
{
  config,
  pkgs,
  ...
}: let
  # User home directory (from nix-darwin users option - guaranteed to exist)
  userHome = config.users.users.larsartmann.home;
in {
  # LaunchAgents for user-level services
  # Replaces scripts/nix-activitywatch-setup.sh with declarative Nix configuration
  # Using nix-darwin environment.userLaunchAgents option
  environment.userLaunchAgents = {
    # ActivityWatch auto-start service
    # NOTE: Binary is aw-qt, not ActivityWatch (Homebrew-installed app bundle)
    # Note: ActivityWatch is currently installed via Homebrew cask due to macOS Nixpkgs support issues
    "net.activitywatch.ActivityWatch.plist" = {
      enable = true; # Set to false to disable
      text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>net.activitywatch.ActivityWatch</string>
            <key>ProgramArguments</key>
            <array>
                <string>/Applications/ActivityWatch.app/Contents/MacOS/aw-qt</string>
                <string>--no-gui</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
            <key>ProcessType</key>
            <string>Background</string>
            <key>WorkingDirectory</key>
            <string>${userHome}</string>
            <key>StandardOutPath</key>
            <string>${userHome}/.local/share/activitywatch/stdout.log</string>
            <key>StandardErrorPath</key>
            <string>${userHome}/.local/share/activitywatch/stderr.log</string>
        </dict>
        </plist>
      '';
    };

    # ActivityWatch Utilization Watcher
    # Nix-managed system resource monitoring (replaces manual pip install)
    # Connects to ActivityWatch server on localhost:5600
    "net.activitywatch.aw-watcher-utilization.plist" = {
      enable = true;
      text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>net.activitywatch.aw-watcher-utilization</string>
            <key>ProgramArguments</key>
            <array>
                <string>${pkgs.aw-watcher-utilization}/bin/aw-watcher-utilization</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>ProcessType</key>
            <string>Background</string>
            <key>WorkingDirectory</key>
            <string>${userHome}</string>
            <key>StandardOutPath</key>
            <string>${userHome}/.local/share/activitywatch/aw-watcher-utilization.log</string>
            <key>StandardErrorPath</key>
            <string>${userHome}/.local/share/activitywatch/aw-watcher-utilization.error.log</string>
        </dict>
        </plist>
      '';
    };

    # Crush AI provider update service
    # Runs daily at midnight to update AI provider configurations
    "com.larsartmann.crush-update-providers.plist" = {
      enable = true;
      text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.larsartmann.crush-update-providers</string>
            <key>ProgramArguments</key>
            <array>
                <string>/run/current-system/sw/bin/crush</string>
                <string>update-providers</string>
            </array>
            <key>StartCalendarInterval</key>
            <dict>
                <key>Hour</key>
                <integer>0</integer>
                <key>Minute</key>
                <integer>0</integer>
            </dict>
            <key>StandardOutPath</key>
            <string>${userHome}/.local/share/crush/update-providers.log</string>
            <key>StandardErrorPath</key>
            <string>${userHome}/.local/share/crush/update-providers.error.log</string>
        </dict>
        </plist>
      '';
    };
  };
}
