{
  pkgs,
  colorScheme,
  ...
}: let
  colors = colorScheme.palette;
in {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;

    settings = {
      manager = {
        ratio = [
          1
          2
          3
        ];
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
        image_bound = [
          0
          0
        ];
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
        open_offset = [
          0
          0
          50
          7
        ];
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
        cwd = {
          fg = "#${colors.base0D}";
        }; # Blue
        hovered = {
          fg = "#${colors.base00}";
          bg = "#${colors.base0D}";
          bold = true;
        };
        preview_hovered = {
          underline = true;
        };
        find_keyword = {
          fg = "#${colors.base0A}";
          bold = true;
          italic = true;
        }; # Yellow
        find_position = {
          fg = "#${colors.base0F}";
          bg = "reset";
          bold = true;
          italic = true;
        }; # Pink
        marker_selected = {
          fg = "#${colors.base0B}";
          bg = "#${colors.base0B}";
        }; # Green
        marker_copied = {
          fg = "#${colors.base0A}";
          bg = "#${colors.base0A}";
        }; # Yellow
        marker_cut = {
          fg = "#${colors.base08}";
          bg = "#${colors.base08}";
        }; # Red
        tab_active = {
          fg = "#${colors.base00}";
          bg = "#${colors.base0D}";
        }; # Blue
        tab_inactive = {
          fg = "#${colors.base05}";
          bg = "#${colors.base02}";
        }; # Surface1
        border_style = {
          fg = "#${colors.base04}";
        }; # Surface2
      };

      mode = {
        normal_main = {
          fg = "#${colors.base00}";
          bg = "#${colors.base0D}";
          bold = true;
        }; # Blue
        normal_alt = {
          fg = "#${colors.base0D}";
          bg = "#${colors.base02}";
        }; # Blue on Surface1
        select_main = {
          fg = "#${colors.base00}";
          bg = "#${colors.base0B}";
          bold = true;
        }; # Green
        select_alt = {
          fg = "#${colors.base0B}";
          bg = "#${colors.base02}";
        }; # Green on Surface1
        unset_main = {
          fg = "#${colors.base00}";
          bg = "#${colors.base08}";
          bold = true;
        }; # Red
        unset_alt = {
          fg = "#${colors.base08}";
          bg = "#${colors.base02}";
        }; # Red on Surface1
      };

      status = {
        separator_style = {
          fg = "#${colors.base04}";
          bg = "#${colors.base04}";
        }; # Surface2
        progress_label = {
          fg = "#${colors.base05}";
          bold = true;
        }; # Text
        progress_normal = {
          fg = "#${colors.base0D}";
          bg = "#${colors.base02}";
        }; # Blue on Surface1
        progress_error = {
          fg = "#${colors.base08}";
          bg = "#${colors.base02}";
        }; # Red on Surface1
        permissions_t = {
          fg = "#${colors.base0D}";
        }; # Blue
        permissions_r = {
          fg = "#${colors.base0A}";
        }; # Yellow
        permissions_w = {
          fg = "#${colors.base08}";
        }; # Red
        permissions_x = {
          fg = "#${colors.base0B}";
        }; # Green
        permissions_s = {
          fg = "#${colors.overlay0}";
        }; # Overlay0
      };

      input = {
        border = {
          fg = "#${colors.base0D}";
        }; # Blue
        title = {};
        value = {};
        selected = {
          reversed = true;
        };
      };

      select = {
        border = {
          fg = "#${colors.base0D}";
        }; # Blue
        active = {
          fg = "#${colors.base0F}";
        }; # Pink
        inactive = {};
      };

      tasks = {
        border = {
          fg = "#${colors.base0D}";
        }; # Blue
        title = {};
        hovered = {
          fg = "#${colors.base0F}";
          underline = true;
        }; # Pink
      };

      which = {
        mask = {
          bg = "#${colors.base00}";
        }; # Base
        cand = {
          fg = "#${colors.base0C}";
        }; # Teal
        rest = {
          fg = "#${colors.overlay2}";
        }; # Overlay2
        desc = {
          fg = "#${colors.base0F}";
        }; # Pink
        separator_style = {
          fg = "#${colors.base04}";
        }; # Surface2
      };

      help = {
        on = {
          fg = "#${colors.base0F}";
        }; # Pink
        exec = {
          fg = "#${colors.base0C}";
        }; # Teal
        desc = {
          fg = "#${colors.overlay2}";
        }; # Overlay2
        hovered = {
          fg = "#${colors.base0F}";
          bg = "#${colors.base02}";
          bold = true;
        }; # Pink on Surface1
        footer = {
          fg = "#${colors.base00}";
          bg = "#${colors.base0D}";
        }; # Blue
      };

      filetype = {
        rules = [
          # Images
          {
            mime = "image/*";
            fg = "#${colors.base0F}";
            icon = "🖼";
          } # Pink
          # Videos
          {
            mime = "video/*";
            fg = "#${colors.base09}";
            icon = "🎬";
          } # Peach
          {
            mime = "audio/*";
            fg = "#${colors.base09}";
            icon = "🎵";
          } # Peach
          # Archives
          {
            mime = "application/zip";
            fg = "#${colors.base0A}";
            icon = "📦";
          } # Yellow
          {
            mime = "application/gzip";
            fg = "#${colors.base0A}";
            icon = "📦";
          } # Yellow
          {
            mime = "application/x-tar";
            fg = "#${colors.base0A}";
            icon = "📦";
          } # Yellow
          {
            mime = "application/x-bzip";
            fg = "#${colors.base0A}";
            icon = "📦";
          } # Yellow
          # Documents
          {
            mime = "application/pdf";
            fg = "#${colors.base08}";
            icon = "📄";
          } # Red
          {
            mime = "application/rtf";
            fg = "#${colors.base0D}";
            icon = "📝";
          } # Blue
          {
            mime = "application/doc*";
            fg = "#${colors.base0D}";
            icon = "📝";
          } # Blue
          # Programming
          {
            mime = "text/*";
            fg = "#${colors.base05}";
          } # Text
          {
            mime = "*/javascript";
            fg = "#${colors.base0A}";
          } # Yellow
          {
            mime = "*/json";
            fg = "#${colors.base0A}";
          } # Yellow
          # Executables
          {
            mime = "application/x-executable";
            fg = "#${colors.base0B}";
            icon = "⚙";
          } # Green
          {
            mime = "application/x-pie-executable";
            fg = "#${colors.base0B}";
            icon = "⚙";
          } # Green
          # Fallback
          {
            url = "*";
            fg = "#${colors.base05}";
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
            on = [
              "g"
              "h"
            ];
            run = "cd ~";
            desc = "Go to home";
          }
          {
            on = [
              "g"
              "d"
            ];
            run = "cd ~/Downloads";
            desc = "Go to Downloads";
          }
          {
            on = [
              "g"
              "p"
            ];
            run = "cd ~/projects";
            desc = "Go to projects";
          }
          {
            on = [
              "g"
              "c"
            ];
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
