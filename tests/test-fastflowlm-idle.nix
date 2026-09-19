# Artifact-level unit test for the FastFlowLM idle-check script (no VM).
#
# The idle check guards the 21.6 GB model: stopping the backend during a
# cold load or active traffic re-pays a multi-minute QLC read. Two of its
# guards exist because of live incidents (the absolute-monotonic-timestamp
# bug and the journal-blind cold-load kill, both 2026-08-18), and one
# regression class is catastrophic (stopping fastflowlm.socket kills the
# :52625 listener until manual intervention). This test runs the SHIPPED
# writeShellApplication artifact with stubbed systemctl/journalctl and
# asserts all five decision paths.
#
# Stubs are sed-INJECTED into the script text: the writeShellApplication
# wrapper pins PATH to its runtimeInputs (systemd first among them), so
# PATH-level stubs can never shadow the real binaries (the DMS lesson).
{ pkgs, self }:

let
  idleExec =
    self.nixosConfigurations.evo-x2.config.systemd.services.fastflowlm-idle.serviceConfig.ExecStart;
in
pkgs.runCommand "test-fastflowlm-idle-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
    ];
    meta.description = "FastFlowLM idle-check decision-path unit test (stubbed systemctl/journalctl)";
  }
  ''
    set -euo pipefail
    work="$PWD/idle-test"
    mkdir -p "$work/stubs"
    export STUBS="$work/stubs"
    src="${idleExec}"

    # --- inject stubs into the shipped artifact, asserting coverage BEFORE
    # running: a failed injection must fail loudly, never phantom-green.
    sed -e 's|\bsystemctl\b|$STUBS/systemctl|g' \
        -e 's|/nix/store/[^ ]*/bin/journalctl|$STUBS/journalctl|g' \
        "$src" > "$work/idle-check"
    chmod +x "$work/idle-check"

    n_systemctl="$(grep -c '\$STUBS/systemctl' "$work/idle-check" || true)"
    if [ "$n_systemctl" -lt 4 ]; then
      echo "FAIL: systemctl stub injection incomplete ($n_systemctl/4 sites)"
      exit 1
    fi
    n_jctl="$(grep -c '\$STUBS/journalctl' "$work/idle-check" || true)"
    if [ "$n_jctl" -ne 1 ]; then
      echo "FAIL: journalctl stub injection incomplete ($n_jctl/1 sites)"
      exit 1
    fi
    echo "PASS: stub injection coverage (4 systemctl, 1 journalctl)"

    # --- stubs (mode-driven) ---
    cat > "$STUBS/systemctl" <<'EOF'
      #!${pkgs.bash}/bin/bash
      MODE="''${MODE:-}"
      STOP_LOG="''${STOP_LOG:-/dev/null}"
      cmd="''${1:-}"
      case "$cmd" in
        is-active)
          if [ "$MODE" = "inactive" ]; then exit 1; fi
          exit 0
          ;;
        list-units)
          if [ "$MODE" = "live-instance" ]; then
            echo "fastflowlm@1.service loaded active running flm proxy bridge"
          fi
          exit 0
          ;;
        show)
          now="$(awk '{printf "%d", $1 * 1000000}' /proc/uptime)"
          case "$MODE" in
            fresh) echo $((now - 300000000)) ;;
            old-traffic | old-silent) echo $((now - 7200000000)) ;;
            *) echo "$now" ;;
          esac
          exit 0
          ;;
        stop)
          echo "stop: $*" >> "$STOP_LOG"
          exit 0
          ;;
        *)
          echo "stub: unexpected systemctl subcommand: $cmd" >&2
          exit 64
          ;;
      esac
    EOF
    chmod +x "$STUBS/systemctl"

    cat > "$STUBS/journalctl" <<'EOF'
      #!${pkgs.bash}/bin/bash
      MODE="''${MODE:-}"
      if [ "$MODE" = "old-traffic" ]; then
        echo "TCP connection established"
        exit 0
      fi
      exit 1
    EOF
    chmod +x "$STUBS/journalctl"

    # --- case runner: idle-check must ALWAYS exit 0 (it is a timer probe,
    # never a failure surface); stop behavior asserted per mode.
    run_case() {
      local mode="$1" expect="$2"
      local log="$work/stop-$mode.log"
      : > "$log"
      local rc=0
      MODE="$mode" STOP_LOG="$log" "$work/idle-check" \
        > "$work/out-$mode.log" 2>&1 || rc=$?
      if [ "$rc" -ne 0 ]; then
        echo "FAIL [$mode]: idle-check exited $rc (want 0)"
        cat "$work/out-$mode.log"
        exit 1
      fi
      if [ "$expect" = "no" ] && [ -s "$log" ]; then
        echo "FAIL [$mode]: stop recorded but none expected: $(cat "$log")"
        exit 1
      fi
      echo "PASS [$mode]"
    }

    run_case inactive no
    run_case live-instance no
    run_case fresh no
    run_case old-traffic no

    run_case old-silent stop
    log="$work/stop-old-silent.log"
    if ! grep -q 'fastflowlm@' "$log"; then
      echo "FAIL [old-silent]: per-connection instances not stopped"
      cat "$log"
      exit 1
    fi
    if ! grep -q ' fastflowlm\.service' "$log"; then
      echo "FAIL [old-silent]: backend not stopped"
      cat "$log"
      exit 1
    fi
    if grep -q 'socket' "$log"; then
      echo "FAIL [old-silent]: socket must NEVER be stopped (2026-08-18 regression: killing the socket kills :52625 until manual intervention)"
      cat "$log"
      exit 1
    fi
    echo "PASS [old-silent]: instances+backend stopped, socket untouched"

    mkdir -p "$out"
    cp "$work"/stop-*.log "$work"/out-*.log "$out/" 2>/dev/null || true
    echo "ALL PASS: 5 decision paths + stub coverage + socket-safety" > "$out/summary"
  ''
