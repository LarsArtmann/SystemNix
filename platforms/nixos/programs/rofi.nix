{pkgs, ...}: let
  theme = import ../../common/theme.nix;
in {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi.override {
      plugins = with pkgs; [rofi-calc rofi-emoji];
    };

    theme = builtins.toFile "catppuccin-grid.rasi" ''
      * {
          bg: #1e1e2e;
          bg-alt: #313244;
          fg: #cdd6f4;
          fg-alt: #a6adc8;
          selected: #89b4fa;
          active: #a6e3a1;
          urgent: #f38ba8;

          background-color: @bg;
          text-color: @fg;
          font: "${theme.font.mono} 10";
      }

      window {
          transparency: "real";
          location: center;
          anchor: center;
          fullscreen: false;
          width: 800px;
          margin: 0px;
          padding: 0px;
          border: 0px solid;
          border-radius: 16px;
          border-color: @selected;
          background-color: #1e1e2ef2;
          cursor: "default";
      }

      mainbox {
          enabled: true;
          spacing: 16px;
          margin: 0px;
          padding: 24px;
          border: 0px solid;
          border-radius: 0px;
          border-color: @selected;
          background-color: transparent;
          children: [ "inputbar", "listview" ];
      }

      inputbar {
          enabled: true;
          spacing: 12px;
          margin: 0px;
          padding: 16px;
          border: 0px solid;
          border-radius: 12px;
          border-color: @selected;
          background-color: @bg-alt;
          text-color: @fg;
          children: [ "prompt", "entry" ];
      }

      prompt {
          enabled: true;
          background-color: transparent;
          text-color: @selected;
          font: "${theme.font.mono} 14";
      }

      entry {
          enabled: true;
          background-color: transparent;
          text-color: @fg;
          cursor: text;
          placeholder: "Search...";
          placeholder-color: @fg-alt;
      }

      listview {
          enabled: true;
          columns: 5;
          lines: 3;
          cycle: true;
          dynamic: true;
          scrollbar: false;
          layout: vertical;
          reverse: false;
          fixed-height: true;
          fixed-columns: true;
          spacing: 8px;
          margin: 0px;
          padding: 0px;
          border: 0px solid;
          border-radius: 0px;
          border-color: @selected;
          background-color: transparent;
          text-color: @fg;
          cursor: "default";
      }

      element {
          enabled: true;
          spacing: 10px;
          margin: 4px;
          padding: 16px 8px;
          border: 0px solid;
          border-radius: 12px;
          border-color: @selected;
          background-color: transparent;
          text-color: @fg;
          orientation: vertical;
          cursor: pointer;
      }

      element normal.normal {
          background-color: transparent;
          text-color: @fg;
      }

      element normal.urgent {
          background-color: #f38ba833;
          text-color: @urgent;
      }

      element normal.active {
          background-color: #a6e3a133;
          text-color: @active;
      }

      element selected.normal {
          background-color: #89b4fa26;
          text-color: @selected;
          border: 1px solid;
          border-color: #89b4fa66;
      }

      element selected.urgent {
          background-color: #f38ba84d;
          text-color: @urgent;
      }

      element selected.active {
          background-color: #a6e3a14d;
          text-color: @active;
      }

      element-icon {
          background-color: transparent;
          text-color: inherit;
          size: 56px;
          cursor: inherit;
      }

      element-text {
          background-color: transparent;
          text-color: inherit;
          highlight: inherit;
          cursor: inherit;
          vertical-align: 0.5;
          horizontal-align: 0.5;
          font: "${theme.font.mono} 9";
      }

      error-message {
          padding: 16px;
          border: 2px solid;
          border-radius: 12px;
          border-color: @urgent;
          background-color: #1e1e2ee6;
          text-color: @fg;
      }

      textbox {
          background-color: transparent;
          text-color: @fg;
          vertical-align: 0.5;
          horizontal-align: 0.0;
          highlight: none;
      }
    '';

    extraConfig = {
      modi = "drun,run,window";
      show-icons = true;
      icon-theme = "Papirus";
      terminal = "ghostty";
      display-drun = " ";
      drun-display-format = "{name}";
      location = 0;
      disable-history = false;
      hide-scrollbar = true;
      sidebar-mode = false;
    };
  };
}
