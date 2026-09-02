# VM test: linger + SDDM login → exactly one niri, none pre-login.
#
# The runtime half of the 2026-08-18 black-screen guard. session-boot-audit
# (eval time) proves nothing reachable from default.target PULLS
# graphical-session.target; THIS test boots the shape for real:
#
#   1. alice lingers → her user manager boots BEFORE any login
#   2. a boot-reachable user unit in the exact incident shape (the
#      aw-watcher gate-wrapper pattern: default.target + waits for the
#      compositor socket, deliberately NO Wants=graphical-session.target)
#      runs through the whole boot
#   3. with the greeter up and the lingering manager fully started,
#      NO niri process may exist (a headless zombie niri blocks the next
#      SDDM login with "A niri session is already running")
#   4. a real SDDM login spawns EXACTLY ONE niri
#
# Scope note: the full evo-x2 stack (niri-flake HM module, DMS, the
# XDG_SESSION_ID condition on niri.service) is deliberately NOT replicated —
# this test pins the generic systemd behavior the incident abused, using the
# nixpkgs niri module. The login is driven through the real SDDM greeter via
# OCR (same pattern as nixpkgs' own sddm test).
{
  pkgs,
}:
{
  name = "niri-session";
  meta.maintainers = [ ];

  nodes.machine =
    { ... }:
    {
      virtualisation = {
        memorySize = 2048;
        # Graphical output for SDDM + niri (virtio-gpu, llvmpipe rendering)
        qemu.options = [ "-vga std" ];
      };

      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
        password = "alice";
        # The point of the test: alice's user manager must boot pre-login
        linger = true;
      };

      services = {
        xserver.enable = true; # X11 greeter (nixpkgs sddm-test pattern)
        displayManager = {
          sddm.enable = true;
          defaultSession = "niri";
        };
      };

      programs.niri.enable = true;

      # Boot-reachable user unit in the exact aw-watcher gate shape: enabled
      # via default.target (so the lingering boot transaction starts it),
      # waits for the compositor socket instead of pulling
      # graphical-session.target. Adding Wants=graphical-session.target here
      # would be the 2026-08-18 bug — session-boot-audit blocks that shape at
      # eval time; this test proves the LEGAL shape stays zombie-free at
      # runtime.
      systemd.user.services.niri-session-gate-test = {
        description = "Linger boot canary: wait for compositor socket (aw-watcher gate shape)";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.writeShellScript "niri-session-gate-test" ''
            while true; do
              for candidate in "''${XDG_RUNTIME_DIR:-/run/user/1000}"/wayland-[0-9]; do
                [ -S "$candidate" ] && sleep infinity
              done
              sleep 1
            done
          ''}";
          Restart = "always";
          RestartSec = "5s";
        };
        unitConfig = {
          StartLimitBurst = 5;
          StartLimitIntervalSec = 300;
        };
      };

      # The test drives the SDDM greeter via OCR (nixpkgs sddm-test pattern);
      # enableOCR is set at the top level of the test spec.

      system.stateVersion = "25.11";
    };

  enableOCR = true;

  testScript = ''
    start_all()

    # 1. Linger: alice's user manager must be up WITHOUT any login
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")
    machine.wait_for_unit("niri-session-gate-test.service", "alice")

    # 2. Greeter ready = pre-login steady state reached
    machine.wait_until_succeeds("pgrep sddm-greeter", timeout=120)

    # 3. THE assertion: no headless zombie niri before login
    machine.fail("pgrep -x niri")

    # 4. Real SDDM login via the greeter
    machine.wait_for_text("(?i)select your user", timeout=120)
    machine.send_chars("alice\n")

    machine.wait_until_succeeds("pgrep -x niri", timeout=120)

    # 5. EXACTLY one niri — a lingering zombie would either block the login
    #    (niri exits "A niri session is already running") or stack a second
    #    compositor
    machine.succeed("test $(pgrep -xc niri) -eq 1")

    # 6. The session is a real graphical login
    machine.wait_until_succeeds("loginctl list-sessions --no-legend | grep -q alice", timeout=60)

    # 7. The gate canary saw the compositor socket (the legal ordering works:
    #    socket-wait, never Wants=graphical-session.target)
    machine.succeed("test -S /run/user/1000/wayland-0 || test -S /run/user/1000/wayland-1")
  '';
}
