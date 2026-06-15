# Chromium-based browser configuration with extension management
# Note: Home Manager's extension management works with Chromium, Brave, Vivaldi,
# but NOT with Google Chrome due to Google Chrome's enterprise policy restrictions.
{
  pkgs,
  lib,
  ...
}: let
  ytShortsBlocker = (import ../browser-extensions.nix).ytShortsBlocker;
in {
  # Chromium browser with declarative extension management
  # NOTE: This Home Manager module is only used on Darwin (macOS).
  # On NixOS, extension management is handled system-wide via programs.chromium
  # in platforms/nixos/programs/chrome.nix
  programs.chromium = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    package = pkgs.brave; # Use Brave as primary Chromium-based browser for extension support

    # Command-line arguments for performance and privacy
    commandLineArgs = [
      "--enable-features=AcceleratedVideoEncoder,VaapiVideoDecoder"
      "--ignore-gpu-blocklist"
      "--enable-zero-copy"
      "--disable-background-timer-throttling"
      "--disable-backgrounding-occluded-windows"
      "--disable-renderer-backgrounding"
    ];

    # Extensions to install declaratively
    extensions = [
      # YouTube Shorts Blocker - hides Shorts from homepage, subscriptions, search
      {inherit (ytShortsBlocker) id;}

      # uBlock Origin - ad blocker (optional, uncomment if desired)
      # { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; }

      # Dark Reader - dark mode for all websites (optional)
      # { id = "eimadpbcbfnmbkopoojfkbdbjgkahlgl"; }
    ];

    # Dictionaries for spell checking
    dictionaries = [
      pkgs.hunspellDictsChromium.en_US
    ];
  };

  # Alternative: Configure ungoogled-chromium instead of Brave
  # programs.chromium.package = pkgs.ungoogled-chromium;

  # Note: Google Chrome extension management via Nix is limited.
  # Chrome requires enterprise policies for forced extension installation,
  # which are system-level and managed via NixOS/nix-darwin modules, not Home Manager.
  #
  # For Google Chrome, you have these options:
  # 1. Install extensions manually from Chrome Web Store
  # 2. Use system-level Chrome policies (NixOS/nix-darwin)
  # 3. Use a Chromium-based browser (Brave, ungoogled-chromium) with Home Manager
}
