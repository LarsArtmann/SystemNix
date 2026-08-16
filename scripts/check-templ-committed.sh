#!/usr/bin/env bash
# Fail if any git-TRACKED *.templ file lacks a tracked *_templ.go sibling.
#
# Nix builds vendor Go source without running `templ generate`. An untracked
# generated file breaks the build with `undefined: someFragment` (AGENTS.md
# gotcha). Vendored deps under gitignored dirs (e.g. vendor/) are invisible
# to `git ls-files` and therefore exempt — only TRACKED .templ files count.
#
# `git ls-files` reflects the INDEX, so a pre-commit invocation catches a
# staged .templ file whose generated counterpart was not staged.
#
# Usage: scripts/check-templ-committed.sh   (from any dir inside a git repo)
# Exit 0 = all generated files committed; Exit 1 = violations listed.

set -euo pipefail

root=$(git rev-parse --show-toplevel)

mapfile -t templ_files < <(git -C "$root" ls-files -- '*.templ')

violations=()
for templ in "${templ_files[@]-}"; do
  [ -n "$templ" ] || continue
  generated="${templ%.templ}_templ.go"
  if ! git -C "$root" ls-files --error-unmatch "$generated" >/dev/null 2>&1; then
    violations+=("$templ -> $generated")
  fi
done

if [ "${#violations[@]}" -gt 0 ]; then
  echo "ERROR: ${#violations[@]} tracked *.templ file(s) without a tracked *_templ.go:" >&2
  printf '  %s\n' "${violations[@]}" >&2
  echo >&2
  echo "Nix builds vendor source without running 'templ generate' — the build" >&2
  echo "fails with 'undefined: someFragment'. Commit the generated files:" >&2
  echo "  git add -- '*_templ.go'" >&2
  exit 1
fi

echo "templ check: ${#templ_files[@]} tracked .templ file(s), all *_templ.go committed"
