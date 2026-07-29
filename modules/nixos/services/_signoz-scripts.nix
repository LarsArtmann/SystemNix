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
      echo "signoz-provision: starting (v3 — HTTP status code checking)"
      SIGNOZ_URL="http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}"
      CHANNEL_NAME="Discord Alerts"
      FAILED=0

      # Helper: check HTTP status code is 2xx
      check_status() {
        local label="$1" status="$2"
        if [ "$status" -ge 200 ] && [ "$status" -lt 300 ]; then
          echo "  OK $label (HTTP $status)"
        else
          echo "  FAILED $label (HTTP $status)" >&2
          FAILED=$((FAILED + 1))
        fi
      }

      # Deploy notification channels (idempotent: delete existing by name, then create fresh)
      WEBHOOK_FILE="${config.sops.secrets.discord_alert_webhook_url.path}"
      if [ -f "$WEBHOOK_FILE" ]; then
        echo "Deploying notification channels..."
        WEBHOOK_URL=$(cat "$WEBHOOK_FILE")
        EXISTING_CHANNELS=$(curl -sf "$SIGNOZ_URL/api/v1/channels" 2>/dev/null || echo '{"data":[]}')

        EXISTING_CHANNEL_ID=$(echo "$EXISTING_CHANNELS" | jq -r --arg n "$CHANNEL_NAME" '.data[] | select(.name == $n) | .id // empty' | head -1)
        if [ -n "$EXISTING_CHANNEL_ID" ]; then
          # Skip recreation: alert rules reference this receiver by name, so
          # deleting + recreating it conflicts ("alertmanager_config_conflict:
          # the receiver name has to be unique"). The channel persists with its
          # webhook across runs; only create when absent.
          echo "  Channel already exists: $CHANNEL_NAME ($EXISTING_CHANNEL_ID) — skipping creation"
        else
          CHANNEL_JSON=$(jq -n --arg url "$WEBHOOK_URL" '{
            name: "Discord Alerts",
            discord_configs: [{
              send_resolved: true,
              webhook_url: $url
            }]
          }')
          echo "  Creating channel: $CHANNEL_NAME"
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -X POST \
            -H "Content-Type: application/json" \
            -d "$CHANNEL_JSON" \
            "$SIGNOZ_URL/api/v1/channels")
          check_status "channel:$CHANNEL_NAME" "$STATUS"
        fi
      else
        echo "Skipping channels: Discord webhook secret not found at $WEBHOOK_FILE"
      fi

      # Deploy alert rules (idempotent: delete existing by name, then create fresh)
      echo "Deploying alert rules..."
      EXISTING_RULES=$(curl -sf --max-time 10 "$SIGNOZ_URL/api/v1/rules" 2>/dev/null || echo '{"data":{"rules":[]}}')

      for rule_file in /etc/signoz/rules/*.json; do
        if [ -f "$rule_file" ]; then
          RULE_NAME=$(jq -r '.alert // empty' "$rule_file")
          if [ -n "$RULE_NAME" ]; then
            EXISTING_ID=$(echo "$EXISTING_RULES" | jq -r --arg n "$RULE_NAME" '.data.rules[]? // empty | select(.alert == $n) | .id // empty' | head -1)
            if [ -n "$EXISTING_ID" ]; then
              echo "  Deleting existing: $RULE_NAME ($EXISTING_ID)"
              curl -sf --max-time 10 -X DELETE "$SIGNOZ_URL/api/v1/rules/$EXISTING_ID" 2>/dev/null || true
            fi
          fi
          echo "  Creating: $(basename "$rule_file")"
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -X POST \
            -H "Content-Type: application/json" \
            -d @"$rule_file" \
            "$SIGNOZ_URL/api/v1/rules")
          check_status "rule:$(basename "$rule_file" .json)" "$STATUS"
        fi
      done

      # Deploy dashboards
      echo "Deploying dashboards..."
      for dash_file in /etc/signoz/dashboards/*.json; do
        if [ -f "$dash_file" ]; then
          echo "  Applying: $(basename "$dash_file")"
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -X POST \
            -H "Content-Type: application/json" \
            -d @"$dash_file" \
            "$SIGNOZ_URL/api/v1/dashboards")
          check_status "dashboard:$(basename "$dash_file" .json)" "$STATUS"
        fi
      done

      # Verify: GET /api/v1/rules must return >0 rules
      echo "Verifying alert rules provisioned..."
      RULE_COUNT=$(curl -sf --max-time 10 "$SIGNOZ_URL/api/v1/rules" 2>/dev/null | jq '.data.rules | length' 2>/dev/null || echo 0)
      if [ "$RULE_COUNT" -gt 0 ]; then
        echo "  OK $RULE_COUNT alert rules confirmed"
      else
        echo "  FAILED: 0 alert rules after provisioning — POST may be failing silently" >&2
        FAILED=$((FAILED + 1))
      fi

      if [ "$FAILED" -gt 0 ]; then
        echo "Provisioning FAILED: $FAILED errors. See stderr above." >&2
        exit 1
      fi
      echo "Provisioning complete: 0 errors."
    '';
  };
}
