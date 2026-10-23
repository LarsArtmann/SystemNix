# port-guard.nix — release-verified port handoff (the berth pattern, adopted
# 2026-10-23 from the T-Crypt/berth analysis; plan: docs/planning/
# 2026-10-23_06-59_SUPERB-berth-patterns-adoption.md T1).
#
# mkPortGuard { pkgs, name, logTag, ownerUnits } → a standalone script for a
# `+`-privileged ExecStartPre. Semantics (extracted from llama-rag.nix's
# PROVEN portGuardScript, live since 2026-09-18 — extraction, not rewrite:
# the body differs from the original only by parameterization, the start-time
# identity, and the release verification):
#
#   1. Enumerate listeners on :$1 (port passed as argv[1]) via ss -tlnp.
#   2. A listener whose /proc/<pid>/cgroup matches ANY ownerUnit is SPARED
#      (the module's own instance — foreign-user rogues need the root the
#      `+` prefix provides; ss shows no pids for foreign listeners otherwise).
#   3. Foreign listeners are signalled TERM, then (2 s later) KILL — berth's
#      driver-confirmed-release lesson: a stop is never assumed, the port is
#      re-checked after the kill loop and a remaining foreign holder FAILS
#      the start with a named holder (bind-blocked) instead of letting the
#      server die on an opaque EADDRINUSE (the flm 5× incident class:
#      09-04/05/07 zombie corpse, 09-18 rogues, 09-30 orphan pair).
#   4. PID start-time identity (/proc/<pid>/stat field 22): snapshotted at
#      enumeration, re-verified immediately before EVERY signal — a recycled
#      PID never inherits a kill decision (berth: PID+start-time lease
#      identity). A mismatch logs loudly and spares the new occupant.
#
# Owners spared at verification too: a lingering owner-cgroup listener at
# ExecStartPre time is the old instance draining — systemd serializes the
# restart, so that is NOT a start blocker.
#
# Unkillable-holder class: a zombie corpse's shared fd table pins the port
# with no killable process (llama-rag.md 2026-09-04). The guard cannot fix
# that — it NAMES it (journal line with pid + cgroup) and fails fast; only a
# reboot (or eventual PID-1 reaping, seen 2026-09-30) releases the socket.
lib:
{
  pkgs,
  name,
  logTag,
  ownerUnits,
}:
assert lib.assertMsg (builtins.length ownerUnits > 0) "mkPortGuard: ownerUnits must name at least one unit whose listeners are legitimate";
pkgs.writeShellScript "${name}.sh" ''
  set -euo pipefail
  port="$1"

  # /proc/<pid>/stat field 22 (starttime) — everything before the LAST ')'
  # of comm is stripped, then starttime is field 20 of the remainder
  # (fields 1-2 are pid + comm). Empty output = process gone.
  _stat22() {
    local stat rem
    stat="$("${pkgs.coreutils}/bin/cat" "/proc/$1/stat" 2>/dev/null || true)"
    [ -n "$stat" ] || return 0
    rem="''${stat##*) }"
    printf '%s' "$rem" | "${pkgs.gawk}/bin/awk" '{print $20}'
  }

  # True iff pid is still the SAME process (same start time) as enumerated.
  _same_process() {
    local now
    now="$(_stat22 "$1")"
    [ -n "$now" ] && [ "$now" = "$2" ]
  }

  pids="$("${pkgs.iproute2}/bin/ss" -tlnp "sport = :$port" 2>/dev/null \
    | "${pkgs.gnused}/bin/sed" -n 's/.*pid=\([0-9]*\).*/\1/p' \
    | "${pkgs.coreutils}/bin/sort" -u || true)"
  for pid in $pids; do
    cgroup="$("${pkgs.coreutils}/bin/cat" "/proc/$pid/cgroup" 2>/dev/null || true)"
    case "$cgroup" in
      ${lib.concatStringsSep "|" (map (u: "*${u}*") ownerUnits)}) ;;
      *)
        st0="$(_stat22 "$pid")"
        if [ -z "$st0" ]; then
          echo "${logTag}: listener pid $pid on :$port already exited (foreign cgroup '$cgroup') - nothing to signal"
          continue
        fi
        echo "${logTag}: stale listener on :$port (pid $pid, foreign cgroup '$cgroup', starttime $st0) - killing"
        if _same_process "$pid" "$st0"; then
          "${pkgs.coreutils}/bin/kill" "$pid" 2>/dev/null || true
        else
          echo "${logTag}: pid $pid RECYCLED before TERM (starttime changed) - NOT signalling the new occupant" >&2
        fi
        "${pkgs.coreutils}/bin/sleep" 2
        if _same_process "$pid" "$st0"; then
          "${pkgs.coreutils}/bin/kill" -9 "$pid" 2>/dev/null || true
        fi
        ;;
    esac
  done

  # Release verification (berth: never grant because a process exited) —
  # the port must be free of FOREIGN holders before the engine binds.
  foreign_left=0
  left="$("${pkgs.iproute2}/bin/ss" -tlnp "sport = :$port" 2>/dev/null \
    | "${pkgs.gnused}/bin/sed" -n 's/.*pid=\([0-9]*\).*/\1/p' \
    | "${pkgs.coreutils}/bin/sort" -u || true)"
  for pid in $left; do
    cgroup="$("${pkgs.coreutils}/bin/cat" "/proc/$pid/cgroup" 2>/dev/null || true)"
    case "$cgroup" in
      ${lib.concatStringsSep "|" (map (u: "*${u}*") ownerUnits)})
        echo "${logTag}: :$port still held by owner-unit pid $pid (old instance draining; systemd serializes the restart)"
        ;;
      *)
        foreign_left=1
        echo "${logTag}: BIND-BLOCKED: :$port still held by foreign pid $pid (cgroup '$cgroup') after release attempt - expect EADDRINUSE; the unkillable-corpse class needs a reboot (llama-rag.md 2026-09-04)" >&2
        ;;
    esac
  done
  [ "$foreign_left" = "0" ]
''
