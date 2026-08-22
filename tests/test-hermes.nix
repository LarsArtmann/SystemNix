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
#   6. LSP bin heal: stripped binaries under lsp/bin get their exec bit
#      back; the perms walk is exec-PRESERVING (0755 files stay executable,
#      plain files still converge to group-readable)
#   7. workspace AGENTS.md v2: marker-based — agent edits survive restarts
#      within a version, v1 files upgrade to v2 (old content replaced)
#   8. hermes-github-verify: skip-cleanly when the token env is unset;
#      unit absent on the bare node (projectsDir = null)
#   9. ~/.ssh perms converge: the exec-preserving walk prunes ~/.ssh and
#      a dedicated converge heals group-writable ssh config on EVERY
#      restart (OpenSSH 'Bad owner or permissions', live 2026-08-21) —
#      both on the full-walk path and on the fast-path exit
#
# The gateway is replaced by `sleep infinity` via mkForce so the unit runs
# its full ExecStartPre chain and holds its mount namespace open for
# nsenter-based assertions.
{
  pkgs,
  inputs,
}: let
  hermesFlakeOutput = (import ../modules/nixos/services/hermes.nix) {
    inherit inputs;
  };
  hermesNixosModule = hermesFlakeOutput.flake.nixosModules.hermes;

  common = {lib, ...}: {
    imports = [
      hermesNixosModule
      ./mock-sops.nix
      ./test-helpers.nix
    ];

    # mock-sops provides the sops.templates OPTION, but the module reads
    # templates."hermes-env".path, which must EXIST (on the real host a
    # secrets module defines it). Mock it and create the rendered file:
    # the unit's EnvironmentFile is unprefixed, so a missing file would
    # fail the unit before any assertion runs.
    sops.templates."hermes-env" = {
      content = "HERMES_VM_TEST=1";
      path = "/run/secrets-rendered/hermes-env";
    };
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

    # The module's startLimitBurst=5/600s counts SUCCESSFUL restarts too;
    # this test restarts hermes 7x in under a minute to exercise
    # ExecStartPre idempotency, tripping the rate limiter from restart #6
    # on. The limiter itself is not under test here.
    systemd.services.hermes.startLimitBurst = lib.mkForce 20;
  };
in {
  name = "hermes";

  nodes = {
    bound = {...}: {
      imports = [common];

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

      # The github-verify DNS gate (getent hosts github.com) must pass
      # deterministically: inside the sandboxed nix build, slirp host-side
      # DNS is not guaranteed. /etc/hosts resolves it without network; the
      # verify script hits the unset-token skip branch before any git use.
      test-helpers.dnsGateHosts = ["github.com"];
    };

    bare = {...}: {
      imports = [common];

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

    # 6. LSP heal + exec-preserving walk. Seed a STRIPPED binary (the exact
    #    state the old chmod 0660 walk left behind since 2026-08-16) and an
    #    executable tool; the next walk-triggering restart must heal the
    #    first and preserve the second while still normalizing plain files.
    bound.succeed(
        "runuser -u hermes -- sh -c 'mkdir -p /home/hermes/lsp/bin /home/hermes/lsp/node_modules/.bin && printf shebang > /home/hermes/lsp/bin/pyright-langserver && chmod 0644 /home/hermes/lsp/bin/pyright-langserver && printf shebang > /home/hermes/tool.sh && chmod 0755 /home/hermes/tool.sh && printf data > /home/hermes/plain.txt && chmod 0600 /home/hermes/plain.txt'"
    )
    bound.succeed("chmod 0755 /home/hermes")
    bound.systemctl("restart hermes")
    bound.wait_for_unit("hermes.service")
    bound.succeed("test -x /home/hermes/lsp/bin/pyright-langserver")
    assert bound.succeed("journalctl -u hermes --no-pager | grep -c 'restored execute bit on 1 LSP binaries' || true").strip() == "1"
    bound.succeed("test -x /home/hermes/tool.sh")
    assert bound.succeed("stat -c %a /home/hermes/plain.txt").strip() == "660"
    # second restart: heal is idempotent (no repeat journal line)
    bound.systemctl("restart hermes")
    bound.wait_for_unit("hermes.service")
    assert bound.succeed("journalctl -u hermes --no-pager | grep -c 'restored execute bit on' || true").strip() == "1"

    # 6b. ssh perms converge (regression: live 2026-08-21 'Bad owner or
    #     permissions on /home/hermes/.ssh/config'). The old walk made
    #     agent-created ssh config 0660 group-writable; OpenSSH refuses
    #     such files. Case A: drift stateDir AND .ssh -> the FULL walk
    #     runs and must leave .ssh owner-only (prune + final converge).
    bound.succeed(
        "runuser -u hermes -- sh -c 'mkdir -p /home/hermes/.ssh && printf sshcfg > /home/hermes/.ssh/config && chmod 2770 /home/hermes/.ssh && chmod 0660 /home/hermes/.ssh/config'"
    )
    bound.succeed("chmod 0755 /home/hermes")
    bound.systemctl("restart hermes")
    bound.wait_for_unit("hermes.service")
    assert bound.succeed("stat -c %a /home/hermes/.ssh/config").strip() == "600"
    assert bound.succeed("stat -c %a /home/hermes/.ssh").strip() == "700"
    # Case B: stateDir healthy -> fast-path exit; .ssh drift alone must
    # still converge (the exact live-host scenario)
    bound.succeed("chmod 0660 /home/hermes/.ssh/config")
    bound.systemctl("restart hermes")
    bound.wait_for_unit("hermes.service")
    assert bound.succeed("stat -c %a /home/hermes/.ssh/config").strip() == "600"

    # 7. workspace AGENTS.md v2: marker on line 1; agent edits survive
    #    restarts within a version; a v1 marker upgrades (content replaced)
    doc = "/home/hermes/workspace/AGENTS.md"
    bound.succeed(f"head -1 {doc} | grep -q 'systemnix-workspace-doc: v2'")
    bound.succeed(f"runuser -u hermes -- sh -c 'echo agent-note >> {doc}'")
    bound.systemctl("restart hermes")
    bound.wait_for_unit("hermes.service")
    bound.succeed(f"grep -q agent-note {doc}")
    bound.succeed("journalctl -u hermes --no-pager | grep -q 'AGENTS.md present (v2, agent edits preserved)'")
    bound.succeed(f"sed -i '1s/v2/v1/' {doc}")
    bound.systemctl("restart hermes")
    bound.wait_for_unit("hermes.service")
    bound.succeed(f"head -1 {doc} | grep -q 'systemnix-workspace-doc: v2'")
    bound.succeed(f"! grep -q agent-note {doc}")
    bound.succeed("journalctl -u hermes --no-pager | grep -q 'upgraded AGENTS.md v1 -> v2'")

    # 7b. marker-less migration (the live-host case: doc installed by the
    #     OLD once-only script has no version line). Byte-equal to the
    #     shipped v1 => upgrade; agent-modified => untouched.
    v1 = bound.succeed(
        "grep -hoP '/nix/store/[a-z0-9]+-hermes-workspace-AGENTS-v1\.md' /nix/store/*hermes-workspace-doc*/bin/hermes-workspace-doc | head -1"
    ).strip()
    assert v1, "v1 doc store path not found in the install script"
    bound.succeed(f"cat {v1} > {doc}")
    bound.systemctl("restart hermes")
    bound.wait_for_unit("hermes.service")
    bound.succeed(f"head -1 {doc} | grep -q 'systemnix-workspace-doc: v2'")
    bound.succeed("journalctl -u hermes --no-pager | grep -q 'upgraded marker-less AGENTS.md (was unmodified v1)'")
    bound.succeed(f"printf 'agent rewrote this\n' > {doc}")
    bound.systemctl("restart hermes")
    bound.wait_for_unit("hermes.service")
    bound.succeed(f"grep -q 'agent rewrote this' {doc}")
    bound.succeed("journalctl -u hermes --no-pager | grep -q 'AGENTS.md present (agent-rewritten header, untouched)'")

    # 8. hermes-github-verify: token env unset in the VM -> skip cleanly
    bound.succeed("systemctl show hermes-github-verify -p Result --value | grep -q success")
    bound.succeed("journalctl -u hermes-github-verify --no-pager | grep -q 'skipping private-repo auth canary'")

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

    # verify unit is projectsDir-gated: absent on the bare node
    bare.fail("systemctl cat hermes-github-verify.service")
  '';
}
