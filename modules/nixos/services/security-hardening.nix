# Security hardening: polkit, PAM, fail2ban, ClamAV, defensive security tools
# Auditd blocked by NixOS 26.05 bug: https://github.com/NixOS/nixpkgs/issues/483085
_: {
  flake.nixosModules.security-hardening = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.security-hardening;
    inherit (import ../../../lib/default.nix lib) onFailure;
    ignoreIpList = "127.0.0.1/8 ::1 ${config.networking.local.subnet} 10.0.0.0/8 172.16.0.0/12";
  in {
    options.services.security-hardening = {
      enable = lib.mkEnableOption "Comprehensive security hardening (polkit, PAM, fail2ban, ClamAV, security tools)";
    };

    config = lib.mkIf cfg.enable {
      users.groups.plugdev = {};

      security = {
        polkit.enable = true;
        pam.services.swaylock = {};
        pam.services.sddm.enableGnomeKeyring = true;
        apparmor.enable = lib.mkDefault false;
      };

      services = {
        dbus = {
          enable = true;
          implementation = "broker";
        };
        gnome.gnome-keyring.enable = true;
        fail2ban = {
          enable = true;
          daemonSettings = {
            Definition.loglevel = "INFO";
            DEFAULT.ignoreip = ignoreIpList;
          };
          jails = {
            sshd.settings = {
              enabled = true;
              port = "ssh";
              filter = "sshd";
              mode = "aggressive";
              maxretry = 3;
              findtime = 600;
              bantime = 3600;
              ignoreip = ignoreIpList;
            };
          };
        };
        clamav.daemon.enable = true;
        clamav.updater.enable = true;
      };

      # ClamAV: socket-activated only — don't block graphical.target at boot.
      systemd.services.clamav-daemon = {
        inherit onFailure;
        wantedBy = lib.mkForce [];
        after = lib.mkForce ["basic.target"];
      };

      # Defensive security tools only
      environment.systemPackages = [
        # polkit_gnome removed — DankMaterialShell provides its own polkit agent
        pkgs.gnome-keyring

        pkgs.pamtester
        pkgs.openssl
        pkgs.gnupg
        pkgs.pass

        pkgs.iptraf-ng
        pkgs.bmon
        pkgs.netsniff-ng
        pkgs.wireshark

        pkgs.aide
        pkgs.osquery

        pkgs.lsof
        pkgs.inotify-tools
        pkgs.iotop
        pkgs.sysstat # iostat -dx 1 — per-device I/O stats
        pkgs.bcc # biotop, biosnoop, biolatency — eBPF per-process block I/O tools (work without CONFIG_TASK_DELAY_ACCT)
        pkgs.bpftrace # eBPF tracing language for custom I/O one-liners
        pkgs.perf

        pkgs.goaccess
        pkgs.ccze

        pkgs.wireguard-tools

        pkgs.tcpdump
        pkgs.nmap
        pkgs.lynis
      ];
    };
  };
}
