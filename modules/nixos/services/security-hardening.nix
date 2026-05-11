_: {
  flake.nixosModules.security-hardening = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.security-hardening;
  in {
    options.services.security-hardening = {
      enable = lib.mkEnableOption "Comprehensive security hardening (polkit, PAM, fail2ban, ClamAV, security tools)";
    };

    config = lib.mkIf cfg.enable {
      # Enable comprehensive security monitoring
      security = {
        # Enable polkit for authentication
        polkit.enable = true;

        # Add Swaylock PAM service for screen locking
        pam.services.swaylock = {};

        # Auto-unlock GNOME Keyring at login via SDDM (for git-credential-libsecret)
        pam.services.sddm.enableGnomeKeyring = true;

        # Audit daemon disabled — NixOS 26.05 bug: audit-rules-nixos.service fails with "No rules"
        # Upstream: https://github.com/NixOS/nixpkgs/issues/483085
        # Re-enable after NixOS resolves the audit-rules service bug
        # auditd.enable = true;
        # auditd.settings = {
        #   log_group = "auditd";
        # };

        # Audit rules configuration (disabled — blocked by auditd bug above)
        # Re-enable after auditd is working and kernel audit module is available
        # audit = {
        #   enable = true;
        #   rules = [
        #     # Monitor critical system files
        #     "-w /etc/passwd -p wa -k identity"
        #     "-w /etc/shadow -p wa -k identity"
        #     "-w /etc/group -p wa -k identity"
        #     "-w /etc/sudoers -p wa -k sudo_changes"
        #
        #     # Monitor SSH configuration
        #     "-w /etc/ssh/sshd_config -p wa -k sshd_config"
        #
        #     # Monitor network configuration changes
        #     "-a always,exit -F arch=b64 -S sethostname -S setdomainname -k network"
        #     "-a always,exit -F arch=b32 -S sethostname -S setdomainname -k network"
        #   ];
        # };

        # AppArmor for mandatory access control (disabled)
        apparmor.enable = false;
      };

      # Security services (SSH is configured separately in ../services/ssh.nix)
      services = {
        # Enable D-Bus for portal communication
        dbus = {
          enable = true;
          # Use dbus-broker for better Wayland support (UWSM preferred)
          implementation = "broker";
        };

        # GNOME Keyring for secrets storage (creates /run/wrappers/bin/gnome-keyring-daemon)
        gnome.gnome-keyring.enable = true;

        # Audit log forwarding disabled (depends on auditd)
        # journald.audit = true;

        # Fail2ban for intrusion prevention
        fail2ban = {
          enable = true;
          daemonSettings = {
            Definition.loglevel = "INFO";
            DEFAULT.ignoreip = "127.0.0.1/8 ::1 ${config.networking.local.subnet} 10.0.0.0/8 172.16.0.0/12";
          };
          jails = {
            # SSH brute force protection
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

        # ClamAV antivirus
        clamav.daemon.enable = true;
        clamav.updater.enable = true;
      };

      # ClamAV: socket-activated only — don't block graphical.target at boot.
      # On-demand when something actually scans; freshclam timer keeps signatures current.
      systemd.services.clamav-daemon = {
        onFailure = ["notify-failure@%n.service"];
        wantedBy = lib.mkForce [];
        after = lib.mkForce ["basic.target"];
      };

      # Auditd group disabled (not needed without auditd)
      # users.groups.auditd = {};

      # Security tools
      environment.systemPackages = with pkgs; [
        # Authentication and portal support
        polkit_gnome
        # Note: xdg-utils moved to base.nix for cross-platform consistency
        gnome-keyring

        # Authentication & Access Control
        pamtester # PAM testing
        openssl # Cryptographic toolkit
        gnupg # Encryption & signing
        pass # Password manager

        # Network & Connection Monitoring
        iptraf-ng # IP traffic monitoring
        bmon # Network bandwidth monitor
        netsniff-ng # Network packet capture
        wireshark # Network protocol analyzer (GUI)
        aircrack-ng # WiFi security testing
        netscanner # Network scanning tool

        # System Security Monitoring
        aide # File integrity monitoring
        osquery # OS monitoring & security analytics

        # Process & File Monitoring
        lsof # List open files
        inotify-tools # File system monitoring
        iotop # I/O monitoring
        perf # Performance analysis

        # Log Analysis & Security
        goaccess # Web log analyzer
        ccze # Log colorizer

        # Privacy & Anonymity
        tor-browser # Anonymous browsing
        openvpn # VPN client
        wireguard-tools # Modern VPN

        # Vulnerability Assessment
        masscan # Fast port scanner
        sqlmap # SQL injection testing
        nikto # Web server scanner
        nuclei # Fast vulnerability scanner

        # Incident Response
        sleuthkit # Forensic toolkit
        tcpdump # Packet capture

        # Security tools (existing)
        wireshark-cli # Packet analysis (CLI)
        nmap # Network scanning
        lynis # Security auditing
      ];
    };
  };
}
