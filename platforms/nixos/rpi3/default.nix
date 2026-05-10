{
  config,
  pkgs,
  lib,
  ...
}: let
  blocklists = import ../../shared/dns-blocklists.nix;
  inherit (config.networking.local) lanIP piIP virtualIP gateway subnet;
  interface = "eth0";
  domain = "home.lan";

  fetchedBlocklists =
    map (bl: {
      inherit (bl) name;
      file = pkgs.fetchurl {
        inherit (bl) url;
        inherit (bl) hash;
        name = "${bl.name}-raw";
      };
    })
    blocklists.blocklists;

  whitelistFile = pkgs.writeText "dns-blocker-whitelist.txt" (
    lib.concatStringsSep "\n" blocklists.whitelist
  );

  processorArgs = lib.concatStringsSep " " (
    lib.concatMap (bl: [
      (toString bl.file)
      bl.name
    ])
    fetchedBlocklists
  );

  processedBlocklist =
    pkgs.runCommand "dns-blocker-processed" {
      nativeBuildInputs = [pkgs.dnsblockd];
    } ''
      mkdir -p $out
      dnsblockd process \
        "0.0.0.0" \
        ${whitelistFile} \
        $out/unbound.conf \
        $out/mapping.json \
        ${processorArgs}
    '';

  unboundIncludeFile = pkgs.writeText "dns-blocker-unbound.conf" ''
    include: ${processedBlocklist}/unbound.conf
  '';
in {
  imports = [
    ../../common/core/nix-settings.nix
    ../system/local-network.nix
  ];

  system.stateVersion = "25.11";

  boot = {
    tmp.cleanOnBoot = true;
    initrd.availableKernelModules = ["usbhid" "usb_storage" "vc4"];
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
    nameservers = ["127.0.0.1" "9.9.9.9"];
    firewall = {
      enable = true;
      allowedTCPPorts = [22 53];
      allowedUDPPorts = [53];
    };
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  services = {
    resolved.enable = false;

    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    unbound = {
      enable = true;
      resolveLocalQueries = true;
      enableRootTrustAnchor = true;

      settings = {
        server = {
          interface = ["0.0.0.0" "::0"];
          do-ip6 = false;
          access-control = [
            "127.0.0.0/8 allow"
            "::1/128 allow"
            "${subnet} allow"
          ];

          num-threads = 2;
          msg-cache-size = "32m";
          rrset-cache-size = "64m";
          prefetch = true;
          prefetch-key = true;

          qname-minimisation = true;
          hide-identity = true;
          hide-version = true;

          harden-glue = true;
          harden-dnssec-stripped = true;
          harden-below-nxdomain = true;
          harden-referral-path = true;

          include = toString unboundIncludeFile;

          root-hints = "${pkgs.dns-root-data}/root.hints";

          local-zone =
            map (d: ''"${d}" transparent'') blocklists.whitelist
            ++ map (d: ''"${d}" always_nxdomain'') blocklists.extraDomains
            ++ [''"${domain}." static''];
          local-data =
            map
            (subdomain: ''"${subdomain}.${domain}. IN A ${lanIP}"'')
            ["auth" "immich" "gitea" "dash" "photomap" "signoz" "tasks" "crm"];
        };

        remote-control = {
          control-enable = true;
          control-interface = "/run/unbound/unbound.ctl";
        };
      };
    };

    dns-failover = {
      enable = true;
      inherit virtualIP interface;
      priority = 50;
      routerID = 53;
      subnetPrefix = 24;
      authPassword = "DNSClusterVRRP-evox2";
    };
  };

  users = {
    mutableUsers = false;
    users.root = {
      hashedPassword = "!";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKm9qk4syNtsGJgWTMNRLdGyP3UtAfAKx7XnJxZxq7dF lars@evo-x2"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    dig
    unbound
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
      wantedBy = ["timers.target"];
    };
    services = {
      unbound.reloadIfChanged = true;
      crush-update-providers = {
        description = "Update Crush AI providers";
        onFailure = ["crush-update-failure.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.nur.repos.charmbracelet.crush}/bin/crush update-providers";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };
      crush-update-failure = {
        description = "Log crush provider update failure";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.util-linux}/bin/logger -t crush-update-providers -p user.err 'Crush provider update failed — check journalctl -u crush-update-providers'";
        };
      };
    };
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    settings.auto-optimise-store = true;
  };
}
