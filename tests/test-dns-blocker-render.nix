# Render regression test for the dnsblockd wrapper (dns-blocker.nix).
# Pins the 2026-09-30 max-adoption gains against wrapper drift:
#   1. allowlist_path — permanent allowlist persistence (the data-loss fix:
#      without it every restart wipes all "Always allow" verdicts)
#   2. DNS rate limit 50/100 + log sampling 500/100 on evo-x2
#   3. extraDomains feeds the render — anti-phantom: a variant with
#      extraDomains = [] must produce a DIFFERENT config derivation; a dead
#      option (the pre-2026-09-30 state) renders byte-identically
#   4. tracking_mode stays METADATA_ONLY until the owner flips it (M09 gate
#      — an agent must never be able to flip this by accident)
#   5. policies (M14): inert on the host ([] renders NO policies key),
#      rendered verbatim when set, and every wrapper assertion (caps /
#      duplicates / targets / dangling refs / schedule shape / slug type)
#      fires on its matching violation at eval time
# Content checks grep the REAL rendered YAML, realized through the ExecStart
# string context — not a reconstruction of the generator.
{
  pkgs,
  inputs,
  ...
}:
let
  evox2 = inputs.self.nixosConfigurations.evo-x2.config;
  svc = evox2.systemd.services.dnsblockd;
  exec = svc.serviceConfig.ExecStart;

  noExtraExec =
    (inputs.self.nixosConfigurations.evo-x2.extendModules {
      # mkForce: a plain definition would CONCATENATE with the host's list
      # (listOf merge semantics) instead of replacing it.
      modules = [ { services.dns-blocker.extraDomains = pkgs.lib.mkForce [ ]; } ];
    }).config.systemd.services.dnsblockd.serviceConfig.ExecStart;

  policiesExec =
    (inputs.self.nixosConfigurations.evo-x2.extendModules {
      # Plain definition concatenates with the host's [] default — exactly
      # the merge we want here (host stays policy-free, variant adds one).
      modules = [
        {
          services.dns-blocker.policies = [
            {
              name = "tv-night";
              devices = [ "lg-tv" ];
              block = [
                "doubleclick.net"
                "ads.example.com"
              ];
              schedule = "22:00-07:00";
            }
          ];
        }
      ];
    }).config.systemd.services.dnsblockd.serviceConfig.ExecStart;

  # gate-timeout-audit pattern: force the variant's assertions and require
  # the one named by the message infix to be among the FAILED ones (message
  # strings are only coerced for failed assertions — short-circuit &&).
  policyAssertionFires =
    infix: modules:
    let
      fired = builtins.filter (
        a: !a.assertion && pkgs.lib.hasInfix infix a.message
      ) (inputs.self.nixosConfigurations.evo-x2.extendModules { inherit modules; }).config.assertions;
    in
    fired != [ ];

  # Bad slugs die at the option's strMatching type check — but submodule
  # field type errors are DEFERRED into the value (forcing the option or a
  # lazy builtins.map over it returns successfully), so the witness must
  # strictly force every name field (isString does). tryEval keeps the
  # error from aborting the whole check evaluation.
  policyOptionEvalFails =
    modules:
    let
      names = builtins.all (p: builtins.isString p.name)
        (inputs.self.nixosConfigurations.evo-x2.extendModules { inherit modules; }).config.services.dns-blocker.policies;
    in
    !(builtins.tryEval names).success;

  checks = [
    {
      ok = builtins.match ".*/bin/dnsblockd serve -c /nix/store/.+-dnsblockd-config.yaml" exec != null;
      msg = "dnsblockd ExecStart shape unexpected: ${toString exec}";
    }
    {
      ok =
        evox2.services.dns-blocker.dnsRateLimitPerSec == 50
        && evox2.services.dns-blocker.dnsRateLimitBurst == 100;
      msg = "evo-x2 DNS rate limit must stay 50/100 (DoS belt, 2026-09-30)";
    }
    {
      ok = evox2.services.dns-blocker.extraDomains != [ ];
      msg = "evo-x2 extraDomains unexpectedly empty — the systemnix-extra belt would vanish";
    }
    {
      ok = noExtraExec != exec;
      msg = "extraDomains no longer feeds the rendered config (phantom-option regression)";
    }
    {
      ok = svc.serviceConfig.StateDirectory == "dnsblockd";
      msg = "StateDirectory must stay dnsblockd (parent of allowlist_path)";
    }
    {
      ok = evox2.services.dns-blocker.policies == [ ];
      msg = "policies must default to [] on evo-x2 (M14 ships inert — no policy configured yet)";
    }
    {
      ok = policiesExec != exec;
      msg = "policies no longer feeds the rendered config (phantom-option regression)";
    }
    {
      ok = policyAssertionFires "exceeds upstream caps" [
        {
          services.dns-blocker.policies = [
            {
              name = "t";
              devices = [ "lg-tv" ];
              block = map (n: "d${toString n}.example.com") (pkgs.lib.range 1 513);
            }
          ];
        }
      ];
      msg = "512-domains-per-arc cap assertion does not fire";
    }
    {
      ok = policyAssertionFires "exceeds upstream caps" [
        {
          services.dns-blocker.policies = map (n: {
            name = "p${toString n}";
            devices = [ "lg-tv" ];
          }) (pkgs.lib.range 1 65);
        }
      ];
      msg = "64-policy cap assertion does not fire";
    }
    {
      ok = policyAssertionFires "duplicate names" [
        {
          services.dns-blocker.policies = [
            {
              name = "t";
              devices = [ "lg-tv" ];
            }
            {
              name = "t";
              devices = [ "evo-x2" ];
            }
          ];
        }
      ];
      msg = "duplicate-name assertion does not fire";
    }
    {
      ok = policyAssertionFires "must target at least one" [
        {
          services.dns-blocker.policies = [ { name = "t"; } ];
        }
      ];
      msg = "no-targets (ErrNoTargets) assertion does not fire";
    }
    {
      ok = policyAssertionFires "undeclared devices" [
        {
          services.dns-blocker.policies = [ { name = "t"; devices = [ "ghost" ]; } ];
        }
      ];
      msg = "dangling-device assertion does not fire";
    }
    {
      ok = policyAssertionFires "device groups" [
        {
          services.dns-blocker.policies = [ { name = "t"; groups = [ "kids" ]; } ];
        }
      ];
      msg = "dangling-group assertion does not fire (no declared device carries a group)";
    }
    {
      ok = policyAssertionFires "schedule must be" [
        {
          services.dns-blocker.policies = [
            {
              name = "t";
              devices = [ "lg-tv" ];
              schedule = "25:00-26:00";
            }
          ];
        }
      ];
      msg = "schedule-shape assertion does not fire (25:00-26:00 must be rejected)";
    }
    {
      ok = policyOptionEvalFails [
        {
          services.dns-blocker.policies = [
            {
              name = "TV_Night";
              devices = [ "lg-tv" ];
            }
          ];
        }
      ];
      msg = "slug type check accepts invalid names (strMatching regression)";
    }
  ];

  failed = builtins.filter (c: !c.ok) checks;
in
if failed != [ ] then
  pkgs.runCommand "dns-blocker-render-test" { } ''
    echo "dns-blocker render regression failures:"
    ${builtins.concatStringsSep "\n" (map (c: "echo ' - ${c.msg}'") failed)}
    exit 1
  ''
else
  pkgs.runCommand "dns-blocker-render-test"
    {
      # Interpolating exec pulls the config derivation (and its blocklist
      # dependencies) into this build — the greps run on the REAL file.
      inherit exec policiesExec;
    }
    ''
      CFG="''${exec#* -c }"
      PCFG="''${policiesExec#* -c }"
      fail() { echo "dns-blocker render content failure: $1"; exit 1; }
      [ -f "$CFG" ] || fail "rendered config not realized: $CFG"
      [ -f "$PCFG" ] || fail "variant config not realized: $PCFG"
      ${pkgs.python3}/bin/python3 - "$CFG" "$PCFG" <<'PYEOF' || fail "see python assert above"
      import json, sys
      cfg = json.load(open(sys.argv[1]))
      assert cfg["allowlist_path"] == "/var/lib/dnsblockd/allowlist", "allowlist_path must point at the persistent state file"
      assert cfg["log_sampling_threshold"] == 500, "log_sampling_threshold drifted"
      assert cfg["log_sampling_rate"] == 100, "log_sampling_rate drifted"
      assert cfg["dns_rate_limit_per_sec"] == 50, "dns_rate_limit_per_sec drifted"
      assert cfg["dns_rate_limit_burst"] == 100, "dns_rate_limit_burst drifted"
      assert any("systemnix-extra" in p for p in cfg["dns_blocklists"]), "systemnix-extra blocklist missing from dns_blocklists"
      assert cfg["tracking_mode"] == "METADATA_ONLY", "tracking_mode must stay METADATA_ONLY until the owner flips it"
      assert "policies" not in cfg, "host config must omit the policies key while the list is empty (optionalAttrs guard)"
      pol = json.load(open(sys.argv[2]))
      p0 = pol["policies"][0]
      assert p0["name"] == "tv-night", "policy name not rendered verbatim"
      assert p0["devices"] == ["lg-tv"], "policy devices not rendered verbatim"
      assert p0["groups"] == [], "per-policy empty groups must stay [] (upstream treats as no entries)"
      assert p0["allow"] == [], "per-policy empty allow must stay [] (upstream treats as no entries)"
      assert p0["block"] == ["doubleclick.net", "ads.example.com"], "policy block list not rendered verbatim"
      assert p0["schedule"] == "22:00-07:00", "policy schedule not rendered verbatim"
      print("content OK")
      PYEOF
      echo "dns-blocker render: allowlist persistence, rate limit, log sampling, extraDomains belt, tracking gate, policies option OK" > $out
    ''
