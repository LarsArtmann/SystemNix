# Static-analysis checks: Nix linters (statix, deadnix), module-shape and
# dead-guard lints, gatus config lints, SigNoz query lint, binary-coverage
# lint + selftest (shared binaryCoverageScanner), gitleaks/lock-audit
# selftests, chown-vs-bind audit. Split out of flake.nix 2026-10-08.
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
      checks =
        let
          # Unit scripts must EXEC every binary they use from the unit's
          # own PATH (runtimeInputs / path / an absolute store ref). A
          # binary provided only by the ambient profile is exit-127 under
          # harden{}'s restricted PATH — or a PHANTOM GREEN when the miss
          # lands inside an `if` condition. Both classes hit LIVE:
          #   awk without gawk:
          #     - btrfs-verify-pool-backups (2026-08-18): awk missing from
          #       the unit path made the device-stats branch silently skip
          #     - btrfs-balance-{metadata,data} (2026-08-31): awk missing
          #       from runtimeInputs — exit 127 on every run for a week
          #       while root chunk-unalloc sat CRITICAL (the ENOSPC
          #       prevention layer fully dead)
          #   `#!/usr/bin/env python3` without pkgs.python3:
          #     - systemd-timer-monitor: exit 127, env: 'python3': No such
          #       file or directory (documented gotcha)
          # v0 is FILE-scoped: the provider must appear anywhere in the
          # same file (runtimeInputs, path, or ${pkgs.X}/bin ref). Extend
          # ONLY with rows backed by a real incident — a false positive
          # here blocks every deploy through pre-commit + CI.
          binaryCoverageScanner = pkgs.writeShellScript "binary-coverage-scan" ''
            # usage: binary-coverage-scan <tree>... — exit 1 on provider gaps
            fail=0
            noncomments() { grep -vE '^[[:space:]]*#($|[^!])' "$1" | grep -vE '^[[:space:]]*(description|name)\s*=' || true; }
            for tree in "$@"; do
              for f in $(find "$tree" -type f -name '*.nix' | sort); do
                # awk → gawk|busybox (provider grep runs on the RAW file, so a `# awk` note alone never satisfies it... actually it DOES — v0 accepts any mention; comments-stripped only gates the USAGE side)
                if noncomments "$f" | grep -qw awk && ! grep -qwE 'gawk|busybox' "$f"; then
                  echo "FAIL: $f execs 'awk' but never mentions gawk/busybox in runtimeInputs/path."
                  echo "  Incidents: btrfs-verify-pool-backups phantom green (2026-08-18);"
                  echo "  btrfs-balance-* exit 127 for a week (2026-08-31). Add pkgs.gawk."
                  fail=1
                fi
                # python3 → pkgs.python3 (SHEBANGS COUNT: the timer-monitor incident WAS a shebang)
                if { noncomments "$f" | grep -qw python3 || grep -qE '^#!.*python3' "$f"; } \
                   && ! grep -qE 'pkgs\.python3|python3Full|python3\.interpreter|python3Packages\.python|writePython3|/bin/python' "$f"; then
                  echo "FAIL: $f uses python3 but never provides it (pkgs.python3 in runtimeInputs/path)."
                  echo "  Incident: systemd-timer-monitor exit 127 — env: 'python3': No such file."
                  fail=1
                fi
              done
            done
            exit "$fail"
          '';
        in
        {
          statix =
            pkgs.runCommand "statix-check"
              {
                nativeBuildInputs = [ pkgs.statix ];
              }
              ''
                cd ${root}
                statix check -o errfmt . 2>&1 | grep -v ':E:0:' | tee $out || true
                if statix check -o errfmt . 2>&1 | grep -v ':E:0:' | grep -q '.'; then
                  exit 1
                fi
                exit 0
              '';

          deadnix =
            pkgs.runCommand "deadnix-check"
              {
                nativeBuildInputs = [ pkgs.deadnix ];
              }
              ''
                cd ${root}
                deadnix --fail --no-lambda-pattern-names . 2>&1 | tee $out
              '';

          # Gatus pat() uses GLOB, not regex. Chars ? and + have
          # different meanings in glob (? = single-char wildcard) vs
          # regex (? = optional quantifier), causing silent false
          # negatives in health checks. { is allowed — Prometheus
          # labels use {label="value"} syntax.
          # Scope: ALL auto-discovered module files, not just
          # gatus-config.nix — since the services.integration registry
          # (2026-09-14), gatus endpoint conditions are authored in the
          # OWNING service modules (entry checks / extraEndpoints), and
          # pat() anywhere crosses the same Nix→YAML→Go glob layers.
          # The method lint stays gatus-config-scoped: mkHttpCheck and
          # the registry checks submodule expose no method field, so
          # method = "..." outside gatus-config.nix is not a gatus value.
          gatus-pattern-lint =
            let
              gatusFiles = lib.filter (lib.hasSuffix ".nix") (
                lib.filesystem.listFilesRecursive (root + "/modules/nixos")
              );
            in
            pkgs.runCommand "gatus-pattern-lint" { } ''
              files="${lib.concatStringsSep " " gatusFiles}"
              for f in $files; do
                if grep -v '^[[:space:]]*#' "$f" | grep -nE 'pat\(.*[?+]'; then
                  echo "FAIL: Gatus pat() patterns contain regex-only chars (? or +) in $f."
                  echo "Gatus pat() uses GLOB, not regex."
                  echo "  ? = single-char wildcard (NOT optional quantifier)"
                  echo "  + = literal character (NOT one-or-more quantifier)"
                  exit 1
                fi
                # pat() globs the WHOLE /metrics body, HELP comments included: an
                # asserted-1 condition pat(*<metric> 1*) silently matches the metric's
                # own "# HELP <metric> 1 if ..." comment and stays green at ANY value
                # (phantom green, live on buildcache/pool/lan-nic/signoz 2026-08-22).
                # Asserted-0 conditions are unaffected ("0 otherwise" never contains
                # "<metric> 0" as a substring). Use the anchored form instead.
                if grep -v '^[[:space:]]*#' "$f" | grep -nE 'pat\(\*[a-z_0-9]+ 1\*\)'; then
                  echo "FAIL: bare pat(*<metric> 1*) conditions match the metric's own HELP comment (in $f)."
                  echo "Use:  [BODY] != pat(*<metric> 0\\n*)  +  [BODY] == pat(*\\n<metric> *)"
                  echo "NOTE: the \\n must reach gatus as a REAL newline (nix \"\\n\" string) — a literal"
                  echo "backslash-n is filepath.Match's ESCAPE for a literal 'n' and can never match"
                  echo "(2026-08-22 bug: 7 deployed checks permanently red from exactly this)."
                  echo "Incident: 2026-08-22 DAS USB drop (buildcache/pool stayed green through a live outage) — docs/status/2026-08-22_01-46_das-usb-drop-gatus-phantom-green-fix.md"
                  exit 1
                fi
                # Escape-sequence trap: in a double-quoted nix string the source
                # bytes backslash-backslash-n evaluate to a LITERAL backslash + 'n'.
                # gatus 5.36.0 pattern.Match delegates to filepath.Match, which
                # treats '\' as an escape for the next character — so the glob
                # "\\n" matches only the letter 'n' and the condition can NEVER
                # match a real /metrics body (permanently red, zero diagnostics;
                # 7 checks were live-broken by this on 2026-08-22). The anchored
                # form needs the REAL newline: single-backslash \n in the nix
                # source (gatus-config.nix anchored conditions are the reference).
                if grep -v '^[[:space:]]*#' "$f" | grep -nE 'pat\(.*\\\\n'; then
                  echo "FAIL: pat() contains a literal backslash-n (nix source \"\\\\n\") in $f."
                  echo "filepath.Match treats '\\' as an ESCAPE, so this glob matches only the letter 'n'"
                  echo "and the condition can never match a real body. Write the newline as single-"
                  echo "backslash \"\\n\" in the double-quoted nix string — see gatus-config.nix anchored forms."
                  exit 1
                fi
              done
              # HTTP method tokens are case-SENSITIVE end to end (RFC 9110):
              # gatus passes the configured method through verbatim and Go's
              # ServeMux matches method tokens case-sensitively — a lowercase
              # "post" 405s against a POST-registered route while an
              # unauthenticated 401 probe CANNOT catch it (auth middleware
              # runs before routing). Live incident: papdashboard /api/ingest
              # 405'd 1076× before a journal 200 proved the fix (2026-08-18).
              if grep -v '^[[:space:]]*#' ${root}/modules/nixos/services/gatus-config.nix | grep -nE 'method = "[a-z]+"'; then
                echo "FAIL: lowercase HTTP method value in gatus-config.nix."
                echo "Method tokens are matched case-sensitively (RFC 9110 + Go ServeMux);"
                echo "'post' 405s against POST-registered routes and 401 probes cannot detect it."
                echo "Use uppercase: method = \"POST\"."
                exit 1
              fi
              touch $out
            '';

          # The 2026-09-29 gatus config-panic incident: an alert
          # description containing `\"` (mount_point="/") made gatus
          # 5.36.0 panic AT STARTUP ("alert description must not have
          # \" or \") — crash-looping the whole monitoring stack while
          # every restart fired a notify-failure@ critical popup
          # (~5s cycle, unsuppressible by DMS DND). Source-level lints
          # cannot see the RENDERED config (descriptions are composed
          # across registry modules), so this check runs the REAL gatus
          # binary's `validate` against the exact yaml the evo-x2 unit
          # loads. NOTE: `gatus validate` also tries to open its sqlite
          # DB AFTER validation — that panic (exit 2, "unable to open
          # database file") is EXPECTED in the sandbox and deliberately
          # ignored; the pass condition is the "Validated N endpoints"
          # line plus absence of "error parsing config". Do not set
          # GATUS_LOG_LEVEL=WARN here — the endpoint-count line is INFO.
          gatus-config-parse =
            let
              sys = inputs.self.nixosConfigurations.evo-x2;
              configFile = sys.config.services.gatus.configFile;
              gatus = sys.config.services.gatus.package;
            in
            pkgs.runCommand "gatus-config-parse-check" { nativeBuildInputs = [ gatus ]; } ''
              GATUS_OIDC_CLIENT_SECRET=check-dummy GATUS_CONFIG_PATH=${configFile} \
                gatus validate > validate.log 2>&1 || true
              if grep -q 'error parsing config' validate.log; then
                echo "FAIL: gatus rejected the rendered config (alert descriptions must not contain quote or backslash):"
                cat validate.log
                exit 1
              fi
              if ! grep -qE 'Validated [0-9]+ endpoints' validate.log; then
                echo "FAIL: no endpoint-validation line — validate never completed config validation:"
                cat validate.log
                exit 1
              fi
              echo "OK: gatus validated the rendered config:"
              grep -E 'Validated [0-9]+ endpoints' validate.log | head -1
              cp validate.log $out
            '';

          # Auto-discovered modules under modules/nixos/{services,desktop}/
          # are flake-parts wrappers: filename -> flake.nixosModules.<filename>.
          # A bare NixOS module evaluates its let-bindings in the WRONG
          # context and contributes NOTHING to hosts — no options, no
          # assertions, silently (2026-08-31 live: signoz-coverage shipped
          # bare; every nix command failed until a concurrent session
          # wrapped it, commit d7237d6c).
          module-shape-lint = pkgs.runCommand "module-shape-lint" { } ''
            fail=0
            for dir in ${root}/modules/nixos/services ${root}/modules/nixos/desktop; do
              for f in "$dir"/*.nix; do
                [ -e "$f" ] || continue
                base=$(basename "$f")
                case "$base" in _*) continue ;; esac
                name="''${base%.nix}"
                # Anchor on the ` =` of the declaration: a bare \b word
                # boundary accepts RENAMED keys too (negative-test-lints
                # caught it: `flake.nixosModules.caddy-mutant =` satisfied
                # the `caddy\b` grep — hyphen is a boundary).
                if ! grep -q "flake\.nixosModules\.''${name}[[:space:]]*=" "$f"; then
                  echo "FAIL: $base does not declare flake.nixosModules.''${name}"
                  echo "  Auto-discovered modules MUST be flake-parts wrappers; a bare NixOS"
                  echo "  module here evaluates silently and contributes NOTHING to hosts."
                  echo "  Shape: { flake.nixosModules.<filename> = { config, lib, pkgs, ... }: { ... }; }"
                  fail=1
                fi
              done
            done
            [ "$fail" -eq 0 ] || exit 1
            touch $out
          '';

          # Dead-guard lint (2026-09-15): writeShellApplication runs
          # errexit+pipefail, so `VAR=$(cmd)` WITHOUT `|| true` EXITS the
          # script when cmd fails — any `[ -z "$VAR" ]` degraded-path
          # guard below is unreachable (live class: website-deploy-monitor
          # failed the unit on every network transient and disk-growth-check
          # 226'd for days, both because the guard could never run).
          # Detection: assignment via command substitution with no
          # `|| true|:|echo|printf|exit` anywhere in the substitution span,
          # followed within 8 lines by a -z/-n guard on the same variable.
          # Exempt a deliberate shape with `# dead-guard-ok` on the line.
          # Heuristic (line-based over .nix sources, not a shell parser):
          # `local x=$(...)` and `[ "$x" = ... ]` guard forms are out of
          # scope for v1 — the fleet sweep validated the FP rate on the
          # real tree.
          dead-guard-lint =
            let
              lintFiles = builtins.filter (lib.hasSuffix ".nix") (
                lib.filesystem.listFilesRecursive (root + "/modules")
                ++ lib.filesystem.listFilesRecursive (root + "/platforms")
                ++ lib.filesystem.listFilesRecursive (root + "/lib")
              );
            in
            pkgs.runCommand "dead-guard-lint" { } ''
              fail=0
              for f in ${lib.concatStringsSep " " lintFiles}; do
                awk '
                  { lines[NR] = $0 }
                  END {
                    bad = 0
                    for (lnIdx = 1; lnIdx <= NR; lnIdx++) {
                      line = lines[lnIdx]
                      if (line ~ /# dead-guard-ok/) continue
                      if (match(line, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[[:space:]]*\$\(/)) {
                        # `$((` opens ARITHMETIC expansion, not a command
                        # substitution — `n=$((n + 1))` cannot fail the
                        # capture the way `n=$(cmd)` can (llama-rag
                        # leaked-instance counter, 2026-09-19 FP).
                        if (substr(line, RSTART + RLENGTH, 1) == "(") continue
                        varName = line
                        sub(/^[[:space:]]*/, "", varName)
                        sub(/=[[:space:]]*\$\(.*/, "", varName)
                        depth = 0
                        protected = 0
                        endIdx = lnIdx
                        for (endIdx = lnIdx; endIdx <= NR; endIdx++) {
                          cur = lines[endIdx]
                          # Protection = the failure path is HANDLED inline:
                          # `|| true`/`:`/degraded echo, a rescue
                          # reassignment like `|| val=0`, or the
                          # `VAR=$(cmd) && …` idiom (errexit does not fire
                          # on the left operand of &&/|| — signoz TTL
                          # retry loop shape).
                          if (cur ~ /\|\|[[:space:]]+(true|:|echo|printf|exit|return|break|continue)/) protected = 1
                          if (cur ~ /\|\|[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/) protected = 1
                          if (cur ~ /\|\|[[:space:]]*\{/) protected = 1
                          if (cur ~ /\)[[:space:]]*&&/) protected = 1
                          lineLen = length(cur)
                          for (charIdx = 1; charIdx <= lineLen; charIdx++) {
                            chr = substr(cur, charIdx, 1)
                            if (chr == "(") depth++
                            else if (chr == ")") depth--
                          }
                          if (depth <= 0) break
                        }
                        if (protected) continue
                        windowEnd = endIdx + 8
                        if (windowEnd > NR) windowEnd = NR
                        for (guardIdx = endIdx + 1; guardIdx <= windowEnd; guardIdx++) {
                          gl = lines[guardIdx]
                          if (index(gl, "-z \"$" varName "\"") || index(gl, "-n \"$" varName "\"") || index(gl, "-z \"''${" varName "}") || index(gl, "-n \"''${" varName "}")) {
                            print FILENAME ":" lnIdx ": DEAD GUARD: " varName "=$(...) lacks `|| true` — under errexit the failed capture exits before the [ -z \"$" varName "\" ] guard at line " guardIdx " can run. Add `|| true` (deliberate degradation) or `# dead-guard-ok`."
                            bad = 1
                            break
                          }
                        }
                      }
                    }
                    if (bad) exit 1
                  }
                ' "$f" || fail=1
              done
              if [ "$fail" -ne 0 ]; then
                echo "FAIL: dead-guard-lint found unreachable degraded-path guards — fix the captures above"
                exit 1
              fi
              touch $out
            '';

          # Textfile-emission guard: a metric echo line without a VALUE
          # makes the node exporter reject the WHOLE .prom file — one
          # value-less line darked all 38 system_* metrics and blocked
          # every deploy (2026-09-02). Fail-level (baseline zero
          # findings at introduction): a snake_case token as the ONLY
          # quoted argument to echo/printf is the value-less shape;
          # append `# emission-ok` to exempt a deliberate one.
          textfile-emission-lint = pkgs.runCommand "textfile-emission-lint" { } ''
            fail=0
            for dir in ${root}/modules/nixos/services ${root}/modules/nixos/desktop; do
              for f in "$dir"/*.nix; do
                [ -e "$f" ] || continue
                while IFS= read -r line; do
                  echo "$line" | grep -q 'emission-ok' && continue
                  echo "FAIL: $(basename "$f"): value-less metric echo (node exporter rejects the whole .prom):"
                  echo "  $line"
                  fail=1
                done < <(grep -nE 'echo[[:space:]]+"[a-z][a-z0-9]*(_[a-z0-9]+)+"[[:space:]]*(>>|>[^>]|[[:space:]]*$)' "$f" || true)
              done
            done
            [ "$fail" -eq 0 ] || exit 1
            touch $out
          '';

          # SigNoz alert rules (_signoz-alerts.nix) + dashboards query the
          # OTel-collector-backed metrics store, which has DIFFERENT label
          # and naming semantics than a plain Prometheus:
          #   1. The prometheus receiver stores the scrape job as the
          #      resource attribute service.name — NO series ever carries a
          #      `job` label, so any `job=` matcher is a permanent
          #      phantom-green (6 rules were silently dead for months;
          #      fixed 2026-08-27 — see
          #      docs/status/2026-08-27_15-50_signoz-phantom-alert-purge-6-dead-rules-fixed.md).
          #   2. Histogram/summary suffixes are stored DOTTED
          #      (`metric.sum`, not `metric_sum`) — the underscore form has
          #      zero series; query via {__name__="metric.suffix"}.
          #   3. `up{service_name=...}` goes STALE mid-outage (the labeled
          #      series disappears when the scrape target fails), so a bare
          #      selector never fires — wrap in count(...) or vector(0).
          #   4. Known-dead metric names (verified 0 series in the store).
          signoz-query-lint =
            let
              alerts = (root + "/modules/nixos/services/_signoz-alerts.nix");
              dashboards = (root + "/modules/nixos/services/dashboards");
              deadMetrics = [ "node_amdgpu_gpu_temp_celsius" ];
            in
            pkgs.runCommand "signoz-query-lint"
              {
                # extensible blocklist of metrics verified to have 0 series;
                # verify additions via
                #   clickhouse-client --query "SELECT count() FROM signoz_metrics.distributed_time_series_v4 WHERE metric_name='X'"
                metrics = toString deadMetrics;
              }
              ''
                                    fail=0
                                    # An empty blocklist makes trap 4's `for m in $metrics`
                                    # silently skip (empty-var for-list = zero iterations, even
                                    # without nullglob) — an emptied deadMetrics list must fail
                                    # LOUD, not phantom-green.
                                    if [ -z "$metrics" ]; then
                                    echo "FAIL: dead-metrics blocklist is empty — trap 4 would be a phantom green."
                                    exit 1
                                    fi
                                    # NOTE: stdenv setup.sh enables `shopt -s nullglob` — an
                                      # unquoted `$strip` command-string variable would have its
                                      # glob-bearing words (the quoted grep pattern) silently
                                      # DELETED, turning every trap below phantom-green. Command
                                      # indirection MUST use function definitions (quotes parse
                                      # at definition time), never variable expansion.
                                      scan() { # scan <label> <files...>
                                        label="$1"; shift
                                        for f in "$@"; do
                                          case "$f" in
                                            *.nix)
                                              stream() { grep -v '^[[:space:]]*#' "$1"; }
                                              ;;
                                            *)
                                              stream() { cat "$1"; }
                                              ;;
                                          esac

                                          # 1. job= label matchers never match anything
                                          if stream "$f" | grep -nE '\bjob[[:space:]]*=[[:space:]]*["~]' >lint_hits; then
                                            echo "FAIL [$label] $f: job= label matcher — no series carries a job label."
                                            echo "  The OTel prometheus receiver stores the scrape job as resource attr"
                                            echo "  service.name. Use node_systemd_unit_state{name=\"X.service\",state=\"active\"}"
                                            echo "  for liveness, or count(up{service_name=\"X\"}) or vector(0) for scrape health."
                                            sed 's/^/    /' lint_hits
                                            fail=1
                                          fi

                                          # 2. underscore histogram/summary suffixes are stored DOTTED
                                          # (googleapis_com exemption: GCP-native metric names like
                                          # storage_googleapis_com_api_request_count END in _count by
                                          # GCP convention — not Prometheus histogram components).
                                          if stream "$f" | grep -nE '[a-z_0-9]+_(sum|count|bucket)\b' | grep -v 'googleapis_com' >lint_hits; then
                                            echo "FAIL [$label] $f: underscore histogram suffix (metric_sum/_count/_bucket)."
                                            echo "  SigNoz stores suffixes DOTTED: metric.sum, metric.count, metric.bucket."
                                            echo "  The underscore form matches zero series (caddy/dns dashboards 2026-08-27)."
                                            echo "  Query as {__name__=\"metric.suffix\"} instead."
                                            sed 's/^/    /' lint_hits
                                            fail=1
                                          fi

                                          # 3. up{service_name=...} goes STALE mid-outage without a vector(0) fallback
                                          if stream "$f" | grep -nE 'up\{[^}]*service_name' | grep -vE '(or vector\(0\)|absent\()' >lint_hits; then
                                            echo "FAIL [$label] $f: bare up{service_name=...} selector."
                                            echo "  On scrape FAILURE the receiver emits a bare-label up=0 series and the"
                                            echo "  labeled series goes stale — the selector returns nothing exactly when"
                                            echo "  it should fire (dnsblockd :9090 wedge, 2026-08-27)."
                                            echo "  Use: count(up{service_name=\"X\"}) or vector(0)"
                                            sed 's/^/    /' lint_hits
                                            fail=1
                                          fi

                                          # 4. known-dead metric names
                                          for m in $metrics; do
                                            if stream "$f" | grep -nE "\b$m\b" >lint_hits; then
                                              echo "FAIL [$label] $f: dead metric '$m' (verified 0 series in the store)."
                                              sed 's/^/    /' lint_hits
                                              fail=1
                                            fi
                                          done
                                        done
                                        rm -f lint_hits
                                        return 0
                                      }

                                      scan alerts ${alerts}
                                      scan dashboards ${dashboards}/*.json

                                      # 5. dashboard layout overlaps: the SigNoz v2 validator
                                      # rejects the WHOLE dashboard with HTTP 400
                                      # ("spec.layouts[0].spec.items[N] and items[M] overlap")
                                      # and the provisioner HARD-fails the deploy by design
                                      # (2026-09-16: systemnix-overview Zone 6 panel). Panels
                                      # are rectangles x..x+width, y..y+height on a 12-col
                                      # grid; any pairwise intersection is fatal.
                                      # NOTE: the heredoc body below is written at this
                                      # block's minimal nix-indent level so the terminator
                                      # lands at column 0 after nix strips the common indent
                                      # (an indented terminator never matches and the heredoc
                                      # eats the rest of the script, bash "unexpected EOF").
                                      if ! overlap_out=$(${pkgs.python3}/bin/python3 - <<'PYOVERLAP'
                import glob, itertools, json, sys
                bad = 0
                for f in sorted(glob.glob("${dashboards}/*.json")):
                    items = json.load(open(f))["spec"]["layouts"][0]["spec"]["items"]
                    for a, b in itertools.combinations(items, 2):
                        if (a["x"] < b["x"] + b["width"] and b["x"] < a["x"] + a["width"]
                                and a["y"] < b["y"] + b["height"] and b["y"] < a["y"] + a["height"]):
                            print("%s: panels (x=%d,y=%d,w=%d,h=%d) and (x=%d,y=%d,w=%d,h=%d) intersect" %
                                  (f, a["x"], a["y"], a["width"], a["height"], b["x"], b["y"], b["width"], b["height"]))
                            bad = 1
                sys.exit(bad)
                PYOVERLAP
                ); then
                                        echo "FAIL: dashboard layout overlap(s):"
                                        echo "$overlap_out"
                                        echo "SigNoz v2 rejects the whole dashboard (HTTP 400) and the provisioner unit"
                                        echo "fails the deploy. Give every panel a disjoint grid rectangle."
                                        exit 1
                                      fi

                                      [ "$fail" -eq 0 ] || exit 1
                                      touch $out
              '';

          binary-coverage-lint = pkgs.runCommand "binary-coverage-lint" { } ''
            ${binaryCoverageScanner} ${root}/modules ${root}/platforms ${root}/lib
            touch $out
          '';

          # Negative test THROUGH nix (the signoz-query-lint v1 nullglob
          # lesson: never trust an exit-0 check you wrote without proving
          # it fails on the historical bug shape). Fixtures carry the exact
          # incident shapes; the scanner must flag them and stay quiet on
          # the compliant twin.
          binary-coverage-selftest =
            let
              evilAwk = pkgs.writeText "evil-awk.nix" ''
                { config, ... }: {
                  systemd.services.evil-balance.serviceConfig.ExecStart =
                    "/bin/sh -c 'btrfs filesystem usage / | awk \"{print \\$3}\"'";
                }
              '';
              evilPython = pkgs.writeText "evil-python.nix" ''
                { config, ... }: {
                  # NB: single-line text on purpose — nested indented
                  # strings would need triple-quote escaping; a mid-line
                  # python3 mention is exactly what the usage-side grep
                  # sees in real modules.
                  environment.etc."evil-daemon.py".text = "#!/usr/bin/env python3\nimport time\ntime.sleep(3600)\n";
                }
              '';
              goodTwin = pkgs.writeText "good-twin.nix" ''
                { config, pkgs, ... }: {
                  systemd.services.good-balance = {
                    path = with pkgs; [ gawk btrfs-progs ];
                    serviceConfig.ExecStart = "/bin/sh -c 'btrfs filesystem usage / | awk \"{print \\$3}\"'";
                  };
                  systemd.services.good-daemon = {
                    path = [ pkgs.python3 ];
                    serviceConfig.ExecStart = "/bin/sh -c 'cat /etc/x > /dev/null'";
                    environment.etc."good.py".text = "#!/usr/bin/env python3\n";
                  };
                }
              '';
              evilTree =
                pkgs.runCommand "evil-tree" { }
                  "mkdir -p $out && cp ${evilAwk} ${evilPython} ${goodTwin} $out/";
              goodTree = pkgs.runCommand "good-tree" { } "mkdir -p $out && cp ${goodTwin} $out/";
              scan = tree: "${binaryCoverageScanner} ${tree} 2>&1";
            in
            pkgs.runCommand "binary-coverage-selftest" { } ''
              # 1. compliant tree must PASS silently
              if ! res=$( ${scan goodTree} ); then
                echo "SELFTEST FAIL: scanner flagged the compliant fixture:"; echo "$res"; exit 1
              fi
              # 2. evil tree must FAIL and NAME both evil fixtures
              if res=$( ${scan evilTree} ); then
                echo "SELFTEST FAIL: scanner passed the evil fixtures (phantom-green lint)"; exit 1
              fi
              echo "$res" | grep -q 'evil-awk.nix' || { echo "SELFTEST FAIL: awk rule did not fire"; exit 1; }
              echo "$res" | grep -q 'evil-python.nix' || { echo "SELFTEST FAIL: python3 rule did not fire"; exit 1; }
              touch $out
            '';

          gitleaks-coverage-selftest = pkgs.runCommand "gitleaks-coverage-selftest" { } ''
            set -u
            cfg=${root}/.gitleaks.toml
            fixtures=${root}/tests/fixtures/gitleaks
            work=$(mktemp -d)
            trap 'rm -rf "$work"' EXIT
            expect_detect() {
              local fixture="$1" label="$2" d
              d=$(mktemp -d "$work/d.XXXXXX")
              cp "$fixtures/$fixture" "$d/"
              # Expand the @HEX40@ template (no-op where absent): entropy
              # must stay realistic or the rule's entropy gate kills the
              # detection this check exists to prove.
              sed -i "s/@HEX40@/$(printf 'systemnix-gitleaks-coverage-fixture' | sha256sum | cut -c1-40)/" "$d/$fixture"
              if ${pkgs.gitleaks}/bin/gitleaks detect --no-git --no-banner --source "$d" --config "$cfg" >/dev/null 2>&1; then
                echo "SELFTEST FAIL: gitleaks did NOT detect $label (fixture: $fixture) — rule dead or fixture drifted (phantom coverage)"
                exit 1
              fi
            }
            expect_detect "positive-square.txt" "the sq0atp- Square access-token rule"
            expect_detect "positive-sourcegraph.txt" "the sgp_ sourcegraph access-token rule"
            expect_detect "positive-sourcegraph-local.txt" "the sgp_local_ sourcegraph access-token alternative"
            expect_clean() {
              local fixture="$1" label="$2" d
              d=$(mktemp -d "$work/d.XXXXXX")
              cp "$fixtures/$fixture" "$d/"
              # SAME template expansion as expect_detect — without it the
              # negatives are scanned as the literal "@HEX40@" string
              # (vacuously clean: no hex for any rule to match, and a
              # corrupted fixture stays undetectable — caught by
              # scripts/negative-test-lints.sh gitleaks/negative-fixture-corrupt
              # on 2026-09-15).
              sed -i "s/@HEX40@/$(printf 'systemnix-gitleaks-coverage-fixture' | sha256sum | cut -c1-40)/" "$d/$fixture"
              if ! ${pkgs.gitleaks}/bin/gitleaks detect --no-git --no-banner --source "$d" --config "$cfg" >/dev/null 2>&1; then
                echo "SELFTEST FAIL: $label tripped gitleaks (fixture: $fixture)"
                ${pkgs.gitleaks}/bin/gitleaks detect --no-git --no-banner --source "$d" --config "$cfg" || true
                exit 1
              fi
            }
            expect_clean "negative-bare-hex.txt" "bare low-entropy 40-hex git SHA"
            expect_clean "negative-hex-no-keyword.txt" "HIGH-entropy 40-hex without rule keywords"
            expect_clean "negative-hex-with-keyword.txt" "bare 40-hex with rule keywords (sourcegraph rule overridden — the rev-pin false-positive class)"
            echo "gitleaks coverage: 3 positive classes detected, 3 negative classes clean"
            touch $out
          '';

          # Lock-audit selftest (2026-10-02 dedup): proves the eval-time
          # flake.lock gate (lib/lock-audit.nix, forced via allEvalGuards)
          # actually fires. Mirrors the gitleaks-coverage pattern: a guard
          # that has never seen a positive fixture is phantom coverage —
          # the audit's first live run caught a real miss (emeet-pixyd),
          # and this check pins that behavior. All legs evaluate at CHECK
          # EVAL time (pure Nix, no nix binary in the sandbox — the
          # in-sandbox nix eval approach fails on missing state dirs);
          # the bash only asserts the precomputed verdicts.
          lock-audit-selftest =
            let
              auditWith =
                lockFile: deliberate:
                (import (root + "/lib/lock-audit.nix") {
                  lock = builtins.fromJSON (builtins.readFile lockFile);
                  inherit deliberate;
                });
              legs = {
                clean = builtins.toJSON (auditWith (root + "/tests/fixtures/lock-audit/clean.lock") { });
                dup = builtins.toJSON (auditWith (root + "/tests/fixtures/lock-audit/evil-dup.lock") { });
                drift = builtins.toJSON (auditWith (root + "/tests/fixtures/lock-audit/evil-drift.lock") { });
                infraDup = builtins.toJSON (auditWith (root + "/tests/fixtures/lock-audit/evil-infra-dup.lock") { });
                allowlisted = builtins.toJSON (
                  auditWith (root + "/tests/fixtures/lock-audit/allowlisted.lock") {
                    "tool.nixpkgs" = "fixture reason";
                  }
                );
                stale = builtins.toJSON (
                  auditWith (root + "/tests/fixtures/lock-audit/clean.lock") {
                    "ghost.nixpkgs" = "x";
                  }
                );
              };
            in
            pkgs.runCommand "lock-audit-selftest"
              {
                inherit (legs)
                  clean
                  dup
                  drift
                  infraDup
                  allowlisted
                  stale
                  ;
              }
              ''
                set -u
                fail() { echo "SELFTEST FAIL: $1"; exit 1; }
                [ "$clean" = "[]" ] || fail "clean fixture produced violations: $clean"
                echo "$dup" | grep -q 'tool' && echo "$dup" | grep -q 'flake-parts' \
                  || fail "evil-dup (same-rev duplicate edge) not flagged: $dup"
                echo "$drift" | grep -q 'fod-tool' && echo "$drift" | grep -q 'nixpkgs' \
                  || fail "evil-drift (foreign-rev edge) not flagged: $drift"
                echo "$infraDup" | grep -q 'hook-tool' && echo "$infraDup" | grep -q 'git-hooks' \
                  || fail "evil-infra-dup (git-hooks own-copy edge) not flagged: $infraDup"
                echo "$infraDup" | grep -q 'compat-tool' && echo "$infraDup" | grep -q 'flake-compat' \
                  || fail "evil-infra-dup (flake-compat own-copy edge) not flagged: $infraDup"
                [ "$allowlisted" = "[]" ] || fail "deliberate-allowlisted edge flagged (qmd/discordsync class): $allowlisted"
                echo "$stale" | grep -q 'matches no live edge' \
                  || fail "stale deliberate entry not flagged (table rot): $stale"
                echo "lock-audit: 6 legs green (clean, dup, drift, infra-dup, allowlisted, stale-deliberate)"
                touch $out
              '';

          # Recursive chown/chmod walks in modules that also configure
          # Bind*Paths: systemd builds the mount namespace BEFORE any
          # ExecStartPre, so a recursive ownership walk descends into the
          # bind (EROFS on read-only binds; cross-filesystem mutation on
          # writable ones). -xdev does NOT protect same-filesystem binds
          # (shared st_dev on one BTRFS subvol) — prune the exact path.
          # FAILING since 2026-09-14 (multiple clean CI cycles passed
          # since the 2026-08-20 hermes incident).
          chown-vs-bind-audit = pkgs.runCommand "chown-vs-bind-audit" { } ''
            warn=0
            for f in $(grep -rlE 'Bind(ReadOnly|ReadWrite)?Paths' ${root}/modules); do
              if grep -nE '(chown|chmod) -R' "$f" | grep -vE '^[0-9]+:[[:space:]]*#'; then
                echo "WARN: $f: recursive chown/chmod -R in a module with Bind*Paths — use find with -prune on the bind target instead"
                warn=1
              fi
              if grep -nE 'find .*(chown|chmod)' "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -vE -- '-prune|-xdev'; then
                echo "WARN: $f: find chown/chmod walk without -prune/-xdev in a module with Bind*Paths"
                warn=1
              fi
            done
            if [ "$warn" -ne 0 ]; then
              echo "FAIL: recursive ownership walks coexist with bind mounts — fix the lines above (find with -prune on the bind target, never chown/chmod -R)"
              exit 1
            fi
            touch $out
          '';
        };
    };
}
