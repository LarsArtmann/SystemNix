{
  config,
  pkgs,
  lib,
  nix-ssh-config,
  ...
}:
let
  blocklists = import ../../common/dns-blocklists.nix;
  dnsLocal = import ../../common/dns-local.nix;
  inherit (config.networking.local)
    lanIP
    piIP
    virtualIP
    gateway
    subnet
    ;
  interface = "eth0";
  domain = "home.lan";
in
{
  imports = [
    ../../common/nix-settings.nix
    ../../common/dns-resolver.nix
    ../../common/locale.nix
    ../system/local-network.nix
    ../system/primary-user.nix
  ];

  system.stateVersion = "25.11";

  boot = {
    tmp.cleanOnBoot = true;
    initrd.availableKernelModules = [
      "usbhid"
      "usb_storage"
      "vc4"
    ];
    zfs.forceImportRoot = false;
  };

  image.baseName = "nixos-rpi3-dns";
  sdImage.compressImage = false;

  networking = {
    hostName = "rpi3-dns";
    inherit domain;
    useDHCP = false;
    enableIPv6 = true;
    interfaces.eth0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = piIP;
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = gateway;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        53
      ];
      allowedUDPPorts = [ 53 ];
    };
  };

  services.sops-config.enable = true;

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    # dnsblockd: embedded DNS resolver + block page server.
    # DoT forwarders (same as evo-x2 — sdns root recursion requires
    # middleware.Setup() which dnsblockd doesn't call). Local zones
    # mirror evo-x2 for LAN consistency.
    dns-blocker = {
      enable = true;

      blockIP = piIP;
      blockPort = 80;
      blockTLSPort = 443;
      blockInterface = "eth0";
      blockIPPrefix = 24;
      statsPort = 9090;

      inherit (blocklists)
        blocklists
        whitelist
        extraDomains
        categories
        ;

      enableDNSSEC = true;
      dnsForwarders = [
        "tls://1.1.1.1:853"
        "tls://9.9.9.9:853"
      ];
      tempAllowAll = false;

      # Local DNS records — mirror evo-x2 for LAN consistency.
      # On failover, clients query rpi3 and get the same home.lan records.
      localRecords =
        builtins.listToAttrs (
          map (subdomain: {
            name = "${subdomain}.${domain}.";
            value = lanIP;
          }) dnsLocal.localSubdomains
        )
        // {
          "*.${domain}." = lanIP;
          "${domain}." = lanIP;
        };
      localZones = [ "${domain}." ];
      allowedNetworks = [
        "127.0.0.0/8"
        "::1/128"
        "${subnet}"
      ];
      dnsIPv6Enabled = false;
    };

    dns-failover = {
      enable = true;
      inherit virtualIP interface;
      priority = 50;
      routerID = 53;
      subnetPrefix = 24;
      passwordFile = config.sops.templates."dns-failover-env".path;
    };
  };

  users = {
    mutableUsers = false;
    users.root = {
      hashedPassword = "!";
      openssh.authorizedKeys.keys = [
        nix-ssh-config.sshKeys.lars
        nix-ssh-config.sshKeys.lars-evo-x2
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    dig
    pkgs.nur.repos.charmbracelet.crush
  ];

  systemd = {
    timers.crush-update-providers = {
      description = "Daily Crush AI provider update";
      timerConfig = {
        OnCalendar = "00:00";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
      wantedBy = [ "timers.target" ];
    };
    services = {
      crush-update-providers = {
        description = "Update Crush AI providers";
        onFailure = [ "crush-update-failure.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe' pkgs.nur.repos.charmbracelet.crush "crush"} update-providers";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };
      crush-update-failure = {
        description = "Log crush provider update failure";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe' pkgs.util-linux "logger"} -t crush-update-providers -p user.err 'Crush provider update failed — check journalctl -u crush-update-providers'";
        };
      };
    };
  };

  nix.gc.options = lib.mkForce "--delete-older-than 7d";
}
