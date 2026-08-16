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
      pkgs.diffutils
    ];
    text = ''
      echo "signoz-provision: starting (v7 — converge rules + route policies + dashboards: skip-unchanged, PUT in place, verified deletes)"
      SIGNOZ_URL="http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}"
      CHANNEL_NAME="Discord Alerts"
      FAILED=0
      RESP=$(mktemp)

      # http METHOD PATH [JSON_BODY] → HTTP status in $HTTP_STATUS, body in $RESP.
      # Never or-true state mutations: every caller checks the status.
      http() {
        local method="$1" path="$2" body="''${3:-}"
        local args=(--silent --max-time 15 -o "$RESP" -w "%{http_code}" -X "$method")
        if [ -n "$body" ]; then
          args+=(-H "Content-Type: application/json" -d "$body")
        fi
        HTTP_STATUS=$(curl "''${args[@]}" "$SIGNOZ_URL$path") || HTTP_STATUS=000
      }

      ok() { [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; }

      fail() {
        echo "  FAILED: $*" >&2
        FAILED=$((FAILED + 1))
      }

      # ---------------- Notification channel ----------------
      # Create when absent, PUT when our owned fields (templates, webhook)
      # drift. Rules reference the receiver by NAME, so the name never changes.
      WEBHOOK_FILE="${config.sops.secrets.discord_alert_webhook_url.path}"
      if [ -f "$WEBHOOK_FILE" ]; then
        echo "Deploying notification channel..."
        WEBHOOK_URL=$(cat "$WEBHOOK_FILE")
        # Minimal Discord rendering — overrides alertmanager's discord.default.*
        # label-dump templates. Title = status/severity emoji + alertname,
        # body = per-alert description (value-expanded at rule-eval time) +
        # clickable ruleSource link (alertmanager.external_url makes it work).
        TITLE_TPL='{{ if eq .Status "firing" }}{{ if eq .CommonLabels.severity "warning" }}🟡{{ else }}🔴{{ end }}{{ else }}🟢{{ end }} {{ .CommonLabels.alertname }}'
        MESSAGE_TPL='{{ if eq .Status "firing" }}{{ range .Alerts }}{{ .Annotations.description }} — {{ .Labels.ruleSource }} {{ end }}{{ else }}Condition recovered.{{ end }}'
        CHANNEL_JSON=$(jq -n --arg url "$WEBHOOK_URL" --arg title "$TITLE_TPL" --arg message "$MESSAGE_TPL" '{
          name: "Discord Alerts",
          discord_configs: [{ send_resolved: true, webhook_url: $url, title: $title, message: $message }]
        }')
        DESIRED_CHANNEL_PROJ=$(jq -S '.discord_configs[0] | {send_resolved, webhook_url, title, message}' <<<"$CHANNEL_JSON")

        http GET /api/v1/channels
        if ! ok; then
          fail "channel list (HTTP $HTTP_STATUS)"
        else
          CHANNEL_ID=$(jq -r --arg n "$CHANNEL_NAME" '.data[]? | select(.name == $n) | .id' "$RESP" | head -1)
          if [ -z "$CHANNEL_ID" ]; then
            echo "  Creating channel: $CHANNEL_NAME"
            http POST /api/v1/channels "$CHANNEL_JSON"
            if ok; then
              echo "  OK channel created (HTTP $HTTP_STATUS)"
            else
              fail "channel create (HTTP $HTTP_STATUS): $(head -c 300 "$RESP")"
            fi
          else
            # .data is a stringified receiver config
            LIVE_CHANNEL_PROJ=$(jq -r --arg n "$CHANNEL_NAME" '.data[]? | select(.name == $n) | .data' "$RESP" | head -1 | jq -S 'try (.discord_configs[0] | {send_resolved, webhook_url, title, message}) catch null')
            if [ "$LIVE_CHANNEL_PROJ" = "$DESIRED_CHANNEL_PROJ" ]; then
              echo "  Channel unchanged: $CHANNEL_NAME — skipping"
            else
              echo "  Updating channel: $CHANNEL_NAME ($CHANNEL_ID)"
              http PUT "/api/v1/channels/$CHANNEL_ID" "$CHANNEL_JSON"
              if ok; then
                echo "  OK channel updated (HTTP $HTTP_STATUS)"
              else
                fail "channel update (HTTP $HTTP_STATUS): $(head -c 300 "$RESP")"
              fi
            fi
          fi
        fi
      else
        echo "Skipping channels: Discord webhook secret not found at $WEBHOOK_FILE"
      fi

      # ---------------- Alert rules (converge) ----------------
      # The v4 provisioner DELETEd + re-created every rule on every deploy:
      # fresh ruleIds made SigNoz emit fake RESOLVED/FIRING pairs, and an
      # or-true delete let duplicates pile up (3 zombie rules were live).
      # v5 converges instead:
      #   unchanged        → skip (zero notifications)
      #   changed           → PUT in place (ruleId preserved → no fake pairs)
      #   zombie duplicates → PUT the first, DELETE the rest (verified)
      #   removed from nix  → DELETE (verified)
      #   final             → convergence assertion on names + counts
      echo "Deploying alert rules (converge)..."
      RULES_PATH="/api/v1/rules"

      # Canonical projection of the fields we own. The live GET adds
      # id/state/timestamps and injects query-spec defaults (disabled,
      # stats, legend); projecting both sides through the same filter makes
      # "unchanged" actually detectable.
      CANON='{alert, ruleType, disabled, description, evalWindow, frequency, labels, annotations: (.annotations // {}), preferredChannels, condition: (.condition | {op, target, matchType, selectedQueryName, compositeQuery: (.compositeQuery | {queryType, panelType, queries: [.queries[] | {type, spec: {name: .spec.name, query: .spec.query, step: .spec.step}}]})})}'

      DESIRED_NAMES=()

      for rule_file in /etc/signoz/rules/*.json; do
        [ -f "$rule_file" ] || continue
        RULE_NAME=$(jq -r '.alert // empty' "$rule_file")
        if [ -z "$RULE_NAME" ]; then
          fail "$(basename "$rule_file"): no .alert field"
          continue
        fi
        DESIRED_NAMES+=("$RULE_NAME")

        http GET "$RULES_PATH"
        if ! ok; then
          fail "list rules before $RULE_NAME (HTTP $HTTP_STATUS)"
          continue
        fi

        # ids of ALL live copies of this name (catches zombie duplicates)
        mapfile -t IDS < <(jq -r --arg n "$RULE_NAME" '.data.rules[]? | select(.alert == $n) | .id' "$RESP")
        DESIRED_CANON=$(jq -S "$CANON" "$rule_file")

        if [ "''${#IDS[@]}" -eq 1 ]; then
          LIVE_OBJ=$(jq -c --arg n "$RULE_NAME" '[.data.rules[]? | select(.alert == $n)][0]' "$RESP")
          LIVE_CANON=$(jq -S "$CANON" <<<"$LIVE_OBJ")
          if [ "$LIVE_CANON" = "$DESIRED_CANON" ]; then
            echo "  Unchanged: $RULE_NAME — skipping"
            continue
          fi
          echo "  Updating in place: $RULE_NAME (''${IDS[0]})"
          http PUT "$RULES_PATH/''${IDS[0]}" "$(cat "$rule_file")"
          if ok; then
            echo "  OK rule updated: $RULE_NAME (HTTP $HTTP_STATUS)"
          else
            echo "  PUT failed (HTTP $HTTP_STATUS) — falling back to delete+create" >&2
            http DELETE "$RULES_PATH/''${IDS[0]}"
            if ! ok; then
              fail "delete $RULE_NAME before recreate (HTTP $HTTP_STATUS)"
              continue
            fi
            http POST "$RULES_PATH" "$(cat "$rule_file")"
            if ok; then
              echo "  OK rule recreated: $RULE_NAME (HTTP $HTTP_STATUS)"
            else
              fail "recreate $RULE_NAME (HTTP $HTTP_STATUS): $(head -c 300 "$RESP")"
            fi
          fi
        else
          for stale_id in "''${IDS[@]}"; do
            [ -n "$stale_id" ] || continue
            echo "  Deleting stale copy: $RULE_NAME ($stale_id)"
            http DELETE "$RULES_PATH/$stale_id"
            if ! ok; then
              fail "delete stale $RULE_NAME/$stale_id (HTTP $HTTP_STATUS): $(head -c 300 "$RESP")"
            fi
          done
          echo "  Creating: $RULE_NAME"
          http POST "$RULES_PATH" "$(cat "$rule_file")"
          if ok; then
            echo "  OK rule created: $RULE_NAME (HTTP $HTTP_STATUS)"
          else
            fail "create $RULE_NAME (HTTP $HTTP_STATUS): $(head -c 300 "$RESP")"
          fi
        fi
      done

      # Delete live rules that no longer exist in /etc/signoz/rules/
      http GET "$RULES_PATH"
      if ! ok; then
        fail "list rules for removal pass (HTTP $HTTP_STATUS)"
      else
        while IFS=$'\t' read -r live_id live_name; do
          [ -n "$live_id" ] || continue
          wanted=false
          for n in "''${DESIRED_NAMES[@]}"; do
            if [ "$n" = "$live_name" ]; then
              wanted=true
            fi
          done
          if [ "$wanted" = false ]; then
            echo "  Deleting removed rule: $live_name ($live_id)"
            http DELETE "$RULES_PATH/$live_id"
            if ! ok; then
              fail "delete removed $live_name (HTTP $HTTP_STATUS): $(head -c 300 "$RESP")"
            fi
          fi
        done < <(jq -r '.data.rules[]? | [.id, .alert] | @tsv' "$RESP")
      fi

      # ---------------- Convergence assertion ----------------
      echo "Verifying rule convergence..."
      http GET "$RULES_PATH"
      if ! ok; then
        fail "convergence check could not list rules (HTTP $HTTP_STATUS)"
      else
        LIVE_NAMES=$(jq -r '.data.rules[]?.alert' "$RESP" | sort)
        LIVE_TOTAL=$(jq -r '.data.rules | length' "$RESP")
        LIVE_UNIQUE=$(jq -r '.data.rules[]?.alert' "$RESP" | sort -u)
        DESIRED_SORTED=$(printf '%s\n' "''${DESIRED_NAMES[@]}" | sort)
        if [ "$LIVE_NAMES" = "$DESIRED_SORTED" ] && [ "$LIVE_UNIQUE" = "$LIVE_NAMES" ] && [ "$LIVE_TOTAL" -eq "''${#DESIRED_NAMES[@]}" ]; then
          echo "  OK $LIVE_TOTAL rules provisioned, exact desired set, zero duplicates"
        else
          echo "  Convergence mismatch — desired vs live:" >&2
          diff <(printf '%s\n' "$DESIRED_SORTED") <(printf '%s\n' "$LIVE_NAMES") >&2 || true
          fail "rules did not converge (live=$LIVE_TOTAL desired=''${#DESIRED_NAMES[@]})"
        fi
      fi

      # ---------------- Route policies (converge) ----------------
      # SigNoz's dispatcher routes alerts ONLY via route policies looked
      # up by ruleId (nfmanager.Match → GetAllByName(ruleId) → expr-lang
      # over alert labels → channels). v1-API rules never get policies
      # auto-created (that path only runs for rules carrying
      # notificationSettings from the UI), so without this loop every
      # alert is silently DROPPED — no receiver, no error (2026-08-16
      # regression). Converge exactly one policy per desired ruleId;
      # tag "systemnix" marks ownership — NEVER touch untagged policies
      # (they may be user-created).
      echo "Deploying route policies (converge)..."
      POLICIES_PATH="/api/v1/route_policies"
      OWNED_TAG="systemnix"

      http GET "$RULES_PATH"
      if ! ok; then
        fail "policy convergence could not list rules (HTTP $HTTP_STATUS)"
      else
        mapfile -t DESIRED_PAIRS < <(jq -r --argjson names "$(printf '%s\n' "''${DESIRED_NAMES[@]}" | jq -R . | jq -s .)" '.data.rules[]? | select(.alert as $a | $names | index($a)) | [.id, .alert] | @tsv' "$RESP")

        http GET "$POLICIES_PATH"
        if ! ok; then
          fail "policy convergence could not list policies (HTTP $HTTP_STATUS)"
        else
          # our policies as id<TAB>name pairs
          mapfile -t OWNED_PAIRS < <(jq -r --arg t "$OWNED_TAG" '.data[]? | select((.tags // []) | index($t)) | [.id, .name] | @tsv' "$RESP")

          # delete orphans + duplicates (keep first per name)
          declare -A KEPT=()
          for pair in "''${OWNED_PAIRS[@]}"; do
            [ -n "$pair" ] || continue
            pol_id="''${pair%%$'\t'*}"
            pol_name="''${pair#*$'\t'}"
            wanted=false
            for dpair in "''${DESIRED_PAIRS[@]}"; do
              if [ "''${dpair%%$'\t'*}" = "$pol_name" ]; then
                wanted=true
                break
              fi
            done
            if [ "$wanted" = false ]; then
              echo "  Deleting orphan policy: $pol_name ($pol_id)"
              http DELETE "$POLICIES_PATH/$pol_id"
              ok || fail "delete orphan policy $pol_name (HTTP $HTTP_STATUS): $(head -c 300 "$RESP")"
            elif [ -n "''${KEPT[$pol_name]:-}" ]; then
              echo "  Deleting duplicate policy: $pol_name ($pol_id)"
              http DELETE "$POLICIES_PATH/$pol_id"
              ok || fail "delete duplicate policy $pol_name (HTTP $HTTP_STATUS): $(head -c 300 "$RESP")"
            else
              KEPT[$pol_name]=1
            fi
          done

          for dpair in "''${DESIRED_PAIRS[@]}"; do
            [ -n "$dpair" ] || continue
            rid="''${dpair%%$'\t'*}"
            rname="''${dpair#*$'\t'}"
            if [ -n "''${KEPT[$rid]:-}" ]; then
              echo "  Policy unchanged: $rname — skipping"
              continue
            fi
            echo "  Creating policy: $rname ($rid)"
            POLICY_JSON=$(jq -n \
              --arg name "$rid" \
              --arg expr "ruleId == \"$rid\"" \
              --arg ch "$CHANNEL_NAME" \
              --arg desc "SystemNix auto-provisioned: route rule '$rname' to $CHANNEL_NAME" \
              '{expression: $expr, kind: "policy", channels: [$ch], name: $name, description: $desc, tags: ["systemnix", "auto-provisioned"]}')
            http POST "$POLICIES_PATH" "$POLICY_JSON"
            if ok; then
              echo "  OK policy created: $rname (HTTP $HTTP_STATUS)"
            else
              fail "create policy $rname (HTTP $HTTP_STATUS): $(head -c 300 "$RESP")"
            fi
          done
        fi
      fi

      # ---------------- Policy convergence assertion ----------------
      echo "Verifying route-policy convergence..."
      http GET "$POLICIES_PATH"
      if ! ok; then
        fail "policy assertion could not list policies (HTTP $HTTP_STATUS)"
      else
        OWNED_NAMES=$(jq -r --arg t "$OWNED_TAG" '.data[]? | select((.tags // []) | index($t)) | .name' "$RESP" | sort)
        OWNED_COUNT=$(jq -r --arg t "$OWNED_TAG" '[.data[]? | select((.tags // []) | index($t))] | length' "$RESP")
        DESIRED_POLICY_NAMES=$(printf '%s\n' "''${DESIRED_PAIRS[@]}" | cut -f1 | sort)
        if [ "$OWNED_NAMES" = "$DESIRED_POLICY_NAMES" ] && [ "$OWNED_COUNT" -eq "''${#DESIRED_PAIRS[@]}" ]; then
          echo "  OK $OWNED_COUNT route policies — exact one-per-rule, zero orphans"
        else
          echo "  Policy convergence mismatch — desired ruleIds vs owned policies:" >&2
          diff <(printf '%s\n' "$DESIRED_POLICY_NAMES") <(printf '%s\n' "$OWNED_NAMES") >&2 || true
          fail "route policies did not converge (owned=$OWNED_COUNT desired=''${#DESIRED_PAIRS[@]})"
        fi
      fi

      # ---------------- Dashboards (converge, native v2) ----------------
      # Dashboards are native v2 (Perses, schemaVersion v6) JSONs with a
      # stable slug in .name and tag owner=systemnix. Converge like rules:
      #   unchanged          → skip (spec roundtrip is byte-identical, verified)
      #   changed            → PUT in place (uuid preserved)
      #   zombie duplicates  → the pre-v2 provisioner POSTed a fresh copy per
      #                         deploy (251 accumulated); anything sharing a
      #                         managed display name but not our slug is one —
      #                         DELETE
      #   removed from nix   → DELETE owned orphans
      # Dashboard failures are HARD failures — the old best-effort mode let
      # every dashboard 400 silently for a month (v1 schema vs v2 API).
      echo "Deploying dashboards (converge, native v2)..."
      DASH_PATH="/api/v2/dashboards"

      list_all_dashboards() {
        # paginated full listing → JSON array on stdout
        local all='[]' offset=0 page_count
        while :; do
          http GET "$DASH_PATH?limit=100&offset=$offset"
          if ! ok; then
            fail "list dashboards (offset $offset, HTTP $HTTP_STATUS)"
            return 1
          fi
          page_count=$(jq '.data.dashboards | length' "$RESP")
          all=$(jq -s '.[0] + .[1]' <(printf '%s' "$all") <(jq '.data.dashboards' "$RESP"))
          [ "$page_count" -lt 100 ] && break
          offset=$((offset + 100))
        done
        printf '%s' "$all"
      }

      DESIRED_DASH_SLUGS=()
      for dash_file in /etc/signoz/dashboards/*.json; do
        [ -f "$dash_file" ] || continue
        SLUG=$(jq -r '.name // empty' "$dash_file")
        DISPLAY=$(jq -r '.spec.display.name // empty' "$dash_file")
        if [ -z "$SLUG" ] || [ -z "$DISPLAY" ]; then
          fail "$(basename "$dash_file"): missing .name slug or .spec.display.name"
          continue
        fi
        DESIRED_DASH_SLUGS+=("$SLUG")

        ALL_DASH=$(list_all_dashboards) || continue

        # zombie copies: same display name, different slug (legacy spam)
        mapfile -t ZOMBIE_IDS < <(jq -r --arg d "$DISPLAY" --arg s "$SLUG" '.[] | select(.spec.display.name == $d and .name != $s) | .id' <<<"$ALL_DASH")
        for zid in "''${ZOMBIE_IDS[@]}"; do
          [ -n "$zid" ] || continue
          echo "  Deleting zombie copy: $DISPLAY ($zid)"
          http DELETE "$DASH_PATH/$zid"
          ok || fail "delete zombie dashboard $zid (HTTP $HTTP_STATUS)"
        done

        mapfile -t IDS < <(jq -r --arg s "$SLUG" '.[] | select(.name == $s) | .id' <<<"$ALL_DASH")
        DESIRED_SPEC=$(jq -S '.spec' "$dash_file")
        if [ "''${#IDS[@]}" -eq 1 ] && [ -n "''${IDS[0]}" ]; then
          http GET "$DASH_PATH/''${IDS[0]}"
          if ok; then
            LIVE_SPEC=$(jq -S '.data.spec' "$RESP")
            if [ "$LIVE_SPEC" = "$DESIRED_SPEC" ]; then
              echo "  Unchanged: $SLUG — skipping"
              continue
            fi
            echo "  Updating in place: $SLUG (''${IDS[0]})"
            http PUT "$DASH_PATH/''${IDS[0]}" "$(cat "$dash_file")"
            if ok; then
              echo "  OK dashboard updated: $SLUG (HTTP $HTTP_STATUS)"
            else
              fail "update dashboard $SLUG (HTTP $HTTP_STATUS): $(head -c 300 "$RESP")"
            fi
          else
            fail "get dashboard $SLUG (''${IDS[0]}, HTTP $HTTP_STATUS)"
          fi
        else
          for extra in "''${IDS[@]:1}"; do
            [ -n "$extra" ] || continue
            echo "  Deleting duplicate slug copy: $SLUG ($extra)"
            http DELETE "$DASH_PATH/$extra"
            ok || fail "delete duplicate $extra (HTTP $HTTP_STATUS)"
          done
          echo "  Creating: $SLUG"
          http POST "$DASH_PATH" "$(cat "$dash_file")"
          if ok; then
            echo "  OK dashboard created: $SLUG (HTTP $HTTP_STATUS)"
          else
            fail "create dashboard $SLUG (HTTP $HTTP_STATUS): $(head -c 300 "$RESP")"
          fi
        fi
      done

      # orphan pass: delete OWNED (tag owner=systemnix) dashboards no longer desired
      ALL_DASH=$(list_all_dashboards) || ALL_DASH='[]'
      mapfile -t ORPHAN_IDS < <(jq -r --argjson names "$(printf '%s\n' "''${DESIRED_DASH_SLUGS[@]}" | jq -R . | jq -s .)" '.[] | select(any(.tags[]?; .key == "owner" and .value == "systemnix")) | select(.name as $n | $names | index($n) | not) | .id' <<<"$ALL_DASH")
      for oid in "''${ORPHAN_IDS[@]}"; do
        [ -n "$oid" ] || continue
        echo "  Deleting orphan dashboard: $oid"
        http DELETE "$DASH_PATH/$oid"
        ok || fail "delete orphan dashboard $oid (HTTP $HTTP_STATUS)"
      done

      # ---------------- Dashboard convergence assertion ----------------
      echo "Verifying dashboard convergence..."
      ALL_DASH=$(list_all_dashboards)
      if [ -n "$ALL_DASH" ]; then
        OWNED=$(jq -r '[.[] | select(any(.tags[]?; .key == "owner" and .value == "systemnix"))] | length' <<<"$ALL_DASH")
        if [ "$OWNED" -eq "''${#DESIRED_DASH_SLUGS[@]}" ]; then
          echo "  OK $OWNED dashboards provisioned, exact desired set"
        else
          fail "dashboards did not converge (owned=$OWNED desired=''${#DESIRED_DASH_SLUGS[@]})"
        fi
      fi

      rm -f "$RESP"

      if [ "$FAILED" -gt 0 ]; then
        echo "Provisioning FAILED: $FAILED errors. See stderr above." >&2
        exit 1
      fi
      echo "Provisioning complete: 0 errors."
    '';
  };
}
