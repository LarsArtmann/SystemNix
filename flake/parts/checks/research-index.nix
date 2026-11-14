# Standing research-index eval gate (2026-11-14, the 2026-11-05 misfiling class).
#
# docs/research/README.md is a hand-maintained index that a report can land
# without appearing in — the README itself admitted "checks.doc-counts does
# NOT police this file yet", and the 2026-11-05 ai-deployment-research
# misfiling episode proved the class live. This gate enforces the index at
# eval time, BOTH directions:
#   forward: every file in docs/research/ (README.md excepted) must be
#            named in the README — a report without a row is invisible to
#            the index and fails loudly here;
#   reverse: every row's relative .md/.html link must resolve — a renamed
#            or deleted report must not leave a stale row behind.
# Name-coverage, deliberately NOT a count leg (row count == file count can
# pass while one file is swapped for another); §f.36 offered the count form
# and per-file coverage subsumes it.
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    lib.mkIf (system == "x86_64-linux") {
      checks =
        let
          # path + string keeps this a PATH (no string-context store-path
          # coercion — same pattern as doc-counts.nix).
          dir = root + "/docs/research";
          entries = builtins.attrNames (builtins.readDir dir);
          indexedText = builtins.readFile (dir + "/README.md");

          # forward: filename present anywhere in the index text (the row's
          # markdown link contains it verbatim; prose mentions also satisfy).
          unindexed = builtins.filter (
            name: name != "README.md" && !lib.strings.hasInfix name indexedText
          ) entries;

          # reverse: every relative link target must exist in the directory.
          # builtins.split yields matched parts as lists carrying the capture
          # groups ONLY (nix 2.34 live semantics: element 0 IS the first
          # capture — no whole-match element); plain strings are the
          # unmatched interstitials. Literal ] is spelled as the bracket
          # class []] — a bare \] is an invalid ERE here (invalid regular
          # expression, live-tested 2026-11-14).
          linkTargets = builtins.concatMap (
            part:
            let
              target = builtins.elemAt part 0;
            in
            if target != null && target != "" then [ target ] else [ ]
          ) (builtins.filter builtins.isList (builtins.split "[]]\\(([^) ]+)\\)" indexedText));
          dangling = builtins.filter (
            target: lib.strings.hasSuffix ".md" target || lib.strings.hasSuffix ".html" target
          ) (builtins.filter (target: !(lib.strings.hasPrefix "http" target)) linkTargets);
          missingTargets = builtins.filter (
            target: !(builtins.pathExists (dir + ("/" + target)))
          ) dangling;

          guards =
            if unindexed != [ ] then
              throw
                "research-index: docs/research/${builtins.head unindexed} has no README index row (${toString (builtins.length unindexed)} unindexed) — add a row to docs/research/README.md (the 2026-11-05 misfiling class)"
            else if missingTargets != [ ] then
              throw
                "research-index: docs/research/README.md links to ${builtins.head missingTargets} which does not exist (${toString (builtins.length missingTargets)} dangling) — fix or remove the stale row"
            else
              "research-index ok: ${toString (builtins.length entries)} files indexed";
        in
        {
          research-index = pkgs.runCommand "research-index" { inherit guards; } ''
            echo "$guards" >/dev/null
            touch $out
          '';
        };
    };
}
