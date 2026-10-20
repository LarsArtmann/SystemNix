# Eval-time render test for the P0 failure-notification Discord path
# (2026-10-12 outage class: the 8-min sole-resolver outage's ONLY signal was
# one DND-suppressible desktop toast — P0 units must additionally page the
# Discord webhook DIRECTLY, not via gatus, because gatus itself is a P0 unit
# whose checks died in the same window).
#
# Pins:
#   1. the notify-failure-p0@ template unit exists on evo-x2
#   2. dnsblockd / gatus / clickhouse / signoz carry BOTH OnFailure entries
#      (desktop toast kept + Discord added) with no duplicates
#   3. a routine desktop unit (crush-update-providers) does NOT Discord-page
#   4. the sops template exists and renders ONLY DISCORD_WEBHOOK_URL
#      (tq-agent-pool-env doctrine: no multi-key env leak into a unit that
#      fires for arbitrary failing units)
#   5. the template unit actually consumes that env file (EnvironmentFile)
{
  pkgs,
  inputs,
  ...
}:
let
  evo = inputs.self.nixosConfigurations.evo-x2.config;
  svc = evo.systemd.services;
  p0Entry = "notify-failure-p0@%n.service";
  toastEntry = "notify-failure@%n.service";
  p0Units = [
    "dnsblockd"
    "gatus"
    "clickhouse"
    "signoz"
  ];
  nonP0Witness = "crush-update-providers";
  p0Env = evo.sops.templates."notify-failure-p0-env";

  p0UnitChecks = map (u: {
    ok =
      builtins.elem toastEntry svc.${u}.onFailure
      && builtins.elem p0Entry svc.${u}.onFailure
      && builtins.length (builtins.filter (e: e == p0Entry) svc.${u}.onFailure) == 1;
    msg = "${u} must carry OnFailure = [desktop toast + notify-failure-p0, p0 exactly once] (got: ${
      builtins.toJSON svc.${u}.onFailure
    })";
  }) p0Units;

  checks = [
    {
      ok = svc ? "notify-failure-p0@";
      msg = "notify-failure-p0@ template unit missing from evo-x2 (platforms/nixos/system/scheduled-tasks.nix)";
    }
    {
      ok = evo.sops.templates ? "notify-failure-p0-env";
      msg = "sops template notify-failure-p0-env missing (modules/nixos/services/sops.nix)";
    }
    {
      ok = svc."notify-failure-p0@".serviceConfig.EnvironmentFile == [ p0Env.path ];
      msg = "notify-failure-p0@ does not consume the notify-failure-p0-env sops template via EnvironmentFile";
    }
    {
      ok = pkgs.lib.hasInfix "DISCORD_WEBHOOK_URL=" p0Env.content;
      msg = "notify-failure-p0-env template does not render DISCORD_WEBHOOK_URL";
    }
    {
      ok =
        !pkgs.lib.hasInfix "PAPDASHBOARD_INGEST_KEY" p0Env.content
        && !pkgs.lib.hasInfix "CV_API_KEY" p0Env.content
        && !pkgs.lib.hasInfix "PAPERLESS_TOKEN" p0Env.content
        && !pkgs.lib.hasInfix "PAP_API_KEY" p0Env.content;
      msg = "notify-failure-p0-env leaked a foreign secret key (one-key template doctrine)";
    }
    {
      ok = svc."notify-failure-p0@".serviceConfig.Type or "" == "oneshot";
      msg = "notify-failure-p0@ must be Type=oneshot";
    }
    {
      ok = pkgs.lib.hasInfix "notify-failure-p0" (svc."notify-failure-p0@".serviceConfig.ExecStart);
      msg = "notify-failure-p0@ ExecStart does not run the notify-failure-p0 script";
    }
  ] ++ p0UnitChecks ++ [
    {
      ok =
        builtins.elem toastEntry svc.${nonP0Witness}.onFailure
        && !builtins.elem p0Entry svc.${nonP0Witness}.onFailure;
      msg = "${nonP0Witness} (routine desktop unit) must NOT Discord-page — P0 wiring leaked beyond the named units";
    }
  ];

  failed = map (c: c.msg) (builtins.filter (c: !c.ok) checks);
in
pkgs.runCommand "notify-p0-render"
  {
    passAsFile = [ "failedJson" ];
    failedJson = builtins.toJSON failed;
  }
  (
    pkgs.lib.optionalString (failed != [ ]) ''
      echo "P0 notify wiring broken:" >&2
      cat "$failedJsonPath" >&2
      exit 1
    ''
    + ''
      echo "notify-p0 render: template unit + dnsblockd/gatus/clickhouse/signoz dual OnFailure + non-P0 witness + one-key env OK" > $out
    ''
  )
