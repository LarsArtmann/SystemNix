{colorScheme, ...}: let
  theme = import ../theme.nix;
in {
  programs.zed-editor = {
    enable = true;
    mutableUserSettings = true;
    userSettings = {
      ui_font_size = 14;
      buffer_font_size = 14;
      ui_font_family = theme.font.mono;
      buffer_font_family = theme.font.mono;
      theme = {
        mode = "dark";
        light = "One Light";
        dark = "Catppuccin Mocha";
      };
      cursor_blink = false;
      relative_line_numbers = true;
      scroll_beyond_last_line = "off";
      word_wrap = "word_boundaries";
      tab_size = 2;
      soft_wrap = "editor_width";
      preferred_line_length = 120;
      show_whitespaces = "selection";
      vim_mode = true;
      vim = {
        use_system_clipboard = "always";
        use_multiline_find = true;
        toggle_relative_line_numbers = true;
      };
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      auto_update = false;
      restore_on_startup = "last_session";
      show_copilot_suggestions = false;
      terminal = {
        font_family = theme.font.mono;
        font_size = 13;
        line_height = "comfortable";
        env = {
          TERM = "xterm-256color";
        };
      };
      project_panel = {
        dock = "left";
        default_width = 240;
        indent_size = 12;
        hide_gitignore = false;
      };
      inlay_hints = {
        enabled = true;
        show_type_hints = true;
        show_parameter_hints = true;
      };
      git = {
        inline_blame = {
          enabled = true;
          delay_ms = 500;
        };
      };
      languages = {
        Nix = {
          tab_size = 2;
          formatter = "language_server";
        };
        Go = {
          tab_size = 4;
          formatter = "language_server";
        };
        Rust.tab_size = 4;
        Python.tab_size = 4;
        TypeScript.tab_size = 2;
        JavaScript.tab_size = 2;
      };
    };
  };
}
