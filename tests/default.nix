{
  pkgs,
  lib,
  nixpkgs,
  system,
}: let
  makeTest = testSpec:
    import "${nixpkgs}/nixos/tests/make-test-python.nix"
    testSpec
    {inherit system;};
in {
  boot = makeTest {
    name = "boot";

    nodes.machine = {pkgs, ...}: {
      system.stateVersion = "25.11";
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("systemctl is-system-running | grep running")
    '';
  };

  dns-blocking = makeTest {
    name = "dns-blocking";

    nodes.machine = {pkgs, ...}: {
      services.unbound = {
        enable = true;
        resolveLocalQueries = true;
        settings = {
          server = {
            interface = ["0.0.0.0"];
            do-ip6 = false;
            access-control = ["0.0.0.0/0 allow"];
            local-zone = [
              ''"ads.example.com." always_nxdomain''
              ''"tracker.example.com." always_nxdomain''
              ''"allowed.example.com." transparent''
            ];
          };
          forward-zone = [
            {
              name = ".";
              forward-addr = "9.9.9.9";
            }
          ];
        };
      };
      environment.systemPackages = [pkgs.dnsutils];
      system.stateVersion = "25.11";
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("unbound.service")
      machine.wait_for_open_port(53)
      machine.succeed("dig ads.example.com @127.0.0.1 | grep 'status: NXDOMAIN'")
      machine.succeed("dig tracker.example.com @127.0.0.1 | grep 'status: NXDOMAIN'")
    '';
  };
}
