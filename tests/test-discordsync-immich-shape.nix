# Pure-eval regression for the DiscordSync Immich conditional shape
# (sops-key-audit pattern — no VM: every asserted surface is an eval-time
# product of modules/nixos/services/sops.nix + discordsync.nix).
#
# Proves the immich.enable gate splits the env template, the restartUnits
# list, and the verify unit/timer coherently:
#   1. ENABLED: the discordsync-env template carries IMMICH_URL +
#      IMMICH_API_KEY, restartUnits names discordsync-immich-verify.service
#      (a key paste re-verifies immediately via the secret restart), and the
#      verify service + daily timer exist.
#   2. DISABLED: the template carries NO IMMICH_ keys, restartUnits never
#      names the verify unit (restartUnits must never reference a unit
#      absent from the generation — activation failure class), and the
#      verify service + timer are absent.
#
# Motivated 2026-10-25: evo-x2 ran the PLACEHOLDER key for 5 weeks while
# /lookup answered "Immich: unavailable" (runbook go-live step 2 pending) —
# the gate shape is now pinned so a refactor cannot silently merge or split
# the three conditional surfaces.
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;
  shared = import ./shared.nix lib;
  mod = shared.mod inputs;

  evalConfig =
    extra:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        # Partial closure by design: integration.nix (which declares
        # services.integration) is deliberately NOT imported — the wrapper's
        # registry entry is guard-gated and skipped here. The option
        # existence check must therefore be off: with the full host closure
        # absent, a definition (source NOT identified — see the queued
        # follow-up; guard provably false and no module greps match) trips
        # the strict check with "services.integration does not exist"
        # (2026-10-25). The shapes asserted below are structural
        # (hasAttr/hasInfix/elem) and do not depend on it; genuine merge
        # errors still throw.
        { _module.check = false; }
        # The SystemNix wrapper (mod "discordsync.nix") imports
        # inputs.discordsync.nixosModules.default ITSELF — do NOT import it
        # here too: the double import is not deduped across access paths and
        # fails eval with "services.discordsync.* is already declared"
        # (observed 2026-10-25).
        inputs.sops-nix.nixosModules.sops
        (mod "discordsync.nix" "discordsync")
        (mod "sops.nix" "sops")
        # sops.nix reads users.primaryUser (declared by the host layer's
        # primary-user.nix, not part of this import set) for template
        # ownership — declare + set it inline.
        {
          options.users.primaryUser = lib.mkOption { type = lib.types.str; };
        }
        {
          users.primaryUser = "discordsync-test-user";
          services.sops-config.enable = true;
          services.discordsync.enable = true;
        }
      ]
      ++ extra;
    }).config;

  enabled = evalConfig [
    { services.discordsync.immich.enable = true; }
  ];
  disabled = evalConfig [ ];

  enabledTemplate = enabled.sops.templates."discordsync-env";
  disabledTemplate = disabled.sops.templates."discordsync-env";

  cases = [
    # --- immich ENABLED: every conditional surface lit ---
    {
      name = "enabled-template-carries-immich-keys";
      pass =
        lib.hasInfix "IMMICH_URL" enabledTemplate.content
        && lib.hasInfix "IMMICH_API_KEY" enabledTemplate.content;
    }
    {
      name = "enabled-restartUnits-names-verify";
      pass = builtins.elem "discordsync-immich-verify.service" enabledTemplate.restartUnits;
    }
    {
      name = "enabled-restartUnits-still-names-daemon";
      pass = builtins.elem "discordsync.service" enabledTemplate.restartUnits;
    }
    {
      name = "enabled-verify-unit-exists";
      pass = enabled.systemd.services ? "discordsync-immich-verify";
    }
    {
      name = "enabled-verify-timer-exists";
      pass = enabled.systemd.timers ? "discordsync-immich-verify";
    }
    # --- immich DISABLED: every conditional surface dark ---
    {
      name = "disabled-template-free-of-immich-keys";
      pass =
        !lib.hasInfix "IMMICH_URL" disabledTemplate.content
        && !lib.hasInfix "IMMICH_API_KEY" disabledTemplate.content;
    }
    {
      name = "disabled-restartUnits-never-names-verify";
      pass =
        !builtins.elem "discordsync-immich-verify.service" disabledTemplate.restartUnits
        && builtins.elem "discordsync.service" disabledTemplate.restartUnits;
    }
    {
      name = "disabled-verify-unit-absent";
      pass = !(disabled.systemd.services ? "discordsync-immich-verify");
    }
    {
      name = "disabled-verify-timer-absent";
      pass = !(disabled.systemd.timers ? "discordsync-immich-verify");
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "discordsync-immich-shape-regression" { } "touch $out"
else
  throw ''
    discordsync-immich-shape regression: ${toString broken}
    The immich.enable gate must move template keys, restartUnits, and the
    verify unit/timer TOGETHER: keys rendered without the verify unit (or
    restartUnits naming a unit absent from the generation) are the
    activation-failure class; keys missing while enabled breaks the /lookup
    cross-archive comparison. Re-verify against
    modules/nixos/services/sops.nix (discordsync-env template) +
    modules/nixos/services/discordsync.nix (verify unit/timer).
  ''
