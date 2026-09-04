{
  lib,
  pkgs,
  ...
}:
{
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
      # 30G GC stop threshold. At the old 100G the stop condition could NEVER
      # be reached on the ~95%-full evo-x2 root, so every GC run deleted
      # through the WHOLE store in one QLC I/O storm (2026-08-21 XFS/nix
      # advisory, docs/status/2026-08-21_21-16 §e.1). 30G still reclaims
      # ample headroom (min-free triggers at 5G) while bounding the sweep.
      max-free = lib.mkDefault 30000000000;
      min-free = lib.mkDefault 5000000000; # 5GB — trigger GC when only 5GB free
      sandbox = lib.mkDefault (!pkgs.stdenv.hostPlatform.isDarwin);
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

      # auto-optimise-store disabled — runs dedup after EVERY build, generating
      # random read I/O that competes with the build itself on QLC NAND.
      # optimise.automatic (daily ~04:00 via nix-optimise.timer) handles dedup
      # once a day during low-activity hours instead.
      auto-optimise-store = false;
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      options = "--delete-older-than 3d";
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      interval = {
        Hour = 3;
      };
    }
    // lib.optionalAttrs (!pkgs.stdenv.hostPlatform.isDarwin) {
      persistent = true;
      dates = "daily";
    };

    optimise.automatic = true;

    # Additional Nix configuration for robustness
    checkConfig = true;
    extraOptions = ''
      # Additional Nix options for enhanced reliability
      keep-build-log = true
      keep-failed = false

      # Build parallelism limits — prevent OOM during Rust/Go compilation
      # max-jobs: max concurrent derivations (not cores per build)
      # cores: max cores per build job (0 = unlimited → causes OOM with 32-core Rust builds)
      # Unified APU: 64 GB shared between CPU and GPU (Ryzen AI MAX+ 395).
      # With GPU AI workloads active, usable RAM is lower than MemTotal suggests.
      # 4 jobs × 8 cores = safe for even the fattest rustc codegen units.
      # Rust builds peak at ~3-4 GB per rustc; 4×8 = 32 parallel ≈ ~64 GB peak.
      # With swap (16 GB) this fits without OOM.
      build-max-jobs = 4
      cores = 8

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
