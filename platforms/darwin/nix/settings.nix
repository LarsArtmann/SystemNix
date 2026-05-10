{lib, ...}: {
  # Import common Nix settings (Darwin-specific overrides below)
  imports = [../../common/nix-settings.nix];

  # Darwin-specific Nix settings overrides
  # Note: Most settings are inherited from ../../common/nix-settings.nix
  # Only Darwin-specific overrides are needed here
  nix.settings = {
    # Darwin override: sandbox disabled due to compatibility issues with macOS
    # Using lib.mkForce to properly override the common module's sandbox = true
    sandbox = lib.mkForce false;
  };
}
