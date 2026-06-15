# macOS Chrome/Chromium policy configuration for extension management
# This configures system-wide Chrome policies via nix-darwin
{pkgs, ...}: let
  inherit (import ../../common/browser-extensions.nix) ytShortsBlocker;
  chromeWebStoreUpdateUrl = ytShortsBlocker.updateUrl;
in {
  # Note: nix-darwin has limited Chrome policy support compared to NixOS
  # For full enterprise policy management on macOS, you typically need:
  # 1. A Mobile Device Management (MDM) solution
  # 2. Manual profile installation
  # 3. Or use a Chromium-based browser with Home Manager instead

  # Alternative approach: Create a Chrome policy file
  # This requires Chrome to be launched with specific flags or via managed preferences

  # Create a helper script to install Chrome policies (manual approach)
  environment.etc."chrome/policies/managed/extensions.json".text = builtins.toJSON {
    ExtensionSettings = {
      # Default: allow all extensions (change to "blocked" for more restrictive)
      "*" = {
        installation_mode = "allowed";
      };
      # Force install YouTube Shorts Blocker
      "${ytShortsBlocker.id}" = {
        installation_mode = "force_installed";
        update_url = chromeWebStoreUpdateUrl;
        toolbar_pin = "force_pinned";
      };
    };
    # Security policies
    BrowserSignin = 0;
    SyncDisabled = true;
    PasswordManagerEnabled = false;
    SafeBrowsingEnabled = true;
    HttpsOnlyMode = "force_enabled";
    # Keep Manifest V2 extensions working
    ExtensionManifestV2Availability = 2;
  };

  # Create a script to help users manually apply the policy
  environment.systemPackages = [
    (pkgs.writeScriptBin "chrome-apply-policies" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      CHROME_POLICY_DIR="/Library/Application Support/Google/Chrome"
      MANAGED_DIR="$CHROME_POLICY_DIR/policies/managed"

      echo "Applying Chrome policies for extension management..."

      if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root (use sudo)"
        exit 1
      fi

      mkdir -p "$MANAGED_DIR"
      cp /etc/chrome/policies/managed/extensions.json "$MANAGED_DIR/extensions.json"

      echo "✓ Chrome policies applied successfully"
      echo "  Policy file: $MANAGED_DIR/extensions.json"
      echo ""
      echo "Note: You need to restart Chrome for changes to take effect."
      echo "      If extensions don't appear, check chrome://policy in your browser."
    '')
  ];

  # Documentation for manual setup
  # Users can also manually copy the policy file if they prefer
}
