# Follow newly opened niri windows: focus windows that niri placed on a
# different workspace/monitor (e.g. via open-on-workspace window rules),
# so launching an app from the DMS spotlight takes you there.
_: {
  flake.nixosModules.focus-new-windows = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.focus-new-windows;
    inherit (import ../../../lib/default.nix lib) hardenUser;

    focus-new-windows-daemon = pkgs.writeScriptBin "focus-new-windows-daemon" ''
      #!${pkgs.python3.interpreter}
      import json
      import os
      import re
      import subprocess
      import sys
      import time

      GRACE_SEC = float(os.environ.get("FOCUS_NEW_WINDOWS_GRACE", "10"))

      try:
          SKIP_APP_IDS = [
              re.compile(p)
              for p in json.loads(os.environ.get("FOCUS_NEW_WINDOWS_SKIP", "[]"))
          ]
      except (json.JSONDecodeError, re.error) as exc:
          print(f"[focus-new-windows] FATAL: invalid skip config: {exc}", file=sys.stderr)
          sys.exit(1)

      def log(msg):
          print(f"[focus-new-windows] {msg}", flush=True)

      def find_niri_socket():
          sock = os.environ.get("NIRI_SOCKET", "")
          if sock and os.path.exists(sock):
              return sock
          runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
          try:
              for f in os.listdir(runtime):
                  if f.startswith("niri.") and f.endswith(".sock"):
                      return os.path.join(runtime, f)
          except OSError:
              pass
          return None

      def is_skipped(app_id):
          return any(p.search(app_id or "") for p in SKIP_APP_IDS)

      def on_open(window, in_grace):
          """A window we have not seen before was just opened."""
          wid = window.get("id")
          if wid is None:
              return
          app_id = window.get("app_id") or ""
          if in_grace:
              log(f"grace: not following window {wid} ({app_id})")
              return
          if window.get("is_focused"):
              # niri already focused it (opened on the active workspace).
              return
          if is_skipped(app_id):
              log(f"skip: window {wid} ({app_id}) matches skip list")
              return
          log(f"following window {wid} ({app_id})")
          subprocess.run(
              ["niri", "msg", "action", "focus-window", "--id", str(wid)],
              check=False,
          )

      def main():
          sock = find_niri_socket()
          if not sock:
              log("FATAL: niri socket not found — is niri running?")
              sys.exit(1)
          os.environ["NIRI_SOCKET"] = sock

          started = time.monotonic()

          # WindowOpenedOrChanged fires for new windows AND updates to
          # existing ones (title changes etc.). Only windows whose id we
          # have not seen before count as "opened".
          known = set()

          log(f"Started (grace={GRACE_SEC}s, skip={[p.pattern for p in SKIP_APP_IDS]})")

          proc = subprocess.Popen(
              ["niri", "msg", "--json", "event-stream"],
              stdout=subprocess.PIPE,
              stderr=subprocess.PIPE,
              text=True,
          )

          for line in proc.stdout:
              line = line.strip()
              if not line:
                  continue
              try:
                  event = json.loads(line)
              except json.JSONDecodeError:
                  continue

              etype = next(iter(event), None)

              if etype == "WindowsChanged":
                  # Complete state snapshot (sent up-front on connect).
                  # Never focus these: they predate the daemon.
                  known = {
                      w.get("id")
                      for w in event.get("WindowsChanged", {}).get("windows", [])
                      if w.get("id") is not None
                  }
              elif etype == "WindowOpenedOrChanged":
                  window = event.get("WindowOpenedOrChanged", {}).get("window", {})
                  wid = window.get("id")
                  if wid is None or wid in known:
                      continue
                  known.add(wid)
                  on_open(window, time.monotonic() - started < GRACE_SEC)
              elif etype == "WindowClosed":
                  known.discard(event.get("WindowClosed", {}).get("id"))

          rc = proc.wait()
          log(f"Event stream ended (rc={rc})")
          sys.exit(rc or 0)

      if __name__ == "__main__":
          main()
    '';
  in {
    options.services.focus-new-windows = {
      enable = lib.mkEnableOption "Focus newly opened niri windows, following launches to their pinned workspace";

      startupGraceSeconds = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "Seconds after session start during which new windows are NOT followed (avoids focus drag from login autostart)";
      };

      skipAppIds = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Regex list of app-ids whose windows should never steal focus (matched with re.search)";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.user.services.focus-new-windows = {
        description = "Follow newly opened niri windows to their workspace";
        after = [
          "graphical-session.target"
          "niri.service"
        ];
        wants = ["niri.service"];
        partOf = ["graphical-session.target"];
        wantedBy = ["graphical-session.target"];

        path = [config.programs.niri.package];

        environment = {
          FOCUS_NEW_WINDOWS_GRACE = toString cfg.startupGraceSeconds;
          FOCUS_NEW_WINDOWS_SKIP = builtins.toJSON cfg.skipAppIds;
        };

        serviceConfig = lib.mkMerge [
          {
            Type = "simple";
            ExecStart = lib.getExe focus-new-windows-daemon;
            Restart = "always";
            RestartSec = "5s";
          }
          (hardenUser {MemoryMax = "128M";})
        ];

        unitConfig = {
          StartLimitBurst = 5;
          StartLimitIntervalSec = 120;
        };
      };
    };
  };
}
