# larsartmann.com deploy-freshness monitor (desktop notification)
#
# Alerts when the production site's /build-info.json `builtAt` timestamp is older
# than maxAgeDays — the "CI silently dead" outage class from 2026-08-14 (billing
# outage ran ~10h with zero jobs started and no notification reached anyone).
# The website repo ships the marker endpoint; this module watches it from the
# always-on NixOS box because GitHub Actions scheduled jobs are billing-blocked.
_: {
  flake.nixosModules.website-deploy-monitor =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.website-deploy-monitor;
      inherit (config.users) primaryUser;
      inherit (import ../../../lib/default.nix lib) hardenUser mkDesktopNotifyService;
      uid = builtins.toString config.users.users.${cfg.user}.uid;

      checkScript = ''
        STATE_DIR="$HOME/.local/state/website-deploy-monitor"
        mkdir -p "$STATE_DIR"
        STATE_FILE="$STATE_DIR/last-alerted-built-at"

        info=$(curl --silent --max-time 10 "${cfg.url}" 2>/dev/null)
        if [ -z "$info" ]; then
          logger -t "website-deploy-monitor" "fetch failed: ${cfg.url} unreachable (uptime checks own availability)"
          exit 0
        fi

        built_at=$(printf '%s' "$info" | jq -r '.builtAt // empty')
        if [ -z "$built_at" ]; then
          logger -t "website-deploy-monitor" "marker has no builtAt field: $info"
          exit 0
        fi

        built_epoch=$(date --date="$built_at" +%s)
        now_epoch=$(date +%s)
        age_seconds=$(( now_epoch - built_epoch ))
        max_age_seconds=$(( ${toString cfg.maxAgeDays} * 86400 ))

        if [ "$age_seconds" -lt "$max_age_seconds" ]; then
          # Fresh deploy — clear any previous alert state.
          rm -f "$STATE_FILE"
          logger -t "website-deploy-monitor" "fresh: builtAt=$built_at ($(( age_seconds / 3600 ))h old)"
          exit 0
        fi

        # Stale — alert once per stale build (not on every timer tick).
        if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE" 2>/dev/null)" = "$built_at" ]; then
          exit 0
        fi

        age_hours=$(( age_seconds / 3600 ))
        notify-send \
          -u critical \
          -a "website-deploy-monitor" \
          -i "web-browser" \
          "larsartmann.com deploy is stale" \
          "Last build is ''${age_hours}h old (built $built_at) — expected < ${toString cfg.maxAgeDays}d. CI is billing-blocked; run pnpm run deploy." 2>/dev/null || true
        echo "$built_at" > "$STATE_FILE"
        logger -t "website-deploy-monitor" "STALE: builtAt=$built_at is ''${age_hours}h old (threshold: ${toString cfg.maxAgeDays}d)"
      '';

      notifyService = mkDesktopNotifyService pkgs {
        name = "website-deploy-monitor";
        description = "Check larsartmann.com deploy freshness and notify when stale";
        inherit checkScript;
        runtimeInputs = with pkgs; [
          curl
          jq
          libnotify
          coreutils
          util-linux
        ];
        inherit (cfg) user;
        inherit uid;
        inherit (cfg) interval;
        bootDelay = "5min";
        hardenFn = hardenUser;
      };
    in
    {
      options.services.website-deploy-monitor = {
        enable = lib.mkEnableOption "larsartmann.com deploy-freshness monitoring with desktop notifications";

        url = lib.mkOption {
          type = lib.types.str;
          default = "https://larsartmann.com/build-info.json";
          description = "Deploy-marker endpoint exposing a builtAt ISO timestamp";
        };

        maxAgeDays = lib.mkOption {
          type = lib.types.ints.positive;
          default = 3;
          description = "Alert when the newest deploy is older than this many days";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "1h";
          description = "Systemd timer interval for freshness checks";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = primaryUser;
          description = "User to send desktop notifications to";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd = {
          timers.website-deploy-monitor = notifyService.timer;
          services.website-deploy-monitor = notifyService.service;
        };
      };
    };
}
