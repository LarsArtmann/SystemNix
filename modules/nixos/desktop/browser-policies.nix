# Browser policies: Chromium/Helium extensions + Firefox UI/UX policies
#
# Helium reads /etc/chromium/policies/ (compile-time constant — the path is
# determined by GOOGLE_CHROME_BRANDING, which Helium doesn't set). So policies
# written by the NixOS programs.chromium module apply to both Chromium and Helium.
#
# ExtensionSettings supersedes ExtensionInstallForcelist. We use it exclusively
# with proper update_url (required for force_installed) to avoid the silent
# no-install bug that missing update_url causes.
{
  flake.nixosModules.browser-policies =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.browser-policies;
    in
    {
      options.services.browser-policies = {
        enable = lib.mkEnableOption "Browser policies (Chromium/Helium extensions, Firefox UI)";

        chromiumExtensions = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                id = lib.mkOption {
                  type = lib.types.strMatching "[a-z]{32}";
                  description = "Chrome Web Store extension ID (32 lowercase letters)";
                  example = "cjpalhdlnbpafiamejdnhcphjbkeiagm";
                };

                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Human-readable name for documentation purposes (not sent to Chromium)";
                  example = "uBlock Origin";
                };

                installationMode = lib.mkOption {
                  type = lib.types.enum [
                    "force_installed"
                    "normal_installed"
                    "allowed"
                  ];
                  default = "force_installed";
                  description = ''
                    force_installed: installed automatically, cannot be removed or disabled.
                    normal_installed: installed automatically, can be disabled but not removed.
                    allowed: user may install manually.
                  '';
                };

                toolbarPin = lib.mkOption {
                  type = lib.types.enum [
                    "force_pinned"
                    "pinned"
                    "unpinned"
                  ];
                  default = "force_pinned";
                  description = "Toolbar pin state for the extension.";
                };
              };
            }
          );
          default = [ ];
          description = "Chromium/Helium extensions to manage via enterprise policy.";
          example = lib.literalExpression ''
            [
              { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; name = "uBlock Origin"; }
              { id = "chphlpgkkbolifaimnlloiipkdnihall"; name = "OneTab"; installationMode = "normal_installed"; }
            ]
          '';
        };

        defaultInstallationMode = lib.mkOption {
          type = lib.types.enum [
            "allowed"
            "blocked"
          ];
          default = "allowed";
          description = ''
            Default policy for extensions NOT listed in chromiumExtensions.
            Set to "blocked" for allowlist-only security (prevents installing unlisted extensions).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        programs.chromium = {
          enable = true;

          extraOpts.ExtensionSettings = {
            "*" = {
              installation_mode = cfg.defaultInstallationMode;
            };
          }
          // (builtins.listToAttrs (
            map (ext: {
              name = ext.id;
              value = {
                installation_mode = ext.installationMode;
                toolbar_pin = ext.toolbarPin;
                update_url = "https://clients2.google.com/service/update2/crx";
              };
            }) cfg.chromiumExtensions
          ));

          # Chromium 150+ deprecates MV2. Some extensions may be MV2-only.
          # 2 = allow both MV2 and MV3 (matches macOS config).
          extraOpts.ExtensionManifestV2Availability = 2;
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
