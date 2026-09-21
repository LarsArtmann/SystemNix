# Superfile configuration (Cross-Platform)
# Modern terminal file manager (`spf`) — https://superfile.dev
#
# Package comes from the upstream flake (v1.6.0+ — nixpkgs is stuck at 1.3.3;
# v1.6.0 ships the bubbletea-v2 preview-reliability rework and configurable
# sidebar sections). The upstream flake's binary is named `superfile`, so the
# `spf` muscle-memory command is a shell function (see fish/zsh/bash.nix) that
# also implements cd-on-quit. NOTE: superfile's shell integration scripts call
# `command spf` — ours call `command superfile` to match this binary name.
{
  superfile,
  pkgs,
  ...
}:
{
  programs.superfile = {
    enable = true;
    package = superfile.packages.${pkgs.system}.default;

    settings = {
      # Built-in Catppuccin Mocha theme — matches the global theme
      # (platforms/common/theme.nix colorSchemeName = "catppuccin-mocha").
      # v1.6.0 theme name; v1.3.x called the same palette `catppuccin`.
      theme = "catppuccin-mocha";

      # Meaningless under Nix — updates come from flake bumps, and the
      # network probe would fire on every launch.
      auto_check_update = false;

      # Explicit: Nerd Fonts are installed (packages/fonts.nix), so icons on.
      nerdfont = true;

      # Quit superfile and the shell follows into the browsed directory —
      # requires the `spf` shell function in fish/zsh/bash.nix.
      cd_on_quit = true;

      # Plugins (owner decision 2026-09-21): the HM module auto-installs the
      # companion packages for metadata (exiftool) and zoxide_support.
      metadata = true;
      zoxide_support = true;
      enable_md5_checksum = true;
    };

    # firstUseCheck: left at default (true) — superfile shows its hotkey
    # tutorial popup on first launch (owner decision 2026-09-21: keep).
    #
    # Deliberately NOT set: hotkeys (default keybindings, owner decision
    # 2026-09-21) and pinnedFolders (add on request).
  };
}
