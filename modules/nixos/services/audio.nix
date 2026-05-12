# PipeWire audio server with ALSA/Pulse/JACK support
_: {
  flake.nixosModules.audio = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.audio-config;
  in {
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
      };

      # Pulseaudio disabled (conflicts with pipewire)
      services.pulseaudio.enable = false;

      # Realtime scheduling for audio
      security.rtkit.enable = true;
    };
  };
}
