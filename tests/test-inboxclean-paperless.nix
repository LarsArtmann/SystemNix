# Pure-eval regression test for the InboxClean -> Paperless archiving
# wiring in modules/nixos/services/inboxclean.nix (2026-09-02). No VM.
#
# Why a MINIMAL nixosSystem and not evo-x2: the full host config carries
# the known latent `config.assertions` poison (sops template entries with
# owner=null crash message interpolation — AGENTS.md), so negative tests
# that force every assertion message are impossible there. The wrapper
# module is evaluated here against stubs instead, which validates its own
# behavior honestly:
#
#   1. paperless.enable=true + paperless present: the sops env file rides
#      BOTH inboxclean units (upstream commonServiceConfig) and
#      PAPERLESS_URL/PAPERLESS_TAGS land in extraEnvironment.
#   2. paperless.enable=true + paperless ABSENT: the eval-time assertion
#      fires (the sync hook would fail-fast + warn on every tick).
#   3. Archiving off (the shipped default): nothing leaks into the units —
#      a half-config Rejection (URL without token) must be impossible.
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;

  # The module file is a flake-parts wrapper (`{ inputs, ... }:`) — apply
  # it with the one input it needs, then take the inner NixOS module.
  inboxcleanModule =
    ((import ../modules/nixos/services/inboxclean.nix) {
      inputs = {
        inherit (inputs) inboxclean;
      };
    }).flake.nixosModules.inboxclean;

  # sops-nix stub: the wrapper reads only secrets.<name>.path and
  # templates."<name>".path.
  sopsStub =
    { lib, ... }:
    {
      options.sops = {
        secrets = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options.path = lib.mkOption { type = lib.types.path; };
            }
          );
        };
        templates = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options.path = lib.mkOption { type = lib.types.path; };
            }
          );
        };
      };
      config.sops = {
        secrets.inboxclean_gmail_credentials.path = "/run/secrets/inboxclean_gmail_credentials";
        templates."inboxclean-paperless-env".path = "/run/secrets/rendered/inboxclean-paperless-env";
      };
    };

  # The nixpkgs paperless module ships in every nixosSystem closure, so
  # `services.paperless.enable` (default false) exists already — no stub.

  # Keep the test lean: force a stub package so the inboxclean Go
  # derivation is never evaluated (mkDefault loses to mkForce lazily).
  base = [
    inboxcleanModule
    sopsStub
    (
      { lib, ... }:
      {
        services.inboxclean.enable = true;
        services.inboxclean.package = lib.mkForce (
          pkgs.runCommand "inboxclean-stub" { } ''
            mkdir -p $out/bin
            touch $out/bin/inboxclean
          ''
        );
      }
    )
  ];

  eval =
    extra:
    (lib.nixosSystem {
      inherit system;
      modules = base ++ extra;
    }).config;

  archivingOn = eval [
    {
      services.inboxclean.paperless.enable = true;
      services.paperless.enable = true;
    }
  ];
  archivingWithoutPaperless = eval [
    { services.inboxclean.paperless.enable = true; }
  ];
  archivingOff = eval [ { } ];
  disabled = eval [
    { services.inboxclean.enable = lib.mkForce false; }
  ];

  syncConfig = c: c.systemd.services.inboxclean-sync.serviceConfig;
  webConfig = c: c.systemd.services.inboxclean-web.serviceConfig;
  envFile = "/run/secrets/rendered/inboxclean-paperless-env";
  paperlessEnv = c: builtins.filter (lib.hasInfix "PAPERLESS_") (syncConfig c).Environment;

  failingPaperlessAssertions =
    c:
    builtins.filter (
      a: !a.assertion && lib.hasPrefix "services.inboxclean.paperless" a.message
    ) c.assertions;

  cases = [
    {
      name = "enabled-wires-env-file-and-url-on-sync";
      pass =
        (syncConfig archivingOn).EnvironmentFile == [ envFile ]
        && builtins.elem "PAPERLESS_URL=http://127.0.0.1:2892" (paperlessEnv archivingOn)
        && builtins.elem "PAPERLESS_TAGS=gmail" (paperlessEnv archivingOn);
    }
    {
      name = "enabled-wires-env-file-on-web-too";
      pass = (webConfig archivingOn).EnvironmentFile == [ envFile ];
    }
    {
      name = "missing-paperless-assertion-fires";
      pass = failingPaperlessAssertions archivingWithoutPaperless != [ ];
    }
    {
      name = "present-paperless-no-assertion";
      pass = failingPaperlessAssertions archivingOn == [ ];
    }
    {
      name = "off-state-leaks-nothing";
      pass =
        (syncConfig archivingOff).EnvironmentFile == [ ]
        && paperlessEnv archivingOff == [ ]
        && (syncConfig archivingOff).EnvironmentFile == (webConfig archivingOff).EnvironmentFile;
    }
    # Backup chain (cv-backup pattern, 2026-09-03): the DB holds both
    # accounts' sync state + the paperless upload ledger. Lock the three
    # cv-lesson guards: mount-gated (dependency-error instead of
    # 226/NAMESPACE on a detached DAS), DAC_READ_SEARCH (root otherwise
    # cannot stat the foreign-owned state dir — silent no-op class), the
    # online .backup script present, and the whole chain gone when the
    # service is disabled. (The backup-coordination registration lives in
    # configuration.nix — host-level, outside this module eval.)
    {
      name = "backup-unit-mount-gated-and-dac-capable";
      pass =
        archivingOn.systemd.services.inboxclean-backup.unitConfig.RequiresMountsFor
        == [ "/mnt/pool/backups/inboxclean" ]
        && archivingOn.systemd.services.inboxclean-backup.serviceConfig.CapabilityBoundingSet
        == "CAP_DAC_READ_SEARCH"
        && lib.hasInfix "inboxclean-backup" archivingOn.systemd.services.inboxclean-backup.serviceConfig.ExecStart;
    }
    {
      name = "backup-timer-present-and-chain-gated-on-enable";
      pass =
        archivingOn.systemd.timers.inboxclean-backup.timerConfig.OnCalendar == "*-*-* 04:30:00"
        && !(disabled.systemd.services ? "inboxclean-backup")
        && !(disabled.systemd.timers ? "inboxclean-backup")
        && !(disabled.systemd.services ? "inboxclean-backup-dir");
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "inboxclean-paperless-test" { } "touch $out"
else
  throw "inboxclean-paperless test failures: ${lib.concatStringsSep ", " broken}"
