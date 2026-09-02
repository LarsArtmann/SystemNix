# SEV1 escalation bridge — making critical alerts unmissable.
#
# The 2026-08-22 double freeze postmortem: Gatus fired "Memory pressure
# CRITICAL" to Discord 43 min before freeze #1 and 17 s before freeze #2 —
# the warnings existed, the human loop did not. User decision (2026-08-22):
# Discord stays the phone channel; when a graphical session is online,
# criticals additionally get (a) a DMS desktop notification and (b) a
# fullscreen red overlay (shutdown-overlay pattern) that cannot be missed
# from across the room.
#
# Architecture:
#   sev1-bridge.service (system, root, every 10 s):
#     - Evaluates SEV1 conditions from the local textfile collectors
#       (guard trip, guard DEAD, monitoring stale, DAS link down, LAN NIC
#       absent, btrfs critical, zram critical).
#     - Active: rewrites /run/systemnix/sev1/alert every run (title,
#       detail, generated-at epoch). The overlay SELF-EXPIRES when the
#       file is older than alertTtlSeconds — a dead bridge can never
#       leave a stuck overlay on screen.
#     - Transitions into a NEW alert set: one DMS notification via
#       `systemd-run --machine=<user>@.host --user` (the AGENTS-documented
#       machined bus proxy; best-effort, no session = no-op) — deduped via
#       a state file, so a persistent alert notifies once, not every 10 s.
#     - Clear: removes the alert file.
#     - Emits sev1-bridge.prom (fail-closed presence metric).
#   sev1-overlay.service (user, graphical-session.target):
#     - Quickshell fullscreen banner while the alert file is fresh AND its
#       severity line (line 4) says "page" — notify-tier alerts never
#       fullscreen.
#
# Overlay triggers are TIERED (user decisions 2026-08-31 evening +
# 2026-09-02 movie-night sessions; HARDENED 2026-09-02 late evening after
# high-memory alerts kept fullscreen-flashing over a movie: "High memory
# should NOT flash my entire screen — only shutdowns and
# ACTUALLY-about-to-be-impacted events may page"; refined same evening —
# "if it's NOT gonna kill it, do a yellow non-flashing one once"):
#   page   = red pulsing fullscreen overlay + persistent critical
#           notification. RESERVED — no current emitter (true
#           drop-everything emergencies only).
#   warn   = STATIC amber fullscreen banner, shown ONCE per alert set,
#           no animation, + one cooldown-gated notification:
#           infra hardware criticals (DAS link, LAN NIC, btrfs critical).
#           Once = the bridge writes "warn" on the first run of a NEW
#           alert set and downgrades every refresh of the SAME set to
#           "warn-seen" (which the overlay ignores) — the downgrade lives
#           in the bridge so "once" survives quickshell restarts and is
#           VM-testable. A CHANGED alert set re-arms the banner.
#   notify = ONE self-expiring normal-urgency desktop notification +
#           Gatus/Discord, NO overlay: EVERY memory-related condition
#           (guard trip, sustained memory stall, guard dead) plus SYSTEM
#           MONITORING STALE, ZRAM SWAP CRITICAL (combined-gated — steady-
#           state high fill never notifies) and FLM RESTORE CAPPED. The
#           guard's entire job is to CONTAIN memory emergencies
#           automatically — the user cannot act mid-movie, and the
#           2026-09-02 re-wake loop proved a memory fullscreen overlay is
#           pure spam. All notify-tier conditions are additionally
#           cooldown-gated against re-notification. The PSI warning tier
#           (psi-metrics) likewise does NOT overlay — Discord only.
_: {
  flake.nixosModules.sev1-escalation =
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

      cfg = config.services.sev1-escalation;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      stateDir = "/var/lib/sev1-escalation";
      alertFile = "/run/systemnix/sev1/alert";

      bridgeScript = pkgs.writeShellApplication {
        name = "sev1-bridge-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.gnused
          pkgs.systemd
        ];
        text = ''
          set -euo pipefail

          # Env-overridable sources for the VM regression test.
          GUARD_PROM="''${GUARD_PROM:-${textfileDir}/memory-emergency-guard.prom}"
          HEALTH_PROM="''${HEALTH_PROM:-${textfileDir}/system_health.prom}"
          ALERT_FILE="''${SEV1_ALERT_FILE:-${alertFile}}"
          STATE_FILE="${stateDir}/last-alert-key"
          OUT="''${SEV1_PROM_OUT:-${textfileDir}/sev1-bridge.prom}"
          TMP="''${OUT}.tmp"
          DESKTOP_USER="${cfg.desktopUser}"

          mkdir -p "$(dirname "$ALERT_FILE")" "$(dirname "$OUT")"

          now=$(date +%s)
          titles=()
          details=()
          severities=()

          # Boot grace: on a fresh boot the textfile metrics are legitimately
          # absent/stale (their last write happened pre-shutdown; collectors
          # haven't ticked yet) and system_health.prom may hold pre-shutdown
          # values. Skipping DEAD/STALE and infra-critical evaluation for the
          # first bootGraceSeconds avoids a false SEV1 page on EVERY reboot
          # (observed 2026-08-31: "MEMORY GUARD DEAD (303s old)" paged 60s
          # after boot). Env-overridable for the VM regression test.
          BOOT_GRACE_SEC=''${SEV1_BOOT_GRACE_SEC:-${toString cfg.bootGraceSeconds}}
          BOOT_GRACE=0
          if [ -r /proc/uptime ]; then
            if [ "$(cut -d' ' -f1 /proc/uptime | cut -d. -f1)" -lt "$BOOT_GRACE_SEC" ]; then
              BOOT_GRACE=1
            fi
          fi

          # Module presence gates: on a host where the guard/health modules
          # are DISABLED their prom files legitimately never exist — treat
          # that as "not applicable", not as DEAD/STALE. SYSTEMCTL_BIN is
          # env-overridable for the VM regression test (the wrapper's
          # runtimeInputs PREPEND to PATH — a PATH-shim systemctl loses).
          SYSTEMCTL_BIN="''${SYSTEMCTL_BIN:-systemctl}"
          guard_enabled=false
          "$SYSTEMCTL_BIN" is-enabled --quiet memory-emergency-guard.timer 2>/dev/null && guard_enabled=true
          health_enabled=false
          "$SYSTEMCTL_BIN" is-enabled --quiet system-health-metrics.timer 2>/dev/null && health_enabled=true

          prom_value() {
            # prom_value <file> <metric> [expected-args] -> prints first match
            awk -v m="$2" '$0 == m || index($0, m " ") == 1 { print $2; exit }' "$1" 2>/dev/null
          }

          file_age() {
            local f=$1
            if [ -f "$f" ]; then
              echo $(( now - $(stat -c %Y "$f" 2>/dev/null || echo "$now") ))
            else
              echo -1
            fi
          }

          # --- Guard trip (the guard ACTED: machine entered a pre-freeze
          #     zone). The alert tracks the EMERGENCY, not the event: it
          #     stays while the sacrifice is actually DOWN
          #     (sacrifice_socket_active=0 — flm is unreachable) and clears
          #     the moment the guard restores the sockets. 2026-09-02
          #     lesson: keying on last_trip_recent alone kept the alert
          #     alive for the metric's whole 30-min window while the
          #     machine had already recovered to 53% MemAvailable (the
          #     restore was blocked by the old zram gate). A missing socket
          #     metric fails LOUD (=0, alert) — same philosophy as the
          #     overlay's missing severity line: an emergency is never
          #     silenced by a parse gap.
          #     TIER: notify (2026-09-02 user decision — "high memory must
          #     NOT flash my entire screen while I watch a movie"). The
          #     guard exists to CONTAIN this automatically; the re-wake
          #     loop proved a fullscreen overlay for a contained emergency
          #     is pure spam. Gatus/Discord + one cooldown-gated desktop
          #     notification carry the visibility.
          guard_trip=0
          if [ "$BOOT_GRACE" = "0" ] && [ "$guard_enabled" = "true" ] && [ -f "$GUARD_PROM" ]; then
            v=$(prom_value "$GUARD_PROM" "memory_emergency_guard_last_trip_recent")
            g_sock=$(prom_value "$GUARD_PROM" "memory_emergency_guard_sacrifice_socket_active")
            g_sock="''${g_sock:-0}"
            if [ "$v" = "1" ] && [ "$g_sock" = "0" ]; then
              guard_trip=1
            fi
          fi
          if [ "$guard_trip" = "1" ]; then
            # Churn context (2026-09-02 re-wake loop): >=2 trips in the last
            # hour means an alert-driven consumer re-wakes flm after every
            # restore — the alert must SAY that, not just "guard tripped".
            g_churn=$(prom_value "$GUARD_PROM" "memory_emergency_guard_trips_last_hour")
            g_churn="''${g_churn:-0}"
            churn_note=""
            if [ "$g_churn" -ge 2 ] 2>/dev/null; then
              churn_note=" TRIP CHURN: ''${g_churn} trips in the last hour — a consumer is re-waking FastFlowLM after every restore; the daily restore budget will stop this."
            fi
            titles+=("MEMORY EMERGENCY GUARD TRIPPED")
            details+=("The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped (this alert clears automatically when the guard restores the sockets).''${churn_note} journalctl -u memory-emergency-guard -n 30")
            severities+=("notify")
          fi

          # --- Restore capped (2026-09-02 anti-churn cap): the daily restore
          #     budget is spent and the socket is still DOWN. The trip page
          #     covers the acute phase via its own condition; after it
          #     clears, flm would silently stay unusable — this notify-tier
          #     condition carries the manual restart path instead. The
          #     machine is not in danger at this point (the budget is only
          #     spent after a day of emergencies); it is a degraded-service
          #     heads-up, not a drop-everything page.
          if [ "$BOOT_GRACE" = "0" ] && [ "$guard_enabled" = "true" ] && [ -f "$GUARD_PROM" ]; then
            v=$(prom_value "$GUARD_PROM" "memory_emergency_guard_restore_capped")
            g_sock=$(prom_value "$GUARD_PROM" "memory_emergency_guard_sacrifice_socket_active")
            if [ "$v" = "1" ] && [ "$g_sock" = "0" ]; then
              titles+=("FLM RESTORE CAPPED")
              details+=("FastFlowLM was sacrificed and the daily restore budget is spent — the socket stays DOWN until a human restarts it (memory-guard anti-churn cap). Restart when memory is healthy: systemctl start fastflowlm.socket")
              severities+=("notify")
            fi
          fi

          # --- Sustained memory stall (2026-08-31 16:34 freeze class: the
          #     box froze with zram EMPTY, MemAvailable healthy, zero OOM
          #     kills — Discord flapped "Memory pressure CRITICAL" for 2 h
          #     while the user sat at the machine. The desktop must SEE the
          #     same SUSTAINED signal Zone 4 trips on: avg60 >= 45, slightly
          #     below the trip threshold. Guard-gated, NOT health-gated:
          #     during the final stall the system-health collector dies
          #     FIRST (live 16:33) — only its own stale alert would fire,
          #     without the actionable shed-load detail.)
          #     TIER: notify (2026-09-02 user decision — high-memory
          #     warnings must NEVER fullscreen-page; see header).
          if [ "$guard_enabled" = "true" ] && [ -f "$GUARD_PROM" ]; then
            g_avg60=$(prom_value "$GUARD_PROM" "memory_emergency_guard_psi_some_avg60_percent")
            g_avg60="''${g_avg60:--1}"
            # Episodic signal (CALIBRATED): the real 16:34 boot NEVER lifted
            # avg60 above ~4% — the observable pre-freeze pattern was the
            # leaky-bucket episode count. Page at 4 (half the guard's trip
            # count of 8) so the desktop page PRECEDES the sacrifice.
            g_episodes=$(prom_value "$GUARD_PROM" "memory_emergency_guard_psi_episodes")
            g_episodes="''${g_episodes:--1}"
            if awk "BEGIN{exit !($g_avg60 >= 45)}" || awk "BEGIN{exit !($g_episodes >= 4)}"; then
              titles+=("MEMORY STALL SUSTAINED")
              details+=("Memory-stall freeze precursor, 2026-08-31 class (avg60=''${g_avg60}%, avg10-episode bucket=''${g_episodes}). Stop heavy builds / VM tests NOW; the guard is (about to be) sacrificing FastFlowLM. journalctl -u memory-emergency-guard -n 30")
              severities+=("notify")
            fi
          fi

          # --- Guard dead (trip capability lost — the guard that should fire
          #     during an emergency is itself down or its metrics vanished).
          #     TIER: notify (2026-09-02 user decision — protection-layer
          #     health is a meta condition, not a user-facing emergency;
          #     the machine freezing IS the user-facing signal, and
          #     Gatus/Discord carry this).
          guard_age=$(file_age "$GUARD_PROM")
          if [ "$BOOT_GRACE" = "0" ] && [ "$guard_enabled" = "true" ] && { [ "$guard_age" -lt 0 ] || [ "$guard_age" -gt $(( ${toString cfg.staleGuardSeconds} )) ]; }; then
            titles+=("MEMORY GUARD DEAD")
            details+=("memory-emergency-guard metrics are missing/stale (''${guard_age}s old). The automated freeze protection is DOWN. systemctl status memory-emergency-guard")
            severities+=("notify")
          fi

          # --- Monitoring stale (system-health textfile collector dead)
          health_age=$(file_age "$HEALTH_PROM")
          if [ "$BOOT_GRACE" = "0" ] && [ "$health_enabled" = "true" ] && { [ "$health_age" -lt 0 ] || [ "$health_age" -gt $(( ${toString cfg.staleHealthSeconds} )) ]; }; then
            # NOTIFY tier (2026-08-31 user decision): stale monitoring is
            # Discord/notification-worthy but must NEVER fullscreen-page —
            # nothing the user can act on mid-movie, and the condition
            # flaps with collector timeouts. Severity is line 4 of the
            # alert file; the overlay ignores non-page alerts.
            titles+=("SYSTEM MONITORING STALE")
            details+=("system_health metrics missing/stale (''${health_age}s old). Most Gatus conditions are phantom right now. systemctl status system-health-metrics")
            severities+=("notify")
          fi

          # --- Infra criticals from system_health.prom
          if [ "$BOOT_GRACE" = "0" ] && [ "$health_enabled" = "true" ] && [ -f "$HEALTH_PROM" ]; then
            v=$(prom_value "$HEALTH_PROM" "system_das_link_present")
            if [ "$v" = "0" ]; then
              titles+=("DAS USB LINK DOWN")
              details+=("All external disks (pool + buildcache) share one USB link that just dropped. Physical reseat + reboot may be needed.")
              severities+=("warn")
            fi
            v=$(prom_value "$HEALTH_PROM" "system_lan_nic_present")
            if [ "$v" = "0" ]; then
              titles+=("LAN NIC ABSENT")
              details+=("The RTL8125 fell off the PCIe bus. Power-cycle (full shutdown ~10s, not warm reboot).")
              severities+=("warn")
            fi
            v=$(prom_value "$HEALTH_PROM" "btrfs_health_critical")
            if [ "$v" = "1" ]; then
              titles+=("BTRFS CRITICAL")
              details+=("Filesystem in CRITICAL state (unalloc/meta envelope). btrfs-health metrics; do not add load.")
              severities+=("warn")
            fi
            v=$(prom_value "$HEALTH_PROM" "system_zram_fill_over_threshold")
            if [ "$v" = "1" ]; then
              # zram near-full ALONE is steady-state normal on this box
              # (swappiness=150 keeps cold anon compressed in zram; live
              # 2026-09-02: 97% fill with 53% MemAvailable and 0.26% PSI —
              # perfectly healthy). Combined-gate exactly like before, but
              # the tier is NOTIFY, not warn/page (2026-09-02 user
              # decision): the guard's own trip alert covers the real
              # cliff within one tick — a second overlay for the same
              # cliff was pure alert spam. A self-expiring notification +
              # the existing Gatus/Discord ZRAM Fill alert carry the
              # early warning. Guard metrics are the PSI/avail source
              # (-1 = guard absent → no escalation).
              g_psi=$(prom_value "$GUARD_PROM" "memory_emergency_guard_psi_some_avg10_percent")
              g_avail=$(prom_value "$GUARD_PROM" "memory_emergency_guard_avail_percent")
              g_psi="''${g_psi:--1}"
              g_avail="''${g_avail:--1}"
              if awk "BEGIN{exit !($g_psi >= 5)}" || awk "BEGIN{exit !($g_avail >= 0 && $g_avail < 15)}"; then
                titles+=("ZRAM SWAP CRITICAL")
                details+=("zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=''${g_psi}%, MemAvailable=''${g_avail}%) — the memory guard is about to sacrifice FastFlowLM; shed load now.")
                severities+=("notify")
              fi
            fi
          fi

          alerts_active=''${#titles[@]}

          # Overall severity (highest tier wins): "page" > "warn" >
          # "notify". Written as line 4 of the alert file (warn may be
          # downgraded to warn-seen below) — the overlay fullscreens ONLY
          # on "page" and shows the static yellow banner ONCE per alert
          # set on "warn".
          page_active=0
          warn_active=0
          for s in "''${severities[@]}"; do
            if [ "$s" = "page" ]; then
              page_active=1
            fi
            if [ "$s" = "warn" ]; then
              warn_active=1
            fi
          done
          severity=notify
          if [ "$warn_active" = "1" ]; then
            severity=warn
          fi
          if [ "$page_active" = "1" ]; then
            severity=page
          fi

          # Page-duration tracking (alert-fatigue visibility): the 2026-09-02
          # incident's core complaint was page DURATION (fullscreen for the
          # metric's whole 30-min window) and nothing measured it. While a
          # page-tier alert is active, expose the running seconds; on clear,
          # freeze the last duration for dashboards.
          PAGE_START_FILE="${stateDir}/page-start-epoch"
          page_last_duration=0
          if [ -f "${stateDir}/page-last-duration" ]; then
            page_last_duration=$(cat "${stateDir}/page-last-duration" 2>/dev/null || echo 0)
          fi
          page_last_duration="''${page_last_duration:-0}"
          page_duration_active=0
          if [ "$page_active" = "1" ]; then
            if [ ! -f "$PAGE_START_FILE" ]; then
              echo "$now" > "$PAGE_START_FILE"
            fi
            pstart=$(cat "$PAGE_START_FILE" 2>/dev/null || echo "$now")
            pstart="''${pstart:-$now}"
            page_duration_active=$(( now - pstart ))
          else
            if [ -f "$PAGE_START_FILE" ]; then
              pstart=$(cat "$PAGE_START_FILE" 2>/dev/null || echo "$now")
              pstart="''${pstart:-$now}"
              page_last_duration=$(( now - pstart ))
              if [ "$page_last_duration" -lt 0 ]; then
                page_last_duration=0
              fi
              echo "$page_last_duration" > "${stateDir}/page-last-duration"
              rm -f "$PAGE_START_FILE"
            fi
          fi

          if [ "$alerts_active" -gt 0 ]; then
            title=$(printf '%s; ' "''${titles[@]}" | sed 's/; $//')
            detail=$(printf '%s | ' "''${details[@]}" | sed 's/ | $//')

            # Alert-set key + whether it changed since the last run —
            # drives BOTH the notification dedup and the warn show-once.
            key=$(printf '%s\n' "''${titles[@]}" | sort | tr '\n' ',')
            prev_key=""
            [ -f "$STATE_FILE" ] && prev_key=$(cat "$STATE_FILE" 2>/dev/null || true)

            # Warn tier shows ONCE per alert set: the first run of a NEW
            # set writes "warn" (overlay renders the static yellow
            # banner), every refresh of the SAME set writes "warn-seen"
            # (overlay ignores it). A changed set re-arms the banner.
            line4="$severity"
            if [ "$severity" = "warn" ] && [ "$key" = "$prev_key" ]; then
              line4="warn-seen"
            fi

            # Rewrite every run: freshness IS the liveness signal for the
            # overlay (it self-expires when the file goes stale).
            printf '%s\n%s\n%s\n%s\n' "$title" "$detail" "$now" "$line4" > "$ALERT_FILE"
            chmod 0644 "$ALERT_FILE"
            echo "SEV1 active (''${alerts_active} condition(s), severity=$line4): $title" >&2

            # Notify ONLY on transition into a new alert set (dedup via
            # state file) — a persistent condition notifies once.
            if [ "$key" != "$prev_key" ]; then
              echo "$key" > "''${STATE_FILE}.tmp"
              mv "''${STATE_FILE}.tmp" "$STATE_FILE"
              # Page tier: persistent critical notification (never
              # cooldown-gated — drop-everything conditions). Warn and
              # notify tiers: self-expiring normal-urgency notification,
              # cooldown-gated so a flapping collector (stale -> clear ->
              # stale cycles, live 2026-08-31 evening) cannot re-notify
              # either.
              send_notification=1
              notify_urgency=critical
              notify_expiry=0
              if [ "$severity" != "page" ]; then
                notify_urgency=normal
                notify_expiry=30000
                # PER-KEY cooldown (2026-09-02): the old single
                # last-notify-epoch let a ZRAM SWAP CRITICAL notify silently
                # suppress a later SYSTEM MONITORING STALE notify (and vice
                # versa) within the window — different conditions, unrelated
                # notifications. Each alert-set key gets its own epoch file;
                # files older than 2x the cooldown are pruned so the state
                # dir stays bounded.
                nkey=$(printf '%s' "$key" | md5sum | cut -d' ' -f1)
                notify_epoch_file="${stateDir}/last-notify-''${nkey}"
                for old in "${stateDir}"/last-notify-*; do
                  [ -f "$old" ] || continue
                  if [ "$old" != "$notify_epoch_file" ]; then
                    old_ts=$(stat -c %Y "$old" 2>/dev/null || echo "$now")
                    if [ $(( now - old_ts )) -gt $(( 2 * ${toString cfg.notifyCooldownSeconds} )) ]; then
                      rm -f "$old"
                    fi
                  fi
                done
                last_notify=0
                if [ -f "$notify_epoch_file" ]; then
                  last_notify=$(cat "$notify_epoch_file" 2>/dev/null || echo 0)
                fi
                last_notify="''${last_notify:-0}"
                if [ $(( now - last_notify )) -lt ${toString cfg.notifyCooldownSeconds} ]; then
                  send_notification=0
                  echo "SEV1 notify-tier notification suppressed (cooldown ''$(( now - last_notify ))s < ${toString cfg.notifyCooldownSeconds}s)" >&2
                fi
              fi
              if [ "$send_notification" = "1" ]; then
                if [ "$severity" != "page" ]; then
                  echo "$now" > "$notify_epoch_file"
                fi
                # Best-effort DMS desktop notification via the machined user
                # bus proxy (AGENTS: root -> user-manager needs --machine).
                systemd-run --machine="$DESKTOP_USER@.host" --user --collect \
                  ${lib.getExe' pkgs.libnotify "notify-send"} \
                  -u "$notify_urgency" -t "$notify_expiry" "SEV1: $title" "$detail" 2>/dev/null || true
              fi
            fi
          else
            rm -f "$ALERT_FILE"
            if [ -f "$STATE_FILE" ]; then
              rm -f "$STATE_FILE"
              echo "SEV1 cleared — conditions recovered" >&2
            fi
          fi

          {
            # Persist the run counter BEFORE the redirected emission block —
            # inside `{ ... } > "$TMP" every echo is redirected to the
            # metrics file, not the state file.
            runs=0
            if [ -f "${stateDir}/runs.count" ]; then
              runs=$(cat "${stateDir}/runs.count" 2>/dev/null) || runs=0
            fi
            runs="''${runs:-0}"
            runs=$(( runs + 1 ))
            echo "$runs" > "${stateDir}/runs.count.tmp" 2>/dev/null && mv "${stateDir}/runs.count.tmp" "${stateDir}/runs.count" || true

            echo "# HELP sev1_bridge_alerts_active Number of active SEV1 conditions, ANY tier (page = overlay + persistent critical notification, notify = single self-expiring notification, no overlay)"
            echo "# TYPE sev1_bridge_alerts_active gauge"
            echo "sev1_bridge_alerts_active ''${alerts_active}"
            echo "# HELP sev1_bridge_page_alerts_active Number of active PAGE-tier SEV1 conditions (fullscreen overlay eligible)"
            echo "# TYPE sev1_bridge_page_alerts_active gauge"
            echo "sev1_bridge_page_alerts_active ''${page_active}"
            echo "# HELP sev1_bridge_page_active_seconds Seconds the current page-tier alert has been active (0 when none) — alert-fatigue visibility"
            echo "# TYPE sev1_bridge_page_active_seconds gauge"
            echo "sev1_bridge_page_active_seconds ''${page_duration_active}"
            echo "# HELP sev1_bridge_page_last_duration_seconds Duration in seconds of the most recently cleared page-tier alert"
            echo "# TYPE sev1_bridge_page_last_duration_seconds gauge"
            echo "sev1_bridge_page_last_duration_seconds ''${page_last_duration}"
            echo "# HELP sev1_bridge_runs_total Total bridge runs since first deploy"
            echo "# TYPE sev1_bridge_runs_total counter"
            echo "sev1_bridge_runs_total ''${runs}"
          } > "$TMP"
          mv "$TMP" "$OUT"
        '';
      };

      sev1OverlayShell = pkgs.writeTextDir "shell.qml" ''
        pragma ComponentBehavior: Bound

        import QtQuick
        import Quickshell
        import Quickshell.Io
        import Quickshell.Wayland

        ShellRoot {
            id: root

            // Written by sev1-bridge.service every 10s while ANY SEV1
            // condition is active: line 1 title, line 2 detail, line 3
            // generated-at epoch. SELF-EXPIRY: a bridge death can never
            // leave this overlay stuck — it hides once the file is older
            // than the TTL (the bridge refreshes it every run).
            readonly property string alertPath: Quickshell.env("SEV1_ALERT_FILE") || "/run/systemnix/sev1/alert"
            property int alertTtl: {
                const raw = Quickshell.env("SEV1_ALERT_TTL");
                const parsed = raw ? parseInt(raw) : 300;
                return parsed > 0 ? parsed : 300;
            }

            property string alertTitle: ""
            property string alertDetail: ""
            property real generatedAt: 0
            // Line 4 of the alert file: "page" (red fullscreen + pulsing,
            // RESERVED — no current emitter), "warn" (static amber banner,
            // shown once — the bridge downgrades refreshes of the same
            // alert set to "warn-seen"), "notify" (no overlay).
            // Missing/unknown line 4 fails LOUD (treated as page): a real
            // emergency must never be silenced by a parse gap.
            property string severity: "page"
            readonly property bool isPage: root.severity == "page"
            readonly property bool isWarn: root.severity == "warn"
            readonly property bool active: root.generatedAt > 0 && (root.isPage || root.isWarn) && (Date.now() / 1000 - root.generatedAt) < root.alertTtl

            function parseAlert(text) {
                const lines = (text ?? "").split("\n");
                const gen = parseInt(lines[2]);
                if (!gen || gen <= 0) {
                    root.generatedAt = 0;
                    root.alertTitle = "";
                    root.alertDetail = "";
                    return;
                }
                root.alertTitle = lines[0] ?? "SEV1";
                root.alertDetail = lines[1] ?? "";
                root.severity = (lines[3] ?? "page").trim();
                root.generatedAt = gen;
            }

            FileView {
                id: alertFile
                path: root.alertPath
                watchChanges: true
                printErrors: false
                onLoaded: root.parseAlert(alertFile.text())
                onLoadFailed: {
                    root.generatedAt = 0;
                }
            }

            Timer {
                interval: 500
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    alertFile.reload();
                }
            }

            Variants {
                model: Quickshell.screens

                delegate: PanelWindow {
                    id: overlay

                    required property var modelData

                    screen: modelData
                    visible: root.active
                    updatesEnabled: root.active

                    WlrLayershell.namespace: "systemnix:sev1-overlay"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.exclusionMode: ExclusionMode.Ignore

                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }

                    color: "transparent"
                    mask: Region {}

                    Rectangle {
                        anchors.fill: parent
                        color: root.isPage ? "#e61a0505" : "#e6b8860b"

                        SequentialAnimation on opacity {
                            running: overlay.visible && root.isPage
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.6
                                duration: 700
                            }
                            NumberAnimation {
                                to: 1
                                duration: 700
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 24

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.isPage ? "SEVERE — SYSTEM EMERGENCY" : "WARNING — HARDWARE CRITICAL"
                                color: root.isPage ? "#ffe0e0" : "#fff3c4"
                                font.pixelSize: Math.min(overlay.width, overlay.height) * 0.035
                                font.weight: Font.Black
                                font.letterSpacing: 10
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.alertTitle
                                color: root.isPage ? "#ff2b2b" : "#ffd24d"
                                font.pixelSize: Math.min(overlay.width, overlay.height) * 0.05
                                font.weight: Font.Black
                                font.family: "monospace"
                                wrapMode: Text.Wrap
                                width: Math.min(overlay.width * 0.85, 1400)
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.alertDetail
                                color: root.isPage ? "#ffd7d7" : "#ffedb8"
                                font.pixelSize: Math.min(overlay.width, overlay.height) * 0.025
                                font.weight: Font.Bold
                                maximumLineCount: 4
                                wrapMode: Text.Wrap
                                width: Math.min(overlay.width * 0.8, 1200)
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
      '';
    in
    {
      options.services.sev1-escalation = {
        enable = lib.mkEnableOption "SEV1 escalation bridge: local unmissable escalation (red fullscreen RESERVED, static yellow once-banner for infra hardware criticals, notification-only for memory/meta) for guard/memory/infra conditions when a graphical session is online (2026-08-22 freeze lesson: Discord fired 43min early, nobody saw it)";

        desktopUser = lib.mkOption {
          type = lib.types.str;
          default = "lars";
          description = "User whose graphical session receives the DMS notification and overlay";
        };

        checkInterval = lib.mkOption {
          type = lib.types.str;
          default = "10s";
          description = "Bridge polling interval. Also the alert-file freshness period — the overlay self-expires after two missed refreshes";
        };

        staleGuardSeconds = lib.mkOption {
          type = lib.types.int;
          default = 300;
          description = "Guard metrics age (seconds) beyond which the guard counts as DEAD (SEV1)";
        };

        staleHealthSeconds = lib.mkOption {
          type = lib.types.int;
          default = 600;
          description = "system-health metrics age (seconds) beyond which monitoring counts as STALE (notify-tier: single notification + Gatus, NO fullscreen overlay — 2026-08-31 movie-night decision)";
        };

        notifyCooldownSeconds = lib.mkOption {
          type = lib.types.int;
          default = 1800;
          description = ''
            Minimum seconds between notify/warn-tier (non-page) desktop
            notifications. These conditions are flap-prone — the collector
            itself oscillates stale/healthy under I/O pressure — so
            re-notification after a clear/refire cycle is suppressed within
            this window (2026-08-31 movie-night lesson: 4 consecutive
            collector timeouts re-paged on every cycle). Page-tier
            notifications are never cooldown-gated.
          '';
        };

        bootGraceSeconds = lib.mkOption {
          type = lib.types.int;
          default = 600;
          description = ''
            Seconds after boot during which DEAD/STALE and infra-critical
            evaluations are suppressed: collectors haven't produced fresh
            metrics yet, so every check would page falsely on each reboot
            (live 2026-08-31: a stale pre-shutdown guard prom paged
            "MEMORY GUARD DEAD" one minute into boot). The grace can be
            disabled per-invocation with SEV1_BOOT_GRACE_SEC=0 (used by the
            VM regression test).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        systemd = {
          tmpfiles.rules = [
            (mkStateDir textfileDir "1777" "nobody" "nogroup")
            "d /run/systemnix/sev1 0755 root root -"
          ];

          services.sev1-bridge = {
            description = "SEV1 escalation bridge: local overlay + notification for critical conditions";
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "64M";
                # Sticky 1777 textfile dir: rename-over-foreign-file needs
                # CAP_FOWNER (the 2026-08-22 guard dead-on-arrival lesson).
                CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_OVERRIDE";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                StateDirectory = "sev1-escalation";
                ExecStart = lib.getExe bridgeScript;
                ReadWritePaths = [
                  textfileDir
                  "/run/systemnix/sev1"
                ];
              }
            ];
          };

          timers.sev1-bridge = {
            description = "Run the SEV1 escalation bridge";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "1min";
              OnUnitActiveSec = cfg.checkInterval;
            };
          };

          user.services.sev1-overlay = {
            description = "Fullscreen SEV1 emergency overlay on all monitors";
            after = [ "graphical-session.target" ];
            partOf = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];

            environment = {
              SEV1_ALERT_TTL = "120";
            };

            restartTriggers = [ sev1OverlayShell ];

            serviceConfig = {
              Type = "simple";
              ExecStart = "${lib.getExe pkgs.quickshell} -p ${sev1OverlayShell}";
              Restart = "always";
              RestartSec = "5s";
              MemoryMax = "256M";
            };
            startLimitBurst = 5;
            startLimitIntervalSec = 120;
          };
        };
      };
    };
}
