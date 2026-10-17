# Selftests for the operational scripts and pre-commit legs, plus the
# disko geometry guard, exit-contract checks, buildcache parity.
# Split out of flake.nix 2026-10-08.
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      checks = {
        # disko geometry spec guard (Phase-2 plan T16.2/T16.3):
        # eval-checks diskoConfigurations.samsung-tlc against the LIVE
        # geometry and asserts the flake-discovery trap stays closed —
        # the disko config must never be reachable from
        # nixosConfigurations (an imported disko module would make
        # `disko --flake .#evo-x2` apply destructive modes).
        disko-samsung-tlc =
          let
            inherit (inputs.self.diskoConfigurations.samsung-tlc.disko.devices.disk.samsung-tlc) content device;
            inherit (content.partitions) esp main;
            evoConfigOptions = inputs.self.nixosConfigurations.evo-x2.options;
            geometryGuards =
              assert device == "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0RA01856V";
              assert content.type == "gpt";
              assert esp.type == "EF00" && esp.size == "4G";
              assert esp.content.format == "vfat";
              assert esp.content.mountpoint == null;
              assert lib.elem "-n" esp.content.extraArgs && lib.elem "SAMSUNG-EFI" esp.content.extraArgs;
              assert main.content.type == "btrfs";
              assert lib.elem "-L" main.content.extraArgs && lib.elem "tlc" main.content.extraArgs;
              # toplevel (subvolid=5) at /mnt/hot — hot/<name> service
              # subvols are created THROUGH it, never a named subvol
              assert main.content.mountpoint == "/mnt/hot";
              assert main.content.subvolumes ? "/nix";
              assert main.content.subvolumes ? "/users/lars/cache/nix";
              assert !(evoConfigOptions ? disko);
              true;
          in
          builtins.deepSeq geometryGuards (
            pkgs.runCommand "disko-samsung-tlc-check" { } ''
              echo "samsung-tlc disko geometry + discovery-trap guard OK" > $out
            ''
          );

        # The pre-deploy §10 metric-absence classifier decides whether a
        # deploy is BLOCKED — twice on 2026-09-02 the downgrade branches
        # (node_textfile_scrape_error, forgejo scan-failed) had no tests
        # and blocked the deploy carrying their own fix. This check runs
        # the fixture selftest THROUGH nix so the tested artifact is the
        # same file pre-deploy-check.sh sources (never trust a script
        # test that greps its own copy).
        pre-deploy-metrics-selftest = pkgs.runCommand "pre-deploy-metrics-selftest" { } ''
          # Stage the repo layout the test script sources from
          # (it resolves scripts/lib/ relative to its own path — a bare
          # store file has no sibling lib).
          scratch=$(mktemp -d)
          mkdir -p "$scratch/scripts/lib"
          cp ${root}/scripts/test-pre-deploy-metrics.sh "$scratch/scripts/test-pre-deploy-metrics.sh"
          cp ${root}/scripts/lib/metrics-gate.sh "$scratch/scripts/lib/metrics-gate.sh"
          ${pkgs.bash}/bin/bash "$scratch/scripts/test-pre-deploy-metrics.sh"
          touch $out
        '';

        # maintenance-entry-gate selftest: runs the BUILT gate binary's
        # 10-scenario fixture selftest (PSI band boundaries, trip-recency
        # window, fail-open PSI-less kernel, clock-skew) — the freeze
        # #19/#20/#21 admission gate every migrate-* script and
        # btrfs-gc-guard delegate to. Testing the store artifact proves
        # the build (writeShellApplication + shellcheck) AND the verdict
        # logic in one shot.
        maintenance-entry-gate-selftest = pkgs.runCommand "maintenance-entry-gate-selftest" { } ''
          ${pkgs.maintenance-entry-gate}/bin/maintenance-entry-gate selftest
          touch $out
        '';

        # thermal-pstate-guard.sh flips the amd_pstate driver mode
        # (active<->guided) on hysteresis over hwmon sensors — the
        # freeze #8-#14 thermal-ceiling family's enforcement leg (a
        # written "no heavy builds" gate was violated within the hour
        # it was written). Runs the REAL committed script against
        # fixture sysfs trees (pre-deploy-metrics-selftest staging
        # shape): enter/exit hysteresis, snapshot restore, external-
        # override adoption, blind-sensor degradation.
        thermal-pstate-guard-selftest =
          pkgs.runCommand "thermal-pstate-guard-selftest"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
              ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/thermal-pstate-guard.sh "$scratch/thermal-pstate-guard.sh"
              ${pkgs.bash}/bin/bash "$scratch/thermal-pstate-guard.sh" selftest
              touch $out
            '';

        # bun-memory-watchdog fixture selftest: kills the 17 GiB bun and
        # the exactly-at-threshold bun, spares the 15 GiB bun and the
        # over-threshold non-bun, accumulates the kill counter across
        # sweeps, and stamps prom freshness. Runs the REAL sweep via
        # `sweep-run` subprocesses against a fixture /proc tree.
        bun-memory-watchdog-selftest =
          pkgs.runCommand "bun-memory-watchdog-selftest"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
              ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/bun-memory-watchdog.sh "$scratch/bun-memory-watchdog.sh"
              ${pkgs.bash}/bin/bash "$scratch/bun-memory-watchdog.sh" selftest
              touch $out
            '';

        # Census durability-ring selftest (10-03 07:18→17:00 census gap):
        # runs the REAL ring append against a fixture textfile dir —
        # bounded rotate-last-N under a 300-tick pressure window, whole-block
        # rotation (no torn samples), epoch monotonicity, corrupt-ring
        # self-heal, SIGKILL-corpse tolerance, empty-sample no-op. Plus two
        # static tripwires on the module the fixture cannot see: the ring
        # append must precede the .prom publish (a run killed between the
        # two still leaves its census sample — the incident property), and
        # the ring must never be a .prom (a multi-sample log would poison
        # the node_exporter exposition).
        census-ring-selftest =
          pkgs.runCommand "census-ring-selftest"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                gnugrep
              ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/system-health-census-ring.sh "$scratch/system-health-census-ring.sh"
              # The selftest re-executes the copy via "$0"; /usr/bin/env does not exist in the sandbox.
              sed -i "1s|.*|#!${pkgs.bash}/bin/bash|" "$scratch/system-health-census-ring.sh"
              ${pkgs.bash}/bin/bash "$scratch/system-health-census-ring.sh" selftest
              mod=${root}/modules/nixos/services/system-health.nix
              ring_line=$(grep -n 'bin/system-health-census-ring' "$mod" | head -n 1 | cut -d: -f1)
              mv_line=$(grep -n 'mv "\$TMP" "\$OUT"' "$mod" | head -n 1 | cut -d: -f1)
              if [ -z "$ring_line" ] || [ -z "$mv_line" ] || [ "$ring_line" -ge "$mv_line" ]; then
                echo "FAIL: census ring append missing or not before the .prom publish (ring@$ring_line mv@$mv_line)"
                exit 1
              fi
              if grep -q 'census-memory-ring\.prom' "$mod"; then
                echo "FAIL: census ring path must never end in .prom (node_exporter would scrape a multi-sample log)"
                exit 1
              fi
              touch $out
            '';

        # catalog-inventory selftest: fixture host docs through the REAL
        # union filter — name-union + alphabetical order, first-non-null
        # field precedence (catalog beats integration, any host order),
        # deployments only from enable=true rows with per-host URLs and
        # the deploying host's port, zero-deploy shapes, service-less host
        # in the hosts list. The 3 live eval legs stay live-only (they are
        # the script's value); the jq assembly is the silently-regressible
        # part. Feeds catalog.home.lan's deployment chips.
        catalog-inventory-selftest =
          pkgs.runCommand "catalog-inventory-selftest"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                jq
              ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/catalog-inventory.sh "$scratch/catalog-inventory.sh"
              # /usr/bin/env does not exist in the sandbox.
              sed -i "1s|.*|#!${pkgs.bash}/bin/bash|" "$scratch/catalog-inventory.sh"
              ${pkgs.bash}/bin/bash "$scratch/catalog-inventory.sh" --self-test
              touch $out
            '';

        # Pre-vacuum evidence-gate selftest: fixture-tests the pure helpers
        # (boot-id/date extraction, hex-boundary evidence grep, open-row date
        # matching against UNCHECKED rows only) plus a static tripwire that
        # pre-deploy-check.sh still wires the gate as a deploy-blocking check
        # (a deleted §15 call would go phantom-green otherwise).
        pre-vacuum-gate-selftest =
          pkgs.runCommand "pre-vacuum-gate-selftest"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                gnugrep
              ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/pre-vacuum-evidence-gate.sh "$scratch/pre-vacuum-evidence-gate.sh"
              # The selftest re-executes the copy via "$0"; /usr/bin/env does not exist in the sandbox.
              sed -i "1s|.*|#!${pkgs.bash}/bin/bash|" "$scratch/pre-vacuum-evidence-gate.sh"
              ${pkgs.bash}/bin/bash "$scratch/pre-vacuum-evidence-gate.sh" selftest
              if ! grep -q 'pre-vacuum-evidence-gate.sh' ${root}/scripts/pre-deploy-check.sh; then
                echo "FAIL: pre-deploy-check no longer wires the pre-vacuum evidence gate"
                exit 1
              fi
              touch $out
            '';

        # Browser-history registration-gate smoke selftest: runs the REAL
        # smoke lib against python3 fixture servers (kernel-assigned ports)
        # — the gate-closed PASS, the 400-open-gate regression branch (§f.15
        # of the 2026-10-15 self-review: the leg shipped without a negative
        # test), the no-CSRF-headers branch, the bare-403-without-body
        # branch (the body match is load-bearing), 429-warn, unexpected
        # status — plus a static tripwire that post-deploy-check.sh still
        # sources the lib and calls the smoke (a deleted wiring would go
        # phantom-green).
        browser-history-registration-smoke-selftest =
          pkgs.runCommand "browser-history-registration-smoke-selftest"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                curl
                gnugrep
                gnused
                python3
              ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/lib/browser-history-registration-smoke.sh "$scratch/lib-smoke.sh"
              cp ${root}/scripts/test-browser-history-registration-smoke.sh "$scratch/test.sh"
              # Repoint the test's lib source at the scratch copy and fix
              # the shebang: /usr/bin/env does not exist in the sandbox.
              sed -i "1s|.*|#!${pkgs.bash}/bin/bash|" "$scratch/test.sh"
              sed -i "s|source \"\$here/lib/browser-history-registration-smoke.sh\"|source \"$scratch/lib-smoke.sh\"|" "$scratch/test.sh"
              ${pkgs.bash}/bin/bash "$scratch/test.sh"
              if ! grep -q 'browser_history_registration_smoke' ${root}/scripts/post-deploy-check.sh; then
                echo "FAIL: post-deploy-check no longer wires the registration-gate smoke"
                exit 1
              fi
              touch $out
            '';

        # io-psi-crosscheck selftest: fixture-tests the pure helpers (io_ticks
        # delta math incl. vanished-device drop, max util, cgroup io.pressure
        # ranking with root exclusion + malformed skip + decimal order), runs
        # the evidence mode end-to-end against a mutating fixture stat file,
        # and a static tripwire that deploy.sh still wires the crosscheck
        # beside the PSI refusal line (a deleted call would go phantom-green).
        io-psi-crosscheck-selftest =
          pkgs.runCommand "io-psi-crosscheck-selftest"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                gnugrep
              ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/io-psi-crosscheck.sh "$scratch/io-psi-crosscheck.sh"
              # The selftest re-executes the copy via "$0"; /usr/bin/env does not exist in the sandbox.
              sed -i "1s|.*|#!${pkgs.bash}/bin/bash|" "$scratch/io-psi-crosscheck.sh"
              ${pkgs.bash}/bin/bash "$scratch/io-psi-crosscheck.sh" selftest ${root}/scripts/deploy.sh
              touch $out
            '';

        # io-psi-forensics selftest: durability + retention for the trap-time
        # capture bundles. Fixture-tests (temp bundle dir, /var/tmp untouched):
        # staging→fsync→atomic-rename ordering (the freeze-13/18 vanish class:
        # a logged "bundle written" must imply fsynced bytes), no staging
        # residue, bundle content present, KEEP-newest retention pruning
        # oldest-first — plus source tripwires pinning the fsync-before-
        # rename-before-log order.
        io-psi-forensics-selftest =
          pkgs.runCommand "io-psi-forensics-selftest"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                gnugrep
              ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/io-psi-forensics.sh "$scratch/io-psi-forensics.sh"
              # The selftest re-executes the copy via "$0"; /usr/bin/env does not exist in the sandbox.
              sed -i "1s|.*|#!${pkgs.bash}/bin/bash|" "$scratch/io-psi-forensics.sh"
              ${pkgs.bash}/bin/bash "$scratch/io-psi-forensics.sh" selftest
              touch $out
            '';

        # Guard trip-counter persist-before-log selftest (freeze-13 finding
        # 11): boot-0's first trip reused the death trip's number because the
        # counter file write was page-cache only when the power cut landed.
        # Static tripwires on the module the VM test cannot run mid-storm:
        # the COUNT_FILE write must precede its fsync, and the fsync must
        # precede the "action taken" journal line (the line implies the
        # counter survived), plus the zone/history fsync leg.
        guard-trip-persist-selftest =
          pkgs.runCommand "guard-trip-persist-selftest"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                gnugrep
              ];
            }
            ''
              mod=${root}/modules/nixos/services/memory-emergency-guard.nix
              count_l=$(grep -n 'echo "\$tripped_total" > "\$COUNT_FILE"' "$mod" | head -1 | cut -d: -f1)
              sync_l=$(grep -n 'sync -f "\$LAST_TRIP_FILE" "\$COUNT_FILE"' "$mod" | head -1 | cut -d: -f1)
              log_l=$(grep -n 'MEMORY EMERGENCY action taken' "$mod" | head -1 | cut -d: -f1)
              zsync_l=$(grep -n 'sync -f "\$ZONE_FILE" "\$HISTORY_FILE"' "$mod" | head -1 | cut -d: -f1)
              hist_l=$(grep -n 'echo "\$now \$zone" >> "\$HISTORY_FILE"' "$mod" | head -1 | cut -d: -f1)
              if [ -z "$count_l" ] || [ -z "$sync_l" ] || [ -z "$log_l" ]; then
                echo "FAIL: trip-persist anchors missing (count@$count_l sync@$sync_l log@$log_l)"
                exit 1
              fi
              if [ "$count_l" -ge "$sync_l" ] || [ "$sync_l" -ge "$log_l" ]; then
                echo "FAIL: persist-before-log order broken (count@$count_l must precede sync@$sync_l must precede log@$log_l)"
                exit 1
              fi
              if [ -z "$zsync_l" ] || [ -z "$hist_l" ] || [ "$hist_l" -ge "$zsync_l" ]; then
                echo "FAIL: zone/history fsync leg missing or misordered (hist@$hist_l zsync@$zsync_l)"
                exit 1
              fi
              touch $out
            '';

        # Boot-evidence-pull selftest: runs the pull script's `selftest`
        # mode (fixture journal through the canonical-section renderer:
        # census counts, hex-boundary id8 citation for the pre-vacuum
        # gate incl. a negative control, panic truncation, write-refusal)
        # plus static tripwires: the stability remedy doc must still point
        # at the script (doc-drift guard) and the script must carry the
        # no-overwrite guard (evidence files are append-only).
        boot-evidence-pull-selftest =
          pkgs.runCommand "boot-evidence-pull-selftest"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                gnugrep
              ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/boot-evidence-pull.sh "$scratch/boot-evidence-pull.sh"
              # The selftest re-executes the copy via "$0"; /usr/bin/env does not exist in the sandbox.
              sed -i "1s|.*|#!${pkgs.bash}/bin/bash|" "$scratch/boot-evidence-pull.sh"
              ${pkgs.bash}/bin/bash "$scratch/boot-evidence-pull.sh" selftest
              grep -q 'boot-evidence-pull.sh' ${root}/docs/agents/stability.md
              grep -q 'REFUSING to overwrite existing evidence file' "$scratch/boot-evidence-pull.sh"
              touch $out
            '';

        # Pocket ID secret-rotation automation selftest (guard + auto-rotate):
        # runs the REAL scripts against fixtures — the regenerateSecretsFor
        # stale-list guard (missing -> allow, fresh -> trip with actionable
        # message, old -> allow) and the auto-rotation planner/parser
        # selftest mode (cap, oldest-first, threshold boundary, hidden-file
        # skip, consumer-spec forms) — plus static tripwires on the module
        # wiring: the provisioner must invoke the guard, the auto-rotation
        # unit must exist with a timeout bound and healthz gate, the cv
        # idempotency-gate form must be in the consumer map, and the daily
        # timer must exist. Dry-run never rotates; apply mode is capped at
        # maxPerRun — the selftest exercises everything that does not need
        # a live Pocket ID.
        pocket-id-rotation-selftest =
          pkgs.runCommand "pocket-id-rotation-selftest"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                gnugrep
              ];
            }
            ''
              scratch=$(mktemp -d)
              guard=${root}/scripts/pocket-id-regenerate-guard.sh
              auto=${root}/scripts/pocket-id-auto-rotate.sh
              mod=${root}/modules/nixos/services/pocket-id.nix

              # guard: missing file -> allow (recreation path)
              if bash "$guard" "$scratch/missing" c 24; then :; else
                echo "FAIL: guard must allow a missing secret file"
                exit 1
              fi

              # guard: fresh file inside window -> trip, actionable message
              echo x >"$scratch/fresh"
              touch -d "1 hour ago" "$scratch/fresh"
              if bash "$guard" "$scratch/fresh" c 24 2>"$scratch/err"; then
                echo "FAIL: guard must trip on a fresh file still listed"
                exit 1
              fi
              grep -q "regenerateSecretsFor GUARD" "$scratch/err" ||
                { echo "FAIL: guard trip message missing"; exit 1; }
              grep -q "regenerateSecretsFor and redeploy" "$scratch/err" ||
                { echo "FAIL: guard fix hint missing"; exit 1; }

              # guard: old file outside window -> allow
              echo x >"$scratch/old"
              touch -d "3 days ago" "$scratch/old"
              if bash "$guard" "$scratch/old" c 24; then :; else
                echo "FAIL: guard must allow a file older than the window"
                exit 1
              fi

              # auto-rotate: planner/parser selftest mode (real artifact)
              bash "$auto" selftest

              # static tripwires on the module wiring
              grep -q 'getExe regenerateGuard} "\$SECRET_FILE"' "$mod" ||
                { echo "FAIL: provisioner does not invoke the stale-list guard"; exit 1; }
              grep -q 'pocket-id-auto-rotation' "$mod" ||
                { echo "FAIL: auto-rotation service/timer missing"; exit 1; }
              grep -q 'TimeoutStartSec = "20min"' "$mod" ||
                { echo "FAIL: auto-rotation unit lacks its TimeoutStartSec bound"; exit 1; }
              grep -q '/healthz' "$mod" &&
                grep -q 'autoRotateScript' "$mod" ||
                { echo "FAIL: auto-rotation script or healthz gate missing"; exit 1; }
              grep -q 'cv-server@cv-oidc-env:' "$mod" ||
                { echo "FAIL: cv idempotency gate missing from consumer map"; exit 1; }
              grep -q 'OnCalendar = "\*-\*-\* 05:00:00"' "$mod" ||
                { echo "FAIL: auto-rotation daily timer missing"; exit 1; }

              touch $out
            '';

        # The pre-deploy §11 vendorHash-freshness parsers BLOCK deploys
        # on FOD hash mismatch — the greps they replaced matched output
        # nix never produces and warned "unable to determine status" on
        # every run for two months (the 2026-08 stale-vendorHash class
        # broke two deploys unseen). Fixtures are REAL captured nix
        # output; same staging + through-nix rationale as
        # pre-deploy-metrics-selftest above.
        pre-deploy-vendor-selftest = pkgs.runCommand "pre-deploy-vendor-selftest" { } ''
          scratch=$(mktemp -d)
          mkdir -p "$scratch/scripts/lib"
          cp ${root}/scripts/test-pre-deploy-vendor.sh "$scratch/scripts/test-pre-deploy-vendor.sh"
          cp ${root}/scripts/lib/vendor-freshness.sh "$scratch/scripts/lib/vendor-freshness.sh"
          ${pkgs.bash}/bin/bash "$scratch/scripts/test-pre-deploy-vendor.sh"
          touch $out
        '';

        # The pre-commit hook's shellcheck leg is the stricter bar
        # (warning; CI's shellcheck job is error-level) but only fires
        # on STAGED files — this fixture proves it end-to-end so
        # "did shellcheck run when X first staged" (2026-09-23 borg
        # drill question) never has to be re-asked: positive run
        # against the REAL hook + a negative mutation (the leg's
        # fail-closed branch removed MUST fail the fixture's S5
        # assert). SHELLCHECK_BIN is pinned because `nix shell`
        # cannot run inside a build sandbox; on the host the test
        # defaults to the hook's exact invocation.
        precommit-shellcheck-leg-selftest =
          pkgs.runCommand "precommit-shellcheck-leg-selftest"
            {
              nativeBuildInputs = [
                pkgs.git
                pkgs.shellcheck
              ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/test-precommit-shellcheck.sh "$scratch/test.sh"
              export SHELLCHECK_BIN=${pkgs.shellcheck}/bin/shellcheck
              # The script copied to scratch cannot discover the repo,
              # so pin the hook for the positive run too.
              cp ${root}/.githooks/pre-commit "$scratch/real-hook"
              PRECOMMIT_HOOK="$scratch/real-hook" bash "$scratch/test.sh"
              sed 's/all_passed=false/all_passed=true/' "$scratch/real-hook" > "$scratch/mutated-hook"
              if PRECOMMIT_HOOK="$scratch/mutated-hook" bash "$scratch/test.sh" > "$scratch/mut.log" 2>&1; then
                echo "FAIL: mutated hook (fail-closed branch removed) passed the fixture"
                cat "$scratch/mut.log"
                exit 1
              fi
              grep -q "S5 leg no longer fail-closed" "$scratch/mut.log" || {
                echo "FAIL: mutation caught but not by the S5 assert"
                cat "$scratch/mut.log"
                exit 1
              }
              touch $out
            '';

        # The pre-commit nix-parse leg (the auto-commit daemon's
        # broken-intermediate class, 4 swept into history before
        # 2026-09-30): proves the staged-.nix parse gate end-to-end —
        # a broken staged file FAILS, a valid nested one parses, a
        # deletion-only staging skips — plus a mutation negative (the
        # parse command neutered must trip the fixture's P1 assert).
        # Bare `nix-instantiate` resolves from PATH (pinned to pkgs.nix
        # via nativeBuildInputs; on the host that IS the hook's real
        # invocation). Parse-only needs no store: HOME is pinned to a
        # scratch dir so libstore init cannot write anywhere real.
        precommit-nix-parse-selftest =
          pkgs.runCommand "precommit-nix-parse-selftest"
            {
              nativeBuildInputs = [
                pkgs.git
                pkgs.nix
              ];
            }
            ''
              scratch=$(mktemp -d)
              mkdir -p "$scratch/home"
              export HOME="$scratch/home"
              cp ${root}/scripts/test-precommit-nix-parse.sh "$scratch/test.sh"
              cp ${root}/.githooks/pre-commit "$scratch/real-hook"
              PRECOMMIT_HOOK="$scratch/real-hook" bash "$scratch/test.sh"
              sed 's/nix-instantiate --parse/nix-instantiate --parse-neutered/' "$scratch/real-hook" > "$scratch/mutated-hook"
              if PRECOMMIT_HOOK="$scratch/mutated-hook" bash "$scratch/test.sh" > "$scratch/mut.log" 2>&1; then
                echo "FAIL: mutated hook (parse command neutered) passed the fixture"
                cat "$scratch/mut.log"
                exit 1
              fi
              grep -q "P1" "$scratch/mut.log" || {
                echo "FAIL: mutation caught but not by the P1 assert"
                cat "$scratch/mut.log"
                exit 1
              }
              touch $out
            '';

        # Standing regression test for the pre-commit docs-only
        # flake-check skip guard (landed 2026-09-28, verified only with
        # a throwaway /tmp classification script until this fixture).
        # Proves the classification (all-docs staged diff skips the
        # leg; .nix-mixed / deleted-.nix / extension-less diffs run it)
        # plus a mutation negative: narrowing the pattern to .md-only
        # must trip the fixture's T1 assert — html/txt-only commits
        # would silently lose the skip.
        precommit-docs-skip-selftest =
          pkgs.runCommand "precommit-docs-skip-selftest"
            {
              nativeBuildInputs = [ pkgs.git ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/test-precommit-docs-skip.sh "$scratch/test.sh"
              cp ${root}/.githooks/pre-commit "$scratch/real-hook"
              PRECOMMIT_HOOK="$scratch/real-hook" bash "$scratch/test.sh"
              sed "s/(md|html|txt)/(md)/" "$scratch/real-hook" > "$scratch/mutated-hook"
              if PRECOMMIT_HOOK="$scratch/mutated-hook" bash "$scratch/test.sh" > "$scratch/mut.log" 2>&1; then
                echo "FAIL: mutated hook (docs pattern narrowed to .md-only) passed the fixture"
                cat "$scratch/mut.log"
                exit 1
              fi
              grep -q "T1" "$scratch/mut.log" || {
                echo "FAIL: mutation caught but not by the T1 assert"
                cat "$scratch/mut.log"
                exit 1
              }
              touch $out
            '';

        # Standing fixture test for .githooks/commit-msg (the 72-char
        # subject contract, whose 7 verification fixtures died with its
        # authoring session 2026-09-28). Proves the inclusive 72/73
        # boundary, comment-scaffold skipping, both merge exemptions,
        # and the multibyte ${#} locale semantics under LC_ALL=C — plus
        # a mutation negative (the 72 constant drifted must trip the
        # fixture's C2 assert).
        commit-msg-hook-selftest =
          pkgs.runCommand "commit-msg-hook-selftest"
            {
              nativeBuildInputs = [ pkgs.git ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/test-commit-msg-hook.sh "$scratch/test.sh"
              cp ${root}/.githooks/commit-msg "$scratch/real-hook"
              COMMIT_MSG_HOOK="$scratch/real-hook" bash "$scratch/test.sh"
              sed 's/-gt 72/-gt 999/' "$scratch/real-hook" > "$scratch/mutated-hook"
              if COMMIT_MSG_HOOK="$scratch/mutated-hook" bash "$scratch/test.sh" > "$scratch/mut.log" 2>&1; then
                echo "FAIL: mutated hook (limit drifted to 999) passed the fixture"
                cat "$scratch/mut.log"
                exit 1
              fi
              grep -q "C2" "$scratch/mut.log" || {
                echo "FAIL: mutation caught but not by the C2 assert"
                cat "$scratch/mut.log"
                exit 1
              }
              touch $out
            '';

        # The post-deploy pressure verdicts must never call a storm
        # healthy (2026-09-02: PASS at memory PSI avg10 48-77% during
        # the evening storm). Fixture-driven through the SAME
        # scripts/lib/pressure-report.sh post-deploy-check.sh sources.
        post-deploy-pressure-selftest = pkgs.runCommand "post-deploy-pressure-selftest" { } ''
          scratch=$(mktemp -d)
          mkdir -p "$scratch/scripts/lib"
          cp ${root}/scripts/test-post-deploy-pressure.sh "$scratch/scripts/test-post-deploy-pressure.sh"
          cp ${root}/scripts/lib/pressure-report.sh "$scratch/scripts/lib/pressure-report.sh"
          ${pkgs.bash}/bin/bash "$scratch/scripts/test-post-deploy-pressure.sh"
          touch $out
        '';

        # The §17 memory-throttle sweep must never go silent (the
        # llama-chat class: 46k throttle events, zero alerts). Fixture-
        # driven through the SAME scripts/lib/memory-throttle-sweep.sh
        # post-deploy-check.sh sources (never a drifted copy).
        post-deploy-memory-throttle-selftest = pkgs.runCommand "post-deploy-memory-throttle-selftest" { } ''
          scratch=$(mktemp -d)
          mkdir -p "$scratch/scripts/lib"
          cp ${root}/scripts/test-post-deploy-memory-throttle.sh "$scratch/scripts/test-post-deploy-memory-throttle.sh"
          cp ${root}/scripts/lib/memory-throttle-sweep.sh "$scratch/scripts/lib/memory-throttle-sweep.sh"
          ${pkgs.bash}/bin/bash "$scratch/scripts/test-post-deploy-memory-throttle.sh"
          touch $out
        '';

        # The §18 service-sanity sweep must never go silent (the
        # DiscordSync class: 121% CPU + ~640 journal lines/min for hours,
        # every liveness gate green). Fixture-driven through the SAME
        # scripts/lib/service-sanity-sweep.sh post-deploy-check.sh sources.
        post-deploy-service-sanity-selftest = pkgs.runCommand "post-deploy-service-sanity-selftest" { } ''
          scratch=$(mktemp -d)
          mkdir -p "$scratch/scripts/lib"
          cp ${root}/scripts/test-post-deploy-service-sanity.sh "$scratch/scripts/test-post-deploy-service-sanity.sh"
          cp ${root}/scripts/lib/service-sanity-sweep.sh "$scratch/scripts/lib/service-sanity-sweep.sh"
          PATH=${pkgs.jq}/bin:$PATH ${pkgs.bash}/bin/bash "$scratch/scripts/test-post-deploy-service-sanity.sh"
          touch $out
        '';

        # The offsite-borg §13/§16 smoke verdicts BLOCK the go-live
        # deploy (and FAIL the post-deploy smoke); the blocks only fire
        # for real once services.offsite-borg.enable flips, so the
        # fixture is the ONLY pre-go-live exercise they get. Runs the
        # SAME scripts/lib/offsite-borg-smoke.sh the gates source
        # (never a drifted copy).
        offsite-borg-smoke-selftest =
          pkgs.runCommand "offsite-borg-smoke-selftest"
            {
              nativeBuildInputs = [ pkgs.jq ];
            }
            ''
              scratch=$(mktemp -d)
              mkdir -p "$scratch/scripts/lib"
              cp ${root}/scripts/test-offsite-borg-smoke.sh "$scratch/scripts/test-offsite-borg-smoke.sh"
              cp ${root}/scripts/lib/offsite-borg-smoke.sh "$scratch/scripts/lib/offsite-borg-smoke.sh"
              ${pkgs.bash}/bin/bash "$scratch/scripts/test-offsite-borg-smoke.sh"
              touch $out
            '';

        # The storage-history §14/§19 smoke verdicts run on EVERY deploy
        # (the tier ships enabled, unlike the enable-gated offsite-borg);
        # the stale/never-worked/wiring-missing branches only occur for
        # real at the worst moment (first 04:20 window, detached pool,
        # config regression), so the fixture is the only cheap exercise
        # they get. Runs the SAME scripts/lib/storage-history-smoke.sh the
        # gates source (never a drifted copy).
        storage-history-smoke-selftest =
          pkgs.runCommand "storage-history-smoke-selftest"
            {
              nativeBuildInputs = [ pkgs.jq ];
            }
            ''
              scratch=$(mktemp -d)
              mkdir -p "$scratch/scripts/lib"
              cp ${root}/scripts/test-storage-history-smoke.sh "$scratch/scripts/test-storage-history-smoke.sh"
              cp ${root}/scripts/lib/storage-history-smoke.sh "$scratch/scripts/lib/storage-history-smoke.sh"
              ${pkgs.bash}/bin/bash "$scratch/scripts/test-storage-history-smoke.sh"
              touch $out
            '';

        # Fixture selftest for the pre-commit formatter memo
        # (scripts/lib/precommit-eval-cache.sh — sourced by the hook
        # and scripts/fmt-cached.sh, never a drifted copy). Proves the
        # safety model: module-edit insensitivity (the perf win),
        # flake.nix/lock/overlays/lib sensitivity, rename sensitivity,
        # unreadable-input MISS, GC'd-path MISS, non-store rejection,
        # and the PRECOMMIT_EVAL_CACHE=0 escape hatch.
        precommit-eval-cache-selftest =
          pkgs.runCommand "precommit-eval-cache-selftest"
            {
              nativeBuildInputs = [
                pkgs.git
                pkgs.nix
              ];
            }
            ''
              scratch=$(mktemp -d)
              mkdir -p "$scratch/scripts/lib"
              cp ${root}/scripts/test-precommit-eval-cache.sh "$scratch/scripts/test-precommit-eval-cache.sh"
              cp ${root}/scripts/lib/precommit-eval-cache.sh "$scratch/scripts/lib/precommit-eval-cache.sh"
              ${pkgs.bash}/bin/bash "$scratch/scripts/test-precommit-eval-cache.sh"
              touch $out
            '';

        # Offsite-borg positive-path render guard (2026-09-24 queue:
        # persists the 2026-09-23 §a6 hand probe that otherwise had to
        # be re-run at every dispatch). Renders evo-x2 with
        # services.offsite-borg.enable = true and asserts the FOUR
        # go-live deliverables land on the job unit at EVAL time:
        # BE/6 IO tier (the ioTier.background mkForce intact — both a
        # dropped force and a re-collide-to-nixpkgs-idle fail), the
        # go-live tripwire ExecStartPre, the .last_success freshness
        # marker ExecStartPost, and the borg-env EnvironmentFile
        # (compared against the sops template's own .path, so drift on
        # either side fails). Pure eval — fires on every
        # `nix flake check`, including --no-build (asserts run when
        # the check attr is forced; deepSeq pattern of
        # disko-samsung-tlc). The priority-50 override is required:
        # configuration.nix sets enable = false as a PLAIN value
        # (status report 2026-09-23_10-05 §a6).
        offsite-borg-positive-render =
          let
            sys = inputs.self.nixosConfigurations.evo-x2.extendModules {
              modules = [
                {
                  services.offsite-borg.enable = lib.mkOverride 50 true;
                }
              ];
            };
            svc = sys.config.systemd.services.borgbackup-job-hetzner.serviceConfig;
            envTemplate = sys.config.sops.templates."borg-env".path;
            # Exec* lines render as a single string today; tolerate a
            # list in case nixpkgs' borgbackup module ever merges its
            # own Exec entries.
            execLines = x: if lib.isList x then lib.concatStringsSep "\n" x else toString x;
            renderGuards =
              assert svc.IOSchedulingClass == "best-effort";
              assert toString svc.IOSchedulingPriority == "6";
              assert lib.hasInfix "borg-offsite-golive-check" (execLines svc.ExecStartPre);
              assert lib.hasInfix "/var/lib/borg-offsite/.last_success" (execLines svc.ExecStartPost);
              assert execLines svc.EnvironmentFile == envTemplate;
              assert lib.hasSuffix "borg-env" envTemplate;
              true;
          in
          builtins.deepSeq renderGuards (
            pkgs.runCommand "offsite-borg-positive-render-check" { } ''
              echo "offsite-borg positive-path render OK (BE/6 + tripwire + marker + borg-env)" > $out
            ''
          );

        # Freeze-7 scrub contract: exit 1 (canceled/guard-stopped) is the
        # ONLY tolerated non-zero scrub exit; exit 3 (csum errors —
        # journal 2026-09-21 @data csum=129533) must stay a hard failure
        # as the corruption tripwire. Widening SuccessExitStatus would
        # silently defuse it (the @data repair policy's Oct-5 deadline
        # rides on this signal). Also pins the freeze-7 timer half:
        # Persistent=false (no boot catch-up stampede) + the serial
        # After= chain (root -> data -> pool, asDropin so the template's
        # ExecStart survives). Negative-proven by
        # scripts/negative-test-lints.sh (scrub group).
        scrub-exit-contract =
          let
            cfg = inputs.self.nixosConfigurations.evo-x2.config;
            scrubSvc = cfg.systemd.services."btrfs-scrub@".serviceConfig;
            dataSvc = cfg.systemd.services."btrfs-scrub@data";
            poolSvc = cfg.systemd.services."btrfs-scrub@mnt\\x2dpool";
            contractGuards =
              lib.throwIfNot (scrubSvc.SuccessExitStatus == [ 1 ])
                "scrub-exit-contract: SuccessExitStatus != [ 1 ] — exit 3 (csum corruption) must stay a hard failure"
                (
                  lib.throwIfNot (cfg.systemd.timers."btrfs-scrub@".timerConfig.Persistent == false)
                    "scrub-exit-contract: scrub timer Persistent must be false (boot catch-up stampede)"
                    (
                      lib.throwIfNot (dataSvc.after == [ "btrfs-scrub@-.service" ])
                        "scrub-exit-contract: /data scrub must serialize after root"
                        (
                          lib.throwIfNot (poolSvc.after == [ "btrfs-scrub@data.service" ])
                            "scrub-exit-contract: pool scrub must serialize after /data"
                            (
                              lib.throwIfNot (dataSvc.overrideStrategy == "asDropin" && poolSvc.overrideStrategy == "asDropin")
                                "scrub-exit-contract: instance overrides must be asDropin (a full unit file shadows the template)"
                                true
                            )
                        )
                    )
                );
          in
          builtins.deepSeq contractGuards (
            pkgs.runCommand "scrub-exit-contract-check" { } ''
              echo "scrub contract OK (exit-1-only tolerance, no catch-up, serialized)" > $out
            ''
          );

        # Socket-bridge exit contract (2026-10-07 deploy-exit-4 class):
        # Accept=true per-connection socat bridges (fastflowlm@,
        # llama-vlm-<name>@) exit 143 when systemd stop-SIGTERMs them —
        # socat propagates TERM as an exit code (code=exited, NOT a
        # signal-kill), so without SuccessExitStatus = [ 143 ] every
        # PLANNED stop (memory-guard Zone-6 sacrifice, idle TTL, unit
        # churn, shutdown) parks the instance FAILED and exit-4s any
        # deploy running at that moment (live: guard trip #2211
        # mid-switch 2026-10-07 17:06). fastflowlm enumerated; llama-vlm
        # DERIVED from its own servers attrset — the module only ever
        # generates socat bridges, so family-internal derivation cannot
        # false-positive a non-socat design (tree-wide Accept=true
        # auto-classing stays an owner decision, source report §g.2).
        # No crash-visibility tradeoff: bridges are stateless, sockets
        # re-spawn per connection, backends keep their own failure
        # metrics. Negative-proven by scripts/negative-test-lints.sh
        # (bridge group).
        bridge-exit-contract =
          let
            cfg = inputs.self.nixosConfigurations.evo-x2.config;
            vlmTemplates =
              if cfg.services.llama-vlm.enable then
                map (name: "llama-vlm-${name}@") (builtins.attrNames cfg.services.llama-vlm.servers)
              else
                [ ];
            bridgeTemplates = [ "fastflowlm@" ] ++ vlmTemplates;
            contractGuards = builtins.all (
              tmpl:
              lib.throwIfNot (cfg.systemd.services."${tmpl}".serviceConfig.SuccessExitStatus == [ 143 ])
                "bridge-exit-contract: ${tmpl} SuccessExitStatus != [ 143 ] — planned stops would park the bridge FAILED and exit-4 concurrent deploys (2026-10-07 class)"
                true
            ) bridgeTemplates;
          in
          builtins.deepSeq contractGuards (
            pkgs.runCommand "bridge-exit-contract-check" { } ''
              echo "bridge exit contract OK (${toString (lib.length bridgeTemplates)} Accept=true socat templates tolerate exit 143)" > $out
            ''
          );

        # Gitleaks positive-coverage selftest (2026-09-15, closes the
        # 40-hex saga): turns the retracted TODO rows 357/361 claims
        # into tested invariants. CORRECTED ATTRIBUTION (the harvested
        # claim was wrong twice — this selftest's first run caught it):
        # (1) `sq0atp-` keys the SQUARE access-token rule, NOT
        # sourcegraph-access-token; (2) sourcegraph-access-token's
        # bare-40-hex alternative fired with a rule keyword
        # (sgp_/sourcegraph) ANYWHERE in the file — that class
        # false-positived on flake.nix's ~15 `github:` rev pins
        # (2026-09-16: 17 findings blocking every hooked commit), so
        # .gitleaks.toml now OVERRIDES the rule to sgp_-prefixed
        # shapes only; the keyword-armed bare-hex positive became a
        # NEGATIVE (negative-hex-with-keyword.txt) and
        # positive-sourcegraph-local.txt covers the override's
        # sgp_local_ alternative. Fixtures live in
        # tests/fixtures/gitleaks/ with NO path allowlist — gitleaks
        # skips allowlisted paths at the WALKER level (a real token
        # pasted into an allowlisted file would be invisible), so the
        # fixtures must stay clean under the repo config on their
        # own; gitleaks entropy gates need realistic
        # literals (an all-'a' token passes the regex but dies at
        # entropy ≥2 — the original failure of this selftest).
        # Fixture tokens are TEMPLATES, never literals: @HEX40@ is
        # substituted with a deterministic sha256-derived hex at scan
        # time, because GitHub push protection pattern-matches raw
        # blobs and IGNORES .gitleaks.toml allowlists — a literal
        # sgp_ fixture blocked the 2026-09-15 master push (GH013).
        # buildcacheDirs ↔ KNOWN_CACHE_ENTRIES parity guard
        # (scripts/check-buildcache-known-parity.sh). Extracts the
        # literal dirs from buildcache.nix and the names from the das-
        # link KNOWN array and asserts full coverage — the [6] drift
        # class fails at CI instead of at the next manual re-fire
        # (2026-10-02 re-fire-9). Selftesting: the positive control
        # plus three deliberate drift shapes must FAIL (gitleaks-
        # coverage-selftest house pattern).
        buildcache-known-parity = pkgs.runCommand "buildcache-known-parity" { } ''
          ${pkgs.bash}/bin/bash ${root}/scripts/check-buildcache-known-parity.sh --selftest \
            ${root}/modules/nixos/services/buildcache.nix \
            ${root}/scripts/das-link-recovery-check.sh \
            | tee $out
        '';

      };
    };
}
