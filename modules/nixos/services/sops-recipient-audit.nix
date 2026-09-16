# Eval-time guard: every encrypted secrets file must carry EXACTLY the age
# recipients its .sops.yaml creation rule mandates. None missing, none stale.
#
# Incident class this closes (live since 2026-06): .sops.yaml is supposed to
# gain a second recipient (rpi3-dns for dns-failover.yaml and the dnsblockd
# files, per the commented key block) but `sops updatekeys` was never run,
# so the encrypted files still carry only evo-x2. The sibling
# sops-key-audit cannot catch this shape: it verifies declared key NAMES
# against the files. Recipient coverage is a file-vs-.sops.yaml property,
# and recipient lines are PLAINTEXT inside each file's `sops:` metadata
# tail, so coverage needs no age key: a pure line-scan of the encrypted
# YAML plus .sops.yaml at eval time.
#
# Without this guard the failure mode is the worst kind: every gate green
# at eval, the deploy dies at ACTIVATION on the target host
# ("sops-install-secrets: ... no identity matched any of the recipients")
# after a full build, on a machine you cannot reach from the desk.
#
# Semantics (mirrors the sops CLI):
#   - FIRST creation rule whose path_regex matches the file wins.
#   - If ANY rule regex cannot be parsed by Nix's regex engine, the audit
#     goes inert (emits nothing): it cannot prove which rule is first for
#     any file. No false positives over exotic Go-only regex constructs.
#   - A secrets file matching NO rule is flagged (sops itself refuses to
#     encrypt a file with no matching creation rule).
#   - Rules resolving to zero age recipients (pgp-only) do not constrain.
#   - Dotfiles and non-.yaml files in the secrets dir are ignored.
#
# Negative test: tests/test-sops-recipient-audit.nix
{
  flake.nixosModules.sops-recipient-audit =
    {
      config,
      lib,
      ...
    }:
    {
      options.services.sops-recipient-audit = {
        sopsYaml = lib.mkOption {
          type = lib.types.path;
          default = ./../../../.sops.yaml;
          description = "The .sops.yaml whose creation_rules mandate recipients (test injection point).";
        };
        secretsDir = lib.mkOption {
          type = lib.types.path;
          default = ./../../../platforms/nixos/secrets;
          description = "Directory of encrypted secret files to audit (test injection point).";
        };
      };

      config =
        let
          cfg = config.services.sops-recipient-audit;

          contentLines =
            file:
            builtins.filter (l: builtins.match "[[:space:]]*(#.*|$)" l == null) (
              builtins.filter builtins.isString (builtins.split "\n" (builtins.readFile file))
            );

          ageRecipient = "age1[a-z0-9]+";

          # keys: block anchors of the form `- &name age1...`
          anchors = builtins.listToAttrs (
            map
              (l: {
                name = builtins.elemAt l 0;
                value = builtins.elemAt l 1;
              })
              (
                builtins.filter (l: l != null) (
                  map (l: builtins.match "[[:space:]]*- &([A-Za-z0-9_-]+) (${ageRecipient})" l) (
                    contentLines cfg.sopsYaml
                  )
                )
              )
          );

          # creation_rules as { regex, refs } chunks: a rule opens at
          # `- path_regex: <regex>`; bare `- *anchor` / `- age1...` list
          # items inside the chunk are its recipients. All other lines are
          # ignored, so the keys: block (which precedes any rule) is inert.
          ruleStart = l: builtins.match "[[:space:]]*- path_regex:[[:space:]]*([^[:space:]]+)" l;
          # Only recipient-bearing items: `*anchor` refs and literal age keys.
          # The trailing-colon exclusion keeps key_groups structure keys
          # (`- age:`, `- pgp:`) out of refs — the 2026-09-16 false-positive
          # class where every file was "missing recipient age:".
          ruleRef = l: builtins.match "[[:space:]]*- (\\*?[A-Za-z0-9_-]+|${ageRecipient})" l;

          foldState = builtins.foldl' (
            state: l:
            let
              started = ruleStart l;
            in
            if started != null then
              {
                rules = if state.cur == null then state.rules else state.rules ++ [ state.cur ];
                cur = {
                  regex = builtins.head started;
                  refs = [ ];
                };
              }
            else if state.cur != null && ruleRef l != null then
              state
              // {
                cur = state.cur // {
                  # PARENTHESES ARE LOAD-BEARING: on nix 2.34 an UNparenthesized
                  # application inside a list literal parses as TWO list
                  # elements — the list then contained the primop `head`
                  # ITSELF (plus the match result), and forcing refs died
                  # "cannot coerce the built-in function 'head' to a string",
                  # breaking every `nix flake check`/eval that touched
                  # config.assertions.
                  refs = state.cur.refs ++ [ (builtins.head (ruleRef l)) ];
                };
              }
            else
              state
          ) {
            rules = [ ];
            cur = null;
          } (contentLines cfg.sopsYaml);

          rawRules = foldState.rules ++ (lib.optional (foldState.cur != null) foldState.cur);

          # A ref is a RECIPIENT only when it is an anchor (`*name`) or a
          # literal age key — the `ruleRef` line-matcher also captures the
          # STRUCTURAL items of the nested `key_groups: - age:` shape (e.g.
          # the literal `age:`), which must NOT count as recipients (every
          # real file was flagged "MISSING recipients age:" before this filter).
          isRecipientRef = ref: lib.hasPrefix "*" ref || builtins.match "${ageRecipient}" ref != null;

          # Refs to age recipients; `*anchor` refs resolve via the keys: block.
          resolvedRules = map (rule: {
            inherit (rule) regex;
            recipientRefs = builtins.filter isRecipientRef rule.refs;
            recipients = builtins.filter (r: r != null) (
              map (ref: if lib.hasPrefix "*" ref then anchors.${lib.removePrefix "*" ref} or null else ref) (
                builtins.filter isRecipientRef rule.refs
              )
            );
            unresolved = builtins.filter (
              ref: lib.hasPrefix "*" ref && !(anchors ? ${lib.removePrefix "*" ref})
            ) (builtins.filter isRecipientRef rule.refs);
          }) rawRules;

          regexesParse = builtins.all (
            rule: (builtins.tryEval (builtins.match rule.regex "")).success
          ) resolvedRules;

          secretFiles = builtins.filter (n: builtins.match "[^.].*\\.yaml$" n != null) (
            builtins.attrNames (builtins.readDir cfg.secretsDir)
          );

          relPath = name: "platforms/nixos/secrets/${name}";

          firstMatchingRule =
            path:
            builtins.foldl' (
              acc: rule:
              if acc != null then acc else if builtins.match rule.regex path != null then rule else null
            ) null resolvedRules;

          fileRecipients =
            name:
            # map head unwraps the match result: without it this is a list of
            # LISTS and the sort in checkFile dies on the first
            # multi-recipient file ("cannot compare a list with a list").
            map
              (l: builtins.head (builtins.match "[[:space:]]*-?[[:space:]]*recipient:[[:space:]]*(${ageRecipient})" l))
              (
                builtins.filter
                  (l: builtins.match "[[:space:]]*-?[[:space:]]*recipient:[[:space:]]*${ageRecipient}" l != null)
                  (contentLines (cfg.secretsDir + "/${name}"))
              );

          checkFile =
            name:
            let
              rule = firstMatchingRule (relPath name);
              expected = builtins.sort builtins.lessThan rule.recipients;
              actual = builtins.sort builtins.lessThan (fileRecipients name);
              missing = lib.subtractLists actual expected;
              stale = lib.subtractLists expected actual;
            in
            if rule == null then
              {
                assertion = false;
                message = "sops-recipient-audit: platforms/nixos/secrets/${name} matches no .sops.yaml creation rule. sops refuses to encrypt files without a matching rule; add one or remove the file.";
              }
            else if missing != [ ] then
              {
                assertion = false;
                message = "sops-recipient-audit: platforms/nixos/secrets/${name} is MISSING recipients ${toString missing} mandated by .sops.yaml rule '${rule.regex}'. Hosts behind those keys cannot decrypt: the deploy fails at ACTIVATION on the target host, after a full build. Run: SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops updatekeys ${toString cfg.secretsDir}/${name}";
              }
            else if stale != [ ] then
              {
                assertion = false;
                message = "sops-recipient-audit: platforms/nixos/secrets/${name} carries STALE recipients ${toString stale} not mandated by .sops.yaml rule '${rule.regex}'. A rotated-away or removed key silently keeps decrypt rights. Run: SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops updatekeys ${toString cfg.secretsDir}/${name}";
              }
            else
              null;

          unresolvedAnchorAssertions = map (rule: {
            assertion = false;
            message = "sops-recipient-audit: .sops.yaml rule '${rule.regex}' references ${toString rule.unresolved} but no such &anchor exists in the keys: block. Typo, or the anchor was removed without updating the rule.";
          }) (builtins.filter (rule: rule.unresolved != [ ]) resolvedRules);
        in
        {
          assertions =
            # A regex Nix cannot parse makes "first matching rule"
            # undecidable for every file: go inert rather than guess (see
            # header). Unresolved anchors are flagged regardless: a
            # malformed .sops.yaml is never silently accepted.
            unresolvedAnchorAssertions
            ++ lib.optionals regexesParse (
              builtins.filter (a: a != null) (map checkFile secretFiles)
            );
        };
    };
}
