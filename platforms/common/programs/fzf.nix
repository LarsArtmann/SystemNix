# FZF configuration (Cross-Platform)
# Migrated from dotfiles/.fzf.zsh
# Home Manager manages completion and keybindings automatically
{colorScheme, ...}: let
  colors = colorScheme.palette;
in {
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;

    # FZF options
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--cycle"
      "--color=bg+:#${colors.base02},bg:#${colors.base00},spinner:#${colors.base06},hl:#${colors.base08}"
      "--color=fg:#${colors.base05},header:#${colors.base08},info:#${colors.base0E},pointer:#${colors.base06}"
      "--color=marker:#${colors.base07},fg+:#${colors.base05},prompt:#${colors.base0E},hl+:#${colors.base08}"
      "--color=selected-bg:#${colors.base03},border:#${colors.base04},label:#${colors.subtext0}"
    ];

    # Use ripgrep for better search performance
    defaultCommand = "rg --files --hidden --glob '!.git'";

    # Ctrl+T and Ctrl+R keybindings are configured automatically
    # No manual sourcing needed
  };
}
