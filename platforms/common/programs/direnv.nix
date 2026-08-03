# direnv — environment switcher for the shell
# Automatically hooks into Fish, Bash, and Zsh
# nix-direnv enables `use flake` in .envrc with persistent caching
#
# The smart library (direnv-smart-lib.sh) is installed to ~/.config/direnv/lib/
# where direnv auto-loads it before every .envrc. It loads AFTER hm-nix-direnv.sh
# (alphabetically zz > hm) so overrides take effect. It provides:
#   - _nix_add_gcroot override (instant symlinks instead of per-input nix build)
#   - use_go_env helper (auto-detects GOEXPERIMENT + GOPRIVATE from project files)
{
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
    config = {
      load_dotenv = true;
    };
  };

  # Smart direnv library — loaded after nix-direnv (zz-* > hm-*)
  home.file.".config/direnv/lib/zz-smart-nix.sh" = {
    source = ./direnv-smart-lib.sh;
  };
}
