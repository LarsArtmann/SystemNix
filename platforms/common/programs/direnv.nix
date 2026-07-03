# direnv — environment switcher for the shell
# Automatically hooks into Fish, Bash, and Zsh
# nix-direnv enables `use flake` in .envrc with persistent caching
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
}
