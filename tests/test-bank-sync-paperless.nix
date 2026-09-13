# Pure-eval regression test for the bank-sync Paperless-ngx archival wiring
# in modules/nixos/services/bank-sync.nix (2026-09-13). No VM.
#
# Same rationale as test-inboxclean-paperless.nix: the full evo-x2 config
# carries the assertions-poison, so the wrapper is evaluated against stubs.
#
#   1. paperlessArchive.enable=true: the oneshot carries BOTH env files
#      (daemon env for the Wise key + the dedicated paperless template for
#      URL/token) + the optional SCA drop-in, runs as the bank-sync user
#      against the shared DB, and is mount-gated on dataDir.
#   2. The timer exists and fires after the canary window (Sun 03:00).
#   3. Default (enable=false): neither unit nor timer exists — a placeholder
#      token can never 401-alert on a weekly schedule by accident.
#   4. bank-sync.enable=false: nothing exists at all.
{
  pkgs,
  lib ? pkgs.lib,
  system,
}:
let
  bankSyncWrapper =
    (import ../modules/nixos/services/bank-sync.nix).flake.nixosModules.bank-sync;

  # Stub for the UPSTREAM bank-sync module's options (the wrapper only reads
  # enable/package/dataDir and sets addr/wiseApiKeyFile/encryptionKeyFile).
  upstreamStub =
    { ... }:
    {
      options.services.bank-sync = {
        enable = lib.mkOption { type = lib.types.bool; default = false; };
        package = lib.mkOption { type = lib.types.package; };
        addr = lib.mkOption { type = lib.types.str; default = "127.0.0.1:8097"; };
        provider = lib.mkOption { type = lib.types.str; default = "wise"; };
        dataDir = lib.mkOption { type = lib.types.path; default = "/var/lib/bank-sync"; };
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
  sopsStub =
    { lib, ... }:
    {
      options.sops.templates = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.path = lib.mkOption { type = lib.types.path; };
          }
        );
      };
      config.sops.templates = {
        "bank-sync-env".path = "/run/secrets/rendered/bank-sync-env";
        "bank-sync-paperless-env".path = "/run/secrets/rendered/bank-sync-paperless-env";
      };
    };

  stubPackage = pkgs.runCommand "bank-sync-stub" { } ''
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
    }
  ];

  eval =
    extra:
    (lib.nixosSystem {
      inherit system;
      modules = base ++ extra;
    }).config;

  archivalOn = eval [ { services.bank-sync.paperlessArchive.enable = true; } ];
  archivalOff = eval [ { } ];
  serviceOff = eval [ { services.bank-sync.enable = lib.mkForce false; } ];

  oneshot = archivalOn.systemd.services.bank-sync-paperless;
  envFiles = oneshot.serviceConfig.EnvironmentFile;

  cases = [
    {
      name = "oneshot-carries-both-env-files-plus-sca-dropin";
      pass =
        builtins.elem "/run/secrets/rendered/bank-sync-env" envFiles
        && builtins.elem "/run/secrets/rendered/bank-sync-paperless-env" envFiles
        && builtins.elem "-/var/lib/bank-sync-sca/token.env" envFiles;
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
        ) oneshot.serviceConfig.Environment;
    }
    {
      name = "oneshot-mount-gated-on-datadir";
      pass = oneshot.unitConfig.RequiresMountsFor == [ "/mnt/pool/services/bank-sync" ];
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
        && !(archivalOff.systemd.timers ? "bank-sync-paperless");
    }
    {
      name = "service-disabled-no-units";
      pass =
        !(serviceOff.systemd.services ? "bank-sync-paperless")
        && !(serviceOff.systemd.timers ? "bank-sync-paperless");
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "bank-sync-paperless-test" { } "touch $out"
else
  throw "bank-sync-paperless test failures: ${lib.concatStringsSep ", " broken}"
