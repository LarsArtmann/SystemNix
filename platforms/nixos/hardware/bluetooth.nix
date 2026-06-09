{pkgs, ...}: {
  # Bluetooth configuration for audio casting and WebAuthn phone passkeys
  # - Nest Audio: Bluetooth audio streaming (A2DP source/sink)
  # - WebAuthn hybrid transport: BLE for phone-as-authenticator via QR code

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Enable audio source/sink roles + generic socket for non-audio usage
        Enable = "Source,Sink,Media,Socket";
        # Auto-connect to paired devices
        AutoEnable = true;
        # Experimental features improve BLE support for WebAuthn caBLE/hybrid
        Experimental = true;
      };
    };
  };

  # Blueman: GTK+ Bluetooth Manager with GUI
  services.blueman.enable = true;

  # FIDO2 / U2F udev rules for USB security keys (YubiKey, etc.)
  services.udev.packages = [pkgs.libfido2];
}
