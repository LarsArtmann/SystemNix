# unit_enabled — post-deploy battery enable-gate probe.
#
# Extracted 2026-11-08 from post-deploy-check.sh (batch §f.37 asked for the
# shared-lib export so pre-deploy/mutation scripts can reuse it) so the
# wants-symlink resolution has a functional harness leg
# (scripts/test-post-deploy-probe-fixtures.sh).
#
# Enable-gate: is the unit ENABLED in this generation (a .wants symlink
# exists for it or its same-name timer), not merely present? NixOS writes
# every unit file defined in the generation to /etc/systemd/system even when
# the owning service module is disabled, so `test -e /etc/systemd/system/X`
# gated smoke sections on DEAD services (the 2026-08-18 sweep ask). Covers
# multi-user/timers/late-applications wants dirs and wants-symlinks owned by
# other units (paperless-scheduler.service.wants/paperless-web.service).
unit_enabled() {
  local u="$1" alt="" hit=""
  [ "${u%.service}" != "$u" ] && alt="${u%.service}.timer"
  # shellcheck disable=SC2046  # the optional -o clause is a single word by construction
  # Trailing slash on the root: /etc/systemd/system is a SYMLINK to
  # /etc/static/systemd/system, and find does not follow a symlinked root
  # without it (every probe then silently returns nothing = everything SKIPs).
  hit=$(find /etc/systemd/system/ -maxdepth 2 -path '*.wants/*' \( -name "$u" $([ -n "$alt" ] && printf '%s' "-o -name $alt") \) -print -quit 2>/dev/null || true)
  [ -n "$hit" ]
}
