{ lib, ... }: {
  options.networking.local = {
    lanIP = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "192.168.1.150";
      description = "Static LAN IP address of this machine";
    };
    subnet = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "192.168.1.0/24";
      description = "LAN subnet in CIDR notation";
    };
    gateway = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "192.168.1.1";
      description = "Default gateway IP address";
    };
    blockIP = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "192.168.1.200";
      description = "IP address for DNS block page responses";
    };
    virtualIP = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "192.168.1.53";
      description = "VRRP virtual IP for DNS failover cluster";
    };
    piIP = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "192.168.1.151";
      description = "Raspberry Pi 3 DNS backup node IP";
    };
    cloudDomain = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "larsartmann.cloud";
      description = ''
        Split-horizon alias zone served alongside home.lan: the same service
        set resolves under this domain for VPN clients (and LAN clients).
        Never published in public DNS — only dnsblockd answers it. See
        docs/brainstorming/2026-09-30_netbird-larsartmann-cloud-selfhosted-vpn.md
      '';
    };
  };
}
