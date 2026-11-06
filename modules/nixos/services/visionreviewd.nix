# Runbook: docs/services/visionreviewd.md
# visionreviewd — SystemNix wrapper around the upstream nixos-module.
#
# The upstream module (inputs.vision-review-agent.nixosModules.visionreviewd)
# provides every option (enable, package, configFile, llamaServer.{enable,
# package, model, port}) plus the hardened systemd units. This file layers
# only the SystemNix-specific concerns on top: the package from the flake
# input, the registered llama port, failure-alert routing, and the
# service-integration registry entry (system-health unit-state monitoring).
#
# No HTTP surface: the daemon writes markdown reviews and talks to the model
# endpoint over loopback, so the registry entry is monitored-only (no vHost,
# no Gatus check — probing llama-vlm's socket-activated captioner would
# defeat its idle-unload TTL by keeping the model permanently resident).
# Returned 2026-09-22 against an input rev that ships the module (the
# 2026-08-18 `or null` lazy guard from the first integration is gone by
# design — see bd580b96 for why the guard existed and was removed).
{ inputs, ... }: {
  flake.nixosModules.visionreviewd =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        onFailure
        ports
        ;
      cfg = config.services.vision-review-agent;
    in
    {
      imports = [ inputs.vision-review-agent.nixosModules.visionreviewd ];

      config = lib.mkIf cfg.enable {
        services.vision-review-agent = {
          # vendorHash shim DROPPED (2026-11-03): upstream 59cc272 bakes
          # the through-our-lock hash hTFMWUh… in vendorHash.nix (proven:
          # detached-worktree `nix build .#visionreviewd` green at that
          # rev; the 2026-10-07 shim value q+Mb6q… had gone stale the
          # other way — it overrode the now-correct upstream hash and was
          # the sole float-register RED of the 2026-11-03 lift wave).
          # Re-add ONLY via nix-hash-fix evidence, never by hand.
          # RE-ADDED 2026-11-06 lock float: vision-review-agent@4520467
          # upstream-baked oPfsexE… stale through our lock (got NAkDPYu…,
          # float-proof-20261106-000533.log). doCheck = false (same wave):
          # TestRunReplayRebuildsReviewsDir is sandbox-FLAKY — the identical
          # drv passed checkPhase in float-proof-20261106-012906.log and
          # failed in float-proof-20261106-014324.log (replayed review file
          # absent under /build); upstream test fix queued
          # (docs/todo/upstream.md).
          package = lib.mkDefault (
            inputs.vision-review-agent.packages.${pkgs.stdenv.hostPlatform.system}.visionreviewd.overrideAttrs {
              vendorHash = "sha256-NAkDPYu+H8KoJiE2qEqqxvH9v/79if18ZMs7W4KDkTY=";
              doCheck = false;
            }
          );
          llamaServer.port = lib.mkDefault ports.visionreviewd-llama;
        };

        # Route unit failures into the notify-failure template (every other
        # long-running service does this; upstream ships no OnFailure).
        # UNIT-level, never serviceConfig: OnFailure is a [Unit] key —
        # nested in [Service] systemd logs "Unknown key 'OnFailure' in
        # section [Service], ignoring" on every boot and the escalation
        # silently never arms (live since the 2026-10-06 wiring; journal
        # evidence in docs/status/2026-10-06_22-18 §e.4).
        systemd.services.visionreviewd.onFailure = onFailure;

        services.integration = lib.optionalAttrs (options ? services.integration) {
          visionreviewd = {
            inherit (cfg) enable;
            vHost.layer = "none";
            monitored = true;
          };
        };
      };
    };
}
