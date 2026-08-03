{
  pkgs,
  lib,
  ...
}:
let
  keepassxcPkg = pkgs.keepassxc;

  # Native messaging manifest for Helium browser extension.
  # Helium uses net.imput.helium (from imputnet/helium change-chromium-branding.patch).
  #   macOS: ~/Library/Application Support/net.imput.helium/
  #   Linux: $XDG_CONFIG_HOME/net.imput.helium/
  # nixpkgs keepassxc already ships Chromium + Firefox manifests at the standard
  # paths — no symlinkJoin wrapper needed. Helium uses a non-standard config dir.
  heliumManifest = builtins.toJSON {
    name = "org.keepassxc.keepassxc_browser";
    description = "KeePassXC integration with native messaging support";
    path = "${keepassxcPkg}/bin/keepassxc-proxy";
    type = "stdio";
    allowed_origins = [ "chrome-extension://oboonakemofpalcgghocfoadofidjkkk/" ];
  };
in
{
  programs.keepassxc = {
    enable = true;
    package = keepassxcPkg;
    settings = {
      Browser.Enabled = true;
      Browser.UpdateBinaryPath = false;
      GUI.ApplicationTheme = "dark";
      GUI.CompactMode = true;
    };
  };

  # Helium browser native messaging host (non-standard config path)
  home.file = lib.mkIf pkgs.stdenv.isDarwin {
    "Library/Application Support/net.imput.helium/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json" =
      {
        text = heliumManifest;
        force = true;
      };
  };

  xdg.configFile = lib.mkIf pkgs.stdenv.isLinux {
    "net.imput.helium/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json" = {
      text = heliumManifest;
      force = true;
    };
  };
}
