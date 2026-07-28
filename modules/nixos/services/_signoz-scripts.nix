# SigNoz shell scripts: readiness probe, provisioning (channels, rules, dashboards)
# Extracted from signoz.nix to keep the module focused on service configuration.
{
  pkgs,
  cfg,
  config,
}:
{
  waitReadyScript = pkgs.writeShellApplication {
    name = "signoz-wait-ready";
    runtimeInputs = [
      pkgs.curl
      pkgs.coreutils
    ];
    text = ''
      end=$((SECONDS + 120))
      while [ $SECONDS -lt $end ]; do
        if curl -sf http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}/api/v1/version >/dev/null 2>&1; then
          exit 0
        fi
        sleep 2
      done
      echo "SigNoz did not become ready within 120s" >&2
      exit 1
    '';
  };

  provisionScript = pkgs.writeShellApplication {
    name = "signoz-provision";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      echo "signoz-provision: starting (v2 — jq .data.rules[] fix)"
      SIGNOZ_URL="http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}"
      CHANNEL_NAME="Discord Alerts"

      # Deploy notification channels (idempotent: delete existing by name, then create fresh)
      WEBHOOK_FILE="${config.sops.secrets.discord_alert_webhook_url.path}"
      if [ -f "$WEBHOOK_FILE" ]; then
        echo "Deploying notification channels..."
        WEBHOOK_URL=$(cat "$WEBHOOK_FILE")
        EXISTING_CHANNELS=$(curl -sf "$SIGNOZ_URL/api/v1/channels" 2>/dev/null || echo '{"data":[]}')

        EXISTING_CHANNEL_ID=$(echo "$EXISTING_CHANNELS" | jq -r --arg n "$CHANNEL_NAME" '.data[] | select(.name == $n) | .id // empty' | head -1)
        if [ -n "$EXISTING_CHANNEL_ID" ]; then
          echo "  Deleting existing channel: $CHANNEL_NAME ($EXISTING_CHANNEL_ID)"
          curl -sf --max-time 10 -X DELETE "$SIGNOZ_URL/api/v1/channels/$EXISTING_CHANNEL_ID" 2>/dev/null || true
        fi

        CHANNEL_JSON=$(jq -n --arg url "$WEBHOOK_URL" '{
          name: "Discord Alerts",
          discord_configs: [{
            send_resolved: true,
            webhook_url: $url
          }]
        }')
        echo "  Creating channel: $CHANNEL_NAME"
        curl -sf --max-time 10 -X POST \
          -H "Content-Type: application/json" \
          -d "$CHANNEL_JSON" \
          "$SIGNOZ_URL/api/v1/channels" 2>/dev/null || true
      else
        echo "Skipping channels: Discord webhook secret not found at $WEBHOOK_FILE"
      fi

      # Deploy alert rules (idempotent: delete existing by name, then create fresh)
      echo "Deploying alert rules..."
      EXISTING_RULES=$(curl -sf --max-time 10 "$SIGNOZ_URL/api/v1/rules" 2>/dev/null || echo '{"data":{"rules":[]}}')

      for rule_file in /etc/signoz/rules/*.json; do
        if [ -f "$rule_file" ]; then
          RULE_NAME=$(jq -r '.data.rule.name // empty' "$rule_file")
          if [ -n "$RULE_NAME" ]; then
            EXISTING_ID=$(echo "$EXISTING_RULES" | jq -r --arg n "$RULE_NAME" '.data.rules[]? // empty | select(.name == $n) | .id // empty' | head -1)
            if [ -n "$EXISTING_ID" ]; then
              echo "  Deleting existing: $RULE_NAME ($EXISTING_ID)"
              curl -sf --max-time 10 -X DELETE "$SIGNOZ_URL/api/v1/rules/$EXISTING_ID" 2>/dev/null || true
            fi
          fi
          echo "  Creating: $(basename "$rule_file")"
          curl -sf --max-time 10 -X POST \
            -H "Content-Type: application/json" \
            -d @"$rule_file" \
            "$SIGNOZ_URL/api/v1/rules" 2>/dev/null || true
        fi
      done

      # Deploy dashboards
      echo "Deploying dashboards..."
      for dash_file in /etc/signoz/dashboards/*.json; do
        if [ -f "$dash_file" ]; then
          echo "  Applying: $(basename "$dash_file")"
          curl -sf --max-time 10 -X POST \
            -H "Content-Type: application/json" \
            -d @"$dash_file" \
            "$SIGNOZ_URL/api/v1/dashboards" 2>/dev/null || true
        fi
      done

      echo "Provisioning complete."
    '';
  };
}
