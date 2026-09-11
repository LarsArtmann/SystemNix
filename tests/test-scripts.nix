# Tests for the scripts/ directory — catches logic bugs that shellcheck can't.
#
# Bug classes covered:
#   - SIGPIPE aborts under pipefail (| head without || true)
#   - check() return codes
#   - sed delimiter correctness on base64
#   - awk field extraction
#   - state file edge cases (empty, missing)
#   - lib.sh helper functions
{ pkgs }:

{
  lib-helpers = pkgs.testers.runNixOSTest {
    name = "lib-helpers";

    nodes.machine = { pkgs, ... }: {
      # Minimal system with bash + coreutils
      environment.systemPackages = [ pkgs.coreutils-full ];
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      # Test: safe_head doesn't abort under pipefail
      machine.succeed("""
        set -euo pipefail
        source ${../scripts/lib.sh}
        # Generate 100 lines, take 10 — must not SIGPIPE
        result=$(seq 1 100 | safe_head 10)
        [ "$(echo "$result" | wc -l)" -eq 10 ] || { echo "safe_head failed"; exit 1; }
        echo "PASS: safe_head"
      """)

      # Test: summary() exit code reflects failures
      machine.succeed("""
        source ${../scripts/lib.sh}
        ok "test-pass"
        # summary should exit 0 when no failures
        summary || { echo "summary should exit 0"; exit 1; }
        echo "PASS: summary exit code (pass)"
      """)

      machine.succeed("""
        source ${../scripts/lib.sh}
        fail "test-fail"
        # summary should exit 1 when failures exist
        if summary 2>/dev/null; then
          echo "summary should exit 1 on failure"
          exit 1
        fi
        echo "PASS: summary exit code (fail)"
      """)

      # Test: state persistence (empty file edge case)
      machine.succeed("""
        source ${../scripts/lib.sh}
        state_init /tmp/state-test counter 2
        state_hit && echo "should not hit on first" && exit 1
        state_hit || echo "PASS: state threshold (2/3)"
        state_reset
        echo "PASS: state reset"
      """)
    '';
  };

  sed-delimiter = pkgs.testers.runNixOSTest {
    name = "sed-delimiter-base64";

    nodes.machine = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.gnused ];
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      # Test: sed with | delimiter works on base64 strings containing /
      machine.succeed("""
        set -euo pipefail
        echo 'hash = "sha256-abc/def+ghi=";' > /tmp/test-sed.nix
        old_hash="sha256-abc/def+ghi="
        new_hash="sha256-xyz/lmn+opq="
        # Must use | not / as delimiter
        sed -i "s|''${old_hash}|''${new_hash}|g" /tmp/test-sed.nix
        grep -q "xyz/lmn+opq=" /tmp/test-sed.nix || { echo "sed | delimiter failed"; exit 1; }
        echo "PASS: sed | delimiter on base64"
      """)

      # Test: / delimiter FAILS on base64 with /
      machine.succeed("""
        set -euo pipefail
        echo 'hash = "sha256-abc/def+ghi=";' > /tmp/test-sed2.nix
        old_hash="sha256-abc/def+ghi="
        new_hash="sha256-xyz/lmn+opq="
        # / delimiter should produce malformed output
        if sed -i "s/''${old_hash}/''${new_hash}/g" /tmp/test-sed2.nix 2>/dev/null; then
          # sed might "succeed" but produce wrong output
          if grep -q "xyz/lmn+opq=" /tmp/test-sed2.nix; then
            echo "PASS: sed / delimiter accidentally worked (no / in this case)"
          else
            echo "PASS: sed / delimiter breaks as expected on base64 with /"
          fi
        else
          echo "PASS: sed / delimiter errors on base64 with /"
        fi
      """)
    '';
  };

  pipefail-sigpipe = pkgs.testers.runNixOSTest {
    name = "pipefail-sigpipe-safety";

    nodes.machine = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.coreutils-full ];
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      # Test: unguarded | head aborts under pipefail
      machine.fail("""
        set -euo pipefail
        seq 1 1000000 | head -1
      """)

      # Test: guarded | head survives
      machine.succeed("""
        set -euo pipefail
        seq 1 1000000 | head -1 || true
        echo "PASS: guarded pipe survives"
      """)
    '';
  };

  # 2026-09-11 phantom-metric deploy block: gawk treats an input file it
  # cannot open (a /proc/<pid>/stat that vanished between shell glob
  # expansion and open) as a FATAL error — END never runs, stdout stays
  # empty, and the conditionally-emitted metric silently disappears for
  # that collector cycle. The system-health STUCK_DSTATE scan hit exactly
  # this and flipped the pre-deploy phantom-metric gate red.
  awk-vanished-input = pkgs.testers.runNixOSTest {
    name = "awk-vanished-input";

    nodes.machine = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.coreutils-full ];
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      # Fixture: two readable proc-stat-style files + one glob-matching
      # dangling symlink (deterministic stand-in for the race).
      machine.succeed("""
        mkdir -p /tmp/procfix
        printf '100 (procA) D 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 0 5 6\n' > /tmp/procfix/100
        printf '200 (procB) R 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 0 5 6\n' > /tmp/procfix/200
        ln -s /nonexistent-target /tmp/procfix/300
      """)

      # The bug form: awk gets the glob as file arguments — dies fat and
      # SILENT on the vanished entry (empty stdout, not 0).
      machine.succeed("""
        set -euo pipefail
        out=$(awk -v now=100000 '
          {
            line = $0
            sub(/^[^)]*\)[[:space:]]+/, "", line)
            split(line, f, " ")
            if (f[1] == "D" && (now - f[20] / 100) >= 3600)
              n++
          }
          END { print n + 0 }
        ' /tmp/procfix/* 2>/dev/null || true)
        [ -z "$out" ] || { echo "BUG FORM should be empty, got: $out"; exit 1; }
        echo "PASS: direct-awk-on-glob emits nothing when an entry vanishes"
      """)

      # The fixed form: cat absorbs the vanished entry (warning suppressed)
      # and the D-state process is still counted.
      machine.succeed("""
        set -euo pipefail
        out=$(cat /tmp/procfix/* 2>/dev/null |
          awk -v now=100000 '
            {
              line = $0
              sub(/^[^)]*\)[[:space:]]+/, "", line)
              split(line, f, " ")
              if (f[1] == "D" && (now - f[20] / 100) >= 3600)
                n++
            }
            END { print n + 0 }
          ' || true)
        [ "$out" = "1" ] || { echo "fixed form should count 1, got: $out"; exit 1; }
        echo "PASS: cat-pipe form survives the vanished entry and counts"
      """)

      # Functional: the exact deployed /proc pipeline always emits an integer.
      machine.succeed("""
        set -euo pipefail
        out=$(cat /proc/[0-9]*/stat 2>/dev/null |
          awk -v now="$(awk '{print int($1)}' /proc/uptime)" '
            {
              line = $0
              sub(/^[^)]*\)[[:space:]]+/, "", line)
              split(line, f, " ")
              if (f[1] == "D" && (now - f[20] / 100) >= 3600)
                n++
            }
            END { print n + 0 }
          ' || true)
        case "$out" in ""|*[!0-9]*) echo "proc pipeline emitted non-integer: $out"; exit 1;; esac
        echo "PASS: live /proc pipeline emits integer: $out"
      """)

      # Static tripwire: system-health.nix must keep the cat-pipe form and
      # must never hand the /proc glob to awk as file arguments again.
      machine.succeed("""
        grep -q 'cat /proc/\[0-9\]\*/stat' ${../modules/nixos/services/system-health.nix} || {
          echo "system-health.nix lost the cat-pipe /proc guard"
          exit 1
        }
        if grep -q "' /proc/\[0-9\]\*/stat" ${../modules/nixos/services/system-health.nix}; then
          echo "system-health.nix passes the /proc glob directly to awk (gawk-fatal class)"
          exit 1
        fi
        echo "PASS: module keeps the cat-pipe form"
      """)
    '';
  };
}
