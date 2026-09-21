# Superfile configuration (Cross-Platform)
# Modern terminal file manager (`spf`) — https://superfile.dev
# Package + config both managed via the Home Manager module; the binary lands
# in home.packages automatically (no entry needed in packages/base.nix).
{ ... }:
{
  programs.superfile = {
    enable = true;

    settings = {
      # v1.3.3's built-in `catppuccin` theme IS Catppuccin Mocha
      # (code_syntax_highlight = "catppuccin-mocha", #1e1e2e base) — matches
      # the global theme (platforms/common/theme.nix colorSchemeName).
      # NOTE: newer superfile releases renamed it to "catppuccin-mocha";
      # revisit the name if the package is ever bumped past v1.3.3.
      theme = "catppuccin";

      # Meaningless under Nix — updates come from nixpkgs bumps, and the
      # network probe would fire on every launch.
      auto_check_update = false;

      # Explicit: Nerd Fonts are installed (packages/fonts.nix), so icons on.
      nerdfont = true;
    };

    # firstUseCheck: left at default (true) — superfile shows its hotkey
    # tutorial popup once on first launch.
    #
    # Deliberately NOT set yet (pending decisions):
    #   hotkeys       — vim-style navigation preset
    #   pinnedFolders — quick-access sidebar entries
    #   settings.metadata / zoxide_support — pull in exiftool / zoxide
    #   cd_on_quit    — needs a fish wrapper function (see fish.nix)
  };
}
