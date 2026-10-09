# Behavioral fixtures for storage scripts: borg-restore-drill, root-prune
# guard, btrfs scrub staleness. Split out of flake.nix 2026-10-08.
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    {
      checks = {
        # Behavioral fixture for scripts/borg-restore-drill.sh
        # (2026-09-24 storage TODO; docs/status report §f.6). The
        # drill is a PLAIN bash script (no writeShellApplication
        # wrapper), so direct PATH stubs work — but it resolves borg
        # via `nix build --print-out-paths --impure --expr`, so the
        # `nix` binary must be stubbed TOO (it prints the stub tree
        # carrying bin/borg). Covers: root-gate die, bogus `--local`
        # die, repo-without-config die, PLACEHOLDER-repo tripwire
        # (fixture BORG_ENV_FILE + id-stub root) + its secrets-missing
        # sibling, happy-path PASS (--local with stubbed borg), and
        # the --verify-data deep-integrity branch (1.x --help probe →
        # --dry-run fallback). Plus a MUTATION NEGATIVE (2026-09-25):
        # a drill COPY with the root gate neutered must FAIL the
        # root-gate case's assertion — proves the fixture exercises
        # the real script content rather than passing vacuously
        # (behavioral twin of scripts/negative-test-lints.sh;
        # anchor-drift-guarded so a no-op sed fails loudly). NOT
        # reachable in the sandbox: the
        # real-mode /mnt/hot mountpoint gate sits BEHIND the
        # `/run/secrets/*` existence checks and `[ -e ]` is a bash
        # builtin that cannot be stubbed — the secrets-missing die is
        # its direct predecessor and is asserted instead.
        #
        # Env-path-pin negative case (folded 2026-09-25 per
        # TODO_LIST/storage.md): the eval-time assertion in
        # platforms/nixos/system/backup.nix pins the drill's
        # BORG_ENV_FILE default to the rendered borg-env sops template;
        # the 2026-09-23 drift probe was hand-run once and ephemeral, so
        # the folded asserts below are its standing regression
        # (test-sops-key-audit shape — pass/fail chosen at eval, fires on
        # every flake check incl. --no-build): control (real module
        # passes), script drift (a sed-drifted COPY of the drill fed to a
        # single-anchor copy of backup.nix — the module's lib import
        # stays lazy while dormant, so the toFile'd copy only needs the
        # script line rewritten), and template-path override (a forced
        # sops.templates."borg-env".path must fire the pin too). Both
        # drift directions run in a MINIMAL nixosSystem co-importing the
        # integration module: backup.nix defines services.integration
        # unconditionally and the empty definition at the undeclared path
        # errors otherwise; evo-x2's full assertions list is NOT forced
        # here — on the enabled shape it realizes the monitor365
        # prepared-source context, which cannot build (private crate).
        borg-restore-drill-fixture =
          let
            pinMessage = "borg-restore-drill env-path pin";
            failingPin =
              assertions: builtins.filter (a: !a.assertion && lib.hasInfix pinMessage a.message) assertions;
            # The fixture's NixOS eval is platform-INDEPENDENT (backup.nix
            # + integration + sops modules carry no host arch), but it
            # must NOT inherit the CHECKING system: on aarch64-darwin
            # `nixosSystem { system = "aarch64-darwin"; }` dies — which
            # plain `nix flake check` on a Linux runner never sees (it
            # silently omits incompatible systems). Pin to linux so the
            # negative cases stay LIVE on every platform (eval-only,
            # same shape as the evo-x2 cross-system evals in
            # disko-samsung-tlc / offsite-borg-positive-render).
            pinAssertionsOf =
              modules:
              (inputs.nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
                inherit modules;
              }).config.assertions;

            # The drifted module injects the drift through the
            # drillScript option (inline string) — NOT through
            # builtins.toFile + import: a toFile source path is
            # un-rooted, so a GC sweep (or the flake eval cache
            # serving the stale path) breaks every eval-only gate
            # with "path '…-backup-drifted.nix' is not valid".
            driftedModule = {
              services.offsite-borg.drillScript =
                lib.replaceStrings [ "/run/secrets/rendered/borg-env" ] [ "/run/secrets/rendered/borg-env-DRIFT" ]
                  (builtins.readFile (root + "/scripts/borg-restore-drill.sh"));
            };

            # enable=true + declared template so the guard consults the
            # template's .path (while dormant it pins the sops-nix
            # default shape, making a path override inert).
            templateOverrideModules = [
              inputs.self.nixosModules.integration
              inputs.sops-nix.nixosModules.sops
              ./platforms/nixos/system/backup.nix
              {
                services.offsite-borg.enable = true;
                sops.templates."borg-env".content = "BORG_REPO=x";
                sops.templates."borg-env".path = lib.mkOverride 50 "/run/secrets/rendered/borg-env-DRIFT";
              }
            ];

            controlFailing = failingPin (pinAssertionsOf [
              inputs.self.nixosModules.integration
              ./platforms/nixos/system/backup.nix
            ]);
            scriptDriftFailing = failingPin (pinAssertionsOf [
              inputs.self.nixosModules.integration
              ./platforms/nixos/system/backup.nix
              driftedModule
            ]);
            templateDriftFailing = failingPin (pinAssertionsOf templateOverrideModules);

            pinGuards =
              assert controlFailing == [ ];
              assert scriptDriftFailing != [ ];
              assert lib.hasInfix ''BORG_ENV_FILE="''${BORG_ENV_FILE:-/run/secrets/rendered/borg-env}"''
                (builtins.head scriptDriftFailing).message;
              assert templateDriftFailing != [ ];
              assert lib.hasInfix "borg-env-DRIFT" (builtins.head templateDriftFailing).message;
              true;
          in
          builtins.deepSeq pinGuards (
            pkgs.runCommand "borg-restore-drill-fixture"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  gnugrep
                  gnused
                ];
              }
              ''
                set -euo pipefail
                FIX=$(mktemp -d)
                BIN="$FIX/bin"; mkdir -p "$BIN"
                ROOT="$FIX/root"; ROOTBIN="$ROOT/bin"; mkdir -p "$ROOTBIN"
                export XDG_STATE_HOME="$FIX/state"; mkdir -p "$XDG_STATE_HOME"
                export STUB_NIX_OUT="$ROOT"

                # ---- nix stub: the drill resolves borg through
                # `nix build --no-link --print-out-paths --impure`; the
                # stub prints the stub tree (bin/borg lives there).
                cat > "$BIN/nix" <<'STUBEOF'
                #!${pkgs.bash}/bin/bash
                echo "''${STUB_NIX_OUT:?STUB_NIX_OUT unset}"
                STUBEOF

                # ---- id stub: real mode's `[ "$(id -u)" -eq 0 ]` gate.
                # STUB_ROOT=1 fakes root for the env-file die cases;
                # unset → uid 1000 → the root-gate die (same observable
                # outcome as the sandbox's real non-root builder).
                cat > "$BIN/id" <<'STUBEOF'
                #!${pkgs.bash}/bin/bash
                if [ "''${1:-}" = "-u" ]; then
                  if [ -n "''${STUB_ROOT:-}" ]; then echo 0; else echo 1000; fi
                  exit 0
                fi
                echo "uid=1000(fixture)"; exit 0
                STUBEOF

                # ---- borg stub: version/list/extract covering the
                # drill's exact call shapes. extract writes the subset
                # files into its CWD (the drill's scratch dir). Unknown
                # FLAGS are dropped (dash-prefixed → shift), never
                # collected as paths — the drill's `borg extract --help`
                # borg2-capability probe once became a junk `--help` file
                # in the invoking cwd, got daemon-committed twice, and
                # broke the push-protection hook repo-wide (2026-09-25).
                cat > "$ROOTBIN/borg" <<'STUBEOF'
                #!${pkgs.bash}/bin/bash
                cmd="''${1:-}"
                case "$cmd" in
                  --version) echo "borg 1.4.5-fixture-stub"; exit 0 ;;
                  list)
                    if [ "''${2:-}" = "--last" ]; then
                      echo "fixture-archive-$(date -u +%Y%m%d%H%M%S)  $(date -u +%Y-%m-%dT%H:%M:%S)  0000000000000000000000000000000000000000000000000000000000000000"
                    else
                      echo "fixture-archive-pinned  $(date -u +%Y-%m-%dT%H:%M:%S)  0000000000000000000000000000000000000000000000000000000000000000"
                    fi
                    exit 0 ;;
                  extract)
                    shift
                    dry=0; paths=()
                    while [ $# -gt 0 ]; do
                      case "$1" in
                        --list) shift ;;
                        --dry-run|--verify-data) [ "$1" = "--dry-run" ] && dry=1; shift ;;
                        ::*) shift ;;
                        # Drop unknown flags (borg2-capability probe);
                        # only non-dash tokens collect as subset paths.
                        -*) shift ;;
                        *) paths+=("''$1"); shift ;;
                      esac
                    done
                    [ "$dry" = 1 ] && exit 0
                    for p in "''${paths[@]}"; do
                      mkdir -p "$(dirname "$p")"
                      printf 'borg-restore-drill-fixture: %s\n' "$p" > "$p"
                    done
                    exit 0 ;;
                  *) echo "borg stub: unhandled subcommand: $cmd" >&2; exit 2 ;;
                esac
                STUBEOF
                chmod +x "$BIN/nix" "$BIN/id" "$ROOTBIN/borg"
                export PATH="$ROOT/bin:$BIN:$PATH"

                DRILL="$FIX/borg-restore-drill.sh"
                cp ${root}/scripts/borg-restore-drill.sh "$DRILL"
                chmod +x "$DRILL"

                rc=0; capt=""
                run() { capt=$(bash "$DRILL" "''$@" 2>&1) && rc=0 || rc=$?; }
                need_rc() { [ "$rc" = "$2" ] || { echo "FAIL $1: rc=$rc want $2"; printf '%s\n' "$capt"; exit 1; }; }
                need_has() { printf '%s\n' "$capt" | grep -qF -- "$2" || { echo "FAIL $1: missing text: $2"; printf '%s\n' "$capt"; exit 1; }; }

                # 1) real mode as non-root → root-gate die (record still
                #    written: the header promises one from early deaths).
                run; need_rc root-gate 1; need_has root-gate "real-repo mode needs root"
                R=$(ls -1t "$XDG_STATE_HOME"/borg-restore-drill/drill-*.log | head -1)
                grep -qF "result           : FAIL" "$R" || { echo "FAIL root-gate: no FAIL record"; cat "$R"; exit 1; }

                # 2) bogus --local → die before any repo access
                run --local "$FIX/does-not-exist"; need_rc bogus-local 1; need_has bogus-local "--local repo dir not found"

                # 3) --local repo without a borg 'config' file
                mkdir -p "$FIX/empty-repo"
                run --local "$FIX/empty-repo"; need_rc no-config 1; need_has no-config "no borg 'config' file"

                # 4) real mode, faked root, fixture env file with the
                #    go-live PLACEHOLDER → tripwire die
                ENVF="$FIX/borg-env"; printf 'BORG_REPO=ssh://PLACEHOLDER@example:23/./repo\n' > "$ENVF"
                export BORG_ENV_FILE="$ENVF" STUB_ROOT=1
                run; need_rc placeholder 1; need_has placeholder "go-live placeholder"

                # 5) real mode, non-placeholder repo → the
                #    /run/secrets/* existence checks fail (mountpoint
                #    gate's direct predecessor; see header note)
                printf 'BORG_REPO=ssh://user@host.example:23/./repo\n' > "$ENVF"
                run; need_rc secrets-missing 1; need_has secrets-missing "/run/secrets/borg_password missing"
                unset BORG_ENV_FILE STUB_ROOT

                # 6) happy path: --local against a stub repo → PASS,
                #    subset extracted + byte-verified, record says PASS
                REPO="$FIX/repo"; mkdir -p "$REPO"; : > "$REPO/config"
                run --local "$REPO"; need_rc happy-local 0; need_has happy-local "result           : PASS"
                need_has happy-local "etc/hostname"
                R=$(ls -1t "$XDG_STATE_HOME"/borg-restore-drill/drill-*.log | head -1)
                grep -qF "result           : PASS" "$R" || { echo "FAIL happy-local: record not PASS"; cat "$R"; exit 1; }

                # 7) --verify-data deep-integrity branch (stub --help has
                #    no borg2 flag → 1.x --dry-run fallback) + --archive pin
                run --local "$REPO" --verify-data --archive fixture-archive-pinned
                need_rc deep 0; need_has deep "deep-integrity: OK"
                need_has deep "result           : PASS"
                # The stub must have DROPPED the --help probe flag: a
                # dash-prefixed junk file in this script's invoking cwd
                # is exactly the daemon-committed pollution the drop
                # exists to prevent (push-protection breakage class).
                junk="$(ls -A -- . 2>/dev/null | grep -E '^-' || true)"
                [ -z "$junk" ] || { echo "FAIL deep: borg stub wrote flag-shaped junk into the invoking cwd: $junk"; exit 1; }

                # 8) mutation NEGATIVE (2026-09-25 storage TODO): a drill
                #    COPY with the root gate neutered (test → `true`) must
                #    FAIL case 1's assertion — proves this fixture
                #    exercises the real script content instead of passing
                #    vacuously (behavioral twin of negative-test-lints).
                #    Anchor-drift-guarded: a sed that no longer matches
                #    makes the "mutation" a silent no-op phantom, so the
                #    case fails loudly instead.
                MUT="$FIX/borg-restore-drill-mutated.sh"
                sed 's/^\([[:space:]]*\)\[ "\$(id -u)" -eq 0 \]/\1true/' "$DRILL" > "$MUT"
                grep -qF 'true ||' "$MUT" || { echo "FAIL mutation-negative: sed anchor no longer matches the root-gate line — mutation is a no-op"; exit 1; }
                if grep -qF '[ "$(id -u)" -eq 0 ]' "$MUT"; then
                  echo "FAIL mutation-negative: root-gate test still present in mutated copy"
                  exit 1
                fi
                DRILL="$MUT"
                run
                DRILL="$FIX/borg-restore-drill.sh"
                # uid-1000 stub + BORG_ENV_FILE unset → the neutered gate
                # lets the run proceed one gate FURTHER: rc 1 (a die
                # fired) with the env-file message PRESENT and the
                # root-gate message ABSENT — the full inversion of
                # case 1.
                need_rc mutation-negative 1
                if printf '%s\n' "$capt" | grep -qF "real-repo mode needs root"; then
                  echo "FAIL mutation-negative: root-gate die still fired on the mutated copy — fixture insensitive to script content"
                  printf '%s\n' "$capt"
                  exit 1
                fi
                need_has mutation-negative "rendered borg env not readable"

                echo "PASS: borg-restore-drill fixture (root-gate, bogus-local, no-config, placeholder, secrets-missing, happy-local, verify-data, no-junk-cwd, env-pin-drift, mutation-negative)" > "$out"
              ''
          );

        # root-prune-guard.sh decides a live prune from a df parse (the
        # 10-02 06:33 dnsblockd SIGBUS/ENOSPC outage class fix). A
        # threshold or parse regression either NEVER prunes (the empty
        # ladder rung again: 93% alert -> nothing -> 100% -> outage) or
        # prunes below the band (needless churn). PATH stubs for
        # df/btrbk + real coreutils/gawk; runs the REAL committed
        # script (pre-deploy-metrics-selftest staging shape). Covers:
        # below-threshold no-fire, the strict >90 boundary (90 = off,
        # 91 = fire), the exact btrbk invocation, failing-prune
        # recording (exit recorded, unit still 0, prom still written).
        root-prune-guard-fixture =
          pkgs.runCommand "root-prune-guard-fixture"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils-full
                gawk
                gnugrep
              ];
            }
            ''
              scratch=$(mktemp -d)
              stubs="$scratch/stubs"
              mkdir -p "$stubs"

              cat > "$stubs/df" <<'EOF'
              #!/usr/bin/env bash
              echo "Filesystem 1024-blocks Used Available Capacity Mounted"
              echo "overlay 1000 $DF_USED $DF_AVAIL 0% /"
              EOF
              cat > "$stubs/btrbk" <<'EOF'
              #!/usr/bin/env bash
              echo "$*" >> "$BTRBK_LOG"
              exit "$BTRBK_RC"
              EOF
              chmod +x "$stubs/df" "$stubs/btrbk"
              patchShebangs "$stubs/df" "$stubs/btrbk"

              run_case() {
                case_name="$1"
                expect_fired="$2"
                expect_rc="$3"
                rm -f "$scratch/out.prom" "$scratch/btrbk.log"
                guard_rc=0
                DF_USED="$df_used" DF_AVAIL="$df_avail" BTRBK_RC="$btrbk_rc" \
                  BTRBK_LOG="$scratch/btrbk.log" \
                  ROOT_PRUNE_GUARD_OUT="$scratch/out.prom" \
                  PATH="$stubs:$PATH" \
                  bash ${root}/scripts/root-prune-guard.sh || guard_rc=$?
                [ "$guard_rc" -eq 0 ] \
                  || { echo "FAIL ($case_name): guard exited $guard_rc (contract: always 0)"; exit 1; }
                grep -Fx "root_prune_guard_fired $expect_fired" "$scratch/out.prom" \
                  || { echo "FAIL ($case_name): fired != $expect_fired"; cat "$scratch/out.prom"; exit 1; }
                grep -Fx "root_prune_guard_prune_exit $expect_rc" "$scratch/out.prom" \
                  || { echo "FAIL ($case_name): prune_exit != $expect_rc"; cat "$scratch/out.prom"; exit 1; }
                grep -Fx "root_prune_guard_usage_pct $pct" "$scratch/out.prom" \
                  || { echo "FAIL ($case_name): usage_pct != $pct"; cat "$scratch/out.prom"; exit 1; }
              }

              # Below threshold: no prune, metrics still written.
              df_used=50; df_avail=50; btrbk_rc=0; pct=50
              run_case "below-threshold" 0 0
              [ -s "$scratch/btrbk.log" ] && { echo "FAIL: btrbk invoked below threshold"; exit 1; }

              # Boundary: 90% is NOT > 90 — strict comparison.
              df_used=90; df_avail=10; btrbk_rc=0; pct=90
              run_case "at-90-no-fire" 0 0
              [ -s "$scratch/btrbk.log" ] && { echo "FAIL: btrbk invoked at exactly 90"; exit 1; }

              # 91%: fires, exact invocation contract.
              df_used=91; df_avail=9; btrbk_rc=0; pct=91
              run_case "over-90-fires" 1 0
              grep -Fx -- "-c /etc/btrbk/root.conf prune" "$scratch/btrbk.log" \
                || { echo "FAIL: wrong btrbk invocation"; cat "$scratch/btrbk.log"; exit 1; }

              # Failing prune: exit recorded, script still 0, prom fresh.
              df_used=95; df_avail=5; btrbk_rc=7; pct=95
              run_case "prune-failure-recorded" 1 7

              touch $out
            '';

        # 2026-10-01 plan P2 #5: the scrub-staleness gauges parse
        # `btrfs scrub status` text — a format that CHANGED across
        # btrfs-progs eras (7.1 prints "Scrub started:    %s" AND
        # "Scrub resumed:    %s" for resumed scrubs, both binary-
        # verified to start at column 0). A pattern regression here
        # degrades silently: stale flips to 1 (phantom red) or never
        # flips (dark coverage). This fixture runs the REAL rendered
        # collector against a stub `btrfs` serving synthetic status
        # output for the five semantic branches + the fail-closed
        # absence branch. Output paths are sed-redirected to a
        # scratch dir (the real textfile dir needs root for the
        # final rename-over); the sed touches ONLY hardcoded paths
        # and the PATH export.
        btrfs-scrub-staleness-fixture =
          let
            sys = inputs.self.nixosConfigurations.evo-x2;
            collector = sys.config.systemd.services.btrfs-health.serviceConfig.ExecStart;
          in
          pkgs.runCommand "btrfs-scrub-staleness-fixture"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils-full
                gnugrep
                gnused
                gawk
              ];
            }
            ''
              set -euo pipefail
              FIX=$(mktemp -d)
              mkdir -p "$FIX/bin" "$FIX/fixtures" "$FIX/out" "$FIX/textfile" "$FIX/state-root"

              cat > "$FIX/bin/btrfs" <<'STUBEOF'
              #!${pkgs.bash}/bin/bash
              set -uo pipefail
              # Self-locating: the check shell's FIX is NOT exported, so
              # resolve the fixture root from this script's own path.
              here=$(cd "$(dirname "$0")" && pwd)
              FIX=$(dirname "$here")
              cmd="''${1:-}"; sub="''${2:-}"; mnt="''${3:-}"
              if [ "$cmd" = "scrub" ] && [ "$sub" = "status" ]; then
                if [ -f "$FIX/fixtures/root.fails" ] && [ "$mnt" = "/" ]; then exit 1; fi
                case "$mnt" in
                  /) cat "$FIX/fixtures/root.txt" ;;
                  /data) cat "$FIX/fixtures/data.txt" ;;
                  *) exit 1 ;;
                esac
                exit 0
              fi
              exit 0
              STUBEOF
              chmod +x "$FIX/bin/btrfs"

              sed \
                -e "s#^export PATH=\"#export PATH=\"$FIX/bin:#" \
                -e "s#/var/lib/prometheus-node-exporter/textfile_collectors#$FIX/textfile#g" \
                -e "s#/var/lib/btrfs-health#$FIX/state-root#g" \
                -e "s#/var/lib/memory-emergency-guard/churn-stopped#$FIX/churn-stopped#g" \
                ${collector} > "$FIX/out/run.sh"
              chmod +x "$FIX/out/run.sh"
              bash -n "$FIX/out/run.sh"

              ctime() { date -d "$1" '+%a %b %e %H:%M:%S %Y'; }
              write_fixture() { # <file> <kind>
                local f="$FIX/fixtures/$1" kind="$2" verb="started"
                [ "$kind" = "resumed-fresh" ] && verb="resumed"
                local d="2 days ago"
                case "$kind" in
                  finished-old) d="11 days ago" ;;
                  running) d="10 minutes ago" ;;
                esac
                case "$kind" in
                  unparseable)
                    printf 'UUID:             f\nScrub device:     /dev/fixture (devid 1)\nScrub started:    GARBAGE NOT A DATE\nStatus:           finished\nDuration:         0:02:15\n' > "$f" ;;
                  never)
                    printf 'UUID:             f\nScrub device:     /dev/fixture (devid 1)\nScrub started:    Never started\n' > "$f" ;;
                  running)
                    printf 'UUID:             f\nScrub device:     /dev/fixture (devid 1)\nScrub started:    %s\nStatus:           running\nDuration:         0:01:23 (still running)\n' "$(ctime "$d")" > "$f" ;;
                  *)
                    printf 'UUID:             f\nScrub device:     /dev/fixture (devid 1)\nScrub %s:    %s\nStatus:           finished\nDuration:         0:02:15\nTotals:           scrubbed 3.00 GiB with 0 errors\n' "$verb" "$(ctime "$d")" > "$f" ;;
                esac
              }

              FAILS=0
              expect() { # <desc> <egrep-pattern> [invert]
                local desc="$1" pat="$2" inv="''${3:-}"
                if [ "$inv" = "invert" ]; then
                  if grep -qE "$pat" "$FIX/textfile/btrfs.prom" 2>/dev/null; then
                    echo "FAIL (unexpected match): $desc"; FAILS=$((FAILS+1))
                  else
                    echo "PASS: $desc"
                  fi
                elif grep -qE "$pat" "$FIX/textfile/btrfs.prom" 2>/dev/null; then
                  echo "PASS: $desc"
                else
                  echo "FAIL (missing match): $desc"; FAILS=$((FAILS+1))
                fi
              }
              run_collector() {
                "$FIX/out/run.sh" >"$FIX/out/run.log" 2>"$FIX/out/run.err" || true
                grep -E 'btrfs_scrub_(stale|last_completed|staleness_parse_errors)' "$FIX/textfile/btrfs.prom" || true
              }

              echo "=== Run A: root=finished-old(11d) data=finished-fresh(2d) ==="
              write_fixture root.txt finished-old
              write_fixture data.txt finished-fresh
              run_collector
              expect "root stale=1" 'btrfs_scrub_stale\{mount="root"\} 1'
              expect "root last_completed nonzero" 'btrfs_scrub_last_completed_seconds\{mount="root"\} [1-9]'
              expect "data stale=0" 'btrfs_scrub_stale\{mount="data"\} 0'
              expect "data last_completed nonzero" 'btrfs_scrub_last_completed_seconds\{mount="data"\} [1-9]'
              expect "parse_errors=0" 'btrfs_scrub_staleness_parse_errors 0$'

              echo "=== Run B: root=resumed-fresh data=running ==="
              write_fixture root.txt resumed-fresh
              write_fixture data.txt running
              run_collector
              expect "resumed root stale=0 (btrfs-progs prints Scrub resumed:)" 'btrfs_scrub_stale\{mount="root"\} 0'
              expect "resumed root last_completed nonzero" 'btrfs_scrub_last_completed_seconds\{mount="root"\} [1-9]'
              expect "running data stale=0" 'btrfs_scrub_stale\{mount="data"\} 0'
              expect "running data last_completed=0" 'btrfs_scrub_last_completed_seconds\{mount="data"\} 0'
              expect "parse_errors=0" 'btrfs_scrub_staleness_parse_errors 0$'

              echo "=== Run C: root=unparseable-finished data=never-started ==="
              write_fixture root.txt unparseable
              write_fixture data.txt never
              run_collector
              # $-anchored: the HELP comment line contains
              # "parse_errors 1 =" and phantom-matches unanchored.
              expect "parse_errors=1 (fails loud, not silent 0)" 'btrfs_scrub_staleness_parse_errors 1$'
              expect "unparseable root stale=0 (parse_errors owns the failure)" 'btrfs_scrub_stale\{mount="root"\} 0'
              expect "unparseable root last_completed=0" 'btrfs_scrub_last_completed_seconds\{mount="root"\} 0'
              expect "never-started data stale=1" 'btrfs_scrub_stale\{mount="data"\} 1'
              expect "never-started data last_completed=0" 'btrfs_scrub_last_completed_seconds\{mount="data"\} 0'

              echo "=== Run D: root scrub-status FAILS data=finished-fresh ==="
              touch "$FIX/fixtures/root.fails"
              write_fixture root.txt finished-fresh
              write_fixture data.txt finished-fresh
              run_collector
              expect "data stale=0 still emitted" 'btrfs_scrub_stale\{mount="data"\} 0'
              expect "root stale line ABSENT (fail-closed; gatus presence condition owns it)" 'btrfs_scrub_stale\{mount="root"\}' invert
              expect "root last_completed ABSENT" 'btrfs_scrub_last_completed_seconds\{mount="root"\}' invert
              rm -f "$FIX/fixtures/root.fails"

              if [ "$FAILS" -gt 0 ]; then
                echo "FAIL: $FAILS assertion(s) failed; last btrfs.prom:"
                cat "$FIX/textfile/btrfs.prom" || true
                echo "--- collector stderr (last run):"
                cat "$FIX/out/run.err" || true
                echo "--- all scrub lines in prom:"
                grep -n "scrub" "$FIX/textfile/btrfs.prom" || true
                echo "--- rendered staleness block:"
                grep -n "scrub_label\|scrub_started_raw\|scrub_stale_v" "$FIX/out/run.sh" | head -20
                echo "--- stub ground truth:"
                head -3 "$FIX/fixtures/root.txt" || true
                "$FIX/bin/btrfs" scrub status / > "$FIX/stub.out" 2>"$FIX/stub.err"; echo "stub rc=$?"
                head -3 "$FIX/stub.out"; cat "$FIX/stub.err"
                echo "--- run.sh PATH line:"
                grep -n "^export PATH" "$FIX/out/run.sh" | cut -c1-120
                exit 1
              fi
              echo "OK: all scrub-staleness fixture assertions passed"
              touch $out
            '';

      };
    };
}
