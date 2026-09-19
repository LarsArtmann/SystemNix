{
  config,
  pkgs,
  nix-ssh-config,
  inputs,
  lib,
  ...
}:
let
  inherit (import ../../../lib/default.nix lib) ports;
  theme = import ../../common/theme.nix;
in
{
  imports = [
    # Import common packages shared with macOS
    ../../common/packages/base.nix
    ../../common/packages/fonts.nix
    ../../common/locale.nix
    # Include hardware configuration - essential for NixOS to boot
    ../hardware/hardware-configuration.nix
    # ESSENTIAL MODULES FOR FUNCTIONAL DESKTOP
    ./boot.nix
    ./boot-mirror.nix # Samsung 2nd boot disk: /boot-mirror ESP mirror + boot-mirror-sync
    ./networking.nix
    ./local-network.nix
    ./primary-user.nix
    ./dns-blocker-config.nix # DNS blocker: dnsblockd embedded resolver + block page
    ./snapshots.nix # BTRFS snapshots with btrbk
    ./btrfs-health.nix # BTRFS chunk allocation health monitor + GC guard (prevents 2026-06-26 crash)
    ./btrfs-rescue.nix # Rescue snapshot tier outside btrbk retention (glob-delete survivor, 2026-09-12 incident)
    ./scheduled-tasks.nix # Daily scheduled tasks (crush update-providers, etc.)
    ./sudo.nix # Passwordless sudo for wheel group
    ../hardware/amd-gpu.nix
    ../hardware/amd-npu.nix
    ../hardware/bluetooth.nix
    ../../common/nix-settings.nix
  ];

  # Wrap all configuration in config attribute
  config = {
    # ── nixpkgs tarball regression: ROOT CAUSE FIX ──────────────────────────
    #
    # The global flake registry at channels.nixos.org contains `exact: true`
    # entries that rewrite ALL nixpkgs refs (nixos-unstable, nixpkgs-unstable,
    # bare nixpkgs) to stale channel tarballs. When `nix flake update` runs, it
    # consults these registry entries and rewrites the flake.lock nixpkgs node
    # from `type: github` to `type: tarball`, breaking evaluation.
    #
    # Layer 1 — Eliminate the source: point flake-registry at a local empty file
    # so Nix NEVER downloads the channels.nixos.org registry with its tarball
    # entries. System + user registries still resolve indirect refs (nixpkgs,
    # home-manager, etc.) without the global registry.
    nix.settings.flake-registry = builtins.toFile "empty-flake-registry.json" ''
      {"flakes":[],"version":2}
    '';

    # Layer 2 — Correct-format system registry overrides. The previous entry
    # used `nix.registry."nixpkgs/nixos-unstable"` which creates
    # `from.id = "nixpkgs/nixos-unstable"` — a COMBINED string that does NOT
    # match the global registry's `from = {id: "nixpkgs", ref: "nixos-unstable"}`
    # format. The explicit `from` field below matches the exact key format.
    nix.registry.nixpkgs-nixos-unstable = {
      from = {
        type = "indirect";
        id = "nixpkgs";
        ref = "nixos-unstable";
      };
      to = {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        ref = "nixos-unstable";
      };
      exact = true;
    };
    nix.registry.nixpkgs-nixpkgs-unstable = {
      from = {
        type = "indirect";
        id = "nixpkgs";
        ref = "nixpkgs-unstable";
      };
      to = {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        ref = "nixpkgs-unstable";
      };
      exact = true;
    };

    # dnsblockd CA is trusted via security.pki.certificates in the dns-blocker module

    # Fix for Home Manager + xdg.portal integration
    environment.pathsToLink = [
      "/share/applications"
      "/share/xdg-desktop-portal"
    ];

    # XDG Desktop Portal for app integration and dark mode preference
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      config = {
        common.default = [
          "niri"
          "gnome"
          "gtk"
        ];
      };
    };

    security.wrappers.fusermount3 = {
      source = "${pkgs.fuse3}/bin/fusermount3";
      owner = "root";
      group = "root";
      setuid = true;
    };

    systemd = {
      # smartd boot resilience: after a crash/wedge the USB DAS can
      # re-enumerate with the kernel's removable flag set — smartd exits
      # status 16 ("no Directive -d removable") and ALL pool-disk SMART
      # monitoring is silently gone (live incident, boot 2026-08-18 06:57;
      # the sysfs flags were back to 0 within hours). smartmontools 7.5
      # rejects '-d sat,removable' as an unsupported device type, so the fix
      # is retry-based: restart on failure until enumeration settles.
      # RestartSec=2min avoids a hot loop while the DAS settles. StartLimit
      # keys are top-level ([Unit] section) per the systemd 261 rule.
      services.smartd = {
        serviceConfig = {
          Restart = lib.mkDefault "on-failure";
          RestartSec = "2min";
        };
        startLimitBurst = 10;
        # Typed in seconds — this NixOS option is an int, not a time-span string.
        startLimitIntervalSec = 600;
      };

      # Portal services must wait for niri compositor to be ready, otherwise they race
      # during live activation (nh os test/switch) when both are restarted simultaneously
      user.units."xdg-desktop-portal-gtk.service.d/after-niri.conf" = {
        text = ''
          [Unit]
          After=niri.service
        '';
      };
      user.units."xdg-desktop-portal-gnome.service.d/after-niri.conf" = {
        text = ''
          [Unit]
          After=niri.service
        '';
      };

      # Home Manager activation can fail transiently during live system activation
      # (nix profile lock, file-in-use conflicts). Retry up to 3 times with 5s delay.
      services.home-manager-lars = {
        startLimitBurst = 3;
        startLimitIntervalSec = 30;
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      tmpfiles.rules = [
        "L+ /var/lib/AccountsService/icons/${config.users.primaryUser} - - - - ${../../../assets/avatar.png}"
        # Ensure Home Manager profile directory exists (replaces activationScripts)
        "d /nix/var/nix/profiles/per-user/${config.users.primaryUser} 0755 ${config.users.primaryUser} users -"
        # Auto-clean stale nix build sandboxes daily (interrupted builds leak them)
        "d /nix/var/nix/builds 0755 root root 1d -"
      ];
    };

    # Boot configuration is now handled by ./boot.nix module
    # which provides systemd-boot with proper nvme and Ryzen AI Max+ support

    # User account
    users.users.lars = {
      isNormalUser = true;
      # The UID is pinned because `config.users.users.lars.uid` is null at eval
      # time (isNormalUser assigns the UID at activation, not eval), and
      # `attr or default` does NOT catch null — `toString null` = "" (proven
      # 2026-09-08). Every `${uid}` interpolation (scheduled-tasks.nix
      # notify-failure@ + service-health-check) silently rendered
      # XDG_RUNTIME_DIR=/run/user/ (empty), so notify-send could never reach
      # the session bus and every OnFailure alert fell back to journal-only.
      # Same root cause as boot.nix's hardcoded "user-1000" slice.
      uid = 1000;
      description = "Lars";
      extraGroups = [
        "networkmanager"
        "wheel"
        "docker"
        "input"
        "video"
        "audio"
        "i2c"
        "render"
        "lp"
        "scanner"
      ];
      # INFO: Set password manually with `passwd lars` after installation
      # NOTE: After SSH hardening, password auth will be disabled - you MUST set up SSH keys
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        nix-ssh-config.sshKeys.lars
      ];
      packages = [
        pkgs.firefox
        pkgs.obs-studio
      ];
    };

    # AccountsService avatar for SDDM login/lock screen
    services.accounts-daemon.enable = true;

    programs = {
      obs-studio = {
        enable = true;
        enableVirtualCamera = true;
      };

      # Enable Fish shell system-wide
      fish.enable = true;

      # SearXNG as default Chromium/Helium search engine.
      # LAN access bypasses oauth2-proxy forward-auth via protectedVHost.
      chromium = lib.mkIf config.services.searx.enable {
        extraOpts = {
          DefaultSearchProviderEnabled = true;
          DefaultSearchProviderName = "SearXNG";
          DefaultSearchProviderKeyword = "sx";
          DefaultSearchProviderSearchURL = "https://search.${config.networking.domain}/search?q={searchTerms}";
          DefaultSearchProviderSuggestURL = "https://search.${config.networking.domain}/autocompleter?q={searchTerms}";
        };
      };
    };

    # Dozzle — Docker container log tailing at logs.home.lan
    # Backend set to docker to avoid running Podman alongside Docker
    # Definition lives in modules/nixos/services/dozzle.nix (hardened: memory
    # cap, no-new-privileges, cap-drop=ALL). The former INLINE definition here
    # was a split brain: the dormant module's hardening never reached the
    # container (extraOptions absent from the generated docker run — the
    # "config sets 256m but running container has Memory=0" TODO mystery).
    virtualisation.oci-containers.backend = "docker";
    services.dozzle = {
      enable = true;
      port = ports.dozzle;
    };

    # EMEET PIXY webcam auto-activation
    hardware.emeet-pixy = {
      enable = true;
      auto = "tracking-only";
      defaultAudio = "nc";
      user = "lars";
    };

    # AMD GPU Support - imported from hardware module
    #
    # Font configuration (cross-platform)
    # Note: Font packages are now imported from common/packages/fonts.nix
    # to avoid duplication across platforms
    # System packages for audio/video codec support
    environment.systemPackages = [
      pkgs.libopus # Opus audio codec for Discord voice support
      # Android platform tools (adb/fastboot). The programs.adb module was
      # removed from nixpkgs: systemd 258 ships the android udev rules with
      # uaccess tags, granting the active seat user device ACLs directly.
      pkgs.android-tools
      # CLI tools replacing hand-installed ~/.local/bin binaries (2026-09-16
      # audit: uv{,x}, shfmt, the `exec bun` node shim, and the raw buildflow
      # binary were manual store-less installs; himalaya/flm artifacts were
      # deleted instead of replaced — dormant/obsolete).
      pkgs.uv
      pkgs.shfmt
      pkgs.nodejs
      inputs.buildflow.packages.${pkgs.system}.default
      # flm CLI (NPU LLM; service consumes the same package). Replaces the
      # deleted ~/.local/bin/flm wrapper — the nix package sets its own
      # XILINX_XRT/LD_LIBRARY_PATH, no hand-maintained script needed.
      pkgs.fastflowlm
      # qmd — global on-device RAG/hybrid search CLI (BM25 + vectors + LLM
      # rerank) over markdown/code collections; also the binary Crush spawns
      # for the `qmd` MCP server (crushrc). Upstream flake pin — see flake.nix
      # input for why nixpkgs is not followed.
      inputs.qmd.packages.${pkgs.system}.default
      # Partitioning for user-run sudo migration scripts (sgdisk). NOT in the
      # system env before 2026-08-22 — the first migrate-clickhouse-xfs.sh
      # prepare run died at "sgdisk: command not found" after stopping the
      # SigNoz stack (sudo's secure PATH hides user-profile tools). Keeping it
      # installed removes the nix-build fallback dependency entirely.
      pkgs.gptfdisk
    ];

    # nix-ld: run dynamically-linked foreign binaries (Jan's self-updating
    # llama.cpp engine downloads, AppImages). Replaces the manual /lib64
    # stub-ld symlink hack (2026-08-28) — the module owns the stub AND sets
    # NIX_LD/NIX_LD_LIBRARY_PATH session-wide. vulkan-loader appended so
    # llama.cpp's libggml-vulkan.so can dlopen libvulkan at runtime (the
    # loader's nixpkgs-patched default ICD paths find RADV in
    # /run/opengl-driver automatically). The nixpkgs jan package is
    # FHS-wrapped and does not need this, but its engine child processes
    # benefit when launched outside the FHS namespace.
    programs.nix-ld = {
      enable = true;
      libraries = [ pkgs.vulkan-loader ];
    };

    fonts.fontconfig.defaultFonts = {
      monospace = [
        theme.font.mono
        "Noto Sans Mono"
      ];
      sansSerif = [
        "DejaVu Sans"
        "Noto Sans"
      ];
      serif = [
        "DejaVu Serif"
        "Noto Serif"
      ];
      emoji = [ "Noto Color Emoji" ];
    };

    # Experimental features
    # Note: Nix settings now imported from common/core/nix-settings.nix

    # System state version
    system.stateVersion = "25.11";

    services = {
      udisks2.enable = true;
      sops-config.enable = true;
      caddy.enable = true;
      forgejo.enable = true;
      immich.enable = true;
      paperless.enable = true;
      # Declarative dashboards: saved views provisioned via the REST API
      # (create-only; defaults = Gmail Archive + Encrypted views). Owner
      # auto-resolves to the Pocket ID SSO user (fallback admin). Runbook:
      # docs/services/paperless.md (Dashboards section).
      paperless-dashboard.enable = true;
      # Miniflux RSS reader (rss.home.lan). Admin password rides sops
      # platforms/nixos/secrets/miniflux.yaml — retrieve with the Sops + Age
      # one-liner (break-glass only); daily login is Pocket ID OIDC. The
      # account link (users.openid_connect_id) is provisioned declaratively
      # by miniflux-oidc-setup — WITHOUT it the first SSO login 400s "This
      # user already exists." (callback never links by username).
      # Runbook: docs/services/miniflux.md
      miniflux.enable = true;
      miniflux.oidcLink.enable = true;
      # Explicit, not auto: auto mode requires exactly ONE Pocket ID user and
      # one miniflux user; prod Pocket ID's user count is not guaranteed to
      # stay 1. 'lars' matches both the Pocket ID username and the break-glass
      # miniflux admin (email-prefix fallback: LIKE 'lars@%').
      miniflux.oidcLink.username = "lars";
      # Central outbound mail relay (Postfix null client on 127.0.0.1:25 →
      # authenticated Resend submission). Ships with a PLACEHOLDER sops
      # credential: every send defers in the postfix queue until the real
      # API key is set (go-live runbook: docs/services/mail-relay.md).
      # Consumers wired to it: paperless (outbound), forgejo (notifications),
      # system/cron mail (root/postmaster aliases).
      mail-relay.enable = true;
      # Per-project crush session DBs → Samsung TLC (/mnt/hot). Structural
      # fix for the 2026-09-14 QLC-root IO storm (guard Zone 6 cycling flm,
      # DEPLOY_FORCE_PRESSURE escapes): crush-hot-db-migrate moves each
      # ~/projects/*/.crush dir to /mnt/hot/crush and leaves a symlink;
      # runs from a daily timer + deploy.sh provisioner loop, skips live
      # sessions. See modules/nixos/services/crush-hot-db.nix.
      crush-hot-db.enable = true;
      attic-config = {
        enable = true;
        cachePublicKey = "monitor365:/vu56vS4pTdjoltqqqj80dJ6freEdzEEf4ugdZUPpY8=";
      };
      # One-time /data → pool migration (atticd, monitor365, monitor365-archive).
      # Self-neutralizing: ConditionPathExists skips the unit once all sources
      # are migrated; started by deploy.sh after every switch.
      data-to-pool-migration.enable = true;
      # One-time ActivityWatch data → pool migration with symlink cutover.
      # Self-neutralizing: ConditionPathIsDirectory skips the unit once the
      # source is a symlink; started by deploy.sh after every switch.
      activitywatch-data-to-pool.enable = true;
      # Rescue snapshots of @ in /mnt/btrfs-root/.rescue (chattr +a): a
      # survivor tier outside btrbk's .snapshots that globs cannot reach —
      # 2026-09-12: all six local snapshots were glob-deleted by a `sudo
      # btrfs subvolume delete ... @.20260*` that meant `du`.
      btrfs-rescue.enable = true;
      pocket-id-config = {
        enable = true;
        # Resend only delivers from VERIFIED domains — home.lan can never be
        # one. Requires larsartmann.cloud verified in Resend (SPF/DKIM) for
        # delivery beyond the account owner's own address.
        smtp.from = "noreply@larsartmann.cloud";
        provision = {
          enable = true;
          adminUser = {
            username = "lars";
            email = "lars@larsartmann.cloud";
            firstName = "Lars";
            lastName = "Artmann";
          };
        };
      };
      oauth2-proxy-config.enable = true;
      taskchampion-config.enable = true;
      display-manager-config.enable = true;
      audio-config.enable = true;
      smart-audio.enable = true;
      focus-new-windows.enable = true;
      shutdown-overlay.enable = true;
      niri-desktop.enable = true;
      # niri-session-manager (upstream LarsArtmann/niri-session-manager):
      # WantedBy=graphical-session.target + Requires=niri.service. Deliberately
      # left UNconditioned (fail-loud): if anything ever starts
      # graphical-session.target outside a real login again (2026-08-18 class),
      # niri.service's ConditionEnvironment=XDG_SESSION_ID refuses the start,
      # the Requires edge fails the manager — visible in the journal — and the
      # session-boot-audit eval guard names the culprit at eval time. No
      # OnFailure routing is attached on purpose: the zombie-niri tripwire
      # (niri_zombie metric + Gatus "Niri Zombie Session") is the detection
      # layer; a Discord page per 2s restart-cycle would only spam.
      niri-session-manager.enable = true;
      security-hardening.enable = true;
      gatus-config.enable = true;
      website-deploy-monitor.enable = true;
      multi-wm.enable = true;
      # Review-only systemd tooling (LAN bypass, no auth) — disabled by
      # default, opt-in for ops review. See modules/nixos/services/.
      systemd-graph.enable = true;
      systemd-timer-monitor.enable = true;
      # Every 6h: self-assign unassigned open issues/PRs across all owned
      # GitHub repos (rides the user's existing gh CLI auth).
      github-auto-assign.enable = true;
      browser-policies = {
        enable = true;
        chromiumExtensions =
          let
            ext = id: name: { inherit id name; };
          in
          [
            # Privacy / Content Blocking
            (ext "cjpalhdlnbpafiamejdnhcphjbkeiagm" "uBlock Origin")
            # Secrets — ID must stay in sync with allowed_origins in
            # platforms/common/programs/keepassxc.nix (native messaging)
            (ext "oboonakemofpalcgghocfoadofidjkkk" "KeePassXC-Browser")
            # Productivity
            (ext "chphlpgkkbolifaimnlloiipkdnihall" "OneTab")
            # Time Tracking
            (ext "nglaklhklhcoonedhgnpgddginnjdadi" "ActivityWatch Web Watcher")
            # Email
            (ext "oeopbcgkkoapgobdbedcemjljbihmemj" "Checker Plus for Gmail")
            # YouTube
            (ext "ckagfhpboagdopichicnebandlofghbc" "YouTube Shorts Blocker")
            (ext "bbeaicapbccfllodepmimpkgecanonai" "BlockTube")
            (ext "mnjggcdmjocbbbhaepdhchncahnbgone" "SponsorBlock for YouTube")
            (ext "enamippconapkdmgfgjchkhakpfinmaj" "DeArrow - Better Titles and Thumbnails")
            (ext "hdannnflhlmdablckfkjpleikpphncik" "YouTube Playback Speed Control")
            (ext "pgpdaocammeipkkgaeelifgakbhjoiel" "YouTube Full Title For Videos")
            # GitHub
            (ext "hlepfoohegkhhmjieoechaddaejaokhf" "Refined GitHub")
            (ext "nbiddhncecgemgccalnoanpnenalmkic" "GitHub Issue Link Status")
            (ext "ocfdgncpifmegplaglcnglhioflaimkd" "GitHub Better Line Counts")
            (ext "pemednoikdemhakcchcmjlckmepoighb" "GitHub Milestones Timeline")
            (ext "ialbpcipalajnakfondkflpkagbkdoib" "Lovely forks")
            # Development Tools
            (ext "fmkadmapgofadopljbjfkapdkoienihi" "React Developer Tools")
            (ext "jabopobgcpjmedljpbcaablpmlmfcogm" "WhatFont")
            # Translation
            (ext "cofdbpoegempjloogbagkncekinflcnj" "DeepL: translate and write with AI")
            # Social / Content
            (ext "iffnacikcgjlndahdgnckeekdefoafbn" "Reddit Image Opener")
          ];
      };
      steam-config.enable = true;
      discordsync = {
        # Re-enabled 2026-08-15: the locked rev (923d4071) builds clean — the
        # Aug 12 "vendorHash mismatch" was a stale FOD cache entry, since evicted.
        enable = true;
        gcsBucket = "discordsync-backup";
        # Immich cross-archive comparison on the /lookup page (ADR-062): the
        # server proxies hex SHA-1 hashes to Immich's bulk-upload-check.
        # Ships with a PLACEHOLDER key — create the real key in Immich scoped
        # to asset.read + asset.upload ONLY, then sops --set it into
        # platforms/nixos/secrets/discordsync-immich.yaml (runbook:
        # docs/services/discordsync.md). discordsync-immich-verify pages when
        # a non-placeholder key is rejected.
        immich.enable = true;
      };

      browser-history = {
        enable = true; # Browser history intelligence server
        # One-time cleanup for the 2026-09-18 registration-gate probe user:
        # the freeze reboots already dropped its users_view row (live
        # browser_history_user_count 0 = pre-probe value), so only the
        # UserRegistered journal event remains in the DB. Purged by a
        # marker-guarded ExecStartPre at the next server start (no root
        # needed — the service user owns the StateDirectory). Remove this
        # block once the marker file is observed in /var/lib/browser-history.
        # NOTE: do NOT fire a fresh registration probe before the count-gap
        # fix (TODO gate-count item) — with count 0 the probe 201s and
        # manufactures new debris.
        probeRegistrationCleanup = {
          enable = true;
          email = "probe-gate@example.com";
        };
      };

      # CV — resume generator + career pipeline server (cv.home.lan).
      # Sops: platforms/nixos/secrets/cv.yaml (cv_api_key → CV_API_KEY).
      cv-server = {
        enable = true;
        # Weekly session-validity probe (Mon 09:41): `cv profile accounts
        # --probe --all` against the operator checkout; exit 3 = a session
        # went invalid → onPage failures, alerting instead of apply-time
        # surprises. Adds chromium to the closure (accepted 2026-08-30).
        profileProbe.enable = true;
      };

      # InboxClean — Gmail AI assistant dashboard (inbox.home.lan).
      # Sops: platforms/nixos/secrets/inboxclean.yaml (gmail credentials.json).
      # Runbook: complete the one-time OAuth flow (see modules/nixos/services/
      # inboxclean.nix header), then flip sync.enable = true.
      inboxclean = {
        enable = true;
        # OAuth tokens exist for main + work (verified via /health 2026-09-02),
        # so the sync timer is live (runbook step 5).
        sync.enable = true;
        # Gmail-attachment archiving into Paperless (uploads ride the sync
        # hook; ledger + checksum dedup make it idempotent). LIVE since
        # 2026-09-02: API token provisioned via `paperless-manage
        # drf_create_token admin` and pasted into
        # platforms/nixos/secrets/inboxclean-paperless.yaml. Keep the sops
        # value and this flag in sync — PAPERLESS_URL without a real token
        # is a config Rejection at every inboxclean process start (web +
        # sync crash). Runbook: modules/nixos/services/inboxclean.nix header.
        paperless.enable = true;
      };

      # PapDashboard — alert hub: Gatus ingests trigger/resolve events, the
      # insight enricher correlates storms, pulls journal + metrics evidence,
      # and asks FastFlowLM (NPU) for root-cause analysis. Outbound Discord
      # is filtered to insights only (raw Gatus alerts still flow directly).
      papdashboard = {
        enable = true;
      };

      browser-history-agent = {
        enable = true; # Extract local browser history → push to server
        serverUrl = "https://history.${config.networking.domain}";
        machineId = "evo-x2";
        # The prod DB has multiple bring-up users — the provisioner must
        # attribute the agent token to lars's Pocket ID identity.
        tokenUserEmail = "lars@larsartmann.cloud";
      };

      # Manifest — Smart LLM router for AI agents (cost optimization)
      manifest = {
        enable = true;
      };

      # Disk usage monitoring with desktop notifications at thresholds
      disk-monitor = {
        enable = true;
      };

      # NVMe SSD health monitoring with desktop notifications for critical events
      nvme-health-monitor = {
        enable = true;
        device = "/dev/disk/by-id/nvme-Lexar_SSD_NQ790_2TB_QBC838R010854P220C";
      };

      # OpenSEO — self-hosted SEO suite (rank tracking, keyword research, backlinks)
      openseo.enable = true;

      # SearXNG — privacy-focused metasearch engine
      searx.enable = true;

      # Dual-WAN with MPTCP and route health monitoring
      # DISABLED: route-health-monitor evicts the eno1 default route on transient
      # ISP probe failures (2s timeout to 1.1.1.1), pinning traffic to WiFi-only.
      # Also ECMP would split packets over the metered phone hotspot.
      # Use services.wifi-failover instead: carrier-based standby failover (no
      # probes, no ECMP) — deletes the pinned eno1 default route on carrier loss
      # so the NM WiFi route (metric 100) takes over, restores it when the cable
      # returns. Without it, pulling the cable blackholes ALL traffic: kernel
      # routes are NOT removed on carrier loss, so the metric-0 static default
      # outranks the connected wlan0 route forever.
      dual-wan.enable = false;

      wifi-failover.enable = true;

      # Mullvad VPN daemon — DISABLED.
      # talpid_dns periodically overwrites /etc/resolv.conf even when disconnected,
      # breaking dnsblockd resolution every ~90s. Re-enable manually only when needed:
      #   mullvad-vpn.enable = true; mullvad dns set custom 192.168.1.150
      mullvad-vpn.enable = false;

      # Centralized AI model storage (/data/ai/)
      ai-models.enable = true;

      # AI inference stack — Ollama ROCm, llama.cpp, gpu-python
      ai-stack.enable = true;

      # FastFlowLM NPU LLM server — socket-activated, OpenAI-compatible.
      # Model is 13.6 GB mmap'd from /data/ai/models/fastflowlm; cold loads
      # on first request, idle-unloads after 1h. OpenAI-compatible at
      # http://127.0.0.1:52625/v1. Wired into projects-management-automation
      # via extraEnvironment (OPENAI_BASE_URL + OPENAI_MODEL) so the auto-
      # commit daemon uses the local NPU LLM instead of an external API.
      # Embeddings are served by llama-rag (below), not FastFlowLM —
      # co-loading embed-gemma via --embed 1 was broken (xrt ENOMEM).
      fastflowlm.enable = true;

      # llama.cpp VLM servers (CPU, socket-activated) — NSFW-audit captioning
      # stack. Replaces the ad-hoc nohup llama-server processes from the
      # 2026-09-18/19 Immich audit sessions. Public ports 8127 (verdict model)
      # and 8128 (caption model), OpenAI-compatible at /v1/chat/completions.
      # E4B needs max_tokens >= 2500 (chain-of-thought); nsfwcaption is a pure
      # captioner. Models are CPU-inference only — see llama-vlm.nix header
      # for the ROCm wedge history and the soak-test rule before killing any
      # manual server.
      llama-vlm = {
        enable = true;
        servers = {
          e4b = {
            port = ports.llama-vlm-e4b;
            backendPort = ports.llama-vlm-e4b-backend;
            modelPath = "/data/ai/models/jan/llamacpp/models/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q8_K_P/model.gguf";
            mmprojPath = "/data/ai/models/jan/llamacpp/models/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q8_K_P/mmproj.gguf";
            keepAlive = "1h";
            memoryMax = "16G";
          };
          cap = {
            port = ports.llama-vlm-cap;
            backendPort = ports.llama-vlm-cap-backend;
            # Snapshot-hash path from the llama-server -hf download
            # (2026-09-18). Update after any re-download.
            modelPath = "/data/ai/cache/huggingface/hub/models--GitMylo--nsfwcaption-qwen3-vl-8b-v3-gguf/snapshots/eb52b76411f34ea197558ec03eb15b2814d1b0c2/NSFWCaption-v3-Qwen3-VL-8B-Q8_0.gguf";
            mmprojPath = "/data/ai/cache/huggingface/hub/models--GitMylo--nsfwcaption-qwen3-vl-8b-v3-gguf/snapshots/eb52b76411f34ea197558ec03eb15b2814d1b0c2/mmproj-NSFWCaption-v3.gguf";
            keepAlive = "2h";
            memoryMax = "16G";
          };
        };
      };

      # llama.cpp RAG stack — embeddings (bge-m3) + reranking (bge-reranker-v2-m3)
      # on the GPU (ROCm). Two lightweight llama-server instances, always-on.
      # Replaces the previous plan to use Ollama for embeddings — Ollama does
      # NOT support reranking (issue #3368). Using llama-server for both keeps
      # the RAG stack on a single Nix-native engine, zero Docker.
      # Model GGUFs are auto-fetched into /data/ai/models/gguf/ at activation
      # by the llama-rag-model-fetch oneshot.
      # DISABLED 2026-09-16: the 20260911 nixpkgs llama.cpp build wedges both
      # servers at "model vocab missing newline token" — 94% single-thread CPU
      # spin forever, /health 503 (3/3 repro, the 2026-09-14 regression).
      # "systemctl stop" is not containment on this host (stc re-arms the
      # units on every deploy — they burned 2 cores for 26h straight).
      # Containment lifted 2026-09-18: the module pins llama.cpp to the
      # 0.3.0 build (rev-pinned `nixpkgs-llama-rag` input) — functionally
      # verified serving bge-m3 embeddings live. Goes ACTIVE at the next
      # deploy. Re-disable if the spin signature ever reappears on the
      # pinned build; drop the pin once 0.4.0+ is fixed upstream.
      # ESCAPE CONDITION FIRED 2026-09-18 (freeze #5): the PINNED 0.3.0 build
      # (store path sj4rpa8y…, correct HSA_OVERRIDE env) spins IDENTICALLY
      # under the systemd units — systemd accounting: 2h33min CPU over 2h43min
      # wall (~94% ×2), 8.6G written per lifecycle, wedged right after the
      # vocab warning from 11:28 (gen-784 re-enable) until the 15:27 freeze;
      # replayed at 15:34 on the post-freeze boot until SIGSTOPped by hand.
      # The one-off direct-run verification was INSUFFICIENT evidence — it ran
      # outside the unit context (deviceCgroup/GPU state differ) and passed
      # while the unit wedges. Re-disabled; do NOT re-enable until the spin is
      # root-caused at the llama.cpp/ROCm layer (bisect upstream, or verify via
      # `systemd-run` with the unit's exact sandbox + a 10-min soak under the
      # real service units — not a shell direct-run).
      llama-rag.enable = false;

      file-and-image-renamer = {
        enable = true;
        watchPaths = [
          "/home/${config.users.primaryUser}/Downloads"
          "/home/${config.users.primaryUser}/Pictures"
        ];
        syntheticModel = "syn:small:vision";
        syntheticApiKeyFile = config.sops.secrets.file_renamer_synthetic_api_key.path;
      };

      libinput = {
        enable = true;
        mouse = {
          accelProfile = "flat";
        };
        touchpad = {
          tapping = true;
          naturalScrolling = true;
          disableWhileTyping = true;
          clickMethod = "clickfinger";
        };
      };

      fstrim.enable = true;

      signoz = {
        enable = true;
      };

      # 2026-08-31 coverage audit: registry asserting every service is FULLY
      # registered with SigNoz (traces/logs), eval-time wiring checks + a
      # runtime freshness collector + Gatus/SigNoz alerting.
      signoz-coverage = {
        enable = true;
      };

      gpu-active = {
        enable = true;
      };

      system-health = {
        enable = true;
      };

      # 2026-08-22 kernel-freeze prevention: stops the FastFlowLM backend
      # when MemAvailable/zram enter the pre-freeze zone (see module header
      # for the full incident narrative).
      memory-emergency-guard = {
        enable = true;
      };

      # 2026-08-22 stability plan: bounding heavy-job demand (flock queue
      # `heavy-job` wrapper; build memory is separately bounded via
      # nix-daemon MemoryHigh in networking.nix).
      workload-admission = {
        enable = true;
      };

      # 2026-08-22 stability plan: local SEV1 escalation — DMS notification
      # + fullscreen overlay for guard-trip/guard-dead/infra-criticals when
      # a graphical session is online (Discord stays the phone channel).
      sev1-escalation = {
        enable = true;
      };

      twenty = {
        enable = true;
      };

      # Voice agents (LiveKit + Whisper ASR)
      voice-agents = {
        enable = false;
      };

      # Hermes AI Agent Gateway (Discord, cron jobs, messaging)
      hermes = {
        enable = true;
        # Read-only view of the primary user's projects, mounted at
        # /home/hermes/workspace/projects. The agent reads the real code and
        # clones into its writable workspace to make changes (upstream
        # worktree isolation) — it can never modify lars' checkouts.
        projectsDir = "/home/${config.users.primaryUser}/projects";
      };

      # Crush Daily — AI-powered development insights from Crush databases
      crush-daily = {
        enable = true;
        environmentFile = config.sops.templates."crush-daily-env".path;
        # Run as the primary user so the collector can read per-user crush state
        # from /home/${primaryUser}/.local/share/crush/. The default upstream
        # system user (crush-daily) cannot traverse /home on this system
        # (mode 700 + ACL mask ---) so `crush projects --json` returns an empty
        # list and "collect done projects=0" forever.
        runAsUser = config.users.primaryUser;
      };

      # bank-sync — Wise bank transaction sync + read-only dashboard.
      # Options (addr/dataDir/wiseApiKeyFile/...) come from the upstream flake
      # module; SystemNix defaults (pool dataDir, sops env, localhost bind)
      # are set in modules/nixos/services/bank-sync.nix.
      #
      # Re-enabled 2026-08-18: the AES encryption_key now exists in
      # platforms/nixos/secrets/bank-sync-encryption.yaml (sops-encrypted to
      # the host age PUBLIC key — creatable without root, unlike
      # bank-sync.yaml which holds the real Wise token and needs the host
      # private key to modify). The unit also carries an ExecStartPre
      # mkSecretCheck guard that fails loudly if the rendered template ever
      # lacks a non-empty key line (silent-unencrypted-downgrade protection).
      # Local-only files (gitignored secrets dir): back up both yamls — if
      # evo-x2 dies, its host key dies with it and the events stay encrypted.
      bank-sync = {
        enable = true;
      };

      # tq agent pool — go-taskqueue dogfood (ROUND8 plan): harvests
      # TODO_LIST.md items from CV/SystemNix/go-taskqueue and runs headless
      # crush agents (model pinned per-repo by the tq-bootstrap oneshot's
      # .crushrc managed block). House defaults (pool journal on the HDD
      # pool, budget 30/day, Caddy tq.<domain> dashboard) live in
      # modules/nixos/services/tq-agent-pool.nix. Cutover runbook for the
      # manually-run round-9 pool: docs/services/tq.md.
      tq-agent-pool = {
        enable = true;
      };

      # mr-sync dashboard — read-only repo-portfolio web UI at
      # mr-sync.<domain> (mr-sync dashboard, the CLI's web surface; the CLI
      # itself rides PATH via mkLarsPackages). Reads the live ~/.mrconfig +
      # ~/.config/mr-sync/config.json and walks ~/projects + ~/forks read-only
      # as the primary user. GITHUB_TOKEN placeholder until a PAT is pasted
      # (dashboard degrades to .mrconfig-only data — runbook:
      # docs/services/mr-sync.md).
      mr-sync-dashboard = {
        enable = true;
      };

      # Overview — local project dashboard (discovers git repos, shows stats/activity)
      overview = {
        enable = true;
        port = ports.overview;
        searchPaths = [ "/home/${config.users.primaryUser}/projects" ];
        logLevel = "info";
        # Daemon architecture: overview delegates all discovery to the
        # project-discovery daemon over the unix socket. It never touches the
        # filesystem directly, so it runs fully unprivileged (no "users" group)
        # and needs only modest memory (~250MB steady state — the daemon pays
        # the 7GB discovery spike, not overview).
        daemonSocket = "unix:///run/project-discovery/daemon.sock";
        memoryMax = "512M";
      };

      # Standalone discovery daemon — owns /run/project-discovery/daemon.sock.
      # Flipped from PMA's co-located embedded daemon (2026-09-07): the socket
      # now survives PMA restarts, and PMA's 8G cgroup no longer pays the
      # discovery spike. Cache TTL 24h matches the PMA-era daemon (the watcher
      # + background refresh keep entries fresh; the TTL is only the ceiling).
      # Socket 0666 preserves the PMA-era access model until consumer users
      # are group-managed (then tighten to 0660).
      project-discovery-daemon = {
        enable = true;
        searchPaths = [ "/home/${config.users.primaryUser}/projects" ];
        cacheTTL = "24h";
        socketMode = "0666";
        extraEnvironment = {
          PROJECT_DISCOVERY_REFRESH_INTERVAL = "60s";
        };
      };

      # Minecraft server (local network only, whitelisted)
      minecraft = {
        enable = false;
        whitelist = {
          LartyHD = "8c9ec1ab-f64f-4003-9110-f98a1f0d7f47";
        };
        client = {
          enable = true;
          fov = 100;
          guiScale = 4;
          gamma = 1.0;
          sound = {
            master = 60;
            music = 50;
            noteBlocks = 75;
            weather = 30;
            hostile = 60;
            ambient = 60;
            voice = 60;
          };
        };
      };

      # Monitor365 unified agent — system + desktop collectors
      # DISABLED since 2026-08-12 (a941f88d): the wireguard-collector git
      # dependency is a PRIVATE repo (github.com/LarsArtmann/wireguard-collector),
      # so the Nix sandbox can never fetch it — the build fails at git fetch
      # with "could not read Username", no hash fix can help. Re-enable only
      # after the crate is published to crates.io, the repo made public, or
      # the crate vendored into the monitor365 workspace (owner decision).
      monitor365 = {
        enable = false;
        settings.collectors = {
          # Headless collectors
          network.enabled = lib.mkDefault true;
          battery.enabled = lib.mkDefault true;
          system_info.enabled = lib.mkDefault true;
          process.enabled = lib.mkDefault true;
          location.enabled = lib.mkDefault true;
          fs_event.enabled = lib.mkDefault true;
          # bluetooth disabled (zbus::blocking panics inside tokio)
          bluetooth.enabled = lib.mkDefault false;
          # Desktop collectors (skip gracefully if no graphical session)
          screenshots.enabled = lib.mkDefault true;
          camera = {
            enabled = lib.mkDefault true;
            interval_seconds = lib.mkDefault 3600; # 1h minimum enforced by validation
          };
          keystrokes.enabled = lib.mkDefault true;
          mouse.enabled = lib.mkDefault true;
          clipboard.enabled = lib.mkDefault true;
          notifications.enabled = lib.mkDefault true;
          app_usage.enabled = lib.mkDefault true;
          afk_status.enabled = lib.mkDefault true;
        };
      };

      # storage-collector — long-term filesystem capacity tracking (JSONL).
      # The storage-trend data source that works while monitor365 is
      # disabled above: tracks /, /data, /mnt/pool, /tmp, ... every cycle,
      # rotating JSONL under /var/lib/storage-collector (~60 MiB bounded),
      # threshold events at 85 % with 80 % re-arm hysteresis.
      storage-collector = {
        enable = true;
      };

      # Monitor365 server (dashboard + API) runs on the same machine
      # Same private-git-dep blocker as the agent above (wireguard-collector).
      monitor365-server = {
        enable = false;
        # DuckDB is the sole store on local-only BTRFS (#1 data-loss risk).
        # Local nightly backup is the prerequisite for any future offsite sync.
        backup = {
          enable = lib.mkDefault true;
          schedule = lib.mkDefault "*-*-* 03:00:00";
          keep = lib.mkDefault 7;
        };
        bootstrap = {
          tenantName = lib.mkDefault "LarsArtmann";
          adminEmail = lib.mkDefault "lars@larsartmann.cloud";
        };
        sso.enable = lib.mkDefault true;
      };

      # USB SSD build cache (/mnt/buildcache) — keeps Go/Rust/npm build churn
      # off the QLC NVMe (root cause of the 2026-08-12 SLC exhaustion crashes).
      # Migration: nix run .#migrate-buildcache (see module docs).
      buildcache = {
        enable = true;
        # Weekly GC: npm/pnpm prune, stale rust targets (>14d), go clean -cache
        # guard at >=90% (go-build is unbounded — gopls mtime refresh defeats
        # Go's native 5-day LRU trim). See buildcache.nix + planning doc
        # docs/planning/2026-08-15_21-23_SMART-BUILDCACHE-OVERHAUL.md.
        gc.enable = true;
      };

      # Boot resilience for smartd: after a crash/wedge the USB DAS can
      # re-enumerate with the kernel's removable flag set — smartd then exits
      # status 16 ("no Directive -d removable") and ALL pool-disk SMART
      # monitoring is silently gone (live incident, boot 2026-08-18 06:57;
      # flags were back to 0 within hours). smartmontools 7.5 rejects
      # '-d sat,removable' as an unsupported type, so the fix is retry-based:
      # restart on failure with a 2-min delay until enumeration settles.
      # All four USB-DAS disks carry "-d sat -d removable": smartd exits 16
      # (fatal registration error, NO disk monitored at all — including the
      # NVMe) when a configured device is absent without the removable
      # directive (2026-08-22: DAS offline → smartd dead for the whole boot).
      # Verified against smartmontools 7.5: "-d sat,removable" is INVALID;
      # only the separate second "-d removable" token tolerates absence.
      smartd = {
        enable = true;
        autodetect = false;
        devices = [
          # Internal NVMe by-id: kernel nvmeXn1 enumeration SHIFTS when drives
          # are added/removed (2026-08-31: the new Samsung took nvme0, moving
          # the Lexar system disk to nvme1 — the hardcoded /dev/nvme0n1 then
          # silently monitored the WRONG disk). by-id is slot-independent.
          {
            device = "/dev/disk/by-id/nvme-Lexar_SSD_NQ790_2TB_QBC838R010854P220C";
          }
          {
            device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0RA01856V";
          }
          # Toshiba MG08ACA16TE 16TB pool members (mirrored BTRFS at
          # /mnt/pool, created 2026-08-16 from the dead private-cloud box).
          # Same USB DAS bridge class as the SanDisks: -d sat is required.
          {
            device = "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A005FWTG";
            options = "-d sat -d removable";
          }
          {
            device = "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A0ZUFWTG";
            options = "-d sat -d removable";
          }
          # USB-attached SanDisk SDSSDA240G SSDs. by-id (ata- serial form) is
          # stable across sdb/sdc letter swaps between the two enclosures;
          # -d sat is required — the USB bridge hides the ATA identity at the
          # plain SCSI layer. SSD 1 = build cache (services.buildcache),
          # SSD 2 = future Docker storage.
          {
            device = "/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311";
            options = "-d sat -d removable";
          }
          {
            device = "/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713";
            options = "-d sat -d removable";
          }
        ];
        defaults.monitored = "-a -o on -s (S/../.././02|L/../../6/03)";
      };

      # DAS pool replug self-heal: zombie reaper + remount + failed-service
      # restart + real-IO metrics (the /mnt/pool analogue of
      # buildcache-usb-recovery; udev-keyed to the two Toshiba serials).
      pool-recovery.enable = true;

      # SMART metrics for the pool members (temp, media counters, G-Sense/
      # Disk_Shift deltas via state file) — closes the "dying drive alerts
      # nowhere remote" gap (smartd's only remote channel rides the mail
      # relay). Gatus "Pool Drives *" checks + the pool-storage SigNoz
      # dashboard consume these.
      pool-smart-metrics.enable = true;

      # Cross-service backup health monitoring. Checks all backup dirs for
      # freshness and writes Prometheus metrics. Gatus alerts on Discord
      # when any backup is stale (>25h). Schedules are staggered to avoid
      # IO spikes: Immich ~01:00, Twenty ~02:00, Manifest ~02:30,
      # Monitor365 03:00.
      backup-coordination = {
        enable = true;
        # All backup freshness rows moved to their owning modules
        # (services.integration.<name>.backup): immich, paperless, twenty,
        # manifest, forgejo, pocket-id (2026-09-15), and earlier monitor365,
        # cv, inboxclean.
      };

      # SSH server with hardening (from nix-ssh-config)
      ssh-server = {
        enable = true;
        allowUsers = [ config.users.primaryUser ];
        passwordAuthentication = false;
        allowRootLogin = false;
        authorizedKeys = [ nix-ssh-config.sshKeys.lars ];
      };

      # Declarative Forgejo repository mirroring
      forgejo-repos = {
        enable = true;
        repos = [
          "git@github.com:LarsArtmann/dnsblockd.git"
          "git@github.com:LarsArtmann/BuildFlow.git"
        ];
        autoSync = true;
      };

      # Auto-commit daemon: watches ~/projects, AI-generates commit messages via MiniMax.
      # Also co-locates the project-discovery daemon (shared by overview and other
      # consumers) — the daemon amortizes the ~7GB discovery spike across all
      # consumers instead of each paying it independently. 8G covers the measured
      # peak with headroom; steady state is ~250MB.
      #
      # gitIdentity: defense-in-depth against the Unknown Author regression.
      # Bakes the operator's identity into the daemon's env so it never has to
      # fall back to git config — even during HM activation races, when
      # ~/.config/git/config hasn't been symlinked yet, or after a fresh
      # user-dir reset. Resolution precedence (matches `git commit`):
      #   1. GIT_AUTHOR_* / GIT_COMMITTER_* env vars (set below)
      #   2. `git config user.{name,email}` (local > global > system)
      #   3. Error — getAuthorSignature fails loud instead of silent fallback
      # See modules/nixos/services/projects-management-automation.nix for the
      # env wiring; see go-commit pkg/commit/git/gogit.go for the resolver.
      # Resumes the auto-commit daemon (disabled 2026-08-12, tracked by
      # TODO_LIST.md:148 — "PMA daemon: stop committing broken flake.lock").
      # The 4-layer tarball regression defense is deployed
      # (CHANGELOG.md:2026-08-12 — registry override + tarball guard +
      # nix flake lock hygiene + scoped `nix flake update`); the
      # discovery daemon still runs (Overview, Gatus, etc. depend on it).
      # The fastflowlm.enable block above provides a local NPU LLM for
      # commit-message generation via the OpenAI provider chain (go-commit
      # 22f0e4c+ reads OPENAI_BASE_URL + OPENAI_MODEL from env).
      projects-management-automation = {
        enable = true;
        mode = "active"; # git auto-commit ENABLED — discovery daemon co-located
        paths = [ "/home/${config.users.primaryUser}/projects" ];
        excludePaths = [
          "/home/${config.users.primaryUser}/projects/forks"
          "/home/${config.users.primaryUser}/projects/archived"
        ];
        autoPush = false;
        debounceSeconds = 60;
        minCommitIntervalSeconds = 120;
        # Flipped 2026-09-07: the standalone project-discovery-daemon service
        # above owns the socket now. PMA must NOT bind it too (bind conflict
        # → start-limit) and no longer pays the discovery memory spike.
        enableDiscoveryDaemon = false;
        memoryMax = "8G";
        goMemLimit = "6GiB";
        # 6h integrity purge: the watcher + 60s background refresh keep the
        # cache precise; an hourly full re-discovery re-reads ~13 GB of git
        # data for a handful of missed events.
        cachePurgeIntervalSeconds = 21600;

        gitIdentity = {
          name = "Lars Artmann";
          email = "git@lars.software";
        };
      };
    };
  };
}
