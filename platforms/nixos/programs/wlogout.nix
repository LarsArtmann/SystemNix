{colorScheme, ...}: let
  theme = import ../../common/theme.nix;
  colors = colorScheme.palette;
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

      lockSvg = icon "#${colors.blue}" "<rect width=\"18\" height=\"11\" x=\"3\" y=\"11\" rx=\"2\" ry=\"2\"/><path d=\"M7 11V7a5 5 0 0 1 10 0v4\"/>";
      hibernateSvg = icon "#${colors.mauve}" "<path d=\"M12 2a10 10 0 1 0 10 10\"/><path d=\"M12 2v10l7-7\"/>";
      logoutSvg = icon "#${colors.peach}" "<path d=\"M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4\"/><polyline points=\"16 17 21 12 16 7\"/><line x1=\"21\" y1=\"12\" x2=\"9\" y2=\"12\"/>";
      shutdownSvg = icon "#${colors.red}" "<path d=\"M18.36 6.64a9 9 0 1 1-12.73 0\"/><line x1=\"12\" y1=\"2\" x2=\"12\" y2=\"12\"/>";
      suspendSvg = icon "#${colors.teal}" "<path d=\"M17 18a5 5 0 0 0-10 0\"/><line x1=\"12\" y1=\"9\" x2=\"12\" y2=\"2\"/>";
      rebootSvg = icon "#${colors.green}" "<polyline points=\"23 4 23 10 17 10\"/><path d=\"M20.49 15a9 9 0 1 1-2.12-9.36L23 10\"/>";
    in ''
      * {
        font-family: "${theme.font.mono}";
        font-size: 16px;
      }

      window {
        background-color: #${colors.base}f2;
        border-radius: 20px;
        border: 3px solid #${colors.lavender};
      }

      button {
        background-color: #${colors.surface0};
        background-repeat: no-repeat;
        background-position: center;
        background-size: 40%;
        color: #${colors.text};
        border-radius: 16px;
        border: 2px solid #${colors.surface1};
        margin: 10px;
        padding: 20px;
        transition: all 0.2s ease;
      }

      button:focus,
      button:active,
      button:hover {
        background-color: #${colors.lavender};
        color: #${colors.base};
        border-color: #${colors.lavender};
        box-shadow: 0 4px 15px #${colors.lavender}66;
      }

      #lock {
        background-image: ${lockSvg};
        border-color: #${colors.blue};
      }
      #lock:hover {
        background-color: #${colors.blue};
        border-color: #${colors.blue};
        box-shadow: 0 4px 15px #${colors.blue}66;
      }

      #hibernate {
        background-image: ${hibernateSvg};
        border-color: #${colors.mauve};
      }
      #hibernate:hover {
        background-color: #${colors.mauve};
        border-color: #${colors.mauve};
        box-shadow: 0 4px 15px #${colors.mauve}66;
      }

      #logout {
        background-image: ${logoutSvg};
        border-color: #${colors.peach};
      }
      #logout:hover {
        background-color: #${colors.peach};
        border-color: #${colors.peach};
        box-shadow: 0 4px 15px #${colors.peach}66;
      }

      #shutdown {
        background-image: ${shutdownSvg};
        border-color: #${colors.red};
      }
      #shutdown:hover {
        background-color: #${colors.red};
        border-color: #${colors.red};
        box-shadow: 0 4px 15px #${colors.red}66;
      }

      #suspend {
        background-image: ${suspendSvg};
        border-color: #${colors.teal};
      }
      #suspend:hover {
        background-color: #${colors.teal};
        border-color: #${colors.teal};
        box-shadow: 0 4px 15px #${colors.teal}66;
      }

      #reboot {
        background-image: ${rebootSvg};
        border-color: #${colors.green};
      }
      #reboot:hover {
        background-color: #${colors.green};
        border-color: #${colors.green};
        box-shadow: 0 4px 15px #${colors.green}66;
      }
    '';
  };
}
