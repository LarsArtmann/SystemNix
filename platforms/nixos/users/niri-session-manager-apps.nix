# Single source of truth for the niri-session-manager app lists.
#
# Consumed by home.nix (TOML generation + HM eval-time assertions) and by
# tests/test-niri-session-config.nix (pure-eval CI guard). Do NOT inline
# these lists anywhere else — the invariant below is only enforceable
# because this file is the one place the entries can rot.
#
# Invariant (2026-08-31 terminal-storm class): every terminal app-id MUST
# appear in singleInstanceApps. Restore dedupes single-instance apps to ONE
# spawn; a terminal missing from that list re-arms the restore-storm growth
# loop (152 empty ghostty terminals per login). Multi-process terminals
# (kitty/foot/alacritty) are single-instance AT RESTORE TIME on purpose:
# an empty restored shell carries no state worth N copies.
{
  singleInstanceApps = [
    "helium"
    "firefox"
    "Firefox"
    "signal"
    "Slack"
    "discord"
    "vesktop"
    "telegramdesktop"
    "Spotify"
    "spotify"
    "org.keepassxc.KeePassXC"
    "kitty"
    "foot"
    "org.wezfurlong.wezterm"
    # ghostty is gtk-single-instance: every surface shares one process.
    # Without this entry restore spawns ONE ghostty per SAVED WINDOW and
    # the count only grows across logins (2026-08-31: 152 per login).
    "com.mitchellh.ghostty"
    "alacritty"
    # emacs: single-process-multi-window when run as a daemon (frames via
    # emacsclient) — the ghostty class. Not installed today (only the
    # dormant Mod+Shift+E keybind references it); pinned preemptively.
    "emacs"
  ];

  # Transient/dialog app-ids: never saved, never restored. Restoring a
  # dialog is nonsense by definition (2026-08-31 report: gcr-prompter was
  # being "restored" every login).
  skipApps = [
    "Jan"
    "gcr-prompter" # GCR/polkit auth prompt dialog
    "xdg-desktop-portal-gtk" # portal file chooser + dialog windows
  ];

  terminalAppIds = [
    "kitty"
    "foot"
    "org.wezfurlong.wezterm"
    "com.mitchellh.ghostty"
    "alacritty"
  ];

  shellNames = [
    "fish"
    "bash"
    "zsh"
    "sh"
    "dash"
    "-fish"
    "-bash"
    "-zsh"
    "-sh"
    "sudo"
    "doas"
  ];

  appMappings = {
    "signal" = [ "signal-desktop" ];
    "telegramdesktop" = [ "telegram-desktop" ];
    "org.keepassxc.KeePassXC" = [ "keepassxc" ];
    "com.mitchellh.ghostty" = [ "ghostty" ];
    "org.wezfurlong.wezterm" = [ "wezterm" ];
  };

  # Returns a list of human-readable violation strings; empty = healthy.
  # Kept next to the data so home.nix assertions and the CI guard test run
  # the SAME check — no second implementation to drift.
  mkInvariantViolations =
    {
      singleInstanceApps,
      skipApps,
      terminalAppIds,
      ...
    }:
    let
      missingTerminals = builtins.filter (id: !builtins.elem id singleInstanceApps) terminalAppIds;
    in
    (map (
      id:
      "niri-session-manager: terminal app-id \"${id}\" is missing from single_instance_apps — restore dedupes single-instance apps to ONE spawn, and a terminal missing from that list re-arms the 2026-08-31 restore-storm growth loop."
    ) missingTerminals)
    ++ (if builtins.elem "gcr-prompter" skipApps then
      [ ]
    else
      [
        "niri-session-manager: gcr-prompter (transient GCR auth dialog) must stay in skip_apps — restoring transient dialogs is nonsense by definition."
      ]
    );
}
