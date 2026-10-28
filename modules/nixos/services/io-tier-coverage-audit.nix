# Eval-time audit: IO-tier COVERAGE on boot-gated units (2026-10-17, PARETO
# M18 / morning report row 17).
#
# Incident class: a repo module adds a boot-gated unit whose start does BULK
# I/O with no IOSchedulingClass — BFQ runs it at the unclassified default, it
# contends with interactive tiers, and the box's freeze-prone QLC storms get
# a new sustained driver. Live precedents tiered only after the fact:
# llama-chat (23 GB model page-in at boot blame #1), btrfs-compsize
# (full-dataset read mid-storm), btrbk sends, hermes-perms-heal,
# dnsblockd's 3.9M-entry blocklist build, immich-ML model loads,
# llama-rag-model-fetch, boot-mirror-sync (the last four tiered when this
# audit landed).
#
# Contract: every unit inside the boot transaction (wantedBy
# multi-user.target / graphical.target) must set serviceConfig.IOSchedulingClass
# — i.e. merge an ioTier.* fragment (lib/default.nix) — OR be allowlisted
# here with a justification. The allowlist is the census of units whose boot
# leg is metadata-only or steady-state-light; a NEW boot-gated unit fails
# eval until its author picks a tier (or argues an exemption here).
#
# Scope note: evo-x2 only — rpi3-dns lists modules explicitly and does not
# import this audit (minimal DNS host, no QLC storm exposure). user.slice
# churner coverage is deliberately OUT of scope (morning report §g.3 owner
# question: HM unit defaults / dedicated agent slice).
#
# Negative tests: scripts/negative-test-lints.sh CASES=iotier
# (tier-stripped boot unit + allowlist-entry-removed both must throw).
{
  flake.nixosModules.io-tier-coverage-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.io-tier-coverage-audit;

      bootBlockingTargets = [
        "multi-user.target"
        "graphical.target"
        # 2026-10-26 ordering-cycle class fix: gated application units live
        # here now — still boot-started, so IO-tier coverage still applies.
        "late-applications.target"
      ];

      offenders =
        let
          bad = lib.filterAttrs (
            name: svc:
            svc.enable
            && builtins.any (w: builtins.elem w bootBlockingTargets) (svc.wantedBy or [ ])
            && (!(svc.serviceConfig ? IOSchedulingClass) || svc.serviceConfig.IOSchedulingClass == null)
            && !builtins.elem name cfg.allow
          ) config.systemd.services;
        in
        lib.sort (a: b: a < b) (lib.attrNames bad);
    in
    {
      options.services.io-tier-coverage-audit = {
        allow = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            # ── nixpkgs-rendered system daemons: light config I/O at boot,
            #    steady-state daemon work, BFQ default adequate. A stock unit
            #    that ever gains a bulk boot leg gets a tier via the
            #    boot-oneshot-bounds-style overlay pattern instead.
            "NetworkManager"
            "NetworkManager-dispatcher"
            "accounts-daemon"
            "cpufreq"
            "iwd"
            "linger-users"
            "logrotate-checkconf"
            "mandb"
            "nscd"
            "post-boot"
            "prometheus-node-exporter"
            "reload-systemd-vconsole-setup"
            "smartd"
            "sshd-keygen"
            "systemd-modules-load"
            "systemd-oomd"
            "systemd-sysctl"
            "watchdogd"
            # ── nixpkgs-rendered app daemons (enabled by our config):
            #    steady-state request I/O, no bulk boot leg. DB-backed ones
            #    with real write pressure are tiered inside their modules or
            #    ride the hot-db Phase-2 waves instead.
            "caddy"
            "crowdsec"
            "forgejo"
            "home-manager-lars"
            "immich-server"
            "netbird-evox2"
            "netbird-evox2-login"
            "oauth2-proxy"
            "pocket-id"
            "redis-immich"
            "redis-paperless"
            "searx"
            # ── repo storage-dir / bootstrap / secret / registration
            #    oneshots: mkdir + chown + small writes, metadata-only I/O.
            "ai-meter-keys"
            "atticd-bootstrap"
            "atticd-storage-dir"
            "bank-sync-fresh-start"
            "bank-sync-storage-dir"
            "binfmt-sandbox-dir"
            "browser-history-backup-dir"
            "buildcache-init"
            "clickhouse-db-backup-dir"
            "crm-backup-dir"
            "crowdsec-bouncer-register"
            "cv-backup-dir"
            "discordsync-attachments-dir"
            "discordsync-db-backup-dir"
            "dnsblockd-allowlist-backup-dir"
            "dnsblockd-attach-ip"
            "dnsblockd-cert-mint"
            "geometrikks-backup-dir"
            "geometrikks-db-provision"
            "hermes-github-verify"
            "inboxclean-backup-dir"
            "indexer-web-secret-key"
            "miniflux-backup-dir"
            "miniflux-oidc-setup"
            "paperless-db-backup-dir"
            "restic-app-dumps-setup"
            "restic-storage-history-setup"
            "rust-cache-init"
            "searxng-secret-key"
            "signoz-clickhouse-log-ttl"
            "tq-bootstrap"
            "tq-storage-dir"
            # ── repo one-shot system tweaks: trivial writes at boot.
            "btrfs-emergency-reserve"
            "mglru-thrash-protection"
            # ── repo steady-state daemons without a bulk boot leg: bounded
            #    config reads at start, then small request-sized I/O. If one
            #    ever shows up in an IO-storm attribution, promote it to a
            #    real tier at its definition site and drop it from here.
            "ai-meter"
            "crm-server"
            "crush-daily"
            "cv-server"
            "file-and-image-renamer"
            "file-and-image-renamer-health"
            "gatus"
            "health-dashboard"
            "hermes"
            "indexer-web"
            "openseo"
            "overview"
            "storage-collector"
            "taskchampion-sync-server"
            "visionreviewd"
            "wifi-failover"
          ];
          description = ''
            Boot-gated (wantedBy multi-user/graphical) units exempt from the
            IOSchedulingClass requirement. Every entry MUST carry a
            justification comment in this list, plus the promotion condition
            (what would move it to a real ioTier at its definition site).
          '';
        };
      };

      config.assertions = [
        {
          assertion = offenders == [ ];
          message = ''
            io-tier-coverage-audit: boot-gated unit(s) without an IO tier:
            ${lib.concatStringsSep ", " offenders}
            Every unit inside the boot transaction must merge an ioTier.* fragment
            (lib/default.nix) into serviceConfig — or be allowlisted in
            services.io-tier-coverage-audit.allow with a justification.
            Incident class: untiered bulk boot I/O contending with interactive
            tiers on the QLC (llama-chat 23 GB page-in, compsize full-dataset
            read). See modules/nixos/services/io-tier-coverage-audit.nix.
          '';
        }
      ];
    };
}
