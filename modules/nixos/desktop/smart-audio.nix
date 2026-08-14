# Smart audio routing: follows niri window focus to select HDMI audio output
_:
{
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

        DEVICE_NAME = os.environ.get("SMART_AUDIO_DEVICE_NAME", "alsa_card.pci-0000_c5_00.1")

        try:
            OUTPUT_MAP = json.loads(os.environ.get("SMART_AUDIO_OUTPUTS", "{}"))
        except json.JSONDecodeError:
            print("[smart-audio] FATAL: invalid SMART_AUDIO_OUTPUTS JSON", file=sys.stderr)
            sys.exit(1)

        DEBOUNCE_SEC = 0.5

        device_id = None
        profile_map = {}
        current_output = None
        last_switch = 0.0
        workspace_outputs = {}
        focused_workspace_id = None


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


        def init_device():
            data = pw_dump()
            for obj in data:
                props = obj.get("info", {}).get("props", {})
                if props.get("device.name") == DEVICE_NAME:
                    dev_id = obj.get("id")
                    params = obj.get("info", {}).get("params", {})
                    pmap = {}
                    for p in params.get("EnumProfile", []):
                        name = p.get("name", "")
                        idx = p.get("index")
                        if name and idx is not None:
                            pmap[name] = idx
                    return dev_id, pmap
            return None, {}


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
                return

            out_cfg = OUTPUT_MAP[target_output]
            profile_name = out_cfg.get("profileName", "")
            sink_name = out_cfg.get("sinkName", "")
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


        def on_event(line):
            global workspace_outputs, focused_workspace_id

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

            elif etype == "WindowsChanged":
                focused_workspace_id = None
                for w in event.get("WindowsChanged", {}).get("windows", []):
                    if w.get("is_focused"):
                        focused_workspace_id = w.get("workspace_id")
                        break

            if focused_workspace_id is not None:
                target = workspace_outputs.get(focused_workspace_id)
                if target:
                    switch_audio(target)


        def main():
            global device_id, profile_map

            sock = find_niri_socket()
            if not sock:
                log("FATAL: niri socket not found — is niri running?")
                sys.exit(1)
            os.environ["NIRI_SOCKET"] = sock

            device_id, profile_map = init_device()
            if device_id is None:
                log(f"FATAL: audio device '{DEVICE_NAME}' not found")
                sys.exit(1)

            log(f"Started (device={DEVICE_NAME} id={device_id})")
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

            # Determine initial focus
            r = subprocess.run(
                ["niri", "msg", "--json", "focused-window"],
                capture_output=True, text=True,
            )
            if r.returncode == 0:
                try:
                    win = json.loads(r.stdout)
                    focused_workspace_id = win.get("workspace_id")
                except json.JSONDecodeError:
                    pass

            if focused_workspace_id is not None:
                target = workspace_outputs.get(focused_workspace_id)
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
          default = "alsa_card.pci-0000_c5_00.1";
          description = "PipeWire device name of the HDMI audio controller";
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
                  description = "PipeWire node name of the sink for this output";
                };
              };
            }
          );
          default = {
            "DP-1" = {
              profileName = "output:hdmi-stereo-extra1";
              sinkName = "alsa_output.pci-0000_c5_00.1.hdmi-stereo-extra1";
            };
            "DP-2" = {
              profileName = "output:hdmi-stereo-extra2";
              sinkName = "alsa_output.pci-0000_c5_00.1.hdmi-stereo-extra2";
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
