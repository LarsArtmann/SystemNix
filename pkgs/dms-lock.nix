{
  writeShellApplication,
  swaylock-effects,
  coreutils,
  findutils,
  colors,
}:
writeShellApplication {
  name = "dms-lock";
  runtimeInputs = [
    swaylock-effects
    coreutils
    findutils
  ];
  text = ''
    # Try DMS lock first (primary — QML-based lock screen with wallpaper + clock)
    if command -v dms &>/dev/null && dms ipc lock lock 2>/dev/null; then
      exit 0
    fi

    # Fallback: swaylock-effects with wallpaper + Catppuccin Mocha theme
    # Try to match the current DMS wallpaper; fall back to first wallpaper in dir
    WALLPAPER=""
    if command -v dms &>/dev/null; then
      WALLPAPER=$(dms ipc call wallpaper get 2>/dev/null | tr -d '[:space:]')
    fi
    if [ -z "$WALLPAPER" ] || [ "$WALLPAPER" = "null" ] || [ ! -f "$WALLPAPER" ]; then
      WALLPAPER=$(find -L "''${HOME:-/home/lars}/.local/share/wallpapers" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        2>/dev/null | sort | head -1)
    fi

    ARGS=(
      --daemonize
      --ignore-empty-password
      --show-failed-attempts
      --clock
      --datestr '%Y-%m-%d'
      --timestr '%H:%M'
      --effect-blur 10x3
      --effect-vignette 0.5:0.5
      --indicator
      --indicator-radius 120
      --indicator-thickness 12
      --inside-color ${colors.base}dd
      --inside-clear-color ${colors.green}dd
      --inside-ver-color ${colors.lavender}dd
      --inside-wrong-color ${colors.red}dd
      --key-hl-color ${colors.lavender}
      --layout-bg-color 00000000
      --layout-text-color ${colors.text}
      --line-color 00000000
      --line-clear-color 00000000
      --line-ver-color 00000000
      --line-wrong-color 00000000
      --ring-color ${colors.surface1}
      --ring-clear-color ${colors.green}
      --ring-ver-color ${colors.lavender}
      --ring-wrong-color ${colors.red}
      --separator-color 00000000
      --text-color ${colors.text}
      --text-clear-color ${colors.base}
      --text-ver-color ${colors.base}
      --text-wrong-color ${colors.base}
      --bs-hl-color ${colors.red}
    )

    if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
      exec swaylock "''${ARGS[@]}" --image "$WALLPAPER"
    else
      exec swaylock "''${ARGS[@]}" --color "${colors.base}"
    fi
  '';
}
