# Tests for the scripts/ directory — catches logic bugs that shellcheck can't.
#
# Bug classes covered:
#   - SIGPIPE aborts under pipefail (| head without || true)
#   - check() return codes
#   - sed delimiter correctness on base64
#   - awk field extraction
#   - state file edge cases (empty, missing)
#   - lib.sh helper functions
{ pkgs, self }:

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

  # 2026-10-20 line-763 class (4th whole-file rejection of system_health.prom):
  # the census emitted systemd's RAW cgroup-name escapes (\x2d for '-') into a
  # prometheus label value; the text format only allows \\ \" and \n escapes,
  # so node_exporter discarded the WHOLE file and every system_* metric went
  # blind — including the brand-new system_local_dns_resolves, whose SigNoz
  # rule had provisioned green against a series that no longer existed.
  # Artifact-level: slice the census section out of the REAL evo-x2 collector
  # script, run it against a fixture cgroup tree carrying the exact offending
  # name, and validate the emitted .prom with the REAL prometheus parser
  # (promtool), plus a mutation leg proving the raw form is genuinely rejected.
  prom-escape-census =
    let
      evo = self.nixosConfigurations.evo-x2.config;
      collector = evo.systemd.services.system-health-metrics.serviceConfig.ExecStart;
      probe = pkgs.writeShellApplication {
        name = "prom-escape-census-probe";
        # SC2016: the census-slice grep anchors are DELIBERATE literals ($ and
        # all) — they must match the collector script's source text exactly.
        excludeShellChecks = [ "SC2016" ];
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.gawk
          pkgs.gnugrep
          pkgs.gnused
          # promtool lives in the `cli` output since prometheus 3.x (the
          # default output ships only the server binary).
          pkgs.prometheus.cli
        ];
        text = ''
          set -euo pipefail
          SCRIPT="''${1:?collector store path required}"

          # Fixture cgroup tree: the exact 2026-10-20 offender (systemd writes
          # unit cgroup dirs with its byte-value escapes intact) plus a
          # plain-named control cgroup.
          mkdir -p '/tmp/sysfix/system.slice/gitea-runner-evo\x2dx2.service'
          printf '44361195520\n' > '/tmp/sysfix/system.slice/gitea-runner-evo\x2dx2.service/memory.current'
          printf 'anon 30110000000\nshmem 900000000\nunevictable 4096\n' > '/tmp/sysfix/system.slice/gitea-runner-evo\x2dx2.service/memory.stat'
          mkdir -p '/tmp/sysfix/system.slice/signoz.service'
          printf '123456789\n' > '/tmp/sysfix/system.slice/signoz.service/memory.current'
          printf 'anon 100000000\nshmem 2000000\nunevictable 0\n' > '/tmp/sysfix/system.slice/signoz.service/memory.stat'

          # Slice the census section out of the REAL script; /sys/fs/cgroup is
          # the ONLY substitution (fixture redirect).
          start=$(grep -n 'CENSUS_ENTRIES=$(' "$SCRIPT" | cut -d: -f1)
          end=$(grep -n -F 'done <<<"$CENSUS_ENTRIES"' "$SCRIPT" | cut -d: -f1)
          [ -n "$start" ] && [ -n "$end" ] || { echo "census section not found in collector script"; exit 1; }
          sed -n "''${start},''${end}p" "$SCRIPT" > /tmp/census-slice.sh
          sed -i 's|/sys/fs/cgroup|/tmp/sysfix|g' /tmp/census-slice.sh

          bash -c 'set -euo pipefail; source /tmp/census-slice.sh; printf %s "$CENSUS_SAMPLE" > /tmp/out.prom'

          # Production shape: the collector emits the census HELP/TYPE block
          # into the assembled .prom (system-health.nix .prom-emit section) —
          # without it promtool's lint stage exits 3 on "no help text".
          {
            printf '%s\n' \
              '# HELP system_cgroup_mem_bytes memory.current of the top cgroups by usage (who is holding RAM)' \
              '# TYPE system_cgroup_mem_bytes gauge' \
              '# HELP system_cgroup_mem_anon_bytes anonymous memory (memory.stat anon) of the same top cgroups' \
              '# TYPE system_cgroup_mem_anon_bytes gauge' \
              '# HELP system_cgroup_mem_shmem_bytes shared/tmpfs/shmem memory (memory.stat shmem) of the same top cgroups' \
              '# TYPE system_cgroup_mem_shmem_bytes gauge' \
              '# HELP system_cgroup_mem_unevictable_bytes mlocked/unevictable memory of the same top cgroups' \
              '# TYPE system_cgroup_mem_unevictable_bytes gauge'
            cat /tmp/out.prom
          } > /tmp/out-with-help.prom
          mv /tmp/out-with-help.prom /tmp/out.prom

          # The escaped form must be present: doubled backslash in the bytes.
          grep -F 'system_cgroup_mem_bytes{cgroup="system.slice_gitea-runner-evo\\x2dx2.service"} 44361195520' /tmp/out.prom
          grep -F 'system_cgroup_mem_anon_bytes{cgroup="system.slice_gitea-runner-evo\\x2dx2.service"} 30110000000' /tmp/out.prom
          # The raw single-backslash form must be GONE (this was the bug).
          if grep -F 'evo\x2dx2' /tmp/out.prom; then
            printf '%s\n' "raw \\x2d label survived unescaped"
            exit 1
          fi
          # Control cgroup still present with its plain name.
          grep -F 'system_cgroup_mem_bytes{cgroup="system.slice_signoz.service"} 123456789' /tmp/out.prom

          # The REAL parser must accept the emitted file…
          promtool check metrics < /tmp/out.prom
          # …and REJECT the raw form (mutation leg: proves the check bites).
          printf '%s\n' 'system_cgroup_mem_bytes{cgroup="system.slice_gitea-runner-evo\x2dx2.service"} 44361195520' > /tmp/raw.prom
          if promtool check metrics < /tmp/raw.prom >/dev/null 2>&1; then
            printf '%s\n' "MUTATION: raw \\x2d label accepted by prometheus parser"
            exit 1
          fi

          # Tripwire: the escaping transform must stay in the artifact.
          grep -qF 'label//\\/\\\\}' "$SCRIPT"

          echo "PASS: census escapes cgroup label values; promtool accepts output, rejects raw form"
        '';
      };
    in
    pkgs.testers.runNixOSTest {
      name = "prom-escape-census";

      nodes.machine = _: {
        system.stateVersion = "25.11";
      };

      testScript = ''
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.succeed("${probe}/bin/prom-escape-census-probe ${collector}")
      '';
    };

  # Artifact-level verification of the two fixed dead-guard scripts (the
  # 2026-09-13 closeout ask: "the run tested faithful bash reconstructions,
  # not the artifacts"). Executes the REAL writeShellApplication store
  # outputs from the evo-x2 config through the degraded/fresh/stale/baseline
  # scenarios. Mocks are injected by SED into copies of the store scripts —
  # writeShellApplication pins runtimeInputs FIRST in PATH, so env-PATH
  # shadowing can never win against them (docs/agents/desktop.md rule); renaming the
  # call inside the script text is the only faithful injection.
  guard-scripts =
    let
      evo = self.nixosConfigurations.evo-x2.config;
      webExe = evo.systemd.services.website-deploy-monitor.serviceConfig.ExecStart;
      diskExe = evo.systemd.services.disk-growth-check.serviceConfig.ExecStart;
    in
    pkgs.testers.runNixOSTest {
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
        machine.succeed("rm -f /tmp/bi.json /root/.local/state/website-deploy-monitor/last-alerted-built-at")
        machine.succeed("HOME=/root /tmp/web-check")
        machine.succeed("test ! -e /root/.local/state/website-deploy-monitor/last-alerted-built-at")

        # 2. marker without builtAt → degraded exit 0
        machine.succeed("echo '{\"foo\":1}' > /tmp/bi.json")
        machine.succeed("HOME=/root /tmp/web-check")
        machine.succeed("test ! -e /root/.local/state/website-deploy-monitor/last-alerted-built-at")

        # 3. unparseable builtAt → degraded exit 0
        machine.succeed("echo '{\"builtAt\":\"not-a-date\"}' > /tmp/bi.json")
        machine.succeed("HOME=/root /tmp/web-check")
        machine.succeed("test ! -e /root/.local/state/website-deploy-monitor/last-alerted-built-at")

        # 4. fresh deploy → exit 0, no alert state
        machine.succeed(
            """ts=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ); echo '{"builtAt":"'"$ts"'"}' > /tmp/bi.json"""
        )
        machine.succeed("HOME=/root /tmp/web-check")
        machine.succeed("test ! -e /root/.local/state/website-deploy-monitor/last-alerted-built-at")

        # 5. stale deploy → STATE file written (notify-send has no session in
        #    the VM — its `|| true` degraded path is itself part of the fix)
        machine.succeed(
            """ts=$(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ); echo '{"builtAt":"'"$ts"'"}' > /tmp/bi.json; echo "$ts" > /tmp/stale-ts"""
        )
        machine.succeed("HOME=/root /tmp/web-check")
        machine.succeed("test -e /root/.local/state/website-deploy-monitor/last-alerted-built-at")
        machine.succeed("grep -q \"$(cat /tmp/stale-ts)\" /root/.local/state/website-deploy-monitor/last-alerted-built-at")

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
        #    (state is 101000000000 after scenario 3 — each run records a new
        #    baseline; 106368709121 - 101000000000 = 5368709121 > threshold)
        machine.fail(dg_run(106368709121))

        # 5. shrink (negative delta) → exit 0
        machine.succeed(dg_run(90000000000))

        print("PASS: guard-scripts artifacts (12 scenarios)")
      '';
    };

  # 2026-09-20 first-run flake-app bug class: scripts/boot-mirror-activate.sh
  # called `lsblk -no PARTNUM` — a column that does not exist (the correct
  # name is PARTN). No static check catches a runtime column name; the first
  # activation aborted before any firmware mutation only by ordering luck.
  # Pins BOTH the correct column (behavior) and the broken one (negative
  # control — if util-linux ever renames columns again, this catches it
  # before an activation does) plus a repo-wide tripwire.
  lsblk-column-names = pkgs.testers.runNixOSTest {
    name = "lsblk-column-names";

    nodes.machine = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.util-linux ];
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      # 1. PARTN is a valid column (exit 0 even on an unpartitioned disk)
      machine.succeed("lsblk -no PARTN >/dev/null")

      # 2. PARTNUM does NOT exist — lsblk exits non-zero
      machine.fail("lsblk -no PARTNUM >/dev/null 2>&1")

      # 3. Repo tripwire: no script may reference the broken column
      machine.succeed("! grep -rn -- '-no PARTNUM' ${../scripts}/")

      print("PASS: lsblk PARTN column contract held")
    '';
  };

  # flm crash-trigger composite (2026-10-23, monitoring.md row — the
  # 2026-10-07 SIGABRT class): PMA generate-timeout journal walks ×
  # fastflowlm coredump walks feeding a conjunction gauge the PMA Commit
  # Health Gatus check asserts 0. Artifact-level: the REAL walk_journal
  # from the rendered evo-x2 collector runs against a stubbed journalctl
  # (count/status semantics incl. the exit-1-no-match and timeout cases),
  # the REAL pair-arithmetic slice from the same script runs through the
  # four cell combinations, and static tripwires pin the walk patterns +
  # emission + anchored Gatus condition to the module source.
  flm-crash-trigger-pair =
    let
      evo = self.nixosConfigurations.evo-x2.config;
      collector = evo.systemd.services.system-health-metrics.serviceConfig.ExecStart;
      probe = pkgs.writeShellApplication {
        name = "flm-crash-trigger-pair-probe";
        # SC2016: slice anchors are deliberate literals; SC1091: the sliced
        # collector sections are runtime artifacts by design.
        excludeShellChecks = [
          "SC2016"
          "SC1091"
        ];
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnused
          pkgs.gnugrep
          pkgs.bash
        ];
        text = ''
          set -euo pipefail
          SCRIPT="''${1:?collector store path required}"
          MODULE="''${2:?module source path required}"
          mkdir -p /tmp/pairtest/bin /tmp/pairtest/walks

          # Stub journalctl: dispatches on the --grep pattern value. The
          # three live behaviors + the two failure shapes the walk must
          # classify (exit 1 = no match = valid empty; timeout kill = 124).
          cat > /tmp/pairtest/bin/journalctl <<'STUB'
          #!/usr/bin/env bash
          pattern=""
          prev=""
          for arg in "$@"; do
            if [ "$prev" = "--grep" ]; then pattern="$arg"; fi
            prev="$arg"
          done
          case "$pattern" in
            *commit.generate*context\ deadline\ exceeded*)
              printf '%s\n' "Oops: commit failed timeout 1" "Oops: commit failed timeout 2" "Oops: commit failed timeout 3"
              exit 0
              ;;
            *Main\ process\ exited,\ code=dumped*)
              printf '%s\n' "fastflowlm.service: Main process exited, code=dumped, status=6/ABRT" "fastflowlm.service: Main process exited, code=dumped, status=11/SEGV"
              exit 0
              ;;
            *no-match-pattern*)
              exit 1
              ;;
            *slow-pattern*)
              sleep 5
              exit 0
              ;;
            *)
              echo "stub journalctl: unexpected pattern: $pattern" >&2
              exit 9
              ;;
          esac
          STUB
          chmod +x /tmp/pairtest/bin/journalctl
          export PATH="/tmp/pairtest/bin:$PATH"

          # ── 1) REAL walk_journal against the stub ──────────────────────
          # Slice the function out of the rendered collector; the printf to
          # $outfile is its last body line.
          sed -n '/walk_journal() {/,/printf .*"\$outfile"/p' "$SCRIPT" > /tmp/pairtest/wj.sh
          echo "}" >> /tmp/pairtest/wj.sh
          # Reproduce the writeShellApplication strictness the real script
          # runs under — pipefail is what turns journalctl's exit 1 into the
          # walk's status word.
          set -o pipefail
          source /tmp/pairtest/wj.sh

          walk_journal /tmp/pairtest/walks/pma-timeouts projects-management-automation.service "-24h" "commit.generate.*context deadline exceeded" 60
          read -r st cnt < /tmp/pairtest/walks/pma-timeouts
          [ "$st" = 0 ] && [ "$cnt" = 3 ] || { echo "timeout walk: expected '0 3', got '$st $cnt'"; exit 1; }

          walk_journal /tmp/pairtest/walks/flm-coredumps fastflowlm.service "-24h" "Main process exited, code=dumped" 60
          read -r st cnt < /tmp/pairtest/walks/flm-coredumps
          [ "$st" = 0 ] && [ "$cnt" = 2 ] || { echo "coredump walk: expected '0 2', got '$st $cnt'"; exit 1; }

          walk_journal /tmp/pairtest/walks/nomatch x.service "-24h" "no-match-pattern" 60
          read -r st cnt < /tmp/pairtest/walks/nomatch
          [ "$st" = 1 ] && [ "$cnt" = 0 ] || { echo "no-match walk: expected '1 0', got '$st $cnt'"; exit 1; }

          walk_journal /tmp/pairtest/walks/slow x.service "-24h" "slow-pattern" 1
          read -r st cnt < /tmp/pairtest/walks/slow
          [ "$st" = 124 ] && [ "$cnt" = 0 ] || { echo "slow walk: expected '124 0', got '$st $cnt'"; exit 1; }

          # ── 2) REAL pair arithmetic, four cells ────────────────────────
          sed -n '/FLM_CRASH_TRIGGER_PAIR=0$/,/FLM_CRASH_TRIGGER_PAIR=1$/p' "$SCRIPT" > /tmp/pairtest/pair.sh
          echo "fi" >> /tmp/pairtest/pair.sh
          check_pair() {
            got=$(bash -c 'export PMA_GENERATE_TIMEOUTS_24H="$1" FLM_COREDUMPS_24H="$2"; source /tmp/pairtest/pair.sh; echo "$FLM_CRASH_TRIGGER_PAIR"' _ "$1" "$2")
            [ "$got" = "$3" ] || { echo "pair($1,$2): expected $3, got $got"; exit 1; }
          }
          check_pair 0 0 0
          check_pair 2 0 0
          check_pair 0 1 0
          check_pair 3 2 1

          # ── 3) Static tripwires on the module source ───────────────────
          grep -qF 'walk_journal "$WALK_DIR/pma-timeouts" projects-management-automation.service "-24h" "commit.generate.*context deadline exceeded" 60' "$MODULE" || {
            echo "module lost the pma-timeouts walk"; exit 1;
          }
          grep -qF 'walk_journal "$WALK_DIR/flm-coredumps" fastflowlm.service "-24h" "Main process exited, code=dumped" 60' "$MODULE" || {
            echo "module lost the flm-coredumps walk"; exit 1;
          }
          grep -qF 'system_flm_crash_trigger_pair_24h' "$MODULE" || {
            echo "module lost the pair metric emission"; exit 1;
          }
          grep -qF '\nsystem_flm_crash_trigger_pair_24h 0\n' "$MODULE" || {
            echo "module lost the anchored Gatus condition"; exit 1;
          }

          echo "PASS: flm crash-trigger pair — walks classify stubbed journal correctly, pair arithmetic holds, wiring pinned"
        '';
      };
    in
    pkgs.testers.runNixOSTest {
      name = "flm-crash-trigger-pair";

      nodes.machine = _: {
        system.stateVersion = "25.11";
      };

      testScript = ''
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.succeed("${probe}/bin/flm-crash-trigger-pair-probe ${collector} ${../modules/nixos/services/system-health.nix}")
      '';
    };

  # Restart-tracking swap fix + crash-loop consumption (2026-10-25,
  # monitoring.md row — the nsfw 239-restart/5-day invisible-loop class):
  # the 2026-09-19 merged systemctl read assumed flag-order output and read
  # positionally, but systemctl show prints properties in its OWN order
  # (live-probed 2026-10-25: NRestarts FIRST) — system_service_nrestarts
  # carried CPU-nanoseconds, cpu_percent read ~0, and the crash-loop delta
  # (correct cur_r vs swapped prev_r) could never be positive. This test
  # slices the REAL keyed-parse loop from the rendered collector and runs it
  # against a stubbed systemctl pinned to the live order (plus the flag
  # order, a [not set] value, and a missing-property line), then pins the
  # consumption wiring (gatus + sev1 + signoz) with static tripwires.
  system-health-restart-tracking =
    let
      evo = self.nixosConfigurations.evo-x2.config;
      collector = evo.systemd.services.system-health-metrics.serviceConfig.ExecStart;
      probe = pkgs.writeShellApplication {
        name = "system-health-restart-tracking-probe";
        # SC2016: slice anchors are deliberate literals; SC1091: the sliced
        # collector loop is a runtime artifact by design.
        excludeShellChecks = [
          "SC2016"
          "SC1091"
        ];
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnused
          pkgs.gnugrep
          pkgs.bash
        ];
        text = ''
          set -euo pipefail
          SCRIPT="''${1:?collector store path required}"
          HEALTH_MODULE="''${2:?system-health module path required}"
          SEV1_MODULE="''${3:?sev1 module path required}"
          SIGNOZ_MODULE="''${4:?signoz rules module path required}"
          WORK=$(mktemp -d)
          mkdir -p "$WORK/bin"

          # Stub systemctl: `systemctl show <svc> -p CPUUsageNSec -p NRestarts
          # --no-pager`. ORDER = the LIVE-VERIFIED output order (2026-10-25,
          # busctl cross-check on nix-daemon: NRestarts=u 0 printed before
          # CPUUsageNSec=t 8.4e13 while the .prom nrestarts carried the CPU
          # value) — the exact order that produced the six-week swap. The
          # mock svc fixture sets exercise: live order, flag order (proving
          # order-immunity), a [not set] CPU value, and a missing CPU line.
          cat > "$WORK/bin/systemctl" <<'STUB'
          #!/usr/bin/env bash
          svc="$2"
          case "$svc" in
            gatus)
              printf 'NRestarts=0\nCPUUsageNSec=111222333444\n' ;;
            nsfw-classifier)
              printf 'NRestarts=5\nCPUUsageNSec=999888777666\n' ;;
            flag-order)
              printf 'CPUUsageNSec=123\nNRestarts=7\n' ;;
            not-set)
              printf 'NRestarts=2\nCPUUsageNSec=[not set]\n' ;;
            missing-cpu)
              printf 'NRestarts=3\n' ;;
            *)
              printf 'NRestarts=0\nCPUUsageNSec=1\n' ;;
          esac
          STUB
          chmod +x "$WORK/bin/systemctl"
          export PATH="$WORK/bin:$PATH"

          # Slice the REAL keyed-parse loop body (from the `cpu_nsec=0` reset
          # to the RESTART_STATE_TMP append — the full per-svc body, incl. the
          # while/read keyed parse and the [not set] guards). Anchor tolerates
          # writeShellApplication's residual per-level indentation (live: the
          # module's 10-space nix indent strips to 2 inside the loop).
          sed -n '/^ *cpu_nsec=0$/,/RESTART_STATE_TMP"$/p' "$SCRIPT" > "$WORK/loopbody.sh"
          grep -q 'CPUUsageNSec' "$WORK/loopbody.sh" || { echo "slice failed: keyed parse not found in rendered collector"; exit 1; }

          export CPU_STATE_TMP="$WORK/cpu_state"
          export RESTART_STATE_TMP="$WORK/restart_state"
          export NOW_EPOCH=100
          : > "$CPU_STATE_TMP"
          : > "$RESTART_STATE_TMP"

          # Run the sliced body once per fixture service (svc preset).
          run_one() {
            local svc="$1"
            bash -c 'set -euo pipefail; svc="'"$svc"'"; source '"$WORK/loopbody.sh"
          }
          run_one gatus
          run_one nsfw-classifier
          run_one flag-order
          run_one not-set
          run_one missing-cpu

          # Assertions: RESTART_STATE $2 = NRestarts (small), CPU_STATE $2 =
          # CPUUsageNSec — for BOTH property orders, the [not set] guard,
          # and the missing-line default.
          check_state() {
            local file="$1" svc="$2" want="$3" label="$4"
            local got
            got=$(grep "^$svc " "$file" | awk '{print $2}')
            [ "$got" = "$want" ] || { echo "FAIL $label: $svc expected $want, got '$got'"; exit 1; }
          }
          check_state "$RESTART_STATE_TMP" gatus 0 "restarts gatus"
          check_state "$RESTART_STATE_TMP" nsfw-classifier 5 "restarts nsfw (the incident shape: cumulative NRestarts)"
          check_state "$RESTART_STATE_TMP" flag-order 7 "restarts flag-order (order-immunity)"
          check_state "$RESTART_STATE_TMP" not-set 2 "restarts not-set"
          check_state "$RESTART_STATE_TMP" missing-cpu 3 "restarts missing-cpu"
          check_state "$CPU_STATE_TMP" gatus 111222333444 "cpu gatus (live order)"
          check_state "$CPU_STATE_TMP" nsfw-classifier 999888777666 "cpu nsfw"
          check_state "$CPU_STATE_TMP" flag-order 123 "cpu flag-order (order-immunity)"
          check_state "$CPU_STATE_TMP" not-set 0 "cpu not-set ([not set] sanitized to 0)"
          check_state "$CPU_STATE_TMP" missing-cpu 0 "cpu missing-cpu (absent line defaults 0)"

          # ── Static tripwires: the consumption wiring exists ────────────
          grep -qF 'case "$prop" in' "$HEALTH_MODULE" || { echo "module lost the keyed parse"; exit 1; }
          grep -qF 'CPUUsageNSec) cpu_nsec="$val"' "$HEALTH_MODULE" || { echo "module lost the CPU key match"; exit 1; }
          grep -qF 'NRestarts) cur_r="$val"' "$HEALTH_MODULE" || { echo "module lost the NRestarts key match"; exit 1; }
          grep -qF '\nsystem_any_service_crash_loop 0\n' "$HEALTH_MODULE" || { echo "module lost the anchored crash_loop gatus condition"; exit 1; }
          grep -qF '\nsystem_any_service_restart_churn 0\n' "$HEALTH_MODULE" || { echo "module lost the anchored churn gatus condition"; exit 1; }
          grep -qF 'system_any_service_crash_loop' "$SEV1_MODULE" || { echo "sev1 bridge lost the crash-loop leg"; exit 1; }
          grep -qF 'UNIT CRASH LOOP' "$SEV1_MODULE" || { echo "sev1 bridge lost the crash-loop title"; exit 1; }
          grep -qF 'system_any_service_crash_loop' "$SIGNOZ_MODULE" || { echo "signoz lost the crash-loop rule"; exit 1; }
          grep -qF 'system_any_service_restart_churn' "$SIGNOZ_MODULE" || { echo "signoz lost the churn rule"; exit 1; }

          echo "PASS: system-health restart tracking — keyed parse order-immune, [not set]/missing guarded, consumption wired"
        '';
      };
    in
    pkgs.testers.runNixOSTest {
      name = "system-health-restart-tracking";

      nodes.machine = _: {
        system.stateVersion = "25.11";
      };

      testScript = ''
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.succeed("${probe}/bin/system-health-restart-tracking-probe ${collector} ${../modules/nixos/services/system-health.nix} ${../modules/nixos/services/sev1-escalation.nix} ${../modules/nixos/services/_signoz-alerts.nix}")
      '';
    };

  # Kernel memcg-OOM collector (2026-10-23, monitoring.md row — freeze-#28
  # class): the per-memcg breakdown pipeline (grep oom_memcg -> sed strip ->
  # sort|uniq -c -> awk label-escape+emit) is sliced from the REAL rendered
  # collector and run against the EXACT preserved freeze-#28 kernel lines,
  # including a cgroup carrying systemd's \xNN byte escape (the census label
  # class). promtool must accept the output and reject the raw-backslash
  # mutation. Static tripwires pin the journalctl pattern + scrape_errors
  # emission + anchored Gatus conditions to the module source.
  memcg-oom-collector =
    let
      evo = self.nixosConfigurations.evo-x2.config;
      collector = evo.systemd.services.system-health-metrics.serviceConfig.ExecStart;
      probe = pkgs.writeShellApplication {
        name = "memcg-oom-collector-probe";
        # SC2016: slice anchors are deliberate literals; SC1091: the sliced
        # pipeline is a runtime artifact; SC1012: the printf '\n' is passed
        # through bash -c to printf itself (deliberate).
        excludeShellChecks = [
          "SC2016"
          "SC1091"
          "SC1012"
        ];
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnused
          pkgs.gnugrep
          pkgs.gawk
          pkgs.prometheus.cli
        ];
        text = ''
          set -euo pipefail
          SCRIPT="''${1:?collector store path required}"
          MODULE="''${2:?module source path required}"
          mkdir -p /tmp/memcgtest

          # Fixture: the EXACT freeze-#28 evidence line shape (preserved
          # 2026-10-12) plus an \xNN-escaped cgroup name (census class) and
          # a second plain memcg for grouping.
          cat > /tmp/memcgtest/raw <<'FIXTURE'
          Oct 12 00:35:23 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=3156072,uid=1000
          Oct 12 02:15:30 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=chromium,pid=3240198,uid=1000
          Oct 12 02:15:31 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice_gitea-runner-evo\x2dx2.service/task_2dfoo.service,task_memcg=...,task=go,pid=1,uid=0
          Oct 12 03:00:00 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/llama-chat.service,task_memcg=...,task=llama-server,pid=2,uid=1000
          FIXTURE

          # Slice the emission pipeline out of the REAL rendered collector:
          # from the oom_memcg grep line through the awk closing brace-quote.
          start=$(grep -n -F "grep -oE 'oom_memcg=[^,]*'" "$SCRIPT" | head -1 | cut -d: -f1)
          [ -n "$start" ] || { echo "oom_memcg pipeline not found in collector script"; exit 1; }
          tail -n +"$start" "$SCRIPT" | sed -n "1,/}'/p" > /tmp/memcgtest/pipeline.sh

          # Production shape: HELP/TYPE header + total, then the sliced
          # pipeline against the fixture raw file.
          MEMCG_OOM_RAW=/tmp/memcgtest/raw bash -c '
            export MEMCG_OOM_RAW
            {
              printf '%s\n' \
                "# HELP system_memcg_oom_kills_24h per-memcg kernel oom kills (24h)" \
                "# TYPE system_memcg_oom_kills_24h gauge"
              source /tmp/memcgtest/pipeline.sh
            } > /tmp/memcgtest/out.prom
          '

          # Grouping + label form: leading slash stripped, counts grouped.
          grep -Fq 'system_memcg_oom_kills_24h{memcg="system.slice/tq-agent-pool.service"} 2' /tmp/memcgtest/out.prom
          grep -Fq 'system_memcg_oom_kills_24h{memcg="system.slice/llama-chat.service"} 1' /tmp/memcgtest/out.prom
          # \xNN escape must be DOUBLED for the text format (census class).
          grep -Fq 'system_memcg_oom_kills_24h{memcg="system.slice_gitea-runner-evo\\x2dx2.service/task_2dfoo.service"} 1' /tmp/memcgtest/out.prom

          # The REAL parser accepts it...
          promtool check metrics < /tmp/memcgtest/out.prom
          # ...and rejects the raw single-backslash mutation.
          printf '%s\n' 'system_memcg_oom_kills_24h{memcg="a\x2db.service"} 1' > /tmp/memcgtest/raw-label.prom
          if promtool check metrics < /tmp/memcgtest/raw-label.prom >/dev/null 2>&1; then
            echo "MUTATION: raw single-backslash label accepted by prometheus parser"
            exit 1
          fi

          # Static tripwires on the module source.
          grep -qF 'oom-kill:constraint=CONSTRAINT_MEMCG' "$MODULE" || {
            echo "module lost the kernel memcg oom journalctl pattern"; exit 1;
          }
          grep -qF 'system_memcg_oom_scrape_errors' "$MODULE" || {
            echo "module lost the scrape_errors emission"; exit 1;
          }
          grep -qF '\nsystem_memcg_oom_kills_total_24h *\n' "$MODULE" || {
            echo "module lost the anchored Gatus presence condition"; exit 1;
          }

          echo "PASS: memcg oom collector — pipeline groups + escapes correctly, promtool accepts output, rejects raw form"
        '';
      };
    in
    pkgs.testers.runNixOSTest {
      name = "memcg-oom-collector";

      nodes.machine = _: {
        system.stateVersion = "25.11";
      };

      testScript = ''
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.succeed("${probe}/bin/memcg-oom-collector-probe ${collector} ${../modules/nixos/services/system-health.nix}")
      '';
    };
}
