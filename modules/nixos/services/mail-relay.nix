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
        harden
        ioTier
        mkStateDir
        onFailure
        serviceOneshotDefaults
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

      # RECIPIENT rewriting for system mail. aliases(5) — what rootAlias
      # feeds — only applies in local(8) delivery, and a null client has
      # mydestination="" so local(8) never runs: root@host mail would relay
      # verbatim and die at the provider as an unroutable recipient. The
      # recipient canonical map rewrites at CLEANUP time (before queuing),
      # so root@/postmaster@ on this host (bare, FQDN, and domain forms)
      # reach systemAlias as a real routable mailbox.
      recipientCanonicalMap = pkgs.writeText "postfix-canonical-recipient" ''
        @${hostName} ${systemAlias}
        @${hostName}.${domain} ${systemAlias}
        @${domain} ${systemAlias}
      '';

      # System mail (root@, postmaster@, cron output) recipient: the explicit
      # option, defaulting to fromAddress — a null client has no local
      # delivery, so unaliased root mail would be rejected by the provider as
      # an invalid recipient instead of reaching anyone.
      systemAlias = if cfg.systemMailRecipient == null then cfg.fromAddress else cfg.systemMailRecipient;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      mailRelayMetrics = pkgs.writeShellApplication {
        name = "mail-relay-metrics";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
          pkgs.gnugrep
          pkgs.postfix
        ];
        text = ''
          OUT="${textfileDir}/mail-relay.prom"
          TMP="''${OUT}.tmp"

          errors=0
          queue=-1
          placeholder=1

          # Credential state (fail-closed): the rendered SASL map must exist,
          # be readable, and NOT carry the PLACEHOLDER go-live marker. A
          # missing file means sops never rendered it — same operational
          # state as a placeholder (every send will fail).
          sasl="/run/secrets-rendered/mail-relay-sasl"
          if [ -r "$sasl" ]; then
            if timeout 5 grep -q "PLACEHOLDER" "$sasl"; then
              placeholder=1
            else
              placeholder=0
            fi
          else
            echo "mail-relay-metrics: rendered SASL map $sasl missing or unreadable" >&2
            placeholder=1
          fi

          # Queue depth via the JSON queue report (one object per message;
          # empty queue prints nothing and jq -s 'length' yields 0).
          queue_json=""
          if ! queue_json=$(timeout 15 postqueue -j 2>/dev/null); then
            echo "mail-relay-metrics: postqueue -j failed (postfix down or queue unreadable)" >&2
            errors=1
          fi
          parsed=$(printf '%s' "$queue_json" | timeout 10 jq -s 'length' 2>/dev/null) || parsed=""
          if [ -n "$parsed" ]; then
            queue=$parsed
          else
            errors=1
          fi

          over=0
          if [ "$queue" -ge ${toString cfg.queueAlertThreshold} ] 2>/dev/null; then
            over=1
          fi

          mkdir -p "${textfileDir}"
          {
            echo "# HELP mail_relay_queue_messages Deferred and active messages in the postfix queue"
            echo "# TYPE mail_relay_queue_messages gauge"
            echo "mail_relay_queue_messages $queue"
            echo "# HELP mail_relay_queue_over_threshold 1 when the queue depth crossed the alert threshold"
            echo "# TYPE mail_relay_queue_over_threshold gauge"
            echo "mail_relay_queue_over_threshold $over"
            echo "# HELP mail_relay_credential_placeholder 1 while the upstream credential is missing or still the go-live placeholder"
            echo "# TYPE mail_relay_credential_placeholder gauge"
            echo "mail_relay_credential_placeholder $placeholder"
            echo "# HELP mail_relay_scrape_errors 1 when any probe in this scrape failed"
            echo "# TYPE mail_relay_scrape_errors gauge"
            echo "mail_relay_scrape_errors $errors"
          } > "$TMP"
          mv "$TMP" "$OUT"

          echo "mail-relay-metrics: queue=$queue over=$over placeholder=$placeholder errors=$errors"
        '';
      };
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
          default = "noreply@larsartmann.cloud";
          description = ''
            From address for all relayed mail. MUST be on a domain the upstream
            provider has verified (Resend rejects other senders). Until
            larsartmann.cloud is added + DNS-verified in the Resend dashboard
            (SPF/DKIM records), sends from this address are rejected and defer
            in the local queue — the Mail Relay Queue check surfaces that as
            the pending go-live step.
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

        queueAlertThreshold = lib.mkOption {
          type = lib.types.ints.positive;
          default = 5;
          description = ''
            Deferred-queue depth at which mail_relay_queue_over_threshold flips
            to 1 (the Gatus "Mail Relay Queue" check alerts). With the
            PLACEHOLDER credential still set, the first few user-triggered
            sends (paperless share link, forgejo notification) cross this and
            surface the pending go-live instead of failing silently forever.
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

            # Rewrite system recipients (root@, postmaster@) to a routable
            # mailbox — see recipientCanonicalMap above.
            recipient_canonical_maps = "texthash:${recipientCanonicalMap}";
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

        # Queue + credential textfile collector for node_exporter. A null
        # client's failure mode is INVISIBLE by design: sends fail at the app
        # (or defer silently) while postfix liveness stays green — the exact
        # phantom-green class this repo's monitoring doctrine exists for.
        # Emits (fail-closed, the file is written on EVERY run):
        #   mail_relay_queue_messages            deferred+active queue depth
        #   mail_relay_queue_over_threshold      1 when depth >= queueAlertThreshold
        #   mail_relay_credential_placeholder    1 while the rendered SASL map
        #                                        is missing or still carries
        #                                        the PLACEHOLDER go-live marker
        #   mail_relay_scrape_errors             1 when any probe failed (values
        #                                        then reflect best-effort reads)
        systemd.services.mail-relay-metrics = {
          description = "Mail relay queue/credential textfile collector";
          inherit onFailure;
          after = [ "postfix.service" ];
          serviceConfig = lib.mkMerge [
            (harden { MemoryMax = "64M"; })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              ExecStart = lib.getExe mailRelayMetrics;
              ReadWritePaths = [ textfileDir ];
              # postqueue is timeout-bounded inside; this is the hard ceiling
              TimeoutStartSec = "1min";
            }
          ];
        };

        systemd.timers.mail-relay-metrics = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "30s";
            OnUnitActiveSec = "5min";
          };
        };

        systemd.tmpfiles.rules = [ (mkStateDir textfileDir "1777" "nobody" "nogroup") ];
      };
    };
}
