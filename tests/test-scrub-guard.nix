# VM test for the btrfs-scrub deferral guard (the 2026-08-31 16:34 freeze
# guard) — exercises the REAL deployed artifact (writeShellApplication output
# from the evo-x2 config) with only the heavy-unit state faked.
#
# The motivating scenario (docs/todo/monitoring.md "Deferred-scrub
# observability + scrub-guard VM test", docs/status/2026-08-31_17-48 §b.4/
# §c.1-2): a btrbk oneshot sits in "activating" MID-SEND; the naive
# `systemctl is-active --quiet` check returns NON-ZERO for that state and
# misses exactly the streaming case — so the guard compares ActiveState
# explicitly and must DEFER. This is also the first end-to-end proof of the
# 2026-10-27 deferral ledger: every defer appends "<epoch> <mnt>" to the
# btrfs-health state dir (the collector reads it into
# btrfs_scrub_deferred_total).
#
# systemctl (and the terminal `btrfs` exec) are sed-STUBBED into the script
# text: the writeShellApplication wrapper pins PATH to its runtimeInputs
# (systemd first among them), so PATH-level stubs can never shadow the real
# binaries (the fastflowlm-idle artifact-test pattern).
#
# Scenarios:
#   1. btrbk-data.service "activating" → guard defers (exit 0, defer
#      message) AND the ledger grows with "<epoch> /data".
#   2. all heavy units "inactive" → guard PROCEEDS past guard 1 (the probe
#      stub records the scrub start; no defer, ledger unchanged).
#   3. btrfs-balance-metadata.service "activating" → defer names the
#      balance unit and appends "<epoch> /mnt/pool".
{ pkgs, self }:

let
  guardExec =
    self.nixosConfigurations.evo-x2.config.systemd.services."btrfs-scrub@".serviceConfig.ExecStart;
  # "${lib.getExe scrubGuard} %f" — the binary part only.
  guardBin = builtins.elemAt (builtins.split " " guardExec) 0;
  # Fixed stub location: the sed-injected script needs no env cooperation.
  stubs = "/tmp/scrub-guard-stubs";
in
pkgs.testers.runNixOSTest {
  name = "scrub-guard";

  nodes.machine =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        (pkgs.runCommand "scrub-guard-under-test"
          {
            nativeBuildInputs = with pkgs; [ gnused ];
          }
          ''
            mkdir -p $out/bin
            sed \
              -e 's|\bsystemctl\b|${stubs}/systemctl|g' \
              -e 's|^exec btrfs scrub start -B |exec ${stubs}/btrfs-probe start -B |' \
              ${guardBin} > $out/bin/btrfs-scrub-guard
            chmod +x $out/bin/btrfs-scrub-guard

            # Negative controls: BOTH injections must have landed — a
            # failed injection would phantom-green every scenario below.
            grep -q '${stubs}/systemctl' $out/bin/btrfs-scrub-guard
            grep -q '${stubs}/btrfs-probe' $out/bin/btrfs-scrub-guard
          '')
      ];
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    machine.succeed("test -x /run/current-system/sw/bin/btrfs-scrub-guard")

    stubs = "${stubs}"
    ledger = "/var/lib/btrfs-health/scrub-deferrals.log"
    machine.succeed(f"mkdir -p {stubs}")

    # systemctl stub: for `... --value <unit>`, print the contents of
    # <unit>.state (default "inactive").
    machine.succeed(f"""
      cat > {stubs}/systemctl <<'EOF'
      #!/bin/sh
      for a in "$@"; do unit="$a"; done
      if [ -f "{stubs}/$unit.state" ]; then
        cat "{stubs}/$unit.state"
      else
        echo inactive
      fi
      exit 0
      EOF
      chmod +x {stubs}/systemctl
    """)
    # btrfs stub: recorded-probe — proves the guard REACHED the scrub start
    # (scenario 2) without needing a real btrfs filesystem in the VM.
    machine.succeed(f"""
      cat > {stubs}/btrfs-probe <<'EOF'
      #!/bin/sh
      echo "PROBE: $*" >> {stubs}/probe.log
      exit 0
      EOF
      chmod +x {stubs}/btrfs-probe
    """)

    # ── Scenario 1: btrbk mid-send (activating) → defer + ledger ──────
    machine.succeed(f"echo activating > {stubs}/btrbk-data.service.state")
    out = machine.succeed("btrfs-scrub-guard /data 2>&1")
    assert "deferring scrub of /data" in out, f"expected defer, got: {out}"
    assert "btrbk-data.service is streaming" in out, f"wrong defer reason: {out}"
    machine.succeed(f"test -f {ledger}")
    line1 = machine.succeed(f"cat {ledger}").strip()
    fields = line1.split()
    assert len(fields) == 2 and fields[0].isdigit() and fields[1] == "/data", (
      f"ledger line malformed: {line1!r}"
    )

    # ── Scenario 2: nothing streaming → guard PROCEEDS (no defer) ─────
    machine.succeed(f"rm -f {stubs}/*.state")
    out = machine.succeed("btrfs-scrub-guard / 2>&1")
    assert "deferring" not in out, f"must not defer when idle, got: {out}"
    machine.succeed(f"grep -q 'PROBE: start -B /' {stubs}/probe.log")
    lines = machine.succeed(f"wc -l < {ledger}").strip()
    assert lines == "1", f"ledger must not grow on a proceed, has {lines} lines"

    # ── Scenario 3: balance mid-run (activating) → defer names it ─────
    machine.succeed(f"echo activating > {stubs}/btrfs-balance-metadata.service.state")
    out = machine.succeed("btrfs-scrub-guard /mnt/pool 2>&1")
    assert "btrfs-balance-metadata.service is streaming" in out, f"wrong reason: {out}"
    last = machine.succeed(f"tail -1 {ledger}").strip()
    assert last.split()[-1] == "/mnt/pool", f"second defer not appended: {last!r}"
    first = machine.succeed(f"head -1 {ledger}").strip()
    assert first.split()[-1] == "/data", f"first ledger line disturbed: {first!r}"

    print("scrub-guard VM test: all scenarios passed")
  '';
}
