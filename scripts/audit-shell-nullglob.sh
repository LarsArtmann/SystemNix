#!/usr/bin/env bash
# audit-shell-nullglob.sh — sweep BUILD-TIME shell (runCommand bodies) for the
# nullglob phantom-green class.
#
# stdenv's setup.sh runs every derivation builder with `shopt -s nullglob`:
# any UNQUOTED expansion whose words contain glob chars (* ? [) that match no
# file is silently DELETED from the command. The incident shape
# (signoz-query-lint v1, 2026-08-27): a command stored in a variable
# (`strip="grep -v '...'"`) and expanded unquoted (`$strip "$file"`) lost its
# quoted pattern word — every trap read EMPTY input and the check passed
# guarding nothing. `nix build` exit 0 proved nothing (verified live).
#
# Scope: .nix files containing `runCommand` — their ''-string bodies execute
# under stdenv setup.sh. Runtime scripts (writeShellApplication /
# writeShellScript bodies run via their own #!/bin/sh) do NOT get nullglob
# and are out of scope.
#
# Verdict tiers:
#   FAIL (exit 1) — crisp, zero-false-positive classes:
#     A  unquoted shell var in COMMAND position (^ | ; | { | ! | if | then |
#        else | elif | do | eval — any keyword that precedes a command),
#        incl. the nix-escaped ''${var} form. Quotes inside a variable's
#        VALUE are data, not syntax — expand a command through a FUNCTION
#        definition instead (quotes parse at definition time).
#     B  `$( $var ... )` command indirection (same class, subshell flavor).
#   WARN (exit 0) — judgment classes, review the output:
#     C  `for x in $var` unquoted list — empty var = zero iterations = check
#        silently disabled (the empty-var silent-skip sibling of nullglob;
#        harden with an explicit empty-guard, see signoz-query-lint).
#     D  `for x in <glob>` without a same-line existence guard
#        (`[ -e ... ]`/`|| continue`) — under nullglob a non-matching glob
#        expands to NOTHING and the loop body silently never runs. Exempt:
#        `bash -c '...'` fixture strings (quoted data, not build shells) and
#        `$(find ...)` command substitution (no shell glob involved).
#
# Usage: bash scripts/audit-shell-nullglob.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Lines exempt from class D (quoted fixture DATA inside tests, never executed
# as build shells — they are the corpus that proves the tmp-cleaner audit
# catches the banned pattern).
readonly D_EXEMPT='bash -c'

fail=0
warns=0
scanned=0

mapfile -t files < <(grep -rl 'runCommand' --include='*.nix' "$REPO_ROOT" 2>/dev/null | sort)

if [ "${#files[@]}" -eq 0 ]; then
  echo "FATAL: no runCommand-bearing .nix files found under $REPO_ROOT"
  exit 2
fi

for f in "${files[@]}"; do
  scanned=$((scanned + 1))
  rel="${f#"$REPO_ROOT"/}"
  # Comment lines are not executable — strip them before every class matcher
  # (same convention as the in-tree lints: grep -v '^[[:space:]]*#').
  code() { grep -vE '^[[:space:]]*#' "$f" || true; }

  # A. unquoted shell var in command position (plain $var or ''${var} form)
  while IFS= read -r line; do
    echo "FAIL [$rel] A: unquoted command-position shell var:"
    echo "  $line"
    echo "  Quotes inside a variable VALUE are data. Use a function definition"
    echo "  for command indirection (incident: signoz-query-lint v1 nullglob phantom-green)."
    fail=1
  done < <(code | grep -nE '(^|[;{}!]|&&|\|\||\||if |then |else |elif |do |eval )[[:space:]]*(\$[a-zA-Z_][a-zA-Z_0-9]*|'"''"'?\$\{[a-zA-Z_][a-zA-Z_0-9]*\})[[:space:]]' || true)

  # B. $( $var ... ) command indirection
  while IFS= read -r line; do
    echo "FAIL [$rel] B: \$( \$var ) command indirection:"
    echo "  $line"
    echo "  Same nullglob class as A in subshell flavor — use a function."
    fail=1
  done < <(code | grep -nE '\$\([[:space:]]*\$[a-zA-Z_][a-zA-Z_0-9]*' || true)

  # C. unquoted for-in list var (empty-var silent-skip — advisory)
  while IFS= read -r line; do
    echo "WARN [$rel] C: unquoted for-in list var (empty var silently skips the loop):"
    echo "  $line"
    warns=$((warns + 1))
  done < <(code | grep -nE 'for[[:space:]]+[a-zA-Z_0-9]+[[:space:]]+in[[:space:]]+[^")]*\$[a-zA-Z_]' || true)

  # The guard (`[ -e ... ] || continue`) may sit on the for-line or the 1-2
  # lines after it — check a 3-line window against the STRIPPED stream.
  while IFS= read -r line; do
    lineno="${line%%:*}"
    case "$line" in
    *"$D_EXEMPT"*) continue ;;
    *'$(find '*) continue ;;
    esac
    window=$(code | sed -n "${lineno},$((lineno + 2))p")
    case "$window" in
    *'[ -e '* | *'|| continue'*) continue ;;
    esac
    echo "WARN [$rel] D: for-in glob without existence guard in the next 2 lines (nullglob skips silently):"
    echo "  $line"
    warns=$((warns + 1))
  done < <(code | grep -nE 'for[[:space:]]+[a-zA-Z_0-9]+[[:space:]]+in[[:space:]]+.*\*' || true)
done

echo ""
echo "=== nullglob audit: $scanned files scanned, $warns warnings, fail=$fail ==="
exit "$fail"
