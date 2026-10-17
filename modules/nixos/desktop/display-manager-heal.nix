# Display-manager self-healing: stale session units (the headless-niri
# lockout class) are recognized and stopped at every DM restart AND every
# sddm login attempt; restore-storm session.json bloat and unfixable states
# are reported with the exact manual fix. Born from the 2026-10-17 lockout:
# an oomd teardown left niri.service active without a seat, and every SDDM
# login bounced with "A niri session is already running".
_: {
  flake.nixosModules.display-manager-heal =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.display-manager-heal;
      healScript = pkgs.writeShellApplication {
        name = "display-manager-heal";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.glibc
          pkgs.jq
          pkgs.systemd
          pkgs.util-linux
        ];
        text = builtins.readFile ../../../scripts/display-manager-heal.sh;
      };
      healBin = "${healScript}/bin/display-manager-heal";
      healArgs =
        lib.concatMap (user: [
          "--user"
          user
        ]) cfg.users
        ++ lib.concatMap (unit: [
          "--unit"
          unit
        ]) cfg.sessionUnits
        ++ [
          "--storm-threshold"
          (toString cfg.restoreStormThreshold)
        ];
    in
    {
      options.services.display-manager-heal = {
        enable = lib.mkEnableOption "display-manager session healer (stale-session auto-fix + login-path guard)";
        users = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "lars" ];
          description = ''
            Graphical users whose lingering session managers are checked for
            stale (seatless) session units on every display-manager restart
            and every sddm login attempt.
          '';
        };
        sessionUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "niri.service"
            "dms.service"
            "niri-session-manager.service"
            "swayidle.service"
            "helium.service"
          ];
          description = ''
            User units that block new logins when found active without a
            logind graphical session (the headless-compositor lockout).
          '';
        };
        restoreStormThreshold = lib.mkOption {
          type = lib.types.ints.positive;
          default = 50;
          description = ''
            Saved-window count in niri-session-manager's session.json above
            which the healer warns about a login restore storm (the
            2026-08-31 152-empty-ghostty class). Report-only: the file is
            user data and is never rewritten automatically.
          '';
        };
      };

      config = lib.mkMerge [
        {
          # The repo's SDDM composition root is services.display-manager-config
          # (modules/nixos/desktop/display-manager.nix) — a phantom
          # `services.display-manager` option never existed; it broke every
          # evo-x2 eval from 2026-10-17 00:56 until this fix.
          services.display-manager-heal.enable = lib.mkDefault config.services.display-manager-config.enable;
        }
        (lib.mkIf (cfg.enable && config.services.display-manager-config.enable) {
          assertions = [
            {
              assertion = cfg.users != [ ];
              message = "services.display-manager-heal.users must not be empty";
            }
            {
              assertion = cfg.sessionUnits != [ ];
              message = "services.display-manager-heal.sessionUnits must not be empty";
            }
          ];

          # 1) Every (re)start of the display manager heals first —
          #    `systemctl restart display-manager.service` becomes a fix, not
          #    a no-op, for the stale-session lockout class.
          systemd.services.display-manager.preStart = lib.mkBefore ''
            ${healBin} ${lib.escapeShellArgs healArgs}
          '';

          # 2) Every sddm login attempt heals before the session starts, so
          #    the bounce-loop path (user just types the password again)
          #    self-heals without any manual restart. Runs in the auth phase
          #    (after password verification, before pam_systemd creates the
          #    new session) so the zombie check sees the pre-login state;
          #    `optional` control means a heal failure can never block login.
          security.pam.services.sddm.rules.auth.display-manager-heal = {
            order = config.security.pam.services.sddm.rules.auth.login.order + 10;
            control = "optional";
            modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
            args = [
              healBin
              "stdout"
            ]
            ++ healArgs;
          };

          # 3) From a live session, wheel may restart the display manager
          #    without an auth agent (DMS owns polkit, so an interactive
          #    prompt only exists while a graphical session is up).
          security.polkit.extraConfig = ''
            polkit.addRule(function(action, subject) {
                if (action.id == "org.freedesktop.systemd1.manage-units"
                    && subject.isInGroup("wheel")
                    && action.lookup("unit") == "display-manager.service") {
                    return polkit.Result.YES;
                }
            });
          '';
        })
      ];
    };
}
