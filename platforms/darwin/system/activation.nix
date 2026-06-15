{pkgs, ...}: {
  system = {
    primaryUser = "larsartmann";

    activationScripts = {
      # File associations (Darwin-specific)
      setFileAssociations.text = ''
        set -e  # Exit on any error

        echo "Setting file associations..."

        # Sublime Text file associations
        ${pkgs.duti}/bin/duti -s com.sublimetext.4 .txt all
        ${pkgs.duti}/bin/duti -s com.sublimetext.4 .md all
        ${pkgs.duti}/bin/duti -s com.sublimetext.4 .json all
        ${pkgs.duti}/bin/duti -s com.sublimetext.4 .jsonl all
        ${pkgs.duti}/bin/duti -s com.sublimetext.4 .yaml all
        ${pkgs.duti}/bin/duti -s com.sublimetext.4 .yml all
        ${pkgs.duti}/bin/duti -s com.sublimetext.4 .toml all
        ${pkgs.duti}/bin/duti -s com.sublimetext.4 .d2 all

        ${pkgs.duti}/bin/duti -s com.apple.TextEdit .rtf all

        # Verify d2 binary is installed and accessible
        if ! command -v d2 >/dev/null 2>&1; then
          echo "❌ FAILURE: d2 binary not found in PATH" >&2
          exit 1
        fi
        echo "✅ d2 binary verified: $(which d2)"

        # Verify .d2 file association
        verify_d2=$(duti -x .d2 2>/dev/null | head -1 || echo "")
        if [[ "$verify_d2" != *"Sublime"* ]]; then
          echo "❌ FAILURE: .d2 files not associated with Sublime Text" >&2
          echo "   Got: $verify_d2" >&2
          exit 1
        fi
        echo "✅ .d2 files associated with Sublime Text"

        # Verify d2 can parse basic syntax
        if ! echo 'x -> y' | ${pkgs.d2}/bin/d2 - >/dev/null 2>&1; then
          echo "❌ FAILURE: d2 syntax check failed" >&2
          exit 1
        fi
        echo "✅ d2 syntax verification passed"
      '';

      # Register applications with Launch Services (Darwin-specific)
      registerApplications.text = ''
        echo "Registering applications with Launch Services..."
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/Nix Apps"

        echo "Updating Spotlight index for Nix applications..."
        mdimport "/Applications/Nix Apps"
      '';
    };
  };

  # Set Darwin configuration path to the flake location
  environment.darwinConfig = "$HOME/projects/SystemNix";
}
