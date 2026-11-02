# VM test for the crush-daily service module
# (modules/nixos/services/crush-daily.nix + the upstream crush-daily flake
# module's service/backup units).
#
# The 2026-11-02 backup work was verified by evaluating the rendered script
# and by a shell harness in the flake's `backup-script` check. Neither can
# prove the things that only a BOOTING unit exposes, and both were written by
# the same hand that wrote the unit — the class of bug this test exists to
# catch:
#
#   1. the pool leaf is created by the mount-gated dir unit (not a tmpfiles
#      rule, which would create it BEFORE the mount and shadow the pool copy
#      on the root fs — the 9-day DAS shadow-dir incident), is owned by the
#      user the backup actually runs as, and is not world-readable
#   2. the backup unit is mount-gated AND the timer survives a reboot
#      (`Persistent`), because a host that boots after 00:30 must still get
#      the night's copy
#   3. the service serves /api/health with schedule mode enabled (the host
#      runs `schedule`, not `serve`, so a health check that only works in
#      serve mode would leave the host's Gatus probe permanently red)
#   4. THE WAL PROPERTY, measured rather than asserted in prose: a row
#      committed after the last checkpoint lives only in the `-wal` file. The
#      artifact must contain it; a plain `cp` of the main database file must
#      not. This is the whole reason the unit uses `.backup` instead of `cp`,
#      and it is invisible to any test that starts from a checkpointed file.
#   5. retention prunes by AGE (the option is days, the unit uses `-mtime`),
#      not by count — a reader who set 30 expecting 30 files would keep a
#      thirty-day window they never asked for
{ pkgs, inputs }:
let
  # Two modules, two owners. The upstream flake module declares the option set
  # and the service + backup units; SystemNix's overlay adds the mount-gated
  # pool leaf and the integration row. Importing only the overlay evaluates
  # against options that do not exist (that is the host's arrangement too —
  # systems/evo-x2.nix imports both).
  upstreamModule = inputs.crush-daily.nixosModules.crush-daily;
  # The overlay file is a flake-parts module: a FUNCTION returning
  # `{ flake.nixosModules.crush-daily = <nixos module>; }`. Apply it to an
  # empty argument set, then select the NixOS module out of the wrapper —
  # binding both steps to names so the precedence trap (`f { }.a` parsing as
  # `f ({ }.a)`) cannot resurface.
  systemNixWrapper = (import ../modules/nixos/services/crush-daily.nix) { };
  systemNixModule = systemNixWrapper.flake.nixosModules.crush-daily;

  port = 18081;
  dataDir = "/var/lib/crush-daily";
  backupDir = "/mnt/pool/backups/crush-daily";
  db = "${dataDir}/crush-daily.db";
  serviceUser = "lars";
in
{
  name = "crush-daily";

  nodes.machine =
    { lib, config, ... }:
    {
      imports = [
        upstreamModule
        systemNixModule
        # The integration registry owns services.integration.* — declared by
        # this module unconditionally (ADR-008 fan-out shape), so the test
        # must co-import it exactly as a host does.
        (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration
        ./test-helpers.nix
        # Real mounted btrfs HDD pool (tests/shared.nix poolDiskFixture — the
        # test-cv recipe). A plain `fileSystems` entry vanishes in VM tests;
        # tmpfs would not carry the by-label mount the module orders against.
        (import ./shared.nix lib).poolDiskFixture
      ];

      system.stateVersion = "25.11";
      virtualisation.memorySize = 2048;

      # sqlite3 for the WAL probe and the artifact's quick_check: the module's
      # units carry sqlite in their own `path`, but the test script runs in the
      # shell's environment, not in a unit.
      environment.systemPackages = [ pkgs.sqlite ];

      # The module defaults to the dedicated `crush-daily` system user with
      # ProtectHome=true. The host runs as the primary user because the
      # collector reads ~/.local/share/crush/projects.json — exercise THAT
      # shape, since the ownership assertions below are meaningless for a
      # dedicated system user (which is also the state dir's own owner).
      users.users.${serviceUser} = {
        isNormalUser = true;
      };

      services.crush-daily = {
        enable = true;
        runAsUser = serviceUser;
        inherit port;
        # No LLM key exists in a sandbox, and insights would fail the config
        # validation before the server ever binds — the health endpoint and
        # the backup leg are what this test is for.
        insightsEnabled = false;
        backup = {
          enable = true;
          directory = backupDir;
          retention = 7;
        };
      };

      # Eval-level assertions on things a boot cannot reveal: the coordination
      # row is what feeds backup-coordination's freshness metric, and a row
      # pointing at the wrong directory would report a healthy backup that is
      # not the one being written.
      assertions = [
        {
          assertion =
            config.services.integration.crush-daily.backup.directory == backupDir;
          message = "integration backup row must name the configured backup directory";
        }
        {
          assertion =
            config.services.integration.crush-daily.backup.filePattern
            == "crush-daily-*.db";
          message = "integration backup row must match the artifact name the unit writes";
        }
        {
          assertion = config.services.integration.crush-daily.backup.maxAgeHours == 25;
          message = "a daily timer needs a >24h freshness ceiling or it alerts every day";
        }
      ];
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # ---- 1. The pool leaf: real mount, right owner, not world-readable ----
    machine.succeed("findmnt -n -o FSTYPE /mnt/pool | grep -q btrfs")
    machine.wait_for_unit("crush-daily-backup-dir.service")
    machine.succeed("test -d ${backupDir}")
    owner = machine.succeed("stat -c %U ${backupDir}").strip()
    assert owner == "${serviceUser}", (
      f"backup dir must be owned by the user the backup runs as, got: {owner!r}"
    )
    mode = machine.succeed("stat -c %a ${backupDir}").strip()
    assert mode == "750", f"backup dir must not be world-readable, got: {mode!r}"

    # ---- 2. Unit shape: mount gate + persistent timer ----
    unit = machine.succeed("systemctl cat crush-daily-backup.service")
    assert (
      "RequiresMountsFor=/mnt/pool" in unit
    ), "backup unit must be mount-gated (a detached pool must fail, not write to /)"
    machine.succeed('test "$(systemctl is-enabled crush-daily-backup.timer)" = enabled')
    timer = machine.succeed("systemctl cat crush-daily-backup.timer")
    assert "OnCalendar=daily" in timer, timer
    assert "Persistent=true" in timer, (
      "a non-persistent daily timer never catches up after a boot that "
      "happens after the scheduled time"
    )

    # ---- 3. schedule mode serves the health endpoint ----
    machine.wait_for_unit("crush-daily.service", timeout=180)
    machine.wait_for_open_port(${toString port}, timeout=120)
    health = machine.succeed("curl -sf http://127.0.0.1:${toString port}/api/health")
    assert '"status"' in health, f"/api/health must answer JSON, got: {health!r}"
    machine.succeed(
      "systemctl cat crush-daily.service | grep -q 'schedule --config'"
    )

    machine.succeed("test -f ${db}")

    # ---- 4. The WAL property, measured: .backup captures, cp does not ----
    # A row written by a second writer stays in the -wal file until the next
    # checkpoint, so the main database file on disk does not contain it yet.
    machine.succeed(
      "sqlite3 ${db} \"INSERT INTO events"
      " (id, event_type, aggregate_type, aggregate_id, version, occurred_at)"
      " VALUES ('vm-wal-probe', 'Probe', 'probe', 'vm', 1, '2026-11-02T00:00:00Z')\""
    )
    # Control of the control: if sqlite checkpointed on close, the probe would
    # already be in the main file and every assertion below would pass while
    # proving nothing.
    main_only = machine.succeed(
      "sqlite3 -readonly 'file:${db}?immutable=1'"
      " \"SELECT count(*) FROM events WHERE id='vm-wal-probe'\""
    ).strip()
    assert main_only == "0", (
      "the probe row reached the main database file, so this test cannot "
      f"distinguish a WAL-aware backup from a byte copy (got {main_only})"
    )

    machine.systemctl("start crush-daily-backup.service")
    artifact = machine.succeed("ls -1 ${backupDir}/crush-daily-*.db | head -1").strip()
    assert artifact.endswith(".db"), f"no backup artifact landed: {artifact!r}"
    machine.succeed(f"sqlite3 -readonly '{artifact}' 'PRAGMA quick_check;' | grep -qx ok")
    in_artifact = machine.succeed(
      f"sqlite3 -readonly '{artifact}' \"SELECT count(*) FROM events WHERE id='vm-wal-probe'\""
    ).strip()
    assert in_artifact == "1", (
      f"the artifact lost the WAL-resident row (count {in_artifact}) — the unit "
      "is copying pages instead of using the online backup API"
    )
    # And the naive alternative, run for real: a byte copy of the main file
    # must NOT contain it. This is the regression the runbook describes; a
    # future "simplify the unit to cp" would show up here as a lost night.
    machine.succeed("cp ${db} /tmp/naive-copy.db")
    naive = machine.succeed(
      "sqlite3 -readonly /tmp/naive-copy.db"
      " \"SELECT count(*) FROM events WHERE id='vm-wal-probe'\""
    ).strip()
    assert naive == "0", (
      "a plain copy contained the WAL-resident row — the fixture is not "
      "exercising the WAL, so the assertion above proves nothing"
    )

    # ---- 5. Retention prunes by age, keeps what is inside the window ----
    # Both fixtures are dated RELATIVE to the VM clock. Hardcoded epochs are a
    # trap: a "this year" timestamp is already outside a 7-day window by
    # November and the test then asserts the opposite of what it means.
    stale = "${backupDir}/crush-daily-20200101_000000.db"
    fresh = "${backupDir}/crush-daily-20200102_000000.db"
    machine.succeed(f"cp '{artifact}' {stale} && touch -d '30 days ago' {stale}")
    machine.succeed(f"cp '{artifact}' {fresh} && touch -d '3 days ago' {fresh}")
    machine.sleep(1)  # distinct timestamp for the second artifact
    machine.systemctl("start crush-daily-backup.service")
    machine.fail(f"test -f {stale}")
    machine.succeed(f"test -f {fresh}")
    machine.succeed(f"test -f '{artifact}'")
    count = machine.succeed("ls -1 ${backupDir}/crush-daily-*.db | wc -l").strip()
    assert int(count) == 3, (
      f"expected 3 artifacts (original, today's second run, the in-window "
      f"fresh one), got {count}"
    )

    # No half-written file may look like a backup: the unit writes to a
    # `.tmp` name and only renames after quick_check passes.
    machine.fail("ls ${backupDir}/.crush-daily-*.tmp")
  '';
}
