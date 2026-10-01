# Pure-eval regression test for the bank-sync Paperless-ngx archival wiring
# in modules/nixos/services/bank-sync.nix (2026-09-13). No VM.
#
# Same rationale as test-inboxclean-paperless.nix: the full evo-x2 config
# carries the assertions-poison, so the wrapper is evaluated against stubs.
#
#   1. paperlessArchive.enable=true: the oneshot carries the daemon env
#      (Wise key) + the runtime-minted tmpfs token file + the optional SCA
#      drop-in, runs as the bank-sync user against the shared DB, is
#      mount-gated on dataDir, and derives the paperless URL from the port
#      registry. The token MINT unit exists: idempotent drf_create_token,
#      oneshot, paperless-user identity, tmpfs RuntimeDirectory, root
#      ExecStartPost handover, ordered before the archival oneshot.
#   2. The timer exists and fires after the canary window (Sun 03:00).
#   3. Default (enable=false): neither unit nor timer exists — the mint
#      never runs, nothing touches the paperless DB.
#   4. bank-sync.enable=false: nothing exists at all.
#   5. Enabling archival with paperless disabled fails the coupling
#      assertion (the mint needs the paperless DB).
{
  pkgs,
  inputs,
  system,
}: let
  lib = inputs.nixpkgs.lib;
  # The module file is a flake-parts wrapper (`_: {...}:`) taking no inputs.
  bankSyncWrapper =
    ((import ../modules/nixos/services/bank-sync.nix) {}).flake.nixosModules.bank-sync;

  # Stub for the UPSTREAM bank-sync module's options (the wrapper only reads
  # enable/package/dataDir and sets addr/wiseApiKeyFile/encryptionKeyFile).
  upstreamStub = _: {
    options.services.bank-sync = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      package = lib.mkOption {type = lib.types.package;};
      addr = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:8097";
      };
      provider = lib.mkOption {
        type = lib.types.str;
        default = "wise";
      };
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/bank-sync";
      };
      wiseApiKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
      encryptionKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
    };
  };

  # sops-nix stub: the wrapper reads templates."<name>".path.
  # NOTE: services.paperless.* needs NO stub — nixpkgs' module-list imports
  # misc/paperless.nix in every nixosSystem (config gated on enable), so
  # user/manage/dataDir/enable come with real options and safe defaults.
  sopsStub = {lib, ...}: {
    options.sops.templates = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.path = lib.mkOption {type = lib.types.path;};
        }
      );
    };
    config.sops.templates = {
      "bank-sync-env".path = "/run/secrets/rendered/bank-sync-env";
    };
  };

  stubPackage = pkgs.runCommand "bank-sync-stub" {} ''
    mkdir -p $out/bin
    touch $out/bin/bank-sync
  '';

  base = [
    bankSyncWrapper
    upstreamStub
    sopsStub
    {
      services.bank-sync = {
        enable = true;
        package = stubPackage;
        dataDir = "/mnt/pool/services/bank-sync";
      };
      # nixpkgs leaves paperless.manage undefined until the service is
      # configured; the mint script only interpolates its store path.
      services.paperless.manage = stubPackage;
    }
  ];

  eval = extra:
    (lib.nixosSystem {
      inherit system;
      modules = base ++ extra;
    }).config;

  archivalOn = eval [{services.bank-sync.paperlessArchive.enable = true;}];
  archivalOff = eval [{}];
  serviceOff = eval [{services.bank-sync.enable = lib.mkForce false;}];
  archivalPaperlessOff = eval [
    {
      services.bank-sync.paperlessArchive.enable = lib.mkForce true;
      services.paperless.enable = lib.mkForce false;
    }
  ];

  oneshot = archivalOn.systemd.services.bank-sync-paperless;
  envFiles = oneshot.serviceConfig.EnvironmentFile;
  mint = archivalOn.systemd.services.bank-sync-paperless-token;

  cases = [
    {
      name = "oneshot-carries-daemon-env-minted-token-plus-sca-dropin";
      pass =
        builtins.elem "/run/secrets/rendered/bank-sync-env" envFiles
        && builtins.elem "/run/bank-sync-paperless/env" envFiles
        && builtins.elem "-/var/lib/bank-sync-sca/token.env" envFiles
        && !(builtins.elem "/run/secrets/rendered/bank-sync-paperless-env" envFiles);
    }
    {
      name = "archival-url-derived-from-port-registry";
      pass =
        builtins.any (
          e: e == "BANK_SYNC_PAPERLESS_URL=http://127.0.0.1:2892"
        )
        oneshot.serviceConfig.Environment;
    }
    {
      name = "mint-unit-exists-and-is-idempotent-oneshot";
      pass =
        mint.serviceConfig.Type
        == "oneshot"
        && lib.hasInfix "drf_create_token admin" mint.serviceConfig.ExecStart
        && lib.hasInfix "paperless-manage" mint.serviceConfig.ExecStart;
    }
    {
      name = "mint-runs-as-paperless-user-with-datarite-access";
      pass =
        mint.serviceConfig.User
        == "paperless"
        && builtins.elem "/var/lib/paperless" mint.serviceConfig.ReadWritePaths
        && mint.unitConfig.RequiresMountsFor == ["/var/lib/paperless"];
    }
    {
      name = "mint-token-lives-in-tmpfs-only-with-root-handover";
      pass =
        lib.hasInfix "/run/bank-sync-paperless/env" mint.serviceConfig.ExecStart
        && lib.hasPrefix "+" mint.serviceConfig.ExecStartPost;
    }
    {
      name = "archival-requires-and-orders-after-the-mint";
      pass =
        builtins.elem "bank-sync-paperless-token.service" oneshot.requires
        && builtins.elem "bank-sync-paperless-token.service" oneshot.after;
    }
    {
      name = "oneshot-runs-as-bank-sync-user";
      pass = oneshot.serviceConfig.User == "bank-sync" && oneshot.serviceConfig.Group == "bank-sync";
    }
    {
      name = "oneshot-points-at-shared-db";
      pass =
        builtins.any (
          e: lib.hasPrefix "BANK_SYNC_DATABASE_PATH=/mnt/pool/services/bank-sync" e
        )
        oneshot.serviceConfig.Environment;
    }
    {
      name = "oneshot-mount-gated-on-datadir";
      pass = oneshot.unitConfig.RequiresMountsFor == ["/mnt/pool/services/bank-sync"];
    }
    {
      name = "oneshot-archives-receipts";
      pass = lib.hasInfix "paperless --receipts" oneshot.serviceConfig.ExecStart;
    }
    {
      name = "timer-fires-sunday-0300";
      pass =
        archivalOn.systemd.timers.bank-sync-paperless.timerConfig.OnCalendar
        == "Sun *-*-* 03:00:00"
        && archivalOn.systemd.timers.bank-sync-paperless.timerConfig.Persistent;
    }
    {
      name = "default-off-no-units";
      pass =
        !(archivalOff.systemd.services ? "bank-sync-paperless")
        && !(archivalOff.systemd.services ? "bank-sync-paperless-token")
        && !(archivalOff.systemd.timers ? "bank-sync-paperless");
    }
    {
      name = "service-disabled-no-units";
      pass =
        !(serviceOff.systemd.services ? "bank-sync-paperless")
        && !(serviceOff.systemd.services ? "bank-sync-paperless-token")
        && !(serviceOff.systemd.timers ? "bank-sync-paperless");
    }
    {
      name = "archival-with-paperless-disabled-fails-coupling-assertion";
      pass = builtins.any (a: !a.assertion) archivalPaperlessOff.config.assertions;
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
  if broken == []
  then pkgs.runCommand "bank-sync-paperless-test" {} "touch $out"
  else throw "bank-sync-paperless test failures: ${lib.concatStringsSep ", " broken}"
