{pkgs, ...}: {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;

    settings = {
      manager = {
        ratio = [1 2 3];
        sort_by = "modified";
        sort_sensitive = false;
        sort_reverse = true;
        sort_dir_first = true;
        linemode = "size";
        show_hidden = false;
        show_symlink = true;
      };

      preview = {
        tab_size = 2;
        max_width = 1920;
        max_height = 1080;
        cache_dir = "~/.cache/yazi";
        image_filter = "catmull-rom";
        image_quality = 90;
      };

      opener = {
        open = [
          {
            run = "xdg-open \"$@\"";
            desc = "Open with default app";
          }
        ];
        edit = [
          {
            run = "zed \"$@\"";
            desc = "Open in Zed";
          }
        ];
      };

      open = {
        rules = [
          {
            url = "*.json";
            use = "edit";
          }
          {
            url = "*.toml";
            use = "edit";
          }
          {
            url = "*.yaml";
            use = "edit";
          }
          {
            url = "*.yml";
            use = "edit";
          }
          {
            url = "*.nix";
            use = "edit";
          }
          {
            url = "*.rs";
            use = "edit";
          }
          {
            url = "*.go";
            use = "edit";
          }
          {
            url = "*.ts";
            use = "edit";
          }
          {
            url = "*.js";
            use = "edit";
          }
          {
            url = "*.css";
            use = "edit";
          }
          {
            url = "*.md";
            use = "edit";
          }
          {
            url = "*";
            use = "open";
          }
        ];
      };

      tasks = {
        micro_workers = 5;
        macro_workers = 10;
        bizarre_retry = 5;
        image_alloc = 536870912;
        image_bound = [0 0];
        suppress_prejudice = false;
      };

      plugin = {
        prepend_preloaders = [];
        append_preloaders = [];
        prepend_previewers = [];
        append_previewers = [];
      };

      input = {
        cursor_blink = false;
      };

      select = {
        open_origin = "hovered";
        open_offset = [0 0 50 7];
      };

      which = {
        sort_by = "none";
        sort_sensitive = false;
        sort_reverse = false;
      };

      log = {
        enabled = false;
      };
    };

    theme = {
      manager = {
        cwd = {fg = "#89b4fa";}; # Blue
        hovered = {
          fg = "#1e1e2e";
          bg = "#89b4fa";
          bold = true;
        };
        preview_hovered = {underline = true;};
        find_keyword = {
          fg = "#f9e2af";
          bold = true;
          italic = true;
        }; # Yellow
        find_position = {
          fg = "#f5c2e7";
          bg = "reset";
          bold = true;
          italic = true;
        }; # Pink
        marker_selected = {
          fg = "#a6e3a1";
          bg = "#a6e3a1";
        }; # Green
        marker_copied = {
          fg = "#f9e2af";
          bg = "#f9e2af";
        }; # Yellow
        marker_cut = {
          fg = "#f38ba8";
          bg = "#f38ba8";
        }; # Red
        tab_active = {
          fg = "#1e1e2e";
          bg = "#89b4fa";
        }; # Blue
        tab_inactive = {
          fg = "#cdd6f4";
          bg = "#313244";
        }; # Surface1
        border_style = {fg = "#585b70";}; # Surface2
      };

      mode = {
        normal_main = {
          fg = "#1e1e2e";
          bg = "#89b4fa";
          bold = true;
        }; # Blue
        normal_alt = {
          fg = "#89b4fa";
          bg = "#313244";
        }; # Blue on Surface1
        select_main = {
          fg = "#1e1e2e";
          bg = "#a6e3a1";
          bold = true;
        }; # Green
        select_alt = {
          fg = "#a6e3a1";
          bg = "#313244";
        }; # Green on Surface1
        unset_main = {
          fg = "#1e1e2e";
          bg = "#f38ba8";
          bold = true;
        }; # Red
        unset_alt = {
          fg = "#f38ba8";
          bg = "#313244";
        }; # Red on Surface1
      };

      status = {
        separator_style = {
          fg = "#585b70";
          bg = "#585b70";
        }; # Surface2
        progress_label = {
          fg = "#cdd6f4";
          bold = true;
        }; # Text
        progress_normal = {
          fg = "#89b4fa";
          bg = "#313244";
        }; # Blue on Surface1
        progress_error = {
          fg = "#f38ba8";
          bg = "#313244";
        }; # Red on Surface1
        permissions_t = {fg = "#89b4fa";}; # Blue
        permissions_r = {fg = "#f9e2af";}; # Yellow
        permissions_w = {fg = "#f38ba8";}; # Red
        permissions_x = {fg = "#a6e3a1";}; # Green
        permissions_s = {fg = "#6c7086";}; # Overlay0
      };

      input = {
        border = {fg = "#89b4fa";}; # Blue
        title = {};
        value = {};
        selected = {reversed = true;};
      };

      select = {
        border = {fg = "#89b4fa";}; # Blue
        active = {fg = "#f5c2e7";}; # Pink
        inactive = {};
      };

      tasks = {
        border = {fg = "#89b4fa";}; # Blue
        title = {};
        hovered = {
          fg = "#f5c2e7";
          underline = true;
        }; # Pink
      };

      which = {
        mask = {bg = "#1e1e2e";}; # Base
        cand = {fg = "#94e2d5";}; # Teal
        rest = {fg = "#9399b2";}; # Overlay2
        desc = {fg = "#f5c2e7";}; # Pink
        separator_style = {fg = "#585b70";}; # Surface2
      };

      help = {
        on = {fg = "#f5c2e7";}; # Pink
        exec = {fg = "#94e2d5";}; # Teal
        desc = {fg = "#9399b2";}; # Overlay2
        hovered = {
          fg = "#f5c2e7";
          bg = "#313244";
          bold = true;
        }; # Pink on Surface1
        footer = {
          fg = "#1e1e2e";
          bg = "#89b4fa";
        }; # Blue
      };

      filetype = {
        rules = [
          # Images
          {
            mime = "image/*";
            fg = "#f5c2e7";
            icon = "🖼";
          } # Pink
          # Videos
          {
            mime = "video/*";
            fg = "#fab387";
            icon = "🎬";
          } # Peach
          {
            mime = "audio/*";
            fg = "#fab387";
            icon = "🎵";
          } # Peach
          # Archives
          {
            mime = "application/zip";
            fg = "#f9e2af";
            icon = "📦";
          } # Yellow
          {
            mime = "application/gzip";
            fg = "#f9e2af";
            icon = "📦";
          } # Yellow
          {
            mime = "application/x-tar";
            fg = "#f9e2af";
            icon = "📦";
          } # Yellow
          {
            mime = "application/x-bzip";
            fg = "#f9e2af";
            icon = "📦";
          } # Yellow
          # Documents
          {
            mime = "application/pdf";
            fg = "#f38ba8";
            icon = "📄";
          } # Red
          {
            mime = "application/rtf";
            fg = "#89b4fa";
            icon = "📝";
          } # Blue
          {
            mime = "application/doc*";
            fg = "#89b4fa";
            icon = "📝";
          } # Blue
          # Programming
          {
            mime = "text/*";
            fg = "#cdd6f4";
          } # Text
          {
            mime = "*/javascript";
            fg = "#f9e2af";
          } # Yellow
          {
            mime = "*/json";
            fg = "#f9e2af";
          } # Yellow
          # Executables
          {
            mime = "application/x-executable";
            fg = "#a6e3a1";
            icon = "⚙";
          } # Green
          {
            mime = "application/x-pie-executable";
            fg = "#a6e3a1";
            icon = "⚙";
          } # Green
          # Fallback
          {
            url = "*";
            fg = "#cdd6f4";
            icon = "📄";
          } # Text
        ];
      };
    };

    keymap = {
      manager = {
        prepend_keymap = [
          {
            on = ["<C-c>"];
            run = "yank";
            desc = "Copy";
          }
          {
            on = ["<C-x>"];
            run = "cut";
            desc = "Cut";
          }
          {
            on = ["<C-v>"];
            run = "paste";
            desc = "Paste";
          }
          {
            on = ["<C-d>"];
            run = "remove";
            desc = "Trash";
          }
          {
            on = ["<C-r>"];
            run = "rename --cursor=before_ext";
            desc = "Rename";
          }
          {
            on = ["<C-s>"];
            run = "search fd";
            desc = "Search files";
          }
          {
            on = ["<C-g>"];
            run = "search rg";
            desc = "Search content";
          }
          {
            on = ["g" "h"];
            run = "cd ~";
            desc = "Go to home";
          }
          {
            on = ["g" "d"];
            run = "cd ~/Downloads";
            desc = "Go to Downloads";
          }
          {
            on = ["g" "p"];
            run = "cd ~/projects";
            desc = "Go to projects";
          }
          {
            on = ["g" "c"];
            run = "cd ~/.config";
            desc = "Go to config";
          }
          {
            on = ["?"];
            run = "help";
            desc = "Open help";
          }
        ];
      };
    };
  };

  # Ensure image preview dependencies are available
  home.packages = with pkgs; [
    ffmpegthumbnailer
    unar
    poppler
  ];
}
