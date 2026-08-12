{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../../common/dns-resolver.nix ];
  # Networking configuration
  networking = {
    hostName = "evo-x2"; # Machine name
    domain = "home.lan"; # Base domain for all local services

    # NetworkManager manages WiFi only; ethernet (eno1) stays on static IP
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      unmanaged = [
        "eno1"
        "interface-name:eno1"
      ];
      dns = "none"; # Keep dnsblockd as the sole resolver
    };
    enableIPv6 = true;

    # Firewall - deny by default, trust LAN, allow public-facing ports
    firewall = {
      enable = true;
      trustedInterfaces = [ "eno1" ];
      allowedTCPPorts = [
        22
        53
        80
        443
      ];
      allowedUDPPorts = [
        53
        853
      ]; # 53=plain DNS + DoQ, 853=DoQ-over-QUIC
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
  };

  # dhcpcd disabled - using static IP
  networking.dhcpcd.enable = false;

  systemd = {
    # Prevent dbus-broker and polkit from restarting on every rebuild.
    # These services have X-Restart-Triggers tied to the system-path hash,
    # which changes whenever any package changes — causing a full D-Bus restart
    # that drops network connections (SSH, etc). Reload is sufficient for
    # picking up new D-Bus service files.
    services = {
      dbus-broker = {
        restartIfChanged = lib.mkForce false;
        reloadIfChanged = lib.mkForce false;
      };
      polkit.restartIfChanged = false;

      # nix-daemon: deprioritize builds so SSH/desktop/services keep I/O priority.
      # BFQ respects IOSchedulingClass — nix builds get best-effort/7 (lowest BE),
      # while interactive sessions stay at default BE/4. Nice=10 drops CPU priority
      # so builds don't starve the desktop under heavy compilation.
      nix-daemon = {
        restartIfChanged = true;
        serviceConfig = {
          LimitNOFILE = 65536;
          IOSchedulingClass = lib.mkForce "best-effort";
          IOSchedulingPriority = lib.mkForce 7;
          Nice = 10;
          # nix-daemon is critical infrastructure — it must be the LAST process
          # killed under memory pressure. Two independent OOM mechanisms exist:
          #
          # 1. systemd-oomd (PSI-based): ManagedOOMPreference = "omit" tells oomd
          #    to NEVER select nix-daemon for killing. oomd kills other services
          #    first. This alone fixed the 2026-08-12 outage where oomd killed
          #    nix-daemon mid-build (4-8G peak) → socket activation re-triggered
          #    → start-limit-hit → "Connection refused" on ALL nix operations.
          #
          # 2. Kernel OOM killer (invoked only when system is truly exhausted):
          #    OOMScoreAdjust = -1000 makes nix-daemon the absolute lowest kill
          #    priority. The kernel OOM killer scores every process 0-1000 and
          #    kills the highest scorer; -1000 means "never kill this unless
          #    there is literally nothing else left." This protects against the
          #    scenario where ManagedOOMPreference=omit prevents oomd from
          #    killing nix-daemon, but the system genuinely runs out of RAM and
          #    the kernel's own OOM killer fires.
          #
          # Together: oomd never touches it, kernel OOM killer targets it last.
          # If nix-daemon IS killed, it means the system was completely out of
          # memory with no other reclaimable processes — a hard reboot was
          # imminent anyway.
          ManagedOOMPreference = "omit";
          OOMScoreAdjust = -1000;
        };
      };
    };

    user.services.dbus-broker = {
      restartIfChanged = lib.mkForce false;
      reloadIfChanged = lib.mkForce false;
    };

    # Increase file descriptor limits to prevent "Too many open files" errors
    settings.Manager = {
      DefaultLimitNOFILE = 65536;
      DefaultLimitNPROC = 65536;
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.gutenprint ];

  # Enable SANE for scanning (Canon PIXMA MG2500 scanner)
  hardware.sane.enable = true;
  hardware.sane.extraBackends = [ pkgs.sane-backends ];

  # nix.gc is defined in platforms/common/nix-settings.nix (shared)
}
