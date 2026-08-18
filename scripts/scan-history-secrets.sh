#!/usr/bin/env bash
# Full-git-history secret scanner that CATCHES WHAT GITLEAKS MISSES.
#
# gitleaks (pre-commit + CI) scans blob bytes literally: a gzip-compressed
# blob hides every secret from it. The 2026-02-09 "iTerm2 State.itermexport"
# leak (1x Google Gemini AIza..., 3x Groq gsk_..., gzip'd binary plist) sat
# in PUBLIC history for 6+ months while gitleaks reported "no leaks found"
# over all 4112 commits. gitleaks also has no Context7 (ctx7sk-) rule.
#
# This script scans EVERY blob reachable from refs, decompresses gzip blobs
# first, and matches a pattern set covering everything found in the 2026-08-18
# incident audit. Exit 1 on any non-allowlisted hit; output is masked.
#
# NOTE: scans the CURRENT repo state. Until the 2026-08-18 filter-repo is
# pushed and all clones re-synced, this will (correctly) flag the old history.
set -euo pipefail

REPO="${1:-.}"
ALLOWLIST='AKIAIOSFODNN7EXAMPLE' # AWS documentation example key (docs/verification)

python3 - "$REPO" "$ALLOWLIST" <<'EOF'
import re, subprocess, sys, gzip

repo, allow = sys.argv[1], sys.argv[2]
patterns = {
    "Google API key": rb"AIza[A-Za-z0-9_\-]{30,}",
    "Groq API key": rb"gsk_[A-Za-z0-9]{30,}",
    "OpenAI API key": rb"sk-(?:proj-)?[A-Za-z0-9]{32,}",
    "Anthropic API key": rb"sk-ant-[A-Za-z0-9_\-]{20,}",
    "Context7 API key": rb"ctx7sk[-_][A-Za-z0-9\-]{20,}",
    "GitHub token": rb"gh[pousr]_[A-Za-z0-9]{30,}",
    "AWS access key": rb"AKIA[0-9A-Z]{16}",
    "Slack token": rb"xox[baprs]-[A-Za-z0-9\-]{10,}",
    "Private key PEM": rb"-----BEGIN [A-Z ]*PRIVATE KEY-----",
}

objects = subprocess.run(
    ["git", "-C", repo, "rev-list", "--objects", "--all"],
    capture_output=True, text=True, check=True,
).stdout.splitlines()
paths = {}
for line in objects:
    parts = line.split(None, 1)
    if parts:
        paths[parts[0]] = parts[1] if len(parts) > 1 else "(no path)"

cat = subprocess.run(
    ["git", "-C", repo, "cat-file", "--batch-check=%(objectname) %(objecttype) %(objectsize)"],
    input="\n".join(paths), capture_output=True, text=True, check=True,
).stdout.splitlines()

findings = []
scanned = 0
for line in cat:
    parts = line.split()
    if len(parts) != 3 or parts[1] != "blob":
        continue
    sha, size = parts[0], int(parts[2])
    if size > 50_000_000:
        continue
    data = subprocess.run(["git", "-C", repo, "cat-file", "blob", sha],
                          capture_output=True, check=True).stdout
    if data[:2] == b"\x1f\x8b":
        try:
            data = gzip.decompress(data)
        except OSError:
            pass
    scanned += 1
    for name, pat in patterns.items():
        for m in re.findall(pat, data):
            value = m.decode("utf-8", "replace")
            if allow and allow in value:
                continue
            findings.append((name, value[:8], len(value), sha[:12], paths.get(sha, "?")))

for name, prefix, length, sha, path in sorted(set(findings)):
    print(f"HIT  {name}: {prefix}...MASKED len={length}  blob={sha}  path={path}")
print(f"scanned {scanned} blobs")
if findings:
    print("FAIL: secrets found in git history")
    sys.exit(1)
print("OK: no secrets found in git history")
EOF
