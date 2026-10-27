# Runbook: docs/services/paperless.md (triage section)
# paperless-triage — confidence gate IN FRONT of the tag-gated paperless-gpt
# pipeline (decision-triage productionization P1, plan
# docs/planning/2026-10-27_21-17_paperless-decision-triage-productionization-plan.md §3).
#
# WHY (the 2026-10-19 burn class): paperless-gpt's AUTO_TAG_MAX_RETRIES=3
# counts ~10s poll cycles, so ~30-60s of LLM unavailability terminal-fails
# EVERY queued document (70 receipts, 210 attempts, 0 successes). This gate
# owns ADMISSION: a document only receives the `paperless-gpt-auto` tag
# after a local yes/no verdict clears a probability-margin threshold.
# The tag is the seam — paperless-gpt keeps extraction, unchanged.
#
# DESIGN CORRECTIONS vs the plan text (both verified 2026-10-27, session
# crush-triage-exec):
#   1. VERDICT PROVIDER = llama-chat (:8850), NOT FastFlowLM. The deployed
#      flm v1.0.2 has NO logprobs support (binary-proven: zero
#      `top_logprobs` strings across the whole store deployment; the
#      upstream docs describing logprobs postdate our pin, and the v1.0.3+
#      bump is blocked by the NPU start-failure + live-serve validation
#      rule). llama-server 0.6.0 (llama-chat) carries top_logprobs
#      binary-proven, and routing through ai-meter's `llama-chat` upstream
#      matches the owner's single-endpoint direction (2026-10-27).
#      paperless-gpt EXTRACTION stays on FastFlowLM — only the verdict
#      moved. Margin = renormalized p(YES)-p(NO) over the first content
#      token's top_logprobs (confidence saturates near 1.0 on right AND
#      wrong answers — bench §d; margin is the gate signal).
#   2. verdict-down exits 0, not nonzero (deviation from plan §3 P1): a
#      5-min timer whose unit exits nonzero on every sweep of an outage
#      walks into startLimitBurst (5/300s) within ~25 min and systemd then
#      REFUSES timer activations until a manual reset-failed — strictly
#      worse visibility than the designed alarm pair (the
#      paperless_triage_refusals_total{reason="verdict_down"} textfile
#      metric + its Gatus absence-check, both alive while the unit runs).
#      The plan's intent — NO document ever reaches a terminal state from
#      an upstream outage, and the failure is visible — is preserved.
#   3. The PSI maintenance-entry-gate runs INSIDE the script as a soft
#      skip (same start-limit reasoning; plus a refused-during-IO-storm
#      sweep would alert-storm alongside the storm's own alerts). A PSI
#      skip leaves last-sweep untouched, so >1h of storm-skips surfaces
#      through the backup-coordination freshness entry.
#
# Privacy: verdicts send OCR text to LOCAL llama-chat only — zero WAN
# egress, zero cloud keys (P2 shadow mode, the cloud arm, stays gated on
# the plan §6 owner pack). Secrets: the paperless API token is
# RUNTIME-MINTED (paperless-gpt-token pattern — zero sops); the ai-meter
# client key is runtime-minted by ai-meter-keys when that proxy is on.
#
# Scope guards: NEVER writes document_type (workflow 1000003 anomaly,
# paperless.md trap #2); only ADDS tags via bulk_edit modify_tags (PATCH
# /api/documents/<id>/ REPLACES the whole tag set — trap #3); custom
# fields are P3 (plan §6 Q4-Q6), NOT written here.
_: {
  flake.nixosModules.paperless-triage =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
  cfg = config.services.paperless-triage;
  inherit (import ../../../lib/default.nix lib)
    harden
    serviceDefaults
    serviceOneshotDefaults
    onFailure
    ioTier
    ports
    mkStateDir
    ;

  paperlessCfg = config.services.paperless;
  paperlessPort = paperlessCfg.port;
  # The pass tag IS paperless-gpt's auto tag — one seam, one vocabulary.
  # Full-path `or` access: the paperless-gpt module may be absent (VM
  # tests, other hosts) — a bare attrpath binding would fail evaluation.
  passTag = config.services.paperless-gpt.autoTag or "paperless-gpt-auto";
  completeTag = config.services.paperless-gpt.autoTagComplete or "paperless-gpt-auto-complete";
  failTag = config.services.paperless-gpt.failTag or "paperless-gpt-failed";
  aiMeterEnabled = config.services.ai-meter.enable or false;

  stateDir = "/var/lib/paperless-triage";
  runtimeEnvFile = "/run/paperless-triage/env";
  textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

  verdictBaseUrl =
    if aiMeterEnabled then
      "http://127.0.0.1:${toString ports.ai-meter}/v1/llama-chat"
    else
      "http://127.0.0.1:${toString config.services.llama-chat.port}/v1";
  verdictModel = config.services.llama-chat.alias or "qwen3.6-35b-a3b-aggressive";

  # Runtime token mint (bank-sync / paperless-gpt-token pattern): idempotent
  # drf_create_token as the paperless user, tmpfs-only storage, then a
  # `+`-privileged chown so the triage user can read its 0400 env file.
  tokenChownScript = pkgs.writeShellScript "paperless-triage-token-chown" ''
    chown ${cfg.user}:${cfg.group} ${runtimeEnvFile}
    chmod 0400 ${runtimeEnvFile}
  '';

  sweepEnvironment = {
    PAPERLESS_BASE_URL = "http://127.0.0.1:${toString paperlessPort}";
    VERDICT_BASE_URL = verdictBaseUrl;
    VERDICT_MODEL = verdictModel;
    VERDICT_TIMEOUT = "180";
    TRIAGE_THRESHOLD = toString cfg.threshold;
    TRIAGE_MAX_DOCS = toString cfg.maxDocsPerSweep;
    TRIAGE_MAX_CHARS = toString cfg.maxContentChars;
    TAG_PASS = passTag;
    TAG_REVIEW = cfg.reviewTag;
    TAG_ENCRYPTED = "encrypted";
    TAG_COMPLETE = completeTag;
    TAG_FAILED = failTag;
    STATE_DIR = stateDir;
    TEXTFILE_DIR = textfileDir;
  };

  sweepScript = pkgs.writeShellApplication {
    name = "paperless-triage-sweep";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
    ];
    text = ''
      set -euo pipefail

      die() { echo "paperless-triage: ERROR: $*" >&2; exit 1; }
      warn() { echo "paperless-triage: WARN: $*" >&2; }

      STATE_FILE="''${STATE_DIR}/state.json"
      MARKER="''${STATE_DIR}/last-sweep"
      PROM="''${TEXTFILE_DIR}/paperless_triage.prom"
      mkdir -p "''${STATE_DIR}" "''${TEXTFILE_DIR}"
      umask 077

      # margin_from_logprobs <response.json>: prints
      #   "MARGIN <float in [-1,1]>"  renormalized p(YES)-p(NO) over the
      #       FIRST content token's top_logprobs (yes/no token variants
      #       summed as PROBABILITIES, then renormalized so the threshold
      #       is scale-free), or
      #   "PARSE_FAIL <reason>"       loud, never a silent default.
      margin_from_logprobs() {
        jq -r '
          .choices[0].logprobs.content[0].top_logprobs // empty
          | if (length == 0) then "PARSE_FAIL no_top_logprobs"
            else
              (map(select((.token // "") | ascii_downcase | gsub("^[\s]+"; "") | startswith("yes")))
                | map(.logprob | exp) | add // 0) as $py
              | (map(select((.token // "") | ascii_downcase | gsub("^[\s]+"; "") | startswith("no")))
                | map(.logprob | exp) | add // 0) as $pn
              | if ($py == 0 and $pn == 0) then "PARSE_FAIL no_yes_no_tokens"
                else "MARGIN \((($py - $pn) / ($py + $pn)) * 1000 | round / 1000)"
                end
            end
        ' "$1"
      }

      selftest() {
        echo "paperless-triage selftest: margin parser fixtures"
        local t out m
        t=$(mktemp)
        # 1. Clear YES: p_yes ~ 0.951, p_no ~ 0.050 -> strongly positive
        printf '%s' '{"choices":[{"logprobs":{"content":[{"top_logprobs":[{"token":"YES","logprob":-0.05},{"token":"NO","logprob":-3.0},{"token":"yes","logprob":-5.5},{"token":"The","logprob":-9.1}]}]}}]}' >"$t"
        out=$(margin_from_logprobs "$t")
        case "$out" in
          MARGIN\ *)
            m="''${out#MARGIN }"
            awk -v m="$m" 'BEGIN { exit !(m > 0.5 && m <= 1) }' || die "fixture 1 (clear YES): got $out"
            ;;
          *) die "fixture 1: unexpected output: $out" ;;
        esac
        # 2. Clear NO -> strongly negative
        printf '%s' '{"choices":[{"logprobs":{"content":[{"top_logprobs":[{"token":"NO","logprob":-0.1},{"token":"YES","logprob":-4.0}]}]}}]}' >"$t"
        out=$(margin_from_logprobs "$t")
        case "$out" in
          MARGIN\ *) m="''${out#MARGIN }" ;;
          *) die "fixture 2: unexpected output: $out" ;;
        esac
        awk -v m="$m" 'BEGIN { exit !(m < -0.5 && m >= -1) }' || die "fixture 2 (clear NO): got $out"
        # 3. Missing top_logprobs (proxy stripped them / server lacks support)
        printf '%s' '{"choices":[{"logprobs":null}]}' >"$t"
        out=$(margin_from_logprobs "$t")
        [ "$out" = "PARSE_FAIL no_top_logprobs" ] || die "fixture 3: got $out"
        # 4. Neither yes nor no in the top list
        printf '%s' '{"choices":[{"logprobs":{"content":[{"top_logprobs":[{"token":"Maybe","logprob":-0.2},{"token":"The","logprob":-2.0}]}]}}]}' >"$t"
        out=$(margin_from_logprobs "$t")
        [ "$out" = "PARSE_FAIL no_yes_no_tokens" ] || die "fixture 4: got $out"
        # 5. Leading-space + case variants must both fold into p(YES)
        printf '%s' '{"choices":[{"logprobs":{"content":[{"top_logprobs":[{"token":" yes","logprob":-0.3},{"token":" Yes","logprob":-0.8},{"token":" no","logprob":-3.9}]}]}}]}' >"$t"
        out=$(margin_from_logprobs "$t")
        case "$out" in
          MARGIN\ *) m="''${out#MARGIN }" ;;
          *) die "fixture 5: unexpected output: $out" ;;
        esac
        awk -v m="$m" 'BEGIN { exit !(m > 0.5) }' || die "fixture 5 (variant folding): got $out"
        rm -f "$t"
        echo "paperless-triage selftest: PASS (5 fixtures)"
      }

      if [ "''${1:-}" = "--selftest" ]; then selftest; exit 0; fi

      : "''${PAPERLESS_BASE_URL:?}" "''${PAPERLESS_API_TOKEN:?}" "''${VERDICT_BASE_URL:?}" "''${VERDICT_MODEL:?}"

      # --- state ---------------------------------------------------------
      # Cumulative counters, the added__gt watermark, and a bounded MRU of
      # terminally-decided doc ids (pending docs hold the watermark, so
      # terminal docs get re-fetched; the MRU keeps them from being
      # re-decided).
      st_last_added=""
      declare -a mru=()
      c_sweeps=0; c_pass=0; c_review=0; c_encrypted=0
      c_down=0; c_parse=0; c_api=0; c_tokens=0
      if [ -s "$STATE_FILE" ]; then
        st_last_added=$(jq -r '.last_added // empty' "$STATE_FILE")
        mapfile -t mru < <(jq -r '.mru // [] | .[]' "$STATE_FILE")
        c_sweeps=$(jq -r '.c.sweeps // 0' "$STATE_FILE")
        c_pass=$(jq -r '.c.pass // 0' "$STATE_FILE")
        c_review=$(jq -r '.c.review // 0' "$STATE_FILE")
        c_encrypted=$(jq -r '.c.encrypted // 0' "$STATE_FILE")
        c_down=$(jq -r '.c.verdict_down // 0' "$STATE_FILE")
        c_parse=$(jq -r '.c.parse // 0' "$STATE_FILE")
        c_api=$(jq -r '.c.api_error // 0' "$STATE_FILE")
        c_tokens=$(jq -r '.c.input_tokens // 0' "$STATE_FILE")
      fi
      # First run: 15-min lookback only. P1 is a going-forward gate — the
      # ~800-doc `new`-tag backlog is deliberately NOT mass-triaged
      # (backfill is an owner-gated decision; runbook triage section).
      if [ -z "$st_last_added" ]; then
        st_last_added=$(date -u -d '-15 min' +%Y-%m-%dT%H:%M:%SZ)
      fi

      g_margin="NaN"
      g_latency="NaN"
      g_backlog=0
      psi_skip=0

      write_prom() {
        local tmp
        tmp=$(mktemp "''${TEXTFILE_DIR}/paperless_triage.prom.XXXXXX")
        chmod 644 "$tmp"
        {
          echo "# HELP paperless_triage_sweeps_total Completed sweeps."
          echo "# TYPE paperless_triage_sweeps_total counter"
          echo "paperless_triage_sweeps_total $c_sweeps"
          echo "# HELP paperless_triage_decisions_total Terminal routing decisions."
          echo "# TYPE paperless_triage_decisions_total counter"
          echo "paperless_triage_decisions_total{verdict=\"pass\"} $c_pass"
          echo "paperless_triage_decisions_total{verdict=\"review\"} $c_review"
          echo "# HELP paperless_triage_encrypted_skips_total Documents skipped as encrypted."
          echo "# TYPE paperless_triage_encrypted_skips_total counter"
          echo "paperless_triage_encrypted_skips_total $c_encrypted"
          echo "# HELP paperless_triage_refusals_total Verdicts that could not be made."
          echo "# TYPE paperless_triage_refusals_total counter"
          echo "paperless_triage_refusals_total{reason=\"verdict_down\"} $c_down"
          echo "paperless_triage_refusals_total{reason=\"parse\"} $c_parse"
          echo "paperless_triage_refusals_total{reason=\"api_error\"} $c_api"
          echo "# HELP paperless_triage_backlog Documents in the last candidate window without a terminal decision."
          echo "# TYPE paperless_triage_backlog gauge"
          echo "paperless_triage_backlog $g_backlog"
          echo "# HELP paperless_triage_margin_last Margin of the most recent verdict."
          echo "# TYPE paperless_triage_margin_last gauge"
          echo "paperless_triage_margin_last $g_margin"
          echo "# HELP paperless_triage_verdict_latency_last_seconds Last verdict call latency."
          echo "# TYPE paperless_triage_verdict_latency_last_seconds gauge"
          echo "paperless_triage_verdict_latency_last_seconds $g_latency"
          echo "# HELP paperless_triage_input_tokens_total Verdict prompt tokens."
          echo "# TYPE paperless_triage_input_tokens_total counter"
          echo "paperless_triage_input_tokens_total $c_tokens"
          echo "# HELP paperless_triage_psi_skip Whether the latest sweep was PSI-gate skipped."
          echo "# TYPE paperless_triage_psi_skip gauge"
          echo "paperless_triage_psi_skip $psi_skip"
        } >"$tmp"
        mv -f "$tmp" "$PROM"
      }

      # --- PSI admission gate (soft skip — module header note 3) ----------
      if ! maintenance-entry-gate --name paperless-triage --psi-max 30 --trip-window-min 0 >/dev/null 2>&1; then
        warn "IO PSI above band - skipping sweep (last-sweep untouched; freshness alerts after 1h of skips)"
        psi_skip=1
        write_prom
        exit 0
      fi

      # --- paperless API helpers ------------------------------------------
      api() {
        # api METHOD PATH [JSON_BODY] -> response JSON on stdout.
        local out status body
        if [ $# -ge 3 ]; then
          out=$(curl --silent --fail-with-body --max-time 60 \
            -H "Authorization: Token ''${PAPERLESS_API_TOKEN}" \
            -H 'Accept: application/json' \
            -H 'Content-Type: application/json' \
            -X "$1" -d "$3" "''${PAPERLESS_BASE_URL}$2") || return 1
        else
          out=$(curl --silent --fail-with-body --max-time 60 \
            -H "Authorization: Token ''${PAPERLESS_API_TOKEN}" \
            -H 'Accept: application/json' \
            -X "$1" "''${PAPERLESS_BASE_URL}$2") || return 1
        fi
        status="''${out##*$'\n'}"
        body="''${out%$'\n'*}"
        printf '%s' "$body"
      }

      tag_id_of() {
        api GET "/api/tags/?name=$1" | jq -r 'if .count > 0 then .results[0].id else "MISSING" end'
      }

      ensure_tag() {
        local id
        id=$(tag_id_of "$1")
        if [ "$id" = "MISSING" ]; then
          id=$(api POST /api/tags/ "{\"name\":\"$1\"}" | jq -r '.id') || return 1
          echo "paperless-triage: created tag '$1' (id=$id)"
        fi
        printf '%s' "$id"
      }

      PASS_ID=$(ensure_tag "''${TAG_PASS:?}") || die "cannot resolve pass tag"
      REVIEW_ID=$(ensure_tag "''${TAG_REVIEW:?}") || die "cannot resolve review tag"
      # Exclusion tags resolve WITHOUT create (absent = nobody carries it).
      ENC_ID=$(tag_id_of "''${TAG_ENCRYPTED}")
      DONE_ID=$(tag_id_of "''${TAG_COMPLETE}")
      FAIL_ID=$(tag_id_of "''${TAG_FAILED}")
      declare -a exclude_ids=("$PASS_ID" "$REVIEW_ID")
      [ "$ENC_ID" != MISSING ] && exclude_ids+=("$ENC_ID")
      [ "$DONE_ID" != MISSING ] && exclude_ids+=("$DONE_ID")
      [ "$FAIL_ID" != MISSING ] && exclude_ids+=("$FAIL_ID")

      in_set() {
        # in_set <needle> <haystack-array-name>
        local needle="$1" elem
        local -n hay="$2"
        for elem in "''${hay[@]}"; do [ "$elem" = "$needle" ] && return 0; done
        return 1
      }

      in_mru() {
        local elem
        for elem in "''${mru[@]}"; do [ "$elem" = "$1" ] && return 0; done
        return 1
      }

      mru_add() {
        mru+=("$1")
        # bounded: keep the newest 300
        if [ "''${#mru[@]}" -gt 300 ]; then
          mapfile -t mru < <(printf '%s\n' "''${mru[@]: -300}")
        fi
      }

      # --- candidate fetch -------------------------------------------------
      page_size=$((TRIAGE_MAX_DOCS * 4))
      DOCS=$(api GET "/api/documents/?added__gt=''${st_last_added}&ordering=added&page_size=''${page_size}") \
        || die "candidate fetch failed"
      total_fetched=$(printf '%s' "$DOCS" | jq '.results | length')

      processed=0
      pending_added=""
      max_terminal_added="$st_last_added"

      verdict_call() {
        # verdict_call <content> -> sets VERDICT_JSON + g_latency; rc!=0 on
        # transport failure (endpoint down / timeout).
        local t0 t1
        VERDICT_JSON=$(mktemp)
        t0=$(date +%s.%N)
        if ! jq -n --arg c "$1" --arg m "''${VERDICT_MODEL}" '{
            model: $m,
            messages: [
              {role: "system", content: "You are a document triage gate. Answer with exactly one word: YES or NO. Do not explain."},
              {role: "user", content: ("Does this document text contain accounting-relevant data (invoice or receipt: dates, amounts, VAT, totals) that can be reliably extracted?\n\n---\n" + $c + "\n---")}
            ],
            temperature: 0, max_tokens: 8, seed: 7,
            logprobs: true, top_logprobs: 20
          }' | curl --silent --fail-with-body --max-time "''${VERDICT_TIMEOUT}" \
            ''${OPENAI_API_KEY:+-H "Authorization: Bearer ''${OPENAI_API_KEY}"} \
            -H 'Content-Type: application/json' --data-binary @- \
            "''${VERDICT_BASE_URL}/chat/completions" >"$VERDICT_JSON"; then
          rm -f "$VERDICT_JSON"
          return 1
        fi
        t1=$(date +%s.%N)
        g_latency=$(awk "BEGIN{printf \"%.3f\", ''${t1} - ''${t0}}")
      }

      tag_doc() {
        # tag_doc <doc_id> <tag_id> — ADDITIVE bulk_edit only (PATCH on a
        # single document REPLACES the whole tag set — runbook trap #3).
        api POST /api/documents/bulk_edit/ \
          "{\"documents\":[$1],\"method\":\"modify_tags\",\"parameters\":{\"add_tags\":[$2]}}" >/dev/null
      }

      while IFS= read -r doc; do
        [ -n "$doc" ] || continue
        doc_id=$(printf '%s' "$doc" | jq -r '.id')
        doc_added=$(printf '%s' "$doc" | jq -r '.added')
        declare -a doc_tags=()
        mapfile -t doc_tags < <(printf '%s' "$doc" | jq -r '.tags | .[] | tostring')

        # already terminal (exclusion tags) or decided in an earlier sweep
        skip=0
        for t in "''${doc_tags[@]}"; do
          if in_set "$t" exclude_ids; then skip=1; fi
        done
        if [ "$skip" = 1 ] || in_mru "$doc_id"; then continue; fi
        if [ "$processed" -ge "''${TRIAGE_MAX_DOCS}" ]; then
          pending_added="''${pending_added:-''${doc_added}}"
          break
        fi

        if [ "$ENC_ID" != MISSING ] && in_set "$ENC_ID" doc_tags; then
          c_encrypted=$((c_encrypted + 1))
          mru_add "$doc_id"
          max_terminal_added="$doc_added"
          processed=$((processed + 1))
          continue
        fi

        if ! DOC_JSON=$(api GET "/api/documents/''${doc_id}/"); then
          c_api=$((c_api + 1))
          pending_added="''${pending_added:-''${doc_added}}"
          warn "document fetch failed: id=''${doc_id}"
          continue
        fi
        content=$(printf '%s' "$DOC_JSON" | jq -r ".content[0:''${TRIAGE_MAX_CHARS}] // \"\"" | tr -d '\000')

        if [ -z "$(printf '%s' "$content" | tr -d '[:space:]')" ]; then
          # Empty OCR text (unreadable/encrypted): nothing extractable —
          # route to review, no LLM call, no gpt admission.
          if tag_doc "$doc_id" "$REVIEW_ID"; then
            c_review=$((c_review + 1)); mru_add "$doc_id"; max_terminal_added="$doc_added"
          else
            c_api=$((c_api + 1)); pending_added="''${pending_added:-''${doc_added}}"
          fi
          processed=$((processed + 1))
          continue
        fi

        if ! verdict_call "$content"; then
          # Verdict endpoint down/timeout: NO writes, sweep stops — the
          # doc stays a candidate (watermark not advanced past it).
          c_down=$((c_down + 1))
          pending_added="''${pending_added:-''${doc_added}}"
          warn "verdict endpoint unreachable - stopping sweep, no tag writes (id=''${doc_id} stays queued)"
          break
        fi

        c_tokens=$((c_tokens + $(jq -r '.usage.prompt_tokens // 0' "$VERDICT_JSON")))
        out=$(margin_from_logprobs "$VERDICT_JSON")
        rm -f "$VERDICT_JSON"
        case "$out" in
          PARSE_FAIL\ *)
            # No usable yes/no posterior (proxy stripped logprobs, model
            # answered off-script): NO write, retried next sweep.
            c_parse=$((c_parse + 1))
            pending_added="''${pending_added:-''${doc_added}}"
            warn "verdict parse failure (''${out#PARSE_FAIL }) on id=''${doc_id} - leaving undecided"
            continue
            ;;
          MARGIN\ *) margin="''${out#MARGIN }" ;;
          *)
            c_parse=$((c_parse + 1))
            pending_added="''${pending_added:-''${doc_added}}"
            warn "unparseable verdict output: $out"
            continue
            ;;
        esac
        g_margin="$margin"

        if awk -v m="$margin" -v t="''${TRIAGE_THRESHOLD}" 'BEGIN { exit !(m >= t) }'; then
          if tag_doc "$doc_id" "$PASS_ID"; then
            c_pass=$((c_pass + 1)); mru_add "$doc_id"; max_terminal_added="$doc_added"
            echo "paperless-triage: id=''${doc_id} margin=''${margin} -> PASS (tagged ''${TAG_PASS})"
          else
            c_api=$((c_api + 1)); pending_added="''${pending_added:-''${doc_added}}"; warn "bulk_edit failed on id=''${doc_id} (pass)"
          fi
        else
          if tag_doc "$doc_id" "$REVIEW_ID"; then
            c_review=$((c_review + 1)); mru_add "$doc_id"; max_terminal_added="$doc_added"
            echo "paperless-triage: id=''${doc_id} margin=''${margin} -> REVIEW (tagged ''${TAG_REVIEW})"
          else
            c_api=$((c_api + 1)); pending_added="''${pending_added:-''${doc_added}}"; warn "bulk_edit failed on id=''${doc_id} (review)"
          fi
        fi
        processed=$((processed + 1))
      done <<<"$(printf '%s' "$DOCS" | jq -c '.results[]')"

      # Watermark: advance only past terminally-decided docs; hold at the
      # OLDEST undecided doc so parse-fails/down-breaks retry next sweep.
      if [ -n "''${pending_added:-}" ]; then
        new_last_added="$pending_added"
      else
        new_last_added="$max_terminal_added"
      fi

      g_backlog=$total_fetched

      # --- persist (atomic) -------------------------------------------------
      tmp_state=$(mktemp "''${STATE_DIR}/state.XXXXXX")
      mru_json="[]"
      if [ "''${#mru[@]}" -gt 0 ]; then
        mru_json=$(printf '%s\n' "''${mru[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')
      fi
      jq -n \
        --arg last_added "$new_last_added" \
        --argjson mru "$mru_json" \
        --argjson sweeps "$((c_sweeps + 1))" \
        --argjson pass "$c_pass" --argjson review "$c_review" --argjson encrypted "$c_encrypted" \
        --argjson down "$c_down" --argjson parse "$c_parse" --argjson api "$c_api" \
        --argjson tokens "$c_tokens" \
        '{last_added: $last_added, mru: $mru, c: {sweeps: $sweeps, pass: $pass, review: $review, encrypted: $encrypted, verdict_down: $down, parse: $parse, api_error: $api, input_tokens: $tokens}}' \
        >"$tmp_state"
      mv -f "$tmp_state" "$STATE_FILE"

      write_prom
      touch "$MARKER"
      echo "paperless-triage: sweep done - processed=''${processed}/''${total_fetched} pass=''${c_pass} review=''${c_review} refusals(down=''${c_down} parse=''${c_parse} api=''${c_api}) watermark=''${new_last_added}"
    '';
  };
in
{
  # Platform-truth catalog entry (ADR-008): unconditional — a timer-driven
  # gate with NO listener (port null, subdomain null).
  imports = [
    {
      services.catalog.paperless-triage = {
        subdomain = null;
        port = null;
        description = "paperless-triage confidence gate in front of paperless-gpt (timer oneshot, no listener)";
        healthPath = null;
      };
    }
  ];

  options.services.paperless-triage = {
    enable = lib.mkEnableOption "paperless-triage confidence gate in front of paperless-gpt" // {
      default = false;
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "paperless-triage";
      description = "User running the sweep.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "paperless-triage";
      description = "Group for the triage user.";
    };

    threshold = lib.mkOption {
      type = lib.types.float;
      default = 0.6;
      description = ''
        Minimum renormalized p(YES)-p(NO) margin for a PASS verdict (margin
        in [-1,1]; 0.6 initial per plan §3, calibrated from shadow data
        later — never raw confidence, which saturates near 1.0).
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "5m";
      description = "Sweep cadence (systemd OnUnitActiveSec).";
    };

    maxDocsPerSweep = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = ''
        Bound on verdict calls per sweep (blast-radius cap; keeps the sweep
        under its unit timeout at the per-call worst case).
      '';
    };

    maxContentChars = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4000;
      description = "OCR text prefix length sent to the local verdict model (page-1 triage signal).";
    };

    reviewTag = lib.mkOption {
      type = lib.types.str;
      default = "needs-review";
      description = "Tag applied to below-threshold / unreadable documents (provisioned + saved-viewed).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = paperlessCfg.enable;
        message = "services.paperless-triage requires services.paperless.enable: the token mint runs drf_create_token against the paperless DB";
      }
      {
        assertion = aiMeterEnabled || (config.services.llama-chat.enable or false);
        message = "services.paperless-triage requires a logprobs-capable verdict endpoint: enable services.ai-meter (llama-chat upstream) or services.llama-chat directly";
      }
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = stateDir;
      description = "paperless-triage sweep user";
    };
    users.groups.${cfg.group} = { };

    # --- API token mint (runtime, tmpfs-only, zero sops) ------------------
    systemd.services.paperless-triage-token = {
      description = "paperless-triage - Paperless API token mint";
      # AFTER the scheduler: drf tokens need auth_user to EXIST on a fresh
      # database (the engine-switch bootstrap trap, VM-proven 2026-10-02).
      after = [
        "postgresql.service"
        "paperless-scheduler.service"
      ];
      wants = [
        "postgresql.service"
        "paperless-scheduler.service"
      ];
      inherit onFailure;
      startLimitBurst = 5;
      startLimitIntervalSec = 300;
      # drf_create_token runs Django checks that write a probe file into
      # the paperless dataDir (checks.py, the 2026-09-16 EROFS lesson).
      unitConfig.RequiresMountsFor = [ paperlessCfg.dataDir ];
      path = [
        pkgs.coreutils
        pkgs.gnugrep
      ];
      script = ''
        MINT_OUT=${runtimeEnvFile}
        umask 077
        token="$(${paperlessCfg.manage}/bin/paperless-manage drf_create_token admin)"
        hex="$(printf '%s\n' "$token" | grep -oE '[0-9a-f]{40}' | head -n1)"
        if [ -z "$hex" ]; then
          echo "paperless-triage-token: token extraction failed (unexpected drf_create_token output)" >&2
          exit 1
        fi
        # Unlink before write: the previous mint's chown made the file
        # unwritable for the paperless user (2026-10-03 activation class).
        rm -f "$MINT_OUT"
        printf 'PAPERLESS_API_TOKEN=%s\n' "$hex" > "$MINT_OUT"
      '';
      serviceConfig = lib.mkMerge [
        {
          Type = "oneshot";
          RemainAfterExit = true;
          User = paperlessCfg.user;
          ReadWritePaths = [ paperlessCfg.dataDir ];
          RuntimeDirectory = "paperless-triage";
          RuntimeDirectoryMode = "0711";
          RuntimeDirectoryPreserve = true;
          TimeoutStartSec = "3min";
          ExecStartPost = "+${tokenChownScript}";
        }
        (harden { ProtectSystem = "strict"; })
        (serviceOneshotDefaults { })
      ];
    };

    # --- Sweep oneshot + timer --------------------------------------------
    systemd.services.paperless-triage = {
      description = "paperless-triage - confidence gate sweep in front of paperless-gpt";
      after =
        [
          "network-online.target"
          "paperless-web.service"
          "paperless-triage-token.service"
        ]
        ++ lib.optionals aiMeterEnabled [ "ai-meter.service" ];
      wants =
        [
          "network-online.target"
          "paperless-web.service"
        ]
        ++ lib.optionals aiMeterEnabled [ "ai-meter.service" ];
      requires = [ "paperless-triage-token.service" ];
      inherit onFailure;
      startLimitBurst = 5;
      startLimitIntervalSec = 300;
      # PSI soft-skip is INSIDE the script (unit start admission stays
      # systemd-clean); a FAILING unit means the sweep itself is broken
      # (state IO, script error) — that pages via onFailure.
      serviceConfig = lib.mkMerge [
        {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;
          StateDirectory = "paperless-triage";
          StateDirectoryMode = "0700";
          ExecStart = lib.getExe sweepScript;
          EnvironmentFile = [ runtimeEnvFile ]
          ++ lib.optionals aiMeterEnabled [ "/run/ai-meter-keys/paperless-triage.env" ];
          # Bounded sweep: maxDocs x verdict-timeout worst case under CPU
          # starvation + state IO (the global 3min default would kill a
          # legitimate cold sweep mid-document).
          TimeoutStartSec = "20min";
          ReadWritePaths = [ textfileDir ];
        }
        (harden {
          MemoryMax = "128M";
        })
        (serviceOneshotDefaults { })
        ioTier.background
      ];
      environment = sweepEnvironment;
      # paperless-web is Type=simple: "active" before Django binds.
      preStart = ''
        ${pkgs.curl}/bin/curl -sf --retry 30 --retry-delay 2 --retry-all-errors \
          -o /dev/null http://127.0.0.1:${toString paperlessPort}/accounts/login/
      '';
    };

    systemd.timers.paperless-triage = {
      description = "paperless-triage - periodic confidence-gate sweep";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3min";
        OnUnitActiveSec = cfg.interval;
        # Missed sweeps (downtime) fire once after boot — bounded by the
        # watermark semantics, never a mass backfill.
        Persistent = true;
      };
    };

    # Shared textfile dir (sticky 1777 — tq-agent-pool same rule, idempotent).
    systemd.tmpfiles.rules = [
      (mkStateDir textfileDir "1777" "nobody" "nogroup")
    ];

    # --- Registry entry: monitored, fresh, NO vHost/tile (not user-facing)
    services.integration = lib.optionalAttrs (options ? services.integration) {
      paperless-triage = {
        inherit (cfg) enable;
        vHost.layer = "none";
        monitored = true;
        checks = [
          # 1. Unit liveness from the system-health collector (no HTTP
          #    surface by design — tq-agent-pool shape).
          {
            name = "Paperless Triage Unit";
            group = "Documents";
            url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
            interval = "2m";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*system_service_state_failed{service=\"paperless-triage\"} 0*)"
            ];
            alert = "paperless-triage unit failed — the confidence gate in front of paperless-gpt is not sweeping (documents are NOT admitted to extraction; nothing burns, but nothing routes either). Check: journalctl -u paperless-triage -n 50.";
          }
          # 2. Verdict-endpoint health: the counter line only exists in the
          #    LATEST textfile (the sweep rewrites it every run), so its
          #    presence means the most recent sweep could not reach a
          #    verdict. Anchored newline form (gatus glob: the \n must
          #    reach gatus as a REAL newline; a bare metric-name pat would
          #    match the HELP comment — the 2026-08-22 phantom-green class).
          {
            name = "Paperless Triage Verdict Endpoint";
            group = "Documents";
            url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
              "[BODY] != pat(*\npaperless_triage_refusals_total{reason=\"verdict_down\"} *)"
            ];
            alert = "paperless-triage: the local verdict endpoint (llama-chat via ai-meter) was unreachable in the latest sweep — no documents were admitted to paperless-gpt. Check: journalctl -u paperless-triage -n 50, then the llama-chat / ai-meter units.";
          }
        ];
        # Sweep freshness through the backup-coordination mechanism (a
        # deliberate repurpose: newest-matching-file age in a directory is
        # exactly the signal; the sweep touches last-sweep on every
        # completed run). 5-min cadence, 1h tolerance = 12 missed sweeps.
        backup = {
          directory = stateDir;
          filePattern = "last-sweep";
          maxAgeHours = 1;
        };
      };
    };

    # --- Declarative entities through the dashboard provisioner -----------
    # ensureTags runs BEFORE saved views resolve their rules, so the
    # Needs Review view binds to the tag in the SAME provisioner run (no
    # first-deploy ordering gap). The paperless-gpt lifecycle tags are
    # ensured by paperless-gpt.nix; the missing-tag drift (2026-10-27
    # probe: paperless-gpt-auto ABSENT live) heals on the next provision.
    services.paperless-dashboard = lib.optionalAttrs (options ? services.paperless-dashboard) {
      ensureTags = [ cfg.reviewTag ];
      savedViews = [
        {
          name = "Needs Review (triage)";
          icon = "funnel";
          filterRules = [ { ruleType = 6; tagName = cfg.reviewTag; } ];
        }
      ];
    };
  };
  };
}

