# 📋 TMUX CONFIGURATION FOR SYSTEMNIX
{
  pkgs,
  colorScheme,
  ...
}: let
  colors = colorScheme.palette;
in {
  programs.tmux = {
    enable = true;
    clock24 = true;
    baseIndex = 1;
    sensibleOnTop = true;
    mouse = true;
    terminal = "screen-256color";
    historyLimit = 10000;
    escapeTime = 0;

    plugins = with pkgs; [
      tmuxPlugins.resurrect
      tmuxPlugins.yank
    ];

    extraConfig = ''
      # SystemNix specific keybindings
      bind c new-window -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind '"' split-window -v -c "#{pane_current_path}"
      bind b last-window

      # SystemNix development session template
      bind D new-session -d -s SystemNix -n just "cd ~/projects/SystemNix && just" \; \
                       new-window -d -n nvim "cd ~/projects/SystemNix && nvim" \; \
                       new-window -d -n shell "cd ~/projects/SystemNix" \; \
                       select-window -t 0

      # Integration with Just commands
      bind J new-window -c "#{pane_current_path}" "cd ~/projects/SystemNix && just"
      bind T new-window -c "#{pane_current_path}" "cd ~/projects/SystemNix && just test"
      bind S new-window -c "#{pane_current_path}" "cd ~/projects/SystemNix && just switch"
      bind B new-window -c "#{pane_current_path}" "cd ~/projects/SystemNix && just benchmark"
      bind H new-window -c "#{pane_current_path}" "cd ~/projects/SystemNix && just health"

      # Session persistence for SystemNix
      set -g @resurrect-strategy-nvim 'session'
      set -g @resurrect-capture-pane-contents 'on'
      set -g @resurrect-save-bash-history 'on'
      set -g @resurrect-save-command-history 'on'
      set -g @resurrect-dir "$HOME/.local/share/tmux/resurrect"

      # Copy-paste improvements (tmux-yank handles clipboard integration)
      setw -g mode-keys vi
      bind P paste-buffer
      bind-key -T copy-mode-vi v send-keys -X begin-selection

      # Status bar customization
      set -g status-interval 1
      set -g status-justify centre
      set -g status-bg "#${colors.base00}"
      set -g status-fg "#${colors.base05}"
      set -g status-left "#[fg=#${colors.base0B}]#S#[fg=default] #I:#W "
      set -g status-right "#[fg=#${colors.base0B}]#(date '+%Y-%m-%d %H:%M')#[fg=default]"

      # Window/pane customization
      setw -g window-status-current-style "bg=#${colors.base01},fg=#${colors.base05}"
      setw -g pane-active-border-style fg="#${colors.base0D}"
      setw -g pane-border-style fg="#${colors.base02}"

      # Pain-control enhancements
      bind-key -n M-left select-pane -L
      bind-key -n M-right select-pane -R
      bind-key -n M-up select-pane -U
      bind-key -n M-down select-pane -D

      # Mouse wheel scrolling
      bind -n WheelUpPane if-shell -F -t "#{pane_in_mode}" "send -M" "copy-mode -e"
      bind -n WheelDownPane if-shell -F -t "#{pane_in_mode}" "send -M" "copy-mode -e"
    '';
  };
}
