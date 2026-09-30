#!/usr/bin/env bash
# Standing fixture test for .githooks/commit-msg (the 72-char subject limit).
#
# Why: the hook shipped 2026-09-28 with all verification fixtures dying with
# the authoring session — zero standing regression protection. This is the
# persisted harness (the flake check `commit-msg-hook-selftest` runs it with a
# mutation negative).
#
# Static asserts pin the REAL hook's load-bearing properties:
#   C1 length is measured via bash ${#first_line} (the hook's locale
#      semantics ride on this — see M6)
#   C2 the limit is enforced at -gt 72
#   C3 the subject is the first NON-# line (comment scaffold excluded)
#   C4 merge subjects are exempt (MERGE_HEAD present, or "Merge " prefix)
#
# Dynamic proof runs the REAL hook against a scratch git repo:
#   M1 72-char ASCII subject accepted (boundary, inclusive)
#   M2 73-char ASCII subject rejected, error names the length
#   M3 comment scaffold skipped — "# Title" then a long-but-ok subject
#   M4 MERGE_HEAD stub exempts an 80-char subject
#   M5 "Merge ..." subject exempts without MERGE_HEAD
#   M6 multibyte under LC_ALL=C: ${#} counts BYTES — a 71-char subject with
#      one em-dash (73 bytes) is rejected, 70 chars (72 bytes) accepted.
#      Pinned under LC_ALL=C for determinism; under a UTF-8 locale the same
#      hook counts characters (both boundaries move by the byte overhead).
#   M7 an all-comment message passes the hook (git aborts empty messages
#      itself, after commit-msg)
#
# Negative (flake check): mutating the 72 constant must FAIL this fixture.
#
# Boundary strings are generated with head -c (byte-exact) — never
# printf %.0s $(seq N), which silently degrades under mvdan/sh.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="${COMMIT_MSG_HOOK:-$REPO_ROOT/.githooks/commit-msg}"

FAILURES=0
die() {
  echo "  FAIL $1"
  FAILURES=$((FAILURES + 1))
}
ok() {
  echo "  ok   $1"
}

echo "=== Static asserts on $HOOK ==="
grep -qF 'length=${#first_line}' "$HOOK" &&
  ok "C1 length via \${#first_line} (locale-dependent counting, pinned by M6)" ||
  die "C1 length measurement drifted"
grep -qF -- "-gt 72" "$HOOK" &&
  ok "C2 limit enforced at -gt 72" ||
  die "C2 limit constant drifted"
grep -qF -- "grep -m1 -v '^#'" "$HOOK" &&
  ok "C3 subject = first non-comment line" ||
  die "C3 scaffold handling drifted"
grep -qF -- "MERGE_HEAD" "$HOOK" && grep -qF -- '"Merge "*' "$HOOK" &&
  ok "C4 merge exemptions present (MERGE_HEAD + Merge prefix)" ||
  die "C4 merge exemption drifted"

echo "=== Dynamic proof (scratch repo, real hook) ==="
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
git -C "$SCRATCH" init -q
git -C "$SCRATCH" config user.name fixture
git -C "$SCRATCH" config user.email fixture@example.com

run_hook() { # <msgfile> [extra env via env]
  (cd "$SCRATCH" && bash "$HOOK" "$1") >/dev/null 2>&1
}

boundary() { # <n> -> N ASCII chars on stdout
  head -c "$1" /dev/zero | tr '\0' 'a'
}

msg72="$(boundary 72)"
msg73="$(boundary 73)"
[ "${#msg72}" = 72 ] && [ "${#msg73}" = 73 ] ||
  die "SETUP boundary generator produced wrong lengths (${#msg72}/${#msg73})"

printf '%s\n' "$msg72" >"$SCRATCH/m72"
if run_hook "$SCRATCH/m72"; then
  ok "M1 72-char subject accepted (inclusive boundary)"
else
  die "M1 72-char subject rejected — limit moved"
fi

printf '%s\n' "$msg73" >"$SCRATCH/m73"
if run_hook "$SCRATCH/m73"; then
  die "M2 73-char subject accepted — limit broken"
else
  ok "M2 73-char subject rejected"
fi

printf '# Subject scaffold\n\n%s\n' "$(boundary 40)" >"$SCRATCH/m-scaffold"
if run_hook "$SCRATCH/m-scaffold"; then
  ok "M3 comment scaffold skipped (40-char real subject measured)"
else
  die "M3 scaffold comment wrongly measured/rejected"
fi

printf 'merge-exempt %s\n' "$(boundary 66)" >"$SCRATCH/m-mergehead" # 80 chars
printf '0123456789abcdef\n' >"$SCRATCH/.git/MERGE_HEAD"
if run_hook "$SCRATCH/m-mergehead"; then
  ok "M4 MERGE_HEAD stub exempts an 80-char subject"
else
  die "M4 MERGE_HEAD exemption missing"
fi
rm -f "$SCRATCH/.git/MERGE_HEAD"

printf 'Merge master into feature-%s\n' "$(boundary 50)" >"$SCRATCH/m-mergeprefix"
if run_hook "$SCRATCH/m-mergeprefix"; then
  ok "M5 'Merge ...' subject exempt without MERGE_HEAD"
else
  die "M5 Merge-prefix exemption missing"
fi

dash="$(printf '\xe2\x80\x94')" # em-dash, 3 UTF-8 bytes, locale-independent
s70="${dash}$(boundary 69)"     # 70 chars, 72 bytes
s71="${dash}$(boundary 70)"     # 71 chars, 73 bytes
printf '%s\n' "$s71" >"$SCRATCH/m-mb71"
if (cd "$SCRATCH" && LC_ALL=C bash "$HOOK" "$SCRATCH/m-mb71") >/dev/null 2>&1; then
  die "M6 71-char + em-dash (73 bytes) accepted under LC_ALL=C — byte-counting changed"
else
  ok "M6 multibyte boundary pinned: 73 bytes rejected under LC_ALL=C"
fi
printf '%s\n' "$s70" >"$SCRATCH/m-mb70"
if (cd "$SCRATCH" && LC_ALL=C bash "$HOOK" "$SCRATCH/m-mb70") >/dev/null 2>&1; then
  ok "M6 70-char + em-dash (72 bytes) accepted under LC_ALL=C"
else
  die "M6 72-byte multibyte subject rejected — boundary moved"
fi

printf '# only comments\n# nothing else\n' >"$SCRATCH/m-comments"
if run_hook "$SCRATCH/m-comments"; then
  ok "M7 all-comment message passes the hook (git aborts empties itself)"
else
  die "M7 all-comment message blocked by the hook"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo ""
  echo "SELFTEST FAILED: $FAILURES assertion(s) broken"
  exit 1
fi
echo ""
echo "SELFTEST OK: commit-msg hook enforces the 72-char subject contract (boundary, scaffold, merge exemptions, multibyte)"
