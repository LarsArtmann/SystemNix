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
#   5. journal WAL enabled (owner decision 2026-10-07): journal_enabled
#      true + DSN inside the StateDirectory — koanf's CWD-relative default
#      would follow WorkingDirectory, but the absolute pin survives any
#      future WorkingDirectory change
#   6. policies (M14): inert on the host ([] renders NO policies key),
#      rendered verbatim when set, and every wrapper assertion (caps /
#      duplicates / targets / dangling refs / schedule shape / slug type)
#      fires on its matching violation at eval time
#   7. scoped filter proxy (ADR-0018): inert on the host (no
#      proxy_filter_domains key while empty), rendered verbatim when set,
#      inject URL rides the systemd env (DNSBLOCKD_PROXY_INJECT_SCRIPT_URL)
#      and NEVER the YAML (store is world-readable)
#   8. rpi3-dns parity (2026-10-28, plan T13): the secondary host shares this
#      module, so its DNS contract is pinned too — same port, same zero_ip
#      response, same 77-entry whitelist — while its DELIBERATE divergences
#      are pinned just as hard (different block IP, filter proxy OFF, no rate
#      limit). Asserted at EVAL level: rpi3-dns is aarch64-linux, so this
#      x86_64 host cannot realize its rendered config file (no aarch64
#      builder) — the option-level facts are what a cross-host drift breaks
#      first, and a file-level leg would need a remote builder to exist here.
#   9. gateway mode (ADR-0011, owner enablement 2026-11-06): the lie rides
#      blockIP (the block-page/splice listener answers there), the DoH
#      bypass preset stays armed, the OFF variant renders NO gateway key at
#      all (anti-phantom), and every wrapper gateway assertion fires on its
#      matching violation at eval time.
#  10. decrypt overlay (ADR-0021, owner enablement 2026-11-07 "MITM myself"):
#      URL-level capture scoped to the two CA-enrolled devices (evo-x2 +
#      macbook; the Pixel6 stays spliced — Android Chrome ignores user CA
#      certs), broad TLD-suffix domains, empty excludes (documented hatch);
#      the flow-only variant renders NO gateway_decrypt_* key (anti-phantom),
#      every decrypt assertion fires on its matching violation, and the LNA
#      browser policy (the lie IP reclassified public — fixes the PNA block
#      class for splice AND decrypt) stays pinned in both policy dirs.
# Content checks grep the REAL rendered YAML, realized through the ExecStart
# string context — not a reconstruction of the generator.
{
  pkgs,
  inputs,
  ...
}:
let
  evox2 = inputs.self.nixosConfigurations.evo-x2.config;
  rpi3 = inputs.self.nixosConfigurations.rpi3-dns.config;
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
              devices = [ "macbook" ];
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

  trialExec =
    (inputs.self.nixosConfigurations.evo-x2.extendModules {
      modules = [
        {
          services.dns-blocker.blocklistTrialUrls = [
            "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"
          ];
        }
      ];
    }).config.systemd.services.dnsblockd.serviceConfig.ExecStart;

  ecsExec =
    (inputs.self.nixosConfigurations.evo-x2.extendModules {
      modules = [
        {
          services.dns-blocker.dnsEcsEnabled = true;
          services.dns-blocker.dnsEcsIpv4PrefixLen = 24;
          services.dns-blocker.dnsEcsIpv6PrefixLen = 56;
        }
      ];
    }).config.systemd.services.dnsblockd.serviceConfig.ExecStart;

  h3Exec =
    (inputs.self.nixosConfigurations.evo-x2.extendModules {
      modules = [
        {
          services.dns-blocker.tlsH3Enabled = true;
        }
      ];
    }).config.systemd.services.dnsblockd.serviceConfig.ExecStart;

  filterSvc =
    (inputs.self.nixosConfigurations.evo-x2.extendModules {
      modules = [
        {
          services.dns-blocker.proxyFilterDomains = [ "porn.example.com" ];
          services.dns-blocker.proxyInjectScriptURL = "http://127.0.0.1:8104/inject/filter.js";
        }
      ];
    }).config.systemd.services.dnsblockd;
  filterExec = filterSvc.serviceConfig.ExecStart;

  pprofExec =
    (inputs.self.nixosConfigurations.evo-x2.extendModules {
      modules = [
        {
          services.dns-blocker.pprofEnabled = true;
        }
      ];
    }).config.systemd.services.dnsblockd.serviceConfig.ExecStart;

  gatewayOffExec =
    (inputs.self.nixosConfigurations.evo-x2.extendModules {
      # mkForce: the host ARMS the gateway (owner enablement 2026-11-06);
      # the OFF variant pins the inert render — no gateway key at all.
      modules = [ { services.dns-blocker.gatewayEnabled = pkgs.lib.mkForce false; } ];
    }).config.systemd.services.dnsblockd.serviceConfig.ExecStart;

  decryptOffExec =
    (inputs.self.nixosConfigurations.evo-x2.extendModules {
      # mkForce: the host ARMS the decrypt overlay (owner enablement
      # 2026-11-07); the OFF variant pins the flow-only render — no
      # gateway_decrypt_* key at all while the gateway itself stays armed.
      modules = [
        {
          services.dns-blocker.gatewayDecryptDomains = pkgs.lib.mkForce [ ];
          services.dns-blocker.gatewayDecryptDevices = pkgs.lib.mkForce [ ];
          services.dns-blocker.gatewayDecryptExcludeDomains = pkgs.lib.mkForce [ ];
        }
      ];
    }).config.systemd.services.dnsblockd.serviceConfig.ExecStart;

  # gate-timeout-audit pattern: force the variant's assertions and require
  # the one named by the message infix to be among the FAILED ones (message
  # strings are only coerced for failed assertions — short-circuit &&).
  # Generic across all wrapper assertions (not just policies) — the infix
  # names the rule.
  policyAssertionFires =
    infix: modules:
    let
      fired =
        builtins.filter (a: !a.assertion && pkgs.lib.hasInfix infix a.message)
          (inputs.self.nixosConfigurations.evo-x2.extendModules { inherit modules; }).config.assertions;
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
      names =
        builtins.all (p: builtins.isString p.name)
          (inputs.self.nixosConfigurations.evo-x2.extendModules { inherit modules; })
          .config.services.dns-blocker.policies;
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
      ok = evox2.services.dns-blocker.proxyFilterDomains == [ ];
      msg = "evo-x2 must keep the scoped filter proxy OFF (owner opt-in, ADR-0018)";
    }
    {
      ok = filterExec != exec;
      msg = "proxyFilterDomains no longer feeds the rendered config (phantom-option regression)";
    }
    {
      ok = pkgs.lib.hasInfix "DNSBLOCKD_PROXY_INJECT_SCRIPT_URL=http://127.0.0.1:8104/inject/filter.js" (
        toString filterSvc.serviceConfig.Environment
      );
      msg = "inject URL must ride the systemd env, never the YAML";
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
              devices = [ "macbook" ];
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
            devices = [ "macbook" ];
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
              devices = [ "macbook" ];
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
          services.dns-blocker.policies = [
            {
              name = "t";
              devices = [ "ghost" ];
            }
          ];
        }
      ];
      msg = "dangling-device assertion does not fire";
    }
    {
      ok = policyAssertionFires "device groups" [
        {
          services.dns-blocker.policies = [
            {
              name = "t";
              groups = [ "kids" ];
            }
          ];
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
              devices = [ "macbook" ];
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
              devices = [ "macbook" ];
            }
          ];
        }
      ];
      msg = "slug type check accepts invalid names (strMatching regression)";
    }
    {
      ok = evox2.services.dns-blocker.blocklistTrialUrls == [ ];
      msg = "blocklistTrialUrls must default to [] (M15 ships inert — shadow evaluation is opt-in)";
    }
    {
      ok = evox2.services.dns-blocker.blocklistCacheDir == "/var/lib/dnsblockd/blocklist-cache";
      msg = "blocklistCacheDir must default to the StateDirectory-backed persistent path (PrivateTmp eats upstream's /tmp default)";
    }
    {
      ok = trialExec != exec;
      msg = "blocklistTrialUrls no longer feeds the rendered config (phantom-option regression)";
    }
    {
      ok = policyAssertionFires "http(s) URLs with a host" [
        {
          services.dns-blocker.blocklistTrialUrls = [ "file:///etc/hosts" ];
        }
      ];
      msg = "trial-URL shape assertion does not fire (file:// must be rejected)";
    }
    {
      ok = policyAssertionFires "absolute path" [
        {
          services.dns-blocker.blocklistCacheDir = "relative/cache-dir";
        }
      ];
      msg = "cache-dir absolute-path assertion does not fire";
    }
    {
      ok = evox2.services.dns-blocker.dnsEcsEnabled == false;
      msg = "dnsEcsEnabled must default to false (M16 ships inert — owner-gated privacy tradeoff)";
    }
    {
      ok =
        evox2.services.dns-blocker.dnsEcsIpv4PrefixLen == 0
        && evox2.services.dns-blocker.dnsEcsIpv6PrefixLen == 0;
      msg = "ECS prefix lengths must default to 0 (upstream /24 and /56 defaults)";
    }
    {
      ok = ecsExec != exec;
      msg = "ECS options no longer feed the rendered config (phantom-option regression)";
    }
    {
      ok = policyAssertionFires "within the address family" [
        {
          services.dns-blocker.dnsEcsEnabled = true;
          services.dns-blocker.dnsEcsIpv4PrefixLen = 33;
        }
      ];
      msg = "ECS prefix-range assertion does not fire (IPv4 >32 must be rejected)";
    }
    {
      ok = evox2.services.dns-blocker.tlsH3Enabled == false;
      msg = "tlsH3Enabled must default to false (M17 ships inert — owner-gated QUIC toggle)";
    }
    {
      ok = h3Exec != exec;
      msg = "tlsH3Enabled no longer feeds the rendered config (phantom-option regression)";
    }
    {
      ok = policyAssertionFires "requires blockTLSPort > 0" [
        {
          # evo-x2 pins blockTLSPort = 443 at plain priority
          # (dns-blocker-config.nix) — override, don't concatenate.
          services.dns-blocker.tlsH3Enabled = true;
          services.dns-blocker.blockTLSPort = pkgs.lib.mkForce 0;
        }
      ];
      msg = "h3-without-tls-port assertion does not fire (upstream errH3RequiresTLSPort must be mirrored)";
    }
    {
      ok = policyAssertionFires "ErrFilterNeedsAddressResponse" [
        {
          services.dns-blocker.proxyFilterDomains = [ "porn.example.com" ];
          services.dns-blocker.dnsBlockResponse = "nxdomain";
        }
      ];
      msg = "filter-domains x nxdomain assertion does not fire (upstream ErrFilterNeedsAddressResponse must be mirrored)";
    }
    {
      ok = policyAssertionFires "proxyInjectScriptURL must be an http(s) URL" [
        {
          # Upstream SetInjectScript validates NOTHING (verified at lock rev
          # f9bb6477) — this wrapper assert is the only guard against a URL
          # the proxy would fail open on.
          services.dns-blocker.proxyInjectScriptURL = "/inject/filter.js";
        }
      ];
      msg = "scheme-less proxyInjectScriptURL assertion does not fire (a typo must not reach the runtime fail-open path)";
    }
    {
      ok =
        !(policyAssertionFires "proxyInjectScriptURL must be an http(s) URL" [
          {
            services.dns-blocker.proxyInjectScriptURL = "http://127.0.0.1:8104/inject/filter.js";
          }
        ]);
      msg = "well-formed proxyInjectScriptURL must NOT trip the shape assertion (false-positive guard)";
    }
    # ── Gateway mode (ADR-0011, owner enablement 2026-11-06) ──
    {
      ok = evox2.services.dns-blocker.gatewayEnabled;
      msg = "evo-x2 must keep the gateway ARMED (owner enablement 2026-11-06) — a silent flip-off would silently end household capture";
    }
    {
      ok = evox2.services.dns-blocker.gatewayIpv4 == evox2.services.dns-blocker.blockIP;
      msg = "the gateway lie must ride the block-page/splice listener address (blockIP) — anything else lands where nothing listens";
    }
    {
      ok = evox2.services.dns-blocker.gatewayBlockExternalDoh;
      msg = "gateway must keep the external-DoH bypass preset armed (without it devices can route encrypted DNS around the capture)";
    }
    {
      ok = gatewayOffExec != exec;
      msg = "gatewayEnabled no longer feeds the rendered config (phantom-option regression)";
    }
    {
      ok = policyAssertionFires "requires proxyEnabled" [
        {
          services.dns-blocker.gatewayEnabled = pkgs.lib.mkForce true;
          services.dns-blocker.proxyEnabled = pkgs.lib.mkForce false;
        }
      ];
      msg = "gateway-requires-proxy assertion does not fire";
    }
    {
      ok = policyAssertionFires "pins gatewayIpv4 == blockIP" [
        { services.dns-blocker.gatewayIpv4 = pkgs.lib.mkForce "192.168.1.250"; }
      ];
      msg = "lie-address==blockIP assertion does not fire";
    }
    {
      ok = policyAssertionFires "capped at 64" [
        {
          services.dns-blocker.gatewayLanRanges = map (
            # NB: this box's Nix (2.34.9) rejects BOTH the `mod` keyword and
            # the `%` token — remainder is spelled arithmetically here.
            n: "10.0.${toString (n / 256)}.${toString (n - (n / 256) * 256)}/32"
          ) (pkgs.lib.range 1 65);
        }
      ];
      msg = "64-lan-range cap assertion does not fire";
    }
    {
      ok = policyAssertionFires "0.0.0.0/0 or ::/0" [
        { services.dns-blocker.gatewayLanRanges = [ "0.0.0.0/0" ]; }
      ];
      msg = "any-range rejection assertion does not fire";
    }
    # ── Decrypt overlay (ADR-0021, owner enablement 2026-11-07) ──
    {
      ok = evox2.services.dns-blocker.gatewayDecryptDevices == [ "evo-x2" "macbook" ];
      msg = "decrypt device scope drifted: only the two CA-enrolled devices (evo-x2 + macbook) may terminate — the Pixel6 (Android Chrome ignores user CA certs) must stay spliced";
    }
    {
      ok = builtins.elem "com" evox2.services.dns-blocker.gatewayDecryptDomains;
      msg = "decrypt domain list lost the broad TLD suffixes (owner posture 2026-11-07: decrypt all general browsing for enrolled devices)";
    }
    {
      ok = decryptOffExec != exec;
      msg = "gatewayDecrypt* no longer feeds the rendered config (phantom-option regression)";
    }
    {
      ok = policyAssertionFires "requires gatewayEnabled" [
        { services.dns-blocker.gatewayEnabled = pkgs.lib.mkForce false; }
      ];
      msg = "decrypt-requires-gateway assertion does not fire (upstream gateway_decrypt_requires_gateway)";
    }
    {
      ok = policyAssertionFires "gateway_decrypt_requires_tls" [
        { services.dns-blocker.blockTLSPort = pkgs.lib.mkForce 0; }
      ];
      msg = "decrypt-requires-TLS-listener assertion does not fire (upstream gateway_decrypt_requires_tls)";
    }
    {
      ok = policyAssertionFires "declared services.dns-blocker.devices" [
        { services.dns-blocker.gatewayDecryptDevices = [ "ghost" ]; }
      ];
      msg = "decrypt unknown-device assertion does not fire (upstream gateway_decrypt_devices_known)";
    }
    {
      ok = policyAssertionFires "gatewayDecryptDomains/excludes capped at 256" [
        { services.dns-blocker.gatewayDecryptDomains = map (n: "d${toString n}.example") (pkgs.lib.range 1 257); }
      ];
      msg = "decrypt 256-entry cap assertion does not fire";
    }
    {
      ok = policyAssertionFires "devices at 64" [
        { services.dns-blocker.gatewayDecryptDevices = map (n: "dev${toString n}") (pkgs.lib.range 1 65); }
      ];
      msg = "decrypt 64-device cap assertion does not fire";
    }
    {
      # LNA browser policy pin: without the override, Chromium browsers lose
      # every lied subresource (the 2026-11-07 github-assets PNA class) in
      # splice AND decrypt postures — cert trust alone does not fix it.
      ok =
        (evox2.environment.etc ? "chromium/policies/managed/dnsblockd-lna.json"
          && pkgs.lib.hasInfix "=public" evox2.environment.etc."chromium/policies/managed/dnsblockd-lna.json".text)
        && (evox2.environment.etc ? "helium/policies/managed/dnsblockd-lna.json"
          && pkgs.lib.hasInfix "=public" evox2.environment.etc."helium/policies/managed/dnsblockd-lna.json".text);
      msg = "LNA address-space override policy missing — Chromium (Helium) browsing breaks under the lie for splice AND decrypt postures";
    }
    # ── rpi3-dns parity (secondary host, same module) ──
    {
      ok = rpi3.services.dns-blocker.enable;
      msg = "rpi3-dns must keep the blocker enabled — it is the VRRP failover resolver";
    }
    {
      ok =
        rpi3.services.dns-blocker.dnsBlockResponse == "zero_ip"
        && evox2.services.dns-blocker.dnsBlockResponse == rpi3.services.dns-blocker.dnsBlockResponse;
      msg = "the two hosts must answer blocked names identically (a failover must not change what a block MEANS)";
    }
    {
      ok = builtins.length rpi3.services.dns-blocker.whitelist == 77;
      msg = "rpi3 whitelist drifted from the shared 77-entry list (the permanent allowlist is judgement data, not per-host state)";
    }
    {
      ok = rpi3.services.dns-blocker.blockIP != evox2.services.dns-blocker.blockIP;
      msg = "the two hosts must answer blocked names with DIFFERENT addresses (otherwise a client cannot tell which resolver it reached)";
    }
    {
      ok = !rpi3.services.dns-blocker.proxyEnabled && evox2.services.dns-blocker.proxyEnabled;
      msg = "filter-proxy asymmetry changed: evo-x2 runs it and rpi3 does not — if rpi3 ever serves filtered domains the lie resolves to a host with no proxy (docs/services/dnsblockd.md 'Failover asymmetry')";
    }
    {
      ok = rpi3.services.dns-blocker.dnsRateLimitPerSec == 0;
      msg = "rpi3 lost its rate-limit exemption (0 = unlimited); a failover with a 50/s cap would throttle every client during an evo-x2 outage";
    }
    {
      ok = rpi3.services.dns-blocker.tempAllowAll == false;
      msg = "rpi3 must never ship with tempAllowAll — the failover host blocking nothing is worse than being down";
    }
    {
      ok = !rpi3.services.dns-blocker.gatewayEnabled && evox2.services.dns-blocker.gatewayEnabled;
      msg = "gateway asymmetry changed: the lie is evo-x2-only — a lying failover peer would flip-flop the household between capture and truth with VRRP (docs/services/dnsblockd.md gateway section)";
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
      inherit
        exec
        policiesExec
        trialExec
        ecsExec
        h3Exec
        filterExec
        pprofExec
        gatewayOffExec
        decryptOffExec
        ;
    }
    ''
      CFG="''${exec#* -c }"
      PCFG="''${policiesExec#* -c }"
      TCFG="''${trialExec#* -c }"
      ECFG="''${ecsExec#* -c }"
      fail() { echo "dns-blocker render content failure: $1"; exit 1; }
      H3CFG="''${h3Exec#* -c }"
      FCFG="''${filterExec#* -c }"
      PPCFG="''${pprofExec#* -c }"
      GOCFG="''${gatewayOffExec#* -c }"
      DOCFG="''${decryptOffExec#* -c }"
      [ -f "$CFG" ] || fail "rendered config not realized: $CFG"
      [ -f "$PCFG" ] || fail "variant config not realized: $PCFG"
      [ -f "$TCFG" ] || fail "trial variant config not realized: $TCFG"
      [ -f "$ECFG" ] || fail "ecs variant config not realized: $ECFG"
      [ -f "$H3CFG" ] || fail "h3 variant config not realized: $H3CFG"
      [ -f "$FCFG" ] || fail "filter variant config not realized: $FCFG"
      [ -f "$PPCFG" ] || fail "pprof variant config not realized: $PPCFG"
      [ -f "$GOCFG" ] || fail "gateway-off variant config not realized: $GOCFG"
      [ -f "$DOCFG" ] || fail "decrypt-off variant config not realized: $DOCFG"
      ${pkgs.python3}/bin/python3 - "$CFG" "$PCFG" "$TCFG" "$ECFG" "$H3CFG" "$FCFG" "$PPCFG" "$GOCFG" "$DOCFG" <<'PYEOF' || fail "see python assert above"
      import json, sys
      cfg = json.load(open(sys.argv[1]))
      assert cfg["allowlist_path"] == "/var/lib/dnsblockd/allowlist", "allowlist_path must point at the persistent state file"
      assert cfg["log_sampling_threshold"] == 500, "log_sampling_threshold drifted"
      assert cfg["log_sampling_rate"] == 100, "log_sampling_rate drifted"
      assert cfg["dns_rate_limit_per_sec"] == 50, "dns_rate_limit_per_sec drifted"
      assert cfg["dns_rate_limit_burst"] == 100, "dns_rate_limit_burst drifted"
      assert any("systemnix-extra" in p for p in cfg["dns_blocklists"]), "systemnix-extra blocklist missing from dns_blocklists"
      assert cfg["tracking_mode"] == "METADATA_ONLY", "tracking_mode must stay METADATA_ONLY until the owner flips it"
      assert cfg["journal_enabled"] is True, "journal WAL must stay enabled on the host (owner decision 2026-10-07, dnsblockd T354 precondition)"
      assert cfg["journal_dsn"] == "/var/lib/dnsblockd/journal.db", "journal DSN must stay inside the StateDirectory (koanf default is CWD-relative)"
      assert "policies" not in cfg, "host config must omit the policies key while the list is empty (optionalAttrs guard)"
      assert cfg["dns_blocklist_cache_dir"] == "/var/lib/dnsblockd/blocklist-cache", "persistent URL-blocklist cache dir missing from host config (PrivateTmp outage guard)"
      assert cfg["dns_ecs_enabled"] is False, "dns_ecs_enabled must default to false on the host (M16 inert gate)"
      assert "dns_ecs_ipv4_prefix_len" not in cfg, "host config must omit ECS prefix lengths at 0 (upstream defaults apply)"
      assert "dns_ecs_ipv6_prefix_len" not in cfg, "host config must omit ECS prefix lengths at 0 (upstream defaults apply)"
      assert "dns_blocklist_trial_urls" not in cfg, "host config must omit trial URLs while the list is empty (optionalAttrs guard)"
      pol = json.load(open(sys.argv[2]))
      p0 = pol["policies"][0]
      assert p0["name"] == "tv-night", "policy name not rendered verbatim"
      assert p0["devices"] == ["macbook"], "policy devices not rendered verbatim"
      assert p0["groups"] == [], "per-policy empty groups must stay [] (upstream treats as no entries)"
      assert p0["allow"] == [], "per-policy empty allow must stay [] (upstream treats as no entries)"
      assert p0["block"] == ["doubleclick.net", "ads.example.com"], "policy block list not rendered verbatim"
      assert p0["schedule"] == "22:00-07:00", "policy schedule not rendered verbatim"
      trial = json.load(open(sys.argv[3]))
      assert trial["dns_blocklist_trial_urls"] == ["https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"], "trial URLs not rendered verbatim"
      assert trial["dns_blocklist_cache_dir"] == "/var/lib/dnsblockd/blocklist-cache", "trial variant lost the persistent cache dir"
      ecs = json.load(open(sys.argv[4]))
      assert ecs["dns_ecs_enabled"] is True, "ECS enable flag not rendered"
      assert ecs["dns_ecs_ipv4_prefix_len"] == 24, "IPv4 ECS prefix not rendered verbatim"
      assert ecs["dns_ecs_ipv6_prefix_len"] == 56, "IPv6 ECS prefix not rendered verbatim"
      assert cfg["tls_h3_enabled"] is False, "tls_h3_enabled must default to false on the host (M17 inert gate)"
      h3 = json.load(open(sys.argv[5]))
      assert h3["tls_h3_enabled"] is True, "tls_h3_enabled enable flag not rendered"
      assert h3["tls_port"] == 443, "h3 variant lost the default tls_port (QUIC terminates on the same port number)"
      assert "proxy_filter_domains" not in cfg, "host config must omit proxy_filter_domains while the filter proxy is OFF (owner opt-in)"
      assert cfg["proxy_tls_passthrough"] is True, "proxy_tls_passthrough drifted from the upstream splice default"
      assert cfg["proxy_inject_strip_csp"] is True, "proxy_inject_strip_csp drifted from the upstream default"
      assert "proxy_inject_script_url" not in cfg, "inject URL leaked into the YAML (must ride the env only — store is world-readable)"
      filt = json.load(open(sys.argv[6]))
      assert filt["proxy_filter_domains"] == ["porn.example.com"], "filter domains not rendered verbatim"
      assert "proxy_inject_script_url" not in filt, "inject URL leaked into the YAML on the filter variant too"
      assert "pprof_enabled" not in cfg, "host config must omit pprof_enabled while the switch is OFF (optionalAttrs guard)"
      pprof = json.load(open(sys.argv[7]))
      assert pprof["pprof_enabled"] is True, "pprof_enabled enable flag not rendered"
      assert pprof["stats_addr"] == "127.0.0.1", "pprof rides the loopback stats listener \u2014 a widened stats_addr would expose profiles"
      assert cfg["gateway_enabled"] is True, "gateway_enabled missing from the host render (ADR-0011 capture would silently be OFF)"
      assert cfg["gateway_mode"] == "flow", "gateway_mode drifted from the only implemented capture posture"
      assert cfg["gateway_ipv4"] == cfg["dns_block_ip"], "gateway lie address must equal the block page address (the splice listener answers there)"
      assert cfg["gateway_ttl"] == 60 and cfg["gateway_max_connections"] == 2048, "gateway ttl/max_connections drifted from upstream defaults"
      assert cfg["gateway_block_external_doh"] is True, "external-DoH bypass preset lost from the gateway render"
      assert cfg["gateway_lan_ranges"] == ["192.168.1.0/24"], "gateway lan range must be the LAN subnet (SSRF-floor widening for hairpin dials)"
      assert "gateway_ipv6" not in cfg, "gateway_ipv6 must stay unrendered while null (AAAA answers empty NOERROR while lying)"
      goff = json.load(open(sys.argv[8]))
      assert "gateway_enabled" not in goff, "gateway OFF variant still renders gateway keys (phantom-option regression)"
      assert "com" in cfg["gateway_decrypt_domains"], "decrypt domain list must carry the broad TLD suffixes (owner posture 2026-11-07)"
      assert cfg["gateway_decrypt_devices"] == ["evo-x2", "macbook"], "decrypt device scope drifted from the two CA-enrolled devices"
      assert cfg["gateway_decrypt_exclude_domains"] == [], "decrypt excludes must render [] (escape hatch documented, not pre-seeded)"
      doff = json.load(open(sys.argv[9]))
      assert doff["gateway_enabled"] is True, "decrypt-OFF variant must keep the gateway itself armed (flow-only posture)"
      assert "gateway_decrypt_domains" not in doff and "gateway_decrypt_devices" not in doff and "gateway_decrypt_exclude_domains" not in doff, "decrypt-OFF variant still renders gateway_decrypt_* keys (phantom-option regression)"
      print("content OK")
      PYEOF
      echo "dns-blocker render: allowlist persistence, rate limit, log sampling, extraDomains belt, tracking gate, journal WAL, policies, trial blocklists, ECS, h3, pprof, gateway mode, decrypt overlay, LNA policy, rpi3 parity OK" > $out
    ''
