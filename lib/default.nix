lib:
let
  harden = import ./systemd.nix { inherit lib; };
  inherit (import ./systemd/service-defaults.nix lib)
    serviceDefaults
    serviceDefaultsUser
    serviceOneshotDefaults
    serviceOneshotDefaultsUser
    onFailure
    onFailureP0
    ;
in
{
  inherit harden;
  hardenUser = args: harden (args // { mode = "user"; });
  inherit
    serviceDefaults
    serviceDefaultsUser
    serviceOneshotDefaults
    serviceOneshotDefaultsUser
    onFailure
    onFailureP0
    ;
  serviceTypes = import ./types.nix lib;

  mkStateDir =
    path: mode: user: group:
    "d ${path} ${mode} ${user} ${group} -";

  # mkPoolDirUnit: the cv-backup-dir pattern (2026-09-04) as a unit generator
  # — the ONLY sanctioned creator of a directory that lives under a removable
  # mount (/mnt/pool). Supersedes the per-module copy of this shape in
  # cv/miniflux/browser-history/geometrikks/signoz/paperless/discordsync.
  #
  # Invariants baked in (do not relax at call sites):
  #   - root oneshot, RemainAfterExit, wantedBy multi-user — mkdir/chown/chmod
  #     are idempotent, so every boot/deploy re-runs safely
  #   - RequiresMountsFor AND ReadWritePaths target the MOUNT ROOT, never the
  #     leaf: on a fresh pool nothing creates the leaf before this unit's
  #     namespace is set up, and a ReadWritePaths entry under the mountpoint
  #     aborts with 226/NAMESPACE before the script can mkdir
  #   - NEVER replace with a tmpfiles rule: pre-mount creation lands on the
  #     root fs and shadows the pool copy (the 9-day DAS shadow-dir incident)
  #   - chown to a service user needs CAP_CHOWN (harden{}'s empty default
  #     bounding set strips it); CAP_FOWNER covers the follow-up chmod on the
  #     then-foreign-owned dir (2026-09-22 EPERM class); CAP_DAC_OVERRIDE
  #     covers traversal. Owner omitted → dir stays root-owned, no caps needed.
  #
  # Returns a full systemd service attrset:
  #   systemd.services.foo-backup-dir = mkPoolDirUnit {
  #     description = "Create Foo backup directory on the HDD pool";
  #     directory = backupDir;
  #     owner = "postgres";   # omit → root-owned (chmod-only)
  #   };
  mkPoolDirUnit =
    {
      description,
      directory,
      owner ? null,
      group ? owner,
      mode ? "0755",
      mountRoot ? "/mnt/pool",
      memoryMax ? "128M",
    }:
    {
      inherit description;
      wantedBy = [ "multi-user.target" ];
      unitConfig.RequiresMountsFor = [ mountRoot ];
      serviceConfig = lib.mkMerge [
        {
          Type = "oneshot";
          User = "root";
          RemainAfterExit = true;
        }
        (harden (
          {
            inherit memoryMax;
            ReadWritePaths = [ mountRoot ];
          }
          // lib.optionalAttrs (owner != null) {
            CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
          }
        ))
        (serviceOneshotDefaults { })
      ];
      script = lib.concatStringsSep "\n" (
        [ "mkdir -p ${directory}" ]
        ++ lib.optional (owner != null) "chown ${owner}:${group} ${directory}"
        ++ [ "chmod ${mode} ${directory}" ]
      );
    };

  # unitExecText: a unit's Exec* line texts + Environment entries as one
  # concatenated string — the shared scan surface of the port-registry and
  # gatus-coverage eval audits (identical scanner, zero drift: a new Exec
  # key or Environment form added here lands in BOTH audits at once).
  # " \n " separator keeps line-position info for error messages.
  unitExecText =
    svc:
    let
      scanKeys = [
        "ExecStart"
        "ExecStartPre"
        "ExecStartPost"
        "ExecStop"
        "ExecStopPost"
        "ExecReload"
        "ExecCondition"
      ];
      envToString =
        env:
        if builtins.isAttrs env then
          lib.mapAttrsToList (k: v: "${k}=${toString v}") env
        else
          map toString (lib.toList env);
    in
    lib.concatStringsSep " \n " (
      (map (
        k:
        if svc.serviceConfig ? ${k} then
          (lib.concatMapStringsSep " " toString (lib.toList svc.serviceConfig.${k}))
        else
          ""
      ) scanKeys)
      ++ (lib.optionals (svc.serviceConfig ? Environment) (envToString svc.serviceConfig.Environment))
    );

  # extractPortLiterals: port numbers from unit Exec/Environment text in the
  # three forms this repo actually writes them:
  #   host-form   127.0.0.1:8099 / localhost 25 / 0.0.0.0:53
  #   colon-form  <non-alnum>:<digits>   (listen=:8100, http://host:8080/x)
  #   flag-form   --port 8100 / --port=8100
  # Trailing boundary excludes letters so model-tag lookalikes
  # ("qwen3.6-moe:35b-a3b" — live false positive on first deploy of the
  # port-registry guard) never match; "--port=8100abc" is not a port literal.
  # KNOWN LIMITATION: word:NNN tokens ("DELAY:300") are lexically
  # indistinguishable from host:port ("resend.com:587" — letters before the
  # colon are legitimate hostnames) and DO extract when NNN is in the 2-65535
  # range; per-audit allowPorts is the sanctioned escape.
  extractPortLiterals =
    text:
    let
      portRegex = "((127\\.0\\.0\\.1|localhost|0\\.0\\.0\\.0)[: ]([0-9]{2,5})([^0-9]|$))|([^0-9]:([0-9]{2,5})([^0-9a-zA-Z]|$))|(--port[ =]([0-9]{2,5})([^0-9a-zA-Z]|$))";
      parts = builtins.split portRegex text;
      digitGroups = builtins.filter (g: builtins.isString g && builtins.match "[0-9]+" g != null) (
        lib.flatten (map (x: if builtins.isList x then x else [ ]) parts)
      );
    in
    lib.unique (builtins.filter (p: p >= 2 && p <= 65535) (map lib.toInt digitGroups));

  mkSecretCheck =
    pkgs:
    {
      name,
      secretPath,
      message,
      extraCheck ? "",
    }:
    pkgs.writeShellApplication {
      name = "check-${name}";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        secret_path="${secretPath}"
        if [ ! -s "$secret_path" ]; then
          echo "${message}" >&2
          exit 1
        fi
        ${extraCheck}
      '';
    };

  mkDesktopNotifyService =
    pkgs:
    {
      name,
      description,
      checkScript,
      runtimeInputs,
      user,
      uid,
      interval ? "5min",
      bootDelay ? "2min",
      hardenFn ? harden,
      extraHarden ? { },
      extraServiceConfig ? { },
    }:
    let
      script = pkgs.writeShellApplication {
        name = "${name}-check";
        inherit runtimeInputs;
        text = checkScript;
      };
    in
    {
      timer = {
        description = "Periodic ${description}";
        timerConfig = {
          OnBootSec = bootDelay;
          OnUnitActiveSec = interval;
          Persistent = true;
        };
        wantedBy = [ "timers.target" ];
      };

      service = {
        inherit description onFailure;
        serviceConfig = lib.mkMerge [
          {
            Type = "oneshot";
            User = user;
            Environment = [
              "DISPLAY=:0"
              "WAYLAND_DISPLAY=wayland-1"
              "XDG_RUNTIME_DIR=/run/user/${uid}"
            ];
            ExecStart = lib.getExe script;
            StandardOutput = "journal";
            StandardError = "journal";
          }
          (hardenFn (
            lib.mkMerge [
              {
                ProtectHome = false;
                NoNewPrivileges = false;
              }
              extraHarden
            ]
          ))
          extraServiceConfig
        ];
      };
    };

  mkHttpCheck =
    {
      name,
      group,
      url,
      interval ? "30s",
      conditions ? [ "[STATUS] == 200" ],
      alerts ? [ ],
      client ? { },
      headers ? { },
    }:
    {
      inherit
        name
        group
        url
        interval
        conditions
        alerts
        ;
    }
    // lib.optionalAttrs (client != { }) { inherit client; }
    // lib.optionalAttrs (headers != { }) { inherit headers; };

  # Discord alert for a gatus endpoint. NOTE: the YAML field is
  # `description` (gatus alert.Alert yaml tag) — `desc:` is silently
  # dropped by yaml.v3 and never reaches Discord.
  discordAlert = desc: [
    {
      type = "discord";
      description = desc;
    }
  ];

  ports =
    let
      raw = (import ./ports.nix).ports;
      byValue = builtins.groupBy (name: toString raw.${name}) (builtins.attrNames raw);
      dupes = builtins.filter (v: builtins.length byValue.${v} > 1) (builtins.attrNames byValue);
      dupeMsg = builtins.concatStringsSep "; " (
        map (v: "port ${v} used by: ${builtins.concatStringsSep ", " byValue.${v}}") dupes
      );
    in
    if dupes == [ ] then raw else builtins.throw "Port collision: ${dupeMsg}";

  # BFQ I/O priority tiers for the evo-x2 QLC NVMe. Each helper returns a
  # systemd serviceConfig fragment — merge with `mkMerge` alongside `harden {}`.
  #
  # Tier philosophy: lower BE priority = higher I/O precedence. SSH (BE/1) always
  # gets I/O before builds (BE/7). Maintenance (idle) only runs when nothing else
  # needs I/O. This prevents build storms from freezing SSH sessions.
  #
  # Usage: `serviceConfig = lib.mkMerge [ (harden {}) (ioTier.build) ];`
  ioTier = {
    # BE/1 — SSH and critical remote access. Highest priority below realtime.
    interactive = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 1;
    };
    # BE/3 — Desktop session (compositor, shell, audio). Must stay responsive.
    desktop = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 3;
    };
    # BE/4 — Default for unclassified services. Most services sit here implicitly.
    service = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 4;
    };
    # BE/5 — Latency-sensitive databases needing consistent I/O without
    # starving interactive/desktop workloads (clickhouse, monitor365).
    heavyDB = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 5;
    };
    # BE/6 — Standard background daemons tolerating I/O latency
    # (signoz, discordsync, browser-history, attic).
    background = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 6;
    };
    # BE/7 — Batch builds and CI. Lowest BE priority + CPU Nice=10.
    # Nix builds, automated commits, git runners.
    build = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
      Nice = 10;
    };
    # idle — Maintenance tasks using I/O only when nothing else needs it.
    # BFQ serves these last. Pairs with CPU Nice=10 (fstrim, clamav).
    maintenance = {
      IOSchedulingClass = "idle";
      Nice = 10;
    };
  };

  images = import ./images.nix;

  rocm = import ./rocm.nix;

  mkFilesystem = import ./filesystems.nix lib;

  # wrapWithMemoryLimit: creates a wrapper script that runs a command under a
  # systemd transient user scope with cgroup MemoryMax + I/O scheduling limits.
  # Prevents memory-hungry dev/test commands (cargo test, go test, pnpm) from
  # consuming all system RAM on memory-constrained hosts like evo-x2 (Strix Halo
  # with chronic GPUActive memory pressure), AND prevents their I/O from starving
  # the desktop on QLC NAND (BE/7 yields to desktop BE/3 — fixes Helium 3 FPS
  # video drops during build storms).
  #
  # I/O defaults match ioTier.build: best-effort priority 7 + Nice=10. This is
  # deliberate — NOT idle class, which would stall foreground builds whenever
  # any background I/O runs. BE/7 gives builds the lowest best-effort priority
  # while still making forward progress.
  #
  # Returns a writeShellApplication derivation. NOT for use inside Nix build
  # sandboxes (systemd-run is unavailable there). Use in devShells or
  # system/user packages.
  #
  # Example:
  #   wrapWithMemoryLimit pkgs {
  #     name = "go-test";
  #     maxMemory = "4G";
  #     command = lib.getExe pkgs.go;
  #     extraArgs = ["test"];
  #   }
  #   → produces a `go-test-memlimit` script that runs `go test "$@"` under
  #     MemoryMax=4G, IOSchedulingClass=best-effort/7, Nice=10
  wrapWithMemoryLimit =
    pkgs:
    {
      name,
      maxMemory,
      command,
      extraArgs ? [ ],
      ioClass ? "best-effort",
      ioPriority ? 7,
      nice ? 10,
    }:
    pkgs.writeShellApplication {
      name = "${name}-memlimit";
      runtimeInputs = [ pkgs.systemd ];
      text = ''
        exec systemd-run \
          --user --collect --wait \
          --same-dir \
          --setenv="*" \
          -p MemoryMax=${maxMemory} \
          -p IOSchedulingClass=${ioClass} \
          -p IOSchedulingPriority=${toString ioPriority} \
          -p Nice=${toString nice} \
          -- ${command} ${lib.escapeShellArgs extraArgs} "$@"
      '';
    };

  # mkOidcGate: generates a systemd config fragment that gates service startup
  # on OIDC stack readiness (Pocket ID + DNS resolution + TLS).
  #
  # The generated ExecStartPre probes the OIDC discovery endpoint via curl,
  # verifying the full chain: DNS resolution → TLS handshake → HTTP 200.
  # This is more robust than pure After= ordering because dnsblockd is
  # Type=simple (process started ≠ DNS resolving) and Pocket ID's own
  # ExecStartPost healthz only checks localhost (no DNS/TLS).
  #
  # Returns: { after, wants, serviceConfig.ExecStartPre }
  # Merge with: systemd.services.foo = lib.mkMerge [ (mkOidcGate {...}) {...} ];
  #
  # Gate budget is 300s (150 retries × 2s): dnsblockd needs ~2min at boot to
  # load its 3.9M-entry blocklist mapping before it answers *.home.lan DNS
  # (measured 2026-08-31: DNS ready at 16:39:58 while the old 120s budget
  # expired at 16:40:01 — oauth2-proxy + gatus + browser-history failed into
  # OnFailure Discord alerts on every slow boot, then self-healed 5s later).
  # The fragment sets TimeoutStartSec = mkDefault "6min" so consumers that
  # merge the whole serviceConfig get a matching ceiling automatically;
  # consumers that pick only ExecStartPre must set their own — enforced at
  # eval time by gate-timeout-audit.nix (≥ 6min for oidc gates).
  #
  # Example:
  #   mkOidcGate { inherit pkgs domain; serviceName = "gatus"; }
  #   → { after = ["network-online.target" "pocket-id.service" ...];
  #       wants = [...]; serviceConfig.ExecStartPre = ["+gatus-wait-oidc"]; }
  mkOidcGate =
    {
      pkgs,
      domain,
      serviceName,
      includeProvision ? true,
    }:
    let
      deps = [
        "network-online.target"
        "pocket-id.service"
        "dnsblockd.service"
      ]
      ++ lib.optional includeProvision "pocket-id-provision.service";
      script = pkgs.writeShellApplication {
        name = "${serviceName}-wait-oidc";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          echo "${serviceName}: waiting for OIDC endpoint at auth.${domain}..."
          curl -sf --max-time 5 --retry 150 --retry-delay 2 --retry-all-errors \
            -o /dev/null "https://auth.${domain}/.well-known/openid-configuration" \
            || {
              echo "${serviceName}: OIDC endpoint unreachable after 300s" >&2
              exit 1
            }
          echo "${serviceName}: OIDC endpoint ready (TLS verified)"
        '';
      };
    in
    {
      # after (not wants) multi-user.target: every consumer is application
      # readiness — its start must not hold the boot transaction open while it
      # waits out dnsblockd's ~2min blocklist load (the 2026-10-18 multi-user
      # family audit: miniflux was the boot-0 critical-chain gate at 91s; the
      # llama-chat 2026-10-17 owner ruling is the precedent). Units stay in
      # multi-user.wants, so deploy coverage is unchanged.
      after = deps ++ [ "multi-user.target" ];
      wants = deps;
      serviceConfig = {
        ExecStartPre = [ "+${lib.getExe script}" ];
        TimeoutStartSec = lib.mkDefault "6min";
      };
    };

  # mkDnsGate: generates a systemd config fragment that gates service startup
  # on DNS resolution readiness. Probes via getent (no TLS, no HTTP).
  #
  # Use for services that need DNS resolution at init time but don't depend
  # on the OIDC stack (e.g., searxng engine init, forgejo OIDC DNS resolution).
  #
  # Returns: { after, wants, serviceConfig }
  #
  # Default budget is 180s (90 attempts × 2s), raised from 120s on 2026-08-31:
  # dnsblockd needs ~2min at boot to load its blocklist mapping (same measured
  # boot that broke the OIDC gate's old 120s budget), so a 120s DNS gate is
  # marginally expired on every slow boot. The fragment sets
  # TimeoutStartSec = mkDefault "4min" (budget + margin); gate-timeout-audit.nix
  # enforces ≥ 4min on every consumer (≥ 6min for -wait-oidc units).
  #
  # Example:
  #   mkDnsGate { inherit pkgs serviceName; hostname = "wikidata.org"; fatal = false; }
  mkDnsGate =
    {
      pkgs,
      serviceName,
      hostname,
      maxAttempts ? 90,
      intervalSec ? 2,
      fatal ? true,
    }:
    let
      script = pkgs.writeShellApplication {
        name = "${serviceName}-wait-dns";
        runtimeInputs = [ pkgs.getent ];
        text = ''
          echo "${serviceName}: waiting for DNS resolution of ${hostname}..."
          for _ in $(seq 1 ${toString maxAttempts}); do
            if getent hosts ${hostname} >/dev/null 2>&1; then
              echo "${serviceName}: DNS resolution ready"
              exit 0
            fi
            sleep ${toString intervalSec}
          done
          echo "${serviceName}: DNS not ready after ${toString (maxAttempts * intervalSec)}s" >&2
          ${if fatal then "exit 1" else "exit 0"}
        '';
      };
    in
    {
      # Same post-gate ordering as mkOidcGate above (application readiness,
      # never a boot gate).
      after = [
        "network-online.target"
        "dnsblockd.service"
        "multi-user.target"
      ];
      wants = [
        "network-online.target"
        "dnsblockd.service"
      ];
      serviceConfig = {
        ExecStartPre = [ "+${lib.getExe script}" ];
        TimeoutStartSec = lib.mkDefault "4min";
      };
    };
}
