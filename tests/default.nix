{pkgs, ...}: let
  # Modern NixOS test runner — replaces the deprecated make-test-python.nix.
  # Same { nodes, testScript, name } shape, cleaner API.
  makeTest = testSpec: pkgs.testers.runNixOSTest testSpec;
in {
  boot = makeTest {
    name = "boot";

    nodes.machine = _: {
      system.stateVersion = "25.11";
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("systemctl is-system-running | grep running")
    '';
  };

  attic = makeTest (import ./test-attic.nix {inherit pkgs;});
  searxng = makeTest (import ./test-searxng.nix {inherit pkgs;});
}
