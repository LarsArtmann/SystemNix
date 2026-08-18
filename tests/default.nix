{
  pkgs,
  inputs,
  system,
  ...
}:
let
  # Modern NixOS test runner — replaces the deprecated make-test-python.nix.
  # Same { nodes, testScript, name } shape, cleaner API.
  makeTest = testSpec: pkgs.testers.runNixOSTest testSpec;
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

  attic = makeTest (import ./test-attic.nix { inherit pkgs; });
  searxng = makeTest (import ./test-searxng.nix { inherit pkgs; });
  caddy-auth-patterns = makeTest (import ./test-caddy-auth.nix { inherit pkgs; });
  gatus-patterns = makeTest (import ./test-gatus-patterns.nix { inherit pkgs; });
  pma-identity = makeTest (import ./test-pma-identity.nix { inherit pkgs; });
  ksm = makeTest (import ./test-ksm.nix { inherit pkgs; });
  port-uniqueness = makeTest (import ./test-port-uniqueness.nix { inherit pkgs; });
  browser-history = makeTest (import ./test-browser-history.nix { inherit pkgs inputs; });
  paperless = makeTest (import ./test-paperless.nix { inherit pkgs; });
  session-boot-audit = import ./test-session-boot-audit.nix { inherit pkgs inputs system; };
}
// (import ./test-scripts.nix { inherit pkgs; })
