# VM test for the WiFi standby failover route guard.
#
# Regression for the 2026-09-06 "cable pulled, WiFi connected, NO internet"
# class: kernel routes are NOT removed on carrier loss (only on admin down),
# so the static metric-0 eno1 default blackholes ALL traffic while the
# NetworkManager fallback route (metric 100) sits unused. Exercises the REAL
# daemon (the deployed ExecStart binary) against a veth pair — the PEER's
# admin state simulates cable carrier:
#   peer up   -> ethfail carrier 1 (cable in)
#   peer down -> ethfail NO-CARRIER, still admin-up (cable out) — exactly the
#                state where the kernel keeps the pinned route and the naive
#                assumption "unplugging removes the route" fails.
#
# Scenarios:
#   1. Missing interface at boot: unit starts and STAYS active (tolerant loop).
#   2. Cable in: metric-0 default via ethfail present, metric-100 standby
#      route present (production topology mirrored: primary metric 0 beats
#      standby metric 100).
#   3. Cable out (peer down, route intact): daemon deletes ONLY the pinned
#      ethfail default; the metric-100 standby is untouched and now serves.
#   4. Cable back (peer up): daemon re-adds the metric-0 primary.
#   5. Unit survives everything: still active, journal carries FAILOVER and
#      RESTORE markers.
{ ... }:
{
  name = "wifi-failover";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        # flake-parts wrapper (top-level lambda) — apply, then pull the
        # NixOS module out of the flake.nixosModules option it declares.
        ((import ../modules/nixos/services/wifi-failover.nix) { }).flake.nixosModules.wifi-failover
        # The module reads config.networking.local.gateway (SystemNix-specific
        # option, normally provided by platforms/nixos/system/local-network.nix).
        (import ../platforms/nixos/system/local-network.nix)
      ];

      services.wifi-failover = {
        enable = true;
        ethernetInterface = "ethfail";
        fallbackInterface = "wlanfail";
        pollIntervalSeconds = 1;
      };
      # Poll-level debug lines into the journal — the test asserts on them.
      systemd.services.wifi-failover.environment.DEBUG_POLL = "1";
      networking.local.gateway = lib.mkForce "10.99.0.1";
    };

  testScript = ''
    start_all()

    # --- Scenario 1: unit tolerates the missing ethfail interface at boot ---
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("wifi-failover.service")
    machine.succeed("systemctl is-active wifi-failover.service")

    # --- Wire the production topology: ethfail (primary) + wlanfail (NM
    #     fallback standby). Create the veth DOWN so the daemon sees carrier 0
    #     while we lay addresses and routes — deterministic, no startup race. ---
    machine.succeed("ip link add ethfail type veth peer name ethpeer")
    machine.succeed("ip link add wlanfail type dummy")
    machine.succeed("ip link set ethfail up")
    machine.succeed("ip link set wlanfail up")
    machine.succeed("ip addr add 10.99.0.2/24 dev ethfail")
    machine.succeed("ip addr add 10.99.1.2/24 dev wlanfail")

    # Static metric-0 primary (as networking.interfaces would install it) +
    # metric-100 NM fallback standby. The qemu default (metric 0) must go —
    # in production nothing else holds metric 0, and the test driver's traffic
    # rides the on-link 10.0.2.0/24 route, not the default.
    machine.succeed("ip route del default || true")
    machine.succeed("ip route add default via 10.99.0.1 dev ethfail")
    machine.succeed("ip route add default via 10.99.1.1 dev wlanfail metric 100")

    # --- Scenario 2: cable in — both routes present, primary wins ---
    machine.succeed("ip link set ethpeer up")
    machine.wait_until_succeeds(
        "ip -4 route show default | grep -q 'via 10.99.1.1 dev wlanfail metric 100'"
    )
    machine.succeed("ip -4 route show default | grep -q 'dev ethfail'")
    # The daemon must have OBSERVED the carrier transition (this is what makes
    # scenario 3 work — without a seen 'up', the down transition is not armed).
    machine.wait_until_succeeds(
        "journalctl -u wifi-failover --no-pager -o cat | grep -q 'carrier UP'"
    )
    primary_first = machine.succeed("ip -4 route show default | head -1").strip()
    assert "dev ethfail" in primary_first, f"primary route must sort first, got: {primary_first}"

    # --- Scenario 3: cable out (peer down -> NO-CARRIER, admin stays up).
    #     The kernel KEEPS the metric-0 route; the daemon must evict it and
    #     leave the standby intact. ---
    print(
        "DEBUG: ethfail carrier file -> ",
        machine.execute("cat /sys/class/net/ethfail/carrier; ip link show ethfail | head -2")[1],
    )
    print(
        "DEBUG: daemon journal tail -> ",
        machine.execute("journalctl -u wifi-failover --no-pager -n 15 -o cat")[1],
    )
    machine.succeed("ip link set ethpeer down")
    machine.wait_until_succeeds(
        "! ip -4 route show default | grep -q 'dev ethfail'"
    )
    machine.succeed(
        "ip -4 route show default | grep -q 'via 10.99.1.1 dev wlanfail metric 100'"
    )
    active = machine.succeed("ip -4 route show default").strip()
    assert "wlanfail" in active, f"standby route must remain active, got: {active}"

    # --- Scenario 4: cable back — primary re-added, beats the standby again ---
    machine.succeed("ip link set ethpeer up")
    machine.wait_until_succeeds(
        "ip -4 route show default | grep -q 'dev ethfail'"
    )
    primary_back = machine.succeed("ip -4 route show default | head -1").strip()
    assert "dev ethfail" in primary_back, f"primary must be restored first, got: {primary_back}"

    # --- Scenario 5: daemon never died; journal has both markers ---
    machine.succeed("systemctl is-active wifi-failover.service")
    machine.succeed("journalctl -u wifi-failover.service | grep -q 'FAILOVER: carrier lost'")
    machine.succeed("journalctl -u wifi-failover.service | grep -q 'RESTORE: carrier back'")
  '';
}
