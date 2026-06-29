{
  pkgs,
  lib,
  ...
}: let
  keepassxcPkg = pkgs.keepassxc;

  # Chromium manifest as a separate file to avoid eval-time cycles
  chromiumManifest = pkgs.writeText "keepassxc-chromium-manifest" (
    builtins.toJSON {
      name = "org.keepassxc.keepassxc_browser";
      description = "KeePassXC integration with native messaging support";
      path = "${keepassxcPkg}/bin/keepassxc-proxy";
      type = "stdio";
      allowed_origins = ["chrome-extension://oboonakemofpalcgghocfoadofidjkkk/"];
    }
  );

  # Wrapper that provides Chromium native messaging manifests.
  # nixpkgs keepassxc only ships $out/lib/mozilla/ (Firefox format).
  # HM's chromium/brave modules expect $out/etc/chromium/native-messaging-hosts/.
  keepassxcWithChromiumManifests = pkgs.symlinkJoin {
    name = "keepassxc-with-chromium-manifests";
    paths = [keepassxcPkg];
    postBuild = ''
      mkdir -p $out/etc/chromium/native-messaging-hosts
      ln -s ${chromiumManifest} $out/etc/chromium/native-messaging-hosts/org.keepassxc.keepassxc_browser.json
    '';
  };

  # Native messaging manifest for Helium browser extension.
  # Helium uses net.imput.helium (from imputnet/helium change-chromium-branding.patch).
  #   macOS: ~/Library/Application Support/net.imput.helium/
  #   Linux: $XDG_CONFIG_HOME/net.imput.helium/
  heliumManifest = builtins.toJSON {
    name = "org.keepassxc.keepassxc_browser";
    description = "KeePassXC integration with native messaging support";
    path = "${keepassxcWithChromiumManifests}/bin/keepassxc-proxy";
    type = "stdio";
    allowed_origins = ["chrome-extension://oboonakemofpalcgghocfoadofidjkkk/"];
  };
in {
  programs.keepassxc = {
    enable = true;
    package = keepassxcWithChromiumManifests;
    settings = {
      Browser.Enabled = true;
      Browser.UpdateBinaryPath = false;
      GUI.ApplicationTheme = "dark";
      GUI.CompactMode = true;
    };
  };

  # Helium browser native messaging host (non-standard config path)
  home.file = lib.mkIf pkgs.stdenv.isDarwin {
    "Library/Application Support/net.imput.helium/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json" = {
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
