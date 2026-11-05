#!/usr/bin/env bash
# Fixture tests for the 2026-10-17 deploy-pipeline optimizations
# (scripts/deploy.sh + scripts/pre-deploy-check.sh). Those shipped with
# ZERO persisted tests — one silent regression reintroduces the exact
# classes they fixed: the 27-min provisioner hang (deploy_restart), the
# double-payed flake eval on failed-deploy re-runs (content-addressed
# stamp), the second deep eval for the race detector (manifest fold),
# and the use-before-set probe-batch bug nearly shipped live
# (GATUS_SERVICE_METRIC_PORTS must be computed BEFORE the batch).
#
# Four groups:
#   A  manifest sed parse — normal / empty / single-unit JSON shapes
#   B  stamp key semantics — stable per tracked tree, mutation-sensitive,
#      untracked-blind; 12h expiry window honored by the find expression
#   C  deploy_restart rc-124 — timeout warns (journal pointer), never
#      fails the deploy; the success path stays silent (extracted from
#      deploy.sh, so the REAL function text is what runs)
#   D  probe_endpoint fixture — body + ok-marker per probe id, and the
#      compute-before-launch ordering pinned as a source tripwire
#   E  force-override ladder (freeze #49) — force_level() 0/1/2/garbage
#      mapping on the REAL function text; the tier-2 extreme-band awk
#      condition accepts/rejects the right (psi,disk) corners; no legacy
#      literal "!= 1" override site may remain (=2 must clear gate 1)
# Run: bash scripts/test-deploy-pipeline.sh  (also a flake check)
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEPLOY_SH="$REPO_ROOT/scripts/deploy.sh"
PDC_SH="$REPO_ROOT/scripts/pre-deploy-check.sh"

TESTS=0
FAILED=0
ok() {
  TESTS=$((TESTS + 1))
  echo "  ok: $1"
}
bad() {
  TESTS=$((TESTS + 1))
  FAILED=$((FAILED + 1))
  echo "  FAIL: $1"
}
assert_eq() { # desc got want
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got [$2], want [$3])"; fi
}
assert_contains() { # desc haystack needle
  case "$2" in
  *"$3"*) ok "$1" ;;
  *) bad "$1 (missing [$3])" ;;
  esac
}

# ---------------------------------------------------------------------------
echo "A. race-detector manifest sed parse (deploy.sh unit-list extraction)"

# The separator split is the load-bearing piece; tripwire so a rewrite of
# the parse in deploy.sh fails here loudly instead of drifting silently.
manifest_tripwire=$(grep -c -- "-e 's/\",\"/\\\\n/g'" "$DEPLOY_SH" || true)
assert_eq "deploy.sh still carries the unit-list separator split" "$manifest_tripwire" "1"

manifest_sed() {
  sed -e 's/^.*"units":\[//' -e 's/\]}\?$//' -e 's/","/\n/g' -e 's/"//g' -e '/^$/d'
}

normal_out=$(printf '%s' '{"drv":"/nix/store/abc-nixos-system","units":["a.service","b.service","c.service"]}' | manifest_sed | sort -u)
assert_eq "normal: three units, no JSON residue" "$normal_out" "$(printf 'a.service\nb.service\nc.service')"

empty_out=$(printf '%s' '{"drv":"/nix/store/abc","units":[]}' | manifest_sed | sort -u)
assert_eq "empty: zero units" "$empty_out" ""

single_out=$(printf '%s' '{"drv":"/nix/store/abc","units":["only.service"]}' | manifest_sed | sort -u)
assert_eq "single: one unit, separator-safe" "$single_out" "only.service"

# ---------------------------------------------------------------------------
echo "B. content-addressed flake-check stamp (check #1)"

# Tripwire: the key pipeline + 12h window must stay in pre-deploy-check.sh.
# The window count is TWO since 2026-10-17 evening (M13): check #1 (flake
# check) and check #2 (toplevel eval + manifest cache) each pin their own
# stamp with the same 12h expiry.
assert_contains "pre-deploy-check.sh pins the stamp key pipeline" "$(grep -c 'flakecheck_key=$(' "$PDC_SH")" "1"
assert_contains "pre-deploy-check.sh keeps the 12h expiry window (check #1 + check #2)" "$(grep -c -- '-mmin +720' "$PDC_SH")" "2"
assert_contains "check #2 toplevel-eval stamp + manifest sidecar pinned" "$(grep -c 'evalcheck_stamp="/tmp/systemnix-predeploy-evalcheck' "$PDC_SH")" "1"

fixture_repo=$(mktemp -d)
trap 'rm -rf "$fixture_repo" "$shim_dir"' EXIT
(
  cd "$fixture_repo" && git init -q && git config user.email t@t && git config user.name t
  echo one >file && git add file && git commit -qm one
) >/dev/null 2>&1

stamp_key() { # computed exactly as pre-deploy-check.sh does, in $1 cwd
  (
    cd "$1" || exit 1
    {
      git rev-parse HEAD 2>/dev/null
      git diff HEAD 2>/dev/null | sha256sum
    } | sha256sum | cut -c1-16
  )
}

key1=$(stamp_key "$fixture_repo")
key2=$(stamp_key "$fixture_repo")
assert_eq "same tracked tree -> same key" "$key1" "$key2"

echo tracked-change >>"$fixture_repo/file"
key3=$(stamp_key "$fixture_repo")
if [ "$key1" != "$key3" ]; then ok "tracked mutation -> new key"; else bad "tracked mutation must change the key"; fi

echo untracked >"$fixture_repo/untracked-file"
key4=$(stamp_key "$fixture_repo")
assert_eq "untracked file -> same key (flake evals are untracked-blind)" "$key3" "$key4"

# Expiry semantics of the deployed expression: fresh stamps pass, stamps
# older than 720 minutes are treated as absent.
stamp_fixture=$(mktemp)
touch -d '2 hours ago' "$stamp_fixture"
fresh_scan=$(find "$stamp_fixture" -mmin +720 2>/dev/null)
assert_eq "stamp aged 2h is NOT expired" "$fresh_scan" ""
touch -d '13 hours ago' "$stamp_fixture"
old_scan=$(find "$stamp_fixture" -mmin +720 2>/dev/null)
if [ -n "$old_scan" ]; then ok "stamp aged 13h IS expired"; else bad "stamp aged 13h must expire"; fi
rm -f "$stamp_fixture"

# ---------------------------------------------------------------------------
echo "C. deploy_restart (extracted live from deploy.sh)"

shim_dir=$(mktemp -d)
mkdir -p "$shim_dir/bin"
cat >"$shim_dir/bin/sudo" <<'EOS'
#!/bin/sh
exec "$@"
EOS
cat >"$shim_dir/bin/systemctl" <<'EOS'
#!/bin/sh
# slow-unit fixture: sleeps past any small budget -> timeout kills it -> 124
sleep 30
EOS
chmod +x "$shim_dir/bin/sudo" "$shim_dir/bin/systemctl"

# Extract the REAL function text so the test runs whatever deploy.sh ships
# today (a copy would test yesterday's function).
deploy_restart_src=$(sed -n '/^deploy_restart()/,/^}/p' "$DEPLOY_SH")
if [ -n "$deploy_restart_src" ]; then ok "deploy_restart extracted from deploy.sh"; else bad "deploy_restart not found in deploy.sh"; fi

dr_out=$(PATH="$shim_dir/bin:$PATH" bash -c "$deploy_restart_src"' && deploy_restart wedged-unit 1' 2>&1)
dr_rc=$?
assert_eq "rc-124 path returns 0 (deploy continues)" "$dr_rc" "0"
assert_contains "rc-124 path warns with the unit name" "$dr_out" "wedged-unit.service not active after 1s"
assert_contains "rc-124 warn carries the journal pointer" "$dr_out" "journalctl -u wedged-unit.service"

cat >"$shim_dir/bin/systemctl" <<'EOS'
#!/bin/sh
exit 0
EOS
chmod +x "$shim_dir/bin/systemctl"
dr2_out=$(PATH="$shim_dir/bin:$PATH" bash -c "$deploy_restart_src"' && deploy_restart fine-unit 5' 2>&1)
dr2_rc=$?
assert_eq "success path returns 0" "$dr2_rc" "0"
assert_eq "success path stays silent" "$dr2_out" ""

# ---------------------------------------------------------------------------
echo "D. probe_endpoint + batch ordering (extracted + source tripwires)"

probe_src=$(sed -n '/^probe_endpoint()/,/^}/p' "$PDC_SH")
if [ -n "$probe_src" ]; then ok "probe_endpoint extracted from pre-deploy-check.sh"; else bad "probe_endpoint not found in pre-deploy-check.sh"; fi

probe_dir=$(mktemp -d)
cat >"$shim_dir/bin/curl" <<'EOS'
#!/bin/sh
# fixture curl: succeed for port 9001 writing -o target, fail otherwise
out=""
url=""
while [ $# -gt 0 ]; do
  case "$1" in
  -o) out="$2"; shift 2 ;;
  *) url="$1"; shift ;;
  esac
done
case "$url" in
*":9001"*) printf 'metric_a 1\n' >"${out:-/dev/null}"; exit 0 ;;
*) exit 1 ;;
esac
EOS
chmod +x "$shim_dir/bin/curl"

PATH="$shim_dir/bin:$PATH" PROBE_DIR="$probe_dir" bash -c "$probe_src"' && probe_endpoint alive-svc 9001; probe_endpoint dead-svc 9002'
if [ -e "$probe_dir/alive-svc.ok" ] && grep -q 'metric_a 1' "$probe_dir/alive-svc.body"; then
  ok "alive endpoint writes .ok + intact .body"
else
  bad "alive endpoint must write .ok + .body"
fi
if [ ! -e "$probe_dir/dead-svc.ok" ] && [ ! -e "$probe_dir/dead-svc.body" ]; then
  ok "dead endpoint writes neither marker"
else
  bad "dead endpoint must write nothing"
fi
rm -rf "$probe_dir"

# The 2026-10-17 use-before-set class: the port registry derivation must
# appear BEFORE the first background probe launch in the file.
ports_line=$(grep -n 'GATUS_SERVICE_METRIC_PORTS=$(' "$PDC_SH" | head -1 | cut -d: -f1)
probe_line=$(grep -n 'probe_endpoint .* &' "$PDC_SH" | head -1 | cut -d: -f1)
if [ -n "$ports_line" ] && [ -n "$probe_line" ] && [ "$ports_line" -lt "$probe_line" ]; then
  ok "port registry computed before the probe batch (no use-before-set)"
else
  bad "port registry must precede the probe batch (ports@$ports_line probes@$probe_line)"
fi

# Per-probe files (not shared >>): tripwire on the marker write form.
assert_contains "per-probe ok-marker write form preserved" "$(grep -c ': >"\$PROBE_DIR/\$1.ok"' "$PDC_SH")" "1"

# ---------------------------------------------------------------------------
echo "E. force-override ladder (freeze #49 tier-2 extreme-band veto)"

# force_level() extracted live from deploy.sh — the REAL function text runs
# (same pattern as group C: a copy would test yesterday's function).
force_level_fn=$(sed -n '/^force_level() {/,/^}/p' "$DEPLOY_SH")
if [ -n "$force_level_fn" ]; then ok "force_level() present in deploy.sh"; else bad "force_level() missing from deploy.sh"; fi

level_unset=$(env -u DEPLOY_FORCE_PRESSURE bash -c "$force_level_fn"'; force_level')
assert_eq "unset DEPLOY_FORCE_PRESSURE maps to 0" "$level_unset" "0"
assert_eq "garbage value maps to 0" "$(DEPLOY_FORCE_PRESSURE=yes bash -c "$force_level_fn"'; force_level')" "0"
assert_eq "=1 maps to 1" "$(DEPLOY_FORCE_PRESSURE=1 bash -c "$force_level_fn"'; force_level')" "1"
assert_eq "=2 maps to 2" "$(DEPLOY_FORCE_PRESSURE=2 bash -c "$force_level_fn"'; force_level')" "2"

# Tier-2 tripwires: the extreme-band condition, the =2 escape hint, and the
# freeze citations must all stay in deploy.sh.
assert_contains "tier-2 extreme-band condition present" "$(grep -c 'io_psi_avg10:-0} >= 80' "$DEPLOY_SH")" "1"
assert_contains "tier-2 =2 escape hint present" "$(grep -c 'DEPLOY_FORCE_PRESSURE=2 nix run' "$DEPLOY_SH")" "1"
assert_contains "tier-2 veto text cites both fatal freezes" "$(grep -c 'twice ended in a WDT freeze' "$DEPLOY_SH")" "1"

# The exact band condition extracted and exercised at the four corners:
# the fatal corner (92.9/101.8 = freeze #49's entry sample) is IN band; the
# moderate-PSI, phantom (high PSI, idle disk), and 50/50 corners are OUT —
# =1 keeps working everywhere outside the fatal corner.
band_cond=$(grep -m1 -o 'awk "BEGIN{exit !(${io_psi_avg10:-0} >= 80)}" && awk "BEGIN{exit !(${disk_busy:-0} >= 80)}"' "$DEPLOY_SH")
if [ -n "$band_cond" ]; then ok "band condition extractable verbatim"; else bad "band condition not found verbatim"; fi
io_psi_avg10=92.9 disk_busy=101.8 eval "$band_cond" && ok "freeze-#49 corner (92.9/101.8) trips tier 2" || bad "freeze-#49 corner must trip tier 2"
io_psi_avg10=75 disk_busy=100 eval "$band_cond" && bad "moderate PSI (75) must NOT trip tier 2" || ok "moderate PSI stays =1 territory"
io_psi_avg10=95 disk_busy=10 eval "$band_cond" && bad "phantom PSI (idle disk) must NOT trip tier 2" || ok "phantom corner stays =1 territory"
io_psi_avg10=50 disk_busy=50 eval "$band_cond" && bad "50/50 must NOT trip tier 2" || ok "50/50 stays =1 territory"

# =2 must clear the first (=1) gate too: no legacy literal "!= 1" override
# site may remain anywhere in deploy.sh.
legacy_sites=$(grep -c 'DEPLOY_FORCE_PRESSURE:-0}" != "1"' "$DEPLOY_SH" || true)
assert_eq "no legacy != 1 override sites remain" "$legacy_sites" "0"

# ---------------------------------------------------------------------------
echo
if [ "$FAILED" -eq 0 ]; then
  echo "deploy-pipeline selftest: $TESTS assertions hold"
  exit 0
else
  echo "deploy-pipeline selftest: $FAILED of $TESTS assertions FAILED"
  exit 1
fi
