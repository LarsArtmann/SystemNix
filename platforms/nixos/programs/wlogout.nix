_: let
  theme = import ../../common/theme.nix;
in {
  # wlogout power menu with Catppuccin Mocha theme and inline SVG icons
  programs.wlogout = {
    enable = true;

    layout = [
      {
        label = "lock";
        action = "swaylock";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "hibernate";
        action = "systemctl hibernate";
        text = "Hibernate";
        keybind = "h";
      }
      {
        label = "logout";
        action = "niri msg action quit";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
    ];

    style = let
      # Catppuccin Mocha SVG icon snippets (color, 24x24 viewBox)
      icon = color: svg_path: "url('data:image/svg+xml;utf8,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"64\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"${color}\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">${svg_path}</svg>')";

      lockSvg = icon "#89b4fa" "<rect width=\"18\" height=\"11\" x=\"3\" y=\"11\" rx=\"2\" ry=\"2\"/><path d=\"M7 11V7a5 5 0 0 1 10 0v4\"/>";
      hibernateSvg = icon "#cba6f7" "<path d=\"M12 2a10 10 0 1 0 10 10\"/><path d=\"M12 2v10l7-7\"/>";
      logoutSvg = icon "#fab387" "<path d=\"M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4\"/><polyline points=\"16 17 21 12 16 7\"/><line x1=\"21\" y1=\"12\" x2=\"9\" y2=\"12\"/>";
      shutdownSvg = icon "#f38ba8" "<path d=\"M18.36 6.64a9 9 0 1 1-12.73 0\"/><line x1=\"12\" y1=\"2\" x2=\"12\" y2=\"12\"/>";
      suspendSvg = icon "#94e2d5" "<path d=\"M17 18a5 5 0 0 0-10 0\"/><line x1=\"12\" y1=\"9\" x2=\"12\" y2=\"2\"/>";
      rebootSvg = icon "#a6e3a1" "<polyline points=\"23 4 23 10 17 10\"/><path d=\"M20.49 15a9 9 0 1 1-2.12-9.36L23 10\"/>";
    in ''
      * {
        font-family: "${theme.font.mono}";
        font-size: 16px;
      }

      window {
        background-color: rgba(30, 30, 46, 0.95);
        border-radius: 20px;
        border: 3px solid #b4befe;
      }

      button {
        background-color: #313244;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 40%;
        color: #cdd6f4;
        border-radius: 16px;
        border: 2px solid #45475a;
        margin: 10px;
        padding: 20px;
        transition: all 0.2s ease;
      }

      button:focus,
      button:active,
      button:hover {
        background-color: #b4befe;
        color: #1e1e2e;
        border-color: #b4befe;
        box-shadow: 0 4px 15px rgba(180, 190, 254, 0.4);
      }

      #lock {
        background-image: ${lockSvg};
        border-color: #89b4fa;
      }
      #lock:hover {
        background-color: #89b4fa;
        border-color: #89b4fa;
        box-shadow: 0 4px 15px rgba(137, 180, 250, 0.4);
      }

      #hibernate {
        background-image: ${hibernateSvg};
        border-color: #cba6f7;
      }
      #hibernate:hover {
        background-color: #cba6f7;
        border-color: #cba6f7;
        box-shadow: 0 4px 15px rgba(203, 166, 247, 0.4);
      }

      #logout {
        background-image: ${logoutSvg};
        border-color: #fab387;
      }
      #logout:hover {
        background-color: #fab387;
        border-color: #fab387;
        box-shadow: 0 4px 15px rgba(250, 179, 135, 0.4);
      }

      #shutdown {
        background-image: ${shutdownSvg};
        border-color: #f38ba8;
      }
      #shutdown:hover {
        background-color: #f38ba8;
        border-color: #f38ba8;
        box-shadow: 0 4px 15px rgba(243, 139, 168, 0.4);
      }

      #suspend {
        background-image: ${suspendSvg};
        border-color: #94e2d5;
      }
      #suspend:hover {
        background-color: #94e2d5;
        border-color: #94e2d5;
        box-shadow: 0 4px 15px rgba(148, 226, 213, 0.4);
      }

      #reboot {
        background-image: ${rebootSvg};
        border-color: #a6e3a1;
      }
      #reboot:hover {
        background-color: #a6e3a1;
        border-color: #a6e3a1;
        box-shadow: 0 4px 15px rgba(166, 227, 161, 0.4);
      }
    '';
  };
}
