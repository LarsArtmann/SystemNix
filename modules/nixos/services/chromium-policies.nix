# Chromium managed policies: extensions, update controls
_: {
  flake.nixosModules.chromium-policies = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.chromium-policies;

    ytShortsBlockerId = "ckagfhpboagdopichicnebandlofghbc";
    oneTabId = "chphlpgkkbolifaimnlloiipkdnihall";
  in {
    options.services.chromium-policies = {
      enable = lib.mkEnableOption "Chromium browser with managed extensions and policies";
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
    };
  };
}
