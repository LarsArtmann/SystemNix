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
          ExecStart = pkgs.writeShellApplication {
            name = "notify-failure";
            runtimeInputs = [pkgs.libnotify pkgs.util-linux];
            text = ''
              notify-send -u critical "Scheduled task failed" "%i — check journalctl -u %i" 2>/dev/null || \
                logger -t "%i" -p user.err "Scheduled task failed — check journalctl -u %i"
            '';
          };
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      crush-update-providers = {
        description = "Update Crush AI providers";
        onFailure = ["notify-failure@%n.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.nur.repos.charmbracelet.crush}/bin/crush update-providers";
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
          ExecStart = "${pkgs.writeShellScript "dns-update" (builtins.readFile ../../../scripts/dns-update.sh)}";
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
          ExecStart = "${pkgs.writeShellScript "service-health-check" (builtins.readFile ../scripts/service-health-check)}";
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
          ExecStart = "${pkgs.docker}/bin/docker system prune -f --filter until=168h";
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
            ExecStart = pkgs.writeShellApplication {
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
            StandardOutput = "journal";
            StandardError = "journal";
          };
      };
    };
  };
}
