#!/usr/bin/env bash
# guard-sim.sh: dry-run of the REAL built memory-emergency-guard script against
# fixture cgroups and sleeper processes, inside a user+mount namespace.
#
# The VM test (tests/test-memory-emergency-guard.nix) proves the guard with
# real systemd in about two minutes. This runs in seconds, against the script
# in the shape a deploy would ship, and covers what the VM cannot: the
# evo-x2 shape, process churn during the guard's /proc reads, and a control
# run against any older build (a scenario that passes on a build with a known
# defect proves nothing).
#
# Usage:
#   guard-sim.sh [test|host] [scenario...]   build the guard script (test =
#                                            the VM node, host = evo-x2) and
#                                            run the scenarios (default: all)
#   guard-sim.sh --live [scenario...]        run against the script that is
#                                            live right now (control run)
#   guard-sim.sh --guard <binary> [scenario...]
#   guard-sim.sh --units [test|host|--live|--guard <binary>] [leg...]
#                                            run the UNIT-CALL legs instead
#                                            (trip_restore_rearm catchup
#                                            zone6_iopause_host zone6_escalation_host)
#   guard-sim.sh --list                      print the scenario names
#
# Scenarios (zone 6, IO-PAUSE selection):
#   nopattern      a driver outside every pattern: nobody paused, mover named
#   driver         a pattern driver with one headless group: paused, resumed
#   tty            the driver behind a controlling TTY: skipped, never paused
#   idle           an idle lifetime heavyweight: not a driver
#   bystander      a pattern cgroup below the top-share bar: not a driver
#   procfail       empty /proc scan: nobody paused (fail closed)
#   walkfail       missing cgroup tree: nobody paused (fail closed)
#   scopetrick     a login-session scope holding one bystander: never paused
#   scopedriver    the scope with an I/O-stalled member: that one is paused
#   sshshape       TTY tree + sshd monitor in one scope: nobody paused
#   svcshape       a service with a listener stand-in and a stalled group:
#                  only the stalled group is paused
#   capshape       nine stalled groups in one cgroup: 8 paused (the cap)
#   vanishservice  /proc entries vanish while the guard reads: fixture seen
#   vanishscope    the same with a stalled scope member under a fake /proc
#
# Nothing here touches the system: the state and textfile directories are
# bind-mounted throwaway copies, systemctl and systemd-run are stubs on PATH,
# and every process the guard can signal is a sleeper this script started.
# Exit status: 0 = every scenario passed, 1 = at least one failed.
set -euo pipefail

ALL_SCENARIOS=(
  nopattern driver tty idle bystander procfail walkfail
  scopetrick scopedriver sshshape svcshape capshape
  vanishservice vanishscope
)
# Unit-call legs (--units): socket and churn stops, restore, churn re-arm,
# backup catch-up, the zone-6 escalation. systemctl is a recording stub, so
# these legs need no fixture cgroups.
ALL_LEGS=(trip_restore_rearm catchup zone6_iopause_host zone6_escalation_host)

die() {
  echo "guard-sim: $*" >&2
  exit 2
}

usage() {
  # Spelled out, not read from "$0": behind the flake app wrapper "$0" is the
  # wrapper.
  cat >&2 <<'USAGE'
usage: guard-sim.sh [test|host] [scenario...]   build the guard script (test = the VM node,
                                                 host = evo-x2) and run the scenarios
       guard-sim.sh --live [scenario...]        run against the script that is live right now
       guard-sim.sh --guard <binary> [scenario...]
       guard-sim.sh --list                      print the scenario names
USAGE
}

# --- inner mode: one scenario, already inside the namespace -----------------
harness_iopause() { # <guard binary> <scenario>
  local GUARD="$1" SCEN="$2"
  # The scenario checks read non-zero statuses on purpose.
  set +e +o pipefail
  set -u
  local SIM="${SIM_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/systemnix/sim-work.$$}"
  local PATTERNS="nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run-"
  local PIDS="" CAP="" SP="" TP="" BY="" ST="" FAILS=0

  # shellcheck disable=SC2329  # invoked by the trap below
  cleanup() {
    # Runs on EVERY exit: a verdict abort must not leave stopped sleepers or
    # io.stat writers behind for the next scenario.
    local p
    # shellcheck disable=SC2086  # deliberate word split over the pid list
    for p in $PIDS $SP $TP $BY $ST $CAP; do
      [ -n "$p" ] || continue
      kill -CONT "$p" 2>/dev/null
      kill "$p" 2>/dev/null
    done
    pgrep -f '^sleep 611$' | while read -r p; do kill "$p" 2>/dev/null; done
  }
  trap cleanup EXIT

  rm -rf "${SIM:?}"
  mkdir -p "$SIM/state" "$SIM/textfile" "$SIM/stub" "$SIM/gt" "$SIM/emptyproc"
  [ "$SCEN" = walkfail ] || mkdir -p "$SIM/cgt"
  mount --bind "$SIM/state" /var/lib/memory-emergency-guard || exit 9
  mount --bind "$SIM/textfile" /var/lib/prometheus-node-exporter/textfile_collectors || exit 9

  # shellcheck disable=SC2016  # the stub's own text, never a shell expansion here
  printf '#!/bin/sh\ncase "$1" in show) echo inactive ;; *) exit 0 ;; esac\n' >"$SIM/stub/systemctl"
  printf '#!/bin/sh\nexit 0\n' >"$SIM/stub/systemd-run"
  chmod +x "$SIM/stub/"*
  # Copy of the built script with the stub dir in front of the wrapper PATH.
  sed "s|^export PATH=\"|export PATH=\"$SIM/stub:|" "$GUARD" >"$SIM/guard"
  chmod +x "$SIM/guard"
  grep -q "^export PATH=\"$SIM/stub:" "$SIM/guard" || {
    echo "HARNESS BUG: the guard wrapper has no PATH line to prefix" >&2
    exit 3
  }

  # Kernel source fakes (same shapes as tests/test-memory-emergency-guard.nix).
  local zram_orig
  zram_orig=$(awk 'BEGIN { printf "%d", 32212254720 * 0.20 }')
  printf 'MemTotal:       10000000 kB\nMemAvailable:    3000000 kB\n' >"$SIM/gt/meminfo"
  printf '%s 1000000000 1000000000 0 0 0 0 0\n' "$zram_orig" >"$SIM/gt/mmstat"
  printf '32212254720\n' >"$SIM/gt/disksize"
  printf 'some avg10=0.10 avg60=4.00 avg300=5.00 total=1000000\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=100000\n' >"$SIM/gt/psi"
  printf 'some avg10=0.00 avg60=55.00 avg300=0.00 total=0\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=0\n' >"$SIM/gt/iopsi"
  printf '8 0 nvme0n1 1 2 3 4 5 6 7 8 9 13000 11 12\n' >"$SIM/gt/diskstats"

  start_writer() { # <cgroup-rel-path> <step-bytes per 0.2 s> <start-bytes>
    # Written by rename (2026-11-26): a reader must never see the truncated,
    # not yet rewritten file (an empty io.stat drops the cgroup from a sample).
    mkdir -p "$SIM/cgt/$1"
    # shellcheck disable=SC2016  # the writer's program text, arguments arrive as $1..$3
    setsid bash -c 'd="$1"; b="$3"; while :; do printf "8:0 rbytes=%s wbytes=0\n" "$b" > "$d/io.stat.tmp" && mv -f "$d/io.stat.tmp" "$d/io.stat"; b=$((b + $2)); sleep 0.2; done' \
      guard-sim-writer "$SIM/cgt/$1" "$2" "$3" >/dev/null 2>&1 &
    PIDS="$PIDS $!"
  }
  static_cgroup() { # <cgroup-rel-path> <bytes>
    mkdir -p "$SIM/cgt/$1"
    printf '8:0 rbytes=%s wbytes=0\n' "$2" >"$SIM/cgt/$1/io.stat"
  }
  start_sleeper() { # prints pid
    setsid sleep 600 >/dev/null 2>&1 &
    echo $!
  }
  start_tty_sleeper() { # prints the pid of the sleep inside a pty session
    script -qec "sleep 611" /dev/null >/dev/null 2>&1 &
    PIDS="$PIDS $!"
    # Polled (2026-11-26): a fixed 0.5 s sleep came back empty on 1 of 9 runs.
    local tp=""
    for _ in $(seq 50); do
      tp=$(pgrep -f '^sleep 611$' | head -1)
      [ -n "$tp" ] && break
      sleep 0.1
    done
    [ -n "$tp" ] || {
      echo "HARNESS BUG: tty sleeper never appeared" >&2
      exit 3
    }
    echo "$tp"
  }
  fake_dstate_proc() { # <pid>: a /proc stand-in whose process is reported in D state
    mkdir -p "$SIM/fakeproc/$1/task/$1"
    sed -E 's/\) [RSDZTtXx+] /) D /' "/proc/$1/stat" >"$SIM/fakeproc/$1/stat"
    cp "$SIM/fakeproc/$1/stat" "$SIM/fakeproc/$1/task/$1/stat"
    grep -q "^[0-9]* (.*) D " "$SIM/fakeproc/$1/stat" || {
      echo "HARNESS BUG: state not rewritten to D" >&2
      exit 3
    }
  }
  fake_plain_proc() { # <pid>: a /proc stand-in entry that keeps the real state
    mkdir -p "$SIM/fakeproc/$1/task/$1"
    cp "/proc/$1/stat" "$SIM/fakeproc/$1/stat"
    cp "/proc/$1/stat" "$SIM/fakeproc/$1/task/$1/stat"
  }
  start_vanishers() {
    # Short-lived processes created BEFORE the fixture (so they sort below it)
    # that die across the window in which the guard lists and reads /proc:
    # the guard reaches its reads about 1.9 s after this point (1 s sample
    # window), the thread-state passes of the current script from about 1.0 s.
    # One of them is listed and gone when the reader reaches it: the reader
    # shape decides whether every later entry survives (the 2026-11-26
    # truncation defect: gawk aborts the batch on an unopenable ARGUMENT).
    local ms
    for ms in $(seq 1000 10 2600); do
      (sleep "$(printf '%d.%03d' $((ms / 1000)) $((ms % 1000)))") >/dev/null 2>&1 &
    done
  }

  local MB=1048576
  case "$SCEN" in
  nopattern)
    start_writer system.slice/offender.service $((250 * MB)) $((1000 * MB))
    ;;
  driver)
    start_writer system.slice/monitor365-server.service $((250 * MB)) $((1000 * MB))
    sleep 0.3
    SP=$(start_sleeper)
    PIDS="$PIDS $SP"
    echo "$SP" >"$SIM/cgt/system.slice/monitor365-server.service/cgroup.procs"
    ;;
  tty)
    start_writer system.slice/monitor365-server.service $((250 * MB)) $((1000 * MB))
    sleep 0.3
    TP=$(start_tty_sleeper)
    echo "$TP" >"$SIM/cgt/system.slice/monitor365-server.service/cgroup.procs"
    ;;
  idle)
    static_cgroup system.slice/monitor365-server.service $((50000 * MB))
    sleep 0.3
    SP=$(start_sleeper)
    PIDS="$PIDS $SP"
    echo "$SP" >"$SIM/cgt/system.slice/monitor365-server.service/cgroup.procs"
    ;;
  bystander)
    start_writer system.slice/offender.service $((250 * MB)) $((1000 * MB))
    start_writer system.slice/monitor365-server.service $((2 * MB)) $((50000 * MB))
    sleep 0.3
    SP=$(start_sleeper)
    PIDS="$PIDS $SP"
    echo "$SP" >"$SIM/cgt/system.slice/monitor365-server.service/cgroup.procs"
    ;;
  procfail)
    start_writer system.slice/monitor365-server.service $((250 * MB)) $((1000 * MB))
    sleep 0.3
    SP=$(start_sleeper)
    PIDS="$PIDS $SP"
    echo "$SP" >"$SIM/cgt/system.slice/monitor365-server.service/cgroup.procs"
    ;;
  walkfail)
    ;;
  scopetrick)
    # A login-session scope that moves data, holding ONE headless S-state
    # member (the sshd-session monitor stand-in): cgroup evidence alone
    # must never pause it (live 2026-11-26: seven logins' monitors frozen).
    start_writer user.slice/user-1000.slice/session-1653.scope $((250 * MB)) $((1000 * MB))
    sleep 0.3
    SP=$(start_sleeper)
    PIDS="$PIDS $SP"
    echo "$SP" >"$SIM/cgt/user.slice/user-1000.slice/session-1653.scope/cgroup.procs"
    ;;
  scopedriver)
    # The same scope, but the headless member IS I/O-stalled (reported in D
    # state by a /proc stand-in): per-group evidence, so it is paused.
    start_writer user.slice/user-1000.slice/session-1653.scope $((250 * MB)) $((1000 * MB))
    sleep 0.3
    SP=$(start_sleeper)
    PIDS="$PIDS $SP"
    echo "$SP" >"$SIM/cgt/user.slice/user-1000.slice/session-1653.scope/cgroup.procs"
    fake_dstate_proc "$SP"
    ;;
  sshshape)
    # The real shape of an interactive SSH login: the scope moves data, a
    # TTY-holding build tree and the headless sshd monitor sit in it. The
    # tree is skipped (TTY), the monitor is skipped (not stalled): nobody
    # is paused and both reasons are in the journal.
    start_writer user.slice/user-1000.slice/session-1653.scope $((250 * MB)) $((1000 * MB))
    sleep 0.3
    TP=$(start_tty_sleeper)
    SP=$(start_sleeper)
    PIDS="$PIDS $SP"
    printf '%s\n%s\n' "$SP" "$TP" >"$SIM/cgt/user.slice/user-1000.slice/session-1653.scope/cgroup.procs"
    ;;
  svcshape)
    # The nix-daemon shape (live 2026-11-26 17:16: the listener, five
    # workers and three builds frozen for an hour on the builds' I/O): a
    # SERVICE cgroup holding a bystander (S state, the listener stand-in)
    # and an I/O-stalled group. Only the stalled group may be paused.
    start_writer system.slice/nix-daemon.service $((250 * MB)) $((1000 * MB))
    sleep 0.3
    BY=$(start_sleeper)
    PIDS="$PIDS $BY"
    ST=$(start_sleeper)
    PIDS="$PIDS $ST"
    printf '%s\n%s\n' "$BY" "$ST" >"$SIM/cgt/system.slice/nix-daemon.service/cgroup.procs"
    fake_dstate_proc "$ST"
    fake_plain_proc "$BY"
    ;;
  capshape)
    # Nine stalled groups in one cgroup: the pause cap (8) counts groups.
    # Live 2026-11-26 07:55: one trip SIGSTOPped 10 groups, 9 of them in
    # nix-daemon.service, because the cap was checked once per cgroup.
    start_writer system.slice/nix-daemon.service $((250 * MB)) $((1000 * MB))
    sleep 0.3
    local _
    for _ in 1 2 3 4 5 6 7 8 9; do
      local CP
      CP=$(start_sleeper)
      PIDS="$PIDS $CP"
      CAP="$CAP $CP"
      fake_dstate_proc "$CP"
    done
    # shellcheck disable=SC2086  # deliberate word split over the pid list
    printf '%s\n' $CAP >"$SIM/cgt/system.slice/nix-daemon.service/cgroup.procs"
    ;;
  vanishservice | vanishscope)
    # Entries vanish while the guard reads /proc; the fixture (created
    # AFTER them, so it sorts above them) must still be seen and paused.
    # vanishservice: real /proc, single-group service (cgroup evidence).
    # vanishscope: fake /proc with the fixture in D state (per-group
    # evidence); the thread-state passes run under the same churn.
    start_vanishers
    if [ "$SCEN" = vanishservice ]; then
      start_writer system.slice/monitor365-server.service $((250 * MB)) $((1000 * MB))
      sleep 0.3
      SP=$(start_sleeper)
      PIDS="$PIDS $SP"
      echo "$SP" >"$SIM/cgt/system.slice/monitor365-server.service/cgroup.procs"
    else
      start_writer user.slice/user-1000.slice/session-1653.scope $((250 * MB)) $((1000 * MB))
      sleep 0.3
      SP=$(start_sleeper)
      PIDS="$PIDS $SP"
      echo "$SP" >"$SIM/cgt/user.slice/user-1000.slice/session-1653.scope/cgroup.procs"
      fake_dstate_proc "$SP"
    fi
    ;;
  *)
    echo "HARNESS BUG: unknown scenario $SCEN" >&2
    exit 2
    ;;
  esac
  sleep 0.5

  local PROC=/proc
  [ "$SCEN" = procfail ] && PROC="$SIM/emptyproc"
  case "$SCEN" in
  scopedriver | svcshape | capshape | vanishscope) PROC="$SIM/fakeproc" ;;
  esac
  local CG="$SIM/cgt"
  [ "$SCEN" = walkfail ] && CG="$SIM/does-not-exist"

  run_guard_calm_inputs() {
    MEMINFO_SRC="$SIM/gt/meminfo" ZRAM_MM_STAT_SRC="$SIM/gt/mmstat" ZRAM_DISKSIZE_SRC="$SIM/gt/disksize" \
      PSI_SRC="$SIM/gt/psi" IO_PSI_SRC="$SIM/gt/iopsi" DISKSTATS_SRC="$SIM/gt/diskstats" \
      CGROUP_IO_SRC="$CG" PROC_ROOT="$PROC" CGROUP_SAMPLE_SECONDS=1 \
      IO_PAUSE_ENABLE=true IO_PAUSE_PATTERNS="$PATTERNS" "$@"
  }

  check() { # <label> <ok: 0 = held>
    if [ "$2" -eq 0 ]; then echo "  ok    $1"; else
      echo "  FAIL  $1"
      FAILS=$((FAILS + 1))
    fi
  }
  has() { grep -qF -- "$1" "$SIM/out1"; }
  lacks() { ! grep -qF -- "$1" "$SIM/out1"; }
  state_is() { # <pid> <first letter of ps stat>
    local s
    s=$(ps -o stat= -p "$1" 2>/dev/null | tr -d ' ')
    [ "${s:0:1}" = "$2" ]
  }
  paused_in_state() { grep -qF -- "$1 " "$SIM/state/io-paused" 2>/dev/null; }

  echo "=== scenario $SCEN ==="
  run_guard_calm_inputs "$SIM/guard" >"$SIM/out1" 2>&1
  echo "guard rc=$?"
  grep -E 'MEMORY EMERGENCY|IO-PAUSE|Traceback|error|not found|No such' "$SIM/out1" | cut -c1-900

  local n p
  case "$SCEN" in
  nopattern)
    has "NO eligible headless tree matched"
    check "no-match line" $?
    has "no pattern covers any driver"
    check "reason names the missing pattern" $?
    lacks "SIGSTOPped"
    check "nobody paused" $?
    ;;
  driver)
    has "SIGSTOPped 1 headless driver process group"
    check "driver paused" $?
    has "(pgid $SP, D "
    check "pause line names the pgid" $?
    state_is "$SP" T
    check "sleeper is stopped" $?
    paused_in_state "$SP"
    check "io-paused records the pgid" $?
    ;;
  tty)
    has "holds a controlling TTY"
    check "TTY skip line" $?
    lacks "SIGSTOPped"
    check "nobody paused" $?
    state_is "$TP" S
    check "tty sleeper still running" $?
    ;;
  idle)
    has "no cgroup moved data"
    check "idle heavyweight is no driver" $?
    lacks "SIGSTOPped"
    check "nobody paused" $?
    ;;
  bystander)
    has "none is a driver"
    check "bystander below the share bar is no driver" $?
    lacks "SIGSTOPped"
    check "nobody paused" $?
    ;;
  procfail)
    has "process scan unavailable"
    check "fail-closed on an empty scan" $?
    lacks "SIGSTOPped"
    check "nobody paused" $?
    ;;
  walkfail)
    has "cgroup walk unavailable"
    check "fail-closed on a missing walk" $?
    lacks "SIGSTOPped"
    check "nobody paused" $?
    ;;
  scopetrick)
    has "was not I/O-stalled in the trip sample"
    check "scope bystander skipped with a reason" $?
    has "beside other groups were not I/O-stalled"
    check "no-match line names the bystander reason" $?
    lacks "SIGSTOPped"
    check "nobody paused" $?
    state_is "$SP" S
    check "scope bystander still running" $?
    ;;
  scopedriver)
    has "SIGSTOPped 1 headless driver process group"
    check "stalled scope member paused" $?
    has "(pgid $SP, D "
    check "pause line carries the stall evidence" $?
    state_is "$SP" T
    check "sleeper is stopped" $?
    ;;
  sshshape)
    n=$(grep -cF "holds a controlling TTY" "$SIM/out1")
    [ "${n:-0}" -ge 1 ]
    check "tty tree skipped ($n line)" $?
    has "was not I/O-stalled in the trip sample"
    check "sshd monitor skipped as not stalled" $?
    lacks "SIGSTOPped"
    check "nobody paused" $?
    state_is "$SP" S
    check "monitor still running" $?
    ;;
  svcshape)
    has "SIGSTOPped 1 headless driver process group"
    check "exactly the stalled group of the service paused" $?
    has "(pgid $ST, D "
    check "pause line names the stalled pgid" $?
    has "pgid $BY in system.slice/nix-daemon.service was not I/O-stalled"
    check "listener stand-in skipped with a reason" $?
    state_is "$ST" T
    check "stalled group is stopped" $?
    state_is "$BY" S
    check "listener stand-in still running" $?
    ;;
  capshape)
    has "SIGSTOPped 8 headless driver process group"
    check "cap stops at 8 groups" $?
    has "the pause cap (8 groups) is reached"
    check "cap named on the pause line" $?
    n=0
    # shellcheck disable=SC2086  # deliberate word split over the pid list
    for p in $CAP; do state_is "$p" T && n=$((n + 1)); done
    [ "$n" -eq 8 ]
    check "exactly 8 of 9 groups stopped (got $n)" $?
    ;;
  vanishservice)
    has "SIGSTOPped 1 headless driver process group"
    check "fixture survived the vanishing entries" $?
    lacks "not in the process map"
    check "no listed pid lost from the process map" $?
    state_is "$SP" T
    check "sleeper is stopped" $?
    ;;
  vanishscope)
    has "SIGSTOPped 1 headless driver process group"
    check "fixture survived the vanishing entries" $?
    has "(pgid $SP, D "
    check "stall evidence collected under churn" $?
    state_is "$SP" T
    check "sleeper is stopped" $?
    ;;
  esac
  echo "io-paused file:"
  cat "$SIM/state/io-paused" 2>/dev/null || echo "(absent)"

  case "$SCEN" in
  driver | scopedriver | svcshape | capshape | vanishservice | vanishscope)
    echo "=== resume run (hard cap: pause epoch backdated 4000 s) ==="
    {
      echo "$(($(date +%s) - 4000))"
      tail -n +2 "$SIM/state/io-paused"
    } >"$SIM/state/io-paused.new"
    mv "$SIM/state/io-paused.new" "$SIM/state/io-paused"
    run_guard_calm_inputs "$SIM/guard" >"$SIM/out2" 2>&1
    echo "guard rc=$?"
    grep -E 'MEMORY EMERGENCY IO-RESUME|Traceback|error' "$SIM/out2" | cut -c1-600
    n=0
    # shellcheck disable=SC2086  # deliberate word split over the pid list
    for p in $SP $ST $CAP; do state_is "$p" T && n=$((n + 1)); done
    [ "$n" -eq 0 ]
    check "hard-cap resume released every paused group ($n still stopped)" $?
    ;;
  esac

  if [ "$FAILS" -eq 0 ]; then
    echo "VERDICT $SCEN: PASS"
    exit 0
  fi
  echo "VERDICT $SCEN: FAIL ($FAILS expectation(s) broken)"
  exit 1
}

# --- inner mode: one unit-call leg, already inside the namespace ------------
harness_units() { # <guard binary> <leg>
  # The legs read non-zero statuses on purpose.
  set +e +o pipefail
  set -u
  local GUARD="$1" LEG="$2"
  local SIM="${SIM_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/systemnix/sim-units-work.$$}"
  local STUB_DIR="$SIM/stub"
  local FAILS=0 WR last

  check() { # <description> <shell test...>
    local desc="$1"
    shift
    # shellcheck disable=SC2294  # the legs hand over shell TEST EXPRESSIONS as text; that is the interface
    if eval "$@"; then echo "PASS  $desc"; else
      echo "FAIL  $desc  [test: $*]"
      FAILS=$((FAILS + 1))
    fi
  }

  rm -rf "$SIM"
  mkdir -p "$SIM/state" "$SIM/textfile" "$SIM/stub" "$SIM/gt" "$SIM/cgt"
  mount --bind "$SIM/state" /var/lib/memory-emergency-guard || exit 9
  mount --bind "$SIM/textfile" /var/lib/prometheus-node-exporter/textfile_collectors || exit 9
  export STUB_DIR

  cat >"$SIM/stub/systemctl" <<'EOF'
  #!/bin/sh
  printf '%s\n' "$*" >> "$STUB_DIR/calls.log"
  name=$(printf '%s\n' "$*" | awk '{print $NF}')
  case "$1" in
    show)
      if [ -r "$STUB_DIR/active.$name" ]; then cat "$STUB_DIR/active.$name"; else echo inactive; fi ;;
    is-active)
      exit "$(cat "$STUB_DIR/is_active.rc" 2>/dev/null || echo 3)" ;;
    cat)
      [ -r "$STUB_DIR/missing.$name" ] && exit 1
      exit 0 ;;
    *)
      [ -r "$STUB_DIR/fail.$name" ] && exit 5
      exit 0 ;;
  esac
EOF
  printf '#!/bin/sh\nexit 0\n' >"$SIM/stub/systemd-run"
  chmod +x "$SIM/stub/"*
  sed "s|^export PATH=\"|export PATH=\"$STUB_DIR:|" "$GUARD" >"$SIM/guard"
  chmod +x "$SIM/guard"
  CHURN_UNITS=$(grep -m1 '^CHURN_UNITS=' "$GUARD" | sed -E 's/^CHURN_UNITS="(.*)"$/\1/')
  BACKUP_UNITS=$(grep -m1 '^BACKUP_UNITS=' "$GUARD" | sed -E 's/^BACKUP_UNITS="(.*)"$/\1/')
  SOCKET_UNITS=$(grep -m1 '^SOCKET_UNITS=' "$GUARD" | sed -E 's/^SOCKET_UNITS="(.*)"$/\1/')

  zram_orig=$(awk 'BEGIN { printf "%d", 32212254720 * 0.20 }')
  write_fakes() { # <avail-pct> <zram-orig> <psi-avg10> <io-avg60> <disk-ticks>
    printf 'MemTotal:       10000000 kB\nMemAvailable:    %s kB\n' "$(awk -v p="$1" 'BEGIN { printf "%d", 10000000 * p }')" >"$SIM/gt/meminfo"
    printf '%s 1000000000 1000000000 0 0 0 0 0\n' "$2" >"$SIM/gt/mmstat"
    printf '32212254720\n' >"$SIM/gt/disksize"
    printf 'some avg10=%s avg60=4.00 avg300=5.00 total=1000000\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=100000\n' "$3" >"$SIM/gt/psi"
    printf 'some avg10=0.00 avg60=%s avg300=0.00 total=0\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=0\n' "$4" >"$SIM/gt/iopsi"
    printf '8 0 nvme0n1 1 2 3 4 5 6 7 8 9 %s 11 12\n' "$5" >"$SIM/gt/diskstats"
  }

  run_guard() { # <extra env...>
    : >"$STUB_DIR/calls.log"
    MEMINFO_SRC="$SIM/gt/meminfo" ZRAM_MM_STAT_SRC="$SIM/gt/mmstat" ZRAM_DISKSIZE_SRC="$SIM/gt/disksize" \
      PSI_SRC="$SIM/gt/psi" IO_PSI_SRC="$SIM/gt/iopsi" DISKSTATS_SRC="$SIM/gt/diskstats" \
      CGROUP_IO_SRC="$SIM/cgt" CGROUP_SAMPLE_SECONDS=1 env "$@" "$SIM/guard" >"$SIM/out" 2>&1
    echo "guard rc=$?"
  }

  calls() { grep -v -E '^(cat|show) ' "$STUB_DIR/calls.log"; }
  has_call() { grep -qxF -- "$1" "$STUB_DIR/calls.log"; }
  state="/var/lib/memory-emergency-guard"

  echo "=== leg $LEG: socket='$SOCKET_UNITS' backups='$BACKUP_UNITS' churn=$(wc -w <<<"$CHURN_UNITS") units ==="

  HOST=0
  [ -z "$SOCKET_UNITS" ] && HOST=1
  echo "shape: $([ "$HOST" = 1 ] && echo HOST-observe-only || echo VM-node-with-socket)"

  # The three live churn units every trip must stop (stub answer files).
  live_units() {
    echo activating >"$STUB_DIR/active.btrbk-root.service"
    echo active >"$STUB_DIR/active.btrfs-balance-data.service"
    echo active >"$STUB_DIR/active.btrfs-scrub@-.service"
  }
  expect_trip_stops() { # <expected stop count of the 12 churn units>
    # shellcheck disable=SC2034  # n is read by the eval'd test "[ \$n = 0 ]" of the next line
    local n=0 u
    # shellcheck disable=SC2086  # deliberate word split over the baked unit list
    for u in $CHURN_UNITS; do has_call "stop $u" || {
      echo "missing stop $u"
      n=1
    }; done
    check "every churn unit got its own stop call ($1)" "[ \$n = 0 ]"
  }
  expect_no_rearm() { check "no re-arm while io PSI is in the storm band" "! grep -q '^start ' $STUB_DIR/calls.log"; }

  case "$LEG" in
  trip_restore_rearm)
    live_units
    # btrbk-data is NOT loaded (the retired-name class): rc 5 on stop.
    : >"$STUB_DIR/missing.btrbk-data.service"
    : >"$STUB_DIR/fail.btrbk-data.service"
    echo 0 >"$STUB_DIR/is_active.rc"
    write_fakes 0.04 "$zram_orig" 0.10 0.00 1000
    run_guard
    grep -E 'MEMORY EMERGENCY' "$SIM/out" | cut -c1-220
    check "zone-1 trip logged" "grep -q 'below absolute floor' '$SIM/out'"
    check "trip count 1" "[ \"\$(cat $state/tripped.count)\" = 1 ]"
    expect_trip_stops "trip 1"
    check "the rc-5 unit did not stop the loop (units after it still stopped)" "has_call 'stop discordsync-db-heal.service'"
    check "no multi-unit stop call" "! grep -E '^stop [^ ]+ [^ ]+$' $STUB_DIR/calls.log | grep -q ."
    if [ "$HOST" = 1 ]; then
      check "host shape: NO socket or sacrifice unit call on a memory trip" "! grep -q 'fastflowlm' $STUB_DIR/calls.log"
      check "host shape: truthful action wording (no 'sockets + sacrifice units stopped')" "grep -q 'action taken: I/O churn units only (no socket or sacrifice unit is configured: observe-only mode) (trip #1, zone 1)' '$SIM/out' && ! grep -q 'stopping sockets' '$SIM/out' && grep -q 'stopping the I/O churn units to relieve pressure' '$SIM/out'"
      check "host shape: no is-active probe (nothing managed)" "! grep -q '^is-active' $STUB_DIR/calls.log"
    else
      check "socket stop is ONE unit per call" "has_call 'stop $SOCKET_UNITS'"
      check "VM shape: unchanged action wording" "grep -q 'action taken: sockets + sacrifice units stopped (trip #1, zone 1)' '$SIM/out' && grep -qF 'stopping sockets + fastflowlm@*.service fastflowlm.service to prevent kernel freeze' '$SIM/out'"
      check "sacrifice units stopped one call each" "has_call 'stop fastflowlm.service' && has_call 'stop fastflowlm@*.service'"
    fi
    # The churn stop HOLDS for one IO action cooldown (2026-11-26): the io
    # PSI value is read before the trip action, so this run (memory trip,
    # calm io) used to restart the units it had just stopped.
    check "no start call in the trip run (the churn stop holds)" "! grep -q '^start ' $STUB_DIR/calls.log"
    check "the held re-arm is logged" "grep -q 'CHURN-REARM HELD' '$SIM/out'"
    check "the held line names the minimum window" "grep -q 'minimum 150s' '$SIM/out'"
    check "no blocking start anywhere in the trip run" "! grep -E '^start [^-]' $STUB_DIR/calls.log | grep -q ."
    check "churn-stopped written and kept" "[ -s $state/churn-stopped ]"
    # --- healthy run, trip 700 s old
    last=$(($(date +%s) - 700))
    echo "$last" >"$state/last-trip"
    echo 3 >"$STUB_DIR/is_active.rc"
    write_fakes 0.30 "$zram_orig" 0.10 0.00 1000
    run_guard
    grep -E 'MEMORY EMERGENCY' "$SIM/out" | cut -c1-260
    if [ "$HOST" = 1 ]; then
      check "host shape: observe-only run touches NO unit" "! grep -qE '^(stop|start|reset-failed|is-active) ' $STUB_DIR/calls.log"
      check "host shape: no restore, no restore budget file" "[ ! -e $state/restored.count ] && ! ls $state/restores-* >/dev/null 2>&1"
      check "host shape: no emergency line on a healthy run" "! grep -q 'MEMORY EMERGENCY' '$SIM/out'"
    else
      check "restore logged" "grep -q 'sacrifice sockets restored' '$SIM/out'"
      check "restore #1 counted" "[ \"\$(cat $state/restored.count)\" = 1 ]"
      check "socket started (blocking, one unit)" "has_call 'start $SOCKET_UNITS'"
      check "reset-failed per sacrifice unit (one call each)" "has_call 'reset-failed fastflowlm@*.service' && has_call 'reset-failed fastflowlm.service' && ! grep -E '^reset-failed [^ ]+ [^ ]+$' $STUB_DIR/calls.log | grep -q ."
      check "no stop on the restore run" "! grep -q '^stop ' $STUB_DIR/calls.log"
      check "daily budget file = 1" "[ \"\$(cat $state/restores-\$(date +%Y%m%d))\" = 1 ]"
    fi
    # Healthy, io calm, but the stop is seconds old: still held.
    check "healthy run inside the stop window starts no churn unit" "! grep -E '^start --no-block (btrbk|btrfs)' $STUB_DIR/calls.log | grep -q ."
    check "healthy run inside the stop window logs the held re-arm" "grep -q 'CHURN-REARM HELD' '$SIM/out'"
    check "no re-arm counted yet" "[ ! -e $state/churn-rearm.count ]"
    check "churn-stopped still present inside the stop window" "[ -s $state/churn-stopped ]"
    # --- second memory trip with io PSI still in the storm band (45 >= 40):
    #     the churn stops must STICK (no drain block while io is not drained)
    echo 0 >"$STUB_DIR/is_active.rc"
    write_fakes 0.04 "$zram_orig" 0.10 45.00 13000
    run_guard
    grep -E 'MEMORY EMERGENCY' "$SIM/out" | cut -c1-200
    check "second trip counted" "[ \"\$(cat $state/tripped.count)\" = 2 ]"
    expect_trip_stops "trip 2"
    expect_no_rearm
    check "churn-stopped lists exactly the 3 live units" \
      "[ \"\$(sort $state/churn-stopped | tail -n +2 | tr '\n' ' ')\" = 'btrbk-root.service btrfs-balance-data.service btrfs-scrub@-.service ' ]"
    check "re-arm counter still absent (no re-arm so far)" "[ ! -e $state/churn-rearm.count ]"
    # --- drain run inside the stop window: healthy, io calm, stop still
    #     fresh -> held (a PSI hovering at the bar used to re-arm on the
    #     first run under it)
    write_fakes 0.30 "$zram_orig" 0.10 0.00 1000
    run_guard
    grep -E 'MEMORY EMERGENCY|CHURN-REARM' "$SIM/out" | cut -c1-260
    check "drain run inside the stop window is held" "grep -q 'CHURN-REARM HELD' '$SIM/out' && ! grep -q 'churn units re-armed' '$SIM/out'"
    check "held drain run starts no churn unit" "! grep -E '^start --no-block (btrbk|btrfs)' $STUB_DIR/calls.log | grep -q ."
    # --- drain run after the window (churn-stopped backdated 700 s): healthy,
    #     io PSI under the trip bar -> churn re-arm
    awk -v e="$(($(date +%s) - 700))" 'NR==1{$0=e}1' "$state/churn-stopped" >"$state/churn-stopped.new"
    mv "$state/churn-stopped.new" "$state/churn-stopped"
    write_fakes 0.30 "$zram_orig" 0.10 0.00 1000
    run_guard
    grep -E 'MEMORY EMERGENCY|CHURN-REARM' "$SIM/out" | cut -c1-260
    check "re-arm logged" "grep -q 'churn units re-armed' '$SIM/out'"
    check "re-arm discloses the scrub exclusion" "grep -q 'btrfs-scrub left stopped' '$SIM/out'"
    check "btrbk-root re-armed WITHOUT blocking" "has_call 'start --no-block btrbk-root.service'"
    check "balance re-armed WITHOUT blocking" "has_call 'start --no-block btrfs-balance-data.service'"
    check "scrub NOT re-armed" "! grep -E '^start .*btrfs-scrub' $STUB_DIR/calls.log | grep -q ."
    check "no blocking start of any churn/backup unit" \
      "n=0; for u in $CHURN_UNITS $BACKUP_UNITS; do has_call \"start \$u\" && n=1; done; [ \$n = 0 ]"
    check "churn-stopped file cleared" "[ ! -e $state/churn-stopped ]"
    check "re-arm counter 1" "[ \"\$(cat $state/churn-rearm.count)\" = 1 ]"
    ;;

  catchup)
    live_units
    for u in $CHURN_UNITS; do [ -r "$STUB_DIR/active.$u" ] || : >"$STUB_DIR/missing.$u"; done
    echo 0 >"$STUB_DIR/is_active.rc"
    write_fakes 0.30 "$zram_orig" 0.10 0.00 1000
    run_guard
    echo $(($(date +%s) - 30)) >"$state/io-ticks.epoch"
    if [ "$HOST" = 1 ]; then
      # Host shape: zone 6 is IO-split (no unit stops before escalation), so
      # the backup is stopped by a MEMORY trip that coincides with a storm.
      write_fakes 0.04 "$zram_orig" 0.10 55.00 13000
      run_guard
      grep -E 'MEMORY EMERGENCY' "$SIM/out" | cut -c1-200
      check "memory trip inside an io storm (host shape)" "grep -q 'below absolute floor' '$SIM/out'"
      check "host shape: no socket call" "! grep -q 'fastflowlm' $STUB_DIR/calls.log"
    else
      write_fakes 0.30 "$zram_orig" 0.10 55.00 13000
      run_guard
      grep -E 'MEMORY EMERGENCY' "$SIM/out" | cut -c1-200
      check "zone-6 trip (io avg60 55, busy disks)" "grep -q 'I/O PSI some avg60' '$SIM/out'"
      check "socket stopped on the legacy zone-6 path" "has_call 'stop $SOCKET_UNITS'"
    fi
    check "backup stop started the starvation clock" "[ -s $state/backup-stopped.epoch ]"
    check "btrbk-root stopped" "has_call 'stop btrbk-root.service'"
    # starve the backup 7 h, keep io PSI at 45 (above trip bar, below resume bar 50)
    echo $(($(date +%s) - 25200)) >"$state/backup-stopped.epoch"
    if [ "$HOST" = 1 ]; then write_fakes 0.04 "$zram_orig" 0.10 45.00 26000; else write_fakes 0.30 "$zram_orig" 0.10 45.00 26000; fi
    run_guard
    grep -E 'MEMORY EMERGENCY' "$SIM/out" | cut -c1-220
    check "catch-up slot granted" "grep -q 'backup catch-up slot granted' '$SIM/out'"
    check "backup started WITHOUT blocking" "has_call 'start --no-block btrbk-root.service'"
    check "no blocking start of any backup unit" "n=0; for u in $BACKUP_UNITS; do has_call \"start \$u\" && n=1; done; [ \$n = 0 ]"
    check "catch-up counter 1" "[ \"\$(cat $state/backup-catchup.count)\" = 1 ]"
    check "starvation clock cleared" "[ ! -e $state/backup-stopped.epoch ]"
    check "non-backup churn unit still in the stopped window" "grep -q 'btrfs-balance-data.service' $state/churn-stopped"
    check "granted backup left the stopped window" "! grep -q 'btrbk-root.service' $state/churn-stopped"
    # A trip INSIDE the protection window must keep the granted backup running.
    echo $(($(date +%s) - 700)) >"$state/last-trip"
    if [ "$HOST" = 1 ]; then write_fakes 0.04 "$zram_orig" 0.10 55.00 39000; else write_fakes 0.30 "$zram_orig" 0.10 55.00 39000; fi
    run_guard
    grep -E 'MEMORY EMERGENCY' "$SIM/out" | cut -c1-220
    check "slot protection line" "grep -q 'catch-up slot active' '$SIM/out' && grep -q 'keeping btrbk-root.service running' '$SIM/out'"
    check "protected backup NOT stopped by the trip action" "! has_call 'stop btrbk-root.service'"
    check "NO backup unit is stopped inside the protection window" "n=0; for u in $BACKUP_UNITS; do has_call \"stop \$u\" && n=1; done; [ \$n = 0 ]"
    check "non-backup churn units are still stopped" "has_call 'stop btrfs-balance-data.service' && has_call 'stop discordsync-db-heal.service'"
    ;;

  zone6_iopause_host)
    # An IO-split trip that finds only a mover outside every pattern must
    # touch NO unit at all (both shapes).
    write_fakes 0.30 "$zram_orig" 0.10 0.00 1000
    run_guard
    echo $(($(date +%s) - 30)) >"$state/io-ticks.epoch"
    mkdir -p "$SIM/cgt/system.slice/offender.service"
    (
      b=1000000000
      while :; do
        printf '8:0 rbytes=%s wbytes=0\n' "$b" >"$SIM/cgt/system.slice/offender.service/io.stat"
        b=$((b + 50000000))
        sleep 0.2
      done
    ) &
    WR=$!
    write_fakes 0.30 "$zram_orig" 0.10 55.00 13000
    run_guard IO_PAUSE_ENABLE=true
    kill "$WR" 2>/dev/null
    grep -E 'MEMORY EMERGENCY' "$SIM/out" | cut -c1-260
    check "zone-6 IO-split trip (no memory action line)" "grep -q 'IO-PAUSE (trip #1, zone 6)' '$SIM/out' && ! grep -q 'action taken: sockets' '$SIM/out'"
    check "IO-TOP names the mover" "grep -q 'IO-TOP (trip #' '$SIM/out' && grep -q 'system.slice/offender.service @' '$SIM/out'"
    check "no-match reason names the pattern gap" "grep -q 'no pattern covers any driver' '$SIM/out'"
    check "no unit stop/start/reset call on an unescalated IO trip" "! grep -qE '^(stop|start|reset-failed) ' $STUB_DIR/calls.log"
    check "no io-paused state written" "[ ! -e $state/io-paused ]"
    ;;

  zone6_escalation_host)
    # Driver trees already paused (pause file 1000 s old) and the storm
    # persists (3 zone-6 history entries since the pause epoch): the guard
    # escalates to the churn-unit stop and STILL never touches a socket.
    live_units
    write_fakes 0.30 "$zram_orig" 0.10 0.00 1000
    run_guard
    echo $(($(date +%s) - 30)) >"$state/io-ticks.epoch"
    now=$(date +%s)
    {
      echo $((now - 1000))
      echo "999999 system.slice/nix-daemon.service"
    } >"$state/io-paused"
    {
      echo $((now - 900)) 6
      echo $((now - 800)) 6
      echo $((now - 700)) 6
    } >"$state/trip-history"
    echo $((now - 650)) >"$state/last-trip"
    mkdir -p "$SIM/cgt/system.slice/offender.service"
    (
      b=1000000000
      while :; do
        printf '8:0 rbytes=%s wbytes=0\n' "$b" >"$SIM/cgt/system.slice/offender.service/io.stat"
        b=$((b + 50000000))
        sleep 0.2
      done
    ) &
    WR=$!
    write_fakes 0.30 "$zram_orig" 0.10 55.00 13000
    run_guard IO_PAUSE_ENABLE=true
    kill "$WR" 2>/dev/null
    grep -E 'MEMORY EMERGENCY' "$SIM/out" | cut -c1-300
    check "escalation line" "grep -q 'io escalation: 3 zone-6 trips with driver trees already paused' '$SIM/out'"
    expect_trip_stops "escalated zone-6 trip"
    check "NEVER a socket or sacrifice stop/start/reset on the escalated IO trip" "! grep -E '^(stop|start|reset-failed) fastflowlm' $STUB_DIR/calls.log | grep -q ."
    check "existing pause kept line" "grep -q 'existing pause kept' '$SIM/out'"
    check "InboxClean dashboard is a pause pattern, not a churn unit (guard stops took its Gatus checks down until 2026-11-27)" "! has_call 'stop inboxclean-web.service' && grep -q 'patterns: .* inboxclean-web.service)' '$SIM/out'"
    check "churn-stopped lists exactly the 3 live units" \
      "[ \"\$(sort $state/churn-stopped | tail -n +2 | tr '\n' ' ')\" = 'btrbk-root.service btrfs-balance-data.service btrfs-scrub@-.service ' ]"
    check "trip count 1" "[ \"\$(cat $state/tripped.count)\" = 1 ]"
    ;;

  *)
    echo "unknown leg $LEG"
    exit 2
    ;;
  esac

  echo "unit calls (without cat/show):"
  calls | sed 's/^/  /'
  echo "=== leg $LEG: $FAILS FAIL ==="
  if [ "$FAILS" -eq 0 ]; then
    echo "VERDICT $LEG: PASS"
    exit 0
  fi
  echo "VERDICT $LEG: FAIL ($FAILS check(s) broken)"
  exit 1
}

# --- outer mode: build the guard, run every scenario in a namespace ---------
shape="test"
GUARD=""
MODE="iopause"
NAMES=()
while [ $# -gt 0 ]; do
  case "$1" in
  --harness)
    [ $# -eq 3 ] || die "--harness takes <guard binary> <scenario>"
    harness_iopause "$2" "$3"
    ;;
  --harness-units)
    [ $# -eq 3 ] || die "--harness-units takes <guard binary> <leg>"
    harness_units "$2" "$3"
    ;;
  --units)
    # The positional names are unit-call legs instead of IO-PAUSE scenarios.
    MODE="units"
    shift
    ;;
  --list)
    if [ "$MODE" = units ]; then printf '%s\n' "${ALL_LEGS[@]}"; else printf '%s\n' "${ALL_SCENARIOS[@]}"; fi
    exit 0
    ;;
  --live)
    # The guard script of the running system, read from its unit file.
    GUARD=$(sed -n 's/^ExecStart=\(.*\)$/\1/p' /run/current-system/etc/systemd/system/memory-emergency-guard.service | head -1)
    [ -n "$GUARD" ] && [ -x "$GUARD" ] || die "cannot find the live guard script in the running system's unit file"
    shift
    ;;
  --guard)
    [ $# -ge 2 ] || die "--guard takes a path"
    GUARD="$2"
    shift 2
    ;;
  test | host)
    shape="$1"
    shift
    ;;
  -*)
    usage
    die "unknown flag: $1"
    ;;
  *)
    NAMES+=("$1")
    shift
    ;;
  esac
done
if [ "$MODE" = units ]; then
  [ "${#NAMES[@]}" -gt 0 ] || NAMES=("${ALL_LEGS[@]}")
  for s in "${NAMES[@]}"; do
    case " ${ALL_LEGS[*]} " in
    *" $s "*) ;;
    *) die "unknown unit-call leg: $s (legs: ${ALL_LEGS[*]})" ;;
    esac
  done
else
  [ "${#NAMES[@]}" -gt 0 ] || NAMES=("${ALL_SCENARIOS[@]}")
  for s in "${NAMES[@]}"; do
    case " ${ALL_SCENARIOS[*]} " in
    *" $s "*) ;;
    *) die "unknown scenario: $s (see --list)" ;;
    esac
  done
fi

if [ -z "$GUARD" ]; then
  case "$shape" in
  test) attr='.#checks.x86_64-linux.memory-emergency-guard.nodes.machine.config.systemd.services.memory-emergency-guard.serviceConfig.ExecStart' ;;
  host) attr='.#nixosConfigurations.evo-x2.config.systemd.services.memory-emergency-guard.serviceConfig.ExecStart' ;;
  esac
  GUARD=$(nix eval --raw "$attr") || die "nix eval failed for the $shape shape"
  nix-store --realise "$GUARD" >/dev/null || die "building the $shape guard script failed"
fi
[ -x "$GUARD" ] || die "guard script is not executable: $GUARD"
echo "guard: $GUARD"

sim_root="${XDG_CACHE_HOME:-$HOME/.cache}/systemnix"
mkdir -p "$sim_root"
passed=0
failed=0
if [ "$MODE" = units ]; then harness_flag="--harness-units"; else harness_flag="--harness"; fi
for s in "${NAMES[@]}"; do
  log="$sim_root/guard-sim-$s.log"
  if unshare -Urm env SIM_DIR="$sim_root/sim-$s" bash "$0" "$harness_flag" "$GUARD" "$s" >"$log" 2>&1; then
    passed=$((passed + 1))
    echo "PASS $s"
  else
    failed=$((failed + 1))
    echo "FAIL $s (log: $log)"
    grep -E '^  FAIL|VERDICT|HARNESS|guard rc=[1-9]' "$log" | head -12 || true
  fi
done
echo "== $passed passed, $failed failed (logs: $sim_root/guard-sim-*.log)"
[ "$failed" -eq 0 ]
