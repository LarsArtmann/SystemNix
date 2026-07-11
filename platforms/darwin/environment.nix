_: {
  # Import common environment variables module
  # Note: Common variables are applied via Nix module system
  # Darwin-specific additions below are merged with commonEnvVars
  imports = [ ../common/environment/variables.nix ];

  # Darwin-specific environment variables (merged with commonEnvVars)
  # Note: Common variables from variables.nix are applied automatically
  # We use mkMerge to combine common and Darwin-specific variables
  environment.variables = {
    # macOS-specific additions (don't override common settings)
    BROWSER = "helium";
    TERMINAL = "iTerm2";
  };

  # Darwin-specific packages - NOTE: iterm2 now in common/packages/base.nix
  # (platform-scoped with lib.optionals stdenv.isDarwin)
  # No additional system packages needed here
}
