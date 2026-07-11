{ config, ... }: {
  # macOS system defaults configuration
  system = {
    # Set system state version for nix-darwin
    stateVersion = 6;

    defaults = {
      # Global macOS settings
      NSGlobalDomain = {
        # Keyboard configuration
        KeyRepeat = 2; # Key repeat rate
        InitialKeyRepeat = 15; # Delay before repeat

        # Trackpad configuration
        "com.apple.trackpad.scaling" = 2.0;

        # Dark mode — driven by preferences.appearance.variant
        AppleInterfaceStyle = if config.preferences.appearance.variant == "dark" then "Dark" else null;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
        TrackpadRightClick = true;
      };

      # Finder preferences
      finder = {
        FXPreferredViewStyle = "Nlsv"; # List view
        ShowStatusBar = true;
        ShowPathbar = true;
      };
    };
  };
}
