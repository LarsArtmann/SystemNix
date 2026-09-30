# Render regression test for the dnsblockd wrapper (dns-blocker.nix).
# Pins the 2026-09-30 max-adoption W1 gains against wrapper drift:
#   1. allowlist_path — permanent allowlist persistence (the data-loss fix:
#      without it every restart wipes all "Always allow" verdicts)
#   2. DNS rate limit 50/100 + log sampling 500/100 on evo-x2
#   3. extraDomains feeds the render — anti-phantom: a variant with
#      extraDomains = [] must produce a DIFFERENT config derivation; a dead
#      option (the pre-2026-09-30 state) renders byte-identically
#   4. tracking_mode stays METADATA_ONLY until the owner flips it (M09 gate
#      — an agent must never be able to flip this by accident)
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
      inherit exec;
    }
    ''
      CFG="''${exec#* -c }"
      fail() { echo "dns-blocker render content failure: $1"; exit 1; }
      [ -f "$CFG" ] || fail "rendered config not realized: $CFG"
      ${pkgs.python3}/bin/python3 - "$CFG" <<'PYEOF' || fail "see python assert above"
      import json, sys
      cfg = json.load(open(sys.argv[1]))
      assert cfg["allowlist_path"] == "/var/lib/dnsblockd/allowlist", "allowlist_path must point at the persistent state file"
      assert cfg["log_sampling_threshold"] == 500, "log_sampling_threshold drifted"
      assert cfg["log_sampling_rate"] == 100, "log_sampling_rate drifted"
      assert cfg["dns_rate_limit_per_sec"] == 50, "dns_rate_limit_per_sec drifted"
      assert cfg["dns_rate_limit_burst"] == 100, "dns_rate_limit_burst drifted"
      assert any("systemnix-extra" in p for p in cfg["dns_blocklists"]), "systemnix-extra blocklist missing from dns_blocklists"
      assert cfg["tracking_mode"] == "METADATA_ONLY", "tracking_mode must stay METADATA_ONLY until the owner flips it"
      print("content OK")
      PYEOF
      echo "dns-blocker render: allowlist persistence, rate limit, log sampling, extraDomains belt, tracking gate OK" > $out
    ''
