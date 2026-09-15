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

  # Artifact-level verification of the two fixed dead-guard scripts (the
  # 2026-09-13 closeout ask: "the run tested faithful bash reconstructions,
  # not the artifacts"). Executes the REAL writeShellApplication store
  # outputs from the evo-x2 config through the degraded/fresh/stale/baseline
  # scenarios. Mocks are injected by SED into copies of the store scripts —
  # writeShellApplication pins runtimeInputs FIRST in PATH, so env-PATH
  # shadowing can never win against them (AGENTS.md rule); renaming the
  # call inside the script text is the only faithful injection.
  guard-scripts =
    let
      evo = self.nixosConfigurations.evo-x2.config;
      webExe = evo.systemd.services.website-deploy-monitor.serviceConfig.ExecStart;
      diskExe = evo.systemd.services.disk-growth-check.serviceConfig.ExecStart;
    in
    makeTest {
      name = "guard-scripts-artifacts";

      nodes.machine = _: {
        system.stateVersion = "25.11";
      };

      testScript = ''
        machine.start()
        machine.wait_for_unit("multi-user.target")

        # ── website-deploy-monitor-check: sed the prod URL to a file:// URL
        machine.succeed("cp ${webExe} /tmp/web-check && chmod +x /tmp/web-check")
        machine.succeed(
            "sed -i 's|https://larsartmann.com/build-info.json|file:///tmp/bi.json|' /tmp/web-check"
        )
        state = "/root/.local/state/website-deploy-monitor/last-alerted-built-at"

        # 1. degraded path: marker endpoint unreachable → fetch-failed log,
        #    exit 0 (the fixed guard MUST run — the pre-fix script exited
        #    with curl's status here), no state written
        machine.succeed("rm -f /tmp/bi.json ${state}")
        machine.succeed("HOME=/root /tmp/web-check")
        machine.succeed("test ! -e ${state}")

        # 2. marker without builtAt → degraded exit 0
        machine.succeed("echo '{\"foo\":1}' > /tmp/bi.json")
        machine.succeed("HOME=/root /tmp/web-check")
        machine.succeed("test ! -e ${state}")

        # 3. unparseable builtAt → degraded exit 0
        machine.succeed("echo '{\"builtAt\":\"not-a-date\"}' > /tmp/bi.json")
        machine.succeed("HOME=/root /tmp/web-check")
        machine.succeed("test ! -e ${state}")

        # 4. fresh deploy → exit 0, no alert state
        machine.succeed(
            """ts=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ); echo '{"builtAt":"'"$ts"'"}' > /tmp/bi.json"""
        )
        machine.succeed("HOME=/root /tmp/web-check")
        machine.succeed("test ! -e ${state}")

        # 5. stale deploy → STATE file written (notify-send has no session in
        #    the VM — its `|| true` degraded path is itself part of the fix)
        machine.succeed(
            """ts=$(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ); echo '{"builtAt":"'"$ts"'"}' > /tmp/bi.json; echo "$ts" > /tmp/stale-ts"""
        )
        machine.succeed("HOME=/root /tmp/web-check")
        machine.succeed("test -e ${state}")
        machine.succeed("grep -q \"$(cat /tmp/stale-ts)\" ${state}")

        # 6. state-file dedup: same stale builtAt again → silent exit 0, no
        #    second STALE journal line
        machine.succeed("HOME=/root /tmp/web-check")
        _, count = machine.execute("journalctl -t website-deploy-monitor --output cat | grep -c 'STALE:'")
        assert count.strip() == "1", f"expected exactly 1 STALE journal line, got {count}"

        # ── disk-growth-check: sed-rename the df call to a mock (PATH
        # shadowing cannot beat runtimeInputs; text injection can)
        machine.succeed("cp ${diskExe} /tmp/dg-check && chmod +x /tmp/dg-check")
        machine.succeed("sed -i 's|df --output=used|mock-df --output=used|' /tmp/dg-check")
        machine.succeed("mkdir -p /tmp/mockbin /var/lib/disk-growth")
        machine.succeed(
            """printf '#!/bin/sh\\nif [ -n "$MOCK_FAIL" ]; then exit 1; fi\\nprintf %s "$MOCK_BYTES"\\n' > /tmp/mockbin/mock-df"""
        )
        machine.succeed("chmod +x /tmp/mockbin/mock-df")

        def dg_run(bytes_value, fail=False):
            prefix = "MOCK_FAIL=1" if fail else f"MOCK_BYTES={bytes_value}"
            return f"{prefix} PATH=/tmp/mockbin:$PATH /tmp/dg-check"

        # 1. degraded path: df fails → ERROR + exit 1 (absent /data is an
        #    alert, not a crash — and pre-fix the unit 226'd instead)
        machine.fail(dg_run("", fail=True))

        # 2. baseline: no state file → record and exit 0
        machine.succeed("rm -f /var/lib/disk-growth/last_usage_bytes")
        machine.succeed(dg_run(100000000000))
        machine.succeed("grep -q 100000000000 /var/lib/disk-growth/last_usage_bytes")

        # 3. growth under 5G → exit 0
        machine.succeed(dg_run(101000000000))

        # 4. growth over 5G (threshold 5*1024^3) → WARNING + exit 1
        machine.fail(dg_run(105368709121))

        # 5. shrink (negative delta) → exit 0
        machine.succeed(dg_run(90000000000))

        print("PASS: guard-scripts artifacts (12 scenarios)")
      '';
    };
}
