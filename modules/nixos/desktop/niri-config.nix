# Niri Wayland compositor: DRM health checks, GPU recovery, metrics
_: {
  flake.nixosModules.niri-config =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.niri-desktop;
      niriPkg = pkgs.niri-unstable;
      inherit (import ../../../lib/default.nix lib)
        harden
        hardenUser
        onFailure
        mkStateDir
        ;
      drmHealthcheck = pkgs.writeShellApplication {
        name = "niri-drm-healthcheck";
        runtimeInputs = with pkgs; [
          procps
          systemd
        ];
        text = builtins.readFile ../../../scripts/niri-drm-healthcheck.sh;
      };
      displayWatchdog = pkgs.writeShellApplication {
        name = "display-watchdog";
        runtimeInputs = with pkgs; [
          procps
          systemd
          kbd
          gawk # login-screen guard parses `loginctl list-sessions` with awk
        ];
        text = builtins.readFile ../../../scripts/display-watchdog.sh;
      };
    in
    {
      options.services.niri-desktop = {
        enable = lib.mkEnableOption "Niri Wayland compositor with XWayland support";
      };

      config = lib.mkIf cfg.enable {
        programs.niri = {
          enable = true;
          package = niriPkg;
        };

        systemd.tmpfiles.rules = [
          (mkStateDir "/var/lib/niri-drm-healthcheck" "0755" config.users.primaryUser "users")
          (mkStateDir "/var/lib/display-watchdog" "0755" "root" "root")
          (mkStateDir "/var/lib/niri-health-metrics" "0755" "root" "root")
        ];

        systemd = {
          user = {
            units =
              let
                unitFiles = builtins.readDir "${niriPkg}/lib/systemd/user";
                mkUnit =
                  name:
                  let
                    baseText = builtins.readFile "${niriPkg}/lib/systemd/user/${name}";
                    text =
                      if name == "niri.service" then
                        let
                          noBindsTo =
                            builtins.replaceStrings [ "BindsTo=graphical-session.target" ] [ "Wants=graphical-session.target" ]
                              baseText;
                          unitLimits =
                            builtins.replaceStrings
                              [ "[Unit]" ]
                              [
                                ''
                                    [Unit]
                                  StartLimitBurst=3
                                  StartLimitIntervalSec=60
                                  # Defense-in-depth against headless starts: the
                                  # user manager only has XDG_SESSION_ID in its
                                  # environment after a real SDDM login ran
                                  # `systemctl --user import-environment`
                                  # (NixOS's session wrapper imports it). A
                                  # lingering boot must NEVER run the compositor
                                  # — a headless niri blocks the next real login
                                  # with "A niri session is already running".
                                  ConditionEnvironment=XDG_SESSION_ID''
                              ]
                              noBindsTo;
                        in
                        unitLimits
                        # Restart=on-failure (not always): a CLEAN exit is the
                        # logout path (Mod+Shift+Q / session end). Restart=always
                        # respawns a headless niri after logout, which blocks the
                        # next SDDM login with "A niri session is already running".
                        # Crashes (signals, nonzero) still auto-restart.
                        + "\nRestart=on-failure\nRestartSec=2s\nOOMScoreAdjust=-1000\nLimitNPROC=infinity\nLimitNOFILE=524288\nIOSchedulingClass=best-effort\nIOSchedulingPriority=3\n"
                        + "\n[Install]\nWantedBy=graphical-session.target\n"
                      else
                        baseText;
                  in
                  {
                    inherit text;
                  };
              in
              lib.listToAttrs (
                map
                  (name: {
                    inherit name;
                    value = mkUnit name;
                  })
                  (
                    lib.filter (name: lib.hasSuffix ".service" name || lib.hasSuffix ".target" name) (
                      builtins.attrNames unitFiles
                    )
                  )
              );

            services.niri-drm-healthcheck = {
              description = "Detect niri DRM zombie state and restart niri";
              # Only run inside a real login session. The user manager only
              # carries XDG_SESSION_ID after niri-session ran
              # `systemctl --user import-environment` (pam_systemd sets it for
              # every session). Pre-login (lingering boot, SDDM greeter
              # manager) the healthcheck has nothing to heal — a niri restart
              # attempted there can only ever (re)start a HEADLESS niri, which
              # is exactly the 2026-08-18 amplifier: the healthcheck
              # restart-looped the zombie every 2 min. The script keeps its own
              # login-screen guard as defense-in-depth.
              unitConfig.ConditionEnvironment = "XDG_SESSION_ID";
              serviceConfig = hardenUser { MemoryMax = "256M"; } // {
                Type = "oneshot";
                ExecStart = lib.getExe drmHealthcheck;
              };
            };

            timers.niri-drm-healthcheck = {
              description = "Check niri DRM health every 60 seconds";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "60s";
                OnUnitActiveSec = "60s";
                AccuracySec = "10s";
              };
            };
          };

          services = {
            display-watchdog = {
              description = "Detect dead display (connected but no signal) and recover";
              path = with pkgs; [ kbd ];
              inherit onFailure;
              serviceConfig = lib.mkMerge [
                {
                  Type = "oneshot";
                  ExecStart = lib.getExe displayWatchdog;
                  OOMScoreAdjust = -500;
                  Environment = "PRIMARY_USER=${config.users.primaryUser}";
                }
                (harden {
                  MemoryMax = "512M";
                  ReadWritePaths = [
                    "/sys/class/drm"
                    "/var/lib/display-watchdog"
                  ];
                })
              ];
            };

            niri-health-metrics = {
              description = "Niri compositor health metrics for node_exporter textfile";
              serviceConfig = lib.mkMerge [
                {
                  Type = "oneshot";
                  ExecStart =
                    let
                      healthMetricsScript = pkgs.writeShellApplication {
                        name = "niri-health-metrics";
                        runtimeInputs = [
                          pkgs.procps
                          pkgs.systemd
                          pkgs.gawk
                          pkgs.coreutils
                        ];
                        text = ''
                          OUT="/var/lib/prometheus-node-exporter/textfile_collectors/niri.prom"
                          TMP="''${OUT}.tmp"
                          TEXTFILE_DIR="/var/lib/prometheus-node-exporter/textfile_collectors"
                          mkdir -p "$TEXTFILE_DIR"

                          # State files for grace periods — prevent false alerts
                          # during niri's 2s auto-restart window (RestartSec=2s, StartLimitBurst=3)
                          # and during the logout window (session closes before niri exits).
                          # Requires 2 consecutive checks (~60s) of the condition before
                          # setting the flag. Same pattern as niri-drm-healthcheck.sh.
                          STATE_DIR="/var/lib/niri-health-metrics"
                          mkdir -p "$STATE_DIR" 2>/dev/null || true
                          DOWN_COUNT_FILE="$STATE_DIR/down_count"
                          ZOMBIE_COUNT_FILE="$STATE_DIR/zombie_count"

                          read_count() {
                            if [ -f "$1" ]; then
                              cat "$1" 2>/dev/null || echo 0
                            else
                              echo 0
                            fi
                          }

                          running=$(pgrep -x niri >/dev/null 2>&1 && echo 1 || echo 0)
                          restarts=$(journalctl --grep "Started niri" _SYSTEMD_USER_UNIT=niri.service --since "10 min" --no-pager --output cat 2>/dev/null | wc -l || true)
                          restarts="''${restarts:-0}"
                          drm_errors=$(journalctl --grep "Permission denied|DeviceMissing" _SYSTEMD_USER_UNIT=niri.service -n 11 --since "30 sec ago" --no-pager --output cat 2>/dev/null | wc -l || true)
                          drm_errors="''${drm_errors:-0}"

                          # Detect whether a graphical session is expected (user logged in via SDDM).
                          # This distinguishes "intentionally headless" (SSH-only, no login) from
                          # "desktop died" (user has a session but niri crashed).
                          # Uses the same loginctl approach as display-watchdog.sh.
                          graphical_session=0
                          found=$(
                            loginctl list-sessions --no-legend 2>/dev/null |
                              awk '{print $1}' |
                              while IFS= read -r sid; do
                                c=$(loginctl show-session "$sid" -p Class --value 2>/dev/null || true)
                                t=$(loginctl show-session "$sid" -p Type --value 2>/dev/null || true)
                                if [ "$c" = "user" ] && { [ "$t" = "wayland" ] || [ "$t" = "x11" ]; }; then
                                  echo 1
                                fi
                              done
                          ) || found=""
                          case "$found" in *1*) graphical_session=1 ;; esac

                          # "Desktop died" = user has a graphical session but niri is not running.
                          # This is the only condition that warrants an alert — not "niri down"
                          # when the user simply hasn't logged in (intentionally headless).
                          # Grace period: 2 consecutive checks (~60s) before alerting, to avoid
                          # false positives during niri's 2s auto-restart window.
                          desktop_died=0
                          if [ "$graphical_session" -eq 1 ] && [ "$running" -eq 0 ]; then
                            count=$(read_count "$DOWN_COUNT_FILE")
                            count=$((count + 1))
                            echo "$count" > "$DOWN_COUNT_FILE" 2>/dev/null || true
                            if [ "$count" -ge 2 ]; then
                              desktop_died=1
                            fi
                          else
                            rm -f "$DOWN_COUNT_FILE" 2>/dev/null || true
                          fi

                          # "Zombie session" = niri running with NO graphical session:
                          # a headless compositor. This is the exact 2026-08-18
                          # incident state — it blocks the next SDDM login with
                          # "A niri session is already running" (black screen).
                          # niri.service's ConditionEnvironment should make it
                          # unreachable; this metric is the tripwire if the class
                          # ever regresses. Grace: 2 consecutive checks so the
                          # seconds between logout-session-close and niri's clean
                          # exit don't page (Restart=on-failure doesn't respawn
                          # a clean logout exit).
                          zombie=0
                          if [ "$running" -eq 1 ] && [ "$graphical_session" -eq 0 ]; then
                            zcount=$(read_count "$ZOMBIE_COUNT_FILE")
                            zcount=$((zcount + 1))
                            echo "$zcount" > "$ZOMBIE_COUNT_FILE" 2>/dev/null || true
                            if [ "$zcount" -ge 2 ]; then
                              zombie=1
                            fi
                          else
                            rm -f "$ZOMBIE_COUNT_FILE" 2>/dev/null || true
                          fi

                          # "Crash loop" = niri restarted 3+ times in 10 min (StartLimitBurst=3).
                          crash_loop=0
                          if [ "$restarts" -ge 3 ]; then
                            crash_loop=1
                          fi

                          {
                            echo "niri_running $running"
                            echo "niri_graphical_session $graphical_session"
                            echo "niri_desktop_died $desktop_died"
                            echo "niri_zombie $zombie"
                            echo "niri_crash_loop $crash_loop"
                            echo "niri_restarts_10m $restarts"
                            echo "niri_drm_errors_30s $drm_errors"
                          } > "$TMP"

                          mv "$TMP" "$OUT"
                        '';
                      };
                    in
                    "${healthMetricsScript}/bin/niri-health-metrics";
                }
                (harden {
                  MemoryMax = "1G";
                  ReadWritePaths = [
                    "/var/lib/prometheus-node-exporter/textfile_collectors"
                    "/var/lib/niri-health-metrics"
                  ];
                })
              ];
            };
          };

          timers = {
            display-watchdog = {
              description = "Check for dead display every 30 seconds";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "30s";
                OnUnitActiveSec = "30s";
                AccuracySec = "5s";
              };
            };

            niri-health-metrics = {
              description = "Collect niri health metrics every 30s";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "30s";
                OnUnitActiveSec = "30s";
              };
            };
          };
        };

        environment.systemPackages = with pkgs; [
          xwayland-satellite
        ];
      };
    };
}
