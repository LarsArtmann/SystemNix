#!/usr/bin/env bash
# Sops pre-deploy gate (pre-deploy §19; pipeline.md row
# "sops manifest check-mode in pre-deploy-check" — superb-v3 S-0002).
#
# Incident class this closes (docs/status/archived/2026-08-18_20-38_issue-138-twenty-v2.32-upgrade-self-review.md §e.1):
# a secret key declared in modules/nixos/services/sops.nix but absent from
# its encrypted yaml killed a deploy at BUILD time (20:03, 2026-08-18) with
# pre-deploy-check 67-PASS-green. The eval-time sops-key-audit
# (missing key names) and sops-recipient-audit (file-vs-.sops.yaml recipient
# parity) catch the static shape earlier now, but three properties are still
# only checked at ACTIVATION — after a full build, the worst moment:
#   (1) the manifest's own sopsfile validation (formats, key presence in
#       the exact per-secret sopsFile the GENERATION will consume),
#   (2) the LIVE host SSH key still maps to a .sops.yaml recipient
#       (host-key rotation drift: "no identity matched any of the
#       recipients" at activation),
#   (3) every repo sops file actually DECRYPTS with the live host key
#       (age-layer + data-key stanzas intact).
# This gate runs (1) pre-BUILD via the manifest attr's checkPhase — the
# exact `sops-install-secrets -check-mode=sopsfile` sops-nix ships — and
# (2)+(3) against the live host key.
#
# Verdict stream: PASS:/WARN:/FAIL: lines. Exit 0 = green or warn-only,
# 1 = FAIL (deploy blocked). A leg that CANNOT run fails loud or warns
# visibly — never silently green (anti-phantom doctrine).
#
# Test knobs (scripts/test-predeploy-sops.sh fixtures):
#   SOPS_GATE_NIX          nix binary            (default: nix)
#   SOPS_GATE_BIN_DIR      PATH prepend for stub ssh-to-age/sops/sudo
#   SOPS_GATE_SOPS_YAML    .sops.yaml path       (default: .sops.yaml)
#   SOPS_GATE_SECRETS_DIR  encrypted files dir   (default: platforms/nixos/secrets)
#   SOPS_GATE_HOST_KEY_PUB host public SSH key   (default: /etc/ssh/ssh_host_ed25519_key.pub)
#   SOPS_GATE_HOST_KEY     host private SSH key  (default: /etc/ssh/ssh_host_ed25519_key)
set -uo pipefail

SOPS_GATE_NIX="${SOPS_GATE_NIX:-nix}"
SOPS_GATE_SOPS_YAML="${SOPS_GATE_SOPS_YAML:-.sops.yaml}"
SOPS_GATE_SECRETS_DIR="${SOPS_GATE_SECRETS_DIR:-platforms/nixos/secrets}"
SOPS_GATE_HOST_KEY_PUB="${SOPS_GATE_HOST_KEY_PUB:-/etc/ssh/ssh_host_ed25519_key.pub}"
SOPS_GATE_HOST_KEY="${SOPS_GATE_HOST_KEY:-/etc/ssh/ssh_host_ed25519_key}"
if [ -n "${SOPS_GATE_BIN_DIR:-}" ]; then
  PATH="$SOPS_GATE_BIN_DIR:$PATH"
fi

GATE_FAILED=0

# Leg 1: build the sops-nix manifest — its checkPhase runs
# `sops-install-secrets -check-mode=sopsfile` (sops-nix modules/sops/
# manifest-for.nix): parse + per-secret key-presence on the exact files the
# generation will consume, pre-build. An eval-level failure (e.g. the
# lock-float audit) also lands here and blocks identically to §1/§2 —
# correct: the sops state cannot be validated on a non-evaluating tree.
MANIFEST_ATTR=".#nixosConfigurations.evo-x2.config.system.build.sops-nix-manifest"
manifest_out=""
if manifest_out=$("$SOPS_GATE_NIX" build --no-link --print-out-paths "$MANIFEST_ATTR" 2>&1); then
  echo "PASS: sops manifest built clean — sops-install-secrets -check-mode=sopsfile green (every declared secret key present in its encrypted file, formats valid): $(printf '%s\n' "$manifest_out" | tail -1)"
else
  echo "FAIL: sops manifest build failed — the sopsfile check (or the eval feeding it) is RED; a deploy would die at build/activation on the same error:"
  printf '%s\n' "$manifest_out" | tail -15 | sed 's/^/    /'
  GATE_FAILED=1
fi

# Leg 2: the LIVE host key must still map to a .sops.yaml recipient.
# Recipient lines are plaintext metadata, and file-vs-.sops.yaml parity is
# already eval-audited (sops-recipient-audit) — so live-key-in-.sops.yaml
# composes to "the live host key can decrypt every file". Host-key rotation
# without updatekeys is otherwise activation-only.
live_recipient=""
live_recipient=$(ssh-to-age <"$SOPS_GATE_HOST_KEY_PUB" 2>/dev/null || true)
if [ -z "$live_recipient" ]; then
  echo "FAIL: cannot derive the live age recipient from $SOPS_GATE_HOST_KEY_PUB (ssh-to-age failed or missing) — decryptability cannot be verified; refusing"
  GATE_FAILED=1
elif grep -q "$live_recipient" "$SOPS_GATE_SOPS_YAML" 2>/dev/null; then
  echo "PASS: live host key maps to a .sops.yaml recipient (${live_recipient:0:12}…) — no host-key rotation drift"
else
  echo "FAIL: the live host key's age recipient ($live_recipient) is NOT in $SOPS_GATE_SOPS_YAML — the host cannot decrypt its secrets and the deploy dies at ACTIVATION, after a full build (host-key rotation drift). Remedy: add the recipient as a key anchor + creation_rules entry, then SOPS_AGE_KEY=\$(sudo cat $SOPS_GATE_HOST_KEY | ssh-to-age -private-key) sops updatekeys <file> for every file under $SOPS_GATE_SECRETS_DIR/"
  GATE_FAILED=1
fi

# Leg 3: decrypt smoke of every repo sops file with the live host key.
# Needs root to read the private host key — degrade to a VISIBLE WARN when
# sudo is not cached (deploy.sh primes sudo before pre-deploy-check runs,
# so the deploy path gets full coverage; standalone runs see the remedy).
if sudo -n true 2>/dev/null; then
  age_key=""
  age_key=$(sudo -n cat "$SOPS_GATE_HOST_KEY" 2>/dev/null | ssh-to-age -private-key 2>/dev/null || true)
  if [ -z "$age_key" ]; then
    echo "FAIL: cannot convert $SOPS_GATE_HOST_KEY to an age identity (sudo ok, ssh-to-age -private-key failed) — decrypt smoke refused"
    GATE_FAILED=1
  else
    decrypt_failed=0
    file_count=0
    for f in "$SOPS_GATE_SECRETS_DIR"/*.yaml; do
      [ -f "$f" ] || continue
      file_count=$((file_count + 1))
      if ! SOPS_AGE_KEY="$age_key" sops -d "$f" >/dev/null 2>&1; then
        echo "FAIL: $f does not decrypt with the live host key — the switch would fail at activation on this file"
        decrypt_failed=1
        GATE_FAILED=1
      fi
    done
    if [ "$decrypt_failed" -eq 0 ]; then
      echo "PASS: all $file_count repo sops files decrypt with the live host key (full decrypt smoke)"
    fi
  fi
else
  echo "WARN: sudo not cached — decrypt smoke skipped (run 'sudo -n true' once, or rely on the deploy path which primes sudo before this gate)"
fi

exit "$GATE_FAILED"
