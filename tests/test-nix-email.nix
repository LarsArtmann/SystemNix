# Eval-contract test for the nix-email consumer wrapper (pure eval,
# test-integration.nix pattern - no VM: the wrapper's entire surface is
# eval-time wiring around the upstream flake's NixOS modules, and the
# upstream behavior itself is VM-tested in the nix-email repo).
#
# Proves, against the REAL pinned upstream input (inputs.nix-email - the
# same rev SystemNix's flake.lock carries):
#   1. The upstream modules import cleanly on this nixpkgs pin (option
#      sets services.mail-server / services.dmarc-monitor exist and the
#      stalwart/parsedmarc nixpkgs modules evaluate).
#   2. dmarc-monitor layer (evo-x2 target): the IMAP password rides the
#      sops _secret path contract, parsedmarc.service gets the onFailure
#      routing + startLimit burst/interval, and the integration-registry
#      entry fans out the backup-freshness check on the reports dir.
#   3. mail-server layer (future VPS target): fallback-admin is a
#      LoadCredential referenced through the %{file:...}% macro on the
#      stateVersion-correct stalwart unit.
#   4. The deployment state (plumbing shipped, enabled NOWHERE) still
#      evaluates - a consumer importing this module without enabling it
#      must never be broken.
#
# PIN NOTE (2026-09-15): the pinned nix-email rev (1f8bb52) predates the
# upstream `services.mail-server.relay` option (it rides the next
# nix-email push). The wrapper guards its relay wiring on option
# existence; the relay-configured cases are replaced by a tryEval
# absence-proof until the pin advances. RESTORE the relay-credential
# assertions when bumping the pin (the wrapper's guard comment marks the
# dead code).
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;
  inherit (import ../lib/default.nix lib) onFailure;

  # Wrapper modules are flake-parts-shaped (`{inputs}: {flake.nixosModules.X}`;
  # test-integration.nix pattern): extract the INNER NixOS module and feed
  # `inputs` back through specialArgs (the extracted module reads
  # inputs.nix-email to import the upstream stack).
  nixEmailModule =
    ((import ../modules/nixos/services/nix-email.nix) { inherit inputs; }).flake.nixosModules.nix-email;
  integrationModule =
    (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration;

  evalConfig = extra:
    (lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        nixEmailModule
        integrationModule
        ./mock-sops.nix
        extra
      ];
    }).config;

  throwIfNot = cond: msg: lib.throwIf (!cond) msg true;

  # --- Case 1: deployment state (nothing enabled) -------------------------
  disabled = evalConfig { };

  # --- Case 2: dmarc-monitor enabled (evo-x2 target) ----------------------
  dmarc = evalConfig { services.dmarc-monitor.enable = true; };
  dmarcReg = dmarc.services.integration.dmarc-monitor;

  # --- Case 3: mail-server enabled, no relay (default stateVersion 26.11) -
  mail = evalConfig { services.mail-server.enable = true; };

  # --- Case 4: old stateVersion -> stalwart-mail unit name ----------------
  mailOld = evalConfig {
    services.mail-server = {
      enable = true;
      stateVersion = "25.11";
    };
  };

  # --- Case 5 (PIN NOTE): the relay option must NOT exist at the pin ------
  # Setting it has to fail eval. When the pin advances past the
  # relay-landing rev, replace this with the relay-credential assertions:
  # services.stalwart.credentials."mail-server-relay" wired from sops
  # exactly when relay.username is set.
  relayOptionMissing = !(builtins.tryEval
    (evalConfig {
      services.mail-server.relay.address = "smtp.resend.com";
    }).config.services.mail-server.hostname).success;

  # Each assertion is `true` by construction (throwIfNot throws at eval on
  # violation); fold to a single boolean for the assert below.
  assertions = lib.all lib.id [
    (throwIfNot (disabled ? services.dmarc-monitor && disabled ? services.mail-server)
      "upstream modules did not import: option sets missing in the disabled case")

    (throwIfNot (dmarc.services.dmarc-monitor.settings.imap.password._secret
      == "/run/secrets/dmarc-imap-password")
      "dmarc imap password is not the sops _secret path")

    (throwIfNot (dmarc.systemd.services.parsedmarc.onFailure == onFailure)
      "parsedmarc onFailure routing missing")

    (throwIfNot (dmarc.systemd.services.parsedmarc.startLimitBurst == 5
      && dmarc.systemd.services.parsedmarc.startLimitIntervalSec == 300)
      "parsedmarc startLimit wiring missing (expected 5 failures / 300 s)")

    (throwIfNot (dmarcReg.unit == "parsedmarc.service" && dmarcReg.monitored == true)
      "integration registry entry missing or wrong for dmarc-monitor")

    (throwIfNot (dmarcReg.backup.directory == dmarc.services.dmarc-monitor.outputDirectory
      && dmarcReg.backup.filePattern == "*.json" && dmarcReg.backup.maxAgeHours == 72)
      "backup freshness check not wired to the parsedmarc reports directory")

    (throwIfNot (mail.services.stalwart.credentials."fallback-admin"
      == "/run/secrets/stalwart-fallback-admin")
      "fallback-admin credential not wired from sops")

    (throwIfNot (!(mail.services.stalwart.credentials ? "mail-server-relay"))
      "relay credential leaked into a relay-less config")

    (throwIfNot (mail.services.stalwart.settings.authentication.fallback-admin.secret
      == "%{file:/run/credentials/stalwart.service/fallback-admin}%")
      "fallback-admin macro does not target the stalwart.service unit (stateVersion 26.11)")

    (throwIfNot (mail.systemd.services.stalwart.onFailure == onFailure)
      "stalwart onFailure routing missing")

    (throwIfNot (mailOld.services.stalwart.settings.authentication.fallback-admin.secret
      == "%{file:/run/credentials/stalwart-mail.service/fallback-admin}%")
      "fallback-admin macro does not track the stalwart-mail rename (stateVersion 25.11)")

    (throwIfNot relayOptionMissing
      "relay option unexpectedly evaluable at the pinned rev - advance the pin and restore the relay-credential assertions")
  ];
in
assert assertions;
pkgs.runCommand "test-nix-email" { } ''
  echo "nix-email consumer wrapper: all eval assertions passed"
  touch "$out"
''
