# Smart audio routing: follows niri window focus to select HDMI audio output
_: {
  flake.nixosModules.smart-audio =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.smart-audio;

      smart-audio-daemon = pkgs.writeScriptBin "smart-audio-daemon" ''
        #!${pkgs.python3.interpreter}
        import json
        import os
        import subprocess
        import sys
        import time

        # "auto" resolves the GPU HDMI audio card at runtime — PCI addresses
        # on this host renumber after hard crashes (c5:00.1 -> c6:00.1,
        # 2026-08-31), which brickwalled every hardcoded variant into a
        # start-limit-hit crash-loop.
        DEVICE_NAME = os.environ.get("SMART_AUDIO_DEVICE_NAME", "auto")
        DEVICE_WAIT_SEC = 120

        try:
            OUTPUT_MAP = json.loads(os.environ.get("SMART_AUDIO_OUTPUTS", "{}"))
        except json.JSONDecodeError:
            print("[smart-audio] FATAL: invalid SMART_AUDIO_OUTPUTS JSON", file=sys.stderr)
            sys.exit(1)

        DEBOUNCE_SEC = 0.5

        device_id = None
        device_name = ""
        card_token = ""
        profile_map = {}
        current_output = None
        last_switch = 0.0
        workspace_outputs = {}


        def log(msg):
            print(f"[smart-audio] {msg}", flush=True)


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


        def pw_dump():
            r = subprocess.run(["pw-dump"], capture_output=True, text=True)
            if r.returncode != 0:
                return []
            try:
                return json.loads(r.stdout)
            except json.JSONDecodeError:
                return []


        def device_from_obj(obj):
            props = obj.get("info", {}).get("props", {})
            params = obj.get("info", {}).get("params", {})
            pmap = {}
            for p in params.get("EnumProfile", []):
                name = p.get("name", "")
                idx = p.get("index")
                if name and idx is not None:
                    pmap[name] = idx
            return obj.get("id"), pmap, props.get("device.name", "")


        def init_device():
            """Resolve the HDMI audio device.

            An explicit SMART_AUDIO_DEVICE_NAME (full PipeWire device name)
            wins if it exists. "auto" (or an explicit name that no longer
            resolves) falls back to the first ALSA card whose profiles
            include HDMI outputs — i.e. the GPU's audio function. That makes
            the daemon immune to the post-crash PCI renumbering this host
            exhibits.
            """
            hdmi = None
            for obj in pw_dump():
                props = obj.get("info", {}).get("props", {})
                name = props.get("device.name", "")
                if not name.startswith("alsa_card."):
                    continue
                if DEVICE_NAME != "auto" and name == DEVICE_NAME:
                    return device_from_obj(obj)
                profiles = [
                    p.get("name", "")
                    for p in obj.get("info", {}).get("params", {}).get("EnumProfile", [])
                ]
                if hdmi is None and any("hdmi" in p for p in profiles):
                    hdmi = obj
            if hdmi is not None:
                return device_from_obj(hdmi)
            return None, {}, ""


        def find_sink_id(sink_name):
            for obj in pw_dump():
                if obj.get("type") != "PipeWire:Interface:Node":
                    continue
                props = obj.get("info", {}).get("props", {})
                if props.get("node.name") == sink_name:
                    return obj.get("id")
            return None


        def switch_audio(target_output):
            global current_output, last_switch

            if target_output not in OUTPUT_MAP or target_output == current_output:
                return

            now = time.time()
            if now - last_switch < DEBOUNCE_SEC:
                # Wait out the debounce instead of dropping the switch:
                # rapid focus changes must still end on the final target.
                time.sleep(DEBOUNCE_SEC - (now - last_switch))

            out_cfg = OUTPUT_MAP[target_output]
            profile_name = out_cfg.get("profileName", "")
            sink_name = out_cfg.get("sinkName", "").replace("{card}", card_token)
            profile_idx = profile_map.get(profile_name)

            if profile_idx is None:
                log(f"WARNING: profile '{profile_name}' not in profile map")
                return

            if device_id is None:
                return

            log(f"Switching to {target_output} (profile={profile_name})")
            subprocess.run(
                ["wpctl", "set-profile", str(device_id), str(profile_idx)],
                check=False,
            )

            time.sleep(0.3)
            sink_node = find_sink_id(sink_name)
            if sink_node is None:
                time.sleep(0.5)
                sink_node = find_sink_id(sink_name)

            if sink_node is None:
                log(f"ERROR: sink '{sink_name}' not found after profile switch")
                return

            subprocess.run(["wpctl", "set-default", str(sink_node)], check=False)
            current_output = target_output
            last_switch = time.time()
            log(f"Audio routed to {target_output} (node {sink_node})")


        FOCUS_EVENTS = {
            "WindowFocusChanged",
            "WindowFocusTimestampChanged",
            "WorkspaceFocused",
            "WorkspaceActiveWindowChanged",
        }


        def focused_output():
            """Output name of the currently focused workspace, or None."""
            r = subprocess.run(
                ["niri", "msg", "--json", "focused-window"],
                capture_output=True, text=True,
            )
            if r.returncode == 0:
                try:
                    win = json.loads(r.stdout)
                except json.JSONDecodeError:
                    win = None
                if isinstance(win, dict) and win.get("workspace_id") is not None:
                    return workspace_outputs.get(win["workspace_id"])
            # No focused window (e.g. empty workspace): fall back to focused workspace
            r = subprocess.run(
                ["niri", "msg", "--json", "workspaces"],
                capture_output=True, text=True,
            )
            if r.returncode == 0:
                try:
                    for ws in json.loads(r.stdout):
                        if ws.get("is_focused"):
                            return ws.get("output")
                except json.JSONDecodeError:
                    pass
            return None


        def on_event(line):
            global workspace_outputs

            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                return

            etype = next(iter(event), None)

            if etype == "WorkspacesChanged":
                for ws in event.get("WorkspacesChanged", {}).get("workspaces", []):
                    wid = ws.get("id")
                    if wid is not None:
                        workspace_outputs[wid] = ws.get("output", "")

            if etype in FOCUS_EVENTS or etype in ("WorkspacesChanged", "WindowsChanged"):
                target = focused_output()
                if target:
                    switch_audio(target)


        def main():
            global device_id, profile_map, device_name, card_token

            sock = find_niri_socket()
            if not sock:
                log("FATAL: niri socket not found — is niri running?")
                sys.exit(1)
            os.environ["NIRI_SOCKET"] = sock

            deadline = time.time() + DEVICE_WAIT_SEC
            while True:
                device_id, profile_map, device_name = init_device()
                if device_id is not None:
                    break
                if time.time() >= deadline:
                    log(
                        "FATAL: no HDMI-capable ALSA device found after "
                        f"{DEVICE_WAIT_SEC}s (is PipeWire running?)"
                    )
                    sys.exit(1)
                log("waiting for PipeWire to enumerate the HDMI audio device...")
                time.sleep(2)
            card_token = (
                device_name[len("alsa_card."):]
                if device_name.startswith("alsa_card.")
                else device_name
            )

            log(f"Started (device={device_name} id={device_id} card={card_token})")
            log(f"Outputs: {list(OUTPUT_MAP.keys())}")

            # Prime workspace→output mapping from current niri state
            r = subprocess.run(
                ["niri", "msg", "--json", "workspaces"],
                capture_output=True, text=True,
            )
            if r.returncode == 0:
                try:
                    for ws in json.loads(r.stdout):
                        wid = ws.get("id")
                        if wid is not None:
                            workspace_outputs[wid] = ws.get("output", "")
                except json.JSONDecodeError:
                    pass

            target = focused_output()
            if target:
                switch_audio(target)

            # Listen to niri event stream
            log("Listening to niri event stream...")
            proc = subprocess.Popen(
                ["niri", "msg", "--json", "event-stream"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )

            for line in proc.stdout:
                line = line.strip()
                if line:
                    on_event(line)

            rc = proc.wait()
            log(f"Event stream ended (rc={rc})")
            sys.exit(rc or 0)


        if __name__ == "__main__":
            main()
      '';
    in
    {
      options.services.smart-audio = {
        enable = lib.mkEnableOption "Smart audio routing based on niri window focus";

        deviceName = lib.mkOption {
          type = lib.types.str;
          default = "auto";
          description = ''
            PipeWire device name of the HDMI audio controller, or "auto" to
            resolve the ALSA card offering HDMI profiles (the GPU audio
            function) at startup. PCI addresses on this host renumber after
            hard crashes (c5:00.1 -> c6:00.1, 2026-08-31) — prefer "auto".
          '';
        };

        outputs = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                profileName = lib.mkOption {
                  type = lib.types.str;
                  description = "WirePlumber profile name for this output";
                };
                sinkName = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    PipeWire node name of the sink for this output. The
                    literal `{card}` placeholder is replaced at runtime with
                    the resolved card token (e.g. pci-0000_c6_00.1).
                  '';
                };
              };
            }
          );
          default = {
            "DP-1" = {
              profileName = "output:hdmi-stereo-extra1";
              sinkName = "alsa_output.{card}.hdmi-stereo-extra1";
            };
            "DP-2" = {
              profileName = "output:hdmi-stereo-extra2";
              sinkName = "alsa_output.{card}.hdmi-stereo-extra2";
            };
          };
          description = "Mapping of niri output names to audio profiles and sinks";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.user.services.smart-audio = {
          description = "Smart audio routing based on niri window focus";
          after = [
            "graphical-session.target"
            "pipewire.service"
            "wireplumber.service"
          ];
          partOf = [ "graphical-session.target" ];
          wantedBy = [ "graphical-session.target" ];

          path = [
            pkgs.wireplumber
            pkgs.pipewire
            config.programs.niri.package
          ];

          environment = {
            SMART_AUDIO_DEVICE_NAME = cfg.deviceName;
            SMART_AUDIO_OUTPUTS = builtins.toJSON cfg.outputs;
          };

          serviceConfig = {
            Type = "simple";
            ExecStart = lib.getExe smart-audio-daemon;
            Restart = "always";
            RestartSec = "5s";
            MemoryMax = "128M";
          };

          unitConfig = {
            StartLimitBurst = 5;
            StartLimitIntervalSec = 120;
          };
        };
      };
    };
}
