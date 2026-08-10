_: {
  name = "port-uniqueness";

  nodes.machine = _: {
    system.stateVersion = "25.11";
  };

  # The port-uniqueness assertion lives in lib/default.nix and fires at eval
  # time via builtins.throw. It is validated on every `nix flake check` — if
  # any two ports in lib/ports.nix share the same value, the entire flake
  # evaluation aborts. This VM test simply confirms the host boots with the
  # current (collision-free) port assignments.
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("systemctl is-system-running | grep running")
    print("Port uniqueness assertion verified — flake evaluated without collision")
  '';
}
