# Scheduled tasks for NixOS using systemd timers
{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (config.users) primaryUser;
  uid = builtins.toString config.users.users.${primaryUser}.uid;
  inherit (import ../../../lib/default.nix lib) harden onFailure;

  # tmp-cleanup script text — hoisted here (NOT inline in the unit) so the
  # eval-time assertion below can prove the systemd-private-* exclusion
  # survives refactors. A store-path ExecStart is invisible to cross-module
  # audits (tmp-cleaner-audit.nix); this text is the one thing eval CAN see.
  tmpCleanupText = ''
    THRESHOLD_MIN=240 # 4 hours — active builds touch files constantly

    # -x prevents crossing into bind-mounted filesystems under /tmp
    before_kb=$(du -skx /tmp 2>/dev/null | cut -f1 || true)
    before_kb=''${before_kb:-0}

    removed=0
    # Only top-level non-dotfile entries — dotfiles (.X11-unix, .font-unix,
    # lock files) are protected. Per-entry descendant check prevents
    # removing dirs that contain recently-touched files (active builds
    # writing into a dir created hours ago: dir mtime stays old but file
    # mtimes are fresh). This is MORE conservative than cleanOnBoot (which
    # wipes everything on reboot). -xdev prevents find from descending
    # into mount points on other filesystems (defense-in-depth).
    for entry in /tmp/*; do
      [ -e "$entry" ] || continue
      [ -L "$entry" ] && continue  # never follow symlinks
      [ -S "$entry" ] && continue  # skip sockets
      [ -p "$entry" ] && continue  # skip named pipes
      case "$entry" in
        # systemd-managed PrivateTmp instance dirs are live service
        # infrastructure, not stale tmp: deleting the backing dir
        # invalidates the private /tmp mount inside the unit's
        # namespace, and forgejo then failed EVERY mirror sync for
        # 12 days with "open /tmp/forgejo-clone-credentials-N: no
        # such file or directory" (2026-08-18..30). systemd's own
        # tmpfiles-clean excludes them; this script must too. The
        # mtime check below cannot protect them — an idle or
        # already-broken service writes nothing into its private
        # tmp for hours, which is exactly the stale profile this
        # script targets.
        /tmp/systemd-private-*) continue ;;
      esac
      # If ANY descendant was touched in the last THRESHOLD_MIN, the
      # entry is active — skip it.
      if find "$entry" -xdev -mmin "-$THRESHOLD_MIN" -print -quit 2>/dev/null | grep -q .; then
        continue
      fi
      # rm errors (permission denied on other users' files) are
      # non-fatal — suppress stderr and continue to next entry.
      rm -rf --one-file-system -- "$entry" 2>/dev/null && removed=$((removed + 1)) || true
    done

    after_kb=$(du -skx /tmp 2>/dev/null | cut -f1 || true)
    after_kb=''${after_kb:-0}
    freed_kb=$((before_kb - after_kb))
    freed_human=$(numfmt --to=iec --suffix=B "$((freed_kb * 1024))" 2>/dev/null || echo "''${freed_kb}KB")
    echo "tmp-cleanup: removed $removed stale entries, freed $freed_human from /tmp"
  '';
in
{
  # Eval-time self-check on the hoisted text above: removing the exclusion
  # must fail `nix flake check`, not wait for the next 12-day outage
  # (2026-08-18..30: forgejo 16,318 mirror errors, discordsync 550 attachment
  # download failures, paperless celery, immich-ml — full story in
  # modules/nixos/services/tmp-cleaner-audit.nix).
  assertions = [
    {
      assertion = lib.hasInfix "systemd-private-*) continue" tmpCleanupText;
      message = ''
        tmp-cleanup guard: the systemd-private-* exclusion was removed from
        the tmp-cleanup script text (platforms/nixos/system/scheduled-tasks.nix).
        Those dirs are systemd PrivateTmp backing infrastructure: deleting one
        unlinks the bind-mount source, and every file creation inside the
        unit's private /tmp then fails ENOENT — self-perpetuating, because a
        broken service writes nothing and its dir always profiles as stale.
        Restore the case-arm exclusion (tests/test-tmp-cleanup.nix asserts the
        behavior). See AGENTS.md "NEVER let any /tmp cleaner touch
        systemd-private-*".
      '';
    }
  ];

  systemd = {
    timers = {
      crush-update-providers = {
        description = "Daily Crush AI provider update";
        timerConfig = {
          OnCalendar = "00:00";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
        wantedBy = [ "timers.target" ];
      };

      blocklist-auto-update = {
        description = "Weekly blocklist hash update";
        timerConfig = {
          OnCalendar = "Mon *-*-* 04:00";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        wantedBy = [ "timers.target" ];
      };

      service-health-check = {
        description = "Service health check";
        timerConfig = {
          OnCalendar = "*:0/15";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
        wantedBy = [ "timers.target" ];
      };

      docker-prune = {
        description = lib.mkForce "Weekly Docker system prune";
        wantedBy = [ "timers.target" ];
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
        wantedBy = [ "timers.target" ];
      };

      stale-lsp-cleanup = {
        description = "Kill stale LSP processes (gopls, etc.) older than 5min — runs every 5min";
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "5min";
          AccuracySec = "30s";
        };
        wantedBy = [ "timers.target" ];
      };

      disk-growth-check = {
        description = "Daily disk growth trend check — alert if /data grows >5G in 24h";
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        wantedBy = [ "timers.target" ];
      };

      nix-build-cleanup = {
        description = "Cleanup of orphaned Nix build sandboxes in /nix/var/nix/builds";
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "4h";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
        wantedBy = [ "timers.target" ];
      };

      tmp-cleanup = {
        description = "Remove stale entries in /tmp older than 4 hours";
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "4h";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
        wantedBy = [ "timers.target" ];
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
          ExecStart =
            let
              notifyFailure = pkgs.writeShellApplication {
                name = "notify-failure";
                runtimeInputs = [
                  pkgs.libnotify
                  pkgs.util-linux
                ];
                text = ''
                  UNIT="''${1:-unknown}"
                  notify-send -u critical "Scheduled task failed" "$UNIT — check journalctl -u $UNIT" 2>/dev/null || \
                    logger -t "$UNIT" -p user.err "Scheduled task failed — check journalctl -u $UNIT"
                '';
              };
            in
            "${notifyFailure}/bin/notify-failure %i";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      crush-update-providers = {
        description = "Update Crush AI providers";
        inherit onFailure;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe' pkgs.nur.repos.charmbracelet.crush "crush"} update-providers";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      blocklist-auto-update = {
        description = "Download blocklists and update hashes in config";
        inherit onFailure;
        path = [
          pkgs.git
          pkgs.nix
          pkgs.gawk
          pkgs.gnused
          pkgs.python3
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart =
            let
              dnsUpdate = pkgs.writeShellApplication {
                name = "dns-update";
                runtimeInputs = [
                  pkgs.git
                  pkgs.nix
                  pkgs.gawk
                  pkgs.gnused
                ];
                text = builtins.readFile ../../../scripts/dns-update.sh;
              };
            in
            "${dnsUpdate}/bin/dns-update";
          WorkingDirectory = "/home/${primaryUser}/projects/SystemNix";
          User = primaryUser;
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      service-health-check = {
        description = "Check critical services and notify on failure";
        inherit onFailure;
        path = [
          pkgs.systemd
          pkgs.libnotify
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart =
            let
              criticalSystemServices = [
                "caddy"
                "forgejo"
                "dnsblockd"
                "postgresql"
              ];
              ignoredFailedServices = [
                "session-*"
                "user@*"
              ];
              checkBlock = svc: "check_service ${svc}";
              ignorePattern = builtins.concatStringsSep " | " ignoredFailedServices;
              healthCheck = pkgs.writeShellApplication {
                name = "service-health-check";
                runtimeInputs = [
                  pkgs.systemd
                  pkgs.libnotify
                  pkgs.coreutils
                  pkgs.gnugrep
                  pkgs.gawk
                ];
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
                  done < <(systemctl --failed --no-legend --type=service 2>/dev/null | awk '{print $2}')

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
                  done < <(systemctl --user --failed --no-legend --type=service 2>/dev/null | awk '{print $2}')

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
            in
            "${healthCheck}/bin/service-health-check";
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
        inherit onFailure;
        path = [ pkgs.docker ];
        # WHY granular, not `system prune`: on docker 29.x `system prune --filter
        # until=168h` logged 0B reclaimed while 8 GB build cache + 2-3-week-old
        # dangling images sat eligible (2026-08-31), and without `-a` tagged-but-unused
        # images (old version tags) are NEVER collectible. Volumes stay out on purpose.
        serviceConfig = lib.mkForce {
          Type = "oneshot";
          ExecStart = [
            "${lib.getExe pkgs.docker} container prune -f"
            "${lib.getExe pkgs.docker} network prune -f"
            "${lib.getExe pkgs.docker} image prune -af --filter until=168h"
            "${lib.getExe pkgs.docker} builder prune -f --filter until=168h"
          ];
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      rust-target-cleanup = {
        description = "Weekly Rust target/ cleanup (dirs >2GB)";
        inherit onFailure;
        serviceConfig =
          harden {
            MemoryMax = "256M";
            ProtectHome = "read-only";
            ReadWritePaths = [ "/home/${primaryUser}/projects" ];
          }
          // {
            Type = "oneshot";
            User = primaryUser;
            Environment = [
              "DISPLAY=:0"
              "WAYLAND_DISPLAY=wayland-1"
              "XDG_RUNTIME_DIR=/run/user/${uid}"
            ];
            ExecStart =
              let
                rustCleanup = pkgs.writeShellApplication {
                  name = "rust-target-cleanup";
                  runtimeInputs = [
                    pkgs.cargo-sweep
                    pkgs.findutils
                    pkgs.coreutils
                    pkgs.libnotify
                  ];
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
                            new_size_kb=$(du -sk "$target_dir" 2>/dev/null | cut -f1 || true)
                            new_size_kb=''${new_size_kb:-0}
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
              in
              "${rustCleanup}/bin/rust-target-cleanup";
            StandardOutput = "journal";
            StandardError = "journal";
          };
      };

      stale-lsp-cleanup = {
        description = "Kill stale LSP processes (gopls, etc.) running longer than 5min";
        inherit onFailure;
        serviceConfig =
          harden {
            MemoryMax = "128M";
            ProtectHome = "read-only";
          }
          // {
            Type = "oneshot";
            User = primaryUser;
            ExecStart =
              let
                lspCleanup = pkgs.writeShellApplication {
                  name = "stale-lsp-cleanup";
                  runtimeInputs = [
                    pkgs.procps
                    pkgs.coreutils
                  ];
                  text = ''
                    MAX_AGE_SECONDS=$((5 * 60))
                    LSP_PROCESS_NAMES=("gopls" "typescript-language-server" "vtsls" "rust-analyzer" "lua-language-server")
                    KILLED=0

                    for proc_name in "''${LSP_PROCESS_NAMES[@]}"; do
                      while IFS= read -r pid; do
                        [ -z "$pid" ] && continue
                        elapsed=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
                        [ -z "$elapsed" ] && continue
                        if [ "$elapsed" -gt "$MAX_AGE_SECONDS" ]; then
                          elapsed_m=$((elapsed / 60))
                          elapsed_s=$((elapsed % 60))
                          echo "Killing stale $proc_name (PID $pid, running ''${elapsed_m}m''${elapsed_s}s)"
                          kill "$pid" 2>/dev/null || true
                          KILLED=$((KILLED + 1))
                        fi
                      done < <(pgrep -u "$USER" "$proc_name" 2>/dev/null)
                    done

                    echo "Done: killed $KILLED stale LSP processes"
                  '';
                };
              in
              "${lspCleanup}/bin/stale-lsp-cleanup";
            StandardOutput = "journal";
            StandardError = "journal";
          };
      };

      nix-build-cleanup = {
        description = "Remove orphaned Nix build sandboxes older than 1 hour";
        inherit onFailure;
        serviceConfig =
          harden {
            MemoryMax = "128M";
            ProtectHome = true;
            ReadWritePaths = [ "/nix/var/nix/builds" ];
          }
          // {
            Type = "oneshot";
            ExecStart =
              let
                buildCleanup = pkgs.writeShellApplication {
                  name = "nix-build-cleanup";
                  runtimeInputs = [
                    pkgs.findutils
                    pkgs.coreutils
                  ];
                  text = ''
                    BUILD_DIR="/nix/var/nix/builds"
                    [ -d "$BUILD_DIR" ] || exit 0

                    before_kb=$(du -sk "$BUILD_DIR" 2>/dev/null | cut -f1 || true)
                    before_kb=''${before_kb:-0}

                    # Remove sandboxes untouched for >1h (active builds constantly write)
                    find "$BUILD_DIR" -maxdepth 1 -type d -name 'nix-*' -mmin +60 -exec rm -rf {} +

                    after_kb=$(du -sk "$BUILD_DIR" 2>/dev/null | cut -f1 || true)
                    after_kb=''${after_kb:-0}
                    freed_kb=$((before_kb - after_kb))
                    freed_human=$(numfmt --to=iec --suffix=B "$((freed_kb * 1024))" 2>/dev/null || echo "''${freed_kb}KB")

                    orphan_count=$(find "$BUILD_DIR" -maxdepth 1 -type d -name 'nix-*' 2>/dev/null | wc -l)
                    echo "Cleaned orphaned build sandboxes — freed $freed_human, $orphan_count remaining"
                  '';
                };
              in
              "${buildCleanup}/bin/nix-build-cleanup";
            StandardOutput = "journal";
            StandardError = "journal";
          };
      };

      tmp-cleanup = {
        description = "Remove stale top-level entries in /tmp untouched for >4h";
        inherit onFailure;
        serviceConfig = lib.mkMerge [
          (harden {
            MemoryMax = "128M";
            ProtectHome = true;
            PrivateTmp = false; # MUST see the real /tmp, not a private tmpfs
            ReadWritePaths = [ "/tmp" ];
          })
          {
            Type = "oneshot";
            ExecStart =
              let
                tmpCleanup = pkgs.writeShellApplication {
                  name = "tmp-cleanup";
                  runtimeInputs = [
                    pkgs.findutils
                    pkgs.coreutils
                  ];
                  text = tmpCleanupText;
                };
              in
              "${tmpCleanup}/bin/tmp-cleanup";
            StandardOutput = "journal";
            StandardError = "journal";
          }
        ];
      };

      disk-growth-check = {
        description = "Check /data disk growth trend and alert if >5G/day";
        inherit onFailure;
        # StateDirectory, NOT ReadWritePaths + preStart mkdir: systemd builds
        # the mount namespace BEFORE any ExecStartPre, so a ReadWritePaths
        # entry pointing at a missing dir aborts with status=226/NAMESPACE
        # and the in-unit mkdir can never create its own namespace path
        # (live bug: unit failed 226 on every run while /var/lib/disk-growth
        # was absent, blinding the /data growth alert for days). PID 1
        # creates StateDirectory dirs before namespace assembly.
        serviceConfig =
          harden {
            MemoryMax = "128M";
            ProtectHome = "read-only";
            StateDirectory = "disk-growth";
          }
          // {
            Type = "oneshot";
            ExecStart =
              let
                diskGrowth = pkgs.writeShellApplication {
                  name = "disk-growth-check";
                  runtimeInputs = [
                    pkgs.coreutils
                    pkgs.util-linux
                  ];
                  text = ''
                    STATE_DIR="/var/lib/disk-growth"
                    STATE_FILE="$STATE_DIR/last_usage_bytes"
                    THRESHOLD=$((5 * 1024 * 1024 * 1024))
                    MOUNT_POINT="/data"

                    current_bytes=$(df --output=used --block-size=1 "$MOUNT_POINT" | tail -1 | tr -d ' ')

                    if [ -z "$current_bytes" ]; then
                      echo "ERROR: could not read disk usage for $MOUNT_POINT"
                      exit 1
                    fi

                    current_human=$(numfmt --to=iec --suffix=B "$current_bytes")
                    echo "Current /data usage: $current_human"

                    if [ -f "$STATE_FILE" ]; then
                      last_bytes=$(cat "$STATE_FILE")
                      delta=$((current_bytes - last_bytes))
                      delta_human=$(numfmt --to=iec --suffix=B "$delta")

                      if [ "$delta" -gt "$THRESHOLD" ]; then
                        echo "WARNING: /data grew $delta_human in 24h (threshold: 5G)"
                        exit 1
                      else
                        echo "Growth: $delta_human in 24h (under 5G threshold)"
                      fi
                    else
                      echo "No previous measurement — recording baseline"
                    fi

                    mkdir -p "$STATE_DIR"
                    printf '%s' "$current_bytes" > "$STATE_FILE"
                  '';
                };
              in
              "${diskGrowth}/bin/disk-growth-check";
            StandardOutput = "journal";
            StandardError = "journal";
          };
      };
    };
  };
}
