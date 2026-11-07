# dnsblockd CA certificate trust: Firefox policies + NSS database import
#
# Extracted from dns-blocker.nix so the block-page server and browser
# trust management are independently composable. Enable this on systems
# where users browse to blocked domains and need to see the dnsblockd
# block page without certificate warnings.
_: {
  flake.nixosModules.dnsblockd-cert-trust =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.dnsblockd-cert-trust;
    in
    {
      options.services.dnsblockd-cert-trust = {
        enable = lib.mkEnableOption "dnsblockd CA certificate trust in Firefox and NSS databases";

        caCertPath = lib.mkOption {
          type = lib.types.path;
          default = config.sops.secrets.dnsblockd_ca_cert.path;
          defaultText = lib.literalExpression "config.sops.secrets.dnsblockd_ca_cert.path";
          description = "Path to the dnsblockd CA certificate (typically a sops-managed secret)";
        };

        disableDoH = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Disable Firefox DNS-over-HTTPS so the local DNS blocker is authoritative";
        };

        localNetworkAccessOverrides = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Chromium Local Network Access address-space overrides, entries
            shaped "<ip-or-cidr>=public" (e.g. "192.168.1.200=public").
            While the dnsblockd gateway lies, public origins resolve to the
            LAN block IP and Chromium's LNA permission blocks every
            subresource ("Permission was denied for this request to access
            the `local` address space" — the 2026-11-07 github-assets
            class). The override reclassifies the lie IP as public so lied
            flows render instead of ERR_FAILED, for splice AND decrypt
            postures. Policy verified: LocalNetworkAccessIpAddressSpaceOverrides
            (Chrome 130+; CGNAT 100.64.0.0/10 is classified LOCAL by
            Chromium — moving the block IP there does NOT dodge LNA).
            Emitted into both /etc/chromium and /etc/helium policy dirs
            (Helium keeps the Chromium policy path; an unused dir is inert).
            Firefox needs nothing: it does not enforce LNA.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        programs.firefox.policies = {
          DNSOverHTTPS = lib.mkIf cfg.disableDoH {
            Enabled = false;
            Locked = true;
          };
          Certificates = {
            Install = [ cfg.caCertPath ];
          };
        };

        systemd.user.services.dnsblockd-cert-import = {
          description = "Import dnsblockd CA cert into NSS database";
          wantedBy = [ "graphical-session.target" ];
          after = [
            "sops-nix.service"
            "graphical-session.target"
          ];
          partOf = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [
            pkgs.nss.tools
            pkgs.coreutils
          ];
          script = ''
            CA_CERT="${cfg.caCertPath}"
            for _ in $(seq 1 30); do
              [ -s "$CA_CERT" ] && break
              sleep 1
            done
            if [ ! -s "$CA_CERT" ]; then
              echo "CA cert not available after 30s: $CA_CERT" >&2
              exit 1
            fi
            mkdir -p $HOME/.pki/nssdb
            if [ ! -f "$HOME/.pki/nssdb/cert9.db" ]; then
              certutil -d sql:$HOME/.pki/nssdb -N --empty-password
            fi
            certutil -d sql:$HOME/.pki/nssdb -D -n dnsblockd-ca 2>/dev/null || true
            certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n dnsblockd-ca -i "$CA_CERT"
          '';
        };

        # Chromium-side LNA fix for the DNS lie (see the option): public
        # origins resolving to the LAN block IP would otherwise lose every
        # subresource to the LNA permission block. Managed-policy JSONs are
        # read at browser start; both fork dirs ship because Helium keeps
        # the Chromium path but an alternate fork dir is inert if unused.
        environment.etc = lib.mkIf (cfg.localNetworkAccessOverrides != [ ]) {
          "chromium/policies/managed/dnsblockd-lna.json".text = builtins.toJSON {
            LocalNetworkAccessIpAddressSpaceOverrides = cfg.localNetworkAccessOverrides;
          };
          "helium/policies/managed/dnsblockd-lna.json".text = builtins.toJSON {
            LocalNetworkAccessIpAddressSpaceOverrides = cfg.localNetworkAccessOverrides;
          };
        };
      };
    };
}
