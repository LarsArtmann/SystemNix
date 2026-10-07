# VM test for the root-prune-guard unit+timer (snapshots.nix).
#
# The root-prune-guard-fixture flake check covers SCRIPT LOGIC only (PATH
# stubs for df/btrbk against the committed script). Nothing covered the
# systemd integration: the timer wiring (OnBootSec/OnUnitActiveSec,
# timers.target), the unit actually running as the btrbk user through the
# writeShellApplication wrapper, and the always-exit-0 + always-write-the-
# .prom contract END-TO-END. This VM test closes that gap.
#
# Proves, against the REAL module import:
#   1. TIMER WIRING: root-prune-guard.timer is enabled (wantedBy
#      timers.target) with the 2min boot / 5min cadence contract.
#   2. UNIT IDENTITY: the service is the btrbk-user oneshot production
#      declares (User=btrbk, StateDirectory=btrbk).
#   3. THRESHOLD CROSSING (real, not stubbed): filling the root past the
#      90% df-scale floor makes the NEXT manual run invoke btrbk with the
#      exact production invocation (`-c /etc/btrbk/root.conf prune`) and
#      record fired=1 — while a failed prune (stubbed btrbk exit 3) still
#      leaves the UNIT exit 0 (operational state, not a crash).
#   4. METRIC RENAME CONTRACT: the .prom lands at the script's DEFAULT
#      textfile path with the root_prune_guard_{fired,usage_pct,prune_exit}
#      names (the Gatus anchored-presence legs key on these), and flips
#      back to fired=0 below threshold with btrbk NOT invoked.
#
# btrbk is stubbed by overwriting its store binary (remount,rw /nix/store —
# the standard VM-test trick) because the writeShellApplication wrapper
# prepends its runtimeInputs to PATH ahead of any unit-level path stub.
{ pkgs, ... }:
let
  snapshots = import ../platforms/nixos/system/snapshots.nix;
  # snapshots.nix sets services.rust-cache.rustProjects (target/ symlink
  # tmpfiles), whose option lives in this flake-parts wrapper module.
  rustCache =
    (import ../modules/nixos/services/rust-cache.nix).flake.nixosModules.rust-cache;
  # btrbk stub: logs the invocation, exits /tmp/btrbk-rc (default 0). Written
  # over ${pkgs.btrbk}/bin/btrbk in the VM because the module's
  # writeShellApplication wrapper prepends its runtimeInputs to PATH ahead
  # of any unit-level path stub.
  btrbkStub = pkgs.writeShellScript "btrbk" ''
    echo "$*" >> /tmp/btrbk.log
    [ -f /tmp/btrbk-rc ] && exit "$(cat /tmp/btrbk-rc)"
    exit 0
  '';
in
{
  name = "root-prune-guard";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        snapshots
        rustCache
        (import ../platforms/nixos/system/primary-user.nix)
      ];

      # Registry-fan-out option stub (test-integration precedent): rust-cache
      # declares a services.integration entry behind `mkIf enable`, which
      # still requires the option to EXIST — the owning module is not part
      # of this test's import set.
      options.services.integration = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
      };
      config = {
        boot.supportedFilesystems = [ "btrfs" ];

        # primaryUser ("lars") is referenced for tmpfiles/home paths; the
        # production user account is created by HM wiring the VM does not run.
        users.users.lars = {
          isNormalUser = true;
        };

        # Production creates the btrbk user via the nixpkgs services.btrbk
        # module's sudoRule story; the guard only needs the user/group to
        # exist, so the test creates them directly.
        users.groups.btrbk = { };
        users.users.btrbk = {
          isSystemUser = true;
          group = "btrbk";
        };
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # 1: timer wiring (wantedBy timers.target -> enabled; cadence contract).
    machine.succeed("systemctl is-enabled root-prune-guard.timer")
    timer = machine.succeed("systemctl cat root-prune-guard.timer")
    assert "OnBootSec=2min" in timer, f"OnBootSec missing: {timer}"
    assert "OnUnitActiveSec=5min" in timer, f"OnUnitActiveSec missing: {timer}"

    # 2: unit identity — the production btrbk-user oneshot.
    user = machine.succeed(
        "systemctl show root-prune-guard.service -p User --value"
    ).strip()
    assert user == "btrbk", f"service User is {user!r}, expected btrbk"

    # The script's default OUT dir must exist (production: the node-exporter
    # textfile dir) — the mktemp + sticky-rename contract needs it.
    machine.succeed(
        "mkdir -p /var/lib/prometheus-node-exporter/textfile_collectors && "
        "chown btrbk:btrbk /var/lib/prometheus-node-exporter/textfile_collectors"
    )

    # Stub btrbk by overwriting its store binary (the wrapper prepends its
    # runtimeInputs to PATH ahead of any unit-level path stub). Default:
    # log the invocation, exit 0; /tmp/btrbk-rc lets the failure-leg flip it.
    # The store path is computed host-side from the SAME pkgs instance the
    # module's writeShellApplication wrapper uses — identical store path.
    btrbk_store = "${pkgs.btrbk}/bin/btrbk"
    machine.succeed("mount -o remount,rw /nix/store")
    machine.succeed("cp ${btrbkStub} " + btrbk_store)

    prom = "/var/lib/prometheus-node-exporter/textfile_collectors/root-prune-guard.prom"

    def metric(name):
        return machine.succeed(
            f"awk '$1 == \"root_prune_guard_{name}\" {{ print $2 }}' {prom}"
        ).strip()

    # 4a (below threshold, FIRST): fresh VM root is well under 90% — the
    # metric is always written, fired=0, btrbk NOT invoked.
    machine.succeed("rm -f /tmp/btrbk.log /tmp/btrbk-rc")
    machine.succeed("systemctl start root-prune-guard.service")
    assert metric("fired") == "0", f"fired should be 0 below threshold: {metric('fired')}"
    assert metric("prune_exit") == "0"
    machine.succeed("test ! -e /tmp/btrbk.log")  # btrbk never invoked below threshold

    # 3: REAL threshold crossing — fill the root past 90% (df scale:
    # used/(used+avail)). fallocate 95% of current avail pushes the ratio
    # over the floor on any root with used > ~5% (a booted NixOS VM root).
    machine.succeed(
        "AVAIL=$(df -Pk / | awk 'NR==2{print $4}') && "
        "fallocate -l $((AVAIL * 95 / 100)) /fill"
    )
    machine.succeed("rm -f /tmp/btrbk.log")
    machine.succeed("systemctl start root-prune-guard.service")  # must exit 0
    usage = metric("usage_pct")
    assert int(usage) > 90, f"fill did not cross 90% (usage_pct={usage})"
    assert metric("fired") == "1", f"fired should be 1 above threshold: {metric('fired')}"
    inv = machine.succeed("cat /tmp/btrbk.log").strip()
    assert inv == "-c /etc/btrbk/root.conf prune", f"wrong btrbk invocation: {inv!r}"
    assert metric("prune_exit") == "0"

    # 3b: FAILING prune — exit recorded in the metric, unit STILL exits 0
    # (the 5-min timer is the retry; Gatus goes red on fired=1, not systemd).
    machine.succeed("echo 3 > /tmp/btrbk-rc && rm -f /tmp/btrbk.log")
    machine.succeed("systemctl start root-prune-guard.service")
    assert metric("prune_exit") == "3", f"prune_exit should record 3: {metric('prune_exit')}"
    assert metric("fired") == "1"

    # 4b: below threshold again — fired flips back, btrbk not invoked.
    machine.succeed("rm -f /fill /tmp/btrbk-rc /tmp/btrbk.log")
    machine.succeed("systemctl start root-prune-guard.service")
    assert metric("fired") == "0"
    assert metric("prune_exit") == "0"
    machine.succeed("test ! -e /tmp/btrbk.log")
  '';
}
