# Scheduled tasks for NixOS using systemd timers
{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (config.users) primaryUser;
  uid = builtins.toString config.users.users.${primaryUser}.uid;
  harden = import ../../../lib/systemd.nix {inherit lib;};
in {
  systemd = {
    timers = {
      crush-update-providers = {
        description = "Daily Crush AI provider update";
        timerConfig = {
          OnCalendar = "00:00";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
        wantedBy = ["timers.target"];
      };

      blocklist-auto-update = {
        description = "Weekly blocklist hash update";
        timerConfig = {
          OnCalendar = "Mon *-*-* 04:00";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        wantedBy = ["timers.target"];
      };

      service-health-check = {
        description = "Service health check";
        timerConfig = {
          OnCalendar = "*:0/15";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
        wantedBy = ["timers.target"];
      };

      docker-prune = {
        description = lib.mkForce "Weekly Docker system prune";
        wantedBy = ["timers.target"];
        timerConfig = lib.mkForce {
          OnCalendar = "Mon *-*-* 03:00";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };

      rust-target-cleanup = {
        description = "Weekly Rust target/ cleanup (dirs >2GB)";
        timerConfig = {
          OnCalendar = "Sun *-*-* 05:00";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        wantedBy = ["timers.target"];
      };

      stale-lsp-cleanup = {
        description = "Daily cleanup of stale LSP processes (gopls, etc.) older than 24h";
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
        wantedBy = ["timers.target"];
      };
    };

    services = {
      # Reusable failure notification template — use via `OnFailure = "notify-failure@%n.service"`
      "notify-failure@" = {
        description = "Notify on failure of %i";
        serviceConfig = {
          Type = "oneshot";
          User = primaryUser;
          Environment = [
            "DISPLAY=:0"
            "WAYLAND_DISPLAY=wayland-1"
            "XDG_RUNTIME_DIR=/run/user/${uid}"
          ];
          ExecStart = let
            notifyFailure = pkgs.writeShellApplication {
              name = "notify-failure";
              runtimeInputs = [pkgs.libnotify pkgs.util-linux];
              text = ''
                notify-send -u critical "Scheduled task failed" "%i — check journalctl -u %i" 2>/dev/null || \
                  logger -t "%i" -p user.err "Scheduled task failed — check journalctl -u %i"
              '';
            };
          in "${notifyFailure}/bin/notify-failure";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      crush-update-providers = {
        description = "Update Crush AI providers";
        onFailure = ["notify-failure@%n.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe' pkgs.nur.repos.charmbracelet.crush "crush"} update-providers";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      blocklist-auto-update = {
        description = "Download blocklists and update hashes in config";
        onFailure = ["notify-failure@%n.service"];
        path = [pkgs.git pkgs.nix pkgs.gawk pkgs.gnused pkgs.python3];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = let
            dnsUpdate = pkgs.writeShellApplication {
              name = "dns-update";
              runtimeInputs = [pkgs.git pkgs.nix pkgs.gawk pkgs.gnused];
              text = builtins.readFile ../../../scripts/dns-update.sh;
            };
          in "${dnsUpdate}/bin/dns-update";
          WorkingDirectory = "/home/${primaryUser}/projects/SystemNix";
          User = primaryUser;
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      service-health-check = {
        description = "Check critical services and notify on failure";
        onFailure = ["notify-failure@%n.service"];
        path = [pkgs.systemd pkgs.libnotify];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = let
            criticalSystemServices = [
              "caddy"
              "forgejo"
              "unbound"
              "dnsblockd"
              "postgresql"
              "docker"
            ];
            ignoredFailedServices = [
              "session-*"
              "user@*"
            ];
            checkBlock = svc: "check_service ${svc}";
            ignorePattern = builtins.concatStringsSep " | " ignoredFailedServices;
            healthCheck = pkgs.writeShellApplication {
              name = "service-health-check";
              runtimeInputs = [pkgs.systemd pkgs.libnotify pkgs.coreutils pkgs.gnugrep];
              text = ''
                export DISPLAY=:0
                export WAYLAND_DISPLAY=wayland-1
                XDG_RUNTIME_DIR=/run/user/$(id -u)
                export XDG_RUNTIME_DIR

                FAILED=""
                TOTAL=0

                check_service() {
                    TOTAL=$((TOTAL + 1))
                    # Retry up to 3 times with 2s sleep — services may be
                    # restarting during a deploy (activating/reloading state).
                    for _attempt in 1 2 3; do
                        if systemctl is-active --quiet "$1" 2>/dev/null; then
                            return 0
                        fi
                        sleep 2
                    done
                    FAILED="$FAILED\n  $1"
                    return 1
                }

                # shellcheck disable=SC2329
                check_user_service() {
                    TOTAL=$((TOTAL + 1))
                    for _attempt in 1 2 3; do
                        if systemctl --user is-active --quiet "$1" 2>/dev/null; then
                            return 0
                        fi
                        sleep 2
                    done
                    FAILED="$FAILED\n  $1 (user)"
                    return 1
                }

                # === Critical system services — must be running ===
                ${builtins.concatStringsSep "\n" (map checkBlock criticalSystemServices)}

                # === Dynamic: catch any other failed system services ===
                while IFS= read -r svc; do
                    case "$svc" in
                        ${ignorePattern})
                            ;;
                        *)
                            if ! echo -e "$FAILED" | grep -qF "  $svc"; then
                                TOTAL=$((TOTAL + 1))
                                FAILED="$FAILED\n  $svc (failed)"
                            fi
                            ;;
                    esac
                done < <(systemctl --failed --no-legend --type=service 2>/dev/null | awk '{print $1}')

                # === Dynamic: catch any failed user services ===
                while IFS= read -r svc; do
                    case "$svc" in
                        ${ignorePattern})
                            ;;
                        *)
                            if ! echo -e "$FAILED" | grep -qF "  $svc (user)"; then
                                TOTAL=$((TOTAL + 1))
                                FAILED="$FAILED\n  $svc (user, failed)"
                            fi
                            ;;
                    esac
                done < <(systemctl --user --failed --no-legend --type=service 2>/dev/null | awk '{print $1}')

                # === Report ===
                if [ -n "$FAILED" ]; then
                    notify-send -u critical "Health Check: services down" "$(echo -e "$FAILED")" 2>/dev/null || true
                    echo "FAILED:$(echo -e "$FAILED")"
                    exit 1
                else
                    echo "OK: $TOTAL/$TOTAL critical services active, no failed services"
                    exit 0
                fi
              '';
            };
          in "${healthCheck}/bin/service-health-check";
          User = primaryUser;
          Environment = [
            "DISPLAY=:0"
            "WAYLAND_DISPLAY=wayland-1"
            "XDG_RUNTIME_DIR=/run/user/${uid}"
          ];
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      docker-prune = {
        description = lib.mkForce "Prune unused Docker resources";
        onFailure = ["notify-failure@%n.service"];
        path = [pkgs.docker];
        serviceConfig = lib.mkForce {
          Type = "oneshot";
          ExecStart = "${lib.getExe pkgs.docker} system prune -f --filter until=168h";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      rust-target-cleanup = {
        description = "Weekly Rust target/ cleanup (dirs >2GB)";
        onFailure = ["notify-failure@%n.service"];
        serviceConfig =
          harden {
            MemoryMax = "256M";
            ProtectHome = "read-only";
            ReadWritePaths = ["/home/${primaryUser}/projects"];
          }
          // {
            Type = "oneshot";
            User = primaryUser;
            Environment = [
              "DISPLAY=:0"
              "WAYLAND_DISPLAY=wayland-1"
              "XDG_RUNTIME_DIR=/run/user/${uid}"
            ];
            ExecStart = let
              rustCleanup = pkgs.writeShellApplication {
                name = "rust-target-cleanup";
                runtimeInputs = [pkgs.cargo-sweep pkgs.findutils pkgs.coreutils pkgs.libnotify];
                text = ''
                  SIZE_THRESHOLD_KB=$((2 * 1024 * 1024))
                  SEARCH_ROOTS=("/home/${primaryUser}/projects")
                  TOTAL_FREED_KB=0
                  CLEANED=0
                  SKIPPED=0
                  FAILED=0

                  log() { echo "[rust-target-cleanup] $*"; }

                  for root in "''${SEARCH_ROOTS[@]}"; do
                    [ -d "$root" ] || continue

                    while IFS= read -r target_dir; do
                      [ -d "$target_dir" ] || continue
                      dir_size_kb=$(du -sk "$target_dir" 2>/dev/null | cut -f1)

                      if [ -z "$dir_size_kb" ] || [ "$dir_size_kb" -lt "$SIZE_THRESHOLD_KB" ]; then
                        SKIPPED=$((SKIPPED + 1))
                        continue
                      fi

                      dir_size_human=$(numfmt --to=iec --suffix=B "$((dir_size_kb * 1024))")
                      project=$(dirname "$target_dir")

                      if [ -f "$project/Cargo.toml" ]; then
                        log "cargo-sweep --time 7d in $project ($dir_size_human)"
                        if cargo-sweep --time 7d --installed 2>/dev/null \
                           || cargo-sweep --time 7d; then
                          new_size_kb=$(du -sk "$target_dir" 2>/dev/null | cut -f1 || echo 0)
                          freed_kb=$((dir_size_kb - new_size_kb))
                          TOTAL_FREED_KB=$((TOTAL_FREED_KB + freed_kb))
                          CLEANED=$((CLEANED + 1))
                          freed_human=$(numfmt --to=iec --suffix=B "$((freed_kb * 1024))")
                          log "Cleaned $project — freed $freed_human"
                        else
                          log "cargo-sweep failed for $project, falling back to full removal"
                          rm -rf "$target_dir"
                          TOTAL_FREED_KB=$((TOTAL_FREED_KB + dir_size_kb))
                          CLEANED=$((CLEANED + 1))
                          log "Fallback removed $target_dir — freed $dir_size_human"
                        fi
                      else
                        log "Removing orphaned target/ $target_dir ($dir_size_human)"
                        if rm -rf "$target_dir"; then
                          TOTAL_FREED_KB=$((TOTAL_FREED_KB + dir_size_kb))
                          CLEANED=$((CLEANED + 1))
                          log "Removed orphan $target_dir — freed $dir_size_human"
                        else
                          FAILED=$((FAILED + 1))
                          log "FAILED to remove $target_dir"
                        fi
                      fi
                    done < <(find "$root" \
                      -type d \
                      -name target \
                      -not -path '*/.*')
                  done

                  TOTAL_FREED_HUMAN=$(numfmt --to=iec --suffix=B "$((TOTAL_FREED_KB * 1024))")
                  log "Done: cleaned $CLEANED, skipped $SKIPPED (under 2GB), failed $FAILED, freed $TOTAL_FREED_HUMAN"

                  if [ "$CLEANED" -gt 0 ]; then
                    notify-send -u low \
                      "Rust target/ cleanup" \
                      "Cleaned $CLEANED projects, freed $TOTAL_FREED_HUMAN" 2>/dev/null || true
                  fi
                '';
              };
            in "${rustCleanup}/bin/rust-target-cleanup";
            StandardOutput = "journal";
            StandardError = "journal";
          };
      };

      stale-lsp-cleanup = {
        description = "Kill stale LSP processes (gopls, etc.) running longer than 24h";
        onFailure = ["notify-failure@%n.service"];
        serviceConfig =
          harden {
            MemoryMax = "128M";
            ProtectHome = "read-only";
          }
          // {
            Type = "oneshot";
            User = primaryUser;
            ExecStart = let
              lspCleanup = pkgs.writeShellApplication {
                name = "stale-lsp-cleanup";
                runtimeInputs = [pkgs.procps pkgs.coreutils];
                text = ''
                  MAX_AGE_SECONDS=$((24 * 3600))
                  LSP_PROCESS_NAMES=("gopls" "typescript-language-server" "vtsls" "rust-analyzer" "lua-language-server")
                  KILLED=0

                  for proc_name in "''${LSP_PROCESS_NAMES[@]}"; do
                    while IFS= read -r pid; do
                      [ -z "$pid" ] && continue
                      elapsed=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
                      [ -z "$elapsed" ] && continue
                      if [ "$elapsed" -gt "$MAX_AGE_SECONDS" ]; then
                        elapsed_h=$((elapsed / 3600))
                        echo "Killing stale $proc_name (PID $pid, running ''${elapsed_h}h)"
                        kill "$pid" 2>/dev/null || true
                        KILLED=$((KILLED + 1))
                      fi
                    done < <(pgrep -u "$USER" "$proc_name" 2>/dev/null)
                  done

                  echo "Done: killed $KILLED stale LSP processes"
                '';
              };
            in "${lspCleanup}/bin/stale-lsp-cleanup";
            StandardOutput = "journal";
            StandardError = "journal";
          };
      };
    };
  };
}
