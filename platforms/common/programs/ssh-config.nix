{
  pkgs,
  lib,
  config,
  ...
}: let
  sd = import ../../../lib/default.nix lib;
  socketsDir = "${config.home.homeDirectory}/.ssh/sockets";

  # Removes SSH control-master sockets whose owning process has died (OOM,
  # suspend, forced logout). A live master accepts connections on its socket;
  # a dead one leaves an orphaned socket file that SSH refuses to reuse,
  # printing "ControlSocket ... already exists, disabling multiplexing" on
  # every git-over-ssh invocation. We probe each socket: if connect() is
  # refused the master is gone and the file is unlinked.
  ssh-socket-cleanup = pkgs.writeShellApplication {
    name = "ssh-socket-cleanup";
    runtimeInputs = [pkgs.python3];
    text = ''
      python3 - "$1" <<'PYEOF'
      import os, socket, stat, sys

      d = sys.argv[1]
      os.makedirs(d, mode=0o700, exist_ok=True)

      checked = removed = 0
      for name in os.listdir(d):
          path = os.path.join(d, name)
          try:
              mode = os.stat(path).st_mode
          except OSError:
              continue
          if not stat.S_ISSOCK(mode):
              continue
          checked += 1
          s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
          s.settimeout(1)
          try:
              s.connect(path)  # live master still listening
              s.close()
              continue
          except OSError:
              pass  # ECONNREFUSED / timed out → stale
          try:
              os.unlink(path)
              removed += 1
          except OSError:
              pass

      print(f"ssh-socket-cleanup: checked {checked}, removed {removed} stale socket(s)")
      PYEOF
    '';
  };
in {
  ssh-config = {
    enable = true;
    user = "lars";
    hosts = {
      onprem = {
        hostname = "192.168.1.100";
        user = "root";
      };
      "evo-x2" = {
        hostname = "192.168.1.150";
        user = "lars";
        serverAliveInterval = 60;
        serverAliveCountMax = 3;
        extraOptions = {
          TCPKeepAlive = "yes";
        };
      };
      "private-cloud-hetzner-0" = {
        hostname = "37.27.217.205";
        user = "root";
      };
      "private-cloud-hetzner-1" = {
        hostname = "37.27.195.171";
        user = "root";
      };
      "private-cloud-hetzner-2" = {
        hostname = "37.27.24.111";
        user = "root";
      };
      "private-cloud-hetzner-3" = {
        hostname = "138.201.155.93";
        user = "root";
      };
    };
  };

  # Ensure the ControlPath target exists before SSH tries to spawn a master.
  home.activation.ssh-sockets-dir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p "${socketsDir}"
    $DRY_RUN_CMD chmod 700 "${socketsDir}"
  '';

  # Self-heal orphaned control-master sockets (Linux only — no systemd on Darwin).
  systemd.user = lib.optionalAttrs pkgs.stdenv.isLinux {
    services.ssh-socket-cleanup = {
      Unit.Description = "Remove stale SSH control-master sockets";
      Service =
        sd.hardenUser {}
        // sd.serviceOneshotDefaultsUser {}
        // {
          Type = "oneshot";
          ExecStart = "${lib.getExe ssh-socket-cleanup} ${socketsDir}";
        };
    };

    timers.ssh-socket-cleanup = {
      Unit.Description = "Periodically prune stale SSH control-master sockets";
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
        Persistent = lib.mkForce true;
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
