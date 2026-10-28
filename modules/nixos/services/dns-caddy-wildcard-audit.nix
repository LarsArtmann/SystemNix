# Eval-time pairing guard (2026-10-28 plan T22): the `*.home.lan` DNS
# wildcard exists ONLY so an unknown name reaches Caddy's catch-all and gets
# the branded 404 instead of a resolver error. Either half alone is a lie:
#
#   - wildcard record WITHOUT the catch-all vHost — the name resolves, the
#     browser connects to a Caddy with no matching site, and the visitor gets
#     a TLS/connection error instead of the 404 page. This was live for five
#     days (2026-10-07 → 10-12) from the other direction (the wildcard was
#     configured but dead upstream) and nobody noticed until a human probed.
#   - catch-all vHost WITHOUT the wildcard — unreachable config, and the
#     Gatus "Caddy catch-all regressed" check can never pass.
#
# Both surfaces move independently (`localRecords` in
# platforms/nixos/system/dns-blocker-config.nix, `virtualHosts` in
# modules/nixos/services/caddy.nix), so nothing but this assertion ties them.
#
# The cloud domain is the documented exception: its zone is explicit-record
# only BY DESIGN (one namespace for the VPN alias set) while Caddy still
# serves a catch-all there, so its pairing is inverted on purpose and listed
# in `allowCatchAllWithoutWildcard`.
_: {
  flake.nixosModules.dns-caddy-wildcard-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.dns-caddy-wildcard-audit;

      domain = config.networking.domain or "home.lan";
      localRecords = config.services.dns-blocker.localRecords or { };
      vhostNames = builtins.attrNames (config.services.caddy.virtualHosts or { });

      wildcardRecordFor = d: "*.${d}.";
      # Caddy vHost keys are URL-ish ("https://*.home.lan"), sometimes with a
      # port — substring match on the domain is what the repo already uses to
      # find them, and a false positive would have to be a vHost that merely
      # CONTAINS the domain name.
      hasCatchAllFor = d: lib.any (n: lib.hasInfix "*.${d}" n) vhostNames;
      hasWildcardRecordFor = d: builtins.hasAttr (wildcardRecordFor d) localRecords;

      # Every domain that carries a catch-all vHost, derived from the config
      # itself rather than hardcoded, so a new one is paired automatically.
      catchAllDomains = builtins.filter hasCatchAllFor [ domain ] ++ cfg.extraPairedDomains;
    in
    {
      options.services.dns-caddy-wildcard-audit = {
        extraPairedDomains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Additional zones whose `*.<domain>` catch-all vHost must be paired
            with a `*.<domain>.` local record (checked in both directions).
          '';
        };
        allowCatchAllWithoutWildcard = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Domains whose catch-all vHost is DELIBERATE while the DNS zone
            stays explicit-record only (the split-horizon cloud zone). Every
            entry needs a comment at the definition site saying why.
          '';
        };
      };

      config.assertions = [
        {
          assertion =
            !(config.services.dns-blocker.enable or false)
            || !(config.services.caddy.enable or false)
            || hasWildcardRecordFor domain == hasCatchAllFor domain;
          message = ''
            dns-caddy-wildcard-audit: the `*.${domain}` DNS wildcard and Caddy's
            `*.${domain}` catch-all have drifted apart.
              wildcard record present:  ${toString (hasWildcardRecordFor domain)}
              catch-all vHost present:  ${toString (hasCatchAllFor domain)}
            Half the pair is not a smaller feature — it is a broken page:
            with only the record, unknown names resolve to a Caddy that has no
            site for them (browser error, not the branded 404); with only the
            vHost, nobody can reach the catch-all at all. Fix both in the same
            commit: platforms/nixos/system/dns-blocker-config.nix (localRecords)
            and modules/nixos/services/caddy.nix (the catch-all vHost).
          '';
        }
        {
          assertion = lib.all (
            d: hasWildcardRecordFor d || builtins.elem d cfg.allowCatchAllWithoutWildcard
          ) catchAllDomains;
          message = ''
            dns-caddy-wildcard-audit: catch-all vHost(s) exist for a zone with no
            `*.<domain>.` local record and no documented exemption.
            Unpaired zones: ${
              lib.concatStringsSep ", " (
                builtins.filter (
                  d: !hasWildcardRecordFor d && !builtins.elem d cfg.allowCatchAllWithoutWildcard
                ) catchAllDomains
              )
            }
            Either add the wildcard record (so the catch-all is reachable) or
            list the domain in services.dns-caddy-wildcard-audit
            .allowCatchAllWithoutWildcard WITH a comment explaining why the zone
            stays explicit-record only.
          '';
        }
      ];
    };
}
