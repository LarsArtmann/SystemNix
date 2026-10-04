# crush-debug: one keybind turns a system error into a crush agent session.
# Lists failed systemd units (system + user) and the active sev1 alert, bundles
# journal evidence, then runs a headless crush fix pass in the SystemNix flake
# and reopens the session interactively for follow-up.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.systemnix-crush-debug;

  crushDebug = pkgs.writeShellApplication {
    name = "crush-debug";
    runtimeInputs = with pkgs; [
      coreutils
      fzf
      findutils
      gnugrep
      gawk
      systemd
      trash-cli
    ];
    text = ''
      # Hand a failing systemd unit or the active sev1 alert to a crush agent.
      #   crush-debug            picker over failed units + sev1, then auto-fix
      #   crush-debug <unit>     target one unit directly (scope auto-detected)
      #   crush-debug --review   skip the auto fix pass, open crush for manual work
      #   crush-debug --yolo     auto pass accepts every permission
      #   crush-debug -          also capture piped stdin as evidence

      STATE_ROOT="''${XDG_STATE_HOME:-$HOME/.local/state}/crush-debug"
      REPO="$HOME/projects/SystemNix"
      MODE="auto"
      EXTRA_ARGS=""
      UNIT=""
      STDIN_EVIDENCE=0

      journal_out() {
        # journal_out <scope> <unit> <count> <format>
        if [ "$1" = "user" ]; then
          journalctl --user -u "$2" -n "$3" --no-pager -o "$4" 2>/dev/null || true
        else
          journalctl -u "$2" -n "$3" --no-pager -o "$4" 2>/dev/null || true
        fi
      }

      hint_line() {
        # one representative journal line for the picker
        line=$(journal_out "$1" "$2" 30 cat | grep -iE 'error|fail|fatal|exception|refused|denied|timed? ?out' | tail -n 1 || true)
        if [ -z "$line" ]; then
          line=$(journal_out "$1" "$2" 1 cat | tail -n 1 || true)
        fi
        printf '%s' "''${line:0:120}"
      }

      add_unit_entries() {
        local scope="$1" unit desc hint
        while IFS=$'\t' read -r unit desc; do
          [ -n "$unit" ] || continue
          hint=$(hint_line "$scope" "$unit")
          entries+="''${scope}"$'\t'"''${unit}"$'\t'"''${desc}"$'\t'"''${hint}"$'\n'
        done < <(
          if [ "$scope" = "user" ]; then
            systemctl --user list-units --state=failed --no-legend --plain 2>/dev/null || true
          else
            systemctl list-units --state=failed --no-legend --plain 2>/dev/null || true
          fi | awk -F' +' '{ unit=$1; $1=""; $2=""; $3=""; $4=""; sub(/^ +/, ""); print unit "\t" $0 }'
        )
      }

      preview_entry() {
        case "$scope" in
          sev1)
            echo "=== /run/systemnix/sev1/alert ==="
            cat /run/systemnix/sev1/alert 2>/dev/null || true
            echo
            echo "=== memory-emergency-guard.service journal (last 60) ==="
            journalctl -u memory-emergency-guard.service -n 60 --no-pager 2>/dev/null | tail -n 60 || true
            ;;
          *)
            echo "=== $scope unit: $unit ==="
            if [ "$scope" = "user" ]; then
              systemctl --user status "$unit" --no-pager -l 2>&1 | head -n 15 || true
            else
              systemctl status "$unit" --no-pager -l 2>&1 | head -n 15 || true
            fi
            echo
            echo "=== journal (last 100) ==="
            journal_out "$scope" "$unit" 100 short-iso | tail -n 100
            ;;
        esac
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --review) MODE="review" ;;
          --auto) MODE="auto" ;;
          --yolo) EXTRA_ARGS="--yolo" ;;
          -h|--help)
            printf '%s\n' \
              "crush-debug: hand a failing unit or the active sev1 alert to a crush agent." \
              "  crush-debug            pick from failed units + sev1, then auto-fix via crush" \
              "  crush-debug <unit>     target one unit directly" \
              "  crush-debug --review   skip the auto pass, open crush for manual work" \
              "  crush-debug --yolo     auto pass accepts every permission" \
              "  crush-debug -          also capture piped stdin as evidence"
            exit 0
            ;;
          --preview)
            scope="''${2:-}"
            unit="''${3:-}"
            preview_entry
            exit 0
            ;;
          -) STDIN_EVIDENCE=1 ;;
          *) UNIT="$1" ;;
        esac
        shift
      done

      entries=""
      add_unit_entries system
      add_unit_entries user
      if [ -r /run/systemnix/sev1/alert ]; then
        sev1_title=$(head -n 1 /run/systemnix/sev1/alert 2>/dev/null || true)
        entries+="sev1"$'\t'"alert"$'\t'"''${sev1_title:-active sev1 alert}"$'\t'"''${sev1_title}"$'\n'
      fi

      if [ -n "$UNIT" ]; then
        scope="system"
        if [ "$UNIT" = "alert" ] && [ -r /run/systemnix/sev1/alert ]; then
          scope="sev1"
        elif ! systemctl cat "$UNIT" >/dev/null 2>&1; then
          scope="user"
        fi
        unit="$UNIT"
      else
        if [ -z "$entries" ]; then
          echo "crush-debug: no failed units and no active sev1 alert. Nothing to debug."
          exit 0
        fi
        sel=$(printf '%s' "$entries" | fzf \
          --delimiter='\t' \
          --with-nth=2,4 \
          --preview="$0 --preview {1} {2}" \
          --preview-window=right:60%:wrap \
          --prompt='error> ' \
          --header='Select an error to hand to crush (Esc aborts)') || exit 0
        scope=$(printf '%s' "$sel" | cut -f1)
        unit=$(printf '%s' "$sel" | cut -f2)
      fi

      ts=$(date +%Y%m%d-%H%M%S)
      safe_unit=$(printf '%s' "$unit" | tr -c 'A-Za-z0-9._@-' '_')
      ws="$STATE_ROOT/$ts-$safe_unit"
      mkdir -p "$ws"
      ev="$ws/evidence.txt"
      {
        echo "crush-debug evidence bundle"
        echo "host: $(uname -n)"
        echo "captured: $(date -Is)"
        echo "scope: $scope"
        echo "unit: $unit"
        case "$scope" in
          sev1)
            echo
            echo "=== /run/systemnix/sev1/alert ==="
            cat /run/systemnix/sev1/alert 2>/dev/null || true
            echo
            echo "=== memory-emergency-guard.service journal (last 150) ==="
            journalctl -u memory-emergency-guard.service -n 150 --no-pager 2>/dev/null | tail -n 150 || true
            ;;
          *)
            echo
            echo "=== systemctl status ==="
            if [ "$scope" = "user" ]; then
              systemctl --user status "$unit" --no-pager -l 2>&1 || true
            else
              systemctl status "$unit" --no-pager -l 2>&1 || true
            fi
            echo
            echo "=== rendered unit file(s) (systemctl cat) ==="
            if [ "$scope" = "user" ]; then
              systemctl --user cat "$unit" 2>&1 || true
            else
              systemctl cat "$unit" 2>&1 || true
            fi
            echo
            echo "=== journal (last 300 lines) ==="
            journal_out "$scope" "$unit" 300 short-iso | tail -n 300
            ;;
        esac
        if [ "$STDIN_EVIDENCE" -eq 1 ]; then
          echo
          echo "=== piped stdin ==="
          cat
        fi
      } > "$ev"

      find "$STATE_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%T@\t%p\n' 2>/dev/null \
        | sort -rn | tail -n +21 | cut -f2- | xargs -r trash 2>/dev/null || true

      extra=""
      if [ "$scope" = "sev1" ]; then
        extra="This is the sev1 escalation alert; the owning modules are modules/nixos/services/sev1-escalation.nix and modules/nixos/services/memory-emergency-guard.nix."
      fi

      prompt="Debug and fix the failing $scope entry '$unit' on this host.
      Full evidence bundle: $ev
      It holds systemctl status, the rendered unit file, and the journal tail (for sev1: the alert file and the guard journal).
      $extra
      The unit is declared in THIS repo (the SystemNix NixOS flake). Find the owning module (modules/nixos/services/, modules/nixos/desktop/, or platforms/) and fix the Nix configuration there. Never hand-patch the live system: fixes land in the flake and ship via 'nix run .#deploy'.
      Do:
      1. Read AGENTS.md before editing anything (house rules: 2-space indent, trash not rm, ports in lib/ports.nix, harden {} + serviceDefaults, monitoring via the integration registry).
      2. Diagnose the root cause from the evidence before changing anything.
      3. Implement the minimal correct fix.
      4. Verify with 'nix flake check --no-build'.
      5. End with a short summary: root cause, files changed, and whether a deploy is needed. Do NOT deploy yourself; tell me to run 'nix run .#deploy'.
      If the root cause is an upstream bug in a LarsArtmann repo (not SystemNix config), do not patch around it here: name the repo and the fix that belongs upstream."
      printf '%s' "$prompt" > "$ws/prompt.txt"

      if [ ! -d "$REPO" ]; then
        echo "crush-debug: SystemNix checkout not found at $REPO" >&2
        exit 1
      fi
      cd "$REPO" || exit 1

      if [ "$MODE" = "review" ]; then
        echo "crush-debug: review mode. Evidence: $ev"
        echo "Prompt (also saved at $ws/prompt.txt):"
        printf '%s\n' "$prompt"
        echo
        exec crush
      fi

      echo ">>> crush-debug: handing '$unit' to crush in $REPO"
      echo ">>> evidence: $ev"
      # shellcheck disable=SC2086
      crush run $EXTRA_ARGS "$prompt" || echo ">>> crush run finished non-zero; opening the session for review"
      crush --continue || crush
    '';
  };
in
{
  options.programs.systemnix-crush-debug = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the crush-debug error-to-agent launcher and its niri keybind.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ crushDebug ];

    programs.niri.settings.binds."Mod+Ctrl+D".action.spawn = [
      "ghostty"
      "--class"
      "floating"
      "-e"
      "crush-debug"
    ];
  };
}
