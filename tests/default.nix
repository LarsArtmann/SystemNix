{
  nixpkgs,
  system,
}:
let
  makeTest =
    testSpec: import "${nixpkgs}/nixos/tests/make-test-python.nix" testSpec { inherit system; };
in
{
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
}
