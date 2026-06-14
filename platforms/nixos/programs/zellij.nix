{
  pkgs,
  colorScheme,
  ...
}: let
  colors = colorScheme.palette;
in {
  # Zellij - Modern terminal multiplexer (tmux alternative)
  programs.zellij = {
    enable = true;
    enableFishIntegration = false; # Manually control to avoid conflicts with tmux

    settings = {
      # Theme - Catppuccin Mocha
      theme = "catppuccin-mocha";
      themes.catppuccin-mocha = {
        fg = "#${colors.base05}"; # Text
        bg = "#${colors.base00}"; # Background
        black = "#${colors.base01}"; # Dark bg
        red = "#${colors.base08}"; # Red
        green = "#${colors.base0B}"; # Green
        yellow = "#${colors.base0A}"; # Yellow
        blue = "#${colors.base0D}"; # Blue
        magenta = "#${colors.base0E}"; # Magenta
        cyan = "#${colors.base0C}"; # Cyan
        white = "#${colors.base05}"; # White
        orange = "#${colors.base09}"; # Orange
      };

      # UI settings
      pane_frames = true;
      simplified_ui = false;
      default_shell = "fish";
      default_layout = "default";
      default_mode = "normal";

      # Scrollback
      scrollback_lines = 10000;

      # Copy mode
      copy_command =
        if pkgs.stdenv.isDarwin
        then "pbcopy"
        else "wl-copy";
      copy_clipboard = "system";
      copy_on_select = false;

      # Plugins
      plugins = {
        tab-bar = {path = "tab-bar";};
        status-bar = {path = "status-bar";};
        strider = {path = "strider";};
        compact-bar = {path = "compact-bar";};
      };
    };

    # Use extraConfig for complex keybindings (KDL format)
    extraConfig = ''
      keybinds {
          // Unbind defaults that conflict
          unbind "Ctrl g" "Ctrl h" "Ctrl o" "Ctrl p" "Ctrl q" "Ctrl s"

          // Normal mode - prefix key style
          normal {
              bind "Ctrl a" { SwitchToMode "tmux"; }
              bind "Ctrl h" { GoToPreviousTab; SwitchToMode "Normal"; }
              bind "Ctrl l" { GoToNextTab; SwitchToMode "Normal"; }
              bind "Ctrl k" { MoveFocus "Up"; }
              bind "Ctrl j" { MoveFocus "Down"; }
              bind "Ctrl r" { SwitchToMode "resize"; }
          }

          // Tmux mode - prefix menu (activated with Ctrl+a)
          tmux {
              bind "\"" { NewPane "Down"; SwitchToMode "Normal"; }
              bind "%" { NewPane "Right"; SwitchToMode "Normal"; }
              bind "x" { CloseFocus; SwitchToMode "Normal"; }
              bind "z" { ToggleFocusFullscreen; SwitchToMode "Normal"; }
              bind "c" { NewTab; SwitchToMode "Normal"; }
              bind "n" { GoToNextTab; SwitchToMode "Normal"; }
              bind "p" { GoToPreviousTab; SwitchToMode "Normal"; }
              bind "Space" { NextSwapLayout; SwitchToMode "Normal"; }
              bind "d" { Detach; }
              bind "q" { Quit; }
              bind "Esc" { CloseFocus; SwitchToMode "Normal"; }
              bind "Ctrl a" { SwitchToMode "Normal"; }
          }

          // Resize mode
          resize {
              bind "h" { Resize "Increase left"; }
              bind "j" { Resize "Increase down"; }
              bind "k" { Resize "Increase up"; }
              bind "l" { Resize "Increase right"; }
              bind "H" { Resize "Decrease left"; }
              bind "J" { Resize "Decrease down"; }
              bind "K" { Resize "Decrease up"; }
              bind "L" { Resize "Decrease right"; }
              bind "Esc" { SwitchToMode "Normal"; }
          }

          // Locked mode - pass all keys through
          locked {
              bind "Ctrl a" { SwitchToMode "Normal"; }
          }

          // Tab mode
          tab {
              bind "n" { GoToNextTab; }
              bind "p" { GoToPreviousTab; }
              bind "r" { SwitchToMode "RenameTab"; TabNameInput 0; }
              bind "h" { GoToPreviousTab; }
              bind "l" { GoToNextTab; }
              bind "1" { GoToTab 1; SwitchToMode "Normal"; }
              bind "2" { GoToTab 2; SwitchToMode "Normal"; }
              bind "3" { GoToTab 3; SwitchToMode "Normal"; }
              bind "4" { GoToTab 4; SwitchToMode "Normal"; }
              bind "5" { GoToTab 5; SwitchToMode "Normal"; }
              bind "6" { GoToTab 6; SwitchToMode "Normal"; }
              bind "7" { GoToTab 7; SwitchToMode "Normal"; }
              bind "8" { GoToTab 8; SwitchToMode "Normal"; }
              bind "9" { GoToTab 9; SwitchToMode "Normal"; }
              bind "Esc" { SwitchToMode "Normal"; }
          }
      }
    '';

    # Layouts using the layouts option (simpler than extraConfig)
    layouts = {
      dev = {
        layout = {
          _children = [
            {
              pane = {
                split_direction = "vertical";
                _children = [
                  {
                    pane = {
                      name = "editor";
                      command = "nvim";
                      args = ["."];
                    };
                  }
                  {
                    pane = {
                      split_direction = "horizontal";
                      _children = [
                        {
                          pane = {
                            name = "terminal";
                            command = "fish";
                          };
                        }
                        {
                          pane = {
                            name = "git";
                            command = "gitui";
                          };
                        }
                      ];
                    };
                  }
                ];
              };
            }
            {
              pane = {
                size = 1;
                borderless = true;
                plugin = {
                  location = "zellij:tab-bar";
                };
              };
            }
            {
              pane = {
                size = 1;
                borderless = true;
                plugin = {
                  location = "zellij:status-bar";
                };
              };
            }
          ];
        };
      };

      monitoring = {
        layout = {
          _children = [
            {
              pane = {
                split_direction = "horizontal";
                _children = [
                  {
                    pane = {
                      name = "htop";
                      command = "htop";
                    };
                  }
                  {
                    pane = {
                      split_direction = "vertical";
                      _children = [
                        {
                          pane = {
                            name = "logs";
                            command =
                              if pkgs.stdenv.isDarwin
                              then "log"
                              else "journalctl";
                            args =
                              if pkgs.stdenv.isDarwin
                              then ["stream"]
                              else ["-f"];
                          };
                        }
                        {
                          pane = {
                            name = "system";
                            command = "btop";
                          };
                        }
                      ];
                    };
                  }
                ];
              };
            }
            {
              pane = {
                size = 1;
                borderless = true;
                plugin = {
                  location = "zellij:tab-bar";
                };
              };
            }
            {
              pane = {
                size = 1;
                borderless = true;
                plugin = {
                  location = "zellij:status-bar";
                };
              };
            }
          ];
        };
      };

      default = {
        layout = {
          _children = [
            {pane = {};}
            {
              pane = {
                size = 1;
                borderless = true;
                plugin = {
                  location = "zellij:tab-bar";
                };
              };
            }
            {
              pane = {
                size = 1;
                borderless = true;
                plugin = {
                  location = "zellij:status-bar";
                };
              };
            }
          ];
        };
      };
    };
  };
}
