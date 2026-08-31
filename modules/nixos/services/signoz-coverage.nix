# SigNoz service telemetry coverage audit — the "register EVERY service FULLY" rail.
#
# WHY THIS EXISTS (2026-08-31): SigNoz's Services page is TRACE-driven — a
# service appears there only if its binary actively pushes OTLP spans. The
# journald logs pipeline covers 80+ units and the prometheus receiver scrapes
# 9 jobs, but only 6 services ever sent spans (cv-application, crush-daily,
# browser-history, discordsync, file-and-image-renamer, gotenberg) because:
#
#   - dnsblockd: FULL trace instrumentation upstream, but the otlp_endpoint
#     YAML config key was never set (traces silently off)
#   - bank-sync: cqrsotel.Setup wired for stdout/noop only — OTLP exporter
#     support added upstream 2026-08-31, pending tag + flake bump
#   - overview / projects-management-automation: TracerProvider initialized
#     ("OTel tracing enabled" in the journal) but ZERO span sites in the
#     codebase — the env var is a perfect noop
#   - papdashboard: OTel METRICS only, no trace SDK
#   - hermes: Python, otel SDK not wired
#   - fastflowlm: prebuilt binary, no OTel at all (noop env since removed)
#
# The otel-endpoint-audit catches wrong endpoint SHAPES at eval time; it
# cannot know whether a binary actually emits. This module closes the loop:
#
#   1. EVAL-TIME: a declarative registry (services.signoz-coverage.expected)
#      keyed by systemd unit. Entries with wiring "env"/"upstream" MUST set
#      OTEL_EXPORTER_OTLP_ENDPOINT on that unit (catches forgotten wiring);
#      conversely ANY unit setting the env var MUST be registered (catches
#      silent noops like the fastflowlm one, untracked list excepted).
#   2. RUNTIME: signoz-coverage-metrics (5 min textfile collector) reads
#      ClickHouse DIRECTLY (never the SigNoz API — same doctrine as the
#      gatus sqlite meta-check) for the last-seen span per registered
#      service and the global logs-pipeline freshness, emitting
#      signoz_traces_reporting / signoz_traces_missing /
#      signoz_logs_pipeline_stale / signoz_coverage_scrape_errors.
#      Fail-closed: query failure writes scrape_errors 1 and forces
#      missing to the full enforced count — never a phantom green.
#   3. Gatus checks (added in gatus-config.nix) + SigNoz alert rules
#      (_signoz-alerts.nix) page on missing/stale/errors.
#
# wiring semantics:
#   "env"      — enforced: unit carries OTEL env, spans MUST flow within
#                maxAgeHours (alert when they don't)
#   "config"   — enforced: traces are enabled via service-native config
#                (dnsblockd otlp_endpoint YAML key), no env assertion
#   "upstream" — KNOWN GAP: env is set (or will be) but the binary cannot
#                emit yet. Counted in signoz_traces_upstream_gaps so the
#                debt stays visible on dashboards without paging. Flip to
#                "env" when upstream instrumentation lands.
# flake-parts wrapper note: files under modules/nixos/{services,desktop}/
# are imported into the flake-parts module set — a bare NixOS module here
# evaluates its let-bindings in the WRONG context (config.systemd.services
# missing → every nix command fails, deploy 2026-08-31 19:35). The wrapper
# below is the documented pattern (session-boot-audit.nix / gate-timeout-audit.nix).
{
  flake.nixosModules.signoz-coverage =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
  inherit (import ../../../lib/default.nix lib)
    harden
    serviceOneshotDefaults
    onFailure
    mkStateDir
    ;

  cfg = config.services.signoz-coverage;

  textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

  expectedJson = pkgs.writeText "signoz-coverage-expected.json" (
    builtins.toJSON (
      lib.mapAttrsToList (unit: e: {
        service = e.serviceName;
        inherit unit;
        maxAgeSeconds = e.maxAgeHours * 3600;
        enforced = e.wiring != "upstream";
      }) cfg.expected
    )
  );

  coverageCollector = pkgs.writeShellApplication {
    name = "signoz-coverage-metrics";
    runtimeInputs = [
      pkgs.clickhouse
      pkgs.jq
      pkgs.gawk
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      OUT="${textfileDir}/signoz-coverage.prom"
      TMP="''${OUT}.tmp.$$"

      # Every unit script must list every binary it execs (gawk lesson,
      # 2026-08-31): timeout is coreutils, clickhouse-client is pkgs.clickhouse.
      ch_query() {
        timeout 45 clickhouse-client --format TSVRaw --query "$1"
      }

      # ClickHouse "active" only means the listener exists; metadata may
      # still be loading right after boot. Retry instead of paging at boot.
      ready=false
      for _attempt in 1 2 3; do
        if ch_query "SELECT 1" >/dev/null 2>&1; then
          ready=true
          break
        fi
        sleep 20
      done

      ERRORS=0
      TRACES_TSV=""
      LOGS_LAST_MS=""

      if [ "$ready" != true ]; then
        echo "signoz-coverage: clickhouse not ready after 3 attempts" >&2
        ERRORS=1
      else
        # maxAgeHours tops out at 720h (30d) — 40d covers every budget.
        TRACES_TSV=$(ch_query "SELECT serviceName, max(toUnixTimestamp64Milli(timestamp)) FROM signoz_traces.distributed_signoz_index_v3 WHERE timestamp > now() - INTERVAL 40 DAY GROUP BY serviceName") || ERRORS=1
        LOGS_LAST_MS=$(ch_query "SELECT max(toUnixTimestamp64Milli(timestamp)) FROM signoz_logs.distributed_logs_v2 WHERE timestamp > now() - INTERVAL 1 DAY") || ERRORS=1
      fi

      now_ms=$(date +%s%3N)

      # last-seen lookup: serviceName -> epoch ms (awk map from the TSV)
      last_ms_of() {
        if [ -z "$TRACES_TSV" ]; then
          echo ""
        else
          printf '%s\n' "$TRACES_TSV" | awk -F '\t' -v svc="$1" '$1 == svc { print $2; exit }'
        fi
      }

      ENFORCED_TOTAL=$(jq '[.[] | select(.enforced)] | length' ${expectedJson})
      UPSTREAM_GAPS=$(jq '[.[] | select(.enforced | not)] | length' ${expectedJson})

      MISSING=0
      {
        echo "# HELP signoz_coverage_scrape_errors 1 if the ClickHouse coverage queries failed, healthy value is zero"
        echo "# TYPE signoz_coverage_scrape_errors gauge"

        if [ "$ERRORS" = 1 ]; then
          # Fail-closed: force the coverage check red by claiming every
          # enforced service missing. The collector itself being broken
          # must never read as "all services healthy".
          echo "signoz_coverage_scrape_errors 1"
          echo "signoz_traces_missing $ENFORCED_TOTAL"
          echo "signoz_traces_upstream_gaps $UPSTREAM_GAPS"
          exit 0
        fi

        echo "signoz_coverage_scrape_errors 0"

        echo "# HELP signoz_traces_expected 1 for every service the registry demands traces from"
        echo "# TYPE signoz_traces_expected gauge"
        echo "# HELP signoz_traces_reporting 1 if the service sent a span within its freshness budget"
        echo "# TYPE signoz_traces_reporting gauge"
        echo "# HELP signoz_traces_last_span_age_seconds seconds since the newest span of this service (negative means never seen)"
        echo "# TYPE signoz_traces_last_span_age_seconds gauge"

        for row in $(jq -r '.[] | @base64' ${expectedJson}); do
          entry=$(printf '%s' "$row" | base64 -d)
          service=$(printf '%s' "$entry" | jq -r '.service')
          budget=$(printf '%s' "$entry" | jq -r '.maxAgeSeconds')
          enforced=$(printf '%s' "$entry" | jq -r '.enforced')

          last_ms=$(last_ms_of "$service")
          if [ -n "$last_ms" ] && [ "$last_ms" -gt 0 ] 2>/dev/null; then
            age_s=$(( (now_ms - last_ms) / 1000 ))
            reporting=0
            [ "$age_s" -le "$budget" ] && reporting=1
          else
            age_s=-1
            reporting=0
          fi

          if [ "$enforced" = true ] && [ "$reporting" = 0 ]; then
            MISSING=$((MISSING + 1))
          fi

          echo "signoz_traces_expected{service=\"''${service}\"} 1"
          echo "signoz_traces_reporting{service=\"''${service}\"} ''${reporting}"
          echo "signoz_traces_last_span_age_seconds{service=\"''${service}\"} ''${age_s}"
        done

        echo "# HELP signoz_traces_missing enforced services without a span inside their budget, healthy value is zero"
        echo "# TYPE signoz_traces_missing gauge"
        echo "signoz_traces_missing $MISSING"
        echo "# HELP signoz_traces_upstream_gaps services whose binaries cannot emit traces yet (upstream instrumentation debt)"
        echo "# TYPE signoz_traces_upstream_gaps gauge"
        echo "signoz_traces_upstream_gaps $UPSTREAM_GAPS"

        logs_age_s=-1
        if [ -n "$LOGS_LAST_MS" ] && [ "$LOGS_LAST_MS" -gt 0 ] 2>/dev/null; then
          logs_age_s=$(( (now_ms - LOGS_LAST_MS) / 1000 ))
        fi
        logs_stale=0
        [ "$logs_age_s" -lt 0 ] || [ "$logs_age_s" -gt 1800 ] && logs_stale=1

        echo "# HELP signoz_logs_pipeline_age_seconds seconds since the newest ingested log record (any service)"
        echo "# TYPE signoz_logs_pipeline_age_seconds gauge"
        echo "signoz_logs_pipeline_age_seconds ''${logs_age_s}"
        echo "# HELP signoz_logs_pipeline_stale 1 if the journald logs pipeline stopped ingesting, healthy value is zero"
        echo "# TYPE signoz_logs_pipeline_stale gauge"
        echo "signoz_logs_pipeline_stale ''${logs_stale}"
      } > "$TMP"

      mv "$TMP" "$OUT"
    '';
  };

  # ── Eval-time wiring checks ─────────────────────────────────────────────
  # environment is attrsOf (either str (listOf str)); serviceConfig.Environment
  # is nullOr (either str (listOf "K=V")). Normalize both to a K=V list.
  unitOtelEntries =
    unit:
    let
      svc = config.systemd.services.${unit};
      fromAttrs = lib.mapAttrsToList (k: v: "${k}=${toString v}") (
        lib.filterAttrs (n: _: n == "OTEL_EXPORTER_OTLP_ENDPOINT") svc.environment
      );
      scEnv = svc.serviceConfig.Environment or null;
      scList =
        if scEnv == null then
          [ ]
        else if builtins.isString scEnv then
          [ scEnv ]
        else
          lib.filter builtins.isString scEnv;
      fromServiceConfig = lib.filter (e: lib.hasPrefix "OTEL_EXPORTER_OTLP_ENDPOINT=" e) scList;
    in
    # An entry with an EMPTY value ("OTEL_EXPORTER_OTLP_ENDPOINT=") is not
    # wiring — a mkForce "" override must still count as missing.
    lib.filter (e: builtins.match "OTEL_EXPORTER_OTLP_ENDPOINT=..*" e != null) (
      fromAttrs ++ fromServiceConfig
    );

  unitHasOtelEnv = unit: (unitOtelEntries unit) != [ ];

  # Reverse scan: EVERY unit carrying the env var must be a registry key (or
  # explicitly untracked) — the structural "no silent noop" rule.
  unitsWithOtelEnv = lib.filter (unit: unitHasOtelEnv unit) (
    builtins.attrNames config.systemd.services
  );

  unregisteredOtelUnits = lib.filter (
    unit: !(cfg.expected ? ${unit}) && !(builtins.elem unit cfg.untrackedOtelUnits)
  ) unitsWithOtelEnv;

  # Forward scan: env/upstream entries whose unit exists must carry the env var.
  envViolations = lib.concatMap (
    unit:
    let
      entry = cfg.expected.${unit};
      unitExists = config.systemd.services ? ${unit};
    in
    lib.optional (unitExists && entry.wiring != "config" && !unitHasOtelEnv unit)
      "signoz-coverage: registry demands traces from unit \"${unit}\" (wiring=${entry.wiring}, serviceName=${entry.serviceName}) but the unit sets no OTEL_EXPORTER_OTLP_ENDPOINT — spans can never reach SigNoz. Set the env var (Go otlptracehttp: localhost:4318, no scheme) or reclassify wiring."
  ) (builtins.attrNames cfg.expected);

  reverseViolations = lib.map (
    unit:
    "signoz-coverage: systemd unit \"${unit}\" sets OTEL_EXPORTER_OTLP_ENDPOINT but is NOT in services.signoz-coverage.expected — if the binary cannot emit spans the env var is a silent noop (the fastflowlm/overview class). Register it with the right wiring (\"env\"/\"config\"/\"upstream\") or add it to untrackedOtelUnits with a reason."
  ) unregisteredOtelUnits;
in
{
  options.services.signoz-coverage = {
    enable = lib.mkEnableOption "SigNoz service telemetry coverage audit (registry + eval assertions + runtime freshness collector)";

    expected = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule {
          options = {
            serviceName = lib.mkOption {
              type = str;
              description = "resource.service.name the binary reports to SigNoz (NOT necessarily the unit name — cv-server reports cv-application).";
            };
            wiring = lib.mkOption {
              type = enum [
                "env"
                "config"
                "upstream"
              ];
              description = ''
                How traces are wired: "env" = unit sets OTEL_EXPORTER_OTLP_ENDPOINT
                and spans are ENFORCED within maxAgeHours; "config" = traces enabled
                via service-native config (no env assertion, still enforced);
                "upstream" = KNOWN GAP, binary cannot emit yet (env is set in
                anticipation) — visible via signoz_traces_upstream_gaps, not alerting.
              '';
            };
            maxAgeHours = lib.mkOption {
              type = int;
              default = 26;
              description = "Span freshness budget. Dense services: 26h. Event-driven ones (renamer, gotenberg): 720h.";
            };
          };
        });
      description = "Registry of services that must be FULLY registered with SigNoz (traces). Keyed by systemd unit name.";
    };

    untrackedOtelUnits = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "Units allowed to set OTEL_EXPORTER_OTLP_ENDPOINT without a registry entry (with a reason in the commit).";
    };
  };

  config = lib.mkIf cfg.enable {
    # The registry: evo-x2 truth as of 2026-08-31. Keep in sync when services
    # are added — the reverse assertion below refuses silent noops.
    services.signoz-coverage.expected =
      let
        env = serviceName: maxAgeHours: {
          inherit serviceName maxAgeHours;
          wiring = "env";
        };
      in
      {
        # ── Enforced, emitting today ──
        cv-server = env "cv-application" 26; # upstream hardcodes the service name
        browser-history = env "browser-history" 26;
        discordsync = env "discordsync" 26;
        crush-daily = env "crush-daily" 26;
        file-and-image-renamer = env "file-and-image-renamer" 720; # spans only when files are renamed
        # Same binary (health subcommand), same serviceName — spans of both
        # units are attributed to "file-and-image-renamer".
        file-and-image-renamer-health = env "file-and-image-renamer" 720;
        gotenberg = env "gotenberg" 720; # spans only when paperless converts office docs
        dnsblockd = {
          serviceName = "dnsblockd";
          wiring = "config"; # otlp_endpoint YAML key in dns-blocker.nix, not env
          maxAgeHours = 26;
        };

        # ── Known upstream gaps (env set, binary cannot emit yet) ──
        bank-sync = {
          serviceName = "bank-sync";
          # OTLP support added upstream 2026-08-31 (cmd/bank-sync/tracing.go,
          # DiscordSync pattern). Flip to "env" after tag + flake bump.
          wiring = "upstream";
        };
        overview = {
          serviceName = "overview";
          # SetupFromEnv runs ("OTel tracing enabled" in journal) but the
          # codebase has ZERO span sites — needs code instrumentation.
          wiring = "upstream";
        };
        projects-management-automation = {
          serviceName = "projects-management-automation";
          wiring = "upstream"; # same class as overview
        };
        papdashboard = {
          serviceName = "papdashboard";
          # OTel METRICS only (prometheus registry), no trace SDK upstream.
          wiring = "upstream";
        };
        hermes = {
          serviceName = "hermes";
          # Python; opentelemetry-sdk not wired into the agent runtime.
          wiring = "upstream";
        };
      };

    assertions = map (msg: {
      assertion = false;
      message = msg;
    }) (envViolations ++ reverseViolations);

    systemd = {
      tmpfiles.rules = [
        (mkStateDir textfileDir "1777" "nobody" "nogroup")
      ];

      services.signoz-coverage-metrics = {
        description = "SigNoz telemetry coverage collector (traces freshness per registered service)";
        inherit onFailure;
        after = [ "clickhouse.service" ];
        serviceConfig = lib.mkMerge [
          (harden { MemoryMax = "128M"; })
          (serviceOneshotDefaults { })
          {
            Type = "oneshot";
            ExecStart = lib.getExe coverageCollector;
            ReadWritePaths = [ textfileDir ];
            # Explicit ceiling: a wedged collection must land in onFailure
            # alerting, not sit in "activating" (global DefaultTimeoutStartSec
            # was proven phantom 2026-08-31).
            TimeoutStartSec = "3min";
          }
        ];
      };

      timers.signoz-coverage-metrics = {
        description = "Collect SigNoz coverage metrics every 5 minutes";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2min";
          OnUnitActiveSec = "5min";
        };
      };
    };
  };
  };
}
