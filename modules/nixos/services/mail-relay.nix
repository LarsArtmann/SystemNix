# Central outbound mail relay: a Postfix NULL CLIENT on loopback. Every local
# service (paperless, forgejo, system cron) submits unauthenticated to
# 127.0.0.1:25; Postfix relays everything through ONE authenticated upstream
# submission endpoint whose credential lives in sops. Consumer services never
# hold the upstream credential, and outbound mail queues locally (deferred,
# retried) when the provider hiccups instead of erroring in each app.
#
# WHY a relay instead of per-app SMTP credentials: one sops secret to rotate,
# provider rejections visible in one mailq, and no app-level retry storms.
# WHY not direct-to-MX: evo-x2 is a residential host with no rDNS — every
# provider rejects direct port-25 delivery, so an authenticated submission
# relay (587/465) is the only working outbound path.
#
# From-address rewriting: the upstream provider only accepts senders on a
# verified domain, so locally-generated addresses (root@evo-x2.home.lan,
# cron output) are rewritten to fromAddress via smtp_generic_maps, and
# root/postmaster aliases point at fromAddress directly.
#
# GO-LIVE (placeholder pattern, like google-sync/inboxclean): the sops file
# ships with a placeholder password. Replace it interactively and restart:
#   sudo sops platforms/nixos/secrets/mail-relay.yaml   # set mail_relay_password
#   sudo systemctl restart postfix
# Runbook: docs/services/mail-relay.md
_: {
  flake.nixosModules.mail-relay =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        ioTier
        onFailure
        ;

      cfg = config.services.mail-relay;
      hostName = config.networking.hostName;
      domain = config.networking.domain;

      # Sender rewriting for locally-generated mail. Applied by the relay
      # client to BOTH envelope and headers on delivery. Covers the bare
      # hostname, the FQDN, and the bare domain — myorigin forms differ per
      # entry point (cron uses the FQDN, some tools use the bare host).
      genericMap = pkgs.writeText "postfix-generic-map" ''
        @${hostName} ${cfg.fromAddress}
        @${hostName}.${domain} ${cfg.fromAddress}
        @${domain} ${cfg.fromAddress}
      '';

      # texthash (NOT hash:): reads the sops-rendered file directly at lookup
      # time — no postmap step, which would never re-run on secret rotation
      # (postfix-setup is a RemainAfterExit oneshot that only re-runs when
      # its own unit definition changes). The smtp client daemon runs as
      # mail_owner (postfix, unchrooted in the NixOS module — master.cf
      # renders "-" = no chroot), so the template is postfix-owned 0400.
      saslPasswordMap = "texthash:${config.sops.templates."mail-relay-sasl".path}";

      # System mail (root@, postmaster@, cron output) recipient: the explicit
      # option, defaulting to fromAddress — a null client has no local
      # delivery, so unaliased root mail would be rejected by the provider as
      # an invalid recipient instead of reaching anyone.
      systemAlias = if cfg.systemMailRecipient == null then cfg.fromAddress else cfg.systemMailRecipient;
    in
    {
      options.services.mail-relay = {
        enable = lib.mkEnableOption "central outbound mail relay (Postfix null client on loopback → authenticated upstream submission)";

        relayHost = lib.mkOption {
          type = lib.types.str;
          default = "smtp.resend.com";
          description = "Upstream submission host to relay all outbound mail through";
        };

        relayPort = lib.mkOption {
          type = lib.types.port;
          default = 587;
          description = "Upstream submission port (587 = STARTTLS, mandatory via smtp_tls_security_level=encrypt)";
        };

        smtpUsername = lib.mkOption {
          type = lib.types.str;
          default = "resend";
          description = "SASL username for the upstream submission endpoint (Resend's SMTP username is the literal string ''resend''; the password is the API key from sops mail_relay_password)";
        };

        fromAddress = lib.mkOption {
          type = lib.types.str;
          default = "onboarding@resend.dev";
          description = ''
            From address for all relayed mail. MUST be on a domain the upstream
            provider has verified (Resend rejects other senders). The default
            onboarding@resend.dev is Resend's test sender: it works without a
            verified domain but only delivers to your own account's email.
            Set a real address (e.g. noreply@your-verified-domain) for actual use.
          '';
        };

        systemMailRecipient = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Where system mail (root@, postmaster@, cron output) is delivered.
            Defaults to fromAddress — root/postmaster aliases point there, so
            cron failures land in the provider inbox instead of vanishing into
            a local mailbox that nobody reads on a null client.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.postfix = {
          enable = true;

          settings.main = {
            # Null client: listen on loopback only, deliver NOTHING locally —
            # every recipient goes out via relayhost.
            myhostname = "${hostName}.${domain}";
            mydomain = domain;
            myorigin = "$myhostname";
            mydestination = "";
            inet_interfaces = "loopback-only";
            mynetworks = [ "127.0.0.0/8" ];

            relayhost = [ "[${cfg.relayHost}]:${toString cfg.relayPort}" ];

            # Upstream authentication (credential from sops via texthash map)
            smtp_sasl_auth_enable = true;
            smtp_sasl_password_maps = saslPasswordMap;
            smtp_sasl_security_options = "noanonymous";

            # Submission endpoints require TLS; encrypt = mandatory and
            # verified against the system CA store.
            smtp_tls_security_level = "encrypt";
            smtp_tls_CAfile = "/etc/ssl/certs/ca-certificates.crt";

            # Rewrite local senders to the verified fromAddress
            smtp_generic_maps = "texthash:${genericMap}";
          };

          # System mail lands in the operator inbox, not a nonexistent local
          # mailbox (see systemAlias above).
          rootAlias = systemAlias;
          postmasterAlias = systemAlias;
        };

        # The nixpkgs postfix module has NO restartTriggers: a config change
        # re-links main.cf in /var/lib/postfix/conf (postfix-setup re-runs)
        # but the RUNNING master keeps the old config. Stamp the settings
        # into a store path so switch-to-configuration restarts postfix when
        # (and only when) its configuration actually changes. Secret rotation
        # is covered separately by the sops template's restartUnits.
        systemd.services.postfix = {
          inherit onFailure;
          restartTriggers = [
            (pkgs.writeText "postfix-config-stamp" (
              builtins.toJSON {
                inherit (cfg)
                  relayHost
                  relayPort
                  smtpUsername
                  fromAddress
                  ;
                main = config.services.postfix.settings.main;
              }
            ))
          ];
          serviceConfig = lib.mkMerge [
            # Layer on top of the module's own hardening — NEVER via `//`,
            # which would discard its ProtectSystem/CapabilityBoundingSet.
            ioTier.service
          ];
        };
      };
    };
}
