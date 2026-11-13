# Eval-time assertion: sops secrets for DynamicUser services MUST be
# root-owned (DynamicUser users do not exist at sops-decrypt time; a
# non-root owner blocks ALL secrets atomically — Gatus, crush-daily, Attic).
#
# DELEGATED (2026-11-13, SUPERB wave A1b): the auto-discovery walker and
# both violation halves (secrets + templates) live in the collection
# (github:LarsArtmann/nixos-modules, modules/dynamic-user-audit — a contract
# check + negative legs travel with it). NOTE: the collection version FIXED
# a latent guard bug this fleet never hit (both hosts import sops-nix):
# tryEval does NOT catch the missing-option error under Nix 2.34 — the
# guard is now `options ? sops.secrets`, importable on sops-less hosts.
{
  inputs,
  ...
}:
{
  flake.nixosModules.dynamic-user-audit = {
    imports = [ inputs.nixos-modules.nixosModules.dynamic-user-audit ];
  };
}
