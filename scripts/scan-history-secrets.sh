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
# Allowlist model (2026-11-03, superb-v3 S-0001):
#   - VALUE digests (sha256 of the full matched value) — never plaintext.
#     Covers canaries (gitleaks-selftest fixtures, leak-canary.tmp.md) and
#     the one REAL key proven auto-revoked by the provider (re_bzp5m…,
#     Resend revoked it 2026-08-18; digest-kept so a DIFFERENT re_ key still
#     fires).
#   - BLOB shas — content-addressed, per-blob. Used where the matched value
#     is generic across secrets (the PEM header inside three historical
#     throwaway-VM nixos.qcow2 disk images: allowlisting the HEADER would mute
#     every PEM in history; the blob sha mutes exactly those three images)
#     and for this repo's own tracked detector fixtures.
#   - The AWS docs example key stays a literal (it IS the published example).
#
# INTENTIONALLY STILL RED (signal, not noise — do NOT "fix" by allowlisting):
#   - AIza… / gsk_… in the iTerm2 blob: the REAL 2026-02-09 leaked keys. The
#     2026-08-18 filter-repo purge was never pushed; rotation is owner-gated
#     (docs/todo/security.md key-rotation row).
#   - ctx7sk-…: real Context7 key documented "still LIVE" in historical
#     AGENTS.md; same owner-rotation row.
#   - syn_cb0b…: real synthetic LLM gateway key, redacted from CURRENT files
#     2026-08-18 but alive in history blobs; same owner-rotation row.
#   These stay red until the keys are rotated + the history purge lands.
#
# 2026-11-03 regex fix: every token prefix is \b-anchored. The OpenAI rule
# used to match INSIDE "task-000001a11c56d902302f02b8200000000.md" filenames
# ("ta|sk-" + 32 hex of a tq task id) — ~140 phantom "variants" across 1,194
# blobs, which is what drowned the CI signal this script's allowlist work
# started with.
#
# NOTE: scans the CURRENT repo state. Until the history purge is pushed and
# all clones re-synced, the real-leak classes above keep this red — by design.
set -euo pipefail

REPO="${1:-.}"
ALLOWLIST='AKIAIOSFODNN7EXAMPLE' # AWS documentation example key (docs/verification)

# sha256(full matched value) — canaries + the provider-revoked Resend key.
VALUE_DIGESTS='
7e642a8da36863b6b262c46b0260f0d21545d4d957f62628cf6ed8a8791fc9f2
9d95aee3a2ca1b79024d3efed25d64fc3bc8e2327b60e5662bb34f64df2678f0
6072345a541900b7747e36ad354c093089265b72d9d53466f86db6d64c14309e
9cef7a7f4706d96c29da9cad1f14c601f3613738ede50d91454854e7b39ac5ac
'
# 7e642a…/9d95ae…: the re_Ab12…/syn_Ab12… gitleaks-coverage fixtures as they
#   appeared in historical flake.nix (2026-09-15 selftest block).
# 607234…: re_abcde… from the tracked leak-canary.tmp.md.
# 9cef7a…: re_bzp5m… — the REAL Pocket-ID SMTP Resend key pasted into the
#   2026-06-11 session-131B report; Resend AUTO-REVOKED it 2026-08-18 (the
#   incident that created this scanner). Kept by digest with provenance.

# Full 40-char blob shas whose findings are skipped (content-addressed).
BLOB_ALLOWLIST='
5870587122f2dead63e9e00e36e286c9e720c2f7
990238a34cc3c145d3e357e9b091f44777f5665d
bf81bf804f07fda0c80274bb43de7c3eb3a0cea5
d08c7678784f54bf86436d72b72aa3409a8b92a8
'
# 3x nixos.qcow2: historical throwaway VM disk images carrying throwaway
#   SSH/host keys (PEM header is generic — only blob-level allowlisting is
#   sound). d08c76…: tests/fixtures/gitleaks/positive-slack.txt, this repo's
#   own detector fixture (xoxb- template).

# Selftest extension points (empty in production): colon-separated extra
# digests / blob shas so checks can exercise the allowlist machinery with
# synthetic values without polluting the static lists.
EXTRA_VALUE_DIGESTS="${SECRET_HISTORY_EXTRA_VALUE_DIGESTS:-}"
EXTRA_BLOBS="${SECRET_HISTORY_EXTRA_BLOBS:-}"

python3 - "$REPO" "$ALLOWLIST" "$VALUE_DIGESTS" "$BLOB_ALLOWLIST" "$EXTRA_VALUE_DIGESTS" "$EXTRA_BLOBS" <<'EOF'
import re, subprocess, sys, gzip, hashlib

repo, allow = sys.argv[1], sys.argv[2]
value_digests = {d for d in sys.argv[3].split() if d}
blob_allow = {d for d in sys.argv[4].split() if d}
value_digests |= {d for d in sys.argv[5].split(":") if d}
blob_allow |= {d for d in sys.argv[6].split(":") if d}

patterns = {
    # All prefixes \b-anchored (2026-11-03): unanchored "sk-" matched inside
    # task-<tq-id> filenames ("ta|sk-000001a1…") — 1,194 phantom blobs.
    "Google API key": rb"\bAIza[A-Za-z0-9_\-]{30,}",
    "Groq API key": rb"\bgsk_[A-Za-z0-9]{30,}",
    "OpenAI API key": rb"\bsk-(?:proj-)?[A-Za-z0-9]{32,}",
    "Anthropic API key": rb"\bsk-ant-[A-Za-z0-9_\-]{20,}",
    "Context7 API key": rb"\bctx7sk[-_][A-Za-z0-9\-]{20,}",
    "Resend API key": rb"\bre_[A-Za-z0-9_]{30,}",
    "Synthetic API key": rb"\bsyn_[A-Za-z0-9]{24,}",
    "GitHub token": rb"\bgh[pousr]_[A-Za-z0-9]{30,}",
    # Fine-grained PATs (github_pat_<22>_<59>) — hermes consumes exactly this
    # class (HERMES_GITHUB_READ_TOKEN), and gitleaks' gh[pousr]_ rule misses it.
    "GitHub fine-grained PAT": rb"\bgithub_pat_[A-Za-z0-9_]{22}_[A-Za-z0-9]{59}",
    "GitLab PAT": rb"\bglpat-[A-Za-z0-9_\-]{20,}",
    "Stripe secret key": rb"\b[sr]k_live_[A-Za-z0-9]{20,}",
    "AWS access key": rb"\bAKIA[0-9A-Z]{16}",
    "Slack token": rb"\bxox[baprs]-[A-Za-z0-9\-]{10,}",
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
skipped_digest = set()
skipped_blob = set()
scanned = 0
oversized = []
for line in cat:
    parts = line.split()
    if len(parts) != 3 or parts[1] != "blob":
        continue
    sha, size = parts[0], int(parts[2])
    if size > 50_000_000:
        # Visible, never silent: a skipped blob is unscanned surface (the
        # gzip'd itermexport class hid keys for 6 months — a skipped zstd/zip
        # blob hides them again).
        oversized.append((sha[:12], size, paths.get(sha, "?")))
        continue
    data = subprocess.run(["git", "-C", repo, "cat-file", "blob", sha],
                          capture_output=True, check=True).stdout
    if data[:2] == b"\x1f\x8b":
        try:
            data = gzip.decompress(data)
        except OSError:
            pass
    scanned += 1
    blob_allowed = sha in blob_allow
    for name, pat in patterns.items():
        for m in re.findall(pat, data):
            value = m.decode("utf-8", "replace")
            if allow and allow in value:
                continue
            if hashlib.sha256(value.encode()).hexdigest() in value_digests:
                skipped_digest.add((name, value[:8]))
                continue
            if blob_allowed:
                skipped_blob.add((name, sha[:12]))
                continue
            findings.append((name, value[:8], len(value), sha[:12], paths.get(sha, "?")))

for name, prefix in sorted(skipped_digest):
    print(f"SKIP  {name}: {prefix}... (value-digest allowlisted)")
for name, sha in sorted(skipped_blob):
    print(f"SKIP  {name} in blob={sha} (blob allowlisted)")
for name, prefix, length, sha, path in sorted(set(findings)):
    print(f"HIT  {name}: {prefix}...MASKED len={length}  blob={sha}  path={path}")
for sha, size, path in sorted(set(oversized)):
    print(f"WARN oversized blob SKIPPED (>50MB, contents unscanned): {sha}  {size} bytes  path={path}")
print(f"scanned {scanned} blobs ({len(skipped_digest)} value-digest + {len(skipped_blob)} blob allowlisted skips)")
if findings:
    print("FAIL: secrets found in git history")
    sys.exit(1)
print("OK: no secrets found in git history")
EOF
