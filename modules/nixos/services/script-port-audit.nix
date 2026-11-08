# Eval-time audit: every HOST-form port literal in the operational scripts
# tree must be a value from lib/ports.nix — the scripts-surface mirror of
# port-registry-audit (which gates systemd unit Exec/Environment text; its
# "the class lives in post-deploy-check.sh only" scope note closed here).
#
# Why this exists: scripts duplicating port truth drift silently. The FIRST
# sweep (2026-11-08, nix-native plan T5) caught exactly the motivating class:
#   - scripts/verify-deployment.sh probing gatus at 9110 — the port retired
#     by the 2026-10-27 band vacation (9110→9410): the gatus legs of that
#     script had been dead for 12 days with no signal
#   - scripts/llama-rag-soak.sh defaulting to unregistered 18848
#
# Matcher: HOST forms only (127.0.0.1:N / localhost N / 0.0.0.0:N) plus
# --port N / --port=N. The bare colon-form (":NNN") that port-registry-audit
# also scans is DELIBERATELY EXCLUDED here: prose-heavy scripts legitimately
# contain word:NNN tokens (timestamps 10:00, durations, exit codes, PSI
# values) and the FP volume drowns the signal (25 false fires on the first
# probe). The zero-padded-group drop in lib/default.nix's extractor exists
# for the same reason.
#
# Scan set: scripts/*.sh + scripts/lib/*.sh (top level only — fixture
# fixtures live under flake checks, out of this tree).
#
# Justified exceptions (deliberate test literals, protocol-fixed ports):
#   services.script-port-audit.allowPorts = [ 59999 ];  # + comment why
# Currently EMPTY: the 2026-11-08 sweep found every host-form literal in the
# tree either registered or fixed on the spot.
{
  flake.nixosModules.script-port-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.script-port-audit;

      registeredPorts = builtins.attrValues (import ../../../lib/ports.nix).ports;
      allowedPorts = registeredPorts ++ cfg.allowPorts;

      # Host + flag forms of lib/default.nix's extractPortLiterals, split
      # out of the shared extractor because the colon-form is prose-noisy on
      # this surface. Keep the group-drop (zero padding) semantics in sync.
      hostPortRegex = "((127\\.0\\.0\\.1|localhost|0\\.0\\.0\\.0)[: ]([0-9]{2,5})([^0-9]|$))|(--port[ =]([0-9]{2,5})([^0-9a-zA-Z]|$))";

      extractHostPortLiterals =
        text:
        let
          parts = builtins.split hostPortRegex text;
          digitGroups = builtins.filter (g: builtins.isString g && builtins.match "[0-9]+" g != null) (
            builtins.concatLists (map (x: if builtins.isList x then x else [ ]) parts)
          );
          portCandidates = builtins.filter (g: builtins.match "0[0-9]+" g == null) digitGroups;
        in
        lib.unique (
          builtins.filter (p: p >= 2 && p <= 65535) (map lib.toInt portCandidates)
        );

      scanDir =
        dir:
        let
          files = builtins.attrNames (builtins.readDir dir);
          shFiles = builtins.filter (f: lib.hasSuffix ".sh" f) files;
        in
        map (f: rec {
          name = f;
          text = builtins.readFile (dir + "/${f}");
          unregistered = builtins.filter (p: !builtins.elem p allowedPorts) (
            extractHostPortLiterals text
          );
        }) shFiles;

      scans = builtins.concatLists (map scanDir [
        ../../../scripts
        ../../../scripts/lib
      ]);

      offenders = builtins.filter (s: s.unregistered != [ ]) scans;

      offenderReport = lib.concatStringsSep "\n" (
        map (s: "  ${s.name}: ${lib.concatStringsSep ", " (map toString s.unregistered)}") offenders
      );
    in
    {
      options.services.script-port-audit = {
        allowPorts = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
          description = ''
            Port numbers exempt from the scripts-tree registry requirement
            (deliberate selftest fixtures, protocol-fixed ports that do not
            belong in lib/ports.nix). Every entry MUST carry a justification
            comment where it is set.
          '';
        };
      };

      config.assertions = [
        {
          assertion = offenders == [ ];
          message = ''
            script-port-audit: host-form port literal(s) in scripts/ not registered in lib/ports.nix:
            ${offenderReport}
            A script hardcoding a port drifts silently when the port moves
            (verify-deployment.sh probed gatus at the retired 9110 for 12
            days). Fix: reference the manifest ports instead
            (/etc/systemnix/integration-manifest.json — post-deploy-check.sh's
            m_port pattern), or add the port to lib/ports.nix, or — for a
            justified fixture — extend:
              services.script-port-audit.allowPorts = [ <port> ];
          '';
        }
      ];
    };
}
