# PipeWire audio server with ALSA/Pulse/JACK support
_: {
  flake.nixosModules.audio =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.audio-config;
    in
    {
      options.services.audio-config = {
        enable = lib.mkEnableOption "PipeWire audio with ALSA/Pulse/JACK support";
      };

      config = lib.mkIf cfg.enable {
        # Enable sound with pipewire
        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          # JACK audio support for professional audio applications
          # Provides low-latency audio processing and audio app interconnection
          jack.enable = true;

          wireplumber.extraConfig."51-hdmi-monitor-priority" = {
            # Disable profile state restoration so the priority rules below
            # always take effect instead of whatever was last selected at runtime
            "wireplumber.settings" = {
              "device.restore-profile" = false;
            };

            # The Radeon audio controller (pci-0000:c5:00.1) exposes multiple
            # HDMI/DisplayPort outputs. Two monitors are connected:
            #   HDMI 2 (eld#0.1) = "LG HDR 4K"  — the main monitor (stereo speakers)
            #   HDMI 3 (eld#0.2) = "LG TV SSCR2" — a TV (full surround)
            # HDMI 3 (the TV) is the preferred audio output.
            "device.profile.priority.rules" = [
              {
                matches = [
                  {
                    "device.name" = "alsa_card.pci-0000_c5_00.1";
                  }
                ];
                actions = {
                  update-props = {
                    priorities = [
                      "output:hdmi-stereo-extra2"
                      "output:hdmi-stereo-extra1"
                    ];
                  };
                };
              }
            ];
          };
        };

        # Pulseaudio disabled (conflicts with pipewire)
        services.pulseaudio.enable = false;

        # Realtime scheduling for audio
        security.rtkit.enable = true;
      };
    };
}
