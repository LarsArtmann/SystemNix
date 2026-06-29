# Browser policies: Chromium extensions + Firefox UI/UX policies
_: {
  flake.nixosModules.browser-policies = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.browser-policies;

    ytShortsBlockerId = "ckagfhpboagdopichicnebandlofghbc";
    oneTabId = "chphlpgkkbolifaimnlloiipkdnihall";
  in {
    options.services.browser-policies = {
      enable = lib.mkEnableOption "Browser policies (Chromium extensions, Firefox UI)";
    };

    config = lib.mkIf cfg.enable {
      programs.chromium = {
        enable = true;

        extensions = [
          ytShortsBlockerId
          oneTabId
        ];

        extraOpts = {
          ExtensionSettings = {
            "${ytShortsBlockerId}" = {
              installation_mode = "force_installed";
              toolbar_pin = "force_pinned";
            };
            "${oneTabId}" = {
              installation_mode = "force_installed";
              toolbar_pin = "force_pinned";
            };
          };
        };
      };

      programs.firefox.policies.Preferences = {
        "browser.shell.checkDefaultBrowser" = {
          Value = false;
          Status = "locked";
        };
        "widget.disable-swipe-tracker" = {
          Value = true;
          Status = "locked";
        };
        "browser.gesture.swipe.left" = {
          Value = "";
          Status = "locked";
        };
        "browser.gesture.swipe.right" = {
          Value = "";
          Status = "locked";
        };
        "browser.gesture.swipe.up" = {
          Value = "";
          Status = "locked";
        };
        "browser.gesture.swipe.down" = {
          Value = "";
          Status = "locked";
        };
        "browser.autofocus" = {
          Value = false;
          Status = "locked";
        };
      };
    };
  };
}
