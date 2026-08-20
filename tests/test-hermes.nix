# VM test for the Hermes module's projects-access plumbing.
#
# The upstream gateway itself needs Discord credentials and platform
# connectivity — out of scope here. What this test locks down is everything
# the SystemNix module adds AROUND it:
#   1. Read-only projects bind is mounted inside the unit's namespace and
#      enforced (writes EROFS, even for root; the writable workspace beside
#      it still works)
#   2. GIT_CONFIG_GLOBAL / TERMINAL_CWD / HERMES_WRITE_SAFE_ROOT ship in the
#      unit environment, and the gitconfig actually un-breaks git on the
#      foreign-owned repos through the bind (negative control proves the env
#      var is load-bearing)
#   3. projectsDir = null (default) ships NO bind and NO env — no
#      half-configured surface
#   4. acl-revoke removes a stale grant exactly once, then is a no-op
#   5. D1 regression: stateDir permission drift + the RO bind present must
#      NOT crash-loop the ExecStartPre permission walk (the 2026-08-20
#      chown-vs-bind EROFS landmine)
#
# The gateway is replaced by `sleep infinity` via mkForce so the unit runs
# its full ExecStartPre chain and holds its mount namespace open for
# nsenter-based assertions.
{
  pkgs,
  inputs,
}:
let
  hermesFlakeOutput = (import ../modules/nixos/services/hermes.nix) {
    inherit inputs;
  };
  hermesNixosModule = hermesFlakeOutput.flake.nixosModules.hermes;

  common =
    { lib, ... }:
    {
      imports = [
        hermesNixosModule
        ./mock-sops.nix
        ./test-helpers.nix
      ];

      # mock-sops provides the sops.templates OPTION, but nothing renders
      # the file. The unit's EnvironmentFile is unprefixed, so a missing
      # file would fail the unit before any assertion runs.
      systemd.tmpfiles.rules = [
        "f /run/secrets-rendered/hermes-env 0400 root root -"
      ];

      users.users.testuser = {
        isNormalUser = true;
        password = "test";
      };

      environment.systemPackages = [
        pkgs.git
        pkgs.acl
      ];

      systemd.services.hermes.serviceConfig.ExecStart =
        lib.mkForce "${pkgs.coreutils}/bin/sleep infinity";
    };
in
{
  name = "hermes";

  nodes = {
    bound =
      { ... }:
      {
        imports = [ common ];

        services.hermes = {
          enable = true;
          projectsDir = "/home/testuser/projects";
        };

        # Pre-create the bind SOURCE so the unprefixed BindReadOnlyPaths
        # cannot fail at boot; content is seeded after the unit is up (a
        # bind of a directory is a live view — no restart needed).
        systemd.tmpfiles.rules = [
          "d /home/testuser/projects 0755 testuser users - -"
        ];
      };

    bare =
      { ... }:
      {
        imports = [ common ];

        services.hermes.enable = true;
      };
  };

  testScript = ''
      def unit_env(machine):
          return machine.succeed("systemctl show hermes -p Environment")

      def main_pid(machine):
          return machine.succeed("systemctl show hermes -p MainPID --value").strip()


      # --- bound node: the full projects-access surface -------------------
      bound.start()
      bound.wait_for_unit("hermes.service")

      # 2. env vars present
      env = unit_env(bound)
      assert "TERMINAL_CWD=/home/hermes/workspace" in env, f"TERMINAL_CWD missing: {env}"
      assert "HERMES_WRITE_SAFE_ROOT=/home/hermes" in env, f"HERMES_WRITE_SAFE_ROOT missing: {env}"
      gitcfg = [kv for kv in env.split() if kv.startswith("GIT_CONFIG_GLOBAL=")]
      assert gitcfg, f"GIT_CONFIG_GLOBAL missing: {env}"
      gitcfg = gitcfg[0].split("=", 1)[1]

      # 1. bind mounted read-only in the unit's namespace
      pid = main_pid(bound)
      bound.succeed(f"nsenter -m -t {pid} cat /proc/self/mountinfo | grep ' /home/hermes/workspace/projects ro,'")

      # Seed a foreign-owned repo through the live bind view
      bound.succeed("runuser -u testuser -- env HOME=/home/testuser git init -q /home/testuser/projects/demo")
      bound.succeed(
          "runuser -u testuser -- env HOME=/home/testuser git -C /home/testuser/projects/demo -c user.email=seed@test.local -c user.name=seed commit -q --allow-empty -m seed"
      )

      # 1. writes through the namespace are EROFS — even for root
      bound.fail(f"nsenter -m -t {pid} touch /home/hermes/workspace/projects/demo/evil")
      bound.succeed(f"nsenter -m -t {pid} test ! -e /home/hermes/workspace/projects/demo/evil")
      # positive control: the workspace beside the bind stays writable
      bound.succeed(f"nsenter -m -t {pid} sh -c 'touch /home/hermes/workspace/writetest && rm /home/hermes/workspace/writetest'")

      # 2. git works on the foreign-owned repo through the bind WITH the
      #    deployed gitconfig; fails without it (env var is load-bearing)
      bound.succeed(
          f"nsenter -m -t {pid} runuser -u hermes -- /bin/sh -c 'HOME=/home/hermes GIT_CONFIG_GLOBAL={gitcfg} git -C /home/hermes/workspace/projects/demo log --oneline -1'"
      )
      bound.fail(
          f"nsenter -m -t {pid} runuser -u hermes -- /bin/sh -c 'HOME=/home/hermes git -C /home/hermes/workspace/projects/demo log --oneline -1'"
      )

      # 4. acl-revoke: removes a stale grant exactly once, then no-op
      bound.succeed("setfacl -m g:hermes:r-x /home/testuser")
      bound.systemctl("restart hermes")
      bound.wait_for_unit("hermes.service")
      assert bound.succeed("journalctl -u hermes --no-pager | grep -c 'removed stale g:hermes ACL' || true").strip() == "1"
      bound.systemctl("restart hermes")
      bound.wait_for_unit("hermes.service")
      assert bound.succeed("journalctl -u hermes --no-pager | grep -c 'removed stale g:hermes ACL' || true").strip() == "1"

      # 5. D1 regression: stateDir perm drift + RO bind present must NOT
      #    crash the permission walk (old code: chown -R EROFS -> start-limit)
      bound.succeed("chmod 0755 /home/hermes")
      bound.systemctl("restart hermes")
      bound.wait_for_unit("hermes.service")
      # the guard tripped and the walk actually ran...
      assert bound.succeed("journalctl -u hermes --no-pager | grep -c 'hermes-perms: fixing ownership' || true").strip() == "1"
      # ...without crossing into the read-only bind
      assert bound.succeed("journalctl -u hermes --no-pager | grep -c 'Read-only file system' || true").strip() == "0"

      # --- bare node: projectsDir = null => no bind, no env ---------------
      bare.start()
      bare.wait_for_unit("hermes.service")

      env = unit_env(bare)
      assert "TERMINAL_CWD=" not in env, f"TERMINAL_CWD shipped without projectsDir: {env}"
      assert "HERMES_WRITE_SAFE_ROOT=" not in env, f"HERMES_WRITE_SAFE_ROOT shipped without projectsDir: {env}"
      assert "GIT_CONFIG_GLOBAL=" not in env, f"GIT_CONFIG_GLOBAL shipped without projectsDir: {env}"

      pid = main_pid(bare)
      bare.succeed(f"! nsenter -m -t {pid} cat /proc/self/mountinfo | grep ' /home/hermes/workspace/projects '")
      bare.succeed("test ! -e /home/hermes/workspace/projects")
    '';
}
