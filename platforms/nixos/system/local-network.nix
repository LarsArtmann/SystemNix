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
  };
}
