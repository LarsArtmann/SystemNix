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
            DEFAULT.ignoreip = "127.0.0.1/8 ::1 ${config.networking.local.subnet} 10.0.0.0/8 172.16.0.0/12";
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
              ignoreip = "127.0.0.1/8 ::1 ${config.networking.local.subnet} 10.0.0.0/8 172.16.0.0/12";
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
      environment.systemPackages = with pkgs; [
        # polkit_gnome removed — DankMaterialShell provides its own polkit agent
        gnome-keyring

        pamtester
        openssl
        gnupg
        pass

        iptraf-ng
        bmon
        netsniff-ng
        wireshark

        aide
        osquery

        lsof
        inotify-tools
        iotop
        sysstat # iostat -dx 1 — per-device I/O stats
        bcc # biotop, biosnoop, biolatency — eBPF per-process block I/O tools (work without CONFIG_TASK_DELAY_ACCT)
        bpftrace # eBPF tracing language for custom I/O one-liners
        perf

        goaccess
        ccze

        wireguard-tools

        tcpdump
        nmap
        lynis
      ];
    };
  };
}
