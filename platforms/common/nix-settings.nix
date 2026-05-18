{
  lib,
  pkgs,
  ...
}: {
  # Common Nix settings (platform-agnostic)
  nix = {
    enable = true;
    settings = {
      # Necessary for using flakes on this system
      experimental-features = "nix-command flakes pipe-operators";

      # Enhanced Nix settings for better performance and reliability
      builders-use-substitutes = true;
      connect-timeout = 30;
      fallback = true;
      http-connections = 25;
      log-lines = 25;
      max-free = lib.mkDefault 100000000000; # 100GB — stop GC when 100GB free reached
      min-free = lib.mkDefault 5000000000; # 5GB — trigger GC when only 5GB free
      sandbox = lib.mkDefault (!pkgs.stdenv.isDarwin);
      # Force IPv4-only binary caches
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org/"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      warn-dirty = false;
    };

    # Automatic garbage collection
    gc =
      {
        automatic = true;
        options = "--delete-older-than 3d";
        persistent = true;
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        interval = {Hour = 3;};
      }
      // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
        dates = "daily";
      };

    optimise.automatic = true;

    # Additional Nix configuration for robustness
    checkConfig = true;
    extraOptions = ''
      # Additional Nix options for enhanced reliability
      keep-build-log = true
      keep-failed = false
      build-max-jobs = auto
      cores = 0

      netrc-file = /etc/nix/netrc

      # Flake settings
      accept-flake-config = false
      show-trace = false
      narinfo-cache-negative-ttl = 3600
    '';
  };

  # Note: nixpkgs.config.allowUnfree is set in flake.nix per-system

  # Note: Time zone configuration is platform-specific
  # NixOS: platforms/nixos/system/networking.nix
  # Darwin: Use system location services
  # (Do not set here to avoid conflicts)
}
