{config, ...}: {
  # Networking configuration
  networking = {
    hostName = "evo-x2"; # Machine name
    domain = "home.lan"; # Base domain for all local services

    # NetworkManager manages WiFi only; ethernet (eno1) stays on static IP
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      unmanaged = ["eno1" "interface-name:eno1"];
      dns = "none"; # Keep unbound as the sole resolver
    };
    enableIPv6 = true;

    # Firewall - deny by default, only allow needed ports
    firewall = {
      enable = true;
      allowedTCPPorts = [22 53 80 443];
      allowedUDPPorts = [53 853]; # 53=plain DNS + DoQ, 853=DoQ-over-QUIC
    };

    # Static IP configuration
    useDHCP = false;
    interfaces.eno1 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = config.networking.local.lanIP;
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = config.networking.local.gateway;

    # dhcpcd disabled - using static IP
    dhcpcd.enable = false;

    # DNS uses unbound via dns-blocker-config.nix
    nameservers = ["127.0.0.1"];
  };

  systemd = {
    # Prevent dbus-broker and polkit from restarting on every rebuild.
    # These services have X-Restart-Triggers tied to the system-path hash,
    # which changes whenever any package changes — causing a full D-Bus restart
    # that drops network connections (SSH, etc). Reload is sufficient for
    # picking up new D-Bus service files.
    services = {
      dbus-broker.restartIfChanged = false;
      polkit.restartIfChanged = false;

      # Reload Nix daemon after config changes to apply settings
      nix-daemon = {
        restartIfChanged = true;
        serviceConfig.LimitNOFILE = 65536;
      };
    };

    # Increase file descriptor limits to prevent "Too many open files" errors
    settings.Manager = {
      DefaultLimitNOFILE = 65536;
      DefaultLimitNPROC = 65536;
    };
  };

  # Disable systemd-resolved to prevent DNS conflicts
  services.resolved.enable = false;

  # Set your time zone.
  time.timeZone = "Europe/Berlin"; # Adjust as needed

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Automatic Nix garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Automatic Nix store optimization
  nix.settings.auto-optimise-store = true;
}
