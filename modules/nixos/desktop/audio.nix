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

          # NO static WirePlumber profile-priority rules here (the old
          # "51-hdmi-monitor-priority" block was removed 2026-09-19): it was
          # doubly dead/fighting — (1) its `device.name` match pinned the
          # pre-crash PCI address `alsa_card.pci-0000_c5_00.1`, which became
          # `c6` in the 2026-08-31 post-crash renumber, so the rule matched
          # NOTHING since then; (2) with `device.restore-profile = false`, any
          # future match would re-apply the priorities on every device event
          # and fight smart-audio's focus-driven profile switches. smart-audio
          # (services.smart-audio) is the SOLE HDMI profile router: it
          # resolves the card by NAME at runtime and switches profiles on
          # workspace focus. Profile state restoration stays at the
          # WirePlumber default (restore-profile on), which re-applies
          # smart-audio's last choice on device events instead of a static
          # priority.
        };

        # Pulseaudio disabled (conflicts with pipewire)
        services.pulseaudio.enable = false;

        # Realtime scheduling for audio
        security.rtkit.enable = true;
      };
    };
}
