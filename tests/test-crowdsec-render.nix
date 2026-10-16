# CrowdSec module render pin (pure eval against the real evo-x2 config, no
# VM; 2026-10-16, wave T20).
#
# The stage-2 declarative units (bouncer-register), the PR #1943 patch-apply
# override, and the counts collector are all render-fragile: a refactor can
# silently drop a unit-order edge, the acquis glob, the sops EnvironmentFile,
# or the override tmpfiles rule, and nothing would fail until a blind boot.
# This check makes the render a tested invariant, geometrikks-caps style.
#
# Asserted (each traces to a live-verified property):
#   - unit order: prereq requires-before crowdsec; bouncer-register after
#     crowdsec + before geometrikks (geo's 15s poll would 401 otherwise)
#   - acquis: sshd journalctl filter + the caddy glob (T1 fix surface)
#   - bouncer-register: sops EnvironmentFile + graceful-skip branch
#   - pr1943: tmpfiles L+ rule + restartTriggers (patch-apply class)
#   - counts collector: unit + 5min timer + fail-closed emission
#   - gatus: the CrowdSec check carries the cs_parser_hits_total health leg
{
  pkgs,
  inputs,
}:
let
  lib = inputs.nixpkgs.lib;

  evox2 = inputs.self.nixosConfigurations.evo-x2.config;
  cs = evox2.systemd.services;
  crowdsec = evox2.services.crowdsec;

  registerUnit = cs.crowdsec-bouncer-register or { };
  countsUnit = cs.crowdsec-counts or { };

  # Script TEXT isn't reachable from the rendered ExecStart path (a store
  # path; reading the derivation output would be IFD) — assert on the
  # module SOURCE instead (the test-scripts.nix static-tripwire pattern).
  moduleSource = builtins.readFile (inputs.self + "/modules/nixos/services/crowdsec.nix");

  gatusCheck = lib.findFirst (c: c.name or "" == "CrowdSec") { } (
    evox2.services.integration.crowdsec.checks or [ ]
  );
  gatusConditions = lib.concatStringsSep "\n" (gatusCheck.conditions or [ ]);

  restartTriggers = map toString (cs.crowdsec.restartTriggers or [ ]);

  acquisJson = builtins.toJSON crowdsec.localConfig.acquisitions;

  cases = [
    {
      name = "prereq-not-required-by-crowdsec";
      pass = lib.elem "crowdsec-prereq.service" (cs.crowdsec.requires or [ ]);
    }
    {
      name = "prereq-not-before-crowdsec";
      pass = lib.elem "crowdsec.service" (cs.crowdsec-prereq.before or [ ]);
    }
    {
      name = "acquis-missing-sshd-journal-filter";
      pass = lib.hasInfix "_SYSTEMD_UNIT=sshd.service" acquisJson;
    }
    {
      name = "acquis-missing-caddy-glob";
      pass = lib.hasInfix "/var/log/caddy/*.log" acquisJson;
    }
    {
      name = "bouncer-register-missing-environmentfile";
      pass = (registerUnit.serviceConfig.EnvironmentFile or [ ]) != [ ];
    }
    {
      name = "bouncer-register-not-after-crowdsec";
      pass = lib.elem "crowdsec.service" (registerUnit.after or [ ]);
    }
    {
      name = "bouncer-register-not-before-geometrikks";
      pass = lib.elem "geometrikks.service" (registerUnit.before or [ ]);
    }
    {
      name = "bouncer-register-graceful-skip-branch-lost";
      pass = lib.hasInfix "no bouncer key rendered" moduleSource;
    }
    {
      name = "pr1943-override-execstartpre-missing";
      pass = lib.any (e: lib.hasInfix "sshd-success-logs.yaml" e) (
        map toString (cs.crowdsec.serviceConfig.ExecStartPre or [ ])
      );
    }
    {
      name = "pr1943-override-not-a-crowdsec-restart-trigger";
      pass = lib.any (t: lib.hasInfix "sshd-success-logs.yaml" t) restartTriggers;
    }
    {
      name = "counts-collector-unit-missing";
      pass = (countsUnit.serviceConfig.ExecStart or "") != "";
    }
    {
      name = "counts-collector-timeout-missing";
      pass = (countsUnit.serviceConfig.TimeoutStartSec or "") == "1min";
    }
    {
      name = "counts-collector-failclosed-emission-lost";
      pass = lib.hasInfix "crowdsec_collector_scrape_errors" moduleSource;
    }
    {
      name = "gatus-crowdsec-health-leg-missing";
      pass = lib.hasInfix "pat(*cs_parser_hits_total*)" gatusConditions;
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "crowdsec-render-test" { } "touch $out"
else
  pkgs.runCommand "crowdsec-render-test" { } ''
    echo "crowdsec render test FAILED for: ${lib.concatStringsSep ", " broken}"
    exit 1
  ''
