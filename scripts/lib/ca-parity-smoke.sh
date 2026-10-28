#!/usr/bin/env bash
# dnsblockd CA parity smoke — post-deploy §22 (fixture-tested by
# scripts/test-ca-parity-smoke.sh and the dnsblockd-guards-selftest flake
# check).
#
# The same CA exists twice by necessity: a PEM inlined into
# security.pki.certificates (platforms/nixos/system/dns-blocker-config.nix)
# so this host trusts it, and the sops secret the dnsblockd block-page proxy
# terminates TLS with. Parity was verified byte-identical 2026-10-28 and was
# enforced by NOTHING — a CA rotation that touches one side and not the other
# silently breaks browser trust, and with it the ADR-0018 scoped
# filter-proxy, which only works while devices trust that CA.
#
# Verdicts (each a distinct real failure mode):
#   sops CA unreadable            -> SKIP (sops not rendered / not provisioned)
#   trust bundle unreadable       -> SKIP (no system store)
#   sops file is not a PEM cert   -> FAIL (the proxy has no usable serving CA)
#   no dnsblockd-CA in bundle     -> FAIL (clients cannot verify what is served)
#   a DIFFERENT dnsblockd-CA      -> FAIL (a retired key keeps trust, so a
#                                   leaked old key still MITMs)
#   identical + >1 copy           -> WARN (benign for trust, but two writers
#                                   append one PEM — the split-brain signature)
#   identical + <90d to expiry    -> WARN (silent trust cliff)
#   identical, single, healthy    -> PASS
#
# Callers provide the verdict callbacks (single message argument):
#   CA_PASS CA_FAIL CA_WARN CA_SKIP
# and optionally CA_PARITY_BUNDLE / CA_PARITY_SOPS paths, so fixtures can
# drive canned bundles without touching the live trust store.

dnsblockd_ca_parity_smoke() {
  local bundle="${CA_PARITY_BUNDLE:-/etc/ssl/certs/ca-certificates.crt}"
  local sops_ca="${CA_PARITY_SOPS:-/run/secrets/dnsblockd_ca_cert}"
  local sops_fp tmp all dir entries matches foreign meta fp

  if [ ! -r "$sops_ca" ]; then
    "$CA_SKIP" "dnsblockd CA parity - ${sops_ca} not readable (sops not rendered / dnsblockd not provisioned)"
    return 0
  fi
  if [ ! -r "$bundle" ]; then
    "$CA_SKIP" "dnsblockd CA parity - ${bundle} not readable (no system trust bundle)"
    return 0
  fi
  if ! sops_fp="$(openssl x509 -in "$sops_ca" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)" || [ -z "$sops_fp" ]; then
    "$CA_FAIL" "dnsblockd CA parity - ${sops_ca} is not a parseable PEM certificate (the proxy has no usable serving CA)"
    return 0
  fi

  # crl2pkcs7|pkcs7 is the only portable way to enumerate every certificate in
  # a bundle (openssl has no split command); the awk then writes one PEM per
  # file. ~296 certs cost roughly 5s of openssl calls — acceptable for a
  # post-deploy smoke, and fixtures stay in the millisecond range.
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/certs"
  dir="$tmp/certs"
  all="$tmp/all.pem"
  openssl crl2pkcs7 -nocrl -certfile "$bundle" 2>/dev/null |
    openssl pkcs7 -print_certs 2>/dev/null >"$all" || true
  awk -v dir="$dir" 'BEGIN{n=0} /-----BEGIN CERTIFICATE-----/{n++} {print > sprintf("%s/c%04d.pem", dir, n)}' "$all"

  matches=0
  foreign=""
  for entries in "$dir"/c*.pem; do
    [ -e "$entries" ] || continue
    meta="$(openssl x509 -in "$entries" -noout -subject -fingerprint -sha256 2>/dev/null || true)"
    case "$meta" in
    *dnsblockd-CA*) ;;
    *) continue ;;
    esac
    matches=$((matches + 1))
    fp="$(printf '%s\n' "$meta" | sed -n 's/^sha256 Fingerprint=//p')"
    if [ "$fp" != "$sops_fp" ]; then
      foreign="${foreign}${fp:-unparsed} "
    fi
  done
  rm -rf "$tmp"

  if [ "$matches" -eq 0 ]; then
    "$CA_FAIL" "dnsblockd CA parity - no dnsblockd-CA in ${bundle}: the proxy serves a CA this host does not trust (a rotation touched one side only — sops vs security.pki.certificates)"
  elif [ -n "$foreign" ]; then
    "$CA_FAIL" "dnsblockd CA parity - a DIFFERENT dnsblockd-CA is trusted (${foreign% }) while the proxy serves ${sops_fp}: a retired key keeps trust, so a leaked old key still MITMs"
  elif ! openssl x509 -in "$sops_ca" -noout -checkend $((90 * 86400)) >/dev/null 2>&1; then
    "$CA_WARN" "dnsblockd CA parity - trust anchor == serving CA, but it expires within 90 days: rotate sops + security.pki.certificates TOGETHER (docs/services/dnsblockd.md 'CA rotation')"
  elif [ "$matches" -gt 1 ]; then
    "$CA_WARN" "dnsblockd CA parity - trusted and identical, but the bundle appends the same CA ${matches}x (benign for trust; two mechanisms write one PEM — find the second writer)"
  else
    "$CA_PASS" "dnsblockd CA parity - trust anchor == serving CA (${sops_fp:0:17}…, valid >90d, single entry)"
  fi
}
